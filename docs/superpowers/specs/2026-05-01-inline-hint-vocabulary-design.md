# 1.9 Task 4 — Icon Vocabulary Standardization (Mini Scope)

**Status:** Approved (2026-05-01)
**Author:** John Urban (with brainstorm collaboration)
**Date:** 2026-05-01
**Target release:** RetireSmartIRA 1.9
**Related docs:**
- `docs/1.9-roadmap.md` — Task 4 entry (original framing was "Tooltip discoverability")
- `docs/superpowers/specs/2026-04-25-color-system-design.md` §4 — `InfoButton` component definition (1.8)
- `docs/beta-feedback/2026-04-23-ron-park-tracking.md` — Ron Park's "missed info buttons" feedback (origin of original framing)

---

## 1. Overview

The 1.9 roadmap framed Task 4 as "promote 5-10 high-value tooltips to inline microcopy + first-run tour + tap telemetry." A pre-brainstorm audit found that the roadmap's premise didn't match the codebase:

**What the roadmap assumed:**
- Many tooltips behind ⓘ buttons that users miss
- A first-run tour would help orient new users
- Telemetry would inform future tooltip-promotion decisions

**What the codebase actually has:**
- `InfoButton` (the canonical 1.8 component) is **deployed 0 times** in production view code
- 34 ad-hoc `Image(systemName: "info.circle*")` instances, of which ~25-28 are **already inline microcopy** (icon + caption text always visible) — just done as ad-hoc HStacks rather than via a standardized component
- Only ~1-2 actual tap-to-reveal tooltips exist (`SocialSecurityPlannerView.showInfoPopover`)
- A first-run tour would be redundant — `GuideView` is already the default first tab (786 lines, includes setup checklist, per-tab guides, key concepts, tips)
- Tap telemetry would have ~1-2 events to record — not enough to inform anything

**The real underlying issue:** the same `info.circle` icon is used inconsistently across the app — sometimes for static disclaimers (always-visible inline hint), sometimes for tap-to-reveal tooltips, sometimes for status indicators that flip based on a threshold. A user can't predict which is which by looking. That ambiguity is what Ron's "I missed most info buttons" comment likely traces to.

This spec reframes Task 4 as a **vocabulary standardization** task: define three clear patterns (`InfoButton`, `InlineHint`, status indicator), replace ad-hoc usage with the standardized components, and document the vocabulary so future code reaches for the right pattern.

### Scope discipline

**In scope:**
- Define and ship a new `InlineHint` component for static, always-visible icon+text hints
- Convert ~25-28 existing ad-hoc `info.circle` + Text HStacks to `InlineHint`
- Convert the SS planner's ad-hoc popover-button pattern to use the canonical `InfoButton` (1 deployment)
- Document the vocabulary in `Theme/README.md` and the `InfoButton.swift` header comment
- Add inline `// Status indicator — distinct from InfoButton/InlineHint` comments to the ~3-5 threshold-based icon flips

**Out of scope:**
- First-run tour — `GuideView` already serves this role
- Tap telemetry — insufficient tap surface to be useful
- New tooltips beyond the SS planner conversion (i.e., no new content; this is purely component-vocabulary work)
- `StatusIndicator` component extraction — YAGNI given ~3-5 usages

**Estimated scope:** ~half day at AI pace, single PR on `1.9/inline-hint-vocabulary` branch.

---

## 2. Decisions log

| # | Decision | Rationale |
|---|---|---|
| 1 | **Reframe Task 4** from "tooltip discoverability + tour + telemetry" to "vocabulary standardization" | Pre-brainstorm audit revealed the roadmap's premise didn't match the codebase. The real issue is icon-vocabulary ambiguity, not missing tooltips. |
| 2 | **Drop first-run tour** | `GuideView` is the default first tab and already provides comprehensive orientation (786 lines, setup checklist, tab guides, key concepts). A separate tour would be redundant. |
| 3 | **Drop tap telemetry** | Only ~1-2 actual tap-to-reveal tooltips exist. Telemetry would have nothing meaningful to record. Reconsider after the vocabulary work if a real tooltip-rich UI emerges. |
| 4 | **New `InlineHint` component, single canonical style** | YAGNI on variants. Most existing usages are visually similar (gray icon + secondary-color caption). If specific spots need brand-teal call-to-action styling, override locally. |
| 5 | **Keep status-indicator pattern ad-hoc** | Only ~3-5 instances; not worth a component. Document in README and add inline comments at each occurrence. |
| 6 | **Convert SS planner popover to canonical `InfoButton`** | The one real tooltip in the app gets the canonical treatment, validating that the component works in deployment. |
| 7 | **No new tooltips** | Adding IRMAA/RMD/Safe Harbor explanations as new `InfoButton` deployments is content work, not vocabulary work. Defer. |

