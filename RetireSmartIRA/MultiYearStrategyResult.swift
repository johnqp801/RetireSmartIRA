//
//  MultiYearStrategyResult.swift
//  RetireSmartIRA
//
//  Top-level output of the Multi-Year Tax Strategy engine.
//

import Foundation

struct MultiYearStrategyResult: Codable, Equatable {
    let recommendedPath: [YearRecommendation]
    let tradeOffsAccepted: [ConstraintHit]
    let sensitivityBands: SensitivityBands
    let widowStressDelta: TaxImpact
    let ssClaimNudge: ClaimAgeFlag?

    init(
        recommendedPath: [YearRecommendation],
        tradeOffsAccepted: [ConstraintHit],
        sensitivityBands: SensitivityBands,
        widowStressDelta: TaxImpact,
        ssClaimNudge: ClaimAgeFlag?
    ) {
        self.recommendedPath = recommendedPath
        self.tradeOffsAccepted = tradeOffsAccepted
        self.sensitivityBands = sensitivityBands
        self.widowStressDelta = widowStressDelta
        self.ssClaimNudge = ssClaimNudge
    }

    /// Sum of tax breakdown totals across the recommended path.
    var lifetimeTaxFromRecommendedPath: Double {
        recommendedPath.reduce(0.0) { $0 + $1.taxBreakdown.total }
    }
}
