# Task 6 report: Utah, the stale rate only

## Rate before and after

`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-UT.json`, `taxSystem.rate`: `0.0455` -> `0.0445`.

Enrolled S.B. 60 (2026 General Session) amends 59-10-104(2)(b) from 4.5% to 4.45%, retrospective to
January 1, 2026. The engine's prior 0.0455 predates even the 4.5% rate S.B. 60 itself cuts from, so
Utah was stale by two rate cuts, not one.

## Which case resolved, and why it was the right one

`single, age 76, a $60,000 Roth conversion pushes MAGI so high that BOTH the Taxpayer Tax Credit and
the Retirement Credit are fully phased out, isolating the bare 4.45%-vs-4.55% rate gap`
(federalAGI $110,000). Its own fixture text establishes both UT credits are legitimately zero under
real law at this income (Taxpayer Tax Credit floors to $0 because Line 19's phase-out $1,193 exceeds
Line 16's $1,089; Retirement Credit floors to $0 because Line 9's phase-out $2,125 exceeds the $450
base), so the entire remaining gap before this fix was the rate alone. Measured engine output after
the edit: $4,895.00, matching `expectedStateTax` exactly. Its `knownDefect` block was deleted.

This is the only one of the five cases where the fixture itself asserts the credit gap is zero at
that income. The other four all have income low enough (or age/filing-status combinations) that at
least one credit is genuinely nonzero under real law, so deleting their blocks would have made the
JSON claim credits the engine still does not compute.

## The four that remain

1. `single, age 50 ... Taxpayer Tax Credit alone` (federalAGI $45,000). Real law owes $618 of
   Taxpayer Tax Credit at this income; engine models none. Summary previously also blamed the stale
   rate; corrected to state the rate is now right and the remaining gap is the credit alone.
   `observedToday` updated 2047.5 -> 2002.5 (measured).

2. `single, age 76 ... Taxpayer Tax Credit plus a partial Retirement Credit` (federalAGI $30,000).
   Real law owes $936 Taxpayer Tax Credit + $325 Retirement Credit; engine models neither. Summary
   previously said "Same Taxpayer Tax Credit and rate-staleness gap"; corrected to drop the
   rate-staleness claim and note the rate is now correct. `observedToday` updated 1365.0 -> 1335.0
   (measured).

3. `MFJ, both spouses born before the 1952 cutoff, doubled Retirement Credit base ($900) largely
   phased out by income` (federalAGI $70,000). Real law owes $1,694 Taxpayer Tax Credit (Retirement
   Credit phases fully to $0, but only because of income, not because the mechanism is absent).
   Summary never mentioned the rate, so wording is unchanged. `observedToday` updated 3185.0 -> 3115.0
   (measured).

4. `MFJ, only primary born before the 1952 cutoff, single-taxpayer Retirement Credit base ($450,
   already fully phased out) plus Taxpayer Tax Credit` (federalAGI $65,000). Real law owes $1,660
   Taxpayer Tax Credit. Summary never mentioned the rate, wording unchanged. `observedToday` updated
   2957.5 -> 2892.5 (measured).

None of these four moved to `expectedStateTax`; all four still fail with `pinnedDefectMoved` against
their OLD `observedToday`, which is exactly why `observedToday` had to be updated to the newly
measured value in each case (`GoldenScenarioSingleYearTests.classify` treats a pin that has moved off
its recorded value as a failure requiring diagnosis, distinct from a defect that has resolved to the
form value).

## Baseline movements (19 total, all state UT)

