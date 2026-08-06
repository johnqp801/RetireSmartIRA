# Task 3: Kansas

Extracted from `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md`. Task 3 has no
heading of its own in the plan: it is one paragraph under the shared heading "Tasks 3 to 9: correct the
eight jurisdictions", which carries a nine-step procedure written once for all of them. Both are
reproduced here verbatim, followed by the Global Constraints that bind this task.

---

## The task itself, verbatim from the plan

**Task 3: Kansas.** Completes the second half of a written promise to Steve Nicolai. The rule must
exempt `ownStateOrLocal`, `federalCivilian`, `uniformedServices` and `railroadRetirement` while leaving
`privateEmployer` taxable, and must NOT match `otherStateOrLocal`. Task 2's new negative case is what
proves the last part.

From the plan's Scope table, the row this task implements:

| Jurisdiction | Defects | Rule, to be verified against its fixture rather than trusted here |
|---|---|---|
| **KS** | 3 | KPERS, federal, military and Railroad Retirement exempt; private taxable. **Completes the second half of a written promise.** |

---

## The shared procedure, verbatim from the plan

- [ ] **Step 1: The golden fixture is the specification.** Phase 4 derived every expected value from
      that jurisdiction's own published authority and a reviewer independently opened the documents. Do
      not research the law again. **One exception:** if the fixture does not carry enough detail to
      write the rule, say so and go to the primary source it cites, exactly as the New Mexico task had
      to when only the first married bracket was quoted. Report that you did.
- [ ] **Step 2: Read `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NY.json`** for the
      shipped shape of `perSourceExemptions`. It is the only working example.
- [ ] **Step 3: Write the rule, and write it to FAIL for the right cases.** A rule that makes your
      fixtures pass while also matching something it should not is the defect this phase exists to
      prevent. For each rule ask: what would this wrongly match? If the fixture set has no case that
      would catch that, ADD one.
- [ ] **Step 4: Run the golden suite.** Cases you fixed now fail saying "delete the knownDefect block."
      That failure is success.
- [ ] **Step 5: Delete the resolved blocks.** Whole blocks, never edit `observedToday` to match. If a
      case you expected to resolve did not, diagnose and report rather than adjusting.
- [ ] **Step 6: Record baseline movements** with MEASURED `after` values and exact `goldenCase` names.
- [ ] **Step 7: Add the jurisdiction to the equivalence lists**, choosing between the two on the
      documented reasoning and explaining the choice.
- [ ] **Step 8: Run the FULL suite.** Other suites may legitimately move; diagnose each, name the test
      and the values, never silence.
- [ ] **Step 9: Report and commit** with explicit paths.

---

## Global Constraints that bind this task, verbatim from the plan

- **UNLIKE PHASE 5a, THIS PHASE CHANGES SWIFT.** 5a was config-only and its confinement rule was
  "nothing but JSON." That rule does not apply here. What replaces it: every Swift change must be an
  ADDITIVE model extension that is provably inert until a config opts into it, and Task 1's gate is
  what proves that.
- **The frozen 1,020-value baseline stays frozen.** Every deliberate movement gets an entry in
  `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` naming the golden case that
  authorises it. That `goldenCase` is MACHINE-CHECKED against real fixture scenario names, so a typo or
  an invented name fails the suite. `after` values are MEASURED from failure messages, never predicted.
- **Two equivalence lists, and they mean different things.** `phase5CorrectedJurisdictions` asserts a
  state DIVERGES from the frozen legacy Swift table. `layerAProvenDivergentJurisdictions` asserts at
  least one scenario in a fixed 10-scenario grid diverges. Kansas and Indiana are deliberately in the
  first and not the second, because that grid never exercises a personal exemption. Place each new
  state on the same reasoning and say why in the report.
- **A golden case going green is the deliverable.** Deleting a `knownDefect` block is how a correction
  is declared complete, and the block's own second assertion forces it: once the engine matches the
  form, the test fails saying "delete the knownDefect block."
- **NO EM DASH CHARACTERS** anywhere, including JSON strings, code comments and reports.
- **Tests are the source of truth.** `MultiYearPerfTests` has a known pre-existing wall-clock flake;
  re-run in isolation rather than calling it a regression.
- **RUN XCODEBUILD IN THE FOREGROUND WITH `timeout: 600000`.** Five agents on this project have stalled
  by backgrounding a build. The 120 second default is not the ceiling. Do not use `run_in_background`
  or Monitor.
- **Never edit by chained `cd`.** Use absolute paths and `git -C`.

---

# CONTROLLER ADDENDUM: added scope, authorized by John on 2026-08-05

**This is NOT in the plan.** The plan assumes Tasks 3 through 9 are config-shaped. A controller audit
before dispatch found that they cannot be, and John chose to fix it here, once, rather than five times.

## The finding

Task 1 added `ownStateOrLocal`, `uniformedServices` and `railroadRetirement` to `PlanSource`. The
user-facing picker is driven by a SEPARATE enum, `PlanClassificationChoice`, at
`RetireSmartIRA/IncomeSourcesView.swift:16`, whose options are unchanged since Phase 3b. **None of them
writes any of the three new cases.** A Kansas user classifying a KPERS pension has exactly one
government-pension option, "other state government pension", and it writes `otherStateOrLocal`.

So a CORRECT Kansas rule, which must match `ownStateOrLocal` and must NOT match `otherStateOrLocal`,
would turn every Kansas golden case green while a real KPERS holder still received no exemption. Task
10 Step 4 would then claim Kansas is complete and "Steve can be told so without qualification," and
that claim would be false.

## What this task must therefore also do

Extend `PlanClassificationChoice` with options that write `ownStateOrLocal`, `uniformedServices` and
`railroadRetirement`. **All three, even though Kansas alone needs only the first**, so Tasks 4, 6, 8 and
9 inherit a picker that can express their rules.

Surfaces to check, all in `RetireSmartIRA/IncomeSourcesView.swift` unless noted:
- the enum itself and its raw values
- the `classification` mapping from each choice to a `RetirementPlanClassification`
- **`choice(for:)`, the reverse lookup, and its EXPLICIT `priorityOrder` array.** That array is
  hand-maintained and does not use `allCases`. A new case omitted from it silently falls through to
  `.notSure`, which would mean an existing correctly-classified row displays as unclassified when
  edited. This is the single most likely silent defect in this part of the task.
- `showsPickerFor(accountType:)`, to confirm the new options inherit the right gating
- the `ForEach(PlanClassificationChoice.allCases)` picker body
- `accountDisplayName(accountType:planStructure:planSource:)`, which maps classifications back to
  display strings and may need the new tuples
- `residenceHasPerSourceRules` reads the live config and needs NO change: shipping Kansas
  `perSourceExemptions` turns the picker on for Kansas automatically. Confirm that, do not modify it.

Find the existing tests covering `PlanClassificationChoice` and its round trip and extend them. A new
case that round-trips through `classification` and back through `choice(for:)` must return itself.

## Two things to REPORT rather than solve

1. **There is no safe automatic migration for existing saved data.** A user who already classified
   their own state's pension as "other state government pension" has `otherStateOrLocal` persisted, and
   after this change that value means "genuinely a different state." You cannot tell those two apart
   from the stored value, so do NOT write a migration that guesses. Report the exposure and its size.
2. **The picker labels are user-facing copy and John has not approved them.** Implement with clear,
   plain working labels and list them PROMINENTLY in your report as PROPOSED, so they can be renamed
   without another build. Do not block on this.
