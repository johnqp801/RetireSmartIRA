# Multi-Year Cash-Charitable Itemizing — Design (V2.1.1, folded into the 2.1 release)

**Date:** 2026-07-12
**Branch:** `2.1/selectable-conversion-approaches`
**Status:** Approved design, pre-plan.

## Context

V2.1.0 ships selectable Roth-conversion approaches with charitable modeling, but
the multi-year `ProjectionEngine` models **QCD only**. It computes taxable income as
`federalAGI − standardDeduction` and has **no itemized path at all** — no SALT, no
mortgage, no cash-charitable deduction, and it does not even apply the OBBBA §170(p)
non-itemizer cash deduction the single-year engine already has
(`ProjectionEngine.swift:695-703`). The Phase-2 UI carries a disclosure admitting cash
charitable is not deducted.

This is a visible hole in a **promoted** use case: the 2.0.0 App Store copy sells
*"Which year should I make a major charitable gift? Test charitable timing against Roth
conversions and your projected tax bill."* A major cash gift's tax value comes from
**itemizing above the standard deduction** in the year it is made, which the multi-year
optimizer currently ignores. Folding this in ("V2.1.1") finishes the charitable story in
one release rather than shipping a self-admitted gap and patching it later.

This is a **completeness / credibility** item, not a competitive differentiator (the
four-way competitive analysis names state-tax precision + IRMAA + ACA-in-optimizer + heir
10-year + survivor as the moat; charitable modeling is not a wedge and is not a flagged
competitor gap). Scope is deliberately bounded (Tier 2 below).

## Goal

Make the multi-year optimizer correctly reward **bunching a cash charitable gift into a
high-conversion year**: in each projected year, choose standard vs. itemized by whichever
yields lower federal tax, with cash charitable deductible (subject to the 60%-AGI limit)
on the itemized path. All three approaches (`recommendedTaxMin` / `fillToBracket` /
`limitToIRMAA`) then optimize against the real after-deduction tax.

## Non-goals (explicit)

- Per-year editable itemizable inputs in the Multi-Year tab (clean fast-follow if wanted).
- 5-year charitable carryforward of amounts above the 60%-AGI limit.
- AMT in the multi-year path (single-year has it; multi-year never has).
- Appreciated-property / stock donations in multi-year (single-year has the 30%-AGI
  bucket; multi-year Tier 2 is **cash-only**: QCD + cash).

These are documented limitations, surfaced to the user (Section 5) — not silent gaps.

## Design

### 1. Inputs added to `MultiYearStaticInputs`

Seeded in `MultiYearInputAdapter` from the single-year `DataManager`, exactly as the
giving plan is seeded today (`MultiYearInputAdapter.swift:239`). Held **flat nominal**
across the horizon.

- `mortgageInterest: Double`
- `otherItemizedDeductions: Double` — non-charitable, non-SALT lump (whatever the
  single-year `baseItemizedDeductions` includes beyond SALT + cash charitable, e.g.
  the non-medical remainder).
- `grossMedicalExpenses: Double` — pre-floor; the 7.5%-AGI floor is applied per year.

Not added:
- **Cash charitable** — derived in-engine per year as `givingTarget − QCDs` (the engine
  already computes QCDs from `charitableGivingPlan`; the cash remainder is the non-QCD
  portion of the target).
- **SALT** — computed per year from that year's state tax, capped at that year's SALT cap;
  the projection already produces per-year state tax (`computeStateTax`).

### 2. Per-year deduction logic in `ProjectionEngine`

Replaces the standard-only computation at `ProjectionEngine.swift:703`. For each projected
year, compute **both** paths and take the one producing **lower federal tax**:

- **Standard path total** = `standardDeduction(...)` (already includes the age-65
  additional deduction + OBBBA senior bonus) `+` OBBBA §170(p) non-itemizer cash deduction
  (min of cash charitable and $1,000 single / $2,000 MFJ, below-the-line — reduces taxable
  income, not AGI). *Decision: include the non-itemizer deduction so standard-deduction
  years still credit small cash gifts, matching single-year and keeping the standard-vs-
  itemized comparison honest.*
