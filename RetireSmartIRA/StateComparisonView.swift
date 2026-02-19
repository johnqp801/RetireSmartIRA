//
//  StateComparisonView.swift
//  RetireSmartIRA
//
//  Compares state income tax across all 50 states + DC for the user's
//  current income scenario, ranked from lowest to highest.
//

import SwiftUI

struct StateComparisonView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedStateForDetail: StateComparisonItem? = nil
    @State private var showingStateDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                currentStateCard
                rankingList
            }
            .padding()
        }
        .background(Color(PlatformColor.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Search states")
        .sheet(isPresented: $showingStateDetail) {
            if let item = selectedStateForDetail {
                StateTaxDetailSheet(
                    item: item,
                    breakdown: dataManager.stateTaxBreakdown(forState: item.state, filingStatus: dataManager.filingStatus),
                    currentStateBreakdown: dataManager.stateTaxBreakdown(forState: dataManager.selectedState, filingStatus: dataManager.filingStatus),
                    currentStateItem: currentStateItem
                )
            }
        }
    }

    // MARK: - Computed Data

    /// All states ranked by state tax (lowest to highest) for the current scenario.
    private var rankedStates: [StateComparisonItem] {
        let income = dataManager.scenarioTaxableIncome
        let fs = dataManager.filingStatus

        let items = USState.allCases.map { state -> StateComparisonItem in
            let tax = dataManager.calculateStateTax(income: income, forState: state, filingStatus: fs)
            let effectiveRate = income > 0 ? (tax / income) * 100 : 0
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

    /// The lowest-tax state (first in ranked list).
    private var lowestTaxState: StateComparisonItem? {
        rankedStates.first
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
        if let current = currentStateItem, let lowest = lowestTaxState {
            let savings = current.stateTax - lowest.stateTax

            Button {
                selectedStateForDetail = current
                showingStateDetail = true
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

                if savings > 1 {
                    Divider()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                        Text("You could save ")
                            .font(.callout)
                        + Text(savings, format: .currency(code: "USD"))
                            .font(.callout)
                            .fontWeight(.bold)
                        + Text("/year in a no-tax state")
                            .font(.callout)
                    }
                    .foregroundStyle(.green)
                } else if current.stateTax < 1 {
                    Divider()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("You're in a no/low income tax state!")
                            .font(.callout)
                            .foregroundStyle(.green)
                    }
                }
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
                    showingStateDetail = true
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
    let breakdown: DataManager.StateTaxBreakdown
    let currentStateBreakdown: DataManager.StateTaxBreakdown
    let currentStateItem: StateComparisonItem?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    stateHeaderSection
                    incomeBreakdownSection
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
            .navigationBarTitleDisplayMode(.inline)
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
    private func generateInsight() -> String {
        let state = breakdown.state.rawValue

        // No income tax
        if breakdown.totalStateTax == 0 && breakdown.flatRate == nil && breakdown.bracketBreakdown.isEmpty {
            return "\(state) has no state income tax. All of your retirement income — Social Security, pensions, IRA withdrawals — is completely tax-free at the state level."
        }

        // Large exemptions (> 50% of income exempted)
        if breakdown.totalExempted > breakdown.totalIncome * 0.5 && breakdown.totalExempted > 0 {
            let largestExemption: String
            if breakdown.socialSecurityExemptAmount >= breakdown.pensionExemptAmount && breakdown.socialSecurityExemptAmount >= breakdown.iraExemptAmount {
                largestExemption = "Social Security"
            } else if breakdown.pensionExemptAmount >= breakdown.iraExemptAmount {
                largestExemption = "pension income"
            } else {
                largestExemption = "IRA/RMD withdrawals"
            }
            return "\(state) offers generous retirement income exemptions. By exempting \(largestExemption) and other retirement income, your state-taxable income drops from \(breakdown.totalIncome.formatted(.currency(code: "USD"))) to just \(breakdown.adjustedTaxableIncome.formatted(.currency(code: "USD"))), significantly reducing your tax bill."
        }

        // Taxes Social Security (unusual — only ~8 states)
        if !breakdown.socialSecurityExempt && breakdown.socialSecurityIncome > 0 {
            return "Unlike most states, \(state) taxes Social Security benefits. This adds \(breakdown.socialSecurityIncome.formatted(.currency(code: "USD"))) to your state-taxable income that would be exempt in 42 other states."
        }

        // Comparison-based insight
        let diff = breakdown.totalStateTax - currentStateBreakdown.totalStateTax
        if item.state != currentStateBreakdown.state {
            if diff < -500 {
                return "Moving to \(state) would save you approximately \(abs(diff).formatted(.currency(code: "USD"))) per year in state income tax compared to \(currentStateBreakdown.state.rawValue)."
            } else if diff > 500 {
                return "\(state) would cost you approximately \(diff.formatted(.currency(code: "USD"))) more per year in state income tax than \(currentStateBreakdown.state.rawValue)."
            }
        }

        // Default: factual summary
        if let rate = breakdown.flatRate {
            return "\(state) uses a flat income tax rate of \(String(format: "%.2f%%", rate * 100)). All taxable income above exemptions is taxed at the same rate regardless of amount."
        } else if !breakdown.bracketBreakdown.isEmpty {
            let topRate = breakdown.bracketBreakdown.last?.rate ?? 0
            return "\(state) uses a progressive income tax with rates ranging from \(String(format: "%.1f%%", (breakdown.bracketBreakdown.first?.rate ?? 0) * 100)) to \(String(format: "%.1f%%", topRate * 100)). Your income is split across \(breakdown.bracketBreakdown.count) bracket\(breakdown.bracketBreakdown.count == 1 ? "" : "s")."
        }

        return "\(state) has a \(breakdown.taxSystemDescription.lowercased()) tax system."
    }
}

// MARK: - Preview

#Preview {
    StateComparisonView()
        .environmentObject(DataManager())
}
