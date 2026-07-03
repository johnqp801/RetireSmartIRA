# Multi-Year Positioning / Copy Refinement — Design Spec

**Date:** 2026-06-30
**Branch:** `2.0/heir-objective` (worktree `.worktrees/2.0-reconcile-engine`)
**Status:** Design approved (brainstorm). Next: implementation plan via writing-plans.

## Problem

The Multi-Year tab states its outputs as definitive advice ("Recommended conversions,"
"This plan saves $X") and two of its honest-scope disclosures are now factually wrong after
the taxable-accounts feature shipped. For a credibility-first product the overclaim is a
churn risk for the sophisticated user; the stale disclosures both mislead and undersell the
engine. This is a copy/correctness refinement only: no engine or logic changes.

## Decisions (from brainstorm)

- **Posture:** keep the "Multi-Year Plan" name; soften the claims. (Not renaming to "Explorer.")
- **Scope:** in-app copy only. App Store listing copy is a separate future pass.
- **Wording:** "Recommended" -> "Modeled" (descriptive, not advice); add "under these
  assumptions" to the two prominent dollar-value sentences only (not every sentence).

## Change set

All changes are user-facing strings. No types, signatures, or logic change.

### A. Soften "Recommended" -> "Modeled"

- `RetireSmartIRA/ConversionLadderChartView.swift:9`
  - FROM: `Text("Recommended conversions by year")`
  - TO:   `Text("Modeled conversions by year")`
- `RetireSmartIRA/MultiYearPlanSections.swift:101` (LadderListView)
  - FROM: `Text("Recommended ladder")`
  - TO:   `Text("Modeled conversion ladder")`

Leave the neutral comparison title `"Your plan vs. doing nothing"` (MultiYearPlanSections.swift:62)
unchanged — it is a comparison label, not a claim.

### B. Add "under these assumptions" to the two headline dollar claims

- `RetireSmartIRA/PlanComparison.swift:99` (savings sentence)
  - FROM: `"This plan saves \(...) in lifetime tax and holds your largest forced RMD to \(rmd)."`
  - TO:   `"Under these assumptions, this plan saves \(...) in lifetime tax and holds your largest forced RMD to \(rmd)."`
- `RetireSmartIRA/TaxImpactChartView.swift:10` (cumulative-tax caption)
  - FROM: `"Your plan pays more tax early, then comes out ahead by about \(...) over the horizon."`
  - TO:   `"Your plan pays more tax early, then comes out ahead by about \(...) over the horizon, under these assumptions."`

Leave `PlanComparison.swift:96` ("This plan comes out about even with doing nothing here.")
unchanged — it already hedges. `PlanSummary.swift:37` already says "under these assumptions"
in its no-conversions branch (precedent for the phrasing).

### C. Refresh `V2Disclosures` (correctness) — `RetireSmartIRA/V2Disclosures.swift`

`positioning` — add taxable-account interactions to the evaluated list:
- TO: `"RetireSmartIRA helps you evaluate multi-year Roth conversions, RMDs, IRMAA, ACA cliffs, survivor tax effects, taxable-account interactions, and heir-tax outcomes using transparent assumptions."`

`limitations` array — new contents (order matters for the CPA PDF parity):
1. (REWRITE, was "no lot-level cost basis... not separately rate-tiered")
   `"Taxable-account sales use an average cost-basis estimate, not lot-level tax-lot selection or short-term versus long-term holding periods."`
2. (KEEP) `"Withdrawal order follows the assumption you select; the app does not optimize the order across accounts."`
3. (KEEP) `"Inherited taxable accounts are credited at a stepped-up cost basis, passing to heirs nearly tax-free."`
4. (KEEP) `"Growth sensitivity is a deterministic high and low band, not a Monte Carlo probability of success."`
5. (KEEP) `"The survivor scenario applies single-filer rates from the start of the horizon, a conservative upper bound."`
6. (ADD) `"Wages, pension, and investment income are entered as steady annual amounts; income that starts or stops mid-horizon is not yet modeled."`

REMOVED: the muni item ("Tax-exempt municipal interest is excluded from MAGI...") — muni is
now included in MAGI, so the statement is false.

### D. Add an "inputs used" line — `V2Disclosures` + `AssumptionsLimitationsView`

Add to `V2Disclosures`:
```swift
/// What the plan reads, shown in the "What this plan covers" panel and the CPA PDF.
static let inputsUsed =
    "This plan uses your IRA, Roth, and inherited-IRA balances, taxable accounts, Social Security, income, deductions, expenses, growth assumptions, IRMAA and ACA thresholds, and legacy settings."
```
Render it in `AssumptionsLimitationsView` as a secondary line beneath the positioning line
(e.g., a `Text(V2Disclosures.inputsUsed).font(.caption).foregroundStyle(.secondary)` under
the existing `Text(V2Disclosures.positioning)`).

## Testing

- No logic change, so behavior tests are unaffected.
- `V2Disclosures` is synced to the CPA briefing PDF. The implementation MUST grep for any test
  asserting `V2Disclosures.limitations` content/count or the muni/cap-gains strings (e.g.,
  MultiYearCPABriefing tests) and update expectations to the new list. The full suite must stay
  green (currently 1152).
- A build (macOS) confirms the string edits compile.

## Out of scope

- Renaming the tab/feature to "Explorer."
- App Store listing / marketing copy (separate pass).
- Any engine, optimizer, or layout change.

## No em dash characters in any added copy.
