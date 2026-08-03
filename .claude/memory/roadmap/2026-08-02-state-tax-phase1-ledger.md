# State Tax Phase 1: JSON Extraction — SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-02-state-tax-phase1-json-extraction.md
Spec: docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md
Audit: .claude/memory/roadmap/2026-08-02-full-50-state-verification.md
Worktree: .worktrees/state-tax-json-migration (branch feature/state-tax-json-migration)

NOTE: a DIFFERENT ledger for the completed V2.3 tax-funding work lives in the main
repo at /Users/johnurban/Projects/RetireSmartIRA/.superpowers/sdd/progress.md.
Do not confuse the two. This file covers only State Tax Phase 1.

Branched off LOCAL main @ 25d7edd, deliberately: origin/main is 2 commits behind and
lacks af45404 (caret fix, owed to Alan) + 25d7edd (Year-1 override wipe).

Baseline verified green BEFORE Task 1:
  1,570 Swift Testing in 265 suites + 503 XCTest, 0 failures, ** TEST SUCCEEDED **
Any failure from here is attributable to the change that produced it.

## Contract for every task in this phase
Phase 1 is BEHAVIOR-INERT. No tax value changes anywhere. A diff in engine output is a
MIGRATION DEFECT, never a tax correction. Corrections happen in Phase 5, each gated by a
golden scenario derived from a state's own form.

## Pre-flight
- Moved the table-wide safe-harbor round-trip test out of Task 4 (where the plan wrote it
  then commented it out until Task 8) into Task 8 where its dependency exists. Commit e9d1115.
- JOHN'S DECISION: Task 8 Step 5 (Xcode folder reference) is JOHN'S to do in Xcode.
  NO subagent may edit project.pbxproj. That decision STANDS as the fallback.
- SUPERSEDING FINDING (verified after he decided): the project uses
  PBXFileSystemSynchronizedRootGroup (objectVersion 77, Xcode 16+) on BOTH
  RetireSmartIRA/ and RetireSmartIRATests/, with no exception sets. New files under
  those folders are bundled automatically, so no task needs manual Xcode work and the
  pause is probably unnecessary. Open question is only whether synchronized bundling
  PRESERVES StateTaxData/<year>/ or FLATTENS it. Task 9's loader resolves both layouts
  and anchors on Bundle(for: BundleMarker.self), not Bundle.main (which is the test
  runner under xcodebuild). Task 8 Step 5 now VERIFIES the built bundle and reports which
  layout appeared; it reports BLOCKED rather than editing the project file.

## Tasks
(none complete yet)
Task 1: complete (commit 67f3058, base b4fd939; review clean BOTH verdicts: spec OK, quality Approved)
  Exactly 2 files, 2 tests. pbxproj untouched (confirmed by me independently AND by reviewer).
  No em dashes (confirmed independently). Suite 1,572 ST (1,570 baseline + 2) + 503 XCTest.
  Minor deferred: report narrative misstated file line counts (37/25 vs actual 39/29). Cosmetic, code correct.
  Minor CARRIED INTO TASK 2 (my plan's defect, not implementer's): verificationUnverifiedDefault
    asserts 3 of 4 fields, never billReferences.isEmpty. A future non-empty default slips through.
    Folded into Task 2 as an explicit one-line requirement since Task 2 edits that same file.
  REVIEWER OBSERVATION worth carrying: verificationRoundTrips does NOT discriminate against any
    current bug (synthesized Codable over String/[String] is correct-by-construction). It is a
    forward-looking regression guard only. From Task 2 on, conformances are HAND-WRITTEN, so
    round-trip tests start doing real work. Watch that Tasks 2-7 tests genuinely discriminate.
  Reviewer could not independently verify the RED transcript (report paraphrased rather than pasted
    it); GREEN was a genuine pasted runner transcript. Judged "credible but not independently
    verified". For later tasks, require the RED output be PASTED, not summarized.
