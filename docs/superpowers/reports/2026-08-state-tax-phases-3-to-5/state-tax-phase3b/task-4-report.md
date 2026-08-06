# Task 4 report: New York, the only jurisdiction whose numbers move

Status: DONE
HEAD before this task: `24f7bf4`

## Summary

New York's IT-201 Line 26 (government pension, uncapped) now ships as `perSourceExemptions`, a
new ordered, first-match-wins rule list on `RetirementIncomeExemptions`. A `.pension`/`.rmd`
`IncomeSource` row or `RetirementDistributionComponent` whose `(structure, source)` matches a rule
is excluded PER THE RULE'S OWN TREATMENT, unconditionally (no age gate -- Line 26 has none), and
contributes nothing to the shared $20,000 Line 29 cap. Everything unmatched pools exactly as
before and flows into the existing, untouched `pensionExemption`/`iraWithdrawalExemption` /
`pensionAndIRAShareSingleCap` / `exemptionAppliesPerIndividual` machinery. The partition runs once,
before that machinery, never per component inside a loop. New York's shipped rule:

```swift
perSourceExemptions: [
    PerSourceExemptionRule(
        matchSources: [.nyStateOrLocal, .federalCivilian],
        matchStructures: [.definedBenefit],
        treatment: .full)
]
```

Both the engine (`TaxCalculationEngine.applyRetirementExemptions`) and the `DataManager` mirror
(`stateTaxBreakdown`) implement the partition independently (per the phase's hand-duplication
convention), sharing only the rule-MATCHING predicate
(`RetirementIncomeExemptions.matchedPerSourceRule(structure:source:)`), so the two surfaces can
never disagree about which rule matched, only (in principle) about how they apply it -- and they
were proven, by mutation, to apply it the same way.

## Step 0a: the unguarded-pooling mutation, both surfaces

Added one test per surface reproducing the reviewer's exact worked case (`.partial(maxExempt:
20_000)`, flat 10% state, single, age 65, income $60,000, two $15,000 components) BEFORE touching
anything else:
- Engine: `Phase3bDistributionComponentTests.capAppliesOncePooledNotPerComponent`
- Mirror: `Phase3bDistributionComponentMirrorTests.mirrorCapAppliesOncePooledNotPerComponent`

Both passed immediately against Task 3's code as committed (pooling was already correct; only the
TEST was missing). Proved they discriminate by making the exact mutation the review described --
applying the $20,000 cap to each component individually instead of to the pooled sum -- in both
`TaxCalculationEngine.swift`'s and `DataManager.swift`'s non-shared-cap IRA branch, running, and
reverting:

```
✘ Test "The shared cap applies ONCE to the pooled component sum, not once per component"
  Expectation failed: (tax → 3000.0) == (4_000 → 4000.0)
✘ Test "The mirror applies the shared cap ONCE to the pooled component sum, not once per component"
  Expectation failed: (pooled.iraExemptAmount → 30000.0) == (20_000 → 20000.0)
