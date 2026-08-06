# Task 1 report: domain model and inference

Branch `feature/state-tax-phase3b`, worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b`.
Base HEAD: `42ce722`. Commit produced by this task: `4d829ef`.

## Files

- `RetireSmartIRA/RetirementPlanClassification.swift` (new): `PlanStructure`, `PlanSource`, `RetirementPlanClassification` with `.infer(incomeType:)` / `.infer(accountType:)`.
- `RetireSmartIRA/PerSourceExemptionRule.swift` (new): `PerSourceExemptionRule` with `matches(structure:source:) -> Bool`.
- `RetireSmartIRATests/Phase3bClassificationTests.swift` (new): 18 tests.
- `RetireSmartIRA/StateTaxCodable.swift`: **not modified.** See "Step 3a" below for why.

## Step 1 -> Step 2: RED transcript

Command:

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/Phase3bClassificationTests
```

Confirmed the `cd` line in the build log itself resolves under `.worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj` before trusting the result.

Compiler errors, pasted verbatim (path prefix trimmed to the filename for width; line:col:kind is untouched):

```
481:Phase3bClassificationTests.swift:69:31: error: cannot find 'PerSourceExemptionRule' in scope
484:Phase3bClassificationTests.swift:70:25: error: reference to member 'nyStateOrLocal' cannot be resolved without a contextual type
487:Phase3bClassificationTests.swift:70:42: error: reference to member 'federalCivilian' cannot be resolved without a contextual type
490:Phase3bClassificationTests.swift:71:28: error: reference to member 'definedBenefit' cannot be resolved without a contextual type
493:Phase3bClassificationTests.swift:72:21: error: cannot infer contextual base in reference to member 'full'
496:Phase3bClassificationTests.swift:17:22: error: cannot find 'RetirementPlanClassification' in scope
499:Phase3bClassificationTests.swift:17:70: error: cannot infer contextual base in reference to member 'rmd'
502:Phase3bClassificationTests.swift:18:27: error: cannot find 'RetirementPlanClassification' in scope
505:Phase3bClassificationTests.swift:18:68: error: cannot infer contextual base in reference to member 'ira'
508:Phase3bClassificationTests.swift:18:82: error: cannot infer contextual base in reference to member 'individual'
511:Phase3bClassificationTests.swift:23:22: error: cannot find 'RetirementPlanClassification' in scope
514:Phase3bClassificationTests.swift:23:70: error: cannot infer contextual base in reference to member 'pension'
517:Phase3bClassificationTests.swift:24:27: error: cannot find 'RetirementPlanClassification' in scope
520:Phase3bClassificationTests.swift:24:68: error: cannot infer contextual base in reference to member 'unknown'
523:Phase3bClassificationTests.swift:24:86: error: cannot infer contextual base in reference to member 'unknown'
526:Phase3bClassificationTests.swift:31:26: error: cannot find 'RetirementPlanClassification' in scope
529:Phase3bClassificationTests.swift:33:27: error: cannot find 'RetirementPlanClassification' in scope
532:Phase3bClassificationTests.swift:33:68: error: cannot infer contextual base in reference to member 'unknown'
535:Phase3bClassificationTests.swift:33:86: error: cannot infer contextual base in reference to member 'unknown'
538:Phase3bClassificationTests.swift:43:22: error: cannot find 'RetirementPlanClassification' in scope
541:Phase3bClassificationTests.swift:43:71: error: cannot infer contextual base in reference to member 'traditionalIRA'
544:Phase3bClassificationTests.swift:44:27: error: cannot find 'RetirementPlanClassification' in scope
547:Phase3bClassificationTests.swift:44:68: error: cannot infer contextual base in reference to member 'ira'
550:Phase3bClassificationTests.swift:44:82: error: cannot infer contextual base in reference to member 'individual'
553:Phase3bClassificationTests.swift:49:22: error: cannot find 'RetirementPlanClassification' in scope
556:Phase3bClassificationTests.swift:49:71: error: cannot infer contextual base in reference to member 'traditional401k'
559:Phase3bClassificationTests.swift:50:27: error: cannot find 'RetirementPlanClassification' in scope
562:Phase3bClassificationTests.swift:50:68: error: cannot infer contextual base in reference to member 'definedContribution'
565:Phase3bClassificationTests.swift:50:98: error: cannot infer contextual base in reference to member 'privateEmployer'
568:Phase3bClassificationTests.swift:57:26: error: cannot find 'RetirementPlanClassification' in scope
571:Phase3bClassificationTests.swift:59:27: error: cannot find 'RetirementPlanClassification' in scope
574:Phase3bClassificationTests.swift:59:68: error: cannot infer contextual base in reference to member 'unknown'
577:Phase3bClassificationTests.swift:59:86: error: cannot infer contextual base in reference to member 'unknown'
580:Phase3bClassificationTests.swift:77:55: error: cannot infer contextual base in reference to member 'definedBenefit'
583:Phase3bClassificationTests.swift:77:80: error: cannot infer contextual base in reference to member 'nyStateOrLocal'
586:Phase3bClassificationTests.swift:82:55: error: cannot infer contextual base in reference to member 'definedBenefit'
589:Phase3bClassificationTests.swift:82:80: error: cannot infer contextual base in reference to member 'federalCivilian'
592:Phase3bClassificationTests.swift:90:56: error: cannot infer contextual base in reference to member 'definedBenefit'
595:Phase3bClassificationTests.swift:90:81: error: cannot infer contextual base in reference to member 'otherStateOrLocal'
598:Phase3bClassificationTests.swift:98:56: error: cannot infer contextual base in reference to member 'definedContribution'
601:Phase3bClassificationTests.swift:98:86: error: cannot infer contextual base in reference to member 'nyStateOrLocal'
604:Phase3bClassificationTests.swift:106:56: error: cannot infer contextual base in reference to member 'definedBenefit'
607:Phase3bClassificationTests.swift:106:81: error: cannot infer contextual base in reference to member 'governmentUnspecified'
610:Phase3bClassificationTests.swift:111:39: error: cannot find 'PerSourceExemptionRule' in scope
613:Phase3bClassificationTests.swift:113:32: error: reference to member 'definedBenefit' cannot be resolved without a contextual type
616:Phase3bClassificationTests.swift:114:25: error: cannot infer contextual base in reference to member 'full'
619:Phase3bClassificationTests.swift:116:61: error: cannot infer contextual base in reference to member 'definedBenefit'
622:Phase3bClassificationTests.swift:116:86: error: cannot infer contextual base in reference to member 'nyStateOrLocal'
625:Phase3bClassificationTests.swift:117:61: error: cannot infer contextual base in reference to member 'definedBenefit'
628:Phase3bClassificationTests.swift:117:86: error: cannot infer contextual base in reference to member 'otherStateOrLocal'
631:Phase3bClassificationTests.swift:118:61: error: cannot infer contextual base in reference to member 'definedBenefit'
634:Phase3bClassificationTests.swift:118:86: error: cannot infer contextual base in reference to member 'governmentUnspecified'
637:Phase3bClassificationTests.swift:119:62: error: cannot infer contextual base in reference to member 'definedContribution'
640:Phase3bClassificationTests.swift:119:92: error: cannot infer contextual base in reference to member 'nyStateOrLocal'
643:Phase3bClassificationTests.swift:124:36: error: cannot find 'PerSourceExemptionRule' in scope
646:Phase3bClassificationTests.swift:125:29: error: reference to member 'nyStateOrLocal' cannot be resolved without a contextual type
649:Phase3bClassificationTests.swift:127:25: error: cannot infer contextual base in reference to member 'full'
652:Phase3bClassificationTests.swift:129:58: error: cannot infer contextual base in reference to member 'definedBenefit'
655:Phase3bClassificationTests.swift:129:83: error: cannot infer contextual base in reference to member 'nyStateOrLocal'
658:Phase3bClassificationTests.swift:130:58: error: cannot infer contextual base in reference to member 'definedContribution'
661:Phase3bClassificationTests.swift:130:88: error: cannot infer contextual base in reference to member 'nyStateOrLocal'
664:Phase3bClassificationTests.swift:131:58: error: cannot infer contextual base in reference to member 'ira'
667:Phase3bClassificationTests.swift:131:72: error: cannot infer contextual base in reference to member 'nyStateOrLocal'
670:Phase3bClassificationTests.swift:132:59: error: cannot infer contextual base in reference to member 'definedBenefit'
673:Phase3bClassificationTests.swift:132:84: error: cannot infer contextual base in reference to member 'federalCivilian'
676:Phase3bClassificationTests.swift:141:42: error: cannot find 'PlanStructure' in scope
679:Phase3bClassificationTests.swift:140:9: error: failed to produce diagnostic for expression; please submit a bug report (https://swift.org/contributing/#reporting-bugs)
682:Phase3bClassificationTests.swift:149:42: error: cannot find 'PlanStructure' in scope
685:Phase3bClassificationTests.swift:149:15: error: failed to produce diagnostic for expression; please submit a bug report (https://swift.org/contributing/#reporting-bugs)
688:Phase3bClassificationTests.swift:164:42: error: cannot find 'PlanSource' in scope
691:Phase3bClassificationTests.swift:163:9: error: failed to produce diagnostic for expression; please submit a bug report (https://swift.org/contributing/#reporting-bugs)
694:Phase3bClassificationTests.swift:172:42: error: cannot find 'PlanSource' in scope
697:Phase3bClassificationTests.swift:172:15: error: failed to produce diagnostic for expression; please submit a bug report (https://swift.org/contributing/#reporting-bugs)
700:Phase3bClassificationTests.swift:194:42: error: cannot find 'PerSourceExemptionRule' in scope
703:Phase3bClassificationTests.swift:193:9: error: failed to produce diagnostic for expression; please submit a bug report (https://swift.org/contributing/#reporting-bugs)
```

