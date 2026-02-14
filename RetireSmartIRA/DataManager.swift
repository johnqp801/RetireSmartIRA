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
    @Published var birthYear: Int = 1953
    @Published var currentYear: Int = Calendar.current.component(.year, from: Date())
    @Published var filingStatus: FilingStatus = .single
    @Published var spouseName: String = ""
    @Published var spouseBirthYear: Int = 1955
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
    @Published var qcdAmount: Double = 0
    @Published var stockDonationEnabled: Bool = false
    @Published var stockPurchasePrice: Double = 0
    @Published var stockCurrentValue: Double = 0
    @Published var stockPurchaseDate: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
    @Published var cashDonationAmount: Double = 0
    @Published var deductionOverride: DeductionChoice? = nil  // nil = auto-pick best
    @Published var completedActionKeys: Set<String> = []

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
        var stateSingle: [TaxBracket]
        var stateMarried: [TaxBracket]
        var federalCapGainsSingle: [TaxBracket]
        var federalCapGainsMarried: [TaxBracket]
    }
    
    // MARK: - Tax Bracket Storage
    @Published var currentTaxBrackets: TaxBrackets
    
    // Initialize with 2026 defaults
    static let default2026Brackets = TaxBrackets(
        federalSingle: [
            TaxBracket(threshold: 0, rate: 0.10),
            TaxBracket(threshold: 11_925, rate: 0.12),
            TaxBracket(threshold: 48_475, rate: 0.22),
            TaxBracket(threshold: 103_350, rate: 0.24),
            TaxBracket(threshold: 197_300, rate: 0.32),
            TaxBracket(threshold: 250_525, rate: 0.35),
            TaxBracket(threshold: 626_350, rate: 0.37)
        ],
        federalMarried: [
            TaxBracket(threshold: 0, rate: 0.10),
            TaxBracket(threshold: 23_850, rate: 0.12),
            TaxBracket(threshold: 96_950, rate: 0.22),
            TaxBracket(threshold: 206_700, rate: 0.24),
            TaxBracket(threshold: 394_600, rate: 0.32),
            TaxBracket(threshold: 501_050, rate: 0.35),
            TaxBracket(threshold: 751_600, rate: 0.37)
        ],
        stateSingle: [
            TaxBracket(threshold: 0, rate: 0.01),
            TaxBracket(threshold: 10_412, rate: 0.02),
            TaxBracket(threshold: 24_684, rate: 0.04),
            TaxBracket(threshold: 38_959, rate: 0.06),
            TaxBracket(threshold: 54_081, rate: 0.08),
            TaxBracket(threshold: 68_350, rate: 0.093),
            TaxBracket(threshold: 349_137, rate: 0.103),
            TaxBracket(threshold: 418_961, rate: 0.113),
            TaxBracket(threshold: 698_271, rate: 0.123)
        ],
        stateMarried: [
            TaxBracket(threshold: 0, rate: 0.01),
            TaxBracket(threshold: 20_824, rate: 0.02),
            TaxBracket(threshold: 49_368, rate: 0.04),
            TaxBracket(threshold: 77_918, rate: 0.06),
            TaxBracket(threshold: 108_162, rate: 0.08),
            TaxBracket(threshold: 136_700, rate: 0.093),
            TaxBracket(threshold: 698_274, rate: 0.103),
            TaxBracket(threshold: 837_922, rate: 0.113),
            TaxBracket(threshold: 1_396_542, rate: 0.123)
        ],
        federalCapGainsSingle: [
            TaxBracket(threshold: 0, rate: 0.0),
            TaxBracket(threshold: 48_350, rate: 0.15),
            TaxBracket(threshold: 533_400, rate: 0.20)
        ],
        federalCapGainsMarried: [
            TaxBracket(threshold: 0, rate: 0.0),
            TaxBracket(threshold: 96_700, rate: 0.15),
            TaxBracket(threshold: 600_050, rate: 0.20)
        ]
    )
    
    
    // Computed Properties
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
    
    var isQCDEligible: Bool {
            currentAge >= 71
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
            return spouseCurrentAge >= 71
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

    func calculateCaliforniaTax(income: Double, filingStatus: FilingStatus = .single) -> Double {
        // California taxes capital gains as ordinary income — no preferential rates
        let brackets = filingStatus == .single ? currentTaxBrackets.stateSingle : currentTaxBrackets.stateMarried
        return progressiveTax(income: income, brackets: brackets)
    }
    
    func totalAnnualIncome() -> Double {
        incomeSources.reduce(0) { $0 + $1.annualAmount }
    }
    
    // MARK: - Roth Conversion Analysis
    
    func analyzeRothConversion(conversionAmount: Double) -> RothConversionAnalysis {
        let currentIncome = taxableIncome(filingStatus: filingStatus)
        let newIncome = currentIncome + conversionAmount

        let currentFederalTax = calculateFederalTax(income: currentIncome, filingStatus: filingStatus)
        let newFederalTax = calculateFederalTax(income: newIncome, filingStatus: filingStatus)
        let federalTaxOnConversion = newFederalTax - currentFederalTax

        let currentCATax = calculateCaliforniaTax(income: currentIncome, filingStatus: filingStatus)
        let newCATax = calculateCaliforniaTax(income: newIncome, filingStatus: filingStatus)
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
    func stateBracketInfo(income: Double, filingStatus: FilingStatus) -> BracketInfo {
        let brackets = filingStatus == .single ? currentTaxBrackets.stateSingle : currentTaxBrackets.stateMarried
        return bracketInfo(income: income, brackets: brackets)
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

        let stateTaxBefore = calculateCaliforniaTax(income: currentIncome, filingStatus: filingStatus)
        let stateTaxAfter = calculateCaliforniaTax(income: newIncome, filingStatus: filingStatus)
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

        let stateTaxBefore = calculateCaliforniaTax(income: baseIncome, filingStatus: fs)
        let stateTaxAfter = calculateCaliforniaTax(income: scenarioIncome, filingStatus: fs)
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
        let caTax = calculateCaliforniaTax(income: totalIncome, filingStatus: filingStatus)
        let totalAnnualTax = federalTax + caTax

        // 90% safe harbor rule
        return (totalAnnualTax * 0.90) / 4.0
    }
    
    init() {
        // Initialize with defaults first
        self.currentTaxBrackets = DataManager.default2026Brackets

        // Then try to load tax brackets from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "taxBrackets"),
           let decoded = try? JSONDecoder().decode(TaxBrackets.self, from: data) {
            self.currentTaxBrackets = decoded
        }

        // Load persisted user data
        let defaults = UserDefaults.standard
        if defaults.object(forKey: StorageKey.birthYear) != nil {
            self.birthYear = defaults.integer(forKey: StorageKey.birthYear)
        }
        if let raw = defaults.string(forKey: StorageKey.filingStatus),
           let status = FilingStatus(rawValue: raw) {
            self.filingStatus = status
        }
        if let name = defaults.string(forKey: StorageKey.spouseName) {
            self.spouseName = name
        }
        if defaults.object(forKey: StorageKey.spouseBirthYear) != nil {
            self.spouseBirthYear = defaults.integer(forKey: StorageKey.spouseBirthYear)
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
        if defaults.object(forKey: StorageKey.qcdAmount) != nil {
            self.qcdAmount = defaults.double(forKey: StorageKey.qcdAmount)
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
    }
    
    // Save tax brackets whenever they change
    func saveTaxBrackets() {
        if let encoded = try? JSONEncoder().encode(currentTaxBrackets) {
            UserDefaults.standard.set(encoded, forKey: "taxBrackets")
        }
    }

    // MARK: - Persistence Keys
    private enum StorageKey {
        static let birthYear = "birthYear"
        static let filingStatus = "filingStatus"
        static let spouseName = "spouseName"
        static let spouseBirthYear = "spouseBirthYear"
        static let enableSpouse = "enableSpouse"
        static let iraAccounts = "iraAccounts"
        static let incomeSources = "incomeSources"
        static let quarterlyPayments = "quarterlyPayments"
        // Tax Planning scenario
        static let yourRothConversion = "yourRothConversion"
        static let spouseRothConversion = "spouseRothConversion"
        static let yourExtraWithdrawal = "yourExtraWithdrawal"
        static let spouseExtraWithdrawal = "spouseExtraWithdrawal"
        static let qcdAmount = "qcdAmount"
        static let stockDonationEnabled = "stockDonationEnabled"
        static let stockPurchasePrice = "stockPurchasePrice"
        static let stockCurrentValue = "stockCurrentValue"
        static let stockPurchaseDate = "stockPurchaseDate"
        static let cashDonationAmount = "cashDonationAmount"
        static let deductionOverride = "deductionOverride"
        static let completedActionKeys = "completedActionKeys"
        static let deductionItems = "deductionItems"
    }

    /// Saves all user data to UserDefaults for persistence across rebuilds.
    func saveAllData() {
        let defaults = UserDefaults.standard
        defaults.set(birthYear, forKey: StorageKey.birthYear)
        defaults.set(filingStatus.rawValue, forKey: StorageKey.filingStatus)
        defaults.set(spouseName, forKey: StorageKey.spouseName)
        defaults.set(spouseBirthYear, forKey: StorageKey.spouseBirthYear)
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
        defaults.set(qcdAmount, forKey: StorageKey.qcdAmount)
        defaults.set(stockDonationEnabled, forKey: StorageKey.stockDonationEnabled)
        defaults.set(stockPurchasePrice, forKey: StorageKey.stockPurchasePrice)
        defaults.set(stockCurrentValue, forKey: StorageKey.stockCurrentValue)
        defaults.set(stockPurchaseDate.timeIntervalSince1970, forKey: StorageKey.stockPurchaseDate)
        defaults.set(cashDonationAmount, forKey: StorageKey.cashDonationAmount)
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
        let brackets = filingStatus == .single ? currentTaxBrackets.stateSingle : currentTaxBrackets.stateMarried
        
        for bracket in brackets.reversed() {
            if income > bracket.threshold {
                return bracket.rate * 100
            }
        }
        return (brackets.first?.rate ?? 0.01) * 100
    }
    
    func stateAverageRate(income: Double, filingStatus: FilingStatus = .single) -> Double {
        guard income > 0 else { return 0.0 }
        let tax = calculateCaliforniaTax(income: income, filingStatus: filingStatus)
        return (tax / income) * 100
    }
    
    // MARK: - Social Security Taxation
        
    // Calculate taxable portion of Social Security benefits
    func calculateTaxableSocialSecurity(filingStatus: FilingStatus = .single) -> Double {
        // Get Social Security income
        let ssIncome = incomeSources
            .filter { $0.type == .socialSecurity }
            .reduce(0) { $0 + $1.annualAmount }
        
        // Get other income (everything except Social Security)
        let otherIncome = incomeSources
            .filter { $0.type != .socialSecurity }
            .reduce(0) { $0 + $1.annualAmount }
        
        // Combined income = Other income + 50% of Social Security
        let combinedIncome = otherIncome + (ssIncome * 0.5)
        
        // Determine taxable portion based on thresholds
        let (threshold1, threshold2) = filingStatus == .single ? (25_000.0, 34_000.0) : (32_000.0, 44_000.0)
        
        if combinedIncome <= threshold1 {
            // No Social Security is taxable
            return 0.0
        } else if combinedIncome <= threshold2 {
            // Up to 50% is taxable
            let excessOverFirst = combinedIncome - threshold1
            let taxableAmount = min(excessOverFirst, ssIncome * 0.5)
            return taxableAmount
        } else {
            // Up to 85% is taxable
            let excessOverSecond = combinedIncome - threshold2
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
        yourExtraWithdrawal + (enableSpouse ? spouseExtraWithdrawal : 0)
    }

    var scenarioCombinedRMD: Double {
        calculateCombinedRMD()
    }

    var scenarioQCDEligible: Bool {
        isQCDEligible || (enableSpouse && spouseIsQCDEligible)
    }

    var scenarioMaxQCDAmount: Double {
        var cap = 0.0
        if isQCDEligible { cap += 105_000 }
        if enableSpouse && spouseIsQCDEligible { cap += 105_000 }
        return min(scenarioCombinedRMD, cap)
    }

    /// RMD remaining after QCD offset
    var scenarioAdjustedRMD: Double {
        guard scenarioCombinedRMD > 0 else { return 0 }
        return scenarioQCDEligible ? max(0, scenarioCombinedRMD - qcdAmount) : scenarioCombinedRMD
    }

    /// Taxable withdrawals: RMD after QCD + extra withdrawals
    var scenarioTotalWithdrawals: Double {
        let rmdTaxableAfterQCD = max(0, scenarioCombinedRMD - (scenarioQCDEligible ? qcdAmount : 0))
        return rmdTaxableAfterQCD + scenarioTotalExtraWithdrawal
    }

    var scenarioStockIsLongTerm: Bool {
        guard let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) else { return false }
        return stockPurchaseDate <= oneYearAgo
    }

    var scenarioStockGainAvoided: Double {
        guard stockDonationEnabled, scenarioStockIsLongTerm else { return 0 }
        return max(0, stockCurrentValue - stockPurchasePrice)
    }

    /// Total withholding from all income sources
    var totalWithholding: Double {
        incomeSources.reduce(0) { $0 + $1.taxWithholding }
    }

    /// Base income before any scenario decisions (pre-deduction)
    var scenarioBaseIncome: Double {
        taxableIncome(filingStatus: filingStatus)
    }

    /// Gross income including RMDs + scenario decisions (pre-deduction).
    /// Subtracts avoided capital gains from donated stock — that gain was never realized.
    var scenarioGrossIncome: Double {
        scenarioBaseIncome + scenarioTotalRothConversion + scenarioTotalWithdrawals - scenarioStockGainAvoided
    }

    // MARK: - Standard vs. Itemized Deduction

    /// 2026 standard deduction based on filing status and age
    var standardDeductionAmount: Double {
        var amount: Double
        switch filingStatus {
        case .single:
            amount = 16_100
            // Age 65+ additional deduction
            if currentAge >= 65 { amount += 2_050 }
            // 2025-2028 senior bonus (phases out above $75k)
            if currentAge >= 65 && scenarioGrossIncome <= 75_000 {
                amount += 4_000
            }
        case .marriedFilingJointly:
            amount = 32_200
            // Age 65+ additional per person
            if currentAge >= 65 { amount += 1_650 }
            if enableSpouse && spouseCurrentAge >= 65 { amount += 1_650 }
            // 2025-2028 senior bonus (phases out above $150k)
            if (currentAge >= 65 || (enableSpouse && spouseCurrentAge >= 65))
                && scenarioGrossIncome <= 150_000 {
                amount += 8_000
            }
        }
        return amount
    }

    /// Total user-entered itemized deductions (mortgage, property tax, etc.)
    var baseItemizedDeductions: Double {
        deductionItems.reduce(0) { $0 + $1.annualAmount }
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
        calculateCaliforniaTax(income: scenarioTaxableIncome, filingStatus: filingStatus)
    }

    var scenarioTotalTax: Double {
        scenarioFederalTax + scenarioStateTax
    }

    /// Tax remaining after withholding
    var scenarioRemainingTax: Double {
        max(0, scenarioTotalTax - totalWithholding)
    }

    /// Quarterly estimated tax payment (90% safe harbor minus withholding)
    var scenarioQuarterlyPayment: Double {
        let safeHarbor = scenarioTotalTax * 0.90 - totalWithholding
        return max(0, safeHarbor / 4.0)
    }

    /// Whether any Tax Planning decisions are active
    var hasActiveScenario: Bool {
        scenarioTotalRothConversion > 0 || scenarioTotalExtraWithdrawal > 0
        || qcdAmount > 0 || (stockDonationEnabled && stockCurrentValue > 0)
        || cashDonationAmount > 0
    }

    /// Total charitable giving (QCD + stock + cash)
    var scenarioTotalCharitable: Double {
        var total = qcdAmount
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
        if qcdAmount > 0 {
            items.append(ActionItem(
                id: "qcd-\(year)",
                title: "Make QCD: \(qcdAmount.formatted(.currency(code: "USD")))",
                detail: "Direct distribution from IRA to qualified charity",
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

        // Quarterly estimated tax payments
        if scenarioQuarterlyPayment > 0 {
            let amount = scenarioQuarterlyPayment.formatted(.currency(code: "USD"))
            items.append(ActionItem(id: "tax-q1-\(year)", title: "Q1 Estimated Tax: \(amount)", detail: "Federal + state estimated tax payment", deadline: "Apr 15, \(year)", category: .estimatedTax))
            items.append(ActionItem(id: "tax-q2-\(year)", title: "Q2 Estimated Tax: \(amount)", detail: "Federal + state estimated tax payment", deadline: "Jun 15, \(year)", category: .estimatedTax))
            items.append(ActionItem(id: "tax-q3-\(year)", title: "Q3 Estimated Tax: \(amount)", detail: "Federal + state estimated tax payment", deadline: "Sep 15, \(year)", category: .estimatedTax))
            items.append(ActionItem(id: "tax-q4-\(year)", title: "Q4 Estimated Tax: \(amount)", detail: "Federal + state estimated tax payment", deadline: "Jan 15, \(year + 1)", category: .estimatedTax))
        }

        return items
    }

    // MARK: - Per-Decision Tax Impact Helpers

    /// Computes total tax for a hypothetical gross income and deduction scenario.
    /// Used internally to measure incremental impact of individual decisions.
    private func totalTaxFor(grossIncome: Double, deduction: Double) -> Double {
        let taxable = max(0, grossIncome - deduction)
        let fed = calculateFederalTax(income: taxable, filingStatus: filingStatus)
        let state = calculateCaliforniaTax(income: taxable, filingStatus: filingStatus)
        return fed + state
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

    /// Tax savings from QCD (reduces taxable withdrawals)
    var qcdTaxSavings: Double {
        guard qcdAmount > 0, scenarioQCDEligible else { return 0 }
        let withoutQCD = totalTaxFor(
            grossIncome: scenarioGrossIncome + qcdAmount,  // QCD portion would be taxable
            deduction: effectiveDeductionAmount
        )
        return withoutQCD - scenarioTotalTax
    }

    /// Tax savings from stock donation (deduction + avoided cap gains).
    /// The avoided gain is already subtracted from scenarioGrossIncome, so the
    /// counterfactual adds it back (gain would have been realized income).
    var stockDonationTaxSavings: Double {
        guard stockDonationEnabled, stockCurrentValue > 0 else { return 0 }
        // Without stock donation: no charitable deduction for stock, gain IS realized
        let charWithout = scenarioCharitableDeductions - (scenarioStockIsLongTerm ? stockCurrentValue : stockPurchasePrice)
        let deductionWithout = scenarioEffectiveItemize
            ? (baseItemizedDeductions + charWithout)
            : standardDeductionAmount
        let effectiveDeductionWithout = max(deductionWithout, standardDeductionAmount)
        // Add back the avoided gain — it would have been part of gross income
        let withoutStock = totalTaxFor(
            grossIncome: scenarioGrossIncome + scenarioStockGainAvoided,
            deduction: effectiveDeductionWithout
        )
        return withoutStock - scenarioTotalTax
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

    // MARK: - Setup Progress

    var setupProgress: SetupProgress {
        SetupProgress(
            hasSetBirthYear: birthYear != 1953,
            hasAccounts: !iraAccounts.isEmpty,
            hasIncomeSources: !incomeSources.isEmpty,
            hasDeductions: !deductionItems.isEmpty
        )
    }
}

// MARK: - Setup Progress Model

struct SetupProgress {
    let hasSetBirthYear: Bool
    let hasAccounts: Bool
    let hasIncomeSources: Bool
    let hasDeductions: Bool

    var completedSteps: Int {
        [hasSetBirthYear, hasAccounts, hasIncomeSources, hasDeductions].filter { $0 }.count
    }
    var totalSteps: Int { 4 }
    var isComplete: Bool { completedSteps == totalSteps }
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
    
    init(id: UUID = UUID(), name: String, accountType: AccountType, balance: Double, institution: String = "", owner: Owner = .primary) {
        self.id = id
        self.name = name
        self.accountType = accountType
        self.balance = balance
        self.institution = institution
        self.owner = owner
    }
}

enum AccountType: String, Codable, CaseIterable {
    case traditionalIRA = "Traditional IRA"
    case rothIRA = "Roth IRA"
    case traditional401k = "Traditional 401(k)"
    case roth401k = "Roth 401(k)"
}

struct IncomeSource: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: IncomeType
    var annualAmount: Double
    var taxWithholding: Double
    var owner: Owner
    
    init(id: UUID = UUID(), name: String, type: IncomeType, annualAmount: Double, taxWithholding: Double = 0, owner: Owner = .primary) {
        self.id = id
        self.name = name
        self.type = type
        self.annualAmount = annualAmount
        self.taxWithholding = taxWithholding
        self.owner = owner
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
        case consulting = "Consulting/1099"
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
