# State Tax Phase 4 SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-04-state-tax-phase4-golden-scenarios.md
Spec: docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md
Worktree: .worktrees/state-tax-phase4 (branch feature/state-tax-phase4), off main @ 6097430
Predecessor ledgers: .claude/memory/roadmap/2026-08-03-state-tax-phase3a-ledger.md and -phase3b-ledger.md. READ THEM.

## Baseline
main @ 6097430. Suite at branch point: 1,752 Swift Testing in 285 suites + 505 XCTest, 0 failures.

## Pre-flight plan review (controller, before Task 1)
Found one defect in the plan itself and fixed it at ed50c6f BEFORE dispatch: the fixture shape
invariant `federalAGI == sum(components)` would have FAILED New York's first fixture, where a
$20,000 excess is deliberate unrelated ordinary income documented only in that fixture's prose
`source` string. Verified against all five existing fixtures: NJ/PA/IL/MS and NY cases 2-4 hold the
equality; NY case 1 is the sole exception. Fix is a declared `otherOrdinaryIncome` field, so the
check stays an exact equality rather than being weakened to `>=`, which would have let the Phase 2
authoring artifact back in.

## Tasks
(none complete yet)

## CONTROLLER PROCESS RULE, learned the hard way on Task 1
I resumed a stalled implementer AND dispatched a replacement into the SAME worktree. Both ran
concurrently, both reached the identical PA mutation, both reverted it, and they raced to commit.
They converged on one commit (edfcccc) and nothing was lost, but that was luck, not design: two
agents mutating the same fixture and the same index could have committed a half-reverted probe.
RULE: one implementer per worktree at a time. If an implementer stalls, either resume it or replace
it, never both. Check output-file mtime to decide which, and treat the abandoned one as dead.

Second lesson from the same task: the plan's baseline test count was STALE. It cited 1,752 ST + 505
XCTest from the Phase 3b ledger, which was measured on the phase3b branch tip BEFORE the RMD spouse
attribution work merged. True baseline on this branch is 1,845 ST in 290 suites + 509 XCTest.
Verified by diffing test files across 16fd6a2..6097430: five new RMD test files, 1,835 insertions,
which accounts for the entire gap. The implementer noticed the discrepancy and explained it wrongly
(blamed the Display Audit Harness, which lives on an unmerged branch and is not here). Plan corrected.

## Tasks
Task 1: complete (commits edfcccc..32ba080, review clean on re-review).
  Two Important findings, BOTH plan-mandated, both fixed at 32ba080:
  (a) knownDefectMechanismRoundTrips tested Codable, not the mechanism. The two-branch pin
      decision this whole phase rests on had ZERO permanent coverage; only the reverted Step 7
      mutation ever exercised it. Fixed by hoisting a pure classify(actual:scenario:) returning
      a five-case GoldenComparison, switched over by the test loop and pinned directly by
      classifyCoversAllOutcomes. Proven by inverting a comparison inside classify.
  (b) the otherOrdinaryIncome doc comment claimed New York already used the field. No fixture
      did; Task 2 Step 2a is what adds it. A doc comment written one task ahead of itself reads
      as fact and is false until that task lands.
  Reviewer independently confirmed the defectAppearsFixed-before-pin ordering is correct case by
  case, including where a stale pin coincidentally equals the form value.
  Suite 1,845 ST in 290 suites + 509 XCTest, 0 failures. Production diff against main empty.
Task 2: complete (commits 26135cf..57e902a, review clean on re-review).
  Two Important findings, both fixed at 57e902a:
  (a) THE LOOPHOLE THAT MATTERED, and it sat on the invariant all 46 later fixtures depend on.
      A fixture with classifiedPensionSources PRESENT BUT EMPTY plus a nonzero pensionIncome
      defeated both new checks at once: noDoubleCountedPension guarded on !isEmpty so it skipped
      entirely, and federalAGIIsInternallyConsistent's `reduce(0) ... ?? pensionIncome` returned
      Optional(0), never nil, so the fallback never fired and pensionIncome vanished from the
      component sum. A fixture could assert a pension number playing no part in its own AGI and
      pass. Fixed by keying on presence rather than non-emptiness, plus a regression test proven
      to discriminate by restoring the old guard. The reviewer verified the extracted helpers are
      the SAME code path the invariants call, not a parallel reimplementation.
  (b) a doc comment named everyJurisdictionHasAFixture, which does not exist; Task 10 adds it.
  Also corrected: the pilot doc comment cited StateTaxData.swift:2069 as CURRENTLY returning
  California for any unknown state. That fallback is GONE. config(for:) is now at :2290-2298 and
  ends in preconditionFailure; removing it was Phase 2's stated deliverable. THE SPEC'S SECTION 1
  IS STALE ON THIS POINT TOO and should not be re-derived from. Plan's Task 4 rationale corrected.
  Minor left open for the final review to triage: GoldenScenarioCoverageTests.swift:44-46, the
  pensionComponent doc comment attributes noDoubleCountedPension's testability to the wrong helper.
  Suite 1,850 ST in 291 suites + 509 XCTest, 0 failures, 6 skipped (pre-existing env-gated harness).
