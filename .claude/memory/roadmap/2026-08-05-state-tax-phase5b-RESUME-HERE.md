# RESUME HERE: State Tax Phase 5b is CLOSED. Nothing awaits John.

**ALL TEN TASKS ARE COMPLETE (1, 2, 3, 3b, 4, 5, 6, 7, 8, 9, 10) and each was reviewed.** The branch
is `feature/state-tax-phase5b`, NOT merged and NOT pushed.

**START WITH THE LEDGER, not this file:**
`.claude/memory/roadmap/2026-08-04-state-tax-phase5b-ledger.md`. It is the durable record of what
5b corrected, what it deliberately did not, the production-diff inventory, and what the next phase
inherits organised BY MISSING MODEL FIELD. This file is the running resume log and the sections
below Task 6 are kept as the history of how each decision was reached.

## STATE AT CLOSE

- **Defect cases: 99 across 32 jurisdictions at Phase 5a close, 88 across 29 at Phase 5b close.**
  Net minus 11. Gross: 12 blocks deleted (AZ 3, DC 3, KS 3, MA 3), 1 added (Idaho's ID-8 cap
  guard). 11 new golden scenarios, 10 of them guards carrying no defect. Derived, not remembered:
  `grep -c '"knownDefect"' RetireSmartIRATests/GoldenScenarios/*.golden.json`.
- **Kansas, Massachusetts and DC now carry ZERO pinned defects**, joining Iowa, Georgia and Indiana
  from Phase 5a. Six of 51 jurisdictions are clean.
- **Four jurisdictions ship a rule:** Kansas, Massachusetts, Arizona, District of Columbia.
- **Four ship NOTHING by a reviewed decision:** Hawaii, North Carolina, Idaho, Vermont. Each keeps
  all its `knownDefect` blocks, plus guard cases, a `knownButUnpinned` entry with a deletion guard,
  and a caption. **These are decisions, not a to-do list. Do not re-open them.**
- **`knownButUnpinned` went from 1 entry (Missouri) to 11.** Most of what this phase learned is a
  defect no fixture can hold.
- Suite at close: **2,020 Swift Testing in 304 suites + 509 XCTest, 0 failures.**

## NOTHING AWAITS JOHN. Zero open items.

**ALL PHASE 5b COPY IS APPROVED**, including Task 9's three, the last outstanding ones, approved by
John on 2026-08-05 as written: DC's `unclassifiedPensionDisclosure` sentence in
`statetax-2026-DC.json`, and DC's survivor toggle label plus its caption and Vermont's caption, both
in `IncomeSourcesView.swift`. The markers are cleared from the tree. **Do not re-open the wording.**

**AND THE LAST JUDGEMENT CALL IS DECIDED.**

**DECIDED BY JOHN ON 2026-08-05: HOLD. Vermont ships no rule.** The recommendation was unanimous
(implementer, reviewer, controller) and John accepted it. Vermont keeps all six `knownDefect` blocks
BY DECISION rather than by default, alongside Hawaii, North Carolina and Idaho.

The rejected shape is the config-only CSRS one: four cases green, roughly $335 of bounded
over-match, but it over-exempts FERS retirees, a GROWING population, to serve CSRS retirees, a class
CLOSED SINCE 1984. That is the same population logic that decided North Carolina.

The preferred fix is DEFERRED, not abandoned: an income-gated military rule implementing Act 71's
quoted $125,000 sentence corrects $4,525.15 a year with NO under-taxation anywhere. It is blocked on
which income basis the gate compares against, a program-level decision no Vermont fixture pins.
**If it is ever built, VT-7 goes in FIRST: AGI $130,000, expected $172.53.** It is the only case
that discriminates the two readings, and a reviewer confirmed it yields three distinct values.

Vermont still holds the largest single dollar gap in the phase, $5,211.50 a year at VT-6's shape.
That is a KNOWN, DISCLOSED COST OF THE HOLD, carried by the caption and by the six pinned blocks,
not an oversight.

Alternatives drafted and rejected for each copy item are in Task 9's report, section 6, kept as the
record of what was considered. **Do not read them as open options.**

## THE PHASE'S MOST IMPORTANT SINGLE FINDING: Vermont

