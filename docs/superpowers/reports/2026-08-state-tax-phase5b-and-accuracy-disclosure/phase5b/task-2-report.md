# Phase 5b Task 2 report: re-label the fixtures the old model forced into wrong cases, and add the missing negative

Branch `feature/state-tax-phase5b`, worktree `.worktrees/state-tax-phase5b`, from HEAD `b0039d3`.

## 1. Why a golden fixture may be edited at all, when Phase 4 froze them

Phase 4's freeze protects one specific thing: a fixture's `expectedStateTax` and its
`knownDefect.observedToday`. Those two numbers are the phase's evidence. `expectedStateTax`
was hand-derived from a published form and independently re-opened by a reviewer;
`observedToday` was measured off the running engine. Editing either to make a test pass
would destroy the only record of what the app actually does versus what the law actually
says.

Nothing in that reasoning protects a fixture's `planSource` label or its prose. Those are
the fixture's STATEMENT of the scenario, and in these three files the statement was
constrained by a model that could not express the scenario. Phase 4 recorded that fact
explicitly rather than hiding it: Vermont and DC each carry CANNOT_VERIFY paragraphs saying
the file could not be satisfied by any configuration, and Kansas's KPERS rows carry a
disclosed stretch label. Task 1 removed the constraint. Leaving the fixtures as they are
would leave three files asserting, in writing, blockers that no longer exist, and would
leave Task 3 and Task 9 writing rules against labels that mean the wrong thing.

So: labels and prose changed, numbers did not. Every `expectedStateTax`, every
`observedToday`, and every `tier` in these three files is byte-identical to what Phase 4
and Phase 5a shipped. The one new number in this task belongs to a case that did not exist
before.

## 2. Kansas: `RetireSmartIRATests/GoldenScenarios/statetax-2026-KS.golden.json`

### 2.1 Re-label

Three rows moved from `otherStateOrLocal` to `ownStateOrLocal`, in KS-4 (single KPERS),
KS-5 (MFJ, KPERS plus federal civil service) and KS-6 (MFJ, KPERS plus private). All three
are KPERS, which is the taxpayer's own state system for a Kansas resident.

KS-4's `source` string disclosed the old label as a stretch. It now states the true
position: what the label is, that Task 1 added the case and Task 2 moved the row onto it,
and why the old label was not merely imprecise. `otherStateOrLocal` exists specifically to
stop an out-of-state pension from claiming a state's own exclusion, so a Kansas rule
naming it would have exempted a California pension. That sentence now points at the new
guard case as the thing that proves it does not.

### 2.2 The new out-of-state guard case, and its derivation

Added as the SEVENTH scenario. Kansas already carried six (two personal-exemption cases and
four per-source cases), so this brings the file to seven. An earlier draft of this report
said "sixth", which was an off-by-one and is corrected here. Named:

> OUT-OF-STATE GUARD, do not simplify away: single filer, a CALIFORNIA public pension held
> by a Kansas resident, fully taxable, the case that proves a Kansas rule exempting
> ownStateOrLocal does NOT also exempt otherStateOrLocal

Inputs mirror the existing KS-3 private-pension contrast case exactly: single, primary age
68, no spouse, federal AGI $40,000, one $40,000 `definedBenefit` row. The only field that
differs from KS-3 is `planSource`, and the only field that differs from KS-4 is
`planSource`. That makes the three age-68 single cases a clean three-way discrimination on
the single axis under test.

Naming precedent came from `statetax-2026-NY.golden.json`, whose fourth scenario is "An
out-of-state public pension: capped, regression test for the design revision away from a
single .governmentPension case". New York states in the name itself both what the case is
and what design decision it defends, so a later reader cannot mistake it for a redundant
duplicate of the private-pension case and delete it. Kansas's name does the same, with an
explicit "do not simplify away", and its `source` string closes with a standing instruction
that this case must never acquire a `knownDefect` block.

