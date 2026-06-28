//
//  EngineRoadmapBatchTests.swift
//  RetireSmartIRATests
//
//  Regression tests for the H2/H3/H4 correctness-credibility batch (2026-06 review):
//   - H2: projection base year is injectable (not hardcoded to Date()).
//   - H3: household horizon runs to the LATER of the two spouses' endpoints.
//   - H4: baseline expenses inflate by CPI (consistent with COLA-adjusted SS).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Engine roadmap batch H2/H3/H4 (2026-06 review)", .serialized)
@MainActor
struct EngineRoadmapBatchTests {

    private func makeInputs(
        baseYear: Int = 2026,
        primaryAge: Int = 65,
        spouseAge: Int? = nil,
        traditional: Double = 1_000_000,
        baselineExpenses: Double = 0,
        ssClaimAge: Int = 70
    ) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: traditional, roth: 0, taxable: 0, hsa: 0),
            baseYear: baseYear,
            primaryCurrentAge: primaryAge,
            spouseCurrentAge: spouseAge,
            filingStatus: spouseAge == nil ? .single : .marriedFilingJointly,
            state: "CA",
            primarySSClaimAge: ssClaimAge,
            spouseSSClaimAge: spouseAge == nil ? nil : ssClaimAge,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: spouseAge == nil ? nil : 0,
            primaryBirthYear: baseYear - primaryAge,
            spouseBirthYear: spouseAge == nil ? nil : baseYear - spouseAge!,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: spouseAge == nil ? 1 : 2,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: spouseAge == nil ? nil : 65,
            baselineAnnualExpenses: baselineExpenses
        )
    }

    private func makeAssumptions(cpi: Double = 0.0, horizonEndAge: Int = 95) -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: horizonEndAge,
            horizonEndAgeSpouse: nil,
            cpiRate: cpi,
            investmentGrowthRate: 0.0,
            withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false,
            perYearExpenseOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0
        )
    }

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    // MARK: - H2: base year is injectable

    @Test("H2: optimizer projects from the injected base year, not the calendar year")
    func baseYearIsInjectable() {
        let inputs = makeInputs(baseYear: 2030, primaryAge: 65)
        let result = OptimizationEngine().optimize(
            inputs: inputs, assumptions: makeAssumptions(), configProvider: provider
        )
        #expect(result.recommendedPath.first?.year == 2030,
            "projection should start at the injected baseYear 2030; got \(String(describing: result.recommendedPath.first?.year))")
    }

    // MARK: - H3: household horizon = later of both spouses

    @Test("H3: a younger spouse extends the household horizon")
    func youngerSpouseExtendsHorizon() {
        // Primary 70, spouse 60, horizonEndAge 95. Primary horizon = 25y (→ 26 years incl. base);
        // spouse horizon = 35y (→ 36 years). Household horizon must use the spouse's longer span.
        let inputs = makeInputs(baseYear: 2026, primaryAge: 70, spouseAge: 60)
        let result = OptimizationEngine().optimize(
            inputs: inputs, assumptions: makeAssumptions(horizonEndAge: 95), configProvider: provider
        )
        #expect(result.recommendedPath.count == 36,
            "household horizon should run to the younger spouse's endpoint (36 years); got \(result.recommendedPath.count)")
    }

    @Test("H3: single filer horizon is unchanged (primary endpoint only)")
    func singleFilerHorizonUnchanged() {
        let inputs = makeInputs(baseYear: 2026, primaryAge: 70, spouseAge: nil)
        let result = OptimizationEngine().optimize(
            inputs: inputs, assumptions: makeAssumptions(horizonEndAge: 95), configProvider: provider
        )
        #expect(result.recommendedPath.count == 26,
            "single-filer horizon = 95-70+1 = 26 years; got \(result.recommendedPath.count)")
    }

    // MARK: - H4: expenses inflate by CPI

    @Test("H4: baseline expenses inflate by CPI over the horizon")
    func expensesInflateByCPI() {
        // Single, $50K expenses, 3% CPI, no income before SS at 70, large trad → expenses are
        // funded from the traditional bucket, so AGI tracks the (inflating) expense each year.
        let inputs = makeInputs(primaryAge: 65, traditional: 2_000_000,
                                baselineExpenses: 50_000, ssClaimAge: 70)
        let assumptions = makeAssumptions(cpi: 0.03)
        let path = ProjectionEngine(configProvider: provider).project(
            inputs: inputs, assumptions: assumptions,
            actionsPerYear: Dictionary(uniqueKeysWithValues: (2026...2030).map { ($0, [LeverAction]()) })
        )
        // Year 4 (2030) expenses ≈ 50_000 * 1.03^4 ≈ 56_275, materially above year 0's $50K.
        #expect(path[4].agi > path[0].agi * 1.10,
            "inflated expenses should raise later-year withdrawals/AGI; yr0=\(path[0].agi) yr4=\(path[4].agi)")
    }
}
