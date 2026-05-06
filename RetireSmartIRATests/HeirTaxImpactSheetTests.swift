//
//  HeirTaxImpactSheetTests.swift
//  RetireSmartIRATests
//

import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class HeirTaxImpactSheetTests: XCTestCase {
    @MainActor func testConstructs() {
        let manager = MultiYearStrategyManager()
        let sheet = HeirTaxImpactSheet(manager: manager)
        XCTAssertNotNil(sheet.body)
    }
}
