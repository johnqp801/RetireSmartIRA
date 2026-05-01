# Inline-Hint Vocabulary Standardization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land a new `InlineHint` component, sweep ~22 ad-hoc `info.circle + Text` HStacks to use it, convert 1 SS-planner popover to the canonical `InfoButton`, mark 7 status-indicator instances with explanatory comments, and document the icon-vocabulary in `Theme/README.md`.

**Architecture:** New `InlineHint(_ text:)` component with single canonical style (gray outlined `info.circle` + caption text in `Color.UI.textSecondary`). Single-pass mechanical conversion across 10 view files, one commit per file for clean revertability. The canonical `InfoButton` (1.8 component, 0 production deployments to date) gets its first deployment via the SS planner popover conversion.

**Tech Stack:** SwiftUI · existing `InfoButton` + `Color.UI.textSecondary` token system · XCTest

**Source spec:** `docs/superpowers/specs/2026-05-01-inline-hint-vocabulary-design.md`

---

## Working agreement

- **Branch:** `1.9/inline-hint-vocabulary`, branched from main. Independent of PR #1 (snapshot testing) and PR #2 (MetricCard sweep) — touches different surface area.
- **No new dependencies.** Pure SwiftUI + existing tokens.
- **No test changes beyond the new `InlineHintTests.swift`.** Existing 688+ tests must keep passing.
- **No `project.pbxproj` edits.** Project uses Xcode 16's `PBXFileSystemSynchronizedRootGroup`.
- **`xcodebuild` invocations** use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` prefix.
- **Per-file commits during conversion sweep.** Clean revert path if any single file's conversion looks wrong.
- **Visual verification deferred to user.** Inline execution can't run the live app; PR body flags visual review as a reviewer responsibility.
- **Pre-existing working tree changes** (`project.pbxproj`, `Theme/README.md`) inherited from main — leave alone, don't include in any commit.

---

## File structure

**New files:**

```
RetireSmartIRA/Theme/Components/InlineHint.swift           ← NEW component, ~30 lines
RetireSmartIRATests/InlineHintTests.swift                   ← NEW test file, ~25 lines
```

**Modified files (in conversion sweep):**

```
RetireSmartIRA/DashboardView.swift                          ← 2 InlineHint conversions, 3 status comments
RetireSmartIRA/SettingsView.swift                           ← 1 InlineHint conversion
RetireSmartIRA/SSDataEntryView.swift                        ← 2 InlineHint conversions, 1 status comment
RetireSmartIRA/IncomeSourcesView.swift                      ← 1 InlineHint conversion
RetireSmartIRA/SSCouplesStrategyView.swift                  ← 3 InlineHint conversions
RetireSmartIRA/RothConversionView.swift                     ← 1 InlineHint conversion
RetireSmartIRA/RMDCalculatorView.swift                      ← 2 InlineHint conversions
RetireSmartIRA/SocialSecurityPlannerView.swift              ← 5 InlineHint + 1 InfoButton conversion
RetireSmartIRA/SSSurvivorAnalysisView.swift                 ← 1 InlineHint conversion
RetireSmartIRA/GuideView.swift                              ← 1 InlineHint conversion
RetireSmartIRA/TaxPlanningView.swift                        ← 2 InlineHint conversions, 2 status comments
RetireSmartIRA/ScenarioChartsView.swift                     ← 1 status comment
RetireSmartIRA/Theme/README.md                              ← MODIFY: vocabulary section
RetireSmartIRA/Theme/Components/InfoButton.swift            ← MODIFY: header comment cross-reference
```

**Files left alone (out of scope for this PR):**
- `ClickwrapView.swift:140` — `icon: "info.circle"` passed as parameter to helper component; not a direct usage
- `RMDCalculatorView.swift:258` — `Label(..., systemImage: "questionmark.circle")` — different icon family (questionmark, not info), used in Button label; not an inline-hint candidate
- `RMDCalculatorView.swift:1231` — `icon: "info.circle"` passed as parameter to helper component
- `SSCouplesStrategyView.swift:475` — `questionmark.circle` — different icon family
- `StateComparisonView.swift:468` — string return value from a function (`return "info.circle.fill"`); not a direct usage

---

## Phase 0 — Setup

### Task 0.1: Create feature branch

**Files:** N/A (git only)

- [ ] **Step 1: Create branch from main**

```bash
git checkout main
git checkout -b 1.9/inline-hint-vocabulary
```

Expected: `Switched to a new branch '1.9/inline-hint-vocabulary'`.

- [ ] **Step 2: Verify clean state**

```bash
git status
```

Expected: only the pre-existing `M RetireSmartIRA.xcodeproj/project.pbxproj` and `M RetireSmartIRA/Theme/README.md`. **Do not stage or commit either pre-existing change** — they're inherited from main's working tree state and will normalize when PR #1 merges.

If anything else is modified, stop and resolve before proceeding.

---

### Task 0.2: Confirm baseline tests

**Files:** N/A (verification only)

- [ ] **Step 1: Run the full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -cE "passed on 'My Mac"
```

