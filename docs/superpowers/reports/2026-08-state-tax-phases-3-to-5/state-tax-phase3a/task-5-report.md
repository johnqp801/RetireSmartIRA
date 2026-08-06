# Task 5 report: Per-qualifying-spouse attribution

Status: DONE
Commit: `5fe180e2eb0419ed5834d22166d3f25ace6eadf0` on `feature/state-tax-phase3a`

## Summary

Added `ExemptionAttribution` (`.household` / `.perQualifyingSpouse`) and
`RetirementIncomeExemptions.exemptionAttribution` (default `.household`).
Wired the engine so pension/RMD `IncomeSource` rows are filtered by the
owner's individual qualification, joint-owned rows use the more generous
age, and `scenarioRetirementDistributions` (which has no owner) is
attributed to the primary. Every state's shipped config stays `.household`;
regeneration added exactly one line (`"exemptionAttribution" : "household"`)
to each of the 51 JSON files, no deletions. Full suite green: 1646 Swift
Testing tests + 503 XCTest tests, 0 failures.

Two deviations from the brief's literal code were required to make the
brief's own verbatim test code compile and pass. Both are documented below
with evidence.

---

## Deviation 1: struct field placement (compile-time, forced by Swift's argument-order rule)

The brief's Step 3 says to place `exemptionAttribution` "after
`exemptionAppliesPerIndividual`" (i.e. before `regularExemptionMinAge`).
But the brief's own verbatim Step 1 test constructs:

```swift
RetirementIncomeExemptions(
    socialSecurityExempt: true,
    pensionExemption: .full,
    iraWithdrawalExemption: .full,
    regularExemptionMinAge: 65,
    exemptionAttribution: attribution)
```

Swift's synthesized memberwise initializer requires call-site keyword
arguments to appear in the same relative order as the declared properties.
Placing `exemptionAttribution` before `regularExemptionMinAge` in the struct
(as Step 3 literally says) makes the above call illegal:

```
error: argument 'exemptionAttribution' must precede argument 'regularExemptionMinAge'
```

Since the task's hard instruction is to use the test code verbatim, I moved
the field to declare it **after** `regularExemptionMinAge` instead (still
immediately before `distributionMinAge`), and updated `StateTaxCodable.swift`'s
`init(from:)` argument order and the round-trip/JSON-shape fixtures'
`exemptionAttribution: .perQualifyingSpouse` placement to match. This is a
declaration-order change only; it does not affect JSON key names or values.

## Deviation 2: `retirementAge`'s `.perQualifyingSpouse` case

The brief's literal Step 4 code:

```swift
case .perQualifyingSpouse:
    retirementAge = primaryAge >= exemptions.distributionMinAge
```

This only gates the scalar's *inclusion* in `iraIncome` via
`distributionMinAge`. But the *exclusion amount* actually applied to that
included income comes from `effectiveIRAExemption`, computed via
`resolveLevel`/`effectiveAge = max(primaryAge, spouseAge)` when a spouse is
enabled — unconditionally household-based, untouched by attribution. So
with a synthetic config setting `regularExemptionMinAge: 65` (as the
brief's own mechanism test `attributionConfig` does) and primary=60/spouse=70,
the literal brief code produces: `retirementAge` true (60 >= 59 default
distributionMinAge) -> scalar included in `iraIncome` -> but the level is
still `.full` because `effectiveAge = max(60,70) = 70 >= 65`. Result: the
scalar is still fully exempted, taxed = 0. The brief's own test
`scenarioDistributionsAreAttributedToThePrimary` expects 4,000 (fully
taxed), since the primary alone does not qualify. I confirmed this by
running the literal code and observing the failure (see RED-2 below).

Fix: use `ageQualifiesForExemption(primaryAge)` instead of the raw
`distributionMinAge` comparison. `ageQualifiesForExemption` already honors
`regularExemptionMinAge`/`earlyAgeTier` when set, falling back to
`distributionMinAge` when `regularExemptionMinAge == 0` (every state today,
since no state carries `.perQualifyingSpouse` in this phase). So for every
currently-relevant (`.household`) config this is byte-identical to the
brief's literal formula; it only changes behavior for the never-shipped
`.perQualifyingSpouse` branch, which no baseline test exercises.

```swift
case .perQualifyingSpouse:
    // Not just distributionMinAge: `ageQualifiesForExemption` also
    // honors `regularExemptionMinAge`/`earlyAgeTier` when set, which
    // is what actually determines effectiveIRAExemption's level
    // below. Using the plain distributionMinAge comparison here would
    // let a primary who fails the state's real age gate still draw
    // the household-level exemption on the scalar, because that
    // level is computed from `effectiveAge` (household max), not the
    // primary alone. When regularExemptionMinAge is 0 (every state
    // today), this reduces to the identical
    // `primaryAge >= exemptions.distributionMinAge` comparison.
    retirementAge = ageQualifiesForExemption(primaryAge)
```

---

## RED transcript (Step 2), pasted verbatim

First attempt hit a *different*, unrelated compile error first: the
brief's verbatim `noStateUsesPerSpouseAttributionYet` test body used a
backslash line-continuation inside a plain `"..."` string literal, which
Swift does not support (only triple-quoted `"""..."""` literals allow
that). This produced a syntax error instead of the expected "cannot find
'ExemptionAttribution'" error:

```
/Users/.../RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:430:91: error: invalid escape sequence in literal
                    "\(state.abbreviation) changed attribution in Phase 3a. Iowa and the \
                                                                                          ^
/Users/.../RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:430:21: error: unterminated string literal
                    "\(state.abbreviation) changed attribution in Phase 3a. Iowa and the \
                    ^
/Users/.../RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:431:60: error: 'c' is not a valid digit in integer literal
                    per-person statutes adopt it in Phase 5c, each gated by a golden scenario.")
                                                           ^
/Users/.../RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:431:95: error: unterminated string literal
                    per-person statutes adopt it in Phase 5c, each gated by a golden scenario.")
                                                                                              ^
```

Fixed by converting that one string literal to a triple-quoted string
(matching the existing pattern already used elsewhere in the same file for
multi-line `#expect` messages), preserving the exact text. Re-ran:

```
/Users/.../RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:359:50: error: cannot find type 'ExemptionAttribution' in scope
    static func attributionConfig(_ attribution: ExemptionAttribution) -> StateTaxConfig {
                                                 ^~~~~~~~~~~~~~~~~~~~
/Users/.../RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:365:35: error: extra argument 'exemptionAttribution' in call
            exemptionAttribution: attribution))
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~~~~~~~
/Users/.../RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:370:46: error: cannot infer contextual base in reference to member 'household'
        let config = Self.attributionConfig(.household)
                                            ~^~~~~~~~~
/Users/.../RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:380:46: error: cannot infer contextual base in reference to member 'perQualifyingSpouse'
        let config = Self.attributionConfig(.perQualifyingSpouse)
                                            ~^~~~~~~~~~~~~~~~~~~
/Users/.../RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:395:46: error: cannot infer contextual base in reference to member 'perQualifyingSpouse'
        let config = Self.attributionConfig(.perQualifyingSpouse)
                                            ~^~~~~~~~~~~~~~~~~~~
/Users/.../RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:406:61: error: cannot infer contextual base in reference to member 'household'
...
** TEST FAILED **
```

This is the expected RED ("cannot find `ExemptionAttribution` in scope").

## RED-2 (Deviation 2's evidence): mechanism test failure under the brief's literal `retirementAge` code

After adding the type/field and wiring `pensionIncome`/`rmdSourceIncome`/the
`retirementAge` switch exactly as the brief's Step 4 gives it (before
applying the `ageQualifiesForExemption` fix), the full mechanism suite ran
21/22 passing with this failure:

```
✘ Test "Scenario distributions have no owner, so per-spouse attribution gates them on the primary" recorded an issue at StateTaxPhase3aMechanismTests.swift:417:9: Expectation failed: (Self.mfjTax(config: config, primaryAge: 60, spouseAge: 70,
✘ Test "Scenario distributions have no owner, so per-spouse attribution gates them on the primary" failed after 0.001 seconds with 1 issue.
✔ Test "Every jurisdiction uses household attribution in Phase 3a" passed after 0.002 seconds.
✘ Suite "Phase 3a mechanisms are load-bearing" failed after 0.018 seconds with 1 issue.
✘ Test run with 22 tests in 1 suite failed after 0.019 seconds with 1 issue.
** TEST FAILED **
```

After applying the `ageQualifiesForExemption(primaryAge)` fix, all 22
mechanism tests passed (see GREEN transcript below).

---

## GREEN transcripts

### Mechanism tests (22/22)

```
✔ Test "distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59" passed after 0.001 seconds.
✔ Test "distributionMinAge defaults to 59, reproducing the previous hardcoded gate" passed after 0.001 seconds.
✔ Test "distributionMinAge also gates per-individual cap doubling, not only scenario distributions" passed after 0.001 seconds.
✔ Test "StatePersonalExemption reproduces New Jersey's four documented outcomes" passed after 0.001 seconds.
✔ Test "A filer on MFJ with no spouse configured gets the single amounts" passed after 0.001 seconds.
✔ Test "Only one spouse over the senior age gets exactly one senior addition" passed after 0.001 seconds.
✔ Test "A state with no senior addition ignores age entirely" passed after 0.001 seconds.
✔ Test "New Jersey's shipped config carries its four exemption values exactly" passed after 0.006 seconds.
✔ Test "New Jersey's config carries the personal exemption; no other state does" passed after 0.002 seconds.
✔ Test "A cliff phase-out removes the whole exclusion above the threshold and nothing below it" passed after 0.001 seconds.
✔ Test "A dollar-for-dollar phase-out reduces the exclusion by the excess and floors at zero" passed after 0.001 seconds.
✔ Test "A fractional ramp reaches zero at the far end of the band" passed after 0.001 seconds.
✔ Test "agiPhaseout reaches the engine and reduces real computed tax" passed after 0.001 seconds.
✔ Test "agiPhaseout reduces the exclusion in the shared-cap branch too" passed after 0.001 seconds.
✔ Test "agiPhaseout reduces the IRA subtraction, not only the pension one" passed after 0.001 seconds.
✔ Test "No jurisdiction ships an agiPhaseout key in Phase 3a" passed after 0.001 seconds.
✔ Test "Household attribution exempts a non-qualifying spouse's pension when the other qualifies" passed after 0.001 seconds.
✔ Test "Per-qualifying-spouse attribution taxes the non-qualifying spouse's own pension" passed after 0.001 seconds.
✔ Test "Per-qualifying-spouse attribution still exempts the qualifying spouse's own pension" passed after 0.001 seconds.
✔ Test "A joint-owned row qualifies when either spouse qualifies, under both attributions" passed after 0.001 seconds.
✔ Test "Scenario distributions have no owner, so per-spouse attribution gates them on the primary" passed after 0.001 seconds.
✔ Test "Every jurisdiction uses household attribution in Phase 3a" passed after 0.002 seconds.
✔ Suite "Phase 3a mechanisms are load-bearing" passed after 0.019 seconds.
✔ Test run with 22 tests in 1 suite passed after 0.020 seconds.
** TEST SUCCEEDED **
```

### Behavior baseline gate (51 jurisdictions x 20 scenarios, held)

```
​✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.044 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.044 seconds.
```

Confirmed both with the exact `retirementAge`/`pensionIncome`/
`rmdSourceIncome` code from the brief AND after the `ageQualifiesForExemption`
fix -- the baseline is untouched by either version, since every state stays
`.household` and the household branch is byte-identical to the pre-Task-5
code.

### Round-trip tests (19/19, including the two extended fixtures)

```
✔ Test "StateVerification round-trips through JSON" passed after 0.001 seconds.
✔ Test "StateVerification defaults to unverified with empty collections" passed after 0.001 seconds.
✔ Test "StateTaxSystem round-trips every case" passed after 0.001 seconds.
✔ Test "StateDeduction round-trips every case" passed after 0.001 seconds.
✔ Test "EstimatedPaymentSchedule round-trips" passed after 0.001 seconds.
✔ Test "StateSafeHarborRule round-trips every case" passed after 0.001 seconds.
✔ Test "ExemptionLevel round-trips every case including NJ's stepped phaseout" passed after 0.001 seconds.
✔ Test "RetirementIncomeExemptions round-trips with every field populated" passed after 0.001 seconds.
✔ Test "Decoding tolerates a file missing optional fields" passed after 0.001 seconds.
✔ Test "Decoding a completely empty JSON object yields every declared default" passed after 0.001 seconds.
✔ Test "Encoded JSON carries all twelve fields under their own keys, with the right values" passed after 0.001 seconds.
✔ Test "Two complementary Bool arrangements make every pair of the four Bool fields mutually distinguishable" passed after 0.003 seconds.
✔ Test "AgeTier decode throws a reportable error, not a ClosedRange trap, when minAge exceeds maxAge" passed after 0.001 seconds.
✔ Test "StateTaxConfig round-trips with verification metadata" passed after 0.001 seconds.
✔ Test "Encoded JSON carries state as an abbreviation string, currentYearSafeHarborRate, estimatedPaymentSchedule, safeHarborRule, and a nested verification object" passed after 0.001 seconds.
✔ Test "Three fixtures make every pair of StateTaxConfig's five Bool fields mutually distinguishable" passed after 0.001 seconds.
✔ Test "Decoding an unknown state abbreviation throws a DecodingError instead of silently defaulting" passed after 0.003 seconds.
✔ Test "Every StateSafeHarborRule used in the real config table round-trips" passed after 0.001 seconds.
✔ Test "AGIPhaseout round-trips both shapes with distinct per-field values" passed after 0.001 seconds.
✔ Test run with 19 tests in 1 suite passed after 0.014 seconds.
** TEST SUCCEEDED **
```

### Six targeted suites together (post-regeneration confirmation), 46 tests

