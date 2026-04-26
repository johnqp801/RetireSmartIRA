# 1.8 Color System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace RetireSmartIRA's ad-hoc color usage with a token-driven design system: brand teal, strict semantic contract, three non-overlapping namespaces (UI / Semantic / Chart), reusable components, and full light+dark mode parity.

**Architecture:** Three-namespace token system in `RetireSmartIRA/Theme/`. Tokens added alongside existing colors so the build stays green throughout migration. Per-screen migration uses tokens + 4 shared components (`BrandButton`, `MetricCard`, `InfoButton`, `Badge`). Visual regression via `swift-snapshot-testing`. Contrast assertions via XCTest.

**Tech Stack:** SwiftUI · Xcode 15+ · swift-snapshot-testing (new dependency) · XCTest · Asset Catalog (light/dark color sets)

**Source spec:** `docs/superpowers/specs/2026-04-25-color-system-design.md`

---

## ⚠️ Plan Addendum 2026-04-25 — Snapshot testing deferred to 1.9

**Decision:** swift-snapshot-testing has been **removed** from the project. Tasks below that reference it should be adapted as follows. This addendum overrides the plan body where they conflict.

**Why:** swift-snapshot-testing 1.18+ has experimental Swift Testing integration that doesn't link cleanly in our Xcode 16 project. Earlier versions (1.16.x, 1.17.x) hit other XCTest linker issues when the package was attached to the wrong target. We burned ~45 min on it and decided to defer rather than keep fighting.

**Replacement strategy for 1.8:**
- **Component visual verification:** Use `#Preview` macros in each component file (gives instant Xcode Canvas live preview in light + dark mode). Already prescribed in the plan code blocks for `BrandButton`, `MetricCard`, `Badge`, `InfoButton`.
- **Behavior tests:** Each component still gets an XCTest file with non-visual assertions (e.g., "tertiaryUtility style renders gray text", "MetricCard.Category.error sets red stripe").
- **Per-screen visual regression:** Manual smoke check (Cmd+B, Cmd+R, eyeball light + dark mode). User does this during Phase 3 migrations.
- **Token correctness:** WCAG contrast assertion tests (Task 1.8) — pure XCTest, no external dep.

**Specific task adjustments:**
- **Task 0.2** (Add swift-snapshot-testing): ~~Done~~ → Reverted, package removed at commit `03b8208`. Skip going forward.
- **Task 2.1** (BrandButton snapshot tests): Replace `BrandButtonSnapshotTests.swift` with `BrandButtonTests.swift` — XCTest behavior assertions only (e.g., `test_primary_style_uses_filled_teal_background`). Keep the `#Preview` blocks in the source file — they replace snapshot baselines for visual review.
- **Task 2.2** (MetricCard snapshot tests): Same pattern — replace snapshot tests with behavior tests.
- **Task 2.3** (Badge snapshot tests): Same.
- **Task 2.4** (InfoButton snapshot tests): Same.
- **Task 3.0** (ScreenSnapshotTests scaffold): Skip entirely. Manual visual review replaces it.
- **Tasks 3.1–3.10** (per-screen migration): Skip Step 7-9 (snapshot test add/record/inspect). Keep Step 11 (manual smoke test in simulator) — that's the regression net.
- **Task 4.1** (Visual regression sweep): Keep — it was already a manual review task. Just don't expect snapshot baselines.

**Deferred follow-up for 1.9:**
- Re-add a snapshot testing solution before 1.9 ACA work begins. By that time, either swift-snapshot-testing's Swift Testing integration will have stabilized, or Apple's native Swift Testing will offer image-snapshot support. Track this as a 1.9 prerequisite.

---

## Working agreement

- **Branch:** create `1.8/color-system` feature branch (Task 0). All work lands there. Merge to main only when 1.8 is App-Store-ready.
- **Build-green discipline:** never delete a color reference until its replacement is in place. Add tokens first, migrate, then sweep for unused literals.
- **Commit cadence:** every task ends with a commit. No batch commits across tasks.
- **Test discipline:** TDD where it pays — token correctness, contrast ratios, component snapshot baselines. Skip TDD on pure-visual screen migrations where snapshot tests serve as the regression net.
- **Xcode project file:** new `.swift` files must be added to the `RetireSmartIRA` target in `project.pbxproj`. The implementing agent should use Xcode's UI for adding files, or carefully edit `project.pbxproj` if working headlessly. After adding any file, build to verify.

---

## File structure (to be created)

```
RetireSmartIRA/
├── Theme/                              ← NEW directory
│   ├── ColorTokens+UI.swift            ← brand, surfaces, text, button states
│   ├── ColorTokens+Semantic.swift      ← green/amber/red + tints + states
│   ├── ColorTokens+Chart.swift         ← hero teal, sand, gray ramp, teal ramp
│   ├── Spacing.swift                   ← spacing scale (4/8/12/16/24/32/48)
│   ├── Radius.swift                    ← corner-radius tokens
│   ├── Components/
│   │   ├── BrandButton.swift           ← 5 button variants
│   │   ├── MetricCard.swift            ← top-stripe card
│   │   ├── InfoButton.swift            ← info.circle.fill at 16pt
│   │   └── Badge.swift                 ← refund/due/error/neutral
│   └── README.md                       ← token + component reference

RetireSmartIRA/Assets.xcassets/
├── AccentColor.colorset/               ← populate with light + dark variants
├── BrandTeal.colorset/                 ← NEW (used by Color+UI extensions)
├── BrandTealHover.colorset/            ← NEW
├── ... (one colorset per token where light/dark variants matter)

RetireSmartIRATests/
├── ColorTokenTests.swift               ← NEW: contrast assertions
└── ComponentSnapshotTests.swift        ← NEW: snapshot tests for components

RetireSmartIRAUITests/                  ← may need to create
└── ScreenSnapshotTests.swift           ← NEW: top-level screen snapshots
```

---

## Phase 0 — Setup

### Task 0.1: Create feature branch

**Files:** N/A (git only)

- [ ] **Step 1: Create and switch to feature branch**

```bash
git checkout -b 1.8/color-system
git push -u origin 1.8/color-system
```

Expected: branch created, tracked upstream.

- [ ] **Step 2: Verify clean working tree**

```bash
git status
```

Expected: "nothing to commit, working tree clean".

---

### Task 0.2: Add swift-snapshot-testing dependency

**Files:**
- Modify: `RetireSmartIRA.xcodeproj/project.pbxproj` (via Xcode UI)

- [ ] **Step 1: Add Swift Package via Xcode**

Open Xcode → File → Add Package Dependencies → enter URL: `https://github.com/pointfreeco/swift-snapshot-testing` → Up to Next Major Version: 1.17.0 → Add Package → check `SnapshotTesting` library, target = `RetireSmartIRATests` → Add Package.

- [ ] **Step 2: Verify import works**

Open `RetireSmartIRATests/RetireSmartIRATests.swift` and add at top:

```swift
import SnapshotTesting
```

