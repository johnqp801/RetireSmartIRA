# Task 3 report: five of the six captions render from config

**Heading corrected 2026-08-06.** It said "the six captions". FIVE moved (HI, MA, NC, ID, VT);
the body below always said five. The District of Columbia's survivor-toggle caption stays a Swift
literal in `IncomeSourcesView` because it explains a CONTROL rather than describing a limitation.

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure`,
branch `feature/state-accuracy-disclosure`, started clean at HEAD `7e91f90`.

## What shipped

Five caption sentences moved into `verification.knownLimitations` in
`statetax-2026-{HI,MA,NC,ID,VT}.json`. The pension editor's five hardcoded state
branches became one `ForEach` over `StateAccuracyContent.limitations(for:)`.
`MultiYearCPABriefing.hawaiiPensionSplitLimitation` stopped carrying its own copy
of Hawaii's sentence and now renders the same stored one.

New API on `StateAccuracyContent`:

- `LimitationScope` (`.app` / `.plan`)
- `limitations(for:scope:)`, `scope` defaulting to `.app`
- `surfaceDependentLimitations(for:scope:)`, the token-carrying subset

## How each moved sentence was proved byte-identical

Nothing was retyped. Both Hawaii literals and all six caption STATICS were
extracted from the parent commit with `git show HEAD:<file>`, the Swift
multi-line `+` concatenations were rebuilt programmatically, and the JSON was
written from those exact bytes. Measured lengths, which match the brief:

| sentence | chars |
|---|---|
| `hawaiiEmployerFundedCaption` | 208 |
| `MultiYearCPABriefing` Hawaii literal | 209 |
| Hawaii **stored** sentence with `{scope}` | 212 |
| Massachusetts / North Carolina / Idaho / Vermont | 222 / 277 / 333 / 326 |

Two gates carry it in the suite:

- `movedCaptionsAreByteIdentical` asserts each of the five statics is an element
  of its state's rendered `limitations(for:)`. It reads the RENDERED list, never
  the stored one.
- `hawaiiSentenceServesBothSurfaces` asserts the stored sentence carries exactly
  one `{scope}`, that the `.app` render equals both `hawaiiEmployerFundedCaption`
  and the 208-char literal spelled out in the test, that
  `hawaiiPensionSplitLimitation` returns the 209-char literal, and that the two
  differ in exactly one word.

A third, `renderedLimitationsCarryNoToken`, sweeps all 51 jurisdictions in both
scopes so an unsubstituted `{scope}` can never reach a user. It is written
against the whole state list, not Hawaii, so a sentence authored in Task 4 is
covered without editing it.

## The collision sweep

**Hawaii is the only one.** This was not eyeballed. Every string literal of 60
characters or more under `RetireSmartIRA/` was extracted (Swift, with comment
lines stripped and multi-line `+` concatenations joined, plus every string in
the 51 bundled JSON files), normalized by lowercasing, collapsing whitespace and
folding `this app|this plan|this figure` to one placeholder, then grouped. Nine
duplicate groups exist in the app; eight are pre-existing unrelated UI copy
(California bracket help duplicated between `DashboardView` and
`ScenarioChartsView`, an IRMAA hint twice in `SettingsView`, an InlineHint pair,
and so on) and none is a limitation sentence. Only the Hawaii pair spans two
disclosure surfaces. A targeted per-caption `grep` of all six distinctive
fragments agreed.

Those eight duplicates are outside this feature and were not touched.

## THE THING THE BRIEF DID NOT ANTICIPATE, and it is a blocker

`StateTaxJSONStructuralEquivalenceTests.structurallyIdentical` (Phase 1 gate,
Layer B) requires that for every jurisdiction NOT on
`phase5CorrectedJurisdictions`, re-encoding the JSON-loaded config is
byte-identical to re-encoding `configs2026Legacy`. `verification` is part of
`StateTaxConfig` and is encoded. **Hawaii, North Carolina, Idaho and Vermont are
not on that set**, so putting a sentence in their `knownLimitations` fails Layer
B for four states. Massachusetts is on the set and needed nothing.

Three ways out were considered:

1. **Add the four to `phase5CorrectedJurisdictions`.** Rejected.
   `Phase5bNewYorkMilitaryTests.theLegacyMirrorWasUpdatedToo` records the
   objection in the codebase's own words: membership "flips structurallyIdentical
   into a must-diverge assertion and permanently excuses the canary from the
   check". It would also assert a tax correction that did not happen.
2. **Mirror the sentences into `configs2026Legacy`**, which is that same New York
   precedent's remedy. Rejected: it puts John's approved copy in two places,
   which is the exact duplication this feature exists to remove, and the frozen
   table is a snapshot of pre-JSON tax law, not a second home for disclosure copy.
3. **A second, narrower set with a confinement proof.** Chosen.
   `disclosureOnlyDivergentJurisdictions = [.hawaii, .northCarolina, .idaho, .vermont]`
   asserts the documents DO differ (so silently dropping the sentence fails) and
   additionally that they are byte-identical once `verification` is stripped from
   both. That is strictly stronger than membership in
   `phase5CorrectedJurisdictions`: every computed field is still under full
   byte-identity, so a decode that dropped, defaulted or reordered one still
   fails. A new `theTwoDivergenceSetsAreDisjoint` keeps a jurisdiction from
   landing on both and getting the weaker check by branch order.

**For Task 4:** of the fifteen covered jurisdictions, New York and Missouri are
on neither set. Populating their `knownLimitations` will fail Layer B until they
are added to `disclosureOnlyDivergentJurisdictions`. This is written into that
declaration's doc comment.

## The `0` sentinel: which treatment, and why

Chosen: **a computed accessor returning an optional**, `StateVerification.statedTaxYear`,
plus a doc comment on it stating what it is for. Not the doc-comment-only option.

The reasoning is the difference between advice and a guarantee. A note on
`taxYear` saying "render nothing at 0" is read once, by whoever writes Task 6,
and never again; nothing stops Task 7 or a later entry point from interpolating
`taxYear` straight into a header. `statedTaxYear` makes the sentinel an
`Optional` at the one place a renderer touches it, so the compiler asks the
question instead of the reviewer. With 36 jurisdictions at `0` today, the
failure mode is not marginal: it is "Pennsylvania tax treatment, 0" for most of
the country.

What is deliberately NOT decided here is the copy. `statedTaxYear` picks no
fallback string. What a page shows when the year is unknown is user-facing
wording and therefore John's, and it belongs with the rest of the page's copy in
Task 6, not buried in a data type. Pinned by
`theTaxYearSentinelIsAnOptionalWhereItIsRead`, which asserts nil for
`.unverified` and for the live Pennsylvania config, and `defaultTaxYear` for
Georgia.

## The three folded-in Minors

1. **Hardcoded `2026`.** Fixed at the root rather than in the message.
   `StateTaxDataLoader.defaultTaxYear` now states the year once and
   `configs2026`'s initializer reads it; the gate asserts
   `v.taxYear == StateTaxDataLoader.defaultTaxYear` and interpolates the same
   value into its message. When a 2027 directory arrives and the accessor moves,
   the gate moves with it instead of silently validating a stale year. Merely
   rewording the message would have documented the bug rather than removed it.
2. **"fails the build".** Now "fails the suite", with an added half-sentence
   saying the code compiles and the app runs either way, so the correction cannot
   be undone by someone skimming.
3. **`#expect(coveredJurisdictions.count == 15)`.** Deleted, with a comment
   saying why, so it is not re-added: set equality already fixes the count, and a
   bare number with no failure message is the thing that test exists to replace
   with a derivation.

