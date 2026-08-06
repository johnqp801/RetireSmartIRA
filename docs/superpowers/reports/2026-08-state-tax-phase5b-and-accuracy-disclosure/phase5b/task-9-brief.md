# Task 9: Vermont and DC together

Task 9 has no heading of its own in `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md`:
it is one paragraph under the shared heading "Tasks 3 to 9". The paragraph, the nine-step shared
procedure and the Global Constraints are verbatim below, then a CONTROLLER ADDENDUM.

---

## The task itself, verbatim from the plan

**Task 9: Vermont and DC together.** These two were UNSATISFIABLE before Task 1 and they share the
reason. Vermont needs `uniformedServices` to separate the uncapped military exclusion from the $10,000
CSRS one; DC needs the survivor flag. Doing them together makes it obvious whether Task 1's extension
actually solved the problem it was built for. **If either is still unsatisfiable after the extension,
that is the single most important finding of this phase** and must be reported as such rather than
worked around.

From the plan's Scope table:

| Jurisdiction | Defects | Rule, to be verified against its fixture rather than trusted here |
|---|---|---|
| **VT** | 6 | $10,000 military and CSRS exclusion, AGI-limited, PLUS an uncapped military exclusion under 2025 Act 71 |
| **DC** | 3 | $3,000 at 62 or over, DC or federal government pensions only, survivor benefits treated separately |

**Note:** Phase 4 established that DC's "$3,000 at 62 or over" provision EXPIRED for tax years after
2014. DC-5's `source` says so and confirms the app already agrees by granting nothing. Only the survivor
exclusion under D.C. Code 47-1803.02(a)(2)(N)(ii) remains live. Read DC-5 before trusting the table row.

---

## The shared procedure, verbatim from the plan

- [ ] **Step 1: The golden fixture is the specification.** Do not research the law again. **One
      exception:** if the fixture does not carry enough detail to write the rule, say so and go to the
      primary source it cites. Report that you did.
- [ ] **Step 2: Read `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NY.json`** for the
      shipped shape of `perSourceExemptions`.
- [ ] **Step 3: Write the rule, and write it to FAIL for the right cases.** For each rule ask: what
      would this wrongly match? If the fixture set has no case that would catch that, ADD one.
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
- **RUN THE SUITE IN THE FOREGROUND WITH `timeout: 600000`.**
- **Never edit by chained `cd`.** Absolute paths and `git -C`.

---

# CONTROLLER ADDENDUM

## 1. DC NEEDS PRODUCTION SWIFT BUILT FIRST. Task 1 recorded the exact chain and deliberately left it.

Task 1 added `var isSurvivorBenefit: Bool?` to `RetirementPlanClassification` and NOTHING ELSE.
Task 2 added the field to the test fixture type `ClassifiedPensionSource` and set it on DC's five
survivor rows. **Everything between those two ends is still missing**, and Task 1's ledger names it:

- a field on `IncomeSource` and on `IRAAccount`
- `matchIsSurvivorBenefit` on `PerSourceExemptionRule`
- a parameter on `matches()`
- a pass-through in `DataManager.matchedPerSourceRule`
- a bridge in `GoldenScenarioSingleYearTests.singleYearStateTax`

I verified before writing this: only `RetirementPlanClassification.swift` mentions `isSurvivorBenefit`
in production. **This is the largest production change in the phase and Task 1's standard applies:
provably inert until a config opts in.** Prove that the way Task 1 did, by showing the full suite
unmoved before any config names the new field, with New York as the canary.

**Watch the decode trap.** Task 1's Critical finding was that `let isSurvivorBenefit: Bool? = nil`
compiled, warned, and then SILENTLY DECODED JSON SETTING IT TRUE AS NIL. When you add the field to
`IncomeSource` and `IRAAccount`, prove by execution that a round trip preserves it, and check the
`PersistenceManager.loadAll` fallback behaviour that Phase 3b's decode-trap lesson covers.

## 2. DC's fixture already contains its own guards. Do not weaken them.

- **DC-1** is a survivor at age 55, flagged `isSurvivorBenefit: true`, expected FULLY TAXABLE because it
  fails the age-62 gate, and it carries NO `knownDefect`. **It is the age-gate guard.** A rule that
  forgets the gate turns DC-1 to $0.00 against its pinned $1,924.00 and fails. Task 2 flagged DC-1
  deliberately for exactly this reason and a reviewer endorsed it.
- **DC-5** is an OWN federal civil service pension at 65, NOT flagged, expected FULLY TAXABLE, no
  `knownDefect`. **It is the survivor guard.** A rule that ignores the flag turns DC-5 to $0.00 and
  fails.
- DC has NO `otherStateOrLocal` row, so it has no out-of-state guard. Task 2's reviewer flagged that and
  said Task 9 Step 3 owes DC a Maryland-pension negative case. **That is your Step 3 obligation.**

## 3. VERMONT MAY NOT BE EXPRESSIBLE, and here is the concrete shape. Triage BEFORE writing.