Derivation of `expectedStateTax`, from the authority the Kansas fixture already carries
(ip25.pdf page 12, Schedule S Line A14, and page 6 for the deduction and exemption):

- Line A14 is a closed list of named Kansas plans and named federal plans. A California
  public retirement system is neither. No A14 subtraction is available, so the full
  $40,000 stays in federal AGI, exactly as a private-employer pension does.
- $40,000 minus $3,605 single standard deduction minus $9,160 SB1 single personal
  exemption = $27,235 taxable.
- Kansas single brackets: $23,000 at 5.2% = $1,196.00. Remaining $27,235 - $23,000 =
  $4,235 at 5.58% = $236.313.
- Total $1,432.313, rounded $1,432.31.

This is the identical arithmetic KS-3 already carries and pins, which is expected: the
whole point of the case is that Kansas taxes an out-of-state public pension the same way it
taxes a private one.

MEASURED, not predicted: the case was added with no `knownDefect` block and
`GoldenScenarioSingleYearTests` passed. That suite's `classify` returns `.matchesForm` only
when the engine's output is within $0.01 of `expectedStateTax`, and returns
`.unexplainedDisagreement` (a failure) otherwise, so a green run is the measurement that
the engine produces $1,432.31 here. That is the desirable outcome named in the dispatch:
the case is correct today and stands as a permanent guard that must keep passing after
Task 3 writes the Kansas rule.

## 3. Vermont: `RetireSmartIRATests/GoldenScenarios/statetax-2026-VT.golden.json`

### 3.1 Which cases are military, verified against the file

I agree with the controller's read, and checked it from the `name` and `source` strings
rather than the amounts. Enumerated:

| # | Name says | Source cites | Verdict |
|---|---|---|---|
| VT-1 | "CSRS pension, AGI $40,000" | Schedule IN-112 Section I, Civil Service Retirement System | CSRS |
| VT-2 | "CSRS pension, AGI $60,000" | IN-112 Section II partial worksheet | CSRS |
| VT-3 | "both spouses have CSRS pensions" | IN-112 Section I question 3 | CSRS |
| VT-4 | "one spouse's CSRS pension ... other spouse's private pension" | IN-112, earnings not covered by Social Security | CSRS |
| VT-5 | "U.S. military retired pay, AGI $100,000" | Act 71 (S.51), MILITARY RETIREMENT INCOME EXEMPTION WORKSHEET | MILITARY |
| VT-6 | "U.S. military retired pay, AGI $150,000" | Act 71 (S.51), same worksheet Section II | MILITARY |

Two military, four CSRS, as stated. VT-5 and VT-6 moved from `federalCivilian` to
`uniformedServices`. VT-1 through VT-4 were left alone, including VT-4's `privateEmployer`
row.

### 3.2 Prose that Task 1 made false

VT-1's and VT-5's `knownDefect.summary` each carried a CANNOT_VERIFY paragraph asserting
that no single `PerSourceExemptionRule` could satisfy both the $10,000 CSRS exclusion and
the uncapped Act 71 military exclusion, and that the file "cannot be fully satisfied by any
StateTaxData configuration until PlanSource gains a distinct uniformed-services case". VT-5
additionally asserted "This app's PlanSource enum has no case for military retired pay
distinct from federal civilian service".

Both now read as FORMER CANNOT_VERIFY, NOW RESOLVED, naming Task 1 as what added the case
and Task 2 as what moved the rows onto it, and naming Task 9 as what still has to write the
configuration. The mechanism sentence at the head of each summary is unchanged, because it
is still true: Vermont's shipped JSON models neither exclusion. `tier` and `observedToday`
were not touched in either.

## 4. DC: `RetireSmartIRATests/GoldenScenarios/statetax-2026-DC.golden.json`

### 4.1 SCOPE EXTENSION, FLAGGED FOR REVIEWER PUSHBACK

