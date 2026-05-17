import XCTest
@testable import RetireSmartIRA

final class ACASubsidyBarThreeMarkerTests: XCTestCase {

    func testMarkerMode_NoBaseline_ReturnsOne() {
        let mode = ACASubsidyBar.markerMode(baselineMAGI: nil, afterPretaxMAGI: nil, currentMAGI: 80_000)
        XCTAssertEqual(mode, .one)
    }

    func testMarkerMode_BaselineEqualsCurrent_ReturnsOne() {
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 80_000, afterPretaxMAGI: nil, currentMAGI: 80_050)
        XCTAssertEqual(mode, .one)
    }

    func testMarkerMode_BaselineOnly_ReturnsTwoBeforeAfter() {
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 100_000, afterPretaxMAGI: nil, currentMAGI: 80_000)
        XCTAssertEqual(mode, .twoBeforeAfter)
    }

    func testMarkerMode_PretaxMatchesBaseline_FallsBackToTwo() {
        // pretax doesn't move MAGI → not a true cascade
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 100_000, afterPretaxMAGI: 100_000, currentMAGI: 80_000)
        XCTAssertEqual(mode, .twoBeforeAfter)
    }

    func testMarkerMode_PretaxMatchesCurrent_FallsBackToTwo() {
        // Roth doesn't move MAGI (only pretax active) → not a cascade
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 100_000, afterPretaxMAGI: 80_000, currentMAGI: 80_000)
        XCTAssertEqual(mode, .twoBeforeAfter)
    }

    func testMarkerMode_FullCascade_ReturnsThreeCascade() {
        // baseline 100K → pretax pushes to 80K → Roth pushes to 95K
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 100_000, afterPretaxMAGI: 80_000, currentMAGI: 95_000)
        XCTAssertEqual(mode, .threeCascade)
    }

    func testMarkerMode_TinyDifferences_BelowEpsilon_FallsBackToTwo() {
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 100_000, afterPretaxMAGI: 99_950, currentMAGI: 95_000)
        XCTAssertEqual(mode, .twoBeforeAfter)
    }
}
