# Snapshot Testing Pass 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land an in-house snapshot testing helper (`SnapshotHelper.swift`) plus 28 component snapshot baselines for `BrandButton`, `MetricCard`, `Badge`, and `InfoButton` so 1.9 work has automated visual regression coverage.

**Architecture:** Homebrew helper using SwiftUI's `ImageRenderer` (built-in, no SPM dependency) + `XCTAttachment` for failure artifacts. Test classes wrap each component variant in `.preferredColorScheme(.light/.dark)` and call `assertSnapshot(of:named:)`. Baseline PNGs live in `RetireSmartIRATests/__Snapshots__/<TestClass>/<name>.png` and are committed to git. macOS-only, XCTest-based, no Swift Testing surface area.

**Tech Stack:** SwiftUI · SwiftUI `ImageRenderer` (iOS 16+ / macOS 13+) · XCTest · `XCTAttachment(image:)` · CoreGraphics (`CGImage` byte buffers for pixel diff)

**Source spec:** `docs/superpowers/specs/2026-04-29-snapshot-testing-design.md`

---

## Working agreement

- **Branch:** `1.9/snapshot-testing-pass-1`. All work lands here. Merge to main when Pass 1 is green and 28 baselines have been visually reviewed.
- **No SPM dependencies.** This is the entire point — we are not adding `swift-snapshot-testing` or any other package. If a step asks to add a package, stop and re-read this line.
- **No `project.pbxproj` edits.** The project uses Xcode 16 `PBXFileSystemSynchronizedRootGroup` — new `.swift` files dropped into `RetireSmartIRATests/` are auto-discovered by Xcode. The unstaged `project.pbxproj` change at session start is not from this work; leave it alone.
- **Build green:** All 670+ existing tests must keep passing throughout. Run the full suite at the end of every Phase.
- **Commit cadence:** every task ends with a commit. No batch commits across tasks.
- **TDD discipline:** Phase 1 helper tasks are TDD — failing test first, then minimal implementation, then verify pass. Phase 2 component snapshot tests are not TDD in the traditional sense (the "test" is a snapshot recording); but each task ends green with all baselines committed.

---

## File structure (to be created)

```
RetireSmartIRATests/
├── SnapshotHelper.swift                   ← NEW: ~80-line homebrew helper + SnapshotInternal namespace
├── SnapshotHelperTests.swift              ← NEW: unit tests for the helper's pure pieces
├── BrandButtonSnapshotTests.swift         ← NEW: 12 baselines (6 styles × 2 modes)
├── MetricCardSnapshotTests.swift          ← NEW: 6 baselines (3 categories × 2 modes)
├── BadgeSnapshotTests.swift               ← NEW: 8 baselines (4 variants × 2 modes)
├── InfoButtonSnapshotTests.swift          ← NEW: 2 baselines (1 style × 2 modes)
└── __Snapshots__/                         ← NEW: 28 PNG baselines, committed
    ├── BrandButtonSnapshotTests/          ← 12 PNGs
    ├── MetricCardSnapshotTests/           ←  6 PNGs
    ├── BadgeSnapshotTests/                ←  8 PNGs
    └── InfoButtonSnapshotTests/           ←  2 PNGs

RetireSmartIRA/Theme/
└── README.md                              ← MODIFY: add ~20-line section on snapshot testing
```

---

## Phase 0 — Setup

### Task 0.1: Create feature branch

**Files:** N/A (git only)

- [ ] **Step 1: Create and switch to feature branch**

```bash
git checkout -b 1.9/snapshot-testing-pass-1
```

Expected: `Switched to a new branch '1.9/snapshot-testing-pass-1'`

- [ ] **Step 2: Verify clean state for snapshot work**

```bash
git status
```

Expected: only the pre-existing `M RetireSmartIRA.xcodeproj/project.pbxproj` from session start. No other modifications. If anything else is modified, stop and resolve before proceeding.

---

### Task 0.2: Confirm existing test baseline

**Files:** N/A (verification only)

Establishes the green baseline so we know our changes are responsible for any later failures.

- [ ] **Step 1: Run the full test suite via xcodebuild**

```bash
xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -quiet \
  2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **` with all existing tests passing (670+ test cases). If any tests fail, stop and investigate — do not start Pass 1 from a broken baseline.

- [ ] **Step 2: Note the baseline counts**

From the output, record:
- Total tests passed: ____
- Total tests failed: 0
- Build warnings: ____

These numbers are the "before" state. The completion gate for this plan is: same number passed + 28 new snapshot tests + helper unit tests, zero failures.

---

## Phase 1 — Helper (TDD)

The helper lives in `RetireSmartIRATests/SnapshotHelper.swift`. It exposes one public function (`assertSnapshot`) and an internal namespace (`enum SnapshotInternal`) of pure functions that are unit-testable without going through `XCTFail`. Phase 1 builds the helper incrementally, with tests first.

### Task 1.1: SnapshotInternal.path — storage path computation

**Files:**
- Create: `RetireSmartIRATests/SnapshotHelper.swift`
- Create: `RetireSmartIRATests/SnapshotHelperTests.swift`

- [ ] **Step 1: Create the test file with a failing test**

Create `RetireSmartIRATests/SnapshotHelperTests.swift`:

```swift
import XCTest
@testable import RetireSmartIRA  // not strictly needed yet, but keeps consistent with project style

final class SnapshotHelperTests: XCTestCase {
    func test_path_extractsTestClassFromFile_andComposesSnapshotsURL() {
        let path = SnapshotInternal.path(
            for: "BrandButton_primary_light",
            file: "/Users/anyuser/Projects/RetireSmartIRA/RetireSmartIRATests/BrandButtonSnapshotTests.swift"
        )
        XCTAssertTrue(
            path.path.hasSuffix("RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_primary_light.png"),
            "Expected suffix not found in path: \(path.path)"
        )
    }

    func test_path_handlesWorktreePathsWithDotClaude() {
        let path = SnapshotInternal.path(
            for: "X",
            file: "/Users/me/Projects/RetireSmartIRA/.claude/worktrees/foo/RetireSmartIRATests/Bar.swift"
        )
        XCTAssertTrue(
            path.path.hasSuffix("RetireSmartIRATests/__Snapshots__/Bar/X.png"),
            "Worktree path mishandled: \(path.path)"
        )
    }
}
```

- [ ] **Step 2: Create the helper file with empty signature**

Create `RetireSmartIRATests/SnapshotHelper.swift`:

