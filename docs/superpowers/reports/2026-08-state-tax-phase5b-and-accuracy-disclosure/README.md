# Working papers: State Tax Phase 5b and the per-state accuracy disclosure

Preserved 2026-08-06, before the two worktrees were removed. These lived in `.superpowers/sdd/`,
which is GITIGNORED, so they would otherwise have been destroyed with the worktrees.

**These are working papers, not the record.** The record is:
- `.claude/memory/roadmap/2026-08-04-state-tax-phase5b-ledger.md` (what Phase 5b corrected, what it
  deliberately did not, and what the next phase inherits organised by missing model field)
- `.claude/memory/roadmap/2026-08-06-accuracy-disclosure-RESUME-HERE.md`
- `.claude/memory/decisions/log.md`
- `.claude/memory/sessions/2026-08-05-state-tax-phase5b-completed.md`

## What is here that is nowhere else

Each task has a brief (what the implementer was told) and a report (what it found). The reports carry
the detail the ledgers summarise: full derivations, the alternatives that were MEASURED and reverted,
and the exact failure output that became the next task's worklist.

Worth keeping specifically because **four jurisdictions deliberately ship no rule** and a future phase
will want to know why before reopening any of them:

- **Hawaii** (`task-5-report.md`): the declined rule was shipped, measured turning all three cases
  green while granting a full exclusion to every contributory defined-benefit pension, then reverted.
- **North Carolina** (`task-7-report.md`): same method; the population arithmetic behind the decision,
  and why the Bailey class closed in 1984 rather than 1989.
- **Idaho** (`task-8-report.md`): two tempting rules measured, plus the military-only partial shape a
  reviewer found had been declined WITHOUT evaluation, and the Social Security offset that made the
  decline survive anyway.
- **Vermont** (`task-9-report.md`): both candidate shapes measured and reverted, and the specification
  for VT-7 (AGI $130,000, expected $172.53), the fixture that would settle which income basis an
  exclusion threshold compares against.

The `.diff` review packages were NOT copied; they are reproducible from git.

Task numbering: Phase 5b ran Tasks 1 to 10 plus a 3b. The accuracy disclosure ran Tasks 1 to 8 plus
the Roth conversion addition and the whole-branch fix waves.