Task 3: complete (commits d9445c8..683b675, one Important finding, fixed).
  8/8 no-tax jurisdictions pass at $0 with no knownDefect. The harness scales from 5 to 13 fixtures.
  ** THE REVIEW EARNED ITS KEEP AND FOUND THE EXACT DEFECT CLASS THIS PHASE EXISTS FOR. **
  Wyoming's source cited Slide 4 for text living on Slide 5 of the very PDF it links. URL right,
  document right, slide TITLE right, quoted words right, and a reader following it would still have
  found nothing supporting the claim. The reviewer downloaded and text-extracted the PDF to catch it;
  the fixer independently re-extracted it with pypdf before applying the change. Naming a document
  is not citing it.
  Re-review DELIBERATELY SKIPPED for the fix, and the reasoning is recorded rather than assumed: the
  change is one word in four comment strings, it cannot move a tax value (WY is $0 by construction),
  and the underlying fact was independently verified against the source PDF by two different agents.
  Reviewer also verified the Texas citation the hard way, rendering a JS SPA to reach the
  constitutional text, and it held up verbatim including the added-date parenthetical.
  NH trap handled correctly: HB 2 (2023), repeal effective 2025-01-01, so TY2026 is fully repealed;
  engine returns 0 via `case .noIncomeTax, .specialLimited` so no knownDefect was needed.
  Minor carried into the plan rather than fixed: all 8 fixtures share one income template. Fine for
  a no-threshold batch whose job was proving scale, NOT fine from Task 4 on, where every state has a
  threshold a case should straddle. Plan amended at the shared batch procedure.
  Suite 1,850 ST in 291 suites + 509 XCTest, 0 failures. Test count is FLAT because Swift Testing
  counts a parameterized test once regardless of argument count; the fixtures are proven bundled by
  fixtureLoads passing over all 13.
Task 4: complete (commits 74e08bf..11430ca, one CRITICAL finding, fixed before fan-out).
  CA and ND pass. NE, IN and OR carry 12 knownDefects between them, all tier "unclassified".
  ** THE FINDING THAT RESHAPES THE PHASE: "confirmed correct" was only ever true of ONE dimension. **
  The audit examined retirement exclusions and nothing else. All five of these states ARE correct on
  that dimension. What Phase 4 found instead is stale standard deductions, stale bracket thresholds,
  and missing credits: NE's $171 credit, IN's $1,000/$2,000 personal exemption, OR's $256 credit.
  Every IN discrepancy is exactly `exemption x 0.0295`, which is what makes the diagnosis a mechanism
  rather than a coincidence. Expect the final catalogue to run well past the audit's predicted 29.
  ** CRITICAL, AND IT WOULD HAVE POISONED ALL FOUR PARALLEL BATCHES. ** ND forced the harness to
  implement the .conformsToFederal branch, which had been hardcoded to 0. The implementer used the
  BASE federal standard deduction and argued the age-65 addition and OBBBA senior bonus "depend on a
  live DataManager this static helper doesn't have." Both halves of that are false: the age addition
  is a pure function of the fixture's ages against constants the helper already reads, and the bonus
  is computable EXACTLY from federalAGI, because the shape invariant makes federalAGI definitionally
  equal to production's scenarioGrossIncome for any composition the schema can express.
  Nine states use .conformsToFederal (AZ CO ID IA MO MT ND NM SC). Only ND had a fixture, and only
  because all four of its cases keep filers under 65 was the gap inert. The other eight are spread
  across every parallel batch and most have age-gated exclusions, so the four-case matrix REQUIRES a
  65+ case for them. The harness would have under-deducted $2,050 single to $15,300 MFJ, computed a
  higher tax than production, and each author would have recorded a knownDefect that was a pure
  harness artifact. Fixed at 11430ca, proven inert across all 18 existing fixtures, and proven to
  discriminate (new 65+ test fails pre-fix at 105.7875, passes post-fix at 0.00).
  Also fixed: OR cited page 17 for text on page 32 (the Wyoming defect class, second occurrence).
  ** A WebFetch 403 IS OFTEN A TOOL ARTIFACT, NOT A SITE BLOCK. ** CA's figures had been confirmed
  against taxformfinder mirrors because ftb.ca.gov 403'd WebFetch. Plain curl reached the official
  page immediately, and checking the real document caught a typo ($504,406 -> $504,411). This lesson
  is now in every downstream batch dispatch.
  Re-review of the fix deliberately skipped: the fixer supplied exactly the evidence a reviewer would
  demand (inertness across 18 fixtures, a discriminating test, independent PDF extraction for OR, and
  an official-source fetch for CA), and the fan-out was the critical path.

