# State Tax Phase 3b: per-source exemptions — SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-03-state-tax-phase3b-per-source.md
Spec: docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
Worktree: .worktrees/state-tax-phase3b (branch feature/state-tax-phase3b), off main @ b138a62
Predecessor ledger: .claude/memory/roadmap/2026-08-03-state-tax-phase3a-ledger.md. READ IT.

## Baseline: NOT re-run, deliberately
b138a62 is the Phase 3a merge commit, whose gate verified 1,657 Swift Testing in 278 suites
+ 503 XCTest, 0 failures, iOS BUILD SUCCEEDED, all 51 JSON bundled. This branch is off that
exact commit with only doc files added, so re-running a five-minute suite to confirm what was
confirmed an hour earlier is the kind of waste the efficiency protocol exists to stop.

## Design decisions (John, 2026-08-03)
1. Classification lives on BOTH IncomeSource and Account, sharing one domain model.
2. TWO internal dimensions (PlanStructure x PlanSource), presented as ONE flat picker.
3. Infer what is knowable; prompt only for pensions, where government-vs-private cannot be inferred.
4. Mechanism PLUS the New York correction. New York is the only jurisdiction whose numbers move.
5. Hawaii disclosed, not modelled.
6. Multi-year: the PENSION input widens; AccountSnapshot does NOT.

## John's review caught three blockers in the first plan draft, all closed before execution
1. Task 3 activated owner attribution despite the New-York-only promise. Now inert; components
   carry owner for a LATER phase. Bundling source classification with owner correction would have
   destroyed the ability to prove New York's rule caused any movement.
2. THE MULTI-YEAR PATH WAS ABSENT. Investigation found it worse than he framed: ProjectionEngine
   receives scalars throughout (two pension numbers, a nine-field AccountSnapshot) and SYNTHESISES
   income rows from them, so NO classification of any kind reaches the projection. Left alone,
   Alan would see the uncapped exclusion on Scenarios and the capped one in Multi-Year: a second
   deliberate cross-path divergence. New Task 5 widens the pension inputs only.
3. Shared caps were not designed. Rule matching is now a PARTITION that runs BEFORE the existing
   cap machinery, never a per-component evaluation, with five derived tests. This codebase already
   shipped the per-component variant of that bug once, which is why pensionAndIRAShareSingleCap
   exists.

He also caught six smaller items: an invalid Task 2 mutation (deleting a non-optional decode
fallback is a compile error, which proves nothing), missing tolerance and debug-vs-release
semantics on the sum invariant, fixture determinism, vague CPA file paths, the New York limitation
needing to appear wherever NY tax is COMPUTED rather than only for residents, and two inaccurate
self-review claims. The second of those exposed a real gap: Task 1 had no typed decode error.

## The defect the design revision removed, worth remembering
The first design had ONE `.governmentPension` case. Offered under that plain-English label it
would have handed New York's uncapped IT-201 Line 26 exclusion to a California or Illinois public
pension held by a NY resident. Line 26 covers NYS, NY localities, named NY authorities and the US
government ONLY. The error direction is UNDER-taxation, and no planned fixture contained an
out-of-state public pension, so nothing would have caught it. Task 4 Step 1 case 4 is its
permanent regression test.

## CONTROLLER PROCESS NOTE
My Bash cwd resets to the MAIN repo between calls, and chained `cd X && ...` does not protect a
later separate call. This bit me four times in this session, once committing this very ledger to
the article branch (reset, single unpushed file, no damage). Use absolute paths for file writes
rather than relying on cwd.

## Tasks
(none complete yet)
Task 1: complete (commit 4d829ef). PlanStructure + PlanSource + PerSourceExemptionRule + inference.
  18 tests. Implementer VERIFIED rather than assumed on the typed decode error: Swift's synthesised
  Codable for String-backed enums already throws a dataCorrupted error naming the type and the bad
  value, so no hand-written conformance was needed and StateTaxCodable.swift stayed untouched. It
  reported that as a deliberate deviation from the brief's file list rather than silently skipping
  the step. Added a third negative matching case (governmentUnspecified) beyond the two specified.

