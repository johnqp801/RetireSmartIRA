# Task 3 report: `personalExemption` as a first-class field

Status: **DONE_WITH_CONCERNS**
Commit: `85c996f` on `feature/state-tax-phase3a`
Worktree: `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a`

## Summary

Implemented `StatePersonalExemption` (new file), added `StateTaxConfig.personalExemption`
(optional, default nil), added Codable support (`encodeIfPresent` / `decodeIfPresent`),
gave New Jersey's legacy Swift table entry its value, moved both `DataManager.swift` call
sites onto the config, and turned `TaxCalculationEngine.njPersonalExemptions` into a
delegating shim.

**One deviation from the brief's literal Step 6/7 code, made deliberately and documented
below**: both DataManager call sites and the shim read `config.personalExemption ??
StateTaxData.configs2026Legacy[state]?.personalExemption` rather than
`config.personalExemption` alone. Reasoning and evidence in "The discovery" section.

**Two tests remain red**, both attributable to a single, understood cause (New Jersey's
bundled JSON does not carry the `personalExemption` key until Task 8 regenerates that
file, and I was instructed not to touch the 51 bundled JSON files). Detail below.

Everything the task named as load-bearing holds:
- The 1,020-value behavior baseline: **green, untouched.**
- `NJOtherExclusionAndExemptionsTests` (the "real guard"): **green, all 9 tests.**
- `GoldenScenarioCrossPathTests` pins, single-year 42.0 and multi-year
  200.40469973890345: **both hold.**
- `ProjectionEngine.swift`: **untouched** (confirmed by `git diff --stat`, not in the
  changed-file list).
- No other state gained a personal exemption (confirmed by the mechanism suite's own
  `onlyNewJerseyCarriesAPersonalExemptionInPhase3a`, partially, see below).

---

## The discovery: JSON vs. legacy divergence, and why the brief's literal code breaks 3 things

