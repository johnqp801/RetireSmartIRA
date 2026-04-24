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

## Addendum: pending Gemini input

The Gemini prompt ([drafted in session 2026-04-24](./2026-04-24-ron-park-tracking.md)) asks for an independent opinion on market norms and a prescriptive recommendation for our audience. When that response comes back, append it below for triangulation.

*(Append Gemini response here.)*
