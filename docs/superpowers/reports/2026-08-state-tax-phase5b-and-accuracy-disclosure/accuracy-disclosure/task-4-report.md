# Task 4 report: the remaining limitation sentences, and the suite turns green

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure`,
branch `feature/state-accuracy-disclosure`, started clean at HEAD `987f653`,
committed as `2d863ee`.

**Status: complete, suite GREEN.** Task 2's deliberate RED (42 issues across 14
jurisdictions) is resolved. No `knownDefect`, no `tier`, no `expectedStateTax`
and nothing under `RetireSmartIRATests/Baselines/` was touched.

---

## 1. THIRTEEN NEW SENTENCES, ALL APPROVED BY JOHN ON 2026-08-06

Every sentence below was new when this report was written and was APPROVED AS
WRITTEN by John on 2026-08-06. Nothing here is open. The five sentences Task
3 moved into config (Hawaii, Massachusetts, North Carolina, Idaho, Vermont) and
Georgia's existing one carry their earlier approval and are NOT reproduced here;
none was reworded.

Grouped by state. Each carries the direction word, as the Kansas model does.

### Arizona (2)

> Arizona may not tax Railroad Retirement benefits at all, but this app gives them only Arizona's $2,500 government pension allowance, so if that reading is right your Arizona state tax may be **overstated**.

> Arizona allows each spouse a separate $2,500 government pension allowance, but this app applies a single $2,500 allowance to the household, so if both of you receive a qualifying pension your Arizona state tax may be **overstated**.

### District of Columbia (2)

> The District of Columbia excludes a DC or federal government survivor annuity from tax once the survivor is 62 or older, but this app applies that exclusion only to a pension you have marked as a survivor benefit, so if you saved your pension before that question existed your District of Columbia state tax may be **overstated** until you re-open the pension and answer it.

> This app asks whether a pension is a survivor annuity only of District of Columbia residents, so if you live elsewhere and compare states, the District's column may be **overstated** for a survivor annuity.

### Kansas (1)

> Kansas exempts federal retirement benefits including a Thrift Savings Plan, but this app applies that exemption only to a defined benefit pension, so if your federal retirement savings are in a TSP your Kansas state tax may be **overstated**.

### Massachusetts (1)

> Massachusetts also excludes a contributory federal government pension and Railroad Retirement benefits from state tax, but this app taxes both in full, so if you receive either your Massachusetts state tax may be **overstated**.

### Missouri (2)

> Missouri caps its public pension exemption at each person's own maximum Social Security benefit, reduced by any Social Security deduction that person claims, but this app exempts a public pension in full with no cap, so your Missouri state tax may be **understated**.

> Missouri limits its private pension, IRA and 401(k) exemption to $6,000 per taxpayer and phases it out above $25,000 of Missouri adjusted gross income ($32,000 married filing combined), but this app exempts that income in full, so your Missouri state tax may be **understated**.

### North Carolina (1)

> North Carolina exempts military retired pay in full, and this app applies that exemption to money entered as military retirement income but not to a pension classified as military retired pay, so entering it as a pension may **overstate** your North Carolina state tax.

### New Mexico (1)

> New Mexico gives each filer aged 65 or older an income-graduated exemption of up to $8,000 on Schedule PIT-ADJ, but this app does not apply it, so if you are 65 or older your New Mexico state tax may be **overstated**.

### New York (1)

> New York may not tax Railroad Retirement benefits at all, but this app gives them only New York's $20,000 pension and annuity exclusion, so if that reading is right your New York state tax may be **overstated**.

### Utah (2)

> Utah reduces tax by a taxpayer tax credit worth up to 6% of your federal standard deduction, phased out above $18,213 of income ($36,426 if married filing jointly), but this app does not apply it, so your Utah state tax may be **overstated**.

> Utah also gives a $450 retirement credit to each filer born on or before December 31, 1952, but this app does not apply it, so if you qualify your Utah state tax may be **overstated**.

### States that got metadata but NO sentence

**Hawaii, Idaho, Vermont** already carry the caption Task 3 moved, and it states
the same mechanism their pinned defects and catalogue entries record. Adding a
second sentence would have restated approved copy.

**Iowa and Indiana** have zero pinned `knownDefect` blocks in their golden
fixtures and zero `knownButUnpinned` entries. They are covered because they were
Phase 5 corrections, so they carry provenance and an empty limitation list. Task
6's empty-state wording is what a user sees for them, which is why that wording
matters more than it looks.

### The two directions, counted

Eleven **overstated** (the app over-taxes), two **understated** (Missouri, both).
Missouri is the only under-taxation case in this batch, which matches the
catalogue: its public-pension entry and its tier 1 private-pension defect both
run that way. Massachusetts's under-taxation case is the noncontributory one,
already covered by the caption Task 3 moved.

---

## 2. What each sentence was translated from

Nothing was researched. Every row cites the entry it came from.

| State | Source in the repo | Direction stated there |
|---|---|---|
| AZ railroad | `knownButUnpinned` AZ #2, "NO AUTHORITY IN THE FIXTURE" | UNDER-exemption, app over-taxes |
| AZ per-spouse cap | pinned `knownDefect` on the AZ MFJ Line 29a case, tier2, `observedToday` 1350.0 | overstates by $37.50 at that shape |
| DC pre-existing rows | `knownButUnpinned` DC #1 | "over-taxation, which is the safe one" |
| DC non-resident | `knownButUnpinned` DC #2, THE NON-RESIDENT CASE | "over-statement of DC" |
| KS TSP | `knownButUnpinned` KS | "UNDER-exemption, i.e. the app over-taxes" |
| MA federal civilian and railroad | `knownButUnpinned` MA #2 | "UNDER-exemption, i.e. the app over-taxes" |
| MO public pension | `knownButUnpinned` MO | correct $6,157.41 against engine $0.00 |
| MO private pension | pinned `knownDefect`, tier1, on the MO private IRA case | `.full` against MO-A Section B's $6,000 cap |
| NC military two paths | `knownButUnpinned` NC #2 | "OVER-taxation by the full amount" |
| NM PIT-ADJ | pinned `knownDefect` x2, tier4, both NM age-exemption cases | exemption "entirely unmodeled" |
| NY railroad | `knownButUnpinned` NY | "UNDER-exemption, i.e. the app over-taxes" |
| UT taxpayer tax credit | pinned `knownDefect` x4, tier4 | credit "entirely unmodeled" |
| UT retirement credit | same, the two age-gated cases | credit "entirely unmodeled" |

Figures quoted in the copy ($2,500, $6,000, $25,000/$32,000, $8,000, $20,000,
$18,213/$36,426, $450, December 31 1952) are all lifted from those entries or
from the fixture prose they quote. No figure was computed and none was sourced
from outside the repository.

### The one entry I deliberately did NOT author, and why

**Arizona's `knownButUnpinned` #1**, the unclassified-pension $2,500 allowance.
The brief says to translate every entry. This one is already disclosed by a
different approved mechanism: `statetax-2026-AZ.json` ships

> "Arizona excludes U.S. military retired pay in full and allows up to $2,500 for a federal, Arizona state or local government pension, but {scope} applies the $2,500 allowance to any pension until it is classified."

as `unclassifiedPensionDisclosure`. That is the same mechanism, in the same
direction, and it is gated on exactly the population the defect affects: a user
with an unclassified pension. Once classified, Arizona's shipped per-source
rules are correct and there is nothing to disclose. A `knownLimitations`
sentence renders UNCONDITIONALLY, so authoring one would have shown every
Arizona user a warning about a state they may already have answered for, and
would have put near-identical approved copy in two places, which is the exact
duplication this feature exists to remove.

The same reasoning does NOT excuse Kansas, Massachusetts, New York or DC, all of
which also ship an `unclassifiedPensionDisclosure`. Each of their sentences is
about a pension that IS correctly classified and still taxed wrongly, which
their disclosures explicitly do not cover. DC's catalogue entry makes the point
directly: "Both disclosure surfaces gate on the pension being UNCLASSIFIED ...
This user is fully classified, so State Comparison shows nothing."

---

## 3. The unfiltered-caption defect: what I shipped and why

### First, a correction to the brief's framing

The brief says the defect appears "the moment you add a bracket, deduction or
credit limitation", implying nothing stored today triggers it. Task 3's report
says the same. I checked Georgia before tagging it, because Georgia is already
populated and already renders under the pension picker, and its sentence reads:

> "Georgia's standard deduction rises again to $70,000 for the retirement-income exclusion in TY2027; this config is TY2026 only and does not encode that increase."

That looks like a standard-deduction sentence, and I was about to tag it as one
and report that Georgia had already shipped the defect. It has not.
`statetax-2026-GA.json` sets `stateDeduction` to a fixed $15,000/$30,000 and
`pensionExemption`/`iraWithdrawalExemption` to `.partial(65000)`. The $70,000 is
the TY2027 **retirement-income exclusion**, not the standard deduction; the
sentence's wording is loose but its mechanism is a retirement exclusion cap. So
Georgia is a pension-topic sentence, correctly placed today, and **the defect is
created entirely by this task's own copy**, specifically Utah's two credits and
New Mexico's age-65 exemption. I did not reword Georgia.

That changed the design: my first draft had a four-case topic enum including
`.deduction`, and after this check no shipped sentence needed it, so it is gone.

### The fix

`knownLimitations` changes from `[String]` to `[StateLimitation]`, a struct of
`text` plus `topic`. `LimitationTopic` has three cases, each earned by a
sentence that ships: `.pension`, `.credit` (Utah x2), `.exemption` (New Mexico).

- `StateAccuracyContent.limitations(for:scope:)` is unchanged in signature and
  returns every sentence. The per-state accuracy page (Task 6) uses it.
- `StateAccuracyContent.pensionLimitations(for:scope:)` is new and returns the
  `.pension` subset. The pension editor uses it.
- `surfaceDependentLimitations(for:scope:)` is untouched; it filters on the
  scope token and is still the CPA briefing's narrow accessor.

Adding a jurisdiction is still a pure data change. The filter reads each
sentence's own topic and `IncomeSourcesView` names no state.

### Why a topic and not the alternatives

- **A boolean like `showsInPensionEditor`** puts a SCREEN inside the tax data,
  and this sentence is already read by three surfaces with a fourth coming in
  Task 7. A topic describes the mechanism and lets each surface decide.
- **Classifying in Swift by matching sentence text** was rejected outright; it
  is the drift the whole feature exists to remove.
- **A second JSON array** would put the two kinds of sentence in two places,
  which is the duplication this feature exists to remove.
- **Grouping the accuracy page by topic** is now available for free in Task 6,
  which is a real second use rather than a hypothetical one.

### The decode is lenient in one direction, deliberately

`StateLimitation.init(from:)` accepts a bare JSON string and resolves it to
`.pension`. That is not a second supported shape and no shipped file uses it.
It exists because a decode THROW is not a loud failure in this codebase: it is
converted by `StateTaxDataLoader` into a per-state fallback to the frozen legacy
table, whose `verification` is `.unverified` with an empty list, so a mistyped
entry would silently delete that state's disclosure in release and trap the
process in debug. Between "a sentence renders under a slightly wrong heading"
and "the sentence disappears", the fallback picks the first, which is the safe
direction in this program.

`everyShippedLimitationIsTaggedInTheFileItself` reads the 51 files off disk and
fails if any element ships as a bare string, so the fallback cannot become the
convention. Decoding through `StateVerification` could not tell the two forms
apart, which is the same reason Layer C inspects raw keys.

### One placement I am not fully happy with, stated rather than hidden

**DC's non-resident sentence is tagged `.pension`,** so it renders in the pension
editor of a DC resident, for whom it is about somebody else. It is about pension
treatment, so the tag is honest, and the accuracy page reached from State
Comparison is where it actually lands in front of the affected user, which Task 7
wires up. I considered a fourth `.comparison` case and rejected it: it would name
a screen, which is what the topic vocabulary is designed not to do, and it would
be a case used exactly once. Mild irrelevance for DC residents, correct placement
for the population that needs it.

---

## 4. Layer B: the set extension, verified rather than taken

The brief says NY and MO are off both sets and must be added. **Confirmed, and
by derivation rather than by trust:**

- `phase5CorrectedJurisdictions` = KS, IA, NM, GA, UT, IN, MA, AZ, DC (9)
- `disclosureOnlyDivergentJurisdictions` = HI, NC, ID, VT (4)
- covered (15) minus both sets = **{MO, NY}**, exactly the two named.

The reason is broader than the brief states: it is not only that I populated
their `knownLimitations`. I added `taxYear`, `lastVerified` and `primarySources`
to all fourteen, and `configs2026Legacy` builds every entry with `verification`
defaulted to `.unverified`, so ANY of those four fields would have made the
re-encoded documents differ. MO and NY would have failed Layer B even if they had
received metadata and no sentence at all.

Both are now on `disclosureOnlyDivergentJurisdictions`. I verified the
confinement claim that membership asserts, rather than assuming it: `git diff -U0`
on both files reports hunks at lines 113 to 124 (MO, `verification` opens at 108)
and 141 to 148 (NY, opens at 136). Every changed line is inside the
`verification` block in both files. The suite re-proves this on every run through
`encodedWithoutVerification`, which is why membership here is strictly stronger
than membership in `phase5CorrectedJurisdictions`: every computed field stays
under full byte-identity.

`theTwoDivergenceSetsAreDisjoint` still passes; the intersection is empty.

I agree with Task 3's rejection of both alternatives and did not revisit them.
Adding these two to `phase5CorrectedJurisdictions` would assert a tax correction
that did not happen, and mirroring copy into `configs2026Legacy` would put
approved copy in two places.

---

## 5. Provenance: where `lastVerified` and `primarySources` came from

**`primarySources`** are the `sourceURL` fields of each state's golden fixture,
which a Phase 4 reviewer independently opened, with a human label built from that
fixture's own `source` prose. No URL was invented and none came from outside the
repository. New Mexico and New York carry two each because their fixtures cite
two; the other twelve carry one.

**`lastVerified`** is the date that state's golden fixture was last committed,
read from `git log -1 --format=%ad --date=short` on the fixture path, not chosen.
That produces 2026-08-04 for IN, MO, NM and UT (Phase 4) and 2026-08-05 for the
other ten (Phase 5b). The golden fixture IS the verification artifact for these
jurisdictions, so its date is the honest answer to "when was this last checked
against its sources". Georgia's existing 2026-08-04 was left alone.

**`billReferences` was deliberately left empty.** Several fixtures name bills
(Vermont's Act 71, New Mexico's HB252, Utah's S.B. 60, Iowa's HF 2317) and
populating it would have been cheap, but nothing gates it, it is not in this
task's scope, and every additional claim is another thing that can be wrong.

---

## 6. Test command and result

Scoped, after the change:

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh StateAccuracyContentTests StateTaxJSONStructuralEquivalenceTests StateTaxCodableRoundTripTests
```

