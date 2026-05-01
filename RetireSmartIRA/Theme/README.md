# RetireSmartIRA Theme System

Tokens and reusable components for the 1.8+ design system.

**Spec:** `docs/superpowers/specs/2026-04-25-color-system-design.md`
**Plan:** `docs/superpowers/plans/2026-04-25-color-system.md`

## Quick reference

### Color tokens (3 namespaces — STRICTLY non-overlapping)

| Namespace | Purpose | Example |
|---|---|---|
| `Color.UI.*` | Brand identity, surfaces, text | `Color.UI.brandTeal` |
| `Color.Semantic.*` | Meaning-bearing (refund / action / error) | `Color.Semantic.amber` |
| `Color.Chart.*` | Data visualization only | `Color.Chart.heroTeal` |

### Components

| Component | File | Use case |
|---|---|---|
| `BrandButton` | `Components/BrandButton.swift` | All buttons — 6 style variants |
| `MetricCard` | `Components/MetricCard.swift` | Top-stripe metric cards |
| `InfoButton` | `Components/InfoButton.swift` | Tappable tooltip trigger, opens popover |
| `InlineHint` | `Components/InlineHint.swift` | Always-visible icon+text hint (short disclaimers) |
| `Badge` | `Components/Badge.swift` | Inline category label (REFUND, DUE, etc.) |

### Spacing & radius

| Token | Use |
|---|---|
| `Spacing.xxs` (4) → `Spacing.xxl` (48) | Padding, gaps |
| `Radius.card` (12) | Outer cards |
| `Radius.input` (8) | Text fields |
| `Radius.button` (6) | Buttons |
| `Radius.badge` (4) | Tags / status badges |
| `Radius.capsule(forHeight:)` | True pills (future use) |

## Strict rules

1. **`Color.Chart.*` never overlaps `Color.Semantic.*`.** Charts use teal + grays + warm sand. No green-meaning-savings, no red-meaning-loss bars.
2. **Green = refund only.** Not savings, not gains, not "good outcomes" generally.
3. **Amber = action required only.** Applied to deadline TEXT and badges. NEVER to dollar amounts themselves.
4. **Red = error / blocking only.** NEVER for "tax owed" — taxes are a mechanical reality.
5. **No yellow.** Tip callouts use gray italic + ⓘ icon.
6. **Tertiary buttons default to gray text.** Teal text only for actions that genuinely advance the user (≈1 in 5 inline links).

## Dark mode

Every token has light + dark variants in the asset catalog. Components consume tokens, so dark mode is automatic.

Special dark-mode rules:
- Body text uses 92% white, not pure white (reduces glare).
- Charts use *fewer* categories in dark mode than light mode (contrast compresses).
- Brand teal in dark mode is `#2A7585` (not the originally proposed `#3D8FA3`) — the darkening was required by WCAG contrast tests on white-text-over-button-background. Foreground usage of brand teal in dark mode (e.g., info-button glyph) qualifies as "large text" per WCAG 1.4.3 and uses the 3.0:1 threshold.

## Verifying components

Open any `Components/*.swift` file in Xcode and use the Canvas (Editor → Canvas, or `⌥⌘↩`) to live-preview the `#Preview` blocks in both light and dark mode. Visual changes during migration should be sanity-checked against the canvas.

XCTest behavior tests live alongside the existing test suite in `RetireSmartIRATests/`. Snapshot testing is deferred to 1.9 — see plan addendum.

## Tooltip & inline-hint vocabulary

Three distinct patterns for explanatory icons. Pick the right one — they look different on purpose.

### `InfoButton` — tappable, opens longer explanation

- Filled `info.circle.fill`, brand-teal, 16pt visual / 24pt hit target
- Tap reveals a popover or sheet with non-trivial explanation
- Use for: concepts that need 1-3 paragraphs (RMD age 73 mechanics, IRMAA brackets, Safe Harbor 110% rule)
- Canonical example as of 1.9: `SocialSecurityPlannerView` analysis popover

### `InlineHint` — always visible, short hint

- Outlined `info.circle`, gray (`Color.UI.textSecondary`), caption-size
- Always visible. Not tappable.
- Use for: short disclaimers, clarifying notes, contextual guidance ≤ 2 sentences
- Examples: "State tax only — local/city taxes are not included.", "Add income sources in the Income & Deductions tab"

### Status indicators (NOT a component)

- Threshold-based icon flip: `info.circle` ↔ `exclamationmark.triangle.fill`
- Pattern is intentionally ad-hoc — the icon switching IS the UX signal
- Don't reach for `InlineHint` or `InfoButton` here; they don't fit
- Each instance has an inline `// Status indicator` comment for future-reader clarity

### When in doubt

If your text fits in one line and is purely informational: `InlineHint`.
If your text needs 1-3 paragraphs: `InfoButton`.
If your icon should change based on data state: leave it ad-hoc with a `// Status indicator` comment.

## Adding a new color

Don't, until you've checked: which job does it have? If the job overlaps an existing token, reuse. If a new job exists, add it to the appropriate namespace, document it in this README, and update the design spec.
