//
//  NYPensionExclusionCombinedCapTests.swift
//  RetireSmartIRATests
//
//  Regression coverage for the NY over-exemption fix: NY Tax Law
//  § 612(c)(3-a) grants ONE combined $20,000 exclusion per qualifying
//  individual (age 59½+) across pension + annuity + IRA distributions.
//
//  Pre-fix, the NY config set BOTH pensionExemption: .partial(20_000) AND
//  iraWithdrawalExemption: .partial(20_000) with NO pensionAndIRAShareSingleCap
//  flag, so the engine's non-shared-cap branch
//  (TaxCalculationEngine applyRetirementExemptions) subtracted up to $20K for
//  pension AND another $20K for IRA separately — up to ~$40K/person. That
//  over-exempted (under-taxed) NY retirees holding BOTH pension and IRA income.
//
//  The fix sets pensionAndIRAShareSingleCap: true on the NY config so pension
//  and IRA route through the combined-cap branch, applying ONE $20K exclusion
//  to the SUMMED pension+IRA income (the same mechanism NJ/CO use).
//
//  Multiplier semantics (verified in StateTaxData.ExemptionLevel.excludedAmount):
//    .partial(maxExempt) returns min(eligibleIncome, maxExempt * perIndividualMultiplier)
//  i.e. the multiplier DOUBLES THE CAP, not the income. For MFJ where both
//  spouses are 59½+, perIndividualMultiplier = 2.0, so the combined exclusion
//  is min(combinedPensionIRA, 20_000 * 2) = min(combined, 40_000).
//
//  These tests exercise the engine entry point directly
//  (calculateStateTax(income:forState:...)) where `income` is already the
//  post-state-deduction NY taxable income before retirement exemptions, so the
//  arithmetic is exact (no NY standard deduction is reapplied inside).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("NY § 612(c)(3-a): one combined $20K pension+IRA exclusion")
struct NYPensionExclusionCombinedCapTests {

    /// NY single progressive bracket tax (TY 2026 tables in StateTaxData).
    /// Mirrors the configured brackets; used to assert exact expected tax.
    private func nySingleTax(_ taxable: Double) -> Double {
        let brackets: [(Double, Double)] = [
            (0, 0.039), (8_500, 0.044), (11_700, 0.0515), (13_900, 0.054),
            (80_650, 0.059), (215_400, 0.0685), (1_077_550, 0.0965),
            (5_000_000, 0.103), (25_000_000, 0.109)
        ]
        var tax = 0.0
        for i in 0..<brackets.count {
            let lower = brackets[i].0
            let upper = i + 1 < brackets.count ? brackets[i + 1].0 : .infinity
            guard taxable > lower else { break }
            tax += (min(taxable, upper) - lower) * brackets[i].1
        }
        return tax
    }

    /// NY MFJ progressive bracket tax (TY 2026 tables in StateTaxData).
    private func nyMarriedTax(_ taxable: Double) -> Double {
        let brackets: [(Double, Double)] = [
            (0, 0.039), (17_150, 0.044), (23_600, 0.0515), (27_900, 0.054),
            (161_550, 0.059), (323_200, 0.0685), (2_155_350, 0.0965),
            (5_000_000, 0.103), (25_000_000, 0.109)
        ]
        var tax = 0.0
        for i in 0..<brackets.count {
            let lower = brackets[i].0
            let upper = i + 1 < brackets.count ? brackets[i + 1].0 : .infinity
            guard taxable > lower else { break }
            tax += (min(taxable, upper) - lower) * brackets[i].1
        }
        return tax
    }

