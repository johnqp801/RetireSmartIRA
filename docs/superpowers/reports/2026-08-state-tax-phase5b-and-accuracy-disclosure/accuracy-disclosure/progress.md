# Per-State Accuracy Disclosure SDD Progress Ledger

Plan: docs/superpowers/plans/2026-08-05-per-state-accuracy-disclosure.md
Spec: docs/superpowers/specs/2026-08-05-per-state-accuracy-disclosure-design.md
Worktree: .worktrees/state-accuracy-disclosure (branch feature/state-accuracy-disclosure)
Cut from feature/state-tax-phase5b @ 587b5c4. DEPENDS ON IT: the six captions and eleven
knownButUnpinned entries this consolidates exist only there.

## Baseline
2,035 Swift Testing in 305 suites + 509 XCTest, 0 failures.

## WHY THIS EXISTS
Commitment item 3 of six promised in writing to Steve Nicolai and Alan Levy. Steve asked to
"communicate how accurate the state modeling is; per-state, per-income-type treatment text", then
found a second state bug the next day. Phase 5b produced the content (11 catalogue entries, 6
approved captions, 4 approved disclosure sentences) and it is all invisible to users today.

## THE CONCEPTUAL RISK THIS DESIGN EXISTS TO AVOID
An empty knownLimitations array records what has NOT BEEN FOUND, never what does not exist. Phase 4
found states believed correct on retirement exclusions that were wrong on brackets, deductions,
credits and filing-status treatment. The empty state is specified as EXACT WORDING in Task 6 rather
than left to an implementer, and a test forbids "no limitations" and "fully modeled".

## PRE-FLIGHT PLAN REVIEW (controller, before Task 1)
1. TASK 2 DELIBERATELY ENDS RED, and Task 4 turns it green. This contradicts the project's standing
   "not done until the suite is green" rule. It is intentional: Task 2's failure list IS Task 4's
   authoring worklist, which is cheaper and more honest than guessing it up front. A reviewer must
   not reject Task 2 on that ground.
2. TWO OVERCLAIMS WERE CORRECTED IN THE SPEC BEFORE PLANNING, by John's review, and the plan must
   not reintroduce either: generating from config REDUCES drift risk rather than eliminating it
   (the engine can disagree with its own config, as this branch proved repeatedly), and a required
   field in JSON gates at DECODE AND TEST time, NOT at Swift compile time.
3. SCOPE DECISION NEEDING JOHN, binds at Task 2: metadata completeness is gated for the 15 covered
   jurisdictions, not all 51, because 50 of 51 configs have an empty lastVerified. Widening is a
   one-line change. Working assumption is 15; confirm before Task 2 ships.

## Tasks
(none complete yet)
Task 1: complete (commit 8a67c35, review PENDING).
  Hoisted DC's survivor-toggle, Hawaii's and Massachusetts's captions from inline view-body literals
  to statics so Task 3's byte-identity gate can exist at all. Extracted from HEAD by script and
  re-parsed out of the edited file, compared byte for byte: 253/208/222 chars, all ASCII, IDENTICAL.
  The three pre-existing statics re-parsed as untouched. Suite 2,037 + 509, 0 failures.
  ** TWO CONTROLLER ERRORS CAUGHT, one of which would not have compiled. **
  1. The plan said `PlanClassificationChoice.*`; the captions are `IncomeSourcesView` statics. The
     plan made the same slip for the three that already existed, so it was a uniform typo. FIXED in
     the plan, including Task 3's gate which would not have compiled.
  2. ** THE HAWAII COLLISION, not anticipated by the plan. ** MultiYearCPABriefing
     .hawaiiPensionSplitLimitation:421 is the SAME sentence except "This plan" vs the caption's
     "This app", pinned by a different test. One knownLimitations string cannot hold both.
     RESOLVED by the controller using the mechanism already in the codebase: the {scope} token that
     unclassifiedPensionDisclosure uses for exactly this. Task 3 amended.
  Implementer added a test beyond the brief pinning the DIRECTION WORD in all six captions (Hawaii
  "overstated" vs Massachusetts "understated"), since harmonising them would invert one. Good call.
  REVIEW: SPEC PASS, quality APPROVED, no Critical or Important. The reviewer wrote its OWN Swift
  string-literal tokenizer rather than trusting the implementer's script, SHA-256 matched all three,
  and proved something stronger: substituting the statics back to literals makes the ENTIRE FILE
  byte-identical to HEAD outside the caption block, which mechanically proves no rendering gate,
  systemImage, font or foregroundStyle moved. Both raised items upheld. The direction-word test was
  judged an extension of an EXISTING repo convention (NC, ID and VT decision suites already assert it)
  rather than gold-plating.
  Three Minors, all cosmetic and all in the new test's own comments, FOLDED INTO TASK 2's dispatch:
  a doc comment claims DC runs toward over-taxation when DC's caption carries no direction word and
  nothing pins one; a test name says "all six ... keep their direction" when only two get a direction
  pin; and Hawaii has both a positive and negative direction assertion where Massachusetts has only
  the positive.
  REVIEWER NOTE APPLIED TO THE PLAN: the two Hawaii strings differ in length (209 vs 208), so Task 3's
  gate must assert the RENDERED string per surface, not the stored sentence.
