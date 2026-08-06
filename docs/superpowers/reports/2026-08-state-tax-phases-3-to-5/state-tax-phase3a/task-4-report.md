# Task 4 report: AGI phase-out mechanism

Status: **DONE**
Commit: `56639491f074e4ea8bc3689c8ac4f3b912e74afb` (short `5663949`) on `feature/state-tax-phase3a`
Worktree: `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a`

## Summary

Implemented `AGIPhaseout` (new file `RetireSmartIRA/StateAGIPhaseout.swift`), added
`RetirementIncomeExemptions.agiPhaseout: AGIPhaseout?` (default `nil`), added the
hand-written `AGIPhaseout.Shape: Codable` conformance plus the `agiPhaseout` key wiring
to `RetirementIncomeExemptions`'s existing Codable conformance in `StateTaxCodable.swift`,
and applied the phase-out in both branches of
`TaxCalculationEngine.applyRetirementExemptions`. No jurisdiction's config sets
`agiPhaseout`; every state's value stays `nil`, confirmed by a dedicated test over all 51
loaded configs. The 1,020-value behavior baseline is untouched, the JSON regeneration
diff is empty, and the full suite is green (1,638 Swift Testing tests / 503 XCTest tests).

One process note: the brief's Step 1 test code, pasted verbatim, contains the same Swift
syntax defect Task 3's report already documented (a non-triple-quoted string literal using
backslash-newline continuation, which is not valid Swift). Fixed the same way Task 3 did —
converted to a triple-quoted literal, identical wording — before getting the real RED
signal. Evidence for both attempts below.

An earlier attempt at this task ended a turn on an unfinished background `Monitor` wait for
the full-suite run instead of running it to completion in the foreground. The coordinator
flagged this; all verification below was re-run in the foreground per that correction, and
this report reflects those foreground runs, not the earlier backgrounded ones.

---

## Step 2: RED transcript

First attempt, using the brief's Step 1 test code verbatim, showing the pre-existing
string-literal syntax defect (unrelated to `AGIPhaseout`):

```
Testing failed:
	Invalid escape sequence in literal
                    "\(state.abbreviation) gained an AGI phase-out in Phase 3a. \
                                                                                 ^
	Unterminated string literal
                    "\(state.abbreviation) gained an AGI phase-out in Phase 3a. \
                    ^
	Unterminated string literal
                    by a golden scenario that also pins the correct income basis.")
                                                                                 ^
	Testing cancelled because the build failed.

** TEST FAILED **


The following build commands failed:
	SwiftDriver RetireSmartIRATests normal arm64 com.apple.xcode.tools.swift.compiler (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	Testing project RetireSmartIRA with scheme RetireSmartIRA
(2 failures)
```

Fixed only that syntax (triple-quoted string, identical wording) in
`RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`'s
`noStateHasAnAGIPhaseoutYet`. After that fix, the real RED transcript
(`tail -30` equivalent, pasted verbatim) for
`xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`:

```
                             shape: .linear(perDollar: 40_000 / 25_000))
                                    ~^~~~~~
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:243:26: error: cannot find 'AGIPhaseout' in scope
            agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                         ^~~~~~~~~~~
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:243:26: error: extra argument 'agiPhaseout' in call
            agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:244:46: error: cannot infer contextual base in reference to member 'linear'
                                     shape: .linear(perDollar: 1.0)))
                                            ~^~~~~~
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:269:49: error: value of type 'RetirementIncomeExemptions' has no member 'agiPhaseout'
            #expect(config.retirementExemptions.agiPhaseout == nil,
                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~ ^~~~~~~~~~~


Test session results, code coverage, and logs:
	/Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Logs/Test/Test-RetireSmartIRA-2026.08.03_03-14-49--0700.xcresult

Testing failed:
	Cannot find 'AGIPhaseout' in scope
	Cannot infer contextual base in reference to member 'cliff'
	Cannot find 'AGIPhaseout' in scope
	Cannot infer contextual base in reference to member 'linear'
	Cannot find 'AGIPhaseout' in scope
	Cannot infer contextual base in reference to member 'linear'
	Cannot find 'AGIPhaseout' in scope
	Extra argument 'agiPhaseout' in call
	Cannot infer contextual base in reference to member 'linear'
	Value of type 'RetirementIncomeExemptions' has no member 'agiPhaseout'
	Testing cancelled because the build failed.

** TEST FAILED **


The following build commands failed:
	SwiftCompile normal arm64 Compiling\ StateTaxPhase3aMechanismTests.swift /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	SwiftCompile normal arm64 /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	Testing project RetireSmartIRA with scheme RetireSmartIRA
(3 failures)
```

