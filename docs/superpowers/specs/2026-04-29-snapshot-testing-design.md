# 1.9 Task 2 — Snapshot Testing Design

**Status:** Approved (2026-04-29)
**Author:** John Urban (with brainstorm collaboration)
**Date:** 2026-04-29
**Target release:** RetireSmartIRA 1.9 (prerequisite for the four other 1.9 tasks)
**Related docs:**
- `docs/1.9-roadmap.md` — Task 2 entry
- `docs/superpowers/plans/2026-04-25-color-system.md` §"Plan Addendum 2026-04-25 — Snapshot testing deferred to 1.9" — explains why 1.8 punted
- Reverted commit `03b8208` — "Remove swift-snapshot-testing dependency for 1.8"

---

## 1. Overview

RetireSmartIRA 1.7.x and earlier had no automated visual regression coverage. The 1.8 release added 21 WCAG contrast assertions and ~15 component behavior tests, but skipped image-based snapshot tests after `swift-snapshot-testing` 1.18+ failed to link cleanly in our Xcode 16 setup (Swift Testing integration target conflicts) and 1.16/1.17 hit separate XCTest linker issues. ~45 minutes were burned before deferring to 1.9.

This spec re-introduces snapshot testing as a 1.9 prerequisite. It is intentionally different from the 1.8 attempt:
- **No external dependency.** A small homebrew helper using SwiftUI's built-in `ImageRenderer` and `XCTAttachment` replaces the third-party library that bit us.
- **macOS-only.** Single-platform coverage avoids 2× baseline maintenance. iOS/iPadOS coverage can be added later if 1.9 features land iOS-specific bugs that screen snapshots would have caught.
- **Two-pass staging.** Helper + components ship as PR 1; screens ship as PR 2 once the helper is proven against simple cases.

### Scope discipline

**In scope:**
- ~80-line homebrew snapshot helper (`SnapshotHelper.swift`)
- 4 component snapshot test files (Pass 1, 28 baselines)
- 1 fixture helper (`SnapshotFixtures.swift`) building on existing `DemoProfile`
- 9 screen snapshot test files (Pass 2, 18 baselines)
- 46 PNG baselines committed to `RetireSmartIRATests/__Snapshots__/`

**Out of scope (defer to later):**
- iOS / iPadOS coverage
- Sheets, modals, alerts (timing complications)
- Sub-views (SS sub-views, ScenarioCharts, GuideView, ClickwrapView, SourcesReferences)
- Migration of existing behavior tests to Swift Testing
- CI integration (project does not currently run snapshot tests in CI; record-on-dev / verify-everywhere is the implicit default)

---

## 2. Decisions log

Each decision below was made during the 2026-04-29 brainstorm. Captured here so a future agent picking up this spec doesn't re-litigate.

