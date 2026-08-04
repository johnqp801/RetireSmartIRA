# RMD Spouse Attribution — SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-03-rmd-spouse-attribution.md
Worktree: .worktrees/rmd-spouse-attribution (branch fix/rmd-spouse-attribution), off main @ 16fd6a2
Related memory: [[rmd-calculator-spouse-gaps]], [[next-release-commitment-ledger]]

## Why this exists
Promised to Steve Nicolai IN WRITING 2026-08-03: "the summary will lead with whichever of you
starts sooner and show both, and the chart will separate the two." His wife is nine years older
and reaches RMD age first. Two of the six next-release commitments; the only two that had no plan.

## The framing that changed during investigation
NO ENGINE CHANGE, and no tax figure may move. calculateCombinedRMD (DataManager.swift:490) is
already calculatePrimaryRMD() + calculateSpouseRMD(), and scenarioTotalWithdrawals (:1662) already
uses it. All three defects are the same shape: THE MATH COUNTS BOTH PEOPLE, THE DISPLAY CREDITS ONE.

The status card is worse than "incomplete". THREE elements read primary-only values: the status
badge (isRMDRequired), the large RMD Age number (rmdAge), and the countdown at
RMDCalculatorView.swift:184 (yearsUntilRMD). So the card can say "Not Yet Required, RMDs start in
9 years" while the spouse's are already due. That is FALSE, not partial.

Also caught during planning: a couple can legitimately have DIFFERENT RMD ages. ProfileManager
.swift:101-109 returns 72 before 1951, 73 for 1951-1959, and 75 for 1960 or later, so a 1959/1960
couple straddles a real SECURE 2.0 boundary. resolve() takes both ages rather than assuming one.

Steve's third sub-point (spouse RMDs absent from Tax Summary) is UNVERIFIED and Task 3 audits
before touching. The math includes the spouse, so if anything is wrong it is presentational; a
wrong NUMBER would be a different defect needing its own plan.

## Tasks
Task 1: complete (commit 014bfe0 + fix c8bf30a). Reviewed on sonnet. 10 tests, targeted runs only,
  no full suite run and correctly so, since nothing in production consumes the type yet.
  RMDHouseholdStatus as a PURE value type: no DataManager, no SwiftUI, no Date(), five value
  parameters. Hoisted deliberately rather than left inline in the view, because the preceding phase
  shipped a defect that 1,752 tests missed by living in a private method on a private view.

  ** REVIEWER'S CATCH, fixed in c8bf30a: max(0, rmdAge - age) CLAMPS, destroying how long someone
     has ALREADY been required. Primary 78 with RMD age 75 (three years overdue) against spouse 85
     with RMD age 73 (twelve years overdue) both clamped to 0, the tie-break evaluated 0 < 0 as
     false, and startsFirst returned .primary with firstRmdAge 75. The spouse became required
     TWELVE YEARS EARLIER. anyoneRequired and showsBothPeople stayed correct, so it was an
     attribution error rather than a wrong requirement signal, but Task 2 narrates this field.
     FIX: one signed measure, age - rmdAge, and whoever has the LARGER value started first. That
     single comparison is correct in all three regimes: both waiting (larger = closer), both
     required (larger = required longer), mixed (positive beats negative). yearsUntilFirst becomes
     max(0, -largest), preserving the zero-once-required contract.
     ALL SEVEN ORIGINAL TESTS PASSED UNCHANGED, which is the evidence that the fix corrected an
     unspecified case without altering specified behavior. **

  Mutations, all four re-run by the reviewer or the fixer rather than trusted:
    - spouseEnabled guard broken: fails singleFilerShowsOnePerson AND disabledSpouseCannotLeakIn.
      The fictional spouseAge 99 leaks in and dominates every field, exactly as designed to catch.
    - tie-break flipped: fails identicalHouseholdsResolveToPrimary.
    - reverted clamp: fails bothRequiredNamesWhoeverStartedEarlier with startsFirst .primary and
      firstRmdAge 75, both wrong.
  Reviewer verified showsBothPeople's boundary by hand across the tricky pairs, including two
    people with different RMD ages who nonetheless start the same year: it is true there, which is
    RIGHT, because a single stated age would misattribute one spouse's trigger age to the other
    even when the countdowns coincide.
  Reviewer also ran a stricter non-ASCII byte scan, not just an em dash grep: zero matches.