This is exactly the expected signal: "Cannot find 'AGIPhaseout' in scope" and "Value of
type 'RetirementIncomeExemptions' has no member 'agiPhaseout'".

---

## Step 3-6: implementation

Created `RetireSmartIRA/StateAGIPhaseout.swift` (the `AGIPhaseout` type, verbatim per the
brief's Step 3, including the "INCOME BASIS, NOT YET VERIFIED" doc comment). Added the
`agiPhaseout` field to `RetirementIncomeExemptions` in `StateTaxData.swift`, right after
`otherRetirementIncomeExclusion`. Wired the engine (`TaxCalculationEngine.swift`, detail
below). Added `AGIPhaseout.Shape: Codable` and the `agiPhaseout` key to
`RetirementIncomeExemptions`'s Codable conformance in `StateTaxCodable.swift`. Added the
round-trip test to `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`.

---

## Step 7: GREEN transcripts

### Mechanism tests + behavior baseline + round-trip tests (foreground)

Command: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`

```
◇ Test "Encoded JSON carries all nine fields under their own keys, with the right values" started.
✔ Test "Encoded JSON carries all nine fields under their own keys, with the right values" passed after 0.001 seconds.
◇ Test "Two complementary Bool arrangements make every pair of the four Bool fields mutually distinguishable" started.
✔ Test "Two complementary Bool arrangements make every pair of the four Bool fields mutually distinguishable" passed after 0.003 seconds.
◇ Test "AgeTier decode throws a reportable error, not a ClosedRange trap, when minAge exceeds maxAge" started.
✔ Test "AgeTier decode throws a reportable error, not a ClosedRange trap, when minAge exceeds maxAge" passed after 0.001 seconds.
◇ Test "StateTaxConfig round-trips with verification metadata" started.
✔ Test "StateTaxConfig round-trips with verification metadata" passed after 0.001 seconds.
◇ Test "Encoded JSON carries state as an abbreviation string, currentYearSafeHarborRate, estimatedPaymentSchedule, safeHarborRule, and a nested verification object" started.
✔ Test "Encoded JSON carries state as an abbreviation string, currentYearSafeHarborRate, estimatedPaymentSchedule, safeHarborRule, and a nested verification object" passed after 0.001 seconds.
◇ Test "Three fixtures make every pair of StateTaxConfig's five Bool fields mutually distinguishable" started.
✔ Test "Three fixtures make every pair of StateTaxConfig's five Bool fields mutually distinguishable" passed after 0.001 seconds.
◇ Test "Decoding an unknown state abbreviation throws a DecodingError instead of silently defaulting" started.
✔ Test "Decoding an unknown state abbreviation throws a DecodingError instead of silently defaulting" passed after 0.004 seconds.
◇ Test "Every StateSafeHarborRule used in the real config table round-trips" started.
✔ Test "Every StateSafeHarborRule used in the real config table round-trips" passed after 0.001 seconds.
◇ Test "AGIPhaseout round-trips both shapes with distinct per-field values" started.
✔ Test "AGIPhaseout round-trips both shapes with distinct per-field values" passed after 0.001 seconds.
✔ Suite "State tax Codable round trips (Phase 1)" passed after 0.010 seconds.
◇ Suite "Phase 3a mechanisms are load-bearing" started.
◇ Test "distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59" started.
✔ Test "distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59" passed after 0.001 seconds.
◇ Test "distributionMinAge defaults to 59, reproducing the previous hardcoded gate" started.
✔ Test "distributionMinAge defaults to 59, reproducing the previous hardcoded gate" passed after 0.001 seconds.
◇ Test "distributionMinAge also gates per-individual cap doubling, not only scenario distributions" started.
✔ Test "distributionMinAge also gates per-individual cap doubling, not only scenario distributions" passed after 0.001 seconds.
◇ Test "StatePersonalExemption reproduces New Jersey's four documented outcomes" started.
✔ Test "StatePersonalExemption reproduces New Jersey's four documented outcomes" passed after 0.001 seconds.
◇ Test "A filer on MFJ with no spouse configured gets the single amounts" started.
✔ Test "A filer on MFJ with no spouse configured gets the single amounts" passed after 0.001 seconds.
◇ Test "Only one spouse over the senior age gets exactly one senior addition" started.
✔ Test "Only one spouse over the senior age gets exactly one senior addition" passed after 0.001 seconds.
◇ Test "A state with no senior addition ignores age entirely" started.
✔ Test "A state with no senior addition ignores age entirely" passed after 0.001 seconds.
◇ Test "New Jersey's shipped config carries its four exemption values exactly" started.
✔ Test "New Jersey's shipped config carries its four exemption values exactly" passed after 0.002 seconds.
◇ Test "New Jersey's config carries the personal exemption; no other state does" started.
✔ Test "New Jersey's config carries the personal exemption; no other state does" passed after 0.002 seconds.
◇ Test "A cliff phase-out removes the whole exclusion above the threshold and nothing below it" started.
✔ Test "A cliff phase-out removes the whole exclusion above the threshold and nothing below it" passed after 0.001 seconds.
◇ Test "A dollar-for-dollar phase-out reduces the exclusion by the excess and floors at zero" started.
✔ Test "A dollar-for-dollar phase-out reduces the exclusion by the excess and floors at zero" passed after 0.001 seconds.
◇ Test "A fractional ramp reaches zero at the far end of the band" started.
✔ Test "A fractional ramp reaches zero at the far end of the band" passed after 0.001 seconds.
◇ Test "agiPhaseout reaches the engine and reduces real computed tax" started.
✔ Test "agiPhaseout reaches the engine and reduces real computed tax" passed after 0.001 seconds.
◇ Test "No jurisdiction carries an agiPhaseout in Phase 3a" started.
✔ Test "No jurisdiction carries an agiPhaseout in Phase 3a" passed after 0.004 seconds.
✔ Suite "Phase 3a mechanisms are load-bearing" passed after 0.011 seconds.
✔ Test run with 34 tests in 3 suites passed after 0.067 seconds.
2026-08-03 03:21:44.564 xcodebuild[81034:8786505] [MT] IDETestOperationsObserverDebug: 1.195 elapsed -- Testing started completed.

Test session results, code coverage, and logs:
	/Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Logs/Test/Test-RetireSmartIRA-2026.08.03_03-21-42--0700.xcresult

** TEST SUCCEEDED **
```

The behavior baseline is inside that same run. Confirming its 51-case pass explicitly
(from an earlier identical foreground run in this session, same log content):

```
​✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.049 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.049 seconds.
```

The 1,020-value baseline (51 jurisdictions x 20 scenarios) held. Neither
`RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift` nor
`Baselines/statetax-behavior-baseline-2026.json` was edited (confirmed in the `git diff
--stat` below, neither file appears).

---

## Empty-regeneration confirmation

Command:
```
TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests ENABLE_APP_SANDBOX=NO
```

Actual output (tail):
```
Test Suite 'Selected tests' passed at 2026-08-03 03:21:53.302.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
◇ Test run started.
↳ Testing Library Version: 1902
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite "State tax JSON generator (manual)" started.
◇ Test "Generate all 51 jurisdiction files" started.
✔ Test "Generate all 51 jurisdiction files" passed after 0.005 seconds.
✔ Suite "State tax JSON generator (manual)" passed after 0.005 seconds.
✔ Test run with 1 test in 1 suite passed after 0.005 seconds.

Test session results, code coverage, and logs:
	/Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Logs/Test/Test-RetireSmartIRA-2026.08.03_03-21-51--0700.xcresult

** TEST SUCCEEDED **
```

Then:
```
$ git status --short RetireSmartIRA/Resources/StateTaxData/2026/
$ echo "EXIT:$?"
EXIT:0
```

No output, nothing to commit. `agiPhaseout` is `nil` for all 51 states, so the
`encodeIfPresent` call in `RetirementIncomeExemptions.encode(to:)` emits nothing new,
exactly as expected.

---

## Full suite (foreground)

Command:
```
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/p3a-task4.log | tail -40
```

Both summary lines, pasted verbatim from `/tmp/p3a-task4.log`:

Swift Testing:
```
✔ Test run with 1638 tests in 278 suites passed after 282.041 seconds.
```

XCTest:
```
Test Suite 'RetireSmartIRATests.xctest' passed at 2026-08-03 03:22:25.807.
	 Executed 503 tests, with 0 failures (0 unexpected) in 19.899 (20.212) seconds
Test Suite 'All tests' passed at 2026-08-03 03:22:25.807.
	 Executed 503 tests, with 0 failures (0 unexpected) in 19.899 (20.213) seconds
```

Overall result: `** TEST SUCCEEDED **`

Tree-confirmation grep, showing the tested `.xcodeproj` is the correct worktree:
```
$ grep -o "worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj" /tmp/p3a-task4.log | head -1
worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
```

`pwd` / branch at the time of these runs:
```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a
feature/state-tax-phase3a
```

1,638 Swift Testing tests (up from 1,632 at the end of Task 3: +6 net, consistent with the
6 new `AGIPhaseout` mechanism tests in `StateTaxPhase3aMechanismTests.swift`; the
`agiPhaseoutRoundTrips` test added to `StateTaxCodableRoundTripTests.swift` brings the true
new-test count to 7, offset by no removals this task). XCTest's 503 unchanged. Both green,
0 failures.

---

## Both engine branches: exact before and after

### Shared-cap branch (`pensionAndIRAShareSingleCap == true`)

Before:
```swift
            let isMarried = filingStatus == .marriedFilingJointly
            let combinedIncome = pensionIncome + iraIncome
            let pensionIRAExclusion = effectivePensionExemption.excludedAmount(
                eligibleIncome: combinedIncome,
                totalGrossIncome: income,
                isMarried: isMarried,
                perIndividualMultiplier: perIndividualMultiplier
            )
            adjusted -= pensionIRAExclusion
```

After:
```swift
            let isMarried = filingStatus == .marriedFilingJointly
            let combinedIncome = pensionIncome + iraIncome
            let rawExclusion = effectivePensionExemption.excludedAmount(
                eligibleIncome: combinedIncome,
                totalGrossIncome: income,
                isMarried: isMarried,
                perIndividualMultiplier: perIndividualMultiplier
            )
            let pensionIRAExclusion = exemptions.agiPhaseout?.reduced(
                exclusion: rawExclusion, totalGrossIncome: income, isMarried: isMarried
            ) ?? rawExclusion
            adjusted -= pensionIRAExclusion
```

`pensionIRAExclusion` is still the name bound to the (now phase-out-reduced) value, and it
is exactly the name the NJ Worksheet D block immediately below reads
(`let unused = max(0, chartMax - pensionIRAExclusion)`), which was left untouched. The raw,
unreduced amount lives only in the new `rawExclusion` local and does not leak into the
Worksheet D computation.

### Independent-cap branch (`pensionAndIRAShareSingleCap == false`)

Before:
```swift
        } else {
            // Standard per-type application: each type's cap applied independently.
            let isMarried = filingStatus == .marriedFilingJointly
            adjusted -= effectivePensionExemption.excludedAmount(
                eligibleIncome: pensionIncome,
                totalGrossIncome: income,
                isMarried: isMarried,
                perIndividualMultiplier: perIndividualMultiplier
            )
            adjusted -= effectiveIRAExemption.excludedAmount(
                eligibleIncome: iraIncome,
                totalGrossIncome: income,
                isMarried: isMarried,
                perIndividualMultiplier: perIndividualMultiplier
            )
        }
