# Task 1 report: extend the model, provably inert

Branch `feature/state-tax-phase5b`, worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`.

## What was added

### Three new `PlanSource` cases (`RetireSmartIRA/RetirementPlanClassification.swift`)

```swift
/// US government civilian service: CSRS and FERS. Distinct from
/// `uniformedServices` (military retired pay) and `railroadRetirement`
/// (Railroad Retirement Board benefits), neither of which is an ordinary
/// federal civilian pension even though all three are federal in origin.
case federalCivilian

/// Military retired pay. Distinct from `federalCivilian` (CSRS/FERS).
/// Phase 5b: Vermont, Arizona, Idaho, Massachusetts and Kansas each give
/// uniformed-services and federal-civilian pay different treatment;
/// before this case existed the two were indistinguishable, so no rule
/// could express that difference.
case uniformedServices

/// Railroad Retirement Board benefits. Phase 5b: neither a state system
/// nor an ordinary federal civilian pension, which is why it is its own
/// case rather than folded into `federalCivilian`. Kansas exempts it by
/// name.
case railroadRetirement

/// The taxpayer's OWN state of residence, or that state's localities:
/// their own state's public retirement system. This is what KPERS (the
/// Kansas Public Employees Retirement System) is for a Kansas resident.
/// Phase 5b: contrast with `otherStateOrLocal` below, which is a
/// DIFFERENT state's system. The two are a matched pair and a rule
/// naming one must never match the other. Before this case existed,
/// Kansas's own KPERS fixtures had to be labelled `otherStateOrLocal`,
/// the exact case whose entire reason for existing is to stop an
/// out-of-state pension from claiming a state's own exclusion.
case ownStateOrLocal

/// A DIFFERENT state or its localities. NOT Line 26 eligible. This case
/// exists specifically to stop an out-of-state public pension from
/// selecting New York's exclusion. Contrast with `ownStateOrLocal`
/// above, the taxpayer's OWN state system: the two are a matched pair
/// and a rule naming one must never match the other.
case otherStateOrLocal
```

`federalCivilian`'s own doc comment was also extended to name both new
siblings, and `otherStateOrLocal`'s doc comment was extended to name
`ownStateOrLocal` (the brief's "each doc comment should name the other"
requirement).

### One new optional survivor flag on `RetirementPlanClassification`

```swift
/// Phase 5b: whether this classified source is a survivor benefit held
/// by someone other than the original plan participant, rather than the
/// participant's own pension. DC exempts a survivor benefit while taxing
/// the holder's own pension, and today both are `federalCivilian`,
/// indistinguishable without this flag.
///
/// Defaults to `nil`, which is what every classification built before
/// this flag existed produces: `RetirementPlanClassification`'s
/// synthesized memberwise initializer carries the same `nil` default,
/// so no existing call site in `infer(incomeType:)` or
/// `infer(accountType:)` needed to change. Swift's synthesized
/// `Decodable` conformance decodes a missing key on an `Optional`
/// property as `nil` rather than throwing, so every fixture and every
/// user save written before this flag existed decodes unchanged.
///
/// Domain model only in this phase, per this file's header: nothing yet
/// reads this flag when matching a `PerSourceExemptionRule`. Wiring it
/// into matching is later phase 5b task work.
let isSurvivorBenefit: Bool? = nil
```

**Placement decision (deviation to record):** the brief said "the classified-source
type" without naming a file, and listed only two files to modify. `RetirementPlanClassification`
is the one type in either file that pairs `structure` and `source` into a single
per-row classification (its own doc comment: "Both dimensions together, carried
by `IncomeSource` and by `Account`"), so the flag went there rather than on
`PerSourceExemptionRule`, which matches rules, not rows. This keeps the change
inside the two named files and inside "types only, domain model only" scope;
wiring it into `matches()` or into `IncomeSource`/`IRAAccount` storage is left
for a later task, matching how Phase 3b itself sequenced `RetirementPlanClassification`
(Task 1, types only) before wiring it onto the two models (Task 2).

### `PerSourceExemptionRule.swift`

Doc-comment only, zero functional change. `matches()`'s body is generic over
`PlanSource`/`PlanStructure` via `Array.contains`, so it already handles the
three new cases correctly with no code change; the comment was extended to
say so explicitly and point at the new test file as the exclusivity proof.

## Inertness evidence

### 1. The frozen 1,020-value baseline does not move

`git diff --stat` against the branch point touches exactly two production
files, both doc-comment-plus-additive-case changes:

```
 RetireSmartIRA/PerSourceExemptionRule.swift       |  9 +++++
 RetireSmartIRA/RetirementPlanClassification.swift | 49 ++++++++++++++++++++++-
 2 files changed, 56 insertions(+), 2 deletions(-)