`TaxCalculationEngine.njPersonalExemptions` was fully hardcoded arithmetic before this
task, independent of any config lookup. The brief's Step 7 shim, and the brief's Step 6
DataManager edits, both route through `StateTaxData.config(for:)`, which (per Phase 1,
already in place before this task) resolves via `StateTaxDataLoader.configs2026`, which is
**bundled JSON**, not the legacy Swift table, for any state whose JSON file loads
successfully. New Jersey's bundled JSON (`RetireSmartIRA/Resources/StateTaxData/2026/
statetax-2026-NJ.json`) loads successfully; it just does not have a `personalExemption`
key (confirmed by inspection: its top-level keys are exactly the pre-Phase-3a 13, none
named `personalExemption`). Per the brief's own text and this branch's ledger
(`.claude/memory/roadmap/2026-08-03-state-tax-phase3a-ledger.md`), that key is added and
NJ's file regenerated in **Task 8**, not Task 3, and I was hard-constrained not to touch
any of the 51 bundled JSON files in Task 3.

Consequence: implementing Step 6/7 **exactly as the brief specifies** (`config
.personalExemption` / `StateTaxData.config(for: .newJersey).personalExemption`, with no
fallback) compiles and passes the baseline, but breaks three things, because all three
resolve New Jersey's config through the JSON loader:

1. All 4 `NJOtherExclusionAndExemptionsTests` personal-exemption tests: the shim now
   returns `0.0` instead of `1000/2000/4000` (empirically confirmed, transcript below).
2. `GoldenScenarioCrossPathTests.newJerseyCrossPathGapPinnedAsObserved`: the single-year
   pin moved from 42.0 to 14.0 (`abs(single - 42.0) → 28.0`), because
   `GoldenScenarioSingleYearTests.singleYearStateTax` calls the shim directly.
3. My own Step 1 mechanism test `onlyNewJerseyCarriesAPersonalExemptionInPhase3a`: this
   one specifically, unavoidably, since it inspects `StateTaxDataLoader.load(taxYear:
   2026)`'s output directly.

(1) and (2) are exactly the tests the outer task instructions named as the load-bearing
"real guards," and instruction 7 explicitly required confirming the cross-path pins hold.
Silently accepting a $0 New Jersey exemption in the two real DataManager production call
sites is also a computed-tax regression, which the phase's own ledger states as an
explicit contract: "BEHAVIOR-INERT. No computed tax value changes, any state, scenario,
filing status or age. A moved number is a defect in the change that moved it."

**Fix applied**: both DataManager call sites and the shim now read `config
.personalExemption ?? StateTaxData.configs2026Legacy[state]?.personalExemption`. This
resolves (1) and (2) without touching any JSON file (verified below). It cannot resolve
(3), because that test bypasses DataManager and the shim entirely and reads the JSON
loader's decoded output directly. There is no code-only fix for that one without either
touching NJ's bundled JSON (prohibited) or changing what the test asserts (which I did
not do, since the brief specifies its code verbatim and it is testing the intended
end-state correctly, just one task early).

**A second, pre-existing test also went red** for the identical root cause, discovered
only when running the full suite (Step 9): `StateTaxJSONStructuralEquivalenceTests
.structurallyIdentical(state: .newJersey)` (Phase 1's "Layer B" gate, not in my Files
list, not touched). It re-encodes the JSON-loaded and legacy-loaded configs for each
state and requires byte-identical output. Since NJ's legacy config now carries
`personalExemption` and NJ's JSON-loaded config does not, the two diverge, correctly:
this gate is doing exactly its documented job (catching decode/JSON drift), and it is
correctly reporting that Task 3 has NOT yet closed that drift for New Jersey (Task 8
does). Isolated to New Jersey only; all other 50 jurisdictions pass:

```
✘ Test "Re-encoding the JSON-loaded config is byte-identical to re-encoding the legacy
  config" recorded an issue with 1 argument state → .newJersey at
  StateTaxJSONEquivalenceTests.swift:560:9: Expectation failed: (jsonEncoded → 3413
  bytes) == (legacyEncoded → 3560 bytes)
  First divergence: line 11: JSON=["pretax401kContributionsTaxableForState" : false,]
  LEGACY=["personalExemption" : {]
```

Both red tests point at the same, single, well-understood cause and both resolve
automatically once Task 8 regenerates New Jersey's bundled JSON file with the
`personalExemption` key. I did not attempt to work around either by touching JSON, per
the hard constraint, and did not weaken either test's assertion.

---

## Step 2: RED transcript, verbatim

The brief's Step 1 test code as given contained a Swift syntax defect unrelated to
`StatePersonalExemption`: a plain (non-triple-quoted) string literal cannot use
backslash-newline continuation across multiple lines in Swift (that is a C convention,
not Swift's). I fixed only that syntax (converted to a triple-quoted literal, identical
wording) so the RED signal reflects the intended failure (missing type) rather than an
unrelated parser error. First attempt, showing the syntax defect:

```
                                                                                         ^
	Unterminated string literal
                        "\(state.abbreviation) gained a personal exemption in Phase 3a. \
                        ^
	'a' is not a valid digit in integer literal
...
	Testing cancelled because the build failed.
** TEST FAILED **
```

After that one syntax fix, the real RED transcript (`tail -30`, pasted verbatim):

```
Test session results, code coverage, and logs:
	/Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Logs/Test/Test-RetireSmartIRA-2026.08.03_01-54-41--0700.xcresult

Testing failed:
	Cannot find 'StatePersonalExemption' in scope
	Cannot infer contextual base in reference to member 'single'
	Cannot infer contextual base in reference to member 'single'
	Cannot infer contextual base in reference to member 'marriedFilingJointly'
	Cannot infer contextual base in reference to member 'marriedFilingJointly'
	Cannot infer contextual base in reference to member 'marriedFilingJointly'
	Cannot infer contextual base in reference to member 'marriedFilingJointly'
	Cannot infer contextual base in reference to member 'marriedFilingJointly'
	Cannot find 'StatePersonalExemption' in scope
	Cannot infer contextual base in reference to member 'single'
	Cannot infer contextual base in reference to member 'marriedFilingJointly'
	Value of type 'StateTaxConfig' has no member 'personalExemption'
	Value of type 'StateTaxConfig' has no member 'personalExemption'
	Testing cancelled because the build failed.

** TEST FAILED **

The following build commands failed:
	SwiftCompile normal arm64 /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	SwiftCompile normal arm64 Compiling\ StateTaxPhase3aMechanismTests.swift /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	Testing project RetireSmartIRA with scheme RetireSmartIRA
(3 failures)
```

This is exactly the expected signal: "Cannot find 'StatePersonalExemption' in scope" and
"Value of type 'StateTaxConfig' has no member 'personalExemption'."

---

## Step 8: GREEN transcript

First attempt, using the brief's literal Step 6/7 code (before the Legacy-fallback fix),
for the record. This is the RED result that led to the discovery above:

```
✘ Test "New Jersey's config carries the personal exemption; no other state does"
  recorded an issue at StateTaxPhase3aMechanismTests.swift:175:17: Expectation failed:
  (config.personalExemption → nil) != nil
Failing tests:
	GoldenScenarioCrossPathTests.newJerseyCrossPathGapPinnedAsObserved()
	NJOtherExclusionAndExemptionsTests.personalExemptionsMFJSenior()
	NJOtherExclusionAndExemptionsTests.personalExemptionsSingleSenior()
	NJOtherExclusionAndExemptionsTests.personalExemptionsSingleUnder65()
	NJOtherExclusionAndExemptionsTests.personalExemptionsMFJUnder65()
	StateTaxPhase3aMechanismTests.onlyNewJerseyCarriesAPersonalExemptionInPhase3a()
```

Detail from that first attempt (values, not just names):

```
✘ Test "PINNED, New Jersey single-year vs multi-year: two components, I2 is the smaller
  one" recorded an issue at GoldenScenarioCrossPathTests.swift:151:9: Expectation
  failed: (abs(single - 42.0) → 28.0) < 0.01
✘ Test "NJ personal exemptions: MFJ 65+ → $4,000" recorded an issue at
  NJOtherExclusionAndExemptionsTests.swift:129:9: Expectation failed:
  (amt → 0.0) == (4_000 → 4000.0)
✘ Test "NJ personal exemptions: single 65+ → $2,000" recorded an issue at
  NJOtherExclusionAndExemptionsTests.swift:136:9: Expectation failed:
  (amt → 0.0) == (2_000 → 2000.0)
✘ Test "NJ personal exemptions: single under 65 → $1,000" recorded an issue at
  NJOtherExclusionAndExemptionsTests.swift:143:9: Expectation failed:
  (amt → 0.0) == (1_000 → 1000.0)
✘ Test "NJ personal exemptions: MFJ both under 65 → $2,000" recorded an issue at
  NJOtherExclusionAndExemptionsTests.swift:150:9: Expectation failed:
  (amt → 0.0) == (2_000 → 2000.0)
```

**After applying the Legacy-fallback fix** to both DataManager call sites and the shim,
re-running the exact Step 8 command:

```
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests -only-testing:RetireSmartIRATests/NJOtherExclusionAndExemptionsTests -only-testing:RetireSmartIRATests/GoldenScenarioCrossPathTests
```

```
◇ Test run started.
◇ Suite "Golden scenarios, cross-path agreement" started.
​✔ Test "Both engine entry points report the same state tax" with 3 test cases passed after 0.003 seconds.
✔ Test "PINNED, New Jersey single-year vs multi-year: two components, I2 is the smaller one" passed after 0.001 seconds.
✔ Suite "Golden scenarios, cross-path agreement" passed after 0.004 seconds.
◇ Suite "NJ Worksheet D other-income exclusion + personal exemptions" started.
✔ Test "MFJ, $30K pension + $60K dividends, total $90K → all sheltered → $0" passed after 0.001 seconds.
✔ Test "MFJ, $30K pension + $100K dividends, total $130K → taxable $97,500" passed after 0.001 seconds.
✔ Test "MFJ, $30K pension + $90K dividends + $10K wages, total $130K → no Worksheet D" passed after 0.001 seconds.
✔ Test "MFJ, $50K dividends + $100K pension, total $150K → taxable $112,500" passed after 0.001 seconds.
✔ Test "MFJ, pension $120K, total $125K → exclusion $60,000 (cap-after-percent fix)" passed after 0.001 seconds.
✔ Test "NJ personal exemptions: MFJ 65+ → $4,000" passed after 0.001 seconds.
✔ Test "NJ personal exemptions: single 65+ → $2,000" passed after 0.001 seconds.
✔ Test "NJ personal exemptions: single under 65 → $1,000" passed after 0.001 seconds.
✔ Test "NJ personal exemptions: MFJ both under 65 → $2,000" passed after 0.001 seconds.
✔ Suite "NJ Worksheet D other-income exclusion + personal exemptions" passed after 0.002 seconds.
◇ Suite "PHASE 3a GATE: state tax behavior baseline" started.
​✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.041 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.041 seconds.
◇ Suite "Phase 3a mechanisms are load-bearing" started.
✔ Test "distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59" passed after 0.001 seconds.
✔ Test "distributionMinAge defaults to 59, reproducing the previous hardcoded gate" passed after 0.001 seconds.
✔ Test "distributionMinAge also gates per-individual cap doubling, not only scenario distributions" passed after 0.001 seconds.
✔ Test "StatePersonalExemption reproduces New Jersey's four documented outcomes" passed after 0.001 seconds.
✔ Test "A filer on MFJ with no spouse configured gets the single amounts" passed after 0.001 seconds.
✔ Test "Only one spouse over the senior age gets exactly one senior addition" passed after 0.001 seconds.
✔ Test "A state with no senior addition ignores age entirely" passed after 0.001 seconds.
✘ Test "New Jersey's config carries the personal exemption; no other state does" recorded an issue at StateTaxPhase3aMechanismTests.swift:175:17: Expectation failed: (config.personalExemption → nil) != nil
✘ Test "New Jersey's config carries the personal exemption; no other state does" failed after 0.002 seconds with 1 issue.
✘ Suite "Phase 3a mechanisms are load-bearing" failed after 0.003 seconds with 1 issue.
✘ Test run with 20 tests in 4 suites failed after 0.058 seconds with 1 issue.
Failing tests:
	StateTaxPhase3aMechanismTests.onlyNewJerseyCarriesAPersonalExemptionInPhase3a()
```

19 of 20 tests in this run pass. The one failure is the JSON-loader-dependent assertion
discussed above (Task 8 dependency), reproduced in isolation and explained, not silently
worked around.

---

## Step 9: full suite

```
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/phase3a-task3.log | tail -40
```

Both summary lines, pasted verbatim from the log:

```
	 Executed 503 tests, with 0 failures (0 unexpected) in 19.424 (19.749) seconds
Test Suite 'All tests' passed at 2026-08-03 02:09:28.676.
	 Executed 503 tests, with 0 failures (0 unexpected) in 19.424 (19.749) seconds
```

```
✘ Test run with 1630 tests in 278 suites failed after 277.440 seconds with 2 issues.
```

```
Failing tests:
	-[StateTaxJSONStructuralEquivalenceTests structurallyIdentical(state:)]
	StateTaxPhase3aMechanismTests.onlyNewJerseyCarriesAPersonalExemptionInPhase3a()
```

Both failures trace to the single cause documented above (New Jersey's bundled JSON not
yet carrying `personalExemption`, deferred to Task 8), confirmed for
`structurallyIdentical` to be isolated to New Jersey only, all other 50 jurisdictions
pass:

```
​◇ Test case passing 1 argument state → .newJersey to "Re-encoding the JSON-loaded
  config is byte-identical to re-encoding the legacy config" started.
✘ Test "Re-encoding the JSON-loaded config is byte-identical to re-encoding the legacy
  config" recorded an issue with 1 argument state → .newJersey at
  StateTaxJSONEquivalenceTests.swift:560:9: Expectation failed:
  (jsonEncoded → 3413 bytes) == (legacyEncoded → 3560 bytes)
  First divergence: line 11: JSON=["pretax401kContributionsTaxableForState" : false,]
  LEGACY=["personalExemption" : {]
```

Tree-confirmation grep, showing the tested `.xcodeproj` is the correct worktree, plus
`pwd`/branch confirmation:

```
$ grep -m 3 "\.xcodeproj" /tmp/phase3a-task3.log
    cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj

$ pwd
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a

$ git branch --show-current
feature/state-tax-phase3a
```

XCTest legacy suite (503 tests) is fully green. Swift Testing suite (1,630 tests, up
from 1,625 before this task's 6 new mechanism tests minus 1 accounting difference,
1,625 + 6 - 1 net = 1,630, consistent with Task 2's recorded count of 1,625) has exactly
2 known, explained, single-root-cause failures.

---

## Both DataManager call sites: exact before and after

### Site 1 (was line 659-671, `calculateStateTaxFromGross`)

Before:

```swift
        // NJ has no standard deduction but grants personal exemptions ($1,000
        // regular per filer + $1,000 per filer 65+). These reduce taxable
        // income AFTER the retirement exclusions/phaseout (which gate on total
        // income), so they are passed as `postExemptionDeduction` rather than
        // subtracted from the phaseout gate here. Other states return 0.
        let njExemptions = state == .newJersey
            ? TaxCalculationEngine.njPersonalExemptions(
                filingStatus: filingStatus, enableSpouse: enableSpouse,
                primaryAge: currentAge, spouseAge: spouseCurrentAge)
            : 0

        let stateTaxableIncome = max(0, adjustedGross - stateDeduction)
        return calculateStateTax(income: stateTaxableIncome, forState: state, filingStatus: filingStatus, taxableSocialSecurity: taxableSocialSecurity, scenarioRetirementDistributions: scenarioRetirementDistributions, scenarioRothConversionAmount: scenarioRothConversionAmount, scenarioRothConversionWithholdingAmount: scenarioRothConversionWithholdingAmount, postExemptionDeduction: njExemptions)
    }
```

After:

```swift
        // Personal exemptions reduce taxable income AFTER the retirement
        // exclusions and their income-gated phaseouts, so they are passed as
        // `postExemptionDeduction` rather than subtracted from the phaseout
        // gate here. States with no personal exemption return 0.
        //
        // Prefers config.personalExemption (bundled JSON); New Jersey's
        // shipped JSON does not carry the key until Task 8 regenerates that
        // file, so this falls back to the legacy Swift table, which already
        // carries NJ's value as of this task, so New Jersey's exemption does
        // not silently regress to $0 in the interim.
        let statePersonalExemption = (config.personalExemption
            ?? StateTaxData.configs2026Legacy[state]?.personalExemption)?.amount(
            filingStatus: filingStatus, enableSpouse: enableSpouse,
            primaryAge: currentAge, spouseAge: spouseCurrentAge) ?? 0

        let stateTaxableIncome = max(0, adjustedGross - stateDeduction)
        return calculateStateTax(income: stateTaxableIncome, forState: state, filingStatus: filingStatus, taxableSocialSecurity: taxableSocialSecurity, scenarioRetirementDistributions: scenarioRetirementDistributions, scenarioRothConversionAmount: scenarioRothConversionAmount, scenarioRothConversionWithholdingAmount: scenarioRothConversionWithholdingAmount, postExemptionDeduction: statePersonalExemption)
    }
