# 2026-08-05: State Tax Phase 5b completed, Tasks 2 through 10

**Branch `feature/state-tax-phase5b` @ `b414022`, PUSHED (verified against `origin`), NOT merged.**
`origin/main` is at `0addbe7`. 40 commits ahead. Suite at close: **2,035 Swift Testing in 305 suites +
509 XCTest, 0 failures.**

This file is the session narrative. **The authoritative technical record is
`.claude/memory/roadmap/2026-08-04-state-tax-phase5b-ledger.md`**, with
`.claude/memory/roadmap/2026-08-05-state-tax-phase5b-RESUME-HERE.md` as the pickup point and the
decisions log carrying each call with its reasoning. The SDD progress ledger and all 23 task
briefs and reports live in `.superpowers/sdd/`, which is GITIGNORED and will not survive.

## What happened

Session opened at Task 2 (Task 1 was already complete) and closed the phase: Tasks 2, 3, 3b, 4, 5, 6,
7, 8, 9, 10, then a whole-branch review, its fix wave, and a targeted verification of the one
shipped-behaviour change to a previously-clean jurisdiction. Every task got an implementer pass and an
independent review pass; several needed two review rounds.

**Defect cases: 99 across 32 jurisdictions to 88 across 29.**

- **Rules shipped:** Kansas, Massachusetts, Arizona, DC. **Kansas is COMPLETE**, engine and app both,
  which closes the second half of the written promise to Steve Nicolai.
- **Deliberately shipped NOTHING, each by a reviewed decision:** Hawaii, North Carolina, Idaho,
  Vermont. Each keeps all its `knownDefect` blocks plus guard cases, a `knownButUnpinned` entry with a
  deletion guard, and a user-facing caption. **These are results, not a to-do list.**

## Decisions John made today

1. **Task 3 adds all three picker options at once** rather than one per task.
2. **Massachusetts ships** with a disclosed under-taxation gap.
3. **Option 2 for the unclassified-pension disclosure:** data-driven gate, per-jurisdiction sentence.
4. **The employee-contributory axis is a Phase 6 item** and now has an owner.
5. **Idaho's decline accepted**, ships no rule.
6. **Vermont HELD.** Ships no rule; the income-gated Act 71 shape is deferred to Phase 6.
7. **All user-facing copy approved:** four disclosure sentences, six captions, the DC survivor toggle,
   and Task 3's three picker labels.

## The five findings worth carrying forward

1. **The plan assumed Tasks 3 to 9 were config-shaped. They were not.** A controller audit before Task
   3 found `PlanClassificationChoice`, the enum driving the USER-FACING picker, is separate from
   `PlanSource` and had no option writing any of Task 1's three new cases. A correct Kansas rule would
   have turned every golden case green while a real KPERS holder got nothing. **This exact failure
   recurred at DC** (no affordance could set the survivor flag) and was caught before shipping.
2. **A capped per-source `treatment` caps PER ROW**, because it is evaluated inside the row loop.
   Design doc 3.4a calls it the phase's largest correctness risk and the codebase had shipped it once,
   in New York's $20,000 exclusion. Banned phase-wide, but **only by a test sweep**: `treatment` is
   still typed as the full `ExemptionLevel`.
3. **Two-surface divergence, found FIVE times.** The DataManager mirror, `MilitaryRetirementExemption`
   gating on income TYPE while rules gate on `planSource`, the multi-year adapter dropping the survivor
   flag, disclosure surfaces gating differently from rules, and finally New York (below). Any place a
   tax fact is computed twice is a candidate.
4. **Vermont is the phase's most important finding.** Task 1's extension dissolved exactly the source
   collision it was built for and Vermont is STILL unsatisfiable, because sources were never the
   binding constraint. Task 1 extended the WHO axis; Vermont's remainder is on HOW MUCH and WHEN.
5. **The whole-branch review earned its cost.** It found a Critical no per-task review could see: Task
   3 made "Military retired pay" selectable everywhere, New York's rule was never widened to name it,
   so a NY military retiree picking the row that correctly describes their pension fell from an
   uncapped exclusion to the capped $20,000 one. **The branch replaced a right-by-accident answer with
   a wrong one.** Fixed by widening NY's rule, mirrored into `configs2026Legacy` so the canary keeps
   its byte-identity gate instead of being excused from it.

## Method notes worth keeping

- **Measure, do not argue.** Hawaii, Idaho and Vermont each SHIPPED the tempting rule temporarily,
  measured that cases went green while the rule was demonstrably wrong, and reverted. A reviewer called
  that the strongest evidence in the report. **The green outcome was available and wrong** in all three.
- **A green suite is not the criterion.** Idaho's review found a partial correction that WAS available
  and had been declined without evaluation; the decline survived, but on different reasons.
- **Coverage written to the implementation's shape is worse than no coverage.** Seven tests covered the
  unclassified-pension disclosure and all seven passed while Kansas got no warning, because each
  asserted only "NY fires, CA does not."
- **Records outlive their truth.** Repeatedly, doc comments and catalogue entries asserted things that
  had become false and a future task would have acted on them. Idaho's entry claimed a decline was
  "procedurally foreclosed" when it was a judgement call.
- **Subagents caught controller errors seventeen-plus times**, including my August 1989 Bailey cutoff
  (it is 1984) and a "$2,200 a year" figure that did not reproduce (it is $1,563.00 at the shape named).
  Both had already been repeated to John before correction. **"Verify before you comply" in every
  dispatch is what surfaced these.**
- **The shell's working directory silently reset to a different worktree on a different branch twice.**
  Absolute paths and `git -C` everywhere, always.

## Open

**Nothing awaits John.** Phase 6's charter is real and organised by missing model field in the ledger:
the contributory axis, `ownStateOrLocal` residence staleness, the disclosure surfaces that gate on
shipping rules so silent jurisdictions stay silent, and the structural fix for capped treatments.

**Vermont holds the largest unclaimed win, $5,211.50 a year**, blocked on one narrow question: which
income basis an exclusion threshold compares against. **VT-7 is specified and ready: AGI $130,000,
expected $172.53.** Write it first if that is ever settled.

Merge decision for the branch is still open.
