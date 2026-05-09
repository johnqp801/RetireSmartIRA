//
//  TabPurposeChip.swift
//  RetireSmartIRA
//
//  Status chip indicating whether a tab is for data entry ("Inputs")
//  or for results/analysis ("Analysis"). Per Ron Park beta feedback.
//

import SwiftUI

enum TabPurpose: Equatable {
    case inputs
    case analysis

    var label: String {
        switch self {
        case .inputs: return "Inputs"
        case .analysis: return "Analysis"
        }
    }

    var icon: String {
        switch self {
        case .inputs: return "square.and.pencil"
        case .analysis: return "chart.bar.doc.horizontal"
        }
    }

    var color: Color {
        switch self {
        case .inputs: return .blue
        case .analysis: return .green
        }
    }
}

struct TabPurposeChip: View {
    let purpose: TabPurpose

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: purpose.icon)
                .font(.caption2)
            Text(purpose.label)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(purpose.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(purpose.color.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(purpose.color.opacity(0.25), lineWidth: 0.5))
    }
}
