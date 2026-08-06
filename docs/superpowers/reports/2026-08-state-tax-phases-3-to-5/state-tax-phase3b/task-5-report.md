# Task 5 report: multi-year receives classified pension income

Status: DONE
HEAD before this task: `77df3ab`
Commit: `b174ccb` (`feature/state-tax-phase3b`)

## Summary

`MultiYearStaticInputs` gains two optional fields, `primaryPensionClassification` /
`spousePensionClassification: RetirementPlanClassification?` (default `nil`), added
ADDITIVELY beside the existing `primaryPensionIncome`/`spousePensionIncome` scalars --
the same pattern Task 3's `distributionComponents` uses beside
`scenarioRetirementDistributions`. `MultiYearInputAdapter` derives each owner's
classification from their `.pension` `IncomeSource` row(s): exactly one row ->
that row's `(planStructure, planSource)`; zero or more than one row -> `nil`
(unclassified), because an owner with two differently-classified pensions cannot
be represented by a single classification without misattributing one pension's
dollars to the other's rule. `ProjectionEngine.computeStateTax` now builds ONE
`IncomeSource` row PER OWNER (previously one combined, always-`.primary`,
always-unclassified row from `primaryPensionIncome + spousePensionIncome`), each
carrying that owner's classification, and forwards it at all three internal call
sites. `WidowStressTest`'s two single-filer variant constructions carry the
surviving spouse's own classification through.

`AccountSnapshot` was NOT widened (out of scope per spec 3.4b): account
classification still affects only the single-year calculation, not the
projection.

## Step 1: RED transcript (verbatim excerpt)

Produced by writing the test file first, then `git stash` on only the four
production files (`MultiYearInputAdapter.swift`, `MultiYearStaticInputs.swift`,
`ProjectionEngine.swift`, `WidowStressTest.swift`) so the test compiled against
pre-Task-5 production code, running `-only-testing:...Phase3bMultiYearPensionClassificationTests`,
then `git stash pop` to restore the fix before continuing.

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bMultiYearPensionClassificationTests.swift:59:43: error: extra arguments at positions #22, #23 in call
        let inputs = MultiYearStaticInputs(
                                          ^
RetireSmartIRA.MultiYearStaticInputs.init:2:21: note: 'init(startingBalances:baseYear:primaryCurrentAge:spouseCurrentAge:filingStatus:state:localIncomeTaxRate:primarySSClaimAge:spouseSSClaimAge:primaryExpectedBenefitAtFRA:spouseExpectedBenefitAtFRA:primaryBirthYear:spouseBirthYear:primaryBirthDate:spouseBirthDate:primaryWageIncome:spouseWageIncome:primaryPensionIncome:spousePensionIncome:primaryOtherOrdinaryIncome:spouseOtherOrdinaryIncome:primaryPreferentialIncome:spousePreferentialIncome:primaryNetInvestmentIncome:spouseNetInvestmentIncome:acaEnrolled:acaHouseholdSize:primaryMedicareEnrollmentAge:spouseMedicareEnrollmentAge:baselineAnnualExpenses:heirSalary:heirFilingStatus:heirDrawdownYears:year1PrimaryRothConversion:year1SpouseRothConversion:year1PrimaryWithdrawal:year1SpouseWithdrawal:year1PrimaryQCD:year1SpouseQCD:charitableGivingPlan:carriedMortgageAndOtherItemized:carriedPropertyAndOtherSALT:carriedGrossMedicalExpenses:taxableAccounts:inheritedAccounts:)' declared here
@MainActor internal init(startingBalances: RetireSmartIRA.AccountSnapshot, ... taxableAccounts: [RetireSmartIRA.TaxableAccountInput] = [], inheritedAccounts: [RetireSmartIRA.InheritedAccountInput] = [])}
                    ^
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bMultiYearPensionClassificationTests.swift:82:42: error: 'nil' requires a contextual type
            spousePensionClassification: nil
                                         ^

Testing failed:
	Extra arguments at positions #22, #23 in call
	'nil' requires a contextual type
	Testing cancelled because the build failed.

** TEST FAILED **

The following build commands failed:
	SwiftCompile normal arm64 /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bMultiYearPensionClassificationTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	SwiftCompile normal arm64 Compiling\ Phase3bMultiYearPensionClassificationTests.swift /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bMultiYearPensionClassificationTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	Testing project RetireSmartIRA with scheme RetireSmartIRA
