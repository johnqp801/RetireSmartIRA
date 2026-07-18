//
//  MultiYearStaticInputs.swift
//  RetireSmartIRA
//
//  Pure value-type snapshot that the multi-year calculation engine consumes.
//  Built once from runtime ObservableObject state via MultiYearInputAdapter and
//  then passed immutably through all engine phases.
//
//  No SwiftUI, no DataManager, no Combine — deliberately dependency-free so
//  engine code is trivially unit-testable.
//

import Foundation

struct MultiYearStaticInputs: Equatable, Sendable {
    // Account starting balances (rolled up from 1.9 AccountType + user inputs for taxable/HSA)
    let startingBalances: AccountSnapshot

    // First-class taxable accounts (V2.0). Empty -> engine synthesizes a single bucket from
    // startingBalances.taxable so legacy callers/tests are unchanged.
    let taxableAccounts: [TaxableAccountInput]

    // Inherited IRAs with complete beneficiary metadata (2.1). Each gets its own engine
    // bucket driven by RMDCalculationEngine's beneficiary schedule (single-life RMDs when
    // the decedent died on/after RBD, forced full drain by year 10 for non-EDBs, tax-free
    // drain for inherited Roth). Inherited accounts missing metadata stay rolled into the
    // owner buckets by the adapter (legacy fallback).
    let inheritedAccounts: [InheritedAccountInput]

    // Scenario planning base year (year 0 of the projection). Defaults to the current
    // calendar year so production/existing callers are unchanged, but is injectable so a
    // saved or future-dated scenario projects from a fixed year and tests are deterministic
    // (instead of silently depending on `Date()`).
    let baseYear: Int

    // Demographics
    let primaryCurrentAge: Int
    let spouseCurrentAge: Int?      // nil = single filer
    let filingStatus: FilingStatus  // existing 1.9 enum
    let state: String               // 2-letter postal code (e.g., "CA")
    let localIncomeTaxRate: Double   // user-entered local/city income tax rate (fraction); 0 = none

    // SS inputs
    let primarySSClaimAge: Int                   // 62-70
    let spouseSSClaimAge: Int?
    let primaryExpectedBenefitAtFRA: Double      // monthly, in today's dollars
    let spouseExpectedBenefitAtFRA: Double?
    let primaryBirthYear: Int                    // for FRA calculation
    let spouseBirthYear: Int?

    // Full birth dates (month-precise) for QCD 70½ eligibility. The `...BirthYear` Ints above
    // stay for RMD-age bracketing (year-of-birth based); these are ADDED, not a replacement.
    let primaryBirthDate: Date
    let spouseBirthDate: Date?

    // Income sources (pre-retirement / wage if still working)
    let primaryWageIncome: Double
    let spouseWageIncome: Double
    let primaryPensionIncome: Double
    let spousePensionIncome: Double

    // V2.0 SIMPLIFICATION (Gemini review 2026-05-03): Captures dividends, interest,
    // capital gains (both short and long), state tax refunds, and "other" income types
    // that don't fit consulting/pension/SS. All are taxed as ORDINARY income for v2.0,
    // even though qualified dividends and long-term capital gains warrant preferential
    // rate treatment. This over-states tax by ~5pp on those dollars — conservative
    // direction, makes the optimizer slightly less aggressive than truly optimal.
    // V2.1 will classify by income type via a Path B refactor (ProjectionEngine
    // consumes [IncomeSource] directly with allowlist semantics).
    let primaryOtherOrdinaryIncome: Double   // ordinary-rate: dividends + interest + short-term cap gains + state refund + other
    let spouseOtherOrdinaryIncome: Double    // same, for spouse

    // Preferential-rate income (qualified dividends + long-term capital gains). Included in
    // AGI/MAGI like any income, but taxed at the federal LTCG schedule, not ordinary rates.
    // (Decumulation step 1 of 2.1: prior to this, these were lumped into otherOrdinaryIncome
    // and over-taxed ~5pp. Cost-basis / gain-harvesting on taxable-account WITHDRAWALS remains
    // a later 2.1 item — this only fixes the rate on the user's stated investment income.)
    let primaryPreferentialIncome: Double
    let spousePreferentialIncome: Double

    // NIIT-qualifying net investment income from the user's stated income sources
    // (dividends, qualified dividends, interest, short + long cap gains). Used ONLY to
    // compute NIIT (§ ProjectionEngine); it does not feed AGI (the same dollars already
    // reach AGI via otherOrdinaryIncome / preferentialIncome / account income). Excludes
    // state refunds and "other". Mirrors TaxCalculationEngine.niitQualifyingTypes.
    let primaryNetInvestmentIncome: Double
    let spouseNetInvestmentIncome: Double

    // ACA / Medicare context
    let acaEnrolled: Bool
    let acaHouseholdSize: Int
    let primaryMedicareEnrollmentAge: Int  // typically 65
    let spouseMedicareEnrollmentAge: Int?

