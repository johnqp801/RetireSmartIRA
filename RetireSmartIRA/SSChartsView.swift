//
//  SSChartsView.swift
//  RetireSmartIRA
//
//  Extracted chart components for the Social Security Planner.
//  Separated to reduce view hierarchy depth and prevent stack overflow on physical devices.
//

import SwiftUI
import Charts

// MARK: - Cumulative Benefits Chart

struct SSCumulativeBenefitsChart: View {
    let chartData: [SSCumulativeChartPoint]
    let lifeExpectancy: Int
    let breakEvenComparisons: [SSBreakEvenComparison]
    let highlightClaimingAge: Int?

    private let scenarioColors: [String: Color] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cumulative Benefits")
                .font(.headline)

            if chartData.isEmpty {
                Text("Enter your benefit estimates to see projections")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                chart
                    .frame(height: 400)

                legend
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var colorScale: KeyValuePairs<String, Color> {
        [
            "Claim at 62": .red,
            "Claim at 63": .orange,
            "Claim at 64": .yellow,
            "Claim at 65": .mint,
            "Claim at 66": .teal,
            "Claim at 66 (FRA)": .teal,
            "Claim at 67": .blue,
            "Claim at 67 (FRA)": .blue,
            "Claim at 68": .indigo,
            "Claim at 69": .purple,
            "Claim at 70": .green,
        ]
    }

    /// Break-even ages that are non-nil, pre-filtered for the chart
    private var validBreakEvenAges: [Int] {
        breakEvenComparisons.compactMap { $0.breakEvenAge }
    }

    /// Upper bound for the X axis — life expectancy + a small buffer
    private var maxChartAge: Int {
        max(lifeExpectancy + 3, 85)
    }

    private var chart: some View {
        Chart {
            ForEach(chartData.filter { $0.age >= 62 && $0.age <= maxChartAge }) { point in
                LineMark(
                    x: .value("Age", point.age),
                    y: .value("Cumulative", point.cumulativeAmount)
                )
                .foregroundStyle(by: .value("Strategy", point.scenarioLabel))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }

            lifeExpectancyRule

            ForEach(validBreakEvenAges, id: \.self) { beAge in
                breakEvenRule(age: beAge)
            }
        }
        .chartForegroundStyleScale(colorScale)
        .chartXScale(domain: 62...maxChartAge)
        .chartXAxis { xAxisContent }
        .chartYAxis { yAxisContent }
        .chartLegend(.hidden)
    }

    private var lifeExpectancyRule: some ChartContent {
        RuleMark(x: .value("Life Expectancy", lifeExpectancy))
            .foregroundStyle(.gray.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
            .annotation(position: .top, alignment: .trailing) {
                Text("LE: \(lifeExpectancy)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
    }

    private func breakEvenRule(age: Int) -> some ChartContent {
        RuleMark(x: .value("Break-even", age))
            .foregroundStyle(.orange.opacity(0.4))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .annotation(position: .top, alignment: .leading) {
                Text("BE \(age)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color(PlatformColor.systemBackground).opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
    }

    @AxisContentBuilder
    private var xAxisContent: some AxisContent {
        AxisMarks(values: [62, 67, 72, 77, 82, 87, 92, 97]) { value in
            AxisValueLabel {
                if let age = value.as(Int.self) {
                    Text("\(age)")
                        .font(.caption2)
                }
            }
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
        }
    }

    @AxisContentBuilder
    private var yAxisContent: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisValueLabel {
                if let amount = value.as(Double.self) {
                    Text(chartYAxisLabel(amount))
                        .font(.caption2)
                }
            }
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
        }
    }

    private var legend: some View {
        let labels: [(String, Color)] = [
            ("Claim at 62", .red),
            ("Claim at 67", .blue),
            ("Claim at 70", .green),
        ]
        return HStack(spacing: 16) {
            ForEach(labels, id: \.0) { label, color in
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chartYAxisLabel(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "$\(String(format: "%.1f", value / 1_000_000))M"
        } else if value >= 1_000 {
            return "$\(String(format: "%.0f", value / 1_000))K"
        }
        return "$\(String(format: "%.0f", value))"
    }
}

// MARK: - Monthly Benefit Comparison Bars

struct SSMonthlyComparisonChart: View {
    let benefitAt62: Double
    let benefitAtFRA: Double
    let benefitAt70: Double
    let plannedAge: Int

    private struct BenefitBar: Identifiable {
        let id = UUID()
        let label: String
        let age: Int
        let amount: Double
        let color: Color
        let isPlanned: Bool
    }

    var body: some View {
        let bars = [
            BenefitBar(label: "Age 62", age: 62, amount: benefitAt62, color: .red, isPlanned: plannedAge == 62),
            BenefitBar(label: "FRA", age: 67, amount: benefitAtFRA, color: .blue, isPlanned: plannedAge == 67),
            BenefitBar(label: "Age 70", age: 70, amount: benefitAt70, color: .green, isPlanned: plannedAge == 70),
        ]

        Chart(bars) { bar in
            BarMark(
                x: .value("Age", bar.label),
                y: .value("Monthly", bar.amount)
            )
            .foregroundStyle(bar.color.gradient)
            .cornerRadius(6)
            .annotation(position: .top) {
                Text(SSCalculationEngine.formatCurrency(bar.amount))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text("$\(String(format: "%.0f", amount))")
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 180)
    }
}
