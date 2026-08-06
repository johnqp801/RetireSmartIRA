# Task 3 report: Iowa, the retirement exclusion and Roth conversions

## Status

DONE. Golden suite green, baseline suite green (18 attributed movements recorded), equivalence gate updated for Iowa, full suite green (1,857 Swift Testing in 293 suites + 509 XCTest, 0 failures).

## The config edit, field by field

File: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IA.json`, `retirementExemptions` block only.

| Field | Shipped | Corrected | Why |
|---|---|---|---|
| `distributionMinAge` | 59 | 55 | Iowa DOR: "55 years of age or older on December 31 of the tax year" (HF 2317). This gates `scenarioRetirementDistributions` (the RMD/withdrawal scalar). |
| `regularExemptionMinAge` | 0 | 55 | Gates the `pensionExemption`/`iraWithdrawalExemption` levels via `resolveLevel`. Set to match the same 55-year statutory age rather than leaving it at 0 (no gate), which would have let a below-55 filer wrongly draw the exclusion. |
| `pensionExemption` | `{"kind":"none"}` | `{"kind":"full"}` | HF 2317 lists "Defined benefit plans, pension plans...including IPERS" as qualifying, no cap. |
| `iraWithdrawalExemption` | `{"kind":"none"}` | `{"kind":"full"}` | HF 2317 lists "Traditional individual retirement accounts (IRA) authorized under section 408(a)" by name, no cap, no income limit. |
| `exemptionAttribution` | `"household"` | `"perQualifyingSpouse"` | Iowa DOR: "the retirement income exclusion is only applicable to a spouse who meets one of the above conditions. If one spouse does not meet one of the above conditions, retirement income attributable to that spouse is not eligible for the exclusion." This is a statutory per-spouse rule, not the engine's historical either-spouse household grant. |
| `rothConversionExemption` | absent | `{"minAge":55,"withheldPortionRemainsTaxable":false}` | HF 2317 lists "Roth conversion income" by name among qualifying distributions, no cap, no income limit. `minAge` set to 55 to match Iowa's statutory age (Pennsylvania, Illinois and Mississippi all ship `minAge:0` since none of the three states' rules condition on age). See below for `withheldPortionRemainsTaxable`. |

JSON wire format for `{"kind":"full"}` and the `rothConversionExemption` object shape were read directly from Pennsylvania's shipped config (`statetax-2026-PA.json`), which ships a full `iraWithdrawalExemption`/`pensionExemption` and a `rothConversionExemption` block today, per the brief's instruction not to guess the enum's encoding.

## The withheld-portion question: what I established, and what I chose

**I could not find Iowa DOR guidance that addresses the withheld-portion question directly**, and I am stating that plainly rather than presenting an inference as a citation.

What I did find, fetched directly from the two primary sources:

1. Iowa DOR's "Retirement Income Tax Guidance" FAQ page (`https://revenue.iowa.gov/taxes/tax-guidance/individual-income-tax/retirement-income-tax-guidance`) lists "Roth conversion income" as qualifying by name. Every sentence on that page mentioning "withhold"/"withholding" concerns *Iowa's own* state withholding obligation on payments to a qualifying vs. non-qualifying recipient (e.g., "state income tax withholding is not required on distributions of retirement income that are not subject to Iowa income tax"). None of it addresses federal tax withheld during a conversion, or draws any distinction based on whether the pre-tax balance actually reaches the Roth account.
2. Iowa Admin. Code r. 701-302.54 (the Roth-IRA-conversion-specific administrative rule, via Cornell LII) states only that "any income realized from the rollover or conversion of the existing IRA is taxable" (subject to the exclusion) and gives a worked example of the total conversion amount. It contains no basis-recovery or "reaches the Roth" mechanism of the kind Pennsylvania's Ans 274 rests on.

Pennsylvania's `withheldPortionRemainsTaxable: true` is not a generic Roth-conversion rule; it is a consequence of Pennsylvania's idiosyncratic cost-recovery approach to IRA distributions, under which a conversion is tax-free only to the extent the pre-tax balance reaches the Roth. Iowa's exclusion, by contrast, is a blanket statutory exclusion of named categories of retirement income (IRAs, pensions, Roth conversions) gated only by age/disability/survivor status, with "no dollar cap and no income limit stated anywhere on the page" (golden fixture's own characterization). That structure is the same shape as Illinois's and Mississippi's rules, both of which ship `withheldPortionRemainsTaxable: false` in this codebase today, and neither of which publishes a PA-Ans-274-style condition either.

