# Decision: CA TY 2025 brackets shipped, broader audit scoped

**Date:** 2026-05-26
**Trigger:** John spotted incorrect MFJ bracket dollar values in the in-app California bracket UI ($21K/$49K/$78K/$108K/$137K/$698K — those are TY 2023 values doubled from single).
**Status:** CA fixed and committed (`b9d6413`). Three related gaps scoped as follow-ups.

---

## What we fixed today

`RetireSmartIRA/StateTaxData.swift` — CA `single` and `married` bracket thresholds were TY 2023 values, ~3 inflation cycles stale. Updated to TY 2025 per CA FTB 2025 Form 540 Tax Rate Schedules.

- Source: https://www.ftb.ca.gov/forms/2025/2025-540-tax-rate-schedules.pdf
- Verified via independent research agent against the official FTB 2025 Form 540 instructions PDF.

Standard deduction in code (`$5,706 / $11,412`) was already correct for TY 2025. MHST $1M threshold is statutory (not indexed) — unchanged.

## Three follow-up gaps discovered during the fix

### Gap 1 — HoH bracket schedule missing

California has a **separate Head of Household bracket schedule (Schedule Z)** that's meaningfully different from both Single (Schedule X) and MFJ (Schedule Y):

| Rate | HoH bracket starts | Single bracket starts | MFJ bracket starts |
|---|---|---|---|
| 1.0% | $0 | $0 | $0 |
| 9.3% | $98,990 | $72,724 | $145,448 |

A HoH user at $90K AGI is in the 8% bracket per CA FTB, but mapped to single brackets they'd be in the 9.3% bracket. Material divergence.

**Current code:** `StateTaxConfig.taxSystem.progressive(single:, married:)` doesn't have an HoH slot at all. The engine maps `.headOfHousehold` filing status to... something. Need to trace `DataManager.swift` line 795 area where `filingStatus == .single ? single : married` — likely HoH → married, which is wrong.

**Fix scope:** Either add `headOfHousehold:` parameter to `.progressive(...)` (preferred — clean API), or add a separate HoH overlay. Then add Schedule Z data for CA and any other state with separate HoH brackets.

### Gap 2 — MFS bracket mapping wrong

California publishes Schedule X as "Single OR Married Filing Separately." Both use the same bracket thresholds. But the current engine maps `.marriedFilingSeparately` → married brackets (Schedule Y), not single. That makes MFS filers see roughly half the rate they should at any given income level.

**Fix scope:** Engine logic change. Anywhere `filingStatus == .single ? single : married` runs, change to `filingStatus == .single || filingStatus == .marriedFilingSeparately ? single : married`. Roughly 4-5 sites per grep results above.

### Gap 3 — 50-state bracket freshness audit needed

If CA was TY 2023 stale, **every other state with income tax may also be stale**. The 2026-05-19 state-tax-consistency-audit memo focused on engine-vs-view consistency and PA-specific issues — bracket vintage was NOT audited.

**Fix scope:** Larger. Each progressive state (~41 of them) needs verification that brackets in `StateTaxData.swift` match the most recently published rate schedule from that state's tax authority. Suggest:
1. Dispatch a research agent with the full state list and a per-state primary-source preference (state DOR/Franchise Tax Board/Revenue Department)
2. Build a table of (state, code-vintage, current-vintage, deltas)
3. Prioritize fixes by user-facing impact (states with the largest deltas, or with material rate changes since the in-code vintage)

The press kit at retiresmartira.com/press claims "2026 IRS limits" and "All 50 states." Both claims are sound at the federal level (we know federal brackets are current), but the state engine is now demonstrably not uniformly current. Worth fixing before next press push or risk a journalist with a state-tax checker noticing.

## Why this happened

Speculation: state bracket data was loaded once when the engine was originally built (TY 2023 was the working year at the time) and never reindexed. CA's standard deduction was bumped at some point to TY 2025 (someone caught that), but the brackets escaped the same update. No process for annually refreshing state tax data exists.

## Process change to consider

Add an annual checklist task: **"Each January, audit state tax data against newly published TY brackets."** Should live in `.claude/memory/roadmap/` or a recurring scheduled routine. Currently we have no such cadence and that's why this drifted.

## Branches

- Fix landed on `feature/multi-year-planning` as `b9d6413`
- **Needs cherry-pick to `1.8.4/incremental` (or wherever next release work happens)** before next App Store submission. CA users on shipped 1.8.4 will continue to see the stale TY 2023 brackets until the next release. Severity: moderate — affects bracket-position UI accuracy and Roth conversion sizing precision; doesn't cause illegal tax calculations.

## Tests

New pinning tests cover the MFJ case from the screenshot ($128K → 8% bracket → $5,008.10). Single $50K and $100K test expectations updated to TY 2025 values. Math verified by hand and via the research agent's bracket data.

## Severity rating

For shipped users (CA, TY 2023 brackets):
- **Roth conversion sizing:** off by one bracket-cycle, ~10-12% error in marginal rate at certain income levels
- **"Room before next bracket" display:** off by ~$2K-$9K depending on bracket
- **Average rate displayed:** off by 0.1-0.3 percentage points
- **Not catastrophic but not negligible.** Worth a 1.8.5 patch release rather than waiting for 1.9.

## Related items

- 2026-05-19 state-tax-consistency-audit (`decisions/2026-05-19-state-tax-consistency-audit.md`) — scope was engine-vs-view, not bracket freshness
- 2026-05-19 qualified-dividends-ltcg audit — adjacent state-tax accuracy work
- This audit (CA bracket freshness) is the **third state-tax audit thread** in two weeks — strong signal that state-tax data needs a recurring process.
