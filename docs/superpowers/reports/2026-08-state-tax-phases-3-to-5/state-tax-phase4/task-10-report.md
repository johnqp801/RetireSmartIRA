# Task 10 report: close the phase

Commit: `1303e9f` on `feature/state-tax-phase4`.

## Summary

Flipped `GoldenScenarioCoverageTests.covered` from a hand-grown 50-entry literal to a derived
`USState.allCases` sweep minus a documented, tested `cannotVerify` exclusion (Montana only,
mechanism confirmed, TY2026 indexed figure unpublished, reviewer-approved). Added two new
completeness tests (`everyJurisdictionHasAFixture`, sweeping all 51; `cannotVerifyListIsExactlyWhatPhase4Shipped`,
pinning the exclusion list's membership so it cannot be silently grown). Created
`GoldenScenarioDefectCatalogueTests.swift` per the brief, plus a `knownButUnpinned` data
structure (not in the brief) carrying Missouri's public-pension-cap defect, which is real,
confirmed, and has no golden case because the 2026 SSA maximum-benefit figure is unreachable
from every official source tried. Wrote the full comparison ledger against the 2026-08-02 audit.

## Catalogue headline counts

- 50 fixture files, 207 total scenarios, all from the shipped JSON (not batch-report prose,
  which in at least one case does not reconcile with its own per-state counts).
- **118 scenarios carry a `knownDefect` across 35 jurisdictions.**
- 89 scenarios pass clean; 15 jurisdictions are entirely clean (AK CA FL IL MS ND NH NJ NV NY
  PA SD TN TX WY).
- Tiers: tier1 34/11, tier2 32/8, tier3 17/8, tier4 18/4, unclassified 17/4.
- CANNOT_VERIFY: 2 (Montana -- unresolved law, external blocker; NC's Bailey mixed-vesting
  sub-case -- unresolved model, internal/schema blocker; kept explicitly distinct).
- Known-but-unpinned: Missouri's public-pension cap (flagship, no fixture at all) plus a
  smaller category of disclosed-but-not-pinned base-computation staleness in OK/AR/SC/WV.

## Comparison against the audit (~29 predicted)

- **Predicted and confirmed: 22 states** (plus NY, predicted-and-already-remediated by Phase
  3b before this phase began).
- **Predicted and NOT reproduced (audit was wrong): 3 states.** DC (described expired,
  sunset-2015 law as current), Vermont (collapsed two independent exclusions into one, wrong
  cap/threshold for the military half), Utah (conflated the Retirement Credit's gate/phaseout
  with a different credit's thresholds). Arizona was deliberately NOT placed here despite one
  batch's own "falsified" framing: its core predicted claim reproduces exactly; the extra gaps
  found are additive, not contradictory.
- **NOT predicted but found: large bucket**, headlined by Georgia's stale rate (5.39% vs
  enacted 4.99%) and standard deduction, Utah's unmodeled Taxpayer Tax Credit plus a stale
  rate, and New Mexico's entire bracket schedule being pre-HB252 -- none of these three are
  retirement-exclusion defects, and all three hit every filer in the state. Also: CO/KY MFJ
  per-individual attribution, Missouri's private-pension cap, Minnesota (never audited, mostly
  correct, three real gaps found), and NE/IN/OR's non-retirement defects.
- **CANNOT_VERIFY: Montana, NC Bailey sub-case**, kept distinct per the brief's instruction.

## Verification

Full suite: `Test run with 1856 tests in 292 suites passed after 319.392 seconds`, `** TEST
SUCCEEDED **`. `xcresulttool`: `failedTests: 0`, `skippedTests: 6`. 1,856 = the 1,851/291
post-merge baseline plus 5 new Task 10 tests; 292 suites = 291 plus the one new catalogue
suite. No `MultiYearPerfTests` flake occurred in this run.

`git -C .../state-tax-phase4 diff --stat main -- RetireSmartIRA/`: empty, both before and
after the commit. Phase 4 corrected no tax value across all ten tasks.

Em dash check: Python codepoint scan for U+2014 across both Swift files and the ledger:
clean.

## Concerns for the next reader

- The ledger names several open items Phase 5 should sequence carefully: Georgia/Utah/New
  Mexico's non-retirement, every-filer defects; Missouri's unpinned cap; OK/AR/SC's
  disclosed-but-unpinned base-rate staleness (fixing their pinned attribution defect alone
  will go green while those states remain substantially wrong); NC's Bailey expressibility gap
  needing a schema decision, not a source.
- I initially wrote the ledger to the MAIN REPO's `.claude/memory/roadmap/` instead of the
  worktree's, the exact class of mistake a predecessor task's ledger warned about. Caught it
  before committing (it was untracked on the main repo's own current branch, no damage), moved
  it into the worktree, and it is now committed at the correct path and up to date with the
  worktree's other Phase 4 ledgers.
