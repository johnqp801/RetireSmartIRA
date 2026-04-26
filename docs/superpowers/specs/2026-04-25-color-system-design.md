# 1.8 Release — Color System & Design Token Refresh

**Status:** Design spec, awaiting approval
**Author:** John Urban (with brainstorm collaboration)
**Date:** 2026-04-25
**Target release:** RetireSmartIRA 1.8 (foundation for 1.9 ACA / Medicare / contributions work)
**Related research:** `docs/beta-feedback/2026-04-24-color-system-research.md`

---

## 1. Overview

RetireSmartIRA 1.0–1.7 grew its visual style organically. Today the app uses ~9 distinct hues per screen, has no defined brand color (`AccentColor.colorset` is empty), and uses the same colors for inconsistent jobs (red for both "warning" and "tax owed", green for "refund" and "savings" and "growth", etc.). Beta users have flagged this as visual noise and inconsistency.

This release introduces:

- A **brand color** (Muted Teal `#2A6B7C`)
- A **strict semantic color contract** — every color has exactly one job
- A **design token system** organized into three namespaces: `Color.UI.*`, `Color.Semantic.*`, `Color.Chart.*`
- **Component tokens** (cards, buttons, info buttons, badges) with consistent treatment across all screens
- **Light + dark mode parity** — dark mode is "free" because every component reads from tokens
- **Spacing and corner-radius tokens** — locked to a standard scale for consistency

This is foundation work. 1.9's ACA / Medicare / pre-tax contribution features will build on these tokens rather than inventing more ad-hoc colors.

### Scope discipline

**In scope:**
- Define and apply tokens across all existing views
- Update color treatments to match the new contract
- Light/dark mode parity
- Visual regression coverage for top-level screens

**Out of scope (defer to later releases):**
- New features or new computations
- Information-architecture changes (tooltip discoverability is a real gap, but it's a UX research initiative, not a color system fix — spawned as a separate task)
- Typography overhaul
- Animation / transition system
- Accessibility audit beyond color contrast (full VoiceOver / Dynamic Type pass is its own initiative)

---

## 2. The Color Contract

The contract is the prescriptive heart of this release. Every color in the app has exactly one job. Code review enforces.

### Contract colors (1 brand + 3 semantic + neutrals)

Brand color carries identity. Semantic colors carry meaning. Both follow the "exactly one job" rule.

| Color | Kind | Hex (light) | Hex (dark) | The one job | Examples |
|---|---|---|---|---|---|
| **Brand Teal** | Brand | `#2A6B7C` | `#2A7585` | Primary identity, default UI accent, ordered-data ramps | Nav bar, primary buttons, info-button glyph, card top-stripe, sequential bracket charts |
| **Green** | Semantic | `#2E7D32` | `#4CAF50` | Money literally returning to the user | "REFUND" badge, refund-amount delta arrow |
| **Amber** | Semantic | `#B85C00` | `#E08A3A` | Action required (time-sensitive or input-needed) | "DUE" badge, deadline text ("Due Jun 15"), IRMAA-proximity warnings, missing-input prompts |
| **Red** | Semantic | `#C62828` | `#EF5350` | Error / blocking state | Form validation errors, crossed IRMAA / ACA cliff, invalid input |

**Explicitly NOT semantic colors:**
- **No yellow.** Tip callouts use gray italic + ⓘ icon, not yellow.
- **Red is never used for "tax owed."** Taxes are a normal mechanical reality, not an error state. Tax amounts are pure black.
- **Green is never used for "good outcomes" generally.** Only refunds. Savings, gains, lower-tax wins are pure black numbers.

### The narrowing rule for amber

Amber is the most easily abused semantic color (warning fatigue). It applies to:
- ✅ Deadline text ("Due Jun 15", "Due Dec 31")
- ✅ Action-required badges ("DUE", "INPUT NEEDED")
- ✅ IRMAA / ACA proximity warnings ("Within $1,200 of IRMAA threshold")
- ✅ Form errors that block save
- ❌ Dollar amounts themselves — *those stay pure black always*
- ❌ Negative deltas ("+$1,240 vs 2025" stays gray, regardless of sign)
- ❌ Generic warnings or "be careful" callouts (use gray italic + ⓘ instead)

### Neutral grays (full ramp)

| Token | Hex (light) | Hex (dark) | Use |
|---|---|---|---|
| `Color.UI.surfaceApp` | `#F5F5F7` | `#000000` | App background — lets cards lift |
| `Color.UI.surfaceCard` | `#FFFFFF` | `#1C1C1E` | Card backgrounds, modals |
| `Color.UI.surfaceInset` | `#F5F5F7` | `#2C2C2E` | Cards inside cards (drawers, list rows) |
| `Color.UI.surfaceDivider` | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.10)` | Hairlines, separators |
| `Color.UI.textPrimary` | `#1A1A1A` | `rgba(255,255,255,0.92)` | Headlines, dollar amounts, labels |
| `Color.UI.textSecondary` | `#666666` | `#9F9FA3` | Deltas, captions, supporting text |
| `Color.UI.textTertiary` | `#8A8A8A` | `#7C7C80` | Disabled, projected, hint text |
| `Color.UI.textUtility` | `#3A3A3C` | `#D0D0D0` | Tertiary button text (utility actions) |

