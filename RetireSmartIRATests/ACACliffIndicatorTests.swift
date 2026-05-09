import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ACACliffIndicatorTests: XCTestCase {

    // MARK: - Headroom state classification

    func testHeadroomState_GreenWhenWellUnderCliff() {
        XCTAssertEqual(ACACliffIndicator.headroomState(headroom: 25_000), .green)
    }

    func testHeadroomState_GreenAtBoundary20K() {
        // exactly $20,000.01 → green; $20,000 → yellow (boundary belongs to yellow)
        XCTAssertEqual(ACACliffIndicator.headroomState(headroom: 20_000.01), .green)
    }

    func testHeadroomState_YellowAtBoundary20K() {
        XCTAssertEqual(ACACliffIndicator.headroomState(headroom: 20_000), .yellow)
    }

    func testHeadroomState_YellowMidRange() {
        XCTAssertEqual(ACACliffIndicator.headroomState(headroom: 10_000), .yellow)
    }

    func testHeadroomState_YellowAtBoundary5K() {
        XCTAssertEqual(ACACliffIndicator.headroomState(headroom: 5_000.01), .yellow)
    }

    func testHeadroomState_RedAtBoundary5K() {
        XCTAssertEqual(ACACliffIndicator.headroomState(headroom: 5_000), .red)
    }

    func testHeadroomState_RedNearCliff() {
        XCTAssertEqual(ACACliffIndicator.headroomState(headroom: 1_000), .red)
    }

    func testHeadroomState_RedAtZero() {
        XCTAssertEqual(ACACliffIndicator.headroomState(headroom: 0), .red)
    }

    func testHeadroomState_CrossedJustOver() {
        XCTAssertEqual(ACACliffIndicator.headroomState(headroom: -1), .crossed)
    }

    func testHeadroomState_CrossedFarOver() {
        XCTAssertEqual(ACACliffIndicator.headroomState(headroom: -10_000), .crossed)
    }

    // MARK: - Equatable

    func testHeadroomState_Equatable() {
        XCTAssertEqual(ACACliffHeadroomState.green, ACACliffHeadroomState.green)
        XCTAssertNotEqual(ACACliffHeadroomState.green, ACACliffHeadroomState.yellow)
    }

    // MARK: - Rendering smoke tests

    @MainActor
    func testIndicator_RendersInAllFourStates() {
        // Smoke test — just verify each state renders without crash
        for (name, magi) in [
            ("green", 50_000.0),    // 34K headroom
            ("yellow", 75_000.0),   // 9K headroom
            ("red", 81_000.0),      // 3K headroom
            ("crossed", 90_000.0),  // -6K headroom
        ] {
            let view = ACACliffIndicator(
                cliffThreshold: 84_000,
                projectedMAGI: magi,
                lostSubsidyEstimate: 6_000
            )
            // Force materialization
            let _ = view.body
            XCTAssertNotNil(view, "ACACliffIndicator failed to render for state: \(name)")
        }
    }

    // MARK: - State property tests (visual chrome regression protection)

    func testGreenState_ColorIsGreen() {
        XCTAssertEqual(ACACliffHeadroomState.green.color, .green)
    }

    func testYellowState_ColorIsOrange() {
        // Yellow state uses .orange (better contrast than yellow on most backgrounds)
        XCTAssertEqual(ACACliffHeadroomState.yellow.color, .orange)
    }

    func testRedState_ColorIsRed() {
        XCTAssertEqual(ACACliffHeadroomState.red.color, .red)
    }

    func testCrossedState_ColorIsRed() {
        // crossed shares red with .red — extra emphasis comes from the banner
        XCTAssertEqual(ACACliffHeadroomState.crossed.color, .red)
    }

    // MARK: - State label tests

    func testGreenState_LabelIsClearOfCliff() {
        XCTAssertEqual(ACACliffHeadroomState.green.label, "Clear of cliff")
    }

    func testYellowState_LabelIsApproachingCliff() {
        XCTAssertEqual(ACACliffHeadroomState.yellow.label, "Approaching cliff")
    }

    func testRedState_LabelIsNearCliff() {
        XCTAssertEqual(ACACliffHeadroomState.red.label, "Near cliff")
    }

    func testCrossedState_LabelIsCliffCrossed() {
        XCTAssertEqual(ACACliffHeadroomState.crossed.label, "Cliff crossed")
    }

    // MARK: - All states distinct

    func testAllStateLabels_AreUnique() {
        let labels = [
            ACACliffHeadroomState.green.label,
            ACACliffHeadroomState.yellow.label,
            ACACliffHeadroomState.red.label,
            ACACliffHeadroomState.crossed.label
        ]
        XCTAssertEqual(Set(labels).count, 4, "Each state should have a unique label for accessibility")
    }

    // MARK: - Headroom-to-state at all key boundaries

    func testStateClassification_IsCompleteAndOrdered() {
        // Verify the threshold ordering is monotonic from crossed up to green
        let testCases: [(headroom: Double, expected: ACACliffHeadroomState)] = [
            (-100_000, .crossed),
            (-1, .crossed),
            (0, .red),
            (5_000, .red),
            (5_000.01, .yellow),
            (10_000, .yellow),
            (20_000, .yellow),
            (20_000.01, .green),
            (50_000, .green),
            (.greatestFiniteMagnitude, .green)
        ]
        for (headroom, expected) in testCases {
            XCTAssertEqual(
                ACACliffIndicator.headroomState(headroom: headroom),
                expected,
                "Headroom \(headroom) should classify as \(expected)"
            )
        }
    }
}