Final summary block:

```
Testing failed:
	Cannot find 'PerSourceExemptionRule' in scope
	Reference to member 'nyStateOrLocal' cannot be resolved without a contextual type
	Reference to member 'federalCivilian' cannot be resolved without a contextual type
	Reference to member 'definedBenefit' cannot be resolved without a contextual type
	Cannot infer contextual base in reference to member 'full'
	Testing cancelled because the build failed.

** TEST FAILED **


The following build commands failed:
	SwiftEmitModule normal arm64 Emitting\ module\ for\ RetireSmartIRATests (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	EmitSwiftModule normal arm64 (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	Testing project RetireSmartIRA with scheme RetireSmartIRA
(3 failures)
```

Failure is for the expected reason: the four new types (`PerSourceExemptionRule`, `RetirementPlanClassification`, `PlanStructure`, `PlanSource`) do not exist yet. No typo in the test file caused this; every referenced production symbol is genuinely absent.

## Step 3: implementation

Created `PlanStructure`, `PlanSource` (cases exactly as spec 3.1, `String, Codable, CaseIterable`, no custom raw strings), `RetirementPlanClassification` (struct wrapping both, `Codable, Equatable, Sendable`, with the two `infer` overloads per spec 3.6), and `PerSourceExemptionRule` (`Codable, Sendable`, `matches(structure:source:) -> Bool` with the empty-list-means-any semantics from spec 3.3/3.4a).