**The brief for this task tells me only to set the survivor flag on DC. I also re-labelled
two rows from `otherStateOrLocal` to `ownStateOrLocal`. That is beyond the brief's literal
text and was authorized by the controller in the dispatch, not by the brief. A reviewer who
disagrees should push back on this specifically.**

The rows are DC-2's $50,000 and DC-3's $25,000, both the District's own government pension.
DC-2's own prose admitted `otherStateOrLocal` was "used here as the closest available
generic" label. The justification for changing it is the same one that motivates the whole
phase: `otherStateOrLocal` means a DIFFERENT jurisdiction's system, so if it stood, Task 9's
DC rule would have to name `otherStateOrLocal` among its `matchSources`, and that rule would
then exempt a Maryland state pension held by a DC resident. D.C. Code 47-1803.02(a)(2)(N)(ii)
covers survivor benefits from the District or the federal government, and nothing else. It
is the identical mislabel to Kansas's KPERS, one jurisdiction over.

I extended scope nowhere else. In particular I did not add a DC out-of-state guard case
mirroring the new Kansas one, though the same argument would support it; that is Step 3 of
Task 9's own shared procedure and belongs to whoever writes the DC rule.

### 4.2 The survivor flag, established empirically

The dispatch was right that this needed measuring rather than assuming. What I did, in
order:

1. Wrote `RetireSmartIRATests/GoldenFixtureSurvivorFlagTests.swift` containing one probe
   that decodes
   `{"amount": 50000, "planStructure": "definedBenefit", "planSource": "federalCivilian", "isSurvivorBenefit": true}`
   into `ClassifiedPensionSource`, re-encodes it, and asserts the key survives. The probe
   is deliberately written to COMPILE against the three-field type, so the RED result is a
   measured test failure rather than a build error.
2. Ran `tools/run-tests.sh GoldenFixtureSurvivorFlagTests`. RED, with the evidence in the
   failure message:

   ```
   ✘ Test "RED probe: a decode/encode round trip preserves isSurvivorBenefit" recorded an issue:
     Expectation failed: (reencoded → "{"planSource":"federalCivilian","amount":50000,
     "planStructure":"definedBenefit"}").contains("isSurvivorBenefit")
   ```

   The key was accepted by the decoder without error and then simply was not there. That
   is the silent-loss class the dispatch named, confirmed on this exact type.
3. Added the field to `ClassifiedPensionSource` in `RetireSmartIRATests/GoldenScenario.swift`
   as `var isSurvivorBenefit: Bool? = nil`. `var` with a default, not `let`, deliberately:
   a `let` with an initial value is treated by Swift as already initialised and is excluded
   from the synthesized `init(from:)` entirely, so a fixture setting the key would still
   have decoded to `nil`. That is precisely the variant Task 1 hit on the production type
   (commit `b0e23fe`, "the survivor flag can now actually hold a value"), and mirroring its
   fix here avoided repeating it. The doc comment records the measured round-trip output so
   a later reader does not have to rediscover it.
4. Replaced the probe with four pinning tests plus the probe: a present key decodes to
   `true`; an absent key decodes to `nil`; the round trip preserves the key; DC's BUNDLED
   fixture carries exactly five flagged and two unflagged rows through `GoldenScenario.load`;
   and no fixture outside DC carries the flag at all. The last one is the regression that
   would catch a default of `false` or `true` creeping in and silently reclassifying every
   other jurisdiction's rows.

Nothing in production was touched. `matches()`, `PerSourceExemptionRule`, `DataManager`,
`IncomeSource` and `IRAAccount` are untouched, and `GoldenScenarioSingleYearTests
.singleYearStateTax` still builds its `IncomeSource` rows from `amount`, `planStructure` and
`planSource` only. The flag is fixture schema, stated but not yet consumed, which is why it
moved no number.

### 4.3 Which rows carry the flag