| # | Decision | Rationale |
|---|---|---|
| 1 | **Library:** homebrew helper using `ImageRenderer` + `XCTAttachment`, no SPM dependency | 1.8 deferral was specifically caused by `swift-snapshot-testing` linker fragility; same library at v1.19.2 is ~13 months old with no recent fixes. Owning ~80 lines eliminates the entire failure class. Apple's Xcode 26.4 image-*attachment* API helps but is not a comparison framework, so it doesn't eliminate the need for our own logic. |
| 2 | **Platform:** macOS only | Project memory: "Native macOS + iOS/iPadOS." User preference: avoid double-maintenance burden of two platforms. Components render identically across platforms; macOS-only catches the bulk of regressions. |
| 3 | **Test runner:** XCTest | Matches the existing 13 test files in `RetireSmartIRATests/`. Stays as far as possible from the Swift Testing integration that broke 1.8. Snapshot tests rarely benefit from Swift Testing's `@Test(arguments:)` parametrization in practice — explicit per-variant func names produce more readable failure logs. |
| 4 | **Scope staging:** two passes (helper + components, then screens) | Helper is the highest-risk piece; proving it on isolated components first means screen-test failures in Pass 2 are unambiguously fixture problems, not helper problems. Each pass is independently shippable. |
| 5 | **Tolerance:** 0.01% pixel-diff threshold | Exact-match would flake on cross-machine font anti-aliasing variations. 0.01% (≈100 pixels in a 1000×1000 image) tolerates AA noise while catching anything color-token-meaningful (a wrong color floods thousands of pixels). |
| 6 | **Helper signature:** `assertSnapshot(of: view, named: name, size: nil, record: false)` | Single function, explicit names per call, no auto-naming from `#function`. Explicit names like `BrandButton_destructivePrimary_dark` read cleanly in failure logs. |
| 7 | **Storage:** `RetireSmartIRATests/__Snapshots__/<TestClass>/<name>.png` | Matches PointFree convention; if we ever migrate to `swift-snapshot-testing`, baselines are already in the right place. |
| 8 | **Record mechanism:** `RECORD_SNAPSHOTS=1` env var on test scheme; delete a PNG to re-record one test | Familiar to anyone who's used PointFree's library. Zero per-call API changes needed. |
| 9 | **Component variant coverage:** per-variant explicit (no kitchen-sink images) | When a snapshot fails, the test name names the broken variant. Diff-readability of small per-variant PNGs is much higher than scanning a 6-button grid. 28 baselines is manageable. |
| 10 | **Skip BrandButton size variants** (compact/prominent) at this stage | Pure font/padding scaling — low signal for visual regression. Add later if regressions prove the assumption wrong. |
| 11 | **Screen fixture strategy:** shared `SnapshotFixtures.makeSnapshotEnvironment()` building on `DemoProfile` | Centralizes the per-screen environment construction. DemoProfile changes (driven by App Store screenshots) auto-propagate to snapshots as expected diffs. Fixture function calls into DemoProfile's existing setup; minor refactor to expose a code-callable entry point if not already present. |
| 12 | **Screen list (9):** Dashboard, TaxPlanning, RMDCalculator, LegacyImpact, SocialSecurityPlanner, Accounts, IncomeSources, QuarterlyTax, Settings | The top-level views from `ContentView`'s tab structure. Sub-views and modals deferred. |
| 13 | **Screen window size:** 1280×800 (standard macOS window) | Captures realistic layout including any responsive breakpoints used in the app. Components use intrinsic size. |
| 14 | **Capture scope:** view body only, no menu bar / window chrome | The view body is what regression tests should cover; chrome is system-rendered and doesn't change with our code. |

---

## 3. Architecture

### File layout

```
RetireSmartIRA/
└── Theme/Components/...                   ← unchanged from 1.8
      (BrandButton.swift, MetricCard.swift, Badge.swift, InfoButton.swift)

RetireSmartIRATests/
├── (existing 13 test files unchanged)
├── SnapshotHelper.swift                   ← NEW (Pass 1): ~80-line homebrew helper
├── SnapshotFixtures.swift                 ← NEW (Pass 2): DemoProfile-backed env
├── BrandButtonSnapshotTests.swift         ← NEW (Pass 1): 12 baselines
├── MetricCardSnapshotTests.swift          ← NEW (Pass 1):  6 baselines
├── BadgeSnapshotTests.swift               ← NEW (Pass 1):  8 baselines
├── InfoButtonSnapshotTests.swift          ← NEW (Pass 1):  2 baselines
├── DashboardSnapshotTests.swift           ← NEW (Pass 2):  2 baselines
├── TaxPlanningSnapshotTests.swift         ← NEW (Pass 2):  2 baselines
├── RMDCalculatorSnapshotTests.swift       ← NEW (Pass 2):  2 baselines
├── LegacyImpactSnapshotTests.swift        ← NEW (Pass 2):  2 baselines
├── SocialSecurityPlannerSnapshotTests.swift  ← NEW (Pass 2):  2 baselines
├── AccountsSnapshotTests.swift            ← NEW (Pass 2):  2 baselines
├── IncomeSourcesSnapshotTests.swift       ← NEW (Pass 2):  2 baselines
├── QuarterlyTaxSnapshotTests.swift        ← NEW (Pass 2):  2 baselines
├── SettingsSnapshotTests.swift            ← NEW (Pass 2):  2 baselines
└── __Snapshots__/                         ← NEW: 46 PNGs total, ~230KB committed
    ├── BrandButtonSnapshotTests/
    │   ├── BrandButton_primary_light.png
    │   ├── BrandButton_primary_dark.png
    │   └── ... (10 more)
    ├── MetricCardSnapshotTests/           (6 PNGs)
    ├── BadgeSnapshotTests/                (8 PNGs)
    ├── InfoButtonSnapshotTests/           (2 PNGs)
    ├── DashboardSnapshotTests/            (2 PNGs)
    └── ... (8 more screen folders, 16 PNGs total)
```

