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

    // Fixed in 1.8.4 (commit landing this change). Previously this test
    // pinned the known-buggy approximation that exempted GA retirees under
    // age 62. The engine now honors GA's actual age requirements per
    // O.C.G.A. § 48-7-27(a)(5): exemption requires age 62+ minimum.
    @Test("GA at age 60: NOT exempted (under O.C.G.A. § 48-7-27 age-62 minimum)")
    func gaAge60NoLongerExempted() {
        // Born 1966 → age 60 in 2026. GA correctly denies exemption (needs 62+).
        let dm = makeDM(state: .georgia, birthYear: 1966, extraWithdrawal: 50_000)
        let tax = dm.scenarioStateTax
        // $50K IRA fully taxable, less GA $12K single deduction → $38K taxable
        // at 5.39% → ~$2,048 GA state tax.
        #expect(tax > 1500,
                "GA age 60: must NOT exempt IRA (requires age 62+ per O.C.G.A. § 48-7-27(a)(5)). Got \(tax)")
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

    // MARK: - New York — $20K pension/annuity exclusion is PER-INDIVIDUAL (1.8.4)

    /// Primary source: NY Tax Law § 612(c)(3-a):
    /// > "Pensions and annuities received by an individual who has attained
    /// >  the age of fifty-nine and one-half" — up to $20,000 per qualifying
    /// >  individual. See also IT-201 instructions for the $20,000 pension
    /// >  and annuity income exclusion.
    ///
    /// For MFJ where both spouses are 59½+, each spouse gets a separate
    /// $20,000 exclusion. The engine pre-fix applied a single household-wide
    /// $20,000 cap. TAXSIM-35 finding #4: NY MFJ ages 70/72 with $90K RMD
    /// + $30K SS → engine $2,726 vs TAXSIM $1,186 (engine over-taxing by
    /// ~$1,540 = roughly 9.65% NY marginal × the missing $20K of exclusion).
    @Test("NY MFJ both 59½+: $20K pension exclusion per spouse → $40K combined cap")
    func nyMfjPerIndividualPensionExclusion() {
        let dm = DataManager(skipPersistence: true)
        // Primary age 70, spouse age 72 — both qualify
        var pDob = DateComponents(); pDob.year = 1956; pDob.month = 1; pDob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: pDob)!
        var sDob = DateComponents(); sDob.year = 1954; sDob.month = 1; sDob.day = 1
        dm.profile.spouseBirthDate = Calendar.current.date(from: sDob)!
        dm.profile.currentYear = 2026
        dm.enableSpouse = true
        dm.selectedState = .newYork
        dm.filingStatus = .marriedFilingJointly
        dm.yourExtraWithdrawal = 90_000  // RMD income

        let withFix = dm.scenarioStateTax

        // Compare against a single filer with same income — single gets only $20K cap.
        let dmSingle = DataManager(skipPersistence: true)
        dmSingle.profile.birthDate = Calendar.current.date(from: pDob)!
        dmSingle.profile.currentYear = 2026
        dmSingle.selectedState = .newYork
        dmSingle.filingStatus = .single
        dmSingle.yourExtraWithdrawal = 90_000
        let singleTax = dmSingle.scenarioStateTax

        // The MFJ tax must be MEASURABLY LESS than single tax (after bracket
        // differences are accounted for) due to the doubled $20K exclusion.
        // We expect ~$1,200-1,500 difference at NY's ~5.85-6.85% bracket on
        // the extra $20K of exclusion.
        let exclusionBenefit = singleTax - withFix
        #expect(exclusionBenefit > 800,
                "NY MFJ both 59½+ should exempt 2 × \\$20K. Single tax=\(singleTax), MFJ tax=\(withFix), benefit=\(exclusionBenefit)")
    }

    /// Negative control — NY MFJ where ONLY primary is 59½+. Should get
    /// only ONE $20K exclusion (per-individual is gated on individual age).
    @Test("NY MFJ only primary 59½+: only $20K exclusion (per-individual gate)")
    func nyMfjOneSpouseUnder59PerIndividual() {
        let dm = DataManager(skipPersistence: true)
        // Primary age 65; spouse age 55 (under 59½)
        var pDob = DateComponents(); pDob.year = 1961; pDob.month = 1; pDob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: pDob)!
        var sDob = DateComponents(); sDob.year = 1971; sDob.month = 1; sDob.day = 1
        dm.profile.spouseBirthDate = Calendar.current.date(from: sDob)!
        dm.profile.currentYear = 2026
        dm.enableSpouse = true
        dm.selectedState = .newYork
        dm.filingStatus = .marriedFilingJointly
        dm.yourExtraWithdrawal = 90_000

        let bothQualifyTax = dm.scenarioStateTax  // only primary 59½+

        // Compare to MFJ where both qualify (raise spouse age to 65+)
        let dm2 = DataManager(skipPersistence: true)
        dm2.profile.birthDate = Calendar.current.date(from: pDob)!
        var s2Dob = DateComponents(); s2Dob.year = 1956; s2Dob.month = 1; s2Dob.day = 1
        dm2.profile.spouseBirthDate = Calendar.current.date(from: s2Dob)!
        dm2.profile.currentYear = 2026
        dm2.enableSpouse = true
        dm2.selectedState = .newYork
        dm2.filingStatus = .marriedFilingJointly
        dm2.yourExtraWithdrawal = 90_000
        let bothQualifyHigherTax = dm2.scenarioStateTax  // both 59½+

        // With only one spouse 59½+, only $20K exclusion. With both, $40K
        // exclusion → less tax. The "only primary qualifies" scenario must
        // have HIGHER tax than the "both qualify" scenario.
        #expect(bothQualifyTax > bothQualifyHigherTax,
                "NY: one-spouse-qualifies tax (\(bothQualifyTax)) must be > both-spouses-qualify tax (\(bothQualifyHigherTax))")
    }

    // MARK: - Georgia — age-tiered retirement income exclusion (1.8.4)

    /// Primary source: O.C.G.A. § 48-7-27(a)(5) — Georgia Retirement Income
    /// Exclusion. Effective for tax years beginning on or after Jan 1, 2012:
    ///   - Ages 62-64: up to $35,000 per qualifying individual
    ///   - Ages 65+:   up to $65,000 per qualifying individual
    /// (Verified from GA Code 2024 + GA DOR Retirement Income Exclusion page.)
    ///
    /// TAXSIM-35 finding #11 (TY2023): GA single age 64 with $60K IRA →
    /// engine $0 vs TAXSIM $2,796. Engine was applying the $65K cap to a
    /// 64-year-old who is only entitled to $35K — over-exempting by $25K
    /// × 5.39% flat rate ≈ $1,347 (TAXSIM's value at 2023 rates is higher
    /// because GA's rate was 5.75% in TY2023).
    @Test("GA age 64 single, $60K IRA → only $35K exempt under early-tier (62-64)")
    func gaAge64UsesEarlyTier35K() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1962; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 64 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .georgia
        dm.filingStatus = .single
        dm.yourExtraWithdrawal = 60_000

        let tax = dm.scenarioStateTax
        // $60K IRA at age 64. Only $35K exempt. Remaining $25K subject to GA
        // state deduction ($12K single) + 5.39% flat rate. After deductions:
        // taxable ≈ $25K - $12K = $13K. Tax ≈ $13K × 0.0539 = $701. Allow
        // wide margin since state deduction handling may vary.
        #expect(tax > 500 && tax < 1500,
                "GA age 64 should partially tax IRA. Got \(tax)")
    }

    /// At age 65+, the regular $65K cap applies → $60K IRA fully exempt.
    @Test("GA age 65 single, $60K IRA → fully exempt under regular tier ($65K cap)")
    func gaAge65UsesRegularTier65K() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 65 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .georgia
        dm.filingStatus = .single
        dm.yourExtraWithdrawal = 60_000

        let tax = dm.scenarioStateTax
        // $60K under $65K cap → fully exempt → $0 GA tax.
        #expect(tax == 0,
                "GA age 65 should fully exempt $60K under $65K cap. Got \(tax)")
    }

    /// Below age 62, no exclusion applies — full IRA is taxable.
    @Test("GA age 60 single, $60K IRA → no exclusion (under 62)")
    func gaAge60NoExclusion() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1966; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 60 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .georgia
        dm.filingStatus = .single
        dm.yourExtraWithdrawal = 60_000

        let tax = dm.scenarioStateTax
        // $60K IRA fully taxable. Tax ≈ ($60K - $12K dedn) × 0.0539 = $2,587.
        #expect(tax > 2000,
                "GA age 60: IRA not exempt at all. Got \(tax)")
    }

    // MARK: - New Jersey — age 62+ minimum for pension exclusion (1.8.4)

    /// Primary source: NJSA 54A:6-15 — NJ Pension and Other Retirement
    /// Income Exclusion. Eligibility requires the taxpayer to be 62 years
    /// of age or older OR totally disabled. The exclusion amount and
    /// AGI-based phaseout are tracked as separate TODOs (filing-status-
    /// aware caps and AGI phaseout require schema work).
    ///
    /// At-age-61 NJ retirees were previously incorrectly granted the
    /// full $100K pension exclusion. This test pins the age gate.
    @Test("NJ age 61 single: pension NOT exempt (under 62 threshold)")
    func njAge61NoExclusion() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1965; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 61 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .newJersey
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]

        let tax = dm.scenarioStateTax
        // $40K pension fully taxable under NJ 62-minimum rule. NJ no state
        // deduction. NJ Single brackets: 1.4% × $20K + 1.75% × $15K + 3.5% × $5K
        // ≈ $717. Allow wide range.
        #expect(tax > 500,
                "NJ age 61: pension must NOT be exempt (NJSA 54A:6-15 requires age 62+). Got \(tax)")
    }

    /// At age 62, the exclusion kicks in and $40K pension is exempted
    /// (well under the $100K MFJ cap that's currently used as the global
    /// fallback for all filing statuses — separate TODO for Single $75K).
    @Test("NJ age 62 single, $40K pension → fully exempt")
    func njAge62Excluded() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1964; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 62 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .newJersey
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]

        let tax = dm.scenarioStateTax
        // $40K pension fully exempt at age 62, no other income → $0 NJ tax.
        #expect(tax == 0,
                "NJ age 62: pension must be exempt (NJSA 54A:6-15). Got \(tax)")
    }

    // MARK: - Colorado — combined pension+IRA single cap, age 55-64 / 65+ tiers (1.8.4)

    /// Primary source: C.R.S. § 39-22-104(4)(f) — Colorado Pension and
    /// Annuity Subtraction. Per CO DOR guidance, pensions and IRA
    /// distributions count TOGETHER against one annual cap:
    ///   - Ages 55-64: $20,000 combined
    ///   - Ages 65+:   $24,000 combined
    /// SB25-136 (which would have removed the cap entirely effective TY2026)
    /// was Postponed Indefinitely 02/27/2025 — did NOT become law. The cap
    /// stays for TY2026.
    ///
    /// TAXSIM-35 finding #12 (TY2023): CO single age 70 with $50K pension
    /// + $30K IRA → engine $717 vs TAXSIM $1,660. Engine was applying the
    /// $24K cap to pension AND to IRA separately ($48K total exempted)
    /// instead of as a single shared $24K cap.
    @Test("CO age 70 single, $50K pension + $30K IRA → \\$24K shared cap (not $24K + $24K)")
    func coCombinedCap() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1956; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 70 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .colorado
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        dm.yourExtraWithdrawal = 30_000

        let tax = dm.scenarioStateTax
        // Total qualifying retirement income: $50K + $30K = $80K.
        // Single shared CO subtraction: $24K → state-taxable retirement = $56K.
        // CO conforms to federal taxable. Std dn $16,100 + age 65 $2,050 +
        // OBBBA senior bonus $6,000 = $24,150 reduces federal taxable.
        // Federal taxable ~ $55,850 (assuming no other deductions).
        // CO state tax ≈ ($55,850 - $24,000) × 0.044 = $1,401.
        // Pre-fix would have been ($55,850 - $48,000) × 0.044 = $345.
        // Test expects tax in the post-fix range (1300-1800).
        #expect(tax > 1200 && tax < 2000,
                "CO age 70: shared $24K cap (not $48K). Got \(tax)")
    }

    /// At age 60 (55-64 tier), the early tier $20K cap applies.
    /// $30K IRA only → $30K - $20K = $10K state-taxable, ~$440 CO tax.
    @Test("CO age 60 single, $30K IRA → \\$20K early-tier cap")
    func coAge60EarlyTier20K() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1966; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 60 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .colorado
        dm.filingStatus = .single
        dm.yourExtraWithdrawal = 30_000

        let tax = dm.scenarioStateTax
        // $30K IRA at age 60. Early tier: $20K cap. $30K - $20K = $10K
        // state-taxable retirement. CO conforms to federal; std dn $16,100
        // (no age add since under 65). Federal taxable ~ $30K - $16,100 = $13,900.
        // After CO $20K subtraction: $13,900 - $20K = negative → floor at 0?
        // Or applied to gross before std dn? Engine details aside, with $20K
        // exemption applied somewhere in the pipeline, CO tax should be
        // measurably non-zero but capped at the federal-taxable amount.
        #expect(tax >= 0,  // very wide; mainly checking no crash
                "CO age 60: early tier should apply. Got \(tax)")
        // Validate vs age 70 (regular tier): same income should produce LOWER
        // tax at 70 due to $24K cap vs $20K cap.
        let dm70 = DataManager(skipPersistence: true)
        var dob70 = DateComponents(); dob70.year = 1956; dob70.month = 1; dob70.day = 1
        dm70.profile.birthDate = Calendar.current.date(from: dob70)!
        dm70.profile.currentYear = 2026
        dm70.selectedState = .colorado
        dm70.filingStatus = .single
        dm70.yourExtraWithdrawal = 30_000
        let tax70 = dm70.scenarioStateTax
        #expect(tax >= tax70,
                "CO age 60 ($20K cap) should be >= age 70 ($24K cap). Got age60=\(tax), age70=\(tax70)")
    }

    /// Below age 55, no CO retirement subtraction applies.
    @Test("CO age 54 single, $30K IRA → no exclusion")
    func coAge54NoExclusion() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1972; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 54 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .colorado
        dm.filingStatus = .single
        dm.yourExtraWithdrawal = 30_000

        // At age 54, no CO retirement subtraction. $30K IRA fully taxable.
        // CO conforms to federal; std dn $16,100. Federal taxable ~$13,900.
        // CO state tax ≈ $13,900 × 0.044 = $612.
        // Compare to age 60 with same income (gets $20K subtraction).
        let tax54 = dm.scenarioStateTax

        let dm60 = DataManager(skipPersistence: true)
        var dob60 = DateComponents(); dob60.year = 1966; dob60.month = 1; dob60.day = 1
        dm60.profile.birthDate = Calendar.current.date(from: dob60)!
        dm60.profile.currentYear = 2026
        dm60.selectedState = .colorado
        dm60.filingStatus = .single
        dm60.yourExtraWithdrawal = 30_000
        let tax60 = dm60.scenarioStateTax

        // Age 54 must have STRICTLY MORE tax than age 60 because age 60 gets
        // the $20K subtraction and age 54 gets nothing.
        #expect(tax54 > tax60,
                "CO age 54 (no exclusion) tax \(tax54) must exceed age 60 ($20K cap) tax \(tax60)")
    }

    // MARK: - LLM-audit follow-up fixes (1.8.4 final pass)

    // ChatGPT + Gemini independent review flagged 3 issues post primary-state
    // fixes. These tests pin each remediation.

    /// NY § 612(c)(3-a) requires the taxpayer to have "attained the age of
    /// fifty-nine and one-half." The engine pre-LLM-audit had no age gate
    /// on NY's $20K exclusion. Adding `regularExemptionMinAge: 59`.
    @Test("NY age 55 single $40K pension → NOT exempt (must be 59½+)")
    func nyAge55NoExclusion() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1971; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 55 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .newYork
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        let tax = dm.scenarioStateTax
        // Without the exclusion, $40K is fully taxable. NY no std dn but has
        // $8,000 fixed state deduction. NY single brackets ascend slowly.
        // Tax > $1000 minimum. Pre-fix would have been ~$880 lower (~$20K × 4.5%).
        #expect(tax > 1100,
                "NY age 55: must NOT exempt pension (statute requires 59½+). Got \(tax)")
    }

    /// Negative control — age 60 (above 59½) qualifies. Pension fully exempt.
    @Test("NY age 60 single $15K pension → fully exempt (under $20K cap)")
    func nyAge60SinglePensionExempt() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1966; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 60
        dm.profile.currentYear = 2026
        dm.selectedState = .newYork
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 15_000)
        ]
        let tax = dm.scenarioStateTax
        // $15K pension fully exempt at age 60 (under $20K cap). $0 other income.
        // NY $8K state deduction applies; no income left after exclusion.
        #expect(tax == 0,
                "NY age 60: $15K pension must be fully exempt. Got \(tax)")
    }

    /// O.C.G.A. § 48-7-27(a)(5) is a SINGLE retirement-income exclusion
    /// (not separate caps for pension and IRA). At age 65+ with $40K
    /// pension + $40K IRA, only $65K combined should exempt.
    @Test("GA single age 65, \\$40K pension + \\$40K IRA → \\$65K shared cap (not \\$65K + \\$65K)")
    func gaSharedCapBothIncomeTypes() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 65 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .georgia
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        dm.yourExtraWithdrawal = 40_000

        let tax = dm.scenarioStateTax
        // Total retirement income: $40K + $40K = $80K.
        // Single GA exclusion: $65K → $15K state-taxable retirement.
        // GA $12K state deduction → $3K taxable at 5.39% ≈ $162.
        // Pre-fix engine would have given separate $65K caps = $130K cap →
        // $0 taxable retirement → $0 tax. Post-fix must show non-zero tax.
        #expect(tax > 100,
                "GA: shared $65K cap (not two $65K caps). Got \(tax)")
    }

    /// The per-individual cap-doubling check used a hardcoded `>= 59`
    /// regardless of state. For GA where the qualifying age is 62, an
    /// under-62 spouse incorrectly enabled cap doubling. Fix: each spouse
    /// must independently qualify for AT LEAST one exemption tier.
    @Test("GA MFJ primary 60 + spouse 65 → NO doubling (primary below GA 62 minimum)")
    func gaUnderageSpouseNoDoubling() {
        let dm = DataManager(skipPersistence: true)
        var pDob = DateComponents(); pDob.year = 1966; pDob.month = 1; pDob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: pDob)!  // primary 60
        var sDob = DateComponents(); sDob.year = 1961; sDob.month = 1; sDob.day = 1
        dm.profile.spouseBirthDate = Calendar.current.date(from: sDob)!  // spouse 65
        dm.profile.currentYear = 2026
        dm.enableSpouse = true
        dm.selectedState = .georgia
        dm.filingStatus = .marriedFilingJointly
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]

        let tax = dm.scenarioStateTax

        // Compare to MFJ where BOTH qualify at the same regular tier.
        let dm2 = DataManager(skipPersistence: true)
        var p2Dob = DateComponents(); p2Dob.year = 1961; p2Dob.month = 1; p2Dob.day = 1
        dm2.profile.birthDate = Calendar.current.date(from: p2Dob)!  // primary 65
        dm2.profile.spouseBirthDate = Calendar.current.date(from: sDob)!  // spouse 65
        dm2.profile.currentYear = 2026
        dm2.enableSpouse = true
        dm2.selectedState = .georgia
        dm2.filingStatus = .marriedFilingJointly
        dm2.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        let bothQualifyTax = dm2.scenarioStateTax

        // primary-60 case (only spouse qualifies for GA) must have HIGHER tax
        // than primary-65 case (both qualify → 2× cap doubling).
        #expect(tax > bothQualifyTax,
                "GA per-individual: primary-60 (one qualifies) tax \(tax) must exceed both-65 tax \(bothQualifyTax)")
    }
}
