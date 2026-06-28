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

    init(result: HeirFrontierResult, selectedWeight: Double, units: DisplayUnits) {
        self.points = result.points.map { fp in
            Point(id: fp.weight, weight: fp.weight,
                  ownerTax: fp.ownerLifetimeTax(units: units),
                  heirsKeep: fp.heirAfterTaxInheritance(units: units),
                  isSelected: fp.weight == selectedWeight)
        }
    }
}
