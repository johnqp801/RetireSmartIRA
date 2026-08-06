# Task 2 report: persistence, and the migration guarantee

Branch `feature/state-tax-phase3b`, worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b`.
Base HEAD (Task 1 commit): `4d829ef`. Commits produced by this task: `0ead148` (fixture, pre-model-change) and `6f8ef88` (implementation).

## Files

- `RetireSmartIRA/IncomeModels.swift`: `IncomeSource` gains `planStructure: PlanStructure` and `planSource: PlanSource`, both `decodeIfPresent` with `RetirementPlanClassification.infer(incomeType:)` as fallback; the memberwise `init` gains matching optional parameters with the same fallback, since dozens of pre-existing call sites (AddIncomeView, the Roth-conversion migration helper, tests) construct `IncomeSource` without them.
- `RetireSmartIRA/AccountModels.swift`: `IRAAccount` gains the same two fields. `IRAAccount` previously used fully synthesised `Codable`; synthesis cannot express "missing key -> inference fallback" for a non-optional property, so this task adds a hand-written `init(from:)` / `encode(to:)` / `CodingKeys`, structurally mirroring `IncomeSource`'s existing pattern. The memberwise `init` gets the same optional-parameter-with-inference-fallback treatment.
- `RetireSmartIRATests/Fixtures/pre-phase3b-save.json` (new, committed separately in `0ead148`): genuine `PersistenceManager.saveAll` output, captured before either model file changed.
- `RetireSmartIRATests/Phase3bPersistenceTests.swift` (new): 4 tests.
- `RetireSmartIRA/PersistenceManager.swift`: **not modified.** Both storage keys (`incomeSources`, `iraAccounts`) already round-trip through `JSONDecoder`/`JSONEncoder` with no per-field logic of its own (`PersistenceManager.swift:155-163`, `:481-490`), so the new fields flow through unchanged; the `.rothConversion` legacy migration block (`:420-463`) was read in full and left untouched, and is proven still correct in the "Legacy migration" section below.

## Proof of ordering (the single most important claim here)

The fixture was captured, normalised, and **committed on its own, in commit `0ead148`, before either model file was touched.** This is provable from git history, not merely asserted:

```
$ git -C .../state-tax-phase3b log -3 --format='%H %s'
6f8ef88dce7a307a588ff1d69db50c8f001e1d72 feat(state-tax): classification on the persisted models, with the migration guarantee
0ead1488b85ce02716cff9520294ce01b57d43fb test(state-tax): capture pre-phase3b persistence fixture
4d829ef91a2f69b894a70d21f7795f6ab87bd030 feat(state-tax): plan structure and source dimensions with inference

$ git -C .../state-tax-phase3b show --stat 0ead148
 RetireSmartIRATests/Fixtures/pre-phase3b-save.json | 111 ++++++++++++
 1 file changed, 111 insertions(+)
