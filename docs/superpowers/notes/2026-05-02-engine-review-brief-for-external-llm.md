# Engine Review Brief — for external LLM (Gemini, ChatGPT, etc.)

**For the reviewer:** You are evaluating the V2.0 multi-year tax strategy engine for RetireSmartIRA — a native macOS / iPadOS / iPhone retirement-tax-planning app. The engine is pure-calculation Swift code (no UI), recently completed. We want a fresh-eyes review of correctness, edge cases, and architectural choices.

---

## What the engine does

Given a retiree's static financial scenario (account balances, ages, income sources, filing status, state) plus a small set of assumptions (CPI rate, investment growth rate, horizon end age, withdrawal-ordering preference), the engine produces a 30-year (or whatever horizon) recommendation:

- **Recommended path:** one `YearRecommendation` per year, with AGI, taxes, account balances, recommended actions (Roth conversions, withdrawals, contributions)
- **Trade-offs accepted:** soft-constraint hits (IRMAA tier crossings, ACA cliff trips, bracket overruns) the optimizer accepted because lifetime savings exceeded the cost
- **Sensitivity bands:** three full paths at growth rate `avg`, `avg-2pp`, `avg+2pp`
- **Widow stress delta:** lifetime-tax delta if higher-earning spouse dies (conservative single-filer-from-day-1 estimate for v2.0)
- **SS claim-age nudge:** flag if delaying / accelerating SS claim by 1–2 years saves >$5K lifetime

## Public API

```swift
let result = MultiYearTaxStrategyEngine().compute(
    inputs: MultiYearStaticInputs,
    assumptions: MultiYearAssumptions
) -> MultiYearStrategyResult
```

The engine is internal-access throughout; no `public` modifier (matches the 1.9 codebase convention).

## Architecture (Scope C+D — greedy year-by-year with full-horizon lookahead)

7 main components:

