# 2026-07-08: Inherited-IRA distribution rules in the Multi-Year engine

Branch: `claude/inspiring-driscoll-7a338f` (worktree elated-goldstine-1306c1, off main)

## What was done

Fixed the verified modeling limitation found during the inherited-IRA article
hardening: the multi-year engine rolled inherited accounts into the owner
buckets and applied only uniform-table owner RMDs, understating forced taxable
income, tax, and IRMAA across the horizon.

- New `InheritedAccountInput` value type bridges the multi-year engine to
  `RMDCalculationEngine.calculateInheritedIRARMD` (single source of truth for
  beneficiary rules: single-life RMDs when decedent died on/after RBD, forced
  full drain by year 10 for non-EDBs, tax-free drain for inherited Roth,
  pre-SECURE stretch, minor-child majority shift).
- `MultiYearInputAdapter` routes metadata-complete inherited accounts to their
  own buckets; metadata-incomplete ones keep the legacy owner roll-up so no
  balance is dropped.
- `ProjectionEngine`: forced distributions compute from start-of-year balances,
  join AGI/state-tax/SS-taxability/gross-up via totalTradWithdrawals (trad) or
  act as tax-free cash (Roth), fund expenses first, and excess deposits to
  taxable. Conversions and auto-funding can never touch inherited buckets, so
  optimizer candidates see forced income as baseline by construction.
- `AccountSnapshot` gained `inheritedTraditional` / `inheritedRoth` (defaults 0,
  included in `total`). Terminal objective (OptimizationEngine x3) and display
  consumers (BalancesChart, CPA briefing, PlanComparison, HeirFrontierCoordinator)
  include the new buckets. WidowStressTest carries inheritedAccounts through.
- Design doc: `docs/superpowers/specs/2026-07-08-inherited-ira-multiyear-design.md`.
- 8 new Swift Testing regression tests in
  `RetireSmartIRATests/InheritedIRAMultiYearTests.swift`. Full suite: 1211 green.

## Documented simplifications (2.x follow-ups)

- Forced distributions only; voluntary early drawdown of an inherited account
  (10-year smoothing) is not an optimizer lever yet.
- Spouse assume-as-own is modeled as inherited stretch; assume-as-own users
  should enter a regular IRA (matches single-year behavior).
- QCDs from inherited IRAs (70.5+) not modeled.
- `DrawdownProjectionEngine` (1.9 drawdown calculator) unchanged, per scope.

## Spun-off task

- WidowStressTest.makeWidowVariant drops `taxableAccounts` and heir fields when
  rebuilding survivor inputs (pre-existing gap, chip spawned for a separate
  session).

## Next steps

- Merge branch to main after review.
- Website CTA can claim multi-year inherited modeling only after this ships.
- Consider a UI surface for the inherited buckets (year list shows the forced
  income inside RMD; balances chart folds inherited into trad/Roth series).
