# Task 3b report: the unclassified-pension disclosure stops being New York only

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`, branch
`feature/state-tax-phase5b`, verified clean at HEAD `93d91c0` before the first edit.

## What shipped

Both disclosure surfaces now read the relevant jurisdiction's own config. New York's copy is unchanged
to the character. Kansas, correct since Task 3 but silent, now warns on both surfaces.

## The config field, and why it is shaped this way

`RetirementIncomeExemptions.unclassifiedPensionDisclosure: String?`, declared immediately after
`perSourceExemptions` in `RetireSmartIRA/StateTaxData.swift`, encoded with `encodeIfPresent` and
decoded with `decodeIfPresent` and no `??` fallback in `RetireSmartIRA/StateTaxCodable.swift`.

- **On `RetirementIncomeExemptions`, not on `StateTaxConfig`.** The field only means anything in the
  presence of `perSourceExemptions`, and the sweep test asserts the two travel together. Putting them
  in different types would have made that pairing a cross-object invariant instead of two adjacent
  lines.
- **`String?`, not `[String]`.** One sentence per jurisdiction was John's decision. An array would
  have quietly permitted zero, which is the exact failure mode this task exists to close.
- **`encodeIfPresent`, so the key is OMITTED rather than written as `null`.** This matches how
  `perSourceExemptions` handles the empty case one line above, and it is what keeps the change to a
  two-file JSON diff instead of a 51-file regeneration. `disclosureRoundTrips` asserts the key is
  absent from a bare encode, so a later refactor to plain `encode` fails a test rather than producing
  a 49-file diff nobody asked for.
- **Additive.** `absentKeyDecodesToNil` decodes a minimal config with no such key and asserts `nil`.
  The 49 jurisdictions that set nothing decode exactly as before and neither surface fires for them.

## The token

`UnclassifiedPensionDisclosure.scopeToken` is `{scope}`. Braces cannot occur in the surrounding
English, so a reviewer reading the JSON sees a placeholder, and a substitution failure surfaces as
visible punctuation in the UI rather than as a plausible sentence. `scopeTokenIsNotProse` pins that it
is brace-delimited; `everyShippedSentenceIsWellFormed` pins that every shipped sentence carries it
exactly once, so a future jurisdiction cannot ship a sentence that reads identically on a screen
showing a figure and in a document describing a plan.

The two substitutions, `this figure` and `this plan`, live on `UnclassifiedPensionDisclosure.Scope`
and reproduce the two hardcoded literals exactly.

## How New York's copy was proven byte-identical

Not by reading it. The two strings were extracted MECHANICALLY from the pre-change sources at HEAD
`93d91c0` with a regex over `git show HEAD:<file>`, printed with `repr`, and measured: 250 characters
for State Comparison, 248 for the CPA briefing, first divergence at character 173, no em dash in
either. Those exact strings are the two literals in
`Phase5bUnclassifiedPensionDisclosureTests.shipped*TextNY`, and
`newYorkCopyIsByteIdenticalToWhatShipped` asserts full `==` against them on both surfaces.
`newYorkBriefingArrayIsByteIdentical` additionally pins the briefing's array to exactly
`[thatOneString]`, so an extra element or a dropped one fails too.

**The test was then proven capable of catching drift, not merely observed to pass.** Mutation 1
inserted ONE extra space into New York's JSON sentence (`$20,000 pension  exclusion`). Both surfaces
failed with a diff naming the character. Reverted.

I also pre-verified the composition in Python against the extracted bytes before ever running a build:
`lead + " " + sentence.replace("{scope}", word)` reproduced both shipped strings at 250 and 248
characters. The Swift test is the standing guard; the Python check only shortened the loop.

## Preserving the viewed-state versus residence asymmetry

They are still two functions with two different parameters, and neither can be called with the other's
input:

- `StateComparisonPresentation.showsUnclassifiedPensionLimitation(viewedState:hasUnclassifiedPension:)`
  and its text companion take a **viewed state** and have no residence parameter at all. The view
  passes `item.state`. The asymmetry is structural: there is no residence in scope to gate on by
  accident.
- `MultiYearCPABriefing.unclassifiedPensionLimitation(residenceState:hasUnclassifiedPension:)` takes a
  **residence**. `MultiYearPlanView` passes `dataManager.selectedState`.

Both doc comments now state the asymmetry and what collapsing it would break, in each direction.
`viewedStateAndResidenceGatesStayDistinct` pins it behaviourally: a household in a state with no rules
still gets the warning when they open New York's or Kansas's column in State Comparison, and gets no
such sentence in their own CPA briefing.

I deliberately did NOT introduce a shared predicate over "the state". The shared code is only
`UnclassifiedPensionDisclosure.text(for:scope:)`, which takes the state as an argument and takes no
position on which state that should be. That is the seam that lets the two surfaces stay different.

## Tests added

New file `RetireSmartIRATests/Phase5bUnclassifiedPensionDisclosureTests.swift`, 14 tests in 1 suite.

| Test | What it would catch |
| --- | --- |
| `newYorkCopyIsByteIdenticalToWhatShipped` | Any drift, by one character, in live New York copy on either surface. The regression guard for the whole change. |
| `newYorkBriefingArrayIsByteIdentical` | The briefing emitting an extra, missing, or altered element. |
| `kansasFiresOnStateComparison` | Kansas silently getting no on-screen warning: the reported defect. Also that State Comparison uses "this figure". |
| `kansasFiresOnCPABriefing` | The same defect in the CPA briefing, and that the briefing uses "this plan". |
| `kansasSentenceReachesTheRenderedBriefingHTML` | A sentence that exists in the array but never reaches the rendered PDF. |
| `stateWithoutPerSourceRulesFiresOnNeitherSurface` (CA, PA, TX, NJ) | A gate that fires for jurisdictions with no rule to go unused. Asserts the premise (no rules) rather than assuming it. |
| `classifiedPensionFiresOnNeitherSurface` (NY, KS) | Losing the classification half of the gate: warning a user who already did the thing. |
| `viewedStateAndResidenceGatesStayDistinct` | Collapsing the two surfaces onto one gate, in either direction. |
| `rulesAndDisclosuresStayInLockstep` | **Tasks 4 through 9 shipping a rule and forgetting the sentence**, and the reverse. |
| `everyShippedSentenceIsWellFormed` | A sentence with no token or two, not naming its jurisdiction, repeating the lead sentence, ending without a period, or containing an em dash. |
| `scopeTokenIsNotProse` | A token respelled into something that could collide with prose. |
| `substitutionTouchesOnlyTheToken` | An unsubstituted `{scope}` reaching a user, or substitution damaging the rest of the sentence. |
| `absentKeyDecodesToNil` | The field becoming non-additive. |
| `disclosureRoundTrips` | Loss across encode/decode, and the key being written as `null` for the 49 jurisdictions that have none. |

`RetireSmartIRATests/Phase3bPresentationTests.swift`: the seven pre-existing tests were updated to the
renamed API. Their New York substance is unchanged, since New York's behaviour must not move. Two
were re-pointed from `.newYork`/`false` to `.california` so they still test "a state that should not
fire" now that the gate is data-driven. `briefingModel` lost its `private` so the new file renders
through the same fixture rather than growing a second copy free to drift.

### Mutation testing: each guard proven to fail

1. One extra space in New York's JSON sentence: 3 failures across both byte-identity tests. Reverted.
2. Kansas's disclosure removed while keeping its rule (exactly what a careless Task 4 would do):
   6 failures, including the sweep reporting `["KS", "NY"] == ["NY"]`. Reverted.
3. State Comparison switched to the briefing's scope word, i.e. the two surfaces collapsed onto one:
   3 failures. Reverted.

## One thing the brief got wrong

**The brief states twice that "nothing tests either surface today." That is false.**
`RetireSmartIRATests/Phase3bPresentationTests.swift` carried seven tests over both surfaces before
this task (three on State Comparison, four on the CPA briefing, including one that renders the HTML).

The brief's underlying point survives and is worth stating precisely, because it is the more useful
lesson: all seven passed while Kansas got no warning at all. They asserted only that New York fires,
that California does not, and that the text is `!isEmpty`. Non-emptiness is what left the copy
unpinned, and hardcoding New York into the TESTS as well as the code is what let the gap survive
review. The defect was not absent coverage; it was coverage written to the implementation's own shape.
That is recorded in the new file's header so the next reader draws the right conclusion.

## One thing not in the brief that the code forced

The brief said no golden fixture should need to change, and none did. But **`RetireSmartIRA/StateTaxData.swift`'s frozen `configs2026Legacy` table did**, for New York only.

Layer B of the Phase 1 gate (`StateTaxJSONEquivalenceTests.structurallyIdentical`) re-encodes each
jurisdiction's JSON-loaded config and its legacy-table config and requires them byte-identical, except
for the six jurisdictions on `phase5CorrectedJurisdictions`. New York is not on that list, so adding a
field to its JSON alone failed the gate on the first full run (3090 bytes against 2881).

I added the same sentence to New York's legacy entry. This follows the exact precedent set when Phase
3b Task 4 added New York's `perSourceExemptions`, which is mirrored in that table for the same reason.
Kansas needs no counterpart: it IS on `phase5CorrectedJurisdictions` and is REQUIRED to diverge.

This is not a pin and not a correction. It is also not merely ceremonial: `configs2026Legacy` is the
live fallback `StateTaxData.config(for:)` uses when the bundled JSON fails to load, so omitting it
would mean a New York user in that failure path silently loses the warning. Flagging it here because
"the frozen legacy table moved" is the kind of thing a reviewer should see stated rather than discover.

No golden fixture changed. No `observedToday`, `tier`, or `expectedStateTax` was touched.
`RetireSmartIRATests/Baselines/` is untouched. `git status` shows only the two JSON configs, six Swift
sources, one existing test file, and the new test file.

## Copy

Shipped verbatim as approved. I have no wording objection to either sentence. One observation, offered
and not acted on: Kansas's sentence says the state "exempts ... with no dollar cap, but {scope} taxes
your pension in full," which is a sharper contrast than New York's "applies the standard $20,000
pension exclusion" because Kansas grants nothing at all without classification. That is accurate, and
the sharper reading is arguably the point. Unchanged.

## Full suite

```
tools/run-tests.sh
```
Foreground, `timeout` 600000, not backgrounded, `xcodebuild` never called directly.

Final run:
```
Swift Testing:  Test run with 1924 tests in 297 suites failed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)
FAILING SUITES: MultiYearPerfTests
  MultiYearPerfTests PASSED in isolation.
  Treating the full-suite failure as the known flake, NOT a regression.
