# Task 7 Report: Prove every Phase 3a field is guarded against encoder loss

Branch `feature/state-tax-phase3a`, starting HEAD `108990b`. Worktree
`/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a`.

## Step 0: Baseline

Before any mutation, ran the two suites the brief names to confirm a clean
starting point (`StateTaxCodableRoundTripTests` + `StateTaxPhase3aMechanismTests`):

```
✔ Test run with 49 tests in 2 suites passed after 0.040 seconds.
** TEST SUCCEEDED **
```

`.xcodeproj` path in the build log confirmed the worktree:
`cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj`

## Step 1: Measurement — mutate each of the five fields' encode line, one at a time

For each field, the corresponding `encode`/`encodeIfPresent` line in
`RetireSmartIRA/StateTaxCodable.swift` was commented out, the targeted suites
were run, the result recorded, and the line restored (confirmed via
`git diff --stat` showing no changes to the production file before moving to
the next field).

| # | Field | Owner type | Line commented out | Result | Verdict |
|---|-------|-----------|---------------------|--------|---------|
| 1 | `distributionMinAge` | `RetirementIncomeExemptions` | `try c.encode(distributionMinAge, forKey: .distributionMinAge)` | 2 failures (`retirementExemptionsRoundTrip`, `retirementExemptionsEncodesExpectedJSONShape`) | **Already guarded** |
| 2 | `exemptionAttribution` | `RetirementIncomeExemptions` | `try c.encode(exemptionAttribution, forKey: .exemptionAttribution)` | 2 failures (same two tests) | **Already guarded** |
| 3 | `agiPhaseout` | `RetirementIncomeExemptions` | `try c.encodeIfPresent(agiPhaseout, forKey: .agiPhaseout)` | 2 failures (same two tests) | **Already guarded** |
| 4 | `rothConversionExemption` | `RetirementIncomeExemptions` | `try c.encodeIfPresent(rothConversionExemption, forKey: .rothConversionExemption)` | 2 failures (same two tests) | **Already guarded** |
| 5 | `personalExemption` | `StateTaxConfig` | `try c.encodeIfPresent(personalExemption, forKey: .personalExemption)` | **0 failures** — 70/70 tests passed across all 4 targeted suites (`StateTaxCodableRoundTripTests`, `StateTaxPhase3aMechanismTests`, `MetamorphicPropertyTests`, `StateTaxBehaviorBaselineTests`) | **SURVIVED — gap confirmed** |

Evidence for each:

**1. `distributionMinAge` removed:**
```
✘ Test "RetirementIncomeExemptions round-trips with every field populated" recorded an issue at StateTaxCodableRoundTripTests.swift:210:9: Expectation failed: (decoded.distributionMinAge → 59) == (original.distributionMinAge → 55)
✘ Test "Encoded JSON carries all thirteen fields under their own keys, with the right values" recorded an issue at StateTaxCodableRoundTripTests.swift:333:9: Expectation failed: (json["distributionMinAge"] as? Int → nil) == 55
✘ Test run with 49 tests in 2 suites failed after 0.026 seconds with 2 issues.
```

**2. `exemptionAttribution` removed:**
```
✘ Test "RetirementIncomeExemptions round-trips with every field populated" recorded an issue at StateTaxCodableRoundTripTests.swift:209:9: Expectation failed: (decoded.exemptionAttribution → .household) == (original.exemptionAttribution → .perQualifyingSpouse)
✘ Test "Encoded JSON carries all thirteen fields under their own keys, with the right values" recorded an issue at StateTaxCodableRoundTripTests.swift:332:9: Expectation failed: (json["exemptionAttribution"] as? String → nil) == "perQualifyingSpouse"
✘ Test run with 49 tests in 2 suites failed after 0.027 seconds with 2 issues.
```

