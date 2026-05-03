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
//    1. Run baseline (MFJ throughout) → baselineObjective = Result.totalObjectiveCost
//       (or use injected baselineObjective when provided by coordinator — see below)
//    2. Build widow variant: filingStatus → .single, deceased spouse's SS/wage/pension
//       zeroed out, surviving spouse inherits all balances.
//    3. Run widow on OptimizationEngine → widowObjective = Result.totalObjectiveCost
//    4. Return TaxImpact(baselineObjective, widowObjective)
//       where delta = widowObjective - baselineObjective (positive = widow pays more)
//
//  Both objectives include in-horizon tax AND terminal liquidation tax, matching
//  exactly what OptimizationEngine.optimize() minimizes. Using totalObjectiveCost
//  (rather than summing taxBreakdown.total manually) avoids Terminal Tax Illusion
//  regression where wrapper deltas were inconsistent with optimizer ranking.
//
//  Single-filer inputs (no spouse): returns TaxImpact(0, 0) — no widow penalty applies.
//
//  Performance optimization: accepts optional baselinePath and baselineObjective parameters.
//  When both are provided (injected by MultiYearTaxStrategyEngine), the internal baseline
//  computation is skipped. When either is nil, the baseline is computed internally
//  (preserves existing behavior for standalone callers / unit tests).
//

import Foundation

struct WidowStressTest {

    init() {}

    func run(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions,
        widowhoodAge: Int = 75,
        baselinePath: [YearRecommendation]? = nil,
        baselineObjective: Double? = nil
    ) -> TaxImpact {
        // Single-filer scenarios: no widow penalty applies
        guard inputs.filingStatus == .marriedFilingJointly,
              inputs.spouseCurrentAge != nil else {
            return TaxImpact(baselineLifetimeTax: 0, scenarioLifetimeTax: 0)
        }

        let engine = OptimizationEngine()

        // Baseline: use injected path/objective when both provided; otherwise compute.
        let baselineObj: Double
        if let injectedPath = baselinePath, let injectedObj = baselineObjective {
            _ = injectedPath  // path itself isn't used here, only the cost — but keep parameter for symmetry
            baselineObj = injectedObj
        } else {
            let baseline = engine.optimize(inputs: inputs, assumptions: assumptions)
            baselineObj = baseline.totalObjectiveCost
        }

        // Widow variant (v2.0 simplification: single-filer from year 0)
        let widowInputs = makeWidowVariant(inputs: inputs)
        let widow = engine.optimize(inputs: widowInputs, assumptions: assumptions)
        let widowObjective = widow.totalObjectiveCost

        return TaxImpact(
            baselineLifetimeTax: baselineObj,
            scenarioLifetimeTax: widowObjective
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
                // V2.0 SIMPLIFICATION (Gemini review 2026-05-03): surviving spouse inherits
                // the FULL married-couple baseline expenses. Real-world surviving spouses
                // typically spend 20-30% less. Using 100% is conservative — over-states the
                // widow penalty (the optimizer is forced to fund the same lifestyle on a
                // single-filer tax bracket, leading to bracket overruns). Acceptable for v2.0
                // as a "worst case" stress estimate. v2.1 should apply a 0.8 multiplier (or
                // surface the multiplier to the user as a tunable assumption).
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
                // V2.0 SIMPLIFICATION (Gemini review 2026-05-03): surviving spouse inherits
                // the FULL married-couple baseline expenses. Real-world surviving spouses
                // typically spend 20-30% less. Using 100% is conservative — over-states the
                // widow penalty (the optimizer is forced to fund the same lifestyle on a
                // single-filer tax bracket, leading to bracket overruns). Acceptable for v2.0
                // as a "worst case" stress estimate. v2.1 should apply a 0.8 multiplier (or
                // surface the multiplier to the user as a tunable assumption).
                baselineAnnualExpenses: inputs.baselineAnnualExpenses
            )
        }
    }
}
