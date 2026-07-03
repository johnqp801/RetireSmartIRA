import Foundation

extension WithdrawalOrderingRule {
    /// Human-readable label for the withdrawal-ordering preset shown in the advanced sheet.
    var displayName: String {
        switch self {
        case .taxEfficient:    return "Tax-efficient"
        case .depleteTradFirst: return "Traditional first"
        case .preserveRoth:    return "Preserve Roth"
        case .proportional:    return "Proportional"
        }
    }
}
