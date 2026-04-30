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
}
