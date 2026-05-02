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
//    traditional = iraAccounts filtered by .accountType.isTraditionalType
//    roth        = iraAccounts filtered by .accountType.isRothType
//    taxable     = caller-supplied (no AccountType for taxable in 1.9)
//    hsa         = caller-supplied (no AccountType for HSA in 1.9)
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
//    wage income   = IncomeType.consulting ("Employment/Other Income") filtered by owner
//    pension income = IncomeType.pension filtered by owner
//
//  ACA / Medicare:
//    acaEnrolled             = scenarioState.enableACAModeling
//    acaHouseholdSize        = scenarioState.acaHouseholdSize
//    primaryMedicareEnrollmentAge = 65 (standard; no per-user field in 1.9)
//    spouseMedicareEnrollmentAge  = 65 when enableSpouse, else nil
//
//  Expenses:
//    baselineAnnualExpenses  = caller-supplied (no annualExpenses field exists in 1.9;
//                              expenses are modeled implicitly via income-vs-withdrawal
//                              planning rather than as an explicit budget line)
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
    ///   - currentTaxableBalance: Non-IRA taxable account balance. No AccountType for
    ///     this in 1.9; caller supplies it (e.g., from a user-input field or MultiYearAssumptions).
    ///   - currentHSABalance: HSA balance. Same rationale as taxable.
    ///   - baselineAnnualExpenses: Annual household spending baseline in today's dollars.
    ///     No single expense field exists in 1.9; caller supplies it.
    static func build(
        from dataManager: DataManager,
        scenarioState: ScenarioStateManager,
        currentTaxableBalance: Double,
        currentHSABalance: Double,
        baselineAnnualExpenses: Double
    ) -> MultiYearStaticInputs {

        // MARK: Account Buckets
        // Roll up the 6 1.9 AccountType cases into the engine's two buckets.
        // AccountType.isTraditionalType covers .traditionalIRA, .traditional401k, .inheritedTraditionalIRA
        // AccountType.isRothType covers .rothIRA, .roth401k, .inheritedRothIRA
        let allAccounts = dataManager.iraAccounts
        let traditional = allAccounts
            .filter { $0.accountType.isTraditionalType }
            .reduce(0.0) { $0 + $1.balance }
        let roth = allAccounts
            .filter { $0.accountType.isRothType }
            .reduce(0.0) { $0 + $1.balance }

        let snapshot = AccountSnapshot(
            traditional: traditional,
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
        let sources = dataManager.incomeSources
        let primaryWage = primaryIncome(from: sources, type: .consulting)
        let spouseWage = spouseIncome(from: sources, type: .consulting, enableSpouse: dataManager.enableSpouse)
        let primaryPension = primaryIncome(from: sources, type: .pension)
        let spousePension = spouseIncome(from: sources, type: .pension, enableSpouse: dataManager.enableSpouse)

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
            acaEnrolled: acaEnrolled,
            acaHouseholdSize: acaSize,
            primaryMedicareEnrollmentAge: primaryMedAge,
            spouseMedicareEnrollmentAge: spouseMedAge,
            baselineAnnualExpenses: baselineAnnualExpenses
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
}