```
◇ Test run started.
​✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.044 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.044 seconds.
... [19 Codable round-trip tests, all passed] ...
✔ Suite "State tax Codable round trips (Phase 1)" passed after 0.010 seconds.
​✔ Test "Every jurisdiction computes identical state tax from JSON and from the legacy table" with 51 test cases passed after 0.115 seconds.
✔ Suite "PHASE 1 GATE: JSON configs are behaviorally identical to the legacy table" passed after 0.116 seconds.
​✔ Test "Re-encoding the JSON-loaded config is byte-identical to re-encoding the legacy config" with 51 test cases passed after 0.110 seconds.
✔ Suite "PHASE 1 GATE: Layer B, structural equivalence (decode is lossless)" passed after 0.110 seconds.
​✔ Test "Each bundled JSON file carries every required top-level key and no unknown ones" with 51 test cases passed after 0.031 seconds.
✔ Test "Exactly one jurisdiction ships a personalExemption key in Phase 3a" passed after 0.007 seconds.
✔ Suite "PHASE 1 GATE: Layer C, file key completeness (the shipped data is complete)" passed after 0.039 seconds.
... [22 Phase 3a mechanism tests, all passed] ...
✔ Suite "Phase 3a mechanisms are load-bearing" passed after 0.018 seconds.
✔ Test run with 46 tests in 6 suites passed after 0.340 seconds.
** TEST SUCCEEDED **
```

---

## Regeneration

Command run:

```
TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests ENABLE_APP_SANDBOX=NO
```

Result: `✔ Test run with 1 test in 1 suite passed after 0.007 seconds. ** TEST SUCCEEDED **`

`git diff --numstat` on the data directory: 51 files changed, each `1  0`
(one insertion, zero deletions).

Deletion check:

```
$ git diff --numstat RetireSmartIRA/Resources/StateTaxData/2026/ | awk '$2 != 0 {print "DELETION in " $3}'
(no output)
```

One state's full diff (Kansas), showing the shape:

```diff
diff --git a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
index 53e6068..0170ebf 100644
--- a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
+++ b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
@@ -14,6 +14,7 @@
     "capitalGainsTreatment" : "followsFederal",
     "distributionMinAge" : 59,
     "exemptionAppliesPerIndividual" : false,
+    "exemptionAttribution" : "household",
     "iraWithdrawalExemption" : {
       "kind" : "none"
     },
```

All 51 files carry the identical one-line addition, `"exemptionAttribution" : "household"`, inside `retirementExemptions`.

---

## Encoder mutation proof (Point 6)

Deleted `try c.encode(exemptionAttribution, forKey: .exemptionAttribution)`
from `StateTaxCodable.swift`, ran the round-trip suite:

```
◇ Test run started.
✘ Test "RetirementIncomeExemptions round-trips with every field populated" recorded an issue at StateTaxCodableRoundTripTests.swift:207:9: Expectation failed: (decoded.exemptionAttribution → .household) == (original.exemptionAttribution → .perQualifyingSpouse)
✘ Test "RetirementIncomeExemptions round-trips with every field populated" failed after 0.002 seconds with 1 issue.
✘ Test "Encoded JSON carries all twelve fields under their own keys, with the right values" recorded an issue at StateTaxCodableRoundTripTests.swift:312:9: Expectation failed: (json["exemptionAttribution"] as? String → nil) == "perQualifyingSpouse"
✘ Test "Encoded JSON carries all twelve fields under their own keys, with the right values" failed after 0.001 seconds with 1 issue.
✘ Suite "State tax Codable round trips (Phase 1)" failed after 0.010 seconds with 2 issues.
✘ Test run with 19 tests in 1 suite failed after 0.010 seconds with 2 issues.
** TEST FAILED **
```

Restored the encode line, ran again:

```
◇ Test run started.
✔ Test run with 19 tests in 1 suite passed after 0.014 seconds.
** TEST SUCCEEDED **
```

`git diff RetireSmartIRA/StateTaxCodable.swift` after the restore showed no
stray mutation -- the diff against the pre-Task-5 baseline contains only the
intended Task 5 additions (CodingKeys reorder/addition, the encode line, and
the `init(from:)` addition), confirming the delete/restore cycle was clean.

---

## Full-suite result

```
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/p3a-task5.log | tail -40
```

Swift Testing summary line:

```
✔ Test run with 1646 tests in 278 suites passed after 299.345 seconds.
```

XCTest summary line:

```
Executed 503 tests, with 0 failures (0 unexpected) in 20.290 (20.614) seconds
```

Both followed by `** TEST SUCCEEDED **`.

Tree confirmation:

```
$ grep -o "worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj" /tmp/p3a-task5.log | head -1
worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
```

---

## `git diff --stat` (staged at commit time)

```
 .../StateTaxData/2026/statetax-2026-AK.json        |  1 +
 .../StateTaxData/2026/statetax-2026-AL.json        |  1 +
 .../StateTaxData/2026/statetax-2026-AR.json        |  1 +
 .../StateTaxData/2026/statetax-2026-AZ.json        |  1 +
 .../StateTaxData/2026/statetax-2026-CA.json        |  1 +
 .../StateTaxData/2026/statetax-2026-CO.json        |  1 +
 .../StateTaxData/2026/statetax-2026-CT.json        |  1 +
 .../StateTaxData/2026/statetax-2026-DC.json        |  1 +
 .../StateTaxData/2026/statetax-2026-DE.json        |  1 +
 .../StateTaxData/2026/statetax-2026-FL.json        |  1 +
 .../StateTaxData/2026/statetax-2026-GA.json        |  1 +
 .../StateTaxData/2026/statetax-2026-HI.json        |  1 +
 .../StateTaxData/2026/statetax-2026-IA.json        |  1 +
 .../StateTaxData/2026/statetax-2026-ID.json        |  1 +
 .../StateTaxData/2026/statetax-2026-IL.json        |  1 +
 .../StateTaxData/2026/statetax-2026-IN.json        |  1 +
 .../StateTaxData/2026/statetax-2026-KS.json        |  1 +
 .../StateTaxData/2026/statetax-2026-KY.json        |  1 +
 .../StateTaxData/2026/statetax-2026-LA.json        |  1 +
 .../StateTaxData/2026/statetax-2026-MA.json        |  1 +
 .../StateTaxData/2026/statetax-2026-MD.json        |  1 +
 .../StateTaxData/2026/statetax-2026-ME.json        |  1 +
 .../StateTaxData/2026/statetax-2026-MI.json        |  1 +
 .../StateTaxData/2026/statetax-2026-MN.json        |  1 +
 .../StateTaxData/2026/statetax-2026-MO.json        |  1 +
 .../StateTaxData/2026/statetax-2026-MS.json        |  1 +
 .../StateTaxData/2026/statetax-2026-MT.json        |  1 +
 .../StateTaxData/2026/statetax-2026-NC.json        |  1 +
 .../StateTaxData/2026/statetax-2026-ND.json        |  1 +
 .../StateTaxData/2026/statetax-2026-NE.json        |  1 +
 .../StateTaxData/2026/statetax-2026-NH.json        |  1 +
 .../StateTaxData/2026/statetax-2026-NJ.json        |  1 +
 .../StateTaxData/2026/statetax-2026-NM.json        |  1 +
 .../StateTaxData/2026/statetax-2026-NV.json        |  1 +
 .../StateTaxData/2026/statetax-2026-NY.json        |  1 +
 .../StateTaxData/2026/statetax-2026-OH.json        |  1 +
 .../StateTaxData/2026/statetax-2026-OK.json        |  1 +
 .../StateTaxData/2026/statetax-2026-OR.json        |  1 +
 .../StateTaxData/2026/statetax-2026-PA.json        |  1 +
 .../StateTaxData/2026/statetax-2026-RI.json        |  1 +
 .../StateTaxData/2026/statetax-2026-SC.json        |  1 +
 .../StateTaxData/2026/statetax-2026-SD.json        |  1 +
 .../StateTaxData/2026/statetax-2026-TN.json        |  1 +
 .../StateTaxData/2026/statetax-2026-TX.json        |  1 +
 .../StateTaxData/2026/statetax-2026-UT.json        |  1 +
 .../StateTaxData/2026/statetax-2026-VA.json        |  1 +
 .../StateTaxData/2026/statetax-2026-VT.json        |  1 +
 .../StateTaxData/2026/statetax-2026-WA.json        |  1 +
 .../StateTaxData/2026/statetax-2026-WI.json        |  1 +
 .../StateTaxData/2026/statetax-2026-WV.json        |  1 +
 .../StateTaxData/2026/statetax-2026-WY.json        |  1 +
 RetireSmartIRA/StateTaxCodable.swift               |  6 +-
 RetireSmartIRA/StateTaxData.swift                  | 30 +++++++
 RetireSmartIRA/TaxCalculationEngine.swift          | 45 ++++++++++-
 .../StateTaxCodableRoundTripTests.swift            | 10 ++-
 .../StateTaxPhase3aMechanismTests.swift            | 94 ++++++++++++++++++++++
 56 files changed, 228 insertions(+), 8 deletions(-)
```

