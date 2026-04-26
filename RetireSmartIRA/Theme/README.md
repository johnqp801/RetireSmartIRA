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
| `InfoButton` | `Components/InfoButton.swift` | Tooltip trigger, ⓘ |
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

## Adding a new color

Don't, until you've checked: which job does it have? If the job overlaps an existing token, reuse. If a new job exists, add it to the appropriate namespace, document it in this README, and update the design spec.
