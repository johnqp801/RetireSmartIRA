# Consolidated backlog, 2026-08-01

Single current picture after V2.3.0 shipped. Pulls together the multi-year backlog (2026-07-13), Alan's three rounds, Fred's finding, Steve Nicolai's twelve items, and the engine follow-ups scattered across session notes.

**Status markers:** ✅ shipped · 🟡 on `main`, unshipped · 🔴 confirmed broken, unfixed · ❓ reported, not yet audited

---

## 0. Owed in writing to named users

These carry commitments, which is what separates them from everything else. Both prior failures of this kind ([[optimizer-objective-not-selectable]], the caret fix missing 2.3.0) happened because a promise lived somewhere other than next to the work.

| Owed to | What | State |
|---|---|---|
| **Alan Levy** | Caret fix "in the next release" (said 2026-07-19). **Missed 2.3.0.** | 🟡 `af45404` on `main` |
| **Alan Levy** | NY government-pension exclusion, confirmed real 07-31 | 🔴 not built |
| **Alan Levy** | Per-year income entry, "next on my list" (2026-07-18) | 🔴 not built |
| **Steve Nicolai** | Kansas personal exemption, confirmed in writing 08-01 | 🔴 not built |
| **Steve Nicolai** | Iowa retirement exclusion missing since TY 2023 (reported 08-02) | 🔴 not built |
| **Steve Nicolai** | "Answers and a plan in a couple of days" on all 12 items | due ~08-03 |

> **2026-08-02 — the state tax table is stale as a whole, not state by state.** Full 51-jurisdiction
> verification done: **~29 have at least one defect**, in five distinct categories. Iowa exempts
> **Roth conversion income** outright for 55+, so this distorts the app's core recommendation. Michigan,
> Connecticut, Virginia and Arizona err the *dangerous* way, overstating exemptions. Nine states are blocked
> on the per-source design (backlog item 1c), which is now a nine-state structural gap rather than a
> two-tester courtesy. Findings, two-model confirmation plan, and Steve's F as a feature:
> `2026-08-02-full-50-state-verification.md`. **Not yet confirmed — do not edit configs until §7 clears.**

---

## 1. Confirmed calculation errors, shipped and wrong today

### 1a. 🔴 Kansas personal exemption missing — and probably not only Kansas

App: (50,000 − 8,240) × 5.2% = **$2,171.52**. Correct: subtract the **$18,320** joint exemption → **$1,218.88**. Overstates every married Kansas filer by **$952.64/yr**. Detail: `2026-08-01-steve-nicolai-feedback.md`.

**Root cause is structural.** `StateTaxConfig` has no personal-exemption field. NJ's is a hardcoded special case (`DataManager.swift:659-671`, `postExemptionDeduction`); CA's are credits. Any state with a personal exemption that is not NJ or CA is a candidate. Audit GA, AL, MA, MS, VA, HI, IA, ME, NE, UT.

**Connects to backlog I2**, which already records that multi-year `computeStateTax` (`ProjectionEngine.swift:1294-1335`) *drops* `postExemptionDeduction`. So the same defect exists twice: missing from the config, and dropped in the multi-year path even where it exists. **Fix both together or Kansas will be right in Scenarios and wrong in Multi-Year.**

### 1b. 🔴 NY government-pension exclusion missing

IT-201 line 26 fully excludes NYS/local/federal government pensions with no cap; line 29's $20,000 applies only to non-government income, and the two are independent tracks. App implements only line 29. Alan is an affected user (NYC employee pension). Detail: `2026-07-30-ny-government-pension-exclusion-gap.md`.

Narrower than first assumed: military retirement is already fully exempt in NY, and the non-government $20,000 logic including the shared pension+IRA cap is correct.

### 1c. 🔴 Per-source state exemptions have no representation — the unifying design

**Alan's NY gap and Steve's suggestion G are the same problem.** A NYC pension is fully excluded while a private pension is capped; some of Steve's wife's 403(b) accounts are state-exempt and others are not. Neither is expressible because `RetirementIncomeExemptions` is **per-state**, not per-source.

