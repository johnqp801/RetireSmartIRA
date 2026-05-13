# Decision Log

Append-only. Newest entries at top. Each entry: `## YYYY-MM-DD: <Title>` + decision + one-sentence rationale.

---

## 2026-05-13: Adopt persistent project memory in `.claude/memory/`

**Decision:** Create `.claude/memory/` with subfolders for decisions, drafts, sessions, and roadmap. Update CLAUDE.md to instruct Claude to read it at session start.

**Rationale:** Three+ prior sessions failed because Claude had no recall of earlier LinkedIn drafts, screenshot picks, or roadmap conversations. In-repo persistent memory eliminates that failure mode and survives across worktrees and machines.

---

## 2026-05-13: Final App Store description opens with "Plan your retirement taxes like a pro — and stay on top of them all year long"

**Decision:** Use the year-round-usefulness framing instead of "in minutes, not hours" or "in hours with powerful what-if scenario planning."

**Rationale:** "In hours" alone sells against the app (sounds slow). "Powerful" is filler. Year-round framing captures real value and reads neutral.

---

## 2026-05-13: App Store description names CPA workload explicitly

**Decision:** Second sentence of description reads "RetireSmartIRA answers the questions that take a CPA hours to model."

**Rationale:** Concrete, name-drops the actual problems users search for (Roth, SS, RMDs, IRMAA, ACA), and implies speed without using a time-promise that could be undercut.

---

## 2026-05-12: V1.8.1 ships with 11 fixes from Ron Park's May 11 feedback

**Decision:** Build 37, marketing version 1.8.1. F1-F5 correctness bugs + U1-U6 UX changes. Submit to App Store same day.

**Rationale:** Real beta feedback from Ron (sub-$1M MFJ retiree, ACA-focused user) surfaced 5 correctness issues and 6 UX gaps that were ship-blockers. All committed, full test suite passes, archived.

---

## 2026-05-12: Defer 17 BLOCK items to 1.8.2

**Decision:** Items beyond Ron's feedback (analyst critique L1-L4, higher-earner additions H1-H5, deferred items D1-D6, code quality C1-C3) move to a separate 1.8.2 release per `docs/superpowers/specs/2026-05-12-1.8.2-incremental-design.md`.

**Rationale:** 1.8.1 must ship today for Apple review. 1.8.2 is a coherent next release, ~19 days of effort, with its own coverage matrix.

---

## 2026-05-12: ACA cliff messaging emphasizes REPAYMENT, not "lost subsidy"

**Decision:** Cliff warnings now say "Crossing the cliff means **repaying** advance credits of ~$X/yr at tax time" instead of "costs $17K/yr in lost subsidy."

**Rationale:** Ron's most important catch. Advance Premium Tax Credits are received during the year; crossing the cliff triggers full repayment THIS year, not just future-year subsidy loss. No repayment cap under post-IRA 2022 rules.

---

## 2026-05-12: Scenarios sections reorder to AGI-reducers-first

**Decision:** New order: Pre-tax Contributions → Charitable → Withdrawals → Roth Conversions. Step numbers renumber dynamically based on visible sections.

**Rationale:** Tells a coherent strategic story whether the user is a MAGI-minimizer (Ron's case) or a Roth-maximizer. You'd never want to set conversions before knowing your contribution-adjusted starting point.

---

## 2026-05-09: V1.7 release notes do NOT use "Honesty Improvements" framing

**Decision:** Reject "Honesty Improvements" or any wording implying prior version was dishonest. Use "Accuracy Improvements," "Refinements," or "Enhanced Calculations."

**Rationale:** Undermines trust in prior releases. Existing users would read "we lied to you before."

---

## 2026-05-02: V2.0 engine locked on `2.0/multi-year-engine` branch with 951 passing tests

**Decision:** Phase 0+1 + 3 OptimizationEngine bug fixes (IRMAA Medicare count, RMD basis timing, ACA gating) locked. UI work (Plan B) is the next major chapter.

**Rationale:** Engine math is correct and external-Gemini-reviewed. Building UI on top of an unstable engine is wasted work.