**3. `agiPhaseout` removed:**
```
✘ Test "RetirementIncomeExemptions round-trips with every field populated" recorded an issue at StateTaxCodableRoundTripTests.swift:213:9: Expectation failed: (decoded.agiPhaseout → nil) == (original.agiPhaseout → AGIPhaseout(thresholdSingle: 50000.0, thresholdMFJ: 75000.0, shape: RetireSmartIRA.AGIPhaseout.Shape.linear(perDollar: 1.6)))
✘ Test "Encoded JSON carries all thirteen fields under their own keys, with the right values" recorded an issue at StateTaxCodableRoundTripTests.swift:353:28: Expectation failed: (json["agiPhaseout"] → nil) as? ([String: Any] → Optional<Any>)
✘ Test run with 49 tests in 2 suites failed after 0.024 seconds with 2 issues.
```

**4. `rothConversionExemption` removed:**
```
✘ Test "RetirementIncomeExemptions round-trips with every field populated" recorded an issue at StateTaxCodableRoundTripTests.swift:214:9: Expectation failed: (decoded.rothConversionExemption → nil) == (original.rothConversionExemption → RothConversionExemption(minAge: 55, withheldPortionRemainsTaxable: true))
✘ Test "Encoded JSON carries all thirteen fields under their own keys, with the right values" recorded an issue at StateTaxCodableRoundTripTests.swift:359:34: Expectation failed: (json["rothConversionExemption"] → nil) as? ([String: Any] → Optional<Any>)
✘ Test run with 49 tests in 2 suites failed after 0.025 seconds with 2 issues.
```

**5. `personalExemption` removed:**
```
◇ Test run started.
✔ Test run with 70 tests in 4 suites passed after 0.133 seconds.
** TEST SUCCEEDED **
```
Silent. Confirms the brief's prediction exactly: `retirementExemptionsEncodesExpectedJSONShape`
covers `RetirementIncomeExemptions`'s thirteen keys, but `personalExemption`
lives on `StateTaxConfig` and its own JSON-shape fixture
(`stateTaxConfigEncodesExpectedJSONShape`) never asserts on it. Layer B
(round-trip / JSON-shape tests) cancels symmetrically because both the
encoded output and the decoded-then-reencoded comparison omit the field the
same way; Layer C (shipped-file tests like
`onlyNewJerseyCarriesAPersonalExemptionInPhase3a` and
`newJerseyConfigExemptionValuesArePinned`) reads the real file on disk via
`StateTaxDataLoader.load`, which still carries the key regardless of what the
in-memory encoder does.

**Conclusion of Step 1:** four of the five fields already have a general
JSON-shape guard from Task 4-6's work on `retirementExemptionsEncodesExpectedJSONShape`.
Only `personalExemption` needed a new test. Per the brief's instruction,
no test was added for the other four (that would be a redundant second
assertion on an already-covered field).

## Step 2: New test — `personalExemptionEncodingIsConditional`

Added to `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`, immediately
after `stateTaxConfigEncodesExpectedJSONShape` and before
`stateTaxConfigBooleanKeysAreMutuallyDistinguishable`, following the brief's
Step 1 example. Asserts the raw encoded JSON dictionary directly (not a
round-tripped/decoded value), matching the style of the other
`...EncodesExpectedJSONShape` tests in this file:

- When `personalExemption` is present, all four of its fields
  (`single`, `marriedFilingJointly`, `seniorAdditionalPerFiler`, `seniorAge`)
  appear under their own keys with the right values.
- When `personalExemption` is `nil`, the `personalExemption` key is absent
  from the JSON entirely (not `null`).

Per the brief's note, `single: 1_000` and `seniorAdditionalPerFiler: 1_000`
are the same value in this fixture, so a swap between those two specific
CodingKeys labels would produce byte-identical JSON and this test alone
cannot distinguish them (pigeonhole, same failure mode the file's own
`retirementExemptionsBooleanKeysAreMutuallyDistinguishable` and
`stateTaxConfigBooleanKeysAreMutuallyDistinguishable` document for
same-valued Bool fields). That gap is acceptable only because
`StateTaxPhase3aMechanismTests.personalExemptionSeniorIsPerFiler` (Task 3)
catches a single/seniorAdditionalPerFiler swap behaviorally: it asserts
3,000 for a household where one spouse is 66 and the other 60 — a result
only reachable when `seniorAdditionalPerFiler` (not `single`) is the amount
added on top of `marriedFilingJointly`. This reasoning is stated in a code
comment on the new test, not left implicit.

