# Display Audit Harness — Stage 1 SDD ledger (preserved)

**Why this file exists.** This is a verbatim copy of `.superpowers/sdd/progress.md` from the
`2.2/display-audit-harness` worktree, which is gitignored scratch and would be destroyed when that
worktree is removed. It records the whole Stage 1 build, every deferred Minor, and the Stage 2 seams.

**Status as of 2026-07-29:** the harness is MERGED to `main` (rebased onto 2.3.0 main; one compile
fix needed, the `perYearExpenseOverrides` -> `perYearOverrides` rename). The 27-profile gate passes
against the post-2.3.0 engine, including HARD GATE B asserting an EMPTY frontier offender set. So the
"pinned 3 offenders" discussion below is HISTORICAL: those were fixed 2026-07-17 and the baseline is
now empty.

**Stage 2 (multi-model packet review) is not started.** Its key seam: packets write to the macOS test
sandbox container unless you pass an absolute path via `AUDIT_PACKET_DIR`. To emit them into the repo:

```
AUDIT_PACKET_DIR=$PWD/RetireSmartIRATests/AuditHarness/packets \
TEST_RUNNER_RUN_AUDIT_HARNESS=1 \
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/AuditGateTests
```

Deferred items still worth acting on, from the review notes below: the §8-5 PV-vs-nominal
"Lifetime tax" label collision (on-screen row is PV, CPA PDF row with the same label is NOMINAL);
`noPhantom` assumes no mid-horizon traditional contributions; `paConversionExempt` uses age>=60 as a
59.5 proxy; `inputsSummary` "trad" excludes inherited balances.

---

# SDD progress — Multi-Year Display Audit (Stage 0+1)
Branch: 2.2/display-audit-harness (rebased on fix branch @7e35192)
Plan: docs/superpowers/plans/2026-07-14-multi-year-display-audit-stage1.md

Task 1: IMPLEMENTED + committed (230b491) — Display Spec doc. Task-review PENDING (paused; see controller note).
  Concerns from implementer:
   - Added `taximpact.*` (cumulative-tax chart) — brief omitted TaxImpactChart.swift. MUST propagate to Task 3 extractor.
   - NEW FINDING: on-screen "Lifetime tax" row = PV, but CPA PDF's same-labeled row = NOMINAL. Same label, two bases. (logged to backlog)
   - Open items: LadderListView; CPA vs on-screen baseline projected independently (not shared by ref).

Task 1: COMPLETE (commits c46255c..b90e702; review clean — approved, 0 Critical/Important; 2 Minor prose nits fixed in b90e702).
  Carry-forward for Task 3: extractor MUST capture taximpact.* (§3) — TaxImpactChart.swift/TaxImpactChartView.swift. Plan's Task 3 file list omits it.

Task 2: COMPLETE (commit e0f7b70; review clean — approved, 0 Critical/Important). 27 profiles, all six states, named repros pa62/residual/6m-ca present. Focused test RED->GREEN; full suite 1348 Swift Testing / 228 suites, 0 fail.
  MINOR (for final review): (a) ids `single-a7-il-verylarge-noconvert` & `mfj-b8-ms-mid-noconvert` use .limitToIRMAA, not true zero-convert — Task 3/4 must NOT assert literal zero conversion on those ids. (b) redundant explicit `acaEnrolled: false` at AuditProfiles.swift:294.

Task 3: COMPLETE (commit a506675; review clean — approved, 0 Critical/Important). DisplaySnapshot.swift (432L) + tests. All 7 surfaces incl. taximpact (§3 carry-forward satisfied). Fidelity VERIFIED against source: drives the real ApproachComparisonCoordinator.compare / HeirFrontierCoordinator.computeFrontier / TaxImpactChart / MultiYearCPABriefing / ThresholdMapChart, active path via ApproachUILogic.activePath — not hand-re-derived. Focused 3/3; full suite 1351/229, 0 fail.
  CARRY-FORWARD to Task 4: (a) captured "doing nothing" baseline is the coordinator's noAdditionalConversions (== emptyActionsMap), NOT literally manager.baselineProjection — so an in-snapshot cpa-vs-noConv baseline check is true by construction; the real-app equivalence is a Stage-2/known-limitation note, not a Task-4 hard fail. (b) all AuditProfile.heirWeight values are frontier presets, so active-path resolves for all 27 (dormant off-preset fallback nuance).
  MINOR (for final review): selectedApproach stored via String(describing:) loses structure (Task 5 packet may want a stable discriminator); active-path fallback differs from view's currentResult fallback (dormant); cliffmap lines read provider.config(2026) vs view's global config (coincide at pin).

