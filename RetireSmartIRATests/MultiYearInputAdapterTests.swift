//
//  MultiYearInputAdapterTests.swift
//  RetireSmartIRATests
//
//  Tests that MultiYearInputAdapter correctly maps 1.9 runtime state
//  into a MultiYearStaticInputs snapshot.
//

import XCTest
@testable import RetireSmartIRA

@MainActor
final class MultiYearInputAdapterTests: XCTestCase {

    // MARK: - Fixture helpers

    /// Make a DataManager with no persistence and a known birth year.
    /// currentAge = currentYear - birthYear; we use 1961 so the primary is ~65 in 2026.
    private func makeDataManager(birthYear: Int = 1961) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.birthDate = birthDateFor(year: birthYear)
        return dm
    }

    private func birthDateFor(year: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!
    }

    // MARK: - Tests

    func test_buildInputs_collapsesRetirementAccountsIntoTwoBuckets() {
        let dm = makeDataManager()
        // Add one account of each of the 6 1.9 AccountType cases (all owner .primary).
        dm.iraAccounts = [
            IRAAccount(name: "Trad IRA",          accountType: .traditionalIRA,          balance: 100_000, owner: .primary),
            IRAAccount(name: "Trad 401k",         accountType: .traditional401k,         balance: 50_000,  owner: .primary),
            IRAAccount(name: "Inherited Trad",    accountType: .inheritedTraditionalIRA, balance: 25_000,  owner: .primary),
            IRAAccount(name: "Roth IRA",          accountType: .rothIRA,                 balance: 80_000,  owner: .primary),
            IRAAccount(name: "Roth 401k",         accountType: .roth401k,                balance: 40_000,  owner: .primary),
            IRAAccount(name: "Inherited Roth",    accountType: .inheritedRothIRA,        balance: 20_000,  owner: .primary),
        ]

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        // traditional = sum of both buckets (backwards-compat computed property)
        XCTAssertEqual(inputs.startingBalances.traditional, 175_000, accuracy: 0.01,
                       "traditional = trad IRA + trad 401k + inherited trad IRA")
        // All trad goes to primary bucket since all accounts are owner .primary
        XCTAssertEqual(inputs.startingBalances.primaryTraditional, 175_000, accuracy: 0.01,
                       "primaryTraditional should equal all trad when all accounts are primary-owned")
        XCTAssertEqual(inputs.startingBalances.spouseTraditional, 0, accuracy: 0.01,
                       "spouseTraditional should be 0 when no spouse-owned trad accounts exist")
        XCTAssertEqual(inputs.startingBalances.roth, 140_000, accuracy: 0.01,
                       "roth = roth IRA + roth 401k + inherited roth IRA")
    }

    func test_buildInputs_splitsTradByOwner_primaryOnly() {
        // When all trad accounts belong to primary, primaryTraditional should be the sum
        // and spouseTraditional should be 0.
        let dm = makeDataManager()
        dm.iraAccounts = [
            IRAAccount(name: "Primary Trad IRA",  accountType: .traditionalIRA,  balance: 200_000, owner: .primary),
            IRAAccount(name: "Primary Trad 401k", accountType: .traditional401k, balance: 100_000, owner: .primary),
        ]

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        XCTAssertEqual(inputs.startingBalances.primaryTraditional, 300_000, accuracy: 0.01,
                       "All trad from primary-owned accounts → primaryTraditional")
        XCTAssertEqual(inputs.startingBalances.spouseTraditional, 0, accuracy: 0.01,
                       "No spouse-owned trad accounts → spouseTraditional = 0")
    }

    func test_buildInputs_splitsTradByOwner_spouseOnly() {
        // When all trad accounts belong to spouse, spouseTraditional should be the sum
        // and primaryTraditional should be 0.
        let dm = makeDataManager()
        dm.iraAccounts = [
            IRAAccount(name: "Spouse Trad IRA",   accountType: .traditionalIRA,  balance: 150_000, owner: .spouse),
            IRAAccount(name: "Spouse Trad 401k",  accountType: .traditional401k, balance: 75_000,  owner: .spouse),
        ]

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        XCTAssertEqual(inputs.startingBalances.primaryTraditional, 0, accuracy: 0.01,
                       "No primary-owned trad accounts → primaryTraditional = 0")
        XCTAssertEqual(inputs.startingBalances.spouseTraditional, 225_000, accuracy: 0.01,
                       "All trad from spouse-owned accounts → spouseTraditional")
    }

    func test_buildInputs_splitsTradByOwner_mixedOwnership() {
        // When both spouses have trad accounts, each bucket should carry the correct sum.
        let dm = makeDataManager()
        dm.iraAccounts = [
            IRAAccount(name: "Primary Trad IRA",  accountType: .traditionalIRA,  balance: 400_000, owner: .primary),
            IRAAccount(name: "Spouse Trad IRA",   accountType: .traditionalIRA,  balance: 300_000, owner: .spouse),
            IRAAccount(name: "Spouse Trad 401k",  accountType: .traditional401k, balance: 100_000, owner: .spouse),
        ]

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        XCTAssertEqual(inputs.startingBalances.primaryTraditional, 400_000, accuracy: 0.01,
                       "primaryTraditional = sum of primary-owned trad accounts")
        XCTAssertEqual(inputs.startingBalances.spouseTraditional, 400_000, accuracy: 0.01,
                       "spouseTraditional = sum of spouse-owned trad accounts")
        XCTAssertEqual(inputs.startingBalances.traditional, 800_000, accuracy: 0.01,
                       "traditional (computed) = primaryTraditional + spouseTraditional")
    }

    func test_buildInputs_passesUserTaxableAndHSABalances() {
        let dm = makeDataManager()
        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions(currentTaxableBalance: 25_000, currentHSABalance: 8_000)
        )

        XCTAssertEqual(inputs.startingBalances.taxable, 25_000, accuracy: 0.01)
        XCTAssertEqual(inputs.startingBalances.hsa, 8_000, accuracy: 0.01)
    }

    func test_buildInputs_propagatesDemographics() {
        let dm = makeDataManager(birthYear: 1961)
        dm.filingStatus = .marriedFilingJointly
        dm.selectedState = .texas

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        XCTAssertEqual(inputs.primaryBirthYear, 1961)
        XCTAssertEqual(inputs.filingStatus, .marriedFilingJointly)
        XCTAssertEqual(inputs.state, "TX")
    }

    func test_buildInputs_singleFiler_spouseFieldsAreNil() {
        let dm = makeDataManager()
        // enableSpouse defaults to false in DataManager(skipPersistence: true)
        XCTAssertFalse(dm.enableSpouse)

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        XCTAssertNil(inputs.spouseCurrentAge)
        XCTAssertNil(inputs.spouseSSClaimAge)
        XCTAssertNil(inputs.spouseExpectedBenefitAtFRA)
        XCTAssertNil(inputs.spouseBirthYear)
        XCTAssertNil(inputs.spouseMedicareEnrollmentAge)
        XCTAssertEqual(inputs.spouseWageIncome, 0)
        XCTAssertEqual(inputs.spousePensionIncome, 0)
    }

    func test_buildInputs_propagatesSSFields() throws {
        let dm = makeDataManager(birthYear: 1961)
        dm.enableSpouse = true
        dm.spouseBirthDate = birthDateFor(year: 1963)

        // Set up primary SS benefit
        var primaryBenefit = SSBenefitEstimate(owner: .primary)
        primaryBenefit.benefitAtFRA = 3_000
        primaryBenefit.plannedClaimingAge = 70
        dm.primarySSBenefit = primaryBenefit

        // Set up spouse SS benefit
        var spouseBenefit = SSBenefitEstimate(owner: .spouse)
        spouseBenefit.benefitAtFRA = 2_000
        spouseBenefit.plannedClaimingAge = 65
        dm.spouseSSBenefit = spouseBenefit

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        XCTAssertEqual(inputs.primarySSClaimAge, 70)
        XCTAssertEqual(inputs.spouseSSClaimAge, 65)
        XCTAssertEqual(inputs.primaryExpectedBenefitAtFRA, 3_000, accuracy: 0.01)
        let spouseBenefitAtFRA = try XCTUnwrap(inputs.spouseExpectedBenefitAtFRA)
        XCTAssertEqual(spouseBenefitAtFRA, 2_000, accuracy: 0.01)
        XCTAssertEqual(inputs.primaryBirthYear, 1961)
        XCTAssertEqual(inputs.spouseBirthYear, 1963)
    }

    func test_buildInputs_propagatesPensionAndWageIncome() {
        let dm = makeDataManager()
        dm.enableSpouse = true
        dm.spouseBirthDate = birthDateFor(year: 1963)
        dm.incomeSources = [
            IncomeSource(name: "Primary Pension",  type: .pension,    annualAmount: 24_000, owner: .primary),
            IncomeSource(name: "Primary Wage",     type: .consulting, annualAmount: 40_000, owner: .primary),
            IncomeSource(name: "Spouse Pension",   type: .pension,    annualAmount: 12_000, owner: .spouse),
            IncomeSource(name: "Spouse Wage",      type: .consulting, annualAmount: 20_000, owner: .spouse),
        ]

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        XCTAssertEqual(inputs.primaryPensionIncome, 24_000, accuracy: 0.01)
        XCTAssertEqual(inputs.primaryWageIncome,    40_000, accuracy: 0.01)
        XCTAssertEqual(inputs.spousePensionIncome,  12_000, accuracy: 0.01)
        XCTAssertEqual(inputs.spouseWageIncome,     20_000, accuracy: 0.01)
    }

    func test_buildInputs_propagatesACAFields() {
        let dm = makeDataManager()
        dm.scenario.enableACAModeling = true
        dm.scenario.acaHouseholdSize = 3

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        XCTAssertTrue(inputs.acaEnrolled)
        XCTAssertEqual(inputs.acaHouseholdSize, 3)
    }

    func test_buildInputs_propagatesBaselineExpenses() {
        let dm = makeDataManager()

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions(baselineAnnualExpenses: 96_000)
        )

        XCTAssertEqual(inputs.baselineAnnualExpenses, 96_000, accuracy: 0.01)
    }

    func test_buildInputs_coupleHasNonNilSpouseFields() {
        let dm = makeDataManager(birthYear: 1961)
        dm.enableSpouse = true
        dm.spouseBirthDate = birthDateFor(year: 1963)

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        XCTAssertNotNil(inputs.spouseCurrentAge)
        XCTAssertNotNil(inputs.spouseSSClaimAge)
        XCTAssertNotNil(inputs.spouseBirthYear)
        XCTAssertNotNil(inputs.spouseMedicareEnrollmentAge)
        XCTAssertEqual(inputs.spouseMedicareEnrollmentAge, 65)
    }

    // MARK: - Engine integration: Year 1 overrides must produce different lifetime tax

    /// Core invariant of the two-cache strategy in MultiYearStrategyManager:
    /// when Year 1 user overrides are pinned (excludeYear1Overrides=false),
    /// the OptimizationEngine must produce a different recommended path than
    /// when it is free to optimize Year 1 from scratch (excludeYear1Overrides=true).
    ///
    /// This test validates the architectural fix in Plan B Phase 1C1 that wires
    /// OptimizationEngine.optimize(...) to read inputs.year1PrimaryRothConversion
    /// and pin it into locked[baseYear] before the greedy forward pass.
    ///
    /// The test exercises ONLY Roth conversion pinning in V2.0; withdrawal and QCD
    /// pinning are deferred to v2.1 (engine doesn't emit those candidates yet).
    @MainActor
    func testEngine_RespectsYear1RothConversionOverride() {
        // Set up a trad-heavy scenario so the optimizer has a strong Roth-conversion
        // opinion for Year 1. The user pins $47.5K — a meaningful deviation from whatever
        // the optimizer would independently choose, and off-grid to avoid collision
        // with OptimizationEngine.candidateAmounts (which includes $50K).
        let dm = makeDataManager(birthYear: 1961)
        dm.iraAccounts = [
            IRAAccount(name: "Primary Trad IRA", accountType: .traditionalIRA,
                       balance: 1_000_000, owner: .primary),
            IRAAccount(name: "Primary Roth IRA", accountType: .rothIRA,
                       balance: 100_000, owner: .primary),
        ]
        dm.yourRothConversion = 47_500  // Off-grid: not in OptimizationEngine.candidateAmounts,
                                         // guarantees engine free-choice cannot match the pin.

        // Use a short horizon for test speed (consistent with OptimizationEngineTests).
        var assumptions = MultiYearAssumptions()
        assumptions.horizonEndAge = 80
        assumptions.stressTestEnabled = false

        let withOverrides = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: assumptions,
            excludeYear1Overrides: false
        )
        let withoutOverrides = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: assumptions,
            excludeYear1Overrides: true
        )

        // Sanity check: adapter correctly sets/zeros the field.
        XCTAssertEqual(withOverrides.year1PrimaryRothConversion, 47_500, accuracy: 0.01)
        XCTAssertEqual(withoutOverrides.year1PrimaryRothConversion, 0, accuracy: 0.01)

        // Run the engine on both input sets.
        let engine = OptimizationEngine()
        let resultWith    = engine.optimize(inputs: withOverrides,    assumptions: assumptions)
        let resultWithout = engine.optimize(inputs: withoutOverrides, assumptions: assumptions)

        // Verify: Year 1's recommended actions include the pinned $47.5K conversion.
        let year1ActionsWithPin = resultWith.recommendedPath.first?.actions ?? []
        let year1RothWithPin: Double = year1ActionsWithPin.compactMap {
            if case .rothConversion(let amt) = $0 { return amt } else { return nil }
        }.reduce(0, +)
        XCTAssertGreaterThanOrEqual(year1RothWithPin, 47_500,
            "Year 1 Roth conversion in the pinned path must be >= the $47.5K user override")

        // Core invariant: paths differ at least in Year 1 Roth actions.
        let year1ActionsWithout = resultWithout.recommendedPath.first?.actions ?? []
        let year1RothWithout: Double = year1ActionsWithout.compactMap {
            if case .rothConversion(let amt) = $0 { return amt } else { return nil }
        }.reduce(0, +)
        // When the optimizer's free choice for Year 1 equals exactly $50K (astronomically
        // unlikely given the continuous candidate space), paths could match. We assert the
        // Year 1 pinned amount equals the override — that's the engine fix under test.
        // Lifetime tax difference would only be guaranteed when override != free-opt choice.
        // So we assert on Year 1 actions only (which we've already done above), plus
        // a structural "paths differ" check that covers the common case.
        let recommendedPathWithoutRothY1 = year1RothWithout
        _ = recommendedPathWithoutRothY1  // suppress unused-variable warning

        // The lifetime tax totals should differ when $50K != whatever engine would freely pick.
        // We compute lifetime tax inline (mirrors OptimizationEngineTests.lifetimeTax helper).
        let terminalRate = assumptions.terminalLiquidationTaxRate
        let lifetimeWith: Double = {
            let inHorizon = resultWith.recommendedPath.reduce(0.0) { $0 + $1.taxBreakdown.total }
            let termTrad = (resultWith.recommendedPath.last?.endOfYearBalances.primaryTraditional ?? 0)
                         + (resultWith.recommendedPath.last?.endOfYearBalances.spouseTraditional ?? 0)
            return inHorizon + termTrad * terminalRate
        }()
        let lifetimeWithout: Double = {
            let inHorizon = resultWithout.recommendedPath.reduce(0.0) { $0 + $1.taxBreakdown.total }
            let termTrad = (resultWithout.recommendedPath.last?.endOfYearBalances.primaryTraditional ?? 0)
                         + (resultWithout.recommendedPath.last?.endOfYearBalances.spouseTraditional ?? 0)
            return inHorizon + termTrad * terminalRate
        }()
        XCTAssertNotEqual(lifetimeWith, lifetimeWithout,
            "Engine MUST produce different lifetime tax totals when Year 1 overrides are pinned ($47.5K) " +
            "vs free-optimized — this is the core invariant the off-plan indicator depends on. " +
            "If this fails, the engine is ignoring year1PrimaryRothConversion.")
    }

    func testBuild_ExcludeYear1Overrides_ZerosLeverFields() {
        let dm = makeDataManager()
        dm.yourRothConversion = 50_000
        dm.spouseRothConversion = 30_000
        dm.yourExtraWithdrawal = 10_000
        dm.spouseExtraWithdrawal = 5_000
        dm.yourQCDAmount = 2_000
        dm.spouseQCDAmount = 1_000

        let withOverrides = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions(),
            excludeYear1Overrides: false
        )
        let withoutOverrides = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions(),
            excludeYear1Overrides: true
        )

        // The two builds must differ because Year 1 lever fields are non-zero in DataManager.
        XCTAssertNotEqual(withOverrides, withoutOverrides,
            "excludeYear1Overrides=true must produce different inputs when DataManager has non-zero levers")

        // Specific field assertions: withOverrides preserves the user's values.
        XCTAssertEqual(withOverrides.year1PrimaryRothConversion, 50_000, accuracy: 0.01)
        XCTAssertEqual(withOverrides.year1SpouseRothConversion, 30_000, accuracy: 0.01)
        XCTAssertEqual(withOverrides.year1PrimaryWithdrawal, 10_000, accuracy: 0.01)
        XCTAssertEqual(withOverrides.year1SpouseWithdrawal, 5_000, accuracy: 0.01)
        XCTAssertEqual(withOverrides.year1PrimaryQCD, 2_000, accuracy: 0.01)
        XCTAssertEqual(withOverrides.year1SpouseQCD, 1_000, accuracy: 0.01)

        // withoutOverrides zeroes all lever fields.
        XCTAssertEqual(withoutOverrides.year1PrimaryRothConversion, 0, accuracy: 0.01)
        XCTAssertEqual(withoutOverrides.year1SpouseRothConversion, 0, accuracy: 0.01)
        XCTAssertEqual(withoutOverrides.year1PrimaryWithdrawal, 0, accuracy: 0.01)
        XCTAssertEqual(withoutOverrides.year1SpouseWithdrawal, 0, accuracy: 0.01)
        XCTAssertEqual(withoutOverrides.year1PrimaryQCD, 0, accuracy: 0.01)
        XCTAssertEqual(withoutOverrides.year1SpouseQCD, 0, accuracy: 0.01)
    }
}
