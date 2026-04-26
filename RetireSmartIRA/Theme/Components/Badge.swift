import SwiftUI

/// Small inline category label. NOT a true pill — see `Radius.capsule` for that.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §4.
struct Badge: View {
    enum Variant {
        case refund    // green text on green tint
        case due       // amber text on amber tint
        case error     // red text on red tint
        case neutral   // gray text on gray tint

        var foreground: Color {
            switch self {
            case .refund:  return .Semantic.green
            case .due:     return .Semantic.amber
            case .error:   return .Semantic.red
            case .neutral: return .UI.textSecondary
            }
        }

        var background: Color {
            switch self {
            case .refund:  return .Semantic.greenTint
            case .due:     return .Semantic.amberTint
            case .error:   return .Semantic.redTint
            case .neutral: return Color(red: 0.94, green: 0.94, blue: 0.95)
            }
        }

        /// Default uppercase label used when displaying the variant without an explicit override.
        var defaultText: String {
            switch self {
            case .refund:  return "REFUND"
            case .due:     return "DUE"
            case .error:   return "ERROR"
            case .neutral: return ""
            }
        }
    }

    let text: String
    let variant: Variant

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(variant.foreground)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(variant.background)
            .clipShape(RoundedRectangle(cornerRadius: Radius.badge))
    }
}

#Preview("All variants — light") {
    HStack(spacing: 8) {
        Badge(text: "REFUND", variant: .refund)
        Badge(text: "DUE", variant: .due)
        Badge(text: "ERROR", variant: .error)
        Badge(text: "DRAFT", variant: .neutral)
    }
    .padding()
    .preferredColorScheme(.light)
}

#Preview("All variants — dark") {
    HStack(spacing: 8) {
        Badge(text: "REFUND", variant: .refund)
        Badge(text: "DUE", variant: .due)
        Badge(text: "ERROR", variant: .error)
        Badge(text: "DRAFT", variant: .neutral)
    }
    .padding()
    .background(Color.UI.surfaceCard)
    .preferredColorScheme(.dark)
}
