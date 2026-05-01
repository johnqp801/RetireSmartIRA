//
//  SocialSecurityPlannerView.swift
//  RetireSmartIRA
//
//  Main Social Security Planner tab — adaptive layout with benefit entry,
//  claiming optimizer, what-if sliders, and tax sync.
//

import SwiftUI
import Charts

struct SocialSecurityPlannerView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDataEntry = false
    @State private var dataEntryInitialMode: SSDataEntryView.EntryMode = .quickEntry
    @State private var dataEntryPresetClaiming = false
    @State private var showClaimingDetail = false
    @State private var claimingDetailOwner: Owner = .primary
    @State private var showCouplesStrategy = false
    @State private var showSurvivorAnalysis = false
    @State private var showInfoPopover = false
    @State private var chartOwner: Owner = .primary

    @Environment(\.availableWidth) private var availableWidth
    private var isWideLayout: Bool { horizontalSizeClass == .regular && availableWidth > 700 }

    var body: some View {
        Group {
            if isWideLayout {
                wideBody
            } else {
                compactBody
            }
        }
        .background(Color(PlatformColor.systemGroupedBackground))
        .sheet(isPresented: $showDataEntry) {
            SSDataEntryView(initialMode: dataEntryInitialMode, presetAlreadyClaiming: dataEntryPresetClaiming)
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showClaimingDetail) {
            SSClaimingOptimizerView(owner: claimingDetailOwner)
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showCouplesStrategy) {
            SSCouplesStrategyView()
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showSurvivorAnalysis) {
            SSSurvivorAnalysisView()
                .environmentObject(dataManager)
        }
    }

    // MARK: - Compact Layout (iPhone)

    private var compactBody: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                statusCard

                if hasBenefitData {
                    assumptionsCard
                }

                if bothEffectivelyClaimed {
                    // Simplified: both have claimed
                    currentBenefitsSummaryCard
                    if hasBenefitData {
                        taxImpactCard
                    }
                    taxSyncCard
                    if hasSurvivorData {
                        survivorCard
                    }
                    if hasCouplesData {
                        alternateScenarioDisclosure
                    }
                } else {
                    // Still planning
                    if hasBenefitData && !dataManager.enableSpouse && anyonePlanning {
                        keyDecisionAnchor
                    }
                    if hasBenefitData && bothPlanning {
                        individualSectionHeader
                    }
                    primaryBenefitCard
                    if dataManager.enableSpouse {
                        spouseBenefitCard
                    }
                    if hasBenefitData {
                        // Couples strategy first — it's the most important decision for married couples
                        if bothPlanning || oneClaimedOnePlanning {
                            couplesSectionHeader
                            couplesStrategyCard
                        }
                        if hasSurvivorData {
                            survivorCard
                        }
                        if anyonePlanning {
                            claimingOptimizerCard
                        }
                        taxImpactCard
                        taxSyncCard
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Wide Layout (iPad / macOS)

    private var wideBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Full-width top section: status + assumptions
                LazyVStack(spacing: 24) {
                    statusCard

                    if hasBenefitData {
                        assumptionsCard
                    }
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 12)

                if bothEffectivelyClaimed {
                    // Simplified layout: both have claimed, no analysis needed
                    LazyVStack(spacing: 24) {
                        currentBenefitsSummaryCard
                        if hasBenefitData {
                            taxImpactCard
                        }
                        taxSyncCard
                        if hasSurvivorData {
                            survivorCard
                        }
                        if hasCouplesData {
                            alternateScenarioDisclosure
                        }
                    }
                    .padding([.horizontal, .bottom])
                } else {
                    // Two-column layout: still planning
                    HStack(alignment: .top, spacing: 20) {
                        LazyVStack(spacing: 24) {
                            if hasBenefitData && !dataManager.enableSpouse && anyonePlanning {
                                keyDecisionAnchor
                            }
                            if hasBenefitData && bothPlanning {
                                individualSectionHeader
                            }
                            primaryBenefitCard
                            if dataManager.enableSpouse {
                                spouseBenefitCard
                            }
                            if hasBenefitData {
                                taxImpactCard
                            }
                            taxSyncCard
                        }
                        .frame(maxWidth: .infinity)

                        LazyVStack(spacing: 24) {
                            if hasBenefitData {
                                if anyonePlanning {
                                    claimingOptimizerCard
                                }
                                if bothPlanning || oneClaimedOnePlanning {
                                    couplesSectionHeader
                                    couplesStrategyCard
                                }
                                if hasSurvivorData {
                                    survivorCard
                                }
                            } else {
                                emptyAnalysisCard
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding([.horizontal, .bottom])
                }
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Social Security")
                            .font(.headline)
                        if hasBenefitData && bothPlanning {
                            InfoButton {
                                showInfoPopover.toggle()
                            }
                            .popover(isPresented: $showInfoPopover) {
                                analysisInfoPopover
                            }
                        }
                    }

                    // Contextual mode label
                    if hasBenefitData {
                        Text(statusModeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if hasBenefitData {
                        let effectiveResult = dataManager.ssEffectiveMonthlyBenefit(for: .primary)
                        let monthly = effectiveResult.monthly
                        if let b = dataManager.primarySSBenefit, b.isAlreadyClaiming {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.UI.brandTeal)
                                Text("Receiving Benefits")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        } else if effectiveResult.isCollecting {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.UI.brandTeal)
                                Text("Collecting")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        } else {
                            let planned = dataManager.primarySSBenefit?.plannedClaimingAge ?? 67
                            let yearsUntil = planned - dataManager.currentAge
                            HStack(spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(Color.UI.brandTeal)
                                Text("Starts at Age \(planned)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                if yearsUntil > 0 {
                                    Text("(in \(yearsUntil) yr\(yearsUntil == 1 ? "" : "s"))")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if monthly > 0 {
                            Text(SSCalculationEngine.formatCurrency(monthly) + "/mo  \u{2022}  " +
                                 SSCalculationEngine.formatCurrency(monthly * 12) + "/yr")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(Color.UI.brandTeal)
                                Text("Enter your SSA benefit estimates to get started")
                                    .font(.callout)
                            }
                            Text("Start with estimates from ssa.gov/myaccount \u{2014} you can refine later. Already collecting? Toggle \"Already Receiving\" to enter your current payment.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Show spouse status in the header when coupled
                    if dataManager.enableSpouse && hasBenefitData {
                        let spouseResult = dataManager.ssEffectiveMonthlyBenefit(for: .spouse)
                        let sName = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
                        if spouseResult.monthly > 0 || dataManager.spouseSSBenefit?.isAlreadyClaiming == true {
                            Divider()
                            HStack(spacing: 8) {
                                Text(sName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let sb = dataManager.spouseSSBenefit, sb.isAlreadyClaiming {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.UI.brandTeal)
                                } else if !spouseResult.isCollecting {
                                    let spousePlanned = dataManager.spouseSSBenefit?.plannedClaimingAge ?? 67
                                    Text("Age \(spousePlanned)")
                                        .font(.caption)
                                        .foregroundStyle(Color.UI.brandTeal)
                                }
                                Spacer()
                                if spouseResult.monthly > 0 {
                                    Text(SSCalculationEngine.formatCurrency(spouseResult.monthly) + "/mo")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }

                Spacer()

                if hasBenefitData && !primaryAlreadyClaiming {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("FRA")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(SSCalculationEngine.fraDescription(birthYear: dataManager.birthYear))
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
            }

            if !hasBenefitData {
                VStack(spacing: 8) {
                    Button {
                        dataEntryPresetClaiming = false
                        showDataEntry = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.body)
                            Text("Enter Benefit Estimates")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        dataEntryPresetClaiming = true
                        showDataEntry = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal")
                                .font(.body)
                            Text("I'm Already Receiving Benefits")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.UI.brandTeal.opacity(0.1))
                        .foregroundStyle(Color.UI.brandTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Benefit Cards

    private var primaryBenefitCard: some View {
        let title = dataManager.userName.isEmpty ? "Your Benefits" : "\(dataManager.userName)'s Benefits"
        return benefitSummaryCard(
            owner: .primary,
            title: title,
            benefit: dataManager.primarySSBenefit,
            birthYear: dataManager.birthYear
        )
    }

    private var spouseBenefitCard: some View {
        let title = dataManager.spouseName.isEmpty ? "Spouse's Benefits" : "\(dataManager.spouseName)'s Benefits"
        return benefitSummaryCard(
            owner: .spouse,
            title: title,
            benefit: dataManager.spouseSSBenefit,
            birthYear: dataManager.spouseBirthYear
        )
    }

    private func benefitSummaryCard(owner: Owner, title: String,
                                    benefit: SSBenefitEstimate?,
                                    birthYear: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    dataEntryInitialMode = .quickEntry
                    dataEntryPresetClaiming = false
                    showDataEntry = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.caption)
                        Text("Edit")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                }
            }

            if let b = benefit, b.hasData {
                if b.isAlreadyClaiming {
                    // Simplified display for already-claiming users
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.UI.brandTeal)
                                    .font(.caption)
                                Text("Receiving Benefits")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(SSCalculationEngine.formatCurrency(b.currentBenefit) + "/mo")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(SSCalculationEngine.formatCurrency(b.currentBenefit * 12) + "/yr")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if bothPlanning || hasSurvivorData {
                        couplesConnectorLabel
                    }
                } else {
                    let fra = SSCalculationEngine.fullRetirementAge(birthYear: birthYear)
                    let plannedMonthly = SSCalculationEngine.benefitAtAge(
                        claimingAge: b.plannedClaimingAge,
                        pia: b.benefitAtFRA,
                        fraYears: fra.years, fraMonths: fra.months
                    )
                    let effectiveResult = dataManager.ssEffectiveMonthlyBenefit(for: owner)

                    // Three benefit amounts in a row (own record only — these are SSA statement values)
                    Text("Estimated monthly benefit if you start at each age:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 0) {
                        benefitColumn(label: "Age 62", amount: b.benefitAt62, color: Color.Chart.tealRamp1)
                        Spacer()
                        benefitColumn(label: "FRA", amount: b.benefitAtFRA, color: Color.Chart.tealRamp3)
                        Spacer()
                        benefitColumn(label: "Age 70", amount: b.benefitAt70, color: Color.Chart.tealRamp6)
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if effectiveResult.isCollecting {
                                Text("Collecting (claimed at \(b.plannedClaimingAge))")
                                    .font(.subheadline)
                            } else {
                                Text("Planned: Age \(b.plannedClaimingAge)")
                                    .font(.subheadline)
                            }
                            Text("FRA: \(SSCalculationEngine.fraDescription(birthYear: birthYear))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(SSCalculationEngine.formatCurrency(effectiveResult.monthly) + "/mo")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(SSCalculationEngine.formatCurrency(effectiveResult.monthly * 12) + "/yr")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Spousal top-up note
                    if effectiveResult.includesSpousalTopUp {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.UI.brandTeal)
                            Text("Includes \(SSCalculationEngine.formatCurrency(effectiveResult.spousalTopUp))/mo spousal top-up")
                                .font(.caption)
                                .foregroundStyle(Color.UI.brandTeal)
                        }
                    } else if !effectiveResult.isCollecting {
                        // Not collecting yet — show own-record amount
                        let yearsUntil = b.plannedClaimingAge - (dataManager.currentYear - birthYear)
                        if yearsUntil > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("Starts in \(yearsUntil) year\(yearsUntil == 1 ? "" : "s") (\(SSCalculationEngine.formatCurrency(plannedMonthly))/mo own benefit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            claimingDetailOwner = owner
                            showClaimingDetail = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.caption)
                                Text("Claiming Analysis")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            dataEntryInitialMode = .earningsHistory
                            dataEntryPresetClaiming = false
                            showDataEntry = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                Text("Import Earnings")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    if bothPlanning || hasSurvivorData {
                        couplesConnectorLabel
                    }
                }
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("Add benefit estimates from your SSA statement")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    dataEntryPresetClaiming = false
                    showDataEntry = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.body)
                        Text("Enter Estimates")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func benefitColumn(label: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(SSCalculationEngine.formatCurrency(amount))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text("/mo")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Claiming Optimizer Card

    private var claimingOptimizerCard: some View {
        // Determine which owner to show: only people still planning
        let effectiveOwner: Owner
        if bothPlanning {
            effectiveOwner = chartOwner
        } else if !primaryAlreadyClaiming {
            effectiveOwner = .primary
        } else {
            effectiveOwner = .spouse
        }

        let chartData = dataManager.ssCumulativeChartData(for: effectiveOwner)
        let breakEvens = dataManager.ssBreakEvenComparisons(for: effectiveOwner)
        let lifeExp = effectiveOwner == .primary
            ? dataManager.ssWhatIfParams.primaryLifeExpectancy
            : dataManager.ssWhatIfParams.spouseLifeExpectancy
        let benefit = effectiveOwner == .primary ? dataManager.primarySSBenefit : dataManager.spouseSSBenefit

        let filteredData = chartData.filter { point in
            point.scenarioLabel.contains("62") ||
            point.scenarioLabel.contains("FRA") ||
            point.scenarioLabel.contains("67") ||
            point.scenarioLabel.contains("70")
        }

        return VStack(spacing: 0) {
            if bothPlanning {
                // Both planning — show picker to toggle between them
                VStack(spacing: 8) {
                    let primaryName = dataManager.userName.isEmpty ? "You" : dataManager.userName
                    let spouseName = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
                    HStack {
                        Text("Individual View")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Individual View", selection: $chartOwner) {
                            Text(primaryName).tag(Owner.primary)
                            Text(spouseName).tag(Owner.spouse)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    Text("Individual claiming outcomes \u{2014} see Couples Strategy for combined optimization")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }

            SSCumulativeBenefitsChart(
                chartData: filteredData,
                lifeExpectancy: lifeExp,
                breakEvenComparisons: breakEvens,
                highlightClaimingAge: benefit?.plannedClaimingAge
            )
        }
    }

    // MARK: - Assumptions Card

    private var assumptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                Text("Assumptions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            if isWideLayout {
                HStack(spacing: 24) {
                    assumptionSliders
                }
            } else {
                VStack(spacing: 12) {
                    assumptionSliders
                }
            }

            Text("Planning Horizon Age is how long you want your plan to support you — not a prediction of death. Pick high to be safe (95 is a common default).")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .onChange(of: dataManager.ssWhatIfParams.primaryLifeExpectancy) { dataManager.saveAllData() }
        .onChange(of: dataManager.ssWhatIfParams.spouseLifeExpectancy) { dataManager.saveAllData() }
        .onChange(of: dataManager.ssWhatIfParams.colaRate) { dataManager.saveAllData() }
    }

    @ViewBuilder
    private var assumptionSliders: some View {
        // Re-labeled from "Life Expectancy" — Ron Park feedback: users
        // misread that as "predict when I'll die." The right framing
        // (per Boldin and other planners): "How long do you want your
        // plan to support you?" Conservative users pick higher (95 is
        // a common default).
        assumptionSlider(
            label: "Your Planning Horizon Age",
            value: Binding(
                get: { Double(dataManager.ssWhatIfParams.primaryLifeExpectancy) },
                set: { dataManager.ssWhatIfParams.primaryLifeExpectancy = Int($0) }
            ),
            displayText: "\(dataManager.ssWhatIfParams.primaryLifeExpectancy)",
            range: 70...100,
            tint: Color.UI.brandTeal
        )

        if dataManager.enableSpouse {
            assumptionSlider(
                label: "\(dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName) Planning Horizon Age",
                value: Binding(
                    get: { Double(dataManager.ssWhatIfParams.spouseLifeExpectancy) },
                    set: { dataManager.ssWhatIfParams.spouseLifeExpectancy = Int($0) }
                ),
                displayText: "\(dataManager.ssWhatIfParams.spouseLifeExpectancy)",
                range: 70...100,
                tint: Color.Chart.callout
            )
        }

        assumptionSlider(
            label: "Annual COLA",
            value: $dataManager.ssWhatIfParams.colaRate,
            displayText: String(format: "%.1f%%", dataManager.ssWhatIfParams.colaRate),
            range: 0...5,
            step: 0.5,
            tint: Color.UI.brandTeal
        )

        valuationModeToggle
    }

    private var valuationModeToggle: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Compare values as")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: Binding(
                    get: { dataManager.ssWhatIfParams.discountRate > 0 ? 1 : 0 },
                    set: {
                        dataManager.ssWhatIfParams.discountRate = $0 == 1 ? 3.0 : 0
                        dataManager.saveAllData()
                    }
                )) {
                    Text("Total Dollars").tag(0)
                    Text("Present Value").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            if dataManager.ssWhatIfParams.discountRate > 0 {
                HStack {
                    Text("Discount Rate")
                        .font(.caption)
                    Slider(
                        value: $dataManager.ssWhatIfParams.discountRate,
                        in: 1...6, step: 0.5
                    )
                    .tint(Color.UI.brandTeal)
                    Text("\(dataManager.ssWhatIfParams.discountRate, specifier: "%.1f")%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 40, alignment: .trailing)
                }
                Text("Adjusts future dollars to today's value — favors earlier claiming at higher rates")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: dataManager.ssWhatIfParams.discountRate) { dataManager.saveAllData() }
    }

    private func assumptionSlider(
        label: String,
        value: Binding<Double>,
        displayText: String,
        range: ClosedRange<Double>,
        step: Double = 1,
        tint: Color
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(displayText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(minWidth: 40, alignment: .trailing)
            }
            Slider(value: value, in: range, step: step)
                .tint(tint)
        }
    }

    // MARK: - Tax Sync Card

    private var taxSyncCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tax Integration")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $dataManager.ssAutoSync)
                    .labelsHidden()
                    .onChange(of: dataManager.ssAutoSync) { _, newValue in
                        if newValue {
                            dataManager.syncSSToIncomeSources()
                        }
                        dataManager.saveAllData()
                    }
            }

            if dataManager.ssAutoSync {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("Benefits automatically synced to Income & Deductions")
                        .font(.callout)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.Semantic.amber)
                    Text("Auto-sync disabled. Manage SS income manually in Income & Deductions.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Empty State

    private var emptyAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claiming Analysis")
                .font(.headline)

            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.UI.brandTeal)
                Text("Enter your benefit estimates to see claiming age analysis, break-even charts, and strategy comparisons.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Couples Strategy Card

    private var couplesStrategyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Couples Strategy")
                    .font(.headline)
                Text("Recommended")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.UI.brandTeal.opacity(0.15))
                    .foregroundStyle(Color.UI.brandTeal)
                    .clipShape(Capsule())
            }

            if oneClaimedOnePlanning {
                Text("\(claimedSpouseName) has already claimed. See how \(decidingSpouseName)'s claiming age affects your combined lifetime benefits and survivor protection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Based on both profiles above. For married couples, this combined strategy is usually more important than individual results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if oneClaimedOnePlanning, let bestCell = couplesStripBestCell {
                // One spouse claimed — show filtered recommendation
                let primaryName = dataManager.userName.isEmpty ? "You" : dataManager.userName
                let spouseN = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName

                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text(primaryName)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            HStack(spacing: 4) {
                                Text("Age \(bestCell.primaryClaimingAge)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                if primaryEffectivelyClaimed {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }

                        Image(systemName: "plus")
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.caption)

                        VStack(spacing: 2) {
                            Text(spouseN)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            HStack(spacing: 4) {
                                Text("Age \(bestCell.spouseClaimingAge)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                if spouseEffectivelyClaimed {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(dataManager.ssWhatIfParams.discountRate > 0 ? "Present Value" : "Lifetime")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Text(SSCalculationEngine.formatLargeCurrency(bestCell.combinedLifetimeBenefit))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.UI.brandTeal.opacity(0.85), Color.UI.brandTeal.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    showCouplesStrategy = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.body)
                        Text("View Couples Analysis")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else if let rec = dataManager.ssCouplesTopStrategy() {
                // Both planning — show full matrix best
                let primaryName = dataManager.userName.isEmpty ? "You" : dataManager.userName
                let spouseN = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName

                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text(primaryName)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Text("Age \(rec.primaryClaimingAge)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }

                        Image(systemName: "plus")
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.caption)

                        VStack(spacing: 2) {
                            Text(spouseN)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Text("Age \(rec.spouseClaimingAge)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(dataManager.ssWhatIfParams.discountRate > 0 ? "Present Value" : "Lifetime")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Text(SSCalculationEngine.formatLargeCurrency(rec.combinedLifetime))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.UI.brandTeal.opacity(0.85), Color.UI.brandTeal.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    showCouplesStrategy = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.body)
                        Text("View Couples Analysis")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .padding(.vertical, 4)
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.UI.brandTeal.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }

    // MARK: - Alternate Scenario Disclosure (Both Claimed)

    @State private var showAlternateScenarios = false

    private var alternateScenarioDisclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation { showAlternateScenarios.toggle() }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .rotationEffect(.degrees(showAlternateScenarios ? 90 : 0))
                        .foregroundStyle(.secondary)
                    Text("Advanced: View Alternate Scenarios")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            if showAlternateScenarios {
                VStack(spacing: 16) {
                    Text("See how different claiming ages would have affected your combined lifetime benefits.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    couplesStrategyCard
                }
            }
        }
    }

    // MARK: - Survivor Card

    private var survivorCard: some View {
        let scenarios = dataManager.ssSurvivorScenarios()
        let primaryName = dataManager.userName.isEmpty ? "primary" : dataManager.userName
        let spouseName = dataManager.spouseName.isEmpty ? "spouse" : dataManager.spouseName

        return VStack(alignment: .leading, spacing: 12) {
            Text("Survivor Impact")
                .font(.headline)

            ForEach(scenarios) { scenario in
                let deceasedName = scenario.deceasedOwner == .primary ? primaryName : spouseName
                let survivorName = scenario.deceasedOwner == .primary ? spouseName : primaryName

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("If \(deceasedName) passes first")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Survivor income drops \(String(format: "%.0f", scenario.percentReduction))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.UI.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(survivorName) gets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SSCalculationEngine.formatCurrency(scenario.householdMonthlyAfter) + "/mo")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }

                if scenario.id != scenarios.last?.id {
                    Divider()
                }
            }

            if scenarios.contains(where: { $0.percentReduction > 20 }) {
                Text("Delaying the higher earner's claim can significantly reduce this drop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                showSurvivorAnalysis = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.xmark")
                        .font(.body)
                    Text("View Survivor Analysis")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Current Benefits Summary (Both Have Claimed)

    private var currentBenefitsSummaryCard: some View {
        let pResult = dataManager.ssEffectiveMonthlyBenefit(for: .primary)
        let sResult = dataManager.enableSpouse ? dataManager.ssEffectiveMonthlyBenefit(for: .spouse) : nil
        let combinedMonthly = pResult.monthly + (sResult?.monthly ?? 0)
        let pName = dataManager.userName.isEmpty ? "You" : dataManager.userName
        let sName = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(String(dataManager.currentYear)) Social Security Benefits")
                    .font(.headline)
                Spacer()
                Button {
                    dataEntryInitialMode = .quickEntry
                    dataEntryPresetClaiming = false
                    showDataEntry = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.caption)
                        Text("Edit")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                }
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.UI.brandTeal)
            }

            // Primary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let b = dataManager.primarySSBenefit {
                        Text("Claimed at age \(b.plannedClaimingAge)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(SSCalculationEngine.formatCurrency(pResult.monthly) + "/mo")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(SSCalculationEngine.formatCurrency(pResult.monthly * 12) + "/yr")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if pResult.includesSpousalTopUp {
                        Text("Includes \(SSCalculationEngine.formatCurrency(pResult.spousalTopUp)) spousal top-up")
                            .font(.caption2)
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                }
            }

            if let sResult = sResult, dataManager.enableSpouse {
                Divider()

                // Spouse
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let b = dataManager.spouseSSBenefit {
                            Text("Claimed at age \(b.plannedClaimingAge)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(SSCalculationEngine.formatCurrency(sResult.monthly) + "/mo")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(SSCalculationEngine.formatCurrency(sResult.monthly * 12) + "/yr")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if sResult.includesSpousalTopUp {
                            Text("Includes \(SSCalculationEngine.formatCurrency(sResult.spousalTopUp)) spousal top-up")
                                .font(.caption2)
                                .foregroundStyle(Color.UI.brandTeal)
                        }
                    }
                }

                Divider()

                // Combined
                HStack {
                    Text("Combined Household")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(SSCalculationEngine.formatCurrency(combinedMonthly) + "/mo")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.UI.textPrimary)
                        Text(SSCalculationEngine.formatCurrency(combinedMonthly * 12) + "/yr")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Tax Impact Card

    private var taxImpactCard: some View {
        let primaryMonthly = dataManager.ssEffectiveMonthlyBenefit(for: .primary).monthly
        let spouseMonthly = dataManager.enableSpouse ? dataManager.ssEffectiveMonthlyBenefit(for: .spouse).monthly : 0
        let totalAnnualSS = (primaryMonthly + spouseMonthly) * 12

        // Estimate taxable portion using the 50%/85% provisional income rules
        let provisionalIncome = dataManager.scenarioGrossIncome - totalAnnualSS + (totalAnnualSS * 0.5)
        let filingStatus = dataManager.filingStatus
        let threshold1: Double = filingStatus == .marriedFilingJointly ? 32000 : 25000
        let threshold2: Double = filingStatus == .marriedFilingJointly ? 44000 : 34000

        let taxableSS: Double
        if provisionalIncome <= threshold1 {
            taxableSS = 0
        } else if provisionalIncome <= threshold2 {
            taxableSS = min(totalAnnualSS * 0.50, (provisionalIncome - threshold1) * 0.50)
        } else {
            let base = min(totalAnnualSS * 0.50, (threshold2 - threshold1) * 0.50)
            taxableSS = min(totalAnnualSS * 0.85, base + (provisionalIncome - threshold2) * 0.85)
        }

        let taxablePercent = totalAnnualSS > 0 ? (taxableSS / totalAnnualSS) * 100 : 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("Tax Impact")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total SS Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(SSCalculationEngine.formatCurrency(totalAnnualSS) + "/yr")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Taxable Portion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(SSCalculationEngine.formatCurrency(taxableSS))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.UI.textPrimary)
                }
            }

            // Taxability bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.UI.surfaceInset)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.UI.brandTeal)
                        .frame(width: geo.size.width * min(taxablePercent / 100, 1.0), height: 8)
                }
            }
            .frame(height: 8)

            if taxableSS == 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.UI.brandTeal)
                        .font(.caption)
                    Text("Your Social Security benefits are not taxable at current income levels.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.UI.brandTeal)
                        .font(.caption)
                    Text("\(String(format: "%.0f", taxablePercent))% of your SS benefits are taxable. This is automatically included in your tax calculations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Section Headers

    private var individualSectionHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Benefit Estimates")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text("Each spouse's own Social Security record. The Couples Strategy below combines both.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @State private var showCouplesInfoPopover = false

    private var couplesSectionHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("Couples Optimization")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text("Recommended")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.UI.brandTeal.opacity(0.15))
                    .foregroundStyle(Color.UI.brandTeal)
                    .clipShape(Capsule())
                Button {
                    showCouplesInfoPopover.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showCouplesInfoPopover) {
                    analysisInfoPopover
                }
            }
            Text("Optimizes total lifetime income and survivor protection for both spouses together")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Info Popover

    private var analysisInfoPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Individual vs. Couples Analysis")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(Color.UI.brandTeal)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Individual Analysis")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Shows the best claiming age for each person on their own, without considering the other spouse.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(Color.UI.brandTeal)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Couples Optimization")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Looks at both spouses together and often recommends a different approach to maximize total lifetime income and protect the surviving spouse.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.UI.textSecondary)
                    .font(.caption)
                Text("In most cases, the couples strategy is the more important decision.")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .frame(width: 340)
    }

    // MARK: - Key Decision Anchor

    private var keyDecisionAnchor: some View {
        HStack(spacing: 8) {
            Image(systemName: "target")
                .foregroundStyle(Color.UI.brandTeal)
            Text("Your key decision: when to start collecting benefits")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status Mode Label

    /// Contextual subtitle telling the user what mode the SS tab is in
    private var statusModeLabel: String {
        if bothEffectivelyClaimed {
            return "Your current benefits"
        } else if oneClaimedOnePlanning {
            return "Optimizing \(decidingSpouseName)'s claiming decision"
        } else if bothPlanning {
            return "Planning your claim"
        } else if anyonePlanning {
            return "Planning your claim"
        } else {
            return ""
        }
    }

    // MARK: - Connector Label

    private var couplesConnectorLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.right")
                .font(.caption2)
            Text("Used in couples analysis below")
                .font(.caption2)
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - Helpers

    private var hasBenefitData: Bool {
        dataManager.primarySSBenefit?.hasData == true
    }

    private var hasCouplesData: Bool {
        dataManager.enableSpouse &&
        dataManager.primarySSBenefit?.hasData == true &&
        dataManager.spouseSSBenefit?.hasData == true
    }

    /// True if both spouses have benefit data (either already-claiming or planned)
    /// — used to gate survivor analysis independently of couples claiming matrix
    private var hasSurvivorData: Bool {
        dataManager.enableSpouse &&
        dataManager.primarySSBenefit?.hasData == true &&
        dataManager.spouseSSBenefit?.hasData == true
    }

    /// True if primary is already claiming
    private var primaryAlreadyClaiming: Bool {
        dataManager.primarySSBenefit?.isAlreadyClaiming == true
    }

    /// True if spouse is already claiming
    private var spouseAlreadyClaiming: Bool {
        dataManager.spouseSSBenefit?.isAlreadyClaiming == true
    }

    /// True if ALL people with benefit data are already claiming — hides optimizer/what-if entirely
    private var allAlreadyClaiming: Bool {
        guard primaryAlreadyClaiming else { return false }
        if dataManager.enableSpouse && dataManager.spouseSSBenefit?.hasData == true {
            return spouseAlreadyClaiming
        }
        return true
    }

    /// Whether primary has effectively claimed (marked "already claiming" OR past planned claiming age)
    private var primaryEffectivelyClaimed: Bool {
        guard let b = dataManager.primarySSBenefit, b.hasData else { return false }
        if b.isAlreadyClaiming { return true }
        let age = dataManager.currentYear - dataManager.birthYear
        return age >= b.plannedClaimingAge
    }

    /// Whether spouse has effectively claimed
    private var spouseEffectivelyClaimed: Bool {
        guard let b = dataManager.spouseSSBenefit, b.hasData else { return false }
        if b.isAlreadyClaiming { return true }
        let age = dataManager.currentYear - dataManager.spouseBirthYear
        return age >= b.plannedClaimingAge
    }

    /// True if both people have effectively claimed — simplifies the view
    private var bothEffectivelyClaimed: Bool {
        if dataManager.enableSpouse {
            return primaryEffectivelyClaimed && spouseEffectivelyClaimed
        }
        return primaryEffectivelyClaimed
    }

    /// True if at least one person is still planning (not already claiming) — shows optimizer/what-if
    private var anyonePlanning: Bool {
        !bothEffectivelyClaimed
    }

    /// True if both spouses are planning (not already claiming) — required for couples claiming matrix
    private var bothPlanning: Bool {
        hasCouplesData && !primaryEffectivelyClaimed && !spouseEffectivelyClaimed
    }

    /// True if exactly one spouse has claimed and the other is still planning — show focused couples analysis
    private var oneClaimedOnePlanning: Bool {
        hasCouplesData && (primaryEffectivelyClaimed != spouseEffectivelyClaimed)
    }

    /// The name of the spouse who is still deciding
    private var decidingSpouseName: String {
        if !primaryEffectivelyClaimed {
            return dataManager.userName.isEmpty ? "You" : dataManager.userName
        } else {
            return dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
        }
    }

    /// The claimed spouse's actual claiming age (for filtering the matrix)
    private var claimedSpouseActualAge: Int {
        if primaryEffectivelyClaimed {
            return dataManager.primarySSBenefit?.plannedClaimingAge ?? 67
        } else {
            return dataManager.spouseSSBenefit?.plannedClaimingAge ?? 67
        }
    }

    /// Best cell from the filtered 1×9 strip (locked to claimed spouse's actual age)
    private var couplesStripBestCell: SSCouplesMatrixCell? {
        let matrix = dataManager.ssCouplesMatrix()
        let filtered: [SSCouplesMatrixCell]
        if primaryEffectivelyClaimed {
            // Lock primary's age, vary spouse
            filtered = matrix.filter { $0.primaryClaimingAge == claimedSpouseActualAge }
        } else {
            // Lock spouse's age, vary primary
            filtered = matrix.filter { $0.spouseClaimingAge == claimedSpouseActualAge }
        }
        return filtered.max(by: { $0.combinedLifetimeBenefit < $1.combinedLifetimeBenefit })
    }

    /// The name of the spouse who has already claimed
    private var claimedSpouseName: String {
        if primaryEffectivelyClaimed {
            return dataManager.userName.isEmpty ? "You" : dataManager.userName
        } else {
            return dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
        }
    }
}
