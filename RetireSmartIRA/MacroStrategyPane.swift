//
//  MacroStrategyPane.swift
//  RetireSmartIRA
//

import SwiftUI

struct MacroStrategyPane: View {
    @ObservedObject var manager: MultiYearStrategyManager
    @Binding var selectedYear: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let result = manager.currentResult,
                   let optimal = manager.engineOptimalResult {
                    HeroStatView(
                        baselineLifetimeTax: baselineLifetimeTax(optimal: optimal),
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
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 400)
                }
            }
            .padding(14)
        }
    }

    private func baselineLifetimeTax(optimal: MultiYearStrategyResult) -> Double {
        // Placeholder: 1.5x optimal as stand-in for a "do-nothing" baseline.
        // Replace with real do-nothing baseline computation in Phase 11.
        optimal.lifetimeTaxFromRecommendedPath * 1.5
    }
}
