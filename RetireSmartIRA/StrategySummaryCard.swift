import SwiftUI

struct StrategySummaryCard: View {
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STRATEGY")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            Text(summaryText)
                .font(.subheadline)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(PlatformColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}