- **Itemized path total** =
  `SALT(capped) + mortgageInterest + otherItemizedDeductions + deductibleMedical
   + cashCharitable(capped at 60% of AGI) + seniorBonusDeduction`
  where `deductibleMedical = max(0, grossMedicalExpenses − 0.075 × AGI)` using **that
  year's** AGI.
- Selection is **per year, independent** — a big-gift year itemizes; lean years take
  standard. That independence is what makes bunching pay off.

Reuse the single-year math where possible rather than reinventing it: the 60%-AGI
charitable cap, the senior-bonus treatment on the itemized path, and the §170(p) cap
mirror `DataManager.baseItemizedDeductions` / `totalItemizedDeductions` /
`nonItemizerCharitableDeduction`. Where a shared pure helper is cleaner than duplicating
logic across `DataManager` and `ProjectionEngine`, extract it.

### 3. Inflation / limitation treatment (Tier 2 simplifications)

- Carried itemizables (mortgage / medical / other) are **flat nominal**. *Decision:
  mortgage amortizes down, medical drifts up — they roughly wash, and per-item inflation
  guessing adds complexity for little accuracy.* Cash charitable retains the giving plan's
  existing `maintainRealValue` behavior.
- **No 5-year carryforward** — cash above the 60%-AGI limit in a year is lost, not carried.
- **No AMT** in the multi-year path.

### 4. Optimizer + comparison impact

All three approaches now see the deduction, so conversion sizing shifts in gift years —
the intended behavior. Downstream consumers (CPA briefing, `ConsequenceDeltas`, charts,
ladder) read the projected `YearRecommendation` and pick up the change automatically.

**Expected: optimizer / projection test rebaselines.** These are the correct new answers
and must be reviewed case-by-case, not blanket-accepted. No production behavior outside
the projection/optimizer changes.

### 5. UI surface (minimal)

- **No new inputs.** One disclosure line in the Multi-Year giving area: itemizable
  deductions are carried from the current-year scenario; charitable carryforward and AMT
  are not modeled in the projection. Reuse/extend the existing giving disclosure rather
  than adding a new component.
- The existing read-only giving refinement stays as-is.

## Testing strategy

- **Engine unit tests** on the per-year standard-vs-itemized selection: a year that should
  itemize (large gift) vs. a year that should take standard; the crossover; the §170(p) cap
  on the standard path; the 60%-AGI cap on the itemized path; medical floor against per-year
  AGI.
- **Bunching behavior test:** a scenario where concentrating the same total giving into one
  high-conversion year yields lower lifetime tax than spreading it — the optimizer/projection
  should reflect that.
- **Parity spot-checks** against the single-year engine for a single year with identical
  inputs (standard-vs-itemized choice and taxable income should agree, modulo the documented
  carryforward/AMT/stock exclusions).
- **MFJ end-to-end** including QCD + cash + limit-to-IRMAA (also closes a pre-existing
  follow-up).
- **Federal-only tests must pin a no-income-tax state (Texas)** — the CA SALT-as-itemized
  confound (senior-bonus session 2026-07-06, widow-tax session 2026-07-11) otherwise moves
  the itemize/standard crossover.
- Re-run the full suite; review every rebaseline. Use `-resultBundlePath` + `xcresulttool`
  (xcodebuild stdout undercounts large Swift-Testing suites).

## Key files

- `RetireSmartIRA/ProjectionEngine.swift` (:695-718 deduction/tax) — core change.
- `RetireSmartIRA/MultiYearStaticInputs.swift` — new input fields.
- `RetireSmartIRA/MultiYearInputAdapter.swift` (:239) — seed from single-year.
- `RetireSmartIRA/DataManager.swift` (`baseItemizedDeductions` :1840, `totalItemizedDeductions`
  :1901, `nonItemizerCharitableDeduction`) — source of the reusable math.
- `RetireSmartIRA/CharitableGiving.swift`, `QCDPlanner.swift` — cash = target − QCD.
- Multi-Year giving UI (disclosure line) — TBD exact file during planning.
