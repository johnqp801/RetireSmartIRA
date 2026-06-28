import XCTest
@testable import RetireSmartIRA

final class ActionItemKeyTests: XCTestCase {

    func testKey_DifferentYearsProduceDifferentKeys() {
        let k2026 = actionItemKey(year: 2026, action: .roth)
        let k2027 = actionItemKey(year: 2027, action: .roth)
        XCTAssertNotEqual(k2026, k2027)
    }

    func testKey_DifferentActionsProduceDifferentKeys() {
        let kRoth = actionItemKey(year: 2026, action: .roth)
        let kQCD = actionItemKey(year: 2026, action: .qcd)
        XCTAssertNotEqual(kRoth, kQCD)
    }

    func testKey_FormatIncludesYearAndAction() {
        let key = actionItemKey(year: 2026, action: .roth)
        XCTAssertTrue(key.contains("2026"))
        XCTAssertTrue(key.contains("roth"))
    }
}
