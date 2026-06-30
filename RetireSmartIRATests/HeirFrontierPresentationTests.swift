import Testing
@testable import RetireSmartIRA

@Suite("HeirFrontierPresentation")
struct HeirFrontierPresentationTests {
    private func fp(_ w: Double, owner: Double, heirs: Double) -> FrontierPoint {
        FrontierPoint(weight: w, ownerLifetimeTaxToday: owner, heirAfterTaxInheritanceToday: heirs,
                      heirTaxToday: 0, pvDiscountFactor: 0.5, recommendedPath: [])
    }

    @Test("flat frontier: no material tradeoff, no headline implying one")
    func flat() {
        let result = HeirFrontierResult(points: [
            fp(0, owner: 4_400_000, heirs: 6_000_000),
            fp(0.5, owner: 4_400_000, heirs: 6_000_000),
            fp(1, owner: 4_400_000, heirs: 6_000_000)])
        let p = HeirFrontierPresentation(result: result, selectedWeight: 0, units: .todaysDollars)
        #expect(!p.hasMaterialTradeoff)
        #expect(p.headline.contains("No meaningful"))
        #expect(p.rows.allSatisfy { $0.comparison == "Baseline" || $0.comparison == "No material change" })
    }

    @Test("real tradeoff: strategy labels, deltas vs owner, and an exchange-rate headline")
    func tradeoff() {
        let result = HeirFrontierResult(points: [
            fp(0, owner: 4_100_000, heirs: 5_700_000),    // optimize for you
            fp(0.5, owner: 4_300_000, heirs: 5_900_000),  // balanced
            fp(1, owner: 4_600_000, heirs: 6_200_000)])   // optimize for heirs
        let p = HeirFrontierPresentation(result: result, selectedWeight: 0.5, units: .todaysDollars)
        #expect(p.hasMaterialTradeoff)
        #expect(p.rows.map(\.strategy) == ["Optimize for you", "Balanced", "Optimize for heirs"])
        #expect(p.rows[0].comparison == "Baseline")
        #expect(p.rows[2].taxDeltaVsOwner == 500_000)
        #expect(p.rows[2].heirsDeltaVsOwner == 500_000)
        #expect(p.rows[1].isSelected)                     // weight 0.5 selected
        #expect(p.rows[2].comparison.contains("to heirs"))
        // heir-optimal: +$500k heirs at +$500k tax -> ~$1.00 per $1
        #expect(p.headline.contains("per $1 of extra tax"))
        #expect(p.headline.contains("$1.00"))
    }

    @Test("present-value units scale every figure by the discount factor")
    func presentValueScales() {
        let result = HeirFrontierResult(points: [
            fp(0, owner: 4_000_000, heirs: 6_000_000),
            fp(1, owner: 4_000_000, heirs: 6_000_000)])
        let pv = HeirFrontierPresentation(result: result, selectedWeight: 0, units: .presentValue)
        #expect(pv.rows[0].lifetimeTax == 2_000_000)      // 4M * 0.5
        #expect(pv.rows[0].heirsKeep == 3_000_000)        // 6M * 0.5
    }

    @Test("inefficient lean: factual, not advisory")
    func inefficient() {
        let result = HeirFrontierResult(points: [
            fp(0, owner: 4_000_000, heirs: 6_000_000),
            fp(1, owner: 4_500_000, heirs: 6_000_000)])   // +$500k tax, no more to heirs
        let p = HeirFrontierPresentation(result: result, selectedWeight: 0, units: .todaysDollars)
        #expect(p.hasMaterialTradeoff)
        #expect(p.headline.contains("without materially increasing"))
        #expect(!p.headline.lowercased().contains("not worth"))
        #expect(!p.headline.lowercased().contains("justify"))
    }
}
