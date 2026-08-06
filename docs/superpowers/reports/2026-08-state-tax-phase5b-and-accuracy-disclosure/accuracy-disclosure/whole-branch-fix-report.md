# Whole-branch review fixes, `feature/state-accuracy-disclosure`

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure`,
branch `feature/state-accuracy-disclosure`, from HEAD `847689a` (clean at start).

Two commits, one per must-fix item. Full suite via `tools/run-tests.sh`, foreground, green at each.

| Commit | Item | Suite |
| --- | --- | --- |
| `3f3ccfb` | CRITICAL 1, remove the multi-year entry point | 2,077 Swift Testing in 306 suites + 509 XCTest, 0 failures |
| (below) | IMPORTANT 2, Georgia's fourteenth sentence, plus I4 | 2,077 Swift Testing in 306 suites + 509 XCTest, 0 failures |

---

## Verification of the brief before complying

Both findings were checked against the code and both are correct.

**C1's engine claim is real.** `TaxCalculationEngine.calculateStateTax` (line 340) never touches
`config.stateDeduction`; it applies `applyRetirementExemptions`, then subtracts
`postExemptionDeduction`, then brackets. The single-year caller `DataManager.calculateStateTax`
(line 728) computes `stateDeduction` by `.none`/`.conformsToFederal`/`.fixed`, subtracts it, and
passes the personal exemption as `postExemptionDeduction`. The multi-year caller, which is
`ProjectionEngine.computeStateTax` and NOT `calculateMultiYearStateTax` as the brief's file/line
pointer implied, passes `income: federalAGI` and omits `postExemptionDeduction` entirely. So the
review's description is right and only the function name in the brief was off.

**Gate 3's blind spot is real.** `perSpouseProbe` and `socialSecurityProbe` both compute the state
standard deduction themselves and pass `income: max(0, X - stateStandardDeduction)` with an explicit
`postExemptionDeduction`. They reproduce the single-year contract and re-verify it. A green Gate 3
was never evidence about the multi-year path.

**Georgia's sentence is garbled as described.** GA's config carries `stateDeduction`
`.fixed(single: 15_000, married: 30_000)` and a `$65,000` retirement exclusion; the memory record
at `.claude/memory/roadmap/2026-08-02-full-50-state-verification.md` confirms the TY2027 figure is
the EXCLUSION rising to `$70,000`. `topic` was `pension`.

One correction to the brief's arithmetic, not to its conclusion: the six approved captions are not
all in `verification.knownLimitations`. FIVE are (HI, ID, VT, NC, MA). The District of Columbia's
survivor-toggle caption is still a Swift literal in `IncomeSourcesView` and was never moved, which
is why DC's two config sentences are both from the approved thirteen. The bookkeeping still lands on
Georgia as the one unapproved sentence: 13 approved + 5 moved captions + Georgia = the 19 sentences
that shipped.

---

## CRITICAL 1: the multi-year entry point is removed

### What was removed

| File | Removed |
| --- | --- |
| `RetireSmartIRA/ApproachComparisonView.swift` | `accuracyState`, `filingStatus`, `showingStateAccuracy`, the `.sheet` presenting `StateAccuracyView`, and the whole `stateDeltaTag(_:)` builder. `consequenceStrip` now calls `deltaTag("State", d.state)`, which is the pre-Task-7 rendering. |
| `RetireSmartIRA/MultiYearPlanView.swift` | `multiYearAccuracyState`, and the two arguments it fed to `ApproachComparisonView`. |
| `RetireSmartIRA/MultiYearStrategyManager.swift` | The `@Published modelledState`, `recordModelledState(from:)`, and both of its call sites. Its only reader was the affordance. |
| `RetireSmartIRA/StateAccuracyContent.swift` | `stateForMultiYear(scenarioState:resident:)`, and the "three entry points" preamble now says two. |

`MultiYearStaticInputs.modelledState` was KEPT. `ProjectionEngine` reads it to resolve the
jurisdiction it taxes each projected year in; deleting it would be an engine change, which is out of
scope. Its doc comment no longer justifies itself by the affordance.

### The two surviving entry points, verified

Both untouched in behaviour, and both re-verified after the change:

- single-year results: `DashboardView.singleYearAccuracyState` calls
  `stateForSingleYearResults(resident:)`, which returns the RESIDENT;
- State Comparison: `StateComparisonView.accuracyPageState` calls
  `stateForComparisonSheet(inspecting:resident:)`, which returns the INSPECTED state.

`comparisonSheetNeverFallsBackToTheResident` still sweeps all 2,601 ordered pairs of the 51
jurisdictions for both, including the 51 where inspected and resident coincide.
`theTwoDestinationsAreDistinguishable` (renamed from `theThreeDestinations...`) still proves they
disagree when the states differ.

### The regression test, and why it is structural

`StateAccuracyContentTests.noMultiYearSurfacePresentsTheAccuracyPage`.

There is no runtime handle on "which view can present this sheet": SwiftUI presentation is a
modifier on a body, so any assertion phrased against one property name passes the moment someone
re-adds the affordance under a different name, in a different view, or behind a wrapper. What cannot
be avoided is that OPENING the page means CONSTRUCTING `StateAccuracyView`, and that an affordance
for it carries the entry points' shared accessibility label.

So the test reads every `.swift` file under the production target (through `#filePath`, the way
`TaxsimOracleTests` and `Phase3bPersistenceTests` already reach the checkout) and asserts:

