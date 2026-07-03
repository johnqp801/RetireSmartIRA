import Foundation

/// Presentation model for the owner-vs-heirs frontier. Turns the optimizer's six weightings into
/// strategy-labeled rows with plain financial outcomes (lifetime tax paid, what heirs keep) and the
/// delta vs the owner-optimal plan, plus a factual dynamic headline and a "material tradeoff" flag
/// so a flat frontier collapses instead of showing identical rows / an empty chart.
///
/// Pure value type; honors the display-units toggle. Intentionally NOT advisory: it states the
/// exchange rate and lets the user judge, rather than declaring a strategy "worth it."
struct HeirFrontierPresentation: Equatable, Sendable {

    /// Two lifetime figures differ "materially" above this many dollars (filters rounding and the
    /// economically-flat frontier where every weighting yields the same outcome).
    static let materialThreshold: Double = 1_000

    struct Row: Identifiable, Equatable, Sendable {
        let id: Double
        let weight: Double
        let strategy: String
        let lifetimeTax: Double
        let heirsKeep: Double
        let taxDeltaVsOwner: Double
        let heirsDeltaVsOwner: Double
        let isBaseline: Bool
        let isSelected: Bool
        /// "Compared with optimize-for-you" phrase ("Baseline", "No material change", or
        /// "+$200k tax, +$200k to heirs"). Shown under each non-baseline strategy.
        let comparison: String
    }

    let rows: [Row]
    let headline: String
    let hasMaterialTradeoff: Bool

    init(result: HeirFrontierResult, selectedWeight: Double, units: DisplayUnits) {
        let pts = result.points
        guard let owner = result.baseline ?? pts.first else {
            rows = []; headline = ""; hasMaterialTradeoff = false; return
        }
        let baseTax = owner.ownerLifetimeTax(units: units)
        let baseHeirs = owner.heirAfterTaxInheritance(units: units)
        let T = Self.materialThreshold

        func strategyName(_ w: Double) -> String {
            if w <= 0 { return "Optimize for you" }
            if w >= 1 { return "Optimize for heirs" }
            if abs(w - 0.5) < 0.001 { return "Balanced" }
            return "\(Int((w * 100).rounded()))% toward heirs"
        }
        func signed(_ v: Double, suffix: String) -> String {
            (v >= 0 ? "+" : "") + PlanSummary.shortDollars(v) + " " + suffix
        }

        rows = pts.map { p in
            let tax = p.ownerLifetimeTax(units: units)
            let heirs = p.heirAfterTaxInheritance(units: units)
            let taxD = tax - baseTax
            let heirsD = heirs - baseHeirs
            let isBase = (p.weight == owner.weight)
            let comparison: String
            if isBase {
                comparison = "Baseline"
            } else if abs(taxD) < T && abs(heirsD) < T {
                comparison = "No material change"
            } else {
                comparison = "\(signed(taxD, suffix: "tax")), \(signed(heirsD, suffix: "to heirs"))"
            }
            return Row(id: p.weight, weight: p.weight, strategy: strategyName(p.weight),
                       lifetimeTax: tax, heirsKeep: heirs,
                       taxDeltaVsOwner: taxD, heirsDeltaVsOwner: heirsD,
                       isBaseline: isBase, isSelected: p.weight == selectedWeight,
                       comparison: comparison)
        }

        // Heir-optimal = the highest weight. Compare it to owner-optimal for the headline.
        let heirOpt = pts.max(by: { $0.weight < $1.weight }) ?? owner
        let extraTax = heirOpt.ownerLifetimeTax(units: units) - baseTax
        let extraHeirs = heirOpt.heirAfterTaxInheritance(units: units) - baseHeirs
        let material = abs(extraTax) >= T || abs(extraHeirs) >= T
        hasMaterialTradeoff = material

        if !material {
            headline = "No meaningful owner-vs-heir tradeoff at these assumptions. Your plan already passes about the same to your heirs either way."
        } else if extraHeirs >= T && extraTax >= T {
            let perDollar = String(format: "$%.2f", extraHeirs / extraTax)
            headline = "Leaning fully toward heirs leaves them about \(PlanSummary.shortDollars(extraHeirs)) more, at a lifetime-tax cost of about \(PlanSummary.shortDollars(extraTax)) (about \(perDollar) to heirs per $1 of extra tax)."
        } else if extraHeirs >= T {
            headline = "Leaning toward heirs leaves them about \(PlanSummary.shortDollars(extraHeirs)) more with little or no added lifetime tax."
        } else if extraTax >= T {
            headline = "Leaning toward heirs raises your lifetime tax by about \(PlanSummary.shortDollars(extraTax)) without materially increasing what your heirs keep."
        } else {
            headline = "Leaning toward heirs does not increase your heirs' after-tax inheritance at these assumptions."
        }
    }
}
