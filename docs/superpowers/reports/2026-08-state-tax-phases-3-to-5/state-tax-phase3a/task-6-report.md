# Task 6 report: Data-driven Roth conversion exemption

Status: DONE
Commit: `9c1dbf7dbf5b7026286d2b59bc759ceb50d7bf68` on `feature/state-tax-phase3a`
Baseline: held (frozen `StateTaxBehaviorBaselineTests` suite green throughout, and used as the
restore-point check after both mutations)
Mutations: both discriminated (encoder mutation turned the named JSON-shape test red; engine
mutation turned the named `pennsylvaniaExemptsNetOfWithholdingViaConfig` test red)
Grep sweep: only the two UI files (`RothConversionWithholdingCard.swift:40`,
`MultiYearTaxFundingCard.swift:61`) plus the unrelated `USState.abbreviation` enum switch remain;
both hardcoded engine/DataManager switches are gone
Tests: 1655 Swift Testing tests / 278 suites passed; 503 XCTest tests passed; 0 failures, 6 skips
(pre-existing, unrelated to this task)

## Summary

Created `RothConversionExemption` (`RetireSmartIRA/StateRothConversionExemption.swift`) and added
`RetirementIncomeExemptions.rothConversionExemption: RothConversionExemption?` (default `nil`).
Configured PA (`minAge: 0, withheldPortionRemainsTaxable: true`), IL and MS (`minAge: 0,
withheldPortionRemainsTaxable: false`) in `StateTaxData.swift`. Replaced the `switch state` in
`TaxCalculationEngine.applyRetirementExemptions` (was lines 746-754) with a config-driven
`if let conversionRule = exemptions.rothConversionExemption` block, age-gated on `effectiveAge`
(household maximum) per the task's explicit instruction, with a comment recording that Iowa's
Phase 5a golden scenario is what will decide whether that is the right predicate for a
conversion under `.perQualifyingSpouse`. Added Codable support (`CodingKeys`, `encodeIfPresent`,
`decodeIfPresent`) in `StateTaxCodable.swift`.

Per the controller addendum, also converted the second hardcoded switch at
`DataManager.swift:889-898` (the breakdown mirror), replacing it with the same
`config.retirementExemptions.rothConversionExemption` / `effectiveAge` logic so the two paths
cannot drift, reusing the `exemptions` and `effectiveAge` locals already in scope in
`stateTaxBreakdown`.

Regenerated all 51 bundled JSON files. Only PA, IL and MS changed, each gaining a
`rothConversionExemption` object nested inside `retirementExemptions`; the other 48 files are
byte-identical. No deletions anywhere (verified below).

Extended both `StateTaxCodableRoundTripTests.swift` fixture tests
(`retirementExemptionsRoundTrip`, `retirementExemptionsEncodesExpectedJSONShape`) with a
non-default `rothConversionExemption` value in declaration order, updated the JSON-shape test's
title/doc comment from "twelve fields" to "thirteen fields", and added the standalone
`rothConversionExemptionRoundTrips` test. Added the brief's `onlyThreeStatesCarryAConversionExemption`
test to `StateTaxPhase3aMechanismTests.swift`, but rewritten to read raw JSON keys via
`StateTaxDataLoader.fileURL` instead of decoded config values, per the standing requirement (a
decoded assertion would pass even if the key were silently absent from every shipped file, since
`nil` is also the decode fallback) -- following the exact pattern of `noStateShipsAnAGIPhaseoutKey`,
`everyStateShipsHouseholdAttribution`, and `onlyNewJerseyShipsAPersonalExemptionKey`.

One deviation from the brief's literal verification ordering, documented below.

---

## Deviation: verification order 1 (mechanism/baseline tests) run AFTER regeneration (order 4), not before

The task's "VERIFICATION, in this order" list places targeted mechanism/round-trip/baseline tests
(step 1) before regeneration (step 4) and the two mutations (steps 2-3) before regeneration too.
I ran step 1 first as listed and it failed as expected -- `pennsylvaniaExemptsNetOfWithholdingViaConfig`,
`illinoisAndMississippiExemptGrossViaConfig`, `onlyThreeStatesCarryAConversionExemption`, 4 pre-existing
`StateRetirementExemptionTests`, and 9 frozen baseline scenarios all failed, because
`TaxCalculationEngine.calculateStateTax(forState: .pennsylvania, ...)` resolves its config through
`StateTaxData.config(for:)`, which reads the bundled JSON -- and the JSON hadn't been regenerated
yet, so `rothConversionExemption` was `nil` for PA/IL/MS at runtime (this is exactly the trap flagged
in context item 3). Only the synthetic-config test (`rothConversionExemptionCanBeAgeGated`, which
uses `configOverride`) passed at that point, confirming the engine logic itself was correct.

