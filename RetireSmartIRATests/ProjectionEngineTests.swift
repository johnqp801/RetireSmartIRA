//
//  ProjectionEngineTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("ProjectionEngine — year-by-year simulation")
@MainActor
struct ProjectionEngineTests {

    // MARK: Test fixtures

    private func makeInputs(
        currentAge: Int = 65,
        traditional: Double = 1_000_000,
        roth: Double = 0,
        taxable: Double = 0,
        hsa: Double = 0,
        wageIncome: Double = 0,
        pensionIncome: Double = 0,
        baselineExpenses: Double = 0,
        ssClaimAge: Int = 67,
        expectedBenefitAtFRA: Double = 3_000,  // monthly
        filingStatus: FilingStatus = .single,
        state: String = "CA"
    ) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: traditional, roth: roth, taxable: taxable, hsa: hsa),
            primaryCurrentAge: currentAge,
            spouseCurrentAge: nil,
            filingStatus: filingStatus,
            state: state,
            primarySSClaimAge: ssClaimAge,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: expectedBenefitAtFRA,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - currentAge,
            spouseBirthYear: nil,
            primaryWageIncome: wageIncome,
            spouseWageIncome: 0,
            primaryPensionIncome: pensionIncome,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: baselineExpenses
        )
    }

    private func makeAssumptions(
        cpi: Double = 0.025,
        growth: Double = 0.06,
        rule: WithdrawalOrderingRule = .taxEfficient
    ) -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95,
            horizonEndAgeSpouse: nil,
            cpiRate: cpi,
            investmentGrowthRate: growth,
            withdrawalOrderingRule: rule,
            stressTestEnabled: false,
            perYearExpenseOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0
        )
    }

    private var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    // MARK: Behavioral tests

    @Test("Single year, no actions, no expenses: balances grow by growthRate")
    func singleYearNoActionsGrowsBalances() {
        let inputs = makeInputs(traditional: 1_000_000, baselineExpenses: 0)
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(growth: 0.06),
            actionsPerYear: [baseYear: []]
        )
        #expect(years.count == 1)
        #expect(abs(years[0].endOfYearBalances.traditional - 1_060_000) < 1.0)
    }

    @Test("Roth conversion before growth: amount moves from traditional to roth, then grows")
    func rothConversionMovesBalances() {
        let inputs = makeInputs(traditional: 1_000_000, roth: 100_000, taxable: 50_000)
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(growth: 0.06),
            actionsPerYear: [baseYear: [.rothConversion(amount: 50_000)]]
        )
        // After conversion: trad 950K, roth 150K. After 6% growth: trad 1,007K, roth 159K.
        #expect(abs(years[0].endOfYearBalances.traditional - 1_007_000) < 1.0)
        #expect(abs(years[0].endOfYearBalances.roth - 159_000) < 1.0)
    }

    @Test("Multi-year horizon: growth compounds")
    func multiYearCompoundsGrowth() {
        let inputs = makeInputs(traditional: 100_000)
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(growth: 0.06),
            actionsPerYear: [baseYear: [], baseYear + 1: [], baseYear + 2: []]
        )
        #expect(years.count == 3)
        // 100K * 1.06^3 ≈ 119,101.60
        #expect(abs(years[2].endOfYearBalances.traditional - 119_101.60) < 1.0)
    }

    @Test("Traditional withdrawal: increases AGI by withdrawal amount")
    func traditionalWithdrawalIncreasesAGI() {
        let inputs = makeInputs(currentAge: 67, traditional: 500_000)
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [.traditionalWithdrawal(amount: 50_000)]]
        )
        // AGI must include the trad withdrawal (and any SS for age 67 since claim age was 67)
        #expect(years[0].agi >= 50_000)
    }

    @Test("Taxable withdrawal: does NOT increase AGI (zero-gain approximation)")
    func taxableWithdrawalDoesNotIncreaseAGI() {
        let inputs = makeInputs(
            currentAge: 67,
            traditional: 0,
            roth: 0,
            taxable: 500_000,
            ssClaimAge: 70  // not yet claimed at age 67 — eliminates SS income
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [.taxableWithdrawal(amount: 50_000)]]
        )
        #expect(years[0].agi == 0)
    }

    @Test("Per-year expense override: drives auto-funded withdrawals")
    func perYearExpenseOverrideDrivesAutoFunding() {
        var assumptions = makeAssumptions()
        assumptions.perYearExpenseOverrides = [baseYear: 120_000]
        let inputs = makeInputs(
            currentAge: 67,
            traditional: 1_000_000,
            taxable: 500_000,
            ssClaimAge: 70  // not yet claimed
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: assumptions,
            actionsPerYear: [baseYear: []]
        )
        // No SS income, no pension, no wage, expenses 120K → must withdraw 120K from accounts.
        // Total assets dropped by ~120K (modulo growth on the part that wasn't withdrawn).
        let endTotal = years[0].endOfYearBalances.total
        let preGrowthExpected = 1_500_000.0 - 120_000.0  // = 1,380,000 before growth
        let grownExpected = preGrowthExpected * 1.06     // ≈ 1,462,800
        #expect(abs(endTotal - grownExpected) < 1_000)   // within $1K tolerance
    }

    @Test("SS income: zero before claim age, non-zero at claim age")
    func ssIncomeAtClaimAge() {
        // Use a high benefit to push SS above the provisional-income threshold.
        // Single: threshold1=25K. Gross SS at FRA = 8000/mo * 12 = 96K.
        // Provisional income = 0 + 0 + 96K*0.5 = 48K → above threshold → taxable SS > 0.
        let inputs = makeInputs(
            currentAge: 65,
            traditional: 100_000,
            ssClaimAge: 67,
            expectedBenefitAtFRA: 8_000  // monthly = 96K annual at FRA — enough to be taxable
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(cpi: 0.025),
            actionsPerYear: [baseYear: [], baseYear + 1: [], baseYear + 2: []]
        )
        // Year 0 (age 65): no SS yet → AGI = 0
        // Year 1 (age 66): no SS yet → AGI = 0
        // Year 2 (age 67): claim year. SS gross = 96K → provisional income = 48K → above threshold
        // Taxable SS > 0 → AGI > 0 in year 2
        #expect(years[0].agi == 0)   // no SS yet at age 65
        #expect(years[1].agi == 0)   // no SS yet at age 66
        #expect(years[2].agi > 0)    // SS began at 67, taxable portion > 0
    }

    @Test("ACA MAGI: nil for post-Medicare ages")
    func acaMagiNilPostMedicare() {
        let inputs = makeInputs(currentAge: 67, traditional: 100_000, ssClaimAge: 67)
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: []]
        )
        #expect(years[0].acaMagi == nil)
    }

    @Test("IRMAA MAGI: non-nil from age 63 (2-year lookback)")
    func irmaaMagiFromAge63() {
        let inputs = makeInputs(currentAge: 63, traditional: 100_000, ssClaimAge: 67)
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: []]
        )
        #expect(years[0].irmaaMagi != nil)
    }

    @Test("Action sequence is reflected in YearRecommendation.actions verbatim")
    func actionsArePropagatedToOutput() {
        let inputs = makeInputs(traditional: 1_000_000)
        let engine = ProjectionEngine()
        let actions: [LeverAction] = [.rothConversion(amount: 30_000), .hsaContribution(amount: 4_300)]
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: actions]
        )
        #expect(years[0].actions == actions)
    }

    // MARK: Additional edge-case tests

    @Test("HSA contribution: reduces AGI, moves money from taxable to HSA")
    func hsaContributionReducesAGI() {
        // Traditional withdrawal gives us baseline AGI, then HSA contribution reduces it
        let inputs = makeInputs(
            currentAge: 67,
            traditional: 500_000,
            taxable: 50_000,
            ssClaimAge: 70  // no SS
        )
        let engine = ProjectionEngine()
        let withHSA = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [
                .traditionalWithdrawal(amount: 50_000),
                .hsaContribution(amount: 4_150)
            ]]
        )
        let withoutHSA = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [.traditionalWithdrawal(amount: 50_000)]]
        )
        // HSA contribution is above-the-line: AGI should be lower with HSA
        #expect(withHSA[0].agi < withoutHSA[0].agi)
        // HSA balance increased by 4150
        #expect(abs(withHSA[0].endOfYearBalances.hsa - 4_150 * 1.06) < 1.0)
    }

    @Test("Roth withdrawal: does NOT increase AGI")
    func rothWithdrawalDoesNotIncreaseAGI() {
        let inputs = makeInputs(
            currentAge: 67,
            roth: 500_000,
            ssClaimAge: 70  // no SS
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [.rothWithdrawal(amount: 50_000)]]
        )
        #expect(years[0].agi == 0)
    }

    @Test("taxableIncome is non-negative even at zero AGI")
    func taxableIncomeIsNonNegative() {
        let inputs = makeInputs(currentAge: 67, roth: 100_000, ssClaimAge: 70)
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: []]
        )
        #expect(years[0].taxableIncome >= 0)
    }

    @Test("Multi-year: balances evolve correctly across years")
    func multiYearBalanceEvolution() {
        let inputs = makeInputs(traditional: 200_000, roth: 100_000)
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(growth: 0.10),
            actionsPerYear: [
                baseYear: [.rothConversion(amount: 10_000)],
                baseYear + 1: []
            ]
        )
        // After year 1: trad = (200K-10K)*1.1 = 209K, roth = (100K+10K)*1.1 = 121K
        #expect(abs(years[0].endOfYearBalances.traditional - 209_000) < 1.0)
        #expect(abs(years[0].endOfYearBalances.roth - 121_000) < 1.0)
        // After year 2: trad = 209K*1.1 = 229,900, roth = 121K*1.1 = 133,100
        #expect(abs(years[1].endOfYearBalances.traditional - 229_900) < 1.0)
        #expect(abs(years[1].endOfYearBalances.roth - 133_100) < 1.0)
    }

    @Test("COLA: SS income grows in later years after claim")
    func colaGrowsSSIncomeOverTime() {
        // Verify that COLA compounding increases the gross SS income stream over time.
        // Person age 62 claims at 62 so SS begins in year 0. We track acaMagi which equals
        // grossSS (taxable + non-taxable SS), a cleaner COLA signal than AGI because the
        // SS taxation formula has non-linearities around the provisional-income thresholds.
        // All three years are pre-Medicare (ages 62, 63, 64) so acaMagi is always non-nil.
        // acaEnrolled: true so acaMagi is computed (Bug C fix: acaMagi requires acaEnrolled=true
        // AND anyPreMedicare; pre-Medicare at 62 satisfies the age condition).
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 100_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 62, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 62, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 8_000, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 62,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: true,   // required for acaMagi to be non-nil (post Bug C fix)
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(cpi: 0.025),
            actionsPerYear: [baseYear: [], baseYear + 1: [], baseYear + 2: []]
        )
        // acaMagi = federalAGI + nonTaxableSS = taxableSS + nonTaxableSS = grossSS.
        // With 2.5% COLA, grossSS grows year over year: year2 acaMagi > year0 acaMagi.
        #expect(years[0].acaMagi != nil)   // pre-Medicare (age 62), acaEnrolled=true → acaMagi defined
        #expect(years[2].acaMagi != nil)   // pre-Medicare (age 64), acaEnrolled=true → acaMagi defined
        let aca0 = years[0].acaMagi ?? 0
        let aca2 = years[2].acaMagi ?? 0
        #expect(aca0 > 0)              // SS is flowing (claiming at 62)
        #expect(aca2 > aca0)           // COLA grew the gross SS stream
    }

    // MARK: RMD tests (v2.0 Phase 1)

    @Test("RMD: no auto-imposed RMD when age below 73")
    func rmdNotImposedBelowAge73() {
        let inputs = makeInputs(currentAge: 70, traditional: 1_000_000)
        let engine = ProjectionEngine()
        let years = engine.project(inputs: inputs, assumptions: makeAssumptions(), actionsPerYear: [baseYear: []])
        // No RMD pressure; person is 70, birthYear ≈ currentYear-70 → rmdAge 75 (SECURE 2.0).
        // No trad withdrawal should be forced.
        let actions = years[0].actions
        let totalTradWithdrawal = actions.compactMap {
            if case .traditionalWithdrawal(let a) = $0 { return a } else { return nil }
        }.reduce(0.0, +)
        #expect(totalTradWithdrawal == 0)
    }

    @Test("RMD: auto-imposed when primary age >= 73 (born 1955)")
    func rmdImposedAtAge73() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 73, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1955,  // → rmdAge = 73
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(inputs: inputs, assumptions: makeAssumptions(), actionsPerYear: [baseYear: []])

        // Year 0 should reflect RMD income in AGI.
        // RMD on $1M @ age 73 ≈ $1M / 26.5 ≈ $37,735
        #expect(years[0].agi > 30_000)  // some RMD-driven AGI
        #expect(years[0].agi < 50_000)  // not absurd
    }

    @Test("RMD: auto-imposed satisfies explicit traditionalWithdrawal already covering it")
    func rmdSatisfiedByExplicitWithdrawal() {
        // Setup: age 73, $1M trad. RMD ≈ $37,735.
        // Explicit action: $50K trad withdrawal (more than RMD).
        // Engine should NOT auto-impose additional RMD on top.
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 73, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1955, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [.traditionalWithdrawal(amount: 50_000)]]
        )
        // Total trad withdrawal in actions list should be just the $50K (no extra RMD top-up since 50K > RMD)
        let totalTrad = years[0].actions.compactMap {
            if case .traditionalWithdrawal(let a) = $0 { return a } else { return nil }
        }.reduce(0.0, +)
        #expect(abs(totalTrad - 50_000) < 100)  // approx, RMD is below 50K so no extra imposed
    }

    @Test("RMD: at age 75 birth-year >= 1960")
    func rmdAtAge75ForLaterBirthYear() {
        // Person born 1962 has rmdAge 75. At currentAge 75 → RMD year 1.
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 75, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1962,  // → rmdAge = 75
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(inputs: inputs, assumptions: makeAssumptions(), actionsPerYear: [baseYear: []])
        // RMD on $1M at age 75 ≈ $1M / 24.6 ≈ $40,650
        #expect(years[0].agi > 30_000)
        #expect(years[0].agi < 60_000)
    }

    @Test("RMD: born 1962, age 73 → no RMD yet (RMD age is 75)")
    func noRMDForLaterBirthYearAtAge73() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 73, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1962,  // → rmdAge = 75 (SECURE 2.0)
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(inputs: inputs, assumptions: makeAssumptions(), actionsPerYear: [baseYear: []])
        // Born 1962, age 73, RMD age 75 → no RMD yet
        #expect(years[0].agi == 0)
    }

    @Test("RMD: continues each year past RMD age")
    func rmdContinuesEachYear() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 73, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1955,  // rmdAge = 73
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [], baseYear + 1: [], baseYear + 2: []]
        )
        // Each year should have RMD-driven AGI.
        #expect(years[0].agi > 0)
        #expect(years[1].agi > 0)
        #expect(years[2].agi > 0)
        // Trad balance should not have grown uncontrolled (RMDs are withdrawing)
        #expect(years[2].endOfYearBalances.traditional < 1_500_000)
    }

    @Test("COLA: exact magnitude matches (1+cpi)^yearsSinceClaim over 5 years")
    func colaExactMagnitudeOverFiveYears() {
        // This is a regression pin for the COLA workaround. If the formula gets swapped
        // (e.g., pow→multiply, or yearsSinceClaim off-by-one), this test fails.
        // The test isolates COLA growth by constructing a scenario where:
        //   - Person already claiming SS (no claim-year transition during the projection)
        //   - No traditional/roth/taxable balances, so AGI = taxable SS only
        //   - acaMagi = grossSS (all pre-Medicare ages 60-64)
        //   - 2.5% CPI compounding over 5 years should yield grossSS_year4 / grossSS_year0
        //     ≈ 1.025^4 = 1.10381 (within ~0.1%)
        // acaEnrolled: true so acaMagi is non-nil for the pre-Medicare ages 60-64
        // (Bug C fix requires acaEnrolled=true AND anyPreMedicare for acaMagi to be set).
        let cpi = 0.025
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 60, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 60, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 5_000, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 60,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: true,   // required for acaMagi to be non-nil (post Bug C fix)
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(cpi: cpi),
            actionsPerYear: Dictionary(uniqueKeysWithValues: (0..<5).map { (baseYear + $0, []) })
        )

        let grossSSYear0 = years[0].acaMagi ?? 0
        let grossSSYear4 = years[4].acaMagi ?? 0
        #expect(grossSSYear0 > 0)

        // Year 4 means 4 years of COLA compounding from year 0.
        // (Year 0 itself is the "claim year" — no COLA applied yet.)
        let expectedRatio = pow(1.0 + cpi, 4.0)   // ≈ 1.103813
        let actualRatio = grossSSYear4 / grossSSYear0
        let pctError = abs(actualRatio - expectedRatio) / expectedRatio
        #expect(pctError < 0.005, "COLA ratio after 4 years should match (1.025)^4 within 0.5%, got \(actualRatio) vs \(expectedRatio)")
    }

    // MARK: IRMAA Medicare-enrolled-count tests (Bug #1 fix)

    @Test("IRMAA: single filer at 65 — medicareEnrolledCount == 1, irmaaCost == 1× perPerson")
    func irmaaSingleFilerCount1() {
        // Single filer, age 65. MAGI must exceed the tier-1 threshold so IRMAA is non-zero.
        // We do a Roth conversion large enough to push MAGI above $109,001 (2026 single tier-1).
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 2_000_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 65, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 65,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [.rothConversion(amount: 150_000)]]
        )
        // medicareEnrolledCount should be 1 (only primary on Medicare)
        #expect(years[0].medicareEnrolledCount == 1)
        // IRMAA cost should equal annualSurchargePerPerson × 1 (non-zero because MAGI > tier-1)
        let irmaaMagi = years[0].irmaaMagi ?? 0
        let result = TaxCalculationEngine.calculateIRMAA(magi: irmaaMagi, filingStatus: .single)
        #expect(result.tier > 0)
        let expectedIRMAA = result.annualSurchargePerPerson * 1.0
        #expect(abs(years[0].taxBreakdown.irmaa - expectedIRMAA) < 0.01)
    }

    @Test("IRMAA: MFJ both spouses age 65+ — medicareEnrolledCount == 2, irmaaCost == 2× perPerson")
    func irmaaMFJBothOnMedicareCount2() {
        // MFJ, primary age 67, spouse age 65. Both past enrollment age 65.
        // Large Roth conversion to push MAGI above tier-1 MFJ threshold ($218,001 in 2026).
        let currentYear = Calendar.current.component(.year, from: Date())
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 4_000_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 67, spouseCurrentAge: 65,
            filingStatus: .marriedFilingJointly, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: 70,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: 0,
            primaryBirthYear: currentYear - 67,
            spouseBirthYear: currentYear - 65,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [.rothConversion(amount: 300_000)]]
        )
        // Both spouses are on Medicare → count = 2
        #expect(years[0].medicareEnrolledCount == 2)
        // IRMAA cost = annualSurchargePerPerson × 2
        let irmaaMagi = years[0].irmaaMagi ?? 0
        let result = TaxCalculationEngine.calculateIRMAA(magi: irmaaMagi, filingStatus: .marriedFilingJointly)
        #expect(result.tier > 0)
        let expectedIRMAA = result.annualSurchargePerPerson * 2.0
        #expect(abs(years[0].taxBreakdown.irmaa - expectedIRMAA) < 0.01)
    }

    @Test("IRMAA: MFJ only primary on Medicare — medicareEnrolledCount == 1, irmaaCost == 1× perPerson")
    func irmaaMFJOnlyPrimaryOnMedicareCount1() {
        // MFJ, primary age 67 (on Medicare), spouse age 62 (not yet on Medicare).
        let currentYear = Calendar.current.component(.year, from: Date())
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 4_000_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 67, spouseCurrentAge: 62,
            filingStatus: .marriedFilingJointly, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: 70,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: 0,
            primaryBirthYear: currentYear - 67,
            spouseBirthYear: currentYear - 62,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [.rothConversion(amount: 300_000)]]
        )
        // Only primary on Medicare → count = 1
        #expect(years[0].medicareEnrolledCount == 1)
        // IRMAA cost = annualSurchargePerPerson × 1
        let irmaaMagi = years[0].irmaaMagi ?? 0
        let result = TaxCalculationEngine.calculateIRMAA(magi: irmaaMagi, filingStatus: .marriedFilingJointly)
        #expect(result.tier > 0)
        let expectedIRMAA = result.annualSurchargePerPerson * 1.0
        #expect(abs(years[0].taxBreakdown.irmaa - expectedIRMAA) < 0.01)
    }

    // MARK: Tax debit tests (Bug #2 fix)

    @Test("Tax debit: taxable reduced by year's tax when taxable > tax")
    func taxDebitReducesTaxableWhenSufficient() {
        // Single filer age 67. Use a large pension income (not from accounts, so no auto-fund
        // withdrawal) to generate a predictable federal tax. Starting taxable = 500K so debit
        // won't exhaust it. Verify endOfYearBalances.taxable == (500K × 1.06) - tax.
        // No explicit actions, no expense shortfall (pension covers expenses).
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 500_000, hsa: 0),
            primaryCurrentAge: 67, spouseCurrentAge: nil,
            filingStatus: .single, state: "TX",  // TX = no state tax; isolates federal only
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 67,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 80_000, spousePensionIncome: 0,  // drives AGI / tax
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 80_000  // covered by pension; no account drawdown
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(growth: 0.06),
            actionsPerYear: [baseYear: []]
        )
        let y = years[0]
        let taxBurden = max(0, y.taxBreakdown.total)
        #expect(taxBurden > 0, "Should have non-zero federal tax on $80K pension income")
        // Expected: taxable grows 6%, then tax is debited.
        let expectedTaxable = 500_000.0 * 1.06 - taxBurden
        #expect(abs(y.endOfYearBalances.taxable - expectedTaxable) < 1.0)
        // Taxable must be strictly less than starting × growthFactor when tax > 0
        #expect(y.endOfYearBalances.taxable < 500_000.0 * 1.06)
    }

    @Test("Tax debit: taxable floored at 0 when tax > taxable (insufficient taxable balance)")
    func taxDebitDoesNotGoBelowZeroWhenInsufficient() {
        // Same scenario but taxable starts near-zero so the tax can't be fully covered.
        // Engine should not crash; taxable should be 0 (not negative).
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 100, hsa: 0),
            primaryCurrentAge: 67, spouseCurrentAge: nil,
            filingStatus: .single, state: "TX",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 67,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 80_000, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 80_000
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(growth: 0.06),
            actionsPerYear: [baseYear: []]
        )
        let y = years[0]
        // Must not crash; taxable should be 0 (fully drained, not negative)
        #expect(y.endOfYearBalances.taxable == 0)
        // Tax burden is still reported correctly in taxBreakdown regardless of available taxable
        #expect(y.taxBreakdown.total > 0)
    }

    // MARK: Bug A — RMD basis is start-of-year trad balance

    @Test("Bug A: RMD computed on start-of-year trad balance, not post-conversion balance")
    func bugA_rmdBasisIsStartOfYearTrad() {
        // Person born 1955 (rmdAge 73), age 73, $1M trad.
        // Apply a large Roth conversion of $200K.
        //
        // Per IRS rules, the RMD must be taken BEFORE a Roth conversion; the conversion
        // does NOT satisfy the RMD. The RMD basis is the prior-year-end balance ($1M).
        //
        // Bug (before fix): engine used post-conversion $800K as RMD basis → auto-RMD ~$30.2K
        // Fix: engine uses start-of-year $1M as RMD basis → auto-RMD ~$37.7K
        //
        // Because Roth conversions are tracked in `explicitRothConversions` (not
        // `explicitTradWithdrawals`), the RMD shortfall = full RMD on $1M regardless of
        // conversion size.
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 73, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1955,  // → rmdAge = 73
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [.rothConversion(amount: 200_000)]]
        )
        // Correct RMD = RMD on $1M (start-of-year). The buggy basis would be $800K (post-conversion).
        let expectedRMD = RMDCalculationEngine.calculateRMD(for: 73, balance: 1_000_000)
        let buggyRMD = RMDCalculationEngine.calculateRMD(for: 73, balance: 800_000)
        #expect(expectedRMD > buggyRMD, "RMD on $1M must exceed RMD on $800K — confirms test is meaningful")

        // The auto-imposed traditionalWithdrawal must equal the full RMD on $1M.
        // (Roth conversions don't count toward RMD satisfaction in the engine's logic.)
        let tradAutoActions = years[0].actions.compactMap {
            if case .traditionalWithdrawal(let a) = $0 { return a } else { return nil }
        }
        let autoRMD = tradAutoActions.reduce(0.0, +)
        #expect(abs(autoRMD - expectedRMD) < 1.0,
                "Auto RMD must equal RMD($1M)=\(expectedRMD). Got \(autoRMD). Buggy basis would give \(buggyRMD)")
        // AGI includes both the $200K conversion income AND the auto-imposed RMD income
        #expect(years[0].agi >= 200_000 + expectedRMD - 1.0)
    }

    @Test("Bug A: partial conversion — auto-RMD uses full start-of-year balance, not post-conversion balance")
    func bugA_partialConversionRmdOnFullBalance() {
        // Person born 1955 (rmdAge 73), age 73, $1M trad.
        // Apply a small $10K Roth conversion (well below the ~$37.7K RMD).
        //
        // Roth conversions do NOT satisfy RMD obligations in the engine (they're tracked
        // separately as `explicitRothConversions`, not `explicitTradWithdrawals`). So the
        // auto-imposed RMD shortfall = full RMD($1M), regardless of conversion size.
        //
        // Bug (before fix): auto-RMD was based on post-conversion $990K → ~$37.4K
        // Fix: auto-RMD based on start-of-year $1M → ~$37.7K
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 73, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1955,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: [.rothConversion(amount: 10_000)]]
        )
        // Correct: auto-RMD = full RMD on $1M (conversions don't count toward RMD shortfall)
        let expectedAutoRMD = RMDCalculationEngine.calculateRMD(for: 73, balance: 1_000_000)
        // Bug would produce: RMD on $990K (post-conversion basis)
        let buggyAutoRMD = RMDCalculationEngine.calculateRMD(for: 73, balance: 990_000)
        #expect(expectedAutoRMD > buggyAutoRMD, "RMD on $1M must exceed RMD on $990K — confirms test is meaningful")

        let tradAutoActions = years[0].actions.compactMap {
            if case .traditionalWithdrawal(let a) = $0 { return a } else { return nil }
        }
        #expect(!tradAutoActions.isEmpty, "Auto-imposed RMD shortfall should be present")
        let autoRMD = tradAutoActions.reduce(0.0, +)
        // Must match the full $1M basis, NOT the post-conversion basis
        #expect(abs(autoRMD - expectedAutoRMD) < 1.0,
                "Auto RMD must equal RMD($1M)=\(expectedAutoRMD). Got \(autoRMD). Buggy basis would give \(buggyAutoRMD)")
    }

    // MARK: Bug B — Unbounded explicit actions clamped to source bucket

    @Test("Bug B: Roth conversion clamped when amount exceeds trad balance")
    func bugB_rothConversionClamped() {
        // Person with $50K trad, $0 roth. Request $200K Roth conversion.
        // Bug: trad goes -$150K, roth gains $200K (phantom wealth).
        // Fix: actual conversion = $50K, trad = $0, roth = $50K * 1.06.
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 50_000, roth: 0, taxable: 100_000, hsa: 0),
            primaryCurrentAge: 60, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 60,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(growth: 0.06),
            actionsPerYear: [baseYear: [.rothConversion(amount: 200_000)]]
        )
        let y = years[0]
        // trad should be 0 (clamped, not negative)
        #expect(y.endOfYearBalances.traditional == 0, "trad must be 0 after clamped conversion, not negative")
        // roth should be ~$50K * 1.06 (only $50K transferred, not $200K)
        #expect(abs(y.endOfYearBalances.roth - 50_000 * 1.06) < 1.0,
                "roth should reflect only $50K conversion, not phantom $200K")
        // AGI should include only $50K of conversion income, not $200K
        #expect(y.agi < 100_000, "AGI should reflect only the $50K actual conversion")
        #expect(y.agi >= 50_000, "AGI must include the $50K conversion income")
    }

    @Test("Bug B: taxableWithdrawal clamped when amount exceeds taxable balance")
    func bugB_taxableWithdrawalClamped() {
        // Person with $20K taxable, request $100K taxableWithdrawal.
        // Bug: taxable goes -$80K.
        // Fix: taxable = $0 after withdrawal.
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 20_000, hsa: 0),
            primaryCurrentAge: 60, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 60,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(growth: 0.06),
            actionsPerYear: [baseYear: [.taxableWithdrawal(amount: 100_000)]]
        )
        // taxable should be 0 (clamped), not negative
        #expect(years[0].endOfYearBalances.taxable == 0, "taxable must not go negative from over-withdrawal")
    }

    // MARK: Bug C — ACA gating must check EITHER spouse

    @Test("Bug C: acaMagi non-nil when spouse is pre-Medicare even if primary is post-Medicare")
    func bugC_acaMagiNonNilWhenSpousePreMedicare() {
        // MFJ: primary age 67 (post-Medicare), spouse age 62 (pre-Medicare), acaEnrolled = true.
        // Before fix: acaMagi = nil because primaryAge >= 65.
        // After fix: acaMagi != nil because spouse is still pre-Medicare.
        let currentYear = Calendar.current.component(.year, from: Date())
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 500_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 67, spouseCurrentAge: 62,
            filingStatus: .marriedFilingJointly, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: 70,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: 0,
            primaryBirthYear: currentYear - 67,
            spouseBirthYear: currentYear - 62,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: true,   // <-- enrolled
            acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: []]
        )
        // Spouse (62) is still pre-Medicare → ACA exposure exists → acaMagi should be non-nil
        #expect(years[0].acaMagi != nil,
                "acaMagi must be non-nil: spouse age 62 is still pre-Medicare on ACA plan")
    }

    @Test("Bug C: acaMagi is nil when both spouses are post-Medicare")
    func bugC_acaMagiNilWhenBothPostMedicare() {
        // MFJ: primary age 67, spouse age 67, both post-Medicare. acaEnrolled = true.
        // Both are past Medicare enrollment age → no one is on ACA → acaMagi should be nil.
        let currentYear = Calendar.current.component(.year, from: Date())
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 500_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 67, spouseCurrentAge: 67,
            filingStatus: .marriedFilingJointly, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: 70,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: 0,
            primaryBirthYear: currentYear - 67,
            spouseBirthYear: currentYear - 67,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: true,
            acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 0
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(),
            actionsPerYear: [baseYear: []]
        )
        // Both spouses (67, 67) are past Medicare enrollment age → acaMagi should be nil
        #expect(years[0].acaMagi == nil,
                "acaMagi must be nil: both spouses are post-Medicare, no ACA exposure")
    }

    @Test("Tax debit: no debit when tax is zero")
    func taxDebitNoDebitOnZeroTax() {
        // Person with zero AGI → zero tax → taxable should grow unimpeded.
        // Single age 60, Roth-only (no taxable income), not yet claiming SS, no pension/wage.
        let inputs = makeInputs(
            currentAge: 60,
            traditional: 0,
            roth: 500_000,
            taxable: 200_000,
            ssClaimAge: 70  // no SS yet
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(growth: 0.06),
            actionsPerYear: [baseYear: []]
        )
        let y = years[0]
        #expect(y.taxBreakdown.total <= 0, "Zero AGI means zero (or negative-subsidy) tax")
        // No debit → taxable grows at full 6%
        #expect(abs(y.endOfYearBalances.taxable - 200_000.0 * 1.06) < 1.0)
    }
}
