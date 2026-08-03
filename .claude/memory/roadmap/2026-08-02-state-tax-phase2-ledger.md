# State Tax Phase 2: Safety Net and Golden-Scenario Harness - SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-02-state-tax-phase2-safety-net.md
Spec: docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md
Worktree: .worktrees/state-tax-phase2 (branch feature/state-tax-phase2, off main @ 7e25516)

NOTE: Phase 1's ledger is preserved at .claude/memory/roadmap/2026-08-02-state-tax-phase1-ledger.md.
A DIFFERENT ledger for the completed V2.3 work lives in the main repo's .superpowers/sdd/.
Do not confuse the three.

Baseline verified before Task 1: 1,605 Swift Testing in 271 suites + 503 XCTest, 0 failures,
plus a clean iOS build with all 51 statetax-2026-*.json confirmed in the .app bundle.

## Contract for every task in this phase
Phase 2 CORRECTS NOTHING and changes NO computed number. It builds the machinery Phase 4 will use
and proves it on a pilot set. Any moved tax value is a defect in this phase.

## Known cross-path divergences (found by inspection BEFORE any test was written)
Detail: .claude/memory/roadmap/2026-08-02-cross-path-state-tax-divergences.md
  1. I2: ProjectionEngine.computeStateTax omits postExemptionDeduction (ProjectionEngine.swift:1622-1634),
     so NJ's per-filer personal exemptions vanish in Multi-Year.
  2. NEW: .rmd IncomeSource rows are UNGATED while scenarioRetirementDistributions is gated at 59.5
     (TaxCalculationEngine.swift:582-585). Multi-year synthesizes .rmd rows, so a 55-year-old with
     IRA withdrawals gets the state IRA exemption in Multi-Year and is denied it in Scenarios.
Both are PINNED as expected in Phase 2, fixed in Phase 5. Fixing them moves numbers.

## Gate correction made before execution
The spec's Phase 2 gate said "harness runs green against confirmed-correct jurisdictions
(PA, IL, MS, CA, NJ)". That conflated CONFIG-correctness with PATH-agreement. NJ is config-correct
and fails the cross-path invariant because of I2. Corrected gate, matching Phase 4's shape: the
invariant's first run is a DISCOVERY exercise and its failures are the deliverable. A green first
run would be the suspicious outcome.

## Plan self-review caught three defects in the plan itself (all fixed pre-execution)
  - a fatalError placeholder where I punted on reading MultiYearStaticInputs (40+ properties, 20 required)
  - a guessed LeverAction case: wrote .withdrawal(amount:owner:), real one is .traditionalWithdrawal(amount:)
  - 8 em dashes, violating the plan's own Global Constraints
  - AND the NJ fixture's $280 expected value was ENGINE-DERIVED (a reviewer re-implemented
    applyRetirementExemptions to check something else), so using it would assert only that the
    engine agrees with itself. Plan now requires hand-derivation from NJ-1040 or BLOCKED.

