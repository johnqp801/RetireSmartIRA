import Testing
@testable import RetireSmartIRA

@Suite("YearRecommendation.underfunded", .serialized)
struct YearRecommendationUnderfundedTests {
    @Test("defaults to nil and is settable") func field() {
        let base = AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0)
        let tb = TaxBreakdown(federal: 0, state: 0, irmaa: 0, acaPremiumImpact: 0)
        let a = YearRecommendation(year: 2026, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: tb, endOfYearBalances: base, actions: [], medicareEnrolledCount: 0)
        #expect(a.underfunded == nil)
        let b = YearRecommendation(year: 2026, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: tb, endOfYearBalances: base, actions: [], medicareEnrolledCount: 0, underfunded: 1234)
        #expect(b.underfunded == 1234)
    }
}
