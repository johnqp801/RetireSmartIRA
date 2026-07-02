import SwiftUI

/// Reusable "show how this is computed" disclosure that renders the income chain. Any single-year
/// tab can drop this under its headline income figure so the reconciliation is one tap away.
struct IncomeBreakdownView: View {
    let breakdown: IncomeBreakdown
    @State private var expanded = false

    var body: some View {
        DisclosureGroup("Show how this is computed", isExpanded: $expanded) {
            VStack(spacing: 4) {
                ForEach(breakdown.steps) { step in
                    if step.isSubtotal { Divider() }
                    HStack {
                        Text(step.label)
                            .fontWeight(step.isSubtotal ? .semibold : .regular)
                        Spacer()
                        Text(step.amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .fontWeight(step.isSubtotal ? .semibold : .regular)
                            .monospacedDigit()
                    }
                    .font(.caption)
                }
            }
            .padding(.top, 4)
        }
        .font(.caption)
    }
}