Expected: 688 (or higher if PR #1 / PR #2 have merged in the meantime).

- [ ] **Step 2: Note the baseline count**

Record the exact number. The completion gate: every later xcodebuild test run reports the same count + 4 new InlineHint behavior tests, with 0 failures.

---

## Phase 1 — Build `InlineHint` component (TDD)

### Task 1.1: `InlineHint` component + tests

**Files:**
- Create: `RetireSmartIRA/Theme/Components/InlineHint.swift`
- Create: `RetireSmartIRATests/InlineHintTests.swift`

- [ ] **Step 1: Write failing tests first**

Create `RetireSmartIRATests/InlineHintTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class InlineHintTests: XCTestCase {
    func test_constructsWithText() {
        let hint = InlineHint("State tax only — local/city taxes are not included.")
        XCTAssertEqual(hint.text, "State tax only — local/city taxes are not included.")
    }

    func test_constructsWithEmptyText() {
        // Edge case: empty string should not crash.
        let hint = InlineHint("")
        XCTAssertEqual(hint.text, "")
    }

    func test_constructsWithMultilineText() {
        let multiline = "First line of hint.\nSecond line wraps to a new line for clarity."
        let hint = InlineHint(multiline)
        XCTAssertEqual(hint.text, multiline)
    }

    func test_isViewType() {
        // The component must conform to View.
        let hint = InlineHint("Test")
        let _: any View = hint
    }
}
```

- [ ] **Step 2: Run tests — expect compile error (InlineHint not defined)**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/InlineHintTests \
  -quiet 2>&1 | tail -10
```

Expected: build fails with "Cannot find 'InlineHint' in scope" or similar.

- [ ] **Step 3: Create the component**

Create `RetireSmartIRA/Theme/Components/InlineHint.swift`:

```swift
import SwiftUI

/// Static, always-visible icon+text hint. Use for short disclaimers, clarifying notes,
/// or contextual guidance that should reach every user without requiring a tap.
///
/// For longer explanations that benefit from one-tap access, use `InfoButton` instead
/// (filled brand-teal icon, opens a popover or sheet).
///
/// For threshold-based status indicators (icon flips between info.circle and
/// exclamationmark.triangle.fill based on data state), keep the ad-hoc `Image`
/// switch — that's a different pattern from this component.
///
/// See `RetireSmartIRA/Theme/README.md` for the full icon-vocabulary documentation
/// and `docs/superpowers/specs/2026-05-01-inline-hint-vocabulary-design.md` for design.
struct InlineHint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(Color.UI.textSecondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.UI.textSecondary)
        }
    }
}