| Case | Rows | Flag |
|---|---|---|
| DC-1, age 55 survivor | federalCivilian $50,000 | true |
| DC-2, age 65 survivor | ownStateOrLocal $50,000 | true |
| DC-3, MFJ both survivors | federalCivilian $30,000, ownStateOrLocal $25,000 | true, true |
| DC-4, one survivor spouse | federalCivilian $30,000 | true |
| DC-4, private spouse | privateEmployer $60,000 | absent |
| DC-5, OWN federal pension | federalCivilian $50,000 | absent |

DC-1 is flagged even though it fails the age gate and is fully taxable. That is deliberate:
it is a survivor benefit whose holder is 55, and it is the contrast case that proves the age
gate does the work. If it were left unflagged, a Task 9 rule that forgot the age gate
entirely would still leave DC-1 green, for the wrong reason.

**A near miss worth recording.** My first pass set the flag by matching row text, and
`{"amount": 50000, ..., "planSource": "federalCivilian"}` occurs twice in this file: DC-1
and DC-5. The bulk edit flagged DC-5, the OWN pension, which is the one row in the file
whose entire purpose is to be the survivor rule's negative. I caught it on the verification
readback and reverted that row.

**CORRECTED after review.** The first version of this section claimed the guard test made
that slip impossible to repeat silently. It did not. That test asserted only file-wide
COUNTS, five flagged and two unflagged, and the two rows in question are byte-identical
apart from the flag, so swapping them leaves both counts at five and two and the test stays
green with DC-5 wrongly flagged. The reviewer caught the overstatement. The test is now
`dcFixtureFlagsEachSurvivorRowByCase` and asserts the expected flag per CASE and per ROW
POSITION, keyed on a distinguishing substring of each scenario's name, with a separate
assertion that each substring matches exactly one scenario so a rename cannot drop a case
out of the sweep. The swap now fails, which is what the earlier claim should have required
before being made.

### 4.4 Prose that Task 1 made false

DC-2's `source` asserted that the PlanSource enum has no case for the District government,
that `otherStateOrLocal` was the closest available generic, and that `ClassifiedPensionSource`
has no survivor-versus-own flag with the distinction stipulated in prose only. All three
statements are now false. Rewritten to state the current labels, name Task 1 and Task 2 as
what removed each blocker, record the measured silent-drop that motivated the schema change,
and note explicitly that nothing consumes the flag yet so the pins did not move.

DC-3's and DC-4's `knownDefect.summary` each carried the CANNOT_VERIFY paragraph about
`ClassifiedPensionSource` needing a survivor-versus-own flag. Both now read FORMER
CANNOT_VERIFY, NOW RESOLVED with the same attribution. Their mechanism sentences, `tier`
and `observedToday` are unchanged.

DC-5's prose was left alone: its claims are about the expired (N)(i) provision and the
current D-40 booklet, and none of them were made false by Task 1.

## 5. Did any pinned value move

No. This is the expected outcome and it held.

The structural reason is checkable rather than merely asserted: only one shipped state
configuration carries a `perSourceExemptions` key at all.

```
$ grep -l "perSourceExemptions" RetireSmartIRA/Resources/StateTaxData/2026/*.json
RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NY.json
```

`planSource` reaches the tax computation only through `TaxCalculationEngine.swift:620,644`
and `DataManager.swift:832,844`, all four of which call `matchedPerSourceRule`. With no
Kansas, Vermont or DC rule to match, re-labelling those rows cannot change an output. The
survivor flag has no consumer at all yet.

`RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` is untouched, and the
frozen 1,020-value baseline suite is green. No new ledger entry was needed, which is the
outcome the dispatch predicted.

## 6. Full suite

RED probe run, before the schema change:

```
$ tools/run-tests.sh GoldenFixtureSurvivorFlagTests
Swift Testing:  Test run with 1 test in 1 suite failed
✘ Expectation failed: (reencoded → "{"planSource":"federalCivilian","amount":50000,
  "planStructure":"definedBenefit"}").contains("isSurvivorBenefit")
```

