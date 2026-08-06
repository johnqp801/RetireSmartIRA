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