    // Living-expense baseline (annual, in today's dollars)
    let baselineAnnualExpenses: Double

    // Heir / legacy inputs (reused from DataManager's single-year Legacy Impact view) — drive
    // the heir-weighted optimizer objective + trade-off frontier.
    let heirSalary: Double             // heir's estimated annual wage income
    let heirFilingStatus: FilingStatus
    let heirDrawdownYears: Int         // SECURE forced-drawdown window (default 10)

    // Year 1 lever values from DataManager slider state.
    // These capture the user's current-year overrides (Roth conversion,
    // extra withdrawal, QCD) so the engine can honor them in Year 1 of the
    // projection. When `excludeYear1Overrides: true` is passed to
    // MultiYearInputAdapter.build(), all six fields are zeroed so the engine
    // computes the unconstrained optimal baseline path.
    let year1PrimaryRothConversion: Double    // default 0
    let year1SpouseRothConversion: Double     // default 0
    let year1PrimaryWithdrawal: Double        // extra withdrawal, default 0
    let year1SpouseWithdrawal: Double         // default 0
    let year1PrimaryQCD: Double               // qualified charitable distribution, default 0
    let year1SpouseQCD: Double                // default 0

    // The household's recurring charitable-giving plan (intent + QCD funding method). Carried
    // here for Phase 1c to consume; NOT applied by ProjectionEngine in Phase 1b (mirrors the
    // carried-but-unapplied year1 QCD fields).
    let charitableGivingPlan: CharitableGivingPlan

    // Itemizable deductions carried from the single-year scenario (flat nominal). SALT here is
    // property + other non-income-tax SALT; the state INCOME tax is computed per year in the engine.
    let carriedMortgageAndOtherItemized: Double
    let carriedPropertyAndOtherSALT: Double
    let carriedGrossMedicalExpenses: Double

    init(
        startingBalances: AccountSnapshot,
        baseYear: Int = Calendar.current.component(.year, from: Date()),
        primaryCurrentAge: Int,
        spouseCurrentAge: Int?,
        filingStatus: FilingStatus,
        state: String,
        localIncomeTaxRate: Double = 0,
        primarySSClaimAge: Int,
        spouseSSClaimAge: Int?,
        primaryExpectedBenefitAtFRA: Double,
        spouseExpectedBenefitAtFRA: Double?,
        primaryBirthYear: Int,
        spouseBirthYear: Int?,
        primaryBirthDate: Date = Date(timeIntervalSince1970: 0),
        spouseBirthDate: Date? = nil,
        primaryWageIncome: Double,
        spouseWageIncome: Double,
        primaryPensionIncome: Double,
        spousePensionIncome: Double,
        primaryOtherOrdinaryIncome: Double = 0,   // NEW — see field comment above
        spouseOtherOrdinaryIncome: Double = 0,    // NEW — see field comment above
        primaryPreferentialIncome: Double = 0,    // qualified dividends + LTCG (preferential rate)
        spousePreferentialIncome: Double = 0,
        primaryNetInvestmentIncome: Double = 0,
        spouseNetInvestmentIncome: Double = 0,
        acaEnrolled: Bool,
        acaHouseholdSize: Int,
        primaryMedicareEnrollmentAge: Int,
        spouseMedicareEnrollmentAge: Int?,
        baselineAnnualExpenses: Double,
        heirSalary: Double = 75_000,
        heirFilingStatus: FilingStatus = .single,
        heirDrawdownYears: Int = 10,
        year1PrimaryRothConversion: Double = 0,
        year1SpouseRothConversion: Double = 0,
        year1PrimaryWithdrawal: Double = 0,
        year1SpouseWithdrawal: Double = 0,
        year1PrimaryQCD: Double = 0,
        year1SpouseQCD: Double = 0,
        charitableGivingPlan: CharitableGivingPlan = .none,
        carriedMortgageAndOtherItemized: Double = 0,
        carriedPropertyAndOtherSALT: Double = 0,
        carriedGrossMedicalExpenses: Double = 0,
        taxableAccounts: [TaxableAccountInput] = [],
        inheritedAccounts: [InheritedAccountInput] = []
    ) {
        self.startingBalances = startingBalances
        self.taxableAccounts = taxableAccounts
        self.inheritedAccounts = inheritedAccounts
        self.baseYear = baseYear
        self.primaryCurrentAge = primaryCurrentAge
        self.spouseCurrentAge = spouseCurrentAge
        self.filingStatus = filingStatus
        self.state = state
        self.localIncomeTaxRate = localIncomeTaxRate
        self.primarySSClaimAge = primarySSClaimAge
        self.spouseSSClaimAge = spouseSSClaimAge
        self.primaryExpectedBenefitAtFRA = primaryExpectedBenefitAtFRA
        self.spouseExpectedBenefitAtFRA = spouseExpectedBenefitAtFRA
        self.primaryBirthYear = primaryBirthYear
        self.spouseBirthYear = spouseBirthYear
        self.primaryBirthDate = primaryBirthDate
        self.spouseBirthDate = spouseBirthDate
        self.primaryWageIncome = primaryWageIncome
        self.spouseWageIncome = spouseWageIncome
        self.primaryPensionIncome = primaryPensionIncome
        self.spousePensionIncome = spousePensionIncome
        self.primaryOtherOrdinaryIncome = primaryOtherOrdinaryIncome
        self.spouseOtherOrdinaryIncome = spouseOtherOrdinaryIncome
        self.primaryPreferentialIncome = primaryPreferentialIncome
        self.spousePreferentialIncome = spousePreferentialIncome
        self.primaryNetInvestmentIncome = primaryNetInvestmentIncome
        self.spouseNetInvestmentIncome = spouseNetInvestmentIncome
        self.acaEnrolled = acaEnrolled
        self.acaHouseholdSize = acaHouseholdSize
        self.primaryMedicareEnrollmentAge = primaryMedicareEnrollmentAge
        self.spouseMedicareEnrollmentAge = spouseMedicareEnrollmentAge
        self.baselineAnnualExpenses = baselineAnnualExpenses
        self.heirSalary = heirSalary
        self.heirFilingStatus = heirFilingStatus
        self.heirDrawdownYears = heirDrawdownYears
        self.year1PrimaryRothConversion = year1PrimaryRothConversion
        self.year1SpouseRothConversion = year1SpouseRothConversion
        self.year1PrimaryWithdrawal = year1PrimaryWithdrawal
        self.year1SpouseWithdrawal = year1SpouseWithdrawal
        self.year1PrimaryQCD = year1PrimaryQCD
        self.year1SpouseQCD = year1SpouseQCD
        self.charitableGivingPlan = charitableGivingPlan
        self.carriedMortgageAndOtherItemized = carriedMortgageAndOtherItemized
        self.carriedPropertyAndOtherSALT = carriedPropertyAndOtherSALT
        self.carriedGrossMedicalExpenses = carriedGrossMedicalExpenses
    }

