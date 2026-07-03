import Foundation

/// Testable macro-summary of a recommended multi-year path. Pure value type — the view formats it.
struct PlanSummary: Equatable, Sendable {
    let lifetimeTax: Double      // sum of in-horizon federal+state+IRMAA+ACA across the path (nominal)
    let lifetimeTaxPV: Double     // same, each year discounted to the base year
    let totalConversions: Double // sum of recommended Roth conversions (always nominal - a flow, not wealth)
    let conversionYears: Int     // count of years with a conversion

    init(path: [YearRecommendation], pvRealDiscountRate: Double = 0, cpiRate: Double = 0) {
        self.lifetimeTax = path.reduce(0) { $0 + $1.taxBreakdown.total }
        let baseYear = path.first?.year ?? 0
        self.lifetimeTaxPV = path.reduce(0) {
            $0 + EngineMath.realPresentValue($1.taxBreakdown.total,
                                             yearsFromBase: $1.year - baseYear,
                                             cpiRate: cpiRate, realDiscountRate: pvRealDiscountRate)
        }
        var total = 0.0, years = 0
        for yr in path {
            let conv = yr.actions.reduce(0.0) { acc, act in
                if case let .rothConversion(amount) = act { return acc + amount }
                return acc
            }
            if conv > 0 { total += conv; years += 1 }
        }
        self.totalConversions = total
        self.conversionYears = years
    }

    /// Lifetime tax for the chosen display units (per-year discounted in present-value mode).
    func lifetimeTax(units: DisplayUnits) -> Double {
        units == .presentValue ? lifetimeTaxPV : lifetimeTax
    }

    /// One-line plain-language headline.
    var headline: String {
        guard totalConversions > 0 else { return "No Roth conversions recommended under these assumptions." }
        return "Convert \(Self.shortDollars(totalConversions)) over \(conversionYears) year\(conversionYears == 1 ? "" : "s")."
    }

    /// Compact currency: "$1.2M" at/above a million, "$148k" at/above a thousand, else "$N".
    static func shortDollars(_ v: Double) -> String {
        let a = abs(v)
        let sign = v < 0 ? "-" : ""
        if a >= 1_000_000 {
            return "\(sign)$\(String(format: "%.1f", a / 1_000_000))M"
        }
        if a >= 1_000 {
            return "\(sign)$\(Int((a / 1_000).rounded()))k"
        }
        return "\(sign)$\(Int(a.rounded()))"
    }
}