**Task 1's model extension dissolved exactly the source collision it was built for, and Vermont is
STILL unsatisfiable, because the binding constraint was never sources.** Phase 4 recorded Vermont
as unsatisfiable because its military and CSRS cases both had to carry `federalCivilian`; Task 2
re-labelled VT-5 and VT-6 to `uniformedServices` from their own Act 71 citations, and the collision
is genuinely gone. Vermont did not move.

What actually blocks it: Vermont needs TWO exclusions with different CAPS and different AGI BANDS,
and a jurisdiction carries one pooled cap and one `agiPhaseout`; and its CSRS exclusion applies
"only to benefits not covered by the Social Security Act", which `federalCivilian` cannot express
because that one case covers CSRS AND FERS. **Task 1 extended the WHO axis. Vermont's remainder
lives on the HOW MUCH and WHEN axes.**

Vermont carries the largest dollar gap in the phase: $5,211.50 a year at VT-6's shape. If Option D
is ever built, write **VT-7 first**: AGI $130,000, expected **$172.53**. It is the only thing that
would pin which income basis the gate compares against, and no current Vermont fixture does.

## DO NOT DELETE THESE

`Phase5bUnclassifiedPensionDisclosureTests.rulesAndDisclosuresStayInLockstep` (the only thing
binding the disclosure gate to the rules gate); all eleven `knownButUnpinned` entries and their
deletion guards; the six captions; Idaho's and Vermont's reflective tripwires (Idaho's has already
fired once, on Task 9's first full-suite run, and correctly re-opened Idaho); the frozen
1,020-value baseline.

---

# History: how each task got there (kept for the record)

## READ THIS BEFORE BRIEFING TASKS 7, 8 OR 9. IT CONSTRAINS ALL THREE.

**A CAPPED PER-SOURCE TREATMENT IS BANNED, and the ban is currently only a test.**
`PerSourceExemptionRule.treatment` is evaluated INSIDE the per-row loop
(`TaxCalculationEngine.swift:619-627`, `DataManager.swift:891-899`), so a `.partial` treatment caps PER
PENSION ROW rather than per household. Design doc section 3.4a names this the single largest
correctness risk in the phase, and this codebase HAS SHIPPED THAT BUG ONCE, in New York's $20,000
exclusion. The natural one-rule-per-form-line implementation walks straight into it. Task 6 found this,
a reviewer confirmed every part of it against the code, and the two loop comments asserting the
invariant turned out to be true only of the configs, not of the code.

**Arizona's workaround:** route the cap through the existing POOLED `pensionExemption` and use
per-source rules only to keep non-qualifying sources OUT of the pool. A sweep now asserts no shipped
rule in any of the 51 configs carries a capped treatment.

**IT GENERALIZES ONLY TO A JURISDICTION WITH EXACTLY ONE CAPPED POOL.** A state needing two different
caps on two different source groups cannot be expressed this way and will force an engine change or a
deferral. **Idaho, Vermont and DC ALL have capped exclusions.** Triage each against this before its
task starts, rather than discovering it mid-task.

Phase 6 candidates from the same finding: `treatment` is still typed as the full `ExemptionLevel`, so
the sweep is a test-level guard rather than a structural guarantee; the durable fix is a narrower
treatment type, or grouping matched rows by rule and applying the treatment once per rule.

## TASK 9 (VERMONT AND DC) OUTCOME

**DC ships its rule and carries zero defects.** `matchSources` `federalCivilian` and
`ownStateOrLocal` at `definedBenefit`, `matchIsSurvivorBenefit: true`, `matchMinAge: 62`, treatment
`full`, under D.C. Code Section 47-1803.02(a)(2)(N)(ii). Measured: DC-2 $1,924.00 to $0.00, DC-3
$1,546.00 to $0.00, DC-4 $3,848.50 to $1,846.00. DC-6 was added as the Maryland survivor guard
Task 2's reviewer said Task 9 owed DC.

**`matchMinAge` had to be built and the brief's chain omitted it.** The per-source partition is
unconditional on age, so DC-1 (a survivor at 55) fails without it, and `perQualifyingSpouse` cannot
substitute because `ownerQualifies` returns true unconditionally for a single filer. It gates on
the ROW OWNER's age, not the household maximum.

**The picker toggle was MANDATORY, not polish.** No sequence of user actions could set
`isSurvivorBenefit`, so every DC golden case would have gone green while a real survivor annuitant
got nothing: Task 3's Kansas failure exactly. The toggle shows where live config consults the
dimension (`residenceUsesSurvivorDimension`, never a hardcoded `== .districtOfColumbia`). The
Bool-to-Bool? mapping is the careful part: a question shown saves the answer, a question NOT shown
PRESERVES what the row had, so no editor stamps "not a survivor" on a question it did not ask.

**Deviation from the brief, endorsed:** no field was added to `IRAAccount`. Nothing in production
constructs a `RetirementDistributionComponent` from an account, and an unreachable PERSISTED field
is dead data in every user's save file. It went on the in-memory component instead.

**Vermont: see the summary near the top of this file.** Both candidate shapes were measured with
Hawaii's method and both reverted. VT-6 caught the military rule exactly as the brief predicted.

**Idaho was re-opened by this task and the decision survived.** Task 8's tripwire fired on the
first full-suite run. Two of Idaho's three objections died (the age gate now exists;
household attribution is moot because `matchMinAge` is per owner). The third survived and decided
it: Line 8a's uncapped, SS-reduced maximum.

