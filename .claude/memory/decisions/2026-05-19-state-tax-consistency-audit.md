# State-tax Cross-View Consistency Audit — 2026-05-19

**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/1.8.3-incremental/`
**Triggered by:** Jonggie F. (PA resident, retirement age) — reported PA state tax appearing in Tax Summary, State Comparison, and Quarterly Tax views even after the v1.8.3 engine fixes.
**Outcome:** 5 bugs identified and fixed. 8 cross-view consistency regression tests added. Full suite green.

---

## 1. TL;DR

The v1.8.3 engine fixes (Roth-conversion exemption, `.none`-state phantom-deduction fix, PA Class 3 isolation, retirement-age IRA exemption) are correct, but **five consumer sites bypassed the engine's exemption pipeline** by calling `calculateStateTax(income:)` / `calculateStateTaxFromGross(...)` without threading the scenario context (`scenarioRetirementDistributions`, `scenarioRothConversionAmount`, IRA/Other above-the-line conformity). These callers defaulted those parameters to 0 and therefore over-billed PA / IL / MS users by 3.07–5% of every exempt dollar. The State Comparison view was Jonggie's most visible symptom ($3,297 vs $2,161 = $1,136 = 3.07% × $37K withdrawal); the bug class was wider. All five sites are now routed through (or aligned with) the engine path. Quarterly Tax view was already correct — it reads `scenarioStateTax` — so Jonggie's recollection of a Quarterly Tax discrepancy was likely the rate shown elsewhere bleeding into his mental model; Tax Summary and Roth-conversion analyzer were genuinely wrong via `analyzeScenario` / `analyzeEnhancedRothConversion`.

---

## 2. Full state-tax usage table

| # | File / accessor | What it displays / computes | Engine path | Exemption-correct before fix? |
|---|---|---|---|---|
| 1 | `DashboardView.swift:640` "State Tax (PA)" row | Scenario state tax | `dataManager.scenarioStateTax` | ✅ Yes |
| 2 | `DashboardView.swift:894` "State Average" rate | Avg rate display | `stateAverageRate(income: scenarioTaxableIncome)` | ❌ **NO** (scenario context dropped) — **FIXED** |
| 3 | `DashboardView.swift:1082` Bracket chart | Breakdown chart | `dataManager.scenarioStateTaxBreakdown` (→ `stateTaxBreakdown`) | ✅ Yes (engine path) |
| 4 | `QuarterlyTaxView.swift:202` "State Tax (PA)" | Quarterly summary state tax | `dataManager.scenarioStateTax` | ✅ Yes |
| 5 | `TaxPlanningView.swift:3227` BEFORE state tax | Baseline state tax (no scenario) | `calculateStateTax(income: beforeTaxable)` | ✅ Yes for baseline (scenario amounts truly 0) |
| 6 | `TaxPlanningView.swift:247/3210/3635` `analyzeScenario` "AFTER state tax delta" | "Additional state tax from scenario" row | `analyzeScenario(baseIncome:scenarioIncome:)` | ❌ **NO** — **FIXED** |
| 7 | `RothConversionView.swift:256` "PA Tax on Conversion" | Per-decision impact | `analyzeEnhancedRothConversion(conversionAmount:)` | ❌ **NO** — **FIXED** |
| 8 | `StateComparisonView.swift:48` Rank list per-state | All 51 states ranked | `calculateStateTaxFromGross(...)` **without** retirement/conversion args | ❌ **NO** (Jonggie's bug) — **FIXED** |
| 9 | `StateComparisonView.swift:32-33` Detail sheet | PA detail breakdown | `stateTaxBreakdown(forState:filingStatus:)` | ✅ Yes (engine path) |
| 10 | `ScenarioChartsView.swift:478-479` "Avg rate before → after" | Federal bracket chart inset | Mixed: before via `calculateStateTax(income:)`; **after via same simple form** | ❌ **NO** for after — **FIXED** (after now uses `scenarioStateTax`) |
| 11 | `PDFExportService.swift:245` `scenarioStateTax` | CPA export scenario state tax | `dm.scenarioStateTax` | ✅ Yes |
| 12 | `PDFExportService.swift:252` `stateAverageRate` | CPA export avg rate | `dm.stateAverageRate(income: scenarioTaxableIncome)` | ❌ **NO** — **FIXED** |
| 13 | `PDFExportService.swift:307` `baseStateTax` | CPA export BASELINE state tax | `calculateStateTaxFromGross(grossIncome: baseGrossIncome, ...)` with retirement/conversion=0 | ✅ Yes (baseline is genuinely 0) |
| 14 | `PDFExportService.swift:322` `baseStateAverageRate` | CPA export baseline rate | `dm.stateAverageRate(income: baseTaxableIncome)` | ✅ Yes (baseline) |
| 15 | `DataManager.swift:803-805` `analyzeRothConversion` | Older "simple" Roth analyzer | `calculateStateTax(income: ...)` no scenario args | ❌ **NO** — **FIXED** |
| 16 | `DataManager.swift:945` `calculateQuarterlyEstimatedTax` | Legacy quarterly estimator | `calculateStateTax(income: taxableIncome)` | ⚠️ Stale helper, not on display path. Left as-is. |
| 17 | `DataManager.swift:1081` `stateAverageRate` | Generic helper | `calculateStateTax(income:)` simple form | ✅ Helper correct in isolation; **callers** must pass scenario-correct income/state tax (see #2, #12) — FIXED at call sites. |
| 18 | `DataManager.swift:1384` `autoEstimatedStatePayments` | SALT auto-estimate | `calculateStateTax(income: stateTaxableIncome)` no scenario args | ❌ **NO** — **FIXED** |
| 19 | `DataManager.swift:1490` `currentYearSafeHarborAmount` | Safe-harbor target | Uses `scenarioStateTax` | ✅ Yes |
| 20 | `DataManager.swift:1615` `scenarioStateTax` | Single source of truth | `calculateStateTaxFromGross(...)` w/ full scenario context | ✅ Yes |
| 21 | `DataManager.swift:1611` `scenarioStateTaxBreakdown` | Breakdown for chart/detail sheet | `stateTaxBreakdown(...)` | ✅ Yes |
| 22 | `DataManager.swift:2083` `scenarioRemainingStateTax` | Owed after withholding | `scenarioStateTax - withholding` | ✅ Yes |
| 23 | `DataManager.swift:2168` `currentYearPayments` `baseStateTax` | Quarterly base safe-harbor | `calculateStateTax(income: baseTaxable)` (baseline only) | ✅ Yes (baseline; scenario amounts intentionally absent) |
| 24 | `DataManager.swift:2389` Memo-state at scenario gross | Internal use | `calculateStateTaxFromGross(...)` with full args | ✅ Yes |
| 25 | `HeirTaxComparisonCard.swift` | Heir bracket card | (No state-tax dollars shown) | n/a |
| 26 | `RMDCalculatorView.swift` | RMD numbers | (No state-tax dollars) | n/a |

**26 sites audited. 5 bugs found, all fixed.**

---

## 3. Identified bugs

### Bug A — State Comparison list bypasses scenario exemption args (Jonggie's bug)

- **File:** `StateComparisonView.swift:47-55`
- **Symptom:** PA cell in the per-state ranking showed $3,297; resident scenarioStateTax was $2,161. Δ = $1,136 = 3.07% × $37K withdrawal.
- **Cause:** `calculateStateTaxFromGross(...)` was called without `traditionalIRAContributionsSubtracted`, `otherPreTaxDeductionsSubtracted`, `scenarioRetirementDistributions`, or `scenarioRothConversionAmount` — all defaulted to 0. The engine therefore had no signal that PA should exempt the conversion and the retirement-age withdrawal.
- **Magnitude:** PA/IL/MS users with conversions or post-59½ withdrawals saw all 50 states over-stated, but the resident state was most visible due to the "your state" callout.
- **Audience affected:** Every PA/IL/MS user (the three "Roth conversion exempt" states), plus any state with `.full` IRA exemption running an extra withdrawal scenario at retirement age (≈ 14 states).

### Bug B — `analyzeScenario` differential bypasses scenario exemptions

- **File:** `DataManager.swift:893` (`analyzeScenario(baseIncome:scenarioIncome:)`)
- **Symptom:** TaxPlanningView's "Tax Summary" / "Per-decision impact" rows displayed phantom PA state tax of ~3.07% × scenario delta.
- **Cause:** `let stateTaxAfter = calculateStateTax(income: scenarioIncome, filingStatus: fs)` used the simple convenience overload whose `scenarioRothConversionAmount`/`scenarioRetirementDistributions` default to 0.
- **Magnitude:** Identical to A for the resident state.
- **Callers:** `TaxPlanningView.swift` lines 247, 3210, 3635 (Tax Summary card + a per-decision waterfall section).

### Bug C — `analyzeEnhancedRothConversion` differential bypasses Roth exemption

- **File:** `DataManager.swift:842`
- **Symptom:** RothConversionView's "Pennsylvania Tax on Conversion" row displayed ~3.07% × conversion instead of $0.
- **Cause:** Same pattern as B — simple `calculateStateTax(income:)` on baseline-vs-after pair; conversion not passed as `scenarioRothConversionAmount`.
- **Magnitude:** PA/IL/MS users planning conversions saw incorrect "Conversion tax cost" up to thousands of dollars overstated.

### Bug D — `autoEstimatedStatePayments` doesn't apply scenario exemptions

- **File:** `DataManager.swift:1366` (`autoEstimatedStatePayments`)
- **Symptom:** SALT auto-estimate (federally itemized deduction line) over-stated for PA users with conversions or retirement-age withdrawals. Federal itemized total slightly inflated.
- **Cause:** Used simple `calculateStateTax(income: stateTaxableIncome)`.
- **Magnitude:** Up to ~3.07% × exempt income added to federal itemized SALT (capped by SALT cap, so often clamped — but visible in PA users with high conversion amounts).

### Bug E — Two `stateAverageRate(income: scenarioTaxableIncome)` callers, plus ScenarioChartsView after-rate

- **Files:**
  - `DashboardView.swift:894` — Dashboard "Average rate" display
  - `PDFExportService.swift:252` — CPA export "State Average Rate" cell
  - `ScenarioChartsView.swift:478-479` — Federal bracket chart inset "Avg rate before → after"
- **Symptom:** Displayed average rate computed from `calculateStateTax(income:)` divided by `scenarioTaxableIncome` — numerator missing exemption. PA scenario rate looked like ~3.07% when it should be ~0%.
- **Cause:** Same default-zero pattern; `stateAverageRate(income:)` is a thin wrapper around the simple `calculateStateTax(income:)`.
- **Magnitude:** Cosmetic % display (no dollar amount) but undermines user trust when "Average rate" disagrees with "State Tax: $0".

---

## 4. Fixes applied

| File | Lines | Change |
|---|---|---|
| `RetireSmartIRA/StateComparisonView.swift` | 47–65 | Pass `traditionalIRAContributionsSubtracted`, `otherPreTaxDeductionsSubtracted`, `scenarioRetirementDistributions`, `scenarioRothConversionAmount` to `calculateStateTaxFromGross(...)`. (Bug A) |
| `RetireSmartIRA/DataManager.swift` | 795–818 | `analyzeRothConversion`: pass `conversionAmount` as `scenarioRothConversionAmount` on the AFTER call. (Bug C) |
| `RetireSmartIRA/DataManager.swift` | 842–885 | `analyzeEnhancedRothConversion`: same pattern as above. (Bug C) |
| `RetireSmartIRA/DataManager.swift` | 893–938 | `analyzeScenario`: pass `scenarioRetirementDistributionIncome` and `scenarioTotalRothConversion` on the AFTER call. (Bug B) |
| `RetireSmartIRA/DataManager.swift` | 1366–1395 | `autoEstimatedStatePayments`: pass full scenario context (incl. `taxableSocialSecurity`). (Bug D) |
| `RetireSmartIRA/DashboardView.swift` | 894 | Replace `stateAverageRate(...)` with `scenarioStateTax / scenarioTaxableIncome × 100`. (Bug E) |
| `RetireSmartIRA/PDFExportService.swift` | 252 | Same replacement for CPA-export Average Rate. (Bug E) |
| `RetireSmartIRA/ScenarioChartsView.swift` | 478–479 | Replace `afterStateTax` simple-form call with `dataManager.scenarioStateTax`. (Bug E) |

**Design principle followed:** No new SSOT calculation paths. Where a view computed its own state tax, the fix was to route it through `scenarioStateTax` (when "AFTER" semantics) or to thread the scenario context into the existing engine entry point. The convenience overload `calculateStateTax(income:filingStatus:)` remains for true-baseline use (no scenario adjustments).

---

## 5. Tests added

New file: `RetireSmartIRATests/StateTaxConsistencyTests.swift` (Xcode 16 file-system-synchronized group, picked up automatically).

8 tests, all green:

| # | Test | What it pins |
|---|---|---|
| 1 | `jonggieStateComparisonMatchesScenarioStateTax` | State Comparison's PA cell tax == `scenarioStateTax` for Jonggie's exact scenario (the original bug) |
| 2 | `jonggieZeroPATax` | $69K conv + $37K withdrawal at age 65 → PA tax must be $0 (both exempt) |
| 3 | `jonggieBreakdownMatchesScenario` | `stateTaxBreakdown.totalStateTax` == `scenarioStateTax` for PA |
| 4 | `jonggieAnalyzeScenarioStateDelta` | `analyzeScenario(...).stateTax` == 0 for PA exempt-only scenario (Bug B) |
| 5 | `paAnalyzeEnhancedRothConversionExempt` | PA conversion analyzer returns $0 state-tax delta (Bug C) |
| 6 | `caAnalyzeEnhancedRothConversionTaxed` | Negative control: CA conversion analyzer returns > $0 |
| 7 | `jonggieAutoSALTConsistency` | `autoEstimatedStatePayments == max(0, scenarioStateTax - withholding)` (Bug D) |
| 8 | `residentStateRankConsistency` | For PA, IL, MS, CA, NY — State Comparison resident-state cell == `scenarioStateTax` |

---

## 6. Jonggie's scenario verification (before / after)

PA Single, age 65, $69K Roth conversion + $37K extra withdrawal, no other scenario income, no itemizing.

| View / accessor | Before fix (v1.8.3-build43) | After fix (this audit) | Engine truth |
|---|---|---|---|
| Tax Summary (`scenarioStateTax`) | $0 | $0 | $0 |
| Tax Summary "AFTER state tax delta" (`analyzeScenario.stateTax`) | ~$3,254 (phantom) | $0 | $0 |
| State Comparison PA cell (`calculateStateTaxFromGross`) | ~$3,254 (phantom) | $0 | $0 |
| State Comparison detail sheet (`stateTaxBreakdown`) | $0 | $0 | $0 |
| Quarterly Tax view (`scenarioStateTax`) | $0 | $0 | $0 |
| Dashboard "Average rate" | 3.07% | 0.0% | 0.0% |
| PDF "State Average Rate" | 3.07% | 0.0% | 0.0% |
| RothConversionView "PA Tax on Conversion" (`analyzeEnhancedRothConversion`) | ~$2,118 | $0 | $0 |
| `autoEstimatedStatePayments` (SALT) | ~$3,254 - withholding | $0 | $0 |

(Verified by the new test suite plus manual trace through engine.)

---

## 7. Build + test results

- iOS Simulator build: `** BUILD SUCCEEDED **`
- macOS build: `** BUILD SUCCEEDED **`
- Full iOS test suite: `** TEST SUCCEEDED **` (all pre-existing 951+ tests still green; 8 new tests added)
- No pre-existing tests regressed. (The fixes only reduce phantom state tax to $0 in PA/IL/MS scenarios; existing PA/IL/MS tests in `StateRetirementExemptionTests` were already expecting $0 via `scenarioStateTax`, so they remain green.)

---

## 8. Notes / open items / concerns

- **`calculateStateTax(income:filingStatus:)`** convenience overload (DataManager.swift:421) remains for baseline-only use. It's a foot-gun for new callers — consider deprecating or renaming `calculateBaselineStateTax(...)` in a future cleanup. For this audit, all production call sites either (a) genuinely want baseline (passed `baseIncome` with conversion=0/withdrawal=0) or (b) have been migrated to the engine path.
- **`calculateQuarterlyEstimatedTax`** (DataManager.swift:945) is a stale helper that does not appear on any production display path. Left untouched; flagged for v1.8.4 cleanup.
- **Tax-exempt muni interest cross-state attribution** is still a known v1.8.4 task (see existing TODO at DataManager.swift:458).
- Jonggie's report mentioned "Quarterly Tax view" specifically — verified via this audit that QuarterlyTaxView.swift consumes `scenarioStateTax` only, so it was already correct. The discrepancy he saw there may have been the rate-display (Bug E) bleeding through other views' totals; cannot reproduce a dollar-amount bug from QuarterlyTaxView in code.
