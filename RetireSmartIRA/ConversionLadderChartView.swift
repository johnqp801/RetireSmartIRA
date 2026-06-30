import SwiftUI
import Charts

struct ConversionLadderChartView: View {
    let model: ConversionLadderChart

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recommended conversions by year").font(.headline)
            Chart(model.points) { point in
                BarMark(x: .value("Year", point.yearLabel),
                        y: .value("Conversion", point.conversion))
                    .foregroundStyle(Color.Chart.heroTeal)
                    .cornerRadius(3)
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
            .chartXAxis {
                AxisMarks { value in
                    AxisTick()
                    AxisValueLabel {
                        if let year = value.as(String.self) {
                            Text(year).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
