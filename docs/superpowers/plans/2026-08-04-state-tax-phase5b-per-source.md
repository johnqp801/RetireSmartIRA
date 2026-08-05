# State Tax Phase 5b: The Per-Source Track: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the model the three things it cannot currently say, then correct all eight jurisdictions whose rules key on WHICH PLAN the money came from, including the second half of the Kansas promise.

**Architecture:** Extend `PlanSource` and `ClassifiedPensionSource` so a rule can distinguish the taxpayer's OWN state system from another state's, uniformed services from civilian federal, and a survivor benefit from the holder's own pension. Every extension defaults to reproducing today's behaviour exactly. Only then correct the eight configs, each against golden cases that already exist plus the negative cases this plan adds.

**Tech Stack:** Swift Testing, `PerSourceExemptionRule` from Phase 3b, bundled JSON under `RetireSmartIRA/Resources/StateTaxData/2026/`, `xcodebuild test` on macOS.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md`, plus four recorded amendments in `.claude/memory/decisions/log.md` dated 2026-08-04: base values first; golden scenarios stand in for the two-model protocol; the legacy Swift table is frozen at pre-correction law with the equivalence gate scoped; Iowa pulled forward.
- **UNLIKE PHASE 5a, THIS PHASE CHANGES SWIFT.** 5a was config-only and its confinement rule was "nothing but JSON." That rule does not apply here. What replaces it: every Swift change must be an ADDITIVE model extension that is provably inert until a config opts into it, and Task 1's gate is what proves that.
- **The frozen 1,020-value baseline stays frozen.** Every deliberate movement gets an entry in `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` naming the golden case that authorises it. That `goldenCase` is MACHINE-CHECKED against real fixture scenario names, so a typo or an invented name fails the suite. `after` values are MEASURED from failure messages, never predicted.
- **Two equivalence lists, and they mean different things.** `phase5CorrectedJurisdictions` asserts a state DIVERGES from the frozen legacy Swift table. `layerAProvenDivergentJurisdictions` asserts at least one scenario in a fixed 10-scenario grid diverges. Kansas and Indiana are deliberately in the first and not the second, because that grid never exercises a personal exemption. Place each new state on the same reasoning and say why in the report.
- **A golden case going green is the deliverable.** Deleting a `knownDefect` block is how a correction is declared complete, and the block's own second assertion forces it: once the engine matches the form, the test fails saying "delete the knownDefect block."
- **NO EM DASH CHARACTERS** anywhere, including JSON strings, code comments and reports.
- **Tests are the source of truth.** Baseline at branch point: 1,857 Swift Testing in 293 suites + 509 XCTest, 0 failures, 6 pre-existing env-gated skips. `MultiYearPerfTests` has a known pre-existing wall-clock flake; re-run in isolation rather than calling it a regression.
- **RUN XCODEBUILD IN THE FOREGROUND WITH `timeout: 600000`.** Five agents on this project have stalled by backgrounding a build. The 120 second default is not the ceiling. Do not use `run_in_background` or Monitor.
- **Never edit by chained `cd`.** Use absolute paths and `git -C`.

**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`, branch `feature/state-tax-phase5b`, off `main` @ `c5a7bce`.

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

---

## THE FINDING THIS PHASE IS BUILT AROUND

Phase 3b built `PerSourceExemptionRule` with two deliberately separate axes, `PlanSource` and `PlanStructure`, specifically so that a plain "government pension" label could not hand New York's uncapped exclusion to a California public pension. New York's fixture carries a permanent regression case proving exactly that.

**Kansas uses the same enum case BACKWARDS, and nothing catches it.**

`PlanSource.otherStateOrLocal` documents itself at `RetireSmartIRA/RetirementPlanClassification.swift:40-43` as "A DIFFERENT state or its localities. NOT Line 26 eligible. This case exists specifically to stop an out-of-state public pension from selecting New York's exclusion."

Kansas's three remaining fixtures label **KPERS**, the Kansas Public Employees Retirement System, as `otherStateOrLocal`. It is not a different state's system; it is Kansas's own, held by a Kansas resident. The label was forced because **the model has no way to say "this state's own system."**

So the obvious Kansas rule, `matchSources: ["otherStateOrLocal", "federalCivilian"]`, would:
1. Make all three Kansas fixtures pass, and
2. Exempt a **California** public pension for a Kansas resident, which Kansas law does not do, and
3. Be caught by nothing, because Kansas has no out-of-state negative case the way New York does.