```

Variable names confirmed at this site before editing: `currentAge`, `spouseCurrentAge`,
`filingStatus`, `enableSpouse` (the last two are function parameters of
`calculateStateTaxFromGross`; the first two are class-scoped computed properties
`var currentAge: Int { profile.currentAge }` / `var spouseCurrentAge: Int
{ profile.spouseCurrentAge }`). `config` was already in scope from
`let config = StateTaxData.config(for: state)` earlier in the same function.

### Site 2 (was line 902-911, `stateTaxBreakdown`)

Before:

```swift
        // NJ personal exemptions ($1,000 regular per filer + $1,000 per filer
        // 65+). Applied AFTER the retirement exclusions (consistent with the
        // engine's `postExemptionDeduction`). Other states: 0.
        let njPersonalExemptionAmt = state == .newJersey
            ? TaxCalculationEngine.njPersonalExemptions(
                filingStatus: filingStatus, enableSpouse: enableSpouse,
                primaryAge: currentAge, spouseAge: spouseCurrentAge)
            : 0

        let adjustedIncome = max(0, income - totalExempted - njPersonalExemptionAmt)
```

After:

```swift
        // Personal exemptions reduce taxable income AFTER the retirement
        // exclusions and their income-gated phaseouts, so they are passed as
        // `postExemptionDeduction` rather than subtracted from the phaseout
        // gate here. States with no personal exemption return 0.
        //
        // Prefers config.personalExemption (bundled JSON); New Jersey's
        // shipped JSON does not carry the key until Task 8 regenerates that
        // file, so this falls back to the legacy Swift table, which already
        // carries NJ's value as of this task, so New Jersey's exemption does
        // not silently regress to $0 in the interim.
        let statePersonalExemption = (config.personalExemption
            ?? StateTaxData.configs2026Legacy[state]?.personalExemption)?.amount(
            filingStatus: filingStatus, enableSpouse: enableSpouse,
            primaryAge: currentAge, spouseAge: spouseCurrentAge) ?? 0

        let adjustedIncome = max(0, income - totalExempted - statePersonalExemption)
