import XCTest
import SwiftUI
@testable import RetireSmartIRA

@MainActor
final class BadgeSnapshotTests: XCTestCase {
    // MARK: - Refund
    func test_refund_light() {
        let view = Badge(text: "REFUND", variant: .refund)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "Badge_refund_light")
    }
    func test_refund_dark() {
        let view = Badge(text: "REFUND", variant: .refund)
            .padding()
            .background(Color.UI.surfaceCard)
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, named: "Badge_refund_dark")
    }

    // MARK: - Due
    func test_due_light() {
        let view = Badge(text: "DUE", variant: .due)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "Badge_due_light")
    }
    func test_due_dark() {
        let view = Badge(text: "DUE", variant: .due)
            .padding()
            .background(Color.UI.surfaceCard)
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, named: "Badge_due_dark")
    }

    // MARK: - Error
    func test_error_light() {
        let view = Badge(text: "ERROR", variant: .error)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "Badge_error_light")
    }
    func test_error_dark() {
        let view = Badge(text: "ERROR", variant: .error)
            .padding()
            .background(Color.UI.surfaceCard)
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, named: "Badge_error_dark")
    }

    // MARK: - Neutral
    func test_neutral_light() {
        let view = Badge(text: "DRAFT", variant: .neutral)
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "Badge_neutral_light")
    }
    func test_neutral_dark() {
        let view = Badge(text: "DRAFT", variant: .neutral)
            .padding()
            .background(Color.UI.surfaceCard)
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, named: "Badge_neutral_dark")
    }
}