---

## Every engine edit, before and after

### `RetireSmartIRA/StateTaxData.swift`

Before: nothing between `// MARK: - Retirement Income Exemptions` and
`struct RetirementIncomeExemptions {`; the struct's field order at
`exemptionAppliesPerIndividual` was immediately followed by
`regularExemptionMinAge`, then `distributionMinAge`.

After (added the enum above the struct, and the field between
`regularExemptionMinAge` and `distributionMinAge` -- see Deviation 1 above
for why the field sits after `regularExemptionMinAge` rather than after
`exemptionAppliesPerIndividual` as the brief's prose literally said):

```swift
/// How a state's retirement exemption is attributed between spouses on a
/// joint return.
enum ExemptionAttribution: String, Codable, Equatable, Sendable {
    /// Either spouse qualifying unlocks the exemption for all of the
    /// household's retirement income. This is what the engine did for every
    /// state before Phase 3a and it remains every state's value through
    /// Phase 3a.
    case household

    /// Each spouse's exemption is gated by that spouse's own age and applies
    /// only to income attributed to that spouse. Iowa's exclusion is written
    /// this way, as are at least seven other per-person statutes (OK, DE, LA,
    /// AR, AL, WI, RI).
    ///
    /// ATTRIBUTION RULES, and the one limitation they carry:
    ///   - A `.pension` or `.rmd` income row is gated by its `owner`'s age.
    ///   - A `.joint`-owned row is gated by the more generous of the two ages,
    ///     which is what `.joint` means elsewhere in this codebase.
    ///   - `scenarioRetirementDistributions` reaches the engine as a single
    ///     scalar with no owner, so it is gated on the PRIMARY's age. A state
    ///     adopting this case must carry a `knownLimitations` sentence saying
    ///     so, because a household whose spouse holds the IRA will be modeled
    ///     conservatively.
    case perQualifyingSpouse
}
```

and, inside `RetirementIncomeExemptions`, after `regularExemptionMinAge`:

```swift
    /// See `ExemptionAttribution`. `.household` reproduces the behavior every
    /// state had before Phase 3a.
    var exemptionAttribution: ExemptionAttribution = .household
```

### `RetireSmartIRA/StateTaxCodable.swift`

Before:

```swift
    private enum CodingKeys: String, CodingKey {
        case socialSecurityExempt, pensionExemption, iraWithdrawalExemption
        case exemptionAppliesPerIndividual, regularExemptionMinAge, distributionMinAge, earlyAgeTier
        case pensionAndIRAShareSingleCap, otherRetirementIncomeExclusion, agiPhaseout
        case capitalGainsTreatment
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(socialSecurityExempt, forKey: .socialSecurityExempt)
        try c.encode(pensionExemption, forKey: .pensionExemption)
        try c.encode(iraWithdrawalExemption, forKey: .iraWithdrawalExemption)
        try c.encode(exemptionAppliesPerIndividual, forKey: .exemptionAppliesPerIndividual)
        try c.encode(regularExemptionMinAge, forKey: .regularExemptionMinAge)
        try c.encode(distributionMinAge, forKey: .distributionMinAge)
        ...

    init(from decoder: Decoder) throws {
        ...
        self.init(
            ...
            exemptionAppliesPerIndividual: try c.decodeIfPresent(Bool.self, forKey: .exemptionAppliesPerIndividual) ?? false,
            regularExemptionMinAge: try c.decodeIfPresent(Int.self, forKey: .regularExemptionMinAge) ?? 0,
            distributionMinAge: try c.decodeIfPresent(Int.self, forKey: .distributionMinAge) ?? 59,
            ...
```

After:

```swift
    private enum CodingKeys: String, CodingKey {
        case socialSecurityExempt, pensionExemption, iraWithdrawalExemption
        case exemptionAppliesPerIndividual
        case regularExemptionMinAge, exemptionAttribution, distributionMinAge, earlyAgeTier
        case pensionAndIRAShareSingleCap, otherRetirementIncomeExclusion, agiPhaseout
        case capitalGainsTreatment
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(socialSecurityExempt, forKey: .socialSecurityExempt)
        try c.encode(pensionExemption, forKey: .pensionExemption)
        try c.encode(iraWithdrawalExemption, forKey: .iraWithdrawalExemption)
        try c.encode(exemptionAppliesPerIndividual, forKey: .exemptionAppliesPerIndividual)
        try c.encode(regularExemptionMinAge, forKey: .regularExemptionMinAge)
        try c.encode(exemptionAttribution, forKey: .exemptionAttribution)
        try c.encode(distributionMinAge, forKey: .distributionMinAge)
        ...

    init(from decoder: Decoder) throws {
        ...
        self.init(
            ...
            exemptionAppliesPerIndividual: try c.decodeIfPresent(Bool.self, forKey: .exemptionAppliesPerIndividual) ?? false,
            regularExemptionMinAge: try c.decodeIfPresent(Int.self, forKey: .regularExemptionMinAge) ?? 0,
            exemptionAttribution: try c.decodeIfPresent(
                ExemptionAttribution.self, forKey: .exemptionAttribution) ?? .household,
            distributionMinAge: try c.decodeIfPresent(Int.self, forKey: .distributionMinAge) ?? 59,
            ...
```

### `RetireSmartIRA/TaxCalculationEngine.swift` (`applyRetirementExemptions`)

Before:

```swift
        let effectivePensionExemption = resolveLevel(regular: exemptions.pensionExemption)
        let effectiveIRAExemption = resolveLevel(regular: exemptions.iraWithdrawalExemption)

        let pensionIncome = incomeSources.filter { $0.type == .pension }.reduce(0) { $0 + $1.annualAmount }

        // Sum of state-recognized IRA-withdrawal income:
        //   1) `.rmd`-typed IncomeSource rows (demo profile / explicit entries), plus
        //   2) `scenarioRetirementDistributions` — RMDs computed from IRA balances,
        //      inherited-IRA RMDs, and extra withdrawals. These don't appear as
        //      IncomeSource rows but flow into scenarioGrossIncome via
        //      scenarioTotalWithdrawals. Age-gate the scenario portion at 59½
        //      (early-withdrawal IRA distributions are taxable in PA and most
        //      states); user-entered `.rmd` rows are not gated because they
        //      implicitly represent retirement-age income.
        let rmdSourceIncome = incomeSources.filter { $0.type == .rmd }.reduce(0) { $0 + $1.annualAmount }
        let retirementAge = primaryAge >= exemptions.distributionMinAge
            || (enableSpouse && spouseAge >= exemptions.distributionMinAge)
        let scenarioExemptable = retirementAge ? scenarioRetirementDistributions : 0
        let iraIncome = rmdSourceIncome + scenarioExemptable
```

After:

```swift
        let effectivePensionExemption = resolveLevel(regular: exemptions.pensionExemption)
        let effectiveIRAExemption = resolveLevel(regular: exemptions.iraWithdrawalExemption)

        /// Whether income owned by `owner` is eligible under the state's
        /// attribution rule. Under `.household` every row is eligible when any
        /// spouse qualifies, which is what `effectiveAge` already encodes.
        func ownerQualifies(_ owner: Owner) -> Bool {
            guard exemptions.exemptionAttribution == .perQualifyingSpouse, enableSpouse else {
                return true
            }
            switch owner {
            case .primary: return ageQualifiesForExemption(primaryAge)
            case .spouse:  return ageQualifiesForExemption(spouseAge)
            case .joint:   return ageQualifiesForExemption(primaryAge)
                                || ageQualifiesForExemption(spouseAge)
            }
        }

        let pensionIncome = incomeSources
            .filter { $0.type == .pension && ownerQualifies($0.owner) }
            .reduce(0) { $0 + $1.annualAmount }

        // Sum of state-recognized IRA-withdrawal income:
        //   1) `.rmd`-typed IncomeSource rows (demo profile / explicit entries), plus
        //   2) `scenarioRetirementDistributions` — RMDs computed from IRA balances,
        //      inherited-IRA RMDs, and extra withdrawals. These don't appear as
        //      IncomeSource rows but flow into scenarioGrossIncome via
        //      scenarioTotalWithdrawals. Age-gate the scenario portion at 59½
        //      (early-withdrawal IRA distributions are taxable in PA and most
        //      states); user-entered `.rmd` rows are not gated because they
        //      implicitly represent retirement-age income.
        let rmdSourceIncome = incomeSources
            .filter { $0.type == .rmd && ownerQualifies($0.owner) }
            .reduce(0) { $0 + $1.annualAmount }
        // Under `.perQualifyingSpouse` the scalar has no owner to attribute it
        // to, so it is gated on the primary. See ExemptionAttribution.
        let retirementAge: Bool
        switch exemptions.exemptionAttribution {
        case .household:
            retirementAge = primaryAge >= exemptions.distributionMinAge
                || (enableSpouse && spouseAge >= exemptions.distributionMinAge)
        case .perQualifyingSpouse:
            // Not just distributionMinAge: `ageQualifiesForExemption` also
            // honors `regularExemptionMinAge`/`earlyAgeTier` when set, which
            // is what actually determines effectiveIRAExemption's level
            // below. Using the plain distributionMinAge comparison here would
            // let a primary who fails the state's real age gate still draw
            // the household-level exemption on the scalar, because that
            // level is computed from `effectiveAge` (household max), not the
            // primary alone. When regularExemptionMinAge is 0 (every state
            // today), this reduces to the identical
            // `primaryAge >= exemptions.distributionMinAge` comparison.
            retirementAge = ageQualifiesForExemption(primaryAge)
        }
        let scenarioExemptable = retirementAge ? scenarioRetirementDistributions : 0
        let iraIncome = rmdSourceIncome + scenarioExemptable
```

`.rmd` rows remain ungated by age (only owner-filtered under
`.perQualifyingSpouse`); the household-vs-scalar divergence pinned by the
baseline scenario "single 55 rmd rows not scenario distributions" is
unchanged, per point 9 of the task context.

### `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`

Added the full `// MARK: - attribution` block from the brief's Step 1
verbatim, with one syntax fix (the triple-quote conversion described in the
RED transcript above; text content unchanged).

### `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`

- `retirementExemptionsRoundTrip`: added `exemptionAttribution: .perQualifyingSpouse,`
  to the fixture (placed in declaration order, after `regularExemptionMinAge`)
  and `#expect(decoded.exemptionAttribution == original.exemptionAttribution)`.
  Corrected the cross-reference comment from "bug across all nine fields" to
  "bug across all twelve fields" (point 7 of the task context).
- `retirementExemptionsEncodesExpectedJSONShape`: same fixture addition, plus
  `#expect(json["exemptionAttribution"] as? String == "perQualifyingSpouse")`.
  Retitled from "all eleven fields" to "all twelve fields" and updated the
  doc comment's "eleven keys" to "twelve keys".

---

## Concerns for the reviewer

1. Two deviations from the brief's literal code, both forced by compiling
   or correctly passing the brief's own verbatim test code (documented in
   full above with before/after and evidence). No behavior for any real
   jurisdiction changes: every state stays `.household`, and the household
   branch of every changed function is byte-identical in inputs/outputs to
   the pre-Task-5 code (confirmed by the unchanged 51x20 baseline).