That is the Phase 3b defect class reappearing in a different state. **The model extension in Task 1 exists to prevent it, and Task 2 adds the missing negative cases that would have caught it.**

The same gap blocks two more jurisdictions, which Phase 4 recorded as UNSATISFIABLE by any configuration:
- **Vermont** needs to distinguish a military pension from a CSRS one. Both are `federalCivilian` in its fixtures, so one rule cannot give them different treatments. Vermont's uncapped military exclusion and its $10,000 CSRS exclusion are indistinguishable.
- **DC** needs to distinguish a survivor benefit from the holder's own pension. Both are `federalCivilian`, and DC exempts the survivor benefit while taxing the own pension.

---

## Scope

**IN: the eight per-source jurisdictions**, 29 defect cases.

| Jurisdiction | Defects | Rule, to be verified against its fixture rather than trusted here |
|---|---|---|
| **KS** | 3 | KPERS, federal, military and Railroad Retirement exempt; private taxable. **Completes the second half of a written promise.** |
| **MA** | 3 | Contributory MA state and local exempt; noncontributory municipal taxable; US uniformed services exempt |
| **HI** | 3 | Employer-funded portion exempt, no cap and no age; employee contributions, 401(k) deferrals and IRAs taxed |
| **AZ** | 4 | The $2,500 exclusion covers GOVERNMENT pensions only, plus a separate uncapped military exclusion |
| **NC** | 3 | Bailey settlement class, vested before 1989-08-12, fully exempt |
| **ID** | 4 | CSRS, Idaho police and fire, and military, at 65 or over (62 if disabled), income-limited |
| **VT** | 6 | $10,000 military and CSRS exclusion, AGI-limited, PLUS an uncapped military exclusion under 2025 Act 71 |
| **DC** | 3 | $3,000 at 62 or over, DC or federal government pensions only, survivor benefits treated separately |

