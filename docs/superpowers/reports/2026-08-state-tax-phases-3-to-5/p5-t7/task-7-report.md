# Task 7 report: Indiana personal exemption

## Exemption object added

`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IN.json`, a new
top-level `personalExemption` key, sibling of `stateDeduction`:

```json
"personalExemption" : {
  "marriedFilingJointly" : 2000,
  "seniorAdditionalPerFiler" : 0,
  "seniorAge" : 65,
  "single" : 1000
}
```

Source: IT-40 Booklet 2025, page 24, Schedule 3 line 1 ($1,000 single /
$2,000 MFJ). Indiana's 2.95% flat rate was untouched.

## Dependent finding and decision

IT-40 Schedule 3 also carries a per-dependent exemption (line 2) and an
income-gated age-65 addition (lines 4-5, requires federal AGI under
$40,000). `StatePersonalExemption` has `single`, `marriedFilingJointly`,
`seniorAdditionalPerFiler`, `seniorAge` only, no dependent field and no
income parameter at all, so the income-gated senior addition cannot be
expressed either. A codebase grep found no dependent-count input anywhere
in the app, matching Kansas's Phase 5a Task 2 finding exactly.

Decision: scope the correction to Schedule 3 line 1 only, same as Kansas.
`seniorAdditionalPerFiler` stays 0 rather than modeling an age-gated
addition without the income gate it actually depends on. Recorded as a
`personalExemptionScopingNote` in the IN golden fixture (same pattern
Kansas used). None of the four golden scenarios involve a dependent or a
filer aged 65+, so no `expectedStateTax` value is affected by either gap.

## The 0.0295 arithmetic check

All four cases, checked against `(observedToday - expectedStateTax)`:

| Case | observedToday | expectedStateTax | moved | exemption x 0.0295 |
|---|---|---|---|---|
| single, moderate income | 1327.5 | 1298.00 | 29.50 | 1,000 x 0.0295 = 29.50 |
| single, high income | 3835.0 | 3805.50 | 29.50 | 1,000 x 0.0295 = 29.50 |
| MFJ, moderate income | 1917.5 | 1858.50 | 59.00 | 2,000 x 0.0295 = 59.00 |
| MFJ, highest income | 6490.0 | 6431.00 | 59.00 | 2,000 x 0.0295 = 59.00 |

Held exactly for all four. No unexplained residual.

## knownDefect blocks

Deleted all four (the only four Indiana had). None remain.

## Baseline movements

Zero. `StateTaxBehaviorBaselineTests` reads `postExemptionDeduction` as a
literal on `BaselineScenario`, never as `config.personalExemption?.amount(...)`.
That field is only consumed at the DataManager layer
(`DataManager.swift:663`, `:1072`) and by `GoldenScenarioSingleYearTests`'s
own helper, neither of which the frozen-baseline harness calls. This is the
identical mechanism the Kansas task found and documented, so I recorded no
entries in `statetax-behavior-movements-2026.json` rather than manufacture
any. Verified directly: ran `StateTaxBehaviorBaselineTests` after the
change, all 51 jurisdiction cases still pass against the frozen file
unchanged.

## Equivalence list placement

- `phase5CorrectedJurisdictions` (Layer B, structural equivalence): added
  `.indiana`. This flips the "must diverge from legacy" assertion for
  Indiana, which is correct since the JSON now carries a corrected
  `personalExemption` the frozen legacy table does not.
- `layerAProvenDivergentJurisdictions` (Layer A, "must actually compute a
  different number" grid): Indiana NOT added, for the same reason Kansas
  was excluded. That scenario grid's `stateTax()` closure also passes
  `postExemptionDeduction: scenario.postExemptionDeduction` as a hardcoded
  literal per scenario (`StateTaxJSONEquivalenceTests.swift:461`), never
  reading `config.personalExemption`. None of its 10 scenarios can be
  moved by this fix, so asserting "at least one diverges" would fail
  Indiana forever in its correct state. Indiana stays on the plain skip
  from `phase5CorrectedJurisdictions` only.

## Other suites that moved

Two Phase-3a-era tests hardcoded "only New Jersey and Kansas" and needed
Indiana added, exactly as the brief predicted from the Kansas precedent:

1. `StateTaxJSONEquivalenceTests.swift`,
   `onlyNewJerseyAndKansasShipAPersonalExemptionKey` -- expected
   `["KS", "NJ"]`, now `["IN", "KS", "NJ"]`.
2. `StateTaxPhase3aMechanismTests.swift`,
   `onlyNewJerseyAndKansasCarryAPersonalExemption` -- carrier set was
   `[.newJersey, .kansas]`, now `[.newJersey, .kansas, .indiana]`.

Both are correct updates: they assert which states ship the field, and
Indiana now legitimately does. `StateTaxJSONFileKeyCompletenessTests`'s
`optionalTopLevelKeys` doc comment was also updated to name Indiana (no
assertion change needed there, `personalExemption` was already optional).

No other suite moved.

## Full suite output

```
Test run with 1857 tests in 293 suites failed after 330.327 seconds with 1 issue.
Failing tests:
	MultiYearPerfTests.persona2_mfjCouple35Years()

Executed 509 tests, with 0 failures (0 unexpected) in 22.582 (22.755) seconds
Test Suite 'All tests' passed at 2026-08-04 22:32:35.170.
```

Re-ran `MultiYearPerfTests` alone: all 4 tests pass clean (30.826s), the
known pre-existing wall-clock flake, not a regression from this change.

Also re-ran the three state-tax gates directly after landing the test-file
edits: `StateTaxBehaviorBaselineTests` (51/51 pass, frozen file untouched),
`GoldenScenarioSingleYearTests` (all 50 jurisdictions pass, IN's four cases
now ordinary passing assertions), `BaselineMovementLedgerTests` (passes,
ledger unchanged and still well-formed) -- 6 tests in 3 suites, all green.

## Confined production diff

```
RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IN.json | 6 ++++++
1 file changed, 6 insertions(+)
```

Only the IN JSON changed under `RetireSmartIRA/`. No Swift file under
`RetireSmartIRA/` was touched.

## Em dash check

`git diff` on every changed line across all four files, grepped for U+2014.
None found.

## Commit

`30682bd` on branch `feature/state-tax-phase5-t7`, worktree
`/Users/johnurban/Projects/RetireSmartIRA/.worktrees/p5-t7`. Files staged
explicitly (no `git add -A`): the IN production JSON, the IN golden
fixture, and the two test files carrying the carrier-list updates.
