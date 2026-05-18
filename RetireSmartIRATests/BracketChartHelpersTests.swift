import XCTest
@testable import RetireSmartIRA
import SwiftUI

// Test-only conforming type to verify BracketSegmentLike protocol
struct TestSegment: BracketSegmentLike {
    let rangeStart: Double
    let rangeEnd: Double
}

final class BracketChartHelpersTests: XCTestCase {
    private func segments() -> [TestSegment] {
        return [
            TestSegment(rangeStart: 0, rangeEnd: 23_850),
            TestSegment(rangeStart: 23_850, rangeEnd: 96_950),
            TestSegment(rangeStart: 96_950, rangeEnd: 206_700),
            TestSegment(rangeStart: 206_700, rangeEnd: 394_600)
        ]
    }

    func testValueAtStartOfFirstSegment_returnsZero() {
        let x = BracketChartHelpers.bracketMarkerPosition(value: 0, segments: segments(), barWidth: 400)
        XCTAssertEqual(x, 0, accuracy: 0.5)
    }

    func testValueMidFirstSegment_returnsMidOfFirstQuarter() {
        // 4 equal-width segments, so each = 100pt. Value 11_925 = 50% of segment 0.
        let x = BracketChartHelpers.bracketMarkerPosition(value: 11_925, segments: segments(), barWidth: 400)
        XCTAssertEqual(x, 50, accuracy: 0.5)
    }

    func testValueAtSegmentBoundary_returnsExactBoundary() {
        let x = BracketChartHelpers.bracketMarkerPosition(value: 23_850, segments: segments(), barWidth: 400)
        XCTAssertEqual(x, 100, accuracy: 0.5)
    }

    func testValuePastLastSegment_clampsToRightEdgeMinusFour() {
        let x = BracketChartHelpers.bracketMarkerPosition(value: 999_999_999, segments: segments(), barWidth: 400)
        XCTAssertEqual(x, 396, accuracy: 0.5)
    }

    func testEmptySegments_returnsZero() {
        let empty: [TestSegment] = []
        let x = BracketChartHelpers.bracketMarkerPosition(value: 50_000, segments: empty, barWidth: 400)
        XCTAssertEqual(x, 0, accuracy: 0.5)
    }

    func testZeroWidthSegmentDoesNotCrash() {
        let degenerate = [
            TestSegment(rangeStart: 0, rangeEnd: 100),
            TestSegment(rangeStart: 100, rangeEnd: 100),
            TestSegment(rangeStart: 100, rangeEnd: 200)
        ]
        let x = BracketChartHelpers.bracketMarkerPosition(value: 100, segments: degenerate, barWidth: 300)
        // Value 100 is at the start of segment 2 (third segment, so position 200 of 300)
        XCTAssertEqual(x, 200, accuracy: 0.5)
    }
}