1. the set of files containing `StateAccuracyView(` is EXACTLY
   `{StateAccuracyView.swift, DashboardView.swift, StateComparisonView.swift}`;
2. the set containing `State tax accuracy for ` is EXACTLY
   `{DashboardView.swift, StateComparisonView.swift}`;
3. each named multi-year presentation file (`MultiYearPlanView.swift`,
   `ApproachComparisonView.swift`, `MultiYearStrategyManager.swift`) EXISTS and contains neither
   marker, so a rename cannot silently drop it from coverage.

Both set assertions are equalities, not subset checks, so a NEW presenter anywhere in the app fails,
not only a multi-year one, and a shipped entry point losing its VoiceOver label fails too.
Non-vacuity is asserted explicitly: more than 100 files must be swept (a broken `#filePath` would
otherwise make the gate green and meaningless), and base names must be unique.

VERIFIED BY MUTATION. A `mutationProbe` view constructing `StateAccuracyView` and carrying the label
was added to `ApproachComparisonView`; the gate produced four failures naming that file, in both set
assertions and both per-file assertions. Reverted.

### What is recorded, and where

The restoration preconditions are written in three places a future task will actually hit:

1. `ApproachComparisonView`, at the top of the type, where the affordance was;
2. `StateAccuracyContent`, in the entry-point preamble, and in the gate's own comment block;
3. `.claude/memory/roadmap/2026-08-06-accuracy-disclosure-RESUME-HERE.md`, which survives the
   worktree.

They say the same thing: restoring the affordance depends on EITHER the engine gap being closed OR a
genuinely path-aware disclosure page landing, and that on the first route AN END-TO-END MULTI-YEAR
BEHAVIOUR PROBE MUST LAND BEFORE THE AFFORDANCE IS RESTORED, because Gate 3 cannot be adapted by
changing an argument.

The engine gap itself is recorded at `ProjectionEngine.computeStateTax`'s doc comment, with the
Kansas and Idaho magnitudes, the reason it is out of scope (it moves the frozen 1,020-value baseline
under `RetireSmartIRATests/Baselines/`), and the two consequences a fix must carry.

Gate 3's limits are recorded immediately above its own MARK, as required: that it is single-year by
construction, and that it behaviour-backs three claims only (per-spouse cap in 2 jurisdictions,
Social Security in 15, Roth conversions in 4), with the standard-deduction claim NOT among them.
That is I3, recorded there rather than only here.

The engine gap was NOT fixed.

---

## IMPORTANT 2: Georgia

`verification.knownLimitations` in `statetax-2026-GA.json` is now empty. Nothing was written to
replace it.

Follow-on edits, all of them forced by the removal rather than optional:

- `StateAccuracyContentTests.limitationBasis["GA"]`: sentence count 1 to 0, with the reason rewritten
  to record all four defects and the removal date, so the entry explains itself to a reader who
  never sees this report.
- `coveredJurisdictionsWithEmptyListsClaimNothing`: the declared literal moves from `["IA", "IN"]` to
  `["GA", "IA", "IN"]`. THIS ASSERTION FAILING IS THE FORCING FUNCTION WORKING: the removal could not
  pass in silence.
- `LimitationTopic`'s doc comment in `StateTaxVerification.swift` cited Georgia's sentence as proof
  that all pre-existing sentences were pension-topic. Rewritten: Georgia was the FIRST
  demonstration that the assumption would not hold, and it was withdrawn rather than retopiced.

The TY2027 fact is preserved at `.claude/memory/roadmap/2026-08-02-full-50-state-verification.md`
under Georgia, now stated precisely (the $70,000 is the exclusion; the standard deduction is a
separate $15,000/$30,000) and with the removal and its four reasons recorded beside it.

### PROPOSED replacements, for John. NONE OF THESE SHIPS.

All three are drafted to the branch's conventions: plain second person, no "config", an explicit
direction, and a topic that is NOT `pension` (the subject is the exclusion's future level, and the
pension editor is the wrong home for it). If John approves one, it would be tagged `exemption`,
Georgia's declared sentence count would go back to 1, and `["GA", "IA", "IN"]` would revert to
`["IA", "IN"]`.

