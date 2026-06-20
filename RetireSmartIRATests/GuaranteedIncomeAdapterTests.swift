import Testing
@testable import RetireSmartIRA

@Suite("GuaranteedIncomeAdapter")
struct GuaranteedIncomeAdapterTests {
    @Test("SS starts at claiming age, inflated")
    func ssStartsAtClaimingAge_inflated() {
        // primary age 64, claims SS at 67 (3 years out), annual SS 30,000 (today's $),
        // no spouse, no pension, 0% inflation. Offsets: 0,0,0,30000,30000.
        let sched = GuaranteedIncomeAdapter.schedule(
            primaryCurrentAge: 64, primarySSClaimAge: 67, primaryAnnualSS: 30_000,
            spouseCurrentAge: nil, spouseSSClaimAge: nil, spouseAnnualSS: 0,
            annualPensionFromStart: 0, inflationRatePercent: 0, horizonYears: 5)
        #expect(sched.annualByYearOffset == [0, 0, 0, 30_000, 30_000])
    }

    @Test("pension active from start, with inflation")
    func pensionActiveFromStart_andInflation() {
        let sched = GuaranteedIncomeAdapter.schedule(
            primaryCurrentAge: 66, primarySSClaimAge: 66, primaryAnnualSS: 0,
            spouseCurrentAge: nil, spouseSSClaimAge: nil, spouseAnnualSS: 0,
            annualPensionFromStart: 20_000, inflationRatePercent: 10, horizonYears: 2)
        // year 0: 20,000 ; year 1: 20,000 * 1.10 = 22,000 (allow float tolerance)
        #expect(abs(sched.annualByYearOffset[0] - 20_000) < 0.01)
        #expect(abs(sched.annualByYearOffset[1] - 22_000) < 0.01)
    }
}