## PARALLEL FAN-OUT, launched 2026-08-04 at John's direction
Tasks 5-9 run SIMULTANEOUSLY in five worktrees off 11430ca, branches feature/state-tax-phase4-b{5..9}:
  b5 CO KY GA MO | b6 IA MI CT VA WI AL RI ME MT MD | b7 KS MA HI AZ NC ID VT DC
  b8 OK DE LA AR SC WV | b9 OH UT NM WA MN
Fixture files are disjoint. The ONLY expected merge conflict is GoldenScenarioCoverageTests.covered,
one line, which the controller resolves. Each batch still gets its own citation-verifying review.
Task 5's role as a gate for 6-9 is FORFEITED by parallelising; John accepted that knowingly, and the
per-batch reviews remain the net.

## A TRAP IN HOW A GREEN SUITE READS, caught in batch 7's interim status
Batch 7 wrote that a passing run meant "every hand-derived expectedStateTax AND every
knownDefect.observedToday matched the actual engine output exactly." That is backwards for half the
cases and it would misrepresent the deliverable if it reached a report.
For a scenario WITHOUT a knownDefect, a pass means the engine matches expectedStateTax.
For a scenario WITH one, a pass means the engine matches observedToday AND DELIBERATELY DOES NOT
match expectedStateTax. The second assertion is what makes the pin self-cleaning.
So "all tests pass" never means "all my numbers agree with the engine". It means every jurisdiction
either agrees with its own published form or disagrees with it in the exact, measured, catalogued way
the fixture says it does. Task 10's catalogue comparison must be written from that reading, and any
batch report claiming engine agreement on a knownDefect case has misdescribed its own findings.

## Batch results as they land (reviews dispatched separately, verdicts appended later)
b5 CO KY GA MO: commit 18c1997, 16 scenarios, all green. ALL FOUR "confirmed correct" states carry
  defects, every one outside the audit's dimension. CO and KY pool a couple's pension into ONE
  household cap instead of two per-spouse caps. MO codes the private pension/IRA exemption as
  unlimited against a real $6,000-per-taxpayer cap with a phase-out. GEORGIA'S RATE IS THE BIG ONE:
  5.39% configured against a claimed 4.99% in law, which is not a retiree defect at all but hits
  every Georgia filer. Disclosed weaknesses: MO's 2026 SSA max benefit sourced secondarily (ssa.gov
  403'd BOTH WebFetch and curl), and GA's HB463 bill attribution rests on converging secondary
  sources though the dollar figures come from GA DOR directly.
b7 KS MA HI AZ NC ID VT DC: commit 062b861, 39 scenarios, 32 defects and 7 clean CONTRAST cases.
  Carries Steve Nicolai's Kansas scenario. ** THE AUDIT WAS FALSIFIED IN THREE PLACES, which is the
  single-source warning coming true: ** Arizona is richer than described (per-spouse cap doubling
  plus a separate uncapped military exclusion), Vermont likewise under 2025 Act 71, and DC's
  described rule is EXPIRED LAW that sunset in 2015. My brief repeated the audit's description of
  DC verbatim, so the brief shipped expired law to an implementer who caught it. Treat every
  remaining audit description as a hypothesis.
  NC CANNOT_VERIFY is narrow and correctly drawn: expressibility only, because Bailey is a
  vesting-date rule and the model has no vesting-date field. Law clear, model cannot carry it. NC
  stays in covered with its other four cases pinned.