```swift
//  SnapshotHelper.swift
//  RetireSmartIRATests
//
//  Homebrew snapshot testing for RetireSmartIRA.
//
//  Why this exists (and isn't swift-snapshot-testing):
//  - 1.8 attempted swift-snapshot-testing 1.16-1.18 and hit XCTest / Swift Testing
//    integration linker failures on Xcode 16. ~45 minutes burned, deferred to 1.9.
//  - This in-house helper has zero external dependencies — uses SwiftUI's built-in
//    ImageRenderer + XCTAttachment + CoreGraphics. No SPM, no linker risk.
//  - Storage path matches PointFree convention so a future migration (if their
//    Swift Testing integration stabilizes) is mechanical.
//  - See docs/superpowers/specs/2026-04-29-snapshot-testing-design.md for design.
//
//  Conventions:
//  - Render scale is hard-coded to 2.0 (Retina). Do not change without re-recording.
//  - Pixel-diff threshold is 0.01% (covers font-AA noise, catches color-token regressions).
//  - To re-record everything: set RECORD_SNAPSHOTS=1 in the test scheme env vars.
//  - To re-record one test: delete its PNG from __Snapshots__/.

import XCTest
import SwiftUI
import CoreGraphics

enum SnapshotInternal {
    /// Computes the baseline PNG URL from the calling test's #file and the snapshot name.
    /// Strategy: walk the file path, find the segment "RetireSmartIRATests", and anchor there.
    static func path(for name: String, file: StaticString) -> URL {
        // TODO: implement
        return URL(fileURLWithPath: "/dev/null")
    }
}
```

- [ ] **Step 3: Run the test, verify it fails**

```bash
xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/SnapshotHelperTests \
  -quiet 2>&1 | tail -30
```

