# RetireSmartIRA — UX / Information-Architecture Audit

**Started:** 2026-07-02
**Method:** flows + fixed rubric + code-grounding across Mac / iPad / iPhone.
**Goal:** find the *structural* UX/IA issues (patterns, cross-platform gaps, misplaced inputs), not
one-off bugs — and produce a prioritized, durable findings list.

---

## 1. Rubric (fixed evaluation lens)

Every finding is tagged with one dimension, a severity, and an effort estimate.

| # | Dimension | What to look for (tailored to this app) |
|---|---|---|
| D1 | **IA / navigation** | Does each input live where a user would look? Is the tab order logical? Are cross-tab dependencies discoverable? (e.g., Multi-Year Plan depends on income/SS/accounts entered on *other* tabs.) |
| D2 | **Discoverability** | Can a feature be found without a tour? Below-the-fold placement, hidden affordances, unlabeled buttons. (e.g., taxable section was below a long IRA list.) |
| D3 | **Input to output clarity** | Does every field state its unit/base? Is it obvious what an input drives? Do displayed values ever contradict each other? (e.g., "% of what?"; the "0 vs $397k" Year-1 field.) |
| D4 | **Consistency** | Controls, terminology, color, and layout repeat across screens. Same concept named the same way; same control for the same job; palette adherence. |
| D5 | **Trust / credibility** | Disclosures present and honest; no overclaim; results framed as modeled-under-assumptions, not advice. |
| D6 | **Cross-platform parity** | Same screen renders correctly on Mac / iPad / iPhone. Vanishing labels, truncation, broken layout, divergent control behavior. (e.g., LabeledContent vs title-as-placeholder.) |
| D7 | **Error prevention & states** | Empty / filled / error states handled; destructive actions confirmed; invalid input handled gracefully. |

**Severity:** `Critical` (blocks a task or shows wrong data) · `Major` (confuses/misleads; likely to
churn a user) · `Minor` (polish).
**Effort:** `S` (inline fix) · `M` (scoped task) · `L` (structural change).

---

## 2. Capture checklist (coverage matrix)

Screens (tabs) from `ContentView`:
Get Started · My Profile · Social Security · Income & Deductions · Accounts · RMD Calculator ·
Scenarios · Tax Summary · Multi-Year Plan · Quarterly Tax · State Comparison.

For each screen capture: **default (filled) state**, and where they exist — **empty state**,
**each modal/editor**, and **scroll states** for long screens (things hide below the fold).

Modals/editors to include explicitly: Add/Edit IRA account · Add/Edit **Taxable** account ·
**Advanced assumptions** sheet · any pickers/steppers.

Platforms: **Mac** (sidebar), **iPad** (sidebar), **iPhone** (tab bar — compact width; this is where
label/truncation issues appear).

Naming: `platform-tab-state.png` (e.g., `ipad-multiyear-filled.png`, `iphone-taxeditor-advanced.png`).

---

## 3. Flows to walk (journeys, not stills)

IA problems only surface in journeys. Start with Flow 1; add others after we calibrate.

### Flow 1 — Cold setup to a finished plan (highest value)
The primary journey; exposes cross-tab dependency and IA gaps.
1. Get Started (onboarding) ->
2. My Profile (ages, filing, state) ->
3. Social Security (benefits, claim ages) ->
4. Income & Deductions (wages/pension/other) ->
5. Accounts (IRAs + at least one Taxable account, incl. the editor) ->
6. Multi-Year Plan: set **annual living expenses**, read summary + comparison + charts, override
   Year-1, open Advanced assumptions, export CPA briefing.
Capture each step; note every moment the user must go *back* to another tab, or can't tell what to
enter next, or sees a value that doesn't match another screen.

### Flow 2 — Interpret and adjust (after Flow 1)
On Multi-Year: toggle Future $ / Present value, override Year-1 and reset, open Advanced
assumptions, read the balances chart / cliffs chart / heir comparison. Watch for clarity + parity.

---

## 4. Findings

### HEADLINE — T3: Data-representation fragmentation across analysis surfaces (Critical)

The app has grown several analysis surfaces that each consume the household inputs a little
differently and **don't visibly reconcile**. Concrete evidence from one profile:

- **Four different "income" totals**, same-ish labels: Income tab **$176,054** · Scenarios "Income
  from Sources" **$140,490** (taxable-only; excludes $46,927 tax-exempt) · Tax Summary "Total
  Baseline Income" **$187,417** · Quarterly "Gross Income" **$224,499**. Each is internally correct;
  together they read as the app disagreeing with itself.
