# Task 2 report: State-aware distribution minimum age

Commit: `39fefbee91484602275eb5752a11a315b56188be`

## Step 2: RED transcript (verbatim)

Command:
```
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests 2>&1 | tail -60
```

Relevant portion of the output, pasted verbatim:

```
SwiftCompile normal arm64 Compiling\ StateTaxPhase3aMechanismTests.swift /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')

SwiftCompile normal arm64 /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
    cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a
    
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:52:37: error: extra argument 'distributionMinAge' in call
                distributionMinAge: 55))
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift:72:46: error: value of type 'RetirementIncomeExemptions' has no member 'distributionMinAge'
        #expect(RetirementIncomeExemptions().distributionMinAge == 59)
                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ^~~~~~~~~~~~~~~~~~

Failed frontend command:
[... swift-frontend invocation omitted here for length, present in full in the terminal scrollback; the two errors above are the operative output ...]

Test session results, code coverage, and logs:
	/Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Logs/Test/Test-RetireSmartIRA-2026.08.03_01-11-04--0700.xcresult

Testing failed:
	Extra argument 'distributionMinAge' in call
	Value of type 'RetirementIncomeExemptions' has no member 'distributionMinAge'
	Testing cancelled because the build failed.

** TEST FAILED **


The following build commands failed:
	SwiftCompile normal arm64 /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	SwiftCompile normal arm64 Compiling\ StateTaxPhase3aMechanismTests.swift /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	Testing project RetireSmartIRA with scheme RetireSmartIRA
(3 failures)
```

This matches the brief's expected failure exactly: `extra argument 'distributionMinAge' in call`, plus the corollary "has no member 'distributionMinAge'" from the second `#expect`. Not a typo, not an unrelated error: both failures are exactly "the field doesn't exist yet."

Note: the swift-frontend invocation line (a single very long command line reproduced in full in the actual terminal output) is omitted above only for report readability; nothing about the pass/fail outcome depends on it. The two `error:` lines and the final `(3 failures)` summary are pasted exactly as emitted.

## Step 3: field added

In `RetireSmartIRA/StateTaxData.swift`, inside `struct RetirementIncomeExemptions`, immediately after `regularExemptionMinAge` and before `earlyAgeTier`:

```swift
    /// Minimum age at which `scenarioRetirementDistributions` (RMDs computed
    /// from balances, inherited-IRA RMDs, and extra withdrawals) becomes
    /// eligible for the state's IRA exemption, and the fallback age used to
    /// decide whether a spouse qualifies when `regularExemptionMinAge` is 0.
    ///
    /// 59 reproduces the constant this replaced, which was hardcoded in
    /// `TaxCalculationEngine.applyRetirementExemptions` in two places and
    /// therefore unreachable from config. Iowa qualifies at 55 (HF 2317), so
    /// config alone could not fix Iowa while this was a literal. The value is
    /// 59 rather than 59.5 because the engine works in integer ages; that
    /// approximation predates this phase and is unchanged by it.
    ///
    /// Changed away from 59 only in Phase 5, gated by a golden scenario.
    var distributionMinAge: Int = 59
```

This is source-compatible with all existing construction sites because `RetirementIncomeExemptions` has no explicit init (implicit memberwise init only), verified before editing.

## Inventory of every `59` occurrence inside `applyRetirementExemptions`

Located the function at line 470 (`static func applyRetirementExemptions(`), spanning to line 701 (the next `static func` at line 703 is `calculateIRMAA`). Ran `sed -n '470,701p' RetireSmartIRA/TaxCalculationEngine.swift | grep -n "59"` against the pre-edit file. Six occurrences, each accounted for below:

1. **Line 499** (comment): "...this function applies a flat 59.5 baseline to `scenarioRetirementDistributions`, which is wrong for Iowa (qualifies at 55); and it cannot apply `pensionExemption` and..." — **This is the clause the brief's Step 4 instructs to delete.** Deleted the "applies a flat 59.5 baseline...wrong for Iowa (qualifies at 55); and" portion, kept the "it cannot apply `pensionExemption` and `iraWithdrawalExemption` independently, because `scenarioRetirementDistributions` is not split by source" portion (still true, Phase 3b's job). Exact before/after in the section below.

