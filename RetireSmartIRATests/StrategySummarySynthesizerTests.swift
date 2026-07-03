//
//  StrategySummarySynthesizerTests.swift
//  RetireSmartIRATests
//

import XCTest
@testable import RetireSmartIRA

final class StrategySummarySynthesizerTests: XCTestCase {

    func testSynthesize_RothLadderCluster_ProducesYearRangeSentence() {
        let path = makePathWithRothConversions([
            (year: 2026, amount: 65_000),
            (year: 2027, amount: 70_000),
            (year: 2028, amount: 60_000),
            (year: 2029, amount: 55_000),
            (year: 2030, amount: 50_000),
            (year: 2031, amount: 0)
        ])

        let summary = StrategySummarySynthesizer.synthesize(path: path, tradeOffs: [])

        XCTAssertTrue(summary.contains("$50") && summary.contains("$70"),
            "Should mention range of conversion amounts")
        XCTAssertTrue(summary.contains("2026") || summary.contains("through 2030"),
            "Should mention year range")
    }

    func testSynthesize_SocialSecurityClaim_NamesYear() {
        let path = makePathWithSSClaim(at: 2028, spouse: .primary)
        let summary = StrategySummarySynthesizer.synthesize(path: path, tradeOffs: [])

        XCTAssertTrue(summary.lowercased().contains("ss") || summary.lowercased().contains("social security"),
            "Should mention SS claim")
        XCTAssertTrue(summary.contains("2028"), "Should mention claim year")
    }

    func testSynthesize_AcceptedConstraintHits_MentionsConstraint() {
        let path = makeBasicPath()
        let tradeOffs: [ConstraintHit] = [
            ConstraintHit(year: 2027, type: .irmaaTier(level: 1), cost: 2400, acceptanceRationale: "Roth conversion benefit exceeds IRMAA cost")
        ]

        let summary = StrategySummarySynthesizer.synthesize(path: path, tradeOffs: tradeOffs)

        XCTAssertTrue(summary.contains("IRMAA") || summary.lowercased().contains("trade-off") || summary.lowercased().contains("tradeoff"),
            "Should mention accepted constraint")
    }

    func testSynthesize_EmptyPath_ProducesPlaceholder() {
        let summary = StrategySummarySynthesizer.synthesize(path: [], tradeOffs: [])
        XCTAssertFalse(summary.isEmpty, "Should produce at least placeholder text for empty path")
    }

    func testSynthesize_MultipleTradeOffs_MentionsCount() {
        let path = makeBasicPath()
        let tradeOffs: [ConstraintHit] = [
            ConstraintHit(year: 2026, type: .irmaaTier(level: 1), cost: 2400, acceptanceRationale: "Worth it"),
            ConstraintHit(year: 2027, type: .acaCliff, cost: 800, acceptanceRationale: "Minor hit"),
            ConstraintHit(year: 2028, type: .bracketOverrun(fromBracket: 22, toBracket: 24), cost: 600, acceptanceRationale: "Small overrun")
        ]

        let summary = StrategySummarySynthesizer.synthesize(path: path, tradeOffs: tradeOffs)

        XCTAssertTrue(summary.contains("3") || summary.contains("trade-off") || summary.contains("tradeoff"),
            "Should mention 3 trade-offs or the word trade-off")
    }

    func testSynthesize_SingleConversionYear_NoRange() {
        let path = makePathWithRothConversions([
            (year: 2026, amount: 65_000)
        ])

        let summary = StrategySummarySynthesizer.synthesize(path: path, tradeOffs: [])

        XCTAssertTrue(summary.contains("2026"), "Should mention the single conversion year")
        XCTAssertFalse(summary.contains("through"), "Single year should not say 'through'")
    }

    // MARK: - Fixtures

    private func makeYearRecommendation(year: Int, actions: [LeverAction]) -> YearRecommendation {
        YearRecommendation(
            year: year,
            agi: 80_000,
            acaMagi: nil,
            irmaaMagi: nil,
            taxableIncome: 60_000,
            taxBreakdown: .zero,
            endOfYearBalances: .zero,
            actions: actions
        )
    }

    private func makePathWithRothConversions(_ entries: [(year: Int, amount: Double)]) -> [YearRecommendation] {
        entries.map { entry in
            let actions: [LeverAction] = entry.amount > 0 ? [.rothConversion(amount: entry.amount)] : []
            return makeYearRecommendation(year: entry.year, actions: actions)
        }
    }

    private func makePathWithSSClaim(at year: Int, spouse: SpouseID) -> [YearRecommendation] {
        let priorYears = (2026..<year).map { y in
            makeYearRecommendation(year: y, actions: [.deferSocialSecurity])
        }
        let claimYear = makeYearRecommendation(year: year, actions: [.claimSocialSecurity(spouse: spouse)])
        return priorYears + [claimYear]
    }

    private func makeBasicPath() -> [YearRecommendation] {
        [makeYearRecommendation(year: 2026, actions: [.traditionalWithdrawal(amount: 20_000)])]
    }
}