2. One syntax fix to the brief's verbatim test code (backslash line
   continuation inside a non-triple-quoted string literal is not valid
   Swift) -- text content preserved exactly, only the quoting style changed
   to match the existing pattern in the same file.

## Review fixes

Fixed 7 mutation-survivor findings from the reviewer's pass on Task 5
(commit 5fe180e), plus one drifted mirror traced to a miss in Task 2.
Commit: `943abda`.

### Fix 1 -- `.perQualifyingSpouse` scalar gate now uses the conjunction

`RetireSmartIRA/TaxCalculationEngine.swift`, the `retirementAge` switch.
Replaced `retirementAge = ageQualifiesForExemption(primaryAge)` with
`retirementAge = primaryAge >= exemptions.distributionMinAge &&
ageQualifiesForExemption(primaryAge)`. The prior form was tighter than the
plan for NJ 59-61 but looser for CO/GA (both ship `earlyAgeTier: 55...64`
with `distributionMinAge: 59`, admitting a 57-year-old past the 59.5 floor).
The conjunction closes both gaps and reduces to the plain comparison when
`regularExemptionMinAge` is 0. Corrected the adjacent comment's false claim
that `regularExemptionMinAge` is 0 "for every state today" (NY 59, NJ 62,
CO 65, GA 65 all ship nonzero) -- the real safety argument is that no state
ships `.perQualifyingSpouse` yet, so the gap was latent, not live.

### Fix 2 -- three new tests closing the untested `ownerQualifies` branches

Added to `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`, MARK:
attribution section, using the existing `attributionConfig` / `mfjTax`
helpers verbatim:

- `perQualifyingSpouseAttributionGatesRMDRowsByOwner` -- the `.rmd` half of
  the owner filter had no coverage (every other attribution test uses
  `.pension`).