(3 failures)
```

Failed exactly as expected: `MultiYearStaticInputs.init` does not yet accept
`primaryPensionClassification:`/`spousePensionClassification:` before Task 5's
production edits exist. Not a typo, not an existing-behavior false pass --
this is the empirical statement that no classification reaches the projection
today (the test cannot even be EXPRESSED against pre-Task-5 code, let alone
pass).

## Why the cross-path comparison target is `TaxCalculationEngine.calculateStateTax`, not the golden $487.75

New York's `stateDeduction` is `.fixed(single: 8_000, married: 16_050)`, nonzero.
`GoldenScenarioSingleYearTests.singleYearStateTax` (documented as standing in
for `DataManager.calculateStateTaxFromGross`) subtracts that deduction from
`federalAGI` BEFORE calling the engine. `ProjectionEngine.computeStateTax` does
not -- confirmed by grep, zero hits:

```
$ grep -n "stateDeduction\|stateStandardDeduction\|StateTaxConfig\|\.taxSystem\b" RetireSmartIRA/ProjectionEngine.swift
(no output)
```

This is a real, PRE-EXISTING gap, orthogonal to pension classification, and not
something Task 5's brief scopes in (files list: `MultiYearStaticInputs.swift`,
`MultiYearInputAdapter.swift`, `ProjectionEngine.swift`, `WidowStressTest.swift`
-- the ask is specifically the pension-classification pass-through, not adding
state-deduction handling to the multi-year path). It is why
`GoldenScenarioCrossPathTests.agreeing` is `["PA", "IL", "MS"]`: all three have
`stateDeduction: .none`, making the missing subtraction a no-op and invisible
in that suite. New York would be the first state where the gap is NOT a no-op,
so comparing the multi-year result against the golden $487.75 (which bakes the
deduction in) would fail for a reason unrelated to this task, contaminating
the classification signal. `Phase3bMultiYearPensionClassificationTests`
therefore calls `TaxCalculationEngine.calculateStateTax` the same way
`ProjectionEngine.computeStateTax` calls it (`income: federalAGI` directly, no
pre-subtraction), isolating exactly the pass-through Task 5 is scoped to fix.
This finding is disclosed here, not fixed.

## GREEN transcript (after Steps 2-3)

```
◇ Suite "Phase 3b Task 5: multi-year pension classification cross-path" started.
◇ Test "An unclassified NY pension stays capped in multi-year year 1 (baseline, unchanged by this task)" started.
✔ Test "An unclassified NY pension stays capped in multi-year year 1 (baseline, unchanged by this task)" passed after 0.007 seconds.
◇ Test "New York government pension: multi-year year 1 agrees with the single-year engine call once classified" started.
✔ Test "New York government pension: multi-year year 1 agrees with the single-year engine call once classified" passed after 0.001 seconds.
✔ Suite "Phase 3b Task 5: multi-year pension classification cross-path" passed after 0.007 seconds.
✔ Test run with 2 tests in 1 suite passed after 0.007 seconds.
...
** TEST SUCCEEDED **
```

## Mutation proof: the cross-path test discriminates

Broke the classification pass-through at the exact line the fix added
(`RetireSmartIRA/ProjectionEngine.swift`, the primary-pension `IncomeSource`
row builder), forcing `planStructure`/`planSource` to `nil` regardless of
`primaryPensionClassification`:

```swift
annualAmount: primaryPensionIncome,
owner: .primary,
planStructure: nil, // MUTATION: break classification pass-through
planSource: nil // MUTATION: break classification pass-through
))
```

Reran the targeted suite:

```
✘ Test "New York government pension: multi-year year 1 agrees with the single-year engine call once classified" recorded an issue at Phase3bMultiYearPensionClassificationTests.swift:134:9: Expectation failed: (abs(single - multi) → 2535.0) < 0.01
✘ Test "New York government pension: multi-year year 1 agrees with the single-year engine call once classified" recorded an issue at Phase3bMultiYearPensionClassificationTests.swift:145:9: Expectation failed: (multi → 2535.0) < (cappedBaseline → 2535.0)
✘ Test run with 2 tests in 1 suite failed after 0.014 seconds with 2 issues.
** TEST FAILED **
```

(`unclassifiedPensionStaysCapped` still passed under this mutation, as
expected -- it never exercises classification.) Reverted the mutation and
confirmed no residue:

```
$ git diff -- RetireSmartIRA/ProjectionEngine.swift | grep -c MUTATION
0
```

Reran the targeted suite: both tests green again (`Test run with 2 tests in 1
suite passed`).

## Step 4 hard check: the pins that must not move

Ran in the same full-suite pass reported below (also confirmed in an earlier
targeted pass over `GoldenScenarioCrossPathTests`, `GoldenScenarioSingleYearTests`,
`GoldenScenarioMultiYearTests`, `StateTaxBehaviorBaselineTests`, and the
Phase 3a/3b suites: 50 tests in 9 suites passed).

- **I2 pins held.** `GoldenScenarioCrossPathTests.newJerseyCrossPathGapPinnedAsObserved`
  passed (single-year 42.0, multi-year 200.40469973890345 -- both assertions
  are `#expect(abs(x - PINNED_VALUE) < 0.01, ...)`, and the test passed, so
  neither pin moved):
  ```
  ◇ Test "PINNED, New Jersey single-year vs multi-year: two components, I2 is the smaller one" started.
  ✔ Test "PINNED, New Jersey single-year vs multi-year: two components, I2 is the smaller one" passed after 0.001 seconds.
  ```