## TASK 8 (IDAHO) OUTCOME

**Idaho ships NO rule. Four defects stay and a FIFTH was added** (ID-8, the cap guard the review
demanded: MFJ 68/70, $140,000 of CSRS, expected $1,069.33, observed $4,902.50). Every other Idaho
case floors taxable income at $0.00 whether the deduction is capped or not, so an UNCAPPED rule
would have passed all of them.

**Idaho is the one decline that is a JUDGEMENT CALL rather than a procedural foreclosure, and the
catalogue entry originally got that wrong.** For `federalCivilian` and `ownStateOrLocal` no
catching case is pinnable. For `uniformedServices` a rule IS expressible and was measured green on
ID-3 with nothing else moving. It was declined on Form 39R Line 8a's dollar-for-dollar reduction by
Social Security and Railroad Retirement received, which the model does not carry: roughly $935 a
year of UNDISCLOSED under-taxation in the COMMON case. Both that and the split-age joint return ARE
pinnable, so a future task may legitimately reach a different conclusion. It should pin them first.

## TASK 7 (NORTH CAROLINA) OUTCOME

**North Carolina ships no Bailey rule. All three defects stay.** The declined rule was measured
green on all three ($0.00, $0.00, $379.05) and reverted. NCDOR's sentence grants and limits in the
same clause, which is Hawaii's structure rather than Massachusetts's. The Bailey class CLOSED in
1989 and can only shrink; its complement grows with every hire. NC-5 was added as the only
vesting-independent guard North Carolina can carry.

**North Carolina is the one place weaker than Hawaii and it is recorded because it cuts against the
decision:** Hawaii's over-taxation is disclosed on two surfaces, North Carolina's was disclosed
nowhere, and a Bailey-vested retiree is over-taxed $1,486.27 a year. A caption now ships; the
structural answer is a Phase 6 disclosure item.

**Also found here, and it predates the phase:** North Carolina military retired pay has TWO PATHS
WITH OPPOSITE ANSWERS. By `IncomeType`, `MilitaryRetirementExemption` returns `.fullyExempt` and
the UI shows a green badge. By classification, the Task 3 picker row writes
`(definedBenefit, uniformedServices)`, NC ships no rule, and the money is taxed in full: $1,486.27
measured. The loops are disjoint so there is no arithmetic bug; the defect is that the answer
depends on which screen the money was entered from.

## TASK 6 (ARIZONA) OUTCOME

