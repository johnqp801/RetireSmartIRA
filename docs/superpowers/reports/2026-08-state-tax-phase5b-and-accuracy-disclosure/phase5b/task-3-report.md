# Task 3 report: Kansas

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`, branch
`feature/state-tax-phase5b`, started from HEAD `0e5ecff270f356bd9e92dcb9eb9fa08f78bba2bc`, working tree
clean at start (verified before the first edit).

Status: **DONE_WITH_CONCERNS**. The tax rule and its guards are complete, measured and green. The
concerns are all in the picker half of the addendum and are reported, not silently absorbed: a
user-facing overlap between the new "my own state" row and the existing New York row, a saved-data
migration exposure I was told not to solve, and three labels John APPROVED AS IS on 2026-08-05.

---

## 1. The Kansas rule

Written into `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json`, inside
`retirementExemptions`, in the sorted-key position between `pensionExemption` and
`regularExemptionMinAge` so the file keeps the generator's `sortedKeys` ordering:

```json
"perSourceExemptions" : [
  {
    "matchSources" : [
      "ownStateOrLocal",
      "federalCivilian",
      "uniformedServices",
      "railroadRetirement"
    ],
    "matchStructures" : [
      "definedBenefit"
    ],
    "treatment" : { "kind" : "full" }
  }
]
```

One rule, first-match-wins, full exclusion, no cap and no age gate, because Schedule S Line A14 states
none for any of the four categories.

### What it deliberately does NOT match, and what catches each

Before running anything I wrote down what the rule could wrongly match. Six axes, and I added a
fixture case for the one nothing was catching.

| Would wrongly match | Caught by | Status |
|---|---|---|
| `otherStateOrLocal`, a different state's system | golden KS-7 (Task 2's guard) | already existed, still green |
| `governmentUnspecified`, jurisdiction never established | **nothing** | **I added golden KS-8** |
| `privateEmployer` | golden KS-3 | already existed, still green |
| `individual` (a personal IRA) | no fixture | added to the Swift negative sweep |
| `nyStateOrLocal` | no fixture | added to the Swift negative sweep |
| `unknown`, the migration default on every pre-3b saved row | no fixture | added to the Swift negative sweep |
| a named source in a NON-`definedBenefit` structure | no fixture; every classified row in the KS fixture is `definedBenefit`, so `matchStructures` could have been deleted outright with the whole golden suite still green | added to the Swift structure sweep, plus an end-to-end case |

`unknown` is the one that would have been most expensive: it is what every pension row saved before
Phase 3b carries, so a rule matching it would have handed a full Kansas exclusion to every
unclassified pension in every existing Kansas user's saved data.

### KS-8, the new fixture case

`RetireSmartIRATests/GoldenScenarios/statetax-2026-KS.golden.json` now has EIGHT scenarios. The new
one is the unestablished-jurisdiction guard: single filer, age 68, $40,000 defined-benefit pension
classified `governmentUnspecified`, expected $1,432.31, **no `knownDefect` block and there must never
be one**, exactly mirroring KS-7's construction. Inputs are deliberately identical to KS-3, KS-4 and
KS-7, so across the four age-68 single cases the ONLY variable is `planSource`.

It needed no new legal research. Its expected value is arithmetically identical to KS-3 and KS-7
(same inputs), and its justification is the same closed-list reading of A14 those two cases already
cite, reinforced by a codebase invariant that is not a Kansas question at all:
`PlanSource.governmentUnspecified`'s own doc comment says "No rule may match this case as though it
were a specific jurisdiction."

The controller's framing was right: the Kansas guard defended `otherStateOrLocal` only. An EMPTY
`matchSources` ("any source") would at least have been caught, by KS-7 and KS-3. But a rule that
listed `governmentUnspecified` explicitly alongside the four real sources would have passed every one
of the seven pre-existing cases while silently exempting a pension whose employer nobody ever
identified. KS-8 closes that.

### `matchStructures: ["definedBenefit"]`, and its disclosed cost

Chosen deliberately, not copied from New York:

- It is co-extensive with what the picker can write for these four sources. All four picker rows that
  produce them are `definedBenefit`, so the constraint loses nothing reachable today.
- It fails safe. A future picker row writing `(definedContribution, ownStateOrLocal)` would not
  auto-inherit a full exclusion. Line A14 names "Kansas Public Employees' Retirement (KPERS)
  ANNUITIES", not the separate KPERS 457 deferred-compensation plan, so auto-exempting a government
  salary-reduction plan would be an over-match with no authority behind it.

**The disclosed cost, reported rather than guessed at:** Line A14's federal category does name Thrift
Savings Plans ("...including Thrift Savings Plans"). A TSP is defined-contribution. Neither this rule
nor the picker can express "federal TSP" today, so a Kansas TSP holder is still taxed on it. I did NOT
widen the rule to reach it and I did NOT write a fixture predicting a figure for it: closing this
needs either a picker row for a federal defined-contribution plan or a second Kansas rule, and either
is a decision with an authority question attached, not a mechanical extension of this task.

---

## 2. `knownDefect` blocks deleted, with measured figures

Three, all resolving to the same measured value. Whole blocks deleted; no `observedToday`, `tier` or
`expectedStateTax` was edited anywhere.

Measured from the Step 4 run (`tools/run-tests.sh GoldenScenarioSingleYearTests`), which failed with
exactly three issues, all `defectAppearsFixed` at `GoldenScenarioSingleYearTests.swift:257`:

| Case | Pinned `observedToday` | Engine after the rule | Expected by the form |
|---|---|---|---|
| KS-4, single filer, KPERS pension | 1432.31 | **0.0** | 0.00 |
| KS-5, MFJ, KPERS + federal civil service | 1218.88 | **0.0** | 0.00 |
| KS-6, MFJ, KPERS + private, COMBINED case | 1218.88 | **0.0** | 0.00 |

KS-6 behaved exactly as its own `knownDefect.summary` predicted: it was sitting at the
only-personal-exemption-fix figure of $1,218.88 after Phase 5a, and the per-source rule is what
finally floored it at $0.00. Nothing had to be diagnosed; every case I expected to resolve did.

KS-1, KS-2, KS-3 and KS-7 all kept passing throughout. **KS-7 passes.** It was the case I watched
most closely, and it never moved.

---

## 3. Step 7: the equivalence-list determination

**Kansas stays where it is: ON `phase5CorrectedJurisdictions`, OFF
`layerAProvenDivergentJurisdictions`. No membership changed.**

This was MEASURED, not reasoned from the comment already in the file. I temporarily added `.kansas` to
`layerAProvenDivergentJurisdictions` (`RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift:561`)
and ran the suite. It failed:

```
✘ "Every jurisdiction computes identical state tax from JSON and from the legacy table"
  ... 1 argument state → .kansas at StateTaxJSONEquivalenceTests.swift:520:13:
  Expectation failed: observedDivergence
