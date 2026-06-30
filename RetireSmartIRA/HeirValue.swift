import Foundation

/// After-tax value passing to heirs under current law. Pure, shared by the heir frontier
/// (HeirFrontierCoordinator) and the plan-vs-doing-nothing comparison (PlanComparison) so the two
/// on-screen "what heirs keep" figures use ONE formula.
///
/// Components:
///  - Roth: inherited tax-free.
///  - Traditional: taxable to heirs over the inherited-IRA drawdown; we subtract the heir's tax.
///  - Taxable brokerage: receives a stepped-up cost basis at death, so it passes near tax-free.
///    V2.0 simplification: full step-up, no lifetime-realization tax modeled (see V2Disclosures).
enum HeirValue {
    static func afterTaxToHeirs(
        roth: Double, traditional: Double, taxable: Double, heirTaxOnTraditional: Double
    ) -> Double {
        roth + (traditional - heirTaxOnTraditional) + taxable
    }
}
