# Task 2 report: `taxYear` on `StateVerification`, and the completeness gate

**Status:** complete. **The suite ends RED by design.** One suite fails,
`StateAccuracyContentTests`, with 42 expectation failures across 14
jurisdictions. That failure list is Task 4's worklist and is reproduced below.

**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure`
**Branch:** `feature/state-accuracy-disclosure`, parent HEAD `4791323`, clean at start.

---

## 1. The failure list, for Task 4

Fourteen jurisdictions fail all three assertions. Georgia passes all three and
is the only covered jurisdiction that does. Every row needs the same three
things added to its `verification` block in
`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-XX.json`:
`"taxYear": 2026`, a non-empty `"lastVerified"`, and at least one
`"primarySources"` entry containing `https://`.

| # | State | `taxYear` | `lastVerified` | HTTPS source | Config file |
|---|---|---|---|---|---|
| 1 | AZ Arizona | missing | missing | missing | `statetax-2026-AZ.json` |
| 2 | DC District of Columbia | missing | missing | missing | `statetax-2026-DC.json` |
| 3 | HI Hawaii | missing | missing | missing | `statetax-2026-HI.json` |
| 4 | IA Iowa | missing | missing | missing | `statetax-2026-IA.json` |
| 5 | ID Idaho | missing | missing | missing | `statetax-2026-ID.json` |
| 6 | IN Indiana | missing | missing | missing | `statetax-2026-IN.json` |
| 7 | KS Kansas | missing | missing | missing | `statetax-2026-KS.json` |
| 8 | MA Massachusetts | missing | missing | missing | `statetax-2026-MA.json` |
| 9 | MO Missouri | missing | missing | missing | `statetax-2026-MO.json` |
| 10 | NC North Carolina | missing | missing | missing | `statetax-2026-NC.json` |
| 11 | NM New Mexico | missing | missing | missing | `statetax-2026-NM.json` |
| 12 | NY New York | missing | missing | missing | `statetax-2026-NY.json` |
| 13 | UT Utah | missing | missing | missing | `statetax-2026-UT.json` |
| 14 | VT Vermont | missing | missing | missing | `statetax-2026-VT.json` |

Not on the list: **GA Georgia**, already populated
(`taxYear` 2026, `lastVerified` 2026-08-04, two HTTPS sources).

14 states x 3 assertions = 42 failures. That is the whole of the red.

**Where Task 4 reads the state names.** The wrapper's condensed summary prints
the failing expression only, so the fourteen abbreviations appear in the FULL
log the wrapper keeps, not in the six-line summary. To regenerate the list:

```bash
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh StateAccuracyContentTests
# then, against the "Full log kept at:" path it prints:
grep -oE "\b[A-Z]{2} (verification\.taxYear must|has no lastVerified|has no HTTPS)" <log> \
  | awk '{print $1}' | sort -u
```

Sources for Task 4 come from each state's golden fixture `sourceURL` fields, per
the plan. Do not invent URLs.

---

## 2. How `taxYear` was shaped, and how it decodes

`RetireSmartIRA/StateTaxVerification.swift`.

- `let taxYear: Int`, declared FIRST in the struct so it leads the provenance
  block. Declaration order sets the synthesized memberwise initializer's
  argument order, so Swift construction sites pass `taxYear:` first.
- **No default in the memberwise initializer.** Every Swift construction site
  must state a year. There are four, all updated: `.unverified` and three test
  fixtures.
- `.unverified` carries `taxYear: 0`.
- **Decoding is lenient for this one key only:**
  `decodeIfPresent(Int.self, forKey: .taxYear) ?? 0`. The other four keys stay
  mandatory, exactly as synthesized decoding had them.

**Why the decode has to be lenient.** Fifty of the fifty-one bundled 2026 files
were generated before this field existed. Synthesized decoding would make
`taxYear` mandatory, all fifty would throw, and `StateTaxDataLoader` converts a
per-state decode failure into a fallback to the frozen legacy table plus, in
debug builds, an `assertionFailure` that traps the test process. A strict decode
here would not have produced a useful red; it would have produced a trap.

**Mechanical notes.**

- `init(from:)` is written in an **extension**, not the struct body, so the
  memberwise initializer is still synthesized. Defining it in the body would
  have suppressed the memberwise init and required hand-writing it.
- `CodingKeys` is declared explicitly rather than relying on synthesis, since
  the extension refers to it.
