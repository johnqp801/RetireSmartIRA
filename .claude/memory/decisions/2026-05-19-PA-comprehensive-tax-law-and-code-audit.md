# PA Comprehensive Tax Law + Code Audit (v1.8.3 prep)

Date: 2026-05-19
Worktree: `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/1.8.3-incremental/` @ `e854d37`
Author: deep-audit subagent

---

## 1. TL;DR

Pennsylvania exempts essentially **all** retirement-age distributions from qualified
retirement plans (IRA/Roth/401k/403b/457b/pension/military/federal/state) from its
3.07% personal income tax, and per **PA DOR Answer ID 274** also exempts the
trustee-to-trustee portion of a **Roth conversion** (only amounts not actually
deposited into the Roth — i.e., federal withholding — remain PA-taxable).

The v1.8.2 production engine only exempts **`scenarioTotalWithdrawals`** (the extra
withdrawal slider) and `.rmd`/`.pension`/`.militaryRetirement` IncomeSource rows
via `applyRetirementExemptions`. It does **NOT** exempt **`scenarioTotalRothConversion`**.
Because Roth conversions are added into `scenarioGrossIncome` and not subtracted
back out for PA, every retirement-age PA user who runs a conversion in the Scenarios
tab is being charged 3.07% × (conversion amount) of state tax that they don't owe.
This is the bug that hits a 60-year-old PA resident the moment they touch the
Roth conversion slider — exactly the John/Jonggie failure mode.

A second, narrower gap: when `.pension` (which in PA also covers all employer
401(k)/403(b)/457(b) distributions and government pensions) is paired with a
state that has `.partial(maxExempt:)`, we sum `.pension` + IRA into separate
buckets — fine — but `.militaryRetirement` is excluded from the `.pension` bucket
and only handled by a separate per-state path. PA happens to handle military
correctly through both paths (full exemption), but if a user mis-classifies a
federal CSRS check as `.pension` vs leaving it as `.consulting`, only the
former is exempted. That's a UX/categorization gap, not a math gap.

---

## 2. PA Tax Law — 20 scenarios

Retirement-age = 59½+ unless noted. Primary source for every row except where flagged
is the PA Personal Income Tax Guide, "Gross Compensation" chapter (PA DOR), reinforced
by 72 P.S. § 7301(d) and 61 Pa. Code § 101.6(c).

