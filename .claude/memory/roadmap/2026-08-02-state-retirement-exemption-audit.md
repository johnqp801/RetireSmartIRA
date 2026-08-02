# State retirement-income exemption audit, 2026-08-02

> **SUPERSEDED the same day by `2026-08-02-full-50-state-verification.md`**, which covers all 51
> jurisdictions. This file is kept as the narrative of how the problem surfaced and why the scope widened.
> One correction from the full pass: Colorado is **not** affected. A secondary source claimed SB25-136
> removed its caps; the bill died in committee.

Triggered by Steve Nicolai's second state-tax report (Iowa, 10:05 AM). He asked one question. The answer is that **Iowa is not close to alone.**

Spot-checked roughly a dozen of the 51 configs in `StateTaxData.swift`. **Eight are wrong.** That hit rate is the finding: this is not a list of bugs to patch, it is a table that has gone stale as a whole.

---

## 0. The thing that changes the priority

**Iowa explicitly exempts Roth conversion income** for qualifying taxpayers. Iowa DOR retirement-income guidance lists "Roth conversion income" by name in the excluded category.

For a Roth conversion planning tool, that is not a rounding error. An Iowa resident 55+ converting $200,000 is shown ~$7,600 of state tax that does not exist, at a 3.8% flat rate. It biases every recommendation the optimizer makes for Iowa users, and it biases them toward under-converting.

The engine already has the right seam for this: `TaxCalculationEngine.swift:672-680` has a `switch state` for Roth-conversion state exemptions covering PA, IL, MS. Iowa belongs there. The wrinkle is that PA/IL/MS are ungated while **Iowa's is age-gated at 55**.

---

## 1. Confirmed wrong, with sources

### 1a. 🔴 Iowa — retirement income fully excluded since TY 2023, app taxes all of it

`StateTaxData.swift:646-657` sets `pensionExemption: .none` with the comment *"IA phased out retirement exclusion with flat tax."* **That comment is backwards.** Iowa HF 2317 Division VI (signed 2022-03-01) *created* the exclusion effective TY 2023.

- Qualifying: age **55+** on Dec 31, OR disabled, OR surviving spouse/survivor with insurable interest
- Covered: IRAs, **Roth conversion income**, 401(k), 457(b), SEP/SIMPLE, defined benefit incl. IPERS, Keogh, ESOP
- Not covered: nonqualified deferred comp (§409A), nonqualified annuities, early distributions subject to the federal 10% penalty
- **No income limit and no dollar cap**
- Per-spouse: only the spouse meeting the criteria excludes their own income

Iowa carries **no `Verified` stamp** in the file, unlike 26 other states. It was never covered by the 2026-05-27 sweep.

### 1b. 🔴 Wisconsin — new $24,000/person exclusion since TY 2025, app has none

2025 Act 15: first **$24,000** of retirement income per individual age **67+**; MFJ with both 67+ = **$48,000**. The old law was $5,000 with a hard AGI limit; Act 15 raised the age from 65 to 67, raised the cap, and **removed the AGI limit entirely**.

App has `.none` for both fields (line 2057). **Wisconsin carries a `Verified 2026-05-27` stamp and is still wrong**, which is why the unverified list is not a sufficient work-list.

### 1c. 🔴 Michigan — app grants an unlimited exemption; the real one is capped

App has `pensionExemption: .full` / `iraWithdrawalExemption: .full` (line 734) with the comment "phasing to full retirement income exemption by 2026."

The phase-in did complete for TY 2026 under PA 4 of 2023, but "full" means the **restored pre-2012 deduction, which has a dollar cap**: **$67,610 single / $135,220 MFJ** for 2026. Public-source retirement income is limited to the private maximum for 2026+ (except taxpayers born before 1946). Military pensions and some public-safety retirees are genuinely uncapped.

**This one errs toward over-conversion** — the opposite direction from Iowa, and the more dangerous direction for a planning tool.

### 1d. 🔴 Connecticut — wrong in both directions at once

App has `pensionExemption: .none` and `iraWithdrawalExemption: .full` (lines 1095-1096).

Reality for TY 2026: pension/annuity **and** IRA distributions both get a 100% deduction, but **only below federal AGI $75,000 single / $100,000 MFJ**, with a gradual phase-out running to $100,000/$150,000.

