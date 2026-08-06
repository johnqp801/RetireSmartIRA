# Task 5 report: Georgia, the stale rate and standard deduction

## Rate and deduction, before and after

| Field | Before | After | Authority |
|---|---|---|---|
| `taxSystem.rate` | 0.0539 (5.39%) | 0.0499 (4.99%) | HB 463 (Economic Growth and Tax Relief Act of 2026), signed 2026-05-11; Gov. Kemp signing announcement |
| `stateDeduction.single` | $12,000 | $15,000 | Georgia DOR, Important Tax Updates page |
| `stateDeduction.married` | $24,000 | $30,000 | Georgia DOR, Important Tax Updates page |

Both changes are retroactive to 2026-01-01 per the same DOR page. I also populated the previously-empty `verification` block (`billReferences`, `knownLimitations`, `lastVerified`, `primarySources`) since it shipped empty in the config, and used it to record that Georgia's exclusion cap rises to $70,000 in TY2027 (not encoded; this config is TY2026 only). I looked for an existing "diary item" recording that TY2027 fact inside `statetax-2026-GA.golden.json` as the brief described, and did not find one (the fixture's schema is only `state`/`taxYear`/`scenarios`, no notes/diary field, and none of the five scenarios' `source` text mentions TY2027). The `knownLimitations` entry I added is the closest analogue and is the only place TY2027 is now recorded; flagging this discrepancy rather than asserting the diary item exists.

## Retirement exclusion tiers: UNCHANGED

`retirementExemptions` in `statetax-2026-GA.json` was not touched in any way: `earlyAgeTier` ($35,000, ages 62-64), `pensionExemption`/`iraWithdrawalExemption` ($65,000, age 65+, `pensionAndIRAShareSingleCap: true`), `exemptionAppliesPerIndividual: true`, `exemptionAttribution: household`, `distributionMinAge: 59`, `regularExemptionMinAge: 65`, `socialSecurityExempt: true` are byte-identical to the pre-change file. Confirmed by `git diff` on the JSON (only `stateDeduction`, `taxSystem.rate`, and `verification` changed) and by all five golden cases resolving from that one edit, exactly as the brief predicted.

## knownDefect blocks

Deleted: all 5, one per scenario in `statetax-2026-GA.golden.json` (below-62-floor, 62-64 tier, above-65K-cap, MFJ both-qualify doubling, MFJ only-primary-qualifies). None remain; Georgia's golden fixture now has zero open defects.

## Baseline movements: 19 GA keys moved, all recorded

All MEASURED via the failing baseline suite, never predicted:

| Key | Before | After |
|---|---|---|
| single 55, distributions only | 3234.0 | 2994.0 |
| single 58, distributions only | 3234.0 | 2994.0 |
| single 59, distributions only | 3234.0 | 2994.0 |
| single 55 rmd rows not scenario distributions | 3234.0 | 2994.0 |
| MFJ 57 with spouse 61 | 6468.0 | 5988.0 |
| MFJ 61 with spouse 56 | 6468.0 | 5988.0 |
| MFJ 56 with spouse 55, both below the gate | 6468.0 | 5988.0 |
| single 54 conversion 80k | 7546.000000000001 | 6986.0 |
| single 62 conversion 100k no withholding | 7546.000000000001 | 6986.0 |
| single 62 conversion 100k with 22k withheld | 7546.000000000001 | 6986.0 |
| single 63 in the early age tier | 1994.3000000000002 | 1846.3 |
| single 65 pension, total 95k | 1617.0 | 1497.0 |
| single 68 pension, total 120k | 2964.5 | 2744.5 |
| single 68 pension, total 140k | 4042.5000000000005 | 3742.5 |
| MFJ 68 both qualify, pension + IRA | 754.6 | 698.6 |
| MFJ 68 pension, total 120k | 431.20000000000005 | 399.2 |
| MFJ 68 pension, total 140k | 1509.2 | 1397.2 |
| MFJ 68 pension, total 200k over the cliff | 4743.200000000001 | 4391.2 |
| MFJ status but spouse disabled, 66 | 1563.1000000000001 | 1447.1 |

`GA|zero income` (0) did not move, as expected. Each entry names one of the 5 GA golden case names (machine-checked by `BaselineMovementLedgerTests`) grouped by which exclusion tier the scenario exercises (below-62-floor, 62-64 tier, above-65K-cap-single, MFJ-both-qualify-doubling, MFJ-only-primary-qualifies), with a one-sentence justification.

## Equivalence lists

