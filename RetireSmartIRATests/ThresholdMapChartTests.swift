import Testing
@testable import RetireSmartIRA

@Suite("ThresholdMapChart")
struct ThresholdMapChartTests {
    private func rec(_ year: Int, agi: Double, irmaaMagi: Double?, acaMagi: Double?, taxable: Double) -> YearRecommendation {
        YearRecommendation(year: year, agi: agi, acaMagi: acaMagi, irmaaMagi: irmaaMagi, taxableIncome: taxable,
            taxBreakdown: .zero, endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: [])
    }

    @Test("MAGI series prefers irmaaMagi, then acaMagi, then agi; bracket series uses taxable income")
    func series() {
        let path = [
            rec(2026, agi: 90_000, irmaaMagi: nil, acaMagi: 88_000, taxable: 70_000),   // pre-Medicare -> acaMagi
            rec(2027, agi: 95_000, irmaaMagi: 96_000, acaMagi: nil, taxable: 75_000),   // Medicare -> irmaaMagi
            rec(2028, agi: 99_000, irmaaMagi: nil, acaMagi: nil, taxable: 80_000)       // neither -> agi
        ]
        let magiLine = ThresholdMapChart.Line(id: "irmaa1", label: "IRMAA tier 1", value: 218_001)
        let brLine = ThresholdMapChart.Line(id: "br12", label: "12%", value: 24_800)
        let model = ThresholdMapChart(path: path, magiLines: [magiLine], bracketLines: [brLine])

        let magi = model.points(for: .magiCliffs)
        #expect(magi.map(\.value) == [88_000, 96_000, 99_000])
        let brackets = model.points(for: .incomeTaxBrackets)
        #expect(brackets.map(\.value) == [70_000, 75_000, 80_000])
        #expect(model.lines(for: .magiCliffs) == [magiLine])
        #expect(model.lines(for: .incomeTaxBrackets) == [brLine])
    }
}
