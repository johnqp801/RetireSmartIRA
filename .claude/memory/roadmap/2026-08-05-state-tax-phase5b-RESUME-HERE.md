# RESUME HERE: State Tax Phase 5b, ready to run Task 6 (Arizona)

**Tasks 1, 2, 3, 3b, 4 and 5 are complete.** Kansas is fully correct. Massachusetts is correct for the
cases the model can express and ships with a disclosed under-taxation gap. Hawaii is a decided
disclosure item. Tasks 6 through 10 remain: Arizona, North Carolina, Idaho, Vermont-and-DC, and close.

**Task 6 is Arizona, and Phase 4 flagged it as PASSING ON WRONG LAW today:** every civilian amount in
its fixtures is under the $2,500 cap, so an uncapped federal-civilian rule leaves the cases green while
being wrong above the cap. Read that warning in the fixture BEFORE writing the rule and consider adding
a case above the cap. Arizona also has two inherited label problems recorded further down this file:
scenario 3 keeps `federalCivilian` on a uniformed-services row, and scenario 4 carries an
`otherStateOrLocal` row for what is almost certainly Arizona's OWN system (Form 140 Line 29a covers US
government plus Arizona state and local), with NO disclosure prose of its own.



## TASK 4 (MASSACHUSETTS) IS COMPLETE, BUT MASSACHUSETTS IS NOT (commits `0bd68af`..`0a19cb8`)

Three real defects fixed: contributory MA state and local pensions and US military retired pay are
excluded outright by MA law and the engine taxed them in full. Suite 1,938 + 509, 0 failures.

**BOTH DECISIONS RESOLVED BY JOHN ON 2026-08-05.**
1. **SHIP as-is. The section 13 reversal was NOT taken.** Shipping knowingly accepts a reachable
   UNDER-taxation path: a noncontributory municipal retiree who picks the own-state picker row gets
   $0.00 instead of $3,000.00. Reverting was rejected as a differently-wrong state, not a safe one,
   since it keeps over-taxing every MA public retiree on quoted statute to protect a small legacy
   category. Section 13's recipe is kept as the record of what shipping cost, not as pending work.
2. **Both copy items APPROVED:** the `unclassifiedPensionDisclosure` sentence in
   `statetax-2026-MA.json` and the picker caption in `IncomeSourcesView.swift`.

**ALSO APPROVED 2026-08-05:** Task 3's three picker labels, as is: "Government pension, my own state or
locality", "Military retired pay", "Railroad Retirement benefits". **All user-facing copy introduced by
Phase 5b is now approved.** Tasks 5 through 9 each still owe a NEW disclosure sentence for approval
alongside their rule; that obligation is unchanged and `rulesAndDisclosuresStayInLockstep` enforces it.

**Do not let the disclosure artifacts be retired now that MA has shipped.** The `knownButUnpinned`
entries, `theContributoryGapStaysRecorded`, and the caption are what make shipping defensible rather
than merely convenient. Deleting any of them turns a disclosed tradeoff into a silent defect.

## TASK 5 (HAWAII) IS COMPLETE, AND ITS DELIVERABLE IS A DECISION, NOT A RULE

**Outcome (b): Hawaii ships NO `perSourceExemptions`, stays "disclosed, not modelled", and all three
`knownDefect` blocks STAY.** The plan explicitly sanctioned this outcome. A reviewer upheld it and said
it would have made the same call.

**The method is the part worth copying.** The implementer did not argue the rule was wrong, it MEASURED:
it temporarily shipped the declined rule (`matchStructures: ["definedBenefit"]`, empty `matchSources`),
watched HI-1, HI-3 and HI-4 all go green at their published figures with NO fixture objecting, observed
that the same rule grants a full Hawaii exclusion to every contributory defined-benefit pension, and
then reverted. **The green outcome was available and it was wrong.** The reviewer reproduced the
arithmetic independently ($266.00 and $2,107.20 both exact) and confirmed the revert was complete.

**Why Hawaii could not trade the way Massachusetts did.** Schedule J's authorising sentence contains
the word "only": the exclusion "applies only to amounts attributable to employer contributions". The
declined rule matches precisely the population that word excludes, so the exclusion and the over-match
come out of THE SAME quoted sentence. Massachusetts had an evidentiary asymmetry to trade on (quoted
statute for the fixes, inference for the gap). Hawaii has none.

