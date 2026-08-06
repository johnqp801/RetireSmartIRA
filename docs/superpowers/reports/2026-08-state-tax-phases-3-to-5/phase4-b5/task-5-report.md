# Task 5 report: Exclusion present, confirmed correct (CO, KY, GA, MO)

Branch: `feature/state-tax-phase4-b5`, worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/phase4-b5`.

## Summary

4 fixtures, 16 scenarios total (4 per state). Every scenario passed the harness. 8 of the 16 scenarios carry a `knownDefect` block (all four Georgia scenarios, two of four Colorado, two of four Kentucky, two of four Missouri); the remaining 8 are clean passes. The audit's specific claim for each state (the retirement-exclusion dollar figures and age tiers) held up in every case. What did NOT hold up, in three of the four states, was something outside the audit's scope: Georgia's tax rate and standard deduction, Colorado's and Kentucky's MFJ per-individual attribution, and Missouri's private-pension/IRA cap. This matches this batch's stated purpose exactly.

## Attestation

I personally opened every `sourceURL` in this batch and checked every clause of each `source` string against the page, with one named exception: the Missouri public-pension-cap scenario's `source` string cites a 2026 Social Security Administration dollar figure ($4,152/month, $49,824/year) that I could not open directly. `ssa.gov` returned HTTP 403 to both WebFetch and to `curl` with a browser user agent from this environment (unlike the Colorado case, where `curl` succeeded after WebFetch's 403). For that one figure I relied on a secondary report (CNBC, 2025-10-31) that quotes SSA's published 2.8% COLA figures, and I say so explicitly inside that fixture's `source` string rather than presenting it as directly verified. Every other clause of every `source` string in this batch, including the Missouri scenario's MO-A mechanism itself, the Colorado, Kentucky, and Georgia figures, and every bill-status claim, was checked against a document or page I opened myself.

One additional caveat, also disclosed in-line: Georgia's `source` strings attribute the 2026 rate cut and standard-deduction increase to "HB 463 (Georgia Economic Growth and Tax Relief Act of 2026)." Five independent sources (an EY tax alert, the Governor's own press release text, CBS Atlanta, WABE, and BDO) all name HB 463. My own attempt to read the bill number directly off the Governor's official "2026 Signed Legislation" listing page gave two DIFFERENT, mutually inconsistent title-pairings for HB 463 across two separate fetch attempts (once "Ad valorem tax; language required to be included in notices of current assessment" and once "Ad valorem tax; certain senior citizens who volunteer with local governments"), which tells me that page's complex responsive table is not reliably parseable by the tools available to me, not that the five converging sources are wrong. The DOLLAR FIGURES themselves (4.99% rate, $15,000/$30,000 standard deduction) are NOT in question: both are stated as a plain declarative fact by Georgia DOR's own "Important Tax Updates" page (dor.georgia.gov/taxes/important-tax-updates), which is what `expectedStateTax` is actually built from. Only the bill-number attribution carries this residual uncertainty, and I say so in the fixture text itself.

## Colorado

**URLs opened, with location of each quote:**
- `https://tax.colorado.gov/sites/tax/files/documents/Book104_2025.pdf` (2025 DR 0104 booklet, fetched via `curl` after WebFetch returned 403 -- confirms the brief's warning that a 403 is often a tool artifact, not a site block). Page 19, "Line 4 Pension and Annuity Subtraction": "Age 65 or older, then you may subtract $24,000 minus any amount entered on line 3... At least 55 years old, but not yet 65, then you may subtract $20,000..." and "Pension/annuity income should not be intermingled between spouses. Each spouse must meet the requirements for the subtraction separately and claim the subtraction only on their pension/annuity income." Page 34, "2025 Colorado Income Tax Table with tax rate of 4.4%."
- `https://leg.colorado.gov/bills/sb25-136` -- Status: "Lost." "02/27/2025... the Senate Committee on State, Veterans, & Military Affairs voted to 'Postpone Senate Bill 25-136 indefinitely' on a vote of 3-2."
- `https://tax.colorado.gov/sites/tax/files/documents/DR0104AD_2025.pdf` -- confirms the Lines 3/4 (primary) vs 5/6 (spouse) structure referenced above.

