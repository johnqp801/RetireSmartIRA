# Task 7: North Carolina

Task 7 has no heading of its own in `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md`:
it is one paragraph under the shared heading "Tasks 3 to 9: correct the eight jurisdictions". The
paragraph, the nine-step shared procedure and the Global Constraints are verbatim below, followed by a
CONTROLLER ADDENDUM.

---

## The task itself, verbatim from the plan

**Task 7: North Carolina.** Bailey keys on vesting before 1989-08-12 and the model has no vesting-date
axis. **Decide: add the axis, or record NC as remaining unsatisfiable.** Do not force it. Whichever you
choose, the report must say which and why, because Phase 4 deliberately kept "the law is clear but the
model cannot express it" separate from "the law could not be established."

The plan's Scope section also says, in its own words:

> **North Carolina may end this phase still unsatisfiable.** Its Bailey rule keys on a VESTING DATE, and
> the model has no vesting-date axis. Phase 4 recorded that as an expressibility gap rather than
> unresolved law. Task 7 decides whether to add the axis or record NC as remaining unsatisfiable; **do
> not force it.**

From the plan's Scope table:

| Jurisdiction | Defects | Rule, to be verified against its fixture rather than trusted here |
|---|---|---|
| **NC** | 3 | Bailey settlement class, vested before 1989-08-12, fully exempt |

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

Steps 3 through 7 apply only if you conclude a rule should ship.

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

## 1. THE DECISION, and the population arithmetic that should drive it

All three North Carolina defect cases carry `otherStateOrLocal` on what are North Carolina's OWN
systems, and each STIPULATES Bailey vesting in PROSE, because the fixture has no field for it. NC-2, a
private pension, is the only guard.

So the only rule the model can express is one keyed on source and structure, and **it would exempt
EVERY North Carolina state and local pension, not only the Bailey class.**

**Work out who that hits before deciding.** Bailey requires five or more years of creditable service as
of 1989-08-12, which means hired no later than roughly 1984. Every North Carolina public employee hired
after August 1989 is OUTSIDE the class and is fully taxable on that pension. Consider which of those two
groups is larger among people using retirement-planning software in 2026, and which direction the error
runs for each. **Say the answer explicitly in your report**, because it is the single most decision-
relevant fact and no fixture states it.

Compare with what this phase has already decided:
- **Massachusetts SHIPPED** with a disclosed under-taxation gap, because its three fixes rested on
  quoted, affirmative statute text while the gap rested on an inference. There was an evidentiary
  asymmetry to trade on.
- **Hawaii SHIPPED NO RULE** and kept its blocks, because Schedule J's authorising sentence contains the
  word "only", so the exclusion and the over-match came out of THE SAME quoted sentence, and the error
  direction would have flipped from disclosed over-taxation to undisclosed under-taxation over a larger
  population.

**Decide which of those two North Carolina resembles, and defend it.** Mark each supporting claim as
quoted authority or as inference. That distinction is what carried both earlier decisions.

The third option remains open: **add a vesting-date axis**. If you choose it, Task 1's standard applies,
provably inert until a config opts in, with exclusivity tests. Weigh honestly whether a date axis serving
one closed and shrinking cohort in one state earns a permanent model field, and whether a real user could
answer the question the picker would have to ask them.

## 2. Task 5's method is the standard

Hawaii did not argue the tempting rule was wrong. It temporarily shipped it, measured that every case
went green while the rule was demonstrably wrong, and reverted. **If you are choosing between shipping
and not shipping, measure the difference rather than reasoning about it.** A reviewer called that the
strongest evidence in the report.

## 3. The relabel, and it is owed regardless of your decision

Task 2 re-labelled Kansas, Vermont and DC and deliberately LEFT North Carolina to this task so the
relabel would land together with the rule. Scenarios 1, 3 and 4 label North Carolina's OWN systems as
`otherStateOrLocal`, which is documented as "a DIFFERENT state or its localities". **Task 2 also
recorded that NC discloses this NOWHERE**, unlike Arizona, Idaho and Massachusetts, inheriting it by a
"see the case above" reference to a case that itself disclosed nothing.

If you ship no rule, decide whether the relabel should still happen. It is factually correct either way
and changes no computed value, but it would leave a `ownStateOrLocal` label with no rule naming it.
Argue it rather than assuming.

## 4. If and only if you ship a rule

- **You owe a disclosure sentence** in `statetax-2026-NC.json`. `rulesAndDisclosuresStayInLockstep` is
  bidirectional: a rule without a sentence fails the suite, and so does a sentence without a rule. The
  copy is user-facing and John approves it, not you: draft two or three options, recommend one, ship
  your recommendation so the suite is green, and flag it prominently as PROPOSED.
- **A CAPPED PER-SOURCE TREATMENT IS BANNED.** `PerSourceExemptionRule.treatment` is evaluated INSIDE
  the per-row loop (`TaxCalculationEngine.swift:619-627`, `DataManager.swift:891-899`), so a `.partial`
  treatment caps PER ROW rather than per household. Design doc 3.4a calls this the phase's single
  largest correctness risk and this codebase has shipped that bug once, in New York's $20,000 exclusion.
  Task 6 added a sweep asserting no shipped rule anywhere carries a capped treatment. Bailey is
  uncapped, so this should not bind you, but confirm rather than assume.
- **Check the DataManager mirror** at roughly `DataManager.swift:828-851` and `892-906`, which
  hand-duplicates the engine's per-source logic and has drifted five times on this branch. Task 3 used a
  mutation it then reverted; match that standard.
- **Check picker reachability.** Task 3 added the three `PlanClassificationChoice` rows so a correct
  rule is reachable by a real user rather than only by a golden fixture.

## 5. What earlier tasks established that constrains you

- `governmentUnspecified` means "a government employer whose jurisdiction was not established", NOT any
  eligibility or funding fact. Do not press it into service as a Bailey marker.
- A defect that no golden case can pin goes in `GoldenScenarioDefectCatalogueTests.knownButUnpinned`,
  **with a test that fails if the entry is deleted.** Task 6 shipped the entry without the guard and a
  reviewer caught it; do not repeat that.
- Kansas's rule deliberately does not match `unknown`, the migration default on every pre-Phase-3b saved
  row. Task 6 found that precedent INVERTS for a denial rule. Work out which kind yours is, if any.

## 6. Standing constraints

- **ABSOLUTE PATHS and `git -C` only.** The controller's own shell silently reset to a different
  worktree on a different branch twice in this session.
- **NEVER edit a `knownDefect.observedToday`, a `tier`, or an `expectedStateTax`** to make a test pass.
- **VERIFY BEFORE YOU COMPLY.** Thirteen times in this program a subagent has caught an error in the
  brief it was handed, including several of the controller's, and two would have put false statements
  into fixtures. Everything above is evidence, not fact.
