//
//  YearListGrouping.swift
//  RetireSmartIRA
//

import Foundation

enum YearListRow {
    case full(YearRecommendation, TransitionBadge)
    case group(startYear: Int, endYear: Int, tier: Int, taxRange: ClosedRange<Double>)
}

enum TransitionBadge: Equatable {
    case currentYear
    case entersTier(Int)
    case dropsToTier(Int)
    case noChange
}

enum YearListGrouping {

    static func group(
        path: [YearRecommendation],
        currentYear: Int,
        tierFor: (YearRecommendation) -> Int
    ) -> [YearListRow] {
        guard !path.isEmpty else { return [] }

        var rows: [YearListRow] = []
        var groupStart: Int? = nil
        var groupTier: Int = 0
        var groupMinTax: Double = .infinity
        var groupMaxTax: Double = 0
        var prevTier: Int? = nil

        func flushGroup(endYear: Int) {
            guard let start = groupStart else { return }
            let groupEndYear = endYear - 1
            if groupEndYear > start {
                // 2+ years — emit a collapsed group row
                rows.append(.group(
                    startYear: start,
                    endYear: groupEndYear,
                    tier: groupTier,
                    taxRange: groupMinTax...groupMaxTax
                ))
            } else if groupEndYear == start {
                // Single year — emit as a full row with .noChange
                if let singleRec = path.first(where: { $0.year == start }) {
                    rows.append(.full(singleRec, .noChange))
                }
            }
            groupStart = nil
            groupMinTax = .infinity
            groupMaxTax = 0
        }

        for rec in path {
            let tier = tierFor(rec)
            let isCurrentYear = rec.year == currentYear

            if isCurrentYear {
                flushGroup(endYear: rec.year)
                rows.append(.full(rec, .currentYear))
                prevTier = tier
                continue
            }

            let isTransition = (prevTier != nil) && (tier != prevTier!)
            if isTransition {
                flushGroup(endYear: rec.year)
                let badge: TransitionBadge = tier > prevTier! ? .entersTier(tier) : .dropsToTier(tier)
                rows.append(.full(rec, badge))
                prevTier = tier
                continue
            }

            if groupStart == nil {
                groupStart = rec.year
                groupTier = tier
            }
            groupMinTax = min(groupMinTax, rec.taxBreakdown.total)
            groupMaxTax = max(groupMaxTax, rec.taxBreakdown.total)
            prevTier = tier
        }

        flushGroup(endYear: (path.last?.year ?? 0) + 1)
        return rows
    }
}