Expected: tests fail with assertions about wrong path suffix. The build should succeed (it's the assertion that fails, not the compile).

- [ ] **Step 4: Implement `SnapshotInternal.path` minimally to pass**

Replace the `path` body in `SnapshotHelper.swift`:

```swift
    static func path(for name: String, file: StaticString) -> URL {
        let fileString = "\(file)"
        // Find the rightmost "RetireSmartIRATests/" — handles worktrees, symlinks, etc.
        guard let testsRange = fileString.range(of: "RetireSmartIRATests/", options: .backwards) else {
            fatalError("SnapshotInternal.path: file path \(fileString) does not contain 'RetireSmartIRATests/'")
        }
        // testClassName = filename without .swift suffix
        let afterTests = fileString[testsRange.upperBound...]
        let className = afterTests.replacingOccurrences(of: ".swift", with: "")
        // Compose: <prefix>RetireSmartIRATests/__Snapshots__/<className>/<name>.png
        let prefix = fileString[..<testsRange.upperBound]
        let composed = "\(prefix)__Snapshots__/\(className)/\(name).png"
        return URL(fileURLWithPath: composed)
    }
```

- [ ] **Step 5: Run the test, verify it passes**

```bash
xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/SnapshotHelperTests \
  -quiet 2>&1 | tail -10
```

Expected: `Test Suite 'SnapshotHelperTests' passed` with 2 tests passing.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRATests/SnapshotHelper.swift RetireSmartIRATests/SnapshotHelperTests.swift
git commit -m "Add SnapshotInternal.path: derive baseline URL from #file"
```

---

### Task 1.2: SnapshotInternal.render — ImageRenderer wrapper

**Files:**
- Modify: `RetireSmartIRATests/SnapshotHelper.swift`
- Modify: `RetireSmartIRATests/SnapshotHelperTests.swift`

- [ ] **Step 1: Add a failing test for `render`**

Append to `SnapshotHelperTests.swift` inside the existing class:

```swift
    @MainActor
    func test_render_producesNonEmptyImageAtScale2() {
        let view = Color.red.frame(width: 50, height: 30)
        let image = SnapshotInternal.render(view: view, size: nil)
        // Expected: 50pt × 30pt × scale 2.0 = 100×60 pixels
        XCTAssertEqual(image.width, 100, "Image width should be 100 (50pt × scale 2)")
        XCTAssertEqual(image.height, 60, "Image height should be 60 (30pt × scale 2)")
    }

    @MainActor
    func test_render_appliesExplicitSize() {
        let view = Color.blue
        let image = SnapshotInternal.render(view: view, size: CGSize(width: 200, height: 100))
        XCTAssertEqual(image.width, 400)   // 200 × 2
        XCTAssertEqual(image.height, 200)  // 100 × 2
    }
```

- [ ] **Step 2: Add the render stub to `SnapshotHelper.swift`**

Add inside `enum SnapshotInternal`:

```swift
    @MainActor
    static func render(view: some View, size: CGSize?) -> CGImage {
        fatalError("not yet implemented")
    }
```

- [ ] **Step 3: Run tests, verify failure**

```bash
xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/SnapshotHelperTests \
  -quiet 2>&1 | tail -15
```

Expected: tests crash with `fatalError`. Build succeeds.

- [ ] **Step 4: Implement `render` minimally**

Replace the stub:

```swift
    @MainActor
    static func render(view: some View, size: CGSize?) -> CGImage {
        let sized: AnyView = if let size {
            AnyView(view.frame(width: size.width, height: size.height))
        } else {
            AnyView(view)
        }
        let renderer = ImageRenderer(content: sized)
        renderer.scale = 2.0  // pinned for reproducibility
        guard let cgImage = renderer.cgImage else {
            fatalError("SnapshotInternal.render: ImageRenderer returned nil cgImage")
        }
        return cgImage
    }
```

- [ ] **Step 5: Run tests, verify pass**

Expected: 4 tests passing in `SnapshotHelperTests`.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRATests/SnapshotHelper.swift RetireSmartIRATests/SnapshotHelperTests.swift
git commit -m "Add SnapshotInternal.render: ImageRenderer at fixed scale 2.0"
```

---

### Task 1.3: SnapshotInternal.compare — pixel diff with tolerance

**Files:**
- Modify: `RetireSmartIRATests/SnapshotHelper.swift`
- Modify: `RetireSmartIRATests/SnapshotHelperTests.swift`

- [ ] **Step 1: Add failing tests for `compare`**

Append to `SnapshotHelperTests`:

```swift
    @MainActor
    func test_compare_identicalImagesProduceZeroDiff() {
        let view = Color.red.frame(width: 20, height: 20)
        let img1 = SnapshotInternal.render(view: view, size: nil)
        let img2 = SnapshotInternal.render(view: view, size: nil)
        let result = SnapshotInternal.compare(actual: img1, expected: img2)
        XCTAssertEqual(result.diffPercent, 0.0, accuracy: 0.0001)
    }

    @MainActor
    func test_compare_completelyDifferentImagesProduce100PercentDiff() {
        let red = SnapshotInternal.render(view: Color.red.frame(width: 20, height: 20), size: nil)
        let blue = SnapshotInternal.render(view: Color.blue.frame(width: 20, height: 20), size: nil)
        let result = SnapshotInternal.compare(actual: red, expected: blue)
        XCTAssertGreaterThan(result.diffPercent, 0.99,
            "Red vs blue should be ~100% different, got \(result.diffPercent)")
    }

    @MainActor
    func test_compare_diffImageHasSameDimensionsAsInputs() {
        let img1 = SnapshotInternal.render(view: Color.red.frame(width: 20, height: 20), size: nil)
        let img2 = SnapshotInternal.render(view: Color.green.frame(width: 20, height: 20), size: nil)
        let result = SnapshotInternal.compare(actual: img1, expected: img2)
        XCTAssertEqual(result.diffImage.width, img1.width)
        XCTAssertEqual(result.diffImage.height, img1.height)
    }
```

- [ ] **Step 2: Add stubs for `compare` and `DiffResult`**

Add inside `enum SnapshotInternal`:

```swift
    struct DiffResult {
        let diffPercent: Double  // 0.0 to 1.0
        let diffImage: CGImage   // red-tinted XOR; transparent where equal
    }

    static func compare(actual: CGImage, expected: CGImage) -> DiffResult {
        fatalError("not yet implemented")
    }
```

- [ ] **Step 3: Run tests, verify failure**

Expected: 3 new tests crash with `fatalError`.

- [ ] **Step 4: Implement `compare` with byte-buffer pixel diff**

Replace the stub. Add a private helper for byte buffer extraction:

```swift
    static func compare(actual: CGImage, expected: CGImage) -> DiffResult {
        precondition(actual.width == expected.width && actual.height == expected.height,
                     "compare: images must have same dimensions")

        let width = actual.width
        let height = actual.height
        let pixelCount = width * height

        let actualBytes = Self.rgba8Buffer(from: actual)
        let expectedBytes = Self.rgba8Buffer(from: expected)

        var diffMask = [UInt8](repeating: 0, count: pixelCount)
        var differingCount = 0

        for i in 0..<pixelCount {
            let base = i * 4
            // Per-channel tolerance: treat values within ±1 as equal (sub-pixel rounding).
            let dr = abs(Int(actualBytes[base]) - Int(expectedBytes[base]))
            let dg = abs(Int(actualBytes[base + 1]) - Int(expectedBytes[base + 1]))
            let db = abs(Int(actualBytes[base + 2]) - Int(expectedBytes[base + 2]))
            let da = abs(Int(actualBytes[base + 3]) - Int(expectedBytes[base + 3]))
            if dr > 1 || dg > 1 || db > 1 || da > 1 {
                diffMask[i] = 1
                differingCount += 1
            }
        }

        let diffPercent = Double(differingCount) / Double(pixelCount)
        let diffImage = Self.makeDiffImage(mask: diffMask, width: width, height: height)
        return DiffResult(diffPercent: diffPercent, diffImage: diffImage)
    }

    /// Extract a packed RGBA8 byte buffer from a CGImage, normalizing format.
    private static func rgba8Buffer(from image: CGImage) -> [UInt8] {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            fatalError("rgba8Buffer: failed to create CGContext")
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    /// Build a red-tinted diff image from the differing-pixel mask.
    /// Where mask[i] == 1, pixel = (255, 0, 0, 200). Else (0, 0, 0, 0).
    private static func makeDiffImage(mask: [UInt8], width: Int, height: Int) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<mask.count where mask[i] == 1 {
            let base = i * 4
            bytes[base] = 255      // R
            bytes[base + 1] = 0    // G
            bytes[base + 2] = 0    // B
            bytes[base + 3] = 200  // A
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let image = ctx.makeImage() else {
            fatalError("makeDiffImage: failed to construct diff CGImage")
        }
        return image
    }
```

- [ ] **Step 5: Run tests, verify pass**

Expected: 7 tests passing.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRATests/SnapshotHelper.swift RetireSmartIRATests/SnapshotHelperTests.swift
git commit -m "Add SnapshotInternal.compare: byte-buffer pixel diff with red-tint diff image"
```

---

### Task 1.4: SnapshotInternal.write / load — PNG file I/O

**Files:**
- Modify: `RetireSmartIRATests/SnapshotHelper.swift`
- Modify: `RetireSmartIRATests/SnapshotHelperTests.swift`

- [ ] **Step 1: Add failing tests for write/load round-trip**

Append to `SnapshotHelperTests`:

```swift
    @MainActor
    func test_writeAndLoad_roundTripsAnImage() throws {
        let original = SnapshotInternal.render(view: Color.purple.frame(width: 20, height: 20), size: nil)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-roundtrip-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        try SnapshotInternal.write(original, to: tmpURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpURL.path))

        let loaded = try XCTUnwrap(SnapshotInternal.load(from: tmpURL))
        let result = SnapshotInternal.compare(actual: original, expected: loaded)
        XCTAssertEqual(result.diffPercent, 0.0, accuracy: 0.0001,
                       "PNG round-trip should be lossless for solid color")
    }

    func test_load_returnsNilForMissingFile() {
        let missing = URL(fileURLWithPath: "/tmp/definitely-does-not-exist-\(UUID()).png")
        XCTAssertNil(SnapshotInternal.load(from: missing))
    }

    @MainActor
    func test_write_createsIntermediateDirectories() throws {
        let img = SnapshotInternal.render(view: Color.gray.frame(width: 10, height: 10), size: nil)
        let baseTmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("nested-\(UUID().uuidString)")
        let nested = baseTmp.appendingPathComponent("a/b/c/file.png")
        defer { try? FileManager.default.removeItem(at: baseTmp) }

        try SnapshotInternal.write(img, to: nested)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }
```

- [ ] **Step 2: Add stubs for write/load**

Inside `enum SnapshotInternal`:

```swift
    static func write(_ image: CGImage, to url: URL) throws {
        fatalError("not yet implemented")
    }

    static func load(from url: URL) -> CGImage? {
        fatalError("not yet implemented")
    }
```

- [ ] **Step 3: Run tests, verify failure**

Expected: 3 new tests crash with `fatalError`.

- [ ] **Step 4: Implement write/load**

Replace stubs. Add `import ImageIO` to the imports at top of file:

```swift
import XCTest
import SwiftUI
import CoreGraphics
import ImageIO       // NEW
import UniformTypeIdentifiers  // NEW (UTType.png)
```

Then:

```swift
    static func write(_ image: CGImage, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "SnapshotInternal", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create CGImageDestination at \(url.path)"])
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "SnapshotInternal", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "CGImageDestinationFinalize failed for \(url.path)"])
        }
    }

    static func load(from url: URL) -> CGImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
