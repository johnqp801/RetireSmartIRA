import Foundation

/// Pure model for the owner-vs-heirs trade-off curve. Honors the display-units toggle via the
/// FrontierPoint unit accessors (display-only re-expression, never a re-optimization).
struct HeirFrontierChart: Equatable, Sendable {
    struct Point: Identifiable, Equatable, Sendable {
        let id: Double
        let weight: Double
        let ownerTax: Double
        let heirsKeep: Double
        let isSelected: Bool
    }
    let points: [Point]

    /// True when the owner-tax or heir-inheritance spread across the plotted points exceeds the
    /// materiality threshold. Mirrors the flat-frontier collapse the view and presentation use, so
    /// the chart, its caption, and the commentary all agree on when there is a trade-off to describe.
    var hasMaterialTradeoff: Bool {
        let taxes = points.map(\.ownerTax)
        let heirs = points.map(\.heirsKeep)
        let taxSpread = (taxes.max() ?? 0) - (taxes.min() ?? 0)
        let heirSpread = (heirs.max() ?? 0) - (heirs.min() ?? 0)
        return taxSpread >= HeirFrontierPresentation.materialThreshold
            || heirSpread >= HeirFrontierPresentation.materialThreshold
    }

    init(result: HeirFrontierResult, selectedWeight: Double, units: DisplayUnits) {
        self.points = result.points.map { fp in
            Point(id: fp.weight, weight: fp.weight,
                  ownerTax: fp.ownerLifetimeTax(units: units),
                  heirsKeep: fp.heirAfterTaxInheritance(units: units),
                  isSelected: fp.weight == selectedWeight)
        }
    }
}
