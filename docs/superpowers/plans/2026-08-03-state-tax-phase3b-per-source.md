# State Tax Phase 3b: per-source exemptions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let state exemptions depend on where retirement money came from, and correct New York's uncapped government-pension exclusion.

**Architecture:** Two internal dimensions (`PlanStructure`, `PlanSource`) carried by both `IncomeSource` and `Account`, surfaced as one flat picker. The engine gains an optional `distributionComponents` parameter carrying owner, structure, source and amount. Config gains an ordered per-source match list, empty for all 51 jurisdictions except New York.

**Spec:** `docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md`. It is the source of every value, enum case and rule. Do not re-derive them here.

**Worktree:** `.worktrees/state-tax-phase3b`, branch `feature/state-tax-phase3b`, off `main` @ `b138a62`.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Only New York's numbers may move, and only in Task 4.** Tasks 1, 2, 3, 5 and 6 are behavior-inert. The Phase 3a frozen baseline (`RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift`, 51 jurisdictions x 20 scenarios) is the gate. Never edit it or its fixture. If it goes red outside Task 4, your change is the defect.
- **Never edit `RetireSmartIRA.xcodeproj/project.pbxproj`.** Both source roots are `PBXFileSystemSynchronizedRootGroup`, so new files are bundled automatically. If you think you need to, stop and report BLOCKED.
- **No em dash characters** anywhere in code, comments, tests, JSON or commit messages. The Phase 3a gate caught four that slipped through six task reviews.
- **Sync the DataManager mirror in the same commit.** `DataManager.stateTaxBreakdown` hand-duplicates `TaxCalculationEngine.applyRetirementExemptions`. On Phase 3a alone, five changes landed in the engine and not the mirror, two of them found only by the final review. **Before calling any engine task done, run `grep <new identifier> RetireSmartIRA/DataManager.swift` and report the output.**
- **Regenerate your own JSON.** A task that gives any real state a non-default config value must regenerate the 51 files in the same commit, or that state regresses on the production path and the Phase 1 Layer B gate goes red. `config(for:)` resolves through bundled JSON, not the legacy Swift table. Never add a `configs2026Legacy` fallback; Phase 1 spent a task removing that pattern.
- **Extend the encoder fixtures in the same commit.** `retirementExemptionsRoundTrip` and `retirementExemptionsEncodesExpectedJSONShape` in `StateTaxCodableRoundTripTests.swift` are the general guard against a dropped `encode` line. They silently went stale twice in Phase 3a while their titles claimed full coverage. Any new encoded field gets a fixture value that is **not** its own default, plus an assertion, plus a mutation proving the assertion discriminates. Update the title's field count.
- **Shipped-data assertions read raw JSON keys, never decoded values.** A decoded assertion passes even when the key is absent from every file, because the asserted value doubles as the decode fallback. This bit three separate tasks in Phase 3a.
- **To claim a test discriminates, mutate the code or data under test** and paste the failure. Mutating an expectation proves only that the comparison is wired. State plainly which mutations you actually ran.
- **Bash cwd resets to `/Users/johnurban/Projects/RetireSmartIRA` between calls.** Prefix EVERY command, read-only ones included, with `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && ...`. Chaining does not protect the next call. Before trusting any suite count, grep the log for the `.xcodeproj` path.
- **Stage explicit paths.** Never `git add -A`; other agents may hold transient mutations in this shared worktree.

## Efficiency protocol

Phase 3a cost about 4.5 hours of agent time, and a measurable share of that was avoidable. Follow these.

1. **Run the FULL suite once, at the end of your task.** Targeted `-only-testing` runs finish in under a second where the full suite takes five minutes. Phase 3a ran the full suite roughly a dozen times when three would have done.
2. **Never background an xcodebuild run.** Seven Phase 3a agents backgrounded verification and returned before it finished, costing a full round trip each. Run in the foreground and read the output in the same turn.
3. **Measure before writing tests.** Phase 3a's Task 7 was told to determine what was already guarded before adding anything, found four of five fields covered, and wrote one test instead of five. Do the same: mutate first, then write only what survived.
4. **Do not hand-count lines in prose.** Paste `git diff --stat`. Three Phase 3a reports wasted reviewer attention on miscounts.

## Baseline

