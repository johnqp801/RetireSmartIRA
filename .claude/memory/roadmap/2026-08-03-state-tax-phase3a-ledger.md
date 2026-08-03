# State Tax Phase 3a: Schema Extensions — SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-03-state-tax-phase3a-schema-extensions.md
Spec: docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md §3.3, §4a row 3
Audit: .claude/memory/roadmap/2026-08-02-full-50-state-verification.md
Worktree: .worktrees/state-tax-phase3a (branch feature/state-tax-phase3a), off LOCAL main @ e540e9f

Predecessors: Phase 1 ledger 2026-08-02-state-tax-phase1-ledger.md,
Phase 2 ledger 2026-08-02-state-tax-phase2-ledger.md. Both record how a test in
this area can look like verification and provide none. Carry those controls forward.

## Scope decision (John, 2026-08-03)
Spec Phase 3 SPLIT into 3a and 3b.
  3a (this plan) = personalExemption, AGI phase-out, per-qualifying-spouse attribution,
     state-aware distribution age, data-driven Roth conversion rule. Five defaulted
     fields on existing types, all behavior-inert.
  3b (separate plan) = per-source exemptions, shipping WITH its user-facing
     classification UI. Rationale: flipping nine states' data reaches neither Alan
     nor Steve until the app can tell a government pension from a private one, and
     a field with no UI repeats the dead-wiring pattern (year1PrimaryWithdrawal,
     perYearExpenseOverrides).

## Contract for every task
BEHAVIOR-INERT. No computed tax value changes, any state, scenario, filing status or age.
A moved number is a defect in the change that moved it, never a tax correction.
No state's tax PARAMETERS change: Iowa stays .none/.none, Kansas gains no exemption,
MI/CT/VA/AZ keep today's values. The only config values added reproduce behavior that
already exists in hardcoded form (NJ's personal exemption, PA/IL/MS's conversion rule).
I2 stays OPEN: ProjectionEngine untouched, GoldenScenarioCrossPathTests pins unchanged
(single-year 42.0, multi-year 200.40469973890345).

## Pre-flight
- CONTROLLER FOUND AND FIXED A PLAN DEFECT BEFORE DISPATCH: the plan's Task 8 (Layer C
  required-vs-optional keys) and Task 9 (regenerate the 51 JSON files) could not be
  separate commits. Layer C's new `onlyNewJerseyShipsAPersonalExemptionKey` is RED until
  the regeneration lands, and the pre-existing exact-13-key assertion goes red the moment
  the regeneration lands first. Either order commits a knowingly-red suite. Merged into
  one Task 8; the gate is now Task 9. Plan renumbered, cross-references fixed.
- WHY TASK 1 EXISTS (the structural point of this phase): the Phase 1 gate compares the
  JSON config against the legacy Swift config, and Phase 3a edits BOTH, so they move
  together and Layer A stays green even if every number in the app changes. The spec's
  stated Phase 3 gate is therefore blind to this phase's actual failure mode. Task 1
  freezes 51 jurisdictions x 17 scenarios captured from main BEFORE any model change.
  No later task may regenerate that fixture to make itself pass.

## Baseline (to be captured by Task 1, not taken on faith)
main @ e540e9f: 1,620 Swift Testing in 275 suites + 503 XCTest, 0 failures.

## Tasks
(none complete yet)
Task 1: commits 855b7c3 + fix 601a622 (base db0977e). Reviewed on opus, RE-REVIEW IN FLIGHT.
  Deliverable: StateTaxBehaviorBaselineTests + Baselines/statetax-behavior-baseline-2026.json.
  51 jurisdictions x 20 scenarios = 1,020 frozen values. No production code touched.
  Full suite 1,622 Swift Testing in 277 suites + 503 XCTest, correct tree.

  ** MY PLAN'S DEFECT, caught by the implementer, and it is a trap worth remembering:
     the brief's second mutation edited StateTaxData.swift's configs2026Legacy and did
     NOT discriminate. Since Phase 1 Task 11, StateTaxData.config(for:) reads the bundled
     JSON and falls back to the legacy Swift table ONLY when a file fails to load, so a
     legacy-table edit is invisible to production. It LOOKS like a discriminating mutation
     and proves nothing. Implementer reported the unexpected PASS instead of reconstructing
     a plausible failure. Corrected mutation (statetax-2026-NJ.json regularExemptionMinAge
     62 -> 65) discriminates: NJ fails "single 63 in the early age tier", 2485.5 vs 0.0.
     Plan amended @ d9070b3. **

  REVIEWER'S REAL CATCH (Important 2), and it is the same shape this program keeps hitting:
     the original 17-scenario grid had NO MFJ case where the household distribution gate
     `primaryAge >= 59 || (enableSpouse && spouseAge >= 59)` evaluates FALSE. Every MFJ
     scenario with nonzero distributions already had a spouse at 59+. Task 5 rewrites that
     exact expression; a default branch degrading to `primaryAge >= 59 || enableSpouse`
     would have moved NONE of the 867 values. CONFIRMED EMPIRICALLY by the fix: that
     mutation now fails 14 states, and in every one the ONLY failing scenario is the newly
     added "MFJ 56 with spouse 55". No pre-existing scenario caught it.

  Also fixed: size assertion (a later implementer could otherwise delete a red scenario
    instead of fixing their code, and the suite would go green with orphaned fixture
    entries); NJ single-filer coverage for stepped tiers 2 and 3 (singlePercent 0.375 and
    0.1875 previously multiplied nothing); a comment that named njPersonalExemptions as a
    guard when calculateStateTax never calls it (the real guard is
    NJOtherExclusionAndExemptionsTests, and Task 3 Step 8's claim needs the same correction).
  Minor not fixed: fileprivate on BaselineScenario cascades (the generator suite is a
    separate struct in the same file calling its internal members). Reverted, as instructed.
