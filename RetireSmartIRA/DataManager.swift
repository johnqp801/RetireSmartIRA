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
    // MARK: - Domain Managers
    let profile = ProfileManager()
    let accounts = AccountsManager()
    let incomeDeductions = IncomeDeductionsManager()
    let scenario = ScenarioStateManager()
    let growthRates = GrowthRatesManager()
    let legacy = LegacyPlanningManager()
    let socialSecurity = SocialSecurityManager()
    private var managerCancellables = Set<AnyCancellable>()

    // User Profile (forwarding to ProfileManager)
    var birthDate: Date {
        get { profile.birthDate }
        set { profile.birthDate = newValue }
    }
    var currentYear: Int {
        get { profile.currentYear }
        set { profile.currentYear = newValue }
    }
    var planYear: Int {
        get { profile.planYear }
        set { profile.planYear = newValue }
    }
    var priorPlanYear: Int { profile.priorPlanYear }
    var filingStatus: FilingStatus {
        get { profile.filingStatus }
        set { profile.filingStatus = newValue }
    }
    var selectedState: USState {
        get { profile.selectedState }
        set { profile.selectedState = newValue }
    }
    var userName: String {
        get { profile.userName }
        set { profile.userName = newValue }
    }
    var spouseName: String {
        get { profile.spouseName }
        set { profile.spouseName = newValue }
    }
    var spouseBirthDate: Date {
        get { profile.spouseBirthDate }
        set { profile.spouseBirthDate = newValue }
    }
    var enableSpouse: Bool {
        get { profile.enableSpouse }
        set { profile.enableSpouse = newValue }
    }
    
    // IRA Accounts (forwarding to AccountsManager)
    var iraAccounts: [IRAAccount] {
        get { accounts.iraAccounts }
        set { accounts.iraAccounts = newValue }
    }
    
    // Income Sources (forwarding to IncomeDeductionsManager)
    var incomeSources: [IncomeSource] {
        get { incomeDeductions.incomeSources }
        set { incomeDeductions.incomeSources = newValue }
    }
    
    // Scenario State (forwarding to ScenarioStateManager)
    var quarterlyPayments: [QuarterlyPayment] {
        get { scenario.quarterlyPayments }
        set { scenario.quarterlyPayments = newValue }
    }
    var yourRothConversion: Double {
        get { scenario.yourRothConversion }
        set { scenario.yourRothConversion = newValue }
    }
    var spouseRothConversion: Double {
        get { scenario.spouseRothConversion }
        set { scenario.spouseRothConversion = newValue }
    }
    var yourExtraWithdrawal: Double {
        get { scenario.yourExtraWithdrawal }
        set { scenario.yourExtraWithdrawal = newValue }
    }
    var spouseExtraWithdrawal: Double {
        get { scenario.spouseExtraWithdrawal }
        set { scenario.spouseExtraWithdrawal = newValue }
    }
    var yourQCDAmount: Double {
        get { scenario.yourQCDAmount }
        set { scenario.yourQCDAmount = newValue }
    }
    var spouseQCDAmount: Double {
        get { scenario.spouseQCDAmount }
        set { scenario.spouseQCDAmount = newValue }
    }
    var yourWithdrawalQuarter: Int {
        get { scenario.yourWithdrawalQuarter }
        set { scenario.yourWithdrawalQuarter = newValue }
    }
    var spouseWithdrawalQuarter: Int {
        get { scenario.spouseWithdrawalQuarter }
        set { scenario.spouseWithdrawalQuarter = newValue }
    }
    var yourRothConversionQuarter: Int {
        get { scenario.yourRothConversionQuarter }
        set { scenario.yourRothConversionQuarter = newValue }
    }
    var spouseRothConversionQuarter: Int {
        get { scenario.spouseRothConversionQuarter }
        set { scenario.spouseRothConversionQuarter = newValue }
    }
    var stockDonationEnabled: Bool {
        get { scenario.stockDonationEnabled }
        set { scenario.stockDonationEnabled = newValue }
    }
    var stockPurchasePrice: Double {
        get { scenario.stockPurchasePrice }
        set { scenario.stockPurchasePrice = newValue }
    }
    var stockCurrentValue: Double {
        get { scenario.stockCurrentValue }
        set { scenario.stockCurrentValue = newValue }
    }
    var stockPurchaseDate: Date {
        get { scenario.stockPurchaseDate }
        set { scenario.stockPurchaseDate = newValue }
    }
    var cashDonationAmount: Double {
        get { scenario.cashDonationAmount }
        set { scenario.cashDonationAmount = newValue }
    }
    var inheritedExtraWithdrawals: [UUID: Double] {
        get { scenario.inheritedExtraWithdrawals }
        set { scenario.inheritedExtraWithdrawals = newValue }
    }
    var deductionOverride: DeductionChoice? {
        get { scenario.deductionOverride }
        set { scenario.deductionOverride = newValue }
    }
    var completedActionKeys: Set<String> {
        get { scenario.completedActionKeys }
        set { scenario.completedActionKeys = newValue }
    }

    // Growth Rates (forwarding to GrowthRatesManager)
    var primaryGrowthRate: Double {
        get { growthRates.primaryGrowthRate }
        set { growthRates.primaryGrowthRate = newValue }
    }
    var spouseGrowthRate: Double {
        get { growthRates.spouseGrowthRate }
        set { growthRates.spouseGrowthRate = newValue }
    }
    var taxableAccountGrowthRate: Double { growthRates.taxableAccountGrowthRate }

    // Legacy Planning (forwarding to LegacyPlanningManager)
    var enableLegacyPlanning: Bool {
        get { legacy.enableLegacyPlanning }
        set { legacy.enableLegacyPlanning = newValue }
    }
    var legacyHeirType: String {
        get { legacy.legacyHeirType }
        set { legacy.legacyHeirType = newValue }
    }
    var legacyHeirEstimatedSalary: Double {
        get { legacy.legacyHeirEstimatedSalary }
        set { legacy.legacyHeirEstimatedSalary = newValue }
    }
    var legacyHeirFilingStatus: FilingStatus {
        get { legacy.legacyHeirFilingStatus }
        set { legacy.legacyHeirFilingStatus = newValue }
    }
    var legacyHeirBirthYear: Int? {
        get { legacy.legacyHeirBirthYear }
        set { legacy.legacyHeirBirthYear = newValue }
    }
    var legacySpouseSurvivorYears: Int {
        get { legacy.legacySpouseSurvivorYears }
        set { legacy.legacySpouseSurvivorYears = newValue }
    }
    /// Growth rate used for legacy projections. Falls back to primaryGrowthRate if user hasn't overridden.
    var legacyGrowthRate: Double {
        get { legacy.legacyGrowthRate ?? primaryGrowthRate }
        set { legacy.legacyGrowthRate = newValue }
    }
    /// Whether the legacy growth rate has been independently set by the user.
    var hasCustomLegacyGrowthRate: Bool {
        legacy.legacyGrowthRate != nil
    }
    /// Resets legacy growth rate to follow the RMD tab's rate.
    func resetLegacyGrowthRate() {
        legacy.legacyGrowthRate = nil
    }

    // Prior Year State Tax (forwarding to IncomeDeductionsManager)
    var priorYearStateBalance: Double {
        get { incomeDeductions.priorYearStateBalance }
        set { incomeDeductions.priorYearStateBalance = newValue }
    }
    /// Prior year federal tax liability (Line 24, Form 1040). For 100%/110% safe harbor.
    var priorYearFederalTax: Double {
        get { incomeDeductions.priorYearFederalTax }
        set { incomeDeductions.priorYearFederalTax = newValue }
    }
    /// Prior year state tax liability (from state return). For state safe harbor.
    var priorYearStateTax: Double {
        get { incomeDeductions.priorYearStateTax }
        set { incomeDeductions.priorYearStateTax = newValue }
    }
    /// Combined prior year total tax for display purposes.
    var priorYearTotalTax: Double {
        priorYearFederalTax + priorYearStateTax
    }
    /// Prior year AGI (Line 11, Form 1040). Determines 100% vs 110% safe harbor rate.
    var priorYearAGI: Double {
        get { incomeDeductions.priorYearAGI }
        set { incomeDeductions.priorYearAGI = newValue }
    }
    /// User's chosen safe harbor method for estimated tax calculations.
    @Published var safeHarborMethod: SafeHarborMethod = .currentYear90

    // Social Security Planner (forwarding to SocialSecurityManager)
    var primarySSBenefit: SSBenefitEstimate? {
        get { socialSecurity.primarySSBenefit }
        set { socialSecurity.primarySSBenefit = newValue }
    }
    var spouseSSBenefit: SSBenefitEstimate? {
        get { socialSecurity.spouseSSBenefit }
        set { socialSecurity.spouseSSBenefit = newValue }
    }
    var primaryEarningsHistory: SSEarningsHistory? {
        get { socialSecurity.primaryEarningsHistory }
        set { socialSecurity.primaryEarningsHistory = newValue }
    }
    var spouseEarningsHistory: SSEarningsHistory? {
        get { socialSecurity.spouseEarningsHistory }
        set { socialSecurity.spouseEarningsHistory = newValue }
    }
    var ssWhatIfParams: SSWhatIfParameters {
        get { socialSecurity.ssWhatIfParams }
        set { socialSecurity.ssWhatIfParams = newValue }
    }
    var ssAutoSync: Bool {
        get { socialSecurity.ssAutoSync }
        set { socialSecurity.ssAutoSync = newValue }
    }

    // Itemized Deductions (forwarding to IncomeDeductionsManager)
    var deductionItems: [DeductionItem] {
        get { incomeDeductions.deductionItems }
        set { incomeDeductions.deductionItems = newValue }
    }

    // MARK: - Tax Bracket Models
    // MARK: - Tax Bracket Storage
    @Published var currentTaxBrackets: TaxBrackets
    
    // Tax constants delegated to TaxCalculationEngine
    static let default2026Brackets = TaxCalculationEngine.default2026Brackets
    static let irmaaStandardPartB = TaxCalculationEngine.irmaaStandardPartB
    static let irmaa2026Tiers = TaxCalculationEngine.irmaa2026Tiers
    static let niitRate = TaxCalculationEngine.niitRate
    static let niitThresholdSingle = TaxCalculationEngine.niitThresholdSingle
    static let niitThresholdMFJ = TaxCalculationEngine.niitThresholdMFJ
    static let niitQualifyingTypes = TaxCalculationEngine.niitQualifyingTypes
    static let amtExemptionSingle = TaxCalculationEngine.amtExemptionSingle
    static let amtExemptionMFJ = TaxCalculationEngine.amtExemptionMFJ
    static let amtPhaseoutThresholdSingle = TaxCalculationEngine.amtPhaseoutThresholdSingle
    static let amtPhaseoutThresholdMFJ = TaxCalculationEngine.amtPhaseoutThresholdMFJ
    static let amtPhaseoutRate = TaxCalculationEngine.amtPhaseoutRate
    static let amt26PercentLimit = TaxCalculationEngine.amt26PercentLimit
    static let amtRate26 = TaxCalculationEngine.amtRate26
    static let amtRate28 = TaxCalculationEngine.amtRate28

    // Computed Properties — derived from birthDate

    /// Extract birth year from birthDate for RMD age bracket calculation
    var birthYear: Int { profile.birthYear }
    var spouseBirthYear: Int { profile.spouseBirthYear }
    var currentAge: Int { profile.currentAge }
    var rmdAge: Int { profile.rmdAge }
    var yearsUntilRMD: Int { profile.yearsUntilRMD }
    var isRMDRequired: Bool { profile.isRMDRequired }
    var isQCDEligible: Bool { profile.isQCDEligible }
    var spouseCurrentAge: Int { profile.spouseCurrentAge }
    var spouseRmdAge: Int { profile.spouseRmdAge }
    var spouseYearsUntilRMD: Int { profile.spouseYearsUntilRMD }
    var spouseIsRMDRequired: Bool { profile.spouseIsRMDRequired }
    var spouseIsQCDEligible: Bool { profile.spouseIsQCDEligible }
    
    
    // Balance aggregations (forwarding to AccountsManager)
    var totalTraditionalIRABalance: Double { accounts.totalTraditionalIRABalance }
    var totalRothBalance: Double { accounts.totalRothBalance }
    var primaryTraditionalIRABalance: Double { accounts.primaryTraditionalIRABalance }
    var spouseTraditionalIRABalance: Double { accounts.spouseTraditionalIRABalance(enableSpouse: enableSpouse) }
    var primaryRothBalance: Double { accounts.primaryRothBalance }
    var spouseRothBalance: Double { accounts.spouseRothBalance(enableSpouse: enableSpouse) }
    var primaryInheritedTraditionalBalance: Double { accounts.primaryInheritedTraditionalBalance }
    var spouseInheritedTraditionalBalance: Double { accounts.spouseInheritedTraditionalBalance(enableSpouse: enableSpouse) }
    var primaryInheritedRothBalance: Double { accounts.primaryInheritedRothBalance }
    var spouseInheritedRothBalance: Double { accounts.spouseInheritedRothBalance(enableSpouse: enableSpouse) }
    var totalInheritedBalance: Double { accounts.totalInheritedBalance }
    var inheritedAccounts: [IRAAccount] { accounts.inheritedAccounts }
    var hasInheritedAccounts: Bool { accounts.hasInheritedAccounts }

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

    // MARK: - RMD Calculations (delegates to RMDCalculationEngine)

    func calculateRMD(for age: Int, balance: Double) -> Double {
        RMDCalculationEngine.calculateRMD(for: age, balance: balance)
    }

    func lifeExpectancyFactor(for age: Int) -> Double {
        RMDCalculationEngine.lifeExpectancyFactor(for: age)
    }

    func singleLifeExpectancyFactor(for age: Int) -> Double {
        RMDCalculationEngine.singleLifeExpectancyFactor(for: age)
    }

    func calculatePrimaryRMD() -> Double {
        guard isRMDRequired else { return 0 }
        return RMDCalculationEngine.calculateRMD(for: currentAge, balance: primaryTraditionalIRABalance)
    }

    func calculateSpouseRMD() -> Double {
        guard enableSpouse && spouseIsRMDRequired else { return 0 }
        return RMDCalculationEngine.calculateRMD(for: spouseCurrentAge, balance: spouseTraditionalIRABalance)
    }

    func calculateCombinedRMD() -> Double {
        calculatePrimaryRMD() + calculateSpouseRMD()
    }

    func calculateInheritedIRARMD(account: IRAAccount, forYear year: Int) -> InheritedRMDResult {
        RMDCalculationEngine.calculateInheritedIRARMD(account: account, forYear: year)
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
        TaxCalculationEngine.progressiveTax(income: income, brackets: brackets)
    }

    func calculateFederalTax(income: Double, filingStatus: FilingStatus = .single) -> Double {
        TaxCalculationEngine.calculateFederalTax(income: income, filingStatus: filingStatus, brackets: currentTaxBrackets, preferentialIncome: preferentialIncome())
    }

    // MARK: - Multi-State Tax Calculation

    /// The tax configuration for the user's selected state of residence.
    var selectedStateConfig: StateTaxConfig { profile.selectedStateConfig }

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
        TaxCalculationEngine.calculateStateTax(income: income, forState: state, filingStatus: filingStatus, taxableSocialSecurity: taxableSocialSecurity, incomeSources: incomeSources, currentAge: currentAge, enableSpouse: enableSpouse, spouseBirthYear: spouseBirthYear, currentYear: currentYear)
    }

    private func californiaExemptionCredits(filingStatus: FilingStatus, agi: Double) -> Double {
        TaxCalculationEngine.californiaExemptionCredits(filingStatus: filingStatus, agi: agi, currentAge: currentAge, enableSpouse: enableSpouse, spouseBirthYear: spouseBirthYear, currentYear: currentYear)
    }

    /// Calculates state tax starting from gross income (pre-deduction).
    /// Applies the state's own standard deduction, then retirement exemptions, then tax.
    /// Used by state comparison and scenarioStateTax to ensure correct state-specific deductions.
    func calculateStateTaxFromGross(grossIncome: Double, forState state: USState, filingStatus: FilingStatus, taxableSocialSecurity: Double) -> Double {
        let config = StateTaxData.config(for: state)

        // Determine state standard deduction
        let stateStandardDeduction: Double
        switch config.stateDeduction {
        case .none:
            stateStandardDeduction = 0
        case .conformsToFederal:
            stateStandardDeduction = standardDeductionAmount
        case .fixed(let single, let married):
            stateStandardDeduction = filingStatus == .single ? single : married
        }

        // If user is itemizing, compute state-specific itemized deductions.
        // State itemized removes SALT (can't deduct state tax on state return)
        // and uses full property tax without the federal $10K SALT cap.
        // Use the larger of state standard or state itemized.
        let stateDeduction: Double
        if scenarioEffectiveItemize {
            stateDeduction = max(stateStandardDeduction, stateItemizedDeductions)
        } else {
            stateDeduction = stateStandardDeduction
        }

        let stateTaxableIncome = max(0, grossIncome - stateDeduction)
        return calculateStateTax(income: stateTaxableIncome, forState: state, filingStatus: filingStatus, taxableSocialSecurity: taxableSocialSecurity)
    }

    /// Applies state-specific retirement income exemptions to reduce state taxable income.
    /// Different states exempt different combinations of Social Security, pensions, and IRA withdrawals.
    /// `taxableSocialSecurity` is the amount of SS actually included in the income figure
    /// (the federally-taxable portion: 0/50/85%), NOT the full SS benefit.
    private func applyRetirementExemptions(income: Double, config: StateTaxConfig, taxableSocialSecurity: Double) -> Double {
        TaxCalculationEngine.applyRetirementExemptions(income: income, config: config, taxableSocialSecurity: taxableSocialSecurity, incomeSources: incomeSources)
    }

    /// Returns a detailed breakdown of how state tax is calculated for a specific state.
    /// Mirrors the logic of `calculateStateTaxFromGross` but captures
    /// every intermediate value for the State Comparison detail sheet.
    func stateTaxBreakdown(forState state: USState, filingStatus: FilingStatus) -> StateTaxBreakdown {
        let grossIncome = scenarioGrossIncome
        let config = StateTaxData.config(for: state)
        let exemptions = config.retirementExemptions

        // 0. Apply state-specific deduction (itemized or standard, whichever is larger)
        let stateStandardDeduction: Double
        switch config.stateDeduction {
        case .none:
            stateStandardDeduction = 0
        case .conformsToFederal:
            stateStandardDeduction = standardDeductionAmount
        case .fixed(let single, let married):
            stateStandardDeduction = filingStatus == .single ? single : married
        }
        let stateDeduction: Double
        if scenarioEffectiveItemize {
            stateDeduction = max(stateStandardDeduction, stateItemizedDeductions)
        } else {
            stateDeduction = stateStandardDeduction
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

        // Apply state personal exemption credits (e.g., California $144/exemption)
        if state == .california {
            totalTax -= californiaExemptionCredits(filingStatus: filingStatus, agi: adjustedIncome)
            totalTax = max(0, totalTax)
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
        incomeDeductions.totalAnnualIncome()
    }

    // MARK: - IRMAA Calculations

    /// Determines the IRMAA tier and annual surcharge for a given MAGI and filing status.
    /// CRITICAL: IRMAA is cliff-based — the ENTIRE surcharge applies once a threshold is crossed.
    /// This is NOT progressive like tax brackets. Do NOT use progressiveTax() here.
    func calculateIRMAA(magi: Double, filingStatus: FilingStatus) -> IRMAAResult {
        TaxCalculationEngine.calculateIRMAA(magi: magi, filingStatus: filingStatus)
    }

    // MARK: - NIIT Calculations (IRC §1411)

    /// Calculates the Net Investment Income Tax for a given NII, MAGI, and filing status.
    /// NIIT = 3.8% × min(NII, max(0, MAGI − threshold))
    ///
    /// Key nuance: Roth conversions and IRA withdrawals are NOT NII themselves, but they
    /// increase MAGI, which can cause existing investment income to become subject to NIIT.
    func calculateNIIT(nii: Double, magi: Double, filingStatus: FilingStatus) -> NIITResult {
        TaxCalculationEngine.calculateNIIT(nii: nii, magi: magi, filingStatus: filingStatus)
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
        TaxCalculationEngine.calculateAMT(taxableIncome: taxableIncome, regularTax: regularTax, filingStatus: filingStatus, scenarioEffectiveItemize: scenarioEffectiveItemize, saltAfterCap: saltAfterCap, deductibleMedicalExpenses: deductibleMedicalExpenses, preferentialIncome: preferentialIncome(), brackets: currentTaxBrackets)
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
        return TaxCalculationEngine.bracketInfo(income: income, brackets: brackets)
    }

    func stateBracketInfo(income: Double, filingStatus: FilingStatus) -> BracketInfo {
        let config = selectedStateConfig
        switch config.taxSystem {
        case .noIncomeTax, .specialLimited:
            return BracketInfo(currentRate: 0, currentThreshold: 0, nextThreshold: .infinity, roomRemaining: 0)
        case .flat(let rate):
            return BracketInfo(currentRate: rate, currentThreshold: 0, nextThreshold: .infinity, roomRemaining: 0)
        case .progressive(let single, let married):
            let brackets = filingStatus == .single ? single : married
            return TaxCalculationEngine.bracketInfo(income: income, brackets: brackets)
        }
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

        // Forward child manager objectWillChange to DataManager
        profile.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &managerCancellables)
        accounts.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &managerCancellables)
        incomeDeductions.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &managerCancellables)
        scenario.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &managerCancellables)
        growthRates.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &managerCancellables)
        legacy.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &managerCancellables)
        socialSecurity.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &managerCancellables)

        // Re-sync SS income sources when birth dates change (affects age-gating, FRA, spousal top-up).
        // Uses receive(on:) to defer to next run loop — @Published fires on willSet, so the new
        // value isn't yet stored when the sink fires. Deferring ensures syncSSToIncomeSources()
        // reads the updated birthDate.
        profile.$birthDate
            .dropFirst() // Skip initial value during init
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncSSToIncomeSources() }
            .store(in: &managerCancellables)
        profile.$spouseBirthDate
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncSSToIncomeSources() }
            .store(in: &managerCancellables)
        profile.$enableSpouse
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncSSToIncomeSources() }
            .store(in: &managerCancellables)

        guard !skipPersistence else { return }
        PersistenceManager.loadAll(into: self)

        // Re-sync SS income sources on startup so spousal top-up and age gating are current
        syncSSToIncomeSources()
    }

    func saveTaxBrackets() {
        #if DEBUG
        PersistenceManager.saveTaxBrackets(currentTaxBrackets, defaults: DemoProfile.defaults)
        #else
        PersistenceManager.saveTaxBrackets(currentTaxBrackets)
        #endif
    }

    func saveAllData() {
        #if DEBUG
        PersistenceManager.saveAll(from: self, defaults: DemoProfile.defaults)
        #else
        PersistenceManager.saveAll(from: self)
        #endif
    }

    /// Resets all scenario properties to defaults.
    func resetScenario() {
        scenario.resetScenarioState()
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
        TaxCalculationEngine.calculateTaxableSocialSecurity(filingStatus: filingStatus, additionalIncome: additionalIncome, incomeSources: incomeSources)
    }
    
    // MARK: - Income Separation (Ordinary vs Preferential)

    /// Long-term capital gains + qualified dividends (taxed at preferential federal rates)
    func preferentialIncome() -> Double {
        incomeSources
            .filter { $0.type == .capitalGainsLong || $0.type == .qualifiedDividends }
            .reduce(0) { $0 + $1.annualAmount }
    }

    /// Tax-exempt interest (muni bonds, tax-free money markets).
    /// Not federally taxable, but included in IRMAA MAGI and SS combined income test.
    var taxExemptInterestTotal: Double {
        incomeSources
            .filter { $0.type == .taxExemptInterest }
            .reduce(0) { $0 + $1.annualAmount }
    }

    /// Ordinary taxable income (excludes long-term cap gains, qualified dividends, and tax-exempt interest)
    func ordinaryTaxableIncome(filingStatus: FilingStatus = .single) -> Double {
        let otherIncome = incomeSources
            .filter { $0.type != .socialSecurity && $0.type != .capitalGainsLong && $0.type != .qualifiedDividends && $0.type != .taxExemptInterest }
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

    /// Annual QCD limit per person, loaded from tax year config JSON.
    var qcdAnnualLimit: Double {
        TaxCalculationEngine.config.qcdAnnualLimit
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
    var totalFederalWithholding: Double { incomeDeductions.totalFederalWithholding }
    var totalStateWithholding: Double { incomeDeductions.totalStateWithholding }
    var totalWithholding: Double { incomeDeductions.totalWithholding }

    /// Taxable portion of Social Security with scenario income included in combined income test.
    /// Per IRS rules, Roth conversions and IRA withdrawals affect the SS taxation thresholds.
    var scenarioTaxableSocialSecurity: Double {
        let scenarioExtra = scenarioTotalRothConversion + scenarioTotalWithdrawals
        return calculateTaxableSocialSecurity(filingStatus: filingStatus, additionalIncome: scenarioExtra)
    }

    var scenarioOrdinaryIncomeSubtotal: Double { incomeDeductions.ordinaryIncomeSubtotal }
    var totalSocialSecurityBenefits: Double { incomeDeductions.totalSocialSecurityBenefits }

    /// What percentage of Social Security is taxable (0%, 50%, or 85% in practice).
    var socialSecurityTaxablePercent: Int {
        guard totalSocialSecurityBenefits > 0 else { return 0 }
        return Int(round(scenarioTaxableSocialSecurity / totalSocialSecurityBenefits * 100))
    }

    var qualifiedDividendsTotal: Double { incomeDeductions.qualifiedDividendsTotal }
    var longTermCapGainsTotal: Double { incomeDeductions.longTermCapGainsTotal }

    /// Base income before any scenario decisions (pre-deduction).
    /// Uses scenario-aware SS taxation that includes Roth conversions and withdrawals
    /// in the IRS combined income test for determining how much SS is taxable.
    var scenarioBaseIncome: Double {
        scenarioOrdinaryIncomeSubtotal + scenarioTaxableSocialSecurity + preferentialIncome()
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
        let cfg = TaxCalculationEngine.config
        let year = currentYear
        var amount: Double

        switch filingStatus {
        case .single:
            amount = cfg.standardDeductionSingle
            if currentAge >= 65 {
                amount += cfg.additionalDeduction65Single
            }
            // OBBBA Senior Bonus
            if currentAge >= 65 && year >= cfg.seniorBonusFirstYear && year <= cfg.seniorBonusLastYear {
                let magi = scenarioGrossIncome
                let reduction = max(0, (magi - cfg.seniorBonusPhaseoutSingle) * cfg.seniorBonusPhaseoutRate)
                let bonus = max(0, cfg.seniorBonusPerPerson - reduction)
                amount += bonus
            }
        case .marriedFilingJointly:
            amount = cfg.standardDeductionMFJ
            if currentAge >= 65 { amount += cfg.additionalDeduction65MFJ }
            if enableSpouse && spouseCurrentAge >= 65 { amount += cfg.additionalDeduction65MFJ }
            // OBBBA Senior Bonus per qualifying person 65+
            if year >= cfg.seniorBonusFirstYear && year <= cfg.seniorBonusLastYear {
                let magi = scenarioGrossIncome
                var qualifyingSeniors = 0
                if currentAge >= 65 { qualifyingSeniors += 1 }
                if enableSpouse && spouseCurrentAge >= 65 { qualifyingSeniors += 1 }
                if qualifyingSeniors > 0 {
                    let totalBonusBase = cfg.seniorBonusPerPerson * Double(qualifyingSeniors)
                    let reduction = max(0, (magi - cfg.seniorBonusPhaseoutMFJ) * cfg.seniorBonusPhaseoutRate)
                    let bonus = max(0, totalBonusBase - reduction)
                    amount += bonus
                }
            }
        }
        return amount
    }

    var totalMedicalExpenses: Double { incomeDeductions.totalMedicalExpenses }

    /// Estimated AGI used for the medical deduction floor. For retirees this is
    /// effectively gross income (pensions, taxable SS, dividends, cap gains, Roth
    /// conversions, withdrawals). True AGI would subtract any above-the-line
    /// deductions (IRA contributions, HSA, etc.) which are typically zero in retirement.
    var estimatedAGI: Double {
        scenarioGrossIncome
    }

    /// The 7.5% AGI floor for medical deductions.
    var medicalAGIFloor: Double {
        estimatedAGI * TaxCalculationEngine.config.medicalAGIFloorRate
    }

    /// Deductible medical expenses (only the portion exceeding 7.5% of AGI).
    var deductibleMedicalExpenses: Double {
        max(0, totalMedicalExpenses - medicalAGIFloor)
    }

    var propertyTaxAmount: Double { incomeDeductions.propertyTaxAmount }
    var additionalSALTAmount: Double { incomeDeductions.additionalSALTAmount }
    var priorYearSALTDeductible: Double { incomeDeductions.priorYearSALTDeductible }

    /// Raw total of SALT-eligible amounts before the federal cap.
    /// Auto-includes: property tax, state withholding from income sources,
    /// prior year state balance due (if positive), manual SALT entries,
    /// and estimated state tax payments for the current year.
    ///
    /// Note on estimated state payments: These are auto-calculated from the
    /// scenario's state tax liability. There is no circularity because state
    /// tax is computed on state taxable income (which excludes SALT — you can't
    /// deduct state tax on your state return). The state payment amount is
    /// stable regardless of whether it's included in federal SALT.
    var totalSALTBeforeCap: Double {
        propertyTaxAmount + totalStateWithholding + priorYearSALTDeductible + additionalSALTAmount + autoEstimatedStatePayments
    }

    /// Estimated state tax payments auto-included in SALT.
    /// This value updates reactively as the user fills in income, accounts, and scenarios.
    /// Returns 0 for no-income-tax states or when there is no state tax liability.
    ///
    /// Uses a self-contained state tax calculation that applies state-specific deductions
    /// and retirement exemptions but does NOT reference any federal SALT or itemized
    /// deduction properties (avoiding the circular dependency chain:
    /// autoEstimatedStatePayments → totalSALTBeforeCap → totalItemizedDeductions →
    /// scenarioEffectiveItemize → calculateStateTaxFromGross → autoEstimatedStatePayments).
    ///
    /// The state deduction used here is always the state standard deduction (not itemized),
    /// which is a conservative choice — if the user itemizes on the state return, their
    /// actual state tax may be slightly lower, making this a mild overestimate. This is
    /// acceptable for SALT planning purposes and avoids any dependency on federal deductions.
    var autoEstimatedStatePayments: Double {
        guard stateHasIncomeTax else { return 0 }
        let config = selectedStateConfig
        let grossIncome = scenarioGrossIncome

        // Apply state standard deduction (independent of federal SALT/itemized chain)
        let stateStdDeduction: Double
        switch config.stateDeduction {
        case .none:
            stateStdDeduction = 0
        case .conformsToFederal:
            stateStdDeduction = standardDeductionAmount
        case .fixed(let single, let married):
            stateStdDeduction = filingStatus == .single ? single : married
        }

        let stateTaxableIncome = max(0, grossIncome - stateStdDeduction)
        // Apply retirement exemptions and compute state tax
        let stateTax = calculateStateTax(income: stateTaxableIncome, filingStatus: filingStatus)
        return max(0, stateTax - totalStateWithholding)
    }

    /// SALT cap based on tax year and filing status (OBBBA, signed July 4, 2025).
    /// - 2018–2024: $10,000 per TCJA
    /// - 2025–2029: $40,000 base with 1% annual inflation, but phased out by
    ///   30% of MAGI exceeding $500,000 (MFJ, +1%/year). Floor of $10,000.
    /// - 2030+: Reverts permanently to $10,000
    var saltCap: Double {
        let cfg = TaxCalculationEngine.config
        let year = currentYear
        if year >= cfg.saltExpandedFirstYear && year <= cfg.saltExpandedLastYear {
            let yearsFromBase = Double(year - cfg.saltBaseYear)
            let inflationMultiplier = pow(1.0 + cfg.saltInflationRate, yearsFromBase)
            let expandedCap = (cfg.saltBaseCap * inflationMultiplier).rounded()

            let phaseoutThreshold = (cfg.saltPhaseoutBaseThreshold * inflationMultiplier).rounded()
            let magi = scenarioGrossIncome
            let phaseoutReduction = max(0, (magi.rounded() - phaseoutThreshold) * cfg.saltPhaseoutRate)
            let afterPhaseout = expandedCap - phaseoutReduction

            return max(cfg.saltFloor, afterPhaseout)
        } else {
            return cfg.saltDefaultCap
        }
    }

    /// SALT deduction after applying the federal cap.
    var saltAfterCap: Double {
        min(totalSALTBeforeCap, saltCap)
    }

    /// Informational: the estimated state tax payments amount that has been
    /// auto-included in the SALT calculation. Used for display in UI and PDF.
    var estimatedStateSALTReminder: Double {
        autoEstimatedStatePayments
    }

    /// Whether the selected state has an income tax (for gating SALT reminders).
    var stateHasIncomeTax: Bool {
        selectedStateConfig.taxSystem.hasIncomeTax
    }

    // MARK: - Safe Harbor

    /// AGI threshold above which the 110% (not 100%) prior-year safe harbor applies.
    /// $150,000 for all filing statuses in this app (Single and MFJ).
    private var safeHarbor110Threshold: Double { 150_000 }

    /// Federal prior-year safe harbor rate: 1.10 if prior AGI > $150k, else 1.00.
    var priorYearFederalSafeHarborRate: Double {
        priorYearAGI > safeHarbor110Threshold ? 1.10 : 1.00
    }

    /// State prior-year safe harbor rate, evaluated from the state's rule.
    /// Returns nil if prior-year safe harbor is unavailable (e.g., CA $1M disqualification).
    var priorYearStateSafeHarborResult: Double? {
        selectedStateConfig.safeHarborRule.priorYearRate(
            priorAGI: priorYearAGI,
            currentAGI: scenarioGrossIncome
        )
    }

    /// State prior-year safe harbor rate for display. Returns the rate or 0 if disqualified.
    var priorYearStateSafeHarborRate: Double {
        priorYearStateSafeHarborResult ?? 0
    }

    /// For display: the federal rate (the one that most commonly varies).
    var priorYearSafeHarborRate: Double {
        priorYearFederalSafeHarborRate
    }

    /// Whether the user is disqualified from the prior-year state safe harbor
    /// (e.g., CA AGI ≥ $1M). When true, state payments must use the current-year method.
    var isStateDisqualifiedFromPriorYear: Bool {
        priorYearStateSafeHarborResult == nil
    }

    /// Total annual payment required under the prior-year safe harbor method.
    var priorYearSafeHarborAmount: Double {
        priorYearFederalSafeHarbor + priorYearStateSafeHarbor
    }

    /// Federal portion of the prior-year safe harbor amount.
    var priorYearFederalSafeHarbor: Double {
        priorYearFederalTax * priorYearFederalSafeHarborRate
    }

    /// State portion of the prior-year safe harbor amount.
    /// Returns 0 if the state disqualifies the prior-year method (CA $1M rule).
    var priorYearStateSafeHarbor: Double {
        guard let rate = priorYearStateSafeHarborResult else { return 0 }
        return priorYearStateTax * rate
    }

    /// Current-year safe harbor rate for the state (0.90 for most, 0.80/0.70/0.60 for some).
    var stateCurrentYearSafeHarborRate: Double {
        selectedStateConfig.currentYearSafeHarborRate
    }

    /// Total annual payment required under the current-year safe harbor method.
    /// Uses 90% for federal and the state's specific rate (which may differ).
    var currentYearSafeHarborAmount: Double {
        let fedTax = scenarioFederalTax + scenarioNIITAmount + scenarioAMTAmount
        return fedTax * 0.90 + scenarioStateTax * stateCurrentYearSafeHarborRate
    }

    // MARK: - Form 2210

    /// Whether the user's scenario requires filing IRS Form 2210, Schedule AI
    /// (annualized income installment method) due to uneven quarterly income allocation.
    var requiresForm2210ScheduleAI: Bool {
        guard hasActiveScenario else { return false }
        let hasUnevenConversion = (yourRothConversion > 0 && yourRothConversionQuarter > 1) ||
            (enableSpouse && spouseRothConversion > 0 && spouseRothConversionQuarter > 1)
        let hasUnevenWithdrawal = (yourExtraWithdrawal > 0 && yourWithdrawalQuarter > 1) ||
            (enableSpouse && spouseExtraWithdrawal > 0 && spouseWithdrawalQuarter > 1)
        // RMDs taken in Q2-Q4 also create uneven quarterly income
        let hasUnevenRMD = (calculatePrimaryRMD() > 0 && yourWithdrawalQuarter > 1) ||
            (enableSpouse && calculateSpouseRMD() > 0 && spouseWithdrawalQuarter > 1)
        return hasUnevenConversion || hasUnevenWithdrawal || hasUnevenRMD
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

    /// State-specific itemized deductions: removes SALT (can't deduct state tax on state return),
    /// but adds back full property tax without the federal $10K SALT cap.
    /// Used when user itemizes to compute state taxable income more accurately.
    var stateItemizedDeductions: Double {
        // Non-SALT, non-property-tax, non-medical deductions (mortgage interest, other, charitable)
        let nonSALTNonMedical = deductionItems
            .filter { $0.type != .propertyTax && $0.type != .saltTax && $0.type != .medicalExpenses }
            .reduce(0) { $0 + $1.annualAmount }

        // Full property tax (no cap at state level)
        let fullPropertyTax = propertyTaxAmount

        // Medical expenses (same AGI floor as federal)
        let medical = deductibleMedicalExpenses

        // Charitable from scenarios (stock + cash donations)
        let charitable = scenarioCharitableDeductions

        // No state/local tax deduction — you can't deduct state taxes on your own state return.
        // Prior year state balance and state withholding are excluded.
        return nonSALTNonMedical + fullPropertyTax + medical + charitable
    }

    /// Taxable income after scenario decisions and deductions
    var scenarioTaxableIncome: Double {
        let income = scenarioGrossIncome - effectiveDeductionAmount
        return max(0, income)
    }

    var scenarioFederalTax: Double {
        calculateFederalTax(income: scenarioTaxableIncome, filingStatus: filingStatus)
    }

    var scenarioFederalTaxBreakdown: FederalTaxBreakdown {
        TaxCalculationEngine.federalTaxBreakdown(
            income: scenarioTaxableIncome,
            filingStatus: filingStatus,
            brackets: currentTaxBrackets,
            preferentialIncome: preferentialIncome()
        )
    }

    var scenarioStateTaxBreakdown: StateTaxBreakdown {
        stateTaxBreakdown(forState: selectedState, filingStatus: filingStatus)
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

    // MARK: - Above-the-Line Deductions (1.9)

    /// Sum of all 1.9 contribution levers that reduce federal AGI.
    /// Phase 2 wires these to `ScenarioStateManager`; for Task 1.3 the placeholder is 0.
    var totalAboveTheLineDeductions: Double {
        // Filled in by Phase 2 — Task 2.6 replaces this body with the live sum.
        0
    }

    // MARK: - Strongly-Typed AGI Variants (1.9)

    /// Federal AGI: scenarioGrossIncome minus above-the-line deductions.
    var federalAGI: FederalAGI {
        FederalAGI(value: scenarioGrossIncome - totalAboveTheLineDeductions)
    }

    /// MAGI for ACA Marketplace subsidy: FederalAGI + tax-exempt interest + non-taxable SS.
    var acaMAGI: ACAMAGI {
        let nonTaxableSS = max(0, totalSocialSecurityBenefits - scenarioTaxableSocialSecurity)
        return ACAMAGI(value: federalAGI.value + taxExemptInterestTotal + nonTaxableSS)
    }

    /// MAGI for Medicare IRMAA: FederalAGI + tax-exempt interest. Replaces the
    /// untyped `irmaaMagi` over Task 1.4. Kept side-by-side for migration.
    var irmaaMAGIWrapped: IRMAAMAGI {
        IRMAAMAGI(value: federalAGI.value + taxExemptInterestTotal)
    }

    // MARK: - Scenario Warnings (1.9 — engine in Phase 5)

    /// Cross-feature scenario warnings. Replaced by `ScenarioWarningEngine.warningsFor(...)`
    /// in Phase 5; returns empty here so dashboard / inline-warning UI can be wired before then.
    var activeScenarioWarnings: [ScenarioWarning] {
        []
    }

    /// IRMAA MAGI = AGI + tax-exempt interest (muni bonds, tax-free money markets).
    /// Tax-exempt interest is not in AGI but the IRS includes it for IRMAA.
    var irmaaMagi: Double {
        estimatedAGI + taxExemptInterestTotal
    }

    /// Current scenario IRMAA result based on IRMAA MAGI (AGI + tax-exempt interest).
    var scenarioIRMAA: IRMAAResult {
        TaxCalculationEngine.calculateIRMAA(magi: irmaaMAGIWrapped, filingStatus: filingStatus)
    }

    /// Total household annual IRMAA surcharge (per-person × number of Medicare members).
    var scenarioIRMAATotalSurcharge: Double {
        scenarioIRMAA.annualSurchargePerPerson * Double(medicareMemberCount)
    }

    /// Baseline IRMAA (without any scenario decisions) for comparison.
    /// Includes tax-exempt interest in MAGI since IRS counts it for IRMAA.
    var baselineIRMAA: IRMAAResult {
        let baselineMAGI = IRMAAMAGI(value: scenarioBaseIncome + taxExemptInterestTotal)
        return TaxCalculationEngine.calculateIRMAA(magi: baselineMAGI, filingStatus: filingStatus)
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
    /// Supports two safe harbor methods:
    /// - `.currentYear90`: current-year safe harbor (90% federal, state-specific rate for state)
    /// - `.priorYear100_110`: prior-year safe harbor with state-specific rates and rules
    /// State payments use the state's required schedule (e.g. CA: 30/40/0/30).
    /// If the state disqualifies the prior-year method (CA $1M rule), the state portion
    /// automatically falls back to the current-year method.
    var scenarioQuarterlyPayments: FederalStateQuarterlyBreakdown {
        let stateSchedule = selectedStateConfig.estimatedPaymentSchedule
        let stateSHRate = stateCurrentYearSafeHarborRate

        // Total federal and state tax (including scenario decisions)
        let totalFederal = scenarioFederalTax + scenarioNIITAmount + scenarioAMTAmount
        let totalState = scenarioStateTax

        var fedPayments = QuarterlyBreakdown()
        var statePayments = QuarterlyBreakdown()

        // Determine if state must use current-year method (disqualification or user chose current-year)
        let useCurrentYearForState = safeHarborMethod == .currentYear90 || isStateDisqualifiedFromPriorYear

        switch safeHarborMethod {
        case .priorYear100_110:
            // Federal: prior-year safe harbor, equal quarters
            let fedAnnual = priorYearFederalSafeHarbor
            for q in 1...4 {
                fedPayments[q] = fedAnnual * 0.25
            }

            if useCurrentYearForState {
                // State disqualified from prior-year — use current-year method for state only
                statePayments = currentYearStatePayments(
                    totalState: totalState, totalFederal: totalFederal,
                    stateSHRate: stateSHRate, stateSchedule: stateSchedule
                )
            } else {
                // State uses prior-year safe harbor
                let stateAnnual = priorYearStateSafeHarbor
                for q in 1...4 {
                    statePayments[q] = stateAnnual * stateSchedule[q]
                }
            }

        case .currentYear90:
            // Both federal and state use current-year method
            let result = currentYearPayments(
                totalFederal: totalFederal, totalState: totalState,
                stateSHRate: stateSHRate, stateSchedule: stateSchedule
            )
            fedPayments = result.federal
            statePayments = result.state
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

    /// Current-year method for both federal and state portions.
    private func currentYearPayments(
        totalFederal: Double, totalState: Double,
        stateSHRate: Double, stateSchedule: EstimatedPaymentSchedule
    ) -> FederalStateQuarterlyBreakdown {
        let baseTaxable = max(0, scenarioBaseIncome - effectiveDeductionAmount)
        let baseFederalTax = calculateFederalTax(income: baseTaxable, filingStatus: filingStatus)
        let baseStateTax = calculateStateTax(income: baseTaxable, filingStatus: filingStatus)

        let incrementalFederal = max(0, totalFederal - baseFederalTax)
        let incrementalState = max(0, totalState - baseStateTax)

        let baseFedSH = max(0, baseFederalTax * 0.90)
        let baseStateSH = max(0, baseStateTax * stateSHRate)
        var fedPayments = QuarterlyBreakdown()
        var statePayments = QuarterlyBreakdown()
        for q in 1...4 {
            fedPayments[q] = baseFedSH * 0.25
            statePayments[q] = baseStateSH * stateSchedule[q]
        }

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

        if qIncome.total > 0 {
            let incFedSH = incrementalFederal * 0.90
            let incStateSH = incrementalState * stateSHRate
            for q in 1...4 {
                let share = qIncome[q] / qIncome.total
                fedPayments[q] += incFedSH * share
                statePayments[q] += incStateSH * share
            }
        }

        return FederalStateQuarterlyBreakdown(federal: fedPayments, state: statePayments)
    }

    /// Current-year method for state portion only (used when state is disqualified from prior-year).
    private func currentYearStatePayments(
        totalState: Double, totalFederal: Double,
        stateSHRate: Double, stateSchedule: EstimatedPaymentSchedule
    ) -> QuarterlyBreakdown {
        let result = currentYearPayments(
            totalFederal: totalFederal, totalState: totalState,
            stateSHRate: stateSHRate, stateSchedule: stateSchedule
        )
        return result.state
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
    /// Mirrors the `scenarioTotalTax` pipeline exactly — uses `calculateStateTaxFromGross`
    /// (not `calculateStateTax`) so the SS-exemption logic matches. Callers must supply
    /// the hypothetical `taxableSocialSecurity` that reflects their scenario (varying
    /// SS-affecting inputs like Roth conversion or withdrawals changes the SS combined-income
    /// test and therefore the taxable-SS amount).
    private func totalTaxFor(
        grossIncome: Double,
        taxableSocialSecurity: Double,
        deduction: Double,
        nii: Double? = nil
    ) -> Double {
        let taxable = max(0, grossIncome - deduction)
        let fed = calculateFederalTax(income: taxable, filingStatus: filingStatus)
        let state = calculateStateTaxFromGross(
            grossIncome: grossIncome,
            forState: selectedState,
            filingStatus: filingStatus,
            taxableSocialSecurity: taxableSocialSecurity
        )
        let niit = calculateNIIT(nii: nii ?? scenarioNetInvestmentIncome, magi: grossIncome, filingStatus: filingStatus).annualNIITax
        let amt = calculateAMT(taxableIncome: taxable, regularTax: fed, filingStatus: filingStatus).amt
        return fed + state + niit + amt
    }

    /// Tax impact of Roth conversions alone. Removes conversions from the scenario
    /// (rebuilding gross income with the recomputed SS-combined-income) and measures
    /// the tax difference.
    var rothConversionTaxImpact: Double {
        guard scenarioTotalRothConversion > 0 else { return 0 }
        // Taxable SS with the Roth conversion removed from the combined-income test.
        let ssWithoutConv = calculateTaxableSocialSecurity(
            filingStatus: filingStatus,
            additionalIncome: scenarioTotalWithdrawals
        )
        let baseWithoutConv = scenarioOrdinaryIncomeSubtotal + ssWithoutConv + preferentialIncome()
        let grossWithoutConv = baseWithoutConv + scenarioTotalWithdrawals - scenarioStockGainAvoided
        let withoutConversions = totalTaxFor(
            grossIncome: grossWithoutConv,
            taxableSocialSecurity: ssWithoutConv,
            deduction: effectiveDeductionAmount
        )
        return scenarioTotalTax - withoutConversions
    }

    /// Tax impact of extra withdrawals alone (RMDs kept; only the discretionary portion removed).
    var extraWithdrawalTaxImpact: Double {
        guard scenarioTotalExtraWithdrawal > 0 else { return 0 }
        let rmdsOnly = scenarioTotalWithdrawals - scenarioTotalExtraWithdrawal
        let ssWithout = calculateTaxableSocialSecurity(
            filingStatus: filingStatus,
            additionalIncome: scenarioTotalRothConversion + rmdsOnly
        )
        let baseWithout = scenarioOrdinaryIncomeSubtotal + ssWithout + preferentialIncome()
        let grossWithout = baseWithout + scenarioTotalRothConversion + rmdsOnly - scenarioStockGainAvoided
        let withoutWithdrawals = totalTaxFor(
            grossIncome: grossWithout,
            taxableSocialSecurity: ssWithout,
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
        // Hypothetical "without QCD": the QCD-offset portion of RMD becomes taxable again.
        // Both SS combined-income and gross income grow by taxableQCDOffset.
        let ssWithoutQCD = calculateTaxableSocialSecurity(
            filingStatus: filingStatus,
            additionalIncome: scenarioTotalRothConversion + scenarioTotalWithdrawals + taxableQCDOffset
        )
        let baseWithoutQCD = scenarioOrdinaryIncomeSubtotal + ssWithoutQCD + preferentialIncome()
        let grossWithoutQCD = baseWithoutQCD + scenarioTotalRothConversion + scenarioTotalWithdrawals + taxableQCDOffset - scenarioStockGainAvoided
        let withoutQCD = totalTaxFor(
            grossIncome: grossWithoutQCD,
            taxableSocialSecurity: ssWithoutQCD,
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

    /// Tax impact of inherited IRA extra withdrawals (Traditional only — Roth is tax-free).
    /// Inherited extras are part of `scenarioTotalWithdrawals`; removing them requires
    /// recomputing the SS combined-income test.
    var inheritedExtraWithdrawalTaxImpact: Double {
        guard inheritedTraditionalExtraTotal > 0 else { return 0 }
        let ssWithout = calculateTaxableSocialSecurity(
            filingStatus: filingStatus,
            additionalIncome: scenarioTotalRothConversion + scenarioTotalWithdrawals - inheritedTraditionalExtraTotal
        )
        let baseWithout = scenarioOrdinaryIncomeSubtotal + ssWithout + preferentialIncome()
        let grossWithout = baseWithout + scenarioTotalRothConversion + scenarioTotalWithdrawals - inheritedTraditionalExtraTotal - scenarioStockGainAvoided
        let withoutInherited = totalTaxFor(
            grossIncome: grossWithout,
            taxableSocialSecurity: ssWithout,
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

    /// Annual IRMAA surcharge increase caused by tax-exempt interest being included in IRMAA MAGI.
    /// Shows users how their "tax-free" muni/money market income affects Medicare premiums.
    var taxExemptInterestIRMAAImpact: Double {
        guard taxExemptInterestTotal > 0, medicareMemberCount > 0 else { return 0 }
        let magiWithout = irmaaMagi - taxExemptInterestTotal
        let irmaaWithout = calculateIRMAA(magi: magiWithout, filingStatus: filingStatus)
        let delta = scenarioIRMAA.annualSurchargePerPerson - irmaaWithout.annualSurchargePerPerson
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
    /// Only the deduction changes; gross income and SS combined-income are unchanged.
    var stockDeductionTaxSavings: Double {
        guard stockDonationEnabled, stockCurrentValue > 0, scenarioEffectiveItemize else { return 0 }
        let stockDeduction = scenarioStockIsLongTerm ? stockCurrentValue : stockPurchasePrice
        let charWithout = scenarioCharitableDeductions - stockDeduction
        let deductionWithout = baseItemizedDeductions + charWithout
        let effectiveDeductionWithout = max(deductionWithout, standardDeductionAmount)
        let withoutDeduction = totalTaxFor(
            grossIncome: scenarioGrossIncome,
            taxableSocialSecurity: scenarioTaxableSocialSecurity,
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
        // Hypothetical "gain realized": capital gain enters SS combined-income too.
        let ssWithGain = calculateTaxableSocialSecurity(
            filingStatus: filingStatus,
            additionalIncome: scenarioTotalRothConversion + scenarioTotalWithdrawals + scenarioStockGainAvoided
        )
        let baseWithGain = scenarioOrdinaryIncomeSubtotal + ssWithGain + preferentialIncome() + scenarioStockGainAvoided
        let grossWithGain = baseWithGain + scenarioTotalRothConversion + scenarioTotalWithdrawals
        // (stockGainAvoided is added via the preferential-income bump above since it would be LTCG
        //  when realized as long-term; short-term gain would land in ordinary — but since this is
        //  a comparison against a donation-enabled scenario, the delta is what matters.)
        let withGainRealized = totalTaxFor(
            grossIncome: grossWithGain,
            taxableSocialSecurity: ssWithGain,
            deduction: effectiveDeductionAmount,
            nii: scenarioNetInvestmentIncome + scenarioStockGainAvoided
        )
        return withGainRealized - scenarioTotalTax
    }

    /// Total tax savings from stock donation (deduction + avoided cap gains)
    var stockDonationTaxSavings: Double {
        stockDeductionTaxSavings + stockCapGainsTaxAvoided
    }

    /// Tax savings from cash donation. Only the deduction changes; gross income and
    /// SS combined-income are unchanged.
    var cashDonationTaxSavings: Double {
        guard cashDonationAmount > 0 else { return 0 }
        let charWithout = scenarioCharitableDeductions - cashDonationAmount
        let deductionWithout = scenarioEffectiveItemize
            ? (baseItemizedDeductions + charWithout)
            : standardDeductionAmount
        let effectiveDeductionWithout = max(deductionWithout, standardDeductionAmount)
        let withoutCash = totalTaxFor(
            grossIncome: scenarioGrossIncome,
            taxableSocialSecurity: scenarioTaxableSocialSecurity,
            deduction: effectiveDeductionWithout
        )
        return withoutCash - scenarioTotalTax
    }

    // MARK: - Legacy Planning Calculations

    /// Tax the heir avoids because the converted amount is now Roth (tax-free) instead of Traditional.
    /// Uses progressive brackets: calculates tax with and without the conversion amount in the heir's income.
    var legacyRothConversionHeirSavings: Double {
        guard enableLegacyPlanning, scenarioTotalRothConversion > 0 else { return 0 }
        let annualWithout = legacyNoActionAnnualDistribution
        let annualWith = legacyWithScenarioAnnualDistribution
        let taxWithout = TaxCalculationEngine.heirTaxEstimate(
            annualDistribution: annualWithout, heirSalary: legacyHeirEstimatedSalary,
            filingStatus: legacyHeirFilingStatus, drawdownYears: legacyDrawdownYears).incrementalTax
        let taxWith = TaxCalculationEngine.heirTaxEstimate(
            annualDistribution: annualWith, heirSalary: legacyHeirEstimatedSalary,
            filingStatus: legacyHeirFilingStatus, drawdownYears: legacyDrawdownYears).incrementalTax
        return max(0, (taxWithout - taxWith) * Double(legacyDrawdownYears))
    }

    /// QCD reduces the inherited IRA balance — heir avoids tax on that portion.
    /// Uses progressive brackets for accuracy.
    var legacyQCDHeirBenefit: Double {
        guard enableLegacyPlanning, scenarioTotalQCD > 0 else { return 0 }
        return scenarioTotalQCD * legacyHeirProgressiveEffectiveRate
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

    /// Heir's estimated total tax on remaining Traditional IRA balance using progressive brackets.
    var legacyHeirEstimatedTaxOnTraditional: Double {
        let annual = legacyWithScenarioAnnualDistribution
        let est = TaxCalculationEngine.heirTaxEstimate(
            annualDistribution: annual, heirSalary: legacyHeirEstimatedSalary,
            filingStatus: legacyHeirFilingStatus, drawdownYears: legacyDrawdownYears)
        return est.totalTaxOverDrawdown
    }

    /// Annual forced distribution from Traditional IRA (no-action scenario).
    var legacyNoActionAnnualDistribution: Double {
        let drawdown = legacyHeirType == "spouseThenChild" ? 10 : legacyDrawdownYears
        guard drawdown > 0 else { return 0 }
        return legacyNoActionTraditionalAtDeath / Double(drawdown)
    }

    /// Annual forced distribution from Traditional IRA (with-scenario).
    var legacyWithScenarioAnnualDistribution: Double {
        let drawdown = legacyHeirType == "spouseThenChild" ? 10 : legacyDrawdownYears
        guard drawdown > 0 else { return 0 }
        return legacyWithScenarioTraditionalAtDeath / Double(drawdown)
    }

    /// Progressive tax estimate for the heir's inherited distributions (with-scenario).
    var legacyHeirTaxEstimate: TaxCalculationEngine.HeirTaxEstimate {
        TaxCalculationEngine.heirTaxEstimate(
            annualDistribution: legacyWithScenarioAnnualDistribution,
            heirSalary: legacyHeirEstimatedSalary,
            filingStatus: legacyHeirFilingStatus,
            drawdownYears: legacyDrawdownYears)
    }

    /// Progressive tax estimate for the no-action scenario.
    var legacyNoActionHeirTaxEstimate: TaxCalculationEngine.HeirTaxEstimate {
        TaxCalculationEngine.heirTaxEstimate(
            annualDistribution: legacyNoActionAnnualDistribution,
            heirSalary: legacyHeirEstimatedSalary,
            filingStatus: legacyHeirFilingStatus,
            drawdownYears: legacyDrawdownYears)
    }

    /// The heir's effective tax rate on inherited distributions (progressive, with-scenario).
    var legacyHeirProgressiveEffectiveRate: Double {
        legacyHeirTaxEstimate.effectiveRateOnDistribution
    }

    /// Heir's projected age at the user's projected year of death.
    /// Nil when the user hasn't supplied `legacyHeirBirthYear`.
    var legacyHeirAgeAtInheritance: Int? {
        guard let birthYear = legacyHeirBirthYear else { return nil }
        return (currentYear + legacyYearsUntilDeath) - birthYear
    }

    /// Kiddie Tax (IRC §1(g)) can apply to dependent full-time students through age 23,
    /// so we surface the concern conservatively at <24. Under 18 is the always-on case.
    var legacyHeirKiddieTaxPossible: Bool {
        guard let age = legacyHeirAgeAtInheritance else { return false }
        return age < 24
    }

    func legacyFamilyWealthAdvantage(atHeirSalary heirSalary: Double) -> Double {
        let noActionRate = TaxCalculationEngine.heirEffectiveTaxRate(
            annualDistribution: legacyNoActionAnnualDistribution,
            heirSalary: heirSalary,
            filingStatus: legacyHeirFilingStatus)
        let withRate = TaxCalculationEngine.heirEffectiveTaxRate(
            annualDistribution: legacyWithScenarioAnnualDistribution,
            heirSalary: heirSalary,
            filingStatus: legacyHeirFilingStatus)

        let noActionAfterTax = legacyNoActionHeirTaxableDrawdown * (1 - noActionRate)
        let withAfterTax = legacyWithScenarioHeirTaxableDrawdown * (1 - withRate)

        let noActionRoth: Double
        let withRoth: Double
        if legacyHeirType == "spouseThenChild" {
            noActionRoth = projectRothSpouseThenChild(startingBalance: totalRothBalance)
            withRoth = projectRothSpouseThenChild(startingBalance: legacyRothAtInheritance)
        } else {
            noActionRoth = projectHeirDrawdownTotal(startingBalance: legacyNoActionRothAtDeath)
            withRoth = projectHeirDrawdownTotal(startingBalance: legacyWithScenarioRothAtDeath)
        }

        let noConvWealth = noActionAfterTax + noActionRoth + legacyTaxMoneyFutureValue
        let withConvWealth = withAfterTax + withRoth
        return withConvWealth - noConvWealth
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
        let heirEstimatedSalary: Double
        let heirFilingStatus: FilingStatus
        let heirType: String
        let currentAge: Int
        let rmdAge: Int
        let taxPaid: Double
        let spouseSurvivorYears: Int
    }

    /// Cached results of expensive legacy calculations.
    private struct LegacyCacheResults {
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
            growthRate: legacyGrowthRate,
            taxableGrowthRate: taxableAccountGrowthRate,
            heirEstimatedSalary: legacyHeirEstimatedSalary,
            heirFilingStatus: legacyHeirFilingStatus,
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
        let chartData = computeCompoundingChartData()
        let breakEvenYr = computeBreakEvenYear()
        return LegacyCacheResults(
            compoundingChartData: chartData,
            breakEvenYear: breakEvenYr
        )
    }

    // MARK: - Legacy Projection Engine (delegates to LegacyPlanningEngine)

    /// Assembles current state into projection parameters for LegacyPlanningEngine.
    private var legacyProjectionParams: LegacyPlanningEngine.ProjectionParams {
        LegacyPlanningEngine.ProjectionParams(
            currentAge: currentAge,
            rmdAge: rmdAge,
            yearsUntilDeath: legacyYearsUntilDeath,
            growthRate: legacyGrowthRate,
            taxableGrowthRate: taxableAccountGrowthRate,
            heirType: legacyHeirType,
            drawdownYears: legacyDrawdownYears,
            spouseSurvivorYears: legacySpouseSurvivorYears,
            spouseBirthYear: spouseBirthYear,
            currentYear: currentYear,
            totalPostDeathYears: legacyTotalPostDeathYears,
            heirEstimatedSalary: legacyHeirEstimatedSalary,
            heirFilingStatus: legacyHeirFilingStatus
        )
    }

    private func projectTraditionalToInheritance(startingBalance: Double) -> Double {
        LegacyPlanningEngine.projectTraditionalToInheritance(startingBalance: startingBalance, params: legacyProjectionParams)
    }

    private func projectRothToInheritance(startingBalance: Double) -> Double {
        LegacyPlanningEngine.projectRothToInheritance(startingBalance: startingBalance, params: legacyProjectionParams)
    }

    private func projectHeirDrawdownTotal(startingBalance: Double) -> Double {
        LegacyPlanningEngine.projectHeirDrawdownTotal(startingBalance: startingBalance, params: legacyProjectionParams)
    }

    private func projectTraditionalSpouseThenChild(startingBalance: Double) -> Double {
        LegacyPlanningEngine.projectTraditionalSpouseThenChild(startingBalance: startingBalance, params: legacyProjectionParams)
    }

    private func projectRothSpouseThenChild(startingBalance: Double) -> Double {
        LegacyPlanningEngine.projectRothSpouseThenChild(startingBalance: startingBalance, params: legacyProjectionParams)
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

    /// Heir's total tax bill WITHOUT scenario actions (progressive brackets).
    var legacyCostOfInaction: Double {
        guard enableLegacyPlanning else { return 0 }
        return legacyNoActionHeirTaxEstimate.totalTaxOverDrawdown
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

    /// Heir's tax bill WITH scenario actions (progressive brackets).
    var legacyWithScenarioHeirTax: Double {
        guard enableLegacyPlanning else { return 0 }
        return legacyHeirTaxEstimate.totalTaxOverDrawdown
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
        let noActionEffRate = legacyNoActionHeirTaxEstimate.effectiveRateOnDistribution
        let heirAfterTaxTraditional = legacyNoActionHeirTaxableDrawdown * (1 - noActionEffRate)
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
        let withEffRate = legacyHeirProgressiveEffectiveRate
        let heirAfterTaxTraditional = legacyWithScenarioHeirTaxableDrawdown * (1 - withEffRate)
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

    // MARK: - Compounding Chart

    var legacyCompoundingChartData: [LegacyCompoundingPoint] {
        return getLegacyCachedResults().compoundingChartData
    }

    private func computeCompoundingChartData() -> [LegacyCompoundingPoint] {
        LegacyPlanningEngine.computeCompoundingChartData(
            scenarioTotalRothConversion: scenarioTotalRothConversion,
            conversionTaxPaidToday: legacyConversionTaxPaidToday,
            growthRate: legacyGrowthRate,
            taxableGrowthRate: taxableAccountGrowthRate,
            heirEstimatedSalary: legacyHeirEstimatedSalary,
            heirFilingStatus: legacyHeirFilingStatus,
            heirDrawdownYears: legacyDrawdownYears,
            maxYears: min(40, legacyYearsUntilDeath + legacyTotalPostDeathYears))
    }

    var legacyBreakEvenYear: Int? {
        return getLegacyCachedResults().breakEvenYear
    }

    private func computeBreakEvenYear() -> Int? {
        LegacyPlanningEngine.computeBreakEvenYear(
            scenarioTotalRothConversion: scenarioTotalRothConversion,
            conversionTaxPaidToday: legacyConversionTaxPaidToday,
            growthRate: legacyGrowthRate,
            taxableGrowthRate: taxableAccountGrowthRate,
            heirEstimatedSalary: legacyHeirEstimatedSalary,
            heirFilingStatus: legacyHeirFilingStatus,
            heirDrawdownYears: legacyDrawdownYears,
            maxYears: legacyYearsUntilDeath + legacyTotalPostDeathYears)
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
            hasSSBenefits: primarySSBenefit?.hasData == true,
            hasAccounts: !iraAccounts.isEmpty,
            hasIncomeSources: !incomeSources.isEmpty,
            hasDeductions: !deductionItems.isEmpty
        )
    }
}