Capture before Task 1 and do not take on faith:

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/p3b-baseline.log | tail -20
```

Expected at `b138a62`: 1,657 Swift Testing in 278 suites + 503 XCTest, 0 failures.

---

## The one place this plan departs from the spec, deliberately

Spec §3.4 says the scalar is "replaced at the boundary." **Do not replace it.** `scenarioRetirementDistributions` has **42 call sites**: 13 in `DataManager`, 6 in `TaxCalculationEngine`, 1 in `StateComparisonView`, 2 in `StateTaxData`, and 20 across 10 test files. Replacing the parameter would churn all 42, and the mechanical noise would bury the change a reviewer needs to see.

Instead, **add** an optional parameter beside it:

```swift
distributionComponents: [RetirementDistributionComponent]? = nil
```

`nil` means the engine synthesises one `unknown` component from the scalar, which is exactly today's behavior, so all 42 existing call sites stay correct and untouched. Only the callers that genuinely know provenance opt in.

The cost is two sources of truth for one quantity, which Task 3 closes with an invariant: when components are supplied, their amounts must sum to the scalar. That is asserted in the engine and tested, so a caller that sets one and forgets the other fails loudly rather than silently double-counting or dropping income.

---

## File Structure

**Created:**
| File | Responsibility |
|---|---|
| `RetireSmartIRA/RetirementPlanClassification.swift` | `PlanStructure`, `PlanSource`, and the inference rules from spec §3.6 |
| `RetireSmartIRA/PerSourceExemptionRule.swift` | The rule type and its matching logic |
| `RetireSmartIRA/RetirementDistributionComponent.swift` | Owner plus classification plus amount |
| `RetireSmartIRATests/Phase3bClassificationTests.swift` | Domain model and inference |
| `RetireSmartIRATests/Phase3bPersistenceTests.swift` | Pre-3b blob decode, behavior preserved |
| `RetireSmartIRATests/Fixtures/pre-phase3b-save.json` | A real pre-3b persisted blob, captured not typed |
| `RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json` | New York's IT-201 cases |

**Modified:** `IncomeModels.swift`, `AccountModels.swift`, `PersistenceManager.swift`, `StateTaxData.swift`, `StateTaxCodable.swift`, `TaxCalculationEngine.swift`, `DataManager.swift`, `IncomeSourcesView.swift`, `AccountsView.swift`, `StateTaxCodableRoundTripTests.swift`, and the 51 bundled JSON files (Task 4 only).

**Task order and why.** Task 2 is the highest-risk work and comes second so a persistence failure surfaces before anything is built on it. Task 3 is the largest engine change and stays inert. Task 4 is the only task where a number moves. Task 5 is the only task with no mechanical gate. Task 6 is the gate.

---

### Task 1: Domain model and inference

**Files:** create `RetirementPlanClassification.swift`, `PerSourceExemptionRule.swift`; modify `StateTaxCodable.swift`; create `Phase3bClassificationTests.swift`.

**Interfaces produced:** `PlanStructure`, `PlanSource` (cases exactly as spec §3.1), `PerSourceExemptionRule` with `matches(structure:source:) -> Bool`, and `RetirementPlanClassification.infer(incomeType:) / .infer(accountType:)` per spec §3.6.

Types only. Nothing consumes them yet, which is intended: Task 2 wires them to storage and Task 3 to the engine.

- [ ] **Step 1: Write the failing tests.** Cover every inference row in spec §3.6, and rule matching including the two cases that carry the design's whole point: a rule matching `[.nyStateOrLocal, .federalCivilian]` x `[.definedBenefit]` must NOT match `(.definedBenefit, .otherStateOrLocal)` and must NOT match `(.definedContribution, .nyStateOrLocal)`. Empty `matchSources` or `matchStructures` means "any".

- [ ] **Step 2: Run and watch it fail to compile.** Paste the transcript verbatim.

- [ ] **Step 3: Implement.** Both enums are `String`-backed so Codable is synthesised. `PerSourceExemptionRule` is a plain struct; its `treatment` is `RetirementIncomeExemptions.ExemptionLevel`, which already has a hand-written Codable.

- [ ] **Step 4: Targeted run, then commit.**
```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/Phase3bClassificationTests 2>&1 | tail -12
```
```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && git add RetireSmartIRA/RetirementPlanClassification.swift RetireSmartIRA/PerSourceExemptionRule.swift RetireSmartIRATests/Phase3bClassificationTests.swift && git commit -m "feat(state-tax): plan structure and source dimensions with inference"
```

---

### Task 2: Persistence, and the migration guarantee

**This is the highest-risk task in the phase.** `IncomeSource` is persisted through `PersistenceManager` and already carries migration logic for a removed enum case. Phase 3a's fields were never persisted, which its final review confirmed explicitly, so a renamed key could not orphan a decoder there. That protection does not apply here, and a renamed coding key orphaning a legacy decoder is exactly what shipped on the V2.3 branch with every per-task review passing.

**Files:** modify `IncomeModels.swift`, `AccountModels.swift`, `PersistenceManager.swift`; create `Phase3bPersistenceTests.swift` and `Fixtures/pre-phase3b-save.json`.

- [ ] **Step 1: Capture a real pre-3b blob before changing anything.** Build a `DataManager` with a spread of income sources and accounts, save through `PersistenceManager`, and write the resulting stored representation to the fixture path. Capture it, do not hand-write it: a typed fixture proves only that your own assumptions round-trip.

- [ ] **Step 2: Write the failing test.** Decode the fixture, assert every source and account carries its inferred classification per spec §3.6, and assert the computed state tax for a fixed scenario is identical to the value computed before the fields existed. That second assertion is the real guarantee, worded in the spec as: existing saves decode without user intervention and preserve current calculated behavior.

- [ ] **Step 3: Add the stored properties.** `var planStructure: PlanStructure` and `var planSource: PlanSource` on both `IncomeSource` and `Account`. Both use `decodeIfPresent` with the inference as fallback, so a blob written before this phase supplies neither key and still lands on the right value.

- [ ] **Step 4: Run the persistence and behavior tests.**
```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/Phase3bPersistenceTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests 2>&1 | tail -12
```

- [ ] **Step 5: Prove the fixture test discriminates.** Change one inference rule (map `traditional401k` to `.ira` instead of `.definedContribution`), confirm the persistence test fails naming that account, revert. Then delete the `?? inference` fallback from one decode and confirm the test fails rather than silently defaulting. Paste both.

- [ ] **Step 6: Full suite once, then commit.** Paste both summary lines and the tree-confirmation grep.

---

### Task 3: The engine takes components, still inert

**Files:** create `RetirementDistributionComponent.swift`; modify `TaxCalculationEngine.swift`, `DataManager.swift`.

**Read the departure note above before starting.** You are ADDING a parameter, not replacing one.

- [ ] **Step 1: Write the failing tests.**
  - A single `unknown` component equals the scalar path exactly, for a grid of states and ages.
  - Components carrying different owners are gated per owner under `.perQualifyingSpouse`, which is what closes the Phase 3a approximation. Phase 3a's `ExemptionAttribution` doc comment records that the unowned scalar was attributed to the primary as a documented limitation; assert that a spouse-owned component is now gated on the spouse's age instead.
  - **The invariant:** supplying components whose amounts do not sum to the scalar is a programming error. Assert it fails loudly.

- [ ] **Step 2: Run, watch it fail, paste.**

- [ ] **Step 3: Implement.** Add `distributionComponents: [RetirementDistributionComponent]? = nil` to `calculateStateTax` and `applyRetirementExemptions`. When nil, synthesise `[RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: scenarioRetirementDistributions)]`. The existing age gate and attribution logic then run per component rather than over one scalar.

- [ ] **Step 4: Add the mirror's test seam and sync it.** Give `DataManager.stateTaxBreakdown(forState:filingStatus:)` a `configOverride: StateTaxConfig? = nil` parameter, defaulting to today's `StateTaxData.config(for:)` lookup. Phase 3a's Task 6 review named the absence of this seam as the reason the mirror's age-gate branch was proven by nothing while the engine's identical branch was proven by a test. Then apply the same per-component logic in the mirror.

- [ ] **Step 5: Run the grep and report it.**
```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && grep -n "distributionComponents\|RetirementDistributionComponent" RetireSmartIRA/DataManager.swift
```

- [ ] **Step 6: Targeted, then full suite once, then commit.** The baseline must hold all 1,020 values; this task is inert.

---

### Task 4: New York, the only jurisdiction whose numbers move

**Files:** modify `StateTaxData.swift`, `StateTaxCodable.swift`, `TaxCalculationEngine.swift`, `DataManager.swift`; regenerate the 51 JSON files; create `GoldenScenarios/statetax-2026-NY.golden.json`.

- [ ] **Step 1: Write New York's golden scenarios first**, from IT-201 with line numbers cited per the citation discipline in the parent spec §3.4. Four cases, and the fourth is the regression test for the defect this design was revised to remove:
  1. NYC employee pension alone: fully excluded, Line 26.
  2. NYC pension plus a private pension: government portion uncapped, private portion against the shared $20,000, Line 29.
  3. A government employee's 403(b): capped, because Line 26 excludes salary-reduction plans.
  4. **An out-of-state public pension: capped.** A single `.governmentPension` case would have given this the uncapped exclusion.

You must open every `sourceURL` and check every clause of `source` against it, and say in your report that you did. Phase 2 of this program shipped three confidently wrong citations whose expected values were right, so every test passed.

- [ ] **Step 2: Run them and watch cases 1 and 2 fail.** Cases 3 and 4 should already pass, since today's behavior caps everything. Paste the transcript; it is the empirical statement of Alan's bug.

- [ ] **Step 3: Add `perSourceExemptions` to `RetirementIncomeExemptions`**, defaulting to `[]`, with Codable and the fixture extension required by Global Constraints.

- [ ] **Step 4: Apply the rules in the engine and the mirror.** First matching rule wins; income matching nothing falls through to the existing per-state exemption. Sync both in this commit.

- [ ] **Step 5: Give New York its rule** (spec §3.3) and **regenerate the 51 files**. Expected diff: `perSourceExemptions` appears in New York's file only. Run the deletion check and confirm no output:
```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && git diff --numstat RetireSmartIRA/Resources/StateTaxData/2026/ | awk '$2 != 0 {print "DELETION in " $3}'
```

- [ ] **Step 6: The baseline WILL move, and only for New York.** Inspect every changed entry, confirm each is a New York row whose movement the golden scenarios explain, then regenerate the fixture in this commit with the diff pasted in your report. **This is the only task in the phase permitted to regenerate that fixture.** If any non-New-York entry moves, stop and report; that is a defect, not a correction.

- [ ] **Step 7: Full suite once, then commit.**

---

### Task 5: The picker, and the disclosures

**Files:** modify `IncomeSourcesView.swift`, `AccountsView.swift`, and the CPA briefing.

No mechanical gate covers this task, which is why Task 6 requires in-app verification.

- [ ] **Step 1: The picker.** One flat list, exactly the rows and mappings in spec §3.2. It appears on `.pension` income rows and on traditional accounts. Roth and inherited accounts get none, since no audited rule turns on their plan kind.

- [ ] **Step 2: A classified 403(b) or 457 displays as itself** in the accounts list, the account detail view and the CPA briefing. The engine-level `AccountType` is unchanged; the visible plan type wins. Nothing continues to call it a Traditional 401(k) after the user has said it is not one.

- [ ] **Step 3: The unclassified New York prompt.** For a resident of a state with a non-empty `perSourceExemptions`, a `.pension` row with `source == .unknown` shows a prominent prompt worded as a question about the pension, and the result carries a visible limitation until answered. Not a subtle optional field.

- [ ] **Step 4: Hawaii's contextual disclosure**, surfaced where a Hawaii user holding a pension will meet it, stating that the employer-funded versus employee-contributed split is not modelled and its tax may be overstated.

- [ ] **Step 5: View tests** for the picker's mappings, the 403(b) display, and the presence of the NY prompt and Hawaii note under the right conditions and their absence otherwise. Then full suite once, and commit.

---

### Task 6: The phase gate

- [ ] **Step 1: Full macOS suite**, foreground, tree confirmed, both summary lines pasted.
- [ ] **Step 2: iOS build**, and confirm all 51 `statetax-2026-*.json` are in the built `.app`. Phase 1 found nobody had checked this; a universal binary with an unbundled resource throws on every iPhone launch while every Mac test stays green.
- [ ] **Step 3: Confirm the scope claims.** `git diff main --stat` for `project.pbxproj` (empty) and for `Resources/StateTaxData/2026/` (New York only beyond the schema key). No em dash in any added Swift or JSON line. Every jurisdiction except New York unchanged in the behavior baseline.
- [ ] **Step 4: Regeneration determinism.** Regenerate twice; the diff must be empty both times.
- [ ] **Step 5: IN-APP VERIFICATION BY JOHN.** Build and run, and have him confirm: the picker's wording reads correctly to a retiree; a NYC pension classified as NY state or local drops the New York tax; an out-of-state public pension does not; a 403(b) shows as a 403(b); the NY prompt and the Hawaii note appear when they should. This step has no substitute and was the final task on V2.3 for the same reason.
- [ ] **Step 6: Whole-branch review** via superpowers:requesting-code-review, on the most capable model. Point it at the persistence migration and at the DataManager mirror specifically, and give it this instruction: grep each new identifier against `DataManager.swift` and report the count, because that one grep is what found the two mirror drifts the six Phase 3a per-task reviews missed.

---

## Self-Review

**Spec coverage.** §3.1 domain model is Task 1. §3.2 picker is Task 5. §3.3 config and New York's rule is Task 4. §3.4 components is Task 3. §3.5 mirror and its test seam is Task 3 Step 4. §3.6 migration is Task 2. §3.7 presentation, all three parts, is Task 5. §4 New York only is Task 4 Step 6. §5 testing is distributed with the golden scenarios in Task 4 Step 1. §6 error handling is covered by the typed decode error in Task 1 and the sum invariant in Task 3.

**The departure from the spec** is stated at the top with its measurement (42 call sites) and its mitigation (the sum invariant), rather than being made silently inside a task.

**Type consistency.** `PlanStructure` and `PlanSource` are defined in Task 1 and used unchanged in Tasks 2, 3, 4 and 5. `RetirementDistributionComponent` carries `owner: Owner`, reusing the existing enum from `AccountModels.swift` rather than introducing a parallel one. `PerSourceExemptionRule.treatment` is `RetirementIncomeExemptions.ExemptionLevel`, which already exists and already has a hand-written Codable, so no new serialisation surface is added for it.

**Known soft spot.** Task 5 has no mechanical gate, which is why Task 6 Step 5 exists and is not optional.
