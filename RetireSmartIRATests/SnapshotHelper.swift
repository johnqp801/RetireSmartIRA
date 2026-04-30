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
import ImageIO
import UniformTypeIdentifiers

enum SnapshotInternal {
    /// Computes the baseline PNG URL from the calling test's #file and the snapshot name.
    /// Strategy: walk the file path, find the segment "RetireSmartIRATests", and anchor there.
    static func path(for name: String, file: StaticString) -> URL {
        let fileString = "\(file)"
        guard fileString.hasPrefix("/") else {
            fatalError("SnapshotInternal.path: #file resolved to a relative path '\(fileString)'. Ensure no BUILD_LIBRARY_FOR_DISTRIBUTION or path-remapping is active in the test target.")
        }
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

    struct DiffResult {
        let diffPercent: Double  // 0.0 to 1.0
        let diffImage: CGImage   // red-tinted XOR; transparent where equal
    }

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

    /// Loads a CGImage from a PNG file at the given URL.
    /// - Returns: nil if the file does not exist OR is unreadable/corrupt.
    ///   Callers that need to distinguish must check FileManager.fileExists separately.
    static func load(from url: URL) -> CGImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

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

    /// Build a red-tinted diff image from the differing-pixel mask.
    /// Where mask[i] == 1, pixel = pre-multiplied red at 78% alpha = (200, 0, 0, 200).
    /// (CGContext requires premultipliedLast for 8bpc RGBA — unpremultipliedLast is unsupported.)
    /// Else (0, 0, 0, 0). Visually identical to pure red at A=200, but format-valid.
    private static func makeDiffImage(mask: [UInt8], width: Int, height: Int) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<mask.count where mask[i] == 1 {
            let base = i * 4
            bytes[base] = 200      // R (premultiplied: 255 * 200/255 = 200)
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
}

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
