# Task 8: Idaho. Report

**Decision: Idaho ships NO `perSourceExemptions` and no pooled exemption. Its four
`knownDefect` blocks stay. Two guard cases were ADDED and they are the deliverable.**

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`,
branch `feature/state-tax-phase5b`, verified clean at HEAD `2f956fa` before the first
edit. One commit: `c0fe864`.

Claims below are marked **[QUOTED]** where they come from the fixture's own Form 39R
citations, **[MEASURED]** where a test run produced them, **[CODE]** where they come
from reading production source, and **[INFERENCE]** otherwise.

---

## 1. Expressibility triage, done before writing anything

I did this first, as instructed, and it decided the task. Idaho needs four things at
once. Three of them are individually inexpressible and the fourth is inexpressible in
combination.

### 1a. The qualifying list turns on facts the classification does not carry

Idaho's Line 8 deduction goes to a CLOSED list. **[QUOTED]** from ID-5's source:
"a closed list (CSRS/FSRDS, PERSI firefighters, certain Idaho police, retired service
members)". Two members of that list are not expressible.

**CSRS but not FERS.** **[QUOTED]** from ID-2's source: "Civil Service Employees:
Retirement annuities paid by the U.S. Civil Service Retirement System (CSRS)...To
qualify for the deduction, the employee must have established eligibility before
1984." **[CODE]** `PlanSource.federalCivilian`'s own doc comment says it means "US
government civilian service: CSRS **and FERS**", and `PlanClassificationChoice`
(`IncomeSourcesView.swift:108`) offers exactly ONE row, "Government pension, federal
civilian", writing `(definedBenefit, federalCivilian)`. There is no pre-1984
eligibility field anywhere on `RetirementPlanClassification`. The fixture says so
itself **[QUOTED]**: "This fixture stipulates the CSRS eligibility (established before
1984) in prose, as ClassifiedPensionSource has no field for it."

So any rule naming `federalCivilian` grants Idaho's deduction to every FERS retiree.

**PERSI firefighters and certain police, but not PERSI.** **[CODE]** the own-state
picker row writes `(definedBenefit, ownStateOrLocal)` for every Idaho public retiree,
teachers and general state employees included. There is no police-or-fire dimension.

### 1b. The population, which is what actually decided it

**[INFERENCE, but entailed by the quoted condition rather than imported]** A
requirement to have established eligibility before 1984 means the qualifying civilian
class CLOSED in 1984 and can never gain a member. Its complement has grown with every
federal civilian hire for forty-two years. So a `federalCivilian` rule is wrong for the
majority of Idaho's federal civilian retirees today and for a larger majority every
year, in the **under-taxation** direction.

This is North Carolina's Bailey argument with different dates, and it points the same
way: shipping would trade a bounded, disclosed over-taxation of a closed and shrinking
cohort for an undisclosed under-taxation of a growing one.

### 1c. Two age gates over ONE shared cap, which is inexpressible independently

This blocker survives even if 1a were solved, and it is the one the controller
addendum asked me to work out early.

Idaho needs: civilians gated at 65 (or 62 if disabled) **[QUOTED]** Part One, service
members gated at 62 (or any age if disabled) **[QUOTED]** Line 8e, both drawing on ONE
household cap of $48,216 single / $72,324 MFJ **[QUOTED]** Line 8a.

**[CODE]** what the model offers:

- The pooled `pensionExemption` carries exactly ONE cap and ONE `regularExemptionMinAge`.
- `earlyAgeTier` is the only second age dimension, and it is **source-blind**: it
  carries `ageRange` and `level` and nothing else, so lowering the gate to 62 for the
  service member lowers it for the civilian too. That IS the trap.
- `PerSourceExemptionRule` carries `matchSources`, `matchStructures`, `treatment` and
  **no age field at all**. `TaxCalculationEngine.swift:606` applies a matched rule
  "UNCONDITIONALLY (no age gate)", and `DataManager.swift:872` mirrors that comment
  verbatim.
- A capped per-source `treatment` is banned phase-wide because `treatment` is evaluated
  inside the per-row loop (`TaxCalculationEngine.swift:619-627`), so it caps per row.

So the two gates cannot share the one cap. **Arizona's workaround does not
generalise here**, exactly as the addendum suspected: it routes a cap through the
pooled exemption, which works only for ONE capped pool sharing ONE set of gates.
Idaho has one capped pool and two sets of gates.

I checked one thing the addendum did not raise, and it is worth recording: the cap
itself *is* expressible, via `.steppedPhaseoutByFilingStatus(maxExemptSingle: 48216,
maxExemptMFJ: 72324, tiers: [one band at 100%])`, because `.partial` carries a single
number and Idaho's MFJ cap is 1.5x its single cap rather than 2x, so
`exemptionAppliesPerIndividual` could not produce it. That avenue exists but does not
rescue the design, since the age-gate problem is untouched by it.

### 1d. Verdict

NOT EXPRESSIBLE. I used the program's established answer rather than forcing a rule:
ship no rule and record why (Hawaii, North Carolina). I did not widen anything.

---

## 2. Measurement, not argument

Hawaii's method is the standard, so I did not merely argue the tempting rules were
wrong. I shipped each temporarily into the real `statetax-2026-ID.json`, measured, and
reverted. **There were TWO tempting rules, not one.**

### Mutation 1: the age-62 pooled rule that Phase 4 warned about

`pensionExemption: partial(48216)`, `regularExemptionMinAge: 62`.

**[MEASURED]** `GoldenScenarioSingleYearTests` reported 5 issues for ID: four
`defectAppearsFixed` (ID-2, ID-3, ID-4, ID-5 all newly matching their published form)
and one `unexplainedDisagreement`. ID-1 passed correctly. Verbatim from the run:

```
ID / single filer, CSRS pension, age 63 ... : engine 0.0, form says 1266.7.
```

So the warning was exactly right: **all five original cases go green and the rule is
wrong**, because it encodes 62 as the CIVILIAN gate when Part One's civilian gate is
65. Reverted.

### Mutation 2: the ungated military per-source rule

`matchSources: ["uniformedServices"], matchStructures: ["definedBenefit"], treatment:
full`. This is the obvious way to give ID-3 its lenient Line 8e gate.

**[MEASURED]** 2 issues. Verbatim:

```
ID / single filer, military retired pay, age 63 ... now MATCHES its published form
(0.0). The defect appears to be FIXED.
ID / single filer, military retired pay, age 55 ... : engine 0.0, form says 1266.7.
```

So it fixes ID-3 and exempts military retired pay at **every age**, including well
below Line 8e's own 62. Reverted. The shipped ID config is byte-identical to its
pre-task state, confirmed by `git status`.

**Both green outcomes were available and both were wrong.** That is the whole finding.

---

## 3. The discriminating cases added, and how their values were derived

### ID-6: civilian at 63 (the case the brief required)

Single, age 63, `(definedBenefit, federalCivilian)` $40,000, federal AGI $40,000,
expects **$1,266.70**, no `knownDefect`.

Derivation, all **[QUOTED]** from Idaho's own fixture arithmetic rather than
recomputed by me: Part One requires 65, or 62 AND disabled; at 63 and not disabled the
taxpayer fails Part One and deducts nothing. The arithmetic is then ID-3's own,
unchanged, because ID-3 sits at the identical age and amount: federal standard
deduction at 63 is $16,100 base only (no age-65 addition, no OBBBA senior bonus),
$40,000 - $16,100 = $23,900, times the 5.3% flat rate = $1,266.70. **ID-3's existing
citation already attests the $16,100 figure at exactly age 63**, so no new arithmetic
was invented. **[MEASURED]** it passes today and passed on the first run.

Its inputs are ID-3's with ONE field changed. That is the point: at the same age 63
Idaho denies the civilian and allows the service member.

### ID-7: service member at 55 (the second guard, added on my own judgement)

Single, age 55, `(definedBenefit, uniformedServices)` $40,000, expects **$1,266.70**,
no `knownDefect`. Line 8e is more lenient than Part One but **[QUOTED]** it is not
ageless ("Classified as disabled (any age), or Age 62 or older"); at 55 and not
disabled this retiree deducts nothing. Same $16,100 / 5.3% arithmetic.

I added this beyond the brief because Step 3 is a requirement, not a preference, and
mutation 2 was a rule the fixture set could not catch. **[INFERENCE]** the population
it protects is not marginal: a service member retiring at twenty years is routinely in
their early forties, so the ungated rule would be wrong for most military retirees for
about two decades each, in the under-taxation direction.

### The other dimensions I checked for indistinguishability

The addendum asked what else is constant such that two rules would be
indistinguishable. Three more, all recorded in the catalogue entry rather than fixed:

- **The cap never binds observably.** ID-4 is *named* "exceeds the $72,324 MFJ
  deduction cap: tests the income-limited cap straddle", but **its own arithmetic
  floors taxable income at $0 whether the deduction is capped at $72,324 or
  uncapped at $80,000**. So no Idaho case distinguishes a capped rule from an
  uncapped one. **I disagree with the fixture's name here** and say so in section 10.
- **No case carries Social Security**, so Line 8a's dollar-for-dollar reduction by
  Social Security and Railroad Retirement benefits received is untested.
- **ID-5's private-pension exclusion is untested**: its $0.00 is reached whether or
  not the private $30,000 is excluded from the pool, because the floor is already hit.

---

## 4. The ID-3 re-label

Done, and it was owed. `federalCivilian` to `uniformedServices`.

**[MEASURED] value-neutral**: ID-3 reports $1,266.70 before and after, which is its
pinned `observedToday`, because Idaho ships no rule matching either label. So it
produced no baseline movement and needed no movements entry.

I verified the addendum's warning and it was correct: ID-3's `source` prose carried a
"LABEL STILL WRONG, RE-LABEL IN TASK 8" instruction that Task 2 wrote to hand forward,
and the label had NOT been fixed. I rewrote that prose into its done-form, recording
that the re-label happened, that it was measured value-neutral, and why it is
load-bearing rather than tidy: while ID-3 and the new ID-6 shared `federalCivilian`,
they demanded contradictory answers from one enum case at the same age 63. That is the
Vermont pattern Task 1 was built for.

---

## 5. knownDefect blocks: none deleted, four left pinned

**No block was deleted, and no `observedToday`, `tier` or `expectedStateTax` was
edited.** Because no rule shipped, all four remain, at their existing measured figures:

| Case | Shape | Expected | `observedToday` (unchanged) |
|---|---|---|---|
| ID-2 | single 68, CSRS $40k | $0.00 | $840.05 |
| ID-3 | single 63, military $40k | $0.00 | $1,266.70 |
| ID-4 | MFJ 68/70, CSRS $80k | $0.00 | $1,722.50 |
| ID-5 | MFJ 68/55, CSRS $40k + private $30k | $0.00 | $1,597.95 |

Left pinned because Idaho grants no Retirement Benefits Deduction at all and this task
could not correct that without shipping a rule that is wrong for a larger and growing
population than the one it helps.

**One `knownButUnpinned` entry added**, for the thing the four pinned blocks cannot
express: *why* they were not fixed. It records both eligibility conditions, the
population argument, and the independent two-gates-over-one-cap blocker. It carries
`NOT EXPRESSIBLE AS A GOLDEN CASE` and names the contradiction that forecloses Step 3
(a FERS retiree at 65+ has inputs byte-identical to ID-2's with a contradictory
`expectedStateTax` of $840.05 against $0.00).

**It has a deletion guard**, `theIdahoDeductionGapStaysRecorded`, because Task 6
shipped one without a guard and was caught.

---

## 6. Agreement with `MilitaryRetirementExemption.swift`

The addendum flagged this as the next place Task 7's divergence lands. **It does not
land here.** **[CODE]** `MilitaryRetirementExemption.swift:182` returns `.fullyTaxable`
for `"ID"`.

- Path 1, by income TYPE: fully taxable. **[MEASURED]** `stateTaxableAmount(gross:
  50_000, stateCode: "ID", age: 70) == 50_000`.
- Path 2, by CLASSIFICATION: fully taxable, because Idaho ships no rule.
  **[MEASURED]** $1,370.05 on a $50,000 pension at 70, the unexcluded figure.

**The two paths AGREE, and my answer agrees with both. No third answer was created.**
That agreement is now pinned by `theTwoMilitaryPathsAgreeForIdaho`, which measures
both paths so it fails the day either moves alone.

They agree on an answer that is **wrong** relative to Line 8e, which grants the
deduction from 62. That defect is already pinned by ID-3, so it needs no catalogue
entry of its own. What the test protects is that a future Idaho military rule must
move BOTH paths together, which is precisely what North Carolina failed to do.

---

## 7. DataManager mirror verification

**[CODE]** I read `DataManager.swift:824-911` against
`TaxCalculationEngine.swift:560-627`. The mirror is faithful: same
`ageQualifiesForExemption`, same `ownerQualifies`, same single-pass partition, same
"UNCONDITIONALLY (no age gate)" comment, and `matchedPerSourceRule` is the shared
predicate both call. Since Idaho ships no rule, it returns `nil` for every row in both
and each reduces to the pooled totals.

**[MEASURED]** `idahoIsUnaffectedByClassification` sweeps all 10 `PlanSource` cases and
asserts, for each, that the breakdown agrees with the computed tax to a cent, that
`pensionExemptAmount` is zero, and that the figure is the unexcluded $1,370.05. All 10
pass. This is also the empirical proof that the ID-3 re-label was value-neutral, since
`federalCivilian` and `uniformedServices` both appear in the sweep at the same figure.

I used a mutation-and-revert only on the config, matching Task 3's standard; the mirror
needed no mutation because it ships no Idaho-specific path.

---

## 8. Picker reachability

**[MEASURED]** `idahoUserCanReachTheRowsTheDecisionTurnsOn` asserts an Idaho resident
is offered `federalCivilianPension`, `ownStateGovernmentPension` and
`uniformedServicesPension`, and that `residenceNamesItsOwnJurisdiction(.idaho)` is
false so the generic own-state row is not suppressed.

This matters in the opposite direction from a task that ships a rule: **reachability is
what makes the over-match a real user-facing risk rather than a fixture artifact.** A
FERS retiree and a CSRS retiree both reach the same row and both would have been
granted the deduction.

I also pinned the consequence of shipping nothing:
`residenceHasPerSourceRules(.idaho)` is false, so
`shouldPromptForClassification` never fires for an Idaho resident, and
`UnclassifiedPensionDisclosure.text(for: .idaho)` is nil on both scopes. **Both
existing disclosure surfaces gate on the jurisdiction shipping rules**, so a
jurisdiction that ships no rule *because its law is inexpressible* is exactly the
jurisdiction whose users are told nothing. That is the wrong way round, and it is why
the caption exists.

---

## 9. Step 7 determination: NEITHER equivalence list

Idaho joins neither `phase5CorrectedJurisdictions` nor
`layerAProvenDivergentJurisdictions`.

**Reasoning, on the documented basis.** `phase5CorrectedJurisdictions` asserts a state
DIVERGES from the frozen legacy Swift table. **Nothing in `statetax-2026-ID.json`
changed** (verified: `git status` shows the file unmodified), so the JSON and the frozen
legacy entry still re-encode byte-identically, and the `else` branch of that test
asserts exactly that equality. Adding Idaho would make the suite fail. Since it is not
on the first list it cannot be on the second, which is a strict refinement.

This follows Hawaii's and North Carolina's precedent exactly: both shipped no rule and
both are on neither list. I also followed their precedent of leaving the config's
`verification.knownLimitations` **empty** and recording the decision in an executable
test file instead, rather than in config prose.

---

## 10. Things I disagreed with or corrected

1. **ID-4's name overstates what it tests.** It is named "exceeds the $72,324 MFJ
   deduction cap: tests the income-limited cap straddle", but its own arithmetic shows
   taxable income floors at $0 whether the cap binds or not. The cap binds on the
   deduction amount and **not observably on the tax**, so ID-4 does not discriminate a
   capped rule from an uncapped one. I did not edit the name (it is not a value, and
   the block is not mine to rewrite), but I recorded the gap in the catalogue entry.
   The controller addendum read that name as evidence "Idaho is capped", which is true
   of Idaho's law but not of what the fixture can verify.

2. **The addendum framed the cap as the thing to triage.** The cap turned out to be
   expressible (via `steppedPhaseoutByFilingStatus`, section 1c). The blockers are the
   **eligibility conditions** and the **two age gates**, neither of which the addendum
   named as decisive. I would not want a later reader to think the cap was the problem.

3. **"Idaho is income-limited" needs qualifying.** The plan's scope table says so and
   the addendum inferred `StateAGIPhaseout` might matter. **[QUOTED]** the fixture cites
   only a dollar cap and a dollar-for-dollar reduction by Social Security and Railroad
   Retirement benefits received. There is no AGI phaseout in Idaho's fixture, so
   `StateAGIPhaseout` and the "per-source exclusions are added on top of the phased-out
   pool" note at `DataManager.swift:1065` did not bear on this task at all.

4. **The brief asked for one discriminating case; I added two.** Mutation 2 was a real,
   reachable wrong rule that the five-case fixture set could not catch, and Step 3 says
   to add a case in exactly that situation.

5. **One deliberate divergence from NC's file.** The "no em or en dash" assertion is
   written with `\u{2014}` / `\u{2013}` escapes rather than the literal characters, so
   this phase's constraint holds under a mechanical grep of the source. Same assertion,
   same characters. `Phase5bNorthCarolinaDecisionTests.swift:477` still carries the
   literals; I did not touch another task's file, but a future sweep may want to.

---

## 11. PROPOSED disclosure wording

**PROPOSED, awaiting John's approval.** It ships now so the suite is green, on North
Carolina's precedent, because Idaho is the second jurisdiction this phase touched with
zero disclosure on any surface and a qualifying retiree is over-taxed by up to $840.05
a year at ID-2's shape with nothing on screen telling them. This is NOT an
`unclassifiedPensionDisclosure` sentence, and cannot be: that string is in bidirectional
lockstep with `perSourceExemptions`, and it would be false anyway, since an Idaho
pension can be perfectly classified and still taxed wrongly.

**Option A (RECOMMENDED, shipped):**

> Idaho deducts certain retirement benefits from state tax, including Civil Service
> (CSRS) annuities, some Idaho police and firefighter pensions, and military retired
> pay, generally from age 65 or from age 62 for retired service members. This app does
> not apply that deduction, so if you qualify your Idaho state tax may be overstated.

Recommended because it names the three qualifying groups AND both age gates, so a
reader can tell whether it applies to them.

**Option B (shorter, vaguer):**

> Idaho grants a Retirement Benefits Deduction for certain government, public safety
> and military pensions. This app does not model the eligibility rules, so if you
> qualify your Idaho state tax may be overstated.

**Option C (names the hard condition, arguably too much detail):**

> Idaho's Retirement Benefits Deduction covers only certain pensions, including CSRS
> annuities where eligibility was established before 1984, some Idaho police and
> firefighter pensions, and military retired pay. This app does not model those
> conditions, so if you qualify your Idaho state tax may be overstated.

"Overstated" is load-bearing in all three: Idaho applies no part of the deduction, so
every error runs toward over-taxation. Harmonising this with the Massachusetts caption
directly above it in the view would invert one of them.

---

## 12. Full suite

Exact command, foreground, at the COMMITTED state `c0fe864`:

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/tools/run-tests.sh
```

