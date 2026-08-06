# Phase 5b whole-branch review: fixes report

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`, branch
`feature/state-tax-phase5b`, starting HEAD `1125213`, clean at start, merge base with `main`
`378c110`. Every finding in the brief was checked against the code before it was acted on. Five
were confirmed as stated. One (MINOR 4) was confirmed in substance but its stated rationale was
wrong, and that is recorded in the disagreements section at the bottom.

---

## CRITICAL 1. New York military retired pay

### The choice: OPTION (a), widen New York's rule

`statetax-2026-NY.json` and the `configs2026Legacy` mirror in `StateTaxData.swift` now name
`["nyStateOrLocal", "federalCivilian", "uniformedServices"]` at `definedBenefit`, treatment
`full`.

The reviewer's account of the defect is correct in every particular, and I re-derived it rather
than accepting it. Task 3 added the "Military retired pay" row to `PlanClassificationChoice` for
every jurisdiction; it writes `(definedBenefit, uniformedServices)`; New York's rule named neither
that source nor anything reaching it; so `matchedPerSourceRule` returned nil and the row pooled
into `pensionIncome` under the capped $20,000 Line 29 exclusion. Before the branch the best
available pick was "Government pension, federal civilian", which the rule matched. The branch
replaced a right-by-accident answer with a wrong one, and every New York golden case stayed green
because none carried such a row.

Four reasons for (a) over (b):

1. **It is correct law by the authority New York's own fixture already quotes**, so it needs no
   research Step 1 forbids. NY-1's `source` string carries the eligibility list verbatim: an
   officer, employee, or beneficiary of an officer or employee of NYS, a NY locality, certain
   named NY public authorities, "or the United States". A retired member of the uniformed
   services is an officer or employee of the United States drawing a federal government pension.
   Military retired pay was always inside that closed list; only the model's vocabulary was too
   coarse to say so, until Task 1 split `uniformedServices` out of `federalCivilian`.
2. **It closes the two-encodings divergence**, which is inheritance item 8 in the close-out
   ledger. `MilitaryRetirementExemption.exemption(for: "NY", age: 65)` already returned
   `.fullyExempt` (`MilitaryRetirementExemption.swift:129`, pinned by
   `MilitaryRetirementExemptionTests.testFullyExempt_NewYork`). Before this change the answer
   depended on which screen the money was entered from. Arizona's identical divergence closed the
   same way in Task 6. This is the first instance of the class that a jurisdiction's own fixture
   had the authority to close.
3. **Option (b) needs a New-York-specific hardcode in the one file Task 3b spent a whole task
   de-special-casing.** `options(for:selected:)` suppresses purely from live config via
   `residenceNamesItsOwnJurisdiction`, and a Task 3 review deliberately changed
   `jurisdictionNamedSources` from a `Set` to a `[PlanSource: USState]` precisely so suppression
   would stay data-driven. Suppressing two rows for New York would have to be a hardcode or a
   second, differently-shaped list.
4. **Option (b) is a landmine in five other states.** It leaves the affected user with no honest
   row: they must describe military retired pay as a federal civilian pension. The picker's own
   doc comment says Kansas, Massachusetts, Arizona, Idaho and Vermont each treat the two
   differently. (b) trades one New York defect for a wrong answer everywhere else, and it does
   not close the divergence in 2.

### Layer B handling: MIRRORED, following Task 3b's precedent

New York is not on `phase5CorrectedJurisdictions`
(`StateTaxJSONEquivalenceTests.swift:736`), so
`StateTaxJSONStructuralEquivalenceTests.structurallyIdentical` requires its bundled JSON and its
`configs2026Legacy` entry to re-encode byte-identically. The change was mirrored into the legacy
table rather than New York being added to the list.

Adding New York to the list was the alternative and it is worse for a reason specific to that
list's semantics: membership does not silence `structurallyIdentical`, it **flips** it into a
must-diverge assertion. So adding New York would permanently excuse the program's canary
jurisdiction from the byte-identity check that has guarded it since Phase 1. Mirroring also keeps
the JSON-load-failure fallback correct, which matters more for a rule than it did for Task 3b's
disclosure string: a user on that path would otherwise be over-taxed rather than merely unwarned.

A dedicated assertion restates it where the change is, so a future missed mirror produces a
message naming the reason rather than a line number in a re-encoded document:
`Phase5bNewYorkMilitaryTests.theLegacyMirrorWasUpdatedToo`.

### The golden case

NY-5, `RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json`: "Military retired pay
alone: fully excluded, Line 26, because a retired service member is an officer or employee of the
United States". Single filer, age 65, federal AGI $90,000, one `(definedBenefit,
uniformedServices)` row of $70,000, $20,000 of other ordinary income. No `knownDefect`: the engine
is correct here now and must stay correct.

`expectedStateTax` $487.75, hand-derived from New York's published schedule and NOT from engine
output. $90,000 less the $70,000 Line 26 subtraction leaves $20,000; less the $8,000 single
standard deduction (Line 34) leaves $12,000 taxable; $8,500 at 3.9% = $331.50, plus $3,200 at 4.4%
= $140.80, plus $300 at 5.15% = $15.45. Total $487.75. It is deliberately the same arithmetic as
NY-1, whose own `source` string derives that figure independently, which is the same
"same arithmetic as the case above" construction NY-3 and NY-4 already use.

**Proven capable of failing, by mutation rather than by reading.** Both the JSON and the legacy
mirror had `uniformedServices` temporarily removed and the two relevant suites were run:

```
tools/run-tests.sh GoldenScenarioSingleYearTests Phase5bNewYorkMilitaryTests
Swift Testing:  Test run with 12 tests in 2 suites failed
  GoldenScenarioSingleYearTests   ... 1 argument abbreviation -> "NY"
  Phase5bNewYorkMilitaryTests     ... 7 issues
  militaryRetiredPayIsUncappedInNewYork: abs(military - 487.75) -> 2695.25
