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
        #expect(c.endingRoth.plan == 200_000)
        #expect(c.endingRoth.doingNothing == 0)

        let planHeirTax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
            balance: 400_000, heirSalary: 75_000, heirFilingStatus: .single, drawdownYears: 10)
        #expect(abs(c.heirsKeep.plan - (200_000 + (400_000 - planHeirTax))) < 1.0)
    }

    @Test("present-value mode discounts lifetime tax and terminal metrics, not peak RMD")
    func presentValue() {
        let plan = [
            yr(2026, tax: 100_000, trad: 800_000, roth: 100_000, rmd: 10_000),
            yr(2027, tax: 100_000, trad: 400_000, roth: 200_000, rmd: 20_000),
        ]
        let nothing = [
            yr(2026, tax: 40_000, trad: 1_500_000, roth: 0, rmd: 30_000),
            yr(2027, tax: 50_000, trad: 1_800_000, roth: 0, rmd: 90_000),
        ]
        let c = PlanComparison(plan: plan, doingNothing: nothing,
                               heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10,
                               pvRealDiscountRate: 0.03)
        // terminal year is 2027, base year 2026 → one year of discounting
        #expect(abs(c.terminalPVFactor - 1.0 / 1.03) < 1e-9)
        // lifetime tax PV: year-0 undiscounted + year-1 discounted
        #expect(abs(c.lifetimeTaxPV.plan - (100_000 + 100_000 / 1.03)) < 0.01)
        #expect(c.lifetimeTaxPV.plan < c.lifetimeTax.plan)
        // terminal() discounts in PV mode, passes through in todaysDollars
        #expect(abs(c.terminal(c.endingRoth, units: .presentValue).plan - c.endingRoth.plan / 1.03) < 0.01)
        #expect(c.terminal(c.endingRoth, units: .todaysDollars).plan == c.endingRoth.plan)
        // lifetimeTax(units:) selects the PV pair in present-value mode
        #expect(c.lifetimeTax(units: .presentValue).plan == c.lifetimeTaxPV.plan)
        #expect(c.lifetimeTax(units: .todaysDollars).plan == c.lifetimeTax.plan)
    }

    @Test("default (no discount rate) leaves PV equal to nominal")
    func noDiscountIsNominal() {
        let plan = [yr(2026, tax: 100_000, trad: 400_000, roth: 200_000, rmd: 20_000)]
        let c = PlanComparison(plan: plan, doingNothing: [],
                               heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
        #expect(c.terminalPVFactor == 1.0)
        #expect(c.lifetimeTaxPV.plan == c.lifetimeTax.plan)
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
