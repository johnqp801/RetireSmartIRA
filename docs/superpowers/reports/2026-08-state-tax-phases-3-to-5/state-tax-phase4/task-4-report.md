# Task 4 report: no retirement exclusion, confirmed correct (CA, NE, ND, IN, OR)

Commit: `74e08bf` on `feature/state-tax-phase4`.

## Summary

- CA: all four cases PASS against real 2025 California law, no `knownDefect`.
- ND: all four cases PASS against real 2025/2026 North Dakota law, no `knownDefect`, after a scoped fix to the test harness's `.conformsToFederal` branch (see "Deviation" below).
- NE: all four cases carry `knownDefect` blocks. NE's `.none` retirement-exclusion encoding is correct (matches the audit); the defects found are unrelated -- a stale engine standard deduction and a fully unmodeled personal exemption credit.
- IN: all four cases carry `knownDefect` blocks. IN's rate (2.95%) and `.none` retirement exclusion are correct; the defect is IN's $1,000/$2,000 personal exemption, entirely unmodeled.
- OR: all four cases carry `knownDefect` blocks. OR's `.none` retirement exclusion is correct; the defects are a stale standard deduction / lower-bracket thresholds and a fully unmodeled $256-per-exemption credit.

All `knownDefect.tier` values are `"unclassified"`: none of these defects are retirement-income-exclusion errors, so none of Tier 1-4 in `.claude/memory/roadmap/2026-08-02-full-50-state-verification.md` (which classifies only exclusion-modeling gaps) describes them. That document explicitly lists "California, Nebraska, North Dakota, Indiana, Oregon -- no retirement exclusion. Correct," which the fixtures confirm directly.

---

## California (CA) -- all four cases PASS