- `perQualifyingSpouseAttributionTaxesANonQualifyingPrimary` -- the
  `.primary` branch of `ownerQualifies` was only ever asserted in the
  exempt direction.
- `perQualifyingSpouseAttributionTaxesAJointRowWhenNeitherQualifies` -- the
  `.joint` branch was only pinned in its OR shape and its exempt direction.

All expected values matched the engine's actual computation on first run;
no expectation was adjusted.

### Fix 3 -- shipped-data assertion now reads raw JSON keys

Replaced `noStateUsesPerSpouseAttributionYet` (decoded-value assertion,
indistinguishable from the `?? .household` decode fallback) with
`everyStateShipsHouseholdAttribution`, which reads
`object?["retirementExemptions"]?["exemptionAttribution"]` via
`JSONSerialization` against the raw file bytes, matching the pattern
already used by `noStateShipsAnAGIPhaseoutKey`.

### Fix 4 -- `DataManager`'s mirror block resynced

`RetireSmartIRA/DataManager.swift`, `stateTaxBreakdown`, lines ~741-800:

(a) Task 2 replaced the engine's hardcoded retirement age with
`exemptions.distributionMinAge` but missed this mirror. Both hardcoded
`59`s (the `retirementAge` boolean and the local `ageQualifiesForExemption`
fallback) now read `exemptions.distributionMinAge`. Kept the `||` shape on
the `retirementAge` line unchanged (`.household` behavior).

(b) Task 5 added owner filtering to the engine's `pensionIncome` and
`rmdSourceIncome` computations; this mirror had none. Added a local
`ownerQualifies` matching the engine's exactly (including the `.joint`
case and the `guard ... else { return true }` short-circuit), and applied
it to both filters. Restructured the block so `effectiveAge` / `minAge` /
`ageQualifiesForExemption` are computed before the income filters that now
depend on them (previously computed after); the two later "MUST mirror"
comment blocks were renumbered 1/2/3 accordingly. No encoded field or
behavior changes for any state -- confirmed by the empty regeneration diff
(step 5 below) and the unchanged 1020-value baseline.

### Fix 5 -- `ExemptionAttribution.perQualifyingSpouse` doc comment, second limitation

`RetireSmartIRA/StateTaxData.swift`. Added the "SECOND LIMITATION" note:
attribution gates which income is eligible, but the exemption LEVEL still
comes from `resolveLevel(effectiveAge)` (household max), so a spouse who
qualifies only for an `earlyAgeTier` can still draw the household's regular
level if the other spouse clears the regular age.

### Mutation proofs (procedure step 2)

All five run in the foreground, each restored and confirmed with `git diff`
before moving to the next.

**(a) Delete `&& ownerQualifies($0.owner)` from the engine's
`rmdSourceIncome` filter.** DISCRIMINATED.

```
◇ Test "Per-qualifying-spouse attribution gates .rmd rows by owner, not only pensions" started.
✘ Test "Per-qualifying-spouse attribution gates .rmd rows by owner, not only pensions" recorded an issue at StateTaxPhase3aMechanismTests.swift:434:9: Expectation failed: (Self.mfjTax(config: config, primaryAge: 70, spouseAge: 60,
✘ Test "Per-qualifying-spouse attribution gates .rmd rows by owner, not only pensions" failed after 0.001 seconds with 1 issue.
✘ Suite "Phase 3a mechanisms are load-bearing" failed after 0.017 seconds with 1 issue.
✘ Test run with 25 tests in 1 suite failed after 0.018 seconds with 1 issue.
** TEST FAILED **
```

Restored (`filter { $0.type == .rmd && ownerQualifies($0.owner) }`);
`git diff` on the mutated line showed no residual change afterward.

**(b) Force `case .primary: return true` in `ownerQualifies`.**
DISCRIMINATED.

```
◇ Test "Per-qualifying-spouse attribution taxes a primary-owned row when the primary does not qualify" started.
✘ Test "Per-qualifying-spouse attribution taxes a primary-owned row when the primary does not qualify" recorded an issue at StateTaxPhase3aMechanismTests.swift:451:9: Expectation failed: (Self.mfjTax(config: config, primaryAge: 60, spouseAge: 70,
✘ Test "Per-qualifying-spouse attribution taxes a primary-owned row when the primary does not qualify" failed after 0.001 seconds with 1 issue.
✘ Suite "Phase 3a mechanisms are load-bearing" failed after 0.018 seconds with 1 issue.
✘ Test run with 25 tests in 1 suite failed after 0.021 seconds with 1 issue.
** TEST FAILED **
```

Restored (`case .primary: return ageQualifiesForExemption(primaryAge)`);
`git diff` on that line showed no residual change afterward.

**(c) Force `case .joint: return true`.** DID NOT DISCRIMINATE -- plain
finding, test left as specified.

```
◇ Test "Per-qualifying-spouse attribution taxes a joint row when neither spouse qualifies" started.
✔ Test "Per-qualifying-spouse attribution taxes a joint row when neither spouse qualifies" passed after 0.001 seconds.
✔ Suite "Phase 3a mechanisms are load-bearing" passed after 0.015 seconds.
✔ Test run with 25 tests in 1 suite passed after 0.015 seconds.
** TEST SUCCEEDED **
```

Trace through `applyRetirementExemptions` for
`attributionConfig(.perQualifyingSpouse)` (`regularExemptionMinAge: 65`, no
`earlyAgeTier`) with the `.joint` pension row:

- `effectiveAge = max(primaryAge, spouseAge)`; `resolveLevel(regular:)`
  returns `regular` (`.full`) iff `effectiveAge >= 65`, else `.none` (no
  tier to fall back to). The exemption LEVEL applied to `pensionIncome`
  therefore depends only on `max(primaryAge, spouseAge) >= 65`.
- `ownerQualifies(.joint)` (real formula) =
  `ageQualifiesForExemption(primaryAge) || ageQualifiesForExemption(spouseAge)`,
  which -- with no `earlyAgeTier` -- is `primaryAge >= 65 || spouseAge >= 65`,
  i.e. exactly `max(primaryAge, spouseAge) >= 65`.
- These two conditions are the same boolean. For age pair (60, 62):
  `effectiveAge = 62 < 65` → level is `.none` → 40,000 taxed regardless of
  `ownerQualifies`, so the mutated always-`true` branch produces the same
  4,000 tax as the real formula. For (60, 66): `effectiveAge = 66 >= 65` →
  level is `.full`, and the real `ownerQualifies(.joint)` is *also* `true`
  (spouse 66 qualifies), so both real and mutated code agree on 0. No age
  pair under this no-tier config can separate the two, because
  `ownerQualifies(.joint)`'s OR-of-thresholds is mathematically identical
  to `resolveLevel`'s max-age threshold check whenever there is no
  `earlyAgeTier`.
- This is exactly the "second limitation" documented in Fix 5: attribution
  gates which income counts, but the LEVEL still comes from
  `resolveLevel(effectiveAge)` (the household max), so for a `.joint`-owned
  row under a no-tier config the two gates collapse into one and a
  `.joint`-only mutation is invisible to any test built on this config. A
  test that could catch it would need a state with a nonzero
  `regularExemptionMinAge` *and* an `earlyAgeTier`, engineered so one
  spouse clears the tier but not the regular age while the other clears
  neither -- a materially different config than `attributionConfig`
  supplies today. Left the test as specified rather than adjusting it to
  chase this mutation, per instruction.