Also fixed one syntax issue while adding the test: the brief's example used
a two-line string literal joined with a trailing `\`, which is not valid
Swift outside a triple-quoted string (`"""..."""`). Rewrote it as a
triple-quoted multi-line string with the same trailing-backslash
line-join, matching the pattern already used elsewhere in this file (e.g.
`everyStateShipsHouseholdAttribution`'s message in
`StateTaxPhase3aMechanismTests.swift`).

### Discrimination proof

RED — commented out `try c.encodeIfPresent(personalExemption, forKey: .personalExemption)`
in `StateTaxCodable.swift`, ran the full `StateTaxCodableRoundTripTests` suite:
```
◇ Test run started.
✘ Test "personalExemption appears in encoded StateTaxConfig JSON when present, and is absent when nil" recorded an issue at StateTaxCodableRoundTripTests.swift:552:29: Expectation failed: (present["personalExemption"] → nil) as? ([String: Any] → Optional<Any>)
✘ Test "personalExemption appears in encoded StateTaxConfig JSON when present, and is absent when nil" failed after 0.001 seconds with 1 issue.
✘ Suite "State tax Codable round trips (Phase 1)" failed after 0.019 seconds with 1 issue.
✘ Test run with 21 tests in 1 suite failed after 0.019 seconds with 1 issue.
	StateTaxCodableRoundTripTests.personalExemptionEncodingIsConditional()
