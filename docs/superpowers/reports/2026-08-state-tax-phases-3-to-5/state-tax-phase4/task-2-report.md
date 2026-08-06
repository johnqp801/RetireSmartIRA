# Task 2 report: coverage enumeration and fixture shape invariants

## Step 1: Wrote the failing test

Created `RetireSmartIRATests/GoldenScenarioCoverageTests.swift` verbatim from the brief:
four `@Test` functions (`fixtureLoads`, `federalAGIIsInternallyConsistent`,
`citationsAreWellFormed`, `noDoubleCountedPension`), each parameterized over
`GoldenScenarioCoverageTests.covered = ["PA", "IL", "MS", "NJ", "NY"]`. The new file
sits under a file-system-synchronized Xcode group, so it needed no `project.pbxproj`
edit to be picked up by the test target.

## Step 2: Ran the coverage suite against the existing five fixtures

Command:

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioCoverageTests
```

Result: exactly one failure, on New York's first scenario, verbatim:

```
✘ Test "federalAGI equals the sum of its components" recorded an issue with 1 argument abbreviation -> "NY" at GoldenScenarioCoverageTests.swift:45:13: Expectation failed: (abs(scenario.federalAGI - components) -> 20000.0) < 0.01
-> NY / NYC employee pension alone: fully excluded, Line 26: federalAGI 90000.0 against components summing to 70000.0.
  The multi-year runner never reads federalAGI, so this mismatch would surface
  as a phantom cross-path divergence. Fix the fixture, not the engine.
  If the excess is deliberate unmodelled ordinary income, DECLARE it in
  otherOrdinaryIncome rather than leaving it implicit.
```

All other cases in `fixtureLoads`, `citationsAreWellFormed`, `noDoubleCountedPension`,
and every other case of `federalAGIIsInternallyConsistent` (PA, IL, MS, NJ, and NY's
remaining three scenarios) PASSED. No other case failed, so there was nothing to
record as a new Phase 2/3b finding and nothing to escalate about the NJ cross-path
pin.

## Step 2a: Declared New York's unmodelled income

Added `"otherOrdinaryIncome": 20000,` to the FIRST scenario only
(`"NYC employee pension alone: fully excluded, Line 26"`) in
`RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json`, placed beside
`rothConversion` as specified. No other scenario in the file, and no other fixture
file, was touched.

Re-ran the coverage suite: PASS, all four tests, all five jurisdictions, including
`federalAGIIsInternallyConsistent` on NY.

Re-ran `GoldenScenarioSingleYearTests` to confirm the field stayed declarative.
New York's four `expectedStateTax` values in the fixture, unchanged by the edit:

```
"expectedStateTax": 487.75   (scenario 1: NYC employee pension alone)
"expectedStateTax": 273.00   (scenario 2: NYC pension + private pension)
"expectedStateTax": 273.00   (scenario 3)
"expectedStateTax": 273.00   (scenario 4)
```

The suite run reported `Test "Single-year path matches each state's own published
form" with 5 test cases passed`, i.e. PA/IL/MS/NJ/NY all still matched their
form-derived values with no rebaselining. `otherOrdinaryIncome` is read only by
`GoldenScenarioCoverageTests.federalAGIIsInternallyConsistent`; it is not summed,
passed, or read anywhere in `GoldenScenarioSingleYearTests.singleYearStateTax` or in
production code (confirmed no production file was touched, see the empty diff
below).

## Step 3: Pointed the single-year suite at the shared enumeration

In `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`, replaced:

```swift
static let pilot = ["PA", "IL", "MS", "NJ", "NY"]
```

with:

```swift
/// Single source of truth for which jurisdictions are asserted. Deliberately
/// NOT a second literal list: a hand-maintained array is how a jurisdiction
/// goes missing, and this codebase already shipped that failure once
/// (StateTaxData.swift:2069 silently returned California for any unknown state).
static let pilot = GoldenScenarioCoverageTests.covered
```

No other line in that file was touched, per the brief's scoping instruction.

## Step 4: Full suite

