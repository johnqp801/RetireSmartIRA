//
//  StressTestRunner.swift
//  RetireSmartIRA
//
//  Runs OptimizationEngine 3× at three growth rates (average, pessimistic = avg-2pp,
//  optimistic = avg+2pp) and returns the three [YearRecommendation] paths as
//  SensitivityBands.
//
//  Pessimistic growth is clamped to 0% to prevent negative compounding (which is
//  not a meaningful retirement-planning scenario).
//

import Foundation

struct StressTestRunner {

    init() {}

    func run(inputs: MultiYearStaticInputs, assumptions: MultiYearAssumptions) -> SensitivityBands {
        let engine = OptimizationEngine()

        var pessimistic = assumptions
        pessimistic.investmentGrowthRate = max(0, assumptions.investmentGrowthRate - 0.02)

        var optimistic = assumptions
        optimistic.investmentGrowthRate = assumptions.investmentGrowthRate + 0.02

        return SensitivityBands(
            optimistic: engine.optimize(inputs: inputs, assumptions: optimistic).recommendedPath,
            average: engine.optimize(inputs: inputs, assumptions: assumptions).recommendedPath,
            pessimistic: engine.optimize(inputs: inputs, assumptions: pessimistic).recommendedPath
        )
    }
}
