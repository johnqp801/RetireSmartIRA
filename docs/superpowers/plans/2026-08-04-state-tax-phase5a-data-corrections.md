# State Tax Phase 5a: Data-Only Corrections: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct every Phase 4 defect that the shipped configuration model can ALREADY express, turning named golden cases from pinned-defect to clean, including both written commitments to Steve Nicolai.

**Architecture:** Each task edits one jurisdiction's bundled JSON, deletes the `knownDefect` blocks its correction resolves, and records every moved frozen-baseline value against the golden case that justifies it. No Swift model change anywhere in this plan; defects needing new fields are deferred to Phase 5b by design.

**Tech Stack:** Swift Testing, bundled JSON configs under `RetireSmartIRA/Resources/StateTaxData/2026/`, `xcodebuild test` on macOS.

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

## File Structure

| File | Responsibility |
|---|---|
| `RetireSmartIRATests/BaselineMovementLedger.swift` | **New.** The record of every frozen-baseline value this phase moves, and why. |
| `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` | **New.** Checked-in movement data: key, before, after, the golden case that justifies it. |
| `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift` | Modified once, in Task 1, to consult the movement ledger. Never modified again. |
| `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-<XX>.json` | One per corrected jurisdiction. The only production files this plan touches. |
| `RetireSmartIRATests/GoldenScenarios/statetax-2026-<XX>.golden.json` | `knownDefect` blocks deleted as their corrections land. |

---

### Task 1: The baseline movement ledger

**Files:**
- Create: `RetireSmartIRATests/BaselineMovementLedger.swift`
- Create: `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`
- Modify: `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift`

**Interfaces:**
- Produces: `BaselineMovement` (`key: String`, `before: Double`, `after: Double`, `state: String`, `goldenCase: String`, `justification: String`) and `BaselineMovementLedger.movements() throws -> [String: BaselineMovement]`. Every later task appends entries to the JSON.

**Why this exists, and why it comes first.** The frozen baseline is the only artifact that proves nothing moved by accident. Regenerating it destroys exactly the evidence it was created to hold, and its own doc comment forbids that outside a phase that attributes each movement. So the ledger inverts the problem: the baseline file stays FROZEN forever, and every deliberate movement is a checked-in record naming the golden case that authorises it. A value that moves without a record fails, which is the same property the frozen file had, preserved through a phase that changes numbers.

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/BaselineMovementLedger.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

/// One deliberate, attributed movement of a frozen-baseline value.
///
/// Phases 1 through 4 could assert that NO baseline value moved. Phase 5 moves
/// values on purpose, so that assertion is replaced rather than weakened: the
/// baseline file stays frozen, and every movement must appear here naming the
/// golden case that authorises it. A value that moves without an entry still
/// fails, which preserves the property the frozen file existed to give.
struct BaselineMovement: Codable, Equatable {
    /// The baseline key, exactly as `StateTaxBehaviorBaselineTests.key` builds
    /// it: "XX|scenario name".
    let key: String
    /// The frozen value, copied from the baseline file. Never edited.
    let before: Double
    /// The value after this phase's correction. MEASURED, never predicted.
    let after: Double
    /// Two-letter jurisdiction, for grouping in reports.
    let state: String
    /// The `name` of the golden scenario whose correction moved this value.
    /// A movement with no golden case behind it is not a correction, it is a
    /// regression that happens to have been noticed.
    let goldenCase: String
    /// One sentence naming the rule that changed, with its authority.
    let justification: String
}

enum BaselineMovementLedger {
    static func movements() throws -> [String: BaselineMovement] {
        let bundle = Bundle(for: BaselineMovementMarker.self)
        guard let url = bundle.url(forResource: "statetax-behavior-movements-2026",
                                   withExtension: "json") else {
            throw LoadError.missing
        }
        let list = try JSONDecoder().decode([BaselineMovement].self,
                                            from: Data(contentsOf: url))
        return Dictionary(uniqueKeysWithValues: list.map { ($0.key, $0) })
    }

    enum LoadError: Error { case missing }
}

private final class BaselineMovementMarker {}

