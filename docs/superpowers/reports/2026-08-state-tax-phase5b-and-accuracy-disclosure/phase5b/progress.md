# State Tax Phase 5b SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md
Predecessor ledgers, both durable and both worth reading before starting:
  .claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md  (the catalogue and its traps)
  .claude/memory/roadmap/2026-08-04-state-tax-phase5a-ledger.md (the corrections method)
Worktree: .worktrees/state-tax-phase5b (branch feature/state-tax-phase5b), off main @ c5a7bce

## Baseline
1,857 Swift Testing in 293 suites + 509 XCTest, 0 failures, 6 pre-existing env-gated skips.
Phase 5a closed at 99 defect cases across 32 jurisdictions. This phase targets 29 of them.

## WHAT IS DIFFERENT ABOUT THIS PHASE
5a was config-only and its confinement rule was "nothing but JSON." THAT RULE IS GONE. 5b changes
Swift. What replaces it: every Swift change must be an ADDITIVE model extension, provably inert until
a config opts into it. Task 1's gate is that proof, and New York is the canary, being the only state
shipping perSourceExemptions today.

## THE FINDING THIS PHASE IS BUILT AROUND
Kansas labels KPERS, its OWN retirement system, as `otherStateOrLocal`, whose doc comment at
RetirementPlanClassification.swift:40-43 says it "exists specifically to stop an out-of-state public
pension from selecting New York's exclusion." The label was forced because the model cannot say "this
state's own system."
So the obvious Kansas rule would (a) pass all three Kansas fixtures, (b) exempt a CALIFORNIA public
pension for a Kansas resident, which Kansas law does not do, and (c) be caught by NOTHING, because
Kansas has no out-of-state negative case the way New York does. Task 2 adds it.
That is the Phase 3b defect class reappearing in a different state. The same missing vocabulary is
what made Vermont (military vs CSRS) and DC (survivor vs own) unsatisfiable.

## Pre-flight plan review (controller, before Task 1)
Scanned for self-contradiction. One item worth naming rather than fixing: Task 2 MODIFIES golden
fixtures, which Phase 4 otherwise treats as frozen. That is deliberate and the plan justifies it
(those fixtures were written against a model that could not express their rules, and Phase 4 recorded
VT and DC as unsatisfiable for exactly that reason). A reviewer may flag it; the answer is in the task
text. No other conflicts found.

