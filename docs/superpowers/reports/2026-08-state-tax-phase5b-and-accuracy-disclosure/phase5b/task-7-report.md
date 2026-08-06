# Task 7 report: North Carolina

**Worktree** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`
**Branch** `feature/state-tax-phase5b`
**Start HEAD** `eba1f52`, working tree clean. Printed and verified before the first edit.

Every supporting claim below is marked **[QUOTED]** (a sentence in a primary source, a fixture
`source` field, or a doc comment reproduced on this branch), **[MEASURED]** (a value this task
produced by running code), or **[INFERENCE]**.

---

## 1. THE DECISION

**North Carolina ships NO `perSourceExemptions` and is recorded as remaining UNSATISFIABLE.** The
three `knownDefect` blocks stay, unedited. No production Swift changed and no state config file was
touched. The plan's own text sanctions this outright: **[QUOTED]** "Decide: add the axis, or record NC
as remaining unsatisfiable. Do not force it."

**The re-label DOES happen anyway.** NC-1, NC-3 and NC-4 move from `otherStateOrLocal` to
`ownStateOrLocal`, and a new out-of-state guard case NC-5 ships. Argued in section 5, not assumed.

North Carolina resembles **Hawaii**, not Massachusetts. Section 3.

---

## 2. THE MEASUREMENT THAT DECIDED IT

I did not argue about what a source-keyed rule would do. I shipped it temporarily and looked.

**ORDER OF OPERATIONS, corrected on review.** An earlier draft of this section implied the mutation came
first. It could not have: `PerSourceExemptionRule.matches` is explicit containment, so a rule naming
`ownStateOrLocal` matches nothing while NC-1, NC-3 and NC-4 still read `otherStateOrLocal`, and zero
defects would have flipped. The actual order was **re-label first, measure second**: the re-label was
applied and `GoldenScenarioSingleYearTests` run green (which is itself the measurement in section 6.3
that the re-label moves no value), and only then was the rule added. The values below are unaffected;
only the narrative order was wrong.

Added to `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NC.json`:

```json
"perSourceExemptions": [
  { "matchSources": ["ownStateOrLocal", "federalCivilian"],
    "matchStructures": ["definedBenefit"],
    "treatment": {"kind": "full"} }
]
```

Those are the two sources NC-1's quoted NCDOR sentence names, mapped onto the model. This is the
**narrowest** shape available, which is the point: even at its narrowest it over-matches.

Command: `tools/run-tests.sh GoldenScenarioSingleYearTests`, foreground.

**[MEASURED]** result: three failures, all NC, all of the form `now MATCHES its published form`, with
values `0.0`, `0.0` and `379.05`. Those are NC-1, NC-3 and NC-4, and those are exactly their
`expectedStateTax` values. In the golden harness's vocabulary that failure IS success: it is the
"delete the knownDefect block" signal from Step 4.

So the rule I declined would have turned all three catalogued defects green, cleared North Carolina
from the defect catalogue entirely, and **not one fixture in the set would have objected**. NC-2, the
private-sector pension, is the only guard the fixture had, and a rule naming `ownStateOrLocal` and
`federalCivilian` sails straight past it. The mutation was reverted with `git checkout --` and the
config verified back to `perSourceExemptions: None` before any other work started.

That is the brief's warning made concrete. The green outcome was available and it was wrong.

---

## 3. WHY SHIPPING FAILS, claim by claim

### 3.1 The over-match is excluded by the very sentence that would authorise the rule

**[QUOTED]** NCDOR, via NC-1's `source`: "the North Carolina Consolidated Judicial Retirement System,
the Federal Employees' Retirement System, or the United States Civil Service Retirement System, **if
the retiree had five or more years of creditable service as of August 12, 1989**".

The grant (which systems) and the limit (the vesting condition) are **one sentence**. The conditional
"if" does exactly what the word "only" does in Hawaii's Schedule J sentence.

**[INFERENCE]** So there is no evidentiary asymmetry to trade on. Task 4 shipped Massachusetts because
its three corrections rested on quoted affirmative statute naming exempt categories while its residual
gap rested on an inference; the quoted side outweighed the inferred side. Here the limit is itself
quoted, from the same clause as the grant. There is nothing to weigh against nothing, which is Task 5's
formulation for Hawaii and it transfers exactly.

**A stronger point than Hawaii had.** **[INFERENCE from the quoted sentence]** No source in the North
Carolina fixture exempts ANY pension unconditionally. Massachusetts had categories that were exempt
outright, so a narrower rule with no over-match existed. Here every system the sentence names carries
the same "if", so **no sub-rule escapes the over-match**. There is no narrowing available at all.

### 3.2 Step 3 cannot be satisfied, which forecloses shipping procedurally

**[QUOTED]** Step 3: "For each rule ask: what would this wrongly match? If the fixture set has no case
that would catch that, ADD one."

The case that would catch it is a NON-Bailey-vested North Carolina state pension. **[MEASURED]**
`Phase5bNorthCarolinaDecisionTests.theDeclinedRuleCannotBeNarrowedToTheBaileyClass` reads the fixture
and confirms NC-1's row is `(definedBenefit, ownStateOrLocal)`, byte-identical to what
`PlanClassificationChoice.ownStateGovernmentPension.classification` writes, which is the only row a
North Carolina public retiree can honestly select whether or not they are Bailey-vested. A fixture for
the non-vested household would therefore carry inputs byte-identical to NC-1's ($50,000,
`definedBenefit`, `ownStateOrLocal`, single, age 70, AGI $50,000) and a contradictory
`expectedStateTax` of $1,486.27 against $0.00.

That is Hawaii's blocker and Arizona's blocker, in the same shape. Step 3 is a requirement of the
shared procedure, not a preference. It cannot be satisfied, which forecloses shipping **independent of
my judgement**.

### 3.3 The direction of the error flips, over a larger and growing population

See section 4. This is the fact the brief asked me to state explicitly.

---

## 4. THE POPULATION ARITHMETIC, and a correction to the brief

### 4.1 The brief is wrong by five hiring cohorts, in my favour

**[QUOTED, brief]** "Bailey requires five or more years of creditable service as of 1989-08-12, meaning
hired no later than roughly 1984. Everyone hired into North Carolina public service after August 1989
is outside the class."

Those two sentences contradict each other and the second is wrong. **[INFERENCE, arithmetic]** To hold
five or more years of creditable service as of 1989-08-12, service must have BEGUN on or before roughly
1984-08-12. So the excluded group is everyone first hired from **September 1984**, not September 1989.
The brief's own premise is right and its conclusion sentence understates the excluded group by five
full hiring cohorts. Corrected here and in the fixture and catalogue prose.

### 4.2 The answer, stated explicitly

**The non-Bailey group is larger, and it is the only one of the two that grows.**

Three claims, in increasing order of how much they rest on inference:

1. **[INFERENCE, arithmetically forced]** The class is CLOSED. It closed on 1984-08-12 and can never
   gain a member. It has shrunk by mortality every year for forty-two years. Its complement has grown
   with every North Carolina public hire over those same forty-two years and still grows. Whatever the
   ratio was in 1990, it has moved monotonically against Bailey every single year since.

2. **[INFERENCE, arithmetically forced]** Every North Carolina public employee retiring in 2026, and in
   every future year, is outside the class. Under a conventional thirty-year career a person hired in
   August 1984 retired around 2014. The entire forward flow of new North Carolina public retirees is
   non-Bailey, permanently.

3. **[INFERENCE]** The age floor. To have entered North Carolina public service by August 1984 a person
   must have been about 18 then, so born no later than 1966, so **60 or older in 2026** at the absolute
   extreme, and 64 to 67 at a normal public-service entry age of 22 to 25. This app's users cluster in
   the Roth-conversion planning window between retirement and RMDs, roughly 60 to 73. Within that
   window the 60-to-65 band was aged 18 to 23 in 1984 and only a thin tail qualifies; the 66-to-73 band
   was 24 to 31 and a real share qualifies, but only those already in North Carolina public service by
   August 1984, not those who entered mid-career or moved to the state later. Each passing year moves
   the whole window further from 1984.

**Stated honestly, the one place this is weaker than it sounds:** among people *currently drawing* a
North Carolina public pension, as opposed to currently employed, the Bailey share is larger than the
forty-two-cohorts framing suggests, because retirees skew to earlier hires. I cannot ground a precise
split without external headcount data and I have not tried to. The decision does not need it: claims 1
and 2 are forced by the 1984 cutoff alone, and claim 3 is about who uses this software.

### 4.3 Direction and magnitude, both ways

- **Today, no rule:** North Carolina OVER-taxes the Bailey class. **[MEASURED]** $1,486.27 a year at
  NC-1's shape, which is the fixture's own pinned `observedToday` and is reproduced by
  `northCarolinaIsUnaffectedByClassification` for every `PlanSource`. Over-taxation is the safe
  direction for a planning tool.
- **With the rule:** North Carolina UNDER-taxes every non-Bailey public pensioner by the same
  $1,486.27 at that shape, at a 3.99% flat rate, silently.

So the rule trades a bounded over-taxation of a closed, aging, can-only-shrink cohort for an
undisclosed under-taxation of an open, growing one that includes every future North Carolina public
retiree. That is the trade Task 5 declined for Hawaii, and the population asymmetry here is sharper
than Hawaii's because the Bailey cohort has a hard closure date.

---

## 5. THE THIRD OPTION: adding a vesting axis, weighed honestly

**Rejected for this task, and I am not going to pretend it is impossible, because it is not.**

Hawaii's option (c) was blocked on the merits: **[QUOTED, Task 5 report]** a fraction "cannot be
validated", because no golden case for a partially employer-funded household can state its own
employer-funded share. **North Carolina's is not blocked that way.** Bailey membership is a boolean; a
golden fixture could carry it as an input the way it carries `amount`; and **[QUOTED]** NC-1's source
notes that a retiree entitled to the exclusion claims it on "Line 20, Form D-400, Schedule S", so many
users can read the answer off their own return. If I had shipped the axis, Step 3 would have become
satisfiable and the three defects would have resolved honestly.

I declined it on scope and cost, and I want that on the record as the actual reason:

1. **[QUOTED, Task 4's catalogue entry]** "the phase's own precedent is that a shared classification
   axis lands in the model task (`isSurvivorBenefit`, Task 1) and is consumed by the jurisdiction
   tasks, not invented by one of them." Task 7 is a jurisdiction task.
2. **[QUOTED, brief]** "Production consumption of the survivor flag is Task 9's, not yours." So Task
   1's axis is still not wired into `matchedPerSourceRule`. A second axis invented here would land in
   the same matching function and the same `DataManager` mirror that has drifted five times on this
   branch, at the same time as Task 9's change to both. Two axes, two tasks, one function.
3. **[INFERENCE]** The axis is not shared. `isSurvivorBenefit` serves DC and generalises;
   `uniformedServices` serves five states named in its own doc comment. A Bailey flag serves ONE
   jurisdiction and one cohort whose correct-answer population declines monotonically to zero, while
   becoming a permanent field in stored user data that cannot be removed without a migration.
4. **[INFERENCE]** It is not a DATE axis, despite the plan's framing. "Five or more years of creditable
   service as of August 12, 1989" is a service-credit computation, not a date a user holds. The honest
   picker question is a Bailey-membership boolean, and a user who guesses it wrong moves their own tax
   by 3.99% of the pension in whichever direction they guessed, with nothing to cross-check them.
5. **[INFERENCE]** Shape. `PlanClassificationChoice` rows are (structure, source) pairs. A third
   orthogonal boolean means either doubling rows or a separate toggle, plus the golden fixture schema,
   plus `PerSourceExemptionRule`, plus the engine, plus the mirror. That is a model task.

So (c) is the right eventual answer and the wrong answer for this task. Recorded in the catalogue
entry, not just here.

---

## 6. THE RE-LABEL: yes, argued rather than assumed

**Done: NC-1, NC-3 and NC-4 move to `ownStateOrLocal`.** Four reasons, and one rebuttal of the brief.

1. **[QUOTED, the fixture itself]** NC-1's `source` said: "Re-label NC-1, NC-3 and NC-4 to
   'ownStateOrLocal' and ADD an out-of-state guard case, exactly as Kansas did, **whichever way Task 7
   rules on the vesting-date axis**." Step 1 makes the golden fixture the specification, and the
   specification instructs this unconditionally.
2. **[QUOTED]** `PlanSource.otherStateOrLocal`'s doc comment: "A DIFFERENT state or its localities."
   These are North Carolina's own systems held by North Carolina residents, so the old labels were
   **false statements stored in a fixture**. Correctness is its own reason.
3. **[MEASURED]** It moves no computed value. `tools/run-tests.sh GoldenScenarioSingleYearTests` was
   green immediately after the re-label, which required the harness's `pinnedDefectHolds` branch to
   reproduce all three `observedToday` figures exactly ($1,486.27, $1,975.05, $1,975.05). Any movement
   would have surfaced as `pinnedDefectMoved`. Also swept over every `PlanSource` by
   `northCarolinaIsUnaffectedByClassification`.
4. **[INFERENCE]** It defuses the Kansas trap for whoever eventually writes the Bailey rule. With the
   old labels the natural rule names `otherStateOrLocal`, and that rule hands a full North Carolina
   exclusion to a California public pension held by an NC resident. NC-5 now fails if anyone does it.

**The brief's objection does not survive contact with the code.** **[QUOTED, brief]** "it would leave a
`ownStateOrLocal` label with no rule naming it." **[MEASURED]** Arizona already ships exactly that:
AZ-4 and AZ-8 carry `ownStateOrLocal` rows, and the sources named by Arizona's two rules are
`nyStateOrLocal`, `otherStateOrLocal`, `privateEmployer` and `uniformedServices`. Task 6 states this
deliberately: **[QUOTED]** "`federalCivilian` and `ownStateOrLocal` are matched by NO rule." A label
with no rule naming it is the shipped, reviewed situation in another jurisdiction on this branch.

### 6.1 The guard case, and why it is the only one that could be added

**NC-5 added:** single filer, age 70, AGI $50,000, $50,000 at `(definedBenefit, otherStateOrLocal)`,
`expectedStateTax` $1,486.27, **no `knownDefect`** because the engine is correct here today.
**[QUOTED]** NCDOR, already in NC-2's `source`: the exclusion "does not apply to retirement benefits
paid to former teachers and state employees of OTHER states." No new research was needed.

**[INFERENCE]** It is the ONLY guard North Carolina can carry, and the reason is worth stating: an
out-of-state public pension is fully taxable in North Carolina at **every** vesting date, so it is
vesting-INDEPENDENT. No correct Bailey rule, present or future, can ever make it exempt, and its
expected value asserts nothing its inputs do not carry.

I deliberately did **not** add a `federalCivilian` guard. A case asserting a taxable federal pension
would encode non-vesting, a fact the inputs do not carry, and it would make a future *correct* Bailey
rule fail. That is the error class this phase exists to prevent.

---

## 7. STEP 7: the equivalence lists

**North Carolina goes on NEITHER list.** No config file changed, so this is not a judgement call.

- `phase5CorrectedJurisdictions` (currently `[kansas, iowa, newMexico, georgia, utah, indiana,
  massachusetts, arizona]`) asserts the bundled JSON deliberately DIVERGES from the frozen legacy Swift
  table. `statetax-2026-NC.json` is byte-identical to what it was at `eba1f52`, so adding NC would
  assert a divergence that does not exist and would simultaneously excuse NC from Layer B's
  `structurallyIdentical` check, which is the check that would catch a Bailey rule arriving by accident.
- `layerAProvenDivergentJurisdictions` (currently `[iowa, newMexico, georgia, utah]`) asserts at least
  one scenario in the fixed 10-scenario grid diverges. Nothing diverges, so it would fail outright.

**[MEASURED]** The full suite confirms NC still passes both checks unchanged, which is the positive
evidence that this task is inert.

## 8. FROZEN BASELINE

**Zero movements.** `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` is untouched
and carries no NC entry. No config changed, so no computed value moved anywhere. The frozen 1,020-value
baseline is frozen.

## 9. THE CAP BAN, confirmed rather than assumed

The brief said Bailey is uncapped so the phase-wide ban should not bind, and told me to confirm.
**Confirmed, two ways.** **[QUOTED]** NC-3's own source: "All distributions from a qualifying Bailey
retirement account...are exempt from state income tax regardless of the source of the funds contained
in the account", with no dollar cap stated. **[MEASURED]** `theCapBanIsNotWhatBlocksNorthCarolina`
switches on the declined rule's `treatment` by CASE and asserts it is not `.partial` or
`.steppedPhaseoutByFilingStatus`. And because North Carolina ships no rule at all, Task 6's 51-state
`noShippedPerSourceRuleIsCapped` sweep is vacuously satisfied for NC and stays green.

## 10. DATAMANAGER MIRROR VERIFICATION

`northCarolinaIsUnaffectedByClassification` sweeps **all of `PlanSource.allCases`** and asserts three
things per source: that `breakdown.totalStateTax` equals `calculateStateTaxFromGross`, that
`breakdown.pensionExemptAmount` is zero (a total-only check cannot catch a mis-attribution), and that
the computed figure is the fixture's own measured $1,486.27. The middle assertion is what would catch a
Bailey exclusion arriving through the mirror rather than through the config, which is the drift mode
that has bitten this branch five times. All pass.

I did not use a revert-mutation here, for Task 6's reason: the sweep asserts an exact attribution figure
per source rather than only agreement, which is the stronger check the mutation would stand in for. The
config mutation in section 2 was reverted and verified.

## 11. PICKER REACHABILITY

- `northCarolinaUserCanReachTheRowsTheDecisionTurnsOn`:
  `residenceNamesItsOwnJurisdiction(.northCarolina)` is **false** (NC's config names no
  jurisdiction-named source, since it ships no rules), so the generic own-state row survives and
  `options(for: .northCarolina, selected: nil)` contains both `.ownStateGovernmentPension` and
  `.otherStateGovernmentPension`. This is what makes the re-label describe a household a real user can
  actually enter, rather than a fixture-only tuple.
- `northCarolinaDoesNotPromptForClassification`: NC does NOT prompt, because
  `shouldPromptForClassification` gates on the residence carrying per-source rules. That is correct
  today (the answer would change nothing) and it is the tripwire for the day a Bailey rule ships: the
  prompt turns itself on and this whole file must be revisited in the same change.

## 12. DISCLOSURE WORDING

**None drafted, deliberately, and nothing here needs John's approval.** Shipping no rule means shipping
no `unclassifiedPensionDisclosure` sentence: Task 3b's `rulesAndDisclosuresStayInLockstep` is
bidirectional, so a sentence without a rule fails the suite. The sentence would also be **false** for
North Carolina, for Task 5's Hawaii reason: it tells a user their exclusion is waiting on
classification, and Bailey is not. A North Carolina pension can be perfectly classified and still be
taxed wrongly. Pinned by `northCarolinaShipsNoDisclosureSentence`.

### 12.1 THE ONE PLACE NORTH CAROLINA IS WEAKER THAN HAWAII

Recorded because it cuts AGAINST my decision, not for it.

**[QUOTED, Task 5 report]** Hawaii's over-taxation "is disclosed on two surfaces", and Task 5 leaned on
that. **[MEASURED]** North Carolina's is disclosed **nowhere**: grepping `IncomeSourcesView.swift`,
`MultiYearCPABriefing.swift` and `UnclassifiedPensionDisclosure.swift` for "Bailey" or "northCarolina"
returns zero hits, confirming Task 2's finding that NC discloses this nowhere. So a Bailey-vested North
Carolina retiree is over-taxed by $1,486.27 at NC-1's shape with no on-screen warning at all.

That does not argue for shipping the wrong rule, which would replace a silent over-taxation with a
silent under-taxation over a larger group. It argues for a DISCLOSURE, and it is a **Phase 6 item**:
the right shape is a Hawaii-style caption plus a CPA-briefing line, which is user-facing copy needing
John's approval, and it belongs with the caption-hoisting work Task 5 already deferred for Hawaii and
Massachusetts. It is now recorded in the catalogue entry with `theBaileyGapStaysRecorded` asserting the
phrase "disclosed NOWHERE" survives, so it cannot be quietly dropped.

## 13. WHAT I CHANGED

Three files. **No production Swift, no state config.**

| Path | Change |
|---|---|
| `RetireSmartIRATests/GoldenScenarios/statetax-2026-NC.golden.json` | 4 rows re-labelled to `ownStateOrLocal`; NC-5 out-of-state guard case ADDED; prose on NC-1, NC-3, NC-4 updated to record the decision and drop the completed re-label instruction. 4 scenarios to 5. No `name`, `tier`, `observedToday` or `expectedStateTax` touched; verified programmatically after the edits. |
| `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift` | one `NC` `knownButUnpinned` entry: the Bailey gap, the measurement, the population arithmetic, the byte-identical blocker, the honest note that the axis is possible but out of scope, and the undisclosed-on-every-surface finding. |
| `RetireSmartIRATests/Phase5bNorthCarolinaDecisionTests.swift` | NEW, 11 tests. The decision made executable. |

The deletion guard the brief asked for is `theBaileyGapStaysRecorded`, which `#require`s the NC entry
and asserts three of its phrases. Task 6 shipped an entry without a guard and a reviewer caught it;
this one has it from the start.