```
Swift Testing:  Test run with 36 tests in 3 suites passed
XCTest:         Executed 0 tests, with 0 failures (0 unexpected)
PASS. 36 test(s) ran, no failures.
```

Full suite, foreground, `tools/run-tests.sh`, no arguments:

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh
```

```
Swift Testing:  Test run with 2048 tests in 306 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)
PASS. 2557 test(s) ran, no failures.
```

**GREEN.** Zero failing suites. `MultiYearPerfTests` did not fail, so the known
wall-clock flake is not in play and the wrapper's re-run path was not exercised.

Count moved from Task 3's 2,044 in 306 suites (with 42 issues) to 2,048 in 306
suites with none. The four added tests are listed below. XCTest unchanged at 509.

### Tests added

| Test | What it pins |
|---|---|
| `pensionEditorFiltersToPensionTopics` | The editor shows pension sentences only and every other topic still reaches the accuracy page. Written as a property over all covered jurisdictions, so a non-pension sentence authored later for any state is caught without editing it. |
| `everyTopicIsUsedBySomeShippedSentence` | Every enum case is earned by a sentence that ships. Fails on an unused case, which is how `.deduction` would have been caught had I not checked Georgia. |
| `everyShippedLimitationIsTaggedInTheFileItself` | No shipped file relies on the bare-string decode fallback. Reads raw bytes, because decoding cannot tell the forms apart. |
| `everyShippedSentenceIsCleanCopy` | No dash, doubled space or stray whitespace in any shipped sentence, on every state and both scopes. The six captions had this; the thirteen new sentences had no gate until now. |

### Verification of the moved sentences

The five Task 3 captions and Georgia's sentence were re-extracted from `HEAD` and
compared to the `text` field they now sit in: all six **byte-identical**. The JSON
rewriter was validated before use by re-rendering all 51 existing `verification`
blocks and confirming zero byte differences against the shipped files, so the
files keep the generator's exact `[.prettyPrinted, .sortedKeys]` formatting and
nothing outside the changed keys moved.

No em dash or en dash anywhere: swept over every changed file and over this
report.

---

## 7. Where I disagreed with the brief, or went past it

1. **Georgia is not an example of the unfiltered-caption defect.** Section 3.
   Its $70,000 is the retirement-income exclusion, not the standard deduction its
   wording suggests, so it is pension-topic and correctly placed. The defect is
   created by this task's own copy, not inherited. This changed the enum.

2. **Arizona's unclassified-pension entry was not authored.** Section 2. It is
   already disclosed by `unclassifiedPensionDisclosure`, on exactly the affected
   population. Thirteen sentences, not fourteen.

3. **The Layer B reason is broader than the brief states.** Section 4. Metadata
   alone diverges the documents, so MO and NY would have failed Layer B even with
   no sentence added.

4. **Hawaii, Idaho and Vermont got no new sentence.** Their catalogue entries and
   pinned defects describe the same mechanism their existing caption already
   states. The brief's worklist framing implies each of the fourteen needs
   authored copy; five of them needed only provenance.

5. **`billReferences` left empty**, section 5, though four fixtures name bills.

6. **Iowa and Indiana ship an empty limitation list**, which makes Task 6's
   empty-state wording load-bearing for two states in the COVERED set, not only
   for the thirty-six outside it. Worth knowing when that copy is written: a user
   who opens Iowa's page sees provenance and no limitations, and that must not
   read as "Iowa is fully modelled".

7. **A risk I am handing forward, and it is the mirror of the one Task 3 handed
   me.** `StateLimitation` now carries a topic, but the FIVE caption statics in
   `IncomeSourcesView` do not, and they remain the pinned record that Task 3's
   move was lossless. They are all pension-topic today so nothing is wrong. If a
   future task moves a NON-pension caption into config, the static and the topic
   can disagree with nothing to catch it. `everyTopicIsUsedBySomeShippedSentence`
   and `pensionEditorFiltersToPensionTopics` constrain the data, not the statics.
