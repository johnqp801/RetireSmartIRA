# Per-state accuracy disclosure: Design

**Status:** approved 2026-08-05, revised same day after review.
**Origin:** beta tester Steve Nicolai, 2026-08-01, recorded as commitment item 3 of six promised in
writing to Steve Nicolai and Alan Levy. His words: *"Communicate how accurate the state modeling is;
per-state, per-income-type treatment text."* He then found a second state bug the following day, which
is the argument for the feature.

**Depends on `feature/state-tax-phase5b`.** This branch is cut from it. The six captions and the
eleven `knownButUnpinned` entries this design authors from exist only there. **FIVE of the six were
consolidated into config as shipped (HI, MA, NC, ID, VT); DC's survivor-toggle caption stays a Swift
literal.** Corrected 2026-08-06; see section 4.

---

## The core promise

The page answers two questions **for the selected state AND tax year**:

1. What tax treatment does RetireSmartIRA currently apply?
2. What known limitations could affect that result?

Deliberately NOT an accuracy score or percentage. There is no honest definition of one, and it would
mislead fastest for the users who care most.

## Non-goals

- A hand-maintained accuracy page. Prose kept separately from the engine drifts, and a drifted accuracy
  page is worse than none because it makes a false promise to precisely the users who went looking for
  the truth.
- The staleness signal (rendering differently when `lastVerified` is old). Deferred.
- The caret-fix completion, commitment item 6. Separate and much smaller spec.

---

## 1. What the user sees

A per-state page in two halves, headed with **state and tax year together**: "Iowa tax treatment,
2026", never bare "Iowa". Otherwise "verified August 2026" reads as a claim about current law generally
when the config is specifically for one tax year.

Header carries: **state, tax year, last verified date, primary sources.**

### "What we model", generated from `StateTaxConfig`

Bracket schedule for the user's filing status, standard deduction, personal exemption, Social Security
treatment, pension and IRA exemptions with dollar amounts and age gates, per-source rules in plain
language ("KPERS, federal, military and Railroad Retirement pensions are excluded"), and local or city
tax where the config carries one.

**No prose is authored for this half.** It is generated from the same state configuration the engine
consumes, which substantially reduces the risk of separately maintained disclosure text drifting from
the modelled rules. **It does not by itself prove the text matches effective engine behaviour**, and
this branch produced several reasons to say so precisely: hardcoded engine logic that overrode config,
filing-status and spouse attribution altering a configured rule, per-source rules the engine could not
express, credits with no config representation at all, and single-year and multi-year paths reading the
same data differently. Gate 3 in section 6 is what closes that gap.

### "Known limitations"

Not "what we don't model yet". Several entries are not absences: they are incorrect amounts, missing
age gates, wrong spouse attribution, unsupported plan-source distinctions, unrepresented credits, or
multi-year path differences. "Known limitations" stays accurate when the sentence is "this app applies
the exclusion once per household rather than separately to each qualifying spouse."

**The empty state must not claim completeness.** An empty array means we have not recorded a
limitation. It does not mean none exists. Phase 4 found states considered correct on retirement
exclusions that were wrong on brackets, deductions, credits and filing-status treatment. Render:

> No known limitations are currently recorded for this state and tax year.

optionally followed by:

> State tax rules are complex, and this does not mean every unusual situation is represented.

**SUPERSEDED BY JOHN ON 2026-08-06, AND THE CHANGE IS THE OPPOSITE OF WHAT THIS SECTION SAYS.** The
second sentence is approved and is NOT optional and NOT limited to the empty state: it renders on
EVERY state page, under a populated limitations list as well as an empty one. Georgia, Iowa and
Indiana each show a verification date, a primary source and the empty-state sentence, and while each
line is individually true, together they read close to a warranty of completeness; a page listing
three limitations makes the same implicit claim about the rules it omits. It ships as
`StateAccuracyContent.modellingCaveatSentence`, a SEPARATE always-rendered element rather than an
append to the sentence above, because the gate on the sentence above is exact equality and John
specified it character for character.

Stronger language ("no known limitations were identified in our latest verification") requires an
explicit recorded verification SCOPE, not merely an empty array, and is out of scope here.

## 2. Where it surfaces, and whose config supplies it

An info affordance beside the state tax figure, at the moment the number is visible and the user can
act on it. **Not Settings.**

**Each destination reads a different state, and this must be explicit** so that a comparison sheet for
Oregon never shows California's disclosure because California is where the user lives:

| Destination | State whose config supplies the page |
|---|---|
| Single-year results state tax line | the selected resident state |
| State Comparison detail sheet | **the state being inspected**, not the resident state |
| Multi-year plan state tax row | the scenario's modelled state |
| Pension-editor captions (section 4) | the resident state |

## 3. Data model and the forcing function