## 14. FULL SUITE

Command, run in the FOREGROUND with a 600000 ms timeout, from the worktree root:

```
tools/run-tests.sh
```

Output:

```
Project:  /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ eba1f52
Scope:    full suite, five to six minutes. Run this in the FOREGROUND.

================ RESULT ================
Swift Testing:  Test run with 1979 tests in 301 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2488 test(s) ran, no failures.
```

Baseline was 1,968 Swift Testing in 300 suites plus 509 XCTest. Now 1,979 in 301 plus 509: exactly one
new suite and its eleven tests, no other movement, zero failures. NC-5 is an extra scenario inside an
existing parameterized test and adds no test count. **`MultiYearPerfTests` did not fail and the
wrapper's isolation re-run was not triggered, so there is nothing to disclaim on that front.**

## 15. THINGS I FOUND WRONG IN THE BRIEF

1. **The August 1989 cutoff is wrong.** The brief says "Everyone hired into North Carolina public
   service after August 1989 is outside the class", which contradicts its own preceding sentence. The
   correct cutoff is roughly August 1984. Section 4.1. It understates the excluded group by five
   hiring cohorts and therefore understates the case for the decision the brief was steering toward.
2. **The `ownStateOrLocal`-with-no-rule objection is already answered by shipped code.** Arizona ships
   two such rows. Section 6.
