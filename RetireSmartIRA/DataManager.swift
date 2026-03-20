//
//  DataManager.swift
//  RetireSmartIRA
//
//  Manages all user financial data and performs calculations
//

import SwiftUI
import Foundation
import Combine

class DataManager: ObservableObject {
    // User Profile
    @Published var birthDate: Date = {
        var c = DateComponents(); c.year = 1953; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!
    }()
    @Published var currentYear: Int = Calendar.current.component(.year, from: Date())
    @Published var filingStatus: FilingStatus = .single
    @Published var selectedState: USState = .california
    @Published var userName: String = ""
    @Published var spouseName: String = ""
    @Published var spouseBirthDate: Date = {
        var c = DateComponents(); c.year = 1955; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!
    }()
    @Published var enableSpouse: Bool = false  // Toggle to enable spouse features
    
    // IRA Accounts
    @Published var iraAccounts: [IRAAccount] = []
    
    // Income Sources
    @Published var incomeSources: [IncomeSource] = []
    
    // Quarterly Tax Payments
    @Published var quarterlyPayments: [QuarterlyPayment] = []

    // MARK: - Tax Planning Scenario State (shared across tabs)
    @Published var yourRothConversion: Double = 0
    @Published var spouseRothConversion: Double = 0
    @Published var yourExtraWithdrawal: Double = 0
    @Published var spouseExtraWithdrawal: Double = 0
    @Published var yourQCDAmount: Double = 0
    @Published var spouseQCDAmount: Double = 0
    @Published var yourWithdrawalQuarter: Int = 4       // 1-4, Q4 default (Dec 31 pattern)
    @Published var spouseWithdrawalQuarter: Int = 4
    @Published var yourRothConversionQuarter: Int = 4
    @Published var spouseRothConversionQuarter: Int = 4
    @Published var stockDonationEnabled: Bool = false
    @Published var stockPurchasePrice: Double = 0
    @Published var stockCurrentValue: Double = 0
    @Published var stockPurchaseDate: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
    @Published var cashDonationAmount: Double = 0
    @Published var inheritedExtraWithdrawals: [UUID: Double] = [:]  // accountId → extra withdrawal amount
    @Published var deductionOverride: DeductionChoice? = nil  // nil = auto-pick best
    @Published var completedActionKeys: Set<String> = []

    // RMD Projection Growth Rates (pretax return — applies to both Traditional & Roth)
    @Published var primaryGrowthRate: Double = 8.0
    @Published var spouseGrowthRate: Double = 8.0

    // Legacy Planning
    @Published var enableLegacyPlanning: Bool = false
    @Published var legacyHeirType: String = "adultChild"   // "spouse", "adultChild", "other"
    @Published var legacyHeirTaxRate: Double = 0.24         // heir's estimated federal tax rate
    @Published var legacySpouseSurvivorYears: Int = 10      // years spouse lives after owner dies (spouseThenChild)

    /// After-tax return on money kept in a taxable account (opportunity cost of conversion).
    /// Derived as 5/8 of the pretax investment return to reflect tax drag.
    var taxableAccountGrowthRate: Double {
        primaryGrowthRate * 5.0 / 8.0
    }

    // Prior Year State Tax
    @Published var priorYearStateBalance: Double = 0  // positive = balance due paid; negative = refund

    // Itemized Deductions
    @Published var deductionItems: [DeductionItem] = []

    // MARK: - Tax Bracket Models
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

    // MARK: - Tax Bracket Storage
    @Published var currentTaxBrackets: TaxBrackets
    
    // Initialize with 2026 defaults (IRS Rev. Proc. 2025-32, OBBBA-adjusted)
    static let default2026Brackets = TaxBrackets(
        federalSingle: [
            TaxBracket(threshold: 0, rate: 0.10),
            TaxBracket(threshold: 12_400, rate: 0.12),
            TaxBracket(threshold: 50_400, rate: 0.22),
            TaxBracket(threshold: 105_700, rate: 0.24),
            TaxBracket(threshold: 201_775, rate: 0.32),
            TaxBracket(threshold: 256_225, rate: 0.35),
            TaxBracket(threshold: 640_600, rate: 0.37)
        ],
        federalMarried: [
            TaxBracket(threshold: 0, rate: 0.10),
            TaxBracket(threshold: 24_800, rate: 0.12),
            TaxBracket(threshold: 100_800, rate: 0.22),
            TaxBracket(threshold: 211_400, rate: 0.24),
            TaxBracket(threshold: 403_550, rate: 0.32),
            TaxBracket(threshold: 512_450, rate: 0.35),
            TaxBracket(threshold: 768_700, rate: 0.37)
        ],
        // State brackets moved to StateTaxData.swift for multi-state support
        federalCapGainsSingle: [
            TaxBracket(threshold: 0, rate: 0.0),
            TaxBracket(threshold: 49_450, rate: 0.15),
            TaxBracket(threshold: 545_500, rate: 0.20)
        ],
        federalCapGainsMarried: [
            TaxBracket(threshold: 0, rate: 0.0),
            TaxBracket(threshold: 98_900, rate: 0.15),
            TaxBracket(threshold: 613_700, rate: 0.20)
        ]
    )

    // MARK: - 2026 IRMAA Tier Data (CMS finalized)
    // Based on 2024 MAGI. Standard Part B premium: $202.90/month.
    static let irmaaStandardPartB: Double = 202.90

    static let irmaa2026Tiers: [IRMAATier] = [
        IRMAATier(tier: 0, singleThreshold: 0,       mfjThreshold: 0,       partBMonthly: 202.90, partDMonthly: 0),
        IRMAATier(tier: 1, singleThreshold: 109_001,  mfjThreshold: 218_001,  partBMonthly: 284.10, partDMonthly: 14.50),
        IRMAATier(tier: 2, singleThreshold: 137_001,  mfjThreshold: 274_001,  partBMonthly: 405.50, partDMonthly: 37.40),
        IRMAATier(tier: 3, singleThreshold: 171_001,  mfjThreshold: 342_001,  partBMonthly: 527.00, partDMonthly: 60.30),
        IRMAATier(tier: 4, singleThreshold: 205_001,  mfjThreshold: 410_001,  partBMonthly: 608.40, partDMonthly: 83.10),
        IRMAATier(tier: 5, singleThreshold: 500_001,  mfjThreshold: 750_001,  partBMonthly: 689.90, partDMonthly: 91.00),
    ]

    // MARK: - NIIT Constants (IRC §1411)
    // Net Investment Income Tax — 3.8% surtax, thresholds NOT indexed for inflation (fixed since 2013).
    static let niitRate: Double = 0.038
    static let niitThresholdSingle: Double = 200_000
    static let niitThresholdMFJ: Double = 250_000

    /// Income types that qualify as Net Investment Income under IRC §1411.
    static let niitQualifyingTypes: Set<IncomeType> = [
        .dividends, .qualifiedDividends, .interest,
        .capitalGainsShort, .capitalGainsLong
    ]

    // MARK: - AMT Constants (IRC §55)
    // Alternative Minimum Tax — 26%/28% rates with exemption phaseout.
    // 2026 values from IRS Rev. Proc. 2025-32; OBBBA raised phaseout thresholds.
    static let amtExemptionSingle: Double = 90_100
    static let amtExemptionMFJ: Double = 140_200
    static let amtPhaseoutThresholdSingle: Double = 500_000
    static let amtPhaseoutThresholdMFJ: Double = 1_000_000
    static let amtPhaseoutRate: Double = 0.50       // 50¢ per $1 of AMTI over threshold
    static let amt26PercentLimit: Double = 244_500  // AMTI above this → 28% rate
    static let amtRate26: Double = 0.26
    static let amtRate28: Double = 0.28

    // Computed Properties — derived from birthDate

    /// Extract birth year from birthDate for RMD age bracket calculation
    var birthYear: Int {
        Calendar.current.component(.year, from: birthDate)
    }

    var spouseBirthYear: Int {
        Calendar.current.component(.year, from: spouseBirthDate)
    }

    var currentAge: Int {
        currentYear - birthYear
    }

    var rmdAge: Int {
        // Born 1951-1959: RMD age is 73
        // Born 1960+: RMD age is 75
        if birthYear >= 1951 && birthYear <= 1959 {
            return 73
        } else if birthYear >= 1960 {
            return 75
        } else {
            return 72 // Born 1950 or earlier
        }
    }

    var yearsUntilRMD: Int {
        max(0, rmdAge - currentAge)
    }

    var isRMDRequired: Bool {
        currentAge >= rmdAge
    }

    /// Returns true if the given birth date results in age 70½ or older as of today.
    /// Age 70½ = exactly 6 calendar months after the 70th birthday.
    private func hasReachedAge70AndHalf(from dob: Date) -> Bool {
        let calendar = Calendar.current
        guard let seventieth = calendar.date(byAdding: .year, value: 70, to: dob) else { return false }
        guard let seventyAndHalf = calendar.date(byAdding: .month, value: 6, to: seventieth) else { return false }
        return Date() >= seventyAndHalf
    }

    var isQCDEligible: Bool {
        hasReachedAge70AndHalf(from: birthDate)
    }

    // Spouse Computed Properties

    var spouseCurrentAge: Int {
        guard enableSpouse else { return 0 }
        return currentYear - spouseBirthYear
    }

    var spouseRmdAge: Int {
        guard enableSpouse else { return 0 }
        if spouseBirthYear >= 1951 && spouseBirthYear <= 1959 {
            return 73
        } else if spouseBirthYear >= 1960 {
            return 75
        } else {
            return 72
        }
    }

    var spouseYearsUntilRMD: Int {
        guard enableSpouse else { return 0 }
        return max(0, spouseRmdAge - spouseCurrentAge)
    }

    var spouseIsRMDRequired: Bool {
        guard enableSpouse else { return false }
        return spouseCurrentAge >= spouseRmdAge
    }

    var spouseIsQCDEligible: Bool {
        guard enableSpouse else { return false }
        return hasReachedAge70AndHalf(from: spouseBirthDate)
    }
    
    
    // Total IRA Balance
    var totalTraditionalIRABalance: Double {
        iraAccounts
            .filter { $0.accountType == .traditionalIRA || $0.accountType == .traditional401k }
            .reduce(0) { $0 + $1.balance }
    }
    
    var totalRothBalance: Double {
        iraAccounts
            .filter { $0.accountType == .rothIRA || $0.accountType == .roth401k }
            .reduce(0) { $0 + $1.balance }
    }
    
    // Balance by Owner
    var primaryTraditionalIRABalance: Double {
        iraAccounts
            .filter { ($0.accountType == .traditionalIRA || $0.accountType == .traditional401k) && $0.owner == .primary }
            .reduce(0) { $0 + $1.balance }
    }

    var spouseTraditionalIRABalance: Double {
        guard enableSpouse else { return 0 }
        return iraAccounts
            .filter { ($0.accountType == .traditionalIRA || $0.accountType == .traditional401k) && $0.owner == .spouse }
            .reduce(0) { $0 + $1.balance }
    }

    var primaryRothBalance: Double {
        iraAccounts
            .filter { ($0.accountType == .rothIRA || $0.accountType == .roth401k) && $0.owner == .primary }
            .reduce(0) { $0 + $1.balance }
    }

    var spouseRothBalance: Double {
        guard enableSpouse else { return 0 }
        return iraAccounts
            .filter { ($0.accountType == .rothIRA || $0.accountType == .roth401k) && $0.owner == .spouse }
            .reduce(0) { $0 + $1.balance }
    }

    // Inherited IRA Balances
    var primaryInheritedTraditionalBalance: Double {
        iraAccounts
            .filter { $0.accountType == .inheritedTraditionalIRA && $0.owner == .primary }
            .reduce(0) { $0 + $1.balance }
    }

    var spouseInheritedTraditionalBalance: Double {
        guard enableSpouse else { return 0 }
        return iraAccounts
            .filter { $0.accountType == .inheritedTraditionalIRA && $0.owner == .spouse }
            .reduce(0) { $0 + $1.balance }
    }

    var primaryInheritedRothBalance: Double {
        iraAccounts
            .filter { $0.accountType == .inheritedRothIRA && $0.owner == .primary }
            .reduce(0) { $0 + $1.balance }
    }

    var spouseInheritedRothBalance: Double {
        guard enableSpouse else { return 0 }
        return iraAccounts
            .filter { $0.accountType == .inheritedRothIRA && $0.owner == .spouse }
            .reduce(0) { $0 + $1.balance }
    }

    var totalInheritedBalance: Double {
        iraAccounts
            .filter { $0.accountType.isInherited }
            .reduce(0) { $0 + $1.balance }
    }

    /// All inherited IRA accounts
    var inheritedAccounts: [IRAAccount] {
        iraAccounts.filter { $0.accountType.isInherited }
    }

    /// Whether the user has any inherited IRA accounts
    var hasInheritedAccounts: Bool {
        iraAccounts.contains { $0.accountType.isInherited }
    }

    /// Extra withdrawals from inherited Traditional IRAs only (taxable as ordinary income)
    var inheritedTraditionalExtraTotal: Double {
        iraAccounts
            .filter { $0.accountType == .inheritedTraditionalIRA }
            .reduce(0) { $0 + (inheritedExtraWithdrawals[$1.id] ?? 0) }
    }

    /// Extra withdrawals from all inherited accounts (for display totals)
    var inheritedExtraWithdrawalTotal: Double {
        iraAccounts
            .filter { $0.accountType.isInherited }
            .reduce(0) { $0 + (inheritedExtraWithdrawals[$1.id] ?? 0) }
    }

    // MARK: - RMD Calculations
    
    func calculateRMD(for age: Int, balance: Double) -> Double {
        let divisor = lifeExpectancyFactor(for: age)
        return balance / divisor
    }
    
    // IRS Uniform Lifetime Table
    func lifeExpectancyFactor(for age: Int) -> Double {
        let table: [Int: Double] = [
            70: 29.1, 71: 28.2, 72: 27.4, 73: 26.5, 74: 25.5, 75: 24.6, 76: 23.7,
            77: 22.9, 78: 22.0, 79: 21.1, 80: 20.2, 81: 19.4,
            82: 18.5, 83: 17.7, 84: 16.8, 85: 16.0, 86: 15.2,
            87: 14.4, 88: 13.7, 89: 12.9, 90: 12.2, 91: 11.5,
            92: 10.8, 93: 10.1, 94: 9.5, 95: 8.9, 96: 8.4,
            97: 7.8, 98: 7.3, 99: 6.8, 100: 6.4, 101: 6.0,
            102: 5.6, 103: 5.2, 104: 4.9, 105: 4.6, 106: 4.3,
            107: 4.1, 108: 3.9, 109: 3.7, 110: 3.5, 111: 3.4,
            112: 3.3, 113: 3.1, 114: 3.0, 115: 2.9, 116: 2.8,
            117: 2.7, 118: 2.5, 119: 2.3, 120: 2.0
        ]
        
        return table[age] ?? 2.0 // Default to 2.0 for ages beyond table
    }

    // MARK: - IRS Single Life Expectancy Table I (for Inherited IRAs)

    /// IRS Single Life Expectancy Table I — used for inherited IRA RMD calculations.
    /// This is a DIFFERENT table from the Uniform Lifetime Table III used for regular RMDs.
    /// Updated per IRS regulations effective 2022+.
    func singleLifeExpectancyFactor(for age: Int) -> Double {
        let table: [Int: Double] = [
            0: 84.6, 1: 83.6, 2: 82.6, 3: 81.6, 4: 80.6,
            5: 79.7, 6: 78.7, 7: 77.7, 8: 76.7, 9: 75.8,
            10: 74.8, 11: 73.8, 12: 72.8, 13: 71.8, 14: 70.8,
            15: 69.9, 16: 68.9, 17: 67.9, 18: 66.9, 19: 66.0,
            20: 65.0, 21: 64.0, 22: 63.0, 23: 62.1, 24: 61.1,
            25: 60.2, 26: 59.2, 27: 58.2, 28: 57.3, 29: 56.3,
            30: 55.3, 31: 54.4, 32: 53.4, 33: 52.5, 34: 51.5,
            35: 50.5, 36: 49.6, 37: 48.6, 38: 47.7, 39: 46.7,
            40: 45.7, 41: 44.8, 42: 43.8, 43: 42.9, 44: 41.9,
            45: 41.0, 46: 40.0, 47: 39.0, 48: 38.1, 49: 37.1,
            50: 36.2, 51: 35.3, 52: 34.3, 53: 33.4, 54: 32.5,
            55: 31.6, 56: 30.6, 57: 29.8, 58: 28.9, 59: 28.0,
            60: 27.1, 61: 26.2, 62: 25.4, 63: 24.5, 64: 23.7,
            65: 22.9, 66: 22.0, 67: 21.2, 68: 20.4, 69: 19.6,
            70: 18.8, 71: 18.0, 72: 17.2, 73: 16.4, 74: 15.6,
            75: 14.8, 76: 14.1, 77: 13.3, 78: 12.6, 79: 11.9,
            80: 11.2, 81: 10.5, 82: 9.9, 83: 9.3, 84: 8.7,
            85: 8.1, 86: 7.5, 87: 7.1, 88: 6.6, 89: 6.1,
            90: 5.7, 91: 5.3, 92: 4.9, 93: 4.6, 94: 4.3,
            95: 4.0, 96: 3.7, 97: 3.4, 98: 3.2, 99: 2.9,
            100: 2.7, 101: 2.5, 102: 2.3, 103: 2.1, 104: 1.9,
            105: 1.8, 106: 1.6, 107: 1.4, 108: 1.3, 109: 1.1,
            110: 1.0, 111: 0.9, 112: 0.8, 113: 0.7, 114: 0.6,
            115: 0.5, 116: 0.4, 117: 0.3, 118: 0.2, 119: 0.1
        ]
        let clamped = max(0, min(119, age))
        return table[clamped] ?? 1.0
    }

    func calculatePrimaryRMD() -> Double {
        guard isRMDRequired else { return 0 }
        return calculateRMD(for: currentAge, balance: primaryTraditionalIRABalance)
    }

    func calculateSpouseRMD() -> Double {
        guard enableSpouse && spouseIsRMDRequired else { return 0 }
        return calculateRMD(for: spouseCurrentAge, balance: spouseTraditionalIRABalance)
    }

    func calculateCombinedRMD() -> Double {
        calculatePrimaryRMD() + calculateSpouseRMD()
    }

    // MARK: - Inherited IRA RMD Calculations

    struct InheritedRMDResult {
        let annualRMD: Double           // required withdrawal this year (0 if none)
        let mustEmptyByYear: Int?       // year account must be fully emptied (nil if lifetime stretch)
        let yearsRemaining: Int?        // years until must-empty deadline
        let rule: String                // human-readable description of the rule
    }

    /// Calculates the required distribution for an inherited IRA account in the given year.
    func calculateInheritedIRARMD(account: IRAAccount, forYear year: Int) -> InheritedRMDResult {
        guard account.accountType.isInherited,
              let beneficiaryType = account.beneficiaryType,
              let yearOfInheritance = account.yearOfInheritance,
              let beneficiaryBirthYear = account.beneficiaryBirthYear else {
            return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil, rule: "Missing inherited IRA data")
        }

