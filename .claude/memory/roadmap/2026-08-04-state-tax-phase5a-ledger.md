# State Tax Phase 5a: base-value corrections, and the two written promises -- SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-04-state-tax-phase5a-data-corrections.md
Spec: docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md
Phase 4 ledger (READ IT, it is the input to this phase):
  .claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md
Worktree: .worktrees/state-tax-phase5 (branch feature/state-tax-phase5), off main @ 2b4f4c1
Merged commit at close: 996104a

Read this file first if you are Phase 5b or anyone picking this program back up. It is the
durable record of what Phase 5a actually corrected, what it left standing and why, and exactly
how far the two promises made to tester Steve Nicolai got. Phase 4 measured; Phase 5a is the
first phase where numbers move.

## What Phase 5a was

Two amendments to the spec govern this phase, both recorded in
`.claude/memory/decisions/log.md` (2026-08-04): (1) base-value defects -- stale rates, brackets,
deductions, personal exemptions -- are corrected BEFORE the retirement-exemption tiers, because
they hit every filer in a state rather than only retirees; (2) Phase 4's golden scenarios, each
cited to a jurisdiction's own published form, stand in for the two-model confirmation protocol
this project otherwise uses, because no GPT-5 or Gemini tool was available in this environment
and a same-model subagent pass would not have satisfied it.

