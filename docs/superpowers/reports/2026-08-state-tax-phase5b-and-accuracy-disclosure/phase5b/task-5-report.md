# Task 5 report: Hawaii

Worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`, branch
`feature/state-tax-phase5b`, HEAD at start `c51f7a8`, working tree clean at start. Verified before the
first edit.

---

## 1. THE DECISION

**Outcome (b). Hawaii ships NO `perSourceExemptions`.** It stays "disclosed, not modelled" per Phase 4,
all three `knownDefect` blocks stay, no config file was touched, and no production Swift changed. The
plan's own text sanctions this ("if not, this is a disclosure item for Phase 6 and the blocks stay").

Not (a), and not (c). The defence for each is below, with every supporting claim marked
**[QUOTED]** (a sentence in a primary source or a doc comment reproduced on this branch),
**[MEASURED]** (a value this task produced by running code), or **[INFERENCE]**.

---

## 2. THE MEASUREMENT THAT DECIDED IT

I did not argue about what a `planStructure` rule would do. I shipped it temporarily and looked.

Added to `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-HI.json`:

```json
"perSourceExemptions": [
  { "matchSources": [], "matchStructures": ["definedBenefit"], "treatment": {"kind": "full"} }
]
```

`matchSources` had to be empty. Hawaii's rule does not key on employer type at all: **[QUOTED]** HI-1's
own source string, "Hawaii's rule keys on WHO FUNDED the plan, not on employer type (government vs.
private) -- a private-sector noncontributory pension qualifies exactly as a public one would." There is
no narrower shape available.

Command: `tools/run-tests.sh GoldenScenarioSingleYearTests`, foreground.

**[MEASURED]** result: three failures, all Hawaii, all of the form
`now MATCHES its published form`, with values `0.0`, `0.0` and `266.0`. Those are HI-1, HI-3 and HI-4,
and those are exactly their `expectedStateTax` values. In the golden harness's vocabulary that failure
IS success: it is the "delete the knownDefect block" signal from Step 4.

So the rule I declined would have turned three catalogued defects green, cleared Hawaii from the defect
catalogue entirely, and **not one fixture in the set would have objected**, even though the same rule
grants a full Hawaii exclusion to every contributory defined-benefit pension in the country. The
mutation was reverted (`git checkout --`), tree confirmed clean, before any other work started.

That is the brief's warning made concrete: "Do not choose the outcome that makes the most tests green."
The green outcome was available and it was wrong.

---

## 3. WHY (a) FAILS, claim by claim

### 3.1 The rule over-matches, and the over-match is contradicted by the very sentence that authorises the exclusion

**[QUOTED]** Hawaii Schedule J Instructions, REV 2025, page 2, via HI-1: "The pension exclusion applies
only to amounts attributable to employer contributions."

**[QUOTED]** mass.gov, Tax Treatment of Government Pensions in Massachusetts, via MA-1: "Massachusetts
state/local employee pensions are **contributory** annuity, pension, endowment, or retirement funds of
the Commonwealth of Massachusetts." That is quoted authority that contributory defined-benefit pensions
exist and are commonplace, and I did not have to research Hawaii ERS or any other plan to establish it.

**[QUOTED]** mass.gov's enumerated exempt list, via MA-2, names "federal **contributory**" pensions as a
category, which is quoted authority that federal civilian annuities are contributory.

**[INFERENCE]** Combining those: a Hawaii resident holding a contributory defined-benefit pension, of
which a CSRS or FERS annuity is the most common instance, qualifies for only part of the Schedule J
exclusion. A structure-only rule gives them all of it.

**[MEASURED]** `Phase5bHawaiiDecisionTests.theDeclinedRuleWouldExemptEveryContributoryPension` sweeps
`PlanSource.allCases` and confirms the declined rule matches every one at `definedBenefit`, including
`federalCivilian`, `ownStateOrLocal`, `governmentUnspecified` and `unknown`.

The asymmetry Task 4 relied on is absent here. Massachusetts's three corrections rested on affirmative
quoted statute naming exempt categories, while its gap rested on an inference from a closed list, so the
quoted side outweighed the inferred side. Hawaii has no such split: the exclusion and the over-match are
governed by the *same quoted sentence*, and the over-match is what that sentence's word "only" excludes.
There is nothing to weigh against nothing.

### 3.2 RETRACTED. I claimed the migration default would have claimed the exclusion. It would not.

The first version of this report and a committed test asserted that a structure-only Hawaii rule would
have swept up `unknown`, the migration default on every pre-Phase-3b saved row, and contrasted that with
Kansas's rule declining it. **That claim was false, and it was marked `[MEASURED]`, which made it worse
than merely wrong.** Caught in review; verified against the code before accepting.

**[QUOTED]** `RetirementPlanClassification.infer(incomeType:)` returns `(structure: .unknown, source:
.unknown)` for everything except `.rmd`, and `PlanClassificationUserSaveDecoding.decode` returns that
`inferredFallback` when the key is absent. So a migrated `.pension` row is `(unknown, unknown)`.

**[INFERENCE]** The declined rule carries `matchStructures: [.definedBenefit]`, which does not match
`structure == .unknown`. **Not one migrated row would have claimed a Hawaii exclusion.** What the test
actually proved was that `matches(structure: .definedBenefit, source: .unknown)` is true, a tuple no
`PlanClassificationChoice` writes and no migration path produces, reachable only as a forward-compat
downgrade when a recognised structure decodes beside an unrecognised source raw value. The Kansas
contrast was non-discriminating for the same reason: Kansas's rule also carries
`matchStructures: ["definedBenefit"]`, so it declines the real migration default by STRUCTURE, not by
naming its sources.

The test is deleted rather than renamed. Nothing behaves wrongly, this was never load-bearing for the
decision, and sections 3.1, 3.3 and 3.4 are untouched by the retraction.

### 3.3 Nothing would catch it, and Step 3's remedy is unavailable

Step 3 says: "For each rule ask: what would this wrongly match? If the fixture set has no case that
would catch that, ADD one." For Hawaii the second half cannot be done.

**[MEASURED]** `noHawaiiGoldenCaseCouldCatchTheOverMatch` reads the HI fixture and confirms HI-1's row is
`(definedBenefit, privateEmployer)`, which is byte-identical to what
`PlanClassificationChoice.privateEmployerPension` writes, the only row a contributory private-sector
defined-benefit retiree can honestly select. A fixture for the contributory household would therefore
carry inputs identical to HI-1's and a contradictory `expectedStateTax`. That is Task 4's blocker kind 2,
verbatim. The same test also confirms no existing HI scenario asserts a taxable all-`definedBenefit`
household, so nothing in the set catches it today either.

**NARROWED after review, because I stated this more universally than it holds.** The byte-identity
argument is airtight for the household that matters and decides the task: a contributory private-sector
defined-benefit retiree writes `(definedBenefit, privateEmployer)`, which is exactly HI-1's row, and no
fixture can separate the two. It is NOT universal. A contributory FEDERAL CIVILIAN household writes
`(definedBenefit, federalCivilian)` and is distinguishable by inputs, so byte-identity does not block a
fixture for it. What blocks that one is kind 1: no admissible partial figure. Both blockers are recorded
in the catalogue entry; it was this section that overstated, and the conclusion is unaffected, because
either blocker alone leaves Step 3 unsatisfiable for the private-sector household.

Step 3 is a requirement of the shared procedure, not a preference. It cannot be satisfied. That
forecloses (a) procedurally, independent of my judgement.

### 3.4 The direction of the error would flip, for a larger population

**[INFERENCE]** Today Hawaii over-taxes, which is the safe direction, and it is disclosed on two
surfaces. Shipping the rule would convert that into an undisclosed under-taxation, at a state whose top
marginal rate is 11 percent, for every contributory defined-benefit pensioner rather than for the
noncontributory subset the rule was meant to help. Massachusetts's accepted gap runs at a flat 5 percent
and is disclosed. Hawaii's would be larger, undisclosed, and would hit the population the rule was NOT
written for.

---

## 4. THE `definedBenefit` FUNDING-SEMANTICS CONTRADICTION, and which reading governs

**Neither reading governs. The field carries no funding semantics at all, and Hawaii's fixture prose has
been corrected to say so.**

**[QUOTED]** `PlanStructure.definedBenefit`'s doc comment is one line: "Traditional pension, annuitised."
It takes no position on funding. Verified by reading
`RetireSmartIRA/RetirementPlanClassification.swift:23-24`, not taken from the brief.

**[QUOTED]** HI-1's source claimed the opposite: "This app's PlanStructure axis is used as the proxy:
'definedBenefit' represents an employer-funded, noncontributory pension (no employee salary-deferral)."
Note the parenthetical: it equates "noncontributory" with "no employee salary-deferral", which is a
conflation. A contributory defined-benefit plan has mandatory employee contributions that are not
salary deferrals in the 401(k) sense but ARE employee contributions under Schedule J. **[INFERENCE]**
The proxy claim is unsound on its own terms, before the Massachusetts clash is even considered.

**[MEASURED]** The clash is reachable in one on-screen table, which is what makes it a defect rather
than a matter of taste. `DataManager.incomeSources(asResidentOf:)` (`DataManager.swift:592`) remaps
`planSource` for a cross-state comparison and hands `planStructure` through untouched. State Comparison
re-reads the same stored rows through every state's config. So one stored
`(definedBenefit, ownStateOrLocal)` row would be read as *contributory* by Massachusetts's column and as
*noncontributory* by Hawaii's column of the same grid, for the same household, at the same moment.
`residenceMappingNeverRemapsPlanStructure` and `definedBenefitCarriesNoFundingSemantics` pin both halves.

**What I did about it.** Amended two `source` strings in
`RetireSmartIRATests/GoldenScenarios/statetax-2026-HI.golden.json`, following Task 4's precedent of
correcting fixture prose in place with an explicit marker. The original proxy sentence is left standing
and the rejection follows it immediately, so a future reader cannot encounter one without the other. No
`name`, `tier`, `observedToday`, `expectedStateTax` or any other field was touched; verified
programmatically before writing, and the diff is two lines.

**Noted for a later pass, not acted on.** HI-1's `source` is now roughly 2,000 characters, and the shape
is wrong: task narrative wraps the Schedule J citation and pushes the arithmetic to the very end, where a
reader checking the number has furthest to go. The durable home for that narrative is the
`knownButUnpinned` catalogue, where it also lives. Rewriting fixture prose to trim it is not this task's
work and would churn a file whose values must not move, so it is recorded here for whoever next opens the
Hawaii fixture.

**Going forward:** `definedBenefit` means "traditional pension, annuitised" and nothing else. Both
shipped rules that use it (New York, Kansas, Massachusetts) are consistent with that, because each
carries its discriminating semantics in `matchSources`, not in the structure. Hawaii is the first
jurisdiction that would have needed the structure to mean something it does not, which is precisely why
it does not get a rule.

---

## 5. WHAT HI-3's `governmentUnspecified` ROW ACTUALLY ASSERTS

HI-3 is the MFJ case, `$40,000` at `(definedBenefit, privateEmployer)` plus `$35,000` at
`(definedBenefit, governmentUnspecified)`, expecting `$0.00`.

**[QUOTED]** `PlanSource.governmentUnspecified`'s doc comment: "A government employer whose jurisdiction
was not established." Task 4's finding that this does not mean "noncontributory" is correct, and I
verified it against the enum rather than accepting the brief.

**[INFERENCE]** So the row asserts, in the model, a traditional annuitised pension from a government
employer of unknown jurisdiction. It asserts nothing about funding. Its `$0.00` expected value depends
entirely on the noncontributory fact stated in the fixture's English prose and recorded in no field.

The consequence, stated precisely because it cuts both ways:

- HI-3 remains a **valid pin of today's defect**. Today's engine ignores classification for Hawaii
  entirely and taxes the full `$75,000` either way, so `observedToday: 2466.40` is right and the block
  stays.
- HI-3 could **never validate a rule**. It would pass identically whether a Hawaii rule respected the
  funding distinction or ignored it, which is the same criticism Task 4 levelled at MA-2 before renaming
  it. HI-3's `source` now records this.

One further point the brief did not raise. Hawaii's would have been the **first shipped rule ever to
match `governmentUnspecified`**. **[QUOTED]** `PerSourceExemptionRule.matches`'s doc comment says that
case "can only satisfy a rule whose `matchSources` is empty ... which no rule shipping in this phase
does." A structure-only Hawaii rule is exactly that shape. Not forbidden, but it would have quietly
retired a property the file's own documentation asserts.

---

## 6. WHY (c), BUILDING THE AXIS NOW, IS ALSO WRONG HERE

I took this seriously rather than dismissing it, because I am the task that was told to decide it.

1. **[QUOTED]** Task 4's own `knownButUnpinned` MA entry states the standard: "the phase's own precedent
   is that a shared classification axis lands in the model task (`isSurvivorBenefit`, Task 1) and is
   consumed by the jurisdiction tasks, not invented by one of them." Task 5 is a jurisdiction task.

2. **The two jurisdictions do not want the same axis, and this is the finding Task 4 asked Task 5 to
   supply.** **[QUOTED]** Massachusetts's exclusion is categorical: contributory excluded,
   noncontributory taxable, per mass.gov's closed list. **[QUOTED]** Hawaii's is proportional: "amounts
   attributable to employer contributions." **[INFERENCE]** A boolean `isEmployerFunded` axis designed
   from Massachusetts would be exactly right for Massachusetts and correct only at the two endpoints for
   Hawaii: a user whose pension is 90 percent employer-funded answering "I contributed" gets zero
   exclusion, and answering "I did not" gets all of it. Both wrong, and the second wrong in the
   dangerous direction. Most real contributory plans live in that middle.

3. **A fraction cannot be validated.** No golden case for a partially employer-funded Hawaii household
   can be written, because its `expectedStateTax` depends on that household's own employer-funded share,
   which is a fact about one plan and one participant and is not stated by any published source. Building
   a model extension with no golden case able to validate it is the pattern this phase exists to prevent.

So (c) is the right eventual answer and the wrong answer for this task. The axis needs a model task, both
jurisdictions in front of it, and a decision about proportion versus category before a line is written.
That is recorded, not just reported.

---

## 7. IS HAWAII'S PRODUCTION CAPTION STILL ACCURATE AND SUFFICIENT

**Accurate: yes, and unchanged. Sufficient: yes, with two corrections to the brief.**

The caption, `RetireSmartIRA/IncomeSourcesView.swift:1319`: "Hawaii excludes the employer-funded portion
of a pension from state tax. This app does not model the split between employer-funded and
employee-contributed amounts, so your Hawaii state tax may be overstated."

- "employer-funded portion" tracks **[QUOTED]** "only to amounts attributable to employer contributions."
  Accurate, and notably it says *portion*, which is more precise than any rule I could have shipped.
- "does not model the split" is still exactly true after this decision, because nothing changed.
- "may be overstated" is still the correct direction. Hawaii applies no exclusion at all, so every error
  runs toward over-taxation. Pinned by `hawaiisDisclosureStillHoldsAfterTheDecision`, which asserts
  "overstated" is present and "understated" is absent, so a future copy edit harmonising the Hawaii and
  Massachusetts captions cannot silently invert one of them.

**Correction 1 to the brief.** The addendum says Hawaii's caption appears "in one file each with no
test". For Hawaii that is not so. There are TWO surfaces: the Income Sources caption above, and
`MultiYearCPABriefing.hawaiiPensionSplitLimitation` (`MultiYearCPABriefing.swift:419`), which is a pure
function already covered by four tests in `Phase3bPresentationTests`. Massachusetts's caption really does
appear in one file with no test; Hawaii's does not. I have added content assertions for the CPA-briefing
string, since the pre-existing tests only checked the array was non-empty and would have passed on any
wording at all.

**Correction 2, a gap I am reporting rather than closing.** The Income Sources caption is still a
view-body string literal with no test seam, and the two Hawaii strings are hand-duplicated, differing by
exactly one word ("This app" against "This plan"), which is the same one-word divergence the `{scope}`
token was invented for in Task 3b. Hawaii cannot use that mechanism: `UnclassifiedPensionDisclosure`
gates on `unclassifiedPensionDisclosure`, which is in bidirectional lockstep with `perSourceExemptions`,
and Hawaii ships neither. Hoisting the literal is a production change with no behavioural gain, it
touches the file Task 4 just shipped, and Massachusetts's caption has the identical problem, so it is one
fix for two jurisdictions and belongs with Phase 6's disclosure work, not smuggled into a task that
otherwise changes no production code.

One substantive limitation, stated plainly: the caption is shown only on the `.pension` income form. A
Hawaii user whose pension income never passes through that form does not see it on that surface. The CPA
briefing gates on `hasPensionIncome` and covers more, but neither surface is universal. Phase 6.

---

## 8. STEPS 6 AND 7

**Step 6, baseline movements: NONE, and none possible.** No config file was modified, so no computed
value moved anywhere. `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` is untouched
and contains no HI entry. The frozen 1,020-value baseline is frozen.

**Step 7 determination: Hawaii goes on NEITHER equivalence list.**

- `phase5CorrectedJurisdictions` currently holds `[kansas, iowa, newMexico, georgia, utah, indiana,
  massachusetts]`. Membership asserts that the bundled JSON DELIBERATELY diverges from the frozen legacy
  Swift table. Hawaii's JSON is byte-identical to what it was at `c51f7a8`, so adding it would assert a
  divergence that does not exist and would simultaneously excuse Hawaii from Layer B's
  `structurallyIdentical` check, which is the check that would catch a Hawaii rule arriving by accident.
  Adding it would make the suite weaker and the assertion false.
- `layerAProvenDivergentJurisdictions` asserts at least one scenario in the fixed 10-scenario grid
  diverges. Nothing diverges, so this would fail outright. Massachusetts is already excluded from this
  list for a related reason recorded by Task 4.

Neither list changed. The full suite confirms Hawaii still passes `structurallyIdentical` and the Layer A
per-scenario identity check, which is the positive evidence that this task is inert.

---

## 9. WHAT I CHANGED

Three files, none of them production Swift, none of them a state config.

1. `RetireSmartIRATests/GoldenScenarios/statetax-2026-HI.golden.json` (2 lines). Prose appended to HI-1's
   and HI-3's `source` strings: the proxy-claim rejection with the measured result, and what the
   `governmentUnspecified` row actually asserts. Values verified unchanged programmatically.
2. `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift`. One `knownButUnpinned` entry for HI:
   the PARTIALLY employer-funded household. This is a real, cited, direction-known over-taxation that no
   golden case can hold, and it is the first entry in the list blocked by BOTH admissible kinds at once
   (no admissible figure AND not expressible). It doubles as the durable record of why Hawaii ships no
   rule.
3. `RetireSmartIRATests/Phase5bHawaiiDecisionTests.swift` (new, 10 tests). The decision made executable:
   Hawaii ships no rule and no disclosure sentence; the declined rule's over-match swept over
   `PlanSource.allCases`; the byte-identical-inputs blocker proven from fixture data; the model carries no
   funding axis; the `definedBenefit` contradiction and the cross-state mapping that makes it reachable;
   the breakdown mirror and inertness across every `PlanSource`; the unpinned entry's survival; the
   CPA-briefing disclosure's wording. Every failure message tells the next contributor what to do if they
   are deliberately changing the decision rather than breaking it.

   **Four review corrections applied.** The false migration-default test is deleted (section 3.2). Two
   unfalsifiable assertions are removed: both restated that an empty `matchSources` at `definedBenefit`
   matches everything, which is true by construction and looked like evidence. The funding tripwire moved
   off picker LABELS, where a row reading "Employer-paid pension" would have slipped past a substring
   check, onto the encoded key set of `RetirementPlanClassification` itself, which is what actually has to
   change for the decision to be revisited. And the disclosure gating test is dropped as a verbatim
   duplicate of `Phase3bPresentationTests`; the wording assertions are the new coverage and they stay.

**DataManager mirror check.** Not strictly owed, since I ship no rule, but done to Task 3's standard:
`hawaiiIsUnaffectedByClassification` sweeps `PlanSource.allCases`, asserts
`DataManager.stateTaxBreakdown` agrees with `calculateStateTaxFromGross` to the cent, asserts
`pensionExemptAmount` is zero for every source, and asserts the computed tax is the fixture's own
measured `$2,107.20`. That last assertion is what would catch a Hawaii exclusion arriving through the
mirror rather than through the config, which is the drift mode that has bitten this branch five times.

**Picker reachability check.** Asked and answered in the negative, which is itself the finding. No
`PlanClassificationChoice` row lets a user state who funded their plan, and the reason sits one level
below the picker: `RetirementPlanClassification` has no field to hold it, so no row could write one
however it were labelled. Pinned by `theModelCarriesNoFundingAxis`, which asserts the classification's
encoded key set is exactly `structure` / `source` / `isSurvivorBenefit` and fails the day a funding axis
is added, sending the reader back here.

**Disclosure wording options.** None drafted, deliberately. Shipping no rule means shipping no
`unclassifiedPensionDisclosure` sentence, and Task 3b's `rulesAndDisclosuresStayInLockstep` is
bidirectional, so a sentence without a rule fails the suite. The existing Hawaii caption is unchanged
approved copy and needs no re-approval. **Nothing in this task requires John's sign-off on user-facing
text.**

---

## 10. FULL SUITE

Command, run in the FOREGROUND with a 600000 ms timeout, from
`/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`:

```
tools/run-tests.sh
```

Output:

```
Project:  /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ 60323d0
Scope:    full suite, five to six minutes. Run this in the FOREGROUND.

================ RESULT ================
Swift Testing:  Test run with 1948 tests in 299 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2457 test(s) ran, no failures.
```

Baseline was 1,938 Swift Testing in 298 suites plus 509 XCTest. Now 1,948 in 299 plus 509: exactly one
new suite and its ten tests, no other movement, zero failures. (The pre-review run stood at 1,950 with
twelve tests; the two removed by review are the false migration-default test and the duplicated gating
test.) `MultiYearPerfTests` did not fail and the wrapper's isolation re-run was not triggered, so there is
nothing to disclaim on that front.

---

## 11. WHAT THE NEXT PERSON SHOULD KNOW

- Hawaii is NOT fixed and its three defects are NOT resolved. A green suite means Hawaii disagrees with
  Schedule J in exactly the catalogued way, which is the harness working as designed.
- The single easiest mistake available here is to read HI-1's original proxy sentence, write the
  four-line rule, watch three defects go green, and ship it. That path was walked and measured in this
  task. HI-1's `source` now warns about it in place.
- The real fix is a funding axis designed against Hawaii AND Massachusetts together, in a model task,
  with the proportion-versus-category question settled first. Both `knownButUnpinned` entries now say so
  and reference each other.
