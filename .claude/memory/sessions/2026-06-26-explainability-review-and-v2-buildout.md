# 2026-06-26 — Explainability + PV, multi-agent code review, external tax review; next: full V2.0 buildout

**Branch:** `2.0/heir-objective` (worktree `.worktrees/2.0-reconcile-engine`), HEAD `a0ba0e1`. PR **#8** open against `main` (johnqp801/RetireSmartIRA). Full suite green: **1083 tests**.

## What shipped this session
1. **Engine-realism batch finished** (C3 gross-up, PV-discounted objective, heir frontier, `rmd` field) — green.
2. **Multi-Year Plan tab explainability arc:**
   - "Your plan vs. doing nothing" comparison block: Lifetime tax, Ending traditional IRA, **Ending Roth IRA**, Peak forced RMD, What heirs keep (`PlanComparison` value type + `PlanComparisonView`).
   - Tab-level **Future $ / Present value** toggle (relabeled from "Today's $"); governs the Your-plan summary, comparison block, and heir frontier.
   - **PV made CPI-consistent** for display (`EngineMath.realPresentValue` = deflate by CPI then discount 3% real). Optimizer objective left at 3%-real-on-nominal (CPI version reverted — broke the IRMAA buffer; see [[objective-cpi-deferred]]).
   - Ladder **IRMAA now attributed to conversions** (plan minus no-conversion baseline) with amount + projection disclaimer.
3. **Diagnostics this session proved the engine is PV-correct** for the real $5.6M-trad MFJ profile (~$1.9M lifetime tax saved vs doing nothing; aggressive conversions are bracket-filling to top of MFJ 35%, not reckless).
4. **Multi-agent foundation code review** (ran `/code-review`-style 8-angle finders) → fixed 4 findings, each with a regression test:
   - **#1 (real bug):** `buildEmptyActionsMap` misaligned the no-conversion baseline (used `Calendar.current` not `inputs.baseYear`, and primary-only horizon) — corrupted the comparison/IRMAA for age-gap couples + future planning years. Fixed + 2 tests.
   - **#2/#4:** unified the optimizer objective so `computeObjectiveCost` (SSClaimNudge) matches the optimizer's terminal discount period. + test.
   - **#3:** ConstraintAcceptor bracket-overrun penalties derived from config rates not literals.
   - **#7:** em-dash in `LadderRow.conversionLabel` → "no conversion".
   - Logged-not-fixed cleanups: #5 lifetimeTax DRY, #6 documented one-field observation tracking, #8 dead `injectedPath` param.
5. **External CPA-style tax review** (ChatGPT + Gemini + Perplexity), reconciled against source + web-verified. **Net: one real fix** — IRMAA Part D Tier 4 $83.50→$83.30 (CMS 2026). Everything else verified correct (Part B surcharge handling, senior bonus below-the-line, ACA==IRMAA MAGI, RMD ages, QCD $111k, Part D Tier 3 $60.40). One real limitation logged: [[multi-year-muni-magi-gap]].

## NEXT SESSION GOAL (user stated): build thin-first → FULL V2.0 product to LAUNCH
The Multi-Year Plan tab is currently a deliberate **thin-first MVP**. The user wants to fully build it out into the launch-ready V2.0 product next session.