Every UT key in `statetax-behavior-baseline-2026.json` moved except `UT|zero income` (0 x any rate is
still 0, so it is not a "movement" under the ledger's `>= 0.005` threshold and carries no entry). All
19 are attributed to the fifth golden case above, since Utah's behavior-baseline scenarios have no
credit-eligible age/income shape that would isolate a different mechanism: the engine does not model
UT's credits at all, in baseline scenarios or golden ones, so a rate-only correction moves every UT
baseline entry by exactly the rate cut and nothing else.

| key | before | after (measured) |
|---|---|---|
| UT\|single 55, distributions only | 2730.0 | 2670.0 |
| UT\|single 58, distributions only | 2730.0 | 2670.0 |
| UT\|single 59, distributions only | 2730.0 | 2670.0 |
| UT\|MFJ 57 with spouse 61 | 5460.0 | 5340.0 |
| UT\|MFJ 61 with spouse 56 | 5460.0 | 5340.0 |
| UT\|MFJ 56 with spouse 55, both below the gate | 5460.0 | 5340.0 |
| UT\|MFJ 68 both qualify, pension + IRA | 6279.0 | 6141.0 |
| UT\|MFJ status but spouse disabled, 66 | 4277.0 | 4183.0 |
| UT\|single 65 pension, total 95k | 4322.5 | 4227.5 |
| UT\|single 68 pension, total 120k | 5460.0 | 5340.0 |
| UT\|single 68 pension, total 140k | 6370.0 | 6230.0 |
| UT\|MFJ 68 pension, total 120k | 5369.0 | 5251.0 |
| UT\|MFJ 68 pension, total 140k | 6279.0 | 6141.0 |
| UT\|MFJ 68 pension, total 200k over the cliff | 9009.0 | 8811.0 |
| UT\|single 62 conversion 100k no withholding | 7280.0 | 7120.0 |
| UT\|single 62 conversion 100k with 22k withheld | 7280.0 | 7120.0 |
| UT\|single 54 conversion 80k | 6370.0 | 6230.0 |
| UT\|single 55 rmd rows not scenario distributions | 2730.0 | 2670.0 |
| UT\|single 63 in the early age tier | 4095.0 | 4005.0 |

All 19 `after` values were copied verbatim from `StateTaxBehaviorBaselineTests` failure messages
("computed X, baseline Y"), not hand-computed. `before` values were copied verbatim from the frozen
`statetax-behavior-baseline-2026.json`.

## Which equivalence list, and why

**Both.**

- `StateTaxJSONStructuralEquivalenceTests.phase5CorrectedJurisdictions` (Layer B, "Append here, and
  only here"): added `.utah`. Utah's corrected JSON (rate 0.0445) now permanently diverges from the
  frozen `configs2026Legacy` table (rate 0.0455, unchanged by design), so `structurallyIdentical`
  must assert divergence rather than identity for Utah, exactly like Kansas and Iowa.

- `StateTaxJSONEquivalenceTests.layerAProvenDivergentJurisdictions` (Layer A, the scenario-grid gate):
  added `.utah`. Utah ships no `personalExemption`, `pensionExemption`, `stateDeduction`, or any
  retirement exemption (all `.none`/`false`), so its flat rate applies to 100% of taxable income with
  nothing to absorb the change. Every one of the grid's 10 scenarios with nonzero `income` therefore
  computes a different tax from the JSON config (4.45%) than from the frozen legacy table (4.55%);
  only `zero income` does not. This is a stronger, closer analogue to Iowa's situation than to
  Kansas's (Kansas is deliberately excluded from this list because none of the grid's scenarios touch
  `postExemptionDeduction`). Verified: `StateTaxJSONEquivalenceTests/jsonMatchesLegacy` passed with
  Utah included in both lists, meaning `observedDivergence` was true for Utah as required.

## Full suite output

Both suite runs used `-project` explicitly against
`/Users/johnurban/Projects/RetireSmartIRA/.worktrees/p5-t6/RetireSmartIRA.xcodeproj`.

Run 1 (immediately after the fix): `1857 tests in 293 suites failed after 336.950 seconds with 1
issue`. The single issue was `MultiYearPerfTests.persona2_mfjCouple35Years()`, a wall-clock perf
budget assertion (`elapsed -> 15.28545093536377s; budget <15s`) unrelated to state tax. Re-run in
isolation twice: failed both times at 15.28s and 15.32s, i.e. barely over budget both times,
consistent with the documented pre-existing wall-clock flake (brief item 5), not a regression from
this change (the test exercises `OptimizationEngine`/multi-year compute performance, not Utah's
config or any state tax calculation).

Run 2 (full clean run, no filters): **`Test run with 1857 tests in 293 suites passed after 328.887
seconds. ** TEST SUCCEEDED **`**. XCTest legacy runner in the same session:
`Executed 509 tests, with 0 failures (0 unexpected) in 22.203 (22.403) seconds`, twice (once per
target). 0 failures, matching the 1,857 + 509 baseline from the brief.

Targeted suites (`StateTaxJSONEquivalenceTests`, `StateTaxJSONStructuralEquivalenceTests`,
`StateTaxJSONFileKeyCompletenessTests`, `StateTaxBehaviorBaselineTests` (after the ledger entries were
added), `BaselineMovementLedgerTests`, `GoldenScenarioSingleYearTests`, `GoldenScenarioDefectCatalogueTests`):
`Test run with 13 tests in 7 suites passed after 0.445 seconds. ** TEST SUCCEEDED **`

No other suite required any change beyond the four files listed below; nothing else's expectation
encoded Utah's old rate.

## Confined production diff

```
RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-UT.json | 2 +-
```

```diff
-    "rate" : 0.0455
+    "rate" : 0.0445
```

No other file under `RetireSmartIRA/` changed. Full change set (`git diff --stat`):

```
RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-UT.json          |   2 +-
RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json       | 152 +++++++++++++++++++
RetireSmartIRATests/GoldenScenarios/statetax-2026-UT.golden.json          |  19 +--
RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift                    |  14 +-
4 files changed, 172 insertions(+), 15 deletions(-)
```

## Em dash check

`grep` for the em dash character (U+2014) against all four changed files: no matches (exit code 1) in
`statetax-2026-UT.json`, `statetax-2026-UT.golden.json`, and `statetax-behavior-movements-2026.json`.
`StateTaxJSONEquivalenceTests.swift`'s pre-existing text uses `--` (double hyphen) throughout, which
this task's additions matched; no em dash introduced.