So the app **understates** for a modest-income CT retiree with a pension, and **overstates** for anyone whose AGI clears the threshold. For this app specifically the second is severe: a large Roth conversion is exactly what pushes a CT filer through the phase-out, and the app currently models the IRA exemption as unconditional.

### 1e. 🔴 Alabama — defined-benefit pensions are fully exempt; app taxes them

Alabama's dividing line is **defined benefit vs defined contribution**, not public vs private. DB pensions (private, state/local, CSRS/FERS, military) are **entirely exempt**. DC distributions (401(k), traditional IRA) get **$6,000 per person at 65+** under Act 2022-294 (Lynn Greer Retirement Income Tax Cut Act), effective 2023, so $12,000 for a couple both 65+.

App has `.none` for both (lines 940-941).

### 1f. 🔴 Rhode Island — $20,000/person modification, app has none

$20,000 per person of pension/annuity/401(k) income at Social Security full retirement age, $40,000 for joint filers, subject to federal AGI limits (~$104,200 single / $130,250 joint). App has `pensionExemption: .none` (line 1861).

### 1g. 🔴 Maine — deduction is badly stale

App has `.partial(maxExempt: 25_000)` (line 1361). The Maine pension income deduction was raised from $10,000 to **$48,216 for TY 2025**, indexed annually, and now carries an income-based phaseout above a federal AGI threshold for TY 2025+.

The app's figure understates the deduction by roughly half. TY 2026 indexed value still needs a primary-source confirmation.

### 1h. 🟠 Hawaii — employer-funded pensions are exempt, app taxes them

Hawaii does not tax the **employer-funded** portion of a qualified pension (no cap, no age test), which covers CSRS/FERS annuities, traditional DB plans, and military retired pay. It **does** tax the employee-contributed portion, 401(k) elective deferrals, and IRA distributions.

App has `.none` for both (lines 1235-1236). The IRA side is right; the pension side is not.

Marked amber rather than red because **the model cannot express it cleanly.** "Employer-funded portion only" is a per-source attribute, not a per-state one. This lands in the same bucket as Alan's NY government pension and Steve's 403(b) — see item 1c in the consolidated backlog.

---

## 2. Narrower or needs confirmation