Task 2: complete (commit 7c72664, review PENDING). SUITE IS RED BY DESIGN and Task 4 turns it green.
  Added StateVerification.taxYear and the completeness gate. Failure list: 14 jurisdictions, 42
  failures (3 each): AZ DC HI IA ID IN KS MA MO NC NM NY UT VT. Georgia passes. THAT LIST IS TASK 4'S
  WORKLIST and the grep recipe to reproduce it is in report section 1, because the abbreviations
  appear in the wrapper's full log rather than its six-line summary.
  ** TWO MORE CONTROLLER ERRORS CAUGHT. **
  1. The plan's rationale for coveredJurisdictions was WRONG. "Every member traceable to a pinned
     defect or a knownButUnpinned entry" is false for GA, IA and IN (Phase 5 corrections with no
     pinned defect) and mis-explains VT (caption only). The real rule is
     phase5CorrectedJurisdictions UNION knownButUnpinned states UNION the six caption states = 15.
     The implementer wrote that rule into the comment AND added a passing test checking it against
     the live catalogue, which is better than what the plan specified. Plan corrected.
  2. Plan line 34 said taxYear arrives in Task 5; it arrives here. Corrected.
  It also corrected a PRE-EXISTING false enforcement claim in StateVerification's own doc comment
  ("cannot be added without a primary source and a verification date"), which 50 of 51 configs
  falsify. Same class as the compile-time-gate overclaim John caught in the spec.
  Three StateVerification fixtures in StateTaxCodableRoundTripTests gained taxYear: 2026, forced by
  the no-default memberwise init. Not baselines, not pinned values.
  REVIEW: SPEC PASS, quality APPROVED. The reviewer re-derived the 14-state failure list INDEPENDENTLY
  of the test by parsing all 51 configs, and confirmed the coveredJurisdictions derivation is real for
  2 of its 3 groups (group 3, caption states, is an honestly-disclosed literal). It proved the gate is
  non-vacuous in BOTH directions, including that deleting the key entirely still fails via the legacy
  fallback, and that the one silent way to neuter it (emptying coveredJurisdictions) is caught by the
  derivation test. It called that pairing the strongest part of the task.
  ** IMPORTANT, a forward risk Task 2 owns the contract for, FOLDED INTO TASK 3: ** taxYear's `0`
  sentinel has NO DEFINED RENDER. Task 6 builds a header showing the tax year, Task 7 wires it to
  entry points resolving ANY state, and 36 uncovered jurisdictions carry taxYear 0 and an empty
  lastVerified. As specified, Pennsylvania renders "Pennsylvania ... 0" with a blank date.
  Four Minors, three folded into Task 3: the gate hardcodes 2026 while its message claims generality;
  a comment says "fails the build" four lines below a careful "neither is a compile error"; and a
  redundant unmessaged count == 15 assertion in the one test whose purpose is to DERIVE rather than
  restate. The fourth (private CodingKeys consistency) and the group-3 literal are noted for Task 3's
  natural cleanup.
