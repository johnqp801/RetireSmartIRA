# Ron Park feedback — fixes tracking

**Purpose:** Running log of everything shipped (or consciously deferred) in response to Ron Park's beta review of RetireSmartIRA on 2026-04-23. Updates as items land; becomes the basis for an email update back to Ron.

**Branch:** `ron-feedback-fixes`
**Target release:** 1.7.2 (or 1.8, depending on scope when we ship)
**Previous release:** 1.7.1 (in App Store review — builds 28/29)

**Status legend:**
- ✅ **Shipped** — landed on the branch, tests passing
- 🔧 **In progress** — actively working
- 📋 **Queued** — on the list, not yet started
- 💬 **Deferred** — explicit decision to push to a later release
- ⚠ **Needs discussion** — TBD with Ron

---

## ✅ Shipped

### Fix #1 — Roth Conversion $1 → $702 phantom tax (credibility-killer)

**What Ron saw:** Dragging the Roth Conversion slider to $1 reported an "Additional Tax" of $702. Marginal rate of 70,200% is obviously wrong.

**Root cause:** The internal `totalTaxFor` helper — used by every per-decision tax-impact calc — was computing state tax via a function (`calculateStateTax`) that ignores state-specific Social Security exemptions. The scenario's authoritative state-tax function (`calculateStateTaxFromGross`) honors them. In California and the ~20 other SS-exempt states, the two functions diverged by hundreds of dollars of phantom state tax, polluting every impact number.

**What's fixed:** All 7 per-decision tax-impact calculations now compute correctly in SS-exempt states:
- Roth Conversion impact
- Extra Withdrawal impact
- Inherited Extra Withdrawal impact
- QCD tax savings
- Stock donation deduction savings
- Stock capital-gains-avoided
- Cash donation savings

**Regression tests:** 2 new tests lock in the invariant that per-decision impact must equal the actual scenario tax delta, specifically for CA + Social Security + dividends scenarios. Prevents this class of bug from regressing silently.

**Commit:** `9decc15` — "Fix per-decision tax impacts in SS-exempt states"

---

### Fix #2 — Slider ↔ text box not updating in Scenarios

**What Ron saw:** "Moving the sliders doesn't auto populate the text box (where you can manually enter $)."

**Root cause:** The shared `CurrencyField` component had a `!isFocused` guard on its slider-to-text sync logic. On macOS, clicking a Slider doesn't clear a TextField's focus state — so once the user had ever clicked into the text field, every subsequent slider drag was silently ignored by the text display.

**What's fixed:** Removed the focus guard. Slider moves now always update the adjacent text box. Because `CurrencyField` is shared across the Scenarios tab, this fix applies to **every slider**: Roth Conversion, Extra Withdrawal, inherited-IRA withdrawals, QCD, stock donation, cash donation.

Implementation replaced the whole `CurrencyField` with SwiftUI's built-in `TextField(value:format:)` — single source of truth, no local `@State` string, no `@FocusState` sync. Deletes ~45 lines of fragile sync logic and eliminates the bug class, not just this instance.

**Commit:** `25f8b39` — "Fix Slider ↔ text box not updating in Scenarios"

---

### Fix #3 — Roth Conversion double-entered (Income page + Scenarios slider)

**What Ron saw:** It was possible to enter a Roth Conversion as an income type on the Income page *and* drag the Scenarios slider. Both stacked, double-counting the conversion in every tax calc.

**Root cause (architectural):** `IncomeType` had a `.rothConversion` case that predated the Scenarios slider. A Roth conversion isn't really "income I received" — it's a decision the planner models. Having it in both places was a legacy artifact from before the scenario feature existed.

**What's fixed — the full long-term change (not a surgical filter):**

1. **`IncomeType.rothConversion` removed from the enum.** The Income-page type picker no longer offers "Roth Conversion." There's exactly one place in the app to model Roth conversions now: the Scenarios slider.

2. **Legacy-data migration runs automatically on first launch of 1.7.2.** Users who had a Roth Conversion on their Income page have their data transparently migrated:
   - The `annualAmount` moves to `yourRothConversion` or `spouseRothConversion` based on owner.
   - Any federal/state withholding is preserved as a new "Other" income source named `"Migrated: withholding from prior Roth conversion (<original name>)"`. This keeps Safe Harbor / quarterly estimated-tax math stable. Users can delete the placeholder if they prefer.
   - The legacy source is removed.

3. **Regression tests cover all migration paths.** Primary owner, spouse owner, withholding preservation, modern-data no-op, and sentinel-never-leaks-to-UI. 5 tests, all passing.

**Architectural benefit:** Now that `IncomeType.rothConversion` doesn't exist, the double-entry bug is impossible to reintroduce. It's not a filter that could be removed by mistake — it's a data-model invariant.

**Commit:** `46d1b95` — "Remove IncomeType.rothConversion and migrate legacy data"

---

### Fix #4 — "RMD — Not yet required" missing on primary side of withdrawal card

**What Ron saw:** "Under Spouse's withdrawals, just above the slider the word 'RMD' appears, but not for Your withdrawals."