```

The mutation was reverted and `git diff` confirmed both files back at the intended content before
anything was committed.

### Baseline movement: NONE, and this needs stating because the brief expected one

The brief said a New York behaviour change would be the phase's first baseline movement and would
need a ledger entry with a MEASURED `after`. It does not, and no entry was written.

`StateTaxBehaviorBaselineTests.computedTax` (`:168-177`) builds its pension rows as
`IncomeSource(name:type:annualAmount:)` with no classification, so
`RetirementPlanClassification.infer(incomeType:)` returns `(unknown, unknown)` for `.pension`.
Widening `matchSources` cannot match `.unknown`. This is the same reasoning that keeps Kansas off
`layerAProvenDivergentJurisdictions`, recorded in that file's own comment as MEASURED rather than
argued. Confirmed here by measurement too: the frozen 1,020-value baseline test passes untouched,
`statetax-behavior-movements-2026.json` carries no New York entry, and the full suite is green.
Phase 5b still records zero baseline movements.

### Railroad Retirement: recorded, not shipped

Treated separately, as instructed, and deliberately NOT widened. New York's fixture cites no
provision covering Railroad Retirement Board benefits, and Step 1 forbids re-researching the law,
so the answer is not derivable from what this repository carries.

The quoted authority also argues actively against the easy guess, which is the part worth keeping:
Line 26's eligibility list is CLOSED, and a railroad retiree was an employee of a private carrier,
not of the United States. Whatever exempts these benefits in New York is therefore a different
mechanism from Line 26, and encoding it as a Line 26 per-source rule would put an uncited claim
into a shipped config. That is exactly the distinction that makes the military widening safe and
this one not.

Recorded as a new `knownButUnpinned` entry for `NY`, with a non-vacuous deletion guard
(`Phase5bNewYorkMilitaryTests.theRailroadRetirementQuestionStaysRecorded`) that re-derives both
legs: the rule still does not name `railroadRetirement`, and the row is still picker-reachable for
a New York resident. The entry notes that the identical question is open for Arizona and
Massachusetts and that one reviewed pass over 45 U.S.C. 231m and the three states' forms would
close all three at once.

### Other coverage added with the widening

`RetireSmartIRATests/Phase5bNewYorkMilitaryTests.swift` (new file; the test target uses
`PBXFileSystemSynchronizedRootGroup`, so no project-file edit is needed). It pins the rule shape,
sweeps `PlanSource.allCases` for what the rule matches and does not (`otherStateOrLocal` is the
load-bearing exclusion), measures the end-to-end figures, asserts the two encodings agree, checks
the picker row is offered to a New York resident and that Task 3's own-state suppression is
untouched, and sweeps the `DataManager` breakdown mirror over every source. The mirror sweep is
not optional bookkeeping: that mirror hand-duplicates the engine's partition and has drifted from
it five times on this branch.

---

## IMPORTANT 2. DC's survivor rule and the non-resident

### RECORDED, with its own entry and deletion guard, not fixed

The reviewer's finding is confirmed exactly. `IncomeSourcesView.swift:1501` shows the toggle and
`:1765` gates the save, both on
`residenceUsesSurvivorDimension(dataManager.selectedState)`, i.e. residence; that toggle is the
only writer of `IncomeSource.isSurvivorBenefit`; `StateComparisonView` computes every
jurisdiction's tax for a non-resident; and `DataManager.incomeSources(asResidentOf:)` remaps
`planSource` only, so the flag arrives at DC's column as `nil`. The measured cost at DC-2's shape
is the full $1,924.00, and it is asserted in the guard rather than quoted from the brief.

It is recorded rather than fixed, and the reason is that every correct fix is a product decision
about who gets asked a question, which is out of scope for a review fix and is John's to approve:

- Widening the gate to "any jurisdiction ships a survivor rule" puts a third question, plus the
  DC-specific caption John approved on 2026-08-05, in front of every user in all fifty-one
  jurisdictions, for a fact that cannot move a dollar of their own tax. That is precisely the
  noise `residenceUsesSurvivorDimension`'s own doc comment declines to make and that
  `shouldPromptForClassification` declines before it.
- The narrower shapes (ask on entering State Comparison; ask only for the jurisdictions on screen;
  disclose instead of asking) each need new user-facing copy, and all Phase 5b copy is approved as
  it stands.
- The disclosure route is blocked for the same reason the existing DC entry names:
  `showsUnclassifiedPensionLimitation` gates on `hasUnclassifiedPension`, and this pension is
  perfectly classified.

The reviewer is right that this is a different and permanent population from the existing DC
entry: that one closes for any DC resident who re-opens their row, this one never closes for
anybody. So it is a second `DC` entry rather than an extension of the first, and it names the
smaller option to weigh first, which is a viewed-state sibling of the residence-keyed disclosure
the existing entry already asks for. The two want one mechanism with two gates, exactly as
`showsUnclassifiedPensionLimitation` and `MultiYearCPABriefing.unclassifiedPensionLimitation`
already are.

Guard: `Phase5bDCSurvivorTests.theNonResidentSurvivorGapStaysRecorded`, non-vacuous on three legs
re-derived from live code (the affordance is residence-gated, swept over `USState.allCases`
rather than asserted for California alone; DC's rule still requires the flag; and the DC column
for a California survivor still reports $1,924.00 through the same breakdown path State
Comparison reads).

**Also fixed while here:** the pre-existing DC guard selected with `.first { $0.state == "DC" }`.
With two DC entries that is the ambiguity the Massachusetts pair already documents, so it now
selects on content. No guard was removed.

---

## IMPORTANT 3. The three missing deletion guards

Confirmed by grep across the test target: eight of the eleven entries had a guard, and the three
named had none. `knownButUnpinnedIsWellFormed` asserts only that the array is non-empty and that
each entry's two strings are non-blank, so all three deleted in silence. The Massachusetts case is
the subtlest: `Phase5bMassachusettsPerSourceTests.theContributoryGapStaysRecorded` selects on
`summary.contains("NONCONTRIBUTORY")`, which is the OTHER Massachusetts entry, and
`federalCivilianIsTaxedInFullToday` pins the figure but never touches the catalogue.

Three guards added, each non-vacuous, each re-deriving its condition from live code so the entry
cannot outlive the defect either:

| Entry | Guard | What it re-derives |
|---|---|---|
| KS, the TSP gap | `Phase5bKansasPerSourceTests.theThriftSavingsPlanGapStaysRecorded` | The rule still declines a federal `definedContribution` plan, AND no `PlanClassificationChoice` case writes one, which is the blocker itself |
| MA, federal civilian and railroad | `Phase5bMassachusettsPerSourceTests.theFederalCivilianGapStaysRecorded` | Neither `federalCivilian` nor `railroadRetirement` is matched by the shipped rule, and both rows are picker-reachable in Massachusetts |
| MO, the uncapped public-pension exemption | `GoldenScenarioDefectCatalogueTests.theMissouriPublicPensionCapGapStaysRecorded` | Missouri's shipped `pensionExemption` is still `.full` |

Missouri's lives in the catalogue file for want of a Missouri suite, since Missouri was never a
Phase 5b jurisdiction. That is weaker than the others only in that a deleter has the entry and the
guard on screen at once; it is not weaker in what it proves. The doc comment says to move it the
moment a Missouri suite exists.

**Ledger corrected**, which was the part of this finding that mattered most, since the ledger is
the one document the next phase acts on. The "ARTIFACTS THAT MUST NOT BE RETIRED" entry said "all
eleven" and named `Phase5bKansasPerSourceTests` among the files holding guards; both halves were
false. It now says thirteen, names the two files that actually hold the new guards, and carries an
explicit correction paragraph stating which three had none and why they deleted silently. The
headline counts elsewhere in the ledger were corrected in the same pass: 11 entries to 13, 218
golden scenarios to 219, and the PRODUCTION DIFF section now records the New York rule change,
the Layer B handling and the railroad decision.

---

## MINOR 4. Tripwires for Hawaii and North Carolina

Added to both, matching the Idaho and Vermont shape: a `Mirror` over
`PerSourceExemptionRule`'s stored-property set, failing when a new matching dimension arrives.

- `Phase5bHawaiiDecisionTests.noPerSourceMatchingDimensionCanExpressTheFundingSplit`, which also
  demonstrates that `treatment` cannot be pressed into service as a proportion, since a `.partial`
  is evaluated per row.
- `Phase5bNorthCarolinaDecisionTests.noPerSourceMatchingDimensionCanCarryBaileyMembership`, which
  also warns that `matchMinAge` is not such a dimension and must not be mistaken for one: the
  Bailey class is defined by service credit as of a fixed date, not by age.

See the disagreement below about the stated rationale for Hawaii.

---

## MINOR 5. The four false doc comments

All four confirmed against the code and corrected. Each correction says what the comment used to
claim as well as what is true, so a reader who half-remembers the old text is not left wondering.

- `RetirementPlanClassification.swift:115` said "nothing yet reads this flag when matching" and
  that wiring it was later Task work. Task 9 wired it; the comment now traces the flag through
  `PerSourceExemptionRule.matches`, `TaxCalculationEngine`, the `DataManager` mirror,
  `MultiYearInputAdapter` and `ProjectionEngine`, and keeps the `Bool?`-over-`Bool` rationale.
- `StateTaxCodable.swift:329` said the key appears only in "New York and Kansas today". Five
  jurisdictions ship both keys (verified by grep over the 51 bundled files: AZ, DC, KS, MA, NY).
  The `perSourceExemptions` comment three lines above was stale in the same way, saying "New
  York's shipped file only", and was corrected too. The corrected text also notes that the four
  no-rule jurisdictions are on the omitted side by decision rather than by default.
- `DataManager.swift:589` forecast that the `ownStateOrLocal` staleness defect would go further
  live with "Tasks 4, 8 and 9 (Massachusetts, Idaho and Vermont)". Two thirds of that forecast
  did not happen: Idaho and Vermont ship nothing. The namers today are KS, MA and DC.
- `IncomeSourcesView.swift:1544` said the North Carolina caption ships "unapproved", three lines
  below the approval. Corrected, with a parenthetical saying the cross-reference was written
  before the approval landed and left uncorrected when it did.

---

## MINOR 6. `choice(for:)` and the survivor flag

Confirmed and fixed. `RetirementPlanClassification` gained a third stored property in Task 9, so
its synthesized `==` compares `isSurvivorBenefit`, while every entry in `choice(for:)`'s
hand-maintained priority list carries `nil`. A whole-value `==` therefore falls through to
`.notSure` for any survivor-flagged classification, which would display an
already-correctly-classified DC survivor annuity as unclassified and rewrite it on save. It is the
exact silent fallthrough that function's own doc comment warns about, arriving by a route the
warning did not anticipate.

Fixed by comparing `structure` and `source` explicitly. That is the right fix rather than a
narrower one: the survivor fact is a separate toggle beside the picker, not something the twelve
rows express, so the reverse lookup should never have been consulting it. Behaviour is unchanged
today, because both call sites build the classification from structure and source alone and
`IRAAccount` has no survivor field at all, but this function is the wrong place to depend on that.

`Phase3bPresentationTests.reverseLookupIgnoresTheSurvivorFlag` sweeps the same cases as
`reverseLookupRoundTrips` with the flag set both ways, which is the blind spot the existing sweep
could not cover.

---

## DISAGREEMENTS AND CORRECTIONS TO THE BRIEF

**MINOR 4's rationale is wrong about Hawaii, though its conclusion stands.** The brief says
Hawaii carries "only `PlanSource.allCases` sweeps" and that "nothing will re-open Hawaii" when a
contributory axis arrives. Hawaii already has a reflective tripwire:
`Phase5bHawaiiDecisionTests.theModelCarriesNoFundingAxis` (`:193-212`) asserts
`RetirementPlanClassification`'s encoded key set is exactly
`["structure", "source", "isSurvivorBenefit"]`, and its failure message reads "If a funding or
contributory axis was added, Hawaii's decision changes and this whole file, the HI
`knownButUnpinned` entry and the Massachusetts contributory entry should be revisited together."
That is precisely the arrival route Hawaii's own entry recommends for the axis, and it is covered.

What was genuinely missing is narrower and still worth closing: neither Hawaii nor North Carolina
had anything watching `PerSourceExemptionRule`'s field set, which is how `matchIsSurvivorBenefit`
and `matchMinAge` actually arrived in Task 9 and how Idaho was legitimately re-opened. A funding
dimension could arrive that way without touching the classification. Both tripwires were added on
that narrower and correct ground. North Carolina's file (`:167-169`) explicitly delegates the
classification-key check to Hawaii's test, so it was relying on coverage that existed; it was the
rule-field route that neither had.

**SUPERSEDED, see the verification round below.** "Roughly $2,200 a
year" for a $60,000 New York military pension is right ($2,155.25 by hand at that shape). The
figure at NY-5's shape, which is what ships, is $2,695.25, and it is MEASURED: the mutation run
above reported `abs(military - 487.75) -> 2695.25`. DC's $1,924.00 is right and is now asserted
rather than quoted.

**Nothing else in the brief was contradicted by the code.** Every file and line reference it gave
resolved to what it said, including the eleven `knownButUnpinned` line numbers, the eight existing
guards, the `NONCONTRIBUTORY` selector problem, and all four stale doc comments.

---

## BINDING CONSTRAINTS: compliance

- No `knownDefect.observedToday`, no `tier`, no `expectedStateTax` was edited. No `knownDefect`
  block was deleted. The only fixture change is one ADDED scenario carrying no `knownDefect`.
- The frozen 1,020-value baseline did not move and no movement-ledger entry was written. See
  CRITICAL 1 above for why the expected movement did not occur, measured rather than assumed.
- NY-5's expected value is derived from New York's published bracket schedule and standard
  deduction, never from engine output, and the derivation is written out in the fixture's own
  `source` string.
- No capped per-source `treatment` was introduced. New York's stays `full`; the $20,000 cap stays
  where it already was, on the pooled `pensionExemption`.
- `rulesAndDisclosuresStayInLockstep`, all existing `knownButUnpinned` entries, all existing
  deletion guards and all captions are intact. Two entries and five guards were ADDED; one
  existing guard's selector was tightened to disambiguate two same-state entries, which removes
  nothing.
- No decided jurisdiction was re-opened. Hawaii, North Carolina, Idaho and Vermont all still ship
  no rule; the two tripwires added are watchers, not rules.
- No approved copy was changed. The only user-facing string touched is a code COMMENT above the
  North Carolina caption; the caption text itself is byte-identical.
- No em dash characters. `git diff -U0 | grep '^+' | grep -c` for the character returns 0, and the
  new file returns 0.

---

## FULL SUITE

Run in the foreground with a 600000 ms timeout, at the state that was committed.

```
$ tools/run-tests.sh

