# Memo hash fix: plan classification must invalidate `scenarioStateTax`

Branch `feature/state-tax-phase3b`, worktree `.worktrees/state-tax-phase3b`.
Starting HEAD `6fed94e` (>= required `4c05388`).

## The defect

`DataManager.scenarioStateTax` (`DataManager.swift:2217-2233`) is wrapped in
`memoizedScenarioStateTax`, keyed on `engineInputsHash`
(`DataManager+Memo.swift`). That hash's income-source loop and account loop
combined every field Phase 3a needed but never picked up the two fields
Phase 3b added: `planStructure` and `planSource`. Reclassifying a pension
(e.g. New York "Government pension, New York State or local" ->
"Government pension, another state or locality") changes what
`TaxCalculationEngine`/`DataManager`'s per-source exemption matcher computes,
but does not change the hash, so `scenarioStateTax` kept returning the
pre-reclassification cached value forever. Confirmed in the running app
(iPhone 17 Pro simulator, NY resident, single, age 73, $70,000 pension):
Tax Summary State Tax stuck at $0.00 after reclassification while State
Comparison (not behind this cache) correctly showed $2,103.00.

## The fix

`RetireSmartIRA/DataManager+Memo.swift`, `engineInputsHash`:
- Income-source loop: added `h.combine(source.planStructure)` and
  `h.combine(source.planSource)` after `source.stateWithholdingPercent`.
- Account loop: added `h.combine(account.planStructure)` and
  `h.combine(account.planSource)` after `account.minorChildMajorityYear`.

No computation changed. `PlanStructure`/`PlanSource` are plain
`String`-backed enums with no associated values, so Swift synthesizes
`Hashable` for them automatically; no extra conformance work needed.

## Audit: which memoized values were affected

`EngineMemoCache` holds 8 slots, all keyed on the same `engineInputsHash`.
Went through each one's compute closure to see whether it reads
`IncomeSource.planStructure`/`planSource` or `IRAAccount.planStructure`/
`planSource`, directly or transitively:

| Memoized property | Reads plan classification? | Affected by the bug? |
|---|---|---|
| `scenarioStateTax` | Yes -- `calculateStateTaxFromGross` -> `calculateStateTax` -> `TaxCalculationEngine.calculateStateTax(incomeSources:)`, which partitions pension/RMD rows through `exemptions.matchedPerSourceRule(structure:source:)`. | **Yes.** This is the reported defect. |
| `scenarioFederalTax` | No -- federal tax has no per-source retirement-plan concept; `planStructure`/`planSource` are a state-only Phase 3b construct. | No. |
| `legacyHeirTaxEstimate` | No -- `TaxCalculationEngine.heirTaxEstimate` takes `annualDistribution`/`heirSalary`/`filingStatus`/`drawdownYears` only; no income-source or account classification enters it. | No. |
| `convertNowVsHeirComparison` | No -- built from `legacyHeirTaxEstimate` (unaffected) and `scenarioTaxableIncome`/`federalBracketInfo` (federal, unaffected). | No. |
| `seniorBonusDeductionAmount` | No -- federal OBBBA senior deduction, gated on MAGI/age/filing status only. | No. |
| `scenarioRetirementDistributionIncome` | No -- sums `scenarioTotalWithdrawals` (RMDs/extra withdrawals by dollar amount), never filters or branches on `planStructure`/`planSource`. | No. |
| `baselineACAMagi` | No -- federal/ACA MAGI computation, no state per-source exemption involved. | No. |
| `ltcg0PercentHeadroom` | No -- federal LTCG bracket math only. | No. |

So exactly one of the 8 raw cache slots is directly affected:
**`scenarioStateTax`**.

### Non-memoized consumers that inherit the staleness

`scenarioStateTax`'s staleness silently propagates into every plain
(non-cached) computed property that reads it, because those properties
recompute on every access but the memoized value they read from was frozen.
Found by grepping `DataManager.swift` for `scenarioStateTax`/`scenarioTotalTax`
usage:

- `scenarioTotalTax` (`DataManager.swift:2235-2237`) --
  `scenarioFederalTax + scenarioStateTax + scenarioNIITAmount + scenarioAMTAmount`.
  Not itself cached, but inherits the stale `scenarioStateTax` term. This is
  almost certainly the actual number the Tax Summary screen's headline total
  reads.
