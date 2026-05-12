import XCTest
@testable import RetireSmartIRA

final class AdaptiveSliderCapTests: XCTestCase {

    func testCap_ZeroBalance_ReturnsZero() {
        XCTAssertEqual(adaptiveSliderCap(balance: 0), 0)
    }

    func testCap_VerySmallBalance_ReturnsBalance() {
        // $30K balance → 20% = $6K, floor = min($30K, $50K) = $30K → $30K wins
        XCTAssertEqual(adaptiveSliderCap(balance: 30_000), 30_000)
    }

    func testCap_SmallBalance_ReturnsFloor() {
        // $100K balance → 20% = $20K, floor = min($100K, $50K) = $50K → floor wins
        XCTAssertEqual(adaptiveSliderCap(balance: 100_000), 50_000)
    }

    func testCap_MediumBalance_ReturnsTwentyPercent() {
        // $1M balance → 20% = $200K, under $500K cap, floor = $50K → 20% wins
        XCTAssertEqual(adaptiveSliderCap(balance: 1_000_000), 200_000)
    }

    func testCap_LargeBalance_ReturnsCap() {
        // $3M balance → 20% = $600K, capped at $500K
        XCTAssertEqual(adaptiveSliderCap(balance: 3_000_000), 500_000)
    }

    func testCap_VeryLargeBalance_ReturnsCap() {
        // $7.3M balance → 20% = $1.46M, capped at $500K
        XCTAssertEqual(adaptiveSliderCap(balance: 7_300_000), 500_000)
    }

    func testCap_ExtraLargeBalance_ReturnsCap() {
        // $20M balance → 20% = $4M, capped at $500K
        XCTAssertEqual(adaptiveSliderCap(balance: 20_000_000), 500_000)
    }

    func testCap_ExactFloorBoundary_ReturnsFloor() {
        // $50K balance → 20% = $10K, floor = min($50K, $50K) = $50K → floor wins
        XCTAssertEqual(adaptiveSliderCap(balance: 50_000), 50_000)
    }

    func testCap_JustAboveFloorCrossover_ReturnsTwentyPercent() {
        // $250K balance → 20% = $50K, floor = $50K → tie, max($50K, $50K) = $50K
        XCTAssertEqual(adaptiveSliderCap(balance: 250_000), 50_000)
    }

    func testCap_AboveFloorCrossover_ReturnsTwentyPercent() {
        // $500K balance → 20% = $100K, floor = $50K → 20% wins
        XCTAssertEqual(adaptiveSliderCap(balance: 500_000), 100_000)
    }

    func testCap_ExactCapBoundary_ReturnsCap() {
        // $2.5M balance → 20% = $500K, exactly at cap
        XCTAssertEqual(adaptiveSliderCap(balance: 2_500_000), 500_000)
    }
}
