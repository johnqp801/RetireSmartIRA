import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class CompactBracketGaugeTests: XCTestCase {
    func testConstructs_ValidInputs() {
        let gauge = CompactBracketGauge(
            currentRate: 0.35,
            currentIncome: 515_000,
            brackets: [
                (rate: 0.10, threshold: 0),
                (rate: 0.12, threshold: 25_000),
                (rate: 0.22, threshold: 101_000),
                (rate: 0.24, threshold: 211_000),
                (rate: 0.32, threshold: 404_000),
                (rate: 0.35, threshold: 512_000),
                (rate: 0.37, threshold: 769_000),
            ],
            roomToNextBracket: 254_000
        )
        XCTAssertNotNil(gauge.body)
    }

    func testConstructs_ZeroIncome() {
        let gauge = CompactBracketGauge(
            currentRate: 0.10, currentIncome: 0,
            brackets: [(rate: 0.10, threshold: 0)], roomToNextBracket: .infinity
        )
        XCTAssertNotNil(gauge.body)
    }
}