## Red-suite state, before and against after

**Before (HEAD `7e91f90`):** one failing test,
`coveredJurisdictionsCarryCompleteVerification`, 42 issues, three per
jurisdiction for the 14 covered jurisdictions that are not Georgia.

**After:** identical. Full suite `tools/run-tests.sh`:

```
Test run with 2044 tests in 306 suites failed after 317.602 seconds with 42 issues.
XCTest: Executed 509 tests, with 0 failures (0 unexpected)
```

Exactly one distinct failing test name, and the 14 jurisdictions extracted from
the log are AZ, DC, HI, IA, ID, IN, KS, MA, MO, NC, NM, NY, UT, VT: the same set,
unchanged. No `MultiYearPerfTests` flake occurred. Swift Testing count rose from
the plan's 2,035 / 305 baseline to 2,044 / 306 with the tests added here.

## Where I disagreed, or went past the brief

- **The five caption statics survive.** The brief's framing is that
  `knownLimitations` becomes "the one place a limitation is written", but the
  plan's Global Constraints also say "do not delete ... any caption", and
  `Phase5bNorthCarolinaDecisionTests`, `Phase5bIdahoDecisionTests` and
  `Phase5bVermontDecisionTests` all still assert against them. So the sentences
  exist in two places, deliberately: config is what RENDERS, the static is the
  pinned record that the move was lossless. That is a real drift risk, so each of
  the five now opens with "NO LONGER THE RENDER SOURCE" and the loop that
  replaced the branches says the same thing. Editing a static alone now changes
  nothing a user sees.