**Direction settles it.** Today's Hawaii error is OVER-taxation, disclosed on two surfaces. The rule
would have converted that into UNDISCLOSED UNDER-taxation at up to 11 percent, for the LARGER
population (every contributory DB pensioner, including CSRS and FERS and essentially every public
plan), to help the shrinking set of noncontributory private DB retirees.

**The axis question Task 4 deferred here is now ANSWERED:** Massachusetts needs a CATEGORICAL
contributory fact, Hawaii needs a PROPORTION. A boolean serves Massachusetts and serves Hawaii only at
its two endpoints, and the wrong endpoint fails toward under-taxation.

**DECIDED BY JOHN 2026-08-05: the axis is a PHASE 6 item.** It now sits with the two other "the model
cannot say it" problems already routed there, the residence-relative `ownStateOrLocal` staleness and
the disclosure that reaches only the input surface. **Do not read the `knownButUnpinned` catalogue as
saying the proportion is unvalidatable.** A golden fixture could carry a stipulated employer-funded
share as an INPUT; the real obstacles are a model field, a picker affordance, and whether a user can
supply a share Schedule J makes the taxpayer compute from cost basis.

---

## THE THING TASK 5 RESOLVED RATHER THAN INHERITED (kept for the record)

**Two fixtures on this branch assign OPPOSITE funding semantics to the same field.** HI-1's `source`
says `definedBenefit` represents an employer-funded NONCONTRIBUTORY pension. MA-1's says
`definedBenefit` IS the contributory Commonwealth pension. `PlanStructure.definedBenefit`'s own doc
comment takes neither side. Task 4 discovered this, declined to build an employee-contributory axis
from four Massachusetts cases precisely because it would have foreclosed Hawaii's, and a reviewer
verified the argument against Hawaii's actual fixture. **Hawaii is where the axis question gets
answered.** The plan already anticipated Hawaii might be a disclosure item rather than a correction;
this is the deciding input.

Also inherited: `governmentUnspecified` means "jurisdiction not established", NOT "noncontributory".
Task 4 established that from the enum's own doc comment and renamed MA-2 accordingly. Do not reuse it
as a funding marker.

---

## TASK 3 IS COMPLETE AND KANSAS IS DONE (commits `44acf69`..`a2125f1`, reviewed clean twice)

**Kansas had two defects. Phase 5a fixed one, Task 3 fixed the other. Steve Nicolai's report is now
fully addressed, and this is the first time in the whole program that has been true of any
jurisdiction.** Suite 1,910 Swift Testing in 296 suites + 509 XCTest, 0 failures.

**Two caveats before anyone tells Steve anything.** Neither affects a Kansas KPERS holder who
classifies their pension, which is Steve's own case, so the claim is sound FOR HIM.
1. An unclassified Kansas pension is still taxed in full and the user gets NO warning, while an
   identically-placed New York user is warned on two surfaces. John chose option 2 to fix this (see
   the OPEN WORK section below). Until it lands, "Kansas is complete" is true only for a user who
   classified.
2. Schedule S Line A14 also names Thrift Savings Plans, which are defined-contribution, and the rule
   matches `definedBenefit` only, so a Kansas TSP holder is still taxed. Recorded as machine-readable
   data in `GoldenScenarioDefectCatalogueTests.knownButUnpinned`, not merely in a report.

## TASK 3b IS ALSO COMPLETE (commit `626199e`, approved first round)

Caveat 1 above is CLOSED. The two unclassified-pension disclosures now gate on live config instead of
on New York, and each jurisdiction's SENTENCE comes from its own config. John approved option A
wording, one string per jurisdiction, with a `{scope}` token swapping "this figure" (State Comparison)
for "this plan" (CPA briefing). New York's live copy was proven byte-identical by extracting both
shipped strings from the PARENT commit and asserting full equality, then proving the test could fail.

**EVERY REMAINING JURISDICTION TASK NOW OWES A JOHN-APPROVED DISCLOSURE SENTENCE ALONGSIDE ITS RULE.**
Tasks 4 (MA), 5 (HI), 6 (AZ), 7 (NC), 8 (ID), 9 (VT and DC). The sweep
`rulesAndDisclosuresStayInLockstep` fails the suite if one is skipped, and a reviewer confirmed it
genuinely fires. **TASK 10 MUST NOT DELETE OR SKIP THAT SWEEP.** It is the only thing binding the
disclosure gate to the rules gate, and removing it silently reopens the Kansas defect for every later
jurisdiction. The copy is user-facing: draft it, get John's approval, then ship it. Do not let an
implementer's own phrasing land.