Scoped golden run, after all fixture and schema changes:

```
$ tools/run-tests.sh GoldenFixtureSurvivorFlagTests GoldenScenarioSingleYearTests \
    GoldenScenarioCoverageTests GoldenScenarioDefectCatalogueTests
Swift Testing:  Test run with 19 tests in 4 suites passed
PASS. 19 test(s) ran, no failures.
```

Full suite, foreground, in the worktree:

```
$ tools/run-tests.sh
Project:  /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ b0039d3
Scope:    full suite, five to six minutes. Run this in the FOREGROUND.

================ RESULT ================
Swift Testing:  Test run with 1885 tests in 295 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2394 test(s) ran, no failures.
```

Against the 1,880-in-294 baseline: +5 Swift Testing tests in +1 suite, which is exactly
`GoldenFixtureSurvivorFlagTests` and nothing else. XCTest unchanged at 509. Zero failures,
so `MultiYearPerfTests` did not flake on this run and no isolation re-run was needed.

One discrepancy from the stated baseline: the wrapper printed no "Skipped" line, where the
baseline mentions 6 pre-existing env-gated skips. The wrapper only prints that line when its
grep matches, and it reports zero failures either way, so this is a summary-formatting
difference rather than a behavioral one. The env-gated audit-harness tests are gated on
`TEST_RUNNER_RUN_AUDIT_HARNESS`, which was not set on any of these runs, exactly as on the
baseline run. I did not chase it further because nothing in this task touches that gate.

## 7. Where I disagreed with the dispatch, and what I checked

I agreed with all four of the controller's resolutions and verified each against the files
rather than accepting it:

- **Vermont's military cases.** Verified from `name` and `source`, tabulated in section 3.1.
  The controller's read was correct.
- **The DC label extension.** Verified that DC-2's own prose already conceded the label was
  a generic stand-in, and that only two rows carry it. Adopted, and flagged as a scope
  extension in section 4.1.
- **The survivor flag hazard.** Verified by running the RED probe rather than by reading the
  type. It reproduced exactly as described.
- **The new Kansas case.** Verified the New York precedent first, mirrored KS-3's inputs
  field by field, derived the value from the fixture's own cited arithmetic, and measured
  rather than predicted the engine's agreement.

Two things I would flag for the reviewer beyond the scope extension:

1. **DC-1 being flagged is a judgement call.** The brief says to set the flag on "the
   survivor-benefit cases". DC-1 is a survivor benefit that is fully taxable because the
   holder is 55. Flagging it is what makes Task 9's age gate load-bearing; not flagging it
   would make DC-1 pass for the wrong reason under a rule with no age gate. I flagged it,
   and section 4.3 says why. A reviewer who reads "survivor-benefit cases" as "the cases
   where the exemption applies" would flag only DC-2, DC-3 and DC-4, and
   `dcFixtureCarriesTheFlag` would then need to expect four and three rather than five and
   two.
2. **The new Kansas guard case does not yet defend against everything it looks like it
   defends against.** It proves a Kansas rule will not exempt `otherStateOrLocal`. It does
   NOT prove anything about `governmentUnspecified`, which is the label a NY-state
   employee's 403(b) carries and which a careless Kansas rule could also list. If Task 3
   wants that covered, it should add the case itself, per Step 3 of its own procedure.

## 8. Files changed

- `RetireSmartIRATests/GoldenScenarios/statetax-2026-KS.golden.json`: three KPERS rows
  re-labelled, KS-4's disclosure prose corrected, one new out-of-state guard scenario added.
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-VT.golden.json`: VT-5 and VT-6
  re-labelled to `uniformedServices`, VT-1 and VT-5 CANNOT_VERIFY prose corrected.
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-DC.golden.json`: two rows re-labelled
  to `ownStateOrLocal`, five survivor rows flagged, DC-2 source and DC-3/DC-4 CANNOT_VERIFY
  prose corrected.
