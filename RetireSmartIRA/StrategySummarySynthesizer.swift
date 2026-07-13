//
//  StrategySummarySynthesizer.swift
//  RetireSmartIRA
//

import Foundation

enum StrategySummarySynthesizer {

    static func synthesize(
        path: [YearRecommendation],
        tradeOffs: [ConstraintHit]
    ) -> String {
        guard !path.isEmpty else {
            return "No multi-year strategy computed yet."
        }

        var sentences: [String] = []

        if let clause = clusterRothConversions(in: path) {
            sentences.append(clause)
        }
        if let ssClause = describeSSClaims(in: path) {
            sentences.append(ssClause)
        }
        if let rmdClause = describeRMDPhase(in: path) {
            sentences.append(rmdClause)
        }
        if !tradeOffs.isEmpty {
            sentences.append(describeTradeOffs(tradeOffs))
        }

        if sentences.isEmpty {
            return "Strategy computed for \(path.count) year(s)."
        }

        return sentences.joined(separator: " ")
    }

    private static func clusterRothConversions(in path: [YearRecommendation]) -> String? {
        // Reads the EXECUTED conversion, not the REQUESTED `.rothConversion` action amount,
        // which can exceed it once an IRA drains or an RMD reservation clamps a spouse's
        // convertible balance (B4).
        let rothYears: [(year: Int, amount: Double)] = path.compactMap { y in
            y.executedRothConversion > 0 ? (y.year, y.executedRothConversion) : nil
        }
        guard !rothYears.isEmpty else { return nil }

        let first = rothYears.first!.year
        let last = rothYears.last!.year
        let amounts = rothYears.map { $0.amount }
        let minAmt = (amounts.min() ?? 0) / 1000
        let maxAmt = (amounts.max() ?? 0) / 1000

        let amtPhrase: String
        if minAmt == maxAmt {
            amtPhrase = "$\(Int(minAmt))K/yr"
        } else {
            amtPhrase = "$\(Int(minAmt))–$\(Int(maxAmt))K/yr"
        }

        let rangePhrase: String
        if first == last {
            rangePhrase = "in \(first)"
        } else {
            rangePhrase = "from \(first) through \(last)"
        }

        return "Convert \(amtPhrase) to Roth \(rangePhrase)."
    }

    private static func describeSSClaims(in path: [YearRecommendation]) -> String? {
        var primaryYear: Int?
        var spouseYear: Int?
        for y in path {
            for action in y.actions {
                if case .claimSocialSecurity(let spouse) = action {
                    if spouse == .primary { primaryYear = y.year }
                    if spouse == .spouse { spouseYear = y.year }
                }
            }
        }
        switch (primaryYear, spouseYear) {
        case (.some(let p), .some(let s)) where p == s:
            return "Both spouses claim SS in \(p)."
        case (.some(let p), .some(let s)):
            return "Claim SS in \(p) (you) and \(s) (spouse)."
        case (.some(let p), nil):
            return "Claim SS in \(p)."
        case (nil, .some(let s)):
            return "Spouse claims SS in \(s)."
        case (nil, nil):
            return nil
        }
    }

    private static func describeRMDPhase(in path: [YearRecommendation]) -> String? {
        for y in path {
            for action in y.actions {
                if case .traditionalWithdrawal = action {
                    return "RMD-fill the bracket starting in \(y.year)."
                }
            }
        }
        return nil
    }

    private static func describeTradeOffs(_ hits: [ConstraintHit]) -> String {
        let count = hits.count
        if count == 1 {
            let h = hits[0]
            switch h.type {
            case .irmaaTier(let level):
                return "Accepts 1 IRMAA Tier \(level) hit at \(h.year)."
            case .acaCliff:
                return "Accepts 1 ACA cliff hit at \(h.year)."
            case .bracketOverrun(let from, let to):
                return "Accepts 1 \(from)% → \(to)% bracket overrun at \(h.year)."
            }
        }
        return "Accepts \(count) trade-offs (see Trade-offs accepted card for detail)."
    }
}
