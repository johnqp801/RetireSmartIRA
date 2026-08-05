# State Tax Phase 4: golden scenarios for all 51 jurisdictions -- SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-04-state-tax-phase4-golden-scenarios.md
Spec: docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md
Worktree: .worktrees/state-tax-phase4 (branch feature/state-tax-phase4), off main @ 6097430
Predecessor ledgers: .claude/memory/roadmap/2026-08-03-state-tax-phase3a-ledger.md and
-phase3b-ledger.md. Read them for how the fixture schema and the per-source exemption
machinery got here.

Read this file first if you are Phase 5, Phase 6, or anyone picking this program back up.
It is the durable record of what Phase 4 actually found, not just what it built.

## What Phase 4 was

Phase 4 wrote a hand-derived golden tax case for every one of the 51 US tax jurisdictions
(50 states + DC), each `expectedStateTax` traced to that jurisdiction's own published form,
statute, or enrolled bill -- never to this app's own output. Where the engine disagrees with
the form, the fixture pins BOTH numbers: `expectedStateTax` (what the form says) and a
`knownDefect.observedToday` (what the engine actually computes, measured by running the
suite). The suite then asserts the engine matches `observedToday` and deliberately does NOT
match `expectedStateTax`, so a real, cited defect stays visible instead of silently tolerated,
and any drift in a known-defective state still fails a test.

**Phase 4 corrects no tax value.** Every number in `RetireSmartIRA/` is untouched. Phase 4 is
measurement; Phase 5 is correction.

## Baseline

Main repo baseline at branch point: main @ 6097430, 1,752 Swift Testing in 285 suites + 505
XCTest, 0 failures (Phase 3b's gate). The plan's own stated baseline for this branch was stale
(cited the Phase 3b figure); Task 1 found and corrected it: true baseline on
`feature/state-tax-phase4` before any Phase 4 work was **1,845 Swift Testing in 290 suites +
509 XCTest**, accounting for five RMD spouse-attribution test files (1,835 insertions) merged
to main between the two branch points. Do not cite the Phase 3b number as this branch's
baseline; do not cite this branch's PRE-work number as post-Phase-4 baseline either -- see
below.

## Tasks 1-2: shape invariants and the defect-pin mechanism

Task 1 (edfcccc..32ba080): built the `KnownDefect` type and the `classify(actual:scenario:)`
five-case comparison (`matches`, `pinnedDefectMoved`, `defectAppearsFixed`,
`unexplainedDisagreement`, plus the base match/mismatch pair) that every fixture is graded
against. Reviewer found the original mechanism test exercised Codable, not the classification
logic itself; fixed by hoisting `classify` to a pure function and pinning it directly.

Task 2 (26135cf..57e902a): added `GoldenScenarioCoverageTests`'s shape invariants
(`federalAGIIsInternallyConsistent`, `noDoubleCountedPension`, `citationsAreWellFormed`).
Reviewer found a real loophole: a fixture with `classifiedPensionSources` present-but-EMPTY
plus a nonzero `pensionIncome` defeated both new checks at once, silently dropping the pension
from the AGI component sum. Fixed by keying the guard on presence, not non-emptiness, with a
regression test proven to discriminate.

Suite after Task 2: 1,850 Swift Testing in 291 suites + 509 XCTest, 0 failures, 6 skipped
(pre-existing env-gated harness tests). This is the number every later batch report cites as
"the branch baseline" -- it is the baseline AFTER the harness itself was hardened, not the
pre-work number two paragraphs up.

## Tasks 3-4: proving the harness scales, and the finding that reshaped the phase

Task 3 (d9445c8, fix 683b675): 8 no-income-tax/no-general-income-tax jurisdictions (AK, FL,
NV, SD, TN, TX, WY, NH), 32 scenarios, all $0, no `knownDefect` needed anywhere. Reviewer
caught Wyoming's citation naming the wrong slide of the right PDF (Slide 4 for text on Slide
5) -- the first instance of a citation-location defect class that recurred five more times
across the phase.

Task 4 (74e08bf, fix pass on top): CA, NE, ND, IN, OR -- the five states the audit called "no
retirement exclusion, correct." All five ARE correct on that one dimension. **The finding that
reshaped the phase: NE, IN, and OR carry 12 `knownDefect`s between them, none of them
retirement-exclusion errors.** NE's stale standard deduction and missing $171 personal-exemption
credit, IN's missing $1,000/$2,000 personal exemption (every discrepancy exactly
`exemption x 0.0295`), OR's stale standard deduction, miscalibrated lower brackets, and missing
$256 exemption credit. "Confirmed correct" in the audit turned out to mean confirmed correct
on the ONE dimension the audit checked. This is what told the controller to expect the final
catalogue to run well past the audit's predicted ~29.

Also at Task 4: a CRITICAL pre-fan-out finding. The test harness's `.conformsToFederal`
standard-deduction branch had been hardcoded to $0 (no pilot state had ever exercised it).
North Dakota forced it live, and the fix generalizes to the age-65 addition and the OBBBA
senior bonus, both pure functions of fixture fields already in scope -- an earlier claim that
they "depend on a live DataManager instance" was false and would have poisoned all four
downstream batches for any 65+ case in a `.conformsToFederal` state (nine states use it:
AZ, CO, ID, IA, MO, MT, ND, NM, SC). Fixed and proven inert across all 18 pre-existing
fixtures, and proven to discriminate.

## Tasks 5-9: parallel fan-out (b5-b9), five worktrees off 11430ca

Dispatched simultaneously per John's direction, each batch disjoint on fixtures, each with its
own citation-verifying review:

- **b5** (18c1997, fix 7786717): CO, KY, GA, MO -- "exclusion present, confirmed correct" states.
- **b6** (194b921, fix 9a296a9): IA, MI, CT, VA, WI, AL, RI, ME, MD -- Tier 1 wrong-value states.
- **b7** (062b861, fix 3afd4bb): KS, MA, HI, AZ, NC, ID, VT, DC -- the per-source wall.
- **b8** (4addccb, fix 6d38e9a): OK, DE, LA, AR, SC, WV -- attribution and age-gate states.
- **b9** (f794548, fix 35a95f8): OH, UT, NM, WA, MN -- Tier 4 credit states plus WA and the
  never-audited MN.

Merged in that order into `feature/state-tax-phase4` (14aabe1, 7e6e2e0, ab046f4, d4c560c). The
only conflict across all four merges was `GoldenScenarioCoverageTests.covered`, one line each
time, resolved to the union. Post-merge: **50 fixture files, 1,851 Swift Testing in 291 suites,
TEST SUCCEEDED** -- the assertion no individual batch could make on its own, since each only
ever proved its own states alongside the ones that predated it.

Per-batch findings are extensive; the full detail lives in each batch's own report
(`.worktrees/phase4-b{5..9}/.superpowers/sdd/task-{5..9}-report.md`, gitignored, worktree-local)
and in `.worktrees/state-tax-phase4/.superpowers/sdd/progress.md`. This ledger's catalogue and
comparison sections below are built directly from those reports plus the shipped fixtures --
this section is a map to them, not a replacement.

## Task 10: close the phase

This is the task this ledger documents in full. Three deliverables:

1. Flip the completeness gate from a hand-grown `covered` literal to a full `USState.allCases`
   sweep, WITH an explicit, reviewed, tested exclusion for Montana.
2. Build the defect catalogue as an executable test suite -- Phase 5's actual input.
3. Compare the catalogue against the audit that started the whole program, rigorously, because
   that comparison is where a single-source memo either holds up or gets falsified.

### Step 1: completeness, with Montana handled correctly

The brief's literal instruction (`covered = USState.allCases.map(\.abbreviation)`, no
exclusion) fails on Montana. Montana's absence is not an oversight: the b6 batch confirmed
Montana's mechanism directly from Montana DOR's Form 2 2025 Instructions (page 6, opened
directly) -- the old income-gated `.partial(4_640)` deduction was repealed effective TY2025 and
replaced with a flat age-65 subtraction -- but the exact TY2026 INDEXED dollar figure for that
subtraction has not been published. A reviewer independently examined the call to exclude
Montana rather than guess or interpolate, and agreed with it.

Weakening the completeness test to quietly pass with Montana missing would have hidden exactly
the failure mode this phase exists to prevent: a jurisdiction with no fixture read as "assumed
correct" instead of "unverified." The fix instead makes the exclusion **data**, not a comment,
because spec 3.5's Phase 6 disclosure UI has to render this exact distinction and needs
something to read other than a code comment:

```swift
struct UnverifiedJurisdiction {
    let abbreviation: String
    let reason: String
}
static let cannotVerify: [UnverifiedJurisdiction] = [
    UnverifiedJurisdiction(abbreviation: "MT", reason: "...")
]
```

`covered` is now derived (`USState.allCases` minus `cannotVerify`), not hand-listed.
`GoldenScenarioCoverageTests.everyJurisdictionHasAFixture` sweeps ALL 51 jurisdictions and
fails if any jurisdiction outside `cannotVerify` has no fixture -- so a jurisdiction silently
falling out of `covered` later, or a future batch that forgets a state, still fails a test. A
second test, `cannotVerifyListIsExactlyWhatPhase4Shipped`, pins the exclusion list's membership
to exactly `["MT"]`, so `everyJurisdictionHasAFixture` cannot be made to pass by quietly
growing the exclusion list instead of writing the missing fixture. Both tests are new;
`fixtureLoads` and the other `covered`-parameterized tests are unchanged in shape, just now
iterating the derived list.

Files: `RetireSmartIRATests/GoldenScenarioCoverageTests.swift`, modified.

### Step 3: the defect catalogue, as an executable suite

New file: `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift`, built per the brief
verbatim (the `Entry` struct, `catalogue()`, `catalogueIsWellFormed`, `printCatalogue`), plus
one addition the brief did not anticipate: a second, parallel data structure for a real defect
that has NO golden case to be read from.

