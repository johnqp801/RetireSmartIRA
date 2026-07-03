import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Objective PV discounting", .serialized)
@MainActor
struct ObjectivePVTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }
    private func inputs() -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 2_000_000, roth: 0, taxable: 1_000_000, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 70, spouseCurrentAge: nil, filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1956, spouseBirthYear: nil, primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0, acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0,
            heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
    }
    private func assumptions(pv: Double) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0.06, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 1_000_000, currentHSABalance: 0)
        a.pvRealDiscountRate = pv; return a
    }
    private func totalConverted(_ r: OptimizationEngine.Result) -> Double {
        r.recommendedPath.reduce(0.0) { acc, yr in acc + yr.actions.reduce(0.0) { a, act in
            if case let .rothConversion(amount) = act { return a + amount }; return a } }
    }
    @Test("higher discount rate converts no more than a near-zero rate") func lessAggressive() {
        let r0 = OptimizationEngine().optimize(inputs: inputs(), assumptions: assumptions(pv: 0.0001), configProvider: provider)
        let r3 = OptimizationEngine().optimize(inputs: inputs(), assumptions: assumptions(pv: 0.05), configProvider: provider)
        #expect(totalConverted(r3) <= totalConverted(r0) + 1.0)
    }

    // Review finding #2: computeObjectiveCost (used by SSClaimNudge) must discount the terminal tax
    // over the SAME horizon as the optimizer's totalObjectiveCost: yearsFromBase == last.year - baseYear + 1.
    @Test("computeObjectiveCost discounts terminal tax over the full horizon (last.year - baseYear + 1)")
    func computeObjectiveCostTerminalDiscount() {
        func yr(_ year: Int, tax: Double, trad: Double) -> YearRecommendation {
            YearRecommendation(year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
                taxBreakdown: TaxBreakdown(federal: tax, state: 0, irmaa: 0, acaPremiumImpact: 0),
                endOfYearBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: 0, hsa: 0),
                actions: [])
        }
        let path = [yr(2026, tax: 10_000, trad: 0), yr(2027, tax: 10_000, trad: 1_000_000)]
        let rate = 0.03, rateLiq = 0.22, baseYear = 2026
        let got = OptimizationEngine.computeObjectiveCost(
            path: path, terminalLiquidationTaxRate: rateLiq, baseYear: baseYear, pvRealDiscountRate: rate)
        let inHorizon = OptimizationEngine.discountedInHorizon(path, baseYear: baseYear, rate: rate)
        // terminal discounted over 2 years (2027 - 2026 + 1), NOT 1 (the old off-by-one)
        let correct = inHorizon + EngineMath.presentValue(1_000_000 * rateLiq, yearsFromBase: 2, realDiscountRate: rate)
        let offByOne = inHorizon + EngineMath.presentValue(1_000_000 * rateLiq, yearsFromBase: 1, realDiscountRate: rate)
        #expect(abs(got - correct) < 0.01)
        #expect(abs(got - offByOne) > 1.0)
    }
}