```

No file under `RetireSmartIRATests/Baselines/` was touched (`git status --porcelain`
shows only the two modified Swift files above plus the new test file as untracked).
`Suite "PHASE 3a GATE: state tax behavior baseline"` (the frozen-baseline gate)
and `Suite "Baseline movement ledger"` both passed in the full run, with no new
entries added to `statetax-behavior-movements-2026.json`.

### 2. Every golden fixture produces exactly what it produces today

`Suite "Golden scenario fixtures"`, `Suite "Golden scenarios, coverage and shape"`,
`Suite "Golden scenarios, defect catalogue"` (the 99 pinned defects),
`Suite "Golden scenarios, single-year path"`, `Suite "Golden scenarios, multi-year path"`,
and `Suite "Golden scenarios, cross-path agreement"` all passed. No golden fixture
file under `RetireSmartIRATests/GoldenScenarios/` was modified (confirmed by
`git status --porcelain`, which lists no changes there).

### 3. New York, named explicitly, is unmoved

New York is the only state shipping `perSourceExemptions` today
(`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NY.json`, one rule:
`matchSources: [nyStateOrLocal, federalCivilian]`, `matchStructures: [definedBenefit]`,
`treatment: full`). `RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json`
is untouched (not in `git status --porcelain`'s output). Every New York-named test
in the full run passed, including the ones that exercise the exact rule this task's
new cases sit beside: `NY Line 26 rule matches a NY state/local defined-benefit pension`,
`NY Line 26 rule matches a federal civilian defined-benefit pension`,
`NY Line 26 rule does NOT match an out-of-state defined-benefit pension (the defect
this design removes)`, `NY Line 26 rule does NOT match a NY-sourced defined-contribution
plan`, `NY Line 26 rule does NOT match governmentUnspecified`, `NY MFJ both age 59.5+: $25K
pension + $25K IRA -> $40K combined cap`, `Computed New York tax for a classified saved
pension row is unchanged by decoding through PersistenceManager`, `NY: NY state tax`
scenario tests (B, D), `New York partial pension exclusion ($20K)`, and others -- all
green, byte-for-byte the same behavior as before this task, because `federalCivilian`,
`nyStateOrLocal`, `definedBenefit` etc. were not renamed, reordered, or given new
matching semantics; only new, distinct cases were added alongside them.

## Exclusivity tests (`RetireSmartIRATests/Phase5bModelExtensionTests.swift`, new)

20 tests, all passing. Each pair below is proved in BOTH directions, which is
the entire point of the task (a plain case existing is not enough; it must not
leak into its sibling's rule):

- `ownStateOrLocal` matches a rule naming `ownStateOrLocal`, and does NOT match a
  rule naming `otherStateOrLocal`. `otherStateOrLocal` matches its own rule, and
  does NOT match a rule naming `ownStateOrLocal`. This is the Kansas KPERS defect
  from the brief, reproduced directly: a rule for KPERS naming `ownStateOrLocal`
  cannot accidentally exempt a California pension classified `otherStateOrLocal`.
- `uniformedServices` matches its own rule and does NOT match a rule naming
  `federalCivilian`; `federalCivilian` does NOT match a rule naming
  `uniformedServices`. This is Vermont's military-vs-CSRS split.
- `railroadRetirement` matches its own rule and does NOT match a rule naming
  `federalCivilian`; `federalCivilian` does NOT match a rule naming
  `railroadRetirement`. Also checked against `uniformedServices` in both
  directions, since all three are federal-adjacent.
- Round-trip: each new case survives `JSONEncoder`/`JSONDecoder` and appears in
  `PlanSource.allCases`.
- `isSurvivorBenefit` defaults to `nil` on a direct constructor call and on both
  `infer(incomeType:)` and `infer(accountType:)`; two classifications equal in
  structure/source remain `Equatable`-equal (confirms adding the property did not
  silently break equality for every existing comparison in `Phase3bClassificationTests`).
- Two decode-trap tests (below).

## User-save decode fallback verification

Verified by running the real production path, not by inspection alone, following
the exact pattern `Phase3bPersistenceTests` used to prove the original Phase 3b fix:

1. **Reachability (forward path):** `newCaseDecodesCorrectlyThroughUserSavePath`
   seeds a genuine `UserDefaults` suite with a saved income row carrying
   `"planSource": "ownStateOrLocal"`, runs it through the real
   `PersistenceManager.loadAll`, and asserts the decoded `IncomeSource.planSource
   == .ownStateOrLocal`. Confirms the new case is reachable through the shipped
   decode path, not only through a rule built directly in a unit test.
2. **Fallback (the decode trap itself):** `unrecognisedFutureCaseFallsBackToUnknown`
   seeds two saved income rows, one with `"planSource": "notARealSourceFromAnEvenLaterBuild"`
   (simulating a save written by a build with cases this build does not have),
   through the same real `PersistenceManager.loadAll` path, and asserts both rows
   survive (`count == 2`), the corrupted row resolves to `.unknown` rather than
   throwing, and `PlanClassificationUserSaveDecoding.unrecognisedClassificationEncountered`
   is set.

I did not just assume `PlanClassificationUserSaveDecoding.decode` still works because
its signature is generic (`T: RetirementPlanClassificationCase`) -- I ran it, because
"requires no edit" is a claim that needs to be run, not assumed. `PlanClassificationUserSaveDecoding.swift`
was in fact NOT edited (confirmed by `git diff`), and both tests above passed, which
is what makes that claim true rather than assumed.

## Full-suite output

Foreground `xcodebuild test`, `timeout: 600000`, ran to completion (no backgrounding, no Monitor):

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
```

