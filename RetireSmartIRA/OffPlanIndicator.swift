//
//  OffPlanIndicator.swift
//  RetireSmartIRA

import SwiftUI

struct OffPlanIndicator: View {

    enum PlanState {
        case onPlan
        case nearOptimal(deltaDollars: Double)
        case offPlan(deltaDollars: Double)
        case significantlyOffPlan(deltaDollars: Double)
    }

    let state: PlanState
    let useNeutralFraming: Bool
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(textColor)

            if showsResetLink {
                Button("Reset", action: onReset)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
            }

            if showsSeeEnginePlanLink {
                Button("See engine's plan", action: onReset)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(backgroundColor)
        .cornerRadius(6)
    }

    private var iconName: String {
        switch state {
        case .onPlan, .nearOptimal: return "checkmark.circle.fill"
        case .offPlan, .significantlyOffPlan: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .onPlan, .nearOptimal: return .green
        case .offPlan: return .orange
        case .significantlyOffPlan: return .red
        }
    }

    private var textColor: Color { iconColor }

    private var backgroundColor: Color {
        switch state {
        case .onPlan, .nearOptimal: return .green.opacity(0.10)
        case .offPlan: return .orange.opacity(0.10)
        case .significantlyOffPlan: return .red.opacity(0.10)
        }
    }

    private var label: String {
        if useNeutralFraming {
            switch state {
            case .offPlan, .significantlyOffPlan:
                return "Different from engine"
            default: break
            }
        }
        switch state {
        case .onPlan: return "On plan"
        case .nearOptimal(let delta): return "Near optimal (\(formatDelta(delta)))"
        case .offPlan(let delta): return "Off plan: \(formatDelta(delta))"
        case .significantlyOffPlan(let delta): return "Significantly off plan: \(formatDelta(delta))"
        }
    }

    private var showsResetLink: Bool {
        guard !useNeutralFraming else { return false }
        switch state {
        case .offPlan, .significantlyOffPlan: return true
        default: return false
        }
    }

    private var showsSeeEnginePlanLink: Bool {
        guard useNeutralFraming else { return false }
        switch state {
        case .offPlan, .significantlyOffPlan: return true
        default: return false
        }
    }

    private func formatDelta(_ d: Double) -> String {
        let sign = d < 0 ? "-" : "+"
        let absVal = Int(d.magnitude.rounded())
        return "\(sign)$\(absVal.formatted(.number))"
    }
}

extension OffPlanIndicator.PlanState {
    static func fromDelta(_ delta: Double, thresholds: Thresholds = .default) -> Self {
        let absVal = delta.magnitude
        if absVal < thresholds.nearOptimal {
            return delta == 0 ? .onPlan : .nearOptimal(deltaDollars: -delta)
        }
        if absVal < thresholds.major {
            return .offPlan(deltaDollars: -delta)
        }
        return .significantlyOffPlan(deltaDollars: -delta)
    }

    struct Thresholds {
        let nearOptimal: Double
        let major: Double
        static let `default` = Thresholds(nearOptimal: 1_000, major: 25_000)
    }
}