**Missouri's public-pension cap is a confirmed, real defect with no pinned fixture.** The b5
batch verified the mechanism directly (MO-A 2025 Part 3 Section A: the public-pension
exemption is capped at the lesser of the pension received or each individual's own maximum
Social Security benefit, reduced by any Social Security deduction the same person claims) and
hand-derived a case that would have pinned it (MFJ, $150,000/$120,000 public pensions: correct
tax $6,157.41 against the engine's `.full`-exemption $0.00). It then could not source the one
number `expectedStateTax` needed -- the 2026 maximum Social Security benefit -- from any
official channel, and DELETED the scenario rather than ship it on a secondary source (a CNBC
article). `catalogue()` can only ever see what a fixture carries, so this defect would
otherwise be invisible to Phase 5 entirely: real, measured to be wrong, cited for its
mechanism, and yet absent from the one artifact Phase 5 is told to consume. That is precisely
the "Phase 5 may never act on it" failure this whole exercise exists to prevent.

The fix: a second static list, `GoldenScenarioDefectCatalogueTests.knownButUnpinned`, carrying
the mechanism AND a concrete, checkable blocker (not "give up" -- a specific list of sources
tried and exhausted), with its own well-formedness test
(`knownButUnpinnedIsWellFormed`). This is DATA for the same reason `cannotVerify` is: it has to
survive independent of any one report, and a future reader (Phase 5, or whoever revisits
Missouri) needs the blocker stated precisely enough to know when it clears.

### Step 2 and Step 4: run and capture

Focused run (`GoldenScenarioCoverageTests` + `GoldenScenarioDefectCatalogueTests`):

```
✔ Test "Every covered jurisdiction has a bundled, decodable fixture" with 50 test cases passed.
✔ Test "Every one of the 51 jurisdictions has a fixture or a documented CANNOT_VERIFY reason" passed.
✔ Test "The CANNOT_VERIFY exclusion list is exactly what Phase 4 shipped, not silently grown" passed.
✔ Test "federalAGI equals the sum of its components" with 50 test cases passed.
✔ Test "Every fixture carries a source and an https sourceURL" with 50 test cases passed.
✔ Test "Fixtures never set both pensionIncome and classifiedPensionSources" with 50 test cases passed.
✔ Test "Empty classifiedPensionSources still requires pensionIncome == 0" passed.
✔ Test "The catalogue is non-empty and every entry is well formed" passed.
✔ Test "Print the catalogue, grouped by tier" passed.
✔ Test "Every known-but-unpinned defect names both a real mechanism and a concrete blocker" passed.
✔ Test run with 10 tests in 2 suites passed after 0.166 seconds.
** TEST SUCCEEDED **
```

## THE DEFECT CATALOGUE (Phase 5's input)

Most lines below are verbatim `printCatalogue` output; some are abridged paraphrases of the
fixture's own `knownDefect.summary`, spot-checked as faithful but not a byte-for-byte transcript.
Read `printCatalogue`'s own test output, not this block, when exact wording matters.

```
PHASE 4 DEFECT CATALOGUE: 118 cases across 35 jurisdictions

TIER1, 34 cases, 11 jurisdictions
  AL  OVERTAXES by $300.00, Alabama's perSourceExemptions is empty, so classifiedPensionSources rows fall through to the flat pensionExemption (.none) regardless of planStructure, missing the $6,000-per-person age-65 defined-contribution exclusion (Schedule RS Line 10); this UNDERSTATES the exemption for defined-contribution/IRA income.
  AL  OVERTAXES by $2310.00, Alabama's perSourceExemptions is empty, so a fully-exempt defined-benefit pension (Ala. Admin. Code 810-3-19-.04, unconditional, no age gate, no cap) is pooled into the flat pensionExemption (.none) and taxed as ordinary income in full; this is the clearest single instance of the structure-blindness defect in this batch.
  AL  OVERTAXES by $1735.00, Same structure-blindness defect at the MFJ scale, compounded across a mixed DB+DC household: the engine's flat pensionExemption (.none) excludes nothing from either the fully-exempt defined-benefit pension or the capped defined-contribution distribution.
  CT  UNDERTAXES by $5950.00, Connecticut's iraWithdrawalExemption is .full with no agiPhaseout configured, so the engine excludes an IRA withdrawal in full even when federal AGI is above CT's $100,000 single cliff, where real law fully phases the subtraction to zero; this overstates the exemption.
  CT  UNDERTAXES by $9500.00, Same missing-agiPhaseout defect as the single-filer case, at the MFJ scale: the engine excludes the full $200,000 IRA withdrawal though real law fully phases the subtraction to zero above $150,000 combined AGI; this OVERSTATES the exemption, the same direction as the single-filer case above.
  CT  UNDERTAXES by $2200.00, Connecticut's iraWithdrawalExemption is .full with no agiPhaseout, so a same-year Roth conversion that lifts total AGI past the phase-out cliff still leaves the engine excluding the IRA withdrawal in full, overstating the exemption exactly when the conversion is what destroys it under real law.
  CT  OVERTAXES by $1550.00, Connecticut's pensionExemption is .none unconditionally, so the engine taxes pension income in full even for a filer well under the $75,000 AGI threshold where real law exempts it entirely; this UNDERSTATES the exemption, the opposite direction from the IRA-side defect in this same batch.
  GA  OVERTAXES by $181.70, RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json's config still carries the pre-HB463 rate (0.0539) and fixed standard deduction ($12,000/$24,000); Georgia's Economic Growth and Tax Relief Act of 2026 cut the rate to 4.99% and raised the standard deduction to $15,000/$30,000 retroactive to January 1, 2026, confirmed on Georgia DOR's own 'Important Tax Updates' page. The retirement-exclusion age/dollar mechanics the 2026-08-02 audit checked are unaffected and correct in every case in this file; only the rate and the deduction are stale.
  GA  OVERTAXES by $201.70, Same stale rate/deduction mechanism as the first scenario in this file (RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json's config still carries 0.0539 and the $12,000 single standard deduction). The 62-64 age-tier $35,000 exclusion cap this case exercises for the first time in this file is applied correctly; only the rate and the deduction are stale.
  GA  OVERTAXES by $241.70, Same stale rate/deduction mechanism as the first scenario in this file; the $65,000 age-65+ exclusion cap and its correct application to this single filer are unaffected.
  GA  OVERTAXES by $483.40, Same stale rate/deduction mechanism as the first scenario in this file. The per-individual doubling this case exercises (exemptionAppliesPerIndividual, pensionAndIRAShareSingleCap) is correctly configured and produces the right $130,000 combined cap -- unlike Colorado and Kentucky in this same batch, Georgia's MFJ attribution is not broken.
  GA  OVERTAXES by $423.40, Same stale rate/deduction mechanism as the first scenario in this file; the single-qualifying-spouse exclusion mechanic is correctly configured and unaffected.
  IA  OVERTAXES by $1478.20, Iowa's config carries no retirement-income exclusion at all (pensionExemption and iraWithdrawalExemption both .none), so the engine taxes a qualifying 60-year-old's full IRA withdrawal as ordinary income instead of excluding it entirely under HF 2317.
  IA  OVERTAXES by $1436.40, Same missing-exclusion defect as the single case: Iowa's config has no pension exclusion at any age, so a fully-qualifying MFJ couple's pension income is taxed in full instead of excluded entirely.
  IA  OVERTAXES by $6988.20, Iowa's config has no rothConversionExemption set at all, so the engine treats a Roth conversion -- named explicitly as qualifying by Iowa DOR guidance -- as fully taxable ordinary income, inventing state tax on the specific transaction the product exists to recommend.
  IA  OVERTAXES by $1098.20, Same missing-exclusion defect as the other Iowa cases (pensionExemption/iraWithdrawalExemption both .none today), pinned separately at age 56 so Phase 5's fix is checked against the engine's hardcoded distributionMinAge=59 gate, not just against the exclusion's existence.
  MD  UNDERTAXES by $1213.38, Maryland's config sets no regularExemptionMinAge, so the pension exclusion applies unconditionally to a 50-year-old (the worksheet requires age 65+ or disabled); this OVERSTATES the exemption.
  MD  UNDERTAXES by $976.38, Maryland's pension exclusion has no mechanism reducing it by Social Security received (worksheet 13A Line 3-4), so the engine excludes the full $25,000 pension even though Social Security received ($50,000) exceeds either candidate TY2026 cap and real law's Line 4 floors the tentative exclusion at $0; this OVERSTATES the exemption.
  MD  UNDERTAXES by $959.25, Maryland's config sets no regularExemptionMinAge and has no per-spouse income attribution, so the pension exclusion is granted against the non-qualifying primary's own income simply because the spouse is 65+; this OVERSTATES the exemption.
  ME  UNDERTAXES by $272.60, Maine's config sets no regularExemptionMinAge, so the pension income deduction applies unconditionally to a distribution received before age 55 (which 36 M.R.S. 5122(2)(M-2) excludes unless paid as substantially equal periodic payments); this OVERSTATES the exemption.
  ME  OVERTAXES by $272.60, Maine's pensionExemption caps at $25,000, well under the real $48,216-per-person figure (36 M.R.S. 5122(2)(M-2), Form 1040ME instructions page 6); this UNDERSTATES the exemption for a qualifying filer with income between the two figures.
  ME  OVERTAXES by $1346.53, Same wrong-dollar-figure defect at the MFJ scale: Maine's config caps the pension deduction at $25,000 against a real $48,216 per-spouse figure, and never doubles the cap for a jointly-filing couple; this UNDERSTATES the exemption.
  ME  UNDERTAXES by $1125.20, Maine's config sets no regularExemptionMinAge and has no per-spouse income attribution, so the $25,000 pension deduction is granted against the non-qualifying primary's own pre-age-55 income simply because the spouse is 65+; this OVERSTATES the exemption.
  MI  UNDERTAXES by $3574.38, Michigan's pensionExemption is .full with no dollar cap, so the engine excludes an unlimited retirement-income amount when real law (RAB 2026-1) caps the TY2026 phase-in at the inflation-adjusted private retirement maximum (at least $65,897 single); this overstates the exemption for any filer above the cap.
  MI  UNDERTAXES by $5023.76, Same as the single-filer defect: Michigan's iraWithdrawalExemption is .full with no dollar cap, so a couple's IRA withdrawals well above the real (at least $131,794) joint cap are excluded in their entirety, overstating the exemption.
  MO  UNDERTAXES by $1412.67, RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-MO.json's config sets iraWithdrawalExemption to .full (unconditional), but Form MO-A Section B caps private pension/IRA/401(k) income at $6,000 per taxpayer, phased out dollar-for-dollar above $25,000 single / $32,000 MFJ Missouri AGI. This is not the public-pension cap the 2026-08-02 audit already flagged; it is a separate, unaudited gap that is directly on-point for this app's core IRA-withdrawal/Roth-conversion use case, and is expressible with the existing .partial(maxExempt:) + AGIPhaseout(.linear(perDollar: 1.0)) machinery already used elsewhere in this codebase.
  RI  OVERTAXES by $1080.00, Rhode Island's config has no retirement-income exclusion at all, so the engine misses the entire $50,000-per-person Pension and Annuity Income Modification for a qualifying filer at full retirement age; this UNDERSTATES the exemption (a missing gate, not an overstatement).
  RI  OVERTAXES by $2535.00, Same missing-exclusion defect at the MFJ scale: Rhode Island's config has no retirement-income exclusion at all, so a couple both at full retirement age gets none of the up-to-$100,000 combined modification it is entitled to.
  VA  UNDERTAXES by $631.88, Virginia's config sets no regularExemptionMinAge, so the $12,000 age deduction (Va. Code 58.1-322.03(5)(b), which requires age 65+) applies unconditionally to a 50-year-old's pension income; this OVERSTATES the exemption for any filer below 65.
  VA  OVERTAXES by $690.00, Virginia's exemptionAppliesPerIndividual is not set, so the engine never doubles the $12,000 age-deduction cap for an MFJ couple where both spouses independently qualify (Va. 760 Instructions worksheet Line 12 requires $12,000 PER qualifying spouse); this UNDERSTATES the exemption, unlike the other Virginia defects in this batch which overstate it.
  VA  UNDERTAXES by $690.00, Virginia's config has no agiPhaseout, so a Roth conversion that lifts AFAGI $20,000 past the $50,000 threshold -- more than the $12,000 cap, which zeroes the deduction entirely per the worksheet's Line 13 cliff -- still leaves the engine granting the full $12,000 age deduction; this OVERSTATES the exemption exactly when the conversion is what destroys it.
  WI  OVERTAXES by $1056.00, Wisconsin's config has no retirement-income exclusion at all, so the engine misses the entire 2025 Act 15 $24,000-per-person exclusion for a qualifying 67+ filer; this UNDERSTATES the exemption (a missing gate, not an overstatement, unlike Michigan/Connecticut/Virginia in this batch).
  WI  OVERTAXES by $2141.15, Same missing-exclusion defect at the MFJ scale: Wisconsin's config has no retirement-income exclusion at all, so the engine misses the entire $48,000 both-spouses-67+ exclusion.
  WI  OVERTAXES by $1056.00, Same missing-exclusion defect: Wisconsin's config has no retirement-income exclusion at all, so even a household where the spouse alone clears the age-67 gate gets none of the $24,000 exclusion it is entitled to.

TIER2, 32 cases, 8 jurisdictions
  AZ  UNDERTAXES by $50.00, AZ's $2,500 exclusion (Line 29a) is government-pensions-only, but statetax-2026-AZ.json applies pensionExemption.partial(2500) with no perSourceExemptions gate, so the engine wrongly grants the exclusion to this private pension, understating tax by exactly $2,000 x 2.5% = $50.00.
  AZ  OVERTAXES by $333.75, This app's PlanSource enum has no case for U.S. uniformed-services retired pay distinct from federal civilian service (used here as the closest available label, disclosed as an imprecise fit); even set aside, statetax-2026-AZ.json models only Line 29a's $2,500 cap and has no Line 29b 100%-exclusion mechanism at all, so the engine excludes at most $2,500 of this fully-exempt $40,000 military pension, overstating tax in the OPPOSITE direction from the private-pension case above. PHASE 5 WARNING: every other federalCivilian amount in this file (AZ-1, AZ-4, AZ-5) is $2,000, under the real $2,500 civilian cap, so an uncapped-federalCivilian rule fixing this case would leave those three cases green while being wrong for any federal civilian retiree whose pension exceeds $2,500. A green AZ suite does NOT mean Arizona's per-source caps are correct.
  AZ  OVERTAXES by $37.50, AZ Form 140 grants each spouse an independent $2,500 cap on Line 29a, but statetax-2026-AZ.json sets exemptionAppliesPerIndividual to false, so the engine pools both spouses' government pensions under one shared $2,500 household cap instead of doubling it, overstating tax by $1,500 x 2.5% = $37.50.
  AZ  UNDERTAXES by $12.50, Only the government-pension spouse's $2,000 should be excluded; the engine pools both spouses' pensions ($4,000 total, government and private alike) under one $2,500 household cap regardless of source, granting $500 more exclusion than the government portion alone justifies and understating tax by $12.50 relative to the correct figure -- a smaller, opposite-signed error from combining the per-source miss (case 2) and the non-doubling miss (case 4).
  DC  OVERTAXES by $1924.00, DC/federal government survivor benefits are fully excluded at age 62+ with no cap (D.C. Code 47-1803.02(a)(2)(N)(ii)); statetax-2026-DC.json has no perSourceExemptions, so the engine taxes the full $50,000.
  DC  OVERTAXES by $1546.00, Both spouses' DC/federal survivor benefits should be fully excluded; the engine has no perSourceExemptions for DC, taxing the full $55,000 household income. CANNOT_VERIFY: this file's DC-3/DC-4 (survivor benefit) require full exemption for (planSource: federalCivilian, planStructure: definedBenefit), while DC-5 (own pension, same pair) requires that pair fully taxable; both parties are 62 or older in every case, so age cannot separate them. This file cannot be fully satisfied by any StateTaxData configuration until ClassifiedPensionSource gains a survivor-versus-own flag.
  DC  OVERTAXES by $2002.50, Only the survivor spouse's $30,000 should be excluded; the engine excludes nothing (no perSourceExemptions for DC), taxing the full $90,000 household income. CANNOT_VERIFY: this file's DC-3/DC-4 (survivor benefit) require full exemption for (planSource: federalCivilian, planStructure: definedBenefit), while DC-5 (own pension, same pair) requires that pair fully taxable; both parties are 62 or older in every case, so age cannot separate them. This file cannot be fully satisfied by any StateTaxData configuration until ClassifiedPensionSource gains a survivor-versus-own flag.
  HI  OVERTAXES by $2107.20, Hawaii's pension exclusion turns on whether the EMPLOYEE contributed, not on employer type; statetax-2026-HI.json has no perSourceExemptions (Phase 3b scoped Hawaii as disclosed-not-modelled), so the engine taxes this fully employer-funded pension at HI's 12-bracket schedule as if it were ordinary income.
  HI  OVERTAXES by $2466.40, Both spouses' noncontributory pensions should be fully excluded; the engine has no perSourceExemptions for HI, taxing the full $75,000 household income.
  HI  OVERTAXES by $2200.40, The noncontributory-pension spouse's income should be excluded while the 401(k)-deferral spouse's distribution stays taxable; the engine excludes neither (no perSourceExemptions for HI), taxing the full $75,000 -- the identical figure the fully-exempt MFJ case above produces, because the engine is blind to the funding-source distinction entirely.
  ID  OVERTAXES by $840.05, CSRS retirement annuities qualify for Idaho's Retirement Benefits Deduction (Form 39R Line 8) once the recipient is 65+; statetax-2026-ID.json has no perSourceExemptions and pensionExemption is 'none', so the engine grants no deduction at all.
  ID  OVERTAXES by $1266.70, Retired service members qualify for Idaho's Retirement Benefits Deduction at age 62 (not 65) per Form 39R Line 8e, a distinct gate from Part One's general rule; the engine has no age-tiered or per-source retirement deduction of any kind for ID, granting nothing. PHASE 5 WARNING: this file's only under-62 case is ID-1 (age 60), so a single age-62 gate applied to (federalCivilian, definedBenefit) would turn all five ID cases in this file green while encoding 62 as the CSRS civilian gate too, when the real CSRS gate is 65 (ID-2's own citation, Form 39R Part One). A green ID suite does NOT mean Idaho's age gates are correct.
  ID  OVERTAXES by $1722.50, Both spouses' CSRS pensions qualify for the MFJ Retirement Benefits Deduction (capped at $72,324); the engine grants nothing, taxing the full $80,000 household income.
  ID  OVERTAXES by $1597.95, Only the CSRS spouse's pension should be deductible; the engine grants no retirement deduction at all for ID, taxing the full $70,000 household income.
  KS  OVERTAXES by $952.64, Kansas SB1 (2024 special session) personal exemption ($18,320 MFJ / $9,160 single / $2,320 per dependent) has no StatePersonalExemption entry in statetax-2026-KS.json, so postExemptionDeduction is 0 and the engine taxes the full standard-deduction-only base.
  KS  OVERTAXES by $489.22, Same mechanism as Steve Nicolai's case: no personal exemption modeled for Kansas, so the engine over-taxes every Kansas filer by the exemption amount times the marginal rate.
  KS  OVERTAXES by $511.13, Private pension correctly receives no per-source exclusion under KS law, and the app also grants it none (no perSourceExemptions configured for KS at all), so this case's whole gap versus the app is the personal-exemption defect above, not a per-source miss. Kept as the same-income contrast for the KPERS case below.
  KS  OVERTAXES by $1943.44, KPERS is enumerated as fully exempt on Schedule S Line A14, but statetax-2026-KS.json has no perSourceExemptions entries at all, so the engine pools this pension into ordinary taxable income exactly as it would a private pension.
  KS  OVERTAXES by $2171.52, Both KPERS and federal-civilian pensions are enumerated as fully exempt on Schedule S Line A14; the engine's empty perSourceExemptions for KS excludes neither, taxing the full $50,000 household income exactly as it would ordinary wages.
  KS  OVERTAXES by $2171.52, COMBINED CASE: this scenario entangles BOTH Kansas defects and will not go green until both fixes land. With ONLY the per-source fix applied: $871.52. With ONLY the personal-exemption fix applied: $1,218.88. Neither equals the expected $0.00. KS-1/KS-2 isolate the personal-exemption defect; KS-3/KS-4/KS-5 isolate the per-source defect; this case is a deliberate integration check, not a substitute.
  MA  OVERTAXES by $3000.00, MA state/local contributory pensions are fully excluded from MA gross income; statetax-2026-MA.json has no perSourceExemptions, so the engine pools it into ordinary taxable income and taxes it at the flat 5% rate.
  MA  OVERTAXES by $3750.00, Both spouses' MA contributory pensions should be fully excluded; the engine's empty perSourceExemptions for MA excludes neither, taxing the full $75,000 household income at 5%.
  MA  OVERTAXES by $1500.00, The military spouse's pension should be fully excluded while the private 401(k) spouse's distribution stays taxable; the engine excludes neither (no perSourceExemptions for MA), taxing the full $60,000.
  NC  OVERTAXES by $1486.27, Bailey-vested NC state/local/federal government pensions are fully exempt from NC tax; statetax-2026-NC.json has no perSourceExemptions (and the model has no vesting-date field to express Bailey status at all -- see the CANNOT_VERIFY discussion below), so the engine taxes it in full.
  NC  OVERTAXES by $1975.05, Both spouses' Bailey-vested pensions should be fully excluded; the engine has no perSourceExemptions for NC, taxing the full $75,000 household income.
  NC  OVERTAXES by $1596.00, The Bailey-vested spouse's pension should be excluded while the private-pension spouse's income stays taxable; the engine excludes neither (no perSourceExemptions for NC), taxing the full $75,000 -- the identical figure the fully-exempt MFJ case above produces.
  VT  OVERTAXES by $335.00, CSRS income up to $10,000 qualifies for VT's Retirement Income Exemption when AGI is under $55,000/$70,000; statetax-2026-VT.json has no perSourceExemptions and pensionExemption is 'none', so the engine grants no exclusion. CANNOT_VERIFY: this file's VT-1 (CSRS, capped at $10,000) and VT-5 (military, uncapped and fully exempt) both require the SAME (planSource: federalCivilian, planStructure: definedBenefit) pair to receive contradictory treatment; no single PerSourceExemptionRule can satisfy both, and neither age nor AGI separates them. This file cannot be fully satisfied by any StateTaxData configuration until PlanSource gains a distinct uniformed-services case.
  VT  OVERTAXES by $305.62, Same missing mechanism as the case above; this fixture specifically pins the linear phase-out band's magnitude ($5,000 of the $10,000 cap retained at AGI $60,000), not just the full-exemption case.
  VT  OVERTAXES by $335.00, Both spouses' combined CSRS income up to $10,000 qualifies for the shared exclusion; the engine grants none, taxing the full $65,000 household income.
  VT  OVERTAXES by $335.00, Only the CSRS spouse's income (up to $10,000) should be excluded; the engine excludes neither spouse's pension, taxing the full $55,000 -- the identical figure the fully-covered MFJ case above produces at the same total income.
  VT  OVERTAXES by $4525.15, This app's PlanSource enum has no case for military retired pay distinct from federal civilian service (used here as the closest available label, disclosed as imprecise); more materially, statetax-2026-VT.json models neither VT retirement exclusion at all, so the engine taxes the full $100,000 military pension exactly as ordinary income. CANNOT_VERIFY: this file's VT-5 (military, uncapped and fully exempt) and VT-1 (CSRS, capped at $10,000) both require the SAME (planSource: federalCivilian, planStructure: definedBenefit) pair to receive contradictory treatment; no single PerSourceExemptionRule can satisfy both, and neither age nor AGI separates them. This file cannot be fully satisfied by any StateTaxData configuration until PlanSource gains a distinct uniformed-services case.
  VT  OVERTAXES by $5211.50, Same missing military exclusion as the case above, pinned specifically in Act 71's linear phase-out band (AGI $150,000, 50% of the pension retained as excludable). The gap here ($5,211.50) is the single largest dollar defect measured in this batch.

TIER3, 17 cases, 8 jurisdictions
  AR  OVERTAXES by $192.24, exemptionAppliesPerIndividual is false, so RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-AR.json's config applies the $6,000 cap once household-wide instead of once per taxpayer, halving the correct $12,000 MFJ exclusion. PHASE 5 WARNING: expectedStateTax in every case is computed against the CONFIGURED bracket table (top rate 3.7%), not Arkansas's real published top rate of 3.9%. Fixing exemptionAppliesPerIndividual alone will turn this case green, but Arkansas will still be wrong for every filer whose income reaches the top bracket. Green here does NOT mean Arkansas is correct.
  CO  OVERTAXES by $1056.00, CO's config has no exemptionAppliesPerIndividual/exemptionAttribution override so the engine pools both spouses' pension income and applies ONE $24,000 household cap, when DR 0104AD Lines 4 and 6 are two separately-computed $24,000 caps (one per spouse, per that spouse's own age) per the instructions' explicit 'do not intermingle' rule.
  DE  UNDERTAXES by $439.50, regularExemptionMinAge is 0, so RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-DE.json's config applies the 60-or-over $12,500 exclusion level unconditionally instead of gating a non-military filer under 60 to the correct $2,000 level.
  DE  OVERTAXES by $590.50, exemptionAppliesPerIndividual is false, so RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-DE.json's config applies the $12,500 cap once household-wide instead of once per spouse, halving the correct $25,000 MFJ exclusion when both spouses are 60+ and independently qualify.
  DE  OVERTAXES by $96.00, Both the missing age gate and the missing per-individual flag are wrong together: today's engine applies the unconditional $12,500 level to the whole pooled $37,000 regardless of either spouse's age.
  KY  OVERTAXES by $1088.85, KY's config has no exemptionAppliesPerIndividual/exemptionAttribution override so the engine pools both spouses' pension income and applies ONE $31,110 household cap, when Schedule P computes each spouse's own $31,110 exclusion separately and combines them regardless of filing status.
  LA  UNDERTAXES by $360.00, regularExemptionMinAge is 0, so RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-LA.json's config applies the 65-or-older $12,000 exclusion unconditionally to a filer well under 65, entitled to no general retirement-income exclusion at all under La. R.S. 47:44.1.
  LA  OVERTAXES by $360.00, exemptionAppliesPerIndividual is false, so RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-LA.json's config applies the $12,000 cap once household-wide instead of once per spouse, halving the correct $24,000 MFJ exclusion.
  LA  UNDERTAXES by $90.00, Both the missing age gate and the pooled, unattributed income model are wrong together, over-sheltering the ineligible under-65 spouse's own retirement income instead of excluding only the 65+ spouse's own $9,000.
  OK  OVERTAXES by $435.00, exemptionAppliesPerIndividual is false, so RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-OK.json's config applies the $10,000 cap once household-wide instead of once per spouse, halving the correct $20,000 MFJ exclusion. PHASE 5 WARNING: expectedStateTax is computed against the CONFIGURED standard deduction ($13,550/$27,100) and bracket table (top rate 4.5%), not Oklahoma's real published figures ($6,350/$12,700 standard deduction, 4.75% top marginal rate). Fixing exemptionAppliesPerIndividual alone will turn this case green, but Oklahoma will still be substantially wrong for every filer. Green here does NOT mean Oklahoma is correct.
  SC  UNDERTAXES by $364.70, regularExemptionMinAge is 0 with no earlyAgeTier configured, so RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-SC.json's config applies the 65-or-older $10,000 retirement-deduction level unconditionally instead of gating a filer under 65 to the correct $3,000 level. PHASE 5 WARNING: same configured-bracket-table caveat as the other SC cases below.
  SC  OVERTAXES by $99.50, No field in RetirementIncomeExemptions models South Carolina's separate $15,000 age-65 deduction against any income. PHASE 5 WARNING applies.
  SC  OVERTAXES by $1042.00, exemptionAppliesPerIndividual is false AND the $15,000 age-65 deduction has no field at all. PHASE 5 WARNING applies.
  SC  OVERTAXES by $416.80, The under-65 age-tier gate is missing AND the $15,000 age-65 deduction has no field at all. PHASE 5 WARNING applies. (All four SC cases: expectedStateTax is computed against the CONFIGURED two-bracket 1.99%/5.21% structure switching at $30,000, not SC1040TT's real 6%-minus-$642 schedule above $100,000. Green on any SC case does NOT mean South Carolina's bracket table is correct.)
  WV  OVERTAXES by $224.80, No field in RetirementIncomeExemptions models West Virginia's $8,000 senior citizen modification; pensionExemption/iraWithdrawalExemption are both .none for every age.
  WV  OVERTAXES by $414.40, No field models the $8,000-per-spouse senior modification or its reduction by other modifications already claimed.
  WV  OVERTAXES by $274.00, No field models the $8,000 senior modification at all, so today's engine excludes nothing for the qualifying spouse's own pension income.

TIER4, 18 cases, 4 jurisdictions
  NM  OVERTAXES by $138.90, The engine still applies NM's pre-HB252 bracket schedule (deleted from law effective TY2025), not the enacted 6-bracket 1.5%-5.9% schedule.
  NM  OVERTAXES by $35.70, Same stale pre-HB252 bracket schedule, compounded with NM's $8,000-scale age-65 PIT-ADJ exemption (entirely unmodeled).
  NM  OVERTAXES by $55.30, Same stale bracket and missing age-65 PIT-ADJ exemption; pins the correct MFJ-column, per-qualifying-spouse exemption behavior the engine has no representation for at all.
  NM  OVERTAXES by $201.20, Same stale pre-HB252 bracket schedule; PIT-ADJ age exemption is legitimately zero at this income under real law too, so this case isolates the bracket-schedule gap alone.
  OH  UNDERTAXES by $73.38, OH's $332 TY2026 bracket base amount, its MAGI-banded personal exemption, and its retirement income credit (up to $200/return) are all unmodeled.
  OH  UNDERTAXES by $23.38, Same mechanism; both the retirement income credit and the $50 senior citizen credit are unmodeled.
  OH  OVERTAXES by $36.62, Same mechanism, doubled exemption count for MFJ.
  OH  OVERTAXES by $36.12, Same mechanism; the age-gated senior credit has no engine-side counterpart at all.
  OH  UNDERTAXES by $279.38, Same bracket-base and exemption gap; the credits' hard $100,000 MAGI cliff has no engine-side counterpart to lose.
  UT  OVERTAXES by $662.50, UT's Taxpayer Tax Credit (up to 6% of the federal standard deduction, phased out 1.3%/dollar over $18,213/$36,426 MAGI) is entirely unmodeled and the engine's flat rate is stale (4.55% configured vs 4.45% enacted for TY2026 by S.B. 60).
  UT  OVERTAXES by $1291.00, Same Taxpayer Tax Credit and rate-staleness gap, compounded with the separate age-gated Retirement Credit ($450/person, fixed 1952 birth-year cutoff), also unmodeled.
  UT  OVERTAXES by $1764.00, Same mechanism; the engine cannot represent the doubled Retirement Credit base for two qualifying spouses because it models neither credit.
  UT  OVERTAXES by $1724.50, Same mechanism as the both-spouses-qualify MFJ case.
  UT  OVERTAXES by $110.00, At this income both UT credits are legitimately zero under real law too, so the entire gap is the stale flat rate: 4.55% engine vs 4.45% enacted.
  WA  UNDERTAXES by $8540.00, WA's capital gains excise tax (RCW 82.87) is not modeled at all; capitalGainsTreatment is hardcoded to .noStateTax and .specialLimited always returns $0.
  WA  UNDERTAXES by $8540.00, Same mechanism, MFJ.
  WA  UNDERTAXES by $91978.00, Same mechanism, spanning both the 7% and 9.9% tiers.
  WA  UNDERTAXES by $70000.00, Same mechanism, at the exact 7%/9.9% tier boundary.

UNCLASSIFIED, 17 cases, 4 jurisdictions
  IN  OVERTAXES by $29.50, Not a retirement-exclusion defect (the audit's .none is correct); IN's $1,000/$2,000 personal exemption is not modeled anywhere in the engine.
  IN  OVERTAXES by $29.50, Same mechanism, single.
  IN  OVERTAXES by $59.00, Same mechanism, doubled for MFJ.
  IN  OVERTAXES by $59.00, Same mechanism, MFJ.
  MN  OVERTAXES by $802.50, MN's Social Security subtraction is entirely unmodeled; socialSecurityExempt is hardcoded false with no income-gated subtraction path.
  MN  OVERTAXES by $909.50, Same missing Social Security subtraction, PLUS MN's own $2,000 aged additional standard deduction is unmodeled; the engine produces the IDENTICAL wrong figure for age 55 and age 70.
  MN  OVERTAXES by $1037.90, MN's Qualified Public Pension Subtraction (household-capped at $27,690 MFJ) and its doubled aged addition are both unmodeled.
  MN  OVERTAXES by $1567.01, Same mechanism; the engine cannot represent that only the qualifying spouse's pension and age contribute.
  MN  OVERTAXES by $418.53, Same missing Public Pension Subtraction and aged addition; the subtraction's own phase-out has no engine-side counterpart.
  NE  OVERTAXES by $68.77, Not a retirement-exclusion defect (the audit's .none is correct); NE's stateDeduction ($12,000 single) is stale against the real published figure ($8,600), and the $171-per-exemption personal credit is unmodeled.
  NE  UNDERTAXES by $312.24, Same mechanism, single.
  NE  UNDERTAXES by $169.54, Same mechanism, doubled for MFJ.
  NE  UNDERTAXES by $299.54, Same mechanism, MFJ.
  OR  OVERTAXES by $105.56, Not a retirement-exclusion defect (the audit's .none is correct); OR's standard deduction and lower-bracket thresholds are both miscalibrated, and the $256-per-exemption credit is unmodeled.
  OR  UNDERTAXES by $173.00, Same mechanism; credit is $0 under both sides here, so the entire gap is the deduction/threshold miscalibration.
  OR  OVERTAXES by $210.12, Same mechanism, doubled for MFJ.
  OR  OVERTAXES by $210.12, Same mechanism, MFJ.
```

## Catalogue headline counts (from the shipped fixtures, not from batch-report prose)

- 50 fixture files, 207 total scenarios.
- **118 scenarios carry a `knownDefect`** across **35 jurisdictions**.
- **89 scenarios pass clean** (no `knownDefect`; engine matches the state's own form).
- **15 jurisdictions are entirely clean**, every scenario agreeing with its own form: AK, CA,
  FL, IL, MS, ND, NH, NJ, NV, NY, PA, SD, TN, TX, WY. Eight of these are no/limited-income-tax
  states, seven are states with a modeled exclusion mechanism the audit and/or this phase
  independently confirmed correct.
- Tier breakdown: tier1 34 cases/11 states, tier2 32/8, tier3 17/8, tier4 18/4, unclassified
  17/4. Sums to 118/35, matching `printCatalogue`'s own totals exactly, and matching the
  catalogue test's own re-derivation from the fixtures directly (not transcribed from any
  batch report, several of which have internal arithmetic that does not reconcile with their
  own per-state case listings -- b6's report, for one, states "42 cases total" while its own
  per-state breakdown sums to 46; this ledger's counts come from parsing the shipped JSON, not
  from either number in that report).

**What `tier` means, and what it does not.** Batches 6-9 used `tier` as the jurisdiction's audit
tier, per the plan. Batch 5 used it as a severity rating instead, assigning `tier1` to GA and MO
and `tier3` to CO and KY even though the 2026-08-02 audit's own section 5 ("Confirmed CORRECT --
do not touch") lists all four with no tier at all -- they are caveats on a correct verdict, not
tiered defects. Task 4 and batch 9 treated the same kind of situation (a defect the audit did
not classify) as `unclassified` instead. The result: a missing personal exemption is `tier2` in
Kansas, `tier4` in Ohio, and `unclassified` in Indiana and Nebraska. **`tier` is NOT a mechanism
grouping** -- do not read `printCatalogue`'s tier-grouped output as "all tier2 cases share a
fix." Retiering the 118 cases to make `tier` mechanism-consistent would churn every entry for no
correctness gain and is deliberately NOT done here. The personal-exemption and
per-exemption-credit states (KS, IN, NE, OR, OH) span four different tiers and are, mechanically,
two shared fixes.

## Comparison against the audit (2026-08-02-full-50-state-verification.md)

The audit predicted roughly 29 defective jurisdictions across five sections (Iowa's own
section plus Tiers 1-4), and separately named a list of jurisdictions it called "confirmed
correct, do not touch." This section is the phase's real payoff: does a single-source memo,
built from one pass of secondary and primary sources with no independent verification, survive
51 independently-cited fixtures built against each state's own form. Where it does not, the
verdict below says explicitly which side was wrong and why, per state, not just "differs."

### Bucket 1: Predicted and confirmed

The audit's Tier 1-3 predictions held up, jurisdiction by jurisdiction, with the mechanism and
direction it described:

- **Iowa** -- full exclusion missing at 55+, Roth conversion income invents tax on the app's
  core transaction. Confirmed exactly, 4/4 predicted mechanisms pinned.
- **Michigan** -- unconditional `.full` overstates against a real cap. Confirmed on direction
  and mechanism; the exact TY2026 cap figure remains open (see Open Items -- the audit's own
  $67,610/$135,220 numbers were not independently reproducible from RAB 2026-1 either, which
  states its own 2026-indexed figure has not been published).
- **Connecticut** -- the audit's own table already flagged "both" directions; confirmed:
  IRA-side overstates above the AGI cliff, pension-side understates unconditionally.
- **Wisconsin** -- missing gate, understates. Confirmed, no exclusion mechanism exists at all.
- **Alabama** -- both halves of the audit's claim (DB fully exempt, DC capped $6,000/person at
  65+) confirmed; the app models neither because `perSourceExemptions` is empty for AL.