Project:  /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ 1125213
Scope:    full suite, five to six minutes. Run this in the FOREGROUND.

================ RESULT ================
Swift Testing:  Test run with 2035 tests in 305 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2544 test(s) ran, no failures.
```

Was 2,020 in 304 suites plus 509. Now 2,035 in 305 suites plus 509: one new suite
(`Phase5bNewYorkMilitaryTests`) and 15 net new tests, counting parameterised cases as one.

**No `MultiYearPerfTests` flake on this run.** The wrapper's isolation re-run was not triggered,
so there is nothing to qualify. The 6 pre-existing env-gated skips are unchanged.

The wrapper's own header confirms it built THIS worktree. The `@ 1125213` in the header is the
commit the run started from; the working tree carried these changes, and the run above is the
final one, made after the mutation experiment had been reverted and verified with `git diff`.

---

# VERIFICATION ROUND: three Minors from the independent verifier

The New York change was independently verified SAFE TO MERGE with no Critical or Important
findings: the verifier re-derived $487.75 from the brackets, re-derived $3,183.00 and the
$2,695.25 delta, confirmed the `configs2026Legacy` mirror is exact and that `structurallyIdentical`
still binds New York, confirmed at the baseline test's row construction that no frozen value could
move, confirmed no over-match across `PlanSource.allCases`, and confirmed both entry paths for
military pay land on $487.75. The railroad restraint was upheld and the Hawaii disagreement was
confirmed correct. Three Minors followed, all three fixed below in one commit.

## MINOR 1. The new NY guard used the selector shape this same commit fixed elsewhere

Confirmed and fixed. `theRailroadRetirementQuestionStaysRecorded` selected
`knownButUnpinned.first { $0.state == "NY" }` with no content predicate, which is exactly the
pattern tightened for DC and written on content for both Massachusetts guards in the same commit.
The verifier's point about WHY it matters here is sharper than the general rule: the entry's own
text names a future New York golden case as the resolution, so it actively invites the second
entry that breaks it. Now selects on
`summary.contains("RAILROAD RETIREMENT benefits is unresolved")`, with a comment saying why.

## MINOR 2. "Roughly $2,200 a year on a $60,000 pension" does not reproduce

Confirmed, and re-derived independently before changing anything rather than taken on the
verifier's word. A single filer at 65 whose only income is a $60,000 military pension: $60,000
less the capped $20,000 less the $8,000 standard deduction leaves $32,000 taxable, which walks to
$331.50 + $140.80 + $113.30 + ($18,100 at 5.4% = $977.40) = **$1,563.00**, against $0.00 after the
widening. The verifier's $1,563.00 is right. My $2,200-ish figure was inherited from the review
brief and I reproduced it at a shape carrying $20,000 of other income without ever saying so. It
sat in derivation-grade surroundings, which is what makes it worth fixing even though nothing
asserted on it.

Corrected in all four places it had reached, not the three named: `StateTaxData.swift`'s shipped
comment, NY-5's fixture `source` string, the close-out ledger, and the new test file's header and
one failure message, which the brief did not list. Each now states BOTH shapes with their
arithmetic rather than one round number, because the honest answer is that the cost depends on the
household's other income.

**And the $60,000-only figure is no longer narrative.**
`militaryRetiredPayIsUncappedInNewYork` now asserts $1,563.00 on the capped path and $0.00 on the
widened one at that shape, so both figures quoted in prose are pinned by arithmetic that runs.
That is the durable fix; correcting the sentences alone would have left the next figure free to
drift the same way.

The ledger carries the incident as a method note rather than a silent edit: **a dollar figure in a
fixture, a config comment or the ledger must be re-derivable from the inputs stated next to it, or
it must name the shape it belongs to.** John was given the wrong figure, so the record needs to
show the correction and not just the corrected number.

## MINOR 3. `Phase3bPerSourceExemptionCapTests.nyShapedConfig()`

Confirmed and fixed by correcting the doc comment rather than the config. Nothing numeric is
wrong: it is a synthetic flat-rate config whose whole purpose is cap mechanics (one pool, one cap,
the per-individual doubling, and the independence of the per-source exclusion from the pooled
one), none of which turns on which sources the rule names. Bringing the source list into line
would have coupled a mechanics fixture to a jurisdiction's live rule for no benefit. The comment
no longer claims to be "NY's actual Section 612(c)(3-a) shape", says explicitly that it is not the
shipped rule, says why the narrower pair is kept deliberately, and points at
`Phase5bNewYorkMilitaryTests` as what pins the real one.

## RECORDED, NOT FIXED: NY-5 is pinned on the single-year path only

`GoldenScenarioMultiYearTests.pilot` is `["PA", "IL", "MS"]`, so no New York fixture case, NY-5
included, is exercised through the multi-year path. This is a pre-existing harness boundary that
predates the branch and that this change did not move: every New York case has always been
single-year-only, and the same is true of the four jurisdictions Phase 5b corrected. The exposure
is also small for this particular change, because the multi-year classification path is
source-agnostic: `MultiYearInputAdapter` carries the pooled classification through without
consulting `matchSources`, and the rule is evaluated by the same
`RetirementIncomeExemptions.matchedPerSourceRule` on both paths. Widening the pilot is a harness
decision for a later phase, not something to fold into a review fix.

## FULL SUITE, at the committed state of the verification round

Command and result are in the closing section of this report, which was re-run after these three
fixes landed.
