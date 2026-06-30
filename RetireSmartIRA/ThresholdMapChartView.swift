import SwiftUI
import Charts

struct ThresholdMapChartView: View {
    let model: ThresholdMapChart
    @State private var measure: ThresholdMapChart.Measure = .magiCliffs

    /// 2026-nominal honesty caveat (static so a test can assert it).
    static let caveat = "Thresholds are shown at 2026 levels. They are not inflation-adjusted, so in later years the real thresholds will sit higher than the lines here."

    private var xDomain: ClosedRange<Int> {
        let ys = model.points(for: measure).map(\.year)
        let lo = ys.min() ?? 0, hi = ys.max() ?? 0
        return lo...(hi > lo ? hi : lo + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Income vs tax cliffs by year").font(.headline)
            Picker("Measure", selection: $measure) {
                Text("Medicare & subsidies").tag(ThresholdMapChart.Measure.magiCliffs)
                Text("Income tax brackets").tag(ThresholdMapChart.Measure.incomeTaxBrackets)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Chart {
                ForEach(model.lines(for: measure)) { line in
                    RuleMark(y: .value("Threshold", line.value))
                        .foregroundStyle(Color.Chart.gray3.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(line.label).font(.caption2).foregroundStyle(.secondary)
                        }
                }
                ForEach(model.points(for: measure)) { point in
                    LineMark(x: .value("Year", point.year), y: .value("Income", point.value))
                        .foregroundStyle(Color.Chart.heroTeal)
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
            .chartXScale(domain: xDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    AxisValueLabel {
                        if let y = value.as(Int.self) { Text(verbatim: String(y)).font(.caption2) }
                    }
                }
            }
            .frame(height: 240)

            Text(Self.caveat).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
