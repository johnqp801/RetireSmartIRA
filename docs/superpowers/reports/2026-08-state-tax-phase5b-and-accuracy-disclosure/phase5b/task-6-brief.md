# Task 6: Arizona

Task 6 has no heading of its own in `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md`:
it is one paragraph under the shared heading "Tasks 3 to 9: correct the eight jurisdictions". The
paragraph, the nine-step shared procedure and the Global Constraints are verbatim below, followed by a
CONTROLLER ADDENDUM carrying what Tasks 2 through 5 established afterwards.

---

## The task itself, verbatim from the plan

**Task 6: Arizona.** The $2,500 exclusion covers GOVERNMENT pensions only, and the app applies it to all
pensions, so it OVERSTATES. There is also a separate uncapped military exclusion. **Phase 4 flagged
Arizona as passing on wrong law today**: every civilian amount in its fixtures is under the $2,500 cap,
so an uncapped federal-civilian rule leaves cases green while being wrong above the cap. Read that
warning in the fixture before writing the rule, and consider adding a case above the cap.

From the plan's Scope table:

| Jurisdiction | Defects | Rule, to be verified against its fixture rather than trusted here |
|---|---|---|
| **AZ** | 4 | The $2,500 exclusion covers GOVERNMENT pensions only, plus a separate uncapped military exclusion |

---

## The shared procedure, verbatim from the plan

- [ ] **Step 1: The golden fixture is the specification.** Phase 4 derived every expected value from
      that jurisdiction's own published authority and a reviewer independently opened the documents. Do
      not research the law again. **One exception:** if the fixture does not carry enough detail to
      write the rule, say so and go to the primary source it cites. Report that you did.
- [ ] **Step 2: Read `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NY.json`** for the
      shipped shape of `perSourceExemptions`.
- [ ] **Step 3: Write the rule, and write it to FAIL for the right cases.** A rule that makes your
      fixtures pass while also matching something it should not is the defect this phase exists to
      prevent. For each rule ask: what would this wrongly match? If the fixture set has no case that
      would catch that, ADD one.
- [ ] **Step 4: Run the golden suite.** Cases you fixed now fail saying "delete the knownDefect block."
- [ ] **Step 5: Delete the resolved blocks.** Whole blocks, never edit `observedToday` to match. If a
      case you expected to resolve did not, diagnose and report rather than adjusting.
- [ ] **Step 6: Record baseline movements** with MEASURED `after` values and exact `goldenCase` names.
- [ ] **Step 7: Add the jurisdiction to the equivalence lists**, choosing between the two on the
      documented reasoning and explaining the choice.
- [ ] **Step 8: Run the FULL suite.** Diagnose each movement, name the test and the values, never silence.
- [ ] **Step 9: Report and commit** with explicit paths.

---

## Global Constraints, verbatim from the plan

- Every Swift change must be an ADDITIVE model extension, provably inert until a config opts into it.
- **The frozen 1,020-value baseline stays frozen.** Movements get entries in
  `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` whose `goldenCase` is
  MACHINE-CHECKED against real fixture scenario names. `after` values are MEASURED, never predicted.
- **Two equivalence lists.** `phase5CorrectedJurisdictions` asserts divergence from the frozen legacy
  Swift table. `layerAProvenDivergentJurisdictions` asserts at least one scenario in a fixed
  10-scenario grid diverges. Place each new state on the documented reasoning and say why.
- **A golden case going green is the deliverable.**
- **NO EM DASH CHARACTERS** anywhere.
- `MultiYearPerfTests` has a known pre-existing wall-clock flake; re-run in isolation.
- **RUN THE SUITE IN THE FOREGROUND WITH `timeout: 600000`.**
- **Never edit by chained `cd`.** Absolute paths and `git -C`.

---

# CONTROLLER ADDENDUM

## 1. THE TRAP, and it is visible in the data before you write anything

Every civilian amount in Arizona's fixtures is **$2,000**, and the cap is **$2,500**. So a rule that
exempts `federalCivilian` UNCAPPED and a rule that caps at $2,500 produce THE SAME NUMBER on every
existing case. Green tells you nothing here.

**The plan says "consider adding a case above the cap." Treat that as the deliverable, not a
suggestion.** Without it the phase ships an Arizona rule whose most important property is unverified.

Ask the same question of every other dimension of your rule, not just the cap. What else is constant
across all five cases such that two different rules would be indistinguishable?