**Recommended first step:** START WITH BRAINSTORMING/SCOPING — define what "full V2.0 launch" means before building. Known candidate increments already surfaced this session:
- Editable Year-1 levers wired to the engine (today only `yourRothConversion` triggers recompute — observation tracking is one-field; see review finding #6).
- Charts/visualizations for the ladder + frontier.
- CPA-briefing PDF export (heir tasks 9-11 were logged earlier).
- Richer comparison/insights UI.

**Deferred engine work to weigh into "full" scope:**
- Hard IRMAA cliff-rejection rule (prereq before CPI-consistent objective) — [[objective-cpi-deferred]].
- Muni interest into multi-year MAGI/SS — [[multi-year-muni-magi-gap]].
- Itemized deductions in the multi-year path (currently standard-deduction only).
- Full 2.1 decumulation (brokerage cost-basis, withdrawal-order optimizer, NIIT, HSA).

**Open product decision:** merging PR #8 to `main` ships V2.0 — hold until the tab is fully built, OR merge the foundation now and build the UI in follow-on PRs. User leaning toward the full build before launch.

## State to resume cleanly
- Work is on `2.0/heir-objective` (PR #8), all pushed, suite green.
- The app builds/launches via `xcodebuild ... -derivedDataPath <scratch>` then `open` (the user's default Debug build kept going stale; use an explicit derivedDataPath to guarantee a fresh binary).
- The real test profile lives in the `com.john.RetireSmartIRA.demo` UserDefaults suite (DEBUG): $5.6M traditional (3.2M+2.4M), MFJ, both age 71, CA, 8% growth, $46,927 muni.

---

## V2.0 UI BUILDOUT — START HERE (next-session handoff)

You don't need to invent the vision; mine the existing material first, then brainstorm/scope before building.

**Read first (where the material lives):**
1. **Thin-first tab design + the backlog:** `docs/superpowers/specs/2026-06-25-multi-year-plan-tab-mvp-design.md`. Its **§9 "Out of scope (later increments)" IS the buildout backlog** (editability, charts, sensitivity bands, advanced sheet).
2. **Full Plan-B UI vision + PARTIAL IMPLEMENTATION lives on branch `origin/2.0/plan-b-ui`** (also `archive/v2.0-planning`) — NOT on `2.0/heir-objective`. Spec `docs/superpowers/specs/2026-05-04-2.0-plan-b-multi-year-ui-design.md` + plan `...plans/2026-05-04-2.0-plan-b-multi-year-ui.md` + impl commits (e.g. "Phase 1C1 off-grid pin amount"). MINE it for full-UI component/layout ideas. **CAVEAT — its central premise is VOID:** it wanted to *replace* Scenarios + Tax Summary with 1.8→2.0 migration + locked-pane UX. The 2026-06-18 product principle killed that. Salvage the components, drop the replacement/migration framing.
3. **Binding product constraint:** additive tabs ONLY, never replace Scenarios/Tax Summary. Source: `sessions/2026-06-18-v1.9-drawdown-design-and-2.0-audit.md`.
4. **Design conventions (use so new UI is consistent):** `docs/superpowers/plans/2026-04-25-color-system.md` (color system) + `docs/superpowers/plans/2026-04-30-metriccard-sweep.md` (MetricCard component). The 1.9 Drawdown tab (`RMDCalculatorView`) is the best in-app example of a finished chart+overlay+toggle tab to match.
5. **Launch context:** `roadmap/current.md` (1.9.0 is live; launch = App Store submission, both iOS + macOS). iOS release workflow + versioning rules in CLAUDE.md.

**Current built state:** Multi-Year Plan = ContentView **tag 10** (additive, beside Scenarios/Tax Summary). Views: `MultiYearPlanView`, `MultiYearPlanSections` (`PlanSummaryView`/`PlanComparisonView`/`LadderListView`/`AssumptionsStripView`), `HeirFrontierView`/`ViewModel`. Manager: `MultiYearStrategyManager` (@MainActor ObservableObject), runs engine off-main, publishes `currentResult`/`baselineProjection`/`heirFrontier`.

**Backlog = candidate "full V2.0" set:**
- Editable Year-1 levers wired to the engine + **full observation tracking** (today only `yourRothConversion` triggers recompute — review finding #6; the rest is part of this work).
- Charts: ladder/balances over time, the heir-frontier curve, sensitivity bands.
- Advanced / assumptions sheet (growth, CPI, pvRealDiscountRate, terminalLiquidationTaxRate, per-spouse horizon).
- CPA-briefing PDF export (heir tasks 9-11).
- Richer comparison/insights; the "before-and-after representative-household projection" John offered Laura Saunders is a concrete real-world demand on exactly this surface.

**Recommended first move:** `git show origin/2.0/plan-b-ui:docs/...` to pull the old design+plan, then BRAINSTORM the full-V2.0 scope against the additive-only principle — decide the launch bar (which increments ship in v2.0 vs defer to 2.1) before writing UI.
