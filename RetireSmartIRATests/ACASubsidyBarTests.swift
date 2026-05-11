import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ACASubsidyBarTests: XCTestCase {

    // MARK: - Readout state classification

    func testReadoutState_FarUnderCliff_IsWellUnder() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: 50_000), .wellUnder)
    }

    func testReadoutState_VeryFarUnderCliff_IsWellUnder() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: 500_000), .wellUnder)
    }

    func testReadoutState_BoundaryJustAbove20K_IsWellUnder() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: 20_000.01), .wellUnder)
    }

    func testReadoutState_BoundaryAt20K_IsApproaching() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: 20_000), .approaching)
    }

    func testReadoutState_ApproachingMidRange_IsApproaching() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: 10_000), .approaching)
    }

    func testReadoutState_BoundaryJustAbove5K_IsApproaching() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: 5_000.01), .approaching)
    }

    func testReadoutState_BoundaryAt5K_IsWithinBuffer() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: 5_000), .withinBuffer)
    }

    func testReadoutState_NearCliff_IsWithinBuffer() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: 2_000), .withinBuffer)
    }

    func testReadoutState_AtZero_IsWithinBuffer() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: 0), .withinBuffer)
    }

    func testReadoutState_JustOverCliff_IsJustOver() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: -5_000), .justOver)
    }

    func testReadoutState_NearLimitOfRecovery_IsJustOver() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: -20_000), .justOver)
    }

    func testReadoutState_PastRecoveryThreshold_IsFarOver() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: -20_000.01), .farOver)
    }

    func testReadoutState_FarOverCliff_IsFarOver() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: -50_000), .farOver)
    }

    func testReadoutState_VeryFarOver_IsFarOver() {
        XCTAssertEqual(ACASubsidyBar.readoutState(headroom: -500_000), .farOver)
    }

    // MARK: - State distinctness

    func testReadoutState_AllStatesDistinct() {
        let states: Set<ACASubsidyBarReadoutState> = [
            .wellUnder, .approaching, .withinBuffer, .justOver, .farOver
        ]
        XCTAssertEqual(states.count, 5)
    }

    // MARK: - Band classification (by FPL %)

    func testBand_LowMAGI_IsFullSubsidy() {
        // 100% FPL → Full subsidy band
        XCTAssertEqual(ACASubsidyBar.band(forFPLPercent: 100), .fullSubsidy)
    }

    func testBand_AtFullSubsidyBoundary_IsFullSubsidy() {
        XCTAssertEqual(ACASubsidyBar.band(forFPLPercent: 200), .fullSubsidy)
    }

    func testBand_JustAboveFullSubsidy_IsGenerous() {
        XCTAssertEqual(ACASubsidyBar.band(forFPLPercent: 250), .generous)
    }

    func testBand_AtModerateRange_IsModerate() {
        XCTAssertEqual(ACASubsidyBar.band(forFPLPercent: 325), .moderate)
    }

    func testBand_AtCliffMinusOne_IsThin() {
        XCTAssertEqual(ACASubsidyBar.band(forFPLPercent: 399), .thin)
    }

    func testBand_AtCliff_IsCliff() {
        XCTAssertEqual(ACASubsidyBar.band(forFPLPercent: 401), .cliff)
    }

    func testBand_FarOverCliff_IsCliff() {
        XCTAssertEqual(ACASubsidyBar.band(forFPLPercent: 800), .cliff)
    }

    // MARK: - Rendering smoke tests

    @MainActor
    func testBarRenders_InAllFiveStates() {
        let cliff = 84_600.0
        // (state name, MAGI to produce that headroom)
        let cases: [(String, Double, Bool)] = [
            ("wellUnder", 30_000, false),
            ("approaching", 74_000, false),
            ("withinBuffer", 82_000, false),
            ("justOver", 90_000, true),
            ("farOver", 200_000, true)
        ]
        for (name, magi, over) in cases {
            let result = ACASubsidyResult(
                acaMAGI: magi,
                householdSize: 2,
                fplAmount: 21_150,
                fplPercent: magi / 21_150 * 100,
                applicableFigure: 0.085,
                benchmarkSilverPlanAnnual: 10_000,
                expectedContribution: magi * 0.085,
                annualPremiumAssistance: over ? 0 : max(0, 10_000 - magi * 0.085),
                dollarsToCliff: cliff - magi,
                isOverCliff: over
            )
            let view = ACASubsidyBar(acaResult: result, beforeMAGI: nil)
            let _ = view.body
            XCTAssertNotNil(view, "ACASubsidyBar failed to render for state: \(name)")
        }
    }

    @MainActor
    func testBarRenders_WithBeforeMAGIMarker() {
        let result = ACASubsidyResult(
            acaMAGI: 48_000,
            householdSize: 2,
            fplAmount: 21_150,
            fplPercent: 227,
            applicableFigure: 0.05,
            benchmarkSilverPlanAnnual: 10_000,
            expectedContribution: 2_400,
            annualPremiumAssistance: 7_600,
            dollarsToCliff: 36_600,
            isOverCliff: false
        )
        let view = ACASubsidyBar(acaResult: result, beforeMAGI: 35_000)
        let _ = view.body
        XCTAssertNotNil(view)
    }
}
