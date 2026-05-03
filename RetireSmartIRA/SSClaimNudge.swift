//
//  SSClaimNudge.swift
//  RetireSmartIRA
//
//  Identifies whether shifting either spouse's Social Security claim age by ±1 or ±2 years
//  would produce a lifetime tax savings greater than $5,000. If so, returns a ClaimAgeFlag
//  for the highest-impact perturbation found.
//
//  Perturbations tested: [-2, -1, +1, +2] years (skipped if out of SSA allowed range 62-70).
//
//  Algorithm (static-ladder, post-Gemini-review 2026-05-03):
//    1. Acquire baseline path and objective cost (from injected params or by running optimize())
//    2. Extract the baseline's locked Roth conversion actions (keyed by year)
//    3. For each ±1, ±2 perturbation of each spouse's SS claim age:
//       a. Project the SAME Roth ladder (no re-optimization) with the shifted SS age,
//          using ProjectionEngine.project() directly
//       b. Compute objective cost via OptimizationEngine.computeObjectiveCost
//          (in-horizon tax + terminal liquidation tax — consistent with optimizer ranking)
//       c. Compare to baseline objective; flag if savings > $5K
//
//  Why static-ladder: the previous implementation called optimize() 9 times
//  (1 + 4 + 4), which under the new fixed-point optimizer takes 13-24s of
//  blocking compute. The static-ladder approach answers the user-facing question
//  "if I shift my SS claim age but keep my Roth strategy, what's the savings?"
//  in ~10ms. Power users wanting "if I shift SS AND re-optimize Roth" can
//  re-run the full engine with the new SS age.
//
//  KNOWN LIMITATION (per Task 1.7 review): MFJ scenarios use effectiveMonthlyBenefitSingle
//  for each spouse independently, NOT the couples-aware effectiveMonthlyBenefit which models
//  spousal-top-up. For couples with very asymmetric PIAs, this nudge under-counts the value
//  of delaying the higher earner. Acceptable for v2.0; revisit when ProjectionEngine adopts
//  couples-aware SS calculation.
//
//  Performance optimization: accepts optional baselinePath and baselineObjective parameters.
//  When both are provided (injected by MultiYearTaxStrategyEngine), the internal baseline
//  optimize() call is skipped entirely (0 optimize() calls for SSClaimNudge at coordinator
//  level). When either is nil, the baseline is computed internally (preserves existing
//  behavior for standalone callers / unit tests).
//

import Foundation

struct SSClaimNudge {

    static let savingsThreshold = 5_000.0
    static let claimAgeMin = 62
    static let claimAgeMax = 70
    static let perturbations = [-2, -1, 1, 2]

    init() {}

    func compute(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions,
        baselinePath: [YearRecommendation]? = nil,
        baselineObjective: Double? = nil
    ) -> ClaimAgeFlag? {
        let engine = OptimizationEngine()
        let projector = ProjectionEngine()

        // Baseline: use injected path/objective when both provided; otherwise compute.
        let baselineRecommendedPath: [YearRecommendation]
        let baselineObj: Double
        if let injectedPath = baselinePath, let injectedObj = baselineObjective {
            baselineRecommendedPath = injectedPath
            baselineObj = injectedObj
        } else {
            let baseline = engine.optimize(inputs: inputs, assumptions: assumptions)
            baselineRecommendedPath = baseline.recommendedPath
            baselineObj = baseline.totalObjectiveCost
        }

        // Extract baseline's locked Roth conversion actions, keyed by year
        var baselineActions: [Int: [LeverAction]] = [:]
        for yearRec in baselineRecommendedPath {
            baselineActions[yearRec.year] = yearRec.actions.filter {
                if case .rothConversion = $0 { return true }
                return false
            }
        }

        var bestFlag: ClaimAgeFlag? = nil
        var bestSavings = 0.0

        // Test primary perturbations (using static-ladder, not re-optimization)
        for delta in Self.perturbations {
            let candidateAge = inputs.primarySSClaimAge + delta
            guard candidateAge >= Self.claimAgeMin && candidateAge <= Self.claimAgeMax else { continue }

            let candidateInputs = inputs.withClaimAge(candidateAge, for: .primary)
            let candidatePath = projector.project(
                inputs: candidateInputs, assumptions: assumptions, actionsPerYear: baselineActions
            )
            let candidateObjective = OptimizationEngine.computeObjectiveCost(
                path: candidatePath, terminalLiquidationTaxRate: assumptions.terminalLiquidationTaxRate
            )
            let savings = baselineObj - candidateObjective  // positive = savings

            if savings > Self.savingsThreshold && savings > bestSavings {
                bestSavings = savings
                bestFlag = ClaimAgeFlag(
                    spouse: .primary,
                    currentClaimAge: inputs.primarySSClaimAge,
                    suggestedClaimAge: candidateAge,
                    estimatedLifetimeTaxDelta: -savings  // negative = savings (per spec)
                )
            }
        }

        // Test spouse perturbations (only if there is a spouse)
        if let spouseClaimAge = inputs.spouseSSClaimAge {
            for delta in Self.perturbations {
                let candidateAge = spouseClaimAge + delta
                guard candidateAge >= Self.claimAgeMin && candidateAge <= Self.claimAgeMax else { continue }

                let candidateInputs = inputs.withClaimAge(candidateAge, for: .spouse)
                let candidatePath = projector.project(
                    inputs: candidateInputs, assumptions: assumptions, actionsPerYear: baselineActions
                )
                let candidateObjective = OptimizationEngine.computeObjectiveCost(
                    path: candidatePath, terminalLiquidationTaxRate: assumptions.terminalLiquidationTaxRate
                )
                let savings = baselineObj - candidateObjective

                if savings > Self.savingsThreshold && savings > bestSavings {
                    bestSavings = savings
                    bestFlag = ClaimAgeFlag(
                        spouse: .spouse,
                        currentClaimAge: spouseClaimAge,
                        suggestedClaimAge: candidateAge,
                        estimatedLifetimeTaxDelta: -savings
                    )
                }
            }
        }

        return bestFlag
    }
}
