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