Command:

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
```

Verbatim result lines:

```
✔ Test run with 1849 tests in 291 suites passed after 309.804 seconds.
** TEST SUCCEEDED **
```

`xcresulttool` summary for the same run: `"failedTests" : 0`, `"skippedTests" : 6`
(the env-gated 27-profile audit harness tests, which skip in the normal loop per
existing project convention), `"result" : "Passed"`.

This is baseline (1,845 Swift Testing tests / 290 suites) plus exactly the 4 new
tests / 1 new suite contributed by `GoldenScenarioCoverageTests`, with 0 failures.
The 509 XCTest tests are folded into the xcresult total above; none failed or
changed count.

## Global constraints, verified

Empty production diff:

```
$ git diff --stat main -- RetireSmartIRA/
(no output)
```

Em dash check across every file touched this task (new and modified):

```
$ grep -n em-dash-character RetireSmartIRATests/GoldenScenarioCoverageTests.swift RetireSmartIRATests/GoldenScenarioSingleYearTests.swift RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json
(no matches, grep exit code 1)
```

No em dash characters present in any file this task touched, including this report.

Only fixture file modified: `RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json`,
and only by the single declarative key described in Step 2a. Confirmed via
`git status` before staging: no other fixture under `RetireSmartIRATests/GoldenScenarios/`
appears as modified.

## Deviation from the brief, reported

The brief's Step 5 commit command stages only:

```
git add RetireSmartIRATests/GoldenScenarioCoverageTests.swift RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
```

That omits `RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json`, which
Step 2a of the same brief requires editing. Committing without it would leave the
declared `otherOrdinaryIncome` field as an uncommitted working-tree change, which
would make the coverage suite's passing state (Step 2a's own verification) not
reproducible from the commit alone, and would violate the project rule that a
change is not done until it is committed and the tree matches what was tested. I
staged and committed the NY fixture edit alongside the two files the brief names,
in the same single commit, rather than leaving it out or splitting it into a second
commit. This is a deliberate inclusion, not scope creep: it is exactly the file
Step 2a of this same task instructs modifying, and no other fixture was touched.

## Commit

```
26135cf test(state-tax): one enumeration for fixture coverage, and shape invariants
 3 files changed, 85 insertions(+), 1 deletion(-)
 create mode 100644 RetireSmartIRATests/GoldenScenarioCoverageTests.swift
```

Files in the commit:
- `RetireSmartIRATests/GoldenScenarioCoverageTests.swift` (new)
- `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift` (modified: `pilot` now derives from `GoldenScenarioCoverageTests.covered`)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json` (modified: one declarative key added to one scenario)

---

# Task 2 review-fix report (2026-08-04)

Applying four reviewer-confirmed findings on top of commit `26135cf`. Scope:
`RetireSmartIRATests/GoldenScenarioCoverageTests.swift` and
`RetireSmartIRATests/GoldenScenarioSingleYearTests.swift` only.

## Finding 1 (Important): empty-array loophole in the pension invariants

Both checks silently mishandled a fixture with `classifiedPensionSources: []`
alongside a nonzero `pensionIncome`.

**Fix, `GoldenScenarioCoverageTests.swift`:**

- Extracted `static func pensionComponent(_ scenario: GoldenScenario) -> Double`,
  the exact expression `federalAGIIsInternallyConsistent` already used
  (`classifiedPensionSources?.reduce(0) { $0 + $1.amount } ?? pensionIncome`).
  Behavior is unchanged; this only makes the expression independently callable
  from a unit test that never touches a fixture file.
- Extracted `static func requiresZeroPensionIncome(_ scenario: GoldenScenario) -> Bool`,
  changed to `scenario.classifiedPensionSources != nil` (mere presence), replacing
  the old inline guard `if let classified = ..., !classified.isEmpty`. This is the
  actual bug fix: an empty array now still requires `pensionIncome == 0`.
- `noDoubleCountedPension` now calls `requiresZeroPensionIncome(scenario)` instead
  of the inline guard.
- `federalAGIIsInternallyConsistent` now calls `pensionComponent(scenario)` instead
  of repeating the expression inline.
- Updated the doc comments on `covered`... no, on `federalAGIIsInternallyConsistent`
  and `noDoubleCountedPension` to state the empty-array case explicitly, and added
  a doc comment on each new helper.