**I chose `withheldPortionRemainsTaxable: false` for Iowa**, on the reasoning above: it is the value that does not import a Pennsylvania-specific mechanism Iowa's statute and guidance give no indication of. This is a reasoned choice under an evidentiary gap, not a confirmed citation, and I want that distinction explicit rather than dressed up as one.

**Correction (post-review): the choice is NOT moot.** A reviewer hand-computed the baseline scenario `IA|single 62 conversion 100k with 22k withheld` against `TaxCalculationEngine.swift:833-842` and found it IS dollar-consequential: under the shipped `false`, the exempt amount is the full $100,000, taxable income is $40,000, and Iowa tax is $1,520.00; under `true`, the exempt amount is $100,000 minus the $22,000 withheld ($78,000), taxable income is $62,000, and Iowa tax is $2,356.00. An $836 difference on a common real situation, since this app has a Roth conversion withholding feature and an Iowa user electing withholding hits this path directly. I verified this arithmetic myself before accepting the correction; it is confirmed. The earlier claim that "no golden or baseline scenario in this phase produces a withholding amount in Iowa where the two settings would compute different Iowa tax" was wrong -- it correctly observed that the scenario computes the SAME result under the shipped `false` setting either way (with or without withholding, both floor at the same $1,520 because the whole base is excluded), but that is not the same claim as the two SETTINGS being moot, and I conflated them. The `false` value itself is unchanged and still the better-reasoned choice; what changes is that this is now flagged, in the movement ledger and in the golden fixture, as resting on an analogy rather than a citation, so a future reader does not mistake one for the other. If Iowa DOR ever publishes explicit guidance on this point, that is the value to revisit.

## exemptionAttribution: why perQualifyingSpouse, and the fixture that catches a wrong setting

Read `ExemptionAttribution` in `RetireSmartIRA/StateTaxData.swift:158-187`. Two cases exist: `.household` (either spouse qualifying unlocks the whole household's exemption -- the pre-Phase-3a default) and `.perQualifyingSpouse` (each spouse's own age gates only income attributed to that spouse). Iowa's DOR guidance is explicit per-spouse language, so `.perQualifyingSpouse` is correct, not a guess.

The fixture case "MFJ, only the SPOUSE qualifies (spouse 65, no income of their own) and the income-bearing primary is 48 and does not qualify" exists precisely to catch a wrong `.household` setting: under `.household`, the spouse's age alone would have unlocked the exclusion for the *primary's* $52,000 pension, which is legally wrong (the pension is attributable to the non-qualifying 48-year-old primary). This case carries no `knownDefect` block because Iowa's pre-fix `.none`/`.none` exemption made the case pass for the wrong reason; it was written "forward-looking" to fail the moment Iowa shipped an exemption under the wrong attribution. With `.perQualifyingSpouse` shipped, it still passes at $461.70, confirming the attribution is correctly per-spouse and not household-wide.

## knownDefect blocks: deleted and remaining

All 4 `knownDefect` blocks in `statetax-2026-IA.golden.json` resolved and were deleted. None remain.

1. "single, age 60, IRA withdrawal fully excluded under HF 2317" (observedToday 1478.20 to now 0.00, matches published form)
2. "MFJ, both spouses 55+ (62/58), pension income fully excluded" (observedToday 1436.40 to now 0.00)
3. "single, age 60, large Roth conversion" (observedToday 6988.20 to now 0.00)
4. "single, age 56, in the 55-58 band" (observedToday 1098.20 to now 0.00)

The two cases with no `knownDefect` block ("single, age 50, below the 55 threshold" and "MFJ, only the SPOUSE qualifies") were already correct before this change (for the reasons stated in their own `source` text) and remain correct after it. The golden suite (`GoldenScenarioSingleYearTests`, 50 states x their fixtures) is fully green.

## The headline number

**A $200,000 Roth conversion by a 60-year-old single Iowan** (golden case "single, age 60, large Roth conversion"), federal AGI $200,000, no other income:

- **Before this change: $6,988.20** in invented Iowa state tax on the conversion itself.
- **After this change: $0.00.** Iowa taxable income floors at $0 because the $200,000 exclusion exceeds the $183,900 base (federal AGI minus the $16,100 standard deduction).

That is the full $6,988.20 removed, on exactly the transaction this product exists to recommend.

## Baseline movements: 18, all measured

`RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` now carries 18 entries, all for `IA|...` keys. `before` was copied verbatim from the frozen `statetax-behavior-baseline-2026.json`; `after` was read directly from the `StateTaxBehaviorBaselineTests` failure messages after the config edit landed, never predicted.

