//
//  TaxModels.swift
//  RetireSmartIRA
//
//  Tax-related data models extracted from DataManager.
//

import Foundation

struct TaxBracket: Codable, Identifiable {
    var id = UUID()
    var threshold: Double
    var rate: Double
}

struct TaxBrackets: Codable {
    var federalSingle: [TaxBracket]
    var federalMarried: [TaxBracket]
    var federalCapGainsSingle: [TaxBracket]
    var federalCapGainsMarried: [TaxBracket]
    // Note: State brackets moved to StateTaxData.swift for multi-state support
}

// MARK: - IRMAA (Medicare Premium Surcharge) Models

/// A single IRMAA tier with cliff thresholds and premium amounts.
/// Unlike tax brackets, IRMAA is cliff-based: crossing a threshold by $1
/// triggers the FULL surcharge for that tier.
struct IRMAATier {
    let tier: Int                // 0 = standard (no surcharge), 1–5 = surcharge tiers
    let singleThreshold: Double  // MAGI threshold for Single filers
    let mfjThreshold: Double     // MAGI threshold for Married Filing Jointly
    let partBMonthly: Double     // Total Part B monthly premium at this tier
    let partDMonthly: Double     // Part D monthly surcharge at this tier
}

/// Result of an IRMAA tier lookup for a given MAGI.
struct IRMAAResult {
    let tier: Int
    let annualSurchargePerPerson: Double  // (Part B surcharge + Part D surcharge) × 12
    let monthlyPartB: Double
    let monthlyPartD: Double
    let distanceToNextTier: Double?       // $ until next cliff (nil if top tier)
    let distanceToPreviousTier: Double?   // $ above current tier threshold (nil if tier 0)
    let magi: Double
}

/// Result of a NIIT calculation (IRC §1411 — 3.8% Net Investment Income Tax).
/// NIIT = 3.8% × min(Net Investment Income, max(0, MAGI − threshold))
struct NIITResult {
    let netInvestmentIncome: Double      // Total NII from qualifying sources
    let magi: Double                     // MAGI used for threshold comparison
    let threshold: Double                // $200K Single / $250K MFJ
    let magiExcess: Double               // max(0, MAGI - threshold)
    let taxableNII: Double               // min(NII, magiExcess) — the base for 3.8%
    let annualNIITax: Double             // taxableNII × 0.038
    let distanceToThreshold: Double      // threshold - MAGI (positive = below, negative = above)
}

/// Result of an AMT calculation (IRC §55 — Alternative Minimum Tax).
/// AMT = max(0, tentativeMinimumTax − regularTax)
struct AMTResult {
    let amti: Double                    // Alternative Minimum Taxable Income
    let exemption: Double               // After phaseout
    let taxableAMTI: Double             // max(0, AMTI - exemption)
    let tentativeMinimumTax: Double     // 26%/28% on taxableAMTI
    let regularTax: Double              // Regular federal tax for comparison
    let amt: Double                     // max(0, TMT - regularTax)
}

/// Detailed breakdown of federal tax calculation showing bracket-by-bracket math.
struct FederalTaxBreakdown {
    let ordinaryIncome: Double
    let preferentialIncome: Double      // qualified dividends + long-term cap gains
    let ordinaryBrackets: [BracketLine]
    let ordinaryTax: Double
    let capGainsBrackets: [BracketLine] // only filled if preferentialIncome > 0
    let capGainsTax: Double
    let totalFederalTax: Double

    struct BracketLine: Identifiable {
        let id = UUID()
        let rate: Double
        let bracketFloor: Double
        let bracketCeiling: Double?     // nil = top bracket
        let taxableInBracket: Double
        let taxFromBracket: Double
    }
}

/// Detailed breakdown of state tax calculation for a specific state.
/// Used by the State Comparison detail sheet to explain WHY a state's tax is what it is.
struct StateTaxBreakdown {
    let state: USState
    let totalIncome: Double                   // scenarioTaxableIncome

    // Income by category (raw amounts before exemptions)
    let socialSecurityIncome: Double
    let pensionIncome: Double
    let iraRmdIncome: Double
    let otherIncome: Double

    // Exemption results per category
    let socialSecurityExempt: Bool
    let socialSecurityExemptAmount: Double
    let pensionExemptionLevel: RetirementIncomeExemptions.ExemptionLevel
    let pensionExemptAmount: Double
    let iraExemptionLevel: RetirementIncomeExemptions.ExemptionLevel
    let iraExemptAmount: Double
    let capitalGainsTreatment: RetirementIncomeExemptions.CapGainsTreatment