**A lesson worth keeping.** Seven tests already covered these two surfaces and ALL SEVEN PASSED while
Kansas got no warning, because each asserted only "New York fires, California does not" and "the text
is non-empty". That was coverage written to the implementation's own shape, not absent coverage. The
replacement sweeps iterate `USState.allCases` and derive their subject from data, so a jurisdiction
added by a later task is in scope with no test edit.

## THE MOST SERIOUS OPEN DEFECT ON THIS BRANCH

**`ownStateOrLocal` goes STALE ON A RESIDENCE CHANGE, and it errs toward UNDER-taxation.** Nothing
records the residence at classification time, and the pension picker gates on `incomeType == .pension`
only, not on the state. Reproduction: a Vermont user classifies VSERS as own-state (harmless, Vermont
ships no rule), then changes residence to Kansas in Settings. `incomeSources(asResidentOf: .kansas)`
short-circuits to identity at `DataManager.swift:577` because the state now matches, Schedule S Line
A14 matches, and a Vermont pension collects Kansas's full exclusion at the user's ACTUAL residence.
Task 3 closed the COMPARING route (State Comparison) but NOT the MOVING route, and the commit message
says so explicitly. Closing it needs a new stored field, so it was deliberately not attempted in Task
3. **It goes further live with every task that names `ownStateOrLocal`, and Tasks 4, 8 and 9 (MA, ID,
VT) all plan to.** Routed to the Phase 6 re-confirm prompt.

---

# Original resume notes follow

**This file exists because the SDD progress ledger lives in `.superpowers/`, which is GITIGNORED and would not survive a new session.** Everything a fresh session needs is below.

---

## Pick up exactly here

