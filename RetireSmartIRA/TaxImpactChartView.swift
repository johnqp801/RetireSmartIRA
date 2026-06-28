import SwiftUI
import Charts

struct TaxImpactChartView: View {
    let model: TaxImpactChart

    private var caption: String {
        let s = model.totalSavings
        if s > 1_000 {
            return "Your plan pays more tax early, then comes out ahead by about \(PlanSummary.shortDollars(s)) over the horizon."
        } else if s < -1_000 {
            return "Over this horizon the plan pays about \(PlanSummary.shortDollars(-s)) more tax than doing nothing; the payoff is in defused future RMDs and what heirs keep."
        }
        return "Cumulative tax paid under your plan versus doing nothing."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cumulative tax: your plan vs doing nothing").font(.headline)
            Chart(model.points) { point in
                LineMark(x: .value("Year", point.year),
                         y: .value("Cumulative tax", point.cumulativePlan),
                         series: .value("Path", "Your plan"))
                    .foregroundStyle(Color.Chart.heroTeal)
                LineMark(x: .value("Year", point.year),
                         y: .value("Cumulative tax", point.cumulativeDoingNothing),
                         series: .value("Path", "Doing nothing"))
                    .foregroundStyle(Color.Chart.gray3)
            }
            .chartForegroundStyleScale([
                "Your plan": Color.Chart.heroTeal,
                "Doing nothing": Color.Chart.gray3
            ])
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
            .frame(height: 200)
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
