# Task 5 brief


---

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md`. **Two amendments apply and are recorded in `.claude/memory/decisions/log.md` (2026-08-04):** (1) base-value defects are corrected BEFORE the retirement-exemption tiers, because they hit every filer rather than only retirees; (2) Phase 4's golden scenarios stand in for the two-model confirmation protocol, so no external model pass gates these corrections.
- **THIS IS THE FIRST PHASE IN THE PROGRAM WHERE NUMBERS MOVE.** Phases 1 through 4 each ended with `git diff main -- RetireSmartIRA/` empty. That is no longer the goal and no longer possible. What replaces it is attribution: every moved value must be traceable to a named golden case citing a state's own published form.
- **Never regenerate the frozen baseline wholesale.** `RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json` holds 1,020 entries (51 jurisdictions x 20 scenarios) captured before Phase 3a. Its own test file says regeneration "is legitimate only in Phase 5, where each moved value is attributable to a named golden scenario citing a state's own published form." Task 1 builds the mechanism that enforces that sentence. Until it exists, correct nothing.
- **A golden case going green is the deliverable, not a green suite.** Deleting a `knownDefect` block is how a correction is declared complete. The block's own second assertion forces this: once the engine matches the form, the test fails with "delete the knownDefect block."
- **Do not touch OK, AR or SC in this plan.** Their `expectedStateTax` values are computed against the app's CONFIGURED brackets, which are themselves wrong, so correcting their base values without re-deriving their golden expectations in the same change turns meaningful pins into meaningless ones. They carry an explicit `PHASE 5 WARNING`. They are Phase 5b work, paired with the re-derivation.
- **NO EM DASH CHARACTERS** in any file, including JSON strings, code comments and reports. Standing user preference and a recurring review finding on this project.
- **Tests are the source of truth** (CLAUDE.md). Baseline at branch point: 1,856 Swift Testing in 292 suites + 509 XCTest, 0 failures, 6 pre-existing env-gated skips. `MultiYearPerfTests` has a known pre-existing wall-clock flake; re-run it in isolation rather than calling it a regression.
- **Never edit by chained `cd`.** Bash cwd resets between calls. Use absolute paths and `git -C`.
- **Never background an xcodebuild command.** Run it FOREGROUND with the Bash tool's `timeout` parameter set to 600000. Three agents died in Phase 4 by backgrounding builds; the 120 second default is not the ceiling.

**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5`, branch `feature/state-tax-phase5`, off `main` @ `2b4f4c1`.

**Build command:**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

---

## Scope: what this plan does and does not cover

Phase 4 catalogued 118 defect cases across 35 jurisdictions. This plan corrects only those the **shipped configuration model can already express.** That boundary was established by reading the model, not assumed:

**EXPRESSIBLE TODAY, and therefore in scope:**

| Field | Exists because | Used here by |
|---|---|---|
| `personalExemption` (`StatePersonalExemption`: `single`, `marriedFilingJointly`, `seniorAdditionalPerFiler`, `seniorAge`) | Phase 3a created it; New Jersey ships it today | **Kansas**, Indiana |
| `distributionMinAge`, `regularExemptionMinAge` | Phase 3a made the hardcoded 59.5 gate configurable | **Iowa** |
| `pensionExemption`, `iraWithdrawalExemption` | pre-existing | **Iowa** |
| `rothConversionExemption` (`minAge`, `withheldPortionRemainsTaxable`) | Phase 3a replaced the hardcoded PA/IL/MS switch | **Iowa** |
| `exemptionAttribution` | Phase 3a added it | **Iowa** |
| plain bracket arrays and `stateDeduction` | pre-existing | **New Mexico**, **Georgia**, **Utah** (rate only) |

**NOT EXPRESSIBLE TODAY, and therefore deferred to Phase 5b:**