| # | Scenario | PA Treatment | Citation |
|---|---|---|---|
| 1 | Traditional IRA distribution, $50K @ 60 | **EXEMPT** — "eligible Pennsylvania retirement plan" distribution after 59½, no early-withdrawal penalty | PA DOR Gross Compensation, §IV(D) |
| 2 | Roth IRA qualified distribution @ 60, 5-yr met | **EXEMPT** — Roth IRA is an "eligible PA retirement plan"; contributions were already PA-taxed at deposit (PA does not allow IRA deduction); earnings exempt at retirement age | PA DOR Gross Compensation; Ans 274 |
| 3 | Roth IRA non-qualified distribution (5-yr unmet) @ 60 | **EXEMPT** of the principal (already-PA-taxed) using cost-recovery; earnings portion exempt **because age ≥ 59½ removes the penalty test** — PA's exemption is keyed to "no federal early-withdrawal penalty applies," not the federal 5-yr Roth rule | PA DOR Gross Compensation, IRA section |
| 4 | Traditional 401(k) @ 60 (rollover-eligible) | **EXEMPT** — qualified §401(a) plan after retirement age | PA DOR Gross Compensation, §IV(B) |
| 5 | Roth 401(k) qualified distribution @ 60 | **EXEMPT** — same chapter; PA already taxed the elective deferral going in (PA disallows the 401(k) pre-tax deferral state-side; `pretax401kContributionsTaxableForState = true`) | PA DOR Gross Compensation |
| 6 | 403(b) at retirement age | **EXEMPT** — §403(b) is a "qualified employer plan" under PA guide; distributions after retirement excluded | PA DOR Gross Compensation |
| 7 | 457(b) governmental at retirement age | **EXEMPT** when received as old-age/retirement benefit. (Non-governmental 457(b) historically had constructive-receipt timing issues but the *retirement* distribution is exempt.) | PA DOR Gross Compensation; PIT Bulletin |
| 8 | Defined-benefit pension @ 60 | **EXEMPT** — "payments commonly recognized as old age or retirement benefits" | 72 P.S. § 7301(d); PA DOR Gross Compensation |
| 9 | Military retirement (federal uniformed services pension) | **EXEMPT** — "retired or retainer pay of a member or former member of a uniformed service" excluded | PA DOR Gross Compensation |
| 10 | Federal CSRS / FERS pension @ retirement age | **EXEMPT** — excluded as "payments arising under… any government" old-age benefit | PA DOR Gross Compensation |
| 11 | State/local government pension @ retirement age (PSERS/SERS/PMRS) | **EXEMPT** — PSERS/SERS expressly confirmed PA-exempt | PSERS/SERS taxes page; PA DOR |
| 12 | Traditional IRA → Roth IRA conversion, $50K @ 60 | **EXEMPT** — "conversion … is generally not taxable" provided the entire gross amount lands in the Roth (withheld-for-fed-tax portion remains PA-taxable as a regular distribution) | **PA DOR Ans 274** |
| 13 | Traditional 401(k) → Roth IRA rollover @ 60 | **EXEMPT** — same Ans 274 logic + qualified-plan rollover treatment; conversion is not a taxable event in PA. Caveat: same withholding-leakage rule | PA DOR Ans 274; Gross Compensation |
| 14 | Traditional 401(k) → Roth 401(k) in-plan conversion @ 60 | **EXEMPT** — in-plan conversion follows the same not-taxable-in-conversion-year treatment | PA DOR Ans 274 (extended); PICPA practitioner guidance |
| 15 | Traditional IRA → Traditional 401(k) trustee-to-trustee rollover @ 60 | **EXEMPT** — pure rollover, never a PA distribution | PA DOR Gross Compensation, "Rollovers" |
| 16 | Backdoor Roth (nondeductible TIRA → immediate conversion) @ 60 | **EXEMPT** — the TIRA contribution wasn't deducted at federal level either; conversion is the Ans-274-blessed step | PA DOR Ans 274 |
| 17 | Early withdrawal under 59½, $50K from TIRA @ 55 | **TAXABLE** in PA on the gain over basis (cost-recovery), unless a PA-recognized exception applies: separation-from-service at 55 from an employer plan (NOT IRA), death, disability, IRS SEPP/72(t), unforeseeable emergency. The IRA "age 55 separation" exception is **federal-only** and does NOT make a PA IRA withdrawal PA-exempt | 61 Pa. Code §101.6(c); PA DOR Gross Compensation |
| 18 | RMD @ 75 | **EXEMPT** — RMD is just a distribution from a qualified plan after retirement age; covered by §IV(B)/(D) of the Gross Compensation guide | PA DOR Gross Compensation |
| 19 | QCD @ 75 ($50K direct to charity) | **EXEMPT** — but trivially so because PA exempts the entire RMD anyway; QCD provides no incremental PA benefit | PA DOR Gross Compensation; practitioner consensus |
| 20 | Inherited IRA distribution (any beneficiary age) | **EXEMPT** for PA personal income tax — "distributions paid to a beneficiary because of the account holder's death" are PA-exempt. (Separate from the PA *inheritance* tax, which is its own tax and not in scope here.) | PA DOR Gross Compensation, "Distributions because of death"; multiple PA practitioner sources |

### Confidence

- **High** for #1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 15, 16, 17, 18, 19, 20 — directly supported by PA DOR Gross Compensation guide and/or Ans 274.
- **Medium** for #3 (PA's treatment of "non-qualified Roth distribution where age ≥ 59½") — practitioner consensus says exempt because PA's test is the federal-penalty test, not the federal 5-year Roth ordering rule, but this is not crisp in the guide.
- **Medium** for #7 non-governmental 457(b) — governmental is clearly exempt; non-governmental has historical constructive-receipt nuance, but the *retirement* distribution itself is exempt.
- **Medium** for #14 in-plan Roth 401(k) conversion — Ans 274 literally addresses TIRA→Roth IRA. Practitioner extension to in-plan is universal but not directly in Ans 274.

---

## 3. Code Audit — engine paths

### 3.1 Architecture as currently shipped

Money flow into PA state tax:

```
IncomeSource rows  ─►  IncomeDeductionsManager.ordinaryIncomeSubtotal      (excludes SS, LTCG, qDiv, tax-exempt int, VA disability)
                                       │
                                       ▼
                       scenarioBaseIncome = ordinaryIncomeSubtotal + taxableSS + preferentialIncome()
                                       │
Scenario sliders ──►   scenarioGrossIncome = scenarioBaseIncome + scenarioTotalRothConversion
                                                                 + scenarioTotalWithdrawals
                                                                 − scenarioStockGainAvoided
                                       │
                                       ▼
                       calculateStateTaxFromGross(grossIncome=…, scenarioRetirementDistributions=scenarioRetirementDistributionIncome)
                                       │
                                       ▼   (state std-deduction, then →)
                       TaxCalculationEngine.calculateStateTax → applyRetirementExemptions
                                       │
                                       │  PA branches: subtract taxableSS, all .pension rows, all .rmd rows,
                                       │                military per-source, AND `scenarioRetirementDistributions`
                                       │                gated at age 59½.
                                       ▼
                       Final taxable income × 0.0307
```

Critical accessor:

```swift
var scenarioRetirementDistributionIncome: Double {
    memoizedScenarioRetirementDistributionIncome { scenarioTotalWithdrawals }   // DataManager.swift:442–446
}
```

So today the engine subtracts back `scenarioTotalWithdrawals` (RMDs computed from
balances + inherited-IRA RMDs + extra withdrawals slider) but NOT
`scenarioTotalRothConversion`. The TODO at TaxCalculationEngine.swift:419–421 already
flags this explicitly:

> "Roth conversion exemption for PA per PA DOR Ans 274 (conversions NOT taxable
>  in conversion year) — affects heir-comparison math substantially for PA users."

### 3.2 Per-scenario audit table

For each scenario: where the dollar lives in the app, how it currently flows
through the engine for a PA retirement-age user, and the gap vs Part A.

