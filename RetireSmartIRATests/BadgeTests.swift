import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class BadgeTests: XCTestCase {
    func test_refundDefaultTextIsREFUND() {
        XCTAssertEqual(Badge.Variant.refund.defaultText, "REFUND")
    }

    func test_dueDefaultTextIsDUE() {
        XCTAssertEqual(Badge.Variant.due.defaultText, "DUE")
    }

    func test_errorDefaultTextIsERROR() {
        XCTAssertEqual(Badge.Variant.error.defaultText, "ERROR")
    }

    func test_neutralDefaultTextIsEmpty() {
        XCTAssertEqual(Badge.Variant.neutral.defaultText, "")
    }

    func test_allVariantsExposeForegroundAndBackground() {
        // Each variant must have a foreground and background — referencing them
        // verifies compile-time existence and that the switch is exhaustive.
        for variant in [Badge.Variant.refund, .due, .error, .neutral] {
            _ = variant.foreground
            _ = variant.background
        }
    }

    func test_allVariantsConstructWithoutCrash() {
        _ = Badge(text: "REFUND", variant: .refund)
        _ = Badge(text: "DUE", variant: .due)
        _ = Badge(text: "ERROR", variant: .error)
        _ = Badge(text: "DRAFT", variant: .neutral)
    }
}
