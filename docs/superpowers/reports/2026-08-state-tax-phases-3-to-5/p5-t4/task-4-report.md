# Task 4 report: New Mexico, the deleted bracket schedule

## Bracket arrays, before and after

`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NM.json`, `taxSystem.single` and `taxSystem.married`.

Before (pre-HB252, deleted from law effective TY2025, the schedule the engine was still running):

- single: 1.7%@0, 3.2%@5,500, 4.7%@11,000, 4.9%@16,000, 5.9%@210,000
- married: 1.7%@0, 3.2%@8,000, 4.7%@16,000, 4.9%@24,000, 5.9%@315,000

After (enacted HB252, Laws 2024, Chapter 67, Section 5, effective TY2025, unchanged for TY2026):

- single: 1.5%@0, 3.2%@5,500, 4.3%@16,500, 4.7%@33,500, 4.9%@66,500, 5.9%@210,000
- married: 1.5%@0, 3.2%@8,000, 4.3%@25,000, 4.7%@50,000, 4.9%@100,000, 5.9%@315,000

The single table matches the golden fixture's case-1 `source` quote verbatim. The married table is not fully quoted in the golden fixture (only the first bracket, "$8,000 -> 1.5%", is stated in case 3's arithmetic). I independently fetched the enrolled/committee-substitute bill text (`https://www.nmlegis.gov/Sessions/24%20Regular/bills/house/HB0252TRS.pdf`, printed page 16, section A "For married individuals filing joint returns, heads of household and surviving spouses") to confirm the full married table before writing it. It reads: not over $8,000 -> 1.5%; $8,000-$25,000 -> $120 + 3.2%; $25,000-$50,000 -> $664 + 4.3%; $50,000-$100,000 -> $1,739 + 4.7%; $100,000-$315,000 -> $4,089 + 4.9%; over $315,000 -> $14,624 + 5.9%. The single table on printed page 17 of the same PDF matches the fixture's quote exactly, corroborating the fixture's own citation. All five golden case arithmetics (752.70, 12.75, 32.25, 0.00, 1275.95) reproduce exactly under threshold/rate-only bracket application, confirming the base amounts in the bill text are internally consistent with pure marginal-rate computation and did not need to be encoded separately (`TaxBracket` has no base-amount field).

## knownDefect blocks: deleted vs remaining

Deleted (2, fully resolved by the bracket fix alone):

- "single, age 55 (below 65, no PIT-ADJ age exemption), stale pre-HB252 bracket schedule is the dominant gap" -- engine now computes 752.70, matches the form exactly. No PIT-ADJ exemption applies at age 55, so this case isolates the bracket defect alone.
- "single, age 70, a $30,000 Roth conversion pushes AGI above BOTH the PIT-ADJ exemption cliff and further into the correct HB252 bracket schedule" -- engine now computes 1,275.95, matches the form exactly. The PIT-ADJ exemption is legitimately $0 at this income even under real law (AGI $60,000 is past the $28,500 single-column cliff), so this case also isolates the bracket defect alone.