b8 OK DE LA AR SC WV: commit 4addccb, 24 scenarios, 6/6 defective, confirming the tier's thesis.
  Also found OK's standard deduction configured at MORE THAN DOUBLE the real figure
  ($13,550/$27,100 against $6,350/$12,700) plus stale top rates in OK, AR and SC, all DISCLOSED BUT
  NOT PINNED so as not to conflate unrelated defects in one case. Reviewer asked to rule on that
  trade: an unpinned defect is one Phase 5 may never act on.
  ** OPEN QUESTION FOR ITS REVIEW: ** the report says it computed all 24 values with a Python script
  mirroring the engine's own progressiveTax algorithm and got ZERO deltas against engine output. If
  that produced observedToday, fine. If it produced expectedStateTax, the batch is CIRCULAR and
  worthless, because expected values must come from each state's published form. Exact agreement on
  all 24 while claiming all six states are defective is a tension that must be reconciled explicitly.

## THE MOST IMPORTANT RESULT OF THE PHASE SO FAR: a fabricated citation, caught
Batch 7's Hawaii HI-2 case quoted a sentence as verbatim source text and attributed it to pages 1-2
of schj_i.pdf. The reviewer downloaded the document, extracted it, and searched: it is 3 pages and
THE SENTENCE APPEARS NOWHERE IN IT. Searches for "deferred compensation", "individual investment",
"returns from" and "elective" all returned zero matches for the quoted language.
Worse than it first appears: HI-2 is a CLEAN case with no knownDefect. For a clean case the citation
is the ONLY thing a reader can check, because there is no measured engine disagreement to fall back
on. A reader following that citation to verify the case finds nothing at all.
This is the exact defect the phase's citation discipline was designed to catch, and the design caught
it. It is also the strongest possible argument for the process control in spec 3.4: no test could
have found this, the value was defensible, and every suite was green.
The fix dispatch asks for a DIAGNOSIS of how the sentence got there, not just a correction, because
knowing which step failed (memory substituted for the document, or a different source misattributed)
is worth more than the patch.

## THE RECURRING DEFECT CLASS OF THIS PHASE, now measured across five batches
Wrong-location citations, where the document is right and the place inside it is wrong:
  b3 Wyoming: Slide 4 cited for text on Slide 5.
  b4 Oregon: page 17 cited for text on page 32.
  b5 Georgia: the load-bearing tier amounts come from IT-511 p21, never used as sourceURL at all.
  b8: SIX wrong-page citations across OK, AR, DE and WV.
  b7 Hawaii: the terminal case of the same disease, a quote with no location because it has no source.
Every one was found by a reviewer opening the document and extracting it page by page. NONE was
findable from the diff, and none would have failed a test. Corollary for Phase 5 and beyond: a
citation is not verified by its presence, its URL resolving, or its values being right.
STRUCTURAL CAUSE worth fixing in a later phase: the schema has ONE sourceURL but a source string
often quotes two or three documents, so the load-bearing clause frequently ends up unlinked. Interim
rule now applied in all fix dispatches: sourceURL points at the document supporting the clause the
expectedStateTax turns on, and every other document quoted carries its full https URL inline.

## A TRAP FOR PHASE 5, surfaced by the b8 review and escalated
b8 computed expectedStateTax against the app's CONFIGURED brackets and standard deductions in the
very states where it separately flagged those configured values as WRONG (OK's standard deduction is
configured at more than double the real figure; OK, AR and SC carry stale top rates). The isolation
reasoning is defensible, but the consequence was undocumented: when Phase 5 fixes Oklahoma's
per-person flag, the golden case goes GREEN while Oklahoma remains substantially wrong for every
filer. A green test would then assert correctness that does not exist. Fix dispatch requires this
stated in the fixture itself where a Phase 5 implementer cannot miss it.
b9 OH UT NM WA MN: commit f794548, 25 scenarios, 23 defects, 2 pass. More audit falsification:
  UT's brief-cited $54k/$90k thresholds belong to a DIFFERENT credit than the one named, and UT's
  real dominant gap is a previously unidentified Taxpayer Tax Credit plus a stale 4.55%-vs-4.45%
  rate. NM's ENTIRE BRACKET SCHEDULE is stale pre-HB252 (2024 law), independent of the age
  exemption, so it hits every NM filer not just retirees. OH has a $332 base-amount quirk under
  H.B. 96 the engine omits. MN, never audited by anything, came back with brackets and standard
  deduction CORRECT: the only "the prior was fine here" result in the phase, and it needs the same
  scrutiny as a defect claim, because a state wrongly declared correct is one Phase 5 never revisits.
  WA needed a schema-limitation writeup: GoldenScenario has NO capital-gains field, and WA's tax is
  a capital gains tax. One WA case "matched by coincidence" and coincidental matches must be named
  in the fixture or a later reader reads them as evidence of correctness.
  Two disclosed source substitutions: NM's PIT-1 instructions 404'd so enacted bill text was used
  (arguably stronger, not weaker), and MN's M1QPEN figures came from a Dec 2025 DOR summary because
  the 2026 form 404'd.
