# Phase 5b Task 4: Massachusetts

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`, branch
`feature/state-tax-phase5b`, started at HEAD `de85081`, working tree clean at start.

Status: COMPLETE and SHIPPED. Review passed with no Critical findings and its fixes are applied. John
decided on 2026-08-05 to SHIP the rule as written rather than take the section 13 reversal, and
approved both Massachusetts copy items (the `unclassifiedPensionDisclosure` sentence and the pension
picker caption) as they stand, and separately approved Task 3's three picker labels AS IS. No copy
string changed in either pass; only the metadata around them.

Full suite green, 1,938 Swift Testing in 298 suites plus 509 XCTest, 2,447 total, zero failures, no
`MultiYearPerfTests` flake on any full run.

---

## 1. THE JUDGEMENT: the mapping is a forced fit, and the axis is not Massachusetts-only

**Determination (b). `governmentUnspecified` is not a legitimate noncontributory marker, and MA-2 was
never a contributory guard.**

The enum says so itself. `PlanSource.governmentUnspecified`'s doc comment
(`RetireSmartIRA/RetirementPlanClassification.swift:70-77`) defines it as "a government employer whose
jurisdiction was not established" and closes with "No rule may match this case as though it were a
specific jurisdiction." Nothing in it is about funding.

The decisive test is not what the case MEANS but what MA-2 can PROVE. MA-2 carries
`(definedBenefit, governmentUnspecified)`. No rule shipping in this phase names
`governmentUnspecified`, so MA-2 passes whether the Massachusetts rule respects the contributory
distinction or ignores it completely. It cannot fail for a contributory reason, so it is not evidence
about contributory treatment. It is a real and load-bearing guard, in exactly Kansas KS-8's role, and
I have renamed and re-sourced it to say that. Its data (source, amount, `expectedStateTax` 3000.00,
no `knownDefect`) is untouched.

**What Massachusetts actually needs:** a THIRD classification axis, employee-contributory against
employer-funded, on `RetirementPlanClassification`, matched by `PerSourceExemptionRule`, with a picker
affordance so a real user can state it and a migration default for every saved row that cannot.

**It is not a Massachusetts quirk, and I have two independent pieces of evidence the brief did not
carry:**

1. **Hawaii's golden fixture, Task 5, turns on the same axis inverted.**
   `RetireSmartIRATests/GoldenScenarios/statetax-2026-HI.golden.json` scenario 1 is "fully
   employer-funded (noncontributory) private-sector pension: fully exempt" and scenario 2 is "401(k)
   elective-deferral distribution: correctly fully taxable (employee-funded)". Hawaii exempts what
   Massachusetts taxes. Hawaii's fixture proxies the axis through `PlanStructure`
   (`definedBenefit` against `definedContribution`); Massachusetts's proxied it through `PlanSource`.
   Two jurisdictions, two incompatible forced proxies for the same distinction, is the signature of a
   missing dimension rather than a one-state oddity.

2. **The gap is ALREADY disclosed in shipped production UI, for Hawaii.**
   `RetireSmartIRA/IncomeSourcesView.swift` carries a `selectedState == .hawaii` caption: "Hawaii
   excludes the employer-funded portion of a pension from state tax. This app does not model the split
   between employer-funded and employee-contributed amounts, so your Hawaii state tax may be
   overstated." That string predates this phase. The axis was a known product gap before Task 4
   noticed it.

**Where the axis belongs: NOT here, and I did not build it.** Three reasons.

- It has to serve Hawaii's inversion, and Hawaii's authority-derived fixture is Task 5's to read.
  Designing a persisted, user-facing axis from Massachusetts's four cases and a guess at Hawaii is
  exactly the "invent it on a fixture set of four cases" failure, and if Task 5 then needs a different
  shape it has to redesign something already shipped into user saves.
- The phase's own ordering is that a shared classification axis lands in the MODEL task and is
  consumed by the jurisdiction tasks. Task 1 added `isSurvivorBenefit` and explicitly left its
  rule-matching consumption to Task 9. A jurisdiction task inventing an axis inverts that for every
  task after it.
- **A half-built axis is worse than none, and this is the concrete failure mode.** If I added
  `isEmployeeContributory` and required `== true` in Massachusetts's rule WITHOUT adding picker rows,
  every real Massachusetts user's row would carry `nil`, the rule would not match, every golden case
  would be green, and every Massachusetts contributory retiree would still be over-taxed. That is
  precisely the Kansas defect Task 3 was created to fix, reproduced one state over with a green suite.
  Closing it needs new picker rows, which is user-facing copy John approves, plus the reverse-lookup
  priority array, plus the `DataManager` mirror. Out of scope for Task 4.

### 1a. What that means for whether Massachusetts can be called complete

**It cannot.** The residual is REACHABLE by a real user and it runs toward UNDER-taxation:

- A Massachusetts resident with a noncontributory municipal pension opens the pension picker.
- The only row they can honestly select is "Government pension, my own state or locality".
- That row writes `(definedBenefit, ownStateOrLocal)`, which the shipped rule matches.
- They receive a full exclusion they are not owed: $0.00 against $3,000.00 on the fixture's own
  $60,000 single filer at the flat 5% rate.

I took this seriously and did not wave it through. Three things were done about it, and none is prose
in a report:

1. **`GoldenScenarioDefectCatalogueTests.knownButUnpinned` gained an MA entry** with the mechanism,
   the measured figures, the direction, and the blocker. This is the program's own established
   artifact for a defect no fixture can hold, and it is DATA, checked by a test.
2. **A test pins the record itself.** `Phase5bMassachusettsPerSourceTests.theContributoryGapStaysRecorded`
   fails if the entry is deleted, and also re-asserts that the rule really does match the row such a
   user would select. The judgement cannot quietly evaporate into a report nobody re-reads.
3. **A production caption now reaches the affected user** (section 6 below), modelled on the shipped
   Hawaii one.

### 1b. Why I did NOT write a golden case for the noncontributory household, and why that is the point

I tried this first, as the shared procedure's Step 3 instructs ("If the fixture set has no case that
would catch that, ADD one"), and rejected it on inspection.

Such a case would be: single, age 66, $60,000, `(definedBenefit, ownStateOrLocal)`, expected
$3,000.00. MA-1 is: single, age 66, $60,000, `(definedBenefit, ownStateOrLocal)`, expected $0.00.
**Byte-identical inputs, contradictory expected values.** The fixture set would assert a
contradiction rather than a defect, and no engine could satisfy both.

That failure IS the proof of the judgement. Step 3's remedy is unavailable here precisely because the
model cannot express the distinction, which is the same shape as the Kansas TSP entry's blocker
("NOT EXPRESSIBLE"), reached by a different route: the Kansas household cannot be described at all,
the Massachusetts one cannot be described DISTINGUISHABLY from an oppositely-treated household.

**Corrected after review.** I originally widened kind 2 only in the ENTRY text, leaving the shared
doc comment defining it as "The household itself cannot be described in the app's model" - under
which a contributor checking their finding against the stated definition would not have recognised
Massachusetts's case, since its household CAN be described, just not distinguishably. The kind-2
definition in `GoldenScenarioDefectCatalogueTests.swift` now names both routes explicitly and cites
Massachusetts as the example of the second.

---

## 2. The rule, and what I deliberately made it NOT match

`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-MA.json`, one rule, mirroring Kansas's
shape:

```json
"perSourceExemptions" : [
  {
    "matchSources" : [ "ownStateOrLocal", "uniformedServices" ],
    "matchStructures" : [ "definedBenefit" ],
    "treatment" : { "kind" : "full" }
  }
]
```

**Deliberately NOT matched, and each is swept by `unnamedSourcesAreNotMatched`, whose argument list is
DERIVED from `PlanSource.allCases` so a case a later task adds is rejected by default:**

- **`unknown`.** The migration default on every pre-Phase-3b saved row. Matching it would hand a full
  Massachusetts exclusion to every unclassified pension in every existing user save. Same reasoning
  Kansas used, and I asked the question the brief told me to ask rather than copying the answer.
- **`otherStateOrLocal`.** A different state's system. Massachusetts is the one jurisdiction in this
  phase where a maintainer has a PLAUSIBLE reason to widen onto it and be wrong, because mass.gov's
  enumerated exempt list does include out-of-state contributory pensions from RECIPROCATING states.
  That is a per-state reciprocity table this app does not have.
- **`governmentUnspecified`.** MA-2, plus the enum's own prohibition.
- **`federalCivilian` and `railroadRetirement`.** See section 5, disclosed under-match.
- **`nyStateOrLocal`, `privateEmployer`, `individual`.**
- **Every structure other than `definedBenefit`.** The exclusion is for contributory ANNUITY, pension,
  endowment and retirement funds of the Commonwealth, not a Massachusetts state employee's 457
  deferred compensation, which is employee salary reduction.
  `PlanClassificationChoice.governmentSalaryReduction` is a row a real user can already select, so
  dropping the constraint would auto-exempt it on no authority. No MA fixture row that the rule
  matches is anything but `definedBenefit`, so `matchStructures` could be deleted outright and every
  golden case would stay green; `namedSourceInAnotherStructureIsNotMatched` is what catches that.

### 2a. Guard cases: MA-2 is NOT sufficient, and my out-of-state guard is deliberately NOT a golden case

The controller asked me to decide. MA-2 covers unestablished-jurisdiction (KS-8's role). Massachusetts
had no equivalent of KS-7 (out-of-state) and no migration-default guard.

Kansas pinned KS-7 with a dollar figure on a California public pension. **I deliberately did not do
that for Massachusetts.** Asserting "$3,000.00 on a California public pension held by an MA resident"
asserts that California does not reciprocate with Massachusetts, and I have no primary source for
that in hand. This phase DELETED a Missouri scenario rather than ship a figure on a secondary source
(`knownButUnpinned`, MO entry); shipping an unverified reciprocity claim into a fixture would be the
same error.

The guard therefore lives in Swift as a MATCH-level assertion, which needs no reciprocity law at all:
`Phase5bMassachusettsPerSourceTests.outOfStateIsNotMatched`, plus the derived `allCases` sweep that
covers it and the migration default together. I consider the sweep strictly stronger than a golden
case for the match question, because it cannot go stale when a `PlanSource` case is added.

---

## 3. Fixture re-labels, and how I confirmed which case is which

I confirmed each against the case's own `name` and `source` text rather than trusting the brief's
list. All four checked out. The brief's warning not to read Task 2's forward-handing prose as evidence
the labels were already fixed was correct: MA-1 and MA-3 carried `otherStateOrLocal` and MA-4 carried
`federalCivilian` at `de85081`.

| Case | Was | Now | Confirmed by |
|---|---|---|---|
| MA-1 | `otherStateOrLocal` | `ownStateOrLocal` | name and source both say "Massachusetts state contributory pension", source quotes "funds of the Commonwealth of Massachusetts (or any of its political subdivisions)". That is the taxpayer's OWN state. |
| MA-2 | `governmentUnspecified` | **unchanged** | Section 1. Data untouched; name and source corrected to describe what the row encodes. |
| MA-3 | `otherStateOrLocal` x2 | `ownStateOrLocal` x2 | name says "both spouses have MA state/local contributory pensions"; same mass.gov section as MA-1. |
| MA-4 | `federalCivilian` | `uniformedServices` | source quotes the 'U.S. military non-contributory pension' section verbatim. The second row (`privateEmployer`, `definedContribution`) is untouched and correct. |

All the "LABEL STILL WRONG, RE-LABEL IN TASK 4" prose was rewritten to record what was done, per the
brief. I did NOT rename MA-1, MA-3 or MA-4, following Task 3's precedent (KS-4's name still describes
its resolved defect). MA-2 IS renamed, because its old name was not a stale defect description but a
false claim about what the row encodes. Verified safe: no entry in
`statetax-behavior-movements-2026.json` references any MA scenario name (the ledger holds only GA, IA,
NM and UT, 75 entries), and `goldenCase` is the only machine-checked name reference.

---

## 4. `knownDefect` blocks deleted, with MEASURED figures

Three deleted, whole blocks, nothing edited.

| Case | `observedToday` (before, measured at `de85081`) | Form value | After (measured) |
|---|---|---|---|
| MA-1 | 3000.00 | 0.00 | **0.00** |
| MA-3 | 3750.00 | 0.00 | **0.00** |
| MA-4 | 3000.00 | 1500.00 | **1500.00** |

The `before` figures are the pinned values that were passing at `de85081`, i.e. measured by the suite
rather than asserted by me. The `after` figures are measured by the green run: with the blocks gone,
`GoldenScenarioSingleYearTests.classify` returns `.matchesForm` for all three, which is only reachable
when the engine is within $0.01 of `expectedStateTax`. A wrong number would have produced
`.unexplainedDisagreement` and named both values.

**Procedural deviation, disclosed.** Steps 4 and 5 describe running the suite, seeing "delete the
knownDefect block", then deleting. I shipped the rule and the deletions together, so I never saw that
message. The verification is equivalent and I consider it stronger: a surviving block would have
failed with `.defectAppearsFixed`, and a wrong rule would have failed with
`.unexplainedDisagreement`. Green means the engine now matches the published form for all three.

**No `knownDefect` failed to resolve.** MA-2 continues to pass with no defect block, at 3000.00.

---

## 5. Disclosed under-match: `federalCivilian` and `railroadRetirement`

**CORRECTED after review.** My first version of this section called this a case where "the fixture
disagrees with itself". Re-reading the two strings against each other, **that was too strong and I
withdraw it.** They are reconcilable: MA-2 says federal contributory pensions are exempt under their
own heading, and MA-4 says only that the MILITARY exclusion must not be expressed via
`federalCivilian`, because mass.gov treats federal civilian pay under a SEPARATE heading. Nothing in
MA-4 asserts that federal civilian pensions are taxable. That makes this a straightforward,
confirmed-mechanism UNDER-MATCH rather than an unresolved contradiction, which is a stronger finding
than I originally reported, and it is why it now has a `knownButUnpinned` entry.

MA-2's source enumerates mass.gov's exempt categories as "MA/local contributory, **federal
contributory**, MBTA, out-of-state reciprocal contributory, **railroad retirement**, U.S.
uniformed-services noncontributory". So Massachusetts appears to exclude CSRS/FERS and Railroad
Retirement too.

But MA-4's source says the opposite in emphasis: "mass.gov's guidance exempts U.S. military pensions,
and separately treats federal CIVILIAN (CSRS/FERS) pensions under a different heading, so a rule
naming 'federalCivilian' would over-exempt."

No Massachusetts golden case pins a `federalCivilian` or `railroadRetirement` figure. Under Step 1 the
fixture is the specification, and writing a rule for a category no fixture pins would be writing law
from an unpinned enumeration. **I named neither.** The resulting under-match errs toward
over-taxation, the safe direction, and it is disclosed here rather than guessed at, exactly as Kansas
disclosed its TSP under-match.

**Now recorded durably, per review.** I originally left this in prose only, which was inconsistent
with the standard I applied to the contributory gap in the same report ("none is prose in a report").
Review was right to call that out. It now has:

- a `knownButUnpinned` MA entry with the mechanism, the measured figures and the blocker, and
- `Phase5bMassachusettsPerSourceTests.federalCivilianIsTaxedInFullToday`, which pins the $3,000.00
  cost for both `federalCivilian` and `railroadRetirement` and goes RED the day anyone widens the
  rule, forcing that widening to arrive with reviewed golden cases rather than quietly.

**Blocker, stated precisely because it fits neither existing kind cleanly:** the household IS
expressible (`PlanClassificationChoice.federalCivilianPension` writes it and a user can select it
today), so it is not kind 2; and the missing thing is not a dollar amount but a REVIEWED derivation of
the rule, so it is kind 1 in shape only. The sole statement of these categories on this branch is a
paraphrase inside MA-2's `source` prose, not a quoted primary source, and Step 1 forbids researching
the law again. I deliberately did not widen the rule from a paraphrase.

**Recommended follow-up (not mine to do):** a reviewed primary-source pass over mass.gov adding MA
golden cases for a federal civilian pension and a Railroad Retirement benefit, then widen the rule to
whatever those cases support and delete the `knownButUnpinned` entry in the same change. Note the same
contributory-axis caveat applies, since mass.gov's category is federal CONTRIBUTORY, though every
federal civilian annuity is contributory in practice.

---

## 6. Picker reachability: CONFIRMED, not assumed

- `PlanClassificationChoice.residenceNamesItsOwnJurisdiction(.massachusetts)` is **false**.
  `jurisdictionNamedSources` is `[.nyStateOrLocal: .newYork]`, and Massachusetts's config names
  `ownStateOrLocal`, not `nyStateOrLocal`, so the `== state` comparison never fires. Massachusetts
  does NOT suppress, which is required: suppression would leave a Massachusetts contributory retiree
  with no row writing `ownStateOrLocal` at all, every golden case green, and no real user able to
  reach the exclusion. That is the exact failure Task 3 was created to fix.
- `options(for: .massachusetts, selected: nil)` returns `allCases` and contains both
  `.ownStateGovernmentPension` and `.uniformedServicesPension`.
- **Reachability is asserted end to end, not just structurally.** `pickerOffersTheRowsTheRuleNeeds`
  takes what each row WRITES (`choice.classification`) and feeds it to
  `matchedPerSourceRule`, so a row that existed but whose classification drifted would fail.
- **Production wiring verified.** Both call sites pass the resident's own state:
  `IncomeSourcesView.swift:1306` and `AccountsView.swift:310`, both
  `options(for: dataManager.selectedState, selected: planChoice)`.

**One production change made. Copy APPROVED by John on 2026-08-05.** `IncomeSourcesView.swift` now carries a
`selectedState == .massachusetts` caption in the pension classification section, immediately after the
shipped Hawaii one it is modelled on:

> Massachusetts excludes a contributory state or local pension but taxes a noncontributory one. This
> app does not model that distinction, so if your pension is noncontributory your Massachusetts state
> tax may be understated.

I shipped it rather than only proposing it because it is the ONLY surface that reaches the affected
user, the direction is under-taxation, and an identically shaped string for the identical gap is
already live for Hawaii. It is inert to every computation. **John approved the wording on 2026-08-05
and it ships as it stands.** Like Hawaii's, it has no test seam, so it can be deleted silently; the
durable guard is the `knownButUnpinned` entry, which is tested.

Task 3's three picker labels were a separate set of copy and John approved them AS IS on the same
date, so all twelve picker rows and both Massachusetts copy items are now approved. Their markers are
cleared too, and `Phase3bPresentationTests.newPickerLabelsAreApprovedAndPinned` still pins the exact
strings.

**Copy item for John, NOT changed by me:** `IncomeSourcesView.swift:1310` reads "Some states,
including New York and Kansas, tax government and private pensions differently." Massachusetts now
does too. "including" keeps it true, so I left user-facing copy alone.

---

## 7. Disclosure sentence: three options, and the one John APPROVED on 2026-08-05

`rulesAndDisclosuresStayInLockstep` makes this mandatory. Sentence one is in code; these are sentence
two, carrying `{scope}`.

**Option A, closest to Kansas's approved cadence:**
> Massachusetts excludes a Massachusetts state or local pension and U.S. military retired pay from
> state tax with no dollar cap, but {scope} taxes your pension in full until it is classified.

**Option B, RECOMMENDED, SHIPPED, and APPROVED by John on 2026-08-05:**
> Massachusetts excludes a contributory Massachusetts state or local pension and U.S. military retired
> pay from state tax with no dollar cap, but {scope} taxes your pension in full until it is classified.

**Option C, naming the limitation inline:**
> Massachusetts excludes a contributory Massachusetts state or local pension and U.S. military retired
> pay from state tax with no dollar cap, but {scope} taxes your pension in full until it is
> classified, and it cannot tell a contributory pension from a noncontributory one.

**Why B.** "contributory" is the statutory condition and it is the one word a reader can check against
their own plan, which matters more here than anywhere else in the program because it is the exact
thing the picker cannot ask. A costs one word and loses that. C mixes two messages at two different
readers: this disclosure only fires for an UNCLASSIFIED pension, while the contributory limitation
bites someone who has already classified, and that reader is served by the section 6 caption instead.

B passes `everyShippedSentenceIsWellFormed`: exactly one `{scope}`, names Massachusetts, does not
repeat the lead sentence, no em dash, ends in a period. Verified live on both surfaces by
`disclosureFiresOnBothSurfaces` (State Comparison renders "this figure", the CPA briefing "this plan").

---

## 8. Step 7 equivalence lists

**`phase5CorrectedJurisdictions`: ADDED**, with a doc bullet. Massachusetts's JSON now carries
`perSourceExemptions` and `unclassifiedPensionDisclosure`; `configs2026Legacy` is frozen and has
neither, so the re-encoded documents differ permanently. Layer B's assertion flips to "must diverge"
and passes.

**`layerAProvenDivergentJurisdictions`: NOT added**, on Kansas's SECOND reason and only that one, and
**MEASURED, not reasoned**. The Layer A grid builds its single `.pension` row with no classification,
so `IncomeSource.init` infers `(unknown, unknown)`; Massachusetts's rule names `ownStateOrLocal` and
`uniformedServices` at `definedBenefit`, none of which is `.unknown`, so `matchedPerSourceRule`
returns `nil` through both configs. Kansas's first reason (a `personalExemption` correction the grid
never reads) does not apply, since Massachusetts ships no `personalExemption` at all and this
correction is entirely `perSourceExemptions`.

Measurement performed exactly as Task 3 did: I temporarily added `.massachusetts` to the list and ran
the two suites. Output, verbatim:

```
✘ Test "Every jurisdiction computes identical state tax from JSON and from the legacy table"
  recorded an issue with 1 argument state → .massachusetts at
  StateTaxJSONEquivalenceTests.swift:533:13: Expectation failed: observedDivergence
