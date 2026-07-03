//
//  MultiYearValueTypes.swift
//  RetireSmartIRA
//
//  Value structs returned by or used within the Multi-Year Tax Strategy engine.
//

import Foundation

// MARK: - TaxBreakdown

struct TaxBreakdown: Codable, Equatable, Sendable {
    let federal: Double
    let state: Double
    let irmaa: Double
    let acaPremiumImpact: Double  // negative = subsidy savings, positive = cliff cost

    init(federal: Double, state: Double, irmaa: Double, acaPremiumImpact: Double) {
        self.federal = federal
        self.state = state
        self.irmaa = irmaa
        self.acaPremiumImpact = acaPremiumImpact
    }

    var total: Double { federal + state + irmaa + acaPremiumImpact }

    static let zero = TaxBreakdown(federal: 0, state: 0, irmaa: 0, acaPremiumImpact: 0)
}

// MARK: - ConstraintHit

struct ConstraintHit: Codable, Equatable, Sendable {
    let year: Int
    let type: ConstraintType
    let cost: Double
    let acceptanceRationale: String

    init(year: Int, type: ConstraintType, cost: Double, acceptanceRationale: String) {
        self.year = year
        self.type = type
        self.cost = cost
        self.acceptanceRationale = acceptanceRationale
    }
}

// MARK: - TaxImpact

struct TaxImpact: Codable, Equatable, Sendable {
    let baselineLifetimeTax: Double
    let scenarioLifetimeTax: Double

    init(baselineLifetimeTax: Double, scenarioLifetimeTax: Double) {
        self.baselineLifetimeTax = baselineLifetimeTax
        self.scenarioLifetimeTax = scenarioLifetimeTax
    }

    /// `delta > 0` means the scenario is worse than baseline (more lifetime tax).
    /// Used by `widowStressDelta` where positive = surviving spouse pays more.
    var delta: Double { scenarioLifetimeTax - baselineLifetimeTax }
}

// MARK: - ClaimAgeFlag

struct ClaimAgeFlag: Codable, Equatable, Sendable {
    let spouse: SpouseID
    let currentClaimAge: Int
    let suggestedClaimAge: Int
    let estimatedLifetimeTaxDelta: Double  // negative = savings

    init(spouse: SpouseID, currentClaimAge: Int, suggestedClaimAge: Int, estimatedLifetimeTaxDelta: Double) {
        self.spouse = spouse
        self.currentClaimAge = currentClaimAge
        self.suggestedClaimAge = suggestedClaimAge
        self.estimatedLifetimeTaxDelta = estimatedLifetimeTaxDelta
    }
}

// MARK: - SensitivityBands

/// Deterministic **growth-rate sensitivity** for the plan: the optimizer re-run at
/// average / average−2pp / average+2pp constant growth. This is a sensitivity band, NOT a
/// risk model — it is not Monte Carlo, not sequence-of-returns risk, and not a
/// probability-of-success estimate. UI must label it as growth sensitivity, never as
/// "risk" or "odds of success" (the engine is positioned as a tax optimizer, not a
/// longevity/ruin-probability tool).
struct SensitivityBands: Codable, Equatable, Sendable {
    let optimistic: [YearRecommendation]   // higher constant growth (avg + 2pp)
    let average: [YearRecommendation]      // the recommended plan at the average growth rate
    let pessimistic: [YearRecommendation]  // lower constant growth (avg − 2pp, clamped ≥ 0%)

    init(optimistic: [YearRecommendation], average: [YearRecommendation], pessimistic: [YearRecommendation]) {
        self.optimistic = optimistic
        self.average = average
        self.pessimistic = pessimistic
    }
}
