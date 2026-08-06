# Mirror-sync report: agiPhaseout + perQualifyingSpouse attribution

Branch `feature/state-tax-phase3a`, worktree
`/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a`.
Starting HEAD `6d2764a1893916741ad3b67e7f675f560d3ebadf`.

## What was fixed

1. **Fix 1** - `DataManager.stateTaxBreakdown`'s mirror did not apply
   `exemptions.agiPhaseout` anywhere. Added the same
   `exemptions.agiPhaseout?.reduced(exclusion:totalGrossIncome:isMarried:) ?? raw`
   call at all three points the engine applies it: the shared-cap branch
   (`combinedExempt`) and the per-type branch (`pensionExemptAmt`,
   `iraExemptAmt`), passing the same `income` and `isMarried` values the
   engine passes.
2. **Fix 2** - the mirror hardcoded the `.household` OR-form for the
   `retirementAge` scalar gate regardless of `exemptions.exemptionAttribution`.
   Replaced with the same exhaustive switch the engine uses
   (`TaxCalculationEngine.swift:603-624`), including the
   `.perQualifyingSpouse` case's AND-conjunction
   (`currentAge >= distributionMinAge && ageQualifiesForExemption(currentAge)`).
3. **Fix 3 (docs only)** - added the COMPOSITION, NOT YET VERIFIED block to
   `AGIPhaseout`'s type doc comment in `RetireSmartIRA/StateAGIPhaseout.swift`,
   documenting that the per-type branch applies the phase-out independently to
   pension and IRA, double-deducting the same excess income.
4. **Fix 4** - added `everyStateShipsDistributionMinAge59` to
   `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`, matching the
   style of `noStateShipsAnAGIPhaseoutKey` / `everyStateShipsHouseholdAttribution`.

## Experiment 1a - Fix 1 (agiPhaseout)

Edited Georgia's shipped JSON
(`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json`) to add:

```json
"agiPhaseout" : {
  "thresholdSingle" : 10000,
  "thresholdMFJ" : 20000,
  "shape" : { "kind" : "cliff" }
}
```

Ran `-only-testing:RetireSmartIRATests/StateTaxBreakdownTests` (the suite is
declared as `@MainActor struct StateTaxBreakdownTests` inside
`RetireSmartIRATests/RetireSmartIRATests.swift`; there is no separate
`StateTaxBreakdownTests.swift` file).

**With Fix 1 applied:** all 6 tests in the suite passed, including
`breakdownMatchesCalculation`.

**With Fix 1 temporarily reverted** (GA JSON left in place): the suite failed
with the exact reviewer-reported numbers:

```
✘ Test "Breakdown totalStateTax matches calculateStateTaxFromGross for all states" recorded an issue at RetireSmartIRATests.swift:1491:13: Expectation failed: isClose((bd.totalStateTax → 161.70000000000002), (calcTax → 3665.2000000000003))
↳ Breakdown mismatch for Georgia: breakdown=161.70000000000002 vs calc=3665.2000000000003
```

Fix 1 re-applied, GA JSON restored:

```
$ git checkout -- RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json
$ git status --short RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json
(no output) -- RESTORED CLEAN
```

## Experiment 1b - Fix 2 (perQualifyingSpouse)

The task's suggested filter,
`-only-testing:RetireSmartIRATests/RetireSmartIRATests/StateTaxTests/breakdownMatchesCalculationBelowTheDistributionAgeGate`,
did not resolve (0 tests executed both times it was tried) - the suite is
actually named `StateTaxBreakdownTests`, not `StateTaxTests`. Fell back to
`-only-testing:RetireSmartIRATests/StateTaxBreakdownTests` per the task's own
escape hatch.

Set GA's `exemptionAttribution` to `"perQualifyingSpouse"` and ran that suite.
**Both with and without Fix 2, all 6 existing tests passed unchanged** -
`breakdownMatchesCalculationBelowTheDistributionAgeGate` uses
`makeDM(birthYear: 2026-56, state: .california)`: single filer, no spouse,
looped over every state. For Georgia specifically this does NOT discriminate
Fix 2, because Georgia's `regularExemptionMinAge` is 65 and `effectiveAge`
(56, no spouse) never reaches it, so `resolveLevel` returns `.none` and the
whole exemption is zero regardless of which attribution branch runs - the same
masking effect documented in the new Fix-4 test's comment about New York.

To get a genuine discriminator, matching the reviewer's own reproduction
(primary 56, spouse 70, $40,000 extra withdrawal - spouse 70 pushes
`effectiveAge` to 70, past GA's regularExemptionMinAge of 65, so the exemption
level is live and the retirementAge scalar actually matters), a temporary test
was added to `StateTaxBreakdownTests` in `RetireSmartIRATests.swift`:

