# Task 3 report: the engine takes components, still inert

Status: DONE
HEAD before this task: `3cf4d26`

## Summary

Added `RetirementDistributionComponent` (owner + structure + source + amount) and an optional
`distributionComponents: [RetirementDistributionComponent]? = nil` parameter to
`TaxCalculationEngine.calculateStateTax`, `TaxCalculationEngine.applyRetirementExemptions`, and the
`DataManager.stateTaxBreakdown` mirror (which also gained the `configOverride: StateTaxConfig? = nil`
test seam Phase 3a's Task 6 review named as missing). `nil` synthesises one `.unknown`/`.unknown`
component from the scalar -- today's behavior exactly -- so all 42 existing
`scenarioRetirementDistributions` call sites, and both `stateTaxBreakdown` production call sites,
stay untouched. When supplied, components are pooled (summed) and the SAME pooled figure replaces
the scalar at the ONE place each function already used it (the age-gated `scenarioExemptable` /
`scenarioDistroExemptable` line) -- no exemption or cap logic runs per component. The sum invariant
(spec 3.4, `abs(total - scalar) <= 0.01`) traps via `assertionFailure` in debug and falls back to the
scalar with an observable flag in release, following the `StateTaxDataLoader.legacyFallbackFired`
precedent.

## Step 2: RED transcript (verbatim excerpt)

Full log: `/private/tmp/claude-501/-Users-johnurban-Projects-RetireSmartIRA/724cdf85-cd14-4a10-8c8d-c10fb1a36eb8/scratchpad/p3b-task3-red.log`
(387 lines; excerpted below -- first errors and the final failure banner, unedited).

```
Command line invocation:
    /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -scheme RetireSmartIRA -destination platform=macOS "-only-testing:RetireSmartIRATests/Phase3bDistributionComponentTests" "-only-testing:RetireSmartIRATests/Phase3bDistributionComponentMirrorTests"
...
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bDistributionComponentTests.swift:50:46: error: cannot find 'RetirementDistributionComponent' in scope
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bDistributionComponentTests.swift:50:45: error: extra argument 'distributionComponents' in call
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bDistributionComponentTests.swift:51:33: error: cannot infer contextual base in reference to member 'primary'
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bDistributionComponentTests.swift:51:54: error: cannot infer contextual base in reference to member 'unknown'
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bDistributionComponentTests.swift:51:72: error: cannot infer contextual base in reference to member 'unknown'
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bDistributionComponentTests.swift:74:13: error: cannot find 'RetirementDistributionComponent' in scope
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bDistributionComponentTests.swift:75:13: error: cannot find 'RetirementDistributionComponent' in scope
...
	Extra argument 'configOverride' in call
	Extra argument 'configOverride' in call
	Cannot find 'RetirementDistributionComponent' in scope
	Cannot find 'RetirementDistributionComponent' in scope
	Extra arguments at positions #3, #4 in call
	Cannot infer contextual base in reference to member 'primary'
	Cannot infer contextual base in reference to member 'unknown'
	Cannot infer contextual base in reference to member 'unknown'
	Testing cancelled because the build failed.

** TEST FAILED **


The following build commands failed:
	SwiftCompile normal arm64 /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bDistributionComponentTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	SwiftCompile normal arm64 Compiling\ Phase3bDistributionComponentTests.swift /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bDistributionComponentTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	Testing project RetireSmartIRA with scheme RetireSmartIRA
(3 failures)
```

Failed exactly as expected: the test file references `RetirementDistributionComponent` and the
`distributionComponents:`/`configOverride:` parameters before either exists. Not a typo, not an
existing-behavior false pass.

## Sum invariant: debug trap and release fallback, evidence kept separate

Both `assertionFailure` calls are real (not stubbed): calling the production entry point
(`resolvePooledAmount`, or any `calculateStateTax`/`stateTaxBreakdown` call) with a violating
components/scalar pair genuinely traps and aborts the process in this Debug test configuration --
confirmed for real during mutation testing below (a floating-point boundary slip in an earlier draft
of my own test tripped it unintentionally; see "Boundary lesson" below). Per the
`StateTaxDataLoader.resolveConfigs` precedent already in this codebase (`resolveConfigs` is "the
fallback-assignment logic extracted out of `configs2026`, specifically so it can be exercised without
triggering `configs2026`'s `assertionFailure`, which traps the test process by design"), the trap
itself is never called from a test. Two pure, non-trapping functions carry the same logic and ARE
called directly:

- **Debug-trap evidence** (`RetirementDistributionComponent.sumInvariantHolds`, the exact boolean
  `resolvePooledAmount` guards its trap on) -- `Phase3bDistributionComponentTests.sumInvariantBoundary`.
- **Release-fallback evidence** (`RetirementDistributionComponent.fallbackAmount`, the exact value
  production resolves to once `assertionFailure` has compiled to a no-op) --
  `Phase3bDistributionComponentTests.fallbackAmountUsesScalarWhenInvariantFails` (violating input ->
  scalar, not the wrong pooled total) and `fallbackAmountPoolsWhenInvariantHolds` (valid input -> pooled
  sum, so the fallback function is not just always-return-scalar).
- **Flag evidence** -- `fallbackFlagStaysFalseInNormalOperation` proves
  `sumInvariantFallbackFired == false` after exercising the real `resolvePooledAmount` with valid
  input. It is deliberately never set `true` from a test: doing so would permanently flip the shared,
  never-reset static flag for the remainder of a parallelised Swift Testing run, poisoning any other
  test that reads it -- the same reason `StateTaxDataLoader.legacyFallbackFired` is never set from a
  test either.

**Boundary lesson (kept in the report because it's real signal, not noise):** my first draft used an
exact one-cent literal (`40_000.01`) at the invariant boundary. `Double`'s binary representation of
`40_000.01` does not subtract to exactly `0.01`, so `sumInvariantHolds` returned `false` for what I
intended to be a passing case, and a later "prove the parameter is wired" test that used the same
one-cent slack against `calculateStateTax`/`stateTaxBreakdown` genuinely tripped the real
`assertionFailure` and crashed the test process (log evidence:
`RetirementDistributionComponent.swift:98: Fatal error: RetirementDistributionComponent amounts sum
to 10000.01, which does not agree with the scalar 10000.0 within one cent; falling back to the scalar
path.`). This is itself proof the debug trap works for real. I widened `sumInvariantBoundary` to
comfortably-inside (0.005) / comfortably-outside (0.02) values instead of the exact edge, and redesigned
the wiring-proof tests (below) to keep component amounts as whole dollars (exact in `Double`) and put
the fractional half-cent offset on the scalar side only, which avoids the same trap.

## Pooling, not per-component capping (spec 3.4a)

The pooling is a single `.reduce` over `components`, executed once, BEFORE the existing
`effectivePensionExemption.excludedAmount` / `effectiveIRAExemption.excludedAmount` calls, which are
otherwise byte-identical to before this task and are still called exactly once each (never inside a
per-component loop):

Engine, `RetireSmartIRA/TaxCalculationEngine.swift:644-648`:
```swift
let pooledScenarioDistribution = RetirementDistributionComponent.resolvePooledAmount(
    components: distributionComponents,
    scalar: scenarioRetirementDistributions
)
let scenarioExemptable = retirementAge ? pooledScenarioDistribution : 0
let iraIncome = rmdSourceIncome + scenarioExemptable
```

Mirror, `RetireSmartIRA/DataManager.swift:834-839`:
```swift
let pooledScenarioDistribution = RetirementDistributionComponent.resolvePooledAmount(
    components: distributionComponents,
    scalar: scenarioRetirementDistributionIncome
)
let scenarioDistroExemptable = retirementAge ? pooledScenarioDistribution : 0
let iraIncome = rmdSourceIncome + scenarioDistroExemptable
```

The pooling itself, `RetireSmartIRA/RetirementDistributionComponent.swift:105` (and identically inside
`fallbackAmount` at line 72): `components.reduce(0) { $0 + $1.amount }` -- one sum, handed to the
unchanged cap machinery downstream (`pensionAndIRAShareSingleCap` branch at
`TaxCalculationEngine.swift:628` onward is untouched by this task).

## Proving `distributionComponents` is actually consumed, not accepted-and-discarded

The sum invariant forces a *valid* components list to numerically equal the scalar within a cent, so a
test that only ever supplies invariant-satisfying components cannot, by itself, distinguish "pooled
correctly" from "silently ignored and the scalar path always ran" -- both produce the same number.
I confirmed this both ways by mutation:

- `singleUnknownComponentMatchesScalarAcrossStatesAndAges` (the grid-equivalence test Step 1 asks for)
  does **not** discriminate a "components silently ignored" mutation -- confirmed by mutating
  `TaxCalculationEngine.swift:645` to pass `components: nil` instead of `components:
  distributionComponents` and rerunning: that test still passed. This is expected and correct, not a
  gap: the invariant makes the two paths numerically identical by construction.
- `componentsAreActuallySummedNotSilentlyIgnored` (engine) and `mirrorPoolsComponentsIntoIRAExemptAmount`
  (mirror) close that gap. Both exploit the invariant's own half-cent slack: two components summing to
  a round `$10,000` (exact in `Double`, no fractional literals) against a scalar of `$9,999.995` -- half
  a cent off, comfortably inside the `<= 0.01` tolerance. With the same `nil`-components mutation
  applied to `TaxCalculationEngine.swift:645`, `componentsAreActuallySummedNotSilentlyIgnored` failed:
  ```
  ✘ Expectation failed: (abs(pooledTax - 5_000.0) → 0.004999999999199645) < 0.0001
  ✘ Expectation failed: (pooledTax → 5000.004999999999) != (scalarTax → 5000.004999999999)
  ```
  With the same mutation applied to `DataManager.swift:835`, `mirrorPoolsComponentsIntoIRAExemptAmount`
  failed identically. Both mutations were reverted after confirming failure; the full targeted suite
  (10/10) passed again afterward.
- `sumInvariantBoundary` was confirmed to discriminate by widening `sumInvariantHolds`'s tolerance from
  `<= 0.01` to `<= 1.0`: two assertions failed as expected (`40_000.02` and `39_999.98` both spuriously
  passed at the loosened tolerance). Reverted; suite green again.
- `fallbackAmountUsesScalarWhenInvariantFails` was confirmed to discriminate by changing
  `fallbackAmount` to unconditionally return the (wrong) pooled sum: it failed
  (`40000.0 == 40500` false). Reverted; suite green again.

## Capability documented, not activated

`componentOwnerDoesNotChangeAttributionInThisPhase` builds a synthetic `.perQualifyingSpouse` config
via `configOverride` (no jurisdiction ships that mode) and confirms a `.spouse`-owned component
produces the identical result to a `.primary`-owned one, for the exact primary-below-gate /
spouse-above-gate case `StateTaxPhase3aMechanismTests.scenarioDistributionsAreAttributedToThePrimary`
already pins for the bare scalar. This documents that `RetirementDistributionComponent.owner` exists
and the type compiles under an owner-sensitive config, without asserting it changes anything -- because
it must not, in this task.

## Step 5 grep (mirror sync)

```
$ grep -n "distributionComponents\|RetirementDistributionComponent" RetireSmartIRA/DataManager.swift
701:    ///   - distributionComponents: Phase 3b Task 3, mirroring
703:    ///     `RetirementDistributionComponent.resolvePooledAmount`, the same
711:        distributionComponents: [RetirementDistributionComponent]? = nil
828:        // Phase 3b Task 3: pool distributionComponents (or the synthesized
833:        // SAME RetirementDistributionComponent.resolvePooledAmount.
834:        let pooledScenarioDistribution = RetirementDistributionComponent.resolvePooledAmount(
835:            components: distributionComponents,
```

## Targeted runs

- `Phase3bDistributionComponentTests` + `Phase3bDistributionComponentMirrorTests`: 10/10 passed.
- `StateTaxBehaviorBaselineTests` (the frozen Phase 3a baseline, 51 jurisdictions x 20 scenarios): 1
  Swift Testing test with 51 parameterized cases, all passed -- baseline held all 1,020 values, untouched.
- `StateTaxConsistencyTests`, `StateTaxPhase3aMechanismTests`, `StateTaxCodableRoundTripTests`,
  `RothConversionWithholdingTests`, `MetamorphicPropertyTests`, `Phase3bClassificationTests`,
  `Phase3bPersistenceTests`: 116/116 passed, 7 suites.

## Full suite (run once, foreground, after all mutations reverted)

Ran via `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'` with output teed to
`/private/tmp/claude-501/-Users-johnurban-Projects-RetireSmartIRA/724cdf85-cd14-4a10-8c8d-c10fb1a36eb8/scratchpad/p3b-task3-fullsuite.log`.
Both summary lines, pasted verbatim from that log:

```
Test run with 1691 tests in 282 suites passed after 302.514 seconds.
```
```
	 Executed 503 tests, with 0 failures (0 unexpected) in 20.649 (21.009) seconds
Test Suite 'All tests' passed at 2026-08-03 15:35:20.761.
	 Executed 503 tests, with 0 failures (0 unexpected) in 20.649 (21.010) seconds
```
```
** TEST SUCCEEDED **
```

(Baseline at `3cf4d26` per the plan's Task 2 report was 1,657 Swift Testing / 278 suites + 503 XCTest;
Tasks 1-2's own suites plus this task's two new suites -- `Phase3bDistributionComponentTests`,
`Phase3bDistributionComponentMirrorTests` -- account for the growth to 1,691 / 282. 0 failures either
way.)

**Tree-confirmation grep** (proves the run above compiled and ran against this worktree, not another
checkout):
```
$ grep -m3 "\.xcodeproj" p3b-task3-fullsuite.log
    cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj
```

## git diff --stat

```
$ git diff --stat --cached
 RetireSmartIRA/DataManager.swift                                    |  36 ++-
 RetireSmartIRA/RetirementDistributionComponent.swift                | 107 +++++++
 RetireSmartIRA/TaxCalculationEngine.swift                           |  25 +-
 RetireSmartIRATests/Phase3bDistributionComponentTests.swift         | 341 +++++++++++++++++++++
 4 files changed, 505 insertions(+), 4 deletions(-)
```

No JSON under `Resources/StateTaxData/`, no view, no `ProjectionEngine.swift`, and no
`project.pbxproj` touched. No em dash characters in any line I added (checked with
`git diff --cached | grep '^+' | grep <em-dash>` against the two modified files, and a direct grep of
both new files -- both zero matches).

## Commit

Staged explicit paths only (`RetireSmartIRA/RetirementDistributionComponent.swift`,
`RetireSmartIRA/TaxCalculationEngine.swift`, `RetireSmartIRA/DataManager.swift`,
`RetireSmartIRATests/Phase3bDistributionComponentTests.swift`); no `git add -A`.