- **Any credit at all.** There is no credit representation in `StateTaxConfig`. Nebraska's $171 personal-exemption credit, Oregon's $256 per-exemption credit, Utah's Taxpayer Tax Credit and Retirement Credit, and Ohio's retirement-income and senior credits all need a new model concept. Utah's stale RATE is in scope here; Utah's credits are not.
- **A bracket base amount.** `TaxBracket` is `threshold` plus `rate` only (`RetireSmartIRA/TaxModels.swift:10-13`). Ohio's "$332 plus 2.75% of the amount over $26,050" cannot be encoded.
- **South Carolina's separate $15,000 age-65 deduction** against any income, reduced by the retirement deduction claimed. No field models it.
- **Vermont and DC**, whose fixture sets are UNSATISFIABLE by any configuration until `PlanSource` gains a uniformed-services case and `ClassifiedPensionSource` gains a survivor flag. Phase 4 proved this; do not attempt them here.

**Partial corrections are expected and are correct.** Utah, Nebraska, Oregon and Ohio will each end this plan with SOME `knownDefect` blocks deleted and others still standing. That is the design: a state is not "done" until every block is gone, and saying so in the report is required.

---

## The correction procedure, shared by Tasks 2 through 7

Written once. Each task below carries only what differs.

- [ ] **Step 1: Read the golden fixture first, and treat it as the specification.** `RetireSmartIRATests/GoldenScenarios/statetax-2026-<XX>.golden.json`. Every `knownDefect.summary` names the mechanism, and every `source` carries the primary-source citation and the arithmetic. **You are not researching the law again. Phase 4 did that and a reviewer independently opened every document.** Your job is to make the config produce the numbers the fixtures already assert.

- [ ] **Step 2: Read the shipped config** at `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-<XX>.json` and identify exactly which fields must change.

- [ ] **Step 3: Capture the before-state of every baseline key for this jurisdiction.**

```bash
python3 -c "
import json
b=json.load(open('/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json'))
for k,v in sorted(b.items()):
    if k.startswith('<XX>|'): print(f'{k}\t{v}')
"
```

- [ ] **Step 4: Make the config edit.** Data only. If you find yourself needing a Swift change, STOP and report BLOCKED: that jurisdiction belongs to Phase 5b and this plan's scope boundary was drawn by reading the model.

- [ ] **Step 5: Run the golden suite and read what moved.**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests 2>&1 | tail -40
```

Cases whose defect you fixed will now FAIL with "now MATCHES its published form ... Delete the knownDefect block". **That failure is success.** It is the self-cleaning pin doing its job.

- [ ] **Step 6: Delete the `knownDefect` block from every case your correction resolved.** Delete the whole block, never edit `observedToday` to match. If a case you expected to resolve did NOT, say so in the report and diagnose it rather than adjusting anything.

- [ ] **Step 7: Record every baseline movement.** Run the baseline suite; each moved key fails naming its computed value. Add one entry per moved key to `statetax-behavior-movements-2026.json` with the MEASURED `after` copied from the failure message, the `before` copied from the frozen file, the `goldenCase` naming the scenario, and a one-sentence `justification` with its authority.

- [ ] **Step 8: Re-run both suites.** Golden green, baseline green.

- [ ] **Step 9: Run the FULL suite.** Other suites may legitimately move, because this phase changes real tax numbers. Any other suite that fails must be diagnosed and reported, never silenced. If its expectation encoded the old wrong behaviour, updating it IS correct, and the report must say which test, which value, and why.

- [ ] **Step 10: Report,** listing every `knownDefect` deleted, every one still standing and why, and every baseline movement.

- [ ] **Step 11: Commit** with explicit paths. Never `git add -A`.

---

### Task 5: Georgia, the stale rate and standard deduction

**Files:**
- Modify: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json`
- Modify: `RetireSmartIRATests/GoldenScenarios/statetax-2026-GA.golden.json`
- Modify: `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`

Georgia's flat rate is **5.39% in the config against 4.99% in law**, and the standard deduction is stale at **$15,000 single / $30,000 married**. Per HB 463, signed 2026-05-11, which the fixture cites to the Governor's own press release.

**Georgia's retirement exclusion is CORRECT and must not be touched.** The $65,000 at 65-or-over and $35,000 at 62-to-64 tiers were confirmed correct by the audit and re-confirmed in Phase 4 against the IT-511 booklet. All five Georgia cases carry the same stale rate and deduction mechanism, so all five should resolve from one edit.

Note for the report: Georgia rises to $70,000 in TY2027, recorded in the fixture as a diary item. Do not encode it; this config is TY2026.