Output:

```
Project:  /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ c0fe864
Scope:    full suite, five to six minutes. Run this in the FOREGROUND.

================ RESULT ================
Swift Testing:  Test run with 1994 tests in 302 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2503 test(s) ran, no failures.
```

Against the stated baseline of 1,979 Swift Testing in 301 suites + 509 XCTest: **+15
Swift Testing tests, +1 suite**, which is exactly `Phase5bIdahoDecisionTests` and
nothing else. XCTest unchanged at 509. **No `MultiYearPerfTests` flake occurred**, so
no isolated re-run was needed. Zero baseline movements: the frozen baseline and
`statetax-behavior-movements-2026.json` were not touched, correctly, because no shipped
Idaho value moved.

## 13. Files changed

- `RetireSmartIRATests/GoldenScenarios/statetax-2026-ID.golden.json` (re-label, prose,
  two guard cases)
- `RetireSmartIRATests/Phase5bIdahoDecisionTests.swift` (new, 15 tests)
- `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift` (ID entry)
- `RetireSmartIRA/IncomeSourcesView.swift` (proposed caption + render site)

`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-ID.json` is **unchanged**.

---

# 14. REVIEW FIXES (commit `73e5d63`)

Review returned SPEC COMPLIANCE: PASS, John accepted the decline, and both captions were
approved. Five items plus two follow-ons were addressed in one commit.