---

## 3. Component design — `InlineHint`

### Public API

```swift
struct InlineHint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View { ... }
}
```

**Single positional argument.** Call site reads as `InlineHint("State tax only — local/city taxes (e.g. NYC) are not included.")` — concise.

### Visual treatment

- Icon: `Image(systemName: "info.circle")` — outlined (NOT filled — distinguishes from `InfoButton.fill`)
- Icon color: `Color.UI.textSecondary`
- Icon size: caption (matches text)
- Text: `font(.caption)`, `foregroundStyle(Color.UI.textSecondary)`
- Layout: `HStack(spacing: 6)` with icon leading + Text. Icon `.alignmentGuide(.firstTextBaseline)` for proper alignment with multi-line text.
- Italic: NO (keeps it readable; the icon already signals "this is supplementary info")

### File location

`RetireSmartIRA/Theme/Components/InlineHint.swift` — alongside the other 4 canonical components (`BrandButton`, `MetricCard`, `Badge`, `InfoButton`).

### `#Preview` blocks

Include both light + dark variants, plus a multi-line example to verify text wrapping behavior.

### Header comment

Document the distinction from `InfoButton`:
- `InlineHint` = static, always visible, not tappable, for short hints/disclaimers/clarifications
- `InfoButton` = tappable, opens popover/sheet, for explanations too long to inline

---

## 4. Conversion categorization

The 34 existing `info.circle*` instances fall into three buckets. Each gets a different action.

### Bucket 1: Convert to `InlineHint` (~25-28 instances)

Pattern (current):
```swift
HStack {
    Image(systemName: "info.circle")
        .foregroundStyle(.secondary)
    Text("State tax only — local/city taxes (e.g. NYC) are not included.")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

Replacement:
```swift
InlineHint("State tax only — local/city taxes (e.g. NYC) are not included.")
```

**Identification rules:**
- Icon is `Image(systemName: "info.circle")` (NOT `.fill`)
- Icon is purely decorative leading element
- Adjacent Text is short caption-style content (1-2 sentences, secondary color)
- Not tappable, no Button wrapper

**Edge cases:** if the existing instance has unusual styling (e.g., brand-teal icon as a call-to-action signal), preserve via inline override:
```swift
InlineHint("Add income sources in the Income & Deductions tab")
    // brand-teal icon override for call-to-action emphasis (Dashboard income breakdown)
```
Out of scope to support this in the component API yet; if more than 2-3 spots need it during the conversion sweep, surface for discussion before mid-sweep API expansion.

### Bucket 2: Status indicators (~3-5 instances)

Pattern (current):
```swift
Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
    .foregroundStyle(distanceToNext < 10_000 ? Color.Semantic.amber : .secondary)