- **Rhode Island** -- pension-side understatement confirmed. One nuance the audit's blanket
  claim did not carry: RI's IRA side is coincidentally CORRECT today (real law also denies
  IRAs the modification), so `iraWithdrawalExemption: .none` happens to be right for the wrong
  reason. Worth knowing before "fixing" RI's IRA treatment.
- **Maryland** -- overstatement confirmed. The audit called this "small," attributing it to a
  ~$600 dollar-figure drift; Phase 4 found the REAL and much larger mechanism is structural
  (missing age-65/disability gate, missing Social Security offset), producing overstatements of
  $959-$1,213 per case, not a small dollar-figure difference. The audit's direction was right;
  its characterization of severity and mechanism understated the defect considerably.
- **Kansas** -- both the per-source wall (KPERS/federal/military exempt, private taxable) and
  the personal-exemption gap the audit attributed to Steve's separate report (already flagged
  by the audit itself as "Kansas now has two independent defects") are confirmed, 6/6.
- **Massachusetts** -- contributory/noncontributory distinction confirmed exactly, including
  the audit's own MA-2 contrast case (noncontributory municipal taxed correctly, by accident of
  the app's blanket taxation).
- **Hawaii** -- employer-vs-employee-funded distinction confirmed exactly.
- **North Carolina** -- Bailey exemption confirmed (3/4 pinned cases), plus one narrow
  expressibility gap the audit did not and could not have anticipated -- see CANNOT_VERIFY.
