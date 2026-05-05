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
    @EnvironmentObject var scenarioStateManager: ScenarioStateManager
    @StateObject private var manager = MultiYearStrategyManager()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.availableWidth) private var availableWidth

    @State private var selectedYear: Int? = nil
    @State private var sheetDetent: PresentationDetent = .medium

    private var isWideLayout: Bool {
        horizontalSizeClass == .regular && availableWidth > 900
    }

    var body: some View {
        Group {
            if isWideLayout {
                wideLayout
            } else {
                compactLayout
            }
        }
        .onAppear {
            manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)
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
                        Year1QuickEditor(manager: manager)
                            .environmentObject(dataManager)
                        ScenarioBuilderView()
                            .environmentObject(dataManager)
                        DashboardView()
                            .environmentObject(dataManager)
                    }
                    .padding(14)
                }
                .background(Color(.secondarySystemGroupedBackground))
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
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
        }
    }
}
