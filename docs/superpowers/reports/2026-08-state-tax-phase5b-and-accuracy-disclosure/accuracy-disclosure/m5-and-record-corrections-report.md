# M5 report: the modelling caveat on every state page, plus two record corrections and two follow-ups

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure`,
branch `feature/state-accuracy-disclosure`, started clean at HEAD `c23a5e0`.

Full suite, foreground, `tools/run-tests.sh`:
**2,079 Swift Testing in 306 suites passed; 509 XCTest, 0 failures. 2,588 tests, no failures.**
Baseline before this change was 2,077 + 509, so the two new tests are the whole delta and nothing
was rebaselined.

---

## 1. M5, and the shape decision

### The copy, verbatim, approved by John 2026-08-06

> State tax rules are complex, and this does not mean every unusual situation is represented.

It renders on **every** state page, under a populated limitations list as well as an empty one. That
is the opposite of how the spec framed it (section 1 offers it as an optional follow-on to the empty
state alone), and the spec now says so at that spot rather than quietly disagreeing with the code.

### THE SHAPE: a separate always-rendered element, NOT an append

The brief asked me to work out whether the sentence belongs inside `limitationsSummary(for:)` or
beside it, and to pick the shape that keeps the empty-state wording independently gated.

**Inside is ruled out by the gates, not by taste.** `limitationsSummary(for:)` is asserted by EXACT
EQUALITY against John's empty-state sentence in three separate tests:

- `emptyLimitationsDoesNotClaimCompleteness` (Pennsylvania, `==`)
- `coveredJurisdictionsWithEmptyListsClaimNothing` (every covered state shipping an empty list, `==`)
- `populatedSummaryCarriesEverySentence` (asserts a populated summary `!=` that string)

Appending the caveat would have forced all three to be rewritten, which is exactly what the brief
forbids, and it would leave one pinned string carrying two separately approved decisions: any future
edit to the caveat would have to move the pin on wording John specified character for character.

**So the shape is:**

- `StateAccuracyContent.modellingCaveatSentence`, a new constant beside `noRecordedLimitationsSentence`.
- One `Text` in `StateAccuracyView.limitationsSection`, placed AFTER the
  `if limitations.isEmpty { ... } else { ... }` branch, so it renders on both paths.
- `limitationsSummary(for:)` unchanged, byte for byte, and its doc comment now states that the
  section carries a sentence this string does not, so a future surface rendering the summary alone
  knows it is rendering an incomplete section.

### Gating

**`modellingCaveatIsPinnedAndIndependent`** pins the caveat by exact equality, sweeps it the way the
captions and the thirteen limitation sentences are swept (no em or en dash, no doubled space, no
surrounding whitespace, pure ASCII), re-asserts the empty-state sentence unchanged, and asserts that
NO jurisdiction's `limitationsSummary` contains the caveat. That last assertion is the one that keeps
the two strings from being merged later.

**`noModellingCaveatIsConditionalOnHavingLimitations`** proves the sentence reaches both a state with
limitations and a state without.

It reads source, and that is deliberate. Whether a SwiftUI `Text` sits inside or outside an `if` is a
property of a view BODY: `some View` is opaque, the branch is resolved by the framework at render
time, and nothing about "renders in both arms" is observable from a constructed `StateAccuracyView`.
What IS invariant is that an unconditional element sits outside the conditional's braces in the
source. The gate brace-matches `limitationsSection` out of `StateAccuracyView.swift`, brace-matches
the `if`/`else` inside it, and asserts the caveat marker appears exactly once and outside that span.
Same tool, and the same reason, as the existing `noMultiYearSurfacePresentsTheAccuracyPage`.

Non-vacuity is asserted rather than assumed: the parsed section must exceed 400 characters and must
still contain both `limitationsSummary(for: state)` and `ForEach(limitations`, so a rename or a
restructure fails the gate loudly instead of turning it into a no-op.

### Mutations run, and all four caught. All reverted.

| Mutation | Result |
|---|---|
| Delete the caveat `Text` from the view | FAILS: `occurrences.count 0 == 1` |
| Move it inside the empty arm | FAILS: index falls inside the conditional span |
| Move it inside the populated arm | FAILS: index falls inside the conditional span |
| Fold the caveat into `limitationsSummary` | FAILS: independence assertion, PLUS all three pre-existing exact-equality gates |

The fourth mutation is the interesting one: it demonstrates that keeping the strings apart is not
bookkeeping. Folding them fired the empty-state gates on Georgia, Iowa, Indiana and the 36 uncovered
jurisdictions at once.

### Copy NOT touched

Five config captions, DC's Swift-literal caption, the thirteen limitation sentences, the Roth
conversion statement, the three header fallbacks and the accessibility labels are all byte-identical.
No `knownDefect`, no pinned value, nothing under `RetireSmartIRATests/Baselines/`. The multi-year
affordance is still gone and `noMultiYearSurfacePresentsTheAccuracyPage` is untouched.

---

## 2. Two record corrections

### 2a. "Six captions moved into config" was wrong in SEVEN places. It is FIVE.

Ground truth, verified against `movedCaptionsAreByteIdentical` and the shipped JSON: five caption
sentences live in `verification.knownLimitations` (HI, MA, NC, ID, VT). Six approved captions exist
as `IncomeSourcesView` statics. DC's survivor-toggle caption never moved, deliberately: it explains a
CONTROL ("Turn this on only for...") rather than describing a limitation, it renders inside the
survivor-toggle branch, and in `knownLimitations` it would show to every DC resident whether or not
the toggle is on screen.

Corrected:

1. `.claude/memory/roadmap/2026-08-06-accuracy-disclosure-RESUME-HERE.md`, the Task 3 bullet.
2. `.superpowers/sdd/progress.md`, the Task 3 entry.
3. `docs/superpowers/plans/2026-08-05-per-state-accuracy-disclosure.md`, the Architecture paragraph.
4. The same plan's file table (`IncomeSourcesView.swift` row).
5. The same plan's Task 3 heading, file list and Interfaces line.
6. `docs/superpowers/specs/2026-08-05-per-state-accuracy-disclosure-design.md`, the dependency note.
7. The same spec's section 4 consolidation list and its Gate 2 description.
8. `RetireSmartIRA/StateAccuracyView.swift`, the type doc comment.
9. `RetireSmartIRATests/StateAccuracyContentTests.swift`, the file header.
10. `RetireSmartIRA/IncomeSourcesView.swift`, the unfiltered-caption comment ("while all six stored
    sentences were about pensions" was five).
11. `.superpowers/sdd/task-3-report.md`, its title and its extraction sentence.
12. `.superpowers/sdd/task-3-brief.md`, its heading and Interfaces line.
13. `.superpowers/sdd/task-1-report.md`, its forward-looking Hawaii-collision note.

Left alone as CORRECT: every reference counting the six captions that exist (`coveredJurisdictions`
group 3, the direction-word test name, `task-4-report.md`'s "five Task 3 captions and Georgia's
sentence: all six byte-identical", `whole-branch-fix-report.md`, which had already made this
correction).

### 2b. The multi-year defect location. THE BRIEF WAS HALF RIGHT, and this is the half that was not.

**There is no `calculateMultiYearStateTax` symbol anywhere in this repository.** A sweep of the
worktree and of the main checkout's `.claude/` and `docs/` trees found the name zero times, so no
document on this branch ever named it. The branch's own records already said
`ProjectionEngine.computeStateTax` correctly, in the resume file, in
`StateAccuracyContentTests`, in `ApproachComparisonView` and in the function's own doc comment.

**What WAS wrong is the line numbers, exactly as the brief warned.** Older ledgers cite
`ProjectionEngine.swift:1294-1335` (`.claude/memory/roadmap/2026-08-01-consolidated-backlog.md`,
`2026-07-13-multi-year-fix-backlog.md`) and `:1622-1634` (the Phase 2 ledger and plan). The
declaration is at `:1617` today and the `calculateStateTax` call it makes is at `:1701`; line 1294 is
now inside an unrelated spouse-balance literal.

Corrected in the living records: the consolidated backlog's I2 cross-reference now names the function
and warns off both stale ranges, and the resume file gained a standalone "THE LOCATION, STATED ONCE"
paragraph saying to grep the function name rather than chase a line. The July 2026 fix-backlog was
left as a historical record of that cycle.

---

## 3. Two follow-ups recorded, NEITHER BUILT

Both are written out in full in `.claude/memory/roadmap/2026-08-06-accuracy-disclosure-RESUME-HERE.md`
under "RECORDED, NOT FIXED", and summarised in `.claude/memory/decisions/log.md` under a new
2026-08-06 entry at the top of the file.

### A. The decode fallback

A per-state JSON decode failure falls back to a config whose `verification` is `.unverified` with
empty limitations, so the page prints "No known limitations are currently recorded for this state and
tax year." The `assertionFailure` beside it is a no-op in release.

**THE RULE, RECORDED IN CAPITALS: IT MUST NEVER FALL BACK TO "NO KNOWN LIMITATIONS." THAT WOULD TURN
A LOADING FAILURE INTO AN ACCURACY CLAIM.**

John's standard: *"the eventual runtime behavior should fail visibly rather than silently."* His
string for the correct fallback:

> State modeling details are temporarily unavailable.

Not a merge blocker, by John's judgement: these are application-owned static files bundled with the
binary rather than uncontrolled server responses, and the suite already proves every bundled
jurisdiction decodes.

### B. The claim-type behavioural matrix

Gate 3 today probes three claims by hand: the per-spouse cap, Social Security and Roth conversions.
The permanent follow-up is a matrix over claim TYPES, not more handpicked probes.

| Claim displayed | Behavioural proof needed |
|---|---|
| Brackets | Income crossing every bracket boundary |
| Standard deduction | Single, MFJ and age additions |
| Personal exemption | Filing status and per-person attribution |
| Social Security | Full, partial and phase-out behaviour |
| Pension exclusion | Age, source, amount and spouse attribution |
| IRA exclusion | Withdrawal and Roth-conversion treatment |
| Local tax | Applicable and non-applicable locations |

John's lesson, recorded alongside it: *"rendering configuration accurately proves only what the data
say, not what every calculation path does. The current branch is safe once its entry points are
restricted to paths that have been verified; broader behavioural completeness can follow."*

---

## 4. Constraints checked

- **No non-ASCII anywhere.** Every added line in the tracked diff and every touched untracked file
  under `.superpowers/sdd/` was swept; zero hits. The commit message is ASCII too.
- **Full suite in the foreground** via `tools/run-tests.sh`, never `xcodebuild`, never backgrounded.
  Green, and no known-flake re-run was needed.
- **Untouched:** every `knownDefect`, every pinned value, everything under
  `RetireSmartIRATests/Baselines/`, the multi-year affordance, and
  `noMultiYearSurfacePresentsTheAccuracyPage`.

## 5. Concerns handed forward

1. **The new gate reads source, and source gates rot differently from behavioural ones.** If
   `limitationsSection` is restructured, the gate fails loudly rather than silently, which is the
   right failure mode, but the next person must fix it deliberately rather than delete it. The
   failure message says so.
2. **The caveat is now the seventh string on the page whose exact wording is John's.** Nothing on the
   page composes it, but the page is getting close to the point where a single approved-copy manifest
   would beat a growing set of individually pinned constants.
3. **Tasks 3 through 8 still have no independent review.** Unchanged by this work and still the
   branch's largest open risk. This change touched Task 6's view and content, so it inherits that gap.
