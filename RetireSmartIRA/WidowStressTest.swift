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
//    1. Resolve the baseline (MFJ throughout) optimized path — injected by the coordinator when
//       available, else computed here.
//    2. Build widow variant: filingStatus → .single, deceased spouse's SS/wage/pension
//       zeroed out, surviving spouse inherits all balances; optimize it.
//    3. Return TaxImpact(baselineNominalTax, widowNominalTax), delta = widow − baseline > 0.
//
//  Both figures are the NOMINAL in-horizon tax actually paid (Σ taxBreakdown.total over each
//  scenario's horizon) — the "$X more in lifetime tax" the banner shows. This is deliberately
//  NOT totalObjectiveCost: the objective is growth-discounted and folds in a terminal-liquidation
//  hypothetical, which is right for RANKING plans but wrong as a user-facing tax-paid amount
//  (changed 2026-07-17; the wealth-consistent objective made that mismatch material — the old
//  displayed figure was a discounted objective value labeled as nominal lifetime tax).
//
//  Single-filer inputs (no spouse): returns TaxImpact(0, 0) — no widow penalty applies.
//
//  Performance optimization: accepts an optional baselinePath (injected by
//  MultiYearTaxStrategyEngine) so the baseline optimize() is skipped; nil recomputes it. The
//  baselineObjective parameter is retained for call-site symmetry but no longer read.
//

import Foundation

struct WidowStressTest {

    init() {}

    func run(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions,
        widowhoodAge: Int = 75,
        baselinePath: [YearRecommendation]? = nil,
        baselineObjective: Double? = nil,
        configProvider: TaxYearConfigProvider = .current
    ) -> TaxImpact {
        // Single-filer scenarios: no widow penalty applies
        guard inputs.filingStatus == .marriedFilingJointly,
              inputs.spouseCurrentAge != nil else {
            return TaxImpact(baselineLifetimeTax: 0, scenarioLifetimeTax: 0)
        }

        let engine = OptimizationEngine()

        // The banner reports "$X more in lifetime tax," so both figures are the NOMINAL in-horizon
        // tax actually paid over each scenario's horizon (sum of taxBreakdown.total), NOT the
        // optimizer's growth-discounted `totalObjectiveCost`. The optimizer still RANKS on the
        // objective (which folds in the terminal-liquidation hypothetical and discounts at the
        // growth rate); that quantity is meaningful for choosing a plan but not as a user-facing
        // "lifetime tax paid" dollar amount. `baselineObjective` is retained in the signature for
        // the coordinator's injection path but is no longer the displayed figure.
        _ = baselineObjective

        // Baseline: use the injected optimized path when provided; otherwise compute it.
        let baselinePathResolved: [YearRecommendation]
        if let injectedPath = baselinePath {
            baselinePathResolved = injectedPath
        } else {
            baselinePathResolved = engine.optimize(inputs: inputs, assumptions: assumptions, configProvider: configProvider).recommendedPath
        }

        // Widow variant (v2.0 simplification: single-filer from year 0)
        let widowInputs = makeWidowVariant(inputs: inputs)
        let widowPath = engine.optimize(inputs: widowInputs, assumptions: assumptions, configProvider: configProvider).recommendedPath

        return TaxImpact(
            baselineLifetimeTax: OptimizationEngine.nominalLifetimeTax(baselinePathResolved),
            scenarioLifetimeTax: OptimizationEngine.nominalLifetimeTax(widowPath)
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
    /// Internal (not private) so tests can reconstruct the exact widow scenario the banner reports.
    func makeWidowVariant(inputs: MultiYearStaticInputs) -> MultiYearStaticInputs {
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
                baselineAnnualExpenses: inputs.baselineAnnualExpenses,
                // Survivor keeps any inherited IRAs; their beneficiary schedule is
                // unchanged by the spouse's death.
                inheritedAccounts: inputs.inheritedAccounts
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
                baselineAnnualExpenses: inputs.baselineAnnualExpenses,
                // Survivor keeps any inherited IRAs; their beneficiary schedule is
                // unchanged by the spouse's death.
                inheritedAccounts: inputs.inheritedAccounts
            )
        }
    }
}
