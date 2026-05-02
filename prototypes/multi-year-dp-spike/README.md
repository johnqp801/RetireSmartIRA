# Multi-Year DP Perf Prototype

**Status:** Built but not yet measured. Run on M1 base to fill in the "Measured results" section below.

## What this is

Synthetic perf prototype that times the inner loop of full dynamic programming
over `(year x bracket x IRMAA x Roth balance bucket)` state space at realistic
size for the RetireSmartIRA 2.0 multi-year tax strategy engine. Per the spec
at `docs/superpowers/specs/2026-05-02-2.0-multi-year-tax-strategy-design.md`
section 3.3, the measured runtime determines whether the engine commits to:

- **<5 sec -- Scope E** (full DP, max optimization)
- **5-15 sec -- Scope C+D** (greedy + 2-year lookahead heuristic)
- **>15 sec -- Scope B** (pure greedy with constraint awareness)

The transitions are synthetic (action x 1000) -- real engine will compute actual
tax. Real tax computation is roughly 10x slower per transition (multiple
function calls vs one multiply), so multiply measured time by ~10 to estimate
real-engine wall clock.

## How to run

Build first (if not already built):

```bash
cd prototypes/multi-year-dp-spike
swift build -c release
```

Then run:

```bash
# Baseline (~25,200 states)
.build/release/DPSpike

# Stress variant (~100,800 states, 4x larger)
.build/release/DPSpike --stress
```

Capture wall-clock time using:

```bash
time .build/release/DPSpike
time .build/release/DPSpike --stress
```

## Measured results

**Hardware:** [Record exact: e.g., MacBook Air M1 (2020), 8GB RAM, Sonoma 14.x]
**Date:** [YYYY-MM-DD]

### Baseline (~25,200 states)
- Backward induction: ___ sec
- Wall clock end-to-end (`time` command): ___ sec

### Stress variant (~100,800 states)
- Backward induction: ___ sec
- Wall clock end-to-end: ___ sec

### Real-engine extrapolation (x10 for actual tax computation)
- Baseline: ___ sec
- Stress: ___ sec

## Decision (per spec section 3.3)

Per the spec's decision tree applied to the **real-engine extrapolation**:

- < 5 sec -- **Scope E** (full DP)
- 5-15 sec -- **Scope C+D** (lookahead-greedy)
- > 15 sec -- **Scope B** (pure greedy)

**Committed scope: [E / C+D / B] -- record after measurement.**

## Caveats

- Synthetic transition cost is a multiply; real engine has multiple function
  calls. Roughly x10 multiplier applied above is a rough heuristic, not a
  precise measurement.
- Decimal vs Double: this prototype uses Double matching the codebase
  convention (Task 0.2 finding). Decimal would be ~3-5x slower.
- M1 base extrapolation: if measured on different hardware, note the
  multiplier (e.g., M3 Pro is ~1.5-2x faster than M1 base).