@Suite("Baseline movement ledger")
struct BaselineMovementLedgerTests {

    @Test("The ledger loads and every entry is well formed")
    func ledgerIsWellFormed() throws {
        let movements = try BaselineMovementLedger.movements()
        for (key, m) in movements {
            #expect(m.key == key, "\(key): entry key disagrees with its map key")
            #expect(!m.goldenCase.isEmpty,
                    "\(key): movement with no golden case is not a correction")
            #expect(!m.justification.isEmpty, "\(key): movement with no justification")
            #expect(abs(m.before - m.after) >= 0.005,
                    "\(key): recorded as moved but before and after agree")
            #expect(key.hasPrefix(m.state + "|"),
                    "\(key): state \(m.state) does not match the key's prefix")
        }
    }
}
```

Create `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` containing exactly:

```json
[]
```

- [ ] **Step 2: Run and verify it passes on an empty ledger**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/BaselineMovementLedgerTests 2>&1 | tail -20
```

Expected: PASS. An empty ledger is the correct starting state, because nothing has been corrected yet.

- [ ] **Step 3: Teach the frozen-baseline gate to consult the ledger**

In `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift`, inside `matchesFrozenBaseline`, replace the per-scenario comparison:

```swift
        for scenario in Self.scenarios {
            let k = Self.key(state, scenario)
            let expected = try #require(baseline[k], "no baseline entry for \(k)")
            let actual = Self.computedTax(state: state, scenario: scenario)
            #expect(
                actual == expected,
                """
                \(k): computed \(actual), baseline \(expected).
                Phase 3a is behavior-inert. A moved value is a defect in the \
                change that moved it, NOT a reason to regenerate this fixture.
                """
            )
        }
```

with:

```swift
        let movements = try BaselineMovementLedger.movements()
        for scenario in Self.scenarios {
            let k = Self.key(state, scenario)
            let frozen = try #require(baseline[k], "no baseline entry for \(k)")
            let actual = Self.computedTax(state: state, scenario: scenario)

            if let moved = movements[k] {
                // A DELIBERATE, ATTRIBUTED movement. The frozen file is never
                // edited; this record carries the new value and its authority.
                #expect(moved.before == frozen,
                        """
                        \(k): the movement ledger records a `before` of \(moved.before) \
                        but the frozen baseline holds \(frozen). The ledger is describing \
                        a starting point that never existed. Fix the ledger, never the \
                        frozen file.
                        """)
                #expect(actual == moved.after,
                        """
                        \(k): computed \(actual), ledger records \(moved.after).
                        This value is under deliberate correction and has moved AGAIN, \
                        or moved to somewhere other than recorded. Diagnose which before \
                        touching either file.
                        Golden case: \(moved.goldenCase)
                        """)
            } else {
                #expect(
                    actual == frozen,
                    """
                    \(k): computed \(actual), baseline \(frozen).
                    This value moved with NO entry in the movement ledger, so nothing \
                    authorises it. Either the change that moved it is a defect, or it is \
                    a real correction that must be recorded in \
                    statetax-behavior-movements-2026.json naming the golden case behind it. \
                    Do NOT regenerate the frozen baseline.
                    """
                )
            }
        }
```

- [ ] **Step 4: Run the baseline suite**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests 2>&1 | tail -20
```

Expected: PASS, unchanged. With an empty ledger every key takes the `else` branch, which is the original assertion.

- [ ] **Step 5: PROVE the ledger can fail, in both directions**

A gate nobody has seen fail is not a gate. Do BOTH, capture both messages verbatim, and revert cleanly after each.

**Mutation A, an unauthorised movement.** Temporarily change any single Kansas bracket rate in `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json`. Re-run the baseline suite. It MUST fail on the `else` branch with the "no entry in the movement ledger" message. Revert with `git -C <worktree> checkout -- RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json` and confirm `git diff` is clean.

**Mutation B, a lying ledger.** Add one entry to the movements JSON with a `before` that does not match the frozen file, for example key `"KS|single 55, distributions only"` with `before: 999.0`, `after: 998.0`, `state: "KS"`, `goldenCase: "probe"`, `justification: "probe"`. Re-run. It MUST fail on the `moved.before == frozen` assertion. Revert the JSON to `[]` and confirm.

- [ ] **Step 6: Run the full suite**

Expected: 0 failures, 1,856 Swift Testing plus 509 XCTest, plus the 1 new test from this task.

- [ ] **Step 7: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5 add RetireSmartIRATests/BaselineMovementLedger.swift RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5 commit -m "test(state-tax): attribute every baseline movement instead of refreezing"
```

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

