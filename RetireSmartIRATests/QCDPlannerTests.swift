import Testing
@testable import RetireSmartIRA

@Suite("QCDPlanner — giving target exposure")
struct QCDPlannerTests {

    @Test func qcdPlannerExposesGivingTarget() {
        let plan = CharitableGivingPlan(intent: .fixedAnnualAmount(10_000),
                                        funding: .fixedQCD(4_000), maintainRealValue: false)
        let r = QCDPlanner.plan(plan,
            primaryRMD: 0, spouseRMD: 0, primaryIRA: 100_000, spouseIRA: 0,
            primaryEligible: true, spouseEligible: false,
            qcdLimit: 100_000, inflationFactor: 1.0)
        #expect(r.target == 10_000)
        #expect(r.total == 4_000)
        #expect(max(0, r.target - r.total) == 6_000)   // cash remainder
    }
}