## Tasks
(none complete yet)
Task 1: complete (commit a867317, base 82ef266; reviewed, spec OK, Approved with findings)
  Year-keyed config access. Pure addition, 71 insertions, ZERO deletions, so Phase 1's hardened
  config(for:) is untouched. pbxproj untouched, no em dashes, .scratch not committed.
  Scoped suite StateTaxJSONLoaderTests: 16 tests, 0 failures. Reviewer RE-RAN it independently
  rather than trusting the report, and got matching numbers.
  Reviewer verified by tracing, not reading: the NSLock is held across the entire check-load-store
  sequence so @unchecked Sendable is justified and there is no read-during-mutation path; the
  byte-comparison test is a GENUINE cross-check (two independent decode paths over a struct, not
  self-comparison); cross-year contamination is structurally impossible (dictionary keyed by year).

  ** IMPORTANT, CARRIED INTO TASK 2 (reviewer's catch, forward-looking):
     `configs(for:)` is ALL-OR-NOTHING PER YEAR, not per-state. `load(taxYear:)` throws on the FIRST
     missing or malformed file and YearCache converts that throw to [:]. So a future 2027 shipping
     50 valid files and 1 broken one returns EMPTY for all 51 states, and every state (including the
     50 good ones) silently falls through to the 2026 fallback.
     Contrast: `configs2026` uses `resolveConfigs`, which is PER-STATE and falls back state-by-state
     without losing good data.
     This conflates two different meanings under one signal: "this year does not exist" versus
     "this year exists but one file broke". Task 2's StateTaxYearAvailability makes DISCLOSURE
     decisions off `configs(for:).isEmpty`, so it would tell a user "assumes 2026 law held constant"
     when in fact 2027 data exists and is broken. Inert today (2026 is proven complete by the Phase 1
     gate) but the disclosure would be actively misleading the first time a year is partial. **
  Minor: configs2026 and configs(for: 2026) are two independent decode paths holding two complete
    copies of the same data. Harmless, and it is precisely why the equivalence test is real rather
    than a self-comparison, but it is duplicated work rather than shared.
Task 2: complete (commit f6f1a65, base a867317; reviewed, spec OK, Approved with findings)
  StateTaxYearAvailability: latestBundledTaxYear, isExtrapolated, isBundledButUnloadable, disclosure.
  Purely additive, 2 files, 159 insertions, no existing file touched. Scoped suite 23/23 green
  (16 pre-existing + 7 new); reviewer re-ran it independently and re-derived the test count from
  the diff rather than trusting the report.

  ** IMPLEMENTER IMPROVED ON MY INSTRUCTION: I suggested probing ONE known file (CA) to answer
     "is this year bundled". They probe ALL 51 filenames instead, which is strictly better - my
     CA-only version would itself have misreported if CA were the missing file. Verified empirically
     by deleting a file and restoring it. **

  Reviewer confirmed by tracing: existence probe uses Bundle.url only, ZERO decodes (the brief's
    version would have done up to 81 full decodes of 51 files each); latestBundledTaxYear is a
    static let so the reverse walk happens once per process; adding statetax-2027-*.json with no
    code change moves it to 2027 automatically; the disclosure names both years and explicitly
    disclaims forecasting future legislation.

  ** IMPORTANT - CORRECTION TO THE TASK 2 REPORT (reasoning error, NOT a code defect).
     The report's Concerns section claims isBundledButUnloadable(taxYear:) creates a NEW call path
     to StateTaxDataLoader.configs2026's debug assertionFailure trap. IT DOES NOT.
     Traced chain: isBundledButUnloadable -> configs(for:) -> YearCache.configs -> load(taxYear:),
     which THROWS and is converted to [:] by `try?`. It never touches configs2026 or resolveConfigs.
     configs2026's trap is reachable only via the pre-existing StateTaxData.config(for:) fallback,
     which Task 2 neither calls nor changes. The crash the implementer saw when deleting a file came
     from a DIFFERENT pre-existing test in the same process forcing configs2026.
     RECORDED HERE BECAUSE PHASE 6 WOULD OTHERWISE GUARD THE WRONG CALL SITE. **

  Minor, forward-looking, unreachable today (only 2026 is bundled), relevant when a 2nd year lands:
    (a) CONTIGUITY GAP: isExtrapolated treats every year <= latestBundledTaxYear as backed by real
        data, but only checks the single MAX year. If 2027 were bundled while 2026's files went
        missing, isExtrapolated(2026) and isBundledButUnloadable(2026) would BOTH be false and
        disclosure(2026) would return nil, silently implying real 2026 law backs the figure.
    (b) probeRange boundary: a bundled-but-partial year outside 2020...2100 could report
        isExtrapolated AND isBundledButUnloadable simultaneously, the one combination the code
        comments say must never occur.
    (c) The taxYear: overload's broken-bundle path is not tested end-to-end (only via the pure-logic
        overload and a manual, uncommitted experiment). Defensible: shipping a deliberately
        corrupted fixture has its own costs.