Task 2: complete (2d3fec8 + review fixes 63853f3). 38 tests across 3 suites, frozen state-tax
  baseline unchanged, macOS whole-app build green.

  DELIBERATE DEVIATION FROM THE PLAN: the plan said "view tests". We did NOT test SwiftUI
  internals. The sentences are built by a pure RMDStatusPresentation and the view only renders
  it. Reason: the preceding phase shipped a defect that 1,752 tests missed because it lived in a
  private view method. The project has no ViewInspector and the established convention is exactly
  this, so it is idiomatic rather than novel.

  Fixed in Task 2 proper: badge reads anyoneRequired, the big number retitles to "First RMD Age"
  only when the two RMD ages actually differ, and two ordered per-person lines appear whenever
  showsBothPeople. Single filers and matched couples verified BYTE-IDENTICAL to before.

  ** REVIEW FINDINGS, all three Important ones fixed in 63853f3: **

  I2, the one that mattered most, and the reviewer framed it better than the implementer did.
    The Dec 31 "Important Deadlines" block still gated on primary-only isRMDRequired, so in the
    EXACT household this task was built for, where only the spouse is required, the card showed
    the corrected badge and both lines and then silently omitted the deadline for the only person
    who has one. Sharper still: Steve's wife is 73 with RMD age 73, so this is her FIRST RMD year,
    the single year the distribution may legally be deferred to April 1. The card asserted she was
    required while withholding the deferral note the app DOES show a primary in the identical
    position. Told something stricter than the law, and denied the mitigation.
    FIX: gate widened to anyoneRequired, plus a new firstYearNotices array, one entry per person
    whose OWN age equals their OWN rmd age, so the April 1 note follows the person. Single-filer
    wording unchanged.

  I3: because build() takes only ages, a named line asserted "Karen's RMDs are required now" for a
    spouse who might hold no traditional IRA at all. Naming a person turns an age fact into a claim
    about her accounts.
    FIX BY WORDING, NOT BY PLUMBING. Deliberately did NOT thread balances in: the card's status
    section has always been age-based for the primary, and making only the SPOUSE balance-aware
    would be internally inconsistent. Lines became pure age statements, "Karen has reached RMD age
    73" and "You reach RMD age 73 in 9 years", which are true whatever she holds.

  I1: with an inherited IRA plus a split clock, ":216-221" reprinted "Own IRA RMDs start in N
    years" four lines under the identical new household line. Gated on lines.isEmpty.

  M2 was worth taking seriously: the reviewer showed that reverting the body chain's final
    "else if lines.isEmpty" to a plain "else" reprints the OLD WRONG countdown underneath the two
    correct lines while all 22 tests stayed green. That seam was unguarded, which is precisely how
    this project has shipped defects before. FIX: a pure BodySections value the view renders from
    rather than re-deriving conditions inline, plus a 480-combination sweep asserting
    showsHouseholdLines and showsLegacyCountdown are NEVER both true.

  Accepted without change: M1 (inherited badge now says "RMDs Required"; the inherited fact still
    appears in the body), M4 default spouse birthdate, M5 whitespace-only names.

  Six mutations, every one re-run by the reviewer independently rather than trusted, and all four
  originals re-run AGAIN after the I3 rewording changed every expected string:
    badge primary-only; ordering forced primary-first; lines built from firstRmdAge; showsBothPeople
    gate broken; deadline gate reverted to primary-only; notices using the primary's age for both.
  NOTABLE: mutation 3 is invisible to the Steve case, because both spouses there share RMD age 73.
    Only the differing-ages test catches it. The headline scenario alone would NOT have caught the
    misattribution bug, so that test is load-bearing rather than redundant.

