import XCTest
@testable import RetireSmartIRA

final class IRMAARunwayBannerTests: XCTestCase {
    func test_visible_whenPrimaryAge60() {
        XCTAssertTrue(IRMAARunwayBanner.shouldShow(primaryAge: 60, spouseAge: nil, spouseEnabled: false))
    }

    func test_visible_whenPrimaryAge62() {
        XCTAssertTrue(IRMAARunwayBanner.shouldShow(primaryAge: 62, spouseAge: nil, spouseEnabled: false))
    }

    func test_hidden_whenPrimaryAge59() {
        XCTAssertFalse(IRMAARunwayBanner.shouldShow(primaryAge: 59, spouseAge: nil, spouseEnabled: false))
    }

    func test_hidden_whenPrimaryAge63() {
        XCTAssertFalse(IRMAARunwayBanner.shouldShow(primaryAge: 63, spouseAge: nil, spouseEnabled: false))
    }

    func test_visible_whenSpouseAge61_andPrimary55() {
        XCTAssertTrue(IRMAARunwayBanner.shouldShow(primaryAge: 55, spouseAge: 61, spouseEnabled: true))
    }

    func test_hidden_whenSpouseAge61_butSpouseDisabled() {
        XCTAssertFalse(IRMAARunwayBanner.shouldShow(primaryAge: 55, spouseAge: 61, spouseEnabled: false))
    }
}