- **Frozen baseline held, byte-identical, not regenerated.**
  ```
  ✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.043 seconds.
  ✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.043 seconds.

  $ git status --porcelain RetireSmartIRATests/Baselines/
  (nothing)
  $ md5 RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json
  MD5 (.../statetax-behavior-baseline-2026.json) = 34a121744f8edf3db7c440202a8c4d83
  $ git show HEAD:RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json | md5
  34a121744f8edf3db7c440202a8c4d83
  ```
- **No jurisdiction other than New York's numbers moved.** The entire diff is
  plumbing in four Swift files under `RetireSmartIRA/`; nothing under
  `RetireSmartIRA/Resources/StateTaxData/` changed:
  ```
  $ git diff --stat -- RetireSmartIRA/Resources/StateTaxData/
  (nothing)
  ```

## Em dash check

```
$ git diff | grep "^+" | grep -c "—"
0
$ python3 -c "... counts em dashes in diff-added lines AND in the new untracked test file ..."
em dashes in diff added lines: 0
em dashes in new test file: 0
```

## Tree-confirmation grep

```
$ grep -o "worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj" /tmp/p3b-task5.log | head -1
worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj
```

## Full suite (run once, foreground)

First attempt was accidentally left running past a tool timeout and had to be
re-run cleanly in the foreground per the controller's correction; the report
below is from the clean, single, foreground run whose output was read in the
same turn (`xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`,
teed to `/tmp/p3b-task5.log`):

```
✔ Test run with 1705 tests in 284 suites passed after 313.097 seconds.
```
```
	 Executed 503 tests, with 0 failures (0 unexpected) in 21.406 (21.603) seconds
Test Suite 'All tests' passed at ...
	 Executed 503 tests, with 0 failures (0 unexpected) in 21.406 (21.603) seconds
```
```
** TEST SUCCEEDED **
```

(Task 4's post-review baseline was 1703 Swift Testing / 283 suites + 503
XCTest. This task adds 1 new suite / 2 new tests
(`Phase3bMultiYearPensionClassificationTests`), landing at 1705 / 284. 0
failures either way.)

## `git diff --stat`

```
$ git diff --stat HEAD~1
 RetireSmartIRA/MultiYearInputAdapter.swift                     | 29 ++++++++++--
 RetireSmartIRA/MultiYearStaticInputs.swift                     | 22 +++++++++-
 RetireSmartIRA/ProjectionEngine.swift                          | 62 +++++++++++++++++++++++------
 RetireSmartIRA/WidowStressTest.swift                            | 15 ++++++-
 RetireSmartIRATests/Phase3bMultiYearPensionClassificationTests.swift | 132 ++++++++++
 5 files changed, 260 insertions(+), 16 deletions(-)
```

No `project.pbxproj` touched (`git diff --stat -- RetireSmartIRA.xcodeproj/project.pbxproj`
empty), no JSON under `Resources/StateTaxData/` touched, no view touched, no
`DataManager.swift` touched (grep for `primaryPensionClassification` /
`spousePensionClassification` / `primaryPensionIncome` / `spousePensionIncome`
in `DataManager.swift` returns zero hits -- the single-year mirror already
carries classification entirely through `IncomeSource.planStructure`/`planSource`
and has no pension scalar fields of its own, so it needed no change for this
task).

## `DataManager.applyRetirementExemptions` (line 674) check

Confirmed this private wrapper is dead code with zero call sites (only its own
declaration and its internal call into `TaxCalculationEngine
.applyRetirementExemptions` match a grep for the name), so its `nil`-pinned
components parameter has no bearing on the cross-path test or on any live
DataManager code path. The real single-year screen path
(`DataManager.scenarioStateTax` -> `calculateStateTaxFromGross`) passes
`incomeSources: incomeSources` directly to `TaxCalculationEngine
.applyRetirementExemptions`, and those rows already carry `planStructure`/
`planSource` from Task 2, independent of this dead wrapper.

## Commit

Staged explicit paths only (no `git add -A`): `RetireSmartIRA/MultiYearInputAdapter.swift`,
`RetireSmartIRA/MultiYearStaticInputs.swift`, `RetireSmartIRA/ProjectionEngine.swift`,
`RetireSmartIRA/WidowStressTest.swift`, `RetireSmartIRATests/Phase3bMultiYearPensionClassificationTests.swift`.

Commit `b174ccb`: `feat(state-tax): multi-year receives classified pension income`.
