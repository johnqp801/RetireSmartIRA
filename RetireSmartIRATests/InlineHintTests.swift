import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class InlineHintTests: XCTestCase {
    func test_constructsWithText() {
        let hint = InlineHint("State tax only — local/city taxes are not included.")
        XCTAssertEqual(hint.text, "State tax only — local/city taxes are not included.")
    }

    func test_constructsWithEmptyText() {
        // Edge case: empty string should not crash.
        let hint = InlineHint("")
        XCTAssertEqual(hint.text, "")
    }

    func test_constructsWithMultilineText() {
        let multiline = "First line of hint.\nSecond line wraps to a new line for clarity."
        let hint = InlineHint(multiline)
        XCTAssertEqual(hint.text, multiline)
    }

    func test_isViewType() {
        // The component must conform to View.
        let hint = InlineHint("Test")
        let _: any View = hint
    }
}
