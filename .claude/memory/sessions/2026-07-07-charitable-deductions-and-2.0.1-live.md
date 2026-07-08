# Session 2026-07-07 — 2.0.1 shipped & live; OBBBA charitable-deduction fix series; coverage audit

Continues [2026-07-06-2.0.1-visibility-chart-commentary.md](2026-07-06-2.0.1-visibility-chart-commentary.md) (which covers the 2.0.1 build/submit). This entry: 2.0.1 going LIVE, a series of OBBBA charitable-deduction correctness fixes, and a full OBBBA-2026 coverage audit. `main` @ origin.

## 1. V2.0.1 — LIVE
Both iOS + macOS **2.0.1 / build 59 approved & live in the App Store 2026-07-07**. Tagged **`v2.0.1-build59`** → commit `819c918` (the version bump — NOT main tip, since later fixes aren't in the build). What's New = "Feature-led"; promo text reused from 2.0.0. Chris Viscomi "it's live" note **SENT** (`drafts/emails/2026-07-07-chris-viscomi-2.0.1-live.md`) — the senior-bonus itemize fix he prompted IS in build 59 (verified). Roadmap flipped to LIVE.

## 2. OBBBA charitable-deduction fix series (the session's main work)
Triggered by working a tax-scenario question ("Jill," single, 2026) whose correct hand-calc diverged from the engine. That surfaced a chain of gaps — all the same shape as the senior-bonus itemize bug (a rule the law grants that the engine applied on only one path). Order of operations in the engine: **AGI ceilings → 0.5% floor → 35% cap.**

| Fix | Rule (2026) | Where | Status |
|---|---|---|---|
| **Non-itemizer cash charitable §170(p)** | $1,000 single / $2,000 MFJ, cash, on top of standard deduction | `DataManager.nonItemizerCharitableDeduction`; reduces taxable income not AGI | ✅ MERGED `main` (`2e52aa5`) |
| **0.5% AGI floor on itemized charitable §170(b)(1)** | only gifts > 0.5% of AGI deductible when itemizing | `charitableAGIFloor` / `deductibleCharitableDeductions` | ✅ MERGED `main` (`e68f0bf`) |
| **Charitable AGI ceilings** | 30% AGI on LT appreciated stock (FMV); 60% AGI on cash | `ceilingLimitedCharitable` (applied before the floor) | ✅ MERGED `main` (`45fff75`) |
| **§68 overall itemized limitation ("35% cap")** | 37%-bracket filers: reduce itemized by 2/37 of lesser(totalItemized, income over 37% threshold); ALL itemized, not just charitable | `DataManager.itemizedOverallLimitationReduction` → subtracted in `effectiveDeductionAmount` | ✅ MERGED `main` (`11cf855`, built by a separate session, task_bf6c96bd) |

- All built TDD (Swift Testing), full suite green at each step (non-itemizer 1184 → floor 1189 → ceilings 1196). Each fix required correcting 1–2 existing tests that encoded the pre-fix behavior (values verified against the law, not rubber-stamped).
- **Federal single-year engine only.** State itemized left uncapped/unfloored (states vary). Multi-year `ProjectionEngine` is standard-deduction-only, so none of the charitable changes flow through it (known M4 limitation, marginally widened; the senior bonus DOES flow through multi-year — verified `ProjectionEngine.swift:1015-1035`).
- **None of these are in the shipped 2.0.1/build 59** (built after submission). They ride the **next build (2.0.2 / build 60)**.
- Decisions logged: `decisions/log.md` 2026-07-07 (three entries — non-itemizer, floor+cap-filed, and ceilings).
- Jill's tax: ~$1,910 → ~$1,640 with §170(p) (worth ~$270 for her because it also drops LTCG under the 0% cap-gains ceiling).

## 3. OBBBA 2026 coverage audit (ran as a Fable 5 sub-task, verified)
Written to `reference/2026-07-07-obbba-2026-coverage-audit.md` (web-sourced + code-cited). **Verified correctly modeled (no action):** SALT ($40k cap, 1%/yr indexing, 30% phaseout >$500k, $10k floor), AMT (2026 $500k/$1M thresholds + 50% phaseout rate — real calc exists), ACA (enhanced subsidies expired, 400% cliff back, Rev.Proc.2025-25 percentages), senior bonus (single + multi-year). **Gaps ranked:** (G1 HIGH) charitable AGI ceilings — being built this session; (G2 MED-LOW) QBI §199A not modeled → overstates tax for semi-retired consultants (app has a consulting income type); (G3 LOW) HSA bronze/catastrophic deemed-HDHP 2026 = content nudge; (G4 LOW) estate $15M exemption = add a disclosure line. N/A-for-audience: tips, overtime, car-loan interest, Trump accounts.

## 4. §68 cap session — finished & merged; ceilings reconciled on top
The 35% cap ran in a separate local session (worktree `.claude/worktrees/bold-thompson-00600b`, branch `claude/blissful-lehmann-34cb01`, task_bf6c96bd). It went quiet ~50 min mid-work (uncommitted), then completed and **merged to `main`** (`8a1fd12` + merge `11cf855`; its own session summary `09d42c9`). Implemented as `DataManager.itemizedOverallLimitationReduction` = `(2/37) × min(totalItemizedDeductions, incomeBeforeItemized − topOrdinaryBracketThreshold)`, subtracted in `effectiveDeductionAmount` on the itemized path; 7-test suite `ItemizedDeductionOverallLimitationTests`.

Then **reconciled the ceilings branch onto it**: rebased `fix/charitable-agi-ceilings` onto `main`. Conflicts were exactly the predicted config surface — `TaxYearConfig` struct + hardcoded fallback + all 4 `tax-*.json` (both added fields after the floor anchor). Resolved by keeping both field sets; **the order-of-operations landed correct automatically** (ceilings→floor produce `deductibleCharitableDeductions` → `totalItemizedDeductions` → §68 cap reads that total in `effectiveDeductionAmount`), so no engine change was needed. One post-rebase compile fix: reordered the fallback init args to match the struct's declaration order (ceilings before cap). **Full suite green 1203** with both present. Merged `main` (`45fff75`).

## Open / next
- **Cut 2.0.2 / build 60** — the full OBBBA charitable stack is now on `main`: non-itemizer §170(p), 0.5% floor, 30%/60% AGI ceilings, and the §68 overall cap. Version bump, release notes (2-3 options), archive+submit both platforms. Also carries the 2.0.2 chart caption/popover consolidation (filed chip).
- **Audit follow-ups:** QBI disclosure (quick) + simplified §199A (2.1); HSA-on-bronze content nudge; estate-tax disclosure line.
- Commit the coverage-audit reference file (done this wrap-up).

See [[v2-status]], [[ios-mac-build-numbers]], [[chart-commentary-2-0-1]].
