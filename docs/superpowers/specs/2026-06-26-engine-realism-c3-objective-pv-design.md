# Engine Realism Batch — Tax-Payment Source (C3) + PV-Discounted Objective Design Spec

**Date:** 2026-06-26
**Status:** Approved design, pending implementation plan
**Branch (work):** `2.0/heir-objective` (off `2.0/reconcile-engine`)
**Motivation:** `sessions/2026-06-26-multi-year-tab-mvp-and-engine-realism-finding.md` — the running Multi-Year Plan tab proved the optimizer drains the entire traditional balance (terminalTrad=0 at every heir weight), producing non-credible recommendations (AGI $401k/yr, IRMAA ignored) and a flat heir frontier. Root causes are these two deferred items; this batch fixes both so the tab's recommendations become credible and the frontier opens into a real trade-off.

---

## 1. Purpose & scope

Two related changes that both curb over-conversion, run as one batch with a shared, attribution-based test re-baseline (conversion goldens WILL move — that is the point):

1. **C3 — tax-payment source with a liquidity brake (gross-up model).** Conversion/year tax is no longer silently paid from invisible "external" funds.
2. **Objective-PV — discount tax to present value inside the optimizer objective** (not just the display toggle), so distant terminal tax on growth-compounded balances stops dominating near-term conversion tax.

**Out of scope:** brokerage cost-basis / gain-harvesting, NIIT, withdrawal-order optimization, full HSA accounts (the rest of 2.1 decumulation); UI changes (the tab already renders whatever the engine returns).

**Sequencing:** C3 first (concrete liquidity brake), then objective-PV (pervasive, re-baselines more). One shared re-baseline ledger.

---

## 2. C3 — tax-payment source (gross-up)

### Today (the bug)
`ProjectionEngine` Step 7 does `taxDebit = min(taxable, yearTaxBurden); taxable -= taxDebit`. Any tax beyond the taxable bucket is implicitly free ("external"). So a conversion has no cost beyond its own headline tax, even at $0 taxable — the optimizer over-converts without limit.

### Design
Add a `TaxPaymentSource` assumption and a realistic gross-up:

```swift
enum TaxPaymentSource: String, Codable, Sendable {
    case taxableThenGrossUp   // DEFAULT: pay from taxable; shortfall pulled from traditional (taxed)
    case external             // legacy behavior (tax assumed paid from outside funds) — for tests/back-compat
}
```
Add `var taxPaymentSource: TaxPaymentSource = .taxableThenGrossUp` to `MultiYearAssumptions` (Codable `decodeIfPresent` default).