#Preview("Single line — light") {
    InlineHint("State tax only — local/city taxes (e.g. NYC) are not included.")
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Multiline — light") {
    InlineHint("Your spouse's income, filing status, and age come from your household inputs — no additional heir details needed.")
        .padding()
        .frame(width: 320)
        .preferredColorScheme(.light)
}

#Preview("Single line — dark") {
    InlineHint("State tax only — local/city taxes (e.g. NYC) are not included.")
        .padding()
        .background(Color.UI.surfaceCard)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 4: Run tests — expect 4 passing**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/InlineHintTests \
  -quiet 2>&1 | tail -10
```

Expected: 4 tests pass.

- [ ] **Step 5: Run full suite — expect baseline + 4**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -cE "passed on 'My Mac"
```

Expected: baseline + 4 (e.g., 692 if baseline is 688).

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRA/Theme/Components/InlineHint.swift \
        RetireSmartIRATests/InlineHintTests.swift
git commit -m "Add InlineHint component for static icon+text hints"
```

---

## Phase 2 — Conversion sweep

Per-file commits. Each task ends with a build check + commit.

### Task 2.1: Convert SS planner popover to canonical `InfoButton`

**Files:** Modify `RetireSmartIRA/SocialSecurityPlannerView.swift:198-213`

The current pattern wraps an `info.circle` Button with a popover. Convert to use the canonical `InfoButton` component (which provides the filled brand-teal icon at 16pt with a 24pt hit target).

- [ ] **Step 1: Replace the ad-hoc popover button**

Use `Edit` to replace this block (lines 198-213):

```swift
                    HStack(spacing: 6) {
                        Text("Social Security")
                            .font(.headline)
                        if hasBenefitData && bothPlanning {
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
                        }
                    }
```

with:

```swift
                    HStack(spacing: 6) {
                        Text("Social Security")
                            .font(.headline)
                        if hasBenefitData && bothPlanning {
                            InfoButton {
                                showInfoPopover.toggle()
                            }
                            .popover(isPresented: $showInfoPopover) {
                                analysisInfoPopover
                            }
                        }
                    }
```

The `InfoButton` component renders the filled brand-teal `info.circle.fill` at 16pt with the proper 24pt hit target. The popover behavior is preserved by attaching `.popover(...)` to the `InfoButton` (matches the prior pattern; `.popover` doesn't care that the underlying view changed).

- [ ] **Step 2: Build to confirm compile**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | head -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRA/SocialSecurityPlannerView.swift
git commit -m "Convert SS planner popover to canonical InfoButton"
```

---

### Task 2.2: Convert inline hints in DashboardView (2 instances)

**Files:** Modify `RetireSmartIRA/DashboardView.swift:215-223, 660-668`

- [ ] **Step 1: Find the exact "Add income sources" hint**

```bash
grep -n -B 1 -A 6 "Add income sources in the Income" RetireSmartIRA/DashboardView.swift | head -15
```

This locates the first inline-hint pattern. Use `Edit` to replace (the exact `old_string` will be the HStack found):

```swift
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("Add income sources in the Income & Deductions tab")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
```

with:

```swift
                InlineHint("Add income sources in the Income & Deductions tab")
```

Note: this instance currently uses brand-teal icon as a call-to-action signal. The replacement uses `Color.UI.textSecondary` (gray) per the canonical InlineHint style. Visually a subtle shift — flag for user review during PR.

- [ ] **Step 2: Find the "State tax only" disclaimer**

```bash
grep -n -B 1 -A 6 "State tax only" RetireSmartIRA/DashboardView.swift | head -15
```

Replace:

```swift
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text("State tax only \u{2014} local/city taxes (e.g. NYC) are not included.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
```

with:

```swift
                InlineHint("State tax only \u{2014} local/city taxes (e.g. NYC) are not included.")
```