```

**Stating it explicitly as required: the only failing suite was `MultiYearPerfTests`, the known
pre-existing wall-clock flake. The wrapper re-ran it in isolation and it passed. This is not a
regression.** Corroborating evidence: the immediately preceding full run, on code differing only by
two comment edits and one reverted mutation, was `1924 tests in 297 suites passed` plus 509 XCTest,
`PASS. 2433 test(s) ran, no failures`, with no flake at all.

Against the 1,910 / 296 / 509 baseline: +14 Swift Testing tests, +1 suite, XCTest unchanged.

## Carry forward for Task 10

**Every remaining Phase 5b jurisdiction task (4 MA, 5 HI, 6 AZ, 7 NC, 8 ID, 9 VT and DC) now owes a
disclosure sentence in its config alongside its rule.** `rulesAndDisclosuresStayInLockstep` enforces it
in both directions and will fail the suite if one is skipped, so Task 10's verification is to confirm
that test still passes with every jurisdiction present, and that each new sentence was reviewed by John
before it shipped. `everyShippedSentenceIsWellFormed` covers the mechanical half of that review.

Note for whoever writes those sentences: each also needs a matching legacy-table entry ONLY if its
jurisdiction is absent from `phase5CorrectedJurisdictions`. The Phase 5b jurisdictions being corrected
will all be on that list, so they should need no legacy edit. Layer B will say so either way.