```

- [ ] **Step 5: Run tests, verify pass**

Expected: 10 tests passing.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRATests/SnapshotHelper.swift RetireSmartIRATests/SnapshotHelperTests.swift
git commit -m "Add SnapshotInternal.write/load: PNG round-trip via ImageIO"
```

---

### Task 1.5: Public `assertSnapshot` — record mode (missing baseline)

**Files:**
- Modify: `RetireSmartIRATests/SnapshotHelper.swift`
- Modify: `RetireSmartIRATests/SnapshotHelperTests.swift`

- [ ] **Step 1: Add a failing integration test for record-mode**

Append to `SnapshotHelperTests`:

```swift
    @MainActor
    func test_recordOrCompare_writesBaselineWhenMissing() {
        // recordOrCompare takes a baseline URL directly, so we don't need to spoof #file.
        // Path-from-file logic is already covered by Task 1.1's tests.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("record-mode-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let baselinePath = tmpDir.appendingPathComponent("baseline.png")

        XCTAssertFalse(FileManager.default.fileExists(atPath: baselinePath.path))

        var observed: SnapshotInternal.Outcome?
        SnapshotInternal.recordOrCompare(
            view: Color.orange.frame(width: 10, height: 10),
            size: nil,
            baselinePath: baselinePath,
            forceRecord: false
        ) { outcome, _ in observed = outcome }

        XCTAssertTrue(FileManager.default.fileExists(atPath: baselinePath.path),
                      "Baseline should have been recorded at \(baselinePath.path)")
        if case .recordedBaseline = observed {} else {
            XCTFail("Expected .recordedBaseline outcome, got \(String(describing: observed))")
        }
    }

    @MainActor
    func test_recordOrCompare_writesBaselineWhenForceRecordTrue() {
        // forceRecord overrides existence check.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("record-force-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let baselinePath = tmpDir.appendingPathComponent("baseline.png")

        // Pre-populate with a known baseline so forceRecord must overwrite it.
        let firstView = Color.purple.frame(width: 10, height: 10)
        try? SnapshotInternal.write(SnapshotInternal.render(view: firstView, size: nil), to: baselinePath)
        let firstSize = (try? Data(contentsOf: baselinePath))?.count ?? 0
        XCTAssertGreaterThan(firstSize, 0)

        // Force-record a different view; baseline should be overwritten.
        var observed: SnapshotInternal.Outcome?
        SnapshotInternal.recordOrCompare(
            view: Color.green.frame(width: 50, height: 50),
            size: nil,
            baselinePath: baselinePath,
            forceRecord: true
        ) { outcome, _ in observed = outcome }

        if case .recordedBaseline = observed {} else {
            XCTFail("Expected .recordedBaseline outcome under forceRecord, got \(String(describing: observed))")
        }
        // New PNG should be a different size (different dimensions)
        let secondSize = (try? Data(contentsOf: baselinePath))?.count ?? 0
        XCTAssertNotEqual(firstSize, secondSize, "Baseline should have been overwritten")
    }
```

Note the design decision: `assertSnapshot` is a thin wrapper that calls `XCTFail`, but the *logic* (decide record vs compare, render, write, diff) lives in `SnapshotInternal.recordOrCompare(...)` which takes a closure for diagnostics. This makes the integration testable without firing real XCTFail.

- [ ] **Step 2: Add stub for `recordOrCompare` and `assertSnapshot`**

Add inside `enum SnapshotInternal`:

```swift
    enum Outcome {
        case recordedBaseline(URL)
        case match
        case mismatch(diffPercent: Double, attachments: [XCTAttachment])
    }

    @MainActor
    static func recordOrCompare(
        view: some View,
        size: CGSize?,
        baselinePath: URL,
        forceRecord: Bool,
        report: (Outcome, _ message: String) -> Void
    ) {
        fatalError("not yet implemented")
    }
```

And at file scope (outside `enum SnapshotInternal`):

```swift
@MainActor
func assertSnapshot(
    of view: some View,
    named name: String,
    size: CGSize? = nil,
    record: Bool = false,
    file: StaticString = #file,
    line: UInt = #line
) {
    let baselinePath = SnapshotInternal.path(for: name, file: file)
    SnapshotInternal.recordOrCompare(
        view: view,
        size: size,
        baselinePath: baselinePath,
        forceRecord: record || ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
    ) { outcome, message in
        switch outcome {
        case .recordedBaseline:
            XCTFail(message, file: file, line: line)
        case .match:
            break  // pass silently
        case .mismatch(_, let attachments):
            for att in attachments {
                XCTContext.runActivity(named: "Snapshot diff: \(name)") { activity in
                    activity.add(att)
                }
            }
            XCTFail(message, file: file, line: line)
        }
    }
}
```

- [ ] **Step 3: Run tests, verify failure**

Expected: new test crashes with `fatalError` from `recordOrCompare` stub.

- [ ] **Step 4: Implement `recordOrCompare` for the record-mode branch only**

Replace the stub:

```swift
    @MainActor
    static func recordOrCompare(
        view: some View,
        size: CGSize?,
        baselinePath: URL,
        forceRecord: Bool,
        report: (Outcome, _ message: String) -> Void
    ) {
        let actual = render(view: view, size: size)
        let baselineExists = FileManager.default.fileExists(atPath: baselinePath.path)

        if forceRecord || !baselineExists {
            do {
                try write(actual, to: baselinePath)
                report(.recordedBaseline(baselinePath),
                       "Recorded baseline at \(baselinePath.path)")
            } catch {
                report(.recordedBaseline(baselinePath),
                       "FAILED to write baseline at \(baselinePath.path): \(error)")
            }
            return
        }

        // Compare path: stub for next task
        report(.match, "")
    }
```

- [ ] **Step 5: Run tests, verify pass**

