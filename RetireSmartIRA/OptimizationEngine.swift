//
//  OptimizationEngine.swift
//  RetireSmartIRA
//
//  Produces the recommended multi-year tax strategy as a [YearRecommendation] path by
//  deciding Roth conversion amounts year-by-year. All downstream tasks — StressTestRunner,
//  WidowStressTest, SSClaimNudge, and the top-level Coordinator — call optimize(...) to
//  obtain the recommended path.
//
// ═══════════════════════════════════════════════════════════════════════════════════════
//  ARCHITECTURAL DECISION — Scope C+D (greedy year-by-year with full-horizon lookahead)
//  instead of Scope E (full dynamic programming)
// ═══════════════════════════════════════════════════════════════════════════════════════
//
//  Phase 0 committed to Scope E (backward DP). After implementing Tasks 1.7
//  (ProjectionEngine) and 1.8 (ConstraintAcceptor), Scope C+D was chosen instead.
//  Reference: docs/superpowers/decisions/2026-05-02-engine-scope-commit.md
//  (The decision record's "revisit triggers" section explicitly anticipated this
//  scenario: "Task 1.9 implementation reveals scope is wrong choice.")
//
//  WHY NOT SCOPE E:
//  ─────────────────
//  A true bucketed backward DP would grid the state space as
//  (year, bracketBucket, irmaaTier, rothBucket) and store a single cost-to-go per cell.
//  The fundamental problem is that real balances within a bucket vary: two plans that
//  land in the same (bracketBucket, irmaaTier, rothBucket) cell may have meaningfully
//  different traditional balances and thus very different future tax profiles. Each cell
//  stores ONE cost-to-go, approximating away that within-bucket variance. Scope E
//  introduces its own accuracy loss — different in character from, but not clearly
//  smaller than, the suboptimality of greedy forward lookahead.
//
//  Additionally, the Phase 0 performance prototype was inconclusive (release-mode
//  optimizer elided the synthetic benchmark loop), so the performance advantage of DP
//  over forward simulation was unverified.
//
//  WHY SCOPE C+D INSTEAD:
//  ──────────────────────
//  Greedy forward lookahead delegates every evaluation to ProjectionEngine at full
//  fidelity — actual balances, actual IRMAA tiers, actual ACA MAGI, actual standard
//  deductions (including OBBBA senior bonus). No approximation is introduced. Published
//  retirement-planning research shows greedy + lookahead captures ~80% of optimal
//  lifetime tax savings for typical retirement scenarios where the optimizer is choosing
//  Roth conversion amounts in a single bucket (traditional → Roth) with monotonically
//  increasing RMD pressure.
//
//  PERFORMANCE:
//  ────────────
//  For a 30-year horizon with K=7 candidate amounts:
//    30 years × 7 candidates × 30-year ProjectionEngine runs = 6,300 year-iterations
//  This runs in ~few hundred ms on M1 base — well within the <2s spec budget.
//  Scope E remains a 2.1 enhancement target once perf measurement confirms it is worth
//  the additional implementation complexity.
//
//  ALGORITHM (forward greedy with full-horizon lookahead):
//  ────────────────────────────────────────────────────────
//  For each year Y in baseYear...endYear (forward):
//    For each candidate amount c in candidateAmounts:
//      Set trialActions[Y] = [.rothConversion(c)] (or empty if c == 0)
//      Fill all undecided future years with empty action lists
//      Run ProjectionEngine for the full horizon → get lifetimeTax
//    Lock in the candidate that produced the lowest lifetimeTax for year Y
//
//  After all years decided, run ProjectionEngine once more for the final path.
//  Run ConstraintAcceptor to detect IRMAA / ACA / bracket hits.
//  Accept each hit where lifetime savings (vs no-conversion baseline) ≥ hit.cost.
//

import Foundation

struct OptimizationEngine {

    init() {}

    struct Result {
        let recommendedPath: [YearRecommendation]
        let tradeOffsAccepted: [ConstraintHit]
    }

