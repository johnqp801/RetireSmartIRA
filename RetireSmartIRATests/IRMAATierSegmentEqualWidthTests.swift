import XCTest
@testable import RetireSmartIRA

final class IRMAATierSegmentEqualWidthTests: XCTestCase {

    // Segments: 6 tiers, equal-width. Each tier occupies 1/6 of the bar.
    // Given a MAGI inside tier i with linear position 0..1 within the tier,
    // the bar fraction is (i + intraFraction) / segmentCount.

    func testMarkerPosition_MidpointOfFirstTier() {
        let frac = IRMAATierBarLayout.markerFraction(
            magi: 50_000,
            tierIndex: 0,
            tierRangeStart: 0,
            tierRangeEnd: 100_000,
            segmentCount: 6
        )
        XCTAssertEqual(frac, 0.5 / 6.0, accuracy: 1e-6)
    }

    func testMarkerPosition_BoundaryAtTier1Start() {
        let frac = IRMAATierBarLayout.markerFraction(
            magi: 100_000,
            tierIndex: 1,
            tierRangeStart: 100_000,
            tierRangeEnd: 150_000,
            segmentCount: 6
        )
        XCTAssertEqual(frac, 1.0 / 6.0, accuracy: 1e-6)
    }

    func testMarkerPosition_MidpointOfTier3of6() {
        let frac = IRMAATierBarLayout.markerFraction(
            magi: 225_000,
            tierIndex: 2,
            tierRangeStart: 200_000,
            tierRangeEnd: 250_000,
            segmentCount: 6
        )
        XCTAssertEqual(frac, 2.5 / 6.0, accuracy: 1e-6)
    }

    func testMarkerPosition_MAGIBelowTierRange_ClampsToZeroInside() {
        let frac = IRMAATierBarLayout.markerFraction(
            magi: -100,
            tierIndex: 0,
            tierRangeStart: 0,
            tierRangeEnd: 100_000,
            segmentCount: 6
        )
        XCTAssertEqual(frac, 0.0, accuracy: 1e-6)
    }

    func testMarkerPosition_MAGIAboveTierRange_ClampsToOneInside() {
        let frac = IRMAATierBarLayout.markerFraction(
            magi: 200_000,
            tierIndex: 0,
            tierRangeStart: 0,
            tierRangeEnd: 100_000,
            segmentCount: 6
        )
        XCTAssertEqual(frac, 1.0 / 6.0, accuracy: 1e-6)
    }

    func testMarkerPosition_DegenerateRange_ReturnsTierStartFraction() {
        let frac = IRMAATierBarLayout.markerFraction(
            magi: 500_000,
            tierIndex: 5,
            tierRangeStart: 500_000,
            tierRangeEnd: 500_000,
            segmentCount: 6
        )
        XCTAssertEqual(frac, 5.0 / 6.0, accuracy: 1e-6)
    }
}
