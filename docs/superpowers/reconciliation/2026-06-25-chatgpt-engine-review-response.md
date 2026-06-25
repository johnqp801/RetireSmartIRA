# ChatGPT Multi-Year Engine Review — Reconciliation & Response (2026-06-25)

External review of the V2.0 multi-year engine (ChatGPT, 24 findings). Each was reconciled
against the actual code per CLAUDE.md (cite file:line before agreeing/rejecting). Result:
**23 valid, 1 partially valid, 0 invalid.** The reviewer correctly diagnosed two real
correctness bugs and caught a config-provider inconsistency the Option C refactor had missed.

## Fixed now (committed on `2.0/reconcile-engine`)

| # | Finding | Fix | Commit |
|---|---|---|---|
| C2 | Roth conversion could consume the RMD balance | Reserve each spouse's required RMD (from start-of-year balance) before Step-1 conversions; conversions capped at `trad − RMD`. Regression test. | `43026d8` |
| C1 | IRMAA used same-year MAGI, not the 2-year lookback | Record every projected year's MAGI; charge year-Y premium from year Y−2 MAGI (fallback to current for first ≤2 yrs). A 63 conversion now raises the 65 premium. Regression test. | `43026d8` |
| H5 | Explicit taxable/Roth withdrawals deleted assets but discarded the cash | Track and credit that cash toward the expense shortfall. Regression test. | `43026d8` |
| M2 | Proportional withdrawal drained Roth when one bucket was short | Second pass over remaining taxable/traditional capacity before Roth. | `43026d8` |
| H1 | Federal brackets + ConstraintAcceptor bypassed `TaxYearConfigProvider` | `ProjectionEngine` federal brackets + `ConstraintAcceptor` ACA/bracket detection now resolve through the provider (closed the gap the Option C commit overclaimed as complete). | `43026d8` |
| M1 | `taxEfficient` == `preserveRoth` (dead behavior) | Documented as intentional v2.0 aliasing; true sequencing is the v2.1 withdrawal optimizer. | `898becf` |
| L2 | Silent fallback to California on bad state input | DEBUG assert so bad input surfaces in tests/dev (user-facing diagnostics = follow-up). | `898becf` |

Full suite green throughout: **1027 tests / 146 suites**, deterministic. 3 new regression tests
(`EngineCorrectnessFixTests.swift`).

## Deferred with rationale (valid, but not a quick fix)

| # | Finding | Why deferred / where it goes |
|---|---|---|
| C3 | Tax paid from "external" (invisible) funds | Needs a real `TaxPaymentSource` assumption + a diagnostics channel — a feature, not a guard. Already documented as a v2.0 limitation in `ProjectionEngine`. Roadmap. |
| C4 | Year-1 withdrawal/QCD inputs collected but ignored | The optimizer pins only Roth (documented in `OptimizationEngine`); the controls don't exist yet. Wire-or-hide belongs to the UI milestone; full support needs `LeverAction.qcd` + withdrawal pinning. |
| L4 | `TaxYearConfig` not `Sendable` | Mechanical but cascades across ~10 nested types in the **shipped** single-year engine. Defer to a focused commit (add `: Sendable` to the immutable config value types) rather than churn shipped code for a Low/latent finding. |

## Roadmap (valid capability gaps — competitiveness, not bugs)

These align with already-planned V2.0/2.1 work:
- **H6 / H7 / H8** — optimizer is Roth-only; terminal tax is a flat rate; inherited IRA collapsed into traditional. → the planned **heir-tax objective** + **2.1 decumulation** (withdrawal-order optimizer, taxable/LTCG, inherited-IRA buckets, objective selection).
- **H3** — spouse horizon (`horizonEndAgeSpouse`) stored but unused; optimizer uses primary only. → household horizon = max of both.
- **H4** — expenses flat nominal while SS is COLA'd. → inflate expenses by CPI (real/nominal flag).
- **H2** — base year hardcoded to `Date()`. → add `baseYear` to `MultiYearStaticInputs`; freeze in tests.
- **M3** — ACA uses national benchmark, not household-specific. → accept SLCSP/premium inputs.
- **M4** — standard-deduction-only. → itemized/charitable/QCD layer (interacts with C4).
- **M5** — SS couple math single-only (documented). → couple-aware in the projection.
- **M6** — stress test is growth ±2pp, not probabilistic. → relabel "growth sensitivity"; Monte Carlo later.
- **M7 / M8** — optimize ~7s × up to 4 calls; detached compute lacks in-loop cancellation. → release benchmarks + thread a cancellation check into the optimizer loops.
- **L1** — `ActionItemType` lacks `Codable` (Equatable is auto-synthesized; the review's "not Equatable" was the only partially-incorrect claim). → add `Codable` if persisted.
- **L3** — HSA/401k lever actions lack statutory limits (not optimizer-emitted today). → validate before exposing.