## 2. AZ-4 MAY NOT BE EXPRESSIBLE, and you must find that out rather than assume either way

AZ-4 is MFJ with two government pensions of $2,000 each. Its name says **"AZ doubles the cap per
spouse"**, and its expected value differs from today's engine by a small amount consistent with the
engine applying ONE household cap where Arizona grants one PER TAXPAYER.

The Kansas fixture records that `exemptionAttribution` is **household-wide in this app's model**. If
Arizona needs a per-taxpayer cap and the model cannot express one, **that is a finding, and Task 5 has
just established how this program handles that**: Hawaii shipped no rule, kept its blocks, and recorded
the reason. You may correct some Arizona cases and leave AZ-4 pinned with its `knownDefect` intact, if
that is what the model supports. Say so plainly rather than forcing it or quietly widening the rule
until the number matches.

## 3. Fixture re-labels this task owes, left here deliberately by Task 2

Confirm each against the case's own `name` and `source` text rather than trusting this list:

- **AZ-3** is U.S. uniformed-services retired pay carrying `federalCivilian`. It should be
  `uniformedServices`. This matters more than a tidy-up: AZ-3 is exempt UNCAPPED under a separate line
  while AZ-1's genuine `federalCivilian` pension is capped at $2,500, so the two require CONTRADICTORY
  treatment from the same enum case until you relabel. That is the Vermont pattern Task 1 was built for.
- **AZ-4's second row** carries `otherStateOrLocal` for what is most likely ARIZONA'S OWN system, since
  Form 140 Line 29a covers US government plus Arizona state and local. Task 3's implementer found this
  and it has NO disclosure prose of its own, so it would otherwise be invisible to you. If you agree it
  is Arizona's own system, relabel to `ownStateOrLocal`. If you disagree, say why.
- AZ-3's `knownDefect.summary` carries prose Task 2 rewrote to hand this instruction forward. **Do not
  read that prose as evidence the labels were already fixed. They were not.**

## 4. THIS TASK OWES A DISCLOSURE SENTENCE if it ships a rule

Task 3b's `rulesAndDisclosuresStayInLockstep` FAILS THE SUITE if a jurisdiction ships
`perSourceExemptions` without a disclosure sentence, and it is bidirectional. Read New York's, Kansas's
and Massachusetts's entries for the established cadence and the `{scope}` token, which resolves to
"this figure" on State Comparison and "this plan" in the CPA briefing.

**The copy is user-facing and John approves it, not you.** Draft two or three options, recommend one,
ship your recommendation so the suite is green, and flag it prominently as PROPOSED.

## 5. What earlier tasks established that constrains you

- `governmentUnspecified` means "a government employer whose jurisdiction was not established", NOT any
  funding or attribution fact. Established from the enum's own doc comment in Task 4.
- Kansas's shipped rule deliberately does NOT match `unknown`, the migration default on every
  pre-Phase-3b saved row. Ask the same question for Arizona.
- Task 3 added three `PlanClassificationChoice` picker rows so a correct rule is reachable by a real
  user rather than only by a golden fixture. Check that an Arizona user can select what your rule needs,
  including that `residenceNamesItsOwnJurisdiction` does not suppress the own-state row for Arizona.
- **The DataManager mirror** at `DataManager.swift` roughly 828 to 851 and 892 to 906 hand-duplicates
  the engine's per-source logic and has drifted from the engine five times on one branch. Verify the
  breakdown agrees with the tax computation for Arizona and say how. Task 3 used a mutation it then
  reverted; match that standard.
- If a defect cannot be pinned by a golden case, `GoldenScenarioDefectCatalogueTests.knownButUnpinned`
  is where it goes, with a test that fails if the entry is deleted.

## 6. Standing constraints

- **ABSOLUTE PATHS and `git -C` only.** The controller's own shell silently reset to a different
  worktree on a different branch twice in this session.
- **NEVER edit a `knownDefect.observedToday`, a `tier`, or an `expectedStateTax`** to make a test pass.
- **VERIFY BEFORE YOU COMPLY.** Twelve times in this program a subagent has caught an error in the brief
  it was handed, including several of the controller's, and two would have put false statements into
  fixtures. Everything above is evidence, not fact.
- Baseline to beat: **1,948 Swift Testing in 299 suites + 509 XCTest, 0 failures.**
