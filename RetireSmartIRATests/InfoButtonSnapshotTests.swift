import XCTest
import SwiftUI
@testable import RetireSmartIRA

@MainActor
final class InfoButtonSnapshotTests: XCTestCase {
    func test_inline_light() {
        let view = HStack(spacing: 6) {
            Text("Primary Heir's Salary")
                .font(.system(size: 13))
            InfoButton {}
            Spacer()
        }
        .padding()
        .frame(width: 280)
        .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "InfoButton_inline_light")
    }

    func test_inline_dark() {
        let view = HStack(spacing: 6) {
            Text("Primary Heir's Salary")
                .font(.system(size: 13))
            InfoButton {}
            Spacer()
        }
        .padding()
        .frame(width: 280)
        .background(Color.UI.surfaceCard)
        .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "InfoButton_inline_dark")
    }
}