Remaining (2, NOT resolved -- both compound the bracket defect with NM's age-65 PIT-ADJ exemption, which `StateTaxConfig` has no field to express: no income-graduated, per-filer or per-qualifying-spouse retirement-age exemption exists anywhere in the model, only the flat `personalExemption`/`pensionExemption`/`iraWithdrawalExemption` shapes, none of which fit a table keyed on AGI bands returning a dollar exemption per qualifying filer):

- "single, age 70 (above 65), the $8,000-scale PIT-ADJ age exemption plus the federal-conformity standard deduction very nearly zero out a modest pension" -- `observedToday` updated from 48.45 to the newly measured 42.75 (bracket fix alone moved the observed defective value; the case still needs the $2,000 PIT-ADJ exemption subtracted to reach the pinned 12.75). Summary rewritten to record what changed and why the case still stands, per the Kansas precedent (commit `49a9084`) of updating `observedToday` in a knownDefect block that moved but did not resolve, rather than leaving a stale pin the suite would then fail on with "A DEFECTIVE state moved."
- "MFJ, only primary is 65+, combined AGI between the single ($28,500) and MFJ ($51,000) thresholds -- carrier for the isMarried-hardcode mutant, independent of Virginia's Task-6 carrier" -- `observedToday` updated from 87.55 to the newly measured 77.25 (bracket fix alone; the case still needs the $3,000 primary-only PIT-ADJ exemption subtracted to reach the pinned 32.25).

The brief text said "one of New Mexico's five cases will NOT resolve here." The measured result is two, not one: both the age-70/$27,000 single case and the MFJ primary-only case depend on the same unmodeled PIT-ADJ exemption mechanism, and neither's `expectedStateTax` is reachable from the bracket fix alone. I did not treat the brief's count as authoritative over the actual test output; `xcodebuild` classified both as `pinnedDefectMoved`, not `defectAppearsFixed`, and I left both blocks standing rather than deleting one to match the brief's number.

The fifth case ("MFJ, both spouses 65+ ... fully zero out the household's taxable income") carried no `knownDefect` block before this change and needed none after: the federal-conformity standard deduction alone ($47,500, doubled age-65 addition + doubled OBBBA bonus) already exceeds the $40,000 AGI, flooring taxable income to $0 regardless of which bracket table or PIT-ADJ amount applies. Verified unchanged.

## Baseline movements (19 entries, all `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`)

`RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift` calls `calculateStateTax` directly on each scenario's `income` figure with no state standard deduction or PIT-ADJ exemption applied, so every one of these movements is attributable to the bracket-schedule correction alone, not the unmodeled exemption. NM had 20 baseline keys; 19 moved, "zero income" (0 -> 0) did not.

| key | before | after | goldenCase |
|---|---|---|---|
| single 55, distributions only | 2660.5 | 2411.0 | single, age 55 ... bracket schedule is the dominant gap |
| single 58, distributions only | 2660.5 | 2411.0 | same |
| single 59, distributions only | 2660.5 | 2411.0 | same |
| MFJ 57 with spouse 61 | 5472.0 | 5069.0 | MFJ, only primary is 65+ ... isMarried-hardcode mutant ... |
| MFJ 61 with spouse 56 | 5472.0 | 5069.0 | same |
| MFJ 56 with spouse 55, both below the gate | 5472.0 | 5069.0 | same |
| MFJ 68 both qualify, pension + IRA | 6354.0 | 5951.0 | same |
| MFJ status but spouse disabled, 66 | 4198.0 | 3807.0 | same |
| single 65 pension, total 95k | 4375.5 | 4113.0 | single, age 55 ... |
| single 68 pension, total 120k | 5600.5 | 5338.0 | same |
| single 68 pension, total 140k | 6580.5 | 6318.0 | same |
| MFJ 68 pension, total 120k | 5374.0 | 4971.0 | MFJ, only primary is 65+ ... |
| MFJ 68 pension, total 140k | 6354.0 | 5951.0 | same |
| MFJ 68 pension, total 200k over the cliff | 9294.0 | 8891.0 | same |
| single 62 conversion 100k no withholding | 7560.5 | 7298.0 | single, age 70, a $30,000 Roth conversion ... |
| single 62 conversion 100k with 22k withheld | 7560.5 | 7298.0 | same |
| single 54 conversion 80k | 6580.5 | 6318.0 | same |
| single 55 rmd rows not scenario distributions | 2660.5 | 2411.0 | single, age 55 ... |
| single 63 in the early age tier | 4130.5 | 3868.0 | same |

All `after` values are MEASURED from the `xcodebuild -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests` failure messages before being written into the ledger, then re-verified green.

MFJ movements are attributed to the "MFJ, only primary is 65+" golden case (rather than the fully-resolved cases) because it is the only NM golden case whose own `source` field discusses the married bracket table explicitly ("Applying the correct MFJ bracket table, $2,150 is in the first bracket (not over $8,000 -> 1.5%)"); that case's `knownDefect` block still stands (its own defect is the unmodeled exemption, not the bracket), but the bracket-table citation inside it is sound and independently confirmed against HB0252TRS.pdf page 16 above.

## Equivalence lists, `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`

- **`phase5CorrectedJurisdictions`** (Layer B, structural divergence from `configs2026Legacy`): added `.newMexico`. This is unconditionally correct for any Phase 5 config edit -- the corrected JSON must re-encode differently from the frozen legacy table, and it does (bracket arrays changed).
- **`layerAProvenDivergentJurisdictions`** (Layer A, the 10-scenario grid, asserts at least one scenario actually diverges): added `.newMexico`. Reasoning: that grid passes fixed `income` values (40,000 up to 300,000, both filing statuses) straight into `calculateStateTax` with no state deduction, so a full bracket-table replacement necessarily changes results wherever old and new thresholds disagree. I did not just assume this -- I reasoned it from the same mechanism Iowa used to qualify for this list (Iowa's fix touches fields the grid varies), confirmed by running the equivalence suite below, which passed with NM on the list.

## Other suites that moved

None found beyond the golden and baseline suites this task is scoped to touch. I ran the full suite twice; both runs showed exactly one issue, `MultiYearPerfTests.persona2_mfjCouple35Years()`, a wall-clock budget test (`<15s`) that measured 15.02s, 15.07s, and 15.06s across three isolated re-runs (`-only-testing:RetireSmartIRATests/MultiYearPerfTests`). This test exercises `OptimizationEngine`'s full multi-year compute path for an MFJ persona and has no state-tax dependency at all; its failure margin (0.02-0.07s over a 15.0s budget) and its consistent near-boundary timing across repeated isolated runs match the brief's description of a known pre-existing wall-clock flake, not a regression introduced by this change. No other test in `StateTaxPhase3aMechanismTests`, `GoldenScenarioCoverageTests`, `GoldenScenarioCrossPathTests`, `GoldenScenarioMultiYearTests`, `GoldenScenarioDefectCatalogueTests`, or any other suite referenced New Mexico's old bracket numbers.

## Full suite output (second, confirming run)

```
Test run with 1857 tests in 293 suites failed after 331.426 seconds with 1 issue.
...
Executed 509 tests, with 0 failures (0 unexpected) in 22.630 (22.810) seconds
...
Failing tests:
	MultiYearPerfTests.persona2_mfjCouple35Years()
```

Isolated re-run of the flake alone (three consecutive `-only-testing:RetireSmartIRATests/MultiYearPerfTests` runs across this session): 15.019s, 15.073s, 15.064s against the 15.0s budget, all other 3 tests in that suite passing each time.

Golden suite alone (`-only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests`): 4 tests, 1 suite, passed.

Baseline + ledger suites alone (`-only-testing:RetireSmartIRATests/BaselineMovementLedgerTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests`): 2 tests, 2 suites, passed.

## Confined production diff

Only file touched under `RetireSmartIRA/`: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NM.json`, the `taxSystem.single` and `taxSystem.married` bracket arrays (rates and thresholds only; no key added or removed; no Swift file touched).

## Em dash check

`git diff -U0` across all four changed files, piped through a Perl-regex grep for U+2014: no matches. This report itself: no em dash characters.

## Files changed

- `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NM.json` (production, bracket schedules only)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-NM.golden.json` (2 knownDefect blocks deleted, 2 knownDefect blocks' observedToday/summary updated)
- `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` (19 NM entries appended)
- `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift` (`.newMexico` appended to both `phase5CorrectedJurisdictions` and `layerAProvenDivergentJurisdictions`, with doc-comment entries)
