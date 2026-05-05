//
//  MultiYearInputAdapter.swift
//  RetireSmartIRA
//
//  Bridges 1.9 runtime ObservableObject state to the pure-value MultiYearStaticInputs
//  snapshot consumed by the 2.0 multi-year engine.
//
//  @MainActor because DataManager and ScenarioStateManager are both MainActor-bound
//  ObservableObjects whose @Published properties must be read on the main actor.
//
//  Field-name mapping from 1.9 API (recorded here for downstream task reference):
//
//  Account buckets:
//    primaryTraditional = iraAccounts filtered by .accountType.isTraditionalType && .owner == .primary
//    spouseTraditional  = iraAccounts filtered by .accountType.isTraditionalType && .owner == .spouse
//    roth               = iraAccounts filtered by .accountType.isRothType (both spouses combined)
//    taxable            = assumptions.currentTaxableBalance (no AccountType for taxable in 1.9)
//    hsa                = assumptions.currentHSABalance (no AccountType for HSA in 1.9)
//
//  Demographics:
//    primaryCurrentAge   = dataManager.currentAge        (currentYear - birthYear)
//    spouseCurrentAge    = dataManager.spouseCurrentAge  (0 when enableSpouse=false → nil)
//    filingStatus        = dataManager.filingStatus
//    state               = dataManager.selectedState.abbreviation  (2-letter postal code)
//
//  SS:
//    primarySSClaimAge          = dataManager.primarySSBenefit?.plannedClaimingAge   (default 67)
//    spouseSSClaimAge           = dataManager.spouseSSBenefit?.plannedClaimingAge    (default 67)
//    primaryExpectedBenefitAtFRA = dataManager.primarySSBenefit?.benefitAtFRA        (default 0)
//    spouseExpectedBenefitAtFRA  = dataManager.spouseSSBenefit?.benefitAtFRA         (default 0)
//    primaryBirthYear           = dataManager.birthYear
//    spouseBirthYear            = dataManager.spouseBirthYear
//
//  Income (derived from incomeSources array by IncomeType):
//    wage income            = IncomeType.consulting ("Employment/Other Income") filtered by owner
//    pension income         = IncomeType.pension filtered by owner
//    other ordinary income  = dividends + qualifiedDividends + interest + capitalGainsShort
//                             + capitalGainsLong + stateTaxRefund + other (filtered by owner)
//                             V2.0 SIMPLIFICATION: all taxed as ordinary; v2.1 will preserve
//                             preferential rate on LTCG and qualified dividends.
//
//  ACA / Medicare:
//    acaEnrolled             = scenarioState.enableACAModeling
//    acaHouseholdSize        = scenarioState.acaHouseholdSize
//    primaryMedicareEnrollmentAge = 65 (standard; no per-user field in 1.9)
//    spouseMedicareEnrollmentAge  = 65 when enableSpouse, else nil
//
//  Expenses:
//    baselineAnnualExpenses  = assumptions.baselineAnnualExpenses (migrated from caller-supplied
//                              in Plan B; no annualExpenses field exists in 1.9; expenses are
//                              modeled implicitly via income-vs-withdrawal planning)
//

import Foundation

@MainActor
enum MultiYearInputAdapter {

