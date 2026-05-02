//
//  SSClaimNudge.swift
//  RetireSmartIRA
//
//  Identifies whether shifting either spouse's Social Security claim age by ±1 or ±2 years
//  would produce a lifetime tax savings greater than $5,000. If so, returns a ClaimAgeFlag
//  for the highest-impact perturbation found.
//
//  Perturbations tested: [-2, -1, +1, +2] years (skipped if out of SSA allowed range 62-70).
//  Baseline is recomputed once; each perturbation gets its own OptimizationEngine call.
//
//  KNOWN LIMITATION (per Task 1.7 review): MFJ scenarios use effectiveMonthlyBenefitSingle
//  for each spouse independently, NOT the couples-aware effectiveMonthlyBenefit which models
//  spousal-top-up. For couples with very asymmetric PIAs, this nudge under-counts the value
//  of delaying the higher earner. Acceptable for v2.0; revisit when ProjectionEngine adopts
//  couples-aware SS calculation.
//

import Foundation

struct SSClaimNudge {

    static let savingsThreshold = 5_000.0
    static let claimAgeMin = 62
    static let claimAgeMax = 70
    static let perturbations = [-2, -1, 1, 2]

    init() {}

    func compute(inputs: MultiYearStaticInputs, assumptions: MultiYearAssumptions) -> ClaimAgeFlag? {
        let engine = OptimizationEngine()

        let baseline = engine.optimize(inputs: inputs, assumptions: assumptions)
        let baselineLifetimeTax = baseline.recommendedPath.reduce(0.0) { $0 + $1.taxBreakdown.total }

        var bestFlag: ClaimAgeFlag? = nil
        var bestSavings = 0.0

        // Test primary perturbations
        for delta in Self.perturbations {
            let candidateAge = inputs.primarySSClaimAge + delta
            guard candidateAge >= Self.claimAgeMin && candidateAge <= Self.claimAgeMax else { continue }

            let candidateInputs = inputs.withClaimAge(candidateAge, for: .primary)
            let candidate = engine.optimize(inputs: candidateInputs, assumptions: assumptions)
            let candidateLifetimeTax = candidate.recommendedPath.reduce(0.0) { $0 + $1.taxBreakdown.total }
            let savings = baselineLifetimeTax - candidateLifetimeTax  // positive = savings

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
                let candidate = engine.optimize(inputs: candidateInputs, assumptions: assumptions)
                let candidateLifetimeTax = candidate.recommendedPath.reduce(0.0) { $0 + $1.taxBreakdown.total }
                let savings = baselineLifetimeTax - candidateLifetimeTax

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
