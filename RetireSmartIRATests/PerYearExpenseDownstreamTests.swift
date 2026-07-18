import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("Per-year expense override — downstream recalculation", .serialized)
struct PerYearExpenseDownstreamTests {
    private func inputs(traditional: Double, taxable: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: traditional, roth: 0, taxable: taxable, hsa: 0),
            primaryCurrentAge: 66, spouseCurrentAge: nil, filingStatus: .single, state: "TX",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 66, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0, primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1, primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 40_000)
    }
    private func assumptions(overrides: [Int: YearOverride]) -> MultiYearAssumptions {
        var a = MultiYearAssumptions()
        a.horizonEndAge = 68; a.cpiRate = 0; a.investmentGrowthRate = 0.05
        a.stressTestEnabled = false; a.perYearOverrides = overrides
        return a
    }
    private var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    @Test("higher expense funded from the traditional IRA raises that year's tax")
    func expenseRaisesTax() {
        // Only-traditional funding: a bigger expense forces a bigger IRA withdrawal → more ordinary tax.
        let inp = inputs(traditional: 1_000_000, taxable: 0)
        func firstYearTax(_ o: [Int: YearOverride]) -> Double {
            ProjectionEngine().project(inputs: inp, assumptions: assumptions(overrides: o), actionsPerYear: [baseYear: []])[0].taxBreakdown.total
        }
        let baseTax = firstYearTax([:])
        let hiTax = firstYearTax([baseYear: YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: 60_000))])
        #expect(hiTax > baseTax + 1)
    }

    @Test("lower expense leaves more in the accounts (downstream balance rises)")
    func lowerExpenseRaisesBalance() {
        let inp = inputs(traditional: 500_000, taxable: 200_000)
        func endTaxable(_ o: [Int: YearOverride]) -> Double {
            ProjectionEngine().project(inputs: inp, assumptions: assumptions(overrides: o), actionsPerYear: [baseYear: []]).last!.endOfYearBalances.taxable
        }
        let base = endTaxable([:])
        let lower = endTaxable([baseYear: YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: -20_000))])
        #expect(lower > base + 1)
    }
}
