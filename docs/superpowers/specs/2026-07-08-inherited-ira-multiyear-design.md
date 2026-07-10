# Inherited IRA distributions in the Multi-Year engine (design)

Date: 2026-07-08
Status: approved for implementation (autonomous session; scope specified by user)

## Problem

`MultiYearInputAdapter` rolls `.inheritedTraditionalIRA` into the owner traditional
buckets and `.inheritedRothIRA` into the Roth bucket. `ProjectionEngine` then applies
only the owner's uniform-table RMDs from the owner's RMD age. For a beneficiary
holding an inherited traditional IRA this misses the mandatory years-1-9 single-life
RMDs (decedent died on/after RBD) and the forced year-10 full drain, so multi-year
projections understate required taxable income, tax, and IRMAA exposure. The
single-year engine (`RMDCalculationEngine.calculateInheritedIRARMD`) already models
all of this correctly.

## Approaches considered

1. Reuse `RMDCalculationEngine.calculateInheritedIRARMD` per projection year with a
   running balance, via a new per-account inherited bucket in the engine (chosen).
   Single source of truth for the distribution rules; the multi-year schedule cannot
   drift from the single-year RMD calculator or the per-account view.
2. Precompute the full distribution schedule in the adapter and pass a year-to-amount
   table into the engine. Rejected: the schedule depends on the running balance
   (growth applied inside the engine), so amounts cannot be precomputed without
   duplicating the growth model.
3. Approximate with a synthetic "empty by year 10" straight-line drain. Rejected:
   loses beneficiary-type, RBD, and pre-SECURE distinctions the app already models
   and advertises in the single-year view.

## Design

### New value type: `InheritedAccountInput`

New file `RetireSmartIRA/InheritedAccountInput.swift`. `Equatable, Sendable`.
Carries exactly the fields `calculateInheritedIRARMD` needs: `balance`, `isRoth`,
`beneficiaryType`, `decedentRBDStatus?`, `yearOfInheritance`, `decedentBirthYear?`,
`beneficiaryBirthYear`, `minorChildMajorityYear?`.

- `init?(account: IRAAccount)` fails unless the account is inherited AND has the
  complete metadata (`beneficiaryType`, `yearOfInheritance`, `beneficiaryBirthYear`).
- `requiredDistribution(forYear:balance:)` builds an `IRAAccount` snapshot with the
  running balance and delegates to `RMDCalculationEngine.calculateInheritedIRARMD`,
  clamping to the balance. This is the only bridge to the rules engine.

### `MultiYearStaticInputs`

New field `inheritedAccounts: [InheritedAccountInput]` with `= []` init default and
threaded through `withClaimAge`. All existing call sites compile unchanged.

### `MultiYearInputAdapter`

Inherited accounts WITH complete metadata are excluded from the primary/spouse
traditional and Roth roll-ups and mapped to `inheritedAccounts`. Inherited accounts
with missing metadata keep the legacy roll-up (owner bucket, uniform-table RMD);
that preserves prior behavior instead of silently dropping the balance.

### `AccountSnapshot`

Two new fields with default 0 in both initializers: `inheritedTraditional`,
`inheritedRoth`. `total` includes them; `traditional` stays owner-only.
Display/terminal consumers that previously saw inherited balances inside the trad
and Roth buckets are updated to add the new fields so nothing visually disappears:
`BalancesChart`, `MultiYearCPABriefing`, `PlanComparison.endingTraditional/Roth`,
`HeirFrontierCoordinator` terminal sums.

### `ProjectionEngine`

Per-account running balances `inheritedBalances[i]` seeded from
`inputs.inheritedAccounts`. Within each projected year:

1. Forced distributions are computed from START-of-year balances (consistent with
   the Pub 590-B prior-year-end convention used for owner RMDs) and are never
   sources for Roth conversions, explicit withdrawals, or expense auto-funding.
   Lever actions cannot touch these buckets, so the optimizer's candidates always
   see forced inherited income as baseline income by construction.
2. `inheritedTradDistributions` (taxable) are added to `totalTradWithdrawals`, so
   AGI, SS taxability, state tax (retirement-income exemption bucketing), the
   gross-up fixed point, and MAGI all pick them up through existing code paths.
   They are also added to the reported `YearRecommendation.rmd` (they are required
   minimum distributions) and appended to `actions` as `.traditionalWithdrawal`.
3. `inheritedRothDistributions` (tax free) are spendable cash, appended to
   `actions` as `.rothWithdrawal`. No AGI/MAGI impact.
4. Both join the expense-funding waterfall the way owner RMD cash does; any excess
   above the year's expense need is deposited into the taxable bucket (already
   taxed cash, basis = balance), so a year-10 drain converts the account into
   taxable wealth instead of leaking out of the projection.
5. Remaining inherited balances grow at `assumptions.investmentGrowthRate` in the
   growth step and are reported in `endOfYearBalances.inheritedTraditional/.inheritedRoth`.

### `OptimizationEngine`

Terminal objective sums (`terminalLiquidationTax`, `computeObjectiveCost`,
`heirTerminalTax`) include `endOfYearBalances.inheritedTraditional`, matching the
pre-change behavior where inherited trad sat inside the owner buckets. Most
post-SECURE cases drain to zero well inside the horizon, so this only matters for
lifetime-stretch (EDB) cases.

## Documented simplifications (v2.x follow-ups)

- Only FORCED distributions are modeled. Voluntary early drawdown of an inherited
  account (often tax-smart to smooth the 10-year window) is not a lever yet.
- Spouse beneficiaries who would elect assume-as-own are modeled as inherited
  stretch; users who assumed ownership should enter the account as a regular IRA
  (matches single-year behavior).
- QCDs from inherited IRAs (allowed at 70.5+) are not modeled.
- `DrawdownProjectionEngine` (1.9 single-purpose drawdown calculator) is out of
  scope per the task definition; it still aggregates per-owner traditional totals.

## Tests (Swift Testing, new file `RetireSmartIRATests/InheritedIRAMultiYearTests.swift`)

1. Adapter: complete-metadata inherited trad/Roth accounts are excluded from owner
   buckets and mapped to `inheritedAccounts`; incomplete-metadata accounts keep the
   legacy roll-up.
2. Died-after-RBD, non-EDB: annual RMDs in years 1-9 raise AGI vs a no-inherited
   baseline; the deadline year forces the full drain (balance to 0, AGI spike);
   IRMAA cost two years after the drain reflects the spike via the MAGI lookback.
3. Died-before-RBD, non-EDB: zero forced income until the deadline year, then the
   full drain.
4. Inherited Roth, non-EDB: year-10 drain moves the balance to taxable with no AGI
   change.
5. AccountSnapshot: new fields default to 0 and flow into `total`.
