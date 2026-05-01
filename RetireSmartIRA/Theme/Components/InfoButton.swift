import SwiftUI

/// Filled brand-teal `info.circle.fill` button at 16pt visual size with 24pt hit target.
/// Use for tappable explanations that open a popover or sheet.
///
/// For static, always-visible icon+text hints (short disclaimers, clarifying notes),
/// use `InlineHint` instead.
///
/// See `RetireSmartIRA/Theme/README.md` for the full icon-vocabulary documentation
/// and `docs/superpowers/specs/2026-04-25-color-system-design.md` §4 for the original
/// component spec.
struct InfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.UI.brandTeal)
                .frame(width: 24, height: 24)  // hit target
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More information")
    }
}

#Preview("Inline with label — light") {
    HStack(spacing: 6) {
        Text("Primary Heir's Salary")
            .font(.system(size: 13))
        InfoButton {}
        Spacer()
    }
    .padding()
    .frame(width: 280)
    .preferredColorScheme(.light)
}

#Preview("Inline with label — dark") {
    HStack(spacing: 6) {
        Text("Primary Heir's Salary")
            .font(.system(size: 13))
        InfoButton {}
        Spacer()
    }
    .padding()
    .frame(width: 280)
    .background(Color.UI.surfaceCard)
    .preferredColorScheme(.dark)
}