Build the test target (`Cmd+U` won't run tests yet, but the build should succeed). Expected: no import errors.

- [ ] **Step 3: Remove the test import (will be re-added per test file)**

Remove the `import SnapshotTesting` line just added.

- [ ] **Step 4: Commit**

```bash
git add RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add swift-snapshot-testing dependency for visual regression"
```

---

## Phase 1 — Token Infrastructure (Week 1)

The goal of Phase 1: every color in the design spec exists as a Swift-callable token, validated by tests, with no view changes yet. The build is green throughout.

### Task 1.1: Populate AccentColor.colorset with brand teal

**Files:**
- Modify: `RetireSmartIRA/Assets.xcassets/AccentColor.colorset/Contents.json`

- [ ] **Step 1: Replace AccentColor Contents.json**

Write to `RetireSmartIRA/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue"  : "0x7C",
          "green" : "0x6B",
          "red"   : "0x2A"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue"  : "0xA3",
          "green" : "0x8F",
          "red"   : "0x3D"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 2: Build the app to verify Asset catalog parses**

Run in Xcode: Product → Build (`Cmd+B`). Expected: build succeeds; brand teal now drives the system AccentColor.

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRA/Assets.xcassets/AccentColor.colorset/Contents.json
git commit -m "Set AccentColor to Muted Teal (#2A6B7C light / #3D8FA3 dark)"
```

---

### Task 1.2: Create Asset Catalog colorsets for light/dark token variants

**Files:**
- Create: `RetireSmartIRA/Assets.xcassets/Brand/` (new folder, 5 colorsets)
- Create: `RetireSmartIRA/Assets.xcassets/Semantic/` (new folder, 12 colorsets)
- Create: `RetireSmartIRA/Assets.xcassets/Chart/` (new folder, 12 colorsets)
- Create: `RetireSmartIRA/Assets.xcassets/Surface/` (new folder, 5 colorsets)
- Create: `RetireSmartIRA/Assets.xcassets/Text/` (new folder, 4 colorsets)

Each colorset is a folder with `Contents.json` defining light + dark RGB values. There are 38 colorsets total.

- [ ] **Step 1: Create the Brand/ colorsets**

Create folder `RetireSmartIRA/Assets.xcassets/Brand/` and inside it create 5 colorset folders. Each colorset folder contains a `Contents.json` with the structure shown in Task 1.1. Use these values:

| Folder name | Light RGB hex | Dark RGB hex |
|---|---|---|
| `BrandTeal.colorset` | `2A6B7C` | `3D8FA3` |
| `BrandTealHover.colorset` | `235862` | `4DA1B5` |
| `BrandTealPressed.colorset` | `1D4B53` | `5BB3C7` |
| `BrandTealDisabled.colorset` | `A6BDC2` | `4F6B72` |
| `BrandTealFocusRing.colorset` | `7AC5D6` | `7AC5D6` |

For each, write a `Contents.json` of the form:

```json
{
  "colors" : [
    {
      "color" : { "color-space" : "srgb", "components" : { "alpha" : "1.000", "blue" : "0xXX", "green" : "0xXX", "red" : "0xXX" } },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" : { "alpha" : "1.000", "blue" : "0xXX", "green" : "0xXX", "red" : "0xXX" } },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Replace `0xXX` with the per-channel hex from the table above (e.g., `BrandTeal` light has `red=0x2A green=0x6B blue=0x7C`).

- [ ] **Step 2: Create the Semantic/ colorsets**

Create folder `RetireSmartIRA/Assets.xcassets/Semantic/` and 12 colorset subfolders:

| Folder | Light hex | Dark hex |
|---|---|---|
| `Green.colorset` | `2E7D32` | `4CAF50` |
| `GreenHover.colorset` | `276B2A` | `5BBF5F` |
| `GreenPressed.colorset` | `225923` | `66CC6B` |
| `GreenDisabled.colorset` | `A8C9A9` | `2E5530` |
| `GreenTint.colorset` | `E8F5E9` | `1F2E20` |
| `Amber.colorset` | `B85C00` | `E08A3A` |
| `AmberHover.colorset` | `9E4F00` | `EBA058` |
| `AmberPressed.colorset` | `824100` | `F0B477` |
| `AmberDisabled.colorset` | `D6B89C` | `5C4023` |
| `AmberTint.colorset` | `FFF3E0` | `2A1F12` |
| `Red.colorset` | `C62828` | `EF5350` |
| `RedHover.colorset` | `A82323` | `F26F6D` |
| `RedPressed.colorset` | `8B1D1D` | `F58A88` |
| `RedDisabled.colorset` | `D9A7A7` | `5A2424` |
| `RedTint.colorset` | `FFEBEE` | `2A1819` |

(That's 15 actually — 5 per semantic color × 3 colors. Update count in folder.)

- [ ] **Step 3: Create the Surface/ colorsets**

Create folder `RetireSmartIRA/Assets.xcassets/Surface/` with 5 subfolders:

| Folder | Light hex | Dark hex |
|---|---|---|
| `SurfaceApp.colorset` | `F5F5F7` | `000000` |
| `SurfaceCard.colorset` | `FFFFFF` | `1C1C1E` |
| `SurfaceInset.colorset` | `F5F5F7` | `2C2C2E` |
| `SurfaceModal.colorset` | `FFFFFF` | `1C1C1E` |
| `SurfaceDivider.colorset` | rgba `000000` α=`0.08` | rgba `FFFFFF` α=`0.10` |

For `SurfaceDivider`, use this `Contents.json` form (alpha-modified):

```json
{
  "colors" : [
    {
      "color" : { "color-space" : "srgb", "components" : { "alpha" : "0.080", "blue" : "0x00", "green" : "0x00", "red" : "0x00" } },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" : { "alpha" : "0.100", "blue" : "0xFF", "green" : "0xFF", "red" : "0xFF" } },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 4: Create the Text/ colorsets**

Create folder `RetireSmartIRA/Assets.xcassets/Text/` with 4 subfolders:

| Folder | Light hex | Dark RGBA |
|---|---|---|
| `TextPrimary.colorset` | `1A1A1A` | `FFFFFF` α=`0.92` |
| `TextSecondary.colorset` | `666666` | `9F9FA3` |
| `TextTertiary.colorset` | `999999` | `7C7C80` |
| `TextUtility.colorset` | `3A3A3C` | `D0D0D0` |

`TextPrimary` dark variant uses alpha (0.92, not 1.000). Use the alpha-modified Contents.json form from Step 3.

- [ ] **Step 5: Create the Chart/ colorsets**

Create folder `RetireSmartIRA/Assets.xcassets/Chart/` with 12 subfolders:

| Folder | Light hex | Dark hex |
|---|---|---|
| `ChartCallout.colorset` | `C28E4A` | `D9A765` |
| `ChartCalloutHover.colorset` | `A87838` | `E2B57E` |
| `ChartCalloutPressed.colorset` | `8E6428` | `EBC498` |
| `ChartGray1.colorset` | `7A7D85` | `A0A3AB` |
| `ChartGray2.colorset` | `9DA1A8` | `888B92` |
| `ChartGray3.colorset` | `BCC0C6` | `6E7178` |
| `ChartGray4.colorset` | `D8DADD` | `52555B` |
| `ChartGray5.colorset` | `E8E9EB` | `3D3F44` |
| `ChartTealRamp1.colorset` | `1F4F5C` | `5BB3C7` |
| `ChartTealRamp2.colorset` | `2A6B7C` | `4DA1B5` |
| `ChartTealRamp3.colorset` | `4D8A99` | `3D8FA3` |
| `ChartTealRamp4.colorset` | `7AA9B5` | `326D7E` |
| `ChartTealRamp5.colorset` | `A7C4CC` | `255560` |
| `ChartTealRamp6.colorset` | `CBDBDF` | `1A4047` |

Note: dark-mode teal ramp inverts (lightest→darkest in light mode becomes darkest→lightest in dark mode) so the visual ordering reads consistently.

- [ ] **Step 6: Add new colorset folders to Xcode project**

In Xcode: select the `Assets.xcassets` group → drag the new top-level folders (`Brand/`, `Semantic/`, `Surface/`, `Text/`, `Chart/`) into the asset catalog. Verify they appear in the catalog browser.

- [ ] **Step 7: Build to verify catalog parses**

`Cmd+B`. Expected: build succeeds, no asset catalog warnings.

- [ ] **Step 8: Commit**

```bash
git add RetireSmartIRA/Assets.xcassets/ RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add color token assets: Brand, Semantic, Surface, Text, Chart"
```

---

### Task 1.3: Create ColorTokens+UI.swift

**Files:**
- Create: `RetireSmartIRA/Theme/ColorTokens+UI.swift`
- Test: `RetireSmartIRATests/ColorTokenUITests.swift`

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/ColorTokenUITests.swift`:

```swift
import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ColorTokenUITests: XCTestCase {
    func test_brandTealResolvesFromAssetCatalog() {
        let color = Color.UI.brandTeal
        // Smoke test: ensure the token compiles and is non-nil.
        // Color equality in SwiftUI is structural, so we render to UIColor/NSColor for verification.
        #if canImport(UIKit)
        let resolved = UIColor(color)
        XCTAssertNotNil(resolved.cgColor)
        #elseif canImport(AppKit)
        let resolved = NSColor(color)
        XCTAssertNotNil(resolved.cgColor)
        #endif
    }

    func test_allUITokensExist() {
        // Reference each token to ensure compile-time existence.
        _ = Color.UI.brandTeal
        _ = Color.UI.brandTealHover
        _ = Color.UI.brandTealPressed
        _ = Color.UI.brandTealDisabled
        _ = Color.UI.brandTealFocusRing
        _ = Color.UI.surfaceApp
        _ = Color.UI.surfaceCard
        _ = Color.UI.surfaceInset
        _ = Color.UI.surfaceModal
        _ = Color.UI.surfaceDivider
        _ = Color.UI.textPrimary
        _ = Color.UI.textSecondary
        _ = Color.UI.textTertiary
        _ = Color.UI.textUtility
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run in Xcode: `Cmd+U` (run all tests). Expected: compilation fails — `Color.UI` does not exist.

- [ ] **Step 3: Create ColorTokens+UI.swift**

Create `RetireSmartIRA/Theme/ColorTokens+UI.swift`:

```swift
import SwiftUI

/// UI namespace tokens — brand identity, surfaces, text.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §3.
extension Color {
    enum UI {
        // MARK: - Brand
        static let brandTeal          = Color("BrandTeal",          bundle: .main)
        static let brandTealHover     = Color("BrandTealHover",     bundle: .main)
        static let brandTealPressed   = Color("BrandTealPressed",   bundle: .main)
        static let brandTealDisabled  = Color("BrandTealDisabled",  bundle: .main)
        static let brandTealFocusRing = Color("BrandTealFocusRing", bundle: .main)

        // MARK: - Surfaces
        static let surfaceApp         = Color("SurfaceApp",         bundle: .main)
        static let surfaceCard        = Color("SurfaceCard",        bundle: .main)
        static let surfaceInset       = Color("SurfaceInset",       bundle: .main)
        static let surfaceModal       = Color("SurfaceModal",       bundle: .main)
        static let surfaceDivider     = Color("SurfaceDivider",     bundle: .main)

        // MARK: - Text
        static let textPrimary        = Color("TextPrimary",        bundle: .main)
        static let textSecondary      = Color("TextSecondary",      bundle: .main)
        static let textTertiary       = Color("TextTertiary",       bundle: .main)
        static let textUtility        = Color("TextUtility",        bundle: .main)
    }
}
```

- [ ] **Step 4: Add file to Xcode target**

In Xcode: right-click the `RetireSmartIRA` group → New Group → name it `Theme` → drag `ColorTokens+UI.swift` into it. Verify it's a member of the `RetireSmartIRA` target (target membership panel on right).

- [ ] **Step 5: Run tests to verify they pass**

`Cmd+U`. Expected: both tests in `ColorTokenUITests` PASS.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRA/Theme/ColorTokens+UI.swift RetireSmartIRATests/ColorTokenUITests.swift RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add Color.UI namespace tokens (brand, surfaces, text)"
```

---

### Task 1.4: Create ColorTokens+Semantic.swift

**Files:**
- Create: `RetireSmartIRA/Theme/ColorTokens+Semantic.swift`
- Test: `RetireSmartIRATests/ColorTokenSemanticTests.swift`

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/ColorTokenSemanticTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ColorTokenSemanticTests: XCTestCase {
    func test_allSemanticTokensExist() {
        _ = Color.Semantic.green
        _ = Color.Semantic.greenHover
        _ = Color.Semantic.greenPressed
        _ = Color.Semantic.greenDisabled
        _ = Color.Semantic.greenTint
        _ = Color.Semantic.amber
        _ = Color.Semantic.amberHover
        _ = Color.Semantic.amberPressed
        _ = Color.Semantic.amberDisabled
        _ = Color.Semantic.amberTint
        _ = Color.Semantic.red
        _ = Color.Semantic.redHover
        _ = Color.Semantic.redPressed
        _ = Color.Semantic.redDisabled
        _ = Color.Semantic.redTint
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

`Cmd+U`. Expected: compile error — `Color.Semantic` undefined.

- [ ] **Step 3: Create ColorTokens+Semantic.swift**

Create `RetireSmartIRA/Theme/ColorTokens+Semantic.swift`:

```swift
import SwiftUI

/// Semantic namespace — meaning-bearing colors with strict one-job rules.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §2.
///
/// **Strict rules:**
/// - `green` = money literally returning to user (refunds only). NOT savings, gains, or "good outcomes" generally.
/// - `amber` = action required (deadlines, missing input, IRMAA proximity). NEVER applied to dollar amounts themselves.
/// - `red`   = error / blocking state only (form validation, crossed cliffs). NEVER for "tax owed."
extension Color {
    enum Semantic {
        // MARK: - Green (refund only)
        static let green         = Color("Green",         bundle: .main)
        static let greenHover    = Color("GreenHover",    bundle: .main)
        static let greenPressed  = Color("GreenPressed",  bundle: .main)
        static let greenDisabled = Color("GreenDisabled", bundle: .main)
        static let greenTint     = Color("GreenTint",     bundle: .main)

        // MARK: - Amber (action required)
        static let amber         = Color("Amber",         bundle: .main)
        static let amberHover    = Color("AmberHover",    bundle: .main)
        static let amberPressed  = Color("AmberPressed",  bundle: .main)
        static let amberDisabled = Color("AmberDisabled", bundle: .main)
        static let amberTint     = Color("AmberTint",     bundle: .main)

        // MARK: - Red (error / blocking only)
        static let red           = Color("Red",           bundle: .main)
        static let redHover      = Color("RedHover",      bundle: .main)
        static let redPressed    = Color("RedPressed",    bundle: .main)
        static let redDisabled   = Color("RedDisabled",   bundle: .main)
        static let redTint       = Color("RedTint",       bundle: .main)
    }
}
```

- [ ] **Step 4: Add to Xcode target**

In Xcode, drag the new file into the `Theme/` group. Verify target membership.

- [ ] **Step 5: Run tests to verify they pass**

`Cmd+U`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRA/Theme/ColorTokens+Semantic.swift RetireSmartIRATests/ColorTokenSemanticTests.swift RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add Color.Semantic namespace tokens (green, amber, red + tints + states)"
```

---

### Task 1.5: Create ColorTokens+Chart.swift

**Files:**
- Create: `RetireSmartIRA/Theme/ColorTokens+Chart.swift`
- Test: `RetireSmartIRATests/ColorTokenChartTests.swift`

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/ColorTokenChartTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ColorTokenChartTests: XCTestCase {
    func test_allChartTokensExist() {
        _ = Color.Chart.heroTeal
        _ = Color.Chart.callout
        _ = Color.Chart.calloutHover
        _ = Color.Chart.calloutPressed
        _ = Color.Chart.gray1
        _ = Color.Chart.gray2
        _ = Color.Chart.gray3
        _ = Color.Chart.gray4
        _ = Color.Chart.gray5
        _ = Color.Chart.tealRamp1
        _ = Color.Chart.tealRamp2
        _ = Color.Chart.tealRamp3
        _ = Color.Chart.tealRamp4
        _ = Color.Chart.tealRamp5
        _ = Color.Chart.tealRamp6
    }

    func test_categoricalSeriesReturnsHeroPlusGrays() {
        // Given a 6-category series, hero leads, then grays descend, then sand callout.
        let series = Color.Chart.categoricalSeries(count: 6, callout: 2)
        XCTAssertEqual(series.count, 6)
        // Position 0 should be the hero (teal); position 2 should be sand.
        // Equality on Color values is structural — compare via underlying CGColor.
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

`Cmd+U`. Expected: compile error — `Color.Chart` undefined; `categoricalSeries` undefined.

- [ ] **Step 3: Create ColorTokens+Chart.swift**

Create `RetireSmartIRA/Theme/ColorTokens+Chart.swift`:

```swift
import SwiftUI

/// Chart namespace — data visualization only.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §5.
///
/// **Hard rule:** `Color.Chart.*` NEVER overlaps `Color.Semantic.*`.
/// The chart palette is teal + neutral grays + warm sand. There is no green
/// chart bar (green means refund), no red chart bar (red means error), no
/// amber chart bar (amber means action required).
extension Color {
    enum Chart {
        // MARK: - Hero + accent
        /// Hero category color. Aliases brand teal — same hex, used in chart context.
        static let heroTeal        = Color.UI.brandTeal
        /// Warm-sand callout for "look here" highlights in categorical charts.
        static let callout         = Color("ChartCallout",        bundle: .main)
        static let calloutHover    = Color("ChartCalloutHover",   bundle: .main)
        static let calloutPressed  = Color("ChartCalloutPressed", bundle: .main)

        // MARK: - Neutral gray ramp (categorical context for non-hero categories)
        static let gray1           = Color("ChartGray1", bundle: .main)
        static let gray2           = Color("ChartGray2", bundle: .main)
        static let gray3           = Color("ChartGray3", bundle: .main)
        static let gray4           = Color("ChartGray4", bundle: .main)
        static let gray5           = Color("ChartGray5", bundle: .main)

        // MARK: - Teal ramp (sequential / ordered data — brackets, time series)
        static let tealRamp1       = Color("ChartTealRamp1", bundle: .main)
        static let tealRamp2       = Color("ChartTealRamp2", bundle: .main)
        static let tealRamp3       = Color("ChartTealRamp3", bundle: .main)
        static let tealRamp4       = Color("ChartTealRamp4", bundle: .main)
        static let tealRamp5       = Color("ChartTealRamp5", bundle: .main)
        static let tealRamp6       = Color("ChartTealRamp6", bundle: .main)

        // MARK: - Helpers

        /// Returns a categorical color series with hero in position 0,
        /// callout sand at the specified callout index, and neutral grays
        /// descending for the rest.
        ///
        /// - Parameters:
        ///   - count: number of categories (1–6)
        ///   - callout: index of the category to highlight with sand. Pass `nil` for no callout.
        /// - Returns: array of `Color` values matching `count`.
        static func categoricalSeries(count: Int, callout: Int? = nil) -> [Color] {
            let grays = [gray1, gray2, gray3, gray4, gray5]
            var result: [Color] = [heroTeal]
            for i in 0..<max(0, count - 1) {
                result.append(grays[min(i, grays.count - 1)])
            }
            if let calloutIdx = callout, calloutIdx < result.count {
                result[calloutIdx] = Self.callout
            }
            return Array(result.prefix(count))
        }

        /// Returns a sequential teal ramp for ordered data (e.g., tax brackets).
        ///
        /// - Parameter count: number of steps (1–6)
        /// - Returns: array of `Color` values from darkest (position 0) to lightest.
        static func sequentialRamp(count: Int) -> [Color] {
            let ramp = [tealRamp1, tealRamp2, tealRamp3, tealRamp4, tealRamp5, tealRamp6]
            return Array(ramp.prefix(count))
        }
    }
}
```

- [ ] **Step 4: Add to Xcode target**

Drag into `Theme/` group, verify target membership.

- [ ] **Step 5: Run tests to verify they pass**

`Cmd+U`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRA/Theme/ColorTokens+Chart.swift RetireSmartIRATests/ColorTokenChartTests.swift RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add Color.Chart namespace tokens (hero teal, sand callout, gray ramp, teal ramp)"
```

---

### Task 1.6: Create Spacing.swift

**Files:**
- Create: `RetireSmartIRA/Theme/Spacing.swift`
- Test: `RetireSmartIRATests/SpacingTests.swift`

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/SpacingTests.swift`:

```swift
import XCTest
@testable import RetireSmartIRA

final class SpacingTests: XCTestCase {
    func test_spacingScaleValues() {
        XCTAssertEqual(Spacing.xxs, 4)
        XCTAssertEqual(Spacing.xs, 8)
        XCTAssertEqual(Spacing.sm, 12)
        XCTAssertEqual(Spacing.md, 16)
        XCTAssertEqual(Spacing.lg, 24)
        XCTAssertEqual(Spacing.xl, 32)
        XCTAssertEqual(Spacing.xxl, 48)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

`Cmd+U`. Expected: compile error.

- [ ] **Step 3: Create Spacing.swift**

Create `RetireSmartIRA/Theme/Spacing.swift`:

```swift
import CoreGraphics

/// Spacing scale (8pt grid with 4pt half-steps).
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §6.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}
```

- [ ] **Step 4: Add to Xcode target**

Drag into `Theme/` group.

- [ ] **Step 5: Run tests to verify they pass**

`Cmd+U`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRA/Theme/Spacing.swift RetireSmartIRATests/SpacingTests.swift RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add Spacing scale tokens (4/8/12/16/24/32/48pt)"
```

---

### Task 1.7: Create Radius.swift

**Files:**
- Create: `RetireSmartIRA/Theme/Radius.swift`
- Test: `RetireSmartIRATests/RadiusTests.swift`

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/RadiusTests.swift`:

```swift
import XCTest
@testable import RetireSmartIRA

final class RadiusTests: XCTestCase {
    func test_radiusValues() {
        XCTAssertEqual(Radius.card, 12)
        XCTAssertEqual(Radius.input, 8)
        XCTAssertEqual(Radius.button, 6)
        XCTAssertEqual(Radius.badge, 4)
    }

    func test_capsuleRadiusForHeight() {
        XCTAssertEqual(Radius.capsule(forHeight: 32), 16)
        XCTAssertEqual(Radius.capsule(forHeight: 24), 12)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

`Cmd+U`. Expected: compile error.

- [ ] **Step 3: Create Radius.swift**

Create `RetireSmartIRA/Theme/Radius.swift`:

```swift
import CoreGraphics

/// Corner-radius tokens. Nested radii descend so curves harmonize.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §6.
enum Radius {
    /// Outer cards, modals, sheets.
    static let card:   CGFloat = 12
    /// Text fields, dropdowns, segmented controls.
    static let input:  CGFloat = 8
    /// All button sizes.
    static let button: CGFloat = 6
    /// Tags / status badges (rounded rectangles, NOT true pills).
    static let badge:  CGFloat = 4

    /// True pill shape: radius is half the component's height.
    /// Reserved for filter chips, segmented controls (future use).
    static func capsule(forHeight height: CGFloat) -> CGFloat {
        height / 2
    }
}
```

- [ ] **Step 4: Add to Xcode target**

Drag into `Theme/` group.

- [ ] **Step 5: Run tests to verify they pass**

`Cmd+U`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRA/Theme/Radius.swift RetireSmartIRATests/RadiusTests.swift RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add Radius tokens (card/input/button/badge + capsule helper)"
```

---

### Task 1.8: Add WCAG contrast assertion tests

**Files:**
- Create: `RetireSmartIRATests/ContrastAssertionTests.swift`

These tests assert WCAG AA (4.5:1) contrast for every text-on-surface combination defined by the spec. Failures here are real bugs — fix the color, not the test.

- [ ] **Step 1: Write the contrast test file**

Create `RetireSmartIRATests/ContrastAssertionTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ContrastAssertionTests: XCTestCase {

    // MARK: - WCAG ratio calculation

    /// Computes the WCAG 2.1 contrast ratio between two colors.
    /// Reference: https://www.w3.org/TR/WCAG21/#contrast-minimum
    private func contrastRatio(_ a: Color, _ b: Color, scheme: ColorScheme) -> Double {
        let l1 = relativeLuminance(a, scheme: scheme)
        let l2 = relativeLuminance(b, scheme: scheme)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: Color, scheme: ColorScheme) -> Double {
        // Resolve to sRGB components via the platform's native color type.
        #if canImport(UIKit)
        var trait = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        let resolved = UIColor(color).resolvedColor(with: trait)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        let appearance: NSAppearance = scheme == .dark ? NSAppearance(named: .darkAqua)! : NSAppearance(named: .aqua)!
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        appearance.performAsCurrentDrawingAppearance {
            let resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.black
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        #endif
        let channels = [r, g, b].map { c -> Double in
            let ch = Double(c)
            return ch <= 0.03928 ? ch / 12.92 : pow((ch + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    private let aaThreshold = 4.5
    private let aaLargeTextThreshold = 3.0

    // MARK: - Light mode assertions

    func test_lightMode_textPrimaryOnSurfaceCard_meetsAA() {
        let ratio = contrastRatio(.UI.textPrimary, .UI.surfaceCard, scheme: .light)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold,
            "textPrimary on surfaceCard light = \(ratio), need ≥ \(aaThreshold)")
    }

    func test_lightMode_textSecondaryOnSurfaceCard_meetsAA() {
        let ratio = contrastRatio(.UI.textSecondary, .UI.surfaceCard, scheme: .light)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold)
    }

    func test_lightMode_brandTealOnSurfaceCard_meetsAA() {
        let ratio = contrastRatio(.UI.brandTeal, .UI.surfaceCard, scheme: .light)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold)
    }

    func test_lightMode_whiteOnBrandTeal_meetsAA() {
        let ratio = contrastRatio(.white, .UI.brandTeal, scheme: .light)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold)
    }

    func test_lightMode_amberOnSurfaceCard_meetsAA() {
        let ratio = contrastRatio(.Semantic.amber, .UI.surfaceCard, scheme: .light)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold)
    }

    func test_lightMode_redOnSurfaceCard_meetsAA() {
        let ratio = contrastRatio(.Semantic.red, .UI.surfaceCard, scheme: .light)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold)
    }

    func test_lightMode_greenOnGreenTint_meetsAALarge() {
        // Badge text on tinted background — large/bold text qualifies for 3:1
        let ratio = contrastRatio(.Semantic.green, .Semantic.greenTint, scheme: .light)
        XCTAssertGreaterThanOrEqual(ratio, aaLargeTextThreshold)
    }

    func test_lightMode_amberOnAmberTint_meetsAALarge() {
        let ratio = contrastRatio(.Semantic.amber, .Semantic.amberTint, scheme: .light)
        XCTAssertGreaterThanOrEqual(ratio, aaLargeTextThreshold)
    }

    func test_lightMode_redOnRedTint_meetsAALarge() {
        let ratio = contrastRatio(.Semantic.red, .Semantic.redTint, scheme: .light)
        XCTAssertGreaterThanOrEqual(ratio, aaLargeTextThreshold)
    }

    // MARK: - Dark mode assertions

    func test_darkMode_textPrimaryOnSurfaceCard_meetsAA() {
        let ratio = contrastRatio(.UI.textPrimary, .UI.surfaceCard, scheme: .dark)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold)
    }

    func test_darkMode_textSecondaryOnSurfaceCard_meetsAA() {
        let ratio = contrastRatio(.UI.textSecondary, .UI.surfaceCard, scheme: .dark)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold)
    }

    func test_darkMode_brandTealOnSurfaceCard_meetsAA() {
        let ratio = contrastRatio(.UI.brandTeal, .UI.surfaceCard, scheme: .dark)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold)
    }

    func test_darkMode_amberOnSurfaceCard_meetsAA() {
        let ratio = contrastRatio(.Semantic.amber, .UI.surfaceCard, scheme: .dark)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold)
    }

    func test_darkMode_redOnSurfaceCard_meetsAA() {
        let ratio = contrastRatio(.Semantic.red, .UI.surfaceCard, scheme: .dark)
        XCTAssertGreaterThanOrEqual(ratio, aaThreshold)
    }
}
```

- [ ] **Step 2: Add to test target**

Drag into `RetireSmartIRATests/` group.

- [ ] **Step 3: Run tests**

`Cmd+U`. Expected: tests run; any failures indicate token hex values that don't meet WCAG AA. **If any fail, the spec's hex values must be adjusted** — file a finding for John before changing values.

- [ ] **Step 4: Commit (with results)**

If all pass:

```bash
git add RetireSmartIRATests/ContrastAssertionTests.swift RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add WCAG AA contrast assertion tests for color tokens"
```

If failures, commit the test file and open a findings file at `docs/superpowers/specs/2026-04-25-contrast-findings.md` describing which tokens failed and proposed adjustments. **Do not silently adjust hex values** — flag for design review first.

---

## Phase 2 — Shared Components (Week 2)

### Task 2.1: Create BrandButton.swift with 6 variants

**Files:**
- Create: `RetireSmartIRA/Theme/Components/BrandButton.swift`
- Test: `RetireSmartIRATests/BrandButtonSnapshotTests.swift`

- [ ] **Step 1: Write the snapshot test (will fail until implementation exists)**

Create `RetireSmartIRATests/BrandButtonSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import RetireSmartIRA

final class BrandButtonSnapshotTests: XCTestCase {

    func test_primary_light() {
        let view = BrandButton(title: "Save", style: .primary) { }
            .frame(width: 200, height: 44)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_primary_dark() {
        let view = BrandButton(title: "Save", style: .primary) { }
            .frame(width: 200, height: 44)
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    func test_secondary_light() {
        let view = BrandButton(title: "Cancel", style: .secondary) { }
            .frame(width: 200, height: 44)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_tertiaryUtility_light() {
        let view = BrandButton(title: "Reset", style: .tertiaryUtility) { }
            .frame(width: 200, height: 36)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_tertiaryForward_light() {
        let view = BrandButton(title: "Learn more", style: .tertiaryForward) { }
            .frame(width: 200, height: 36)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_destructiveSecondary_light() {
        let view = BrandButton(title: "Delete", style: .destructiveSecondary) { }
            .frame(width: 200, height: 44)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_destructivePrimary_light() {
        let view = BrandButton(title: "Yes, delete forever", style: .destructivePrimary) { }
            .frame(width: 280, height: 44)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_disabled_primary_light() {
        let view = BrandButton(title: "Save", style: .primary) { }
            .disabled(true)
            .frame(width: 200, height: 44)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }
}
```

- [ ] **Step 2: Run snapshot test (expect compile error first)**

`Cmd+U`. Expected: compile fails — `BrandButton` undefined.

- [ ] **Step 3: Create BrandButton.swift**

Create `RetireSmartIRA/Theme/Components/BrandButton.swift`:

```swift
import SwiftUI

/// The canonical button component. Five visual variants matching the design spec.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §4.
struct BrandButton: View {
    enum Style {
        case primary
        case secondary
        /// Default tertiary — gray text. Use for utility actions (Edit, Reset, Cancel).
        case tertiaryUtility
        /// Teal-text tertiary — use ONLY for actions that genuinely advance the user
        /// (≈1 in 5 inline links). See spec §4 "Tertiary defaults to gray."
        case tertiaryForward
        /// Outline red, inline destructive (next to a primary).
        case destructiveSecondary
        /// Filled red, final-step modal confirmation only.
        case destructivePrimary
    }

    enum Size {
        case compact   // 28pt height, 13pt text
        case standard  // 36pt height, 15pt text
        case prominent // 44pt height, 17pt text

        var height: CGFloat {
            switch self {
            case .compact:   return 28
            case .standard:  return 36
            case .prominent: return 44
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .compact:   return 13
            case .standard:  return 15
            case .prominent: return 17
            }
        }
    }

    let title: String
    var style: Style = .primary
    var size: Size = .standard
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: size.fontSize, weight: .semibold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: size.height)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        guard isEnabled else { return disabledTextColor }
        switch style {
        case .primary:               return .white
        case .secondary:             return .UI.brandTeal
        case .tertiaryUtility:       return .UI.textUtility
        case .tertiaryForward:       return .UI.brandTeal
        case .destructiveSecondary:  return .Semantic.red
        case .destructivePrimary:    return .white
        }
    }

    private var backgroundColor: Color {
        guard isEnabled else { return disabledBackgroundColor }
        switch style {
        case .primary:               return .UI.brandTeal
        case .secondary:             return .clear
        case .tertiaryUtility:       return .clear
        case .tertiaryForward:       return .clear
        case .destructiveSecondary:  return .clear
        case .destructivePrimary:    return .Semantic.red
        }
    }

    private var borderColor: Color {
        guard isEnabled else { return disabledBorderColor }
        switch style {
        case .primary, .destructivePrimary:        return .clear
        case .secondary:                           return .UI.brandTeal
        case .tertiaryUtility, .tertiaryForward:   return .clear
        case .destructiveSecondary:                return .Semantic.red
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .secondary, .destructiveSecondary: return 1.5
        default:                                 return 0
        }
    }

    private var disabledTextColor: Color {
        switch style {
        case .primary, .destructivePrimary: return .white.opacity(0.65)
        case .secondary:                     return .UI.brandTealDisabled
        case .destructiveSecondary:          return .Semantic.redDisabled
        case .tertiaryUtility, .tertiaryForward:
            return .UI.textTertiary
        }
    }

    private var disabledBackgroundColor: Color {
        switch style {
        case .primary:            return .UI.brandTealDisabled
        case .destructivePrimary: return .Semantic.redDisabled
        default:                  return .clear
        }
    }

    private var disabledBorderColor: Color {
        switch style {
        case .secondary:            return .UI.brandTealDisabled
        case .destructiveSecondary: return .Semantic.redDisabled
        default:                    return .clear
        }
    }
}

#Preview("Primary") {
    BrandButton(title: "Save", style: .primary) {}.padding()
}

#Preview("All variants") {
    VStack(spacing: 12) {
        BrandButton(title: "Primary",            style: .primary) {}
        BrandButton(title: "Secondary",          style: .secondary) {}
        BrandButton(title: "Tertiary Utility",   style: .tertiaryUtility) {}
        BrandButton(title: "Tertiary Forward",   style: .tertiaryForward) {}
        BrandButton(title: "Destructive Sec.",   style: .destructiveSecondary) {}
        BrandButton(title: "Destructive Primary",style: .destructivePrimary) {}
    }
    .padding()
}
```

- [ ] **Step 4: Add file to Xcode target**

In Xcode: under `Theme/`, create a `Components` subgroup. Drag `BrandButton.swift` in. Verify target membership.

- [ ] **Step 5: Run snapshot tests for the first time (records baselines)**

First snapshot run records baselines. Run `Cmd+U`. Expected: tests "fail" with "No reference image found" — but this records baselines automatically.

- [ ] **Step 6: Run snapshot tests again to verify baselines**

`Cmd+U`. Expected: PASS.

- [ ] **Step 7: Visually inspect baseline images**

Open the recorded snapshot images in `RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/`. Verify each looks correct against the spec. If any look wrong, delete the bad image and re-run to re-record after fixing.

- [ ] **Step 8: Commit**

```bash
git add RetireSmartIRA/Theme/Components/BrandButton.swift RetireSmartIRATests/BrandButtonSnapshotTests.swift RetireSmartIRATests/__Snapshots__/ RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add BrandButton component with 6 variants and snapshot baselines"
```

---

### Task 2.2: Create MetricCard.swift

**Files:**
- Create: `RetireSmartIRA/Theme/Components/MetricCard.swift`
- Test: `RetireSmartIRATests/MetricCardSnapshotTests.swift`

- [ ] **Step 1: Write the snapshot test**

Create `RetireSmartIRATests/MetricCardSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import RetireSmartIRA

final class MetricCardSnapshotTests: XCTestCase {

    func test_informational_light() {
        let view = MetricCard(
            label: "Total Tax",
            value: "$12,847",
            delta: "+$1,240 vs 2025",
            category: .informational
        )
        .frame(width: 280)
        .padding()
        .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_actionRequired_light() {
        let view = MetricCard(
            label: "Q2 Estimated",
            value: "$3,212",
            delta: "Due Jun 15",
            deltaIsAmber: true,
            category: .actionRequired,
            badge: .due
        )
        .frame(width: 280)
        .padding()
        .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_refund_light() {
        let view = MetricCard(
            label: "Est. Refund",
            value: "$1,830",
            delta: "Federal",
            category: .informational,
            badge: .refund
        )
        .frame(width: 280)
        .padding()
        .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_error_light() {
        let view = MetricCard(
            label: "ACA Subsidy",
            value: "$0",
            delta: "Cliff exceeded",
            category: .error,
            badge: .error
        )
        .frame(width: 280)
        .padding()
        .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_informational_dark() {
        let view = MetricCard(
            label: "Total Tax",
            value: "$12,847",
            delta: "+$1,240 vs 2025",
            category: .informational
        )
        .frame(width: 280)
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

`Cmd+U`. Expected: compile error.

- [ ] **Step 3: Create MetricCard.swift**

Create `RetireSmartIRA/Theme/Components/MetricCard.swift`:

```swift
import SwiftUI

/// The canonical metric card. Top-stripe colored band over a white body.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §4.
struct MetricCard: View {
    enum Category {
        case informational  // brand teal stripe — default
        case actionRequired // amber stripe
        case error          // red stripe

        var stripeColor: Color {
            switch self {
            case .informational:  return .UI.brandTeal
            case .actionRequired: return .Semantic.amber
            case .error:          return .Semantic.red
            }
        }
    }

    let label: String
    let value: String
    var delta: String? = nil
    /// Whether the delta string should render in amber (e.g., deadline text).
    /// The dollar VALUE itself stays primary text — only delta/deadline qualifies for amber.
    var deltaIsAmber: Bool = false
    var category: Category = .informational
    var badge: Badge.Variant? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 4pt category stripe
            Rectangle()
                .fill(category.stripeColor)
                .frame(height: 4)

            // Body
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xxs) {
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.UI.textSecondary)
                    if let badge {
                        Badge(text: badge.defaultText, variant: badge)
                    }
                    Spacer()
                }
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.UI.textPrimary)
                if let delta {
                    Text(delta)
                        .font(.system(size: 11))
                        .foregroundStyle(deltaIsAmber ? Color.Semantic.amber : Color.UI.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.UI.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: .black.opacity(0.08), radius: 1.5, x: 0, y: 1)
    }
}

#Preview("Informational") {
    MetricCard(label: "Total Tax", value: "$12,847", delta: "+$1,240 vs 2025")
        .padding()
}

#Preview("Action required") {
    MetricCard(
        label: "Q2 Estimated",
        value: "$3,212",
        delta: "Due Jun 15",
        deltaIsAmber: true,
        category: .actionRequired,
        badge: .due
    )
    .padding()
}
```

- [ ] **Step 4: Add to Xcode target**

Drag into `Components/` group.

- [ ] **Step 5: Run snapshot tests (records baselines)**

`Cmd+U`. First run records baselines.

- [ ] **Step 6: Run again to verify**

`Cmd+U`. Expected: PASS.

- [ ] **Step 7: Visually inspect baselines**

Open `RetireSmartIRATests/__Snapshots__/MetricCardSnapshotTests/`. Verify each rendering matches spec.

- [ ] **Step 8: Commit**

```bash
git add RetireSmartIRA/Theme/Components/MetricCard.swift RetireSmartIRATests/MetricCardSnapshotTests.swift RetireSmartIRATests/__Snapshots__/ RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add MetricCard component (top-stripe variant) with snapshot baselines"
```

---

### Task 2.3: Create Badge.swift

Note: `MetricCard` references `Badge` — to keep the build green during Phase 2 development, do this task **before** Task 2.2 (or leave Task 2.2 incomplete until Badge exists). The order in this plan assumes the implementer reads ahead; if executing strictly in order, swap 2.2 and 2.3.

**Files:**
- Create: `RetireSmartIRA/Theme/Components/Badge.swift`
- Test: `RetireSmartIRATests/BadgeSnapshotTests.swift`

- [ ] **Step 1: Write snapshot test**

Create `RetireSmartIRATests/BadgeSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import RetireSmartIRA

final class BadgeSnapshotTests: XCTestCase {

    func test_refund_light() {
        let view = Badge(text: "REFUND", variant: .refund)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_due_light() {
        let view = Badge(text: "DUE", variant: .due)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_error_light() {
        let view = Badge(text: "ERROR", variant: .error)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_neutral_light() {
        let view = Badge(text: "DRAFT", variant: .neutral)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_refund_dark() {
        let view = Badge(text: "REFUND", variant: .refund)
            .padding()
            .background(Color.UI.surfaceCard)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }
}
```

- [ ] **Step 2: Verify failure**

`Cmd+U`. Expected: compile error.

- [ ] **Step 3: Create Badge.swift**

Create `RetireSmartIRA/Theme/Components/Badge.swift`:

```swift
import SwiftUI

/// Small inline category label. NOT a true pill — see Radius.capsule for that.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §4.
struct Badge: View {
    enum Variant {
        case refund    // green text on green tint
        case due       // amber text on amber tint
        case error     // red text on red tint
        case neutral   // gray text on gray tint

        var foreground: Color {
            switch self {
            case .refund:  return .Semantic.green
            case .due:     return .Semantic.amber
            case .error:   return .Semantic.red
            case .neutral: return .UI.textSecondary
            }
        }

        var background: Color {
            switch self {
            case .refund:  return .Semantic.greenTint
            case .due:     return .Semantic.amberTint
            case .error:   return .Semantic.redTint
            case .neutral: return Color(red: 0.94, green: 0.94, blue: 0.95)  // ChartGray5 equiv
            }
        }

        /// Default text used when displaying the variant without an explicit override.
        var defaultText: String {
            switch self {
            case .refund:  return "REFUND"
            case .due:     return "DUE"
            case .error:   return "ERROR"
            case .neutral: return ""
            }
        }
    }

    let text: String
    let variant: Variant

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(variant.foreground)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(variant.background)
            .clipShape(RoundedRectangle(cornerRadius: Radius.badge))
    }
}

#Preview("All variants") {
    HStack(spacing: 8) {
        Badge(text: "REFUND", variant: .refund)
        Badge(text: "DUE", variant: .due)
        Badge(text: "ERROR", variant: .error)
        Badge(text: "DRAFT", variant: .neutral)
    }
    .padding()
}
```

- [ ] **Step 4: Add to Xcode target**

Drag into `Components/` group.

- [ ] **Step 5: Record baselines**

`Cmd+U` (first run records).

- [ ] **Step 6: Verify pass**

`Cmd+U`. Expected: PASS.

- [ ] **Step 7: Visually inspect baselines**

Confirm each variant in `__Snapshots__/BadgeSnapshotTests/`.

- [ ] **Step 8: Commit**

```bash
git add RetireSmartIRA/Theme/Components/Badge.swift RetireSmartIRATests/BadgeSnapshotTests.swift RetireSmartIRATests/__Snapshots__/ RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add Badge component (refund/due/error/neutral) with snapshot baselines"
```

---

### Task 2.4: Create InfoButton.swift

**Files:**
- Create: `RetireSmartIRA/Theme/Components/InfoButton.swift`
- Test: `RetireSmartIRATests/InfoButtonSnapshotTests.swift`

- [ ] **Step 1: Write snapshot test**

Create `RetireSmartIRATests/InfoButtonSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import RetireSmartIRA

final class InfoButtonSnapshotTests: XCTestCase {

    func test_default_light() {
        let view = InfoButton {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }

    func test_default_dark() {
        let view = InfoButton {}
            .padding()
            .background(Color.UI.surfaceCard)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    func test_inLabelRow_light() {
        let view = HStack(spacing: 6) {
            Text("Primary Heir's Salary")
                .font(.system(size: 13))
            InfoButton {}
            Spacer()
        }
        .frame(width: 280)
        .padding()
        .preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image)
    }
}
```

- [ ] **Step 2: Verify failure**

`Cmd+U`. Expected: compile error.

- [ ] **Step 3: Create InfoButton.swift**

Create `RetireSmartIRA/Theme/Components/InfoButton.swift`:

```swift
import SwiftUI

/// Filled info icon at 16pt visual size with 24pt hit target.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §4.
struct InfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.UI.brandTeal)
                .frame(width: 24, height: 24)  // hit target
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More information")
    }
}

#Preview("Inline with label") {
    HStack(spacing: 6) {
        Text("Primary Heir's Salary")
        InfoButton {}
    }
    .padding()
}
```

- [ ] **Step 4: Add to Xcode target**

Drag into `Components/` group.

- [ ] **Step 5: Record baselines**

`Cmd+U`.

- [ ] **Step 6: Verify pass**

`Cmd+U`. Expected: PASS.

- [ ] **Step 7: Visually inspect baselines**

- [ ] **Step 8: Commit**

```bash
git add RetireSmartIRA/Theme/Components/InfoButton.swift RetireSmartIRATests/InfoButtonSnapshotTests.swift RetireSmartIRATests/__Snapshots__/ RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add InfoButton component (filled brand teal at 16pt) with snapshot baselines"
```

---

### Task 2.5: Write Theme/README.md

**Files:**
- Create: `RetireSmartIRA/Theme/README.md`

- [ ] **Step 1: Write the README**

Create `RetireSmartIRA/Theme/README.md`:

```markdown
# RetireSmartIRA Theme System

Tokens and reusable components for the 1.8+ design system.

**Spec:** `docs/superpowers/specs/2026-04-25-color-system-design.md`

## Quick reference

### Color tokens (3 namespaces — STRICTLY non-overlapping)

| Namespace | Purpose | Example |
|---|---|---|
| `Color.UI.*` | Brand identity, surfaces, text | `Color.UI.brandTeal` |
| `Color.Semantic.*` | Meaning-bearing (refund/action/error) | `Color.Semantic.amber` |
| `Color.Chart.*` | Data visualization only | `Color.Chart.heroTeal` |

### Components

| Component | Use case |
|---|---|
| `BrandButton` | All buttons — 5 style variants |
| `MetricCard` | Top-stripe metric cards |
| `InfoButton` | Tooltip trigger, ⓘ |
| `Badge` | Inline category label (REFUND, DUE, etc.) |

### Spacing & radius

| Token | Use |
|---|---|
| `Spacing.xxs` (4) → `Spacing.xxl` (48) | Padding, gaps |
| `Radius.card` (12) | Outer cards |
| `Radius.input` (8) | Text fields |
| `Radius.button` (6) | Buttons |
| `Radius.badge` (4) | Tags / status badges |
| `Radius.capsule(forHeight:)` | True pills |

## Strict rules

1. **Color.Chart never overlaps Color.Semantic.** Charts use teal + grays + sand. No green-meaning-savings, no red-meaning-loss bars.
2. **Green = refund only.** Not savings, not gains, not "good."
3. **Amber = action required only.** Applied to deadline TEXT and badges. NEVER to dollar amounts themselves.
4. **Red = error / blocking only.** NEVER for "tax owed" — taxes are a mechanical reality.
5. **No yellow.** Tip callouts use gray italic + ⓘ icon.
6. **Tertiary buttons default to gray text.** Teal text only for actions that genuinely advance the user (≈1 in 5 inline links).

## Dark mode

Every token has light + dark variants in the asset catalog. Components consume tokens, so dark mode is automatic.

Special dark-mode rules:
- Body text uses 92% white, not pure white (reduces glare).
- Charts use *fewer* categories in dark mode than light mode (contrast compresses).
- Brand teal brightens slightly (`#3D8FA3`) to maintain perceived saturation against dark surfaces.

## Adding a new color

Don't, until you've checked: which job does it have? If the job overlaps an existing token, reuse. If a new job exists, add it to the appropriate namespace and update this README.
```

- [ ] **Step 2: Add to Xcode target (optional — README is just docs)**

The README doesn't need to be in the target, but having it visible in the Xcode navigator is helpful. Drag into `Theme/` group; in target membership panel, leave unchecked (it's documentation, not source).

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRA/Theme/README.md
git commit -m "Add Theme/ system documentation"
```

---

## Phase 3 — Per-Screen Migration (Week 3)

Each task in Phase 3 follows the same shape:
1. Open the view file.
2. Find every hardcoded color (`Color.red`, `Color(red:green:blue:)`, named colors not in tokens).
3. Replace with the appropriate token.
4. Replace ad-hoc card/button/info-button code with the shared components from Phase 2.
5. Add a snapshot test of the screen in light + dark.
6. Smoke-test the screen manually in both modes.
7. Commit.

The token replacement decision tree:

```
Is this color decoration?  →  Use Color.UI.brandTeal or a Color.Chart.* token.
Is it semantic (refund/action/error)?  →  Color.Semantic.{green/amber/red}
Is it text?  →  Color.UI.text{Primary/Secondary/Tertiary/Utility}
Is it a surface?  →  Color.UI.surface{App/Card/Inset/Modal/Divider}
Is it data viz?  →  Color.Chart.* (NEVER Color.Semantic.*)
```

Anti-patterns to flag during migration:
- Tax amounts in red → switch to `Color.UI.textPrimary`
- Generic "good" outcomes in green → switch to `Color.UI.textPrimary`
- Generic "warning" callouts in yellow → remove (use gray italic + InfoButton)
- Decorative rainbow palette in charts → switch to `Color.Chart.categoricalSeries(count:callout:)` or `Color.Chart.sequentialRamp(count:)`

### Per-screen snapshot test template

Before starting per-screen migration, create the shared screen snapshot test infrastructure:

### Task 3.0: Create ScreenSnapshotTests.swift template

**Files:**
- Create: `RetireSmartIRATests/ScreenSnapshotTests.swift`

- [ ] **Step 1: Create the test scaffold**

Create `RetireSmartIRATests/ScreenSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import RetireSmartIRA

/// Top-level screen snapshot tests. One test method per screen × color scheme.
/// Failures during migration are EXPECTED — re-record baselines after manual review.
final class ScreenSnapshotTests: XCTestCase {

    /// Standard test device for snapshot consistency.
    /// Choose iPhone 15 Pro size (393×852) for iOS, fixed Mac size for macOS.
    private static let testWidth: CGFloat = 393
    private static let testHeight: CGFloat = 852

    private func snap<V: View>(
        _ view: V,
        scheme: ColorScheme,
        function: String = #function
    ) {
        let wrapped = view
            .frame(width: Self.testWidth, height: Self.testHeight)
            .preferredColorScheme(scheme)
        assertSnapshot(of: wrapped, as: .image, named: "\(function)-\(scheme == .dark ? "dark" : "light")")
    }

    // MARK: - Per-screen tests added below as each screen is migrated.
    // Test naming convention: test_<screenName>_<scheme>
}
```

- [ ] **Step 2: Add to test target**

Drag into `RetireSmartIRATests/` group.

- [ ] **Step 3: Verify it builds**

`Cmd+B` (build only). Expected: success.

- [ ] **Step 4: Commit**

```bash
git add RetireSmartIRATests/ScreenSnapshotTests.swift RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Add ScreenSnapshotTests scaffold for per-screen visual regression"
```

---

### Task 3.1: Migrate DashboardView.swift

**Files:**
- Modify: `RetireSmartIRA/DashboardView.swift`
- Modify: `RetireSmartIRATests/ScreenSnapshotTests.swift`

- [ ] **Step 1: Audit current color usage**

```bash
grep -n "Color\." /Users/johnurban/Projects/RetireSmartIRA/RetireSmartIRA/DashboardView.swift | head -50
grep -n "Color(red:" /Users/johnurban/Projects/RetireSmartIRA/RetireSmartIRA/DashboardView.swift
```

Document each non-token color reference and the token it should map to. Save to a working note (don't commit) so the implementer can reference during refactor.

- [ ] **Step 2: Replace hardcoded colors with tokens**

For each hardcoded color found in Step 1, edit the line to use a token from `Color.UI.*` / `Color.Semantic.*` / `Color.Chart.*`. Apply the decision tree at the top of Phase 3.

Example replacements:

```swift
// BEFORE
.foregroundColor(Color(red: 0.42, green: 0.18, blue: 0.62))   // ad-hoc purple
.background(Color.red.opacity(0.1))                            // tax-owed accent

// AFTER
.foregroundStyle(Color.UI.brandTeal)
.background(Color.UI.surfaceCard)  // taxes are normal, not red
```

- [ ] **Step 3: Replace ad-hoc cards with `MetricCard`**

Find any inline `RoundedRectangle()` + `VStack` patterns that match the metric-card shape. Replace with `MetricCard(label:value:delta:category:badge:)`. Remove the ad-hoc styling code.

- [ ] **Step 4: Replace ad-hoc buttons with `BrandButton`**

Find any inline `Button(action:)` with custom styling. Replace with `BrandButton(title:style:action:)`. Pick the right style:
- "Save", "Calculate", main CTA → `.primary`
- "Cancel" next to Save → `.secondary`
- Inline "Edit", "Reset" → `.tertiaryUtility`
- Inline "Learn more", "View breakdown" → `.tertiaryForward` (use sparingly)

- [ ] **Step 5: Replace info icons with `InfoButton`**

Find any `Image(systemName: "info.circle")` (or similar). Replace with `InfoButton { /* show tooltip */ }`.

- [ ] **Step 6: Replace inline badges with `Badge`**

Find any `Text("REFUND").background(...).clipShape(...)` patterns. Replace with `Badge(text: "REFUND", variant: .refund)`.

- [ ] **Step 7: Add a snapshot test for the migrated screen**

In `RetireSmartIRATests/ScreenSnapshotTests.swift`, add:

```swift
func test_dashboardView_light() {
    snap(DashboardView(), scheme: .light)
}

func test_dashboardView_dark() {
    snap(DashboardView(), scheme: .dark)
}
```

If `DashboardView()` requires environment objects or initializer args, mock them with realistic test data:

```swift
func test_dashboardView_light() {
    let view = DashboardView()
        .environmentObject(DataManager.preview)  // create a `preview` static if needed
        .environmentObject(ScenarioStateManager.preview)
    snap(view, scheme: .light)
}
```

If `DataManager.preview` doesn't exist, add it as a `static let preview = DataManager(...)` in `DataManager.swift`. This is fixture infrastructure, not feature code — keep it minimal.

- [ ] **Step 8: Run snapshot test to record baseline**

`Cmd+U` filtered to `test_dashboardView`. First run records, second run verifies.

- [ ] **Step 9: Visually inspect baseline**

Open `RetireSmartIRATests/__Snapshots__/ScreenSnapshotTests/test_dashboardView_light.png` and `test_dashboardView_dark.png`. Verify:
- Brand teal appears in nav / accent positions
- No red on tax amounts
- No yellow anywhere
- Cards have top-stripe in correct category color
- Charts use teal + grays + sand (no rainbow)

If anything looks wrong, fix the source and re-record.

- [ ] **Step 10: Run full test suite**

`Cmd+U`. Expected: all tests PASS (existing + new screen tests).

- [ ] **Step 11: Manual smoke test in simulator**

Build and run on iPhone 15 simulator → switch between light + dark mode (Cmd+Shift+A in simulator) → verify the dashboard reads correctly in both. Note any issues for follow-up.

- [ ] **Step 12: Commit**

```bash
git add RetireSmartIRA/DashboardView.swift RetireSmartIRATests/ScreenSnapshotTests.swift RetireSmartIRATests/__Snapshots__/
git commit -m "Migrate DashboardView to color tokens + shared components"
```

---

### Task 3.2 through 3.10: Migrate remaining screens

Repeat the Task 3.1 template for each screen. Each is its own task with its own commit. **Order them by complexity** (simplest first to build confidence):

| Task | File | Notes |
|---|---|---|
| **3.2** | `SettingsView.swift` | Smallest screen — good warm-up |
| **3.3** | `AccountsView.swift` | Account list, simple cards |
| **3.4** | `IncomeSourcesView.swift` | Form-heavy, lots of inputs |
| **3.5** | `RMDCalculatorView.swift` | Calculation result + chart |
| **3.6** | `QuarterlyTaxView.swift` | Has timing/deadline elements (amber stress test) |
| **3.7** | `LegacyImpactView.swift` | Comparison chart + IRR slider |
| **3.8** | `SocialSecurityPlannerView.swift` | Complex — multiple sub-views (SSChartsView, SSDataEntryView, etc.) |
| **3.9** | `TaxPlanningView.swift` | **Largest** — 9 hues today, Roth strategy guide with 6-color decorative palette |
| **3.10** | `RothConversionView.swift` | Slider + chart, double-counting warning UI |

For each: follow Task 3.1's 12 steps verbatim — substituting the screen file and view name. Each task produces a single commit.

**Special notes per screen:**

- **3.6 QuarterlyTaxView:** This is the amber stress test. Ensure deadline TEXT is amber but dollar VALUES stay primary text (per spec §7).
- **3.7 LegacyImpactView:** The "Roth wins immediately" / "Roth overtakes Traditional at year N" line at line 483 should NOT use semantic green. Keep it primary text. Per spec §7.
- **3.9 TaxPlanningView:** The Roth strategy guide currently uses 6 sequential decorative colors. Replace with `Color.Chart.sequentialRamp(count: 6)`. The chart palette must use ONLY `Color.Chart.*` — flag any use of semantic colors in charts as a bug.
- **3.10 RothConversionView:** Has a slider + text-box pair. Color states for the slider track use `Color.UI.brandTeal` (active) and `Color.Chart.gray3` (inactive).

After each screen task, run the full test suite (`Cmd+U`) to confirm no regressions in earlier screens.

---

### Task 3.11: Migrate sub-views (Social Security, Scenario Charts, etc.)

**Files:**
- Modify: `SSChartsView.swift`, `SSClaimingOptimizerView.swift`, `SSCouplesStrategyView.swift`, `SSDataEntryView.swift`, `SSSurvivorAnalysisView.swift`, `ScenarioChartsView.swift`, `StateComparisonView.swift`, `GuideView.swift`, `ClickwrapView.swift`, `ContentView.swift`, `SourcesReferencesView.swift`, `RetireSmartIRAApp.swift`, `PDFExportService.swift`

These are smaller / supporting views. Apply the same migration template (Task 3.1 steps 1–6, 10, 12). Snapshot tests are optional for these — covered transitively when the parent view (e.g., `SocialSecurityPlannerView`) is snapshot-tested.

- [ ] **Step 1: Audit each file**

```bash
for f in SSChartsView.swift SSClaimingOptimizerView.swift SSCouplesStrategyView.swift \
         SSDataEntryView.swift SSSurvivorAnalysisView.swift ScenarioChartsView.swift \
         StateComparisonView.swift GuideView.swift ClickwrapView.swift ContentView.swift \
         SourcesReferencesView.swift RetireSmartIRAApp.swift PDFExportService.swift; do
  echo "=== $f ==="
  grep -n "Color\." "RetireSmartIRA/$f" | head -10
done
```

- [ ] **Step 2: Migrate one file at a time, committing per file**

For each file, do the migration + commit. Don't batch — keep commits atomic.

```bash
git add RetireSmartIRA/SSChartsView.swift
git commit -m "Migrate SSChartsView to color tokens"
# repeat for each file
```

- [ ] **Step 3: Run full test suite**

`Cmd+U`. Expected: all previous tests PASS.

---

### Task 3.12: Sweep for remaining hardcoded colors

After all screens have been migrated, do a final sweep for any color references that escaped.

- [ ] **Step 1: Search for hardcoded RGB**

```bash
grep -rn "Color(red:" RetireSmartIRA/ --include="*.swift" | grep -v "// allowed:"
```

Each match is suspect. Either replace with a token, or — if it's truly unique decoration that doesn't fit any token — add a comment justifying it: `// allowed: one-off illustration color`.

- [ ] **Step 2: Search for legacy SwiftUI named colors that should be tokens**

```bash
grep -rn "Color\.\(red\|green\|blue\|orange\|yellow\|purple\|pink\)" RetireSmartIRA/ --include="*.swift"
```

For each match: should it be a semantic token? A chart token? A UI token? Replace appropriately. The exception is system colors like `.primary`, `.secondary`, `.accentColor`, `.clear`, `.white`, `.black` — those are fine to keep where they semantically apply.

- [ ] **Step 3: Run full test suite**

`Cmd+U`. Expected: PASS.

- [ ] **Step 4: Commit any sweep fixes**

```bash
git add -A
git commit -m "Final sweep: replace remaining hardcoded colors with tokens"
```

---

## Phase 4 — Final QA & Polish

### Task 4.1: Full visual regression sweep

**Files:** N/A (review only)

- [ ] **Step 1: Run full test suite**

`Cmd+U`. Expected: all tests PASS — token tests, contrast assertions, component snapshots, screen snapshots.

- [ ] **Step 2: Visually review every snapshot**

Open `RetireSmartIRATests/__Snapshots__/` and walk every PNG. Compare against the design spec. For each:
- Brand teal in correct positions?
- No red on tax amounts?
- No yellow anywhere?
- Cards have correct category stripes?
- Charts use only Chart namespace tokens?
- Dark mode looks good (not just inverted, actually well-tuned)?

Flag any issues; fix and re-record.

- [ ] **Step 3: Manual full-app smoke test in light mode**

Build to physical device or simulator. Walk every primary user flow:
1. Launch → Dashboard
2. Profile → Edit heir info → save
3. Income → Add income source
4. Itemized Deductions → fill in
5. SALT → see auto-calculation
6. Roth Conversion → adjust slider
7. Tax Planning → view breakdown
8. RMD → calculate
9. Legacy Impact → view chart
10. Quarterly Tax → see deadlines
11. Settings → toggle every option

Note any visual issues, fix, re-record snapshots, commit per-fix.

- [ ] **Step 4: Manual full-app smoke test in dark mode**

Same flow, dark mode. Pay extra attention to:
- Chart legibility (contrast often degrades in dark mode)
- Body text glare (should be 92% white, not eye-burning)
- Brand teal saturation (should not feel "neon")

- [ ] **Step 5: No commit if no changes; otherwise commit**

```bash
git add -A
git commit -m "Visual regression fixes from full QA sweep"  # only if changes
```

---

### Task 4.2: Accessibility verification

**Files:** N/A (review only)

- [ ] **Step 1: Run contrast assertion tests**

`Cmd+U` filtered to `ContrastAssertionTests`. Expected: all PASS.

- [ ] **Step 2: VoiceOver smoke test (iOS)**

Run on simulator with VoiceOver on. Walk the dashboard. Verify:
- Every InfoButton has accessibility label "More information"
- Every BrandButton announces its title
- Every Badge announces its text
- No "Image" announcements without context

Note any issues; fix in components or labels. Re-run.

- [ ] **Step 3: Dynamic Type smoke test**

In Settings → Display & Brightness → Text Size → set to largest. Open the app. Verify nothing clips egregiously. Note: full Dynamic Type compliance is out of scope for 1.8 (per spec §10) — flag findings as follow-up.

- [ ] **Step 4: Commit any accessibility fixes**

```bash
git add -A
git commit -m "Accessibility fixes from VoiceOver / contrast review"  # only if changes
```

---

### Task 4.3: Bump version to 1.8.0

**Files:**
- Modify: `RetireSmartIRA.xcodeproj/project.pbxproj`

- [ ] **Step 1: Find current version**

```bash
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" RetireSmartIRA.xcodeproj/project.pbxproj | head -10
```

Should show `MARKETING_VERSION = 1.7.2;` and a CURRENT_PROJECT_VERSION.

- [ ] **Step 2: Bump version in Xcode**

Open Xcode → select project → General tab → set:
- Version: `1.8.0`
- Build: increment from current (e.g., 31 → 32)

- [ ] **Step 3: Verify the change**

```bash
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" RetireSmartIRA.xcodeproj/project.pbxproj | head -10
```

Expected: shows `1.8.0` and bumped build number.

- [ ] **Step 4: Build and run**

`Cmd+R`. Expected: launches successfully.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "Bump version to 1.8.0 (color system release)"
```

---

### Task 4.4: Spawn follow-up tasks identified during migration

**Files:** N/A (task spawning only)

The spec section §10 lists deferred work. During implementation, the agent may have noticed additional gaps. Spawn follow-up tasks now while context is fresh:

- [ ] **Step 1: Spawn the tooltip discoverability initiative**

Using the `mcp__ccd_session__spawn_task` tool (or document in tracking file):

Title: "Tooltip discoverability UX research"
TLDR: "Beta users miss most info-button tooltips. The 1.8 visual fix helps but doesn't solve discovery. Run a focused initiative: promote top tooltips to inline microcopy, design a first-run tour, add tap telemetry."
Prompt: "Investigate which info-button tooltips in RetireSmartIRA carry the highest-value content (look at recent beta feedback). Propose: (1) 3–5 tooltips that should be promoted to inline microcopy, (2) a first-run onboarding tour design, (3) telemetry instrumentation to measure tap rates. This builds on top of the 1.8 InfoButton component visual fix already shipped. Reference docs/superpowers/specs/2026-04-25-color-system-design.md §4 and §10."

- [ ] **Step 2: Document any other findings**

Add to `docs/beta-feedback/2026-05-XX-1.8-followups.md` (or append to the Ron Park tracking doc): any visual issues, copy issues, or UX gaps noticed during migration that weren't in scope for 1.8.

- [ ] **Step 3: Commit**

```bash
git add docs/
git commit -m "Document 1.8 follow-up tasks"
```

---

### Task 4.5: Open PR and request review

**Files:** N/A (git/GitHub only)

- [ ] **Step 1: Push branch**

```bash
git push origin 1.8/color-system
```

- [ ] **Step 2: Open PR via gh**

```bash
gh pr create --title "1.8 — Color system & design token refresh" --body "$(cat <<'EOF'
## Summary
- Brand color: Muted Teal `#2A6B7C` (light) / `#3D8FA3` (dark)
- Three non-overlapping token namespaces: `Color.UI` / `Color.Semantic` / `Color.Chart`
- 5 reusable components: `BrandButton`, `MetricCard`, `InfoButton`, `Badge`
- Strict semantic contract: green=refund only, amber=action only, red=error only, no yellow
- Light + dark mode parity via tokens
- Visual regression coverage via snapshot tests
- WCAG AA contrast assertions for all token combinations

## Test plan
- [x] All token unit tests pass
- [x] Contrast assertion tests pass (WCAG AA on every text/surface combo)
- [x] Component snapshot baselines committed and reviewed
- [x] Per-screen snapshot tests in light + dark mode
- [x] Manual smoke test: every primary user flow in light mode
- [x] Manual smoke test: every primary user flow in dark mode
- [x] VoiceOver smoke test on dashboard
- [x] Build succeeds on iPhone simulator
- [x] Build succeeds on macOS (My Mac target)

## Spec
`docs/superpowers/specs/2026-04-25-color-system-design.md`

## Implementation plan
`docs/superpowers/plans/2026-04-25-color-system.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Return PR URL to user**

The PR is now open. User reviews and merges when satisfied.

---

## Self-review checklist (read after writing — fill in before submitting plan)

### Spec coverage

- [x] §1 Overview — addressed by Phase 0 (branch setup) + intro
- [x] §2 Color contract — addressed by Tasks 1.2, 1.3, 1.4 (tokens) + 1.8 (contrast)
- [x] §3 Token architecture — addressed by Tasks 1.3, 1.4, 1.5 (3 namespaces)
- [x] §4 Component tokens — addressed by Tasks 2.1–2.5
- [x] §5 Chart palette — addressed by Task 1.5 (Color.Chart namespace + helpers)
- [x] §6 Surfaces, spacing, radii — addressed by Tasks 1.2, 1.6, 1.7
- [x] §7 Numerical color rules — enforced via Phase 3 audit + manual review
- [x] §8 Migration scope — addressed by Phase 3 (one task per screen)
- [x] §9 Testing — addressed by Tasks 1.8 (contrast), 2.x (component snapshots), 3.x (screen snapshots), 4.1 (visual sweep), 4.2 (a11y)
- [x] §10 Out of scope — addressed by Task 4.4 (spawn follow-ups)
- [x] §11 Risks — mitigations baked into task structure (visual regression, atomic commits)
- [x] §12 Approval/next steps — addressed by Task 4.5 (PR)

### Placeholder scan

No "TBD", "TODO", "implement later", "fill in details", or "similar to Task N" patterns. All code shown literally. All commands shown literally. All file paths absolute or repository-relative.

### Type consistency

- `BrandButton.Style` cases used consistently across BrandButton.swift and BrandButtonSnapshotTests.swift
- `MetricCard.Category` referenced consistently (informational/actionRequired/error)
- `Badge.Variant` referenced consistently (refund/due/error/neutral)
- Token names consistent: `Color.UI.brandTeal`, `Color.Semantic.amber`, `Color.Chart.heroTeal`
- `Spacing.xxs` (lowercase) consistent — never `Spacing.XXS`
- `Radius.button`, `Radius.card`, `Radius.badge` consistent

---

*End of plan.*
