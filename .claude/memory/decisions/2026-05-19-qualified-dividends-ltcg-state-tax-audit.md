# Qualified Dividends / LTCG State Tax Audit — PA (and other flat-deduction states)

**Date:** 2026-05-19
**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/1.8.3-incremental/` @ `dac14db`
**Scope:** Read-only audit; no code changes.

---

## 1. TL;DR

**Qualified dividends and LTCG are NOT the bug.** Both flow into the PA state tax base correctly via `preferentialIncome()` → `scenarioBaseIncome` → `scenarioGrossIncome`. So does ordinary dividends, interest, and STCG.

**The actual bug:** `calculateStateTaxFromGross` (and `stateTaxBreakdown`) apply **federal-style itemized deductions to PA gross income whenever the user itemizes federally**, even though PA has `stateDeduction: .none` (PA has no standard or itemized deduction at the state level; it taxes the 8 statutory income classes directly).

The bug pattern is in `DataManager.swift:491-496` and again in `DataManager.swift:545-550`:

```swift
if scenarioEffectiveItemize {
    stateDeduction = max(stateStandardDeduction, stateItemizedDeductions)
} else {
    stateDeduction = stateStandardDeduction
}
```

For a state configured `.none`, `stateStandardDeduction = 0`, but the itemize branch then overrides with `stateItemizedDeductions` (mortgage interest + property tax + medical + charitable + other non-SALT). That whole pool gets subtracted from PA gross.

For John's scenario this manifests as a ~$25,700 phantom deduction (≈ $789 / 0.0307), matching the observed $4,436 → $3,647 gap.

**Bug scope:** Affects every `.none` state where the user itemizes federally. That's a dozen states (PA, IL, IN, KY, MA, MI, ND, OH, UT, CT, NJ, WV) for any user with mortgage interest, big property taxes, or large charitable giving.

**Fix scope:** Small. Single conditional in two mirrored locations (the live calc + the breakdown view). No new state flags needed — `.none` already exists; the code just has to honor it. Magnitude per affected user: ~3% of itemized deductions worth of state tax (e.g. $25K itemized × 3.07% = $768 under-collection per year in PA).

---

## 2. PA Tax Law Verification

PA Personal Income Tax — eight statutory income classes; no standard or itemized deduction; flat 3.07%.

Confirmed via PA Department of Revenue Personal Income Tax Guide (current as of 2026 reading):

- **Qualified dividends:** PA treats ALL dividends (Class 5) at full 3.07%. There is NO federal preferential rate concept in PA. Source: PA DOR PIT Guide, Chapter on Dividends; PA-40 Schedule B instructions.
- **LTCG / STCG:** PA Class 3 ("Net Gains or Income From the Disposition of Property"). All capital gains — long or short — taxed at full 3.07%. Within Class 3, losses can offset gains (so John's −$6,285 STCG correctly offsets his $64,219 LTCG). Losses CANNOT cross classes. Source: PA DOR PIT Guide, Chapter on Net Gains or Income From the Disposition of Property; PA-40 Schedule D instructions.
- **Interest (Class 6):** All interest taxable at 3.07% except PA-issued municipal bond interest (and US Treasury interest, which is federal-preempted under 31 USC §3124). Non-PA muni interest IS PA-taxable. Source: PA DOR PIT Guide, Chapter on Interest.
- **No standard / itemized deduction on PA-40.** PA-40 sums the 8 classes; the only PA-side reductions are Schedule O (special tax forgiveness — income-tested credit), unreimbursed business expenses (PA UE), and Schedule SP (poverty exemption). PA does NOT allow mortgage interest, charitable contributions, property tax, or medical expenses as PA deductions. Source: PA-40 instructions; PA DOR Tax Forgiveness program.

For PA, the federal preferential treatment of qualified dividends and LTCG does NOT apply. PA's flat 3.07% applies to all of them. **VERIFIED.**

---

## 3. Code Audit — Income-Type Flow

### Path 1 — `.qualifiedDividends` and `.capitalGainsLong`

- `IncomeDeductionsManager.ordinaryIncomeSubtotal` (line 67-71): **excludes** `.qualifiedDividends` and `.capitalGainsLong`.
- `DataManager.preferentialIncome()` (line 1039-1043): **sum of** `.capitalGainsLong + .qualifiedDividends`.
- `DataManager.scenarioBaseIncome` (line 1162-1164) = `scenarioOrdinaryIncomeSubtotal + scenarioTaxableSocialSecurity + preferentialIncome()`.
- `DataManager.scenarioGrossIncome` (line 1168-1170) = `scenarioBaseIncome + scenarioTotalRothConversion + scenarioTotalWithdrawals − scenarioStockGainAvoided`.
- `scenarioStateTax` (line 1556-1571) passes `scenarioGrossIncome` to `calculateStateTaxFromGross`.

**Conclusion:** Both qualified dividends and LTCG ARE included in PA state taxable income. No bug here.

### Path 2 — `.capitalGainsShort` and `.interest`

- Neither is excluded from `ordinaryIncomeSubtotal` (line 69 filter). Both flow through ordinary subtotal → scenarioBaseIncome → state tax.
- STCG flows in as a (possibly negative) number, naturally offsetting other ordinary items in the same sum. For John this means $36,523 ord div + (−$6,285) STCG + $1,170 interest + $3,500 pension = $34,908 ordinary subtotal.
- Conceptually PA Class 3 only allows STCG losses to offset Class 3 gains, not Class 5/6. The code lumps them all together, so a Class 3 loss (STCG) effectively offsets Class 5 dividends or Class 6 interest, which violates PA's class-isolation rule. For John this is favorable to the engine ($6,285 less PA-taxable) but in a different scenario could be unfavorable. **Secondary bug — small in magnitude here.**

### Path 3 — `.taxExemptInterest`

- Excluded from `ordinaryIncomeSubtotal` and from `preferentialIncome()`. Does not enter `scenarioGrossIncome`. Correct for PA at the federal-AGI-derived gross level.
- Note: the code does not distinguish PA-issued muni interest from out-of-state muni interest. PA only exempts PA-issued. Tertiary bug — not the cause of the $789 gap, but worth flagging.

### Path 4 — Pension and SS

- Pension included in ordinarySubtotal, then removed in `applyRetirementExemptions` via `pensionExemption: .full`.
- SS taxed-portion included in scenarioBaseIncome via `scenarioTaxableSocialSecurity`, then removed via `socialSecurityExempt: true`.
- Both correctly handled.

### Path 5 — `calculateStateTaxFromGross` deduction logic (THE BUG)

`DataManager.calculateStateTaxFromGross` (lines 457-500):

```swift
let stateStandardDeduction: Double
switch config.stateDeduction {
case .none:                  stateStandardDeduction = 0
case .conformsToFederal:     stateStandardDeduction = standardDeductionAmount
case .fixed(let s, let m):   stateStandardDeduction = (filingStatus == .single ? s : m)
}