One deliberate deviation from the spec's illustrative struct signature: spec 3.3 shows `struct PerSourceExemptionRule: Codable, Equatable, Sendable`. `RetirementIncomeExemptions.ExemptionLevel` (the `treatment` field's type) is not `Equatable` today, and neither is its nested `PhaseoutTier`; both are declared in `StateTaxData.swift`, outside this task's file list. Adding `Equatable` there would be a small, safe, non-behavioral change, but it is not in the Task 1 file list and the brief's own "Interfaces produced" line for this task asks only for `matches(structure:source:) -> Bool`, not for struct-level `Equatable`. I dropped `Equatable` from `PerSourceExemptionRule` rather than touch a file outside the stated scope. Nothing in this task's tests needed to compare two `PerSourceExemptionRule` values for equality.

## Step 4: GREEN transcript

Same command as RED, after implementation:

```
◇ Test run started.
↳ Testing Library Version: 1902
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite "Phase 3b: RetirementPlanClassification and PerSourceExemptionRule" started.
◇ Test "An RMD income row infers ira / individual" started.
✔ Test "An RMD income row infers ira / individual" passed after 0.001 seconds.
◇ Test "A pension income row infers unknown / unknown, deferred to the picker" started.
✔ Test "A pension income row infers unknown / unknown, deferred to the picker" passed after 0.001 seconds.
◇ Test "Every other IncomeType infers unknown / unknown" started.
✔ Test "Every other IncomeType infers unknown / unknown" passed after 0.001 seconds.
◇ Test "A traditional IRA account infers ira / individual" started.
✔ Test "A traditional IRA account infers ira / individual" passed after 0.001 seconds.
◇ Test "A traditional 401(k) account infers definedContribution / privateEmployer" started.
✔ Test "A traditional 401(k) account infers definedContribution / privateEmployer" passed after 0.001 seconds.
◇ Test "Every other AccountType infers unknown / unknown" started.
✔ Test "Every other AccountType infers unknown / unknown" passed after 0.001 seconds.
◇ Test "NY Line 26 rule matches a NY state/local defined-benefit pension" started.
✔ Test "NY Line 26 rule matches a NY state/local defined-benefit pension" passed after 0.001 seconds.
◇ Test "NY Line 26 rule matches a federal civilian defined-benefit pension" started.
✔ Test "NY Line 26 rule matches a federal civilian defined-benefit pension" passed after 0.001 seconds.
◇ Test "NY Line 26 rule does NOT match an out-of-state defined-benefit pension (the defect this design removes)" started.
✔ Test "NY Line 26 rule does NOT match an out-of-state defined-benefit pension (the defect this design removes)" passed after 0.001 seconds.
◇ Test "NY Line 26 rule does NOT match a NY-sourced defined-contribution plan (structure gate)" started.
✔ Test "NY Line 26 rule does NOT match a NY-sourced defined-contribution plan (structure gate)" passed after 0.001 seconds.
◇ Test "NY Line 26 rule does NOT match governmentUnspecified, which is not itself a jurisdiction" started.
✔ Test "NY Line 26 rule does NOT match governmentUnspecified, which is not itself a jurisdiction" passed after 0.001 seconds.
◇ Test "Empty matchSources means any source, gated only by structure" started.
✔ Test "Empty matchSources means any source, gated only by structure" passed after 0.001 seconds.
◇ Test "Empty matchStructures means any structure, gated only by source" started.
✔ Test "Empty matchStructures means any structure, gated only by source" passed after 0.001 seconds.
◇ Test "An unrecognized PlanStructure string throws DecodingError instead of silently defaulting" started.
✔ Test "An unrecognized PlanStructure string throws DecodingError instead of silently defaulting" passed after 0.001 seconds.
◇ Test "The PlanStructure decode error names both the type and the bad value" started.
✔ Test "The PlanStructure decode error names both the type and the bad value" passed after 0.001 seconds.
◇ Test "An unrecognized PlanSource string throws DecodingError instead of silently defaulting" started.
✔ Test "An unrecognized PlanSource string throws DecodingError instead of silently defaulting" passed after 0.007 seconds.
◇ Test "The PlanSource decode error names both the type and the bad value" started.
✔ Test "The PlanSource decode error names both the type and the bad value" passed after 0.001 seconds.
◇ Test "A hand-edited PerSourceExemptionRule with a bogus matchStructures entry throws, not silently coerced" started.
✔ Test "A hand-edited PerSourceExemptionRule with a bogus matchStructures entry throws, not silently coerced" passed after 0.001 seconds.
✔ Suite "Phase 3b: RetirementPlanClassification and PerSourceExemptionRule" passed after 0.010 seconds.
✔ Test run with 18 tests in 1 suite passed after 0.010 seconds.

** TEST SUCCEEDED **
```