2. **Line 529** (comment, in the block above `func ageQualifiesForExemption`): "...States with no explicit age gate fall back to the 59½ statutory baseline used by NY § 612(c)(3-a) and most similar per-individual states." **Left unchanged.** This is a different comment block from the one the brief targets (that one sits directly above `var adjusted = income`; this one sits above `func ageQualifiesForExemption`). The brief's Step 4 scopes the deletion to "the comment block above `var adjusted = income`" only. This sentence also remains literally accurate: every state's config still defaults `distributionMinAge` to 59 in this task, so "fall back to the 59 statutory baseline" is still what happens when there is no explicit age gate. Not touched.

3. **Line 539** (code): `return age >= 59` inside `ageQualifiesForExemption`. **Changed** to `return age >= exemptions.distributionMinAge` per the brief's Step 4 instruction.

4. **Line 578** (comment, in the block above `rmdSourceIncome`): "...Age-gate the scenario portion at 59½ (early-withdrawal IRA distributions are taxable in PA and most states); user-entered `.rmd` rows are not gated because they implicitly represent retirement-age income." **Left unchanged.** Not the comment block the brief names (that one is above `var adjusted = income`), and it remains accurate today: no state's config moves `distributionMinAge` away from 59 in this task, so the scenario portion is still gated "at 59" in every live jurisdiction. Not in scope; not touched.

5. **Line 583** (code): `let retirementAge = primaryAge >= 59 || (enableSpouse && spouseAge >= 59)`. **Changed** to read `exemptions.distributionMinAge` on both sides, per the brief's Step 4 instruction.

6. **Line 674** (comment, in the Roth-conversion-exemption block): "...We therefore apply it independently of `scenarioRetirementDistributions`, which retains its 59½ gate for distributions." **Left unchanged.** Same reasoning as #2 and #4: different comment block, not named by the brief, and still accurate under the default.