**(d) Delete `"exemptionAttribution"` from Kansas's shipped JSON.**
DISCRIMINATED, names KS.

```
◇ Test "Every jurisdiction ships exemptionAttribution as household in Phase 3a" started.
✘ Test "Every jurisdiction ships exemptionAttribution as household in Phase 3a" recorded an issue at StateTaxPhase3aMechanismTests.swift:484:9: Expectation failed: (wrong → ["KS"]).isEmpty → false
✘ Test "Every jurisdiction ships exemptionAttribution as household in Phase 3a" failed after 0.002 seconds with 1 issue.
✘ Suite "Phase 3a mechanisms are load-bearing" failed after 0.018 seconds with 1 issue.
✘ Test run with 25 tests in 1 suite failed after 0.018 seconds with 1 issue.
** TEST FAILED **
```

Restored with `git checkout -- RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json`;
`git diff --stat` on that file showed nothing afterward.

**(e) Revert `DataManager`'s `retirementAge` line to hardcoded 59 AND set
KS's `distributionMinAge` to 55.** DID NOT DISCRIMINATE -- plain finding
about the mirror's guard, not a reason to skip Fix 4.

```
◇ Test "Breakdown totalStateTax matches calculateStateTaxFromGross for all states" started.
✔ Test "Breakdown totalStateTax matches calculateStateTaxFromGross for all states" passed after 0.006 seconds.
✔ Suite "State Tax — Breakdown Detail" passed after 0.013 seconds.
✔ Test run with 5 tests in 1 suite passed after 0.013 seconds.
** TEST SUCCEEDED **
```

`StateTaxBreakdownTests.breakdownMatchesCalculation` builds its `DataManager`
via the file's `makeDM` helper with `birthYear: 1955` and `currentYear:
2026` (default, `enableSpouse: false`) -- `currentAge` = 71, which exceeds
both 55 and 59, so the `retirementAge` boolean is identical under either
threshold. The test also supplies no `iraAccounts` / scenario-projected
withdrawals, only a manual `.rmd` `IncomeSource` row, so
`scenarioRetirementDistributionIncome` (the value `retirementAge` actually
gates) is 0 regardless -- the boolean has no observable path to the
computed tax in this test at all. The suite's other four tests don't touch
KS or this age boundary either. Nothing in `StateTaxBreakdownTests` would
catch this specific divergence; it would only surface if a future test
used an age between the hardcoded 59 and a state's lowered
`distributionMinAge` together with a nonzero
`scenarioRetirementDistributionIncome`. Restored both the `DataManager`
line and KS's JSON; `git diff` on `DataManager.swift` after restoring
showed only the intended Fix 4 changes, and `git diff --stat` on the KS
file showed nothing.

### Baseline and breakdown suite (procedure steps 3-4)

`StateTaxBehaviorBaselineTests`: `Test "Every jurisdiction and scenario
matches the frozen pre-Phase-3a baseline" with 51 test cases passed` --
1020 values unmoved, `Baselines/statetax-behavior-baseline-2026.json`
untouched.

`StateTaxBreakdownTests`: `Test run with 5 tests in 1 suite passed`.

`StateTaxPhase3aMechanismTests` (full class, post-fix): `Test run with 25
tests in 1 suite passed`.

### Regeneration diff (procedure step 5)

```
TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests ENABLE_APP_SANDBOX=NO
...
✔ Test "Generate all 51 jurisdiction files" passed after 0.005 seconds.
** TEST SUCCEEDED **
```

```
$ git status --short RetireSmartIRA/Resources/StateTaxData/2026/
(no output)
```

Empty, as expected -- Fix 4 changes no encoded field.

### Full suite (procedure step 6)

Ran in the foreground (`xcodebuild test -scheme RetireSmartIRA -destination
'platform=macOS' ENABLE_APP_SANDBOX=NO`), 297s Swift Testing + 21s XCTest.
Tree-confirmation grep against the log:
`worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj` (present, confirms
the run was against this worktree).

Both summary lines:

```
✔ Test run with 1649 tests in 278 suites passed after 297.140 seconds.
```
```
Test Suite 'All tests' passed at 2026-08-03 09:23:17.598.
	 Executed 503 tests, with 0 failures (0 unexpected) in 20.908 (21.226) seconds
```

### Commit (procedure step 7)

`943abda` -- `fix(state-tax): close the untested attribution branches and
resync the DataManager mirror`. Staged explicit paths: `TaxCalculationEngine.swift`,
`StateTaxData.swift`, `DataManager.swift`, `StateTaxPhase3aMechanismTests.swift`.

---

## Discrimination fixes

Closes both mutations that survived in the report above (mutation (c),
`.joint: return true` on `ownerQualifies`, and mutation (e), `DataManager`'s
hardcoded-59 `retirementAge` line combined with a lowered
`distributionMinAge`). Both were plain findings against tests that could not
see the code path they were named for; this pass rebuilds each test's
scenario so the path is observable, without touching any state's real
config permanently.

### Gap 1 fix

`RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`. Added
`ownerGatedOnlyConfig` next to `attributionConfig` (`distributionMinAge:
65`, `regularExemptionMinAge` left at its default 0, so `resolveLevel`
returns the regular `.full` level unconditionally and `ownerQualifies` is
the only age gate left standing). Rewrote
`perQualifyingSpouseAttributionTaxesAJointRowWhenNeitherQualifies` to use it
and added a third assertion (primary 66 / spouse 60) pinning the OR shape
from the other side. Expectations were derived independently from the
config (flat 10%, `.full` exemption, $40,000 pension row) rather than
copied: excluded when `ownerQualifies` admits the row, taxed at $4,000
when it does not. Confirmed against `ExemptionLevel.excludedAmount`
(`.full` returns `eligibleIncome` unconditionally, `StateTaxData.swift`
line 352) — arithmetic matched on the first run, nothing was adjusted.

### Gap 2 fix

`RetireSmartIRATests/RetireSmartIRATests.swift`. Added
`breakdownMatchesCalculationBelowTheDistributionAgeGate` beside
`breakdownMatchesCalculation`. Built via `makeDM(birthYear: 2026 - 56,
state: .california)` (age 56, below the default/shipped `distributionMinAge`
of 59, and below every custom `regularExemptionMinAge` any state ships) with
`dm.yourExtraWithdrawal = 40_000` — a scenario-projected distribution, not
an `.rmd` row, so `scenarioRetirementDistributionIncome` (`DataManager.swift`
line 561, `== scenarioTotalWithdrawals`) is nonzero and the `retirementAge`
gate at line 789 actually has something to gate. Sweeps `USState.allCases`
comparing `bd.totalStateTax` (`stateTaxBreakdown`) against
`calculateStateTaxFromGross`, this time passing the real
`scenarioRetirementDistributions: scenarioDistributions` explicitly (the
existing case never does — it defaults to 0, which is why it can't see this
either). Passed on first run.

### Mutation (a) — force `case .joint: return true` in the engine's `ownerQualifies`