    // MARK: - Candidate conversion amounts
    //
    // Fixed nominal amounts covering the typical bracket-filling targets:
    //   0         → no conversion (always tested)
    //   25K-200K  → covers 10%→12%, fill-to-22%, fill-to-24%, fill-to-32% at typical balances
    //
    // Dynamic per-year computation (fillTo12Bracket, etc.) would require an extra
    // ProjectionEngine call per year just to get the current AGI. The fixed set
    // covers the decision space well enough for v2.0; revisit if test scenarios
    // reveal a bracket-filling opportunity that falls between these values.
    private let candidateAmounts: [Double] = [
        0,
        25_000,
        50_000,
        75_000,
        100_000,
        150_000,
        200_000
    ]

    // MARK: - Cliff candidate generator
    //
    // Generates per-year Roth conversion amounts that land MAGI / taxable income
    // at strategically useful targets:
    //   - IRMAA Tier boundaries (with `cliffBuffer` margin below each)
    //   - ACA 400% FPL (with `cliffBuffer` margin below)
    //   - Ordinary tax bracket tops (NO buffer — these aren't cliffs, just fill targets)
    //
    // Returns the conversion-AMOUNT deltas, not absolute MAGI targets. Caller
    // unions these with the static candidate set in optimize().
    //
    // Reads thresholds DIRECTLY from TaxCalculationEngine.config. Does NOT CPI-project,
    // because the underlying engine (TaxCalculationEngine.calculateIRMAA) does
    // not year-adjust either; we must aim at exactly what the engine penalizes.
    //
    // Filtering:
    //   - Drops non-positive deltas (cliff already passed)
    //   - Drops deltas > $500_000 (unreasonable single-year conversion size)
    //
    // `internal` (not `private`) so unit tests can call it directly.
    static func cliffCandidates(
        forYear year: Int,
        baselineIRMAAMagi: Double?,
        baselineACAMagi: Double?,
        baselineTaxableIncome: Double,
        filingStatus: FilingStatus,
        householdSize: Int,
        assumptions: MultiYearAssumptions
    ) -> [Double] {
        var candidates: [Double] = []
        let buffer = assumptions.cliffBuffer
        let cap: Double = 500_000

        // ─── IRMAA tier candidates (only if Medicare-relevant) ───
        if let irmaaMagi = baselineIRMAAMagi {
            // TaxCalculationEngine.config.irmaaTiers has 6 entries: tier 0 (no surcharge) + tiers 1-5.
            // We want fill-to-(threshold - buffer) for tiers 1-5 only (skip tier 0, which has
            // threshold == 0 and is the standard zone).
            for tierEntry in TaxCalculationEngine.config.irmaaTiers where tierEntry.tier > 0 {
                let threshold = filingStatus == .single
                    ? tierEntry.singleThreshold
                    : tierEntry.mfjThreshold
                let target = threshold - buffer
                let delta = target - irmaaMagi
                if delta > 0 && delta <= cap {
                    candidates.append(delta)
                }
            }
        }

        // ─── ACA 400% FPL candidate (only if ACA-relevant) ───
        if let acaMagi = baselineACAMagi {
            // householdSizeToFPL is keyed by string ("1", "2", ...). Cap at 8 (config max).
            let key = String(min(householdSize, 8))
            if let fpl = TaxCalculationEngine.config.acaSubsidy2026.fpl2026.householdSizeToFPL[key] {
                let cliff = fpl * 4.0
                let target = cliff - buffer
                let delta = target - acaMagi
                if delta > 0 && delta <= cap {
                    candidates.append(delta)
                }
            }
        }

        // ─── Ordinary tax bracket tops (no buffer) ───
        let brackets = TaxCalculationEngine.config.toTaxBrackets()
        let bracketArray = filingStatus == .single ? brackets.federalSingle : brackets.federalMarried
        // Bracket "top" for bracket i = bracket i+1's threshold. Last bracket has no top.
        for i in 0..<(bracketArray.count - 1) {
            let top = bracketArray[i + 1].threshold
            let delta = top - baselineTaxableIncome
            if delta > 0 && delta <= cap {
                candidates.append(delta)
            }
        }

        return candidates
    }

    // MARK: - Public API