## Tasks
Task 9: complete (commit 5e81cf5). DC SHIPS ITS RULE. VERMONT IS STILL UNSATISFIABLE, and the plan
  named that in advance as the single most important finding of this phase.
  ** THE PLAN'S QUESTION, ANSWERED. ** For DC, Task 1's extension was the right axis and it works. For
  VERMONT it was NECESSARY AND NOT SUFFICIENT: the VT-1/VT-5 source collision really is gone, but the
  blocker was never only sources. Vermont needs TWO exclusions with different caps AND different AGI
  bands and a jurisdiction carries one pooled cap and one agiPhaseout; and its CSRS exclusion applies
  "only to benefits ... not covered by the Social Security Act", which federalCivilian cannot express
  because that case covers CSRS AND FERS. Task 1 extended the WHO axis; Vermont's remainder is on the
  HOW MUCH and WHEN axes.
  ** BOTH VERMONT SHAPES MEASURED, Hawaii's method, both reverted. ** The config-only CSRS shape
  (pooled .partial(10000) + agiPhaseout linear + two .none rules) turned VT-1, VT-2, VT-3 and VT-4 ALL
  GREEN at 742.03 / 1579.53 / 1316.55 / 981.55 with VT-5 and VT-6 still pinned. DECLINED on Hawaii's
  test: grant and limiter come out of the same quoted authority, the word "only" is in it, and the
  over-matched population (FERS, growing) is larger than the served one (CSRS, closed since 1984).
  The military .full rule turned VT-5 green and moved VT-6 off its pin to 0.00. VT-6 caught it exactly
  as the brief predicted. Vermont ships NO rule, all six defects STAY, plus a caption and
  Phase5bVermontDecisionTests (8 tests, with a reflective tripwire that re-opens Vermont if a second
  pooled cap or phase-out ever arrives).
  ** A THIRD SHAPE EXISTS AND IS RECOMMENDED TO JOHN, NOT SHIPPED. ** An income-gated military rule
  (matchMaxIncome sibling of matchMinAge) implements Act 71's quoted $125,000 sentence exactly: VT-5
  green, VT-6 correctly pinned, NO under-taxation anywhere, worth $4,525.15 a year. Not built because
  the gate would compare against the post-state-deduction income figure, so VT's config would carry
  $117,150 where Act 71 says $125,000, and NO VT FIXTURE PINS THE BASIS (VT-5 and VT-6 sit the same
  side under both readings). That is a program-level decision AGIPhaseout's own doc comment defers, not
  a jurisdiction one. Report section 1.4 gives the VT-7 fixture that would pin it: AGI $130,000,
  expected $172.53.
  ** DC: THE PHASE'S LARGEST PRODUCTION CHANGE, and the brief's chain was INCOMPLETE. ** matchMinAge
  had to be built too: the per-source partition is unconditional on age, so DC-1 (survivor at 55) fails
  without it, and perQualifyingSpouse cannot substitute because ownerQualifies returns true
  unconditionally for a single filer. It gates on the ROW OWNER's age, not the household maximum.
  Three blocks deleted whole, MEASURED: DC-2 1924.00 -> 0.00, DC-3 1546.00 -> 0.00, DC-4 3848.50 ->
  1846.00. DC-1 and DC-5 still pass. Added DC-6, the Maryland survivor annuity Task 2's reviewer said
  Task 9 owed DC, deliberately one enum case away from DC-2. NO baseline movement, so no ledger entry.
  ** DEVIATION FROM THE BRIEF, flagged for review: no field was added to IRAAccount. ** Nothing in
  production constructs a RetirementDistributionComponent (grep), so an account-level flag has no path
  to the matcher; IRAAccount already carries beneficiaryType; DC's rule is definedBenefit-only; and an
  unreachable PERSISTED field is dead data in every user's save file, which "provably inert until a
  config opts in" cannot cover. The field WAS added to RetirementDistributionComponent (in-memory).
  ** THE PICKER AFFORDANCE WAS MANDATORY. ** No sequence of user actions could set isSurvivorBenefit,
  so every DC case would have gone green while a real survivor annuitant got nothing: Task 3's Kansas
  failure exactly. A toggle now shows where live config consults the dimension
  (residenceUsesSurvivorDimension, never a hardcoded == .districtOfColumbia). The Bool-to-Bool? mapping
  is the careful part: question shown saves the answer, question not shown PRESERVES what the row had,
  so no editor ever stamps "not a survivor" on a question it did not ask.
  ** MIRROR VERIFIED BY MUTATION, then reverted. ** Passing a literal nil at the DataManager pension
  site produced 1924.00 vs 0.00 and exempt 0 vs 50000 for both named sources. Finding: the PRE-EXISTING
  StateTaxBreakdownTests.breakdownMatchesCalculation stayed GREEN through that mutation, because no
  existing test drives DC with a survivor row.
  ** IDAHO RE-OPENED, and Task 8's reflective tripwire is why. ** It fired on the first full-suite run,
  as designed. Re-measured: the age-gated military rule turns ID-3 green and moves nothing else, so TWO
  of Task 8's three objections are gone (the age gate, and household attribution, since matchMinAge is
  per owner). The decision SURVIVES on the third, the uncapped SS-reduced Line 8a maximum, and both
  over-exemptions are pinnable so Step 3 requires the catching cases first. Test renamed and re-pointed
  at the surviving blocker; the ID knownButUnpinned entry corrected, since half its "RESOLVE IT"
  sentence asked for an age gate that now exists.
  DC knownButUnpinned entry added WITH a non-vacuous deletion guard: a DC survivor whose row predates
  this task carries nil, gets no exclusion, and gets NO warning, because both disclosure surfaces gate
  on the pension being UNCLASSIFIED and this one is classified. Task 4's Phase 6 item in a new form.
  Step 7: DC on phase5CorrectedJurisdictions, NOT on layerAProvenDivergentJurisdictions, MEASURED as
  "None diverged" for TWO independent reasons (unclassified row, and no survivor flag). VT on neither.
  ** AWAITING JOHN: ** (1) the Vermont judgement call, ship Option B with a disclosed FERS gap or hold.
  Recommendation: HOLD, take Option D in Phase 6 instead, it is strictly better. (2) Three PROPOSED
  copy items: DC's disclosure sentence, DC's survivor toggle plus caption, and Vermont's caption.
  Suite 2,018 Swift Testing in 304 suites + 509 XCTest, 0 failures, 2,527 total. No MultiYearPerfTests
  flake on the committed run.

