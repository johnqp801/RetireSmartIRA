import Testing
@testable import RetireSmartIRA

@Suite("OffPlanStatus")
struct OffPlanStatusTests {
    @Test("bands classify by extra lifetime tax")
    func bands() {
        #expect(OffPlanStatus(extraLifetimeTax: -500) == .onPlan)
        #expect(OffPlanStatus(extraLifetimeTax: 0) == .onPlan)
        #expect(OffPlanStatus(extraLifetimeTax: 999) == .onPlan)
        #expect(OffPlanStatus(extraLifetimeTax: 1_000) == .nearOptimal)
        #expect(OffPlanStatus(extraLifetimeTax: 9_999) == .nearOptimal)
        #expect(OffPlanStatus(extraLifetimeTax: 10_000) == .offPlan)
        #expect(OffPlanStatus(extraLifetimeTax: 24_999) == .offPlan)
        #expect(OffPlanStatus(extraLifetimeTax: 25_000) == .significantlyOffPlan)
    }

    @Test("only onPlan reports isOnPlan; labels and copy are non-empty and em-dash-free")
    func labelsAndFlags() {
        #expect(OffPlanStatus.onPlan.isOnPlan)
        #expect(!OffPlanStatus.offPlan.isOnPlan)
        for s in [OffPlanStatus.onPlan, .nearOptimal, .offPlan, .significantlyOffPlan] {
            #expect(!s.label.isEmpty)
            #expect(!s.caption.isEmpty)
            #expect(!s.label.contains("\u{2014}"))
            #expect(!s.caption.contains("\u{2014}"))
        }
        #expect(OffPlanStatus.onPlan.severity == .good)
        #expect(OffPlanStatus.significantlyOffPlan.severity == .warning)
    }

    @Test("matching Year-1 reads on plan despite a residual lifetime-tax gap (optimizer artifact)")
    func year1MatchIsOnPlan() {
        // The exact demo bug: user Year-1 == optimal Year-1 ($200k), but current lifetime tax sits
        // $41,639 above the free optimum because pinning yields a slightly worse years-2+ path.
        // That residual is not user-fixable, so it must read as on plan.
        let s = OffPlanStatus.forYear1(userYear1: 200_000, optimalYear1: 200_000,
                                       currentLifetimeTax: 4_433_936, optimalLifetimeTax: 4_392_297)
        #expect(s == .onPlan)
    }

    @Test("genuinely different Year-1 is classified by the lifetime-tax delta")
    func year1DifferentUsesDelta() {
        let off = OffPlanStatus.forYear1(userYear1: 0, optimalYear1: 200_000,
                                         currentLifetimeTax: 4_500_000, optimalLifetimeTax: 4_392_297)
        #expect(off == .significantlyOffPlan)   // ~$108k delta
        let near = OffPlanStatus.forYear1(userYear1: 150_000, optimalYear1: 200_000,
                                          currentLifetimeTax: 4_397_000, optimalLifetimeTax: 4_392_297)
        #expect(near == .nearOptimal)            // ~$4.7k delta
    }
}
