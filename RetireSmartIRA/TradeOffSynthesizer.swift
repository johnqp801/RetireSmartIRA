//
//  TradeOffSynthesizer.swift
//  RetireSmartIRA
//
//  Collapses raw ConstraintHit events into a deduplicated, plain-English
//  list for the trade-offs UI. Pure logic; no SwiftUI.
//

import Foundation

/// One row in the "Trade-offs accepted" card, after dedup + plain-English templating.
struct SummarizedTradeOff: Equatable, Hashable {
    let year: Int
    /// Plain-English WHAT: e.g. "IRMAA Tier 4 premium", "Bracket bump: 12% → 22%".
    let title: String
    /// Templated WHY: explains why the engine accepted this trade-off.
    let whyText: String
    /// Total accepted cost in dollars. For dedup'd rows this is the sum of the
    /// underlying ConstraintHit `cost` values (e.g. Part B + Part D for the same
    /// IRMAA tier in the same year).
    let costDollars: Double
}

enum TradeOffSynthesizer {

    /// Summarize a list of ConstraintHits.
    ///
    /// Dedup rule: hits with the same (year, ConstraintType) collapse into one row,
    /// summing their costs. Because `ConstraintType.irmaaTier(level:)` is a single
    /// combined case (no Part B / Part D distinction at the type level), two IRMAA
    /// hits for the same year and tier — which is how the engine emits the Part B /
    /// Part D split — naturally collapse into one row with summed cost.
    ///
    /// Output is sorted by year ascending, then by title.
    static func summarize(hits: [ConstraintHit]) -> [SummarizedTradeOff] {
        // Group by (year, normalized type key) to dedup.
        var buckets: [String: (year: Int, type: ConstraintType, total: Double)] = [:]
        var insertionOrder: [String] = []

        for hit in hits {
            let key = "\(hit.year)|\(typeKey(hit.type))"
            if let existing = buckets[key] {
                buckets[key] = (existing.year, existing.type, existing.total + hit.cost)
            } else {
                buckets[key] = (hit.year, hit.type, hit.cost)
                insertionOrder.append(key)
            }
        }

        let summarized = insertionOrder.compactMap { key -> SummarizedTradeOff? in
            guard let bucket = buckets[key] else { return nil }
            return SummarizedTradeOff(
                year: bucket.year,
                title: title(for: bucket.type),
                whyText: whyText(for: bucket.type),
                costDollars: bucket.total
            )
        }

        return summarized.sorted { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year < rhs.year }
            return lhs.title < rhs.title
        }
    }

    // MARK: - Type key (for dedup)

    private static func typeKey(_ type: ConstraintType) -> String {
        switch type {
        case .irmaaTier(let level):
            return "irmaa:\(level)"
        case .acaCliff:
            return "aca"
        case .bracketOverrun(let from, let to):
            return "bracket:\(from)->\(to)"
        }
    }

    // MARK: - WHAT title (plain English)

    private static func title(for type: ConstraintType) -> String {
        switch type {
        case .irmaaTier(let level):
            return "IRMAA Tier \(level) premium"
        case .acaCliff:
            return "ACA cliff"
        case .bracketOverrun(let from, let to):
            return "Bracket bump: \(from)% → \(to)%"
        }
    }

    // MARK: - WHY templates

    private static func whyText(for type: ConstraintType) -> String {
        switch type {
        case .bracketOverrun:
            return "Accepted to fit larger Roth conversions before RMDs raise your bracket later."
        case .irmaaTier:
            return "Accepted because conversion savings exceed the extra Medicare cost."
        case .acaCliff:
            return "Accepted because long-term tax savings exceed the lost subsidy."
        }
    }
}