| Key | Before | After |
|---|---|---|
| single 55, distributions only | 2280.00 | 760.00 |
| single 58, distributions only | 2280.00 | 760.00 |
| single 59, distributions only | 2280.00 | 760.00 |
| MFJ 57 with spouse 61 | 4560.00 | 2660.00 |
| MFJ 61 with spouse 56 | 4560.00 | 2660.00 |
| MFJ 56 with spouse 55, both below the gate | 4560.00 | 2660.00 |
| MFJ 68 both qualify, pension + IRA | 4332.00 | 532.00 |
| MFJ status but spouse disabled, 66 | 3572.00 | 532.00 |
| single 65 pension, total 95k | 3610.00 | 570.00 |
| single 68 pension, total 120k | 4560.00 | 760.00 |
| single 68 pension, total 140k | 5320.00 | 1140.00 |
| MFJ 68 pension, total 120k | 4484.00 | 304.00 |
| MFJ 68 pension, total 140k | 5244.00 | 1064.00 |
| MFJ 68 pension, total 200k over the cliff | 7524.00 | 3344.00 |
| single 62 conversion 100k no withholding | 6080.00 | 1520.00 |
| single 62 conversion 100k with 22k withheld | 6080.00 | 1520.00 |
| single 55 rmd rows not scenario distributions | 2280.00 | 760.00 |
| single 63 in the early age tier | 2736.00 | 1216.00 |

Two IA baseline scenarios did **not** move, as expected and confirmed by their absence from the failure list:

- `single 54 conversion 80k` -- age 54 is below both the new `distributionMinAge` (55) and the new `rothConversionExemption.minAge` (55), so neither the distribution nor the conversion qualifies for exclusion. Unchanged by design; the baseline scenario's own comment says it exists to pin exactly this ("A conversion BELOW the distribution age gate").
- `zero income` -- no income, nothing to exclude.

Each movement's `goldenCase` cites one of Iowa's own golden scenarios (verified to resolve against `statetax-2026-IA.golden.json` by `BaselineMovementLedgerTests`), grouped by mechanism: the `distributionMinAge`/scalar-distribution movements cite "single, age 56, in the 55-58 band..."; the pension-exclusion movements cite "MFJ, both spouses 55+ (62/58), pension income fully excluded"; the two conversion movements and the rmd-row/early-tier movements cite the Roth-conversion and IRA-withdrawal golden cases respectively. Full justification text for each entry is in the JSON file itself.

## The equivalence gate

`RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`:

1. Appended `.iowa` to `phase5CorrectedJurisdictions` (line ~539, `StateTaxJSONStructuralEquivalenceTests`), per the brief.
2. **Additional finding, not anticipated by the brief:** a second, separate gate in the same file -- `StateTaxJSONEquivalenceTests.jsonMatchesLegacy` ("PHASE 1 GATE: JSON configs are behaviorally identical to the legacy table", Layer A) -- failed with 9 issues after the config edit. This suite predates `phase5CorrectedJurisdictions` and does not consult it; it directly asserts the JSON-loaded config and the frozen legacy Swift table compute identical tax across its own 10-scenario grid. Kansas's Task 2 correction (`personalExemption`) never tripped this gate because none of its 10 scenarios read `postExemptionDeduction` from config (same reason the behavior baseline was silent for Kansas). Iowa's correction touches `scenarioRetirementDistributions`, `scenarioRothConversionAmount`, `pensionIncome`, and `primaryAge`/`spouseAge` directly, so 9 of its 10 scenarios (all but "zero income") legitimately diverge from the frozen legacy table now. I added a `phase5CorrectedJurisdictions`-gated `continue` inside the scenario loop so this Layer A gate skips the identity assertion for corrected jurisdictions, with a comment explaining why, rather than silencing the individual Iowa failures or leaving the gate red. This mirrors Layer B's existing precedent (divergence from the frozen legacy table is expected and attributed elsewhere -- the golden fixture and the movement ledger -- for jurisdictions on that list) rather than inventing a new mechanism.

`StateTaxPhase3aMechanismTests.swift`: three Phase-3a mechanism pins failed after the config edit, each of which explicitly named Iowa's future move in its own failure message before I touched anything:

1. `everyStateShipsHouseholdAttribution` -- asserted every state ships `"household"`. Iowa now ships `"perQualifyingSpouse"`. Updated to carve out Iowa specifically (expect `perQualifyingSpouse` for Iowa, `household` for everyone else), renamed to "Every jurisdiction except Iowa still ships exemptionAttribution as household".
2. `everyStateShipsDistributionMinAge59` -- asserted every state ships `59`. Iowa now ships `55`. Same carve-out pattern, renamed "Every jurisdiction except Iowa still ships distributionMinAge as 59".
3. `onlyThreeStatesCarryAConversionExemption` -- asserted exactly `{PA, IL, MS}` carry `rothConversionExemption`, all with `minAge: 0`. Iowa is now a fourth member with `minAge: 55`, `withheldPortionRemainsTaxable: false`. Updated the expected set to include Iowa, added assertions for Iowa's specific values, and excluded Iowa from the "minAge should be 0" loop. Renamed "Exactly PA, IL, MS and Iowa carry a conversion exemption".

All three updates are corrections of test expectations that were built on Iowa's pre-fix state and explicitly documented as temporary ("in Phase 3a", "Iowa moves to 55 in Phase 5a" in the original failure messages) -- not silenced failures. `StateTaxPhase3aMechanismTests` (30 tests) is green after the edit.

## Full suite output

```
Test run with 1857 tests in 293 suites passed after 315.897 seconds.
...
Executed 509 tests, with 0 failures (0 unexpected) in 21.546 (21.739) seconds.
Test Suite 'All tests' passed.
** TEST SUCCEEDED **
```

1,857 Swift Testing tests in 293 suites, 509 XCTest tests, 0 failures total, matching the branch's stated baseline exactly. `MultiYearPerfTests` did not appear as a failure in this run, so its known wall-clock flake did not trigger; no isolated re-run was needed.

## Confined production diff

Only production file touched: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IA.json`.

```diff
   "retirementExemptions" : {
     "capitalGainsTreatment" : "followsFederal",
-    "distributionMinAge" : 59,
+    "distributionMinAge" : 55,
     "exemptionAppliesPerIndividual" : false,
-    "exemptionAttribution" : "household",
+    "exemptionAttribution" : "perQualifyingSpouse",
     "iraWithdrawalExemption" : {
-      "kind" : "none"
+      "kind" : "full"
     },
     "otherRetirementIncomeExclusion" : false,
     "pensionAndIRAShareSingleCap" : false,
     "pensionExemption" : {
-      "kind" : "none"
+      "kind" : "full"
+    },
+    "regularExemptionMinAge" : 55,
+    "rothConversionExemption" : {
+      "minAge" : 55,
+      "withheldPortionRemainsTaxable" : false
     },
-    "regularExemptionMinAge" : 0,
     "socialSecurityExempt" : true
   },