b6 IA MI CT VA WI AL RI ME MD: commit 194b921, 42 scenarios, 14 pass / 28 tier1 defects.
  MONTANA IS CANNOT_VERIFY AND EXCLUDED FROM covered: mechanism confirmed (a flat age-65 subtraction
  replaced the old income-gated deduction) but the exact TY2026 indexed figure is unpublished. That
  is the phase's rule working as intended rather than a gap.
  ** THE AUDIT'S FRAMING WAS WRONG ON DIRECTION, which matters because Phase 5 was told to prioritise
  by error direction. ** Virginia and Connecticut are wrong in BOTH directions, not uniformly
  overstating: VA's missing per-spouse cap doubling UNDERSTATES while its missing age gate and AGI
  phase-out OVERSTATE; CT's IRA side overstates while its pension side understates.
  Rhode Island's IRA side is COINCIDENTALLY correct (real law also denies IRAs). Iowa's and Rhode
  Island's "MFJ one spouse qualifies" cases pass today ONLY because those states currently exclude
  nothing at all, so those passes may be vacuous; Maine's and Maryland's analogous cases already fail
  because their exclusions are active but age-blind.
  Disclosed weakness: Maryland's TY2026 figure ($41,200 verified vs the audit's $40,600) sits behind
  a JS-rendered Comptroller portal neither curl nor WebFetch could execute. Claimed robust to the
  $600 ambiguity; the review is verifying that claim rather than accepting it.

## ALL 51 JURISDICTIONS NOW HAVE FIXTURES except Montana (CANNOT_VERIFY, by design).
Totals across the five parallel batches: 172 scenarios written on top of the 20 from tasks 3 and 4.

b8 FIXES: commit 6d38e9a. Six wrong-page citations corrected, Delaware's bracket table given a real
  Division of Revenue citation, and the PHASE 5 WARNING added to OK, AR and SC.
  ** THE FIXER CAUGHT TWO ERRORS THAT ORIGINATED IN THE REVIEW AND THAT I THEN PROPAGATED VERBATIM
  INTO ITS INSTRUCTIONS, and it verified rather than complying: **
  (a) I told it to add the Phase 5 warning to Delaware and West Virginia too. DE's standard deduction
      and brackets were independently confirmed CORRECT, so the warning would have been false there.
      It scoped the change to OK, AR and SC only.
  (b) I told it South Carolina's booklet is internally inconsistent between "lines 35 through 48" and
      "lines 35 to 46". It extracted SC's instructions and found NEITHER phrase anywhere. The
      inconsistency is real but lives in WEST VIRGINIA's booklet; the reviewer had conflated the two
      because the WV citation context was pages 27 and 28. It put the accurate note in the WV fixture
      and documented the misattribution explicitly instead of silently redirecting it or adding a
      false note to SC because an instruction said so.
  LESSON FOR THE CONTROLLER: I forwarded reviewer findings into fix dispatches without re-verifying
  them. A reviewer's finding is evidence, not fact, exactly like an implementer's report. Two of the
  findings I passed on were wrong, and only the fixer's refusal to comply blindly kept a false
  statement out of a fixture. Re-verify a finding before instructing a fix on it, or at minimum
  instruct the fixer to verify first, which is what saved this one.

b9 REVIEW: APPROVED. Reviewer re-fetched every source and re-derived the figures independently, and
  all four beyond-the-brief corrections held. Three Important citation-location fixes dispatched.
  ** TWO FINDINGS HERE ARE BIGGER THAN THE RETIREMENT DIMENSION THAT PROMPTED THIS WHOLE PROGRAM: **
  UTAH: the engine carries 4.55%. Enrolled S.B. 60 cuts the rate from 4.5% to 4.45%. So the engine is
    stale against even the PRE-cut rate, meaning Utah has been wrong for longer than one legislative
    session, and it is wrong for EVERY Utah filer rather than only retirees. Verified from the
    enrolled bill text and the engine JSON directly, both read by the reviewer.
  NEW MEXICO: the engine's single and married bracket arrays are the OLD, DELETED pre-HB252 table
    VERBATIM. HB252 was signed 2024-03-06, Chapter 67. A two-year-old enacted bracket change was
    never applied, and again it hits every NM filer.
  Neither state's problem is a retirement exemption. The audit that started this program looked only
  at retirement exemptions, so neither was findable by it. This is the strongest evidence yet that
  the thirteen unaudited config dimensions matter more than the one that was audited.
  MINNESOTA confirmed genuinely correct on brackets and standard deduction, verified line by line
  against a dated MN DOR TY2026 publication rather than inferred from the audit's silence. Its only
  gaps are the SS subtraction, the public pension subtraction and the aged addition, all confirmed
  absent in the engine JSON.
  WASHINGTON's schema-limitation handling was judged a model of flag-rather-than-hide: the
  coincidental $0 match is labelled COINCIDENTAL inside the fixture, so a later reader cannot mistake
  it for agreement.

