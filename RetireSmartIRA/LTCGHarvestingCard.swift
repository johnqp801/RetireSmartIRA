import SwiftUI

/// 0% LTCG Bracket Harvesting Awareness Card (1.8.2 L2).
///
/// Shows the user the top of the 0% long-term capital gains bracket and their
/// remaining headroom against current scenario taxable income. Mounted in
/// `TaxPlanningView` only when `profile.hasTaxableBrokerage` is true.
struct LTCGHarvestingCard: View {
    @Environment(DataManager.self) var dataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .foregroundStyle(Color.UI.brandTeal)
                Text("0% LTCG Harvesting Headroom")
                    .font(.headline)
            }
            HStack {
                Text("Top of 0% LTCG bracket")
                Spacer()
                Text(dataManager.ltcg0PercentTop, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .fontWeight(.semibold)
            }
            .font(.callout)
            HStack {
                Text("Remaining headroom")
                Spacer()
                Text(dataManager.ltcg0PercentHeadroom, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .fontWeight(.semibold)
                    .foregroundStyle(dataManager.ltcg0PercentHeadroom > 0 ? Color.Semantic.green : Color.Semantic.red)
            }
            .font(.callout)
            Text("Every $1 of Roth conversion reduces this headroom by $1. Consider whether harvesting taxable-account gains is more valuable than converting now.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.UI.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