Task 5: complete (commits 60323d0..6b95834, review PASS, decision UPHELD). HAWAII SHIPS NO RULE.
  ** THE DELIVERABLE IS A DECISION, NOT A RULE, and the plan explicitly sanctioned that outcome. **
  Hawaii ships no perSourceExemptions, stays "disclosed, not modelled", all three knownDefect blocks
  STAY. No config file and no production Swift changed at all.
  ** THE METHOD IS THE PART WORTH COPYING. ** The implementer did not argue the rule was wrong, it
  MEASURED: temporarily shipped the declined rule (matchStructures ["definedBenefit"], empty
  matchSources), watched HI-1, HI-3 and HI-4 ALL GO GREEN at their published figures with NO fixture
  objecting, observed the same rule grants a full Hawaii exclusion to every contributory DB pension,
  then reverted. THE GREEN OUTCOME WAS AVAILABLE AND IT WAS WRONG. The reviewer reproduced the
  arithmetic independently ($266.00 and $2,107.20 both exact) and confirmed the revert was complete.
  Why Hawaii could not trade the way Massachusetts did: Schedule J's authorising sentence contains the
  word "only", so the exclusion and the over-match come out of THE SAME QUOTED SENTENCE. MA had an
  evidentiary asymmetry (quoted statute for the fixes, inference for the gap); Hawaii has none.
  Direction settles it: today's error is OVER-taxation, disclosed on two surfaces. The rule would have
  made it UNDISCLOSED UNDER-taxation at up to 11%, for the LARGER population (every contributory DB
  pensioner including CSRS and FERS), to help the shrinking set of noncontributory private DB retirees.
  ** THE AXIS QUESTION TASK 4 DEFERRED HERE IS ANSWERED: ** MA needs a CATEGORICAL contributory fact,
  HI needs a PROPORTION. A boolean serves MA and serves HI only at its two endpoints, and the wrong
  endpoint fails toward under-taxation.
  Step 3 is PROCEDURALLY UNSATISFIABLE for Hawaii: a contributory private-sector DB household writes
  (definedBenefit, privateEmployer), byte-identical to HI-1 with a contradictory expected value, so the
  plan's "ADD one" remedy cannot be performed. That forecloses shipping independent of judgement.
  ** THE REVIEW'S IMPORTANT FINDING, and it is the class this program exists to prevent. ** A test
  named theDeclinedRuleWouldHaveMatchedTheMigrationDefault asserted something FALSE and shipped it
  marked [MEASURED]. The real migration default is (unknown, unknown), and the declined rule carries
  matchStructures [definedBenefit], which does NOT match structure == .unknown, so not one migrated row
  would have claimed the exclusion. Deleted. Report section 3.2 is now a RETRACTION, not a quiet edit.
  Two brief corrections the implementer made and the reviewer verified: Hawaii's disclosure lives in
  TWO files not one and already had four tests (the "one file each, no test" claim holds for MA only);
  and HI-1's own proxy sentence is unsound on its own terms, glossing "noncontributory" as "no
  salary-deferral", which is a conflation that undercuts the fixture's stated justification.
  ** DECIDED BY JOHN 2026-08-05: the contributory axis is a PHASE 6 item ** and now has an owner, with
  the residence-relative ownStateOrLocal staleness and the input-surface-only disclosure.
  DO NOT read knownButUnpinned as saying Hawaii's proportion is unvalidatable. A golden fixture COULD
  stipulate the employer-funded share as an INPUT. The real obstacles are a model field, a picker
  affordance, and whether a user can supply a share Schedule J makes them compute from cost basis.
  Suite 1,948 Swift Testing in 299 suites + 509 XCTest, 0 failures.