- Added a regression test, `emptyClassifiedPensionSourcesStillRequiresZeroPensionIncome`,
  that builds a `GoldenScenario` directly in Swift (no fixture file) with
  `classifiedPensionSources: []` and `pensionIncome: 50_000`, and asserts BOTH:
  (a) `requiresZeroPensionIncome(scenario)` is `true` (this is the half that
  would have failed under the old `!classified.isEmpty` guard), and (b)
  `pensionComponent(scenario) == 0` (confirming the component sum silently
  drops `pensionIncome` once the array is present, which is why (a) must hold).

**Shape chosen and why:** rather than one boolean like "isConsistent," I split
the fix into two small helpers so the regression test could pin the guard
condition itself, not just its downstream numeric effect. A test that only
asserted `pensionComponent(scenario) == 0` would have passed both before and
after the fix (that expression was never buggy); the bug was entirely in the
guard's `!isEmpty` clause. Extracting `requiresZeroPensionIncome` let Step 3
below reintroduce exactly the original bug and watch the regression test catch
it, rather than fabricating a plausible-sounding but non-discriminating test.

## Finding 2 (Important): doc comment named a function that does not exist

**Fix, `GoldenScenarioCoverageTests.swift`, doc comment on `covered`:** reworded
to say `covered` grows as each batch task lands, and that Task 10 both switches
it to a full `USState.allCases` sweep AND adds a dedicated completeness test
named `everyJurisdictionHasAFixture`, which "does not exist yet." No longer
describes Task 10 as "replacing the body of" a function that is not in this
file.

## Finding 3 (Minor): test name overclaimed

**Fix, `GoldenScenarioCoverageTests.swift`:** renamed the display name of
`citationsAreWellFormed` from "Every fixture carries a resolvable https
citation" to "Every fixture carries a source and an https sourceURL."
Assertions unchanged (still just `hasPrefix("https://")` plus a non-empty
`source` check); nothing resolves anything and the name no longer implies it
does.

## Finding 4: doc comment described a fixed defect in the present tense

**Fix, `GoldenScenarioSingleYearTests.swift`, doc comment on `pilot`:** changed
the `StateTaxData.swift:2069` present-tense claim to past tense and dropped the
stale line number, per the finding's own verification (the fallback is gone;
`StateTaxData.config(for:)` is now at `:2290-2298` and traps via
`preconditionFailure` instead of defaulting to California). Kept the argument
("a hand-maintained array is how a jurisdiction goes missing") intact and
added the corrected mechanism description in its place. Two files touched by
this task, as flagged in the brief.

## Focused suite run (both files as fixed, before the Step 3 revert-and-prove)

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioCoverageTests -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests
```

Verbatim tail:

```
◇ Test "Empty classifiedPensionSources still requires pensionIncome == 0" started.
✔ Test "Empty classifiedPensionSources still requires pensionIncome == 0" passed after 0.001 seconds.
✔ Suite "Golden scenarios, coverage and shape" passed after 0.014 seconds.
◇ Suite "Golden scenarios, single-year path" started.
...
✔ Suite "Golden scenarios, single-year path" passed after 0.009 seconds.
✔ Test run with 8 tests in 2 suites passed after 0.024 seconds.
** TEST SUCCEEDED **
```

## Step 3: proved the regression test can fail

Temporarily reverted only `requiresZeroPensionIncome`'s body to the original
buggy condition:

```swift
static func requiresZeroPensionIncome(_ scenario: GoldenScenario) -> Bool {
    if let classified = scenario.classifiedPensionSources, !classified.isEmpty {
        return true
    }
    return false
}
```

Re-ran the same focused command. Verbatim failure:

```
◇ Test "Empty classifiedPensionSources still requires pensionIncome == 0" started.
✘ Test "Empty classifiedPensionSources still requires pensionIncome == 0" recorded an issue at GoldenScenarioCoverageTests.swift:155:9: Expectation failed: GoldenScenarioCoverageTests.requiresZeroPensionIncome(scenario -> GoldenScenario(name: "regression: empty classifiedPensionSources", source: "n/a, synthetic regression fixture", sourceURL: "https://example.com/regression", filingStatus: "single", primaryAge: 65, spouseAge: nil, federalAGI: 0.0, taxableSocialSecurity: 0.0, pensionIncome: 50000.0, iraWithdrawals: 0.0, rothConversion: 0.0, expectedStateTax: 0.0, classifiedPensionSources: Optional([]), knownDefect: nil, otherOrdinaryIncome: nil))
...
✘ Suite "Golden scenarios, coverage and shape" failed after 0.019 seconds with 1 issue.
...
Failing tests:
	GoldenScenarioCoverageTests.emptyClassifiedPensionSourcesStillRequiresZeroPensionIncome()
