import SwiftUI
import Charts

struct SparklineRow: View {
    let path: [YearRecommendation]

    var body: some View {
        HStack(spacing: 8) {
            sparklineCard("Trad", color: .blue, values: path.map { $0.endOfYearBalances.traditional })
            sparklineCard("Roth", color: .green, values: path.map { $0.endOfYearBalances.roth })
            sparklineCard("Taxable", color: .orange, values: path.map { $0.endOfYearBalances.taxable })
            sparklineCard("HSA", color: .purple, values: path.map { $0.endOfYearBalances.hsa })
        }
    }

    private func sparklineCard(_ name: String, color: Color, values: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.caption2).foregroundColor(.secondary)
            Text("$\(Int((values.first ?? 0) / 1000))K")
                .font(.subheadline.weight(.bold))
            Chart(Array(values.enumerated()), id: \.offset) { idx, v in
                LineMark(
                    x: .value("idx", idx),
                    y: .value("v", v)
                )
                .foregroundStyle(color)
            }
            .frame(height: 30)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(6)
    }
}