Task 2: complete (commits 0ead148 fixture + 6f8ef88 implementation + fix 53ac0f8). Reviewed on opus.
  Suite 1,681 ST in 280 suites + 503 XCTest. Baseline held 1,020. Legacy .rothConversion migration
  held. THE HIGHEST-RISK TASK IN THE PHASE, and it came out clean.

  ** ORDERING DISCIPLINE, done right and worth copying: the implementer committed the captured
     fixture as its OWN commit (0ead148) touching neither model file, BEFORE changing anything.
     That makes "this is a genuine pre-change blob" provable from git history rather than asserted
     in a report. The reviewer then verified the content independently: no planStructure or
     planSource key on any record, and neither symbol existed in any production file at 4d829ef.
     This is the exact discipline the V2.3 branch lacked, where migration tests wrote legacy VALUES
     under the NEW key and every per-task review passed while an "external" tax-funding scenario
     silently became account-funded. **

  ** THE FIX THAT MATTERED MOST, from the review: a single unrecognised classification string in
     ONE income row would have discarded EVERY stored income source, because PersistenceManager
     .loadAll wraps its decode in `try?`. Demonstrated: five rows in, zero rows out. The spec now
     distinguishes the two data sources deliberately (§6 plus the paragraph above §3.7): shipped
     state JSON keeps strict throw, because a silent default there turns a corrupt config into a
     plausible wrong tax; USER SAVES fall back to .unknown with an observable diagnostic flag,
     because destroying real user data to guard against a value the app has no rule for anyway is
     the wrong trade. Trigger is real once Task 6 ships the picker: a later phase adding a
     PlanSource case produces saves an older build cannot read. **

  Reviewer also verified, beyond what was asked: a full loadAll -> saveAll -> loadAll -> saveAll ->
    loadAll cycle is a FIXED POINT (identical tax across three generations, identical canonical
    blobs between generations 2 and 3, every pre-3b key preserved). And that replacing IRAAccount's
    synthesised Codable with a hand-written one kept all 14 stored properties with encodeIfPresent
    on exactly the six optionals, which is where this task could have quietly orphaned user data.
  Minor fixed: four em dashes in added lines, AND the report claimed there were none. In a phase
    whose method is evidence before assertion, the false verification claim was the worse half.
  Minor fixed: the migration gate called JSONDecoder directly rather than going through
    PersistenceManager.loadAll. Accurate today, brittle tomorrow. Re-pointed at the real load path.

  ** CARRIED INTO TASK 4 AS STEP 5a: computedStateTaxUnchangedByMigration PASSED under a mutation
     that made every decoded classification wrong, because nothing consumes the fields yet. The
     report presented it as the assertion proving the migration promise; it proves only that decode
     did not corrupt the OTHER fields. Once New York's rule consumes those fields it must be
     re-pointed at a New York scenario and re-proven by mutation. **
  Open, recorded not fixed: DataManager() in the test target reads UserDefaults.standard, so a
    persistence test can pick up real saved data from the developer's machine. Pre-existing.

