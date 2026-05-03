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

struct MultiYearStaticInputs: Equatable {
    // Account starting balances (rolled up from 1.9 AccountType + user inputs for taxable/HSA)
    let startingBalances: AccountSnapshot

    // Demographics
    let primaryCurrentAge: Int
    let spouseCurrentAge: Int?      // nil = single filer
    let filingStatus: FilingStatus  // existing 1.9 enum
    let state: String               // 2-letter postal code (e.g., "CA")

    // SS inputs
    let primarySSClaimAge: Int                   // 62-70
    let spouseSSClaimAge: Int?
    let primaryExpectedBenefitAtFRA: Double      // monthly, in today's dollars
    let spouseExpectedBenefitAtFRA: Double?
    let primaryBirthYear: Int                    // for FRA calculation
    let spouseBirthYear: Int?

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
    let primaryOtherOrdinaryIncome: Double   // dividends + interest + cap gains + state refund + other (taxable, ordinary rate)
    let spouseOtherOrdinaryIncome: Double    // same, for spouse

    // ACA / Medicare context
    let acaEnrolled: Bool
    let acaHouseholdSize: Int
    let primaryMedicareEnrollmentAge: Int  // typically 65
    let spouseMedicareEnrollmentAge: Int?

    // Living-expense baseline (annual, in today's dollars)
    let baselineAnnualExpenses: Double

    init(
        startingBalances: AccountSnapshot,
        primaryCurrentAge: Int,
        spouseCurrentAge: Int?,
        filingStatus: FilingStatus,
        state: String,
        primarySSClaimAge: Int,
        spouseSSClaimAge: Int?,
        primaryExpectedBenefitAtFRA: Double,
        spouseExpectedBenefitAtFRA: Double?,
        primaryBirthYear: Int,
        spouseBirthYear: Int?,
        primaryWageIncome: Double,
        spouseWageIncome: Double,
        primaryPensionIncome: Double,
        spousePensionIncome: Double,
        primaryOtherOrdinaryIncome: Double = 0,   // NEW — see field comment above
        spouseOtherOrdinaryIncome: Double = 0,    // NEW — see field comment above
        acaEnrolled: Bool,
        acaHouseholdSize: Int,
        primaryMedicareEnrollmentAge: Int,
        spouseMedicareEnrollmentAge: Int?,
        baselineAnnualExpenses: Double
    ) {
        self.startingBalances = startingBalances
        self.primaryCurrentAge = primaryCurrentAge
        self.spouseCurrentAge = spouseCurrentAge
        self.filingStatus = filingStatus
        self.state = state
        self.primarySSClaimAge = primarySSClaimAge
        self.spouseSSClaimAge = spouseSSClaimAge
        self.primaryExpectedBenefitAtFRA = primaryExpectedBenefitAtFRA
        self.spouseExpectedBenefitAtFRA = spouseExpectedBenefitAtFRA
        self.primaryBirthYear = primaryBirthYear
        self.spouseBirthYear = spouseBirthYear
        self.primaryWageIncome = primaryWageIncome
        self.spouseWageIncome = spouseWageIncome
        self.primaryPensionIncome = primaryPensionIncome
        self.spousePensionIncome = spousePensionIncome
        self.primaryOtherOrdinaryIncome = primaryOtherOrdinaryIncome
        self.spouseOtherOrdinaryIncome = spouseOtherOrdinaryIncome
        self.acaEnrolled = acaEnrolled
        self.acaHouseholdSize = acaHouseholdSize
        self.primaryMedicareEnrollmentAge = primaryMedicareEnrollmentAge
        self.spouseMedicareEnrollmentAge = spouseMedicareEnrollmentAge
        self.baselineAnnualExpenses = baselineAnnualExpenses
    }

    /// Returns a copy with the named spouse's claim age replaced (used by SSClaimNudge).
    func withClaimAge(_ age: Int, for spouse: SpouseID) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: startingBalances,
            primaryCurrentAge: primaryCurrentAge,
            spouseCurrentAge: spouseCurrentAge,
            filingStatus: filingStatus,
            state: state,
            primarySSClaimAge: spouse == .primary ? age : primarySSClaimAge,
            spouseSSClaimAge: spouse == .spouse ? age : spouseSSClaimAge,
            primaryExpectedBenefitAtFRA: primaryExpectedBenefitAtFRA,
            spouseExpectedBenefitAtFRA: spouseExpectedBenefitAtFRA,
            primaryBirthYear: primaryBirthYear,
            spouseBirthYear: spouseBirthYear,
            primaryWageIncome: primaryWageIncome,
            spouseWageIncome: spouseWageIncome,
            primaryPensionIncome: primaryPensionIncome,
            spousePensionIncome: spousePensionIncome,
            primaryOtherOrdinaryIncome: primaryOtherOrdinaryIncome,
            spouseOtherOrdinaryIncome: spouseOtherOrdinaryIncome,
            acaEnrolled: acaEnrolled,
            acaHouseholdSize: acaHouseholdSize,
            primaryMedicareEnrollmentAge: primaryMedicareEnrollmentAge,
            spouseMedicareEnrollmentAge: spouseMedicareEnrollmentAge,
            baselineAnnualExpenses: baselineAnnualExpenses
        )
    }
}
