//
//  HeroStatViewTests.swift
//  RetireSmartIRATests
//

import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class HeroStatViewTests: XCTestCase {

    func testHero_StandardSavings_ConstructsWithoutCrash() {
        let view = HeroStatView(
            baselineLifetimeTax: 5_400_000,
            yourPlanLifetimeTax: 5_000_000,
            heirTaxRatePercent: 22,
            offPlanState: .onPlan,
            useNeutralOffPlanFraming: false,
            onReset: {}
        )
        XCTAssertNotNil(view.body)
    }

    func testHero_AlreadyOptimal_ConstructsWithoutCrash() {
        let view = HeroStatView(
            baselineLifetimeTax: 5_000_000,
            yourPlanLifetimeTax: 5_000_500,
            heirTaxRatePercent: 22,
            offPlanState: .onPlan,
            useNeutralOffPlanFraming: false,
            onReset: {}
        )
        XCTAssertNotNil(view.body)
    }

    func testHero_ExactZeroSavings_ConstructsWithoutCrash() {
        let view = HeroStatView(
            baselineLifetimeTax: 5_000_000,
            yourPlanLifetimeTax: 5_000_000,
            heirTaxRatePercent: 22,
            offPlanState: .onPlan,
            useNeutralOffPlanFraming: false,
            onReset: {}
        )
        XCTAssertNotNil(view.body)
    }

    func testHero_OffPlan_ConstructsWithoutCrash() {
        let view = HeroStatView(
            baselineLifetimeTax: 5_400_000,
            yourPlanLifetimeTax: 5_200_000,
            heirTaxRatePercent: 22,
            offPlanState: .offPlan(deltaDollars: -200_000),
            useNeutralOffPlanFraming: false,
            onReset: {}
        )
        XCTAssertNotNil(view.body)
    }
}
