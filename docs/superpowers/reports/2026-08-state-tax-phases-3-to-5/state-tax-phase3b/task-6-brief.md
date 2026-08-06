### Task 6: The picker, and the disclosures

**Files:** modify `IncomeSourcesView.swift`, `AccountsView.swift`, `MultiYearCPABriefing.swift`, and `StateComparisonView.swift`.

No mechanical gate covers this task, which is why Task 7 requires in-app verification.

- [ ] **Step 1: The picker.** One flat list, exactly the rows and mappings in spec §3.2. It appears on `.pension` income rows and on traditional accounts. Roth and inherited accounts get none, since no audited rule turns on their plan kind.

- [ ] **Step 2: A classified 403(b) or 457 displays as itself** in the accounts list, the account detail view and the CPA briefing. The engine-level `AccountType` is unchanged; the visible plan type wins. Nothing continues to call it a Traditional 401(k) after the user has said it is not one.

- [ ] **Step 3: The unclassified New York prompt and limitation.** A `.pension` row with `source == .unknown` shows a prominent prompt worded as a question about the pension, not a subtle optional field.

- [ ] **Step 3a: The limitation must appear wherever New York tax is COMPUTED, not only where New York is the residence.** `StateComparisonView` computes other states' tax for a non-resident, and `MultiYearCPABriefing` renders figures a CPA will read. A user comparing their state against New York with an unclassified pension gets an incomplete New York number in both places, so both carry the limitation.

- [ ] **Step 4: Hawaii's contextual disclosure**, surfaced where a Hawaii user holding a pension will meet it, stating that the employer-funded versus employee-contributed split is not modelled and its tax may be overstated.

- [ ] **Step 5: View tests** for the picker's mappings, the 403(b) display, and the presence of the NY prompt and Hawaii note under the right conditions and their absence otherwise. Then full suite once, and commit.

---