Expected: 12 tests passing in `SnapshotHelperTests` (10 from prior tasks + 2 new).

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRATests/SnapshotHelper.swift RetireSmartIRATests/SnapshotHelperTests.swift
git commit -m "Add assertSnapshot + recordOrCompare with record-mode branch"
```

---

### Task 1.6: `recordOrCompare` — compare-mode branches (match + mismatch)

**Files:**
- Modify: `RetireSmartIRATests/SnapshotHelper.swift`
- Modify: `RetireSmartIRATests/SnapshotHelperTests.swift`

- [ ] **Step 1: Add failing tests for match and mismatch outcomes**

Append to `SnapshotHelperTests`:

```swift
    @MainActor
    func test_recordOrCompare_returnsMatchWhenIdentical() throws {
        // Pre-record a baseline manually
        let view = Color.red.frame(width: 10, height: 10)
        let img = SnapshotInternal.render(view: view, size: nil)
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("compare-match-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let baselinePath = tmpDir.appendingPathComponent("RetireSmartIRATests/__Snapshots__/X/test.png")
        try SnapshotInternal.write(img, to: baselinePath)

        var observed: SnapshotInternal.Outcome?
        SnapshotInternal.recordOrCompare(
            view: view,
            size: nil,
            baselinePath: baselinePath,
            forceRecord: false
        ) { outcome, _ in observed = outcome }

        if case .match = observed {} else {
            XCTFail("Expected .match, got \(String(describing: observed))")
        }
    }

    @MainActor
    func test_recordOrCompare_returnsMismatchWhenDifferent() throws {
        // Pre-record red baseline; render blue; expect mismatch with attachments.
        let red = Color.red.frame(width: 10, height: 10)
        let blue = Color.blue.frame(width: 10, height: 10)
        let redImg = SnapshotInternal.render(view: red, size: nil)
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("compare-mismatch-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let baselinePath = tmpDir.appendingPathComponent("RetireSmartIRATests/__Snapshots__/X/test.png")
        try SnapshotInternal.write(redImg, to: baselinePath)

        var observed: SnapshotInternal.Outcome?
        SnapshotInternal.recordOrCompare(
            view: blue,
            size: nil,
            baselinePath: baselinePath,
            forceRecord: false
        ) { outcome, _ in observed = outcome }

        guard case let .mismatch(diffPct, attachments) = observed else {
            XCTFail("Expected .mismatch, got \(String(describing: observed))")
            return
        }
        XCTAssertGreaterThan(diffPct, 0.5, "Red vs blue should be very different")
        XCTAssertEqual(attachments.count, 3, "Expected actual + expected + diff attachments")
    }

    @MainActor
    func test_recordOrCompare_returnsMatchWhenWithinTolerance() throws {
        // Identical render — should be exact match (0 diff), well within 0.01% threshold.
        let view = Color(red: 0.5, green: 0.5, blue: 0.5).frame(width: 50, height: 50)
        let img = SnapshotInternal.render(view: view, size: nil)
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("compare-tolerance-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let baselinePath = tmpDir.appendingPathComponent("RetireSmartIRATests/__Snapshots__/X/test.png")
        try SnapshotInternal.write(img, to: baselinePath)

        var observed: SnapshotInternal.Outcome?
        SnapshotInternal.recordOrCompare(
            view: view,
            size: nil,
            baselinePath: baselinePath,
            forceRecord: false
        ) { outcome, _ in observed = outcome }

        if case .match = observed {} else {
            XCTFail("Expected .match for identical re-render, got \(String(describing: observed))")
        }
    }
```

- [ ] **Step 2: Run tests, verify failure**

Expected: 3 new tests fail (the stub returns `.match` unconditionally, so the mismatch test fails; the match tests may pass spuriously, which is fine).

- [ ] **Step 3: Implement the compare-mode branches**

Replace the body of `recordOrCompare` after the record branch:

```swift
        // Compare path
        guard let expected = load(from: baselinePath) else {
            report(.recordedBaseline(baselinePath),
                   "Baseline file disappeared between existence check and load: \(baselinePath.path)")
            return
        }

        guard actual.width == expected.width && actual.height == expected.height else {
            report(.mismatch(diffPercent: 1.0, attachments: makeAttachments(actual: actual, expected: expected, diff: nil)),
                   "Snapshot dimensions changed: baseline \(expected.width)x\(expected.height), actual \(actual.width)x\(actual.height) — delete baseline to re-record")
            return
        }

        let diff = compare(actual: actual, expected: expected)
        let threshold = 0.0001  // 0.01% per spec §4
        if diff.diffPercent <= threshold {
            report(.match, "")
        } else {
            let pctStr = String(format: "%.4f", diff.diffPercent * 100)
            report(
                .mismatch(diffPercent: diff.diffPercent,
                          attachments: makeAttachments(actual: actual, expected: expected, diff: diff.diffImage)),
                "Snapshot mismatch: \(pctStr)% pixels differ (threshold: 0.01%) at \(baselinePath.path)"
            )
        }
    }

    static func makeAttachments(actual: CGImage, expected: CGImage, diff: CGImage?) -> [XCTAttachment] {
        var atts: [XCTAttachment] = []

        let nsActual = NSImage(cgImage: actual, size: NSSize(width: actual.width, height: actual.height))
        let actualAtt = XCTAttachment(image: nsActual)
        actualAtt.name = "actual.png"
        actualAtt.lifetime = .keepAlways
        atts.append(actualAtt)

        let nsExpected = NSImage(cgImage: expected, size: NSSize(width: expected.width, height: expected.height))
        let expectedAtt = XCTAttachment(image: nsExpected)
        expectedAtt.name = "expected.png"
        expectedAtt.lifetime = .keepAlways
        atts.append(expectedAtt)

        if let diff {
            let nsDiff = NSImage(cgImage: diff, size: NSSize(width: diff.width, height: diff.height))
            let diffAtt = XCTAttachment(image: nsDiff)
            diffAtt.name = "diff.png"
            diffAtt.lifetime = .keepAlways
            atts.append(diffAtt)
        }
        return atts
    }
```

Add `import AppKit` to the imports at the top of `SnapshotHelper.swift` if not already present (`NSImage` and `NSSize` live there; XCTest pulls AppKit in transitively on macOS, but be explicit):

```swift
import AppKit
```

- [ ] **Step 4: Run tests, verify pass**

Expected: 15 tests passing (12 from prior tasks + 3 new).

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRATests/SnapshotHelper.swift RetireSmartIRATests/SnapshotHelperTests.swift
git commit -m "Add compare-mode branches to recordOrCompare with XCTAttachment diff bundle"
```

---

### Task 1.7: Verify full helper end-to-end

**Files:**
- Modify: `RetireSmartIRATests/SnapshotHelperTests.swift`

- [ ] **Step 1: Add an end-to-end smoke test using `recordOrCompare` directly**

Append to `SnapshotHelperTests`:

```swift
    /// End-to-end test exercising the record-then-verify cycle. Uses recordOrCompare
    /// directly (not the public assertSnapshot) so we don't fire real XCTFail during
    /// the recording phase. This test should always pass.
    @MainActor
    func test_recordOrCompare_endToEnd_recordThenVerify() {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let baselinePath = tmpDir.appendingPathComponent("baseline.png")

        let view = Color.cyan.frame(width: 30, height: 30)

        // First call: no baseline exists → records and reports .recordedBaseline.
        var firstOutcome: SnapshotInternal.Outcome?
        SnapshotInternal.recordOrCompare(
            view: view, size: nil, baselinePath: baselinePath, forceRecord: false
        ) { outcome, _ in firstOutcome = outcome }

        if case .recordedBaseline = firstOutcome {} else {
            XCTFail("First call should have recorded baseline, got \(String(describing: firstOutcome))")
        }

        // Second call: baseline exists, identical render → reports .match.
        var secondOutcome: SnapshotInternal.Outcome?
        SnapshotInternal.recordOrCompare(
            view: view, size: nil, baselinePath: baselinePath, forceRecord: false
        ) { outcome, _ in secondOutcome = outcome }

        if case .match = secondOutcome {} else {
            XCTFail("Second call should have matched, got \(String(describing: secondOutcome))")
        }
    }
```

- [ ] **Step 2: Run tests, verify pass**

Expected: 16 tests passing in `SnapshotHelperTests`.

- [ ] **Step 3: Run full test suite, verify no existing test regressions**

```bash
xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -quiet 2>&1 | tail -20
```

Expected: all 670+ existing tests still pass + 16 new helper tests = 686+ tests, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add RetireSmartIRATests/SnapshotHelperTests.swift
git commit -m "Add end-to-end smoke test for assertSnapshot record-then-verify cycle"
```

---

## Phase 2 — Component snapshot tests

Each task creates one snapshot test class, records baselines under `RECORD_SNAPSHOTS=1`, visually reviews each PNG against Xcode's `#Preview` rendering, then commits both the test file and PNGs.

### Task 2.1: BrandButton snapshot tests (12 baselines)

**Files:**
- Create: `RetireSmartIRATests/BrandButtonSnapshotTests.swift`
- Create: 12 PNG baselines in `RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/`

- [ ] **Step 1: Create the test file**

Create `RetireSmartIRATests/BrandButtonSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import RetireSmartIRA

@MainActor
final class BrandButtonSnapshotTests: XCTestCase {
    // MARK: - Primary
    func test_primary_light() {
        let view = BrandButton(title: "Convert", style: .primary, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_primary_light")
    }
    func test_primary_dark() {
        let view = BrandButton(title: "Convert", style: .primary, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_primary_dark")
    }

    // MARK: - Secondary
    func test_secondary_light() {
        let view = BrandButton(title: "Cancel", style: .secondary, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_secondary_light")
    }
    func test_secondary_dark() {
        let view = BrandButton(title: "Cancel", style: .secondary, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_secondary_dark")
    }

    // MARK: - Tertiary Utility
    func test_tertiaryUtility_light() {
        let view = BrandButton(title: "Reset", style: .tertiaryUtility, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_tertiaryUtility_light")
    }
    func test_tertiaryUtility_dark() {
        let view = BrandButton(title: "Reset", style: .tertiaryUtility, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_tertiaryUtility_dark")
    }

    // MARK: - Tertiary Forward
    func test_tertiaryForward_light() {
        let view = BrandButton(title: "View breakdown", style: .tertiaryForward, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_tertiaryForward_light")
    }
    func test_tertiaryForward_dark() {
        let view = BrandButton(title: "View breakdown", style: .tertiaryForward, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_tertiaryForward_dark")
    }

    // MARK: - Destructive Secondary
    func test_destructiveSecondary_light() {
        let view = BrandButton(title: "Delete", style: .destructiveSecondary, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_destructiveSecondary_light")
    }
    func test_destructiveSecondary_dark() {
        let view = BrandButton(title: "Delete", style: .destructiveSecondary, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_destructiveSecondary_dark")
    }

    // MARK: - Destructive Primary
    func test_destructivePrimary_light() {
        let view = BrandButton(title: "Yes, delete forever", style: .destructivePrimary, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_destructivePrimary_light")
    }
    func test_destructivePrimary_dark() {
        let view = BrandButton(title: "Yes, delete forever", style: .destructivePrimary, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_destructivePrimary_dark")
    }
}
```

The dark-mode tests add `.background(Color.UI.surfaceApp)` so the dark canvas is captured in the PNG (otherwise `ImageRenderer` produces a transparent background and dark mode looks identical to light mode in the snapshot).

- [ ] **Step 2: Record baselines via `RECORD_SNAPSHOTS=1`**

```bash
RECORD_SNAPSHOTS=1 xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/BrandButtonSnapshotTests \
  -quiet 2>&1 | tail -20
```

Expected: all 12 tests "fail" with "Recorded baseline at ..." messages. 12 PNGs now exist in `RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/`.

- [ ] **Step 3: Visually inspect each baseline PNG**

```bash
ls -la RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/
open RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/*.png
```

For each PNG, verify against the matching `#Preview` in `RetireSmartIRA/Theme/Components/BrandButton.swift`:
- Primary: filled brand teal, white text
- Secondary: clear fill, brand teal border, brand teal text
- Tertiary Utility: clear fill, gray text
- Tertiary Forward: clear fill, brand teal text
- Destructive Secondary: clear fill, red border, red text
- Destructive Primary: filled red, white text

In dark mode, all colors should shift to their dark variants (per `ColorTokens+UI.swift`).

If any PNG looks wrong, the underlying component is broken — not the snapshot test. Stop, debug the component, then proceed.

- [ ] **Step 4: Re-run without record env var, verify all pass**

```bash
xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/BrandButtonSnapshotTests \
  -quiet 2>&1 | tail -10
```

Expected: all 12 tests pass.

- [ ] **Step 5: Commit test file and baselines together**

```bash
git add RetireSmartIRATests/BrandButtonSnapshotTests.swift \
        RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/
git commit -m "Add BrandButton snapshot tests with 12 baselines"
```

---

### Task 2.2: MetricCard snapshot tests (6 baselines)

**Files:**
- Create: `RetireSmartIRATests/MetricCardSnapshotTests.swift`
- Create: 6 PNG baselines in `RetireSmartIRATests/__Snapshots__/MetricCardSnapshotTests/`

- [ ] **Step 1: Create the test file**

Create `RetireSmartIRATests/MetricCardSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import RetireSmartIRA

@MainActor
final class MetricCardSnapshotTests: XCTestCase {
    // MARK: - Informational (default)
    func test_informational_light() {
        let view = MetricCard(label: "Total Tax", value: "$12,847", delta: "+$1,240 vs 2025")
            .frame(width: 240)
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "MetricCard_informational_light")
    }
    func test_informational_dark() {
        let view = MetricCard(label: "Total Tax", value: "$12,847", delta: "+$1,240 vs 2025")
            .frame(width: 240)
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "MetricCard_informational_dark")
    }

    // MARK: - Action Required (amber)
    func test_actionRequired_light() {
        let view = MetricCard(
            label: "Q2 Estimated",
            value: "$3,212",
            delta: "Due Jun 15",
            deltaIsAmber: true,
            category: .actionRequired,
            badge: .due
        )
        .frame(width: 240)
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "MetricCard_actionRequired_light")
    }
    func test_actionRequired_dark() {
        let view = MetricCard(
            label: "Q2 Estimated",
            value: "$3,212",
            delta: "Due Jun 15",
            deltaIsAmber: true,
            category: .actionRequired,
            badge: .due
        )
        .frame(width: 240)
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "MetricCard_actionRequired_dark")
    }

    // MARK: - Error (red)
    func test_error_light() {
        let view = MetricCard(
            label: "ACA Subsidy",
            value: "$0",
            delta: "Cliff exceeded",
            category: .error,
            badge: .error
        )
        .frame(width: 240)
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "MetricCard_error_light")
    }
    func test_error_dark() {
        let view = MetricCard(
            label: "ACA Subsidy",
            value: "$0",
            delta: "Cliff exceeded",
            category: .error,
            badge: .error
        )
        .frame(width: 240)
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "MetricCard_error_dark")
    }
}
```

- [ ] **Step 2: Record baselines**

```bash
RECORD_SNAPSHOTS=1 xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/MetricCardSnapshotTests \
  -quiet 2>&1 | tail -15
```

Expected: 6 PNGs recorded in `__Snapshots__/MetricCardSnapshotTests/`.

- [ ] **Step 3: Visually inspect each PNG against the component's `#Preview`s in `MetricCard.swift`**

Verify:
- Informational: brand teal stripe (4pt) on top of white card
- Action Required: amber stripe; "Due Jun 15" delta in amber; DUE badge
- Error: red stripe; ERROR badge
- Dark variants use dark-mode card surface and matching stripe colors

If any PNG looks wrong, the component is broken. Fix component, delete PNG, re-record.

- [ ] **Step 4: Re-run without record env var, verify pass**

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRATests/MetricCardSnapshotTests.swift \
        RetireSmartIRATests/__Snapshots__/MetricCardSnapshotTests/
git commit -m "Add MetricCard snapshot tests with 6 baselines"
```

---

### Task 2.3: Badge snapshot tests (8 baselines)

**Files:**
- Create: `RetireSmartIRATests/BadgeSnapshotTests.swift`
- Create: 8 PNG baselines

- [ ] **Step 1: Create the test file**

Create `RetireSmartIRATests/BadgeSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import RetireSmartIRA

@MainActor
final class BadgeSnapshotTests: XCTestCase {
    // MARK: - Refund
    func test_refund_light() {
        let view = Badge(text: "REFUND", variant: .refund)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "Badge_refund_light")
    }
    func test_refund_dark() {
        let view = Badge(text: "REFUND", variant: .refund)
            .padding()
            .background(Color.UI.surfaceCard)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "Badge_refund_dark")
    }

    // MARK: - Due
    func test_due_light() {
        let view = Badge(text: "DUE", variant: .due)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "Badge_due_light")
    }
    func test_due_dark() {
        let view = Badge(text: "DUE", variant: .due)
            .padding()
            .background(Color.UI.surfaceCard)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "Badge_due_dark")
    }

    // MARK: - Error
    func test_error_light() {
        let view = Badge(text: "ERROR", variant: .error)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "Badge_error_light")
    }
    func test_error_dark() {
        let view = Badge(text: "ERROR", variant: .error)
            .padding()
            .background(Color.UI.surfaceCard)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "Badge_error_dark")
    }

    // MARK: - Neutral
    func test_neutral_light() {
        let view = Badge(text: "DRAFT", variant: .neutral)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "Badge_neutral_light")
    }
    func test_neutral_dark() {
        let view = Badge(text: "DRAFT", variant: .neutral)
            .padding()
            .background(Color.UI.surfaceCard)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "Badge_neutral_dark")
    }
}
```

- [ ] **Step 2: Record baselines**

```bash
RECORD_SNAPSHOTS=1 xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/BadgeSnapshotTests \
  -quiet 2>&1 | tail -15
