import Foundation

/// Testable display model for one year of the recommended ladder.
struct LadderRow: Identifiable, Equatable, Sendable {
    var id: Int { year }
    let year: Int
    let conversion: Double
    let agi: Double
    let irmaaSurcharge: Double   // this year's projected Medicare IRMAA cost (both spouses, annual)

    init(_ rec: YearRecommendation) {
        self.year = rec.year
        self.conversion = rec.actions.reduce(0.0) { acc, act in
            if case let .rothConversion(amount) = act { return acc + amount }
            return acc
        }
        self.agi = rec.agi
        self.irmaaSurcharge = rec.taxBreakdown.irmaa
    }

    var hasIRMAASurcharge: Bool { irmaaSurcharge > 0 }

    var conversionLabel: String { conversion > 0 ? "convert \(PlanSummary.shortDollars(conversion))" : "—" }
    var agiLabel: String { "AGI \(PlanSummary.shortDollars(agi))" }
    /// Compact "IRMAA +$Xk" tag for the year, empty when there is no surcharge.
    var irmaaLabel: String { hasIRMAASurcharge ? "IRMAA +\(PlanSummary.shortDollars(irmaaSurcharge))" : "" }
}
