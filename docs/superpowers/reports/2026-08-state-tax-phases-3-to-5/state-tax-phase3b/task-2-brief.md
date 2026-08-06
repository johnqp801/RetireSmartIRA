### Task 2: Persistence, and the migration guarantee

**This is the highest-risk task in the phase.** `IncomeSource` is persisted through `PersistenceManager` and already carries migration logic for a removed enum case. Phase 3a's fields were never persisted, which its final review confirmed explicitly, so a renamed key could not orphan a decoder there. That protection does not apply here, and a renamed coding key orphaning a legacy decoder is exactly what shipped on the V2.3 branch with every per-task review passing.

**Files:** modify `IncomeModels.swift`, `AccountModels.swift`, `PersistenceManager.swift`; create `Phase3bPersistenceTests.swift` and `Fixtures/pre-phase3b-save.json`.

- [ ] **Step 1: Capture a real pre-3b blob before changing anything.** Build a `DataManager` with a spread of income sources and accounts, save through `PersistenceManager`, and write the resulting stored representation to the fixture path. Capture it, do not hand-write it: a typed fixture proves only that your own assumptions round-trip.

- [ ] **Step 1a: Normalise the fixture before committing.** `IncomeSource.id` is a fresh `UUID` per instance, and the blob may carry timestamps, device paths or build metadata. Any of those makes the fixture regenerate differently every capture and the test noisy. Replace unstable values with fixed literals once, by hand, and note in the file's header comment which fields were normalised and why. Phase 1 hit the same class of problem when 285 random UUIDs rewrote the generated JSON on every run.

- [ ] **Step 2: Write the failing test.** Decode the fixture, assert every source and account carries its inferred classification per spec §3.6, and assert the computed state tax for a fixed scenario is identical to the value computed before the fields existed. That second assertion is the real guarantee, worded in the spec as: existing saves decode without user intervention and preserve current calculated behavior.

- [ ] **Step 3: Add the stored properties.** `var planStructure: PlanStructure` and `var planSource: PlanSource` on both `IncomeSource` and `Account`. Both use `decodeIfPresent` with the inference as fallback, so a blob written before this phase supplies neither key and still lands on the right value.

- [ ] **Step 4: Run the persistence and behavior tests.**
```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/Phase3bPersistenceTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests 2>&1 | tail -12
```

- [ ] **Step 5: Prove the fixture test discriminates.** Change one inference rule (map `traditional401k` to `.ira` instead of `.definedContribution`), confirm the persistence test fails naming that account, revert. Then replace one inference fallback with a wrong but COMPILABLE value (`.unknown`, or a deliberately incorrect classification) and confirm the persistence test fails. Do NOT delete the `?? inference` clause: the properties are non-optional, so deletion is a compile error, which proves nothing about whether the test detects bad migration. Paste both.

- [ ] **Step 6: Full suite once, then commit.** Paste both summary lines and the tree-confirmation grep.

---