```

- [ ] **Step 3: Visually inspect each PNG**

Verify against `Badge.swift` `#Preview`s:
- Refund: green text on light green tint
- Due: amber text on light amber tint
- Error: red text on light red tint
- Neutral: gray text on light gray tint
- Dark variants use the dark tint values from `ColorTokens+Semantic.swift`

- [ ] **Step 4: Re-run without record env var, verify pass**

Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRATests/BadgeSnapshotTests.swift \
        RetireSmartIRATests/__Snapshots__/BadgeSnapshotTests/
git commit -m "Add Badge snapshot tests with 8 baselines"
```

---

### Task 2.4: InfoButton snapshot tests (2 baselines)

**Files:**
- Create: `RetireSmartIRATests/InfoButtonSnapshotTests.swift`
- Create: 2 PNG baselines

- [ ] **Step 1: Create the test file**

Create `RetireSmartIRATests/InfoButtonSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import RetireSmartIRA

@MainActor
final class InfoButtonSnapshotTests: XCTestCase {
    func test_inline_light() {
        let view = HStack(spacing: 6) {
            Text("Primary Heir's Salary")
                .font(.system(size: 13))
            InfoButton {}
            Spacer()
        }
        .padding()
        .frame(width: 280)
        .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "InfoButton_inline_light")
    }

    func test_inline_dark() {
        let view = HStack(spacing: 6) {
            Text("Primary Heir's Salary")
                .font(.system(size: 13))
            InfoButton {}
            Spacer()
        }
        .padding()
        .frame(width: 280)
        .background(Color.UI.surfaceCard)
        .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "InfoButton_inline_dark")
    }
}
```

- [ ] **Step 2: Record baselines**

```bash
RECORD_SNAPSHOTS=1 xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/InfoButtonSnapshotTests \
  -quiet 2>&1 | tail -10