```

Variable names at this site were checked independently rather than assumed identical
to site 1: `stateTaxBreakdown(forState state: USState, filingStatus: FilingStatus)`
takes `state` and `filingStatus` as its own parameters; `currentAge` and
`spouseCurrentAge` resolve to the same class-scoped computed properties as site 1 (there
is only one such property pair in `DataManager`, used throughout the class); `enableSpouse`
resolves to the same class-scoped computed property. They turned out identical to site 1
in this repo state, but this was verified, not assumed, per the brief's own caution that
they "may differ."

Both sites' `config` local (`let config = StateTaxData.config(for: state)`) was already
in scope before my edit, confirmed by reading the surrounding ~50 lines of each function
before editing.

---

## `git diff --stat`

```
 RetireSmartIRA/DataManager.swift                   | 52 +++++++++-------
 RetireSmartIRA/StatePersonalExemption.swift        | 53 ++++++++++++++++
 RetireSmartIRA/StateTaxCodable.swift               |  6 +-
 RetireSmartIRA/StateTaxData.swift                  | 19 +++++-
 RetireSmartIRA/TaxCalculationEngine.swift          | 26 +++++---
 .../StateTaxPhase3aMechanismTests.swift            | 70 ++++++++++++++++++++++
 6 files changed, 195 insertions(+), 31 deletions(-)
