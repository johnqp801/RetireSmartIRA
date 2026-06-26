import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("MVP sections construct", .serialized)
@MainActor
struct MultiYearPlanSectionsConstructTests {
    @Test("plan summary + ladder build from a path")
    func build() {
        let rec = YearRecommendation(year: 2026, agi: 100_000, acaMagi: nil, irmaaMagi: nil,
            taxableIncome: 85_000, taxBreakdown: TaxBreakdown(federal: 1, state: 0, irmaa: 0, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: [.rothConversion(amount: 40_000)], medicareEnrolledCount: 0)
        let summary = PlanSummaryView(summary: PlanSummary(path: [rec]))
        let ladder = LadderListView(rows: [LadderRow(rec)])
        _ = summary.body
        _ = ladder.body
        #expect(true)
    }
}