Task 3: AUDIT COMPLETE, read-only, no code touched. Full report at .superpowers/sdd/task-3-audit.md.

  VERDICT, execution-backed rather than reasoned: THE SPOUSE'S RMD IS IN THE TAX MATH. A throwaway
  probe on a household with a primary holding NO traditional balance and a 78-year-old spouse
  holding $1M showed enableSpouse moving calculateSpouseRMD 0 -> $45,454.55, scenarioTaxableIncome
  $7,800 -> $45,604.55, and scenarioTotalTax $780 -> $4,976.55. So this is a DISPLAY defect and
  belongs on this branch. It does NOT need its own engine plan or engine regression test.

  THE FAILURE SHAPE WAS THE OPPOSITE OF WHAT I BRIEFED. I told the auditor to hunt for a combined
  number under a primary-implying label. No money row has that. The real shape is the mirror image:
  PRIMARY-ONLY STATUS TEXT SITTING DIRECTLY ABOVE CORRECTLY-ATTRIBUTED COMBINED MONEY, which reads
  to a customer as the money being wrong. That is why Steve reported a missing number when no
  number is missing. Keep this in mind for the reply to him: nothing was miscalculated.

  45 display sites inspected. Ranked:
   P1 PDFExportService.swift:1053-1057 CONTRADICTS ITSELF. Personal Information prints "RMD Begins
      Age 75 (14 years)" from primary-only isRMDRequired/rmdAge/yearsUntilRMD, while Income Sources
      two sections later lists "Spouse's RMD $45,454.55" and folds it into the total. Ranked top
      because the CPA briefing goes to a THIRD PARTY who cannot ask what the app meant.
   P2 DashboardView.swift:195-206 Tax Summary header "Years Until RMD: 14" for a household six
      years into its spouse's RMDs. Almost certainly Steve's ACTUAL complaint: the header is read
      first and the correct Income Breakdown is twelve rows below.
   P3 TaxPlanningView.swift:1618-1620 vs :1263-1272, the same combined figure is "Required RMD"
      collapsed and "Combined RMDs" expanded.
   P4 LegacyImpactView.swift:82-91 "You have 14 gap years before RMDs start" to a household already
      six years into spouse RMDs.
   P5 DataManager.swift:2852-2859 action item "Take RMD: $X" unnamed while the spouse's is named;
      PDF Owner column hardcodes "Primary" at PDFExportService.swift:1091.
   P6 TaxPlanningView.swift:1630 and QuarterlyTaxView.swift:521 gate on RMD AGE where they mean RMD
      DUE, so a zero-balance primary past 75 is told "RMD required".
   P7 DataManager.swift:433 -> AccountsManager.swift:94, enableSpouse=false silently zeroes a
      spouse traditional balance. Largely defended already; residual risk is an imported profile.

  P1 through P5 are all the SAME defect and the fix already exists: route them through the tested
  RMDHouseholdStatus instead of primary-only properties. P6 and P7 are DIFFERENT bugs (age-vs-due,
  and a data-zeroing path) and go to backlog rather than being smuggled into this branch.

  NOT CLEARED, do not assume it is fine: the MULTI-YEAR CPA briefing (MultiYearCPABriefing.swift
  :213/261/271) runs off the optimizer's YearRecommendation, a different engine, and
  MultiYearStrategyManager.swift:263-265 uses a primary-only primaryRMDStartAge for
  yearsBeforeFirstRMD. Same defect shape in the multi-year world. Needs its own audit.

  Seam noted for the regression test: buildHTML / sectionPersonalInfo / sectionIncomeSources are
  private static and unreachable via @testable import. The file already widens sectionAccounts to
  internal at :1318, so following that precedent would let a test assert on rendered HTML rather
  than on the inputs to a branch.

