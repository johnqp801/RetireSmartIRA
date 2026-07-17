//
//  LocalIncomeTaxTests.swift
//  RetireSmartIRATests
//
//  Alan feedback (2nd round): the app modeled no local/city income tax (e.g. NYC
//  ~3.88%) — only the itemized SALT *deduction*. `calculateStateTax` now accepts a
//  user-entered `localIncomeTaxRate` applied to the SAME state-taxable base as the
//  state income tax (after retirement exclusions + deductions), folded into the
//  returned state figure. Default rate 0 keeps every existing result byte-identical.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Local/city income tax (Alan 2nd-round feedback)")
struct LocalIncomeTaxTests {

    private func stateTax(_ state: USState, income: Double, localRate: Double,
                          type: IncomeType = .other) -> Double {
        TaxCalculationEngine.calculateStateTax(
            income: income, forState: state, filingStatus: .single,
            taxableSocialSecurity: 0,
            incomeSources: [IncomeSource(name: "Income", type: type, annualAmount: income)],
            currentAge: 70, enableSpouse: false, spouseBirthYear: 1955, currentYear: 2026,
            localIncomeTaxRate: localRate)
    }

    // Isolation: a no-state-income-tax state has $0 state tax, so the whole result is the
    // local term = rate × the (unexcluded) income base.
    @Test("no-income-tax state: local tax is exactly rate × income")
    func localIsolatedInNoIncomeTaxState() {
        #expect(stateTax(.florida, income: 100_000, localRate: 0.0388) == 3_880)
    }

    @Test("localRate 0 leaves state tax byte-identical (default preserved)")
    func zeroRateUnchanged() {
        // Florida: $0 with no local rate.
        #expect(stateTax(.florida, income: 100_000, localRate: 0) == 0)
        // A taxing state: rate 0 equals the no-arg default path.
        let withDefault = TaxCalculationEngine.calculateStateTax(
            income: 120_000, forState: .newYork, filingStatus: .single, taxableSocialSecurity: 0,
            incomeSources: [IncomeSource(name: "Income", type: .other, annualAmount: 120_000)],
            currentAge: 70, enableSpouse: false, spouseBirthYear: 1955, currentYear: 2026)
        let withZero = stateTax(.newYork, income: 120_000, localRate: 0)
        #expect(withDefault == withZero)
    }

    // On a state that DOES tax income, local stacks additively and scales linearly with the
    // rate (base-independent proof it's rate × a fixed base, not tangled into the brackets).
    @Test("taxing state: local stacks on state tax and scales linearly with the rate")
    func localStacksAndScalesLinearly() {
        let base = stateTax(.newYork, income: 150_000, localRate: 0)
        let at3 = stateTax(.newYork, income: 150_000, localRate: 0.03)
        let at6 = stateTax(.newYork, income: 150_000, localRate: 0.06)
        #expect(at3 > base)                                   // local adds to state tax
        #expect(abs((at6 - base) - 2 * (at3 - base)) < 0.01)  // linear in the rate
    }

    // Wiring guard: the rate carried on MultiYearStaticInputs raises the multi-year projection's
    // per-year state tax (adapter → inputs → ProjectionEngine.computeStateTax → calculateStateTax).
    @MainActor
    @Test("multi-year projection applies the inputs' localIncomeTaxRate")
    func multiYearProjectionAppliesLocalRate() {
        func project(localRate: Double) -> Double {
            let inputs = MultiYearStaticInputs(
                startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 300_000, hsa: 0),
                primaryCurrentAge: 66, spouseCurrentAge: nil,
                filingStatus: .single, state: "NY", localIncomeTaxRate: localRate,
                primarySSClaimAge: 70, spouseSSClaimAge: nil,
                primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
                primaryBirthYear: Calendar.current.component(.year, from: Date()) - 66, spouseBirthYear: nil,
                primaryWageIncome: 0, spouseWageIncome: 0,
                primaryPensionIncome: 0, spousePensionIncome: 0,
                acaEnrolled: false, acaHouseholdSize: 1,
                primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
                baselineAnnualExpenses: 0)
            let a = MultiYearAssumptions(
                horizonEndAge: 67, horizonEndAgeSpouse: nil, cpiRate: 0, investmentGrowthRate: 0.06,
                withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
                perYearExpenseOverrides: [:], currentTaxableBalance: 300_000, currentHSABalance: 0)
            let baseYear = Calendar.current.component(.year, from: Date())
            let years = ProjectionEngine().project(
                inputs: inputs, assumptions: a,
                actionsPerYear: [baseYear: [.rothConversion(amount: 100_000)]])
            return years.reduce(0) { $0 + $1.taxBreakdown.state }
        }
        #expect(project(localRate: 0.03) > project(localRate: 0) + 1)
    }
}
