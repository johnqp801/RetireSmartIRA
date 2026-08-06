# Every disclosure surface misses the "ships no rule on purpose" case

**Found:** 2026-08-05, Phase 5b Task 8 (Idaho) and its review. Confirmed against source.
**For:** Phase 6 disclosure work. This is a STRUCTURAL finding, not an Idaho one.

**AMENDED at Phase 5b close (Task 10).** Two counts below were written at Task 8 and Task 9 moved
both. The category now holds **FOUR** jurisdictions, not three: Vermont joined Hawaii, North
Carolina and Idaho, and it carries the largest gap of the four ($5,211.50 a year at VT-6's shape).
`knownButUnpinned` now holds **eleven** entries, not eight: DC's was added by Task 9 and is the
sharpest case in the file, because a DC survivor whose row predates Task 9 is over-taxed while
being perfectly CLASSIFIED, so every gate listed below misses them for a second, independent
reason. Nothing else in this note changed, and none of its recommendations were acted on.

## The shape

Phase 5b produced a category that did not exist when the disclosure surfaces were
designed: **a jurisdiction with a real golden fixture, defects measured and pinned, and
`perSourceExemptions` deliberately EMPTY** because its law is inexpressible. Three
jurisdictions are now in it: **Hawaii (Task 5), North Carolina (Task 7), Idaho (Task 8).**

Every existing surface gates on something this category fails.

| Surface | Gate | Why it misses |
|---|---|---|
| `PlanClassificationChoice.shouldPromptForClassification` | `residenceHasPerSourceRules`, i.e. `!perSourceExemptions.isEmpty` | Zero rules, so the classification prompt never fires |
| `UnclassifiedPensionDisclosure.text(for:scope:)` | config's `unclassifiedPensionDisclosure` sentence | That sentence is in bidirectional lockstep with the rules, so it cannot exist without them |
| `GoldenScenarioCoverageTests.cannotVerify` | jurisdiction has NO fixture | These have fixtures, and good ones, so they are not flagged as unverified |

**The gate is "did this state ship rules", and the answer that needs disclosing most is
"no, deliberately, because we could not."** That is exactly backwards.

## Two further gaps in the same area

- **`GoldenScenarioDefectCatalogueTests.knownButUnpinned` has NO production consumer at
  all.** It is the durable record for every defect no fixture can hold (AZ, KS, MA x2,
  MO, NC x2, ID), and nothing reads it outside the test target. No user, and no CPA
  briefing, is told anything it contains.
- **The captions only render inside the pension EDIT sheet.** `IncomeSourcesView` shows
  the Hawaii, Massachusetts, North Carolina and Idaho captions in the add/edit income
  form. A user who entered their pension and THEN moved to one of these states, or who
  simply never reopens the row, never sees one. The CPA briefing carries no line for any
  of them.

## Why it matters more than it looks

The three jurisdictions in this category are there BECAUSE their errors could not be
fixed. So the population with the largest unfixable error is the population told
nothing. Directions differ and the copy must not be harmonised: Hawaii, North Carolina
and Idaho all run toward OVER-taxation; Massachusetts runs toward UNDER-taxation.

## What Phase 6 should decide

1. Re-gate disclosure on **"this jurisdiction has a recorded gap"** rather than on
   "this jurisdiction shipped rules". The natural source is `knownButUnpinned` plus the
   fixtures' `knownDefect` blocks, which would need to move out of the test target or be
   mirrored into one shipped structure.
2. Give `knownButUnpinned` a production consumer, or accept in writing that it is an
   engineering record only.
3. Put these disclosures somewhere a user sees without editing an income row. State
   Comparison and the CPA briefing are the two candidates already in the codebase.
4. Task 5 already recorded that the Hawaii and Massachusetts captions are inline string
   literals with no test seam. North Carolina's (Task 7) and Idaho's (Task 8) are
   hoisted statics WITH seams. Finish the job by hoisting the first two.

## Related

- `.claude/memory/roadmap/2026-08-05-unclassified-pension-disclosure-decision.md`
- Idaho's reasoning: `RetireSmartIRATests/Phase5bIdahoDecisionTests.swift`
- North Carolina's: `RetireSmartIRATests/Phase5bNorthCarolinaDecisionTests.swift`
- Hawaii's: `RetireSmartIRATests/Phase5bHawaiiDecisionTests.swift`