**2026-04-25 adjustment:** Light-mode `textTertiary` was originally `#999999` but achieved only 2.85:1 contrast on white (WCAG AA Large Text requires ≥ 3.0:1). Darkened to `#8A8A8A` (3.44:1).

Notably: dark mode body text is **92% white**, not pure white. Reduces visual glare on OLED displays per Gemini's recommendation.

---

## 3. Token Architecture

Three namespaces, strictly non-overlapping:

```swift
// Brand identity, neutral surfaces, text, button styles
Color.UI.brandTeal
Color.UI.surfaceApp
Color.UI.surfaceCard
Color.UI.textPrimary
// etc.

// Meaning-bearing colors (refund, action-required, error)
Color.Semantic.green
Color.Semantic.amber
Color.Semantic.red

// Data visualization only — never used in UI chrome
Color.Chart.heroTeal
Color.Chart.callout       // warm sand #C28E4A
Color.Chart.gray1 ... gray5
Color.Chart.tealRamp1 ... tealRamp6  // for sequential/ordered data
```

### The non-overlap rule (hard rule, code-review enforced)

**`Color.Chart.*` never includes any color from `Color.Semantic.*`.**

The chart palette is teal + grays + warm sand. There is no green-meaning-savings chart bar. There is no red-meaning-loss chart bar. If a chart needs to highlight "loss" specifically, it uses the warm sand callout, not red.

Why: prevents the most common color-system failure where data charts visually compete with semantic warnings. A red chart bar next to a red error message creates ambiguity. Strict separation eliminates the class of bug.

### Interactive states

For the 5 colors that have meaning (Brand Teal, Green, Amber, Red, Sand), each gets explicit hex tokens for hover / pressed / disabled. Opacity hacks are forbidden — they create muddy colors against varying backgrounds and break in dark mode.

For neutral grays, opacity shifts are fine — grays compose well.

| State | Brand Teal (light) | Brand Teal (dark) |
|---|---|---|
| Default | `#2A6B7C` | `#2A7585` |
| Hover (macOS) | `#235862` | `#3A8595` |
| Pressed | `#1D4B53` | `#4A95A5` |
| Focused | `#2A6B7C` + 2pt focus ring `#7AC5D6` | `#2A7585` + ring `#7AC5D6` |
| Disabled | `#A6BDC2` | `#4F6B72` |

**2026-04-25 adjustment:** Dark-mode `brandTeal` was originally `#3D8FA3` but contrast testing showed white text only achieved 3.71:1 contrast (WCAG AA requires ≥ 4.5:1 for normal text). Darkened to `#2A7585` (white-on-it = 5.30:1). Hover/pressed dark variants adjusted proportionally to preserve their relationship to the base.

**2026-04-25 trade-off note:** The darkened dark-mode `brandTeal` cannot simultaneously serve as a 4.5:1 foreground color on `#1C1C1E` (it achieves 3.23:1). The two requirements are mathematically incompatible — no single teal can give white-on-teal ≥ 4.5:1 AND teal-on-#1C1C1E ≥ 4.5:1. We accept the trade-off because brand teal is never used as small body text in this app. Its foreground usage is limited to: 16pt info-button glyphs (graphical objects, 3:1 rule), ≥15pt tertiary/secondary button labels (large text per WCAG 1.4.3), and section headers. The contrast assertion test for brand teal as dark-mode foreground uses the 3.0:1 large-text threshold to reflect this rule.

