# 1.9 Task 3 — MetricCard Component Sweep

**Status:** Approved (2026-04-30)
**Author:** John Urban (with brainstorm collaboration)
**Date:** 2026-04-30
**Target release:** RetireSmartIRA 1.9
**Related docs:**
- `docs/1.9-roadmap.md` — Task 3 entry
- `docs/superpowers/specs/2026-04-25-color-system-design.md` §4 — `MetricCard` component definition (1.8)
- `docs/superpowers/plans/2026-04-25-color-system.md` — 1.8 plan, including per-screen "decline-to-swap" judgment calls

---

## 1. Overview

Task 3 of the 1.9 roadmap was framed as "audit Dashboard / TaxPlanning / RMD / Legacy / Quarterly / SS / Accounts for ad-hoc card patterns that should be `MetricCard`." A pre-brainstorm audit (done by an Explore subagent on 2026-04-30) found that the *actual* technical debt is much narrower than that framing suggested:

- **1 HIGH-confidence swap** (clean MetricCard fit)
- **~3 MEDIUM-confidence swaps** that need straightforward adaptation
- **10+ LOW-confidence cards** that should remain ad-hoc — they have features `MetricCard` doesn't and shouldn't support: charts, multi-row breakdowns, side-by-side comparisons, interactive controls.

The 1.8 "decline-to-swap" calls were not lazy — they reflected real semantic mismatches. The narrow swap below clears the actual debt; the LOW cards get inline comments so future readers don't re-litigate them.

### Scope discipline

**In scope:**
- Swap 3 specific cards to `MetricCard` (with documented adaptation strategies for the multi-value cases)
- Add inline `// Intentionally ad-hoc: <reason>` comments to 7 specific LOW-confidence cards
- Manual visual verification of all affected screens in light + dark mode
- Single branch, single PR

