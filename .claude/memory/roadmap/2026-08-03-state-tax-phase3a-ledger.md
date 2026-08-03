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
