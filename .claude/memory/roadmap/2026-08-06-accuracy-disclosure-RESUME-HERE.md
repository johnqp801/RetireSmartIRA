# RESUME HERE: Per-state accuracy disclosure, all eight tasks done. Nothing awaits John.

**Branch `feature/state-accuracy-disclosure`, cut from `feature/state-tax-phase5b` @ `587b5c4`.
NOT pushed, NOT merged.** Suite green: 2,076 Swift Testing in 306 suites + 509 XCTest, 0 failures.

**This file exists because the SDD ledger at `.superpowers/sdd/progress.md` is GITIGNORED.** That
ledger is far richer; read it if the worktree still exists. So are the per-task reports it points at,
which hold the rejected copy alternatives.

Spec: `docs/superpowers/specs/2026-08-05-per-state-accuracy-disclosure-design.md`
Plan: `docs/superpowers/plans/2026-08-05-per-state-accuracy-disclosure.md`

## Why this exists
Commitment item 3 of six promised in writing to Steve Nicolai and Alan Levy. Steve asked to
"communicate how accurate the state modeling is; per-state, per-income-type treatment text", then
found a second state bug the next day. **Zero of the six commitments have shipped.** Released version
is 2.3.0 build 63; everything since is on `main` unreleased.

## Done
- **Task 1** (`8a67c35`, reviewed clean): hoisted three inline captions to statics so they could be
  asserted at all.
- **Task 2** (`7c72664`, reviewed clean): `StateVerification.taxYear` plus the completeness gate.
- **Task 3** (`987f653`, mechanically verified, FULL REVIEW NOT RUN): six captions moved into
  `verification.knownLimitations`; Hawaii uses a `{scope}` token so one stored sentence renders both
  approved wordings byte-identically.
- **Task 4** (`2d863ee`, mechanically verified, FULL REVIEW NOT RUN): 13 new limitation sentences,
  verification metadata for 14 jurisdictions, and a `topic` per limitation.
- **Task 5** (`3074127`): the factual half, generated from live config.
- **Task 6** (`870324c`): `StateAccuracyView`, and an empty state that claims nothing.
- **Task 7** (`d107b0d`): three entry points, each resolving its own state.
- **Task 8** (`fee5c8f`): behaviour-backed fidelity and bidirectional completeness gates.
- **Roth conversion statement** (`d3a7d9e`): the four configs rendered as three shapes.

## AWAITING JOHN
**ZERO ITEMS.** On 2026-08-06 John approved, as written, every outstanding user-facing string on this
branch. A reader arriving here does not have to work out which batch is still open, because none is:

- Task 4's **13 limitation sentences**: AZ 2, DC 2, KS 1, MA 1, MO 2, NC 1, NM 1, NY 1, UT 2.
- Task 6's **fallback strings**: the "tax year not recorded" page title, "No verification date
  recorded.", "No primary sources recorded.", and the "State tax accuracy" navigation title.
- Task 7's **three accessibility labels**, "State tax accuracy for <State>".
- The **Roth conversion statement**, label "Roth conversions": IL and MS "Not taxed by this state.";
  PA "Not taxed by this state. Any part of the conversion withheld for federal tax does not reach the
  Roth account, so that part stays taxable."; IA "Not taxed by this state from age 55."
- The **multi-year delta tag**, `State` to `State (KS)`.

The rejected alternatives for each are kept in the per-task reports under `.superpowers/sdd/`,
retitled so they read as a decision already made rather than as options still open.

## Remaining before merge
1. **An independent review of Tasks 3 through 8.** The controller verified all six MECHANICALLY, by
   grep and by suite, and never ran a reviewer over them. Tasks 1 and 2 are the only reviewed ones on
   this branch. This is the largest open risk, and it is a process gap, not a known defect.
2. **The multi-year entry point has no always-on-screen home.** The plan assumed a "Multi-year plan
   state tax row" that does not exist: the Multi-Year tab's table has no state column. The affordance
   went on the only state tax figure the tab prints, the `State (KS)` delta tag in
   `ApproachComparisonView`, which appears only once an approach comparison exists. So a multi-year
   user may never see the entry point. Detail in `.superpowers/sdd/task-7-8-report.md` section 2.
3. **The Iowa `effectiveAge` candidate limitation sentence, not authored.** The engine gates Iowa's
   Roth conversion age on `effectiveAge`, the HOUSEHOLD MAXIMUM, not on the converting owner's age
   (`TaxCalculationEngine.swift:862` and its comment, which flags the question as undecided pending
   Iowa's Phase 5a golden scenario). The approved copy says "from age 55" and is silent about whose
   age, which is true for a single filer and for a couple where the older spouse converts, and
   arguably wrong where a 50 year old converts and a 60 year old spouse pulls the household maximum
   over the gate. That is an engine question first and a limitation sentence second; neither exists
   yet.

## THE THINGS A FRESH SESSION MUST NOT LOSE
1. **An empty `knownLimitations` NEVER renders as a clean bill of health.** Exact wording, specified
   by John: "No known limitations are currently recorded for this state and tax year." IOWA AND
   INDIANA SHIP EMPTY LISTS, so this is load-bearing INSIDE the covered set, not only for the 36
   states outside it.
2. **Gate 3 tests EFFECTIVE BEHAVIOUR, not a config echo.** If the page claims a per-spouse
   exclusion, the ENGINE must actually double it. A config echo would pass while the engine was wrong,
   which the predecessor branch shipped several times.
3. **`taxYear` 0 and empty `lastVerified` are what the 36 uncovered states carry.** Task 3 added the
   optional accessor `statedTaxYear` and deliberately chose NO fallback string, because that copy was
   John's. Task 6's fallbacks are now approved; the rule that no year is ever INVENTED still stands.
4. **Each entry point resolves a different state.** State Comparison uses the INSPECTED state, not the
   resident's. A comparison sheet for Oregon must never show California's disclosure.
5. **Layer B**: `disclosureOnlyDivergentJurisdictions` exists so populating `verification` does not
   force a state onto `phase5CorrectedJurisdictions`, which would permanently excuse the
   byte-identity check. Any newly populated state must join it.
6. **The optional second sentence on the empty-limitations string is still UNAPPROVED and still does
   not ship.** "State tax rules are complex, and this does not mean every unusual situation is
   represented" was never put to John and was not part of the 2026-08-06 approval. The gate on
   `noRecordedLimitationsSentence` is exact equality, so appending it is a copy change, not a tidy-up.
   See `StateAccuracyContent.swift` above `noRecordedLimitationsSentence`.
