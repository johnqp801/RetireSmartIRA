# NY government-pension exclusion missing (found by Alan Levy, 2026-07-30)

**Status:** confirmed engine gap, awaiting Alan's confirmation of his pension type. Reply sent 2026-07-30.

**Severity:** real calculation error for NYS / NYC / federal-civilian retirees. Overstates state AND city tax.

---

## The law, verified against primary source

Form IT-201 carries **two separate subtraction lines**, and that is the whole point:

| Line | Covers | Cap |
|---|---|---|
| **26** | Pensions of NYS, its localities, and the federal government | **none, fully excluded** |
| **29** | Pension and annuity income exclusion | **$20,000, per person, age 59½** |

Line 29 applies only to pension income **"not from a New York State or local government pension plan or federal government pension plan."** The two tracks are independent: **government pension income does NOT consume any of the $20,000.**

Line 26 eligibility: officer, employee, **or beneficiary of one**, of NYS, a NY locality, specified public authorities (MTA Police, MaBSTOA, LIRR), or the US government.

**Carve-out that matters for the fix:** payments from *supplemental annuity plans funded through salary reduction* are NOT Line 26 eligible. A NYC teacher's 403(b) TDA or a 457 deferred-comp balance does not qualify even though the employer is governmental. Only the pension itself does. So "is it a government pension?" is not a sufficient question; the plan type has to be established too.

Sources: [IT-201 instructions](https://www.tax.ny.gov/forms/current-forms/it/it201i.htm), [Information for retired persons](https://www.tax.ny.gov/pit/file/information_for_seniors.htm).

## What the app already gets RIGHT (do not "fix" these)

- **Non-government pensions are correct.** `pensionExemption: .partial(maxExempt: 20_000)`, `exemptionAppliesPerIndividual: true`, `regularExemptionMinAge: 59`, and critically `pensionAndIRAShareSingleCap: true` enforcing ONE combined $20,000 across pension + IRA rather than $20,000 each. That double-exemption bug was already found and fixed; see the comment block at `StateTaxData.swift:1755-1771`.
- **Social Security** is exempt for NY (`socialSecurityExempt: true`), and the local/city rate runs on the post-exclusion base (`TaxCalculationEngine.swift:399`), so SS is not hit by city tax either.
- **Military retirement is already fully exempt in NY** (`MilitaryRetirementExemption.swift:129-130`). A military retiree is handled correctly today.

## The actual gap, scoped

**Non-military government pensions only:** NYS employees, NYC and other NY local employees, federal civilian retirees.

- No `IncomeType` can represent one. `IncomeModels.swift` has `.pension` and `.militaryRetirement`, nothing between them.
- `RetirementIncomeExemptions` expresses exemptions **per state**, not **per source**, so there is no way to say "this pension is fully excluded, that one is capped" within the same return.

**Two-part harm for an affected retiree:**
1. Everything above $20,000 is taxed by state and city, when NY taxes none of it.
2. Worse in combination: if they also draw an IRA, `pensionAndIRAShareSingleCap` makes the government pension consume the $20,000 that should have covered the IRA. They lose the exclusion twice.

## Fix shape (not yet built)

Needs a **per-source** government-pension flag, not a state-level setting, because one taxpayer can hold both a Line 26 pension and Line 29 income. Rough shape:
- new `IncomeType` case or a boolean on `IncomeSource` distinguishing a qualifying government pension
- route it to full exclusion in NY, and exclude it from the `pensionAndIRAShareSingleCap` pool
- UI must let the user say whether the plan is the pension itself vs a salary-reduction supplemental plan (403(b)/457), since the latter is not Line 26 income
- other states have analogous government-pension rules; check before generalizing the flag

TDD, and the state-tax suite is the gate.

## Related

Alan's round-2 feedback (local city tax, state withholding %) shipped in 2.1.2 and is credited in the comment at `TaxCalculationEngine.swift:394`. That round was never logged when received; this file exists so this one is not lost the same way.
