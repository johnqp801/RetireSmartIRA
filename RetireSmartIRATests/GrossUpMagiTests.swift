import Testing
import Foundation
@testable import RetireSmartIRA

/// A3: when the conversion tax is self-funded by a grossed-up traditional withdrawal
/// (.taxableThenGrossUp, ProjectionEngine Step 7), that extra ordinary income (`dW`) must be
/// reflected in (1) the MAGI stored for the 2-year IRMAA lookback (`irmaaMagiByYear`) and
/// (2) the reported `magi`/`irmaaMagi` fields — not just in `agi` (`reportedAGI`).
@Suite("A3 gross-up MAGI feeds IRMAA/NIIT", .serialized)
@MainActor
struct GrossUpMagiTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    // Zero Social Security + no muni/tax-exempt income -> magiAddback == 0, so post-fix
    // `rec.magi` must equal `rec.agi` EXACTLY (both = reportedAGI). Pre-fix, `rec.magi` uses
    // pre-gross-up federalAGI, which is strictly less than reportedAGI whenever gross-up fires.
    private func inputs(trad: Double, taxable: Double, age: Int) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026, primaryCurrentAge: age, spouseCurrentAge: nil, filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 2026 - age, spouseBirthYear: nil, primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0, acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0,
            heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
    }
    private func assumptions(_ src: TaxPaymentSource) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
        a.taxPaymentSource = src; return a
    }

    @Test("gross-up-funded year: reported magi equals reported agi (no SS/muni addback)")
    func magiMatchesAgiWhenGrossUpFires() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 2_000_000, taxable: 0, age: 63), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: 400_000)]])
        // Sanity: gross-up actually fired (an extra traditionalWithdrawal action beyond the conversion).
        let withdrawals = p[0].actions.compactMap { act -> Double? in
            if case let .traditionalWithdrawal(a) = act { return a }; return nil }
        #expect(withdrawals.contains { $0 > 0 })
        #expect(abs(p[0].magi - p[0].agi) < 1.0)
    }

    @Test("gross-up-funded conversion raises IRMAA 2 years later vs an ample-taxable twin")
    func futureIRMAAReflectsGrossUp() {
        let engine = ProjectionEngine(configProvider: provider)
        let actions: [Int: [LeverAction]] = [2026: [.rothConversion(amount: 120_000)], 2027: [], 2028: []]
        let grossUp = engine.project(
            inputs: inputs(trad: 2_000_000, taxable: 0, age: 63), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: actions)
        let ample = engine.project(
            inputs: inputs(trad: 2_000_000, taxable: 2_000_000, age: 63), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: actions)
        #expect(grossUp[2].medicareEnrolledCount == 1)
        #expect(grossUp[2].taxBreakdown.irmaa > ample[2].taxBreakdown.irmaa)
    }
}