Task 4: complete (f122841). The chart now separates the two people. 12 new tests, 61 in the
  targeted gate, baseline unchanged, macOS build green.
  Assembly HOISTED out of the private view property into file-scope pure types (RMDChartSeries as
  the single namer plus isRegular predicate, RMDChartHousehold, RMDChartDataBuilder), same reason
  as Task 1: private view methods are where this project's defects hide.
  SUM PRESERVATION is proven against an INDEPENDENT transcription of the pre-split accumulator
  (legacyProjectBalance + legacyCombinedRegularRMD calling RMDCalculationEngine directly, never
  the builder), asserted per-year to 1e-6 in two household shapes. That is the evidence no number
  moved, and it is stronger than re-using the code under test to compute its own expectation.
  MY BRIEF WAS WRONG ON ONE POINT: I called a site a hover tooltip. This chart has NO tooltip; it
  is the "Combined Peak" per-year total, and the implementer noted a first(where:) there would have
  silently DROPPED the spouse. Five sites filtered on the bare "IRA / 401(k)" literal, all now
  routed through the predicate: hasRegularRMDs, legend, chartForegroundStyleScale, peak annotation,
  and that per-year total.
  Single-filer category string stays EXACTLY "IRA / 401(k)". Peak is the household per-year total,
  not a per-person max, because a per-person max would report less than the tallest bar and
  contradict the existing "Combined Peak" line; label becomes "Peak (both):" for couples so a
  household number is never shown under a one-person label.
  Resolved ambiguity: when enableSpouse is true but the spouse holds no IRA, the primary series is
  still named "Your IRA / 401(k)" and no spouse series is emitted.

P1-P5 display-attribution fix: complete (26044c3). FULL macOS suite green, 1,815 Swift Testing in
  289 suites + 505 XCTest, 0 failures. Baseline matched all 51 jurisdictions. NO DOLLAR FIGURE
  CHANGED. All five reverts individually failed their named test, and each single-filer companion
  test kept PASSING under its mutation, which is what proves those pin compatibility rather than
  the fix. P1's test asserts on RENDERED HTML, after widening the private static seam following
  the file's own precedent at :1318; asserting on branch inputs is what let the defect survive.
  Two resolutions worth keeping: the audit's spouse (born 1948) has RMD age 72, NOT 73, per
  ProfileManager, so the copy says 72; and the spouse action title also became possessive, since
  "Take Karen RMD" beside a possessive primary would defeat the symmetry P5 asks for.

IN-APP VERIFICATION DONE, and it EARNED ITS KEEP AGAIN. Household built in the simulator: primary
  born 1960 (age 66, RMD age 75), spouse "Karen" born 1953 (age 73, RMD age 73, so she is in her
  FIRST RMD year), MFJ, Karen owning a $900k traditional IRA and the primary a $475k 403(b).
  VERIFIED CORRECT ON SCREEN: badge "RMDs Required"; headline retitled "First RMD Age 73"; the two
  ordered lines with Karen leading; the December 31 block PRESENT (absent before the fix for this
  exact household); "Karen's first RMD can be delayed until April 1 2027"; the chart legend showing
  two series with Karen-only bars through '34 and the primary's dark segment first appearing in
  2035, the year he turns 75; peak labelled "Peak (both)"; Tax Summary header reading "RMD STATUS /
  Required / Karen has reached RMD age 73"; the CPA briefing showing "Karen RMD Status: Has reached
  RMD age 73" above "Primary RMD Status: Reaches RMD age 75 in 9 years" with Karen in the Owner
  column, and the old self-contradicting "RMD Begins: Age 75 (14 years)" GONE.

  ** WHAT ONLY THE SCREEN CAUGHT (commit 486b39e): ** the Scenario Builder's "Conversion
  Opportunity Window" still read "You have 9 years before RMDs start. This is an ideal time for
  Roth conversions" while Karen owed $33,962.26 by December 31. TaxPlanningView.swift:938 gated on
  primary-only isRMDRequired, whereas the Legacy tab, which this branch HAD fixed, correctly showed
  nothing because gapSentence guards on !anyoneRequired. TWO SCREENS CONTRADICTED EACH OTHER, and
  the branch created that gap by fixing one twin and leaving the other. Not in the plan, not in the
  45-site audit, not caught by any of the reviews. Subtle because each sentence is individually
  TRUE; the defect is the household-level advice clause welded onto a per-person fact.

