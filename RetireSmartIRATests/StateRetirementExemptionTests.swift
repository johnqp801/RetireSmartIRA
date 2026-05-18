//
//  StateRetirementExemptionTests.swift
//  RetireSmartIRATests
//
//  Regression coverage for the 1.8.1.1 build 38 engine fix: state-level
//  retirement-income exemptions (RetirementIncomeExemptions) are now wired
//  into calculateStateTaxFromGross / scenarioStateTax / stateTaxBreakdown
//  via scenarioRetirementDistributionIncome. Prior to the fix, scenario
//  withdrawals (RMDs from balances, inherited-IRA RMDs, extra withdrawals)
//  flowed into scenarioGrossIncome but never matched the exemption filter,
//  so PA/IL/MS retirement-age users were charged state tax on IRA
//  distributions they should not owe.
//
//  Verified user scenario: PA resident (Jonggie F.), retirement age, $50K
//  IRA distribution, no W-2 → PA state tax MUST be $0 (PA already taxed the
//  contributions; PA DOR Gross Compensation guide).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("State retirement-income exemption wiring (1.8.1.1 build 38)")
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
}
