//
//  SSModels.swift
//  RetireSmartIRA
//
//  Data models for the Social Security Planner feature
//

import Foundation

// MARK: - Persisted Models

/// User's Social Security benefit estimates from their SSA statement
struct SSBenefitEstimate: Codable, Identifiable {
    var id = UUID()
    var owner: Owner
    var benefitAt62: Double         // Monthly benefit at age 62
    var benefitAtFRA: Double        // Monthly benefit at Full Retirement Age
    var benefitAt70: Double         // Monthly benefit at age 70
    var plannedClaimingAge: Int     // 62-70
    var plannedClaimingMonth: Int   // 0-11 within claiming year
    var isAlreadyClaiming: Bool     // true if user is already receiving SS
    var currentBenefit: Double      // Current monthly benefit (for already-claiming users)

    init(owner: Owner, benefitAt62: Double = 0, benefitAtFRA: Double = 0, benefitAt70: Double = 0,
         plannedClaimingAge: Int = 67, plannedClaimingMonth: Int = 0,
         isAlreadyClaiming: Bool = false, currentBenefit: Double = 0) {
        self.owner = owner
        self.benefitAt62 = benefitAt62
        self.benefitAtFRA = benefitAtFRA
        self.benefitAt70 = benefitAt70
        self.plannedClaimingAge = plannedClaimingAge
        self.plannedClaimingMonth = plannedClaimingMonth
        self.isAlreadyClaiming = isAlreadyClaiming
        self.currentBenefit = currentBenefit
    }

    // Backward-compatible Codable decoding for existing persisted data
    enum CodingKeys: String, CodingKey {
        case id, owner, benefitAt62, benefitAtFRA, benefitAt70
        case plannedClaimingAge, plannedClaimingMonth
        case isAlreadyClaiming, currentBenefit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        owner = try c.decode(Owner.self, forKey: .owner)
        benefitAt62 = try c.decode(Double.self, forKey: .benefitAt62)
        benefitAtFRA = try c.decode(Double.self, forKey: .benefitAtFRA)
        benefitAt70 = try c.decode(Double.self, forKey: .benefitAt70)
        plannedClaimingAge = try c.decode(Int.self, forKey: .plannedClaimingAge)
        plannedClaimingMonth = try c.decode(Int.self, forKey: .plannedClaimingMonth)
        isAlreadyClaiming = try c.decodeIfPresent(Bool.self, forKey: .isAlreadyClaiming) ?? false
        currentBenefit = try c.decodeIfPresent(Double.self, forKey: .currentBenefit) ?? 0
    }

    var hasData: Bool {
        isAlreadyClaiming ? currentBenefit > 0 : (benefitAt62 > 0 || benefitAtFRA > 0 || benefitAt70 > 0)
    }

    /// Annual benefit at the planned claiming age (requires birth year for FRA)
    func plannedAnnualBenefit(birthYear: Int) -> Double {
        benefitAtPlannedAge(birthYear: birthYear) * 12
    }

    /// Monthly benefit at the planned claiming age (requires birth year for FRA)
    func benefitAtPlannedAge(birthYear: Int) -> Double {
        if isAlreadyClaiming { return currentBenefit }
        guard benefitAtFRA > 0 else { return 0 }
        let fra = SSCalculationEngine.fullRetirementAge(birthYear: birthYear)
        return SSCalculationEngine.benefitAtAge(
            claimingAge: plannedClaimingAge,
            claimingMonth: plannedClaimingMonth,
            pia: benefitAtFRA,
            fraYears: fra.years, fraMonths: fra.months
        )
    }
}

/// A single year of earnings from the SSA record
struct SSEarningsRecord: Codable, Identifiable {
    var id = UUID()
    var year: Int
    var earnings: Double
}

/// Complete earnings history for AIME/PIA calculation (Phase 3)
struct SSEarningsHistory: Codable {
    var owner: Owner
    var records: [SSEarningsRecord]
    var futureEarningsPerYear: Double
    var futureWorkYears: Int

    init(owner: Owner, records: [SSEarningsRecord] = [], futureEarningsPerYear: Double = 0, futureWorkYears: Int = 0) {
        self.owner = owner
        self.records = records
        self.futureEarningsPerYear = futureEarningsPerYear
        self.futureWorkYears = futureWorkYears
    }
}

/// What-if parameters for scenario modeling
struct SSWhatIfParameters: Codable, Equatable {
    var primaryLifeExpectancy: Int
    var spouseLifeExpectancy: Int
    var colaRate: Double            // Annual COLA percentage (e.g. 2.5)
    var discountRate: Double        // For present-value analysis (e.g. 0 for nominal)

    init(primaryLifeExpectancy: Int = 85, spouseLifeExpectancy: Int = 87,
         colaRate: Double = 2.5, discountRate: Double = 0) {
        self.primaryLifeExpectancy = primaryLifeExpectancy
        self.spouseLifeExpectancy = spouseLifeExpectancy
        self.colaRate = colaRate
        self.discountRate = discountRate
    }
}