Net: 2 of 6 occurrences were code and were changed (the two the brief specifies by line number, `:539` and `:583` pre-edit, matching the brief's stated `TaxCalculationEngine.swift:539` and `:583`). 1 of 6 was the one named comment clause, edited per instruction. The remaining 3 are separate, unnamed comments describing the same "59" default from different vantage points in the function; each is still literally true today (no jurisdiction has moved off the 59 default in this task), so none were touched, consistent with the brief scoping the comment edit to a single named block.

## Step 4: exact comment-block diff

Text deleted (was lines 498-502):
```
        // Still open and confirmed by the audit: this function applies a flat
        // 59.5 baseline to `scenarioRetirementDistributions`, which is wrong for
        // Iowa (qualifies at 55); and it cannot apply `pensionExemption` and
        // `iraWithdrawalExemption` independently, because
        // `scenarioRetirementDistributions` is not split by source.
```

Text kept (now lines 498-500):
```
        // Still open and confirmed by the audit: this function cannot apply
        // `pensionExemption` and `iraWithdrawalExemption` independently, because
        // `scenarioRetirementDistributions` is not split by source.
```

Removed only the clause that became false this step ("applies a flat 59.5 baseline to `scenarioRetirementDistributions`, which is wrong for Iowa (qualifies at 55)"). Kept the still-true clause about pension/IRA not being independently splittable by source (Phase 3b's job), re-joining it cleanly into "this function cannot apply..." so the sentence still parses.

## Step 5: Codable support

`RetireSmartIRA/StateTaxCodable.swift`, `extension RetirementIncomeExemptions: Codable`:
- Added `distributionMinAge` to `CodingKeys`, positioned after `regularExemptionMinAge` and before `earlyAgeTier`.
- Added `try c.encode(distributionMinAge, forKey: .distributionMinAge)` to `encode(to:)`, after the `regularExemptionMinAge` line.
- Added `distributionMinAge: try c.decodeIfPresent(Int.self, forKey: .distributionMinAge) ?? 59,` to `init(from:)`, in declaration order after `regularExemptionMinAge` and before `earlyAgeTier`.

## Step 6: GREEN transcript

Command:
```
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests 2>&1 | tail -25
```

Output (verbatim):
```
​◇ Test case passing 1 argument state → .newJersey to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .newMexico to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .newYork to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .northCarolina to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .northDakota to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .ohio to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .oklahoma to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .oregon to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .pennsylvania to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .rhodeIsland to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .southCarolina to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .southDakota to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .tennessee to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .texas to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .utah to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .vermont to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .virginia to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .washington to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .westVirginia to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .wisconsin to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​◇ Test case passing 1 argument state → .wyoming to "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" started.
​✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.047 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.047 seconds.
◇ Suite "Phase 3a mechanisms are load-bearing" started.
◇ Test "distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59" started.
✔ Test "distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59" passed after 0.001 seconds.
◇ Test "distributionMinAge defaults to 59, reproducing the previous hardcoded gate" started.
✔ Test "distributionMinAge defaults to 59, reproducing the previous hardcoded gate" passed after 0.001 seconds.
✔ Suite "Phase 3a mechanisms are load-bearing" passed after 0.001 seconds.
✔ Test run with 3 tests in 2 suites passed after 0.048 seconds.
2026-08-03 01:12:41.897 xcodebuild[75188:8471701] [MT] IDETestOperationsObserverDebug: 1.953 elapsed -- Testing started completed.
2026-08-03 01:12:41.897 xcodebuild[75188:8471701] [MT] IDETestOperationsObserverDebug: 0.000 sec, +0.000 sec -- start
2026-08-03 01:12:41.897 xcodebuild[75188:8471701] [MT] IDETestOperationsObserverDebug: 1.953 sec, +1.953 sec -- end

Test session results, code coverage, and logs:
	/Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Logs/Test/Test-RetireSmartIRA-2026.08.03_01-12-16--0700.xcresult

** TEST SUCCEEDED **

Testing started
```

Both PASS: `StateTaxBehaviorBaselineTests` ("PHASE 3a GATE: state tax behavior baseline" suite) passed with its single parameterized test executing all 51 jurisdiction test cases; `StateTaxPhase3aMechanismTests` ("Phase 3a mechanisms are load-bearing" suite) passed both of its 2 tests. `Test run with 3 tests in 2 suites passed` (2 mechanism tests + 1 baseline test, the baseline test itself fanning out to 51 parameterized cases).

## Step 7: full suite result

Command:
```
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/phase3a-task2.log | tail -40
```
(actual tee target used: `/private/tmp/claude-501/-Users-johnurban-Projects-RetireSmartIRA/724cdf85-cd14-4a10-8c8d-c10fb1a36eb8/scratchpad/phase3a-task2.log`, this session's scratchpad directory, in place of `/tmp`)

Swift Testing summary line (verbatim):
```
✔ Test run with 1624 tests in 278 suites passed after 277.820 seconds.
```

XCTest summary lines (verbatim):
```
	 Executed 503 tests, with 0 failures (0 unexpected) in 19.302 (19.616) seconds
Test Suite 'All tests' passed at 2026-08-03 01:13:15.927.
	 Executed 503 tests, with 0 failures (0 unexpected) in 19.302 (19.617) seconds
```

Final result: `** TEST SUCCEEDED **`.

Tree-confirmation grep:
```
$ grep -c "worktrees/state-tax-phase3a" /private/tmp/claude-501/-Users-johnurban-Projects-RetireSmartIRA/724cdf85-cd14-4a10-8c8d-c10fb1a36eb8/scratchpad/phase3a-task2.log
10
```
Non-zero, confirms the run built and tested against `.worktrees/state-tax-phase3a`, not the main repo root.

Both target suites also confirmed present and green inside the full run (not just the scoped run in Step 6):
```
◇ Suite "PHASE 3a GATE: state tax behavior baseline" started.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.042 seconds.
◇ Suite "Phase 3a mechanisms are load-bearing" started.
✔ Suite "Phase 3a mechanisms are load-bearing" passed after 0.005 seconds.
```

## Behavior baseline confirmation

`StateTaxBehaviorBaselineTests` PASSED, in both the scoped run (Step 6) and the full suite (Step 7). Case count: 51 jurisdiction test cases (one parameterized `@Test` fanning out over `USState.allCases`, 51 states/DC-equivalent count as asserted by the suite's own size guards), each internally iterating its 20-scenario baseline grid (51 x 20 = 1020 frozen values, per the suite's own `#expect(baseline.count == USState.allCases.count * Self.scenarios.count, ...)` and `#expect(Self.scenarios.count == 20, ...)` assertions). No scenario in that file was edited, no baseline JSON was regenerated, and the grid-size guard assertions were not touched. This is the inertness proof: all 1020 frozen state-tax values are unmoved by adding the configurable `distributionMinAge` field defaulted to 59.

## git diff --stat

```
$ git show --stat HEAD
commit 39fefbee91484602275eb5752a11a315b56188be
Author: johnqp801 <john.urban@me.com>
Date:   Mon Aug 3 01:18:48 2026 -0700

    feat(state-tax): make the distribution age gate configurable, defaulting to 59

 RetireSmartIRA/StateTaxCodable.swift               |  4 +-
 RetireSmartIRA/StateTaxData.swift                  | 15 +++++
 RetireSmartIRA/TaxCalculationEngine.swift          | 11 ++--
 .../StateTaxPhase3aMechanismTests.swift            | 74 ++++++++++++++++++++++
 4 files changed, 97 insertions(+), 7 deletions(-)
```

## Constraints honored

- `RetireSmartIRA.xcodeproj/project.pbxproj` not touched (`git diff --stat -- RetireSmartIRA.xcodeproj/project.pbxproj RetireSmartIRA/ProjectionEngine.swift` produced no output). The project uses Xcode 16 `PBXFileSystemSynchronizedRootGroup` file groups, confirmed by grep before creating the new test file, so the new `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift` file was picked up automatically without a pbxproj edit.
- `RetireSmartIRA/ProjectionEngine.swift` not touched (same diff-stat check).
- No em dash characters in any changed file, checked with `grep "—"` against the diff and the new test file (both zero matches).
- No state's tax parameters changed; `StateTaxData.swift`'s 45 existing `RetirementIncomeExemptions(...)` construction sites are unaffected because the type has no explicit init (implicit memberwise init only) and the new field carries a default. New York's `regularExemptionMinAge: 59` in `StateTaxData.swift` was not touched; that is a state data value, unrelated to the engine constant this task addresses.
- 51 bundled JSON files under `RetireSmartIRA/Resources/StateTaxData/2026/` were not regenerated; the decoder's `?? 59` fallback (Step 5) makes this safe, matching how `regularExemptionMinAge` already handles the same situation for its own key.

## Review fixes

A reviewer mutation-tested the `distributionMinAge` read inside the nested
`ageQualifiesForExemption(_:)` in `RetireSmartIRA/TaxCalculationEngine.swift`
(the fallback branch used when `regularExemptionMinAge == 0`) and found no
existing test caught a hardcoded-`59` mutant there. That call site is only
reached via `bothSpousesQualify`, which requires `enableSpouse: true`, and
every existing mechanism test used `enableSpouse: false`.

### Fix 1 — added a discriminating test

Added `distributionMinAgeGatesPerIndividualDoubling()` to
`RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`. It builds a
synthetic Iowa-shaped config with `exemptionAppliesPerIndividual: true`,
`regularExemptionMinAge` left at its default 0 (so the fallback branch runs),
and a `$20,000` partial pension cap, then compares tax owed for a
56-year-old vs 60-year-old spouse under a 55-gate config and a 59-gate
config, with `enableSpouse: true`.

### Fix 2 — corrected an overclaiming comment

`distributionMinAgeIsHonored()`'s age-60 assertion pair previously claimed
in a comment that it was "what stops the first pair from passing for the
wrong reason." The reviewer's mutation analysis found the age-56 pair alone
already discriminates that case and could construct no mutant caught by the
age-60 pair but missed by the age-56 pair. Replaced the comment with
accurate wording (that pair documents the boundary shape; it doesn't add
discriminating power).

### Step 2 — mechanism suite green after the fixes

`-only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests`, all 3 tests
passed, including the new one, before any mutation was introduced.

### Step 3 — proof the new test discriminates

Temporarily reverted the production line in
`RetireSmartIRA/TaxCalculationEngine.swift`:

```
-            return age >= exemptions.distributionMinAge
+            return age >= 59
```

Re-ran `-only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests`.
Pasted failure output:

```
◇ Suite "Phase 3a mechanisms are load-bearing" started.
◇ Test "distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59" started.
✔ Test "distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59" passed after 0.001 seconds.
◇ Test "distributionMinAge defaults to 59, reproducing the previous hardcoded gate" started.
✔ Test "distributionMinAge defaults to 59, reproducing the previous hardcoded gate" passed after 0.001 seconds.
◇ Test "distributionMinAge also gates per-individual cap doubling, not only scenario distributions" started.
✘ Test "distributionMinAge also gates per-individual cap doubling, not only scenario distributions" recorded an issue at StateTaxPhase3aMechanismTests.swift:107:9: Expectation failed: (tax(config: config(distributionMinAge: 55), spouseAge: 56) → 2000.0) == (0 → 0.0)
↳ // Spouse is 56. Under a 55 gate BOTH spouses qualify, the cap doubles
↳ // to 40,000 and the whole pension is excluded. Under the default 59
↳ // gate the spouse does not qualify, the cap stays 20,000, and 20,000
↳ // remains taxable at 10 percent.
✘ Test "distributionMinAge also gates per-individual cap doubling, not only scenario distributions" failed after 0.001 seconds with 1 issue.
✘ Suite "Phase 3a mechanisms are load-bearing" failed after 0.001 seconds with 1 issue.
✘ Test run with 3 tests in 1 suite failed after 0.001 seconds with 1 issue.

Failing tests:
	StateTaxPhase3aMechanismTests.distributionMinAgeGatesPerIndividualDoubling()

** TEST FAILED **
```

The new test failed exactly as predicted: under the hardcoded-59 mutant,
`config(distributionMinAge: 55)` at `spouseAge: 56` produced `2000.0`
(spouse doesn't qualify under a hardcoded 59, so the cap never doubles)
instead of the expected `0` (spouse should qualify under the 55-gate
config), correctly diagnosing that the config's `distributionMinAge` was
being ignored. The other two pre-existing tests stayed green, confirming
the mutant only breaks the new, previously-unguarded path.

Restored the production line and confirmed the tree is clean:

```
$ git diff RetireSmartIRA/TaxCalculationEngine.swift | wc -l
       0
```

Re-ran the mechanism suite after restoring; all 3 tests passed again
(same output as Step 2).

### Step 4 — baseline suite still green

`-only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests`:

```
✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.047 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.047 seconds.
✔ Test run with 1 test in 1 suite passed after 0.047 seconds.
** TEST SUCCEEDED **
```

All 51 jurisdictions matched the frozen baseline (1,020 frozen values,
per-jurisdiction subtests within the single parameterized `@Test`).
`RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift` and
`RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json` were
not touched.

### Step 5 — full suite

Ran the full suite (`xcodebuild test -project RetireSmartIRA.xcodeproj
-scheme RetireSmartIRA -destination 'platform=macOS'`) from
`.worktrees/state-tax-phase3a`. Both summary lines:

```
Swift Testing: ✔ Test run with 1625 tests in 278 suites passed after 280.751 seconds.
XCTest:        Test Suite 'All tests' passed at 2026-08-03 01:38:16.132.
                	 Executed 503 tests, with 0 failures (0 unexpected) in 20.344 (20.511) seconds
```

`** TEST SUCCEEDED **`.

Worktree/xcodeproj confirmation (grepped from the build log before trusting
any result):

```
$ grep -o "worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj" /tmp/p3a-task2fix.log | head -1
worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
$ grep -m1 "cd /Users/johnurban.*RetireSmartIRA.xcodeproj" /tmp/p3a-task2fix.log
    cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
```

### Constraints honored (review-fix pass)

- `RetireSmartIRA.xcodeproj/project.pbxproj` not touched.
- `RetireSmartIRA/ProjectionEngine.swift` not touched.
- No em dash characters introduced.
- `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift` and
  `RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json` not
  touched; baseline stayed green.
- The Step 3 production-code revert was temporary; `TaxCalculationEngine.swift`
  is unchanged in the final commit (`git diff` against HEAD~1 for that file
  is empty).

### Commit

```
cf680ce test(state-tax): guard the distributionMinAge read that governs per-individual doubling
```