Task 3: complete (commits 864262b + d5c13c2, base f6f1a65; first pass NEEDS WORK, RE-REVIEWED CLEAN)
  Golden scenario fixture format + loader + PA/IL/MS pilot fixtures. Test bundle only, never
  Bundle.main. Loader assertions proven to discriminate by deliberate breakage.
  Implementer improved on the brief: renamed totalIncome -> federalAGI to match the engine's real
  parameter vocabulary (ProjectionEngine.computeStateTax names that value federalAGI). Exactly the
  "catch it at 3 files, not 51" principle.

  ** TWO CRITICAL FINDINGS, BOTH MINE. I wrote the citations into the plan's fixture JSON and the
     implementer transcribed them faithfully.
       MS: I cited 27-7-15(4)(j), which is COMBAT-ZONE HAZARDOUS DUTY PAY for Armed Forces members.
           Retirement income is (4)(k) government / (4)(l) private. This fixture needs (4)(l).
       IL: I cited Schedule M. The retirement subtraction is taken on IL-1040 LINE 5, and Illinois
           DOR explicitly warns that using Schedule M causes a DOUBLE SUBTRACTION and triggers a
           notice. My citation pointed a reader at the one place that would be wrong.
     Both expected values (0) were numerically CORRECT. The evidence for them was false, written
     with the same confidence as the PA citation that turned out accurate. A reader following my
     citations to check the work would have found nothing supporting it.
     This is the exact failure golden scenarios exist to prevent: the source field is what makes
     "derived from the state's own form, not from our engine" auditable rather than trust-me. **

  STRUCTURAL FIX ADOPTED (reviewer's recommendation, taken NOW at 3 files rather than after 51
  inherit the weakness): added a `sourceURL` field alongside the citation string, asserted non-empty
  and https-prefixed. A citation STRING alone made this class of error invisible to review.
  Assertions proven to discriminate INDIVIDUALLY: broke sourceURL to "" (both isEmpty and hasPrefix
  fired), then to an http:// URL (only hasPrefix fired).

  Implementer verified each corrected citation INDEPENDENTLY rather than on my authority, after I
  told them I had been confidently wrong twice: fetched FindLaw + Justia for MS (agreeing), and
  tax.illinois.gov's and pa.gov's own pages for IL/PA. Disclosed honestly what they could NOT fetch
  (MS DOR Title 35 returned 403; IL/PA official PDFs would not decode as text).
  Verified by me: expectedStateTax does not appear in the fix diff at all, so no value moved.

  RE-REVIEW verdict: spec OK, Approved. Reviewer RE-DERIVED both corrections from primary sources
  rather than trusting my correction or the implementer's account. IL Line 5 confirmed verbatim from
  tax.illinois.gov. MS (4)(l) confirmed verbatim from FindLaw, AND the reviewer found an
  authoritative source neither of us cited (dor.ms.gov's own FAQ: "Pensions, IRA withdrawals, and
  401(k) distributions are all exempt, once you have met the retirement plan's requirements"), which
  closes the traditional-IRA gap better than the statute text alone.

  ** THE LIMIT OF THE STRUCTURAL FIX, demonstrated concretely and now in the SPEC (commit 25c0f76):
     sourceURL can only prove a string is SHAPED like a resolvable link. It can never prove the
     link's content supports the sentence beside it. The reviewer proved this on our own work: the
     IL sourceURL is a good, resolvable, on-topic DOR page, yet one clause of the adjacent source
     text (the double-subtraction/DOR-notice warning) is NOT on that page.
     #expect cannot do semantic matching, so Phase 4 needs a PROCESS control instead: the fixture
     author AND the reviewer must each state they personally opened every sourceURL and checked
     EVERY CLAUSE of source against it. Added to the spec beside the golden-scenario layer. **

  Minor, non-blocking, for whenever these files are next touched:
    (a) MS (4)(l) says "private retirement system or plan of which the recipient was a member during
        employment", which is textually silent on a personal traditional IRA. Result is still right;
        add the DOR FAQ as a second citation to bridge it.
    (b) IL's double-subtraction clause is accurate but sourced elsewhere than its own sourceURL.
    (c) PA fixture lost its trailing newline. Cosmetic, valid JSON.
Task 4: complete (commits 2b3e2d7 + comment fix; reviewed, spec OK, Approved with findings)
  Single-year golden runner. 48 lines, one new file, zero fixtures or config touched.
  PA/IL/MS all match their published forms exactly (0.0 vs 0.0).

  ** REVIEWER DID THE CORRECT MUTATION TEST ITSELF, and it mattered.
     The implementer mutated the FIXTURE (expectedStateTax 0 -> 12345), which only proves the
     #expect comparison is wired up. A REAL defect moves the ENGINE's side, not the fixture's.
     The reviewer mutated PA's actual production config (pensionExemption.kind full -> none),
     got EXIT=65 with engine 1228.0 vs form 0.0, then iraWithdrawalExemption -> none, engine 1535.0
     vs form 0.0, restored, EXIT=0. So the test DOES catch engine regressions.
     It works because every fixture is built so federalAGI == pensionIncome + iraWithdrawals, making
     any exemption failure produce an obviously nonzero result.
     LESSON FOR ALL LATER TASKS: when claiming a test discriminates, mutate the CODE UNDER TEST,
     not the expectation. **

  ** IMPORTANT, FIXED, AND IT CHANGES TASK 6: the runner's doc comment claimed it drives "the same
     entry point the Scenarios screen uses". It does not. The real screen path is
     DataManager.scenarioStateTax (:2055) -> calculateStateTaxFromGross (:586) -> wrapper (:544) ->
     TaxCalculationEngine.calculateStateTax. The runner skips all three DataManager layers, so it
     also skips localIncomeTaxRate and postExemptionDeduction forwarding and the state-standard-
     deduction / above-the-line reconciliation.
     Numerically inert for PA/IL/MS (all stateDeduction .none, none is NJ, no contribution fields).
     NOT inert for Task 6: if the single-year side ALSO omits postExemptionDeduction, then both
     sides omit it, NJ's I2 divergence VANISHES, and Task 6's pinned "they still differ" test would
     fail for the wrong reason. Task 6 MUST supply postExemptionDeduction on the single-year side. **
  Minor: all three fixtures are age 67, single, so MFJ, per-individual cap doubling and spouse-age
    gating are entirely unexercised. Fold into Phase 4's fixture expansion.
Task 5: complete (commit 9faa066, base 4cca7f7; reviewed, spec OK, Approved with findings)
  Multi-year golden runner. One new file, 85 lines. No fixture, config, or engine touched.
  baseYear pinned to 2026 and confirmed LOAD-BEARING (drives sortedYears, the SS claim-year
  calculation, and ExpenseResolution's CPI anchor), not a cosmetic parameter.
  Config-mutation proof done the RIGHT way: flipped PA's production pensionExemption.kind
  full -> none, engine $1,228.00 vs form $0.00, restored, green.

  ** THE 90,000 AGI CORRESPONDENCE IS GENUINE, NOT ENGINEERED. The reviewer distrusted an exact
     first-attempt match (correctly) and traced it independently through five projection steps:
     SS is exactly 0 via two independent guards (benefit 0 AND claim age 70 unreached at 67), not
     merely small; expenses exactly 0; the whole $50k withdrawal sweeps into a same-year zero-basis
     taxable bucket; federalAGI = 40,000 pension + 50,000 withdrawal = 90,000 exactly; and the
     tax-funding cascade never fires a gross-up because the federal bill is covered by that
     zero-gain bucket. The fixture format has NO fields for SS or expenses, so zeroing them was the
     only non-arbitrary choice available, not a knob turned to hit a target. **

  Cross-path corroboration, judged NON-circular: Task 4's reviewer independently mutated PA's config
  on the SINGLE-year path and got $1,228.00; Task 5's implementer did the identical mutation on the
  MULTI-year path and got the same $1,228.00 (40,000 x 3.07%, arithmetically exact). Two separately
  invoked paths landing on a cents-precise figure from one production JSON change.
  Caveat the reviewer attached: PA is flat-rate with a binary exemption, so this validates arithmetic
  agreement, not bracket or phase-out logic.

  ** IMPORTANT, MUST BE READ BEFORE TASK 6: the multi-year runner BYPASSES OptimizationEngine and
     MultiYearTaxStrategyEngine entirely. It calls ProjectionEngine().project() directly with
     hand-pinned .traditionalWithdrawal AND .rothConversion actions. But OptimizationEngine.swift:
     410-416 states in its own comment that withdrawal amounts are NEVER pinned in V2.0, and no
     production caller anywhere constructs that lever pair. The Multi-Year SCREEN's output comes from
     MultiYearTaxStrategyEngine.compute() -> OptimizationEngine.optimize().
     So this test proves the shared low-level TAX PRIMITIVE agrees with the state's form under a
     lever combination the real optimizer never produces. It does NOT prove the Multi-Year screen's
     recommended output agrees.
     This is the direct analogue of Task 4's DataManager finding but ONE LAYER DEEPER: it skips
     DECISION-MAKING, not just data plumbing. **

  CONSEQUENCE FOR TASK 6, stated plainly: NEITHER runner is its real screen. The single-year runner
  skips DataManager's three layers; the multi-year runner skips the optimizer. So Task 6's invariant
  compares TWO ENGINE INVOCATIONS, not two screens. It is still worth building - it is exactly what
  isolates the shared primitive from the callers - but it must not be described as "the two screens
  agree", and Phase 4 must not read a green run that way either.
  Minor: actionsPerYear supplies only the baseYear key (production populates every horizon year);
    verified inert for year 1. And GoldenScenario.taxableSocialSecurity is unused by the multi-year
    runner with no defined translation, harmless while all pilot fixtures have it at 0.
Task 6: fix IN FLIGHT (commit b0abd9a, base 9faa066; reviewed on opus, verdict NEEDS WORK)
  Cross-path invariant + NJ fixture. The analysis under this task was judged the best in the phase:
  the reviewer independently reproduced the $171.89 confounding figure digit for digit and confirmed
  the $252.00 NJ derivation to the cent against nj.gov primary sources it fetched itself.

  ** CRITICAL: THE HAND-DERIVED $252.00 WAS ASSERTED BY NOTHING.
     NJ appears in NONE of the three pilot lists (loader, single-year, multi-year are all
     ["PA","IL","MS"]). The only suite loading NJ is cross-path, which compares single to multi and
     never reads expectedStateTax. So the form-derived value, its source AND its sourceURL were all
     decoded-but-unused, and the Phase 2 exit criterion naming NJ was enforced by nothing.
     PROVEN BY MUTATION: expectedStateTax set to 99999.0, all four golden suites ran, EXIT=0.
     This is the same failure this phase keeps hitting in new costumes: something that LOOKS like
     verification and provides none. The clause-by-clause URL discipline added after Task 3 worked
     here (it caught two more citation errors on its first real outing) but it cannot catch a
     fixture nobody runs. **

  ** THE NJ GAP DECOMPOSES INTO THREE TERMS AND I2 IS THE SMALLEST. Closes to the cent:
       $210.00  federalAGI 95,000 vs component sum 80,000. Multi-year DERIVES AGI from components
                (ProjectionEngine.swift:680-690), so $15,000 of fixture income never reaches it.
                This is a FIXTURE-AUTHORING ARTIFACT I introduced, and it is 7.5x I2.
       $130.40  Step-7 gross-up withdrawal of $9,314.62 injected as phantom income.
        $28.00  I2 itself, the missing $2,000 NJ personal exemption.
       252.00 - 210.00 + 130.40 + 28.00 = 200.40, exact.
     Task 4's reviewer had already identified federalAGI == pension + withdrawals as LOAD-BEARING
     for discrimination in the PA/IL/MS fixtures. I broke that invariant in the one fixture where
     it mattered. **

  ** THE PINNED TEST COULD NOT FAIL FOR THE RIGHT REASON. Its intent was to go red when Phase 5
     fixes I2. Reviewer reproduced the experiment: with I2 fixed, multi-year moves to $171.89, so
     abs(252.00 - 171.89) = 80.11 >= 0.01 and the test KEEPS PASSING. It would also keep passing if
     multi-year regressed to $50,000. An inequality tripwire stays armed regardless; pin OBSERVED
     VALUES instead. **

  Two more citation defects, caught by the reviewer-opens-the-URL control:
    Worksheet D belongs to line 28b (Other Retirement Income Exclusion), not 28a, whose amount comes
      from the "Determining Your Exclusion Amount" chart. The repo ALREADY had this right at
      NJOtherExclusionAndExemptionsTests.swift:7. Error originated in my brief.
    Line 43 uses the Tax Table below $100,000 taxable; the citation named the Rate Schedules, which
      the booklet forbids at this income. Values coincide at $252, citation misdirects.

  CORRECTION TO THE RECORD: the $280 placeholder is the SINGLE-year figure with
  postExemptionDeduction omitted, NOT "the multi-year I2-buggy answer". Multi-year produces $200.40
  and never produces $280. I repeated the wrong attribution upstream.

## PHASE 4 BLOCKERS, from the Task 6 review. Phase 4 must not start until these are settled.
  1. GIVE THE MULTI-YEAR RUNNER A FUNDING SOURCE. Step 7's gross-up injected $9,314.62 of phantom
     income into the only nonzero fixture in the pilot. EVERY Phase 4 fixture with tax due inherits
     it. Either set taxable: high enough that taxFundingWithdrawal == 0, or use .paidFromOutsideMoney.
     Cross-path agreement is only meaningful at dW == 0, and no pilot fixture satisfies that.
  2. REQUIRE federalAGI == pensionIncome + iraWithdrawals + taxableSocialSecurity in fixtures, or
     teach the multi-year runner to honor federalAGI. Otherwise every fixture feeds two different
     incomes to the two paths and authors read the gap as an engine bug.
  3. EVERY FIXTURE MUST BE IN A PILOT LIST. Finding 1 is a one-line bug class that replicates 51x.
  4. Pin observed values, not inequalities, for known divergences.
  5. Point sourceURL at instruction booklets, and hold the clause-by-clause discipline.
  Items 1 and 2 together account for $340.40 of the NJ gap in opposing directions; the real engine
  divergence under all that noise is $28.00.

Task 6: complete (commits b0abd9a + fix 1b8b39c; first pass NEEDS WORK on opus, all findings closed)
  CRITICAL CLOSED AND VERIFIED: NJ added to the loader and single-year pilots (NOT multi-year, so
  the 200.40 vs 42.00 gap stays visible as the Phase 5 signal without turning this phase red).
  Setting expectedStateTax to 99999.0 now produces EXIT=65 with a named failure; before the fix it
  left all four suites GREEN.
  NJ re-derived to $42.00 with full arithmetic: AGI 80,000 -> line 28a exclusion min(80,000, 75,000)
  = 75,000 -> line 29 = 5,000 -> minus 2,000 exemptions (regular + senior 65+) -> taxable 3,000 ->
  2025 NJ-1040 TAX TABLE row 3,000-3,050 = $42.00. Verified three ways (table row, formula, engine).
  Fixture federalAGI set to 80,000 so it equals its components, REMOVING the $210 artifact I had
  introduced. Gap decomposition is now two real terms and closes exactly:
    42.00 + 129.89 (tax-funding cascade) + 28.51 (I2) = 200.40
  Pinned test now pins OBSERVED VALUES (42.0 and 200.40469973890345) instead of an inequality, so it
  fails the moment either side moves rather than staying armed regardless.
  Citations corrected: Worksheet D -> line 28b, tax read from the Tax Table not the Rate Schedules,
  sourceURL repointed at the instruction booklet.

  ** THE IMPLEMENTER CORRECTED ME AGAIN, THIRD TIME THIS SESSION ON A CITATION FACT.
     I instructed the citation to state that NJ's 2025 instructions are not published. They ARE.
     The agent downloaded them, verified, and cited 2025 with evidence rather than repeating my
     false claim. My three citation errors this session: MS combat-pay paragraph, IL Schedule M,
     and this. All three were stated with full confidence. **

  Concern carried forward: sourceURL uses NJ's ROLLING current/1040i.pdf path (no stable 2025
  archive exists yet, checked, 404). It will describe 2026 content once NJ rolls it over, so it
  needs re-verification or an archival URL when one appears.

## PHASE 2 COMPLETE AND MERGED to main @ 7c6d4e6 (merge commit, 13 commits).
  Final suite on the branch: 1,620 Swift Testing in 275 suites + 503 XCTest, 0 failures, right tree.
  Phase 2 start baseline was 1,605 + 503. Net +15 tests, all additive. No engine or config file was
  modified in ANY Phase 2 commit; no computed tax value changed.
