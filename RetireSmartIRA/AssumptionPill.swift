//
//  AssumptionPill.swift
//  RetireSmartIRA

import SwiftUI

struct AssumptionPill: View {
    let label: String
    let style: Style
    let action: () -> Void

    enum Style {
        case standard
        case featured     // distinct color (Heir Tax Rate)
        case toggleOn     // green stress-test
        case toggleOff
        case overflow     // "Advanced ⋯"
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(backgroundColor)
                .foregroundColor(textColor)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        switch style {
        case .standard, .toggleOff: return Color(.tertiarySystemFill)
        case .featured: return .blue.opacity(0.15)
        case .toggleOn: return .green
        case .overflow: return .clear
        }
    }

    private var textColor: Color {
        switch style {
        case .standard: return .primary
        case .featured: return .blue
        case .toggleOn: return .white
        case .toggleOff, .overflow: return .secondary
        }
    }
}