1. **`MultiYearStaticInputs`** — value-type snapshot of the scenario (built by `MultiYearInputAdapter` from runtime `DataManager` + `ScenarioStateManager` ObservableObject state, but the engine doesn't see those — pure value-type input)
2. **`MultiYearAssumptions`** — engine inputs (CPI, growth, horizon, withdrawal rule, taxable+HSA balances, stress toggle)
3. **`ProjectionEngine`** — pure year-by-year forward simulation. Takes static inputs + per-year `[LeverAction]`s, returns `[YearRecommendation]`. Order of operations per year: explicit actions → SS income → RMD auto-impose → expense auto-fund → growth → tax. Calls existing 1.9 engines (`TaxCalculationEngine`, `ACASubsidyEngine`, `MedicareCostEngine`, `SSCalculationEngine`, `RMDCalculationEngine`).
4. **`ConstraintAcceptor`** — detects IRMAA tier hits, ACA cliff trips, bracket overruns from a candidate path
5. **`OptimizationEngine`** — the actual optimizer. For each year, evaluates 7 candidate Roth conversion amounts `[0, 25K, 50K, 75K, 100K, 150K, 200K]` via full-horizon lookahead; locks in the candidate with lowest lifetime tax; advances. After all years, computes acceptance rationale (savings vs cost) for each constraint hit.
6. **`StressTestRunner` / `WidowStressTest` / `SSClaimNudge`** — wrappers running OptimizationEngine with perturbed inputs
7. **`MultiYearTaxStrategyEngine`** — top-level coordinator that wires the above into `MultiYearStrategyResult`

## Key files (read in this order)

### Spec + corrections + decisions
1. `docs/superpowers/specs/2026-05-02-2.0-multi-year-tax-strategy-design.md` — original spec
2. `docs/superpowers/plans/2026-05-02-2.0-multi-year-tax-strategy-engine-corrections.md` — Phase 0 corrections to the spec
3. `docs/superpowers/decisions/2026-05-02-engine-scope-commit.md` — architecture decision record (in 2.0 worktree)
4. `docs/superpowers/notes/2026-05-02-ss-module-audit.md` — SS engine audit (in 2.0 worktree)

### Engine types
5. `RetireSmartIRA/MultiYearStaticInputs.swift` — input snapshot type
6. `RetireSmartIRA/MultiYearAssumptions.swift` — assumption inputs
7. `RetireSmartIRA/AccountSnapshot.swift` — 4-bucket account model
8. `RetireSmartIRA/MultiYearTypes.swift` — `WithdrawalOrderingRule`, `LeverAction`, `ConstraintType`
9. `RetireSmartIRA/MultiYearValueTypes.swift` — `TaxBreakdown`, `ConstraintHit`, `TaxImpact`, `ClaimAgeFlag`, `SensitivityBands`
10. `RetireSmartIRA/YearRecommendation.swift` — per-year output
11. `RetireSmartIRA/MultiYearStrategyResult.swift` — top-level output
12. `RetireSmartIRA/SpouseID.swift` — small enum

### Engine implementations
13. `RetireSmartIRA/MultiYearInputAdapter.swift` — runtime → snapshot bridge
14. `RetireSmartIRA/ProjectionEngine.swift` — year-by-year simulation (522 lines, the most-substantial engine)
15. `RetireSmartIRA/ConstraintAcceptor.swift` — constraint detection
16. `RetireSmartIRA/OptimizationEngine.swift` — the optimizer (222 lines)
17. `RetireSmartIRA/StressTestRunner.swift`, `WidowStressTest.swift`, `SSClaimNudge.swift`
18. `RetireSmartIRA/MultiYearTaxStrategyEngine.swift` — top-level coordinator

### Pre-existing 1.9 engines (called by ProjectionEngine; assume correct, but worth understanding their interfaces)
19. `RetireSmartIRA/TaxCalculationEngine.swift` — federal tax, state tax, IRMAA, taxable SS portion
20. `RetireSmartIRA/ACASubsidyEngine.swift` — ACA premium subsidy
21. `RetireSmartIRA/MedicareCostEngine.swift` — Medicare premium math
22. `RetireSmartIRA/SSCalculationEngine.swift` — Social Security benefit calculation
23. `RetireSmartIRA/RMDCalculationEngine.swift` — Required Minimum Distribution lookup
24. `RetireSmartIRA/IncomeModels.swift` — IncomeType + IncomeSource (note: `.vaDisability` was just added)

### Tests (read for sample input/output behavior)
25. `RetireSmartIRATests/MultiYearReferenceScenariosTests.swift` — 8 hand-validated scenarios
26. `RetireSmartIRATests/ProjectionEngineTests.swift` — 22 year-simulation tests
27. `RetireSmartIRATests/OptimizationEngineTests.swift` — 9 optimizer tests
28. Other `MultiYear*Tests.swift` files

## Known v2.0 limitations (DO NOT flag these as bugs)

These are documented design decisions for v2.0; v2.1 will address them:

1. **Scope C+D, not full DP.** Phase 0 originally committed to Scope E (full dynamic programming) but Task 1.9 implementation revealed that bucketed-state DP introduces representative-state approximations. C+D uses ProjectionEngine + ConstraintAcceptor at full fidelity — ~80% of optimal per published research, but with no approximation in the cost calculations. Scope E is a v2.1 enhancement target.

2. **IRMAA cost is per-person.** For MFJ couples both on Medicare, the household pays 2× this. Uniformly under-stated across all paths so relative ranking is preserved. v2.1 will track per-spouse Medicare enrollment age.

3. **SSClaimNudge uses single-spouse SS calc.** Couples-aware `effectiveMonthlyBenefit` (with spousal top-up rule) is deferred. Asymmetric-PIA couples may see slightly under-counted nudges.

4. **WidowStressTest applies single-filer rates from year 0.** Conservative upper-bound estimate. Year-of-death modeling deferred to v2.1.

5. **Inherited IRA balances collapsed into the trad bucket.** No SECURE-act 10-year-drain enforcement.

6. **Excess RMD deposited pre-tax to taxable.** Slight wealth overstatement (effective-rate × small residual); minor distortion.

7. **Income-type exclusions use blocklist filters.** Every new tax-exempt income type needs to be added to ~3 sites. v2.1 will refactor to allowlist computed properties on `IncomeType`.

8. **Acceptance rationale uses global lifetime savings.** When multiple constraint hits occur, all are tested against the same aggregate savings rather than per-hit attribution. Acceptable for v2.0 (most paths return 0–1 hits with the current heuristic); v2.1 will refine if RMDs generate paths with multiple simultaneous hits.

## What we want from the review

Five questions, ranked:

1. **Are there correctness bugs we missed?** Particularly in tax math (provisional income, MAGI add-backs, bracket boundaries, RMD computation), in the optimizer's lookahead logic, or in the constraint detection.

2. **Are there edge cases the tests don't cover?** Specifically: scenarios where the engine produces nonsensical output, crashes, or returns a path that violates internal invariants (e.g., `taxableIncome > AGI`, `endOfYearBalance < 0`).

3. **Is the C+D heuristic obviously suboptimal?** Are there scenarios where a hand-computed multi-year strategy clearly beats what the optimizer would find? (The 7 candidate amounts are fixed; we acknowledge this as a v2.0 simplification.)

4. **Are any of the documented v2.0 simplifications more painful than they appear?** I.e., would real users hit them as visible bugs in common scenarios, not as edge cases?

5. **Is the architecture sound for v2.1+ extension?** Particularly: adding new income types, refining widow modeling, switching to full DP, adding per-spouse trad-balance tracking.

## Suggested review process

1. **Skim the spec + corrections** to understand the design.
2. **Read the public API + main engine file** (`ProjectionEngine.swift` is the biggest).
3. **Read 2-3 reference scenarios** to see how the engine is exercised end-to-end.
4. **Probe with edge cases.** Suggest scenarios you'd like to see the engine run; we can execute them as test cases and share the output.
5. **Critique the v2.0 simplifications.** Are any of them wrong-headed for shipping?
6. **Suggest priorities for v2.1.**

## How to execute scenarios

The engine is part of a Swift / Xcode project. To run a specific scenario, suggest a `MultiYearStaticInputs` + `MultiYearAssumptions` configuration as Swift code, and the maintainer will add it as a Swift Testing test case, run `xcodebuild test`, and share the resulting `MultiYearStrategyResult` JSON.
