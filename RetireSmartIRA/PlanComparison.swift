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
    let endingTaxable: Pair      // after-tax money; the plan shifts this into Roth vs. doing nothing
    /// After-tax inheritance = ending Roth + (ending traditional - heir income tax) + ending taxable.
    /// The taxable account receives a stepped-up cost basis at death, so it passes to heirs near
    /// tax-free; it is credited in full here (see HeirValue / V2Disclosures for the simplification).
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

        // Per-year discounted lifetime tax (each year discounted to the base year).
        let baseYear = plan.first?.year ?? doingNothing.first?.year ?? 0
        let lastYear = plan.last?.year ?? doingNothing.last?.year ?? baseYear

        self.lifetimeTax = Pair(plan: PlanPathMetrics.lifetimeTax(plan),
                                doingNothing: PlanPathMetrics.lifetimeTax(doingNothing))
        self.endingTraditional = Pair(plan: PlanPathMetrics.endingTraditional(plan),
                                      doingNothing: PlanPathMetrics.endingTraditional(doingNothing))
        self.endingRoth = Pair(plan: PlanPathMetrics.endingRoth(plan),
                               doingNothing: PlanPathMetrics.endingRoth(doingNothing))
        self.endingTaxable = Pair(plan: PlanPathMetrics.endingTaxable(plan),
                                  doingNothing: PlanPathMetrics.endingTaxable(doingNothing))
        self.heirsKeep = Pair(plan: PlanPathMetrics.heirsKeep(plan, heirSalary: heirSalary,
                                                              heirFilingStatus: heirFilingStatus,
                                                              heirDrawdownYears: heirDrawdownYears),
                              doingNothing: PlanPathMetrics.heirsKeep(doingNothing, heirSalary: heirSalary,
                                                                      heirFilingStatus: heirFilingStatus,
                                                                      heirDrawdownYears: heirDrawdownYears))
        self.peakForcedRMD = Pair(plan: PlanPathMetrics.peakForcedRMD(plan),
                                  doingNothing: PlanPathMetrics.peakForcedRMD(doingNothing))
        self.lifetimeTaxPV = Pair(plan: PlanPathMetrics.lifetimeTaxPV(plan, baseYear: baseYear,
                                                                      cpiRate: cpiRate, pvRealDiscountRate: pvRealDiscountRate),
                                  doingNothing: PlanPathMetrics.lifetimeTaxPV(doingNothing, baseYear: baseYear,
                                                                             cpiRate: cpiRate, pvRealDiscountRate: pvRealDiscountRate))
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
        return "Under these assumptions, this plan saves \(PlanSummary.shortDollars(savings)) in lifetime tax and holds your largest forced RMD to \(rmd)."
    }
}
