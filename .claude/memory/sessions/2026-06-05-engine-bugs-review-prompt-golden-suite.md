# 2026-06-05 — Engine bug fixes, review-prompt feature (1.8.6), golden-case suite

## What happened this session (large session — many things)

---

## 1. macOS 1.8.5 confirmed live
Both platforms now on 1.8.5. Roadmap updated.

---

## 2. `main` reconciliation — ✅ COMPLETED
- **Problem:** `main` was 207 commits stale (reported v1.8.0, missing all 1.8.x, no `.claude/memory/`). Releases had shipped from worktree branches/tags and never merged back.
- **Fix:** Pointed `main` at `v1.8.5-build50` tree + synced latest memory; archived `main`'s 10 V2.0-planning-doc commits to `archive/v2.0-planning`; deleted `feature/multi-year-planning` (backup: `backup/feature-myp`). Force-pushed `main` (solo dev).
- `main` is now canonical shipped code (MARKETING_VERSION 1.8.5 / build 49).

---

## 3. ImprovMX API key rotation — ✅ COMPLETED
- **Exposure:** key `sk_2edc0c27…b7b1067` was in 3 committed memory files on a PUBLIC GitHub repo, still live (HTTP 200).
- **Fix:** Deleted key + replacement (both verified 401). Account now has ZERO live keys. Leaked string redacted from memory files (commit `5576940`).
- **Rule:** Never screenshot or paste API keys. Generate ad-hoc only when needed.

---

## 4. Engine bug: stock-gain-avoided double-count — ✅ FIXED (branch, not yet on main)
**Root cause discovered during dogfooding the app against user's own 2025 tax return.**