```

Zero of the ten scenarios diverged. A "must diverge" assertion would fail Massachusetts forever in its
correct state, so it stays on the plain skip. Reverted, and the reasoning plus the measurement is
recorded in the declaration's doc comment.

---

## 9. Baseline movements: NONE, and that is measured

No entry was added to `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`. The
frozen 1,020-value baseline did not move, for the same mechanism as section 8:
`StateTaxBehaviorBaselineTests.computedTax` builds its `.pension` and `.rmd` rows unclassified, so
`.pension` infers `(unknown, unknown)` and `.rmd` infers `(ira, individual)`
(`RetirementPlanClassification.infer(incomeType:)`), and the Massachusetts rule matches neither.
Measured, not predicted: the baseline suite is green in the full run, and any unrecorded movement
fails it.

---

## 10. DataManager breakdown mirror: verified by mutation, then reverted

`DataManager.swift` hand-duplicates the engine's per-source partition and has drifted five times on
one branch. Both paths carry the Massachusetts rule.

`breakdownMirrorAgreesWithTheEngineForMassachusetts` sweeps `PlanSource.allCases` and asserts on each
that `stateTaxBreakdown(forState:).totalStateTax` equals `calculateStateTaxFromGross`, AND that the
breakdown ATTRIBUTES the exclusion to `pensionExemptAmount` rather than reaching the right total by
another route.

**Proved the check has teeth**, matching Task 3's standard. I replaced the breakdown's pension
partition with an unconditional `pooledPensionIncome += row.annualAmount` and ran the suite. It failed
on both halves for both matched sources:

```
✘ ... source → .ownStateOrLocal: (abs(breakdown.totalStateTax - computed) → 3000.0) < 0.01
✘ ... source → .ownStateOrLocal: (abs(breakdown.pensionExemptAmount - (isExemptSource ? 60_000 : 0)) → 60000.0) < 0.01
✘ ... source → .uniformedServices: (same two)
```

Reverted with `git checkout --`, confirmed by `git status` showing `DataManager.swift` unmodified, and
the full suite re-run green afterwards. The residence-mapping half
(`incomeSources(asResidentOf:)`) is already covered by Task 3's tests and needed no change: the
mapping rewrites `ownStateOrLocal` to `otherStateOrLocal` for a hypothetical other state, and
Massachusetts's rule rejects `otherStateOrLocal`, so a non-resident's own-state pension cannot claim
Massachusetts's exclusion on the State Comparison screen.

---

## 11. Full suite

Command, run in the foreground, from the worktree:

```
tools/run-tests.sh
```

Output:

```
Project:  /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ 0bd68af
Scope:    full suite, five to six minutes. Run this in the FOREGROUND.