3. **Hawaii's option (c) and North Carolina's are not the same kind of blocked.** The brief presents
   the axis choice as parallel across the two. Hawaii's was blocked on validatability; North Carolina's
   is not blocked at all, only out of scope. I have said so rather than borrowing Hawaii's stronger
   argument. Section 5.
4. **North Carolina is undisclosed where Hawaii is disclosed twice**, which the brief does not mention
   and which weakens the Hawaii analogy at exactly the point the brief leans on it. Section 12.1.

---

# ADDENDUM: review response (commit 2)

## A1. The catalogue shipped a WRONG durable record. Corrected, and the real defect logged

The reviewer was right and I verified every element before acting. **[QUOTED]**
`MilitaryRetirementExemption.swift:125`: `case "NC":  // North Carolina, full exemption enacted 2021`
returning `.fullyExempt`, consumed at `TaxCalculationEngine.swift:812` and `DataManager.swift:1092`,
with `IncomeSourcesView`'s `stateTreatmentHint` rendering a green "Fully exempt from North Carolina
state tax" label. My `blockedOn` said the fixture "cites no North Carolina provision covering military
retired pay" and that Task 7 therefore left the status quo. **No re-research was needed; the codebase
had already answered.** That paragraph is rewritten.

Worse, and this is the part I should have caught myself: my own
`northCarolinaIsUnaffectedByClassification` **MEASURED $1,486.27 for `uniformedServices` in North
Carolina and I passed it as expected**, without noticing it contradicts the shipped military answer for
the same money. The mechanism gates on `IncomeSource.type == .militaryRetirement`, not on
`planSource == .uniformedServices`, and the pension picker is offered unconditionally to every state,
so a North Carolina user reaches the taxed path without doing anything unusual. Task 6 found and closed
the identical divergence in Arizona (`bothMilitaryRoutesAgree`); North Carolina has no rule to close it
with.