## 14a. The substantive one: I missed a third option, and my record overstated the decline

**The review is right and I was wrong.** A partial, military-only correction existed in
Arizona's actual shipped shape and section 1c of this report never evaluated it. My
rebuttal of Arizona addressed only a COMPLETE Idaho rule, which is true and beside the
point of partial correction, the very thing the brief named as legitimate and that
Arizona itself did by leaving AZ-4 pinned.

**[MEASURED]**, not accepted on description. I applied it to the real shipped config:
`pensionExemption: .steppedPhaseoutByFilingStatus(48216, 72324, one 100% band)`,
`regularExemptionMinAge: 62`, plus one `.none` rule naming the nine non-military
`PlanSource` cases. Result: **ID-3 goes green and nothing else moves.** One issue
reported, `defectAppearsFixed` on ID-3. Reverted.

So a golden case going green was available for the `uniformedServices` branch, and
"a golden case going green is the deliverable" is the phase's own words.

**The decline stands on the review's reasons, not mine.** I independently recomputed the
load-bearing one rather than taking the figure: a single military retiree at 65 with a
$60,000 pension and $30,000 of Social Security has $35,850 of pre-deduction Idaho income,
a real maximum of $48,216 - $30,000 = $18,216, and therefore **$934.60** of tax against
the $0.00 the rule produces. That matches the review's ~$935 and it is the common
household, since most military retirees draw Social Security. Under-taxation is the
dangerous direction. Plus `exemptionAttribution: .household` letting an under-62 military
spouse inherit a 62-plus spouse's gate, and a `.none` list of nine hand-enumerated cases
where anything added later falls silently INTO the pool.