```

After:
```swift
        } else {
            // Standard per-type application: each type's cap applied independently.
            let isMarried = filingStatus == .marriedFilingJointly
            let rawPension = effectivePensionExemption.excludedAmount(
                eligibleIncome: pensionIncome,
                totalGrossIncome: income,
                isMarried: isMarried,
                perIndividualMultiplier: perIndividualMultiplier
            )
            adjusted -= exemptions.agiPhaseout?.reduced(
                exclusion: rawPension, totalGrossIncome: income, isMarried: isMarried
            ) ?? rawPension

            let rawIRA = effectiveIRAExemption.excludedAmount(
                eligibleIncome: iraIncome,
                totalGrossIncome: income,
                isMarried: isMarried,
                perIndividualMultiplier: perIndividualMultiplier
            )
            adjusted -= exemptions.agiPhaseout?.reduced(
                exclusion: rawIRA, totalGrossIncome: income, isMarried: isMarried
            ) ?? rawIRA
        }
```

Each of the two subtractions is bound to its own `raw*` local first (`rawPension`,
`rawIRA`) so the phase-out reduction is visible in a debugger and in a diff, per the
brief's instruction. Nothing downstream in this branch reads either local by name (unlike
the shared-cap branch), so no further renaming trap applies here.

Nothing else in `applyRetirementExemptions` changed. `ProjectionEngine.swift` was not
touched (confirmed absent from `git diff --stat` below).

---

## `git diff --stat`

```
$ git diff --stat bea311a HEAD
 RetireSmartIRA/StateAGIPhaseout.swift              | 52 +++++++++++++++
 RetireSmartIRA/StateTaxCodable.swift               | 30 ++++++++-
 RetireSmartIRA/StateTaxData.swift                  |  4 ++
 RetireSmartIRA/TaxCalculationEngine.swift          | 16 ++++-
 .../StateTaxCodableRoundTripTests.swift            | 17 +++++
 .../StateTaxPhase3aMechanismTests.swift            | 76 ++++++++++++++++++++++
 6 files changed, 191 insertions(+), 4 deletions(-)
