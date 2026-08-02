# Steve Nicolai feedback, 2026-08-01 (4 issues + 8 suggestions)

Emailed support@ 3:48 PM. **Acknowledged same evening**, and that reply CONFIRMED the Kansas bug in writing. Treat that the way [[pending-fixes-next-release]] treats Alan's caret fix: a commitment attached to a named person.

John also promised "answers and a plan over the next couple of days."

---

## 1. KANSAS IS MISSING ITS PERSONAL EXEMPTION — confirmed to the cent

**Steve's report:** $50,000 of income, tool says $2,171.52, his own calculation $1,218.88, citing ksrevenue.gov.

**Both numbers reproduce exactly from the config:**

| | Calculation | Result |
|---|---|---|
| App | (50,000 − 8,240 std ded) × 5.2% | **$2,171.52** |
| Correct | (50,000 − 8,240 − **18,320**) × 5.2% | **$1,218.88** |

Brackets and standard deduction are correct. The personal exemption is absent. Kansas DOR (SB 1, 2024 special session, effective TY2024): **$18,320 MFJ, $9,160 single/HOH/MFS, $2,320 per dependent.** Standard deduction $3,605 / $8,240 is already right in the config.

**Overstates every married Kansas filer by $952.64 a year**, flat, regardless of income within the first bracket.

### The bigger finding: there is no personal-exemption concept in the engine

`StateTaxConfig` has no exemption field. `StateDeduction` offers only `.none`, `.conformsToFederal`, `.fixed`. New Jersey's exemptions exist as a HARDCODED special case in `DataManager.swift:659-671` via a `postExemptionDeduction` argument; California's are handled separately as credits (`DataManager.swift:959`).

**So Kansas is unlikely to be the only wrong state.** Every state with a personal exemption that is not NJ or CA is a candidate for the same error, and Kansas surfaced only because one user did the arithmetic by hand. Candidates to audit: GA, AL, MA, MS, VA, HI, IA, ME, NE, UT.

**Fix shape:** add a `personalExemption` field to `StateTaxConfig` (per-filer and per-dependent), route it through the same post-exemption deduction path NJ already uses, then audit every state config against its DOR source. TDD; the state-tax suite is the gate. Do NOT patch Kansas alone, that accretes a second hardcoded special case.

## 2. RMD calculator shows only the primary's RMDs

Spouse is 9 years older and starts RMDs first. Steve asks it to show both and lead with whoever starts sooner. Also says spouse RMDs are absent from Tax Summary. **Not yet audited.** Distinct from the spouse/joint-account-ownership RMD fix that shipped in 2.3.

## 3. Cannot model living off taxable withdrawals

"We withdraw from taxable to get enough to live on, but I don't seem to be able to create a scenario for that."

**This independently corroborates Fred's finding** (2026-07-14 session, "withdrawal-not-pulled", confirmed = the 2.1 decumulation gap). Two unrelated users now. Raises the priority of Fred's Scenarios-withdrawal integration.

## 4. Taxable account yield percentages do not flow into income

"Taxable accounts have a number of percentages for dividends/cap gains, but none of this is automatically added to income."

`TaxableAccount` carries `qualifiedDividendYield`, `ordinaryIncomeYield`, `taxExemptYield`, `realizedLongTermGainYield`. Those drive the multi-year projection. Whether they should also populate single-year Scenarios income is a DESIGN question, not obviously a bug. **Not yet audited.** Note this is the same expectation gap as suggestion A.

---

## Suggestions A-H

- **A.** Move Accounts above Income and Deductions so it is filled first; show taxable-account income inside Income and Deductions; add HSA as an account type.
- **B.** Rename "Income and Deductions" to just "Income"; allow year ranges on income. *(Year ranges = per-year income entry, also promised to Alan 2026-07-18.)*
- **C.** Add an Expenses page for future years with options for how expenses are funded (traditional IRA, taxable, etc.). Notes multi-year already has some of this.
- **D.** Move Charitable Contributions out of Scenarios to its own page, or into Expenses.
- **E.** Donor Advised Fund account type as a stock-donation destination. Asks whether the engine can optimize **bunching** donations into one year and paying out over several, with an educational callout.
- **F.** Communicate how accurate the state tax modeling is. Wants informational text when clicking a state describing the treatment of each income type. *(Directly relevant: he found a state bug the same day he asked for this.)*
- **G.** **Per-account flag for state-exempt 403(b) withdrawals.** His wife worked for the state; some of her 403(b) accounts are not taxable in their state, others are, so it must be an account-level property.
- **H.** Add a Federal bonds income type, generally not taxable at state level.

### G is the same shape as Alan's NY problem

Both are **state exemptions that depend on the SOURCE, not the state**: a government pension in NY, a state-employee 403(b) in Kansas. Neither is expressible today because `RetirementIncomeExemptions` is per-state, not per-source. See `roadmap/2026-07-30-ny-government-pension-exclusion-gap.md`. **These should be designed together, not patched separately.**

---

## Priority

1. **Personal-exemption field plus multi-state audit.** Shipped calculation error, confirmed in writing to a user, probably not just Kansas.
2. **Per-source state exemption flag** (G + Alan's NY gap), one design covering both.
3. Audit items 2 and 4, which may or may not be bugs.
4. The information-architecture suggestions (A-D) are a coherent critique and worth considering as a set rather than piecemeal.