        let yearsElapsed = year - yearOfInheritance
        let beneficiaryAge = year - beneficiaryBirthYear
        let isRothInherited = account.accountType == .inheritedRothIRA
        let deadline = yearOfInheritance + 10

        // Inherited Roth IRAs: EDBs get lifetime stretch (no RMDs, no deadline).
        // Non-EDBs get 10-year rule with no annual RMDs, just must empty by year 10.
        if isRothInherited {
            if beneficiaryType.isEligibleDesignated {
                // EDB Roth: no RMDs required, no deadline (lifetime stretch, tax-free)
                return InheritedRMDResult(
                    annualRMD: 0,
                    mustEmptyByYear: nil,
                    yearsRemaining: nil,
                    rule: "Eligible designated beneficiary — lifetime stretch, no RMDs (Roth)"
                )
            } else {
                // Non-EDB Roth: 10-year rule, no annual RMDs
                let remaining = max(0, deadline - year)
                if year >= deadline {
                    return InheritedRMDResult(
                        annualRMD: account.balance,
                        mustEmptyByYear: deadline,
                        yearsRemaining: 0,
                        rule: "10-year deadline reached — full balance must be withdrawn (Roth)"
                    )
                }
                return InheritedRMDResult(
                    annualRMD: 0,
                    mustEmptyByYear: deadline,
                    yearsRemaining: remaining,
                    rule: "10-year rule — no annual RMDs, must empty by \(deadline) (Roth)"
                )
            }
        }

        // Traditional Inherited IRA logic by beneficiary type
        switch beneficiaryType {
        case .spouse:
            // Spouse: lifetime stretch, recalculated annually using SLE Table I at beneficiary's current age
            guard yearsElapsed >= 1 else {
                return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil,
                                          rule: "Spouse — RMDs begin the year after inheritance")
            }
            let factor = singleLifeExpectancyFactor(for: beneficiaryAge)
            let rmd = factor > 0 ? account.balance / factor : account.balance
            return InheritedRMDResult(
                annualRMD: rmd,
                mustEmptyByYear: nil,
                yearsRemaining: nil,
                rule: "Spouse — lifetime stretch (SLE factor \(String(format: "%.1f", factor)) at age \(beneficiaryAge))"
            )