```

No JSON file, no baseline file
(`Baselines/statetax-behavior-baseline-2026.json`,
`RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift`), no `ProjectionEngine.swift`,
and no `.xcodeproj` file appears in this diff.

---

## Commit

```
$ git status --short
 M RetireSmartIRA/StateTaxCodable.swift
 M RetireSmartIRA/StateTaxData.swift
 M RetireSmartIRA/TaxCalculationEngine.swift
 M RetireSmartIRATests/StateTaxCodableRoundTripTests.swift
 M RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift
?? RetireSmartIRA/StateAGIPhaseout.swift

$ git add RetireSmartIRA/StateAGIPhaseout.swift RetireSmartIRA/StateTaxCodable.swift \
    RetireSmartIRA/StateTaxData.swift RetireSmartIRA/TaxCalculationEngine.swift \
    RetireSmartIRATests/StateTaxCodableRoundTripTests.swift \
    RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift

$ git commit -m "feat(state-tax): general AGI phase-out mechanism, no jurisdiction using it yet"
[feature/state-tax-phase3a 5663949] feat(state-tax): general AGI phase-out mechanism, no jurisdiction using it yet
 6 files changed, 191 insertions(+), 4 deletions(-)
 create mode 100644 RetireSmartIRA/StateAGIPhaseout.swift

