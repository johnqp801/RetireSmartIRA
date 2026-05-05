//
//  YearOverYearDeltaSynthesizerTests.swift
//  RetireSmartIRATests
//

import XCTest
@testable import RetireSmartIRA

final class YearOverYearDeltaSynthesizerTests: XCTestCase {

    func testSynthesize_TaxJump_DueToRMDStart() throws {
        let prior = makeYearRecommendation(year: 2025, actions: [], federal: 8_000)
        let current = makeYearRecommendation(year: 2026, actions: [.traditionalWithdrawal(amount: 30_000)], federal: 14_000)

        let result = YearOverYearDeltaSynthesizer.synthesize(prior: prior, current: current)

        let delta = try XCTUnwrap(result.taxDelta)
        XCTAssertEqual(delta, 6_000, accuracy: 0.01)
        XCTAssertNotNil(result.causeSentence)
        XCTAssertTrue(result.causeSentence?.contains("RMD") ?? false,
            "Cause should mention RMD, got: \(result.causeSentence ?? "nil")")
    }

    func testSynthesize_TaxJump_DueToSSClaim() throws {
        let prior = makeYearRecommendation(year: 2025, actions: [.deferSocialSecurity], federal: 8_000)
        let current = makeYearRecommendation(year: 2026, actions: [.claimSocialSecurity(spouse: .primary)], federal: 14_000)

        let result = YearOverYearDeltaSynthesizer.synthesize(prior: prior, current: current)

        let delta = try XCTUnwrap(result.taxDelta)
        XCTAssertEqual(delta, 6_000, accuracy: 0.01)
        XCTAssertNotNil(result.causeSentence)
        let cause = result.causeSentence ?? ""
        XCTAssertTrue(cause.lowercased().contains("social security") || cause.uppercased().contains("SS"),
            "Cause should mention Social Security or SS, got: \(cause)")
    }

    func testSynthesize_IRMAACross_NamesTier() throws {
        let prior = makeYearRecommendation(year: 2025, actions: [], federal: 8_000, irmaa: 0)
        let current = makeYearRecommendation(year: 2026, actions: [], federal: 14_000, irmaa: 2_400)

        let result = YearOverYearDeltaSynthesizer.synthesize(prior: prior, current: current)

        let delta = try XCTUnwrap(result.taxDelta)
        XCTAssertEqual(delta, 8_400, accuracy: 0.01)
        XCTAssertNotNil(result.causeSentence)
        XCTAssertTrue(result.causeSentence?.contains("IRMAA") ?? false,
            "Cause should mention IRMAA, got: \(result.causeSentence ?? "nil")")
    }

    func testSynthesize_NoMaterialChange_NoCause() throws {
        let prior = makeYearRecommendation(year: 2025, actions: [], federal: 8_000)
        let current = makeYearRecommendation(year: 2026, actions: [], federal: 8_500)

        let result = YearOverYearDeltaSynthesizer.synthesize(prior: prior, current: current)

        let delta = try XCTUnwrap(result.taxDelta)
        XCTAssertEqual(delta, 500, accuracy: 0.01)
        XCTAssertNil(result.causeSentence)
    }

    func testSynthesize_FirstYear_NoComparison() {
        let current = makeYearRecommendation(year: 2026, actions: [.traditionalWithdrawal(amount: 30_000)], federal: 14_000)

        let result = YearOverYearDeltaSynthesizer.synthesize(prior: nil, current: current)

        XCTAssertNil(result.taxDelta)
        XCTAssertNil(result.causeSentence)
    }

    // MARK: - Fixtures

    private func makeYearRecommendation(
        year: Int,
        actions: [LeverAction],
        federal: Double = 8_000,
        irmaa: Double = 0
    ) -> YearRecommendation {
        YearRecommendation(
            year: year,
            agi: 80_000,
            acaMagi: nil,
            irmaaMagi: nil,
            taxableIncome: 60_000,
            taxBreakdown: TaxBreakdown(federal: federal, state: 1_000, irmaa: irmaa, acaPremiumImpact: 0),
            endOfYearBalances: .zero,
            actions: actions
        )
    }
}
