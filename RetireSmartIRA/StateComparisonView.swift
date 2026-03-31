//
//  StateComparisonView.swift
//  RetireSmartIRA
//
//  Compares state income tax across all 50 states + DC for the user's
//  current income scenario, ranked from lowest to highest.
//

import SwiftUI
import Charts

struct StateComparisonView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedStateForDetail: StateComparisonItem? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                currentStateCard
                stateComparisonChart
                rankingList
            }
            .padding()
        }
        .background(Color(PlatformColor.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Search states")
        .sheet(item: $selectedStateForDetail) { item in
            StateTaxDetailSheet(
                item: item,
                breakdown: dataManager.stateTaxBreakdown(forState: item.state, filingStatus: dataManager.filingStatus),
                currentStateBreakdown: dataManager.stateTaxBreakdown(forState: dataManager.selectedState, filingStatus: dataManager.filingStatus),
                currentStateItem: currentStateItem
            )
        }
    }

    // MARK: - Computed Data

    /// All states ranked by state tax (lowest to highest) for the current scenario.
    private var rankedStates: [StateComparisonItem] {
        let grossIncome = dataManager.scenarioGrossIncome
        let fs = dataManager.filingStatus
        let taxableSS = dataManager.scenarioTaxableSocialSecurity

        let items = USState.allCases.map { state -> StateComparisonItem in
            let tax = dataManager.calculateStateTaxFromGross(grossIncome: grossIncome, forState: state, filingStatus: fs, taxableSocialSecurity: taxableSS)
            let effectiveRate = grossIncome > 0 ? (tax / grossIncome) * 100 : 0
            let config = StateTaxData.config(for: state)
            return StateComparisonItem(
                state: state,
                stateTax: tax,
                effectiveRate: effectiveRate,
                isCurrentState: state == dataManager.selectedState,
                taxSystemLabel: taxSystemLabel(for: config)
            )
        }

        let sorted = items.sorted { $0.stateTax < $1.stateTax }

        // Assign ranks (ties get same rank)
        var ranked: [StateComparisonItem] = []
        for (index, item) in sorted.enumerated() {
            let rank: Int
            if index > 0 && abs(item.stateTax - sorted[index - 1].stateTax) < 0.01 {
                rank = ranked[index - 1].rank  // same rank for ties
            } else {
                rank = index + 1
            }
            ranked.append(item.withRank(rank))
        }
        return ranked
    }

    /// Filtered states based on search text.
    private var filteredStates: [StateComparisonItem] {
        if searchText.isEmpty { return rankedStates }
        return rankedStates.filter {
            $0.state.rawValue.localizedCaseInsensitiveContains(searchText) ||
            $0.state.abbreviation.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// The current state's entry in the ranked list.
    private var currentStateItem: StateComparisonItem? {
        rankedStates.first { $0.isCurrentState }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("State Tax Comparison")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }

            Text("How your current income scenario would be taxed in every state")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Taxable Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dataManager.scenarioTaxableIncome, format: .currency(code: "USD"))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Filing Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dataManager.filingStatus.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }

            Text("Based on your income sources, deductions, and scenario decisions. Retirement income exemptions applied per state.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Current State Card

    @ViewBuilder
    private var currentStateCard: some View {
        if let current = currentStateItem {
            Button {
                selectedStateForDetail = current

            } label: {
            VStack(spacing: 10) {
                HStack {
                    Text("Your State: \(current.state.rawValue)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Text("#\(current.rank) of \(rankedStates.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(current.rank <= 10 ? .green : current.rank <= 30 ? .orange : .red)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("State Tax")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(current.stateTax, format: .currency(code: "USD"))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(current.stateTax == 0 ? .green : .primary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Effective Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f%%", current.effectiveRate))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }

                Divider()
                HStack(spacing: 4) {
                    Image(systemName: rankIcon(for: current))
                        .foregroundStyle(current.rank <= 10 ? .green : current.rank <= 30 ? .orange : .red)
                    Text("For your current plan, your state ranks ")
                        .font(.callout)
                    + Text("#\(current.rank)")
                        .font(.callout)
                        .fontWeight(.bold)
                    + Text(" for lowest state tax")
                        .font(.callout)
                }
                .foregroundStyle(current.rank <= 10 ? .green : current.rank <= 30 ? .orange : .red)
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - State Comparison Bar Chart

    /// Color for a bar based on where the state falls in the tax spectrum.
    /// Green → Teal → Gold → Orange → Pink → Purple → Blue as tax increases.
    private func barColor(for item: StateComparisonItem, maxTax: Double) -> Color {
        if item.isCurrentState { return Color(red: 0.15, green: 0.45, blue: 0.95) }
        if item.stateTax < 0.01 { return Color(red: 0.05, green: 0.78, blue: 0.35) }

        let ratio = maxTax > 0 ? min(item.stateTax / maxTax, 1.0) : 0

        // 5-stop spectrum: Green → Gold → Orange → Hot Pink → Purple → Blue
        if ratio < 0.2 {
            let t = ratio / 0.2
            // Green → Teal
            return Color(red: 0.05 - t * 0.05, green: 0.78 - t * 0.06, blue: 0.35 + t * 0.33)
        } else if ratio < 0.4 {
            let t = (ratio - 0.2) / 0.2
            // Teal → Gold
            return Color(red: 0.0 + t * 0.98, green: 0.72 + t * 0.06, blue: 0.68 - t * 0.68)
        } else if ratio < 0.6 {
            let t = (ratio - 0.4) / 0.2
            // Gold → Orange
            return Color(red: 0.98 + t * 0.02, green: 0.78 - t * 0.28, blue: 0.0)
        } else if ratio < 0.8 {
            let t = (ratio - 0.6) / 0.2
            // Orange → Hot Pink
            return Color(red: 1.0 - t * 0.08, green: 0.50 - t * 0.28, blue: 0.0 + t * 0.50)
        } else {
            let t = (ratio - 0.8) / 0.2
            // Hot Pink → Purple → Blue
            return Color(red: 0.92 - t * 0.74, green: 0.22 + t * 0.08, blue: 0.50 + t * 0.35)
        }
    }

    @ViewBuilder
    private var stateComparisonChart: some View {
        let data = rankedStates  // all 51 states, already sorted lowest → highest
        if !data.isEmpty {
            let maxTax = data.map(\.stateTax).max() ?? 1
            let yDomain = maxTax < 0.01 ? 100.0 : maxTax * 1.1
            let currentTax = currentStateItem?.stateTax ?? 0

            VStack(alignment: .leading, spacing: 14) {
                // Header with gradient icon
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.1, green: 0.78, blue: 0.45), Color(red: 0.95, green: 0.35, blue: 0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("State Tax Across All 50 States")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Annual state income tax for your current plan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Chart
                ScrollView(.horizontal, showsIndicators: false) {
                    Chart {
                        // Reference line at current state's tax level
                        if currentTax > 0.01 {
                            RuleMark(y: .value("Your Tax", currentTax))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                                .foregroundStyle(Color(red: 0.15, green: 0.45, blue: 0.95).opacity(0.6))
                                .annotation(position: .top, alignment: .leading) {
                                    Text("Your State: \(chartYAxisLabel(currentTax))")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color(red: 0.15, green: 0.45, blue: 0.95))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 0.15, green: 0.45, blue: 0.95).opacity(0.15))
                                        .clipShape(Capsule())
                                }
                        }

                        ForEach(data) { item in
                            BarMark(
                                x: .value("State", item.state.abbreviation),
                                y: .value("State Tax", item.stateTax),
                                width: .ratio(0.75)
                            )
                            .foregroundStyle(barColor(for: item, maxTax: maxTax))
                            .cornerRadius(2)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel {
                                if let abbrev = value.as(String.self) {
                                    let isCurrent = abbrev == dataManager.selectedState.abbreviation
                                    Text(abbrev)
                                        .font(.system(size: isCurrent ? 8 : 7, weight: isCurrent ? .heavy : .regular))
                                        .foregroundStyle(isCurrent ? Color(red: 0.15, green: 0.45, blue: 0.95) : .primary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .foregroundStyle(.gray.opacity(0.3))
                            AxisValueLabel {
                                if let val = value.as(Double.self) {
                                    Text(chartYAxisLabel(val))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXScale(domain: data.map { $0.state.abbreviation })
                    .chartYScale(domain: 0...yDomain)
                    .frame(width: max(CGFloat(data.count) * 20, 700), height: 260)
                }

                // Legend
                HStack(spacing: 16) {
                    chartLegendDot(color: Color(red: 0.15, green: 0.45, blue: 0.95), label: "Your state")
                    chartLegendDot(color: Color(red: 0.05, green: 0.78, blue: 0.35), label: "No/Low tax")
                    chartLegendDot(color: Color(red: 1.0, green: 0.50, blue: 0.0), label: "Medium tax")
                    chartLegendDot(color: Color(red: 0.18, green: 0.30, blue: 0.85), label: "High tax")
                }
                .font(.caption2)
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.78, blue: 0.35).opacity(0.4),
                                Color(red: 1.0, green: 0.50, blue: 0.0).opacity(0.35),
                                Color(red: 0.58, green: 0.22, blue: 0.88).opacity(0.4),
                                Color(red: 0.18, green: 0.30, blue: 0.85).opacity(0.4)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
    }

    private func chartLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    /// Compact y-axis label for currency values.
    private func chartYAxisLabel(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "$\(String(format: "%.0f", value / 1_000_000))M"
        } else if value >= 1_000 {
            return "$\(String(format: "%.0f", value / 1_000))K"
        } else if value < 0.01 {
            return "$0"
        } else {
            return "$\(String(format: "%.0f", value))"
        }
    }

    // MARK: - Ranking List

    private var rankingList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("All States Ranked")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("Lowest → Highest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ForEach(filteredStates) { item in
                Button {
                    selectedStateForDetail = item
    
                } label: {
                    stateRow(item)
                }
                .buttonStyle(.plain)
                if item.state != filteredStates.last?.state {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - State Row

    private func stateRow(_ item: StateComparisonItem) -> some View {
        HStack(spacing: 12) {
            // Rank badge
            Text("\(item.rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(rankColor(for: item))
                .clipShape(Circle())

            // State info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.state.rawValue)
                        .font(.subheadline)
                        .fontWeight(item.isCurrentState ? .bold : .regular)
                    if item.isCurrentState {
                        Text("YOU")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                Text(item.taxSystemLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Tax amount and rate
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.stateTax, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(item.stateTax == 0 ? .green : .primary)
                Text(String(format: "%.2f%%", item.effectiveRate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(item.isCurrentState ? Color.blue.opacity(0.08) : Color.clear)
    }

    // MARK: - Helpers

    /// Color for rank badge based on position.
    private func rankColor(for item: StateComparisonItem) -> Color {
        if item.stateTax < 1 { return .green }
        if item.rank <= 10 { return .green }
        if item.rank <= 25 { return .orange }
        return .red
    }

    /// Icon for the rank summary in the current state card.
    private func rankIcon(for item: StateComparisonItem) -> String {
        if item.rank <= 10 { return "checkmark.seal.fill" }
        if item.rank <= 30 { return "info.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    /// Human-readable label for a state's tax system.
    private func taxSystemLabel(for config: StateTaxConfig) -> String {
        switch config.taxSystem {
        case .noIncomeTax:
            return "No income tax"
        case .specialLimited:
            return "No general income tax"
        case .flat(let rate):
            return String(format: "Flat %.2f%%", rate * 100)
        case .progressive(let single, _):
            if let topRate = single.last?.rate {
                return String(format: "Progressive, up to %.1f%%", topRate * 100)
            }
            return "Progressive brackets"
        }
    }
}

// MARK: - Data Model

struct StateComparisonItem: Identifiable {
    let id = UUID()
    let state: USState
    let stateTax: Double
    let effectiveRate: Double
    let isCurrentState: Bool
    let taxSystemLabel: String
    var rank: Int = 0

    func withRank(_ rank: Int) -> StateComparisonItem {
        var copy = self
        copy.rank = rank
        return copy
    }
}

// MARK: - State Tax Detail Sheet

/// Detail sheet showing a full breakdown of how a state calculates income tax,
/// including retirement income exemptions, bracket-by-bracket calculations,
/// and a comparison to the user's current state.
private struct StateTaxDetailSheet: View {
    let item: StateComparisonItem
    let breakdown: StateTaxBreakdown
    let currentStateBreakdown: StateTaxBreakdown
    let currentStateItem: StateComparisonItem?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    stateHeaderSection
                    if item.state != currentStateBreakdown.state {
                        savingsHeadlineSection
                    }
                    if item.state != currentStateBreakdown.state {
                        exemptionComparisonSection
                    } else {
                        incomeBreakdownSection
                    }
                    taxCalculationSection
                    if item.state != currentStateBreakdown.state {
                        comparisonSection
                    }
                    insightSection
                }
                .padding()
            }
            .background(Color(PlatformColor.systemGroupedBackground))
            .navigationTitle(item.state.rawValue)
            #if os(iOS)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Section 1: State Header

    private var stateHeaderSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.state.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(breakdown.taxSystemDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("#\(item.rank)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(rankColor(for: item))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Section 1B: Savings/Cost Headline

    private var savingsHeadlineSection: some View {
        let diff = breakdown.totalStateTax - currentStateBreakdown.totalStateTax
        let absDiff = abs(diff)
        let isCheaper = diff < -1
        let isMoreExpensive = diff > 1
        let isNeutral = !isCheaper && !isMoreExpensive

        return VStack(spacing: 6) {
            if isNeutral {
                HStack(spacing: 6) {
                    Image(systemName: "equal.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("About the same as \(currentStateBreakdown.state.rawValue)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(absDiff, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(isCheaper ? .green : .red)

                Text(isCheaper ? "less per year" : "more per year")
                    .font(.headline)
                    .foregroundStyle(isCheaper ? .green : .red)

                Text("compared to \(currentStateBreakdown.state.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background((isNeutral ? Color.gray : (isCheaper ? Color.green : Color.red)).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Section 2A: Side-by-Side Exemption Comparison

    private var exemptionComparisonSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("How Each State Treats Your Income")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            Divider()

            // Column headers
            HStack {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.state.abbreviation)
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 80)
                Text(currentStateBreakdown.state.abbreviation)
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 80)
            }

            // Social Security row
            if breakdown.socialSecurityIncome > 0 || currentStateBreakdown.socialSecurityIncome > 0 {
                exemptionComparisonRow(
                    label: "Social Security",
                    amount: max(breakdown.socialSecurityIncome, currentStateBreakdown.socialSecurityIncome),
                    thisExempt: breakdown.socialSecurityExempt,
                    thisExemptAmount: breakdown.socialSecurityExemptAmount,
                    currentExempt: currentStateBreakdown.socialSecurityExempt,
                    currentExemptAmount: currentStateBreakdown.socialSecurityExemptAmount
                )
            }

            // Pension row
            if breakdown.pensionIncome > 0 || currentStateBreakdown.pensionIncome > 0 {
                let thisStatus = exemptionStatusText(breakdown.pensionExemptionLevel, exemptAmount: breakdown.pensionExemptAmount)
                let currentStatus = exemptionStatusText(currentStateBreakdown.pensionExemptionLevel, exemptAmount: currentStateBreakdown.pensionExemptAmount)
                let thisColor = exemptionStatusColor(breakdown.pensionExemptionLevel)
                let currentColor = exemptionStatusColor(currentStateBreakdown.pensionExemptionLevel)
                comparisonStatusRow(label: "Pension",
                                    amount: max(breakdown.pensionIncome, currentStateBreakdown.pensionIncome),
                                    thisStatus: thisStatus, thisColor: thisColor,
                                    currentStatus: currentStatus, currentColor: currentColor)
            }

            // IRA/RMD row
            if breakdown.iraRmdIncome > 0 || currentStateBreakdown.iraRmdIncome > 0 {
                let thisStatus = exemptionStatusText(breakdown.iraExemptionLevel, exemptAmount: breakdown.iraExemptAmount)
                let currentStatus = exemptionStatusText(currentStateBreakdown.iraExemptionLevel, exemptAmount: currentStateBreakdown.iraExemptAmount)
                let thisColor = exemptionStatusColor(breakdown.iraExemptionLevel)
                let currentColor = exemptionStatusColor(currentStateBreakdown.iraExemptionLevel)
                comparisonStatusRow(label: "IRA/RMD",
                                    amount: max(breakdown.iraRmdIncome, currentStateBreakdown.iraRmdIncome),
                                    thisStatus: thisStatus, thisColor: thisColor,
                                    currentStatus: currentStatus, currentColor: currentColor)
            }

            // Other income row
            if breakdown.otherIncome > 0 || currentStateBreakdown.otherIncome > 0 {
                comparisonStatusRow(label: "Other Income",
                                    amount: max(breakdown.otherIncome, currentStateBreakdown.otherIncome),
                                    thisStatus: "Taxed", thisColor: .red,
                                    currentStatus: "Taxed", currentColor: .red)
            }

            Divider()

            // Totals exempted comparison
            HStack {
                Text("Total Exempted")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(breakdown.totalExempted, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .frame(width: 80)
                Text(currentStateBreakdown.totalExempted, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .frame(width: 80)
            }



        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    /// Row for Social Security comparison (uses simple exempt/taxed).
    private func exemptionComparisonRow(label: String, amount: Double, thisExempt: Bool, thisExemptAmount: Double, currentExempt: Bool, currentExemptAmount: Double) -> some View {
        VStack(spacing: 2) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.subheadline)
                    Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(thisExempt ? "Exempt" : "Taxed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(thisExempt ? .green : .red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((thisExempt ? Color.green : Color.red).opacity(0.12))
                    .clipShape(Capsule())
                    .frame(width: 80)
                Text(currentExempt ? "Exempt" : "Taxed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(currentExempt ? .green : .red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((currentExempt ? Color.green : Color.red).opacity(0.12))
                    .clipShape(Capsule())
                    .frame(width: 80)
            }
        }
    }

    /// Row for pension/IRA comparison using status text and color.
    private func comparisonStatusRow(label: String, amount: Double, thisStatus: String, thisColor: Color, currentStatus: String, currentColor: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.subheadline)
                Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(thisStatus)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(thisColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(thisColor.opacity(0.12))
                .clipShape(Capsule())
                .frame(width: 80)
            Text(currentStatus)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(currentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(currentColor.opacity(0.12))
                .clipShape(Capsule())
                .frame(width: 80)
        }
    }




    // MARK: - Section 2: Income Breakdown with Exemptions

    private var incomeBreakdownSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Income & Exemptions")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            Text("How this state treats your retirement income")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Social Security
            if breakdown.socialSecurityIncome > 0 {
                exemptionRow(
                    label: "Social Security",
                    amount: breakdown.socialSecurityIncome,
                    exemptAmount: breakdown.socialSecurityExemptAmount,
                    statusText: breakdown.socialSecurityExempt ? "Exempt" : "Taxed",
                    statusColor: breakdown.socialSecurityExempt ? .green : .red
                )
            }

            // Pension
            if breakdown.pensionIncome > 0 {
                exemptionRow(
                    label: "Pension",
                    amount: breakdown.pensionIncome,
                    exemptAmount: breakdown.pensionExemptAmount,
                    statusText: exemptionStatusText(breakdown.pensionExemptionLevel, exemptAmount: breakdown.pensionExemptAmount),
                    statusColor: exemptionStatusColor(breakdown.pensionExemptionLevel)
                )
            }

            // IRA/RMD
            if breakdown.iraRmdIncome > 0 {
                exemptionRow(
                    label: "IRA/RMD",
                    amount: breakdown.iraRmdIncome,
                    exemptAmount: breakdown.iraExemptAmount,
                    statusText: exemptionStatusText(breakdown.iraExemptionLevel, exemptAmount: breakdown.iraExemptAmount),
                    statusColor: exemptionStatusColor(breakdown.iraExemptionLevel)
                )
            }

            // Other income
            if breakdown.otherIncome > 0 {
                exemptionRow(
                    label: "Other Income",
                    amount: breakdown.otherIncome,
                    exemptAmount: 0,
                    statusText: "Taxed",
                    statusColor: .red
                )
            }

            Divider()

            // Totals
            if breakdown.totalExempted > 0 {
                HStack {
                    Text("Total Exempted")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Spacer()
                    Text("-\(breakdown.totalExempted, format: .currency(code: "USD"))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Text("Adjusted Taxable Income")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text(breakdown.adjustedTaxableIncome, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Section 3: Tax Calculation

    private var taxCalculationSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tax Calculation")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            Divider()

            if !breakdown.bracketBreakdown.isEmpty {
                // Progressive bracket breakdown
                ForEach(breakdown.bracketBreakdown) { bracket in
                    HStack {
                        Text(bracketRangeText(floor: bracket.bracketFloor, ceiling: bracket.bracketCeiling))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "@ %.1f%%", bracket.rate * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("=")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(bracket.taxFromBracket, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(width: 80, alignment: .trailing)
                    }
                }

                Divider()
            } else if let rate = breakdown.flatRate {
                // Flat tax calculation
                HStack {
                    Text(breakdown.adjustedTaxableIncome, format: .currency(code: "USD"))
                        .font(.subheadline)
                    Text("×")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f%%", rate * 100))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("=")
                        .foregroundStyle(.secondary)
                    Text(breakdown.totalStateTax, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Divider()
            } else {
                // No income tax
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("This state does not levy an income tax.")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }

            // Total
            HStack {
                Text("Total State Tax")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text(breakdown.totalStateTax, format: .currency(code: "USD"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(breakdown.totalStateTax == 0 ? .green : .primary)
            }

            HStack {
                Text("Effective Rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f%%", breakdown.effectiveRate))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Section 4: Comparison to Current State

    private var comparisonSection: some View {
        let diff = breakdown.totalStateTax - currentStateBreakdown.totalStateTax
        let rateDiff = breakdown.effectiveRate - currentStateBreakdown.effectiveRate
        let isMoreExpensive = diff > 0

        return VStack(spacing: 8) {
            HStack {
                Text("vs. Your State (\(currentStateBreakdown.state.rawValue))")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            Divider()

            // Three-column comparison
            HStack(spacing: 0) {
                // Column headers
                VStack(alignment: .leading, spacing: 8) {
                    Text("")
                        .font(.caption)
                    Text("State Tax")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Eff. Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    Text(item.state.abbreviation)
                        .font(.caption)
                        .fontWeight(.bold)
                    Text(breakdown.totalStateTax, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(String(format: "%.2f%%", breakdown.effectiveRate))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    Text(currentStateBreakdown.state.abbreviation)
                        .font(.caption)
                        .fontWeight(.bold)
                    Text(currentStateBreakdown.totalStateTax, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(String(format: "%.2f%%", currentStateBreakdown.effectiveRate))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    Text("Diff")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text(diff, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isMoreExpensive ? .red : .green)
                    Text(String(format: "%+.2f%%", rateDiff))
                        .font(.caption)
                        .foregroundStyle(isMoreExpensive ? .red : .green)
                }
                .frame(maxWidth: .infinity)
            }

            if abs(diff) > 1 {
                Divider()
                HStack(spacing: 4) {
                    Image(systemName: isMoreExpensive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(isMoreExpensive ? .red : .green)
                    Text("\(item.state.rawValue) costs ")
                        .font(.callout)
                    + Text(abs(diff), format: .currency(code: "USD"))
                        .font(.callout)
                        .fontWeight(.bold)
                    + Text("/year \(isMoreExpensive ? "MORE" : "LESS") than \(currentStateBreakdown.state.rawValue)")
                        .font(.callout)
                }
                .foregroundStyle(isMoreExpensive ? .red : .green)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Section 5: Key Insight

    private var insightSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Key Insight")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            Divider()

            Text(generateInsight())
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Helpers

    /// Color for rank badge.
    private func rankColor(for item: StateComparisonItem) -> Color {
        if item.stateTax < 1 { return .green }
        if item.rank <= 10 { return .green }
        if item.rank <= 25 { return .orange }
        return .red
    }

    /// Row showing an income type with its exemption status.
    private func exemptionRow(label: String, amount: Double, exemptAmount: Double, statusText: String, statusColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    /// Human-readable exemption status.
    private func exemptionStatusText(_ level: RetirementIncomeExemptions.ExemptionLevel, exemptAmount: Double) -> String {
        switch level {
        case .full:
            return "Exempt"
        case .partial(let maxExempt):
            if exemptAmount >= maxExempt {
                return "First \(maxExempt.formatted(.currency(code: "USD").precision(.fractionLength(0)))) exempt"
            } else {
                return "Exempt"  // actual amount is less than cap, so fully exempt
            }
        case .none:
            return "Taxed"
        }
    }

    /// Color for exemption status badge.
    private func exemptionStatusColor(_ level: RetirementIncomeExemptions.ExemptionLevel) -> Color {
        switch level {
        case .full: return .green
        case .partial: return .orange
        case .none: return .red
        }
    }

    /// Format a bracket range like "$0–$10,000" or "$60,000+".
    private func bracketRangeText(floor: Double, ceiling: Double?) -> String {
        let floorStr = floor.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        if let ceiling {
            let ceilStr = ceiling.formatted(.currency(code: "USD").precision(.fractionLength(0)))
            return "\(floorStr)–\(ceilStr)"
        } else {
            return "\(floorStr)+"
        }
    }

    /// Generates a human-readable insight about this state's tax treatment.
    /// Always leads with a factual overview of the state's full tax system,
    /// then adds exemption and comparison details.
    private func generateInsight() -> String {
        let state = breakdown.state.rawValue
        let config = StateTaxData.config(for: item.state)
        var parts: [String] = []

        // Part 1: Tax system overview — uses the full state config, not just the user's brackets
        switch config.taxSystem {
        case .noIncomeTax:
            parts.append("\(state) does not levy a state income tax. All of your retirement income \u{2014} Social Security, pensions, IRA withdrawals \u{2014} is completely tax-free at the state level.")
        case .specialLimited:
            parts.append("\(state) does not tax general earned or retirement income. Only limited income types (such as interest, dividends, or capital gains) may be subject to state tax.")
        case .flat(let rate):
            parts.append("\(state) uses a flat income tax of \(String(format: "%.2f%%", rate * 100)) applied equally to all taxable income above exemptions.")
        case .progressive(let single, _):
            let lowRate = single.first?.rate ?? 0
            let topRate = single.last?.rate ?? 0
            let bracketCount = single.count
            parts.append("\(state) uses a progressive income tax with \(bracketCount) bracket\(bracketCount == 1 ? "" : "s"), ranging from \(String(format: "%.1f%%", lowRate * 100)) to \(String(format: "%.1f%%", topRate * 100)).")
        }

        // Part 2: Retirement income exemptions (only for states with an income tax)
        let hasTax: Bool
        switch config.taxSystem {
        case .noIncomeTax, .specialLimited: hasTax = false
        case .flat, .progressive: hasTax = true
        }
        if hasTax {
            var exemptions: [String] = []
            if breakdown.socialSecurityExempt && breakdown.socialSecurityIncome > 0 {
                exemptions.append("Social Security is exempt")
            } else if !breakdown.socialSecurityExempt && breakdown.socialSecurityIncome > 0 {
                exemptions.append("Social Security is taxed")
            }

            if breakdown.pensionIncome > 0 {
                switch breakdown.pensionExemptionLevel {
                case .full: exemptions.append("pensions are fully exempt")
                case .partial: exemptions.append("pensions are partially exempt")
                case .none: exemptions.append("pensions are fully taxed")
                }
            }

            if breakdown.iraRmdIncome > 0 {
                switch breakdown.iraExemptionLevel {
                case .full: exemptions.append("IRA/RMD withdrawals are fully exempt")
                case .partial: exemptions.append("IRA/RMD withdrawals are partially exempt")
                case .none: exemptions.append("IRA/RMD withdrawals are fully taxed")
                }
            }

            if !exemptions.isEmpty {
                let exemptionSummary = "For retirement income: " + exemptions.joined(separator: ", ") + "."
                parts.append(exemptionSummary)
            }

            // Highlight generous exemptions
            if breakdown.totalExempted > breakdown.totalIncome * 0.5 && breakdown.totalExempted > 0 {
                parts.append("These exemptions reduce your state-taxable income from \(breakdown.totalIncome.formatted(.currency(code: "USD"))) to \(breakdown.adjustedTaxableIncome.formatted(.currency(code: "USD"))).")
            }
        }

        // Part 3: Comparison to current state (only when viewing a different state)
        if item.state != currentStateBreakdown.state {
            let diff = breakdown.totalStateTax - currentStateBreakdown.totalStateTax
            if abs(diff) > 1 {
                let moreOrLess = diff > 0 ? "more" : "less"
                parts.append("Compared to \(currentStateBreakdown.state.rawValue), \(state) would cost \(abs(diff).formatted(.currency(code: "USD"))) \(moreOrLess) per year in state income tax.")
            } else {
                parts.append("State tax in \(state) is essentially the same as \(currentStateBreakdown.state.rawValue) for your income.")
            }
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Preview

#Preview {
    StateComparisonView()
        .environmentObject(DataManager())
}