**OUT, and each for a reason established by reading the model:**
- **Credits** (NE, OR, UT, OH). There is no credit representation in `StateTaxConfig` at all. That is its own phase.
- **A bracket base amount** (OH's "$332 plus 2.75%"). `TaxBracket` is threshold plus rate only.
- **South Carolina's separate $15,000 age-65 deduction** against any income.
- **Attribution and age gates** (OK, DE, LA, AR, SC, WV). Those fields largely exist; that is a config-shaped phase like 5a and should be one.
- **The OK, AR and SC base values**, which must be corrected TOGETHER with a re-derivation of their golden expectations or their pins become meaningless.
- **Cross-path work** (I2, E8).

**North Carolina may end this phase still unsatisfiable.** Its Bailey rule keys on a VESTING DATE, and the model has no vesting-date axis. Phase 4 recorded that as an expressibility gap rather than unresolved law. Task 7 decides whether to add the axis or record NC as remaining unsatisfiable; **do not force it.**

---

### Task 1: Extend the model, provably inert

**Files:**
- Modify: `RetireSmartIRA/RetirementPlanClassification.swift`
- Modify: `RetireSmartIRA/PerSourceExemptionRule.swift`
- Test: `RetireSmartIRATests/Phase5bModelExtensionTests.swift` (new)

**Interfaces:**
- Produces: three new `PlanSource` cases and one new optional property on the classified-source type. Tasks 3 through 9 author config against these names, so get them right here.

Add to `PlanSource`:
- **`ownStateOrLocal`**, meaning the taxpayer's OWN state or its localities. This is what KPERS is for a Kansas resident, what a Massachusetts contributory pension is for a Massachusetts resident, and so on. Its doc comment must contrast itself explicitly with `otherStateOrLocal`, whose comment already explains it exists to STOP an out-of-state pension selecting a state's exclusion. **These two cases are a matched pair and each doc comment should name the other.**
- **`uniformedServices`**, meaning military retired pay. Distinct from `federalCivilian`, which is CSRS and FERS. Vermont, Arizona, Idaho, Massachusetts and Kansas all treat these differently, and today they are indistinguishable.
- **`railroadRetirement`**, which Kansas exempts by name and which is neither a state nor an ordinary federal civilian pension.

Add to the classified-source type an optional survivor flag, defaulting to nil so every existing fixture and save decodes unchanged. DC exempts a survivor benefit while taxing the holder's own pension, and both are `federalCivilian` today.

**THE GATE FOR THIS TASK IS INERTNESS.** Adding enum cases must not move a single computed value. Specifically:
- The frozen 1,020-value baseline must not move. No new movement-ledger entries in this task.
- Every golden fixture must produce exactly what it produces today, including all 99 remaining pinned defects.
- New York's four fixtures must be byte-for-byte unaffected. New York is the only state shipping `perSourceExemptions` today, so it is the canary: if its numbers move, matching semantics changed rather than widened.

**Prove inertness by running the full suite before and after and showing no value moved.** Then prove the new cases are REACHABLE by a focused unit test that constructs a `PerSourceExemptionRule` matching each new case and asserts it matches what it should and, more importantly, does NOT match what it should not. `ownStateOrLocal` must not satisfy a rule naming `otherStateOrLocal`, and vice versa; that is the whole point.

**Watch for the decode trap Phase 3b already hit once.** Its ledger records that a single unrecognised classification string in one saved income row would have discarded EVERY stored income source, because `PersistenceManager.loadAll` wraps its decode in `try?`. The resolution then was that shipped state JSON keeps a strict throw while USER SAVES fall back to `.unknown` with an observable diagnostic. Adding enum cases means a save written by a newer build cannot be read by an older one. Verify that fallback still holds for the new cases and say how you verified it.

---

### Task 2: Re-label the fixtures the old model forced into wrong cases, and add the missing negatives

**Files:**
- Modify: `RetireSmartIRATests/GoldenScenarios/statetax-2026-KS.golden.json`
- Modify: `RetireSmartIRATests/GoldenScenarios/statetax-2026-VT.golden.json`
- Modify: `RetireSmartIRATests/GoldenScenarios/statetax-2026-DC.golden.json`

**This task changes fixtures, which Phase 4 otherwise treats as frozen. That is deliberate and it needs justifying in the report.** These three fixtures were written against a model that could not express their rules. Phase 4 recorded Vermont and DC as UNSATISFIABLE for exactly this reason and recorded Kansas's `otherStateOrLocal` usage as a disclosed stretch. Task 1 removed the limitation; this task makes the fixtures say what they always meant.

- **Kansas:** re-label KPERS from `otherStateOrLocal` to `ownStateOrLocal` in all three cases. **Then ADD the negative regression case Kansas lacks**, mirroring New York's: a Kansas resident holding a CALIFORNIA public pension (`otherStateOrLocal`), which Kansas does NOT exempt. Derive its expected value from the Kansas form the existing fixtures already cite. Name it so a later reader knows it is the out-of-state guard and must not be simplified away. **Without this case, a wrong Kansas rule passes.**
- **Vermont:** re-label its military cases from `federalCivilian` to `uniformedServices`, leaving genuine CSRS cases alone. Read each case's `source` string to decide which is which; do not guess from the amounts.
- **DC:** set the survivor flag on the survivor-benefit cases, leaving own-pension cases alone.

**Expected outcome: no tax value moves in this task either.** Re-labelling changes what a FUTURE rule can match; it does not change today's computation, because no state yet has a rule naming the new cases. The `observedToday` pins should hold. If any moves, that is a finding: it means something matched on the old label that should not have.

The new Kansas negative case is the exception. It is new, so it needs its own `expectedStateTax` derived from the form, and it will need a `knownDefect` block if today's engine gets it wrong.

---

### Tasks 3 to 9: correct the eight jurisdictions

**Shared procedure**, written once:

- [ ] **Step 1: The golden fixture is the specification.** Phase 4 derived every expected value from that jurisdiction's own published authority and a reviewer independently opened the documents. Do not research the law again. **One exception:** if the fixture does not carry enough detail to write the rule, say so and go to the primary source it cites, exactly as the New Mexico task had to when only the first married bracket was quoted. Report that you did.
- [ ] **Step 2: Read `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NY.json`** for the shipped shape of `perSourceExemptions`. It is the only working example.
- [ ] **Step 3: Write the rule, and write it to FAIL for the right cases.** A rule that makes your fixtures pass while also matching something it should not is the defect this phase exists to prevent. For each rule ask: what would this wrongly match? If the fixture set has no case that would catch that, ADD one.
- [ ] **Step 4: Run the golden suite.** Cases you fixed now fail saying "delete the knownDefect block." That failure is success.
- [ ] **Step 5: Delete the resolved blocks.** Whole blocks, never edit `observedToday` to match. If a case you expected to resolve did not, diagnose and report rather than adjusting.
- [ ] **Step 6: Record baseline movements** with MEASURED `after` values and exact `goldenCase` names.
- [ ] **Step 7: Add the jurisdiction to the equivalence lists**, choosing between the two on the documented reasoning and explaining the choice.
- [ ] **Step 8: Run the FULL suite.** Other suites may legitimately move; diagnose each, name the test and the values, never silence.
- [ ] **Step 9: Report and commit** with explicit paths.

**Task 3: Kansas.** Completes the second half of a written promise to Steve Nicolai. The rule must exempt `ownStateOrLocal`, `federalCivilian`, `uniformedServices` and `railroadRetirement` while leaving `privateEmployer` taxable, and must NOT match `otherStateOrLocal`. Task 2's new negative case is what proves the last part.

**Task 4: Massachusetts.** Contributory state and local exempt, noncontributory municipal taxable, US uniformed services exempt. The contributory-versus-noncontributory distinction may need a judgement about whether it maps to an existing axis; if it does not, say so rather than forcing it.

**Task 5: Hawaii.** The employer-funded portion is exempt with no cap and no age, while employee contributions, 401(k) deferrals and IRAs are taxed. Phase 4 scoped Hawaii as "disclosed, not modelled." Decide whether the employer-funded split is expressible now; if not, this is a disclosure item for Phase 6 and the blocks stay.

**Task 6: Arizona.** The $2,500 exclusion covers GOVERNMENT pensions only, and the app applies it to all pensions, so it OVERSTATES. There is also a separate uncapped military exclusion. **Phase 4 flagged Arizona as passing on wrong law today**: every civilian amount in its fixtures is under the $2,500 cap, so an uncapped federal-civilian rule leaves cases green while being wrong above the cap. Read that warning in the fixture before writing the rule, and consider adding a case above the cap.

**Task 7: North Carolina.** Bailey keys on vesting before 1989-08-12 and the model has no vesting-date axis. **Decide: add the axis, or record NC as remaining unsatisfiable.** Do not force it. Whichever you choose, the report must say which and why, because Phase 4 deliberately kept "the law is clear but the model cannot express it" separate from "the law could not be established."

**Task 8: Idaho.** CSRS, Idaho police and fire, and military, at 65 or over (62 if disabled), income-limited. **Phase 4 flagged Idaho as passing on wrong law today**: its only sub-62 case is at age 60, so a single age-62 gate turns all five cases green while being wrong for civilian retirees whose real gate is 65. Read that warning first and consider adding a case that discriminates.

**Task 9: Vermont and DC together.** These two were UNSATISFIABLE before Task 1 and they share the reason. Vermont needs `uniformedServices` to separate the uncapped military exclusion from the $10,000 CSRS one; DC needs the survivor flag. Doing them together makes it obvious whether Task 1's extension actually solved the problem it was built for. **If either is still unsatisfiable after the extension, that is the single most important finding of this phase** and must be reported as such rather than worked around.

---

### Task 10: Close Phase 5b

- [ ] **Step 1: Count.** Phase 5a closed at 99 defect cases across 32 jurisdictions. Report the delta and the per-jurisdiction breakdown.
- [ ] **Step 2: Run the FULL suite,** foreground, `timeout: 600000`, 0 failures.
- [ ] **Step 3: Confirm what moved in production.** Unlike 5a, Swift changed here. Show that the Swift diff is confined to the model extension and that no engine logic changed beyond consuming new fields.
- [ ] **Step 4: State the Kansas promise plainly.** Kansas had two defects. 5a fixed one. If this phase fixed the other, Kansas is complete and Steve can be told so without qualification, which has not been true at any point in this program. If it did not, say exactly what remains.
- [ ] **Step 5: Write the ledger** at `.claude/memory/roadmap/2026-08-04-state-tax-phase5b-ledger.md`, following the Phase 5a ledger's shape, carrying what Phase 5c inherits organised by missing model field.
- [ ] **Step 6: Commit.**

---

## Self-review against the spec

**Spec 3.3c, per-source exemptions,** names nine jurisdictions keyed to which plan the money came from and calls it "the largest single engine change in the release." Tasks 1 through 9 are that change. New York was already done in Phase 3b, leaving the eight here.

**Spec 3.4's requirement that user-reported scenarios become permanent golden cases** is honoured: Kansas's fixtures carry Steve Nicolai's own figures, and Task 2 adds the out-of-state negative case that protects them from a wrong rule.

**The two-axis design decision from Phase 3b** is extended rather than abandoned. Task 1 adds cases to an existing axis; it does not collapse the axes or add a generic "government" case, which is the specific mistake that design revision prevented.

**DEFERRED and why:** credits, the bracket base amount, South Carolina's age-65 deduction, attribution and age gates, the OK/AR/SC base values with their required re-derivation, and cross-path work. Each is deferred because it needs a different model change or a different method, not because of preference.