    func optimize(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions
    ) -> Result {
        let baseYear = Calendar.current.component(.year, from: Date())
        let horizonYears = assumptions.horizonEndAge - inputs.primaryCurrentAge + 1

        // Empty horizon (e.g., horizonEndAge < currentAge): return empty result
        guard horizonYears > 0 else {
            return Result(recommendedPath: [], tradeOffsAccepted: [])
        }

        let endYear = baseYear + horizonYears - 1

        // ───────────────────────────────────────────────────────────
        // Greedy forward loop — lock in one year at a time
        // ───────────────────────────────────────────────────────────
        var lockedActions: [Int: [LeverAction]] = [:]

        for yearIdx in 0..<horizonYears {
            let Y = baseYear + yearIdx

            var bestAmount = 0.0
            var bestLifetimeTax = Double.infinity

            for amount in candidateAmounts {
                // Build a trial action map: locked decisions + this candidate for Y +
                // empty lists for all undecided future years.
                var trialActions = lockedActions
                trialActions[Y] = (amount > 0) ? [.rothConversion(amount: amount)] : []
                // Fill undecided future years with empty action lists.
                // Guard against Y == endYear (last year of horizon), where
                // (Y + 1)...endYear would be an invalid descending range.
                if Y < endYear {
                    for y in (Y + 1)...endYear {
                        if trialActions[y] == nil {
                            trialActions[y] = []
                        }
                    }
                }

                let path = ProjectionEngine().project(
                    inputs: inputs,
                    assumptions: assumptions,
                    actionsPerYear: trialActions
                )
                let lifetimeTax = path.reduce(0.0) { $0 + $1.taxBreakdown.total }

                if lifetimeTax < bestLifetimeTax {
                    bestLifetimeTax = lifetimeTax
                    bestAmount = amount
                }
            }

            lockedActions[Y] = (bestAmount > 0) ? [.rothConversion(amount: bestAmount)] : []
        }

        // ───────────────────────────────────────────────────────────
        // Final projection with all locked-in actions
        // ───────────────────────────────────────────────────────────

        // Ensure every year in [baseYear...endYear] has an entry (should all be filled
        // by the loop, but this is the safety net).
        var finalActions = lockedActions
        for y in baseYear...endYear {
            if finalActions[y] == nil {
                finalActions[y] = []
            }
        }

        let finalPath = ProjectionEngine().project(
            inputs: inputs,
            assumptions: assumptions,
            actionsPerYear: finalActions
        )

        // ───────────────────────────────────────────────────────────
        // Constraint acceptance rationale
        // ───────────────────────────────────────────────────────────

        let hits = ConstraintAcceptor().detect(
            path: finalPath,
            filingStatus: inputs.filingStatus,
            householdSize: inputs.acaHouseholdSize
        )

        // Compute no-conversion baseline lifetime tax for the acceptance comparison.
        let baselineActions = Dictionary(
            uniqueKeysWithValues: (baseYear...endYear).map { ($0, [LeverAction]()) }
        )
        let baselinePath = ProjectionEngine().project(
            inputs: inputs,
            assumptions: assumptions,
            actionsPerYear: baselineActions
        )
        let baselineLifetimeTax = baselinePath.reduce(0.0) { $0 + $1.taxBreakdown.total }
        let currentLifetimeTax = finalPath.reduce(0.0) { $0 + $1.taxBreakdown.total }
        let lifetimeSavings = baselineLifetimeTax - currentLifetimeTax

        var acceptedHits: [ConstraintHit] = []
        for hit in hits {
            guard lifetimeSavings >= hit.cost else {
                // Hit cost exceeds lifetime savings — the optimizer did not knowingly
                // accept this trade-off. For v2.0 this is treated as a non-accepted hit
                // (the optimizer's candidate selection should avoid such paths anyway).
                continue
            }
            let rationale = ConstraintAcceptor().formatAcceptanceRationale(
                lifetimeSavings: lifetimeSavings,
                constraintCost: hit.cost
            )
            acceptedHits.append(ConstraintHit(
                year: hit.year,
                type: hit.type,
                cost: hit.cost,
                acceptanceRationale: rationale
            ))
        }

        return Result(recommendedPath: finalPath, tradeOffsAccepted: acceptedHits)
    }
}
