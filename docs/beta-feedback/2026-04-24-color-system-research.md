# Color system research + recommendation

**Context:** During the Ron Park feedback pass, queue items 1 (SALT color legend) and 2 (slider/graph color alignment) surfaced a broader concern: the app's color scheme is inconsistent — the same hue means different things in different parts of the app — and possibly too colorful for the retirement-planning category.

**Verdict after research:** the concern is correct and the problem is bigger than the two queue items suggested. This warrants a standalone design-system refresh, not a string-of-tweaks fix.

---

## Evidence Stream 1 — market norms (external research)

### Retirement-planning category (Boldin, Empower, Fidelity, Vanguard)

Decisively **muted**. The pattern:

- **One dominant brand color** (navy/teal/forest green).
- **Neutral chrome** (grays, whites) dominates the interface.
- **Semantic color** (green = on-track, red = vulnerable, amber = progressing) **restricted to status and charts** — not used for categorical distinctions.
- None use rainbow-categorical color across their dashboards.

Notable specifics:
- **Fidelity** uses an unusual earthy palette (#af8a49 warm gold, #006044 forest green, #76a923 olive). Brand identity anchored by forest green, not blue.
- **Empower** uses dark navy as primary, green as secondary semantic; "calming blues" described consistently in reviews.
- **Boldin** uses a traffic-light rubric for plan health (green = excelling, yellow = progressing, red = vulnerable); Monte Carlo projections use a single blue line with shading, not multi-color bands.
- **Vanguard** third-party descriptions: "minimalist, data-focused, conservative, muted tones, navy/gray/green."

### Consumer fintech adjacent (Monarch, Copilot)

More vibrant, but **systematic**:

- **Monarch**: cool colors = assets (cash green, investments blue, real estate purple), warm colors = liabilities (credit cards red, loans yellow). Color encodes a meaningful axis.
- **Copilot Money** (Apple Design Award finalist 2024): vibrant, but locked into a published design system with ~30 components + ~50 icons + two themes. Users pick category colors from a palette, so vibrancy is user-driven, not designer-sprayed.

### TurboTax

Sits between: **data UI is muted** (Cerulean Blue + Thunderbird Red), all visual vibrancy is contained **inside illustrations**, not charts or chrome.

### Verified functional color vocabulary across the category

| Color | Meaning | Evidence |
|---|---|---|
| Green | Positive / asset / on-track / savings | Boldin "excelling," Monarch cash, Empower target range |
| Red | Negative / liability / vulnerable / error | Boldin "vulnerable," Monarch credit cards, TurboTax error |
| Amber / yellow | Warning / progressing / caution | Boldin "progressing," Monarch loans |
| Blue | Primary brand / informational / actual values | Empower cash, TurboTax primary, Boldin Monte Carlo |

---

## Evidence Stream 2 — our codebase (internal audit)

### No custom brand color

`Assets.xcassets/AccentColor.colorset/Contents.json` contains only `{"idiom":"universal"}` — no color value. The app inherits SwiftUI's default system blue as its "accent," which means our "brand color" is the same hue that marks 7+ other meanings throughout the app.

### Distinct hues per screen

| Screen | Distinct hues |
|---|---|
| Dashboard (alone) | 8 (blue, orange, red, green, purple, teal, indigo, pink — plus gray chrome) |
| Scenarios (alone) | 9 (blue, orange, red, green, purple, teal, indigo, yellow, pink) |

The Scenarios tab's Roth strategy guide walks through 6 sequential sections, each with a different arbitrary `color:` arg purely as section-icon decoration (blue → green → red → purple → orange → …). The waterfall chart on the same tab packs 7 hues into one chart (gray, purple, blue, indigo, green, orange, teal).

Industry norm for this category (per Stream 1): ~3–5 hues per screen.

### Concept-to-color mapping is unstable across screens

**Roth** — three different colors depending on screen:
- `DashboardView:2464` — Roth IRA/401(k) balance row = **green**
- `TaxPlanningView:914` — Waterfall bar "Roth" = **purple**
- `TaxPlanningView:1814` — Summary row "Your Conversion" = **orange**
- `DashboardView:983` — "Roth Conversions" breakdown = **orange**
- `DashboardView:399` — Dashboard "Scenario Decisions" row = **purple**
- `LegacyImpactView:411` — Roth projection line = **green**

**Traditional IRA** — blue almost everywhere except the Legacy chart where it's orange/red:
- `DashboardView:2462`, `RMDCalculatorView:874` — **blue**
- `LegacyImpactView:420, 826` — **orange** line with **red** legend dot

**Inherited IRA** — orange in charts, indigo in scenarios:
- `DashboardView:2467`, `RMDCalculatorView:874–875` — **orange**
- `TaxPlanningView:730, 926, 1381, 1481` — **indigo**

### Colors have multiple conflicting meanings

**Red** — overwhelmingly "tax owed / penalty / deadline" (Dashboard:632–646, RMDCalculator:1353, QuarterlyTaxView:198–202) — but also:
- `SocialSecurityPlannerView:459` — Age 62 claim column (categorical, not danger)
- `LegacyImpactView:826` — Traditional IRA legend dot (categorical)
- `TaxPlanningView:1666` — Roth-guide section icon (decorative)

A user trained on the dominant meaning reads "your Age 62 SS benefit" as danger when it isn't.

**Orange** — warning ("approaching IRMAA threshold" at Dashboard:696, 715, 1942) AND Roth conversion category AND inherited IRA category, often co-occurring on the same screen.

**Purple** — spouse owner identity AND Roth conversions AND generic highlight chips.

**Blue** — at least 6 distinct meanings (federal tax, Traditional IRA, extra withdrawals, primary owner, FRA SS benefit, current-year row highlight, section-icon decoration).

### Top 3 highest-confusion inconsistencies

1. **Roth's color is unstable** — green / purple / orange depending on screen. Highest-impact fix, highest visibility. Files: DashboardView, TaxPlanningView, LegacyImpactView.
2. **Red doubles as "tax/danger" AND Age 62 SS AND Traditional legend dot AND decorative section icons** — users may misread SS Age-62 numbers as "bad."
3. **Orange stacks three meanings** — warning, Roth conversion, inherited IRA — and these co-occur on the Dashboard's IRMAA + Tax Saved region.

---

## Synthesis: where we are relative to the category

| Dimension | Category norm (retirement planners) | Us |
|---|---|---|
| Dominant brand color | One, specific | None (empty AccentColor) |
| Hues per screen | 3–5 | 8–9 |
| Semantic color use | Reserved for status + charts | Mixed with decorative + categorical |
| Categorical consistency across screens | Locked (Roth = X everywhere) | Unstable (Roth = green OR purple OR orange) |
| Color carries information | Yes, always | Often decorative |

We are design-wise closer to early-stage consumer fintech than to the retirement-planning category our users benchmark against (Boldin, Empower, Fidelity).

---

## Recommendation

### 1. Treat this as a standalone design-system project, not a string of tweaks

Items 1 and 2 from the Ron-feedback queue (SALT color legend; slider/graph color alignment) become no-ops — there are no canonical colors to align TO until we define them. Defer those items into this larger workstream.

### 2. Target release: 1.8

1.7.2 ships the other queued items (Planning Horizon rename, child grammar, Legacy Impact polish, Roth migration banner). The color system work takes 1.8 as its own deliverable. Needs:
- Palette definition (~0.5 day, design)
- Design token file (`Colors.swift` with `Color.Brand.*`, `Color.Semantic.*`, `Color.Category.*`) (~0.5 day)
- Audit + update every call site (~2 days given the ~800 usages)
- Visual validation across all screens (~1 day)
- Beta feedback pass (~a week elapsed)

### 3. Proposed palette (placeholder — refine with Gemini + design review)

**Brand**
- One dominant color. Candidates:
  - Forest green (Fidelity-style — "growth," distinct from fintech norm)
  - Navy blue (Empower/Boldin-style — category norm, conservative)
  - Muted teal (distinctive, feels modern-professional)

**Semantic** (reserved for status — never categorical, never decorative)
- Green = on-track / savings / positive change
- Red = tax owed / penalty / deadline / negative change
- Amber = warning / approaching a cliff
- Gray = neutral chrome

**Categorical** (locked across all screens, derived from a constrained palette)
- Roth (tax-free): ONE color, proposed muted green (echoes "grows tax-free")
- Traditional (tax-deferred): ONE color, proposed muted blue
- Inherited (edge case): ONE color, proposed muted amber

Concerns to resolve:
- If semantic green and Roth-green are both green, users may confuse "Roth bar increased" with "a positive event." Options: two shades, or Roth gets a different categorical color (Fidelity-gold?).
- No purples, pinks, or teals as primary categorical colors — reserve those for rare accent needs.

### 4. Rules to encode in a design-system doc

- **Max 4 hues per screen** (brand + 3 semantic) plus neutrals.
- **Categorical color is immutable across screens.** Roth = X everywhere, forever, enforced via design tokens.
- **No decorative color on icons or section headers.** If the icon doesn't carry information, it's gray or brand-accent.
- **Red/green/amber are reserved for semantic use.** Never used for categorical ID (e.g., Age 62 SS column stops being red).
- **Define a custom brand color** in `AccentColor.colorset` so `.tint(.accentColor)` becomes a real thing.

### 5. What NOT to change

- The waterfall and projection charts do legitimately need distinct colors per series. Lock them to the categorical palette (Roth = X, Traditional = Y, Inherited = Z) rather than the free-for-all that exists today.
- Don't remove green/red from profit/loss displays — that's universally understood across the category and Ron wasn't complaining about those.

---

## Next steps

1. Paste the Gemini prompt (drafted separately) and get the outside opinion.
2. Compare Gemini's recommendation to this doc — note points of agreement and disagreement.
3. Pick a palette (maybe with a quick Visual Companion mockup session).
4. Write the design spec (brainstorming → writing-plans → subagent-driven-development, same flow as Americas journey).
5. Execute in 1.8.

---

## Addendum: Gemini outside opinion (2026-04-24)

Gemini's independent audit, requested for triangulation:

### Framing

> "When beta users in the pre-retiree/retiree demographic flag that an app feels 'inconsistent' and 'too colorful,' it is almost always a symptom of **cognitive overload masking as a visual design complaint**. At this life stage, users are managing six-figure decisions with high anxiety; they need a tool that feels like a steady fiduciary, not a gamified trading app."

### Market survey (agrees with our external agent)

- **Boldin**: muted, 1–2 dominant UI hues; shades-of-same-hue for categorical data; semantic color scattered only carefully.
- **Empower**: stark base + 1–2 UI hues, but *allocation charts* can carry 4–6 hues. Core UI stays neutral; color complexity is contained inside charts.
- **Fidelity**: muted, dominantly white/gray/"Fidelity Green." **Uses monochromatic scales (shades of same hue) for categorical data** rather than distinct hues.
- **Vanguard**: most muted of the group — nearly monochrome UI with signature burgundy only for branding. Relies on **typography, whitespace, and layout** for categorical grouping instead of color.
- **TurboTax**: vibrant but surgically precise. Color guides the user through high-friction processes (e.g., bright green "Refund" ticker as focal point) — color for *feedback*, not data categorization.

### Category synthesis

- Norm clusters firmly on the **"muted institutional"** end.
- Core UI is monochrome (white/slate/gray) + one primary brand color for interactive elements.
- **"Consumer fintech vibrant" is actively avoided because it signals gamification, which degrades trust in long-term wealth management.**

### Functional color vocabulary for the 55+ demographic

| Color | Meaning | Notes |
|---|---|---|
| Green | Growth, savings, positive cash flow | Hardwired |
| Red | Loss, penalty, critical error | **NOT for standard taxes — see below** |
| Amber / neutral orange | Caution, approaching a threshold | |

**Specific corrective — taxes should NOT be red:**

> "Taxes are an expected reality, not a penalty. Using red for taxes owed causes unnecessary panic. Use a neutral tone (like slate gray or muted orange) for standard tax liabilities, reserving red only for penalties or avoidable tax traps."

This is a new actionable insight not surfaced by our internal audit or external agent. Our current code renders federal/state/NIIT/AMT tax amounts in red throughout the Dashboard (lines 632–646) and Quarterly Tax view. Under Gemini's rubric, we're telling every user their *normal* tax obligation is a crisis.

### Prescriptive recommendations

- **Hues per screen:** one primary accent (subdued navy or teal) + one secondary semantic (red or green only for alerts/positive reinforcement).
- **Palette structure:** 80% whitespace + grays, 15% primary brand hue, 5% semantic color.
- **Categorical data:** stop using distinct hues. Use **monochromatic shading** (e.g., dark blue = Traditional IRA, medium blue = Roth, light blue = Taxable brokerage) + typography weight + spatial grouping.
- **Charts:** if multiple hues are unavoidable, use a muted, colorblind-safe *sequential* palette (slate / navy / teal).
- **Avoid:** purples, hot pinks, neons (read as "crypto" or "budgeting app"). Avoid vibrant "buy now" greens — use grounded forest/emerald instead.

### Cognition research cited

- **Stroop effect**: when users have to reassess what a color means based on which screen they're on, cognitive load spikes.
- **Colin Ware's *Information Visualization***: as eyes age (55+), contrast sensitivity decreases and susceptibility to visual clutter increases. Too many colors literally impair a user's ability to quickly read and trust a chart.

### Single highest-leverage recommendation (Gemini's headline)

> **"Decouple your UI palette from your Data Visualization palette. Reserve vibrant semantic colors (red/green) exclusively for UI alerts, text readouts, and primary actions. For all charts, tables, and categorical data (Roth, Traditional, SALT caps), use a strict, muted, cohesive palette (like varying shades of slate, navy, and gray). If an element does not require the user to take immediate action or feel a specific emotion, it should not be brightly colored."**

---

## Triangulation — what changes in our recommendation

Our internal audit, the external agent's survey, and Gemini's audit converge on the core diagnosis. But Gemini adds three specific moves we should adopt:

### 1. Taxes are not red

Our current dashboard tells users their federal tax, state tax, NIIT, and AMT are all in red. For most users those are normal, expected, already-paid obligations — not crises. Gemini's fix: reserve red only for **penalties and avoidable tax traps** (missed RMDs, underpayment penalties, NIIT crossing a threshold that could have been avoided). Standard tax liabilities go to slate gray or neutral orange.

**Implication for our design spec:** add a specific rule — "red is reserved for penalties, deadlines, and avoidable cliffs. Normal tax amounts are neutral."

### 2. Monochromatic shading for categorical data

Our initial proposed palette assigned three different categorical hues (Roth green, Traditional blue, Inherited amber). Gemini's approach: **same brand hue, different shades** — e.g., Traditional dark blue, Roth medium blue, Taxable brokerage light blue. This matches Fidelity's real-world implementation and dramatically reduces screen-level color count.

**Implication for our design spec:** switch the categorical strategy from "one distinct hue per concept" to "shades of the brand color." Brand becomes the unifying anchor. Semantic green/red remain, but rarely co-occur with categorical shading.

### 3. UI palette vs. Data Viz palette

Our current spec implied one unified palette. Gemini's rubric separates them:
- **UI palette** (navigation, buttons, alerts, form labels): brand + semantic + neutrals.
- **Data Viz palette** (charts, category badges, series colors): muted sequential scale of the brand hue.

These don't share colors except the brand accent.

**Implication for our design spec:** the design-token file gets two namespaces: `Color.UI.*` and `Color.Chart.*`. Chart colors are shades, UI colors are solids.

---

## Updated prescriptive direction (post-Gemini)

| Role | Color | Rule |
|---|---|---|
| Brand (primary accent) | One muted hue — navy, teal, or forest green | Used for interactive elements and as the anchor for Data Viz shades |
| Semantic: positive | Grounded green (forest/emerald, not neon) | Savings, refunds, on-track projections, successful actions |
| Semantic: negative / critical | Red | **Penalties, deadlines, avoidable cliffs only.** Not for standard taxes. |
| Semantic: warning | Amber | Approaching a threshold (IRMAA cliff, RMD deadline, ACA subsidy cliff when that lands) |
| Standard tax amounts | Slate gray or neutral muted tone | Expected obligation, not a crisis |
| Categorical (charts, badges) | Shades of the brand hue (sequential scale) | Traditional / Roth / Inherited / Brokerage → dark → medium → light → lighter |
| Chrome / neutrals | Grays, white, muted slate | Backgrounds, dividers, non-informational UI |

Screens target: brand + 1 active semantic + neutrals. Charts use shades. **Max 3 distinct hues visible on any screen.**

### What NOT to change from the original plan

- Still defer to 1.8.
- Still need a design-system tokens file.
- Still need audit-and-update all ~800 call sites.
- Still need a beta pass with Ron to validate the result before GA.

### New work items the Gemini input adds

- **Tax-color correction pass** (can potentially ship in 1.7.2 as a targeted fix — smaller scope than the full color-system overhaul): change federal/state/NIIT/AMT amounts on the Dashboard and Quarterly Tax view from red to a neutral tone, reserving red for actual penalties/deadlines. This would make the app feel less panicky *immediately*, even before the full design-system refresh.
- **Monochromatic-shades token work**: define the sequential brand-color scale for categorical data (5 shades minimum for series charts).

---

## Addendum: ChatGPT outside opinion (2026-04-24)

Second independent audit, requested for triangulation alongside Gemini's.

### Framing

> "I would take the beta user's concern seriously. For this category, too colorful is a real risk."

### Market survey (agrees with both our agent and Gemini)

- **Boldin**: the most relevant benchmark. Light institutional base, teal/green as dominant success/progress color, occasional orange for CTAs, restrained chart colors. Some multi-hue screens but the interface still feels planner-like.
- **Empower**: professional dashboard framing. Blue/teal/green accents, restrained cards, color used mostly for account/portfolio status rather than decorative energy.
- **Vanguard**: most institutional. Heavy white/neutral space, very limited accenting, "save, invest, retire" utility feel.
- **Fidelity**: utility-first. Didn't have enough screenshot evidence for detailed chart-color claims.
- **TurboTax**: more vibrant than the retirement planners, but dominant pattern is still one strong brand color + semantic moments (teal/green for refund/positive outcome, red check for completion) + lots of white space.

### Category synthesis

> "The category norm clusters closer to muted institutional than consumer-fintech vibrant. These products are helping people make high-stakes, numerically dense decisions; they cannot feel like a budgeting toy, crypto dashboard, or gamified wellness app. RetireSmartIRA can be warmer and more modern than Vanguard, but it should not look more colorful than Boldin or TurboTax."

Concrete ceiling: "Should not look more colorful than Boldin or TurboTax" — a useful anchor we can visually benchmark against.

### Proposed semantic color vocabulary

| Color | Meaning |
|---|---|
| Primary blue/teal | Navigation, selected state, neutral emphasis |
| Green | Tax savings, surplus, favorable movement, "room available" |
| Red | Tax-owed **increase**, penalty, over-threshold, adverse movement |
| Amber | Warning / proximity / cliff risk — **not "bad" yet** |
| Gray / slate | Baseline, historical, neutral, disabled, secondary data |

Note the distinction: **red means "an *increase* in tax owed"**, not the total tax figure. Another vote in favor of Gemini's "don't color standard taxes red" point.

### The governing rule

> **"A hue can have only one job. If amber means IRMAA warning in one place, it should not mean 'charitable giving category' elsewhere. If green means savings, do not also use green as 'Traditional IRA' unless the chart is clearly categorical and isolated."**

### Specific new idea: solve categorical with *style*, not more color

> "For Roth vs. Traditional, I would not solve this mainly with more color. Use labels, grouping, line style, fill style, icons, and typography. Example: Roth line = solid primary accent; Traditional line = dashed slate; taxable account = dotted gray. In tables, use column grouping and headers rather than colored cells everywhere. In charts, if Roth must have a color, use a consistent muted accent and avoid making it look like 'good' merely because it is green."

This is a different approach from Gemini's "monochromatic shades of the brand hue." Both solve the same problem (too many hues for categorical data); this one uses **stroke style + fill pattern + typography** instead of color altogether.

### Critical insight — "green is good" can mislead *in this app specifically*

> "Bright green can feel like 'buy now' or 'winning,' which is dangerous when the correct tax decision may increase taxes today to reduce future taxes."

This is a RetireSmartIRA-specific warning nobody else flagged. Our core thesis is that sometimes the right move is to accept more tax *now* to avoid more tax *later* (Roth conversions, early RMDs in low-income years). If the UI colors "pay less tax today" as green-good, users may miss the long-term frame. Green should be reserved for **unambiguously positive** outcomes, not short-term tax bill changes.

### Cognition research cited

- **"Don't rely on color alone; pair color with text/icons/structure"** — accessibility best practice.
- **Visual search / color combinations under cognitive load** — color choices affect task performance.
- **Data visualization / multiple encodings** — color competes with other visual features; too many encodings can make clusters harder to perceive.

### Single highest-leverage recommendation (ChatGPT's headline)

> **"Create a written semantic color contract and audit every screen against it. Not a palette board — a contract. For each color, define: 'This color means X, never Y.' Then reduce screen-level color until the only saturated elements are decision-critical: savings, cost, warning, threshold, selected control."**

The framing as a *contract* (not a style guide) is notable — it's a set of bans as much as a set of choices.

---

## Final synthesis — three sources converging

| Point | Internal audit | External agent | Gemini | ChatGPT |
|---|---|---|---|---|
| Category norm is muted | — | ✓ | ✓ | ✓ |
| Max 3–5 hues per screen | ✓ (we're at 8–9) | ✓ | ✓ (2) | ✓ (3) |
| One hue = one meaning | ✓ (top-3 inconsistency) | ✓ | ✓ | ✓ (explicit rule) |
| Need custom brand color | ✓ (AccentColor empty) | ✓ (all peers have one) | ✓ | ✓ |
| Categorical should not be "more color" | — | ✓ (Monarch systematic) | ✓ (monochromatic shades) | ✓ (line style / typography) |
| **Taxes ≠ red** | — | — | ✓ | ✓ (increases only) |
| **Green-is-good can mislead this app** | — | — | — | ✓ (unique) |
| Decouple UI palette from chart palette | — | — | ✓ | — (implicit in "contract") |
| Written contract / design tokens required | ✓ (no tokens today) | ✓ (published design systems) | ✓ (tokens) | ✓ ("not a palette — a contract") |

**Unanimous verdict:** the beta user's concern is accurate, the problem is global, and the fix is a constrained, written color contract with category-norm-level muted palette.

## Final prescriptive direction (post-triangulation)

### The color contract (to be formalized into a Swift design-token file)

| Role | Color | The contract |
|---|---|---|
| **Brand / primary accent** | One muted hue (proposed: deep teal or navy — pending design review) | Interactive elements, selected state, navigation. The anchor. |
| **Semantic: positive** | Grounded green (forest / emerald — not neon) | **Unambiguous wins only**: tax refunds, "room available in bracket," successful saves. Not used for scenario comparisons where "lower tax today" may be the wrong answer. |
| **Semantic: negative / critical** | Red | **Penalties, deadlines, avoidable cliffs, adverse increases** (e.g., a Roth conversion that pushes past the IRMAA cliff). **Never for standard expected tax amounts.** |
| **Semantic: warning** | Amber | Approaching-a-threshold (IRMAA cliff, ACA cliff when it lands, RMD deadline). Not "bad," just "pay attention." |
| **Neutral tax amounts** | Slate gray | Standard federal / state / NIIT / AMT figures — the things that are true but not crises. |
| **Categorical (charts, badges)** | **Shape + style + typography, not color.** Solid primary accent for the featured series; dashed slate for the comparison series; dotted gray for tertiary. If chart needs color per series, use shades of the brand hue. | Max 1 saturated hue per chart. Legend always visible. |
| **Chrome / backgrounds** | White / very light gray / slate gray for dividers | 80% of screen pixels. |

### Screen-level rule

**Max 3 saturated hues visible on any screen**: brand + one active semantic + one chart-accent. Everything else is neutral.

### Rules formulated as bans (the "contract" framing)

- Purple is not a category color. Period. (Spouse-owner badges move to brand-tinted or icon-differentiated.)
- Red is not used for standard tax amounts. Red appears only next to penalties, cliff violations, deadlines, and adverse deltas (+$X).
- Green is not used for "category = Roth." Roth gets the brand accent or a shape difference.
- No decorative color on section headers or strategy-guide icons. If the icon doesn't carry information, it's gray.
- AccentColor.colorset gets a real brand color defined. `.tint(.accentColor)` becomes the standard path.
- Line-style encoding (solid / dashed / dotted) is a first-class tool for categorical distinction in charts.

### Low-hanging fruit: ship a "tax-color correction" in 1.7.2

Before the full color-system refresh lands in 1.8, one specific change emerged from both Gemini and ChatGPT that's scoped small enough to ship now: **recolor standard tax amounts from red to slate gray on the Dashboard + Quarterly Tax view.** Reserve red only for penalties, deadlines, and adverse deltas. This alone removes the "everything feels alarming" undertone Ron reported without requiring a palette decision.

Scope: ~8 call sites in `DashboardView.swift` and `QuarterlyTaxView.swift`. Pure color-literal change. ~30 minutes.

### Still-open decisions (for design review before 1.8 starts)

- Brand color: deep teal vs. navy vs. muted forest green. ChatGPT suggests teal/navy; Gemini flexible; internal preference TBD. Recommend a Visual Companion mockup session to pick.
- Categorical strategy: shades-of-brand-hue (Gemini) vs. line-style-and-typography (ChatGPT). Not mutually exclusive — could use line style for *series* comparisons (Roth-vs-Traditional wealth curves) and shades for *allocation* charts. Worth a design decision.
- Whether to keep green for "tax refund" in addition to "savings" — ChatGPT's warning about the Roth-vs-Traditional frame argues for narrowing green further.

---

## Action summary

1. **Research doc complete** (this file). Three-source triangulation done.
2. **Decision recorded:** color-system refresh scheduled for 1.8 as its own workstream.
3. **Quick win for 1.7.2:** the tax-color correction (red → slate for standard amounts) — candidate for inclusion in the current branch if we want it.
4. **Next for 1.8:** pick brand color (design review), write the Swift design-token file, audit and update all ~800 call sites, visual validation, beta pass with Ron.
