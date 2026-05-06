import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class TaxPositionPanelTests: XCTestCase {
    func testConstructs_RealisticInputs() {
        let panel = TaxPositionPanel(
            federalRate: 0.35,
            federalIncome: 515_000,
            federalBrackets: [
                (rate: 0.10, threshold: 0),
                (rate: 0.37, threshold: 769_000),
            ],
            federalRoomToNext: 254_000,
            irmaaTier: 4,
            irmaaCushionToNextK: 113,
            stateRatePercent: 9.3,
            niitAnnualDollars: 5_900
        )
        XCTAssertNotNil(panel.body)
    }
}