**The record was corrected, which matters more than the decision.** The catalogue
`blockedOn` now splits BRANCH 1 (`federalCivilian` / `ownStateOrLocal`, foreclosed
procedurally, catching case unpinnable) from BRANCH 2 (`uniformedServices`, EXPRESSIBLE,
declined as a judgement call) and names the three reasons for branch 2, noting that the
first two ARE pinnable so a future task may legitimately decide differently. Both
tripwire messages and the test file header were corrected the same way.

## 14b. Remaining items

- **MINOR 1.** `theTwoAgeGatesCannotShareTheOneCap` now compares the WHOLE stored-property
  set of `RetirementIncomeExemptions` against a 15-name list. The review is right that
  `filter { $0 == "regularExemptionMinAge" }.count == 1` could only catch a rename: a
  second age gate arrives as a differently named property and the count stays 1. The
  `pensionExemption` assertion is folded into the same set comparison, so it now has a
  message.
- **MINOR 2.** ID-4 renamed. **[MEASURED]** the safety claim first:
  `statetax-behavior-movements-2026.json` contains zero `"ID"` and zero `idaho`.
- **MINOR 3: I ADDED the cap guard.** ID-8, MFJ 68/70, $140,000 of CSRS pensions,
  expected **$1,069.33** derived from Line 8a ($92,500 post-standard-deduction less the
  $72,324 maximum, at 5.3%), **`observedToday` $4,902.50 MEASURED** before pinning. It is
  the only Idaho case where the maximum changes the answer; every other case floors at
  $0.00 capped or not, so an uncapped rule passed all of them. Idaho now carries five
  pinned defects. This also required narrowing
  `noIdahoGoldenCaseCanCatchTheFERSOverMatch` to uncapped households, since ID-8 is a
  taxable all-`federalCivilian` case for a cap reason unrelated to source.