The `scenarioStockGainAvoided` (donated stock's unrealized gain, e.g. $74,999) was being **subtracted from gross income AND from NII** even though the gain was never realized and was never in income. The donation's benefit is fully captured by the charitable deduction.

**6 sites fixed** in `DataManager.swift`:
1. `scenarioGrossIncome` (the main bug) — understated taxable income by $74,999
2. `scenarioNetInvestmentIncome` (NIIT bug, found via ChatGPT audit) — suppressed NII, caused $0 NIIT when $2,546 was correct
3. 4 per-decision impact counterfactuals (Roth/withdrawal/QCD/inherited-IRA "Tax Impact Waterfall" deltas)

**Cascade impact:** Also understated MAGI (used for NIIT + IRMAA). Before fix: NIIT showed $0 (wrongly "below $250k threshold"); IRMAA showed wrong tier. After fix: NIIT $1,924 initially, then found to be $2,546 correct after NII fix.

**4 pre-existing tests corrected** (they had asserted the buggy subtraction behavior).
**2 new tests added** pinning correct behavior.
**Tests:** 1,242 → 1,253 passing.

---

## 5. In-app review-prompt feature — ✅ BUILT (on branch, 1.8.6 bundle)

### Design (approved)
- `@Observable ReviewPromptManager` — pure decision logic + 2 UserDefaults keys; no StoreKit
- **Trigger:** ≥ 4 Scenario↔Tax-Summary (tab 5↔6) switches **OR** ≥ 6 debounced recalcs (1s debounce, slider drag = 1)
- **Fire:** next app launch only (never mid-session; "rich session + returned" signal)
- **Gate:** once per app marketing version + iOS OS throttle; no maturity floor
- **Manual:** "Rate RetireSmartIRA" row in Settings → `macappstore://…?action=write-review` (macOS) / `https://…` (iOS), App ID 6759405282
- **Per-session gate:** `armedAtLaunch` flag — pending request earned in Session N only fires in Session N+1's launch

### Implementation (6 TDD tasks, subagent-driven)
- `ReviewPromptManager.swift` — 9 unit tests covering all decision paths
- Wired into: `RetireSmartIRAApp` (inject), `ContentView` (.task launch + .onChange tab switch), `TaxPlanningView` (scenarioBinding setter), `SettingsView` (Rate row)
- Both platforms build; 1,251 tests passing after all 6 tasks
- `requestReview` placed at ContentView scope (App scope doesn't resolve on both SDKs)
- Tab 5 = Scenarios, Tab 6 = Tax Summary; `Group` wrapper avoids double-counting on iPad

---

## 6. Version bump: 1.8.6 / build 51

All of the following are bundled on branch `fix/stock-gain-avoided-double-count`:
1. Stock-gain-avoided double-count fix (6 sites + tests)
2. In-app review-prompt feature (9 tests, both platforms)
3. Version 1.8.6 / build 51

**Branch not yet merged to main or pushed.** User chose "Keep as-is" when the finishing skill offered options.

---

## 7. SS taxation bug — ✅ FIXED (same branch)

**Root cause found during IRS golden-case research:**
`TaxCalculationEngine.swift` line ~770 — the tier-2 branch of `calculateTaxableSocialSecurity` was missing the IRS Pub 915 Worksheet 1 **line-14 cap**: the 50%-taxed tier must be `min(0.5 × band, 0.5 × gross_SS)`. Without the cap, when gross SS falls below the threshold band ($9k single / $12k MFJ) but income reaches the 85% tier, taxable SS was overstated.

Example: IRS Pub 915 Example 3 (MFJ, SS $10k, other $40.5k) → engine returned $7,275 vs correct **$6,275**.

**Fix:** `let tier1Amount = min((threshold2 - threshold1) * 0.5, ssIncome * 0.5)` (one-line)
**Tests:** 2 new golden tests (IRS Pub 915 Ex. 3 + hand-verified single case). Full suite: 1,253 passing.

---

## 8. Golden-case test suite built — `IRSGoldenCaseTests.swift`

### IRS oracle cases (primary sources, TY2025/2026):
- **Pub 915 Ex. 1 (SS):** Single, SS $5,980 + pension $18,600 + wages $9,400 → taxable SS **$2,990**
- **Pub 590-B Ex. 1 (RMD):** Balance $100k, age 75, divisor 24.6 → RMD **$4,065**; divisor directly asserted
- **NIIT Q&A Ex. A:** MFJ, NII $225k, MAGI $300k → NIIT **$1,900** (3.8% × $50k excess)
- **E2E stock-donation regression:** avoided gain does not reduce gross income OR NII (pins all 3 engine bugs together)

### OBBBA persona sub-calculations (TY2026, IRS-worksheet-computed, NOT Gemini's numbers):
- **Persona 3 (Conversion Window):** taxable SS = $34k (Gemini said $40k — they used gross not taxable); senior deduction = $12k (MAGI $149k just under $150k threshold)
- **Persona 4 (RMD Management):** taxable SS = $21,250; senior deduction = $5,625 (MAGI $81,250 > $75k threshold → partially phased; Gemini said $6k)
- **Senior deduction full phase-out:** MFJ both-65 at MAGI $250k → $0 (confirming legal research)

**Critical note on Gemini scenarios:** Use as input templates only. Their tax totals are wrong: they used gross SS instead of taxable SS in AGI, and ignored the senior-deduction phase-out. Do not use their tax-line numbers as golden values.

---

## 9. OBBBA senior deduction: engine is CORRECT

**Research question:** Per-person vs. combined phase-out for MFJ both-65.
**Answer (HIGH confidence):** The engine's per-person implementation is **correct**.

Statutory text (IRC §63(f)(5)): "*$6,000 for each qualified individual*" and "*the $6,000 amount … reduced (but not below zero) by 6% of excess MAGI*."

IRS Schedule 1-A worksheet: computes one per-person reduced amount (Line 35 = $6,000 − 6% × excess), then each qualifying spouse claims it separately (Lines 36a, 36b). Sum at Line 37.

At MAGI $220k MFJ both-65: engine returns $3,600 ✅ (NOT $7,800 which the "combined" reading gives).
Full phase-out at **$250,000 MAGI** for MFJ both-65.

The IRC §151(d)(5)(B) analogy the engine used is unnecessary but points in the right direction — the statute is unambiguous without it.

---

## 10. TY2024/2025 configs created — NOT YET COMMITTED (pending test suite green)

Files `tax-2024.json` and `tax-2025.json` created, sourced values:
- SALT: 2024 = $10k (TCJA), 2025 = $40k (OBBBA retroactive) ← key difference
- Standard deduction: 2024 $14,600/$29,200; 2025 $15,750/$31,500 (OBBBA-amended)
- Senior bonus: 2024 disabled (firstYear=9999), 2025 enabled ($6k/person, 2025-2028)
- IRMAA, brackets, QCD limits, contribution limits all sourced
- **Stride bug fixed:** `loadOrFallback` had `stride(from: year-1, through: 2026, by: -1)` = empty range for any year ≤ 2026. Fixed to `through: 2000`.
- 3 pre-existing QCD tests corrected (were testing absent-JSON fallback, now real values)
- 1 CA regression test corrected (needed `currentYear = 2026` pin after singleton became year-sensitive)
- **FLAGGED uncertainties:** 2024 IRMAA Tier-2 Part D ($33.00), CA MFJ phaseout thresholds, ACA benchmark silver premiums (estimated)

---

## Open threads as of end of session

1. **Branch `fix/stock-gain-avoided-double-count`** — 1.8.6 bundle (engine fixes + review prompt + golden suite + configs), tests green (target 1,260+), needs merge → main + push
2. **Manual smoke test** before App Store submit: launch app, bounce Scenarios↔Tax-Summary 4x, quit and relaunch → review sheet fires once; check Settings "Rate" link on macOS
3. **Submit 1.8.6** to App Store Connect (build 51)
4. **IRMAA Tier-2 Part D 2024:** verify $33.00 vs CMS-8085-N
5. **CA MFJ phaseout thresholds 2024/2025:** verify against FTB 540 booklet
6. **Dividend field UX fix** (still open from earlier): relabel "Ordinary Dividends" → "Non-Qualified Dividends" + inline "Box 1a − Box 1b" hint (the bug that caused user's own double-count)
7. **Stale `main`** re: `backup/feature-myp` (local) and `archive/v2.0-planning` (origin) — cleanup when convenient

---

## Context from the tax-return sanity check

User entered their 2026 scenario; cross-checked against their 2024/2025 Two-Year Federal Comparison (ProSeries). Key finding: after the SS and stock-donation fixes, the 2026 projection tracks history:
- 2024: taxable income $297,824 / fed tax $52,336
- 2025: taxable income $367,336 / fed tax $62,872
- 2026 (corrected): taxable income $202,357 / fed tax $28,127 (lower due to ~$115k IRA distributions vs prior ~$210-228k + $75k stock donation)
