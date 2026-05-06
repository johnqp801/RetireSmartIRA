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
                    .foregroundStyle(.orange)
                ForEach(summarized, id: \.self) { item in
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
                Text(item.costDollars < 1_000
                     ? "$\(Int(item.costDollars))"
                     : "$\(Int((item.costDollars / 1_000).rounded()))K")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            }
            Text(item.whyText)
                .font(.caption2.italic())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .padding(.vertical, 4)
    }
}