### Existing 1.8 behavior tests are unchanged

The 1.8 component behavior tests (`BrandButtonTests.swift`, `MetricCardTests.swift`, `BadgeTests.swift`, `InfoButtonTests.swift`) stay exactly as they are. Snapshot tests are additive — they live in separate files and assert different things (visual identity vs. behavioral correctness).

---

## 4. Helper API (`SnapshotHelper.swift`)

### Public surface

```swift
@MainActor
func assertSnapshot(
    of view: some View,
    named name: String,
    size: CGSize? = nil,           // nil = intrinsic; pass for screens
    record: Bool = false,           // overrides env var if true
    file: StaticString = #file,
    line: UInt = #line
)
```

Single public function. Caller responsibility:
- Apply `.preferredColorScheme(.light)` or `.dark)` to the view at the call site (helper does not branch on mode internally — the mode is part of the rendered view).
- Pass `size` for screen-level snapshots; omit for components (intrinsic sizing).
- Use a unique, explicit `name` per call. Convention: `<Subject>_<variant>_<mode>` (e.g., `BrandButton_destructivePrimary_dark`, `Dashboard_light`).

### Rendering

`ImageRenderer(content: view)` with hard-coded `scale = 2.0` (Retina). If `size` is provided, the view is wrapped in `.frame(width: size.width, height: size.height)` before rendering. The `cgImage` property is read on the main actor (hence `@MainActor` on the helper).

The hard-coded scale is deliberate — `ImageRenderer.scale` defaults to the host display's scale, which would produce different pixel counts on different machines. Pinning to 2.0 ensures baselines are reproducible. Documented in the helper's header comment.

### Storage path computation

From `#file`, derive the test class name by stripping the file path prefix and `.swift` suffix:
- `.../RetireSmartIRATests/BrandButtonSnapshotTests.swift` → class name `BrandButtonSnapshotTests`
- Baseline path: `<repo>/RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/<name>.png`

The `<repo>` portion is computed at runtime from `#file` (walk up directories until finding `RetireSmartIRATests/`). This avoids hard-coding the user's home directory.

### Three-branch logic

**Branch 1 — Record (forced, env, or missing):**
- Triggered when `record == true`, OR `RECORD_SNAPSHOTS=1` env var is set, OR no baseline file exists at the computed path.
- Action: render → write PNG to baseline path (creating directories as needed) → `XCTFail("Recorded baseline at <path>", file: file, line: line)`.
- Why fail on record: prevents accidentally committing a green test that didn't actually compare anything. Forces the developer to unset the env var / re-run before claiming the test passes.

**Branch 2 — Compare:**
- Triggered when baseline exists and record is not active.
- Action: render the actual image → load baseline as `CGImage` → compare via byte-buffer pixel diff (see §4.5 below).
- If `(differing_pixels / total_pixels) > 0.0001`:
  - Build three `XCTAttachment`s: `actual.png`, `expected.png`, `diff.png` (red-tinted XOR — pixels that differ rendered as red on a transparent background).
  - `XCTFail("Snapshot mismatch: <pct>% pixels differ (threshold: 0.01%)", file: file, line: line)`.
  - Attachments named clearly so they're easy to find in the Xcode test report.
- Else: pass silently.

**Branch 3 — Edge case:**
- Baseline image exists but has different dimensions from the freshly rendered image (e.g., view was resized). Treat as a render-time failure: `XCTFail("Snapshot dimensions changed: baseline <WxH>, actual <WxH> — delete baseline to re-record")`.

