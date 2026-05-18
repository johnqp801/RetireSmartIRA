import XCTest
import SwiftUI
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

    // MARK: - M6 — Boundary tests around the $100 epsilon

    func testMarkerMode_PretaxLegExactly100_IsTreatedAsNoMovement() {
        // Boundary: a delta of exactly $100 is NOT > epsilon (strict inequality in implementation),
        // so the pretax leg is treated as "no movement" and the cascade falls back to two markers.
        // Setup: baseline 100_100, pretax 100_000 (delta=100), current 90_000 (delta from pretax=10_000).
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 100_100, afterPretaxMAGI: 100_000, currentMAGI: 90_000)
        XCTAssertEqual(mode, .twoBeforeAfter, "Delta of exactly $100 should not trigger threeCascade")
    }

    func testMarkerMode_PretaxLegExactly101_TriggersThreeCascade() {
        // One dollar above the boundary: leg is now > epsilon and cascade should engage.
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 100_101, afterPretaxMAGI: 100_000, currentMAGI: 90_000)
        XCTAssertEqual(mode, .threeCascade, "Delta of $101 should trigger threeCascade")
    }

    func testMarkerMode_PretaxLegExactly99_BelowBoundary_FallsBackToTwo() {
        // One dollar below the boundary: matches the $100 case (still no movement).
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 100_099, afterPretaxMAGI: 100_000, currentMAGI: 90_000)
        XCTAssertEqual(mode, .twoBeforeAfter, "Delta of $99 should not trigger threeCascade")
    }

    func testMarkerMode_RothLegExactly100_IsTreatedAsNoMovement() {
        // Same boundary on the second leg (middle → current).
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 110_000, afterPretaxMAGI: 100_000, currentMAGI: 100_100)
        XCTAssertEqual(mode, .twoBeforeAfter)
    }

    func testMarkerMode_RothLegExactly101_TriggersThreeCascade() {
        let mode = ACASubsidyBar.markerMode(baselineMAGI: 110_000, afterPretaxMAGI: 100_000, currentMAGI: 100_101)
        XCTAssertEqual(mode, .threeCascade)
    }

    // MARK: - I2 — View-integration smoke test for markerMode

    @MainActor
    func testThreeCascade_ViewIntegration_RendersAndExposesExpectedMode() {
        // Smoke test: construct an ACASubsidyBar with the same call shape TaxPlanningView uses
        // (acaResult + beforeMAGI + afterPretaxMAGI), then verify the static helper that backs
        // the view's `markerMode` computed property returns .threeCascade for this scenario.
        // This locks down the input → mode mapping so a future refactor renaming or moving the
        // helper can't silently change what the view renders.
        let result = ACASubsidyResult(
            acaMAGI: 95_000,
            householdSize: 2,
            fplAmount: 21_150,
            fplPercent: 449,
            applicableFigure: 0.085,
            benchmarkSilverPlanAnnual: 10_000,
            expectedContribution: 8_075,
            annualPremiumAssistance: 1_925,
            dollarsToCliff: -10_400,
            isOverCliff: true
        )
        let view = ACASubsidyBar(acaResult: result, beforeMAGI: 110_000, afterPretaxMAGI: 100_000)
        let _ = view.body
        XCTAssertNotNil(view)
        let mode = ACASubsidyBar.markerMode(
            baselineMAGI: 110_000,
            afterPretaxMAGI: 100_000,
            currentMAGI: 95_000
        )
        XCTAssertEqual(mode, .threeCascade)
    }

    // MARK: - I3 — Pixel-collision guard between middle and current markers

    func testMiddleMarkerCollidesWithCurrent_FarApart_NoCollision() {
        // 320pt-wide bar, MAGI range 0…100K. Mid 50K → x=160, current 80K → x=256. Gap 96pt.
        let collides = ACASubsidyBar.middleMarkerCollidesWithCurrent(
            midMAGI: 50_000, currentMAGI: 80_000, barMaxMAGI: 100_000, barWidth: 320
        )
        XCTAssertFalse(collides)
    }

    func testMiddleMarkerCollidesWithCurrent_WithinThreshold_Collides() {
        // 320pt-wide bar, MAGI range 0…100K → 320 / 100_000 = 0.0032 pt/$ → $50 delta = 0.16pt < 8pt.
        let collides = ACASubsidyBar.middleMarkerCollidesWithCurrent(
            midMAGI: 80_000, currentMAGI: 80_050, barMaxMAGI: 100_000, barWidth: 320
        )
        XCTAssertTrue(collides, "Middle and current within $50 on a 320pt-wide bar should collide")
    }

    func testMiddleMarkerCollidesWithCurrent_ExactlyAtThreshold_DoesNotCollide() {
        // Threshold is < 8pt (strict). Engineer a $-delta such that pixel distance == 8pt exactly,
        // which should NOT register as a collision.
        // 320pt-wide bar, 100K range: 8pt corresponds to $2_500 delta.
        let collides = ACASubsidyBar.middleMarkerCollidesWithCurrent(
            midMAGI: 80_000, currentMAGI: 82_500, barMaxMAGI: 100_000, barWidth: 320
        )
        XCTAssertFalse(collides, "Exactly 8pt apart should not be treated as a collision")
    }

    func testMiddleMarkerCollidesWithCurrent_ZeroBarWidth_DoesNotCollide() {
        // Defensive: zero width returns false (no rendering => no collision concern).
        let collides = ACASubsidyBar.middleMarkerCollidesWithCurrent(
            midMAGI: 80_000, currentMAGI: 80_000, barMaxMAGI: 100_000, barWidth: 0
        )
        XCTAssertFalse(collides)
    }
}
