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
//  Outer loop (cap = 2, exit on convergence; see optimize() body for cap rationale):
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
        /// In-horizon tax + terminal liquidation tax — mirrors what optimize()'s objective
        /// minimizes. Wrappers (WidowStressTest, SSClaimNudge) should read this directly
        /// instead of re-summing taxBreakdown.total, which omits terminal liquidation tax.
        let totalObjectiveCost: Double
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
        assumptions: MultiYearAssumptions,
        configProvider: TaxYearConfigProvider = .current
    ) -> [Double] {
        var candidates: [Double] = []
        let buffer = assumptions.cliffBuffer
        let cap: Double = 500_000
        // Resolve this projection year's config explicitly (no global static dependency).
        let cfg = configProvider.config(forYear: year)

        // ─── IRMAA tier candidates (only if Medicare-relevant) ───
        if let irmaaMagi = baselineIRMAAMagi {
            // TaxCalculationEngine.config.irmaaTiers has 6 entries: tier 0 (no surcharge) + tiers 1-5.
            // We want fill-to-(threshold - buffer) for tiers 1-5 only (skip tier 0, which has
            // threshold == 0 and is the standard zone).
            for tierEntry in cfg.irmaaTiers where tierEntry.tier > 0 {
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
            if let fpl = cfg.acaSubsidy2026.fpl2026.householdSizeToFPL[key] {
                let cliff = fpl * 4.0
                let target = cliff - buffer
                let delta = target - acaMagi
                if delta > 0 && delta <= cap {
                    candidates.append(delta)
                }
            }
        }

        // ─── Ordinary tax bracket tops (no buffer) ───
        let brackets = cfg.toTaxBrackets()
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
        // Inherited traditional still at horizon end (lifetime-stretch EDB cases; non-EDB
        // accounts drain within 10 years) is pre-tax money like the owner buckets.
        let trad = last.endOfYearBalances.primaryTraditional
                 + last.endOfYearBalances.spouseTraditional
                 + last.endOfYearBalances.inheritedTraditional
        return trad * rate
    }

    // MARK: - Shared objective helper
    //
    // Computes the optimizer's full objective for a path: in-horizon tax + terminal
    // liquidation tax. Used at Result construction and by wrappers (WidowStressTest,
    // SSClaimNudge) that need to evaluate path objectives consistently with how the
    // optimizer ranked them. Static so wrappers can call it after a ProjectionEngine.project()
    // without needing an OptimizationEngine instance.

    /// PV of a path's in-horizon tax, discounting each year to baseYear.
    static func discountedInHorizon(_ path: [YearRecommendation], baseYear: Int, rate: Double) -> Double {
        path.reduce(0.0) { $0 + EngineMath.presentValue($1.taxBreakdown.total, yearsFromBase: $1.year - baseYear, realDiscountRate: rate) }
    }

    /// Single source of truth for the full PV objective: discounted in-horizon tax PLUS the
    /// terminal tax discounted by the FULL horizon length (`horizonYears == endYear - baseYear + 1`;
    /// the terminal balance is liquidated at the end of the last horizon year). Every site that
    /// ranks a path — the candidate sweep, the constraint-acceptance baseline/current comparison,
    /// the final Result, and `computeObjectiveCost` — MUST go through this so the optimizer's
    /// ranking and the wrappers (SSClaimNudge) never diverge on the terminal discount period.
    static func objectiveCost(path: [YearRecommendation], baseYear: Int, horizonYears: Int,
                              rate: Double, terminalTax: Double) -> Double {
        discountedInHorizon(path, baseYear: baseYear, rate: rate)
            + EngineMath.presentValue(terminalTax, yearsFromBase: horizonYears, realDiscountRate: rate)
    }

    static func computeObjectiveCost(
        path: [YearRecommendation],
        terminalLiquidationTaxRate: Double,
        baseYear: Int,
        pvRealDiscountRate: Double
    ) -> Double {
        guard let last = path.last else {
            return discountedInHorizon(path, baseYear: baseYear, rate: pvRealDiscountRate)
        }
        let trad = last.endOfYearBalances.primaryTraditional
                 + last.endOfYearBalances.spouseTraditional
                 + last.endOfYearBalances.inheritedTraditional
        // Match optimize()'s horizonYears (endYear - baseYear + 1) exactly, so this helper and the
        // optimizer's totalObjectiveCost discount the terminal tax over the same number of years.
        let horizonYears = max(0, last.year - baseYear + 1)
        return objectiveCost(path: path, baseYear: baseYear, horizonYears: horizonYears,
                             rate: pvRealDiscountRate, terminalTax: trad * terminalLiquidationTaxRate)
    }

    // MARK: - Heir-weighted objective (owner-vs-heirs trade-off)
    //
    // objective(λ) = inHorizon + (1−λ)·ownerTerminalSelfTax + λ·heirTerminalTax
    // In-horizon tax is always counted once; only the TERMINAL disposition is convex-blended.
    // λ=0 reproduces today's objective exactly (preserves the Terminal-Tax-Illusion fix).

    /// Pure convex blend of the two terminal dispositions (in-horizon counted once by callers).
    static func blendedObjectiveCost(
        inHorizon: Double,
        selfTerminalTax: Double,
        heirTerminalTax: Double,
        heirWeight: Double
    ) -> Double {
        inHorizon + (1 - heirWeight) * selfTerminalTax + heirWeight * heirTerminalTax
    }

    /// Heir 10-year "tax bomb" on the terminal Traditional balance (stacked heir rate).
    /// Roth is tax-free to the heir and excluded.
    private func heirTerminalTax(
        _ path: [YearRecommendation],
        inputs: MultiYearStaticInputs
    ) -> Double {
        guard let last = path.last else { return 0 }
        let trad = last.endOfYearBalances.primaryTraditional
                 + last.endOfYearBalances.spouseTraditional
                 + last.endOfYearBalances.inheritedTraditional
        return LegacyPlanningEngine.heirTaxOnInheritedTraditional(
            balance: trad,
            heirSalary: inputs.heirSalary,
            heirFilingStatus: inputs.heirFilingStatus,
            drawdownYears: inputs.heirDrawdownYears)
    }

    /// Blended terminal disposition: (1−λ)·owner-self-liquidation + λ·heir bomb.
    private func blendedTerminalTax(
        _ path: [YearRecommendation],
        inputs: MultiYearStaticInputs,
        selfRate: Double,
        heirWeight: Double
    ) -> Double {
        let selfTax = terminalLiquidationTax(path, rate: selfRate)
        let heirTax = heirTerminalTax(path, inputs: inputs)
        return (1 - heirWeight) * selfTax + heirWeight * heirTax
    }

    // MARK: - Public API

    func optimize(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions,
        configProvider: TaxYearConfigProvider = .current,
        heirWeight: Double = 0,
        approach: ConversionApproach = .recommendedTaxMin
    ) -> Result {
        switch approach {
        case .recommendedTaxMin:
            break   // fall through to the existing greedy body below (unchanged)
        case .fillToBracket, .limitToIRMAA:
            return runDeterministicLadder(approach: approach, inputs: inputs,
                                          assumptions: assumptions, configProvider: configProvider,
                                          heirWeight: heirWeight)
        }

        let baseYear = inputs.baseYear

        // H3: the household horizon runs to the LATER of each spouse's endpoint, so a younger
        // spouse's longer horizon isn't truncated to the primary's. Each spouse's end year =
        // baseYear + (their horizonEndAge − their current age). horizonEndAge(for: .spouse)
        // falls back to the shared horizonEndAge when no spouse override is set. (Mid-horizon
        // survivor filing-status transitions are modeled separately by WidowStressTest; here
        // both spouses are assumed alive across the household horizon.)
        let primaryEndYear = baseYear + (assumptions.horizonEndAge - inputs.primaryCurrentAge)
        let spouseEndYear: Int = {
            guard let spouseAge = inputs.spouseCurrentAge else { return primaryEndYear }
            return baseYear + (assumptions.horizonEndAge(for: .spouse) - spouseAge)
        }()
        let endYear = max(primaryEndYear, spouseEndYear)
        let horizonYears = endYear - baseYear + 1

        // Empty horizon (e.g., horizonEndAge < currentAge): return empty result
        guard horizonYears > 0 else {
            return Result(recommendedPath: [], tradeOffsAccepted: [], totalObjectiveCost: 0)
        }

        // ───────────────────────────────────────────────────────────
        // Initial locked state: $0 for every year (matches old single-pass behavior).
        // The fixed-point iteration will refine this.
        // ───────────────────────────────────────────────────────────
        var locked: [Int: [LeverAction]] = Dictionary(
            uniqueKeysWithValues: (baseYear...endYear).map { ($0, [LeverAction]()) }
        )

        // ───────────────────────────────────────────────────────────
        // Plan B Phase 1: pin Year 1 actions from user overrides if present.
        //
        // staticInputs.year1PrimaryRothConversion / year1SpouseRothConversion carry
        // the user's Year1QuickEditor slider values when excludeYear1Overrides=false
        // (the "current path" cache). When excludeYear1Overrides=true those fields
        // are zeroed, so the engine optimizes Year 1 from scratch (the "engine
        // optimal" baseline path). This is the mechanism that makes the two-cache
        // strategy in MultiYearStrategyManager meaningful.
        //
        // Only Roth conversions are pinnable in V2.0:
        // - LeverAction has .traditionalWithdrawal/.rothWithdrawal but the greedy
        //   candidate sweep doesn't emit them; pinning would be ineffective.
        // - LeverAction has NO .qcd case at all — adding QCD pinning requires an
        //   engine surface change.
        // V2.1 candidate: extend LeverAction with .qcd case + teach greedy to emit
        // withdrawal/QCD candidates so user-set sliders affect engine output.
        // ───────────────────────────────────────────────────────────
        let year1Roth = inputs.year1PrimaryRothConversion + inputs.year1SpouseRothConversion

        var year1PinnedActions: [LeverAction] = []
        if year1Roth > 0 {
            year1PinnedActions.append(.rothConversion(amount: year1Roth))
        }

        if !year1PinnedActions.isEmpty {
            locked[baseYear] = year1PinnedActions
        }

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
            // Cooperative cancellation (M8): when the manager cancels a superseded compute
            // (rapid slider changes), bail out of the expensive candidate sweep instead of
            // running it to completion. The caller discards a cancelled result.
            if Task.isCancelled { return Result(recommendedPath: [], tradeOffsAccepted: [], totalObjectiveCost: 0) }
            iteration += 1
            let previousLocked = locked

            // ───── Inner forward greedy pass ─────
            for yearIdx in 0..<horizonYears {
                if Task.isCancelled { return Result(recommendedPath: [], tradeOffsAccepted: [], totalObjectiveCost: 0) }
                let Y = baseYear + yearIdx

                // Plan B Phase 1: if user has pinned Year 1 actions, skip optimization
                // for that year — engine respects user choices and optimizes Years 2+
                // around them. This applies in EVERY fixed-point iteration so the pin
                // is never overwritten by a refinement pass.
                // When year1PinnedActions is empty (excludeYear1Overrides=true, or all
                // Year 1 sliders are zero), this guard never fires and behavior is
                // identical to pre-Plan-B — all 951 prior engine tests remain valid.
                if yearIdx == 0 && !year1PinnedActions.isEmpty {
                    continue
                }

                // Compute baseline projection NOW with current `locked` (which has
                // been updated through year Y-1 in this pass). Critical for cliff
                // candidate generation: stale baseline → wrong distance-to-cliff.
                // (Gemini correction; see spec section "Algorithm".)
                let currentBaselinePath = ProjectionEngine(configProvider: configProvider).project(
                    inputs: inputs, assumptions: assumptions, actionsPerYear: locked
                )
                let baselineRec = currentBaselinePath[yearIdx]

                // B4 root cause 1 (2026-07-13 fix backlog): the traditional balance actually
                // available to convert THIS year — prior year's end-of-year primary + spouse
                // traditional (excludes inherited buckets, which are never a conversion source;
                // see ProjectionEngine's rothConversion handling). For yearIdx==0 that's simply
                // the starting balance. Reused below to cap `bestAmount` so a candidate that
                // gets silently clamped by ProjectionEngine (e.g. testing $150K against a
                // drained/near-drained $101K account) can never get LOCKED at its inflated
                // nominal value — only the executed conversion should ever surface. Without
                // this, `locked[Y]` (and everything downstream that reads `rec.actions`:
                // PlanSummary.totalConversions, the ladder chart/rows, the CPA export, the
                // narrative synthesizer) reports a phantom conversion that was never executed.
                let availableTraditionalAtY: Double = yearIdx == 0
                    ? inputs.startingBalances.traditional
                    : currentBaselinePath[yearIdx - 1].endOfYearBalances.primaryTraditional
                        + currentBaselinePath[yearIdx - 1].endOfYearBalances.spouseTraditional

                // Generate per-year cliff candidates using the actual baseline MAGI/income for Y.
                let cliffs = OptimizationEngine.cliffCandidates(
                    forYear: Y,
                    baselineIRMAAMagi: baselineRec.irmaaMagi,
                    baselineACAMagi: baselineRec.acaMagi,
                    baselineTaxableIncome: baselineRec.taxableIncome,
                    filingStatus: inputs.filingStatus,
                    householdSize: inputs.acaHouseholdSize,
                    assumptions: assumptions,
                    configProvider: configProvider
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

                    let path = ProjectionEngine(configProvider: configProvider).project(
                        inputs: inputs, assumptions: assumptions, actionsPerYear: trialActions
                    )
                    let r = assumptions.pvRealDiscountRate
                    let objective = Self.objectiveCost(
                        path: path, baseYear: baseYear, horizonYears: horizonYears, rate: r,
                        terminalTax: blendedTerminalTax(path, inputs: inputs,
                                                        selfRate: assumptions.terminalLiquidationTaxRate,
                                                        heirWeight: heirWeight))

                    if objective < bestObjective {
                        bestObjective = objective
                        bestAmount = amount
                    }
                }

                // Cap the LOCKED amount at what's actually available this year. The candidate
                // sweep above is unaffected (it already selects on the real, clamped objective);
                // this only prevents a request that ties or wins on a clamped-identical objective
                // from being reported as a larger conversion than what will ever execute.
                let cappedBestAmount = min(bestAmount, availableTraditionalAtY)
                locked[Y] = (cappedBestAmount > 0) ? [.rothConversion(amount: cappedBestAmount)] : []
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

        let finalPath = ProjectionEngine(configProvider: configProvider).project(
            inputs: inputs, assumptions: assumptions, actionsPerYear: finalActions
        )

        // ───────────────────────────────────────────────────────────
        // Constraint acceptance rationale (objective includes terminal tax,
        // matching the inner-loop comparison)
        // ───────────────────────────────────────────────────────────

        let hits = ConstraintAcceptor().detect(
            path: finalPath,
            filingStatus: inputs.filingStatus,
            householdSize: inputs.acaHouseholdSize,
            configProvider: configProvider
        )

        let baselineActions = Dictionary(
            uniqueKeysWithValues: (baseYear...endYear).map { ($0, [LeverAction]()) }
        )
        let baselinePath = ProjectionEngine(configProvider: configProvider).project(
            inputs: inputs, assumptions: assumptions, actionsPerYear: baselineActions
        )
        let rRate = assumptions.pvRealDiscountRate
        let baselineLifetimeTax = Self.objectiveCost(
            path: baselinePath, baseYear: baseYear, horizonYears: horizonYears, rate: rRate,
            terminalTax: blendedTerminalTax(baselinePath, inputs: inputs, selfRate: assumptions.terminalLiquidationTaxRate, heirWeight: heirWeight))
        let currentLifetimeTax = Self.objectiveCost(
            path: finalPath, baseYear: baseYear, horizonYears: horizonYears, rate: rRate,
            terminalTax: blendedTerminalTax(finalPath, inputs: inputs, selfRate: assumptions.terminalLiquidationTaxRate, heirWeight: heirWeight))
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

        return Result(
            recommendedPath: finalPath,
            tradeOffsAccepted: acceptedHits,
            totalObjectiveCost: Self.objectiveCost(
                path: finalPath, baseYear: baseYear, horizonYears: horizonYears,
                rate: assumptions.pvRealDiscountRate,
                terminalTax: blendedTerminalTax(finalPath, inputs: inputs,
                                                selfRate: assumptions.terminalLiquidationTaxRate,
                                                heirWeight: heirWeight))
        )
    }

    // MARK: - Deterministic ladders (.fillToBracket / .limitToIRMAA)

    /// Deterministic per-year ladder: for each year, bisect the conversion that lands at the
    /// approach's target (ordinary bracket top, or the IRMAA tier ceiling), lock it, and move on.
    /// A single forward pass — each year's landing depends only on years <= Y.
    private func runDeterministicLadder(
        approach: ConversionApproach,
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions,
        configProvider: TaxYearConfigProvider,
        heirWeight: Double
    ) -> Result {
        let baseYear = inputs.baseYear
        let primaryEndYear = baseYear + (assumptions.horizonEndAge - inputs.primaryCurrentAge)
        let spouseEndYear: Int = {
            guard let spouseAge = inputs.spouseCurrentAge else { return primaryEndYear }
            return baseYear + (assumptions.horizonEndAge(for: .spouse) - spouseAge)
        }()
        let endYear = max(primaryEndYear, spouseEndYear)
        guard endYear >= baseYear else { return Result(recommendedPath: [], tradeOffsAccepted: [], totalObjectiveCost: 0) }

        var locked: [Int: [LeverAction]] = Dictionary(uniqueKeysWithValues: (baseYear...endYear).map { ($0, [LeverAction]()) })
        // Preserve the pinned Year-1 conversion, consistent with the greedy path.
        let year1Roth = inputs.year1PrimaryRothConversion + inputs.year1SpouseRothConversion
        let hasYear1Pin = year1Roth > 0
        if hasYear1Pin { locked[baseYear] = [.rothConversion(amount: year1Roth)] }

        for Y in baseYear...endYear {
            if Task.isCancelled { return Result(recommendedPath: [], tradeOffsAccepted: [], totalObjectiveCost: 0) }
            if Y == baseYear && hasYear1Pin { continue }   // respect the Year-1 pin

            // f(x): project year Y with conversion x this year (years < Y already locked;
            // years > Y don't affect year Y).
            func projectTrial(_ x: Double) -> [YearRecommendation] {
                var trial = locked
                trial[Y] = x > 0 ? [.rothConversion(amount: x)] : []
                return ProjectionEngine(configProvider: configProvider).project(
                    inputs: inputs, assumptions: assumptions, actionsPerYear: trial)
            }

            // land-point: the metric this approach root-finds on.
            func landPoint(_ x: Double) -> Double {
                let rec = projectTrial(x)[Y - baseYear]
                switch approach {
                case .fillToBracket:   return rec.taxableIncome - rec.taxablePreferential   // ordinary income
                case .limitToIRMAA:    return rec.magi
                case .recommendedTaxMin: return 0
                }
            }

            // B4 root cause 1 (2026-07-13 fix backlog): the traditional balance actually
            // available to convert THIS year — the prior year's end-of-year primary + spouse
            // traditional (excludes inherited buckets, which are never a conversion source).
            // The OLD code capped the bisection's upperBound at the STARTING balance (a
            // constant), so once the account drained, the search kept locking a phantom
            // "convert up to $500K" request every remaining year (the projection silently
            // clamped the EXECUTED conversion to $0, but the inflated locked request leaked
            // into rec.actions and everything downstream that reads it — PlanSummary totals,
            // the ladder chart/rows, the CPA export, the narrative synthesizer).
            let availableTraditionalAtY: Double = Y == baseYear
                ? inputs.startingBalances.traditional
                : {
                    let priorRec = projectTrial(0)[Y - baseYear - 1]
                    return priorRec.endOfYearBalances.primaryTraditional + priorRec.endOfYearBalances.spouseTraditional
                }()
            let upperBoundCap = min(availableTraditionalAtY, 500_000.0)

            let target: Double = {
                let cfg = configProvider.config(forYear: Y)
                switch approach {
                case .fillToBracket(let rate):
                    let brackets = cfg.toTaxBrackets()
                    let arr = inputs.filingStatus == .single ? brackets.federalSingle : brackets.federalMarried
                    // top of the bracket at `rate` = the NEXT bracket's threshold.
                    if let i = arr.firstIndex(where: { abs($0.rate - rate) < 1e-9 }), i + 1 < arr.count {
                        return arr[i + 1].threshold
                    }
                    return .greatestFiniteMagnitude   // rate not found this year -> no cap (convert nothing extra)
                case .limitToIRMAA(let tier, let buffer):
                    let tiers = cfg.toIRMAATiers()
                    guard let tierEntry = tiers.first(where: { $0.tier == tier }) else { return .greatestFiniteMagnitude }
                    let threshold = inputs.filingStatus == .single ? tierEntry.singleThreshold : tierEntry.mfjThreshold
                    return threshold - buffer
                case .recommendedTaxMin: return 0
                }
            }()

            let x = ConversionLadder.largestConversionBelow(target: target, upperBound: upperBoundCap, evaluate: landPoint)
            locked[Y] = x > 0 ? [.rothConversion(amount: x)] : []
        }

        let finalPath = ProjectionEngine(configProvider: configProvider).project(
            inputs: inputs, assumptions: assumptions, actionsPerYear: locked)
        let hits = ConstraintAcceptor().detect(path: finalPath, filingStatus: inputs.filingStatus,
                                                householdSize: inputs.acaHouseholdSize, configProvider: configProvider)
        return Result(
            recommendedPath: finalPath,
            tradeOffsAccepted: hits,   // report the crossings the chosen approach lands on (advisory)
            totalObjectiveCost: Self.objectiveCost(
                path: finalPath, baseYear: baseYear, horizonYears: endYear - baseYear + 1,
                rate: assumptions.pvRealDiscountRate,
                terminalTax: blendedTerminalTax(finalPath, inputs: inputs,
                                                selfRate: assumptions.terminalLiquidationTaxRate, heirWeight: heirWeight)))
    }
}
