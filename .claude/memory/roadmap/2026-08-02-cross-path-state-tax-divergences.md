# Cross-path state tax divergences, found 2026-08-02

Found while designing Phase 2's cross-path invariant, by reading the two call sites rather than
by running a test. Both are cases where the SAME household produces DIFFERENT state tax depending
on which screen the user is looking at.

Both paths delegate to the same `TaxCalculationEngine.calculateStateTax`. The divergence is
entirely in what each caller passes.

## Divergence 1: `postExemptionDeduction` dropped in multi-year (backlog I2, known)

- Single-year: `DataManager` passes it (5 call sites).
- Multi-year: `ProjectionEngine.computeStateTax` (:1622-1634) omits the argument, so it defaults to 0.
- Verified by absence: `postExemptionDeduction` appears ZERO times in `ProjectionEngine.swift`.

**Effect:** New Jersey's $1,000-per-filer personal exemptions apply in Scenarios and vanish in
Multi-Year. NJ is the only state using this field today, so NJ is the only state affected.

## Divergence 2: age-gating asymmetry (NEW, not previously recorded)

`TaxCalculationEngine.swift:582-585`:

```swift
let rmdSourceIncome = incomeSources.filter { $0.type == .rmd }...      // NOT age-gated
let retirementAge = primaryAge >= 59 || (enableSpouse && spouseAge >= 59)
let scenarioExemptable = retirementAge ? scenarioRetirementDistributions : 0   // gated at 59
let iraIncome = rmdSourceIncome + scenarioExemptable
```

- Multi-year (`ProjectionEngine.swift:1608-1612`) SYNTHESIZES `.rmd` IncomeSource rows from computed
  withdrawals. Those are ungated, so the IRA exemption applies at ANY age.
- Single-year passes the same money as `scenarioRetirementDistributions`, gated at 59.5.

**Effect: a 55-year-old with IRA withdrawals gets the state IRA exemption in Multi-Year and is
denied it in Scenarios.** Same inputs, two screens, different tax.

Affects every state with a non-`.none` `iraWithdrawalExemption`, which is most of them, for anyone
under 59.5. Early retirees converting before 59.5 are a core audience for this app.

**The in-code rationale does not cover the caller that relies on it.** The comment says user-entered
`.rmd` rows "implicitly represent retirement-age income". That is reasonable for rows a user typed
into the Scenarios UI. `ProjectionEngine` synthesizes them from computed withdrawals at whatever age
the projection has reached, so the assumption is false for the multi-year caller.

**Interaction with Iowa:** Iowa's real statute qualifies at 55, and the hardcoded 59.5 gate is wrong
for Iowa regardless. Once Iowa's config is corrected in Phase 5, multi-year would accidentally reach
the right answer via the ungated `.rmd` path while single-year denies it. Fixing the gate and fixing
Iowa must be reasoned about together.

## Consequence for the Phase 2 gate

The spec's Phase 2 gate said "harness runs green against the confirmed-correct jurisdictions
(PA, IL, MS, CA, NJ)". That conflates two different properties: those states' CONFIG VALUES are
correct, which is not the same as the two CODE PATHS agreeing. NJ is config-correct and will fail
the cross-path invariant immediately because of Divergence 1.

Corrected gate, matching Phase 4's shape: **the invariant's first run is a discovery exercise and
its failures are the deliverable.** A green first run would be the suspicious outcome, since two
divergences are already identifiable by inspection.

Known divergences get pinned as documented-expected failures until Phase 5 fixes them, so they are
visible rather than hidden, and so a NEW divergence appearing later is distinguishable from these.