- **Idaho** -- the general CSRS/police/fire rule confirmed, with a real refinement the audit's
  one-line summary blurred: military retirees qualify at age 62 under a SEPARATE line
  (Form 39R Line 8e), not the general 65+ gate. Not a contradiction; a richer true picture.
- **Delaware** -- BOTH predicted gaps (missing age-60 gate, missing per-individual flag)
  confirmed exactly as described, including their combination.
- **Louisiana** -- age-65 gate and per-individual flag both confirmed exactly.
- **Arkansas** -- per-individual flag confirmed. (Base-rate staleness found alongside is a
  separate, not-predicted item -- see Bucket 3 and Known-but-unpinned.)
- **South Carolina** -- the audit's headline $15,000 age-65-deduction gap confirmed exactly.
- **West Virginia** -- the $8,000 senior modification gap confirmed exactly as described.
- **Ohio** -- both named credits (retirement income credit, senior citizen credit) confirmed
  missing.
- **Washington** -- confirmed exactly as described: the capital gains excise tax is genuinely
  unmodeled, `.noStateTax` returns $0 regardless of realized gain, and the code comment
  describing "7% on gains > $250K" describes a computation the engine does not implement.
- **Missouri (public-pension cap)** -- the mechanism the audit flagged as a caveat within its
  "confirmed correct" section (the pension exclusion dollar amounts are right; the pension
  exemption's CAP against maximum Social Security benefit is not modeled) is confirmed real and
  correctly diagnosed. It could not be pinned with a fixture -- see Known-but-unpinned.
- **New York** -- the audit's Tier 2 prediction (government pensions should be fully excluded,
  distinct from the $20,000 line-29 cap) WAS a real, confirmed defect at the time the audit was
  written. It is not one anymore: Phase 3b (Task 4, commit bbf631d+3bfab67) shipped New York's
  IT-201 Line 26 uncapped government-pension exclusion before Phase 4 began. Phase 4's NY
  fixture (4 scenarios, 0 defects) confirms NY is fully clean today. Recorded here as
  "predicted, confirmed at the time, already remediated," not as a live Phase 4 finding.
