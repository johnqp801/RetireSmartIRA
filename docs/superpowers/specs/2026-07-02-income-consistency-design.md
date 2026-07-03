# Income Consistency + Input-Clarity — Design Spec

**Date:** 2026-07-02
**Branch:** `2.0/heir-objective` (worktree `.worktrees/2.0-reconcile-engine`)
**Status:** Design approved (brainstorm). Next: implementation plan via writing-plans.
**Source:** UX/IA audit `docs/ux-audit/2026-07-02-ux-ia-audit.md` (themes T3, T2, T1; finding INC-1).

## Problem

The app presents the household's income as **four different totals under overlapping labels**, one per
tab, which reads as the app contradicting itself (a credibility problem). The four are a coherent
*chain of adjustments*, but the labels hide the chain:

| Value | Meaning | Where (current label) |
|---|---|---|
| $176,054 | income sources incl. tax-exempt | Income tab "Total Annual Income" (`IncomeSourcesView`) |
| $187,417 | + inherited-IRA RMD | Tax Summary "Total Baseline Income" (`DashboardView`) |
| $140,490 | taxable portion (− tax-exempt) | Scenarios "Income from Sources" (`TaxPlanningView`) |
| $224,499 | + scenario withdrawals/conversions | Quarterly "Gross Income" (`QuarterlyTaxView`, `dataManager.scenarioGrossIncome`) |

Related issues from the same audit:
- **T2:** a legacy "I have a taxable brokerage account" toggle (`profile.hasTaxableBrokerage`,
  `SettingsView`) now collides with the new first-class taxable accounts.
- **T1:** the Multi-Year plan silently runs with $0 when Social Security or income is unentered; only a
  missing *taxable account* is flagged.
- **INC-1:** when taxable accounts have yields, the Multi-Year adapter silently supersedes the manual
  investment-income entries on the Income tab (single-year tabs still use them) with no signal.

## Scope

In: T3 (income representation), T2, T1, INC-1.
**Explicitly deferred:** the IA consolidation of Scenarios / Tax Summary / Quarterly into one "This
Year" surface — a larger navigation/product decision that gets its own brainstorm.

## Approach (chosen: B)

- A — relabel in place only (rejected: numbers still computed in N places, can re-diverge).
- **B — canonical `IncomeBreakdown` model + shared reconciliation view (chosen).** One source of
  truth for the chain; tabs read from it; visible reconciliation; no tax-engine change.
- C — full income-service refactor of every tab's tax path (rejected: too much shipped-code risk).

## T3 — canonical income model + shared breakdown

### `IncomeBreakdown` (pure value type)
Computed once from the household inputs. Exposes the chain as ordered, labeled steps so any consumer
reads the same numbers. The chain must **foot by construction** for every household, not just the demo
profile — each subtotal equals the corresponding tab's headline exactly, and the bridge steps are
residuals so the arithmetic always adds up:

```
allSources            "Income from all sources"          (gross, incl. tax-exempt + gross SS)
+ regularRMD          "Regular RMD"                       (row hidden when 0)
+ inheritedRMD        "Inherited-IRA RMD"                 (row hidden when 0)
= totalWithRMDs       "Total income (sources + RMDs)"     [= Tax Summary headline]
- (residual)          "Less tax-exempt interest and untaxed Social Security"  (= taxableFromSources - totalWithRMDs)
= taxableFromSources  "Taxable income from sources"       [= Scenarios headline]
+ (residual)          "Scenario withdrawals / conversions" (= grossWithScenario - taxableFromSources)
= grossWithScenario   "Gross income (with scenario)"      [= Quarterly headline]
```

Why the two bridge steps are residuals, not independent computations: Tax Summary's baseline is
**gross** (`totalAnnualIncome() + combinedRMD + inheritedRMD`) while Scenarios' is **taxable**
(`taxableIncome() + combinedRMD + inheritedRMD`); the true gross-to-taxable bridge removes tax-exempt
interest **and** the untaxed portion of Social Security. Computing that residual guarantees the shown
subtotals foot regardless of SS taxability or RMD age. The final residual similarly absorbs any
scenario-driven change in SS taxability into the "scenario withdrawals / conversions" line.