- **Captions.** APPROVED markers set on both, wording untouched, all four PROPOSED
  markers cleared (two comments in `IncomeSourcesView`, two doc comments in the NC and ID
  test files).
- **Phase 6 finding** recorded at
  `.claude/memory/roadmap/2026-08-05-disclosure-surfaces-miss-the-no-rule-case.md`. I
  verified `GoldenScenarioCoverageTests.cannotVerify` exists as described before writing
  it, and added two findings of my own: `knownButUnpinned` has no production consumer,
  and the captions render only in the pension edit sheet.
- **`.claude/memory/decisions/log.md`** carried the coordinator's approval entry, which
  said Idaho keeps four blocks. I appended an amendment recording ID-8 and the ID-4
  rename, since that entry is now the durable record and was written before those landed.

## 14c. Full suite after review fixes

Same command, foreground, at committed `73e5d63`:

```
Swift Testing:  Test run with 1995 tests in 302 suites failed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

FAILING SUITES:
  MultiYearPerfTests

The only failing suite is MultiYearPerfTests, a known wall-clock flake.
Re-running it in isolation to check that claim...

  MultiYearPerfTests PASSED in isolation.
  Treating the full-suite failure as the known flake, NOT a regression.
```

**Stating it explicitly as the wrapper requires: the only failing suite was
`MultiYearPerfTests`, the known pre-existing wall-clock flake, and it PASSED when the
wrapper re-ran it in isolation. That is the evidence, and it is not a regression.** Test
count moved 1,994 to 1,995, the single new `theCapGuardCaseStaysInTheFixture`. XCTest
unchanged at 509.