Task 4: complete (commits 0bd68af..0a19cb8, review PASS, no Critical). MASSACHUSETTS IS NOT COMPLETE,
  and that is a deliberate, defended outcome rather than a shortfall. TWO DECISIONS AWAIT JOHN, below.
  Rule fixes three real defects: contributory MA state and local pensions and US military retired pay
  are excluded outright by MA law and the engine taxed them in full. Relabels: MA-1 and MA-3
  otherStateOrLocal -> ownStateOrLocal, MA-4 federalCivilian -> uniformedServices, each confirmed
  against the case's own quoted source rather than the brief's list.
  ** THE JUDGEMENT THE PLAN ASKED FOR, and it was answered NO. ** governmentUnspecified is a FORCED
  FIT: its own doc comment says "a government employer whose jurisdiction was not established", nothing
  about funding. MA-2 was therefore never a contributory guard, and it was renamed to the
  unestablished-jurisdiction guard it actually is (data byte-identical, adopting KS-8's vocabulary).
  Massachusetts genuinely needs a third EMPLOYEE-CONTRIBUTORY axis. It was NOT built, because the axis
  is not MA-only and designing it from four MA cases would foreclose Hawaii's Task 5.
  ** THE CONTRADICTION THAT PROVES THAT POINT, verified by the reviewer against HI's fixture: ** HI-1's
  source says definedBenefit represents an employer-funded NONCONTRIBUTORY pension; MA-1 says
  definedBenefit IS the contributory Commonwealth pension. TWO FIXTURES ON THIS BRANCH ASSIGN OPPOSITE
  FUNDING SEMANTICS TO THE SAME FIELD, and PlanStructure.definedBenefit's doc comment takes neither
  side. Task 5 (Hawaii) must resolve this, not inherit it.
  ** THE COST OF SHIPPING, disclosed not discovered: ** a noncontributory municipal retiree who picks
  the own-state picker row now gets $0.00 instead of $3,000.00. UNDER-taxation, reachable by a real
  user. No golden case can pin it: such a case would carry inputs BYTE-IDENTICAL to MA-1's with a
  contradictory expectedStateTax. That unavailability IS the finding. Recorded as a knownButUnpinned
  entry, a test that fails if the entry is deleted, and a caption directly under the picker.
  Guards went into SWIFT rather than golden cases, and the reviewer upheld it narrowly: MA's
  out-of-state treatment is conditional on RECIPROCITY, so a KS-7-style fixture would have asserted an
  unsourced legal claim. The Swift sweep derives from PlanSource.allCases, so a case added by a later
  task is rejected BY DEFAULT, which a golden case cannot do.
  Step 7: MA added to phase5CorrectedJurisdictions, NOT to layerAProvenDivergentJurisdictions, on
  Kansas's second reason only (that grid's pension row is unclassified). Reviewer read the grid and
  confirmed. Consequence recorded as a Minor: MA now has ZERO Layer A coverage.
  Implementer WITHDREW its own "the fixture self-contradicts on federalCivilian" framing on re-reading:
  the two strings are reconcilable and it is a plain confirmed under-match, so a MA CSRS or FERS
  retiree is over-taxed today. It did NOT widen the rule, because the only statement of those
  categories on this branch is a paraphrase in MA-2's prose, not a quoted primary source.
  ** AWAITING JOHN: ** (1) SHIP as-is or take the section 13 reversal. Reviewer and controller BOTH
  recommend SHIP: the three fixes rest on quoted affirmative rule text, the new gap rests on a
  closed-list INFERENCE the fixture itself flags as not verbatim, and reverting over-taxes the large
  majority (c. 32 systems are contributory by statute) to protect a small legacy category. Section 13
  now carries a COMPLETE six-item reversal recipe; the first version would have shipped a FALSE
  DISCLOSURE, since statetax-2026-MA.json line 42 would still promise an exclusion the app no longer
  applied and everyShippedSentenceIsWellFormed checks nothing semantic. (2) Two copy items, both
  shipped as PROPOSED: the disclosure sentence and the picker caption.
  ** ROUTED TO PHASE 6: ** the under-taxation warning is INPUT-SURFACE ONLY. State Comparison and, more
  seriously, the CPA BRIEFING handed to a preparer, present $0.00 with no caveat, because
  unclassifiedPensionDisclosure fires only for an UNCLASSIFIED pension and this user has classified.
  Also: both contributory captions (MA's and Hawaii's) are untestable, one file each, no test.
  Suite 1,938 Swift Testing in 298 suites + 509 XCTest, 0 failures, no flake on three full runs.

