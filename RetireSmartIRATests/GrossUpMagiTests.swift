import Testing
import Foundation
@testable import RetireSmartIRA

/// A3: when the conversion tax is self-funded by a grossed-up traditional withdrawal
/// (.taxableThenGrossUp, ProjectionEngine Step 7), that extra ordinary income (`dW`) must be
/// reflected in (1) the MAGI stored for the 2-year IRMAA lookback (`irmaaMagiByYear`) and
/// (2) the reported `magi`/`irmaaMagi` fields — not just in `agi` (`reportedAGI`).
@Suite("A3 gross-up MAGI feeds IRMAA/NIIT", .serialized)
@MainActor
struct GrossUpMagiTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    // Zero Social Security + no muni/tax-exempt income -> magiAddback == 0, so post-fix
    // `rec.magi` must equal `rec.agi` EXACTLY (both = reportedAGI). Pre-fix, `rec.magi` uses
    // pre-gross-up federalAGI, which is strictly less than reportedAGI whenever gross-up fires.
    private func inputs(trad: Double, taxable: Double, age: Int) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026, primaryCurrentAge: age, spouseCurrentAge: nil, filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 2026 - age, spouseBirthYear: nil, primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0, acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0,
            heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
    }
    private func assumptions(_ src: TaxPaymentSource) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
        a.taxPaymentSource = src; return a
    }

    @Test("gross-up-funded year: reported magi equals reported agi (no SS/muni addback)")
    func magiMatchesAgiWhenGrossUpFires() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 2_000_000, taxable: 0, age: 63), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: 400_000)]])
        // Sanity: gross-up actually fired (an extra traditionalWithdrawal action beyond the conversion).
        let withdrawals = p[0].actions.compactMap { act -> Double? in
            if case let .traditionalWithdrawal(a) = act { return a }; return nil }
        #expect(withdrawals.contains { $0 > 0 })
        #expect(abs(p[0].magi - p[0].agi) < 1.0)
    }

    @Test("gross-up-funded conversion raises IRMAA 2 years later vs an ample-taxable twin")
    func futureIRMAAReflectsGrossUp() {
        let engine = ProjectionEngine(configProvider: provider)
        let actions: [Int: [LeverAction]] = [2026: [.rothConversion(amount: 120_000)], 2027: [], 2028: []]
        let grossUp = engine.project(
            inputs: inputs(trad: 2_000_000, taxable: 0, age: 63), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: actions)
        let ample = engine.project(
            inputs: inputs(trad: 2_000_000, taxable: 2_000_000, age: 63), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: actions)
        #expect(grossUp[2].medicareEnrolledCount == 1)
        #expect(grossUp[2].taxBreakdown.irmaa > ample[2].taxBreakdown.irmaa)
    }

    // A3/NIIT: a gross-up-funded conversion pushes federalAGI well past the pre-gross-up figure.
    // With stated NII sized so pre-gross-up MAGI-excess-over-threshold is LESS than the NII itself
    // (i.e. the pre-gross-up NIIT is not yet capped at the full NII), the post-gross-up MAGI
    // un-caps more (or all) of the stated NII, and the REPORTED niit channel must reflect that —
    // not the stale pre-gross-up figure. Federal-only: state pinned to "TX" (no state tax/NIIT
    // interaction to control for).
    private func niitInputs(nii: Double, trad: Double, taxable: Double, age: Int) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026, primaryCurrentAge: age, spouseCurrentAge: nil, filingStatus: .single, state: "TX",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 2026 - age, spouseBirthYear: nil, primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            primaryNetInvestmentIncome: nii,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0,
            heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
    }

    @Test("gross-up-funded year: reported NIIT reflects post-gross-up MAGI, not the pre-gross-up figure")
    func niitReflectsGrossUp() {
        // Pre-gross-up federalAGI == the conversion amount (no wages/pension/SS/RMD in play).
        // $210k conversion vs the $200k single NIIT threshold leaves only $10k of MAGI-excess,
        // strictly less than the $25k of stated NII -> pre-gross-up NIIT is NOT yet capped at the
        // full NII, so a gross-up that pushes MAGI further past the threshold must raise it.
        let nii = 25_000.0
        let conversion = 210_000.0
        let threshold = 200_000.0

        let p = ProjectionEngine(configProvider: provider).project(
            inputs: niitInputs(nii: nii, trad: 2_000_000, taxable: 0, age: 63),
            assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: conversion)]])
        let rec = p[0]

        // Sanity: gross-up actually fired.
        let withdrawals = rec.actions.compactMap { act -> Double? in
            if case let .traditionalWithdrawal(a) = act { return a }; return nil }
        #expect(withdrawals.contains { $0 > 0 })

        // Pre-gross-up reference NIIT, computed the same way Step 3 of the engine does.
        // Confirm the setup: pre-gross-up MAGI-excess ($10k) is strictly less than NII ($25k),
        // so pre-gross-up NIIT is NOT yet capped at the full 3.8% x NII.
        let preGrossUpExcess = conversion - threshold
        #expect(preGrossUpExcess < nii)
        let preGrossUpNIIT = TaxCalculationEngine.calculateNIIT(
            nii: nii, magi: conversion, filingStatus: .single).annualNIITax
        #expect(abs(preGrossUpNIIT - preGrossUpExcess * 0.038) < 0.01)

        // The reported NIIT must be recomputed on the ACTUAL post-gross-up AGI (rec.agi), and
        // must exceed the pre-gross-up figure since the gross-up strictly increases MAGI.
        let expectedFinal = TaxCalculationEngine.calculateNIIT(
            nii: nii, magi: rec.agi, filingStatus: .single).annualNIITax
        #expect(rec.agi > conversion) // gross-up strictly raised AGI
        #expect(abs(rec.taxBreakdown.niit - expectedFinal) < 0.01)
        #expect(rec.taxBreakdown.niit > preGrossUpNIIT)
    }

    @Test("no-gross-up profile: NIIT is unchanged by the fix (ample taxable cash covers the tax)")
    func niitUnchangedWhenNoGrossUp() {
        let nii = 25_000.0
        let conversion = 210_000.0

        let p = ProjectionEngine(configProvider: provider).project(
            inputs: niitInputs(nii: nii, trad: 2_000_000, taxable: 2_000_000, age: 63),
            assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: conversion)]])
        let rec = p[0]

        // No traditional gross-up withdrawal this year (ample taxable cash covered the tax bill).
        let withdrawals = rec.actions.compactMap { act -> Double? in
            if case let .traditionalWithdrawal(a) = act { return a }; return nil }
        #expect(!withdrawals.contains { $0 > 0 })

        // reportedAGI == federalAGI here, so niitFinal must equal the pre-gross-up formula exactly.
        let expected = TaxCalculationEngine.calculateNIIT(
            nii: nii, magi: rec.agi, filingStatus: .single).annualNIITax
        #expect(abs(rec.taxBreakdown.niit - expected) < 0.01)
    }
}
