//
//  TaxPlanningView.swift
//  RetireSmartIRA
//
//  Tax planning and scenario modeling — unified with Roth conversion analysis
//

import SwiftUI

struct TaxPlanningView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWideLayout: Bool { horizontalSizeClass == .regular }

    // MARK: - Local UI state for stock text fields (sync to DataManager)
    @State private var stockPurchasePriceText: String = ""
    @State private var stockCurrentValueText: String = ""

    // MARK: - Section expansion (pure UI state)
    @State private var qcdSectionExpanded: Bool = true
    @State private var stockSectionExpanded: Bool = false
    @State private var cashSectionExpanded: Bool = false

    // MARK: - Computed helpers

    private var spouseEnabled: Bool { dataManager.enableSpouse }
    private var spouseLabel: String {
        dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
    }

    // RMDs
    private var yourRMD: Double {
        guard dataManager.isRMDRequired else { return 0 }
        return dataManager.calculatePrimaryRMD()
    }

    private var spouseRMD: Double {
        guard spouseEnabled && dataManager.spouseIsRMDRequired else { return 0 }
        return dataManager.calculateSpouseRMD()
    }

    private var combinedRMD: Double { yourRMD + spouseRMD }

    // Slider caps (based on each owner's traditional balance)
    private var yourSliderMax: Double {
        max(200_000, dataManager.primaryTraditionalIRABalance)
    }
    private var spouseSliderMax: Double {
        max(200_000, dataManager.spouseTraditionalIRABalance)
    }

    // Total Roth conversions & extra withdrawals
    private var totalRothConversion: Double {
        dataManager.yourRothConversion + (spouseEnabled ? dataManager.spouseRothConversion : 0)
    }
    private var totalExtraWithdrawal: Double {
        dataManager.yourExtraWithdrawal + (spouseEnabled ? dataManager.spouseExtraWithdrawal : 0)
    }

    // MARK: - Stock donation helpers

    private var stockPurchasePriceValue: Double { dataManager.stockPurchasePrice }
    private var stockCurrentValueNum: Double { dataManager.stockCurrentValue }

    private var stockIsLongTerm: Bool {
        guard let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) else { return false }
        return dataManager.stockPurchaseDate <= oneYearAgo
    }

    private var stockHoldingPeriodText: String {
        let components = Calendar.current.dateComponents([.year, .month], from: dataManager.stockPurchaseDate, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0
        if years > 0 && months > 0 {
            return "\(years)y \(months)m"
        } else if years > 0 {
            return "\(years)y"
        } else {
            return "\(months)m"
        }
    }

    /// Capital gain avoided by donating long-term stock instead of selling
    private var stockGainAvoided: Double {
        guard dataManager.stockDonationEnabled, stockIsLongTerm else { return 0 }
        return max(0, stockCurrentValueNum - stockPurchasePriceValue)
    }

    /// (Removed — avoided gains now subtracted from gross income in DataManager)

    // MARK: - QCD helpers

    private var qcdEligible: Bool {
        dataManager.isQCDEligible || (spouseEnabled && dataManager.spouseIsQCDEligible)
    }

    private var maxQCDAmount: Double {
        var cap = 0.0
        if dataManager.isQCDEligible { cap += 111_000 }
        if spouseEnabled && dataManager.spouseIsQCDEligible { cap += 111_000 }
        return cap
    }

    // MARK: - Withdrawal math

    /// RMD remaining after QCD offset
    private var adjustedCombinedRMD: Double {
        guard combinedRMD > 0 else { return 0 }
        return qcdEligible ? max(0, combinedRMD - dataManager.qcdAmount) : combinedRMD
    }

    /// Taxable withdrawals (QCD portion excluded from taxable income)
    private var totalWithdrawals: Double {
        let rmdTaxableAfterQCD = max(0, combinedRMD - (qcdEligible ? dataManager.qcdAmount : 0))
        return rmdTaxableAfterQCD + totalExtraWithdrawal
    }

    // MARK: - Income

    private var baseIncome: Double {
        dataManager.taxableIncome(filingStatus: dataManager.filingStatus)
    }

    private var itemizeDeductions: Bool { dataManager.scenarioEffectiveItemize }

    private var itemizeBinding: Binding<Bool> {
        Binding(
            get: { dataManager.scenarioEffectiveItemize },
            set: { newValue in dataManager.deductionOverride = newValue ? .itemized : .standard }
        )
    }

    private var taxableIncome: Double {
        dataManager.scenarioTaxableIncome
    }

    /// Total charitable giving for display
    private var totalCharitable: Double {
        var total = dataManager.qcdAmount
        if dataManager.stockDonationEnabled { total += stockCurrentValueNum }
        total += dataManager.cashDonationAmount
        return total
    }

    private var hasAnyCharitable: Bool {
        dataManager.qcdAmount > 0 || (dataManager.stockDonationEnabled && stockCurrentValueNum > 0) || dataManager.cashDonationAmount > 0
    }

    // MARK: - Opportunity window helpers

    private var showOpportunityWindow: Bool {
        (!dataManager.isRMDRequired && dataManager.primaryTraditionalIRABalance > 0)
        || (spouseEnabled && !dataManager.spouseIsRMDRequired && dataManager.spouseTraditionalIRABalance > 0)
    }

    // MARK: - Scenario analysis (live bracket/rate tracking)

    private var scenarioAnalysis: ScenarioTaxAnalysis? {
        let totalDistribution = totalRothConversion + totalWithdrawals
        guard totalDistribution > 0 || hasAnyCharitable else { return nil }
        return dataManager.analyzeScenario(
            baseIncome: baseIncome,
            scenarioIncome: taxableIncome
        )
    }

    // Bracket room at current scenario income
    private var federalBracketRoom: BracketInfo {
        dataManager.federalBracketInfo(income: taxableIncome, filingStatus: dataManager.filingStatus)
    }

    // Dynamic strategy tip
    private var bracketStrategyTitle: String {
        federalBracketRoom.roomRemaining > 0
            ? "Stay in Current Bracket"
            : "Top Federal Bracket"
    }

    private var bracketStrategyDescription: String {
        let room = federalBracketRoom
        let bracketPct = String(format: "%.0f", room.currentRate * 100)
        if room.roomRemaining > 0 {
            return "You can add up to \(room.roomRemaining.formatted(.currency(code: "USD"))) more and stay in the \(bracketPct)% federal bracket"
        } else {
            return "Already in the \(bracketPct)% federal bracket \u{2014} no ceiling on distributions within this rate"
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isWideLayout {
                wideBody
            } else {
                compactBody
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Populate text fields from DataManager on first appear
            if stockPurchasePriceText.isEmpty && dataManager.stockPurchasePrice > 0 {
                stockPurchasePriceText = String(format: "%.0f", dataManager.stockPurchasePrice)
            }
            if stockCurrentValueText.isEmpty && dataManager.stockCurrentValue > 0 {
                stockCurrentValueText = String(format: "%.0f", dataManager.stockCurrentValue)
            }
        }
        .onDisappear {
            dataManager.saveAllData()
        }
        .onChange(of: stockPurchasePriceText) { _, newValue in
            dataManager.stockPurchasePrice = Double(newValue.replacingOccurrences(of: ",", with: "")) ?? 0
            dataManager.saveAllData()
        }
        .onChange(of: stockCurrentValueText) { _, newValue in
            dataManager.stockCurrentValue = Double(newValue.replacingOccurrences(of: ",", with: "")) ?? 0
            dataManager.saveAllData()
        }
    }

    // MARK: - Layout variants

    private var compactBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard
                opportunityWindowSection
                rothConversionSection
                withdrawalSection
                charitableSection
                taxImpactSection
                perDecisionImpact
                rateBreakdownSection
                bracketAnalysisSection
                strategyTipsSection
            }
            .padding()
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left: scenario inputs
            ScrollView {
                VStack(spacing: 24) {
                    summaryCard
                    opportunityWindowSection
                    rothConversionSection
                    withdrawalSection
                    charitableSection
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            // Right: tax results & analysis
            ScrollView {
                VStack(spacing: 24) {
                    taxImpactSection
                    perDecisionImpact
                    rateBreakdownSection
                    bracketAnalysisSection
                    strategyTipsSection
                    emptyAnalysisPlaceholder
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Empty Analysis Placeholder

    @ViewBuilder
    private var emptyAnalysisPlaceholder: some View {
        if scenarioAnalysis == nil && !hasAnyCharitable
            && totalRothConversion == 0 && totalWithdrawals == 0 {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Tax Analysis")
                    .font(.headline)
                Text("Adjust conversions, withdrawals, or charitable contributions to see real-time tax impact here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tax Planning Scenario")
                .font(.title2)
                .fontWeight(.bold)

            Text("Model Roth conversions, withdrawals, and charitable giving to find your optimal tax strategy.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Income from Sources")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(baseIncome, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Taxable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(taxableIncome, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(totalRothConversion > 0 || totalWithdrawals > 0 || hasAnyCharitable ? .orange : .primary)
                }
            }

            Text("Before RMDs, conversions, withdrawals, and charitable contributions")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .italic()

            if spouseEnabled {
                Text("Filing jointly \u{2013} all scenarios model joint tax impact")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Deduction Comparison Card

    private var deductionComparisonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            let standard = dataManager.standardDeductionAmount
            let itemized = dataManager.totalItemizedDeductions
            let recommended = dataManager.recommendedDeductionType

            HStack(spacing: 0) {
                // Standard side
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Standard")
                            .font(.caption)
                            .fontWeight(.semibold)
                        if recommended == .standard {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                    Text(standard, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(recommended == .standard ? .green : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("|")
                    .foregroundStyle(.separator)

                // Itemized side
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        if recommended == .itemized {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        Text("Itemized")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    Text(itemized, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(recommended == .itemized ? .green : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Segmented control: Auto / Standard / Itemized
            Picker("Deduction Method", selection: Binding(
                get: {
                    if dataManager.deductionOverride == nil { return 0 }
                    return dataManager.deductionOverride == .standard ? 1 : 2
                },
                set: { tag in
                    switch tag {
                    case 1: dataManager.deductionOverride = .standard
                    case 2: dataManager.deductionOverride = .itemized
                    default: dataManager.deductionOverride = nil
                    }
                }
            )) {
                Text("Auto").tag(0)
                Text("Standard").tag(1)
                Text("Itemized").tag(2)
            }
            .pickerStyle(.segmented)

            if !itemizeDeductions {
                Text("Standard deduction selected \u{2014} stock and cash donations will not reduce taxable income")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .italic()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Per-Decision Tax Impact

    @ViewBuilder
    private var perDecisionImpact: some View {
        if dataManager.hasActiveScenario {
            VStack(alignment: .leading, spacing: 12) {
                Text("Per-Decision Tax Impact")
                    .font(.headline)

                var netImpact: Double = 0

                if dataManager.scenarioTotalRothConversion > 0 {
                    let impact = dataManager.rothConversionTaxImpact
                    let _ = netImpact += impact
                    impactRow(label: "Roth Conversions", amount: impact, isPositive: false, color: .purple)
                }

                if dataManager.scenarioTotalExtraWithdrawal > 0 {
                    let impact = dataManager.extraWithdrawalTaxImpact
                    let _ = netImpact += impact
                    impactRow(label: "Extra Withdrawals", amount: impact, isPositive: false, color: .blue)
                }

                if dataManager.qcdAmount > 0 {
                    let savings = dataManager.qcdTaxSavings
                    let _ = netImpact -= savings
                    impactRow(label: "QCD", amount: savings, isPositive: true, color: .green)
                    Text("QCD also lowers your Adjusted Gross Income (AGI), which may provide additional savings not shown here — such as lower Medicare IRMAA premiums and reduced Social Security taxation.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 28)
                        .padding(.top, -4)
                }

                if dataManager.stockDonationEnabled && dataManager.stockCurrentValue > 0 {
                    let savings = dataManager.stockDonationTaxSavings
                    let _ = netImpact -= savings
                    impactRow(label: "Stock Donation", amount: savings, isPositive: true, color: .orange)
                }

                if dataManager.cashDonationAmount > 0 {
                    let savings = dataManager.cashDonationTaxSavings
                    let _ = netImpact -= savings
                    impactRow(label: "Cash Donation", amount: savings, isPositive: true, color: .teal)
                }

                Divider()

                // Net impact
                let displayNet = dataManager.rothConversionTaxImpact + dataManager.extraWithdrawalTaxImpact
                    - dataManager.qcdTaxSavings - dataManager.stockDonationTaxSavings - dataManager.cashDonationTaxSavings

                HStack {
                    Text("Net Tax Impact")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(displayNet >= 0 ? "+" : "")\(displayNet.formatted(.currency(code: "USD")))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(displayNet >= 0 ? .red : .green)
                }

                Text("Approximate \u{2014} individual impacts may not sum exactly to net due to progressive tax interaction")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    private func impactRow(label: String, amount: Double, isPositive: Bool, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(isPositive ? "saves" : "adds") ~\(amount.formatted(.currency(code: "USD")))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isPositive ? .green : .red)
        }
    }

    // MARK: - Opportunity Window

    @ViewBuilder
    private var opportunityWindowSection: some View {
        if showOpportunityWindow {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Conversion Opportunity Window")
                        .font(.headline)
                }

                if !dataManager.isRMDRequired && dataManager.primaryTraditionalIRABalance > 0 {
                    Text("You have \(dataManager.yearsUntilRMD) years before RMDs start. This is an ideal time for Roth conversions while potentially in a lower tax bracket.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if spouseEnabled && !dataManager.spouseIsRMDRequired && dataManager.spouseTraditionalIRABalance > 0 {
                    Text("\(spouseLabel) has \(dataManager.spouseYearsUntilRMD) years before RMDs start.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Roth Conversion Section

    private var rothConversionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Roth Conversions")
                .font(.headline)

            // Your Roth conversion
            ConversionSliderCard(
                label: spouseEnabled ? "Your Conversion" : "Conversion Amount",
                icon: spouseEnabled ? "person.fill" : nil,
                balance: dataManager.primaryTraditionalIRABalance,
                amount: $dataManager.yourRothConversion,
                sliderMax: yourSliderMax,
                tint: .orange
            )

            // Spouse Roth conversion
            if spouseEnabled && dataManager.spouseTraditionalIRABalance > 0 {
                ConversionSliderCard(
                    label: "\(spouseLabel)'s Conversion",
                    icon: "person.fill",
                    balance: dataManager.spouseTraditionalIRABalance,
                    amount: $dataManager.spouseRothConversion,
                    sliderMax: spouseSliderMax,
                    tint: .orange
                )
            }

            // Combined total
            if spouseEnabled && (dataManager.yourRothConversion > 0 || dataManager.spouseRothConversion > 0) {
                Divider()
                HStack {
                    Text("Combined Roth Conversions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(totalRothConversion, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
            }

            // Bracket room indicator
            if totalRothConversion > 0 || totalExtraWithdrawal > 0 {
                let room = federalBracketRoom
                let bracketPct = String(format: "%.0f", room.currentRate * 100)
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    if room.roomRemaining > 0 {
                        Text("Federal: \(room.roomRemaining.formatted(.currency(code: "USD"))) remaining in \(bracketPct)% bracket")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Federal: At top of \(bracketPct)% bracket")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Withdrawal Section

    private var withdrawalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("IRA/401(k) Withdrawals")
                .font(.headline)

            // Your RMD & extra withdrawal
            if dataManager.primaryTraditionalIRABalance > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    if spouseEnabled {
                        Label("Your Withdrawals", systemImage: "person.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    if dataManager.isRMDRequired {
                        HStack {
                            Text("Required RMD")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(yourRMD, format: .currency(code: "USD"))
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                    }

                    WithdrawalSliderCard(
                        label: "Extra Withdrawal",
                        amount: $dataManager.yourExtraWithdrawal,
                        sliderMax: 200_000,
                        tint: .blue
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Spouse RMD & extra withdrawal
            if spouseEnabled && dataManager.spouseTraditionalIRABalance > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Label("\(spouseLabel)'s Withdrawals", systemImage: "person.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if dataManager.spouseIsRMDRequired {
                        HStack {
                            Text("Required RMD")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(spouseRMD, format: .currency(code: "USD"))
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                    } else {
                        HStack {
                            Text("RMD")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Not yet required")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    WithdrawalSliderCard(
                        label: "Extra Withdrawal",
                        amount: $dataManager.spouseExtraWithdrawal,
                        sliderMax: 200_000,
                        tint: .blue
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Combined totals
            if totalWithdrawals > 0 {
                Divider()

                if spouseEnabled && combinedRMD > 0 {
                    HStack {
                        Text("Combined RMDs")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(combinedRMD, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                }

                HStack {
                    Text(spouseEnabled ? "Combined Total Distribution" : "Total IRA/401(k) Distribution")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(totalWithdrawals, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Charitable Section

    private var charitableSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Charitable Contributions")
                    .font(.headline)
                Spacer()
                if hasAnyCharitable {
                    Text("Total: \(totalCharitable, format: .currency(code: "USD"))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }

            // Deduction comparison card
            deductionComparisonCard

            Divider()

            // MARK: QCD Sub-section
            DisclosureGroup(isExpanded: $qcdSectionExpanded) {
                if qcdEligible {
                    VStack(spacing: 12) {
                        HStack {
                            Text("QCD Amount")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(dataManager.qcdAmount, format: .currency(code: "USD"))
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }

                        if maxQCDAmount > 0 {
                            Slider(value: $dataManager.qcdAmount, in: 0...maxQCDAmount, step: 500)
                                .tint(.green)

                            HStack {
                                Text("$0")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Max: \(maxQCDAmount, format: .currency(code: "USD"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("No eligible accounts for QCD")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                        }

                        if dataManager.qcdAmount > 0 && combinedRMD > 0 {
                            Divider()
                            HStack {
                                Text("RMD Satisfied by QCD")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(min(dataManager.qcdAmount, combinedRMD), format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            }
                            HStack {
                                Text("Remaining RMD")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(adjustedCombinedRMD, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(adjustedCombinedRMD > 0 ? .red : .green)
                            }
                        }

                        if dataManager.qcdAmount > 0 && combinedRMD == 0 {
                            Divider()
                            Text("No RMD requirement yet \u{2014} QCD is excluded from taxable income as a direct IRA-to-charity transfer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Text("QCD requires age 70\u{00BD} or older")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.top, 8)
                }
            } label: {
                HStack {
                    Image(systemName: "heart.circle.fill")
                        .foregroundStyle(.green)
                    Text("QCD \u{2014} From RMD")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            Divider()

            // MARK: Appreciated Stock Sub-section
            DisclosureGroup(isExpanded: $stockSectionExpanded) {
                VStack(spacing: 12) {
                    Toggle("Enable Stock Donation", isOn: $dataManager.stockDonationEnabled)
                        .font(.subheadline)

                    if dataManager.stockDonationEnabled {
                        VStack(spacing: 10) {
                            HStack {
                                Text("Purchase Price")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                HStack {
                                    Text("$")
                                        .foregroundStyle(.secondary)
                                    TextField("0", text: $stockPurchasePriceText)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 120)
                                }
                            }

                            HStack {
                                Text("Current Value")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                HStack {
                                    Text("$")
                                        .foregroundStyle(.secondary)
                                    TextField("0", text: $stockCurrentValueText)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 120)
                                }
                            }

                            DatePicker("Purchase Date", selection: $dataManager.stockPurchaseDate, in: ...Date(), displayedComponents: .date)
                                .font(.callout)
                        }

                        if stockCurrentValueNum > 0 || stockPurchasePriceValue > 0 {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Holding Period")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(stockHoldingPeriodText) (\(stockIsLongTerm ? "Long-term \u{2713}" : "Short-term"))")
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(stockIsLongTerm ? .green : .red)
                                }

                                if !stockIsLongTerm {
                                    Text("Short-term holding \u{2014} only cost basis is deductible, not fair market value")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                        .italic()
                                }

                                if stockCurrentValueNum > stockPurchasePriceValue {
                                    HStack {
                                        Text("Unrealized Gain")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(stockCurrentValueNum - stockPurchasePriceValue, format: .currency(code: "USD"))
                                            .font(.callout)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.green)
                                    }

                                    if stockIsLongTerm {
                                        HStack {
                                            Text("Capital Gains Tax Avoided")
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(stockGainAvoided, format: .currency(code: "USD"))
                                                .font(.callout)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.green)
                                        }
                                        .padding(.leading, 8)
                                    }
                                } else if stockCurrentValueNum > 0 {
                                    Text("No unrealized gain \u{2014} consider cash donation instead")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .italic()
                                }

                                if itemizeDeductions {
                                    HStack {
                                        Text("Deduction")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        let deduction = stockIsLongTerm ? stockCurrentValueNum : stockPurchasePriceValue
                                        Text(deduction, format: .currency(code: "USD"))
                                            .font(.callout)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.orange)
                                    }
                                    Text(stockIsLongTerm ? "Fair market value deduction" : "Cost basis deduction (short-term)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Appreciated Stock Donation")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            Divider()

            // MARK: Cash/Bank Sub-section
            DisclosureGroup(isExpanded: $cashSectionExpanded) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Cash Donation Amount")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(dataManager.cashDonationAmount, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                    }

                    Slider(value: $dataManager.cashDonationAmount, in: 0...200_000, step: 500)
                        .tint(.purple)

                    HStack {
                        Text("$0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("$200,000")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if dataManager.cashDonationAmount > 0 {
                        Divider()
                        HStack {
                            Text(itemizeDeductions ? "Tax Deduction" : "No Tax Benefit")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(itemizeDeductions ? dataManager.cashDonationAmount : 0, format: .currency(code: "USD"))
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(itemizeDeductions ? .orange : .red)
                        }

                        if !itemizeDeductions {
                            Text("Taking standard deduction \u{2014} cash donations don't reduce taxes")
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .italic()
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Image(systemName: "banknote.fill")
                        .foregroundStyle(.purple)
                    Text("Cash / Bank Account Donation")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Tax Impact Section

    @ViewBuilder
    private var taxImpactSection: some View {
        if totalRothConversion > 0 || totalWithdrawals > 0 || hasAnyCharitable {
            TaxImpactView(
                yourRothAmount: dataManager.yourRothConversion,
                spouseRothAmount: spouseEnabled ? dataManager.spouseRothConversion : 0,
                yourWithdrawalAmount: yourRMD + dataManager.yourExtraWithdrawal,
                spouseWithdrawalAmount: spouseEnabled ? (spouseRMD + dataManager.spouseExtraWithdrawal) : 0,
                totalWithdrawals: totalWithdrawals,
                totalRothConversion: totalRothConversion,
                qcdAmount: dataManager.qcdAmount,
                stockDonationValue: dataManager.stockDonationEnabled ? stockCurrentValueNum : 0,
                stockDonationGain: stockGainAvoided,
                cashDonationAmount: dataManager.cashDonationAmount,
                itemizeDeductions: itemizeDeductions,
                baseIncome: baseIncome,
                spouseEnabled: spouseEnabled,
                spouseLabel: spouseLabel
            )
        }
    }

    // MARK: - Rate Breakdown Section

    @ViewBuilder
    private var rateBreakdownSection: some View {
        if let analysis = scenarioAnalysis {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tax Rate Breakdown")
                    .font(.headline)

                // Column headers
                HStack {
                    Text("")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Federal")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                    Text("California")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                }

                RateRow(
                    label: "Marginal (Before)",
                    federalRate: analysis.federalMarginalBefore,
                    stateRate: analysis.stateMarginalBefore,
                    highlight: false
                )

                RateRow(
                    label: "Marginal (After)",
                    federalRate: analysis.federalMarginalAfter,
                    stateRate: analysis.stateMarginalAfter,
                    highlight: analysis.crossesFederalBracket || analysis.crossesStateBracket
                )

                Divider()

                RateRow(
                    label: "Effective on Scenario",
                    federalRate: analysis.federalEffectiveRate * 100,
                    stateRate: analysis.stateEffectiveRate * 100,
                    highlight: false
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Bracket Analysis Section

    @ViewBuilder
    private var bracketAnalysisSection: some View {
        if let analysis = scenarioAnalysis {
            VStack(alignment: .leading, spacing: 16) {
                Text("Bracket Analysis")
                    .font(.headline)

                BracketAnalysisCard(
                    title: "Federal",
                    bracketBefore: analysis.federalBracketBefore,
                    bracketAfter: analysis.federalBracketAfter,
                    marginalBefore: analysis.federalMarginalBefore,
                    marginalAfter: analysis.federalMarginalAfter,
                    crosses: analysis.crossesFederalBracket,
                    color: .blue
                )

                BracketAnalysisCard(
                    title: "California",
                    bracketBefore: analysis.stateBracketBefore,
                    bracketAfter: analysis.stateBracketAfter,
                    marginalBefore: analysis.stateMarginalBefore,
                    marginalAfter: analysis.stateMarginalAfter,
                    crosses: analysis.crossesStateBracket,
                    color: .orange
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Strategy Tips Section

    @ViewBuilder
    private var strategyTipsSection: some View {
        if dataManager.totalTraditionalIRABalance > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Conversion Strategies")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    StrategyTip(
                        icon: "chart.bar.fill",
                        title: bracketStrategyTitle,
                        description: bracketStrategyDescription
                    )

                    StrategyTip(
                        icon: "calendar.badge.clock",
                        title: "Multi-Year Strategy",
                        description: "Spread conversions over several years before RMDs start"
                    )

                    StrategyTip(
                        icon: "dollarsign.circle",
                        title: "Pay Tax from Other Funds",
                        description: "Use non-retirement money to pay conversion tax for maximum benefit"
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }
}

// MARK: - Conversion Slider Card

struct ConversionSliderCard: View {
    let label: String
    var icon: String?
    let balance: Double
    @Binding var amount: Double
    let sliderMax: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                if let icon = icon {
                    Label(label, systemImage: icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(amount, format: .currency(code: "USD"))
                    .fontWeight(.semibold)
            }

            Slider(value: $amount, in: 0...sliderMax, step: 1_000)
                .tint(tint)

            HStack {
                Text("$0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Balance: \(balance, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Withdrawal Slider Card

struct WithdrawalSliderCard: View {
    let label: String
    @Binding var amount: Double
    let sliderMax: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(amount, format: .currency(code: "USD"))
                    .fontWeight(.semibold)
            }

            Slider(value: $amount, in: 0...sliderMax, step: 1_000)
                .tint(tint)

            HStack {
                Text("$0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("$200,000")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Tax Impact View

struct TaxImpactView: View {
    let yourRothAmount: Double
    let spouseRothAmount: Double
    let yourWithdrawalAmount: Double
    let spouseWithdrawalAmount: Double
    let totalWithdrawals: Double
    let totalRothConversion: Double
    let qcdAmount: Double
    let stockDonationValue: Double
    let stockDonationGain: Double
    let cashDonationAmount: Double
    let itemizeDeductions: Bool
    let baseIncome: Double
    let spouseEnabled: Bool
    let spouseLabel: String
    @EnvironmentObject var dataManager: DataManager

    private var totalDistribution: Double {
        totalRothConversion + totalWithdrawals
    }

    private var totalCharitable: Double {
        qcdAmount + stockDonationValue + cashDonationAmount
    }

    private var adjustedTaxableIncome: Double {
        var income = baseIncome + totalRothConversion + totalWithdrawals

        // Stock donation FMV deduction (if itemizing and long-term — gain > 0 implies long-term)
        if stockDonationValue > 0 && itemizeDeductions {
            income -= stockDonationValue
        }

        // Cash donation deduction (if itemizing)
        if cashDonationAmount > 0 && itemizeDeductions {
            income -= cashDonationAmount
        }

        return max(0, income)
    }

    private var scenarioAnalysis: ScenarioTaxAnalysis {
        dataManager.analyzeScenario(
            baseIncome: baseIncome,
            scenarioIncome: adjustedTaxableIncome
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tax Impact")
                .font(.headline)

            if spouseEnabled {
                Text("Joint filing \u{2013} combined tax liability")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Per-person breakdown
            if spouseEnabled && totalDistribution > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Distribution Breakdown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Your distributions
                    if yourRothAmount > 0 || yourWithdrawalAmount > 0 {
                        HStack {
                            Label("You", systemImage: "person.fill")
                                .font(.callout)
                            Spacer()
                        }

                        if yourRothAmount > 0 {
                            HStack {
                                Text("  Roth Conversion")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(yourRothAmount, format: .currency(code: "USD"))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        if yourWithdrawalAmount > 0 {
                            HStack {
                                Text("  Withdrawal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(yourWithdrawalAmount, format: .currency(code: "USD"))
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    // Spouse distributions
                    if spouseRothAmount > 0 || spouseWithdrawalAmount > 0 {
                        HStack {
                            Label(spouseLabel, systemImage: "person.fill")
                                .font(.callout)
                            Spacer()
                        }
                        .padding(.top, 4)

                        if spouseRothAmount > 0 {
                            HStack {
                                Text("  Roth Conversion")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(spouseRothAmount, format: .currency(code: "USD"))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        if spouseWithdrawalAmount > 0 {
                            HStack {
                                Text("  Withdrawal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(spouseWithdrawalAmount, format: .currency(code: "USD"))
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Text("Total Distribution")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(totalDistribution, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else if !spouseEnabled && totalRothConversion > 0 && totalWithdrawals > 0 {
                // Single-person combined breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("Distribution Breakdown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Roth Conversion")
                            .font(.callout)
                        Spacer()
                        Text(totalRothConversion, format: .currency(code: "USD"))
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }

                    HStack {
                        Text("IRA/401(k) Withdrawal")
                            .font(.callout)
                        Spacer()
                        Text(totalWithdrawals, format: .currency(code: "USD"))
                            .font(.callout)
                            .foregroundStyle(.blue)
                    }

                    Divider()

                    HStack {
                        Text("Total Distribution")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(totalDistribution, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Charitable giving summary
            if totalCharitable > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Charitable Giving Summary")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if qcdAmount > 0 {
                        HStack {
                            Text("QCD from RMD")
                                .font(.callout)
                            Spacer()
                            Text(qcdAmount, format: .currency(code: "USD"))
                                .font(.callout)
                                .foregroundStyle(.green)
                        }
                    }

                    if stockDonationValue > 0 {
                        HStack {
                            Text("Appreciated Stock")
                                .font(.callout)
                            Spacer()
                            Text(stockDonationValue, format: .currency(code: "USD"))
                                .font(.callout)
                                .foregroundStyle(.green)
                        }

                        if stockDonationGain > 0 {
                            Text("  Gain of \(stockDonationGain, format: .currency(code: "USD")) not taxed")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    if cashDonationAmount > 0 {
                        HStack {
                            Text("Cash Donation")
                                .font(.callout)
                            Spacer()
                            Text(cashDonationAmount, format: .currency(code: "USD"))
                                .font(.callout)
                                .foregroundStyle(itemizeDeductions ? .orange : .red)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Total Charitable")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(totalCharitable, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
            }

            // Tax numbers
            VStack(spacing: 12) {
                HStack {
                    Text("Federal Tax")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(scenarioAnalysis.federalTax, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }

                HStack {
                    Text("State Tax")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(scenarioAnalysis.stateTax, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }

                Divider()

                HStack {
                    Text("Total Additional Tax")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(scenarioAnalysis.totalTax, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                }

                if totalDistribution > 0 {
                    HStack {
                        Text("Effective Rate on Distributions")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(scenarioAnalysis.effectiveRate * 100, specifier: "%.1f")%")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct TaxPlanningView_Previews: PreviewProvider {
    static var previews: some View {
        TaxPlanningView()
            .environmentObject(DataManager())
    }
}