```swift
@Test("TEMP: perQualifyingSpouse mismatch reproduction for GA, primary 56 spouse 70")
func tempReproPerQualifyingSpouseGA() {
    let dm = makeDM(birthYear: 2026 - 56, filingStatus: .marriedFilingJointly, state: .georgia)
    dm.enableSpouse = true
    var c = DateComponents(); c.year = 2026 - 70; c.month = 1; c.day = 1
    dm.spouseBirthDate = Calendar.current.date(from: c)!
    dm.yourExtraWithdrawal = 40_000
    let grossIncome = dm.scenarioGrossIncome
    let taxableSS = dm.scenarioTaxableSocialSecurity
    let scenarioDistributions = dm.scenarioRetirementDistributionIncome
    #expect(scenarioDistributions > 0)
    let bd = dm.stateTaxBreakdown(forState: .georgia, filingStatus: .marriedFilingJointly)
    let calcTax = dm.calculateStateTaxFromGross(grossIncome: grossIncome, forState: .georgia, filingStatus: .marriedFilingJointly, taxableSocialSecurity: taxableSS, scenarioRetirementDistributions: scenarioDistributions)
    #expect(isClose(bd.totalStateTax, calcTax), "breakdown=\(bd.totalStateTax) vs calc=\(calcTax)")
}
```

**With Fix 2 reverted:**

```
✘ Test "TEMP: perQualifyingSpouse mismatch reproduction for GA, primary 56 spouse 70" recorded an issue at RetireSmartIRATests.swift:1543:9: Expectation failed: isClose((bd.totalStateTax → 0.0), (calcTax → 862.4000000000001))
↳ breakdown=0.0 vs calc=862.4000000000001
```

Same qualitative failure the reviewer reported (mirror reports 0.0, engine
reports a nonzero tax) - exact magnitude differs because the reproduction's
income composition is not identical to the reviewer's undisclosed setup, but
the divergence mechanism is the same one Fix 2 targets.

**With Fix 2 re-applied:** the temp test passed
(`✔ ... passed after 0.001 seconds`).

Cleanup:

```
$ git diff --stat RetireSmartIRATests/RetireSmartIRATests.swift
(no output)   -- temp test fully removed, matches original
$ git checkout -- RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json
$ git status --short RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json RetireSmartIRATests/RetireSmartIRATests.swift
(no output) -- RESTORED CLEAN
```

## Experiment 2 - Fix 4 discrimination

Changed Ohio's shipped `distributionMinAge` from 59 to 55 in
`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-OH.json`. Ran
`-only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests`:

```
✘ Test "Every jurisdiction ships distributionMinAge as 59 in Phase 3a" recorded an issue at StateTaxPhase3aMechanismTests.swift:530:9: Expectation failed: (wrong → ["OH"]).isEmpty → false
↳ Iowa moves to 55 in Phase 5a, gated by a golden scenario. Found wrong or missing: ["OH"]
```

Test fails and correctly names Ohio. Restored:

```
$ git checkout -- RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-OH.json
$ git status --short RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-OH.json
(no output) -- RESTORED CLEAN
```

## Targeted suite run (step 4)

```
$ xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' \
    -only-testing:RetireSmartIRATests/StateTaxBreakdownTests \
    -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests \
    -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests \
    -only-testing:RetireSmartIRATests/MetamorphicPropertyTests \
    ENABLE_APP_SANDBOX=NO
```

```
◇ Suite "Metamorphic property tests (1.8.4)" started.
✔ Suite "Metamorphic property tests (1.8.4)" passed after 0.064 seconds.
◇ Suite "State Tax — Breakdown Detail" started.
✔ Suite "State Tax — Breakdown Detail" passed after 0.013 seconds.
◇ Suite "PHASE 3a GATE: state tax behavior baseline" started.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.042 seconds.
◇ Suite "Phase 3a mechanisms are load-bearing" started.
✔ Suite "Phase 3a mechanisms are load-bearing" passed after 0.017 seconds.
✔ Test run with 57 tests in 4 suites passed after 0.137 seconds.
```

`.xcodeproj` path confirmed against this worktree:
`cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj`.

The behavior baseline (`StateTaxBehaviorBaselineTests`, 51 jurisdictions x
scenarios) held with no changes - both fixes are inert against every shipped
config, as expected.

## Regeneration diff (step 5)

```
$ TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA \
    -destination 'platform=macOS' \
    -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests \
    ENABLE_APP_SANDBOX=NO
✔ Test "Generate all 51 jurisdiction files" passed after 0.006 seconds.

$ git status --short RetireSmartIRA/Resources/StateTaxData/2026/
(no output) -- diff is EMPTY
```

## Full suite (step 6, run once, foreground)

`.xcodeproj` path confirmed: `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj`.

Two summary lines:

```
Test Suite 'RetireSmartIRATests.xctest' passed at 2026-08-03 11:41:12.927.
	 Executed 503 tests, with 0 failures (0 unexpected) in 20.902 (21.078) seconds
```

```
✔ Test run with 1657 tests in 278 suites passed after 296.695 seconds.
```

`** TEST SUCCEEDED **`. Total 2,160 tests (503 XCTest + 1,657 Swift Testing),
0 failures.

## Final state

```
$ git status --short
 M RetireSmartIRA/DataManager.swift
 M RetireSmartIRA/StateAGIPhaseout.swift
 M RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift
```

Only the three intended files changed. No em dash characters were introduced
in any new/edited line (verified via a UTF-8 em-dash grep restricted to the
diff's `+` lines). `RetireSmartIRA.xcodeproj/project.pbxproj`,
`RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift`,
`Baselines/statetax-behavior-baseline-2026.json`, and
`RetireSmartIRA/ProjectionEngine.swift` were not touched. No state's shipped
tax parameters changed permanently (every JSON edit above was reverted via
`git checkout --` and confirmed clean before moving on).

Commit: `fix(state-tax): sync the breakdown mirror for agiPhaseout and per-spouse attribution`
