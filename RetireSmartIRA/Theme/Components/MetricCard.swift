import SwiftUI

/// The canonical metric card. Top-stripe colored band over a card body.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §4.
struct MetricCard: View {
    enum Category {
        case informational  // brand teal stripe — default
        case actionRequired // amber stripe
        case error          // red stripe

        var stripeColor: Color {
            switch self {
            case .informational:  return .UI.brandTeal
            case .actionRequired: return .Semantic.amber
            case .error:          return .Semantic.red
            }
        }
    }

    let label: String
    let value: String
    var delta: String? = nil
    /// Whether the delta string should render in amber (e.g., deadline text).
    /// The dollar VALUE itself stays primary text — only delta/deadline qualifies for amber.
    var deltaIsAmber: Bool = false
    var category: Category = .informational
    var badge: Badge.Variant? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 4pt category stripe
            Rectangle()
                .fill(category.stripeColor)
                .frame(height: 4)

            // Body
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xxs) {
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.UI.textSecondary)
                    if let badge {
                        Badge(text: badge.defaultText, variant: badge)
                    }
                    Spacer()
                }
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.UI.textPrimary)
                if let delta {
                    Text(delta)
                        .font(.system(size: 11))
                        .foregroundStyle(deltaIsAmber ? Color.Semantic.amber : Color.UI.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.UI.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: .black.opacity(0.08), radius: 1.5, x: 0, y: 1)
    }
}

#Preview("Informational — light") {
    MetricCard(label: "Total Tax", value: "$12,847", delta: "+$1,240 vs 2025")
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.light)
}

#Preview("Refund — light") {
    MetricCard(
        label: "Est. Refund",
        value: "$1,830",
        delta: "Federal",
        category: .informational,
        badge: .refund
    )
    .padding()
    .background(Color.UI.surfaceApp)
    .preferredColorScheme(.light)
}

#Preview("Action required — light") {
    MetricCard(
        label: "Q2 Estimated",
        value: "$3,212",
        delta: "Due Jun 15",
        deltaIsAmber: true,
        category: .actionRequired,
        badge: .due
    )
    .padding()
    .background(Color.UI.surfaceApp)
    .preferredColorScheme(.light)
}

#Preview("Error — light") {
    MetricCard(
        label: "ACA Subsidy",
        value: "$0",
        delta: "Cliff exceeded",
        category: .error,
        badge: .error
    )
    .padding()
    .background(Color.UI.surfaceApp)
    .preferredColorScheme(.light)
}

#Preview("Informational — dark") {
    MetricCard(label: "Total Tax", value: "$12,847", delta: "+$1,240 vs 2025")
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.dark)
}