### Pixel comparison algorithm

```
1. Convert both CGImages to a known pixel format (kCGImageAlphaPremultipliedLast, RGBA8).
2. Get raw byte buffers via CGDataProvider.
3. Iterate 4 bytes at a time (one pixel). A pixel "differs" if any of R/G/B/A differ by more than 1 (tolerance for sub-pixel rounding noise).
4. Count differing pixels; compute fraction.
5. Build diff image: same size as input, RGBA8. For each pixel: if differs, set pixel to (255, 0, 0, 200) (red, semi-transparent); else set to (0, 0, 0, 0) (transparent).
```

Total helper size estimate: ~80 lines including comments and the diff-image builder. Self-contained in `SnapshotHelper.swift`.

### Header comment requirements

The file starts with a comment block that documents:
- The hard-coded `scale = 2.0` decision and why.
- The 0.01% tolerance and how to adjust if CI flakes.
- The `RECORD_SNAPSHOTS=1` env var workflow.
- The "delete a PNG to re-record one test" workflow.
- Why the helper exists vs. using `swift-snapshot-testing` (one-paragraph summary, link to this spec).

---

## 5. Pass 1 — Components (PR 1)

**Estimate:** ~half day.

**Deliverables:**
1. `SnapshotHelper.swift` (~80 LOC).
2. Four test files (one per component), uniform pattern.
3. 28 PNG baselines under `__Snapshots__/`.
4. One paragraph added to `RetireSmartIRA/Theme/README.md` documenting the helper's existence and the record workflow.

### Variant table

| Test class | Variants snapshotted | × modes | = baselines |
|---|---|---|---|
| `BrandButtonSnapshotTests` | 6 styles at `.standard` size: `.primary`, `.secondary`, `.tertiaryUtility`, `.tertiaryForward`, `.destructiveSecondary`, `.destructivePrimary` | × 2 | 12 |
| `MetricCardSnapshotTests` | 3 categories: `.informational`, `.actionRequired`, `.error` | × 2 | 6 |
| `BadgeSnapshotTests` | 4 variants: `.refund`, `.due`, `.error`, `.neutral` | × 2 | 8 |
| `InfoButtonSnapshotTests` | 1 style (filled brand-teal at 16pt) | × 2 | 2 |
| **Total** | | | **28** |

### Test pattern (uniform)

```swift
@MainActor
final class BrandButtonSnapshotTests: XCTestCase {
    func test_primary_light() {
        let view = BrandButton("Convert", style: .primary, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_primary_light")
    }

    func test_primary_dark() {
        let view = BrandButton("Convert", style: .primary, size: .standard) {}
            .padding()
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_primary_dark")
    }

    // ... 10 more tests for the other 5 styles × 2 modes
}
```

The `.padding()` is intentional — gives the component breathing room in the rendered PNG so the diff isn't dominated by edge anti-aliasing.

### Recording the initial baselines

1. With `RECORD_SNAPSHOTS=1` set in scheme env vars, run all snapshot tests. They all "fail" with "Recorded baseline at ..." messages. PNGs written to disk.
2. Visually inspect each PNG against the component's `#Preview` rendering in Xcode Canvas. Confirm correctness.
3. Unset the env var, re-run. All tests should now pass.
4. `git add RetireSmartIRATests/__Snapshots__/` and commit alongside the test files.

### Acceptance criteria

- All 28 snapshot tests pass on a clean checkout with `RECORD_SNAPSHOTS` unset.
- All 670+ existing tests still pass.
- A deliberate color change to a single component (e.g., temporarily change `Color.UI.brandTeal`) causes the relevant snapshot tests to fail with attached actual/expected/diff PNGs visible in the Xcode test report.

---

## 6. Pass 2 — Screens (PR 2)

**Estimate:** ~half-to-full day, depending on `DemoProfile` refactor scope.

**Deliverables:**
1. `SnapshotFixtures.swift`.
2. Small `DemoProfile.swift` refactor if needed (extract demo-data setup into a static, code-callable function).
3. Nine screen test files.
4. 18 PNG baselines under `__Snapshots__/`.

