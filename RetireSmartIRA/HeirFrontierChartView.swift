import SwiftUI
import Charts

struct HeirFrontierChartView: View {
    let model: HeirFrontierChart

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your taxes vs what heirs keep").font(.headline)
            Chart {
                ForEach(model.points) { point in
                    LineMark(x: .value("Your lifetime tax", point.ownerTax),
                             y: .value("Heirs keep", point.heirsKeep))
                        .foregroundStyle(Color.Chart.gray3)
                }
                ForEach(model.points) { point in
                    PointMark(x: .value("Your lifetime tax", point.ownerTax),
                              y: .value("Heirs keep", point.heirsKeep))
                        .foregroundStyle(point.isSelected ? Color.Chart.callout : Color.Chart.heroTeal)
                        .symbolSize(point.isSelected ? 160 : 60)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(PlanSummary.shortDollars(amount)).font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(PlanSummary.shortDollars(amount)).font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                }
            }
            .frame(height: 220)
            Text("Each point is a strategy weighting, from owner-optimal to heir-optimal. The highlighted point is your current selection. Lower tax to the left; more for heirs is higher.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