Needs a per-source or per-account flag, plus the carve-out that salary-reduction supplemental plans (403(b) TDA, 457) are NOT line-26 income even for a government employer. **Design once, covering both users.** Patching them separately produces two hardcoded special cases on top of NJ's.

---

## 2. 🔴 The decumulation gap — two users and Fred, independently

**Multi-Year does not pull Scenarios-tab IRA/401k withdrawals.** The adapter reads `dataManager.yourExtraWithdrawal` into dead `year1PrimaryWithdrawal`/`year1SpouseWithdrawal` fields the engine never reads, and there is no ongoing-year withdrawal field at all. Documented in-code as the "2.1 decumulation" gap at `OptimizationEngine.swift:388-395`. **Overstates conversion room and IRA balances.**

Reported independently by:
- **Fred**, 2026-07-14, confirmed by grep
- **Steve**, 2026-08-01 (#3): "We withdraw from taxable to get enough to live on, but I don't seem to be able to create a scenario for that"

Fred's approved vision email frames the target architecture: **Multi-Year recommends, Scenarios commits, Tax Summary explains**, with decumulation modeled as source + use + ordering. That is the design brief.

**Same dead-wiring pattern** appears in per-year overrides: `perYearExpenseOverrides` exists in model and engine (`ProjectionEngine.swift:490`) but only expenses got a UI in 2.1.2; there is still no per-year *income* override at all. That is Alan's outstanding promise and Steve's suggestion B.

This is the largest single piece of work on the list and probably the defining feature of the next major version.

---

## 3. ❓ Reported, not yet audited

- **Steve #2:** RMD calculator shows only the primary's RMDs. His spouse is 9 years older and starts first. Also says spouse RMDs are missing from Tax Summary. Distinct from the spouse/joint-ownership RMD fix shipped in 2.3.
- **Steve #1:** taxable-account yield percentages (`qualifiedDividendYield`, `ordinaryIncomeYield`, `taxExemptYield`, `realizedLongTermGainYield`) do not flow into income. They drive the multi-year projection; whether they should populate single-year Scenarios is a design question. Same expectation gap as his suggestion A.

---

## 4. 🟡 On `main`, waiting for a release

- `af45404` **caret-at-end.** Applied to `SettingsView` ONLY. Eight other numeric screens still exposed: `IncomeSourcesView`, `AccountsView`, `RothConversionView`, `QuarterlyTaxView`, `SSDataEntryView`, `TaxPlanningView`, `Year1EditorView`, `YearDetailEditor`. One line each. **Undecided:** extend before shipping, or ship narrow. `IncomeSourcesView` is the sharpest risk.
- `25d7edd` **Year-1 override wipe.**

Next build = `CURRENT_PROJECT_VERSION` 63 → 64.

---

## 5. Multi-year backlog — VERIFIED against `main` 2026-08-01

The 2026-07-13 backlog file is stale. Statuses below were checked in code, not inferred.

### Confirmed FIXED, drop them

| Item | Evidence |
|---|---|
| **A1** over-conversion objective | `900ba6d` wealth-consistent objective, 2026-07-17 |
| **D7** `brakeStopsDrain` | re-enabled with A1 |
| **B2** deferred-tax row | shipped 2.1.1 |
| **B4** phantom conversions in ladder | `LadderRow.swift:28` uses `rec.executedRothConversion` |
| **C6** charts default to nominal | `MultiYearPlanView.swift:11` `defaultUnits = .presentValue` |
| **E9** local/city tax dropped | `MultiYearStaticInputs.swift:41` carries `localIncomeTaxRate` |
| **B5** CPA PDF nominal vs PV | `MultiYearCPABriefing.swift:153-177`, every row says "present value" |
| **D10** orphaned `PlanComparisonView` | file deleted |
| **D11** chips read global config | no `TaxCalculationEngine.config.current` in those views |
| **I1** PA/IL/MS conversion exemption | fixed 2026-07-14 |

### Confirmed STILL OPEN

| Item | Verified how |
|---|---|
| **I2** multi-year drops `postExemptionDeduction` | the identifier appears NOWHERE in `ProjectionEngine.swift`. **Same defect as Kansas; fix together.** |
| **E8** SALT-cap phaseout basis mismatch | single-year `DataManager.saltCap:1747` uses `scenarioGrossIncome`; multi-year `MultiYearItemizedDeduction.swift:95` passes `agi` net of above-the-line. Two surfaces disagree for anyone with above-the-line deductions. |
| **F-SS** warn when taxable SS exceeds planner benefits | no such warning anywhere in the codebase |
| **C5** IRMAA reference lines unreadable | no IRMAA reference-line handling in any chart view |
| **I3** heir-frontier narrative headline | **could not confirm either way.** No narrative/headline code found in `HeirFrontierCoordinator` or `PlanPathMetrics`. Left open rather than guessed. |
| **A2** fill-to-bracket AGI misleading | traced, NOT a bug, no action |

## 6. Engine follow-ups from the V2.3 work

- **Annotate-then-rank for infeasible strategies.** Comparison columns are inflated by phantom funding with no feasibility marker, and `keepBestOfCandidates` ranks purely on objective cost. Nothing reads `isInfeasible`. Explicitly named as a limit in the published conversion-tax article.
- **`acaPremiumImpactFinal` on a post-gross-up basis.**
- **IRMAA/ACA/NIIT frozen inside the gross-up sizing loop** (`ProjectionEngine.swift:967`). Documented, defensible (IRMAA is billed two years later), and stated as a limit in the article. Revisit only if the framing changes.
- **TAXSIM fixtures beyond the 50% band.**
- **Rebase the 2.2 display-audit harness onto current `main`.** Baselines moved under the V2.3 engine fixes.
- **CPA-briefing deferred-tax parity** with the on-screen row.

---

## 7. Steve's suggestions A-H — an information-architecture critique

Worth reading as one argument rather than eight tickets. His thesis: **accounts should come first, income should be derived from them, and expenses deserve their own page with funding rules.**

| | Suggestion | Note |
|---|---|---|
| **A** | Accounts above Income and Deductions; show taxable-account income there; add HSA as an account type | Pairs with his #1 |
| **B** | Rename to just "Income"; allow year ranges | = per-year income entry, also promised to Alan |
| **C** | Expenses page for future years, with funding options (traditional, taxable, etc.) | This is **the decumulation gap** in UI form |
| **D** | Move Charitable Contributions out of Scenarios to its own page or into Expenses | |
| **E** | Donor Advised Fund account type as a stock-donation destination; can the engine optimize **bunching** into one year with payout over several, with an educational callout | New capability, not a fix |
| **F** | Communicate how accurate the state modeling is; per-state, per-income-type treatment text | Pointed, given he found a state bug the same day |
| **G** | Per-account flag for state-exempt 403(b) | **= 1c above** |
| **H** | Federal bonds income type, generally state-exempt | Small, well-defined |

**A, B, C and D are one coherent restructure**, and C is the decumulation gap wearing a UI hat. Doing C properly likely forces A and B anyway.

**F is worth taking seriously as trust infrastructure.** The site already has an `/accuracy` page; the app has no equivalent. A user who cannot see the modeling scope has no way to know when to distrust a number, which is exactly how Steve found Kansas.

---

## Suggested order

1. **Personal-exemption field + multi-state audit + I2**, single piece of work. Shipped error, written commitment, structural, and it fixes the multi-year path at the same time.
2. **Per-source state exemption design** covering Alan's NY pension and Steve's 403(b) together.
3. **Decide the caret scope**, then cut a build. Two fixes are sitting on `main` and one is overdue to a tester.
4. **Audit Steve #1 and #2**, cheap, may not be bugs.
5. **Decumulation.** The big one. Fred's vision email is the design brief; Steve's suggestion C is the UI shape.
6. Everything else.
