# State Tax Phase 5a SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-04-state-tax-phase5a-data-corrections.md
Spec: docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md
Phase 4 ledger (READ IT, it is the input to this phase):
  .claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md
Worktree: .worktrees/state-tax-phase5 (branch feature/state-tax-phase5), off main @ 2b4f4c1

## Baseline
1,856 Swift Testing in 292 suites + 509 XCTest, 0 failures, 6 pre-existing env-gated skips.
Phase 4 closed with 118 defect cases across 35 jurisdictions. This phase reduces that number.

## Two recorded spec amendments govern this phase
1. Base values are corrected BEFORE the retirement tiers, because they hit every filer.
2. Phase 4's golden scenarios stand in for the two-model confirmation protocol. Claude cannot run
   that protocol (no GPT-5 or Gemini tools here) and same-model subagents would NOT satisfy it, so
   the real choice was Phase 4's evidence versus an external pass by John. Recorded in decisions/log.

## THE PROPERTY THAT CHANGES IN THIS PHASE
Phases 1 through 4 all ended with `git diff main -- RetireSmartIRA/` EMPTY. That is over. Numbers
move here on purpose. What replaces the empty diff is (a) attribution, via the Task 1 movement
ledger, and (b) confinement: the diff must stay inside Resources/StateTaxData/2026/, so any .swift
file in it means the scope boundary was crossed.

## Pre-flight plan review (controller, before Task 1)
Scanned for self-contradiction and for anything the review rubric treats as a defect. One item worth
naming rather than fixing: Task 1's `ledgerIsWellFormed` loops over an empty ledger and so asserts
nothing on first run. It gains teeth as entries land, and the real gate is proven by the Step 5
mutation in both directions, which is required before any correction is permitted. Left as written.

## Tasks
(none complete yet)
Task 1: complete (commits de74471..11f6f76, review clean, then hardened).
  The frozen baseline stays FROZEN FOREVER. Every deliberate movement is a checked-in record naming
  the golden case that authorises it. Proven to fail in BOTH directions before any correction was
  allowed: an unauthorised movement (config changed, no entry) and a lying ledger (entry whose
  `before` disagrees with the frozen file).
  Reviewer walked all five silent-movement paths and found none open. The one it expected to be a
  gap, a ledger entry for a value that did NOT move, is closed as a side effect of comparing against
  `after` rather than `before`, backstopped by the well-formedness check that rejects a zero-movement
  entry.
  ** TWO MINOR FINDINGS ACTED ON IMMEDIATELY RATHER THAN DEFERRED, because the next six tasks all
  write ledger entries and both protect exactly that: **
  (a) `goldenCase` was free text validated only as non-empty, so a typo or a plausible name for a
      case never written would break the attribution chain silently while every test stayed green.
      Now machine-checked against the actual golden fixtures. Probe confirmed it fails naming the
      missing case.
  (b) `generate()` regenerates the frozen file wholesale and was correctly left alone by Task 1 as
      out of scope, but under the new design one command with STATE_TAX_BASELINE set destroys four
      phases of evidence. Not deleted (a new tax year is a legitimate use); made loud instead.
  Montana decision, made deliberately: a movement in a jurisdiction with NO golden fixture FAILS,
  because no golden coverage means no attribution target to point at.
  OPEN, recorded not fixed: the one-golden-case-per-movement model is unproven under load. The
  implementer found no concrete break but flagged Kansas's SB1 fixtures as the likely first test.
  Revisit if a real single-fix-moves-many-cases situation appears in Tasks 2 to 7.
Task 2: complete (commit 49a9084, review clean, no Critical or Important findings).
  ** THE FIRST TAX VALUE THIS PROGRAM HAS EVER CHANGED. ** Steve Nicolai's scenario now computes
  $1,218.88 where it produced $2,171.52. Reviewer reproduced the arithmetic independently:
  $50,000 - $8,240 - $18,320 = $23,440 x 5.2%.
  Deleted KS-1, KS-2, KS-3. Retained KS-4, KS-5 (per-source, Phase 5b) and KS-6 (the documented
  COMBINED case, which correctly still fails and whose observedToday was updated to the
  personal-exemption-fix-only figure the fixture had PRE-PREDICTED, $1,218.88).
  ** KANSAS IS NOT YET FULLY CORRECT. ** Its second defect stands: KPERS, federal, military and
  Railroad Retirement pensions should be fully exempt while private pensions are taxable. A Kansas
  filer holding a KPERS pension is still over-taxed. Do not tell Steve Kansas is fixed.
  Dependents: the app has NO dependent-count input anywhere, so the correction is scoped to single
  and MFJ and the $2,320-per-dependent amount is left unmodelled and recorded. Reviewer confirmed no
  notional dependent was folded into either base figure, which would have made the shipped number
  wrong for the single filers who are this app's typical user.
  Baseline movements: ZERO, and the claim was VERIFIED not accepted. calculateStateTax only subtracts
  a caller-supplied postExemptionDeduction literal and never reads config.personalExemption, so that
  gate is structurally blind to this fix. The real guard is the golden suite.

