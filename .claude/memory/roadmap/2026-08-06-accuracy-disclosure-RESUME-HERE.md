# RESUME HERE: Per-state accuracy disclosure, all eight tasks done. Nothing awaits John.

**Branch `feature/state-accuracy-disclosure`, cut from `feature/state-tax-phase5b` @ `587b5c4`.
NOT pushed, NOT merged.** Suite green after the whole-branch review fixes: 2,077 Swift Testing in
306 suites + 509 XCTest, 0 failures.

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
- **Task 7** (`d107b0d`): three entry points, each resolving its own state. **THE MULTI-YEAR ONE WAS
  REMOVED BEFORE MERGE, see the section below; two ship.**
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

## THE MULTI-YEAR ENTRY POINT IS GONE, AND HERE IS WHAT RESTORING IT COSTS
**Removed 2026-08-06 by John's decision, in the whole-branch review, before merge.** Two entry
points ship: single-year results (resident's state) and State Comparison (the INSPECTED state).

**Why.** `ProjectionEngine.computeStateTax` calls
`TaxCalculationEngine.calculateStateTax(income: federalAGI, ...)` and omits `postExemptionDeduction`.
That engine function does NOT apply `config.stateDeduction` itself; the caller must, and the
single-year caller `DataManager.calculateStateTax` does. So the multi-year projection taxes a base
still containing the whole state standard deduction and personal exemption, and for a
`.conformsToFederal` state carries no federal deduction across either. **Kansas MFJ is about $1,482
a year of phantom state tax. Idaho MFJ both 67 is about $2,517.** The affordance sat beside that
number and opened a page printing "Standard deduction: $8,240" and "Personal exemption: $18,320".
John: *"An absent explanation is better than an explanation that contradicts the number it
accompanies."*

**RESTORING IT DEPENDS ON, and neither is a view change:**
1. the engine gap above being fixed, so the page's deduction and exemption lines are true of
   multi-year figures too; **or**
2. a genuinely path-aware disclosure page, with its own path-specific copy and its own behavioural
   tests.

**AND, on route 1, AN END-TO-END MULTI-YEAR BEHAVIOUR PROBE MUST LAND BEFORE THE AFFORDANCE COMES
BACK.** Gate 3 cannot stand in for one: both of its probes call the engine with income the probe
itself already reduced by the state deduction, so they encode and re-verify the SINGLE-YEAR
contract. A green Gate 3 could never have caught this.

**The engine gap is NOT fixed and is out of scope for this branch:** it moves the frozen 1,020-value
behaviour baseline under `RetireSmartIRATests/Baselines/`. It is recorded in code at
`ProjectionEngine.computeStateTax`'s doc comment.

**The gate.** `StateAccuracyContentTests.noMultiYearSurfacePresentsTheAccuracyPage` sweeps every
production `.swift` file and asserts the set constructing `StateAccuracyView`, and the set carrying
an affordance's accessibility label, are EXACTLY the approved presenters. Structural rather than a
check for one symbol: a re-add under a different property name, in a different view, or through a
wrapper still fails it. Verified by mutation.

## GEORGIA'S FOURTEENTH SENTENCE IS GONE, AND GA NOW SHIPS AN EMPTY LIST
**Removed 2026-08-06 by John's decision, before merge.** `statetax-2026-GA.json` carried the only
limitation sentence on this branch that was neither one of the thirteen John approved nor one of the
six approved captions. Four problems: it called the TY2027 $70,000 a STANDARD DEDUCTION when it is
the retirement-income EXCLUSION and GA's standard deduction is $15,000/$30,000; it said "this
config" on a user surface; it stated no over/under direction; and its `pension` topic put it inside
the pension editor under "What kind of pension is this?", the exact placement `LimitationTopic` was
introduced to prevent. It predated the branch and had NO production consumer; this branch built two
readers for it. John: the fact that it predates the branch does not excuse this branch from
activating it for users.

**No replacement was shipped**, because John cannot approve wording that does not exist yet. Three
PROPOSED drafts are in `.superpowers/sdd/whole-branch-fix-report.md`, unshipped.

**The TY2027 fact is preserved** at
`.claude/memory/roadmap/2026-08-02-full-50-state-verification.md`, under Georgia, now stated
correctly and with the removal recorded.

**A sweep of all 51 configs found no other unapproved sentence.** The 19 that ship are the 13
approved sentences plus five of the six approved captions in config (HI, ID, VT, NC, MA); DC's
survivor-toggle caption is still a Swift literal in `IncomeSourcesView` and is the sixth.

**GEORGIA IS NOW THE THIRD STATE, with Iowa and Indiana, rendering a verified date, a primary source
and "No known limitations are currently recorded".** In aggregate that reads closer to a clean bill
than any single line of it claims. JOHN'S OPEN CALL. The design's optional second sentence ("State
tax rules are complex, and this does not mean every unusual situation is represented") was
deliberately left unshipped and unapproved, and stays that way.

## RECORDED, NOT FIXED
- **A per-state JSON decode failure now ERASES that state's disclosure.** `StateTaxDataLoader` turns
  a decode throw into a per-state fallback to the frozen legacy table, whose `verification` is
  `.unverified` with empty limitations, and the accompanying `assertionFailure` is a no-op in
  release. At the merge base the five caption sentences were Swift literals that could not fail to
  render; they now can. A release user hits the empty-state wording instead of the caption.
- **Gate 3's coverage is three claims, not the page.** Per-spouse cap (2 jurisdictions), Social
  Security (15), Roth conversions (4). Bracket rates, standard deduction, personal exemption,
  pension and IRA exemption levels, per-source rules and age gates are NOT behaviour-backed.
- **Four stale New York comments were corrected 2026-08-06** (`Phase5bNewYorkMilitaryTests` x2,
  `StateTaxData.swift` x2). They said NY was on neither divergence list and therefore required
  outright byte-identity; NY is now on `disclosureOnlyDivergentJurisdictions`, which excuses
  `verification` alone. Their CONCLUSIONS were unchanged: the mirrored rule and the mirrored
  disclosure are both computed fields and are still held to byte-identity.

## Remaining before merge
1. **An independent review of Tasks 3 through 8.** The controller verified all six MECHANICALLY, by
   grep and by suite, and never ran a reviewer over them. Tasks 1 and 2 are the only reviewed ones on
   this branch. This is the largest open risk, and it is a process gap, not a known defect.
2. **The Iowa `effectiveAge` candidate limitation sentence, not authored.** The engine gates Iowa's
   Roth conversion age on `effectiveAge`, the HOUSEHOLD MAXIMUM, not on the converting owner's age
   (`TaxCalculationEngine.swift:862` and its comment, which flags the question as undecided pending
   Iowa's Phase 5a golden scenario). The approved copy says "from age 55" and is silent about whose
   age, which is true for a single filer and for a couple where the older spouse converts, and
   arguably wrong where a 50 year old converts and a 60 year old spouse pulls the household maximum
   over the gate. That is an engine question first and a limitation sentence second; neither exists
   yet.

## THE THINGS A FRESH SESSION MUST NOT LOSE
1. **An empty `knownLimitations` NEVER renders as a clean bill of health.** Exact wording, specified
   by John: "No known limitations are currently recorded for this state and tax year." GEORGIA,
   IOWA AND INDIANA SHIP EMPTY LISTS, so this is load-bearing INSIDE the covered set, not only for
   the 36 states outside it.
2. **Gate 3 tests EFFECTIVE BEHAVIOUR, not a config echo.** If the page claims a per-spouse
   exclusion, the ENGINE must actually double it. A config echo would pass while the engine was wrong,
   which the predecessor branch shipped several times.
   **BUT DO NOT MISTAKE ITS EXISTENCE FOR COVERAGE.** It probes three claims: the per-spouse cap (2
   jurisdictions), Social Security (15) and Roth conversions (4). Bracket rates, the standard
   deduction, the personal exemption, pension and IRA exemption levels, per-source rules and age
   gates are NOT behaviour-backed. That is not academic: the STANDARD-DEDUCTION claim was among the
   unprobed ones and it is the one that turned out to be wrong on the multi-year path. And every
   probe is single-year by construction. Both limits are recorded above Gate 3's own MARK.
3. **`taxYear` 0 and empty `lastVerified` are what the 36 uncovered states carry.** Task 3 added the
   optional accessor `statedTaxYear` and deliberately chose NO fallback string, because that copy was
   John's. Task 6's fallbacks are now approved; the rule that no year is ever INVENTED still stands.
4. **Each entry point resolves a different state.** State Comparison uses the INSPECTED state, not the
   resident's. A comparison sheet for Oregon must never show California's disclosure. Both surviving
   resolvers were re-verified after the multi-year removal, including the 2,601-pair sweep.
5. **Layer B**: `disclosureOnlyDivergentJurisdictions` exists so populating `verification` does not
   force a state onto `phase5CorrectedJurisdictions`, which would permanently excuse the
   byte-identity check. Any newly populated state must join it.
6. **The optional second sentence on the empty-limitations string is still UNAPPROVED and still does
   not ship.** "State tax rules are complex, and this does not mean every unusual situation is
   represented" was never put to John and was not part of the 2026-08-06 approval. The gate on
   `noRecordedLimitationsSentence` is exact equality, so appending it is a copy change, not a tidy-up.
   See `StateAccuracyContent.swift` above `noRecordedLimitationsSentence`.
