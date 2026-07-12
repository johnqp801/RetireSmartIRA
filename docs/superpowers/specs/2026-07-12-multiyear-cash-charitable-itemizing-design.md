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
across the horizon. Three new `Double` fields (default 0):

- `carriedMortgageAndOtherItemized` — the single-year `nonSALTNonMedical` sum (mortgage
  interest + other misc deduction items; excludes property tax, SALT, medical, charitable).
- `carriedPropertyAndOtherSALT` — property tax + any non-income-tax SALT items. Feeds the
  SALT total *before* the cap, alongside the per-year computed state income tax, so it
  stays subject to the SALT cap (folding it into the line above would wrongly escape the cap).
- `carriedGrossMedicalExpenses` — pre-floor; the 7.5%-AGI floor is applied per year.

Not added:
- **Cash charitable** — derived in-engine per year as `givingTarget − totalQCD`. The engine
  already computes QCDs from `charitableGivingPlan`; the cash remainder is the non-QCD
  portion of the target. `QCDPlanner.plan(...)` will be extended to also return the year's
  `target` (or `cashCharitable`) so the engine doesn't recompute it.
- **State income tax (SALT core)** — computed per year from that year's state tax
  (`computeStateTax`), which varies with conversions. Combined with `carriedPropertyAndOtherSALT`,
  then capped.

### 2. Per-year deduction logic in `ProjectionEngine`

Replaces the standard-only computation at `ProjectionEngine.swift:703`. For each projected
year, compute **both** paths and take the one producing **lower federal tax**.

**Ordering note:** the state-tax computation (`computeStateTax`, currently at :721, *after*
federal tax) must move to *before* the deduction decision, because SALT needs that year's
state income tax. This is safe — `computeStateTax` consumes `federalAGI` and income
components, never federal taxable income or federal tax, so there is no circularity.

- **Standard path total** = `standardDeduction(...)` (already includes the age-65
  additional deduction + OBBBA senior bonus) `+` OBBBA §170(p) non-itemizer cash deduction
  = `min(cashCharitable, cfg.nonItemizerCashCharitableCap{Single|MFJ})` for `year ≥
  cfg.nonItemizerCashCharitableFirstYear` (below-the-line — reduces taxable income, not AGI).
  *Decision: include the non-itemizer deduction so standard-deduction years still credit
  small cash gifts, matching single-year and keeping the comparison honest.*
- **Itemized path total** (mirrors single-year `totalItemizedDeductions` minus its
  §68 reduction, then the §68 reduction applied):
  1. `saltBeforeCap = stateIncomeTax + carriedPropertyAndOtherSALT`
  2. `salt = min(saltBeforeCap, saltCap(year, magi: federalAGI))` — `saltCap` replicates
     `DataManager.saltCap`: OBBBA expanded cap (base × inflation) with the MAGI phaseout
     (`saltPhaseoutRate` over `saltPhaseoutBaseThreshold × inflation`), floored, else default cap.
  3. `deductibleMedical = max(0, carriedGrossMedicalExpenses − cfg.medicalAGIFloorRate × AGI)`
  4. Charitable (cash-only): `cashCeiling = min(cashCharitable, cfg.charitableCashAGICeilingRate
     × AGI)`; `floor = (year ≥ cfg.itemizedCharitableAGIFloorFirstYear) ? cfg.itemizedCharitableAGIFloorRate
     × AGI : 0`; `deductibleCharitable = max(0, cashCeiling − floor)`.
  5. `itemizedBeforeLimit = salt + carriedMortgageAndOtherItemized + deductibleMedical
     + deductibleCharitable + seniorBonusDeduction`
  6. §68 overall limitation (`year ≥ cfg.itemizedOverallLimitationFirstYear`):
     `excess = max(0, federalAGI − topOrdinaryBracketThreshold)`;
     `reduction = cfg.itemizedOverallLimitationRate × min(itemizedBeforeLimit, excess)`;
     `itemizedEffective = itemizedBeforeLimit − reduction`. (`federalAGI` here already equals
     income net of above-the-line deductions, matching single-year's `incomeBeforeItemized`.)
- Choose the path with lower federal tax; taxable income = `AGI − chosenDeduction` (standard
  path subtracts std + §170(p); itemized path subtracts `itemizedEffective`). Selection is
  **per year, independent** — a big-gift year itemizes; lean years take standard. That
  independence is what makes bunching pay off.

**Shared pure helper.** Extract these rules into a dependency-free
`MultiYearItemizedDeduction` helper (static funcs over `TaxYearConfig` + scalars) rather
than duplicating them inline. It mirrors `DataManager.saltCap` / `deductibleMedicalExpenses`
/ `deductibleCharitableDeductions` / `itemizedOverallLimitationReduction` /
`nonItemizerCharitableDeduction`. Parity tests assert it agrees with the single-year
`DataManager` for identical single-year inputs. `DataManager` itself is **not** refactored
to call the helper in this release (avoids churning single-year tests); that consolidation
is a noted follow-up.

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
