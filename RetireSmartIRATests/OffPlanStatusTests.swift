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
}