- `scenarioRemainingTax` (`:2679`) -- `scenarioTotalTax - totalWithholding`.
- The lifetime-impact deltas at `:3040`, `:3059`, `:3085`, `:3143`, `:3236`,
  `:3262`, `:3284` (convert/withdraw/QCD/inherited/deduction/gain/cash-donation
  "impact" figures) -- each subtracts two `scenarioTotalTax` evaluations, so
  each one is stale by the same stuck-`scenarioStateTax` amount both before
  and after the scenario change being measured, though the delta itself can
  partially cancel depending on what else moved.

### Confirmed NOT affected: `scenarioStateTaxBreakdown`

`scenarioStateTaxBreakdown` (`DataManager.swift:2213-2215`) is **not** behind
`EngineMemoCache` at all -- it calls `stateTaxBreakdown(forState:filingStatus:)`
directly on every read, no memo wrapper. This is exactly why the bug report's
"State Comparison" screen showed the correct $2,103.00 live while the Tax
Summary headline (reading the memoized `scenarioStateTax`) stayed at $0.00 on
the same data.

### Account-loop audit: no currently-memoized value depends on it

The task instructions called out the account loop's identical gap for
`IRAAccount.planStructure`/`planSource`. Traced every path from an account's
classification into the DataManager memo layer:

- `calculateStateTaxFromGross` (used by `scenarioStateTax`) has no
  `distributionComponents` parameter at all.
- `stateTaxBreakdown` (used by the *unmemoized* `scenarioStateTaxBreakdown`)
  does take a `distributionComponents: [RetirementDistributionComponent]?`
  parameter, but `scenarioStateTaxBreakdown`'s call site
  (`DataManager.swift:2213-2215`) always passes `nil` -- it is never supplied
  from account data anywhere in `DataManager.swift`.
- Grepped the whole app (`grep -rn "RetirementDistributionComponent(" RetireSmartIRA/*.swift`,
  excluding tests) -- **zero** production call sites construct one. The only
  place `planStructure`/`planSource` reach a per-source rule via an
  account-shaped distribution is `ProjectionEngine.computeStateTax`
  (`ProjectionEngine.swift:1590-1651`, the multi-year path), which builds its
  own `[IncomeSource]` array and calls
  `TaxCalculationEngine.calculateStateTax` directly -- it never touches
  `DataManager`'s `EngineMemoCache` or `engineInputsHash`.

Conclusion: today, no memoized DataManager value's *output* depends on
`IRAAccount.planStructure`/`planSource` in the single-year pipeline, because
nothing in that pipeline is wired to read them yet. The account-loop hash
addition is therefore prophylactic, not a fix for an currently-observable
staleness bug -- consistent with the file's own stated policy ("when in
doubt, add it," false positives only cost performance, false negatives cause
silent bugs). If a future task wires account classification into this
pipeline (the `distributionComponents` parameter exists for exactly that),
the hash already covers it and won't reintroduce this exact defect silently.

## Tests added

`RetireSmartIRATests/DataManagerMemoizationTests.swift`, three new tests:

