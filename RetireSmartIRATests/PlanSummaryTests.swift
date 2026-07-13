import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("PlanSummary", .serialized)
struct PlanSummaryTests {
    private func rec(year: Int, fed: Double, conv: Double) -> YearRecommendation {
        YearRecommendation(
            year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: TaxBreakdown(federal: fed, state: 0, irmaa: 0, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: conv > 0 ? [.rothConversion(amount: conv)] : [],
            medicareEnrolledCount: 0, executedRothConversion: conv)
    }

    @Test("sums lifetime tax and total conversions over the path")
    func sums() {
        let path = [rec(year: 2026, fed: 10_000, conv: 50_000),
                    rec(year: 2027, fed: 12_000, conv: 30_000),
                    rec(year: 2028, fed: 8_000, conv: 0)]
        let s = PlanSummary(path: path)
        #expect(s.lifetimeTax == 30_000)
        #expect(s.totalConversions == 80_000)
        #expect(s.conversionYears == 2)
    }

    @Test("empty path is all zeros")
    func empty() {
        let s = PlanSummary(path: [])
        #expect(s.lifetimeTax == 0 && s.totalConversions == 0 && s.conversionYears == 0)
    }

    @Test("shortDollars scales to millions instead of '$12641k'")
    func shortDollarsScales() {
        #expect(PlanSummary.shortDollars(12_641_000) == "$12.6M")
        #expect(PlanSummary.shortDollars(4_314_000) == "$4.3M")
        #expect(PlanSummary.shortDollars(1_000_000) == "$1.0M")
        #expect(PlanSummary.shortDollars(148_000) == "$148k")
        #expect(PlanSummary.shortDollars(26_000) == "$26k")
        #expect(PlanSummary.shortDollars(500) == "$500")
        #expect(PlanSummary.shortDollars(0) == "$0")
    }
}
