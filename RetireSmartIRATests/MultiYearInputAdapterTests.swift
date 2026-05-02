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
        // Add one account of each of the 6 1.9 AccountType cases.
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
            currentTaxableBalance: 0,
            currentHSABalance: 0,
            baselineAnnualExpenses: 0
        )

        XCTAssertEqual(inputs.startingBalances.traditional, 175_000, accuracy: 0.01,
                       "traditional = trad IRA + trad 401k + inherited trad IRA")
        XCTAssertEqual(inputs.startingBalances.roth, 140_000, accuracy: 0.01,
                       "roth = roth IRA + roth 401k + inherited roth IRA")
    }

    func test_buildInputs_passesUserTaxableAndHSABalances() {
        let dm = makeDataManager()
        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            currentTaxableBalance: 25_000,
            currentHSABalance: 8_000,
            baselineAnnualExpenses: 0
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
            currentTaxableBalance: 0,
            currentHSABalance: 0,
            baselineAnnualExpenses: 0
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
            currentTaxableBalance: 0,
            currentHSABalance: 0,
            baselineAnnualExpenses: 0
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
            currentTaxableBalance: 0,
            currentHSABalance: 0,
            baselineAnnualExpenses: 0
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
            currentTaxableBalance: 0,
            currentHSABalance: 0,
            baselineAnnualExpenses: 0
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
            currentTaxableBalance: 0,
            currentHSABalance: 0,
            baselineAnnualExpenses: 0
        )

        XCTAssertTrue(inputs.acaEnrolled)
        XCTAssertEqual(inputs.acaHouseholdSize, 3)
    }

    func test_buildInputs_propagatesBaselineExpenses() {
        let dm = makeDataManager()

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            currentTaxableBalance: 0,
            currentHSABalance: 0,
            baselineAnnualExpenses: 96_000
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
            currentTaxableBalance: 0,
            currentHSABalance: 0,
            baselineAnnualExpenses: 0
        )

        XCTAssertNotNil(inputs.spouseCurrentAge)
        XCTAssertNotNil(inputs.spouseSSClaimAge)
        XCTAssertNotNil(inputs.spouseBirthYear)
        XCTAssertNotNil(inputs.spouseMedicareEnrollmentAge)
        XCTAssertEqual(inputs.spouseMedicareEnrollmentAge, 65)
    }
}
