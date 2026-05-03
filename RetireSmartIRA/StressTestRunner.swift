//
//  StressTestRunner.swift
//  RetireSmartIRA
//
//  Runs OptimizationEngine at three growth rates (average, pessimistic = avg-2pp,
//  optimistic = avg+2pp) and returns the three [YearRecommendation] paths as
//  SensitivityBands.
//
//  Pessimistic growth is clamped to 0% to prevent negative compounding (which is
//  not a meaningful retirement-planning scenario).
//
//  Performance optimization: accepts an optional baselinePath parameter. When provided
//  (injected by MultiYearTaxStrategyEngine), the "average" band reuses the already-computed
//  baseline path and skips an extra optimize() call. When nil, the average band is computed
//  internally (preserves existing behavior for standalone callers / unit tests).
//

import Foundation

struct StressTestRunner {

    init() {}

    func run(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions,
        baselinePath: [YearRecommendation]? = nil
    ) -> SensitivityBands {
        let engine = OptimizationEngine()

        var pessimistic = assumptions
        pessimistic.investmentGrowthRate = max(0, assumptions.investmentGrowthRate - 0.02)

        var optimistic = assumptions
        optimistic.investmentGrowthRate = assumptions.investmentGrowthRate + 0.02

        // Use injected baseline path for the "average" band when provided;
        // otherwise compute it (preserves old behavior for existing callers / tests).
        let averagePath = baselinePath
            ?? engine.optimize(inputs: inputs, assumptions: assumptions).recommendedPath

        return SensitivityBands(
            optimistic: engine.optimize(inputs: inputs, assumptions: optimistic).recommendedPath,
            average: averagePath,
            pessimistic: engine.optimize(inputs: inputs, assumptions: pessimistic).recommendedPath
        )
    }
}
