# Task 1 Report: The `knownDefect` mechanism

Status: verification and evidence pass. The code was already correct in the working
tree (matches the brief exactly, confirmed by re-reading `GoldenScenario.swift` and
`GoldenScenarioSingleYearTests.swift` against Steps 1, 3, and 5 of the brief before
touching anything). This report covers Steps 2 through 8.

## Step 2/6: Full suite, first pass (before mutation)

Command:

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
```

Run in the foreground, redirected to a log file rather than piped through `tail`
directly (see Deviation 1 below), exit code 0.

Verbatim result lines:

```
Executed 509 tests, with 0 failures (0 unexpected) in 22.625 (22.809) seconds
Test Suite 'All tests' passed at 2026-08-04 11:34:13.604.
Executed 509 tests, with 0 failures (0 unexpected) in 22.625 (22.810) seconds
Test run with 1845 tests in 290 suites passed after 331.685 seconds.
** TEST SUCCEEDED **
```

This is 1,845 Swift Testing tests in 290 suites plus 509 XCTest tests. The brief's
stated baseline was 1,752 Swift Testing tests in 285 suites plus 505 XCTest, "now +2"
for this task. The observed counts are well above baseline+2 (93 more Swift Testing
tests, 5 more suites, 4 more XCTest tests). This is not attributable to this task's
two new tests; the working tree already carries other uncommitted/prior work on this
branch beyond `GoldenScenario.swift` and `GoldenScenarioSingleYearTests.swift` (a
Display Audit Harness suite, `DisplayInvariantsTests`, `DisplaySnapshotTests`, and
others visible in the full log, none of which this task touched). `git status --short`
before and after this task's work shows only the two files this task modified are
dirty, so the extra tests are already committed on this branch from prior phases, not
something this pass introduced. Recorded as an observation, not treated as a defect,
since the brief's own "0 failures" bar is what governs pass/fail here.

## Step 7: Mutation proof

Fixture under test: `RetireSmartIRATests/GoldenScenarios/statetax-2026-PA.golden.json`,
its only (first) scenario, `"retiree, pension and IRA fully exempt"`.

### Mutation A: deliberately wrong `observedToday: 999.0`

Added:

```json
"knownDefect": {"tier": "tier1", "summary": "mutation probe", "observedToday": 999.0}
```

Command:

```
xcodebuild test -project .../RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests
```

Verbatim failure (first `#expect`, the observed-value pin, fires as required):

```
✘ Test "Single-year path matches each state's own published form" recorded an issue with 1 argument abbreviation → "PA" at GoldenScenarioSingleYearTests.swift:135:17: Expectation failed: (abs(actual - defect.observedToday) → 999.0) < 0.01
↳ PA / retiree, pension and IRA fully exempt: engine now 0.0, pinned observed value 999.0.
  A DEFECTIVE state moved. Diagnose what changed before touching this pin.
  Defect: mutation probe
```

This confirms the first branch of the `if let defect` logic fails when the pin
disagrees with the engine's real output.

Note: because PA's fixture in fact has no real defect (its engine output already
equals its published form, both 0.0), the second `#expect` on the same run also
fired, since actual (0.0) trivially equals `expectedStateTax` (0.0):

```
✘ ... at GoldenScenarioSingleYearTests.swift:142:17: Expectation failed: (abs(actual - scenario.expectedStateTax) → 0.0) >= 0.01
↳ PA / retiree, pension and IRA fully exempt now MATCHES its published form (0.0). The defect appears to be FIXED.
  Delete the knownDefect block from this fixture so the case becomes a
  normal passing assertion. Do not update observedToday to keep it quiet.
```

Both `#expect`s in a Swift Testing function run independently (unlike `#require`),
so this is expected, not a problem: the brief's requirement was that the FIRST
`#expect` fail, and it did, with the exact failure message pinned above. The
mutation also incidentally failed the pre-existing `absentKnownDefectDecodesNil`
test (because it now loads a PA fixture that does carry a `knownDefect`), which is
the correct and expected side effect of mutating a fixture that test also reads,
not a defect in the mechanism.

The engine's real output for this scenario, read directly from the failure message
above, is `0.0`.

### Mutation B: `observedToday` set to PA's real observed figure (0.0)

Changed to:

```json
"knownDefect": {"tier": "tier1", "summary": "mutation probe", "observedToday": 0.0}
```

Same command, re-run. Verbatim failure, now ONLY the second `#expect` fires:

```
✘ Test "Single-year path matches each state's own published form" recorded an issue with 1 argument abbreviation → "PA" at GoldenScenarioSingleYearTests.swift:142:17: Expectation failed: (abs(actual - scenario.expectedStateTax) → 0.0) >= 0.01
↳ PA / retiree, pension and IRA fully exempt now MATCHES its published form (0.0). The defect appears to be FIXED.
  Delete the knownDefect block from this fixture so the case becomes a
  normal passing assertion. Do not update observedToday to keep it quiet.
```

The first `#expect` (the pin) now passes, because `actual` (0.0) matches
`observedToday` (0.0). Only the second `#expect` fails, exactly as the brief
predicts: this is the self-cleaning behavior, the pin forces deletion of a
`knownDefect` block once the state's output genuinely matches its published form.
(`absentKnownDefectDecodesNil` still fails too, for the same reason as Mutation A;
same expected side effect, not part of what Step 7 asks to demonstrate.)

Both branches of the `if let defect` logic have now each been shown to fail on
their own dedicated line.

### Revert

```
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 checkout -- RetireSmartIRATests/GoldenScenarios/statetax-2026-PA.golden.json
```

Evidence, `git status --short`:

```
 M RetireSmartIRATests/GoldenScenario.swift
 M RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
```

Evidence, `git diff -- RetireSmartIRATests/GoldenScenarios/` (empty, confirmed by
running it and getting no output):

```
(no output)
```

Only the two files this task is scoped to change are dirty. The PA fixture is back
to its original committed content.

## Step 4: Production diff

```
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 diff --stat main -- RetireSmartIRA/
```

Output: empty (no output). Nothing under `RetireSmartIRA/` differs from `main`.
Phase 4 corrects no tax value and touches no production file, confirmed.

## Step 5: Full suite, final pass (after revert)

First attempt at this step, run in the foreground with `timeout: 600000`, was
killed by the harness's own timeout (exit 137) partway through
(`DisplaySnapshotTests`), after about 1,896 log lines versus roughly 6,000 in a
completed run. A stray `xcodebuild`/`xctest` process was still alive afterward
(`ps aux` showed a PID with only 2s of CPU time sitting since the timeout fired);
it was killed with `pkill -9 -f xcodebuild; pkill -9 -f xctest` before retrying,
on the theory that a leftover process from the killed run was contending for the
simulator/build lock. The retry, same command, completed cleanly:

```
Executed 509 tests, with 0 failures (0 unexpected) in 21.809 (22.007) seconds
Test Suite 'All tests' passed
Executed 509 tests, with 0 failures (0 unexpected) in 21.809 (22.008) seconds
Test run with 1845 tests in 290 suites passed after 318.916 seconds.
** TEST SUCCEEDED **
```

Exit code 0. Same counts as the pre-mutation run (1,845 Swift Testing / 290 suites,
509 XCTest), confirming the revert left the suite exactly as it was before the
mutation work and that it is genuinely green, not just green because the mutated
fixture was still in place.

A line in this log reading `hard failures: 0` (line 5799) is a pre-existing test's
own diagnostic output, unrelated to this task and unrelated to any harness gate;
noted only so it isn't mistaken for something this task introduced.

## Step 6: Em dash check

Searched both modified files for the literal em dash character (U+2014) using a
shell grep with the character passed via `$'...'` ANSI-C quoting (not reproduced
here verbatim, to avoid placing the character itself in this report).

No matches (grep exit code 1) in either modified file.

## Deviations from the brief

1. The brief's suggested commands pipe `xcodebuild` output through `tail`
   (`... 2>&1 | tail -40`). The first attempt at the Step 2 full-suite run using
   that exact form returned only `Exit code 1` with no captured output, which is
   not useful as evidence and does not by itself mean the suite failed (a `tail`
   pipeline's exit status reflects `tail`, not `xcodebuild`, once truncated by an
   agent-side limit). Every subsequent run redirected full output to a log file
   under the scratchpad directory and then grepped/tailed that file, so the exact
   exit code of `xcodebuild` itself could be captured and quoted (`echo
   "EXIT_CODE=$?"` immediately after). This produced the verbatim result lines
   quoted above and is a strictly more verifiable substitute for the brief's
   command, not a different test run.
