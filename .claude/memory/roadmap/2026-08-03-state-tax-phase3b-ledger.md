# State Tax Phase 3b: per-source exemptions — SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-03-state-tax-phase3b-per-source.md
Spec: docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
Worktree: .worktrees/state-tax-phase3b (branch feature/state-tax-phase3b), off main @ b138a62
Predecessor ledger: .claude/memory/roadmap/2026-08-03-state-tax-phase3a-ledger.md. READ IT.

## Baseline: NOT re-run, deliberately
b138a62 is the Phase 3a merge commit, whose gate verified 1,657 Swift Testing in 278 suites
+ 503 XCTest, 0 failures, iOS BUILD SUCCEEDED, all 51 JSON bundled. This branch is off that
exact commit with only doc files added, so re-running a five-minute suite to confirm what was
confirmed an hour earlier is the kind of waste the efficiency protocol exists to stop.

## Design decisions (John, 2026-08-03)
1. Classification lives on BOTH IncomeSource and Account, sharing one domain model.
2. TWO internal dimensions (PlanStructure x PlanSource), presented as ONE flat picker.
3. Infer what is knowable; prompt only for pensions, where government-vs-private cannot be inferred.
4. Mechanism PLUS the New York correction. New York is the only jurisdiction whose numbers move.
5. Hawaii disclosed, not modelled.
6. Multi-year: the PENSION input widens; AccountSnapshot does NOT.

## John's review caught three blockers in the first plan draft, all closed before execution
1. Task 3 activated owner attribution despite the New-York-only promise. Now inert; components
   carry owner for a LATER phase. Bundling source classification with owner correction would have
   destroyed the ability to prove New York's rule caused any movement.
2. THE MULTI-YEAR PATH WAS ABSENT. Investigation found it worse than he framed: ProjectionEngine
   receives scalars throughout (two pension numbers, a nine-field AccountSnapshot) and SYNTHESISES
   income rows from them, so NO classification of any kind reaches the projection. Left alone,
   Alan would see the uncapped exclusion on Scenarios and the capped one in Multi-Year: a second
   deliberate cross-path divergence. New Task 5 widens the pension inputs only.
3. Shared caps were not designed. Rule matching is now a PARTITION that runs BEFORE the existing
   cap machinery, never a per-component evaluation, with five derived tests. This codebase already
   shipped the per-component variant of that bug once, which is why pensionAndIRAShareSingleCap
   exists.

He also caught six smaller items: an invalid Task 2 mutation (deleting a non-optional decode
fallback is a compile error, which proves nothing), missing tolerance and debug-vs-release
semantics on the sum invariant, fixture determinism, vague CPA file paths, the New York limitation
needing to appear wherever NY tax is COMPUTED rather than only for residents, and two inaccurate
self-review claims. The second of those exposed a real gap: Task 1 had no typed decode error.

## The defect the design revision removed, worth remembering
The first design had ONE `.governmentPension` case. Offered under that plain-English label it
would have handed New York's uncapped IT-201 Line 26 exclusion to a California or Illinois public
pension held by a NY resident. Line 26 covers NYS, NY localities, named NY authorities and the US
government ONLY. The error direction is UNDER-taxation, and no planned fixture contained an
out-of-state public pension, so nothing would have caught it. Task 4 Step 1 case 4 is its
permanent regression test.

## CONTROLLER PROCESS NOTE
My Bash cwd resets to the MAIN repo between calls, and chained `cd X && ...` does not protect a
later separate call. This bit me four times in this session, once committing this very ledger to
the article branch (reset, single unpushed file, no damage). Use absolute paths for file writes
rather than relying on cwd.

## Tasks
(none complete yet)
