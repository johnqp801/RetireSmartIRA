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

### Fix #5 — Ambiguous "Prior Year" labels replaced with explicit year + foundation for year-over-year history

**What Ron saw:** "Prior year state tax balance — So this is 2025, not 2024, right? (Just trying to make sure 'Prior' is always used consistently)." And: "SALT > Estimated State Tax Payments (auto) — what's the auto part? ... It wasn't clear to me this wasn't asking for 2025 est taxes paid."

**Root cause:** Several labels in Income & Deductions and Quarterly Tax said "Prior Year" without specifying which year. The naïve fix (interpolate `currentYear - 1` from the system clock) would silently break on January 1 of each year — labels would flip to the new year while the user's stored data still reflected the prior year's plan.

**What's fixed — design the foundation for year-over-year history while fixing the labels:**

1. **New persisted `planYear` field** added to the user's profile. Unlike `currentYear` (which tracks the system clock and auto-advances on January 1), `planYear` is stable once set — it only changes when explicitly bumped.

2. **All year-specific UI labels now use `planYear` and `planYear - 1` directly**, e.g.:
   - "2025 State Tax Balance"
   - "auto-calculated for 2026"
   - "2025 Tax Information" (in Safe Harbor section)
   - "100% of 2025 Tax" (in Safe Harbor amount line)

3. **Existing users are migrated automatically**: on first launch of 1.7.2, `planYear` defaults to the system year at load time and is persisted. From then on, the field is stable regardless of calendar rollover.

4. **Forward compatibility:** `planYear` is the anchor for the future year-over-year history feature (deferred to 1.9). When that feature ships, it can migrate today's flat fields into per-year snapshots keyed by `planYear`, and add a "Start planning 2027" workflow that bumps `planYear` and freezes the prior year's plan. Without today's change, that feature would have nowhere to attach.

**Commit:** `4af0db4` — "Replace ambiguous 'Prior Year' labels with explicit years via persisted planYear"

---

### Fix #6 — W-2 box references, withholding "annual," and per-type income guidance

**What Ron saw:** Could not tell which W-2 box to copy from ("Is this Box 1 or Box 3?"), whether withholding fields were annual or per-paycheck, what "Interest" vs "Dividends" specifically meant, or how to handle qualified vs ordinary dividends.

**What's fixed:**

1. **Clearer picker labels** (via a new `IncomeType.displayName` property — the Codable raw value stays untouched, so existing persisted data doesn't need migration):
   - "Dividends" → **"Ordinary Dividends"** (pairs naturally with "Qualified Dividends")
   - "Interest" → **"Taxable Interest"** (pairs with "Tax-Exempt Interest")

2. **Withholding TextField labels now include "annual" and W-2 box numbers**:
   - "Federal Withholding (optional)" → "Annual Federal Withholding (**W-2 Box 2**, optional)"
   - "State Withholding (optional)" → "Annual State Withholding (**W-2 Box 17**, optional)"

3. **Four new conditional "About …" guidance sections** appear in the Add/Edit Income form when the relevant type is selected (matches the existing pattern used for state-tax refunds and tax-exempt interest):
   - **Employment / W-2 Income**: explains W-2 **Box 1** (not Box 3), addresses the 401(k)-pre-tax gotcha, covers 1099 / self-employment net-profit handling.
   - **Taxable Interest**: clarifies 1099-INT Box 1, distinguishes from muni interest (use Tax-Exempt Interest) and mortgage interest paid (deduction, not income).
   - **Ordinary Dividends**: 1099-DIV Box 1a − Box 1b, prompts user to split out qualified portion.
   - **Qualified Dividends**: 1099-DIV Box 1b, preferential cap-gains rates, reverse pointer to Ordinary Dividends for the non-qualified portion.

**Commit:** `99d4630` — "Clarify income type + W-2 box labels + per-type guidance"

---

### Fix #7 — Standard tax amounts no longer rendered in red

**What Ron saw (implicit):** every federal/state/NIIT/AMT/total tax figure on the Dashboard rendered in red. RMD amounts and "Required" status also red. The aggregate effect: every glance at the app felt alarming, even when nothing was actually wrong.

**What's fixed:** Per the color-system research and triangulation, red is now reserved for **adverse signals only** — penalties, deadlines, cliff crossings, scenario decisions that worsen outcomes. Standard tax obligations and RMD amounts render in default neutral text.

**Specifically changed:**
- Dashboard tax breakdown: Federal Tax, State Tax, NIIT, AMT, Total Tax rows
- Federal/State/Total subtotals in the Total Tax disclosure
- "RMD Status: Required" indicator
- Personal + spouse RMD amount displays
- QuarterlyTaxView: NIIT and AMT summary rows

**Intentionally retained as red (legitimate adverse signals):**
- SALT cap loss line, Medical AGI floor exclusion
- Roth conversion "Tax cost this year" on the suggestion card
- "In the top 37% federal bracket" warning
- NIIT cliff-crossed alert and threshold marker

**Why this matters:** Both Gemini and ChatGPT, independently, called this out as the single highest-leverage color move. Removes the "everything feels alarming" undertone immediately, without committing to a full palette decision (which lands in 1.8).

**Commit:** `1fa275f` — "Recolor standard tax amounts red → neutral (color contract Fix #7)"

---

## 📋 Queued for this release

Rest of the short-list from the [response doc](2026-04-23-ron-park.md):

**Note:** items 1 & 2 (SALT color legend; slider/graph color alignment) were **deferred to 1.8** after a color-system research pass surfaced a broader design problem. See [color system research](2026-04-24-color-system-research.md) for the full audit. Those items become no-ops until the canonical palette exists.
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

### Color-system refresh (deferred into 1.8 from items 1 & 2 of the short-list)

**Scope:** Items 1 (SALT color-code legend) and 2 (slider/graph color alignment) from the 1.7.2 short-list revealed a global design problem: 9+ distinct hues per screen, no custom brand color, unstable concept-to-color mapping (Roth is green/purple/orange depending on screen), and semantic red/green doing double duty as categorical identities.

**Why deferred:** The fix is a standalone design-system project, not a tweak. Retirement-planning category norm (Boldin, Empower, Fidelity, Vanguard) is decisively muted — one brand color, 3–5 hues per screen, semantic color reserved for status. We're currently closer to early-stage consumer fintech in visual density.

**Full research:** [docs/beta-feedback/2026-04-24-color-system-research.md](2026-04-24-color-system-research.md).

**Target:** 1.8 release. Tasks: palette definition → design-token file → audit-and-update all ~800 color call sites → visual validation → beta feedback.

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

- **Total items tracked:** 22 (7 shipped, 3 queued, 11 deferred, 2 needs-discussion). Items 1 & 2 of the queue (SALT legend, slider/graph color alignment) rolled into the deferred color-system refresh after research showed they're symptoms of a larger design issue. Fix #7 (tax-color correction) was a small but impactful piece of that larger work that we extracted and shipped now.
- **Last updated:** 2026-04-24
- **Update frequency:** As items land