Task 3: complete (commit 987f653). Controller verified MECHANICALLY, full review NOT run.
  ** FIVE caption sentences moved into verification.knownLimitations (HI, MA, NC, ID, VT), NOT six. **
  Corrected 2026-08-06; this ledger, the resume file, the plan, the spec and the task reports all said
  six. Six approved captions exist. DC's survivor-toggle caption stays a Swift literal in
  IncomeSourcesView because it explains a CONTROL rather than describing a limitation, and moving it
  would show it to every DC resident whether or not the toggle is on screen.
  Hawaii's uses the {scope} token:
  one stored 212-char sentence renders both approved wordings byte-identically, and the controller
  independently confirmed substituting "plan" reproduces the CPA briefing's 209-char literal exactly.
  Hawaii proven the ONLY collision by a normalized sweep of every 60+ char literal in the app.
  ** LAYER B BLOCKER THE PLAN NEVER ANTICIPATED. ** structurallyIdentical demands JSON/legacy
  byte-identity for jurisdictions off phase5CorrectedJurisdictions, and HI/NC/ID/VT are off it.
  Task 3 added disclosureOnlyDivergentJurisdictions with a proof the divergence is confined to
  `verification`, rather than excusing the check permanently or mirroring copy into the frozen table.
  0-sentinel resolved with an optional accessor `statedTaxYear`; it deliberately picks NO fallback
  string, since that copy was John's. Task 6 authored it and John APPROVED it 2026-08-06.

Task 4: complete (commit 2d863ee). SUITE IS GREEN AGAIN, 2,048 + 509, 0 failures.
  Controller verified mechanically, full review NOT run.
  ** 13 NEW SENTENCES, ALL APPROVED BY JOHN 2026-08-06 AS WRITTEN: ** AZ 2, DC 2, KS 1, MA 1, MO 2, NC 1, NM 1, NY 1, UT 2. Eleven
  say "overstated", two say "understated" (both Missouri). Listed by state in report section 1.
  ** THE BRIEF'S GEORGIA PREMISE WAS WRONG AND IT CHANGED THE DESIGN. ** Georgia's $70,000 is the
  TY2027 retirement-income EXCLUSION, not the standard deduction the controller's wording implied
  (config: deduction 15k/30k, exclusion 65k). So Georgia is pension-topic and correctly placed, and
  the unfiltered-caption defect is created by Task 4's OWN new copy (Utah credits, New Mexico
  exemption), not inherited.
  Unfiltered-caption defect FIXED: knownLimitations became [StateLimitation] (text + topic, three
  cases each earned). The editor reads pensionLimitations(for:); the accuracy page still shows all.
  Decode accepts a bare string as a safe-direction fallback, with a gate reading RAW FILE BYTES
  proving no shipped file uses it.
  Layer B: MO and NY added, confirmed by derivation as the only covered states off both sets.
  Arizona's unclassified-pension entry deliberately NOT authored: already covered by its
  unclassifiedPensionDisclosure, gated on exactly the affected population. Hence 13, not 14.
  ** IOWA AND INDIANA SHIP EMPTY LISTS, ** which makes Task 6's empty-state wording load-bearing
  INSIDE the covered set, not just for the 36 outside it.
  Handing forward: the five caption statics carry no topic, so a future non-pension caption move
  could disagree with its stored topic uncaught.
Tasks 5+6: complete (3074127, 870324c). Factual half + page + empty state. Suite green 2,062+509.
Tasks 7+8: complete (d107b0d, fee5c8f). Three resolvers + both gates. Suite green 2,071+509.
  ALL SIX GATES VERIFIED BY MUTATION AND REVERTED.
  ** THE PLAN'S THIRD ENTRY POINT DOES NOT EXIST. ** The multi-year tab has NO state tax row; its only
  state-tax figure is the `State` delta tag in the approach-comparison strip, which renders only when
  a comparison exists. So the multi-year affordance is NOT always on screen. John's call.
  ** ROTH CONVERSION TREATMENT IS ABSENT FROM THE PAGE ** and four states carry rothConversionExemption
  (IA, IL, MS, PA). This is a ROTH CONVERSION APP. PA exempts the conversion entirely, so a $200k
  converter assumes a $6,140 state cost that does not exist and nothing on the page corrects them.
  Ten lines plus a test. Recommended before merge; left as John's scope call.
  Gate 3 CANNOT catch California's engine-hardcoded exemption credits by behaviour probe, structurally:
  a probe compares a CLAIM against behaviour and the page makes no claim. Closed instead with a scope
  gate (covered set stays disjoint from engine-hardcoded jurisdictions) plus an assertion the credits
  are real, so the exclusion cannot go stale.
  Gate 1 traces per JURISDICTION, not per sentence: StateLimitation has no citation field, and that
  schema change belongs to Phase 6.
