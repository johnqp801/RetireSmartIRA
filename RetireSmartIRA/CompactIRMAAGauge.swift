//
//  CompactIRMAAGauge.swift
//  RetireSmartIRA
//

import SwiftUI

struct CompactIRMAAGauge: View {
    let currentTier: Int      // 0 = Clear, 1..5 = Tiers
    let cushionToNextTierK: Int?

    private let labels = ["Clear", "T1", "T2", "T3", "T4", "T5"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("IRMAA tier")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(currentTier >= 4 ? .orange : .secondary)
            }

            HStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle()
                        .fill(tierColor(i))
                        .overlay(
                            Rectangle()
                                .stroke(Color.blue, lineWidth: i == currentTier ? 2 : 0)
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            HStack(spacing: 2) {
                ForEach(0..<labels.count, id: \.self) { i in
                    Text(labels[i])
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var statusText: String {
        if currentTier == 0 { return "Clear" }
        if let cushion = cushionToNextTierK {
            return "⚠ T\(currentTier) · $\(cushion)K cushion"
        }
        return "⚠ T\(currentTier)"
    }

    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 0: return Color(red: 0.64, green: 0.85, blue: 0.64)
        case 1: return Color(red: 0.86, green: 0.91, blue: 0.86)
        case 2: return Color(red: 0.96, green: 0.84, blue: 0.53)
        case 3: return Color(red: 0.96, green: 0.70, blue: 0.43)
        case 4: return Color(red: 0.94, green: 0.55, blue: 0.30)
        default: return Color(red: 0.84, green: 0.36, blue: 0.36)
        }
    }
}