### Task 2: Kansas, the personal exemption

**Files:**
- Modify: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json`
- Modify: `RetireSmartIRATests/GoldenScenarios/statetax-2026-KS.golden.json`
- Modify: `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`

**THIS CARRIES A WRITTEN PROMISE TO A NAMED USER.** Steve Nicolai reported it and was told in writing it would be fixed. His scenario is pinned to the cent: $50,000 of income against the $8,240 standard deduction at 5.2% produces **$2,171.52** today where **$1,218.88** is correct, a difference of $952.64 a year for every married Kansas filer.

Add a `personalExemption` object at the TOP LEVEL of the config, a sibling of `stateDeduction` and `retirementExemptions` (NOT nested inside either), matching New Jersey's shape, which ships today as `{"single": 1000, "marriedFilingJointly": 2000, "seniorAdditionalPerFiler": 1000, "seniorAge": 65}`.

Kansas per SB 1 of the 2024 special session: **$9,160 single, $18,320 married filing jointly, $2,320 per dependent.** Kansas has no senior addition, so `seniorAdditionalPerFiler` is 0.

**The per-dependent amount needs a scope decision you must make explicitly, not silently.** `StatePersonalExemption` has no dependent field, and it is unlikely this app models a dependent count at all. Establish whether it does by grepping the codebase for a dependents input. If it does not, scope this correction to the single and married amounts, and say plainly in your report and in the Kansas fixture that the $2,320 per-dependent amount is not modelled. **Do NOT fold a notional dependent into the base amount** to make a number match; that would be inventing a household the user never described.

**Two defects, and this task fixes only ONE.** Kansas also has a per-source defect (KPERS, federal, military and Railroad Retirement fully exempt while private pensions are taxable), which needs `perSourceExemptions` and is Phase 5b. Cases KS-1 and KS-2 resolve here. KS-3, KS-4 and KS-5 do not. **KS-6 is a documented COMBINED case that needs both fixes and will NOT go green in this task**; its own summary says so and names the isolators. Do not treat KS-6 still failing as a failed correction.

Expected baseline movement: every Kansas key whose scenario has taxable income, since a personal exemption reduces taxable income for all of them.

---

### Task 3: Iowa, the retirement exclusion and Roth conversions

**Files:**
- Modify: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IA.json`
- Modify: `RetireSmartIRATests/GoldenScenarios/statetax-2026-IA.golden.json`
- Modify: `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`

**THE HIGHEST-VALUE CORRECTION IN THE PROGRAM, and the second written promise.** Iowa excludes retirement income from age 55 including **Roth conversion income by name**, no cap, no income limit. The app models none of it, so for an Iowan it invents state tax on the exact transaction this product exists to optimise: roughly $7,600 on a $200,000 conversion at 3.8%.

Under `retirementExemptions`, today's shipped values and their targets:

| Field | Shipped | Target |
|---|---|---|
| `distributionMinAge` | 59 | 55 |
| `regularExemptionMinAge` | 0 | 55 |
| `pensionExemption` | `{"kind": "none"}` | full |
| `iraWithdrawalExemption` | `{"kind": "none"}` | full |
| `exemptionAttribution` | `"household"` | per-individual |
| `rothConversionExemption` | ABSENT | added, age-gated at 55 |

For the exact JSON encoding of a full exemption, read a state that ships one today rather than guessing the enum's wire format.