** TEST FAILED **
```
Only the new test failed; the other 20 tests in the suite stayed green,
confirming this is the only guard for this specific gap.

GREEN — restored the encode line, confirmed via `git diff --stat` (no output,
clean), reran:
```
◇ Test run started.
✔ Test run with 21 tests in 1 suite passed after 0.019 seconds.
** TEST SUCCEEDED **
```

## Item (a): pin Mississippi's `withheldPortionRemainsTaxable` in the shipped-data test

`RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`,
`onlyThreeStatesCarryAConversionExemption`, pinned Pennsylvania's (`true`)
and Illinois's (`false`) `withheldPortionRemainsTaxable` but never
Mississippi's. Added:

```swift
#expect(withExemption[.mississippi]?["withheldPortionRemainsTaxable"] as? Bool == false)
```

immediately after the existing Illinois line.

### Discrimination proof

RED — edited `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-MS.json`,
flipping `"withheldPortionRemainsTaxable" : false` to `true` under
`rothConversionExemption`, ran `StateTaxPhase3aMechanismTests`:
```
◇ Test run started.
✘ Test "Illinois and Mississippi exempt the gross conversion regardless of withholding" recorded an issue at StateTaxPhase3aMechanismTests.swift:540:13: Expectation failed: (taxed → 880.0) == (0 → 0.0)
✘ Test "Illinois and Mississippi exempt the gross conversion regardless of withholding" failed after 0.001 seconds with 1 issue.
✘ Test "Exactly PA, IL and MS carry a conversion exemption in Phase 3a" recorded an issue at StateTaxPhase3aMechanismTests.swift:589:9: Expectation failed: (withExemption[.mississippi]?["withheldPortionRemainsTaxable"] as? Bool → true) == false
✘ Test "Exactly PA, IL and MS carry a conversion exemption in Phase 3a" failed after 0.003 seconds with 1 issue.
✘ Test run with 29 tests in 1 suite failed after 0.027 seconds with 2 issues.
```
Line 589 is exactly the newly added assertion (confirmed by reading the file
at that line during the mutation). The extra failure on
`illinoisAndMississippiExemptGrossViaConfig` is expected collateral: that
behavioral test reads the same live shipped config through
`TaxCalculationEngine.calculateStateTax`, so flipping the shipped bit also
breaks the pre-existing behavioral assertion. This confirms the shipped bit
is genuinely load-bearing, not just newly pinned.

GREEN — restored the JSON file, confirmed via `git diff --stat` (no output,
clean), reran:
```
◇ Test run started.
✔ Test run with 29 tests in 1 suite passed after 0.027 seconds.
** TEST SUCCEEDED **
```

## Item (b): conversion-withholding case in `MetamorphicPropertyTests.crossViewMatrix`

Confirmed the gap: `crossViewMatrix` (a `[(USState, Double, Double)]` of
`(state, extraWithdrawal, rothConversion)`, consumed by both `p16` and `p17`)
had no dimension for Roth-conversion withholding at all — every case leaves
`DataManager.rothConversionWithholdingMode` at its default `.paidFromOutside`,
so `scenarioRothConversionWithholdingAmount` is always `$0`. That makes the
GROSS branch of the net-vs-gross ternary in both
`TaxCalculationEngine.applyRetirementExemptions` (line ~738-747) and its
mirror in `DataManager.stateTaxBreakdown` (line ~886-894) indistinguishable
from the withheld-portion-taxable branch: `gross - $0 == gross` either way.
Illinois and Mississippi both set `withheldPortionRemainsTaxable: false` in
their shipped config, so they always take that GROSS branch, and it was
never exercised with nonzero withholding.

This was not an unfixable structural blocker: the tuple was extended by one
element, `RothConversionWithholdingMode`, defaulting to `.paidFromOutside`
for all 15 existing combinations (preserving their exact prior behavior) and
appending two new combinations —
`(.illinois, 0, 50_000, .withheldFromConversion)` and
`(.mississippi, 0, 50_000, .withheldFromConversion)` — bringing the matrix
from 15 to 17 cases. This matches the file's existing shape: a static array
of tuples built from orthogonal dimensions via `flatMap`/`map`, consumed
identically by two parameterized `@Test` functions. `makeSingle` gained one
new defaulted parameter (`rothConversionWithholdingMode`, default
`.paidFromOutside`) to set `dm.rothConversionWithholdingMode`; both `p16`
and `p17` gained the corresponding fourth parameter and pass it through.
No other test in the file was touched, and no existing call site of
`makeSingle` needed updating since the new parameter is defaulted.

`P16` was left calling `calculateStateTaxFromGross` without an explicit
withholding argument (that helper has no such parameter — it defaults to 0
internally), which is fine for these two new cases specifically: since
IL/MS's `withheldPortionRemainsTaxable == false`, the GROSS branch ignores
withholding on both sides of P16's comparison, so P16 is not the property
that catches a broken GROSS branch here. P17 (`stateTaxBreakdown.totalStateTax`
vs `scenarioStateTax`) compares two independently-written implementations —
the DataManager mirror and the actual TaxCalculationEngine — so it is the
property that would catch either one drifting.

### Discrimination proof

Confirmed the two new cases actually execute (not just get added to a list
nobody runs), by grepping the verbose xcodebuild log for the P16/P17 test-case
lines:
```
◇ Test case passing 4 arguments state → .illinois, extraWithdrawal → 0.0, rothConversion → 50000.0, withholdingMode → .withheldFromConversion to "P16: ..." started.
◇ Test case passing 4 arguments state → .mississippi, extraWithdrawal → 0.0, rothConversion → 50000.0, withholdingMode → .withheldFromConversion to "P16: ..." started.
✔ Test "P16: ..." with 17 test cases passed after 0.018 seconds.
```
(same two cases present under P17, also passing, `with 17 test cases`).

RED — mutated `DataManager.stateTaxBreakdown`'s ternary at line ~891-893 so
the GROSS (false) branch also subtracts withholding, i.e. made both branches
identical to the withheld-taxable formula:
```swift
return conversionRule.withheldPortionRemainsTaxable
    ? max(0, scenarioTotalRothConversion - scenarioRothConversionWithholdingAmount)
    : max(0, scenarioTotalRothConversion - scenarioRothConversionWithholdingAmount)
