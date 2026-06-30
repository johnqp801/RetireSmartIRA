import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("ThresholdMapChartView construct", .serialized)
@MainActor
struct ThresholdMapChartViewTests {
    @Test("builds and carries the 2026-nominal caveat copy")
    func build() {
        let rec = YearRecommendation(year: 2026, agi: 90_000, acaMagi: nil, irmaaMagi: 95_000,
            taxableIncome: 70_000, taxBreakdown: .zero,
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0), actions: [])
        let model = ThresholdMapChart(
            path: [rec],
            magiLines: [.init(id: "irmaa1", label: "IRMAA tier 1", value: 218_001)],
            bracketLines: [.init(id: "br12", label: "12%", value: 24_800)])
        let view = ThresholdMapChartView(model: model)
        _ = view.body
        #expect(ThresholdMapChartView.caveat.localizedCaseInsensitiveContains("2026"))
        #expect(!ThresholdMapChartView.caveat.contains("\u{2014}"))
    }
}