Roth conversion statement: complete (d3a7d9e), authorized by John 2026-08-06. Suite green 2,076+509.
  ** THE FOUR CONFIGS ARE NOT UNIFORM: three shapes. ** IL and MS minAge 0 with no caveat; PA minAge 0
  with the WITHHELD PORTION still taxable; IA minAge 55. Rendered from the two fields rather than
  flattened, which is exactly what the design's render-live-data principle requires.
  ** IOWA'S RULE EXISTS ONLY IN THE BUNDLED JSON, not in the inline Swift table, ** so Iowa doubles as
  a legacy-fallback detector: if the loader ever falls back, Iowa's statement disappears.
  Placed after the IRA and 401(k) exemption and before per-source rules, on the section's stated
  principle of computation order (the engine applies this exemption last). Iowa's IRA line says the
  OPPOSITE of the truth for a conversion, which is the argument for promoting it above the pension
  line; that is a two-line change if John wants it.
  ** CANDIDATE LIMITATION SENTENCE, FLAGGED SO IT IS NOT LOST: ** the engine gates Iowa's age on
  `effectiveAge`, the HOUSEHOLD MAXIMUM, not the converting owner's age. The approved copy says "from
  age 55" and is silent on whose age. Out of scope for this change.
  APPROVED copy (John, 2026-08-06), label "Roth conversions": IL/MS "Not taxed by this state."; PA "Not taxed by this
  state. Any part of the conversion withheld for federal tax does not reach the Roth account, so that
  part stays taxable."; IA "Not taxed by this state from age 55."

M5 (the modelling caveat) + record corrections: complete. Suite green, full run below.
  ** THE CAVEAT SHIPS ON EVERY STATE PAGE, WHICH INVERTS THE SPEC. ** Spec section 1 offered "State
  tax rules are complex, and this does not mean every unusual situation is represented" as an
  OPTIONAL follow-on to the empty state. John approved it 2026-08-06 and made it unconditional: a
  page listing three limitations makes the same implicit claim about the rules it omits as an empty
  page makes about all of them.
  ** SHAPE: A SEPARATE ALWAYS-RENDERED ELEMENT, NOT AN APPEND. ** `noRecordedLimitationsSentence` is
  pinned by EXACT EQUALITY in three tests and John specified it character for character, so appending
  would make one pinned string carry two separately approved decisions and force a caveat edit to
  move the empty-state pin. New constant `StateAccuracyContent.modellingCaveatSentence`; new `Text`
  in `StateAccuracyView.limitationsSection`, OUTSIDE the empty-versus-populated branch.
  Two gates. `modellingCaveatIsPinnedAndIndependent` pins the wording, sweeps it for dashes, doubled
  space and non-ASCII, and asserts no jurisdiction's `limitationsSummary` absorbs it. Second gate
  `noModellingCaveatIsConditionalOnHavingLimitations` brace-parses `limitationsSection` out of the
  view SOURCE, because whether a `Text` sits inside an `if` is a property of an opaque `some View`
  body with no runtime handle; same tool and same reason as
  `noMultiYearSurfacePresentsTheAccuracyPage`.
  FOUR MUTATIONS RUN AND REVERTED, all caught: caveat deleted (occurrence count 0), moved into the
  empty arm, moved into the populated arm, and folded into `limitationsSummary` (which also fired the
  three pre-existing exact-equality gates, proving the independence claim is real).
  ** TWO RECORD CORRECTIONS. ** (1) "Six captions moved into config" was wrong in SEVEN places; it is
  FIVE. (2) The multi-year defect is `ProjectionEngine.computeStateTax`. There is NO
  `calculateMultiYearStateTax` symbol anywhere in the repo, so that half of the brief was already
  correct on this branch; what WAS wrong were stale line ranges (`:1294-1335`, `:1622-1634`) in the
  consolidated backlog and the Phase 2 ledger. Corrected to name the function, not a line.
  ** TWO FOLLOW-UPS RECORDED, NEITHER BUILT: ** the decode fallback (MUST NEVER fall back to "No
  known limitations"; John's string is "State modeling details are temporarily unavailable.") and the
  claim-type behavioural matrix. Both in full in
  `.claude/memory/roadmap/2026-08-06-accuracy-disclosure-RESUME-HERE.md` under RECORDED, NOT FIXED,
  and in `.claude/memory/decisions/log.md`.
