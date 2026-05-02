# Decision: Engine Scope Commitment — Scope E (full DP)

**Date:** 2026-05-02
**Driver:** Phase 0 perf prototype (Task 0.4) + analytical estimate
**Status:** Committed; will be revisited at Phase 1 Task 1.9 (engine implementation) for empirical validation.

## Context

Per spec [§3.3](../specs/2026-05-02-2.0-multi-year-tax-strategy-design.md), the multi-year engine's internal architecture is determined by Phase 0 perf measurement. The decision tree:

| Measured runtime | Commitment |
|---|---|
| <5 sec | **Scope E** — full dynamic programming |
| 5–15 sec | **Scope C+D** — greedy with 2-year lookahead heuristic |
| >15 sec | **Scope B** — pure greedy with constraint awareness |

## Measured perf (Phase 0 prototype, commit 08f54dc)

The synthetic prototype at `prototypes/multi-year-dp-spike/` was built and run on the user's M1 hardware. Results:

```
Total states: 25,200 (year × bracket × IRMAA × Roth balance bucket)
Total transitions per pass: ~252,000
DP backward induction: 0.000 sec (below printf precision)
Wall clock baseline: 0.302 sec (mostly process startup)
Wall clock stress (4× state size, 100,800 states): 0.008 sec
```

**Caveat — measurements are not representative.** The synthetic transition cost (`action × 1000`) is monotonically increasing in `action`, so the release-mode optimizer determined that `action = 0` always wins, set `dp[s] = 0`, and elided the inner loop entirely. The 0.302 / 0.008 numbers are dominated by process startup, not DP work.

The prototype confirmed only the structural feasibility (DP loops compile and run without crash). It did not produce a reliable per-transition cost number.

## Analytical estimate (the actual decision basis)

Given the prototype results don't tell us the per-transition cost, we estimate it from the existing 1.9 engine code:

**Per-transition cost in the real engine:**
- `TaxCalculationEngine.calculateFederalTax`: bracket search + marginal-income math ≈ **30–50 FP ops**
- `MedicareCostEngine.calculateIRMAA` (tier check): ~**10 ops**
- `ACASubsidyEngine` cliff math: ~**5 ops**
- 5 function-call overheads at ~5–10 ns each: ~**25–50 ns**
- **Estimated per-transition cost: ~100–200 ns**

**Total runtime at our state size (252K transitions, 1 backward-induction pass):**

| Margin | Estimated runtime |
|---|---|
| Optimistic (engineering estimate) | 25–50 ms |
| 10× pessimistic | 250–500 ms |
| 100× pessimistic | 2.5–5 sec |
| Spec threshold for Scope E | **<5 sec** |

Even at the 100× pessimistic bound, Scope E is feasible.

## Decision

**Committed: Scope E (full dynamic programming).**

## Implications for Task 1.9 (OptimizationEngine)

**State representation:** `dp[year][bracketBucket][irmaaTier][rothBalanceBucket]: Double`

**Discretization:**
- Year: 30 (horizon)
- Bracket bucket: 7 (2026 federal brackets — 10/12/22/24/32/35/37%)
- IRMAA tier: 6 (tier 0 + 5 tiers)
- Roth balance bucket: 20 (start: $0–$2M discretized log-uniformly)

**Algorithm:**
1. **Backward induction** from year `horizonEnd` to year 0
2. For each `(year, bracket, irmaa, roth)` state:
   - For each candidate `LeverAction` (Roth conversion amount, withdrawal, etc., discretized to 5–10 levels):
     - Project next-year state: compute year's tax via `TaxCalculationEngine`, update balances, advance bracket/IRMAA/Roth buckets
     - Cost = year's tax + `dp[year+1][nextState]`
   - Store minimum cost
3. **Forward path reconstruction:** from start state, follow argmin actions year-by-year

**Action set per state:** 5–10 candidate Roth conversion amounts (e.g., $0, $20K, $40K, fill-12%-bracket, fill-22%-bracket, fill-24%-bracket). Plus auto-determined withdrawals/contributions per the user's `withdrawalOrderingRule` (those don't add to action enumeration).

## Implications for stress tests

`StressTestRunner` runs 3 full optimizations (`avg`, `avg-2pp`, `avg+2pp`). At Scope E:
- 3 × ~50 ms (optimistic) = ~150 ms
- 3 × ~5 sec (100× pessimistic) = ~15 sec

`SSClaimNudge` runs 4 perturbations per spouse × 2 spouses = 8 extra optimizations. At Scope E:
- 8 × ~50 ms = ~400 ms (optimistic)
- 8 × ~5 sec = ~40 sec (100× pessimistic)

`WidowStressTest` runs 1 extra optimization with a different mortality. ~50 ms – 5 sec.

**Total `MultiYearTaxStrategyEngine.compute()` budget at Scope E:**
- Main + 3 stress + 1 widow + 8 SS-nudge = 13 optimizations
- Optimistic: ~650 ms
- 100× pessimistic: ~65 sec ← **THIS IS A PROBLEM**

If real-world per-transition cost lands at the 100× pessimistic bound, the SS-nudge alone busts the user-facing perf budget (engine should produce a recommendation in <2 sec per spec §9). Mitigation:

1. **Cache.** SS-nudge perturbations only differ in claim age; most state transitions are identical. Memoize at the year level.
2. **Skip SS-nudge unless asked.** Make it lazy / on-demand rather than computed proactively.
3. **Lower SS-nudge perturbation count.** ±2yr only (2 perturbations) instead of ±1, ±2 (4).

These are all viable mitigations. We'll choose at Task 1.9 based on actual measured cost.

## Revisit triggers

- **Task 1.9 implementation reveals scope is wrong choice** → revisit before merging Phase 1. If real per-transition cost exceeds 200 ns, downgrade to Scope C+D.
- **Phase 1 perf benchmark fails the <2 sec budget on M1 base.** Apply mitigations above; if insufficient, downgrade.
- **2.1 release**: revisit if user feedback indicates optimization gaps (e.g., obvious better paths found by hand that the engine missed).

## Risk acknowledgement

The decision is based on analytical estimate, not direct measurement. Risk:
- The estimate is off by more than 100× — extremely unlikely given how mature 1.9 engine code is
- A real bottleneck (memory allocation, Decimal-to-Double bridging, Swift overhead we haven't accounted for) materializes at scale — possible, mitigated by Phase 1 perf gate

If the gate fails, the fallback path (Scope C+D) is well-defined in the spec. No architectural commitment is locked in until Phase 1 ships.
