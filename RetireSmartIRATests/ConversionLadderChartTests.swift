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
        let model = ConversionLadderChart(path: [rec(2026, conv: 40_000), rec(2027, conv: 60_000)])
        #expect(model.points.count == 2)
        #expect(model.points[0].year == 2026)
        #expect(model.points[0].conversion == 40_000)
        #expect(model.points[1].conversion == 60_000)
        #expect(model.hasAnyConversion)
        #expect(!ConversionLadderChart(path: [rec(2026, conv: 0)]).hasAnyConversion)
    }

    @Test("trims to the conversion window, dropping leading and trailing zero years")
    func trimsToConversionWindow() {
        // Leading + trailing zero years would pad the categorical x-axis with empty bars.
        let model = ConversionLadderChart(path: [
            rec(2026, conv: 0),
            rec(2027, conv: 40_000),
            rec(2028, conv: 25_000),
            rec(2029, conv: 0),
            rec(2030, conv: 0),
        ])
        #expect(model.points.map(\.year) == [2027, 2028])
    }

    @Test("keeps interior zero years so a gap in the schedule still reads as a gap")
    func keepsInteriorZeros() {
        let model = ConversionLadderChart(path: [
            rec(2026, conv: 40_000),
            rec(2027, conv: 0),
            rec(2028, conv: 25_000),
        ])
        #expect(model.points.map(\.year) == [2026, 2027, 2028])
        #expect(model.points[1].conversion == 0)
    }

    @Test("falls back to the full path when there are no conversions")
    func noConversionsKeepsAll() {
        let model = ConversionLadderChart(path: [rec(2026, conv: 0), rec(2027, conv: 0)])
        #expect(model.points.count == 2)
        #expect(!model.hasAnyConversion)
    }
}