```

Exactly the reviewer's predicted wrong values ($3,000 tax, $30,000 `iraExemptAmount`). Reverted;
targeted suite (12/12, then 13/13 after 0c) green again.

### Step 0b: corrected the three misleading "synthesises .unknown component" comments

`RetirementDistributionComponent.swift:78-80` (doc comment on `resolvePooledAmount`),
`TaxCalculationEngine.swift`'s `distributionComponents:` parameter doc comment, and its two call
sites in `TaxCalculationEngine.swift` and `DataManager.swift` all claimed the `nil` path
"synthesises one `.unknown` component." It does not -- `resolvePooledAmount`'s `guard let
components else { return scalar }` short-circuits straight to the scalar; no
`RetirementDistributionComponent` is ever constructed. Corrected all four comments to say so
explicitly, while noting the two are numerically identical (which is presumably why the wrong
description felt natural).

### Step 0c: named the sum-invariant tolerance as a constant

Added `RetirementDistributionComponent.sumInvariantTolerance: Double = 0.01`, used it in
`sumInvariantHolds`, and added `sumInvariantToleranceIsOneCent` asserting `== 0.01` directly.
`sumInvariantBoundary` only ever proved the tolerance sits in `[0.005, 0.02)` (two probe points
bracketing an interval); this closes that gap.

## Citation statement (golden scenarios)

I opened both `sourceURL`s used in `GoldenScenarios/statetax-2026-NY.golden.json` via WebFetch and
cross-checked with an independent WebSearch pass (Thomson Reuters UltraTax CS, LegalClarity,
TaxAct, Drake Software, all describing the same two lines) before writing any expected value:

- `https://www.tax.ny.gov/forms/current-forms/it/it201i.htm` (IT-201 instructions). Confirmed
  directly from this page: **Line 26** ("Government Pension Subtraction") -- eligibility is
  "officer, employee, or beneficiary of an officer or employee" of NYS (incl. SUNY/CUNY), certain
  named public authorities (MTA Police, MABSTOA, LIRR), NY local governments, or the US/its
  territories/DC; no dollar cap; explicitly EXCLUDES "periodic distributions from government (IRC
  Section 457) deferred compensation plans" and "any portion attributable to contributions... to a
  supplemental annuity plan which was funded through a salary reduction program" (a 403(b) is
  exactly such a plan, even under a government employer). **Line 29** ("Pension and Annuity Income
  Exclusion," $20,000) -- age 59 1/2, per person, and its qualifying income explicitly does "not
  include" amounts already subtracted on Line 26 (the two tracks are independent, confirming the
  government pension consumes none of the $20,000); IRC Section 403(b) employer-purchased
  annuities DO qualify for Line 29, IRC Section 457 government deferred comp does NOT.
- `https://www.tax.ny.gov/pit/file/information_for_seniors.htm` ("Information for retired
  persons"). Confirmed directly: the government-pension exclusion covers "a pension or other
  distribution from a New York State or local government pension plan or federal government
  pension plan," "regardless of your age," and eligibility is officer/employee/beneficiary of NYS,
  its political subdivisions, or the US -- a closed list that does not include another state's
  government, which is the basis for golden case 4 (out-of-state pension is NOT Line 26 income).

Neither page states in so many words "a California pension does not qualify" -- I checked for that
exact sentence via a second WebSearch pass and did not find one -- so golden case 4's citation is
explicit that the Line 26 eligibility list is closed and does not name any other state, which is
the same conclusion the design doc's own section 2 already draws (the case this design was revised
to add a jurisdiction dimension specifically to prevent). I did not find, and would flag rather
than silently accept, any citation implying the opposite.

## Step 2: RED transcript (cases 1 and 2 fail against pre-fix behavior)

Ran BEFORE Step 3 (before `perSourceExemptions` existed as a field) -- the classified `IncomeSource`
rows compile fine (Task 2 already added `planStructure`/`planSource`), but the pre-Task-4 engine
never consults them for exemption purposes, so a classified NY government pension is treated
exactly like an unclassified one: capped.

```
✘ Test "Single-year path matches each state's own published form" ... abbreviation → "NY"
  Expectation failed: (abs(actual - scenario.expectedStateTax) → 2695.25) < 0.01
  ↳ NY / NYC employee pension alone: fully excluded, Line 26: engine 3183.0, form says 487.75.
✘ Test "Single-year path matches each state's own published form" ... abbreviation → "NY"
  Expectation failed: (abs(actual - scenario.expectedStateTax) → 3720.0) < 0.01
  ↳ NY / NYC pension plus a private pension...: engine 3993.0, form says 273.0.
```

This is the empirical statement of Alan's bug: the pre-fix engine overstates his tax by $2,695.25
and $3,720.00 in these two hand-derived cases. Cases 3 (government 403(b)) and 4 (out-of-state
pension) already passed at this point, unchanged before and after the fix, because neither matches
Line 26 either way (structure mismatch for case 3, source mismatch for case 4).

