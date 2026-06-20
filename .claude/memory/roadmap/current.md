# Current Release Roadmap

**Last updated:** 2026-06-14

---

## IN REVIEW / PARTIAL LIVE: V1.8.7 (build 54 — submitted iOS + macOS 2026-06-11)

**Status:** ✅ Both iOS and macOS approved and live (2026-06-12).

**What's in 1.8.7:**
- ACA FPL thresholds updated to 2025 HHS poverty guidelines ($15,650 single / $21,150 couple)
- ACA applicable percentage figures corrected to Rev. Proc. 2025-25 (2.10%–9.96%)
- IRA limits: base $7,500 / catch-up $1,100 (age 50+) per Notice 2025-67
- 401k limits: base $24,500 / catch-up $8,000 (50-59) / super catch-up $11,250 (60-63)
- CA exemption credit: $144 → $153/person (FTB)
- IRMAA tiers 2-4 corrected to 2026 CMS values (Tier 4 Part B was most significant: $608.40 → $649.20)
- 1,271 tests passing

**Release notes (approved Option C):**
> 1.8.7 — Updated 2026 Figures
> • ACA subsidy thresholds and premium percentages updated for 2026
> • IRA and 401(k) contribution limits updated for 2026
> • Medicare IRMAA premium tiers updated for 2026

**Draft:** `.claude/memory/drafts/release-notes/2026-06-11-1.8.7-release-notes.md`
**Branch:** `fix/aca-2026-config` (merged to main)
**Tag:** `v1.8.7-build54` ← create: `git tag -a v1.8.7-build54 -m "1.8.7 submitted review 2026-06-11" && git push origin v1.8.7-build54`

---

## PLANNED (NEXT): V1.9 — drawdown feature + NJ phaseout (single release)

**Status:** Planned. Decision 2026-06-18: **no standalone 1.8.8** — its NJ scope is folded into **V1.9** to avoid two back-to-back Apple reviews. Build 55 already staged in pbxproj (`CURRENT_PROJECT_VERSION` 54→55); `MARKETING_VERSION` bumps 1.8.7 → **1.9** at release. NOTE: the original "1.9 features bundle" (healthcare/AGI) already SHIPPED inside 1.8.2–1.8.7 — see decision-log 2026-06-18; the 1.9 label is reassigned to the drawdown feature.

**Scope item A — Contained pre-RMD drawdown projection (new headline feature):**
- Lives in the **RMD Calculator tab**, display-only. Planned annual withdrawal / target-spending input for the pre-RMD years; balance drawn down year by year at the growth-rate slider; after RMD age take `max(planned, RMD)`; new balance-over-time graph; 40-year horizon; single inflation input; pro-rata split across a household's accounts. Traditional/401(k)-focused.
- **Does NOT touch Scenarios or Tax Summary** (verified: those use current-year `calculatePrimaryRMD()`, not `projectBalance`/`growthRate`). Legacy planning is the only adjacent consumer of the projection machinery — decide whether drawdowns propagate.
- Open seam: optionally surface projected IRMAA/ACA exposure per year by reusing the already-live `MedicareCostEngine` / `ACASubsidyEngine`.
- Needs its own brainstorm → spec → plan (in progress as of 2026-06-18). Multi-bucket (brokerage/Roth) sequencing stays 2.0.

**Scope item B — NJ pension-exclusion AGI phaseout** (from Brian/Bob NJ feedback, 2026-06-14): model NJSA 54A:6-15 income-based phaseout. **Built on the `1.9/drawdown` worktree (Task 15, stepped phaseout + combined cap).** Currently NJ over-exempts in the $100K–$150K window (no phaseout, no $150K cliff) and single filers use the MFJ $100K cap instead of the correct $75K. Phase E's `.partialWithAGIPhaseout` doesn't fit cleanly — NJ's phaseout is *stepped* (50%/25% MFJ; 37.5%/18.75% single), not linear, and needs per-filing-status caps ($75K single / $100K MFJ). Touches the `ExemptionLevel` enum → update `StateComparisonView.swift` switch statements for exhaustiveness. Regression tests for $100K/$125K/$150K boundaries (single + MFJ). Full detail: decision-log 2026-06-14.