- **Investment income entered twice** (Income tab manual entries *and* taxable-account yields), with
  the Multi-Year adapter **silently superseding** the manual entries while the single-year tabs still
  use them — no UI signal (this is a direct consequence of the taxable-accounts supersede logic).
- **RMD peak differs**: RMD Calculator "IRA/401k peak $534k in 2035" vs Multi-Year "peak forced RMD
  $785k-$1.1M" (different horizons/assumptions, unexplained to the user).
- **Effective rate** defined differently: Tax Summary avg 3.6% vs State Comparison 1.81%.

Root cause: three engines behind overlapping UI (`TaxCalculationEngine` -> Scenarios/Tax Summary/
Quarterly/State; `DrawdownProjectionEngine` -> RMD Calculator; `ProjectionEngine` -> Multi-Year).
**Fix direction:** one household "inputs" model with consistent labels; where a surface uses a subset
(taxable-only, +scenario, +horizon), label it explicitly; and a single place to see "what income the
app thinks you have."

### IA consolidation question (Major)

**Scenarios + Tax Summary + Quarterly Tax** are three separate tabs doing closely-related *single-year*
scenario work — they share the exact output (taxable $111,738.93, total tax $8,930.84) but frame the
input four ways. This is the "two-mode" question: consider one **"This Year"** surface (single-year)
clearly distinct from **Multi-Year** (multi-year), rather than three sibling tabs.

### Positive baseline (protect these)

The tax-engine depth is the real differentiator and it shows: Tax Summary's IRMAA guidance ("$2,574
until next tier; reduce income by $53k to save $2,297/yr"), the State Comparison (current scenario
taxed in all 51 states), the RMD projection chart, and honest disclosures throughout.

### Systemic themes (fix these for leverage)

- **T1 — Cross-tab dependency is inconsistently surfaced (D1, Major).** The Multi-Year plan
  silently consumes data entered on other tabs (Social Security, Income, Accounts). Only the
  *missing-taxable-account* case shows a warning; missing SS or income run to $0 with no nudge.
  The tab also mixes inline inputs (living expenses, HSA, horizon, Year-1) with off-tab inputs.
  **Fix:** a "Plan inputs / health check" strip at the top of Multi-Year that flags empty critical
  inputs (SS, income) the same way the taxable warning does; and/or a compact "inputs used" line
  near the top (today it only appears at the very bottom in "What this plan covers").

- **T2 — "Taxable" is split across three places (D1/D4, Major).** My Profile's "I have a taxable
  brokerage account" toggle (legacy / single-year) + the Accounts "Taxable Accounts" section
  (new, first-class) + the Multi-Year roll-up. Users must reconcile them. **Fix:** reconcile the
  My Profile toggle with the first-class accounts (derive it from `taxableAccounts.isEmpty`, drop
  it, or relabel it to point at the Accounts section).

### Pilot findings (Flow 1, macOS)

