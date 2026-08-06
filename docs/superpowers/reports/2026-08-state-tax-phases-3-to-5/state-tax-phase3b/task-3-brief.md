### Task 3: The engine takes components, still inert

**Files:** create `RetirementDistributionComponent.swift`; modify `TaxCalculationEngine.swift`, `DataManager.swift`.

**Read the departure note above before starting.** You are ADDING a parameter, not replacing one.

- [ ] **Step 1: Write the failing tests.**
  - A single `unknown` component equals the scalar path exactly, for a grid of states and ages.
  - **The invariant**, per spec §3.4: components must agree with the scalar within one cent. `abs(total - scalar) <= 0.01`, never exact `Double` equality. In debug this is an `assertionFailure`; in release it falls back to the scalar path and sets an observable diagnostic flag, following `StateTaxDataLoader.legacyFallbackFired` from Phase 1. Test the debug trap and the release fallback separately.
  - **Do NOT write a test asserting that a spouse-owned component changes the age gate.** That would activate owner attribution, which this phase does not do. A capability test through `configOverride` with a synthetic `.perQualifyingSpouse` config is acceptable and inert, since no jurisdiction ships that mode, but it must be labelled as documenting capability rather than closing the Phase 3a approximation.

- [ ] **Step 2: Run, watch it fail, paste.**

- [ ] **Step 3: Implement.** Add `distributionComponents: [RetirementDistributionComponent]? = nil` to `calculateStateTax` and `applyRetirementExemptions`. When nil, synthesise `[RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: scenarioRetirementDistributions)]`.

- [ ] **Step 3a: Refactor the engine to iterate components, but change no rule.** Every component takes the same age gate and the same attribution the scalar takes today. The phrase "run per component" must not become "apply a cap per component": see Task 4 Step 4 and spec §3.4a. Task 3 pools the components and hands the pooled figure to the existing logic unchanged.

- [ ] **Step 4: Add the mirror's test seam and sync it.** Give `DataManager.stateTaxBreakdown(forState:filingStatus:)` a `configOverride: StateTaxConfig? = nil` parameter, defaulting to today's `StateTaxData.config(for:)` lookup. Phase 3a's Task 6 review named the absence of this seam as the reason the mirror's age-gate branch was proven by nothing while the engine's identical branch was proven by a test. Then apply the same per-component logic in the mirror.

- [ ] **Step 5: Run the grep and report it.**
```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && grep -n "distributionComponents\|RetirementDistributionComponent" RetireSmartIRA/DataManager.swift
```

- [ ] **Step 6: Targeted, then full suite once, then commit.** The baseline must hold all 1,020 values; this task is inert.

---