**Root cause:** In the Scenarios → IRA/401(k) Withdrawals card, the spouse's side had both "Required RMD: $X" (when RMD-age) **and** "RMD — Not yet required" (when pre-RMD-age). The primary user's side only had the first — if the user was pre-RMD-age, the row was skipped entirely, reading as a missing check rather than a deliberate UX choice.

**What's fixed:** Added the mirrored `else` branch on the primary side. Pre-RMD-age users now see "RMD — Not yet required" as reassurance that the app checked and found no requirement yet.

**Commit:** `149ff94` — "Show 'RMD — Not yet required' on primary side of withdrawal card"

---

## 📋 Queued for this release

Rest of the short-list from the [response doc](2026-04-23-ron-park.md):
- **Explicit year labels everywhere.** "2025 State Tax Balance" not "Prior Year Balance"; same for all "Prior year" labels. (~30 min)
- **W-2 Box 1 / Box 2 / Box 17 tooltips on income + withholding rows.** (~15 min)
- **"Auto" → "Auto-calculated for 2026"; SALT plain-English intro; color legend.** (~30 min)
- **Slider/graph color alignment (orange/orange, blue/blue).** (~15 min)
- **Child vs. Children grammar** in heir settings. (~10 min)
- **Life Expectancy → Planning Horizon Age** with tooltip. (~15 min)
- **Legacy Impact: box around whole section + "(given your inputs)" on the "Roth wins" line.** (~20 min)

Estimate: ~3 hours of implementation + notarization. Can ship same-day.

---

## 💬 Deferred (explicit decisions)

### ACA subsidy modeling + cliff warning

**Scope:** Biggest single-feature ask in Ron's review. $2,300/mo real-dollar stakes at the $84K cliff. A new subsidy engine, FPL + applicable-figure tables, cliff banner in Scenarios, dashboard card.

**Why deferred:** ~1 week engineering effort. Won't fit in 1.7.2 bug-fix release. Sequenced as the headline of 1.8.

**Next step:** Design doc + spec + plan (using brainstorming + writing-plans flow) to be built out between 1.7.2 ship and 1.8 start.

---

### Pre-tax contribution scenario levers (401(k) / Traditional IRA / HSA contributions)

**Scope:** Scenario sliders for contributions that lower AGI — paired with the ACA cliff feature since these are the mechanical tools for managing AGI.

**Why deferred:** Shipped together with ACA as part of 1.8's "Reduce AGI" thematic grouping.

---

### "Reduce AGI" dashboard section

**Scope:** Unifies ACA cliff warning + QCD + charity + stock donation + new pre-tax contributions into one goal-oriented card.

**Why deferred:** Shipped together with ACA (Phase 2 feature in 1.8). Needs items 3 and 4 above to exist before this has content to unify.

---

### Brokerage + HSA account modeling

**Scope:** Completes the portfolio picture. Tax-free / tax-deferred / already-taxed bucket organization. Unlocks withdrawal-order strategy work. HSA state-tax special case for CA and NJ.

**Why deferred:** ~2 weeks. Target 1.9.

---

### Year-over-year history / snapshots

**Scope:** Frozen per-year data so Ron can "look back at 2025 and 2026 plans when I start on 2027." A real Boldin weakness we could differentiate on.

**Why deferred:** Genuine feature; needs proper design. Target 1.9 or 2.0.

---

### Multi-year Roth conversion optimization

**Scope:** Boldin-style "how much to convert each year under optimistic / average / pessimistic returns" with start/stop guidance.

**Why deferred:** Largest single feature on the list — needs a planning engine. Target 2.0.

---

### Withdrawal-order strategy modeling

**Scope:** When to withdraw from Trad IRA before brokerage (low-income year, ACA cliff, estate step-up). Requires brokerage accounts to exist first.

**Why deferred:** Depends on brokerage (1.9). Full strategy comparison is its own feature.

---

### Additional income types (rental, property sale, crypto)

**Scope:** Dedicated types with correct tax treatment (rental QBI / depreciation; §121 exclusion for property).

**Why deferred:** Not blocking Ron's current use; captured implicitly via "Other" and capital-gains types today. Target 2.0.

---

### App name rethink

**Scope:** Ron: "App name undersells the breadth." Genuinely true — the app is now a full retirement tax planner, not just RMD/Roth.

**Why deferred:** Accept the App Store rating-reset cost carefully. Needs strategic decision, not a quick call. Target: before 2.0 if at all.

---

### History form 2210 / Q4 Roth annotation

**Scope:** Ron noted Form 2210 annotation flow for Q4 Roth conversions. IRS seems to only care if they send a letter, but worth a tooltip in Safe Harbor section.

**Why deferred:** Minor. Sweep into the Safe Harbor polish pass in 1.8.

---

## ⚠ Needs discussion

- **"Collect vs. calculate" page status chips** — is the "Inputs" vs "Analysis" framing Ron suggested the right framing? Or is a different UX cue better? (~30 min investigation)
- **Trad IRA / 401(k) withdrawals as Income type** — add new type, or keep scenario-centric model with a tooltip pointing to the withdrawal slider? (~1 hr decision + 30 min implementation)

---

## Meta

- **Total items tracked:** 22 (4 shipped, 7 queued, 10 deferred, 2 needs-discussion)
- **Last updated:** 2026-04-24
- **Update frequency:** As items land
