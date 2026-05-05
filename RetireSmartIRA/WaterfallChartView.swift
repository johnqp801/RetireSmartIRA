import SwiftUI
import Charts

struct WaterfallChartView: View {
    let path: [YearRecommendation]
    let sensitivityBands: SensitivityBands?
    let selectedYear: Int?
    let onYearTap: (Int) -> Void

    var body: some View {
        Chart {
            ForEach(path, id: \.year) { y in
                BarMark(
                    x: .value("Year", shortYear(y.year)),
                    y: .value("Federal", y.taxBreakdown.federal)
                )
                .foregroundStyle(by: .value("Component", "Federal"))

                BarMark(
                    x: .value("Year", shortYear(y.year)),
                    y: .value("State", y.taxBreakdown.state)
                )
                .foregroundStyle(by: .value("Component", "State"))

                if y.taxBreakdown.irmaa > 0 {
                    BarMark(
                        x: .value("Year", shortYear(y.year)),
                        y: .value("IRMAA", y.taxBreakdown.irmaa)
                    )
                    .foregroundStyle(by: .value("Component", "IRMAA"))
                }

                if y.taxBreakdown.acaPremiumImpact > 0 {
                    BarMark(
                        x: .value("Year", shortYear(y.year)),
                        y: .value("ACA", y.taxBreakdown.acaPremiumImpact)
                    )
                    .foregroundStyle(by: .value("Component", "ACA"))
                }
            }

            if let bands = sensitivityBands {
                ForEach(Array(zip(bands.optimistic, bands.pessimistic).enumerated()), id: \.offset) { _, pair in
                    let (opt, pess) = pair
                    RectangleMark(
                        x: .value("Year", shortYear(opt.year)),
                        yStart: .value("Optimistic", opt.taxBreakdown.total),
                        yEnd: .value("Pessimistic", pess.taxBreakdown.total)
                    )
                    .foregroundStyle(.blue.opacity(0.10))
                }
            }
        }
        .chartForegroundStyleScale([
            "Federal": Color.blue,
            "State": Color.cyan,
            "IRMAA": Color.orange,
            "ACA": Color.red
        ])
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6))
        }
        .frame(height: 180)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { location in
                        // TODO: tap-to-select
                        _ = location
                        _ = proxy
                        _ = geo
                    }
            }
        }
    }

    private func shortYear(_ year: Int) -> String {
        let twoDigit = year % 100
        return twoDigit < 10 ? "0\(twoDigit)" : "\(twoDigit)"
    }
}
