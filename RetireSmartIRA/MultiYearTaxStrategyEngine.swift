//
//  MultiYearTaxStrategyEngine.swift
//  RetireSmartIRA
//
//  Top-level coordinator for the Multi-Year Tax Strategy engine.
//
//  Wires together the four engine pieces and returns a fully-populated
//  MultiYearStrategyResult:
//
//    1. OptimizationEngine    → recommendedPath + tradeOffsAccepted
//    2. StressTestRunner      → sensitivityBands (±2pp growth, only if stressTestEnabled)
//    3. WidowStressTest       → widowStressDelta (always)
//    4. SSClaimNudge          → ssClaimNudge (always)
//
//  When stressTestEnabled = false, optimistic and pessimistic bands mirror the
//  average (no perturbed OptimizationEngine runs).
//
//  Performance budget: ~few hundred ms for typical 30-year horizon on M1 base.
//  Total optimize() calls per compute() (with dependency-injected baseline):
//    - 1× main optimization (the single source of truth for the baseline)
//    - 2× StressTestRunner (optimistic + pessimistic; average reuses main baseline)
//    - 1× WidowStressTest (widow variant only; baseline injected from main)
//    - 0× SSClaimNudge (static-ladder; baseline injected from main)
//  Total: 4 optimize() calls (down from 6-10 pre-injection).
//

import Foundation

struct MultiYearTaxStrategyEngine {

    init() {}

    func compute(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions
    ) -> MultiYearStrategyResult {

        // Main optimization (the single source of truth for the baseline)
        let optEngine = OptimizationEngine()
        let optResult = optEngine.optimize(inputs: inputs, assumptions: assumptions)

        // Sensitivity bands — pass baseline path through to skip the redundant "average" run
        let bands: SensitivityBands
        if assumptions.stressTestEnabled {
            bands = StressTestRunner().run(
                inputs: inputs,
                assumptions: assumptions,
                baselinePath: optResult.recommendedPath
            )
        } else {
            // Disabled: optimistic and pessimistic mirror the recommended path
            bands = SensitivityBands(
                optimistic: optResult.recommendedPath,
                average: optResult.recommendedPath,
                pessimistic: optResult.recommendedPath
            )
        }

        // Widow stress test — pass baseline through to skip the redundant baseline run
        let widowImpact = WidowStressTest().run(
            inputs: inputs,
            assumptions: assumptions,
            baselinePath: optResult.recommendedPath,
            baselineObjective: optResult.totalObjectiveCost
        )

        // SS claim-age nudge — pass baseline through to skip the redundant baseline run
        let ssFlag = SSClaimNudge().compute(
            inputs: inputs,
            assumptions: assumptions,
            baselinePath: optResult.recommendedPath,
            baselineObjective: optResult.totalObjectiveCost
        )

        return MultiYearStrategyResult(
            recommendedPath: optResult.recommendedPath,
            tradeOffsAccepted: optResult.tradeOffsAccepted,
            sensitivityBands: bands,
            widowStressDelta: widowImpact,
            ssClaimNudge: ssFlag
        )
    }
}