Logged as its own `NC` `knownButUnpinned` entry with its own deletion guard,
`theMilitaryTypeVersusSourceDivergenceStaysRecorded`, which MEASURES both paths rather than restating
the entry, so it fails the day either moves, including the day someone ships the `uniformedServices`
rule that would close it. The Bailey guard now selects on `summary.contains("BAILEY")` rather than on
state alone, since North Carolina carries two entries and a state-only lookup would pass on the wrong one.

## A2. The caption: PROPOSED, shipped, awaiting John's approval

The reviewer is right that I conflated caption CREATION with the caption HOISTING Task 5 deferred.
Hawaii and Massachusetts both already HAVE captions; Task 4 shipped Massachusetts's in this same phase,
in this same file, and its comment says it "is the only surface that reaches the affected user". North
Carolina had none. Concluding that the nearest-term deliverable was a caption and then not drafting one
was the wrong call.

**RECOMMENDED, Option A, now shipping and flagged PROPOSED in the code:**

> North Carolina exempts a state, local or federal government pension under the Bailey settlement if
> you had five or more years of creditable service by August 12, 1989. This app does not model that
> vesting date, so if you qualify your North Carolina state tax may be overstated.

**Option B, rejected (shorter):**

> North Carolina exempts a government pension under the Bailey settlement only for retirees vested
> before August 12, 1989. This app does not model that vesting date, so if you qualify your North
> Carolina state tax may be overstated.