================ RESULT ================
Swift Testing:  Test run with 1938 tests in 298 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2447 test(s) ran, no failures.
```

Baseline was 1,924 Swift Testing in 297 suites plus 509 XCTest. The delta is +14 Swift Testing tests
and +1 suite, all from `Phase5bMassachusettsPerSourceTests` (parameterized tests count as one).
**No `MultiYearPerfTests` flake on any of the three full runs**, so there is nothing to disclaim. No other suite
moved.

---

## 12. What I disagreed with, or found wrong in the brief

1. **The brief's "MA-2 in that role. Decide whether it is sufficient" understates it.** MA-2 is
   sufficient for the unestablished-jurisdiction role and covers NOTHING of the contributory question,
   which was the thing it was named for. Both halves needed saying.
2. **The brief presents the axis as one "that only Massachusetts uses".** That is not right, and it is
   the load-bearing fact in the judgement. Hawaii's fixture and a shipped production caption both
   already turn on it. I would not have reached the same conclusion on the brief's framing alone.
3. **Step 3's "ADD one" is unavailable for the case that most needs it**, and the reason it is
   unavailable is the finding (section 1b). A subsequent task following the procedure literally could
   waste effort writing a contradictory fixture.
4. **Kansas's KS-7 pattern does not transfer**, because Massachusetts's out-of-state treatment is
   conditional on reciprocity while Kansas's is a flat closed list (section 2a). Copying the pattern
   would have shipped an unverified legal assertion into a golden fixture.
5. **Massachusetts under-matches on `federalCivilian` and `railroadRetirement`** (section 5). Neither
   the brief nor the plan's three-item scope mentions the category at all. **I have since withdrawn
   my own first characterisation of this as the fixture contradicting itself**; on careful re-reading
   the two strings are reconcilable and the finding is a plain under-match, which is a stronger claim,
   not a weaker one.
6. **I applied my own "not prose in a report" standard unevenly**, per review: to the contributory gap
   but not to the federal-civilian one. Corrected in this pass with an entry and a test.
7. **Procedural deviation on Steps 4 and 5**, disclosed in section 4: the rule and the deletions
   landed together, so the "delete the knownDefect block" message never appeared.

## 13. NOT TAKEN: John decided to SHIP as-is on 2026-08-05. The reversal recipe, kept as a record

**DECISION MADE. This recipe was NOT used.** John reviewed the judgement in section 1 and chose to
ship the rule as written, so nothing below has been applied and nothing below is pending. It is kept
because it is the record of what shipping cost and what undoing it would take, and because it was
wrong the first time in a way worth remembering. Every disclosure artifact stays in place: shipping
does not retire the disclosure, it is what makes shipping defensible.

**The first version of this section was incomplete and
following it literally would have shipped a FALSE DISCLOSURE.** It is corrected and executable below.
Reviewer's catch, and it is the important one: `unclassifiedPensionDisclosure` is not derived from
`perSourceExemptions`, so removing the rule does not remove the sentence promising the exclusion.
`everyShippedSentenceIsWellFormed` would NOT catch it, because it checks token count, jurisdiction
name, em dash and terminal period, nothing semantic. Both output surfaces would keep telling
Massachusetts users the app grants an exclusion it no longer grants.

The conservative alternative is to not exempt `ownStateOrLocal` in Massachusetts at all, leaving the
noncontributory user correctly taxed and MA-1 and MA-3 defective. The `uniformedServices` half of the
rule and MA-4's correction are unaffected either way and carry no contributory question at all, so
the rule shrinks rather than disappears and Massachusetts STAYS on `phase5CorrectedJurisdictions`.

**Every file and test the reversal touches:**

1. `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-MA.json`
   - Delete `"ownStateOrLocal"` from `matchSources`, leaving `["uniformedServices"]`.
   - **REWRITE `unclassifiedPensionDisclosure` (line 42).** This is the false-disclosure trap and no
     test guards it. It must stop promising the state and local exclusion. Suggested replacement,
     which would be NEW copy needing its own approval (John's 2026-08-05 approval covers the sentence
     that SHIPPED, not this reversal-only variant) and still needing exactly one `{scope}` token:
     "Massachusetts excludes U.S. military retired pay from state tax with no dollar cap, but {scope}
     taxes your pension in full until it is classified."
   - Do NOT delete the key: `rulesAndDisclosuresStayInLockstep` fails if a jurisdiction ships rules
     without a sentence, and one rule remains.
2. `RetireSmartIRATests/GoldenScenarios/statetax-2026-MA.golden.json`
   - Restore MA-1's `knownDefect`: tier2, `observedToday` **3000.00**, against `expectedStateTax` 0.00.
   - Restore MA-3's `knownDefect`: tier2, `observedToday` **3750.00**, against `expectedStateTax` 0.00.
   - Leave the `ownStateOrLocal` LABELS in place. They are correct independent of the rule, and
     reverting them would reintroduce the Kansas mislabel.
   - MA-2 and MA-4 unchanged.
3. `RetireSmartIRATests/Phase5bMassachusettsPerSourceTests.swift`
   - Drop `.ownStateOrLocal` from `sourcesMassachusettsNames`. It moves automatically into the derived
     `sourcesMassachusettsDoesNotName` sweep, which is the intended behaviour.
   - **`ownStatePensionIsExemptEndToEnd` goes RED. Delete it** or invert it to expect $3,000.00.
   - **`pickerOffersTheRowsTheRuleNeeds` goes RED**, on its final loop: `.ownStateGovernmentPension`
     would still be offered but would no longer match any rule. Narrow the loop to
     `.uniformedServicesPension` only.
   - `ownStateDefinedContributionIsStillTaxedEndToEnd` stays green but becomes vacuous; keep or drop.
   - **Delete `theContributoryGapStaysRecorded`** (the gap it records no longer exists).
   - `federalCivilianIsTaxedInFullToday` and the `federalCivilian` entry are UNAFFECTED. Do not touch
     them; that under-match is independent of this decision.
4. `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift`
   - Delete ONLY the MA **contributory** `knownButUnpinned` entry (the one whose summary contains
     "NONCONTRIBUTORY"). **Keep the MA federal-civilian entry.**
   - Remove the Massachusetts clause from the kind-2 doc comment, which now cites it as the example.
5. `RetireSmartIRA/IncomeSourcesView.swift`
   - Delete the `selectedState == .massachusetts` caption and its comment block. Under the
     conservative rule the app no longer understates that user's tax, so the warning becomes false.
6. **Unchanged, deliberately:** `phase5CorrectedJurisdictions` keeps `.massachusetts` (one rule and a
   disclosure still diverge from the frozen legacy table, and Layer B asserts they MUST);
   `layerAProvenDivergentJurisdictions` still excludes it; no baseline movement entries either way.

**Then run `tools/run-tests.sh` in the foreground.** Expected: green, with the suite count down by
roughly two tests. Any RED beyond the ones named above means the recipe missed something; diagnose
rather than adjusting a pin.

---

## 14. Recorded, not solved: routed to Phase 6

**The under-taxation warning is INPUT-SURFACE ONLY.** Reviewer's finding, accepted in full, and it is
the largest remaining hole in this task's disclosure story. The section 6 caption reaches a user who
is EDITING a pension row. The two surfaces that CONSUME the resulting figure carry nothing:

- `unclassifiedPensionDisclosure` fires only when a pension is UNCLASSIFIED. The affected user has
  classified: that is exactly how they got the wrong exclusion. So neither surface warns them.
- **State Comparison** shows Massachusetts at $0.00 with no caveat.
- **The CPA BRIEFING is the serious one.** It is the document handed to a tax preparer, and it would
  present $0.00 of Massachusetts tax with no indication that the figure depends on a contributory
  determination the app never made.

Hawaii's precedent is structurally identical and equally input-surface-only, but its direction is
over-taxation; Massachusetts's is under-taxation, which is what makes this worth Phase 6's attention
rather than parity with Hawaii. **This is a Phase 6 disclosure item and I did not solve it here**: the
fix is a classified-pension caveat on the consuming surfaces, which is a new disclosure mechanism
(the existing one is gated on the opposite condition), plus user-facing copy John approves.

### Two Minors the reviewer accepted rather than asked me to change, recorded for Task 10

1. **Massachusetts now has ZERO Layer A coverage.** Adding it to `phase5CorrectedJurisdictions` makes
   `jsonMatchesLegacy` `continue` past its per-scenario JSON-versus-legacy identity check, and because
   Massachusetts is correctly NOT on `layerAProvenDivergentJurisdictions` (section 8, measured),
   nothing replaces it. Massachusetts is in exactly Kansas's position and the same reasoning was
   applied, so this is consistent rather than new, but it now affects two jurisdictions and the
   comment below the scenario loop should say so when Task 10 closes the phase. Layer B and
   `Phase5bMassachusettsPerSourceTests` are what guard Massachusetts today.
2. **Both contributory captions are untestable.** The Hawaii one and the new Massachusetts one both
   live as literals inside a SwiftUI view body with no extracted seam, so a refactor drops either
   silently and no test notices. The durable guards are the two `knownButUnpinned` entries and
   `theContributoryGapStaysRecorded`. Extracting both captions to testable statics is a small, safe
   cleanup that belongs with the Phase 6 disclosure work in item 14 above, not here.
