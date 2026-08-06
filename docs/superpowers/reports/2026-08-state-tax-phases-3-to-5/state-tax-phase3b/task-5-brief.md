### Task 5: Multi-year receives classified pension income

`ProjectionEngine` gets scalars: `inputs.primaryPensionIncome + inputs.spousePensionIncome` summed into one number, and `computeStateTax` then synthesises a `.pension` row from it. So no classification reaches the projection today. Without this task Alan sees the uncapped exclusion on Scenarios and the capped one in the Multi-Year plan, which is a second deliberate cross-path divergence in a program already carrying one.

**Files:** `MultiYearStaticInputs.swift`, `MultiYearInputAdapter.swift`, `ProjectionEngine.swift`, `WidowStressTest.swift`.

**Out of scope, and it must be disclosed rather than discovered:** `AccountSnapshot` is NOT widened. It collapses every account into nine doubles and is a persisted `Codable` type whose four traditional scalars are read by the bucket math, the RMD basis and the snapshot tests. Consequence: **account classification affects the single-year calculation and not the projection.** No rule shipping in this phase depends on it, so no number is wrong; Steve's flag is stored and displayed but inert until Kansas is verified. Add that sentence to Hawaii's neighbours in the disclosure surface built in Task 6.

- [ ] **Step 1: Write the failing cross-path test.** A household with a NYC government pension must produce the same New York state tax from `DataManager` and from `ProjectionEngine`'s year one. It fails before this task because the projection caps what the single-year path excludes.
- [ ] **Step 2: Widen the pension inputs.** `primaryPensionIncome` and `spousePensionIncome` carry classification. Keep the existing scalar accessors so unrelated consumers stay untouched, the same additive approach the distribution components use.
- [ ] **Step 3: Pass components into `computeStateTax`** instead of synthesising an unclassified `.pension` row.
- [ ] **Step 4: Confirm the pins the phase must not move.** `GoldenScenarioCrossPathTests` still reads single-year 42.0 and multi-year 200.40469973890345. Those pin backlog item I2, which this phase does NOT fix. If they move, you have changed something beyond pension classification.
- [ ] **Step 5: Targeted runs, then the full suite once, then commit.**

---