```

(`RetireSmartIRA/StatePersonalExemption.swift` is a new file; git renders its diff stat
against `/dev/null`, so it is included in the total above.)

No JSON file, no baseline file (`Baselines/statetax-behavior-baseline-2026.json`,
`StateTaxBehaviorBaselineTests.swift`), no `ProjectionEngine.swift`, and no
`.xcodeproj` file appears in this diff.

---

## Cross-path pins: confirmed unchanged

```
◇ Suite "Golden scenarios, cross-path agreement" started.
​✔ Test "Both engine entry points report the same state tax" with 3 test cases passed after 0.007 seconds.
◇ Test "PINNED, New Jersey single-year vs multi-year: two components, I2 is the smaller one" started.
✔ Test "PINNED, New Jersey single-year vs multi-year: two components, I2 is the smaller one" passed after 0.001 seconds.
✔ Suite "Golden scenarios, cross-path agreement" passed after 0.008 seconds.
✔ Test run with 2 tests in 1 suite passed after 0.008 seconds.
```

Single-year 42.0 and multi-year 200.40469973890345 both hold. `ProjectionEngine.swift`
was not touched (confirmed absent from `git diff --stat` above), so the multi-year path
is provably unaffected regardless of the pin holding.

---

## Concerns for the next reviewer / Task 8

1. **Two tests are red for one understood, documented reason.** New Jersey's bundled
   JSON (`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json`) does not
   carry the `personalExemption` key. Task 8 (per the brief's own text and this branch's
   ledger) regenerates that file. Once it does, both
   `StateTaxPhase3aMechanismTests.onlyNewJerseyCarriesAPersonalExemptionInPhase3a` and
   `StateTaxJSONStructuralEquivalenceTests.structurallyIdentical(state: .newJersey)`
   should go green with no further code change, since both DataManager call sites and
   the shim already prefer `config.personalExemption` (the JSON path) and only fall back
   to legacy when it is absent.
2. **I deviated from the brief's literal Step 6/7 code** by adding the
   `?? StateTaxData.configs2026Legacy[state]?.personalExemption` fallback. Without it,
   New Jersey's personal exemption silently drops to $0 in both real DataManager
   production call sites and in the compatibility shim, between this task and Task 8.
   That is a genuine computed-tax regression for New Jersey filers, which the phase's own
   ledger states as an explicit non-goal ("BEHAVIOR-INERT... A moved number is a defect").
   I verified this empirically (transcripts above) before deciding to deviate, rather
   than assuming it from reading code alone.
3. This is worth a line in `.claude/memory/roadmap/2026-08-03-state-tax-phase3a-ledger.md`
   under a Task 3 entry (matching the Task 1/2 entries' style), which I have not
   added myself since it was not in my explicit file list for this task and the
   worktree's ledger is shared/controller-owned per the Task 2 entry's process note.

---

## Regeneration fix

Status: **DONE**
Commit: `8ae4fd7` on `feature/state-tax-phase3a` (worktree
`/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a`)

This follow-up removes the legacy fallback documented above as "Concern 2" and replaces
it with the correct fix: regenerate the 51 bundled JSON files so New Jersey's
`personalExemption` is genuinely present in the shipped data, per the process note in
`7b85689` ("tasks that add non-default legacy values must regenerate their own JSON").

### 1. Legacy fallbacks removed

Both `DataManager.swift` call sites (`calculateStateTaxFromGross`, line ~669, and the
personal-exemption read inside the retirement-exemptions path, line ~919) and the
`TaxCalculationEngine.njPersonalExemptions` shim (line ~472) were reverted to read
`config.personalExemption` alone, with the interim "falls back to legacy until Task 8"
comment blocks removed. Both DataManager call sites use `self.currentAge` /
`self.spouseCurrentAge` (instance properties backed by `profile.currentAge` /
`profile.spouseCurrentAge`); there is no local-parameter name divergence between the two
sites, contrary to the brief's caution to check.

Confirming grep, run after the edits:

```
$ grep -n "configs2026Legacy" RetireSmartIRA/DataManager.swift RetireSmartIRA/TaxCalculationEngine.swift
(no output, exit code 1)
```

### 2. Layer C split into required + optional top-level keys

`RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`'s `StateTaxJSONFileKeyCompletenessTests`
suite now has `requiredTopLevelKeys` (the original 13) plus `optionalTopLevelKeys =
["personalExemption"]`, and two tests: `topLevelKeysAreCompleteAndKnown` (per-state,
required-present + no-unknown-keys) and `onlyNewJerseyShipsAPersonalExemptionKey`
(exactly one carrier, NJ). Both green (51 + 1 test cases).

### 3. Regeneration

```
TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests ENABLE_APP_SANDBOX=NO
```
`** TEST SUCCEEDED **`, "Generate all 51 jurisdiction files" passed. Confirmed via
`.xcodeproj` path in the build log: `.../worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj`.

### 4. Diff review

Deletion check:
```
$ git diff --numstat RetireSmartIRA/Resources/StateTaxData/2026/ | awk '$2 != 0 {print "DELETION in " $3}'
(no output)
```
`git diff --stat` for the 51 files: `51 files changed, 57 insertions(+)` before staging
(0 deletions). Only NJ's file contains `"personalExemption"` in the diff (grep-confirmed
against the full directory diff).

Full New Jersey diff (as committed in `8ae4fd7`):
```diff
diff --git a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json
index de8f076..38de255 100644
--- a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json
+++ b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NJ.json
@@ -9,9 +9,16 @@
   },
   "hsaContributionsTaxableForState" : true,
   "otherPreTaxDeductionsTaxableForState" : false,