$ git rev-parse HEAD
56639491f074e4ea8bc3689c8ac4f3b912e74afb
```

No `git add -A` / `git add .` used; each of the 6 explicit paths was staged. No stray
edits from other agents in the shared worktree were picked up (`git status --short` before
staging showed exactly these 6 paths and nothing else).

---

## Concerns

None outstanding. The task's own gate test (`noStateHasAnAGIPhaseoutYet`) passed, the
1,020-value behavior baseline is unmoved, the regeneration diff was genuinely empty, and
the full suite is green with no unexplained deltas.

---

## Review fixes

A mutation-testing reviewer found that two of the three `agiPhaseout` call sites
(the shared-cap branch and the IRA-side of the per-type branch) had no discriminating
test, plus a stale encoder-guard fixture that predated `distributionMinAge` (Task 2) and
`agiPhaseout` (Task 4). Six fixes applied:

1. Added `agiPhaseoutAppliesInTheSharedCapBranch` to
   `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`, covering the
   `pensionAndIRAShareSingleCap` branch's `pensionIRAExclusion` reduction
   (`TaxCalculationEngine.swift` ~line 604).
2. Added `agiPhaseoutAppliesToTheIRASubtraction`, covering the per-type branch's
   `rawIRA` reduction (`TaxCalculationEngine.swift` ~line 651), using a `.rmd`-typed
   income source so the reduction is actually exercised.
3. Extended `retirementExemptionsRoundTrip` and `retirementExemptionsEncodesExpectedJSONShape`
   in `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift` with `distributionMinAge: 55`
   and `agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000, shape: .linear(perDollar: 1.6))`,
   added matching assertions, retitled the JSON-shape test from "all nine fields" to
   "all eleven fields", and added a doc-comment sentence that this fixture must be
   extended whenever a field is added to `RetirementIncomeExemptions`.
4. Replaced `noStateHasAnAGIPhaseoutYet` (asserted on decoded values) with
   `noStateShipsAnAGIPhaseoutKey` (reads raw JSON keys via `StateTaxDataLoader.fileURL`),
   matching Task 3's analogue pattern in `StateTaxJSONFileKeyCompletenessTests`.
5. Added the BOUNDARY CONVENTION doc comment to `AGIPhaseout.Shape.cliff` in
   `RetireSmartIRA/StateAGIPhaseout.swift`, flagging the New Mexico audit-wording
   ambiguity at exactly the threshold.
6. Added a Phase 5 NOTE above the NJ Worksheet D block in
   `RetireSmartIRA/TaxCalculationEngine.swift`, documenting that `chartMax` derives
   from the unreduced exemption level, currently unreachable because no state combines
   `.steppedPhaseoutByFilingStatus`, `otherRetirementIncomeExclusion`, and `agiPhaseout`.

### Mutation 2a: shared-cap branch, `let pensionIRAExclusion = rawExclusion`

Command: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests ENABLE_APP_SANDBOX=NO`