## THE DIAGNOSIS OF THE FABRICATED CITATION, in the implementer's own words
b7 FIXES: commit 3afd4bb. It re-fetched schj_i.pdf, confirmed 3 pages against pdfinfo, and confirmed
the quoted sentence appears nowhere. Its account of HOW:
  "not a misattributed quote from a different document, but generic domain-memory boilerplate about
   deferred-comp taxation written to match a conclusion I already believed, rather than derived from
   the source."
THAT IS THE MECHANISM, and it is worth more than the fix. Not a citation copied from the wrong place.
A plausible-sounding sentence composed from prior knowledge to support a conclusion already held, then
presented in quotation marks with a page range. Hawaii's REAL rule ("The pension exclusion applies
only to amounts attributable to employer contributions") is genuinely on page 2 of that same document
and fully supports the same conclusion, so the ANSWER was right the whole time. Only the evidence was
invented. That is precisely why no test could catch it and why a reviewer opening the document is the
only control that works.
Generalisation for every later phase: the risk is highest exactly when you already know the answer.
A citation written to justify a conclusion is not a citation, and confidence in the conclusion is the
warning sign rather than the reassurance.
Also fixed in the same pass: KS-6 kept as a deliberate COMBINED case but renamed and re-summarised to
state it needs BOTH Kansas fixes, showing the arithmetic for each single-fix outcome ($871.52 and
$1,218.88, neither of which is the expected $0.00) and naming KS-1/KS-2 and KS-3/KS-4/KS-5 as the
single-mechanism cases, so a Phase 5 implementer cannot mistake a still-red KS-6 for a failed fix.
KS-3/KS-4's "enumerates ONLY four categories" overclaim reworded; page 12 lists about twelve.
PAGE-COUNT OFF-BY-ONE DIAGNOSED AND REPRODUCIBLE: splitting pdftotext output on form-feed yields one
extra empty trailing chunk versus pdfinfo's true count. That explains the same off-by-one in several
batches' reports and is worth knowing for Phases 5 to 7.
HAWAII IS FLAGGED FOR THE FINAL WHOLE-BRANCH REVIEW to re-verify independently, since a same-agent
fix to its own fabrication is the one correction in this phase that most deserves a second pair of eyes.

b5 FIXES: commit 7786717. All seven findings applied. GA's sourceURL moved to the IT-511 PDF with
  page 21 re-confirmed by extraction across all five GA scenarios, the dangling cross-reference
  deleted, HB 463 resolved to the Governor's own press release (fetched and quoted directly, so the
  "residual uncertainty" framing is gone), CO's SB25-136 disposition added inline, KY's rate and
  deduction citations corrected with the Schedule P and Form 740 URLs inlined, and one middle-tier
  scenario added each to CO (age 60, clean pass at $611.60) and GA (age 63, $499.00 expected against
  a measured $700.70).
  ** CANNOT_VERIFY EXERCISED PROPERLY, AND IT COST SOMETHING. ** Missouri's case depended on the 2026
  Social Security maximum benefit of $49,824. The fixer tried the Federal Register (fetched the real
  2026 COLA notice; it does not carry this figure), SSA press releases, factsheets and OACT pages
  (all 403), CRS Report 94-803 (does not carry it), Missouri's own 2026 MO-A form (not yet published)
  and the Wayback Machine (no snapshot). No official source states the figure, so the scenario was
  marked CANNOT_VERIFY and REMOVED rather than shipped on a news article. Missouri now has 3
  scenarios, down from 4.
  ** THE HONEST COST, WHICH MUST REACH THE TASK 10 CATALOGUE: Missouri's public-pension-cap defect is
  REAL (the engine codes a .full exemption against a real cap linked to each individual's maximum
  Social Security benefit) and now has NO golden case pinning it. ** A real defect with no pinned
  case is exactly the "Phase 5 may never act on it" problem. It must appear in the catalogue as a
  known-but-unpinned defect blocked on source availability, not vanish because its fixture was
  removed. Revisit when ssa.gov is reachable or the 2026 MO-A publishes.

