//
//  MultiYearValueTypes.swift
//  RetireSmartIRA
//
//  Value structs returned by or used within the Multi-Year Tax Strategy engine.
//

import Foundation

// MARK: - TaxBreakdown

struct TaxBreakdown: Codable, Equatable {
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

struct ConstraintHit: Codable, Equatable {
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

struct TaxImpact: Codable, Equatable {
    let baselineLifetimeTax: Double
    let scenarioLifetimeTax: Double

    init(baselineLifetimeTax: Double, scenarioLifetimeTax: Double) {
        self.baselineLifetimeTax = baselineLifetimeTax
        self.scenarioLifetimeTax = scenarioLifetimeTax
    }

    var delta: Double { scenarioLifetimeTax - baselineLifetimeTax }
}

// MARK: - ClaimAgeFlag

struct ClaimAgeFlag: Codable, Equatable {
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

struct SensitivityBands: Codable, Equatable {
    let optimistic: [YearRecommendation]
    let average: [YearRecommendation]
    let pessimistic: [YearRecommendation]

    init(optimistic: [YearRecommendation], average: [YearRecommendation], pessimistic: [YearRecommendation]) {
        self.optimistic = optimistic
        self.average = average
        self.pessimistic = pessimistic
    }
}