```

- [ ] **Step 3: Visually inspect both PNGs**

Verify against `InfoButton.swift` `#Preview`s:
- Filled `info.circle.fill` symbol at 16pt, brand teal color
- Inline with the label "Primary Heir's Salary"
- Dark variant: brand teal shifts to dark-mode value, text shifts to light-mode-on-dark

- [ ] **Step 4: Re-run without record env var, verify pass**

Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRATests/InfoButtonSnapshotTests.swift \
        RetireSmartIRATests/__Snapshots__/InfoButtonSnapshotTests/
git commit -m "Add InfoButton snapshot tests with 2 baselines"
```

---

## Phase 3 — Documentation

### Task 3.1: Theme/README.md helper documentation

**Files:**
- Modify: `RetireSmartIRA/Theme/README.md`

- [ ] **Step 1: Read the existing README to find the right insertion point**

```bash
sed -n '1,60p' RetireSmartIRA/Theme/README.md
```

Identify where to insert a new "Snapshot testing" section. If a "Testing" section already exists, append to it. Otherwise, add a new section near the bottom (before any "Future" / "Out of scope" section).

- [ ] **Step 2: Add the snapshot-testing section**

Use the `Edit` tool to add the following section to `RetireSmartIRA/Theme/README.md` (adjust insertion point per Step 1):

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRA/Theme/README.md
git commit -m "Document snapshot testing in Theme/README.md"
```