| # | Scenario | Input lives at | Engine path (PA, age 60) | Current PA tax treatment | Law | Gap |
|---|---|---|---|---|---|---|
| 1 | Trad IRA distrib via scenario slider | `ScenarioStateManager.extraWithdrawal*` → `DataManager.scenarioTotalWithdrawals` (DataManager.swift:1102) | scenarioGrossIncome → calculateStateTaxFromGross → `scenarioRetirementDistributions` ✔ subtracted in applyRetirementExemptions | **EXEMPT** (correctly) | EXEMPT | none |
| 1a | Trad IRA distrib entered as IncomeSource `.rmd` row | IncomeModels.swift:108 + IncomeDeductionsManager | ordinaryIncomeSubtotal → scenarioBaseIncome → calculateStateTaxFromGross; PA `.rmd` rows subtracted at TaxCalculationEngine.swift:452 | **EXEMPT** (correctly) | EXEMPT | none |
| 2 | Roth IRA qualified distrib | Not a discrete input — modeled as scenarioTotalWithdrawals (no account-type tagging) | Same as #1, exempt under scenarioRetirementDistributions | **EXEMPT** | EXEMPT | none |
| 3 | Roth non-qualified | Same | Same | EXEMPT | EXEMPT (PA's test is the penalty test) | none, acceptable |
| 4 | Trad 401(k) distrib | Same as #1 (no account-type tagging on the slider) | Same | EXEMPT | EXEMPT | none |
| 5 | Roth 401(k) qualified distrib | Same | Same | EXEMPT | EXEMPT | none |
| 6 | 403(b) | Same | Same | EXEMPT | EXEMPT | none |
| 7 | 457(b) governmental | Same | Same | EXEMPT | EXEMPT | none |
| 8 | Pension | `.pension` IncomeSource row (IncomeModels:99) | ordinaryIncomeSubtotal → scenarioBaseIncome → calculateStateTaxFromGross; subtracted in applyRetirementExemptions:433–441 | **EXEMPT** (correctly) | EXEMPT | none |
| 9 | Military retirement | `.militaryRetirement` row (IncomeModels:109) | ordinaryIncomeSubtotal in; subtracted via MilitaryRetirementExemption per-source loop (TaxCalculationEngine.swift:470–484) | **EXEMPT** (PA returns full exemption) | EXEMPT | none |
| 10 | Federal CSRS/FERS | User must categorize as `.pension` (no dedicated type) | Treated as `.pension` → exempt; if user mis-tags as `.consulting` → taxed | EXEMPT if tagged `.pension`, taxed if mis-tagged | EXEMPT | UX gap, not engine gap |
| 11 | State/local pension (PSERS) | `.pension` | Same as #8 | EXEMPT | EXEMPT | none |
| 12 | **Roth conversion (scenario slider)** | `ScenarioStateManager` → `DataManager.scenarioTotalRothConversion` (DataManager.swift:1057) | Added to scenarioGrossIncome at line 1156; **NOT** included in `scenarioRetirementDistributionIncome` (line 442–446); flows through PA tax untouched | **TAXED at 3.07%** (incorrect) | **EXEMPT** per PA DOR Ans 274 | **CRITICAL GAP** |
| 13 | 401(k) → Roth IRA rollover | Same slider as #12 | Same | TAXED (incorrect) | EXEMPT | same gap as #12 |
| 14 | In-plan Roth conversion | Same slider | Same | TAXED (incorrect) | EXEMPT | same gap as #12 |
| 15 | TIRA → T401(k) rollover | Not modeled; pure rollover (no scenario knob) | n/a | n/a | EXEMPT | none |
| 16 | Backdoor Roth | Conversion side uses #12 slider | Same as #12 | TAXED (incorrect) | EXEMPT | same gap as #12 |
| 17 | Early withdrawal (under 59½) | Same slider as #1 | Gated at age 59½ (TaxCalculationEngine.swift:453) — `scenarioExemptable = retirementAge ? scenarioRetirementDistributions : 0` — so PA correctly TAXES at <59½ | TAXED (correctly, when both spouses <59½) | TAXABLE | none. Note: PA-specific exceptions (death/disability/SEPP) are NOT modeled — acceptable simplification |
| 18 | RMD @ 75 | `calculateCombinedRMD()` feeds scenarioTotalWithdrawals | Same as #1 | EXEMPT | EXEMPT | none |
| 19 | QCD | `scenarioTotalQCD` (separately tracked, reduces taxable RMD before adding to withdrawals) | Same as #1; PA-net-zero either way | EXEMPT | EXEMPT | none |
| 20 | Inherited IRA distribution | `scenarioInheritedRMD*` + inherited extras flow into scenarioTotalWithdrawals | Same as #1 — exempt via scenarioRetirementDistributions | EXEMPT | EXEMPT | none |

### 3.3 Specifically-requested critical paths

- **`.pension` IncomeSource row** → flows through `ordinaryIncomeSubtotal` → eventually
  reaches `applyRetirementExemptions` where PA's `.full` pensionExemption subtracts the
  exact pension dollar amount. **Correctly exempted today.**
- **`.rmd` IncomeSource row** → same flow → PA's `.full` iraWithdrawalExemption subtracts.
  **Correctly exempted today.**
- **`.militaryRetirement` IncomeSource row** → flows through `ordinaryIncomeSubtotal`,
  then PA-side handled by `MilitaryRetirementExemption.stateTaxableAmount(state="PA",…)`
  per-source loop. PA returns 0 taxable → fully exempted. **Correctly exempted today.**
- **`scenarioTotalRothConversion`** → added to `scenarioGrossIncome` (line 1156),
  passes through `calculateStateTaxFromGross` (line 1545), reaches
  `applyRetirementExemptions` **WITHOUT** being included in the
  `scenarioRetirementDistributions` argument (only `scenarioTotalWithdrawals` is).
  **TAXED AT 3.07% — INCORRECT per PA DOR Ans 274.** This is the John/Jonggie bug.
- **`scenarioTotalWithdrawals`** → routed via `scenarioRetirementDistributionIncome`
  (DataManager.swift:442–446) → passed as `scenarioRetirementDistributions:` argument
  at four call sites (1554, 1792, 2323, and the breakdown-mirror in stateTaxBreakdown).
  Age-gated at 59½. **Correctly exempted today** (this is the v1.8.2 fix).

---

## 4. Engineering Specification for v1.8.3

### 4.1 The minimum fix (covers all confirmed PA gaps + matches all "full" / "partial" states)

**Step A — Introduce a discrete accessor for the scenario-level Roth conversion side
of the exemption pipeline.** Don't fold it into `scenarioRetirementDistributionIncome`
because that one is age-gated at 59½ for **withdrawals**, and the PA-Ans-274 exemption
for **conversions** has a different rationale (conversions are not "early withdrawals"
even at age 30 — the conversion itself is not a taxable event regardless of age).

Add to `DataManager`:

```swift
/// Scenario-level Roth conversion that PA (per DOR Ans 274) and any state with
/// `.full` IRA exemption treats as non-taxable in the conversion year. Other
/// `.full`/`.partial`/`.none` states follow their normal rule — except the few
/// jurisdictions that disagree (none in our supported set as of 2026-05).
///
/// NOT age-gated: PA Ans 274 doesn't condition exemption on retirement age.
/// However, MOST other states that exempt IRA *distributions* DO require
/// retirement age. To be safe, expose the conversion separately and let
/// `applyRetirementExemptions` decide per-state.
var scenarioRothConversionForStateExemption: Double {
    scenarioTotalRothConversion
}
```

**Step B — Plumb a new parameter `scenarioRothConversionAmount` through
`calculateStateTaxFromGross` → `calculateStateTax` → `applyRetirementExemptions`.**
Update all 4 call sites of `calculateStateTaxFromGross` (DataManager.swift:1545,
1783, 2314, and `totalTaxFor` helper) and the `stateTaxBreakdown` mirror (lines 521–650)
so the conversion amount flows in alongside `scenarioRetirementDistributions`.

**Step C — Inside `TaxCalculationEngine.applyRetirementExemptions` add a per-state
decision for the conversion bucket.** Concretely:

```swift
// Roth conversion (PA Ans 274 + practitioner consensus for other full-exemption states).
// Pennsylvania: not taxable in conversion year — subtract regardless of age.
// IL, MS, MI, HI (employer plan only — N/A for conversions): mirror PA.
// All other states: TAXABLE in the conversion year — do not subtract.
let conversionExemption: Double = {
    switch state {
    case .pennsylvania, .illinois, .mississippi:
        return scenarioRothConversionAmount   // full, no age gate
    case .michigan:
        // MI's 2023 retirement reform — conversion is treated as a qualified
        // retirement distribution if the participant has reached retirement age.
        return retirementAge ? scenarioRothConversionAmount : 0
    default:
        return 0
    }
}()
adjusted -= conversionExemption
```

**Step D — Mirror the same logic in `DataManager.stateTaxBreakdown` (lines 521–650)
so the per-line tooltip / detail sheet shows the conversion as an "Exempted" row
rather than letting it disappear into "other income."**

**Step E — Add a regression test that drives `totalTaxFor` and `scenarioStateTax`
with a PA + age-60 + $100K conversion fixture and asserts state tax = $0 (or matches
the non-conversion portion exactly).**

### 4.2 Files & call sites that MUST be touched

| File | Lines | Change |
|---|---|---|
| `RetireSmartIRA/TaxCalculationEngine.swift` | 401–487 (`applyRetirementExemptions` signature + body) | New `scenarioRothConversionAmount` parameter; PA + IL + MS exemption switch. Delete the TODO at 419–421. |
| `RetireSmartIRA/TaxCalculationEngine.swift` | 330–340 (`calculateStateTax` wrapper) | Pass `scenarioRothConversionAmount` through. |
| `RetireSmartIRA/DataManager.swift` | 428–430 (`calculateStateTax(forState:…)` wrapper) | Accept and forward the new arg. |
| `RetireSmartIRA/DataManager.swift` | 442–446 (`scenarioRetirementDistributionIncome`) | LEAVE this alone; do NOT fold conversion in (different age-gating semantics). |
| `RetireSmartIRA/DataManager.swift` | 457–499 (`calculateStateTaxFromGross`) | Add `scenarioRothConversionAmount` parameter; forward to `calculateStateTax`. |
| `RetireSmartIRA/DataManager.swift` | 505–516 (`applyRetirementExemptions` private wrapper) | Forward through to engine. |
| `RetireSmartIRA/DataManager.swift` | 521–650 (`stateTaxBreakdown`) | Add the conversion exemption row to the breakdown; subtract from `adjustedIncome`. |
| `RetireSmartIRA/DataManager.swift` | 1545 (`scenarioStateTax` call site) | Pass `scenarioRothConversionAmount: scenarioTotalRothConversion`. |
| `RetireSmartIRA/DataManager.swift` | 1783 (`stateTax` in ACA helper) | Same. |
| `RetireSmartIRA/DataManager.swift` | 2314 (`totalTaxFor` helper) | Same — plus add an optional `scenarioRothConversionAmount` arg to `totalTaxFor` itself so the "without-conversion" hypotheticals can pass `0`. |
| `RetireSmartIRA/DataManager.swift` | 2342, 2360, 2386, 2440, 2557, 2587 (callers of `totalTaxFor`) | When the hypothetical removes Roth conversion (rothConversionTaxImpact), pass `scenarioRothConversionAmount: 0`. When keeping it, pass `scenarioTotalRothConversion`. |
| Tests | `RetireSmartIRATests/StateTaxTests.swift` (or PA-specific file if it exists) | Add fixtures from §5 below. |

### 4.3 What NOT to change

- Do **NOT** modify how `.pension` / `.rmd` / `.militaryRetirement` IncomeSource rows
  are exempted — they already work correctly for PA.
- Do **NOT** add a `.fullIncludingConversion` enum case to `ExemptionLevel`. The
  conversion exemption is orthogonal to the distribution exemption (different age
  semantics, different states qualify). Keep it as its own pipeline.
- Do **NOT** widen the age gate on `scenarioRetirementDistributions` — `<59½` early
  withdrawals must remain PA-taxable for the small set of PA users actually doing
  pre-retirement withdrawals.

---

## 5. Required test cases (the fix MUST pass)

All assume `currentYear = 2026`, `pretax401kContributionsTaxableForState = true` for PA.

### 5.1 John's exact failing scenario

Inputs:
- State: PA
- Filing: MFJ
- Primary age 60, spouse age 60 (both retirement-age)
- `.qualifiedDividends` IncomeSource: $36,500
- `.capitalGainsLong` IncomeSource: $64,000
- `.pension` IncomeSource: $3,500
- `.socialSecurity` primary: $68,000
- `.socialSecurity` spouse: $24,000
- `.taxExemptInterest` (other "exempt" income): $27,000
- No scenario sliders activated

Expected: PA taxable income = $36,500 (qDiv) + $64,000 (LTCG) = $100,500
(SS exempt, pension exempt, tax-exempt interest excluded entirely)

PA state tax = $100,500 × 0.0307 = **$3,085.35** (≈ $3,090; not $3,647)

`scenarioStateTax` MUST equal this within ±$1.

### 5.2 PA + Roth conversion (the v1.8.3 critical fix)

Same as 5.1 plus:
- Scenarios tab: Roth conversion slider = $50,000

PA-taxable income unchanged at $100,500 (conversion is PA-exempt per Ans 274).

PA state tax MUST equal **$3,085.35** — exactly the same as 5.1. Today it would
return $3,085.35 + $50,000 × 0.0307 = $4,620.35, off by $1,535.

### 5.3 PA + retirement-age withdrawal slider (regression — 1.8.2 must still pass)

Same as 5.1 plus:
- Scenarios tab: extra withdrawal slider = $40,000

PA state tax MUST still equal **$3,085.35** (extra withdrawal is exempt at 59½+).
This locks in the v1.8.2 fix against future regressions.

### 5.4 PA + early withdrawal (must remain TAXABLE)

Same as 5.1 but ages are 55/55 and extra-withdrawal slider = $40,000.

PA state tax MUST equal ($100,500 + $40,000) × 0.0307 = **$4,313.35**
(SS still combined-income-tested; LTCG/qDiv flow regardless of age).

### 5.5 PA + Roth conversion at age 50 (Ans 274 not age-gated)

Same household profile but ages 50/50, no SS/pension, just `.consulting`
$80,000 + Roth conversion slider $50,000.

PA state tax MUST equal **$80,000 × 0.0307 = $2,456** (conversion exempt
regardless of age per Ans 274; consulting fully taxable).

### 5.6 IL/MS Roth conversion (parity check — same code path)

IL or MS at any age with $50K conversion → state tax on conversion = $0
(both are `.full` exemption states with similar non-taxation of conversions in
practitioner consensus).

### 5.7 Non-PA-pattern state Roth conversion (MA, CA, OR, etc.)

MA + age 60 + $50K Roth conversion → state tax MUST treat the $50K as ordinary
income (conversion taxable at conversion year per IRC §408A(d)(3) federal flow-through
to state). MA tax must not decrease vs the pre-fix state.

### 5.8 PA + inherited IRA distribution

PA + beneficiary age 35 (NOT 59½) + inherited-IRA RMD = $20,000.
PA state tax = $0 — inherited distributions exempt regardless of beneficiary age.

(Note: the current age-gate at 59½ in `applyRetirementExemptions` may incorrectly
tax this scenario for a young beneficiary because `scenarioExemptable` only fires
at retirementAge. **Verify** in the fix whether `scenarioInheritedRMD` should bypass
the age gate. If `scenarioTotalWithdrawals` includes inherited-IRA RMDs and the
beneficiary is under 59½, today's code would tax it — flag this as test #5.8 and
either confirm it doesn't apply or fix in scope.)

---

## 6. Analogous-state quick check

| State | Pension/IRA in code | Conversion exemption needed in fix? | Notes |
|---|---|---|---|
| Illinois | `.full / .full` | **YES** — IL exempts all qualified retirement income including conversions per IL Pub 120 | Same gap as PA |
| Mississippi | `.full / .full` | **YES** — MS Code §27-7-15(4)(j); conversions treated as non-event | Same gap as PA |
| Michigan | `.full / .full` (per 2023 reform phase-in) | **CONDITIONAL** — MI exempts retirement-age qualified distributions; conversion treatment less crisp. Recommend age-gated exemption | Verify with MI Treasury before flipping |
| Alabama | `.partial(2_500)` for pension; IRA `.none` | No conversion-specific exemption — AL taxes 401(k)/IRA distributions and would tax conversion | No fix needed |
| Colorado | `.partial(24_000)` both | Conversion would consume part of the $24K cap if exempt at all; CO 2026 SB25-136 phasing — conservatively treat as taxable; **TODO follow-up** |
| Georgia | `.partial(65_000)` age 62+ exclusion | Conversion would consume part of cap; GA practitioner consensus treats as taxable for the cap test — leave taxable |
| New York | `.partial(20_000)` per filer age 59½+ | Conversion is NOT in the $20K NY pension exclusion (NY DTF clarified) — leave taxable |
| New Jersey | Tiered phase-out (income-based) | Conversion is taxable in NJ; pension exclusion has its own phase-out — leave taxable |
| Kentucky | `.partial(31_110)` | Conversion taxable in KY (no equivalent of PA Ans 274) — leave taxable |
| Virginia | Pension/IRA mostly `.none` (with age 65 deduction) | Leave taxable |
| Maryland | `.partial(40_600 age 65+)` employer plans only | Conversion taxable; MD subtraction is employer-plan-only — leave taxable |
| Ohio | Retirement income credit (small) | OH gives a tax credit, not an exclusion — out of scope for this fix |

**Conclusion:** PA, IL, MS get the conversion exemption in v1.8.3. MI is a *maybe*
(documented as a TODO with conservative default of "no conversion exemption" until
verified with MI Treasury).

---

## 7. Citations

- [PA DOR Answer ID 274 — Taxability of Roth IRAs](https://revenue-pa.custhelp.com/app/answers/detail/a_id/274/~/taxability-of-roth-iras-according-to-pa-income-tax-rules)
- [PA Personal Income Tax Guide — Gross Compensation](https://www.pa.gov/agencies/revenue/forms-and-publications/pa-personal-income-tax-guide/gross-compensation)
- [PSERS — Taxes on Benefit](https://www.pa.gov/agencies/psers/member-resources/retired/taxes-on-benefit)
- [SERS Defined Benefit Plan — Taxes](https://sers.pa.gov/DefinedBenefitPlan-RetiredMembers-Taxes.html)
- [PMRS — Taxes](https://pmrs.pa.gov/retirees/taxes/)
- [PA DOR DFO-02 PIT Preparation Guide](https://www.pa.gov/content/dam/copapwp-pagov/en/revenue/documents/formsandpublications/formsforindividuals/pit/documents/dfo-02.pdf)
- 72 P.S. § 7301(d) — definition of "compensation" (statutory)
- 61 Pa. Code § 101.6 — IRA distribution exclusions (regulation)
- PA DOR REV-636 — Retirement & Pension Benefits (PA Form)
