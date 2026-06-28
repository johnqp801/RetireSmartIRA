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

    /// Off-plan status for the Year-1 editor. The only lever the user controls on this tab is the
    /// Year-1 conversion, so they are ON PLAN once their Year-1 amount matches the engine's optimal
    /// Year-1 amount. We do NOT classify directly off the whole-path lifetime-tax delta: the
    /// optimizer is path-dependent under pinning (pinning even the OPTIMAL Year-1 still yields a
    /// slightly worse years-2+ path than the free optimum), so the residual gap is not user-fixable
    /// and must not read as "off plan." When the Year-1 amounts genuinely differ, classify by the
    /// lifetime-tax delta.
    static func forYear1(userYear1: Double,
                         optimalYear1: Double,
                         currentLifetimeTax: Double,
                         optimalLifetimeTax: Double,
                         matchThreshold: Double = 1_000) -> OffPlanStatus {
        if abs(userYear1 - optimalYear1) < matchThreshold { return .onPlan }
        return OffPlanStatus(extraLifetimeTax: currentLifetimeTax - optimalLifetimeTax)
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
