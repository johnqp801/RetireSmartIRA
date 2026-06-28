import Testing
@testable import RetireSmartIRA

@Suite("ConversionLadderChart")
struct ConversionLadderChartTests {
    private func rec(_ year: Int, conv: Double) -> YearRecommendation {
        YearRecommendation(year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: .zero, endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: conv > 0 ? [.rothConversion(amount: conv)] : [])
    }

    @Test("maps per-year conversions and reports presence")
    func maps() {
        let model = ConversionLadderChart(path: [rec(2026, conv: 40_000), rec(2027, conv: 0)])
        #expect(model.points.count == 2)
        #expect(model.points[0].year == 2026)
        #expect(model.points[0].conversion == 40_000)
        #expect(model.points[1].conversion == 0)
        #expect(model.hasAnyConversion)
        #expect(!ConversionLadderChart(path: [rec(2026, conv: 0)]).hasAnyConversion)
    }
}
