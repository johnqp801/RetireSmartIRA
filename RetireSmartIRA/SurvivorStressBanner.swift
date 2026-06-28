import SwiftUI

/// Dismissible banner surfacing the survivor tax penalty: how much more lifetime tax the surviving
/// spouse is projected to pay filing single. Conservative upper bound (single-filer rates from the
/// start of the horizon).
struct SurvivorStressBanner: View {
    let widowDelta: TaxImpact
    @Binding var dismissed: Bool

    static let minimumToShow: Double = 1_000

    static func shouldShow(widowDelta: TaxImpact, dismissed: Bool) -> Bool {
        !dismissed && widowDelta.delta > minimumToShow
    }

    var body: some View {
        if Self.shouldShow(widowDelta: widowDelta, dismissed: dismissed) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.fill.badge.minus").foregroundStyle(Color.Semantic.amber)
                    Text("Survivor tax impact").font(.headline)
                    Spacer()
                    Button { dismissed = true } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
                Text("If one spouse passes, the survivor is projected to pay about \(PlanSummary.shortDollars(widowDelta.delta)) more in lifetime tax filing as single. Roth conversions now can reduce that exposure. This is a conservative estimate under current law.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding().background(Color.Semantic.amberTint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