The `verification` block already exists in the config schema with `lastVerified`, `primarySources` and
`knownLimitations`. It is populated for exactly one jurisdiction, Georgia. Nothing new is invented; the
work is filling it and reading it.

**Make the block required in the schema.** Note precisely what that does: these configs are JSON, so a
missing required property fails at **decode or test time, not Swift compile time**. The forcing
function is therefore a suite-enforced loading gate, not a compiler guarantee. Gate 4 in section 6 is
that gate.

## 4. The consolidation

Today three separate places tell a user what the app cannot model, and a naive implementation adds a
fourth:

1. **Six pension-editor captions**, hardcoded `if selectedState ==` branches in `IncomeSourcesView`.
   **FIVE of them moved (HI, MA, NC, ID, VT).** The District of Columbia's survivor-toggle caption
   stayed: it is the instruction for a CONTROL rather than a description of a limitation, and moving
   it would show it to every DC resident whether or not the toggle is on screen.
2. **Four `unclassifiedPensionDisclosure` sentences** in config, gated on the pension being unclassified.
3. **Eleven `knownButUnpinned` catalogue entries**, with NO production consumer at all.

**`knownLimitations` becomes the single place a limitation sentence is written.** The captions render
from the resident's config instead of hardcoded branches. The per-state view shows the same sentences.
The catalogue entries become the authoring source: each already carries a mechanism, a citation and a
blocker, so producing its user-facing sentence is translation rather than research.

Adding a jurisdiction stops meaning editing a SwiftUI file.

**`unclassifiedPensionDisclosure` stays a separate field.** It is an actionable prompt tied to the
user's own data classification; `knownLimitations` describes the engine. Merging them would blur "the
app cannot model this rule" with "the app could model it, but you have not identified your pension
source." Those are materially different and only one of them is actionable by the user.

Four sources become two, which is the right number.

## 5. Content scope

Limitation sentences for jurisdictions with verified findings: the eight Phase 5b states (KS, MA, HI,
AZ, NC, ID, VT, DC), plus New York, Missouri, and the Phase 5a corrections (IA, NM, GA, UT, IN).
Roughly fifteen, each traceable to a catalogue entry or a pinned defect.

The remaining thirty-six get the factual half and the "none currently recorded" empty state from
section 1. **No hedged sentences written to fill space, and no implication that an empty list means
verified-complete.**

**Every new sentence is user-facing copy and goes to John for approval before it ships**, in one batch.
Sentences moved from existing captions carry their existing approval.

## 6. Testing: four gates

1. **Disclosure completeness, bidirectional.** Modelled on `rulesAndDisclosuresStayInLockstep`.
   - Every active pinned defect in a covered jurisdiction produces a limitation.
   - Every limitation corresponds to a pinned defect, an expressly unmodelled rule, or a documented
     disclosure-only finding.
   - A corrected defect forces removal or revision of its limitation.
   - **No orphan disclosure survives after its underlying issue is fixed.**

2. **Migration byte-identity, TEMPORARY.** Each of the five moved captions reproduces character for
   character after the move, asserted against the string extracted from the **parent commit** rather
   than the current tree. This gate exists to prove the relocation was lossless and is **not** a
   permanent freeze on the wording. Once migration lands, the permanent assertions pin **presence,
   state, mechanism, source, and affected income type**, so John can approve a copy change later
   without fighting an obsolete snapshot.

3. **Rendering fidelity against EFFECTIVE BEHAVIOUR, all 51.** Not an echo test. If the page says
   "$10,000 retirement exclusion per qualifying spouse", the test must establish that the engine
   applies $20,000 when both spouses qualify and $10,000 when one does. Reading an amount and a boolean
   back out of the config would not catch a faulty engine implementation, and this branch produced
   several faulty implementations that a config echo would have passed.

4. **Source and verification completeness**, loading every jurisdiction. Each must carry:
   - a tax year, matching the config's own year
   - a nonempty `lastVerified`
   - at least one admissible primary source, HTTPS, with a valid URL
   - supporting authority or a defect-catalogue reference for **every** limitation
   - no limitation referring to a year different from the config year unless explicitly stated

## 7. Risks

- **Moving approved copy.** Mitigated by gate 2, the same operation Task 3b performed successfully on
  New York's disclosure text.
- **The captions are currently untestable view-body literals** in one file, flagged by two separate
  Phase 5b reviews. Hoisting them to config is what makes gate 2 possible at all, so the risk of moving
  them is lower than the risk of leaving them.
- **Overclaiming accuracy.** The single largest conceptual risk, and the reason section 1's empty state
  is specified as wording rather than left to the implementer.
- **Scope creep into a general disclosure taxonomy.** Phase 6 owns that. This design reads the config
  it already has and does not redesign how disclosure is decided.