- `encode(to:)` stays synthesized and now emits `taxYear` for every config.
  Checked against the three places that re-encode configs and compare:
  `StateTaxJSONStructuralEquivalenceTests.structurallyIdentical` compares JSON
  against legacy, and both sides now carry `taxYear` 0 for the fifty
  unpopulated states, so they stay byte-identical; Georgia is already in
  `phase5CorrectedJurisdictions` and is required to diverge, which it still
  does. `StateTaxJSONFileKeyCompletenessTests` checks TOP-LEVEL keys only, so a
  new key nested inside `verification` does not trip it. Full suite confirms
  all three still pass.

**Georgia.** `"taxYear" : 2026` added to its `verification` block, placed last
to keep the file in the `[.prettyPrinted, .sortedKeys]` order the generator
writes. Re-parsed to confirm it is still valid JSON.

---

## 3. Why `coveredJurisdictions` holds these fifteen

`RetireSmartIRA/StateAccuracyContent.swift`, a new file. The Xcode project uses
`PBXFileSystemSynchronizedRootGroup`, so no `project.pbxproj` edit was needed;
verified by the file compiling into both targets.

The brief handed me the fifteen. I verified them rather than taking them, and
the set turns out to be **exactly** the union of three groups that already exist
in the test target:

1. **Phase 5 corrected jurisdictions** (9): KS, IA, NM, GA, UT, IN, MA, AZ, DC.
   `StateTaxJSONStructuralEquivalenceTests.phase5CorrectedJurisdictions`.
2. **`knownButUnpinned` catalogue states** (9): AZ, MO, KS, MA, HI, NC, ID, DC,
   NY. Thirteen entries across nine states.
3. **Pension-editor caption states** (6): HI, MA, DC, NC, ID, VT. These must be
   covered because Task 3 moves those captions into
   `verification.knownLimitations`, and a caption cannot render from a config
   the gate does not cover.

Union = 15, matching the brief exactly. Vermont enters only through group 3.
Georgia, Iowa and Indiana enter only through group 1.

I added a second test, `coveredSetMatchesItsStatedRationale`, that computes that
union from the live catalogue and asserts equality. It PASSES. It exists so that
adding or removing a jurisdiction has to be deliberate rather than a drift, and
so the rationale in the comment is checked rather than asserted.

**Why the set is not all fifty-one, stated in the code comment:** twenty-one
further states carry pinned defects and are deliberately absent (AL, AR, CO, CT,
DE, KY, LA, MD, ME, MI, MN, NE, OH, OK, OR, RI, SC, VA, WA, WI, WV). Membership
is a statement about what this release authored, NOT a statement that the states
outside it are clean. The gate's doc comment says so explicitly, so a future
reader cannot take a green run as a clean bill of health for the other
thirty-six. Widening is one declaration; the gate reads the set and needs no
change.

---

## 4. What enforces this, stated accurately

The configurations are JSON. **Nothing here is a compile-time guarantee, and no
comment I wrote claims one.** Concretely:

- A missing `taxYear` decodes to `0` and fails at TEST time.
- A missing `lastVerified` or `primarySources` throws at DECODE time.
- Neither is a Swift compile error, and neither can be made into one while the
  data ships as JSON.

The `#expect` in `coveredJurisdictionsCarryCompleteVerification` is the only
gate on completeness. I also corrected a pre-existing doc comment on
`StateVerification` that read "Required by schema on every state file. A
jurisdiction cannot be added without a primary source and a verification date."
That was already untrue when I arrived: fifty of fifty-one configs ship with an
empty `lastVerified`. Leaving a false enforcement claim directly above an
accurate one seemed worse than fixing it. Comment only, no behavior change.

---

## 5. The three folded-in review findings

All in `RetireSmartIRATests/StateAccuracyContentTests.swift`. No caption wording
was touched.

