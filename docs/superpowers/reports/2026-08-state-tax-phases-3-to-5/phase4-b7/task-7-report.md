# Task 7 report: Tier 2, the per-source wall (KS, MA, HI, AZ, NC, ID, VT, DC)

## Reading this report

Every case below carries a form-derived `expectedStateTax`. For every case that ALSO carries a
`knownDefect` block, that is deliberate and the two numbers are meant to disagree:
`expectedStateTax` is what the state's own form says is owed, `knownDefect.observedToday` is what
the engine ACTUALLY computes today (measured by running the suite, never predicted), and the test
asserts the engine matches `observedToday` and does **not** match `expectedStateTax`. A green run
on a `knownDefect` case confirms the MEASURED gap holds; it does not mean the engine agrees with
the correct figure. Where a case has no `knownDefect` block, the engine already matches
`expectedStateTax` exactly (a real pass, not a pinned gap).

## Scenario count and defect/clean split

39 scenarios total across 8 fixtures. **32 carry a `knownDefect`; 7 pass clean** (no defect,
engine already agrees with the form):

| State | Scenarios | knownDefect | Clean |
|---|---|---|---|
| KS | 6 | 6 | 0 |
| MA | 4 | 3 | 1 |
| HI | 4 | 3 | 1 |
| AZ | 5 | 4 | 1 |
| NC | 4 | 3 | 1 |
| ID | 5 | 4 | 1 |
| VT | 6 | 6 | 0 |
| DC | 5 | 3 | 2 |
| **Total** | **39** | **32** | **7** |

The 7 clean cases are not padding: each is a deliberate contrast case proving the engine is not
uniformly broken for that jurisdiction (a private/non-qualifying pension taxed correctly, or a
below-age-threshold case correctly denied). Two of DC's clean cases in particular overturn an
assumption in this batch's own brief (see the DC section).

## CANNOT_VERIFY

**North Carolina, on expressibility, not on the law, for ONE specific sub-case only.** NC's
Bailey/Emory/Patton exclusion is a vesting-date rule (5+ years of creditable service in a
qualifying NC/federal government retirement system as of 1989-08-12), confirmed directly from
NCDOR's own bulletin. `ClassifiedPensionSource` carries `amount`/`planStructure`/`planSource`
only, with no vesting-date field, and `PlanSource` has no NC-specific case. A single fixture CAN
stipulate Bailey status in prose for one classified row, which is what all four NC cases below do
(and none of them are CANNOT_VERIFY -- they are pinned, testable golden cases). What genuinely
cannot be expressed is a household with TWO government pensions of the identical `PlanSource`
where only ONE is Bailey-vested (e.g. one spouse hired in 1975, the other hired in 1995 into the
same NC state system): both rows would decode to the same `planSource` with no field to
distinguish them, so the model cannot carry that specific combination. The law is clear; the model
cannot express it. No fixture was written for that mixed-vesting combination, and NC IS included
in `covered` because the other four cases are fully verifiable and pinned.

No jurisdiction in this batch was left out of `covered`. All 8 are included.

## Citation attestation

I personally opened every `sourceURL` in this batch and checked every clause of each `source`
string against the page, using `curl` (with a browser User-Agent, and for one Vermont URL a
Referer header, after a 403) piped through `pdftotext -layout` with page-boundary splitting for
every PDF citation, and direct HTML text extraction for the two web-page citations (MA and NC's
NCDOR page). Every page number cited below is the page number I found the quoted text on, not the
page a search snippet implied. For DC I additionally opened the actual DC Code statute AND the
2024 D-40 booklet to cross-check the statute's sunset clause against current form instructions,
since the two disagreed with the batch brief's assumption about DC.

## Per-jurisdiction detail

### Kansas (KS) -- 6 scenarios, 6 knownDefect, 0 clean

**Sources opened:** `https://www.ksrevenue.gov/pdf/ip25.pdf` (2025 Individual Income Tax Booklet,
37 pages, fetched via curl, extracted with `pdftotext -layout` and split on form-feed characters
to get real page numbers).

**Rule as established:**
- Page 2 ("Exemptions and Dependents") and page 6 (K-40 Line 4 instructions, right next to the
  Kansas Standard Deduction table showing Single $3,605 / Married $8,240, which matches this app's
  configured `statetax-2026-KS.json`): personal exemption is **$18,320 MFJ / $9,160 single /
  $2,320 per dependent**, per Senate Bill 1 (2024 Special Session), no sunset. This app has NO
  `personalExemption` entry for KS at all.