** TEST FAILED **
```

All other tests in both suites (including `noDoubleCountedPension` against the
real PA/IL/MS/NJ/NY fixtures) stayed green under the reintroduced bug, because
none of the shipped fixtures use an empty `classifiedPensionSources` array.
That confirms the reviewer's point: without a synthetic regression test, this
exact class of fixture defect is invisible to the current fixture set.

Reverted the helper back to `scenario.classifiedPensionSources != nil` and
re-ran the focused suite: `Test run with 8 tests in 2 suites passed after
0.027 seconds. ** TEST SUCCEEDED **`

`git diff` on `GoldenScenarioCoverageTests.swift` after the revert shows only
the intended fix (`requiresZeroPensionIncome` reads
`scenario.classifiedPensionSources != nil`) with no trace of the temporarily
reintroduced `!classified.isEmpty` clause.

## Full suite (after revert, all four fixes in place)

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
```

Verbatim:

```
✔ Test run with 1850 tests in 291 suites passed after 318.580 seconds.
** TEST SUCCEEDED **
```

XCTest line from the same run: `Executed 509 tests, with 0 failures (0
unexpected) in 21.050 (21.237) seconds. Test Suite 'All tests' passed`.

Skipped-test lines (6 total, matching the pre-existing env-gated harness plus
two "Generate..." helper tests, none new):

```
skipped: "set RUN_AUDIT_HARNESS=1 to run the full 27-profile display gate"
skipped: "set RUN_AUDIT_HARNESS=1 to run the full 27-profile catalog invariant sweep"
skipped: "set RUN_AUDIT_HARNESS=1 to run the full 27-profile catalog invariant sweep"
skipped: "set RUN_AUDIT_HARNESS=1 to run the full 27-profile encodability sweep"
skipped: "Generate the frozen behavior baseline"
skipped: "Generate all 51 jurisdiction files"
```

Result: 1,850 Swift Testing tests (baseline 1,849 + the 1 new regression test)
in 291 suites, 509 XCTest tests, 0 failures, 6 skipped. Matches the baseline
plus exactly one new test, as expected: this task added one `@Test` function
and no new `@Suite`.

## Empty production diff

```
$ git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 diff --stat main -- RetireSmartIRA/
(no output)
```

## Em dash check

```
$ grep -n em-dash-character RetireSmartIRATests/GoldenScenarioCoverageTests.swift RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
(no matches, grep exit code 1)
```

No em dash characters in either modified file or in this report.

## Note: an unrelated pre-existing uncommitted change found in the worktree

`git status` in this worktree also showed
`docs/superpowers/plans/2026-08-04-state-tax-phase4-golden-scenarios.md` as
modified, with a correction note dated 2026-08-04 about the same
`StateTaxData.swift:2069` California-fallback claim this task's Finding 4
addresses in `GoldenScenarioSingleYearTests.swift`. That edit predates this
session (I never opened or wrote to that file) and is outside this task's
scope (`GoldenScenarioCoverageTests.swift` plus, for Finding 4 only,
`GoldenScenarioSingleYearTests.swift`). Left untouched and NOT included in
this task's commit, per the brief's explicit-paths instruction.

## Commit

```
$ git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/GoldenScenarioCoverageTests.swift RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
$ git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): close the empty-classified-pension loophole in the shape invariants"
```

Result: `57e902a test(state-tax): close the empty-classified-pension loophole in the shape invariants`, 2 files changed, 94 insertions(+), 10 deletions(-).