**`.taxableThenGrossUp` mechanic** (in `ProjectionEngine`, replacing Step 7's debit):
1. Pay the year's tax from `taxable` first.
2. If `taxable` is exhausted and tax remains, pay the **remaining tax by an additional traditional withdrawal**, grossed up for the tax that withdrawal itself creates. Because withdrawing $W to pay $S of tax adds $W to AGI (more tax), solve the gross-up with a **bounded fixed-point** (cap 3 iterations): each pass, recompute the year's federal+state tax including the extra withdrawal, take the new shortfall, withdraw it from `primaryTrad`/`spouseTrad` (older-spouse-first), repeat until the shortfall converges (< $1) or the cap/`trad` balance is hit.
3. If traditional is also exhausted (genuinely insolvent), debit what's available and record an `underfunded` amount on the `YearRecommendation` (a new optional field, default nil) so the UI/optimizer can see it. (No silent "external" funding.)

**Why this brakes over-conversion:** paying conversion tax from the IRA is strictly worse (the spiral), so a conversion that outruns taxable liquidity now carries its true cost in the objective — the optimizer backs off on its own, no arbitrary penalty factor needed.

**`.external`** preserves today's `min(taxable, tax)` behavior; used by any test that must hold the old numbers and as a documented escape hatch.

### Interaction notes
- The additional gross-up withdrawal counts toward RMD satisfaction (it is a real distribution) and adds to AGI/MAGI like any trad withdrawal.
- Cliff candidates / optimizer need not change for C3 — the brake emerges through the objective (the extra tax makes over-large conversions score worse). The candidate set may still propose large conversions; they just stop winning.

---

## 3. Objective-PV — discount in the optimizer objective

### Today (the bug)
`OptimizationEngine` minimizes `inHorizonTax + blendedTerminalTax` in **nominal, undiscounted** dollars, while the terminal traditional balance compounds at `investmentGrowthRate`. So converting now at the top bracket beats leaving a balance that grows for N years and is taxed later — driving the AGI-$401k-every-year plans.

### Design
Discount every tax dollar to the base year inside the objective, using the existing `assumptions.pvRealDiscountRate` (3% real; already present, currently display-only):

- **In-horizon:** each year Y's `taxBreakdown.total` is discounted by `(1 + r)^-(Y - baseYear)` before summing.
- **Terminal:** the blended terminal tax (self-liquidation + heir bomb) is discounted by `(1 + r)^-(horizonYears)` (it occurs at the end of the horizon).

Implement as a small pure helper so it is unit-testable and used everywhere the objective is computed:

```swift
static func presentValue(_ amount: Double, yearsFromBase: Int, realDiscountRate r: Double) -> Double {
    amount / pow(1 + r, Double(yearsFromBase))
}
```

Thread `pvRealDiscountRate` + `baseYear` into: the inner candidate-loop objective, the static `computeObjectiveCost(...)` (add a discount-rate parameter; wrappers pass `assumptions.pvRealDiscountRate`), and `blendedTerminalTax` discounting. The heir blend math is unchanged — only each term is discounted before blending/summing.

### Display-toggle interaction
The frontier's today's-$ / PV display toggle stays as-is (it re-expresses the *reported* owner/heir figures). Now the *optimizer* also discounts, so the recommended plan itself is less aggressive — the display toggle and the objective use the same rate, which is coherent (no double-discounting: the toggle scales today's-dollar reported figures for display; the objective discounts to choose the plan).

---

## 4. Test re-baseline (attribution-based, shared ledger)

Both changes move conversion amounts and objective costs. Re-baseline with the three-bucket discipline (as in the reconciliation):
- **Bucket A — should NOT move:** structural/property tests (monotonicity endpoints, λ=0 reproduces-legacy *under the new objective*, blend composition, formatting). Fix the source if these break.
- **Bucket B — expected to move:** any test asserting a specific conversion amount, terminal balance, or objective cost. Attribute each to C3 (liquidity) or PV (discounting), update, record in `docs/superpowers/reconciliation/2026-06-26-realism-delta-ledger.md`.
- **Bucket C — investigate.**

> Note the `λ=0 reproduces today's objective` test (`HeirObjectiveTests.lambdaZeroMatchesLegacy`) compares two *optimize* calls — both shift identically under the new objective, so it should still hold (it asserts equality between two runs, not a fixed number). Verify.

Add new tests: C3 gross-up (a conversion whose tax exceeds taxable forces an extra trad withdrawal and a smaller net Roth gain; `.external` preserves old behavior); PV helper (discount math); and a **regression for the finding** — a screenshot-like scenario (large trad, 6% growth, long horizon) now leaves `terminalTrad > 0` at λ=0 and the frontier owner/heir spread widens materially across weights.

---

## 5. Definition of done

- `.taxableThenGrossUp` is the default; conversions are liquidity-braked (an extra trad withdrawal funds unaffordable tax; genuinely insolvent years record `underfunded`, never silent external).
- The optimizer objective discounts in-horizon + terminal tax at `pvRealDiscountRate`.
- The screenshot regression scenario no longer drains the trad to zero and the heir frontier shows a material owner-vs-heir spread.
- Full suite green with every moved assertion attributed in the delta ledger; no assertion weakened to pass.
- Re-run the Multi-Year Plan tab: recommendations are credible (conversions respect liquidity + don't blow every IRMAA tier) and the frontier opens into a real trade-off.

---

## 6. Risks

- **R1 — gross-up non-convergence / runaway:** bound the fixed-point (≤3 iterations) and cap withdrawals at the `trad` balance; record `underfunded` rather than loop.
- **R2 — double-discounting in the display toggle:** the toggle scales *reported today's-dollar* figures; the objective discounts to *choose*. Keep the reported figures in today's dollars; only the objective and the toggle apply the rate, never both to the same number.
- **R3 — broad re-baseline hides a regression:** the §4 Bucket-A guard tests (structure/monotonicity) must stay green un-edited; only Bucket-B golden numbers move, each attributed.