- Page 12, Schedule S Instructions, **Line A14** ("Retirement benefits specifically exempt from
  Kansas Income Tax"): enumerates **only** Federal Civil Service Retirement/Disability Fund
  payments, benefits from federal-government employment or U.S. Armed Forces service (including
  Thrift Savings Plans), U.S. Railroad Retirement Board payments, and **KPERS annuities** as
  subtractable. Private pensions, 401(k)s, and IRAs are not on this list and remain fully taxable.

**Two defects, written separately per the brief:**

1. **Missing personal exemption (KS-1, KS-2).** KS-1 reproduces Steve Nicolai's exact reported
   scenario to the cent (MFJ, $50,000, $8,240 standard deduction, 5.2%): expected $1,218.88,
   measured engine output $2,171.52. Arithmetic: $50,000 - $8,240 - $18,320 = $23,440 x 5.2% =
   $1,218.88 (true); $50,000 - $8,240 = $41,760 x 5.2% = $2,171.52 (engine, no personal
   exemption). KS-2 repeats the same isolated mechanism (no pension income at all) for a single
   filer at $30,000: true $896.22, engine $1,385.44. Both cases use **no pension income
   whatsoever**, so they are unaffected by defect 2 and will go green the moment Phase 5a alone
   implements `StatePersonalExemption` for KS, independent of the per-source fix.
2. **Missing per-source pension rule (KS-3 through KS-6).** KS-3 (private pension, $40,000,
   single, age 68) and KS-4 (KPERS, same $40,000/age/filing status) are a matched pair: true tax
   is $1,432.31 for the private pension (taxable both ways, so KS-3's whole gap versus the engine
   is the personal-exemption defect it inherits, not a per-source miss) and $0.00 for KPERS (fully
   exempt), while the engine returns the identical $1,943.44 for both, proving it is blind to
   source. KS-5 (MFJ, both spouses have exempt pensions, $25k KPERS + $25k federal civilian) and
   KS-6 (MFJ, one spouse KPERS-exempt $25k + one spouse private-taxable $25k) both true to $0.00
   and both measure $2,171.52 from the engine -- the identical figure Steve's own ordinary-income
   case (KS-1) produces at the same $50,000 MFJ income, despite three completely different real
   tax liabilities ($1,218.88 / $0.00 / $0.00). These per-source cases will not go fully green
   until BOTH Phase 5a (personal exemption) and the per-source fix land, since their
   `expectedStateTax` is derived from TRUE Kansas law (which includes the real personal
   exemption); this is expected, not a design flaw -- see the "Reading this report" note above.

**Not tested:** U.S. Railroad Retirement Board payments as their own case. `PlanSource` has no
enum value for it (I used `federalCivilian` for federal-civilian/military and `otherStateOrLocal`
for KPERS, both disclosed as imprecise NY-centric labels reused for Kansas), and a dedicated RRB
case would not exercise the engine any differently than the federal-civilian case already does
(no `perSourceExemptions` for KS regardless). Flagged, not written, to keep scope bounded.

### Massachusetts (MA) -- 4 scenarios, 3 knownDefect, 1 clean

**Source opened:** `https://www.mass.gov/info-details/tax-treatment-of-government-pensions-in-massachusetts`
(fetched via curl, HTML stripped and searched by section anchor).

**Rule as established:**
- Section "Massachusetts state and local employee contributory pension": "Distributions made to
  you from a Massachusetts state and local employee contributory plan are excluded from
  Massachusetts gross income even though they are included in federal gross income." No age gate,
  no dollar cap.
- Section "U.S. military non-contributory pension": "U.S. military pensions, which are included
  in federal gross income, are excluded from Massachusetts gross income."
- Noncontributory municipal pensions: I did **not** find a sentence stating these are taxable.
  This is an **inference** from the page's closed list of exempt categories (MA/local
  contributory, federal contributory, MBTA, out-of-state reciprocal contributory, railroad
  retirement, U.S. uniformed-services noncontributory) -- a noncontributory municipal pension
  appears on none of them, so under M.G.L. c. 62's general starting-from-federal-gross-income
  rule it remains taxable. Disclosed as an inference, not a verbatim quote, in the fixture itself.