**(a) Doc comment claimed a DC direction that nothing pins.** The comment read
"Hawaii and DC run toward over-taxation". DC's caption carries no direction word
at all; it is a scoping instruction ("Turn this on only for a pension paid to
you as someone else's survivor or beneficiary"). Rewritten to say Hawaii runs
toward over-taxation and Massachusetts toward under-taxation, that those two are
the load-bearing pair, and that the other four say nothing about direction, DC's
in particular being a scoping instruction with no direction for a test to pin.

**(b) Overstated test name.** `"All six pension-editor captions are dash-free
and keep their direction"` became `"All six pension-editor captions are
dash-free, and the Hawaii and Massachusetts directions stay opposed"`. The dash
and whitespace sweep does cover six; the direction pin covers two, and the name
now says which.

**(c) Redundant Hawaii negative.** Removed
`#expect(!IncomeSourcesView.hawaiiEmployerFundedCaption.contains("understated"))`.
Hawaii and Massachusetts now carry one positive pin each, symmetrically. A
comment records that the negative was removed and why, so it is not
reintroduced as a perceived gap. Note the asymmetry was the finding: the
negative is not logically implied by the positive, but the case it guards
against (a single-direction sentence containing both words) is contrived, and
Massachusetts never carried its mirror image, so the asymmetry read as
meaningful when it was not.

---

## 6. Test command and result

Scoped run:

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh StateAccuracyContentTests
```

```
Swift Testing:  Test run with 4 tests in 1 suite failed
XCTest:         Executed 0 tests, with 0 failures (0 unexpected)
FAILING SUITES:
  StateAccuracyContentTests
```

Full suite, foreground, to prove nothing else moved:

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh
```

```
Swift Testing:  Test run with 2039 tests in 306 suites failed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)
FAILING SUITES:
  StateAccuracyContentTests
```

`StateAccuracyContentTests` is the ONLY failing suite in the whole run, and its
only failing test is the new completeness gate. The other three tests in the
suite pass, including the new rationale test. `MultiYearPerfTests` did not fail,
so the known wall-clock flake is not in play here.

Baseline comparison: the plan's stated baseline is 2,035 Swift Testing in 305
suites plus 509 XCTest. Task 1 added the suite (305 to 306) with two tests; this
task added two more, giving 2,039. XCTest is unchanged at 509 with zero
failures.

---

## 7. Where I disagreed with the brief

**1. The plan's provenance claim for the covered set is wrong.** The brief's
code comment said "Every member is traceable to a pinned defect or a
knownButUnpinned entry." Georgia, Iowa and Indiana have neither: zero
`knownDefect` blocks in their golden fixtures and no `knownButUnpinned` entry.
They are in the set because they are Phase 5 corrected jurisdictions. Vermont
has pinned defects but is in the set because of its caption. I wrote the
accurate three-group rule instead and added a passing test that checks it. This
is the same class of error as folded-in finding (a): a comment claiming more
than anything pins.

**2. "No default so a config cannot omit it silently" does not do what it
says.** The brief's rationale for omitting a memberwise default is that a config
cannot then omit `taxYear`. It cannot: configs are JSON and never touch the
memberwise initializer, and the JSON path defaults to `0` by design. I kept the
no-default behavior, because requiring every Swift construction site to state a
year is worth having on its own, but the doc comment states the real reason
rather than the stated one.

**3. Plan File Structure table says `taxYear` arrives in Task 5.** Line 34 of
the plan reads "Gains `taxYear` in Task 5", while Task 2 is where it is
specified and where I added it. Cosmetic inconsistency in the plan document,
flagged so a later reader does not go looking in Task 5. I did not edit the
plan.

**4. The type-name correction held up.** The six captions are `IncomeSourcesView`
statics, not `PlanClassificationChoice`. Verified before relying on either name.

**5. Three test fixtures outside my task file needed touching.**
`StateTaxCodableRoundTripTests.swift` has three `StateVerification(...)`
construction sites that the no-default memberwise initializer breaks. Each
gained `taxYear: 2026`. These are round-trip fixtures, not baselines and not
pinned values, and the change strengthens them: `verificationRoundTrips`
compares whole values, so it now proves `taxYear` survives encode and decode. I
also added one assertion that `.unverified.taxYear == 0`. Nothing under
`RetireSmartIRATests/Baselines/` was touched, no `knownDefect`, no `tier`, no
`expectedStateTax`.

---

## 8. Files changed

| File | Change |
|---|---|
| `RetireSmartIRA/StateTaxVerification.swift` | `taxYear: Int` added, lenient decode in an extension, explicit `CodingKeys`, `.unverified` gets `taxYear: 0`, struct doc comment corrected |
| `RetireSmartIRA/StateAccuracyContent.swift` | NEW. `coveredJurisdictions` and its rationale |
| `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json` | `"taxYear" : 2026` |
| `RetireSmartIRATests/StateAccuracyContentTests.swift` | Gate 4, rationale test, three folded-in fixes |
| `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift` | Three fixtures gain `taxYear: 2026`, one new assertion |

`IncomeSourcesView.swift` was NOT touched. Its seventeen pre-existing em dashes
are untouched, and no em dash or en dash was added anywhere: verified by
scanning every changed file, including this report.