- **Minnesota** — Qualified Public Pension Subtraction (TY 2023+): $25,000 MFJ / $12,500 other, indexed, phasing out above $100,000 MFJ / $78,000 single AGI. Narrow: only public pensions whose members are **not** SS-covered. App has `.none`. Real but low-population.
- **Missouri** — code comment cites **HB 798**; the operative bill appears to be **HB 426**. Substance mostly holds (100% private retirement allowance TY 2026+, and Missouri's definition of "retirement allowance" includes IRAs but excludes Roth IRAs). But the **public** pension exemption is capped at each individual's **maximum Social Security benefit**, which the app does not model. Verify before touching.
- **Georgia** — $65,000 at 65+ is correct for TY 2026. Rises to **$70,000 in TY 2027**. Diary item, not a bug.

---

## 3. What this means structurally

Three separate problems, and only the first is a data-entry fix.

**The `Verified` stamps are not load-bearing.** Wisconsin's Act 15 passed in July 2025, ten months before the 2026-05-27 sweep, and the sweep still recorded Wisconsin as having no exclusion. Eleven states carry no stamp at all (NH, WA, AZ, CO, GA, IA, KY, UT, AL, DC, NM), and Iowa and Alabama are both on that list and both wrong. But so is stamped Wisconsin. **The unverified list is a starting point, not the work-list.**

**The engine's 59½ gate is hardcoded and blocks Iowa.** `TaxCalculationEngine.swift:570` computes `retirementAge = primaryAge >= 59 || (enableSpouse && spouseAge >= 59)` for scenario distributions. Iowa qualifies at **55**. Setting Iowa's config alone leaves a 55-to-58-year-old Iowan wrongly taxed. `regularExemptionMinAge` exists on the config but does not reach this gate.

That same line uses `||`, so **either** spouse being 59+ unlocks the exemption for household distributions. Iowa's exclusion is explicitly per-qualifying-spouse. Worth a separate look.

**Roth conversion exemption is a hardcoded `switch state`.** Adding Iowa means adding the first *age-gated* entry to a switch whose three existing cases are all ungated.

**A pattern worth naming:** four of the eight involve an **income-based phase-out or a dollar cap** (CT, MI, ME, RI), and the model expresses caps but has no general phase-out-by-AGI mechanism except NJ's bespoke `steppedPhaseoutByFilingStatus`. For a Roth conversion tool, AGI-triggered phase-outs are the single most important thing to get right, because a conversion is the thing that triggers them.

---

## 4. Coverage honesty

I checked roughly a dozen states closely. **Not audited at all:** DE, OK, SC, VA, MD, MT, NM, UT, AZ, DC, VT, NE, KY, CO, ND, OH, ID, IN, NC, KS, NY, NJ, LA, CA, MA, OR, WV, MS, PA, IL, plus the no-income-tax group.

Given 8 confirmed wrong out of ~12 examined, **assume the unexamined 30+ have a similar defect rate until checked.** The expected number of additional bugs in the unexamined set is not small.

Washington's capital-gains tax (7% above ~$270k) is worth a specific look since the app models WA as fully exempt.

---

## 5. Recommended sequencing

Steve is owed answers on his original 12 items ~08-03, and this is now a 13th. It is also the second state-tax bug he has found in two days, which is the part worth taking seriously.

1. **Iowa**, as a complete fix: config + the 59½ gate + the Roth-conversion switch. It is the reported bug, it is a written commitment, and it is the one that most distorts the app's core recommendation.
2. **Michigan and Connecticut**, because they overstate exemptions and push users toward over-converting. A too-generous number is worse than a too-stingy one here.
3. **Wisconsin, Alabama, Rhode Island, Maine** — mechanical config changes once the shapes exist.
4. **Full 50-state re-verification** with primary sources and a dated stamp per state. This is the real deliverable. The 2026-05-27 sweep demonstrably missed a change that predated it.
5. **Hawaii** waits on the per-source exemption design (backlog 1c), alongside Alan's NY pension and Steve's 403(b).
6. **A general AGI-phaseout mechanism** on `RetirementIncomeExemptions`. Four of eight need it.

Consider whether Steve's suggestion **F** ("communicate how accurate the state modeling is") should ship alongside. He asked for it the day before finding a second state bug, and he is right.

---

## Sources

- [Iowa DOR — Retirement Income Tax Guidance](https://revenue.iowa.gov/taxes/tax-guidance/individual-income-tax/retirement-income-tax-guidance)
- [Iowa HF 2317 enrolled text](https://www.legis.iowa.gov/docs/publications/LGE/89/HF2317.pdf)
- [Wisconsin 2025 Act 15 — LFB distribution estimate](https://docs.legis.wisconsin.gov/misc/lfb/budget/2025_27_biennial_budget/509_estimated_distribution_of_individual_income_tax_reductions_in_motion_44_6_18_25)
- [Michigan Revenue Administrative Bulletin 2026-1](https://www.michigan.gov/taxes/rep-legal/rab/2026-revenue-administrative-bulletins/revenue-administrative-bulletin-2026-1)
- [Michigan DOT — Retirement and Pension Benefits](https://www.michigan.gov/taxes/iit/tax-guidance/tax-situations/retirement-and-pension-benefits)
- [CT OLR — A Guide to Connecticut's Personal Income Tax](https://cga.ct.gov/2024/rpt/pdf/2024-R-0130.pdf)
- [Alabama DOR — Income Exempt from Alabama Income Taxation](https://www.revenue.alabama.gov/individual-corporate/income-exempt-from-alabama-income-taxation/)
- [Alabama Retail Association — Retirement Income Tax Exemption (Act 2022-294)](https://alabamaretail.org/news/retirement-income-tax-cut/)
- [RI Division of Taxation — Retirement Income Guide, PUB 2026-01](https://tax.ri.gov/sites/g/files/xkgbur541/files/2026-02/PUB_2026-01_Retirement_Income_Guide.pdf)
- [MainePERS — Maine Pension Income Deduction](https://www.mainepers.org/retirement/benefit-payment-and-tax-information/important-information-about-the-maine-pension-income-deduction-and-your-mainepers-benefit/)
- [Minnesota DOR — Qualified Public Pension Subtraction](https://www.revenue.state.mn.us/public-pension-subtraction)
- [Missouri DOR — Pension FAQs](https://dor.mo.gov/faq/taxation/individual/pension.html)
- [Missouri HB 426 (2025 session)](https://www.senate.mo.gov/25info/BTS_Web/Bill.aspx?SessionType=R&BillID=18266206)