```
◇ Test "agiPhaseout reduces the exclusion in the shared-cap branch too" started.
✘ Test "agiPhaseout reduces the exclusion in the shared-cap branch too" recorded an issue at StateTaxPhase3aMechanismTests.swift:290:9: Expectation failed: (tax(income: 55_000) → 4300.0) == (4_800 → 4800.0)
↳ // At 55,000 the exclusion is cut by 5,000 to 7,000: 48,000 taxable, 4,800.
✘ Test "agiPhaseout reduces the exclusion in the shared-cap branch too" recorded an issue at StateTaxPhase3aMechanismTests.swift:292:9: Expectation failed: (tax(income: 70_000) → 5800.0) == (7_000 → 7000.0)
↳ // At 70,000 the exclusion is gone entirely: 70,000 taxable, 7,000.
✘ Test "agiPhaseout reduces the exclusion in the shared-cap branch too" failed after 0.001 seconds with 2 issues.
...
Failing tests:
	StateTaxPhase3aMechanismTests.agiPhaseoutAppliesInTheSharedCapBranch()
** TEST FAILED **
```

`agiPhaseoutAppliesToTheIRASubtraction` stayed green under this mutation, as expected
(different branch). Restored with Edit, confirmed with `git diff RetireSmartIRA/TaxCalculationEngine.swift`
showing only the intended FIX 6 doc-comment addition, no mutation residue.

