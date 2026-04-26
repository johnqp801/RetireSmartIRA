import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ColorTokenSemanticTests: XCTestCase {
    func test_allSemanticTokensExist() {
        _ = Color.Semantic.green
        _ = Color.Semantic.greenHover
        _ = Color.Semantic.greenPressed
        _ = Color.Semantic.greenDisabled
        _ = Color.Semantic.greenTint
        _ = Color.Semantic.amber
        _ = Color.Semantic.amberHover
        _ = Color.Semantic.amberPressed
        _ = Color.Semantic.amberDisabled
        _ = Color.Semantic.amberTint
        _ = Color.Semantic.red
        _ = Color.Semantic.redHover
        _ = Color.Semantic.redPressed
        _ = Color.Semantic.redDisabled
        _ = Color.Semantic.redTint
    }
}
