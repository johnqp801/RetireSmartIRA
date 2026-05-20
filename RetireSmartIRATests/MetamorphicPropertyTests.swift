//
//  MetamorphicPropertyTests.swift
//  RetireSmartIRATests
//
//  Metamorphic property-based tests for the tax engine.
//
//  Background:
//  -----------
//  v1.8.2 and v1.8.3 both shipped the same PA state-tax bug (Jonggie F., PA
//  retiree). The existing 951-test example-based suite passed, because every
//  hand-picked fixture happened to miss the cross-view code path. Metamorphic
//  testing asserts *invariants* that must hold over large swaths of the input
//  space — e.g. "doubling income roughly doubles federal tax above the standard
//  deduction" or "MFJ tax ≤ Single tax at the same total income". A property
//  violation surfaces whole bug classes that point-fixtures cannot.
//
//  This is the technique used by Tizpaz-Niari et al. (ICSE-SEIS 2023) when they
//  audited TurboTax / H&R Block / TaxAct / TaxSlayer.
//
//  These tests are READ-ONLY against the engine — if a property fails, the
//  failure is reported as an engine finding; we do NOT silently change the
//  engine to make a property pass.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("Metamorphic property tests (1.8.4)")
struct MetamorphicPropertyTests {

    // MARK: - Test fixture helpers