```
Ran `MetamorphicPropertyTests`:
```
◇ Test run started.
✘ Test "P17: stateTaxBreakdown.totalStateTax matches scenarioStateTax" recorded an issue with 4 arguments state → .illinois, extraWithdrawal → 0.0, rothConversion → 50000.0, withholdingMode → .withheldFromConversion at MetamorphicPropertyTests.swift:356:9: Expectation failed: (abs(breakdown.totalStateTax - dm.scenarioStateTax) → 594.0) < 1.0
✘ Test "P17: stateTaxBreakdown.totalStateTax matches scenarioStateTax" recorded an issue with 4 arguments state → .mississippi, extraWithdrawal → 0.0, rothConversion → 50000.0, withholdingMode → .withheldFromConversion at MetamorphicPropertyTests.swift:356:9: Expectation failed: (abs(breakdown.totalStateTax - dm.scenarioStateTax) → 388.0) < 1.0
✘ Test "P17: stateTaxBreakdown.totalStateTax matches scenarioStateTax" with 17 test cases failed after 0.017 seconds with 2 issues.
✘ Test run with 20 tests in 1 suite failed after 0.066 seconds with 2 issues.
```
Both new IL and MS withholding cases fail; every other one of the 17 P17
cases (and all of P16) stayed green, confirming this pair of cases is what
guards the mirror's GROSS branch.

GREEN — restored `DataManager.swift`, confirmed via `git diff --stat` (no
output, clean), reran:
```
◇ Test run started.
✔ Test run with 20 tests in 1 suite passed after 0.063 seconds.
** TEST SUCCEEDED **
```

## Targeted suites, together, before the full run

```
✔ Test run with 71 tests in 4 suites passed after 0.137 seconds.
** TEST SUCCEEDED **
```
(`StateTaxCodableRoundTripTests` + `StateTaxPhase3aMechanismTests` +
`MetamorphicPropertyTests` + `StateTaxBehaviorBaselineTests`, all in the
foreground.)

## Full suite, once, in the foreground

Ran `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' ENABLE_APP_SANDBOX=NO`
with no `-only-testing` filter.

Both summary lines:
```
Test Suite 'All tests' passed at 2026-08-03 10:38:19.653.
	 Executed 503 tests, with 0 failures (0 unexpected) in 19.794 (20.105) seconds
```
```
✔ Test run with 1656 tests in 278 suites passed after 289.125 seconds.
```
`** TEST SUCCEEDED **`

Tree-confirmation grep (xcodeproj path used by this build):
```
$ grep -n "\.xcodeproj" full-suite.log | head -1
45:    cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
```
Confirms the run built and tested `.worktrees/state-tax-phase3a`, not the
main checkout.

## Final diff

```
$ git diff --stat
 RetireSmartIRATests/MetamorphicPropertyTests.swift | 54 +++++++++++++++-----
 .../StateTaxCodableRoundTripTests.swift            | 57 ++++++++++++++++++++++
 .../StateTaxPhase3aMechanismTests.swift            |  1 +
 3 files changed, 101 insertions(+), 11 deletions(-)
```
Three files, all under `RetireSmartIRATests/`. No production source file has
a net change — `RetireSmartIRA/StateTaxCodable.swift` and
`RetireSmartIRA/DataManager.swift` were both mutated and restored during
verification, and `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-MS.json`
was mutated and restored during verification; `git diff --stat` on each shows
no output, confirming a clean restore. `StateTaxBehaviorBaselineTests.swift`
and `Baselines/statetax-behavior-baseline-2026.json` were not touched.
`RetireSmartIRA.xcodeproj/project.pbxproj` was not touched — no new files
were created, only existing test files edited.

## Summary

- All five Phase 3a fields are now proven guarded against a dropped encode
  line: four (`distributionMinAge`, `exemptionAttribution`, `agiPhaseout`,
  `rothConversionExemption`) already were, via
  `retirementExemptionsEncodesExpectedJSONShape`; `personalExemption` was
  not and now is, via the new `personalExemptionEncodingIsConditional`.
- Item (a): Mississippi's `withheldPortionRemainsTaxable` is now pinned in
  `onlyThreeStatesCarryAConversionExemption`, alongside PA and IL.
- Item (b): `crossViewMatrix` now includes two Illinois/Mississippi cases
  with nonzero Roth-conversion withholding, closing the GROSS-branch
  coverage gap in `DataManager.stateTaxBreakdown`'s net-vs-gross mirror.
  This was achievable without restructuring — no genuine blocker was found.
- Full suite: 503 XCTest + 1,656 Swift Testing = 2,159 tests, all green.
- No production source changes remain (confirmed by `git diff --stat`
  showing only test files).
