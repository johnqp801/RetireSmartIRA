import Foundation

/// Testable macro-summary of a recommended multi-year path. Pure value type — the view formats it.
struct PlanSummary: Equatable, Sendable {
    let lifetimeTax: Double      // sum of in-horizon federal+state+IRMAA+ACA across the path
    let totalConversions: Double // sum of recommended Roth conversions
    let conversionYears: Int     // count of years with a conversion

    init(path: [YearRecommendation]) {
        self.lifetimeTax = path.reduce(0) { $0 + $1.taxBreakdown.total }
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

    /// One-line plain-language headline.
    var headline: String {
        guard totalConversions > 0 else { return "No Roth conversions recommended under these assumptions." }
        return "Convert \(Self.shortDollars(totalConversions)) over \(conversionYears) year\(conversionYears == 1 ? "" : "s")."
    }

    static func shortDollars(_ v: Double) -> String { "$\(Int((v / 1000).rounded()))k" }
}
