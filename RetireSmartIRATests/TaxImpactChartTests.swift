import Testing
@testable import RetireSmartIRA

@Suite("TaxImpactChart")
struct TaxImpactChartTests {
    private func rec(_ year: Int, tax: Double) -> YearRecommendation {
        YearRecommendation(year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: TaxBreakdown(federal: tax, state: 0, irmaa: 0, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0), actions: [])
    }

    @Test("accumulates plan and doing-nothing tax by year and totals savings")
    func accumulates() {
        let plan = [rec(2026, tax: 30_000), rec(2027, tax: 10_000)]          // cum: 30k, 40k
        let none = [rec(2026, tax: 12_000), rec(2027, tax: 25_000)]          // cum: 12k, 37k
        let model = TaxImpactChart(plan: plan, doingNothing: none)
        #expect(model.points.count == 2)
        #expect(model.points[0].cumulativePlan == 30_000)
        #expect(model.points[0].cumulativeDoingNothing == 12_000)
        #expect(model.points[1].cumulativePlan == 40_000)
        #expect(model.points[1].cumulativeDoingNothing == 37_000)
        // plan pays 40k vs 37k -> plan is 3k WORSE cumulatively here -> negative savings
        #expect(model.totalSavings == -3_000)
    }
}