    // After exemptions
    let totalExempted: Double
    let adjustedTaxableIncome: Double

    // Tax calculation detail
    let taxSystemDescription: String          // "No income tax" / "Flat 4.95%" / "Progressive 2%–9.9%"
    let bracketBreakdown: [BracketDetail]     // empty for flat/no-tax states
    let flatRate: Double?                     // only for flat-tax states
    let totalStateTax: Double
    let effectiveRate: Double                 // (totalStateTax / totalIncome) * 100

    struct BracketDetail: Identifiable {
        let id = UUID()
        let bracketFloor: Double
        let bracketCeiling: Double?           // nil for top bracket
        let rate: Double
        let taxableInBracket: Double
        let taxFromBracket: Double            // taxableInBracket * rate
    }
}

struct RothConversionAnalysis {
    let conversionAmount: Double
    let federalTax: Double
    let stateTax: Double
    let totalTax: Double
    let effectiveRate: Double
}

struct BracketInfo {
    let currentRate: Double        // decimal, e.g. 0.22
    let currentThreshold: Double   // lower bound of current bracket
    let nextThreshold: Double      // upper bound (Double.infinity if top bracket)
    let roomRemaining: Double      // nextThreshold - income (0 if top bracket)
}

struct EnhancedRothConversionAnalysis {
    let conversionAmount: Double
    let federalTax: Double
    let stateTax: Double
    let totalTax: Double

    // Per-tax-system effective rates on the conversion
    let federalEffectiveRate: Double
    let stateEffectiveRate: Double
    let combinedEffectiveRate: Double

    // Marginal rates before/after (as percentages)
    let federalMarginalBefore: Double
    let federalMarginalAfter: Double
    let stateMarginalBefore: Double
    let stateMarginalAfter: Double

    // Bracket detail
    let federalBracketBefore: BracketInfo
    let federalBracketAfter: BracketInfo
    let stateBracketBefore: BracketInfo
    let stateBracketAfter: BracketInfo

    let crossesFederalBracket: Bool
    let crossesStateBracket: Bool
}

struct ScenarioTaxAnalysis {
    let baseIncome: Double
    let scenarioIncome: Double
    let additionalIncome: Double

    let federalTax: Double
    let stateTax: Double
    let totalTax: Double
    let effectiveRate: Double

    let federalMarginalBefore: Double   // percentage
    let federalMarginalAfter: Double
    let stateMarginalBefore: Double
    let stateMarginalAfter: Double

    let federalEffectiveRate: Double    // decimal
    let stateEffectiveRate: Double

    let federalBracketBefore: BracketInfo
    let federalBracketAfter: BracketInfo
    let stateBracketBefore: BracketInfo
    let stateBracketAfter: BracketInfo

    let crossesFederalBracket: Bool
    let crossesStateBracket: Bool
}

// MARK: - Medicare Plan Type (1.9)

/// Medicare plan type per spouse. Drives `MedicareCostEngine` cost composition
/// and HSA-eligibility gating (HSA requires HDHP coverage incompatible with Medicare).
enum MedicarePlanType: String, Codable, CaseIterable {
    case preMedicare = "Pre-Medicare"
    case originalMedicare = "Original Medicare (A+B)"
    case medicareAdvantage = "Medicare Advantage (Part C)"
}

// MARK: - Strongly-Typed AGI Variants (1.9)

/// Federal AGI as filed on Form 1040 Line 11. Distinct nominal type to prevent
/// callers from passing the wrong MAGI variant into ACA/IRMAA engines.
struct FederalAGI: Equatable {
    let value: Double
}

/// MAGI used for ACA Marketplace subsidy computation:
/// `FederalAGI + tax-exempt interest + non-taxable Social Security benefits`.
/// (Form 8962.)
struct ACAMAGI: Equatable {
    let value: Double
}

/// MAGI used for Medicare IRMAA tier lookup:
/// `FederalAGI + tax-exempt interest`.
struct IRMAAMAGI: Equatable {
    let value: Double
}

// MARK: - Scenario Warnings (1.9 — engine in ScenarioWarningEngine.swift, Phase 5)

struct ScenarioWarning: Equatable {
    enum Category: String {
        case acaCliff
        case acaApproaching
        case irmaaTierCrossing
        case irmaaApproaching
        case niitCrossing
        case bracketCrossing
        case widowBracketJump
    }
    enum Timing: String {
        case currentYear
        case twoYearsOut
    }
    enum Severity: String {
        case warning
        case info
    }

    let category: Category
    let timing: Timing
    let severity: Severity
    let dollarImpactPerYear: Double
    let messageHeadline: String
    let messageDetail: String
}