**Branch:** `feature/state-tax-phase5b`, local HEAD **`e5acef4`**. NOT pushed since `b0e23fe`, NOT merged.
**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`
**Plan:** `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md` (on that branch)
**Next task:** **Task 3, Kansas**, which COMPLETES the second half of the written promise to Steve Nicolai.

Suite on that branch: **1,885 Swift Testing in 295 suites + 509 XCTest, 0 failures**, 6 pre-existing env-gated skips.

`origin/main` is at `5024947`. Phases 1 through 5a are all merged and pushed.

---

## Read these first, in this order

1. `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md` (the catalogue and its traps)
2. `.claude/memory/roadmap/2026-08-04-state-tax-phase5a-ledger.md` (the corrections method, plus the Iowa resolution appended 2026-08-05)
3. The Phase 5b plan named above
4. This file

---

## THE FINDING PHASE 5B IS BUILT AROUND

Phase 3b built `PerSourceExemptionRule` with two deliberately separate axes so a plain "government pension" label could not hand New York's uncapped exclusion to a California public pension. New York carries a permanent regression case proving it.

**Kansas uses the same enum case BACKWARDS.** `PlanSource.otherStateOrLocal` documents itself at `RetireSmartIRA/RetirementPlanClassification.swift:40-43` as "A DIFFERENT state or its localities... exists specifically to stop an out-of-state public pension from selecting New York's exclusion." Kansas's three remaining fixtures label **KPERS**, Kansas's OWN system, with that case. The label was forced because the model could not say "this state's own system."

So the obvious Kansas rule would (a) pass all three Kansas fixtures, (b) exempt a **California** public pension for a Kansas resident, which Kansas law does not do, and (c) be caught by NOTHING, because Kansas has no out-of-state negative case the way New York does. **Task 2 adds that case.** It is the whole reason Task 2 exists.

The same missing vocabulary is what made **Vermont** (military vs CSRS, both `federalCivilian`) and **DC** (survivor vs own pension, both `federalCivilian`) UNSATISFIABLE by any configuration, per Phase 4.

---

## Task 1 is COMPLETE (commits `ebd2544`..`b0e23fe`), reviewed, one Critical found and fixed

Added to `PlanSource`: **`ownStateOrLocal`**, **`uniformedServices`**, **`railroadRetirement`**. Added a survivor flag to `RetirementPlanClassification`.

**20 exclusivity tests** in `RetireSmartIRATests/Phase5bModelExtensionTests.swift` prove BOTH directions for every new-versus-old pair. That mutual exclusion is the entire point: a rule naming `ownStateOrLocal` must NOT match `otherStateOrLocal`, and the converse.

**Inertness proven.** Only the two model files changed. No baseline, no movement ledger, no golden fixture. `PerSourceExemptionRule.matches()` is byte-for-byte unchanged, so a rule written before this behaves identically after. **New York was the canary** (only state shipping `perSourceExemptions`) and is unmoved.

**THE CRITICAL FINDING, worth remembering as a Swift trap.** The survivor flag shipped as `let isSurvivorBenefit: Bool? = nil`. A reviewer COMPILED that exact shape rather than reasoning about it and established by execution: the memberwise init REJECTS an argument for it ("extra argument in call"); the compiler warns the property "will not be decoded"; and **decoding JSON that explicitly sets it `true` SUCCEEDS AND YIELDS NIL**, with no error. Not merely useless, **silently lossy**. Fixed by `let` to `var`, with the compile error captured as RED first.

`Bool?` was kept over a plain `Bool` defaulting false, and the reasoning is worth preserving: a migrated `federalCivilian` record has genuinely never been ASKED whether it is a survivor benefit, so `false` would assert "known not survivor" for an unanswered question. Same discipline the file already applies via `PlanStructure.unknown` and `PlanSource.unknown`.

**DOWNSTREAM CHAIN, deliberately NOT built in Task 1, needed before DC can work:** a field on `IncomeSource` and `IRAAccount`; `matchIsSurvivorBenefit` on `PerSourceExemptionRule`; a parameter on `matches()`; a pass-through in `DataManager.matchedPerSourceRule`; a field on the fixture type `ClassifiedPensionSource`; and a bridge in `GoldenScenarioSingleYearTests.singleYearStateTax`.

---

## Task 2 is COMPLETE (commits `8c58d28`..`e5acef4`), reviewed clean over two rounds

Suite **1,885 Swift Testing in 295 suites + 509 XCTest, 0 failures**. **NO PIN MOVED**, verified
structurally as well as by the suite: only `statetax-2026-NY.json` ships a `perSourceExemptions` key,
and `planSource` reaches the computation only via `matchedPerSourceRule`, so re-labelling cannot change
an output. `Baselines/` untouched, no movement-ledger entry.

- **Kansas:** three KPERS rows `otherStateOrLocal` to `ownStateOrLocal`, plus a NEW seventh scenario,
  a Kansas resident holding a CALIFORNIA public pension, expected **$1,432.31**, and deliberately **NO
  `knownDefect`** because the engine already agrees. That is the desired shape: it is a permanent guard
  that must KEEP PASSING after Task 3. Implementer and reviewer each re-derived $1,432.31 independently
  from the ip25.pdf citations the fixture already carried, never from engine output.
- **Vermont:** VT-5 and VT-6 to `uniformedServices`, identified from the Act 71 citations in `name` and
  `source` rather than from the amounts. VT-1 through VT-4 are CSRS and were left alone.
- **DC:** survivor flag set on the five survivor rows, **including DC-1 (age 55, which fails the age
  gate)**. That was a judgement call and the reviewer endorsed it: flagging DC-1 makes Task 9's age gate
  LOAD-BEARING, because a rule that forgets the gate then returns $0 against DC-1's pinned $1,924.
- **DC, a controller-authorized extension beyond the plan's Task 2 text:** DC's two `otherStateOrLocal`
  rows to `ownStateOrLocal`. Without it, Task 9's DC rule would have had to name `otherStateOrLocal`,
  exempting a MARYLAND pension for a DC resident: the exact Kansas defect, one jurisdiction over.
- `ClassifiedPensionSource` gained `isSurvivorBenefit` as **TEST-ONLY fixture plumbing**. Production
  consumption remains Task 9's. Proven RED-first BY MEASUREMENT: before the schema change the JSON key
  decoded and re-encoded as `{planSource, amount, planStructure}`, silently gone. Same silent-loss class
  as Task 1's Critical.

**The review finding worth remembering as a method lesson.** The first fixture guard pinned the survivor
flags by COUNT (five flagged, two unflagged, file-wide). DC-1's and DC-5's rows are byte-identical apart
from the flag, which is exactly how the original bulk edit hit the wrong one, and swapping them still
passed 5-and-2. It is now pinned by CASE IDENTITY, and **both the implementer and the reviewer verified
it BY MUTATION rather than by reading**, the reviewer performing the swap itself and reverting it.

---

## DECIDED 2026-08-05 BY JOHN: OPTION 1, Task 3 adds ALL THREE picker options now

**The picker cannot express the three `PlanSource` cases Task 1 added, so a CORRECT Kansas rule would
be unreachable by every real user.** Found by controller code audit before Task 3 was dispatched, and
the plan never mentions it.

Kansas's rule must match `ownStateOrLocal` and must NOT match `otherStateOrLocal`, which is the entire
point of the guard case Task 2 added. But the user-facing picker is driven by a SEPARATE enum,
`PlanClassificationChoice`, at `RetireSmartIRA/IncomeSourcesView.swift:1160`, and its nine options are
unchanged since Phase 3b. None writes `ownStateOrLocal`, `uniformedServices` or `railroadRetirement`. A
Kansas user classifying a KPERS pension has exactly one government-pension option, "other state
government pension", which writes `otherStateOrLocal` at `IncomeSourcesView.swift:57`.

**Consequence if this is not addressed:** every Kansas golden case goes green, the suite is fully
honest, and a real KPERS holder still gets no exemption. **Task 10 Step 4 would then claim Kansas is
complete and "Steve can be told so without qualification", and that claim would be FALSE.** The same
gap blocks MA, VT, AZ and ID later in this phase, so it is not Kansas-specific.

Note the UI gate itself is already data-driven and needs no change:
`IncomeSourcesView.residenceHasPerSourceRules` reads the live config, so shipping a Kansas
`perSourceExemptions` block turns the picker on for Kansas automatically. The gap is purely that the
picker's OPTIONS cannot produce the new cases.

**John chose option 1 on 2026-08-05:** Task 3 adds all three picker options at once, so Tasks 4, 6, 8
and 9 inherit a picker that can express what their rules need rather than editing the same
`choice(for:)` reverse-lookup priority list five separate times. **This widens Task 3 beyond the plan's
config-shaped assumption into production SwiftUI.** Logged in `.claude/memory/decisions/log.md`.

The three rejected options, kept so the reasoning is not re-litigated: adding only `ownStateOrLocal`
now; deferring the whole picker to a dedicated task before Task 10; deferring it to Phase 6 with Task
10 stating plainly that Kansas is correct in the engine but not selectable in the app.

---

## WHAT TASKS 3, 4, 6, 7 AND 9 INHERIT, and it is not all in the fixtures

1. **`ownStateOrLocal` IS RESIDENCE-RELATIVE BUT STORED AS A STATIC LABEL, and this is the biggest open
   question on the branch.** The enum carries no jurisdiction identity. A KPERS pension classified
   `ownStateOrLocal` while the user lived in Kansas KEEPS that label after a move to DC, where a Task 9
   rule matching `ownStateOrLocal` plus the survivor flag would exempt income DC does not exempt. This
   is a property of Task 1's model that Task 2's re-labels EXPOSE rather than cause. **It needs an
   answer before any `ownStateOrLocal` rule ships to users.**
2. **MA scenarios 1 and 3, and NC scenarios 1, 3 and 4, still label those states' OWN systems as
   `otherStateOrLocal`.** The KPERS mislabel again. Deliberately LEFT to Tasks 4 and 7 so the relabel
   lands together with the rule and its out-of-state guard, exactly as Kansas did across Tasks 2 and 3.
3. **AZ scenario 3 and ID scenario 3 keep `federalCivilian` on rows that are uniformed-services pay**,
   and **AZ scenario 4 carries an `otherStateOrLocal` row for what is almost certainly Arizona's OWN
   system** (Form 140 Line 29a covers US government plus Arizona state and local). Relabels belong to
   Tasks 6 and 8.
4. Task 2 rewrote the prose around every one of those rows to hand the instruction forward. **Do not
   read that prose as evidence the labels were fixed. They were not.** The stale text it replaced said
   the enum lacked cases it now has, which would have pushed those implementers toward rules against
   `federalCivilian` (also exempting CSRS) and `otherStateOrLocal` (also exempting out-of-state
   pensions). Note also that MA-3, NC-3 and NC-4 carried the mislabel with **nothing disclosed
   anywhere**, inheriting it by a "see the case above" reference to a case that itself disclosed
   nothing.
5. **For Task 9:** DC-3's and DC-4's `knownDefect.summary` both claim "both parties are 62 or older in
   every case", and DC-4's are 65 and 60. The argument survives, because the 60-year-old holds the
   `privateEmployer` row, but the literal claim is false. It PREDATES this branch and is untouched.
6. The new Kansas guard defends against `otherStateOrLocal` only, not `governmentUnspecified`. If Task 3
   wants that covered it adds the case itself.
7. **DC now has no `otherStateOrLocal` row at all**, so it lacks the out-of-state guard Kansas just
   gained. Task 9 Step 3 owes DC a Maryland-pension negative case.

---

## What Task 2 did (original brief, kept for the record)

Modify three fixtures. **This changes golden fixtures, which Phase 4 otherwise treats as frozen, and that is deliberate**: these three were written against a model that could not express their rules, and Phase 4 recorded VT and DC as unsatisfiable for exactly that reason. Justify it in the report.

- **Kansas:** re-label KPERS from `otherStateOrLocal` to `ownStateOrLocal` in all three cases. **Then ADD the out-of-state negative case Kansas lacks**, mirroring New York's: a Kansas resident holding a CALIFORNIA public pension, which Kansas does NOT exempt. Name it so a later reader knows it is the guard.
- **Vermont:** re-label military cases from `federalCivilian` to `uniformedServices`, leaving genuine CSRS cases alone. Read each case's `source` string to decide which is which; do not guess from amounts.
- **DC:** set the survivor flag on survivor-benefit cases, leaving own-pension cases alone. **Note the downstream chain above is not built yet**, so DC may need part of it before the flag can be set from a fixture at all. If so, that is a real finding and belongs in the report rather than being worked around.

**Expected: no tax value moves in Task 2.** Re-labelling changes what a FUTURE rule can match, not today's computation, because no state yet has a rule naming the new cases. The `observedToday` pins should hold. If any moves, something matched on the old label that should not have, and that is a finding. The new Kansas negative case is the exception, being new.

---

## Then Tasks 3 to 10

3 Kansas per-source (**COMPLETES the second half of Steve Nicolai's promise**), 4 Massachusetts, 5 Hawaii, 6 Arizona, 7 North Carolina, 8 Idaho, 9 Vermont and DC together, 10 close the phase.

**Two states currently PASS ON WRONG LAW and Phase 4 flagged both:**
- **Arizona:** every civilian amount in its fixtures is under the $2,500 cap, so an uncapped federal-civilian rule leaves cases green while being wrong above the cap.
- **Idaho:** its only sub-62 case is at age 60, so a single age-62 gate turns all five cases green while being wrong for civilian retirees whose real gate is 65.

**North Carolina may stay unsatisfiable.** Bailey keys on vesting before 1989-08-12 and the model has no vesting-date axis. Decide whether to add the axis or record NC as remaining unsatisfiable. **Do not force it.**

---

## Standing rules that cost real time when ignored

- **RUN XCODEBUILD IN THE FOREGROUND with the Bash tool's `timeout: 600000`.** Five agents stalled by backgrounding a build, each costing a full turn. The 120 second default is not the ceiling. Do not use `run_in_background` or Monitor. **The durable fix is a wrapper script; nobody has written one.**
- **"Verify before you comply" belongs in every fix dispatch.** Seven separate times a subagent caught an error in the brief it was given, including two of mine that would have put false statements into fixtures. A reviewer finding is evidence, not fact, exactly like an implementer report.
- **The frozen 1,020-value baseline stays frozen forever.** Movements go in `statetax-behavior-movements-2026.json` with a `goldenCase` that is machine-checked against real fixture names. `after` values are MEASURED from failure messages, never predicted.
- **Two equivalence lists mean different things.** `phase5CorrectedJurisdictions` (KS, IA, NM, GA, UT, IN) asserts divergence from the frozen legacy Swift table. `layerAProvenDivergentJurisdictions` (IA, NM, GA, UT) asserts at least one scenario in a fixed grid diverges. Kansas and Indiana are deliberately in the first and NOT the second, because that grid never exercises a personal exemption.
- **NO EM DASH CHARACTERS** anywhere.
- **A fixture can be citation-clean and still not carry enough.** New Mexico's married bracket table was only partially quoted, so its corrector had to fetch the enrolled bill. Expect this again.
