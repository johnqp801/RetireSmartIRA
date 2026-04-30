import XCTest
import SwiftUI
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

    @MainActor
    func test_recordOrCompare_writesBaselineWhenMissing() {
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
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("record-force-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let baselinePath = tmpDir.appendingPathComponent("baseline.png")

        let firstView = Color.purple.frame(width: 10, height: 10)
        try? SnapshotInternal.write(SnapshotInternal.render(view: firstView, size: nil), to: baselinePath)
        let firstSize = (try? Data(contentsOf: baselinePath))?.count ?? 0
        XCTAssertGreaterThan(firstSize, 0)

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
        let secondSize = (try? Data(contentsOf: baselinePath))?.count ?? 0
        XCTAssertNotEqual(firstSize, secondSize, "Baseline should have been overwritten")
    }

    @MainActor
    func test_recordOrCompare_returnsMatchWhenIdentical() throws {
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
}