Three defects fixed (measured: $396.25, $0.00, $1,453.75), four guard cases added including the
ABOVE-CAP case Phase 4 said was missing, and the two inherited relabels done (AZ-3 to
`uniformedServices`, AZ-4's second row to `ownStateOrLocal`). Disclosure sentence APPROVED by John.

**AZ-4 STAYS PINNED and that is correct.** `exemptionAppliesPerIndividual: true` turns it green while
granting $5,000 to an MFJ household where only ONE spouse holds the qualifying pension: the flag
doubles on the AGE gate, Arizona conditions doubling on each spouse RECEIVING qualifying income. The
trade is $37.50 of over-taxation against $62.50 of under-taxation, and a new golden case pins it, so
flipping the flag turns AZ-4 green and that case red. AZ-4 also could not be pinned even against a
correct engine, because the fixture schema has NO OWNER FIELD, so its two rows are one taxpayer's two
pensions.

**Arizona is the first non-New-York config to name a jurisdiction-specific source.** It only works
because a Task 3 review changed `jurisdictionNamedSources` from a `Set` to a `[PlanSource: USState]`
comparing `== state`. Under the old version, Arizona residents would have had the own-state picker row
suppressed and the Line 29a allowance would be unreachable for an ASRS retiree.



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

## Pick up exactly here (UPDATED AT PHASE CLOSE, 2026-08-05)

**Branch:** `feature/state-tax-phase5b`. **NOT pushed and NOT merged.**
**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`
**Plan:** `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md` (on that branch)
**Branch point:** `c5a7bce`. `main` was merged IN at `b0039d3` for the test wrapper, so
`git merge-base HEAD main` reports `378c110`. **Diff with `main...HEAD` (three dots), not two.**

**Next actions, in order:**
1. Get John's answers on the four items listed near the top of this file. The Vermont call is the
   only one that changes code; the other three are copy approvals on strings already in the tree.
2. Decide merge. The branch changes 15 production Swift files and 5 shipped configs, so this is a
   real release-bearing change, not a docs merge. Nothing has shipped to users yet.
3. Phase 6 scope: the ledger's "WHAT THE NEXT PHASE INHERITS" section, organised by missing model
   field. The employee-contributory axis already has an owner (John assigned it 2026-08-05).

Suite at close: **2,020 Swift Testing in 304 suites + 509 XCTest, 0 failures**, 6 pre-existing
env-gated skips. Run it with `tools/run-tests.sh` in the FOREGROUND, `timeout: 600000`.

The stale original of this block said "next task: Task 3, Kansas" at HEAD `e5acef4`. All ten tasks
are done.

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

- **RUN THE SUITE WITH `tools/run-tests.sh` IN THE FOREGROUND, `timeout: 600000`.** Five agents stalled by backgrounding a build, each costing a full turn. The 120 second default is not the ceiling. Do not use `run_in_background` or Monitor. **The wrapper NOW EXISTS** (`378c110`, merged into this branch at `b0039d3`): it supplies `-project` so a reset cwd cannot build a different worktree, refuses to report a false green when zero tests ran, and re-runs the known `MultiYearPerfTests` wall-clock flake in isolation to check the claim. Do not call `xcodebuild` directly.
- **"Verify before you comply" belongs in every fix dispatch.** Seven separate times a subagent caught an error in the brief it was given, including two of mine that would have put false statements into fixtures. A reviewer finding is evidence, not fact, exactly like an implementer report.
- **The frozen 1,020-value baseline stays frozen forever.** Movements go in `statetax-behavior-movements-2026.json` with a `goldenCase` that is machine-checked against real fixture names. `after` values are MEASURED from failure messages, never predicted.
- **Two equivalence lists mean different things.** `phase5CorrectedJurisdictions` asserts divergence from the frozen legacy Swift table; at Phase 5b close it reads KS, IA, NM, GA, UT, IN, MA, AZ, DC. `layerAProvenDivergentJurisdictions` (IA, NM, GA, UT) asserts at least one scenario in a fixed grid diverges. Kansas, Indiana, Massachusetts and DC are deliberately in the first and NOT the second: that grid never exercises a personal exemption, and its pension row is built UNCLASSIFIED and infers to unknown/unknown, so no per-source rule can reach it. Each of those exclusions was MEASURED ("None diverged"), not assumed. Consequence recorded as a Minor: Massachusetts has ZERO Layer A coverage.
- **NO EM DASH CHARACTERS** anywhere.
- **A fixture can be citation-clean and still not carry enough.** New Mexico's married bracket table was only partially quoted, so its corrector had to fetch the enrolled bill. Expect this again.
