import SwiftUI

/// The canonical button component. Six visual variants matching the design spec.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §4.
struct BrandButton: View {
    enum Style {
        case primary
        case secondary
        /// Default tertiary — gray text. Use for utility actions (Edit, Reset, Cancel).
        case tertiaryUtility
        /// Teal-text tertiary — use ONLY for actions that genuinely advance the user
        /// (≈1 in 5 inline links). See spec §4 "Tertiary defaults to gray."
        case tertiaryForward
        /// Outline red, inline destructive (next to a primary).
        case destructiveSecondary
        /// Filled red, final-step modal confirmation only.
        case destructivePrimary
    }

    enum Size {
        case compact   // 28pt height, 13pt text
        case standard  // 36pt height, 15pt text
        case prominent // 44pt height, 17pt text

        var height: CGFloat {
            switch self {
            case .compact:   return 28
            case .standard:  return 36
            case .prominent: return 44
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .compact:   return 13
            case .standard:  return 15
            case .prominent: return 17
            }
        }
    }

    let title: String
    var style: Style = .primary
    var size: Size = .standard
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: size.fontSize, weight: .semibold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: size.height)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        guard isEnabled else { return disabledTextColor }
        switch style {
        case .primary:               return .white
        case .secondary:             return .UI.brandTeal
        case .tertiaryUtility:       return .UI.textUtility
        case .tertiaryForward:       return .UI.brandTeal
        case .destructiveSecondary:  return .Semantic.red
        case .destructivePrimary:    return .white
        }
    }

    private var backgroundColor: Color {
        guard isEnabled else { return disabledBackgroundColor }
        switch style {
        case .primary:               return .UI.brandTeal
        case .secondary:             return .clear
        case .tertiaryUtility:       return .clear
        case .tertiaryForward:       return .clear
        case .destructiveSecondary:  return .clear
        case .destructivePrimary:    return .Semantic.red
        }
    }

    private var borderColor: Color {
        guard isEnabled else { return disabledBorderColor }
        switch style {
        case .primary, .destructivePrimary:        return .clear
        case .secondary:                           return .UI.brandTeal
        case .tertiaryUtility, .tertiaryForward:   return .clear
        case .destructiveSecondary:                return .Semantic.red
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .secondary, .destructiveSecondary: return 1.5
        default:                                 return 0
        }
    }

    private var disabledTextColor: Color {
        switch style {
        case .primary, .destructivePrimary: return .white.opacity(0.65)
        case .secondary:                     return .UI.brandTealDisabled
        case .destructiveSecondary:          return .Semantic.redDisabled
        case .tertiaryUtility, .tertiaryForward:
            return .UI.textTertiary
        }
    }

    private var disabledBackgroundColor: Color {
        switch style {
        case .primary:            return .UI.brandTealDisabled
        case .destructivePrimary: return .Semantic.redDisabled
        default:                  return .clear
        }
    }

    private var disabledBorderColor: Color {
        switch style {
        case .secondary:            return .UI.brandTealDisabled
        case .destructiveSecondary: return .Semantic.redDisabled
        default:                    return .clear
        }
    }
}

#Preview("All variants — light") {
    VStack(spacing: 12) {
        BrandButton(title: "Primary",              style: .primary) {}
        BrandButton(title: "Secondary",            style: .secondary) {}
        BrandButton(title: "Tertiary Utility",     style: .tertiaryUtility) {}
        BrandButton(title: "Tertiary Forward",     style: .tertiaryForward) {}
        BrandButton(title: "Destructive Secondary",style: .destructiveSecondary) {}
        BrandButton(title: "Destructive Primary",  style: .destructivePrimary) {}
    }
    .padding()
    .preferredColorScheme(.light)
}

#Preview("Disabled — light") {
    VStack(spacing: 12) {
        BrandButton(title: "Primary",   style: .primary) {}.disabled(true)
        BrandButton(title: "Secondary", style: .secondary) {}.disabled(true)
        BrandButton(title: "Tertiary",  style: .tertiaryUtility) {}.disabled(true)
    }
    .padding()
    .preferredColorScheme(.light)
}

#Preview("All variants — dark") {
    VStack(spacing: 12) {
        BrandButton(title: "Primary",              style: .primary) {}
        BrandButton(title: "Secondary",            style: .secondary) {}
        BrandButton(title: "Tertiary Utility",     style: .tertiaryUtility) {}
        BrandButton(title: "Tertiary Forward",     style: .tertiaryForward) {}
        BrandButton(title: "Destructive Secondary",style: .destructiveSecondary) {}
        BrandButton(title: "Destructive Primary",  style: .destructivePrimary) {}
    }
    .padding()
    .background(Color.UI.surfaceApp)
    .preferredColorScheme(.dark)
}