**ONE VALUE MUST BE RESEARCHED, NOT COPIED.** Pennsylvania ships `rothConversionExemption` as `{"minAge": 0, "withheldPortionRemainsTaxable": true}`, and that `true` rests on PA DOR Ans 274, a Pennsylvania ruling. Iowa is the first AGE-GATED member of this rule, so `minAge` is 55, and **whether Iowa likewise taxes the withheld portion is a separate question you must establish from Iowa DOR guidance.** Copying Pennsylvania's flag unchecked is exactly the plausible-looking guess this whole program exists to eliminate. If you cannot establish it, say so and choose the treatment the Iowa fixture's own cases require, stating that you did.

**`exemptionAttribution` is per-qualifying-spouse, and one fixture case exists solely to prove it.** Iowa's exclusion is explicitly per qualifying spouse, against the engine's historical household-wide grant when either spouse qualified. The MFJ case where only one spouse qualifies is the one that catches a wrong setting here. Read the enum's cases in the Swift model to pick the right one.

Six of Iowa's cases carry defects. Expect all of them to resolve; if any does not, that is a finding.

---

### Task 4: New Mexico, the deleted bracket schedule

**Files:**
- Modify: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NM.json`
- Modify: `RetireSmartIRATests/GoldenScenarios/statetax-2026-NM.golden.json`
- Modify: `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`

The engine runs the **pre-HB252 bracket schedule, deleted from law effective TY2025**, for both single and married. HB252 was signed 2024-03-06, Chapter 67. This hits every New Mexico filer, not only retirees, and it is the oldest defect in the catalogue.

The correct 6-bracket schedule and the deleted 5-bracket one are both quoted in the New Mexico fixture's `source` strings, taken from the enrolled bill text. Use the fixture as the specification.

**One of New Mexico's five cases will NOT resolve here.** The age-65 PIT-ADJ exemption is an income-limited exemption the fixture also pins; if that needs a field the model lacks, leave its block standing and say so. Read the fixture carefully to separate the bracket defect from the exemption defect, because they are compounded in some cases and isolated in others.

Expect large baseline movements: replacing an entire bracket schedule moves every New Mexico key with taxable income.

---

### Task 5: Georgia, the stale rate and standard deduction

**Files:**
- Modify: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json`
- Modify: `RetireSmartIRATests/GoldenScenarios/statetax-2026-GA.golden.json`
- Modify: `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`

Georgia's flat rate is **5.39% in the config against 4.99% in law**, and the standard deduction is stale at **$15,000 single / $30,000 married**. Per HB 463, signed 2026-05-11, which the fixture cites to the Governor's own press release.

**Georgia's retirement exclusion is CORRECT and must not be touched.** The $65,000 at 65-or-over and $35,000 at 62-to-64 tiers were confirmed correct by the audit and re-confirmed in Phase 4 against the IT-511 booklet. All five Georgia cases carry the same stale rate and deduction mechanism, so all five should resolve from one edit.

Note for the report: Georgia rises to $70,000 in TY2027, recorded in the fixture as a diary item. Do not encode it; this config is TY2026.

---

### Task 6: Utah, the stale rate only

**Files:**
- Modify: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-UT.json`
- Modify: `RetireSmartIRATests/GoldenScenarios/statetax-2026-UT.golden.json`
- Modify: `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`

The engine carries **4.55%**. Enrolled S.B. 60 sets the rate at **4.45%**, cutting it from 4.5%, so the app is stale against even the pre-cut rate and Utah has been wrong for longer than one legislative session.

**THIS TASK CORRECTS THE RATE AND NOTHING ELSE.** Utah's dominant defect is its two unmodelled credits, the Taxpayer Tax Credit (UCA 59-10-1018) and the age-gated Retirement Credit (UCA 59-10-1019), and **there is no credit representation anywhere in `StateTaxConfig`.** Those are Phase 5b.

Exactly one of Utah's five cases should resolve here: the one whose fixture states that at its income both credits are legitimately zero under real law too, so the entire gap is the stale rate. **The other four must keep their `knownDefect` blocks**, and each block's summary should still describe the credit gap accurately after your change. If a summary now overstates what remains wrong, correct its wording without deleting the block.

Do not delete a block merely because its number moved closer.

---

### Task 7: Indiana, the personal exemption

**Files:**
- Modify: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-IN.json`
- Modify: `RetireSmartIRATests/GoldenScenarios/statetax-2026-IN.golden.json`
- Modify: `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`

