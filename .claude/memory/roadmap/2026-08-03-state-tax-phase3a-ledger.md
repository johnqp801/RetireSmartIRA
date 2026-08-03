# State Tax Phase 3a: Schema Extensions — SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-03-state-tax-phase3a-schema-extensions.md
Spec: docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md §3.3, §4a row 3
Audit: .claude/memory/roadmap/2026-08-02-full-50-state-verification.md
Worktree: .worktrees/state-tax-phase3a (branch feature/state-tax-phase3a), off LOCAL main @ e540e9f

Predecessors: Phase 1 ledger 2026-08-02-state-tax-phase1-ledger.md,
Phase 2 ledger 2026-08-02-state-tax-phase2-ledger.md. Both record how a test in
this area can look like verification and provide none. Carry those controls forward.

## Scope decision (John, 2026-08-03)
Spec Phase 3 SPLIT into 3a and 3b.
  3a (this plan) = personalExemption, AGI phase-out, per-qualifying-spouse attribution,
     state-aware distribution age, data-driven Roth conversion rule. Five defaulted
     fields on existing types, all behavior-inert.
  3b (separate plan) = per-source exemptions, shipping WITH its user-facing
     classification UI. Rationale: flipping nine states' data reaches neither Alan
     nor Steve until the app can tell a government pension from a private one, and
     a field with no UI repeats the dead-wiring pattern (year1PrimaryWithdrawal,
     perYearExpenseOverrides).

## Contract for every task
BEHAVIOR-INERT. No computed tax value changes, any state, scenario, filing status or age.
A moved number is a defect in the change that moved it, never a tax correction.
No state's tax PARAMETERS change: Iowa stays .none/.none, Kansas gains no exemption,
MI/CT/VA/AZ keep today's values. The only config values added reproduce behavior that
already exists in hardcoded form (NJ's personal exemption, PA/IL/MS's conversion rule).
I2 stays OPEN: ProjectionEngine untouched, GoldenScenarioCrossPathTests pins unchanged
(single-year 42.0, multi-year 200.40469973890345).

## Pre-flight
- CONTROLLER FOUND AND FIXED A PLAN DEFECT BEFORE DISPATCH: the plan's Task 8 (Layer C
  required-vs-optional keys) and Task 9 (regenerate the 51 JSON files) could not be
  separate commits. Layer C's new `onlyNewJerseyShipsAPersonalExemptionKey` is RED until
  the regeneration lands, and the pre-existing exact-13-key assertion goes red the moment
  the regeneration lands first. Either order commits a knowingly-red suite. Merged into
  one Task 8; the gate is now Task 9. Plan renumbered, cross-references fixed.
- WHY TASK 1 EXISTS (the structural point of this phase): the Phase 1 gate compares the
  JSON config against the legacy Swift config, and Phase 3a edits BOTH, so they move
  together and Layer A stays green even if every number in the app changes. The spec's
  stated Phase 3 gate is therefore blind to this phase's actual failure mode. Task 1
  freezes 51 jurisdictions x 17 scenarios captured from main BEFORE any model change.
  No later task may regenerate that fixture to make itself pass.

## Baseline (to be captured by Task 1, not taken on faith)
main @ e540e9f: 1,620 Swift Testing in 275 suites + 503 XCTest, 0 failures.