**Option C, rejected (shortest, closest to the Massachusetts cadence):**

> North Carolina exempts a Bailey-vested government pension but taxes all others. This app does not
> model Bailey vesting, so if your pension qualifies your North Carolina state tax may be overstated.

Why A. Bailey's test is not "vested before a date", it is **five or more years of creditable service as
of** that date, and that distinction is the entire question the user has to answer about themselves. B
compresses it to "vested before", which is the same imprecision the plan and the brief both made; C
drops it altogether and leaves "Bailey-vested" as an undefined term. A is longer than the Hawaii and
Massachusetts captions, which is the accepted cost, the same trade Task 6 made for Arizona.

All three follow the shared cadence ([state] [rule]; this app does not model [axis]; so [conditional]
your [state] tax may be [direction]), name the direction as **overstated** (North Carolina applies no
exclusion, so understated would be false), and carry no em dash. Unlike the other captions this one is
**hoisted to a static**, `IncomeSourcesView.northCarolinaBaileyCaption`, so it has a test seam; there
was no reason to add a third untestable view-body literal while Phase 6 is chartered to remove two.

## A3. Minors

3. Test-file header said "CLOSED on 1989-08-12". Fixed to August 1984, with the derivation spelled out.
4. `theCapBanIsNotWhatBlocksNorthCarolina` DELETED. The reviewer is right that it switched on a
   constant declared `.full` in the same file, so it could only fail if someone edited that constant.
   Task 6's `noShippedPerSourceRuleIsCapped` is the real check and covers NC vacuously. The Bailey
   uncapped finding stays in section 9 as prose, where it belongs.