Tail of the run:

```
Test run with 1877 tests in 294 suites passed after 326.332 seconds.
...
** TEST SUCCEEDED **
```

XCTest summary from the same run:

```
Test Suite 'RetireSmartIRATests.xctest' passed at 2026-08-04 23:50:18.354.
	 Executed 509 tests, with 0 failures (0 unexpected) in 22.029 (22.208) seconds
Test Suite 'All tests' passed at 2026-08-04 23:50:18.354.
	 Executed 509 tests, with 0 failures (0 unexpected) in 22.029 (22.209) seconds
```

1877 = 1857 baseline Swift Testing + 20 new (`Phase5bModelExtensionTests`).
294 suites = 293 baseline + 1 new suite. 509 XCTest, 0 failures, matches the
brief's stated baseline exactly. 0 failures across both test systems.

## MultiYearPerfTests re-run in isolation

Per the brief's note about a known pre-existing wall-clock flake, re-ran this
suite alone rather than reading anything into its timing inside the full run:

```
xcodebuild test -project .../RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/MultiYearPerfTests
...
Test run with 4 tests in 1 suite passed after 29.616 seconds.
** TEST SUCCEEDED **
```

Passed cleanly in isolation. No regression; not called out further.

## Em dash check

Checked all three touched/added files (both modified production files plus the
new test file) with a Python UTF-8 scan for U+2014, not just `grep` (which can
silently mismatch on locale/encoding):

```
No em dash characters found in any of the three files.
```

## Deviations

- **Survivor flag placement**: see "Placement decision" above -- put on
  `RetirementPlanClassification` rather than `PerSourceExemptionRule`, reasoned
  from "classified-source type" and the struct's own doc comment. Both files
  the brief named were still modified; `RetirementPlanClassification.swift` doing
  more of the work than `PerSourceExemptionRule.swift` (which only gained a
  doc comment) reflects that `PerSourceExemptionRule.matches()` needed zero
  functional change for the new cases to be correctly exclusive -- the
  containment logic it already had covers them for free, which is itself part
  of the inertness proof.
- No other deviations. No golden fixture, baseline, or movement-ledger file was
  touched. No existing `PlanSource`/`PlanStructure` case was renamed, reordered,
  or given new matching semantics.

## Critical fix: isSurvivorBenefit was unreachable and silently lossy

A reviewer compiled `let isSurvivorBenefit: Bool? = nil` in isolation and established
three facts by execution, not reasoning: the synthesized memberwise initializer
rejects any argument for it ("extra argument in call"), the compiler warns that
the property "will not be decoded because it is declared with an initial value
which cannot be overwritten," and, worst of all, decoding JSON that explicitly
contains `"isSurvivorBenefit": true` succeeds and produces `nil`, with no error
and no diagnostic. That last fact is the actual defect: not merely useless, but
silently lossy in a way that matches the class of failure Phase 3b's decode-trap
lesson exists to prevent.

### RED, captured by compiling, not by inspection

