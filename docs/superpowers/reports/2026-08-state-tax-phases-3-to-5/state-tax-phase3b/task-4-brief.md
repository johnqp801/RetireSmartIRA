### Task 4: New York, the only jurisdiction whose numbers move

**Files:** modify `StateTaxData.swift`, `StateTaxCodable.swift`, `TaxCalculationEngine.swift`, `DataManager.swift`; regenerate the 51 JSON files; create `GoldenScenarios/statetax-2026-NY.golden.json`.

- [ ] **Step 1: Write New York's golden scenarios first**, from IT-201 with line numbers cited per the citation discipline in the parent spec §3.4. Four cases, and the fourth is the regression test for the defect this design was revised to remove:
  1. NYC employee pension alone: fully excluded, Line 26.
  2. NYC pension plus a private pension: government portion uncapped, private portion against the shared $20,000, Line 29.
  3. A government employee's 403(b): capped, because Line 26 excludes salary-reduction plans.
  4. **An out-of-state public pension: capped.** A single `.governmentPension` case would have given this the uncapped exclusion.

You must open every `sourceURL` and check every clause of `source` against it, and say in your report that you did. Phase 2 of this program shipped three confidently wrong citations whose expected values were right, so every test passed.

- [ ] **Step 2: Run them and watch cases 1 and 2 fail.** Cases 3 and 4 should already pass, since today's behavior caps everything. Paste the transcript; it is the empirical statement of Alan's bug.

- [ ] **Step 3: Add `perSourceExemptions` to `RetirementIncomeExemptions`**, defaulting to `[]`, with Codable and the fixture extension required by Global Constraints.

- [ ] **Step 4: Apply the rules as a PARTITION, not as a per-component cap evaluation.** This is the single largest correctness risk in the phase, and this codebase has already shipped the bug it guards against: New York's shared pension-and-IRA cap exists because an earlier version granted $20,000 to pension and another $20,000 to IRA.

Per spec §3.4a, the order is:

1. Test each component and each `IncomeSource` row against `perSourceExemptions`. First match wins.
2. Amounts matching a `.full` rule are subtracted outright and **contribute nothing to any shared cap**.
3. Pool everything unmatched and hand it to the EXISTING `pensionExemption` / `iraWithdrawalExemption` logic untouched, including `pensionAndIRAShareSingleCap` and `exemptionAppliesPerIndividual`.

The cap is therefore still applied once, to a pooled figure, per eligible taxpayer. Do not evaluate a cap inside a per-component loop. Sync the mirror in this commit.

- [ ] **Step 4a: Write these five cap tests before Step 5.** Each must be derived from the statute, not from observed output:
  1. Two private pensions owned by the primary: ONE $20,000 cap between them, not two.
  2. One IRA distribution plus one private pension, same taxpayer: one shared cap, which is what `pensionAndIRAShareSingleCap` already enforces.
  3. Primary and spouse each with qualifying income: the cap doubles once, via the existing `exemptionAppliesPerIndividual`, and not per component.
  4. An uncapped New York government pension **plus** capped private retirement income: the government pension is excluded independently and consumes none of the $20,000.
  5. Several capped sources summing to more than $20,000: the excess is taxed.

Prove case 1 discriminates by making the rule loop apply the cap per component and confirming it fails; that is the exact defect these tests exist to prevent.

- [ ] **Step 5: Give New York its rule** (spec §3.3) and **regenerate the 51 files**. Expected diff: `perSourceExemptions` appears in New York's file only. Run the deletion check and confirm no output:
```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b && git diff --numstat RetireSmartIRA/Resources/StateTaxData/2026/ | awk '$2 != 0 {print "DELETION in " $3}'
```

- [ ] **Step 5a: Re-point the migration gate so it becomes load-bearing.** Task 2's `computedStateTaxUnchangedByMigration` currently proves only that decode did not corrupt OTHER fields: its reviewer mutated every decoded classification to a wrong value and the test still PASSED, because nothing consumed the fields yet. After this task New York's rule consumes them, so re-point that test at a New York pension scenario and confirm by mutation that a wrong classification now fails it. Until you do, the test's name overclaims what it guards.

- [ ] **Step 6: The baseline WILL move, and only for New York.** Inspect every changed entry, confirm each is a New York row whose movement the golden scenarios explain, then regenerate the fixture in this commit with the diff pasted in your report. **This is the only task in the phase permitted to regenerate that fixture.** If any non-New-York entry moves, stop and report; that is a defect, not a correction.

- [ ] **Step 7: Full suite once, then commit.**

---