Task 3: complete (commit 34220b8). Reviewed on opus: spec OK, Approved with findings.
  distributionComponents added BESIDE the 42-call-site scalar, not replacing it. Pooled at one
  line in both engine (:644-648) and mirror (:834-839). Suite 1,691 ST in 282 suites + 503 XCTest.
  Baseline held 1,020. Mirror got its configOverride seam; reviewer read both side by side and
  found no drift, unlike Phase 3a where five changes missed the mirror.

  ** IMPORTANT, FOLDED INTO TASK 4 RATHER THAN A SEPARATE FIX CYCLE: pooling is UNGUARDED.
     The reviewer mutated the engine and mirror to apply the exemption PER COMPONENT instead of
     once to the pooled figure, and ALL 10 of Task 3's tests passed, AND the 1,020-value frozen
     baseline passed. Only a throwaway probe caught it. Reason: every multi-component test uses
     iraWithdrawalExemption .full, where excludedAmount returns eligibleIncome unchanged, so
     summing per component and pooling give identical numbers.
     Failure scenario from the probe: .partial(maxExempt: 20_000), flat 10%, single, age 65,
     income 60,000, two components of 15,000. Correct 4,000; per-component capping gives 3,000.
     That is the historical New York double-20,000 bug reproduced exactly. ~20 lines to close:
     one capped-config two-component test per surface. Task 4 Step 4 needs this guard to already
     exist, since Task 4 is the task that reaches for the component array. **

  Minor, also folded into Task 4: three comments in RetirementDistributionComponent.swift:78-80,
    TaxCalculationEngine.swift:352 and :639-641, DataManager.swift:828-830 say the nil path
    "synthesises one .unknown component". It does NOT; it short-circuits to the scalar
    (RetirementDistributionComponent.swift:95). Numerically identical and safer, but Task 4 must
    not assume nil hands it a component list to run rule matching over.
  Minor, also folded: sumInvariantBoundary proves only that the tolerance lies somewhere in
    [0.005, 0.02). Name the tolerance as a constant and assert its value.
  Minor, RECORDED NOT FIXED: the release fallback and its flag are executed by no test in any
    configuration, because assertionFailure traps first in Debug and the test target does not link
    in Release (pre-existing SwiftUI opaque-return-type symbols in ThresholdMapChartViewTests).
    The reviewer judged the strategy defensible but corrected the report's stated reason: the
    sibling flag from Task 1 IS driven true by tests, so "avoid poisoning a shared static" does not
    hold; the real reason is unreachability behind the trap. A trap-injection seam
    (onViolation: (String) -> Void = { assertionFailure($0) }) would fix it if the invariant ever
    gains teeth. Residual risk low: the only unproven statement is a diagnostic affecting no value.
  Implementer honesty worth noting: its first boundary test used an exact one-cent literal, float
    error pushed it outside tolerance, and it genuinely tripped the trap and crashed the test
    process. It redesigned around whole-dollar components with a half-cent scalar offset and
    reported the crash as a real finding rather than quietly working around it.
  For Task 5: DataManager's private applyRetirementExemptions wrapper at :674 forwards no
    components and is pinned to nil.

Task 4: complete (commits bbf631d + fix 3bfab67). Reviewed on opus, Approved with findings, all fixed.
  NEW YORK'S IT-201 LINE 26 UNCAPPED GOVERNMENT PENSION EXCLUSION SHIPS. Alan Levy's confirmed bug.
  Only statetax-2026-NY.json changed among the 51 files, 14 insertions, 0 deletions.
  Suite 1,703 ST in 283 suites + 503 XCTest.

  ** THE RELEASE-PLANNING FACT: the New York fix is NOT REACHABLE BY ANY USER until Task 6 ships
     the picker. Verified three independent ways: no view file references planStructure or
     planSource; every pension row a user can create infers to .unknown/.unknown via
     IncomeSource.init; and no production caller passes distributionComponents non-nil. A New York
     government-pension holder computes exactly the same overstated tax after this commit as
     before. Both the Steve and Alan emails promise fixes "in the next release", so TASK 6 IS
     LOAD-BEARING FOR A WRITTEN PROMISE, not optional polish. **

  ** THE PLAN PREDICTED THE BASELINE WOULD MOVE. IT DID NOT, and that is correct. Every baseline
     scenario builds .pension rows with no classification, which infer to .unknown, which New
     York's rule never matches. The fixture came back byte-identical and was NOT regenerated.
     Corroborated empirically: the baseline stayed green under two independent mutations of New
     York's rule, which it could not have if any of the 1,020 entries touched it. **

  ** THE ROOT-CAUSE FINDING: PerSourceExemptionRule EXISTED TWICE. Task 2 shipped a top-level type
     with seven matching tests; Task 4 declared a nested duplicate and re-implemented the predicate
     as matchedPerSourceRule. Production used the nested one. So seven tests guarded a type nothing
     shipped, which is WHY blanking New York's matchStructures left all 43 tests across six suites
     green. Failure scenario that would have shipped: a New York state employee's 403(b)
     (definedContribution + nyStateOrLocal) silently receiving the uncapped Line 26 exclusion
     instead of the 20,000 cap. Fixed by deleting the nested copy AND making matchedPerSourceRule
     DELEGATE to the tested predicate, so unifying the type made the tested path the shipping path
     rather than leaving two same-shaped implementations. **

  Also fixed: golden case 3 used planSource governmentUnspecified, which fails matchSources and so
    never reached the structure gate; now nyStateOrLocal. Both cap tests (engine :169 and mirror
    :196) SATURATED the cap either way (unmatched pool 25,000 against a 20,000 cap, so min() gave
    20,000 under both correct and mutated code); unmatched pool dropped below 20,000 and income
    raised to 115,000 so neither the cap's min() nor the taxable-income zero floor masks it.
  Citation defects fixed, the Phase 2 class recurring: golden case 1 quoted "regardless of your
    age" against it201i.htm, where that phrase appears only in the Line 29 Beneficiaries paragraph,
    a different rule; the sentence is on information_for_seniors.htm. Case 3 claimed flatly that a
    403(b) is a salary-reduction supplemental plan, but the form scopes the exclusion to "contributions
    YOU MADE", so it does not hold for an employer-funded portion.
  Minor fixed: GoldenScenarioSingleYearTests:44 claimed New York is the first pilot state with a
    nonzero stateDeduction. Mississippi also has one; its fixture is inert only because it expects 0.