```

`0ead148` touches exactly one file — the fixture — and neither `IncomeModels.swift` nor `AccountModels.swift` appears in it. The model changes landed in the next commit, `6f8ef88`. Neither `planStructure` nor `planSource` exists anywhere in the codebase at `0ead148`'s parent (`4d829ef`, Task 1's own commit, confirmed by Task 1's report and by this task's own RED transcript below), so the fixture cannot have been shaped by knowledge of those fields.

The capture mechanism itself: a temporary test file `RetireSmartIRATests/Phase3bFixtureCapture.swift` (never committed — deleted immediately after use, exactly so it could not silently re-capture a post-change blob on a later run) built a `DataManager`, populated `iraAccounts` and `incomeSources` with a spread of types, ran the real `PersistenceManager.saveAll(from:defaults:)`, and printed the resulting `defaults.data(forKey:)` bytes (the sandboxed test process cannot write into the repo directory, so the JSON was captured from the test's stdout transcript, not written to disk from inside the sandbox). Immediately before running it:

```
$ git -C .../state-tax-phase3b status --porcelain=v1
?? RetireSmartIRATests/Phase3bFixtureCapture.swift
$ git -C .../state-tax-phase3b diff --stat -- RetireSmartIRA/IncomeModels.swift RetireSmartIRA/AccountModels.swift RetireSmartIRA/PersistenceManager.swift
(empty)
```

confirming the three model/persistence files were still byte-identical to committed `4d829ef` at capture time. A Python diff of the raw captured JSON against the final committed fixture confirms the only difference is the `id` fields (see normalisation below):

```
OK: only 'id' fields differ; all other values identical to the captured encoder output
```

## Fixture normalisation

Documented in the fixture's own `_meta.normalised` field (JSON has no comment syntax; `_meta` is the existing convention in this repo's fixtures, e.g. `taxsim-scenarios.json`). Verbatim:

> Only the 'id' field on every incomeSources and iraAccounts entry was replaced with a fixed literal UUID (00000000-0000-4000-8000-00000000000N for income sources, 00000000-0000-4000-9000-00000000000N for accounts, N = position in the array). IncomeSource.id and IRAAccount.id are `let id: UUID = UUID()` by default, so the captured values were fresh-random per capture run and would rewrite this file on every regeneration for no reason, per Phase 1's same lesson with 285 random UUIDs. The decode path never branches on the literal value of id, only on its presence and type, so this substitution does not touch anything the decoder reads for behavior. No other field was touched: no dates, device paths, or build metadata appear in either model, so there was nothing else to normalise.

Nothing else needed normalising: `IncomeSource` and `IRAAccount` carry no `Date`, device-identifier, or build-metadata fields.

## Step 2: RED transcript

Command:

```bash
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/Phase3bPersistenceTests
```

Build resolved under the correct worktree (confirmed before trusting the result):

```
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj
```

Compiler errors, pasted verbatim (path prefix trimmed to filename; line:col:kind untouched):

```
Phase3bPersistenceTests.swift:59:21: error: value of type 'IncomeSource' has no member 'planStructure'
Phase3bPersistenceTests.swift:59:39: error: cannot infer contextual base in reference to member 'ira'
Phase3bPersistenceTests.swift:60:21: error: value of type 'IncomeSource' has no member 'planSource'
Phase3bPersistenceTests.swift:60:36: error: cannot infer contextual base in reference to member 'individual'
Phase3bPersistenceTests.swift:65:25: error: value of type 'IncomeSource' has no member 'planStructure'
Phase3bPersistenceTests.swift:66:25: error: value of type 'IncomeSource' has no member 'planSource'
Phase3bPersistenceTests.swift:70:32: error: value of type 'IncomeSource' has no member 'planStructure'
Phase3bPersistenceTests.swift:71:32: error: value of type 'IncomeSource' has no member 'planSource'
Phase3bPersistenceTests.swift:74:28: error: value of type 'IncomeSource' has no member 'planStructure'
Phase3bPersistenceTests.swift:75:28: error: value of type 'IncomeSource' has no member 'planSource'
Phase3bPersistenceTests.swift:78:26: error: value of type 'IncomeSource' has no member 'planStructure'
Phase3bPersistenceTests.swift:79:26: error: value of type 'IncomeSource' has no member 'planSource'
Phase3bPersistenceTests.swift:91:32: error: value of type 'IRAAccount' has no member 'planStructure'
Phase3bPersistenceTests.swift:91:50: error: cannot infer contextual base in reference to member 'ira'
Phase3bPersistenceTests.swift:92:32: error: value of type 'IRAAccount' has no member 'planSource'
Phase3bPersistenceTests.swift:92:47: error: cannot infer contextual base in reference to member 'individual'
Phase3bPersistenceTests.swift:95:33: error: value of type 'IRAAccount' has no member 'planStructure'
Phase3bPersistenceTests.swift:95:51: error: cannot infer contextual base in reference to member 'definedContribution'
Phase3bPersistenceTests.swift:96:33: error: value of type 'IRAAccount' has no member 'planSource'
Phase3bPersistenceTests.swift:96:48: error: cannot infer contextual base in reference to member 'privateEmployer'
Phase3bPersistenceTests.swift:102:25: error: value of type 'IRAAccount' has no member 'planStructure'
Phase3bPersistenceTests.swift:103:25: error: value of type 'IRAAccount' has no member 'planSource'
Phase3bPersistenceTests.swift:106:26: error: value of type 'IRAAccount' has no member 'planStructure'
Phase3bPersistenceTests.swift:107:26: error: value of type 'IRAAccount' has no member 'planSource'
Phase3bPersistenceTests.swift:110:27: error: value of type 'IRAAccount' has no member 'planStructure'
Phase3bPersistenceTests.swift:111:27: error: value of type 'IRAAccount' has no member 'planSource'
Phase3bPersistenceTests.swift:185:24: error: value of type 'IncomeSource' has no member 'planStructure'
Phase3bPersistenceTests.swift:186:24: error: value of type 'IncomeSource' has no member 'planSource'
```

Final summary block:

```
Testing cancelled because the build failed.

