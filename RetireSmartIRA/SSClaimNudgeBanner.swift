import SwiftUI

/// Dismissible banner suggesting a different Social Security claiming age when the engine projects
/// a lifetime-tax improvement from shifting it.
struct SSClaimNudgeBanner: View {
    let nudge: ClaimAgeFlag?
    @Binding var dismissed: Bool

    static func shouldShow(nudge: ClaimAgeFlag?, dismissed: Bool) -> Bool {
        guard !dismissed, let n = nudge else { return false }
        return n.suggestedClaimAge != n.currentClaimAge
    }

    static func message(_ n: ClaimAgeFlag) -> String {
        let who = n.spouse == .primary ? "you" : "your spouse"
        let savings = PlanSummary.shortDollars(abs(n.estimatedLifetimeTaxDelta))
        return "Claiming Social Security for \(who) at age \(n.suggestedClaimAge) instead of \(n.currentClaimAge) is projected to save about \(savings) in lifetime tax under this plan."
    }

    var body: some View {
        if let n = nudge, Self.shouldShow(nudge: nudge, dismissed: dismissed) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar.badge.clock").foregroundStyle(Color.Semantic.green)
                    Text("Social Security timing").font(.headline)
                    Spacer()
                    Button { dismissed = true } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
                Text(Self.message(n)).font(.callout).foregroundStyle(.secondary)
            }
            .padding().background(Color.Semantic.greenTint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