        case .disabled, .chronicallyIll:
            // Lifetime stretch using SLE Table I, recalculated annually
            guard yearsElapsed >= 1 else {
                return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil,
                                          rule: "\(beneficiaryType.rawValue) — RMDs begin the year after inheritance")
            }
            let factor = singleLifeExpectancyFactor(for: beneficiaryAge)
            let rmd = factor > 0 ? account.balance / factor : account.balance
            return InheritedRMDResult(
                annualRMD: rmd,
                mustEmptyByYear: nil,
                yearsRemaining: nil,
                rule: "\(beneficiaryType.rawValue) — lifetime stretch (SLE factor \(String(format: "%.1f", factor)) at age \(beneficiaryAge))"
            )

        case .notTenYearsYounger:
            // Lifetime stretch: initial SLE factor at beneficiary's age in year after death, reduced by 1 each year
            guard yearsElapsed >= 1 else {
                return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil,
                                          rule: "Not >10 years younger — RMDs begin the year after inheritance")
            }
            let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
            let initialFactor = singleLifeExpectancyFactor(for: initialAge)
            let yearsOfReduction = year - (yearOfInheritance + 1) // 0 in first RMD year
            let factor = max(1.0, initialFactor - Double(yearsOfReduction))
            let rmd = account.balance / factor
            return InheritedRMDResult(
                annualRMD: rmd,
                mustEmptyByYear: nil,
                yearsRemaining: nil,
                rule: "Not >10 years younger — lifetime stretch (factor \(String(format: "%.1f", factor)))"
            )

        case .minorChild:
            // SLE stretch until age 21, then 10-year rule kicks in
            let majorityYear = account.minorChildMajorityYear ?? (beneficiaryBirthYear + 21)
            if year < majorityYear {
                // Still a minor — SLE stretch
                guard yearsElapsed >= 1 else {
                    return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil,
                                              rule: "Minor child — RMDs begin the year after inheritance")
                }
                let factor = singleLifeExpectancyFactor(for: beneficiaryAge)
                let rmd = factor > 0 ? account.balance / factor : account.balance
                return InheritedRMDResult(
                    annualRMD: rmd,
                    mustEmptyByYear: nil,
                    yearsRemaining: nil,
                    rule: "Minor child — SLE stretch until age 21 (factor \(String(format: "%.1f", factor)))"
                )
            } else {
                // Reached majority — 10-year rule from majority year
                let tenYearDeadline = majorityYear + 10
                let remaining = max(0, tenYearDeadline - year)
                if year >= tenYearDeadline {
                    return InheritedRMDResult(
                        annualRMD: account.balance,
                        mustEmptyByYear: tenYearDeadline,
                        yearsRemaining: 0,
                        rule: "Minor child (now adult) — 10-year deadline reached, full balance due"
                    )
                }
                let rbdStatus = account.decedentRBDStatus ?? .beforeRBD
                if rbdStatus == .afterRBD {
                    // Annual RMDs required using SLE factor at age in year after majority, reduced by 1 each year
                    let ageAtMajorityPlus1 = (majorityYear + 1) - beneficiaryBirthYear
                    let initialFactor = singleLifeExpectancyFactor(for: ageAtMajorityPlus1)
                    let yearsOfReduction = year - (majorityYear + 1)
                    let factor = max(1.0, initialFactor - Double(max(0, yearsOfReduction)))
                    let rmd = account.balance / factor
                    return InheritedRMDResult(
                        annualRMD: rmd,
                        mustEmptyByYear: tenYearDeadline,
                        yearsRemaining: remaining,
                        rule: "Minor child (now adult) — annual RMDs + must empty by \(tenYearDeadline) (factor \(String(format: "%.1f", factor)))"
                    )
                } else {
                    return InheritedRMDResult(
                        annualRMD: 0,
                        mustEmptyByYear: tenYearDeadline,
                        yearsRemaining: remaining,
                        rule: "Minor child (now adult) — no annual RMDs, must empty by \(tenYearDeadline)"
                    )
                }
            }

        case .nonEligibleDesignated:
            // 10-year rule
            let remaining = max(0, deadline - year)
            let rbdStatus = account.decedentRBDStatus ?? .beforeRBD

            if year >= deadline {
                return InheritedRMDResult(
                    annualRMD: account.balance,
                    mustEmptyByYear: deadline,
                    yearsRemaining: 0,
                    rule: "10-year deadline reached — full balance must be withdrawn"
                )
            }

            if rbdStatus == .beforeRBD {
                // No annual RMDs, just 10-year emptying
                return InheritedRMDResult(
                    annualRMD: 0,
                    mustEmptyByYear: deadline,
                    yearsRemaining: remaining,
                    rule: "10-year rule (before RBD) — no annual RMDs, must empty by \(deadline)"
                )
            } else {
                // Annual RMDs years 1-9 using SLE, remaining balance in year 10
                guard yearsElapsed >= 1 else {
                    return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: deadline, yearsRemaining: remaining,
                                              rule: "10-year rule (after RBD) — RMDs begin the year after inheritance")
                }
                let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
                let initialFactor = singleLifeExpectancyFactor(for: initialAge)
                let yearsOfReduction = year - (yearOfInheritance + 1)
                let factor = max(1.0, initialFactor - Double(yearsOfReduction))
                let rmd = account.balance / factor
                return InheritedRMDResult(
                    annualRMD: rmd,
                    mustEmptyByYear: deadline,
                    yearsRemaining: remaining,
                    rule: "10-year rule (after RBD) — annual RMDs required, must empty by \(deadline) (factor \(String(format: "%.1f", factor)))"
                )
            }
        }
    }

    /// Total inherited IRA RMD across all inherited accounts for the current year
    var inheritedIRARMDTotal: Double {
        iraAccounts
            .filter { $0.accountType.isInherited }
            .reduce(0) { $0 + calculateInheritedIRARMD(account: $1, forYear: currentYear).annualRMD }
    }

    var primaryInheritedRMD: Double {
        iraAccounts
            .filter { $0.accountType.isInherited && $0.owner == .primary }
            .reduce(0) { $0 + calculateInheritedIRARMD(account: $1, forYear: currentYear).annualRMD }
    }

    var spouseInheritedRMD: Double {
        guard enableSpouse else { return 0 }
        return iraAccounts
            .filter { $0.accountType.isInherited && $0.owner == .spouse }
            .reduce(0) { $0 + calculateInheritedIRARMD(account: $1, forYear: currentYear).annualRMD }
    }

    // MARK: - Tax Calculations

    /// Progressive tax helper — applies bracket rates to income.
    private func progressiveTax(income: Double, brackets: [TaxBracket]) -> Double {
        var tax = 0.0
        for i in brackets.indices {
            let bracket = brackets[i]
            if income > bracket.threshold {
                let nextThreshold = i + 1 < brackets.count ? brackets[i + 1].threshold : income
                let taxableAtThisRate = min(income, nextThreshold) - bracket.threshold
                tax += taxableAtThisRate * bracket.rate
            }
        }
        return tax
    }

    func calculateFederalTax(income: Double, filingStatus: FilingStatus = .single) -> Double {
        let capGains = max(0, preferentialIncome())
        let ordinaryIncome = max(0, income - capGains)

        // Tax on ordinary income using ordinary brackets
        let ordinaryBrackets = filingStatus == .single
            ? currentTaxBrackets.federalSingle : currentTaxBrackets.federalMarried
        var tax = progressiveTax(income: ordinaryIncome, brackets: ordinaryBrackets)

        // Tax on cap gains using preferential brackets, stacked on top of ordinary
        if capGains > 0 {
            let capGainsBrackets = filingStatus == .single
                ? currentTaxBrackets.federalCapGainsSingle : currentTaxBrackets.federalCapGainsMarried
            let taxOnTotal = progressiveTax(income: income, brackets: capGainsBrackets)
            let taxOnOrdinary = progressiveTax(income: ordinaryIncome, brackets: capGainsBrackets)
            tax += taxOnTotal - taxOnOrdinary
        }

        return tax
    }

    // MARK: - Multi-State Tax Calculation

    /// The tax configuration for the user's selected state of residence.
    var selectedStateConfig: StateTaxConfig {
        StateTaxData.config(for: selectedState)
    }

    /// Calculates state income tax for the selected state, applying retirement income exemptions.
    /// Calculates state tax using pre-deduction income for the selected state.
    /// Applies the state's own standard deduction and retirement exemptions.
    func calculateStateTax(income: Double, filingStatus: FilingStatus = .single) -> Double {
        calculateStateTax(income: income, forState: selectedState, filingStatus: filingStatus)
    }

    /// Calculates state tax for a specific state (used for cross-state comparison).
    /// `income` is post-state-deduction income (state taxable income before retirement exemptions).
    /// `taxableSocialSecurity` is the SS amount included in income (to correctly subtract for SS-exempt states).
    func calculateStateTax(income: Double, forState state: USState, filingStatus: FilingStatus = .single, taxableSocialSecurity: Double = 0) -> Double {
        let config = StateTaxData.config(for: state)
        let adjustedIncome = applyRetirementExemptions(income: income, config: config, taxableSocialSecurity: taxableSocialSecurity)

        switch config.taxSystem {
        case .noIncomeTax, .specialLimited:
            return 0
        case .flat(let rate):
            return max(0, adjustedIncome) * rate
        case .progressive(let single, let married):
            let brackets = filingStatus == .single ? single : married
            return progressiveTax(income: max(0, adjustedIncome), brackets: brackets)
        }
    }

    /// Calculates state tax starting from gross income (pre-deduction).
    /// Applies the state's own standard deduction, then retirement exemptions, then tax.
    /// Used by state comparison and scenarioStateTax to ensure correct state-specific deductions.
    func calculateStateTaxFromGross(grossIncome: Double, forState state: USState, filingStatus: FilingStatus, taxableSocialSecurity: Double) -> Double {
        let config = StateTaxData.config(for: state)
        let stateDeduction: Double
        switch config.stateDeduction {
        case .none:
            stateDeduction = 0
        case .conformsToFederal:
            stateDeduction = effectiveDeductionAmount
        case .fixed(let single, let married):
            stateDeduction = filingStatus == .single ? single : married
        }
        let stateTaxableIncome = max(0, grossIncome - stateDeduction)
        return calculateStateTax(income: stateTaxableIncome, forState: state, filingStatus: filingStatus, taxableSocialSecurity: taxableSocialSecurity)
    }

    /// Applies state-specific retirement income exemptions to reduce state taxable income.
    /// Different states exempt different combinations of Social Security, pensions, and IRA withdrawals.
    /// `taxableSocialSecurity` is the amount of SS actually included in the income figure
    /// (the federally-taxable portion: 0/50/85%), NOT the full SS benefit.
    private func applyRetirementExemptions(income: Double, config: StateTaxConfig, taxableSocialSecurity: Double) -> Double {
        var adjusted = income
        let exemptions = config.retirementExemptions

        // Social Security exemption: most states (42) exempt SS from state tax.
        // Subtract only the taxable portion that was included in income, not the full benefit.
        if exemptions.socialSecurityExempt {
            adjusted -= taxableSocialSecurity
        }

        // Pension exemption
        let pensionIncome = incomeSources.filter { $0.type == .pension }.reduce(0) { $0 + $1.annualAmount }
        switch exemptions.pensionExemption {
        case .full:
            adjusted -= pensionIncome
        case .partial(let maxExempt):
            adjusted -= min(pensionIncome, maxExempt)
        case .none:
            break
        }

        // IRA withdrawal exemption (applies to RMDs and other retirement account distributions)
        let iraIncome = incomeSources.filter { $0.type == .rmd }.reduce(0) { $0 + $1.annualAmount }
        switch exemptions.iraWithdrawalExemption {
        case .full:
            adjusted -= iraIncome
        case .partial(let maxExempt):
            adjusted -= min(iraIncome, maxExempt)
        case .none:
            break
        }

        return max(0, adjusted)
    }

    /// Returns a detailed breakdown of how state tax is calculated for a specific state.
    /// Mirrors the logic of `calculateStateTaxFromGross` but captures
    /// every intermediate value for the State Comparison detail sheet.
    func stateTaxBreakdown(forState state: USState, filingStatus: FilingStatus) -> StateTaxBreakdown {
        let grossIncome = scenarioGrossIncome
        let config = StateTaxData.config(for: state)
        let exemptions = config.retirementExemptions

        // 0. Apply state-specific standard deduction
        let stateDeduction: Double
        switch config.stateDeduction {
        case .none:
            stateDeduction = 0
        case .conformsToFederal:
            stateDeduction = effectiveDeductionAmount
        case .fixed(let single, let married):
            stateDeduction = filingStatus == .single ? single : married
        }
        let income = max(0, grossIncome - stateDeduction)

        // 1. Gather income by category from income sources
        let taxableSS = scenarioTaxableSocialSecurity
        let pensionIncome = incomeSources.filter { $0.type == .pension }.reduce(0) { $0 + $1.annualAmount }
        let iraIncome = incomeSources.filter { $0.type == .rmd }.reduce(0) { $0 + $1.annualAmount }
        let otherIncome = max(0, income - taxableSS - pensionIncome - iraIncome)

        // 2. Calculate each exemption amount (mirrors applyRetirementExemptions logic)
        // SS exemption uses the taxable portion (what was included), not the full benefit
        let ssExemptAmt = exemptions.socialSecurityExempt ? taxableSS : 0

        let pensionExemptAmt: Double
        switch exemptions.pensionExemption {
        case .full: pensionExemptAmt = pensionIncome
        case .partial(let maxExempt): pensionExemptAmt = min(pensionIncome, maxExempt)
        case .none: pensionExemptAmt = 0
        }

        let iraExemptAmt: Double
        switch exemptions.iraWithdrawalExemption {
        case .full: iraExemptAmt = iraIncome
        case .partial(let maxExempt): iraExemptAmt = min(iraIncome, maxExempt)
        case .none: iraExemptAmt = 0
        }

        let totalExempted = ssExemptAmt + pensionExemptAmt + iraExemptAmt
        let adjustedIncome = max(0, income - totalExempted)

        // 3. Calculate tax with bracket-level detail
        var bracketDetails: [StateTaxBreakdown.BracketDetail] = []
        var flatRate: Double? = nil
        var totalTax = 0.0
        var taxSystemDesc = ""

        switch config.taxSystem {
        case .noIncomeTax:
            taxSystemDesc = "No income tax"
        case .specialLimited:
            taxSystemDesc = "No general income tax"
        case .flat(let rate):
            flatRate = rate
            taxSystemDesc = String(format: "Flat %.2f%%", rate * 100)
            totalTax = max(0, adjustedIncome) * rate
        case .progressive(let single, let married):
            let brackets = filingStatus == .single ? single : married
            if let first = brackets.first?.rate, let last = brackets.last?.rate {
                taxSystemDesc = String(format: "Progressive %.1f%%–%.1f%%", first * 100, last * 100)
            } else {
                taxSystemDesc = "Progressive brackets"
            }

            // Walk brackets to build per-bracket breakdown
            for i in brackets.indices {
                let bracket = brackets[i]
                if adjustedIncome > bracket.threshold {
                    let ceiling = i + 1 < brackets.count ? brackets[i + 1].threshold : nil
                    let effectiveCeiling = ceiling ?? adjustedIncome
                    let taxable = min(adjustedIncome, effectiveCeiling) - bracket.threshold
                    let taxAtRate = taxable * bracket.rate
                    totalTax += taxAtRate
                    bracketDetails.append(StateTaxBreakdown.BracketDetail(
                        bracketFloor: bracket.threshold,
                        bracketCeiling: ceiling,
                        rate: bracket.rate,
                        taxableInBracket: taxable,
                        taxFromBracket: taxAtRate
                    ))
                }
            }
        }

        let effectiveRate = income > 0 ? (totalTax / income) * 100 : 0

        return StateTaxBreakdown(
            state: state,
            totalIncome: income,
            socialSecurityIncome: taxableSS,
            pensionIncome: pensionIncome,
            iraRmdIncome: iraIncome,
            otherIncome: otherIncome,
            socialSecurityExempt: exemptions.socialSecurityExempt,
            socialSecurityExemptAmount: ssExemptAmt,
            pensionExemptionLevel: exemptions.pensionExemption,
            pensionExemptAmount: pensionExemptAmt,
            iraExemptionLevel: exemptions.iraWithdrawalExemption,
            iraExemptAmount: iraExemptAmt,
            capitalGainsTreatment: exemptions.capitalGainsTreatment,
            totalExempted: totalExempted,
            adjustedTaxableIncome: adjustedIncome,
            taxSystemDescription: taxSystemDesc,
            bracketBreakdown: bracketDetails,
            flatRate: flatRate,
            totalStateTax: totalTax,
            effectiveRate: effectiveRate
        )
    }

    func totalAnnualIncome() -> Double {
        incomeSources.reduce(0) { $0 + $1.annualAmount }
    }

    // MARK: - IRMAA Calculations

    /// Determines the IRMAA tier and annual surcharge for a given MAGI and filing status.
    /// CRITICAL: IRMAA is cliff-based — the ENTIRE surcharge applies once a threshold is crossed.
    /// This is NOT progressive like tax brackets. Do NOT use progressiveTax() here.
    func calculateIRMAA(magi: Double, filingStatus: FilingStatus) -> IRMAAResult {
        let tiers = DataManager.irmaa2026Tiers
        let standardB = DataManager.irmaaStandardPartB

        // Walk tiers in reverse to find the highest tier the MAGI qualifies for
        // Round MAGI to whole dollars to prevent floating-point errors at cliff boundaries
        let roundedMAGI = magi.rounded()
        var matchedTier = tiers[0]
        for tier in tiers.reversed() {
            let threshold = filingStatus == .single ? tier.singleThreshold : tier.mfjThreshold
            if roundedMAGI >= threshold {
                matchedTier = tier
                break
            }
        }

        let surchargeB = matchedTier.partBMonthly - standardB
        let surchargeD = matchedTier.partDMonthly
        let annualSurcharge = (surchargeB + surchargeD) * 12

        // Distance to next tier cliff
        let nextTierIndex = matchedTier.tier + 1
        var distanceToNext: Double? = nil
        if nextTierIndex < tiers.count {
            let nextThreshold = filingStatus == .single
                ? tiers[nextTierIndex].singleThreshold
                : tiers[nextTierIndex].mfjThreshold
            distanceToNext = nextThreshold - magi
        }

        // Distance above current tier threshold
        var distanceToPrevious: Double? = nil
        if matchedTier.tier > 0 {
            let currentThreshold = filingStatus == .single
                ? matchedTier.singleThreshold
                : matchedTier.mfjThreshold
            distanceToPrevious = magi - currentThreshold
        }

        return IRMAAResult(
            tier: matchedTier.tier,
            annualSurchargePerPerson: annualSurcharge,
            monthlyPartB: matchedTier.partBMonthly,
            monthlyPartD: matchedTier.partDMonthly,
            distanceToNextTier: distanceToNext,
            distanceToPreviousTier: distanceToPrevious,
            magi: magi
        )
    }

    // MARK: - NIIT Calculations (IRC §1411)

    /// Calculates the Net Investment Income Tax for a given NII, MAGI, and filing status.
    /// NIIT = 3.8% × min(NII, max(0, MAGI − threshold))
    ///
    /// Key nuance: Roth conversions and IRA withdrawals are NOT NII themselves, but they
    /// increase MAGI, which can cause existing investment income to become subject to NIIT.
    func calculateNIIT(nii: Double, magi: Double, filingStatus: FilingStatus) -> NIITResult {
        let threshold = filingStatus == .single
            ? DataManager.niitThresholdSingle
            : DataManager.niitThresholdMFJ

        // Round MAGI to whole dollars to prevent floating-point errors at threshold boundary
        let roundedMAGI = magi.rounded()
        let magiExcess = max(0, roundedMAGI - threshold)
        let taxableNII = min(nii, magiExcess)
        let tax = taxableNII * DataManager.niitRate
        let distance = threshold - roundedMAGI

        return NIITResult(
            netInvestmentIncome: nii,
            magi: magi,
            threshold: threshold,
            magiExcess: magiExcess,
            taxableNII: taxableNII,
            annualNIITax: tax,
            distanceToThreshold: distance
        )
    }

    // MARK: - AMT Calculations (IRC §55)

    /// Calculates Alternative Minimum Tax for 2026.
    ///
    /// For retirees, AMTI = taxable income + add-back of SALT deduction
    /// + add-back of deductible medical expenses (only when itemizing).
    /// If taking the standard deduction, AMTI ≈ taxable income (no add-backs).
    ///
    /// Cap gains within AMTI are taxed at federal preferential rates (0/15/20%),
    /// not the 26/28% AMT rates, matching Form 6251 line 12 treatment.
    func calculateAMT(taxableIncome: Double, regularTax: Double, filingStatus: FilingStatus) -> AMTResult {
        // 1. Calculate AMTI add-backs (only when itemizing — standard deduction has none)
        var addBacks = 0.0
        if scenarioEffectiveItemize {
            addBacks += saltAfterCap              // SALT fully added back for AMT
            addBacks += deductibleMedicalExpenses  // medical expenses added back for AMT
        }
        let amti = taxableIncome + addBacks

        // 2. Exemption with phaseout (50¢ per $1 of AMTI over threshold)
        let baseExemption = filingStatus == .single
            ? DataManager.amtExemptionSingle : DataManager.amtExemptionMFJ
        let phaseoutThreshold = filingStatus == .single
            ? DataManager.amtPhaseoutThresholdSingle : DataManager.amtPhaseoutThresholdMFJ
        // Round AMTI to whole dollars to prevent floating-point errors at phaseout threshold
        let phaseout = max(0, (amti.rounded() - phaseoutThreshold) * DataManager.amtPhaseoutRate)
        let exemption = max(0, baseExemption - phaseout)

        // 3. Taxable AMTI (after exemption)
        let taxableAMTI = max(0, amti - exemption)

        // 4. Tentative minimum tax: 26%/28% on ordinary, preferential rates on cap gains
        let capGains = max(0, preferentialIncome())
        let ordinaryAMTI = max(0, taxableAMTI - capGains)

        // 26%/28% on ordinary portion of AMTI
        var tmt = 0.0
        if ordinaryAMTI <= DataManager.amt26PercentLimit {
            tmt = ordinaryAMTI * DataManager.amtRate26
        } else {
            tmt = DataManager.amt26PercentLimit * DataManager.amtRate26
                + (ordinaryAMTI - DataManager.amt26PercentLimit) * DataManager.amtRate28
        }

        // Cap gains taxed at federal preferential rates (stacked on top of ordinary AMTI)
        if capGains > 0 {
            let capGainsBrackets = filingStatus == .single
                ? currentTaxBrackets.federalCapGainsSingle : currentTaxBrackets.federalCapGainsMarried
            let taxOnTotal = progressiveTax(income: taxableAMTI, brackets: capGainsBrackets)
            let taxOnOrdinary = progressiveTax(income: ordinaryAMTI, brackets: capGainsBrackets)
            tmt += taxOnTotal - taxOnOrdinary
        }

        // 5. AMT = excess of tentative minimum tax over regular tax
        let amt = max(0, tmt - regularTax)

        return AMTResult(
            amti: amti,
            exemption: exemption,
            taxableAMTI: taxableAMTI,
            tentativeMinimumTax: tmt,
            regularTax: regularTax,
            amt: amt
        )
    }

    // MARK: - Roth Conversion Analysis

    func analyzeRothConversion(conversionAmount: Double) -> RothConversionAnalysis {
        let currentIncome = taxableIncome(filingStatus: filingStatus)
        let newIncome = currentIncome + conversionAmount

        let currentFederalTax = calculateFederalTax(income: currentIncome, filingStatus: filingStatus)
        let newFederalTax = calculateFederalTax(income: newIncome, filingStatus: filingStatus)
        let federalTaxOnConversion = newFederalTax - currentFederalTax

        let currentCATax = calculateStateTax(income: currentIncome, filingStatus: filingStatus)
        let newCATax = calculateStateTax(income: newIncome, filingStatus: filingStatus)
        let caTaxOnConversion = newCATax - currentCATax

        let totalTaxOnConversion = federalTaxOnConversion + caTaxOnConversion
        let effectiveRate = conversionAmount > 0 ? totalTaxOnConversion / conversionAmount : 0

        return RothConversionAnalysis(
            conversionAmount: conversionAmount,
            federalTax: federalTaxOnConversion,
            stateTax: caTaxOnConversion,
            totalTax: totalTaxOnConversion,
            effectiveRate: effectiveRate
        )
    }
    
    // MARK: - Bracket Helpers

    /// Returns bracket detail for the given income against federal brackets.
    func federalBracketInfo(income: Double, filingStatus: FilingStatus) -> BracketInfo {
        let brackets = filingStatus == .single ? currentTaxBrackets.federalSingle : currentTaxBrackets.federalMarried
        return bracketInfo(income: income, brackets: brackets)
    }

    /// Returns bracket detail for the given income against state brackets.
    /// For progressive states, uses actual brackets. For flat/no-tax states, returns synthetic info.
    func stateBracketInfo(income: Double, filingStatus: FilingStatus) -> BracketInfo {
        let config = selectedStateConfig
        switch config.taxSystem {
        case .noIncomeTax, .specialLimited:
            return BracketInfo(currentRate: 0, currentThreshold: 0, nextThreshold: .infinity, roomRemaining: 0)
        case .flat(let rate):
            return BracketInfo(currentRate: rate, currentThreshold: 0, nextThreshold: .infinity, roomRemaining: 0)
        case .progressive(let single, let married):
            let brackets = filingStatus == .single ? single : married
            return bracketInfo(income: income, brackets: brackets)
        }
    }

    private func bracketInfo(income: Double, brackets: [TaxBracket]) -> BracketInfo {
        for i in brackets.indices.reversed() {
            if income > brackets[i].threshold {
                let isTopBracket = i == brackets.count - 1
                let nextThreshold = isTopBracket ? Double.infinity : brackets[i + 1].threshold
                let room = isTopBracket ? 0 : nextThreshold - income
                return BracketInfo(
                    currentRate: brackets[i].rate,
                    currentThreshold: brackets[i].threshold,
                    nextThreshold: nextThreshold,
                    roomRemaining: max(0, room)
                )
            }
        }
        // Below first bracket threshold (shouldn't happen for income > 0)
        let first = brackets.first!
        let nextThreshold = brackets.count > 1 ? brackets[1].threshold : Double.infinity
        return BracketInfo(
            currentRate: first.rate,
            currentThreshold: first.threshold,
            nextThreshold: nextThreshold,
            roomRemaining: max(0, nextThreshold - income)
        )
    }

    // MARK: - Enhanced Roth Conversion Analysis

    func analyzeEnhancedRothConversion(conversionAmount: Double, filingStatus: FilingStatus) -> EnhancedRothConversionAnalysis {
        let currentIncome = taxableIncome(filingStatus: filingStatus)
        let newIncome = currentIncome + conversionAmount

        let fedTaxBefore = calculateFederalTax(income: currentIncome, filingStatus: filingStatus)
        let fedTaxAfter = calculateFederalTax(income: newIncome, filingStatus: filingStatus)
        let federalTax = fedTaxAfter - fedTaxBefore

        let stateTaxBefore = calculateStateTax(income: currentIncome, filingStatus: filingStatus)
        let stateTaxAfter = calculateStateTax(income: newIncome, filingStatus: filingStatus)
        let stateTax = stateTaxAfter - stateTaxBefore

        let totalTax = federalTax + stateTax

        let fedMarginalBefore = federalMarginalRate(income: currentIncome, filingStatus: filingStatus)
        let fedMarginalAfter = federalMarginalRate(income: newIncome, filingStatus: filingStatus)
        let stateMarginalBefore = stateMarginalRate(income: currentIncome, filingStatus: filingStatus)
        let stateMarginalAfter = stateMarginalRate(income: newIncome, filingStatus: filingStatus)

        let fedBracketBefore = federalBracketInfo(income: currentIncome, filingStatus: filingStatus)
        let fedBracketAfter = federalBracketInfo(income: newIncome, filingStatus: filingStatus)
        let stateBracketBefore = stateBracketInfo(income: currentIncome, filingStatus: filingStatus)
        let stateBracketAfter = stateBracketInfo(income: newIncome, filingStatus: filingStatus)

        return EnhancedRothConversionAnalysis(
            conversionAmount: conversionAmount,
            federalTax: federalTax,
            stateTax: stateTax,
            totalTax: totalTax,
            federalEffectiveRate: conversionAmount > 0 ? federalTax / conversionAmount : 0,
            stateEffectiveRate: conversionAmount > 0 ? stateTax / conversionAmount : 0,
            combinedEffectiveRate: conversionAmount > 0 ? totalTax / conversionAmount : 0,
            federalMarginalBefore: fedMarginalBefore,
            federalMarginalAfter: fedMarginalAfter,
            stateMarginalBefore: stateMarginalBefore,
            stateMarginalAfter: stateMarginalAfter,
            federalBracketBefore: fedBracketBefore,
            federalBracketAfter: fedBracketAfter,
            stateBracketBefore: stateBracketBefore,
            stateBracketAfter: stateBracketAfter,
            crossesFederalBracket: fedMarginalAfter > fedMarginalBefore,
            crossesStateBracket: stateMarginalAfter > stateMarginalBefore
        )
    }

    // MARK: - Scenario Tax Analysis

    /// Analyzes tax impact for a full scenario (conversions + withdrawals + QCD).
    /// Unlike `analyzeEnhancedRothConversion` which computes base income internally,
    /// this accepts explicit base and scenario incomes so the caller can include
    /// QCD offsets, charitable deductions, and other adjustments.
    func analyzeScenario(baseIncome: Double, scenarioIncome: Double) -> ScenarioTaxAnalysis {
        let additionalIncome = scenarioIncome - baseIncome
        let fs = filingStatus

        let fedTaxBefore = calculateFederalTax(income: baseIncome, filingStatus: fs)
        let fedTaxAfter = calculateFederalTax(income: scenarioIncome, filingStatus: fs)
        let federalTax = fedTaxAfter - fedTaxBefore

        let stateTaxBefore = calculateStateTax(income: baseIncome, filingStatus: fs)
        let stateTaxAfter = calculateStateTax(income: scenarioIncome, filingStatus: fs)
        let stateTax = stateTaxAfter - stateTaxBefore

        let totalTax = federalTax + stateTax

        let fedMarginalBefore = federalMarginalRate(income: baseIncome, filingStatus: fs)
        let fedMarginalAfter = federalMarginalRate(income: scenarioIncome, filingStatus: fs)
        let stateMarginalBefore = stateMarginalRate(income: baseIncome, filingStatus: fs)
        let stateMarginalAfter = stateMarginalRate(income: scenarioIncome, filingStatus: fs)

        let fedBracketBefore = federalBracketInfo(income: baseIncome, filingStatus: fs)
        let fedBracketAfter = federalBracketInfo(income: scenarioIncome, filingStatus: fs)
        let stateBracketBefore = stateBracketInfo(income: baseIncome, filingStatus: fs)
        let stateBracketAfter = stateBracketInfo(income: scenarioIncome, filingStatus: fs)

        return ScenarioTaxAnalysis(
            baseIncome: baseIncome,
            scenarioIncome: scenarioIncome,
            additionalIncome: additionalIncome,
            federalTax: federalTax,
            stateTax: stateTax,
            totalTax: totalTax,
            effectiveRate: additionalIncome > 0 ? totalTax / additionalIncome : 0,
            federalMarginalBefore: fedMarginalBefore,
            federalMarginalAfter: fedMarginalAfter,
            stateMarginalBefore: stateMarginalBefore,
            stateMarginalAfter: stateMarginalAfter,
            federalEffectiveRate: additionalIncome > 0 ? federalTax / additionalIncome : 0,
            stateEffectiveRate: additionalIncome > 0 ? stateTax / additionalIncome : 0,
            federalBracketBefore: fedBracketBefore,
            federalBracketAfter: fedBracketAfter,
            stateBracketBefore: stateBracketBefore,
            stateBracketAfter: stateBracketAfter,
            crossesFederalBracket: fedMarginalAfter > fedMarginalBefore,
            crossesStateBracket: stateMarginalAfter > stateMarginalBefore
        )
    }

    // MARK: - Quarterly Estimated Tax

    func calculateQuarterlyEstimatedTax() -> Double {
        let totalIncome = taxableIncome(filingStatus: filingStatus)
        let federalTax = calculateFederalTax(income: totalIncome, filingStatus: filingStatus)
        let caTax = calculateStateTax(income: totalIncome, filingStatus: filingStatus)
        let totalAnnualTax = federalTax + caTax

        // 90% safe harbor rule
        return (totalAnnualTax * 0.90) / 4.0
    }
    
    init(skipPersistence: Bool = false) {
        // Initialize with defaults first
        self.currentTaxBrackets = DataManager.default2026Brackets

        guard !skipPersistence else { return }

        // Then try to load tax brackets from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "taxBrackets"),
           let decoded = try? JSONDecoder().decode(TaxBrackets.self, from: data) {
            self.currentTaxBrackets = decoded
        }

        // Load persisted user data
        let defaults = UserDefaults.standard

        // Birth date: try new Date key first, then migrate from legacy Int birth year
        if let birthInterval = defaults.object(forKey: StorageKey.birthDate) as? Double {
            self.birthDate = Date(timeIntervalSince1970: birthInterval)
        } else if defaults.object(forKey: StorageKey.birthYear) != nil {
            let year = defaults.integer(forKey: StorageKey.birthYear)
            var c = DateComponents(); c.year = year; c.month = 1; c.day = 1
            if let date = Calendar.current.date(from: c) { self.birthDate = date }
        }

        if let raw = defaults.string(forKey: StorageKey.filingStatus),
           let status = FilingStatus(rawValue: raw) {
            self.filingStatus = status
        }
        if let raw = defaults.string(forKey: StorageKey.selectedState),
           let state = USState(rawValue: raw) {
            self.selectedState = state
        }
        if let name = defaults.string(forKey: StorageKey.spouseName) {
            self.spouseName = name
        }
        if let name = defaults.string(forKey: StorageKey.userName) {
            self.userName = name
        }

        // Spouse birth date: try new Date key first, then migrate from legacy Int
        if let spouseInterval = defaults.object(forKey: StorageKey.spouseBirthDate) as? Double {
            self.spouseBirthDate = Date(timeIntervalSince1970: spouseInterval)
        } else if defaults.object(forKey: StorageKey.spouseBirthYear) != nil {
            let year = defaults.integer(forKey: StorageKey.spouseBirthYear)
            var c = DateComponents(); c.year = year; c.month = 1; c.day = 1
            if let date = Calendar.current.date(from: c) { self.spouseBirthDate = date }
        }
        if defaults.object(forKey: StorageKey.enableSpouse) != nil {
            self.enableSpouse = defaults.bool(forKey: StorageKey.enableSpouse)
        }
        if let data = defaults.data(forKey: StorageKey.iraAccounts),
           let decoded = try? JSONDecoder().decode([IRAAccount].self, from: data) {
            self.iraAccounts = decoded
        }
        if let data = defaults.data(forKey: StorageKey.incomeSources),
           let decoded = try? JSONDecoder().decode([IncomeSource].self, from: data) {
            self.incomeSources = decoded
        }
        if let data = defaults.data(forKey: StorageKey.quarterlyPayments),
           let decoded = try? JSONDecoder().decode([QuarterlyPayment].self, from: data) {
            self.quarterlyPayments = decoded
        }

        // Load Tax Planning scenario state
        if defaults.object(forKey: StorageKey.yourRothConversion) != nil {
            self.yourRothConversion = defaults.double(forKey: StorageKey.yourRothConversion)
        }
        if defaults.object(forKey: StorageKey.spouseRothConversion) != nil {
            self.spouseRothConversion = defaults.double(forKey: StorageKey.spouseRothConversion)
        }
        if defaults.object(forKey: StorageKey.yourExtraWithdrawal) != nil {
            self.yourExtraWithdrawal = defaults.double(forKey: StorageKey.yourExtraWithdrawal)
        }
        if defaults.object(forKey: StorageKey.spouseExtraWithdrawal) != nil {
            self.spouseExtraWithdrawal = defaults.double(forKey: StorageKey.spouseExtraWithdrawal)
        }
        if defaults.object(forKey: StorageKey.yourQCDAmount) != nil {
            self.yourQCDAmount = defaults.double(forKey: StorageKey.yourQCDAmount)
        }
        if defaults.object(forKey: StorageKey.spouseQCDAmount) != nil {
            self.spouseQCDAmount = defaults.double(forKey: StorageKey.spouseQCDAmount)
        }
        // Migrate from legacy single qcdAmount → assign to primary
        if self.yourQCDAmount == 0 && self.spouseQCDAmount == 0,
           defaults.object(forKey: StorageKey.qcdAmount) != nil {
            self.yourQCDAmount = defaults.double(forKey: StorageKey.qcdAmount)
        }
        // Withdrawal/conversion quarter timing
        if defaults.object(forKey: StorageKey.yourWithdrawalQuarter) != nil {
            let v = defaults.integer(forKey: StorageKey.yourWithdrawalQuarter)
            self.yourWithdrawalQuarter = (1...4).contains(v) ? v : 4
        }
        if defaults.object(forKey: StorageKey.spouseWithdrawalQuarter) != nil {
            let v = defaults.integer(forKey: StorageKey.spouseWithdrawalQuarter)
            self.spouseWithdrawalQuarter = (1...4).contains(v) ? v : 4
        }
        if defaults.object(forKey: StorageKey.yourRothConversionQuarter) != nil {
            let v = defaults.integer(forKey: StorageKey.yourRothConversionQuarter)
            self.yourRothConversionQuarter = (1...4).contains(v) ? v : 4
        }
        if defaults.object(forKey: StorageKey.spouseRothConversionQuarter) != nil {
            let v = defaults.integer(forKey: StorageKey.spouseRothConversionQuarter)
            self.spouseRothConversionQuarter = (1...4).contains(v) ? v : 4
        }
        if defaults.object(forKey: StorageKey.stockDonationEnabled) != nil {
            self.stockDonationEnabled = defaults.bool(forKey: StorageKey.stockDonationEnabled)
        }
        if defaults.object(forKey: StorageKey.stockPurchasePrice) != nil {
            self.stockPurchasePrice = defaults.double(forKey: StorageKey.stockPurchasePrice)
        }
        if defaults.object(forKey: StorageKey.stockCurrentValue) != nil {
            self.stockCurrentValue = defaults.double(forKey: StorageKey.stockCurrentValue)
        }
        if defaults.object(forKey: StorageKey.stockPurchaseDate) != nil {
            let interval = defaults.double(forKey: StorageKey.stockPurchaseDate)
            if interval > 0 {
                self.stockPurchaseDate = Date(timeIntervalSince1970: interval)
            }
        }
        if defaults.object(forKey: StorageKey.cashDonationAmount) != nil {
            self.cashDonationAmount = defaults.double(forKey: StorageKey.cashDonationAmount)
        }
        // Load inherited extra withdrawals (UUID string keys → Double values)
        if let data = defaults.data(forKey: StorageKey.inheritedExtraWithdrawals),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            self.inheritedExtraWithdrawals = Dictionary(uniqueKeysWithValues:
                decoded.compactMap { key, value in
                    guard let uuid = UUID(uuidString: key) else { return nil }
                    return (uuid, value)
                }
            )
        }
        if let raw = defaults.string(forKey: StorageKey.deductionOverride),
           let choice = DeductionChoice(rawValue: raw) {
            self.deductionOverride = choice
        }
        if let data = defaults.data(forKey: StorageKey.completedActionKeys),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.completedActionKeys = decoded
        }
        if let data = defaults.data(forKey: StorageKey.deductionItems),
           let decoded = try? JSONDecoder().decode([DeductionItem].self, from: data) {
            self.deductionItems = decoded
        }
        if defaults.object(forKey: StorageKey.priorYearStateBalance) != nil {
            self.priorYearStateBalance = defaults.double(forKey: StorageKey.priorYearStateBalance)
        }
        if defaults.object(forKey: StorageKey.primaryGrowthRate) != nil {
            self.primaryGrowthRate = defaults.double(forKey: StorageKey.primaryGrowthRate)
        }
        if defaults.object(forKey: StorageKey.spouseGrowthRate) != nil {
            self.spouseGrowthRate = defaults.double(forKey: StorageKey.spouseGrowthRate)
        }
        if defaults.object(forKey: StorageKey.enableLegacyPlanning) != nil {
            self.enableLegacyPlanning = defaults.bool(forKey: StorageKey.enableLegacyPlanning)
        }
        if let heirType = defaults.string(forKey: StorageKey.legacyHeirType) {
            self.legacyHeirType = heirType
        }
        if defaults.object(forKey: StorageKey.legacyHeirTaxRate) != nil {
            self.legacyHeirTaxRate = defaults.double(forKey: StorageKey.legacyHeirTaxRate)
        }
        if defaults.object(forKey: StorageKey.legacySpouseSurvivorYears) != nil {
            let stored = defaults.integer(forKey: StorageKey.legacySpouseSurvivorYears)
            self.legacySpouseSurvivorYears = stored > 0 ? stored : 10
        }
        // taxableAccountGrowthRate is computed from primaryGrowthRate
    }

    // Save tax brackets whenever they change
    func saveTaxBrackets() {
        if let encoded = try? JSONEncoder().encode(currentTaxBrackets) {
            UserDefaults.standard.set(encoded, forKey: "taxBrackets")
        }
    }

    // MARK: - Persistence Keys
    private enum StorageKey {
        static let birthDate = "birthDate"
        static let spouseBirthDate = "spouseBirthDate"
        // Legacy keys for migration from Int birth year
        static let birthYear = "birthYear"
        static let spouseBirthYear = "spouseBirthYear"
        static let filingStatus = "filingStatus"
        static let selectedState = "selectedState"
        static let spouseName = "spouseName"
        static let enableSpouse = "enableSpouse"
        static let iraAccounts = "iraAccounts"
        static let incomeSources = "incomeSources"
        static let quarterlyPayments = "quarterlyPayments"
        // Tax Planning scenario
        static let yourRothConversion = "yourRothConversion"
        static let spouseRothConversion = "spouseRothConversion"
        static let yourExtraWithdrawal = "yourExtraWithdrawal"
        static let spouseExtraWithdrawal = "spouseExtraWithdrawal"
        static let yourQCDAmount = "yourQCDAmount"
        static let spouseQCDAmount = "spouseQCDAmount"
        static let qcdAmount = "qcdAmount"  // legacy key for migration
        static let yourWithdrawalQuarter = "yourWithdrawalQuarter"
        static let spouseWithdrawalQuarter = "spouseWithdrawalQuarter"
        static let yourRothConversionQuarter = "yourRothConversionQuarter"
        static let spouseRothConversionQuarter = "spouseRothConversionQuarter"
        static let stockDonationEnabled = "stockDonationEnabled"
        static let stockPurchasePrice = "stockPurchasePrice"
        static let stockCurrentValue = "stockCurrentValue"
        static let stockPurchaseDate = "stockPurchaseDate"
        static let cashDonationAmount = "cashDonationAmount"
        static let inheritedExtraWithdrawals = "inheritedExtraWithdrawals"
        static let deductionOverride = "deductionOverride"
        static let completedActionKeys = "completedActionKeys"
        static let deductionItems = "deductionItems"
        static let priorYearStateBalance = "priorYearStateBalance"
        static let userName = "userName"
        static let primaryGrowthRate = "primaryGrowthRate"
        static let spouseGrowthRate = "spouseGrowthRate"
        static let enableLegacyPlanning = "enableLegacyPlanning"
        static let legacyHeirType = "legacyHeirType"
        static let legacyHeirTaxRate = "legacyHeirTaxRate"
        static let legacySpouseSurvivorYears = "legacySpouseSurvivorYears"
        // taxableAccountGrowthRate is now computed from primaryGrowthRate (5/8 ratio)
    }

    /// Saves all user data to UserDefaults for persistence across rebuilds.
    func saveAllData() {
        let defaults = UserDefaults.standard
        defaults.set(birthDate.timeIntervalSince1970, forKey: StorageKey.birthDate)
        defaults.set(filingStatus.rawValue, forKey: StorageKey.filingStatus)
        defaults.set(selectedState.rawValue, forKey: StorageKey.selectedState)
        defaults.set(spouseName, forKey: StorageKey.spouseName)
        defaults.set(userName, forKey: StorageKey.userName)
        defaults.set(spouseBirthDate.timeIntervalSince1970, forKey: StorageKey.spouseBirthDate)
        defaults.set(enableSpouse, forKey: StorageKey.enableSpouse)

        if let data = try? JSONEncoder().encode(iraAccounts) {
            defaults.set(data, forKey: StorageKey.iraAccounts)
        }
        if let data = try? JSONEncoder().encode(incomeSources) {
            defaults.set(data, forKey: StorageKey.incomeSources)
        }
        if let data = try? JSONEncoder().encode(quarterlyPayments) {
            defaults.set(data, forKey: StorageKey.quarterlyPayments)
        }

        // Tax Planning scenario state
        defaults.set(yourRothConversion, forKey: StorageKey.yourRothConversion)
        defaults.set(spouseRothConversion, forKey: StorageKey.spouseRothConversion)
        defaults.set(yourExtraWithdrawal, forKey: StorageKey.yourExtraWithdrawal)
        defaults.set(spouseExtraWithdrawal, forKey: StorageKey.spouseExtraWithdrawal)
        defaults.set(yourQCDAmount, forKey: StorageKey.yourQCDAmount)
        defaults.set(spouseQCDAmount, forKey: StorageKey.spouseQCDAmount)
        defaults.set(yourWithdrawalQuarter, forKey: StorageKey.yourWithdrawalQuarter)
        defaults.set(spouseWithdrawalQuarter, forKey: StorageKey.spouseWithdrawalQuarter)
        defaults.set(yourRothConversionQuarter, forKey: StorageKey.yourRothConversionQuarter)
        defaults.set(spouseRothConversionQuarter, forKey: StorageKey.spouseRothConversionQuarter)
        defaults.set(stockDonationEnabled, forKey: StorageKey.stockDonationEnabled)
        defaults.set(stockPurchasePrice, forKey: StorageKey.stockPurchasePrice)
        defaults.set(stockCurrentValue, forKey: StorageKey.stockCurrentValue)
        defaults.set(stockPurchaseDate.timeIntervalSince1970, forKey: StorageKey.stockPurchaseDate)
        defaults.set(cashDonationAmount, forKey: StorageKey.cashDonationAmount)
        // Save inherited extra withdrawals as JSON dictionary (UUID string keys → Double values)
        let inheritedDict = Dictionary(uniqueKeysWithValues: inheritedExtraWithdrawals.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(inheritedDict) {
            defaults.set(data, forKey: StorageKey.inheritedExtraWithdrawals)
        }
        if let override = deductionOverride {
            defaults.set(override.rawValue, forKey: StorageKey.deductionOverride)
        } else {
            defaults.removeObject(forKey: StorageKey.deductionOverride)
        }
        if let data = try? JSONEncoder().encode(completedActionKeys) {
            defaults.set(data, forKey: StorageKey.completedActionKeys)
        }
        if let data = try? JSONEncoder().encode(deductionItems) {
            defaults.set(data, forKey: StorageKey.deductionItems)
        }
        defaults.set(priorYearStateBalance, forKey: StorageKey.priorYearStateBalance)
        defaults.set(primaryGrowthRate, forKey: StorageKey.primaryGrowthRate)
        defaults.set(spouseGrowthRate, forKey: StorageKey.spouseGrowthRate)
        defaults.set(enableLegacyPlanning, forKey: StorageKey.enableLegacyPlanning)
        defaults.set(legacyHeirType, forKey: StorageKey.legacyHeirType)
        defaults.set(legacyHeirTaxRate, forKey: StorageKey.legacyHeirTaxRate)
        defaults.set(legacySpouseSurvivorYears, forKey: StorageKey.legacySpouseSurvivorYears)
        // taxableAccountGrowthRate is computed from primaryGrowthRate
    }

    /// Resets all scenario properties to defaults.
    func resetScenario() {
        yourRothConversion = 0
        spouseRothConversion = 0
        yourExtraWithdrawal = 0
        spouseExtraWithdrawal = 0
        yourQCDAmount = 0
        spouseQCDAmount = 0
        yourWithdrawalQuarter = 4
        spouseWithdrawalQuarter = 4
        yourRothConversionQuarter = 4
        spouseRothConversionQuarter = 4
        stockDonationEnabled = false
        stockPurchasePrice = 0
        stockCurrentValue = 0
        stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        cashDonationAmount = 0
        inheritedExtraWithdrawals = [:]
        deductionOverride = nil
        completedActionKeys = []
        saveAllData()
    }

    /// Ensures quarterlyPayments has entries for the current year, syncing estimated amounts.
    func syncQuarterlyPayments() {
        let payments = scenarioQuarterlyPayments
        let amounts = [payments.q1, payments.q2, payments.q3, payments.q4]
        let calendar = Calendar.current
        let dueDates = [
            calendar.date(from: DateComponents(year: currentYear, month: 4, day: 15))!,
            calendar.date(from: DateComponents(year: currentYear, month: 6, day: 15))!,
            calendar.date(from: DateComponents(year: currentYear, month: 9, day: 15))!,
            calendar.date(from: DateComponents(year: currentYear + 1, month: 1, day: 15))!
        ]

        for q in 1...4 {
            if let idx = quarterlyPayments.firstIndex(where: { $0.quarter == q && $0.year == currentYear }) {
                quarterlyPayments[idx].estimatedAmount = amounts[q - 1]
            } else {
                let payment = QuarterlyPayment(
                    quarter: q,
                    year: currentYear,
                    dueDate: dueDates[q - 1],
                    estimatedAmount: amounts[q - 1]
                )
                quarterlyPayments.append(payment)
            }
        }
    }

    // Reset to default 2026 brackets
    func resetToDefaultBrackets() {
        currentTaxBrackets = DataManager.default2026Brackets
        saveTaxBrackets()
    }
    
    // MARK: - Tax Rate Calculations
    
    func federalMarginalRate(income: Double, filingStatus: FilingStatus = .single) -> Double {
        let brackets = filingStatus == .single ? currentTaxBrackets.federalSingle : currentTaxBrackets.federalMarried
        
        for bracket in brackets.reversed() {
            if income > bracket.threshold {
                return bracket.rate * 100
            }
        }
        return (brackets.first?.rate ?? 0.10) * 100
    }
    
    func federalAverageRate(income: Double, filingStatus: FilingStatus = .single) -> Double {
        guard income > 0 else { return 0.0 }
        let tax = calculateFederalTax(income: income, filingStatus: filingStatus)
        return (tax / income) * 100
    }
    
    func stateMarginalRate(income: Double, filingStatus: FilingStatus = .single) -> Double {
        let config = selectedStateConfig
        switch config.taxSystem {
        case .noIncomeTax, .specialLimited:
            return 0
        case .flat(let rate):
            return rate * 100
        case .progressive(let single, let married):
            let brackets = filingStatus == .single ? single : married
            for bracket in brackets.reversed() {
                if income > bracket.threshold {
                    return bracket.rate * 100
                }
            }
            return (brackets.first?.rate ?? 0) * 100
        }
    }

    func stateAverageRate(income: Double, filingStatus: FilingStatus = .single) -> Double {
        guard income > 0 else { return 0.0 }
        let tax = calculateStateTax(income: income, filingStatus: filingStatus)
        return (tax / income) * 100
    }
    
    // MARK: - Social Security Taxation
        
    // Calculate taxable portion of Social Security benefits
    /// Calculates the taxable portion of Social Security benefits.
    /// `additionalIncome` includes Roth conversions, extra withdrawals, etc. that
    /// aren't in `incomeSources` but affect the IRS combined income test.
    func calculateTaxableSocialSecurity(filingStatus: FilingStatus = .single, additionalIncome: Double = 0) -> Double {
        // Get Social Security income
        let ssIncome = incomeSources
            .filter { $0.type == .socialSecurity }
            .reduce(0) { $0 + $1.annualAmount }

        // Get other income (everything except Social Security)
        let otherIncome = incomeSources
            .filter { $0.type != .socialSecurity }
            .reduce(0) { $0 + $1.annualAmount }

        // Combined income = Other income + additional scenario income + 50% of Social Security
        // Per IRS, Roth conversions and IRA withdrawals count toward combined income
        let combinedIncome = otherIncome + additionalIncome + (ssIncome * 0.5)
        
        // Determine taxable portion based on thresholds
        // Round to whole dollars to prevent floating-point errors at tier boundaries
        let roundedCombined = combinedIncome.rounded()
        let (threshold1, threshold2) = filingStatus == .single ? (25_000.0, 34_000.0) : (32_000.0, 44_000.0)

        if roundedCombined <= threshold1 {
            // No Social Security is taxable
            return 0.0
        } else if roundedCombined <= threshold2 {
            // Up to 50% is taxable
            let excessOverFirst = roundedCombined - threshold1
            let taxableAmount = min(excessOverFirst, ssIncome * 0.5)
            return taxableAmount
        } else {
            // Up to 85% is taxable
            let excessOverSecond = roundedCombined - threshold2
            let tier1Amount = (threshold2 - threshold1) * 0.5
            let tier2Amount = min(excessOverSecond * 0.85, ssIncome * 0.85 - tier1Amount)
            let taxableAmount = min(tier1Amount + tier2Amount, ssIncome * 0.85)
            return taxableAmount
        }
    }
    
    // MARK: - Income Separation (Ordinary vs Preferential)

    /// Long-term capital gains + qualified dividends (taxed at preferential federal rates)
    func preferentialIncome() -> Double {
        incomeSources
            .filter { $0.type == .capitalGainsLong || $0.type == .qualifiedDividends }
            .reduce(0) { $0 + $1.annualAmount }
    }

    /// Ordinary taxable income (excludes long-term cap gains and qualified dividends)
    func ordinaryTaxableIncome(filingStatus: FilingStatus = .single) -> Double {
        let otherIncome = incomeSources
            .filter { $0.type != .socialSecurity && $0.type != .capitalGainsLong && $0.type != .qualifiedDividends }
            .reduce(0) { $0 + $1.annualAmount }
        let taxableSS = calculateTaxableSocialSecurity(filingStatus: filingStatus)
        return otherIncome + taxableSS
    }

    /// Total taxable income (ordinary + preferential). Existing callers use this.
    func taxableIncome(filingStatus: FilingStatus = .single) -> Double {
        return ordinaryTaxableIncome(filingStatus: filingStatus) + preferentialIncome()
    }

    // MARK: - Scenario Computations (shared across Dashboard, Tax Planning, Quarterly Tax)

    var scenarioTotalRothConversion: Double {
        yourRothConversion + (enableSpouse ? spouseRothConversion : 0)
    }

    var scenarioTotalExtraWithdrawal: Double {
        yourExtraWithdrawal + (enableSpouse ? spouseExtraWithdrawal : 0) + inheritedTraditionalExtraTotal
    }

    var scenarioCombinedRMD: Double {
        calculateCombinedRMD() + inheritedIRARMDTotal
    }

    var scenarioTotalQCD: Double {
        yourQCDAmount + (enableSpouse ? spouseQCDAmount : 0)
    }

    var scenarioQCDEligible: Bool {
        isQCDEligible || (enableSpouse && spouseIsQCDEligible)
    }

    /// Annual QCD limit per person, inflation-adjusted per SECURE 2.0 Act.
    /// 2025: $108,000 (IRS confirmed). 2026: $111,000 (IRS Notice 2025-67).
    var qcdAnnualLimit: Double {
        switch currentYear {
        case ...2024: return 105_000
        case 2025: return 108_000
        default: return 111_000  // 2026+ (will need future IRS updates)
        }
    }

    var yourMaxQCDAmount: Double {
        isQCDEligible ? qcdAnnualLimit : 0
    }

    var spouseMaxQCDAmount: Double {
        (enableSpouse && spouseIsQCDEligible) ? qcdAnnualLimit : 0
    }

    /// RMD remaining after QCD offset
    /// RMD remaining after QCD offset. QCD only applies to regular (non-inherited) IRA RMDs.
    var scenarioAdjustedRMD: Double {
        let regularRMD = calculateCombinedRMD()
        let inheritedRMD = inheritedIRARMDTotal
        guard (regularRMD + inheritedRMD) > 0 else { return 0 }
        let regularAfterQCD = scenarioQCDEligible ? max(0, regularRMD - scenarioTotalQCD) : regularRMD
        return regularAfterQCD + inheritedRMD
    }

    /// Taxable withdrawals: RMD after QCD + extra withdrawals.
    /// QCD offset only applies to regular (non-inherited) RMDs.
    var scenarioTotalWithdrawals: Double {
        let regularRMD = calculateCombinedRMD()
        let inheritedRMD = inheritedIRARMDTotal
        let regularAfterQCD = max(0, regularRMD - (scenarioQCDEligible ? scenarioTotalQCD : 0))
        return regularAfterQCD + inheritedRMD + scenarioTotalExtraWithdrawal
    }

    var scenarioStockIsLongTerm: Bool {
        guard let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) else { return false }
        return stockPurchaseDate <= oneYearAgo
    }

    /// Unrealized gain avoided by donating stock instead of selling.
    /// Applies to both long-term and short-term holdings — either way, the gain
    /// is never realized and should not appear in gross income.
    var scenarioStockGainAvoided: Double {
        guard stockDonationEnabled else { return 0 }
        return max(0, stockCurrentValue - stockPurchasePrice)
    }

    /// Federal withholding from all income sources
    var totalFederalWithholding: Double {
        incomeSources.reduce(0) { $0 + $1.federalWithholding }
    }

    /// State withholding from all income sources
    var totalStateWithholding: Double {
        incomeSources.reduce(0) { $0 + $1.stateWithholding }
    }

    /// Combined federal + state withholding from all income sources
    var totalWithholding: Double {
        totalFederalWithholding + totalStateWithholding
    }

    /// Taxable portion of Social Security with scenario income included in combined income test.
    /// Per IRS rules, Roth conversions and IRA withdrawals affect the SS taxation thresholds.
    var scenarioTaxableSocialSecurity: Double {
        let scenarioExtra = scenarioTotalRothConversion + scenarioTotalWithdrawals
        return calculateTaxableSocialSecurity(filingStatus: filingStatus, additionalIncome: scenarioExtra)
    }

    /// Base income before any scenario decisions (pre-deduction).
    /// Uses scenario-aware SS taxation that includes Roth conversions and withdrawals
    /// in the IRS combined income test for determining how much SS is taxable.
    var scenarioBaseIncome: Double {
        let otherIncome = incomeSources
            .filter { $0.type != .socialSecurity && $0.type != .capitalGainsLong && $0.type != .qualifiedDividends }
            .reduce(0) { $0 + $1.annualAmount }
        let capGains = preferentialIncome()
        return otherIncome + scenarioTaxableSocialSecurity + capGains
    }

    /// Gross income including RMDs + scenario decisions (pre-deduction).
    /// Subtracts avoided gains from donated stock — that gain was never realized.
    var scenarioGrossIncome: Double {
        scenarioBaseIncome + scenarioTotalRothConversion + scenarioTotalWithdrawals - scenarioStockGainAvoided
    }

    // MARK: - Standard vs. Itemized Deduction

    /// Standard deduction based on filing status, age, and tax year.
    /// Reflects OBBBA (signed July 4, 2025) changes:
    /// - 2025: $15,750 Single / $31,500 MFJ (OBBBA retroactive boost)
    /// - 2026: $16,100 Single / $32,200 MFJ (IRS Rev. Proc. 2025-32)
    /// - Age 65+ additional: $2,050 Single / $1,650 MFJ per person (2026)
    /// - OBBBA Senior Bonus (2025-2028): $6,000 per qualifying person 65+,
    ///   phases out at 6% of MAGI over $75K (Single) / $150K (MFJ).
    ///   Not available for Married Filing Separately.
    var standardDeductionAmount: Double {
        let year = currentYear
        var amount: Double

        switch filingStatus {
        case .single:
            // Base standard deduction
            if year == 2025 {
                amount = 15_750
            } else {
                amount = 16_100  // 2026 (IRS Rev. Proc. 2025-32)
            }
            // Age 65+ additional deduction
            if currentAge >= 65 {
                amount += (year == 2025) ? 2_000 : 2_050
            }
            // OBBBA Senior Bonus (2025-2028): $6,000 with gradual phaseout
            if currentAge >= 65 && year >= 2025 && year <= 2028 {
                let seniorBonusBase = 6_000.0
                let phaseoutThreshold = 75_000.0
                let phaseoutRate = 0.06
                let magi = scenarioGrossIncome
                let reduction = max(0, (magi - phaseoutThreshold) * phaseoutRate)
                let bonus = max(0, seniorBonusBase - reduction)
                amount += bonus
            }
        case .marriedFilingJointly:
            // Base standard deduction
            if year == 2025 {
                amount = 31_500
            } else {
                amount = 32_200  // 2026 (IRS Rev. Proc. 2025-32)
            }
            // Age 65+ additional per person
            let additionalPer65 = (year == 2025) ? 1_600.0 : 1_650.0
            if currentAge >= 65 { amount += additionalPer65 }
            if enableSpouse && spouseCurrentAge >= 65 { amount += additionalPer65 }
            // OBBBA Senior Bonus (2025-2028): $6,000 per qualifying person 65+
            // with gradual phaseout at 6% of MAGI over $150K
            if year >= 2025 && year <= 2028 {
                let seniorBonusPerPerson = 6_000.0
                let phaseoutThreshold = 150_000.0
                let phaseoutRate = 0.06
                let magi = scenarioGrossIncome

                // Count qualifying seniors
                var qualifyingSeniors = 0
                if currentAge >= 65 { qualifyingSeniors += 1 }
                if enableSpouse && spouseCurrentAge >= 65 { qualifyingSeniors += 1 }

                if qualifyingSeniors > 0 {
                    let totalBonusBase = seniorBonusPerPerson * Double(qualifyingSeniors)
                    let reduction = max(0, (magi - phaseoutThreshold) * phaseoutRate)
                    let bonus = max(0, totalBonusBase - reduction)
                    amount += bonus
                }
            }
        }
        return amount
    }

    /// Total medical expenses entered by the user (before AGI floor).
    var totalMedicalExpenses: Double {
        deductionItems.filter { $0.type == .medicalExpenses }.reduce(0) { $0 + $1.annualAmount }
    }

    /// Estimated AGI used for the medical deduction floor. For retirees this is
    /// effectively gross income (pensions, taxable SS, dividends, cap gains, Roth
    /// conversions, withdrawals). True AGI would subtract any above-the-line
    /// deductions (IRA contributions, HSA, etc.) which are typically zero in retirement.
    var estimatedAGI: Double {
        scenarioGrossIncome
    }

    /// The 7.5% AGI floor for medical deductions.
    var medicalAGIFloor: Double {
        estimatedAGI * 0.075
    }

    /// Deductible medical expenses (only the portion exceeding 7.5% of AGI).
    var deductibleMedicalExpenses: Double {
        max(0, totalMedicalExpenses - medicalAGIFloor)
    }

    /// Property tax from deduction items
    var propertyTaxAmount: Double {
        deductionItems.filter { $0.type == .propertyTax }.reduce(0) { $0 + $1.annualAmount }
    }

    /// Additional manual SALT entries (city/local taxes not auto-captured)
    var additionalSALTAmount: Double {
        deductionItems.filter { $0.type == .saltTax }.reduce(0) { $0 + $1.annualAmount }
    }

    /// Prior year state balance due that's SALT-deductible (only positive amounts)
    var priorYearSALTDeductible: Double {
        max(0, priorYearStateBalance)
    }

    /// Raw total of SALT-eligible amounts before the federal cap.
    /// Auto-includes: property tax, state withholding from income sources,
    /// prior year state balance due (if positive), and any manual SALT entries.
    var totalSALTBeforeCap: Double {
        propertyTaxAmount + totalStateWithholding + priorYearSALTDeductible + additionalSALTAmount
    }

    /// SALT cap based on tax year and filing status (OBBBA, signed July 4, 2025).
    /// - 2018–2024: $10,000 per TCJA
    /// - 2025–2029: $40,000 base with 1% annual inflation, but phased out by
    ///   30% of MAGI exceeding $500,000 (MFJ, +1%/year). Floor of $10,000.
    /// - 2030+: Reverts permanently to $10,000
    var saltCap: Double {
        let year = currentYear
        if year >= 2025 && year <= 2029 {
            // OBBBA base cap with 1% annual inflation adjustment from 2025
            let yearsFromBase = Double(year - 2025)
            let inflationMultiplier = pow(1.01, yearsFromBase)
            let expandedCap = (40_000.0 * inflationMultiplier).rounded()

            // Income-based phaseout: reduced by 30% of MAGI over threshold
            // Threshold: $500,000 MFJ in 2025, also inflated 1%/year
            let phaseoutThreshold = (500_000.0 * inflationMultiplier).rounded()
            let magi = scenarioGrossIncome
            // Round MAGI to whole dollars to prevent floating-point errors at phaseout threshold
            let phaseoutReduction = max(0, (magi.rounded() - phaseoutThreshold) * 0.30)
            let afterPhaseout = expandedCap - phaseoutReduction

            // Floor: never less than $10,000 regardless of phaseout
            return max(10_000, afterPhaseout)
        } else if year >= 2018 && year <= 2024 {
            return 10_000
        } else {
            // 2030+ reverts to TCJA cap
            return 10_000
        }
    }

    /// SALT deduction after applying the federal cap.
    var saltAfterCap: Double {
        min(totalSALTBeforeCap, saltCap)
    }

    /// Total user-entered itemized deductions with SALT cap and medical AGI floor applied.
    var baseItemizedDeductions: Double {
        let nonSALTNonMedical = deductionItems
            .filter { $0.type != .propertyTax && $0.type != .saltTax && $0.type != .medicalExpenses }
            .reduce(0) { $0 + $1.annualAmount }
        return nonSALTNonMedical + saltAfterCap + deductibleMedicalExpenses
    }

    /// Charitable deductions from Tax Planning (stock + cash, NOT QCD which is pre-tax)
    var scenarioCharitableDeductions: Double {
        var total = 0.0
        if stockDonationEnabled {
            total += scenarioStockIsLongTerm ? stockCurrentValue : stockPurchasePrice
        }
        total += cashDonationAmount
        return total
    }

    /// Total itemized deductions: base entries + charitable from Tax Planning
    var totalItemizedDeductions: Double {
        baseItemizedDeductions + scenarioCharitableDeductions
    }

    /// Auto-recommended deduction type (whichever is higher)
    var recommendedDeductionType: DeductionChoice {
        totalItemizedDeductions > standardDeductionAmount ? .itemized : .standard
    }

    /// Whether to actually itemize (respects user override, otherwise auto-picks best)
    var scenarioEffectiveItemize: Bool {
        switch deductionOverride {
        case .itemized: return true
        case .standard: return false
        case nil: return recommendedDeductionType == .itemized
        }
    }

    /// The deduction amount actually applied to income
    var effectiveDeductionAmount: Double {
        scenarioEffectiveItemize ? totalItemizedDeductions : standardDeductionAmount
    }

    /// Taxable income after scenario decisions and deductions
    var scenarioTaxableIncome: Double {
        let income = scenarioGrossIncome - effectiveDeductionAmount
        return max(0, income)
    }

    var scenarioFederalTax: Double {
        calculateFederalTax(income: scenarioTaxableIncome, filingStatus: filingStatus)
    }

    var scenarioStateTax: Double {
        calculateStateTaxFromGross(
            grossIncome: scenarioGrossIncome,
            forState: selectedState,
            filingStatus: filingStatus,
            taxableSocialSecurity: scenarioTaxableSocialSecurity
        )
    }

    var scenarioTotalTax: Double {
        scenarioFederalTax + scenarioStateTax + scenarioNIITAmount + scenarioAMTAmount
    }

    // MARK: - IRMAA Scenario Properties

    /// Number of Medicare enrollees in household (age 65+).
    var medicareMemberCount: Int {
        var count = 0
        if currentAge >= 65 { count += 1 }
        if enableSpouse && spouseCurrentAge >= 65 { count += 1 }
        return count
    }

    /// Current scenario IRMAA result based on estimatedAGI (≈ MAGI for retirees).
    var scenarioIRMAA: IRMAAResult {
        calculateIRMAA(magi: estimatedAGI, filingStatus: filingStatus)
    }

    /// Total household annual IRMAA surcharge (per-person × number of Medicare members).
    var scenarioIRMAATotalSurcharge: Double {
        scenarioIRMAA.annualSurchargePerPerson * Double(medicareMemberCount)
    }

    /// Baseline IRMAA (without any scenario decisions) for comparison.
    var baselineIRMAA: IRMAAResult {
        calculateIRMAA(magi: scenarioBaseIncome, filingStatus: filingStatus)
    }

    /// Whether scenario decisions pushed into a higher IRMAA tier.
    var scenarioPushedToHigherIRMAATier: Bool {
        scenarioIRMAA.tier > baselineIRMAA.tier
    }

    /// Annual surcharge per person at the tier BELOW the current scenario tier.
    /// Returns 0 if already at Tier 0 (standard). Used to compute savings from dropping a tier.
    var scenarioIRMAAPreviousTierAnnualSurcharge: Double {
        let irmaa = scenarioIRMAA
        guard irmaa.tier > 0 else { return 0 }
        let tiers = DataManager.irmaa2026Tiers
        let currentThreshold = filingStatus == .single
            ? tiers[irmaa.tier].singleThreshold
            : tiers[irmaa.tier].mfjThreshold
        let lowerResult = calculateIRMAA(magi: currentThreshold - 1, filingStatus: filingStatus)
        return lowerResult.annualSurchargePerPerson
    }

    // MARK: - NIIT Scenario Properties

    /// Total Net Investment Income from income sources.
    /// Includes: dividends, qualified dividends, interest, short/long-term capital gains.
    /// Excludes: Social Security, pensions, RMDs, Roth conversions, employment, state tax refunds.
    /// Stock donation avoids realizing capital gains, so scenarioStockGainAvoided reduces NII.
    var scenarioNetInvestmentIncome: Double {
        let baseNII = incomeSources
            .filter { DataManager.niitQualifyingTypes.contains($0.type) }
            .reduce(0) { $0 + $1.annualAmount }
        return max(0, baseNII - scenarioStockGainAvoided)
    }

    /// Current scenario NIIT result based on estimatedAGI (effectively MAGI for retirees).
    var scenarioNIIT: NIITResult {
        calculateNIIT(nii: scenarioNetInvestmentIncome, magi: estimatedAGI, filingStatus: filingStatus)
    }

    /// The annual NIIT tax amount for the current scenario.
    var scenarioNIITAmount: Double {
        scenarioNIIT.annualNIITax
    }

    /// Baseline NIIT (without scenario decisions) for comparison.
    var baselineNIIT: NIITResult {
        let baseNII = incomeSources
            .filter { DataManager.niitQualifyingTypes.contains($0.type) }
            .reduce(0) { $0 + $1.annualAmount }
        return calculateNIIT(nii: baseNII, magi: scenarioBaseIncome, filingStatus: filingStatus)
    }

    /// Whether scenario decisions triggered or increased NIIT.
    var scenarioIncreasedNIIT: Bool {
        scenarioNIITAmount > baselineNIIT.annualNIITax
    }

    // MARK: - AMT Scenario Properties

    /// Full AMT result for current scenario.
    var scenarioAMT: AMTResult {
        calculateAMT(
            taxableIncome: scenarioTaxableIncome,
            regularTax: scenarioFederalTax,
            filingStatus: filingStatus
        )
    }

    /// AMT amount (0 for most retirees; > 0 only if tentative minimum tax exceeds regular tax).
    var scenarioAMTAmount: Double {
        scenarioAMT.amt
    }

    /// Total tax remaining after all withholding
    var scenarioRemainingTax: Double {
        max(0, scenarioTotalTax - totalWithholding)
    }

    /// Federal tax remaining after federal withholding
    var scenarioRemainingFederalTax: Double {
        max(0, scenarioFederalTax - totalFederalWithholding)
    }

    /// State tax remaining after state withholding
    var scenarioRemainingStateTax: Double {
        max(0, scenarioStateTax - totalStateWithholding)
    }

    /// Quarterly estimated tax payment (90% safe harbor minus withholding) — uniform fallback
    var scenarioQuarterlyPayment: Double {
        let payments = scenarioQuarterlyPayments
        return payments.total > 0 ? payments.total / 4.0 : 0
    }

    /// Per-quarter estimated tax payments with federal/state split.
    /// Base tax (from regular income) is spread evenly; incremental tax from scenario
    /// events is allocated to the quarter each event is planned.
    var scenarioQuarterlyPayments: FederalStateQuarterlyBreakdown {
        // Base tax: from regular income sources only, no scenario additions
        let baseTaxable = max(0, scenarioBaseIncome - effectiveDeductionAmount)
        let baseFederalTax = calculateFederalTax(income: baseTaxable, filingStatus: filingStatus)
        let baseStateTax = calculateStateTax(income: baseTaxable, filingStatus: filingStatus)

        // Total federal and state tax (including scenario decisions)
        let totalFederal = scenarioFederalTax + scenarioNIITAmount + scenarioAMTAmount
        let totalState = scenarioStateTax

        // Incremental tax from scenario events
        let incrementalFederal = max(0, totalFederal - baseFederalTax)
        let incrementalState = max(0, totalState - baseStateTax)

        // Base per-quarter (90% safe harbor, spread evenly)
        let baseFedPerQ = max(0, baseFederalTax * 0.90) / 4.0
        let baseStatePerQ = max(0, baseStateTax * 0.90) / 4.0

        var fedPayments = QuarterlyBreakdown(q1: baseFedPerQ, q2: baseFedPerQ,
                                              q3: baseFedPerQ, q4: baseFedPerQ)
        var statePayments = QuarterlyBreakdown(q1: baseStatePerQ, q2: baseStatePerQ,
                                                q3: baseStatePerQ, q4: baseStatePerQ)

        // Assign incremental taxable income to the quarter each event occurs
        var qIncome = QuarterlyBreakdown()
        let yourWdl = max(0, calculatePrimaryRMD() - (isQCDEligible ? yourQCDAmount : 0)) + yourExtraWithdrawal
        qIncome[yourWithdrawalQuarter] += yourWdl
        if enableSpouse {
            let spWdl = max(0, calculateSpouseRMD() - (spouseIsQCDEligible ? spouseQCDAmount : 0)) + spouseExtraWithdrawal
            qIncome[spouseWithdrawalQuarter] += spWdl
        }
        qIncome[yourRothConversionQuarter] += yourRothConversion
        if enableSpouse {
            qIncome[spouseRothConversionQuarter] += spouseRothConversion
        }

        // Distribute incremental tax proportionally to quarters by income share
        if qIncome.total > 0 {
            let incFedSH = incrementalFederal * 0.90
            let incStateSH = incrementalState * 0.90
            for q in 1...4 {
                let share = qIncome[q] / qIncome.total
                fedPayments[q] += incFedSH * share
                statePayments[q] += incStateSH * share
            }
        }

        // Subtract withholding separately (spread evenly)
        let fedWPerQ = totalFederalWithholding / 4.0
        let stateWPerQ = totalStateWithholding / 4.0
        for q in 1...4 {
            fedPayments[q] = max(0, fedPayments[q] - fedWPerQ)
            statePayments[q] = max(0, statePayments[q] - stateWPerQ)
        }

        return FederalStateQuarterlyBreakdown(federal: fedPayments, state: statePayments)
    }

    /// Label for the primary user: their name if set, otherwise "Your".
    var primaryLabel: String {
        userName.isEmpty ? "Your" : userName + "'s"
    }

    /// Short label for the primary user: name if set, otherwise "You".
    var primaryShortLabel: String {
        userName.isEmpty ? "You" : userName
    }

    /// Whether any Tax Planning decisions are active
    var hasActiveScenario: Bool {
        scenarioTotalRothConversion > 0 || scenarioTotalExtraWithdrawal > 0
        || scenarioTotalQCD > 0 || (stockDonationEnabled && stockCurrentValue > 0)
        || cashDonationAmount > 0
        || inheritedExtraWithdrawalTotal > 0
    }

    /// Total charitable giving (QCD + stock + cash)
    var scenarioTotalCharitable: Double {
        var total = scenarioTotalQCD
        if stockDonationEnabled { total += stockCurrentValue }
        total += cashDonationAmount
        return total
    }

    // MARK: - Action Item Generation

    struct ActionItem: Identifiable {
        let id: String
        let title: String
        let detail: String
        let deadline: String
        let category: ActionCategory
    }

    enum ActionCategory: String {
        case rmd, rothConversion, qcd, withdrawal, estimatedTax, charitable
    }

    var generatedActionItems: [ActionItem] {
        var items: [ActionItem] = []
        let year = currentYear

        if calculatePrimaryRMD() > 0 {
            items.append(ActionItem(
                id: "rmd-primary-\(year)",
                title: "Take RMD: \(calculatePrimaryRMD().formatted(.currency(code: "USD")))",
                detail: "Withdraw from your traditional IRA/401(k)",
                deadline: "Dec 31, \(year)",
                category: .rmd
            ))
        }
        if enableSpouse && calculateSpouseRMD() > 0 {
            items.append(ActionItem(
                id: "rmd-spouse-\(year)",
                title: "Take \(spouseName.isEmpty ? "Spouse" : spouseName) RMD: \(calculateSpouseRMD().formatted(.currency(code: "USD")))",
                detail: "Withdraw from spouse's traditional IRA/401(k)",
                deadline: "Dec 31, \(year)",
                category: .rmd
            ))
        }
        if yourRothConversion > 0 {
            items.append(ActionItem(
                id: "roth-primary-\(year)",
                title: "Roth Conversion: \(yourRothConversion.formatted(.currency(code: "USD")))",
                detail: "Contact custodian to convert traditional → Roth IRA",
                deadline: "Dec 31, \(year)",
                category: .rothConversion
            ))
        }
        if enableSpouse && spouseRothConversion > 0 {
            items.append(ActionItem(
                id: "roth-spouse-\(year)",
                title: "\(spouseName.isEmpty ? "Spouse" : spouseName) Roth Conversion: \(spouseRothConversion.formatted(.currency(code: "USD")))",
                detail: "Contact custodian to convert spouse's traditional → Roth IRA",
                deadline: "Dec 31, \(year)",
                category: .rothConversion
            ))
        }
        if yourExtraWithdrawal > 0 {
            items.append(ActionItem(
                id: "withdrawal-primary-\(year)",
                title: "Extra Withdrawal: \(yourExtraWithdrawal.formatted(.currency(code: "USD")))",
                detail: "Withdraw additional funds from traditional IRA/401(k)",
                deadline: "Dec 31, \(year)",
                category: .withdrawal
            ))
        }
        if enableSpouse && spouseExtraWithdrawal > 0 {
            items.append(ActionItem(
                id: "withdrawal-spouse-\(year)",
                title: "\(spouseName.isEmpty ? "Spouse" : spouseName) Extra Withdrawal: \(spouseExtraWithdrawal.formatted(.currency(code: "USD")))",
                detail: "Withdraw additional funds from spouse's traditional IRA/401(k)",
                deadline: "Dec 31, \(year)",
                category: .withdrawal
            ))
        }
        if yourQCDAmount > 0 {
            items.append(ActionItem(
                id: "qcd-primary-\(year)",
                title: "Make QCD: \(yourQCDAmount.formatted(.currency(code: "USD")))",
                detail: "Direct distribution from IRA to qualified charity",
                deadline: "Dec 31, \(year)",
                category: .qcd
            ))
        }
        if enableSpouse && spouseQCDAmount > 0 {
            items.append(ActionItem(
                id: "qcd-spouse-\(year)",
                title: "\(spouseName.isEmpty ? "Spouse" : spouseName) QCD: \(spouseQCDAmount.formatted(.currency(code: "USD")))",
                detail: "Direct distribution from spouse's IRA to qualified charity",
                deadline: "Dec 31, \(year)",
                category: .qcd
            ))
        }
        if stockDonationEnabled && stockCurrentValue > 0 {
            items.append(ActionItem(
                id: "stock-donation-\(year)",
                title: "Donate Appreciated Stock: \(stockCurrentValue.formatted(.currency(code: "USD")))",
                detail: "Transfer shares to charity's brokerage account",
                deadline: "Dec 31, \(year)",
                category: .charitable
            ))
        }
        if cashDonationAmount > 0 {
            items.append(ActionItem(
                id: "cash-donation-\(year)",
                title: "Cash Donation: \(cashDonationAmount.formatted(.currency(code: "USD")))",
                detail: "Donate to qualified charity — keep receipt",
                deadline: "Dec 31, \(year)",
                category: .charitable
            ))
        }

        // Quarterly estimated tax payments (per-quarter amounts based on timing)
        let qPayments = scenarioQuarterlyPayments
        let quarterInfo: [(Int, String, String)] = [
            (1, "Q1", "Apr 15, \(year)"),
            (2, "Q2", "Jun 15, \(year)"),
            (3, "Q3", "Sep 15, \(year)"),
            (4, "Q4", "Jan 15, \(year + 1)")
        ]
        for (q, label, deadline) in quarterInfo {
            let amount = qPayments[q]
            if amount > 0 {
                let fedAmt = qPayments.federal[q]
                let stateAmt = qPayments.state[q]
                let detail: String
                if fedAmt > 0 && stateAmt > 0 {
                    detail = "Federal: \(fedAmt.formatted(.currency(code: "USD"))) + State: \(stateAmt.formatted(.currency(code: "USD")))"
                } else if fedAmt > 0 {
                    detail = "Federal estimated tax payment"
                } else {
                    detail = "State estimated tax payment"
                }
                items.append(ActionItem(
                    id: "tax-\(label.lowercased())-\(year)",
                    title: "\(label) Estimated Tax: \(amount.formatted(.currency(code: "USD")))",
                    detail: detail,
                    deadline: deadline,
                    category: .estimatedTax
                ))
            }
        }

        return items
    }

    // MARK: - Per-Decision Tax Impact Helpers

    /// Computes total tax for a hypothetical gross income and deduction scenario.
    /// Used internally to measure incremental impact of individual decisions.
    private func totalTaxFor(grossIncome: Double, deduction: Double, nii: Double? = nil) -> Double {
        let taxable = max(0, grossIncome - deduction)
        let fed = calculateFederalTax(income: taxable, filingStatus: filingStatus)
        let state = calculateStateTax(income: taxable, filingStatus: filingStatus)
        let niit = calculateNIIT(nii: nii ?? scenarioNetInvestmentIncome, magi: grossIncome, filingStatus: filingStatus).annualNIITax
        let amt = calculateAMT(taxableIncome: taxable, regularTax: fed, filingStatus: filingStatus).amt
        return fed + state + niit + amt
    }

    /// Tax impact of Roth conversions alone (approximate — removes conversions and measures difference)
    var rothConversionTaxImpact: Double {
        guard scenarioTotalRothConversion > 0 else { return 0 }
        let withoutConversions = totalTaxFor(
            grossIncome: scenarioGrossIncome - scenarioTotalRothConversion,
            deduction: effectiveDeductionAmount
        )
        return scenarioTotalTax - withoutConversions
    }

    /// Tax impact of extra withdrawals alone
    var extraWithdrawalTaxImpact: Double {
        guard scenarioTotalExtraWithdrawal > 0 else { return 0 }
        let withoutWithdrawals = totalTaxFor(
            grossIncome: scenarioGrossIncome - scenarioTotalExtraWithdrawal,
            deduction: effectiveDeductionAmount
        )
        return scenarioTotalTax - withoutWithdrawals
    }

    /// Tax savings from QCD — only the portion that offsets a taxable RMD produces
    /// unambiguous current-year savings.  Pre-RMD, the savings depend on the user's
    /// alternative (cash donation, stock donation, or no donation), so we report $0
    /// and instead show an informational AGI-advantage note in the UI.
    var qcdTaxSavings: Double {
        guard scenarioTotalQCD > 0, scenarioQCDEligible else { return 0 }
        let regularRMD = calculateCombinedRMD()
        let taxableQCDOffset = min(scenarioTotalQCD, regularRMD)
        guard taxableQCDOffset > 0 else { return 0 }
        let withoutQCD = totalTaxFor(
            grossIncome: scenarioGrossIncome + taxableQCDOffset,
            deduction: effectiveDeductionAmount
        )
        return withoutQCD - scenarioTotalTax
    }

    /// Whether the user is QCD-eligible but not yet subject to RMDs (ages 70½–72).
    var isPreRMDQCDEligible: Bool {
        scenarioQCDEligible && !isRMDRequired
    }

    /// The AGI advantage of QCD vs. taking a taxable IRA distribution and donating cash.
    /// Useful for showing the user why QCD matters even when current-year tax savings are $0.
    var qcdAGIAdvantage: Double {
        guard scenarioTotalQCD > 0, scenarioQCDEligible else { return 0 }
        return scenarioTotalQCD
    }

    // MARK: - Per-Decision IRMAA Impact

    /// IRMAA surcharge increase caused by Roth conversions (cliff-based).
    var rothConversionIRMAAImpact: Double {
        guard scenarioTotalRothConversion > 0, medicareMemberCount > 0 else { return 0 }
        let magiWithout = estimatedAGI - scenarioTotalRothConversion
        let irmaaWithout = calculateIRMAA(magi: magiWithout, filingStatus: filingStatus)
        let delta = scenarioIRMAA.annualSurchargePerPerson - irmaaWithout.annualSurchargePerPerson
        return delta * Double(medicareMemberCount)
    }

    /// IRMAA surcharge increase caused by extra withdrawals (cliff-based).
    var extraWithdrawalIRMAAImpact: Double {
        guard scenarioTotalExtraWithdrawal > 0, medicareMemberCount > 0 else { return 0 }
        let magiWithout = estimatedAGI - scenarioTotalExtraWithdrawal
        let irmaaWithout = calculateIRMAA(magi: magiWithout, filingStatus: filingStatus)
        let delta = scenarioIRMAA.annualSurchargePerPerson - irmaaWithout.annualSurchargePerPerson
        return delta * Double(medicareMemberCount)
    }

    /// Tax impact of inherited IRA extra withdrawals (Traditional only — Roth is tax-free)
    var inheritedExtraWithdrawalTaxImpact: Double {
        guard inheritedTraditionalExtraTotal > 0 else { return 0 }
        let withoutInherited = totalTaxFor(
            grossIncome: scenarioGrossIncome - inheritedTraditionalExtraTotal,
            deduction: effectiveDeductionAmount
        )
        return scenarioTotalTax - withoutInherited
    }

    /// IRMAA surcharge increase caused by inherited IRA extra withdrawals (cliff-based).
    var inheritedExtraWithdrawalIRMAAImpact: Double {
        guard inheritedTraditionalExtraTotal > 0, medicareMemberCount > 0 else { return 0 }
        let magiWithout = estimatedAGI - inheritedTraditionalExtraTotal
        let irmaaWithout = calculateIRMAA(magi: magiWithout, filingStatus: filingStatus)
        let delta = scenarioIRMAA.annualSurchargePerPerson - irmaaWithout.annualSurchargePerPerson
        return delta * Double(medicareMemberCount)
    }

    /// IRMAA surcharge savings from QCD (only the RMD-offsetting portion reduces MAGI).
    var qcdIRMAASavings: Double {
        guard scenarioTotalQCD > 0, medicareMemberCount > 0 else { return 0 }
        let regularRMD = calculateCombinedRMD()
        let taxableQCDOffset = min(scenarioTotalQCD, regularRMD)
        guard taxableQCDOffset > 0 else { return 0 }
        let magiWithoutQCD = estimatedAGI + taxableQCDOffset
        let irmaaWithoutQCD = calculateIRMAA(magi: magiWithoutQCD, filingStatus: filingStatus)
        let delta = irmaaWithoutQCD.annualSurchargePerPerson - scenarioIRMAA.annualSurchargePerPerson
        return delta * Double(medicareMemberCount)
    }

    // MARK: - Per-Decision NIIT Impact
    // These are for display breakdown only — the base tax impact properties already include
    // NIIT via totalTaxFor(). NII stays constant; only MAGI changes.

    /// NIIT increase caused by Roth conversions (not NII, but raises MAGI).
    var rothConversionNIITImpact: Double {
        guard scenarioTotalRothConversion > 0, scenarioNetInvestmentIncome > 0 else { return 0 }
        let magiWithout = estimatedAGI - scenarioTotalRothConversion
        let niitWithout = calculateNIIT(nii: scenarioNetInvestmentIncome, magi: magiWithout, filingStatus: filingStatus)
        return scenarioNIITAmount - niitWithout.annualNIITax
    }

    /// NIIT increase caused by extra withdrawals (not NII, but raises MAGI).
    var extraWithdrawalNIITImpact: Double {
        guard scenarioTotalExtraWithdrawal > 0, scenarioNetInvestmentIncome > 0 else { return 0 }
        let magiWithout = estimatedAGI - scenarioTotalExtraWithdrawal
        let niitWithout = calculateNIIT(nii: scenarioNetInvestmentIncome, magi: magiWithout, filingStatus: filingStatus)
        return scenarioNIITAmount - niitWithout.annualNIITax
    }

    /// NIIT increase caused by inherited IRA extra withdrawals.
    var inheritedExtraWithdrawalNIITImpact: Double {
        guard inheritedTraditionalExtraTotal > 0, scenarioNetInvestmentIncome > 0 else { return 0 }
        let magiWithout = estimatedAGI - inheritedTraditionalExtraTotal
        let niitWithout = calculateNIIT(nii: scenarioNetInvestmentIncome, magi: magiWithout, filingStatus: filingStatus)
        return scenarioNIITAmount - niitWithout.annualNIITax
    }

    /// NIIT savings from QCD (only the RMD-offsetting portion reduces MAGI).
    var qcdNIITSavings: Double {
        guard scenarioTotalQCD > 0, scenarioNetInvestmentIncome > 0 else { return 0 }
        let regularRMD = calculateCombinedRMD()
        let taxableQCDOffset = min(scenarioTotalQCD, regularRMD)
        guard taxableQCDOffset > 0 else { return 0 }
        let magiWithoutQCD = estimatedAGI + taxableQCDOffset
        let niitWithoutQCD = calculateNIIT(nii: scenarioNetInvestmentIncome, magi: magiWithoutQCD, filingStatus: filingStatus)
        return niitWithoutQCD.annualNIITax - scenarioNIITAmount
    }

    /// Tax savings from the stock donation's itemized deduction (FMV for long-term, cost basis for short-term).
    /// This represents the reduction in cash the user must pay in taxes.
    var stockDeductionTaxSavings: Double {
        guard stockDonationEnabled, stockCurrentValue > 0, scenarioEffectiveItemize else { return 0 }
        let stockDeduction = scenarioStockIsLongTerm ? stockCurrentValue : stockPurchasePrice
        let charWithout = scenarioCharitableDeductions - stockDeduction
        let deductionWithout = baseItemizedDeductions + charWithout
        let effectiveDeductionWithout = max(deductionWithout, standardDeductionAmount)
        let withoutDeduction = totalTaxFor(
            grossIncome: scenarioGrossIncome,
            deduction: effectiveDeductionWithout
        )
        return withoutDeduction - scenarioTotalTax
    }

    /// Tax avoided by donating appreciated stock instead of selling.
    /// Long-term gains would be taxed at capital gains rates; short-term gains
    /// at ordinary income rates. Either way, donating avoids realizing the gain.
    var stockCapGainsTaxAvoided: Double {
        guard stockDonationEnabled, scenarioStockGainAvoided > 0 else { return 0 }
        // Compare: current scenario vs. scenario where gain IS realized (added to gross income)
        // but stock deduction is still present (isolates just the gain effect)
        let withGainRealized = totalTaxFor(
            grossIncome: scenarioGrossIncome + scenarioStockGainAvoided,
            deduction: effectiveDeductionAmount,
            nii: scenarioNetInvestmentIncome + scenarioStockGainAvoided
        )
        return withGainRealized - scenarioTotalTax
    }

    /// Total tax savings from stock donation (deduction + avoided cap gains)
    var stockDonationTaxSavings: Double {
        stockDeductionTaxSavings + stockCapGainsTaxAvoided
    }

    /// Tax savings from cash donation
    var cashDonationTaxSavings: Double {
        guard cashDonationAmount > 0 else { return 0 }
        let charWithout = scenarioCharitableDeductions - cashDonationAmount
        let deductionWithout = scenarioEffectiveItemize
            ? (baseItemizedDeductions + charWithout)
            : standardDeductionAmount
        let effectiveDeductionWithout = max(deductionWithout, standardDeductionAmount)
        let withoutCash = totalTaxFor(
            grossIncome: scenarioGrossIncome,
            deduction: effectiveDeductionWithout
        )
        return withoutCash - scenarioTotalTax
    }

    // MARK: - Legacy Planning Calculations

    /// Tax the heir avoids because the converted amount is now Roth (tax-free) instead of Traditional.
    var legacyRothConversionHeirSavings: Double {
        guard enableLegacyPlanning, scenarioTotalRothConversion > 0 else { return 0 }
        return scenarioTotalRothConversion * legacyHeirTaxRate
    }

    /// QCD reduces the inherited IRA balance — heir avoids tax on that portion.
    /// Uses the full QCD amount (all QCD shrinks the IRA, regardless of RMD offset).
    var legacyQCDHeirBenefit: Double {
        guard enableLegacyPlanning, scenarioTotalQCD > 0 else { return 0 }
        return scenarioTotalQCD * legacyHeirTaxRate
    }

    /// The user's current-year tax cost for Roth conversion (fed + state + IRMAA).
    var legacyUserCurrentCost: Double {
        rothConversionTaxImpact + rothConversionIRMAAImpact
    }

    /// Net legacy benefit: heir savings minus user's current-year cost.
    var legacyNetBenefit: Double {
        legacyRothConversionHeirSavings + legacyQCDHeirBenefit - legacyUserCurrentCost
    }

    /// Estimated Traditional IRA balance at inheritance after scenario actions.
    var legacyTraditionalAtInheritance: Double {
        max(0, totalTraditionalIRABalance - scenarioTotalRothConversion - scenarioTotalQCD)
    }

    /// Estimated Roth IRA balance at inheritance after scenario actions.
    var legacyRothAtInheritance: Double {
        totalRothBalance + scenarioTotalRothConversion
    }

    /// Heir's estimated total tax on remaining Traditional IRA balance.
    var legacyHeirEstimatedTaxOnTraditional: Double {
        legacyTraditionalAtInheritance * legacyHeirTaxRate
    }

    /// Human-readable description of inheritance rules based on heir type.
    var legacyHeirTypeDescription: String {
        switch legacyHeirType {
        case "spouse":
            return "Your spouse can roll this into their own IRA \u{2014} no forced distribution timeline."
        case "spouseThenChild":
            return "Spouse inherits first (rollover), then your child inherits after \(legacySpouseSurvivorYears) years under the 10-year rule."
        default:
            return "Your heir must withdraw the full balance within 10 years \u{2014} at their tax rate."
        }
    }

    /// Formatted heir tax rate as a percentage string.
    var legacyHeirTaxRateFormatted: String {
        "\(Int(legacyHeirTaxRate * 100))%"
    }

    /// Heir's drawdown period: 10 years (SECURE Act) or 20 years (spouse stretch).
    var legacyDrawdownYears: Int {
        legacyHeirType == "spouse" ? 20 : 10
    }

    /// Total years from owner's death to end of all heir drawdowns.
    /// For spouseThenChild: spouse survivor years + child's 10-year SECURE Act.
    var legacyTotalPostDeathYears: Int {
        switch legacyHeirType {
        case "spouse": return 20
        case "spouseThenChild": return legacySpouseSurvivorYears + 10
        default: return 10
        }
    }

    /// Estimated years until death, based on IRS Single Life Expectancy table.
    /// Capped at a minimum of 5 years to avoid degenerate projections.
    var legacyYearsUntilDeath: Int {
        let factor = singleLifeExpectancyFactor(for: currentAge)
        return max(5, Int(factor))
    }

    /// Estimated age at death for display purposes.
    var legacyEstimatedDeathAge: Int {
        currentAge + legacyYearsUntilDeath
    }

    // MARK: - Legacy Calculation Cache

    /// Cache key capturing all inputs that affect legacy calculations.
    /// When any input changes, the cache is invalidated and results recalculate.
    private struct LegacyCacheKey: Equatable {
        let rothConversion: Double
        let qcd: Double
        let traditionalBalance: Double
        let rothBalance: Double
        let growthRate: Double
        let taxableGrowthRate: Double
        let heirTaxRate: Double
        let heirType: String
        let currentAge: Int
        let rmdAge: Int
        let taxPaid: Double
        let spouseSurvivorYears: Int
    }

    /// Cached results of expensive legacy calculations.
    private struct LegacyCacheResults {
        let breakEvenHeirTaxRate: Double
        let breakEvenAtHorizons: [(years: Int, rate: Double, advantage: Double)]
        let compoundingChartData: [LegacyCompoundingPoint]
        let breakEvenYear: Int?
    }

    /// The current cache key — computed from live inputs.
    private var legacyCacheKey: LegacyCacheKey {
        LegacyCacheKey(
            rothConversion: scenarioTotalRothConversion,
            qcd: scenarioTotalQCD,
            traditionalBalance: totalTraditionalIRABalance,
            rothBalance: totalRothBalance,
            growthRate: primaryGrowthRate,
            taxableGrowthRate: taxableAccountGrowthRate,
            heirTaxRate: legacyHeirTaxRate,
            heirType: legacyHeirType,
            currentAge: currentAge,
            rmdAge: rmdAge,
            taxPaid: legacyConversionTaxPaidToday,
            spouseSurvivorYears: legacySpouseSurvivorYears
        )
    }

    /// Stored cache key from last calculation.
    private var _legacyCachedKey: LegacyCacheKey?
    /// Stored cached results.
    private var _legacyCachedResults: LegacyCacheResults?

    /// Returns cached results, recalculating only if inputs changed.
    private func getLegacyCachedResults() -> LegacyCacheResults {
        let key = legacyCacheKey
        if let cached = _legacyCachedResults, _legacyCachedKey == key {
            return cached
        }
        let results = computeLegacyResults()
        // Cache on self (class, so mutation is fine)
        (self as DataManager)._legacyCachedKey = key
        (self as DataManager)._legacyCachedResults = results
        return results
    }

    /// Performs all expensive legacy calculations in a single pass.
    private func computeLegacyResults() -> LegacyCacheResults {
        let breakEvenRate = computeBreakEvenHeirTaxRate()
        let horizons = computeBreakEvenAtHorizons()
        let chartData = computeCompoundingChartData()
        let breakEvenYr = computeBreakEvenYear()
        return LegacyCacheResults(
            breakEvenHeirTaxRate: breakEvenRate,
            breakEvenAtHorizons: horizons,
            compoundingChartData: chartData,
            breakEvenYear: breakEvenYr
        )
    }

    // MARK: - Legacy Projection Engine

    /// Projects a Traditional IRA balance forward through the owner's lifetime,
    /// accounting for annual RMDs (starting at rmdAge) and growth.
    /// Returns the balance remaining at death for the heir to inherit.
    private func projectTraditionalToInheritance(startingBalance: Double) -> Double {
        guard startingBalance > 0 else { return 0 }
        var balance = startingBalance
        let years = legacyYearsUntilDeath
        for yearOffset in 0..<years {
            let projectedAge = currentAge + yearOffset + 1
            // Take RMD if at or past RMD age
            if projectedAge >= rmdAge {
                let rmd = calculateRMD(for: projectedAge, balance: balance)
                balance -= rmd
            }
            // Remaining balance grows
            balance *= (1 + primaryGrowthRate / 100)
        }
        return max(0, balance)
    }

    /// Projects a Roth IRA balance forward through the owner's lifetime.
    /// No RMDs on Roth — it just compounds tax-free.
    private func projectRothToInheritance(startingBalance: Double) -> Double {
        guard startingBalance > 0 else { return 0 }
        let years = legacyYearsUntilDeath
        return startingBalance * pow(1 + primaryGrowthRate / 100, Double(years))
    }

    /// Projects total withdrawals during heir's drawdown period with growth.
    /// Returns total amount withdrawn (larger than starting balance due to continued growth).
    private func projectHeirDrawdownTotal(startingBalance: Double) -> Double {
        guard startingBalance > 0 else { return 0 }
        var balance = startingBalance
        var totalWithdrawn = 0.0
        let years = legacyDrawdownYears
        for yearsLeft in stride(from: years, through: 1, by: -1) {
            let withdrawal = balance / Double(yearsLeft)
            totalWithdrawn += withdrawal
            balance -= withdrawal
            balance *= (1 + primaryGrowthRate / 100)
        }
        return totalWithdrawn
    }

    // MARK: - Spouse-then-Child Chain Projections

    /// Projects Traditional IRA through three phases: owner's life → spouse rollover → child's 10-year drawdown.
    /// Phase 1: Owner takes RMDs, balance grows until owner's death.
    /// Phase 2: Spouse rolls into own IRA, takes spouse RMDs, balance grows for survivor years.
    /// Phase 3: Child inherits and must empty in 10 years (SECURE Act).
    private func projectTraditionalSpouseThenChild(startingBalance: Double) -> Double {
        guard startingBalance > 0 else { return 0 }

        // Phase 1: Owner's lifetime (reuse existing function)
        let balanceAtOwnerDeath = projectTraditionalToInheritance(startingBalance: startingBalance)

        // Phase 2: Spouse rollover period — spouse takes RMDs based on their age
        var balance = balanceAtOwnerDeath
        let spouseAgeAtInheritance = (currentYear - spouseBirthYear) + legacyYearsUntilDeath
        // Compute spouse RMD age from birth year directly (avoid enableSpouse guard)
        let spouseRmdStartAge: Int = spouseBirthYear >= 1960 ? 75 : (spouseBirthYear >= 1951 ? 73 : 72)

        for yearOffset in 0..<legacySpouseSurvivorYears {
            let spouseAge = spouseAgeAtInheritance + yearOffset + 1
            if spouseAge >= spouseRmdStartAge {
                let rmd = calculateRMD(for: spouseAge, balance: balance)
                balance -= rmd
            }
            balance *= (1 + primaryGrowthRate / 100)
        }
        let balanceAtSpouseDeath = max(0, balance)

        // Phase 3: Child inherits — 10-year SECURE Act forced drawdown
        // Use projectHeirDrawdownTotal which uses legacyDrawdownYears (10 for spouseThenChild)
        return projectHeirDrawdownTotal(startingBalance: balanceAtSpouseDeath)
    }

    /// Projects Roth IRA through three phases: owner's life → spouse rollover → child's 10-year drawdown.
    /// Roth has no RMDs for owner or spouse (spousal rollover), so phases 1+2 are pure compounding.
    private func projectRothSpouseThenChild(startingBalance: Double) -> Double {
        guard startingBalance > 0 else { return 0 }

        // Phases 1+2: Pure compounding through owner's life + spouse's rollover period (no Roth RMDs)
        let totalCompoundingYears = legacyYearsUntilDeath + legacySpouseSurvivorYears
        let balanceAtSpouseDeath = startingBalance * pow(1 + primaryGrowthRate / 100, Double(totalCompoundingYears))

        // Phase 3: Child inherits — 10-year drawdown (all tax-free for Roth)
        return projectHeirDrawdownTotal(startingBalance: balanceAtSpouseDeath)
    }

    // MARK: - "Do Nothing" Scenario (no conversions, no QCDs)

    /// Traditional IRA balance at death WITHOUT any scenario actions.
    var legacyNoActionTraditionalAtDeath: Double {
        projectTraditionalToInheritance(startingBalance: totalTraditionalIRABalance)
    }

    /// Roth IRA balance at death WITHOUT any scenario actions.
    var legacyNoActionRothAtDeath: Double {
        projectRothToInheritance(startingBalance: totalRothBalance)
    }

    /// Heir's total taxable drawdown from Traditional IRA WITHOUT scenario (includes growth during drawdown).
    var legacyNoActionHeirTaxableDrawdown: Double {
        if legacyHeirType == "spouseThenChild" {
            return projectTraditionalSpouseThenChild(startingBalance: totalTraditionalIRABalance)
        }
        return projectHeirDrawdownTotal(startingBalance: legacyNoActionTraditionalAtDeath)
    }

    /// Heir's total tax bill WITHOUT scenario actions.
    var legacyCostOfInaction: Double {
        guard enableLegacyPlanning else { return 0 }
        return legacyNoActionHeirTaxableDrawdown * legacyHeirTaxRate
    }

    // MARK: - "With Scenario" Projections

    /// Traditional IRA balance at death WITH scenario actions (conversions + QCDs reduce starting balance).
    var legacyWithScenarioTraditionalAtDeath: Double {
        projectTraditionalToInheritance(startingBalance: legacyTraditionalAtInheritance)
    }

    /// Roth IRA balance at death WITH scenario (original Roth + converted amount, all compounding tax-free).
    var legacyWithScenarioRothAtDeath: Double {
        projectRothToInheritance(startingBalance: legacyRothAtInheritance)
    }

    /// Heir's total taxable drawdown from Traditional IRA WITH scenario.
    var legacyWithScenarioHeirTaxableDrawdown: Double {
        if legacyHeirType == "spouseThenChild" {
            return projectTraditionalSpouseThenChild(startingBalance: legacyTraditionalAtInheritance)
        }
        return projectHeirDrawdownTotal(startingBalance: legacyWithScenarioTraditionalAtDeath)
    }

    /// Heir's tax bill WITH scenario actions.
    var legacyWithScenarioHeirTax: Double {
        guard enableLegacyPlanning else { return 0 }
        return legacyWithScenarioHeirTaxableDrawdown * legacyHeirTaxRate
    }

    // MARK: - Family Totals

    /// Family total tax WITHOUT conversion: just the heir's bill (user pays $0 now).
    var legacyNoConversionFamilyTotal: Double {
        legacyCostOfInaction
    }

    /// Family total tax WITH conversion: user's current cost + heir's reduced bill.
    var legacyWithConversionFamilyTotal: Double {
        legacyUserCurrentCost + legacyWithScenarioHeirTax
    }

    /// Net family tax savings from the scenario decisions.
    var legacyFamilyTaxSavings: Double {
        legacyNoConversionFamilyTotal - legacyWithConversionFamilyTotal
    }

    /// Family savings per $100K converted (for the rate arbitrage metric).
    var legacyPer100KSavings: Double {
        guard scenarioTotalRothConversion > 0 else { return 0 }
        let rothSavingsPerDollar = legacyFamilyTaxSavings / scenarioTotalRothConversion
        return rothSavingsPerDollar * 100_000
    }

    // MARK: - Total Family Wealth Comparison (including opportunity cost)

    /// The tax paid today on the Roth conversion — this money leaves the family's investment pool.
    var legacyConversionTaxPaidToday: Double {
        guard scenarioTotalRothConversion > 0 else { return 0 }
        return rothConversionTaxImpact + rothConversionIRMAAImpact
    }

    /// What the tax money would have grown to if NOT converted (invested in taxable account).
    /// This is the opportunity cost of paying the conversion tax today.
    var legacyTaxMoneyFutureValue: Double {
        guard legacyConversionTaxPaidToday > 0 else { return 0 }
        let years = Double(legacyYearsUntilDeath + legacyTotalPostDeathYears)
        return legacyConversionTaxPaidToday * pow(1 + taxableAccountGrowthRate / 100, years)
    }

    /// TOTAL FAMILY WEALTH without conversion:
    /// Heir's after-tax Traditional IRA drawdown + tax money that stayed invested in taxable account.
    var legacyNoConversionTotalWealth: Double {
        let heirAfterTaxTraditional = legacyNoActionHeirTaxableDrawdown * (1 - legacyHeirTaxRate)
        let heirRothTaxFree: Double
        if legacyHeirType == "spouseThenChild" {
            heirRothTaxFree = projectRothSpouseThenChild(startingBalance: totalRothBalance)
        } else {
            heirRothTaxFree = projectHeirDrawdownTotal(startingBalance: legacyNoActionRothAtDeath)
        }
        let taxMoneyKept = legacyTaxMoneyFutureValue
        return heirAfterTaxTraditional + heirRothTaxFree + taxMoneyKept
    }

    /// TOTAL FAMILY WEALTH with conversion:
    /// Heir's after-tax Traditional (smaller) + heir's tax-free Roth (larger) — no tax money left over.
    var legacyWithConversionTotalWealth: Double {
        let heirAfterTaxTraditional = legacyWithScenarioHeirTaxableDrawdown * (1 - legacyHeirTaxRate)
        let heirRothTaxFree: Double
        if legacyHeirType == "spouseThenChild" {
            heirRothTaxFree = projectRothSpouseThenChild(startingBalance: legacyRothAtInheritance)
        } else {
            heirRothTaxFree = projectHeirDrawdownTotal(startingBalance: legacyWithScenarioRothAtDeath)
        }
        return heirAfterTaxTraditional + heirRothTaxFree
    }

    /// Net family wealth advantage from conversion.
    var legacyFamilyWealthAdvantage: Double {
        legacyWithConversionTotalWealth - legacyNoConversionTotalWealth
    }

    // MARK: - Break-Even Analysis (Numerical — consistent with wealth model)

    /// Computes family wealth advantage for a given heir tax rate using the full simulation
    /// (including RMD drag, growth differentials, drawdown periods).
    /// This ensures break-even is consistent with the main wealth comparison.
    private func familyWealthAdvantageAtHeirRate(_ testRate: Double) -> Double {
        guard scenarioTotalRothConversion > 0 else { return 0 }
        let rTaxable = taxableAccountGrowthRate / 100

        // "No conversion" wealth: heir's after-tax Traditional + Roth + tax money kept invested
        let noActionHeirTaxableDrawdown: Double
        let noActionRothDrawdown: Double
        if legacyHeirType == "spouseThenChild" {
            noActionHeirTaxableDrawdown = projectTraditionalSpouseThenChild(startingBalance: totalTraditionalIRABalance)
            noActionRothDrawdown = projectRothSpouseThenChild(startingBalance: totalRothBalance)
        } else {
            noActionHeirTaxableDrawdown = projectHeirDrawdownTotal(startingBalance: legacyNoActionTraditionalAtDeath)
            noActionRothDrawdown = projectHeirDrawdownTotal(startingBalance: legacyNoActionRothAtDeath)
        }
        let noActionHeirAfterTax = noActionHeirTaxableDrawdown * (1 - testRate)
        let totalYears = Double(legacyYearsUntilDeath + legacyTotalPostDeathYears)
        let taxMoneyGrown = legacyConversionTaxPaidToday * pow(1 + rTaxable, totalYears)
        let noConversionWealth = noActionHeirAfterTax + noActionRothDrawdown + taxMoneyGrown

        // "With conversion" wealth: heir's after-tax smaller Traditional + larger Roth
        let withHeirTaxableDrawdown: Double
        let withRothDrawdown: Double
        if legacyHeirType == "spouseThenChild" {
            withHeirTaxableDrawdown = projectTraditionalSpouseThenChild(startingBalance: legacyTraditionalAtInheritance)
            withRothDrawdown = projectRothSpouseThenChild(startingBalance: legacyRothAtInheritance)
        } else {
            withHeirTaxableDrawdown = projectHeirDrawdownTotal(startingBalance: legacyWithScenarioTraditionalAtDeath)
            withRothDrawdown = projectHeirDrawdownTotal(startingBalance: legacyWithScenarioRothAtDeath)
        }
        let withHeirAfterTax = withHeirTaxableDrawdown * (1 - testRate)
        let withConversionWealth = withHeirAfterTax + withRothDrawdown

        return withConversionWealth - noConversionWealth
    }

    /// Numerically finds the heir tax rate where family wealth advantage = 0.
    /// Uses bisection method for reliability. Returns 0 if conversion always wins, 1.0 if never wins.
    var legacyBreakEvenHeirTaxRate: Double {
        return getLegacyCachedResults().breakEvenHeirTaxRate
    }

    private func computeBreakEvenHeirTaxRate() -> Double {
        guard scenarioTotalRothConversion > 0, legacyConversionTaxPaidToday > 0 else { return 0 }

        let advantageAt0 = familyWealthAdvantageAtHeirRate(0.0)
        if advantageAt0 >= 0 { return 0 }

        let advantageAt100 = familyWealthAdvantageAtHeirRate(1.0)
        if advantageAt100 <= 0 { return 1.0 }

        var lo = 0.0
        var hi = 1.0
        for _ in 0..<50 {
            let mid = (lo + hi) / 2
            let adv = familyWealthAdvantageAtHeirRate(mid)
            if adv < 0 { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    /// Whether the conversion is mathematically favorable based on break-even analysis.
    var legacyConversionIsFavorable: Bool {
        legacyHeirTaxRate > legacyBreakEvenHeirTaxRate
    }

    /// Family wealth advantage at multiple time horizons.
    /// Uses simplified projection (no RMD drag) for the horizon table since we vary the time.
    var legacyBreakEvenAtHorizons: [(years: Int, rate: Double, advantage: Double)] {
        return getLegacyCachedResults().breakEvenAtHorizons
    }

    private func computeBreakEvenAtHorizons() -> [(years: Int, rate: Double, advantage: Double)] {
        guard scenarioTotalRothConversion > 0, legacyConversionTaxPaidToday > 0 else { return [] }
        let rPretax = primaryGrowthRate / 100
        let rTaxable = taxableAccountGrowthRate / 100
        let heirRate = legacyHeirTaxRate

        return [10, 20, 30].map { totalYears in
            let rothFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(totalYears))
            let tradFV = rothFV * (1 - heirRate)
            let taxKeptFV = legacyConversionTaxPaidToday * pow(1 + rTaxable, Double(totalYears))
            let advantage = rothFV - tradFV - taxKeptFV

            var lo = 0.0
            var hi = 1.0
            for _ in 0..<40 {
                let mid = (lo + hi) / 2
                let testTradFV = rothFV * (1 - mid)
                let testAdv = rothFV - testTradFV - taxKeptFV
                if testAdv < 0 { lo = mid } else { hi = mid }
            }
            let breakEven = (lo + hi) / 2
            return (years: totalYears, rate: breakEven, advantage: advantage)
        }
    }

    // MARK: - Compounding Divergence Chart Data

    /// Data point for the Roth vs Traditional compounding chart.
    struct LegacyCompoundingPoint: Identifiable {
        let id = UUID()
        let year: Int
        let rothValue: Double       // Tax-free value to heir
        let traditionalValue: Double // After-tax value to heir + tax money kept
    }

    /// Year-by-year data showing how Roth and Traditional paths diverge.
    /// Roth path: converted amount compounds tax-free.
    /// Traditional path: same amount compounds tax-deferred (heir pays tax) + tax money compounds at after-tax rate.
    var legacyCompoundingChartData: [LegacyCompoundingPoint] {
        return getLegacyCachedResults().compoundingChartData
    }

    private func computeCompoundingChartData() -> [LegacyCompoundingPoint] {
        guard scenarioTotalRothConversion > 0, legacyConversionTaxPaidToday > 0 else { return [] }
        let converted = scenarioTotalRothConversion
        let taxPaid = legacyConversionTaxPaidToday
        let rPretax = primaryGrowthRate / 100
        let rTaxable = taxableAccountGrowthRate / 100
        let heirRate = legacyHeirTaxRate
        let maxYears = min(40, legacyYearsUntilDeath + legacyTotalPostDeathYears)

        var points: [LegacyCompoundingPoint] = []
        for year in stride(from: 0, through: maxYears, by: 5) {
            let rothFV = converted * pow(1 + rPretax, Double(year))
            let tradFV = converted * pow(1 + rPretax, Double(year)) * (1 - heirRate)
            let taxKeptFV = taxPaid * pow(1 + rTaxable, Double(year))
            points.append(LegacyCompoundingPoint(year: year, rothValue: rothFV, traditionalValue: tradFV + taxKeptFV))
        }
        if maxYears % 5 != 0 {
            let rothFV = converted * pow(1 + rPretax, Double(maxYears))
            let tradFV = converted * pow(1 + rPretax, Double(maxYears)) * (1 - heirRate)
            let taxKeptFV = taxPaid * pow(1 + rTaxable, Double(maxYears))
            points.append(LegacyCompoundingPoint(year: maxYears, rothValue: rothFV, traditionalValue: tradFV + taxKeptFV))
        }
        return points
    }

    /// The year at which the Roth path overtakes the Traditional+tax path.
    /// Returns nil if Roth always wins (break-even at year 0) or never wins within the projection.
    var legacyBreakEvenYear: Int? {
        return getLegacyCachedResults().breakEvenYear
    }

    private func computeBreakEvenYear() -> Int? {
        guard scenarioTotalRothConversion > 0, legacyConversionTaxPaidToday > 0 else { return nil }
        let converted = scenarioTotalRothConversion
        let taxPaid = legacyConversionTaxPaidToday
        let rPretax = primaryGrowthRate / 100
        let rTaxable = taxableAccountGrowthRate / 100
        let heirRate = legacyHeirTaxRate
        let maxYears = legacyYearsUntilDeath + legacyTotalPostDeathYears

        let roth0 = converted
        let trad0 = converted * (1 - heirRate) + taxPaid
        if roth0 >= trad0 { return 0 }

        for year in 1...maxYears {
            let rothFV = converted * pow(1 + rPretax, Double(year))
            let tradFV = converted * pow(1 + rPretax, Double(year)) * (1 - heirRate)
            let taxKeptFV = taxPaid * pow(1 + rTaxable, Double(year))
            if rothFV >= (tradFV + taxKeptFV) { return year }
        }
        return nil
    }

    /// "Return on taxes paid" — frames the conversion as an investment decision.
    /// Family wealth gained divided by tax paid, annualized over the projection period.
    var legacyReturnOnTaxesPaid: Double {
        guard legacyConversionTaxPaidToday > 0 else { return 0 }
        let gain = legacyFamilyWealthAdvantage
        return (gain / legacyConversionTaxPaidToday) * 100
    }

    /// Enhanced heir type description with peak-earning-years framing.
    var legacyHeirTypeDescriptionDetailed: String {
        switch legacyHeirType {
        case "spouse":
            return "Your spouse can roll this into their own IRA \u{2014} no forced distribution timeline. Projected over ~\(legacyDrawdownYears) years."
        case "spouseThenChild":
            return "Your spouse rolls this into their own IRA for ~\(legacySpouseSurvivorYears) years, then your child inherits and must withdraw everything within 10 years \u{2014} during their peak earning years."
        default:
            return "Your heir must withdraw everything within 10 years \u{2014} typically during their peak earning years (50s\u{2013}60s), at their highest tax rates."
        }
    }

    // MARK: - Widow Tax Bracket Analysis

    /// Whether the widow tax bracket analysis applies (married filing jointly with spouse enabled).
    var widowBracketApplies: Bool {
        filingStatus == .marriedFilingJointly && enableSpouse
    }

    /// The taxable income used for bracket comparison (scenario or baseline).
    var widowComparisonIncome: Double {
        hasActiveScenario ? scenarioTaxableIncome : scenarioBaseIncome
    }

    /// Current marginal federal bracket rate as Married Filing Jointly.
    var widowCurrentMarginalRate: Double {
        let info = federalBracketInfo(income: widowComparisonIncome, filingStatus: .marriedFilingJointly)
        return info.currentRate
    }

    /// Marginal federal bracket rate the surviving spouse would face filing Single on similar income.
    /// Uses ~90% of current income to approximate post-death income (one SS benefit drops off,
    /// but RMDs, pensions, and investments remain).
    var widowSurvivorMarginalRate: Double {
        let survivorIncome = widowComparisonIncome * 0.85
        let info = federalBracketInfo(income: survivorIncome, filingStatus: .single)
        return info.currentRate
    }

    /// The bracket jump in percentage points (e.g., 24% → 32% = 8 points).
    var widowBracketJump: Double {
        widowSurvivorMarginalRate - widowCurrentMarginalRate
    }

    /// Whether there is a meaningful bracket jump for the survivor.
    var widowHasBracketJump: Bool {
        widowBracketApplies && widowBracketJump > 0
    }

    /// Estimated additional tax per year the survivor would pay on RMD income
    /// due to the bracket jump.
    var widowAdditionalTaxPerYear: Double {
        guard widowHasBracketJump else { return 0 }
        // Approximate: the RMD portion that moves into the higher bracket
        let rmdIncome = calculateRMD(for: max(rmdAge, currentAge), balance: totalTraditionalIRABalance)
        return rmdIncome * widowBracketJump
    }

    /// Tax saved per dollar converted now (convert at married rate, avoid survivor's single rate).
    var widowSavingsPerDollarConverted: Double {
        guard widowHasBracketJump else { return 0 }
        return widowSurvivorMarginalRate - widowCurrentMarginalRate
    }

    /// Estimated tax saved on the scenario's Roth conversion amount due to bracket arbitrage.
    var widowConversionBracketSavings: Double {
        guard widowHasBracketJump, scenarioTotalRothConversion > 0 else { return 0 }
        return scenarioTotalRothConversion * widowSavingsPerDollarConverted
    }

    // MARK: - Setup Progress

    var setupProgress: SetupProgress {
        let defaultComponents = DateComponents(year: 1953, month: 1, day: 1)
        let defaultDate = Calendar.current.date(from: defaultComponents)!
        return SetupProgress(
            hasSetBirthDate: birthDate != defaultDate,
            hasAccounts: !iraAccounts.isEmpty,
            hasIncomeSources: !incomeSources.isEmpty,
            hasDeductions: !deductionItems.isEmpty
        )
    }
}

// MARK: - Setup Progress Model

struct SetupProgress {
    let hasSetBirthDate: Bool
    let hasAccounts: Bool
    let hasIncomeSources: Bool
    let hasDeductions: Bool

    var completedSteps: Int {
        [hasSetBirthDate, hasAccounts, hasIncomeSources, hasDeductions].filter { $0 }.count
    }
    var totalSteps: Int { 4 }
    var isComplete: Bool { completedSteps == totalSteps }
}

// MARK: - Quarterly Breakdown Model

struct QuarterlyBreakdown {
    var q1: Double = 0
    var q2: Double = 0
    var q3: Double = 0
    var q4: Double = 0

    var total: Double { q1 + q2 + q3 + q4 }

    subscript(quarter: Int) -> Double {
        get {
            switch quarter {
            case 1: return q1
            case 2: return q2
            case 3: return q3
            case 4: return q4
            default: return 0
            }
        }
        set {
            switch quarter {
            case 1: q1 = newValue
            case 2: q2 = newValue
            case 3: q3 = newValue
            case 4: q4 = newValue
            default: break
            }
        }
    }
}

struct FederalStateQuarterlyBreakdown {
    var federal: QuarterlyBreakdown = QuarterlyBreakdown()
    var state: QuarterlyBreakdown = QuarterlyBreakdown()

    /// Combined payment per quarter (backward-compatible)
    var q1: Double { federal.q1 + state.q1 }
    var q2: Double { federal.q2 + state.q2 }
    var q3: Double { federal.q3 + state.q3 }
    var q4: Double { federal.q4 + state.q4 }

    var total: Double { federal.total + state.total }
    var federalTotal: Double { federal.total }
    var stateTotal: Double { state.total }

    subscript(quarter: Int) -> Double { federal[quarter] + state[quarter] }
}

// MARK: - Data Models

enum Owner: String, Codable, CaseIterable {
    case primary = "You"
    case spouse = "Spouse"
    case joint = "Joint"
}
    
struct IRAAccount: Identifiable, Codable {
    let id: UUID
    var name: String
    var accountType: AccountType
    var balance: Double
    var institution: String
    var owner: Owner

    // Inherited IRA fields (nil for regular accounts)
    var beneficiaryType: BeneficiaryType?
    var decedentRBDStatus: DecedentRBDStatus?
    var yearOfInheritance: Int?
    var decedentBirthYear: Int?
    var beneficiaryBirthYear: Int?
    var minorChildMajorityYear: Int?

    init(id: UUID = UUID(), name: String, accountType: AccountType, balance: Double, institution: String = "", owner: Owner = .primary,
         beneficiaryType: BeneficiaryType? = nil, decedentRBDStatus: DecedentRBDStatus? = nil,
         yearOfInheritance: Int? = nil, decedentBirthYear: Int? = nil,
         beneficiaryBirthYear: Int? = nil, minorChildMajorityYear: Int? = nil) {
        self.id = id
        self.name = name
        self.accountType = accountType
        self.balance = balance
        self.institution = institution
        self.owner = owner
        self.beneficiaryType = beneficiaryType
        self.decedentRBDStatus = decedentRBDStatus
        self.yearOfInheritance = yearOfInheritance
        self.decedentBirthYear = decedentBirthYear
        self.beneficiaryBirthYear = beneficiaryBirthYear
        self.minorChildMajorityYear = minorChildMajorityYear
    }
}

enum AccountType: String, Codable, CaseIterable {
    case traditionalIRA = "Traditional IRA"
    case rothIRA = "Roth IRA"
    case traditional401k = "Traditional 401(k)"
    case roth401k = "Roth 401(k)"
    case inheritedTraditionalIRA = "Inherited Traditional IRA"
    case inheritedRothIRA = "Inherited Roth IRA"

    var isInherited: Bool {
        self == .inheritedTraditionalIRA || self == .inheritedRothIRA
    }

    var isTraditionalType: Bool {
        self == .traditionalIRA || self == .traditional401k || self == .inheritedTraditionalIRA
    }

    var isRothType: Bool {
        self == .rothIRA || self == .roth401k || self == .inheritedRothIRA
    }
}

enum BeneficiaryType: String, Codable, CaseIterable {
    case spouse = "Spouse"
    case minorChild = "Minor Child"
    case disabled = "Disabled Individual"
    case chronicallyIll = "Chronically Ill Individual"
    case notTenYearsYounger = "Not >10 Years Younger"
    case nonEligibleDesignated = "Non-Eligible Designated"

    /// Eligible Designated Beneficiaries get lifetime stretch; others get 10-year rule
    var isEligibleDesignated: Bool {
        switch self {
        case .spouse, .minorChild, .disabled, .chronicallyIll, .notTenYearsYounger:
            return true
        case .nonEligibleDesignated:
            return false
        }
    }
}

enum DecedentRBDStatus: String, Codable, CaseIterable {
    case beforeRBD = "Before RBD"
    case afterRBD = "After RBD"
}

struct IncomeSource: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: IncomeType
    var annualAmount: Double
    var federalWithholding: Double
    var stateWithholding: Double
    var owner: Owner

    /// Combined federal + state withholding for this source
    var totalWithholding: Double { federalWithholding + stateWithholding }

    init(id: UUID = UUID(), name: String, type: IncomeType, annualAmount: Double, federalWithholding: Double = 0, stateWithholding: Double = 0, owner: Owner = .primary) {
        self.id = id
        self.name = name
        self.type = type
        self.annualAmount = annualAmount
        self.federalWithholding = federalWithholding
        self.stateWithholding = stateWithholding
        self.owner = owner
    }

    // MARK: - Data Migration
    // Decode legacy data that used a single "taxWithholding" field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(IncomeType.self, forKey: .type)
        annualAmount = try container.decode(Double.self, forKey: .annualAmount)
        owner = try container.decode(Owner.self, forKey: .owner)

        // Try new keys first; fall back to legacy "taxWithholding" → federalWithholding
        if let fed = try? container.decode(Double.self, forKey: .federalWithholding) {
            federalWithholding = fed
            stateWithholding = (try? container.decode(Double.self, forKey: .stateWithholding)) ?? 0
        } else {
            let legacy = (try? container.decode(Double.self, forKey: .taxWithholding)) ?? 0
            federalWithholding = legacy
            stateWithholding = 0
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, type, annualAmount, federalWithholding, stateWithholding, owner, taxWithholding
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(annualAmount, forKey: .annualAmount)
        try container.encode(federalWithholding, forKey: .federalWithholding)
        try container.encode(stateWithholding, forKey: .stateWithholding)
        try container.encode(owner, forKey: .owner)
    }
}
    
    enum IncomeType: String, Codable, CaseIterable {
        case socialSecurity = "Social Security"
        case pension = "Pension"
        case dividends = "Dividends"
        case qualifiedDividends = "Qualified Dividends"
        case interest = "Interest"
        case capitalGainsShort = "Capital Gains (Short-term)"
        case capitalGainsLong = "Capital Gains (Long-term)"
        case consulting = "Employment/Other Income"
        case stateTaxRefund = "State Tax Refund"
        case rmd = "RMD"
        case rothConversion = "Roth Conversion"
        case other = "Other"
    }
    
    enum FilingStatus: String, Codable, CaseIterable {
        case single = "Single"
        case marriedFilingJointly = "Married Filing Jointly"
    }

