import SwiftUI
import Charts

/// The owner-vs-heirs frontier as a labeled scatter: x = your lifetime taxes paid, y = what heirs
/// keep after tax, one point per strategy weighting with the endpoints named and the selection
/// highlighted. Collapses to a message when the frontier is flat (no tradeoff to plot).
struct HeirFrontierChartView: View {
    let model: HeirFrontierChart

    private var maxWeight: Double { model.points.map(\.weight).max() ?? 0 }

    private var hasMaterialTradeoff: Bool { model.hasMaterialTradeoff }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Your taxes vs. what heirs keep").font(.headline)
                ChartInfoButton(commentary: model.commentary)
                Spacer()
            }
            if hasMaterialTradeoff {
                chart
                Text("Each point is a strategy weighting; the highlighted point is your current selection. Down-left favors you (less lifetime tax); up-right favors heirs (more inheritance).")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("All strategy weightings produce essentially the same outcome at these assumptions, so there is no tradeoff curve to plot.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var chart: some View {
        Chart {
            ForEach(model.points) { p in
                LineMark(x: .value("Your lifetime tax", p.ownerTax),
                         y: .value("What heirs keep", p.heirsKeep))
                    .foregroundStyle(Color.Chart.gray3)
            }
            ForEach(model.points) { p in
                PointMark(x: .value("Your lifetime tax", p.ownerTax),
                          y: .value("What heirs keep", p.heirsKeep))
                    .foregroundStyle(p.isSelected ? Color.Chart.callout : Color.Chart.heroTeal)
                    .symbolSize(p.isSelected ? 160 : 60)
                    .annotation(position: .top, alignment: .center) {
                        if p.weight <= 0 {
                            Text("Optimize for you").font(.caption2).foregroundStyle(.secondary)
                        } else if p.weight == maxWeight {
                            Text("Optimize for heirs").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .chartXAxisLabel("Your lifetime taxes paid")
        .chartYAxisLabel("What heirs keep after tax")
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                AxisValueLabel {
                    if let a = value.as(Double.self) { Text(PlanSummary.shortDollars(a)).font(.caption2) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                AxisValueLabel {
                    if let a = value.as(Double.self) { Text(PlanSummary.shortDollars(a)).font(.caption2) }
                }
            }
        }
        .frame(height: 240)
    }
}