## THREE DISTINCT CITATION FAILURE MODES, now separable, all invisible to tests
The b6 review completes the taxonomy. These are different diseases needing different controls:
  1. RIGHT DOCUMENT, WRONG LOCATION. Wyoming slide 4-for-5, Oregon page 17-for-32, six in b8, two in
     b9, Connecticut page 24-for-25. Control: extract page by page and check the printed footer.
  2. INVENTED TEXT. Hawaii's quote that exists in no document, and now Michigan case 1's "'N/A' row
     of the RAB's own phase-in table" where the reviewer checked all four HTML tables and found no
     such table and no "N/A" anywhere. In BOTH cases the underlying CLAIM was true and supported by
     other real text in the same document. Control: search for the quoted sentence, never assume it
     is present.
  3. RIGHT DOCUMENT, WRONG EDITION. New with Maryland. The implementer "personally verified" $41,200
     against Worksheet 13A, but `pdfinfo` shows that PDF's embedded title is "2025 Pension Exclusion
     Computation Worksheet 13A". So the figure was verified against a real, correct, authoritative
     document from the WRONG TAX YEAR, and it is consistent with rather than contradicting the claim
     that TY2026 dropped to $40,600. There is currently NO primary-source confirmation of EITHER
     candidate figure for TY2026. Control: check the document's own year metadata, not just its
     content. A citation can be genuine, accurate, and still be about a different year.
  Mode 3 is the most dangerous of the three, because every existing control passes it: the URL
  resolves, the document is official, the quote is verbatim, and the page is right.
  ALSO: the Maryland fixture's "robust to the $600 ambiguity" claim was FALSE for scenario 2. The
  reviewer recomputed under $40,600 and got $234.88 against the asserted $206.38, a $28.50 swing.
  Robust as to the defect's EXISTENCE and DIRECTION, not as to the dollar value asserted. Scenarios
  1, 3 and 4 are genuinely robust and were verified as such.

b9 FIXES: commit 35a95f8. All four findings verified BEFORE applying, and the verification paid off
  three ways:
  (a) It found a FOURTH instance of the PIT-ADJ page error (Case E) that the reviewer missed. The
      reviewer named B, C and D.
  (b) On Utah it did NOT adopt the reviewer's reconstruction of why the OBBBA senior bonus is
      excluded. It verified independently via the TC-40 instructions and IRS Schedule 1-A that the
      OBBBA senior deduction flows to Form 1040 line 13b, while Utah's Line 12 pulls from line 12e.
      The reconstruction happened to be right, but it was confirmed rather than trusted.
  (c) Finding 4 was MISLOCATED IN MY DISPATCH: I said the Washington causal overstatement was in the
      report; it is in the WA fixture's source string and the report never made the claim. It fixed
      the real location.
  That is the THIRD time a fixer has caught an error in what I forwarded (b8 twice, b9 once). The
  pattern is now unambiguous and the instruction to verify before complying is what catches it every
  time. Keep that instruction in every fix dispatch for Phases 5 to 7.
  Self-caught during the work: an edit introduced unescaped double quotes breaking WA's JSON, and an
  em dash in its own report prose. Both found by its own verification pass before commit.

## MERGE PLAN, once b6 fixes land
All five batch branches are off 11430ca and touch disjoint fixture files. The ONLY expected conflict
is GoldenScenarioCoverageTests.covered, one line per branch. Merge b5, b6, b7, b8, b9 into
feature/state-tax-phase4 in that order, resolving `covered` to the UNION each time, then verify:
  - covered contains exactly 50 abbreviations (51 jurisdictions minus Montana, CANNOT_VERIFY)
  - the fixture file count matches
  - the full suite is green on the merged branch, which no single batch could prove
Then Task 10: flip completeness on, build the defect catalogue, compare it against the audit's
predictions, and write the ledger.

