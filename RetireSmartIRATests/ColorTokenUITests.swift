import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ColorTokenUITests: XCTestCase {
    func test_brandTealResolvesFromAssetCatalog() {
        let color = Color.UI.brandTeal
        // Smoke test: ensure the token compiles and is non-nil.
        // Color equality in SwiftUI is structural; render to platform-native for verification.
        #if canImport(UIKit)
        let resolved = UIColor(color)
        XCTAssertNotNil(resolved.cgColor)
        #elseif canImport(AppKit)
        let resolved = NSColor(color)
        XCTAssertNotNil(resolved.cgColor)
        #endif
    }

    func test_allUITokensExist() {
        // Reference each token to ensure compile-time existence.
        _ = Color.UI.brandTeal
        _ = Color.UI.brandTealHover
        _ = Color.UI.brandTealPressed
        _ = Color.UI.brandTealDisabled
        _ = Color.UI.brandTealFocusRing
        _ = Color.UI.surfaceApp
        _ = Color.UI.surfaceCard
        _ = Color.UI.surfaceInset
        _ = Color.UI.surfaceModal
        _ = Color.UI.surfaceDivider
        _ = Color.UI.textPrimary
        _ = Color.UI.textSecondary
        _ = Color.UI.textTertiary
        _ = Color.UI.textUtility
    }
}
