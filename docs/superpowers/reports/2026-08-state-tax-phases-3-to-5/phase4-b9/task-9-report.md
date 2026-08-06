# Task 9 Report: Tier 4 (OH, UT, NM) + Washington + Minnesota

Batch commit: `f794548` on branch `feature/state-tax-phase4-b9`.

## Attestation

I personally opened every `sourceURL` in this batch and checked every clause of each `source`
string against the page, with the following documented exceptions where a primary source was
retrieved but a specific figure could not be located and I used a corroborating source instead
(each noted at the point it applies below, not hidden):

- Ohio's TY2026 `$332` bracket base and 4.45%→2.75% rate-collapse language was read directly from
  the Legislative Service Commission's H.B. 96 bill analysis PDF (a government source, not the
  enacted statute text itself, because I could not find a standalone TY2026 rate-schedule page on
  tax.ohio.gov distinct from the 2025 IT 1040 booklet). I corroborated the $332 figure and the
  "flat 2.75% for TY2026" claim against three independent secondary sources (a WebSearch summary,
  not opened as pages) before treating it as reliable; the LSC PDF itself is the source cited in
  each fixture and I opened and read it directly, including the printed page-484 table.
- Utah's SB60 rate cut (4.5%→4.45%) was confirmed by opening BOTH the introduced bill PDF and the
  enrolled bill PDF directly (le.utah.gov), not merely a news summary; the "signed March 23, 2026"
  claim comes from a WebSearch summary only, not a page I opened directly, and is noted as such.
- New Mexico's HB252 bracket replacement was confirmed by opening the bill text PDF directly
  (nmlegis.gov) and reading the deleted-vs-new bracket tables side by side on the page; the
  "signed March 6, 2024, Chapter 67" fact is from a WebSearch summary, not a page I opened
  directly.
- Washington's 2026 capital-gains standard deduction was NOT found published anywhere (confirmed
  by opening the DOR capital-gains page directly and by search); I used the 2025 figure
  ($278,000) and say so explicitly in every WA fixture's `source`, per this task's own instruction
  for exactly this situation.
- Minnesota's Schedule M1QPEN phase-out FORMULA (the step-by-step worksheet mechanics) is read
  from the 2024 version of that form (the only year I could retrieve after several URL attempts
  against the current DOR site's 2025/2026-dated paths all 404'd); the DOLLAR FIGURES used in
  every MN fixture come from a different, later, and more authoritative document -- the Minnesota
  Department of Revenue's official "Tax Year 2026 Inflation-Adjusted Amounts" PDF (Tax Research
  Division, dated December 1, 2025) -- which I opened directly and which states the applicable
  tax year on its face. This substitution (2024 form for mechanics, 2026 document for dollars) is
  stated in the fixtures' own `source` text, not just here.

Every dollar figure that appears in an `expectedStateTax` was hand-derived from one of these
opened, quoted sources; none came from running the app or engine.

## Ohio