Vermont needs TWO different exclusions:
- CSRS: **capped at $10,000**, AGI phase-out $55,000 to $65,000 single, $70,000 to $80,000 MFJ
- Military under Act 71: **UNCAPPED**, AGI phase-out $125,000 to $175,000, all filing statuses

Three facts I verified in the code before writing this, each of which you should confirm rather than
trust:

1. **A CAPPED PER-SOURCE TREATMENT IS BANNED PHASE-WIDE.** `PerSourceExemptionRule.treatment` is
   evaluated INSIDE the per-row loop (`TaxCalculationEngine.swift:619-627`,
   `DataManager.swift:891-899`), so `.partial` caps PER ROW. Design doc 3.4a calls this the phase's
   single largest correctness risk and this codebase HAS SHIPPED that bug once, in New York's $20,000
   exclusion. Task 6 added a sweep asserting no shipped rule carries a capped treatment.
2. **An AGI phase-out mechanism EXISTS**, `StateAGIPhaseout`, and Arizona's precedent is to route a cap
   through the POOLED `pensionExemption`, which the phase-out then reduces.
3. **BUT per-source exclusions are ADDED ON TOP of the phased-out pool, not phased out themselves.**
   See `DataManager.swift:1065`: `pensionExemptAmt = perSourceExcludedPension + (agiPhaseout?.reduced(...))`.

So the pooled mechanism can carry ONE capped, AGI-phased exclusion. Vermont has TWO, with different
caps AND different phase-out bands. **Work out early whether both can be expressed, and if not, which
one can and what happens to the other.**

**VT-2 and VT-6 are the phase-out guards.** VT-2 pins the CSRS band's magnitude at AGI $60,000 ($5,000
of the $10,000 cap retained) and VT-6 pins Act 71's band at AGI $150,000 ($75,000 of an uncapped
exclusion retained). A per-source `full` rule on `uniformedServices` would make VT-5 green and VT-6
WRONG, because per-source exclusions are not phased out. **If you find yourself about to ship a rule
that makes VT-5 green, check VT-6 before you believe it.**

## 4. This program's established answers when something is not expressible

Use one of them rather than forcing a rule. **What is NOT legitimate is widening a rule until the
numbers match.**

- **Hawaii and North Carolina shipped NO rule**, kept their `knownDefect` blocks, and recorded why.
  Both were upheld by review.
- **Arizona corrected three cases and left AZ-4 PINNED** because the model could not express
  per-taxpayer attribution. Partial correction is legitimate.
- **Massachusetts SHIPPED with a disclosed gap**, but only because its fixes rested on quoted,
  affirmative statute while its gap rested on an inference.

**Mark each of your claims as quoted authority or as inference.** That distinction carried all four
earlier decisions and a reviewer will apply it to yours.

**Hawaii's method is the standard:** it did not argue the tempting rule was wrong, it temporarily
shipped it, measured that every case went green while the rule was demonstrably wrong, and reverted.
Measure rather than reason wherever you can.

## 5. If you ship a rule for either jurisdiction

- **You owe that jurisdiction a disclosure sentence.** `rulesAndDisclosuresStayInLockstep` is
  bidirectional: a rule without a sentence fails the suite and so does a sentence without a rule. The
  copy is user-facing and John approves it: draft two or three options per jurisdiction, recommend one,
  ship your recommendation, flag prominently as PROPOSED.
- **Check the DataManager mirror** at roughly `DataManager.swift:828-851` and `892-906`. It
  hand-duplicates the engine's per-source logic and has drifted five times on this branch. Your survivor
  pass-through lands in exactly that mirror, so this is higher risk than usual. Task 3 used a mutation
  it then reverted; match that standard.
- **Check picker reachability.** A rule no real user can select is a green suite and an undelivered fix.
  **The survivor flag has NO picker affordance at all today.** If DC's rule needs one, say so: Task 3
  established the precedent that adding it is in scope when the alternative is an unreachable rule.

## 6. A REACHABLE DIVERGENCE FOUND IN TASK 7 that lands here too

`MilitaryRetirementExemption.swift` ships per-state military answers gated on
`source.type == .militaryRetirement`, NOT on `planSource == .uniformedServices`. The same military
pension can get two different answers depending on how it was entered. **Vermont exempts military pay
and VT-5 and VT-6 are military cases, so read Vermont's entry in that file before writing anything** and
say whether your rule agrees with it. Do not silently create a third answer.

## 7. What earlier tasks established

- `governmentUnspecified` means "a government employer whose jurisdiction was not established", NOT any
  eligibility fact.
- Kansas's rule deliberately does not match `unknown`. Task 6 found that precedent INVERTS for a DENIAL
  rule. Work out which kind yours is.
- A defect no golden case can pin goes in `GoldenScenarioDefectCatalogueTests.knownButUnpinned`, **with
  a test that fails if the entry is deleted.** Task 6 shipped one without the guard and was caught.
- **VERIFY BEFORE YOU COMPLY.** Fifteen times in this program a subagent has caught an error in the
  brief it was handed, including several of the controller's, and two would have put false statements
  into fixtures. Everything above is evidence, not fact.