Task 4: COMPLETE (commit 8758eb6; oracle code APPROVED — 0 Critical/Important in code). 6 invariants, exact keys, ε=1.0. Additive snapshot ext ActivePathAuditSnapshot/pathAudit (canonical magi/agi + convertible-trad proxy). Focused 4/4; full suite 1355/230, 0 fail.
  VERIFIED FINDING (reviewer confirmed independently, REAL + MATERIAL): frontier.nonDominated fires on 3 profiles on THIS branch — dominated heir-frontier points, magnitudes:
    - mfj-b6-ca-verylarge-old: +$14,295 owner tax / -$191,285 heirs (worst pt)
    - single-c3-nj-shorthorizon: +$33,408 / -$33,328
    - mfj-c3-il-shorthorizon: +$141,358 / -$59,683
  CAUSAL CORRECTION (reviewer, vs implementer's report): these 3 profiles do NOT converge (hit iteration cap), so keepBestOfCandidates de-domination DOES run yet frontier stays dominated. Root cause = per-λ candidate scoring does not enforce CROSS-λ Pareto non-domination. Fix = a final cross-λ Pareto repair sweep, NOT merely dropping the !greedyConverged gate. Distinct from/deeper than the I3 fix (2c54746). Related to known greedy/iteration-cap pathology ([[over-conversion-brake-ineffective]], INV13).
  Task 4 oracle Minor (for final review): noPhantom proxy assumes no mid-horizon trad contributions (clean for retiree catalog, guard if working contributors added); paConversionExempt uses age>=60 as 59.5 proxy (skips 59-60 converters); frontierFindingIsPinned pins offender SET but not magnitude (silent shrink wouldn't trip).

Task 5: BLOCKED on human policy decision — plan's "#expect(allViolations.isEmpty)" hard gate is NOT achievable on this branch (frontier.nonDominated fires materially on 3 profiles). Options: (a) engine cross-λ Pareto-repair fix now; (b) documented allowlist of the 3; (c) baseline/pinned-offender-set diff gate (hard-gate the other 5, assert frontier offender set == known 3). Awaiting John.

Task 5: COMPLETE (commit 9be1eb6; review clean — approved, 0 Critical/Important). AuditPacket + AuditPacketWriter (deterministic .prettyPrinted/.sortedKeys, one file/profile) + AuditProfile.summary + .gitignore + standing gate. GATE A (5 clean invariants empty) + GATE B (frontier offender set == pinned 3) + magnitude pin (keyed to oracle's own dominance predicate, ±10%). Focused gate GREEN (~390s, 27 packets); full suite 1357/231, 0 fail. On-main repro DEFERRED (B2 field absent on main → capture won't compile there without forking; expected on-main = RED; tree clean, no scratch worktree left).
  Task 5 Minor (for final review): magnitude test isDominated loops `weight != pi.weight` vs oracle's `j != i` (equivalent only bc preset weights unique — add a comment); inputsSummary "trad" excludes inherited (Stage 2 should read snapshot, not parse summary).
  SEAM (defer to Stage 2 w/ docs): packets write to macOS test sandbox container, not the worktree (writer takes dir:URL so Stage 2 passes an absolute repo path; .gitignore entry is a no-op under sandbox).

STAGE 1 COMPLETE — all 5 tasks done + reviewed. Next: final whole-branch review, then finishing-a-development-branch. Stage 2 (Plan B multi-model runner) is a separate future plan.

FINAL WHOLE-BRANCH REVIEW (opus, 7e35192..9be1eb6): Verdict = FIX-THEN-MERGE. 0 Critical.
  IMPORTANT #1 (perf): AuditHarness folder adds ~25-28 min to every full `xcodebuild test` — capture (~14s/profile) runs ~120× across the folder (each of several tests re-captures all 27). Fix: share ONE capture pass (static let, deterministic) across DisplayInvariantsTests+AuditGateTests + drop duplicate 3-profile recapture; and/or env-gate the full-catalog gate so local loop stays fast (CI runs it). Hurts CLAUDE.md tests-are-source-of-truth loop. -> WORKFLOW DECISION for John.
  IMPORTANT #2 (packets): AuditGateTests writes to CWD-relative "RetireSmartIRATests/AuditHarness/packets" -> under xcodebuild lands in sandbox container, NOT repo. .gitignore entry is a no-op; Stage-2 input not produced at expected path; a write error fails the GATE for a non-display reason. Fix: resolve dir from env (AUDIT_PACKET_DIR) fallback to temp, log absolute path, don't fail the display gate on write error. Clear fix.
  MINORS: baseline 3-ids duplicated in 3 places + fragile detail-string-split in frontierFindingIsPinned (hoist one canonical static let, use structured .profileId); magnitude-pin assumes a strictly-dominated point exists (monotonicity-only offender -> confusing Issue.record; make nil a documented skip); GATE B failure msg lacks what-to-do pointer (add "see memory frontier-cross-lambda-domination" + how to re-pin); naming nits (unchanged Minor).
  PLAN/DESIGN: bless taximpact addition; gate revision right; CONFIRM the "reproduce on main" step (Task5 Step4) — it was DEFERRED, reviewer wants the evidence; Stage-2 packet schema should carry label/units text for the deferred §8-5 / §6 definition risks.

FINAL-REVIEW FIXES: DONE (commit 9a383b3). Per John's decision (share capture + env-gate):
  - Shared @MainActor static AuditCaptureCache.all (one 27-profile capture pass, reused across DisplayInvariantsTests+AuditGateTests+magnitude test; dup 3-profile recapture removed).
  - Env-gate: heavy catalog-wide tests use .enabled(if: AuditCaptureCache.runFullHarness) — SKIP in normal loop; run via TEST_RUNNER_RUN_AUDIT_HARNESS=1 (app-hosted bundle strips the TEST_RUNNER_ prefix; inside process it's plain RUN_AUDIT_HARNESS; documented in AuditGateTests header). Smoke tests (1-3 profile) stay always-on.
  - Packet dir: AUDIT_PACKET_DIR env else <temporaryDirectory>/audit-packets (guaranteed writable, abs path logged); write wrapped so I/O failure can't fail the display gate.
  - Minors: canonical AuditCaptureCache.frontierBaseline (dedup 3 places); frontierFindingIsPinned uses structured .profileId not detail-string-split; magnitude nil = documented skip; GATE B failure msg points to memory frontier-cross-lambda-domination.
  VERIFIED: gate-OFF 5 catalog tests skip + 9 pass (72s); gate-ON both gates GREEN (358s, offender set==3, magnitudes ±10%, 27 packets); full suite no-flag 1357 Swift Testing + 503 XCTest, 0 fail (~232s). GATE A/B assertions confirmed intact (set-equality preserved). Tree clean.

STAGE 1 DONE + FINAL REVIEW CLEAN + FIXES LANDED. Ready for finishing-a-development-branch.
