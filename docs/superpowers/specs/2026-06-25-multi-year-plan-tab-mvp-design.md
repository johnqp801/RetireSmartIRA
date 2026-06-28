# Multi-Year Plan Tab — Thin MVP (Increment 1) Design Spec

**Date:** 2026-06-25
**Status:** Approved design, pending implementation plan
**Branch (work):** `2.0/heir-objective` (off `2.0/reconcile-engine`)
**Supersedes (partially):** `docs/superpowers/specs/2026-05-04-2.0-plan-b-multi-year-ui-design.md` — that design's central premise (a consolidated tab that *replaces* Scenarios + Tax Summary, with 1.8→2.0 migration/locked-pane UX) is void under the 2026-06-18 product principle. This spec is the additive, thin first increment.

---

## 1. Purpose

Surface the reconciled multi-year engine in the app for the first time, as a **new additive tab** beside Scenarios and Tax Summary (never replacing them). The increment is deliberately thin: enough to render the engine's recommendation end-to-end and the heir trade-off frontier (the differentiator), validate the engine↔UI integration, and demo. Editability, charts, sensitivity bands, and the advanced sheet are later increments.

**Why thin first:** the engine has never been driven by a UI, half the old Plan-B design serves an architecture we rejected, and the old spec is stale post-reconciliation. A small surface makes the integration test conclusive before scaling up.

## 2. Product principle (hard constraint)

The single-year **Scenarios** and **Tax Summary** tabs are CORE and MUST NOT be modified, replaced, or removed. The Multi-Year Plan tab is purely additive. A test asserts the tab is wired without touching those views.

## 3. Architecture

- **`MultiYearPlanView`** (SwiftUI) — the tab root. Holds `@StateObject private var manager = MultiYearStrategyManager()`. On `.task`/`onAppear`: `manager.attach(dataManager:scenarioStateManager:)` (from the environment) and trigger the existing compute path. Renders manager state; contains no business logic.
- **All presentation logic in value-type structs** (testable, no SwiftUI), per the codebase pattern. Views are thin renderers.
- The engine, adapter, and `MultiYearStrategyManager` already exist and are tested — this increment is mostly rendering + a small assumptions input + the frontier wiring.

## 4. Layout (single scrolling column, identical phone/iPad/Mac)

```
┌ Multi-Year Plan ───────────────────────────┐
│ [AssumptionsStrip]  taxable $ · HSA $ · …   │
│ [PlanSummary]       lifetime tax · converts │
│ [LadderList]        read-only year rows     │
│ [HeirFrontierSection] 6 weights · $/PV · …  │
└─────────────────────────────────────────────┘
```

## 5. Components

### 5.1 AssumptionsStripView
Collects the inputs with no existing home and surfaces the key defaults. Edits mutate `manager.assumptions` then call `manager.recompute(.assumptionsChanged)`.
- **Taxable balance** (`assumptions.currentTaxableBalance`) and **HSA balance** (`assumptions.currentHSABalance`) — user-input, not in any AccountType.
- **Horizon end age** (`assumptions.horizonEndAge`, default 95) and **growth rate** (`assumptions.investmentGrowthRate`, may default from `DataManager.primaryGrowthRate`).
- Heir salary/filing already flow from `DataManager.legacyHeir*` via the adapter — NOT collected here.

### 5.2 PlanSummaryView
Headline numbers for the **currently selected weight's** result: projected lifetime tax, total recommended Roth conversions, and a one-line plain-language summary. Backed by a `PlanSummary` struct (reuse/extend `StrategySummarySynthesizer`); the View formats only.

### 5.3 LadderListView
Read-only year rows for the selected weight's `recommendedPath`: `year · recommended conversion · AGI · marginal bracket · IRMAA/ACA cliff flag`. Each row's display content comes from a testable `LadderRow` model built from a `YearRecommendation`. No editing in this increment.

### 5.4 HeirFrontierSection
Reuses the existing `HeirFrontierView` + `HeirFrontierViewModel`. Renders the six weights with the **today's-$ / present-value** toggle and the "your taxes vs. what your heirs keep" readout. **Selecting a weight (Option 2) updates `selectedHeirWeight`, which re-renders PlanSummary + LadderList to that weighting** — no recompute, because the per-weight paths are already in the frontier result (§6).

### 5.5 States
- **`setupIncomplete`** — when required inputs are missing (e.g., no accounts / balances): a prompt to set assumptions, not a spinner.
- **`loading`** — "Computing your plan…" while `manager.isComputingFrontier` / initial compute runs.
- **`computed`** — the full layout above.

## 6. Engine/manager additions (small, contained)

1. **`FrontierPoint.recommendedPath: [YearRecommendation]`** — the `HeirFrontierCoordinator` already runs `optimize` per weight and currently keeps only summary figures; retain the path so a selected weight drives the ladder/summary without re-optimizing. (`[YearRecommendation]` is `Equatable`/`Sendable`, so `FrontierPoint` stays conformant.)
2. **`MultiYearStrategyManager`** gains:
   - `@Published var heirFrontier: HeirFrontierResult?` and `@Published var isComputingFrontier: Bool` (from heir plan Task 10).
   - `func computeHeirFrontier()` — builds inputs via the adapter, runs `HeirFrontierCoordinator().computeFrontier(...)` off-main (via the existing detached, cancellable work pattern), publishes the result.
   - `@Published var selectedHeirWeight: Double = 0` — drives which weight's path the summary/ladder show. Defaults to 0 (owner-optimal = today's recommendation).

No change to the optimizer's math or any single-year code.

## 7. Tab wiring

Add a tab in `ContentView` (both the compact and regular `TabView` arms) labeled **"Multi-Year Plan"** with an appropriate SF Symbol, placed immediately after **Tax Summary**. Use a new tag value (next free integer). Scenarios/Tax Summary tags and content are unchanged.

## 8. Testing

- **Logic (unit, Swift Testing):** `PlanSummary` synthesizer, `LadderRow` model, `HeirFrontierViewModel` (already specced) — pure value-type tests with fixtures.
- **Manager integration:** attach a `DataManager(skipPersistence: true)`, trigger compute + `computeHeirFrontier()`, assert `currentResult`, `heirFrontier?.points.count == 6`, and that selecting a weight yields that weight's path. No UI rendering.
- **View construction / snapshot:** each view builds from a fixture result without crashing (mirrors the existing `*ViewTests` pattern); optional snapshot.
- **Product-principle guard:** a test/check asserting the ContentView diff adds the tab and does not modify the Scenarios/Tax Summary tab content.

## 9. Out of scope (later increments)

Editable Year-1 (quick editor), tax-savings waterfall + account sparklines, sensitivity bands UI, advanced sheet, callout banners (SS nudge / widow), CPA-briefing PDF heir section (heir plan task 11), any migration/locked-pane UX (void under the additive model), master-detail layout.

## 10. Definition of done

The Multi-Year Plan tab renders, on a real run, the engine's recommended ladder + macro summary + selectable heir frontier from real `DataManager` data, with loading and setup-incomplete states; Scenarios/Tax Summary unchanged; all new logic/manager/view tests green; full suite green.
