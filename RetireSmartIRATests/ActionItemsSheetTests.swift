import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ActionItemsSheetTests: XCTestCase {

    @MainActor
    func testCheckboxKeysAreYearScoped() {
        let key2026 = actionItemKey(year: 2026, action: .roth)
        let key2027 = actionItemKey(year: 2027, action: .roth)
        UserDefaults.standard.set(true, forKey: key2026)
        defer {
            UserDefaults.standard.removeObject(forKey: key2026)
            UserDefaults.standard.removeObject(forKey: key2027)
        }
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key2026))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key2027),
                       "2027 key must read default (false), not 2026 value")
    }

    @MainActor
    func testConstructs() {
        let sheet = ActionItemsSheet(
            year: 2026, rothAmount: 341_000, qcdAmount: 0,
            stockDonationAmount: 50_000, requiredRMDAmount: 11_000
        )
        XCTAssertNotNil(sheet.body)
    }
}