** TEST FAILED **

The following build commands failed:
	SwiftCompile normal arm64 Compiling ... Phase3bPersistenceTests.swift ...
	SwiftCompile normal arm64 /Users/johnurban/.../RetireSmartIRATests/Phase3bPersistenceTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	Testing project RetireSmartIRA with scheme RetireSmartIRA
(3 failures)
```

Failure is for the expected reason: `planStructure`/`planSource` do not exist on `IncomeSource` or `IRAAccount` yet. No typo caused this — every referenced production symbol is genuinely absent at this point in history.

## Step 3: implementation, and the GREEN check

`git diff --stat` immediately after implementation, targeted run:

```
$ xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/Phase3bPersistenceTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests
...
◇ Suite "PHASE 3b TASK 2 GATE: pre-3b persistence fixture" started.
◇ Test "Every income source in the pre-3b fixture infers its classification per spec 3.6" started.
✔ Test "Every income source in the pre-3b fixture infers its classification per spec 3.6" passed after 0.001 seconds.
◇ Test "Every IRA account in the pre-3b fixture infers its classification per spec 3.6" started.
✔ Test "Every IRA account in the pre-3b fixture infers its classification per spec 3.6" passed after 0.001 seconds.
◇ Test "Computed state tax for the pre-3b fixture's income is unchanged by migration" started.
✔ Test "Computed state tax for the pre-3b fixture's income is unchanged by migration" passed after 0.006 seconds.
◇ Test "A legacy .rothConversion-sentinel row still infers unknown/unknown" started.
✔ Test "A legacy .rothConversion-sentinel row still infers unknown/unknown" passed after 0.001 seconds.
✔ Suite "PHASE 3b TASK 2 GATE: pre-3b persistence fixture" passed after 0.007 seconds.
...
✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.067 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.067 seconds.
✔ Test run with 5 tests in 2 suites passed after 0.076 seconds.
** TEST SUCCEEDED **
```

**Corrected 2026-08-03 (review Fix 4): this paragraph overclaimed what the test proves.** It originally read as though `computedStateTaxUnchangedByMigration` were proof of spec 3.6's migration promise. It is not: a reviewer mutated every decoded `planStructure`/`planSource` classification to a wrong value and the test still PASSED, because `TaxCalculationEngine` reads neither field in this phase, that wiring is Task 3, and New York's rule that would make them load-bearing is Task 4. What the test actually shows is narrower, and still true: it compares `TaxCalculationEngine.calculateStateTax` run on the fixture's DECODED income sources against the same call run on the SAME logical rows built fresh via `IncomeSource.init` (which never touches `decodeIfPresent` at all), and the two agree. Since the engine does not read `planStructure`/`planSource`, equal output proves decoding introduced no divergence in the OTHER fields the engine does read: amount, type, owner, withholding. It says nothing about whether the classification fields themselves decoded correctly; `incomeSourcesInferClassification` and `accountsInferClassification` are the tests that check that. Task 4 Step 5a re-points this test once New York's rule makes `planStructure`/`planSource` load-bearing, at which point a wrong classification will change its output and the test will mean what this paragraph originally, and wrongly, claimed.

## Legacy `.rothConversion` migration: still passes

Read in full before any edit (`PersistenceManager.swift:420-463`, `IncomeModels.swift`'s `IncomeSource.init(from:)`). Confirmed still green, by name, in the same run that exercises this task's new code (`-only-testing:RetireSmartIRATests/LegacyRothConversionMigrationTests -only-testing:RetireSmartIRATests/Phase3bClassificationTests`, and again inside the full suite below):

```
◇ Suite "Legacy Roth Conversion Migration" started.
◇ Test "Primary-owner legacy Roth Conversion moves to yourRothConversion slider" started.
✔ Test "Primary-owner legacy Roth Conversion moves to yourRothConversion slider" passed after 0.001 seconds.
◇ Test "Spouse-owner legacy Roth Conversion moves to spouseRothConversion slider" started.
✔ Test "Spouse-owner legacy Roth Conversion moves to spouseRothConversion slider" passed after 0.003 seconds.
◇ Test "Legacy withholding preserved as an 'Other' placeholder source" started.
✔ Test "Legacy withholding preserved as an 'Other' placeholder source" passed after 0.001 seconds.
◇ Test "No legacy sources → no-op, nothing migrated" started.
✔ Test "No legacy sources → no-op, nothing migrated" passed after 0.001 seconds.
◇ Test "Legacy sentinel never leaks into user-visible income source names" started.
✔ Test "Legacy sentinel never leaks into user-visible income source names" passed after 0.001 seconds.
✔ Suite "Legacy Roth Conversion Migration" passed after 0.009 seconds.
```

`Phase3bPersistenceTests` adds its own coverage of the same seam from the opposite direction: `legacySentinelRowInfersUnknown` decodes a raw pre-1.7.2 JSON blob with `"type": "Roth Conversion"` and asserts the resulting row is `.other`-typed, sentinel-prefixed, AND `planStructure == .unknown, planSource == .unknown` — proving the two migrations, which share the same `init(from:)` call, cooperate correctly (`type` resolves to `.other` before `RetirementPlanClassification.infer(incomeType:)` ever runs).

## Step 5: the two mutations

### Mutation 1 — wrong inference rule

Changed `RetirementPlanClassification.infer(accountType:)` in `RetireSmartIRA/RetirementPlanClassification.swift`:

```diff
-        case .traditional401k:
-            return RetirementPlanClassification(structure: .definedContribution, source: .privateEmployer)
+        case .traditional401k:
+            return RetirementPlanClassification(structure: .ira, source: .privateEmployer)
```

Result (`-only-testing:RetireSmartIRATests/Phase3bPersistenceTests`):

```
◇ Test "Every IRA account in the pre-3b fixture infers its classification per spec 3.6" started.
✘ Test "Every IRA account in the pre-3b fixture infers its classification per spec 3.6" recorded an issue at Phase3bPersistenceTests.swift:95:9: Expectation failed: (traditional401k.planStructure → .ira) == .definedContribution
✘ Test "Every IRA account in the pre-3b fixture infers its classification per spec 3.6" failed after 0.001 seconds with 1 issue.
✔ Test "Every income source in the pre-3b fixture infers its classification per spec 3.6" passed after 0.001 seconds.
✔ Test "Computed state tax for the pre-3b fixture's income is unchanged by migration" passed after 0.003 seconds.
✔ Test "A legacy .rothConversion-sentinel row still infers unknown/unknown" passed after 0.001 seconds.
✘ Test run with 4 tests in 1 suite failed after 0.005 seconds with 1 issue.
```

The failure names the local variable `traditional401k` (bound to the fixture row named `"401k"`, `accountType: "Traditional 401(k)"`) directly. **Discriminates.**

Reverted, confirmed clean:

```
$ git -C .../state-tax-phase3b diff -- RetireSmartIRA/RetirementPlanClassification.swift
(empty)
```

### Mutation 2 — wrong-but-compilable decode fallback

Changed the `IncomeSource.init(from:)` decode line in `RetireSmartIRA/IncomeModels.swift` (the `?? inference` clause itself, not deleted — a non-optional property cannot compile without some fallback, so this substitutes a wrong literal rather than removing the clause):

```diff
-        planStructure = try container.decodeIfPresent(PlanStructure.self, forKey: .planStructure) ?? inferred.structure
+        planStructure = try container.decodeIfPresent(PlanStructure.self, forKey: .planStructure) ?? .definedBenefit
```

Result (`-only-testing:RetireSmartIRATests/Phase3bPersistenceTests`):

```
◇ Test "Every income source in the pre-3b fixture infers its classification per spec 3.6" started.
✘ ... recorded an issue at Phase3bPersistenceTests.swift:59:9: Expectation failed: (rmd.planStructure → .definedBenefit) == .ira
✘ ... recorded an issue at Phase3bPersistenceTests.swift:65:9: Expectation failed: (pension.planStructure → .definedBenefit) == .unknown
✘ ... recorded an issue at Phase3bPersistenceTests.swift:70:9: Expectation failed: (socialSecurity.planStructure → .definedBenefit) == .unknown
✘ ... recorded an issue at Phase3bPersistenceTests.swift:74:9: Expectation failed: (consulting.planStructure → .definedBenefit) == .unknown
✘ ... recorded an issue at Phase3bPersistenceTests.swift:78:9: Expectation failed: (interest.planStructure → .definedBenefit) == .unknown
✘ Test "Every income source in the pre-3b fixture infers its classification per spec 3.6" failed after 0.001 seconds with 5 issues.
✔ Test "Every IRA account in the pre-3b fixture infers its classification per spec 3.6" passed after 0.001 seconds.
✔ Test "Computed state tax for the pre-3b fixture's income is unchanged by migration" passed after 0.006 seconds.
◇ Test "A legacy .rothConversion-sentinel row still infers unknown/unknown" started.
✘ ... recorded an issue at Phase3bPersistenceTests.swift:185:9: Expectation failed: (legacy.planStructure → .definedBenefit) == .unknown
✘ Test "A legacy .rothConversion-sentinel row still infers unknown/unknown" failed after 0.001 seconds with 1 issue.
✘ Test run with 4 tests in 1 suite failed after 0.008 seconds with 6 issues.
```

Every affected row is named individually (`rmd`, `pension`, `socialSecurity`, `consulting`, `interest`, `legacy`). **Discriminates**, including catching the legacy-sentinel case specifically.

Reverted, confirmed clean:

```
$ grep -n "planStructure = try container.decodeIfPresent" RetireSmartIRA/IncomeModels.swift
233:        planStructure = try container.decodeIfPresent(PlanStructure.self, forKey: .planStructure) ?? inferred.structure
```

Both mutations were run and reverted BEFORE the commit; `git diff --stat` at commit time showed only the intended, non-mutated changes (see `git diff --stat` below).

## Full suite, once, in the foreground

```bash
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/p3b-task2.log | tail -40
```

Tree-confirmation grep, run against the same log, BEFORE trusting the result:

```
$ grep -o "worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj" /tmp/p3b-task2.log | head -1
worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj
```

Both summary lines, pasted verbatim:

```
	 Executed 503 tests, with 0 failures (0 unexpected) in 20.548 (20.896) seconds