    /// Build a MultiYearStaticInputs snapshot from runtime state.
    ///
    /// - Parameters:
    ///   - dataManager: The live DataManager instance.
    ///   - scenarioState: The live ScenarioStateManager instance (also reachable as
    ///     `dataManager.scenario`, but passed separately to keep the signature testable).
    ///   - assumptions: Per-scenario assumptions. `currentTaxableBalance`,
    ///     `currentHSABalance`, and `baselineAnnualExpenses` are read from here.
    ///   - excludeYear1Overrides: When `true`, zeroes all Year 1 lever values (Roth
    ///     conversion, extra withdrawal, QCD for both spouses) before they flow into
    ///     `MultiYearStaticInputs`. Used by `MultiYearStrategyManager` when building
    ///     inputs for the engine-optimal baseline cache, so the optimizer chooses Year 1
    ///     levers freely rather than being constrained to the user's slider values.
    ///     Default `false` preserves existing call-site behaviour.
    static func build(
        from dataManager: DataManager,
        scenarioState: ScenarioStateManager,
        assumptions: MultiYearAssumptions,
        excludeYear1Overrides: Bool = false
    ) -> MultiYearStaticInputs {

        // Year 1 lever values — optionally zeroed for the optimal-baseline cache.
        let primaryRoth      = excludeYear1Overrides ? 0 : dataManager.yourRothConversion
        let spouseRoth       = excludeYear1Overrides ? 0 : dataManager.spouseRothConversion
        let primaryWithdrawal = excludeYear1Overrides ? 0 : dataManager.yourExtraWithdrawal
        let spouseWithdrawal = excludeYear1Overrides ? 0 : dataManager.spouseExtraWithdrawal
        let primaryQCD       = excludeYear1Overrides ? 0 : dataManager.yourQCDAmount
        let spouseQCD        = excludeYear1Overrides ? 0 : dataManager.spouseQCDAmount

        let currentTaxableBalance = assumptions.currentTaxableBalance
        let currentHSABalance = assumptions.currentHSABalance
        let baselineAnnualExpenses = assumptions.baselineAnnualExpenses

        // MARK: Account Buckets
        // Roll up the 6 1.9 AccountType cases. Traditional buckets are split by owner so the
        // engine can compute per-spouse RMDs independently (Bug D fix — per-spouse tracking).
        // AccountType.isTraditionalType covers .traditionalIRA, .traditional401k, .inheritedTraditionalIRA
        // AccountType.isRothType covers .rothIRA, .roth401k, .inheritedRothIRA
        let allAccounts = dataManager.iraAccounts
        let primaryTraditional = allAccounts
            .filter { $0.accountType.isTraditionalType && $0.owner == .primary }
            .reduce(0.0) { $0 + $1.balance }
        let spouseTraditional = allAccounts
            .filter { $0.accountType.isTraditionalType && $0.owner == .spouse }
            .reduce(0.0) { $0 + $1.balance }
        let roth = allAccounts
            .filter { $0.accountType.isRothType }
            .reduce(0.0) { $0 + $1.balance }

        let snapshot = AccountSnapshot(
            primaryTraditional: primaryTraditional,
            spouseTraditional: spouseTraditional,
            roth: roth,
            taxable: currentTaxableBalance,
            hsa: currentHSABalance
        )

        // MARK: Demographics
        let primaryAge = dataManager.currentAge
        // spouseCurrentAge returns 0 when enableSpouse=false; map to nil for the engine.
        let spouseAge: Int? = dataManager.enableSpouse ? dataManager.spouseCurrentAge : nil

        // MARK: SS
        // plannedClaimingAge lives on SSBenefitEstimate, not as a top-level DataManager field.
        // Default to 67 (FRA for most workers born 1960+) when not yet entered.
        let primaryClaimAge = dataManager.primarySSBenefit?.plannedClaimingAge ?? 67
        let spouseClaimAge: Int? = dataManager.enableSpouse
            ? (dataManager.spouseSSBenefit?.plannedClaimingAge ?? 67)
            : nil

        // benefitAtFRA = the user's PIA (Primary Insurance Amount) from their SSA statement.
        let primaryBenefit = dataManager.primarySSBenefit?.benefitAtFRA ?? 0
        let spouseBenefit: Double? = dataManager.enableSpouse
            ? (dataManager.spouseSSBenefit?.benefitAtFRA ?? 0)
            : nil

        // MARK: Income (derived from incomeSources array)
        // Wage/employment income uses IncomeType.consulting ("Employment/Other Income").
        // Pension income uses IncomeType.pension.
        // Other ordinary income (dividends, interest, cap gains, state refund, other) uses isOtherOrdinary.
        let sources = dataManager.incomeSources
        let primaryWage = primaryIncome(from: sources, type: .consulting)
        let spouseWage = spouseIncome(from: sources, type: .consulting, enableSpouse: dataManager.enableSpouse)
        let primaryPension = primaryIncome(from: sources, type: .pension)
        let spousePension = spouseIncome(from: sources, type: .pension, enableSpouse: dataManager.enableSpouse)
        let primaryOther = Self.primaryOtherOrdinaryIncome(from: sources)
        let spouseOther = Self.spouseOtherOrdinaryIncome(from: sources, enableSpouse: dataManager.enableSpouse)

        // MARK: ACA / Medicare
        let acaEnrolled = scenarioState.enableACAModeling
        let acaSize = scenarioState.acaHouseholdSize
        // Standard Medicare eligibility is 65. No per-user override field exists in 1.9.
        let primaryMedAge = 65
        let spouseMedAge: Int? = dataManager.enableSpouse ? 65 : nil

        // MARK: State (2-letter postal abbreviation)
        let stateAbbrev = dataManager.selectedState.abbreviation

        return MultiYearStaticInputs(
            startingBalances: snapshot,
            primaryCurrentAge: primaryAge,
            spouseCurrentAge: spouseAge,
            filingStatus: dataManager.filingStatus,
            state: stateAbbrev,
            primarySSClaimAge: primaryClaimAge,
            spouseSSClaimAge: spouseClaimAge,
            primaryExpectedBenefitAtFRA: primaryBenefit,
            spouseExpectedBenefitAtFRA: spouseBenefit,
            primaryBirthYear: dataManager.birthYear,
            spouseBirthYear: dataManager.enableSpouse ? dataManager.spouseBirthYear : nil,
            primaryWageIncome: primaryWage,
            spouseWageIncome: spouseWage,
            primaryPensionIncome: primaryPension,
            spousePensionIncome: spousePension,
            primaryOtherOrdinaryIncome: primaryOther,
            spouseOtherOrdinaryIncome: spouseOther,
            acaEnrolled: acaEnrolled,
            acaHouseholdSize: acaSize,
            primaryMedicareEnrollmentAge: primaryMedAge,
            spouseMedicareEnrollmentAge: spouseMedAge,
            baselineAnnualExpenses: baselineAnnualExpenses,
            year1PrimaryRothConversion: primaryRoth,
            year1SpouseRothConversion: spouseRoth,
            year1PrimaryWithdrawal: primaryWithdrawal,
            year1SpouseWithdrawal: spouseWithdrawal,
            year1PrimaryQCD: primaryQCD,
            year1SpouseQCD: spouseQCD
        )
    }

