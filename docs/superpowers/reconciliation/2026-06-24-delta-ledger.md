# V2.0 Reconciliation Delta Ledger (2026-06-24)

Every multi-year test value that changed during reconciliation, with the engine change
that explains it. This is the published validation basis for the 2027 subscription. A value
with no attribution is NOT re-baselined — it is investigated as a possible regression.

Branch: `2.0/reconcile-engine` (off `main`). Spec: `docs/superpowers/specs/2026-06-24-v2.0-multi-year-engine-reconciliation-design.md`.

## Engine-core compile fixes (Task 2 — pre-re-baseline)
| File | Change | Reason |
|---|---|---|
| MultiYearInputAdapter.swift | `IncomeType.militaryRetirement` → ordinary-income bucket (was dropped) | main added the case; the "already extracted" classification was untrue, silently dropping the income. Taxed as ordinary; state pension-exemption deferred to v2.1. |
| MultiYearStrategyManager.swift | Replace `withObservationTracking` busy-loop with self-re-arming pattern | main migrated DataManager/ScenarioStateManager to the `@Observable` macro; the ported Combine subscription broke. Busy-loop fix spun CPU + lost debounce. Full live-field reactivity is a UI-milestone item. |

## Architecture change — per-year config provider (Option C, approved by John)
**Root issue found during re-baseline:** the ported multi-year engine read the process-global
`TaxCalculationEngine.config` static (single-year, set once at startup). That made the engine's
results depend on global state, so a TEST-ONLY `withConfig(forYear:)` swap in another test bled
into the optimizer under parallel execution — producing flaky, message-less collateral failures.
A global single-year config is also the wrong shape for a multi-year engine.

**Fix:** introduced `TaxYearConfigProvider` (`(Int) -> TaxYearConfig`) and threaded it through the
entire multi-year engine — `MultiYearTaxStrategyEngine.compute` → `OptimizationEngine.optimize`/
`cliffCandidates`, `ProjectionEngine.project` (resolves per projection year), `StressTestRunner`,
`WidowStressTest`, `SSClaimNudge`, `MultiYearStrategyManager`. Every entry point defaults to
`.current` (returns the active global config for all years), so **production behavior is byte-
identical**; tests inject `.fixed(config)` for determinism; `.bundled` is the future seam for
genuine per-year tax law / inflation indexing. Touches only the new (ported) engine — the shipped
single-year engine still uses the static unchanged. Also added a `deinit` to
`MultiYearStrategyManager` that cancels its observation/debounce Tasks (removes the leak that
amplified the parallel collateral).

## Pre-existing main hazard fixed — test parallelization disabled (approved by John)
After Option C, the multi-year engine no longer reads the global config static, eliminating
22 of the original 23 parallel failures. One residual flake remained — `FederalBracketInfoTests`
(a main test) racing `TaxsimOracleTests`, which swaps the global `TaxCalculationEngine.config`
to TY2023 via the TEST-ONLY `withConfig(forYear:)` to match TAXSIM-35's year cap (its DataManager
reads the global). Main's own devs documented this hazard (`RetireSmartIRATests.swift:15`).

**Fix:** set `parallelizable = "NO"` on the test target in `RetireSmartIRA.xcscheme`, with an
explanatory comment on the `TaxsimOracleTests` suite. Rationale: the config singleton is
intentional production architecture (set once at startup, never swapped in prod), so the correct
response to a global a test must swap is serial test execution — **zero production impact, no
locking added to the shipped engine hot path** (vs. a live App Store app). Serial is fast here
(~12.5s for 1024 tests; the heavy optimizer tests dominate, so parallelism barely helped). The
forward path to true parallel-safety is config injection (TaxYearConfigProvider), already done
for the multi-year engine.

Result: default `xcodebuild test` (scheme) now passes 1024 tests / 145 suites, deterministically.

## Diagnosis: the "23 parallel failures" were not real
| Run | Result |
|---|---|
| Parallel (pre-fix) | 23 "failures" — all on a single worker process, zero assertion text, all passing on main and in isolation → crash/contention collateral, not assertion failures |
| Serial (pre-fix) | exactly **1** real failure: `CliffCandidateGeneratorTests.acaCliffMFJHousehold2` (stale ACA FPL) |
| main baseline | green — confirms the failures were introduced by test-isolation fragility, not engine math |

## Parked tests (deferred to the UI milestone — could not compile without a deferred view/persistence surface)
| Test | Missing surface |
|---|---|
| PlanBPersistenceTests | `DataManager.multiYearAssumptions` (not-yet-ported persistence property) |
| MigrationFlowTests | `ContentView.detectSetupComplete` (not-yet-ported migration method) |
| FullFlowIntegrationTest | `OffPlanIndicator` (deferred view) |

## Bucket A — real bugs found + fixed (test value should NOT have moved)
| Test | Symptom | Root cause | Fix |
|---|---|---|---|

## Bucket B — re-baselined (attributed to a known engine improvement)
| Test | Old value | New value | Attributed engine change |
|---|---|---|---|
| CliffCandidateGeneratorTests.acaCliffMFJHousehold2 | candidate 31_560 (FPL HH2 21_640) | candidate 29_600 (FPL HH2 21_150) | main's 1.8.7 ACA FPL refresh (tax-2026.json HH2 = 21_150 vs the branch's stale 21_640). Test now derives expected from the injected config so it can't go stale again. |

## Bucket C — investigated (resolved into A or B)
| Test | Resolution |
|---|---|
