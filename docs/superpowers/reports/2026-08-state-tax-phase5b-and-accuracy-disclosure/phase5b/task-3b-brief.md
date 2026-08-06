# Task 3b: the unclassified-pension disclosure stops being New York only

**Not in the plan.** A Task 3 reviewer finding, rated Important, that John decided on 2026-08-05. It is
its own task and its own commit so the disclosure change is reviewable apart from the Kansas rule diff.

## The defect

Two disclosures exist to tell a user that a per-source rule is going unused because their pension is
unclassified. Both are hardcoded to New York:

- `RetireSmartIRA/StateComparisonView.swift:21-29`. `showsUnclassifiedNewYorkPensionLimitation` gates on
  `viewedState == .newYork && hasUnclassifiedPension`, and the copy is a `static let` beside it.
  **Note the deliberate asymmetry recorded in its own doc comment: this one gates on WHICH STATE'S
  BREAKDOWN IS ON SCREEN, not on residence, because State Comparison computes every state's tax for a
  non-resident too. Preserve that.**
- `RetireSmartIRA/MultiYearCPABriefing.swift:394-397`. `newYorkUnclassifiedPensionLimitation` gates on
  `residesInNewYork && hasUnclassifiedPension`, called from `RetireSmartIRA/MultiYearPlanView.swift:371-377`.

Kansas now ships a per-source rule, so an unclassified Kansas KPERS holder is taxed in full on an
exclusion Kansas law grants, with no warning on either surface, while an identically-placed New York
user is warned on both. **Nothing tests either surface today.**

## The decision, option 2 of three

Gate on whether the relevant state's config carries per-source rules AT ALL, rather than on New York,
and take the jurisdiction-specific SENTENCE from that state's own config. New York keeps its exact
current wording. Rejected: generic copy naming no state or figure (a vague warning does not tell a user
what to do), and adding Kansas alone (reopens the same gap at MA, HI, AZ, ID, VT and DC).

`RetireSmartIRA/IncomeSourcesView.swift`'s `residenceHasPerSourceRules` is the existing precedent for
the data-driven gate: it reads live config rather than hardcoding a state. Task 3 added
`residenceNamesItsOwnJurisdiction` in the same spirit. Follow that pattern.

## Copy, APPROVED BY JOHN. Use verbatim.

Sentence one is jurisdiction-independent and stays in code, unchanged:

    Your pension is not yet classified as government or private in Income Sources.

Sentence two comes from config. It carries a token where the two surfaces differ: State Comparison says
"this figure", the CPA briefing says "this plan". **One string per jurisdiction, not two.**

New York, which must remain BYTE-IDENTICAL to what ships today once the token is substituted:

    New York excludes a qualifying government pension from state tax with no dollar cap, but
    <TOKEN> applies the standard $20,000 pension exclusion until it is classified.

Kansas, option A, approved 2026-08-05:

    Kansas exempts a KPERS, federal government, military or Railroad Retirement pension from state
    tax with no dollar cap, but <TOKEN> taxes your pension in full until it is classified.

Pick a token spelling that cannot collide with prose. Assert by test that substituting it into New
York's entry reproduces today's two strings EXACTLY, character for character. That test is the
regression guard for the whole change: it is what proves New York's user-visible copy did not drift.

## What to build

1. An additive optional field on the shipped state config carrying that sentence. `decodeIfPresent`
   with a nil default, so all 49 configs that do not set it decode unchanged and neither surface fires
   for them. Follow how `perSourceExemptions` was added in `RetireSmartIRA/StateTaxCodable.swift`.
2. Populate it in `statetax-2026-NY.json` and `statetax-2026-KS.json` only.
3. Rewrite both gates to read the config. Keep State Comparison keyed on the VIEWED state and the CPA
   briefing on RESIDENCE. Rename the two functions so nothing still says "NewYork".
4. Tests. There are none today. Cover, at minimum: the New York byte-identity assertion above; Kansas
   now fires on both surfaces; a state with no per-source rules fires on neither; a classified pension
   fires on neither; and a sweep asserting that every config shipping `perSourceExemptions` also ships
   this sentence, so a later task cannot add a rule and silently forget the disclosure.

## Carry forward

**Every remaining Phase 5b jurisdiction task (4 MA, 5 HI, 6 AZ, 7 NC, 8 ID, 9 VT and DC) now owes a
disclosure sentence alongside its rule.** The sweep test in item 4 is what enforces it. Say in your
report that Task 10 should verify none was skipped.

## Constraints

- ABSOLUTE PATHS and `git -C` only. Never a bare relative path, never a chained `cd`. The controller's
  own shell silently reset to a different worktree on a different branch twice today.
- **The copy above is user-facing and John approved these exact words. Do not improve them.** If you
  believe a word is wrong, say so in the report and ship the approved wording anyway.
- No pin may move: `observedToday`, `tier` and `expectedStateTax` in golden fixtures are untouchable,
  and this task should not go near them. The frozen baseline in `RetireSmartIRATests/Baselines/` stays
  untouched. No golden fixture should need to change at all; if you think one does, stop and report.
- NO EM DASH CHARACTERS anywhere, including UI copy, JSON strings, comments and the commit message.
- Run the FULL suite with `tools/run-tests.sh` in the FOREGROUND, `timeout` 600000, never backgrounded,
  never `xcodebuild` directly. Baseline to beat: 1,910 Swift Testing in 296 suites + 509 XCTest, 0
  failures.
- **VERIFY BEFORE YOU COMPLY.** Nine times in this program a subagent has caught an error in the brief
  it was handed. Everything above is evidence, not fact. If the code contradicts it, follow the code
  and say so.
