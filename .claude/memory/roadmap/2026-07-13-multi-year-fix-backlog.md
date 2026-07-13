# Multi-Year Plan — Fix Backlog (living list)

**Started:** 2026-07-13 (John, while walking the Multi-Year tab with a $20M MFJ Bob/Sue test profile).
**Status:** Post-2.1.0-submission. None of these block the shipped 2.1.0 (all pre-existing or display-only). Grouped by area; ordered roughly by user-visible severity. Append as new items surface (Fred's review feeds in here).

---

## A. Engine / objective (deeper, next-cycle)

### A1. "Minimize lifetime tax" over-converts (drains IRA into high brackets) — ROOT-CAUSED
The λ=0 optimizer minimizes **PV(in-horizon tax) + PV(0.22 × ending traditional)**, which is NOT the same as maximizing after-tax wealth. It fully drains the IRA (converting into 32–37%) to avoid a 22% terminal + low-bracket RMDs, leaving the household slightly *poorer* than a gentle fill. Decomposition (deleted harness): full-drain objective 268k / wealth 6,054k vs fillTo12% objective 339k / wealth **6,168k**. Mechanism: 6%-growth-vs-3%-discount gap inflates the terminal-tax penalty to ~0.45/$ of leftover trad. Severity: material impact small (~2% wealth), but it's the DEFAULT objective and reads as bad advice.
**Fix directions:** (a) quick guard — cap tax-min conversions at ~the terminal-rate bracket (22–24%); (b) recalibrate terminal tax so growth-vs-discount stops over-penalizing; (c) reframe objective toward after-tax wealth. Details: memory `over-conversion-brake-ineffective.md`.

### A2. "Fill to bracket" is CORRECT, but the AGI/MAGI it produces is misleading — TRACED, NOT A BUG
Two wrong hypotheses corrected in-session: (1) bisection overshoots — WRONG (trace: ordinary taxable lands exactly on the 22% top $211k every year); (2) AGI driven by selling the low-basis stock to fund conversion taxes — WRONG (John's Apple Stock has "use to pay Roth conversion taxes" UNCHECKED, so nothing is sold to fund taxes).
**Correct mechanism:** the high AGI is the taxable portfolio's **ongoing dividend + capital-gain-distribution income**, computed as `(qualifiedDividendYield + realizedLongTermGainYield) × balance` per account (TaxableAccountEngine.annualIncome). John's $6M Apple at 1.5% qual-div = ~$90k/yr alone; the full ~$11M taxable portfolio throws off ~$150–200k/yr regardless of conversions or sales. That preferential layer stacks on the 22%-filled ordinary income → AGI $441k, taxed at 15–20% LTCG + 3.8% NIIT (MAGI > $250k) + state, and crosses IRMAA. Conversion tax is paid from a flagged account or grossed up from the IRA (ordinary, already inside the 22% fill).
**Real issue is CLARITY, not correctness:** the ladder/charts show AGI/MAGI against a "fill to 22%" (ordinary-income) label. A user reads AGI $441k as "this isn't 22%," when it's mostly unavoidable investment income, not the conversion.
**Fix (clarity/UX):** (a) surface the ordinary-taxable landing next to the bracket ("ordinary income at 22% ceiling; investment income adds $X to MAGI"); (b) show that the high MAGI (and the NIIT/IRMAA flags) come from the portfolio's dividend/distribution throw-off stacking on the conversion, not the conversion breaking 22%; (c) a concentrated high-dividend holding (the $6M Apple) makes conversions cross NIIT/IRMAA unavoidably — worth surfacing.

## A3. Gross-up tax-funding does NOT recompute IRMAA/ACA — CONFIRMED (real calc approximation)
`ProjectionEngine.swift:837-838` (`.taxableThenGrossUp` default): when the IRA funds the conversion tax via a grossed-up withdrawal, "IRMAA/ACA are NOT recomputed for the gross-up withdrawal." So the extra ordinary income from self-funding the tax understates its IRMAA (and ACA) impact. Federal+state ARE recomputed (incrementalTax, :865-876); IRMAA/NIIT-via-MAGI from the gross-up are not. Surfaced by the external review (F6a) — verified valid.
**Fix:** recompute IRMAA/ACA (and NIIT MAGI) for the gross-up withdrawal, or document the understatement in-app. Note: gross-up IS correctly counted in the fill-to-bracket ordinary target (no bracket overshoot — trace-confirmed).

## A4. Gross-up IRA withdrawal is not disclosed — CONFIRMED (disclosure gap)
The ladder shows "convert $X" but never the ADDITIONAL IRA withdrawal taken to pay the conversion tax (when taxable funding is short). So the true IRA outflow and drawdown speed are hidden; "convert $319k" understates total IRA depletion. (External review F6b.)
**Fix:** show gross conversion, the separate tax-funding IRA withdrawal, and total ordinary income created. (Multi-year uses gross-up, NOT withholding, so the full conversion does reach the Roth — the "amount reaching Roth" concern does not apply here.)

## B. Comparison / display consistency

### B2. "Minimize lifetime tax" shows a HIGHER "Lifetime tax" than "Fill to bracket" — CONFIRMED
Comparison table "Lifetime tax" = `PlanPathMetrics.lifetimeTax` = **nominal undiscounted sum** of taxes paid, no terminal tax (PlanPathMetrics.swift:8). But "Minimize lifetime tax" optimizes **PV + terminal tax** (OptimizationEngine.swift:232). It defers tax (RMD tail on the $3.6M it leaves) → higher nominal total ($755k) than the front-loaded fill-to-22% ($718k). Same dollars, different time-weighting. Reads as "the minimize option doesn't minimize."
**Fix:** show the **PV** lifetime tax in the comparison (what the optimizer actually minimizes) so the minimize option comes out lowest — or show both nominal + PV columns. Repro: Bob/Sue, fill-22 $718k vs minimize $755k.

### B4. Phantom "$500k" conversions after the IRA drains — REPRODUCED, TWO stacked bugs
Ladder shows "convert $500k" in years where the traditional IRA is $0 (AGI far below $500k proves the actual conversion is ~$0). Reproduced with a Bob/Sue harness (deleted): real ~$250k conversions fill ordinary to the 22% top ($211k) until the IRA drains ~2034, then rows read "convert $500k" with startTrad=$0, ordinary=$0, actual conversion=$0, AGI = just dividends (~$121–166k). Matches John's screen (his $500k rows, AGI $131–294k).
**Root cause 1 (engine):** `OptimizationEngine.runDeterministicLadder` sets `upperBoundCap = min(inputs.startingBalances.traditional, 500_000)` — the STARTING balance (constant $1.83M), not the CURRENT year's available traditional. So it tests/locks a $500k request every year even after the account is empty; the empty-year conversion is $0 but ordinary stays low so `largestConversionBelow` accepts $500k as the locked amount.
**Root cause 2 (display):** the row shows the locked `LeverAction` request, not the projected actual conversion.
**Fix:** (1) cap `upperBoundCap` at the CURRENT-year available traditional (per-year), so it never requests from a drained account; (2) add `executedRothConversion` (clamped actual) to `YearRecommendation` and route ALL consumers to it, not `actions`.

**DOWNSTREAM AUDIT (2026-07-13, John's ask — did the phantom request leak into totals/tax/balances/IRMAA/NIIT/legacy?):**
Foundation: `ProjectionEngine:247-294` CLAMPS every conversion to convertible balance ("Bug B fix"), so BALANCES/INCOME/TAX reflect the actual; but `rec.actions` still carries the REQUESTED amount. Fault line: reads `rec.actions` = requested (phantom); reads `taxBreakdown`/`agi`/`taxableIncome`/`endOfYearBalances`/`magi` = clamped actual.
- **SAFE (read clamped projection — money numbers are CORRECT):** lifetime tax (`PlanPathMetrics.lifetimeTax`→taxBreakdown), tax-comparison deltas federal/state/IRMAA/ACA/NIIT (`ConsequenceDeltas`→taxBreakdown per channel), ending balances / ending trad / ending Roth (`endOfYearBalances`), legacy/heirs-keep (`PlanPathMetrics.heirsKeep`→ending balances), peak forced RMD (`rmd`). Phantom does NOT corrupt tax/balances/IRMAA/NIIT/legacy.
- **LEAKS (read requested `actions` → conversion-amount figures INFLATED):** (1) `PlanSummary.totalConversions` = "Convert $11.6M over 26 years" (phantom ~$500k×~15 drained yrs ≈ $7.5M phantom); (2) `PlanPathMetrics.peakAnnualRothConversion` = "+$300k peak conversion" comparison delta (reports $500k vs real ~$253k); (3) `ConversionLadderChart` = conversions-by-year bars; (4) `LadderRow` = ladder rows; (5) `MultiYearCPABriefing:178,193` = CPA export conversion figures (the report going to Fred); (6) `StrategySummarySynthesizer.clusterRothConversions` = narrative.
- **SAFE-because-Year-1-only:** `MultiYearPlanView.year1Roth`, `MultiYearStrategyManager.resetYear1ToEngineOptimal` (Year 1 is never a drained/phantom year).
**Net:** tax/wealth/IRMAA/NIIT/legacy math is sound; the entire conversion-REPORTING layer (headline total, peak-conversion comparison, by-year chart, ladder, CPA export, narrative) is inflated by never-executed conversions. Fix at source (upperBoundCap) + route all 6 leaks to executedRothConversion.

## C. Charts / UX

### C5. IRMAA-tier reference lines unreadable when income >> thresholds
"Income vs tax cliffs" chart stacks the tier 1–5 labels on top of each other near $0 when household income (e.g. $3.5M) dwarfs the ~$200k Medicare thresholds. Adds clutter, not insight.
**Fix:** hide/collapse the tier lines (or annotate "above all IRMAA tiers") when income is orders of magnitude above the top tier.

### C6. Balances/cliffs charts default to nominal "Future $"
Large nominal far-future dollars ($80–150M) alarm users even with correct inputs. The "Present value" toggle exists but defaults to Future $.
**Fix (consider):** default to Present value, or label the axis/period so nominal 2050s dollars aren't read as today's. Product call.

## D. Tests / cleanup

### D7. Re-enable `RealismRegressionTests.brakeStopsDrain`
Shelved when A1's correct SALT behavior flipped it (CA state tax now deductible → drains at λ=0). Re-enable with a robust, non-knife-edge assertion once A1's objective fix lands.

### D10. Delete orphaned `PlanComparisonView` (dead code after the 2c three-way swap; model still used).
### D11. Thread `configProvider` into the approach chips (currently read global `TaxCalculationEngine.config.current`; benign today, both `.current`).

## E. Minor modeling seams

### E8. SALT-cap MAGI-phaseout basis mismatch
`MultiYearItemizedDeduction.saltCap` phases out vs the passed `agi` (net of above-the-line); single-year `DataManager.saltCap` uses `scenarioGrossIncome` (gross). Diverges only when above-the-line deductions (401k/HSA/trad-IRA) are nonzero AND MAGI > ~$500k. Non-biting for retirees.

### E9. Local/city income tax (`.saltTax`) dropped from the multi-year projection
Adapter carries property tax only; the engine recomputes STATE income tax per year but has no local/city income-tax line, so manually-entered `.saltTax` is not modeled multi-year.

## F. Possible guardrails (nice-to-have)

### F-SS. Warn when taxable SS exceeds the SS-Planner benefits
John hit a data-entry error: muni interest also entered as a Social Security source → taxable SS showed $115k (> 85% of the $88k SS-Planner benefits). Not a bug, but the app could flag "taxable SS exceeds your entered benefits — check for a duplicate/mistyped income source."

## G. External-review reconciliation (2026-07-13) — verified against code, DON'T re-chase
A sophisticated external review (pasted by John) raised 7 findings. Reconciled via `review-external` against the code:
- **ALREADY CORRECT (close, do not re-open):**
  - Investment-income classification (F2): adapter classifies interest/nonqual-div/short-term-gains as ORDINARY, only qual-div/LTCG as preferential (MultiYearInputAdapter isOtherOrdinary/isPreferential); double-count guarded by accountsSupersedeIncome (:208-217). Per-account yields split ord/pref/exempt.
  - NIIT calc + incremental attribution (F3): `taxableNII = min(nii, magiExcess)` correct; `ConsequenceDeltas = selected − noConversion` per channel — NIIT/IRMAA attributed INCREMENTALLY, not wholesale. Per-year ladder flags only the conversion-added surcharge.
  - Bracket-fill vs optimized distinction (F5): already 3 approaches (fillToBracket mechanical / recommendedTaxMin optimized / limitToIRMAA). (Optimizer quality = A1.)
- **REAL, added above:** A3 (gross-up IRMAA/ACA not recomputed, F6a), A4 (gross-up outflow not disclosed, F6b).
- **DISCLOSURE ENHANCEMENTS (valid, lower priority):**
  - F1: surface an all-in incremental MARGINAL RATE ("~28.6%"), not just per-channel $ deltas (all components already computed).
  - F4: show IRMAA tier-before → tier-after + the 2-year-lag year (currently shows incremental $ only).
  - F7: relabel chip "Fill ORDINARY income through the 22% bracket" (tooltip is already accurate).
- **Lesson (Claude): my live explanation to John was looser than the engine** — over-attributed the high AGI to "dividends on top," under-stated the incremental/classification precision the engine actually applies. Engine ≠ my paraphrase; verify before characterizing.

## H. Systematic invariant sweep (2026-07-13) — methodology + first results
John's ask: a systematic way to generate diverse profiles + check display-vs-engine consistency. Built a scratch sweep (deleted): 18 profiles (filing × age-band × trad-size × state × giving) × 4 approaches (taxMin/fill22/fill24/limitIRMAA2) = 72 runs, ~1650 profile-years, checking per-year invariants. RESULTS:
- **INV1 (conversion > available trad): 304 hits = B4, CONFIRMED WIDESPREAD + BROADER — fires on greedy `taxMin` too** (e.g. taxMin req $142k vs $101k available), not just runDeterministicLadder. B4 fix MUST cover BOTH the greedy OptimizationEngine path and the deterministic ladder.
- **INV3 (MAGI < AGI): 567 hits = A3 fingerprint.** `rec.magi`/`rec.irmaaMagi` use PRE-gross-up federalAGI (ProjectionEngine:995 "mirrors irmaaMagi; do NOT change to reportedAGI"); `rec.agi`=reportedAGI is POST-gross-up. The gap IS the gross-up withdrawal excluded from IRMAA/ACA/NIIT MAGI → A3 confirmed, affects ~1/3 of profile-years.
- **CLEARED as correct (0 violations):** INV6 conversion-caused IRMAA-tier breach (limit-to-IRMAA never adds a conversion that breaches — earlier "hits" were unavoidable baseline income above the tier); INV9 IRMAA oracle (independent recompute: per-person surcharge × enrolled count, 2-yr lookback — MATCHES displayed, so IRMAA arithmetic is right *given its MAGI*); negative balances; IRMAA-without-Medicare; negative taxable SS. Engine core arithmetic holds up.
- **Net:** the two hand-found bugs (B4, A3) are systematic but NOT the tip of an iceberg of different bugs (this invariant set found no third class). Methodology validated.
**PRODUCTIONIZE:** rebuild as `MultiYearInvariantTests` (asserting, fails on violation) AFTER B4/A3 are fixed — permanent regression net. **EXPAND invariants to hunt the next layer:** independent NIIT oracle; taxable-SS ≤ 85%×gross oracle; fill-bracket lands EXACTLY at top (undershoot); displayed-vs-executed conversion (B4 reporting leak); B2 nominal-vs-PV lifetime-tax check; independent state-tax oracle. Each new oracle = a new chance to catch a divergence.

## A5. Greedy "Minimize lifetime tax" optimizer is SUBOPTIMAL on its own objective — NEW (expanded sweep, 2026-07-13)
Expanded oracle sweep INV13: for 6/18 profiles, a fixed deterministic approach (fill-to-24% or limit-to-IRMAA) produces a LOWER `computeObjectiveCost` (PV in-horizon + PV terminal, the exact objective the greedy minimizes, heirWeight=0) than `recommendedTaxMin`. Worst: MFJ/age63/$6M/CA — fill24 obj $2.80M vs taxMin $3.24M = **taxMin is $442k (14%) WORSE**. Also age68/$6M/CA +$91k, age68/$1.8M/PA +$54k, others $6–14k. So "Minimize lifetime tax" can be beaten by "Fill to bracket" on the minimize objective's OWN terms. Ties to the runtime log `OptimizationEngine: hit iteration cap (2) without convergence` — greedy + 2-iteration cap doesn't converge.
**Distinct from A1** (A1 = objective optimizes the wrong THING / over-converts; A5 = optimizer doesn't even find the min of the objective it HAS) and **from B2** (B2 = nominal-vs-PV display; A5 is measured on the PV objective itself).
**Fix directions:** raise/remove the greedy iteration cap or add convergence; OR seed/compare the greedy against the deterministic ladders and keep the best; OR replace greedy with a stronger search. At minimum: after computing all approaches, "Minimize lifetime tax" should never be dominated by another approach on the objective — enforce/guard.

## INV2b. $500k annual conversion cap prevents filling higher brackets — MINOR
`upperBoundCap` (also the $500k limb of B4) caps conversions at $500k/yr, so "fill to 24/32/37%" can't reach those brackets for large IRAs (sweep: fill24 landed ordinary $386k, ~$17k short of the $403,550 24% top, with $5.5M still convertible). Fill-to-LOW-brackets is unaffected. Consider raising/removing the cap (or scaling it) when the target bracket is high and balance is ample.

## H2. Expanded sweep CLEARED (0 violations) — engine arithmetic verified sound
NIIT within 3.8%×(MAGI−threshold) bound + never charged at/under threshold; taxable SS never > 0 before claim age; IRMAA oracle (per-person surcharge × enrolled count, 2-yr lookback) matches displayed; no negative balances; no fill-to-bracket overshoot; no IRMAA-without-Medicare. So the NIIT/SS/IRMAA/balance calcs are sound — the real issues are B4 (phantom conversions), A3 (gross-up→MAGI), A5 (optimizer suboptimality).
