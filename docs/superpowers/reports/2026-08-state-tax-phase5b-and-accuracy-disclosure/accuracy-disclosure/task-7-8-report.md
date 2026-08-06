# Tasks 7 and 8: three entry points, two behaviour gates, and the branch closed

**Branch** `feature/state-accuracy-disclosure`, worktree
`/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure`.
Started clean at `870324c`.

| Task | Commit | Full suite |
|---|---|---|
| 7, three entry points | `d107b0d` | 2,066 Swift Testing in 306 suites + 509 XCTest, 0 failures |
| 8, Gates 1 and 3 | see below | 2,071 Swift Testing in 306 suites + 509 XCTest, 0 failures |

Command, in the foreground, both times:

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh
```

Baseline entering the work was 2,062 + 509. Nine tests added, four in Task 7 and
five in Task 8. No `MultiYearPerfTests` flake in either run, and neither run had
any failure to explain.

---

## 1. The three resolvers, and how each was proved

`StateAccuracyContent` gained three one-line functions. Each takes only the
states its own destination has, and names them, so a call site cannot hand over
the wrong one without the argument label saying so.

| Destination | Resolver | Returns | Call site |
|---|---|---|---|
| Single-year results state tax line | `stateForSingleYearResults(resident:)` | the resident | `DashboardView.stateTaxRow`, via `singleYearAccuracyState` |
| State Comparison detail sheet | `stateForComparisonSheet(inspecting:resident:)` | the INSPECTED state | `StateTaxDetailSheet.accuracyPageState` |
| Multi-year plan state tax figure | `stateForMultiYear(scenarioState:resident:)` | the modelled state | `MultiYearPlanView.multiYearAccuracyState` |

**Why three functions and not one taking a destination enum.** A single
`state(for:)` would make all three call sites pass the same two arguments and
put the choice inside a switch nobody reads at the point of use.
`stateForSingleYearResults` takes no viewed state at all, because that screen
has none, so the wrong state cannot be passed to it even by accident.

### What the tests prove

- `entryPointsResolveTheCorrectState`, the plan's own test, one example per
  destination.
- `comparisonSheetNeverFallsBackToTheResident` sweeps every ORDERED PAIR of the
  fifty-one jurisdictions, 2,601 combinations, including all fifty-one where
  inspected and resident coincide. The plan's single example would pass for a
  resolver that returned a hardcoded Oregon, or one that returned the resident
  whenever the two happen to be equal. This one would not.
- `theThreeDestinationsAreDistinguishable` asserts the three disagree when the
  states they read differ, which is the property lost by collapsing them.
- `modelledStateResolvesEveryAbbreviation` builds a real
  `MultiYearStaticInputs` for each of the fifty-one abbreviations and asserts
  `modelledState` round-trips, plus the malformed case returning `nil`.

### The multi-year state, and why it is not just `dataManager.selectedState`

The brief's asymmetry is the important one, but there is a second, quieter way
to get the multi-year entry point wrong: read the resident state at the call
site, which is already in scope, and call it the scenario's state. That is
indistinguishable from correct today and would silently stay wrong forever.

So the multi-year state is taken from the engine's own inputs:

1. `MultiYearStaticInputs` gained `var modelledState: USState?`, which resolves
   `inputs.state` (the two-letter code the adapter writes).
2. `ProjectionEngine.project` was pointed at it. That line already performed the
   identical lookup to decide which jurisdiction to tax each projected year in;
   it now reads the same accessor, so **the state the plan's tax was computed in
   and the state the accuracy page describes cannot resolve differently.**
3. `MultiYearStrategyManager` gained `@Published private(set) var modelledState`,
   recorded from the built inputs in `performCompute` and
   `computeApproachComparison`, guarded on inequality because `@Published`
   republishes on every assignment and this runs on every compute.
4. `MultiYearPlanView.multiYearAccuracyState` maps that through
   `stateForMultiYear(scenarioState:resident:)`.

Today `MultiYearInputAdapter` fills `inputs.state` from
`dataManager.selectedState`, so the two agree. The point is that if a later
release lets a plan model a state the household does not live in, the page
follows the plan rather than the address, with no change at the call site.

`nil` is handled rather than defaulted. `ProjectionEngine` falls back to
California for an abbreviation no `USState` carries, so a `nil` here means the
plan was taxed as California; the affordance renders as the plain untappable tag
rather than naming a jurisdiction the figures did not come from.

### The limit of the proof, stated plainly

The resolvers and their asymmetry are proved by test. **The argument each call
site supplies is proved by reading the code, not by a test**, because asserting
it would mean rendering SwiftUI. There is no way around that short of a UI test
harness this repository does not have. What was done instead:

- Each call site is a named computed property with a doc comment stating which
  state wins and why, rather than an inline expression buried in a view body.
- `StateTaxDetailSheet.accuracyPageState` passes `currentStateBreakdown.state`
  as `resident:`, which is the same field the sheet's body already uses to
  decide whether it is showing the user's own state at all, so the two readings
  of "resident" in that file agree.
- `ApproachComparisonView` takes an already-resolved `accuracyState` and does
  not read `DataManager`, so the multi-year choice can only be made in
  `MultiYearPlanView`, the one place that holds both states.

File and line, for review: `DashboardView.swift:1006` (`singleYearAccuracyState`),
`StateComparisonView.swift:614` (`accuracyPageState`), `MultiYearPlanView.swift:68`
(`multiYearAccuracyState`).

---

## 2. Where the affordance actually went, and one place the plan was wrong

**Single-year results:** `DashboardView`'s Tax Projection card, on the
`State Tax (KS)` line. The row's abbreviation and the page now both read
`singleYearAccuracyState`, so the state named on the row and the state the page
describes cannot drift apart. Deliberately not folded into the shared
`taxRow(label:value:)`: ten other rows use that helper and have no accuracy
page.

**State Comparison detail sheet:** beside the inspected state's name in
`stateHeaderSection`. The sheet gained a `filingStatus` parameter, because the
accuracy page reports filing-status-specific bracket, deduction and exemption
columns and `StateTaxBreakdown` does not carry the status it was computed for.

**Multi-year: THE PLAN'S "state tax row" DOES NOT EXIST.** Task 7 says to modify
"the single-year results view and `MultiYearPlanView`" and names a "Multi-year
plan state tax row". There is no such row. The ladder prints year, conversion,
AGI and IRMAA; the plan summary prints a lifetime tax total; the year-by-year
table has no state column. Verified by reading `MultiYearPlanView`,
`MultiYearPlanSections` (`AssumptionsStripView`, `PlanSummaryView`,
`PlanComparisonView`, `LadderListView`) and by grepping the whole production
tree for a state tax label.

The one place the Multi-Year tab prints a number that is specifically state
income tax is the consequence strip's `State` delta tag in
`ApproachComparisonView`, so that is where the affordance went, per the design's
"an info affordance beside the state tax figure, at the moment the number is
visible". It reads `State (KS)` with an info glyph and is a button; when no
state resolved it falls back to the plain tag.

**Consequence worth flagging to John:** that tag only renders when an approach
comparison exists, so the multi-year entry point is not always on screen. If the
intent was an always-available affordance on that tab, it needs a home that is
not tied to the comparison, and that is a design decision rather than an
implementation one.

---

## 3. Gate 3, and what it catches that an echo would not

### The per-spouse gate: three probes, not two

The plan's sketch compares two engine calls and asserts `both < single`. That
passes for an engine that grants a second exclusion of any size at all,
including one dollar. So there is a third probe:

1. one spouse qualifies,
2. both spouses qualify,
3. one spouse qualifies, on a pension smaller by exactly the configured cap.

**Probes 2 and 3 must produce the SAME tax**, which holds only if the second
qualifying spouse moved the taxable base by exactly one more full cap. A
doubling that stopped short, or one that ran twice, breaks the equality while
`both < single` still passes.

The configured cap is read in order to BUILD probe 3. Nothing asserts the
configured value; what is asserted is how far the engine moved. That is the
distinction between this and an echo.

Only one input differs between probes 1 and 2: the spouse's age. Filing status,
standard deduction, personal exemption and the pooled exemption LEVEL are
identical, because `effectiveAge` is the household maximum and the primary is
above every gate in both. `postExemptionDeduction` is computed once with both
ages qualifying and passed unchanged to all three probes, because a state
granting a per-filer senior addition would otherwise give the younger-spouse
probe a smaller exemption and a higher tax, biasing the comparison in the
direction the test is trying to prove. So a difference in the result can only
come from `perIndividualMultiplier`.

The probe is built from `GoldenScenarioSingleYearTests.singleYearStateTax`'s
construction, as instructed: same `calculateStateTax` argument list, same
`postExemptionDeduction` derivation from `config.personalExemption`, same
state-standard-deduction step. One private-employer defined-benefit pension row,
so New York's per-source rule (which names `nyStateOrLocal`, `federalCivilian`
and `uniformedServices`) cannot match and change the pooled figure underneath
the comparison.

It also asserts the PAGE and the config agree about whether the claim is made at
all, in both directions: a flag with no sentence hides a rule the user is
entitled to, a sentence with no flag promises one the engine was never asked
for. And it pins `checked == ["GA", "NY"]`, so a jurisdiction gaining or losing
a per-spouse cap has to be acknowledged rather than quietly changing what the
gate covers. Without that literal, a covered set that lost both states would
pass in silence.

**Verified by mutation, not by assumption.** Dropping the second spouse to a
non-qualifying age made the gate fail with real magnitudes: Georgia moved
$3,243.50, which is its $65,000 cap at 4.99%, and New York $1,080.00. The
equality assertion failed by those same amounts. Reverted before commit.

### The Social Security gate

Added because the Social Security line is the page's most-read sentence and the
one an echo would validate most convincingly: the statement is generated
straight from `socialSecurityExempt`, so reading that flag back would prove only
that a boolean equals itself.

What is asserted: feeding the engine a taxable benefit must LOWER the tax for a
jurisdiction whose page says the benefit is not taxed, and must leave it
UNCHANGED for one whose page says it is taxed as ordinary income. Both
directions, every covered jurisdiction. The nine untaxed jurisdictions are
outside it by construction, because they emit no Social Security statement at
all, and the test asserts that too: a covered state that taxes income and says
nothing about Social Security fails.

**Verified by mutation:** zeroing the benefit in the second probe failed for
twelve covered jurisdictions. Reverted.

### What Gate 3 CANNOT see, recorded as an executable statement

`californiaExemptionCredits` is subtracted behind a `state == .california`
branch in `TaxCalculationEngine.calculateStateTax:405`, mirrored at
`DataManager.swift:1229`. No `StateTaxConfig` field carries it.

**No behaviour probe can catch this, and saying so precisely matters.** A probe
discovers a discrepancy between a CLAIM and BEHAVIOUR. The page makes no claim
about California's credits, because it is generated from a config that has none.
The page is not wrong about California; it is silent about a reduction
California filers actually receive. There is nothing for a probe to compare.

So the gate the tests can honestly hold is the SCOPE one, and that is what was
written:

- `jurisdictionsWithEngineLogicNoConfigExpresses: Set<USState> = [.california]`,
  a hand-maintained literal, because the thing it names is Swift source rather
  than data. Compiled by sweeping the production tree for a state compared by
  name inside a tax computation; those two lines are the only occurrences.
- `coveredJurisdictionsCarryNoUnrepresentedEngineLogic` asserts the covered set
  is disjoint from it. California is outside the covered set today, so this is
  green, and it is what makes ADDING California a deliberate act: it fails until
  the credits gain a config representation or a limitation sentence discloses
  them.
- `californiaCreditsAreInvisibleToAConfigGeneratedPage` proves the literal is
  not decorative: the credit is genuinely positive for an ordinary joint
  household, and California's generated page mentions no credit in either filing
  status. If a future refactor moves the credits into config, that test fails
  and the stale exclusion gets cleaned up instead of sitting there forever.

**Verified by mutation:** adding Kansas to the literal failed the disjointness
gate. Reverted.

---

## 4. Gate 1, four directions

Modelled on `Phase5bUnclassifiedPensionDisclosureTests.rulesAndDisclosuresStayInLockstep`.

The traceability data available in the repository is per JURISDICTION:
`GoldenScenarioDefectCatalogueTests.catalogue()` derives the pinned set from the
golden fixtures, and `knownButUnpinned` is a list of jurisdictions and
mechanisms. **`StateLimitation` carries `text` and `topic` and no citation
field**, so nothing in the data links one sentence to one catalogue entry.
Adding such a field is a config schema change and belongs with the disclosure
taxonomy the design assigns to Phase 6. This is stated in the test's own doc
comment rather than glossed.

What the gate enforces instead is a declared table,
`limitationBasis: [String: (basis, sentences)]`, covering
`coveredJurisdictions` exactly, checked against the LIVE catalogue every run.

1. **Every covered jurisdiction with a pinned defect ships at least one
   limitation.** Eight qualify today: AZ, HI, ID, MO, NC, NM, UT, VT. All eight
   ship one.
2. **Every limitation traces.** Each jurisdiction declares `.pinnedDefect`,
   `.unpinnedCatalogue`, or `.disclosureOnly(reason:)`, and the declaration is
   verified: `.pinnedDefect` must still appear in the catalogue,
   `.unpinnedCatalogue` must still be named by an entry, and `.disclosureOnly`
   must have a non-empty reason AND must have NEITHER, so the category cannot be
   used to park a finding that does trace and would otherwise be caught by
   direction 1.
3. **A correction forces removal or revision.** The declared SENTENCE COUNT is
   the forcing function, and it is why the basis alone is not enough: a
   jurisdiction with two findings keeps its basis when one is fixed. The count
   fails, and someone has to decide whether the surviving sentence is still
   true.
4. **No orphan disclosure survives**, in both halves. Inward: a jurisdiction
   whose declared basis has fallen away fails with a message naming the orphan.
   Outward: **no jurisdiction outside the covered set may ship a limitation at
   all**, because Gate 4 does not require its verification metadata, so such a
   sentence would have no date, no source and no recorded basis, and nothing
   would ever check it again.

Only one jurisdiction is `.disclosureOnly` with a sentence: Georgia. Its
configuration is correct for TY2026 and no golden case disagrees with the state's
own form; the sentence records that the retirement-income exclusion rises again
in TY2027 and that this file does not encode the later year. That is a statement
about the config's SCOPE rather than a defect in it. Iowa and Indiana are also
`.disclosureOnly`, with a declared count of ZERO, listed so the table covers the
covered set exactly and a jurisdiction cannot escape the gate by being left out
of the table.

**Verified by mutation, three ways.** Re-declaring Georgia as `.pinnedDefect`
failed (no pinned defect traces to it). Changing Utah's declared count from 2 to
1 failed. Adding an orphan sentence to Pennsylvania's shipped JSON failed the
outward half, and incidentally also failed
`emptyLimitationsDoesNotClaimCompleteness`, which is the older gate doing its
job. All three reverted; `statetax-2026-PA.json` restored with
`git checkout` and confirmed clean.

---

## 5. The five inherited concerns, adjudicated

### 1. Roth conversion treatment is absent from the page. NOT MINE TO FIX, and I agree it is John's call.

Verified the premise first, because the brief is evidence rather than fact. Four
jurisdictions carry `rothConversionExemption`: Iowa, Illinois, Mississippi and
Pennsylvania. Three of the four are OUTSIDE `coveredJurisdictions` (IL, MS, PA),
so for those the page today shows the factual half and the "none currently
recorded" empty state, and adding a Roth line would be the only thing on the
page a conversion planner would act on.

**The Pennsylvania case is the strongest one and it is stronger than the brief
states.** Pennsylvania taxes ordinary income at a flat 3.07% and exempts the
conversion; a user converting $200,000 who does not know that will assume a
$6,140 state cost that does not exist. Nothing on Pennsylvania's page today
contradicts that assumption, and nothing states the exemption either.

I did not add it, for the same reason Task 5 did not: the design's section 1
enumerates the factual half's contents and does not include it, so widening what
the page claims is a scope decision. Task 8's brief is Gates 1 and 3 and closing
the branch. Adding a statement type would also require deciding where it sits in
`statementsKeepTheirOrder`'s fixed order, which is user-facing sequencing.

**Recommendation: ship it, as a small follow-up, before the branch merges.** It
is roughly ten lines plus a test, it is the single most decision-relevant fact
the config holds for a Roth conversion app, and the page's whole purpose is to
tell a user what treatment is being applied. Two placements are defensible:
after `IRA and 401(k) exemption` (it is a distribution-side rule) or immediately
after `Tax rates` (it is the one line a conversion planner is on the page for).
I would put it after the IRA line, because the page's order is the order the tax
is computed in and breaking that for prominence would cost more than it buys.

### 2. The plan's "local tax" statement cannot exist. CONFIRMED, no action.

Independently re-verified. `localIncomeTaxRate` occurs twice in the production
tree, both in `TaxCalculationEngine`: the parameter declaration and its single
use. It is a figure the user types in, not a per-state field, so there is
nothing per-state to report and the absent-is-omitted rule handles it with no
special case. Correctly omitted by Task 5.

### 3. California's exemption credits. HANDLED, and the limit is recorded rather than papered over.

See section 3 above. Gate 3 **cannot** catch this by behaviour probe, and the
reason is structural rather than a gap in effort: a probe compares a claim
against behaviour, and the page makes no claim. What the gate does instead is
prevent the page from ever being published for a jurisdiction in that position,
which is the enforceable half, and it asserts the credits are real so the
exclusion cannot go stale silently. Both are executable. Task 5 was right that
Gate 3 is where this belongs; it was optimistic about what form the answer could
take.

### 4. `.specialLimited` emits one statement and stops. VERIFIED, no action.

Re-derived rather than taken on trust. `untaxedJurisdictionsMakeOneStatement`
derives its set from `taxSystem.hasIncomeTax` rather than naming states, and it
passes. The new Social Security gate now covers the same ground from the other
direction: it asserts that a covered jurisdiction which TAXES income and emits no
Social Security statement is a failure, so the "emit nothing" path cannot spread
from the untaxed jurisdictions to a taxing one unnoticed.

### 5. The `["IA", "IN"]` property test. VERIFIED, and deliberately doubled.

Still passing. Gate 1's table now also declares Iowa and Indiana with a sentence
count of zero, which is a second, independent statement of the same fact from a
different direction (the count table rather than the empty-state sweep). That is
redundancy on purpose: the empty state is the single most dangerous thing on
this page to get wrong.

---

## 6. Copy APPROVED by John on 2026-08-06, as written

Three strings, all accessibility labels, none of them visible text. There is no
new visible copy in either task: the three affordances are info glyphs, and every
word on the page they open was approved in Tasks 5 and 6. All three labels, and
the `State (KS)` delta tag named below, were approved as written on 2026-08-06.
The alternatives in the table are recorded as REJECTED, not as open options.

| Where | Shipped wording | Alternatives, all rejected |
|---|---|---|
| Single-year results state tax line | `State tax accuracy for Kansas` | 1. `State tax accuracy for Kansas` (SHIPPED). Names the state, so a VoiceOver user hears which jurisdiction the page will describe. 2. `How accurate is Kansas state tax?` Reads as a question the button answers, but invites the reading that the app is rating its own accuracy, which the design rejects outright. 3. `About Kansas state tax`. Vaguer, and does not say the page is about accuracy. |
| State Comparison detail sheet | `State tax accuracy for Oregon` | Same three. Naming the state matters MOST here, because the state named is the one being inspected and not where the user lives, which is exactly the distinction a sighted user gets from the button's position and a VoiceOver user would otherwise lose. |
| Multi-year State delta tag | `State tax accuracy for Kansas` | Same three. |

All three use one wording on purpose: three affordances doing the same thing
should not read three different ways.

One visible-text change worth naming, though it is not new copy: the multi-year
delta tag's label goes from `State` to `State (KS)`, matching the abbreviation
convention the single-year row already uses (`State Tax (KS)`). John APPROVED
this change on 2026-08-06; the tag keeps the abbreviation. Reverting it to a bare
`State` would be a one-line change, and is not wanted.

---

## 7. Things I disagreed with, or found wrong

**One: the plan's "Multi-year plan state tax row" does not exist.** Section 2
above. The affordance went on the only state tax figure the Multi-Year tab
prints, and the fact that it is a delta rather than a level, and only present
when an approach comparison exists, is flagged for John rather than papered
over.

**Two: the plan's Gate 3 sketch would pass on a one-dollar second exclusion.**
`both < single` is a direction test, not an amount test, and the design asks for
"the engine applies $20,000 when both spouses qualify and $10,000 when one
does", which is an amount. The third probe is the difference. Section 3.

**Three: Gate 1 cannot be per-sentence with the data that exists**, and a test
written as though it could would be quietly weaker than it looked. Stated in the
test's own doc comment and in section 4, with the schema change it would need
assigned to where the design already puts it.

**Four: my own error, recorded because it cost a rerun.** Reverting a mutation
experiment with `git checkout --` on the test file discarded the uncommitted
Task 8 work along with the mutation. Re-applied from context and the second
round of mutations was run against a backup copy in the scratchpad instead.
Nothing shipped was affected, and the final tree was diffed against `d107b0d` to
confirm only `StateAccuracyContentTests.swift` changed.

**Five: not a disagreement, a scope judgement worth naming.** Task 7's file list
names three view files. The work also touched `MultiYearStaticInputs`,
`ProjectionEngine` and `MultiYearStrategyManager`, to make the multi-year
resolver read the state the ENGINE modelled rather than re-reading the resident
at the call site. That is three files beyond the brief. The alternative was a
call site that is indistinguishable from the resident resolver, which is the
collapse the brief warns against, arrived at by a different door. The
`ProjectionEngine` change is a one-line substitution of an identical expression.

---

## 8. Nothing untouched that should have been

- No `knownDefect`, `tier`, `observedToday` or `expectedStateTax` was edited.
- Nothing under `RetireSmartIRATests/Baselines/` was touched.
- No existing limitation sentence was changed. The nineteen shipped sentences
  are byte-identical to `870324c`.
- No em dash or en dash was added. `IncomeSourcesView.swift`'s seventeen
  pre-existing ones were left alone; that file was not modified at all.
- `git diff 870324c --stat` covers ten files: three view files and three engine
  or model files for Task 7, `StateAccuracyContent.swift` for the resolvers, the
  test file, and this report.