    // MARK: - Private Helpers

    /// Sum annualAmount for all primary-owner income sources of the given type.
    private static func primaryIncome(from sources: [IncomeSource], type incomeType: IncomeType) -> Double {
        sources
            .filter { $0.type == incomeType && $0.owner == .primary }
            .reduce(0.0) { $0 + $1.annualAmount }
    }

    /// Sum annualAmount for all spouse-owner income sources of the given type.
    /// Returns 0 when spouse is not enabled.
    private static func spouseIncome(from sources: [IncomeSource], type incomeType: IncomeType, enableSpouse: Bool) -> Double {
        guard enableSpouse else { return 0 }
        return sources
            .filter { $0.type == incomeType && $0.owner == .spouse }
            .reduce(0.0) { $0 + $1.annualAmount }
    }

    /// Sum annualAmount for all primary-owner income sources whose type contributes
    /// to AGI as ORDINARY income, EXCLUDING types handled separately:
    ///   - .consulting (wage), .pension (already extracted as their own fields)
    ///   - .socialSecurity (handled via SSBenefitEstimate model)
    ///   - .rmd (engine-generated, not user-entered)
    ///   - .vaDisability, .taxExemptInterest (excluded from AGI by design)
    private static func primaryOtherOrdinaryIncome(from sources: [IncomeSource]) -> Double {
        sources
            .filter { $0.owner == .primary && Self.isOtherOrdinary(type: $0.type) }
            .reduce(0.0) { $0 + $1.annualAmount }
    }

    /// Same as primaryOtherOrdinaryIncome but for spouse owner.
    /// Returns 0 when spouse is not enabled.
    private static func spouseOtherOrdinaryIncome(from sources: [IncomeSource], enableSpouse: Bool) -> Double {
        guard enableSpouse else { return 0 }
        return sources
            .filter { $0.owner == .spouse && Self.isOtherOrdinary(type: $0.type) }
            .reduce(0.0) { $0 + $1.annualAmount }
    }

    /// Allowlist of IncomeType cases that are taxable as ORDINARY income and not
    /// already handled by another field on MultiYearStaticInputs.
    ///
    /// V2.0 simplification: includes capitalGainsLong and qualifiedDividends, both of
    /// which warrant preferential rate treatment that this v2.0 mapping doesn't model.
    /// Conservative over-tax direction; v2.1 Path B refactor will classify properly.
    ///
    /// Exhaustive switch (no default branch): any future IncomeType case must be
    /// explicitly classified here — Swift will fail to compile otherwise.
    private static func isOtherOrdinary(type incomeType: IncomeType) -> Bool {
        switch incomeType {
        case .dividends, .qualifiedDividends, .interest,
             .capitalGainsShort, .capitalGainsLong,
             .stateTaxRefund, .other:
            return true
        case .consulting, .pension:
            return false  // already extracted as wage / pension
        case .socialSecurity, .rmd:
            return false  // handled separately
        case .vaDisability, .taxExemptInterest:
            return false  // excluded from AGI by design
        }
    }
}
