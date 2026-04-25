import XCTest
@testable import RetireSmartIRA

final class RadiusTests: XCTestCase {
    func test_radiusValues() {
        XCTAssertEqual(Radius.card, 12)
        XCTAssertEqual(Radius.input, 8)
        XCTAssertEqual(Radius.button, 6)
        XCTAssertEqual(Radius.badge, 4)
    }

    func test_capsuleRadiusForHeight() {
        XCTAssertEqual(Radius.capsule(forHeight: 32), 16)
        XCTAssertEqual(Radius.capsule(forHeight: 24), 12)
        XCTAssertEqual(Radius.capsule(forHeight: 44), 22)
    }
}