5. `northCarolinaDoesNotPromptForClassification` DELETED as tautological, for the reason given.
6. Report section 2's ordering corrected in place.
7. `theOutOfStateGuardCaseStaysInTheFixture` now asserts over EVERY `otherStateOrLocal` case rather
   than `guards.first`, so a later case cannot shadow NC-5.

## A4. Minor 8, and my one disagreement: the `verification` block stays empty

**I tried it and reverted it, on measurement.** Filling NC's `verification` block fails
`StateTaxJSONEquivalenceTests` at line 764: `(jsonEncoded → 2265 bytes) == (legacyEncoded → 1269
bytes)` for `.northCarolina`. `verification` is part of the encoded `StateTaxConfig` and the frozen
legacy Swift table carries `.unverified` for NC, so filling it makes the re-encoded documents diverge.

The only way to green it is to add North Carolina to `phase5CorrectedJurisdictions`, and that has a
cost the minor did not price: **membership EXCUSES a jurisdiction from `structurallyIdentical`**, which
is precisely the mechanical tripwire that would catch a Bailey rule arriving in NC's config by
accident. My section 7 gave that as an explicit reason not to add NC, and the review upheld the Step 7
determination. Trading that guard for prose in a block that has no deletion guard of its own is the
wrong direction for the one jurisdiction in this phase whose entire finding is "no rule may ship here".

Georgia is not a counter-example. It is the only state with a filled `verification` block and it is
already in `phase5CorrectedJurisdictions` because Phase 5 genuinely changed its rates, so it had
surrendered that check for an independent reason.

Both sentences I would have written into `knownLimitations` are instead in the two NC catalogue
entries, which DO have deletion guards. That is the stronger home for them.

---

## 16. WHAT THE NEXT PERSON SHOULD KNOW

- North Carolina is **NOT fixed** and its three defects are **NOT resolved**. A green suite means North
  Carolina disagrees with NCDOR in exactly the catalogued way, which is the harness working as designed.
- The single easiest mistake available here is to read NC-1's stipulated prose, write the four-line
  rule, watch three defects go green, and ship it. That path was walked and measured in this task.
- The real fix is a Bailey-membership axis in a MODEL task, after Task 9 has wired `isSurvivorBenefit`
  into `matchedPerSourceRule` and the mirror, so both axes land in one coherent change. Weigh at that
  point whether a permanent stored field serving one state's closed and shrinking cohort earns its
  place, or whether the honest answer is a disclosure.
- The nearest-term deliverable for a North Carolina user is **not a rule, it is a caption**. Section 12.1.
