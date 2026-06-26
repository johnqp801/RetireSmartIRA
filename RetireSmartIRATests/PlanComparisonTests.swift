import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("PlanComparison")
struct PlanComparisonTests {
    private func breakdown(total: Double) -> TaxBreakdown {
        TaxBreakdown(federal: total, state: 0, irmaa: 0, acaPremiumImpact: 0)
    }
    private func snapshot(trad: Double, roth: Double) -> AccountSnapshot {
        AccountSnapshot(primaryTraditional: trad, spouseTraditional: 0, roth: roth, taxable: 0, hsa: 0)
    }
    private func yr(_ year: Int, tax: Double, trad: Double, roth: Double, rmd: Double) -> YearRecommendation {
        YearRecommendation(
            year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: breakdown(total: tax), endOfYearBalances: snapshot(trad: trad, roth: roth),
            actions: [], rmd: rmd)
    }

    @Test("derives the four metric pairs from plan and baseline")
    func metrics() {
        let plan = [
            yr(2026, tax: 100_000, trad: 800_000, roth: 100_000, rmd: 10_000),
            yr(2027, tax: 100_000, trad: 400_000, roth: 200_000, rmd: 20_000),
        ]
        let nothing = [
            yr(2026, tax: 40_000, trad: 1_500_000, roth: 0, rmd: 30_000),
            yr(2027, tax: 50_000, trad: 1_800_000, roth: 0, rmd: 90_000),
        ]
        let c = PlanComparison(plan: plan, doingNothing: nothing,
                               heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)

        #expect(c.lifetimeTax.plan == 200_000)
        #expect(c.lifetimeTax.doingNothing == 90_000)
        #expect(c.endingTraditional.plan == 400_000)
        #expect(c.endingTraditional.doingNothing == 1_800_000)
        #expect(c.peakForcedRMD.plan == 20_000)
        #expect(c.peakForcedRMD.doingNothing == 90_000)

        let planHeirTax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
            balance: 400_000, heirSalary: 75_000, heirFilingStatus: .single, drawdownYears: 10)
        #expect(abs(c.heirsKeep.plan - (200_000 + (400_000 - planHeirTax))) < 1.0)
    }

    @Test("empty paths yield zero pairs")
    func emptyPaths() {
        let c = PlanComparison(plan: [], doingNothing: [],
                               heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
        #expect(c.lifetimeTax.plan == 0)
        #expect(c.endingTraditional.doingNothing == 0)
        #expect(c.peakForcedRMD.plan == 0)
    }
}