Task 3b: complete (commit 626199e, review APPROVED first round, 4 non-blocking Minors).
  NOT IN THE PLAN. A Task 3 reviewer finding John decided: the two unclassified-pension disclosures
  stop gating on New York and gate on live config, with the SENTENCE coming from each jurisdiction's
  own config. John approved option A wording, one string per jurisdiction, `{scope}` token swapping
  "this figure" (State Comparison) for "this plan" (CPA briefing).
  ** NEW YORK'S LIVE COPY PROVEN BYTE-IDENTICAL. ** Both shipped strings (250 and 248 chars) extracted
  mechanically from the PARENT commit, pinned as literals, asserted with full ==, then proven capable
  of failing by a reverted one-space mutation. The reviewer re-extracted them from 93d91c0 itself
  rather than from the current tree and recomposed both outside Swift. They did not move.
  The two surfaces gate on DIFFERENT things on purpose (State Comparison on the VIEWED state, the CPA
  briefing on RESIDENCE) and that is now structural: neither function has the other's parameter in
  scope, so no shared predicate exists that a later task could collapse.
  ** THE BRIEF WAS WRONG that nothing tested these surfaces. ** Seven tests existed and ALL SEVEN
  PASSED while Kansas got no warning, because each asserted only "NY fires, CA does not" and "the text
  is non-empty". Coverage written to the implementation's shape, not absent coverage. The replacement
  sweeps iterate USState.allCases and derive their subject from DATA, which is the structural fix.
  One unanticipated file: `configs2026Legacy` in StateTaxData.swift, New York only. Layer B requires
  NY's JSON and legacy entry to re-encode byte-identically since NY is not on
  phase5CorrectedJurisdictions, and that table is the live fallback when JSON fails to load, so
  omitting it would lose the warning in that path. Kansas needs no counterpart because it IS on the
  list and is required to diverge. Reviewer verified all three grounds and ran the Layer B gate.
  ** EVERY REMAINING JURISDICTION TASK NOW OWES A JOHN-APPROVED DISCLOSURE SENTENCE. **
  `rulesAndDisclosuresStayInLockstep` fails the suite if a task ships a rule without one. Reviewer
  confirmed it genuinely fires. TASK 10 MUST NOT DELETE OR SKIP THAT SWEEP: it is the only thing
  binding the two predicates together, and removing it silently reopens the Kansas defect for every
  later jurisdiction.
  Suite 1,924 Swift Testing in 297 suites + 509 XCTest. MultiYearPerfTests was the only failure, the
  documented pre-existing wall-clock flake; the wrapper re-ran it in isolation and it PASSED.

