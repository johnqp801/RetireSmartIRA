//
//  InsightCalloutBanner.swift
//  RetireSmartIRA

import SwiftUI

struct InsightCalloutBanner: View {
    let title: String
    let message: String
    let primaryActionLabel: String?
    let onPrimaryAction: (() -> Void)?
    let onDismiss: () -> Void
    let impact: Impact

    enum Impact { case minor, moderate, major }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.orange)
                .font(impactFont)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(impactTitleFont)
                Text(message).font(.caption).foregroundColor(.secondary)
                if let label = primaryActionLabel, let action = onPrimaryAction {
                    Button(label, action: action)
                        .font(.caption.weight(.semibold))
                        .padding(.top, 2)
                }
            }
            Spacer()
            Button(action: onDismiss) {
                if impact == .major {
                    Text("Dismiss").font(.caption2.weight(.semibold))
                } else {
                    Image(systemName: "xmark").font(.caption2)
                }
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(impactPadding)
        .background(Color.yellow.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
        .cornerRadius(8)
    }

    private var impactFont: Font {
        switch impact {
        case .minor: return .body
        case .moderate: return .title3
        case .major: return .title2
        }
    }

    private var impactTitleFont: Font {
        switch impact {
        case .minor: return .caption.weight(.semibold)
        case .moderate: return .subheadline.weight(.semibold)
        case .major: return .headline
        }
    }

    private var impactPadding: EdgeInsets {
        switch impact {
        case .minor: return EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        case .moderate: return EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        case .major: return EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        }
    }
}
