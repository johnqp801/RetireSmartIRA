import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ActionItemsBannerTests: XCTestCase {

    func testHidden_WhenAllActionsZero() {
        let banner = ActionItemsBanner(
            year: 2026, rothAmount: 0, qcdAmount: 0,
            stockDonationAmount: 0, requiredRMDAmount: 0, onViewAll: {}
        )
        XCTAssertFalse(banner.shouldShow)
    }

    func testShown_WhenRothNonZero() {
        let banner = ActionItemsBanner(
            year: 2026, rothAmount: 341_000, qcdAmount: 0,
            stockDonationAmount: 0, requiredRMDAmount: 0, onViewAll: {}
        )
        XCTAssertTrue(banner.shouldShow)
    }

    func testCount_SumsNonZeroActions() {
        let banner = ActionItemsBanner(
            year: 2026, rothAmount: 341_000, qcdAmount: 0,
            stockDonationAmount: 50_000, requiredRMDAmount: 0, onViewAll: {}
        )
        XCTAssertEqual(banner.actionCount, 2)
    }

    func testConstructs() {
        let banner = ActionItemsBanner(
            year: 2026, rothAmount: 341_000, qcdAmount: 0,
            stockDonationAmount: 50_000, requiredRMDAmount: 0, onViewAll: {}
        )
        XCTAssertNotNil(banner.body)
    }
}
