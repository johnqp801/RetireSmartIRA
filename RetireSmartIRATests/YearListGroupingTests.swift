//
//  YearListGroupingTests.swift
//  RetireSmartIRATests
//

import XCTest
@testable import RetireSmartIRA

final class YearListGroupingTests: XCTestCase {

    private func rec(_ year: Int, tier: Int, tax: Double = 100_000) -> YearRecommendation {
        YearRecommendation(
            year: year,
            agi: tax,
            acaMagi: nil,
            irmaaMagi: nil,
            taxableIncome: tax,
            taxBreakdown: TaxBreakdown(federal: tax, state: 0, irmaa: Double(tier) * 1000, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(primaryTraditional: 0, spouseTraditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: [],
            medicareEnrolledCount: 0
        )
    }

    func testGrouping_AllSameTier_ProducesYearOneFullPlusOneGroupedRow() {
        let path = (2026...2030).map { rec($0, tier: 4) }
        let groups = YearListGrouping.group(
            path: path,
            currentYear: 2026,
            tierFor: { $0.taxBreakdown.irmaa > 0 ? Int($0.taxBreakdown.irmaa / 1000) : 0 }
        )
        XCTAssertEqual(groups.count, 2)
        if case .full(let r, _) = groups[0] {
            XCTAssertEqual(r.year, 2026)
        } else {
            XCTFail("First row must be full for current year")
        }
        if case .group(let startYear, let endYear, _, _) = groups[1] {
            XCTAssertEqual(startYear, 2027)
            XCTAssertEqual(endYear, 2030)
        } else {
            XCTFail("Second row must be a group")
        }
    }

    func testGrouping_TierTransition_BadgesTransitionYearAsFull() {
        let path = [
            rec(2026, tier: 4), rec(2027, tier: 4), rec(2028, tier: 4),
            rec(2029, tier: 5), rec(2030, tier: 5)
        ]
        let groups = YearListGrouping.group(
            path: path,
            currentYear: 2026,
            tierFor: { $0.taxBreakdown.irmaa > 0 ? Int($0.taxBreakdown.irmaa / 1000) : 0 }
        )
        XCTAssertEqual(groups.count, 4)
        if case .full(let r, let badge) = groups[2] {
            XCTAssertEqual(r.year, 2029)
            if case .entersTier(let tier) = badge {
                XCTAssertEqual(tier, 5)
            } else {
                XCTFail("Year 2029 must badge as entersTier(5)")
            }
        } else {
            XCTFail("Year 2029 must be a full row")
        }
    }

    func testGrouping_TierImproves_BadgesAsImprovement() {
        let path = [
            rec(2026, tier: 5), rec(2027, tier: 5),
            rec(2028, tier: 4), rec(2029, tier: 4)
        ]
        let groups = YearListGrouping.group(
            path: path,
            currentYear: 2026,
            tierFor: { $0.taxBreakdown.irmaa > 0 ? Int($0.taxBreakdown.irmaa / 1000) : 0 }
        )
        if case .full(let r, let badge) = groups[2] {
            XCTAssertEqual(r.year, 2028)
            if case .dropsToTier(let tier) = badge {
                XCTAssertEqual(tier, 4)
            } else {
                XCTFail("Year 2028 must badge as dropsToTier(4)")
            }
        } else {
            XCTFail("Year 2028 must be a full row")
        }
    }

    func testGrouping_AllDifferentTiers_AllFullRows() {
        let path = [rec(2026, tier: 1), rec(2027, tier: 2), rec(2028, tier: 3)]
        let groups = YearListGrouping.group(
            path: path,
            currentYear: 2026,
            tierFor: { $0.taxBreakdown.irmaa > 0 ? Int($0.taxBreakdown.irmaa / 1000) : 0 }
        )
        XCTAssertEqual(groups.count, 3)
        for g in groups {
            if case .group = g { XCTFail("No groups expected when every year is a transition") }
        }
    }

    func testGrouping_EmptyPath_ReturnsEmpty() {
        XCTAssertTrue(YearListGrouping.group(path: [], currentYear: 2026, tierFor: { _ in 0 }).isEmpty)
    }

    func testGrouping_SingleYearSameTierAtEnd_IsFullRow() {
        // 2026 T4 (current), 2027 T5 (transition, full), 2028 T5 (single-year tail, should be full or group-of-1)
        let path = [rec(2026, tier: 4), rec(2027, tier: 5), rec(2028, tier: 5)]
        let groups = YearListGrouping.group(
            path: path,
            currentYear: 2026,
            tierFor: { $0.taxBreakdown.irmaa > 0 ? Int($0.taxBreakdown.irmaa / 1000) : 0 }
        )
        // 2028 is a single same-tier year after the transition — must appear as a row (not dropped)
        XCTAssertEqual(groups.count, 3, "All 3 years must produce a row (no year dropped)")
        // Verify no single-year group is emitted (should be a .full row instead)
        for g in groups {
            if case .group(let s, let e, _, _) = g {
                XCTAssertNotEqual(s, e, "Single-year group detected — should be a .full row")
            }
        }
    }
}