Indiana's **$1,000 single / $2,000 married** personal exemption is entirely unmodelled, per IT-40 booklet Line 1. Every Indiana discrepancy in the catalogue is exactly `exemption x 0.0295`, which is what makes this a diagnosed mechanism rather than a coincidence, and it is a useful arithmetic check on your work.

Use the same top-level `personalExemption` object as Kansas, a sibling of `stateDeduction`. Indiana has no senior addition.

All four Indiana cases should resolve. Indiana's rate of 2.95% is confirmed correct and must not be touched.

---

### Task 8: Close Phase 5a

**Files:**
- Create: `.claude/memory/roadmap/2026-08-04-state-tax-phase5a-ledger.md`

- [ ] **Step 1: Count what moved.**

```bash
python3 -c "
import json,glob,collections
tot=0; st=collections.Counter()
for f in sorted(glob.glob('/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRATests/GoldenScenarios/*.golden.json')):
    d=json.load(open(f))
    n=sum(1 for s in d['scenarios'] if s.get('knownDefect'))
    tot+=n
    if n: st[d['state']]=n
print('defect cases remaining:',tot,'across',len(st),'jurisdictions')
m=json.load(open('/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json'))
print('baseline values moved:',len(m),'across',len({x[\"state\"] for x in m}),'jurisdictions')
"
```

Phase 4 closed with 118 defect cases across 35 jurisdictions. Report the delta.

- [ ] **Step 2: Run the FULL suite** and confirm 0 failures.

- [ ] **Step 3: Confirm production changes are confined to config data.**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5 diff --stat main -- RetireSmartIRA/
```

Expected: ONLY files under `RetireSmartIRA/Resources/StateTaxData/2026/`. **Any `.swift` file here means this plan's scope boundary was crossed and it must be justified or reverted.** This replaces Phase 4's empty-diff check: the diff is no longer empty by design, but it must still be confined.

- [ ] **Step 4: Write the ledger**, following `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md`. It must carry: every correction with its authority; every baseline movement grouped by jurisdiction; every `knownDefect` still standing and the field it waits on; and an explicit statement of what Phase 5b inherits.

- [ ] **Step 5: State the promises plainly.** Kansas and Iowa are the two written commitments. Say whether each is fully corrected, partially corrected, or not, and for Kansas name precisely which of its two defects remains. **Steve was promised both. A half-corrected Kansas described as "fixed" would be the failure this program has been trying to avoid all along.**

- [ ] **Step 6: Commit.**

---

## Self-review against the spec

**Spec 4a Phase 5, "apply corrections tier by tier"** is deliberately reordered per the recorded 2026-08-04 amendment: base values first, because they hit every filer. Kansas and Iowa are pulled into this wave because both are written promises and both are expressible today.

**Spec 3.4 Layer 1, the two-model protocol,** is discharged by Phase 4's golden scenarios per the recorded amendment. Task procedures direct implementers to treat the fixtures as the specification and forbid re-researching the law, which is what makes that amendment safe.

**Spec 4a's "each sub-phase turns a defined set of golden cases red to green and breaks nothing else"** is enforced by Step 5 of the shared procedure (the self-cleaning pin) and Task 8 Step 3 (the confined diff).

**Spec 5's frozen-baseline requirement** is preserved rather than abandoned. Task 1 keeps the file frozen forever and moves attribution into a ledger, which is stricter than regenerating.

**DEFERRED to Phase 5b, and each is deferred for a reason established by reading the model, not by preference:** all credits (NE, OR, UT, OH); Ohio's bracket base amount; South Carolina's $15,000 age-65 deduction; every per-source correction (KS's second defect, MA, HI, AZ, NC, ID, VT, DC); every attribution and age-gate correction (OK, DE, LA, AR, SC, WV); the OK/AR/SC base values, which must be corrected together with a re-derivation of their golden expectations; and the cross-path work (I2, E8). **Vermont and DC additionally require model extensions before they are satisfiable at all.**