- **Oklahoma amount** -- the audit's "confirmed correct, $10,000 stands, HB2190 still in
  committee" claim reproduced exactly; OK's per-individual attribution gap (a separate,
  Tier-3-predicted item) is the live defect, not the dollar figure.
- **Kentucky amount** -- the audit's "$31,110 stands, HB146 died in committee" claim reproduced
  exactly (KY's own defect, found new, is the MFJ per-individual attribution gap -- Bucket 3).
- **Colorado amount** -- the audit's calibration-probe claim (SB25-136 postponed indefinitely,
  $24,000/$20,000 caps stand) reproduced exactly, confirmed a second time independently by this
  phase against the actual bill-status page.
- **Georgia retirement-exclusion mechanics** -- the audit's $65,000/$35,000 age-tier figures
  and MFJ-doubling mechanic confirmed exactly correct. Georgia's LIVE defect (the stale rate)
  is unrelated to what the audit checked -- see Bucket 3.
- **Illinois, Mississippi, Pennsylvania** -- full exemption confirmed correct; pre-existing
  Phase 2 fixtures, unchanged, still clean.
- **New Jersey** -- stepped phaseout confirmed correct; pre-existing Phase 2 fixture, unchanged.
- **California, North Dakota** -- "no retirement exclusion, correct" confirmed exactly, AND
  these are the only two of the audit's five "confirmed correct, no exclusion" states with NO
  defects of any kind. (Nebraska, Indiana, Oregon are also confirmed correct on the exclusion
  dimension specifically, but carry unrelated defects -- see Bucket 3.)
