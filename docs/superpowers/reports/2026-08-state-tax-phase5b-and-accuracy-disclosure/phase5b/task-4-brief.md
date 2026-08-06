# Task 4: Massachusetts

Task 4 has no heading of its own in `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md`:
it is one paragraph under the shared heading "Tasks 3 to 9: correct the eight jurisdictions", which
carries a nine-step procedure written once for all of them. Both are reproduced verbatim below,
followed by the binding Global Constraints and then a CONTROLLER ADDENDUM carrying work established
after the plan was written.

---

## The task itself, verbatim from the plan

**Task 4: Massachusetts.** Contributory state and local exempt, noncontributory municipal taxable, US
uniformed services exempt. The contributory-versus-noncontributory distinction may need a judgement
about whether it maps to an existing axis; if it does not, say so rather than forcing it.

From the plan's Scope table:

| Jurisdiction | Defects | Rule, to be verified against its fixture rather than trusted here |
|---|---|---|
| **MA** | 3 | Contributory MA state and local exempt; noncontributory municipal taxable; US uniformed services exempt |

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

## Global Constraints, verbatim from the plan

- **UNLIKE PHASE 5a, THIS PHASE CHANGES SWIFT.** Every Swift change must be an ADDITIVE model extension
  that is provably inert until a config opts into it.
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
  is declared complete.
- **NO EM DASH CHARACTERS** anywhere, including JSON strings, code comments and reports.
- **Tests are the source of truth.** `MultiYearPerfTests` has a known pre-existing wall-clock flake;
  re-run in isolation rather than calling it a regression.
- **RUN THE SUITE IN THE FOREGROUND WITH `timeout: 600000`.** Do not use `run_in_background` or Monitor.
- **Never edit by chained `cd`.** Use absolute paths and `git -C`.

---

# CONTROLLER ADDENDUM: what Tasks 2, 3 and 3b established after the plan was written

## 1. Fixture re-labels this task owes, deliberately left to you

Task 2 re-labelled Kansas, Vermont and DC, and deliberately LEFT Massachusetts to this task so the
relabel lands together with the rule and its guard case, exactly as Kansas did across Tasks 2 and 3.
Confirm each against the case's own `name` and `source` text rather than trusting this list:

- **MA-1 and MA-3** label Massachusetts's OWN contributory systems as `otherStateOrLocal`. That case is
  documented as "a DIFFERENT state or its localities", so this is the same mislabel Kansas carried.
  They should be `ownStateOrLocal`.
- **MA-4** labels a U.S. uniformed-services pension as `federalCivilian`. It should be
  `uniformedServices`.
- MA-1 and MA-4's `source` strings carry a disclosure that the enum has no such case. Task 2 rewrote
  that prose to hand the instruction forward. **Do not read that prose as evidence the labels were
  already fixed. They were not.** Correct the prose once you have corrected the labels.

## 2. THE JUDGEMENT THE PLAN ASKS FOR, and what makes it hard

MA-2 is the noncontributory municipal pension, correctly taxable, carrying no `knownDefect`, and it is
labelled `governmentUnspecified`. So the contributory-versus-noncontributory distinction is currently
carried by the difference between `ownStateOrLocal` and `governmentUnspecified`.

**`governmentUnspecified` does not mean "noncontributory". It means "government, unspecified which".**
Using it as the noncontributory marker is a forced fit, and the plan explicitly tells you to say so
rather than force it. Before writing the rule, decide and defend one of:
  (a) the mapping is legitimate and MA-2 is a real guard, or
  (b) it is a forced fit, in which case say what axis Massachusetts actually needs and whether adding
      it belongs here or in a later phase. **Do not force it.**

Whichever you choose, note that a real Massachusetts user with a noncontributory municipal pension
would plausibly select the picker's own-state option and wrongly receive the exemption, because the
picker cannot express contributory versus noncontributory either. Say what that means for whether
Massachusetts can be called complete.

## 3. The picker (Task 3 built it, and Massachusetts is its first real reuse)

Task 3 added three `PlanClassificationChoice` options writing `ownStateOrLocal`, `uniformedServices`
and `railroadRetirement`, precisely so a correct rule would be reachable by a real user rather than
only by a golden fixture. Massachusetts's rule needs the first two. **Verify they are genuinely
reachable for a Massachusetts resident**, including the suppression logic Task 3 added
(`residenceNamesItsOwnJurisdiction`), which suppresses the own-state option ONLY for a resident whose
config names a jurisdiction-specific source. Massachusetts should NOT suppress. Confirm, do not assume.

## 4. THIS TASK OWES A DISCLOSURE SENTENCE, and John must approve the wording

Task 3b made the two unclassified-pension disclosures read live config. The sweep
`rulesAndDisclosuresStayInLockstep` FAILS THE SUITE if a jurisdiction ships `perSourceExemptions`
without a disclosure sentence, so this is not optional and you will see it fail if you skip it.

Shape: sentence one is jurisdiction-independent and lives in code. Your config supplies sentence two,
carrying the `{scope}` token that resolves to "this figure" on State Comparison and "this plan" in the
CPA briefing. Read New York's and Kansas's entries for the established cadence.

**The copy is user-facing and John approves it, not you.** Draft two or three options in your report,
recommend one, and ship your recommendation so the suite is green. Flag prominently that it is
PROPOSED and awaiting approval, exactly as Task 3 did with the picker labels. Kansas's approved
sentence is the model:

    Kansas exempts a KPERS, federal government, military or Railroad Retirement pension from state
    tax with no dollar cap, but {scope} taxes your pension in full until it is classified.

## 5. Known trap: the DataManager mirror

`DataManager.swift` around 828 to 851 and 892 to 906 HAND-DUPLICATES the engine's per-source logic for
the income breakdown, and it has drifted from the engine five times on one branch. Your rule flows
through BOTH paths. Verify the breakdown agrees with the tax computation for Massachusetts and say how
you verified it. Task 3 did this with a mutation it then reverted, which is the standard to match.

## 6. Standing constraints established by earlier tasks

- **ABSOLUTE PATHS and `git -C` only.** The controller's own shell silently reset to a different
  worktree on a different branch twice in this session.
- **VERIFY BEFORE YOU COMPLY.** Ten times in this program a subagent has caught an error in the brief
  it was handed, including several of the controller's, and two of those would have put false
  statements into fixtures. Everything above is evidence, not fact.
- Baseline to beat: **1,924 Swift Testing in 297 suites + 509 XCTest.**
