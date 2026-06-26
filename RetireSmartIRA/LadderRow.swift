import Foundation

/// Testable display model for one year of the recommended ladder.
struct LadderRow: Identifiable, Equatable, Sendable {
    var id: Int { year }
    let year: Int
    let conversion: Double
    let agi: Double
    let hasIRMAASurcharge: Bool

    init(_ rec: YearRecommendation) {
        self.year = rec.year
        self.conversion = rec.actions.reduce(0.0) { acc, act in
            if case let .rothConversion(amount) = act { return acc + amount }
            return acc
        }
        self.agi = rec.agi
        self.hasIRMAASurcharge = rec.taxBreakdown.irmaa > 0
    }

    var conversionLabel: String { conversion > 0 ? "convert \(PlanSummary.shortDollars(conversion))" : "—" }
    var agiLabel: String { "AGI \(PlanSummary.shortDollars(agi))" }
}
