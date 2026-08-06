# Task 9 report: Vermont and DC together

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`, branch
`feature/state-tax-phase5b`, parent `73e5d63`, single commit `5e81cf5`. Tree was clean at start and
is clean at finish.

**Outcome in one line: DC ships its rule and three defects are gone; Vermont is STILL UNSATISFIABLE
after Task 1's extension, which the plan names as the single most important finding of this phase.**

---

## 0. THE PLAN'S QUESTION, ANSWERED FIRST

> *Doing them together makes it obvious whether Task 1's extension actually solved the problem it was
> built for.*

**For DC: YES, completely, but the extension alone was not enough to ship.** The survivor flag was the
right axis and it separates DC-2/DC-3/DC-4 from DC-5 exactly as Task 1 predicted. What Task 1 did not
anticipate, and what the plan's chain does not list, is that DC also needs an AGE GATE ON THE RULE. It
had to be built here. Details in section 2.2.

**For Vermont: NO. NECESSARY BUT NOT SUFFICIENT, and the blocker was never the source vocabulary
alone.** Task 1 did dissolve the specific collision it was built for: VT-1 (CSRS, capped) and VT-5
(military, uncapped) no longer sit on the same `(federalCivilian, definedBenefit)` pair. That
collision is genuinely gone. Two independent blockers remain, and neither is about sources:

1. **One pooled cap and one `agiPhaseout` per jurisdiction, and Vermont needs two of each.** CSRS is
   $10,000 phasing out over $55,000-$65,000 single / $70,000-$80,000 MFJ. Military under Act 71 is
   UNCAPPED phasing out over $125,000-$175,000 for every filing status. A per-source rule can carry
   neither band (a matched row is excluded outright, and per-source exclusions are ADDED ON TOP of the
   phased-out pool rather than being phased out) and cannot carry the CSRS cap either (banned
   phase-wide).
2. **`federalCivilian` covers CSRS AND FERS**, and Vermont's exclusion applies, quoting VT-4's own
   source, *"only to benefits that are based on earnings not covered by the Social Security Act"*. FERS
   earnings are covered. There is no narrower source to name.

So the honest generalisation is: **Task 1 extended the WHO axis, and Vermont's remaining problem is on
the HOW MUCH and WHEN axes.** That is a real finding about the shape of the model, not about Vermont.

---

## 1. VERMONT

### 1.1 Options ENUMERATED, before any was declined

Idaho's review is the cautionary tale about declining without enumerating, so all four are here with
measured numbers, not just the one taken.

| # | Shape | Cases it turns green | Measured? | Verdict |
|---|---|---|---|---|
| A | Ship nothing | 0 of 6 | n/a | **TAKEN** |
| B | Pooled CSRS: `pensionExemption .partial(10000)` + `agiPhaseout` linear + two `.none` rules | **4 of 6** | YES, all four green | DECLINED, FERS over-match |
| C | Military `.full` on `uniformedServices`, unconditional | 1 of 6, BREAKS VT-6 | YES, VT-6 moved off pin | DECLINED, wrong |
| D | Military `.full` + a NEW income gate | 1 of 6, VT-6 stays pinned | not built | **RECOMMENDED TO JOHN**, not shipped |

### 1.2 Option B, MEASURED (Hawaii's method: ship it, measure it, revert it)

Temporarily written into `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-VT.json`:

```
pensionExemption: partial, maxExempt 10000
agiPhaseout: thresholdSingle 47150, thresholdMFJ 54300, shape linear perDollar 1.0
perSourceExemptions:
  1. deny (treatment none) every source EXCEPT federalCivilian, any structure
  2. deny (treatment none) federalCivilian at definedContribution / ira / unknown
