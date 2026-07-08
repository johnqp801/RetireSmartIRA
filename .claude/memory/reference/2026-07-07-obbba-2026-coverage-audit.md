# OBBBA 2026 Coverage Audit — RetireSmartIRA engine vs. law

**Date:** 2026-07-07. **Scope:** individual-tax OBBBA provisions effective TY2026 relevant to retirees / near-retirees, audited against `main` (read-only; the 35% itemized-benefit cap was being built in a parallel session and is excluded). Every law claim carries a source URL; every app claim carries file:line.

**Bottom line:** the engine's 2026 core is in better shape than expected. SALT, AMT, ACA-cliff-return, and the senior bonus are all correctly modeled and match the law. The real gaps are the **charitable AGI ceilings (30%/60%)** — the app's own stock-donation feature can silently over-deduct — plus **QBI** for users with self-employment income, and two low-priority content/disclosure items.

---

## Verified DONE (modeled correctly — no action)

### 1. OBBBA Senior Bonus ($6k/person 65+, phaseout 6% over $75k/$150k MAGI, 2025–2028)
- Law: IRC §151(d) as amended. Already extensively verified in-house (see decisions log 2026-07-06).
- App: `DataManager.standardDeductionAmount` (DataManager.swift:1558) + itemized path (`totalItemizedDeductions`, DataManager.swift:~1877 post-floor edit). **Bonus finding:** it also flows through the **multi-year** engine — `ProjectionEngine.swift:1015–1035` applies the bonus (with per-person phaseout) inside its per-year standard deduction. Multi-year coverage is better than the "standard-deduction-only" label suggests.

### 2. Non-itemizer cash charitable deduction §170(p) ($1,000/$2,000, cash only, 2026+, permanent)
- App: `DataManager.nonItemizerCharitableDeduction` (built 2026-07-07). Single-year only (multi-year has no charitable inputs at all — consistent with limitation M4). Confirmed NOT subject to the 0.5% floor (floor is itemized-path only). DONE.

### 3. 0.5%-of-AGI floor on itemized charitable §170(b)(1) (2026+)
- App: `DataManager.charitableAGIFloor` / `deductibleCharitableDeductions` → floored term in `totalItemizedDeductions` (built 2026-07-07). DONE.

### 4. 35% itemized-deduction benefit cap (2/37 formula, 37% bracket, 2026+)
- IN PROGRESS in a parallel session (task_bf6c96bd). Not audited here; not a gap.

