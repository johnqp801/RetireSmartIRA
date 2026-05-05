//
//  MacroStrategyPane.swift
//  RetireSmartIRA
//

import SwiftUI

struct MacroStrategyPane: View {
    @ObservedObject var manager: MultiYearStrategyManager
    @Binding var selectedYear: Int?
    @State private var computeError: Error? = nil
    @AppStorage("lockedOverlayDismissed") private var overlayDismissed = false
    @State private var showOnboardingSheet = false

    private var isLocked: Bool {
        !manager.assumptions.assumptionsConfirmed
    }

    var body: some View {
        ZStack {
            ScrollView {
            VStack(spacing: 12) {
                CalloutBannersHost(manager: manager)

                if let result = manager.currentResult,
                   let optimal = manager.engineOptimalResult {
                    HeroStatView(
                        recommendedLifetimeTax: optimal.lifetimeTaxFromRecommendedPath,
                        heirTaxRatePercent: Int(manager.assumptions.terminalLiquidationTaxRate * 100),
                        offPlanState: OffPlanIndicator.PlanState.fromDelta(
                            result.lifetimeTaxFromRecommendedPath - optimal.lifetimeTaxFromRecommendedPath
                        ),
                        useNeutralOffPlanFraming: !manager.firstOffPlanShown,
                        onReset: {
                            manager.markFirstOffPlanShown()
                            manager.resetYear1ToEngineOptimal()
                        }
                    )

                    StrategySummaryCard(
                        summaryText: StrategySummarySynthesizer.synthesize(
                            path: result.recommendedPath,
                            tradeOffs: result.tradeOffsAccepted
                        )
                    )

                    WaterfallChartView(
                        path: result.recommendedPath,
                        sensitivityBands: manager.assumptions.stressTestEnabled ? result.sensitivityBands : nil,
                        selectedYear: selectedYear,
                        onYearTap: { selectedYear = $0 }
                    )

                    SparklineRow(path: result.recommendedPath)

                    TradeOffsAcceptedCard(tradeOffs: result.tradeOffsAccepted)

                    YearListView(
                        path: result.recommendedPath,
                        tradeOffs: result.tradeOffsAccepted,
                        selectedYear: $selectedYear
                    )
                } else if !manager.hasEverComputed {
                    MacroPaneSkeleton()
                } else if computeError != nil {
                    errorView
                } else {
                    MacroPaneSkeleton()
                }
            }
            .padding(14)
            .macroStaleStateOverlay(isComputing: manager.isComputing)
            }
            .blur(radius: isLocked ? 12 : 0)
            .allowsHitTesting(!isLocked)

            if isLocked {
                if !overlayDismissed {
                    LockedMacroOverlay(
                        onSetUp: { showOnboardingSheet = true },
                        onDismiss: { overlayDismissed = true }
                    )
                } else {
                    VStack {
                        LockedMacroSlimBanner(onSetUp: { showOnboardingSheet = true })
                        Spacer()
                    }
                }
            }
        }
        .sheet(isPresented: $showOnboardingSheet) {
            OnboardingAssumptionsSheet(manager: manager)
        }
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Strategy couldn't be computed")
                .font(.headline)
            Text("Some inputs may be missing or invalid.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Retry") {
                manager.recompute(reason: .appLaunch)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 400)
    }

}