    /// Single filer, age 65, resident of a no-income-tax state (Texas).
    /// Used for federal-only invariants — keeps state-tax noise out.
    private func makeSingleAge65NoStateTax(extraWithdrawal: Double = 0,
                                           rothConversion: Double = 0) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 65 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .texas
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.yourExtraWithdrawal = extraWithdrawal
        dm.yourRothConversion = rothConversion
        return dm
    }

    /// MFJ filer (primary age 65 + spouse age 65), TX (no state tax).
    private func makeMFJAge65NoStateTax(extraWithdrawal: Double = 0) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.spouseBirthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .texas
        dm.enableSpouse = true
        dm.filingStatus = .marriedFilingJointly
        dm.yourExtraWithdrawal = extraWithdrawal
        return dm
    }

    /// Single filer at an arbitrary age in `state`.
    private func makeSingle(state: USState,
                            age: Int,
                            extraWithdrawal: Double = 0,
                            rothConversion: Double = 0,
                            wages: Double = 0) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        let birthYear = 2026 - age
        var dob = DateComponents(); dob.year = birthYear; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = state
        dm.enableSpouse = false
        dm.filingStatus = .single
        dm.yourExtraWithdrawal = extraWithdrawal
        dm.yourRothConversion = rothConversion
        if wages > 0 {
            dm.incomeSources.append(
                IncomeSource(name: "Wages", type: .consulting, annualAmount: wages, owner: .primary)
            )
        }
        return dm
    }

    // MARK: - Federal tax — monotonicity & shape

    /// Property 1: Federal tax is non-decreasing in gross income.
    @Test("P1: Federal tax non-decreasing as extra withdrawal grows")
    func p1_federalTaxNonDecreasingInIncome() {
        let amounts: [Double] = [0, 20_000, 50_000, 100_000, 200_000, 500_000]
        var prevTax: Double = -1
        var prevAmt: Double = -1
        for amt in amounts {
            let dm = makeSingleAge65NoStateTax(extraWithdrawal: amt)
            let tax = dm.scenarioFederalTax
            #expect(tax >= prevTax,
                    "Federal tax must be non-decreasing. extraWithdrawal=\(amt) tax=\(tax) but prev (\(prevAmt))=\(prevTax)")
            prevTax = tax
            prevAmt = amt
        }
    }

    /// Property 2: Federal tax = 0 at zero income.
    @Test("P2: Federal tax is $0 at zero income (Single age 65)")
    func p2_zeroFederalAtZeroIncome() {
        let dm = makeSingleAge65NoStateTax()
        #expect(dm.scenarioFederalTax == 0,
                "Expected $0 federal tax at zero income. Got \(dm.scenarioFederalTax)")
    }

    /// Property 3: Doubling income roughly doubles federal liability (above std deduction).
    /// At $100K vs $200K, the ratio should be between 1.5× and 2.5× — wide
    /// enough to accommodate bracket creep but narrow enough to catch
    /// catastrophic mismatches.
    @Test("P3: Doubling income roughly doubles federal tax (1.5x–2.5x)")
    func p3_doublingIncomeRoughlyDoublesFederal() {
        let dmLow = makeSingleAge65NoStateTax(extraWithdrawal: 100_000)
        let dmHigh = makeSingleAge65NoStateTax(extraWithdrawal: 200_000)
        let lo = dmLow.scenarioFederalTax
        let hi = dmHigh.scenarioFederalTax
        guard lo > 0 else {
            Issue.record("P3 precondition: federal tax at $100K must be > 0. Got \(lo).")
            return
        }
        let ratio = hi / lo
        #expect(ratio >= 1.5 && ratio <= 2.5,
                "Doubling income $100K→$200K: expected fed tax ratio in [1.5, 2.5]. Got \(ratio) (lo=\(lo) hi=\(hi))")
    }

    /// Property 4: Adding $1K never DECREASES federal tax (fine-grain monotonicity).
    @Test("P4: $1K increments never decrease federal tax (50K → 60K sweep)")
    func p4_fineGrainMonotonicity() {
        var prev: Double = -1
        var prevAmt: Double = -1
        for amt in stride(from: 50_000.0, through: 60_000.0, by: 1_000.0) {
            let dm = makeSingleAge65NoStateTax(extraWithdrawal: amt)
            let tax = dm.scenarioFederalTax
            #expect(tax >= prev,
                    "Fed tax must not decrease as income grows $1K at a time. At \(amt): tax=\(tax), prev (at \(prevAmt))=\(prev)")
            prev = tax
            prevAmt = amt
        }
    }

    // MARK: - Filing status invariants

    /// Property 5: MFJ federal tax ≤ 2× Single federal tax at same per-person income.
    /// (If each spouse earned $X individually, filing jointly is no worse than
    /// filing as two single people.)
    @Test("P5: MFJ at $X total ≤ 2× Single at $X (joint brackets are wider)",
          arguments: [50_000.0, 100_000.0, 200_000.0, 500_000.0])
    func p5_mfjLeqTwiceSinglePerPerson(amount: Double) {
        let dmSingle = makeSingleAge65NoStateTax(extraWithdrawal: amount)
        let dmMFJ = makeMFJAge65NoStateTax(extraWithdrawal: amount)
        let singleTax = dmSingle.scenarioFederalTax
        let mfjTax = dmMFJ.scenarioFederalTax
        #expect(mfjTax <= 2 * singleTax + 1.0,
                "MFJ at $\(amount) should be ≤ 2× Single at $\(amount). single=\(singleTax) mfj=\(mfjTax)")
    }

    /// Property 6: MFJ ≤ Single at the SAME total household income (MFJ brackets
    /// are wider, so jointly is more favorable for a single-earner household).
    /// Verified by hand at $100K, 2026 brackets:
    ///   Single age 65 std dedn ≈ $17,000 → taxable $83K → tax ≈ $13.4K
    ///   MFJ both age 65 std dedn ≈ $34,800 → taxable $65.2K → tax ≈ $7.2K
    /// So MFJ ≤ Single must hold.
    @Test("P6: MFJ federal tax ≤ Single federal tax at SAME total income",
          arguments: [50_000.0, 100_000.0, 200_000.0, 500_000.0])
    func p6_mfjLeqSingleSameTotalIncome(amount: Double) {
        let dmSingle = makeSingleAge65NoStateTax(extraWithdrawal: amount)
        let dmMFJ = makeMFJAge65NoStateTax(extraWithdrawal: amount)
        let singleTax = dmSingle.scenarioFederalTax
        let mfjTax = dmMFJ.scenarioFederalTax
        #expect(mfjTax <= singleTax + 1.0,
                "At same total income $\(amount), MFJ tax should be ≤ Single tax (wider joint brackets). single=\(singleTax) mfj=\(mfjTax)")
    }

    // MARK: - State tax — PA-specific invariants

    /// Property 7: PA retirement-age IRA distribution → $0 state tax.
    @Test("P7: PA, age 65, $50K extra withdrawal, $0 wages → $0 PA tax")
    func p7_paRetirementAgeWithdrawalExempt() {
        let dm = makeSingle(state: .pennsylvania, age: 65, extraWithdrawal: 50_000)
        #expect(dm.scenarioStateTax == 0,
                "PA retirement-age IRA distribution must be state-exempt. Got \(dm.scenarioStateTax)")
    }

    /// Property 8: PA Roth conversion at any age → $0 state tax (DOR Ans 274,
    /// no age gate on the conversion itself).
    @Test("P8: PA Roth conversion is state-exempt at any age",
          arguments: [45, 55, 65, 75])
    func p8_paRothConversionExemptAtAnyAge(age: Int) {
        let dm = makeSingle(state: .pennsylvania, age: age, rothConversion: 50_000)
        #expect(dm.scenarioStateTax == 0,
                "PA Roth conversion at age \(age) must be state-exempt (Ans 274). Got \(dm.scenarioStateTax)")
    }

    /// Property 9: PA wages ARE taxed at 3.07%.
    @Test("P9: PA, age 65, $50K wages, no retirement income → state tax > $0 (≈ 3.07%)")
    func p9_paWagesTaxed() {
        let dm = makeSingle(state: .pennsylvania, age: 65, wages: 50_000)
        let tax = dm.scenarioStateTax
        #expect(tax > 0,
                "PA wages must be taxed. Got \(tax)")
        let expected = 50_000 * 0.0307
        #expect(abs(tax - expected) < 50.0,
                "PA wages tax should be ≈ 3.07% × $50K = \(expected). Got \(tax)")
    }

    /// Property 10: PA young (pre-59½) IRA withdrawal IS taxed (no exemption).
    @Test("P10: PA, age 50, $50K extra withdrawal → state tax > $0")
    func p10_paYoungWithdrawalTaxed() {
        let dm = makeSingle(state: .pennsylvania, age: 50, extraWithdrawal: 50_000)
        #expect(dm.scenarioStateTax > 0,
                "PA pre-retirement IRA withdrawal must be taxed. Got \(dm.scenarioStateTax)")
    }

    /// Property 11: PA state tax monotonic in wages.
    @Test("P11: PA state tax non-decreasing as wages grow")
    func p11_paStateTaxMonotonicInWages() {
        let amounts: [Double] = [0, 25_000, 50_000, 100_000]
        var prev: Double = -1
        var prevAmt: Double = -1
        for amt in amounts {
            let dm = makeSingle(state: .pennsylvania, age: 65, wages: amt)
            let tax = dm.scenarioStateTax
            #expect(tax >= prev,
                    "PA state tax must be non-decreasing in wages. wages=\(amt) tax=\(tax) prev (\(prevAmt))=\(prev)")
            prev = tax
            prevAmt = amt
        }
    }

    // MARK: - State tax — cross-state structural invariants

    /// Property 12: All 9 no-income-tax states return $0 for any pure-income scenario.
    @Test("P12: No-income-tax states return $0 state tax",
          arguments: [USState.texas, .florida, .nevada, .washington,
                      .southDakota, .wyoming, .alaska, .tennessee, .newHampshire])
    func p12_noIncomeTaxStates(state: USState) {
        let dm = makeSingle(state: state, age: 65, extraWithdrawal: 100_000)
        #expect(dm.scenarioStateTax == 0,
                "\(state.rawValue) has no state income tax; expected $0. Got \(dm.scenarioStateTax)")
    }

    /// Property 13: IL retirement-age IRA distribution → $0 state tax.
    @Test("P13: IL retirement-age IRA distribution → $0 state tax")
    func p13_ilRetirementExempt() {
        let dm = makeSingle(state: .illinois, age: 65, extraWithdrawal: 100_000)
        #expect(dm.scenarioStateTax == 0,
                "IL exempts retirement income. Got \(dm.scenarioStateTax)")
    }

    /// Property 14: MS retirement-age IRA distribution → $0 state tax.
    @Test("P14: MS retirement-age IRA distribution → $0 state tax")
    func p14_msRetirementExempt() {
        let dm = makeSingle(state: .mississippi, age: 65, extraWithdrawal: 100_000)
        #expect(dm.scenarioStateTax == 0,
                "MS exempts retirement income. Got \(dm.scenarioStateTax)")
    }

    /// Property 15: CA does NOT exempt retirement income → state tax > $0.
    @Test("P15: CA retirement-age IRA distribution → state tax > $0")
    func p15_caRetirementTaxed() {
        let dm = makeSingle(state: .california, age: 65, extraWithdrawal: 100_000)
        #expect(dm.scenarioStateTax > 0,
                "CA does not exempt retirement income. Got \(dm.scenarioStateTax)")
    }

    // MARK: - Engine plumbing invariants (cross-view audit lock-in)

    /// (State, extraWithdrawal, rothConversion) parameter triples for #16/#17.
    /// 5 states × 3 scenarios = 15 combinations each.
    static let crossViewMatrix: [(USState, Double, Double)] = {
        let states: [USState] = [.pennsylvania, .illinois, .newYork, .california, .georgia]
        let scenarios: [(Double, Double)] = [
            (0, 50_000),         // pure conversion
            (50_000, 0),         // pure withdrawal
            (37_000, 69_000),    // Jonggie-style mixed
        ]
        return states.flatMap { s in scenarios.map { (s, $0.0, $0.1) } }
    }()

    /// Property 16: scenarioStateTax == calculateStateTaxFromGross(... full args).
    @Test("P16: scenarioStateTax matches calculateStateTaxFromGross across states/scenarios",
          arguments: crossViewMatrix)
    func p16_stateTaxMatchesGrossHelper(state: USState, extraWithdrawal: Double, rothConversion: Double) {
        let dm = makeSingle(state: state, age: 65,
                            extraWithdrawal: extraWithdrawal,
                            rothConversion: rothConversion)
        let scenarioTax = dm.scenarioStateTax
        let listTax = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome,
            forState: state,
            filingStatus: dm.filingStatus,
            taxableSocialSecurity: dm.scenarioTaxableSocialSecurity,
            hsaContributionsAddedBack: dm.scenario.scenarioTotalHSA,
            traditionalIRAContributionsSubtracted: dm.scenario.scenarioTotalTraditionalIRA,
            otherPreTaxDeductionsSubtracted: dm.scenario.scenarioTotalOtherPreTaxDeductions,
            pretax401kContributionsAddedBack: dm.scenario.scenarioTotalTraditional401k,
            scenarioRetirementDistributions: dm.scenarioRetirementDistributionIncome,
            scenarioRothConversionAmount: dm.scenarioTotalRothConversion
        )
        #expect(abs(scenarioTax - listTax) < 1.0,
                "\(state.rawValue) extraW=\(extraWithdrawal) conv=\(rothConversion): scenarioStateTax=\(scenarioTax) listTax=\(listTax)")
    }

    /// Property 17: stateTaxBreakdown.totalStateTax == scenarioStateTax.
    @Test("P17: stateTaxBreakdown.totalStateTax matches scenarioStateTax",
          arguments: crossViewMatrix)
    func p17_breakdownMatchesScenarioStateTax(state: USState, extraWithdrawal: Double, rothConversion: Double) {
        let dm = makeSingle(state: state, age: 65,
                            extraWithdrawal: extraWithdrawal,
                            rothConversion: rothConversion)
        let breakdown = dm.stateTaxBreakdown(forState: state, filingStatus: dm.filingStatus)
        #expect(abs(breakdown.totalStateTax - dm.scenarioStateTax) < 1.0,
                "\(state.rawValue) extraW=\(extraWithdrawal) conv=\(rothConversion): breakdown=\(breakdown.totalStateTax) scenarioStateTax=\(dm.scenarioStateTax)")
    }

    // MARK: - Roth conversion math

    /// Property 18: Adding a Roth conversion never DECREASES federal tax.
    @Test("P18: Federal tax non-decreasing as Roth conversion grows")
    func p18_rothConversionNonDecreasingFederal() {
        let conversions: [Double] = [0, 10_000, 25_000, 50_000]
        var prev: Double = -1
        var prevConv: Double = -1
        for conv in conversions {
            let dm = makeSingleAge65NoStateTax(extraWithdrawal: 50_000, rothConversion: conv)
            let tax = dm.scenarioFederalTax
            #expect(tax >= prev,
                    "Adding Roth conversion must not reduce federal tax. conv=\(conv) tax=\(tax) prev (\(prevConv))=\(prev)")
            prev = tax
            prevConv = conv
        }
    }

    /// Property 19: At conversion = $0, conversion-aware fed tax == non-conversion fed tax.
    @Test("P19: Roth conversion=0 produces identical federal tax to no conversion")
    func p19_zeroConversionIdempotent() {
        let dmZero = makeSingleAge65NoStateTax(extraWithdrawal: 50_000, rothConversion: 0)
        let dmAbsent = makeSingleAge65NoStateTax(extraWithdrawal: 50_000)
        #expect(abs(dmZero.scenarioFederalTax - dmAbsent.scenarioFederalTax) < 0.01,
                "rothConversion=0 must equal no-conversion. zero=\(dmZero.scenarioFederalTax) absent=\(dmAbsent.scenarioFederalTax)")
    }

    // MARK: - Social Security taxation

    /// Property 20: At very low non-SS income, SS is not taxable (IRS combined
    /// income below $25K threshold for Single).
    @Test("P20: Single age 67, $20K SS, $0 other income → taxable SS = $0")
    func p20_lowIncomeSSNotTaxable() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1959; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 67 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .texas
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.incomeSources.append(
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 20_000, owner: .primary)
        )
        let taxableSS = dm.scenarioTaxableSocialSecurity
        #expect(taxableSS == 0,
                "Single $20K SS + $0 other income → taxable SS should be $0 (below $25K combined-income threshold). Got \(taxableSS)")
    }
}