### Fixture helper

```swift
@MainActor
enum SnapshotFixtures {
    /// Returns a populated environment matching the -DemoProfile launch arg
    /// (Pat 64, Sue 62, MFJ CA, $200K Roth conversion, asymmetric SS PIAs).
    static func makeSnapshotEnvironment() -> Environment

    struct Environment {
        let dataManager: DataManager
        let scenarioState: ScenarioStateManager
        let incomeDeductions: IncomeDeductionsManager
        let accounts: AccountsManager
        let growthRates: GrowthRatesManager
        let socialSecurity: SocialSecurityManager
        let legacyPlanning: LegacyPlanningManager
        // (Final list determined by reading DemoProfile.swift at start of Pass 2.)
    }
}
```

**Implementation strategy:**
1. First task of Pass 2: read `RetireSmartIRA/DemoProfile.swift` and identify the entry point that runs at `-DemoProfile` launch.
2. If that entry point is already a static function or static helper, call it from `makeSnapshotEnvironment()` directly.
3. If it's inline in `RetireSmartIRAApp.init()` or behind a launch-arg check, refactor: extract into `DemoProfile.makeEnvironment() -> Environment` (or similar), call from both the launch path and the new fixture.
4. The fixture must pin time-dependent state: `currentYear` and `planYear` set to known values (probably 2026 given today's date) so snapshot baselines don't drift on January 1.

### Test pattern (uniform across all 9 screens)

```swift
@MainActor
final class DashboardSnapshotTests: XCTestCase {
    func test_dashboard_light() {
        let env = SnapshotFixtures.makeSnapshotEnvironment()
        let view = DashboardView()
            .environmentObject(env.dataManager)
            .environmentObject(env.scenarioState)
            // ... whatever else DashboardView consumes
            .frame(width: 1280, height: 800)
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "Dashboard_light",
                       size: CGSize(width: 1280, height: 800))
    }

    func test_dashboard_dark() { /* same with .dark */ }
}
```

The `.environmentObject(...)` chain matches whatever the real screen reads — determined by quick grep at the start of each screen's test work.

### Screens covered

| # | View | Test file | Baselines |
|---|---|---|---|
| 1 | `DashboardView` | `DashboardSnapshotTests.swift` | 2 |
| 2 | `TaxPlanningView` | `TaxPlanningSnapshotTests.swift` | 2 |
| 3 | `RMDCalculatorView` | `RMDCalculatorSnapshotTests.swift` | 2 |
| 4 | `LegacyImpactView` | `LegacyImpactSnapshotTests.swift` | 2 |
| 5 | `SocialSecurityPlannerView` | `SocialSecurityPlannerSnapshotTests.swift` | 2 |
| 6 | `AccountsView` | `AccountsSnapshotTests.swift` | 2 |
| 7 | `IncomeSourcesView` | `IncomeSourcesSnapshotTests.swift` | 2 |
| 8 | `QuarterlyTaxView` | `QuarterlyTaxSnapshotTests.swift` | 2 |
| 9 | `SettingsView` | `SettingsSnapshotTests.swift` | 2 |
| | | **Total** | **18** |

### Recording the initial baselines

1. With `RECORD_SNAPSHOTS=1` set, run all screen snapshot tests. PNGs written.
2. **Critical visual review step:** for each PNG, launch the app with `-DemoProfile`, navigate to the corresponding screen in light + dark mode, and compare visually against the recorded PNG. They should match (modulo window chrome, which the snapshot doesn't capture).
3. If any PNG looks wrong, that's a real signal — either the fixture is incomplete (manager state missing), the screen has hidden environment dependencies, or the screen reads `Date()` directly. Fix the underlying issue, delete the PNG, re-record.
4. Once all 18 PNGs match the live app, unset env var, re-run, all green.
5. `git add` PNGs alongside test files.

### Acceptance criteria

- All 18 screen snapshot tests pass on a clean checkout with `RECORD_SNAPSHOTS` unset.
- All 28 component snapshot tests from Pass 1 still pass.
- All 670+ existing tests still pass.
- Each PNG visually matches the corresponding screen rendered in the running app with `-DemoProfile`.
- A deliberate token change (e.g., temporarily changing `Color.UI.surfaceCard`) causes multiple screen snapshots to fail — confirms cross-screen regression coverage actually works.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Font anti-aliasing varies across macOS minor versions or graphics driver state, causing flaky tests | 0.01% threshold absorbs typical AA noise. If CI / multi-machine flakes appear, raise to 0.05% as a documented adjustment in the helper header. |
| `ImageRenderer` scale defaulting to host display scale produces non-reproducible pixel counts | Hard-code `scale = 2.0` in helper. Documented in header comment. |
| Screen views read live `Date()` or carry time-dependent state | Pass 2 fixture pins `currentYear` and `planYear` to known values. If a view still reads `Date()` directly after fixture setup, treat as a real bug (it would also affect App Store screenshots) and fix the view, not the test. |
| Some screens use `@StateObject` and construct their own managers, making injection impossible | Confirm at start of Pass 2 by reading each screen's init. If injection isn't possible, record baseline of current behavior and file a follow-up task to refactor that screen. Do not block Pass 2 on screen refactors. |
| `__Snapshots__/` directory grows unmanageably | 46 PNGs × ~5KB each ≈ 230KB committed. Acceptable, far under any LFS threshold. |
| Xcode 26.4 image-attachment API behaves differently than `XCTAttachment(image:)` | Helper uses `XCTAttachment(image: NSImage)`, which has been mature since Xcode 7. The Xcode 26.4 change just makes attachments more visible in the test report — no helper code change needed to benefit. |
| `DemoProfile.swift` is tightly coupled to `-DemoProfile` launch-arg branching, can't be called from tests | Pass 2 first task: read `DemoProfile.swift`. Refactor only what's needed to expose a `static func makeEnvironment() -> Environment` — keep launch-arg path calling into the same function so demo behavior stays identical. Estimated ~30 minutes if refactor is needed; zero if already structured this way. |
| The helper's `#file`-based class-name extraction misbehaves with unusual paths (worktrees, symlinks) | Walk-up-directories approach is robust to symlinks and worktrees as long as `RetireSmartIRATests/` exists somewhere in the path. Document the assumption in the helper header. |

---

## 8. Future extensions (explicitly NOT in 1.9)

These are real concerns that could surface follow-up tasks but are explicitly not in this spec's scope.

- **iOS / iPadOS coverage** — re-evaluate after 1.9 ships; if iOS-specific regressions slip through, add a parallel iOS snapshot target.
- **Sub-view snapshots** — SS sub-views, ScenarioCharts, GuideView, ClickwrapView, SourcesReferences. Add per-screen if 1.9 features land in any of them and screen-level coverage proves insufficient.
- **Sheets, modals, alerts** — animation timing makes these hard to snapshot deterministically. Possible future work using `withTransaction(_:)` to disable animations.
- **CI integration** — project does not currently run snapshot tests in CI. If/when CI exists, add a step that runs `xcodebuild test` without `RECORD_SNAPSHOTS` and fails on any snapshot mismatch.
- **Migration to `swift-snapshot-testing`** — possible if PointFree ships a Swift Testing fix for Xcode 26 and we want richer features (animation snapshots, accessibility snapshots, etc.). Storage path convention matches PointFree's, so migration is mechanical.
- **Migration of existing behavior tests to Swift Testing** — orthogonal decision, separate task.

---

## 9. Approval & next steps

**Approval gate:** John reviews this spec, approves or requests revisions.

**Next step (after approval):** Invoke `superpowers:writing-plans` to break this spec into a step-by-step implementation plan with concrete code, test additions, and PR sequencing. The plan will be split per pass:
- `docs/superpowers/plans/2026-04-29-snapshot-testing-pass-1.md` — helper + components
- `docs/superpowers/plans/2026-04-29-snapshot-testing-pass-2.md` — fixture + screens

**Total estimated scope:** 1-2 days of focused work, matching the 1.9 roadmap estimate. Pass 1 lands first as its own PR; Pass 2 follows.

---

*End of spec.*