DISCRIMINATED. `RetireSmartIRA/TaxCalculationEngine.swift`,
`ownerQualifies`, changed:

```swift
case .joint:   return ageQualifiesForExemption(primaryAge)
                    || ageQualifiesForExemption(spouseAge)
```
to
```swift
case .joint:   return true
```

Ran `-only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests`:

```
◇ Test "Per-qualifying-spouse attribution taxes a joint row when neither spouse qualifies" started.
✘ Test "Per-qualifying-spouse attribution taxes a joint row when neither spouse qualifies" recorded an issue at StateTaxPhase3aMechanismTests.swift:481:9: Expectation failed: (Self.mfjTax(config: config, primaryAge: 60, spouseAge: 62,
                            sources: jointPension) → 0.0) == (4_000 → 4000.0)
↳ // Neither spouse clears the 65 gate, so the joint row is taxed.
✘ Test "Per-qualifying-spouse attribution taxes a joint row when neither spouse qualifies" failed after 0.001 seconds with 1 issue.
✘ Suite "Phase 3a mechanisms are load-bearing" failed after 0.023 seconds with 1 issue.
✘ Test run with 25 tests in 1 suite failed after 0.023 seconds with 1 issue.
Failing tests:
	StateTaxPhase3aMechanismTests.perQualifyingSpouseAttributionTaxesAJointRowWhenNeitherQualifies()
** TEST FAILED **
```

This is the mutation that previously survived; the rewritten test now
catches it. Restored `ownerQualifies` to the OR form; `git diff --stat
RetireSmartIRA/TaxCalculationEngine.swift` produced no output.

### Mutation (b) — revert `DataManager`'s `retirementAge` to hardcoded 59 + lower one state's `distributionMinAge`

DISCRIMINATED. Two temporary edits:

`RetireSmartIRA/DataManager.swift`, `stateTaxBreakdown`:
```swift
let retirementAge = currentAge >= 59
    || (enableSpouse && spouseCurrentAge >= 59)
```

`RetireSmartIRA/StateTaxData.swift`, Kentucky's `retirementExemptions`
(chosen because it ships `iraWithdrawalExemption: .partial(maxExempt:
31_110)` — a state whose exemption is `.none` can't show the divergence,
since 0 exemption stays 0 regardless of the gate):
```swift
iraWithdrawalExemption: .partial(maxExempt: 31_110),  // combined
distributionMinAge: 55,  // TEMP mutation for discrimination proof, must be reverted
```

Regenerated JSON (`TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test
-only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests
ENABLE_APP_SANDBOX=NO`) so `StateTaxData.config(for:)` (which reads the
bundled JSON, not the Swift table) saw the change. Confirmed exactly one
file changed, exactly the field mutated:

```
$ git status --porcelain RetireSmartIRA/Resources/StateTaxData/
 M RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KY.json
$ git diff RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KY.json
-    "distributionMinAge" : 59,
+    "distributionMinAge" : 55,
```

Ran `-only-testing:RetireSmartIRATests/StateTaxBreakdownTests`:

```
◇ Test "Breakdown totalStateTax matches calculateStateTaxFromGross below the distribution age gate" started.
✘ Test "Breakdown totalStateTax matches calculateStateTaxFromGross below the distribution age gate" recorded an issue at RetireSmartIRATests.swift:1518:13: Expectation failed: isClose((bd.totalStateTax → 1282.4), (calcTax → 193.55))
↳ Breakdown mismatch for Kentucky: breakdown=1282.4 vs calc=193.55
✘ Test "Breakdown totalStateTax matches calculateStateTaxFromGross below the distribution age gate" failed after 0.004 seconds with 1 issue.
✘ Suite "State Tax — Breakdown Detail" failed after 0.016 seconds with 1 issue.
✘ Test run with 6 tests in 1 suite failed after 0.016 seconds with 1 issue.
Failing tests:
	StateTaxBreakdownTests.breakdownMatchesCalculationBelowTheDistributionAgeGate()
** TEST FAILED **
```

At age 56, Kentucky (real config, `distributionMinAge: 55`): the
`TaxCalculationEngine` path (`calculateStateTaxFromGross` → `calculateStateTax`,
called with the explicit nonzero `scenarioRetirementDistributions`) computes
`retirementAge = 56 >= 55 = true`, grants the $31,110 partial IRA exclusion.
The `DataManager` mirror (`bd`, hardcoded-59 mutant): `retirementAge = 56 >=
59 = false`, grants nothing. The two diverge and the test fails, naming
Kentucky exactly — the mutation this test exists to catch.

**Restore.** Reverted both:

```swift
// DataManager.swift
let retirementAge = currentAge >= exemptions.distributionMinAge
    || (enableSpouse && spouseCurrentAge >= exemptions.distributionMinAge)
```
```swift
// StateTaxData.swift, Kentucky — distributionMinAge line removed, back to default
iraWithdrawalExemption: .partial(maxExempt: 31_110),  // combined
capitalGainsTreatment: .followsFederal
```

```
$ git diff --stat RetireSmartIRA/DataManager.swift RetireSmartIRA/StateTaxData.swift
(no output)
```

Regenerated JSON again to restore Kentucky's file:

```
TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests ENABLE_APP_SANDBOX=NO
...
✔ Test "Generate all 51 jurisdiction files" passed after 0.005 seconds.
** TEST SUCCEEDED **
```

```
$ git status --porcelain
 M RetireSmartIRATests/RetireSmartIRATests.swift
 M RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift
```

No JSON file left modified — confirmed by the absence of any
`RetireSmartIRA/Resources/StateTaxData/` entry in `git status --porcelain`
after the second regeneration.

### Baseline gate (procedure step 3)

`-only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests`:

```
✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.048 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.048 seconds.
✔ Test run with 1 test in 1 suite passed after 0.049 seconds.
```

1020 frozen values (51 jurisdictions × 20 scenarios) unmoved.

### Full suite (procedure step 4)

Ran in the foreground: `xcodebuild test -scheme RetireSmartIRA -destination
'platform=macOS'` (no `-only-testing`, no sandbox override — default full
run), 332s wall time.

Swift Testing summary line:
```
✔ Test run with 1650 tests in 278 suites passed after 297.646 seconds.
```

XCTest summary line:
```
Test Suite 'All tests' passed at 2026-08-03 09:41:02.596.
	 Executed 503 tests, with 0 failures (0 unexpected) in 20.559 (20.749) seconds
```

No `✘`, no "TEST FAILED", no nonzero failure count anywhere in the full log
(`grep -n "TEST FAILED\|✘\|failed after" full-suite-run.log | grep -v "0
failures"` returned nothing). `** TEST SUCCEEDED **` at the end.

### Final tree state and commit (procedure step 5)

```
$ git status --porcelain
 M RetireSmartIRATests/RetireSmartIRATests.swift
 M RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift
```

Only the two intended test files. `RetireSmartIRA.xcodeproj/project.pbxproj`,
`ProjectionEngine.swift`, `StateTaxBehaviorBaselineTests.swift`, and
`Baselines/statetax-behavior-baseline-2026.json` were never touched.
Committed both paths explicitly (no `git add -A`) as
`test(state-tax): make the joint-owner and breakdown-mirror guards actually discriminate`.