+  "personalExemption" : {
+    "marriedFilingJointly" : 2000,
+    "seniorAdditionalPerFiler" : 1000,
+    "seniorAge" : 65,
+    "single" : 1000
+  },
   "pretax401kContributionsTaxableForState" : false,
   "retirementExemptions" : {
     "capitalGainsTreatment" : "followsFederal",
+    "distributionMinAge" : 59,
     "exemptionAppliesPerIndividual" : false,
     "iraWithdrawalExemption" : {
       "kind" : "steppedPhaseoutByFilingStatus",
```

Full Kansas diff (as committed in `8ae4fd7`), representative of the other 49 files that
gained only `distributionMinAge`:
```diff
diff --git a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
index 1a7d783..53e6068 100644
--- a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
+++ b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
@@ -12,6 +12,7 @@
   "pretax401kContributionsTaxableForState" : false,
   "retirementExemptions" : {
     "capitalGainsTreatment" : "followsFederal",
+    "distributionMinAge" : 59,
     "exemptionAppliesPerIndividual" : false,
     "iraWithdrawalExemption" : {
       "kind" : "none"
```

### 5. Determinism

Ran the generator a second time (after the first regeneration, before staging) and a
third time (after staging/committing, to re-verify): each time `git status --short` line
count for the JSON directory stayed at 51 modified files with the identical diff stat
(`51 files changed, 57 insertions(+)`, 0 deletions each run). No random/nondeterministic
field (e.g., a UUID) was rewritten on any regeneration pass.

### 6. Test results (all in the foreground, `.xcodeproj` path confirmed as
`.../worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj` in each log)

- `StateTaxPhase3aMechanismTests`: 8/8 passed, including
  `onlyNewJerseyCarriesAPersonalExemptionInPhase3a` ("New Jersey's config carries the
  personal exemption; no other state does") -- **GREEN** (was red at HEAD before this
  fix).
- `StateTaxBehaviorBaselineTests`: "Every jurisdiction and scenario matches the frozen
  pre-Phase-3a baseline" with 51 test cases (1,020 frozen values) passed -- unmoved.
- `StateTaxJSONEquivalenceTests` (Layer A): "Every jurisdiction computes identical state
  tax from JSON and from the legacy table" with 51 test cases passed.
- `StateTaxJSONStructuralEquivalenceTests` (Layer B): "Re-encoding the JSON-loaded config
  is byte-identical to re-encoding the legacy config" with 51 test cases passed,
  including `.newJersey` -- **GREEN** (was red at HEAD before this fix).
- `StateTaxJSONFileKeyCompletenessTests` (Layer C, rewritten): both
  `topLevelKeysAreCompleteAndKnown` (51 cases) and
  `onlyNewJerseyShipsAPersonalExemptionKey` passed.
- `NJOtherExclusionAndExemptionsTests`: 9/9 passed.
- `GoldenScenarioCrossPathTests`: "Both engine entry points report the same state tax"
  (3 cases) and "PINNED, New Jersey single-year vs multi-year: two components, I2 is the
  smaller one" both passed -- single-year 42.0 and multi-year 200.40469973890345 both
  hold.

Full suite (`xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`),
run in the foreground with an extended timeout, log at `/tmp/p3a-task3fix.log`:

- Swift Testing summary line: `Test run with 1631 tests in 278 suites passed after
  280.876 seconds.`
- XCTest summary: `Test Suite 'All tests' passed at 2026-08-03 02:30:47.009.`, with the
  XCTest-hosted suite itself reporting `Executed 503 tests, with 0 failures (0
  unexpected) in 20.212 (20.398) seconds.`
- `** TEST SUCCEEDED **`
- `.xcodeproj` path confirmed in the log:
  `worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj`.

### 7. Commit

```
$ git add <54 explicit paths: DataManager.swift, TaxCalculationEngine.swift,
  StateTaxJSONEquivalenceTests.swift, and all 51 statetax-2026-*.json files>
$ git commit -m "fix(state-tax): regenerate the JSON so New Jersey's exemption is data, not a legacy fallback"
[feature/state-tax-phase3a 8ae4fd7] fix(state-tax): regenerate the JSON so New Jersey's exemption is data, not a legacy fallback
 54 files changed, 92 insertions(+), 48 deletions(-)
```

No `git add -A` / `git add .` used; each of the 54 paths (previously listed by `git diff
--name-only`, which matched exactly what this task touched, no stray edits from other
agents in the shared worktree) was staged explicitly.

Concern 2 from the original Task 3 report is now resolved. Concern 1 (the two red tests)
is resolved. Concern 3 (a ledger entry) remains outstanding and is still not mine to add
per the same reasoning as before.

## Review fixes

Commit: `f193c54` on `feature/state-tax-phase3a`

Three findings from the Task 3 review, all applied:

**Fix 1 (Important).** `GoldenScenarioSingleYearTests.singleYearStateTax` was still doing
`state == .newJersey ? TaxCalculationEngine.njPersonalExemptions(...) : 0`, the exact
hardcoded branch Task 3 removed from production. Replaced with
`StateTaxData.config(for: state).personalExemption?.amount(...) ?? 0`, matching what
`DataManager` now does at both call sites. Updated the doc comment above the function to
stop describing the deleted mechanism. Left the "both sides agree by being wrong the same
way" sentence intact, since it is the reason for the fix.

**Fix 2 (Minor).** Added `newJerseyConfigExemptionValuesArePinned` to
`StateTaxPhase3aMechanismTests.swift`, pinning New Jersey's shipped config
(`single: 1_000, marriedFilingJointly: 2_000, seniorAdditionalPerFiler: 1_000,
seniorAge: 65`) against the loaded JSON via `StateTaxDataLoader.load`, not against the
hand-built `njExemption` fixture the existing tests use. Without it, `seniorAge` could
have been anywhere from 62 to 65 and every existing NJ test still passed.

**Fix 3 (docs).** Corrected the Task 3 Interfaces line in
`docs/superpowers/plans/2026-08-03-state-tax-phase3a-schema-extensions.md` (was: "Task 8
adds its key to Layer C's optional set and regenerates NJ's file with it", which is false
since Task 3 did both, per the plan correction already in that same document).

### Fix 1 discrimination evidence

Temporarily added `personalExemption: StatePersonalExemption(single: 9_160,
marriedFilingJointly: 18_320, seniorAdditionalPerFiler: 0, seniorAge: 65)` to Kansas's
entry in `RetireSmartIRA/StateTaxData.swift`, then regenerated the bundled JSON with
`TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA -destination
'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests
ENABLE_APP_SANDBOX=NO` (test succeeded, and `statetax-2026-KS.json` gained a
`personalExemption` block, confirming `StateTaxData.config(for:)`, which resolves
through the bundled JSON, now sees it).

Added a throwaway Swift Testing file (`RetireSmartIRATests/ZZZThrowawayKansasDiscriminationTest.swift`,
picked up automatically since the test target uses Xcode's file-system-synchronized
groups, no pbxproj edit needed), ran only that suite, and captured printed values:

- OLD helper logic (`state == .newJersey ? njPersonalExemptions(...) : 0`) for Kansas,
  single, age 70: `0.0`, invisible to the Kansas exemption.
- NEW helper (`StateTaxData.config(for: .kansas).personalExemption?.amount(...)`) for the
  same inputs: `9160.0`, sees it.
- `singleYearStateTax(scenario, state: .kansas)` on a real PA-fixture-shaped scenario with
  the NEW helper: `4423.472`, versus the same call forced to `postExemptionDeduction: 0`
  (what the OLD helper would have produced for a non-NJ state): `4934.6`. The two differ,
  confirming the fix changes `singleYearStateTax`'s actual output for a state that gains
  an exemption, not just an isolated helper call.

All three assertions in the throwaway suite passed. Ran this as an actual test suite
(not just a printed value) because it also exercises `singleYearStateTax` itself, not
only the `config(for:)` lookup.

Reverted completely: deleted the throwaway test file, then `git checkout --
RetireSmartIRA/Resources/StateTaxData/2026/ RetireSmartIRA/StateTaxData.swift` to restore
both the legacy Swift table and all 51 JSON files to their committed state. Confirmed
with `git status --short` immediately after the revert:

```
 M RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
 M RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift
 M docs/superpowers/plans/2026-08-03-state-tax-phase3a-schema-extensions.md
```

No JSON file and no Swift file left modified beyond the three intended fixes. Kansas's
config carries no `personalExemption` on this branch; that correction is Phase 5a's,
gated by a golden scenario, per the note already in `StatePersonalExemption.swift`'s doc
comment and in `StateTaxPhase3aMechanismTests.personalExemptionWithoutSeniorTierIgnoresAge`.

### Test results, all in the foreground

- `StateTaxPhase3aMechanismTests`: 9/9 passed, including the new
  `newJerseyConfigExemptionValuesArePinned`.
- `GoldenScenarioSingleYearTests`: 1 test, 4 cases (PA/IL/MS/NJ), all passed.
- `GoldenScenarioCrossPathTests`: 2/2 passed. Pins confirmed unchanged in source:
  `single - 42.0` and `multi - 200.40469973890345` (both `newJerseyCrossPathGapPinnedAsObserved`
  and "Both engine entry points report the same state tax" green).
- `StateTaxBehaviorBaselineTests`: 51/51 jurisdiction cases passed (the 1,020-value
  baseline, unmoved).
- `NJOtherExclusionAndExemptionsTests`: 9/9 passed.
- Full suite (`xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`, run
  in the foreground with an explicit 600s timeout to avoid auto-backgrounding):
  - Swift Testing summary line: `Test run with 1632 tests in 278 suites passed after
    279.273 seconds.`
  - XCTest summary line: `Executed 503 tests, with 0 failures (0 unexpected) in 20.318
    (20.499) seconds.`
  - `** TEST SUCCEEDED **`
  - `.xcodeproj` path confirmed in the log: `.../worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj`.

### Commit

```
$ git add RetireSmartIRATests/GoldenScenarioSingleYearTests.swift \
    RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift \
    docs/superpowers/plans/2026-08-03-state-tax-phase3a-schema-extensions.md
$ git commit -m "test(state-tax): stop the golden runner mirroring a deleted hardcoded state check"
[feature/state-tax-phase3a f193c54] test(state-tax): stop the golden runner mirroring a deleted hardcoded state check
 3 files changed, 30 insertions(+), 12 deletions(-)
```

No `git add -A` / `git add .` used. `git status --short` after the commit showed a clean
tree.