### Mutation 2b: per-type branch, `adjusted -= rawIRA`

Command: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests ENABLE_APP_SANDBOX=NO`

```
◇ Test "agiPhaseout reduces the IRA subtraction, not only the pension one" started.
✘ Test "agiPhaseout reduces the IRA subtraction, not only the pension one" recorded an issue at StateTaxPhase3aMechanismTests.swift:320:9: Expectation failed: (tax(income: 55_000) → 4300.0) == (4_800 → 4800.0)
✘ Test "agiPhaseout reduces the IRA subtraction, not only the pension one" recorded an issue at StateTaxPhase3aMechanismTests.swift:321:9: Expectation failed: (tax(income: 70_000) → 5800.0) == (7_000 → 7000.0)
✘ Test "agiPhaseout reduces the IRA subtraction, not only the pension one" failed after 0.001 seconds with 2 issues.
...
Failing tests:
	StateTaxPhase3aMechanismTests.agiPhaseoutAppliesToTheIRASubtraction()
** TEST FAILED **
```

`agiPhaseoutAppliesInTheSharedCapBranch` stayed green under this mutation, as expected.
Restored with Edit, confirmed with `git diff RetireSmartIRA/TaxCalculationEngine.swift`
showing only the FIX 6 doc-comment addition.

### Mutation 2c: delete `try c.encodeIfPresent(agiPhaseout, forKey: .agiPhaseout)`

Command: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests ENABLE_APP_SANDBOX=NO`

```
◇ Test "RetirementIncomeExemptions round-trips with every field populated" started.
✘ Test "RetirementIncomeExemptions round-trips with every field populated" recorded an issue at StateTaxCodableRoundTripTests.swift:209:9: Expectation failed: (decoded.agiPhaseout → nil) == (original.agiPhaseout → AGIPhaseout(thresholdSingle: 50000.0, thresholdMFJ: 75000.0, shape: RetireSmartIRA.AGIPhaseout.Shape.linear(perDollar: 1.6)))
✘ Test "RetirementIncomeExemptions round-trips with every field populated" failed after 0.007 seconds with 1 issue.
◇ Test "Encoded JSON carries all eleven fields under their own keys, with the right values" started.
✘ Test "Encoded JSON carries all eleven fields under their own keys, with the right values" recorded an issue at StateTaxCodableRoundTripTests.swift:329:28: Expectation failed: (json["agiPhaseout"] → nil) as? ([String: Any] → Optional<Any>)
✘ Test "Encoded JSON carries all eleven fields under their own keys, with the right values" failed after 0.001 seconds with 1 issue.
...
Failing tests:
	StateTaxCodableRoundTripTests.retirementExemptionsRoundTrip()
	StateTaxCodableRoundTripTests.retirementExemptionsEncodesExpectedJSONShape()
** TEST FAILED **
```

Restored with Edit; `git diff RetireSmartIRA/StateTaxCodable.swift` produced no output
(clean restore, byte-identical to before the mutation).

### Mutation 2d: delete `try c.encode(distributionMinAge, forKey: .distributionMinAge)`