- **The seven no-income-tax states plus New Hampshire** -- confirmed, all 32 scenarios pass at
  exactly $0.00.

### Bucket 2: Predicted and NOT reproduced (the audit was wrong)

Applying a strict reading -- the audit's SPECIFIC described rule, tested literally, does not
match TY2026 law -- three states qualify, all independently caught by primary-source review in
this phase (b7's own framing called this "the audit falsified in three places," naming Arizona
alongside these two; this ledger's more conservative reading places Arizona in Bucket 1+3
instead, since its core predicted mechanism DOES reproduce -- see the note under DC below for
why the bar is drawn there):

- **District of Columbia -- the audit was wrong.** The audit described "$3,000 at 62+, DC or
  federal government pensions only" as the current rule. That provision (D.C. Code
  47-1803.02(a)(2)(N)(i)) contains its own sunset clause: "this sub-subparagraph shall apply
  for taxable years beginning before January 1, 2015." It expired in 2015 and does not apply to
  TY2026. Confirmed by reading the current D-40 booklet cover to cover (97 pages): no
  pension-exclusion line exists anywhere for a living retiree's own pension. Current law
  excludes only SURVIVOR benefits (subparagraph (N)(ii), no sunset, uncapped, still age 62+,
  DC/federal source only) -- a different beneficiary class than the audit described. A fixture
  built literally to the audit's description would assert a rule that does not exist for
  TY2026. This phase's own task brief repeated the audit's description of DC verbatim, so the
  wrong claim propagated one layer before an implementer caught it against the primary source.
- **Vermont -- the audit was materially wrong about scope, right about mechanism for CSRS
  only.** The audit collapsed two independent Vermont exclusions into one: "$10,000
  military/CSRS exclusion, AGI-limited $55k/$70k." The CSRS half of that description is
  confirmed correct exactly as stated. The military half is not the same rule at all: Act 71
  (S.51, signed June 25, 2025, brand new for TY2025) created a SEPARATE military retirement
  exclusion that is FULLY UNCAPPED (not $10,000), applies at a single $125,000 AGI threshold
  regardless of filing status (not the $55k/$70k single/MFJ split), and phases to zero at
  $175,000. A fixture built to the audit's literal description for a military pension would use
  the wrong cap, the wrong threshold, and the wrong filing-status structure. This produced the
  single largest dollar defect measured anywhere in the phase ($5,211.50, VT case 6).
- **Utah -- the audit was wrong, and conflated two different credits.** The audit's
  "$450/person, full at <=$54,000 single / $90,000 joint" description names the Retirement
  Credit's dollar amount but the OTHER credit's thresholds. UT's actual Retirement Credit
  (UCA 59-10-1019) is gated by a FIXED birth-year cutoff ("born on or before December 31,
  1952"), not age 65 as the audit's framing implies, and phases out at a much steeper rate
  starting at $25,000 single / $32,000 MFJ MAGI, not $54,000/$90,000. Those figures belong to a
  wholly separate Social Security Benefits Credit the audit did not name. A fixture built to
  the audit's literal thresholds for the Retirement Credit would be wrong on both the gate and
  the phase-out. This is the exact single-source conflation the audit's own §7 warned about,
  reproduced inside the audit itself.

**Arizona, considered and NOT placed in this bucket.** The audit's specific claim ("the $2,500
exclusion covers government pensions only; the app applies it to all pensions, overstating the
exemption") reproduces exactly (AZ case 2). What the audit did not mention -- the per-spouse
cap doubling (Line 29a) and the separate, uncapped military Line 29b exclusion -- are real,
additional gaps this phase found, not contradictions of what the audit claimed. Both push tax
in the OPPOSITE direction from the audit's named mechanism (AZ cases 3 and 4 both OVERTAX,
where the audit predicted understatement), so Arizona's net picture is richer and partly
opposite in direction from the audit's single-mechanism description, but the audit's own
testable claim was not falsified. Recorded here rather than silently folded into Bucket 1
because the distinction matters: DC and Utah's audit entries would produce a WRONG fixture if
followed literally; Arizona's would produce a CORRECT but incomplete one.

### Bucket 3: NOT predicted but found

The audit examined one of thirteen configuration dimensions (retirement-income exclusions).
Everything below is a real, primary-source-confirmed defect this phase found in a DIFFERENT
dimension, on top of what the audit covered -- expected, and it is the single largest bucket
by case count once Georgia, New Mexico, and Utah's non-retirement rate/bracket defects are
counted, because those three hit every filer in those states, not just retirees:

- **Georgia -- stale rate and standard deduction, the largest non-retirement finding in the
  phase.** 5.39% configured against a 4.99% enacted rate (HB 463, retroactive to 2026-01-01,
  confirmed against Georgia DOR's own "Important Tax Updates" page and the Governor's signing
  press release), plus a $12,000/$24,000 standard deduction configured against the real
  $15,000/$30,000. Every one of Georgia's five tier1 cases in the catalogue is this defect, not
  a retirement-exclusion error -- the exclusion mechanics the audit checked are correct in
  every one of them.
- **Utah -- the Taxpayer Tax Credit, bigger than the named Retirement Credit, plus a stale
  rate.** UCA 59-10-1018's Taxpayer Tax Credit (an income-scaled offset applying to essentially
  every Utah filer, not just retirees, phasing out 1.3% per dollar over $18,213/$36,426 MAGI)
  is entirely unmodeled and was never mentioned by the audit. Also found: 4.55% configured vs
  4.45% enacted (S.B. 60, confirmed from both the introduced and enrolled bill text), meaning
  Utah has been stale against even the PRE-cut rate for longer than one legislative session,
  and every Utah filer is affected regardless of retirement status.
