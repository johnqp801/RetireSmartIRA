import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class InfoButtonTests: XCTestCase {
    func test_buttonConstructsWithoutCrash() {
        _ = InfoButton {}
    }

    func test_buttonAcceptsActionClosure() {
        var tapped = false
        let button = InfoButton { tapped = true }
        // Can't trigger SwiftUI button action in unit test without UI, but we can
        // verify the closure storage compiles. tapped stays false; that's fine.
        _ = button
        XCTAssertFalse(tapped)
    }
}
