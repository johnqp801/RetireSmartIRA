import Foundation

/// One overridable input for one year. `recurringLevel` is a step-change to the recurring baseline
/// effective this year onward (CPI-grown from here until a later recurring anchor); `oneTimeAmount`
/// is an additive adjustment for this year only (may be negative). nil = "not overridden".
struct FieldOverride: Codable, Equatable, Sendable {
    var recurringLevel: Double?
    var oneTimeAmount: Double?

    var isEmpty: Bool { recurringLevel == nil && oneTimeAmount == nil }
    /// nil when empty, else self — so empty records are never stored.
    var pruned: FieldOverride? { isEmpty ? nil : self }
}

/// All per-year input overrides for one year. 2.1.2 wires `livingExpenses`; income/withdrawal
/// fields are added here later without restructuring.
struct YearOverride: Codable, Equatable, Sendable {
    var livingExpenses: FieldOverride?

    var isEmpty: Bool { (livingExpenses?.pruned) == nil }
    var pruned: YearOverride? {
        let le = livingExpenses?.pruned
        return le == nil ? nil : YearOverride(livingExpenses: le)
    }
}

extension Dictionary where Key == Int, Value == YearOverride {
    /// Drops empty year entries so the map never carries dead keys (badges read real values).
    func pruned() -> [Int: YearOverride] {
        reduce(into: [:]) { acc, kv in if let p = kv.value.pruned { acc[kv.key] = p } }
    }
}
