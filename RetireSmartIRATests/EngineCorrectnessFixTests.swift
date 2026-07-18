//
//  EngineCorrectnessFixTests.swift
//  RetireSmartIRATests
//
//  Regression tests for the correctness fixes from the 2026-06 external engine review:
//   - C2: Roth conversions cannot consume the RMD balance.
//   - C1: IRMAA uses a 2-year MAGI lookback (a conversion at 63 raises the 65 premium).
//   - H5: explicit taxable/Roth withdrawals fund expenses (cash is not discarded).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Engine correctness fixes (2026-06 review)", .serialized)
@MainActor
struct EngineCorrectnessFixTests {

    private func makeInputs(
        currentAge: Int = 65,
        traditional: Double = 1_000_000,
        roth: Double = 0,
        taxable: Double = 0,
        wageIncome: Double = 0,
        pensionIncome: Double = 0,
        baselineExpenses: Double = 0,
        ssClaimAge: Int = 70,
        expectedBenefitAtFRA: Double = 0,
        filingStatus: FilingStatus = .single,
        state: String = "CA",
        acaEnrolled: Bool = false
    ) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: traditional, roth: roth, taxable: taxable, hsa: 0),
            primaryCurrentAge: currentAge,
            spouseCurrentAge: nil,
            filingStatus: filingStatus,
            state: state,
            primarySSClaimAge: ssClaimAge,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: expectedBenefitAtFRA,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 2026 - currentAge,
            spouseBirthYear: nil,
            primaryWageIncome: wageIncome,
            spouseWageIncome: 0,
            primaryPensionIncome: pensionIncome,
            spousePensionIncome: 0,
            acaEnrolled: acaEnrolled,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: baselineExpenses
        )
    }

    private func makeAssumptions(
        growth: Double = 0.0,
        rule: WithdrawalOrderingRule = .taxEfficient
    ) -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95,
            horizonEndAgeSpouse: nil,
            cpiRate: 0.0,
            investmentGrowthRate: growth,
            withdrawalOrderingRule: rule,
            stressTestEnabled: false,
            perYearOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0
        )
    }

    /// Pin the real 2026 config so IRMAA/bracket values are deterministic.
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    // MARK: - C2: RMD must be satisfied before a conversion can drain the bucket

    @Test("C2: a conversion larger than the balance still leaves the RMD distributed")
    func conversionCannotConsumeRMD() {
        // Age 73 single filer, small traditional IRA, requests a conversion that would
        // otherwise consume the entire balance.
        let inputs = makeInputs(currentAge: 73, traditional: 100_000)
        let assumptions = makeAssumptions()
        let requiredRMD = RMDCalculationEngine.calculateRMD(for: 73, balance: 100_000)
        #expect(requiredRMD > 0)

        let path = ProjectionEngine(configProvider: provider).project(
            inputs: inputs,
            assumptions: assumptions,
            actionsPerYear: [2026: [.rothConversion(amount: 200_000)]]
        )

        // The year's actions must include the auto-imposed RMD as a traditional withdrawal
        // approximately equal to the required RMD (it was NOT swallowed by the conversion).
        let rmdWithdrawals = path[0].actions.compactMap { action -> Double? in
            if case let .traditionalWithdrawal(amount) = action { return amount }
            return nil
        }
        let autoRMD = rmdWithdrawals.max() ?? 0
        #expect(abs(autoRMD - requiredRMD) < 1.0,
            "RMD must be distributed before the conversion; expected ~\(requiredRMD), got \(autoRMD)")
    }

    // MARK: - C1: IRMAA 2-year lookback

    @Test("C1: a conversion at age 63 raises the IRMAA premium at age 65 (2-year lookback)")
    func irmaaLookbackChargesTwoYearsLater() {
        // Single filer, age 63, modest pension, ACA not relevant. Compare a large age-63
        // conversion vs no conversion and inspect the IRMAA charged at age 65 (index 2).
        let inputs = makeInputs(currentAge: 63, traditional: 1_000_000, pensionIncome: 40_000)
        let assumptions = makeAssumptions()

        let withConversion = ProjectionEngine(configProvider: provider).project(
            inputs: inputs, assumptions: assumptions,
            actionsPerYear: [2026: [.rothConversion(amount: 150_000)], 2027: [], 2028: [], 2029: []]
        )
        let baseline = ProjectionEngine(configProvider: provider).project(
            inputs: inputs, assumptions: assumptions,
            actionsPerYear: [2026: [], 2027: [], 2028: [], 2029: []]
        )

        // Year 0 (age 63): pre-Medicare, so no IRMAA regardless of the conversion.
        #expect(withConversion[0].taxBreakdown.irmaa == 0,
            "age 63 is pre-Medicare; no IRMAA in the conversion year")

        // Year 2 (age 65, index 2): the age-63 conversion drives the premium via the
        // 2-year lookback, so IRMAA-with-conversion must exceed IRMAA-without.
        #expect(withConversion[2].taxBreakdown.irmaa > baseline[2].taxBreakdown.irmaa,
            "age-63 conversion should raise the age-65 IRMAA premium (lookback); withConv=\(withConversion[2].taxBreakdown.irmaa) baseline=\(baseline[2].taxBreakdown.irmaa)")
    }

    // MARK: - H5: explicit taxable/Roth withdrawals fund expenses

    @Test("H5: an explicit Roth withdrawal funds expenses and avoids auto trad withdrawals")
    func explicitRothWithdrawalFundsExpenses() {
        // Age 65 single, NO taxable, $40K expenses. Without funding actions, the engine
        // auto-funds expenses from the traditional bucket → AGI ≈ $40K. With an explicit
        // Roth withdrawal that covers expenses, no traditional auto-funding is needed → AGI ≈ 0.
        let inputs = makeInputs(currentAge: 65, traditional: 500_000, roth: 100_000,
                                taxable: 0, baselineExpenses: 40_000)
        let assumptions = makeAssumptions(rule: .taxEfficient)

        let autoFunded = ProjectionEngine(configProvider: provider).project(
            inputs: inputs, assumptions: assumptions, actionsPerYear: [2026: []]
        )
        let rothFunded = ProjectionEngine(configProvider: provider).project(
            inputs: inputs, assumptions: assumptions,
            actionsPerYear: [2026: [.rothWithdrawal(amount: 40_000)]]
        )

        #expect(autoFunded[0].agi > 30_000,
            "with no taxable, expenses auto-fund from traditional → AGI should reflect ~$40K")
        #expect(rothFunded[0].agi < 1_000,
            "explicit Roth withdrawal funds expenses → no taxable trad withdrawal → AGI ≈ 0; got \(rothFunded[0].agi)")
    }
}
