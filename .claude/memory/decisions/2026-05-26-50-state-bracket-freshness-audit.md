# 50-State Tax Data Freshness Audit

**Date:** 2026-05-26
**Trigger:** Gap 3 from CA bracket freshness audit (`decisions/2026-05-26-CA-bracket-freshness-audit.md`)
**Scope:** All 43 configured states with income tax (CA excluded — fixed today)
**Status:** Discovery complete. Fixes scoped but NOT yet applied — pending user decision on scope and TY policy.

---

## Triage table (sorted by severity)

| State | Code vintage (inferred) | Latest published | Severity | Notes |
|---|---|---|---|---|
| **Louisiana** | TY 2024 progressive 1.85/3.5/4.25 | **TY 2025 flat 3%** (HB 10, 2024) | 🔴 STRUCTURAL | Entire tax system changed; code overtaxes every LA filer |
| **Kansas** | Pre-2024 3-bracket 3.1/5.25/5.7 | TY 2024+ 2-bracket 5.2/5.58 (SB 1) | 🔴 STRUCTURAL | Bracket count + rates wrong |
| **Montana** | "Flat 4.7%" | TY 2024+ 2-bracket 4.7/5.9 | 🔴 STRUCTURAL | MT is not flat; top rate 5.9% missing |
| **North Dakota** | "Flat 1.95%" | TY 2024+ progressive 0/1.95/2.5 | 🔴 STRUCTURAL | ND has 3 brackets incl. 2.5% top, not flat |
| **Hawaii** | TY 2023 brackets + invented std ded | TY 2025 (Act 46 widening + ded increase) | 🔴 HIGH | Brackets ~10% stale; std deduction $8K/$16K does not match HI actual ($4.4K/$8.8K) |
| **Connecticut** | Pre-2024 (3% / 5% bottom) | TY 2024+ (2% / 4.5% rate cut) | 🔴 HIGH | Material rate cut missed |
| **Arkansas** | TY 2024 top 4.4% | TY 2025 top 3.9% | 🔴 HIGH | Top rate cut Apr 2024 retroactive to TY 2024 |
| **Michigan** | TY 2023 (4.05%) | TY 2024+ reverted to 4.25% | 🔴 HIGH | 4.05% was one-year trigger TY 2023 only |
| **Maryland** | std deduction $4,100/$8,200 | TY 2025 max $2,700/$5,450 (15% AGI cap) | 🔴 HIGH | Std deduction appears materially wrong/too high |
| **Rhode Island** | TY 2023 thresholds | TY 2025 ($79,900/$181,650) | 🔴 HIGH | Brackets ~9% stale (2+ inflation cycles) |
| West Virginia | TY 2023/24 top 5.12% | TY 2025 top 4.82% (trigger) | 🟡 MEDIUM | Trigger-based reduction missed |
| Missouri | TY 2024 top 4.7% | TY 2025 top 4.5% (trigger met) | 🟡 MEDIUM | Top rate 1yr stale |
| Minnesota | TY 2024 brackets + std ded | TY 2025 (~3% indexed) | 🟡 MEDIUM | Brackets + std deduction 1yr stale |
| Vermont | TY 2024 brackets | TY 2025 (~5% indexed) | 🟡 MEDIUM | 1yr stale |
| Oregon | TY 2024 brackets + std ded | TY 2025 | 🟡 MEDIUM | 1yr stale |
| Wisconsin | TY 2024 brackets | TY 2025 (~2.5% indexed) | 🟡 MEDIUM | 1yr stale |
| Maine | TY 2024 thresholds | TY 2025 | 🟡 MEDIUM | 1yr stale |
| Nebraska | TY 2024 brackets (rates OK) | TY 2025 brackets indexed | 🟡 MEDIUM | Rate ✅; thresholds 1yr stale |
| Delaware | TY 2024 std ded $3,250/$6,500 | TY 2025 $5,700/$11,400 (HB 89) | 🟡 MEDIUM | Std deduction nearly doubled |
| South Carolina | TY 2024 top 6.3% | TY 2025 top 6.2% | 🟡 MEDIUM | Top rate -10bp; comment claims "2026" but isn't |
| New Mexico | Pre-2025 brackets | TY 2025 (HB 252 restructure) | 🟡 MEDIUM | Verify bracket restructure |
| DC | TY 2024 std ded $14,600/$25,900 | TY 2025 $15,000/$30,000 | 🟢 LOW | Std deduction 1yr stale; brackets ✅ |
| Georgia | TY 2024 flat 5.39% | TY 2025 5.19% (HB 111 accel.) | 🟢 LOW | Rate -20bp; comment claims "2026" but TY26 scheduled 4.99% |
| Idaho | TY 2024 5.695% | TY 2025 5.3% | 🟢 LOW | Rate -39bp; comment claims "2026" but isn't |
| Virginia | std ded $8,750/$17,500 | TY 2025 $8,500/$17,000 | 🟢 LOW | Slight over; brackets static ✅ |
| New York | TY 2024/25 brackets | TY 2025 | 🟢 LOW | Brackets stable, std ded ✅ |
| Oklahoma | TY 2024 brackets/std ded | TY 2025 | 🟢 LOW | Reasonably current |
| Indiana | Flat 2.95% (claimed 2026) | TY 2025 3.00%, TY 2026 2.95% scheduled | 🟢 LOW | Slightly ahead — using TY2026 scheduled rate |
| Kentucky | Flat 3.5% (claimed 2026) | TY 2025 4.0%, TY 2026 3.5% scheduled | 🟢 LOW | Ahead — uses TY2026 scheduled rate |
| North Carolina | Flat 3.99% (claimed 2026) | TY 2025 4.25%, TY 2026 3.99% scheduled | 🟢 LOW | Ahead — uses TY2026 scheduled rate |
| Ohio | Flat 2.75% (claimed 2026) | TY 2024 prog 2.75/3.5; flat 2.75 TY 2026 sched | 🟢 LOW | Ahead — uses TY2026 scheduled; TY 2025 still has 3.5% top |
| Mississippi | Flat 4.4% | TY 2025 4.4%, TY 2026 4.0% scheduled | ✅ CURRENT | Matches TY 2025 |
| Arizona | Flat 2.5% | TY 2025 2.5% | ✅ CURRENT | Stable since 2023 |
| Colorado | Flat 4.40% | TY 2025 4.40% | ✅ CURRENT | (TABOR may trigger temp 4.25% some years) |
| Iowa | Flat 3.8% | TY 2025 3.8% | ✅ CURRENT | |
| Illinois | Flat 4.95% | TY 2025 4.95% | ✅ CURRENT | Stable since 2017 |
| Massachusetts | Flat 5% | TY 2025 5% (+4% surtax >$1M not modeled) | ✅ CURRENT | Note: 4% surtax on >$1M missing |
| Pennsylvania | Flat 3.07% | TY 2025 3.07% | ✅ CURRENT | |
| Utah | Flat 4.55% | TY 2025 4.55% | ✅ CURRENT | |
| Alabama | 2/4/5% | TY 2025 unchanged | ✅ CURRENT | |
| New Jersey | 1.4%–10.75% | TY 2025 unchanged | ✅ CURRENT | Brackets static since 2020 |
| New Hampshire | No-tax (specialLimited) | I&D repealed effective 2025 | ✅ CURRENT | Comment correctly notes 2025 repeal |
| Washington | No general income tax | TY 2025 ✅ | ✅ CURRENT | 7% LTCG handled separately |