- `RetireSmartIRATests/GoldenScenario.swift`: `ClassifiedPensionSource` gains
  `var isSurvivorBenefit: Bool? = nil`, test-only.
- `RetireSmartIRATests/GoldenFixtureSurvivorFlagTests.swift`: new, five tests.

---

# Fix pass: the five review findings

Reviewer returned SPEC COMPLIANCE: PASS, sided with me on both flagged items (the DC
re-label to `ownStateOrLocal`, and flagging DC-1), and returned two Important plus three
Minor findings. All five are fixed here in one commit. Two further Minors the coordinator is
recording in the phase ledger were deliberately not touched.

## Important 1: the guard test asserted counts, not identity

The finding is correct and the criticism is exact. `dcFixtureCarriesTheFlag` asserted five
flagged rows and two unflagged rows, file-wide. DC-1's row and DC-5's row differ only by the
flag, so swapping them holds both counts and the test passes with DC-5, the survivor rule's
designated negative, wrongly flagged. The test claimed to catch the near miss that actually
happened during this task, and would not have caught it.

Replaced with `dcFixtureFlagsEachSurvivorRowByCase`, driven by a `dcExpectedFlags` table of
`(nameContains, flags)` pairs, one per case, with `flags` ordered by row position within the
case. Three assertions now hold it up: the scenario count must equal the expectation count,
so a case added or removed forces a decision about its flag; each `nameContains` must match
exactly ONE scenario, so a rename fails loudly rather than dropping a case out of the sweep;
and each case's `[Bool?]` flag vector must equal its expectation exactly. Keyed on name
substrings rather than indices so reordering the fixture cannot silently re-point an
expectation at the wrong case. DC-1 to DC-5 map to `[true]`, `[true]`, `[true, true]`,
`[true, nil]`, `[nil]`, and the DC-1/DC-5 swap now fails on both cases.

Both overstatements corrected: the test's own doc comment now says plainly what the count
version missed and why, and report section 4.3 carries an explicit CORRECTED paragraph
rather than a silent rewrite.

VERIFIED BY MUTATION, not by reasoning. The DC-1/DC-5 flag swap was applied to the fixture
and the suite run:

```
$ tools/run-tests.sh GoldenFixtureSurvivorFlagTests     # with DC-1 and DC-5 flags swapped
Swift Testing:  Test run with 5 tests in 1 suite failed
'DC's bundled fixture flags each survivor row, case by case, and never DC-5' recorded an issue:
  Expectation failed: (flags -> [nil]) == (expectation.flags -> [Optional(true)])
'DC's bundled fixture flags each survivor row, case by case, and never DC-5' recorded an issue:
  Expectation failed: (flags -> [Optional(true)]) == (expectation.flags -> [nil])
```

Two issues, one per swapped case, which is the mutation the count-based version passed. The
swap was then reverted and the fixture re-verified against `git show HEAD:` for structural
equality outside `source`, so nothing from the mutation survived.

## Important 2: stale prose in four other jurisdictions

Confirmed and fixed, prose only. No `planSource` value, no `expectedStateTax`, no
`observedToday`, no `tier` changed in any of the four files. Verified mechanically rather
than by eye: a script re-parsed each file, stripped `source` and `knownDefect.summary`, and
compared the remaining structure to `git show HEAD:<path>`. All four came back identical.

Each replacement does the three things the coordinator asked for, rather than deleting the
stale sentence: it says the case now EXISTS, names it, and states that THIS ROW'S LABEL
STILL NEEDS CHANGING in that jurisdiction's own task. Each also names the specific wrong
rule the stale text would have invited, because "re-label this" is easier to skip than "a
rule against `federalCivilian` would hand three civilian retirees an exclusion Arizona does
not grant."