2. One full-suite run (the first attempt at Step 5) was killed by the tool's own
   600000ms timeout before completing, apparently because a prior mutation-testing
   `xcodebuild` invocation left an orphaned process contending for the build/test
   lock. This was diagnosed via `ps aux`, the stray process was killed, and the
   run was repeated to a clean, complete, green result (quoted above). No source
   file was touched between the killed attempt and the successful retry; this is
   a process-hygiene issue with running several `xcodebuild test` invocations
   back to back in one session, not evidence of flakiness in the suite itself.

No other deviations. Steps 1 and 3 (the `KnownDefect` type and the two-branch
assertion) were not rewritten; they were read and confirmed to match the brief.

## Commit

```
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/GoldenScenario.swift RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): pin known defects instead of tolerating them"
```

---

## Follow-up fixes (review findings 1 and 2, applied to edfcccc)

Two review findings, both traced to errors in the plan text, applied on top of the above.

### Finding 1: no permanent test for the branch logic

Extracted the two-branch decision in `singleYearMatchesGolden` into a pure static
function, per the brief's design.

Placement: added `GoldenComparison` and `static func classify(actual:scenario:)`
to `GoldenScenarioSingleYearTests` (not `GoldenScenario.swift`). Reasoning: the
enum and function express a TEST decision (what the golden-scenario suite does
with an engine result), not a property of the fixture data model itself.
`GoldenScenario.swift` stays a plain Codable data type with no test-specific
vocabulary. Keeping `classify` next to `singleYearMatchesGolden` also means a
reader sees the extracted logic right above its one caller.

Changes in `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`:
- Added `GoldenComparison: Equatable` with the five cases from the brief verbatim
  (`matchesForm`, `pinnedDefectHolds`, `pinnedDefectMoved`, `defectAppearsFixed`,
  `unexplainedDisagreement`), and `static func classify(actual:scenario:)` with
  the `defectAppearsFixed`-before-pin-check ordering the brief specified.
- Rewrote `singleYearMatchesGolden`'s loop body to `switch` on
  `Self.classify(actual:scenario:)`. `.matchesForm` and `.pinnedDefectHolds` are
  the passing cases (no-op). The three failing cases each emit
  `#expect(Bool(false), "...")` with the original failure message wording
  preserved as closely as possible (same wording, now built from the enum's
  associated values instead of the scenario/defect directly).
- Replaced `knownDefectMechanismRoundTrips` (which only round-tripped a JSON
  literal through the decoder and never drove the branch) with
  `classifyCoversAllOutcomes`, which calls `classify` directly across all five
  outcomes, including an explicit case proving `defectAppearsFixed` wins over
  `pinnedDefectMoved`/`pinnedDefectHolds` when a defect is present but the actual
  now matches the form. Used plain sequential `#expect` calls inside one `@Test`
  rather than `@Test(arguments:)` with tuples: no existing test in this repo uses
  tuple-array arguments, and I did not want to gamble the build on unverified
  support for that call shape in this project's Swift Testing version. Backed by
  a small `static func makeScenario(expectedStateTax:knownDefect:)` helper that
  builds a `GoldenScenario` directly via its synthesized memberwise initializer
  (no JSON), with fixed placeholder values for every field `classify` does not
  read.
- Kept `absentKnownDefectDecodesNil` unchanged, as instructed.

No JSON-decoding assertion for the new optional fields was kept as a separate
test (the brief's fallback instruction did not apply: nothing decode-related was
left over from the deleted test).

### Finding 2: false present-tense claim in the `otherOrdinaryIncome` doc comment