```

That is the "None diverged" branch: not one of the 10 grid scenarios computes a different tax from the
corrected JSON than from the frozen legacy table. I reverted the edit immediately.

The mechanism, now recorded in the file's own comment: the only `.pension` row that grid builds is
`IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)` with NO classification.
`IncomeSource.init` then falls back to `RetirementPlanClassification.infer(incomeType:)`, which returns
`(unknown, unknown)` for every type except `.rmd`. Kansas's rule names four specific government
sources; `.unknown` is not among them, so `matchedPerSourceRule` returns `nil` for that row through
BOTH configs and the correction is invisible to this grid. Kansas now belongs on
`phase5CorrectedJurisdictions` for two independent reasons rather than one, and belongs off the second
list for two independent reasons rather than one. I updated both doc comments to say so.

### The frozen baseline did not move

`StateTaxBehaviorBaselineTests` passed unchanged, so **no entry was added to
`RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` and that file is untouched**
(confirmed with `git status` on `RetireSmartIRATests/Baselines/`). Same mechanism: that grid's pension
and RMD rows are also built without a classification, so none of the 1,020 values can see a per-source
rule. This is the correct outcome for this task, not an omission. If a later Phase 5b task classifies
a row in either grid, that task will owe the ledger an entry.

---

## 4. How I verified the DataManager breakdown mirror

`DataManager.swift:818-851` and `:978-1005` hand-duplicate the engine's per-source partition
(`TaxCalculationEngine.swift:616-651`). They call the same `matchedPerSourceRule`, but re-implement
the loop, the pooling and the cap interaction around it. Nothing in the golden fixture set touches
that path at all: `GoldenScenarioSingleYearTests.singleYearStateTax` drives
`TaxCalculationEngine.calculateStateTax` directly and never constructs a breakdown.

I did three things, in order.

**a. Read both sides.** Confirmed the mirror's `pensionExemptAmt = perSourceExcludedPension + ...`
feeds `totalExempted`, which feeds `adjustedIncome`, which is what `totalStateTax` is computed from.
So the mirror's per-source term is load-bearing for the displayed tax, not display-only.

**b. Wrote a sweeping test.**
`Phase5bKansasPerSourceTests.breakdownMirrorAgreesWithTheEngineForKansas` runs eight sources through a
real `DataManager` set to Kansas (the four the rule names plus `otherStateOrLocal`,
`governmentUnspecified`, `privateEmployer` and `unknown`) and asserts two things per source: that
`stateTaxBreakdown(...).totalStateTax` equals `calculateStateTaxFromGross(...)`, and that
`breakdown.pensionExemptAmount` is $40,000 for a matched source and $0 for an unmatched one. The
second assertion matters on its own: a mirror can arrive at the right TOTAL by a different route while
displaying a wrong attribution, and both numbers are read by a user.

**c. Proved the test discriminates, by mutation.** A green test on an already-correct mirror proves
nothing about whether it would catch drift. I temporarily neutralised the mirror's per-source term
(`pensionExemptAmt = 0 * perSourceExcludedPension + ...`) and re-ran. It failed on all four exempt
sources, on both assertions: mirror $1,432.31 against engine $0.00, and attribution $0 against $40,000
expected. Then `git checkout -- RetireSmartIRA/DataManager.swift`, confirmed clean with `git status`.
**`DataManager.swift` is unmodified in the final commit.**

Worth recording: the pre-existing `StateTaxBreakdownTests.breakdownMatchesCalculation`, which sweeps
all 51 states, would NOT have caught that mutation. It builds its pension row unclassified, so it
never reaches a per-source rule in any state. The new test closes a real hole, not a hypothetical one.

**Result: the breakdown display and the tax computation agree for Kansas across every source, matched
and unmatched.**

---

## 5. The picker: THE THREE LABELS, APPROVED AS IS BY JOHN ON 2026-08-05

Three rows added to `PlanClassificationChoice` (`RetireSmartIRA/IncomeSourcesView.swift`). **These
three labels shipped as working copy and John approved them AS IS on 2026-08-05, so they are now
approved user-facing copy and changing them is his decision, not a maintainer's.** Nothing keys
on a label, and what a row PERSISTS is the `RetirementPlanClassification` its `classification` returns,
so renaming any of them is a two-line edit (the `label` switch and the pin in
`Phase3bPresentationTests`) with zero behavioral consequence and no data migration.

**Correction, on review.** An earlier draft of this section, and two doc comments, said the persisted
value is the case's `rawValue`. That is wrong. `PlanClassificationChoice` is a presentation type held
only in `@State` (`AccountsView.swift:245`, `IncomeSourcesView.swift:1002`) and is never encoded;
`RetirementPlanClassification` is what `IncomeSource` and `IRAAccount` store. The additive property I
claimed still holds, but it holds through `classification`, not through `rawValue`, and
`pickerClassificationsMatchSpec` is the test that protects it. `originalRawValuesAreUnchanged` is kept
for the smaller true reason now stated in its own doc comment: `rawValue` is the case's `Identifiable`
id and therefore its `ForEach`/`Picker` view identity.

| Case | **APPROVED label** | Writes |
|---|---|---|
| `ownStateGovernmentPension` | **"Government pension, my own state or locality"** | `(definedBenefit, ownStateOrLocal)` |
| `uniformedServicesPension` | **"Military retired pay"** | `(definedBenefit, uniformedServices)` |
| `railroadRetirementPension` | **"Railroad Retirement benefits"** | `(definedBenefit, railroadRetirement)` |

All three landed together, per the addendum, even though Kansas needs only the first, so Tasks 4, 6, 8
and 9 inherit a picker that can express their rules.

One more piece of user-facing copy changed, also for John's review: the caption under the pension
picker read "Some states, including New York, tax government and private pensions differently." It now
reads **"Some states, including New York and Kansas, tax government and private pensions
differently."** Purely factual as of this task; revert or reword freely.

### Surfaces checked, per the addendum's list

- **The enum and its raw values.** Three cases added. The three new rows are INSERTED (own-state after
  New York; military and railroad after federal civilian) rather than appended, which changes display
  POSITION but preserves the relative order of all nine original rows. No existing case's
  `classification` changed, which is the property that matters for stored data, and no existing case's
  `rawValue` changed either, which matters for view identity. Both are pinned by their own tests
  (`pickerAdditionIsPurelyAdditive`, `originalRawValuesAreUnchanged`), so a future edit that quietly
  re-tuples an existing row while updating the full-list literal still fails.
- **`classification`.** Three new arms, each writing exactly one of Task 1's new `PlanSource` cases.
- **`choice(for:)` and its `priorityOrder` array.** All three added. This was the addendum's flagged
  silent-defect risk and it is real: the array is hand-maintained, does not use `allCases`, and an
  omitted case falls through to `.notSure` with no compile error, so an already-correctly-classified
  row would display as unclassified the moment a user opened it to edit. The existing
  `reverseLookupRoundTrips` test sweeps `allCases` and is what catches an omission; I confirmed it
  covers the new cases automatically and added a doc comment on the array pointing at it. I also added
  `pickerRowsWriteDistinctClassifications`, which proves no NEW collision was introduced beyond the
  documented `.employer401k` / `.privateSalaryReduction` pair, since a second undocumented collision
  would make one of the colliding rows silently un-round-trippable.
- **`showsPickerFor(accountType:)`.** No change needed and none made. It gates on `AccountType` only
  (not Roth, not inherited); the new rows inherit that gating unchanged.
- **`ForEach(PlanClassificationChoice.allCases)` picker body.** Two call sites,
  `IncomeSourcesView.swift:1161` and `AccountsView.swift:308`. Both iterate `allCases`, so both pick
  the new rows up with no edit.
- **`accountDisplayName(accountType:planStructure:planSource:)`.** No change needed and none made. It
  special-cases exactly one tuple, `(definedContribution, governmentUnspecified)`, and falls back to
  `accountType.rawValue` for everything else. The three new tuples are all `definedBenefit`, so they
  fall back exactly as `nyGovernmentPension` and `federalCivilianPension` already do. Adding arms
  would change the display of accounts classified through the existing government-pension rows too,
  which is a behavior change nobody asked for.
- **`residenceHasPerSourceRules`.** Confirmed, not modified, exactly as instructed. It reads the live
  config, so shipping Kansas's `perSourceExemptions` turns the classification prompt on for Kansas
  residents with no code change. I added a test that proves it rather than asserting it in a comment:
  `kansasNowCarriesAPerSourceRule` checks both the predicate and that
  `shouldPromptForClassification` fires for an unclassified Kansas pension row.

### The New York / own-state overlap: MITIGATED in the follow-up commit, see section 9

For a New York resident, `nyGovernmentPension` and `ownStateGovernmentPension` describe the same
pension, and **only the first one selects New York's Line 26 exclusion.** A New York resident who
picks the new row writes `ownStateOrLocal`, which New York's shipped rule does not name, and is
over-taxed.

The first commit left this unfixed on purpose and reported it. On review the controller authorized a
mitigation, which landed in the follow-up commit: the own-state row is not OFFERED to a resident whose
own config already names its own jurisdiction. Section 9 has the mechanism, the test coverage, and why
this is a mitigation rather than the fix.

The structural fix remains deferred and remains the right one: retire `nyStateOrLocal` in favour of the
general `ownStateOrLocal` (the NY case predates it and is the jurisdiction-named form of the same
idea). That migration touches New York's shipped config, New York's golden fixtures and existing user
saves, and is not a Task 3 side effect.

The expedient alternative, adding `ownStateOrLocal` to New York's `matchSources`, is wrong in a way
worth recording: State Comparison evaluates ONE household's rows against EVERY state's config, so a
Kansas resident asking "what if I moved to New York" would have their KPERS row exempted by New York,
which it should not be. That is the residence-relativity problem, which the follow-up commit fixes
separately and properly at `DataManager.incomeSources(asResidentOf:)`. See section 9.

### REPORTED, NOT SOLVED: the saved-data exposure, in BOTH directions

There is no safe automatic migration, and I wrote none.

**Two directions, and the first draft of this section covered only one.** The
`otherStateOrLocal` direction is below and errs toward over-taxation. The `ownStateOrLocal`
direction, added on re-review, errs toward UNDER-taxation and is the more serious of the two. It is
written up in section 10 rather than here, because it is not a migration question at all: the value
is not stale at load time, it goes stale later, when the user changes residence.

A user who already classified their own state's pension through the only government option that
existed has `otherStateOrLocal` persisted. After this change that stored value means "genuinely a
different state." The two are indistinguishable from the stored value alone: nothing in
`IncomeSource` or `IRAAccount` records the taxpayer's residence at the time of classification, and
even if it did, a resident of Kansas holding a genuine California pension is a real household, so
"residence matched at save time" would not disambiguate either. A migration that guessed would
silently grant a Kansas exclusion to a real out-of-state pension, which is the exact defect KS-7
exists to prevent, reintroduced through the back door.

**Size of the exposure.** Bounded, and small in the direction that matters:

- Only `.pension`-typed income rows and non-Roth, non-inherited accounts can carry the value at all.
- Only rows a user EXPLICITLY classified are affected. Every unclassified row carries
  `(unknown, unknown)` from `infer(incomeType:)`, not `otherStateOrLocal`. The pension picker
  defaults to whatever `choice(for:)` returns for the existing classification, which for an
  unclassified row is `.notSure`, so `otherStateOrLocal` is never written by accident.
- The prompt that drove users to classify at all is gated on `residenceHasPerSourceRules`, which until
  this commit was true for New York ONLY. So the exposed population is essentially: users who set
  their residence to New York, were prompted, and chose "another state or locality". For those users
  the stored value is almost certainly CORRECT under the new meaning too, since a New York resident
  picking that row was saying exactly "a different state".
- The population it would hurt, Kansas residents who classified a KPERS pension as "another state",
  is close to empty by construction: Kansas carried no per-source rule before this commit, so those
  users were never prompted and had no reason to open the picker.
- The direction of any residual error is over-taxation, not under-taxation. A stale
  `otherStateOrLocal` denies an exclusion; it never grants one.

**Recommended handling:** no data migration. If anything is done, make it a one-time, in-app prompt
for `.pension` rows carrying `otherStateOrLocal` whose owner's residence now has per-source rules,
asking the user to re-confirm. That is a Phase 6 disclosure-shaped change, not a silent rewrite.

---

## 6. Full suite

```
tools/run-tests.sh
```

Run in the foreground with a 600000 ms timeout, from
`/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`.

```
Project:  /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ 0e5ecff
Scope:    full suite, five to six minutes. Run this in the FOREGROUND.