**URLs opened:**
- `https://www.ftb.ca.gov/forms/2025/2025-540-booklet.html` (official FTB booklet page -- opened directly via WebFetch and via the Claude Browser tool; confirmed the page exists, lists "2025 California Tax Rate Schedules" as a section, and is the correct authority)
- `https://www.taxformfinder.org/forms/2025/2025-california-tax-rate-schedules.pdf` (mirror of the FTB-authored "2025 California Tax Rate Schedules" PDF, read in full -- ftb.ca.gov returns HTTP 403 to both WebFetch and the Browser tool for its own PDF endpoints, so the exact Schedule X/Y numbers were confirmed from this faithful mirror instead)
- `https://www.taxformfinder.org/california/form-540` (mirror reproducing Form 540's own line 18, read directly, to confirm the standard deduction dollar amounts)

**Figures derived:**
- Standard deduction (Form 540 line 18): $5,706 single / $11,412 MFJ.
- Exemption credit (Form 540 line 7/9): $153 per exemption, phased out $6 per $2,500 of AGI over $252,203 single / $504,406 MFJ (matches `TaxYearConfig`'s `caExemptionCreditPerPerson`/phaseout constants exactly).
- Bracket schedule (Schedule X single, Schedule Y MFJ), confirmed to the dollar against the engine's `StateTaxData.swift` config, including the 1% Mental Health Services Tax surcharge folded into the engine's synthetic 12.3%/13.3% tiers.

**Arithmetic:**
1. Single, age 55, AGI $65,000 (pension only). Taxable = 65,000 - 5,706 = 59,294 (8.00% Schedule X bracket, base $1,987.41 at $57,542): tax = 1,987.41 + 0.08*(59,294-57,542) = 1,987.41 + 140.16 = 2,127.57. Credit: 1 exemption * $153, AGI well under $252,203 phaseout, full credit. Net = 2,127.57 - 153 = **$1,974.57**.
2. Single, age 63, AGI $400,000 (pension $150k, IRA $100k, Roth $150k). Taxable = 400,000 - 5,706 = 394,294 (10.30% bracket, base $30,986.19 at $371,479): tax = 30,986.19 + 0.103*(394,294-371,479) = 30,986.19 + 2,349.945 = 33,336.135. Credit: AGI 394,294 exceeds $252,203 by 142,091; floor(142,091/2500)=56 steps * $6 = $336 > $153, fully phased out. Net = **$33,336.14**.
3. MFJ, ages 58/56, AGI $150,000 (pension $100k, SS $50k). CA excludes SS entirely: state income before deduction = 150,000 - 50,000 = 100,000; taxable = 100,000 - 11,412 = 88,588 (6.00% Schedule Y bracket, base $2,044.02 at $82,904): tax = 2,044.02 + 0.06*(88,588-82,904) = 2,044.02 + 341.04 = 2,385.06. Credit: 2 exemptions * $153 = $306, AGI well under $504,406. Net = **$2,079.06**.
4. MFJ, ages 63/61, AGI $1,200,000 (pension $500k, IRA $300k, Roth $400k) -- deliberately lands inside the $1,000,000-$1,485,906 band, the one region where CA's real law (regular 11.3% Schedule Y bracket + a flat, non-doubled 1% MHST surcharge above $1,000,000) and a mutant that doubled the MHST threshold for MFJ would diverge. Taxable = 1,200,000 - 11,412 = 1,188,588. Regular-schedule component (11.30% bracket, base $77,276.52 at $891,542): 77,276.52 + 0.113*(1,188,588-891,542) = 77,276.52 + 33,566.198 = 110,842.718. MHST: 0.01*(1,188,588-1,000,000) = 1,885.88. Total = 112,728.598. Credit: AGI far exceeds $504,406, fully phased out. Net = **$112,728.60**.

Measured engine output matched all four to the cent on the first run; no `knownDefect` needed.

---

## Nebraska (NE) -- all four cases carry `knownDefect`

**URLs opened (all read in full via the Read tool on downloaded PDFs, not summarized):**
- `https://revenue.nebraska.gov/sites/default/files/doc/tax-forms/2025/f_Individual_Income_Tax_Booklet.pdf` (2025 Form 1040N booklet, 8-307-2025)
- `https://revenue.nebraska.gov/sites/default/files/doc/tax-forms/2025/2025_Tax_Calculation_Schedule.pdf` (8-460-2025)
- `https://nebraskalegislature.gov/laws/statutes.php?statute=77-2715.03` (raw statute text, fetched via curl, confirming LB 754's 2026 rate schedule 2.46%/3.51%/4.55% and the 2014 BASE bracket table)
- `https://revenue.nebraska.gov/sites/default/files/doc/business/Cir_En_2025/2026_percent.pdf` and `2026_instruct.pdf` (2026 employer withholding circular, read to rule OUT as a source -- see below)

**Deviation, explained:** as of this writing (2026-08-04), NE DOR has not published the TY2026 Form 1040N, tax calculation schedule, or standard deduction chart. Only the TY2025 return and a TY2026 employer WITHHOLDING circular exist. The withholding circular's percentage-method rates (2.26/3.22/4.21/4.35/4.48/4.60%) do NOT match the statutory 2.46/3.51/4.55% schedule -- they are a withholding approximation keyed to a flat $2,440/year "withholding allowance" value (confirmed on page 9 of `2026_instruct.pdf`: "Value of One Income Tax Withholding Allowance... Annually... 2,440.00"), not the Form 1040N bracket/deduction schedule. Per the task's explicit "2026 (or latest published)" allowance, every NE fixture uses the fully-published 2025 figures, stated plainly in each fixture's `name`/`source`.

**Figures derived (2025, latest published):**
- Standard deduction (Line 6, "Nebraska Standard Deduction Chart", 0 boxes checked): $8,600 single / $17,200 MFJ.
- Personal exemption credit (Line 18): $171 per exemption, a CREDIT against tax, not a deduction.
- Bracket schedule (8-460-2025), Single: $0-4,030 @2.46%; $4,030-24,120 @3.51% (base $99.14); $24,120-38,870 @5.01% (base $804.30); $38,870+ @5.20% (base $1,543.28). MFJ: $0-8,040 @2.46%; $8,040-48,250 @3.51% (base $197.78); $48,250-77,730 @5.01% (base $1,609.15); $77,730+ @5.20% (base $3,086.10).
- Social Security fully exempt (confirmed via Schedule I Part B line 31 and the app's own cited LB 754 comment); no retirement-income (pension/IRA) exclusion line exists on Form 1040N -- confirms the audit's `.none`.

**Arithmetic and MEASURED engine discrepancy** (all four `observedToday` values copied verbatim from the actual `xcodebuild test` failure output before any fixture edit):
1. Single, age 60, AGI $30,000 (pension only). Taxable = 30,000-8,600 = 21,400 (3.51% bracket): 99.14+0.0351*(21,400-4,030) = 99.14+609.687 = 708.827. Credit 1*$171. Net = **$537.83**. Engine: `606.5999999999999`.
2. Single, age 62, AGI $100,000 (pension $50k, IRA $30k, Roth $20k). Taxable = 100,000-8,600 = 91,400 (5.20% bracket): 1,543.28+0.052*(91,400-38,870) = 1,543.28+2,731.56 = 4,274.84. Credit $171. Net = **$4,103.84**. Engine: `3791.6`.
3. MFJ, ages 60/58, AGI $160,000 (pension $130k, SS $30k). State income before deduction = 160,000-30,000 = 130,000; taxable = 130,000-17,200 = 112,800 (top 5.20% bracket): 3,086.10+0.052*(112,800-77,730) = 3,086.10+1,823.64 = 4,909.74. Credit 2*$171=$342. Net = **$4,567.74**. Engine: `4398.2`.
4. MFJ, ages 55/50, AGI $150,000 (pension $80k, IRA $30k, Roth $40k). Taxable = 150,000-17,200 = 132,800 (top bracket): 3,086.10+0.052*(132,800-77,730) = 3,086.10+2,863.64 = 5,949.74. Credit $342. Net = **$5,607.74**. Engine: `5308.2`.

**Mechanism**: `RetireSmartIRA/StateTaxData.swift`'s Nebraska config sets `stateDeduction: .fixed(single: 12_000, married: 24_000)`, roughly matching the 2013 pre-inflation BASE bracket table in the statute rather than any inflation-adjusted current figure -- real NE law is ~$8,600/$17,200. Nebraska's $171-per-exemption personal credit (a tax CREDIT, not a deduction) has no analog anywhere in the engine (no `personalExemption` config entry for NE, and NE is not special-cased the way California is for its own exemption credits).

---

## North Dakota (ND) -- all four cases PASS (after a harness fix)

**URLs opened (all read in full via the Read tool):**
- `https://www.tax.nd.gov/sites/www/files/documents/forms/individual/2025-iit/28702-form-nd-1-2025.pdf` (Form ND-1, 2025)
- `https://www.tax.nd.gov/sites/www/files/documents/forms/individual/2025-iit/tax-tables-2025.pdf` (2025 Tax Table + Tax Rate Schedules, the fixture's `sourceURL`)

**Figures derived:**
- Form ND-1 line 1b starts from FEDERAL TAXABLE INCOME (Form 1040 line 15), which is already net of the federal standard deduction -- this is exactly why the engine's `stateDeduction` is coded `.conformsToFederal`.
- No pension or IRA exclusion line exists on Form ND-1 (only two narrow, occupation-specific carve-outs: military retirement, line 14; licensed peace officer retirement, line 9) -- confirms the audit's `.none`. Line 15 confirms a Social Security exclusion separately.
- 2025 Tax Rate Schedules (page 8 of the Tax Tables PDF): Single $0-48,475 @0%; $48,475-244,825 @1.95%; $244,825+ @2.50% (base $3,828.83). MFJ $0-80,975 @0%; $80,975-298,075 @1.95%; $298,075+ @2.50% (base $4,233.45). These match the engine's own 2026 config thresholds to the dollar.

**Deviation, with reasoning -- test-harness fix, not a production change.** `GoldenScenarioSingleYearTests.singleYearStateTax`'s `.conformsToFederal` branch previously treated the state standard deduction as $0, with a doc comment reading "`.conformsToFederal` is not handled -- no pilot state uses it... flag this comment if a future pilot state needs it." ND is that pilot state. Production `DataManager.calculateStateTaxFromGross` already handles `.conformsToFederal` correctly (uses `standardDeductionAmount`, the real federal figure), so the $0 branch was a test-harness gap, not an engine defect -- pinning a `knownDefect` there would have recorded a FALSE claim that the shipped app disagrees with ND law when only this isolated test replica did. I extended the branch (`RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`) to read `TaxCalculationEngine.config.standardDeductionSingle`/`standardDeductionMFJ` ($16,100/$32,200 for 2026), mirroring the BASE federal standard deduction only (no age-65 addition, no OBBBA senior bonus, both of which need a live `DataManager` instance this static helper doesn't have). Every ND fixture keeps both filers under 65, making this exact for them, not an approximation. Confirmed via `grep` that no other `covered` state uses `.conformsToFederal`, so this change is a no-op everywhere else -- the full suite run below confirms it.

**Arithmetic:**
1. Single, age 52, AGI $70,000 (pension only). Taxable = 70,000-16,100 = 53,900 (1.95% bracket): 0.0195*(53,900-48,475) = 0.0195*5,425 = 105.7875. **$105.79**.
2. Single, age 60, AGI $300,000 (pension $100k, IRA $80k, Roth $120k). Taxable = 300,000-16,100 = 283,900 (2.50% bracket): 3,828.83+0.025*(283,900-244,825) = 3,828.83+976.875 = 4,805.705. Measured engine output on the raw double arithmetic is `4805.7`, so the fixture was corrected from a hand-rounded `4805.71` to `4805.70` (a representation/rounding-convention correction, not a law question -- decided per Step 7, "the fixture is wrong").
3. MFJ, ages 55/53, AGI $160,000 (pension $130k, SS $30k). State income before deduction = 130,000; taxable = 130,000-32,200 = 97,800 (1.95% bracket): 0.0195*(97,800-80,975) = 0.0195*16,825 = 328.0875. **$328.09**.
4. MFJ, ages 58/56, AGI $500,000 (pension $200k, IRA $150k, Roth $150k). Taxable = 500,000-32,200 = 467,800 (2.50% bracket): 4,233.45+0.025*(467,800-298,075) = 4,233.45+4,243.125 = 8,476.575. Measured engine output landed on `8476.58` (passed as-is; a different double-arithmetic rounding outcome than case 2, both legitimate).

---

## Indiana (IN) -- all four cases carry `knownDefect`

**URLs opened (all read in full via the Read tool):**
- `https://forms.in.gov/Download.aspx?id=16915` (IT-40 Booklet 2025 -- exemptions on page 24, Schedule 3)
- `https://www.in.gov/dor/files/dn01.pdf` (Departmental Notice #1, effective Jan. 1, 2026 -- the fixture's `sourceURL`)

**Figures derived:**
- 2026 rate: "For 2026, the state adjusted gross income tax rate for individuals is 2.95%." (Departmental Notice #1, page 2) -- matches the engine's config exactly.
- No state standard deduction (config `.none` correct).
- Personal exemption (Schedule 3 line 1): $1,000 single / $2,000 MFJ.
- Social Security fully excluded from Indiana AGI (IN DOR "Indiana Deductions from Income": "Indiana allows a tax deduction for any Social Security or railroad retirement benefits included in federal adjusted gross income") -- confirms the audit's socialSecurityExempt.
- No pension or IRA exclusion (config `.none` confirmed correct by the audit).

**Arithmetic and MEASURED engine discrepancy:**
1. Single, age 55, AGI $45,000. Taxable = 45,000-1,000 = 44,000. Tax = 44,000*0.0295 = **$1,298.00**. Engine: `1327.5` (diff = $29.50 = $1,000*0.0295 exactly).
2. Single, age 62, AGI $130,000 (pension $60k, IRA $30k, Roth $40k). Taxable = 130,000-1,000 = 129,000. Tax = 129,000*0.0295 = **$3,805.50**. Engine: `3835.0` (same $29.50 gap).
3. MFJ, ages 58/56, AGI $95,000 (pension $65k, SS $30k). State income before exemption = 65,000; taxable = 65,000-2,000 = 63,000. Tax = 63,000*0.0295 = **$1,858.50**. Engine: `1917.5` (diff = $59.00 = $2,000*0.0295 exactly).
4. MFJ, ages 60/58, AGI $220,000 (pension $100k, IRA $60k, Roth $60k). Taxable = 220,000-2,000 = 218,000. Tax = 218,000*0.0295 = **$6,431.00**. Engine: `6490.0` (same $59.00 gap).

**Mechanism**: Indiana's $1,000/$2,000 personal exemption has no representation anywhere in the engine (`personalExemption` is nil for IN -- only NJ's config sets it). Every discrepancy is exactly `exemption * 0.0295`, confirming this is the sole mechanism.

---

## Oregon (OR) -- all four cases carry `knownDefect`

**URLs opened (all read in full via the Read tool):**
- `https://www.oregon.gov/dor/forms/FormsPubs/form-or-40-inst_101-040-1_2025.pdf` (2025 Form OR-40 Instructions, 150-101-040-1 -- the fixture's `sourceURL`)

**Figures derived:**
- Standard deduction (page 16, Table 5): $2,835 single / $5,670 MFJ.
- Tax rate charts (page 17): Chart S (single/MFS) $50,000-$125,000: $4,065 + 8.75% of excess over $50,000; over $125,000: $10,627 + 9.9% of excess over $125,000. Chart J (MFJ/HoH/QSS): $50,000-$250,000: $3,756 + 8.75%; over $250,000: $21,256 + 9.9%.
- Exemption credit (page 18, box 25 worksheet): $256 per exemption, gated to $0 when federal AGI exceeds $100,000 single / $200,000 for all other statuses.
- No pension/IRA exclusion; Social Security fully excluded (config confirmed correct by the audit).

**Deviation, with reasoning -- income floor chosen to avoid a transcription risk.** Every OR case was deliberately kept at or above $50,000 in OR taxable income so the derivation could use the explicitly-printed Chart S/J rate-chart formula instead of OR-40's scanned, multi-column, $50-wide printed tax TABLE for incomes under $50,000, whose lower-bracket boundaries I could not transcribe from the scanned image with confidence (an early, discarded attempt to read the low-income table produced internally inconsistent single/MFJ deltas, which I did not trust and did not use). This kept my OWN arithmetic clean, but it did NOT insulate the comparison from the engine's own lower-bracket thresholds, since `TaxCalculationEngine.calculateStateTax` cascades through ALL of a state's configured brackets regardless of where the fixture's final income lands -- see the measured discrepancies below, which are larger than the deduction gap alone would predict, confirming OR's config lower-bracket thresholds are also slightly off (not independently re-derived to the dollar; described only qualitatively in each `knownDefect.summary`, honestly, rather than guessed at a precision I could not verify).

**Arithmetic and MEASURED engine discrepancy:**
1. Single, age 60, AGI $58,000 (pension only). Taxable = 58,000-2,835 = 55,165 (8.75% Chart S band): 4,065+0.0875*(55,165-50,000) = 4,065+451.9375 = 4,516.9375. Credit: AGI under $100,000, full $256. Net = **$4,260.94**. Engine: `4366.5`.
2. Single, age 63, AGI $140,000 (pension $60k, IRA $30k, Roth $50k). Taxable = 140,000-2,835 = 137,165 (9.9% band): 10,627+0.099*(137,165-125,000) = 10,627+1,204.335 = 11,831.335. Credit: AGI over $100,000, fully phased out to $0. Net = **$11,831.34**. Engine: `11658.34`.
3. MFJ, ages 62/60, AGI $80,000 (pension $60k, SS $20k). State income before deduction = 60,000; taxable = 60,000-5,670 = 54,330 (8.75% Chart J band): 3,756+0.0875*(54,330-50,000) = 3,756+378.875 = 4,134.875. Credit: AGI under $200,000, full 2*$256=$512. Net = **$3,622.88**. Engine: `3833.0`.
4. MFJ, ages 58/56, AGI $190,000 (pension $90k, IRA $40k, Roth $60k). Taxable = 190,000-5,670 = 184,330 (8.75% band): 3,756+0.0875*(184,330-50,000) = 3,756+11,753.875 = 15,509.875. Credit: AGI under $200,000, full $512. Net = **$14,997.88**. Engine: `15208.0`.

**Mechanism**: OR's engine standard deduction ($4,840/$9,680) overstates Form OR-40's real figures ($2,835/$5,670), OR's lower-bracket thresholds are also slightly miscalibrated (confirmed by the residual gap after accounting for the deduction alone), and the $256/$512 exemption credit is entirely unmodeled.

---

## Full suite

```
xcodebuild test -project .../RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
...
Test run with 1850 tests in 291 suites passed after 323.412 seconds.
...
Executed 509 tests, with 0 failures (0 unexpected) in 22.327 (22.512) seconds.
Test Suite 'All tests' passed
** TEST SUCCEEDED **
```

6 skips, all pre-existing and env-gated, matching the branch baseline exactly:
- 4x `RUN_AUDIT_HARNESS` display-audit-harness tests
- "Generate the frozen behavior baseline"
- "Generate all 51 jurisdiction files"

A first full-suite run showed 2 unrelated failures (`MultiYearPerfTests.persona2_mfjCouple35Years`, `persona4_preRetirementSaverWithWages`) -- both pure wall-clock perf-budget tests (15s ceilings) whose own file header documents CPU-contention-driven flakiness under full-suite parallel load ("CPU contention can roughly double wall-clock times"). Re-run in isolation (`-only-testing:RetireSmartIRATests/MultiYearPerfTests`), both passed comfortably (14.456s and 7.395s against 15s budgets). A second full-suite run passed clean with zero failures, confirming this was contention flakiness unrelated to this batch's changes, not a regression.

## Production diff

```
git diff --stat main -- RetireSmartIRA/
```
Empty. Confirmed before and after the ND harness-fix commit.

## Em dash check

`grep` for U+2014 across all five new fixture files plus the two modified Swift test files: zero matches.

## Files touched

- Created: `RetireSmartIRATests/GoldenScenarios/statetax-2026-{CA,NE,ND,IN,OR}.golden.json`
- Modified: `RetireSmartIRATests/GoldenScenarioCoverageTests.swift` (`covered` += CA, NE, ND, IN, OR)
- Modified: `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift` (`.conformsToFederal` branch, see ND deviation above)

## Attestation

I personally opened every `sourceURL` in this batch and checked every clause of each `source` string against the page, with one disclosed exception: California's Form 540 line 18 standard deduction ($5,706/$11,412) and the Schedule X/Y tax rate schedule. The fixture's `sourceURL` (`ftb.ca.gov/forms/2025/2025-540-booklet.html`) is a real page I opened directly (via WebFetch and the Claude Browser tool) and confirmed is the correct authority and lists the relevant sections, but `ftb.ca.gov` returns HTTP 403 to both tools for its own PDF endpoints. For the exact dollar figures I instead opened and read in full two faithful mirrors of the same FTB-authored documents (`taxformfinder.org`'s copies of the 2025 California Tax Rate Schedules PDF and of Form 540's own line 18 text), both read directly rather than taken from a search-engine summary. Every other citation in this batch -- all of NE, ND, IN, and OR, and CA's exemption-credit figures -- was opened and read in full directly from the state revenue department's own domain via the Read tool on a downloaded PDF or a direct page fetch, not summarized secondhand.

---

# Review-findings pass (2026-08-04), applied on top of the above

Three confirmed review findings applied to this task's output. HEAD at start: `74e08bf`.

## Finding 1 (CRITICAL): harness under-deducted for filers 65+ in the `.conformsToFederal` branch

Read `DataManager.swift:1735-1775` (`standardDeductionAmount`) directly before writing anything. It does exactly what the finding brief described, and I found no discrepancy with the brief: base federal standard deduction, plus `additionalDeduction65Single`/`additionalDeduction65MFJ` (MFJ version added once per qualifying person, so up to twice), plus the OBBBA senior bonus computed from `scenarioGrossIncome` (`DataManager.swift:1721-1723`, `scenarioBaseIncome + scenarioTotalRothConversion + scenarioTotalWithdrawals`), gated to `cfg.seniorBonusFirstYear...seniorBonusLastYear`, with the MFJ case reducing the $6,000 bonus separately per qualifying senior (per IRC 151(d)(5)(B)) and then summing, not one shared reduction multiplied by headcount.

`RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`'s `.conformsToFederal` case now mirrors this in full, using `scenario.federalAGI` as the MAGI input (comment in the code explains why this is exact, not approximate, for this fixture schema: the shape invariant requires `federalAGI` to equal the sum of declared income components, and the schema has no capital-gains/dividend field that could make the two diverge). The prior comment claiming both terms "depend on a live DataManager instance this static helper doesn't have" has been deleted and replaced; that claim was wrong, as the brief predicted, since both terms are pure functions of fixture fields and static config constants already in scope.

### Proof the fix is inert for all 18 existing fixtures

Before and after the change, `xcodebuild test ... -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests -only-testing:RetireSmartIRATests/GoldenScenarioCoverageTests` passes with the same 18 test cases in "Single-year path matches each state's own published form," no `unexplainedDisagreement`, `pinnedDefectMoved`, or `defectAppearsFixed` failures anywhere, and no `knownDefect` block needed adding or removing. All four ND fixtures (the only `.conformsToFederal` state with fixtures today) keep `primaryAge`/`spouseAge` under 65 (52, 60, 55/53, 58/56), so none of them reach the new age/bonus branches; every other pilot state's `stateDeduction` is `.none` or `.fixed`, which this change never touches.

### New regression test, and proof it fails without the fix

Added `conformsToFederalDeductsForAge65AndOver()` to the same file. It builds a `GoldenScenario` in Swift (not a bundled fixture, per instruction), reusing ND's bundled "single, moderate income, 1.95% bracket" case's $70,000 federal AGI / all-pension income but aging the filer to 70. Expected: base $16,100 + age-65 addition $2,050 + full $6,000 senior bonus (MAGI $70,000 is under the $75,000 single phaseout threshold) = $24,150 deduction; taxable income $70,000 - $24,150 = $45,850 falls entirely inside ND's 0% first bracket ($0-$48,475), so tax = $0.00.

To prove this test actually exercises the fix, I temporarily reverted only the `.conformsToFederal` case's body back to the pre-fix base-deduction-only logic (keeping the new test in place), ran just `GoldenScenarioSingleYearTests`, and it failed as predicted:

```
✘ Test "The .conformsToFederal branch deducts the age-65+ addition and OBBBA senior bonus" recorded an issue at GoldenScenarioSingleYearTests.swift:334:9: Expectation failed: (abs(actual - 0.0) → 105.7875) < 0.01
```

$105.7875 is exactly the pre-fix figure: $70,000 - $16,100 (base deduction only) = $53,900 taxable, taxed at ND's 1.95% bracket, matching the under-65 ND fixture's own math at the same income. I then restored the fix (verified via `git diff --stat` showing the file back to its fixed state) and reran; it passed. This is direct before/after proof, not an inference.

## Finding 2 (Important): Oregon page citation

Verified independently before editing: downloaded `https://www.oregon.gov/dor/forms/FormsPubs/form-or-40-inst_101-040-1_2025.pdf` (32 pages per `pypdf`) and extracted every page's text with `pypdf` in Python. Page 17 contains only the *instruction* to use Chart S/Chart J ("Use Chart S if your filing status is single... Use Chart J if..."), with no formula text. The actual "2025 Tax rate charts" section, containing the Chart S and Chart J dollar-and-percentage formulas quoted verbatim in all four OR fixture `source` strings, is on page 32 ("Chart S: For persons filing single or married filing separately... Chart J: For persons filing jointly..."). This matches the reviewer's finding exactly; I did not need to report BLOCKED.

Changed "page 17" to "page 32" in all four `source` strings in `statetax-2026-OR.golden.json`, touching nothing else. The page 16 (Table 5 standard deduction) and page 18 (exemption credit worksheet) citations were left untouched, matching the finding's instruction that they were already verified correct.

## Finding 3 (Important): California sourcing

Tried harder to reach the official document before falling back to anything else, per instruction. A plain `curl` with no User-Agent header, and separately with a generic `curl/8.0` UA and a `python-requests` UA, all returned HTTP 200 for `https://www.ftb.ca.gov/forms/2025/2025-540-booklet.html` in this session, and a browser-style Chrome UA also returned 200 with the full page body (298,035 bytes). The earlier 403 reported for this project's tooling did not reproduce for me via `curl`; it may be specific to the original fetch tool/IP/headers used when the fixture was first written, or transient Akamai bot-detection behavior, but I have no way to confirm which. Since the official page loaded, I read it directly (not a mirror) and located every dollar figure and every bracket boundary cited in all four CA fixtures inside that page's own text:

- Standard deduction: "1 - Single $5,706 2 - Married/RDP filing jointly $11,412" -- matches.
- Schedule X 8.00%/9.30%/10.30% brackets ("57,542 72,724 1,987.41 + 8.00%...", "371,479 445,771 30,986.19 + 10.30%...") -- matches.
- Schedule Y 6.00%/11.30% brackets ("82,904 115,084 2,044.02 + 6.00%...", "891,542 1,485,906 77,276.52 + 11.30%...") -- matches.
- Single exemption-credit phaseout threshold $252,203 -- matches.
- MFJ exemption-credit phaseout threshold: the official page reads **$504,411**, but the fixture (both the moderate-income and the $1.2M MHST scenarios) had transcribed **$504,406**. This is a genuine transcription error, caught only because the official document is now readable directly. It does not change any `expectedStateTax`: both scenarios' AGI (88,588 and 1,188,588) are so far from either number that "far under" and "far over" hold regardless of which figure is correct.

Since I obtained the official document, I cited it directly rather than keeping the mirror-plus-disclosure fallback the finding offered as a second option. All four CA `source` strings now state plainly that the figures were confirmed directly against the official `ftb.ca.gov` page (with the method: browser-UA curl, HTTP 200), note that a plain automated fetch had previously 403'd earlier tooling on this project (so the reader understands why a mirror was ever in the picture), and record that the mirror is no longer the basis for these figures. The two MFJ threshold occurrences were corrected from $504,406 to $504,411, with an inline note explaining the correction and confirming it does not move either `expectedStateTax`. `sourceURL` was already the official `ftb.ca.gov` URL in all four scenarios and needed no change.

## Verification run (this pass)

Focused suite (`GoldenScenarioSingleYearTests` + `GoldenScenarioCoverageTests`), after the fix: 9 tests, 0 failures (18 single-year cases + classify + decode + the new age-65 test).

Full suite:
```
xcodebuild test -project .../RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
```
Swift Testing: "Test run with 1851 tests in 291 suites passed after 311.706 seconds" (baseline 1,850 + the 1 new age-65 test = 1,851, exact match).
`xcresulttool get test-results summary`: `passedTests: 2354`, `failedTests: 0`, `skippedTests: 6`, `totalTestCount: 2360`. 2354 = 1851 (Swift Testing) + 503 (XCTest passed); 503 + 6 skipped = 509 XCTest total, matching the 509-XCTest baseline exactly. No `MultiYearPerfTests` failure occurred, so no isolated re-run was needed.

## Production diff (this pass)

`git diff --stat main -- RetireSmartIRA/` is empty. Confirmed after all three fixes.

## Em dash check (this pass)

`grep` for U+2014 across the two modified Swift/JSON test files (`GoldenScenarioSingleYearTests.swift`, `statetax-2026-CA.golden.json`, `statetax-2026-OR.golden.json`) and this report addendum: zero matches.

## Files touched (this pass)

- Modified: `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift` (`.conformsToFederal` branch rewritten to mirror `DataManager.standardDeductionAmount` in full; new regression test added)
- Modified: `RetireSmartIRATests/GoldenScenarios/statetax-2026-OR.golden.json` (page 17 -> page 32, four `source` strings, nothing else)
- Modified: `RetireSmartIRATests/GoldenScenarios/statetax-2026-CA.golden.json` (four `source` strings rewritten for sourcing honesty; MFJ phaseout threshold typo $504,406 -> $504,411 corrected in two of them; no `expectedStateTax` or `sourceURL` changed)