Init: `init(allSources:regularRMD:inheritedRMD:taxableFromSources:grossWithScenario:)`. Pure,
`Sendable`. Unit-tested that the chain foots for a **nonzero-regular-RMD** case (the demo hid this by
having regularRMD == 0), and that each subtotal reproduces its headline expression.

### RMD reconciliation (single source)
The three `combinedRMD` expressions across the tabs (`DashboardView`, `TaxPlanningView`, and
`DataManager.calculateCombinedRMD()`) are behaviorally identical — `calculateSpouseRMD()` already
guards on `enableSpouse && spouseIsRMDRequired`, so all reduce to `calculatePrimaryRMD() +
calculateSpouseRMD()`. Route every headline and the model through `DataManager.calculateCombinedRMD()`
and delete the duplicated per-view locals, so there is one canonical regular-RMD figure.

### Single source of truth
Rebind each of the four tab headlines to `dataManager.incomeBreakdown` (`.allSources`, `.totalWithRMDs`,
`.taxableFromSources`, `.grossWithScenario`) and remove the duplicated view-local income totals
(`DashboardView.totalBaseline`, `TaxPlanningView.incomeFromSourcesWithRMDs`). Because the model uses the
identical expressions, the displayed numbers are unchanged; the duplication is what goes away.

### `IncomeBreakdownView` (reusable)
A disclosure row ("Show how this is computed") that renders the chain (or the slice a tab cares about).
Each single-year tab's headline number is sourced from `IncomeBreakdown` (no per-view recomputation)
and gets this expander so the reconciliation is always one tap away.

### Precise labels (headline per tab)
| Tab | From | To |
|---|---|---|
| Income (`IncomeSourcesView`) | "Total Annual Income" | "Total income from sources" |
| Tax Summary (`DashboardView`) | "Total Baseline Income" | "Total income (sources + RMDs)" |
| Scenarios (`TaxPlanningView`) | "Income from Sources" | "Taxable income from sources" |
| Quarterly (`QuarterlyTaxView`) | "Gross Income" | "Gross income (with scenario)" |

The two actively-wrong ones were Scenarios (labeled generic but taxable-only) and Quarterly (bare
"Gross Income" silently including scenario withdrawals).

## T2 — reconcile the taxable toggle

Derive `hasTaxableBrokerage` from `!dataManager.taxableAccounts.isEmpty` and **remove the manual toggle
from My Profile** (`SettingsView`). The LTCG-harvesting card and any taxable-account single-year
surfaces then light up automatically when a taxable account exists — one source of truth.
Migration: an existing user who had the toggle on but no accounts entered loses the card until they add
one; acceptable now that adding a taxable account is easy and discoverable.

## T1 — missing-input health check

Reuse the orange-note pattern from the missing-taxable-account warning. On the Multi-Year tab, when a
critical input is empty, show a compact nudge that deep-links to the owning tab:
- Social Security $0 / not entered → "No Social Security entered - the plan assumes $0. Add it on the
  Social Security tab."
- No income sources entered → equivalent.

Scope: SS + income only (taxable already warns). Additive; same component pattern.

## INC-1 — supersede signal

When taxable accounts exist AND manual investment-income entries (dividends, qualified dividends,
interest, cap gains, tax-exempt interest) exist on the Income tab, show a note where those entries live:
*"For the Multi-Year plan, investment income is derived from your taxable accounts. These entries are
still used by the single-year Tax Summary, Scenarios, and Quarterly views."* Conditional note only; no
engine change.

## Testing

- `IncomeBreakdown` unit tests: the chain math and step labels reproduce $176k → $187k → $140k → $224k
  from representative inputs; tax-exempt is excluded from the taxable step; scenario additions apply.
- View construct/smoke tests for `IncomeBreakdownView` and the updated tab headlines.
- T2: `hasTaxableBrokerage` derives from `taxableAccounts`; LTCG card visibility follows.
- Full suite stays green (~1155). No tax-engine or ProjectionEngine change.
- No em dash characters in any added copy.

## Out of scope
- IA consolidation (merging the three single-year tabs).
- Any change to `TaxCalculationEngine` / `ProjectionEngine` math (this is representation + labeling).
- Reconsidering the Multi-Year supersede itself (INC-1 is a signal, not a mechanism change).
