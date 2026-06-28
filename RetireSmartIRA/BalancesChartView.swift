import SwiftUI
import Charts

struct BalancesChartView: View {
    let model: BalancesChart
    @State private var showBand = false

    private var xDomain: ClosedRange<Int> {
        let ys = model.points.map(\.year)
        let lo = ys.min() ?? 0, hi = ys.max() ?? 0
        return lo...(hi > lo ? hi : lo + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account balances over time").font(.headline)
            Chart {
                if showBand {
                    ForEach(model.points) { point in
                        if let low = point.totalLow, let high = point.totalHigh {
                            AreaMark(x: .value("Year", point.year),
                                     yStart: .value("Low", low),
                                     yEnd: .value("High", high))
                                .foregroundStyle(Color.Chart.heroTeal.opacity(0.12))
                        }
                    }
                }
                ForEach(model.points) { point in
                    LineMark(x: .value("Year", point.year),
                             y: .value("Balance", point.traditional),
                             series: .value("Account", "Traditional"))
                        .foregroundStyle(Color.Chart.gray3)
                    LineMark(x: .value("Year", point.year),
                             y: .value("Balance", point.roth),
                             series: .value("Account", "Roth"))
                        .foregroundStyle(Color.Chart.heroTeal)
                    LineMark(x: .value("Year", point.year),
                             y: .value("Balance", point.taxable),
                             series: .value("Account", "Taxable"))
                        .foregroundStyle(Color.Chart.callout)
                }
            }
            .chartForegroundStyleScale([
                "Traditional": Color.Chart.gray3,
                "Roth": Color.Chart.heroTeal,
                "Taxable": Color.Chart.callout
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
            .chartXScale(domain: xDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    AxisValueLabel {
                        if let y = value.as(Int.self) { Text(verbatim: String(y)).font(.caption2) }
                    }
                }
            }
            .frame(height: 220)
            if model.hasBand {
                Toggle("Show growth-rate sensitivity band", isOn: $showBand)
                    .font(.caption)
                if showBand {
                    Text("Shaded range = total balance under higher and lower constant growth. This is growth-assumption sensitivity, not a probability or odds of success.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
