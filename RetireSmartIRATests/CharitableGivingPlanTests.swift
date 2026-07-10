import Testing
@testable import RetireSmartIRA

@Suite("Phase 1b — charitable-giving input model", .serialized)
@MainActor
struct CharitableGivingPlanTests {

    @Test("GivingIntent and QCDFundingMethod carry their associated values and are Equatable")
    func valueTypesEquatable() {
        #expect(GivingIntent.fixedAnnualAmount(20_000) == GivingIntent.fixedAnnualAmount(20_000))
        #expect(GivingIntent.fixedAnnualAmount(20_000) != GivingIntent.percentOfRMD(0.25))
        #expect(QCDFundingMethod.qcdFirst == QCDFundingMethod.qcdFirst)
        #expect(QCDFundingMethod.fixedQCD(10_000) != QCDFundingMethod.qcdFirst)
    }

    @Test("CharitableGivingPlan.none directs no giving")
    func noneHasNoGiving() {
        #expect(CharitableGivingPlan.none.hasGiving == false)
        #expect(CharitableGivingPlan.none.funding == .qcdFirst)
        #expect(CharitableGivingPlan.none.maintainRealValue == true)
    }

    @Test("hasGiving reflects a positive fixed amount or percent")
    func hasGivingReflectsIntent() {
        let fixed = CharitableGivingPlan(intent: .fixedAnnualAmount(20_000), funding: .qcdFirst, maintainRealValue: true)
        let pct = CharitableGivingPlan(intent: .percentOfRMD(0.25), funding: .qcdFirst, maintainRealValue: false)
        let zero = CharitableGivingPlan(intent: .percentOfRMD(0), funding: .qcdFirst, maintainRealValue: true)
        #expect(fixed.hasGiving == true)
        #expect(pct.hasGiving == true)
        #expect(zero.hasGiving == false)
    }
}