Same pattern for green, amber, red, sand. Full table in `Color+Tokens.swift` (the implementation file).

For SwiftUI's built-in pressed feedback on standard `Button(action:)`, we let the system handle the depression effect by default. We override pressed-state color only when the system default doesn't read clearly enough — which we'll evaluate per component.

---

## 4. Component Tokens

Components consume color and dimension tokens. Each component has a defined set of states.

### Card

The metric / info card pattern that appears on every screen.

- **Shape:** 12pt corner radius, white fill, subtle shadow `0 1px 3px rgba(0,0,0,0.08)`
- **Top stripe:** 4pt tall colored band at top, encodes card category
  - `Color.UI.brandTeal` for informational cards (default)
  - `Color.Semantic.amber` for action-required cards (deadline, missing input)
  - `Color.Semantic.red` for error/blocking cards (validation failure, cliff exceeded)
- **Padding:** 14pt horizontal, 12pt vertical inside the body (below the stripe)
- **Light mode:** white card on `#F5F5F7` app background
- **Dark mode:** `#1C1C1E` card on pure black `#000000` app background

### Button (5 variants)

| Variant | Fill | Border | Text | Use case |
|---|---|---|---|---|
| **Primary** | Brand Teal | none | White | Main action per screen |
| **Secondary** | Transparent | 1.5pt Brand Teal | Brand Teal | Alternative action ("Cancel" next to Primary) |
| **Tertiary (utility)** | Transparent | none | Gray `#3A3A3C` | Inline utility actions (Edit, Reset, Dismiss) — DEFAULT |
| **Tertiary (forward)** | Transparent | none | Brand Teal | Inline links that advance the user ("View breakdown", "Learn more") — USE SPARINGLY |
| **Destructive Secondary** | Transparent | 1.5pt Semantic Red | Semantic Red | Inline destructive next to a primary |
| **Destructive Primary** | Semantic Red | none | White | Final-step modal confirmation only ("Yes, delete forever") |