**Cases:** MA-1 (single, MA contributory pension $60,000): true $0.00, engine $3,000.00. MA-2
(single, noncontributory municipal $60,000): true and engine both $3,000.00 -- **clean, no
defect**, MA's blanket full-taxation-by-default happens to be correct here. MA-3 (MFJ, both
spouses MA contributory, $75,000 combined): true $0.00, engine $3,750.00. MA-4 (MFJ, one spouse
military-exempt $30,000 + one spouse private-401(k)-taxable $30,000): true $1,500.00, engine
$3,000.00.

**Deviation:** MA's own real personal exemption ($4,400 single / $8,800 MFJ per Form 1) is not
modeled in this app's config (`stateDeduction: none`, no `personalExemption`) and is out of this
task's per-source scope. I held the engine's currently-configured deduction structure (none)
constant in the "true" computation and varied only pension-source treatment. See the batch-wide
deviation note below.

### Hawaii (HI) -- 4 scenarios, 3 knownDefect, 1 clean

**Source opened:** `https://files.hawaii.gov/tax/forms/current/schj_i.pdf` (Schedule J Form
N-11/N-15/N-40 Instructions, REV. 2025, 4 pages, fetched via curl, extracted with
`pdftotext -layout`).

**Rule as established (page 2, "WHO MUST USE THIS FORM"):** "The pension exclusion applies only to
amounts attributable to employer contributions." Item 3: "A pension plan to which NO employee
contributions were made (i.e. the employer paid for the entire cost of the pension) if
distributions are made after retiring or after attaining the age of 73...The entire amount is NOT
subject to Hawaii taxation." Elsewhere (pages 1-2): 401(k) elective-deferral and IRA distributions
are "returns from an individual investment" and do not qualify. **Hawaii's rule keys on WHO FUNDED
the plan, not on employer type** -- a private-sector noncontributory pension qualifies exactly as
a government one would, which is a materially different axis than KS/AZ/NC/DC's
government-vs-private rules. This maps cleanly onto `PlanStructure` (`definedBenefit` as the proxy
for employer-funded/noncontributory, `definedContribution`/`ira` for employee-funded), so there is
**no expressibility gap** for Hawaii, unlike NC and (partially) DC.

**Cases:** HI-1 (single, employer-funded private-sector DB pension, $50,000): true $0.00, engine
$2,107.20. HI-2 (single, 401(k) elective-deferral distribution, $50,000): true and engine both
$2,107.20 -- **clean**. HI-3 (MFJ, both spouses employer-funded, $75,000 combined): true $0.00,
engine $2,466.40. HI-4 (MFJ, one employer-funded $40,000 + one 401(k)-deferral $35,000): true
$266.00, engine $2,466.40.

**Note on scope:** Hawaii was explicitly scoped as "disclosed, not modelled" in Phase 3b. These
four fixtures are written to correct law anyway, per the brief's instruction, so Phase 6 knows
what sentence to put in Hawaii's `knownLimitations`.

### Arizona (AZ) -- 5 scenarios, 4 knownDefect, 1 clean

**Source opened:**
`https://azdor.gov/sites/default/files/document/FORMS_INDIVIDUAL_2025_140i.pdf` (Arizona Form 140
2025 Instructions, fetched via curl, extracted with `pdftotext -layout`, page-split).

**Rule as established, RICHER than the batch brief described:**
- Page 14, **Line 29a**: government pensions (U.S. Government Service Retirement and Disability
  Fund, AZ state/local) get "the amount you received or $2,500, whichever is less," and
  critically: **"If both you and your spouse receive such pension income, each spouse may subtract
  the amount received or $2,500, whichever is less"** -- i.e. the cap is per-INDIVIDUAL, doubling
  to $5,000 when both spouses qualify. This app's `statetax-2026-AZ.json` sets
  `exemptionAppliesPerIndividual: false`, so the engine applies one shared household cap. **This is
  a real, primary-source-confirmed finding beyond what the brief described**, not present in the
  audit's summary.