- **New Mexico -- the entire bracket schedule is stale, pre-HB252.** HB252 (Laws 2024,
  Chapter 67, signed 2024-03-06) replaced NM's 5-bracket 1.7%-5.9% schedule with a 6-bracket
  1.5%-5.9% schedule effective TY2025. `statetax-2026-NM.json` still carries the OLD, DELETED
  table verbatim, confirmed by reading the bill text's own bracketed-for-deletion old table
  against its new one. A two-year-old enacted change was never applied, and it hits every New
  Mexico filer. The audit's named age-65 exemption gap ($8,000, graduated not a strict cliff,
  as this phase refined) is real too, but is the SMALLER of NM's two defects.
- **Colorado, Kentucky -- MFJ per-individual attribution.** Both states pool both spouses'
  pension income into ONE household cap where the primary source (DR 0104AD's "do not
  intermingle" instruction for CO; Schedule P's per-taxpayer Column A/B structure for KY)
  requires two separately-computed per-spouse caps. Same shape as the Tier-3 states the audit
  DID predict this pattern for (OK, DE, LA, AR, SC, WV); the audit's own "confirmed correct, do
  not touch" list for CO and KY covered only the dollar amounts, not this attribution gap.
- **Arizona -- per-spouse cap doubling and the separate military exclusion.** See the Bucket 2
  discussion above; both are real, additional, primary-source-confirmed gaps beyond the
  audit's single-mechanism description.
- **Idaho -- the distinct military age gate (62, not 65).** A real, primary-source-confirmed
  refinement the audit's one-line summary did not carry.
- **Missouri -- the private pension/IRA/401(k) cap, the largest finding in that batch given the
  app's own purpose.** The audit's Missouri entry focused entirely on the PUBLIC pension cap.
  The PRIVATE pension/IRA/401(k) exemption is not "full" either: it is a small $6,000-per-
  taxpayer amount that phases out completely above $25,000 single / $32,000 MFJ Missouri AGI.
  Since this app's core use case is IRA withdrawal and Roth conversion planning, and typical
  users' income is well above those thresholds, the app currently shows $0 Missouri tax on IRA
  withdrawals in exactly the situations where Missouri law taxes them in full. This is pinned
  (MO case 2 in the catalogue) and distinct from the unpinned public-pension defect below.
- **Ohio -- the $332 TY2026 bracket base amount and the MAGI-banded personal exemption**, on
  top of the two credits the audit did name.
- **Minnesota -- never audited at all.** Appears in no tier of the audit and on no
  confirmed-correct list. Phase 4 found MN's TY2026 brackets and BASE standard deduction are
  genuinely correct (verified line by line against a dated MN DOR TY2026 publication, not
  inferred from the audit's silence) -- the only "the prior config was fine here" result that
  came from checking a state nobody had looked at, worth exactly as much scrutiny as a defect
  claim. What's missing: the Social Security subtraction (entirely absent, hardcoded false),
  the Qualified Public Pension Subtraction, and Minnesota's own separate $2,000/$1,600 aged
  additional standard deduction. 5 defects, tier unclassified.
- **Nebraska, Indiana, Oregon -- non-retirement defects in states the audit correctly called
  `.none`-correct on the exclusion dimension.** NE: stale standard deduction ($12,000
  configured, a roughly-2013 pre-inflation base, against the real $8,600) plus a missing
  $171-per-exemption personal credit. IN: the $1,000/$2,000 personal exemption entirely
  unmodeled (every discrepancy exactly `exemption x 0.0295`). OR: stale standard deduction,
  miscalibrated lower-bracket thresholds, and a missing $256-per-exemption credit. All 17
  unclassified-tier cases outside Minnesota's five are this pattern.

### Bucket 4: CANNOT_VERIFY

Four entries, deliberately kept distinct because they resolve differently and belong to
different downstream phases:

- **Montana -- law is unresolved, not the model.** Mechanism confirmed (Montana DOR Form 2 2025
  Instructions, page 6: the old income-gated `.partial(4_640)` deduction was repealed effective
  TY2025 and replaced with a flat age-65 subtraction), but the exact TY2026 INDEXED dollar
  figure has not been published by Montana DOR as of 2026-08-04. This is an EXTERNAL blocker --
  nothing in the app or its schema needs to change; the fixture (and, eventually, Phase 5's
  correction) is waiting on Montana DOR to publish a number. Belongs to Phase 6 as a
  `knownLimitations` entry until that happens, not to Phase 5 as something to build. Encoded as
  data in `GoldenScenarioCoverageTests.cannotVerify`, with its own pinned membership test.
- **North Carolina's Bailey mixed-vesting sub-case -- the model is unresolved, not the law.**
  NC's Bailey/Emory/Patton exclusion is a vesting-date rule: 5+ years of creditable service in
  a qualifying NC/federal government retirement system as of 1989-08-12, confirmed directly
  from NCDOR's own bulletin. The law is completely clear. What cannot be expressed is a
  household with TWO government pensions of the IDENTICAL `PlanSource` where only ONE is
  Bailey-vested (e.g. one spouse hired in 1975, the other in 1995, into the same NC state
  system) -- both rows decode to the same `planSource` with no field to distinguish them. This
  is NOT why NC is excluded from `covered` (it is not excluded; NC has four pinned cases, each
  of which stipulates Bailey status in prose for a single classified row, which the schema CAN
  express one row at a time). It is a narrower, INTERNAL blocker -- an engine/schema gap Phase 5
  (or a schema-widening pass) could close by adding a vesting-date field, with no external
  dependency at all. Recorded here as an open item for Phase 5's design, not Phase 6's
  disclosure copy, precisely because it is an engineering decision, not a waiting-on-a-source
  decision.
- **Vermont -- the model is unresolved, not the law, and this one is worse than NC's: the
  fixture SET is internally unsatisfiable, not just under-expressive for one household.** VT-1
  (age 63, AGI $40,000) requires a $10,000 cap on `(federalCivilian, definedBenefit)`; VT-5 (age
  60, AGI $100,000) requires that SAME pair uncapped and fully exempt. No age gate and no AGI
  phase-out can separate them, because the distinguishing fact is military versus CSRS, which
  `PlanSource` has no case for (`PerSourceExemptionRule` matches only on `matchSources` and
  `matchStructures`, `StateTaxData.swift:308,327-329`, and configuration is per-STATE, not
  per-scenario, so one rule set must serve both VT-1 and VT-5 at once). An INTERNAL blocker,
  same class as NC's: the law is completely clear, the model cannot express it. Closed by the
  same fix NC and AZ/ID/MA would benefit from -- a distinct uniformed-services `PlanSource`
  case. See the CRITICAL-1 blocker entry above.
- **DC -- the model is unresolved, not the law, and the fixture SET is internally
  unsatisfiable.** DC-3 and DC-4 (both spouses 62+, `federalCivilian` survivor benefit) require
  `(federalCivilian, definedBenefit)` fully exempt; DC-5 (age 65, `federalCivilian` own pension)
  requires that SAME pair fully taxable. Both parties are 62 or older in every one of these
  cases, so age cannot separate them either; the distinguishing fact is survivor-versus-own,
  which `ClassifiedPensionSource` has no field for. An INTERNAL blocker, same class as NC's and
  Vermont's: the law is completely clear, the model cannot express it. Closed by adding a
  survivor flag to `ClassifiedPensionSource`. A prior pass of this ledger (attributed to batch
  7) examined this exact DC risk and concluded a same-`planSource` survivor/own collision would
  need a single household to bite, and so "did not become a second CANNOT_VERIFY entry." That
  reasoning was wrong: `perSourceExemptions` configuration is shared across the WHOLE file, not
  evaluated per household, so DC-3/DC-4 and DC-5 collide across scenarios in the same file
  exactly as VT-1/VT-5 do. Recorded here as the correction.

## Known-but-unpinned: real defects with no golden case

**Missouri's public-pension cap** is the flagship example the task specifically asked to be
carried forward as executable data (`GoldenScenarioDefectCatalogueTests.knownButUnpinned`).
Mechanism: MO-A 2025 Part 3 Section A caps the public-pension exemption at the lesser of the
pension received or each individual's own maximum Social Security benefit, reduced by any SS
deduction claimed; `StateTaxData.swift` codes it `.full` (unlimited). The b5 batch tried, in
order: the 2026 Federal Register COLA notice (reachable, does not carry the figure); every
ssa.gov path for a press release, fact sheet, or OACT table (all return HTTP 403 to both
WebFetch and curl); CRS Report 94-803 (reachable, does not carry the figure); Missouri's own
2026 MO-A form (404, unpublished); the Wayback Machine (no snapshot of the SSA pages that would
carry it). The scenario that would have pinned this WAS written and verified against a
secondary-sourced $49,824 figure, then DELETED rather than shipped on that source, per this
phase's own citation discipline. Missouri's fixture carries 3 scenarios today, not 4.

**A second, smaller category: base-computation defects deliberately isolated OUT of Tier 3
attribution fixtures**, disclosed in-fixture with an explicit "PHASE 5 WARNING" but with no
dedicated case of their own:

- **Oklahoma** -- standard deduction configured at MORE than double the real figure
  ($13,550/$27,100 vs the real $6,350/$12,700) and a stale top rate (4.5% configured vs 4.75%
  enacted). Fixing OK's per-individual attribution flag alone will turn OK's fixture green
  while Oklahoma remains substantially wrong for every filer.
- **Arkansas** -- stale top rate (3.7% configured vs 3.9% enacted).
- **South Carolina** -- the CONFIGURED two-bracket 1.99%/5.21% structure (switching at
  $30,000) does not match SC1040TT's real 6%-minus-$642 schedule applying above $100,000. All
  four SC cases carry this warning.

**Correction: West Virginia does NOT belong in this category.** An earlier draft of this section
listed WV alongside OK/AR/SC as carrying an explicit "PHASE 5 WARNING" and a disclosed
$2,000-per-exemption personal exemption gap. Neither is true of the shipped
`statetax-2026-WV.golden.json`: it contains no "PHASE 5 WARNING" text anywhere, and no mention
of a personal exemption at all. The only related disclosure is in WV-1's `source` field, a
prose caveat that the configured bracket rates were not independently confirmed against a
primary 2026 WV rate schedule -- a narrower, unflagged note, not a warning that WV's numbers are
wrong. The "Open items Phase 5 inherits" section below lists only OK, AR, SC for this category;
that section is correct, this one was not.

The distinction from Missouri matters: OK, AR, and SC all HAVE fixtures and the warning is
readable by anyone who opens the case. Missouri has NO case for this specific defect at all,
which is why it alone needed the separate `knownButUnpinned` data structure -- there is no
fixture text for a future reader to find it in.

## Citation findings

Full detail lives in `.superpowers/sdd/progress.md`; this is the summary Phase 5-7 should
carry forward. Three distinct citation-failure modes were separated across the phase, all
invisible to every test in the suite:

1. **Right document, wrong location.** The document is real and correctly cited; the specific
   page or slide named does not carry the quoted text (it is elsewhere in the same document).
   Occurred at least ten times across the phase: Wyoming (Slide 4 for text on Slide 5),
   Oregon (page 17 for text on page 32), Connecticut (page 24 for the Phase-Out Table itself,
   which is on page 25), six instances across Oklahoma/Arkansas/Delaware/West Virginia in one
   batch, and others. Control that catches it: extract the document page by page and check the
   printed footer against the specific page requested, not the page a search snippet or memory
   implied.
2. **Invented text.** A quoted sentence, presented as verbatim and attributed to a real
   document and page range, does not appear anywhere in that document. Two confirmed instances,
   both diagnosed the same way in the implementer's own words: not a misattributed quote from a
   different document, but "generic domain-memory boilerplate... written to match a conclusion
   I already believed, rather than derived from the source." Hawaii's HI-2 case (a CLEAN case
   with no `knownDefect`, meaning the citation was the ONLY thing a reader could have checked at
   all) quoted a sentence about deferred-compensation taxation that exists in no document; the
   real, correct sentence supporting the same true conclusion was on the same page, just not
   the one quoted. Michigan's case 1 fabricated an "'N/A' row of the RAB's own phase-in table"
   that does not exist; the underlying legal claim was correct and stated in real prose
   elsewhere on the same page. In both cases the ANSWER was right and the EVIDENCE was
   invented. Control: search the extracted text for the literal quoted sentence; never assume
   presence from a plausible-sounding recollection.
3. **Right document, wrong edition.** The most dangerous of the three, because every other
   control passes it: URL resolves, document is official, quote is verbatim, page is right --
   and the document is simply from the wrong TAX YEAR. Maryland's $41,200 figure was
   "personally verified" against Worksheet 13A, a real, correct, authoritative PDF -- whose own
   embedded metadata title reads "2025 Pension Exclusion Computation Worksheet 13A." The figure
   is consistent with, not contradicting, a separate secondary report that TY2026 dropped to
   $40,600; there is currently no primary-source confirmation of EITHER candidate figure for
   TY2026. Control: check the document's own year metadata (e.g. `pdfinfo`'s Title field), not
   just its content.