    /// Build a single-filer DataManager at the given age (integer tax-year age),
    /// with an optional pension IncomeSource. IRA income is supplied separately
    /// via the engine's `scenarioRetirementDistributions` parameter.
    private func makeSingle(age: Int, pension: Double) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - age; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .newYork
        dm.filingStatus = .single
        if pension > 0 {
            dm.incomeSources = [IncomeSource(name: "Pension", type: .pension, annualAmount: pension)]
        }
        return dm
    }

    // MARK: - Test 1 — Single filer, unambiguous (the core regression)

    /// Single, age 60, $30K pension + $30K IRA = $60K combined eligible.
    /// NY § 612(c)(3-a): ONE combined $20K exclusion → NY taxable = $40K.
    ///
    /// Pre-fix the engine excluded $20K pension AND $20K IRA = $40K → taxable
    /// $20K (tax $397.50). This test asserts taxable $40K (tax $1,995.00), so it
    /// FAILS on the old engine and PASSES after pensionAndIRAShareSingleCap.
    @Test("Single age 60, $30K pension + $30K IRA → one $20K exclusion (taxable $40K)")
    func singleCombinedCapExcludesOnly20K() {
        let dm = makeSingle(age: 60, pension: 30_000)
        // income = full NY taxable before retirement exemptions = $60K
        // (pension $30K is in `income` AND surfaced via the .pension source;
        //  IRA $30K is in `income` AND supplied as scenarioRetirementDistributions).
        let tax = dm.calculateStateTax(
            income: 60_000,
            forState: .newYork,
            filingStatus: .single,
            scenarioRetirementDistributions: 30_000
        )
        // Correct: 60_000 − min(60_000, 20_000) = 40_000 taxable.
        let expected = nySingleTax(40_000)  // = 1_995.00
        #expect(abs(tax - expected) < 1.0,
                "NY single must exclude ONE combined $20K (taxable $40K, tax \(expected)). Got \(tax)")
        // Guard against the old double-exclusion result (taxable $20K → $397.50).
        #expect(tax > nySingleTax(20_000) + 1.0,
                "NY must NOT apply two separate $20K exclusions ($40K total). Got \(tax)")
    }

    // MARK: - Test 2 — MFJ, both 59½+ (per-individual cap doubling)

    /// MFJ, both age 61 (both 59½+), household $25K pension + $25K IRA = $50K
    /// combined. perIndividualMultiplier = 2.0 doubles the CAP, so the exclusion
    /// is min($50K, $20K × 2) = min($50K, $40K) = $40K → NY taxable = $10K.
    ///
    /// Arithmetic: combined = 25_000 + 25_000 = 50_000;
    ///   exclusion = min(50_000, 20_000 * 2.0) = 40_000;
    ///   taxable   = 50_000 − 40_000 = 10_000.
    ///
    /// Pre-fix the engine over-excluded the full $50K (pension $25K ≤ $40K cap
    /// AND IRA $25K ≤ $40K cap, applied separately) → taxable $0.
    ///
    /// KNOWN LIMITATION: the combined-cap branch sums HOUSEHOLD pension+IRA, so
    /// a concentrated-income MFJ couple (one spouse holding most of the income)
    /// may still slightly over-exempt vs. true per-spouse caps — full per-spouse
    /// dollar attribution is a deferred follow-up.
    @Test("NY MFJ both 59½+: $25K pension + $25K IRA → $40K combined cap (taxable $10K)")
    func mfjBothQualifyDoublesCap() {
        let dm = DataManager(skipPersistence: true)
        var pDob = DateComponents(); pDob.year = 1965; pDob.month = 1; pDob.day = 1  // age 61
        dm.profile.birthDate = Calendar.current.date(from: pDob)!
        var sDob = DateComponents(); sDob.year = 1965; sDob.month = 1; sDob.day = 1  // age 61
        dm.profile.spouseBirthDate = Calendar.current.date(from: sDob)!
        dm.profile.currentYear = 2026
        dm.enableSpouse = true
        dm.selectedState = .newYork
        dm.filingStatus = .marriedFilingJointly
        dm.incomeSources = [IncomeSource(name: "Pension", type: .pension, annualAmount: 25_000)]

        let tax = dm.calculateStateTax(
            income: 50_000,
            forState: .newYork,
            filingStatus: .marriedFilingJointly,
            scenarioRetirementDistributions: 25_000
        )
        let expected = nyMarriedTax(10_000)  // 10_000 * 0.039 = 390.00
        #expect(abs(tax - expected) < 1.0,
                "NY MFJ both 59½+ excludes 2×$20K = $40K combined (taxable $10K, tax \(expected)). Got \(tax)")
        #expect(tax > 1.0,
                "NY must NOT exclude the full $50K — $40K is the doubled cap. Got \(tax)")
    }

    // MARK: - Test 3 — Single, IRA only (unchanged baseline)

    /// Single, age 60, $30K IRA, $0 pension → exclusion $20K, taxable $10K.
    /// Confirms IRA-alone still gets the $20K (the fix doesn't regress the
    /// IRA-only path; the combined branch with pension=0 gives min(30K,20K)=20K).
    @Test("Single age 60, $30K IRA only, no pension → $20K exclusion (taxable $10K)")
    func singleIRAOnlyStillGets20K() {
        let dm = makeSingle(age: 60, pension: 0)
        let tax = dm.calculateStateTax(
            income: 30_000,
            forState: .newYork,
            filingStatus: .single,
            scenarioRetirementDistributions: 30_000
        )
        let expected = nySingleTax(10_000)  // 10_000 → 397.50
        #expect(abs(tax - expected) < 1.0,
                "NY single IRA-only must exclude $20K (taxable $10K, tax \(expected)). Got \(tax)")
    }

    // MARK: - Test 4 — Under age 59½ (age gate)

    /// Single, age 58 (under 59½), $30K pension → exclusion $0 (age gate),
    /// taxable $30K. Confirms the regularExemptionMinAge=59 gate still bites.
    @Test("Single age 58 (<59½), $30K pension → $0 exclusion (taxable $30K)")
    func singleUnder59NoExclusion() {
        let dm = makeSingle(age: 58, pension: 30_000)
        let tax = dm.calculateStateTax(
            income: 30_000,
            forState: .newYork,
            filingStatus: .single,
            scenarioRetirementDistributions: 0
        )
        let expected = nySingleTax(30_000)  // 30_000 → 1_455.00
        #expect(abs(tax - expected) < 1.0,
                "NY single under 59½ gets NO exclusion (taxable $30K, tax \(expected)). Got \(tax)")
    }
}
