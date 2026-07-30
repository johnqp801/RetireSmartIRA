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

### B2. "Minimize lifetime tax" shows a HIGHER "Lifetime tax" than "Fill to bracket" — CONFIRMED + REPRODUCED 2026-07-14 (display-only, NOT an optimizer bug)
**2026-07-14 reproduction (John's macOS 2.1.1 screenshot: fill-24 $1.8M vs Minimize $2.3M "lifetime tax"):** built a repro harness (MFJ/63/$3M trad/$300-350k existing ordinary income so fill-24 has little headroom and leaves a residual IRA). Confirmed DEFINITIVELY: **Minimize CORRECTLY minimizes its objective** — `min.totalObjectiveCost` < `fill24.totalObjectiveCost` in every case (e.g. min $2,790,798 vs fill24 $3,243,402). The paradox is 100% the DISPLAY: "Lifetime tax" (`ApproachColumn.lifetimeTaxPV`) = in-horizon PV tax PAID only; fill-24 leaves a big residual traditional IRA ($3.5M in repro / $1.0M on John's screen) whose deferred tax the column never shows, so fill-24 looks cheaper. Minimize drains → pays it in-horizon → looks higher. NOT A5 (Minimize is not dominated on its objective; the `!greedyConverged` gate is fine — do NOT change it for this). Heirs-keep is a rounding-level near-tie on small households; in controlled repros Minimize leaves heirs MORE (at heirWeight 0 the optimizer targets owner tax + self-liquidation, not heir wealth — that's the heir slider's job).
**FIX CHOSEN (John, 2026-07-14): add a "deferred tax on remaining IRA" ROW** — keep "Lifetime tax" = tax paid in-horizon, add a row showing the estimated future tax on each approach's leftover traditional (so the hidden liability is visible next to the paid tax). (Supersedes the old "show PV" fix note — PV is already shown; the gap was the terminal/deferred tax.)
**✅ FIXED 2026-07-14 (branch `fix/multiyear-state-tax-heir-frontier`).** New `PlanPathMetrics.deferredTaxOnRemainingTraditional` = the heir tax already folded into `heirsKeep` (so gross ending wealth − deferred tax reconciles EXACTLY to heirsKeep, by construction — `heirsKeep` refactored to reuse it). New `ApproachColumn.deferredTaxOnRemainingIRA` field; new "Deferred tax on remaining IRA" row in `ApproachComparisonView` directly under "Lifetime tax", scaled by `terminalPVFactor` in PV mode like the other terminal figures. TDD: RED `ApproachComparisonTests.deferredTaxOnRemainingIRA` (residual-IRA no-conv path → deferred tax > 0 AND grossEnding − deferredTax == heirsKeep) → GREEN. Full macOS suite green (1,347 Swift Testing + 503 XCTest, 0 fail). NOT committed. FOLLOW-UP (optional): surface the same deferred-tax line in the CPA briefing export (`MultiYearCPABriefing`) for parity.

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

## I. State-tax multi-year gaps (2026-07-14, iPad screenshot audit — Bob/Sue MFJ ~$1.83M trad + $2.3M taxable)

Audit reconciled against existing items: this session independently CONFIRMED A1/A2 (over-convert-but-correct, high-AGI-is-portfolio-throwoff), A5 (frontier dominance), and B2 (minimize-shows-higher-tax). The three items below are NEW / not previously logged.