1. `scenarioStateTaxInvalidatesOnPensionPlanSourceChange` -- NY, single, age
   73, one $70,000 pension. Primes `scenarioStateTax` with
   `(planStructure: .definedBenefit, planSource: .nyStateOrLocal)` (fully
   excluded under NY's Line 26 per-source rule), mutates ONLY
   `incomeSources[0].planSource` to `.otherStateOrLocal` (no longer matches,
   falls back to the ordinary $20,000-capped exclusion), re-reads
   `scenarioStateTax`, asserts it changed and rose.
2. `scenarioStateTaxInvalidatesOnPensionPlanStructureChange` -- same setup,
   mutates ONLY `planStructure` to `.definedContribution` instead (NY's rule
   requires `.definedBenefit`), same assertions.
3. `engineInputsHashChangesOnAccountPlanClassificationChange` -- asserts
   `engineInputsHash` itself changes when an `IRAAccount`'s `planSource` and
   then `planStructure` change. Per the audit above, no memoized *value*
   currently depends on this, so this test proves hash coverage, not a
   behavior change (documented in the test's own comment).

Both pension tests go through the real memoized property
(`dm.scenarioStateTax`), not the engine directly, so they exercise the exact
code path the bug lived in.

## Discrimination proof

### GREEN (fix in place, before reverting)

Ran only the memoization suite (`RetireSmartIRATests/DataManagerMemoizationTests.swift`,
15 tests) via `xcodebuild test-without-building ... -only-testing:RetireSmartIRATests/DataManagerMemoizationTests`:

```
◇ Test "scenarioStateTax invalidates when a pension's planSource classification changes (NY)" started.
✔ Test "scenarioStateTax invalidates when a pension's planSource classification changes (NY)" passed after 0.001 seconds.
◇ Test "scenarioStateTax invalidates when a pension's planStructure classification changes (NY)" started.
✔ Test "scenarioStateTax invalidates when a pension's planStructure classification changes (NY)" passed after 0.001 seconds.
◇ Test "engineInputsHash changes when an account's planStructure or planSource changes" started.
✔ Test "engineInputsHash changes when an account's planStructure or planSource changes" passed after 0.001 seconds.
✔ Suite "DataManager memoization — cache hit + invalidation" passed after 0.017 seconds.
✔ Test run with 15 tests in 1 suite passed after 0.017 seconds.

** TEST EXECUTE SUCCEEDED **
```

### RED (reverted the two `h.combine` additions in both loops)

Removed `h.combine(source.planStructure)` / `h.combine(source.planSource)`
from the income-source loop and `h.combine(account.planStructure)` /
`h.combine(account.planSource)` from the account loop, rebuilt
(`build-for-testing`, succeeded), reran the same tests:

```
◇ Test "scenarioStateTax invalidates when a pension's planSource classification changes (NY)" started.
✘ Test "scenarioStateTax invalidates when a pension's planSource classification changes (NY)" recorded an issue at DataManagerMemoizationTests.swift:288:9: Expectation failed: (beforeHash → 2047743522344545804) != (afterHash → 2047743522344545804)
↳ Changing planSource should change engineInputsHash
✘ Test "scenarioStateTax invalidates when a pension's planSource classification changes (NY)" recorded an issue at DataManagerMemoizationTests.swift:291:9: Expectation failed: (after → 0.0) != (before → 0.0)
↳ Reclassifying the pension's planSource must change scenarioStateTax; got before=0.0 after=0.0 (stale memo would leave these equal)
✘ Test "scenarioStateTax invalidates when a pension's planSource classification changes (NY)" recorded an issue at DataManagerMemoizationTests.swift:292:9: Expectation failed: (after → 0.0) > (before → 0.0)
↳ Losing the full Line 26 exclusion for a $50K larger taxable base should raise NY state tax; got before=0.0 after=0.0
✘ Test "scenarioStateTax invalidates when a pension's planSource classification changes (NY)" failed after 0.004 seconds with 3 issues.
◇ Test "scenarioStateTax invalidates when a pension's planStructure classification changes (NY)" started.
✘ Test "scenarioStateTax invalidates when a pension's planStructure classification changes (NY)" recorded an issue at DataManagerMemoizationTests.swift:319:9: Expectation failed: (beforeHash → 1707184173628097867) != (afterHash → 1707184173628097867)
↳ Changing planStructure should change engineInputsHash
✘ Test "scenarioStateTax invalidates when a pension's planStructure classification changes (NY)" recorded an issue at DataManagerMemoizationTests.swift:322:9: Expectation failed: (after → 0.0) != (before → 0.0)
↳ Reclassifying the pension's planStructure must change scenarioStateTax; got before=0.0 after=0.0 (stale memo would leave these equal)
✘ Test "scenarioStateTax invalidates when a pension's planStructure classification changes (NY)" recorded an issue at DataManagerMemoizationTests.swift:323:9: Expectation failed: (after → 0.0) > (before → 0.0)
↳ Losing the full Line 26 exclusion for a $50K larger taxable base should raise NY state tax; got before=0.0 after=0.0
✘ Test "scenarioStateTax invalidates when a pension's planStructure classification changes (NY)" failed after 0.001 seconds with 3 issues.
◇ Test "engineInputsHash changes when an account's planStructure or planSource changes" started.
✘ Test "engineInputsHash changes when an account's planStructure or planSource changes" recorded an issue at DataManagerMemoizationTests.swift:356:9: Expectation failed: (sourceBefore → -6502969768698675775) != (sourceAfter → -6502969768698675775)
↳ Changing an account's planSource should change engineInputsHash
✘ Test "engineInputsHash changes when an account's planStructure or planSource changes" recorded an issue at DataManagerMemoizationTests.swift:360:9: Expectation failed: (sourceAfter → -6502969768698675775) != (structureAfter → -6502969768698675775)
↳ Changing an account's planStructure should change engineInputsHash
✘ Test "engineInputsHash changes when an account's planStructure or planSource changes" failed after 0.001 seconds with 2 issues.
✘ Suite "DataManager memoization — cache hit + invalidation" failed after 0.019 seconds with 8 issues.
✘ Test run with 15 tests in 1 suite failed after 0.019 seconds with 8 issues.

Failing tests:
	DataManagerMemoizationTests.scenarioStateTaxInvalidatesOnPensionPlanSourceChange()
	DataManagerMemoizationTests.scenarioStateTaxInvalidatesOnPensionPlanSourceChange()
	DataManagerMemoizationTests.scenarioStateTaxInvalidatesOnPensionPlanSourceChange()
	DataManagerMemoizationTests.scenarioStateTaxInvalidatesOnPensionPlanStructureChange()
	DataManagerMemoizationTests.scenarioStateTaxInvalidatesOnPensionPlanStructureChange()
	DataManagerMemoizationTests.scenarioStateTaxInvalidatesOnPensionPlanStructureChange()
	DataManagerMemoizationTests.engineInputsHashChangesOnAccountPlanClassificationChange()
	DataManagerMemoizationTests.engineInputsHashChangesOnAccountPlanClassificationChange()

** TEST EXECUTE FAILED **
```

Note the exact `before=0.0 after=0.0` in the RED output: this is the same
stuck-at-$0.00 failure mode hand-verified in the running app.

### GREEN again (restored both `h.combine` additions)

Restored the four lines, rebuilt (`build-for-testing`, succeeded), reran the
same tests:

```
◇ Test "scenarioStateTax invalidates when a pension's planSource classification changes (NY)" started.
✔ Test "scenarioStateTax invalidates when a pension's planSource classification changes (NY)" passed after 0.001 seconds.
◇ Test "scenarioStateTax invalidates when a pension's planStructure classification changes (NY)" started.
✔ Test "scenarioStateTax invalidates when a pension's planStructure classification changes (NY)" passed after 0.001 seconds.
◇ Test "engineInputsHash changes when an account's planStructure or planSource changes" started.
✔ Test "engineInputsHash changes when an account's planStructure or planSource changes" passed after 0.001 seconds.
✔ Suite "DataManager memoization — cache hit + invalidation" passed after 0.015 seconds.
✔ Test run with 15 tests in 1 suite passed after 0.016 seconds.

** TEST EXECUTE SUCCEEDED **
```

The tests discriminate: RED without the fix, GREEN with it, in both
directions.

## Em dash check

Ran a byte-level (`grep -nP '\xe2\x80\x94'`) scan over both changed files, no
match (exit code 1 = not found):

```
$ grep -nP '\xe2\x80\x94' RetireSmartIRA/DataManager+Memo.swift RetireSmartIRATests/DataManagerMemoizationTests.swift
grep exit code: 1
```

Also verified via `git diff` over just the changed hunks, same result (exit
code 1, no output). All prose asides in the new test comments use the
codebase's existing double-hyphen convention (`--`), matching e.g.
`DataManager.swift`'s existing comments in the same area (`... this cap --
never evaluated per row.`).

## Baseline and pins

- `StateTaxBehaviorBaselineTests` ("PHASE 3a GATE: state tax behavior
  baseline"): `Test "Every jurisdiction and scenario matches the frozen
  pre-Phase-3a baseline" with 51 test cases passed after 0.045 seconds.` --
  all 51 jurisdictions, byte-identical, as expected (this fix changes a cache
  key, not a computation).
- `GoldenScenarioCrossPathTests` ("Golden scenarios, cross-path agreement"):
  `Test "Both engine entry points report the same state tax" with 3 test
  cases passed` (PA/IL/MS) and `Test "PINNED, New Jersey single-year vs
  multi-year: two components, I2 is the smaller one" passed` -- both suites
  passed; single-year 42.0 and multi-year 200.40469973890345 pins held
  (unreachable, since neither `TaxCalculationEngine.swift` nor
  `Resources/StateTaxData/` was touched).

## Full suite (run exactly once, at the end)

`xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'`

Two summary lines (Swift Testing suite, then the nested legacy XCTest suite):

```
Executed 505 tests, with 0 failures (0 unexpected) in 21.877 (22.066) seconds
Test run with 1755 tests in 285 suites passed after 315.819 seconds.
```

`** TEST SUCCEEDED **`. `hard failures: 0`.

## `git diff --stat`

```
 RetireSmartIRA/DataManager+Memo.swift              |   4 +
 .../DataManagerMemoizationTests.swift              | 116 +++++++++++++++++++++
 2 files changed, 120 insertions(+)
```

No other files touched. `RetireSmartIRA.xcodeproj/project.pbxproj`,
`TaxCalculationEngine.swift`, and `Resources/StateTaxData/*` are all
untouched (`git diff --stat` shows only the two files above).
