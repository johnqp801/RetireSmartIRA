# State Tax Phase 3a — Phase Gate Report (Task 8 + Task 9)

Run date: 2026-08-03
Worktree: /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a
Branch: feature/state-tax-phase3a
HEAD at start of gate: 6b4311b6855c6235b3246994e39ffef2163c3c29 (confirmed matches expected)

## STATUS: BLOCKED — hard constraint violated (em dash characters introduced by this branch)

Steps 1-6 were executed as specified. Step 5's em-dash check failed: this branch
introduces new lines containing the em dash character in two files
(`RetireSmartIRA/DataManager.swift` and `RetireSmartIRATests/RetireSmartIRATests.swift`).
Per the explicit HARD CONSTRAINT ("No em dash characters anywhere") and the
instruction to STOP and report rather than attempt a fix, Step 7 (commit) was
NOT executed. The Step 1 comment correction was made and verified free of
em dashes, but was left uncommitted pending direction, since Step 7 as written
assumes a clean gate.

---

## STEP 1 — Comment correction in StateTaxCodableRoundTripTests.swift

Replaced the false claim (that `personalExemptionSeniorIsPerFiler` behaviorally
backstops the single/seniorAdditionalPerFiler pigeonhole gap) with the corrected
text supplied. Comment-only change, verified against surrounding indentation.
Confirmed no em dash character in the new text:

```
$ grep -n $'—' RetireSmartIRATests/StateTaxCodableRoundTripTests.swift
(no output)
```

Resulting block (lines ~548-572):

```swift
                single: 1_000, marriedFilingJointly: 2_000,
                seniorAdditionalPerFiler: 1_000, seniorAge: 65))
        let present = try #require(try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(withExemption)) as? [String: Any])
        let exemption = try #require(present["personalExemption"] as? [String: Any])
        // marriedFilingJointly (2_000) and seniorAge (65) are each unique
        // values in this fixture, so a swap involving either is visible.
        // single and seniorAdditionalPerFiler are BOTH 1_000 here, so a swap
        // between those two specifically would produce byte-identical JSON --
        // this test alone cannot tell them apart (the same pigeonhole
        // argument retirementExemptionsBooleanKeysAreMutuallyDistinguishable
        // and stateTaxConfigBooleanKeysAreMutuallyDistinguishable make above
        // for same-valued Bool fields, here for two same-valued Doubles).
        // The single and seniorAdditionalPerFiler values are both 1,000, so a
        // CodingKeys swap between them would be invisible here. Nothing in the
        // suite currently backstops that, and an earlier version of this
        // comment wrongly claimed personalExemptionSeniorIsPerFiler did: that
        // test builds the type directly and calls amount(...), never touching
        // JSONEncoder. newJerseyConfigExemptionValuesArePinned has the same
        // blind spot, since New Jersey's real values are also 1,000 and 1,000.
        // No swap bug is possible today because StatePersonalExemption's
        // Codable conformance is entirely compiler-synthesized. If anyone
        // hand-writes an encoder for it, matching what this phase did for
        // AGIPhaseout and StateTaxSystem, give this fixture distinct values
        // first.
        #expect(exemption["single"] as? Double == 1_000)
        #expect(exemption["marriedFilingJointly"] as? Double == 2_000)
        #expect(exemption["seniorAdditionalPerFiler"] as? Double == 1_000)
```

NOT committed yet (see Step 7 / status above).

---

## STEP 2 — Regeneration determinism (Task 8)

### Run 1

```
$ TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA \
    -destination 'platform=macOS' \
    -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests \
    ENABLE_APP_SANDBOX=NO
...
◇ Test run started.
↳ Testing Library Version: 1902
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite "State tax JSON generator (manual)" started.
◇ Test "Generate all 51 jurisdiction files" started.
✔ Test "Generate all 51 jurisdiction files" passed after 0.006 seconds.
✔ Suite "State tax JSON generator (manual)" passed after 0.006 seconds.
✔ Test run with 1 test in 1 suite passed after 0.006 seconds.
...
** TEST SUCCEEDED **
```

```
$ git status --short RetireSmartIRA/Resources/StateTaxData/2026/
(no output)
```

### Run 2 (re-run to confirm determinism)

```
$ TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA \
    -destination 'platform=macOS' \
    -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests \
    ENABLE_APP_SANDBOX=NO
...
◇ Test run started.
◇ Suite "State tax JSON generator (manual)" started.
◇ Test "Generate all 51 jurisdiction files" started.
✔ Test "Generate all 51 jurisdiction files" passed after 0.005 seconds.
✔ Suite "State tax JSON generator (manual)" passed after 0.005 seconds.
✔ Test run with 1 test in 1 suite passed after 0.005 seconds.
...
** TEST SUCCEEDED **
```