I therefore ran regeneration (step 4) immediately after confirming that first RED-to-config-gap
state, before attempting the two mutations. This was necessary, not optional: a "discrimination"
mutation must flip a test from GREEN to RED to prove anything. Running the discrimination mutation
against a test that was already failing (for an unrelated reason -- missing config data) would have
proven nothing. Both mutations below were therefore run against a genuinely green baseline
(post-regeneration), which is what makes their RED result meaningful.

---

## Step 2: RED transcript (verbatim)

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:548:38: error: cannot find 'RothConversionExemption' in scope
            rothConversionExemption: RothConversionExemption(
                                     ^~~~~~~~~~~~~~~~~~~~~~~
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:548:38: error: extra argument 'rothConversionExemption' in call
            rothConversionExemption: RothConversionExemption(
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~~~~~~~~~~~~~~~~~~~

Testing failed:
	Cannot find 'RothConversionExemption' in scope
	Extra argument 'rothConversionExemption' in call
	Testing cancelled because the build failed.

** TEST FAILED **
```

Exactly the expected failure (`cannot find 'RothConversionExemption' in scope`).

### Post-implementation, pre-regeneration RED (config-gap trap, per context item 3)

After implementing the type, field, engine change, and Codable support, but before regenerating
JSON, the real-state tests failed exactly as the context note predicted:

```
✘ Test "Pennsylvania still exempts only the net amount deposited into the Roth" recorded an issue at StateTaxPhase3aMechanismTests.swift:526:9: Expectation failed: (tax(withholding: 0) → 3070.0) == (0 → 0.0)
↳ // PA rate 3.07%. Full conversion exempt when nothing is withheld.
✘ Test "Illinois and Mississippi exempt the gross conversion regardless of withholding" recorded an issue: (taxed → 4950.0) == (0 → 0.0) ↳ IL should exempt the gross conversion
✘ Test "Exactly PA, IL and MS carry a conversion exemption in Phase 3a" recorded an issue: (Set(withExemption.keys) → []) == (Set([.pennsylvania, .illinois, .mississippi]) → ...)

Failing tests:
	StateRetirementExemptionTests.paJohnsScenarioPlusRothConversion()
	StateRetirementExemptionTests.paRothConversionNotAgeGated()
	StateRetirementExemptionTests.ilRothConversionExempt()
	StateRetirementExemptionTests.msRothConversionExempt()
	-[StateTaxBehaviorBaselineTests matchesFrozenBaseline(state:)]  (x9)
	StateTaxPhase3aMechanismTests.pennsylvaniaExemptsNetOfWithholdingViaConfig()
	StateTaxPhase3aMechanismTests.illinoisAndMississippiExemptGrossViaConfig()
	StateTaxPhase3aMechanismTests.onlyThreeStatesCarryAConversionExemption()
```

Resolved by regeneration (see below); confirmed GREEN afterward (98 tests / 4 suites passed).

---

## Mutation 1: encoder (point 5) -- delete the `rothConversionExemption` encode line

Removed `try c.encodeIfPresent(rothConversionExemption, forKey: .rothConversionExemption)` from
`RetirementIncomeExemptions.encode(to:)` in `StateTaxCodable.swift`.

Result (RED, `-only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`):

```
◇ Test "RetirementIncomeExemptions round-trips with every field populated" started.
✘ Test "RetirementIncomeExemptions round-trips with every field populated" recorded an issue at StateTaxCodableRoundTripTests.swift:214:9: Expectation failed: (decoded.rothConversionExemption → nil) == (original.rothConversionExemption → RothConversionExemption(minAge: 55, withheldPortionRemainsTaxable: true))
✘ Test "RetirementIncomeExemptions round-trips with every field populated" failed after 0.001 seconds with 1 issue.
...
◇ Test "Encoded JSON carries all thirteen fields under their own keys, with the right values" started.
✘ Test "Encoded JSON carries all thirteen fields under their own keys, with the right values" recorded an issue at StateTaxCodableRoundTripTests.swift:359:34: Expectation failed: (json["rothConversionExemption"] → nil) as? ([String: Any] → Optional<Any>)
✘ Test "Encoded JSON carries all thirteen fields under their own keys, with the right values" failed after 0.001 seconds with 1 issue.
✘ Suite "State tax Codable round trips (Phase 1)" failed after 0.014 seconds with 2 issues.

Failing tests:
	StateTaxCodableRoundTripTests.retirementExemptionsRoundTrip()
	StateTaxCodableRoundTripTests.retirementExemptionsEncodesExpectedJSONShape()

** TEST FAILED **
```

The named JSON-shape test (`retirementExemptionsEncodesExpectedJSONShape`) went red as required.

Restored the encode line. Re-run confirmed GREEN:

```
** TEST SUCCEEDED **
```

---

## Mutation 2: engine discrimination (point 3) -- make the PA branch exempt GROSS, not net

In `TaxCalculationEngine.applyRetirementExemptions`, swapped the ternary branches:

```swift
// mutated (wrong):
let exemptAmount = conversionRule.withheldPortionRemainsTaxable
    ? scenarioRothConversionAmount
    : max(0, scenarioRothConversionAmount - scenarioRothConversionWithholdingAmount)
```

Result (RED, mechanism + baseline + retirement-exemption suites):

```
◇ Test "Pennsylvania still exempts only the net amount deposited into the Roth" started.
✘ Test "Pennsylvania still exempts only the net amount deposited into the Roth" recorded an issue at StateTaxPhase3aMechanismTests.swift:528:9: Expectation failed: (abs(tax(withholding: 22_000) - 675.40) → 675.4) < 0.005
↳ // $22,000 withheld stays PA-taxable: 22,000 x 0.0307 = 675.40.
✘ Test "Pennsylvania still exempts only the net amount deposited into the Roth" failed after 0.001 seconds with 1 issue.
◇ Test "Illinois and Mississippi exempt the gross conversion regardless of withholding" started.
✘ Test "Illinois and Mississippi exempt the gross conversion regardless of withholding" recorded an issue: (taxed → 1089.0) == (0 → 0.0) ↳ IL should exempt the gross conversion
✘ Test "Illinois and Mississippi exempt the gross conversion regardless of withholding" recorded an issue: (taxed → 880.0) == (0 → 0.0) ↳ MS should exempt the gross conversion

Failing tests:
	-[StateTaxBehaviorBaselineTests matchesFrozenBaseline(state:)]  (x3)
	StateTaxPhase3aMechanismTests.pennsylvaniaExemptsNetOfWithholdingViaConfig()
	StateTaxPhase3aMechanismTests.illinoisAndMississippiExemptGrossViaConfig()

** TEST FAILED **
```

The named test (`pennsylvaniaExemptsNetOfWithholdingViaConfig`) went red as required, plus the
inverse effect on IL/MS (since the mutation is a full ternary swap, not a PA-only change) and 3
frozen baseline conversion scenarios, confirming the baseline is genuinely sensitive to this rule.

Restored the correct ternary. Re-run confirmed GREEN (98 tests / 4 suites passed).

---

## Step 4: Regeneration

```
TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests ENABLE_APP_SANDBOX=NO
...
✔ Test "Generate all 51 jurisdiction files" passed after 0.005 seconds.
** TEST SUCCEEDED **
```

Deletion check (per context item 3):

```
$ git diff --numstat RetireSmartIRA/Resources/StateTaxData/2026/ | awk '$2 != 0 {print "DELETION in " $3}'
(no output)
```

Files changed:

```
$ git status --porcelain RetireSmartIRA/Resources/StateTaxData/2026/
 M RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IL.json
 M RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-MS.json
 M RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-PA.json
```

Exactly the three expected files; the other 48 are untouched.

### Diff: Pennsylvania (one of PA/IL/MS)

```diff
diff --git a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-PA.json b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-PA.json
index 8c4ede7..9e1aaae 100644
--- a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-PA.json
+++ b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-PA.json
@@ -24,6 +24,10 @@
       "kind" : "full"
     },
     "regularExemptionMinAge" : 0,
+    "rothConversionExemption" : {
+      "minAge" : 0,
+      "withheldPortionRemainsTaxable" : true
+    },
     "socialSecurityExempt" : true
   },
   "safeHarborRule" : {
```

### Diff: Illinois (one other state)

```diff
diff --git a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IL.json b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IL.json
index 100f5e7..610acc0 100644
--- a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IL.json
+++ b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IL.json
@@ -24,6 +24,10 @@
       "kind" : "full"
     },
     "regularExemptionMinAge" : 0,
