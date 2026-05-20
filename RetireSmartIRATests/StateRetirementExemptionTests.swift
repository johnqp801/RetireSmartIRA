//
//  StateRetirementExemptionTests.swift
//  RetireSmartIRATests
//
//  Regression coverage for the 1.8.2 build 41 engine fix: state-level
//  retirement-income exemptions (RetirementIncomeExemptions) are now wired
//  into calculateStateTaxFromGross / scenarioStateTax / stateTaxBreakdown
//  via scenarioRetirementDistributionIncome. Prior to the fix, scenario
//  withdrawals (RMDs from balances, inherited-IRA RMDs, extra withdrawals)
//  flowed into scenarioGrossIncome but never matched the exemption filter,
//  so PA/IL/MS retirement-age users were charged state tax on IRA
//  distributions they should not owe.
//
//  Verified user scenario: PA resident, retirement age, $50K IRA
//  distribution, no W-2 → PA state tax MUST be $0 (PA already taxed the
//  contributions; PA DOR Gross Compensation guide).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("State retirement-income exemption wiring (build 41)")
struct StateRetirementExemptionTests {

    /// Helper: build a DataManager with deterministic plan year + birthYear.
    /// Defaults to single filer, age 65 in tax year 2026, no other income.
    private func makeDM(
        state: USState,
        birthYear: Int = 1961,
        currentYear: Int = 2026,
        filingStatus: FilingStatus = .single,
        extraWithdrawal: Double = 0,
        wageIncome: Double = 0
    ) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        var birthComponents = DateComponents()
        birthComponents.year = birthYear
        birthComponents.month = 1
        birthComponents.day = 1
        dm.profile.birthDate = Calendar.current.date(from: birthComponents)!
        dm.profile.currentYear = currentYear
        dm.selectedState = state
        dm.filingStatus = filingStatus
        if extraWithdrawal > 0 {
            dm.yourExtraWithdrawal = extraWithdrawal
        }
        if wageIncome > 0 {
            dm.incomeSources.append(IncomeSource(
                name: "Wages",
                type: .consulting,
                annualAmount: wageIncome
            ))
        }
        return dm
    }

    // MARK: - Pennsylvania (the user-reported state)

    @Test("PA: retirement-age $50K IRA distribution → $0 state tax (Jonggie's scenario)")
    func paRetirementAgeIRAFullyExempt() {
        let dm = makeDM(state: .pennsylvania, birthYear: 1961, extraWithdrawal: 50_000)
        let tax = dm.scenarioStateTax
        #expect(tax == 0, "PA should fully exempt IRA distributions at retirement age. Got \(tax)")
    }

    @Test("PA: pre-59½ $50K IRA distribution → state tax applies (early withdrawal)")
    func paEarlyWithdrawalNotExempt() {
        // Born 1980 → age 46 in 2026
        let dm = makeDM(state: .pennsylvania, birthYear: 1980, extraWithdrawal: 50_000)
        let tax = dm.scenarioStateTax
        // PA flat 3.07%, no state standard deduction → $50,000 * 0.0307 = $1,535
        #expect(tax > 1_400 && tax < 1_700, "Expected ≈$1,535 PA tax on early withdrawal, got \(tax)")
    }

    @Test("PA: retirement-age IRA + W-2 → state tax only on W-2 portion")
    func paRetirementAgeMixedIncome() {
        let dm = makeDM(state: .pennsylvania, birthYear: 1961, extraWithdrawal: 50_000, wageIncome: 30_000)
        let tax = dm.scenarioStateTax
        // $30,000 * 0.0307 = $921 — the $50K IRA should be exempted
        #expect(tax > 800 && tax < 1_050, "Expected ≈$921 PA tax on $30K wages only, got \(tax)")
    }

    // MARK: - Other .full-exemption states

    @Test("IL: retirement-age $50K IRA distribution → $0 state tax")
    func ilRetirementAgeIRAFullyExempt() {
        let dm = makeDM(state: .illinois, birthYear: 1961, extraWithdrawal: 50_000)
        #expect(dm.scenarioStateTax == 0)
    }

    @Test("MS: retirement-age $50K IRA distribution → $0 state tax")
    func msRetirementAgeIRAFullyExempt() {
        let dm = makeDM(state: .mississippi, birthYear: 1961, extraWithdrawal: 50_000)
        #expect(dm.scenarioStateTax == 0)
    }

    // MARK: - States with NO retirement exemption (CA)

    @Test("CA: retirement-age $50K IRA distribution → state tax applies (no exemption)")
    func caRetirementAgeIRATaxed() {
        let dm = makeDM(state: .california, birthYear: 1961, extraWithdrawal: 50_000)
        let tax = dm.scenarioStateTax
        #expect(tax > 0, "CA has no IRA exemption; retirement-age distributions are taxable. Got \(tax)")
    }

    // MARK: - Georgia (partial exemption at $65K cap)

    @Test("GA: retirement-age $50K IRA distribution → $0 state tax (within $65K cap)")
    func gaRetirementAgeIRAWithinCap() {
        let dm = makeDM(state: .georgia, birthYear: 1961, extraWithdrawal: 50_000)
        let tax = dm.scenarioStateTax
        // Known approximation: GA's real rule is 62+, with separate $35K tier for 62-64.
        // Our flat 59½ gate allows full exemption at age 65 within the $65K cap.
        #expect(tax == 0, "GA partial exemption should cover $50K (under $65K cap). Got \(tax)")
    }

    @Test("GA: retirement-age $80K IRA distribution → state tax on $15K excess")
    func gaRetirementAgeIRAExceedsCap() {
        let dm = makeDM(state: .georgia, birthYear: 1961, extraWithdrawal: 80_000)
        let tax = dm.scenarioStateTax
        // $80K - $65K cap = $15K exemption-eligible amount remains exposed.
        // After GA's $12K single standard deduction → $3K taxable * 5.39% ≈ $162.
        // We bound loosely since the exact computation depends on
        // standard-deduction interaction with the exemption.
        #expect(tax > 0, "GA should still tax the $15K above the $65K cap. Got \(tax)")
        #expect(tax < 1_000, "GA tax should reflect only the excess, not the full $80K. Got \(tax)")
    }

    // MARK: - Age threshold edge cases

    // TODO(post-1.8.2): GA-specific refinement — real rule is 62+ with a
    // separate $35K cap for ages 62-64. Our flat 59½ gate is a known
    // approximation; an under-62 GA retiree currently gets the full $65K cap
    // they don't qualify for in reality. Filed as separate audit task.
    @Test("GA at age 60 (flat 59½ gate): exempted per current approximation")
    func gaAge60FlatGateApproximation() {
        // Born 1966 → age 60 in 2026. Real GA rule denies exemption (needs 62+),
        // but our flat 59½ gate allows it. This test pins current behavior so
        // the GA-specific refinement task can knowingly flip the expectation.
        let dm = makeDM(state: .georgia, birthYear: 1966, extraWithdrawal: 50_000)
        let tax = dm.scenarioStateTax
        #expect(tax == 0, "Current flat 59½ gate exempts GA at age 60 (known approximation). Got \(tax)")
    }

    // MARK: - calculateStateTaxFromGross direct API

    @Test("calculateStateTaxFromGross: PA retirement-age path zeros out IRA distributions")
    func calculateStateTaxFromGrossPAExemptsIRA() {
        let dm = makeDM(state: .pennsylvania, birthYear: 1961)
        let tax = dm.calculateStateTaxFromGross(
            grossIncome: 50_000,
            forState: .pennsylvania,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            scenarioRetirementDistributions: 50_000
        )
        #expect(tax == 0, "PA must exempt scenario retirement distributions at retirement age. Got \(tax)")
    }

    @Test("calculateStateTaxFromGross: PA pre-59½ does NOT exempt")
    func calculateStateTaxFromGrossPAEarlyTaxed() {
        let dm = makeDM(state: .pennsylvania, birthYear: 1980)
        let tax = dm.calculateStateTaxFromGross(
            grossIncome: 50_000,
            forState: .pennsylvania,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            scenarioRetirementDistributions: 50_000
        )
        #expect(tax > 1_400 && tax < 1_700, "Expected ≈$1,535 PA tax. Got \(tax)")
    }

    // MARK: - v1.8.3 PA Comprehensive Fix tests
    //
    // Coverage for PA DOR Ans 274 (Roth conversion exemption) and adjacent gaps.
    // Source of truth: .claude/memory/decisions/2026-05-19-PA-comprehensive-tax-law-and-code-audit.md

    /// Build a DataManager mirroring John's (Jonggie's) failing scenario.
    /// PA MFJ, Bob age 60 (DOB 1966), Sue age 61 (DOB 1964), with the exact
    /// income mix from the bug report. By default no scenario sliders are set.
    private func makeJohnsScenario(
        rothConversion: Double = 0,
        extraWithdrawal: Double = 0
    ) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        var bob = DateComponents(); bob.year = 1966; bob.month = 2; bob.day = 2
        dm.profile.birthDate = Calendar.current.date(from: bob)!
        var sue = DateComponents(); sue.year = 1964; sue.month = 9; sue.day = 2
        dm.profile.spouseBirthDate = Calendar.current.date(from: sue)!
        dm.profile.enableSpouse = true
        dm.profile.currentYear = 2026
        dm.selectedState = .pennsylvania
        dm.filingStatus = .marriedFilingJointly

        dm.incomeSources = [
            IncomeSource(name: "Ordinary Dividends", type: .qualifiedDividends, annualAmount: 36_523),
            IncomeSource(name: "LTCG", type: .capitalGainsLong, annualAmount: 64_219),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 3_500),
            IncomeSource(name: "SS Bob", type: .socialSecurity, annualAmount: 68_328, owner: .primary),
            IncomeSource(name: "SS Sue", type: .socialSecurity, annualAmount: 24_000, owner: .spouse),
            IncomeSource(name: "Muni Interest", type: .taxExemptInterest, annualAmount: 26_927),
        ]

        if rothConversion > 0 {
            dm.yourRothConversion = rothConversion
        }
        if extraWithdrawal > 0 {
            dm.yourExtraWithdrawal = extraWithdrawal
        }

        return dm
    }

    /// Test 1.1 — John's exact failing scenario (no scenario sliders).
    ///
    /// Per PA law: SS exempt, pension exempt, muni interest excluded from PA
    /// gross compensation. Only qDiv ($36,523) + LTCG ($64,219) = $100,742 is
    /// PA-taxable. Expected = $100,742 × 0.0307 ≈ $3,092.79.
    @Test("PA v1.8.3 — Test 1.1: John's scenario, no sliders → ~$3,085 PA tax")
    func paJohnsScenarioBaseline() {
        let dm = makeJohnsScenario()
        let tax = dm.scenarioStateTax
        #expect(tax > 3_050 && tax < 3_120,
                "Expected ≈$3,085 (qDiv+LTCG only at 3.07%); got \(tax). If ~$3,200+ then pension is being TAXED. If ~$3,650+ then SS or muni leakage.")
    }

    /// Test 1.2 — John's scenario + $50K Roth conversion.
    /// PA DOR Ans 274: conversion is NOT taxable in PA. Expected = same as 1.1.
    @Test("PA v1.8.3 — Test 1.2: + $50K Roth conversion → same tax (Ans 274)")
    func paJohnsScenarioPlusRothConversion() {
        let baseline = makeJohnsScenario().scenarioStateTax
        let withConv = makeJohnsScenario(rothConversion: 50_000).scenarioStateTax
        #expect(abs(withConv - baseline) < 1.0,
                "PA Roth conversion must not change state tax. Baseline=\(baseline) withConv=\(withConv) delta=\(withConv - baseline)")
    }

    /// Test 1.3 — PA Roth conversion exemption is NOT age-gated.
    /// Age 50 (single), $50K conversion + $0 other → PA state tax must be $0.
    @Test("PA v1.8.3 — Test 1.3: age 50 + $50K conversion → $0 (no age gate per Ans 274)")
    func paRothConversionNotAgeGated() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1976; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .pennsylvania
        dm.filingStatus = .single
        dm.yourRothConversion = 50_000
        let tax = dm.scenarioStateTax
        #expect(tax == 0,
                "PA must exempt Roth conversion regardless of age (Ans 274). Got \(tax)")
    }

    /// Test 1.4 — Early withdrawal under 59½ is still PA-taxed.
    /// Locks the age gate for *withdrawals* so we don't widen it accidentally.
    @Test("PA v1.8.3 — Test 1.4: age 55 + $40K extra withdrawal → ≈$1,228 (age gate preserved)")
    func paEarlyExtraWithdrawalStillTaxed() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1971; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .pennsylvania
        dm.filingStatus = .single
        dm.yourExtraWithdrawal = 40_000
        let tax = dm.scenarioStateTax
        #expect(tax > 1_150 && tax < 1_300,
                "Expected ≈$1,228 PA tax on $40K early withdrawal. Got \(tax)")
    }

    /// Test 1.5 — IL Roth conversion exemption (no age gate).
    @Test("IL v1.8.3 — Test 1.5: age 50 + $50K Roth conversion → $0 state tax")
    func ilRothConversionExempt() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1976; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .illinois
        dm.filingStatus = .single
        dm.yourRothConversion = 50_000
        let tax = dm.scenarioStateTax
        #expect(tax == 0,
                "IL must exempt Roth conversion regardless of age. Got \(tax)")
    }

    /// Test 1.6 — MS Roth conversion exemption (no age gate).
    @Test("MS v1.8.3 — Test 1.6: age 50 + $50K Roth conversion → $0 state tax")
    func msRothConversionExempt() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1976; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .mississippi
        dm.filingStatus = .single
        dm.yourRothConversion = 50_000
        let tax = dm.scenarioStateTax
        #expect(tax == 0,
                "MS must exempt Roth conversion regardless of age. Got \(tax)")
    }

    /// Test 1.7 — CA taxes Roth conversion (control).
    @Test("CA v1.8.3 — Test 1.7: age 60 + $50K Roth conversion → state tax > $0")
    func caRothConversionStillTaxed() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1966; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .california
        dm.filingStatus = .single
        dm.yourRothConversion = 50_000
        let tax = dm.scenarioStateTax
        #expect(tax > 0,
                "CA taxes Roth conversion. Got \(tax)")
    }

    /// Test 1.8 — PA inherited-IRA RMD for under-59½ beneficiary is exempt.
    /// Modeled as a `.rmd` IncomeSource row (which is the user-entered way to
    /// represent any RMD-type distribution, including inherited). PA exempts
    /// `.rmd` rows unconditionally today, so this test should already pass.
    @Test("PA v1.8.3 — Test 1.8: age 45 + $15K inherited RMD (.rmd row) → $0 PA tax")
    func paInheritedRMDUnderAgeExempt() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1981; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .pennsylvania
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Inherited IRA RMD", type: .rmd, annualAmount: 15_000)
        ]
        let tax = dm.scenarioStateTax
        #expect(tax == 0,
                "PA must exempt inherited-IRA RMD regardless of beneficiary age. Got \(tax)")
    }
}