Tertiary defaults to gray. Teal-text-tertiary is reserved for actions that genuinely advance the user — about 1 in 5 inline links. This is the discipline that keeps the brand from becoming visual noise (per ChatGPT's "reduce teal usage 30–40%" feedback).

**Sizes:** all buttons share three sizes — Compact (28pt height, 13pt text), Standard (36pt, 15pt text), Prominent (44pt, 17pt text).

### Info Button

The ⓘ icon next to field labels and section headers.

- **Glyph:** SF Symbol `info.circle.fill` (filled, not outlined — visibility over minimalism)
- **Color:** `Color.UI.brandTeal`
- **Size:** 16pt visual
- **Hit target:** 24×24pt (forgiving on touch / trackpad)
- **Placement:** trailing the label, vertically centered, 6pt leading gap from label

This is the *visual* fix for tooltip discoverability. It's not the *full* fix — see "Spawned follow-up tasks" for the deeper UX work.

### Badge / Tag

Small inline category labels. **NOT a true pill** — see future "Pill / Capsule" component for fully-rounded shape.

- **Shape:** 4pt corner radius, filled background, no border
- **Padding:** 1pt vertical, 5pt horizontal
- **Text:** 9–10pt, 700 weight, uppercase, 0.5pt letter-spacing
- **Variants:**
  - **Refund:** green text on light green tint `Color.Semantic.greenTint` `#E8F5E9` (dark: `rgba(76,175,80,0.20)`)
  - **Due:** amber text on light amber tint `Color.Semantic.amberTint` `#FFF3E0` (dark: `rgba(224,138,58,0.18)`)
  - **Error:** red text on light red tint `Color.Semantic.redTint` `#FFEBEE` (dark: `rgba(239,83,80,0.18)`)
  - **Neutral:** gray text on light gray tint `#F0F0F2`

### Pill / Capsule (reserved for future)

Fully-rounded shape (`radius = height/2`). Reserved for filter chips, segmented controls, multi-select chips that may land in 1.9 or later. **Not used in 1.8.**

---

## 5. Chart Palette

Charts consume only `Color.Chart.*`. Never `Color.Semantic.*`.

### Hero + grays + accent (categorical data)

Most app charts have a "hero" — the primary income source, the proposed Roth conversion, the focal year. The pattern:

- **Hero:** `Color.Chart.heroTeal` = `Color.UI.brandTeal` (i.e., `#2A6B7C`)
- **Supporting categories:** descending gray ramp `Color.Chart.gray1..gray5`
  - `gray1` = `#7A7D85`
  - `gray2` = `#9DA1A8`
  - `gray3` = `#BCC0C6`
  - `gray4` = `#D8DADD`
  - `gray5` = `#E8E9EB` (effectively the lightest, used sparingly)
- **Callout accent:** `Color.Chart.callout` = warm sand `#C28E4A` (dark: `#D9A765`) — for "look here, this is what's changing"

If a chart has no clear hero (every category equally weighted), use the teal-shade ramp instead (see below).

### Teal shade ramp (ordered/sequential data)

For tax brackets, year-over-year projections, age-based withdrawal schedules — anything where order/magnitude matters:

- `Color.Chart.tealRamp1` = `#1F4F5C` (darkest — typically "highest" or "first")
- `Color.Chart.tealRamp2` = `#2A6B7C` (= brand teal)
- `Color.Chart.tealRamp3` = `#4D8A99`
- `Color.Chart.tealRamp4` = `#7AA9B5`
- `Color.Chart.tealRamp5` = `#A7C4CC`
- `Color.Chart.tealRamp6` = `#CBDBDF` (lightest)

Dark-mode parity uses the same sequence shifted brighter.

### Line-chart shape/style differentiation

For multi-line projections (e.g., "actual vs projected vs alternative scenario"), use SwiftUI's built-in `StrokeStyle(dash:)`:

- **Solid** = actual / current
- **Dashed** `[6, 4]` = projected
- **Dotted** `[2, 3]` = alternative scenario / what-if

Combined with hero teal + warm sand accent, this gives 3-line clarity without needing additional hues.

### Dark mode chart rule

Per Gemini: dark mode charts use *fewer* categories than light mode, not more. Contrast compresses in dark backgrounds. Practical rule:
- Light mode: up to 6 chart categories before forcing "Other" collapse
- Dark mode: up to 4 chart categories before forcing "Other" collapse

If a chart can't degrade gracefully to 4 categories, redesign the chart, don't invent dark-mode-only colors.

---

## 6. Surfaces, Spacing, Radii

### Surface tokens (light / dark)

| Token | Light | Dark |
|---|---|---|
| `surfaceApp` | `#F5F5F7` | `#000000` |
| `surfaceCard` | `#FFFFFF` | `#1C1C1E` |
| `surfaceInset` | `#F5F5F7` | `#2C2C2E` |
| `surfaceModal` | `#FFFFFF` | `#1C1C1E` |
| `surfaceDivider` | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.10)` |

### Spacing scale (8pt grid with 4pt half-steps)

`4 / 8 / 12 / 16 / 24 / 32 / 48` pt

Token names: `Spacing.xxs` (4) / `xs` (8) / `sm` (12) / `md` (16) / `lg` (24) / `xl` (32) / `xxl` (48).

### Corner radii

Nested radii descend, so curves harmonize when components nest:

| Token | Radius | Use |
|---|---|---|
| `Radius.card` | 12pt | Outer cards, modals |
| `Radius.input` | 8pt | Text fields, dropdowns, segmented controls |
| `Radius.button` | 6pt | Buttons (all sizes) |
| `Radius.badge` | 4pt | Tags, labels, status pills (rounded rectangles) |
| `Radius.capsule` | `height/2` | True pills (reserved for future use) |

---

## 7. Numerical Color Rules (Critical)

This is where the strict contract pays off. Numerical color is a recurring source of bugs and visual noise, so we're prescriptive:

| Number type | Color | Example |
|---|---|---|
| Headline answer | `textPrimary` (`#1A1A1A`) | "Total Tax: **$12,847**" |
| Refund amount | `textPrimary` + green REFUND badge nearby | "**$1,830** [REFUND]" |
| Tax owed | `textPrimary` (NOT red) | "Owed: **$3,212**" |
| Action-required deadline text | `Color.Semantic.amber` | "Due **Jun 15**" |
| Action-required dollar amount | `textPrimary` (NOT amber) | "**$3,212** Due Jun 15" |
| Comparative delta (any sign) | `textSecondary` (`#666`) | "+$1,240 vs 2025" |
| Disabled / projected value | `textTertiary` (`#8A8A8A`) | "Projected: $14,200" |
| Form-validation error value | `Color.Semantic.red` | "$**XYZ** invalid" |