    /// Returns a copy with the named spouse's claim age replaced (used by SSClaimNudge).
    func withClaimAge(_ age: Int, for spouse: SpouseID) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: startingBalances,
            baseYear: baseYear,
            primaryCurrentAge: primaryCurrentAge,
            spouseCurrentAge: spouseCurrentAge,
            filingStatus: filingStatus,
            state: state,
            localIncomeTaxRate: localIncomeTaxRate,
            primarySSClaimAge: spouse == .primary ? age : primarySSClaimAge,
            spouseSSClaimAge: spouse == .spouse ? age : spouseSSClaimAge,
            primaryExpectedBenefitAtFRA: primaryExpectedBenefitAtFRA,
            spouseExpectedBenefitAtFRA: spouseExpectedBenefitAtFRA,
            primaryBirthYear: primaryBirthYear,
            spouseBirthYear: spouseBirthYear,
            primaryBirthDate: primaryBirthDate,
            spouseBirthDate: spouseBirthDate,
            primaryWageIncome: primaryWageIncome,
            spouseWageIncome: spouseWageIncome,
            primaryPensionIncome: primaryPensionIncome,
            spousePensionIncome: spousePensionIncome,
            primaryOtherOrdinaryIncome: primaryOtherOrdinaryIncome,
            spouseOtherOrdinaryIncome: spouseOtherOrdinaryIncome,
            primaryPreferentialIncome: primaryPreferentialIncome,
            spousePreferentialIncome: spousePreferentialIncome,
            primaryNetInvestmentIncome: primaryNetInvestmentIncome,
            spouseNetInvestmentIncome: spouseNetInvestmentIncome,
            acaEnrolled: acaEnrolled,
            acaHouseholdSize: acaHouseholdSize,
            primaryMedicareEnrollmentAge: primaryMedicareEnrollmentAge,
            spouseMedicareEnrollmentAge: spouseMedicareEnrollmentAge,
            baselineAnnualExpenses: baselineAnnualExpenses,
            heirSalary: heirSalary,
            heirFilingStatus: heirFilingStatus,
            heirDrawdownYears: heirDrawdownYears,
            year1PrimaryRothConversion: year1PrimaryRothConversion,
            year1SpouseRothConversion: year1SpouseRothConversion,
            year1PrimaryWithdrawal: year1PrimaryWithdrawal,
            year1SpouseWithdrawal: year1SpouseWithdrawal,
            year1PrimaryQCD: year1PrimaryQCD,
            year1SpouseQCD: year1SpouseQCD,
            charitableGivingPlan: charitableGivingPlan,
            carriedMortgageAndOtherItemized: carriedMortgageAndOtherItemized,
            carriedPropertyAndOtherSALT: carriedPropertyAndOtherSALT,
            carriedGrossMedicalExpenses: carriedGrossMedicalExpenses,
            taxableAccounts: taxableAccounts,
            inheritedAccounts: inheritedAccounts
        )
    }
}