> **A.** "Georgia's retirement income exclusion rises from $65,000 to $70,000 for tax year 2027,
> and this app applies the 2026 amount, so your Georgia state tax may be overstated for 2027 and
> later years."

> **B.** "This app models Georgia's rules for tax year 2026 only. Georgia's retirement income
> exclusion rises to $70,000 in 2027, so if your plan runs past 2026 your Georgia state tax may be
> overstated in those years."

> **C.** "Georgia raises its retirement income exclusion to $70,000 in tax year 2027. This app
> applies the 2026 exclusion of $65,000 for every year of your plan, so your Georgia state tax may
> be overstated from 2027 onward."

A caution John should weigh before picking one: every one of the 51 configs is a single tax year,
and this would be the ONLY sentence disclosing that, which risks implying the other 50 have no such
horizon. B is the most honest about that and the least specific about Georgia. The stronger option
may be to disclose the single-tax-year scope once, on the page, for every jurisdiction, rather than
per state. That is a design change and was not put to John.

### The sweep for other unapproved sentences

All 51 bundled configs were parsed and every `knownLimitations` entry listed. Nineteen sentences
ship. Georgia's was the only one outside the approved set:

| Approved 13 | AZ 2, DC 2, KS 1, MA 1, MO 2, NC 1, NM 1, NY 1, UT 2 |
| --- | --- |
| Approved captions, in config | HI 1, ID 1, VT 1, NC 1, MA 1 |
| Approved caption, still a Swift literal | DC survivor toggle, in `IncomeSourcesView` |
| NOT approved | GA 1, now removed |

The two `StateLimitation` fixtures in `StateTaxCodableRoundTripTests` are synthetic test strings with
no production consumer and are not user-facing copy.

No approved copy was changed anywhere: the six captions, the thirteen sentences, the Roth conversion
statement, the fallback strings and the three accessibility labels are byte-identical, and their
pinning tests are untouched and green.

### I4, folded in here

Four comments said New York was on neither divergence list and therefore required outright
byte-identity with the frozen table. New York has been on `disclosureOnlyDivergentJurisdictions`
since Task 4, so the premise was stale. Corrected at `Phase5bNewYorkMilitaryTests.swift` (the header
LAYER B block and the failure message in `theLegacyMirrorWasUpdatedToo`) and `StateTaxData.swift`
(the mirrored per-source rule and the mirrored `unclassifiedPensionDisclosure`).

THE CONCLUSIONS DID NOT CHANGE, and each correction says so explicitly.
`disclosureOnlyDivergentJurisdictions` excuses the `verification` block ALONE; the mirrored rule and
the mirrored disclosure are both computed fields and are still held to byte-identity. So the
mirrors are still required and the argument against adding NY to `phase5CorrectedJurisdictions`
still stands. The comment at `StateTaxJSONEquivalenceTests.swift` that cites that precedent as its
own justification now says the same, and its stale "THESE FOUR" count is now "THESE SIX".

---

## Recorded, not fixed

- **I3.** Gate 3's coverage. Recorded above its MARK in the test file and in the roadmap memory.
- **M1.** A per-state JSON decode failure now ERASES that state's disclosure. `StateTaxDataLoader`
  turns a decode throw into a per-state fallback to the frozen legacy table, whose `verification` is
  `.unverified` with empty limitations, and the accompanying `assertionFailure` is a no-op in
  release. At the merge base the five moved captions were Swift literals that could not fail to
  render; a release user now sees the empty-state wording instead. Recorded in the roadmap memory.
  Iowa doubles as a detector for this in one direction only (its Roth statement exists solely in the
  bundled JSON), and only in tests.
- **M5.** Iowa, Indiana and NOW GEORGIA render a verified date, a source link and "No known
  limitations are currently recorded for this state and tax year", which in aggregate reads closer
  to a clean bill than any single line of it claims. The design's second sentence ("State tax rules
  are complex, and this does not mean every unusual situation is represented") stays UNSHIPPED and
  UNAPPROVED, as instructed. Recorded as John's open call in the roadmap memory and in
  `coveredJurisdictionsWithEmptyListsClaimNothing`'s doc comment. Georgia joining makes the call
  slightly more pressing than the review found it, because three of fifteen covered jurisdictions
  now render it.

## Constraints observed

- No em dash and no non-ASCII in any added line, in any file, or in either commit message.
  Verified by `git diff | grep '^+' | grep -P '[^\x00-\x7F]'` returning nothing.
- No `knownDefect`, no pinned value and nothing under `RetireSmartIRATests/Baselines/` was touched.
- The full suite was run in the foreground with `tools/run-tests.sh` before each commit, never
  `xcodebuild`, never backgrounded. Green both times: 2,077 Swift Testing in 306 suites + 509
  XCTest, 0 failures. The count is one higher than the 2,076 baseline because this work adds exactly
  one test and removes none.
