//
//  ACACliffIndicator.swift
//  RetireSmartIRA
//
//  Live ACA cliff indicator for the Roth conversion slider area.
//  Shows headroom to the cliff with green/yellow/red/crossed visual states.
//  Per Ron Park beta feedback (Item #10 in 1.8.1 spec).
//

import SwiftUI

enum ACACliffHeadroomState: Equatable {
    case green       // > $20K headroom — clear of cliff
    case yellow      // > $5K and ≤ $20K — approaching
    case red         // 0 to $5K — within buffer
    case crossed     // < $0 — over the cliff

    var color: Color {
        switch self {
        case .green: return .green
        case .yellow: return .orange
        case .red: return .red
        case .crossed: return .red
        }
    }

    var label: String {
        switch self {
        case .green: return "Clear of cliff"
        case .yellow: return "Approaching cliff"
        case .red: return "Near cliff"
        case .crossed: return "Cliff crossed"
        }
    }
}

struct ACACliffIndicator: View {
    let cliffThreshold: Double
    let projectedMAGI: Double
    let lostSubsidyEstimate: Double

    private var headroom: Double {
        cliffThreshold - projectedMAGI
    }

    private var state: ACACliffHeadroomState {
        Self.headroomState(headroom: headroom)
    }

    static func headroomState(headroom: Double) -> ACACliffHeadroomState {
        if headroom < 0 { return .crossed }
        if headroom <= 5_000 { return .red }
        if headroom <= 20_000 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(state.color)
                    .frame(width: 8, height: 8)
                Text(state.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state.color)
                Spacer()
            }

            HStack {
                Text("ACA cliff: \(formatDollars(cliffThreshold))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(headroomLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(state.color)
                    .monospacedDigit()
            }

            if state == .crossed {
                Text("⚠ ACA subsidy lost — costs ~\(formatDollars(lostSubsidyEstimate))/yr")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.top, 2)
            }
        }
        .padding(8)
        .background(state.color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(state.color.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var headroomLabel: String {
        if state == .crossed {
            return "Over by \(formatDollars(abs(headroom)))"
        } else {
            return "Headroom: \(formatDollars(headroom))"
        }
    }

    private func formatDollars(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if absValue >= 1_000 {
            return String(format: "$%.0fK", value / 1_000)
        } else {
            return String(format: "$%.0f", value)
        }
    }
}