- [ ] **Step 3: Build to confirm**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | head -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add RetireSmartIRA/DashboardView.swift
git commit -m "Convert DashboardView inline hints to InlineHint component (2 instances)"
```

---

### Task 2.3: Convert inline hint in SettingsView (1 instance)

**Files:** Modify `RetireSmartIRA/SettingsView.swift:137-144`

This instance uses the FILLED `info.circle.fill` icon currently. Per the spec, filled icons that aren't tappable belong as InlineHint (outlined). The conversion changes the visual from filled-brand-teal to outlined-secondary — flag for user review during PR.

- [ ] **Step 1: Replace the heir-clarification hint**

Use `Edit`:

```swift
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Color.UI.brandTeal)
                                .font(.caption)
                            Text("Your spouse's income, filing status, and age come from your household inputs — no additional heir details needed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
```

with:

```swift
                        InlineHint("Your spouse's income, filing status, and age come from your household inputs — no additional heir details needed.")
```

- [ ] **Step 2: Build to confirm**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | head -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRA/SettingsView.swift
git commit -m "Convert SettingsView heir-clarification hint to InlineHint"
```

---

### Task 2.4: Convert inline hints across remaining views (single sweep)

This task batches the remaining ~17 inline-hint conversions across 8 files into one task with multiple edits, each followed by a build check, then one commit at the end. Per-file commits start to feel excessive at this point — these are all mechanical replacements following the same pattern.

**Files:**
- Modify: `RetireSmartIRA/SSDataEntryView.swift` (lines ~321, ~406)
- Modify: `RetireSmartIRA/IncomeSourcesView.swift` (line ~416)
- Modify: `RetireSmartIRA/SSCouplesStrategyView.swift` (lines ~736, ~1241, ~1275)
- Modify: `RetireSmartIRA/RothConversionView.swift` (line ~185)
- Modify: `RetireSmartIRA/RMDCalculatorView.swift` (lines ~149, ~634)
- Modify: `RetireSmartIRA/SocialSecurityPlannerView.swift` (lines ~264, ~562, ~867, ~1378, ~1428)
- Modify: `RetireSmartIRA/SSSurvivorAnalysisView.swift` (line ~287)
- Modify: `RetireSmartIRA/GuideView.swift` (line ~279)
- Modify: `RetireSmartIRA/TaxPlanningView.swift` (lines ~1202, ~2168)

For each location, the conversion pattern is the same:

1. Find the HStack containing `Image(systemName: "info.circle"*)` paired with adjacent `Text(...)`.
2. Replace the entire HStack with `InlineHint("<the same text content>")`.
3. Preserve any conditional `if` wrappers around the original HStack.

- [ ] **Step 1: Per-file conversion — SSDataEntryView (2 instances)**

```bash
grep -n -B 1 -A 8 "info\.circle" RetireSmartIRA/SSDataEntryView.swift | head -40
```

For each non-status instance found at L321 and L406, locate the surrounding HStack and replace with `InlineHint("<text>")`. (L979 is a status indicator — skip in this task; covered in Task 2.5.)

- [ ] **Step 2: Per-file conversion — IncomeSourcesView (1 instance)**

```bash
grep -n -B 1 -A 8 "info\.circle" RetireSmartIRA/IncomeSourcesView.swift | head -15
```

L416 — replace the HStack with `InlineHint("<text>")`.

- [ ] **Step 3: Per-file conversion — SSCouplesStrategyView (3 instances)**

```bash
grep -n -B 1 -A 8 "info\.circle" RetireSmartIRA/SSCouplesStrategyView.swift | head -30
```

L736, L1241, L1275 — convert each. (L475 is `questionmark.circle` — different icon family, leave alone.)

- [ ] **Step 4: Per-file conversion — RothConversionView (1 instance)**

L185 — convert.

- [ ] **Step 5: Per-file conversion — RMDCalculatorView (2 instances)**

L149, L634 — convert. (L258 is a Button-Label with `questionmark.circle`, L1231 is a helper-passed icon string — both leave alone.)

- [ ] **Step 6: Per-file conversion — SocialSecurityPlannerView (5 instances)**

L264, L562, L867, L1378, L1428 — convert. (L202 was already handled in Task 2.1.)

- [ ] **Step 7: Per-file conversion — SSSurvivorAnalysisView (1 instance)**

L287 — convert.

- [ ] **Step 8: Per-file conversion — GuideView (1 instance)**

L279 — convert.

- [ ] **Step 9: Per-file conversion — TaxPlanningView (2 instances)**

L1202, L2168 — convert. (L2907 and L3061 are status indicators — skip in this task; covered in Task 2.5.)

- [ ] **Step 10: Build to confirm everything still compiles**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | head -5
```

Expected: `** BUILD SUCCEEDED **`. If any conversion broke compilation (likely cause: an HStack had additional modifiers that need to move to the InlineHint, or the surrounding code expected the HStack as a tuple of subviews), surface the file + line for inspection rather than guessing.

- [ ] **Step 11: Commit all converted files together**

```bash
git add RetireSmartIRA/SSDataEntryView.swift \
        RetireSmartIRA/IncomeSourcesView.swift \
        RetireSmartIRA/SSCouplesStrategyView.swift \
        RetireSmartIRA/RothConversionView.swift \
        RetireSmartIRA/RMDCalculatorView.swift \
        RetireSmartIRA/SocialSecurityPlannerView.swift \
        RetireSmartIRA/SSSurvivorAnalysisView.swift \
        RetireSmartIRA/GuideView.swift \
        RetireSmartIRA/TaxPlanningView.swift
git commit -m "Convert ad-hoc info.circle inline hints to InlineHint across 9 view files"
```

---

### Task 2.5: Add explanatory comments to status-indicator instances

**Files:**
- Modify: `RetireSmartIRA/DashboardView.swift` (lines ~693, ~712, ~1953)
- Modify: `RetireSmartIRA/SSDataEntryView.swift` (line ~979)
- Modify: `RetireSmartIRA/ScenarioChartsView.swift` (line ~716)
- Modify: `RetireSmartIRA/TaxPlanningView.swift` (lines ~2907, ~3061)

These 7 instances use threshold-based icon switches (`info.circle` ↔ `exclamationmark.triangle.fill`) and are NOT inline-hint candidates. They're status indicators — leave them as-is and add an explanatory comment.

The standard comment format:

```swift
// Status indicator (threshold-based icon flip) — distinct from InfoButton/InlineHint vocabulary.
// See docs/superpowers/specs/2026-05-01-inline-hint-vocabulary-design.md §4.
```

- [ ] **Step 1: DashboardView L693 (IRMAA threshold indicator)**

Find the line:
```swift
                            Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
```

Add the 2-line comment immediately above (matching surrounding indentation).

- [ ] **Step 2: DashboardView L712 (IRMAA threshold indicator)**

Same as Step 1, different line.

- [ ] **Step 3: DashboardView L1953 (IRMAA threshold indicator)**

Same as Step 1, different line.

- [ ] **Step 4: SSDataEntryView L979**

Find:
```swift
                    Image(systemName: abs(pct) > 10 ? "exclamationmark.triangle" : "info.circle")
```

Add comment above (this one switches based on percentage threshold, but the pattern is the same).

- [ ] **Step 5: ScenarioChartsView L716**

Find:
```swift
                        Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
```

Add comment above.

- [ ] **Step 6: TaxPlanningView L2907**

Same pattern, add comment above.

- [ ] **Step 7: TaxPlanningView L3061**

```swift
                        Image(systemName: niit.distanceToThreshold < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
```

Same pattern, add comment above.

- [ ] **Step 8: Build to confirm comments don't break anything**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | head -5
```

Expected: `** BUILD SUCCEEDED **`. (Comments shouldn't break compilation, but we built once for safety.)

- [ ] **Step 9: Commit**

```bash
git add RetireSmartIRA/DashboardView.swift \
        RetireSmartIRA/SSDataEntryView.swift \
        RetireSmartIRA/ScenarioChartsView.swift \
        RetireSmartIRA/TaxPlanningView.swift
git commit -m "Document 7 status-indicator instances as distinct from InlineHint/InfoButton"
```

---

## Phase 3 — Documentation

### Task 3.1: Update Theme/README.md and InfoButton.swift header

**Files:**
- Modify: `RetireSmartIRA/Theme/README.md` (add vocabulary section)
- Modify: `RetireSmartIRA/Theme/Components/InfoButton.swift` (header comment cross-reference)

- [ ] **Step 1: Add vocabulary section to Theme/README.md**

Read the current README:

```bash
cat RetireSmartIRA/Theme/README.md | head -100
```

Find a good insertion point — probably after the "Components" section or near where `InfoButton` is described. Add this new subsection:

```markdown
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
```

- [ ] **Step 2: Update InfoButton.swift header comment**

Read the current header:

```bash
sed -n '1,15p' RetireSmartIRA/Theme/Components/InfoButton.swift
```

Use `Edit` to add a one-line cross-reference. The existing header is short; append a "See also" line. Specifically, replace the existing header comment block with:

```swift
//
//  InfoButton.swift
//  RetireSmartIRA
//
//  Filled brand-teal `info.circle.fill` button at 16pt with a 24pt hit target.
//  Use for tappable explanations that open a popover or sheet.
//
//  For static, always-visible icon+text hints (short disclaimers, clarifying
//  notes), use `InlineHint` instead.
//
//  See `RetireSmartIRA/Theme/README.md` for the full icon-vocabulary documentation.
//
```

If the existing header doesn't match this format (it might be a doc comment on the struct itself rather than a file header), adapt the placement — the goal is a discoverable cross-reference to `InlineHint`.

- [ ] **Step 3: Build to confirm**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | head -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add RetireSmartIRA/Theme/README.md \
        RetireSmartIRA/Theme/Components/InfoButton.swift
git commit -m "Document icon vocabulary: InfoButton vs InlineHint vs status indicator"
```

---

## Phase 4 — Validation + PR

### Task 4.1: Final test suite verification

**Files:** N/A (verification only)

- [ ] **Step 1: Run the full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -cE "passed on 'My Mac"
```

Expected: baseline + 4 (the 4 new InlineHint behavior tests). Specifically:
- 692 if Task 0.2 baseline was 688
- 736 if Task 0.2 baseline was 732 (PR #1 had merged)
- 692 if Task 0.2 baseline was 688 and PR #2 had merged (PR #2 didn't add tests)

- [ ] **Step 2: Confirm no `project.pbxproj` modifications from this work**

```bash
git diff main..1.9/inline-hint-vocabulary -- RetireSmartIRA.xcodeproj/project.pbxproj
```

Expected: empty diff. If non-empty, something inadvertently touched the pbxproj — investigate before merging.

- [ ] **Step 3: Confirm test changes are limited to the new InlineHintTests.swift**

```bash
git diff main..1.9/inline-hint-vocabulary --name-only -- RetireSmartIRATests/
```

Expected: only `RetireSmartIRATests/InlineHintTests.swift` listed. No other test files touched.

---

### Task 4.2: Push branch + create PR

**Files:** N/A (git only)

- [ ] **Step 1: Push the branch**

```bash
git push -u origin 1.9/inline-hint-vocabulary 2>&1 | tail -5
```

Expected: `* [new branch]      1.9/inline-hint-vocabulary -> 1.9/inline-hint-vocabulary`.

- [ ] **Step 2: Create the PR**

```bash
gh pr create --title "1.9 Task 4: Icon vocabulary standardization (InlineHint + InfoButton deployment)" --body "$(cat <<'EOF'
## Summary

Tighter execution of 1.9 Task 4. The roadmap's original framing was "tooltip discoverability + first-run tour + tap telemetry," but a pre-brainstorm audit found the codebase reality didn't match — `InfoButton` (the canonical 1.8 component) is deployed 0 times in production, ~25-28 of the 34 \`info.circle*\` instances are already inline microcopy via ad-hoc HStacks, and `GuideView` already serves the first-run-orientation role a tour would fill. This PR reframes Task 4 as **icon vocabulary standardization**.

## What landed

**New:** `InlineHint(_ text:)` component with single canonical style (outlined `info.circle` + gray caption text). 4 behavior tests in `InlineHintTests.swift`.

**Conversions:**
- 1× ad-hoc popover button → canonical `InfoButton` (SS planner, the one real tooltip)
- ~22× ad-hoc `Image + Text` HStacks → `InlineHint` (across 10 view files)
- 7× status-indicator instances annotated with explanatory comments (left as-is — they're a different pattern from InlineHint/InfoButton)

**Documentation:**
- New "Tooltip & inline-hint vocabulary" section in `Theme/README.md`
- `InfoButton.swift` header comment cross-references `InlineHint`

**Out of scope (rejected during brainstorm):**
- First-run tour — `GuideView` already covers this
- Tap telemetry — insufficient tap surface (only 1-2 actual tooltips in the app)
- New tooltips beyond the SS planner conversion — content work, not vocabulary work
- `StatusIndicator` component extraction — YAGNI given ~7 usages

## Test plan

- [x] All baseline tests still pass (no behavior changes — pure UI substitution)
- [x] 4 new `InlineHintTests` pass
- [x] `xcodebuild build` succeeds after each conversion phase
- [x] No `project.pbxproj` modifications
- [x] No SPM dependencies added
- [x] Test changes limited to the new `InlineHintTests.swift`

## Manual visual review (deferred to reviewer)

This PR was implemented via inline execution; live SwiftUI rendering wasn't visually inspected during execution. Before merging, please verify in light + dark mode:

1. **Each affected screen** renders the inline hints with the new gray-icon + gray-caption style
2. **Two specific instances had visual shifts** during conversion (flag for closer inspection):
   - `DashboardView` "Add income sources" hint — was brand-teal icon, now gray (per canonical InlineHint style)
   - `SettingsView` heir-clarification hint — was filled brand-teal `info.circle.fill`, now outlined gray
3. **SS planner popover button** — should now show the filled brand-teal `info.circle.fill` at 16pt (canonical `InfoButton` look) instead of the prior subheadline-size outlined version. Tap should still open the analysis popover.

If any layout looks broken or the visual shifts feel wrong, revert the relevant commit (one per file or category for clean revert).

## Spec / plan

- Spec: `docs/superpowers/specs/2026-05-01-inline-hint-vocabulary-design.md`
- Plan: `docs/superpowers/plans/2026-05-01-inline-hint-vocabulary.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" 2>&1 | tail -3
```

Expected: outputs the URL of the new PR.

- [ ] **Step 3: Confirm PR is open**

The output of Step 2 includes the PR URL (e.g., `https://github.com/johnqp801/RetireSmartIRA/pull/3`). Visit it to confirm:
- Title is correct
- Body renders the markdown
- Diff shows the expected files (~13 view/component/doc files + 1 new test file)
- No `project.pbxproj` or other-test-file changes in the diff

---

## Out of scope for this plan

These were rejected during brainstorm and explicitly do NOT belong in this PR:

- First-run tour
- Tap telemetry on `InfoButton`
- New tooltip content for IRMAA / RMD / Safe Harbor / etc.
- `StatusIndicator` component extraction
- `InlineHint` style variants (keep single canonical style for now)
- Sweep of `Image(systemName:)` patterns other than `info.circle*` and `info.circle.fill`
- Conversion of helper-passed icon strings (`ClickwrapView:140`, `RMDCalculatorView:1231`) — those go through abstraction layers we're not touching

If any come up during execution, stop and report rather than expanding scope.

---

*End of plan.*
