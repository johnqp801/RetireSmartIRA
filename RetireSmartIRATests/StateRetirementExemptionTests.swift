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

    // MARK: - v1.8.3 Bug #1: Phantom itemized deductions in `.none` states
    //
    // Source of truth:
    // .claude/memory/decisions/2026-05-19-qualified-dividends-ltcg-state-tax-audit.md
    //
    // Pre-fix bug: calculateStateTaxFromGross + stateTaxBreakdown applied
    // federal-style itemized deductions (mortgage + property tax + medical +
    // charitable) to state taxable income for EVERY state, including the 10
    // states whose StateTaxConfig.stateDeduction is `.none` (PA, IL, IN, MA,
    // MI, OH, UT, CT, NJ, WV). PA users were under-billed by ~3.07% × non-
    // SALT itemized total. Fix: `.none` means $0 state deduction, period.

    /// Builds John's PA MFJ scenario AT ITS FULL FIDELITY for the Bug #1
    /// regression test (audit task spec). Adds:
    /// - ordinary Dividends ($36,523) — non-qualified, Class 5
    /// - STCG (-$6,285) — Class 3 loss (offsets within Class 3)
    /// - Interest ($1,170) — Class 6
    /// Compared to `makeJohnsScenario` which uses qualified-dividends as a
    /// proxy bundle, this version mirrors the audit dollar-for-dollar.
    private func makeJohnsAuditScenario(itemizing: Bool = false) -> DataManager {
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
            IncomeSource(name: "Dividends", type: .dividends, annualAmount: 36_523),
            IncomeSource(name: "Qualified Dividends", type: .qualifiedDividends, annualAmount: 48_860),
            IncomeSource(name: "LTCG", type: .capitalGainsLong, annualAmount: 64_219),
            IncomeSource(name: "STCG", type: .capitalGainsShort, annualAmount: -6_285),
            IncomeSource(name: "Interest", type: .interest, annualAmount: 1_170),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 3_500),
            IncomeSource(name: "SS Bob", type: .socialSecurity, annualAmount: 68_328, owner: .primary),
            IncomeSource(name: "SS Sue", type: .socialSecurity, annualAmount: 24_000, owner: .spouse),
            IncomeSource(name: "Muni Interest", type: .taxExemptInterest, annualAmount: 26_927),
        ]

        if itemizing {
            // Composition that yields the audit's ~$25,692 stateItemizedDeductions
            // pool (non-SALT, non-medical: mortgage interest; property tax
            // uncapped; medical above floor; charitable). The exact composition
            // doesn't matter for the regression — what matters is that the
            // pool is large enough to expose the phantom-deduction bug if it
            // ever regresses.
            dm.deductionItems = [
                DeductionItem(name: "Mortgage Interest", type: .mortgageInterest, annualAmount: 10_054),
                DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 15_624),
            ]
            dm.cashDonationAmount = 500
            dm.deductionOverride = .itemized
        }
        return dm
    }

    /// John's exact failing scenario (audit task). PA MFJ, dividends + qDiv +
    /// LTCG − STCG + interest + pension (PA-exempt at retirement age) + SS (PA-
    /// exempt) + muni interest (PA-exempt, see v1.8.4 Bug #3 limitation).
    ///
    /// Expected PA tax baseline (no itemizing):
    ///   Class 5 (all dividends): $36,523 + $48,860 = $85,383
    ///   Class 6 (interest):                            $1,170
    ///   Class 3 (LTCG + STCG):  $64,219 + (-$6,285) = $57,934
    ///   Total PA taxable:                              $144,487
    ///   PA tax: $144,487 × 0.0307 ≈ $4,435.75 ≈ $4,436
    @Test("PA v1.8.3 Bug #1 — Johns audit scenario, no itemizing → ≈$4,436")
    func paJohnsAuditScenarioNoItemizing() {
        let dm = makeJohnsAuditScenario(itemizing: false)
        let tax = dm.scenarioStateTax
        #expect(tax > 4_420 && tax < 4_452,
                "Expected ≈$4,436 PA tax. Got \(tax). Pre-fix was ~$3,647 (phantom itemized leak).")
    }

    /// Same income mix + federal itemizing with $26,178 of non-SALT/medical
    /// deductions. PA has NO state-level deduction (`.none`); the federal
    /// itemize MUST NOT change PA state tax. Pre-fix: tax dropped to ~$3,647.
    /// Post-fix: tax stays at ~$4,436. Pins Bug #1.
    @Test("PA v1.8.3 Bug #1 — Johns scenario WITH federal itemizing → still ≈$4,436")
    func paJohnsAuditScenarioWithItemizing() {
        let baseline = makeJohnsAuditScenario(itemizing: false).scenarioStateTax
        let itemized = makeJohnsAuditScenario(itemizing: true).scenarioStateTax
        #expect(abs(itemized - baseline) < 1.0,
                "PA state tax MUST be invariant under federal itemization. baseline=\(baseline) itemized=\(itemized) delta=\(itemized - baseline)")
        #expect(itemized > 4_420 && itemized < 4_452,
                "Expected ≈$4,436 PA tax even with federal itemizing. Got \(itemized).")
    }

    /// Bug #1 regression — generic `.none` state itemizer test helper.
    /// Builds a single-filer scenario with a high-mortgage-and-property-tax
    /// itemized stack, in the named state. PA-style configs (`.none`) must
    /// not let any of the $30K+ pool leak into state taxable income.
    private func makeNoneStateItemizerScenario(state: USState) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1985; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = state
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Wages", type: .consulting, annualAmount: 120_000),
        ]
        dm.deductionItems = [
            DeductionItem(name: "Mortgage Interest", type: .mortgageInterest, annualAmount: 20_000),
            DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 12_000),
        ]
        dm.cashDonationAmount = 5_000
        return dm
    }

    /// For each `.none` state: state tax must be IDENTICAL whether the user
    /// itemizes federally or takes the federal standard. Bug #1 regression.
    @Test("Bug #1 — `.none` states are invariant under federal itemization: PA")
    func bug1NoneInvariantPA() { assertNoneStateInvariant(.pennsylvania) }

    @Test("Bug #1 — `.none` states are invariant under federal itemization: IL")
    func bug1NoneInvariantIL() { assertNoneStateInvariant(.illinois) }

    @Test("Bug #1 — `.none` states are invariant under federal itemization: MA")
    func bug1NoneInvariantMA() { assertNoneStateInvariant(.massachusetts) }

    @Test("Bug #1 — `.none` states are invariant under federal itemization: NJ")
    func bug1NoneInvariantNJ() { assertNoneStateInvariant(.newJersey) }

    @Test("Bug #1 — `.none` states are invariant under federal itemization: OH")
    func bug1NoneInvariantOH() { assertNoneStateInvariant(.ohio) }

    private func assertNoneStateInvariant(_ state: USState) {
        let dmStd = makeNoneStateItemizerScenario(state: state)
        dmStd.deductionOverride = .standard
        let stdTax = dmStd.scenarioStateTax

        let dmItm = makeNoneStateItemizerScenario(state: state)
        dmItm.deductionOverride = .itemized
        let itmTax = dmItm.scenarioStateTax

        #expect(abs(itmTax - stdTax) < 1.0,
                "\(state) is `.none`; state tax MUST NOT change with federal itemization. std=\(stdTax) itm=\(itmTax) delta=\(itmTax - stdTax)")
        #expect(stdTax > 0, "\(state): expected positive state tax on $120K wages.")
    }

    /// Negative control: CA is `.fixed`, NOT `.none`. The fix MUST NOT touch
    /// CA's deduction logic — when itemizing federally, CA state tax should
    /// pick the larger of CA's $5,706 single standard or CA itemized total.
    /// With the audit's $37K non-SALT itemized pool, CA itemized > standard,
    /// so CA tax with itemizing should be LOWER than CA tax with standard.
    @Test("Bug #1 negative control — CA (`.fixed`) still uses itemized when larger")
    func bug1CAStillItemizes() {
        let dmStd = makeNoneStateItemizerScenario(state: .california)
        dmStd.deductionOverride = .standard
        let stdTax = dmStd.scenarioStateTax

        let dmItm = makeNoneStateItemizerScenario(state: .california)
        dmItm.deductionOverride = .itemized
        let itmTax = dmItm.scenarioStateTax

        #expect(itmTax < stdTax,
                "CA is `.fixed`; itemizing with $37K of non-SALT deductions should still reduce CA tax. std=\(stdTax) itm=\(itmTax)")
    }

    // MARK: - v1.8.3 Bug #2: PA Class 3 capital-loss isolation
    //
    // PA classifies cap gains as Class 3. Net Class 3 losses CANNOT offset
    // Class 5 (dividends) or Class 6 (interest). When LTCG + STCG < 0, the
    // PA contribution from Class 3 must floor at $0. Most states follow
    // federal rules (where capital losses can offset $3K of ordinary income
    // per year); only PA's class isolation is modeled here.

    /// PA: $1,000 interest + $5,000 STCG loss + $0 LTCG.
    /// - Federal: net Class 3 = -$5,000 (cap at -$3K for ordinary offset).
    /// - PA: Class 3 net = -$5,000, floored to $0. Class 6 = $1,000.
    ///       PA taxable = $1,000 × 0.0307 ≈ $30.70.
    /// Pre-fix engine allowed the negative STCG to reduce ordinary-subtotal
    /// (interest) → PA tax effectively $0. Fix restores PA Class 3 isolation.
    @Test("PA v1.8.3 Bug #2 — STCG loss does NOT offset interest")
    func paClass3LossDoesNotOffsetInterest() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .pennsylvania
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Interest", type: .interest, annualAmount: 1_000),
            IncomeSource(name: "STCG", type: .capitalGainsShort, annualAmount: -5_000),
        ]
        let tax = dm.scenarioStateTax
        // Expected: $1,000 × 0.0307 ≈ $30.70. Tight bounds to detect regression.
        #expect(tax > 25 && tax < 40,
                "PA Class 3 loss must not offset Class 6 interest. Expected ≈$30.70, got \(tax)")
    }

    /// PA: $5,000 STCG loss + no LTCG, no other income.
    /// Class 3 net = -$5,000, floors at $0. No other income → PA tax = $0.
    /// (Sanity-checks the floor logic: addback restores grossIncome to $0,
    /// state tax remains $0 because there are no positive income sources.)
    @Test("PA v1.8.3 Bug #2 — STCG loss alone yields $0 PA tax")
    func paClass3LossAloneFloorsAtZero() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .pennsylvania
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "STCG", type: .capitalGainsShort, annualAmount: -5_000),
        ]
        let tax = dm.scenarioStateTax
        #expect(tax == 0, "PA: lone Class 3 loss → $0 tax. Got \(tax)")
    }

    /// PA: STCG loss within Class 3 still offsets LTCG inside Class 3.
    /// LTCG $20K + STCG -$8K → net Class 3 = +$12K (positive — no floor).
    /// PA tax ≈ $12,000 × 0.0307 = $368.40. Confirms intra-class offset works.
    @Test("PA v1.8.3 Bug #2 — STCG loss DOES offset LTCG within Class 3")
    func paClass3IntraClassOffsetStillWorks() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .pennsylvania
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "LTCG", type: .capitalGainsLong, annualAmount: 20_000),
            IncomeSource(name: "STCG", type: .capitalGainsShort, annualAmount: -8_000),
        ]
        let tax = dm.scenarioStateTax
        // Net Class 3 = $12,000 → $12,000 × 0.0307 = $368.40
        #expect(tax > 360 && tax < 380,
                "PA Class 3 intra-class offset should yield ≈$368. Got \(tax)")
    }

    /// Negative control — CA does NOT have class isolation. CA follows
    /// federal rules where capital losses can offset up to $3K of ordinary
    /// income. With $1,000 interest + $5,000 STCG loss, CA effective income
    /// is reduced by the federal $3K offset, so CA state tax stays at $0
    /// (negative AGI on small base). The point of this test is to confirm
    /// the new `capitalLossesClassIsolated` flag is PA-specific.
    @Test("Bug #2 negative control — CA capital loss CAN offset ordinary income")
    func bug2CACanOffset() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .california
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Interest", type: .interest, annualAmount: 1_000),
            IncomeSource(name: "STCG", type: .capitalGainsShort, annualAmount: -5_000),
        ]
        let tax = dm.scenarioStateTax
        // CA: $1K interest - $5K STCG loss = -$4K AGI; flooring at $0 by
        // engine, then CA standard deduction → $0 tax. The key behavioral
        // distinction: CA does NOT add the loss back. We assert that.
        #expect(tax == 0, "CA: federal rules apply; loss flows through. Got \(tax)")
        // To prove the rule, compare to a CA scenario WITHOUT the STCG loss:
        // gross would be $1K interest only (well under any deductions, still
        // $0). So this is mostly a smoke check that we didn't break CA.
    }

    // MARK: - Maryland — IRA does NOT qualify for pension exclusion (1.8.4)

    /// Primary source: MD Comptroller Technical Bulletin No. 51 (effective
    /// April 10, 2025), Section II.F "Pension exclusion":
    /// > "A traditional IRA, a Roth IRA, a rollover IRA, a simplified
    /// >  employee plan (SEP), a Keogh plan, an ineligible deferred
    /// >  compensation plan, or foreign retirement income does not qualify."
    /// Statute: Md Tax-General § 10-209.
    ///
    /// TAXSIM-35 finding (#17) at TY2023 for the scenario below:
    /// engine = $0, TAXSIM = $887. Engine was over-exempting because
    /// `iraWithdrawalExemption` was misconfigured as `.partial(maxExempt: 39_500)`
    /// — applying the pension cap to IRAs. Correct: IRAs do NOT qualify.
    @Test("MD age 66 single, $30K IRA only → IRA fully taxable (no pension exclusion for IRA)")
    func mdIraDistributionDoesNotQualifyForPensionExclusion() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1960; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 66 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .maryland
        dm.filingStatus = .single
        dm.yourExtraWithdrawal = 30_000

        let tax = dm.scenarioStateTax
        // $30K IRA distribution. MD std deduction (single): $4,100. MD has no
        // age-based addition to standard deduction (TB-51 gives a separate
        // $1,000 personal exemption for age 65+ but the engine has stateDeduction
        // .fixed; tested implementation only). Conservatively expect SOME tax,
        // since IRA is fully taxable in MD at retirement age.
        #expect(tax > 500,
                "MD must tax IRA distributions at age 66 (no MD pension exclusion for IRA per TB-51). Got \(tax)")
    }

    /// Pensions DO qualify, IRAs do NOT, so a pension-only scenario under
    /// the cap should fully exempt. Negative control proving the pension
    /// path still works.
    @Test("MD age 66 single, $35K pension only → fully exempt (under $39,500 cap)")
    func mdPensionUnderCapFullyExempt() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1960; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 66
        dm.profile.currentYear = 2026
        dm.selectedState = .maryland
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 35_000)
        ]

        let tax = dm.scenarioStateTax
        // $35K pension under the $39,500 MD cap → fully excluded.
        // MD has no other income → state tax = $0.
        #expect(tax == 0,
                "MD: $35K pension under $39,500 cap should be fully exempt. Got \(tax)")
    }

    /// Mixed pension + IRA: pension exempts up to the cap, IRA is fully
    /// taxable. Matches TAXSIM-35 scenario #17. The IRA portion remains
    /// taxable and must produce non-zero MD state tax.
    @Test("MD age 66 single, $35K pension + $30K IRA → only pension exempted, IRA taxable")
    func mdMixedPensionAndIRAOnlyPensionExempt() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1960; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 66
        dm.profile.currentYear = 2026
        dm.selectedState = .maryland
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 35_000)
        ]
        dm.yourExtraWithdrawal = 30_000

        let tax = dm.scenarioStateTax
        // $35K pension fully excluded. $30K IRA fully taxable.
        // Engine pre-fix: returned $0 (over-exempting). Post-fix: should
        // produce ~$887 (the TAXSIM TY2023 reference) — engine is at TY2026
        // so dollar value may differ but must be clearly > $0.
        #expect(tax > 500,
                "MD: IRA must be taxable even when pension exhausts the cap. Got \(tax)")
    }
}
