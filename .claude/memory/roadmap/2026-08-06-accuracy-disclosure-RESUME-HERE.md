# RESUME HERE: Per-state accuracy disclosure, Tasks 1 to 4 done

**Branch `feature/state-accuracy-disclosure`, cut from `feature/state-tax-phase5b` @ `587b5c4`.
NOT pushed, NOT merged.** Suite green: 2,048 Swift Testing in 306 suites + 509 XCTest, 0 failures.

**This file exists because the SDD ledger at `.superpowers/sdd/progress.md` is GITIGNORED.** That
ledger is far richer; read it if the worktree still exists.

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

## AWAITING JOHN
**13 sentences, PROPOSED**: AZ 2, DC 2, KS 1, MA 1, MO 2, NC 1, NM 1, NY 1, UT 2. Eleven say
"overstated", two "understated" (both Missouri). Grouped by state in `.superpowers/sdd/task-4-report.md`
section 1.

## Remaining
Tasks 5 to 8: the factual half generated from config; the page and its empty state; three entry points
that each resolve a DIFFERENT state; and two behaviour gates.

## THE THINGS A FRESH SESSION MUST NOT LOSE
1. **An empty `knownLimitations` NEVER renders as a clean bill of health.** Exact wording, specified
   by John: "No known limitations are currently recorded for this state and tax year." IOWA AND
   INDIANA SHIP EMPTY LISTS, so this is load-bearing INSIDE the covered set, not only for the 36
   states outside it.
2. **Gate 3 tests EFFECTIVE BEHAVIOUR, not a config echo.** If the page claims a per-spouse
   exclusion, the ENGINE must actually double it. A config echo would pass while the engine was wrong,
   which the predecessor branch shipped several times.
3. **`taxYear` 0 and empty `lastVerified` are what the 36 uncovered states carry.** Task 3 added the
   optional accessor `statedTaxYear` and deliberately chose NO fallback string, because that copy is
   John's. Task 6 must not invent one.
4. **Each entry point resolves a different state.** State Comparison uses the INSPECTED state, not the
   resident's. A comparison sheet for Oregon must never show California's disclosure.
5. **Layer B**: `disclosureOnlyDivergentJurisdictions` exists so populating `verification` does not
   force a state onto `phase5CorrectedJurisdictions`, which would permanently excuse the
   byte-identity check. Any newly populated state must join it.
6. Tasks 3 and 4 were verified mechanically by the controller but never independently reviewed.
   **Review them before merge.**