================ RESULT ================
Swift Testing:  Test run with 1901 tests in 296 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2410 test(s) ran, no failures.
```

Against the stated baseline of 1,885 Swift Testing in 295 suites plus 509 XCTest: **+16 Swift Testing
tests, +1 suite, XCTest unchanged, zero failures.** The delta reconciles exactly: 9 from the new
`Phase5bKansasPerSourceTests` suite, 7 added to `Phase3bPresentationTests`. **`MultiYearPerfTests` did
not flake on this run** and was not re-run in isolation, because it did not fail; there is no failure
of any kind to explain away.

No other suite moved. Nothing was silenced, skipped or weakened.

---

## 7. Files changed

Production:
- `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json`: the rule.
- `RetireSmartIRA/IncomeSourcesView.swift`: three picker rows, their labels, their classifications,
  the `priorityOrder` entries, doc comments, and the one caption edit.

Tests and fixtures:
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-KS.golden.json`: three `knownDefect` blocks
  deleted, KS-8 added.
- `RetireSmartIRATests/Phase5bKansasPerSourceTests.swift`: new.
- `RetireSmartIRATests/Phase3bPresentationTests.swift`: picker pins updated and extended.
- `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`: comments only, recording the Step 7
  measurement and Kansas's second reason for being on `phase5CorrectedJurisdictions`. No membership
  changed.