Whole-branch review: PROMISE KEPT, verified with rendered strings. Branch quality Ready with
  findings. Full suite 1,815 with one failure that is a PRE-EXISTING wall-clock flake
  (MultiYearPerfTests.persona2_mfjCouple35Years missing a 15s budget by 0.08%, green in isolation,
  and the branch touches no engine file). No-tax-moved verified INDEPENDENTLY of the baseline: the
  diff matches zero files containing "engine", and DataManager's only changed lines are two
  ActionItem title strings.
  It also SHARPENED the earlier finding: under the firstRmdAge mutation the headline Steve test AND
  all 11 DataManager-level RMDDisplayAttributionTests stay GREEN. The entire six-surface suite is
  blind to the misattribution, because the card consumes only lines.first and documentRows uses
  each person's own age. Only the pure presentation tests catch it, via households the customer is
  not. Do not trust the headline scenario to protect this.

REGRESSION THIS BRANCH INTRODUCED, found by the review, fixed in 6388cc9. Making the badge read
  anyoneRequired meant a spouse aged 73 holding ONLY a Roth got "RMDs Required", an April 1
  deferral notice, the two-RMDs amber warning, and a RED alert row in the CPA briefing, while
  combinedRMD was 0 and there were no action items. A Roth has no lifetime RMD. On main that
  household correctly read "Not Yet Required".
  THE PRINCIPLE, and the earlier decision was only half right: rewording the LINES into age
  statements was correct and stays. But that reasoning got extended to surfaces that are NOT age
  statements. A badge saying "RMDs Required", an April 1 notice, and a red alert row in a CPA
  document are DUE-NESS CLAIMS, and age alone cannot support them. So: age statements stay
  age-based, due-ness claims became balance-aware (age-required AND holding a traditional balance).
  Badge kept as "Not Yet Required" rather than inventing a third string, because new user-facing
  wording is John's call with 2-3 options offered.

