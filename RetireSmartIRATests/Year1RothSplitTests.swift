import Testing
@testable import RetireSmartIRA

@Suite("Year1RothSplit")
struct Year1RothSplitTests {
    @Test("preserves the existing split ratio with an exact sum")
    func preservesRatio() {
        let even = Year1RothSplit.apply(newTotal: 80_000, your: 50_000, spouse: 50_000)
        #expect(even.your == 40_000)
        #expect(even.spouse == 40_000)

        let skewed = Year1RothSplit.apply(newTotal: 80_000, your: 75_000, spouse: 25_000)
        #expect(skewed.your == 60_000)
        #expect(skewed.spouse == 20_000)
        #expect(skewed.your + skewed.spouse == 80_000)   // sum stays exact
    }

    @Test("does not silently zero the spouse portion when the total shrinks")
    func shrinkKeepsBoth() {
        let r = Year1RothSplit.apply(newTotal: 30_000, your: 50_000, spouse: 50_000)
        #expect(r.your == 15_000)
        #expect(r.spouse == 15_000)
    }

    @Test("no prior split routes the whole amount to primary; negatives clamp to zero")
    func fallbacks() {
        #expect(Year1RothSplit.apply(newTotal: 60_000, your: 0, spouse: 0) == (60_000, 0))
        #expect(Year1RothSplit.apply(newTotal: -5, your: 10_000, spouse: 0) == (0, 0))
    }

    @Test("odd totals still sum exactly")
    func exactSumOnOddTotals() {
        let r = Year1RothSplit.apply(newTotal: 80_001, your: 50_000, spouse: 50_000)
        #expect(r.your + r.spouse == 80_001)
    }
}