## REMAINING: Task 5 (multi-year pension classification), Task 6 (picker, LOAD-BEARING FOR THE
## WRITTEN PROMISE), Task 7 (gate + in-app verification by John).

Task 5: complete (commit b174ccb). PER-TASK REVIEW DEFERRED to the Task 7 whole-branch review,
  deliberately, for time. Evidence was strong enough to justify it: compile-level RED captured by
  stashing the four production files while keeping the test, then GREEN, then a mutation forcing
  the classification to nil inside ProjectionEngine.computeStateTax's row builder produced a
  $2,535 gap and was reverted clean.
  Multi-year now receives classified pension income, so a classified New York government pension
  produces the SAME answer from DataManager and from ProjectionEngine year one. Without this the
  user would have seen the uncapped exclusion on Scenarios and the capped figure in Multi-Year.
  I2 pins HELD (single-year 42.0, multi-year 200.40469973890345). Frozen baseline byte-identical,
  checksum 34a121744f8edf3db7c440202a8c4d83, not regenerated. Suite 1,705 ST in 284 suites + 503.
  AccountSnapshot deliberately NOT widened, per spec 3.4b: account classification affects the
  single-year calculation and NOT the projection. No shipping rule depends on it, so no number is
  wrong, but it must be disclosed in Task 6 rather than discovered.

