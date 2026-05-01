import SwiftUI

/// Static, always-visible icon+text hint. Use for short disclaimers, clarifying notes,
/// or contextual guidance that should reach every user without requiring a tap.
///
/// For longer explanations that benefit from one-tap access, use `InfoButton` instead
/// (filled brand-teal icon, opens a popover or sheet).
///
/// For threshold-based status indicators (icon flips between info.circle and
/// exclamationmark.triangle.fill based on data state), keep the ad-hoc `Image`
/// switch — that's a different pattern from this component.
///
/// See `RetireSmartIRA/Theme/README.md` for the full icon-vocabulary documentation
/// and `docs/superpowers/specs/2026-05-01-inline-hint-vocabulary-design.md` for design.
struct InlineHint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(Color.UI.textSecondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.UI.textSecondary)
        }
    }
}

#Preview("Single line — light") {
    InlineHint("State tax only — local/city taxes (e.g. NYC) are not included.")
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Multiline — light") {
    InlineHint("Your spouse's income, filing status, and age come from your household inputs — no additional heir details needed.")
        .padding()
        .frame(width: 320)
        .preferredColorScheme(.light)
}

#Preview("Single line — dark") {
    InlineHint("State tax only — local/city taxes (e.g. NYC) are not included.")
        .padding()
        .background(Color.UI.surfaceCard)
        .preferredColorScheme(.dark)
}
