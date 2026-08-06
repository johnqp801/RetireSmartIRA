# Task 5: Hawaii

Task 5 has no heading of its own in `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md`:
it is one paragraph under the shared heading "Tasks 3 to 9: correct the eight jurisdictions". The
paragraph, the nine-step shared procedure and the Global Constraints are reproduced verbatim below,
followed by a CONTROLLER ADDENDUM carrying what Tasks 3, 3b and 4 established afterwards.

---

## The task itself, verbatim from the plan

**Task 5: Hawaii.** The employer-funded portion is exempt with no cap and no age, while employee
contributions, 401(k) deferrals and IRAs are taxed. Phase 4 scoped Hawaii as "disclosed, not modelled."
Decide whether the employer-funded split is expressible now; if not, this is a disclosure item for
Phase 6 and the blocks stay.

From the plan's Scope table:

| Jurisdiction | Defects | Rule, to be verified against its fixture rather than trusted here |
|---|---|---|
| **HI** | 3 | Employer-funded portion exempt, no cap and no age; employee contributions, 401(k) deferrals and IRAs taxed |

**Note what that paragraph does NOT say.** It does not instruct you to ship a rule. It gives you a
decision with two legitimate outcomes, and "the blocks stay" is explicitly one of them.

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
- [ ] **Step 5: Delete the resolved blocks.** Whole blocks, never edit `observedToday` to match.
- [ ] **Step 6: Record baseline movements** with MEASURED `after` values and exact `goldenCase` names.
- [ ] **Step 7: Add the jurisdiction to the equivalence lists**, choosing between the two on the
      documented reasoning and explaining the choice.
- [ ] **Step 8: Run the FULL suite.** Diagnose each movement, name the test and the values, never silence.
- [ ] **Step 9: Report and commit** with explicit paths.

Steps 3 through 7 apply only if you conclude a rule should ship. If you conclude it should not, say so
and the deliverable is the decision, its defence, and the disclosure.

---

## Global Constraints, verbatim from the plan

- Every Swift change must be an ADDITIVE model extension, provably inert until a config opts into it.
- **The frozen 1,020-value baseline stays frozen.** Movements get entries in
  `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` whose `goldenCase` is
  MACHINE-CHECKED against real fixture scenario names. `after` values are MEASURED, never predicted.
- **Two equivalence lists.** `phase5CorrectedJurisdictions` asserts divergence from the frozen legacy
  Swift table. `layerAProvenDivergentJurisdictions` asserts at least one scenario in a fixed
  10-scenario grid diverges. Place each new state on the documented reasoning and say why.
- **A golden case going green is the deliverable.** Deleting a `knownDefect` block is how a correction
  is declared complete.
- **NO EM DASH CHARACTERS** anywhere.
- `MultiYearPerfTests` has a known pre-existing wall-clock flake; re-run in isolation rather than
  calling it a regression.
- **RUN THE SUITE IN THE FOREGROUND WITH `timeout: 600000`.**
- **Never edit by chained `cd`.** Absolute paths and `git -C`.

---

# CONTROLLER ADDENDUM

## 1. THE DECISION THIS TASK EXISTS TO MAKE, and the evidence Task 4 handed you

Hawaii's fixture expresses the employer-funded split through `planStructure`: `definedBenefit` for the
exempt employer-funded pensions, `definedContribution` for the taxable 401(k) deferrals. HI-1's own
`source` string says so outright: **"This app's PlanStructure axis is used as the proxy: 'definedBenefit'
represents an employer-funded, noncontributory pension."**

**Task 4 found that Massachusetts's fixture asserts the OPPOSITE of the same field.** MA-1 treats
`definedBenefit` as the CONTRIBUTORY Commonwealth pension, because M.G.L. c. 32 systems are contributory
defined-benefit plans by statute. `PlanStructure.definedBenefit`'s own doc comment says "Traditional
pension, annuitised" and takes no position on funding.