Before touching the property, I added the test that constructs a classification
with `isSurvivorBenefit: true` to `Phase5bModelExtensionTests.swift` and ran
`xcodebuild build-for-testing` against the unmodified `let` declaration. It did
not compile:

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRATests/Phase5bModelExtensionTests.swift:173:32: error: extra argument 'isSurvivorBenefit' in call
            isSurvivorBenefit: true
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~
```

Matches the reviewer's finding exactly. That non-compile is itself the proof
that no call site could ever construct the type with a non-nil value under the
old declaration.

### Fix

Changed `let isSurvivorBenefit: Bool? = nil` to `var isSurvivorBenefit: Bool? = nil`
in `RetireSmartIRA/RetirementPlanClassification.swift`. A `var` with a default
value is included in the synthesized memberwise initializer as an overridable
default parameter, and synthesized `Decodable` treats a present key as an
overwrite of that default rather than as a value the type can never hold. The
default itself is unchanged (`nil`), so every existing call site and every
already-stored fixture or user save still decodes and constructs exactly as
before.

Also corrected the doc comment on the property, which previously claimed the
synthesized initializer and `Decodable` conformance "carry the same nil default"
in a way that implied later wiring was already safe. Per the compiler evidence
above, under `let` neither one did: both locked the value at `nil` permanently.
The comment now states what the code actually does after the fix: a present key
decodes to the value it contains, a missing key still resolves to `nil`, and no
existing call site needed to change.

### Tests added, beside the existing exclusivity tests in `Phase5bModelExtensionTests.swift`

1. `survivorFlagIsConstructibleAndReadsBack`: constructs a classification with
   `isSurvivorBenefit: true` via the memberwise initializer and asserts it reads
   back as `true`. Under the old `let` declaration this test does not compile at
   all, which is the RED proof above; it only compiles and passes after the fix.
2. `survivorFlagDecodesPresentKeyAsTrue`: decodes
   `{"structure": "definedBenefit", "source": "federalCivilian", "isSurvivorBenefit": true}`
   through `JSONDecoder` directly against `RetirementPlanClassification` and
   asserts the result is `true`, not `nil`. This is the silently-lossy half of
   the finding, proved by decoding real JSON rather than by reading the type
   declaration.
3. `survivorFlagDecodesMissingKeyAsNil`: decodes the same shape with the key
   omitted and asserts `nil`, confirming every fixture and user save written
   before this flag existed is unaffected by the fix.

### Bool vs Bool?: kept Bool?, reasoned explicitly

The reviewer flagged, as a style preference rather than a defect, that a plain
`Bool` defaulting to `false` might be simpler than `Bool?` defaulting to `nil`,
since (unlike `PlanStructure.unknown` / `PlanSource.unknown`) there is no
"not yet classified" third state being modelled here. I considered it and kept
`Bool?`: there IS a genuine third state, because a migrated `federalCivilian`
record has never been asked whether it is a survivor benefit, and collapsing
that "never asked" state into `false` would assert "known not a survivor"
for a record where nobody has actually answered that question, exactly the
kind of guessed-default the rest of this file goes out of its way to avoid by
giving `PlanStructure`/`PlanSource` an explicit `.unknown` case instead of
picking a default case. `Bool?` preserves that same discipline for a boolean
dimension.

### Scope confirmation

Production diff is limited to `RetireSmartIRA/RetirementPlanClassification.swift`
(the `let` to `var` change and the doc comment correction). No field was added
to `IncomeSource`, `IRAAccount`, `PerSourceExemptionRule`, `ClassifiedPensionSource`,
or `GoldenScenarioSingleYearTests`; no `matches()` signature changed; no
`DataManager.matchedPerSourceRule` pass-through was added. That is the known
downstream chain the reviewer mapped for the DC task that consumes this flag,
recorded here so it is not re-derived: a field on `IncomeSource` and
`IRAAccount`, a `matchIsSurvivorBenefit` on `PerSourceExemptionRule`, a
parameter on `matches()`, a pass-through in `DataManager.matchedPerSourceRule`,
a field on the fixture type `ClassifiedPensionSource`, and a bridge in
`GoldenScenarioSingleYearTests.singleYearStateTax`. None of it is done here.

### Full-suite output after the fix

Foreground `xcodebuild test`, `timeout: 600000`, ran to completion:

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
```

```
Test Suite 'RetireSmartIRATests.xctest' passed at 2026-08-05 00:13:34.142.
	 Executed 509 tests, with 0 failures (0 unexpected) in 21.363 (21.734) seconds
✔ Test run with 1880 tests in 294 suites passed after 318.429 seconds.
** TEST SUCCEEDED **
```

1880 = 1877 baseline Swift Testing (already including the prior 20 Phase 5b
Task 1 tests) + 3 new tests from this fix. 509 XCTest, 0 failures, unchanged
from baseline. 0 failures across both test systems. Log scanned for "failed"/
"failure" outside "0 failures" lines; only hits are test NAMES containing the
word "failure" (e.g. "reports its OWN failure"), all passing.

`MultiYearPerfTests` re-run in isolation per the brief's note about a known
pre-existing wall-clock flake:

```
xcodebuild test ... -only-testing:RetireSmartIRATests/MultiYearPerfTests
✔ Test run with 4 tests in 1 suite passed after 29.669 seconds.
** TEST SUCCEEDED **
```

Passed cleanly in isolation, consistent with the known flake, not a regression.

### Inertness re-confirmed

`git status --porcelain` and `git diff --stat` show exactly two modified files:
`RetireSmartIRA/RetirementPlanClassification.swift` and
`RetireSmartIRATests/Phase5bModelExtensionTests.swift`. No baseline file, no
movement ledger, no golden fixture touched.

### Em dash check

Scanned both touched files with a Python UTF-8 scan for the literal em dash
character. None found.
