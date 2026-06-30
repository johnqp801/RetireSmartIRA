//
//  YearRecommendationExtensionsTests.swift
//  RetireSmartIRATests
//

import XCTest
@testable import RetireSmartIRA

final class YearRecommendationExtensionsTests: XCTestCase {

    func testLifetimeTax_EmptyArray_IsZero() {
        let path: [YearRecommendation] = []
        XCTAssertEqual(path.lifetimeTax, 0)
    }

    func testLifetimeTax_SumsTaxBreakdownTotals() {
        let path: [YearRecommendation] = [
            .stub(year: 2026, taxTotal: 100_000),
            .stub(year: 2027, taxTotal: 110_000),
            .stub(year: 2028, taxTotal: 120_000),
        ]
        XCTAssertEqual(path.lifetimeTax, 330_000, accuracy: 0.01)
    }
}

private extension YearRecommendation {
    static func stub(year: Int, taxTotal: Double) -> YearRecommendation {
        YearRecommendation(
            year: year,
            agi: 0,
            acaMagi: nil,
            irmaaMagi: nil,
            taxableIncome: 0,
            taxBreakdown: TaxBreakdown(federal: taxTotal, state: 0, irmaa: 0, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(
                primaryTraditional: 0, spouseTraditional: 0,
                roth: 0, taxable: 0, hsa: 0
            ),
            actions: []
        )
    }
}