NOT changed, deliberately: `RetireSmartIRA/DataManager.swift` (mutation experiment fully reverted),
`RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` (no value moved),
`RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json` (frozen),
`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NY.json`, `PerSourceExemptionRule.matches`,
`RetirementPlanClassification.matches`/survivor-flag consumption, and `DataManager`'s survivor
pass-through (all Task 9's).

---

## 8. Where I disagreed with, or went beyond, the brief

1. **The brief's first line gave the wrong path to itself** (`/Users/johnurban/Projects/RetireSmartIRA/.superpowers/sdd/task-3-brief.md`),
   corrected two lines later. I read the worktree copy. Noting it only because the same class of
   mistake, reading a file from the wrong worktree, is a documented recurring failure on this project.
2. **Step 3 says "add a case" if nothing catches an over-match, and I did**, which the plan's Task 3
   paragraph does not anticipate: it says Task 2's negative case "is what proves the last part," and
   treats the guard question as closed. It was closed for `otherStateOrLocal` and open for
   `governmentUnspecified`. KS-8 is the difference.
3. **I did not copy New York's rule shape uncritically.** New York's `matchStructures:
   ["definedBenefit"]` is the right answer for Kansas too, but for a Kansas-specific reason (A14 names
   annuities), and it carries a Kansas-specific cost (TSP) that New York's does not. Section 1 records
   both rather than treating the shape as inherited.
4. **The addendum asked for the picker rows and I built them, but I do not think Kansas can be called
   complete for a New York-adjacent user until the `nyStateOrLocal` / `ownStateOrLocal` overlap is
   resolved.** Task 10 Step 4's planned claim that "Steve can be told so without qualification" is
   sound for Steve, a Kansas KPERS holder, who can now select his plan and get the right answer. It is
   not sound as a general statement about the picker.
5. **I added one line of user-facing copy** (the caption edit) that nobody asked for. It is factual and
   trivially revertible, and it is flagged in section 5 rather than buried.

---

# 9. Post-review fix commit

Review returned SPEC COMPLIANCE: PASS with five items to fix in one commit, plus one finding routed to
John that I did not touch (the unclassified-pension disclosures hardcoded to New York in
`StateComparisonView` and `MultiYearCPABriefing`, which need new user-facing copy).

Full suite after the fixes: **1,909 Swift Testing in 296 suites + 509 XCTest, 0 failures**, via
`tools/run-tests.sh` in the foreground. That is +8 Swift Testing tests over the first commit's 1,901
and the delta reconciles exactly: 5 picker-suppression tests, 3 residence-relativity tests. No suite
count change, no XCTest change, no `MultiYearPerfTests` flake. **KS-7 and KS-8 both still pass**, along
with every other Kansas golden case.

## Findings 1 and 3: one root cause, but NOT one fix. I shipped two.

I disagree with one thing the review concluded, and it changes the shape of the work rather than the
verdict. **The authorized picker mitigation closes finding 1. It does not close finding 3.**

The demonstration is Vermont. Finding 3's example household is a Vermont resident who selects the
own-state row and then views Kansas. Vermont's config carries no jurisdiction-named per-source rule, so
`residenceNamesItsOwnJurisdiction(.vermont)` is false and the suppression never fires for them, which
is CORRECT: the own-state row is the right classification for their actual residence and hiding it
would be wrong. The bad number appears later, when their correctly-classified VSERS pension is
evaluated against Kansas's config. Suppression happens at classification time; the defect happens at
comparison time. No amount of filtering the picker reaches it.

So I implemented the authorized mitigation for finding 1 AND a separate, contained fix for finding 3.
Both are data-driven and neither hardcodes a state.

### Finding 1: suppress the own-state row where the state names its own jurisdiction

`RetireSmartIRA/IncomeSourcesView.swift`, three additions to `PlanClassificationChoice`:

- `jurisdictionNamedSources: Set<PlanSource> = [.nyStateOrLocal]`. DATA, so retiring the legacy case
  when the structural fix lands is a one-line deletion here and nowhere else.
- `residenceNamesItsOwnJurisdiction(_:)`, which asks the LIVE config whether any of that state's own
  per-source rules names a jurisdiction-named source. Same spirit as `residenceHasPerSourceRules`, and
  deliberately not `state == .newYork`.
- `options(for:selected:)`, returning `allCases` for everyone else and `allCases` minus the own-state
  row for a resident of such a state.

Both picker bodies now call it: `IncomeSourcesView.swift` (income rows) and `AccountsView.swift`
(accounts). Both already had `dataManager` in scope, so neither needed plumbing.

**The `selected:` parameter is the part worth reviewing hardest.** Suppression governs what a user can
newly CHOOSE, never what they already chose. A row that somehow carries `ownStateOrLocal` in New York
(imported data, a residence change made after classifying, a future build) must still find its own
selection in the list, or SwiftUI's `Picker` renders blank against a selection matching no tag and the
next save silently rewrites the row's classification. That would be a data-loss bug introduced by a
safety mitigation. `anExistingOwnStateSelectionSurvivesSuppression` pins both halves: the suppressed
row reappears when it is the current selection, and does not reappear when it is not.

Five tests in `Phase3bPresentationTests`: New York suppresses exactly one row and keeps the
jurisdiction-named one; **Kansas does NOT suppress**, because Kansas's rule uses the generic source and
suppressing it there would reintroduce the exact defect the addendum exists to fix; a no-rule state is
untouched; the selection-survives case above; and a pin on the `jurisdictionNamedSources` membership.

### Finding 3: residence-relative sources must not be inherited by a hypothetical other state

`RetireSmartIRA/DataManager.swift`, new `incomeSources(asResidentOf:)`. Identity for the taxpayer's
actual residence; for any other state it rewrites `ownStateOrLocal` rows to `otherStateOrLocal`,
because in the hypothetical where you live in Kansas, your Vermont pension IS an out-of-state pension.

**I did not invent this pattern. It is already in this codebase, at this exact seam, three lines
above the call I changed:**

```swift
// Apply the user's local/city income tax rate ONLY to their own state - a cross-state
// comparison (a hypothetical other state) must not inherit the home locality's rate.
let localRate = (state == selectedState) ? localIncomeTaxRate : 0
```

That line has been there since v1.8.3. The new one generalises the same rule from a rate to a
classification, and I chose this over the alternatives for that reason: it is the established
precedent, it is one function, and it needs no engine signature change (the engine never learns what
residence is, which is what made a rules-layer fix invasive).

Applied to BOTH paths, because this is the DataManager mirror trap the brief warned about and the
mapping is exactly the kind of thing that gets applied to one side only:

- `calculateStateTax(income:forState:...)`, which is what `calculateStateTaxFromGross` and therefore
  State Comparison's ranking call.
- `stateTaxBreakdown(forState:)`'s per-source partition, which recomputes its own tax rather than
  reading the other path.

Deliberately NOT applied to the gross `pensionIncome` / `rmdSourceIncome` totals in the breakdown:
those are amounts, and the mapping never changes an amount.

`breakdownMirrorAppliesTheResidenceMapping` sweeps four states and asserts the two paths agree on each.

**Numerically inert for everything that exists today**, which the full suite confirms by not moving.
Stated precisely, because an earlier draft said "no shipped fixture drives this path" and that is easy
to misread as the stronger and FALSE claim "no fixture carries the value": five golden scenarios do
carry `ownStateOrLocal`, including Kansas KS-4, KS-5 and KS-6. What is true is that none of them
reaches this function, because the golden runner calls `TaxCalculationEngine.calculateStateTax`
directly and never constructs a `DataManager`. Neither frozen scenario grid classifies its rows at
all, and no user save can carry the value, because the picker row that writes it ships in this same
branch. No pin moved and the movement ledger is still untouched.

## Finding 4: the `rawValue` persistence claim was wrong

Correct, and I accept it without reservation. `PlanClassificationChoice` is `@State` only
(`AccountsView.swift:245`, `IncomeSourcesView.swift:1002`) and is never encoded;
`RetirementPlanClassification` is what persists. Corrected in all three places named, plus the enum's
own doc comment where the same claim appeared a second time:

- `RetireSmartIRATests/Phase3bPresentationTests.swift`, the `originalRawValuesAreUnchanged` doc
  comment, which now says the old rationale was wrong and states the true, smaller one: `rawValue` is
  the case's `Identifiable` id and therefore its `ForEach`/`Picker` view identity. Test kept, as
  instructed. Its name changed to stop advertising the false claim.
- `RetireSmartIRA/IncomeSourcesView.swift`, the enum doc comment and the `label` doc comment.
- Section 5 of this report, corrected in place, with the correction called out rather than quietly
  rewritten.

## Finding 5: negative sweeps derived, not hand-listed

Correct, and it was the same defect class I had just written a doc comment about for `priorityOrder`,
which makes it worse than a miss. `Phase5bKansasPerSourceTests` now carries ONE hand-written list,
`sourcesLineA14Names`, and derives everything else:

- `sourcesLineA14DoesNotName` = `PlanSource.allCases` minus that list.
- `structuresOtherThanDefinedBenefit` = `PlanStructure.allCases` minus `definedBenefit`.
- The breakdown-mirror sweep now runs `PlanSource.allCases` outright rather than the eight I picked.

A `PlanSource` added by Tasks 4 through 9 is now rejected by default and has to be deliberately moved
into `sourcesLineA14Names` to be exempted, which is a change a reviewer sees.

## Finding 6: the TSP under-match is now DATA

Correct: the mechanism for exactly this already existed and I left a real finding in prose.
`GoldenScenarioDefectCatalogueTests.knownButUnpinned` now carries a `KS` entry naming the mechanism
(A14 includes Thrift Savings Plans in the federal category this rule implements; a TSP is
defined-contribution; `matchStructures: ["definedBenefit"]` excludes it) and the blocker.

One thing I stated explicitly in the entry rather than glossing: this widens that list's meaning.
Its doc comment describes a defect blocked on a missing DOLLAR FIGURE. This one is blocked on
EXPRESSIVENESS. No fixture can pin it because `PlanClassificationChoice` has no row writing a federal
defined-contribution plan, so a Kansas TSP holder cannot classify one at all, and a fixture asserting a
tax for a classification no user can select would assert something unreachable. Resolving it is a
product decision, not research. I judged that widening the list by one kind of blocker is better than
letting a measured under-exemption live only in a task report, which is the list's stated purpose, but
it is a judgement and a reviewer may disagree.

## What I did not touch

The disclosure copy hardcoded to New York in `StateComparisonView` and `MultiYearCPABriefing`, per
instruction. Note for whoever picks it up: `residenceNamesItsOwnJurisdiction` and
`residenceHasPerSourceRules` are both live-config predicates that new copy can key on without
hardcoding a state.

---

# 10. Second post-review fix commit

Re-review returned SPEC COMPLIANCE: PASS with both of my disagreements upheld. Three Minors fixed
here, plus one Important recorded rather than solved, plus one non-finding recorded so it cannot be
lost.

Two things the re-review established that I had NOT verified myself and am recording as inherited
evidence rather than my own work: only New York and Kansas ship `perSourceExemptions` at all, and
`residenceNamesItsOwnJurisdiction(.vermont)` stays false even AFTER Task 9 ships Vermont's rule,
because the predicate keys on jurisdiction-named sources and Vermont's rule will name the generic
`ownStateOrLocal`. That second point matters: my Vermont argument in section 9 holds not just today
but through the task that makes Vermont live.

## Minor 2: `selected` no longer has a default

`options(for:selected:)` carried `selected: PlanClassificationChoice? = nil`. The reviewer's objection
is exactly right and it is the sharper form of my own section 9 note: I identified the omitted-selection
case as the data-loss risk worth reviewing hardest, and then left it as the DEFAULT call form. Both
production call sites passed it, but the tests deliberately exercise the nil form, so no test could
also assert that production always passes it. A third call site would omit it with no compile error
and nothing red.

The default is gone. Callers pass `nil` explicitly when there genuinely is no selection, and the four
tests that do now say so at the call. This moves the guarantee from vigilance to the compiler, which
is the only place it belongs for a failure mode whose symptom is a silently rewritten user row.

## Minor 3: the predicate now checks what its name says

`jurisdictionNamedSources` is now `[PlanSource: USState]`, `[.nyStateOrLocal: .newYork]`, and
`residenceNamesItsOwnJurisdiction` compares `jurisdictionNamedSources[$0] == state`.

As a `Set<PlanSource>` it dropped the source-to-state association, so the predicate answered "does this
state's config name ANY jurisdiction-named source" while its name asserted "does it name ITS OWN". The
two coincide today only because `nyStateOrLocal` is the only such case and only New York's config
names it. The map is the same one-line-to-retire shape, so nothing about the structural fix got
harder.

Two tests, not one, because the map alone does not prove the predicate uses it: the membership pin now
also asserts every OTHER `PlanSource` maps to nothing, and a new
`suppressionIsKeyedToTheNamedStateNotMerePresence` sweeps all 51 states and requires that only New York
suppresses. That second test is what would actually fail if the predicate regressed to mere presence.

## Minor 4: the category doc comment now states the genus

`knownButUnpinned`'s doc comment defined the category by "blocked on a missing dollar figure", which
after the Kansas TSP entry contradicted its own data, with my widening rationale buried inside that
entry's `blockedOn` string. Since that comment is where a future contributor decides whether their
finding belongs, burying it there was the wrong place.

It now states the genus (a defect measured against a state's own published form, mechanism cited,
which no golden case can hold) and enumerates both admissible blocker kinds explicitly: NO ADMISSIBLE
FIGURE (Missouri, resolved by a source becoming reachable) and NOT EXPRESSIBLE (Kansas TSP, resolved by
a product decision). It also says plainly that the old definition was the differentia of the single
member that happened to exist rather than the genus, and that a finding which COULD be pinned belongs
in a fixture with a `knownDefect` block instead.

## RECORDED, NOT SOLVED: `ownStateOrLocal` goes stale on a residence change

**This is the most serious thing in this report and it is not fixed.** I accept the finding without
reservation and I did not identify it myself; section 5's migration analysis covered only the
`otherStateOrLocal` direction, which is the safe one.

The mechanism. Nothing records the residence at classification time, and the pension picker is gated on
`incomeType == .pension` only, never on the state, so any resident can select the own-state row today.
A Vermont user classifies VSERS as own-state. Harmless, because Vermont ships no rule. Later they
change residence to Kansas in Settings. `incomeSources(asResidentOf: .kansas)` now short-circuits to
identity at its own guard, because the state MATCHES. Schedule S Line A14 matches. A Vermont pension
receives Kansas's full exclusion at the user's actual residence, on the Scenarios screen, not in a
hypothetical.

Why this is worse than anything else in this report:

- **The direction is UNDER-taxation.** Every other exposure I have reported errs toward over-taxing,
  which is conservative. This one under-taxes, which is the direction that produces a wrong number a
  user acts on.
- **It is not a comparison artifact.** Section 9's finding 3 was about a hypothetical the user is
  explicitly exploring. This is the user's actual, current tax.
- **It gets worse on schedule.** Tasks 4, 8 and 9 ship `ownStateOrLocal` rules for Massachusetts,
  Idaho and Vermont, so the number of residence pairs that trigger it grows with the phase.
- **My finding-3 fix cannot reach it,** and my previous commit message overclaimed by saying it
  "contains `ownStateOrLocal`'s residence relativity". It contains the COMPARING route only. The
  MOVING route is untouched. That wording is corrected in this commit's message and the limitation is
  now written into `incomeSources(asResidentOf:)`'s own doc comment, next to the guard that
  short-circuits, so the next reader of that function sees it.

Why I did not fix it: it needs a new stored field, a residence stamp at classification time, on
`IncomeSource` and `IRAAccount`. That is a schema change with its own migration question (every
existing classified row has no stamp, and defaulting it either way is a guess of exactly the kind
section 5 refuses to make for `otherStateOrLocal`). It is not a Task 3 side effect.

**Routing:** alongside the Phase 6 re-confirm prompt section 5 already recommends. That prompt is the
natural carrier for both directions at once, since both resolve the same way, by asking the user rather
than guessing: "you told us this pension is from your own state's system, and your residence has
changed since. Is it still?" One prompt, one decision, both stale directions closed, no schema
guessing.

## RECORDED: the non-finding on `distributionComponents`

The re-review noted that the breakdown's SECOND `matchedPerSourceRule` block, the one over
`distributionComponents`, is not residence-mapped while the pension and RMD partitions above it are.

Inert today, and correctly judged a non-finding: no production caller passes `distributionComponents`
non-nil, only tests do, so that array is always empty on every shipped path. But "inert because nobody
calls it yet" is exactly the kind of fact that evaporates. It is now written as a comment at that
block, stating that whichever task first supplies components in production inherits the obligation to
map `ownStateOrLocal` there too, and what goes wrong if it does not.

## Full suite

`tools/run-tests.sh`, foreground, timeout 600000, from the worktree root.

```
Swift Testing:  Test run with 1910 tests in 296 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2419 test(s) ran, no failures.
```

+1 Swift Testing test over the previous commit's 1,909, which is
`suppressionIsKeyedToTheNamedStateNotMerePresence`. No suite count change, no XCTest change, no
`MultiYearPerfTests` flake, no pin moved, movement ledger still untouched. KS-7 and KS-8 both pass.

## Disagreement

None. All three Minors were correct as stated, the recorded Important is a real defect I missed and it
is more serious than anything I had found on my own, and the non-finding was correctly classified.