- **AZ-3** (`knownDefect.summary`): `uniformedServices` exists, re-label in Task 6, and do
  not write Line 29b's 100% exclusion against `federalCivilian`, because AZ-1, AZ-4 and
  AZ-5 are federal CIVILIAN pensions on the $2,500 Line 29a cap. The existing PHASE 5
  WARNING about every civilian amount sitting under the cap is untouched.
- **ID-3** (`source`): `uniformedServices` exists, re-label in Task 8, and note that Line
  8e's service-member age test is more lenient than Part One's general gate, so a rule
  against `federalCivilian` would apply the lenient test to ID-1, ID-2, ID-4 and ID-5,
  wrong for ID-1 at age 60 in the opposite direction from the defect being fixed.
- **MA-4** (`source`): `uniformedServices` exists, re-label in Task 4, do not write the
  military exclusion against `federalCivilian`.
- **MA-1** (`source`): `ownStateOrLocal` exists, re-label MA-1 and MA-3 in Task 4, and ADD
  an out-of-state guard case, named as the same mislabel Kansas carried with the California
  consequence spelled out.
- **MA-3** (`source`): forward pointer to MA-1's instruction.
- **NC-1, NC-3, NC-4** (`source`): the same, pointing at Task 7, with the instruction
  stated as holding whichever way Task 7 rules on the vesting-date axis. NC-4's note also
  says its private-pension row is correctly labelled and stays, so the instruction is not
  read as applying to both rows.

**One correction to the finding.** It says NC scenarios 1, 3 and 4 carry the "no
state-specific case; `otherStateOrLocal` is the closest available generic" disclosure, and
that MA scenario 3 does. They do not. Grepping the fixture set for both
`PlanSource enum has no` and `closest available` returns AZ, ID, MA and DC only, never NC,
and within MA only scenarios 1 and 4. NC's rows carry the mislabel with no disclosure at
all, and MA-3 and NC-3/NC-4 inherit theirs by a "see the single-filer case above" reference.
That makes the underlying finding WORSE, not better: those rows are mislabelled and were not
disclosed anywhere, so a Task 4 or Task 7 implementer reading MA-3 or NC-3 in isolation
would have seen nothing at all. I added the forward instruction to them rather than
correcting a sentence that was not there.

## Minor 3: a new false statement in my own DC prose

Confirmed. My rewrite widened the collision list to "DC-2/DC-3/DC-4 (survivor) and DC-5",
while the same edit moved DC-2's row off `federalCivilian` onto `ownStateOrLocal`, making
the sentence false about the row printed directly beneath it. Restored to DC-3/DC-4 and
added one sentence saying why DC-2 is no longer part of that collision and why it carries
the flag anyway: the statute exempts survivor benefits from the District OR the federal
government, so Task 9's rule has to match the survivor fact across both sources.

## Minor 4: swallowed load failures

Confirmed. `onlyDCUsesTheFlagToday` now uses `try`, not `try?`, with a comment recording
that every abbreviation in `covered` is guaranteed to load by
`GoldenScenarioCoverageTests.everyJurisdictionHasAFixture`, so a throw is a real regression
and swallowing it would make the sweep quietly stop checking whatever file broke.

## Minor 5: sixth versus seventh scenario

Confirmed. Kansas carried six scenarios and the guard is the seventh. Section 2.2 corrected
in place, with the off-by-one noted rather than silently swapped.

## Full suite after the fix pass

```
$ tools/run-tests.sh
Project:  /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ 8c58d28

================ RESULT ================
Swift Testing:  Test run with 1885 tests in 295 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2394 test(s) ran, no failures.
```

Same totals as the Task 2 commit: the guard test was rewritten, not added, so the count is
unchanged at 1,885 in 295 suites. No pin moved, in any of the seven fixtures now touched
across both commits. `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`
remains untouched.

## Observation for the ledger (SUPERSEDED, now fixed: see the second fix pass below)

