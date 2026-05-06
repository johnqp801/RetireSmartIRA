//
//  TradeOffSynthesizerTests.swift
//  RetireSmartIRATests
//

import XCTest
@testable import RetireSmartIRA

final class TradeOffSynthesizerTests: XCTestCase {

    // MARK: - Dedup

    /// Two IRMAA hits for the same year and tier collapse into one row with summed cost.
    /// (ConstraintType uses a single combined `irmaaTier` case — Part B and Part D are not
    /// distinguished at the type level, so duplicate hits for the same year+tier represent
    /// the Part B/D split that the engine sometimes emits as separate ConstraintHit values.)
    func testDedupSameYearSameTierCollapses() {
        let hits = [
            ConstraintHit(year: 2027, type: .irmaaTier(level: 4), cost: 1_800,
                          acceptanceRationale: "Part B"),
            ConstraintHit(year: 2027, type: .irmaaTier(level: 4), cost: 600,
                          acceptanceRationale: "Part D"),
        ]
        let out = TradeOffSynthesizer.summarize(hits: hits)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].year, 2027)
        XCTAssertEqual(out[0].costDollars, 2_400, accuracy: 0.01)
        XCTAssertTrue(out[0].title.contains("Tier 4"))
    }

    /// IRMAA T4 in 2027 and T5 in 2028 remain two separate rows.
    func testSeparateTiersRemainSeparate() {
        let hits = [
            ConstraintHit(year: 2027, type: .irmaaTier(level: 4), cost: 1_800,
                          acceptanceRationale: ""),
            ConstraintHit(year: 2028, type: .irmaaTier(level: 5), cost: 2_500,
                          acceptanceRationale: ""),
        ]
        let out = TradeOffSynthesizer.summarize(hits: hits)
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0].year, 2027)
        XCTAssertEqual(out[1].year, 2028)
        XCTAssertTrue(out[0].title.contains("Tier 4"))
        XCTAssertTrue(out[1].title.contains("Tier 5"))
    }

    /// Different tiers in the same year remain separate rows.
    func testDifferentTiersSameYearRemainSeparate() {
        let hits = [
            ConstraintHit(year: 2027, type: .irmaaTier(level: 3), cost: 1_000,
                          acceptanceRationale: ""),
            ConstraintHit(year: 2027, type: .irmaaTier(level: 4), cost: 1_800,
                          acceptanceRationale: ""),
        ]
        let out = TradeOffSynthesizer.summarize(hits: hits)
        XCTAssertEqual(out.count, 2)
    }

    // MARK: - WHY templates

    func testBracketOverrunWhyMentionsRothConversions() {
        let hits = [
            ConstraintHit(year: 2026, type: .bracketOverrun(fromBracket: 12, toBracket: 22),
                          cost: 5_000, acceptanceRationale: "")
        ]
        let out = TradeOffSynthesizer.summarize(hits: hits)
        XCTAssertEqual(out.count, 1)
        XCTAssertTrue(out[0].whyText.contains("Roth conversions"),
                      "Expected whyText to mention Roth conversions, got: \(out[0].whyText)")
    }

    func testIRMAAWhyMentionsMedicare() {
        let hits = [
            ConstraintHit(year: 2027, type: .irmaaTier(level: 2), cost: 900,
                          acceptanceRationale: "")
        ]
        let out = TradeOffSynthesizer.summarize(hits: hits)
        XCTAssertEqual(out.count, 1)
        XCTAssertTrue(out[0].whyText.contains("Medicare"),
                      "Expected whyText to mention Medicare, got: \(out[0].whyText)")
    }

    // MARK: - Sort order

    func testSortByYearAscendingThenTitle() {
        let hits = [
            ConstraintHit(year: 2028, type: .irmaaTier(level: 5), cost: 100,
                          acceptanceRationale: ""),
            ConstraintHit(year: 2027, type: .acaCliff, cost: 200,
                          acceptanceRationale: ""),
            ConstraintHit(year: 2027, type: .bracketOverrun(fromBracket: 12, toBracket: 22),
                          cost: 300, acceptanceRationale: ""),
        ]
        let out = TradeOffSynthesizer.summarize(hits: hits)
        XCTAssertEqual(out.count, 3)
        XCTAssertEqual(out[0].year, 2027)
        XCTAssertEqual(out[1].year, 2027)
        XCTAssertEqual(out[2].year, 2028)
        // Within 2027, title sorted ascending
        XCTAssertLessThanOrEqual(out[0].title, out[1].title)
    }

    // MARK: - Title formatting

    func testBracketOverrunTitleFormat() {
        let hits = [
            ConstraintHit(year: 2026, type: .bracketOverrun(fromBracket: 12, toBracket: 22),
                          cost: 5_000, acceptanceRationale: "")
        ]
        let out = TradeOffSynthesizer.summarize(hits: hits)
        XCTAssertTrue(out[0].title.contains("12%"))
        XCTAssertTrue(out[0].title.contains("22%"))
    }

    func testACATitle() {
        let hits = [
            ConstraintHit(year: 2026, type: .acaCliff, cost: 4_000, acceptanceRationale: "")
        ]
        let out = TradeOffSynthesizer.summarize(hits: hits)
        XCTAssertEqual(out.count, 1)
        XCTAssertTrue(out[0].title.localizedCaseInsensitiveContains("ACA"))
    }
}
