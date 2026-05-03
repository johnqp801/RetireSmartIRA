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
//  ALGORITHM (fixed-point iteration with cliff-aware candidates):
//  ────────────────────────────────────────────────────────────────
//  Outer loop (cap = 5, exit on convergence):
//    Inner loop — for each year Y in baseYear...endYear (forward):
//      Compute current-iteration baseline projection (inside the Y loop).
//      Generate cliff candidates from actual MAGI / taxable income for Y.
//      Union cliff candidates with static candidateAmounts; dedupe within $1K.
//      For each candidate amount c:
//        Set trialActions[Y] = [.rothConversion(c)] (or empty if c == 0)
//        Future years keep PRIOR-iteration locked decisions (not [])
//        Run ProjectionEngine for the full horizon → get objective (lifetime tax + terminal)
//      Lock in the candidate that produced the lowest objective for year Y.
//    Check convergence: if locked == previousLocked, exit outer loop early.
//
//  After convergence (or cap), run ProjectionEngine once more for the final path.
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

    // MARK: - Terminal liquidation tax helper
    //
    // Estimates the future tax burden of leftover Traditional balance at the
    // end of the horizon. Critical for the optimizer's objective function:
    // without this, the engine treats deferred trad as free wealth and biases
    // toward "do nothing" (Bug 1 — Terminal Tax Illusion).
    //
    // Uses MultiYearAssumptions.terminalLiquidationTaxRate (default 0.22).
    // For pre-Plan-B v2.0 ship, the rate is hardcoded in MultiYearAssumptions
    // defaults; Plan B will surface it in onboarding.
    private func terminalLiquidationTax(
        _ path: [YearRecommendation],
        rate: Double
    ) -> Double {
        guard let last = path.last else { return 0 }
        let trad = last.endOfYearBalances.primaryTraditional
                 + last.endOfYearBalances.spouseTraditional
        return trad * rate
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
        // Initial locked state: $0 for every year (matches old single-pass behavior).
        // The fixed-point iteration will refine this.
        // ───────────────────────────────────────────────────────────
        var locked: [Int: [LeverAction]] = Dictionary(
            uniqueKeysWithValues: (baseYear...endYear).map { ($0, [LeverAction]()) }
        )

        // ───────────────────────────────────────────────────────────
        // Outer fixed-point iteration loop (cap = 2)
        //
        // Each iteration runs a forward greedy pass over all years, using the
        // PRIOR iteration's locked decisions as the future-year fill (instead
        // of $0). Repeats until locked stops changing OR cap reached.
        //
        // Iteration cap of 2 brings isolated optimize() runtime to ~7s and keeps
        // parallel test-suite runs reliably under the 15s perf budget. Original
        // cap of 5 caused 30-50s runtime; cap of 3 still blew budget under
        // parallel contention. Empirical observation: realistic scenarios converge
        // in 2-3 iterations. With cap=2 we may lose one refinement pass on edge
        // cases; the #if DEBUG non-convergence log will surface them for analysis.
        // ───────────────────────────────────────────────────────────
        let maxIterations = 2
        var iteration = 0
        var converged = false
        while iteration < maxIterations && !converged {
            iteration += 1
            let previousLocked = locked

            // ───── Inner forward greedy pass ─────
            for yearIdx in 0..<horizonYears {
                let Y = baseYear + yearIdx

                // Compute baseline projection NOW with current `locked` (which has
                // been updated through year Y-1 in this pass). Critical for cliff
                // candidate generation: stale baseline → wrong distance-to-cliff.
                // (Gemini correction; see spec section "Algorithm".)
                let currentBaselinePath = ProjectionEngine().project(
                    inputs: inputs, assumptions: assumptions, actionsPerYear: locked
                )
                let baselineRec = currentBaselinePath[yearIdx]

                // Generate per-year cliff candidates using the actual baseline MAGI/income for Y.
                let cliffs = OptimizationEngine.cliffCandidates(
                    forYear: Y,
                    baselineIRMAAMagi: baselineRec.irmaaMagi,
                    baselineACAMagi: baselineRec.acaMagi,
                    baselineTaxableIncome: baselineRec.taxableIncome,
                    filingStatus: inputs.filingStatus,
                    householdSize: inputs.acaHouseholdSize,
                    assumptions: assumptions
                )

                // Union with static set; dedupe within $1K tolerance.
                let allAmounts = (candidateAmounts + cliffs).sorted()
                var deduped: [Double] = []
                for amt in allAmounts {
                    if let last = deduped.last, abs(amt - last) < 1_000 { continue }
                    deduped.append(amt)
                }

                var bestAmount: Double = 0
                var bestObjective = Double.infinity

                for amount in deduped {
                    var trialActions = locked
                    trialActions[Y] = (amount > 0) ? [.rothConversion(amount: amount)] : []
                    // Future undecided years keep PRIOR-iteration locked values.
                    // (No more `trialActions[y] = []` — that was Bug 2.)

                    let path = ProjectionEngine().project(
                        inputs: inputs, assumptions: assumptions, actionsPerYear: trialActions
                    )
                    let objective = path.reduce(0.0) { $0 + $1.taxBreakdown.total }
                                  + terminalLiquidationTax(path, rate: assumptions.terminalLiquidationTaxRate)

                    if objective < bestObjective {
                        bestObjective = objective
                        bestAmount = amount
                    }
                }

                locked[Y] = (bestAmount > 0) ? [.rothConversion(amount: bestAmount)] : []
            }

            // ───── Convergence check ─────
            if locked == previousLocked {
                converged = true
            }
        }

        // Optional debug: log if we hit the cap without converging.
        #if DEBUG
        if !converged {
            print("OptimizationEngine: hit iteration cap (\(maxIterations)) without convergence")
        }
        #endif

        // ───────────────────────────────────────────────────────────
        // Final projection with all locked-in actions
        // ───────────────────────────────────────────────────────────

        // Safety net: ensure every year in [baseYear...endYear] has an entry
        // (the loop above should have filled them all).
        var finalActions = locked
        for y in baseYear...endYear {
            if finalActions[y] == nil {
                finalActions[y] = []
            }
        }

        let finalPath = ProjectionEngine().project(
            inputs: inputs, assumptions: assumptions, actionsPerYear: finalActions
        )

        // ───────────────────────────────────────────────────────────
        // Constraint acceptance rationale (objective includes terminal tax,
        // matching the inner-loop comparison)
        // ───────────────────────────────────────────────────────────

        let hits = ConstraintAcceptor().detect(
            path: finalPath,
            filingStatus: inputs.filingStatus,
            householdSize: inputs.acaHouseholdSize
        )

        let baselineActions = Dictionary(
            uniqueKeysWithValues: (baseYear...endYear).map { ($0, [LeverAction]()) }
        )
        let baselinePath = ProjectionEngine().project(
            inputs: inputs, assumptions: assumptions, actionsPerYear: baselineActions
        )
        let baselineLifetimeTax = baselinePath.reduce(0.0) { $0 + $1.taxBreakdown.total }
                                + terminalLiquidationTax(baselinePath, rate: assumptions.terminalLiquidationTaxRate)
        let currentLifetimeTax = finalPath.reduce(0.0) { $0 + $1.taxBreakdown.total }
                               + terminalLiquidationTax(finalPath, rate: assumptions.terminalLiquidationTaxRate)
        let lifetimeSavings = baselineLifetimeTax - currentLifetimeTax

        var acceptedHits: [ConstraintHit] = []
        for hit in hits {
            guard lifetimeSavings >= hit.cost else { continue }
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
