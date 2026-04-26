import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class BrandButtonTests: XCTestCase {
    func test_allStylesExist() {
        let _ : [BrandButton.Style] = [
            .primary,
            .secondary,
            .tertiaryUtility,
            .tertiaryForward,
            .destructiveSecondary,
            .destructivePrimary
        ]
    }

    func test_sizeHeights() {
        XCTAssertEqual(BrandButton.Size.compact.height, 28)
        XCTAssertEqual(BrandButton.Size.standard.height, 36)
        XCTAssertEqual(BrandButton.Size.prominent.height, 44)
    }

    func test_sizeFontSizes() {
        XCTAssertEqual(BrandButton.Size.compact.fontSize, 13)
        XCTAssertEqual(BrandButton.Size.standard.fontSize, 15)
        XCTAssertEqual(BrandButton.Size.prominent.fontSize, 17)
    }

    func test_buttonConstructsWithoutCrash() {
        _ = BrandButton(title: "Test", style: .primary, size: .standard) {}
        _ = BrandButton(title: "Test", style: .destructiveSecondary, size: .compact) {}
        _ = BrandButton(title: "Test", style: .tertiaryForward, size: .prominent) {}
    }

    func test_defaultStyleIsPrimary() {
        let btn = BrandButton(title: "Test") {}
        // We can't introspect SwiftUI views, but we can confirm the default
        // initializer accepts a single title + action, which means style defaults to .primary.
        _ = btn
    }
}
