import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("YearRecommendation.rmd field")
struct RMDFieldTests {
    private func sampleBreakdown() -> TaxBreakdown { .zero }
    private func sampleSnapshot() -> AccountSnapshot {
        AccountSnapshot(primaryTraditional: 0, spouseTraditional: 0, roth: 0, taxable: 0, hsa: 0)
    }

    @Test("rmd defaults to 0 when omitted (back-compat)")
    func defaultsToZero() {
        let yr = YearRecommendation(
            year: 2026, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: sampleBreakdown(), endOfYearBalances: sampleSnapshot(), actions: [])
        #expect(yr.rmd == 0)
    }

    @Test("rmd is retained when supplied")
    func retainsValue() {
        let yr = YearRecommendation(
            year: 2026, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: sampleBreakdown(), endOfYearBalances: sampleSnapshot(), actions: [],
            rmd: 40_650)
        #expect(yr.rmd == 40_650)
    }
}