Command: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests ENABLE_APP_SANDBOX=NO`

```
◇ Test "RetirementIncomeExemptions round-trips with every field populated" started.
✘ Test "RetirementIncomeExemptions round-trips with every field populated" recorded an issue at StateTaxCodableRoundTripTests.swift:206:9: Expectation failed: (decoded.distributionMinAge → 59) == (original.distributionMinAge → 55)
✘ Test "RetirementIncomeExemptions round-trips with every field populated" failed after 0.001 seconds with 1 issue.
◇ Test "Encoded JSON carries all eleven fields under their own keys, with the right values" started.
✘ Test "Encoded JSON carries all eleven fields under their own keys, with the right values" recorded an issue at StateTaxCodableRoundTripTests.swift:309:9: Expectation failed: (json["distributionMinAge"] as? Int → nil) == 55
✘ Test "Encoded JSON carries all eleven fields under their own keys, with the right values" failed after 0.001 seconds with 1 issue.
...
Failing tests:
	StateTaxCodableRoundTripTests.retirementExemptionsRoundTrip()
	StateTaxCodableRoundTripTests.retirementExemptionsEncodesExpectedJSONShape()
** TEST FAILED **
```

This confirms the guard is now current for `distributionMinAge`, a field added two
tasks ago and previously unguarded by this fixture. Restored with Edit; `git diff
RetireSmartIRA/StateTaxCodable.swift` produced no output after restoring, and
`git status --short` showed only the four intended files (`StateAGIPhaseout.swift`,
`TaxCalculationEngine.swift`, `StateTaxCodableRoundTripTests.swift`,
`StateTaxPhase3aMechanismTests.swift`), confirming no mutation residue.

All four mutations discriminated correctly; none needed test adjustment to manufacture
a failure.

### Behavior baseline

`xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests ENABLE_APP_SANDBOX=NO`

```
✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.047 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.047 seconds.
✔ Test run with 1 test in 1 suite passed after 0.047 seconds.
** TEST SUCCEEDED **
```

The frozen baseline values are unmoved by these test-only changes (no jurisdiction sets
`agiPhaseout`, so `applyRetirementExemptions` computes byte-identical results for all 51
states' scenarios).

### Regeneration check

`TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests ENABLE_APP_SANDBOX=NO`

```
✔ Test "Generate all 51 jurisdiction files" started.
✔ Suite "State tax JSON generator (manual)" passed after 0.006 seconds.
✔ Test run with 1 test in 1 suite passed after 0.006 seconds.
** TEST SUCCEEDED **
```

`git status --short RetireSmartIRA/Resources/StateTaxData/2026/` produced no output:
the diff is empty, as expected, because `agiPhaseout` remains `nil` for all 51 states.

### Full suite (foreground)

`xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' ENABLE_APP_SANDBOX=NO`

Both summary lines:

```
✔ Test run with 1640 tests in 278 suites passed after 278.635 seconds.
```
```
	 Executed 503 tests, with 0 failures (0 unexpected) in 19.136 (19.440) seconds
```

`** TEST SUCCEEDED **`

### Final tree confirmation

```
$ git status --short
 M RetireSmartIRA/StateAGIPhaseout.swift
 M RetireSmartIRA/TaxCalculationEngine.swift
 M RetireSmartIRATests/StateTaxCodableRoundTripTests.swift
 M RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift
```

No `.xcodeproj`, no `StateTaxBehaviorBaselineTests.swift`, no baseline JSON, no
`ProjectionEngine.swift` in the diff. `git diff | grep '^+' | grep "—"` matched nothing:
no em dash characters were introduced.

### Commit

```
$ git add RetireSmartIRA/StateAGIPhaseout.swift RetireSmartIRA/TaxCalculationEngine.swift \
    RetireSmartIRATests/StateTaxCodableRoundTripTests.swift \
    RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift

$ git commit -m "test(state-tax): guard both unreached phase-out call sites and the stale encoder fixture"
[feature/state-tax-phase3a f87bb3f] test(state-tax): guard both unreached phase-out call sites and the stale encoder fixture
 4 files changed, 114 insertions(+), 12 deletions(-)

$ git rev-parse HEAD
f87bb3f44b67b9b07022c9014e33baf11c0c3a2f
```
