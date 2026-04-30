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
}