### 5. SALT cap: $40,000 (2025), +1%/yr, 30% phaseout above $500k MAGI (indexed), $10k floor, reverts 2030
- Law: cap $40k 2025 → $40,400 2026, cap AND threshold indexed 1%/yr; reduction = 30% × (MAGI − threshold), never below $10,000; 2025–2029 then $10k. Sources: [Venable](https://www.venable.com/insights/publications/2025/08/salt-alert-final-obbba-temporarily-expands-salt), [HCVT](https://www.hcvt.com/alertarticle-SALT-Deduction-Cap-Increase-Under-OBBBA), [Thomson Reuters](https://tax.thomsonreuters.com/blog/how-the-one-big-beautiful-bill-reshapes-salt-planning/).
- App: `DataManager.saltCap` (DataManager.swift:1723–1744) — `saltBaseCap × 1.01^years` (line 1728–1729), threshold indexed identically (1731), 30% phaseout (1733), `max(saltFloor, …)` (1736), year-gated 2025–2029 with `saltDefaultCap` $10k outside (config). **Matches the law. Modeled: YES.**
- Note: MFS variants ($20k/$250k/$5k) are N/A — the app supports only Single and MFJ (`FilingStatus`, IncomeModels.swift:150–153). App-wide design constraint, not an OBBBA gap.

### 6. AMT 2026: exemption ~$90,100/$140,200; phaseout thresholds RESET to $500k/$1M (indexed from 2027); phaseout rate 25%→50%
- Law: thresholds return to 2018 statutory levels in 2026, rate doubles to 50%, exemptions stay TCJA-level indexed. Sources: [Doeren Mayhew](https://www.doeren.com/viewpoint/alternative-minimum-tax-obbbas-impact-what-you-need-to-know), [KLR](https://kahnlitwin.com/blogs/tax-blog/amt-changes-under-the-big-beautiful-bill-act-what-to-expect-in-2026), [Kitces](https://www.kitces.com/blog/obbba-one-big-beautiful-bill-act-tax-planning-salt-cap-senior-deduction-qbi-deduction-tax-cut-and-jobs-act-tcja-amt-trump-accounts/).
- App: config `amtExemptionSingle: 90100 / MFJ: 140200`, thresholds `500000/1000000`, `amtPhaseoutRate: 0.5` (tax-2026.json); real AMT computation exists — `TaxCalculationEngine.calculateAMT` with SALT+medical addbacks, 50% exemption phaseout, 26/28% rates, cap-gains carve-out. **Matches. Modeled: YES.** (Housekeeping: thresholds index from 2027 — catch in the annual config refresh.)

### 7. ACA 2026: enhanced (ARPA/IRA) subsidies EXPIRED; 400% FPL cliff returns; Rev. Proc. 2025-25 percentages (2.10%→9.96% flat 300–400%)
- Law: enhanced credits ended with 2025; 2026 reverts to 100–400% FPL eligibility with the cliff; applicable percentages per [Rev. Proc. 2025-25](https://www.irs.gov/pub/irs-drop/rp-25-25.pdf); cliff ≈ $62,600 single (2025 HHS guidelines apply to 2026 coverage). Sources: [KFF](https://www.kff.org/affordable-care-act/what-we-know-so-far-about-2026-aca-marketplace-enrollment-premiums-and-deductibles/), [healthinsurance.org](https://www.healthinsurance.org/blog/marketplace-enrollees-face-return-of-the-subsidy-cliff/), [CRS](https://www.congress.gov/crs-product/R48290).
- App: `acaSubsidy2026` config = FPL $15,650/$21,150 (2025 guidelines), applicable figures 0.021→0.0996 with 1.0 at 400% (`hasCliff: true`); `ACASubsidyEngine` derives the cliff from the first `applicableFigure >= 1.0` row and zeroes the subsidy above it (ACASubsidyEngine.swift:45–58), interpolating within bands (:75–81). **Matches current law. Modeled: YES.** (This was pre-OBBBA law reasserting itself; the config was already refreshed in 1.8.7.)

---

## GAPS (ranked)

### G1 — Charitable AGI ceilings: 60% cash / 30% appreciated property (permanent under OBBBA) — **HIGH for this app**
- Law: cash gifts to public charities deductible up to 60% of AGI (made permanent by OBBBA); appreciated long-term property (stock) capped at **30% of AGI**; excess carries forward 5 years. Sources: [Greenberg Traurig](https://www.gtlaw.com/en/insights/2025/10/new-limitations-on-charitable-deductions-take-effect-in-2026), [Fidelity Charitable](https://www.fidelitycharitable.org/articles/obbb-tax-reform.html).
- App: **no ceiling of any kind.** `scenarioCharitableDeductions` (DataManager.swift:1848) sums stock FMV + cash and, after the new 0.5% floor, flows uncapped into `totalItemizedDeductions`. Grep for 60%/30% charitable limits: none.
- Impact: app **understates tax** when gifts exceed the ceilings. The 30% stock ceiling is the dangerous one because the app *actively promotes* stock-donation scenarios: e.g. $60k stock gift on $150k AGI → law allows $45k this year (rest carries forward); app deducts the full $60k. Direction: under-tax; affected: exactly the users the stock-donation feature targets.
- Priority: **HIGH** (30% stock ceiling), 60% cash ceiling MEDIUM (harder to hit). Carryforward modeling can be phase 2 (start by capping + showing "excess carries forward" note).

### G2 — QBI §199A: made permanent + new $400 minimum deduction (2026) — **MEDIUM-LOW**
- Law: 20% QBI deduction permanent; 2026 adds wider phase-in ranges and a $400 minimum deduction for ≥$1,000 of active QBI. Sources: [IRS](https://www.irs.gov/newsroom/qualified-business-income-deduction), [RSM](https://rsmus.com/insights/services/business-tax/obbba-tax-qbi-deduction.html).
- App: not modeled anywhere; yet the app HAS an "Employment/Other Income" type (`case consulting`, IncomeModels.swift:120) used for consulting/self-employment income.
- Impact: **overstates tax** for semi-retired consultants (a real slice of the audience). Full QBI (SSTB limits, wage caps) is complex; a simplified 20%-of-Schedule-C-profit version with a disclosure would capture most cases.
- Priority: MEDIUM-LOW. At minimum add a disclosure that QBI is not modeled.

### G3 — HSA: all bronze + catastrophic ACA plans deemed HDHP-eligible (2026) — **LOW (content, not engine)**
- Law: from 2026-01-01, individual-market bronze/catastrophic plans qualify for HSA contributions regardless of deductible ([IRS](https://www.irs.gov/newsroom/treasury-irs-provide-guidance-on-new-tax-benefits-for-health-savings-account-participants-under-the-one-big-beautiful-bill), IRS Notice 2026-5).
- App: HSA contribution is user-entered; eligibility is the user's assertion; limits are current (config: 4400/8750/+1000). Engine change: none needed. Opportunity: the Reduce-AGI / HSA guidance copy should mention that early retirees on ACA bronze plans can now fund an HSA — squarely this app's audience (bridge-years ACA users doing Roth conversions).
- Priority: LOW engine / nice content win.

### G4 — Estate/gift exemption $15M per person (2026, permanent, indexed) — **LOW (disclosure only)**
- Law: $15M/person ($30M couple) from 2026, permanent, indexed ([Morgan Lewis](https://www.morganlewis.com/pubs/2025/10/irs-announces-increased-gift-and-estate-tax-exemption-amounts-for-2026)).
- App: models heir INCOME tax only (`LegacyPlanningEngine.heirTaxOnInheritedTraditional`; taxable step-up in `HeirValue`). No federal estate tax anywhere — which is **correct by omission** for virtually all users under a $15M/$30M exemption. But no disclosure says so: grep of `V2Disclosures.swift` / `AssumptionsLimitationsView.swift` finds no estate mention.
- Priority: LOW — add one disclosure line ("assumes estate below the federal exemption; estate tax not modeled").

### G5 — Multi-year flow-through of the new charitable items — **known-limitation footnote**
- `ProjectionEngine` remains standard-deduction-only (no itemized path, no charitable inputs, no §170(p)). The senior bonus IS in multi-year (ProjectionEngine.swift:1015–1035). Net: single-year and multi-year now diverge slightly for cash donors (single-year gives §170(p); multi-year doesn't). Existing M4 limitation, marginally widened. Fold into the 2.1 itemized/charitable-layer work; no separate fix.

### N/A for this audience (checked, intentionally not modeled)
- **Tips deduction** (up to $25k) and **overtime deduction** — W-2 worker provisions.
- **Car-loan interest deduction** — new-vehicle personal loans; not a retirement-planning input.
- **Trump accounts** — under-18 accounts. (Tiny content angle: grandparents can contribute; not an engine item.)
- **Wagering-loss 90% limitation** — app doesn't model gambling income.
- **Misc 2% itemized deductions repealed permanently / personal exemption $0 permanent / Pease→2/37** — app never modeled the first two; 2/37 in progress.
- **Mortgage $750k acquisition-debt cap permanent + PMI-as-interest (2026)** — app takes mortgage interest as a user-entered `DeductionItem` without enforcing debt caps; generic input-trust limitation, not an OBBBA gap.

---

## Recommended next fixes (ranked)

1. **Charitable AGI ceilings (G1)** — cap appreciated-stock gifts at 30% of AGI and cash at 60% in the itemized path (single-year), with an "excess carries forward (not yet modeled)" note. Completes the charitable stack begun with the 0.5% floor + §170(p). Engine + tests, same TDD pattern.
2. **QBI disclosure now; simplified §199A later (G2)** — one disclosure line immediately; a simplified 20% QBI deduction for consulting income as a 2.1 candidate.
3. **HSA-on-bronze content nudge (G3)** — copy update in the HSA/Reduce-AGI guidance; pairs perfectly with the ACA-cliff-return story for bridge-year retirees.
4. **Estate-tax disclosure line (G4)** — one sentence in V2Disclosures / Assumptions & Limitations.
5. **Config-refresh reminders** — AMT phaseout thresholds index from 2027; SALT cap/threshold already self-index in code. Catch in the annual TY2027 refresh.

*Not committed — file written for review. Sources inline above.*