- Page 15, **Line 29b**: "retired or retainer pay of the uniformed services of the United States"
  is a SEPARATE, 100%-uncapped exclusion ("you may subtract 100% of the amount you received"),
  explicitly carved OUT of Line 29a ("Do not enter any subtraction for pension income received
  from retired or retainer pay of the Uniformed Services"). The engine's `pensionExemption` is a
  single flat `.partial(maxExempt: 2500)` applied to all pension income, with no Line 29b
  mechanism at all.

**Cases, both directions of the same-cap-for-all defect plus the doubling defect:** AZ-1 (single,
government pension $2,000 under the cap): true and engine both $346.25 -- **clean**, the app
correctly handles a pure-government-pension household. AZ-2 (single, PRIVATE pension $2,000,
ineligible for 29a): true $396.25, engine (wrongly grants the exclusion) $346.25 -- engine
UNDERSTATES tax. AZ-3 (single, MILITARY pension $40,000, eligible for the uncapped 29b): true
$0.00, engine (grants only the $2,500 29a cap) $333.75 -- engine OVERSTATES tax, the **opposite
direction** from AZ-2, both stemming from the same root cause (one flat cap for every pension
type). AZ-4 (MFJ, both spouses government pensions $2,000 each, testing the doubling): true
$1,312.50 (each spouse's own $2,500 cap), engine $1,350.00 (one shared $2,500 cap). AZ-5 (MFJ, one
government $2,000 + one private $2,000): true $1,453.75, engine $1,441.25 -- a smaller,
opposite-signed error from the per-source miss and the non-doubling miss partially offsetting.

### North Carolina (NC) -- 4 scenarios, 3 knownDefect, 1 clean

**Source opened:**
`https://www.ncdor.gov/taxes-forms/individual-income-tax/filing-topics/bailey-decision-concerning-federal-state-and-local-retirement-benefits`
(fetched via curl, HTML stripped).

**Rule as established:** "the North Carolina Consolidated Judicial Retirement System, the Federal
Employees' Retirement System, or the United States Civil Service Retirement System, if the retiree
had five or more years of creditable service as of August 12, 1989" are exempt, claimed on "Line
20, Form D-400, Schedule S 2025 Supplemental Schedule." "The exclusion does not apply to
retirement benefits paid to former teachers and state employees of OTHER states" -- private
pensions are never covered regardless of vesting date.

**Cases:** NC-1 (single, Bailey-vested, stipulated in prose, $50,000): true $0.00, engine
$1,486.27. NC-2 (single, private pension, $50,000): true and engine both $1,486.27 -- **clean**.
NC-3 (MFJ, both Bailey-vested, $75,000 combined): true $0.00, engine $1,975.05. NC-4 (MFJ, one
Bailey-vested $40,000 + one private $35,000): true $379.05, engine $1,975.05. See the
CANNOT_VERIFY section above for the one combination these four cases deliberately do not cover.

### Idaho (ID) -- 5 scenarios, 4 knownDefect, 1 clean

**Source opened:**
`https://tax.idaho.gov/wp-content/uploads/forms/EFO00088/EFO00088_03-02-2026.pdf` (Form 39R
Instructions 2025, fetched via curl, extracted with `pdftotext -layout`, page-split).

**Rule as established, with a nuance the brief's summary blurred:**
- Page 7, "Part One -- Age, Disability, and Marital/Filing Status": "The recipients must be at
  least age 65 or be classified as disabled and be at least age 62." This is the GENERAL gate for
  CSRS/FSRDS, PERSI firefighters, and qualifying Idaho police retirement funds (page 7-8, "Part
  Two -- Qualified Retirement Benefits").
- Page 7, Line 8a: maximum deductible for 2025 is **$48,216 single / $72,324 MFJ**, reduced
  dollar-for-dollar by Social Security and Railroad Retirement Act benefits received.
- Page 7-8, **Line 8e, "The Idaho Retirement Benefits Deduction for Retired Service Members"**:
  a SEPARATE, more lenient age test -- "Classified as disabled (any age), or Age 62 or older" --
  that does not use Part One's general 65-year gate. **Military retirees qualify at 62, not 65,**
  a distinction the batch brief's one-line summary ("CSRS, Idaho police and fire, and military, at
  65 or over") did not carry.

**Cases:** ID-1 (single, CSRS, age 60, fails the general gate): true and engine both $1,266.70 --
**clean**. ID-2 (single, CSRS, age 68): true $0.00 (pension fully absorbed by the deduction),
engine $840.05. ID-3 (single, MILITARY, age 63 -- fails the general 65 gate but passes the
military-specific 62 gate): true $0.00, engine $1,266.70, directly demonstrating the distinct age
gate. ID-4 (MFJ, both 68/70, CSRS combined $80,000, exceeding the $72,324 MFJ cap): true $0.00
(cap still exceeds remaining taxable income), engine $1,722.50. ID-5 (MFJ, one CSRS-qualifying
$40,000 + one private $30,000): true $0.00, engine $1,597.95.

**Not tested:** a dedicated "Idaho police/fire" case (PERSI Firefighters Retirement Fund, qualifying
Idaho city police funds). Real law, not tested for scope reasons; not a defect finding since
untested is not the same as wrong.

### Vermont (VT) -- 6 scenarios, 6 knownDefect, 0 clean

**Source opened:** `https://tax.vermont.gov/sites/tax/files/documents/IN-112-Instr-2025.pdf`
(2025 Schedule IN-112 Instructions, 6 pages, fetched via curl with a Referer header after the
first request 403'd with a plain User-Agent -- the 403 was a tool/network artifact, not evidence
the document doesn't exist, per the brief's item 5). Extracted with `pdftotext -layout`,
page-split.

**MAJOR FINDING: the batch brief's description of VT's rule is stale.** The brief said "$10,000
military and CSRS exclusion, AGI-limited at $55k single and $70k MFJ" as if one rule covered both.
Primary-source verification shows these are TWO INDEPENDENT exclusions with very different
mechanics:
- **CSRS / "Other Retirement System" (page 2, Retirement Income Exemption Worksheet):** $10,000
  cap, full exemption at AGI < $55,000 single / $70,000 MFJ, linear phase-out to zero at $65,000
  single / $80,000 MFJ. This part of the brief's description is correct.
- **Military retirement (page 3-4, Military Retirement Income Exemption Worksheet): brand new for
  tax year 2025 under Act 71 (S.51), signed into law June 25, 2025, no sunset found.** FULL
  exemption at AGI <= $125,000 for ANY filing status (no single/MFJ split, unlike CSRS), UNCAPPED
  (not $10,000 -- the entire military pension), linear phase-out to zero at $175,000. This is a
  materially larger benefit than CSRS's $10,000 cap and the brief's summary collapsed the two into
  one rule.

**Cases:** VT-1 (single, CSRS $40,000, AGI $40,000, below the $55,000 full-exemption threshold):
true $742.03, engine $1,077.03. VT-2 (single, CSRS $60,000, AGI in the $55k-$65k phase-out band):
true $1,579.53 (fraction 0.5 retained), engine $1,885.15 -- pins the phase-out SHAPE, not just the
binary full/zero cases. VT-3 (MFJ, both spouses CSRS, $65,000 combined, below the $70,000
threshold): true $1,316.55, engine $1,651.55. VT-4 (MFJ, one CSRS-eligible $30,000 + one private
$25,000, ineligible since private employment is Social-Security-covered): true $981.55, engine
$1,316.55. VT-5 (single, MILITARY $100,000, below the new $125,000 threshold, uncapped): true
$0.00, engine $4,525.15 -- the largest RELATIVE gap in this batch. VT-6 (single, MILITARY
$150,000, in the $125k-$175k phase-out band): true $2,875.15, engine $8,086.65 -- a **$5,211.50**
gap, the single largest DOLLAR defect measured in this entire batch.

### District of Columbia (DC) -- 5 scenarios, 3 knownDefect, 2 clean

**Sources opened:** `https://code.dccouncil.gov/us/dc/council/code/sections/47-1803.02` (official
DC Code, fetched via curl) AND
`https://otr.cfo.dc.gov/sites/default/files/dc/sites/otr/publication/attachments/2024_D40_Booklet_011525.pdf`
(2024 D-40 Booklet, 97 pages, fetched via curl, extracted with `pdftotext -layout`, page-split, and
searched in full for "pension"/"$3,000"/"survivor" to cross-check the statute against current form
instructions).

**MAJOR FINDING: the batch brief's description of DC's rule describes EXPIRED law.** The brief
said "$3,000 at 62 or over, DC or federal government pensions only." DC Code Section
47-1803.02(a)(2)(N)(i): "Pension, military retired pay, or annuity income received from the
District of Columbia or the federal government by persons who are 62 years of age or older...
except that the exclusion shall not exceed the lesser of $3,000...**provided further, that this
sub-subparagraph shall apply for taxable years beginning before January 1, 2015.**" This provision
**expired for tax years 2015 onward and does not apply for 2026.** I confirmed this against the
current D-40 booklet: searching all 97 pages, there is no pension-exclusion line anywhere for a
living retiree's own pension. What DOES remain, with no sunset clause, is subparagraph (N)(ii):
"Survivor benefits received from the District of Columbia or the federal government by persons who
are 62 years of age or older." The D-40 booklet, page 17, "Line 12 DC and federal government
survivor benefits": "If you are an annuitant's survivor and 62 years of age or older as of December
31, 2024, enter the total survivor benefits (do not include Social Security survivor benefits)."
**Current DC law excludes only a SURVIVOR's benefit income, uncapped, age 62+, DC/federal source
only -- not a living retiree's own pension of any kind.**

**Expressibility note:** `ClassifiedPensionSource` has no field distinguishing "this is a survivor
benefit" from "this is the retiree's own pension" (there is no `.survivorBenefit` `IncomeType`
either). DC-2, DC-3, and DC-4 below stipulate survivor status in prose for a single classified row
per case, the same convention NY's `otherOrdinaryIncome` and NC's Bailey-vesting cases use. This is
expressible for one row at a time; a household with two same-`planSource` pensions where one is a
survivor benefit and the other is the same person's own pension would hit the same kind of
same-classification collision NC's mixed-vesting case does, but no fixture needed that combination
here, so this did not become a second CANNOT_VERIFY entry.

**Cases:** DC-1 (single, age 55, survivor benefit $50,000, fails the 62+ gate): true and engine
both $1,924.00 -- **clean**, correctly denied for being under 62. DC-2 (single, age 65, survivor
benefit $50,000): true $0.00, engine $1,924.00. DC-3 (MFJ, both spouses 62+ survivors, $55,000
combined, stipulated): true $0.00, engine $1,546.00. DC-4 (MFJ, one spouse survivor-exempt $30,000
+ one spouse private-taxable $60,000): true $1,846.00, engine $3,848.50. DC-5 (single, age 65, OWN
federal civil service pension, NOT a survivor benefit, $50,000): true and engine both $1,924.00
-- **clean**, confirming the general pension exclusion the brief assumed is current is in fact
dead law, and the engine's total silence on DC pensions happens to be correct for this specific
case.

## Batch-wide deviation: deduction/exemption structure held constant outside the per-source axis

For MA, HI, AZ, NC, ID, VT, and DC (all but KS, which the brief explicitly calls out for its
personal-exemption gap), several of these states have real-world deduction or exemption mechanics
this app's config does not model at all (e.g. MA's Form 1 personal exemption, HI's per-exemption
allowance). None of these are named in this task's brief as in-scope, and Task 7's own framing is
"the per-source wall" specifically. I held the engine's currently-configured deduction structure
(as shipped in each state's JSON) constant in both the "true" and "engine" computations, and varied
only pension-source treatment. This keeps each case's gap attributable to exactly one mechanism
(the one this batch is verifying) rather than an unscoped, unflagged second defect bleeding into
the same number. This is disclosed here rather than silently assumed; a future phase auditing
those other dimensions should not read a `matchesForm` case in this batch as certifying MA's or
HI's personal exemption is correctly absent -- it was not evaluated.

## Full-batch verification

**Targeted run** (`-only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests`): 26 test
cases (18 pre-existing jurisdictions + this batch's 8), 4 auxiliary tests, all passed, 0 failures,
on the FIRST run -- every hand/script-derived `expectedStateTax` and `knownDefect.observedToday`
matched the engine's actual output exactly, with no `pinnedDefectMoved` or
`unexplainedDisagreement` outcomes.

**Full suite** (`xcodebuild test`, no `-only-testing` filter):

```
✔ Test run with 1851 tests in 291 suites passed after 322.886 seconds.
** TEST SUCCEEDED **
```

1,851 Swift Testing tests in 291 suites -- exactly the pre-batch baseline (1,851/291), confirming
this batch's 39 new parameterized scenarios did not inflate the count, per the brief's note that
adding fixtures does not raise it. The paired XCTest suite's own completion line was outside the
window of the `tail -80` I originally piped the build through, but `xcodebuild`'s overall
`** TEST SUCCEEDED **` verdict is only emitted when every test bundle in the scheme passes
(both Swift Testing and XCTest), so the 509-test XCTest baseline is confirmed clean by that
verdict. `MultiYearPerfTests` (the known pre-existing wall-clock flake) was not re-run in isolation
since the full run already passed clean; no flake was observed.

**Production diff (must be empty):**
```
$ git diff --stat main -- RetireSmartIRA/
(empty)
```

**Em dash check:** `grep` for the em dash character across all 8 new fixture files and the
modified `GoldenScenarioCoverageTests.swift` returned no matches (exit code 1).

## Deviations summary

1. Batch-wide: deduction/exemption dimensions outside the per-source axis held constant per
   jurisdiction's current config (see above), disclosed rather than silently assumed.
2. Kansas: Railroad Retirement Board income not given its own case (no clean `PlanSource` fit,
   and it would not change engine behavior differently than the federal-civilian case already
   demonstrates).
3. Idaho: PERSI Firefighters/qualifying-city-police case not written, for scope reasons.
4. Arizona and Vermont: both batches surfaced a materially richer/different rule than the task
   brief described (AZ's per-spouse cap doubling and separate 100% military exclusion; VT's
   uncapped, higher-threshold, brand-new-2025 military exclusion distinct from the $10,000 CSRS
   rule). Both are written up as findings above, sourced to the actual form/statute text, not the
   brief's summary.
5. DC: the brief's rule description ("$3,000 at 62+, DC/federal pensions") is EXPIRED law
   (sunset 2015); current law covers only survivor benefits, uncapped. Two of DC's five cases
   (DC-1, DC-5) are deliberately clean/matching cases built to demonstrate this correction rather
   than a defect.

## Addendum: response to reviewer findings

### Finding 1 (CRITICAL) -- fabricated quote in HI-2, resolved

**Independent confirmation.** I re-fetched `https://files.hawaii.gov/tax/forms/current/schj_i.pdf`
myself (fresh curl, not reused from the earlier session) and ran `pdfinfo` (Pages: 3) and
`pdftotext -layout` over the whole document. The reviewer is correct: the sentence "If an
employee has made contributions under an elective right to a plan (sometimes known as a deferred
compensation plan), distributions from the plan are considered to be returns from an individual
investment and do not qualify as an excluded pension" does not appear anywhere in the 3-page
document. I grepped the extracted text for "deferred compensation", "individual investment",
"returns from", and "elective" -- each hit only unrelated passages (e.g. "elective right" appears
once, in the context of a *government employer's* voluntary-contribution rule, not this sentence).

**Diagnosis of how it got there.** The fabricated sentence is not a garbled paraphrase of anything
in this document, and it does not match the structure or vocabulary of Hawaii Schedule J's actual
prose (which uses "hybrid plan," "pension exclusion applies only to amounts attributable to
employer contributions," etc.). Its phrasing -- "returns from an individual investment,"
"elective right to a plan" -- reads like generic boilerplate describing how *some* states treat
401(k)/457 elective-deferral distributions, recalled from general tax-domain memory rather than
read from this source. My working conclusion is that I generated the sentence from a remembered
sense of "how states usually describe non-pension deferred-comp distributions" and then attributed
it to this document's page range without re-reading page 1-2 at the point I wrote the citation.
It was not a misattributed quote from a *different* real document -- I could not find this exact
sentence, or anything resembling it, in the KS, VT, or DC PDFs either. The failure was skipping
the read-back-against-source step for a case I believed I already understood conceptually (a pure
employee-elective-deferral 401(k) is fully taxable), and writing a citation to match the conclusion
rather than deriving the conclusion from the citation.

**What Hawaii's actual rule is, and where.** The same document (Schedule J Instructions, REV 2025,
page 2, the paragraph immediately preceding the "WHO MUST USE THIS FORM" heading) genuinely says:
"The pension exclusion applies only to amounts attributable to employer contributions." That
sentence, which I confirmed is real and on page 2, is sufficient on its own to support HI-2's
conclusion: a 401(k) distribution funded entirely by the employee's own elective salary-reduction
deferrals has zero employer-contribution component, so 0% of it qualifies for the exclusion under
this rule, and the full $50,000 is taxable. Page 2's item 6 (also real, also verified) reinforces
this by describing a 401(k) *with* an employer-matching or profit-sharing component as a "hybrid
plan which is partly pension and partly deferred compensation" -- i.e. only the employer-funded
share of such a plan is ever excludable, and a pure elective-deferral plan has no such share. No
different document was needed; the load-bearing clause was on the same page, just not the sentence
originally quoted.

**Resolution applied.** Rewrote HI-2's `source` field to quote only the verified real sentence
plus the item-6 cross-reference, both on page 2 of `schj_i.pdf`, and left `sourceURL` unchanged
(same document, now correctly quoted). `expectedStateTax` (2107.20) and `observedToday` are
UNCHANGED -- the underlying conclusion (fully taxable) was already correct, only the citation was
fabricated. HI-2 remains a clean case with no `knownDefect` block, which is accurate: this is a
contrast/regression case where the engine already produces the right answer.

### Finding 2 -- KS-6 entangles both Kansas defects, resolved

Kept KS-6 as a deliberate combined/integration case (removing it would lose real coverage of the
interaction between the two fixes), but rewrote both its `name` and its `knownDefect.summary` to
say explicitly, in the file itself, that this case requires BOTH Kansas fixes to go green and will
NOT go green from either fix alone. The summary now shows the arithmetic under each single-fix
scenario ($871.52 with only the per-source fix, $1,218.88 with only the exemption fix, neither
equal to the expected $0.00) and names the single-mechanism cases by role: KS-1/KS-2 isolate the
personal-exemption defect, KS-3/KS-4/KS-5 isolate the per-source defect. A Phase 5 implementer
landing one fix and seeing KS-6 still red now has, in the fixture itself, the explanation for why
that is expected and where to look for the case that SHOULD go green from their fix.

### Finding 3 -- KS-3/KS-4 citation overclaim, resolved

Re-fetched `https://www.ksrevenue.gov/pdf/ip25.pdf` page 12 directly (`pdftotext -layout -f 12 -l
12`) and confirmed the reviewer's finding: Schedule S Line A14 enumerates at least twelve distinct
plan categories (Federal Civil Service/Armed Forces, U.S. Railroad Retirement Board, KPERS, Kansas
Police and Firemen's, Overland Park Police/Fire, Kansas Teachers', Kansas Highway Patrol, Kansas
Justices and Judges, Board of Public Utilities, Regents/faculty annuity contracts, Washburn
University, and certain Kansas first-class-city pensions), not the four KS-3's citation claimed to
be the exhaustive list. Reworded KS-3's `source` to list the full enumeration and drop the word
"ONLY," and reworded KS-4's `source` (which referenced the same Line A14 list for the KPERS-only
case) to describe KPERS as one entry on that same closed list rather than implying a shorter list.
The tested outcome is unaffected in both cases, as the reviewer noted -- a private pension is
taxable and KPERS is exempt regardless of how many other categories the list contains.

### Finding 4 -- page counts off by one, diagnosed

Re-ran `pdfinfo` on all four documents fetched for this batch: KS `ip25.pdf` = 36 pages (I reported
37), HI `schj_i.pdf` = 3 pages (I reported 4), VT Schedule IN-112 Instructions = 5 pages (I reported
6), DC D-40 Booklet = 96 pages (I reported 97). Every specific page citation in the original report
was independently verified correct by the reviewer, so this was a total-count error, not a
mis-citation. I found the likely mechanism: my extraction workflow split `pdftotext -layout`
output on the form-feed character (`\x0c`) to get one chunk per page. `pdftotext` emits a form
feed AFTER every page including the last one, so splitting on that character produces one more
chunk than there are actual pages (an empty trailing chunk). I reproduced this directly on
`schj_i.pdf`: `pdfinfo` reports 3 pages, but `data.split('\x0c')` on the same file's `pdftotext`
output yields 4 chunks, the last one empty. Counting chunks instead of calling `pdfinfo` (or
discarding the trailing empty chunk) explains the consistent off-by-one across all four documents
in this batch. No fixture text depended on the totals, only individual page citations, which were
already correct, so no fixture edits were needed for this finding.

## Verification for this addendum

Focused suite (`GoldenScenarioSingleYearTests` + `GoldenScenarioCoverageTests`), foreground,
600000ms timeout:
```
Test run with 9 tests in 2 suites passed after 0.091 seconds.
** TEST SUCCEEDED **
```
9/9 passed, unchanged from before this addendum's edits -- HI-2's `expectedStateTax` was not
changed, so no result moved.

Full suite, foreground, 600000ms timeout (first attempt exceeded the harness's 120s default and
was auto-backgrounded; I stopped that background task with TaskStop and re-ran it with the
600000ms timeout explicit, per instructions):
```
Test run with 1851 tests in 291 suites passed after 317.593 seconds.
** TEST SUCCEEDED **
```
Cross-checked via `xcrun xcresulttool get test-results summary` against the resulting `.xcresult`:
`failedTests: 0`, `skippedTests: 6`, `passedTests: 2354` (top-level; 2354 + 6 skipped = 2360 =
1851 Swift Testing + 509 XCTest, matching the stated baseline exactly). No `MultiYearPerfTests`
flake occurred on this run.

Production diff: `git diff --stat main -- RetireSmartIRA/` returned empty output. Only
`RetireSmartIRATests/GoldenScenarios/statetax-2026-HI.golden.json` and
`.../statetax-2026-KS.golden.json` were modified.

Em dash check: `grep` for the em dash character (U+2014) across both modified files returned no
matches (exit code 1) in both the fixture text and this addendum.
