# Session 2026-08-03 to 2026-08-04: State Tax Phase 3 (a + b) and RMD Spouse Attribution

Both bodies of work are MERGED AND PUSHED. `origin/main` @ `a0452da`.
Nothing here has SHIPPED. `main` is well ahead of released 2.3.0, so Steve Nicolai and Alan Levy
still run an app where their reported items are broken.

---

## 1. State Tax Phase 3, split into 3a and 3b

Phase 3 of the seven-phase state tax verification program (spec
`docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md`) was split,
because per-source exemptions are useless to users until the app can tell a government pension from
a private one.

**Phase 3a** (merged `b138a62`): five hardcoded rules became config data, each defaulting to
reproducing today's computed tax exactly. `distributionMinAge` (a literal 59 in the engine plus two
more in DataManager's mirror), `personalExemption` (a New-Jersey-only function), `agiPhaseout` (new
mechanism, unused by any state), `exemptionAttribution` (new mode, every state stays `.household`),
`rothConversionExemption` (two hardcoded `switch state` blocks over PA/IL/MS).

**Phase 3b** (merged `16fd6a2`): per-source exemption classification with its user-facing UI.
`PlanStructure` and `PlanSource` were deliberately kept as two axes rather than one broad
`.governmentPension` case, so a non-New-York public pension cannot accidentally receive New York's
uncapped IT-201 Line 26 exclusion.

**No jurisdiction's numbers moved in either phase.** The phase gate was a frozen behavior baseline:
51 jurisdictions x 20 scenarios = 1,020 values, captured BEFORE any change.

### The defining pattern of both phases
Every task shipped something that looked guarded and was not, and it was found by REVERTING A LINE
AND RE-RUNNING, never by reading a diff. Five separate DataManager mirror drifts on 3a alone. An
encoder guard whose comment claimed "all nine fields" had silently gone stale at 9 of 11.

### The single most valuable outcome
In-app verification found a **memoization cache-key gap**: `engineInputsHash` in
`DataManager+Memo.swift` omitted `planStructure` and `planSource`, so a user could classify an
account and watch nothing happen. It was missed by 1,752 tests, the 1,020-value frozen baseline,
four golden scenarios, six per-task reviews AND a whole-branch review, because every one of them
called the engine directly and none went through the memoized property a user actually reads.

### My own defects during this phase, worth not repeating
- I told an implementer to mutate `configs2026Legacy`, which is DEAD on the read path since Phase 1
  Task 11. The implementer reported the unexpected PASS rather than fabricating a result.
- Deferring all JSON regeneration to a later task silently regressed NJ's personal exemption to $0
  on the production path. The implementer's `configs2026Legacy` fallback workaround was rejected;
  the correct fix was to regenerate in-task.