`RetireSmartIRATests/GoldenScenario.swift`, the `otherOrdinaryIncome` doc
comment. Confirmed against `RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json`
that no fixture (New York's first scenario included) sets `otherOrdinaryIncome`;
the $20,000 currently lives only in that fixture's prose `source` string, exactly
as the finding describes.

Replaced the false "is the precedent and ... the only user of it" paragraph with:

> No fixture sets this field yet. It exists for New York's first fixture, whose
> `federalAGI` of $90,000 stands against a $70,000 classified government pension,
> leaving $20,000 of unrelated ordinary income currently described only in that
> fixture's prose `source` string. A later task moves that $20,000 into this
> field.

The DECLARATIVE ONLY paragraph and the cross-path paragraph were left untouched.

## Step 2 (re-run): focused suite after both fixes

Command:
```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests
```

Result (verbatim tail):
```
✔ Test "Single-year path matches each state's own published form" with 5 test cases passed after 0.008 seconds.
◇ Test "classify covers all five outcomes of the defect-pin decision" started.
✔ Test "classify covers all five outcomes of the defect-pin decision" passed after 0.001 seconds.
◇ Test "A fixture with no knownDefect decodes it as nil" started.
✔ Test "A fixture with no knownDefect decodes it as nil" passed after 0.001 seconds.
✔ Suite "Golden scenarios, single-year path" passed after 0.010 seconds.
✔ Test run with 3 tests in 1 suite passed after 0.010 seconds.
** TEST SUCCEEDED **
```

## Step 3: proof the new test can fail

Temporarily inverted the pin comparison inside `classify`:
```swift
return abs(actual - defect.observedToday) < tolerance
    ? .pinnedDefectMoved(actual: actual, pinned: defect.observedToday)   // was .pinnedDefectHolds
    : .pinnedDefectHolds                                                 // was .pinnedDefectMoved(...)
```

Re-ran the same focused suite. `classifyCoversAllOutcomes` FAILED with two
issues, verbatim:
```
✘ Test "classify covers all five outcomes of the defect-pin decision" recorded an issue at GoldenScenarioSingleYearTests.swift:216:9: Expectation failed: (Self.classify(actual: 1200, scenario: withDefect) -> .pinnedDefectMoved(actual: 1200.0, pinned: 1200.0)) == .pinnedDefectHolds
-> // knownDefect present, engine still produces the pinned figure.
✘ Test "classify covers all five outcomes of the defect-pin decision" recorded an issue at GoldenScenarioSingleYearTests.swift:220:9: Expectation failed: (Self.classify(actual: 1300, scenario: withDefect) -> .pinnedDefectHolds) == (.pinnedDefectMoved(actual: 1300, pinned: 1200) -> .pinnedDefectMoved(actual: 1300.0, pinned: 1200.0))
✘ Test "classify covers all five outcomes of the defect-pin decision" failed after 0.001 seconds with 2 issues.
✘ Suite "Golden scenarios, single-year path" failed after 0.006 seconds with 2 issues.
✘ Test run with 3 tests in 1 suite failed after 0.006 seconds with 2 issues.
** TEST FAILED **
```
(`singleYearMatchesGolden` and `absentKnownDefectDecodesNil` still passed;
only the new unit test caught the inversion, exactly as intended.)

Reverted the inversion back to the original ordering. Confirmed the revert is
clean:
```
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 diff RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
```
shows only the intended net changes from before the inversion (the `? .pinnedDefectHolds : .pinnedDefectMoved(...)` ordering matches the original edit, not the inverted one).

## Step 4: full suite after both fixes

Command:
```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
```

Result (verbatim tail):
```
✔ Test run with 1845 tests in 290 suites passed after 314.703 seconds.
** TEST SUCCEEDED **
```
Separately grepped the XCTest legacy suite line from the same kind of run:
```
Test Suite 'RetireSmartIRATests.xctest' passed at 2026-08-04 12:09:48.116.
	 Executed 509 tests, with 0 failures (0 unexpected) in 21.376 (21.696) seconds
Test Suite 'All tests' passed at 2026-08-04 12:09:48.117.
	 Executed 509 tests, with 0 failures (0 unexpected) in 21.376 (21.696) seconds
```
Total: 1845 Swift Testing + 509 XCTest, 0 failures.

## Step 5: production diff

```
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 diff --stat main -- RetireSmartIRA/
```
Output: empty. No production file touched.

## Step 6: em dash check (both modified files)

```
grep -n $'\xe2\x80\x94' RetireSmartIRATests/GoldenScenario.swift RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
```
Exit code 1 (no matches) in both files.

## Commit

```
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/GoldenScenario.swift RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): make the defect-pin decision testable, and pin it"
```