## Tasks
(none complete yet)
Task 1: COMPLETE (commits 855b7c3 + fix 601a622 + hardening 00b3838, base db0977e).
  RE-REVIEWED CLEAN on opus: spec OK, quality Approved, no blocking findings.
  Deliverable: StateTaxBehaviorBaselineTests + Baselines/statetax-behavior-baseline-2026.json.
  51 jurisdictions x 20 scenarios = 1,020 frozen values. No production code touched.
  Full suite 1,622 Swift Testing in 277 suites + 503 XCTest, correct tree.

  ** MY PLAN'S DEFECT, caught by the implementer, and it is a trap worth remembering:
     the brief's second mutation edited StateTaxData.swift's configs2026Legacy and did
     NOT discriminate. Since Phase 1 Task 11, StateTaxData.config(for:) reads the bundled
     JSON and falls back to the legacy Swift table ONLY when a file fails to load, so a
     legacy-table edit is invisible to production. It LOOKS like a discriminating mutation
     and proves nothing. Implementer reported the unexpected PASS instead of reconstructing
     a plausible failure. Corrected mutation (statetax-2026-NJ.json regularExemptionMinAge
     62 -> 65) discriminates: NJ fails "single 63 in the early age tier", 2485.5 vs 0.0.
     Plan amended @ d9070b3. **

  REVIEWER'S REAL CATCH (Important 2), and it is the same shape this program keeps hitting:
     the original 17-scenario grid had NO MFJ case where the household distribution gate
     `primaryAge >= 59 || (enableSpouse && spouseAge >= 59)` evaluates FALSE. Every MFJ
     scenario with nonzero distributions already had a spouse at 59+. Task 5 rewrites that
     exact expression; a default branch degrading to `primaryAge >= 59 || enableSpouse`
     would have moved NONE of the 867 values. CONFIRMED EMPIRICALLY by the fix: that
     mutation now fails 14 states, and in every one the ONLY failing scenario is the newly
     added "MFJ 56 with spouse 55". No pre-existing scenario caught it.

  Also fixed: size assertion (a later implementer could otherwise delete a red scenario
    instead of fixing their code, and the suite would go green with orphaned fixture
    entries); NJ single-filer coverage for stepped tiers 2 and 3 (singlePercent 0.375 and
    0.1875 previously multiplied nothing); a comment that named njPersonalExemptions as a
    guard when calculateStateTax never calls it (the real guard is
    NJOtherExclusionAndExemptionsTests, and Task 3 Step 8's claim needs the same correction).
  Minor not fixed: fileprivate on BaselineScenario cascades (the generator suite is a
    separate struct in the same file calling its internal members). Reverted, as instructed.

  RE-REVIEW verified by independent arithmetic, not by trusting the report:
    - The regeneration is provably ADDITIVE. git diff --numstat on the fixture: 153
      insertions, ZERO deletions. All 867 pre-existing values byte-identical (checked
      under exact float AND repr comparison, so no last-bit drift). That doubles as proof
      no production file drifted from e540e9f, since drift would have moved values.
    - Reviewer hand-derived five of the 153 new values from config data alone, including
      both new NJ tier values to the cent, and confirmed singlePercent 0.375/0.1875 are
      the BINDING term in them (37,500 < 45,000 and 20,625 < 26,250), so Minor 1 is
      genuinely closed rather than nominally.
    - 14 failing states on the household-gate mutation is the arithmetically NECESSARY
      number, not a coverage shortfall. Reviewer derived the set independently before
      reading the report and matched it exactly. The one-state gap versus mutation 1's 15
      is NY, whose regularExemptionMinAge is 59 with no earlyAgeTier, so at effective age
      56 its IRA exemption resolves to .none and opening the gate changes nothing.
  Minor 7 TAKEN (00b3838): pinned `Self.scenarios.count == 20`. The existing count
    assertion compares baseline.count against allCases.count * scenarios.count, and BOTH
    operands move together under delete-and-regenerate. A literal does not. Verified green
    on the correct tree.
  Minor 6 FIXED in the same commit: the plan's Task 1 block still described 17 scenarios
    and 867 entries; an as-built note now points at the source file.
  Minor 5 NOT fixed (report prose only): task-1-report.md:726 mis-explains WHY 14 failed,
    saying the failing states "carry age-gated exemptions" when PA/IL/MS have
    regularExemptionMinAge 0 and exempt unconditionally. The mutated gate is the ENGINE's
    59 scalar at TaxCalculationEngine.swift:583, independent of each state's config age.
    Numbers and transcripts correct; the one-sentence rationalization is not. Do not
    inherit that mental model.
  Minor 2 OPEN, carry to final review: NJ still has exactly ONE scenario with an age
    inside the [62, 65) window ("single 63 in the early age tier") and its baseline is 0,
    so NJ can be caught becoming LESS generous there but never MORE generous.
  Minor 4 noted, not worth fixing: loadBaseline() decodes the 1020-entry file 51 times
    (once per parameterized case). Suite runs in ~45 ms.
Task 2: commits 39fefbe + fix cf680ce (base cdd66e2). Reviewed on sonnet, RE-REVIEW IN FLIGHT.
  distributionMinAge: Int = 59 on RetirementIncomeExemptions, replacing the engine's two
  hardcoded 59s. Decoder uses decodeIfPresent ?? 59 because the 51 JSON files do not carry
  the key until Task 8. Suite 1,625 ST in 278 suites + 503 XCTest, correct tree.
  Baseline held all 1,020 values, which is the inertness proof.

  ** REVIEWER'S CATCH, and it is the phase's recurring shape a second time: of the TWO
     converted sites, only ONE was guarded. Reverting `return age >= exemptions.distributionMinAge`
     inside ageQualifiesForExemption back to a literal 59 left BOTH the mechanism tests AND
     the 1,020-value baseline GREEN. That site is reachable only via bothSpousesQualify,
     which is gated on `enableSpouse &&`, and every mechanism test passed enableSpouse: false.
     It governs per-individual cap doubling for a state with regularExemptionMinAge == 0 and
     exemptionAppliesPerIndividual == true, which is a plausible Iowa shape in Phase 5.
     Closed by distributionMinAgeGatesPerIndividualDoubling; the fixer confirms it now fails
     under that exact revert (2000.0 vs 0.0) while the other two stay green. **

  ** QUESTION SETTLED BY EVIDENCE, worth keeping: the decoder default and the property
     default could silently diverge. The reviewer mutated `?? 59` to `?? 60` and the BASELINE
     gate failed 15 jurisdictions (e.g. VA "single 59, distributions only", 3192.5 vs 2502.5).
     So the pre-existing Task 1 gate, not the new "defaults to 59" unit test, is what protects
     that pairing. The unit test only checks the Swift memberwise default in isolation. **

  Reviewer also verified independently: all six `59` occurrences in applyRetirementExemptions
    accounted for; NY's regularExemptionMinAge: 59 (a state DATA value) correctly untouched;
    45 existing RetirementIncomeExemptions construction sites unaffected (implicit memberwise
    init, no explicit init); pbxproj, ProjectionEngine, baseline test and fixture all untouched.
  Minor fixed in cf680ce: the age-60 assertion pair's comment claimed it stopped the age-56
    pair from passing for the wrong reason. Mutation analysis showed the age-56 pair alone
    already discriminates that case. Comment now says it documents the boundary's shape.
  PROCESS NOTE: the fix agent returned mid-flight, having applied the edits but not committed,
    while waiting on a background monitor it had started. Verified the tree directly rather
    than assuming, found edits uncommitted and production source correctly restored, and
    resumed it with an instruction to run in the foreground. Do not let subagents background
    their own verification runs.

## CONTROLLER ERROR, caught by the reviewer, fixed at a75d8eb
  I ran `git add -A && git commit` in this worktree WHILE the Task 2 reviewer was mid-mutation,
  and it swept the reviewer's temporary revert of
  `return age >= exemptions.distributionMinAge` -> `return age >= 59` into commit b22270c,
  under a message reading "docs(ledger)". HEAD genuinely carried the regression: the very fix
  Task 2 had just added was silently undone, and the commit label gave no hint.
  Timestamps confirm the race: the reviewer's xcodebuild started 01:45:29, b22270c is 01:45:30.

  FOUND BY: the reviewer, which noticed HEAD was not the SHA it expected and read the commit.
  It restored the correct line in the working tree and deliberately did NOT commit, since the
  history was not its to rewrite. Correct call.

  FIXED: amended b22270c with the restoration staged, so the commit's tree now equals cf680ce
  plus the ledger only. Verified `git diff cf680ce HEAD --stat` shows the ledger file alone,
  working tree clean, and the mechanism + baseline suites green on the correct tree.
  b22270c is superseded by a75d8eb; any earlier reference to b22270c means a75d8eb.
  AUDITED the other five doc commits (db0977e, 00b3838, ecb3f16, 18c70b0, cdd66e2): all clean,
  no stray hunks. Only b22270c was contaminated.

  ** PROCESS CHANGE, binding for the rest of this phase: reviewers and fix agents MUTATE
     PRODUCTION FILES in this shared worktree as their primary verification method, so the
     working tree is not mine to sweep. (1) NEVER `git add -A` here; stage explicit paths.
     (2) NEVER commit while a review or fix agent is in flight. Wait for its notification.
     A commit that lands during a mutation window looks exactly like a legitimate commit. **