**Out of scope:**
- Expanding `MetricCard`'s API to support multi-value, range, or comparison patterns (rejected during brainstorm — keeps the component narrow)
- New canonical card components (`CompositeCard`, `ComparisonCard`, `StatusCard`) — also rejected; the views legitimately need different patterns and forcing them into a single component family adds complexity without value
- Snapshot test coverage of the affected screens (Pass 2 of snapshot testing handles this; Task 3 doesn't depend on it)
- Any structural refactor of the affected views beyond the card swaps

**Estimated scope:** ~1-2 hours of focused work, single PR.

---

## 2. The three swaps

### Swap 1: `IncomeSourcesView` "Total Annual Income"

**Location:** `RetireSmartIRA/IncomeSourcesView.swift` lines ~21-34

**Current:** Ad-hoc card with VStack containing label "Total Annual Income" + a single currency value (sum of all income sources).

**After:** Single `MetricCard(label: "Total Annual Income", value: <formatted>, category: .informational)`.

**Visual change:** Adds the 4pt brand-teal top stripe; otherwise visually identical.

**Risk:** Trivial. Pure label + value display.

### Swap 2: `AccountsView` "Total IRA Balance"

**Location:** `RetireSmartIRA/AccountsView.swift` lines ~19-65

**Current:** Single ad-hoc card with a 3-column layout: Traditional balance | Roth balance | Inherited balance, each with its own label and currency value.

**After:** `HStack(spacing: Spacing.sm)` of 3 separate `MetricCard`s — one per balance type. Each card stands alone with its own label and value.

**Visual change:** The 3 values become 3 visually distinct cards (each with its own brand-teal top stripe and white surface) instead of a single multi-column card. This is a meaningful visual shift — the cards will read as 3 metrics rather than 1 metric with 3 components. Argument for: each value IS independent; the three balances are tracked separately, sourced from different data, and have different contextual meaning.

**Risk:** Medium-low. Visual parity with the prior design isn't perfect, but the new design is more honest about the data structure.

### Swap 3: `DashboardView` headerCard

**Location:** `RetireSmartIRA/DashboardView.swift` lines ~133-207

**Current:** Single ad-hoc card displaying 4 separate metrics: "2026 Tax Year" (year), primary user age, spouse age, RMD status.

**After:** Replace with a flexible layout (probably `HStack` or `LazyVGrid` depending on screen width handling already in DashboardView) of 4 `MetricCard`s — one per metric.

**Decisions:**
- Year metric: `MetricCard(label: "Tax Year", value: "2026", category: .informational)`
- Primary age: `MetricCard(label: "<Name>'s Age", value: "<age>", category: .informational)`
- Spouse age (if MFJ + spouse exists): same pattern as primary
- RMD status: depends on current display.
  - If "Required" / "Not yet required" today, MetricCard with `.informational` for both states (RMD status is a fact, not an alert; per the color-system spec amber is reserved for time-sensitive deadlines).
  - If a deadline is shown ("RMD due Dec 31"), MetricCard with `.actionRequired` and amber delta text.

**Visual change:** Header becomes 4 cards in a row (or wrapped grid on narrow widths) instead of 1 multi-metric card. Subjectively cleaner; objectively a denser visual signal because each metric gets its own surface.

**Risk:** Medium. The headerCard is the first thing the user sees on the dashboard, so a layout regression here is high-visibility. Manual visual check is mandatory.

---

## 3. The seven decline-to-swap comments

For each card below, add a short inline comment immediately above the card's view definition, in this format:

```swift
// Intentionally ad-hoc: MetricCard doesn't fit — <reason>.
// See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
```

| # | File | Approx. lines | Card | Reason |
|---|---|---|---|---|
| 1 | `AccountsView.swift` | ~140-220 | `AccountRow` | List-row context with multiple inline badges (owner, beneficiary, account type). MetricCard is for standalone metrics, not list items. |
| 2 | `LegacyImpactView.swift` | ~154-202 | `painVsGainHeader` | Side-by-side comparison ("Cost Today" vs "Family Gain") with arrow visual. MetricCard is single-value; the comparison structure is the whole point. |
| 3 | `TaxPlanningView.swift` | ~2515-2670 | `scenarioSummaryCard` | Multi-row tax breakdown with conditional sections (deduction status, before/after columns, tax impact). Detailed analysis card, not a metric. |
| 4 | `TaxPlanningView.swift` | ~584-663 | `deductionComparisonCard` | Standard vs Itemized side-by-side comparison with checkmarks. Comparison structure is the point. |
| 5 | `QuarterlyTaxView.swift` | ~174-284 | `annualTaxSummary` | Detailed tax line-item breakdown with multiple rows and dividers. A summary table, not a metric card. |
| 6 | `SocialSecurityPlannerView.swift` | ~191-364 | `statusCard` | Interactive multi-state benefit-status display with conditional buttons (claim entry, edit benefit). MetricCard is read-only and single-state. |
| 7 | `QuarterlyTaxView.swift` | ~601-750 | `safeHarborCard` | Interactive picker control + detailed explanation table. Control card, not metric card. |

The comment placement should be high-visibility (immediately above the `var <name>Card: some View` declaration or equivalent).

### Deferred candidate

`QuarterlyTaxView.swift` "Per Quarter Payment" / "Quarterly Range" display (~lines 226-251 within annualTaxSummary) is a MEDIUM candidate where MetricCard *could* fit with the range expressed as a delta string ("$X – $Y"), but the range UX deserves its own treatment and snapshot coverage before changing it. Add this comment instead:

```swift
// Candidate for MetricCard swap — range UX deserves its own treatment first.
// Revisit after Pass 2 snapshot tests cover this screen.
// See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
```

---

## 4. Verification

### Tests

- All 670+ pre-existing behavior tests must still pass.
- The 1.8 component behavior tests for `MetricCard` (`MetricCardTests.swift`) verify the canonical component is correct. The swaps don't change `MetricCard.swift` itself, so those tests should pass unchanged.
- The Pass 1 snapshot tests for `MetricCard` (in PR #1, may or may not be merged when Task 3 lands) verify component visual correctness.
- **No new tests needed for Task 3.** The screens it touches don't yet have snapshot coverage (Pass 2 adds that). Behavior is unchanged — only the rendering shape of the cards changes.

### Manual visual smoke

Launch with `-DemoProfile` and visually verify each affected screen in **light + dark** mode:

1. Income Sources tab — confirm "Total Annual Income" card now has the brand-teal top stripe and looks visually parented to the other content.
2. Accounts tab — confirm the 3 IRA balance cards layout cleanly in their new HStack arrangement; check on macOS standard window width and a narrow window to confirm wrapping (if any).
3. Dashboard — confirm the 4 header metrics render correctly in their new flex layout, in both light and dark mode.

### Acceptance criteria

- All 670+ pre-existing tests still pass
- Each affected screen visually verified in light + dark
- All 7 decline-to-swap comments added with clear reasons
- Single PR with a clear description of what changed and why

---

## 5. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `DashboardView` headerCard layout regression on narrow widths (iPad portrait, narrow Mac window) | Manual visual check at multiple window widths during implementation; if narrow-width wrapping is ugly, fall back to a 2×2 LazyVGrid or keep some metrics inline |
| `AccountsView` "Total IRA Balance" 3-card split looks more fragmented than the prior single card | Visual judgment during implementation. If the new layout reads as 3 separate items rather than "the IRA picture," consider a wrapping section header ("IRA Balances") above the HStack to preserve grouping |
| Comments feel like clutter in views | Keep them to 2 lines max; use a consistent format so they're skimmable |
| User decides post-merge that one of the 3 swaps was wrong | Each swap is a separate, isolated change; can be reverted via `git revert` of just the relevant hunks. Single-PR scope means low blast radius |
| Task 3 timing relative to Pass 1 PR #1 merge | Task 3 doesn't depend on PR #1 — it touches different files (RetireSmartIRA/*View.swift). Both can land in either order; minor merge-conflict risk is zero |

---

## 6. Out of scope (deferred to later or rejected)

- **Expanding `MetricCard`'s API** for multi-value or range support — rejected during brainstorm. Keeps the component narrow and consistent.
- **New canonical card components** (`CompositeCard`, `ComparisonCard`, `StatusCard`) — rejected. The view-level patterns are heterogeneous enough that forcing them into a component family adds more complexity than it removes.
- **The deferred `QuarterlyTaxView` quarterly payment range card** — wait for Pass 2 snapshot coverage before changing.
- **Any structural view refactor** beyond the card swaps. The Task 3 PR should only touch the lines of code that swap a card or add a comment.
- **The 1.9 features-bundle dashboard sections** (Task 5: ACA, Medicare, contributions, Reduce-AGI) — those will be built using `MetricCard` from the start per the spec, but that's Task 5's work, not Task 3's.

---

## 7. Approval & next steps

**Approval gate:** John reviews this spec, approves or requests revisions.

**Next step (after approval):** Invoke `superpowers:writing-plans` to break this spec into a step-by-step implementation plan. Given the small scope (~1-2 hours), the plan will likely be a single phase with one task per swap and one task for the comments, plus a final manual-verification step.

**Branch:** `1.9/metriccard-sweep`, branched from main. Independent of PR #1.

---

*End of spec.*