MULTI-YEAR, confirmed by the review's live traces and fixed in f44595f. Both were the same defects
  in a DIFFERENT engine (the optimizer's YearRecommendation), which is why the single-year audit
  never saw them:
   - MultiYearStrategyManager.swift:263-271 computed yearsBeforeFirstRMD from the primary alone, so
     ConversionWindowBanner told this household "You have about 11 years before required minimum
     distributions begin" while Karen's 2026 RMD was $45,283.02. THIRD instance of one sentence;
     the banner now pulls its already-begun clause from the SAME builder the Scenario Builder uses,
     so the two tabs cannot drift again.
   - MultiYearCPABriefing.swift:253/261 printed the Age column as r.year - primaryBirthYear beside
     r.rmd, a HOUSEHOLD figure, so the CPA read "2026 / age 64 / RMD $45,283". Now shows both ages
     in the existing cell ("64 / 73", header "Ages") rather than adding a thirteenth column to a
     twelve-column nowrap table, with attribution in the note that has no width constraint.
     Gated on first-RMD YEAR not RMD AGE, because two people can share RMD age 75 and reach it a
     decade apart, which produces the identical contradiction.
   TRAP WORTH REMEMBERING: MultiYearStrategyManager.dataManager is `private weak`. A first draft of
   the tests let the DataManager deallocate inside a helper and the nil-expecting straddle test
   PASSED FOR ENTIRELY THE WRONG REASON. Tests now hold both managers in locals and assert
   rmdAge == 75 / spouseRmdAge == 73 before the real assertion.

FINAL IN-APP VERIFICATION PASSED. Multi-Year tab on the straddle household now shows the AMBER
  banner "Required distributions have already begun" with "Karen's RMDs have already begun, so part
  of your lower brackets is already in use. Your own required minimum distributions are still about
  9 years away." The hourglass.bottomhalf.filled SF Symbol RENDERS, which matters because a bad
  symbol name shows as blank and no test can catch it.

  ** BUILD TRAP THAT NEARLY FAKED A VERIFICATION, worth more than the fix itself: ** the rebuild
  after the multi-year commits reported ** BUILD SUCCEEDED ** and the app still showed the OLD green
  "Conversion opportunity window / You have about 9 years". Cause: xcodebuild with no -project and
  no cd built the MAIN REPO, which is on a different branch, into a DIFFERENT DerivedData directory,
  leaving the worktree product untouched. There are ~38 RetireSmartIRA-* DerivedData dirs; the
  worktree's is bqlnhygmnxefdndsouzuybyhyurq. Background bash commands do NOT change session cwd,
  so `cd X && ...` in a backgrounded call protects only that call.
  CAUGHT BY comparing `stat` on the built product against the source mtimes: binary 23:53, sources
  01:04. A green build is NOT evidence the thing on screen is your code.
  RULE: always pass `-project <worktree>/RetireSmartIRA.xcodeproj` explicitly, and confirm the
  product mtime is NEWER than your last commit before believing anything on screen.
  The earlier verification was NOT invalidated: the main repo does not even contain
  RMDStatusPresentation.swift, so the branch-only strings seen on screen could only have come from
  the worktree build.

## REMAINING
On-screen checklist from the implementers:
  - Tax Summary header now uses the MetricCard DELTA SLOT, newly used on that card, so check the
    three cards do not crowd at iPhone width
  - exported briefing shows two named RMD rows and no "RMD Begins"
  - Legacy tab gap-years note is gone entirely
  - collapsed Scenarios card reads "Combined RMDs"
  - RMD card: two ordered lines, the deadline block present for a spouse-only-required household,
    and exactly one April 1 notice naming the right person
  - chart bars two-tone with both people in the legend; primary's segment first appears the year he
    hits his own RMD age; inherited sand still visually distinct; legend wraps rather than clips
  - BOTH-in-first-RMD-year renders two April 1 notices under one shared amber warning, never seen
  - toggling Enable Spouse OFF must revert the legend to exactly "IRA / 401(k)" and drop "(both)"

## BACKLOG, deliberately NOT on this branch
P6 age-vs-due gate (TaxPlanningView.swift:1630, QuarterlyTaxView.swift:521): a zero-balance primary
  past 75 is told "RMD required". Different bug.
P7 enableSpouse=false zeroing a spouse traditional balance (DataManager.swift:433 ->
  AccountsManager.swift:94). Largely defended; residual risk is an imported profile.
MULTI-YEAR, never audited: MultiYearCPABriefing.swift:213/261/271 and
  MultiYearStrategyManager.swift:263-265's primary-only primaryRMDStartAge. Same defect shape in a
  different engine. Do NOT assume it is clean because the single-year path now is.

## STILL UNVERIFIED ON SCREEN
Nothing renders the card in a test, so the BodySections to SwiftUI mapping is eyeball-verified
only. Task 5 must look at the running app. Phase 3b's worst defect was found exactly this way,
after 1,752 tests, a 1,020-value baseline and seven reviews all missed it, because every one of
them called the engine directly and none went through what a user actually reads.
Two things to look at specifically: the deadline block and the single April 1 notice landing in
Steve's household, and the both-people-in-their-first-RMD-year case, which renders two April 1
notices under one shared amber warning and has never been seen on screen.