## Top fixes by user impact (agent's ranking)

Ordered by likely-affected filer count × delta magnitude:

1. **Michigan** — populous (10M), rate wrong by 20bp; affects every MI filer; one-line fix
2. **Connecticut** — high-tax, dense retiree population; missed 2024 rate cuts
3. **Louisiana** — entire tax system changed to flat 3% TY 2025; structural rewrite
4. **Kansas** — structural (3 brackets → 2); most KS filers now in 5.2% bracket code doesn't have
5. **Hawaii** — high-tax; brackets compressed at low thresholds means retirees hit top brackets too quickly; std deduction appears invented
6. **Maryland** — std deduction overstated by ~$1.5K/$2.7K → systematically undertaxes MD filers
7. **Montana / North Dakota** — both modeled as "flat" but are progressive
8. **Arkansas** — top rate 4.4% → 3.9% (50bp cut affects nearly all AR filers, since top bracket starts at $8,800)
9. **West Virginia** — trigger reduced top to 4.82%; code at 5.12% overtaxes
10. **Rhode Island** — bracket thresholds 9% stale
11. **Delaware** — std deduction nearly doubled by HB 89; understates DE filer deduction
12. **Missouri** — top rate 4.7% → 4.5%; affects nearly all MO filers

## Strategic / product decisions surfaced by audit

