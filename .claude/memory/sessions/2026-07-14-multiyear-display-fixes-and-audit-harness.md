# 2026-07-14 — Multi-Year display fixes, Fred/Alan threads, v2.2 audit-harness kickoff

Long multi-thread session. Everything below is durable (committed or saved); the RESUME pointer is in auto-memory `MEMORY.md`.

## 1. Release status
- **V2.1.1 build 61: BOTH PLATFORMS APPROVED & LIVE 2026-07-14** (iOS earlier, macOS later same day). On `main`, tagged `v2.1.1-build61`. Cleanup now unblocked (`git worktree remove .worktrees/2.1.1-user-feedback` + `git branch -d 2.1.1/user-feedback-fixes` — copy SDD ledger out first if wanted).

## 2. Multi-Year fixes — branch `fix/multiyear-state-tax-heir-frontier` (off main @4cda6be, NOT merged/pushed → future 2.1.2)
Found from John's iPad/Mac screenshots, all TDD, full macOS suite green (1,347 Swift Testing + 503 XCTest, 0 fail). 3 commits:
- **d363982 I1** — PA/IL/MS Roth-conversion state tax: multi-year `ProjectionEngine.computeStateTax` dropped `scenarioRothConversionAmount`, so PA (owner 59½+) was taxed ~3.07% on conversions it should exempt (~$82k spurious). Fix forwards `explicitRothConversions` at all 3 call sites. Test `paConversionExemptFromMultiYearStateTax`.
- **2c54746 I3** — heir-frontier "toward heirs" (λ>0) points were dominated (backwards table) because `keepBestOfCandidates` de-domination was gated to `heirWeight==0` (`OptimizationEngine.swift:654`). Removed the gate (kept the `!greedyConverged` perf gate). Test `taxMinNotDominatedAtPositiveHeirWeight`.
- **7e35192 B2** — "Minimize lifetime tax" appears beaten by "Fill to bracket." **IMPORTANT REVERSAL:** I first told John this was genuine A5 dominance; a deterministic reproduction (MFJ/63/$3M/high-income, residual IRA) PROVED it is DISPLAY-only — Minimize's true objective is always lower. The "Lifetime tax" row shows in-horizon PV tax only; fill-to-bracket hides deferred tax on the residual IRA. **The `!greedyConverged` gate is FINE — do NOT touch it for this.** Fix = new "Deferred tax on remaining IRA" row (`PlanPathMetrics.deferredTaxOnRemainingTraditional` = the heir tax already inside `heirsKeep`; reconciles by construction). Test `deferredTaxOnRemainingIRA`.

**Cross-state audits:** I1 is PA/IL/MS ONLY. CA and NJ correctly tax conversions (no exemption keys off the dropped arg). NJ's heavy machinery (SS exclusion, pension/IRA exclusion + $100k cap + $150k phaseout, Worksheet D) IS applied in multi-year. Backlog:
- **I2** (low sev, NOT fixed) — multi-year `computeStateTax` drops `postExemptionDeduction`: CA state std deduction (~$1k/yr) + NJ personal exemption (~$130-180/yr) + HSA add-back. Largely self-cancels in convert-vs-noConvert delta.
- **B5** (NEW, found writing the audit spec) — CPA PDF "Lifetime tax" is NOMINAL while on-screen row is PV. Same label, two bases.

All logged in the living backlog: `.worktrees/2.1-selectable-conversion-approaches/.claude/memory/roadmap/2026-07-13-multi-year-fix-backlog.md` (sections I1/I2/I3, B2, B5).

## 3. Fred's finding (CONFIRMED, not fixed)
Multi-Year conversion ladder does NOT pull Scenarios-tab IRA/401k withdrawals. Adapter reads `dataManager.yourExtraWithdrawal` into DEAD `year1PrimaryWithdrawal`/`year1SpouseWithdrawal` fields the engine never reads (grep-confirmed); no ongoing-year withdrawal field at all. Code comment `OptimizationEngine.swift:388-395` documents it as the "2.1 decumulation" gap. Overstates conversion room / IRA balances. This is the seed of the v2.2 workflow vision.