The most-violated rule today is "tax owed should be red." It's not. Per WCAG and per the app's domain logic, taxes are a mechanical reality, not an error state. Coloring them red is emotional design, not informational design.

---

## 8. Migration Scope

Estimated ~800 call sites across all view files. The token system makes the migration mechanical: replace hardcoded colors with token references, then verify visually.

### Files definitely affected

- `RetireSmartIRA/Assets.xcassets/AccentColor.colorset/Contents.json` — populate with brand teal
- `RetireSmartIRA/Theme/` — new directory for tokens
  - `Color+UI.swift` — surfaces, text, brand, button states
  - `Color+Semantic.swift` — green, amber, red + tints
  - `Color+Chart.swift` — teal hero + grays + sand + teal ramp
  - `Spacing.swift` — spacing scale
  - `Radius.swift` — corner radius scale
- View files (every screen):
  - `DashboardView.swift`
  - `TaxPlanningView.swift`
  - `RMDCalculatorView.swift`
  - `LegacyImpactView.swift`
  - `SocialSecurityPlannerView.swift`
  - `AccountsView.swift`
  - `IncomeSourcesView.swift`
  - `QuarterlyTaxView.swift`
  - `SettingsView.swift`
  - All form / input / drawer subviews
- Component files (new):
  - `MetricCard.swift` — reusable card with top-stripe variant
  - `InfoButton.swift` — reusable info-button token
  - `Badge.swift` — reusable badge component (refund / due / error / neutral)
  - `BrandButton.swift` — reusable button styles (primary / secondary / tertiary / destructive)

### Files probably affected

- Charts: any view using SwiftUI Charts will need its `.foregroundStyle` calls re-pointed at `Color.Chart.*`

### Files NOT affected

- Domain logic (tax calculations, RMD logic, etc.) — pure model code is colorblind
- Data persistence
- Test fixtures

---

## 9. Testing & Verification

Three layers:

### Visual regression

Snapshot tests on top-level screens in light + dark mode using `swift-snapshot-testing`:
- Dashboard
- TaxPlanning
- LegacyImpact
- RMD
- Accounts
- IncomeSources
- QuarterlyTax
- Settings

Catches accidental regressions during the migration. New baseline images are committed once approved.

### Contrast assertions

Unit tests that assert WCAG AA (4.5:1) contrast for:
- All text-on-surface combinations (textPrimary on surfaceCard, textSecondary on surfaceCard, etc.)
- All button states (default, hover, pressed, disabled)
- All badge / pill foreground-on-background combinations
- All chart hero/accent against `surfaceCard`

### Manual smoke checklist (light + dark)

- Every primary user flow from launch screen to a tax-calculation result
- Every modal and confirmation dialog
- Every form validation error state
- Every chart with categorical data (income breakdown, comparison views)
- Every chart with sequential data (brackets, year-over-year)

---

## 10. Out of Scope / Spawned Follow-ups

These are real concerns that surfaced during the brainstorm but don't belong in 1.8.

### Tooltip discoverability (UX research initiative)

Beta users miss most info-button tooltips today. The visual fix in 1.8 (filled brand teal at 16pt) helps but doesn't solve discovery. The deeper work — promoting top tooltips to inline microcopy, first-run tour, telemetry on tap rates — is a separate initiative.

**Spawn as follow-up task.**

### Dynamic Type / VoiceOver audit

The token system makes future accessibility work easier, but a full Dynamic Type pass + VoiceOver labeling audit is its own release. Out of scope here.

### Animation / transition system

Color transitions, view transitions, micro-interactions all benefit from a token system — but the choice of when/where to animate is its own design decision, deferred.

### Typography overhaul

Font sizes / weights / line heights need their own pass. Today's app uses defaults plus ad-hoc overrides. Worth doing, but not in 1.8.

---

## 11. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Migration breaks something subtle (off-by-one shade, wrong card variant on edge case) | Visual regression tests + manual smoke list |
| Sand chart accent visually collides with semantic amber UI element | Avoid adjacency in layout; sand is lighter / less saturated than amber; document the rule in `Color+Chart.swift` header comment |
| Dark mode looks worse than light mode (common failure mode for financial apps) | Per-component dark mode review; reduce chart category count in dark mode; 92%-not-pure-white text |
| Contrast assertion tests fail for existing color combos we want to keep | Each failure is a real bug — fix the color, not the test |
| 800 call sites is bigger than expected and we run over | Stage migration: shared components first, then per-screen. Each screen-level PR can ship independently if the token system is in place. |