Task 3: complete (commits 44acf69..a2125f1, review clean over two rounds). KANSAS IS DONE.
  Rule: matchSources = ownStateOrLocal, federalCivilian, uniformedServices, railroadRetirement;
  matchStructures = definedBenefit; treatment full. Deliberately does NOT match otherStateOrLocal,
  governmentUnspecified, privateEmployer, individual, nyStateOrLocal, or `unknown`. That last one is
  the migration default on every pre-3b saved row and was the most expensive over-match available.
  Three knownDefect blocks deleted whole, MEASURED: KS-4 1432.31 -> 0.00, KS-5 1218.88 -> 0.00,
  KS-6 1218.88 -> 0.00. KS-6 was the deliberate COMBINED case and it resolved for exactly the reason
  its own summary PREDICTED, not coincidentally. The reviewer re-derived all three from the shipped
  config rather than from the report.
  KS-7 (the Task 2 California guard) and KS-3 never moved. The implementer ADDED KS-8, an
  unestablished-jurisdiction guard, because nothing caught governmentUnspecified. Reviewer confirmed
  both guards catch an over-match STRUCTURALLY, not merely that they pass.
  Step 7: Kansas stays ON phase5CorrectedJurisdictions, OFF layerAProvenDivergentJurisdictions,
  MEASURED by temporarily adding it and getting "None diverged". That grid's pension row is built
  unclassified and infers to unknown/unknown, which is also why no frozen baseline value could move.
  ** THE PLAN WAS WRONG THAT TASKS 3 TO 9 ARE CONFIG-SHAPED. ** Controller audit before dispatch found
  PlanClassificationChoice (IncomeSourcesView.swift:16), the enum driving the USER-FACING picker, is
  separate from PlanSource and had no option writing any of Task 1's three new cases. A correct Kansas
  rule would have turned every golden case green while a real KPERS holder got nothing. John chose to
  add all three picker options here, once, so Tasks 4, 6, 8 and 9 inherit them.
  Two live wrong numbers followed from that and BOTH are fixed: a NY retiree could pick the new
  own-state row and lose NY's uncapped exclusion for the capped $20,000 one; and a resident of any
  state could see another state's ownStateOrLocal exclusion on State Comparison. The implementer
  DISAGREED with the reviewer's "one fix closes both" and was upheld: suppression acts at
  CLASSIFICATION time, the comparison bug at COMPARISON time, and suppression must never fire for
  Vermont because the own-state row is correct for their actual residence.
  Suite 1,910 Swift Testing in 296 suites + 509 XCTest, 0 failures.