```

`tools/run-tests.sh GoldenScenarioSingleYearTests` reported FOUR `defectAppearsFixed` issues, all VT,
and nothing else:

| Case | Pinned before | Published form | Result |
|---|---|---|---|
| VT-1 single CSRS AGI $40,000 | 1,077.03 | **742.03** | GREEN |
| VT-2 single CSRS AGI $60,000 (phase-out band) | 1,885.15 | **1,579.53** | GREEN |
| VT-3 MFJ CSRS $65,000 | 1,651.55 | **1,316.55** | GREEN |
| VT-4 MFJ CSRS + private | 1,316.55 | **981.55** | GREEN |
| VT-5, VT-6 military | 4,525.15 / 8,086.65 | unchanged | pins HELD |

Reverted with `git checkout --`; `git status --porcelain` confirmed clean before anything else ran.

**The green outcome was available and it is wrong.** The rule's pool membership can only be keyed on
`federalCivilian`, whose own doc comment reads *"US government civilian service: CSRS and FERS"*. So
every FERS annuitant in Vermont under the AGI threshold would receive a $10,000 exclusion Vermont does
not grant them.

**Why this is Hawaii and not Massachusetts.** Massachusetts shipped because its fixes rested on quoted
affirmative statute while its gap rested on an inference. Vermont has no such asymmetry: the grant
(VT-1's *"the Civil Service Retirement System"*) and the limiter (VT-4's *"only to benefits that are
based on earnings not covered by the Social Security Act"*) are BOTH quoted, and the limiter contains
the word "only". That is Hawaii's Schedule J situation exactly.

**Direction and population both point the same way.** Today's error is OVER-taxation. The rule would
trade it for UNDER-taxation of a LARGER population: CSRS closed to new entrants in 1984 and shrinks
every year, while FERS grows with every federal civilian hire. And the under-taxation would be
UNDISCLOSED, because `unclassifiedPensionDisclosure` fires only for an UNCLASSIFIED pension and these
users would have classified correctly.

**Marked as quoted authority vs inference:**
- QUOTED: CSRS qualifies (VT-1 source, IN-112 Section I). QUOTED: the exclusion is $10,000 capped
  (VT-1). QUOTED: the linear phase-out shape and bands (VT-2). QUOTED: the Social-Security-coverage
  limiter with the word "only" (VT-4). QUOTED: Act 71's $125,000 full-exemption sentence and its
  worksheet formula (VT-5, VT-6).
- INFERENCE (mine): that FERS earnings are Social-Security-covered and therefore FERS is outside the
  limiter. This is the one inferential step in the decline, and it is the standard characterisation of
  FERS. If John disagrees with it, Option B becomes shippable and the decision should be revisited.

**Magnitude, stated honestly against the decline.** The over-match is BOUNDED, unlike Hawaii's: the
$10,000 cap is fully phased out above AGI $65,000 / $80,000, and inside the band Vermont's rate is
3.35%, so the maximum wrong benefit is about $335 a year. That is much smaller than Hawaii's unbounded
11%-of-pension exposure, and a reasonable person could weigh it differently. **It is presented to John
as a judgement call in section 6, with a recommendation to hold.**

### 1.3 Option C, MEASURED

`matchSources ["uniformedServices"]`, `matchStructures ["definedBenefit"]`, treatment `full`.

- VT-5 (AGI $100,000): **$0.00, matches its published form, GREEN.**
- VT-6 (AGI $150,000): **$0.00 against the pinned $8,086.65 and a published $2,875.15. FAILED as
  `pinnedDefectMoved`.**

Reverted. The brief predicted this precisely ("If you find yourself about to ship a rule that makes
VT-5 green, check VT-6 before you believe it") and VT-6 did its job.

### 1.4 Option D, the shape that WOULD work, and why it was not built

Task 9 added `matchMinAge` to `PerSourceExemptionRule` for DC. An income-gated sibling
(`matchMaxIncome`) would let the military rule implement Act 71's quoted sentence exactly:

> *"For taxpayers of any filing status with adjusted gross income equal to or less than $125,000, all
> military retirement and survivor benefit income is exempt."*

Consequences, worked out but NOT measured (the field was not built): VT-5 green at $0.00; VT-6 falls
through the gate and stays pinned at $8,086.65; correct below $125,000; over-taxing (the safe
direction, and the status quo) inside the band; correct above $175,000. **No under-taxation anywhere.**
This is a real, Arizona-style partial correction worth $4,525.15 a year to a Vermont military retiree.

**One reason it was not built here, and it is a program-level decision rather than a Vermont one.**
`AGIPhaseout.reduced` and any income gate would compare against the `income` argument of
`calculateStateTax`, which `DataManager.calculateStateTaxFromGross` and the golden runner have already
reduced by the state standard deduction. So Vermont's config would have to carry **$117,150** where Act
71 says $125,000 (and $47,150 / $54,300 where IN-112 says $55,000 / $70,000 for Option B). Writing a
non-statutory number into a config file, in a phase whose whole method is "the fixture is the
specification", is the class of thing this program exists to catch. `AGIPhaseout`'s own doc comment
already flags this basis as unverified and defers it:

> *"Several statutes key off a state-specific AGI that is not that number ... each state's Phase 4
> golden scenario pins its own basis and Phase 5 corrects the call site if needed."*

**No Vermont fixture pins the basis.** VT-5 (AGI $100,000, income $92,150) and VT-6 (AGI $150,000,
income $142,150) sit on the same side of $125,000 under BOTH readings. So the basis choice would be
unverifiable by construction. Section 6 recommends the concrete fixture that would pin it (a VT-7 at
AGI $130,000, derivable from Act 71's already-quoted worksheet formula: fraction 0.9, exclusion
$117,000, taxable $5,150, tax **$172.53**).

### 1.5 What Vermont ships

- **No rule, no pooled exemption, no phase-out.** All six `knownDefect` blocks STAY, unmoved.
- **`RetireSmartIRATests/Phase5bVermontDecisionTests.swift`**, 8 tests, the decision made executable in
  the Hawaii / North Carolina / Idaho pattern. It includes a reflective tripwire on
  `RetirementIncomeExemptions`' stored properties, so the day a second pooled cap or a second
  phase-out arrives, Vermont is re-opened automatically. That is Task 8's mechanism, reused, and Task 8
  proved it works by catching me.
- **A picker caption** (section 5), because Vermont's $5,211.50 VT-6 gap is the largest in the phase
  and a Vermont resident sees NOTHING today: `shouldPromptForClassification` gates on
  `residenceHasPerSourceRules` (Vermont has none) and `UnclassifiedPensionDisclosure.text(for:
  .vermont)` is nil (lockstep with the rules).
- **Stale fixture prose rewritten**, not deleted. VT-1's and VT-5's `knownDefect.summary` both said
  "Task 9 writes them". They now record the decision and hand the instruction forward, following Task
  2's precedent.

### 1.6 Point 6 of the brief: `MilitaryRetirementExemption.swift`

Checked before writing anything. `MilitaryRetirementExemption.swift:204-205` returns `.fullyTaxable`
for `"VT"`. **Vermont ships no rule, so no third answer was created and no divergence was introduced.**
For the record, that table is stale against Act 71 (2025) and would give a `.militaryRetirement`-typed
row a different answer from a `uniformedServices`-classified `.pension` row if Vermont ever ships one.
Any future Vermont rule must update that entry in the same change. This is Task 7's finding, unchanged
and still open.

---

## 2. DISTRICT OF COLUMBIA

### 2.1 Options enumerated

The brief's note was right and I verified it against DC-5 before trusting the Scope table: subparagraph
(N)(i)'s "$3,000 at 62 or over" **EXPIRED for tax years beginning after 2014** and the app is already
correct to grant nothing for it. So there is exactly one live provision, (N)(ii), and one option shape:
a per-source rule keyed on the survivor fact plus the age gate. The only real choices inside it were
which sources to name (settled by the statute's "from the District of Columbia or the federal
government": `federalCivilian` and `ownStateOrLocal`, and NOT `otherStateOrLocal`) and where the age
gate lives (settled in 2.2).

### 2.2 The rule, and what it deliberately does NOT match

`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-DC.json`:

```json
"perSourceExemptions": [{
  "matchSources": ["federalCivilian", "ownStateOrLocal"],
  "matchStructures": ["definedBenefit"],
  "matchIsSurvivorBenefit": true,
  "matchMinAge": 62,
  "treatment": {"kind": "full"}
}]
```

It deliberately does NOT match: `otherStateOrLocal` (DC-6 is the guard), `privateEmployer`,
`nyStateOrLocal`, `uniformedServices`, `railroadRetirement`, `governmentUnspecified`, `individual`, or
`unknown`; any structure other than `definedBenefit`; any row whose survivor flag is `false` (DC-5) or
`nil`; and any row whose owner is under 62 (DC-1).

**Kansas's `unknown` precedent, and which kind of rule this is.** The brief flags that Kansas's
"do not match `unknown`" precedent INVERTS for a denial rule. **DC's is a GRANT rule, not a denial
rule**, so Kansas's precedent applies directly and unmodified: `unknown` is not named, an unclassified
DC pension gets nothing, the error runs toward over-taxation, and the disclosure sentence covers it.
The same reasoning governs the new survivor dimension: a `nil` flag means the question was never asked
and satisfies neither `true` nor `false`.

**THE AGE GATE IS MANDATORY AND IT IS NOT IN THE BRIEF'S CHAIN.** This is my main correction to the
brief. The per-source partition is documented as applying *"UNCONDITIONALLY (no age gate)"* because New
York's Line 26 exclusion has none, and `regularExemptionMinAge` cannot help: it gates the POOLED levels
through `resolveLevel`, which the partition never consults. I checked whether
`exemptionAttribution: .perQualifyingSpouse` could substitute, and it cannot: `ownerQualifies` returns
`true` unconditionally when `enableSpouse` is false, so DC-1 (a SINGLE filer at 55) would still match.
So `matchMinAge` had to be built. Without it DC-1 produces $0.00 against its pinned $1,924.00 and fails
as `unexplainedDisagreement`. The brief itself names DC-1 as the age-gate guard, so the omission is in
the chain list, not in the reasoning.

**`matchMinAge` gates on the ROW OWNER's age, not the household maximum.** D.C. Code
47-1803.02(a)(2)(N)(ii) conditions on the age of the person RECEIVING the benefit. This is the same
owner-age resolution the engine's existing military-retirement block already performs. It has a
side-effect on Idaho, in section 3.

### 2.3 The survivor chain I built

Task 1 added the flag to `RetirementPlanClassification` and stopped; Task 2 added it to the fixture
type. Everything between:

| Piece | File | Note |
|---|---|---|
| `isSurvivorBenefit: Bool?` | `IncomeModels.swift` | init param, CodingKeys, `encodeIfPresent`, `try?` decode |
| `isSurvivorBenefit: Bool?` | `RetirementDistributionComponent.swift` | `var` with default, see 2.4 |
| `matchIsSurvivorBenefit`, `matchMinAge` | `PerSourceExemptionRule.swift` | both `var` with `nil` default |
| two params on `matches()` | `PerSourceExemptionRule.swift` | defaulted, see 2.5 |
| two params on `matchedPerSourceRule` | `StateTaxData.swift` | defaulted, see 2.5 |
| new fields in hand-written `Equatable` | `StateTaxData.swift` | Layer B compares rules through this operator |
| 3 engine matching sites | `TaxCalculationEngine.swift` | plus an `ageOf(_:)` helper |
| 3 DataManager mirror sites | `DataManager.swift` | plus a mirrored `ageOf(_:)` |
| golden runner bridge | `GoldenScenarioSingleYearTests.swift` | passes `row.isSurvivorBenefit` straight through, `nil` included |
| picker affordance | `IncomeSourcesView.swift` | section 5 |

**Inertness proof, done the way Task 1 did it.** With every Swift change above in place and NO config
naming any new field, I ran the FULL suite. Result: **1,995 Swift Testing in 302 suites + 509 XCTest,
with exactly ONE failure, and it was not numeric.** New York, the canary and the only state shipping
`perSourceExemptions` at that point, was unmoved; so were Kansas, Massachusetts and Arizona; so was the
frozen 1,020-value baseline. The single failure was Task 8's Idaho reflection tripwire firing on the
new field, which is section 3.

### 2.4 What I did NOT build, and why (verify before you comply)

**The brief's chain lists a field on `IRAAccount`. I did not add it.** Four reasons, and I flag this as
a deliberate deviation for review:

1. `grep -rn "RetirementDistributionComponent(" RetireSmartIRA/` returns NOTHING. No production code
   constructs a component, so `distributionComponents` is `nil` at every production call site and an
   account-level survivor flag has no path to the matcher at all.
2. `IRAAccount` already carries `beneficiaryType`, `decedentRBDStatus` and four inherited-IRA date
   fields. A survivor fact about an account is already representable; a second overlapping flag creates
   two sources of truth.
3. DC's rule is `definedBenefit`-only and an `IRAAccount` never infers to `definedBenefit`.
4. The Global Constraint is "provably inert until a config opts into it". An unreachable PERSISTED
   field cannot be opted into, so it would be dead data written into every user's save file.

I DID add the field to `RetirementDistributionComponent`, because the engine's third matching site has
to pass something and `component.isSurvivorBenefit` is more honest than a hardcoded `nil`. It is
in-memory only, not persisted.

### 2.5 The defaulted-parameter decision, stated so a reviewer can disagree

I first made `matchedPerSourceRule`'s two new parameters REQUIRED, so no production site could forget
them. That broke about 20 call sites across `Phase5bKansasPerSourceTests`,
`Phase5bMassachusettsPerSourceTests`, `Phase5bArizonaPerSourceTests`, `Phase5bHawaiiDecisionTests` and
`Phase3bClassificationTests`. I reverted to defaults, for two reasons:

- **The churn is the risk.** Twenty mechanical edits inside four other tasks' test files, each an
  opportunity to alter what they assert, buys a property that is weaker than it looks.
- **A required parameter forces a site to write SOMETHING, not the RIGHT thing.** The mirror's actual
  drift mode on this branch has been wrong values, not missing arguments.
- **The failure direction of forgetting is safe.** A gated rule reached from a site that omitted the
  arguments matches NOTHING, so the exclusion goes unapplied and the taxpayer is over-taxed.

What guards the six production sites instead is behavioural: the mirror test in 2.7, proven by
mutation.

### 2.6 Blocks deleted, with MEASURED figures

All three measured by running the golden suite with the rule shipped and reading the reported form
values, never predicted:

| Case | `observedToday` (deleted) | Now produces | Published form |
|---|---|---|---|
| DC-2 single survivor 65, District pension | 1,924.00 | **0.00** | 0.00 |
| DC-3 MFJ 65/63, two survivors | 1,546.00 | **0.00** | 0.00 |
| DC-4 MFJ 65 survivor + 60 private | 3,848.50 | **1,846.00** | 1,846.00 |

Whole blocks deleted. No `observedToday`, `tier` or `expectedStateTax` was edited anywhere in this
task.

**Still pinned, and why: nothing.** DC now has zero `knownDefect` blocks. What DC has instead is a
`knownButUnpinned` entry (section 2.9), which is a different thing.

**Baseline movements: NONE, and no ledger entry is owed.** The frozen 1,020-value baseline did not
move; the full suite confirms it. The reason is structural, the same one that kept Kansas out of the
Layer A list: the baseline grid builds an unclassified `.pension` row that infers `(unknown, unknown)`
and carries no survivor flag, so DC's rule cannot match it, twice over.

### 2.7 The DataManager mirror verification

`DataManager.stateTaxBreakdown` hand-duplicates the engine's partition and has drifted five times on
this branch, and my pass-throughs land in exactly it. So I did what Task 3 did: **mutation, then
revert.**

I temporarily replaced `isSurvivorBenefit: row.isSurvivorBenefit` with a literal `nil` at the mirror's
pension-row site. `Phase5bDCSurvivorTests` failed with, exactly:

```
federalCivilian  breakdown 1924.00 vs computed 0.00 ; exempt 0 vs expected 50000
ownStateOrLocal  breakdown 1924.00 vs computed 0.00 ; exempt 0 vs expected 50000
theMirrorMovesOnBothNewAxes: survivorOver.pensionExemptAmount off by 50000.0
```

Reverted; `grep` confirmed zero remaining occurrences before the commit.

**A finding worth recording: the PRE-EXISTING mirror test did not catch it.**
`StateTaxBreakdownTests.breakdownMatchesCalculation` stayed green through the mutation, because no
existing test drives DC with a survivor row. The new sweep is what closes it.

### 2.8 Step 3: what would this rule wrongly match, and the case I ADDED

**DC-6, a Maryland state survivor annuity.** Single filer, 65, $50,000, `otherStateOrLocal`,
`definedBenefit`, `isSurvivorBenefit: true`, expected **$1,924.00**, NO `knownDefect` because the
engine already agrees both before and after the rule. Arithmetic identical to DC-1 and DC-5:
$50,000 - $14,600 = $35,400; 4% to $10,000 = $400.00; 6% on $25,400 = $1,524.00.

This is the case Task 2's reviewer said Task 9 owed DC after the `ownStateOrLocal` relabel left DC with
no out-of-state row. It is deliberately as close to DC-2 as the schema allows, differing ONLY in
`planSource`, so it fails if a future author widens `matchSources`, and it independently proves the
survivor flag alone is not sufficient.

Beyond the fixture, `dcRuleMatchesOnlyWhatTheStatuteNames` sweeps `PlanSource.allCases`, so a case
added by a later task is classified deliberately rather than by default.

### 2.9 The DC `knownButUnpinned` entry, with a non-vacuous deletion guard

**The defect:** a DC survivor annuitant whose pension row was saved before this task carries
`isSurvivorBenefit == nil`, gets no exclusion, and gets NO WARNING on any surface, because both
disclosure surfaces gate on the pension being UNCLASSIFIED and this user's is classified. They keep
paying DC-2's pre-correction $1,924.00 until they re-open the row.

**Why no golden case can pin it:** a fixture row either states the flag or omits it, and omitting it is
exactly what DC-5 does. A case for "a survivor benefit never asked about" would carry inputs
byte-identical to DC-5's with a contradictory `expectedStateTax`. This is admissible kind 2.

**The guard:** `theSilentlyOverTaxedExistingRowDefectStaysRecorded` fails if the entry is deleted, AND
re-derives the entry's condition from the SHIPPED config (`matchIsSurvivorBenefit == true`, and a `nil`
row still matching nothing), so the entry cannot outlive the defect either. That is the non-vacuous
half Task 6 was caught omitting.

Direction is over-taxation, the safe one. This is Task 4's input-surface-only disclosure gap in a new
form and belongs with it in Phase 6.

---

## 3. IDAHO WAS RE-OPENED. This is a cross-task finding.

Task 8 declined Idaho's military rule partly because `PerSourceExemptionRule` had no age dimension, and
asserted that BY REFLECTION so it would fail the day one arrived. **It fired on my first full-suite
run.** Excellent test design, and I treated it as an instruction rather than an obstacle.

**Re-measured, Hawaii's method.** Temporarily shipped `matchSources ["uniformedServices"]`,
`matchStructures ["definedBenefit"]`, `matchMinAge: 62`, treatment `full` into
`statetax-2026-ID.json`. Result: **ID-3 goes green at its published $0.00 and NOTHING ELSE MOVES.**
ID-7 (military at 55) stays correctly denied; ID-1 and ID-6 (civilians at 60 and 63) are untouched,
because the gate is on the rule and not the pool. Reverted.

**Two of Task 8's three objections are now GONE.** The age gate exists. And the household-attribution
objection ("an under-62 military spouse inherits a 62-plus spouse's gate") is gone too, because
`matchMinAge` reads the ROW OWNER's age.

**The decision survives on the third, and it is decisive.** Line 8a is a CAPPED maximum ($48,216 /
$72,324) reduced dollar-for-dollar by Social Security and Railroad Retirement received. `treatment:
full` is uncapped, and a `.partial` per-source treatment is banned phase-wide. Both over-exemptions ARE
pinnable (unlike Idaho's FERS collision), so Step 3 requires the catching cases be ADDED, at which
point the rule fails them. **Idaho still ships nothing.**

Records updated rather than silenced: the test is renamed and re-pointed at the surviving blocker, and
the ID `knownButUnpinned` entry now carries the re-measurement plus a correction, because half of its
"RESOLVE IT" sentence asked for a per-source age gate that now exists.

---

## 4. STEP 7, the equivalence lists

**DC goes on `phase5CorrectedJurisdictions`. DC does NOT go on
`layerAProvenDivergentJurisdictions`.**

MEASURED, not reasoned, per the documented precedent: I temporarily added `.districtOfColumbia` to
both lists and ran `StateTaxJSONEquivalenceTests`. The "at least one scenario diverged" assertion
FAILED with `observedDivergence` at line 533. Reverted the Layer A half.

Two INDEPENDENT reasons, either sufficient, both now documented at the declaration:

1. Kansas's second reason: the grid's single `.pension` row is built without a classification and
   infers `(unknown, unknown)`; DC's rule names `federalCivilian` and `ownStateOrLocal`.
2. DC's own: that row also carries no `isSurvivorBenefit`, and DC's rule sets
   `matchIsSurvivorBenefit: true`, which a `nil` row never satisfies.

**Vermont goes on neither list**, because Vermont ships no correction at all.

---

## 5. PICKER REACHABILITY, and the affordance the survivor flag needed

**The survivor flag had NO picker affordance, and without one DC's rule would have been unreachable.**
The twelve-row `PlanClassificationChoice` picker writes `planStructure`/`planSource` and nothing else,
so no sequence of user actions could set `isSurvivorBenefit`. Every DC golden case would have gone
green while a real DC survivor annuitant received nothing. **That is Task 3's Kansas failure exactly**,
and Task 3 established that adding the affordance is in scope when the alternative is an unreachable
rule. So I added it.

- A `Toggle` in the existing "What kind of pension is this?" section, gated on
  `PlanClassificationChoice.residenceUsesSurvivorDimension(_:)`, which is DERIVED FROM LIVE CONFIG
  (any shipped rule with a non-nil `matchIsSurvivorBenefit`) and never a hardcoded `== .districtOfColumbia`.
  Today exactly one jurisdiction asks; `onlyTheDistrictAsksTheSurvivorQuestion` sweeps
  `USState.allCases` to assert the gate and the config agree, and separately asserts the derived list
  is `[DC]` so a second jurisdiction updates it deliberately.
- **The `Bool` control to `Bool?` model mapping is where the care went.** Question shown, save the
  toggle (true OR false: the user saw it and answered). Question NOT shown, keep whatever the row
  already carried, which is `nil` for every never-asked row. This stops a Kansas resident's pension
  from being silently stamped "not a survivor benefit" by an editor that never asked, and stops a DC
  resident who moves away from losing an answer they gave. Also gated on `.pension`, mirroring
  `classificationToSave`.
- Both sources DC's rule names are reachable through existing rows
  ("Government pension, federal civilian" and "Government pension, my own state or locality", both
  added by Task 3), asserted by `dcsSourcesAreReachableFromThePicker` including the structure pairing.

**A pre-existing hazard this rule makes live, flagged not fixed.** Task 2's carried-forward item 1:
`ownStateOrLocal` is residence-relative but stored as a static label, so a KPERS pension classified in
Kansas keeps that label after a move to DC, where DC's rule plus the survivor flag would exempt income
DC does not exempt. Kansas's and Massachusetts's shipped rules already name `ownStateOrLocal`, so this
is not new, but DC extends its reach. It remains the most important open question on this branch.

---

## 6. COPY, ALL THREE APPROVED BY JOHN ON 2026-08-05, AS WRITTEN

**Status: settled.** All three items below were approved by John on 2026-08-05, exactly as they
stand, and the "PROPOSED COPY, AWAITING JOHN" markers are cleared from the tree. The rejected
alternatives are KEPT below as the record of what was considered and which way the decision went.
They are not open options; do not re-run this choice from them.

**Section 6.4 is a different thing and it is now also DECIDED.** John approved Vermont's wording on
2026-08-05 and, separately, accepted the unanimous HOLD recommendation the same day. Nothing in this
report awaits an answer.


### 6.1 DC disclosure sentence, APPROVED (shipped in `statetax-2026-DC.json`)

**Recommended, shipped, and APPROVED as written on 2026-08-05:**
> "The District of Columbia excludes a DC or federal government survivor benefit from tax with no
> dollar cap once the survivor is 62 or older, but {scope} taxes your pension in full until it is
> classified."

Alternatives drafted and REJECTED, kept as the record of what was considered:
- *"Washington DC excludes DC and federal government survivor benefits in full at age 62 and over, but
  {scope} taxes your pension in full until it is classified."* Rejected: "Washington DC" is less
  precise than the jurisdiction's own name, and "in full" reads as a total rather than as "uncapped".
- *"The District excludes a survivor annuity from the DC or federal government once the survivor is 62
  or older, but {scope} taxes your pension in full until it is classified."* Rejected: drops "no dollar
  cap", which is the fact that distinguishes this live provision from the expired $3,000 one a reader
  may remember.

Recommended because it names BOTH conditions a reader must test themselves against (the two employers
and the age) and keeps the shipped Kansas/Massachusetts trailing clause byte-for-byte, so the
over-taxation direction stays consistent across jurisdictions.

### 6.2 DC survivor toggle and its caption, APPROVED (shipped in `IncomeSourcesView.swift`)

**Recommended, shipped, and APPROVED as written on 2026-08-05:**
> Toggle label: "I receive this as a survivor or beneficiary"
>
> Caption: "The District of Columbia excludes a DC or federal government survivor annuity from tax once
> the survivor is 62 or older, but taxes an annuitant's own pension in full. Turn this on only for a
> pension paid to you as someone else's survivor or beneficiary."

Alternative label drafted and REJECTED, kept as the record: *"This is a survivor benefit"*. Rejected as ambiguous about WHOSE benefit:
a user reading it next to their own pension may think "yes, my spouse will survive me".

### 6.3 Vermont caption, APPROVED (shipped in `IncomeSourcesView.swift`)

**Recommended, shipped, and APPROVED as written on 2026-08-05:**
> "Vermont exempts up to $10,000 of Civil Service Retirement System income for filers under $55,000 of
> income ($70,000 if married filing jointly), and under 2025's Act 71 exempts military retired pay in
> full under $125,000 of income. This app applies neither exemption, so if you qualify your Vermont
> state tax may be overstated."

Alternatives drafted and REJECTED, kept as the record of what was considered:
- *"Vermont exempts some retirement income, including Civil Service and military retired pay, subject
  to income limits. This app does not apply those exemptions, so your Vermont state tax may be
  overstated."* Rejected: too vague to let a reader test whether it applies to them, which is the
  failure mode Task 8 explicitly named when choosing Idaho's wording.
- *"Vermont exempts military retired pay in full for filers under $125,000 of income. This app does not
  apply that exemption, so if you qualify your Vermont state tax may be overstated."* Rejected: names
  only the larger exclusion and leaves CSRS holders, who are four of Vermont's six fixtures, with
  nothing on screen.

### 6.4 THE JUDGEMENT CALL, DECIDED BY JOHN ON 2026-08-05: HOLD

**Should Vermont ship Option B (the CSRS shape) with a disclosed FERS gap, the way Massachusetts
shipped? ANSWERED: NO. John decided HOLD on 2026-08-05.** The arguments as they were put to him:

- FOR: four golden cases go green, MEASURED. The correction is real for every Vermont CSRS annuitant.
  The over-match is BOUNDED at roughly $335 a year and fully disappears above AGI $65,000 / $80,000,
  which is far smaller than Hawaii's unbounded exposure.
- AGAINST, and my recommendation: the over-matched population (FERS) is larger than the served one
  (CSRS, closed since 1984) and growing; the direction is UNDISCLOSED under-taxation, which is the
  dangerous one; and the limiter is QUOTED with the word "only", so this is Hawaii's test rather than
  Massachusetts's asymmetry.

**Recommendation: HOLD. Do not ship Option B. JOHN DECIDED HOLD on 2026-08-05**, so Vermont ships
no rule and keeps all six blocks by decision rather than by default. Instead take Option D in a Phase 6 model task, which is
strictly better: it corrects the LARGER Vermont defect ($4,525.15 versus roughly $335), introduces no
under-taxation at all, and forces the AGI-basis question to be settled deliberately with a VT-7 fixture
at AGI $130,000 (expected **$172.53**) to pin it.

---

## 7. THINGS I CHECKED THAT THE BRIEF ASKED ABOUT, briefly

- **Capped per-source treatment ban:** DC ships `full`. Task 6's sweep passes. Vermont ships nothing,
  and `Phase5bVermontDecisionTests` demonstrates the ban's bite numerically (two $6,000 CSRS rows draw
  $12,000 from a `.partial(10000)` treatment).
- **`rulesAndDisclosuresStayInLockstep`:** DC ships both a rule and a sentence. Vermont ships neither.
  Green in both directions.
- **Decode-trap / `PersistenceManager.loadAll`:** proven by EXECUTION, not reasoning.
  `PerSourceExemptionRule` round-trips both new fields and re-encodes a legacy rule WITHOUT the new
  keys (which is what keeps Layer B byte-comparable). `IncomeSource` round-trips `true` and `false`,
  omits the key when never asked, and a malformed value resolves to `nil` rather than throwing, with
  the whole array still decoding. That last one matters because `loadAll` wraps its decode in `try?`,
  so one throwing row discards every stored income source.
- **`var` not `let` with a default,** at all three new sites, for exactly Task 1's Critical reason.
- **No em dash characters** anywhere in the diff or the new files, verified by grep.

---

## 8. THE FULL SUITE, at the committed state

Command, foreground, `timeout` 600000:

```
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b && tools/run-tests.sh
```

Output:

```
Project:  /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ 5e81cf5
Scope:    full suite, five to six minutes. Run this in the FOREGROUND.

