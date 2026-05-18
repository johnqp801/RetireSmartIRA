//
//  StateBracketBarMarkerTests.swift
//  RetireSmartIRATests
//
//  Tests for BracketChartHelpers.bracketMarkerPosition — the pure-logic helper that
//  converts a dollar value into an x-offset on the equal-width state bracket bar.
//

import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class StateBracketBarMarkerTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a minimal BracketSegment for use in tests.
    private func seg(_ start: Double, _ end: Double) -> DashboardView.BracketSegment {
        DashboardView.BracketSegment(
            rate: 0.01,
            label: "1%",
            rangeStart: start,
            rangeEnd: end,
            isCurrent: false
        )
    }

    /// CA MFJ brackets (visible through 9.3% bracket, 6 segments).
    private var caMFJ6: [DashboardView.BracketSegment] {
        [
            seg(0,        20_824),   // idx 0: 1%
            seg(20_824,   49_368),   // idx 1: 2%
            seg(49_368,   77_918),   // idx 2: 4%
            seg(77_918,  108_162),   // idx 3: 6%
            seg(108_162, 136_700),   // idx 4: 8%
            seg(136_700, 698_274),   // idx 5: 9.3%
        ]
    }

    // MARK: - Within first bracket

    func testMarkerPosition_AtStart_IsZero() {
        // $0 is the very start of the first bracket → x = 0
        let barWidth: CGFloat = 600
        let x = BracketChartHelpers.bracketMarkerPosition(
            value: 0,
            segments: caMFJ6,
            barWidth: barWidth
        )
        XCTAssertEqual(x, 0, accuracy: 0.5)
    }

    func testMarkerPosition_MidFirstBracket() {
        // $10,412 is halfway through first CA MFJ bracket (0–20,824)
        // Expected: 0.5 * (barWidth / 6)
        let barWidth: CGFloat = 600
        let segW = barWidth / 6
        let expected = segW * 0.5  // idx 0, intra = 0.5
        let x = BracketChartHelpers.bracketMarkerPosition(
            value: 10_412,
            segments: caMFJ6,
            barWidth: barWidth
        )
        XCTAssertEqual(x, expected, accuracy: 1.0)
    }

    // MARK: - Within middle bracket

    func testMarkerPosition_WithinFourthBracket_8pct() {
        // $124,000 falls in 8% bracket (108,162–136,700), index 4
        // intra = (124000 - 108162) / (136700 - 108162) ≈ 0.555
        let barWidth: CGFloat = 600
        let segW = barWidth / 6
        let intra = (124_000.0 - 108_162.0) / (136_700.0 - 108_162.0)
        let expected = 4 * segW + CGFloat(intra) * segW
        let x = BracketChartHelpers.bracketMarkerPosition(
            value: 124_000,
            segments: caMFJ6,
            barWidth: barWidth
        )
        XCTAssertEqual(x, expected, accuracy: 1.0)
    }

    // MARK: - At a segment boundary

    func testMarkerPosition_AtBoundaryBetween3And4_LandsAtSegmentStart() {
        // $108,162 is the exact start of the 8% bracket (index 4)
        // Expected: exactly 4 * segW
        let barWidth: CGFloat = 600
        let segW = barWidth / 6
        let expected = 4 * segW
        let x = BracketChartHelpers.bracketMarkerPosition(
            value: 108_162,
            segments: caMFJ6,
            barWidth: barWidth
        )
        XCTAssertEqual(x, expected, accuracy: 0.5)
    }

    // MARK: - Above all brackets (clamp to right edge)

    func testMarkerPosition_AboveAllBrackets_ClampsToRightEdge() {
        // $5M is far past the last visible segment
        let barWidth: CGFloat = 600
        let x = BracketChartHelpers.bracketMarkerPosition(
            value: 5_000_000,
            segments: caMFJ6,
            barWidth: barWidth
        )
        // Should clamp to barWidth - 4
        XCTAssertEqual(x, barWidth - 4, accuracy: 0.5)
    }

    // MARK: - Edge cases

    func testMarkerPosition_EmptySegments_ReturnsZero() {
        let empty: [DashboardView.BracketSegment] = []
        let x = BracketChartHelpers.bracketMarkerPosition(
            value: 100_000,
            segments: empty,
            barWidth: 300
        )
        XCTAssertEqual(x, 0)
    }

    func testMarkerPosition_SingleSegment_Midpoint() {
        // Single-segment bar: value at midpoint → half of barWidth
        let segments = [seg(0, 100_000)]
        let barWidth: CGFloat = 300
        let x = BracketChartHelpers.bracketMarkerPosition(
            value: 50_000,
            segments: segments,
            barWidth: barWidth
        )
        XCTAssertEqual(x, barWidth / 2, accuracy: 0.5)
    }
}