### 1. TY 2025 actuals vs. TY 2026 scheduled

Five states (IN, KY, NC, OH, MS) have code values that match **TY 2026 scheduled rates** rather than TY 2025 actuals. The code comments even say "(2026)" for these. This is technically wrong for a user filing a TY 2025 return today.

**Product question:** What tax year is the app modeling? Options:
- **A.** TY 2025 actuals (what users actually pay this year) — must roll back the "ahead of schedule" states
- **B.** TY 2026 actuals (forward-looking; press kit says "2026 IRS limits") — must roll forward 24+ states currently behind schedule, including newly-fixed CA (which would mean using projected/indexed 2026 values that haven't been officially published)
- **C.** Hybrid — federal on TY 2026, state on latest published (TY 2025) — current de facto state, but inconsistent and confusing

Recommend documenting whatever policy is chosen prominently in `StateTaxData.swift` header comment so the next maintainer (or AI) knows the rule.

### 2. The 4% MA surtax on income >$1M is missing

Affects high-net-worth retirees in MA. Probably outside the typical retiree demo, but worth modeling for completeness.

### 3. HoH brackets globally missing

Already logged from CA audit. Same applies to every state with separate HoH brackets (most states with progressive tax).

### 4. WA LTCG threshold

Washington's 7% capital gains tax above $262K (TY 2025, indexed from $250K). Audit didn't deeply verify this is current.

## Suggested fix scope batches

**Batch 1 — "Most user-impactful structural fixes" (~3-4 hours work):**
- Louisiana — convert from progressive to flat 3%
- Kansas — restructure from 3 → 2 brackets
- Montana — convert from "flat" to 2-bracket progressive
- North Dakota — convert from "flat" to 3-bracket progressive
- Michigan — one-line rate change 4.05% → 4.25%

**Batch 2 — "High-severity non-structural" (~2 hours):**
- Hawaii — bracket refresh + std deduction correction
- Connecticut — rate cut to 2%/4.5% on bottom brackets
- Arkansas — top rate 4.4% → 3.9%
- Maryland — std deduction correction
- Rhode Island — bracket refresh

**Batch 3 — "Medium severity 1-yr stale refreshes" (batch task, ~2 hours):**
- WV, MO, MN, VT, OR, WI, ME, NE, DE, SC, NM, DC, GA, ID, VA, OK + the std-ded-1yr-stale items

**Batch 4 — "TY policy decision" (product call, 1 hour discussion):**
- Decide TY 2025 vs TY 2026 vs hybrid policy
- Roll affected states forward or back based on policy

**Batch 5 — "Missing features":**
- MA 4% surtax on income >$1M
- HoH brackets across all states (depends on engine API change from CA audit)

## Process recommendations

- **Make the StateTaxData.swift file machine-checkable.** Add structured comments per state with `TY: YYYY` and `LastVerified: YYYY-MM-DD` markers, plus a top-of-file table summarizing vintage per state.
- **Annual January refresh task.** Add a scheduled routine (via `/schedule`) to dispatch this same audit-agent every January, producing a fresh delta table to triage before TY filing season.
- **Test coverage per state.** Currently only CA has bracket-pinning tests. Add pinning tests for at least the top-10 user-impact states.
- **Decide press claim accuracy.** Press kit says "All 50 states · 2026 IRS limits · 7 tax mechanics." Federal is true; state is not uniformly current. Either: (a) tighten state engine before next press push, or (b) soften the press claim.

## Branches

- This audit was conducted on `feature/multi-year-planning`
- Fixes will need to land on this branch AND be cherry-picked to `1.8.4/incremental` (or the next release branch) for shipped users to benefit. Same hygiene note as the CA fix.

## Source

Discovery via independent general-purpose research agent (gen-purpose agent type), 2026-05-26 afternoon session, ~95-second runtime, 3 tool uses. Agent ID `ad9370918afdbf622` (still resumable if we need follow-up on specific states).
