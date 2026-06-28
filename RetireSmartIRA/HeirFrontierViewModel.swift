import Foundation

/// Testable readout logic for the heir-frontier section (no SwiftUI).
struct HeirFrontierViewModel {
    let baseline: FrontierPoint
    let selected: FrontierPoint
    let units: DisplayUnits

    var ownerTaxDelta: Double {
        selected.ownerLifetimeTax(units: units) - baseline.ownerLifetimeTax(units: units)
    }
    var heirInheritanceDelta: Double {
        selected.heirAfterTaxInheritance(units: units) - baseline.heirAfterTaxInheritance(units: units)
    }
    var readoutText: String {
        let tax = PlanSummary.shortDollars(abs(ownerTaxDelta))
        let heir = PlanSummary.shortDollars(abs(heirInheritanceDelta))
        if selected.weight == baseline.weight {
            return "This is the plan optimized for your own lifetime tax."
        }
        return "Compared with planning only for yourself, this costs you \(tax) more in lifetime tax and leaves your heirs \(heir) more."
    }
}
