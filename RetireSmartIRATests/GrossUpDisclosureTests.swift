import Testing
import Foundation
@testable import RetireSmartIRA

/// A4: the ladder shows "convert $X" but never the ADDITIONAL IRA withdrawal taken to pay the
/// conversion tax when taxable funds are short — hiding the true IRA outflow. This suite pins
/// `YearRecommendation.taxFundingWithdrawal` (the IRA gross-up withdrawal) to the engine's actual
/// Step-7 gross-up amount, and confirms it is 0 when taxable funds the tax bill instead.
@Suite("A4 gross-up disclosure", .serialized)
@MainActor
struct GrossUpDisclosureTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }
    private func inputs(trad: Double, taxable: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 66, spouseCurrentAge: nil, filingStatus: .single, state: "TX",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1960, spouseBirthYear: nil, primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0, acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0,
            heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
    }

    /// Pinned-tax fixture for a zero-conversion year with a real tax bill: age 76 (RMDs active),
    /// large pension, gross-up funding, no conversion actions anywhere. Proves taxFundingWithdrawal
    /// is scoped to the WHOLE year's tax bill (federal + state + IRMAA + ACA + NIIT on
    /// pension/RMD/SS/wages), not conversion tax only — the reviewer's core finding on A4.
    private func noConversionInputs() -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 3_000_000, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 76, spouseCurrentAge: nil, filingStatus: .single, state: "TX",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1950, spouseBirthYear: nil, primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 300_000, spousePensionIncome: 0, acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 400_000,
            heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
    }
    private func assumptions(_ src: TaxPaymentSource) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
        a.taxPaymentSource = src; return a
    }

    @Test("taxFundingWithdrawal equals the gross-up traditional withdrawal when taxable is empty")
    func grossUpFundedYear() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 0), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: 400_000)]])
        let rec = p[0]
        // The gross-up amount is the single traditionalWithdrawal action the engine appends for
        // Step 7 (no RMD fires at age 66, so this is unambiguous — mirrors TaxGrossUpTests).
        let grossUpWithdrawal = rec.actions.compactMap { act -> Double? in
            if case let .traditionalWithdrawal(a) = act { return a }; return nil
        }.reduce(0, +)
        #expect(grossUpWithdrawal > 0)
        #expect(rec.taxFundingWithdrawal == grossUpWithdrawal)
    }

    @Test("taxFundingWithdrawal is 0 when ample taxable funds the tax bill")
    func taxableFundedYear() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 1_000_000), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: 200_000)]])
        #expect(p[0].taxFundingWithdrawal == 0)
    }

    @Test("taxFundingWithdrawal is 0 with no conversion at all")
    func noConversionYear() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 0), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: []])
        #expect(p[0].taxFundingWithdrawal == 0)
    }

    @Test("taxFundingWithdrawal is > 0 in a zero-conversion year with a large pension tax bill — the field funds the WHOLE year's tax, not conversion tax only")
    func grossUpFiresWithZeroConversion() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: noConversionInputs(), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: []])
        let rec = p[0]
        #expect(rec.executedRothConversion == 0)
        #expect(rec.taxFundingWithdrawal > 0)
    }
}