```
$ git status --short RetireSmartIRA/Resources/StateTaxData/2026/
(no output)
```

**Result: PASS.** Both runs produced an empty diff. Regeneration is deterministic
and every earlier task that changed encoder output already regenerated the 51
JSON files correctly.

---

## STEP 3 — macOS suite (full, foreground)

```
$ xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/p3a-gate.log | tail -40
...
✔ Test run with 1656 tests in 278 suites passed after 291.248 seconds.
...
** TEST SUCCEEDED **
```

xcodeproj path confirmation:

```
$ grep -o "worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj" /tmp/p3a-gate.log | head -1
worktrees/state-tax-phase3a/RetireSmartIRA.xcodeproj
```

Summary lines:

```
Swift Testing: Test run with 1656 tests in 278 suites passed after 291.248 seconds.
XCTest:        Executed 503 tests, with 0 failures (0 unexpected) in 19.597 (19.908) seconds
```

**Result: PASS. 0 failures.**

---

## STEP 4 — iOS build + bundling check

```
$ xcodebuild build -scheme RetireSmartIRA -destination 'generic/platform=iOS' 2>&1 | tail -20
...
RegisterExecutionPolicyException .../Debug-iphoneos/RetireSmartIRA.app ...
Validate .../Debug-iphoneos/RetireSmartIRA.app ...
Touch .../Debug-iphoneos/RetireSmartIRA.app ...

** BUILD SUCCEEDED **
```

```
$ command find ~/Library/Developer/Xcode/DerivedData -name "RetireSmartIRA.app" \
    -path "*iphoneos*" -newermt '-45 minutes' \
    -exec sh -c 'echo "$1"; ls "$1" | grep -c "^statetax-2026-"' _ {} \;
/Users/johnurban/Library/Developer/Xcode/DerivedData/RetireSmartIRA-bpayrrxoupdfwrcajhptqydviwze/Build/Products/Debug-iphoneos/RetireSmartIRA.app
51
```

**Result: PASS.** iOS build succeeded; all 51 statetax-2026-*.json files are
bundled into the built .app.

(Note: this environment's default `find` is aliased/shadowed to `bfs`, which
does not accept `-newermt '-45 minutes'` relative syntax. Used `command find`
to invoke the real BSD find; this is a tooling workaround, not a deviation
from the check itself.)

---

## STEP 5 — Untouched-scope + em-dash checks

```
$ git diff main --stat -- RetireSmartIRA.xcodeproj/project.pbxproj
(no output)

$ git diff main --stat -- RetireSmartIRA/ProjectionEngine.swift
(no output)

$ git diff main -- RetireSmartIRATests/GoldenScenarioCrossPathTests.swift
(no output)
```

All three EMPTY as required. `ProjectionEngine.swift` untouched confirms
backlog item I2 is still open, and `GoldenScenarioCrossPathTests.swift` still
pins the observed single-year 42.0 / multi-year 200.40469973890345 divergence,
unmodified by Phase 3a.

### Em dash check

```
$ git diff main --name-only -- '*.swift' '*.json' | while read f; do [ -f "$f" ] && grep -l $'—' "$f"; done
RetireSmartIRA/DataManager.swift
RetireSmartIRA/StateTaxData.swift
RetireSmartIRA/TaxCalculationEngine.swift
RetireSmartIRATests/MetamorphicPropertyTests.swift
RetireSmartIRATests/RetireSmartIRATests.swift
```

**Result: FAIL as literally specified** (expected no output; got 5 files).

Investigation to separate pre-existing/unchanged content from content this
branch actually added (`git diff main -- <file> | grep '^+' | grep em-dash`):

- `RetireSmartIRA/StateTaxData.swift` — matches are all pre-existing context
  lines near unrelated diff hunks; **no em dash on any added (`+`) line.**
- `RetireSmartIRA/TaxCalculationEngine.swift` — matches are pre-existing
  context, plus three em-dash lines that this branch **removed** (`-`
  lines); **no em dash on any added (`+`) line.**
- `RetireSmartIRATests/MetamorphicPropertyTests.swift` — the file has a diff
  vs main elsewhere, but none of its em-dash lines fall within any diff hunk;
  **no em dash on any added (`+`) line.**