---

## Phase 4 — Validation

### Task 4.1: Final verification

**Files:** N/A (verification only)

- [ ] **Step 1: Confirm `project.pbxproj` is unchanged from session start**

```bash
git status RetireSmartIRA.xcodeproj/project.pbxproj
```

Expected: `M RetireSmartIRA.xcodeproj/project.pbxproj` (the pre-existing change from session start, not from this work). If our changes have modified the pbxproj, that's a regression — `fileSystemSynchronizedGroups` should have made manual edits unnecessary.

- [ ] **Step 2: Run the full test suite**

```bash
xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -quiet 2>&1 | tail -25
```

Expected output:
- `** TEST SUCCEEDED **`
- Total tests run = baseline_count_from_Task_0.2 + 28 (component snapshots) + 16 (helper unit tests) = approximately **686+ tests**
- 0 failures

- [ ] **Step 3: Confirm baseline file count**

```bash
find RetireSmartIRATests/__Snapshots__ -name "*.png" | sort | wc -l
find RetireSmartIRATests/__Snapshots__ -name "*.png" | sort
```

Expected: `28` PNGs total. List should match:

```
RetireSmartIRATests/__Snapshots__/BadgeSnapshotTests/Badge_due_dark.png
RetireSmartIRATests/__Snapshots__/BadgeSnapshotTests/Badge_due_light.png
RetireSmartIRATests/__Snapshots__/BadgeSnapshotTests/Badge_error_dark.png
RetireSmartIRATests/__Snapshots__/BadgeSnapshotTests/Badge_error_light.png
RetireSmartIRATests/__Snapshots__/BadgeSnapshotTests/Badge_neutral_dark.png
RetireSmartIRATests/__Snapshots__/BadgeSnapshotTests/Badge_neutral_light.png
RetireSmartIRATests/__Snapshots__/BadgeSnapshotTests/Badge_refund_dark.png
RetireSmartIRATests/__Snapshots__/BadgeSnapshotTests/Badge_refund_light.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_destructivePrimary_dark.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_destructivePrimary_light.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_destructiveSecondary_dark.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_destructiveSecondary_light.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_primary_dark.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_primary_light.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_secondary_dark.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_secondary_light.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_tertiaryForward_dark.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_tertiaryForward_light.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_tertiaryUtility_dark.png
RetireSmartIRATests/__Snapshots__/BrandButtonSnapshotTests/BrandButton_tertiaryUtility_light.png
RetireSmartIRATests/__Snapshots__/InfoButtonSnapshotTests/InfoButton_inline_dark.png
RetireSmartIRATests/__Snapshots__/InfoButtonSnapshotTests/InfoButton_inline_light.png
RetireSmartIRATests/__Snapshots__/MetricCardSnapshotTests/MetricCard_actionRequired_dark.png
RetireSmartIRATests/__Snapshots__/MetricCardSnapshotTests/MetricCard_actionRequired_light.png
RetireSmartIRATests/__Snapshots__/MetricCardSnapshotTests/MetricCard_error_dark.png
RetireSmartIRATests/__Snapshots__/MetricCardSnapshotTests/MetricCard_error_light.png
RetireSmartIRATests/__Snapshots__/MetricCardSnapshotTests/MetricCard_informational_dark.png
RetireSmartIRATests/__Snapshots__/MetricCardSnapshotTests/MetricCard_informational_light.png
```

If the count is wrong or names mismatch, investigate before merging.

- [ ] **Step 4: Sanity-check regression detection works**

This is a one-shot manual confirmation that the helper actually catches regressions (don't commit this change).

```bash
# Temporarily change brand teal in ColorTokens+UI.swift, e.g. flip a hex digit
# Then re-run snapshot tests:
xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/BrandButtonSnapshotTests \
  -quiet 2>&1 | tail -20
```

Expected: many of the BrandButton snapshot tests fail with mismatch percentages and `actual.png`/`expected.png`/`diff.png` attachments visible in the Xcode test report (open the Report Navigator → click the failing test → expand attachments).

Then revert the change:

```bash
git checkout RetireSmartIRA/Theme/ColorTokens+UI.swift
```

Re-run, all green.

- [ ] **Step 5: Final commit log review**

```bash
git log --oneline 1.9/snapshot-testing-pass-1 ^main
```

Expected: roughly 11-13 commits, each one self-contained:
- Helper TDD commits (Tasks 1.1–1.7): ~7 commits
- Component snapshot commits (Tasks 2.1–2.4): 4 commits
- Documentation commit (Task 3.1): 1 commit

If a commit looks too large or covers unrelated work, consider rebasing — but only if the user wants it; squashing isn't required to merge.

- [ ] **Step 6: PR-ready state confirmed**

Branch ready for PR. The PR body should reference:
- This plan (`docs/superpowers/plans/2026-04-29-snapshot-testing-pass-1.md`)
- The spec (`docs/superpowers/specs/2026-04-29-snapshot-testing-design.md`)
- Counts: 28 baselines, 16 helper unit tests, ~80-line homebrew helper, no SPM dependencies

---

## Out of scope for this plan (Pass 2)

These are explicitly handled by `docs/superpowers/plans/2026-04-29-snapshot-testing-pass-2.md` (to be written after Pass 1 ships):

- `SnapshotFixtures.swift` and any `DemoProfile` refactor
- 9 screen-level snapshot test files (Dashboard, TaxPlanning, RMD, LegacyImpact, SS, Accounts, IncomeSources, QuarterlyTax, Settings)
- 18 screen baselines

Don't drift into Pass 2 work while executing this plan. If a screen test seems easy to add, resist — Pass 2 has its own fixture-strategy decisions that benefit from being written with hindsight on Pass 1's actual behavior.

---

*End of plan.*