Task 2: complete (commits 8c58d28..e5acef4, review clean).
  Re-labelled three golden fixtures the old model forced into wrong cases, and added the Kansas
  out-of-state guard the phase was built around. Modifying golden fixtures is otherwise forbidden by
  Phase 4; it is justified here because these three were written against a model that could not express
  their rules, which is why Phase 4 recorded VT and DC as unsatisfiable.
  KS: three KPERS rows otherStateOrLocal -> ownStateOrLocal, plus a NEW seventh scenario, a Kansas
  resident holding a CALIFORNIA public pension, expected $1,432.31, NO knownDefect because the engine
  already agrees. That is the desired shape: it is a permanent guard that must keep passing after Task 3.
  Both the implementer and the reviewer re-derived $1,432.31 independently from the ip25.pdf citations
  the fixture already carried, never from engine output.
  VT: VT-5 and VT-6 -> uniformedServices. Identified from the Act 71 / MILITARY RETIREMENT WORKSHEET
  citations in name and source, not from the amounts, by implementer and reviewer independently.
  VT-1 through VT-4 are CSRS and were correctly left alone.
  DC: survivor flag set on the five survivor rows, INCLUDING DC-1 (age 55, fails the age gate). That
  was a judgement call and the reviewer endorsed it: DC-1 is factually a survivor benefit, and flagging
  it makes Task 9's age gate LOAD-BEARING, because a rule that forgets the gate then produces $0
  against DC-1's pinned $1,924. Leave it unflagged and that same broken rule stays green.
  ** CONTROLLER-AUTHORIZED SCOPE EXTENSION, beyond the plan's literal Task 2 text: ** DC's two
  otherStateOrLocal rows -> ownStateOrLocal. Reviewer endorsed. Without it, Task 9's DC rule would have
  had to name otherStateOrLocal, which would exempt a MARYLAND pension for a DC resident: the exact
  Kansas defect, knowingly shipped one jurisdiction over.
  ClassifiedPensionSource gained isSurvivorBenefit (TEST-ONLY fixture plumbing). Production consumption
  is still Task 9's. Established RED-first BY MEASUREMENT: before the schema change the key decoded and
  re-encoded as {planSource, amount, planStructure}, silently gone. Same silent-loss class as Task 1's
  Critical.
  ** NO PIN MOVED. ** Verified structurally as well as by suite: only statetax-2026-NY.json ships a
  perSourceExemptions key, and planSource reaches the computation only via matchedPerSourceRule, so
  re-labelling KS/VT/DC cannot change an output. Baselines/ untouched, no movement-ledger entry.
  Review: SPEC PASS both rounds. Round 1 gave 2 Important + 5 Minor, round 2 approved with 3 Minor.
  The Important that mattered: dcFixtureCarriesTheFlag pinned by COUNT, so swapping the flag between
  DC-1 and DC-5 (byte-identical rows, which is how the original bulk edit hit the wrong one) still
  passed 5-and-2. Now pinned by CASE IDENTITY, and BOTH the implementer and the reviewer verified it BY
  MUTATION rather than by reading, the reviewer reproducing the swap itself and reverting.
  The other Important: stale prose in AZ, ID, MA and NC still told the Task 4/6/7/8 implementers the
  enum lacks cases it now HAS. Corrected as prose only, rewritten to hand the relabel instruction
  forward rather than merely deleted. The implementer DISAGREED with that finding's scope and was
  right: NC disclosed nothing at all and within MA only scenarios 1 and 4 did, so the highest-risk rows
  were silent, which makes the finding worse rather than milder.
  Suite 1,885 Swift Testing in 295 suites + 509 XCTest, 0 failures, 2,394 total.

Task 1: complete (commits ebd2544..b0e23fe, one Critical finding, fixed).
  Added ownStateOrLocal, uniformedServices, railroadRetirement to PlanSource, plus a survivor flag.
  20 exclusivity tests proving BOTH directions for every new-versus-old pair, which is the whole
  point: a rule naming ownStateOrLocal must not match otherStateOrLocal, and the converse.
  Inertness confirmed: only the two model files changed, no baseline, no ledger, no fixture. New York,
  the only state shipping perSourceExemptions and therefore the canary, unmoved. matches() is
  byte-for-byte unchanged, so a rule written before this behaves identically after.
  ** THE CRITICAL FINDING, and it was worse than it first looked. ** The survivor flag shipped as
  `let isSurvivorBenefit: Bool? = nil`. The reviewer COMPILED that exact shape rather than reasoning
  about it and established three things by execution: the memberwise init REJECTS an argument for it
  ("extra argument in call"); the compiler warns the property "will not be decoded"; and decoding JSON
  that explicitly sets it true SUCCEEDS AND YIELDS NIL, with no error and no diagnostic.
  That last one is the serious part. Not merely useless, SILENTLY LOSSY. A later DC fixture setting
  that key would have decoded clean and lost the value with nothing to notice, which is precisely the
  silent-corruption class Phase 3b's decode-trap lesson exists to prevent.
  Fixed by let -> var, with the compile error captured as RED first. Kept Bool? rather than a plain
  Bool defaulting false, with reasoning worth keeping: a migrated federalCivilian record has genuinely
  never been ASKED whether it is a survivor benefit, so defaulting to false would assert "known not
  survivor" for an unanswered question. Same discipline the file already applies via
  PlanStructure.unknown and PlanSource.unknown.
  ** DOWNSTREAM CHAIN RECORDED FOR THE DC TASK, deliberately NOT built here: ** a field on IncomeSource
  and IRAAccount, matchIsSurvivorBenefit on PerSourceExemptionRule, a parameter on matches(), a
  pass-through in DataManager.matchedPerSourceRule, a field on the fixture type
  ClassifiedPensionSource, and a bridge in GoldenScenarioSingleYearTests.singleYearStateTax.
  Suite 1,880 Swift Testing in 294 suites + 509 XCTest, 0 failures.