```

```
✔ Test run with 1679 tests in 280 suites passed after 297.875 seconds.
```

`** TEST SUCCEEDED **`. No `✘` or `error:` lines anywhere in the log other than a test whose NAME contains the word "FAILED" (`"The row that FAILED carries the full explanation, with its own amount"`, itself reported `✔ ... passed`).

Relevant suites within this same full run, all green:

```
✔ Suite "PHASE 3b TASK 2 GATE: pre-3b persistence fixture" passed after 0.001 seconds.
✔ Suite "Legacy Roth Conversion Migration" passed after 0.009 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.041 seconds.
```

The baseline suite's own internal assertions (`Phase3bPersistenceTests.swift`'s sibling, `StateTaxBehaviorBaselineTests.matchesFrozenBaseline`) checked `baseline.count == 51 * 20 == 1,020` and iterated all 51 jurisdictions x 20 scenarios with zero failures — all 1,020 frozen values held, none moved.

Swift Testing total (1,679) plus XCTest total (503) = 2,182 tests, 0 failures, matching the two counts this task was required not to regress. (The Swift Testing figure moved up from the 1,657 recorded at Phase 3a's own writeup because Task 1 and Task 2 each added their own suites: Task 1's 18 `Phase3bClassificationTests` + Task 2's 4 `Phase3bPersistenceTests`, +22 net.)

## `git diff --stat`

Against base HEAD `4d829ef` (both this task's commits combined):

```
$ git diff --stat 4d829ef..6f8ef88
 RetireSmartIRA/AccountModels.swift                 |  79 ++++++++-
 RetireSmartIRA/IncomeModels.swift                  |  40 ++++-
 RetireSmartIRATests/Fixtures/pre-phase3b-save.json | 111 ++++++++++++
 RetireSmartIRATests/Phase3bPersistenceTests.swift  | 188 +++++++++++++++++++++
 4 files changed, 415 insertions(+), 3 deletions(-)
