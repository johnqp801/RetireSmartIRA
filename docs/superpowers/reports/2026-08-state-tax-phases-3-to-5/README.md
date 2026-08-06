# Working papers: State Tax Phases 3 to 5

Preserved 2026-08-06, before thirteen merged worktrees were removed. These lived in
`.superpowers/sdd/`, which is GITIGNORED, so they would have been destroyed with the worktrees.
All thirteen branches were verified fully contained in `origin/main` before removal.

**These are working papers, not the record.** The durable record for these phases is in
`.claude/memory/roadmap/`: the Phase 1, 2, 3a, 3b, 4, 5a and 5b ledgers, the 51-jurisdiction audit,
and the full 50-state verification document.

## Layout

Four phase-level directories carry the substance:

- `state-tax-phase3a` (17) and `state-tax-phase3b` (13): the schema extensions and the per-source
  rule. Phase 3b is where `PerSourceExemptionRule` was designed with TWO deliberately separate axes
  so a plain "government pension" label could not hand New York's uncapped exclusion to a California
  public pension. Every later phase leans on that decision.
- `state-tax-phase4` (16): the golden-scenario catalogue. Every expected value derived from the
  jurisdiction's own published authority, with a reviewer independently opening the documents. This
  is where the 118 defects were pinned and where the "passing on wrong law" warnings for Arizona and
  Idaho were first written.
- `state-tax-phase5` (11): the first tax corrections in the program.

The nine single-file directories (`phase4-b5` to `b9`, `p5-t4` to `t7`) are per-task worktrees whose
briefs are one file each.

The `.diff` review packages were NOT copied; they are reproducible from git.
