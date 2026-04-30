import XCTest
import SwiftUI
@testable import RetireSmartIRA

@MainActor
final class BrandButtonSnapshotTests: XCTestCase {
    // MARK: - Primary
    func test_primary_light() {
        let view = BrandButton(title: "Convert", style: .primary, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_primary_light")
    }
    func test_primary_dark() {
        let view = BrandButton(title: "Convert", style: .primary, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_primary_dark")
    }

    // MARK: - Secondary
    func test_secondary_light() {
        let view = BrandButton(title: "Cancel", style: .secondary, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_secondary_light")
    }
    func test_secondary_dark() {
        let view = BrandButton(title: "Cancel", style: .secondary, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_secondary_dark")
    }

    // MARK: - Tertiary Utility
    func test_tertiaryUtility_light() {
        let view = BrandButton(title: "Reset", style: .tertiaryUtility, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_tertiaryUtility_light")
    }
    func test_tertiaryUtility_dark() {
        let view = BrandButton(title: "Reset", style: .tertiaryUtility, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_tertiaryUtility_dark")
    }

    // MARK: - Tertiary Forward
    func test_tertiaryForward_light() {
        let view = BrandButton(title: "View breakdown", style: .tertiaryForward, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_tertiaryForward_light")
    }
    func test_tertiaryForward_dark() {
        let view = BrandButton(title: "View breakdown", style: .tertiaryForward, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_tertiaryForward_dark")
    }

    // MARK: - Destructive Secondary
    func test_destructiveSecondary_light() {
        let view = BrandButton(title: "Delete", style: .destructiveSecondary, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_destructiveSecondary_light")
    }
    func test_destructiveSecondary_dark() {
        let view = BrandButton(title: "Delete", style: .destructiveSecondary, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_destructiveSecondary_dark")
    }

    // MARK: - Destructive Primary
    func test_destructivePrimary_light() {
        let view = BrandButton(title: "Yes, delete forever", style: .destructivePrimary, size: .standard) {}
            .padding()
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "BrandButton_destructivePrimary_light")
    }
    func test_destructivePrimary_dark() {
        let view = BrandButton(title: "Yes, delete forever", style: .destructivePrimary, size: .standard) {}
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "BrandButton_destructivePrimary_dark")
    }
}