## CARRIED FORWARD FROM TASK 2's REVIEW, deliberately NOT fixed in Task 2
These are for the final whole-branch review to triage and for the named tasks to act on.

1. ** ownStateOrLocal IS RESIDENCE-RELATIVE BUT STORED AS A STATIC LABEL. ** The enum carries no
   jurisdiction identity. A KPERS pension classified ownStateOrLocal while the user lived in Kansas
   KEEPS that label after a move to DC, where a Task 9 rule matching ownStateOrLocal plus the survivor
   flag would then exempt income DC does not exempt. This is a property of Task 1's model that Task 2's
   relabels EXPOSE rather than cause. It needs an answer before any ownStateOrLocal rule ships to
   users, and it is the most important open question on this branch.
2. DC now has NO otherStateOrLocal row at all, so it lacks the out-of-state guard Kansas just gained.
   Nothing was lost by the relabel (those rows were expected-exempt and never functioned as guards),
   but Task 9 Step 3 owes DC a Maryland-pension negative case.
3. MA scenarios 1 and 3, and NC scenarios 1, 3 and 4, still label those states' OWN systems as
   otherStateOrLocal. That is the KPERS mislabel again. Deliberately LEFT to Tasks 4 and 7 so the
   relabel lands together with the rule and its out-of-state guard, exactly as Kansas did in Task 2/3.
   Task 2's fix wave rewrote the surrounding prose to hand that instruction forward; do not treat the
   prose as evidence the labels were fixed.
4. AZ scenario 3 and ID scenario 3 keep federalCivilian on rows that are uniformed-services pay.
   Same deal: relabel belongs to Tasks 6 and 8, prose already says so.
4b. ** AZ scenario 4 carries an otherStateOrLocal row for what is most likely ARIZONA'S OWN system **
   (Form 140 Line 29a covers US government plus Arizona state and local). Found by the Task 2 fix
   implementer, NOT on any finding list, deliberately untouched, and it has NO disclosure prose of its
   own, so it is invisible to Task 6 in exactly the way MA-3 and NC-3/NC-4 were. Task 6 must check it.
   CORRECTION to item 3 above, established by grep during the fix wave: the "no state-specific case /
   closest available generic" disclosure exists ONLY in AZ, ID, MA (scenarios 1 and 4) and DC. MA-3,
   NC-3 and NC-4 carry the otherStateOrLocal mislabel with NOTHING disclosed anywhere, which makes the
   finding worse rather than milder. The labels themselves are as item 3 describes.
5. The new Kansas guard defends against otherStateOrLocal only, not governmentUnspecified. If Task 3
   wants that covered it adds the case itself.
6. ** FOR TASK 9. ** DC-3's and DC-4's knownDefect.summary both claim "both parties are 62 or older in
   every case, so age cannot separate them either." DC-4's parties are 65 and 60. The ARGUMENT survives
   (the 60-year-old holds the privateEmployer row, not a federalCivilian one) but the literal claim is
   false. Confirmed present at b0039d3 and untouched by either Task 2 commit, so it PREDATES this
   branch. Task 9 will read exactly these summaries when writing the DC survivor rule.
