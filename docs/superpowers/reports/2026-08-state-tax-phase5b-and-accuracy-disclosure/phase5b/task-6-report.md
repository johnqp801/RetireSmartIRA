# Task 6: Arizona. Report

**Worktree** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`
**Branch** `feature/state-tax-phase5b`
**Start HEAD** `0adc0b43ff44803e57076ceffd8fc10b3e81eae8`, working tree clean (verified before first edit)
**Commit** `19ee212`, range `0adc0b4..19ee212`

---

## 1. The headline: the cap is NOT a per-source rule, and that is the whole design

The obvious Arizona rule is one `perSourceExemptions` entry per line of Form 140:
`uniformedServices` at `full` for Line 29b, and `[federalCivilian, ownStateOrLocal]`
at `partial(2500)` for Line 29a. I did not ship that, and the reason is the single
most important finding in this task.

`PerSourceExemptionRule.treatment` is evaluated **inside the row loop**, in both
`TaxCalculationEngine.applyRetirementExemptions` (around line 619) and its
`DataManager.stateTaxBreakdown` mirror (around line 891):

```swift
for row in qualifyingPensionRows {
    if let rule = exemptions.matchedPerSourceRule(structure: row.planStructure, source: row.planSource) {
        perSourceExcludedPension += rule.treatment.excludedAmount(
            eligibleIncome: row.annualAmount, totalGrossIncome: income,
            isMarried: isMarried, perIndividualMultiplier: 1.0)
    } else {
        pensionIncome += row.annualAmount
    }
}
```

For a `.full` treatment that is a partition, which is what the design intends. For a
`.partial` treatment it is **a cap granted once per row**. Design doc section 3.4a
forbids precisely this ("rule matching partitions, it does not evaluate per
component"), `RetirementDistributionComponent.swift`'s file header calls it "the
single largest correctness risk in this phase," and this codebase has already
shipped the bug once (New York's shared pension-and-IRA cap exists because an
earlier version granted $20,000 to each). Both loop comments currently assert
"never a cap evaluated per row," which is true only because no shipped rule had
ever used `.partial`. Arizona would have been the first.

**What Arizona ships instead**, all in `statetax-2026-AZ.json`:

| Piece | Value | Purpose |
|---|---|---|
| rule 1 | `[uniformedServices]` at `[definedBenefit]`, `full` | Line 29b, uncapped |
| rule 2 | `[privateEmployer, otherStateOrLocal, nyStateOrLocal]` at `[definedBenefit, definedContribution]`, `none` | removes non-qualifying pensions from the pool |
| `pensionExemption` | `partial(2500)`, **unchanged** | Line 29a, applied ONCE to the pooled remainder |
| `exemptionAppliesPerIndividual` | `false`, **unchanged** | see section 3 |

A `.none` treatment excludes zero AND drops the row out of `pensionIncome`, so it
is an outright denial. That is how a government-only cap is expressed without the
cap ever entering the row loop. Everything the rules do not name falls through to
the pooled cap, which is exactly what section 3.4a step 3 prescribes.

This is measured, not asserted. Golden case 8 (single filer, `federalCivilian`
$2,000 + `ownStateOrLocal` $2,000) expects $333.75, i.e. **$2,500 excluded in
total**. A per-row `partial(2500)` rule excludes $4,000 and gives $296.25. That
case exists solely to catch the tempting rule, and `Phase5bArizonaPerSourceTests
.noShippedPerSourceRuleIsCapped` sweeps every one of the 51 jurisdictions so the
invariant is not Arizona-local.

## 2. What I deliberately made the rules NOT match

- **`federalCivilian` and `ownStateOrLocal` are matched by NO rule.** They are Line
  29a income, and Line 29a is the pooled cap, so they must arrive at the cap
  machinery unmatched. A `full` match would make them uncapped, a `none` match
  would deny them. `line29aSourcesFallThroughToThePooledCap` pins this, derived
  from `PlanSource.allCases` so a case added later lands there by default.
- **`otherStateOrLocal` is denied.** This is the Kansas/KPERS trap. Golden case 7
  is an Arizona resident holding another state's public pension, receiving nothing.
- **`nyStateOrLocal` is denied.** `residenceNamesItsOwnJurisdiction(.arizona)` is
  false, so `options(for: .arizona)` offers an Arizona user the New York row. They
  can select it, so the rule has to answer for it.
- **`unknown` is NOT named**, see section 5.
- **`ira` structure is excluded from the denial rule.** `.rmd` rows infer
  `(ira, individual)` and run through the same `matchedPerSourceRule` partition, so
  widening the denial rule to `ira` would start pulling RMD rows out of the IRA
  pool as a side effect. Pinned by `denialRuleSpansEmployerStructuresOnly`.

## 3. AZ-4 and per-taxpayer attribution: STAYS PINNED

The brief predicted this and was right about the outcome, though the blocker sits
somewhere slightly different from where the brief pointed.

Arizona Line 29a: "If both you and your spouse receive such pension income, **each
spouse** may subtract the amount received or $2,500, whichever is less." The
doubling is conditioned on each spouse **receiving qualifying pension income**.

The tempting fix is `exemptionAppliesPerIndividual: true`, which AZ-4's own
`knownDefect.summary` named as the culprit. I measured it rather than reasoning
about it, per the Task 5 standard:

| Household | Correct AZ | flag `false` (shipped) | flag `true` |
|---|---|---|---|
| AZ-4: MFJ, both spouses $2,000 qualifying | $1,312.50 | $1,350.00 (pinned) | $1,312.50 green |
| new case 9: MFJ, ONE spouse $6,000 qualifying | $1,350.00 | $1,350.00 green | $1,287.50 wrong |

`exemptionAppliesPerIndividual` doubles the cap when **both spouses clear the AGE
gate** (`bothSpousesQualify`, engine line 559). That is a different condition from
Arizona's. Flipping it trades a $37.50 over-taxation for a $62.50
**under**-taxation, which is the more dangerous direction for a planning tool, and
in a shape (one spouse holds the government pension) that is at least as common as
AZ-4's. So AZ-4 keeps its `knownDefect` at its existing `observedToday` of
$1,350.00, unedited, and **new golden case 9 pins the consequence of flipping the
flag**, so the trade cannot be made silently later: flipping it turns AZ-4 green
and case 9 red.

**Three separate things block a correct per-taxpayer cap**, and the brief named
only the first:
1. `exemptionAttribution` is household-wide (as the Kansas fixture records).
2. The per-source partition never reads `owner`, even though `IncomeSource` carries
   it and `ownerQualifies` is called two lines earlier. `perIndividualMultiplier`
   is hardcoded to `1.0` at all **six** call sites:
   `TaxCalculationEngine.swift:623, 647, 698` and `DataManager.swift:895, 907, 977`.
   (An earlier draft of this report said four. Corrected on review.)
3. **The golden fixture schema has no owner field.** `ClassifiedPensionSource`
   carries `amount`, `planStructure`, `planSource` and `isSurvivorBenefit` only,
   and `GoldenScenarioSingleYearTests.singleYearStateTax` builds every row with the
   `owner: .primary` default. So AZ-4's two rows are, to the engine, one taxpayer's
   two pensions. Even a fully correct per-taxpayer engine could not be pinned from
   this file, and AZ-4's $4,000 expectation is only reachable by a per-row cap,
   i.e. by wrong law. This is the same shape as Hawaii's byte-identical blocker.

## 4. The fixture re-labels, confirmed against each case's own text

Both were confirmed against the case's `name` and `source`, not taken from the brief.

- **AZ-3 → `uniformedServices`.** Its `source` quotes Line 29b verbatim and quotes
  Line 29a's explicit carve-out ("Do not enter any subtraction for pension income
  received from retired or retainer pay of the Uniformed Services"). Confirmed. The
  relabel is load-bearing: `federalCivilian` also carries cases 1, 4, 5, 6 and 9,
  which are capped at $2,500, so a `full` rule written against `federalCivilian`
  would have handed five civilian retirees an uncapped exclusion.
- **AZ-4 row 2 → `ownStateOrLocal`.** Its `source` states Line 29a covers "US
  government pensions plus Arizona state and local pensions" and that the expected
  figure requires this row to qualify. `otherStateOrLocal` is definitionally a
  different state's. Confirmed, and the relabel is what keeps AZ-4 at $1,350.00:
  left as `otherStateOrLocal` it would have been denied by rule 2 and moved to
  $1,362.50.

**A correction to the brief.** Addendum section 3 says AZ-4's second row "has NO
disclosure prose of its own, so it would otherwise be invisible to you." That is
not so: AZ-4's `source` field carries roughly 700 words on exactly this mislabel,
including the California-pension example and the `ownStateOrLocal` remedy. It was
the most thoroughly documented item in the fixture.

## 5. The unclassified default: New York's precedent, not Kansas's

The brief asks the Kansas question ("Kansas's rule deliberately does not match
`unknown`; ask the same for Arizona"). The principle behind Kansas's choice is
"conservative until classified," not "never name unknown", and the two states'
rules point in opposite directions:

- Kansas's rule **grants**. Leaving `unknown` unmatched means taxed in full until
  classified. Conservative.
- Arizona's rule 2 **denies**. Naming `unknown` there would mean no allowance until
  classified, which would **raise state tax for every existing Arizona user who has
  not classified**, including genuine government pensioners entitled to it, with no
  action on their part.

Kansas and Massachusetts could take the conservative route for free because both
ship `pensionExemption: none` already; no user's tax moved. Arizona ships a live
$2,500 blanket allowance, so the same choice is not free.

**New York is the exact structural precedent** and I followed it: NY keeps
`pensionExemption: partial(20000)` applying to unclassified rows on top of its
per-source rule, and warns via `unclassifiedPensionDisclosure`. Arizona now does
the same. No existing Arizona user's tax changes without them classifying.

The residual (an unclassified private pension keeps a $2,500 allowance it is not
entitled to, worth up to $62.50) is recorded as a new `AZ` entry in
`GoldenScenarioDefectCatalogueTests.knownButUnpinned`. It genuinely cannot be
pinned: an unclassified private pension and an unclassified government pension are
both `(unknown, unknown)` at the same amount, age, status and AGI, with correct
answers of $396.25 and $346.25. A fixture can assert one or the other, never both.

## 6. Golden cases: deleted, added, retained

**Deleted (three whole `knownDefect` blocks; no `observedToday`, `tier` or
`expectedStateTax` was edited anywhere):**

| Case | Was | Now, MEASURED | Mechanism |
|---|---|---|---|
| 2, single, private pension | $346.25 | **$396.25** | denial rule removes it from the pool |
| 3, single, military $40,000 | $333.75 | **$0.00** | Line 29b `full` rule |
| 5, MFJ, government + private | $1,441.25 | **$1,453.75** | private denied, government keeps $2,000 |

Measured by `tools/run-tests.sh GoldenScenarioSingleYearTests`, which reported all
three as `defectAppearsFixed` with those figures before the blocks were removed.

**Retained:** case 4 (AZ-4), pinned at its existing $1,350.00, unmoved. Its
`summary` prose was rewritten to record the measurement in section 3, and its
`source` prose was updated to drop Task 2's now-complete relabel instruction. Names
on cases 2, 3 and 5 were updated because they asserted engine defects that no
longer exist.

**Added (four):**

| # | Case | Expected | Dimension it pins |
|---|---|---|---|
| 6 | single, `federalCivilian` **$10,000** | $333.75 | **THE CAP.** Uncapped gives $146.25 |
| 7 | single, `otherStateOrLocal` $10,000 | $396.25 | out-of-state over-match |
| 8 | single, `federalCivilian` + `ownStateOrLocal` $2,000 each | $333.75 | pooled, not per-row (per-row gives $296.25) |
| 9 | MFJ 66/65, ONE `federalCivilian` $6,000 | $1,350.00 | non-doubling (flag `true` gives $1,287.50) |

All four expected values were derived from the fixture's own documented arithmetic
method (federal standard deduction $16,100/$32,200 base, $2,050/$1,650 age-65
addition, $6,000 OBBBA senior bonus per qualifying person under the
$75,000/$150,000 thresholds), cross-checked against the deduction totals cases 1
and 4 already state ($24,150 single at 66, $47,500 MFJ at 66/65). All four passed
on first measurement.

**The other constants I checked** beyond the cap, per the brief's instruction to
ask the question of every dimension:
- Every original row is `definedBenefit`, so `matchStructures` was untestable.
  Covered by `militaryInAnotherStructureIsNotFullyExcluded` and
  `denialRuleSpansEmployerStructuresOnly`.
- No original case had a non-qualifying **government** pension (all non-qualifying
  amounts were `privateEmployer`). Case 7.
- No original case had one taxpayer holding two qualifying pensions. Case 8.
- No original case had an MFJ household with the qualifying pension on one spouse.
  Case 9.
- `uniformedServices`, `railroadRetirement`, `governmentUnspecified` and `unknown`
  are reached by no fixture at all; the mirror sweep covers all of
  `PlanSource.allCases`.

## 7. Frozen baseline

**Zero movements.** No entry was added to
`RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json`, and
`StateTaxBehaviorBaselineTests` passes untouched. This is a consequence of the
design, not luck: `pensionExemption` and `exemptionAppliesPerIndividual` are both
unchanged, so the only new levers are the two per-source rules, and those fire only
on **classified** rows. The baseline grid classifies nothing, so every row infers
`(unknown, unknown)` and matches neither rule.

## 8. Step 7: the equivalence lists

- **`phase5CorrectedJurisdictions`: Arizona ADDED.** The JSON now carries
  `perSourceExemptions` and `unclassifiedPensionDisclosure`, neither of which exists
  in the frozen `configs2026Legacy`, so the re-encoded documents must diverge.
  `structurallyIdentical` passes for AZ with the addition and would fail without it.
- **`layerAProvenDivergentJurisdictions`: Arizona NOT added, MEASURED.** I
  temporarily added `.arizona`, ran
  `tools/run-tests.sh StateTaxJSONEquivalenceTests`, and the "at least one scenario
  diverged" assertion failed at `StateTaxJSONEquivalenceTests.swift:533` with
  `Expectation failed: observedDivergence`, i.e. none diverged. Then reverted. The
  reason is Kansas's and Massachusetts's second reason exactly: that grid's single
  `.pension` row is built without a classification, so it infers `(unknown,
  unknown)` and matches neither Arizona rule through either config. Recorded in the
  declaration's doc comment in the same shape as Kansas's and Massachusetts's.

## 9. DataManager mirror verification

`DataManager.stateTaxBreakdown` hand-duplicates the per-source partition (lines
~887 to 911) and has drifted from the engine five times on one branch. No golden
fixture reaches it, since the golden runner calls `TaxCalculationEngine` directly.

`breakdownMirrorAgreesWithTheEngineForArizona` sweeps **all of
`PlanSource.allCases`** and asserts two things per source: that
`breakdown.totalStateTax` equals `calculateStateTaxFromGross`, and that
`breakdown.pensionExemptAmount` is the right figure, which a total-only check
cannot catch. Expected attribution on a $10,000 pension: **$10,000** for
`uniformedServices`, **$0** for the three denied sources, **$2,500** for everything
else. All pass. I read the mirror's own cap branch (lines 1055 to 1067) to confirm
`pensionExemptAmt = perSourceExcludedPension + pooled exclusion`, so the attribution
is a real check on the partition and not on the total by another route.

Two further mirror checks: `ownStateAllowanceIsNotInheritedByComparison` drives the
`incomeSources(asResidentOf:)` remap (a Kansas KPERS holder comparing Arizona gets
$0, not Arizona's own-state allowance) and asserts breakdown and computation agree
on that path too. I also found and pinned a **second, pre-existing route** to
Arizona's military exclusion: `MilitaryRetirementExemption.stateTaxableAmount`
already returns `.fullyExempt` for `"AZ"`, but only for rows typed
`IncomeType.militaryRetirement`. That loop and the per-source partition are
disjoint (a row has one type), so there is no double exclusion, and after this task
the two routes finally agree. `bothMilitaryRoutesAgree` pins it. Before this task
the same money was taxed differently depending on which screen it was entered from.

I did not use a revert-mutation for the mirror, because the sweep asserts exact
attribution figures per source rather than only agreement, which is the stronger
check the mutation was standing in for.

## 10. Picker reachability

- `arizonaUserCanReachEveryClassificationTheRulesNeed`: all five rows Arizona's
  rules distinguish are in `options(for: .arizona, selected: nil)`.
- `arizonaDoesNotSuppressTheOwnStateRow`: `residenceNamesItsOwnJurisdiction(
  .arizona)` is **false**, so the generic own-state row survives for Arizona
  residents. This matters: it is the only way an Arizona State Retirement System
  retiree can describe their pension, and Line 29a covers it. The suppression fires
  only for a state whose own config names its own jurisdiction, which is New York
  alone.
- `arizonaNowPromptsForClassification`: shipping `perSourceExemptions` is what turns
  `shouldPromptForClassification` on for a jurisdiction. Arizona had no prompt
  before this task, so an Arizona user was never asked the question their tax now
  turns on. It now fires.

## 11. Disclosure copy: APPROVED BY JOHN, 2026-08-05

Task 3b's `rulesAndDisclosuresStayInLockstep` is bidirectional, so a sentence had to
ship for the suite to be green. I drafted the three options below and recommended A.
**John approved Option A as it stands on 2026-08-05**, so the sentence in
`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-AZ.json` is approved
user-facing copy, unchanged from what shipped. B and C are retained below as the
record of what was considered and rejected; neither is pending.

The approval is recorded in-repo on
`Phase5bArizonaPerSourceTests.arizonaDisclosureNamesBothLines`, because the sentence
lives in a JSON file that cannot carry a comment. That matches how Task 4's
Massachusetts copy and Task 3's picker labels were recorded in
`IncomeSourcesView.swift`.

**Option A: APPROVED AND SHIPPED.** Names both lines and the actual unclassified
default:

> Arizona excludes U.S. military retired pay in full and allows up to $2,500 for a
> federal, Arizona state or local government pension, but {scope} applies the $2,500
> allowance to any pension until it is classified.

**Option B: REJECTED (shorter, NY cadence).** Drops the government-only scoping:

> Arizona excludes U.S. military retired pay from state tax with no dollar cap, but
> {scope} applies the standard $2,500 government-pension exclusion until it is
> classified.

**Option C: REJECTED (shortest).**

> Arizona excludes military retired pay from state tax with no dollar cap, but
> {scope} caps your pension exclusion at $2,500 until it is classified.

The reasoning that selected **A**, kept because it is what a later rewrite has to
answer to. Arizona is the only jurisdiction in this phase whose unclassified default
is wrong in **both** directions: too little for a military retiree (who is owed an
uncapped exclusion) and too much for a private pensioner (who is owed nothing). B and
C describe only the first. A's clause "applies the $2,500 allowance to any pension"
is what lets a private pensioner understand that classifying may **raise** their
number, which no other state's sentence has had to say. A is longer than the New York
and Kansas sentences; that was the accepted cost.

All three satisfy the mechanical gates (`{scope}` exactly once, names Arizona, no em
dash, ends in a period, does not repeat the lead sentence).

## 12. Full suite

```
tools/run-tests.sh          # foreground, timeout 600000
Swift Testing:  Test run with 1966 tests in 300 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)
PASS. 2475 test(s) ran, no failures.
```

Baseline was 1,948 in 299 suites + 509. The delta is exactly `+18` tests in `+1`
suite, which is `Phase5bArizonaPerSourceTests` and nothing else: the four new golden
cases are argument rows inside existing parameterized tests and add no test count.
`MultiYearPerfTests` did not flake on this run, so the wrapper's isolation re-run
was not triggered and there is nothing to disclaim.

## 13. Things I disagreed with, or found wrong in the brief

1. **AZ-4's second row was NOT undocumented.** Addendum section 3 says it "has NO
   disclosure prose of its own, so it would otherwise be invisible to you." Its
   `source` field carries an extensive treatment of precisely that mislabel. The
   brief understated what was already in the fixture.
2. **The Kansas `unknown` precedent does not transfer directly.** The brief frames it
   as "Kansas's rule does not match `unknown`; ask the same question." Applying that
   shape literally to Arizona inverts its meaning, because Arizona's rule denies
   where Kansas's grants. I followed New York instead, and section 5 gives the
   reasoning.
3. **The real AZ-4 blocker is broader than the brief's framing.** The brief points at
   `exemptionAttribution` being household-wide. That is one of three blockers; the
   per-source partition also hardcodes `perIndividualMultiplier: 1.0`, and the
   golden fixture schema has no owner field, so the case could not be pinned even
   against a correct engine. Section 3.
4. **A latent trap the brief did not flag, and the largest finding here.** Nothing in
   the plan or addendum warned that a `.partial` treatment inside a
   `perSourceExemptions` rule produces a **per-row** cap. Arizona is the first
   jurisdiction in this phase that needs a capped per-source exclusion, so it is the
   first that could hit it, and the natural one-rule-per-form-line implementation
   walks straight into a bug that section 3.4a names as the phase's largest
   correctness risk. Both loops carry comments asserting "never a cap evaluated per
   row," which are true only by the accident that no shipped rule had used
   `.partial`. `noShippedPerSourceRuleIsCapped` now enforces it across all 51
   jurisdictions.

## 13a. CONSTRAINS THE REST OF THE PHASE. Read before Idaho, Vermont or DC

Recorded, deliberately not solved. Two limits on what this task actually
delivered, both of which the next capped jurisdiction will hit.

**1. The Arizona pattern generalizes to exactly ONE capped pool per state.** The
arrangement here (leave the cap in the pooled `pensionExemption`, use `.none`
per-source rules to evict the complement) works because Arizona has a single
$2,500 cap over a single group of qualifying sources. `pensionExemption` is one
field holding one `ExemptionLevel`, and the cap machinery runs once. **A
jurisdiction with two different caps on two different source groups cannot be
expressed this way at all**, and neither can one whose capped group needs a cap
different from its uncapped group beyond the `full`/`none` split. Idaho, Vermont
and DC all have capped exclusions and all remain in this phase. Whichever of them
needs a second cap faces a real fork: change the engine so a per-source rule can
carry a cap that is POOLED across its matched rows (which is the principled fix,
and would also make the AZ-4 per-taxpayer work tractable), or defer the
jurisdiction the way Hawaii was deferred. Discovering this at Idaho-implementation
time, with the one-rule-per-form-line instinct already in hand, is how the per-row
cap bug gets shipped.

**2. My 3.4a sweep is a guard on the CONFIGS, not a structural guarantee.**
`PerSourceExemptionRule.treatment` is still typed as the full
`RetirementIncomeExemptions.ExemptionLevel`, so `partial` and
`steppedPhaseoutByFilingStatus` remain constructible and decodable in a per-source
rule. `noShippedPerSourceRuleIsCapped` catches it only for the 51 bundled files,
at test time. Nothing stops the type from being used that way, and nothing catches
it in a config that is not one of the 51. The durable versions, both Phase 6
candidates: give `treatment` a narrower type admitting only `full` and `none`
(cheap, and makes the illegal state unrepresentable), or implement per-rule
pooling in the engine and mirror so a capped treatment means what a reader
expects. The first is a smaller change and closes the trap; the second is what
Arizona would actually have wanted and unblocks limit 1 above.

## 14. Recorded, not fixed

- **`railroadRetirement` falls through to the $2,500 cap.** Under 45 U.S.C. 231m,
  Railroad Retirement benefits are arguably exempt from state income tax outright,
  and Kansas already exempts them by name. The Arizona fixture carries no railroad
  case and no citation, and Step 1 forbids re-researching the law, so I left the
  status quo rather than guessing at either `full` or `none`. Direction is
  under-exemption. **Now recorded durably** as a second `AZ` entry in
  `knownButUnpinned`, with `theRailroadRetirementGapStaysRecorded` as its deletion
  guard, rather than living only in this report. (Added on review; the reviewer was
  right that a report is not a durable record.)
- **`governmentUnspecified` falls through to the $2,500 cap.** Jurisdiction never
  established, and `PlanSource`'s own doc comment forbids treating it as a specific
  jurisdiction, so neither naming it nor denying it is defensible without authority.
  Recorded inside the railroad entry's `blockedOn`, since it is the same question.
- **A `.pension` row classified as an IRA** `(ira, individual)` keeps the $2,500
  allowance, because the denial rule is scoped to the two employer structures to
  avoid touching `.rmd` rows. Low reachability.
- **The two loop comments** in `TaxCalculationEngine.swift` (~line 609) and
  `DataManager.swift` (~line 873) claim "never a cap evaluated per row." I left them
  unedited, since they remain true of everything shipped and the new sweep now
  enforces them, but they read as an invariant of the code when they are actually an
  invariant of the configs.

## 15. Files touched

| Path | Change |
|---|---|
| `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-AZ.json` | two per-source rules, disclosure sentence. `pensionExemption` and `exemptionAppliesPerIndividual` deliberately unchanged |
| `RetireSmartIRATests/GoldenScenarios/statetax-2026-AZ.golden.json` | 2 re-labels, 3 `knownDefect` blocks deleted, 4 cases added, AZ-4 prose rewritten, 3 stale names corrected. 5 scenarios to 9 |
| `RetireSmartIRATests/Phase5bArizonaPerSourceTests.swift` | NEW, 18 tests |
| `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift` | AZ added to `phase5CorrectedJurisdictions`; the Layer A measurement recorded |
| `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift` | new `AZ` `knownButUnpinned` entry |

No production Swift was modified. The engine and the mirror were read closely and
left untouched; the entire correction is config plus fixtures plus tests.