Two fabricated citations were caught this phase (Hawaii's HI-2, Michigan's case 1), both by a
reviewer independently downloading and text-extracting the source document rather than trusting
a prior fetch. None of the three failure modes would have failed a single test in the suite --
citation correctness is a process control, per spec 3.4, not something the type system or the
assertion suite can verify. The controller's generalization, worth repeating for Phase 5-7:
the risk of a fabricated citation is highest exactly when the author already believes the
conclusion is correct. A citation written to justify a conclusion is not a citation; confidence
in the conclusion is the warning sign, not the reassurance.

## Full suite gate (Step 6)

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA -destination 'platform=macOS'
...
✔ Test run with 1856 tests in 292 suites passed after 319.392 seconds.
** TEST SUCCEEDED **
```

`xcresulttool get test-results summary`: `failedTests: 0`, `skippedTests: 6`, `passedTests`
consistent with 1,856 Swift Testing + 509 XCTest = 2,365 total, matching. 1,856 = the
1,851/291 post-merge baseline plus 5 new tests from Task 10
(`everyJurisdictionHasAFixture`, `cannotVerifyListIsExactlyWhatPhase4Shipped`,
`catalogueIsWellFormed`, `printCatalogue`, `knownButUnpinnedIsWellFormed`); 292 suites =
291 plus the one new `GoldenScenarioDefectCatalogueTests` suite. **0 failures.** No
`MultiYearPerfTests` flake occurred in this run (it is documented as a pre-existing wall-clock
flake under full-suite parallel load in several batch reports; this run did not hit it, so
there was nothing to re-run in isolation or explain away).

## Production diff (Step 7)

```
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 diff --stat main -- RetireSmartIRA/
```

Empty. Confirmed after all of Phase 4's work, tasks 1 through 10. Not one line of
`StateTaxData.swift`, `TaxCalculationEngine.swift`, or any `Resources/StateTaxData/2026/*.json`
changed across the entire phase. Phase 4 corrected no tax value. `git status --short` on Task
10's own changes shows exactly two files: `RetireSmartIRATests/GoldenScenarioCoverageTests.swift`
(modified) and `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift` (new).

## Open items Phase 5 inherits

- **The 118-case catalogue above, grouped by tier**, is the direct input. Tier 1 (34 cases, 11
  states) is the audit's own priority ordering ("material, expressible in today's model") and
  the largest tier by case count after Tier 2's per-source wall.
- **Georgia's rate/deduction staleness, Utah's Taxpayer Tax Credit and rate staleness, and New
  Mexico's stale bracket schedule** hit every filer in those states, not just retirees, and are
  not retirement-exclusion work at all -- worth sequencing ahead of some Tier 1/2/3 items
  precisely because their blast radius is every user, not a subset. **Nebraska's stale standard
  deduction ($12,000 configured against the real $8,600), Oregon's miscalibrated brackets, and
  Indiana's unmodeled personal exemption belong in this same every-filer category** -- they sit
  in `unclassified`, which `printCatalogue` prints last, so they are easy to miss if this list is
  read as exhaustive. Add them to the early-sequencing set alongside GA/UT/NM.
- **Missouri's public-pension cap** is real and confirmed but has no pinned case. Before
  correcting it, either find a source for the 2026 maximum Social Security benefit (retry
  ssa.gov; check whether the 2026 MO-A form has published) or accept correcting it without a
  golden-case regression guard, and say so explicitly when it ships.
- **Oklahoma, Arkansas, South Carolina's stale base-computation values** (standard deduction,
  top rate, bracket table) are disclosed but unpinned. Fixing only the attribution flags these
  states' Tier 3 cases target will go green without making these states correct; do not read a
  green OK/AR/SC fixture as "Oklahoma/Arkansas/South Carolina is now correct."
- **North Carolina's Bailey mixed-vesting expressibility gap** needs a schema decision (a
  vesting-date field, or a way to distinguish two same-`planSource` rows), not a source. This
  is Phase 5 (or a schema-widening pass), not Phase 6.
- **Montana** waits on Montana DOR publishing the TY2026 indexed figure. Check again before
  each future release; there is nothing to build until then.
- **Washington's capital gains field gap** (`GoldenScenario` has no capital-gains field; the WA
  fixtures carry the gain amount in `otherOrdinaryIncome`, labeled explicitly as a schema
  workaround) is a real product gap independent of Phase 5/6: this app's own affluent-skewing
  audience is the exact population who would realize a WA capital gain large enough to matter,
  and the engine currently guarantees them $0 state tax regardless of gain size.
- **BLOCKER: `PlanSource` has no case for U.S. uniformed-services retired pay distinct from
  federal civilian service.** Not a nice-to-have. It is a hard prerequisite for Vermont, whose
  VT-1/VT-5 fixture pair cannot both be satisfied by any configuration without it (see Bucket 4
  below), and a correctness trap for Arizona (AZ-3), Idaho (ID-3), and Massachusetts (MA-4),
  where `federalCivilian` is used as an imprecise stand-in for military pay and a fix that
  treats `federalCivilian` uniformly will silently mis-handle whichever of the two populations
  it does not target. Four states affected: VT, AZ, ID, MA.
- **Michigan's exact TY2026 cap** ($65,897/$131,794 TY2025 figures were used as a floor;
  RAB 2026-1's own worked example states the 2026-indexed figure is not yet published) and
  **Maine's AGI-phaseout ramp shape** (threshold's existence confirmed; the exact reduction
  formula -- cliff vs. linear ramp -- was not found in the time available, and no Maine case in
  this fixture depends on it) are both open, narrower items worth a follow-up primary-source
  pass before Phase 5 ships either state's fix.
- **DataManager's mirror implementation of the exemption logic** (flagged in prior-phase
  memory as `datamanager-breakdown-mirror`) should be grepped for every new identifier Phase 5
  introduces while correcting any of the above, per that standing lesson.
- **No single vocabulary for "the engine happens to agree with the form despite the underlying
  defect."** Across batches this phase used at least three: "-- contrast/regression case" and
  "-- MATCH" in scenario `name` strings, "correct by coincidence" / "coincidentally correct" in
  `source` prose (AL case 1, IA case 2, RI's IRA case, WV case 4), and unlabeled clean passes
  with no marker at all. No downstream consequence found this phase -- every instance was
  readable in context -- but worth settling on one convention before Phase 5 adds more
  fixtures, so a future reader can grep for it reliably.

## Commit

```
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/ .claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): all 51 jurisdictions covered, defect catalogue closed"
```
