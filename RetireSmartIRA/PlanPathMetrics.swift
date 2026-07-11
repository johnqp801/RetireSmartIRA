import Foundation

/// Per-path metric derivations shared by PlanComparison (two-way) and ApproachComparison
/// (three-way). Pure functions over a projected [YearRecommendation]. Extracted so both
/// comparisons compute identical figures from identical code.
enum PlanPathMetrics {

    static func lifetimeTax(_ path: [YearRecommendation]) -> Double {
        path.reduce(0) { $0 + $1.taxBreakdown.total }
    }

    static func lifetimeTaxPV(_ path: [YearRecommendation], baseYear: Int,
                              cpiRate: Double, pvRealDiscountRate: Double) -> Double {
        path.reduce(0) {
            $0 + EngineMath.realPresentValue($1.taxBreakdown.total,
                                             yearsFromBase: $1.year - baseYear,
                                             cpiRate: cpiRate, realDiscountRate: pvRealDiscountRate)
        }
    }

    static func endingTraditional(_ path: [YearRecommendation]) -> Double {
        guard let last = path.last else { return 0 }
        return last.endOfYearBalances.primaryTraditional + last.endOfYearBalances.spouseTraditional
            + last.endOfYearBalances.inheritedTraditional
    }

    static func endingRoth(_ path: [YearRecommendation]) -> Double {
        guard let last = path.last else { return 0 }
        return last.endOfYearBalances.roth + last.endOfYearBalances.inheritedRoth
    }

    static func endingTaxable(_ path: [YearRecommendation]) -> Double {
        path.last?.endOfYearBalances.taxable ?? 0
    }

    static func peakForcedRMD(_ path: [YearRecommendation]) -> Double {
        path.map(\.rmd).max() ?? 0
    }

    /// Largest single-year total Roth conversion across the path (sum of `.rothConversion`
    /// actions within a year, maxed across years). Used for the CPA "Δ peak conversion" figure.
    static func peakAnnualRothConversion(_ path: [YearRecommendation]) -> Double {
        path.map { year in
            year.actions.reduce(0.0) { acc, action in
                if case .rothConversion(let amt) = action { return acc + amt } else { return acc }
            }
        }.max() ?? 0
    }

    static func heirsKeep(_ path: [YearRecommendation], heirSalary: Double,
                          heirFilingStatus: FilingStatus, heirDrawdownYears: Int) -> Double {
        let trad = endingTraditional(path)
        let heirTax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
            balance: trad, heirSalary: heirSalary,
            heirFilingStatus: heirFilingStatus, drawdownYears: heirDrawdownYears)
        return HeirValue.afterTaxToHeirs(
            roth: endingRoth(path), traditional: trad,
            taxable: endingTaxable(path), heirTaxOnTraditional: heirTax)
    }
}
