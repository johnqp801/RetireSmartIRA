# Current Release Roadmap

**Last updated:** 2026-06-04

---

## LIVE: V1.8.5 (iOS build 50, released 2026-05-29 / macOS build 48 live 2026-06-04)

**Status:**
- **iOS 1.8.5 build 50 — ✅ APPROVED & LIVE 2026-05-29.**
- **macOS 1.8.5 build 48 — ✅ APPROVED & LIVE in the App Store (confirmed 2026-06-04).**
  Both platforms now on 1.8.5.

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
**Status:** Engine locked on `2.0/multi-year-engine` (951+ passing tests). UI
work on `2.0/plan-b-ui` (also `2.0/v2.0.1-path-3-polish`). Branched from
`2.0/multi-year-engine`, not main.
**Spec:** `docs/superpowers/specs/2026-05-04-2.0-plan-b-multi-year-ui-design.md`
**Plan:** `docs/superpowers/plans/2026-05-04-2.0-plan-b-multi-year-ui.md`
(12 phases, 53 tasks, 145 steps). Est. 3-4 weeks.

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
