//
//  WidowStressTest.swift
//  RetireSmartIRA
//
//  Estimates the lifetime-tax penalty a surviving spouse faces after losing their partner.
//
//  v2.0 simplification: assumes higher SS earner dies on day 1 (not at widowhoodAge).
//  This produces a CONSERVATIVE upper-bound widow-penalty estimate — suitable for the
//  "what if your spouse dies" planning callout. The surviving spouse inherits all account
//  balances and pays single-filer rates from year 0 throughout the projection.
//
//  v2.1 will model a mid-projection filing-status switch at widowhoodAge, which requires
//  a two-segment projection (MFJ up to widow year, single thereafter).
//
//  Algorithm:
//    1. Run baseline (MFJ throughout) → sum taxBreakdown.total = baselineLifetimeTax
//    2. Build widow variant: filingStatus → .single, deceased spouse's SS/wage/pension
//       zeroed out, surviving spouse inherits all balances.
//    3. Run widow on OptimizationEngine → widowLifetimeTax
//    4. Return TaxImpact(baselineLifetimeTax, widowLifetimeTax)
//       where delta = widowLifetimeTax - baselineLifetimeTax (positive = widow pays more)
//
//  Single-filer inputs (no spouse): returns TaxImpact(0, 0) — no widow penalty applies.
//

import Foundation

struct WidowStressTest {

    init() {}

    func run(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions,
        widowhoodAge: Int = 75
    ) -> TaxImpact {
        // Single-filer scenarios: no widow penalty applies
        guard inputs.filingStatus == .marriedFilingJointly,
              inputs.spouseCurrentAge != nil else {
            return TaxImpact(baselineLifetimeTax: 0, scenarioLifetimeTax: 0)
        }

        let engine = OptimizationEngine()

        // Baseline: full MFJ projection
        let baseline = engine.optimize(inputs: inputs, assumptions: assumptions)
        let baselineLifetimeTax = baseline.recommendedPath.reduce(0.0) { $0 + $1.taxBreakdown.total }

        // Widow variant (v2.0 simplification: single-filer from year 0)
        let widowInputs = makeWidowVariant(inputs: inputs)
        let widow = engine.optimize(inputs: widowInputs, assumptions: assumptions)
        let widowLifetimeTax = widow.recommendedPath.reduce(0.0) { $0 + $1.taxBreakdown.total }

        return TaxImpact(
            baselineLifetimeTax: baselineLifetimeTax,
            scenarioLifetimeTax: widowLifetimeTax
        )
    }

    /// Builds a widow variant of MultiYearStaticInputs.
    ///
    /// The deceased spouse is assumed to be the HIGHER SS earner — losing the higher
    /// earner produces the more meaningful (larger) tax penalty.  The surviving spouse
    /// inherits all account balances (standard spousal inheritance assumption).
    ///
    /// v2.0: single-filer rates from year 0.
    /// v2.1 will model widow-from-widowhoodAge with mid-projection filing-status switch.
    private func makeWidowVariant(inputs: MultiYearStaticInputs) -> MultiYearStaticInputs {
        let primaryBenefit = inputs.primaryExpectedBenefitAtFRA
        let spouseBenefit = inputs.spouseExpectedBenefitAtFRA ?? 0

        // Survivor is the lower SS earner; deceased is the higher one.
        let survivorIsPrimary = primaryBenefit < spouseBenefit

        if survivorIsPrimary {
            // Deceased = spouse. Surviving primary keeps own demographics; no spouse fields.
            return MultiYearStaticInputs(
                startingBalances: inputs.startingBalances,  // surviving spouse inherits all
                primaryCurrentAge: inputs.primaryCurrentAge,
                spouseCurrentAge: nil,
                filingStatus: .single,
                state: inputs.state,
                primarySSClaimAge: inputs.primarySSClaimAge,
                spouseSSClaimAge: nil,
                primaryExpectedBenefitAtFRA: inputs.primaryExpectedBenefitAtFRA,
                spouseExpectedBenefitAtFRA: nil,
                primaryBirthYear: inputs.primaryBirthYear,
                spouseBirthYear: nil,
                primaryWageIncome: inputs.primaryWageIncome,
                spouseWageIncome: 0,
                primaryPensionIncome: inputs.primaryPensionIncome,
                spousePensionIncome: 0,
                acaEnrolled: inputs.acaEnrolled,
                acaHouseholdSize: 1,
                primaryMedicareEnrollmentAge: inputs.primaryMedicareEnrollmentAge,
                spouseMedicareEnrollmentAge: nil,
                baselineAnnualExpenses: inputs.baselineAnnualExpenses
            )
        } else {
            // Deceased = primary. Surviving "primary" of widow scenario uses original
            // spouse's demographics (spouse becomes the only person).
            let spouseCurrentAge = inputs.spouseCurrentAge ?? inputs.primaryCurrentAge
            let spouseSSClaimAge = inputs.spouseSSClaimAge ?? 67
            let spouseBirthYear = inputs.spouseBirthYear ?? inputs.primaryBirthYear
            let spouseMedAge = inputs.spouseMedicareEnrollmentAge ?? 65

            return MultiYearStaticInputs(
                startingBalances: inputs.startingBalances,
                primaryCurrentAge: spouseCurrentAge,
                spouseCurrentAge: nil,
                filingStatus: .single,
                state: inputs.state,
                primarySSClaimAge: spouseSSClaimAge,
                spouseSSClaimAge: nil,
                primaryExpectedBenefitAtFRA: spouseBenefit,
                spouseExpectedBenefitAtFRA: nil,
                primaryBirthYear: spouseBirthYear,
                spouseBirthYear: nil,
                primaryWageIncome: inputs.spouseWageIncome,
                spouseWageIncome: 0,
                primaryPensionIncome: inputs.spousePensionIncome,
                spousePensionIncome: 0,
                acaEnrolled: inputs.acaEnrolled,
                acaHouseholdSize: 1,
                primaryMedicareEnrollmentAge: spouseMedAge,
                spouseMedicareEnrollmentAge: nil,
                baselineAnnualExpenses: inputs.baselineAnnualExpenses
            )
        }
    }
}