Task 2: complete (commit 5574c65, base 67f3058; review clean BOTH verdicts: spec OK, quality Approved)
  Created StateTaxCodable.swift (serialization only, no tax logic = BEHAVIOR-INERT holds).
  Sanctioned billReferences one-liner landed. pbxproj untouched, no em dashes (both confirmed independently).
  Suite 1,573 ST + 503 XCTest. RED output PASTED verbatim this time (the Task 1 gap is closed).
  Reviewer verified exhaustiveness: adding a 5th StateTaxSystem case breaks compilation on BOTH
    encode and decode (no default: in either production switch). Desired.
  ** CARRY INTO TASKS 3-7 (reviewer's key insight): taxSystemRoundTrips only catches a
     single/married SWAP because the fixture uses ASYMMETRIC data (thresholds 23,000 vs 46,000).
     Symmetric fixture data would let swap bugs pass silently. Every remaining round-trip test
     MUST use distinct values per field/filing status, or it proves less than it appears to. **
  Minor deferred (x2, both report-narrative only, code correct): report claimed the test "checks
    that UUIDs are regenerated" (matchesShape never reads .id at all, by design); line counts
    misstated again (72 vs 42 insertions, 46 vs 49 lines). RECURRING across Tasks 1 and 2 -
    tell implementers to stop hand-counting lines; it wastes reviewer attention.
Task 3: complete (commit de0a946, base 5574c65; spec OK, quality Approved with 2 Minor findings)
  StateDeduction + EstimatedPaymentSchedule Codable. PlanningModels.swift changed EXACTLY one line
  (conformance only) - verified independently by me AND reviewer. pbxproj untouched, no em dashes.
  Asymmetric-fixture requirement HELD: added .fixed(single: 8_000, married: 16_000) alongside KY's
  genuinely-equal 3_360/3_360. Reviewer traced the swap detection concretely; RED was run WITH the
  asymmetric case already present, so TDD ordering was correct, not bolted on after.
  Reviewer confirmed the hand-counted-line-number problem from Tasks 1-2 is resolved.
  ** IMPORTANT FOR TASK 9 (reviewer's real catch, filed as Minor but it grows teeth later):
     EstimatedPaymentSchedule's custom init enforces precondition(|q1+q2+q3+q4 - 1.0| < 0.001).
     Compiler-SYNTHESIZED init(from:) assigns stored properties directly and BYPASSES that
     precondition entirely. Inert today (nothing decodes it from JSON yet), but Task 7 decodes
     StateTaxConfig which CONTAINS this type, and Task 9's loader reads real JSON. By then a
     malformed quarters array would load silently. Task 9 must validate it, or the type needs a
     hand-written init(from:) that reproduces the invariant. DO NOT let this reach Phase 5. **
  Minor deferred: StateTaxCodable.swift now mixes single-line and multi-line CodingKeys/Kind
    declaration styles (inherited from my brief's own snippets, not an implementer choice).
    Cosmetic. Worth one reformat pass before the file grows to 7 conformances.
  Reviewer ⚠️: implementer ran only the SCOPED suite, not the full one. Controller is running the
    full suite independently before Task 4 rather than assuming.
Task 4: complete (commit 8887773, base de0a946; spec OK, quality Approved with findings)
  ** CONTROLLER CAUGHT A PLAN DEFECT BEFORE DISPATCH: my plan's Task 4 code handled only THREE
     StateSafeHarborRule cases. The real enum (PlanningModels.swift:162-182) has FIVE - it also has
     mirrorsFederalWithDisqualification(disqualifyAGI:) [California] and noPenalty [Idaho], BOTH of
     which are live in the config table. Shipping the plan's 3-case version would have been silent
     data loss for CA and ID at Task 8. Told the implementer the full case list upfront. **
  All 5 cases handled in Kind + encode + init(from:). NO default: branch in either switch (verified
  independently by me AND reviewer), so a 6th case breaks compilation rather than misdecoding.
  Reviewer verified NO KEY REUSE across cases (rate/threshold/lowRate/highRate/disqualifyAGI each
  used by exactly one case), so hand-edited JSON cannot decode into the wrong case silently.
  Mutation analysis confirmed caught: lowRate/highRate swap; disqualification payload dropped;
  and the nasty one - noPenalty vs mirrorsFederal confusion (both payload-free) is caught because
  both appear as distinct entries in the same test array.
  RED pasted verbatim; reviewer confirmed the cited line numbers match the real 5-case test, so the
  RED capture came from the extended test, not the brief's smaller version.
  IMPORTANT (evidentiary, not code): report's full-suite proof pasted ONLY the Swift Testing
    summary (1,576/266), never the XCTest leg (503). Controller re-ran the full suite to close it.
  Minor deferred: StateTaxCodable.swift still mixes single-line (StateDeduction) and multi-line
    (StateTaxSystem, StateSafeHarborRule) CodingKeys/Kind styles. Task 4 correctly did not fix it
    (out of scope). Worth one normalization pass before the file reaches 7 conformances.
  PROCESS CHANGE for Tasks 5-12: require BOTH summary lines pasted (Swift Testing AND XCTest).

## CONTROLLER PROCESS ERROR (caught 2026-08-02, before it could mislead anything)
The Bash session cwd RESETS to /Users/johnurban/Projects/RetireSmartIRA between calls. It does
NOT persist. My Task 4 full-suite verification ran without an explicit cd and therefore tested the
MAIN REPO on branch article/conversion-tax-funding-figures, not this worktree.

It reported 1,575 tests in 265 suites, which is dangerously close to the expected 1,576/266 and
would have read as plausible. Caught only because the suite count was one short of what Task 4's
+1 test required. The article branch happens to sit at 1,575/265 (1,570 baseline + 5 article
figure tests), so the near-collision was luck, not signal.

VERIFIED CORRECT (both targeted the worktree, confirmed by the .xcodeproj path in each log):
  - baseline-test.log        -> worktree, 1,570 ST in 265 suites + 503 XCTest  (true baseline)
  - task3-full-suite.log     -> worktree, 1,575 ST in 266 suites + 503 XCTest  (true post-Task-3)
WRONG TREE, DISREGARD:
  - task4-full-suite.log     -> MAIN REPO / article branch. Re-run as task4-full-suite-RETRY.log.

GUARD for every remaining task: (1) always `cd <worktree> && xcodebuild ...` inside the SAME
command; (2) before trusting any suite count, grep the log for the .xcodeproj path and confirm it
contains .worktrees/state-tax-json-migration. A count alone is not proof of which tree ran.
Task 5: complete (commits 2ea8296 + fix 31e3f90, base 8887773; RE-REVIEWED CLEAN, both verdicts, zero remaining findings)
  ExemptionLevel + PhaseoutTier Codable. StateTaxData.swift NOT modified (implicit memberwise init
  was already accessible module-wide), so zero blast radius into engine logic. pbxproj untouched,
  no em dashes. Report pasted BOTH suite lines this time (1,577 ST + 503 XCTest) - Task 4 gap closed.

  ** BEST FINDING OF THE PHASE SO FAR (implementer's, verified by reviewer):
     The brief's behavioral-only test would NOT have caught a silent .infinity -> 0 collapse.
     Reason: tierPercent does `tiers.first { income <= $0.upperBound } ?? tiers.last`, so the LAST
     tier is selected either way - directly when its bound is correctly .infinity, or via the ??
     fallback when corrupted to a finite value. Identical struct, identical percentages, identical
     excludedAmount. The final tier's own upperBound is BEHAVIORALLY INERT.
     Confirmed empirically by mutation test, then closed with a structural isInfinite assertion.
     This is exactly the quiet-loss failure mode Task 5 was commissioned to guard against, and a
     purely behavioral test would have shipped blind to it. NJ is a CONFIRMED-CORRECT state, so
     this would have broken working behavior. **

  IMPORTANT - FIXED and re-verified (31e3f90). Reviewer independently re-derived the numbers from
     source (single clamps to 75,000 vs MFJ 90,000; 4 behavioral + 2 structural failures) instead of
     trusting the transcript, and walked EVERY field confirming no blind spot remains. Detail:
     maxExemptSingle/maxExemptMFJ swap is UNGUARDED - same blind-spot class, different fields.
     Behaviorally invisible because every call uses eligibleIncome: 50_000, below BOTH caps
     (75k/100k), so chartMax's min(eligibleIncome, cap) clamps to 50,000 regardless of which cap.
     Structurally invisible because the new assertion destructures (_, _, let originalTiers),
     discarding both caps. Shipped encode/decode is CORRECT today - this is a coverage gap, not a
     live bug. Fix requires BOTH a structural cap comparison AND a behavioral case with
     eligibleIncome BETWEEN the caps (90_000), each mutation-tested to prove it discriminates.

  Reviewer mutation analysis on the committed test: tiers decoded in REVERSE = caught (both ways);
     mfjPercent/singlePercent swap = caught, but ONLY by the structural check for tier index 1,
     since no income in the grid (40k/90k/130k/200k) falls in that tier's (100k, 125k] band.
     That is a good argument for keeping structural and behavioral checks as complements.
  Minor deferred: report's described mechanism for the last-tier fallback is imprecise (in the
     UNCORRUPTED case `first` matches .infinity directly; the ?? fallback only rescues the mutated
     case). Conclusion correct, mechanism description slightly off. Documentation nit only.
Task 6: complete (commits a18104e + fix 0d0e4a3, base 31e3f90; RE-REVIEWED CLEAN both verdicts, zero findings)
  Suite after fix: 1,583 ST in 266 suites + 503 XCTest, 0 failures, correct tree (I verified independently).
  RetirementIncomeExemptions + AgeTier + CapGainsTreatment Codable. StateTaxData.swift untouched,
  pbxproj untouched, no em dashes. Suite 1,580 ST + 503 XCTest, right tree confirmed.
  Implementer improved on MY brief unprompted: brief's test covered only 6 of 9 fields and used
  IDENTICAL values for pensionExemption/iraWithdrawalExemption. Hardened to 65,000 vs 42,000,
  added an empty-{} defaults test, mutation-tested the socialSecurityExempt decode default.
  I verified independently: all nine `?? default` fallbacks match their declarations exactly,
  including the dangerous socialSecurityExempt ?? true (a ?? false would have made SS taxable in
  every state whose JSON omits the key).

  ** THE DEFAULT-MASKING TRAP (reviewer's catch, third variant of the Task 5 lesson):
     A fixture value that EQUALS its declared default cannot prove the field survived. Dropping
     socialSecurityExempt on ENCODE is invisible - the key vanishes, decodeIfPresent falls back to
     `true`, and the equality assertion passes. The other two tests hand-craft JSON literals so they
     never call encode() at all. This is the THIRD time this phase that a test looked like coverage
     and was not (Task 5 .infinity, Task 5 caps, now this). All three share one root cause:
     asserting on ROUND-TRIPPED VALUES rather than on the ENCODED REPRESENTATION. **

  IMPORTANT x2, fix dispatched:
    (1) socialSecurityExempt: true == its own default -> encode-drop invisible. Set to false.
    (2) All four Bools are `true`, so a CodingKeys label swap between any two yields byte-identical
        JSON. Value-distinctness CANNOT fully fix this (2 values, 4 fields), so the fix is structural.
    FIX = a JSON-SHAPE TEST: encode, JSONSerialization into a dictionary, assert every key is present
    with the expected value. That catches dropped fields, swapped CodingKeys labels, and
    default-masked fields for all nine at once, independent of fixture values. This generalizes and
    should be the pattern for Task 7's StateTaxConfig too.

  ** CARRY INTO TASK 9 (reviewer's concrete recommendation, folded into the Task 6 fix instead):
     AgeTier decodes `lowerBound...upperBound` via ClosedRange's `...`, whose precondition TRAPS
     (process crash) when minAge > maxAge. Task 9's loader reads real JSON across 51 jurisdictions,
     so malformed input must throw a catchable DecodingError, not kill the app. Guard added now. **
  Minor: report's closing claim "All nine fields are guarded... No field was left as an unguarded
    limitation" was inaccurate; being corrected.

  FIX 0d0e4a3 contents: socialSecurityExempt fixture flipped to false; JSON-SHAPE test added
  (encode -> JSONSerialization -> assert every key present with expected value); AgeTier decode
  guard throwing DecodingError instead of ClosedRange's trap.

  ** DEEPER FINDING FROM THE MUTATION TESTING (implementer's, beyond what I asked for):
     A JSON-shape test with a SINGLE fixture STILL cannot catch a CodingKeys swap between two
     fields that hold the SAME value. Asserting key->value mapping is not enough: if both booleans
     are `true`, swapping their forKey: labels still writes the correct value under each key.
     Empirically confirmed - the swap went UNDETECTED against a single fixture and only failed once
     a SECOND fixture with a different value combination was added.
     So the full rule is: JSON-shape assertions PLUS at least two fixtures whose value combinations
     differ per field. This is the 4th variant of the same lesson this phase (Task 5 .infinity,
     Task 5 caps, Task 6 default-masking, now Task 6 same-value key swap). CARRY INTO TASK 7,
     which has FIVE conformity Bools all defaulting to false - the exact same trap, five-way. **

  AgeTier guard confirmed LOAD-BEARING by mutation: removing it and feeding minAge 70 / maxAge 60
    traps the process (Fatal error: Range requires lowerBound <= upperBound, EXIT=65) rather than
    throwing. Task 9's loader reads 51 real JSON files, so this had to be a catchable error.
  Process note: the fix agent died on an API error AFTER committing 0d0e4a3 but BEFORE writing its
    report. Verified the tree directly rather than assuming; found code complete and report stale,
    still claiming the AgeTier trap was "out of scope" which the fix had just made false. Resumed
    the agent for the report only, explicitly instructing it to declare any mutation it had NOT
    actually run rather than reconstruct plausible output.

  RE-REVIEW VERDICT: spec OK, Approved, no outstanding findings. Reviewer independently rebuilt the
  swap-discrimination truth table and the trap-vs-throw claim instead of trusting the report.

  ** THE GENERAL RULE, now proven (carry into Task 7 and every later Codable work):
     To make a CodingKeys swap detectable among N fields of the SAME type, you need enough fixtures
     that every field has a UNIQUE signature across them. For booleans that is ceil(log2(N)) fixtures.
     Task 6 had 4 Bools -> 2 fixtures, and the committed test uses them optimally:
       socialSecurityExempt          (F,F)
       exemptionAppliesPerIndividual (F,T)
       pensionAndIRAShareSingleCap   (T,F)
       otherRetirementIncomeExclusion(T,T)
     All 4 signatures distinct => all C(4,2)=6 pairs discriminable. Single-fixture testing CANNOT
     achieve this at any level of inspection detail - it is a pigeonhole limit, not a test-quality
     problem (4 fields into 2 values must repeat).
     TASK 7 HAS FIVE conformity Bools -> needs THREE fixtures (2^3=8 >= 5 signatures). **

  Reviewer also confirmed no OTHER same-type sibling group is exposed: pensionExemption/
  iraWithdrawalExemption already use distinct values (65,000/42,000); earlyAgeTier,
  regularExemptionMinAge and capitalGainsTreatment are singletons of their type.
Task 7: complete (commits 6d8ec70 + fix ce0c514, base 0d0e4a3; REVIEWED CLEAN both verdicts, zero findings)
  StateTaxConfig Codable + `verification` stored property. StateTaxData.swift diff is EXACTLY the
  property, the init param, and the assignment - nothing else (verified by me AND reviewer).
  Suite 1,587 ST in 266 suites + 503 XCTest, correct tree. pbxproj untouched, no em dashes.
  Three-fixture boolean signatures verified distinct by reviewer: hsa=100, ira=010, other=001,
    k401=110, capLoss=101 => all C(5,2)=10 swap pairs discriminable.
  Unknown state abbreviation throws a TYPED DecodingError before any other field decodes.

  ** CONTROLLER CAUGHT THE WIDEST-BLAST-RADIUS GAP OF THE PHASE (before the reviewer saw it):
     The first pass omitted estimatedPaymentSchedule and safeHarborRule from the fixture, so both
     sat at their DEFAULTS and a dropped encode line was undetectable. The implementer had framed
     this as "by design, matching Task 6's precedent" - but Task 6's precedent was to FIX
     default-masking, not accept it.
     Blast radius: 24 of 51 states set an EXPLICIT safeHarborRule (20 .flatRate, KY .agiThreshold,
     CA .mirrorsFederalWithDisqualification, ID .noPenalty, 1 explicit .mirrorsFederal), and CA sets
     a non-federal estimatedPaymentSchedule. A silent drop would have rewritten 23 STATES' SAFE
     HARBOR RULES to .mirrorsFederal in Task 8's generated files.
     WORSE: Task 10's equivalence gate would likely NOT have caught it, because that gate compares
     computed STATE TAX and safe harbor governs estimated-tax PENALTY timing, not the tax figure.
     Fixed in ce0c514 with non-default fixtures + direct JSON-shape assertions, both drop mutations
     confirmed failing before and passing after. **

## HARD REQUIREMENT FOR TASK 10 (accumulated evidence, five instances)
  A numeric "no value moved" comparison is NECESSARY BUT NOT SUFFICIENT to prove this migration is
  lossless. Five fields this phase could have been silently lost without changing any computed tax:
    1. NJ .infinity tier bound (behaviorally inert by construction)
    2. NJ maxExemptSingle/maxExemptMFJ (clamp never bound at the fixture's income)
    3. socialSecurityExempt (fixture value equalled its own default)
    4. same-value boolean CodingKeys swap (byte-identical JSON, pigeonhole limit)
    5. safeHarborRule / estimatedPaymentSchedule (default-masked, 24-state blast radius, and
       OUTSIDE what the equivalence gate even measures)
  Task 10 MUST add structural field-level verification alongside the numeric comparison.
Task 8: complete (commits 2ec51ab + 6314b0b + 92ebb6b, base ce0c514; REVIEWED CLEAN both verdicts)
  51 files GENERATED (never transcribed) as statetax-2026-<ABBR>.json. Suite 1,589 ST in 267 suites
  + 503 XCTest. pbxproj untouched. configs2026 -> configs2026Legacy rename + alias, all 8 refs inert.
  Reviewer spot-checked NJ/CA/ID/KY/IL/TX FIELD BY FIELD against the Swift source: zero mismatches.
  Parsed all 51 programmatically: schema complete, verification present and .unverified in every one.

  ** TWO CONTROLLER-DIRECTED FIXES, both from real defects found during the task:
     (1) BUNDLE FLATTENING. Xcode 16 PBXFileSystemSynchronizedRootGroup copies resources
         INDIVIDUALLY, so Resources/StateTaxData/2026/CA.json lands in the app as bare CA.json with
         NO directory. The implementer proposed a loader fallback for CA.json; I rejected it, because
         2027/CA.json would ALSO flatten to CA.json and silently collide, and the spec requires
         adding a tax year to be purely additive. Fixed by year-prefixing the filenames, which is the
         convention this app ALREADY proved: tax-2023..tax-2026.json sit flat in the source root and
         load via forResource: "tax-\(year)" (TaxYearConfig.swift:204).
         CONSEQUENCE: John's reserved Xcode folder-reference step is NO LONGER NEEDED AT ALL, and
         Task 9's loader needs no change - the new names match its already-drafted 3rd fallback.
     (2) 285 RANDOM UUIDs. TaxBracket.id is a fresh UUID per process, so every regeneration rewrote
         285 lines of pure noise - inverting the whole reason for moving to JSON (diffable,
         reviewable). Fixed by excluding id from TaxBracket's CodingKeys. Safe on evidence: the
         app's own tax-2026.json has NEVER carried ids, and id is used in zero computations.
         DETERMINISM NOW PROVEN, not asserted: generated twice into separate snapshots,
         diff -r empty, exit 0. **

  Minor (report accuracy only, no code change): report said tax-*.json decode through TaxBracket;
    they actually decode through TaxYearConfig.BracketEntry. Conclusion still correct, and better
    supported via PersistenceManager's TaxBrackets UserDefaults round-trip, which the reviewer found.
  Controller error acknowledged: I never generated task-8-brief.md. The implementer sourced from the
    committed plan doc and cross-checked the dispatch prompt. Correct recovery.
  Recurring hazard, hit TWICE more this task: Bash cwd silently resets to the MAIN REPO on an
    unrelated branch. A stray rm no-op'd there. Explicit cd on EVERY command, no exceptions.
Task 9: complete (commit 24e2640, base 92ebb6b; REVIEWED CLEAN both verdicts)
  StateTaxDataLoader. Suite 1,597 ST in 268 suites + 503 XCTest. pbxproj untouched, .scratch not
  committed, no em dashes. Nothing in production consumes the loader yet (correct - Task 11 wires it).
  Single year-prefixed lookup, NO dead fallbacks. Reviewer confirmed the implementer also removed the
  brief's now-unreachable directoryMissing/incomplete error cases rather than leaving dead code.
  Reviewer verified INDEPENDENTLY, against the real files on disk rather than the report's prose:
    - no substitution path exists on any branch
    - the 51-file tests are REAL (call StateTaxDataLoader.load, no fixtures)
    - NJ's .infinity canary goes through the REAL loader path; confirmed statetax-2026-NJ.json
      carries "unbounded" and the PhaseoutTier decoder maps it back to .infinity
    - quarters validation tolerance (0.001) matches PlanningModels.swift:107 exactly, throws not traps

  ** MINOR -> HARD REQUIREMENT FOR TASK 11 (my plan's defect, again):
     StateTaxDataLoader.configs2026 swallows a load failure via assertionFailure (a NO-OP in release
     builds) and returns [:]. That is a silent empty substitute - precisely the pattern the throwing
     loader was built to eliminate. Verbatim from my brief's Step 3 code. Inert today because nothing
     consumes it; Task 11 wires it into StateTaxData.config(for:), which is exactly when it starts
     mattering. TASK 11 MUST replace it with a loud failure path. **
Task 10: THE PHASE 1 GATE - COMPLETE AND CERTIFIED (commits 790dae7 + fix f2d4cd7, base 24e2640)
  Reviewed on opus, re-reviewed after fixes. FINAL VERDICT, verbatim:
  "Yes. This gate certifies the migration, without qualification."
  Suite 1,600 ST in 271 suites + 503 XCTest, 0 failures, correct tree.
  Three layers, all proven able to FAIL under mutation:
    A numeric   - engine output identical, 51 states x scenario grid  (mutated IL rate -> failed on IL)
    B structural- re-encode both configs, compare Data bytes           (decode-side mutation -> failed CA/NJ)
    C file keys - each file carries EXACTLY the 13 top-level keys      (removed a CA key -> failed on CA)

  ** THE STRUCTURAL FACT THAT JUSTIFIES THE REDESIGN (reviewer, verified):
     calculateStateTax reads only TWO of StateTaxConfig's THIRTEEN fields - taxSystem and
     retirementExemptions. It never reads stateDeduction, safeHarborRule, estimatedPaymentSchedule,
     currentYearSafeHarborRate, the conformity Bools, capitalLossesClassIsolated, or verification.
     So the plan's ORIGINAL single-layer numeric gate was structurally blind to 11 of 13 fields.
     Without Layer B this gate would have certified a migration that silently dropped California's
     30/40/0/30 payment schedule, or all 23 states' non-default safeHarborRule values, or every
     state's stateDeduction amounts. Layer B is where most of the protection actually lives. **

  ** LAYER B's LIMIT, found empirically, not predicted: dropping a field from encode(to:) does NOT
     fail Layer B - SYMMETRIC CANCELLATION, both sides omit it and still compare equal. Worse, the
     reviewer drew the consequence nobody had written down: an encode-side drop BLINDS Layer B for
     that field permanently, since a later decode-side loss of the same field would also pass.
     Encoder completeness is a PRECONDITION for Layer B's validity, not a parallel concern. **

  IMPORTANT x2, both fixed in f2d4cd7:
    (1) Layer C was MISLABELED "encode is complete". It reads the CHECKED-IN FILES, so a code-only
        encode(to:) drop leaves it green. It proves the SHIPPED DATA is complete, not the encoder.
        The encoder's real guard is the Task 6/7 JSON-shape unit tests. Dangerous as a label: a
        Phase 3 maintainer trusting it could delete those unit tests and silently reopen the gap.
        Renamed + pointer added to the three tests that actually guard the encoder.
    (2) Layer A passed incomeSources: [] everywhere, so pensionIncome == 0 in ALL 9 x 51 runs and
        pensionExemption was NEVER exercised for the 47 states without a shared cap. AZ, MD, ME, MT
        have pensionExemption as their ONLY non-.none exemption field, so Layer A tested essentially
        nothing for them. Fixed by adding a .pension IncomeSource scenario. Proof: corrupting AZ's
        cap ($2,500 -> $50,000) now fails Layer A (1125.0 vs 2312.5); previously invisible.
  Reviewer corrected the implementer's Concern #1: RetirementIncomeExemptions.socialSecurityExempt
    IS guarded, at StateTaxCodableRoundTripTests.swift:291. Branch is airtight against encode-side
    field loss at EVERY nesting level; no hole to name.
  Open, deliberately not closed (Layer B covers them structurally): military-retirement branch
    (TaxCalculationEngine.swift:643) and NJ's earned-income condition (:604) are unexercised by A.

  RE-REVIEW (opus) verified EMPIRICALLY, not by reading: reviewer re-implemented
  applyRetirementExemptions independently and ran all 51 configs through it twice (real cap vs
  perturbed) to test whether caps actually BIND. Results: AZ 2312.50 -> 375.00, MD 2503 -> 660,
  ME 4485.30 -> 870, MT 4654.09 -> 705, and NJ maxExemptSingle 280.00 -> 0.00. NJ's single cap
  now binds where it never did before. Coverage is WIDER than the commit claimed: 15 states'
  pension caps now measurably move Layer A (AR AZ CO DE GA KY LA MD ME MT NJ NY OK SC VA).
  AZ mutation arithmetic reproduces to the cent from committed code. Purely additive; no assertion
  removed, relaxed, or given a tolerance.

  ** BETTER REASON than mine for stopping where we did on the two unexercised branches:
     I accepted them because "Layer B covers them structurally". The reviewer's reason is stronger:
     NEITHER BRANCH IS DRIVEN BY A FIELD THIS PHASE MIGRATES. Military retirement resolves through
     MilitaryRetirementExemption.swift's own hardcoded table keyed by a state-code STRING; it never
     reads StateTaxConfig and no key in the 51 JSON files feeds it. NJ's earned-income limb is
     gated by a hardcoded literal, not config data. Exercising either would test the ENGINE, not
     the MIGRATION, which is not what this gate is for. **
Task 11: complete (commits 2dba617 + fix 2c08da8; reviewed, Approved with findings, both fixed)
  PRODUCTION NOW READS JSON. California substitution REMOVED. Silent [:] fallback REMOVED.
  Release fallback goes to configs2026Legacy FOR THE SAME STATE, with legacyFallbackFired observable.
  Reviewer corrected me: the deletion hazard I worried about is NOT real (both fallback sites use
  direct static access, so deleting configs2026Legacy is a COMPILE ERROR, not a silent failure).
  Reviewer found a hazard I missed: the safety comment was UNSCOPED. The gate proves equivalence for
  TAX YEAR 2026 against today's legacy table. A future 2027 copy-paste would carry "this is safe"
  into a context where it is false. Now scoped explicitly.
  Reviewer also caught the implementer (and me) accepting too broad a claim: the assertionFailure
  TRAP is untestable, but the fallback ASSIGNMENT around it was extractable and testable. Extracted;
  removing the assignment now produces 106 failures.
Task 12: complete (commit d28bb45, done by controller directly, comment-only)
  Removed the TODO instructing a future engineer to uncap Colorado on the authority of SB25-136,
  a bill postponed indefinitely 2025-02-27 that never became law. Also corrected the TaxsimOracle
  header that cited the same dead bill. Colorado's OWN config comment already said "DID NOT pass" -
  the false claim lived only in the two places that told someone what to do NEXT.

## ALL 12 TASKS COMPLETE. FULL TESTING GREEN ON BOTH PLATFORMS.
  macOS: 1,605 Swift Testing in 271 suites + 503 XCTest, 0 failures, ** TEST SUCCEEDED **
  iOS:   ** BUILD SUCCEEDED **, 0 errors
  iOS BUNDLING VERIFIED (nobody had checked this; Task 8 only verified macOS): all 51
    statetax-2026-*.json present in a freshly built .app. Universal binary, so an unbundled
    resource would have thrown on every iPhone launch while every Mac test stayed green.
  Baseline at phase start was 1,570 + 503. Net +35 tests, all additive, zero expected values changed.
  22 commits off main. Working tree clean.

## FINAL WHOLE-BRANCH REVIEW (opus) - VERDICT: READY TO MERGE, no Critical findings
  Hunted specifically for the cross-task shape that bit this repo on the V2.3 branch (a renamed
  JSON coding key orphaning a legacy decoder, every per-task review passing). TRACED AND BENIGN:
  TaxBracket lost `id` from CodingKeys in Task 8, and that type IS round-tripped through
  PersistenceManager into UserDefaults for user-editable brackets. Previously persisted blobs DO
  contain "id". Decode now ignores the unknown key and `var id = UUID()` supplies a fresh default.
  No throw, no wrong default. Also confirmed tax-2023..2026.json decode through
  TaxYearConfig.BracketEntry, NOT TaxBracket, so the change cannot reach them.

  Verified clean branch-wide: loader's Bundle(for:) resolves correctly for the SHIPPING app on both
  platforms (two native targets, both synchronized roots, tests app-hosted); generated files are NOT
  stale (92ebb6b changed TaxBracket.CodingKeys AND regenerated in the same commit; no generation
  input changed after); xcodeproj untouched across all 23 commits; no existing test's expected value
  modified anywhere; all 13 top-level keys guarded against encode-side loss.

  ** REVIEWER CORRECTED THE CONTROLLER on the legacy-fallback safety comment. I scoped it to
     "tax year 2026". WRONG EVENT. The thing that invalidates the proof is PHASE 5, which corrects
     wrong tax values in the JSON for that SAME year. From the first correction, configs2026Legacy
     holds known-wrong data for those states and the release fallback would serve it - and the
     equivalence gate, the only tripwire, is exactly what Phase 5 retires. Now documented as:
     REMOVE OR RE-POINT the fallback at the first Phase 5 correction, do not merely re-scope. **

  IMPORTANT x2, both fixed in 9a7df5b:
    (1) productionPathUsesJSON claimed "the loader populates verification metadata; the legacy table
        cannot". FALSE - all 51 files carry .unverified and legacy DEFAULTS to .unverified, so it
        compared .unverified == .unverified. Reverting configs2026 to legacy would have kept the
        whole suite green. This is INHERENT, not a fixable assertion: the gate's purpose is proving
        the two indistinguishable by value. Test comment now honest; added a real assertion that the
        loader ran and did not fall back.
    (2) The Phase 5 scoping clause above.
  Minor fixed: legacyFallbackDidNotFireInNormalOperation could pass vacuously under parallel
    execution without forcing the static-let initializer. Now forces it.
  Minor noted, not a defect: 81 added lines contain em dashes, ALL in commit 322e318 (rescued
    memory docs authored earlier on the article branch), ZERO in any Swift or JSON file.

## PHASE 1 COMPLETE. 23 commits off main. Working tree clean.
  FINAL VERIFICATION (controller-run, correct tree, after all review fixes):
    macOS: 1,605 Swift Testing in 271 suites + 503 XCTest, 0 failures, ** TEST SUCCEEDED **
    iOS:   ** BUILD SUCCEEDED **, all 51 statetax-2026-*.json confirmed in the built .app
  Phase start baseline was 1,570 + 503. Net +35 tests, all additive, ZERO expected values changed.
  BEHAVIOR-INERT CONTRACT HELD: the only two behavior changes are the deliberate ones (no more
  California substitution for a missing state; no more silent empty dictionary on bundle failure).