**URLs opened:**
- `https://dam.assets.ohio.gov/image/upload/v1767095693/tax.ohio.gov/forms/ohio_individual/individual/2025/it1040-booklet.pdf` (64-page 2025 IT 1040 booklet) -- opened, extracted per-page text, and confirmed line numbers against PDF page indices directly (not just search-engine text).
- `https://www.lsc.ohio.gov/assets/legislation/136/hb96/ps/files/hb96-tax-bill-analysis-as-passed-by-the-senate-136th-general-assembly.pdf` -- opened directly, confirmed the TY2026 table sits on the PDF page whose own footer reads "P a g e | 484."
- `https://dam.assets.ohio.gov/image/upload/v1758139620/tax.ohio.gov/forms/ohio_individual/individual/2025/1040-bundle.pdf` -- opened directly to confirm the "Use only black ink. Use whole dollars only." instruction on the OFFICIAL blank Schedule of Credits form (not the third-party taxformfinder.org mirror I found first and discarded per this phase's citation-discipline rule).

**Rule established:** TY2026 Ohio nonbusiness income tax is $332 + 2.75% of taxable nonbusiness
income over $26,050 (H.B. 96, signed by Governor DeWine June 30, 2025, enacted as the FY2026-27
operating budget; the LSC bill analysis I opened directly states the exact TY2026 table). Personal/
dependent exemption is MAGI-banded ($2,400/$2,150/$1,900/$0, IT 1040 booklet printed page 17,
frozen for TY2025-26 by H.B. 96's inflation-indexing suspension). Retirement Income Credit
(booklet printed page 28, Table 2 on printed page 44) is up to $200 PER RETURN (not per spouse),
requires MAGI-less-exemptions under $100,000 and qualifying pension/IRA/401(k) income. Senior
Citizen Credit (printed page 28) is a flat $50 PER RETURN if 65+ and under the same MAGI cliff.
Both are a hard cliff at $100,000, not a phase-out.

**Arithmetic (all five cases), whole-dollar rounding per the official Schedule of Credits/IT 1040
instruction "Use whole dollars only," round-half-up:**

| Case | FAGI | Exemption | Taxable | Line 8a | Credits | Tax |
|---|---|---|---|---|---|---|
| single 58, $50k pension | 50,000 | 2,150 | 47,850 | 332+599.50→932 | 200 | **732.00** |
| single 70, $60k pension | 60,000 | 2,150 | 57,850 | 332+874.50→1,207 | 250 | **957.00** |
| MFJ both 65+, $80k combined | 80,000 | 4,300 | 75,700 | 332+1,365.375→1,697 | 250 | **1,447.00** |
| MFJ one 65+, $65k combined | 65,000 | 4,300 | 60,700 | 332+953.375→1,285 | 250 | **1,035.00** |
| single 66, $70k+$40k Roth=$110k | 110,000 | 1,900 | 108,100 | 332+2,256.375→2,588 | 0 (MAGI>$100k) | **2,588.00** |

**knownDefects (all five, MEASURED via the failure-message engine value, tier4):**
- 732.00 case: `observedToday 658.625`
- 957.00 case: `observedToday 933.625`
- 1,447.00 case: `observedToday 1483.625`
- 1,035.00 case: `observedToday 1071.125`
- 2,588.00 case: `observedToday 2308.625`

Mechanism for all five: the engine's OH bracket array has only two entries (0% to $26,050, then a
bare 2.75% with no base constant), no personal-exemption representation, and no credit
representation at all -- so it under-collects the $332 base amount is actually never the issue
(engine has no base term to omit incorrectly -- it just multiplies), it OVER-collects relative to
form (misses the exemption and both credits) in every case except the fifth, where the credits
are legitimately zero under real law too and the remaining gap is purely the missing $332 base +
missing exemption.

**Disclosed-limitation sentence for OH:** "This app does not currently account for Ohio's
Retirement Income Credit (up to $200 per return) or its $50 Senior Citizen Credit; both require
household MAGI under $100,000, which is below what most users of this app's Roth-conversion
planning will have in a conversion year."

## Utah

**URLs opened:**
- `https://tax.utah.gov/forms/current/tc-40inst.pdf` (2025 TC-40 Instructions, 41 pages) -- opened directly, confirmed printed-page-to-PDF-page mapping for Lines 4-25 (printed pages 7-9) and the Retirement Credit Worksheet (printed page 19).
- `https://le.utah.gov/Session/2026/bills/introduced/SB0060.pdf` and `https://le.utah.gov/~2026/bills/enrolled/SB0060.pdf` -- both opened directly; confirmed the rate-cut text is IDENTICAL between introduced and enrolled versions.

**Rule established:** Utah's rate for TY2026 is 4.45% (S.B. 60, enrolled bill text I opened
directly: "the tax is an amount equal to the product of ... (b) 4.45%," retrospective to
1/1/2026), not 4.55% as the engine's config states -- a genuine, separate rate-staleness defect on
top of the missing credits. Utah's tax base (TC-40 Line 9) is FEDERAL AGI plus additions minus a
SHORT list of specific subtractions (municipal bond interest, previously-taxed retirement income,
etc.) -- it is NOT federal taxable income, and does NOT itself subtract the federal standard
deduction. Instead, Utah refunds an approximation of that deduction's value through the
**Taxpayer Tax Credit** (UCA 59-10-1018, TC-40 Lines 11-20): 6% of (personal exemption for
dependents + federal standard/itemized deduction), phased out 1.3% per dollar of Utah taxable
income over a base amount ($18,213 single / $36,426 MFJ, 2025 figures, 2026 not yet published so
stated explicitly). This credit is NOT named anywhere in the batch brief and is a bigger,
previously-unidentified finding than the $450 Retirement Credit the brief names -- it applies to
essentially every Utah filer, not just retirees. The Retirement Credit itself (UCA 59-10-1019) is
NOT age-65-gated as the brief assumed -- it is a FIXED birth-year cutoff ("born on or before Dec.
31, 1952"), confirmed against Utah Code text directly, meaning eligibility never moves forward and
the eligible population only shrinks each year. The brief's "$54,000 single / $90,000 joint"
figures belong to a DIFFERENT credit (the Social Security Benefits Credit, code AH, UCA
59-10-1042), not the Retirement Credit -- this is exactly the single-source-audit conflation this
phase exists to catch, and I corrected it rather than repeating it.

**Arithmetic (all five cases):**

| Case | FAGI | UT tax @4.45% | Std ded | TTC (Line20) | Retirement Cr. | Total credits | Tax |
|---|---|---|---|---|---|---|---|
| single 50, $45k | 45,000 | 2,003 (rounded) | 16,100 | 966-348=618 | 0 (post-1952 birth) | 618 | **1,385.00** |
| single 76, $30k | 30,000 | 1,335 | 18,150 | 1,089-153=936 | 450-125=325 | 1,261 | **74.00** |
| MFJ both born ≤1952, $70k | 70,000 | 3,115 | 35,500 | 2,130-436=1,694 | 900-950→0 | 1,694 | **1,421.00** |
| MFJ one born ≤1952, $65k | 65,000 | 2,893 (rounded) | 33,850 | 2,031-371=1,660 | 450-825→0 | 1,660 | **1,233.00** |
| single 76, $50k+$60k Roth=$110k | 110,000 | 4,895 | 18,150 | 1,089-1,193→0 | 450-2,125→0 | 0 | **4,895.00** |

**knownDefects (all five, MEASURED, tier4):**
- 1,385.00 case: `observedToday 2047.5`
- 74.00 case: `observedToday 1365.0`
- 1,421.00 case: `observedToday 3185.0`
- 1,233.00 case: `observedToday 2957.5`
- 4,895.00 case: `observedToday 5005.0` (this case isolates the bare 4.45%-vs-4.55% rate gap since both credits are legitimately zero at this income; $5,005 - $4,895 = $110, exactly $110,000 x 0.001, the rate delta.)

**Disclosed-limitation sentence for UT:** "This app does not currently account for Utah's
Taxpayer Tax Credit (an income-scaled offset most Utah filers qualify for, phasing out gradually
at higher income) or its $450-per-person Retirement Credit (limited to taxpayers born on or
before December 31, 1952, a fixed and shrinking population)."

## New Mexico

**URLs opened:**
- `https://klvg4oyd4j.execute-api.us-west-2.amazonaws.com/prod/PublicFiles/34821a9573ca43e7b06dfad20f5183fd/61f8c5b0-b391-49b5-9d66-6605ef1f0c13/2025pit-adj-ins.pdf` (2025 PIT-ADJ Instructions) -- opened directly, page ADJ-4 (Table 1 and the Line 13 text) read in full, including the exact per-band dollar figures.
- `https://www.nmlegis.gov/Sessions/24%20Regular/bills/house/HB0252TRS.pdf` -- opened directly; read the bracketed (deleted) OLD table and the underscored (new) table side by side on printed pages 14-16.
- `https://www.tax.newmexico.gov/individuals/personal-income-tax-information-overview/` -- opened directly (confirmed the $8,000/age-65 language exists on NM TRD's own site, though the exact table came from PIT-ADJ, not this overview page).
- The exact new PIT-1 instructions PDF (with the tax-year-labeled bracket table itself) returned 404 from every URL I tried; I used the bill text (an even more authoritative primary source) instead and corroborated the bracket numbers against Tax Foundation's independent summary (a secondary source, not treated as sole basis).

**Rule established (two independent findings, not just one):**
1. **Stale bracket schedule.** NM's House Bill 252 (Laws 2024, Chapter 67, signed March 6, 2024)
   replaced the state's 5-bracket 1.7%-5.9% schedule with a 6-bracket 1.5%-5.9% schedule, effective
   any taxable year beginning on or after January 1, 2025 -- confirmed directly from the bill text,
   which shows the OLD table bracketed for deletion and the exact NEW table (base amounts and all)
   immediately after. The engine's `statetax-2026-NM.json` still uses the OLD, deleted table
   verbatim. This is a previously-unidentified finding, not what the batch brief pointed me at.
2. **Missing age-65 exemption**, per the batch brief: PIT-ADJ Line 13 exempts up to $8,000 based on
   a GRADUATED 8-step table keyed to federal AGI (Table 1), not a simple $28,500/$51,000 cliff as
   the brief's shorthand suggested -- the exemption steps down $1,000 per $1,500 (single) / $3,000
   (MFJ) of AGI above $18,000 (single) / $30,000 (MFJ), reaching exactly $0 at $28,501/$51,001. The
   $28,500/$51,000 figures ARE correct as the full-phase-out point, but describing it as a binary
   cliff (as opposed to graduated) would be inaccurate; my Case B deliberately sits mid-scale to
   test the graduated mechanism, not just the endpoints.

New Mexico's standard deduction correctly conforms to federal law in the engine (`conformsToFederal`), and per this batch's context item 5, the test harness already applies the age-65 addition and OBBBA senior bonus correctly for that branch -- so the ONLY divergence for NM is the two findings above, not a missing standard deduction.

**New Mexico is the required second carrier of the isMarried-hardcode regression** (Case C):
combined AGI $45,000 sits between the single cliff ($28,500) and the MFJ cliff ($51,000); under
the correct MFJ-column lookup the exemption is $3,000 (primary only qualifies), but under a mutant
that hardcodes `isMarried: false`, the lookup would wrongly use the single column (already past
its $28,500 cliff at this AGI) and return $0 -- a $45.00 tax difference this fixture is positioned
to catch.

**Arithmetic (all five cases):**

| Case | FAGI | Std ded | Exemption | Taxable | Bracket | Tax |
|---|---|---|---|---|---|---|
| A: single 55, $40k | 40,000 | 16,100 | 0 (age<65) | 23,900 | 434.50+4.3%×7,400 | **752.70** |
| B: single 70, $27k | 27,000 | 24,150 | 2,000 | 850 | 1.5%×850 | **12.75** |
| C: MFJ one 65+, $45k (between-thresholds carrier) | 45,000 | 39,850 | 3,000 | 2,150 | 1.5%×2,150 | **32.25** |
| D: MFJ both 65+, $40k | 40,000 | 47,500 | 8,000 | 0 (floored) | -- | **0.00** |
| E: single 70, $30k+$30k Roth=$60k | 60,000 | 24,150 | 0 (past $28,500) | 35,850 | 1,165.50+4.7%×2,350 | **1,275.95** |

**knownDefects (four of five -- Case D matched the engine exactly and needed none; MEASURED, tier4):**
- Case A (752.70): `observedToday 891.6`
- Case B (12.75): `observedToday 48.45`
- Case C (32.25): `observedToday 87.55000000000001`
- Case E (1,275.95): `observedToday 1477.15`
- Case D (0.00) is NOT a knownDefect: the harness's own `.conformsToFederal` standard-deduction computation already zeroes taxable income at this combined AGI regardless of the missing $8,000 exemption or the stale bracket table, so the engine and the form coincidentally agree. This is a genuine, honest finding, not a gap papered over.

**Disclosed-limitation sentence for NM:** "This app does not currently account for New Mexico's
age-65-or-older income exemption (up to $8,000 per qualifying spouse, phasing out on a graduated
scale between roughly $18,000 and $28,500 of federal AGI for a single filer, or $30,000-$51,000
for a married couple)."

**Note on tier labeling:** the brief groups NM with the "credit states" (OH, UT), but New Mexico's
$8,000 provision is an income EXCLUSION (a subtraction from AGI before tax), not a tax credit --
mechanically closer to NJ's or CO's retirement exclusions than to OH's or UT's dollar-for-dollar
credits. I kept `tier4` per the brief's explicit assignment for this batch, but the mechanism
description in each fixture's `knownDefect.summary` says "exemption," not "credit," to keep the
distinction accurate for Phase 5/6.

## Washington

**URLs opened:**
- `https://dor.wa.gov/taxes-rates/other-taxes/capital-gains-tax` -- opened directly with plain curl (no 403; this is the official DOR page).
- `https://dor.wa.gov/forms-publications/publications-subject/special-notices/new-tiered-rates-washingtons-capital-gains-tax` -- opened directly, "Issue Date June 30, 2025," full tier table read.

**Rule established:** Washington has no general income tax, but DOES levy a 7%/9.9% tiered excise
tax on long-term capital gains (RCW 82.87, enacted by ESSB 5096 in 2021; the second 9.9% tier was
added by ESSB 5813, Chapter 421, Laws of 2025, per the official DOR special notice). The engine
(`RetireSmartIRA/StateTaxData.swift:650-661`) sets `capitalGainsTreatment: .noStateTax` with a code
comment reading "7% on gains > $250K" -- a comment that describes a tax the engine does not
actually implement anywhere; `TaxCalculationEngine.swift:396` routes WA's `.specialLimited`
`taxSystem` straight to `tax = 0` unconditionally. The 2026 standard deduction figure ($278,000
for 2025, per-return not per-person, adjusted annually for inflation) has NOT been published as of
this research (confirmed by opening the DOR page directly and by search); every WA fixture uses
the 2025 figure and states that explicitly, per this task's own instruction for this exact
situation.

**Schema faithfulness (required by the task brief):** the `GoldenScenario` schema has NO field for
capital gains. I used `otherOrdinaryIncome` (documented as "declarative only," never summed into
anything or passed to the engine) purely to satisfy the `federalAGI`-equals-sum-of-components
shape invariant, and every WA fixture's `source` states explicitly and at length that this is a
SCHEMA LIMITATION, not a claim that the income is ordinary/wage/retirement income. I judged this
preferable to omitting WA from `covered` entirely, because the numeric behavior (engine always
returns $0 for WA regardless of field choice, since `.specialLimited` short-circuits before
reading any income composition at all) is unaffected by which field carries the dollar figure, so
no numeric claim is being smuggled in by the choice. A later phase reading this file will find the
schema gap named explicitly rather than silently worked around.

**Arithmetic (all five cases; 2025 standard deduction $278,000, tiers per the DOR special notice):**

| Case | Gross gain | Taxable gain | Tax |
|---|---|---|---|
| single, below deduction | 150,000 | 0 | **0.00** (matches engine by coincidence) |
| single, 7% tier only | 400,000 | 122,000 | 122,000×7% = **8,540.00** |
| MFJ, same gain (deduction not doubled) | 400,000 | 122,000 | **8,540.00** (identical to single case) |
| MFJ, crosses into 9.9% tier | 1,500,000 | 1,222,000 | 1,000,000×7%+222,000×9.9% = **91,978.00** |
| single, exactly at the $1M taxable-gain boundary | 1,278,000 | 1,000,000 | 1,000,000×7% = **70,000.00** |

**knownDefects (four of five -- the below-deduction case matches and needs none; all MEASURED at exactly `observedToday: 0.0`, tier4):**
All four nonzero cases confirmed the engine returns exactly `0.0` (not merely close to zero -- the
`.specialLimited` branch is an unconditional constant, so this is a mathematically exact pin, not
an approximation).

**Disclosed-limitation sentence for WA:** "This app does not currently model Washington's capital
gains excise tax (7% on long-term gains above roughly $278,000 per return, rising to 9.9% above $1
million of taxable gain); Washington is treated as having no state-level tax on any income,
including capital gains, which is INCORRECT for a household realizing a large capital gain."

## Minnesota

**URLs opened:**
- `https://www.revenue.state.mn.us/social-security-benefit-subtraction` -- opened directly.
- `https://www.revenue.state.mn.us/public-pension-subtraction` -- opened directly.
- `https://www.revenue.state.mn.us/sites/default/files/2024-12/m1qpen-24.pdf` -- opened directly (the 2025/2026-dated URL patterns for this specific form all 404'd after several attempts; the 2024 version was the most recent I could retrieve).
- `https://www.revenue.state.mn.us/press-release/2025-12-16/minnesota-income-tax-brackets-standard-deduction-and-dependent-exemption` -- opened directly; this is the official TY2026 bracket/standard-deduction press release, dated December 16, 2025.
- `https://www.revenue.state.mn.us/sites/default/files/2025-12/inflation-adjusted-amounts-2026.pdf` -- opened directly; this single, dated (December 1, 2025), official document is the primary source for every MN dollar figure in this batch (Social Security subtraction thresholds, Public Pension Subtraction maximums and thresholds, and the aged/blind additional standard deduction).

**Minnesota was previously unaudited.** It appears in no tier of the audit driving this phase and
on no confirmed-correct list; this file is a NEW finding about a state nobody had looked at yet,
not a confirmation of a prior result.

**Rule established:** Minnesota's TY2026 tax BRACKETS and BASE standard deduction are ALREADY
CORRECT in the engine -- I checked both directly against the official December 2025 press release
and they match exactly (single: 5.35%/6.80%/7.85%/9.85% at $33,310/$109,430/$203,150; standard
deduction $15,300 single / $30,600 MFJ). This is a genuine "the audit's prior wasn't wrong here"
result worth stating plainly, per this phase's instruction to say so when a state is correct. What
IS missing: (1) the Social Security subtraction (simplified method, full below AGI $86,410
single/$110,780 MFJ, phased 10% per $4,000 above -- `socialSecurityExempt` is hardcoded `false`
with no subtraction path at all); (2) the Qualified Public Pension Subtraction (Minn. Stat.
290.0132 Subd. 34, a HOUSEHOLD-capped, not per-spouse, subtraction of up to $13,850 single/$27,690
MFJ, restricted to specific non-Social-Security-covered public pension plans, phased 10% per
$2,000 of AGI above $86,410/$110,780); and (3) Minnesota's OWN $2,000 (single)/$1,600 (married, per
qualifying spouse) additional standard deduction for filers 65+ or blind, which is entirely
separate from the federal age-65 addition and is likewise absent because `stateDeduction.kind` is
a flat `fixed()` with no age-conditional term.

**Arithmetic (all five cases):**

| Case | FAGI | SS sub. | Pension sub. | Std ded (+aged) | MN AGI/taxable | Tax |
|---|---|---|---|---|---|---|
| single 55, pension $30k + SS $15k | 45,000 | 15,000 (full) | 0 (non-qualifying) | 15,300 | 14,700 | 14,700×5.35% = **786.45** |
| single 70, same composition | 45,000 | 15,000 | 0 | 17,300 (+2,000 aged) | 12,700 | **679.45** |
| MFJ both 65+, qualifying $50k combined | 50,000 | 0 | 27,690 (capped) | 33,800 (+3,200 aged) | 0 (floored) | **0.00** |
| MFJ one qualifying, $70k combined | 70,000 | 0 | 27,690 (capped, only qualifying $45k counted) | 32,200 (+1,600 aged) | 10,110 | 10,110×5.35% = **540.885→540.89** |
| single 70, $50k qualifying + $50k Roth=$100k | 100,000 | 0 | 4,155 (phased, 70% reduction) | 17,300 (+2,000 aged) | 78,545 | 1,782.085+6.8%×45,235 = **4,858.065→4,858.07** |

**knownDefects (all five, MEASURED, tier `unclassified` per the brief's instruction):**
- 786.45 case: `observedToday 1588.95`
- 679.45 case: `observedToday 1588.95` -- IDENTICAL to the age-55 case's engine value, which is itself a finding: the engine's flat `fixed()` standard deduction is completely age-blind, so it produces the SAME wrong number for a 55-year-old and a 70-year-old with identical income, when real law differs by exactly $107.00 ($2,000 aged addition × 5.35%).
- 0.00 case: `observedToday 1037.9`
- 540.89 case: `observedToday 2107.9`
- 4,858.07 case: `observedToday 5276.605`

**Disclosed-limitation sentence for MN:** "This app does not currently account for Minnesota's
Social Security income subtraction, its Qualified Public Pension Subtraction (limited to specific
non-Social-Security-covered government pension plans), or its own additional standard deduction
for filers 65 or older."

## CANNOT_VERIFY

None. All five jurisdictions in this batch were resolvable from primary sources; New Mexico's PIT-1
instructions PDF specifically (as opposed to PIT-ADJ, which I did retrieve) 404'd from every URL I
tried, but the bill text and PIT-ADJ instructions together were sufficient to derive every case
without it, so NM is not marked unverified. All five states remain in `covered`.

## Full-suite output

Batch-scoped run (`GoldenScenarioSingleYearTests` + `GoldenScenarioCoverageTests`) after adding
the `knownDefect` blocks: **9 tests in 2 suites passed, 0 failures** (23 test cases per
parameterized test, covering the full `covered` list including this batch's five states).

Full suite (`xcodebuild test -project .../RetireSmartIRA.xcodeproj -scheme RetireSmartIRA
-destination 'platform=macOS'`):

```
Test run with 1851 tests in 291 suites passed after 315.909 seconds.
Test Suite 'RetireSmartIRATests.xctest' passed at 2026-08-04 16:20:09.686.
	 Executed 509 tests, with 0 failures (0 unexpected) in 22.136 (22.299) seconds
Test Suite 'All tests' passed at 2026-08-04 16:20:09.686.
	 Executed 509 tests, with 0 failures (0 unexpected) in 22.136 (22.299) seconds
** TEST SUCCEEDED **
```

1,851 Swift Testing tests in 291 suites (matches baseline exactly -- adding fixtures did not raise
the count, as expected) + 509 XCTest (matches baseline exactly), 0 failures. 6 Swift Testing tests
skipped (matches the baseline's "6 skipped" -- all are the env-gated 27-profile audit-harness tests
and two "Generate ..." maintenance tests, none related to this batch). `MultiYearStrategyManagerPerfTests`
and the "Performance -- full compute() across personas" suite (the perf-adjacent suites in this
codebase) both ran and passed cleanly in this run; I did not observe a flake and have nothing to
report as a re-run-in-isolation finding.

## Production diff (must be empty)

```
$ git diff --stat main -- RetireSmartIRA/
(no output)
```

Confirmed empty. `git status --short` shows only the five new fixture files and the one-line
append to `GoldenScenarioCoverageTests.swift`.

## Em dash check

Checked with a direct Python Unicode scan (U+2014) across all five new fixture JSON files plus the
modified `GoldenScenarioCoverageTests.swift`: zero matches. I used `--` (double hyphen) throughout
in place of any em dash.

## Deviations from the brief, with reasoning

1. **Utah's Retirement Credit thresholds ($54,000/$90,000) were REJECTED, not used.** The brief's
   own text ("Utah has up to $450 per person, full at or below $54,000 single and $90,000 joint")
   conflates two different Utah credits. I verified against the primary source (TC-40 Instructions
   and Utah Code 59-10-1019) and found the Retirement Credit's actual phase-out starts at $25,000
   single/$32,000 MFJ MAGI at a much steeper 2.5%-per-dollar rate, and is gated by a FIXED 1952
   birth-year cutoff, not age 65. The $54,000/$90,000 figures belong to the separate Social
   Security Benefits Credit. I used the correct, verified figures rather than the brief's.
2. **A previously-unidentified Utah finding (the Taxpayer Tax Credit) dominates the UT results.**
   Not mentioned anywhere in the brief; discovered by reading the TC-40 line-by-line instructions
   in full rather than stopping once the named credit was found.
3. **A previously-unidentified Ohio finding (the $332 TY2026 bracket base amount) affects every OH
   case**, not just the credit-eligible ones. Not mentioned in the brief.
4. **A previously-unidentified New Mexico finding (the entire bracket schedule is stale, pre-HB252)
   affects every NM case.** Not mentioned in the brief, which framed NM purely as an age-exemption
   state.
5. **New Mexico Case D (MFJ, both spouses 65+) needed no `knownDefect`** because the engine's own
   correct standard-deduction handling already zeroes taxable income at that income level
   regardless of the missing $8,000 exemption; I did not force a defect record where the numbers
   genuinely agree.
6. **Washington fixtures carry the gain amount in `otherOrdinaryIncome`** rather than being
   omitted from `covered`, with the schema limitation stated explicitly in every fixture's prose,
   per the brief's own instruction to do exactly this if a faithful representation isn't possible.
7. **Minnesota's tier is `unclassified`**, per the brief's explicit instruction, even though the
   findings (SS subtraction, pension subtraction, aged addition) are somewhat heterogeneous.

## Register update

`GoldenScenarioCoverageTests.covered` now reads: `["PA", "IL", "MS", "NJ", "NY", "AK", "FL", "NV",
"SD", "TN", "TX", "WY", "NH", "CA", "NE", "ND", "IN", "OR", "OH", "UT", "NM", "WA", "MN"]` (23
jurisdictions total after this batch).

## Addendum: citation-precision fixes (post-approval reviewer findings)

This batch was approved on substance. A reviewer independently re-fetched the primary sources and
found five citation-precision issues, none of which change any `expectedStateTax` or
`observedToday` value. Per instruction, I re-verified every finding against the actual documents
myself before changing anything, rather than forwarding the findings blind. All five held up under
my own check (four confirmed as described, one confirmed but with a location correction, and I
found one additional instance of the same underlying error the reviewer did not call out).

**Finding 1 (New Mexico, single/estates-and-trusts bracket table page) -- CONFIRMED, FIXED.**
I downloaded `HB0252TRS.pdf` directly (`curl` + `pdftotext -layout`, page-by-page) and read printed
pages 14 through 18 myself. Printed page 16 ends with the NEW married-filing-jointly table's data
rows followed only by the NEW single/estates-and-trusts table's column header ("B. For single
individuals and for estates and trusts: For taxable income: The tax shall be:") -- no data rows.
The quoted six-row table ("Not over $5,500: 1.5%" through "Over $210,000: $9,748 plus 5.9%...")
is entirely on printed page 17. I also confirmed the document's own page-bottom marker ("- 16 -",
"- 17 -") so printed page and PDF page are IDENTICAL in this document (no cover-page offset):
printed page 16 = PDF page 16, printed page 17 = PDF page 17. Fixed the citation in Case A's
`source` string (the load-bearing citation for 4 of 5 NM records) from "printed page 16" to
"printed page 17, PDF page 17 of 45," with a note on what page 16 actually contains.

**Finding 2 (New Mexico, PIT-ADJ Table 1 "same page" citation) -- CONFIRMED, FIXED, plus one
additional instance the reviewer did not flag.** I downloaded the 2025 PIT-ADJ Instructions PDF
directly and read PDF pages 4 and 5 (document pages ADJ-4 and ADJ-5) myself. ADJ-4 (PDF page 4)
carries the "LINE 13. Exemption for persons age 65 or older, or blind" narrative in full, ending
with worked examples and "Mark Correct Boxes on PIT-1 Return" instructions, then moves straight
into "LINE 14" -- no table anywhere on the page. ADJ-5 (PDF page 5) opens directly with "TABLE 1.
Exemptions for Persons 65 or Older or Blind (see line 13 instructions)," the boxed table itself.
The reviewer named cases B, C, and D as citing Table 1 to the wrong page; on my own check, Case E
ALSO cites "page ADJ-4, Table 1" for the same lookup and has the identical error, which the
reviewer's finding did not mention. I fixed all four (B, C, D, and E), each now citing "page ADJ-5,
PDF page 5 of 8" for the table itself, distinct from the ADJ-4 narrative citations (which remain
correct and unchanged, since the Line 13 narrative genuinely is on ADJ-4).

**Finding 3 (Utah, dangling OBBBA cross-reference) -- CONFIRMED as dangling, rationale
INDEPENDENTLY VERIFIED, not merely adopted.** I confirmed via `grep -n OBBBA` on the report that
every "OBBBA" mention in the deliverable is in the New Mexico section; there is no Utah-specific
explanation anywhere, including in the single commit's git history for this file (only one commit
exists, `f794548`, so there is no earlier draft to recover a lost rationale from). I did not simply
adopt the reviewer's reconstruction on faith. I re-read the 2025 TC-40 Instructions myself
(downloaded directly, `pdftotext -layout` pages 7-8): Line 12 of the Taxpayer Tax Credit worksheet
is defined verbatim as "Enter your federal standard or itemized deduction from line 12e of your
federal return (1040, 1040-SR)." I then confirmed independently (WebSearch, IRS and secondary
sources including the IRS's own "Check your eligibility for the new enhanced deduction for
seniors" guidance) that the OBBBA enhanced senior deduction is NOT part of federal line 12e: it is
computed on 2025 Schedule 1-A, Part V, and flows to a separate Form 1040 line 13b, added AFTER line
12e in the 1040's own arithmetic. Since Utah's Line 12 pulls only from 12e by its own text, and the
senior bonus lives on 13b, the exclusion is correct under real law, independently confirmed rather
than taken on the reviewer's word. I wrote this rationale in full into the affected fixture's
`source` string (the $110,000-Roth-conversion case) and dropped the "see the batch report for why"
pointer, per the FIX instruction's first option combined with its second: the reasoning is now
self-contained in the fixture rather than requiring a cross-reference into a separate file.

**Finding 4 (Washington, causal overstatement about `agreeing`) -- CONFIRMED, but MISLOCATED as
described; fixed at the actual location.** I read `GoldenScenarioCrossPathTests.swift:50` directly:
`static let agreeing = ["PA", "IL", "MS"]`, a hardcoded literal. Washington's exclusion from
`pathsAgree` is automatic and has nothing to do with `otherOrdinaryIncome`, exactly as the reviewer
said. However, `grep -n "agreeing" task-9-report.md` returns nothing -- the offending sentence is
not in the report at all. It is in `statetax-2026-WA.golden.json`'s first scenario's `source`
string ("This fixture is EXCLUDED from GoldenScenarioCrossPathTests.agreeing both because nonzero
otherOrdinaryIncome always excludes a fixture from that suite..."). I fixed the wording at that
actual location, not in the report (which never made this claim), reading: "This fixture is not
exercised by GoldenScenarioCrossPathTests.pathsAgree because `agreeing`
(GoldenScenarioCrossPathTests.swift:50) is a hardcoded list, ['PA', 'IL', 'MS']; Washington's
absence from that suite is automatic and definitional, not a consequence of carrying its gain in
otherOrdinaryIncome or of any other field choice in this fixture..."

**Finding 5 (Ohio source type, LSC bill analysis vs. codified statute) -- NO CHANGE, noted as a
known follow-up.** Confirmed by re-reading the Attestation and Ohio sections of this report: the
LSC bill-analysis citation and the reason a standalone TY2026 statute page could not be found are
already disclosed in both the Attestation section (lines 12-18 above) and inline in the Ohio
section. Flagging here per the instruction so it is not lost: a future pass should retarget this
citation to R.C. 5747.02 once a TY2026 IT 1040 booklet is published; no action taken now.

**Test suite (focused, foreground, this batch's fixtures only):**

```
$ xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA \
    -destination 'platform=macOS' \
    -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests \
    -only-testing:RetireSmartIRATests/GoldenScenarioCoverageTests
...
✔ Test "Single-year path matches each state's own published form" with 23 test cases passed after 0.018 seconds.
✔ Test "classify covers all five outcomes of the defect-pin decision" passed after 0.007 seconds.
✔ Test "A fixture with no knownDefect decodes it as nil" passed after 0.001 seconds.
✔ Test "The .conformsToFederal branch deducts the age-65+ addition and OBBBA senior bonus" passed after 0.001 seconds.
✔ Suite "Golden scenarios, single-year path" passed after 0.026 seconds.
✔ Test run with 9 tests in 2 suites passed after 0.191 seconds.
** TEST SUCCEEDED **
```

Unchanged pass count and outcome from the original batch run (9 tests, 2 suites, 0 failures),
consistent with these being comment-only citation edits.

**Production diff (must be empty):**

```
$ git diff --stat main -- RetireSmartIRA/
(no output, exit 0)
```

`git status --short` shows only the three edited fixture files: `statetax-2026-NM.golden.json`,
`statetax-2026-UT.golden.json`, `statetax-2026-WA.golden.json`. No other fixture, and nothing under
`RetireSmartIRA/`, was touched.

**Em dash check:** re-ran the scan (Python, counting occurrences of the U+2014 character) across all three edited files:
zero matches in each. One authoring slip caught and fixed during this pass: my first edit to the
Washington fixture used literal double-quoted list syntax (`["PA", "IL", "MS"]`) inside an
already-double-quoted JSON string, which broke JSON parsing (`json.decoder.JSONDecodeError` on
reload); corrected to single-quoted list syntax matching this file's existing convention before
proceeding to the test run.