18/18 tests pass, 0 failures.

## Step 3a: the typed decode error

Both enums are declared `String, Codable, CaseIterable` with **synthesised** Codable, per Step 3's instruction. Step 3a says to confirm rather than assume that synthesis is diagnosable, and hand-write only if it is not.

**Empirical check, run before implementing** (outside the Xcode project, as a standalone `swift` script, to see the raw synthesised behavior with no test-framework formatting in the way):

```swift
enum PlanStructure: String, Codable, CaseIterable {
    case definedBenefit, definedContribution, ira, unknown
}
struct Wrapper: Codable { let structure: PlanStructure }

let json = #"{"structure": "bogusValue"}"#
let data = json.data(using: .utf8)!
do {
    let w = try JSONDecoder().decode(Wrapper.self, from: data)
    print("DECODED (unexpected): \(w)")
} catch let error as DecodingError {
    print("error: \(error)")
} catch {
    print("Other error: \(error)")
}
```

Output:

```
error: DecodingError.dataCorrupted: Data was corrupted. Path: structure. Debug description: Cannot initialize PlanStructure from invalid String value bogusValue
```

The synthesised error already names the exact type (`PlanStructure`) and the exact offending raw value (`bogusValue`) in the `debugDescription`, plus the JSON coding path. That is diagnosable: a developer or a decode-failure log line reporting this message identifies both what was expected and what was actually found in the file, which is what "so a corrupt or hand-edited config is diagnosable" requires. **No hand-written `Codable` conformance was needed for either enum.** `StateTaxCodable.swift` (the file housing every hand-written conformance in this codebase, e.g. `StateTaxConfig`'s `"Unknown state abbreviation '\(abbreviation)'"` error for the same class of problem) was therefore left untouched. The Task 1 file list named it as a file to modify; I did not modify it, because Step 3a's own instruction conditions that modification on synthesis being insufficient, and it was not.

**In-suite JSON literal used for the test** (`Phase3bClassificationTests.swift`, `planStructureDecodeErrorIsDiagnosable` and the `PlanSource` equivalent):

```swift
let malformed = Data("\"notARealStructure\"".utf8)
do {
    _ = try JSONDecoder().decode(PlanStructure.self, from: malformed)
    Issue.record("Expected decoding to throw; it succeeded instead")
} catch let error as DecodingError {
    let description = String(describing: error)
    #expect(description.contains("PlanStructure"))
    #expect(description.contains("notARealStructure"))
} catch {
    Issue.record("Expected a DecodingError, got \(type(of: error)): \(error)")
}
```

and the `PlanSource` mirror with `"notARealSource"`. Both passed (see GREEN transcript above: "The PlanStructure decode error names both the type and the bad value" / "The PlanSource decode error names both the type and the bad value").

A third test exercises the array-context path a real config file would actually use, rather than only a bare top-level string, per "confirm it rather than assume it":

```swift
let malformed = Data("""
{"matchSources": ["nyStateOrLocal"],
 "matchStructures": ["notARealStructure"],
 "treatment": {"kind": "full"}}
""".utf8)
#expect(throws: DecodingError.self) {
    _ = try JSONDecoder().decode(PerSourceExemptionRule.self, from: malformed)
}
```

This also throws `DecodingError` (test `perSourceExemptionRuleDecodeThrowsOnBogusStructureInArray`, passed). No fallback to `.unknown` occurs in either the bare-value or array-context path.

## The two negative matching cases

Both required by the brief were written and both pass:

1. **`(.definedBenefit, .otherStateOrLocal)` must NOT match** a rule with `matchSources: [.nyStateOrLocal, .federalCivilian]`, `matchStructures: [.definedBenefit]`. Test `nyRuleDoesNotMatchOutOfStateDefinedBenefit`. Produced `false`, as required. This is the regression test for the defect the design doc names directly: an out-of-state (e.g. California or Illinois) public pension held by a New York resident must not receive the uncapped Line 26 exclusion.
2. **`(.definedContribution, .nyStateOrLocal)` must NOT match** the same rule. Test `nyRuleDoesNotMatchDefinedContributionEvenFromNY`. Produced `false`, as required. This is the structure gate: a NY government employee's 403(b) is excluded from Line 26 by its `definedContribution` structure alone, regardless of source, and falls through to the ordinary capped exemption.

I also added a third, related negative case beyond the two named in the brief, directly targeting context clue 4 (`governmentUnspecified` is not a jurisdiction): `(.definedBenefit, .governmentUnspecified)` against the same NY-shaped rule must NOT match. Test `nyRuleDoesNotMatchGovernmentUnspecified`. Produced `false`. Mechanically this already falls out of `matchSources.contains(source)` returning false for a value that isn't literally in the list, so it wasn't a case that could have failed differently from case 1, but it documents the specific constraint from the design doc rather than leaving it implicit.

## `git diff --stat`

Against base HEAD `42ce722`:

```
 RetireSmartIRA/PerSourceExemptionRule.swift        |  40 +++++
 RetireSmartIRA/RetirementPlanClassification.swift  |  91 ++++++++++
 .../Phase3bClassificationTests.swift               | 197 +++++++++++++++++++++
 3 files changed, 328 insertions(+)
```

`git status --porcelain` after commit is clean. No other file changed; `RetireSmartIRA.xcodeproj/project.pbxproj` was not touched (both source roots are synchronized groups, confirmed by `git diff --stat` showing zero changes to it); `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift` and its fixture were not touched.

## Commit

`4d829ef` on `feature/state-tax-phase3b`, message `feat(state-tax): plan structure and source dimensions with inference`. Staged explicitly (`git add RetireSmartIRA/RetirementPlanClassification.swift RetireSmartIRA/PerSourceExemptionRule.swift RetireSmartIRATests/Phase3bClassificationTests.swift`), no `git add -A`.

## Scope check against hard constraints

- No edit to `project.pbxproj`.
- No em dash characters used anywhere in the new code, tests, this report, or the commit message.
- No computed tax value changed; no engine, `DataManager`, `ProjectionEngine`, view, or JSON file touched. Only two new production Swift files and one new test file were added.
- `StateTaxBehaviorBaselineTests.swift` and its fixture untouched.
- Explicit paths staged, no `git add -A`.

## Only run in the foreground

Both the RED and GREEN `xcodebuild test` invocations ran synchronously via the Bash tool, not Monitor and not backgrounded. A targeted run (`-only-testing:RetireSmartIRATests/Phase3bClassificationTests`) was sufficient; a full-suite run was not attempted, since nothing in production consumes these types yet and the hard constraints rule out any change that could affect other tests.
