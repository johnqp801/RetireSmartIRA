import Testing
@testable import RetireSmartIRA

@Suite("PlanComparison heir step-up")
struct PlanComparisonHeirStepUpTests {
    private func rec(year: Int, roth: Double, trad: Double, taxable: Double) -> YearRecommendation {
        YearRecommendation(
            year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: .zero,
            endOfYearBalances: AccountSnapshot(traditional: trad, roth: roth, taxable: taxable, hsa: 0),
            actions: [])
    }

    @Test("what heirs keep includes the terminal taxable balance at step-up")
    func heirsKeepIncludesTaxable() {
        let plan = [rec(year: 2026, roth: 0, trad: 0, taxable: 0),
                    rec(year: 2027, roth: 100_000, trad: 0, taxable: 500_000)]
        let cmp = PlanComparison(plan: plan, doingNothing: plan,
            heirSalary: 0, heirFilingStatus: .single, heirDrawdownYears: 10)
        // trad = 0 -> heir tax = 0; heirs keep = Roth(100k) + 0 + taxable(500k)
        #expect(cmp.heirsKeep.plan == 600_000)
    }
}
