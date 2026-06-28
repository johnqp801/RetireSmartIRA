import Foundation

/// How far the user's current plan sits from the engine-optimal plan, measured by extra projected
/// lifetime tax (current minus optimal). Pure value type; the view maps `severity` to a color.
/// Year-1 Roth is the only lever the v2.0 optimizer honors, so this reflects the cost of the user's
/// Year-1 choice versus the optimizer's free pick.
enum OffPlanStatus: Equatable {
    case onPlan
    case nearOptimal
    case offPlan
    case significantlyOffPlan

    enum Severity { case good, caution, warning }

    /// `extraLifetimeTax` = current plan lifetime tax minus engine-optimal lifetime tax.
    /// Values at or below 0 (current no worse than optimal) read as on plan.
    init(extraLifetimeTax: Double) {
        switch extraLifetimeTax {
        case ..<1_000:   self = .onPlan
        case ..<10_000:  self = .nearOptimal
        case ..<25_000:  self = .offPlan
        default:         self = .significantlyOffPlan
        }
    }

    var isOnPlan: Bool { self == .onPlan }

    var label: String {
        switch self {
        case .onPlan:               return "On plan"
        case .nearOptimal:          return "Near optimal"
        case .offPlan:              return "Off plan"
        case .significantlyOffPlan: return "Significantly off plan"
        }
    }

    var caption: String {
        switch self {
        case .onPlan:
            return "Your Year-1 choice matches the optimized plan."
        case .nearOptimal:
            return "Your Year-1 choice costs a little more lifetime tax than the optimized plan."
        case .offPlan:
            return "Your Year-1 choice costs noticeably more lifetime tax than the optimized plan."
        case .significantlyOffPlan:
            return "Your Year-1 choice costs much more lifetime tax than the optimized plan."
        }
    }

    var severity: Severity {
        switch self {
        case .onPlan:               return .good
        case .nearOptimal:          return .caution
        case .offPlan, .significantlyOffPlan: return .warning
        }
    }
}
