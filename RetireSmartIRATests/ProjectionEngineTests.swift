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
        let inputs = makeInputs(
            currentAge: 62,
            traditional: 100_000,
            ssClaimAge: 62,
            expectedBenefitAtFRA: 8_000  // monthly at FRA; claiming at 62 reduces ~30%
        )
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: makeAssumptions(cpi: 0.025),
            actionsPerYear: [baseYear: [], baseYear + 1: [], baseYear + 2: []]
        )
        // acaMagi = federalAGI + nonTaxableSS = taxableSS + nonTaxableSS = grossSS.
        // With 2.5% COLA, grossSS grows year over year: year2 acaMagi > year0 acaMagi.
        #expect(years[0].acaMagi != nil)   // pre-Medicare (age 62) → acaMagi defined
        #expect(years[2].acaMagi != nil)   // pre-Medicare (age 64) → acaMagi defined
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
        let cpi = 0.025
        let inputs = makeInputs(
            currentAge: 60,
            traditional: 0,            // isolate SS as the only AGI source
            roth: 0,
            taxable: 0,
            hsa: 0,
            ssClaimAge: 60,            // already claiming at scenario start
            expectedBenefitAtFRA: 5_000
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
}