## THE BLOCKER THIS TASK UNCOVERED, and the pattern it sets for the six that follow
configs2026Legacy is a 1,651-line second copy of all 51 states' data in StateTaxData.swift. Its own
comment says "Not the production path after Task 11", but config(for:) tries JSON, then legacy, then
preconditionFailure, WHICH TRAPS IN RELEASE TOO. So it is a live fallback, and a Phase 1 test asserts
the two tables are identical per state. Correcting Kansas's JSON turned that red.
John's decision: FREEZE the legacy table at pre-correction law. Not updated per correction (35
double-edits, and this project already drifted a hand-duplicated mirror five times on one branch),
not deleted (deleting makes a bundling failure CRASH rather than serve slightly stale numbers, which
is a worse trade for a shipped consumer app than Phase 2's California case, where the fallback served
ANOTHER STATE'S data).
** THE SKIP IS LOUD, NOT SILENT, and this was the requirement that mattered: ** a corrected
jurisdiction must be asserted to have DIVERGED. If Kansas's two configs ever match again, meaning the
correction was reverted or someone edited the frozen table, the suite fails. Reviewer confirmed
StateTaxJSONEquivalenceTests.swift:323-345 asserts inequality rather than skipping.
Residual risk DISCLOSED in the legacy table's own doc comment, in user terms: if the bundled JSON ever
fails to load, a user in a corrected jurisdiction silently receives pre-correction tax rules.
Next six tasks append to `phase5CorrectedJurisdictions` (StateTaxJSONEquivalenceTests.swift:255-273),
which carries an "Append here, and only here" comment.
MINOR, open, to fold into Task 8: StateTaxBehaviorBaselineTests.swift:81-87 names
NJOtherExclusionAndExemptionsTests as the guard for personal-exemption logic. That file is
New-Jersey-only and never mentions Kansas. Kansas's actual guard is the golden suite. Pre-existing
comment, not authored by this task, but it misleads a future reader.
Task 3: complete (commits 258eeb5..a74407f, one Critical finding, fixed).
  IOWA IS FULLY CORRECT: 0 of 6 defect cases remain. A 60-year-old Iowan converting $200,000 now owes
  what Iowa actually charges instead of roughly $7,600 of invented state tax. Reviewer hand-verified
  all six config fields, all four deletions, and independently recomputed all 18 baseline movements.
  Single JSON edit, exactly as Phase 3a's config work predicted. The audit's "engine surgery"
  description was stale and correctly ignored.
  ** THE CRITICAL FINDING WAS A FALSE CLAIM IN THE RECORD, NOT A WRONG NUMBER. **
  Iowa needed one value that cannot be looked up: does Iowa tax the WITHHELD portion of a Roth
  conversion? PA says yes on a PA-specific cost-recovery mechanism; IL and MS, whose exclusions are
  blanket like Iowa's, say no. No Iowa DOR guidance addresses it (FAQ and Iowa Admin Code
  r.701-302.54 both checked). `false` was chosen by analogy, which is defensible and STANDS.
  What was wrong was the report calling the choice MOOT. The reviewer hand-computed, and the fixer
  independently CONFIRMED, that on baseline key `IA|single 62 conversion 100k with 22k withheld` the
  tax is $1,520.00 under the shipped `false` and $2,356.00 under `true`. An $836 difference, on a
  baseline scenario whose own comment says it exists to distinguish exactly this mechanism.
  ** THIS MATTERS BECAUSE THE APP HAS A ROTH CONVERSION WITHHOLDING FEATURE, ** so an Iowa user
  electing withholding hits this path. A shipped tax figure now rests on a reasoned analogy rather
  than a citation. Corrected in three places (report, movement ledger justification, and the Iowa
  fixture text) so the analogy travels with the data instead of living in a gitignored report.
  OPEN ITEM FOR JOHN, worth closing before release: get Iowa DOR or a CPA to confirm the withheld
  portion treatment. If it turns out to be `true`, Iowa's withheld-conversion figures move by ~$836.