**Scope item C — NJ completeness (CANDIDATES, John deciding later 2026-06-18 which land in 1.9):** the NJ tax-completeness audit (decision-log 2026-06-18) found several more NJ gaps beyond the phaseout. Pure-engine-logic candidates that could ride in 1.9: **Worksheet D Other Retirement Income Exclusion** (Bob's confirmed finding — unused pension exclusion spills onto interest/dividends/cap gains, gated total ≤ $150k + earned ≤ $3,000), **NJ personal exemptions** ($1,000 + $1,000 senior each), and **tax-exempt-interest NJ reversal** (pending code verification). Bigger items needing new inputs (likely defer past 1.9): NJ **IRA basis** (only earnings taxable), **medical-expense deduction** (>2% NJ gross), **property-tax deduction/credit**. John to choose 1.9 scope.

**Reminders before ship:** full test suite (1,271+) green incl. new NJ boundary tests + drawdown tests; offer 2-3 neutral release-note wordings (per CLAUDE.md — no "honesty/bug-fix" framing). 1.9 is also the moment to finally market the quietly-shipped healthcare bundle (ACA + Medicare + Reduce-AGI).

---

## SUPERSEDED: V1.8.6 (build 54 — both iOS and macOS live 2026-06-07)

**Status:** ✅ LIVE on both platforms. Approved and available in the App Store.

**What's in 1.8.6:**
- SS taxability fix (IRS Pub 915 line-14 cap — modest SS with high other income was overstated)
- Stock-gain-avoided double-count fix: avoided gain no longer reduces gross income, NII, or MAGI (was understating NIIT + IRMAA tier when stock donation was active)
- In-app review prompt (ReviewPromptManager — value-event trigger, fires on next launch, per-version gated, "Rate" row in Settings)
- TY2024/2025 configs + loadOrFallback stride fix
- IRS golden-case test suite (Pub 915, 590-B, NIIT Q&A, OBBBA truth tables) — 1,269 tests

**Release notes (approved Option B):**
> 1.8.6 — Accuracy Improvements
> • Improved Social Security taxability calculations for scenarios where benefit amounts are modest relative to other income
> • Refined how charitable stock donations interact with net investment income and MAGI — more accurate IRMAA tier and NIIT projections
> • Added "Rate RetireSmartIRA" in Settings for easy App Store reviews

**Draft:** `.claude/memory/drafts/release-notes/2026-06-05-1.8.6-release-notes.md`
**Branch:** `fix/stock-gain-avoided-double-count` (on origin; merged to main)
**Tag:** `v1.8.6-build51` ← create this now: `git tag -a v1.8.6-build51 -m "1.8.6 live both platforms 2026-06-07" && git push origin v1.8.6-build51`

---

## SUPERSEDED: V1.8.5 (iOS build 50 / macOS build 48)

**Status:**
- **iOS 1.8.5 build 50 — ✅ LIVE 2026-05-29.**
- **macOS 1.8.5 build 48 — ✅ LIVE 2026-06-04.**
  Both platforms on 1.8.5. Superseded by 1.8.6 once approved.

**Marketing version:** 1.8.5
**Submitted:** ~2026-05-27 PT (both platforms)
**Tag:** `v1.8.5-build50` (annotated, on origin)
**Branch:** `1.8.5/state-tax-refresh` @ `6a6e110`

**What shipped (state-tax accuracy release):**
- 26 state tax schedules refreshed to TY 2026 (Tier 1-3 + Bucket 2 sweep)
- CA stale TY2023 bracket bug fixed (→ TY2025)
- Structural restructures: LA, KS, MT, ND, SC, OH, MA
- MO bracket correction caught by TriSTAR multi-LLM review (ChatGPT)
- Ships the press-facing Tax Data Methodology Brief
- Carries forward 1.8.4's Roth conversion withholding feature + earlier fixes
- ~1,100+ tests

**Detail:** `sessions/2026-05-27-v1.8.5-state-tax-refresh.md` (on 1.8.5 branch),
`sessions/2026-05-30-1.8.5-release-status.md`

---

## Release history (shipped)

| Version | Build | Status | Notes |
|---|---|---|---|
| 1.8.1 | 37 | Released 2026-05-14 | Ron Park ACA feedback — 5 correctness + 6 UX fixes |
| 1.8.2 | 42 | Released | Phase 1 (Ron polish) + Phase 2 (analyst critique) + Phase 3 (higher-earner) |
| 1.8.3 | 43 | Tagged `v1.8.3-build43` | Incremental |
| 1.8.4 | iOS 48 / Mac 47 | Superseded by 1.8.5 | Roth conversion withholding feature + 5 state fixes; **macOS withdrawn** from review when stuck; iOS superseded by 1.8.5 |
| 1.8.5 | iOS 50 / Mac 48 | ✅ iOS + Mac LIVE | 26-state TY2026 refresh (see above); Mac live 2026-06-04 |

---

## Next / in-progress tracks

### Reconcile `main` to shipped 1.8.5 — ✅ DONE 2026-06-04
**Status:** Executed. `main` (`c45327f`, on origin) is now the shipped `v1.8.5-build50`
tree + latest memory — trustworthy again. V2.0 planning docs archived to
`archive/v2.0-planning`; `feature/multi-year-planning` deleted (backup: `backup/feature-myp`).
Details + undo command: `reference/git-topology.md`, decision-log 2026-06-04.

### V1.9 — features bundle
**Status:** In progress on worktrees `1.9/features-bundle` and
`1.9/snapshot-testing-pass-1`. Scope TBD-confirm.

### V2.0 Plan B — Multi-Year Tax Strategy UI
**Status (re-audited 2026-06-18):** Multi-year Roth-optimization engine + Plan-B
year-by-year UI are **substantially built and tested** on `2.0/v2.0.1-path-3-polish`
(furthest branch; ~27.5k lines; `MultiYearTaxStrategyEngine`, `OptimizationEngine`+DP
spike, `ProjectionEngine`, `MultiYearStrategyManager`, full `Year*` UI; 43 test files,
~163+ engine cases). **BUT all 2.0 branches are ~190 commits behind main** (branched
~2026-05-02, pre-1.8.x healthcare bundle and pre-state-tax-refresh). Built against an
**old tax engine** → the dominant remaining cost is **reconciliation onto current
main**, not greenfield. NOT built: plan history/snapshots (only `AccountSnapshot` stub),
HSA full accounts, and the 2.1 decumulation set (brokerage, withdrawal-order).
Old "3-4 weeks" estimate is superseded; true shape = expensive merge + finish
plan-history + HSA + (2.1) decumulation. See decision-log 2026-06-18.

**PRODUCT PRINCIPLE (decision 2026-06-18):** single-year **Scenarios** and **Tax
Summary** tabs are CORE and must NOT be replaced/removed by 2.0/2.1. Multi-year
capability is **additive — likely a brand-new tab** ("Multi-Year Plan") beside the
single-year tools. Verify the Plan-B UI augments, not supplants, during reconciliation.

**Spec:** `docs/superpowers/specs/2026-05-04-2.0-plan-b-multi-year-ui-design.md`
**Plan:** `docs/superpowers/plans/2026-05-04-2.0-plan-b-multi-year-ui.md`
(12 phases, 53 tasks, 145 steps — predates the audit; estimate stale).

### iCloud cross-device sync
**Status:** Scoped, not started. Target v1.9 or v2.x. Opt-in by default
(privacy positioning preserved). Spec: `roadmap/icloud-sync.md`.

---

## Future tracks (parked)

- **V2.1 veteran/federal package:** Military Retirement / Railroad / FERS
  bundled together (see user auto-memory `veteran-federal-income-segment.md`)
- **History Globe (separate project):** scroll-driven 3D Mapbox app on Vercel

---

## Open operational threads (as of 2026-05-30)

1. **macOS 1.8.5 review** — ✅ RESOLVED. Approved & live in the App Store
   (confirmed 2026-06-04). Both platforms now on 1.8.5.
2. **State-tax engine deferrals** — Phase C2 states (NE/NM/WI/VT/OR primary-
   source verification) and engine-API edge cases; see
   `decisions/2026-05-26-50-state-bracket-freshness-audit.md`.
3. **Jonggie** — substantive reply queued; watch for App Store review.
4. 🔐 **Rotate exposed ImprovMX API key** — ✅ RESOLVED 2026-06-04. Old key
   `…b7b1067` deleted (verified HTTP 401); a briefly-exposed replacement
   `…04406` was also deleted (verified 401). Account now has ZERO live API
   keys. Leaked string redacted from 3 memory session files (commit 5576940).
   Note: git history + public `v1.8.5-build50` tag still contain the old
   string, but it's dead — harmless. See decision-log 2026-06-04.
