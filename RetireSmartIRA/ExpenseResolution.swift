import Foundation

/// Resolves a year's nominal living expense from the baseline + per-year overrides.
/// expense(Y) = max(0, recurringBaseline(Y) + oneTime(Y)), where recurringBaseline(Y) is the latest
/// `recurringLevel` anchor at/before Y grown by CPI from its year (else the original baseline from
/// baseYear), and oneTime(Y) is this year's additive adjustment (may be negative).
enum ExpenseResolution {
    static func expense(year: Int, baseYear: Int, baselineAnnualExpenses: Double,
                        cpiRate: Double, overrides: [Int: YearOverride]) -> Double {
        // Latest recurring anchor at or before `year`.
        let anchors = overrides
            .compactMap { (k, v) -> (Int, Double)? in
                guard k <= year, let lvl = v.livingExpenses?.recurringLevel else { return nil }
                return (k, lvl)
            }
            .sorted { $0.0 < $1.0 }
        let (anchorYear, anchorValue) = anchors.last ?? (baseYear, baselineAnnualExpenses)
        let recurring = anchorValue * pow(1 + cpiRate, Double(max(0, year - anchorYear)))
        let oneTime = overrides[year]?.livingExpenses?.oneTimeAmount ?? 0
        return max(0, recurring + oneTime)
    }
}
