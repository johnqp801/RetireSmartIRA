//
//  SSChartsView.swift
//  RetireSmartIRA
//
//  Extracted chart components for the Social Security Planner.
//  Separated to reduce view hierarchy depth and prevent stack overflow on physical devices.
//

import SwiftUI
import Charts

// MARK: - Cumulative Benefits Chart Line Selection

/// Pure, testable logic that decides which claim-age lines the Cumulative
/// Benefits chart plots, and which design-system color token each gets.
///
/// The engine computes 9 claiming scenarios (ages 62 through 70), but the
/// locked chart palette (teal ramp + neutral grays + warm sand; see
/// `ColorTokens+Chart.swift`) can't give 9 lines truly distinct colors.
/// Instead this shows only the ages that matter for a claiming decision:
/// 62, Full Retirement Age, and 70, plus the user's own planned claiming
/// age when it's set and not already one of those three.
enum SSCumulativeChartColors {

    /// Design-system tokens available to this chart, kept as an enum (rather
    /// than exposing `Color` directly) so tests can assert distinctness by
    /// token identity instead of relying on `Color`'s Equatable behavior.
    enum Token: Equatable {
        case tealRamp1
        case heroTeal
        case callout
        case gray3

        var color: Color {
            switch self {
            case .tealRamp1: return Color.Chart.tealRamp1
            case .heroTeal: return Color.Chart.heroTeal
            case .callout: return Color.Chart.callout
            case .gray3: return Color.Chart.gray3
            }
        }
    }

    /// One claim-age line to display: its scenario label (as produced by
    /// `SSCalculationEngine.claimingScenarios`), its color token, and
    /// whether it represents the user's own planned claiming age.
    struct DisplayLine: Equatable {
        let label: String
        let token: Token
        let isPlanned: Bool

        var color: Color { token.color }
    }

    /// Selects the claim-age lines to plot and assigns each a distinct color.
    ///
    /// Always includes "Claim at 62", the FRA line (matched by the
    /// "(FRA)" suffix -- FRA varies by birth year, so this is never
    /// hardcoded to 66 or 67), and "Claim at 70" -- in that order, when
    /// present in `availableLabels`. Also includes the user's planned
    /// claiming age when it's set and its label isn't already one of
    /// those three.
    ///
    /// - Parameters:
    ///   - availableLabels: scenario labels actually present in the chart
    ///     data (normally all of ages 62 through 70).
    ///   - plannedAge: the user's planned claiming age, if any.
    /// - Returns: an ordered list of lines to display, each with a distinct color token.
    static func displayLines(availableLabels: [String], plannedAge: Int?) -> [DisplayLine] {
        var lines: [DisplayLine] = []

        if let label62 = matchingLabel(forAge: 62, in: availableLabels) {
            lines.append(DisplayLine(label: label62, token: .tealRamp1, isPlanned: plannedAge == 62))
        }
        if let fraLabel = availableLabels.first(where: { $0.hasSuffix("(FRA)") }) {
            let plannedIsFRA = plannedAge.map { matchingLabel(forAge: $0, in: availableLabels) == fraLabel } ?? false
            lines.append(DisplayLine(label: fraLabel, token: .heroTeal, isPlanned: plannedIsFRA))
        }
        if let label70 = matchingLabel(forAge: 70, in: availableLabels) {
            lines.append(DisplayLine(label: label70, token: .callout, isPlanned: plannedAge == 70))
        }
        if let plannedAge,
           let plannedLabel = matchingLabel(forAge: plannedAge, in: availableLabels),
           !lines.contains(where: { $0.label == plannedLabel }) {
            lines.append(DisplayLine(label: plannedLabel, token: .gray3, isPlanned: true))
        }

        return lines
    }

    private static func matchingLabel(forAge age: Int, in labels: [String]) -> String? {
        labels.first { $0 == "Claim at \(age)" || $0 == "Claim at \(age) (FRA)" }
    }
}

// MARK: - Cumulative Benefits Chart

struct SSCumulativeBenefitsChart: View {
    let chartData: [SSCumulativeChartPoint]
    let lifeExpectancy: Int
    let breakEvenComparisons: [SSBreakEvenComparison]
    let highlightClaimingAge: Int?

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

    /// The key claim-age lines to display (62, FRA, 70, plus the user's
    /// planned age when distinct) with their assigned color tokens. Both
    /// `chart` (data filter + color scale) and `legend` derive from this
    /// single source of truth so they can't drift apart.
    private var displayLines: [SSCumulativeChartColors.DisplayLine] {
        let availableLabels = Array(Set(chartData.map(\.scenarioLabel)))
        return SSCumulativeChartColors.displayLines(availableLabels: availableLabels, plannedAge: highlightClaimingAge)
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
        let lines = displayLines
        let displayedLabels = Set(lines.map(\.label))
        let plannedLabels = Set(lines.filter(\.isPlanned).map(\.label))

        return Chart {
            ForEach(chartData.filter { $0.age >= 62 && $0.age <= maxChartAge && displayedLabels.contains($0.scenarioLabel) }) { point in
                LineMark(
                    x: .value("Age", point.age),
                    y: .value("Cumulative", point.cumulativeAmount)
                )
                .foregroundStyle(by: .value("Strategy", point.scenarioLabel))
                .lineStyle(StrokeStyle(lineWidth: plannedLabels.contains(point.scenarioLabel) ? 3.5 : 2.5))
            }

            lifeExpectancyRule

            ForEach(validBreakEvenAges, id: \.self) { beAge in
                breakEvenRule(age: beAge)
            }
        }
        .chartForegroundStyleScale(domain: lines.map(\.label), range: lines.map(\.color))
        .chartXScale(domain: 62...maxChartAge)
        .chartXAxis { xAxisContent }
        .chartYAxis { yAxisContent }
        .chartLegend(.hidden)
    }

    private var lifeExpectancyRule: some ChartContent {
        RuleMark(x: .value("Planning Horizon", lifeExpectancy))
            .foregroundStyle(Color.Chart.gray3.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
            .annotation(position: .top, alignment: .trailing) {
                Text("Plan to: \(lifeExpectancy)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
    }

    private func breakEvenRule(age: Int) -> some ChartContent {
        RuleMark(x: .value("Break-even", age))
            .foregroundStyle(Color.Chart.gray2.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .annotation(position: .top, alignment: .leading) {
                Text("BE \(age)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.UI.textSecondary)
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
        let lines = displayLines
        return HStack(spacing: 16) {
            ForEach(lines, id: \.label) { line in
                HStack(spacing: 4) {
                    Circle()
                        .fill(line.color)
                        .frame(width: line.isPlanned ? 10 : 8, height: line.isPlanned ? 10 : 8)
                    Text(legendText(for: line))
                        .font(.caption)
                        .fontWeight(line.isPlanned ? .semibold : .regular)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Decorates the planned-age line's legend entry so "your plan" reads
    /// as special, without altering the underlying scenario label used to
    /// match chart data.
    private func legendText(for line: SSCumulativeChartColors.DisplayLine) -> String {
        line.isPlanned ? "\(line.label) (your plan)" : line.label
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
            BenefitBar(label: "Age 62", age: 62, amount: benefitAt62, color: Color.Chart.tealRamp1, isPlanned: plannedAge == 62),
            BenefitBar(label: "FRA", age: 67, amount: benefitAtFRA, color: Color.Chart.tealRamp3, isPlanned: plannedAge == 67),
            BenefitBar(label: "Age 70", age: 70, amount: benefitAt70, color: Color.Chart.tealRamp6, isPlanned: plannedAge == 70),
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
