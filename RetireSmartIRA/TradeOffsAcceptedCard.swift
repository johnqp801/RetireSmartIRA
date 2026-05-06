import SwiftUI

struct TradeOffsAcceptedCard: View {
    let tradeOffs: [ConstraintHit]

    private var summarized: [SummarizedTradeOff] {
        TradeOffSynthesizer.summarize(hits: tradeOffs)
    }

    var body: some View {
        if summarized.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Trade-offs accepted", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
                ForEach(Array(summarized.enumerated()), id: \.offset) { _, item in
                    row(for: item)
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 0.5))
        }
    }

    private func row(for item: SummarizedTradeOff) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(item.year) — \(item.title)")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("$\(Int(item.costDollars / 1000))K")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
                    .monospacedDigit()
            }
            Text(item.whyText)
                .font(.caption2.italic())
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .padding(.vertical, 4)
    }
}
