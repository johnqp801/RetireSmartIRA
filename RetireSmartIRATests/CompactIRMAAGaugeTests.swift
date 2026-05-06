import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class CompactIRMAAGaugeTests: XCTestCase {
    func testConstructs_Tier4() {
        let gauge = CompactIRMAAGauge(currentTier: 4, cushionToNextTierK: 113)
        XCTAssertNotNil(gauge.body)
    }

    func testConstructs_Clear() {
        let gauge = CompactIRMAAGauge(currentTier: 0, cushionToNextTierK: nil)
        XCTAssertNotNil(gauge.body)
    }

    func testConstructs_TopTier() {
        let gauge = CompactIRMAAGauge(currentTier: 5, cushionToNextTierK: nil)
        XCTAssertNotNil(gauge.body)
    }
}