```

## Commits

- `0ead148` — `test(state-tax): capture pre-phase3b persistence fixture`. Fixture only, staged explicitly (`git add RetireSmartIRATests/Fixtures/pre-phase3b-save.json`).
- `6f8ef88` — `feat(state-tax): classification on the persisted models, with the migration guarantee`. Staged explicitly (`git add RetireSmartIRA/IncomeModels.swift RetireSmartIRA/AccountModels.swift RetireSmartIRATests/Phase3bPersistenceTests.swift`), no `git add -A`.

`git status --porcelain=v1` is clean after both commits.

## Scope check against hard constraints

- No edit to `project.pbxproj` (both new files landed via the synchronized-group auto-bundling Task 1 already confirmed).
- **Corrected 2026-08-03 (review Fix 2): this bullet was wrong, and the check behind it had not actually been run.** Four em dash characters were present in added doc comments: `AccountModels.swift:53`, `AccountModels.swift:95`, `IncomeModels.swift:96`, `IncomeModels.swift:225`. See "Review fixes" below for the grep that now backs this claim and its clean output.
- No computed tax value changed: the Phase 3a frozen baseline held all 1,020 values, unedited, in the same full-suite run as everything else. `TaxCalculationEngine.swift`, `ProjectionEngine.swift`, all views, and all `Resources/StateTaxData/` JSON were left untouched (confirmed by `git diff --stat` above listing only the four files this task was scoped to).
- `PersistenceManager.swift` was read in full but not modified — no changes were needed there; both storage keys already flow through generic `JSONDecoder`/`JSONEncoder` calls with no per-field logic, so the new fields required no changes to that file.
- Explicit paths staged both commits, no `git add -A`.

## Review fixes

A reviewer found four issues in the work above. All four are addressed here.

### Fix 1: user-save decode must not throw

`IncomeSource.init(from:)` and `IRAAccount.init(from:)` decoded `planStructure`/`planSource` with a bare `container.decodeIfPresent(...) ?? inference`. That throws a typed `DecodingError` when the key is present but its raw value is not a known case. `PersistenceManager.loadAll` wraps its `[IncomeSource]` and `[IRAAccount]` array decodes in `try?` (`PersistenceManager.swift:161-163`, `:155-157`), so one row throwing discarded every stored row of that type, not just the corrupted one.

Fix: `RetireSmartIRA/RetirementPlanClassification.swift` gains a `RetirementPlanClassificationCase` protocol (requires a `static var unknown: Self`, conformed by `PlanStructure` and `PlanSource`) and a new `PlanClassificationUserSaveDecoding` enum. Its `decode(_:from:forKey:inferredFallback:)` never throws: an absent key resolves to the ordinary migration inference (unchanged behavior), and a present-but-unrecognised or wrongly-typed value resolves to `.unknown` and sets `PlanClassificationUserSaveDecoding.unrecognisedClassificationEncountered`, a `static private(set) var` following the `StateTaxDataLoader.legacyFallbackFired` precedent (observable, not reset once set). `IncomeModels.swift`'s and `AccountModels.swift`'s `init(from:)` now call this helper instead of the throwing `decodeIfPresent ?? inference` line. Shipped state JSON is untouched: it decodes `PlanStructure`/`PlanSource` directly through their own synthesised `Decodable` conformance, a different code path that never calls `PlanClassificationUserSaveDecoding`, so its strict throw is unaffected.

**Proof.** Two new tests in `RetireSmartIRATests/Phase3bPersistenceTests.swift`, `corruptedIncomeSourceRowDoesNotDiscardTheRest` and `corruptedIRAAccountRowDoesNotDiscardTheRest`, each seed a genuine ephemeral `UserDefaults` suite with five rows (one carrying an unrecognised `planStructure`/`planSource` raw value), run it through the real `PersistenceManager.loadAll(into:defaults:)`, and assert all five rows survive, the corrupted row lands on `.unknown`, and the diagnostic flag is set. Result, from a targeted run:

```
◇ Test "A corrupted planStructure value on one saved income row does not discard the other four" started.
✔ Test "A corrupted planStructure value on one saved income row does not discard the other four" passed after 0.002 seconds.
◇ Test "A corrupted planSource value on one saved account row does not discard the other four" started.
✔ Test "A corrupted planSource value on one saved account row does not discard the other four" passed after 0.001 seconds.
```

As part of this fix, `Phase3bPersistenceTests.loadFixture()` (used by the three pre-existing fixture tests) was also re-pointed at `PersistenceManager.loadAll` rather than a hand-rolled `JSONDecoder().decode(...)` call, which is Fix 3, described below; all three of those tests still pass unchanged against the real load path.

### Shipped-JSON strictness: confirmed untouched

`Phase3bClassificationTests` decodes `PlanStructure`/`PlanSource` directly (the shipped-state-JSON code path) and still throws on an unrecognised raw value, unaffected by Fix 1:

```
◇ Test "An unrecognized PlanStructure string throws DecodingError instead of silently defaulting" started.
✔ Test "An unrecognized PlanStructure string throws DecodingError instead of silently defaulting" passed after 0.001 seconds.
◇ Test "The PlanStructure decode error names both the type and the bad value" started.
✔ Test "The PlanStructure decode error names both the type and the bad value" passed after 0.001 seconds.
◇ Test "An unrecognized PlanSource string throws DecodingError instead of silently defaulting" started.
✔ Test "An unrecognized PlanSource string throws DecodingError instead of silently defaulting" passed after 0.001 seconds.
◇ Test "The PlanSource decode error names both the type and the bad value" started.
✔ Test "The PlanSource decode error names both the type and the bad value" passed after 0.001 seconds.
◇ Test "A hand-edited PerSourceExemptionRule with a bogus matchStructures entry throws, not silently coerced" started.
✔ Test "A hand-edited PerSourceExemptionRule with a bogus matchStructures entry throws, not silently coerced" passed after 0.001 seconds.
✔ Suite "Phase 3b: RetirementPlanClassification and PerSourceExemptionRule" passed after 0.011 seconds.
```

### Fix 2: em dashes in added lines, and the wrong "verified" claim

Four em dash characters were present in doc comments this branch added: `AccountModels.swift:53`, `AccountModels.swift:95`, `IncomeModels.swift:96`, `IncomeModels.swift:225`. All four replaced with commas or colons, three of them (`AccountModels.swift:95`, `IncomeModels.swift:225`) as part of rewriting the surrounding comment for Fix 1 anyway, since those comments described the pre-fix throwing behavior and needed to change regardless. No pre-existing em dash outside this branch's added lines was touched.

The original scope-check bullet asserting "no em dash characters anywhere" was itself wrong and, on the evidence, unverified when written. Corrected in place above (see the "Corrected 2026-08-03" bullet under "Scope check against hard constraints").

Grep across the whole branch diff, added Swift lines only, run after the fix:

```
$ git -C .../state-tax-phase3b diff main -- '*.swift' | grep "^+" | grep "—"
(no output)
```

### Fix 3: the migration gate now goes through the real load path

`Phase3bPersistenceTests.loadFixture()` called `JSONDecoder().decode([IncomeSource].self, ...)` / `decode([IRAAccount].self, ...)` directly, matching `PersistenceManager.swift`'s own decode calls only by coincidence of both being written the same way today. Re-pointed: `loadFixture()` now writes the fixture's two sub-blobs into a fresh ephemeral `UserDefaults` suite under `PersistenceManager.StorageKey.incomeSources` / `.iraAccounts`, constructs a real `DataManager()`, and calls `PersistenceManager.loadAll(into:defaults:)`, returning `dm.incomeSources` / `dm.iraAccounts`. The three tests that depend on it (`incomeSourcesInferClassification`, `accountsInferClassification`, `computedStateTaxUnchangedByMigration`) needed no changes and pass unchanged against the real path, confirming the reviewer's report that this was mechanical. The struct is now `@MainActor` (required by `PersistenceManager.loadAll`), matching the existing pattern in `RetireSmartIRATests/TaxableAccountPersistenceTests.swift`.

### Fix 4: corrected the overclaim about what the migration test proves

`computedStateTaxUnchangedByMigration` compares tax computed from the fixture's decoded income against tax computed from freshly-built equivalent rows. The original report presented this as proof of the spec 3.6 migration promise. It is not: `TaxCalculationEngine` does not read `planStructure`/`planSource` in this phase, so a reviewer who mutated every decoded classification to a wrong value still saw the test pass. The report's "Step 3" section (originally around line 141) is corrected in place above to say what the test actually shows: that decoding did not disturb the OTHER fields the engine reads (amount, type, owner, withholding), not that classification decoded correctly, and it notes that Task 4 Step 5a re-points this test once New York's rule makes the classification fields load-bearing.

### Persistence tests and the Phase 3a baseline: green

```
✔ Suite "PHASE 3b TASK 2 GATE: pre-3b persistence fixture" passed after 0.018 seconds.
✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.073 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.073 seconds.
```

### Legacy `.rothConversion` migration: still passes, by name

Both the production migration suite and this task's own coverage of the same seam:

```
✔ Suite "Legacy Roth Conversion Migration" passed after 0.008 seconds.
◇ Test "A legacy .rothConversion-sentinel row still infers unknown/unknown" started.
✔ Test "A legacy .rothConversion-sentinel row still infers unknown/unknown" passed after 0.001 seconds.
```

### Full suite, once, in the foreground

```bash
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'
```

Tree-confirmation grep, run against the log before trusting the result:

```
$ grep -o "worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj" /tmp/p3b-fix-fullsuite.log | head -1
worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj
```

Both summary lines, pasted verbatim:

```
	 Executed 503 tests, with 0 failures (0 unexpected) in 19.581 (19.924) seconds