enum DeductionChoice: String, Codable {
    case standard
    case itemized
}

struct DeductionItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: DeductionType
    var annualAmount: Double
    var owner: Owner

    init(id: UUID = UUID(), name: String, type: DeductionType, annualAmount: Double, owner: Owner = .primary) {
        self.id = id
        self.name = name
        self.type = type
        self.annualAmount = annualAmount
        self.owner = owner
    }
}

enum DeductionType: String, Codable, CaseIterable {
    case mortgageInterest = "Mortgage Interest"
    case propertyTax = "Property Tax"
    case saltTax = "State & Local Tax (SALT)"
    case medicalExpenses = "Medical Expenses"
    case other = "Other Itemized"
}
    
struct QuarterlyPayment: Identifiable, Codable {
        let id: UUID
        var quarter: Int // 1-4
        var year: Int
        var dueDate: Date
        var estimatedAmount: Double
        var paidAmount: Double
        var isPaid: Bool
        
        init(id: UUID = UUID(), quarter: Int, year: Int, dueDate: Date, estimatedAmount: Double, paidAmount: Double = 0, isPaid: Bool = false) {
            self.id = id
            self.quarter = quarter
            self.year = year
            self.dueDate = dueDate
            self.estimatedAmount = estimatedAmount
            self.paidAmount = paidAmount
            self.isPaid = isPaid
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
