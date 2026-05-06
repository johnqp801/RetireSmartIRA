//
//  TaxPlanningView.swift
//  RetireSmartIRA
//
//  V2.0 top-level Tax Planning tab. Wide (>900pt): master-detail HStack.
//  Compact (≤900pt): macro pane full-width + placeholder until Phase 4
//  wires the bottom sheet.
//

import SwiftUI

struct TaxPlanningView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var manager = MultiYearStrategyManager()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.availableWidth) private var availableWidth

    @State private var selectedYear: Int? = nil
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var showStrategyGuide = false
    @State private var showExportSheet = false
    @State private var exportPDFData: Data? = nil
    @State private var isGeneratingPDF = false
    @State private var showActionItemsSheet = false

    private var isWideLayout: Bool {
        horizontalSizeClass == .regular && availableWidth > 900
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content
        }
        #else
        content
        #endif
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if isWideLayout {
                wideLayout
            } else {
                compactLayout
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        triggerExport()
                    } label: {
                        Label("Export CPA Briefing", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isGeneratingPDF)
                    Button {
                        showStrategyGuide = true
                    } label: {
                        Label("Tax Strategy Guide", systemImage: "graduationcap")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showStrategyGuide) {
            TaxStrategyGuideSheet()
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showExportSheet) {
            if let pdfData = exportPDFData {
                let name = dataManager.userName.isEmpty ? "" : "_\(dataManager.userName)"
                ShareSheet(pdfData: pdfData, fileName: "TaxSummary\(name)_\(dataManager.currentYear).pdf")
            }
        }
        #endif
        .onAppear {
            manager.attach(dataManager: dataManager, scenarioStateManager: dataManager.scenario)
            if let saved = dataManager.multiYearAssumptions {
                manager.assumptions = saved
            }
            if selectedYear == nil {
                selectedYear = manager.currentResult?.recommendedPath.first?.year
            }
            if !manager.hasEverComputed {
                manager.recompute(reason: .appLaunch)
            }
        }
    }

    private var wideLayout: some View {
        VStack(spacing: 0) {
            AssumptionsPillBar(manager: manager)
            HStack(spacing: 0) {
                MacroStrategyPane(manager: manager, selectedYear: $selectedYear)
                    .frame(maxWidth: .infinity)

                Divider()

                yearDetailContent
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 0) {
            AssumptionsPillBar(manager: manager)
            MacroStrategyPane(manager: manager, selectedYear: $selectedYear)
        }
        .sheet(isPresented: .constant(manager.assumptions.assumptionsConfirmed)) {
            TaxPlanningBottomSheet(
                manager: manager,
                selectedYear: selectedYear,
                detent: $sheetDetent
            )
            .environmentObject(dataManager)
            .presentationDetents(
                [.fraction(0.15), .medium, .large],
                selection: $sheetDetent
            )
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .interactiveDismissDisabled(true)
        }
        .onChange(of: selectedYear) { _, newYear in
            guard let newYear else { return }
            sheetDetent = (newYear == dataManager.currentYear) ? .medium : .fraction(0.15)
        }
    }

    @ViewBuilder
    private var yearDetailContent: some View {
        if let year = selectedYear,
           let result = manager.currentResult,
           let yearRec = result.recommendedPath.first(where: { $0.year == year }) {
            if yearRec.year == dataManager.currentYear {
                ScrollView {
                    VStack(spacing: 12) {
                        ActionItemsBanner(
                            year: dataManager.currentYear,
                            rothAmount: dataManager.scenarioTotalRothConversion,
                            qcdAmount: dataManager.scenarioTotalQCD,
                            stockDonationAmount: dataManager.stockDonationEnabled ? dataManager.stockCurrentValue : 0,
                            requiredRMDAmount: dataManager.scenarioCombinedRMD,
                            onViewAll: { showActionItemsSheet = true }
                        )
                        Year1QuickEditor(manager: manager)
                            .environmentObject(dataManager)
                        taxPositionPanel
                    }
                    .padding(14)
                }
                .background(Color(PlatformColor.secondarySystemGroupedBackground))
                .sheet(isPresented: $showActionItemsSheet) {
                    ActionItemsSheet(
                        year: dataManager.currentYear,
                        rothAmount: dataManager.scenarioTotalRothConversion,
                        qcdAmount: dataManager.scenarioTotalQCD,
                        stockDonationAmount: dataManager.stockDonationEnabled ? dataManager.stockCurrentValue : 0,
                        requiredRMDAmount: dataManager.scenarioCombinedRMD
                    )
                }
            } else {
                let priorIdx = result.recommendedPath.firstIndex(where: { $0.year == year }) ?? 0
                let priorRec: YearRecommendation? = priorIdx > 0 ? result.recommendedPath[priorIdx - 1] : nil
                let hit = result.tradeOffsAccepted.first(where: { $0.year == year })
                YearProjectionCard(
                    recommendation: yearRec,
                    priorRecommendation: priorRec,
                    constraintHit: hit,
                    priorBalances: priorRec?.endOfYearBalances
                )
            }
        } else if manager.isComputing {
            ProgressView("Computing strategy…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(PlatformColor.secondarySystemGroupedBackground))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text("Select a year")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Tap any bar in the waterfall chart\nto see that year's detail.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(PlatformColor.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Export

    private func triggerExport() {
        guard !isGeneratingPDF else { return }
        isGeneratingPDF = true
        let snapshot = PDFExportData(from: dataManager)
        Task {
            let data = await PDFExportService.generatePDF(from: snapshot)
            await MainActor.run {
                exportPDFData = data
                isGeneratingPDF = false
                #if canImport(UIKit)
                showExportSheet = true
                #elseif canImport(AppKit)
                let name = dataManager.userName.isEmpty ? "" : "_\(dataManager.userName)"
                MacPDFExporter.save(pdfData: data, fileName: "TaxSummary\(name)_\(dataManager.currentYear).pdf")
                #endif
            }
        }
    }

    // MARK: - Tax Position Panel (Year 1 right pane)

    private var taxPositionPanel: some View {
        let fs = dataManager.filingStatus
        let income = dataManager.scenarioTaxableIncome
        let fedBracket = dataManager.federalBracketInfo(income: income, filingStatus: fs)
        let fedBracketTuples: [(rate: Double, threshold: Double)] = {
            let brackets = fs == .single
                ? dataManager.currentTaxBrackets.federalSingle
                : dataManager.currentTaxBrackets.federalMarried
            return brackets.map { (rate: $0.rate, threshold: $0.threshold) }
        }()
        let irmaa = dataManager.scenarioIRMAA
        let cushionToNextK: Int? = {
            guard let dist = irmaa.distanceToNextTier, dist > 0 else { return nil }
            return Int(dist / 1000)
        }()
        let stateRate = dataManager.stateMarginalRate(income: income, filingStatus: fs)
        let niit = dataManager.scenarioNIITAmount

        return TaxPositionPanel(
            federalRate: fedBracket.currentRate,
            federalIncome: income,
            federalBrackets: fedBracketTuples,
            federalRoomToNext: fedBracket.roomRemaining,
            irmaaTier: irmaa.tier,
            irmaaCushionToNextK: cushionToNextK,
            stateRatePercent: stateRate * 100,
            stateLabel: dataManager.selectedState.abbreviation,
            niitAnnualDollars: niit
        )
    }
}