So two fixtures on this branch assign opposite funding semantics to the same field, and a reviewer
verified that independently. **Task 4 deliberately declined to build an employee-contributory axis from
four Massachusetts cases precisely so that Hawaii could decide it rather than inherit it. That is your
task.**

Decide and DEFEND one of:
- **(a) The split is expressible today** via `planStructure`, the rule ships, and the blocks are
  deleted. If you choose this, you must confront that real contributory defined-benefit pensions exist
  and Hawaii taxes their employee-funded portion, so ask what such a rule would WRONGLY match for a
  Hawaii resident and whether any fixture would catch it.
- **(b) The split is NOT expressible**, Hawaii remains "disclosed, not modelled" per Phase 4, the
  `knownDefect` blocks stay, and the deliverable is the decision plus its record. The plan explicitly
  sanctions this outcome.
- **(c) An employee-contributory axis should be built now**, having seen both jurisdictions' needs. If
  you choose this, it is a model extension and Task 1's standard applies: provably inert until a config
  opts in, with exclusivity tests proving both directions.

**Do not force it, and do not choose (a) merely because it makes three cases green.** Task 4 shipped a
rule that created a reachable under-taxation path and that was accepted only because the fixes rested
on quoted, affirmative statute text while the gap rested on an inference. Weigh Hawaii on the same
scale and say explicitly which side each of your claims sits on.

## 2. What Task 4 established that constrains your reasoning

- `governmentUnspecified` means "a government employer whose jurisdiction was not established", NOT
  "noncontributory". Established from the enum's own doc comment. **HI-3 carries a
  `governmentUnspecified` row.** Work out what that row actually asserts before relying on it.
- A golden case cannot pin a defect whose inputs would be byte-identical to an existing case with a
  contradictory expected value. That unavailability is a legitimate FINDING, not an excuse, and Task 4
  recorded such a gap in `GoldenScenarioDefectCatalogueTests.knownButUnpinned` plus a test that fails if
  the entry is deleted. Both mechanisms are available to you.
- Hawaii ALREADY HAS a production caption disclosing this limitation, added by Phase 3b Task 6, in
  `RetireSmartIRA/IncomeSourcesView.swift`. Read it. Judge whether it is still accurate and sufficient
  after whatever you decide, and note that Task 4's reviewer flagged both contributory captions as
  untestable, appearing in one file each with no test.

## 3. If and only if you ship a rule

- **You owe a disclosure sentence** in `statetax-2026-HI.json`. Task 3b's
  `rulesAndDisclosuresStayInLockstep` FAILS THE SUITE if a jurisdiction ships `perSourceExemptions`
  without one, and it is bidirectional, so do not add a sentence without a rule either. Read New York's,
  Kansas's and Massachusetts's for the established cadence, including the `{scope}` token that resolves
  to "this figure" on State Comparison and "this plan" in the CPA briefing.
- **The copy is user-facing and John approves it, not you.** Draft two or three options, recommend one,
  ship your recommendation so the suite is green, and flag it prominently as PROPOSED.
- **Check the DataManager mirror.** `DataManager.swift` around 828 to 851 and 892 to 906 hand-duplicates
  the engine's per-source logic and has drifted from the engine five times on one branch. Task 3
  verified it with a mutation it then reverted; match that standard.
- **Check the picker.** Task 3 added the three `PlanClassificationChoice` rows so a correct rule is
  reachable by a real user rather than only by a golden fixture. Ask whether a Hawaii user can actually
  select what your rule needs.

## 4. Standing constraints

- **ABSOLUTE PATHS and `git -C` only.** The controller's own shell silently reset to a different
  worktree on a different branch twice in this session.
- **NEVER edit a `knownDefect.observedToday`, a `tier`, or an `expectedStateTax`** to make a test pass.
- **VERIFY BEFORE YOU COMPLY.** Eleven times in this program a subagent has caught an error in the brief
  it was handed, including several of the controller's, and two would have put false statements into
  fixtures. Everything above is evidence, not fact.
- Baseline to beat: **1,938 Swift Testing in 298 suites + 509 XCTest, 0 failures.**
