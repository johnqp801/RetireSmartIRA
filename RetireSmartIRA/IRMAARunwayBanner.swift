import SwiftUI

/// Amber dismissible banner for ages 60-62 IRMAA-free Roth conversion runway.
/// Fires when anyone in the household is in the pre-63 window where conversions
/// don't affect future Medicare premiums (the 2-year MAGI lookback starts at age 63).
struct IRMAARunwayBanner: View {
    let primaryAge: Int
    let spouseAge: Int?
    let spouseEnabled: Bool
    @Binding var dismissed: Bool

    /// Determines visibility: true if primary age 60-62 OR spouse enabled and spouse age 60-62.
    static func shouldShow(primaryAge: Int, spouseAge: Int?, spouseEnabled: Bool) -> Bool {
        func ageInRange(_ a: Int) -> Bool { (60...62).contains(a) }
        if ageInRange(primaryAge) { return true }
        if spouseEnabled, let s = spouseAge, ageInRange(s) { return true }
        return false
    }

    var body: some View {
        if Self.shouldShow(primaryAge: primaryAge, spouseAge: spouseAge, spouseEnabled: spouseEnabled) && !dismissed {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .foregroundStyle(Color.Semantic.amber)
                    Text("IRMAA-Free Conversion Window")
                        .font(.headline)
                    Spacer()
                    Button { dismissed = true } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                Text("You're in your most valuable Roth conversion years. Conversions made now don't affect your Medicare premiums later. Once you hit age 63, your MAGI starts determining your Medicare IRMAA tier two years later.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.Semantic.amberTint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
