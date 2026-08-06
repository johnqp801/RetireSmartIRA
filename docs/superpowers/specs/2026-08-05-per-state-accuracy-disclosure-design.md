# Per-state accuracy disclosure: Design

**Status:** approved 2026-08-05.
**Origin:** beta tester Steve Nicolai, 2026-08-01, recorded as commitment item 3 of six promised in
writing to Steve Nicolai and Alan Levy. His words: *"Communicate how accurate the state modeling is;
per-state, per-income-type treatment text."* He then found a second state bug the following day, which
is the argument for the feature.

**Depends on `feature/state-tax-phase5b`.** This branch is cut from it. The six captions this design
consolidates and the eleven `knownButUnpinned` entries it authors from exist only there.

---

## Goal

Answer two questions for any of the 51 jurisdictions, at the moment the number is on screen: **what
does this app model for my state**, and **what does it not model yet**.

## Non-goals

- A hand-maintained accuracy page. A prose page kept separately from the engine drifts, and a drifted
  accuracy page is worse than none, because it makes a false promise to precisely the users who went
  looking for the truth.
- The staleness signal (rendering differently when `lastVerified` is old). Good idea, not what was
  asked for, and the non-optional block in section 3 prevents the failure it guards against. Deferred.
- The caret-fix completion, which is commitment item 6. Separate and much smaller spec.

---

## 1. What the user sees

A per-state page in two halves.

### "What we model", generated entirely from `StateTaxConfig`

Bracket schedule for the user's filing status, standard deduction, personal exemption, Social Security
treatment, pension and IRA exemptions with dollar amounts and age gates, per-source rules rendered in
plain language ("KPERS, federal, military and Railroad Retirement pensions are excluded"), and local or
city tax where the config carries one.

**No prose is authored for this half.** It is a rendering of live data, so it cannot drift from the
engine. This alone satisfies "per-state, per-income-type treatment text" for all 51 jurisdictions at
no writing cost.

### "What we don't model yet"

The `knownLimitations` sentences verbatim, plus `lastVerified` and a link to `primarySources`. A state
with no limitations says so plainly, which is the useful answer for a user checking their own state and
finding nothing wrong.

## 2. Where it surfaces

An info affordance beside the state tax figure, at the moment the number is visible and the user can
act on it. Three entry points, one destination:

- the single-year results state tax line
- the State Comparison detail sheet
- the multi-year plan's state tax row

**Not Settings.** Burying it defeats the purpose.

## 3. Data model

The `verification` block already exists in the config schema, carrying `lastVerified`,
`primarySources` and `knownLimitations`. It is populated for exactly one jurisdiction, Georgia.
Nothing new is invented; the work is filling it and reading it.

**One change with teeth: make the block non-optional.** A new state config then cannot compile without
a verification date and a source. That is the forcing function that stops this rotting the way it has
since the field was added.

## 4. The consolidation

This decides whether the feature reduces complexity or adds to it.

Today three separate places tell a user what the app cannot model, and a naive implementation would add
a fourth:

1. **Six pension-editor captions**, hardcoded `if selectedState ==` branches in `IncomeSourcesView`
   (Hawaii, Massachusetts, North Carolina, Idaho, Vermont, and DC's survivor-toggle explanation).
2. **Four `unclassifiedPensionDisclosure` sentences** in config, gated on the pension being
   unclassified.
3. **Eleven `knownButUnpinned` catalogue entries**, which have NO production consumer at all.

**`knownLimitations` becomes the single place a limitation sentence is written.** The captions render
from the resident's config instead of from hardcoded branches. The per-state view shows the same
sentences. The catalogue entries become the authoring source: each already carries a mechanism, a
citation and a blocker, so producing its user-facing sentence is translation rather than research.

Adding a jurisdiction stops meaning editing a SwiftUI file.

**The cost, stated honestly:** this moves copy already approved and shipped-adjacent. Every moved
sentence gets a test pinning it byte-for-byte, the guard used when New York's disclosure text moved
into config and was proven character-identical at the parent commit.

`unclassifiedPensionDisclosure` stays a separate field. It answers a different question ("your pension
is unclassified, so a rule you may qualify for is going unused") and fires on a different condition.
Merging it into `knownLimitations` would conflate a prompt with a disclosure.

## 5. Content scope

Limitation sentences for jurisdictions with verified findings: the eight Phase 5b states (KS, MA, HI,
AZ, NC, ID, VT, DC), plus New York, Missouri, and the Phase 5a corrections (IA, NM, GA, UT, IN).
Roughly fifteen, each traceable to a catalogue entry or a pinned defect.

The remaining thirty-six get the factual half and an honestly empty limitations list. **No hedged
sentences written to fill space.**

**Every new sentence is user-facing copy and goes to John for approval before it ships**, in one batch
rather than trickled. Sentences moved from existing captions carry their existing approval.

## 6. Testing

Three gates:

1. **Disclosure completeness sweep.** Every config with a pinned `knownDefect` in a covered
   jurisdiction carries at least one limitation sentence, so a state cannot be corrected and left
   undisclosed. Modelled on `rulesAndDisclosuresStayInLockstep`, which is bidirectional and must not be
   deleted.
2. **Byte-identity per moved caption.** Each of the six reproduces character for character after the
   move, asserted against the string extracted from the parent commit rather than from the current
   tree.
3. **Rendering fidelity, all 51.** The factual half matches the config it claims to describe, so the
   page cannot say one thing while the engine does another.

## 7. Risks

- **Moving approved copy.** Mitigated by gate 2. This is the same operation Task 3b performed
  successfully on New York.
- **The captions are currently untestable view-body literals** in one file, flagged by two separate
  Phase 5b reviews. Hoisting them to config is what makes gate 2 possible at all, so the risk of moving
  them is lower than the risk of leaving them.
- **Scope creep into a general disclosure taxonomy.** Phase 6 owns that. This design reads the config
  it already has and does not redesign how disclosure is decided.