// MARK: - Analysis Results (computed, not persisted)

/// Result of analyzing a single claiming age scenario
struct SSClaimingScenario: Identifiable {
    let id = UUID()
    var claimingAge: Int
    var claimingMonth: Int
    var monthlyBenefit: Double
    var annualBenefit: Double
    var cumulativeByAge: [(age: Int, cumulative: Double)]
    var breakEvenVs: [(vsAge: Int, breakEvenAge: Int?)]
    var label: String

    var isEarly: Bool { claimingAge < 67 }
    var isDelayed: Bool { claimingAge > 67 }
}

/// Chart data point for cumulative benefit visualization
struct SSCumulativeChartPoint: Identifiable {
    let id = UUID()
    var age: Int
    var cumulativeAmount: Double
    var scenarioLabel: String
}

/// Break-even comparison between two claiming scenarios
struct SSBreakEvenComparison: Identifiable {
    let id = UUID()
    var earlyAge: Int
    var laterAge: Int
    var breakEvenAge: Int?          // nil if later never catches up within life expectancy
    var earlyMonthly: Double
    var laterMonthly: Double
    var advantageAtLifeExpectancy: Double  // positive = later is better
}

// MARK: - Couples Strategy Results

/// A single cell in the couples claiming-age matrix
struct SSCouplesMatrixCell: Identifiable {
    let id = UUID()
    var primaryClaimingAge: Int
    var spouseClaimingAge: Int
    var primaryMonthly: Double          // With spousal top-up (if applicable)
    var spouseMonthly: Double           // With spousal top-up (if applicable)
    var primaryOwnMonthly: Double = 0   // Own record only (no spousal top-up)
    var spouseOwnMonthly: Double = 0    // Own record only (no spousal top-up)
    var combinedLifetimeBenefit: Double
    var survivorBenefitIfPrimaryDies: Double   // Monthly survivor benefit for spouse
    var survivorBenefitIfSpouseDies: Double     // Monthly survivor benefit for primary
    var isHighestLifetime: Bool
}

/// Summary of the highest-lifetime couples strategy
struct SSCouplesTopStrategy {
    var primaryClaimingAge: Int
    var spouseClaimingAge: Int
    var combinedLifetime: Double
    var rationale: String
    var monthlyWhileBothAlive: Double
    /// Monthly amounts with spousal top-up (once both have filed)
    var primaryMonthly: Double = 0
    var spouseMonthly: Double = 0
    /// Monthly amounts based on own record only (before spousal top-up kicks in)
    var primaryOwnMonthly: Double = 0
    var spouseOwnMonthly: Double = 0
}

// MARK: - Survivor Analysis Results

/// Scenario showing household income impact when one spouse dies
struct SSSurvivorScenario: Identifiable {
    let id = UUID()
    var title: String                           // e.g. "If primary dies first"
    var deceasedOwner: Owner
    var householdMonthlyBefore: Double          // Combined SS while both alive
    var householdMonthlyAfter: Double           // Survivor's SS after death
    var monthlyReduction: Double                // How much income drops
    var percentReduction: Double                // Percentage drop
    var survivorBenefitSource: String           // "Own benefit" or "Survivor benefit"
    var filingStatusChange: String              // e.g. "MFJ → Single"
}

// MARK: - AIME/PIA Calculation Results

/// Result of computing PIA from earnings history
struct SSPIAResult {
    var aime: Int                       // Average Indexed Monthly Earnings (truncated)
    var pia: Double                     // Primary Insurance Amount (rounded to dime)
    var indexedEarnings: [(year: Int, actual: Double, indexed: Double)]
    var top35Years: [(year: Int, indexed: Double)]
    var totalIndexedEarnings: Double
    var bendPoint1: Double
    var bendPoint2: Double
    var yearsOfEarnings: Int            // Years with non-zero earnings
    var zeroPaddedYears: Int            // 35 minus years of earnings (if < 35)

    /// PIA-derived benefit estimates for comparison with SSA statement
    func benefitAt62(birthYear: Int) -> Double {
        let fra = SSCalculationEngine.fullRetirementAge(birthYear: birthYear)
        return SSCalculationEngine.benefitAtAge(claimingAge: 62, pia: pia,
                                                 fraYears: fra.years, fraMonths: fra.months)
    }

    func benefitAtFRA(birthYear: Int) -> Double {
        return pia
    }

    func benefitAt70(birthYear: Int) -> Double {
        let fra = SSCalculationEngine.fullRetirementAge(birthYear: birthYear)
        return SSCalculationEngine.benefitAtAge(claimingAge: 70, pia: pia,
                                                 fraYears: fra.years, fraMonths: fra.months)
    }
}

// MARK: - Parse Results

enum SSParseError: Error {
    case noValidRows
    case partialParse(valid: [SSEarningsRecord], skippedLines: [String])
}

struct SSParseResult {
    var records: [SSEarningsRecord]
    var skippedLines: [String]
    var zeroYears: [Int]            // Years with $0 earnings
    var capYears: [Int]             // Years that hit the SS taxable maximum
}