```

No Swift file under `RetireSmartIRA/` was modified. Test-only files touched (all within the brief's stated scope, plus the one additional Layer A finding above): `RetireSmartIRATests/GoldenScenarios/statetax-2026-IA.golden.json`, `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`, `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`, `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`.

## Em dash check

Checked all five changed files (`grep` for the em dash character) plus this report. None found; double hyphens (`--`) used throughout instead, per the standing no-em-dash rule.

## Review response (post-review corrections)

A reviewer raised three findings against this task. Findings and responses:

### Finding 1 (critical): the mootness claim was false

Corrected above, in place, rather than only appended: the earlier statement that the `withheldPortionRemainsTaxable` choice is "moot for every fixture in this task" was wrong. I verified the reviewer's hand computation myself against `TaxCalculationEngine.swift:833-842` and the baseline scenario `IA|single 62 conversion 100k with 22k withheld` (income $160,000, retirementDistributions $20,000 fully exempt, rothConversion $100,000, rothConversionWithholding $22,000, age 62): under the shipped `false`, exempt amount is the full $100,000, taxable income $40,000, tax $1,520.00 (40,000 x 0.038); under `true`, exempt amount is $100,000 - $22,000 = $78,000, taxable income $62,000, tax $2,356.00 (62,000 x 0.038). Both figures match the reviewer exactly. The `false` value itself is unchanged; the correction is to the record, not the config. Also updated: the `justification` field for that entry in `statetax-behavior-movements-2026.json`, and the `source` text for the "single, age 60, large Roth conversion" case in `statetax-2026-IA.golden.json`, both now state the setting is a reasoned analogy under an evidentiary gap, not a citation, and both cite the $1,520.00 / $2,356.00 figures. No `expectedStateTax`, `before`, `after`, or config value moved anywhere.

### Finding 2 (important): Layer A's blanket skip

Replaced the blanket `continue` for every jurisdiction in `phase5CorrectedJurisdictions` with a targeted assertion. Design: track `observedDivergence` across the scenario loop (true if any scenario's JSON-computed tax differs from legacy); after the loop, for jurisdictions in a new `layerAProvenDivergentJurisdictions` set (currently just `.iowa`), assert `observedDivergence` is true. Kansas is deliberately left out of that set (stays on the plain skip, comment explains why: none of the 10 scenarios read `postExemptionDeduction`, so Kansas is structurally invisible to this grid). The next corrected jurisdiction slots in by adding it to `layerAProvenDivergentJurisdictions` if this grid exercises its corrected field(s), or leaving it out (like Kansas) with a comment if not.

Probe, and an honest note on a discrepancy found while proving it: the brief specified reverting only `distributionMinAge` from 55 to 59. I did that, ran `StateTaxJSONEquivalenceTests` filtered to Iowa, and the assertion did NOT fail -- it stayed green. I checked why before accepting or rejecting the brief's expectation: only 1 of the 10 Layer A scenarios uses a primary age between 55 and 58 (the only band `distributionMinAge` 55-vs-59 affects; every other scenario's primary age is 61+ and clears both values identically), and that one scenario (`early retiree 57, below the 59.5 gate`) also carries a $25,000 Roth conversion that stays exempt under Iowa's separate `rothConversionExemption.minAge` (55, untouched by this revert), so it keeps diverging from legacy through that channel regardless. Meanwhile every other scenario keeps diverging through `iraWithdrawalExemption`/`pensionExemption` (gated by `regularExemptionMinAge`, also untouched by this revert), independent of `distributionMinAge` entirely. So a single-field revert of just `distributionMinAge` cannot flip this assertion, because Iowa's correction touches several independent fields and the grid is sensitive to more than one of them.

To actually prove the assertion has teeth against the regression it exists to catch, I reverted ALL of Iowa's Phase 5a fields at once (`distributionMinAge` to 59, `exemptionAttribution` to `household`, `iraWithdrawalExemption`/`pensionExemption` to `none`, `regularExemptionMinAge` to 0, `rothConversionExemption` removed entirely -- i.e., the exact pre-fix bundled JSON), reran the same filtered suite, and it failed as designed:

```
✘ Test "Every jurisdiction computes identical state tax from JSON and from the legacy table" recorded an issue with 1 argument state → .iowa at StateTaxJSONEquivalenceTests.swift:520:13: Expectation failed: observedDivergence
↳ IA is listed in layerAProvenDivergentJurisdictions, so at least one of the scenarios above must compute a different tax from the JSON config than from the frozen legacy table. None diverged. Either the correction was reverted from the bundled JSON, or this scenario grid no longer exercises the corrected field -- both are regressions to investigate, not silence.
```

Restored the file to the exact committed content afterward and confirmed with `git diff` (clean, zero-byte difference after fixing a self-introduced trailing-newline discrepancy from the restore process itself, also confirmed clean by a second `git diff`). This is the more meaningful probe: it demonstrates the assertion catches the actual regression it is meant to catch (a correction silently reverted from the bundled JSON), which the brief's literal single-field instruction did not, for the structural reason above.

### Finding 3 (minor): case count

No code change needed. Noting for the record: four of Iowa's cases carried defects, not six; the other two already matched the correct form before this task. Not propagating "six" into any summary.

## Final verification after all three fixes

Focused suite (`StateTaxJSONEquivalenceTests`, `StateTaxBehaviorBaselineTests`, `GoldenScenarioSingleYearTests`): 6 tests in 3 suites passed, including the 51-case Layer A test.

Full suite (`xcrun xcresulttool get test-results summary` on the produced `.xcresult`, since the raw `tail`-piped log truncated the XCTest legacy-bundle line): `"result" : "Passed"`, `"failedTests" : 0`, `"skippedTests" : 6`, `"totalTestCount" : 2366` (1,857 Swift Testing + 509 XCTest, matching the branch's stated baseline exactly). `MultiYearPerfTests` did not fail in this run; no isolated re-run was needed.

Production diff confinement (`git diff --stat main -- RetireSmartIRA/`): still exactly `statetax-2026-IA.json`, `statetax-2026-KS.json` (Task 2), and the comment-only `StateTaxData.swift` change (Task 2). This review round touched zero files under `RetireSmartIRA/`.

No tax value moved: `git diff` on `statetax-behavior-movements-2026.json` and `statetax-2026-IA.golden.json` shows only `justification`/`source` text changed. Confirmed programmatically too -- a script walked both JSON trees before (`HEAD`) and after this round's edits, collected every numeric leaf value, and diffed the two sets: zero differences in both files.

Em dash check: all four touched files (`task-3-report.md`, `statetax-behavior-movements-2026.json`, `statetax-2026-IA.golden.json`, `StateTaxJSONEquivalenceTests.swift`) grepped clean.