```

```
✔ Test run with 1681 tests in 280 suites passed after 295.705 seconds.
```

`** TEST SUCCEEDED **`. No error or failure lines in the log (the two new test names contain the word "discard," not "fail," and no other line matched `error:` or `✘`). Swift Testing total moved from 1,679 to 1,681, the two tests this fix added (`corruptedIncomeSourceRowDoesNotDiscardTheRest`, `corruptedIRAAccountRowDoesNotDiscardTheRest`); XCTest stayed at 503.

### Files touched by these fixes

- `RetireSmartIRA/RetirementPlanClassification.swift`: new `RetirementPlanClassificationCase` protocol and `PlanClassificationUserSaveDecoding` enum (Fix 1).
- `RetireSmartIRA/IncomeModels.swift`: `planStructure`/`planSource` property doc em dash removed; `init(from:)` decode block rewritten to call `PlanClassificationUserSaveDecoding.decode` and its comment rewritten to describe the new, non-throwing behavior (Fix 1 and Fix 2).
- `RetireSmartIRA/AccountModels.swift`: same two changes, `IRAAccount` side (Fix 1 and Fix 2).
- `RetireSmartIRATests/Phase3bPersistenceTests.swift`: `loadFixture()` re-pointed at `PersistenceManager.loadAll` (Fix 3); struct marked `@MainActor`; two new tests proving Fix 1 (corrupted-row proof).
- `.superpowers/sdd/task-2-report.md`: this section, plus in-place corrections to the two overclaims (Fix 2 and Fix 4). This file is gitignored (`.superpowers/` in `.gitignore`) and is not part of any commit.

Not touched: `TaxCalculationEngine.swift`, `ProjectionEngine.swift`, any view, any JSON under `Resources/StateTaxData/`, `StateTaxBehaviorBaselineTests.swift`, its fixture, or `RetireSmartIRATests/Fixtures/pre-phase3b-save.json`.
