import Foundation

/// Testable "your plan vs. doing nothing" comparison for the Multi-Year Plan tab.
/// Pure value type -- the view formats it. "doingNothing" is the engine's no-conversion baseline.
struct PlanComparison: Equatable, Sendable {

    /// One metric under both paths. Display orientation (lower-is-better vs higher-is-better)
    /// is the view's concern; this type only carries the two values.
    struct Pair: Equatable, Sendable {
        let plan: Double
        let doingNothing: Double
    }

    let lifetimeTax: Pair        // lower is better
    let endingTraditional: Pair  // lower is better (defused RMD bomb)
    let endingRoth: Pair         // higher is better (value shifted into tax-free Roth)
    let heirsKeep: Pair          // higher is better
    let peakForcedRMD: Pair      // lower is better

    init(plan: [YearRecommendation],
         doingNothing: [YearRecommendation],
         heirSalary: Double,
         heirFilingStatus: FilingStatus,
         heirDrawdownYears: Int) {

        func lifetimeTax(_ p: [YearRecommendation]) -> Double {
            p.reduce(0) { $0 + $1.taxBreakdown.total }
        }
        func endingTrad(_ p: [YearRecommendation]) -> Double {
            guard let last = p.last else { return 0 }
            return last.endOfYearBalances.primaryTraditional + last.endOfYearBalances.spouseTraditional
        }
        func endingRoth(_ p: [YearRecommendation]) -> Double { p.last?.endOfYearBalances.roth ?? 0 }
        func heirsKeep(_ p: [YearRecommendation]) -> Double {
            let trad = endingTrad(p)
            let heirTax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
                balance: trad, heirSalary: heirSalary,
                heirFilingStatus: heirFilingStatus, drawdownYears: heirDrawdownYears)
            return endingRoth(p) + (trad - heirTax)
        }
        func peakRMD(_ p: [YearRecommendation]) -> Double { p.map(\.rmd).max() ?? 0 }

        self.lifetimeTax = Pair(plan: lifetimeTax(plan), doingNothing: lifetimeTax(doingNothing))
        self.endingTraditional = Pair(plan: endingTrad(plan), doingNothing: endingTrad(doingNothing))
        self.endingRoth = Pair(plan: endingRoth(plan), doingNothing: endingRoth(doingNothing))
        self.heirsKeep = Pair(plan: heirsKeep(plan), doingNothing: heirsKeep(doingNothing))
        self.peakForcedRMD = Pair(plan: peakRMD(plan), doingNothing: peakRMD(doingNothing))
    }

    /// Lifetime-tax reduction vs doing nothing (positive = plan saves money).
    var lifetimeTaxSavings: Double { lifetimeTax.doingNothing - lifetimeTax.plan }

    /// One-line plain-language headline. Uses the existing compact-dollar formatter.
    var headline: String {
        guard lifetimeTaxSavings > 1_000 else {
            return "This plan comes out about even with doing nothing here."
        }
        return "This plan saves \(PlanSummary.shortDollars(lifetimeTaxSavings)) in lifetime tax and holds your largest forced RMD to \(PlanSummary.shortDollars(peakForcedRMD.plan))."
    }
}
