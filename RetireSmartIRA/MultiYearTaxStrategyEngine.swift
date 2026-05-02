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
//  Total dispatch per compute():
//    - 1× OptimizationEngine for main path
//    - 3× OptimizationEngine via StressTestRunner (when enabled)
//    - 2× OptimizationEngine via WidowStressTest (baseline + widow variant)
//    - N× OptimizationEngine via SSClaimNudge (1 baseline + 4 perturbations × 1-2 spouses)
//  Total: 6-10 optimize() calls. At ~few hundred ms each = well under <5s budget.
//

import Foundation

struct MultiYearTaxStrategyEngine {

    init() {}

    func compute(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions
    ) -> MultiYearStrategyResult {

        // Main optimization
        let optEngine = OptimizationEngine()
        let optResult = optEngine.optimize(inputs: inputs, assumptions: assumptions)

        // Sensitivity bands (only if enabled)
        let bands: SensitivityBands
        if assumptions.stressTestEnabled {
            bands = StressTestRunner().run(inputs: inputs, assumptions: assumptions)
        } else {
            // Disabled: optimistic and pessimistic mirror the recommended path
            bands = SensitivityBands(
                optimistic: optResult.recommendedPath,
                average: optResult.recommendedPath,
                pessimistic: optResult.recommendedPath
            )
        }

        // Widow stress test (always runs; separate concern per spec)
        let widowImpact = WidowStressTest().run(inputs: inputs, assumptions: assumptions)

        // SS claim-age nudge
        let ssFlag = SSClaimNudge().compute(inputs: inputs, assumptions: assumptions)

        return MultiYearStrategyResult(
            recommendedPath: optResult.recommendedPath,
            tradeOffsAccepted: optResult.tradeOffsAccepted,
            sensitivityBands: bands,
            widowStressDelta: widowImpact,
            ssClaimNudge: ssFlag
        )
    }
}