After Step 5 (New York's rule live in both `configs2026Legacy` and the regenerated JSON), all four
cases pass:
```
✔ Test "Single-year path matches each state's own published form" with 5 test cases passed
```

## Step 4a: the five cap tests

New suite `Phase3bPerSourceExemptionCapTests` (7 tests: 5 cases, 2 with a mirror counterpart for
cases 1 and 4). All derived from the statute (NY Tax Law Section 612(c)(3)/(3-a), the same IT-201
citations above), using a flat-10%/no-deduction NY-shaped `configOverride` so expected values are
exact hand arithmetic rather than a bracket walk.

Case 1 (`twoPrivatePensionsShareOneCap` / `mirrorTwoPrivatePensionsShareOneCap`) is the one the
brief requires to discriminate against a per-component cap loop. Proved it by mutation: replaced
the shared-cap branch's pooled `combinedIncome` exclusion with a sum of per-pension-ROW exclusions
in both `TaxCalculationEngine.swift` and `DataManager.swift`, reran:

```
✘ "Two private pensions owned by the primary share ONE $20,000 cap, not two"
  Expectation failed: (tax → 0.0) == (1_000 → 1000.0)
✘ "The mirror shares ONE $20,000 cap across two private pensions, not two"
  Expectation failed: (breakdown.pensionExemptAmount → 30000.0) == (20_000 → 20000.0)
  Expectation failed: (breakdown.totalStateTax → 0.0) == (1_000 → 1000.0)
```

(Cases 2, 3 and 5 also failed under this same mutation, for the same underlying reason -- multiple
unmatched pooled amounts stopped sharing one cap; case 4 did not fail, because its single unmatched
row's per-row cap and pooled cap are algebraically identical when nothing else is pooled with it.)
Reverted both files; full 7/7 green again.

## Step 3: encoder fixtures extended, mutation proof

`RetirementIncomeExemptionsRoundTrip` and `retirementExemptionsEncodesExpectedJSONShape` (renamed
"thirteen" -> "fourteen" fields) both now carry a non-default, non-empty `perSourceExemptions`
value and assert it round-trips / appears correctly in raw JSON. Added
`perSourceExemptionsEncodingIsConditional`, proving the key is present only when non-empty, absent
when empty (this IS the mechanism behind Task 4's "appears in New York's file only" contract).
Proved it discriminates by mutation: removed the `if !perSourceExemptions.isEmpty` guard in
`StateTaxCodable.swift` so the key always encodes, reran:

```
✘ "perSourceExemptions is omitted from encoded JSON when empty, present when non-empty"
  Expectation failed: (absent["perSourceExemptions"] → (...)) 
```

Reverted; 22/22 green again.

## Step 5: JSON regeneration, deletion check, diff

Deletion check (per the brief's exact command): no output.
```
$ git diff --numstat RetireSmartIRA/Resources/StateTaxData/2026/ | awk '$2 != 0 {print "DELETION in " $3}'
(nothing)
```

`git diff --stat` on the JSON directory: only New York, 14 insertions, 0 deletions.
```
 .../Resources/StateTaxData/2026/statetax-2026-NY.json | 14 ++++++++++++++
 1 file changed, 14 insertions(+)
```

Full diff:
```json
+    "perSourceExemptions" : [
+      {
+        "matchSources" : [
+          "nyStateOrLocal",
+          "federalCivilian"
+        ],
+        "matchStructures" : [
+          "definedBenefit"
+        ],
+        "treatment" : {
+          "kind" : "full"
+        }
+      }
+    ],
```

Confirmed the production path (`StateTaxData.config(for:)`, which resolves through bundled JSON,
not `configs2026Legacy`) actually picks this up: before regenerating, the golden-scenario test
still failed with the OLD numbers (3183.0/3993.0) even though `configs2026Legacy`'s NY entry
already had the rule -- exactly the trap the brief named. After regenerating, all four NY cases
pass. `StateTaxJSONEquivalenceTests` (the Phase 1 Layer B gate, JSON vs. legacy table agreement for
all 51 states) stayed green throughout, because both tables were updated together.

## Step 5a: migration-gate mutation proof

Re-pointed `Phase3bPersistenceTests`. The original `computedStateTaxUnchangedByMigration` is KEPT
(still proves decode doesn't corrupt other fields for the pre-3b fixture, whose `.pension` row has
no classification keys at all) but its doc comment now states its real limitation. Added
`computedStateTaxUnchangedByMigrationForAClassifiedNewYorkPension`: decodes an inline, POST-3b-shaped
saved blob (`"planStructure": "definedBenefit", "planSource": "nyStateOrLocal"` keys PRESENT) through
the real `PersistenceManager.loadAll`, and asserts the computed NY tax matches a freshly built
equivalent, plus a same-test cross-check that the computed tax is strictly less than the same
pension classified `otherStateOrLocal` (proving the assertion isn't vacuously true).

Proved by mutation: temporarily forced `IncomeSource.init(from:)`'s `planSource` decode to always
return `.otherStateOrLocal` regardless of the saved value (the reviewer's exact "every decoded
classification wrong" mutation), reran:

```
✘ "Computed New York tax for a classified saved pension row is unchanged by decoding through PersistenceManager"
  Expectation failed: (decoded.first?.planSource → .otherStateOrLocal) == .nyStateOrLocal
  Expectation failed: (actual → 643.5) == (expected → 448.5)
  Expectation failed: (actual → 643.5) < (tax(for: [...otherStateOrLocal]))
```

(Four other tests in the same file also failed under this file-wide mutation, for the same reason;
irrelevant to this proof, which is specifically that THIS test now fails where it could not
before.) Reverted; 7/7 green again.

## Step 6: the baseline

Regenerated `RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json`
(`TEST_RUNNER_STATE_TAX_BASELINE=1`, `STATE_TAX_GENERATE`-style manual suite). Result: **byte-for-byte
identical to the checked-in file.**

```
$ md5 RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json
MD5 (...) = 34a121744f8edf3db7c440202a8c4d83
$ git show HEAD:RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json | md5
34a121744f8edf3db7c440202a8c4d83
$ git status --porcelain RetireSmartIRATests/Baselines/
(nothing)
```

**Zero entries moved, including New York.** This is the correct, verified outcome, not an
oversight: `StateTaxBehaviorBaselineTests.computedTax` builds every `.pension` row via
`IncomeSource(name: "Pension", type: .pension, annualAmount: scenario.pensionIncome)` with no
`planStructure`/`planSource` arguments, so every pension row in all 20 frozen scenarios resolves to
`.unknown`/`.unknown` by inference -- which New York's rule (`matchSources: [.nyStateOrLocal,
.federalCivilian]`) never matches. New York's numbers only move for a taxpayer whose pension is
EXPLICITLY classified as a NY government defined-benefit plan, which no baseline scenario is, and
which no real user's saved data is either until Task 6 ships the classification picker -- consistent
with Task 3's "still inert" framing and with the design doc's note that account/income
classification is stored but does nothing until its consuming rule ships. I inspected all 1,020
entries via the checksum-equality proof above rather than a line-by-line diff, since there is
nothing to inspect: the files are identical. Nothing non-New-York moved (trivially, since nothing
moved at all), so there is nothing to STOP and report. `StateTaxBehaviorBaselineTests` passes
against the unmodified checked-in fixture.

## Global constraints

**Em dash check** (added lines only, git diff, plus full-content scan of both new files -- a
previous report in this program asserted zero when there were four, so this is a `git diff`-scoped
Python scan, not a bare grep):
```
TOTAL ADDED-LINE EM DASHES: 0
RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json (new file): 0 em dashes
RetireSmartIRATests/Phase3bPerSourceExemptionCapTests.swift (new file): 0 em dashes
```

**`perSourceExemptions` grep, `DataManager.swift`:**
```
$ grep -n "perSourceExemptions" RetireSmartIRA/DataManager.swift
823:        // evaluated per row. Empty `exemptions.perSourceExemptions` (every
```
(One hit -- a doc comment. The mirror's actual logic calls the shared matching function by name;
`grep -n "matchedPerSourceRule" RetireSmartIRA/DataManager.swift` shows six call sites across the
pension-row partition, the RMD-row partition, and the distribution-component partition, confirming
the mirror is genuinely wired to the same rule-matching predicate the engine uses, not merely
carrying the field name in a comment.)

**`project.pbxproj`:** not touched (`git diff --stat -- RetireSmartIRA.xcodeproj/project.pbxproj`
empty).

**`configs2026Legacy` fallback:** not added. NY's `perSourceExemptions` rule was added to
`configs2026Legacy`'s existing NY entry (the source-of-truth table the JSON generator reads FROM,
per `StateTaxDataGeneratorTests`), then the 51 JSON files were regenerated from it -- not a runtime
fallback mechanism. `StateTaxData.config(for:)` itself is unchanged.

**`git diff --stat`:**
```
 RetireSmartIRA/DataManager.swift                   | 113 ++++++++++++++++---
 .../StateTaxData/2026/statetax-2026-NY.json        |  14 +++
 .../RetirementDistributionComponent.swift          |  33 ++++--
 RetireSmartIRA/StateTaxCodable.swift               |  11 +-
 RetireSmartIRA/StateTaxData.swift                  | 123 ++++++++++++++++++++-
 RetireSmartIRA/TaxCalculationEngine.swift          | 110 ++++++++++++++----
 RetireSmartIRATests/GoldenScenario.swift           |  20 ++++
 .../GoldenScenarioSingleYearTests.swift            |  56 +++++++++-
 .../Phase3bDistributionComponentTests.swift        |  94 ++++++++++++++++
 RetireSmartIRATests/Phase3bPersistenceTests.swift  | 102 +++++++++++++++--
 .../StateTaxCodableRoundTripTests.swift            |  62 ++++++++++-
 11 files changed, 677 insertions(+), 61 deletions(-)
```
Two new files staged separately (not counted above): `RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json`,
`RetireSmartIRATests/Phase3bPerSourceExemptionCapTests.swift`. No `ProjectionEngine.swift`, no
view. `RetireSmartIRA/IncomeModels.swift` was mutated (Step 5a proof) and reverted -- confirmed
zero net diff before staging.

## Full suite (run once, foreground)

```
Test run with 1703 tests in 283 suites passed after 322.918 seconds.
```
```
	 Executed 503 tests, with 0 failures (0 unexpected) in 21.717 (22.058) seconds
```
```
** TEST SUCCEEDED **
```

Growth from Task 3's 1691 ST / 282 suites to 1703 / 283 is exactly the 12 tests and 1 suite this
task added (3 from Step 0, 1 from Step 3, 7 + 1 new suite from Step 4a, 1 from Step 5a). 0 failures
either way.

**Tree-confirmation grep:**
```
$ grep -m3 "\.xcodeproj" p4-fullsuite.log
    cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj
```

## Commit

Staged explicit paths only (13 files: 6 modified production files, 5 modified test files, 2 new
test files); no `git add -A`.

## Review fixes

Six findings from the post-Task-4 review: three coverage/structure defects, three wording ones.
HEAD before this pass: `bbf631d`.

### Fix 1: two `PerSourceExemptionRule` types, one dead

`PerSourceExemptionRule.swift:19` declared a top-level type with `matches(structure:source:)`,
covered by seven tests in `Phase3bClassificationTests.swift`. `StateTaxData.swift:322` declared a
SECOND, nested `RetirementIncomeExemptions.PerSourceExemptionRule` with identical fields and its
own hand-rolled `matchedPerSourceRule` predicate. Production resolved to the nested one; the
top-level type, and the seven tests exercising it, were dead.

**Direction chosen: deleted the nested duplicate, kept the top-level type.** The brief's stated
preference, and the right one here: the top-level type already had its own file and its own
7-test suite, while the nested one had neither. Concretely:

- Deleted the nested `struct PerSourceExemptionRule` (`StateTaxData.swift:322-330` before this
  pass).
- Changed `matchedPerSourceRule(structure:source:)` to `perSourceExemptions.first {
  $0.matches(structure: structure, source: source) }` -- it now DELEGATES to
  `PerSourceExemptionRule.matches`, the one predicate the seven tests exercise, rather than
  re-deriving the same boolean logic inline. This is the part that actually closes the gap: unifying
  the type alone would still have left production running its own copy of the match logic next to a
  tested-but-unconsumed copy.
- Moved the hand-written `Equatable` conformance from `extension
  RetirementIncomeExemptions.PerSourceExemptionRule: Equatable` to `extension
  PerSourceExemptionRule: Equatable` (same body, only the target type changed).
- Re-pointed every remaining `RetirementIncomeExemptions.PerSourceExemptionRule(...)` construction
  site to the now-unambiguous bare `PerSourceExemptionRule(...)`: `StateTaxData.swift`'s New York
  config literal, `StateTaxCodable.swift`'s decode call, `Phase3bPerSourceExemptionCapTests.swift`,
  and three sites in `StateTaxCodableRoundTripTests.swift`.
- `Phase3bClassificationTests.swift` needed NO change -- it already wrote the bare, unqualified
  `PerSourceExemptionRule(...)`, which now resolves unambiguously to the surviving top-level type.

Confirmed exactly one type remains:
```
$ grep -rn "struct PerSourceExemptionRule" RetireSmartIRA/
RetireSmartIRA/PerSourceExemptionRule.swift:19:struct PerSourceExemptionRule: Codable, Sendable {
$ grep -rn "RetirementIncomeExemptions.PerSourceExemptionRule" RetireSmartIRA/ RetireSmartIRATests/
(nothing)
```

### Fix 2 + Fix 5: New York's `matchStructures` was unpinned; case 3's citation overclaimed

Golden case 3 (the government-403(b) fixture, the one fixture meant to guard the structure
dimension) used `planSource: "governmentUnspecified"`, which already fails `matchSources` --
so it never reached the `matchStructures` check, and blanking `matchStructures` in both the JSON
and the Swift table left all 43 pre-existing tests green.

Fixed by changing case 3's `planSource` to `"nyStateOrLocal"` (a NY state/local employee's 403(b),
exactly the reviewer's named failure scenario), renaming the case to make the regression-test intent
explicit, and adding a note to its `source` field explaining WHY this is the only fixture that
reaches the structure gate with a source that already clears `matchSources`.

Same edit narrowed Fix 5's overclaim: the old text asserted flatly "a 403(b) is exactly such a
salary-reduction supplemental plan," which doesn't hold for an employer-funded portion. Reworded to
scope the claim to the employee's own salary-reduction contributions, matching the form's actual
language ("any portion attributable to contributions you made").

Mutation proof (2a): blanked `matchStructures` to `[]` in BOTH
`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NY.json` and the `PerSourceExemptionRule(`
literal at `StateTaxData.swift`'s New York config (~line 1970), rebuilt
(`build-for-testing`, since a JSON-resource-only edit still needs a rebuild to land in the test
bundle), reran the golden/cap/JSON-equivalence suites:

```
✘ Test "Single-year path matches each state's own published form" recorded an issue with 1
  argument abbreviation → "NY" at GoldenScenarioSingleYearTests.swift:134:13: Expectation failed:
  (abs(actual - scenario.expectedStateTax) → 273.0) < 0.01
  ↳ NY / A NY state/local employee's 403(b): capped, because Line 26 excludes salary-reduction
    plans -- regression test for the structure dimension: engine 0.0, form says 273.0.
✘ Test "Single-year path matches each state's own published form" with 5 test cases failed after
  0.006 seconds with 1 issue.
✘ Test run with 9 tests in 3 suites failed after 0.151 seconds with 1 issue.
```

Reverted both files. `git diff -- RetireSmartIRA/StateTaxData.swift
RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NY.json` afterward shows `matchStructures`
back to `[.definedBenefit]` / `["definedBenefit"]` and nothing else changed by the mutation.

### Fix 3: the shared-cap mirror had no test catching "a matched amount still counts toward the cap"

`governmentPensionConsumesNoneOfSharedCap` (engine) and its mirror both used an unmatched private
pension of $25,000, ABOVE the $20,000 cap, so `min(pooled-with-government, 20_000)` and
`min(unmatched-alone, 20_000)` were both $20,000 regardless of whether the matched government
pension leaked into the shared-cap base. Adding it back in (the reviewer's exact mutation) passed
both tests silently.

Fixed by dropping the unmatched private pension to $15,000 (below the cap), so the two bases
diverge ($65,000 pooled-with-government vs $15,000 unmatched-alone). Also raised `income` to
$115,000 (engine) / added a $50,000 `.interest` row (mirror, which has no separate `income:`
parameter and derives gross income from `incomeSources`) so the extra exclusion the mutation
produces doesn't ALSO get masked by flooring taxable income at $0 -- the same saturation trap the
case already exists to rule out on the cap side, just showing up one level down via the zero floor
instead of via `min()`. `.interest` is ordinary income, never inspected by `matchedPerSourceRule`,
so it doesn't perturb the exemption arithmetic itself.

Mutation proof (2b, engine): changed `TaxCalculationEngine.swift`'s shared-cap branch from
`let combinedIncome = pensionIncome + iraIncome` to `... + perSourceExcludedPension`, rebuilt, reran:

```
✘ Test "An uncapped government pension consumes none of the $20,000 shared with capped private
  income" recorded an issue at Phase3bPerSourceExemptionCapTests.swift:203:9: Expectation failed:
  (tax → 4500.0) == (5_000 → 5000.0)
✘ Test run with 7 tests in 1 suite failed after 0.007 seconds with 1 issue.
```

Reverted; `git diff -- RetireSmartIRA/TaxCalculationEngine.swift` empty afterward.

Mutation proof (2c, mirror): same edit in `DataManager.swift`'s shared-cap branch (`let
combinedIncome = pooledPensionIncome + pooledIraIncome` → `... + perSourceExcludedPension`),
rebuilt, reran:

```
✘ Test "The mirror: an uncapped government pension consumes none of the shared cap" recorded an
  issue at Phase3bPerSourceExemptionCapTests.swift:250:9: Expectation failed:
  (breakdown.totalStateTax → 4500.0) == (5_000 → 5000.0)
✘ Test run with 7 tests in 1 suite failed after 0.002 seconds with 1 issue.
```

(`breakdown.pensionExemptAmount` did not itself diverge under this mutation -- the mirror's
pension/IRA display-attribution split, `pooledPensionShare = min(pooledPensionIncome,
combinedExempt)`, happens to saturate at $15,000 either way here, so the extra $5,000 the mutation
adds shows up in `iraExemptAmt` instead. `totalStateTax`, the figure that actually reflects the tax
computation, discriminates correctly, and the named test fails as a whole.) Reverted; `git diff --
RetireSmartIRA/DataManager.swift` empty afterward.

All three named mutations now discriminate. `git diff --stat` after all three reverts touches only
`RetireSmartIRA/StateTaxData.swift`, `RetireSmartIRA/StateTaxCodable.swift`,
`RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`,
`RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json`,
`RetireSmartIRATests/Phase3bPerSourceExemptionCapTests.swift`, and
`RetireSmartIRATests/StateTaxCodableRoundTripTests.swift` -- no leftover mutation state in
`TaxCalculationEngine.swift`, `DataManager.swift`, or the production JSON.

### Fix 4: golden case 1's citation pointed at the wrong page

The verbatim quote ending "regardless of your age" does not appear on `it201i.htm` (the cited
`sourceURL`); it appears on `information_for_seniors.htm` (already case 4's `sourceURL`). Fixed by
switching case 1's `sourceURL` to the seniors page and re-labeling the `source` field's opening
clause to name that page instead of "IT-201 instructions." The quoted sentence itself was already
correct and is unchanged.

### Fix 6: the "first pilot state with a nonzero `stateDeduction`" comment was wrong

`GoldenScenarioSingleYearTests.swift`'s doc comment claimed New York was the first pilot state
whose `stateDeduction` is nonzero. Mississippi's is also nonzero (`.fixed(single: 2_300, married:
4_600)`, `StateTaxData.swift:933`). Corrected the comment: New York is the first state whose
`stateDeduction` actually CHANGES this harness's computed answer; Mississippi's is numerically inert
for its one current fixture only because that fixture's retirement-income exemptions already zero
out taxable income before the state standard deduction has anything left to act on, so a future
Mississippi fixture with surviving taxable income will be affected by the same
`stateStandardDeduction` switch.

### Baseline: unchanged, not regenerated

```
$ git status --porcelain RetireSmartIRATests/Baselines/
(nothing)
$ md5 RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json
MD5 (.../statetax-behavior-baseline-2026.json) = 34a121744f8edf3db7c440202a8c4d83
$ git show HEAD:RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json | md5
34a121744f8edf3db7c440202a8c4d83
```
Byte-identical to the checked-in file (same checksum as Task 4's own report). None of the six fixes
touch `StateTaxBehaviorBaselineTests` or its fixture, and no baseline scenario carries a classified
pension row, so nothing could have moved.

### Full suite (run once, foreground)

```
$ xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
...
✔ Test run with 1703 tests in 283 suites passed after 316.938 seconds.
...
	 Executed 503 tests, with 0 failures (0 unexpected) in 22.018 (22.350) seconds
...
** TEST SUCCEEDED **
```

Same test counts as Task 4's own full-suite run (1703 Swift Testing / 283 suites, 503 XCTest) --
this pass only reworded/renumbered existing tests and deleted a dead type, adding no new `@Test`
functions and removing none.

**Tree-confirmation grep:**
```
$ grep -m5 "\.xcodeproj" full-suite.log
    /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination platform=macOS
    cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj
```

**Em dash check** (`git diff | grep -o $'\xe2\x80\x94' | wc -l`, the UTF-8 em dash character): `0`.

**Hard constraints:** `project.pbxproj` not touched (`git diff --stat -- RetireSmartIRA.xcodeproj/project.pbxproj`
empty). No jurisdiction other than New York's `perSourceExemptions` changed --
`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NY.json` and the New York literal in
`StateTaxData.swift` are the only production files this pass edited, and both ended the pass
byte-identical to before it (the mutation proofs edited and reverted them; the net diff is zero).
`StateTaxBehaviorBaselineTests.swift` and its fixture untouched. `ProjectionEngine.swift` and every
view untouched.

### Commit (review-fixes pass)

Staged explicit paths only, no `git add -A`:
`RetireSmartIRA/StateTaxData.swift`, `RetireSmartIRA/StateTaxCodable.swift`,
`RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`,
`RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json`,
`RetireSmartIRATests/Phase3bPerSourceExemptionCapTests.swift`,
`RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`.

Message: `fix(state-tax): one rule type, and guard New York's structure dimension`