## MERGE COMPLETE
All five batch branches merged into feature/state-tax-phase4. Four conflicts, all on the single
`covered` line, all resolved to the union. Result: 50 fixture files, 50 abbreviations in `covered`,
Montana correctly absent as CANNOT_VERIFY.
** FULL SUITE GREEN ON THE MERGED BRANCH: 1,851 Swift Testing in 291 suites, TEST SUCCEEDED. **
That is the assertion no individual batch could make, since each only ever proved its own states
alongside the 18 that predated it.
NOTE FOR TASK 10: the plan's Step 1 flips completeness to a full USState.allCases sweep, which would
FAIL on Montana. Montana's absence is a DELIBERATE, reviewed CANNOT_VERIFY, not an oversight, so the
completeness test must carry an explicit, documented exclusion list rather than being weakened. An
unverifiable jurisdiction has to be visibly unverifiable, which is exactly what spec 3.5 requires of
the disclosure UI in Phase 6.

## FINAL WHOLE-BRANCH REVIEW: agent hit the session limit mid-run, controller ran the checks directly
The dispatched reviewer died on an API session limit. Rather than block, I ran its checklist myself.
All INVALIDATING checks pass:
  1. NO production change in ANY of the 28 commits, checked commit by commit rather than only at the
     tip. The phase's central promise holds across its whole history.
  2. ZERO circularity violations. No defect case has expectedStateTax equal to observedToday, which
     is the tell for an expected value derived from the engine rather than a published form. This was
     the one defect that would have invalidated the entire phase.
  3. ZERO em dash characters across the whole branch diff.
HARNESS verified line by line against DataManager.standardDeductionAmount (:1735-1775): base
  deduction, age-65 addition once per qualifying person, and the OBBBA bonus reduced PER PERSON then
  summed (IRC 151(d)(5)(B)), same thresholds and rate. federalAGI as MAGI is documented as exact
  rather than approximate, with the reasoning given. Structurally identical to production.
SELF-CLEANING PIN verified: classify() checks defectAppearsFixed BEFORE the pin, so a state corrected
  in Phase 5 fails with "delete the knownDefect block" rather than the less useful "the pin moved".
MONTANA verified as visibly excluded, not silently: a structured `cannotVerify` list with per-entry
  reasons, a completeness test that still fails for any OTHER missing jurisdiction, and a separate
  test pinning the list to exactly ["MT"] so it cannot silently grow. It is data a Phase 6 disclosure
  UI can read, which is what spec 3.5 needs.
HAWAII INDEPENDENTLY RE-VERIFIED BY ME, since a same-agent fix to its own fabrication was the single
  correction most deserving outside eyes. Downloaded schj_i.pdf, confirmed 3 pages, and confirmed the
  replacement quote ("The pension exclusion applies only to amounts attributable to employer
  contributions") is genuinely present with the "SCHEDULE J ... PAGE 2" marker immediately preceding
  it. An exact-string search MISSED it and a whitespace-normalised search found it: the difference is
  pdftotext line wrapping. Worth knowing, because an exact-match check alone would have wrongly
  condemned a good citation, which is the false-positive twin of the fabrication it replaced.
STILL OWED: the cross-batch consistency pass and the Phase 5 consumability judgement, which are the
  two things a whole-branch reviewer sees that I cannot check mechanically. Re-dispatch after the
  session limit resets, BEFORE merging to main.

## FINAL REVIEW FIXES: agent hit the session limit again; controller verified and committed
The fix agent made all 13 edits, then died before testing or committing. Its report file was never
written. I verified its work directly rather than re-dispatching:
  - PARSED every fixture before and after: ZERO changes to expectedStateTax, observedToday, or
    knownDefect presence across all 50 files. The edits are documentation only, as required. A naive
    grep suggested otherwise, but those matches were prose mentions of the field names INSIDE summary
    strings, not field changes. Worth remembering: on this branch, grep for a field name hits the
    prose too, because the summaries now discuss the fields by name.
  - Production diff against main still EMPTY. Zero em dashes.
  - Spot-checked all three Critical fixes landed: VT and DC each disclose that the file cannot be
    satisfied by any configuration until PlanSource gains a uniformed-services case (VT) and
    ClassifiedPensionSource gains a survivor flag (DC); ID and AZ now carry the PHASE 5 WARNING;
    NC's dangling reference is gone.
  - FULL SUITE GREEN: 1,856 Swift Testing in 292 suites, 509 XCTest, 0 failures. TEST SUCCEEDED.
  - Committed b00b557. Working tree clean.
No re-review dispatched: the edits are prose, provably moved no value, and the suite is green. That
is a proportionality call, recorded rather than assumed.

## PHASE 4 IS COMPLETE. Branch feature/state-tax-phase4 @ b00b557, ready to merge to main.