Six states were in scope: Kansas and Indiana (personal exemptions), Iowa (retirement exclusion
plus the Roth-conversion mechanism -- pulled forward specifically so both of Steve's written
promises would land in the same wave), and Georgia, New Mexico, Utah (stale rate/bracket/
deduction values that hit every filer). Tasks 1-3 ran sequentially in this worktree; Tasks 4-7
(New Mexico, Georgia, Utah, Indiana) ran in parallel worktrees (`p5-t4` through `p5-t7`) and
merged back with only one recurring, one-line conflict (`GoldenScenarioCoverageTests.covered`,
resolved to the union each time, same pattern as Phase 4's fan-out).

## THE PROPERTY THAT CHANGED IN THIS PHASE

Phases 1 through 4 each ended with `git diff main -- RetireSmartIRA/` EMPTY. That is over, on
purpose. What replaces the empty-diff guarantee is attribution and confinement: every moved
value is a checked-in movement-ledger record naming the golden case that authorizes it, and the
production diff stays confined to `Resources/StateTaxData/2026/` plus documentation. Any other
`.swift` file appearing in that diff would mean the scope boundary was crossed.

## Headline counts, verified independently in this task, not copied from prior reports

Ran the same parse the brief specified, against the merged branch:

```
defect cases remaining: 99 across 32 jurisdictions
baseline values moved: 75 across 4 jurisdictions
  GA 19, IA 18, NM 19, UT 19
```

Matches the brief's stated figures exactly: **118 defect cases at Phase 4 close, 99 now**, a net
reduction of 19 cases (14 deleted outright across IA/GA/IN, plus KS/NM/UT each losing some but
not all of their cases -- see per-state detail below). **75 attributed baseline movements**, zero
fabricated, all four states' counts matching each task's own report.

Full per-jurisdiction remaining-defect count, parsed directly from the shipped fixtures:
AL 3, AR 1, AZ 4, CO 1, CT 4, DC 3, DE 3, HI 3, ID 4, KS 3, KY 1, LA 3, MA 3, MD 3, ME 4, MI 2,
MN 5, MO 1, NC 3, NE 4, NM 2, OH 5, OK 1, OR 4, RI 2, SC 4, UT 4, VA 3, VT 6, WA 4, WI 3, WV 3.
Iowa, Georgia, and Indiana do not appear in this list because their case counts are zero.

## Every correction, with its authority

### Iowa -- fully corrected, 0 of 6 defect cases remain

File: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IA.json`, `retirementExemptions`
block only. Six fields changed, each cited to Iowa HF 2317 or Iowa DOR guidance:

| Field | Shipped | Corrected | Authority |
|---|---|---|---|
| `distributionMinAge` | 59 | 55 | Iowa DOR: "55 years of age or older on December 31 of the tax year" |
| `regularExemptionMinAge` | 0 | 55 | Same statutory age, gates the pension/IRA exemption levels |
| `pensionExemption` | `.none` | `.full` | HF 2317: defined benefit plans including IPERS qualify, no cap |
| `iraWithdrawalExemption` | `.none` | `.full` | HF 2317 names traditional IRAs (26 U.S.C. 408(a)) by name, no cap |
| `exemptionAttribution` | `household` | `perQualifyingSpouse` | Iowa DOR: a non-qualifying spouse's own retirement income is not eligible |
| `rothConversionExemption` | absent | `{minAge:55, withheldPortionRemainsTaxable:false}` | HF 2317 names "Roth conversion income" by name; see the open item below |

**A 60-year-old Iowan converting $200,000 now owes what Iowa actually charges instead of
roughly $7,600 of invented state tax** (the golden case's own before/after: $6,988.20 to
$0.00, taxable income floors at $0 because the exclusion exceeds the AGI base). All four Iowa
`knownDefect` blocks deleted; the two cases that carried none were already correct and remain
so. 18 baseline movements, all measured (never predicted) and attributed to one of three golden
cases by mechanism (distribution-age gate, pension/IRA exclusion, Roth-conversion exclusion).
Two IA scenarios did not move by design: `single 54 conversion 80k` (age 54 is below both new
age gates) and `zero income`.

### Kansas -- PARTIALLY corrected. 3 of 6 defect cases remain. This is the one that needs care.

File: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json`. Added a top-level
`personalExemption` object ($9,160 single / $18,320 MFJ, Kansas SB1, 2024 special session).
Deleted KS-1 (Steve Nicolai's exact reported scenario), KS-2 (single-filer analogue), KS-3 (the
private-pension contrast case, confirming the ONLY gap in these three was the personal
exemption). **Steve Nicolai's own $50,000 MFJ scenario now computes $1,218.88, matching the
Kansas Department of Revenue's published form to the cent, where it computed $2,171.52 before**
($50,000 - $8,240 standard deduction - $18,320 personal exemption = $23,440 taxable x 5.2%).

Three cases remain, and they are Kansas's SECOND, separate defect: KPERS, federal civilian,
military, and Railroad Retirement pensions are enumerated as fully exempt on Kansas Schedule S
Line A14, while private pensions stay taxable. `statetax-2026-KS.json` has no `perSourceExemptions`
entries at all, so the engine pools every pension source into ordinary taxable income
identically. **A Kansas filer holding a KPERS pension is still over-taxed today.** The three
remaining cases (KS-4, KS-5, KS-6) wait on the field this defect needs: `perSourceExemptions`
rules keyed on `PlanSource`/`PlanStructure`, the same per-source machinery Phase 4's Tier 2
states (MA, HI, AZ, NC, ID, VT, DC) also wait on. Dependents ($2,320/dependent under SB1) were
deliberately left unmodeled: `StatePersonalExemption` has no dependent-count field and a
codebase grep found no dependent-count input anywhere in the app, so folding a dependent amount
into the base figure would have invented a household composition and misstated the number for
the single/no-dependent filers who are this app's typical user. Recorded as
`personalExemptionScopingNote` in the golden fixture.

**For a Steve-facing email:** Kansas's personal-exemption defect is fixed to the cent. Kansas's
second, separate defect -- the per-source pension exemption -- is not fixed and a filer holding a
KPERS, federal, military, or Railroad Retirement pension will still see the app over-tax that
income. Do not describe Kansas as "fixed" without that second sentence attached.

### Indiana -- fully corrected, 0 of 4 defect cases remain

File: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IN.json`. Added
`personalExemption` ($1,000 single / $2,000 MFJ, IT-40 Booklet 2025 page 24 Schedule 3 line 1).
All four discrepancies matched `exemption x 0.0295` exactly ($29.50 single, $59.00 MFJ), the
diagnostic check that turned "Indiana is wrong" into a confirmed mechanism rather than a
coincidence. Same dependent-modeling scope decision as Kansas (per-dependent and the
income-gated senior addition left unmodeled, no input exists for either).

### Georgia -- fully corrected, 0 of 5 defect cases remain

File: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json`. Rate 5.39% to 4.99%
(HB 463, Economic Growth and Tax Relief Act of 2026, signed 2026-05-11, retroactive to
2026-01-01, confirmed against Georgia DOR's own "Important Tax Updates" page and the Governor's
signing announcement). Standard deduction $12,000/$24,000 to $15,000/$30,000, same authority.
Georgia's retirement-exclusion tiers ($35,000 age 62-64, $65,000 age 65+, MFJ doubling) were not
touched at all and were already correct; every one of Georgia's five defects was the stale rate
and deduction, not a retirement-exclusion error. All five `knownDefect` blocks deleted.

Three pre-existing `StateRetirementExemptionTests` cases needed updating, and the reason matters
for Phase 5b: each one's hand-picked input sat exactly on the new zero-crossing point the
corrected math produces, so the test would have passed regardless of whether Georgia's config
was right (`gaRetirementAgeIRAExceedsCap`, `gaAge64UsesEarlyTier35K`, `gaSharedCapBothIncomeTypes`,
all fixed with new inputs, comfortably clear of the boundary, comments citing HB 463's
arithmetic).

### New Mexico -- PARTIALLY corrected. 2 of 4 defect cases remain.

File: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NM.json`, `taxSystem.single` and
`taxSystem.married` bracket arrays. The engine was still running the pre-HB252 5-bracket
1.7%-5.9% schedule, deleted from law effective TY2025; replaced with the enacted 6-bracket
1.5%-5.9% schedule (HB252, Laws 2024, Chapter 67, signed 2024-03-06). This is the oldest defect
in the Phase 4 catalogue and it hits every New Mexico filer, not only retirees. Two of four
defect cases resolved outright (both isolate the bracket defect alone, with the age-65 exemption
either not yet in play or legitimately zero under real law at that income).

Two cases remain, and they wait on the SAME missing model field: **NM's age-65 PIT-ADJ
exemption, an income-graduated dollar exemption keyed to AGI bands, which `StateTaxConfig` has
no field to express.** The model's only exemption shapes are the flat
`personalExemption`/`pensionExemption`/`iraWithdrawalExemption`, none of which fit a table keyed
on AGI returning a per-qualifying-filer dollar amount. `observedToday` was remeasured on both
(48.45 to 42.75, and 87.55 to 77.25) rather than left stale.

One note worth carrying: the Task 4 brief said one NM case would not resolve; two did not. The
implementer trusted the measured `xcodebuild` classification over the brief's count -- the sixth
time in this program a subagent caught an error in the instructions it was given (see the
Method Findings section).

### Utah -- PARTIALLY corrected. 4 of 5 defect cases remain.

File: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-UT.json`, `taxSystem.rate` only:
0.0455 to 0.0445 (enrolled S.B. 60, 2026 General Session, amending 59-10-104(2)(b), retrospective
to 2026-01-01). Utah's prior rate predated even the 4.5% rate S.B. 60 itself cuts from -- Utah
was stale by two rate cuts, not one. Exactly one of five defect cases resolved: the single case
whose own fixture text establishes BOTH Utah credits (the Taxpayer Tax Credit and the Retirement
Credit) are legitimately zero at that income under real law, isolating the bare rate gap with
nothing else in play.

Four cases remain, and they wait on **any credit representation at all.** Utah's Taxpayer Tax
Credit (UCA 59-10-1018, income-scaled, applies to essentially every Utah filer) and its separate
Retirement Credit (UCA 59-10-1019, a fixed birth-year cutoff of 1952, not an age-65 gate) are
both entirely unmodeled; `StateTaxConfig` has no credit mechanism of any kind. All four
`observedToday` values were remeasured, not left stale, and two summaries were reworded to drop
the now-fixed rate-staleness claim -- a stale summary still blaming the rate would have misdirected
Phase 5b into re-fixing something already corrected.

## THE EXACT MODEL FIELD EACH PARTIAL CORRECTION WAITS ON

- **Kansas** waits on `perSourceExemptions` (per-source exemption rules keyed on
  `PlanSource`/`PlanStructure`), the same field the Phase 4 Tier 2 per-source wall states (MA,
  HI, AZ, NC, ID, VT, DC) wait on.
- **New Mexico** waits on an income-graduated, age-65-gated exemption keyed to AGI bands and
  filing status -- a shape none of `StateTaxConfig`'s existing exemption types express.
- **Utah** waits on any credit representation at all: an income-phased tax credit mechanism,
  which does not exist in the model in any form today.

## The two written promises, stated plainly

Both were made in writing to tester Steve Nicolai.

**Iowa is fully corrected.** A 60-year-old Iowan converting $200,000 now owes what Iowa actually
charges instead of roughly $7,600 of invented state tax. This promise is kept in full.

**Kansas is NOT fully corrected.** His own reported scenario is fixed to the cent: $2,171.52 to
$1,218.88. Kansas's second defect stands: KPERS, federal, military, and Railroad Retirement
pensions should be fully exempt while private pensions are taxable, and they are not. A Kansas
filer holding a KPERS pension is still over-taxed today. Do not tell Steve Kansas is fixed
without that qualification attached; a half-corrected Kansas described as "fixed" would be
exactly the failure this program has been trying to avoid all along.

## The open item that needs a human, not an engineer

Iowa's `rothConversionExemption.withheldPortionRemainsTaxable` is shipped as `false`, chosen by
analogy to Illinois and Mississippi (both ship `false` under exclusions with the same blanket
shape as Iowa's), not to Pennsylvania (which ships `true`, resting on a PA-specific cost-recovery
mechanism Iowa's statute gives no indication of). **No Iowa DOR guidance addresses the question
directly.** Both primary sources were checked directly: the Iowa DOR "Retirement Income Tax
Guidance" FAQ page (every withholding-related sentence concerns Iowa's own state withholding
obligation, not federal withholding during a conversion) and Iowa Admin. Code r.701-302.54 (the
Roth-conversion-specific rule, which states only that "any income realized from the rollover or
conversion... is taxable," subject to the exclusion, with no basis-recovery mechanism of the kind
Pennsylvania's rule rests on).

This is dollar-consequential, not academic. On the baseline scenario
`IA|single 62 conversion 100k with 22k withheld` ($160,000 income, $100,000 Roth conversion,
$22,000 withheld, age 62): under the shipped `false`, the exempt amount is the full $100,000,
taxable income $40,000, Iowa tax **$1,520.00**. Under `true`, the exempt amount is $100,000 minus
the $22,000 withheld ($78,000), taxable income $62,000, Iowa tax **$2,356.00**. An $836
difference. **This app has a Roth conversion withholding feature, so an Iowa user electing
withholding hits this exact path.** The `false` value is the better-reasoned choice under the
evidentiary gap and stands as shipped, but it rests on an analogy, not a citation. Recorded as an
open item: get Iowa DOR or a CPA to confirm the withheld-portion treatment before relying on the
Iowa withheld-conversion figures in anything more consequential than this app's own estimate. If
guidance surfaces `true`, Iowa's withheld-conversion figures move by roughly $836 on this
scenario's shape.

## The mechanism this phase built, and why Phase 5b must not weaken it

The frozen 1,020-value baseline (`statetax-behavior-baseline-2026.json`) stays frozen forever.
Every deliberate movement away from it is a checked-in record in
`statetax-behavior-movements-2026.json` naming the golden case that authorizes it. Two gates
enforce this, both built in Task 1 and proven to fail in both directions before any correction
was permitted: an unauthorized movement (config changed, no ledger entry) fails, and a lying
ledger (an entry whose `before` disagrees with the frozen file) fails.

The `goldenCase` field in each movement entry is machine-checked against the real golden
fixtures (`BaselineMovementLedgerTests`), not validated as merely non-empty. This closes a
specific failure mode: a typo or a plausible-sounding name for a golden case that was never
written would otherwise break the attribution chain silently while every test stayed green. A
probe run against a deliberately missing case name confirmed it fails.

**How a Phase 5b implementer adds to it:** correct the config field, run
`StateTaxBehaviorBaselineTests`, copy the `before`/`after` values verbatim out of the failure
messages (never hand-compute or predict them), append one entry per moved key to
`statetax-behavior-movements-2026.json` citing the golden case whose `source` field justifies the
movement's mechanism, and confirm `BaselineMovementLedgerTests` passes. Do not regenerate the
frozen baseline file itself; its own test file states regeneration is legitimate only when every
moved value is attributable this way, which is the property this mechanism exists to prove
holds. A guard was added this phase making wholesale regeneration (`STATE_TAX_BASELINE`-gated)
loud rather than silent, since one command with that variable set can destroy four phases of
evidence.

One structural fact any Phase 5b implementer needs before writing a movement entry: the frozen
baseline harness (`StateTaxBehaviorBaselineTests`) calls `calculateStateTax` directly and passes
`postExemptionDeduction` as a per-scenario **literal**, never reading `config.personalExemption`
itself. That computation happens one layer up, in `DataManager.swift`. This means any correction
that lives entirely inside `personalExemption` (Kansas's Task 2, Indiana's Task 7) is
**structurally invisible to this baseline gate** -- it will show zero movements, verified by
running the suite before and after, not because nothing changed but because this particular
26-scenario grid never exercises that field. This is not a gap to fix; it is why the golden
suite, not the baseline suite, is the real regression guard for personal-exemption corrections.

## The legacy-table decision and its residual risk

`configs2026Legacy` in `RetireSmartIRA/StateTaxData.swift` is a 1,651-line hardcoded Swift mirror
of all 51 states' configs, used only as a fallback when the bundled JSON fails to load. It is
now **frozen at pre-Phase-5 law**: not updated per correction (that would mean a double-edit for
every one of the six states this phase touched, and this project has already drifted a
hand-duplicated mirror five times on one branch elsewhere), and not deleted (deleting would turn
a bundling failure into an app crash for every user, worse than serving stale-but-plausible
numbers to the rare user who hits the fallback). The doc comment above the declaration in
`StateTaxData.swift` states this explicitly, added Task 2, comment-only.

Two equivalence lists exist in `StateTaxJSONEquivalenceTests.swift` and they assert different
things:

- **`phase5CorrectedJurisdictions`** (Layer B, `StateTaxJSONStructuralEquivalenceTests`): the
  full set of states this phase corrected -- Kansas, Iowa, Indiana, Georgia, New Mexico, Utah, 6
  states. For any state on this list, the structural-equivalence test flips from asserting the
  JSON-loaded config and the frozen legacy table byte-encode IDENTICALLY to asserting they
  byte-encode DIFFERENTLY. If a corrected jurisdiction's two configs ever match again -- meaning
  the correction was reverted from the JSON, or someone hand-edited the frozen legacy table to
  match -- the suite fails.
- **`layerAProvenDivergentJurisdictions`** (Layer A, `StateTaxJSONEquivalenceTests.jsonMatchesLegacy`,
  a fixed 10-scenario grid): a narrower, stronger claim -- at least one scenario in that specific
  grid actually computes a different tax number from the JSON config than from the legacy table.
  Only 4 states qualify: Iowa, Georgia, New Mexico, Utah.

**Kansas and Indiana are deliberately in the first list and NOT the second**, and the reason is
the same structural fact noted above: that fixed 10-scenario grid passes `postExemptionDeduction`
as a hardcoded literal per scenario and never reads `config.personalExemption`, so no personal-
exemption-only correction can ever move it. Asserting "at least one scenario diverges" for Kansas
or Indiana against that specific grid would fail them forever even in their fully correct state.
This was verified, not assumed: a probe reverting Kansas's `personalExemption` block entirely and
re-running the suite confirmed the Layer B assertion (the one Kansas IS on) catches the reversion
correctly, and a parallel probe for Iowa (reverting all of Iowa's Phase 5a fields at once, since a
single-field revert was shown not to move every grid scenario) confirmed the Layer A assertion
(the one Iowa IS on) also catches its own reversion.

**Why this distinction matters for the next state Phase 5b corrects:** append to
`phase5CorrectedJurisdictions` unconditionally, for every corrected state -- that assertion is
always true for a genuine correction. Append to `layerAProvenDivergentJurisdictions` only if the
specific field being corrected is one this fixed 10-scenario grid actually varies (income and
filing status only, no personal exemption, no per-source pension classification). Placing a
personal-exemption-only correction on the second list would create a test that can never pass in
the state's correct, fully-shipped configuration.

**Residual risk, stated in the doc comment and repeated here:** if the bundled JSON ever fails to
load for a user in Kansas, Iowa, Indiana, Georgia, New Mexico, or Utah, that user silently
receives the pre-correction tax rules for their state via the frozen legacy fallback, with no
error and no indication anything is stale.

## What Phase 5b inherits

Organized by the missing model field, because that is how the work actually decomposes rather
than by state:

- **Per-source exemptions** (`perSourceExemptions`, keyed on `PlanSource`/`PlanStructure`):
  Kansas's second defect (KPERS/federal/military/Railroad Retirement fully exempt, private
  taxable), plus the Phase 4 Tier 2 states this was always going to serve -- Massachusetts,
  Hawaii, Arizona, North Carolina, Idaho, Vermont, DC.
- **Credit representation** (no mechanism exists today): Nebraska's $171-per-exemption personal
  credit, Oregon's $256-per-exemption credit, Utah's Taxpayer Tax Credit and Retirement Credit
  (both), Ohio's retirement income credit and $50 senior citizen credit.
- **A bracket base amount**: Ohio's $332 TY2026 bracket base and its MAGI-banded personal
  exemption, on top of the credit gap above.
- **South Carolina's separate age-65 deduction**: no field in `RetirementIncomeExemptions` models
  the $15,000 age-65 deduction as distinct from the general retirement-income deduction.
- **Age-graduated income-band exemptions**: New Mexico's PIT-ADJ exemption is the immediate
  example (the remaining 2 NM cases); the same shape recurs nowhere else in the current
  catalogue but is worth naming as a class since it is a genuinely new exemption type, not a
  variant of an existing one.
- **Attribution and age gates** (per-individual doubling, regular-exemption minimum age):
  Oklahoma, Delaware, Louisiana, Arkansas, South Carolina, West Virginia -- the Tier 3 states
  Phase 4 catalogued. **Do not correct Oklahoma, Arkansas, or South Carolina's base values
  (standard deduction, top rate, bracket table) without re-deriving their golden expectations in
  the SAME change.** Their `expectedStateTax` values are computed against the app's currently
  CONFIGURED (wrong) brackets; fixing the brackets without re-deriving the expectations turns a
  meaningful pin into a meaningless one. Each carries its own "PHASE 5 WARNING" text in its
  fixture.
- **Model extensions required before satisfiability, not just before correction**: Vermont and
  DC both have internally unsatisfiable fixture sets under the current schema (Vermont's
  CSRS-vs-military distinction and DC's survivor-vs-own distinction both collide on the same
  `PlanSource`/`ClassifiedPensionSource` pair with no field to separate them), per Phase 4's own
  Bucket 4 findings. These need a schema decision before any correction attempt, not just a
  config edit.

## Method findings worth carrying, drawn from the controller ledger

**Seven separate occasions where a subagent caught an error in the brief it was given.** This is
why "verify before you comply" is now standing practice for this program, not a one-off caution.
Instances from this phase alone: (1) the Layer A probe instruction specifying a single-field
revert for Iowa, which the implementer found did not move the assertion and traced to the real
mechanism before accepting the brief's framing; (2) the Task 4 brief's claim that exactly one New
Mexico case would not resolve, when the measured result was two -- the implementer trusted the
`xcodebuild` classification over the stated count. Phase 4 contributed five more (the controller
ledger's own running count), including the Layer A blanket-skip design (Task 3's reviewer) and
the mootness claim on Iowa's withheld-portion question, corrected in place rather than only
appended once the reviewer's hand computation was independently verified.

**A Phase 4 fixture can be citation-clean and still not carry everything a corrector needs.** New
Mexico's married bracket table was quoted in the golden fixture for only its first bracket, not
the full schedule; the Task 4 implementer independently fetched the enrolled bill text
(HB0252TRS.pdf, page 16) to confirm the complete six-bracket table before writing it into the
config, rather than extrapolating from the partial quote. Expect this again: a fixture's `source`
field proves the cited fact is real, not that it is complete enough to correct from directly.

**Georgia's three pre-existing tests sat exactly on a zero-crossing.** `gaRetirementAgeIRAExceedsCap`,
`gaAge64UsesEarlyTier35K`, and `gaSharedCapBothIncomeTypes` all used hand-picked inputs that, by
coincidence, landed exactly on the boundary where the corrected math produces the same result as
the old, wrong math (an $80,000 input that zeroes out under both the old $12,000 deduction and
the new $15,000 deduction, for instance). All three passed before this phase's fix and would have
kept passing after it with no code change at all -- they were not exercising the discriminating
range. Fixed by moving each input comfortably clear of its zero-crossing, with the new boundary
math documented in the test's own comment. Worth a general lesson for Phase 5b: a test that
passes on both the buggy and the corrected value is not testing the thing it claims to test, and
this only surfaces when the correction itself is what reveals the coincidence.

## Full suite gate

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA -destination 'platform=macOS'
...
Test run with 1857 tests in 293 suites passed after 316.432 seconds.
** TEST SUCCEEDED **
```

`xcresulttool get test-results summary` on the produced `.xcresult`: `"result" : "Passed"`,
`"failedTests" : 0`, `"skippedTests" : 6` (pre-existing env-gated harness tests, same six every
prior phase reports), `"passedTests" : 2360` at the top level (1,857 Swift Testing + 509 XCTest =
2,366 total including the 6 skips). No `MultiYearPerfTests` failure occurred in this run, so
there was nothing to re-run in isolation; several individual task reports this phase did hit that
known pre-existing wall-clock flake (`persona2_mfjCouple35Years()`, a `<15s` budget test with no
state-tax dependency) and each confirmed it by isolated re-run at 15.0-15.3s, consistent with a
flake rather than a regression.

## Production diff confinement

```
git diff --stat main -- RetireSmartIRA/
 .../StateTaxData/2026/statetax-2026-GA.json         | 15 ++++++++-------
 .../StateTaxData/2026/statetax-2026-IA.json         | 14 +++++++++-----
 .../StateTaxData/2026/statetax-2026-IN.json         |  6 ++++++
 .../StateTaxData/2026/statetax-2026-KS.json         |  6 ++++++
 .../StateTaxData/2026/statetax-2026-NM.json         | 20 ++++++++++++++------
 .../StateTaxData/2026/statetax-2026-UT.json         |  2 +-
 RetireSmartIRA/StateTaxData.swift                   | 21 +++++++++++++++++++++
 7 files changed, 65 insertions(+), 19 deletions(-)
```

Six config JSONs under `Resources/StateTaxData/2026/`, plus `StateTaxData.swift`. The
`StateTaxData.swift` diff was read in full: all 21 added lines are `///` doc-comment lines above
the `configs2026Legacy` declaration, zero braces, zero code, zero data. **No Swift logic and no
data moved anywhere in this phase.** Every tax-value correction is confined to the six JSON
files.

## Em dash check

Grepped this ledger file for the em dash character (U+2014): none found.

## Commit

```
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5 add .claude/memory/roadmap/2026-08-04-state-tax-phase5a-ledger.md
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5 commit -m "docs(state-tax): Phase 5a ledger, Iowa fully fixed, Kansas partially"
```