| ID | Screen | Dim | Sev | Eff | Finding | Code / fix |
|----|--------|-----|-----|-----|---------|-----------|
| GS-1 | Get Started | D5 | (+) | - | Honest "manual entry, no aggregation" disclosure + Setup Progress checklist; strong onboarding. | keep |
| MP-1 | My Profile | D1/D4 | Major | M | "I have a taxable brokerage account" toggle now collides with first-class Taxable Accounts (theme T2). | SettingsView; reconcile with `dataManager.taxableAccounts` |
| SS-1 | Social Security | D1 | (+) | - | "Benefits automatically synced to Income & Deductions" clearly states a cross-tab dependency. | keep |
| SS-2 | Social Security | D1/D5 | Major | M | SS not entered (setup 4/5), yet Multi-Year runs with $0 SS and no nudge (theme T1). | add missing-input nudge |
| AC-1 | Accounts | D2 | (+) | - | Taxable Accounts now above the IRA list (discoverable) — the move landed. | keep |
| AC-2 | Accounts | D3/D4 | Major | S | Every taxable row shows "Brokerage" subtitle even for "Tax Free Money Market" / "Jack's Trust" — category unused, subtitle can contradict the name. | `TaxableAccountRow` shows `category.rawValue`; hide when default, or use category meaningfully |
| AC-3 | Accounts | D3/D4 | Major | M | Top "IRA Balances" summary omits Taxable (~$11M sits right below). Add a Taxable card / rename to "Balances". | `AccountsView` balances summary |
| AC-4 | Accounts | D4 | Minor | S | Button labels inconsistent: "Add" (taxable) vs "Add Account" (IRA). | unify label |
| MY-1 | Multi-Year | D3 | (+) | - | Assumptions strip now shows taxable roll-up + Annual living expenses + horizon; fixes present. | keep |
| MY-2 | Multi-Year | D3 | Minor | S | Year-1 field shows "0" during "Computing your plan…" (plannedYear1 is 0 until the result lands), briefly re-showing the old 0-vs-plan confusion. | show a placeholder while computing |
| INC-1 | Income & Deductions | D1/D3 | Critical | M | Manual investment income (~$172k) is silently superseded by taxable-account yields in Multi-Year, but still used by single-year tabs; no signal (theme T3). | `MultiYearInputAdapter` supersede; add a note on Income tab when accounts exist |
| INC-2 | Income & Deductions | D3 | Minor | S | "Short Term Cp Gains" label typo ("Cp"). | fix label |
| RMD-1 | RMD Calculator | D3 | (+) | - | Dated obligations + projected-RMD chart with peaks; strong. | keep |
| RMD-2 | RMD Calculator | D1/D4 | Major | L | Own drawdown model (RMD only / spending gap / withdrawal rate) overlaps Multi-Year; RMD peak ($534k) does not obviously reconcile with Multi-Year ($785k-$1.1M) (theme T3). | reconcile / cross-link / explain horizon diff |
| SCN-1 | Scenarios | D3/D4 | Major | M | "Income from Sources $140,490" (taxable-only) vs Income tab $176,054 under near-identical labels (theme T3). | label the subset explicitly |
| SCN-2 | Scenarios | D1 | Major | L | Scenarios / Tax Summary / Quarterly overlap heavily (single-year scenario tax); consolidation question. | see IA consolidation |
| TS-1 | Tax Summary | D3/D5 | (+) | - | Rich single-year breakdown + excellent actionable IRMAA guidance; the app's strength. | keep |
| QT-1 | Quarterly Tax | D3/D7 | (+) | - | Safe-harbor choice with tradeoffs + payment schedule with paid toggles. | keep |
| QT-2 | Quarterly Tax | D4 | Major | M | "Gross Income $224,499" — a 4th income figure across tabs (theme T3). | consistent income labeling |
| SC-1 | State Comparison | D3 | (+) | - | Current scenario taxed across all 51 states, ranked; genuine differentiator. | keep |
| SC-2 | State Comparison | D6 | Minor | M | 50 two-letter bars will be cramped on iPhone (compact width). | parity check |

**Full macOS pass complete (all 11 tabs).** Not yet captured: modals/editors (Advanced assumptions
sheet, account editors, SS estimate entry) and the **iPad + iPhone parity passes**.

### Prioritized (full macOS pass)

**Structural (highest leverage, L):**
1. **T3 — data-representation fragmentation.** One household inputs model + consistent income labels
   across tabs; explicitly label subsets; a single "what income the app thinks you have" view. This is
   the #1 credibility issue (numbers that don't match across tabs). Covers INC-1, SCN-1, QT-2, RMD-2.
2. **IA consolidation** — collapse Scenarios / Tax Summary / Quarterly into one "This Year" surface,
   distinct from Multi-Year (SCN-2).
3. **T2 / MP-1** — reconcile the duplicate "taxable" concept.

**Trust/correctness (M):**
4. **T1 / SS-2** — missing-critical-input nudges on Multi-Year (SS, income), not just taxable.
5. **INC-1** — signal on the Income tab that account yields supersede manual investment income for Multi-Year.
6. **AC-3** — Taxable card in the balances summary.

**Quick wins (S):**
7. **AC-2** category subtitle; **INC-2** "Cp" typo; **AC-4** Add-button label; **MY-2** Year-1 computing placeholder.

**Deferred to parity pass:** SC-2 (iPhone 50-bar chart) and a full iPad/iPhone sweep.

---

## 5. Process notes

- **Grounding:** each finding cross-references the SwiftUI source so a symptom becomes a pattern with
  a known blast radius (e.g., "all N instances of X"), not a single-screen note.
- **Capture method (decide per pilot):** either (a) Claude drives the **Mac** app via computer-use and
  captures screens directly, or (b) the user shoots the batch. iPad/iPhone parity shots come from the
  user or a simulator (computer-use only sees the Mac desktop).
- **Optional model diversity:** run the same screenshot set + this rubric through a second capable
  model, then adjudicate the two finding lists.
- **Pilot first:** run Flow 1 end-to-end, calibrate the rubric and severity bar, *then* scale to all
  screens/platforms. Don't capture everything up front.