---

## 12. Approval & Next Steps

**Approval gate:** John reviews this spec, approves or requests revisions.

**Next step (after approval):** Invoke `superpowers:writing-plans` to break this spec into a step-by-step implementation plan with concrete code changes, test additions, and PR sequencing.

**Estimated scope:** ~3 weeks of focused work. Token infrastructure (week 1), shared component refactor (week 2), per-screen migration + visual regression (week 3).

---

## Appendix A — Full token catalog (reference)

This is the complete list of color tokens that will exist after 1.8. Implementation lives in `RetireSmartIRA/Theme/`.

```swift
extension Color {
  enum UI {
    // Brand
    static let brandTeal             = Color(...)  // #2A6B7C light / #2A7585 dark
    static let brandTealHover        = Color(...)  // #235862 / #3A8595
    static let brandTealPressed      = Color(...)  // #1D4B53 / #4A95A5
    static let brandTealDisabled     = Color(...)  // #A6BDC2 / #4F6B72
    static let brandTealFocusRing    = Color(...)  // #7AC5D6 / #7AC5D6

    // Surfaces
    static let surfaceApp            = Color(...)  // #F5F5F7 / #000000
    static let surfaceCard           = Color(...)  // #FFFFFF / #1C1C1E
    static let surfaceInset          = Color(...)  // #F5F5F7 / #2C2C2E
    static let surfaceModal          = Color(...)  // #FFFFFF / #1C1C1E
    static let surfaceDivider        = Color(...)  // rgba(0,0,0,0.08) / rgba(255,255,255,0.10)

    // Text
    static let textPrimary           = Color(...)  // #1A1A1A / rgba(255,255,255,0.92)
    static let textSecondary         = Color(...)  // #666666 / #9F9FA3
    static let textTertiary          = Color(...)  // #8A8A8A / #7C7C80
    static let textUtility           = Color(...)  // #3A3A3C / #D0D0D0  (tertiary button text)
  }

  enum Semantic {
    // Green (refund only)
    static let green                 = Color(...)  // #2E7D32 / #4CAF50
    static let greenTint             = Color(...)  // #E8F5E9 / rgba(76,175,80,0.20)
    static let greenHover            = Color(...)
    static let greenPressed          = Color(...)
    static let greenDisabled         = Color(...)

    // Amber (action required)
    static let amber                 = Color(...)  // #B85C00 / #E08A3A
    static let amberTint             = Color(...)  // #FFF3E0 / rgba(224,138,58,0.18)
    static let amberHover            = Color(...)
    static let amberPressed          = Color(...)
    static let amberDisabled         = Color(...)

    // Red (error / blocking only)
    static let red                   = Color(...)  // #C62828 / #EF5350
    static let redTint               = Color(...)  // #FFEBEE / rgba(239,83,80,0.18)
    static let redHover              = Color(...)
    static let redPressed            = Color(...)
    static let redDisabled           = Color(...)
  }

  enum Chart {
    // Hero + grays + accent (categorical with hero)
    static let heroTeal              = Color.UI.brandTeal  // alias
    static let callout               = Color(...)  // #C28E4A / #D9A765 (warm sand)
    static let calloutHover          = Color(...)
    static let calloutPressed        = Color(...)
    static let calloutDisabled       = Color(...)

    static let gray1                 = Color(...)  // #7A7D85
    static let gray2                 = Color(...)  // #9DA1A8
    static let gray3                 = Color(...)  // #BCC0C6
    static let gray4                 = Color(...)  // #D8DADD
    static let gray5                 = Color(...)  // #E8E9EB

    // Teal ramp (ordered/sequential data)
    static let tealRamp1             = Color(...)  // #1F4F5C
    static let tealRamp2             = Color(...)  // #2A6B7C (= brandTeal)
    static let tealRamp3             = Color(...)  // #4D8A99
    static let tealRamp4             = Color(...)  // #7AA9B5
    static let tealRamp5             = Color(...)  // #A7C4CC
    static let tealRamp6             = Color(...)  // #CBDBDF
  }
}
```

Hex literals shown for reference; actual implementation will use `Color(red:green:blue:)` initializers or named asset catalog entries with light/dark variants.

---

*End of spec.*