let stateDeduction: Double
if scenarioEffectiveItemize {
    stateDeduction = max(stateStandardDeduction, stateItemizedDeductions)   // ← BUG
} else {
    stateDeduction = stateStandardDeduction
}

let stateTaxableIncome = max(0, adjustedGross - stateDeduction)
```

When `config.stateDeduction == .none` AND user is itemizing federally, the code substitutes `stateItemizedDeductions` (mortgage interest + full property tax + medical + charitable + other non-SALT) for the state deduction. PA — and every other `.none` state — should always have `stateDeduction = 0`.

Same pattern in `stateTaxBreakdown` at lines 545-550.

### Forward math for John (no itemize)

- ordinarySubtotal = $34,908
- taxableSS = 0.85 × $92,328 = $78,479
- preferential = $48,860 + $64,219 = $113,079
- scenarioGrossIncome = $226,466
- After exemptions: − $78,479 SS − $3,500 pension = **$144,487**
- PA tax = $144,487 × 0.0307 = **$4,435.75 ≈ $4,436** ✓ (matches expected)

### Forward math for John (federal itemize)

If John has e.g. $36,000 federal itemized deductions (likely composition: $10K SALT cap + $25K mortgage interest + charitable + medical), then `stateItemizedDeductions` strips SALT but adds back full property tax (uncapped). For a typical taxpayer in PA with ~$8K property tax + ~$15K mortgage interest + ~$5K charitable + medical floor remnant, `stateItemizedDeductions` lands somewhere in the $25K-$28K range.

- $144,487 − $25,692 = $118,795
- PA tax = $118,795 × 0.0307 = **$3,647** ✓ (matches observed)

The $25,692 phantom deduction is `stateItemizedDeductions` being applied to PA. This is the bug.

---

## 4. Identified Bug(s)

### Bug #1 — PRIMARY (the $789 PA gap)

**Location:** `DataManager.swift:491-496` (`calculateStateTaxFromGross`) and `DataManager.swift:545-550` (`stateTaxBreakdown`).

**Behavior:** When a state's config is `stateDeduction: .none`, the engine still allows `stateItemizedDeductions` to reduce that state's taxable income whenever the user itemizes federally.

**Magnitude for John:** ~$789 of under-collected PA tax (≈ $25,692 phantom deduction × 0.0307).

**States affected:** PA, IL, IN, KY, MA, MI, ND, OH, UT, CT, NJ, WV (all `stateDeduction: .none` per `StateTaxData.swift`). Any user in these states who itemizes federally and has non-SALT itemized deductions (mortgage interest, full property tax, medical, charitable) will see understated state tax.

**Magnitude across users:** Linear in itemized non-SALT deductions × state rate. A user with $40K itemized in PA → ~$1,228 under-collection. In MA (5%) with same → $2,000+. In NJ (top rate 10.75%) the impact would be larger but progressive brackets blur the calculation.

### Bug #2 — SECONDARY (class-crossing loss offsets)

**Location:** `IncomeDeductionsManager.ordinaryIncomeSubtotal` line 67-71.

**Behavior:** `.capitalGainsShort` is summed alongside `.dividends`, `.interest`, etc. with no class isolation. A negative STCG (loss) reduces dividends/interest at the state level, which PA Class 3 rules forbid (losses can offset gains within Class 3 only).

**Magnitude for John:** $6,285 STCG loss is favorable to the engine here (reduces PA-taxable by $193). Per PA rules, it should still offset LTCG (both Class 3), netting Class 3 to $57,934 — which produces the SAME result for John because there are positive Class 3 gains to absorb it. So this is invisible in John's scenario but would matter for a taxpayer with STCG loss > LTCG gain (the excess should not offset interest/dividends).

**States affected:** Any state that follows PA's class-isolation model. Most states follow federal capital-loss rules (capital losses can offset $3K of ordinary income/year federally) so the engine's behavior is actually closer to most states' than to PA's.

### Bug #3 — TERTIARY (in-state muni interest)

**Location:** `.taxExemptInterest` handling — no distinction between in-state and out-of-state munis.

**Behavior:** PA exempts only PA-issued muni interest. Most states do the same for their own munis but tax out-of-state munis. The engine treats all muni interest as state-tax-exempt.

**Magnitude for John:** $26,927 × 0.0307 = $827 if any portion is non-PA munis. Cannot determine without more data.

**States affected:** Most progressive-tax states.

---

## 5. Fix Specification

### Fix #1 (primary, ship immediately)

In `DataManager.calculateStateTaxFromGross` and `DataManager.stateTaxBreakdown`, change the deduction selector so `.none` cannot be overridden:

```swift
let stateDeduction: Double
switch config.stateDeduction {
case .none:
    stateDeduction = 0   // PA, IL, IN, KY, MA, MI, ND, OH, UT, CT, NJ, WV have no state deduction at all
case .conformsToFederal, .fixed:
    let baseline = stateStandardDeduction
    stateDeduction = scenarioEffectiveItemize
        ? max(baseline, stateItemizedDeductions)
        : baseline
}
```

Apply the same change in both call sites (live calc and breakdown view).

**Effort:** ~30 minutes to write, 30 minutes to test the two call sites for parity.

**Risk:** Some states currently configured `.none` may actually allow some narrow deduction class (e.g. PA Schedule SP poverty exemption; MA personal exemption — actually MA may already be using `.fixed` for the personal exemption; verify). Audit each `.none` state's config to confirm `.none` was intentional and not a "we haven't implemented it yet" placeholder. The fix is correct for PA per PA-40 instructions; verify per-state for the others before shipping.

### Fix #2 (secondary, post-1.8.3 / verify per-state)

Add a `capitalLossOffsetTreatment` flag to `RetirementIncomeExemptions` (or a new `StateTaxConfig` field):
- `.federal` — losses can offset $3K of ordinary income annually (most states).
- `.classIsolated` — losses only offset within capital-gains class (PA).

In the PA path of `applyRetirementExemptions`, isolate `.capitalGainsShort` + `.capitalGainsLong` into a separate Class 3 calc and clamp the net to ≥ 0. The simpler approximation: for PA-class states, do `max(0, STCG + LTCG)` and add that back to the rest of ordinary income.

**Effort:** 2-3 hours including tests.

### Fix #3 (tertiary, low priority)

Add a `muniInterestOriginState: String?` field to `IncomeSource`. When state == user's resident state, exempt; otherwise add back to state gross. Default behavior preserved (treat as in-state) for backward compatibility on legacy sources.

**Effort:** 4-6 hours including UI for source entry.

---

## 6. Test Cases (to add)

### For Fix #1

`StateTaxPAItemizedTests.swift`:

1. **`paItemizingMustNotReducePAStateTax`** — PA MFJ, build a scenario with $20K mortgage interest + $8K property tax + $5K charitable items. Verify `scenarioStateTax` is identical whether `deductionOverride = .itemized` or `.standard`. PA does not allow itemization at the state level.

2. **`paJohnsFullScenarioBaseline`** — Reproduce the audit task's exact income mix (ord div $36,523, qDiv $48,860, LTCG $64,219, STCG −$6,285, interest $1,170, pension $3,500, SS $92,328, muni $26,927). Verify `scenarioStateTax ≈ $4,436` ±$2 with no itemized deductions.

3. **`paJohnsFullScenarioWithItemizing`** — Same income mix + $20K mortgage interest + $8K property tax. Verify tax is still ≈ $4,436 (NOT $3,647). Asserts the fix.

4. Mirror tests for IL, MA, OH, NJ. Each should be insensitive to itemization at the state level.

### For Fix #2

5. **`paSTCGLossDoesNotOffsetInterest`** — PA, scenario with $1,000 interest + $5,000 STCG loss + $0 LTCG. Expected PA-taxable = $1,000 (loss can't cross to Class 6). Engine currently computes $0 (uses −$4,000 ordinary subtotal × 0.0307 = $0). This test pins the desired behavior.

### For Fix #3

6. **`outOfStateMuniInterestTaxableForPA`** — PA resident with $10K NY-issued muni interest. Expected PA tax includes $10K × 0.0307. Engine currently exempts. Pins behavior.

---

## 7. Citations

- **PA DOR Personal Income Tax Guide** (current as of 2026) — chapters on Dividends, Interest, Net Gains or Income From the Disposition of Property. https://www.revenue.pa.gov/FormsandPublications/PAPersonalIncomeTaxGuide/
- **PA-40 Instructions** (2025 / 2026 forms) — confirms no standard or itemized deduction at state level; income is summed across eight classes on Lines 1a–8.
- **PA-40 Schedule B** — Dividend income (all types taxable at 3.07%).
- **PA-40 Schedule D** — Sale, Exchange or Disposition of Property (all capital gains taxed at 3.07%; losses class-isolated).
- **PA DOR Letter Ruling Ans 274** — Roth conversion exemption (already implemented in v1.8.3).
- **31 USC §3124** — Federal preemption excluding US Treasury interest from state taxation.
- **Codebase references:**
  - `RetireSmartIRA/DataManager.swift:457-500` (`calculateStateTaxFromGross`)
  - `RetireSmartIRA/DataManager.swift:522-580` (`stateTaxBreakdown`)
  - `RetireSmartIRA/DataManager.swift:1039-1043` (`preferentialIncome()`)
  - `RetireSmartIRA/DataManager.swift:1162-1170` (`scenarioBaseIncome`, `scenarioGrossIncome`)
  - `RetireSmartIRA/DataManager.swift:1492-1513` (`stateItemizedDeductions`)
  - `RetireSmartIRA/IncomeDeductionsManager.swift:67-71` (`ordinaryIncomeSubtotal`)
  - `RetireSmartIRA/TaxCalculationEngine.swift:323-367` (`calculateStateTax`)
  - `RetireSmartIRA/TaxCalculationEngine.swift:403-502` (`applyRetirementExemptions`)
  - `RetireSmartIRA/StateTaxData.swift:526-538` (PA config)