### I1. PA/IL/MS Roth-conversion exemption DROPPED in multi-year `computeStateTax` — ✅ FIXED 2026-07-14 (branch `fix/multiyear-state-tax-heir-frontier`, off `main` @ 4cda6be)
**Fix landed:** added `explicitRothConversions` param to `computeStateTax` and forwarded it as `scenarioRothConversionAmount` (withholding 0 — multi-year uses gross-up) at all 3 call sites (main + 2 incremental-gain recomputes). TDD: RED `ProjectionEngineTests.paConversionExemptFromMultiYearStateTax` (PA 62 converting $100k → state tax $3,070 = 3.07%×$100k) → GREEN ($0). Full macOS suite green (1,346 Swift Testing + 503 XCTest = 1,849, 0 fail). NOT yet committed/merged as of 2026-07-14 (awaiting John's go on commit + release-build decision). Original finding below.

For a PA resident 59½+ (Bob 62), PA does not tax Roth conversions, so correct PA state tax on the conversions is ~$0. But the multi-year path taxes the FULL conversion at PA 3.07%. Screenshot showed "+$82k State" ($82k ÷ 0.0307 ≈ $2.67M of conversions taxed). Root cause: `ProjectionEngine.computeStateTax` (`ProjectionEngine.swift:1294-1335`) calls `TaxCalculationEngine.calculateStateTax` WITHOUT `scenarioRothConversionAmount`/`scenarioRothConversionWithholdingAmount` (default 0), so PA's exemption at `TaxCalculationEngine.swift:667-670` subtracts nothing. Single-year passes them correctly (`DataManager.swift:1043` etc.). Also affects the incremental-gain recomputes at `ProjectionEngine.swift:870-874` and `935-938`. Same-shape miss would hit IL and MS (the other two states in the conversion-exemption switch, `TaxCalculationEngine.swift:667-675`). **Not display-only:** `taxBreakdown.total` feeds the optimizer objective, so PA/IL/MS conversions are over-penalized → optimizer may under-recommend converting; and the "Total −$94k" plan-vs-nothing delta should be ~−$176k. **Does NOT cancel in the convert-vs-noConvert delta** (conversion-specific). CA/NJ verified separately (CA: no error — CA taxes conversions correctly; NJ: pending).
**Fix:** add an `explicitRothConversions` (+ withholding, 0 in no-withhold plans) parameter to `computeStateTax` and forward it at the `calculateStateTax` call (`ProjectionEngine.swift:1324`); caller at `:704` already has it in scope; apply at the two incremental-recompute sites too.

### I2. Multi-year `computeStateTax` drops the pre-`calculateStateTax` state adjustments the single-year path applies — NEW, LOW, flat-per-year
Generalized across CA + NJ audits (2026-07-14): the multi-year `computeStateTax` (`ProjectionEngine.swift:1294-1335`) omits `postExemptionDeduction` and the AGI add-backs the single-year `DataManager` computes before calling `calculateStateTax`. Concretely dropped:
- **State standard deduction** (states with `.fixed`/`.standard` `stateDeduction`, e.g. CA `.fixed(married: 11_412)` `StateTaxData.swift:1042`; applied single-year at `DataManager.swift:655`). CA MFJ ≈ **$1,050–1,175/yr** overstatement.
- **NJ personal exemption** (`$2,000` MFJ both <65, +$1,000/filer at 65; single-year passes it as `postExemptionDeduction` at `DataManager.swift:649-656`; multi-year defaults it to 0). NJ ≈ **$127–179/yr** now (→ ~$255–359/yr once both 65).
- **HSA add-back** (`hsaContributionsTaxableForState`, e.g. NJ; single-year `DataManager.swift:585`). $0 for a retired couple not contributing to an HSA — structural only.
All are non-conversion-specific → largely CANCEL in the convert-vs-noConvert delta, so LOW priority. (PA has `stateDeduction: .none` and no personal exemption, which is why only I1 surfaced there.) Related to E9 (local tax dropped multi-year).
**Fix:** compute the state standard deduction / personal exemption per year and pass them via `postExemptionDeduction` into `calculateStateTax` (mirror `DataManager.swift:649-656`), and re-add HSA for `hsaContributionsTaxableForState` states.

**Cross-state conversion verdict (2026-07-14, all three audits):** the conversion-specific state-tax bug (I1) is UNIQUE to PA (and would hit IL/MS) — the dropped `scenarioRothConversionAmount` defeats a real conversion exemption. **CA and NJ correctly tax conversions** (no exemption keys off that argument, so it's inert), and NJ's heavy retirement machinery (SS exclusion, pension/IRA combined exclusion + $100k cap + $150k stepped-cliff phaseout, Worksheet D) IS correctly applied in multi-year because it lives inside the shared `applyRetirementExemptions`. So I1 = PA/IL/MS only; I2 = all fixed-deduction / personal-exemption states.

### I3. Heir frontier λ>0 points NOT de-dominated → backwards/dominated frontier + self-contradicting narrative — ✅ ENGINE FIXED 2026-07-14 (same branch `fix/multiyear-state-tax-heir-frontier`); narrative-headline reconciliation still TODO
**Fix landed (engine):** removed the `guard heirWeight == 0 else { return greedy }` at `OptimizationEngine.swift:654` so `keepBestOfCandidates` de-dominates EVERY frontier weight (the `!greedyConverged` perf gate stays, so only non-convergent points pay the candidate cost). TDD: RED `HeirObjectiveTests.taxMinNotDominatedAtPositiveHeirWeight` (MFJ/63/$6M/CA at w=0.10: greedy obj $2.466M dominated by fill-to-32% $2.336M, ~$123k/5% worse) → GREEN. Task6 (previously only endpoint-checked, comment admitted intermediate "wiggle") still passes. Full macOS suite green (1,849, 0 fail). **STILL TODO (display, not engine):** verify the narrative headline (`HeirFrontierPresentation.swift:75-93`, endpoint λ1-vs-λ0) now agrees with the table rows now that the frontier is monotone; reconcile if it can still contradict. NOT yet committed/merged. Original finding below.

"Owner vs heirs tradeoff" shows leaning toward heirs making BOTH axes worse: "Optimize for you" $653k tax / $10.4M heirs vs "10% toward heirs" $831k / $6.6M — a dominated point, impossible on a real efficient frontier. Root cause: the A5 `keepBestOfCandidates` de-domination fix is GATED by `guard heirWeight == 0 else { return greedy }` (`OptimizationEngine.swift:654`). So ONLY the λ=0 "Optimize for you" endpoint gets de-dominated; every λ>0 frontier point (`HeirFrontierCoordinator.presetWeights = [0,0.10,0.25,0.50,0.75,1.0]`, `HeirFrontierCoordinator.swift:15`) returns raw greedy, which the code's own comments call 14–28% worse on ~1/3 of profiles. Frontier is non-monotonic in λ. SECONDARY: the narrative headline (`HeirFrontierPresentation.swift:75-93`) compares only the ENDPOINTS (λ=1 vs λ=0 → "+$16k, no material heir change") while the table renders the dominated λ=0.10 row (+$178k, −$3.8M) — card contradicts itself.
**Fix:** remove the `heirWeight == 0` gate at `OptimizationEngine.swift:654` so `keepBestOfCandidates` de-dominates every frontier point under its own λ-weighted objective (candidate scoring at `:681-690` already threads `heirWeight`). Perf: 12 ladders × 6 points — the gate exists purely for frontier cost (comment `:637-638`), so it's a perf/correctness tradeoff, not modeling. Then reconcile the endpoint-based headline with the worst displayed row. This is the frontier-specific completion of A5.

## H2. Expanded sweep CLEARED (0 violations) — engine arithmetic verified sound
NIIT within 3.8%×(MAGI−threshold) bound + never charged at/under threshold; taxable SS never > 0 before claim age; IRMAA oracle (per-person surcharge × enrolled count, 2-yr lookback) matches displayed; no negative balances; no fill-to-bracket overshoot; no IRMAA-without-Medicare. So the NIIT/SS/IRMAA/balance calcs are sound — the real issues are B4 (phantom conversions), A3 (gross-up→MAGI), A5 (optimizer suboptimality).

### B5. CPA PDF "Lifetime tax" is NOMINAL while the on-screen row is PV — NEW (found 2026-07-14 while writing the display-audit Stage-0 spec)
Same label ("Lifetime tax"), two different bases across two surfaces: the on-screen approach-comparison row shows present value (`ApproachUILogic.displayedLifetimeTax` → `lifetimeTaxPV`), but `MultiYearCPABriefing` prints the nominal undiscounted sum for the same label. A user comparing the app to the exported CPA report sees two different numbers for "Lifetime tax." Adjacent to B2 (nominal-vs-PV). Fix: make the CPA report label/basis consistent with the on-screen row (show PV, or label both explicitly). Surfaced by the audit harness Stage-0 spec pass — exactly the class of thing the harness is meant to institutionalize.