- My spec contained a FALSE sentence ("affects the single-year calculation and not the Multi-Year
  projection") that was copied verbatim into user-facing UI. Account classification affects NEITHER.
- `git add -A` raced a reviewer's in-flight mutation and committed its temporary revert.
  RULE ADOPTED: stage explicit paths, never commit while a review agent is running.
- Four working-directory slips, one committing a ledger to the wrong branch.
  RULE ADOPTED: absolute paths and `git -C`, never rely on a chained `cd`.

---

## 2. Emails to Steve Nicolai and Alan Levy (both SENT 2026-08-03)

Drafts saved at `.claude/memory/drafts/emails/2026-08-03-steve-nicolai-twelve-items-reply.md` and
`2026-08-03-alan-levy-457-account-type.md`.

**John's correction, which set a standing rule:** my first draft disclosed the internal audit
finding that ~29 of 51 jurisdictions were defective. John rejected it flatly: *"steve is a user, not
a shareholder... it gives him the ability to share on bogleheads how bad the app was and how he
straightened it out, leaving a very tarnished reputation."*
**RULE: scope user-facing replies to that user's OWN items. Internal audit findings stay internal.**

Also corrected before sending: the draft said "RMDs begin at 73", which is wrong for anyone born
1960 or later, since `ProfileManager.swift:101-109` returns 75. Changed to "the same age".

---

## 3. RMD Spouse Attribution (the larger half of the session)

Plan `docs/superpowers/plans/2026-08-03-rmd-spouse-attribution.md`, ten commits, merged `a0452da`,
branch also pushed to origin at `3cf3d85` for granular history. Full macOS suite green
(1,843 Swift Testing + 509 XCTest), frozen tax baseline unchanged, verified in the running app.

### THE FINDING THAT MATTERS MOST
**The spouse's RMD was ALWAYS in the tax math.** Established by EXECUTION, not reasoning: on a
household with a zero-balance primary and a 78-year-old spouse holding $1M, toggling `enableSpouse`
moved `scenarioTotalTax` from $780 to $4,976.55.

The failure shape was the OPPOSITE of what I briefed the auditor to hunt for. I told it to look for
a combined number under a primary-implying label. No money row has that. The real shape is the
mirror image: **primary-only STATUS TEXT sitting directly above correctly-attributed combined
money**, and the header is read first. That is why a customer reported a missing number when no
number was missing.

**When writing to Steve: his figures were right and the labels around them were not. Do not
apologize for wrong math; there was none.**

### Two promised items became nine surfaces
RMD status card, projection chart, Dashboard Tax Summary header, Scenario Builder, Legacy tab,
single-year CPA briefing, action items, Multi-Year banner, multi-year CPA briefing.

Three were never reported and matter more than the request:
- The **December 31 deadline block** was primary-only, so in Steve's exact household the card named
  his wife and then omitted the deadline for the only person who has one. She is 73 with an RMD age
  of 73, her FIRST RMD year, so the April 1 deferral the app grants a primary in the identical
  position was being withheld from her. Told something stricter than the law, denied the mitigation.
- The **single-year CPA briefing contradicted itself**, printing "RMD Begins: Age 75 (14 years)"
  while billing "Spouse's RMD $45,454.55" two sections later. It goes to a third party.
- The **multi-year briefing** printed "2026 / age 64 / RMD $45,283", impossible for a 64-year-old,
  because the Age column used the primary's birth year beside a household figure.

### A regression this work introduced, then fixed
Making the badge read "anyone required" meant a 73-year-old spouse holding only a **Roth** got
"RMDs Required", an April 1 notice, the two-RMDs warning, and a RED CPA alert row, while
`combinedRMD` was 0 and there were no action items. A Roth has no lifetime RMD. On `main` that
household correctly read "Not Yet Required".

**The principle that resolved it, and the correction to my own earlier call:** rewording the LINES
into age statements was right and stays. But I extended that reasoning to surfaces that are not age
statements at all. A badge saying "RMDs Required", an April 1 deferral notice, and a red alert row
in a CPA document are **due-ness claims**, and age alone cannot support them.
**Age statements stay age-based; due-ness claims check that the person holds a traditional balance.**

Badge kept as "Not Yet Required" rather than inventing a third string, because new user-facing
wording is John's call with 2-3 options offered.

### Testing notes worth keeping
- `RMDHouseholdStatus` hoisted as a PURE value type (no DataManager, no SwiftUI, no `Date()`),
  because the preceding phase shipped a defect that 1,752 tests missed by living in a private view
  method. Same reasoning drove `RMDStatusPresentation` and the chart builder.
- A reviewer caught that `max(0, rmdAge - age)` CLAMPS, destroying who became required FIRST when
  both already are. Fixed with one signed measure (`age - rmdAge`, larger started first), correct in
  all three regimes. All seven original tests passed unchanged, which is the evidence it corrected
  an unspecified case rather than altering a specified one.
- **The headline customer scenario does NOT catch the misattribution bug**, because both spouses
  there share RMD age 73. Under that mutation the Steve test AND all 11 DataManager-level
  attribution tests stay GREEN. Only the differing-ages test catches it. Do not trust the headline
  scenario to protect this.
- Chart sum preservation is pinned against an INDEPENDENT transcription of the pre-split
  accumulator, not by re-using the code under test to compute its own expectation.
- TRAP: `MultiYearStrategyManager.dataManager` is `private weak`. A first draft of its tests let the
  DataManager deallocate inside a helper and a nil-expecting test PASSED FOR ENTIRELY THE WRONG
  REASON. Tests now assert the RMD ages before the real assertion.

### What only the running app caught
The Scenario Builder's "Conversion Opportunity Window" still read *"You have 9 years before RMDs
start. This is an ideal time for Roth conversions"* while the wife owed $33,962.26 by December 31.
`TaxPlanningView.swift:938` gated on primary-only `isRMDRequired`, while the Legacy tab, which this
branch HAD fixed, correctly showed nothing. **Two screens contradicted each other, and the branch
created that gap by fixing one twin and leaving the other.** Not in the plan, not in the 45-site
audit, not caught by any of seven reviews. Subtle because each sentence was individually TRUE; the
defect was the household-level advice clause welded onto a per-person fact.

### The build trap, worth more than any single fix
A rebuild reported `** BUILD SUCCEEDED **` and the simulator kept running OLD code. Cause: the
working directory resets between tool calls, so `xcodebuild` with no `-project` built the MAIN REPO,
which is on a different branch, into a DIFFERENT DerivedData directory (there are ~38
`RetireSmartIRA-*` dirs; the worktree's was `bqlnhygmnxefdndsouzuybyhyurq`). Backgrounded commands
do not change session cwd, so `cd X && ...` protects only that one call.
Caught by comparing `stat` on the built binary (23:53) against source mtimes (01:04).
**RULE: always pass `-project <worktree>/RetireSmartIRA.xcodeproj` explicitly, and confirm the
product mtime is NEWER than your last commit before believing anything on screen.**

### Git note from the merge
Completing the merge out-of-band while its editor was still open left a stale `MERGE_HEAD` after the
abandoned `git merge` exited. Content was fine, but that marker would silently make the NEXT
ordinary commit a two-parent merge. `git merge --quit` clears it without touching index or tree.
**Finish a merge in its editor, or close the editor first, then commit.**

---

## Where things stand

**Six written commitments, two now built:**

| # | Promised | Status |
|---|---|---|
| 1 | Kansas exemption corrected | State Tax Phase 5 |
| 2 | Iowa exclusion corrected | State Tax Phase 5 |
| 3 | Per-state detail view | State Tax Phase 6 |
| 4 | RMD summary leads with whoever starts first | **on main**, unreleased |
| 5 | RMD chart separates the two people | **on main**, unreleased |
| 6 | Caret fix (owed to Alan since 2026-07-19) | on main, already missed 2.3.0 once |

**Backlogged deliberately, all recorded:**
- P6 age-vs-due gate (`TaxPlanningView.swift:1644`): a zero-balance primary past 75 is told
  "RMD required". Defensible when primary-only; this branch made it reachable through a spouse.
- P7 `enableSpouse=false` zeroing a spouse traditional balance (`DataManager.swift:433` ->
  `AccountsManager.swift:94`). Largely defended; residual risk is an imported profile.
- Cosmetic: the Tax Summary's third metric card is now taller than the two beside it, because the
  RMD status line sits in a `delta` slot with no `lineLimit`. Fine on iPhone 17 Pro, likely tight on
  an SE.
- Pre-existing flake: `MultiYearPerfTests.persona2_mfjCouple35Years`, a 15-second wall-clock budget
  missed by 0.08%, green in isolation. Unrelated to any of this work.

**Housekeeping:** `feature/state-tax-phase3b` was never pushed to origin (3a is there, 3b is not).
Both state-tax worktrees are merged and removable. The RMD worktree was removed and its gitignored
`.superpowers/sdd/` mutation transcripts went with it; the durable record is the branch ledger at
`.claude/memory/roadmap/2026-08-03-rmd-spouse-attribution-ledger.md`, now on `main`.

**Next:** State Tax Phases 4-7 remain, and Phases 5 and 6 carry three of the six promises. The
multi-year path got its first real audit this session but only where these defects reached it; it
has never had a full pass.
