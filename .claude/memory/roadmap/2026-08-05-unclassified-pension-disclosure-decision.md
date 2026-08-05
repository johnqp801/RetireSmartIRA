# PENDING, apply to the repo once the Task 3 fix wave lands

John chose OPTION 2 on 2026-08-05 for the unclassified-pension disclosure gap.

## Decision

The two unclassified-pension disclosures stop gating on New York and start gating on whether the
resident's own config carries per-source rules at all. The SENTENCE each jurisdiction shows comes from
that jurisdiction's own config, so New York keeps its exact current wording and every jurisdiction
Phase 5b adds owes its own sentence.

Rejected: generic copy that names no state or dollar figure (option 1), on the grounds that a vague
warning does not tell a user what to do; and adding Kansas alone (option 3), which reopens the same gap
at MA, HI, AZ, ID, VT and DC.

## The two surfaces

- `RetireSmartIRA/StateComparisonView.swift:22`, `showsUnclassifiedNewYorkPensionLimitation`, gates on
  `viewedState == .newYork`.
- `RetireSmartIRA/MultiYearCPABriefing.swift:394`, `newYorkUnclassifiedPensionLimitation`, gated at
  `RetireSmartIRA/MultiYearPlanView.swift:371-377`, gates on `residesInNewYork`.

Both exist to warn a user that a per-source rule is going unused because their pension is unclassified.
Neither fires for Kansas today. Nothing tests either. The existing copy names New York's mechanics
("the standard $20,000 pension exclusion"), which is why it cannot simply be generalized.

`RetireSmartIRA/IncomeSourcesView.swift`'s `residenceHasPerSourceRules` is the existing precedent for
the data-driven gate: it reads the live config rather than hardcoding New York.

## Consequences to carry into the plan

Every remaining Phase 5b jurisdiction task (4 MA, 5 HI, 6 AZ, 7 NC, 8 ID, 9 VT and DC) now owes a
disclosure sentence in its config alongside its rule. Task 10 should verify none was skipped.

## Constraint

The copy is user-facing. John reviews the wording before it ships; do not let an implementer's own
phrasing land unreviewed. Draft it, show it, then commit it.

## Origin

Reviewer finding, Task 3 review, rated Important. Called the surface most likely to make "Kansas is
complete" untrue for a real user. The controller's Task 3 addendum missed it because it listed only
surfaces inside IncomeSourcesView.swift.