- **`phase5CorrectedJurisdictions`** (Layer B, "Append here, and only here"): added `.georgia`. Required for any corrected jurisdiction, per the comment's own rule -- a corrected jurisdiction must diverge from the frozen legacy table.
- **`layerAProvenDivergentJurisdictions`** (the 10-scenario grid gate): also added `.georgia`. Reasoning: `taxSystem.rate` and `stateDeduction` are consulted for every scenario with positive taxable income, and 9 of that grid's 10 scenarios have non-zero income (only "zero income" computes $0 identically either way, same as Iowa's own listed reasoning). Confirmed by running the suite: GA passed on both lists with the "must diverge" assertion satisfied.

## Other suite: StateRetirementExemptionTests, 3 tests updated

All three failures were legitimate consequences of the correction, not new defects, diagnosed and fixed:

1. **`gaRetirementAgeIRAExceedsCap`**: pinned an $80K IRA distribution expecting nonzero tax (`~$162` under the stale $12K deduction / 5.39% rate). Under HB 463's corrected $15K deduction, $80K - $65K cap = $15K excess, and $15K - $15K deduction = exactly $0. The test's own input landed precisely on the new zero-crossing point. Changed the input to $100K (matching the golden fixture's own age-66/$100K-pension case, $998.00), which restores a nonzero, non-boundary result and keeps the test meaningful.
2. **`gaAge64UsesEarlyTier35K`**: pinned `tax > 500 && tax < 1500` against the old ~$701 estimate. Corrected math: ($60K - $15K deduction) - $35K early-tier cap = $10K taxable, $10K x 0.0499 = $499.00, just under the old lower bound. Updated the bound to `tax > 400 && tax < 600` and the comment to cite HB 463 and the matching golden case.
3. **`gaSharedCapBothIncomeTypes`**: used $40K pension + $40K IRA ($80K total) specifically to distinguish the shared-$65K-cap fix (nonzero tax) from a hypothetical pre-fix double-cap bug ($0 tax, since $80K < the buggy $130K double cap). Under HB 463's $15K deduction, $80K also became the exact zero-crossing point for the corrected math too, so both the bug and the fix now compute $0 on that input, destroying the test's discriminating power. Bumped both incomes to $50K each ($100K total, still under the $130K double cap so it would still catch the old bug, comfortably above the new zero-crossing point): $100K - $65K cap = $35K, minus $15K deduction = $20K taxable, $998.00, again matching the golden fixture's age-66/$100K case.

All three now pass with wide, defensible margins; full documentation of the HB 463 arithmetic is in the code comments. No production Swift file was touched; only this test file.

## Full suite results

Confined to Georgia/movement suites (green after both rounds of fixes):
```
✔ Test run with 8 tests in 5 suites passed after 0.399 seconds.
```
(StateTaxBehaviorBaselineTests, BaselineMovementLedgerTests, GoldenScenarioSingleYearTests, StateTaxJSONStructuralEquivalenceTests, StateTaxJSONEquivalenceTests)

`StateRetirementExemptionTests` in isolation after the fix:
```
✔ Test run with 48 tests in 1 suite passed after 0.123 seconds.
```

Full suite:
```
✔ Test run with 1857 tests in 293 suites failed after 331.362 seconds with 1 issue.
Failing tests:
	MultiYearPerfTests.persona2_mfjCouple35Years()
```
Only failure is the known pre-existing wall-clock flake (35-year MFJ compute() performance budget, unrelated to state tax data). Re-run twice in isolation: 15.567s and (second run also over budget) against a 15.0s budget, both non-deterministic wall-clock misses, not a regression from this change -- Georgia's config touches only per-year tax computation inputs, not the optimizer's iteration count or timing. XCTest suite (509 tests) was unaffected; the same full run reported the combined count with no XCTest failures listed.

509 XCTest tests ran as part of the same full-suite invocation; none appear in the "Failing tests" list, so all 509 passed.

## Confined production diff

Only one production file touched, exactly as scoped:

```
RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json | 15 ++++++++-------
```
(shown in full above, under "Rate and deduction"). No Swift file under `RetireSmartIRA/` was modified.

Test-side files touched:
```
RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json  | 152 +++++++++++++
RetireSmartIRATests/GoldenScenarios/statetax-2026-GA.golden.json     |  35 +---
RetireSmartIRATests/StateRetirementExemptionTests.swift              |  61 ++++--
RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift               |  12 +-
```

## Em dash check

`git diff` on every line I added, across all 5 changed files, contains zero em dash characters (U+2014). Pre-existing em dashes in untouched lines of `StateRetirementExemptionTests.swift` (added by earlier work, not this task) were left as-is since editing unrelated lines was out of scope.