```

**Action:** leave the code as-is. Add a one-line comment immediately above:
```swift
// Status indicator (threshold-based icon flip) — distinct from InfoButton/InlineHint vocabulary.
// See docs/superpowers/specs/2026-05-01-inline-hint-vocabulary-design.md §4.
Image(systemName: distanceToNext < 10_000 ? ...)
```

**Identification rules:**
- Icon depends on a threshold or other dynamic state
- Icon is the primary signal (no adjacent explanatory text, OR text is contextual to the icon's state)
- The icon switching IS the UX

### Bucket 3: Convert to canonical `InfoButton` (1-2 instances)

Pattern (current — SS planner):
```swift
Button {
    showInfoPopover.toggle()
} label: {
    Image(systemName: "info.circle")
        .font(.subheadline)
        .foregroundStyle(Color.UI.brandTeal)
}
.buttonStyle(.plain)
.popover(isPresented: $showInfoPopover) {
    analysisInfoPopover
}
```

Replacement:
```swift
InfoButton {
    showInfoPopover.toggle()
}
.popover(isPresented: $showInfoPopover) {
    analysisInfoPopover
}
```

**Identification rules:**
- Wrapped in a `Button` (or has a tap gesture)
- Triggers a popover/sheet/alert
- The associated content is non-trivial explanation, not a one-liner

The 1.8 spec defined `InfoButton` as the canonical pattern for this case. Task 4 deploys it for the first time.

### Bucket 4 (residual): instances that don't fit any bucket

If the audit during execution finds an instance that doesn't fit cleanly:
- Document why in a quick note
- Pause and surface for discussion before forcing a conversion

Don't shoehorn an instance into the wrong bucket. The audit's value is the categorization, not the conversion.

---

## 5. Documentation update

### `Theme/README.md`

Add a "Tooltip & inline-hint vocabulary" section explaining:
- When to use `InfoButton` (tappable, opens popover, for longer explanations)
- When to use `InlineHint` (always visible, short hints/disclaimers)
- Status indicators are a separate concern — threshold-based icon flips, not tooltip patterns

Format: short, scan-able bullet list with one-line examples per pattern.

### `Theme/Components/InfoButton.swift` header comment

Update the existing header comment to:
- Reference `InlineHint` as the alternative for static disclaimers
- Note that as of 1.9, the canonical deployment example is the SS planner popover

---

## 6. Verification

### Tests

- All ~688 (or ~732 if PR #1 has merged) existing tests must still pass.
- No new test files needed — the conversion is mechanical UI substitution. Pass 1 (PR #1) snapshot tests cover the canonical components; the converted `InfoButton` deployment will be visible in those snapshots if/when re-recorded.
- The new `InlineHint` component should get a behavior test alongside `InfoButton`/`MetricCard`/`Badge` in `RetireSmartIRATests/`. Pattern matches existing `InfoButtonTests.swift` — basic "constructs without crash" + "exposes expected text."

### Manual visual smoke

- Build with `-DemoProfile`, navigate to each affected screen, confirm:
  - Inline hints render with the new component (visually identical to before, since both are gray icon + gray caption — but now from a single source)
  - SS planner tooltip popover still opens on tap and contains the same content
  - No layout regressions on screens that had ad-hoc inline-hint patterns

### Acceptance criteria

- All ~688 (or ~732) pre-existing tests pass
- New `InlineHint` component lands with `#Preview` blocks for light + dark
- `InlineHintTests.swift` adds basic behavior tests
- All ~25-28 inline-hint instances converted
- Status-indicator instances marked with comments
- SS planner popover converted to use canonical `InfoButton`
- `Theme/README.md` documents the vocabulary
- Single PR with a clear description

---

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Conversion sweep accidentally changes visual appearance | The new `InlineHint` is intentionally visually identical to the most common ad-hoc pattern (gray icon + gray caption). Spot-check 4-5 affected screens during execution. |
| `InlineHint`'s single-style API is too restrictive (some spots need brand-teal icon for call-to-action) | If the audit finds 3+ spots that genuinely need different styling, surface for discussion before sweeping. The first 1-2 can use inline overrides; more than that suggests a 2-variant API is warranted. |
| The SS planner popover conversion breaks the existing tooltip behavior | Test the popover open/close + content rendering after the conversion. The `InfoButton` API takes a closure (the action), and `.popover(isPresented:)` is attached separately — same pattern as today, just using the canonical icon. |
| Status-indicator instances misclassified as inline-hints (or vice-versa) | The audit's identification rules are explicit. If unsure, leave as-is and surface for discussion. |
| Pass 1 snapshot tests (in PR #1) may regress when the canonical `InfoButton` is deployed somewhere else | If PR #1 has merged before Task 4 lands, re-running snapshot tests after the SS planner conversion may flag the SS planner's screen-level snapshot (not a thing yet — Pass 2 territory). At Task 4 commit time, only `InfoButton`'s component-level snapshot is live, and Task 4 doesn't change `InfoButton.swift` itself. So no regression expected. Verify by running snapshot tests after the conversion. |

---

## 8. Out of scope (deferred or rejected)

These were considered during brainstorm and explicitly do NOT belong in this PR:

- **First-run tour** — `GuideView` already covers it
- **Tap telemetry** — insufficient tap surface
- **New tooltip content** (IRMAA, RMD age 73, Safe Harbor explanations) — content work, not vocabulary work
- **`StatusIndicator` component** — YAGNI given ~3-5 usages
- **`InlineHint` style variants** — single canonical style; reconsider if conversion sweep finds 3+ legitimately different needs
- **Audit of `Image(systemName:)` more broadly** (other system images used as decorations elsewhere) — only `info.circle*` is in scope; other icons are out of scope

---

## 9. Approval & next steps

**Approval gate:** John reviews this spec, approves or requests revisions.

**Next step (after approval):** Invoke `superpowers:writing-plans` to break this spec into a step-by-step implementation plan. Given the small scope (~half day), the plan is likely:
- Phase 0: Setup (branch, baseline tests)
- Phase 1: Build `InlineHint` component + `InlineHintTests.swift` (TDD)
- Phase 2: Conversion sweep (one task per category)
- Phase 3: Documentation update
- Phase 4: Final validation + PR

**Branch:** `1.9/inline-hint-vocabulary`, branched from main. Independent of PR #1 (snapshot testing) and PR #2 (MetricCard sweep) — touches different surface area.

---

*End of spec.*