- `RetireSmartIRA/DataManager.swift` — **VIOLATION.** This branch added:
  ```
  +        // TaxCalculationEngine.applyRetirementExemptions exactly — including
  +        // with scenarioStateTax — caught by
  ```
  (part of a new comment block explaining the age/owner-based exemption
  eligibility gather step, mirroring the phrasing of a pre-existing comment
  elsewhere in the same file that also uses an em dash).
- `RetireSmartIRATests/RetireSmartIRATests.swift` — **VIOLATION.** This
  branch added a new test with doc comment:
  ```
  +        // and supplies no scenario-projected retirement distributions at all —
  +        // via an extra withdrawal — not an `.rmd` row — so a drift between the
  ```
  (inside the new `breakdownMatchesCalculationBelowTheDistributionAgeGate` test).

**Conclusion: the em-dash hard constraint is violated by newly added content
in this branch**, in `RetireSmartIRA/DataManager.swift` and
`RetireSmartIRATests/RetireSmartIRATests.swift`. Per instructions, no fix was
attempted.

---

## STEP 6 — Phase numbers

```
$ git log --oneline main..HEAD | wc -l
32
```

Suite counts:
- Baseline (phase start): 1,620 Swift Testing tests in 275 suites + 503 XCTest
- Final (this gate):      1,656 Swift Testing tests in 278 suites + 503 XCTest
- Delta: +36 Swift Testing tests, +3 suites, XCTest unchanged (503 -> 503)

Count only went up; XCTest count is unchanged (not decreased), consistent
with "no pre-existing test removed."

```
$ git diff main --stat
 .../roadmap/2026-08-03-state-tax-phase3a-ledger.md |  466 +++++
 RetireSmartIRA/DataManager.swift                   |  128 +-
 .../StateTaxData/2026/statetax-2026-AK.json        |    2 +
 .../StateTaxData/2026/statetax-2026-AL.json        |    2 +
 .../StateTaxData/2026/statetax-2026-AR.json        |    2 +
 .../StateTaxData/2026/statetax-2026-AZ.json        |    2 +
 .../StateTaxData/2026/statetax-2026-CA.json        |    2 +
 .../StateTaxData/2026/statetax-2026-CO.json        |    2 +
 .../StateTaxData/2026/statetax-2026-CT.json        |    2 +
 .../StateTaxData/2026/statetax-2026-DC.json        |    2 +
 .../StateTaxData/2026/statetax-2026-DE.json        |    2 +
 .../StateTaxData/2026/statetax-2026-FL.json        |    2 +
 .../StateTaxData/2026/statetax-2026-GA.json        |    2 +
 .../StateTaxData/2026/statetax-2026-HI.json        |    2 +
 .../StateTaxData/2026/statetax-2026-IA.json        |    2 +
 .../StateTaxData/2026/statetax-2026-ID.json        |    2 +
 .../StateTaxData/2026/statetax-2026-IL.json        |    6 +
 .../StateTaxData/2026/statetax-2026-IN.json        |    2 +
 .../StateTaxData/2026/statetax-2026-KS.json        |    2 +
 .../StateTaxData/2026/statetax-2026-KY.json        |    2 +
 .../StateTaxData/2026/statetax-2026-LA.json        |    2 +
 .../StateTaxData/2026/statetax-2026-MA.json        |    2 +
 .../StateTaxData/2026/statetax-2026-MD.json        |    2 +
 .../StateTaxData/2026/statetax-2026-ME.json        |    2 +
 .../StateTaxData/2026/statetax-2026-MI.json        |    2 +
 .../StateTaxData/2026/statetax-2026-MN.json        |    2 +
 .../StateTaxData/2026/statetax-2026-MO.json        |    2 +
 .../StateTaxData/2026/statetax-2026-MS.json        |    6 +
 .../StateTaxData/2026/statetax-2026-MT.json        |    2 +
 .../StateTaxData/2026/statetax-2026-NC.json        |    2 +
 .../StateTaxData/2026/statetax-2026-ND.json        |    2 +
 .../StateTaxData/2026/statetax-2026-NE.json        |    2 +
 .../StateTaxData/2026/statetax-2026-NH.json        |    2 +
 .../StateTaxData/2026/statetax-2026-NJ.json        |    8 +
 .../StateTaxData/2026/statetax-2026-NM.json        |    2 +
 .../StateTaxData/2026/statetax-2026-NV.json        |    2 +
 .../StateTaxData/2026/statetax-2026-NY.json        |    2 +
 .../StateTaxData/2026/statetax-2026-OH.json        |    2 +
 .../StateTaxData/2026/statetax-2026-OK.json        |    2 +
 .../StateTaxData/2026/statetax-2026-OR.json        |    2 +
 .../StateTaxData/2026/statetax-2026-PA.json        |    6 +
 .../StateTaxData/2026/statetax-2026-RI.json        |    2 +
 .../StateTaxData/2026/statetax-2026-SC.json        |    2 +
 .../StateTaxData/2026/statetax-2026-SD.json        |    2 +
 .../StateTaxData/2026/statetax-2026-TN.json        |    2 +
 .../StateTaxData/2026/statetax-2026-TX.json        |    2 +
 .../StateTaxData/2026/statetax-2026-UT.json        |    2 +
 .../StateTaxData/2026/statetax-2026-VA.json        |    2 +
 .../StateTaxData/2026/statetax-2026-VT.json        |    2 +
 .../StateTaxData/2026/statetax-2026-WA.json        |    2 +
 .../StateTaxData/2026/statetax-2026-WI.json        |    2 +
 .../StateTaxData/2026/statetax-2026-WV.json        |    2 +
 .../StateTaxData/2026/statetax-2026-WY.json        |    2 +
 RetireSmartIRA/StateAGIPhaseout.swift              |   59 +
 RetireSmartIRA/StatePersonalExemption.swift        |   53 +
 RetireSmartIRA/StateRothConversionExemption.swift  |   27 +
 RetireSmartIRA/StateTaxCodable.swift               |   48 +-
 RetireSmartIRA/StateTaxData.swift                  |   97 +-
 RetireSmartIRA/TaxCalculationEngine.swift          |  142 +-
 .../Baselines/statetax-behavior-baseline-2026.json | 1022 +++++++++++
 .../GoldenScenarioSingleYearTests.swift            |   25 +-
 RetireSmartIRATests/MetamorphicPropertyTests.swift |   54 +-
 RetireSmartIRATests/RetireSmartIRATests.swift      |   27 +
 .../StateTaxBehaviorBaselineTests.swift            |  279 +++
 .../StateTaxCodableRoundTripTests.swift            |  136 +-
 .../StateTaxJSONEquivalenceTests.swift             |   52 +-
 .../StateTaxPhase3aMechanismTests.swift            |  595 ++++++
 ...26-08-03-state-tax-phase3a-schema-extensions.md | 1939 ++++++++++++++++++++
 ...tate-tax-verification-and-maintenance-design.md |    6 +
 69 files changed, 5124 insertions(+), 151 deletions(-)
```