`statetax-2026-AZ.golden.json` scenario 4 carries an `otherStateOrLocal` row for what its
name calls a government pension qualifying under Arizona's Line 29a, alongside a
`federalCivilian` row. Line 29a covers US government and Arizona state and local pensions,
so that row is most likely Arizona's OWN system carrying the same mislabel MA and NC carry.
It was not on the finding list and I did not touch it. Recording it here so Task 6 sees it,
since AZ-4 has no disclosure prose of its own and would otherwise be invisible the same way
MA-3 and NC-3 were.

---

# Second fix pass: the two remaining Minors

Re-review came back SPEC PASS and CODE QUALITY APPROVED, no Critical and no Important, with
the DC-1/DC-5 mutation reproduced independently rather than taken on trust, and my
disagreement about the finding's scope adjudicated in my favour. Two cheap Minors remained.

## Minor 1: AZ-4 got the observation but not the instruction

The reviewer is right, and the criticism lands on my own reasoning rather than on the code.
I recorded AZ-4 in the closing observation above, including the sentence "would otherwise be
invisible the same way MA-3 and NC-3 were", and then left it invisible. Task 6 will read the
fixture, not this report and not the phase ledger. Five other rows in the same batch got a
one-line pointer for exactly that reason; there was no principled distinction that gave AZ-4
only a footnote.

Fixed in `statetax-2026-AZ.golden.json` AZ-4's `source`, prose only. The label, the
`expectedStateTax` of $1,312.50 and the `observedToday` pin are untouched, verified the same
way as the earlier four: re-parse, strip `source` and `knownDefect.summary`, compare to
`git show HEAD:`, identical.

The wording states the inference rather than asserting the label is wrong by fiat, because
the fixture never says outright which government the pension comes from: for AZ-4's expected
figure to be correct that pension must QUALIFY under Line 29a, Line 29a covers US government
plus Arizona state and local pensions, the other row already carries `federalCivilian`, so
this row must be Arizona's OWN system. It then names the trap in the same shape the other
five got: a Task 6 rule that must exempt this row would name `otherStateOrLocal` and thereby
exempt a California public pension held by an Arizona resident, which Line 29a does not
cover. The re-label itself stays with Task 6, so it lands with the rule and its guard case,
as Kansas did.

The closing observation section above is retitled as superseded rather than deleted, so the
sequence stays legible: it was recorded honestly, then acted on.

## Minor 3: the per-case sweep never asserted DISTINCT matches

Correct, and it is the same class of hole as the count-based version the previous pass
replaced. `file.scenarios.count == dcExpectedFlags.count` plus "each substring matches
exactly one scenario" both hold if a rename merges two substrings onto ONE scenario name:
five expectations, five scenarios, every substring matching exactly one case, and one case
asserted by nothing at all.

The loop now iterates `file.scenarios.enumerated()`, collects each match's offset into a
`Set<Int>`, and asserts `matchedIndices.count == dcExpectedFlags.count` after the loop. Two
expectations landing on the same case collapse the set and fail.

## Full suite after the second fix pass

```
$ tools/run-tests.sh
Project:  /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ 67dc405

================ RESULT ================
Swift Testing:  Test run with 1885 tests in 295 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2394 test(s) ran, no failures.
```

Totals unchanged again: an assertion was added inside an existing test, not a new test. No
pin moved in any of the eight fixtures now touched across the three commits, and
`RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` is still untouched.

## Left alone deliberately

DC-3's and DC-4's `knownDefect.summary` both claim "both parties are 62 or older in every
case", and DC-4's are 65 and 60. The claim is literally false, though the argument it
supports survives because the 60-year-old holds the `privateEmployer` row and so is not part
of the collision being described. Present at `b0039d3` and untouched by all three of my
commits, so it predates this branch. The coordinator is recording it for Task 9, which will
read those summaries when writing the survivor rule. Not touched here.
