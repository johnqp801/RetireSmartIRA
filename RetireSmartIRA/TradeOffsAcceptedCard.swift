import SwiftUI

struct TradeOffsAcceptedCard: View {
    let tradeOffs: [ConstraintHit]

    var body: some View {
        if !tradeOffs.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Trade-offs accepted")
                        .font(.caption.weight(.semibold))
                }
                ForEach(tradeOffs.prefix(5), id: \.year) { hit in
                    HStack {
                        Text("\(hit.year):")
                            .fontWeight(.semibold)
                        Text(describe(hit.type))
                            .lineLimit(1)
                        Spacer()
                        Text("$\(Int(hit.cost / 1000))K")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                }
            }
            .padding(10)
            .background(Color.orange.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            .cornerRadius(8)
        }
    }

    private func describe(_ type: ConstraintType) -> String {
        switch type {
        case .irmaaTier(let level): return "IRMAA Tier \(level) hit"
        case .acaCliff: return "ACA cliff hit"
        case .bracketOverrun(let from, let to): return "\(from)% → \(to)% bracket overrun"
        }
    }
}
