//
//  MultiYearStrategyManagerBaselineTests.swift
//  RetireSmartIRATests
//

import XCTest
@testable import RetireSmartIRA

@MainActor
final class MultiYearStrategyManagerBaselineTests: XCTestCase {

    func testBaselineProjection_StartsNil() {
        let manager = MultiYearStrategyManager()
        XCTAssertNil(manager.baselineProjection,
                     "baselineProjection must default to nil before first compute")
    }
}
