### Task 1: Domain model and inference

**Files:** create `RetirementPlanClassification.swift`, `PerSourceExemptionRule.swift`; modify `StateTaxCodable.swift`; create `Phase3bClassificationTests.swift`.

**Interfaces produced:** `PlanStructure`, `PlanSource` (cases exactly as spec §3.1), `PerSourceExemptionRule` with `matches(structure:source:) -> Bool`, and `RetirementPlanClassification.infer(incomeType:) / .infer(accountType:)` per spec §3.6.

Types only. Nothing consumes them yet, which is intended: Task 2 wires them to storage and Task 3 to the engine.

- [ ] **Step 1: Write the failing tests.** Cover every inference row in spec §3.6, and rule matching including the two cases that carry the design's whole point: a rule matching `[.nyStateOrLocal, .federalCivilian]` x `[.definedBenefit]` must NOT match `(.definedBenefit, .otherStateOrLocal)` and must NOT match `(.definedContribution, .nyStateOrLocal)`. Empty `matchSources` or `matchStructures` means "any".

- [ ] **Step 2: Run and watch it fail to compile.** Paste the transcript verbatim.

- [ ] **Step 3: Implement.** Both enums are `String`-backed so Codable is synthesised. `PerSourceExemptionRule` is a plain struct; its `treatment` is `RetirementIncomeExemptions.ExemptionLevel`, which already has a hand-written Codable.

- [ ] **Step 3a: Add the typed decode error spec §6 requires**, which synthesised Codable does not give you: an unrecognised `PlanStructure` or `PlanSource` string must throw a `DecodingError` naming the state, never fall back to `.unknown`. A silent fallback here would turn a corrupt or hand-edited config into a plausible wrong answer, which is the failure mode this whole program exists to remove. Test it with a hand-written JSON literal carrying a bogus string.

- [ ] **Step 4: Targeted run, then commit.**
```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/Phase3bClassificationTests 2>&1 | tail -12
```
```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && git add RetireSmartIRA/RetirementPlanClassification.swift RetireSmartIRA/PerSourceExemptionRule.swift RetireSmartIRATests/Phase3bClassificationTests.swift && git commit -m "feat(state-tax): plan structure and source dimensions with inference"
```

---