- **DC's survivor caption stays a static, and I agree with the plan.** Beyond the
  plan's reason (it explains a control rather than a limitation), there is a
  behavioural one it does not give: it renders inside the
  `residenceUsesSurvivorDimension` branch, so moving it to `knownLimitations`
  would show it to every DC resident whether or not the survivor toggle is on
  screen, which changes what a user sees.
- **`taxYear`, `lastVerified` and `primarySources` were NOT populated**, though
  the plan's Task 3 Step 3 says to add them "alongside" the sentence. Doing so
  would have turned five of the 14 red jurisdictions green, contradicting the
  standing instruction that the red set be unchanged, and it duplicates Task 4
  Step 3, which owns sourcing and says "do not invent URLs". Task 4's worklist is
  intact.
- **`hawaiiPensionSplitLimitation` reads `surfaceDependentLimitations`, not
  `limitations`.** Handing it the whole of Hawaii's list would silently widen a
  function gated on pension income to whatever Task 4 adds to Hawaii's config,
  including sentences about brackets or deductions.
- **`LimitationScope` is a new enum, not `UnclassifiedPensionDisclosure.Scope`.**
  That type substitutes whole noun phrases mid-sentence ("this figure", "this
  plan"); Hawaii's token follows a capitalised "This", so its substitutions are
  bare nouns. Reusing it would render "This this plan does not model". The TOKEN
  constant is shared, so there is still one placeholder spelling in the codebase.
- **`scope` defaults to `.app`.** Every on-screen surface is in the app and only
  the exported briefing is not, so a default of `.plan` would be wrong at every
  call site but one. The sweep test covers both scopes regardless.
- **One risk handed forward, and it is not hypothetical.** The pension editor's
  new loop renders EVERYTHING in a state's `knownLimitations`, unfiltered, inside
  "What kind of pension is this?". Today only the five caption states are
  populated, so the screen is unchanged. After Task 4 authors sentences for
  Kansas, Missouri, New York, Utah, Georgia and Indiana, a limitation about
  brackets or standard deductions will appear under a pension picker. Flagged in
  a comment at the loop itself as well as here. It needs a way to tell the two
  kinds apart before that config lands.
- **One consequence of moving the sentence into data.** If a bundled JSON file
  ever fails to decode, `StateTaxDataLoader` falls back per state to
  `configs2026Legacy`, whose `verification` is `.unverified` with an empty
  `knownLimitations`. On that path the Hawaii disclosure silently disappears from
  both surfaces, where before it was a hardcoded literal that could not. The
  fallback trips `assertionFailure` in debug and sets `legacyFallbackFired`, and
  it is inherent to "config is the one place a limitation is written", so it is
  recorded rather than worked around.