## 4. Emails (saved in `.claude/memory/drafts/emails/`)
- **Alan Levy — 2.1.1 feedback shipped** (`2026-07-14-alan-levy-2.1.1-feedback-shipped.md`): SENT by John. Alan is an iPhone user + evangelist.
- **Fred — Multi-Year vision** (`2026-07-14-fred-multiyear-scenario-vision.md`): APPROVED (solo "I" voice), John to send. Lays out recommend/commit/explain: Multi-Year *recommends*, Scenarios *commits*, Tax Summary *explains*; keep both numbers on override; decumulation source+use+ordering. Incorporated a ChatGPT critique John endorsed (fixed a charitable/MAGI error: cash gift doesn't move MAGI, QCD does).

## 5. Alan's 2nd-round feedback (verified vs code; NOT yet logged to backlog or replied)
1. **No local/city income tax** (NY 3.88% = NYC) — REAL gap. App models no local income tax; `saltTax` is only the itemized SALT *deduction*. Moderate effort.
2. **State withholding percent unsupported** — REAL gap, QUICK WIN. Income source has `federalWithholdingMode`/`federalWithholdingPercent`/`effectiveFederalWithholding` but state is a flat dollar field. Mirror the 3 federal fields for state.
3. **"Numbers for 2027+"** — the Multi-Year tab already projects income/taxes/RMD forward (discoverability). But per-year custom entry NOT exposed: `perYearExpenseOverrides` exists in the model + engine (`ProjectionEngine.swift:490`) but NO UI writes it; and there's no per-year income override at all. (Same dead-wiring pattern as year1Withdrawal.) Multi-year expense UI = a single `baselineAnnualExpenses` field in `AssumptionsStripView` (`MultiYearPlanView.swift:100-105`), grown by CPI.
**TODO next session:** log these 3 to backlog; draft an Alan reply (thank + point to Multi-Year tab + acknowledge the two gaps).

## 6. v2.2 planning — Multi-Year Display Audit Harness (IN PROGRESS)
John wants v2.2 (or 2.1.5): per-year income+expense overrides + Scenarios↔Multi-Year workflow. But FIRST a systematic way to test Multi-Year displays using OTHER AIs ("don't trust Claude to audit Claude"). Brainstormed → spec → plan → started subagent-driven execution.

**Branch `2.2/display-audit-harness`** (REBASED onto `fix/multiyear-state-tax-heir-frontier` so it has I1/I3/B2 — the harness must guard the FIXED displays). Commits: fixes (d363982/2c54746/7e35192) + spec (19e1095) + plan (c46255c) + Task 1 (230b491).
- **Design principle:** deterministic gate; LLMs NEVER produce numbers or hold the gate — they review definitions/labels/tax-claims against the oracle's numbers, ≥2 models must agree. (Today's B2 reversal is the case-in-point: an LLM was confidently wrong; a deterministic repro corrected it.)
- **Spec:** `docs/superpowers/specs/2026-07-14-multi-year-display-audit-harness-design.md`. Two stages + a written Display Spec.
- **Plan A (Stage 0+1):** `docs/superpowers/plans/2026-07-14-multi-year-display-audit-stage1.md`. 5 tasks. Stage 2 (multi-model CLI runner, GPT+Gemini) = separate Plan B, blocked on Stage-1 packets.
- **Execution (subagent-driven): Task 1 DONE + committed (230b491)** — the Stage-0 Display Spec doc (`docs/superpowers/audit/multi-year-display-spec.md`). **Task-review PENDING** (paused for session length).
  - Concern to carry: **Task 3 must extend to cover `TaxImpactChart.swift` / `taximpact.*`** (plan's file lists omitted it; implementer added it to the spec).
  - Ledger: `.worktrees/2.2-display-audit-harness/.superpowers/sdd/progress.md`.

**RESUME v2.2 harness:** in the 2.2 worktree, read the SDD ledger, complete Task 1's task-review, then Tasks 2-5, then Stage 2 (Plan B). Use superpowers:subagent-driven-development.

## 7. Open housekeeping
- `main-baseline` worktree is DIRTY: stray `ScratchDominanceRepro.swift` + a `debugGreedy` hook in `OptimizationEngine.swift` (both labeled "SCRATCH — DELETE") from the B2 investigation. Clean when convenient.
- `fix/multiyear-state-tax-heir-frontier` unmerged/unpushed (future 2.1.2 build for both platforms). Also has optional follow-ups: I2, CPA-briefing deferred-tax parity, B5.
- 2.1.1 worktree/branch cleanup unblocked (see §1).
