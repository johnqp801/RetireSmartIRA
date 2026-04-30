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

## Snapshot testing (added in 1.9 — Pass 1)

The four components in this directory have automated snapshot tests in `RetireSmartIRATests/`:

- `BrandButtonSnapshotTests.swift` — 12 baselines (6 styles × 2 modes)
- `MetricCardSnapshotTests.swift` — 6 baselines (3 categories × 2 modes)
- `BadgeSnapshotTests.swift` — 8 baselines (4 variants × 2 modes)
- `InfoButtonSnapshotTests.swift` — 2 baselines (1 style × 2 modes)

PNG baselines live in `RetireSmartIRATests/__Snapshots__/<TestClass>/<name>.png` and are committed to git.

### When you change a component

If your change affects rendering, the corresponding snapshot tests will fail. Re-record the affected baselines:

- **Re-record one test:** delete the PNG and run that test once.
- **Re-record everything:** set `RECORD_SNAPSHOTS=1` in the test scheme's environment variables and run `Cmd+U`. All snapshot tests will "fail" with "Recorded baseline at …" messages. Unset the env var, run again, all green.

Always visually inspect the new PNG before committing — if it doesn't match the component's `#Preview` rendering in Xcode Canvas, something is broken in the component, not the snapshot.

### Why homebrew (not swift-snapshot-testing)

The 1.8 attempt to use PointFree's library hit linker failures with Xcode 16's Swift Testing integration. The in-house helper at `RetireSmartIRATests/SnapshotHelper.swift` has zero external dependencies (uses SwiftUI's built-in `ImageRenderer` + `XCTAttachment`). See the file's header comment for design notes and `docs/superpowers/specs/2026-04-29-snapshot-testing-design.md` for full context.

## Adding a new color

Don't, until you've checked: which job does it have? If the job overlaps an existing token, reuse. If a new job exists, add it to the appropriate namespace, document it in this README, and update the design spec.