================ RESULT ================
Swift Testing:  Test run with 2018 tests in 304 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2527 test(s) ran, no failures.
```

Baseline was 1,995 Swift Testing in 302 suites + 509 XCTest. This task adds 23 tests and 2 suites
(`Phase5bDCSurvivorTests`, 15; `Phase5bVermontDecisionTests`, 8). **`MultiYearPerfTests` did not
flake on this run**, so there is nothing to disclose on that front.

---

## 9. FILES

Production:
- `RetireSmartIRA/PerSourceExemptionRule.swift`
- `RetireSmartIRA/StateTaxData.swift`
- `RetireSmartIRA/IncomeModels.swift`
- `RetireSmartIRA/RetirementDistributionComponent.swift`
- `RetireSmartIRA/TaxCalculationEngine.swift`
- `RetireSmartIRA/DataManager.swift`
- `RetireSmartIRA/IncomeSourcesView.swift`
- `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-DC.json`

Tests and fixtures:
- `RetireSmartIRATests/Phase5bDCSurvivorTests.swift` (new)
- `RetireSmartIRATests/Phase5bVermontDecisionTests.swift` (new)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-DC.golden.json`
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-VT.golden.json`
- `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`
- `RetireSmartIRATests/GoldenFixtureSurvivorFlagTests.swift`
- `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift`
- `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`
- `RetireSmartIRATests/Phase5bIdahoDecisionTests.swift`

Untouched, deliberately: `RetireSmartIRATests/Baselines/` (no movement), all Vermont config,
`MilitaryRetirementExemption.swift`, `AccountModels.swift`.

---

## 10. REVIEW FIXES (commit `cac85bd`)

**IMPORTANT 1, accepted in full.** DC's rule was unreachable from Multi-Year. The survivor flag was
dropped at `MultiYearInputAdapter.pensionClassification` and again at
`ProjectionEngine.computeStateTax`, so single-year excluded a qualifying survivor annuity while every
projected year taxed it in full. DC is the FIRST jurisdiction whose discriminant is not fully described
by `(structure, source)`, which is why NY, KS, MA and AZ never exposed it. Fixed at both sites.

One judgement inside the fix, worth a reviewer's eye: the adapter carries the flag **only when every
row for that owner agrees on it**. `hasMixedPensionClassification` compares structure and source only,
so a survivor annuity and an own pension from the same system pass it while disagreeing about the
survivor fact; applying either row's flag to the POOLED total would misattribute the other row's
dollars. A disagreement falls back to `nil`, claiming no exclusion, matching the conservative fallback
the structure/source guard already uses. `hasMixedPensionClassification` itself was deliberately NOT
widened, because it also drives a user-facing warning and that is a copy decision.

The age half needed no work: `matchMinAge` reads the ROW OWNER's age, and the ages `ProjectionEngine`
passes are the real projected ages, so the gate re-evaluates correctly as a household ages through 62.

**Both pass-throughs are tested, and both tests were proven capable of failing by reverted mutations.**
Nulling `ProjectionEngine`'s took the 66-year-old survivor from a $135.90 residual to the full
$3,304.92; nulling the adapter's turned every carried flag to `nil`.

One correction to my own first draft of that test: it asserted the multi-year survivor figure was
exactly `$0.00` and it is `$135.90`. That is NOT a defect. The household has no taxable balance and no
expenses, so `ProjectionEngine`'s Step 7 tax-funding cascade grosses up a traditional withdrawal to pay
the federal bill, and that withdrawal is itself DC-taxable. It is the same structural term
`GoldenScenarioCrossPathTests.newJerseyCrossPathGapPinnedAsObserved` decomposes. The test now asserts
the size of the effect against the unexcluded case, plus an exact equality at 55 where the flag must
change nothing.

**IMPORTANT 2, accepted.** `PerSourceExemptionRule`'s doc claimed `matchedPerSourceRule`'s parameters
are "deliberately NOT defaulted" and named two production call sites. Both false: they ARE defaulted
(section 2.5 explains why) and there are six. Rewritten to state what the code does, why the failure
direction of omitting an argument is safe, and which behavioural tests actually hold the property.

**Minors 3, 4 and 5, all accepted and fixed.** The two "UNCONDITIONALLY (no age gate)" comments in the
engine and its mirror; DC-2's pointer to a movements-ledger entry that does not exist and is not owed
(it now says so and why); the self-contradictory failure message in the Vermont decision tests.

**No disagreement with any finding.**

Full suite at `cac85bd`: `tools/run-tests.sh`, foreground, `timeout` 600000.
**2,020 Swift Testing in 304 suites + 509 XCTest, 0 failures, 2,529 total.** No `MultiYearPerfTests`
flake. Vermont's six blocks and its byte-unchanged config are intact, no pin moved, DC-1 and DC-5 still
pass.