Spot checks on the two largest test-file diffs that are not pure additions:

- `GoldenScenarioSingleYearTests.swift`: the diff changes the cross-path
  helper's `postExemptionDeduction` computation from a hardcoded
  `state == .newJersey` branch to reading `config.personalExemption?.amount(...)`,
  matching the production refactor (Task 3 removed the hardcoded switch). No
  test assertion / expected numeric value was changed; only the mechanism
  used to compute an input mirrors the new config-driven code path.
- `StateTaxJSONEquivalenceTests.swift`: the file-key-completeness test was
  widened from an exact-set equality check to a required-set + a narrow
  optional-set (`personalExemption`), plus a new test asserting only New
  Jersey carries that key in Phase 3a. This is an accommodation for the new
  field, not a loosened/incorrect assertion, and a new test pins the
  single-jurisdiction scope.

`StateTaxBehaviorBaselineTests.swift` and its fixture (`Baselines/statetax-behavior-baseline-2026.json`)
appear in the diff as pre-existing additions from earlier tasks on this
branch; they were NOT touched during this gate session, consistent with the
hard constraint.

---

## STEP 7 — Commit

**NOT EXECUTED.** Step 5's em-dash hard-constraint check failed (new em-dash
content added by this branch in `DataManager.swift` and
`RetireSmartIRATests.swift`, both predating this gate session). Per the
instruction "If ANY step fails, STOP and report it. Do not attempt a fix," the
Step 1 comment-only fix in `StateTaxCodableRoundTripTests.swift` was made and
verified em-dash-free, but was left uncommitted so the branch state stays
exactly as found, pending direction on the em-dash violation.

---

## Hard constraints checklist

- [x] `RetireSmartIRA.xcodeproj/project.pbxproj` not edited (confirmed empty diff vs main; not touched this session)
- [x] `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift` / fixture not edited this session
- [x] `RetireSmartIRA/ProjectionEngine.swift` not touched (confirmed empty diff vs main)
- [ ] **No em dash characters anywhere — VIOLATED** by pre-existing branch content (see Step 5)
- [x] No fix attempted for the failing check; reporting only
