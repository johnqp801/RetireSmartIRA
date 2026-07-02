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

**Not yet captured (pilot stopped after 5 screens):** Income & Deductions, RMD Calculator, Scenarios,
Tax Summary, Quarterly Tax, State Comparison; all modals; iPad + iPhone parity passes.

### Prioritized (from the pilot so far)
1. **T2 / MP-1** — reconcile the duplicate "taxable" concept (structural clarity).
2. **T1 / SS-2** — missing-critical-input nudges on Multi-Year (trust + correctness).
3. **AC-3** — Taxable card in the balances summary (completeness).
4. **AC-2** — fix the misleading category subtitle (quick win).
5. **AC-4, MY-2** — polish (quick wins).

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
