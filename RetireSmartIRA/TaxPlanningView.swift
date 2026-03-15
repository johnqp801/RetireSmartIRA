//
//  TaxPlanningView.swift
//  RetireSmartIRA
//
//  Scenario modeling — Roth conversions, withdrawals, and charitable giving
//

import SwiftUI
import Charts

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
    @State private var showResetConfirmation: Bool = false

    // MARK: - Sheet presentation state for scenario steps
    @State private var showRothSheet: Bool = false
    @State private var showWithdrawalSheet: Bool = false
    @State private var showInheritedSheet: Bool = false
    @State private var showCharitableSheet: Bool = false
    @State private var showRothGuide: Bool = false
    @State private var showCharitableGuide: Bool = false
    @State private var showLegacyDetails: Bool = false

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

    /// Unrealized gain avoided by donating stock instead of selling
    private var stockGainAvoided: Double {
        guard dataManager.stockDonationEnabled else { return 0 }
        return max(0, stockCurrentValueNum - stockPurchasePriceValue)
    }

    /// (Removed — avoided gains now subtracted from gross income in DataManager)

    // MARK: - QCD helpers

    private var qcdEligible: Bool {
        dataManager.isQCDEligible || (spouseEnabled && dataManager.spouseIsQCDEligible)
    }

    private var yourMaxQCD: Double {
        dataManager.yourMaxQCDAmount
    }

    private var spouseMaxQCD: Double {
        dataManager.spouseMaxQCDAmount
    }

    private var totalQCD: Double {
        dataManager.yourQCDAmount + (spouseEnabled ? dataManager.spouseQCDAmount : 0)
    }

    // MARK: - Withdrawal math

    /// RMD remaining after QCD offset
    private var adjustedCombinedRMD: Double {
        guard combinedRMD > 0 else { return 0 }
        return qcdEligible ? max(0, combinedRMD - totalQCD) : combinedRMD
    }

    /// Taxable withdrawals (QCD portion excluded from taxable income)
    private var totalWithdrawals: Double {
        let rmdTaxableAfterQCD = max(0, combinedRMD - (qcdEligible ? totalQCD : 0))
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
        var total = totalQCD
        if dataManager.stockDonationEnabled { total += stockCurrentValueNum }
        total += dataManager.cashDonationAmount
        return total
    }

    private var hasAnyCharitable: Bool {
        totalQCD > 0 || (dataManager.stockDonationEnabled && stockCurrentValueNum > 0) || dataManager.cashDonationAmount > 0
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
        .background(Color(PlatformColor.systemGroupedBackground))
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
        .onChange(of: dataManager.yourWithdrawalQuarter) { dataManager.saveAllData() }
        .onChange(of: dataManager.spouseWithdrawalQuarter) { dataManager.saveAllData() }
        .onChange(of: dataManager.yourRothConversionQuarter) { dataManager.saveAllData() }
        .onChange(of: dataManager.spouseRothConversionQuarter) { dataManager.saveAllData() }
    }

    // MARK: - Layout variants

    private var compactBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard
                opportunityWindowSection
                rothConversionCard
                rothConversionGuideCard
                withdrawalCard
                inheritedWithdrawalCard
                charitableCard
                charitableGuideCard
                scenarioSummaryCard
                taxImpactWaterfallChart
                scenarioFederalBracketChart
                scenarioStateBracketChart
                scenarioIRMAAChart
                scenarioNIITChart
                legacyImpactCard
                perDecisionImpact
                strategyTipsSection
            }
            .padding()
        }
        .sheet(isPresented: $showRothGuide) {
            rothConversionGuideSheet
        }
        .sheet(isPresented: $showCharitableGuide) {
            charitableGuideSheet
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left: scenario inputs
            ScrollView {
                VStack(spacing: 24) {
                    summaryCard
                    opportunityWindowSection
                    rothConversionCard
                    rothConversionGuideCard
                    withdrawalCard
                    inheritedWithdrawalCard
                    charitableCard
                    charitableGuideCard
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            // Right: tax results & analysis
            ScrollView {
                VStack(spacing: 24) {
                    scenarioSummaryCard
                    taxImpactWaterfallChart
                    scenarioFederalBracketChart
                    scenarioStateBracketChart
                    scenarioIRMAAChart
                    scenarioNIITChart
                    legacyImpactCard
                    perDecisionImpact
                    strategyTipsSection
                    emptyAnalysisPlaceholder
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showRothGuide) {
            rothConversionGuideSheet
        }
        .sheet(isPresented: $showCharitableGuide) {
            charitableGuideSheet
        }
    }

    /// Reusable sheet wrapper with NavigationStack, title, and Done button
    private func scenarioSheet<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .padding()
            }
            .background(Color(PlatformColor.systemGroupedBackground))
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showRothSheet = false
                        showWithdrawalSheet = false
                        showInheritedSheet = false
                        showCharitableSheet = false
                    }
                }
            }
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
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scenario Builder")
                .font(.title2)
                .fontWeight(.bold)

            Text("Work through each step below to build your tax scenario. Adjust conversions, withdrawals, and charitable giving \u{2014} the tax impact updates in real time.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if isWideLayout {
                Text("Adjust inputs on the left and see results on the right.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }

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

            if dataManager.hasActiveScenario {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset Scenario", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .confirmationDialog("Reset all scenario values to defaults?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                    Button("Reset Scenario", role: .destructive) {
                        dataManager.resetScenario()
                        stockPurchasePriceText = ""
                        stockCurrentValueText = ""
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
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
        .background(Color(PlatformColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Legacy Impact Card

    @ViewBuilder
    private var legacyImpactCard: some View {
        if dataManager.enableLegacyPlanning && dataManager.hasActiveScenario {
            let hasRothConversion = dataManager.scenarioTotalRothConversion > 0
            let hasQCD = dataManager.scenarioTotalQCD > 0
            let hasLegacyContent = hasRothConversion || hasQCD

            if hasLegacyContent {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.85), .indigo.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            Image(systemName: "gift.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Legacy Impact")
                                .font(.headline)
                            Text("How your decisions affect your heirs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // SECTION A: Family Wealth Impact (clean headline)
                    if hasRothConversion {
                        VStack(spacing: 10) {
                            Text("Family Wealth Impact")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)

                            // Side-by-side: total wealth only (no scary tax subtotals)
                            HStack(spacing: 16) {
                                VStack(spacing: 4) {
                                    Text("Without conversion")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(dataManager.legacyNoConversionTotalWealth, format: .currency(code: "USD").precision(.fractionLength(0)))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)

                                VStack(spacing: 4) {
                                    let conversionLabel = legacyCompactCurrency(dataManager.scenarioTotalRothConversion)
                                    Text("With \(conversionLabel) Roth conversion")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Text(dataManager.legacyWithConversionTotalWealth, format: .currency(code: "USD").precision(.fractionLength(0)))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.green)
                                }
                                .frame(maxWidth: .infinity)
                            }

                            // Net family gain — the hero number
                            let advantage = dataManager.legacyFamilyWealthAdvantage
                            HStack(spacing: 6) {
                                Image(systemName: advantage >= 0 ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(advantage >= 0 ? .green : .orange)
                                Text("Net family gain:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(abs(advantage), format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(advantage >= 0 ? .green : .orange)
                            }
                            .frame(maxWidth: .infinity)

                            // Return on taxes paid — frames conversion as investment
                            let rotp = dataManager.legacyReturnOnTaxesPaid
                            if dataManager.legacyConversionTaxPaidToday > 0 && abs(rotp) > 0.1 {
                                let rotpFmt = String(format: "%.1f", abs(rotp))
                                Text("Equivalent to a \(rotpFmt)% return on the \(legacyCompactCurrency(dataManager.legacyConversionTaxPaidToday)) in taxes paid")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }

                            let deathAge = dataManager.legacyEstimatedDeathAge
                            let yearsLeft = dataManager.legacyYearsUntilDeath
                            let drawdownYears = dataManager.legacyDrawdownYears
                            let growthPct = Int(dataManager.primaryGrowthRate)
                            Text("Projected \(yearsLeft) years to age \(deathAge), then heir's \(drawdownYears)-year drawdown at \(growthPct)% growth")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // "Show Details" toggle — progressive disclosure
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showLegacyDetails.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showLegacyDetails ? "Hide Details" : "See the Full Advantages of Converting")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: showLegacyDetails ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    if showLegacyDetails {

                    // SECTION B: The Decision Framing — "You paid $X to shelter $Y"
                    if hasRothConversion {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                Text("Why This Works")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            let taxPaid = dataManager.legacyConversionTaxPaidToday
                            let converted = dataManager.scenarioTotalRothConversion
                            let growthPct = Int(dataManager.primaryGrowthRate)
                            let taxGrowthPct = Int(dataManager.taxableAccountGrowthRate)

                            // The shelter framing
                            HStack(spacing: 0) {
                                Text("You pay ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(taxPaid, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(" today to permanently move ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(converted, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                                Text(" into tax-free compounding.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // The key insight — bold thesis
                            (Text("Roth conversions shift money from taxable compounding to tax-free compounding.")
                                .fontWeight(.bold) +
                            Text(" Over time, tax-free compounding wins."))
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .padding(.vertical, 4)

                            // The mechanism
                            let taxGrowthFmt = String(format: "%.1f", dataManager.taxableAccountGrowthRate)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Circle().fill(.green).frame(width: 6, height: 6)
                                    Text("Roth compounds at \(growthPct)% tax-free \u{2014} no RMDs, no tax on withdrawal")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Circle().fill(.orange).frame(width: 6, height: 6)
                                    Text("Tax dollars you kept only compound at ~\(taxGrowthFmt)% after tax drag")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Per-$100K multiplier
                            if converted > 0 {
                                let per100K = (abs(dataManager.legacyFamilyWealthAdvantage) / converted) * 100_000
                                let per100KLabel = legacyCompactCurrency(per100K)
                                let direction = dataManager.legacyFamilyWealthAdvantage >= 0 ? "adds" : "costs"
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.green)
                                        .font(.caption2)
                                    Text("Under these assumptions, every $100K converted \(direction) about \(per100KLabel) of family wealth")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .italic()
                                }
                            }
                        }
                    }

                    // SECTION B2: Compounding Divergence Chart
                    if hasRothConversion {
                        let chartData = dataManager.legacyCompoundingChartData
                        if chartData.count >= 2 {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("How Roth Conversions Increase Family Wealth Over Time")
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                // Compute Y-axis baseline to zoom into the divergence
                                let allValues = chartData.flatMap { [$0.rothValue, $0.traditionalValue] }
                                let minVal = allValues.min() ?? 0
                                let maxVal = allValues.max() ?? 1
                                let range = maxVal - minVal
                                let yFloor = max(0, minVal - range * 0.3)
                                let yCeiling = maxVal + range * 0.1
                                let breakEvenYr = dataManager.legacyBreakEvenYear

                                Chart {
                                    ForEach(chartData) { point in
                                        LineMark(
                                            x: .value("Year", point.year),
                                            y: .value("Value", point.rothValue),
                                            series: .value("Path", "Roth (tax-free)")
                                        )
                                        .foregroundStyle(.green)
                                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                                        .interpolationMethod(.catmullRom)

                                        LineMark(
                                            x: .value("Year", point.year),
                                            y: .value("Value", point.traditionalValue),
                                            series: .value("Path", "Traditional + tax $ kept")
                                        )
                                        .foregroundStyle(.orange)
                                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
                                        .interpolationMethod(.catmullRom)
                                    }

                                    // Shade the gap (only where Roth wins)
                                    ForEach(chartData) { point in
                                        if point.rothValue > point.traditionalValue {
                                            AreaMark(
                                                x: .value("Year", point.year),
                                                yStart: .value("Trad", point.traditionalValue),
                                                yEnd: .value("Roth", point.rothValue)
                                            )
                                            .foregroundStyle(.green.opacity(0.12))
                                            .interpolationMethod(.catmullRom)
                                        }
                                    }

                                    // Break-even vertical rule
                                    if let beYear = breakEvenYr, beYear > 0 {
                                        RuleMark(x: .value("Break-even", beYear))
                                            .foregroundStyle(.blue)
                                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                            .annotation(position: .top, alignment: .center) {
                                                Text("Yr \(beYear)")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(.blue)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.1))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                    }
                                }
                                .chartYScale(domain: yFloor...yCeiling)
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisGridLine()
                                        AxisValueLabel {
                                            if let v = value.as(Double.self) {
                                                Text(legacyCompactCurrency(v))
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks { value in
                                        AxisGridLine()
                                        AxisValueLabel {
                                            if let yr = value.as(Int.self) {
                                                Text("Yr \(yr)")
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                                .chartLegend(position: .bottom, spacing: 4)
                                .frame(height: 200)

                                // Break-even callout below chart
                                if let beYear = breakEvenYr {
                                    if beYear == 0 {
                                        VStack(spacing: 2) {
                                            Text("Under these assumptions, Roth wins immediately.")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.green)
                                            Text("Higher future tax rates (widow bracket jump or the SECURE Act 10-year rule for heirs) would strengthen the advantage further.")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                    } else {
                                        VStack(spacing: 2) {
                                            Text("Under these assumptions, Roth overtakes Traditional at year \(beYear).")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.blue)
                                            Text("Higher future tax rates (widow bracket jump or the SECURE Act 10-year rule for heirs) would move the crossover earlier.")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                    }
                                }

                                Text("The Roth advantage grows the longer the money compounds")
                                    .font(.caption2)
                                    .italic()
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    // SECTION C: Break-Even + Time Horizon
                    if hasRothConversion {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "target")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                                Text("Break-Even Analysis")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            let breakEvenPct = Int(dataManager.legacyBreakEvenHeirTaxRate * 100)
                            let heirPct = Int(dataManager.legacyHeirTaxRate * 100)
                            let favorable = dataManager.legacyConversionIsFavorable

                            HStack(spacing: 6) {
                                Image(systemName: favorable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(favorable ? .green : .orange)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Conversion wins if heir's rate exceeds \(breakEvenPct)%")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    let statusText = favorable
                                        ? "Your heir's \(heirPct)% rate clears the \(breakEvenPct)% threshold"
                                        : "Your heir's \(heirPct)% rate is below the \(breakEvenPct)% threshold \u{2014} consider carefully"
                                    Text(statusText)
                                        .font(.caption2)
                                        .foregroundStyle(favorable ? .green : .secondary)
                                }
                            }

                            // Time horizon table — shows how advantage grows over time
                            let horizons = dataManager.legacyBreakEvenAtHorizons
                            if !horizons.isEmpty {
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("Time Horizon")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Break-even")
                                            .frame(maxWidth: .infinity, alignment: .center)
                                        Text("Family Gain")
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 4)

                                    ForEach(horizons, id: \.years) { h in
                                        HStack {
                                            Text("\(h.years) years")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Text("\(Int(h.rate * 100))%")
                                                .frame(maxWidth: .infinity, alignment: .center)
                                            let label = h.advantage >= 0
                                                ? "+\(legacyCompactCurrency(h.advantage))"
                                                : "-\(legacyCompactCurrency(abs(h.advantage)))"
                                            Text(label)
                                                .foregroundStyle(h.advantage >= 0 ? .green : .orange)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        .font(.caption)
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                Text("The longer the money compounds, the more Roth conversions favor the family")
                                    .font(.caption2)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // SECTION D: QCD Legacy Benefit
                    if hasQCD {
                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.subheadline)
                                Text("QCD Legacy Benefit")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            }
                            let qcdAmount = legacyCompactCurrency(dataManager.scenarioTotalQCD)
                            let qcdSavings = legacyCompactCurrency(dataManager.legacyQCDHeirBenefit)
                            Text("Removes \(qcdAmount) from your IRA tax-free \u{2014} saves heir ~\(qcdSavings) in future taxes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Reduces heir's \(dataManager.legacyDrawdownYears)-year tax burden")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // SECTION D2: Widow Tax Bracket Warning
                    if dataManager.widowHasBracketJump {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill.xmark")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                Text("Surviving Spouse Tax Bracket Jump")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            let currentPct = Int(dataManager.widowCurrentMarginalRate * 100)
                            let survivorPct = Int(dataManager.widowSurvivorMarginalRate * 100)
                            let jumpPts = Int(dataManager.widowBracketJump * 100)

                            VStack(alignment: .leading, spacing: 6) {
                                // The bracket jump visual
                                HStack(spacing: 8) {
                                    VStack(spacing: 2) {
                                        Text("Now (MFJ)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(currentPct)%")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.green)
                                    }
                                    .frame(maxWidth: .infinity)

                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(.red)
                                        .fontWeight(.bold)

                                    VStack(spacing: 2) {
                                        Text("Survivor (Single)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(survivorPct)%")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.red)
                                    }
                                    .frame(maxWidth: .infinity)

                                    VStack(spacing: 2) {
                                        Text("Jump")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("+\(jumpPts) pts")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.orange)
                                    }
                                    .frame(maxWidth: .infinity)
                                }

                                Text("When one spouse passes, the survivor files Single \u{2014} but income barely drops. The same IRA withdrawals get taxed at higher Single rates.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if hasRothConversion {
                                    let savings = dataManager.widowConversionBracketSavings
                                    if savings > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "shield.fill")
                                                .foregroundStyle(.green)
                                                .font(.caption2)
                                            Text("Converting now at \(currentPct)% avoids the survivor paying \(survivorPct)% later \u{2014} saves \(legacyCompactCurrency(savings)) in bracket arbitrage")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }

                                Text("This creates a \"golden conversion window\" \u{2014} while both spouses are alive, you have wider married tax brackets and two standard deductions. Convert now before the window closes.")
                                    .font(.caption2)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color.red.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // SECTION E: Portfolio at Inheritance — Projected to Death
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        let deathAge = dataManager.legacyEstimatedDeathAge
                        Text("Projected Portfolio at Age \(deathAge)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        // Column headers
                        HStack {
                            Text("")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("No Scenario")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text("With Scenario")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        legacyPortfolioRow(
                            label: "Traditional IRA",
                            before: dataManager.legacyNoActionTraditionalAtDeath,
                            after: dataManager.legacyWithScenarioTraditionalAtDeath,
                            betterIfLower: true
                        )
                        legacyPortfolioRow(
                            label: "Roth IRA",
                            before: dataManager.legacyNoActionRothAtDeath,
                            after: dataManager.legacyWithScenarioRothAtDeath,
                            betterIfLower: false
                        )
                        legacyPortfolioRow(
                            label: "Heir's tax bill",
                            before: dataManager.legacyCostOfInaction,
                            after: dataManager.legacyWithScenarioHeirTax,
                            betterIfLower: true
                        )

                        Text("Traditional balance reflects RMDs taken from age \(dataManager.rmdAge)+")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // SECTION F: Heir Inheritance Reality Check
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("What Your Heir Actually Inherits")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        // Show that heir gets BOTH accounts
                        let tradAtDeath = hasRothConversion
                            ? dataManager.legacyWithScenarioTraditionalAtDeath
                            : dataManager.legacyNoActionTraditionalAtDeath
                        let rothAtDeath = hasRothConversion
                            ? dataManager.legacyWithScenarioRothAtDeath
                            : dataManager.legacyNoActionRothAtDeath
                        let drawdownYears = dataManager.legacyDrawdownYears

                        if tradAtDeath > 0 {
                            let annualForced = tradAtDeath / Double(drawdownYears)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Circle().fill(.red).frame(width: 6, height: 6)
                                    Text("Traditional IRA: \(legacyCompactCurrency(tradAtDeath)) \u{2014} must be emptied in \(drawdownYears) years")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Text("   ")
                                        .font(.caption2)
                                    Text("~\(legacyCompactCurrency(annualForced))/year added to heir's taxable income")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.red)
                                }

                                if rothAtDeath > 0 {
                                    HStack(spacing: 4) {
                                        Circle().fill(.green).frame(width: 6, height: 6)
                                        Text("Roth IRA: \(legacyCompactCurrency(rothAtDeath)) \u{2014} tax-free, no forced timeline")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            // The key warning
                            if dataManager.legacyHeirType != "spouse" {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your heir receives both accounts. The \(legacyCompactCurrency(annualForced))/year from the Traditional IRA is added on top of their own salary \u{2014} potentially pushing them into the \(Int(dataManager.legacyHeirTaxRate * 100))% bracket or higher during their peak earning years.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text("Every dollar you convert to Roth now is one less dollar forced through their tax bracket later.")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                }
                                .padding(8)
                                .background(Color.orange.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        // Heir type context
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: dataManager.legacyHeirType == "spouse" ? "person.2.fill" : "clock.fill")
                                .foregroundStyle(.blue)
                                .font(.caption2)
                                .padding(.top, 2)
                            Text(dataManager.legacyHeirTypeDescriptionDetailed)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    } // end showLegacyDetails
                }
                .padding()
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            }
        }
    }

    /// Helper: comparison row for legacy side-by-side
    private func legacyComparisonRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    /// Helper: portfolio before/after row
    private func legacyPortfolioRow(label: String, before: Double, after: Double, betterIfLower: Bool) -> some View {
        let improved = betterIfLower ? after < before : after > before
        return HStack {
            Text(label)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(before, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(after, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(improved ? .green : (after == before ? .secondary : .orange))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// Helper: compact currency formatting for inline text
    private func legacyCompactCurrency(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return "$" + String(format: "%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return "$" + String(format: "%.0fK", amount / 1_000)
        } else {
            return "$" + String(format: "%.0f", amount)
        }
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

                    let irmaaImpact = dataManager.rothConversionIRMAAImpact
                    if irmaaImpact > 0 {
                        let _ = netImpact += irmaaImpact
                        impactRow(label: "  IRMAA Surcharge", amount: irmaaImpact, isPositive: false, color: .pink)
                    }

                    // NIIT breakdown (informational — already included in tax impact above)
                    let rothNIIT = dataManager.rothConversionNIITImpact
                    if rothNIIT > 0 {
                        Text("    incl. \(rothNIIT, format: .currency(code: "USD")) NIIT")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.leading, 28)
                            .padding(.top, -4)
                    }
                }

                if dataManager.scenarioTotalExtraWithdrawal > 0 {
                    let impact = dataManager.extraWithdrawalTaxImpact
                    let _ = netImpact += impact
                    impactRow(label: "Extra Withdrawals", amount: impact, isPositive: false, color: .blue)

                    let irmaaImpact = dataManager.extraWithdrawalIRMAAImpact
                    if irmaaImpact > 0 {
                        let _ = netImpact += irmaaImpact
                        impactRow(label: "  IRMAA Surcharge", amount: irmaaImpact, isPositive: false, color: .pink)
                    }

                    let wdlNIIT = dataManager.extraWithdrawalNIITImpact
                    if wdlNIIT > 0 {
                        Text("    incl. \(wdlNIIT, format: .currency(code: "USD")) NIIT")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.leading, 28)
                            .padding(.top, -4)
                    }
                }

                if dataManager.inheritedTraditionalExtraTotal > 0 {
                    let impact = dataManager.inheritedExtraWithdrawalTaxImpact
                    let _ = netImpact += impact
                    impactRow(label: "Inherited IRA Withdrawals", amount: impact, isPositive: false, color: .indigo)

                    let irmaaImpact = dataManager.inheritedExtraWithdrawalIRMAAImpact
                    if irmaaImpact > 0 {
                        let _ = netImpact += irmaaImpact
                        impactRow(label: "  IRMAA Surcharge", amount: irmaaImpact, isPositive: false, color: .pink)
                    }

                    let inhNIIT = dataManager.inheritedExtraWithdrawalNIITImpact
                    if inhNIIT > 0 {
                        Text("    incl. \(inhNIIT, format: .currency(code: "USD")) NIIT")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.leading, 28)
                            .padding(.top, -4)
                    }
                }

                if totalQCD > 0 {
                    let savings = dataManager.qcdTaxSavings
                    let _ = netImpact -= savings
                    impactRow(label: "QCD", amount: savings, isPositive: true, color: .green)

                    let irmaaSavings = dataManager.qcdIRMAASavings
                    if irmaaSavings > 0 {
                        let _ = netImpact -= irmaaSavings
                        impactRow(label: "  IRMAA Savings", amount: irmaaSavings, isPositive: true, color: .pink)
                    }

                    let qcdNIIT = dataManager.qcdNIITSavings
                    if qcdNIIT > 0 {
                        Text("    incl. \(qcdNIIT, format: .currency(code: "USD")) NIIT savings")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.leading, 28)
                            .padding(.top, -4)
                    }

                    if irmaaSavings == 0 && qcdNIIT == 0 {
                        Text("QCD also lowers your AGI, which may reduce Social Security taxation.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                            .padding(.top, -4)
                    }
                }

                if dataManager.stockDonationEnabled && dataManager.stockCurrentValue > 0 {
                    // Itemized deduction benefit (reduces cash taxes owed)
                    let deductionSavings = dataManager.stockDeductionTaxSavings
                    if deductionSavings > 0 {
                        let _ = netImpact -= deductionSavings
                        impactRow(label: "Stock Donation Tax Reduction", amount: deductionSavings, isPositive: true, color: .orange)
                    }

                    // Tax on gain avoided (by donating instead of selling)
                    let gainsAvoided = dataManager.stockCapGainsTaxAvoided
                    if gainsAvoided > 0 {
                        let _ = netImpact -= gainsAvoided
                        impactRow(label: dataManager.scenarioStockIsLongTerm ? "Cap Gains Avoided" : "Gain Tax Avoided", amount: gainsAvoided, isPositive: true, color: .orange)
                    }

                    // Note if not itemizing (deduction provides no benefit)
                    if deductionSavings == 0 && !dataManager.scenarioEffectiveItemize {
                        Text("Taking standard deduction \u{2014} stock donation deduction not applied")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                            .padding(.top, -4)
                    }
                }

                if dataManager.cashDonationAmount > 0 {
                    let savings = dataManager.cashDonationTaxSavings
                    let _ = netImpact -= savings
                    impactRow(label: "Cash Donation", amount: savings, isPositive: true, color: .teal)
                }

                Divider()

                // Net impact (including IRMAA surcharge changes)
                let displayNet = dataManager.rothConversionTaxImpact + dataManager.extraWithdrawalTaxImpact
                    + dataManager.inheritedExtraWithdrawalTaxImpact
                    - dataManager.qcdTaxSavings - dataManager.stockDeductionTaxSavings - dataManager.stockCapGainsTaxAvoided - dataManager.cashDonationTaxSavings
                    + dataManager.rothConversionIRMAAImpact + dataManager.extraWithdrawalIRMAAImpact
                    + dataManager.inheritedExtraWithdrawalIRMAAImpact - dataManager.qcdIRMAASavings

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
            .background(Color(PlatformColor.systemBackground))
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

    // MARK: - Chart 4: Tax Impact Waterfall

    private struct WaterfallBar: Identifiable {
        let id = UUID()
        let label: String
        let yStart: Double
        let yEnd: Double
        let color: Color
        let isTotal: Bool
    }

    private var waterfallBars: [WaterfallBar] {
        var bars: [WaterfallBar] = []

        // Compute base tax (tax before any scenario decisions)
        let rothImpact = dataManager.rothConversionTaxImpact
        let rothIRMAA = dataManager.rothConversionIRMAAImpact
        let wdlImpact = dataManager.extraWithdrawalTaxImpact
        let wdlIRMAA = dataManager.extraWithdrawalIRMAAImpact
        let inhImpact = dataManager.inheritedExtraWithdrawalTaxImpact
        let inhIRMAA = dataManager.inheritedExtraWithdrawalIRMAAImpact
        let qcdSavings = dataManager.qcdTaxSavings
        let qcdIRMAA = dataManager.qcdIRMAASavings
        let stockSavings = dataManager.stockDeductionTaxSavings
        let cashSavings = dataManager.cashDonationTaxSavings

        let finalTax = dataManager.scenarioTotalTax + dataManager.scenarioIRMAATotalSurcharge
        let baseTax = finalTax
            - (rothImpact + rothIRMAA)
            - (wdlImpact + wdlIRMAA)
            - (inhImpact + inhIRMAA)
            + (qcdSavings + qcdIRMAA)
            + stockSavings
            + cashSavings

        // Base bar
        bars.append(WaterfallBar(label: "Base Tax", yStart: 0, yEnd: baseTax, color: .gray, isTotal: true))

        var runningTotal = baseTax

        // Costs (go UP)
        let rothTotal = rothImpact + rothIRMAA
        if rothTotal > 0 {
            bars.append(WaterfallBar(label: "Roth", yStart: runningTotal, yEnd: runningTotal + rothTotal, color: .purple, isTotal: false))
            runningTotal += rothTotal
        }

        let wdlTotal = wdlImpact + wdlIRMAA
        if wdlTotal > 0 {
            bars.append(WaterfallBar(label: "Wdl", yStart: runningTotal, yEnd: runningTotal + wdlTotal, color: .blue, isTotal: false))
            runningTotal += wdlTotal
        }

        let inhTotal = inhImpact + inhIRMAA
        if inhTotal > 0 {
            bars.append(WaterfallBar(label: "Inh", yStart: runningTotal, yEnd: runningTotal + inhTotal, color: .indigo, isTotal: false))
            runningTotal += inhTotal
        }

        // Savings (go DOWN)
        let qcdTotal = qcdSavings + qcdIRMAA
        if qcdTotal > 0 {
            bars.append(WaterfallBar(label: "QCD", yStart: runningTotal, yEnd: runningTotal - qcdTotal, color: .green, isTotal: false))
            runningTotal -= qcdTotal
        }

        if stockSavings > 0 {
            bars.append(WaterfallBar(label: "Stock", yStart: runningTotal, yEnd: runningTotal - stockSavings, color: .orange, isTotal: false))
            runningTotal -= stockSavings
        }

        if cashSavings > 0 {
            bars.append(WaterfallBar(label: "Cash", yStart: runningTotal, yEnd: runningTotal - cashSavings, color: .teal, isTotal: false))
            runningTotal -= cashSavings
        }

        // Final bar
        bars.append(WaterfallBar(label: "Final Tax", yStart: 0, yEnd: finalTax, color: .gray.opacity(0.8), isTotal: true))

        return bars
    }

    private func waterfallYAxisLabel(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return "$\(String(format: "%.1f", amount / 1_000_000))M"
        } else if amount >= 1000 {
            return "$\(Int(amount / 1000))K"
        } else {
            return "$\(Int(amount))"
        }
    }

    @ViewBuilder
    private var taxImpactWaterfallChart: some View {
        if dataManager.hasActiveScenario {
            let bars = waterfallBars
            // Only show if there are decision bars (more than just base + final)
            if bars.count > 2 {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.85), .green.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tax Impact Waterfall")
                                .font(.headline)
                            Text("How each decision affects your total tax")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    // Waterfall chart
                    Chart(bars) { bar in
                        BarMark(
                            x: .value("Decision", bar.label),
                            yStart: .value("Start", bar.yStart),
                            yEnd: .value("End", bar.yEnd)
                        )
                        .foregroundStyle(bar.color)
                        .cornerRadius(3)
                        .annotation(position: .overlay) {
                            let amount = abs(bar.yEnd - bar.yStart)
                            if amount > 0 {
                                let isSavings = bar.yEnd < bar.yStart && !bar.isTotal
                                Text("\(isSavings ? "-" : "")\(waterfallYAxisLabel(amount))")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                    .shadow(color: .black.opacity(0.5), radius: 1)
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(waterfallYAxisLabel(amount))
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label)
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 260)

                }
                .padding()
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .green.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            }
        }
    }

    // MARK: - Scenario Bracket & IRMAA Charts

    /// Compact dollar label (same as waterfallYAxisLabel but reused for bracket charts)
    private func scenarioChartLabel(_ amount: Double) -> String {
        waterfallYAxisLabel(amount)
    }

    /// Helper to find next bracket rate label
    private func scenarioNextBracketRate(after currentRate: Double) -> Int {
        let brackets = dataManager.filingStatus == .single
            ? dataManager.currentTaxBrackets.federalSingle
            : dataManager.currentTaxBrackets.federalMarried
        for i in brackets.indices {
            if abs(brackets[i].rate - currentRate) < 0.001, i + 1 < brackets.count {
                return Int(brackets[i + 1].rate * 100)
            }
        }
        return Int(currentRate * 100)
    }

    // MARK: Federal Bracket Chart (Scenario)

    private struct ScenarioBracketSegment: Identifiable {
        let id = UUID()
        let rate: Double
        let label: String
        let rangeStart: Double
        let rangeEnd: Double
        let isCurrent: Bool
    }

    private var scenarioBracketSegments: [ScenarioBracketSegment] {
        let brackets = dataManager.filingStatus == .single
            ? dataManager.currentTaxBrackets.federalSingle
            : dataManager.currentTaxBrackets.federalMarried
        let afterIncome = dataManager.scenarioTaxableIncome

        var segments: [ScenarioBracketSegment] = []
        for i in brackets.indices {
            let start = brackets[i].threshold
            let end: Double
            if i + 1 < brackets.count {
                end = brackets[i + 1].threshold
            } else {
                end = max(start + 50_000, afterIncome * 1.2)
            }
            let isCurrent = afterIncome > start && (i + 1 >= brackets.count || afterIncome <= brackets[i + 1].threshold)
            segments.append(ScenarioBracketSegment(
                rate: brackets[i].rate,
                label: "\(Int(brackets[i].rate * 100))%",
                rangeStart: start,
                rangeEnd: end,
                isCurrent: isCurrent
            ))
        }
        return segments
    }

    @ViewBuilder
    private var scenarioFederalBracketChart: some View {
        if dataManager.hasActiveScenario {
            let beforeIncome = max(0, dataManager.scenarioBaseIncome - dataManager.effectiveDeductionAmount)
            let afterIncome = dataManager.scenarioTaxableIncome
            if afterIncome > 0 {
                let segments = scenarioBracketSegments
                let bracketInfo = dataManager.federalBracketInfo(income: afterIncome, filingStatus: dataManager.filingStatus)
                let bracketColors: [Color] = [
                    Color(red: 0.05, green: 0.78, blue: 0.35),
                    Color(red: 0.0, green: 0.72, blue: 0.68),
                    Color(red: 0.98, green: 0.78, blue: 0.0),
                    Color(red: 1.0, green: 0.50, blue: 0.0),
                    Color(red: 0.92, green: 0.22, blue: 0.50),
                    Color(red: 0.58, green: 0.22, blue: 0.88),
                    Color(red: 0.18, green: 0.30, blue: 0.85),
                ]

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [.green.opacity(0.85), .red.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            Image(systemName: "chart.bar.xaxis.ascending")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Federal Tax Bracket Position")
                                .font(.headline)
                            Text(dataManager.filingStatus.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    let currentIdx = segments.firstIndex(where: { $0.isCurrent }) ?? 0
                    let showThrough = min(currentIdx + 1, segments.count - 1)
                    let visibleSegments = Array(segments.prefix(showThrough + 1))
                    let chartMax = visibleSegments.last?.rangeEnd ?? 1
                    let barHeight: CGFloat = 36
                    let topPad: CGFloat = 40

                    GeometryReader { geo in
                        let w = geo.size.width

                        // Bracket bars
                        ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                            let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                            let color = bracketColors[min(globalIdx, bracketColors.count - 1)]
                            let x = w * segment.rangeStart / chartMax
                            let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax

                            if globalIdx <= currentIdx {
                                Rectangle().fill(color)
                                    .frame(width: segW, height: barHeight)
                                    .offset(x: x, y: topPad)
                            } else {
                                Rectangle().fill(color.opacity(0.22))
                                    .frame(width: segW, height: barHeight)
                                    .offset(x: x, y: topPad)
                            }
                        }

                        // Separator lines
                        ForEach(Array(visibleSegments.dropFirst().enumerated()), id: \.element.id) { _, segment in
                            let bx = w * segment.rangeStart / chartMax
                            Rectangle().fill(Color.primary.opacity(0.2))
                                .frame(width: 1, height: barHeight)
                                .offset(x: bx - 0.5, y: topPad)
                        }

                        // Before marker (dashed gray)
                        let beforeX = CGFloat(beforeIncome / chartMax) * w
                        Path { path in
                            path.move(to: CGPoint(x: beforeX, y: topPad - 5))
                            path.addLine(to: CGPoint(x: beforeX, y: topPad + barHeight + 5))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(.secondary)

                        Text("Before \(scenarioChartLabel(beforeIncome))")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .position(x: min(max(beforeX, 40), w - 40), y: 10)

                        // After marker (solid)
                        let afterX = CGFloat(afterIncome / chartMax) * w
                        Path { path in
                            path.move(to: CGPoint(x: afterX, y: topPad - 5))
                            path.addLine(to: CGPoint(x: afterX, y: topPad + barHeight + 5))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 2.5))
                        .foregroundStyle(.primary)

                        Text("After \(scenarioChartLabel(afterIncome))")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .position(x: min(max(afterX, 35), w - 35), y: 26)

                        // Outer border
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            .frame(width: w, height: barHeight)
                            .offset(y: topPad)

                        // Rate + range labels below
                        ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                            let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                            let isLast = index == visibleSegments.count - 1
                            let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax
                            let segX = w * segment.rangeStart / chartMax
                            let centerX = segX + segW / 2

                            VStack(spacing: 1) {
                                Text(segment.label)
                                    .font(.system(size: segW > 55 ? 11 : 9, weight: segment.isCurrent ? .bold : .semibold))
                                    .foregroundStyle(bracketColors[min(globalIdx, bracketColors.count - 1)])
                                let rangeText1 = isLast && segment.rate >= 0.37
                                    ? scenarioChartLabel(segment.rangeStart) + "+"
                                    : scenarioChartLabel(segment.rangeStart) + " – " + scenarioChartLabel(segment.rangeEnd)
                                Text(rangeText1)
                                    .font(.system(size: segW > 55 ? 9 : 7))
                                    .foregroundStyle(.secondary)
                            }
                            .position(x: centerX, y: topPad + barHeight + 18)
                        }
                    }
                    .frame(height: topPad + barHeight + 36)

                    // Average tax rate before → after
                    let beforeFedTax = dataManager.calculateFederalTax(income: beforeIncome, filingStatus: dataManager.filingStatus)
                    let afterFedTax = dataManager.calculateFederalTax(income: afterIncome, filingStatus: dataManager.filingStatus)
                    let beforeAvgFed = beforeIncome > 0 ? (beforeFedTax / beforeIncome) * 100 : 0
                    let afterAvgFed = afterIncome > 0 ? (afterFedTax / afterIncome) * 100 : 0
                    HStack(spacing: 6) {
                        Image(systemName: "percent")
                            .foregroundStyle(.purple)
                            .font(.caption)
                        Text("Avg rate:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", beforeAvgFed))
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", afterAvgFed))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(afterAvgFed > beforeAvgFed ? .red : .green)
                    }

                    // Room remaining callout
                    if bracketInfo.roomRemaining > 0 {
                        let nextRate = scenarioNextBracketRate(after: bracketInfo.currentRate)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                                Text("**\(bracketInfo.roomRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))** room before the \(nextRate)% bracket")
                                    .font(.caption)
                            }
                            if dataManager.enableLegacyPlanning {
                                Text("You could convert up to ~\(bracketInfo.roomRemaining, format: .currency(code: "USD").precision(.fractionLength(0))) more this year without entering the \(nextRate)% bracket.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 24)
                            }
                        }
                    } else if bracketInfo.currentRate >= 0.37 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("In the top **37%** federal bracket")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.green.opacity(0.3), .red.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            }
        }
    }

    // MARK: State Bracket Chart (Scenario)

    @ViewBuilder
    private var scenarioStateBracketChart: some View {
        if dataManager.hasActiveScenario {
            let config = dataManager.selectedStateConfig
            switch config.taxSystem {
            case .progressive(let single, let married):
                let brackets = dataManager.filingStatus == .single ? single : married
                let beforeIncome = max(0, dataManager.scenarioBaseIncome - dataManager.effectiveDeductionAmount)
                let afterIncome = dataManager.scenarioTaxableIncome
                if afterIncome > 0 && brackets.count > 1 {
                    let bracketInfo = dataManager.stateBracketInfo(income: afterIncome, filingStatus: dataManager.filingStatus)

                    // Build segments
                    let segments: [ScenarioBracketSegment] = brackets.enumerated().map { i, bracket in
                        let start = bracket.threshold
                        let end: Double = i + 1 < brackets.count ? brackets[i + 1].threshold : max(start + 50_000, afterIncome * 1.2)
                        let isCurrent = afterIncome > start && (i + 1 >= brackets.count || afterIncome <= brackets[i + 1].threshold)
                        return ScenarioBracketSegment(
                            rate: bracket.rate,
                            label: String(format: "%.1f%%", bracket.rate * 100),
                            rangeStart: start,
                            rangeEnd: end,
                            isCurrent: isCurrent
                        )
                    }

                    // Generate colors for state brackets (gradient from green to red)
                    let stateColors: [Color] = segments.enumerated().map { i, _ in
                        let t = segments.count > 1 ? Double(i) / Double(segments.count - 1) : 0
                        return Color(
                            red: t * 0.9,
                            green: (1 - t) * 0.7 + 0.1,
                            blue: 0.2
                        )
                    }

                    let currentIdx = segments.firstIndex(where: { $0.isCurrent }) ?? 0
                    let showThrough = min(currentIdx + 1, segments.count - 1)
                    let visibleSegments = Array(segments.prefix(showThrough + 1))
                    let chartMax = visibleSegments.last?.rangeEnd ?? 1
                    let barHeight: CGFloat = 36
                    let topPad: CGFloat = 40

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: [.green.opacity(0.85), .orange.opacity(0.85)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                Image(systemName: "building.columns.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(dataManager.selectedState.rawValue) Tax Bracket")
                                    .font(.headline)
                                Text(dataManager.filingStatus.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        GeometryReader { geo in
                            let w = geo.size.width

                            // Bracket bars
                            ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                                let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                                let color = stateColors[min(globalIdx, stateColors.count - 1)]
                                let x = w * segment.rangeStart / chartMax
                                let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax

                                if globalIdx <= currentIdx {
                                    Rectangle().fill(color)
                                        .frame(width: segW, height: barHeight)
                                        .offset(x: x, y: topPad)
                                } else {
                                    Rectangle().fill(color.opacity(0.22))
                                        .frame(width: segW, height: barHeight)
                                        .offset(x: x, y: topPad)
                                }
                            }

                            // Separator lines
                            ForEach(Array(visibleSegments.dropFirst().enumerated()), id: \.element.id) { _, segment in
                                let bx = w * segment.rangeStart / chartMax
                                Rectangle().fill(Color.primary.opacity(0.2))
                                    .frame(width: 1, height: barHeight)
                                    .offset(x: bx - 0.5, y: topPad)
                            }

                            // Before marker
                            let beforeX = CGFloat(beforeIncome / chartMax) * w
                            Path { path in
                                path.move(to: CGPoint(x: beforeX, y: topPad - 5))
                                path.addLine(to: CGPoint(x: beforeX, y: topPad + barHeight + 5))
                            }
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .foregroundStyle(.secondary)

                            Text("Before \(scenarioChartLabel(beforeIncome))")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .position(x: min(max(beforeX, 40), w - 40), y: 10)

                            // After marker
                            let afterX = CGFloat(afterIncome / chartMax) * w
                            Path { path in
                                path.move(to: CGPoint(x: afterX, y: topPad - 5))
                                path.addLine(to: CGPoint(x: afterX, y: topPad + barHeight + 5))
                            }
                            .stroke(style: StrokeStyle(lineWidth: 2.5))
                            .foregroundStyle(.primary)

                            Text("After \(scenarioChartLabel(afterIncome))")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .position(x: min(max(afterX, 35), w - 35), y: 26)

                            // Outer border
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                .frame(width: w, height: barHeight)
                                .offset(y: topPad)

                            // Rate + range labels below
                            ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                                let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                                let isLast = index == visibleSegments.count - 1
                                let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax
                                let segX = w * segment.rangeStart / chartMax
                                let centerX = segX + segW / 2

                                VStack(spacing: 1) {
                                    Text(segment.label)
                                        .font(.system(size: segW > 55 ? 11 : 9, weight: segment.isCurrent ? .bold : .semibold))
                                        .foregroundStyle(stateColors[min(globalIdx, stateColors.count - 1)])
                                    let rangeText2 = isLast && globalIdx == segments.count - 1
                                        ? scenarioChartLabel(segment.rangeStart) + "+"
                                        : scenarioChartLabel(segment.rangeStart) + " – " + scenarioChartLabel(segment.rangeEnd)
                                    Text(rangeText2)
                                        .font(.system(size: segW > 55 ? 9 : 7))
                                        .foregroundStyle(.secondary)
                                }
                                .position(x: centerX, y: topPad + barHeight + 18)
                            }
                        }
                        .frame(height: topPad + barHeight + 36)

                        // Average state tax rate before → after
                        let beforeStateTax = dataManager.calculateStateTax(income: beforeIncome, filingStatus: dataManager.filingStatus)
                        let afterStateTax = dataManager.calculateStateTax(income: afterIncome, filingStatus: dataManager.filingStatus)
                        let beforeAvgState = beforeIncome > 0 ? (beforeStateTax / beforeIncome) * 100 : 0
                        let afterAvgState = afterIncome > 0 ? (afterStateTax / afterIncome) * 100 : 0
                        HStack(spacing: 6) {
                            Image(systemName: "percent")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("Avg rate:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f%%", beforeAvgState))
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f%%", afterAvgState))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(afterAvgState > beforeAvgState ? .red : .green)
                        }

                        // Room remaining callout
                        if bracketInfo.roomRemaining > 0 {
                            let nextStateRate: Double = (segments.first(where: { $0.rate > bracketInfo.currentRate })?.rate ?? bracketInfo.currentRate) * 100
                            let nextRate = String(format: "%.1f", nextStateRate)
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                                Text("**\(bracketInfo.roomRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))** room before the next state bracket")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color(PlatformColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.green.opacity(0.3), .orange.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
                }
            default:
                EmptyView()
            }
        }
    }

    // MARK: IRMAA Chart (Scenario)

    private struct ScenarioIRMAATierSegment: Identifiable {
        let id = UUID()
        let tier: Int
        let label: String
        let rangeStart: Double
        let rangeEnd: Double
        let surchargePerPerson: Double
        let isCurrent: Bool
    }

    private var scenarioIRMAATierSegments: [ScenarioIRMAATierSegment] {
        let tiers = DataManager.irmaa2026Tiers
        let isMFJ = dataManager.filingStatus == .marriedFilingJointly
        let magi = dataManager.scenarioIRMAA.magi
        let currentTier = dataManager.scenarioIRMAA.tier
        let standardB = DataManager.irmaaStandardPartB

        var segments: [ScenarioIRMAATierSegment] = []
        for i in tiers.indices {
            let threshold = isMFJ ? tiers[i].mfjThreshold : tiers[i].singleThreshold
            let nextThreshold: Double
            if i + 1 < tiers.count {
                nextThreshold = isMFJ ? tiers[i + 1].mfjThreshold : tiers[i + 1].singleThreshold
            } else {
                nextThreshold = max(threshold + 300_000, magi * 1.2)
            }

            let surchargeB = tiers[i].partBMonthly - standardB
            let surchargeD = tiers[i].partDMonthly
            let annualSurcharge = (surchargeB + surchargeD) * 12

            segments.append(ScenarioIRMAATierSegment(
                tier: i,
                label: i == 0 ? "$0/yr" : "+\(scenarioChartLabel(max(0, annualSurcharge)))/yr",
                rangeStart: threshold,
                rangeEnd: nextThreshold,
                surchargePerPerson: max(0, annualSurcharge),
                isCurrent: currentTier == i
            ))
        }
        return segments
    }

    @ViewBuilder
    private var scenarioIRMAAChart: some View {
        if dataManager.hasActiveScenario && dataManager.medicareMemberCount > 0 {
            let irmaa = dataManager.scenarioIRMAA
            let baselineIrmaa = dataManager.baselineIRMAA
            let afterMAGI = irmaa.magi
            let beforeMAGI = baselineIrmaa.magi
            let segments = scenarioIRMAATierSegments
            let memberCount = dataManager.medicareMemberCount
            let tierColors: [Color] = [
                Color(red: 0.05, green: 0.78, blue: 0.35),
                Color(red: 0.98, green: 0.78, blue: 0.0),
                Color(red: 1.0, green: 0.50, blue: 0.0),
                Color(red: 0.92, green: 0.22, blue: 0.50),
                Color(red: 0.58, green: 0.22, blue: 0.88),
                Color(red: 0.18, green: 0.30, blue: 0.85),
            ]

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.85), .red.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "heart.text.square.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("IRMAA Medicare Surcharge")
                            .font(.headline)
                        Text("Based on \(dataManager.filingStatus.rawValue) MAGI · Affects \(dataManager.currentYear + 2) premiums")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                let chartMax = segments.last?.rangeEnd ?? 1
                let barHeight: CGFloat = 36
                let topPad: CGFloat = 40

                GeometryReader { geo in
                    let w = geo.size.width

                    // Tier bars
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        let color = tierColors[min(index, tierColors.count - 1)]
                        let x = w * segment.rangeStart / chartMax
                        let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax
                        let isFirst = index == 0
                        let isLastSeg = index == segments.count - 1

                        if isFirst {
                            UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 0, topTrailingRadius: 0)
                                .fill(color.opacity(segment.isCurrent ? 1.0 : 0.75))
                                .frame(width: segW, height: barHeight)
                                .offset(x: x, y: topPad)
                        } else if isLastSeg {
                            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 5, topTrailingRadius: 5)
                                .fill(color.opacity(segment.isCurrent ? 1.0 : 0.75))
                                .frame(width: segW, height: barHeight)
                                .offset(x: x, y: topPad)
                        } else {
                            Rectangle()
                                .fill(color.opacity(segment.isCurrent ? 1.0 : 0.75))
                                .frame(width: segW, height: barHeight)
                                .offset(x: x, y: topPad)
                        }
                    }

                    // Before marker (dashed gray)
                    let beforeX = CGFloat(beforeMAGI / chartMax) * w
                    Path { path in
                        path.move(to: CGPoint(x: beforeX, y: topPad - 5))
                        path.addLine(to: CGPoint(x: beforeX, y: topPad + barHeight + 5))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(.secondary)

                    Text("Before \(scenarioChartLabel(beforeMAGI))")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .position(x: min(max(beforeX, 40), w - 40), y: 10)

                    // After marker (solid)
                    let afterX = CGFloat(afterMAGI / chartMax) * w
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2.5, height: barHeight + 10)
                        .offset(x: afterX - 1.25, y: topPad - 5)

                    Text("After \(scenarioChartLabel(afterMAGI))")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .position(x: min(max(afterX, 35), w - 35), y: 26)

                    // Surcharge + range labels below bar
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        let isLast = index == segments.count - 1
                        let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax
                        let segX = w * segment.rangeStart / chartMax
                        let centerX = segX + segW / 2

                        VStack(spacing: 1) {
                            Text(segment.label)
                                .font(.system(size: segW > 50 ? 9 : 7, weight: segment.isCurrent ? .bold : .semibold))
                                .foregroundStyle(tierColors[min(index, tierColors.count - 1)])
                            if segment.tier == 0 {
                                Text("< \(scenarioChartLabel(segments.count > 1 ? segments[1].rangeStart : 0))")
                                    .font(.system(size: segW > 50 ? 8 : 7))
                                    .foregroundStyle(.secondary)
                            } else {
                                let rangeText3 = isLast
                                    ? scenarioChartLabel(segment.rangeStart) + "+"
                                    : scenarioChartLabel(segment.rangeStart) + "–" + scenarioChartLabel(segment.rangeEnd)
                                Text(rangeText3)
                                    .font(.system(size: segW > 50 ? 8 : 7))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .position(x: centerX, y: barHeight + topPad + 18)
                    }
                }
                .frame(height: barHeight + topPad + 36)

                // Callouts
                VStack(alignment: .leading, spacing: 6) {
                    if irmaa.tier == 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("No IRMAA surcharge")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("Tier \(irmaa.tier): \(irmaa.annualSurchargePerPerson, format: .currency(code: "USD").precision(.fractionLength(0)))/yr per person\(memberCount > 1 ? " (\(dataManager.scenarioIRMAATotalSurcharge, format: .currency(code: "USD").precision(.fractionLength(0))) household)" : "")")
                                .font(.caption)
                        }
                    }

                    if let distanceToNext = irmaa.distanceToNextTier, distanceToNext > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
                                .foregroundStyle(distanceToNext < 10_000 ? .orange : .blue)
                                .font(.caption)
                            Text("\(distanceToNext, format: .currency(code: "USD").precision(.fractionLength(0))) below next IRMAA cliff")
                                .font(.caption)
                                .foregroundStyle(distanceToNext < 10_000 ? .orange : .secondary)
                        }
                    }

                    if dataManager.scenarioPushedToHigherIRMAATier {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("Scenario pushes you to a **higher IRMAA tier**")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if irmaa.tier > 0, let distanceToPrev = irmaa.distanceToPreviousTier {
                        let savingsPerPerson = irmaa.annualSurchargePerPerson - dataManager.scenarioIRMAAPreviousTierAnnualSurcharge
                        let householdSavings = savingsPerPerson * Double(memberCount)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Reduce by \(distanceToPrev + 1, format: .currency(code: "USD").precision(.fractionLength(0))) to save \(householdSavings, format: .currency(code: "USD").precision(.fractionLength(0)))/yr")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .red.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        }
    }

    // MARK: NIIT Position Chart (Scenario)

    @ViewBuilder
    private var scenarioNIITChart: some View {
        if dataManager.hasActiveScenario && dataManager.scenarioNetInvestmentIncome > 0 {
            let niit = dataManager.scenarioNIIT
            let baselineNiit = dataManager.baselineNIIT
            let beforeMAGI = baselineNiit.magi
            let afterMAGI = niit.magi
            let threshold = niit.threshold
            let chartMax = max(threshold * 1.5, afterMAGI * 1.2, beforeMAGI * 1.2)
            let barHeight: CGFloat = 36
            let topPad: CGFloat = 40

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.85), .red.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Net Investment Income Tax")
                            .font(.headline)
                        Text("3.8% surtax on investment income")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                GeometryReader { geo in
                    let w = geo.size.width
                    let thresholdX = CGFloat(threshold / chartMax) * w

                    // Left zone: No NIIT (green)
                    UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 0, topTrailingRadius: 0)
                        .fill(Color(red: 0.05, green: 0.78, blue: 0.35))
                        .frame(width: thresholdX, height: barHeight)
                        .offset(y: topPad)

                    // Right zone: 3.8% NIIT (red/orange)
                    UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 5, topTrailingRadius: 5)
                        .fill(Color(red: 0.92, green: 0.22, blue: 0.22).opacity(0.85))
                        .frame(width: w - thresholdX, height: barHeight)
                        .offset(x: thresholdX, y: topPad)

                    // Threshold boundary line
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 2, height: barHeight + 10)
                        .offset(x: thresholdX - 1, y: topPad - 5)

                    // Before marker (dashed gray)
                    let beforeX = CGFloat(beforeMAGI / chartMax) * w
                    Path { path in
                        path.move(to: CGPoint(x: beforeX, y: topPad - 5))
                        path.addLine(to: CGPoint(x: beforeX, y: topPad + barHeight + 5))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(.secondary)

                    Text("Before \(scenarioChartLabel(beforeMAGI))")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .position(x: min(max(beforeX, 40), w - 40), y: 10)

                    // After marker (solid)
                    let afterX = CGFloat(afterMAGI / chartMax) * w
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2.5, height: barHeight + 10)
                        .offset(x: afterX - 1.25, y: topPad - 5)

                    Text("After \(scenarioChartLabel(afterMAGI))")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .position(x: min(max(afterX, 35), w - 35), y: 26)

                    // Zone labels below bar
                    let noNiitCenterX = thresholdX / 2
                    let niitZoneCenterX = thresholdX + (w - thresholdX) / 2

                    VStack(spacing: 1) {
                        Text("No NIIT")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(red: 0.05, green: 0.78, blue: 0.35))
                        Text("< \(scenarioChartLabel(threshold))")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .position(x: noNiitCenterX, y: topPad + barHeight + 18)

                    VStack(spacing: 1) {
                        Text("3.8% NIIT")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.red)
                        Text(scenarioChartLabel(threshold) + "+")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .position(x: niitZoneCenterX, y: topPad + barHeight + 18)
                }
                .frame(height: topPad + barHeight + 36)

                // Callouts
                VStack(alignment: .leading, spacing: 6) {
                    if niit.annualNIITax > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("NIIT: \(niit.annualNIITax, format: .currency(code: "USD").precision(.fractionLength(0)))/yr")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }

                        if dataManager.scenarioIncreasedNIIT {
                            let niitIncrease = niit.annualNIITax - baselineNiit.annualNIITax
                            if niitIncrease > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text("Scenario adds \(niitIncrease, format: .currency(code: "USD").precision(.fractionLength(0))) in NIIT")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            let distance = niit.distanceToThreshold
                            Text("No NIIT — \(max(0, distance), format: .currency(code: "USD").precision(.fractionLength(0))) below threshold")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .red.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
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

    // MARK: - Step 1: Roth Conversions

    private var rothConversionStep: some View {
        ScenarioStepSection(
            stepNumber: 1,
            title: "Roth Conversions",
            description: "Move funds from a Traditional IRA to a Roth IRA. You\u{2019}ll pay tax now, but future growth and withdrawals are tax-free. There\u{2019}s no age restriction \u{2014} this is especially valuable before RMDs begin, when your income may be lower. As you adjust the amount, watch the tax impact update on the right.",
            stepColor: .orange,
            icon: "arrow.right.arrow.left"
        ) {
            rothConversionContent
        }
    }

    @ViewBuilder
    private var rothConversionContent: some View {
        // Your Roth conversion
        ConversionSliderCard(
            label: spouseEnabled ? "Your Conversion" : "Conversion Amount",
            icon: spouseEnabled ? "person.fill" : nil,
            balance: dataManager.primaryTraditionalIRABalance,
            amount: $dataManager.yourRothConversion,
            sliderMax: yourSliderMax,
            tint: .orange
        )

        if dataManager.yourRothConversion > 0 {
            QuarterPicker(label: "Timing", quarter: $dataManager.yourRothConversionQuarter)
        }

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

            if dataManager.spouseRothConversion > 0 {
                QuarterPicker(label: "Timing", quarter: $dataManager.spouseRothConversionQuarter)
            }
        }

        // Combined total
        if spouseEnabled && (dataManager.yourRothConversion > 0 || dataManager.spouseRothConversion > 0) {
            Divider()
            ViewThatFits {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Combined Roth Conversions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(totalRothConversion, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
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

    // MARK: - Step 2: IRA/401(k) Withdrawals

    private var withdrawalStep: some View {
        ScenarioStepSection(
            stepNumber: 2,
            title: "IRA/401(k) Withdrawals",
            description: "Withdraw cash from your retirement savings for living expenses or other needs. Withdrawals are penalty-free after age 59\u{00BD}. Required Minimum Distributions (RMDs) are shown automatically. Any extra withdrawals add to your taxable income \u{2014} see the impact on tax rates and IRMAA on the right.",
            stepColor: .blue,
            icon: "banknote"
        ) {
            withdrawalContent
        }
    }

    @ViewBuilder
    private var withdrawalContent: some View {
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
                    sliderMax: max(200_000, dataManager.primaryTraditionalIRABalance),
                    tint: .blue
                )

                if dataManager.isRMDRequired || dataManager.yourExtraWithdrawal > 0 {
                    QuarterPicker(label: "Withdrawal Timing", quarter: $dataManager.yourWithdrawalQuarter)
                }
            }
            .padding()
            .background(Color(PlatformColor.secondarySystemBackground))
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
                    sliderMax: max(200_000, dataManager.spouseTraditionalIRABalance),
                    tint: .blue
                )

                if dataManager.spouseIsRMDRequired || dataManager.spouseExtraWithdrawal > 0 {
                    QuarterPicker(label: "Withdrawal Timing", quarter: $dataManager.spouseWithdrawalQuarter)
                }
            }
            .padding()
            .background(Color(PlatformColor.secondarySystemBackground))
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

    // MARK: - Step 3: Inherited IRA Withdrawals (conditional)

    @ViewBuilder
    private var inheritedWithdrawalStep: some View {
        if dataManager.hasInheritedAccounts {
            ScenarioStepSection(
                stepNumber: 3,
                title: "Inherited IRA Withdrawals",
                description: "If you\u{2019}ve inherited a Traditional IRA, required annual distributions may apply depending on the original owner\u{2019}s RBD status and your beneficiary type. You can take extra withdrawals beyond the required amount. Inherited Traditional distributions are taxable but not eligible for QCDs.",
                stepColor: .indigo,
                icon: "archivebox"
            ) {
                inheritedWithdrawalContent
            }
        }
    }

    @ViewBuilder
    private var inheritedWithdrawalContent: some View {
        ForEach(dataManager.inheritedAccounts) { account in
            let result = dataManager.calculateInheritedIRARMD(account: account, forYear: dataManager.currentYear)
            let extraMax = max(0, account.balance - result.annualRMD)
            let isRoth = account.accountType == .inheritedRothIRA

            VStack(alignment: .leading, spacing: 12) {
                // Account name + owner badge
                HStack {
                    Text(account.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if spouseEnabled {
                        Text(account.owner.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(isRoth ? "Roth" : "Traditional")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(isRoth ? .green : .orange)
                }

                // Balance
                HStack {
                    Text("Balance")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(account.balance, format: .currency(code: "USD"))
                        .font(.callout)
                        .fontWeight(.semibold)
                }

                // Beneficiary type
                if let beneficiary = account.beneficiaryType {
                    HStack {
                        Text("Beneficiary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(beneficiary.rawValue)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // Required annual RMD
                if result.annualRMD > 0 {
                    HStack {
                        Text("Required Distribution")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(result.annualRMD, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                } else {
                    HStack {
                        Text("Required Distribution")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("None")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // 10-year deadline warning
                if let deadline = result.mustEmptyByYear, let remaining = result.yearsRemaining {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(remaining <= 1 ? .red : .orange)
                        Text("Must empty by end of \(deadline) (\(remaining) year\(remaining == 1 ? "" : "s") remaining)")
                            .font(.caption)
                            .foregroundStyle(remaining <= 1 ? .red : .orange)
                    }
                }

                // Extra withdrawal slider
                if extraMax > 0 {
                    Divider()
                    WithdrawalSliderCard(
                        label: "Extra Withdrawal",
                        amount: inheritedWithdrawalBinding(for: account.id),
                        sliderMax: extraMax,
                        tint: .indigo
                    )
                }

                // Roth tax-free note
                if isRoth {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Roth \u{2014} withdrawals are tax-free")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // Combined total
        if dataManager.inheritedExtraWithdrawalTotal > 0 {
            Divider()
            HStack {
                Text("Total Inherited Extra Withdrawals")
                    .fontWeight(.semibold)
                Spacer()
                Text(dataManager.inheritedExtraWithdrawalTotal, format: .currency(code: "USD"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.indigo)
            }
            if dataManager.inheritedTraditionalExtraTotal > 0 && dataManager.inheritedTraditionalExtraTotal < dataManager.inheritedExtraWithdrawalTotal {
                HStack {
                    Text("Taxable (Traditional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(dataManager.inheritedTraditionalExtraTotal, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    /// Creates a Binding into the inheritedExtraWithdrawals dictionary for a specific account UUID.
    private func inheritedWithdrawalBinding(for accountId: UUID) -> Binding<Double> {
        Binding<Double>(
            get: { dataManager.inheritedExtraWithdrawals[accountId] ?? 0 },
            set: { newValue in
                if newValue > 0 {
                    dataManager.inheritedExtraWithdrawals[accountId] = newValue
                } else {
                    dataManager.inheritedExtraWithdrawals.removeValue(forKey: accountId)
                }
            }
        )
    }

    /// Dynamic step number for charitable contributions (shifts when inherited accounts exist)
    private var charitableStepNumber: Int {
        dataManager.hasInheritedAccounts ? 4 : 3
    }

    // MARK: - Collapsed Summary Cards (open sheets on tap)

    private var rothConversionCard: some View {
        VStack(spacing: 0) {
            ScenarioStepCard(
                stepNumber: 1,
                title: "Roth Conversions",
                description: "Move funds from a Traditional IRA to a Roth IRA. You\u{2019}ll pay tax now, but future growth and withdrawals are tax-free.",
                stepColor: .orange,
                icon: "arrow.right.arrow.left",
                isExpanded: showRothSheet,
                action: { withAnimation(.easeInOut(duration: 0.3)) { showRothSheet.toggle() } }
            ) {
                rothSummary
            }

            if showRothSheet {
                VStack(alignment: .leading, spacing: 16) {
                    rothConversionContent
                }
                .padding()
                .background(Color(PlatformColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, -8)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    // MARK: - Why Consider Roth Conversions Guide

    private var rothConversionGuideCard: some View {
        Button {
            showRothGuide = true
        } label: {
            HStack(spacing: 14) {
                VStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }
                .frame(width: 44, height: 44)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Why Consider Roth Conversions?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("6 key reasons conversions can save your household thousands in taxes across your lifetime, your spouse\u{2019}s, and your heirs\u{2019}.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.08), Color.yellow.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var rothConversionGuideSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Intro
                    VStack(alignment: .leading, spacing: 8) {
                        Text("For households with large Traditional IRAs, the strategy is less about minimizing this year\u{2019}s tax bill and more about managing taxes across your entire retirement.")
                            .font(.callout)

                        Text("The goal: shift money from tax-deferred accounts into tax-free accounts at favorable rates, before RMDs begin.")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    }

                    Divider()

                    // Section 1: Low Tax Years
                    rothGuideSection(
                        number: 1,
                        icon: "calendar.badge.clock",
                        color: .blue,
                        title: "Convert During Low-Tax Years",
                        body: "Many retirees have a window between retirement and the start of RMDs (age 73) when taxable income is lower. Converting during these years lets you pay tax at moderate rates \u{2014} often the 22% or 24% brackets \u{2014} rather than higher rates that may apply later when RMDs stack on top of Social Security, dividends, and other income."
                    )

                    // Section 2: Fill Up Bracket
                    rothGuideSection(
                        number: 2,
                        icon: "chart.bar.fill",
                        color: .green,
                        title: "Fill Up the Current Tax Bracket",
                        body: "Many planners recommend converting just enough each year to stay within a desired bracket \u{2014} often the top of the 24% bracket. The logic: if RMDs later push income into the 32% bracket or higher, paying 24% today is advantageous."
                    )

                    // Section 3: Surviving Spouse
                    rothGuideSection(
                        number: 3,
                        icon: "person.fill.xmark",
                        color: .red,
                        title: "Protect the Surviving Spouse",
                        body: "When one spouse dies, the survivor files as Single, and tax brackets compress dramatically. The same income that was comfortably in the 24% bracket when filing jointly can quickly fall into the 32% bracket for a single filer. Converting while both spouses are alive lets you pay tax at joint rates and reduces future RMDs that could push the surviving spouse into higher brackets."
                    )

                    // Section 4: Better for Heirs
                    rothGuideSection(
                        number: 4,
                        icon: "gift.fill",
                        color: .purple,
                        title: "Roth Assets Are Better for Heirs",
                        body: "Under current law, most non-spouse heirs must withdraw inherited retirement accounts within 10 years. If they inherit a Traditional IRA, every dollar is taxable \u{2014} often at their own high marginal rates during peak earning years. If they inherit a Roth IRA, withdrawals are generally tax-free. Many families prefer leaving heirs larger Roth balances and smaller Traditional IRAs."
                    )

                    // Section 5: Reduce Future RMDs
                    rothGuideSection(
                        number: 5,
                        icon: "arrow.down.right",
                        color: .orange,
                        title: "Reduce Future RMDs",
                        body: "Every dollar moved into a Roth reduces the Traditional IRA balance that generates RMDs. This can lower lifetime taxable income, reduce the chance of hitting higher tax brackets, and potentially avoid Medicare premium surcharges (IRMAA)."
                    )

                    // Section 6: Gradual Approach
                    rothGuideSection(
                        number: 6,
                        icon: "stairs",
                        color: .teal,
                        title: "Convert Gradually, Not All at Once",
                        body: "Rather than converting everything at once, most strategies involve annual conversions over many years, carefully balancing tax brackets, Medicare premium thresholds (IRMAA), and cash available to pay the conversion tax."
                    )

                    Divider()

                    // Summary callout
                    VStack(alignment: .leading, spacing: 12) {
                        Label("The Three Phases", systemImage: "arrow.triangle.branch")
                            .font(.subheadline)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 10) {
                            rothGuidePhaseRow(
                                phase: "1",
                                title: "Joint Lifetime",
                                detail: "Convert at favorable joint tax rates",
                                color: .blue
                            )
                            rothGuidePhaseRow(
                                phase: "2",
                                title: "Surviving Spouse",
                                detail: "Smaller RMDs mean lower single-filer taxes",
                                color: .orange
                            )
                            rothGuidePhaseRow(
                                phase: "3",
                                title: "Inheritance",
                                detail: "Heirs receive tax-free Roth withdrawals",
                                color: .purple
                            )
                        }

                        Text("Converting portions of Traditional IRA assets to Roth before RMDs begin can smooth taxes across all three phases and shift more wealth into accounts that grow and pass to heirs tax-free.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // CTA
                    HStack(spacing: 8) {
                        Image(systemName: "hand.point.up.left.fill")
                            .foregroundStyle(.blue)
                        Text("Use Step 1 above to model different Roth conversion amounts and see the tax impact in real time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)
                }
                .padding()
            }
            .background(Color(PlatformColor.systemGroupedBackground))
            .navigationTitle("Why Consider Roth Conversions?")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showRothGuide = false }
                }
            }
        }
    }

    private func rothGuideSection(number: Int, icon: String, color: Color, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Text(body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rothGuidePhaseRow(phase: String, title: String, detail: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(phase)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(color)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var rothSummary: some View {
        if totalRothConversion > 0 {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                if dataManager.yourRothConversion > 0 {
                    summaryRow(label: spouseEnabled ? "Your Conversion" : "Conversion", value: dataManager.yourRothConversion, color: .orange)
                }
                if spouseEnabled && dataManager.spouseRothConversion > 0 {
                    summaryRow(label: "\(spouseLabel)'s Conversion", value: dataManager.spouseRothConversion, color: .orange)
                }
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("No conversions configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var withdrawalCard: some View {
        VStack(spacing: 0) {
            ScenarioStepCard(
                stepNumber: 2,
                title: "IRA/401(k) Withdrawals",
                description: "Withdraw cash from your retirement savings. RMDs are shown automatically. Extra withdrawals add to taxable income.",
                stepColor: .blue,
                icon: "banknote",
                isExpanded: showWithdrawalSheet,
                action: { withAnimation(.easeInOut(duration: 0.3)) { showWithdrawalSheet.toggle() } }
            ) {
                withdrawalSummary
            }

            if showWithdrawalSheet {
                VStack(alignment: .leading, spacing: 16) {
                    withdrawalContent
                }
                .padding()
                .background(Color(PlatformColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, -8)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    @ViewBuilder
    private var withdrawalSummary: some View {
        if combinedRMD > 0 || totalExtraWithdrawal > 0 {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                if combinedRMD > 0 {
                    summaryRow(label: "Required RMD", value: combinedRMD, color: .red)
                }
                if totalExtraWithdrawal > 0 {
                    summaryRow(label: "Extra Withdrawals", value: totalExtraWithdrawal, color: .blue)
                }
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(dataManager.isRMDRequired ? "RMD required \u{2014} tap Adjust" : "No withdrawals configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var inheritedWithdrawalCard: some View {
        if dataManager.hasInheritedAccounts {
            VStack(spacing: 0) {
                ScenarioStepCard(
                    stepNumber: 3,
                    title: "Inherited IRA Withdrawals",
                    description: "Required distributions from inherited IRAs. You can take extra withdrawals beyond the required amount.",
                    stepColor: .indigo,
                    icon: "archivebox",
                    isExpanded: showInheritedSheet,
                    action: { withAnimation(.easeInOut(duration: 0.3)) { showInheritedSheet.toggle() } }
                ) {
                    inheritedSummary
                }

                if showInheritedSheet {
                    VStack(alignment: .leading, spacing: 16) {
                        inheritedWithdrawalContent
                    }
                    .padding()
                    .background(Color(PlatformColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.top, -8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
        }
    }

    @ViewBuilder
    private var inheritedSummary: some View {
        let totalRequired = dataManager.inheritedIRARMDTotal
        let totalExtra = dataManager.inheritedExtraWithdrawalTotal
        if totalRequired > 0 || totalExtra > 0 {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                if totalRequired > 0 {
                    summaryRow(label: "Required Distribution", value: totalRequired, color: .red)
                }
                if totalExtra > 0 {
                    summaryRow(label: "Extra Withdrawals", value: totalExtra, color: .indigo)
                }
                HStack(spacing: 4) {
                    Text("\(dataManager.inheritedAccounts.count) account\(dataManager.inheritedAccounts.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("\(dataManager.inheritedAccounts.count) inherited account\(dataManager.inheritedAccounts.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var charitableCard: some View {
        VStack(spacing: 0) {
            ScenarioStepCard(
                stepNumber: charitableStepNumber,
                title: "Charitable Contributions",
                description: "Reduce your tax burden through QCDs, appreciated stock donations, and cash gifts.",
                stepColor: .green,
                icon: "heart.circle",
                isExpanded: showCharitableSheet,
                action: { withAnimation(.easeInOut(duration: 0.3)) { showCharitableSheet.toggle() } }
            ) {
                charitableSummary
            }

            if showCharitableSheet {
                VStack(alignment: .leading, spacing: 16) {
                    charitableContent
                }
                .padding()
                .background(Color(PlatformColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, -8)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    @ViewBuilder
    private var charitableSummary: some View {
        if hasAnyCharitable {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                if totalQCD > 0 {
                    summaryRow(label: "QCD", value: totalQCD, color: .green)
                }
                if dataManager.stockDonationEnabled && stockCurrentValueNum > 0 {
                    summaryRow(label: "Stock Donation", value: stockCurrentValueNum, color: .green)
                }
                if dataManager.cashDonationAmount > 0 {
                    summaryRow(label: "Cash Donation", value: dataManager.cashDonationAmount, color: .green)
                }
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("No donations configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Reusable summary row for collapsed cards
    private func summaryRow(label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value, format: .currency(code: "USD"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    // MARK: - Charitable Contributions

    private var charitableStep: some View {
        ScenarioStepSection(
            stepNumber: charitableStepNumber,
            title: "Charitable Contributions",
            description: "Reduce your tax burden through charitable giving. QCDs (age 70\u{00BD}+) transfer IRA funds directly to charity and can satisfy RMDs tax-free. Donating appreciated stock avoids tax on unrealized gains \u{2014} long-term holdings get a fair market value deduction, while short-term holdings are deductible at cost basis. Cash donations provide a deduction when itemizing. Each method has different tax benefits \u{2014} combine them to optimize your strategy.",
            stepColor: .green,
            icon: "heart.circle"
        ) {
            charitableContent
        }
    }

    @ViewBuilder
    private var charitableContent: some View {
        if hasAnyCharitable {
            HStack {
                Spacer()
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
                    // Your QCD slider
                    if dataManager.isQCDEligible {
                        VStack(spacing: 10) {
                            HStack {
                                if spouseEnabled {
                                    Label("Your QCD", systemImage: "person.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("QCD Amount")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                CurrencyField(value: $dataManager.yourQCDAmount, range: 0...yourMaxQCD, color: .green)
                            }

                            Slider(value: $dataManager.yourQCDAmount, in: 0...yourMaxQCD, step: 500)
                                .tint(.green)

                            HStack {
                                Text("$0")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Max: \(yourMaxQCD, format: .currency(code: "USD"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Spouse QCD slider
                    if spouseEnabled && dataManager.spouseIsQCDEligible {
                        VStack(spacing: 10) {
                            HStack {
                                Label("\(spouseLabel)'s QCD", systemImage: "person.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                CurrencyField(value: $dataManager.spouseQCDAmount, range: 0...spouseMaxQCD, color: .green)
                            }

                            Slider(value: $dataManager.spouseQCDAmount, in: 0...spouseMaxQCD, step: 500)
                                .tint(.green)

                            HStack {
                                Text("$0")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Max: \(spouseMaxQCD, format: .currency(code: "USD"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Combined total (only when spouse enabled and either has amount)
                    if spouseEnabled && totalQCD > 0 {
                        Divider()
                        HStack {
                            Text("Combined QCD")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(totalQCD, format: .currency(code: "USD"))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                    }

                    // RMD satisfaction (when RMD exists)
                    if totalQCD > 0 && combinedRMD > 0 {
                        Divider()
                        HStack {
                            Text("RMD Satisfied by QCD")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(min(totalQCD, combinedRMD), format: .currency(code: "USD"))
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

                    // No-RMD note
                    if totalQCD > 0 && combinedRMD == 0 {
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

        if dataManager.hasInheritedAccounts {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.orange)
                Text("Inherited IRA distributions are not eligible for QCDs. Only distributions from your own Traditional IRA qualify for QCD treatment.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
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
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
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
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 120)
                            }
                        }

                        DatePicker("Purchase Date", selection: $dataManager.stockPurchaseDate, in: ...Date(), displayedComponents: .date)
                            .font(.callout)
                            #if os(macOS)
                            .datePickerStyle(.field)
                            #endif
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
                                    .foregroundStyle(stockIsLongTerm ? .green : .orange)
                            }

                            if !stockIsLongTerm {
                                Text("Short-term holding \u{2014} deduction limited to cost basis, but donating still avoids tax on the gain")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
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

                                HStack {
                                    Text(stockIsLongTerm ? "Cap Gains Tax Avoided" : "Income Tax Avoided")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(stockGainAvoided, format: .currency(code: "USD"))
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                                .padding(.leading, 8)

                                if !stockIsLongTerm {
                                    Text("Short-term gain would be taxed as ordinary income if sold")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .italic()
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
                    CurrencyField(value: $dataManager.cashDonationAmount, range: 0...200_000, color: .primary)
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

    // MARK: - Charitable Info Sheet

    // MARK: - How Contribution Types Impact Taxes Guide

    private var charitableGuideCard: some View {
        Button {
            showCharitableGuide = true
        } label: {
            HStack(spacing: 14) {
                VStack {
                    Image(systemName: "heart.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .frame(width: 44, height: 44)
                .background(Color.green.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("How Contribution Types Impact Taxes")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Learn how QCDs, stock donations, and cash gifts each reduce your tax burden in different ways.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.08), Color.blue.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var charitableGuideSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Section 1: Traditional Deductions & Roth Strategy
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Traditional Charitable Deductions", systemImage: "gift.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)

                        Text("Charitable giving can play a useful role in managing taxes and smoothing income over time, especially for retirees who are trying to stay within a specific tax bracket while doing Roth conversions. Traditional charitable contributions\u{2014}whether made in cash or appreciated stock\u{2014}generally reduce taxable income if you itemize deductions. By lowering taxable income, these deductions can create additional \u{201C}room\u{201D} within a tax bracket, which can allow you to convert more money from a traditional IRA to a Roth IRA without moving into a higher marginal tax rate.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(PlatformColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 3)

                    // Section 2: Appreciated Stock
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Donating Appreciated Stock", systemImage: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)

                        Text("Donating appreciated stock can be particularly efficient because you typically receive a charitable deduction equal to the market value of the shares while avoiding the capital gains tax that would have been owed if the stock were sold. This makes stock donations a powerful way to support charities while simultaneously reducing the taxable income reported on your return. Cash donations work similarly from a deduction standpoint, though they do not provide the added benefit of eliminating embedded capital gains.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(PlatformColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 3)

                    // Section 3: QCDs
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Qualified Charitable Distributions (QCDs)", systemImage: "heart.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)

                        Text("For retirees over age 70\u{00BD}, Qualified Charitable Distributions (QCDs) from an IRA offer an even more powerful planning tool. A QCD sends funds directly from the IRA to a charity and the distribution is excluded from taxable income, even though it can count toward satisfying required minimum distributions (RMDs). Because the distribution never appears in adjusted gross income (AGI), QCDs can reduce both taxable income and modified AGI, which may help manage tax brackets and potentially reduce exposure to IRMAA Medicare surcharges.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(PlatformColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 3)

                    // Section 4: Combined Strategy
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Combining Strategies", systemImage: "arrow.triangle.merge")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)

                        Text("Used strategically, a combination of charitable deductions, appreciated stock donations, and QCDs can help manage income levels while creating more flexibility to perform Roth conversions within a targeted tax bracket.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(PlatformColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
                }
                .padding()
            }
            .background(Color(PlatformColor.systemGroupedBackground))
            .navigationTitle("Contribution Tax Impact")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showCharitableGuide = false }
                }
            }
        }
    }

    // MARK: - Tax Impact Section

    @ViewBuilder
    private var scenarioSummaryCard: some View {
        if dataManager.hasActiveScenario {
            let beforeTaxable = max(0, dataManager.scenarioBaseIncome - dataManager.effectiveDeductionAmount)
            let afterTaxable = dataManager.scenarioTaxableIncome
            let beforeFedTax = dataManager.calculateFederalTax(income: beforeTaxable, filingStatus: dataManager.filingStatus)
            let beforeStateTax = dataManager.calculateStateTax(income: beforeTaxable, filingStatus: dataManager.filingStatus)
            let beforeTotalTax = beforeFedTax + beforeStateTax
            let afterTotalTax = dataManager.scenarioTotalTax + dataManager.scenarioIRMAATotalSurcharge
            let additionalTax = afterTotalTax - beforeTotalTax
            let additionalIncome = afterTaxable - beforeTaxable
            let effectiveOnScenario = additionalIncome > 0 ? additionalTax / additionalIncome : 0
            let isItemizing = dataManager.scenarioEffectiveItemize
            let wouldItemizeWithout = dataManager.totalItemizedDeductions > dataManager.standardDeductionAmount + additionalIncome * 0.01 // rough check
            let switchedToItemized = isItemizing && dataManager.baseItemizedDeductions < dataManager.standardDeductionAmount

            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.85), .purple.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scenario Summary")
                            .font(.headline)
                        Text("Impact of your scenario decisions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Taxable Income Before → After
                HStack {
                    Text("Taxable Income")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(beforeTaxable, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.subheadline)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(afterTaxable, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(afterTaxable > beforeTaxable ? .red : .green)
                }

                // Deduction Status
                VStack(alignment: .leading, spacing: 4) {
                    if switchedToItemized {
                        // Show before → after with explanation
                        HStack {
                            Text("Deduction")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Standard \(dataManager.standardDeductionAmount, format: .currency(code: "USD").precision(.fractionLength(0)))")
                                .font(.subheadline)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Itemized \(dataManager.totalItemizedDeductions, format: .currency(code: "USD").precision(.fractionLength(0)))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                        let extraDeduction = dataManager.totalItemizedDeductions - dataManager.standardDeductionAmount
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption2)
                            Text("Charitable giving triggers itemizing — \(extraDeduction, format: .currency(code: "USD").precision(.fractionLength(0))) more in deductions")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    } else {
                        HStack {
                            Text("Deduction")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(isItemizing ? "Itemized" : "Standard")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(dataManager.effectiveDeductionAmount, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // Total Additional Tax
                HStack {
                    Text("Additional Tax from Scenario")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(additionalTax, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(additionalTax > 0 ? .red : .green)
                }

                // Effective Rate on Scenario Income
                if additionalIncome > 0, let analysis = scenarioAnalysis {
                    HStack {
                        Text("Effective Rate on Scenario")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        let combinedRate = analysis.federalEffectiveRate + analysis.stateEffectiveRate
                        Text(String(format: "%.1f%%", combinedRate * 100))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(String(format: "(Fed %.1f%% + %@ %.1f%%)", analysis.federalEffectiveRate * 100, dataManager.selectedState.abbreviation, analysis.stateEffectiveRate * 100))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
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
                    Text(dataManager.selectedState.abbreviation)
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
            .background(Color(PlatformColor.systemBackground))
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

                // State bracket analysis — conditional on tax system type
                if case .progressive = dataManager.selectedStateConfig.taxSystem {
                    BracketAnalysisCard(
                        title: dataManager.selectedState.rawValue,
                        bracketBefore: analysis.stateBracketBefore,
                        bracketAfter: analysis.stateBracketAfter,
                        marginalBefore: analysis.stateMarginalBefore,
                        marginalAfter: analysis.stateMarginalAfter,
                        crosses: analysis.crossesStateBracket,
                        color: .orange
                    )
                } else if case .flat(let rate) = dataManager.selectedStateConfig.taxSystem {
                    HStack {
                        Text(dataManager.selectedState.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        Spacer()
                        Text(String(format: "Flat rate: %.2f%%", rate * 100))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if case .noIncomeTax = dataManager.selectedStateConfig.taxSystem {
                    HStack {
                        Text(dataManager.selectedState.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        Spacer()
                        Text("No state income tax")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                } else if case .specialLimited = dataManager.selectedStateConfig.taxSystem {
                    HStack {
                        Text(dataManager.selectedState.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        Spacer()
                        Text("No general income tax")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - IRMAA Analysis Section

    @ViewBuilder
    private var irmaaAnalysisSection: some View {
        if dataManager.medicareMemberCount > 0 {
            let irmaa = dataManager.scenarioIRMAA
            let baseline = dataManager.baselineIRMAA
            let memberCount = dataManager.medicareMemberCount

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "cross.case.fill")
                        .foregroundStyle(.pink)
                    Text("Medicare IRMAA")
                        .font(.headline)
                }

                // Current MAGI and Tier
                HStack {
                    Text("Estimated MAGI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(dataManager.estimatedAGI, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("IRMAA Tier")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(irmaa.tier == 0 ? "Standard (no surcharge)" : "Tier \(irmaa.tier)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(irmaa.tier > 0 ? .red : .green)
                }

                // Surcharge amount
                if irmaa.tier > 0 {
                    HStack {
                        Text("Annual Surcharge")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(irmaa.annualSurchargePerPerson, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                            if memberCount > 1 {
                                Text("per person")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if memberCount > 1 {
                        HStack {
                            Text("Household Total (\(memberCount) on Medicare)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(dataManager.scenarioIRMAATotalSurcharge, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                    }

                    // Monthly premium breakdown
                    HStack {
                        Text("Monthly Part B Premium")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(irmaa.monthlyPartB, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    if irmaa.monthlyPartD > 0 {
                        HStack {
                            Text("Monthly Part D Surcharge")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(irmaa.monthlyPartD, format: .currency(code: "USD"))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }

                Divider()

                // Distance to next cliff
                if let distanceToNext = irmaa.distanceToNextTier, distanceToNext > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
                            .foregroundStyle(distanceToNext < 10_000 ? .orange : .blue)
                        Text("\(distanceToNext, format: .currency(code: "USD")) until next IRMAA tier")
                            .font(.caption)
                            .foregroundStyle(distanceToNext < 10_000 ? .orange : .secondary)
                    }
                }

                // Distance above current tier — actionable: drop a tier
                if irmaa.tier > 0, let distanceToPrev = irmaa.distanceToPreviousTier {
                    let savingsPerPerson = irmaa.annualSurchargePerPerson - dataManager.scenarioIRMAAPreviousTierAnnualSurcharge
                    let householdSavings = savingsPerPerson * Double(memberCount)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You're \(distanceToPrev + 1, format: .currency(code: "USD")) above the Tier \(irmaa.tier) cliff")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("Reduce income by that amount to save \(householdSavings, format: .currency(code: "USD"))/year\(memberCount > 1 ? " household" : "")")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Tier change warning
                if dataManager.scenarioPushedToHigherIRMAATier {
                    let additionalCost = (irmaa.annualSurchargePerPerson - baseline.annualSurchargePerPerson) * Double(memberCount)
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Scenario decisions push you from Tier \(baseline.tier) to Tier \(irmaa.tier) — adding \(additionalCost, format: .currency(code: "USD"))/year in surcharges")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // 2-year lookback note
                Text("IRMAA is based on income from 2 years prior. Your \(String(dataManager.currentYear)) income decisions will affect \(String(dataManager.currentYear + 2)) Medicare premiums.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - NIIT Analysis Section

    @ViewBuilder
    private var niitAnalysisSection: some View {
        if dataManager.scenarioNetInvestmentIncome > 0 {
            let niit = dataManager.scenarioNIIT
            let baseline = dataManager.baselineNIIT

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "percent")
                        .foregroundStyle(.red)
                    Text("Net Investment Income Tax")
                        .font(.headline)
                }

                HStack {
                    Text("Net Investment Income")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(niit.netInvestmentIncome, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Estimated MAGI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(niit.magi, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("NIIT Threshold (\(dataManager.filingStatus == .single ? "Single" : "MFJ"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(niit.threshold, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Divider()

                if niit.annualNIITax > 0 {
                    HStack {
                        Text("MAGI Excess Over Threshold")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(niit.magiExcess, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Taxable NII (lesser of NII or excess)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(niit.taxableNII, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("NIIT (3.8%)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(niit.annualNIITax, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }

                    if dataManager.scenarioIncreasedNIIT {
                        let additionalNIIT = niit.annualNIITax - baseline.annualNIITax
                        if additionalNIIT > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text("Scenario decisions add \(additionalNIIT, format: .currency(code: "USD")) in NIIT by raising MAGI above the threshold")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: niit.distanceToThreshold < 10_000 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                            .foregroundStyle(niit.distanceToThreshold < 10_000 ? .orange : .green)
                        Text("NIIT: Below threshold (no surtax)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(niit.distanceToThreshold < 10_000 ? .orange : .green)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: niit.distanceToThreshold < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
                            .foregroundStyle(niit.distanceToThreshold < 10_000 ? .orange : .blue)
                            .font(.caption)
                        Text("\(niit.distanceToThreshold, format: .currency(code: "USD")) below NIIT threshold")
                            .font(.caption)
                            .foregroundStyle(niit.distanceToThreshold < 10_000 ? .orange : .secondary)
                    }
                }

                Text("NIIT applies to the lesser of your net investment income or MAGI above \(niit.threshold, format: .currency(code: "USD")). Roth conversions and withdrawals raise MAGI but are not investment income.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
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
            .background(Color(PlatformColor.systemBackground))
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
                CurrencyField(value: $amount, range: 0...sliderMax, color: .primary)
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
                CurrencyField(value: $amount, range: 0...sliderMax, color: .primary)
            }

            Slider(value: $amount, in: 0...sliderMax, step: 1_000)
                .tint(tint)

            HStack {
                Text("$0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(sliderMax, format: .currency(code: "USD"))
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
    let stockDonationValue: Double      // FMV — what the charity receives
    let stockDeductionAmount: Double    // FMV for long-term, cost basis for short-term
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

        // Stock donation deduction (if itemizing — FMV for long-term, cost basis for short-term)
        if stockDeductionAmount > 0 && itemizeDeductions {
            income -= stockDeductionAmount
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
                    Text("State Tax (\(dataManager.selectedState.abbreviation))")
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
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Currency Input Field

/// An editable text field that syncs with a Double binding.
/// Shows the current value formatted as currency; typing a number updates the binding
/// (and any connected slider). Clamps to min...max on commit.
struct CurrencyField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("$0", text: $text)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .multilineTextAlignment(.trailing)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .frame(width: 100)
            .focused($isFocused)
            .onAppear { text = formatValue(value) }
            .onSubmit { commitText() }
            .onChange(of: value) { _, newValue in
                if !isFocused { text = formatValue(newValue) }
            }
            .onChange(of: text) { _, newText in
                // Live-parse while typing so slider and model stay in sync
                if isFocused {
                    let cleaned = newText.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "")
                    if let parsed = Double(cleaned), parsed >= range.lowerBound {
                        value = min(parsed, range.upperBound)
                    }
                }
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    // Show raw number for easier editing
                    text = value == 0 ? "" : "\(Int(value))"
                } else {
                    commitText()
                }
            }
    }

    private func commitText() {
        let parsed = Double(text.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "")) ?? 0
        value = min(max(parsed, range.lowerBound), range.upperBound)
        text = formatValue(value)
    }

    private func formatValue(_ v: Double) -> String {
        v.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

// MARK: - Quarter Picker

struct QuarterPicker: View {
    let label: String
    @Binding var quarter: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Picker(label, selection: $quarter) {
                Text("Q1").tag(1)
                Text("Q2").tag(2)
                Text("Q3").tag(3)
                Text("Q4").tag(4)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }
}

// MARK: - Scenario Step Card (collapsed summary with Adjust button)

struct ScenarioStepCard<Summary: View>: View {
    let stepNumber: Int
    let title: String
    let description: String
    let stepColor: Color
    let icon: String
    let isExpanded: Bool
    let action: () -> Void
    @ViewBuilder let summary: () -> Summary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: number + icon + title + Adjust/Done button
            HStack(alignment: .top, spacing: 12) {
                Text("\(stepNumber)")
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(stepColor)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .foregroundStyle(stepColor)
                            .font(.subheadline)
                        Text(title)
                            .font(.headline)
                    }
                    if !isExpanded {
                        Text(description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Button(action: action) {
                    Text(isExpanded ? "Done" : "Adjust")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(isExpanded ? stepColor : stepColor.opacity(0.12))
                        .foregroundStyle(isExpanded ? .white : stepColor)
                        .clipShape(Capsule())
                }
            }

            // Summary of current values (only when collapsed)
            if !isExpanded {
                summary()
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Scenario Step Section

struct ScenarioStepSection<Content: View>: View {
    let stepNumber: Int
    let title: String
    let description: String
    let stepColor: Color
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Step header with numbered circle
            HStack(alignment: .top, spacing: 12) {
                Text("\(stepNumber)")
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(stepColor)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .foregroundStyle(stepColor)
                            .font(.subheadline)
                        Text(title)
                            .font(.headline)
                    }
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
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