## CONTROLLER ERROR, the fifth time a subagent caught something I got wrong
My Layer A probe instruction (revert only Iowa's `distributionMinAge` to 59) does NOT demonstrate the
gate's teeth. The fixer ran it, found it stayed GREEN, and traced why: only 1 of the 10 grid scenarios
sits in the 55-58 band that field affects, and that one still diverges independently via the
Roth-conversion exemption, which is gated separately. Every other scenario diverges via
iraWithdrawalExemption/pensionExemption, gated by `regularExemptionMinAge`, which my probe left
untouched. It used a FULL revert of all Iowa Phase 5a fields instead and the assertion failed as
designed. Lesson: a mutation probe must target the mechanism the assertion actually rests on, and I
specified one field where the gate depends on several independent ones.

## PROGRESS: 111 defect cases remain (Phase 4 closed at 118). 18 attributed baseline movements.

## PARALLEL FAN-OUT for Tasks 4 to 7 (NM, GA, UT, IN), worktrees p5-t4 through p5-t7 off a74407f
Task 7 Indiana: complete (commit 30682bd on feature/state-tax-phase5-t7). 4 of 4 cases resolved.
  The 0.0295 arithmetic check held EXACTLY on all four (29.50 = 1,000 x 0.0295 for both single cases,
  59.00 = 2,000 x 0.0295 for both MFJ), which is what turns "Indiana is wrong" into a diagnosed
  mechanism rather than a coincidence.
  Baseline movements: 0, VERIFIED rather than assumed, by re-running the baseline suite and confirming
  the frozen file unchanged. Same mechanism Kansas hit: the harness passes postExemptionDeduction as a
  per-scenario literal and never reads config.personalExemption. The dispatch warned against
  manufacturing movements to look thorough and it did not.
  It also kept Indiana OFF the Layer A scenario-grid list for the same reason Kansas is off it (that
  grid hardcodes postExemptionDeduction too), reasoning by precedent rather than by instruction. That
  is the judgement the two-list design was hoping for.
Task 6 Utah: complete (commit fca91b5 on feature/state-tax-phase5-t6). EXACTLY 1 deleted, 4 remain,
  which is the outcome the dispatch demanded and the one a careless implementer would have got wrong.
  The deleted case is the $110k Roth-conversion phase-out scenario, where BOTH Utah credits are
  legitimately zero under real law, so the bare rate gap is isolated there and nowhere else.
  ** THE PART THAT SHOWS THE INSTRUCTION LANDED: ** the four surviving blocks did not just survive.
  Two summaries were REWORDED to drop the now-fixed rate-staleness claim, and all four had
  observedToday REMEASURED. A stale summary still asserting the rate is wrong would have misdirected
  Phase 5b into re-fixing something already corrected, which is the specific harm the "correct the
  wording, do not delete the block" instruction exists to prevent.
  19 baseline movements, everything except the zero-income scenario, all measured and attributed.
  Utah went into BOTH equivalence lists, unlike Kansas and Indiana, correctly: a rate cut is exercised
  by nearly every scenario in both grids, whereas a personal exemption is exercised by neither.
Task 4 New Mexico: complete (commit c71e9b4 on feature/state-tax-phase5-t4). 2 deleted, 2 remain.
  The engine no longer runs the bracket table a bill signed 2024-03-06 deleted. This was the oldest
  defect in the catalogue and it hit every NM filer, not only retirees.
  ** SIXTH TIME AN AGENT CAUGHT AN ERROR IN WHAT I GAVE IT: ** my brief said ONE case would not
  resolve. Two do not. It trusted the MEASURED xcodebuild classification over my count and left both
  standing with remeasured pins (48.45 to 42.75, 87.55 to 77.25). Both compound the bracket defect
  with NM's age-65 PIT-ADJ exemption, which StateTaxConfig has no field to express, so both are
  correctly Phase 5b.
  ** A GAP IN A PHASE 4 FIXTURE, worth knowing before Phase 5b leans on others: ** the NM golden
  fixture quoted only the FIRST bracket of the married table, not the full schedule. The implementer
  needed the whole thing, so it independently fetched HB0252TRS.pdf page 16 and confirmed the complete
  table before writing it, citing that in its report. Correct behaviour, but it means a fixture can be
  citation-clean and still not carry everything a corrector needs. Expect this again.
  19 baseline movements, measured and attributed.
