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

## 4. Findings (fill during analysis)

| ID | Screen / flow step | Dimension | Severity | Effort | Finding | Code location | Fix |
|----|--------------------|-----------|----------|--------|---------|---------------|-----|
| _pending_ | | | | | | | |

Group **systemic patterns** (multiple instances / one root cause) at the top of the final report,
separate from one-offs. End with a prioritized list: quick wins (S) vs structural (L).

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