+    "rothConversionExemption" : {
+      "minAge" : 0,
+      "withheldPortionRemainsTaxable" : false
+    },
     "socialSecurityExempt" : true
   },
   "safeHarborRule" : {
```

(Mississippi's diff is byte-identical in shape: `minAge: 0, withheldPortionRemainsTaxable: false`,
same insertion point.)

---

## Step 5: Targeted post-regeneration verification (all green)

Mechanism + round-trip + baseline + retirement-exemption:

```
✔ Suite "State retirement-income exemption wiring (build 41)" passed after 0.046 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.041 seconds.
✔ Suite "State tax Codable round trips (Phase 1)" passed after 0.009 seconds.
✔ Suite "Phase 3a mechanisms are load-bearing" passed after 0.020 seconds.
✔ Test run with 98 tests in 4 suites passed after 0.115 seconds.
```

JSON gate suites + StateTaxBreakdownTests:

```
◇ Suite "State Tax — Breakdown Detail" started.
✔ Suite "State Tax — Breakdown Detail" passed after 0.015 seconds.
◇ Suite "PHASE 1 GATE: JSON configs are behaviorally identical to the legacy table" started.
✔ Suite "PHASE 1 GATE: JSON configs are behaviorally identical to the legacy table" passed after 0.113 seconds.
◇ Suite "PHASE 1 GATE: Layer B, structural equivalence (decode is lossless)" started.
✔ Suite "PHASE 1 GATE: Layer B, structural equivalence (decode is lossless)" passed after 0.111 seconds.
◇ Suite "PHASE 1 GATE: Layer C, file key completeness (the shipped data is complete)" started.
✔ Suite "PHASE 1 GATE: Layer C, file key completeness (the shipped data is complete)" passed after 0.046 seconds.
✔ Test run with 10 tests in 4 suites passed after 0.286 seconds.
```

(`StateTaxJSONEquivalenceTests`/`StateTaxJSONStructuralEquivalenceTests` each run their per-state
checks as one parameterized `@Test` with 51 cases, hence the low top-level count.)

---

## Step 6: Full suite, once, in the foreground

```
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' ENABLE_APP_SANDBOX=NO
```

Ran to completion in the foreground (no Monitor/background use), duration ~289s for the
Swift Testing pass. Both framework summary lines, extracted from the run's own `.xcresult`
diagnostics export (not re-run):

```
	 Executed 503 tests, with 0 failures (0 unexpected) in 20.369 (20.564) seconds
Test Suite 'All tests' passed at 2026-08-03 10:05:08.118.
```

```
✔ Test run with 1655 tests in 278 suites passed after 289.441 seconds.
```

Aggregate xcresult summary (`xcrun xcresulttool get test-results summary`): `"result" : "Passed"`,
`"failedTests" : 0`, `"totalTestCount" : 2158` (2152 passed + 6 skipped, pre-existing skips
unrelated to this task).

### Tree-confirmation grep

```
$ xcodebuild -scheme RetireSmartIRA -showBuildSettings 2>/dev/null | grep -m1 "PROJECT_FILE_PATH"
    PROJECT_FILE_PATH = /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
```

Every individual `xcodebuild` invocation's own build-phase output throughout this task also
showed `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a` for each build
step (visible in the Step-2 RED transcript's build log above), confirming every run in this
report executed against the worktree, not the main checkout.

---

## Controller addendum: grep sweep for other hardcoded PA/IL/MS references

Before any changes (baseline sweep):

```
$ grep -rn "case .pennsylvania\|case .illinois\|case .mississippi\|== .pennsylvania\|== .illinois\|== .mississippi" --include="*.swift" RetireSmartIRA/ | grep -v abbreviation
RetireSmartIRA/DataManager.swift:891:            case .pennsylvania:
RetireSmartIRA/DataManager.swift:893:            case .illinois, .mississippi:
RetireSmartIRA/RothConversionWithholdingCard.swift:40:        isWithheldMode && dataManager.selectedState == .pennsylvania
RetireSmartIRA/TaxCalculationEngine.swift:747:        case .pennsylvania:
RetireSmartIRA/TaxCalculationEngine.swift:750:        case .illinois, .mississippi:
RetireSmartIRA/MultiYearTaxFundingCard.swift:61:        mode.usesCustodialWithholding && state == .pennsylvania
RetireSmartIRA/StateTaxData.swift:87:        case .illinois: "IL"
RetireSmartIRA/StateTaxData.swift:98:        case .mississippi: "MS"
RetireSmartIRA/StateTaxData.swift:112:        case .pennsylvania: "PA"
```

After all changes (final sweep):

```
$ grep -rn "case .pennsylvania\|case .illinois\|case .mississippi\|== .pennsylvania\|== .illinois\|== .mississippi" --include="*.swift" RetireSmartIRA/ | grep -v abbreviation
RetireSmartIRA/RothConversionWithholdingCard.swift:40:        isWithheldMode && dataManager.selectedState == .pennsylvania
RetireSmartIRA/MultiYearTaxFundingCard.swift:61:        mode.usesCustodialWithholding && state == .pennsylvania
RetireSmartIRA/StateTaxData.swift:87:        case .illinois: "IL"
RetireSmartIRA/StateTaxData.swift:98:        case .mississippi: "MS"
RetireSmartIRA/StateTaxData.swift:112:        case .pennsylvania: "PA"
```

Findings:

1. **Both hardcoded tax-math switches are gone** -- `DataManager.swift:889-898` (breakdown
   mirror) and `TaxCalculationEngine.swift:746-754` (the switch this task's brief targeted) no
   longer appear. Both are now `config.retirementExemptions.rothConversionExemption`-driven.
2. **`RetireSmartIRA/StateTaxData.swift:87,98,112`** -- these are three `case` arms of the
   `USState.abbreviation` computed property's own switch (mapping every one of the 51
   jurisdictions to its two-letter code). Not a target: this is the enum's own abbreviation
   table, unrelated to conversion-exemption tax logic, and it maps all 51 states, not just
   PA/IL/MS. Left untouched, as it should be.
3. **`RetireSmartIRA/RothConversionWithholdingCard.swift:40`** and
   **`RetireSmartIRA/MultiYearTaxFundingCard.swift:61`** -- both gate PA-specific disclosure
   copy (a UI string explaining the withholding caveat to the user) on
   `state == .pennsylvania` / `selectedState == .pennsylvania`. Per the controller addendum,
   these were explicitly NOT converted in this task: they are display copy, not tax math, and
   converting them (e.g. to key off `rothConversionExemption?.withheldPortionRemainsTaxable`)
   is a scope decision left for a future task, not a mechanical extension of this one. Reporting
   them here so the decision is recorded rather than forgotten, as instructed.

---

## `git diff --stat`

```
$ git diff --stat HEAD~1
 RetireSmartIRA/DataManager.swift                                       | 28 ++++----
 RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IL.json       |  4 ++
 RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-MS.json       |  4 ++
 RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-PA.json       |  4 ++
 RetireSmartIRA/StateRothConversionExemption.swift                      | 27 +++++++
 RetireSmartIRA/StateTaxCodable.swift                                   |  4 ++
 RetireSmartIRA/StateTaxData.swift                                      | 21 ++++++
 RetireSmartIRA/TaxCalculationEngine.swift                              | 47 +++++--------
 RetireSmartIRATests/StateTaxCodableRoundTripTests.swift                | 30 ++++++++-
 RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift                | 82 +++++++++++++++++++++++
 10 files changed, 205 insertions(+), 46 deletions(-)
```

## Hard constraints respected

- `RetireSmartIRA.xcodeproj/project.pbxproj` was not edited (new file relies on the project's
  synchronized file group -- confirmed by checking that no prior Phase 3a task, including the two
  that also added new Swift files, touched `project.pbxproj` either: `git log --oneline -- \
  RetireSmartIRA.xcodeproj/project.pbxproj` shows only release-bump commits predating this phase).
- No em dash characters used anywhere in code, comments, tests, or the commit message.
- `RetireSmartIRA/ProjectionEngine.swift` was not touched.
- `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift` and
  `RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json` were not edited.
- No JSON file was hand-edited; all three changed JSON files came from the generator test run.
- The two UI files were not converted; both are reported above.
- Commit staged explicit paths only (10 files); no `git add -A` was used.
