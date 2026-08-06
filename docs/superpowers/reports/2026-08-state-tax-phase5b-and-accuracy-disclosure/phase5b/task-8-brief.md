# Task 8: Idaho

Task 8 has no heading of its own in `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md`:
it is one paragraph under the shared heading "Tasks 3 to 9: correct the eight jurisdictions". The
paragraph, the nine-step shared procedure and the Global Constraints are verbatim below, followed by a
CONTROLLER ADDENDUM.

---

## The task itself, verbatim from the plan

**Task 8: Idaho.** CSRS, Idaho police and fire, and military, at 65 or over (62 if disabled),
income-limited. **Phase 4 flagged Idaho as passing on wrong law today**: its only sub-62 case is at age
60, so a single age-62 gate turns all five cases green while being wrong for civilian retirees whose
real gate is 65. Read that warning first and consider adding a case that discriminates.

From the plan's Scope table:

| Jurisdiction | Defects | Rule, to be verified against its fixture rather than trusted here |
|---|---|---|
| **ID** | 4 | CSRS, Idaho police and fire, and military, at 65 or over (62 if disabled), income-limited |

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

---

## Global Constraints, verbatim from the plan

- Every Swift change must be an ADDITIVE model extension, provably inert until a config opts into it.
- **The frozen 1,020-value baseline stays frozen.** Movements get entries in
  `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` whose `goldenCase` is
  MACHINE-CHECKED against real fixture scenario names. `after` values are MEASURED, never predicted.
- **Two equivalence lists.** Place each new state on the documented reasoning and say why.
- **A golden case going green is the deliverable.**
- **NO EM DASH CHARACTERS** anywhere.
- `MultiYearPerfTests` has a known pre-existing wall-clock flake; re-run in isolation.
- **RUN THE SUITE IN THE FOREGROUND WITH `timeout: 600000`.**
- **Never edit by chained `cd`.** Absolute paths and `git -C`.

---

# CONTROLLER ADDENDUM

## 1. THE TRAP PHASE 4 NAMED, made concrete

Idaho's five cases sit at ages 60, 68, 63, 68/70 and 68/55. **The only case below 65 that should be
DENIED is ID-1 at age 60.** ID-3 is at 63 and should be ALLOWED, because it is military and military
uses a lower gate.

So a single age-62 gate makes all five cases green: 60 fails, 63/68/70 pass. And it is WRONG, because a
CIVILIAN retiree at 63 or 64 should be denied and no fixture tests that. **Adding a case that
discriminates 62 from 65 is the deliverable, not a suggestion.** Task 6 faced the identical shape with
Arizona's $2,500 cap, where every amount sat under the cap, and adding the above-cap case is what made
its rule verifiable.

Then ask the same question of every other dimension. What else is constant across all five cases such
that two different rules would be indistinguishable?

## 2. THE CONSTRAINT THAT MAY BLOCK YOU, and triage it BEFORE writing anything

**A CAPPED PER-SOURCE TREATMENT IS BANNED PHASE-WIDE.** `PerSourceExemptionRule.treatment` is evaluated
INSIDE the per-row loop (`TaxCalculationEngine.swift:619-627`, `DataManager.swift:891-899`), so a
`.partial` caps PER PENSION ROW rather than per household. Design doc 3.4a calls this the phase's single
largest correctness risk and this codebase HAS SHIPPED that bug once, in New York's $20,000 exclusion.
Task 6 added a sweep asserting no shipped rule in any of the 51 configs carries a capped treatment.

**Arizona's workaround was to route its cap through the existing POOLED `pensionExemption` and use
per-source rules only to keep non-qualifying sources OUT of the pool. That generalizes ONLY to a
jurisdiction with exactly ONE capped pool sharing ONE set of gates.**

Idaho looks like it may not fit. ID-4's name says it exceeds a $72,324 MFJ deduction cap, so Idaho is
capped. And the plan says civilians gate at 65 while military gate lower. **A single pooled exemption
carries one cap and one age gate.** If Idaho needs two different age gates over one shared cap, or two
caps, work out early whether that is expressible at all.

**Triage this before writing the rule and say what you found.** If it is not expressible, this program
has an established answer and you should use it rather than forcing a rule: Hawaii and North Carolina
both shipped NO rule, kept their `knownDefect` blocks, and recorded why. Partial correction is also
legitimate: Arizona corrected three cases and left AZ-4 pinned because the model could not express
per-taxpayer attribution. **What is NOT legitimate is widening the rule until the numbers match.**

## 3. Fixture re-labels this task owes

Confirm each against the case's own `name` and `source` text rather than trusting this list:

- **ID-3 is military retired pay carrying `federalCivilian`.** It should be `uniformedServices`. This is
  load-bearing rather than tidy: ID-3 at age 63 must be ALLOWED while a civilian at 63 must be DENIED,
  and both are `federalCivilian` today, so they require CONTRADICTORY treatment from the same enum case
  until you relabel. That is the Vermont pattern Task 1 was built for.
- ID-3's `source` carries prose Task 2 rewrote to hand this instruction forward. **Do not read that
  prose as evidence the label was already fixed. It was not.**
- Idaho's fixture also stipulates a CSRS eligibility condition ("established eligibility before 1984")
  in prose because the model has no field for it. Note what that means for what your rule can promise.

## 4. If you ship a rule

- **You owe a disclosure sentence** in `statetax-2026-ID.json`. `rulesAndDisclosuresStayInLockstep` is
  bidirectional. The copy is user-facing and John approves it: draft two or three options, recommend
  one, ship your recommendation so the suite is green, flag it prominently as PROPOSED.
- **Check the DataManager mirror** at roughly `DataManager.swift:828-851` and `892-906`. It
  hand-duplicates the engine's per-source logic and has drifted five times on this branch. Task 3 used a
  mutation it then reverted; match that standard.
- **Check picker reachability.** A rule no real user can select is a green suite and an undelivered fix.

## 5. A REACHABLE DIVERGENCE JUST FOUND IN TASK 7, and Idaho is the next place it lands

`MilitaryRetirementExemption.swift` ships per-state military answers gated on `source.type ==
.militaryRetirement`, NOT on `planSource == .uniformedServices`. So the same military pension can get
two different answers depending on how the user entered it. **Idaho is a military-exempting state and
ID-3 is a military case, so check what Idaho's entry in that file says before you write anything**, and
say in your report whether your rule agrees with it. Do not silently create a third answer.

## 6. What earlier tasks established that constrains you

- `governmentUnspecified` means "a government employer whose jurisdiction was not established", NOT any
  eligibility fact.
- Kansas's rule deliberately does not match `unknown`, the migration default on pre-Phase-3b saved rows.
  Task 6 found that precedent INVERTS for a DENIAL rule, because denying `unknown` raises tax for every
  unclassified user with no action on their part. Work out which kind yours is.
- A defect no golden case can pin goes in `GoldenScenarioDefectCatalogueTests.knownButUnpinned`, **with
  a test that fails if the entry is deleted.** Task 6 shipped one without the guard and was caught.

## 7. Standing constraints

- **ABSOLUTE PATHS and `git -C` only.**
- **NEVER edit a `knownDefect.observedToday`, a `tier`, or an `expectedStateTax`** to make a test pass.
- **VERIFY BEFORE YOU COMPLY.** Fourteen times in this program a subagent has caught an error in the
  brief it was handed, including several of the controller's, and two would have put false statements
  into fixtures. Everything above is evidence, not fact.
