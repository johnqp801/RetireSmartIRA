# Plan-vs-Nothing Explainability Block - Design

**Date:** 2026-06-26
**Status:** Approved (brainstorming complete)
**Branch:** `2.0/heir-objective` (worktree `.worktrees/2.0-reconcile-engine`)

## Problem

The Multi-Year Plan tab recommends aggressive Roth-conversion ladders that, for large
traditional balances, drive AGI to $500k–$800k for years on end. A diagnostic on the
canonical saved scenario ($5.6M traditional, MFJ, age 71, 8% growth, $0 taxable) confirmed
these recommendations are **PV-correct**, not artifacts: converting hard saves ~$1.9M of
lifetime tax versus never converting, because the un-converted IRA balloons to ~$8.1M and
forces large RMDs taxed at top brackets.

But the recommendation is presented with no justification. A user (and the project owner)
looking at "convert $200k/yr, AGI $600k" reads it as reckless, because the *cost* is visible
and the *benefit* is invisible. The fix is explanation, not changing the math: show, next to
the ladder, what the plan buys versus doing nothing.

## Goal

Add a "Your plan vs. doing nothing" comparison block to the Multi-Year Plan tab that makes the
benefit of the recommended ladder concrete and believable, using the no-conversion baseline the
engine already computes.

## Non-Goals (v1 - logged as follow-ups)

- No PV / "Today's $" toggle on the comparison numbers (plain dollars, matching the existing
  "Your plan" summary).
- No per-year "why this conversion" annotations on ladder rows.
- No charts/graphs.

## Architecture

Data already present:

- `MultiYearStrategyManager` publishes `baselineProjection: [YearRecommendation]?` (the
  no-conversion path) and `currentResult` / `engineOptimalResult` (the recommended path). The
  baseline is computed but never displayed.
- The heir after-tax calc already exists:
  `LegacyPlanningEngine.heirTaxOnInheritedTraditional(balance:heirSalary:heirFilingStatus:drawdownYears:)`.
  The frontier computes "heirs keep" as `terminalRoth + (terminalTrad - heirTax)`
  (`HeirFrontierCoordinator.swift:40-47`).

Three units, each with one responsibility:

1. **`YearRecommendation.rmd: Double`** - the engine surfaces the forced RMD for each year as
   its own field, instead of leaving it bundled inside the year's `.traditionalWithdrawal`
   actions (which also carry gross-up and expense withdrawals). Default `0` for back-compat,
   matching the `underfunded` field pattern. Populated by `ProjectionEngine` where the RMD is
   already computed internally.

2. **`PlanComparison`** - a pure value type. Input: the recommended path, the baseline path, and
   the heir inputs (heirSalary, heirFilingStatus, heirDrawdownYears). Output: four labeled
   metric pairs `(plan: Double, doingNothing: Double)`. No UI, no engine calls beyond the
   existing `LegacyPlanningEngine` heir function. Fully unit-testable.

3. **`PlanComparisonSection`** - a SwiftUI view that renders a `PlanComparison` as a two-column
   ("Your plan" | "Doing nothing") block with a one-line headline. Dumb view; all numbers come
   from the `PlanComparison`.

## The Four Metrics

Each is a `(plan, doingNothing)` pair. `plan` is derived from `recommendedPath`;
`doingNothing` from `baselineProjection`.

| Metric | Definition |
|---|---|
| **Lifetime tax** | `path.reduce(0){ $0 + $1.taxBreakdown.total }` - in-horizon income tax over the path. Matches the existing "Projected lifetime tax" label. |
| **Ending IRA balance** | `path.last.endOfYearBalances.primaryTraditional + .spouseTraditional` - pre-tax traditional remaining at the horizon end. Makes the RMD bomb concrete. |
| **What heirs keep** | `terminalRoth + (terminalTrad - heirTax)`, where `heirTax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(balance: terminalTrad, heirSalary:, heirFilingStatus:, drawdownYears:)`. Same formula the frontier uses; applied to each path's terminal balances. |
| **Peak forced RMD** | `path.map(\.rmd).max() ?? 0` - the largest single-year required minimum distribution. Honestly isolates FORCED income, so the plan (smaller IRA → smaller RMD) always compares favorably. |

Note on "peak forced RMD": total AGI is deliberately NOT used, because the plan's voluntary
conversion years carry high AGI too - peak AGI would make the plan look worse, inverting the
message. RMD is the forced component, and that is what the plan reduces.

## Data Flow

```
ProjectionEngine.project()
   └─ sets YearRecommendation.rmd per year (already computes the value)
MultiYearStrategyManager
   ├─ recommendedPath  (currentResult.recommendedPath)
   └─ baselineProjection  (no-conversion path)
        └─ PlanComparison(plan: recommendedPath, doingNothing: baselineProjection, heir inputs…)
              └─ PlanComparisonSection renders the four pairs + headline
```

The section appears only when both `recommendedPath` and `baselineProjection` are available
(i.e. after a full optimal recompute). When the baseline is absent, the section is hidden.

## Headline

One line above the table, e.g.:
"This plan saves ~$1.9M in lifetime tax and keeps your largest forced RMD under $X."
Derived from the lifetime-tax delta and the plan's peak-RMD value. Wording finalized during
implementation; values come from `PlanComparison`.

## Error / Edge Handling

- **No baseline yet:** section hidden (guarded on `baselineProjection != nil`).
- **Empty paths:** `PlanComparison` returns zeros; section hidden if the plan path is empty.
- **Plan ≈ baseline (no conversions recommended):** deltas near zero. Acceptable - the block
  honestly shows "doing nothing is about the same here," which is correct for low-balance users.
- **Negative savings:** not expected (the optimizer minimizes the objective), but the view must
  render a negative or zero delta without breaking layout; no special-casing of sign beyond display.

## Testing

- `ProjectionEngine`: `rmd` is populated and equals the expected RMD for a known RMD-age
  scenario; `0` before RMD age.
- `PlanComparison`: given a hand-built plan path and baseline path with known terminal balances
  and per-year tax, the four metric pairs match expected values; peak-RMD selects the max year.
- Heir metric: `PlanComparison`'s "what heirs keep" matches a direct call to
  `LegacyPlanningEngine.heirTaxOnInheritedTraditional` on the same terminal balances.
- Back-compat: existing `YearRecommendation` constructions compile with `rmd` defaulted.

## File Structure

- Modify: `RetireSmartIRA/YearRecommendation.swift` (add `rmd`)
- Modify: `RetireSmartIRA/ProjectionEngine.swift` (populate `rmd`)
- Create: `RetireSmartIRA/PlanComparison.swift`
- Create: `RetireSmartIRA/PlanComparisonSection.swift` (or add to `MultiYearPlanSections.swift`
  if that file is the established home for these sections)
- Modify: `RetireSmartIRA/MultiYearPlanView.swift` (render the section under the summary)
- Tests: `RetireSmartIRATests/PlanComparisonTests.swift`, plus an `rmd`-population test in the
  ProjectionEngine test suite.