**Figures derived:** pension/IRA subtraction $24,000 at 65+, $20,000 at 55-64, shared cap between pension and IRA (config's `pensionAndIRAShareSingleCap: true` matches). Flat rate 4.4% (C.R.S. 39-22-104(1.7); no TY2026-specific TABOR reduction found, so the statutory base rate stands). Standard deduction conforms to federal (2026: $16,100 single / $32,200 MFJ, +$2,050/$1,650 age-65 addition, +$6,000/person OBBBA senior bonus phased out at 6% above $75,000 single / $150,000 MFJ MAGI).

**Finding not in the audit's scope:** the DR 0104AD's Lines 3-6 structure and its explicit "do not intermingle" instruction establish that Colorado's $24,000/$20,000 cap is computed SEPARATELY per spouse, based on each spouse's own age -- not one household-wide cap. `StateTaxData.swift`'s CO config sets no `exemptionAppliesPerIndividual`/`exemptionAttribution` override (both default false/household), so the engine pools both spouses' pension income into one cap.

**Arithmetic (all four cases; case-by-case, step by step):**

1. Single, age 50, pension $18,000, no SS. Age 50 < 55, so Line 4 subtraction = $0 (both engine and form agree). Federal taxable income = 18000 - 16100 (2026 single std deduction, no age addback) = 1900. CO taxable income = 1900 - 0 = 1900. Tax = 1900 * 0.044 = **$83.60**. Clean pass.
2. Single, age 70, pension $80,000, no SS. Age 70 >= 65: subtraction = min(24000, 80000) = 24000. Federal std deduction = 16100 + 2050 (age-65) + [6000 - max(0,(80000-75000)*0.06)=5700] (senior bonus after phase-out) = 23850. Federal taxable income = 80000-23850 = 56150. CO taxable income = 56150-24000 = 32150. Tax = 32150*0.044 = **$1,414.60**. Clean pass.
3. MFJ, primary 68/$60,000 pension, spouse 66/$55,000 pension, no SS. Correct (per-spouse): primary excl = min(24000,60000)=24000; spouse excl = min(24000,55000)=24000; combined = 48000. Federal std deduction = 32200+1650+1650 (both 65+) + 12000 (both get full $6,000 senior bonus, MAGI 115000 < 150000 MFJ threshold) = 47500. Federal taxable income = 115000-47500=67500. CO taxable income = 67500-48000 = **19500 -> tax $858.00** (correct/expected). Engine (single pooled cap): excl = min(115000,24000)=24000. CO taxable income = 67500-24000=43500. Tax = 43500*0.044 = **$1,914.00 (measured `observedToday`, confirmed by the actual test run -- matched my hand prediction exactly)**. `knownDefect`, tier3.
4. MFJ, primary 67/$50,000 pension, spouse 60/$40,000 wages (declared via `otherOrdinaryIncome`, no pension of her own). Only one pool exists either way, so per-spouse and pooled agree: excl = min(24000,50000)=24000. Federal std deduction = 32200+1650(primary only)+6000(1 qualifying senior)=39850. Federal taxable income=90000-39850=50150. CO taxable income=50150-24000=26150. Tax=26150*0.044= **$1,150.60**. Clean pass (contrast case: the defect only bites when both spouses actually have their own pension income).

## Kentucky

**URLs opened, with location of each quote:**
- `https://apps.legislature.ky.gov/law/statutes/statute.aspx?id=57914` (current codified KRS 141.019, PDF served with an HTML content-type -- read directly as a PDF). Subsection (1)(g)1.b: "For taxable years beginning on or after January 1, 2018, exclude up to thirty-one thousand one hundred ten dollars ($31,110) of total distributions from pension plans, annuity contracts, profit-sharing plans, retirement plans, or employee savings plans." The 2026-effective amendments listed in the statute's own History note (2026 Ky. Acts ch. 161 sec. 7, ch. 198 sec. 48) touch subsections (r)/(j)/(k)/(l)/(m) only -- confirmed by reading the full statute text, not just the amendment note. No age qualifier appears anywhere in (1)(g).
- `https://apps.legislature.ky.gov/record/25rs/hb146.html` (official KY General Assembly bill-history page). "Last Action: 02/04/25: to Appropriations & Revenue (H)." No further action recorded through the page's own "Last updated: 7/24/2025" timestamp, i.e. through the end of the 2025 session -- died in committee.
- `https://revenue.ky.gov/News/Pages/Kentucky-DOR-Announces-2026-Standard-Deduction.aspx` -- "the standard deduction for 2026 is $3,360, an increase of $90."
- `https://revenue.ky.gov/Forms/Schedule%20P%20(2025).pdf` (form 42A740-P (10-25)), page 1: "PART III -- TOTAL TO BE EXCLUDED THIS YEAR... Enter the lesser of line 2 or $31,110" and "Joint filers -- Combine lines 4(a) and 4(b) and enter on appropriate form." Page 2, "LINE-BY-LINE INSTRUCTIONS," "Column A, Column B": "This exclusion is for each taxpayer. A taxpayer and spouse must compute and claim their own exclusion, regardless of filing status."
- `https://revenue.ky.gov/Forms/740%20(2025).pdf` -- Line 10: "Nonitemizers: Enter $3,270 in Columns A and/or B" (2025 figure); filing status 3 "Married, filing joint return" reports everything in Column B ("Yourself (or Joint)") only, confirming true joint filers use ONE combined standard deduction, not two.

**Figures derived:** $31,110 pension/retirement exclusion, no age gate, per taxpayer (not per return). 2026 flat rate 3.5% (HB 1, 2025 RS, signed by Gov. Beshear, 4%->3.5% effective 1/1/2026). 2026 standard deduction $3,360, same figure for single and true-joint MFJ (one combined column).

**Finding not in the audit's scope:** Schedule P's own instructions establish the $31,110 exclusion as per-taxpayer, combined across both spouses' separately-computed amounts even on a true joint return. `StateTaxData.swift`'s KY config sets no `exemptionAppliesPerIndividual`/`exemptionAttribution` override, so the engine pools both spouses' pension income into one $31,110 cap.

**Arithmetic:**

1. Single, age 62, pension $25,000 (no age gate applies; case varies income instead, per the brief's guidance for a state with no age threshold). Excl = min(25000,31110)=25000 (fully excluded). KY AGI = 25000-25000=0. Std deduction 3360. Taxable income = max(0,0-3360)=0. Tax = **$0**. Clean pass.
2. Single, age 70, pension $50,000. Excl = min(50000,31110)=31110. KY AGI = 50000-31110=18890. Taxable income = 18890-3360=15530. Tax = 15530*0.035= **$543.55**. Clean pass.
3. MFJ, primary 66/$35,000 pension, spouse 64/$35,000 pension. Correct: primary excl=min(35000,31110)=31110; spouse excl=min(35000,31110)=31110; combined=62220. KY AGI = 70000-62220=7780. Taxable income=7780-3360=4420. Tax=4420*0.035= **$154.70** (expected). Engine (pooled): excl=min(70000,31110)=31110. KY AGI=70000-31110=38890. Taxable income=38890-3360=35530. Tax=35530*0.035= **$1,243.55 (measured `observedToday`, matched hand prediction exactly)**. `knownDefect`, tier3.
4. MFJ, primary 66/$40,000 pension, spouse 58/$30,000 wages (`otherOrdinaryIncome`). Only one pool exists: excl=min(40000,31110)=31110. KY AGI=70000-31110=38890. Taxable income=35530. Tax=35530*0.035= **$1,243.55**. Clean pass.

## Georgia

**URLs opened, with location of each quote:**
- `https://dor.georgia.gov/document/document/2025-it-511-individual-income-tax-booklet/download` (2025 IT-511 booklet, 69 pages). Page 21, "Subtractions," item 1 "Retirement income": "The maximum retirement income exclusion is $35,000 for taxpayers who are: A. 62-64 years of age, or B. less than 62 and permanently disabled... The maximum retirement income exclusion is $65,000 for taxpayers who are 65 years of age or older... The exclusion is available for the taxpayer and their spouse; however, each must qualify on a separate basis. If both spouses qualify, each spouse may claim the amounts above." Page 13, "Filing Requirements" table: Married filing jointly $24,000, Single $12,000 (2025 figures; superseded for 2026, see below). Page 24, "Retirement Income Exclusion" worksheet example, confirming taxable IRA and taxable pension income are pooled into the same "Unearned Income" line against one combined maximum, matching the config's `pensionAndIRAShareSingleCap: true`.
- `https://dor.georgia.gov/retirement-income-exclusion` -- "For married couples filing joint returns with both members receiving retirement income, the maximum adjustment for that year may be up to twice the individual exclusion amount."
- `https://dor.georgia.gov/taxes/important-tax-updates` -- "The Georgia income tax rate has been reduced to a flat rate of 4.99%." and "The Georgia standard deduction has been increased to $15,000 for single taxpayers, heads of households, and married taxpayers filing separately, or $30,000 for married taxpayers filing jointly."
- `https://gov.georgia.gov/press-releases/2026-05-11/gov-kemp-signs-legislation-lowering-taxes-and-supporting-economic-growth` -- "lowers Georgia's state income tax rate from 5.19% to 4.99%... raises the retirement income exclusion to $70,000 beginning in 2027."

**Figures derived:** retirement exclusion $35,000 (62-64 or disabled) / $65,000 (65+), per person, doubled for MFJ when both qualify, rising to $70,000 in TY2027 (not yet, so $65,000 stands for the TY2026 fixtures here). **Flat rate 4.99% for 2026** (not 5.39% as configured -- HB 463, "Georgia Economic Growth and Tax Relief Act of 2026," cut the rate from 5.19% to 4.99% retroactive to 1/1/2026). **Standard deduction $15,000 single / $30,000 MFJ for 2026** (not $12,000/$24,000 as configured -- same bill, same effective date).

**Finding not in the audit's scope, and the largest one in this batch:** every Georgia case in this file carries a stale rate AND a stale standard deduction. The audit examined only the retirement-exclusion dollar figures and age tiers, which ARE correct and remain correct in every case below; the tax RATE itself is off by 0.40 percentage points, which moves every Georgia calculation in the app, not just retirement-income ones.

**Arithmetic:**

1. Single, age 60, pension $20,000. Age 60 < 62, no exclusion. Correct: std deduction 15000. Taxable income = 20000-15000-0=5000. Tax=5000*0.0499= **$249.50** (expected). Engine (stale 12000/5.39%): taxable income = 20000-12000-0=8000. Tax=8000*0.0539= **$431.20 (measured, matched hand prediction)**. `knownDefect`, tier1.
2. Single, age 66, pension $100,000. Excl=min(100000,65000)=65000. Correct: taxable income before excl = 100000-15000=85000; after excl = 20000. Tax=20000*0.0499= **$998.00** (expected). Engine: taxable income before excl = 100000-12000=88000; after excl (unaffected)=23000. Tax=23000*0.0539= **$1,239.70 (measured, matched)**. `knownDefect`, tier1.
3. MFJ, primary 70/$110,000, spouse 68/$90,000 pension (both 65+, both qualify -> doubled cap). Correct: taxable income before excl=200000-30000=170000; excl=min(200000,130000)=130000; after=40000. Tax=40000*0.0499= **$1,996.00** (expected). Engine: taxable income before excl=200000-24000=176000; excl (same mechanism, correctly doubled since `exemptionAppliesPerIndividual: true` IS already set)=130000; after=46000. Tax=46000*0.0539= **$2,479.40 (measured, matched)**. `knownDefect`, tier1 -- but the exclusion mechanic itself is a clean pass; only rate/deduction are wrong.
4. MFJ, primary 66/$70,000 pension, spouse 55/$50,000 wages (spouse doesn't qualify by age, no pension of her own). Correct: taxable income before excl=120000-30000=90000; excl=min(70000,65000)=65000; after=25000. Tax=25000*0.0499= **$1,247.50** (expected). Engine: taxable income before excl=120000-24000=96000; excl (same)=65000; after=31000. Tax=31000*0.0539= **$1,670.90 (measured, matched)**. `knownDefect`, tier1.

## Missouri

**URLs opened, with location of each quote:**
- `https://dor.mo.gov/faq/taxation/individual/pension.html` -- "The maximum exemption for private pension income is $6,000" with full-deduction income limits "$25,000 -- Single" / "$32,000 -- Married filing combined."
- `https://dor.mo.gov/forms/MO-A_2025.pdf`, page 3, "Part 3 -- Pension and Social Security/Social Security Disability." **Section A, "Public Pension Calculation - Pensions received from any federal, state, or local government"**: Line 2 "Amount from Line 1 or $47,633 (maximum social security benefit), whichever is less," Line 4 "Subtract Line 3 from Line 2." **Section B, "Private Pension Calculation - Annuities, pensions, IRAs, and 401(k) plans funded by a private source"**: Line 4 filing-status threshold table (MFJ $32,000 / Single-HOH-QW $25,000 / MFS $16,000), Line 7 "Amounts from Line 6Y and 6S or $6,000, whichever is less," Line 9 "Total private pension, subtract Line 5 from Line 8. If Line 5 is greater than Line 8, enter $0." **Section C, "Social Security or Social Security Disability Calculation"**: "To be eligible for social security deduction you must be 62 years of age by December 31."
- `https://dor.mo.gov/forms/MO-1040%20Instructions_2025.pdf`, page 21, "2025 Tax Chart": "Over $9,191 ... $256 plus 4.7% of the excess over $9,191," confirming the bracket-progression method and the 2025 baseline thresholds used to corroborate the 2026 figures already in `StateTaxData.swift` (which independently match multiple 2026-specific bracket calculators, e.g. `https://ustax.tools/missouri-tax-brackets-2026/`, at $1,348/$2,696/$4,044/$5,392/$6,740/$8,088/$9,436).

**Figures derived:** Social Security fully exempt with no income limit (confirmed correct, config matches). Public pension exemption capped at each individual's maximum Social Security benefit ($47,633 for 2025 per the form; $49,824 for 2026 per SSA's 2026 COLA figures -- see the attestation section above for the sourcing caveat on this one number), reduced by any SS deduction claimed. **Private pension/IRA/401(k) exemption capped at $6,000 per taxpayer, phased out dollar-for-dollar above $25,000 single / $32,000 MFJ Missouri AGI** -- NOT unconditionally full, as configured. Brackets: confirmed correct, matching config exactly.

**Findings, one in the audit's scope and one not:**
- In scope (the audit already named this): the public pension cap tied to the max Social Security benefit is not modeled; config has `pensionExemption: .full`.
- NOT in the audit's scope, and the largest single finding of this whole batch given the app's own purpose: the PRIVATE pension/IRA/401(k) exemption is not "full" at all. It is a small $6,000-per-taxpayer amount that phases out completely once Missouri AGI (minus Social Security) exceeds $25,000 single / $32,000 MFJ. Since this app's core use case is IRA withdrawal and Roth conversion planning, and its typical user's income is well above those thresholds, this means the app currently shows $0 Missouri state tax on IRA withdrawals in exactly the situations where real Missouri law taxes them in full.

**Arithmetic:**

1. Single, age 63, IRA withdrawal $5,000. Correct (Section B): Line3=5000-0=5000 < 25000 threshold, Line5=$0 reduction. Line7=min(5000,6000)=5000. Excl=5000 (fully excluded). MO AGI=5000-5000=0. Std deduction (federal-conforming, single, <65) = 16100, already exceeding the $5,000 of income. Tax = **$0** both before and after the exclusion. Clean pass.
2. Single, age 60, IRA withdrawal $50,000. Correct: Line3=50000-0=50000. Line5=50000-25000=25000 (reduction). Line7=min(50000,6000)=6000. Line9: Line5(25000) > Line8(6000) -> excl=$0 (fully phased out). MO AGI=50000 (fully taxable). Std deduction=16100. Taxable income=50000-16100=33900. Tax = 262.86 (cumulative through the $9,436 bracket floor) + 0.047*(33900-9436) = 262.86+1149.81= **$1,412.67** (expected). Engine (`.full`): excl=50000 (all of it). Taxable income=33900-50000, floored at 0. Tax = **$0.00 (measured, matched hand prediction)**. `knownDefect`, tier1.
3. MFJ, primary 67/$150,000 public pension, spouse 65/$120,000 public pension. Correct (Section A): primary excl=min(150000,49824)=49824; spouse excl=min(120000,49824)=49824; combined=99648. Std deduction (both 65+, senior bonus fully phased out at this income)=35500. Taxable income before excl=270000-35500=234500. After excl=234500-99648=134852. Tax=262.86+0.047*(134852-9436)=262.86+5894.55= **$6,157.41** (expected). Engine (`.full`): excl=270000 (all of it). Taxable income = 234500-270000, floored at 0. Tax = **$0.00 (measured, matched)**. `knownDefect`, tier unclassified (per the brief's explicit assignment for this exact mechanism).
4. MFJ, primary 66/$4,000 IRA withdrawal, spouse 58/$20,000 wages (`otherOrdinaryIncome`). Correct: Line3=24000-0=24000 < 32000 threshold, Line5=$0. Line7=min(4000,6000)=4000. Excl=4000 (fully excluded; only primary contributes to the pool). MO AGI=24000-4000=20000. Std deduction (primary 65+ addback + full $6,000 senior bonus, income well under the $150,000 MFJ phase-out start)=32200+1650+6000=39850, exceeding the $24,000 of income. Tax = **$0** both before and after the exclusion (coincides with the engine's `.full` treatment, since the $4,000 withdrawal is under BOTH the real $6,000 cap and the unconditional-full treatment). Clean pass.

## Full-suite output

Targeted run first (`-only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests -only-testing:RetireSmartIRATests/GoldenScenarioCoverageTests`): all 22 covered jurisdictions passed on the first attempt, including all four new fixtures and all eight `knownDefect` blocks -- no iteration was needed; every hand-predicted `observedToday` matched the engine's actual measured output exactly.

Full suite (`xcodebuild test -project .../phase4-b5/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'`, run in the foreground, ~325s):

```
Test run with 1851 tests in 291 suites passed after 325.842 seconds.
** TEST SUCCEEDED **
```

`xcresulttool get test-results summary` on the resulting `.xcresult` bundle:

```
"expectedFailures" : 0,
"failedTests" : 0,
"passedTests" : 2354,
"result" : "Passed",
"skippedTests" : 6,
"totalTestCount" : 2360
```

2360 = 1851 Swift Testing + 509 XCTest, exactly matching the branch baseline stated in the brief (1,851 + 509, 0 failures, 6 skipped). The count did not rise, as expected, since Swift Testing counts a parameterized test once regardless of argument count. `MultiYearPerfTests` was not flagged as flaky in this run (0 failures overall, ran as part of the full suite).

## Production diff (must be empty)

```
$ git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/phase4-b5 diff --stat main -- RetireSmartIRA/
(no output)
```

Empty, as required. No line of `StateTaxData.swift`, `TaxCalculationEngine.swift`, or any `Resources/StateTaxData/2026/*.json` was touched.

## Em dash check

```
$ python3 -c "... checks all 4 fixtures + GoldenScenarioCoverageTests.swift for U+2014 ..."
clean: statetax-2026-CO.golden.json
clean: statetax-2026-KY.golden.json
clean: statetax-2026-GA.golden.json
clean: statetax-2026-MO.golden.json
clean: GoldenScenarioCoverageTests.swift
```

No em dash characters in any file this batch touched.

## Deviations from a literal reading of the brief

- The brief's item 7 states "Colorado, Kentucky and Georgia all have age gates." That is true for Colorado and Georgia but NOT for Kentucky: KRS 141.019(1)(g), read directly, carries no age qualifier at all (confirmed by opening the codified statute itself, not a summary). Kentucky's two "age-gate" cases were redesigned per the brief's own separate instruction for states with no age threshold ("varying income instead of age... say so in the fixture name"), which is what I did.
- I found and pinned three defects the brief did not anticipate: Colorado's and Kentucky's MFJ per-individual attribution gap (both tier3, same shape as the design doc's existing OK/DE/LA/AR/WV Tier 3 entries), Georgia's stale rate and standard deduction (tier1), and Missouri's private-pension/IRA phase-out (tier1, distinct from the public-pension cap the audit already named). All four are backed by a primary source I opened directly and are reasoned through in the arithmetic above.
- The Missouri public-pension-cap scenario's dollar figure for the 2026 maximum Social Security benefit ($49,824) is sourced secondarily (see Attestation) because ssa.gov itself refused both WebFetch and curl.

## Review response: citation findings 1-7 (applied on top of 18c1997)

A review pass judged this batch's tax research correct but found the citations unfollowable in several places, because the fixture schema has exactly one `sourceURL` field while several `source` strings quote two or three documents. The fix applied throughout: `sourceURL` now points at the document that supports the LOAD-BEARING clause, the one `expectedStateTax` actually turns on; every other document quoted in the same `source` string now carries its own inline https URL beside the clause it supports. No `expectedStateTax` or `observedToday` was changed except for the two brand-new middle-tier scenarios below. No file outside the four fixtures in this batch was touched.

### Finding 1 (Georgia's load-bearing figures were unlinked)

Downloaded the actual IT-511 PDF (`https://dor.georgia.gov/document/document/2025-it-511-individual-income-tax-booklet/download`, 5.2 MB, confirmed a real PDF via `file`) and extracted it page by page with `pdftotext -f 20 -l 22 -layout` rather than trusting the earlier report's page citation secondhand. The extracted text shows the "Subtractions ... 1. Retirement income ... The maximum retirement income exclusion is $35,000 ... $65,000" passage sitting between the embedded page-footer "20 2025 IT-511 Instructions Booklet" and the next footer "21 2025 IT-511 Instructions Booklet", which places it on the document's own page 21 (footer numbering matches pdftotext page numbering exactly in this PDF, no cover-page offset). Page 21 is confirmed correct.

`sourceURL` for all five Georgia scenarios (the original four plus the new middle-tier case) now points at that IT-511 PDF, since every one of them turns on the age-tier exclusion amount. The two DOR web pages (`important-tax-updates` for the rate/standard-deduction claim, `retirement-income-exclusion` for the MFJ-doubling claim) are now inlined as full https URLs beside the specific clauses they support, in every scenario that cites them.

### Finding 2 (Georgia's dangling cross-reference)

Deleted the fragment "see this fixture's knownDefect note on the bill-number caveat" from case 1's `source` string. It pointed at a caveat that does not exist in any of this file's four (now five) `knownDefect.summary` fields.

### Finding 3 (Georgia's bill number was not actually uncertain)

Fetched `https://gov.georgia.gov/press-releases/2026-05-11/gov-kemp-signs-legislation-lowering-taxes-and-supporting-economic-growth` directly (WebFetch). It states plainly: "HB 463 lowers Georgia's state income tax rate from 5.19% to 4.99%, beginning January 1, 2026," signed May 11, 2026. Rewrote case 1's `source` to cite this press release for the bill-number/rate claim and dropped the residual-uncertainty framing entirely; the same press release is now inlined in every Georgia scenario's rate clause. The prior report's "two mutually inconsistent title-pairings" caveat (from trying to parse the Governor's complex signed-legislation table) is superseded by this direct, unambiguous primary source and is not repeated in the fixture text. Correcting the same overstatement in the report: it is retracted here, not carried forward.

### Finding 4 (Colorado's bill disposition never reached the artifact)

Fetched `https://leg.colorado.gov/bills/sb25-136` directly (WebFetch) and confirmed both the bill's official short title, "Expand Deduction For Retirement Benefits," and its status history: "02/27/2025 | Senate | Senate Committee on State, Veterans, & Military Affairs Postpone Indefinitely." Added one sentence to Colorado case 2's `source` naming SB25-136, its Postponed Indefinitely disposition on 2025-02-27, and stating that the $24,000 (65+) and $20,000 (55-64) DR 0104AD caps therefore stand for TY2026, with the bill URL inline. This is the same verification the prior report already performed; it is now traceable from the fixture itself, not only from the report.

### Finding 5 (two Kentucky claims were not at their cited URLs)

(a) Downloaded `https://revenue.ky.gov/Forms/2026%20Withholding%20Formula.pdf` and extracted it with `pdftotext -layout` (WebFetch's HTML-to-markdown conversion could not read this particular PDF; the raw download worked). Line 8 of the extracted text reads: "2026 Kentucky Tax Rate: 3.5% of taxable income Formula:" -- confirming the 3.5% figure directly. Case 2's `sourceURL` now points at this withholding-formula PDF (load-bearing for the rate claim, which the case's own name foregrounds: "excess is taxed at the 2026 flat 3.5% rate"), and the standard-deduction page (`revenue.ky.gov/News/Pages/Kentucky-DOR-Announces-2026-Standard-Deduction.aspx`) is now inlined beside the $3,360 deduction clause instead.

(b) Case 1: `sourceURL` stays on the KRS statute page (load-bearing for the $31,110 figure the case turns on), and the Schedule P PDF is now inlined beside the "Enter the lesser of line 2 or $31,110" quote. Case 3: `sourceURL` stays on the Schedule P PDF (load-bearing for the per-spouse $31,110 x2 mechanic), and the Form 740 PDF is now inlined beside the Column-B/joint-filing quote it supports.

### Finding 6 (Missouri's Social Security figure rested on a news article)

Tried, in order, every official government avenue the finding suggested before concluding CANNOT_VERIFY:

1. **Federal Register.** Found and fetched (via `curl` with a browser user-agent, after `WebFetch` redirected into `unblock.federalregister.gov`'s bot-check page) the actual SSA COLA determination notice: "Cost-of-Living Increase and Other Determinations for 2026," published 2025-11-03, `https://www.federalregister.gov/documents/2025/11/03/2025-19763/cost-of-living-increase-and-other-determinations-for-2026`. This notice IS reachable and IS official, but it does not state the $4,152/month ($49,824/year) maximum-benefit-at-full-retirement-age figure anywhere in its text -- it publishes the OASDI contribution and benefit base ($184,500 for 2026), the national average wage index ($69,846.57), retirement-earnings-test exempt amounts, and SSI figures, none of which is the number Missouri's Section A cap needs.
2. **SSA press release / fact sheet / OACT tables under other paths.** Every ssa.gov path tried (`/news/press/releases/2025/2025-10-24-i.html`, `/news/press/factsheets/colafacts2026.pdf`, `/oact/cola/examplemax.html`, `/oact/cola/central.html`) returned HTTP 403, consistent with the original researcher's finding that ssa.gov itself is unreachable from this environment, not just one page of it.
3. **Congressional Research Service.** Fetched CRS Report 94-803, "Social Security: Cost-of-Living Adjustments" (updated 2026-05-27, `https://www.congress.gov/crs_external_products/RS/PDF/94-803/94-803.43.pdf`), extracted with `pdftotext`. It covers COLA computation methodology and the taxable maximum, not the specific full-retirement-age maximum-benefit dollar figure either.
4. **Missouri's own 2026 MO-A form.** `https://dor.mo.gov/forms/MO-A_2026.pdf` returns 404 -- Missouri DOR has not yet published the TY2026 form (expected; forms for a mid-year tax year are typically released toward year-end), so there is no state-published figure to cite yet either.
5. **Wayback Machine**, targeted specifically at the SSA fact sheet and OACT example-max URLs (not just a generic ssa.gov check): `archive.org/wayback/available` returned `"archived_snapshots": {}` for both, i.e. no snapshot exists to fall back to.

No official source states this specific dollar figure. Per the finding's explicit instruction, the scenario was marked CANNOT_VERIFY and **removed from the fixture** rather than shipped on the CNBC citation. Missouri's fixture now has three scenarios instead of four. **Missouri's public-pension-cap-at-maximum-Social-Security-benefit case is unverifiable until ssa.gov becomes reachable or Missouri DOR publishes its 2026 MO-A form.** This also removes the `knownDefect` block that scenario carried (the public-pension `.full`-exemption gap the 2026-08-02 audit already named); that defect still exists in the engine and is still real, it simply has no golden case pinning it in this batch until a verifiable dollar figure is available.

### Finding 7 (two age tiers were never exercised)

Added one new scenario to each file, landing squarely in the middle of the untested tier. Both were run through the actual harness before being finalized; neither needed a `knownDefect` block predicted in advance, and the measured engine output matched the hand derivation in both cases on the first run (see full-suite output below), which is why neither carries a `knownDefect`... except Georgia's, which does, for the same stale-rate/deduction reason every other Georgia case in this file does.

- **Colorado**, new case "single, age 60, squarely in the 55-64 tier: $20,000 subtraction cap exercised" (inserted as the file's second scenario). Single filer, pension income $50,000, no Social Security. DR 0104AD Line 4 subtraction = min(20000,50000) = 20000 (age 60 is in the 55-64 tier per Book104_2025.pdf page 19). Federal taxable income = 50000 - 16100 (2026 single standard deduction, no age-65 addback, no OBBBA senior bonus since primaryAge 60 < 65) = 33900. Colorado taxable income = 33900 - 20000 = 13900. Tax = 13900 * 0.044 = **$611.60**. Single filer, so Colorado's MFJ per-individual-attribution defect (Finding 4's subject) does not apply here; the harness run confirmed a clean pass with no `knownDefect` needed.
- **Georgia**, new case "single, age 63, squarely in the 62-64 tier: $35,000 exclusion cap exercised" (inserted as the file's second scenario). Single filer, pension income $60,000, federalAGI $60,000. Correct (form) figures: GA standard deduction $15,000 single, exclusion = min(60000,35000) = 35000, taxable income = 60000-15000-35000 = 10000, tax = 10000*0.0499 = **$499.00** (`expectedStateTax`). The engine still carries GA's pre-HB463 config (0.0539 rate, $12,000 single standard deduction, same defect as every other Georgia case in this file), so it disagrees: taxable income = 60000-12000-35000 = 13000, tax = 13000*0.0539 = **$700.70**, which the actual test run confirmed as the MEASURED `observedToday` (matched the hand prediction exactly, not just asserted in advance). `knownDefect`, tier1, same stale-rate/deduction mechanism as the file's other four scenarios; the 62-64 tier mechanic itself is correct.

## Verification re-run (this pass)

Focused suite (`-only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests -only-testing:RetireSmartIRATests/GoldenScenarioCoverageTests`, foreground, `timeout: 600000`):

```
✔ Test "Single-year path matches each state's own published form" with 22 test cases passed after 0.012 seconds.
✔ Suite "Golden scenarios, single-year path" passed after 0.017 seconds.
✔ Test run with 9 tests in 2 suites passed after 0.078 seconds.
** TEST SUCCEEDED **
```

All 22 covered jurisdictions passed, including both new middle-tier scenarios (CO clean pass, GA `knownDefect` pin), on the first run after the citation edits -- no arithmetic needed correcting.

Full suite (`xcodebuild test -project .../phase4-b5/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'`, foreground, `timeout: 600000`, ~352s):

```
Test run with 1851 tests in 291 suites passed after 321.160 seconds.
** TEST SUCCEEDED **
```

`xcresulttool get test-results summary` on the resulting `.xcresult` bundle:

```
"expectedFailures" : 0,
"failedTests" : 0,
"passedTests" : 2354,
"result" : "Passed",
"skippedTests" : 6,
"totalTestCount" : 2360
```

2360 = 1851 Swift Testing + 509 XCTest, 0 failures, 6 skipped -- matches the branch baseline exactly (1,851 + 509, 0 failures, 6 skipped) despite Missouri losing one scenario and Colorado/Georgia each gaining one (Swift Testing's parameterized-test counting is unaffected by scenario count within a fixture; only the per-jurisdiction argument count changes, not the number of `@Test` declarations). `MultiYearPerfTests` was not flagged as flaky in this run.

## Production diff (must be empty), re-checked

```
$ git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/phase4-b5 diff --stat main -- RetireSmartIRA/
(no output)
```

Empty. Only the four fixture JSON files under `RetireSmartIRATests/GoldenScenarios/` were touched this pass; nothing under `RetireSmartIRA/` (the production target) or outside this batch's four states was modified.

## Em dash check, re-checked

Searched all four fixtures plus this report itself for the literal U+2014 em dash character (a Python containment check against the character itself, not a shell grep that could be fooled by terminal rendering):

```
clean: statetax-2026-GA.golden.json
clean: statetax-2026-CO.golden.json
clean: statetax-2026-KY.golden.json
clean: statetax-2026-MO.golden.json
clean: task-5-report.md
```

No em dash characters anywhere. (This report uses " -- " as a plain double-hyphen throughout, matching the convention already used in every fixture `source` string in this batch.)