Task 6: complete (commit 3fa5320). THE TASK THAT MAKES THE PHASE REACHABLE. 33 new tests.
  Suite 1,738 ST in 285 suites + 503 XCTest. Baseline byte-identical, I2 pins held.
  Mutations that discriminated: the out-of-state-pension picker mapping (flipping it to select New
  York's exclusion failed 4 tests including the named regression test), and the New York prompt's
  residence gate.

  ** LATENT BUG FOUND AND FIXED AS A SIDE EFFECT: neither Add Income nor Add Account passed the
     classification on save, so ANY edit to a classified row would have silently wiped it back to
     the inferred default. A user would classify a pension, edit its amount later, and quietly lose
     the classification along with the correct tax treatment. **

  Honest scope reporting worth crediting: MultiYearCPABriefing.swift was audited and has NO
  per-account display surface at all, so deliverable 2 had nothing to fix there rather than being
  quietly skipped.

  ** OPEN, AND IT AFFECTS THE STEVE PROMISE: two OTHER surfaces still render
     account.accountType.rawValue and will print "Traditional 401(k)" over a classified 403(b):
     PDFExportService.swift and RMDCalculatorView.swift. Outside Task 6's four-file scope and
     correctly flagged rather than silently expanded. Steve was told his 403(b) would show as
     itself; if he classifies one and exports a PDF he still sees 401(k). Fix before the release
     that carries the promise. **

## FINAL WHOLE-BRANCH REVIEW (opus): READY WITH CONDITIONS. All three closed at b21019b.
  Suite after fixes: 1,752 ST in 285 suites + 505 XCTest. Baseline byte-identical, I2 pins held.

  ** IMPORTANT 1, AND THE SPEC WAS THE SOURCE: the account picker told the user "This affects your
     single-year Tax Summary and Scenarios. It does not yet affect the Multi-Year plan." Account
     classification affects NEITHER; it is inert in every tax path. PROVEN BY PROBE: a NY household
     with a $500k traditional 401(k), classified (definedBenefit, nyStateOrLocal) versus
     unclassified, computed $3,121.8679245283015 BOTH WAYS, identical to the last digit.
     IRAAccount.planStructure/planSource are read at exactly three sites repo-wide, all
     presentation. MY spec §3.4b said "affects the single-year calculation and not the Multi-Year
     projection", which is wrong in the OVERPROMISING direction; its own next clause ("stored and
     displayed but inert until Kansas is verified") was the accurate one. Both the string and the
     spec are corrected. A wrong sentence in a spec became a wrong sentence shown to users. **

  ** IMPORTANT 2, AND A NAMED USER COULD HIT IT: MultiYearInputAdapter.pensionClassification
     returned nil whenever an owner had MORE THAN ONE .pension row. Probed: primary with a $45,000
     NYSLRS pension and a $25,000 NYC pension, BOTH classified (definedBenefit, nyStateOrLocal),
     gave single-year $0 against multi-year $2,535, every year of the horizon. And all three
     disclosure surfaces stayed SILENT, because they gate on planSource == .unknown and both rows
     WERE classified, so the CPA briefing printed the capped figure with no limitation. A New York
     City retiree holding a city pension plus a state pension is an ordinary profile. This is the
     exact cross-path divergence Task 5 existed to close, closed for one row and left open for two.
     Fixed: the classification attaches when an owner's rows AGREE, nil only on a genuine mix, and
     the three predicates now warn on a genuine mix too. **

  ** IMPORTANT 3: this phase's most consequential bug (neither save path passed the classification,
     so ANY edit reverted it to the inferred default) was fixed in Task 6 and guarded by NOTHING,
     because saveIncome() and saveAccount() are private methods on private view structs. Hoisted to
     testable statics with both branches pinned, including "a non-pension row passes nil". **

  KNOWN-OPEN (a) PROMOTED AND FIXED: PDFExportService.swift:1326 and RMDCalculatorView.swift:687
    still printed accountType.rawValue over a classified 403(b). The reviewer's argument, accepted:
    given Important 1, THE LABEL IS THE ENTIRE DELIVERABLE for a classified 403(b), because there
    is no tax effect behind it. A label right on one screen and wrong on the two a user would print
    for a CPA is worse than not shipping it. Steve was told in writing his 403(b) would show as
    itself.

  CLEAN, verified by the reviewer rather than assumed: persistence round trip including the legacy
    .rothConversion sentinel; EVERY save path audited by exhaustive grep of IncomeSource( and
    IRAAccount( constructions, confirming the two edit sheets are the only user-facing writers and
    there is no profile-switch or duplicate path; New York's rule and all three negatives; all four
    golden fixture values recomputed BY HAND against the shipped brackets; mirror parity on every
    new field; no duplicate types remain and matchedPerSourceRule delegates to the tested
    predicate; Task 5's refactor numerically inert; no double-exclusion path exists.

## OPEN, RECORDED, NOT FIXED (none block merge)
  - Minor mirror drift, latent: DataManager.swift:1055 computes pensionIRAExclusion including the
    per-source exclusions where the engine (TaxCalculationEngine.swift:766) uses the capped
    exclusion only, so `unused` diverges the day a state carries BOTH otherRetirementIncomeExclusion
    and perSourceExemptions. NJ is the only such state today and has no per-source rules. One line.
  - Retyping an RMD row to Pension permanently suppresses every NY disclosure: AddIncomeView has no
    .onChange(of: incomeType) reset, unlike AddAccountView's at AccountsView.swift:476, so the
    pre-selected "IRA" classification is saved onto a pension, which matches no rule AND is not
    .unknown, so nothing warns.
  - .unknown does double duty as "never asked" and "user answered Not sure", so a user who picks
    Not sure gets the amber prompt forever with no dismissal.
  - PRE-EXISTING, now load-bearing: ProjectionEngine NEVER subtracts the state standard deduction
    (grep -c stateDeduction = 0), so New York's Multi-Year figure is over-taxed by $8,000 single /
    $16,050 MFJ relative to Scenarios. Found and documented by Task 5, and the reason NY is absent
    from GoldenScenarioCrossPathTests.agreeing. This branch IS the New York release and invites the
    user to compare paths, so it deserves a backlog entry rather than a test doc comment.
  - Unrelated: .joint-owned pension rows are dropped from Multi-Year entirely
    (MultiYearInputAdapter.swift:339, :348 filter primary/spouse only).
