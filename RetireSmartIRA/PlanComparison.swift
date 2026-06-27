import Foundation

/// Testable "your plan vs. doing nothing" comparison for the Multi-Year Plan tab.
/// Pure value type -- the view formats it. "doingNothing" is the engine's no-conversion baseline.
struct PlanComparison: Equatable, Sendable {

    /// One metric under both paths. Display orientation (lower-is-better vs higher-is-better)
    /// is the view's concern; this type only carries the two values.
    struct Pair: Equatable, Sendable {
        let plan: Double
        let doingNothing: Double
        func scaled(by factor: Double) -> Pair {
            Pair(plan: plan * factor, doingNothing: doingNothing * factor)
        }
    }

    let lifetimeTax: Pair        // lower is better (nominal sum)
    let endingTraditional: Pair  // lower is better (defused RMD bomb)
    let endingRoth: Pair         // higher is better (value shifted into tax-free Roth)
    /// After-tax inheritance = ending Roth + (ending traditional - heir income tax).
    /// LIMITATION: excludes the taxable brokerage account, which also passes to heirs and
    /// receives a stepped-up cost basis (near tax-free to them). So a large taxable balance is
    /// UNDER-credited here. Mirrors HeirFrontierCoordinator's "heirs keep" for consistency.
    let heirsKeep: Pair          // higher is better
    let peakForcedRMD: Pair      // lower is better; ALWAYS nominal (a stress figure, not wealth)

    /// Lifetime tax with each year discounted to the base year. Use in present-value mode.
    let lifetimeTaxPV: Pair
    /// Discount factor from the horizon's terminal year back to the base year. Multiply the
    /// terminal-balance metrics (ending traditional, ending Roth, what heirs keep) by this for
    /// present-value mode. 1.0 when no discounting.
    let terminalPVFactor: Double

    init(plan: [YearRecommendation],
         doingNothing: [YearRecommendation],
         heirSalary: Double,
         heirFilingStatus: FilingStatus,
         heirDrawdownYears: Int,
         pvRealDiscountRate: Double = 0,
         cpiRate: Double = 0) {

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

        // Per-year discounted lifetime tax (each year discounted to the base year).
        let baseYear = plan.first?.year ?? doingNothing.first?.year ?? 0
        func lifetimeTaxPV(_ p: [YearRecommendation]) -> Double {
            p.reduce(0) {
                $0 + EngineMath.realPresentValue($1.taxBreakdown.total,
                                                 yearsFromBase: $1.year - baseYear,
                                                 cpiRate: cpiRate, realDiscountRate: pvRealDiscountRate)
            }
        }
        let lastYear = plan.last?.year ?? doingNothing.last?.year ?? baseYear

        self.lifetimeTax = Pair(plan: lifetimeTax(plan), doingNothing: lifetimeTax(doingNothing))
        self.endingTraditional = Pair(plan: endingTrad(plan), doingNothing: endingTrad(doingNothing))
        self.endingRoth = Pair(plan: endingRoth(plan), doingNothing: endingRoth(doingNothing))
        self.heirsKeep = Pair(plan: heirsKeep(plan), doingNothing: heirsKeep(doingNothing))
        self.peakForcedRMD = Pair(plan: peakRMD(plan), doingNothing: peakRMD(doingNothing))
        self.lifetimeTaxPV = Pair(plan: lifetimeTaxPV(plan), doingNothing: lifetimeTaxPV(doingNothing))
        self.terminalPVFactor = EngineMath.realPresentValue(1.0, yearsFromBase: lastYear - baseYear,
                                                            cpiRate: cpiRate, realDiscountRate: pvRealDiscountRate)
    }

    /// Lifetime tax for the chosen display units (per-year discounted in present-value mode).
    func lifetimeTax(units: DisplayUnits) -> Pair {
        units == .presentValue ? lifetimeTaxPV : lifetimeTax
    }
    /// A terminal-balance metric scaled for the chosen display units.
    func terminal(_ nominal: Pair, units: DisplayUnits) -> Pair {
        units == .presentValue ? nominal.scaled(by: terminalPVFactor) : nominal
    }

    /// One-line plain-language headline for the chosen units. Peak RMD stays nominal.
    func headline(units: DisplayUnits) -> String {
        let lt = lifetimeTax(units: units)
        let savings = lt.doingNothing - lt.plan
        guard savings > 1_000 else {
            return "This plan comes out about even with doing nothing here."
        }
        let rmd = PlanSummary.shortDollars(peakForcedRMD.plan) + (units == .presentValue ? " (nominal)" : "")
        return "This plan saves \(PlanSummary.shortDollars(savings)) in lifetime tax and holds your largest forced RMD to \(rmd)."
    }
}
