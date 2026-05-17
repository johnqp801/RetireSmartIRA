//
//  StateTaxAboveTheLineConformityTests.swift
//  RetireSmartIRATests
//
//  Verifies that Traditional IRA and R3 "Other" above-the-line deductions
//  reduce state taxable income in conforming states (default), and that
//  no-income-tax states / non-conforming flags behave as expected.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State above-the-line conformity flags")
struct StateAboveTheLineConformityFlagsTests {

    @Test("All states conform to federal IRA deduction by default")
    func allStatesConformToIRA() {
        for state in USState.allCases {
            let config = StateTaxData.config(for: state)
            #expect(
                config.traditionalIRAContributionsTaxableForState == false,
                "State \(state) should be IRA-conforming by default"
            )
        }
    }

    @Test("All states conform to federal Other above-the-line by default")
    func allStatesConformToOther() {
        for state in USState.allCases {
            let config = StateTaxData.config(for: state)
            #expect(
                config.otherPreTaxDeductionsTaxableForState == false,
                "State \(state) should be Other-conforming by default"
            )
        }
    }
}

@Suite("State above-the-line conformity behavior")
@MainActor
struct StateAboveTheLineConformityBehaviorTests {

    @Test("New York: IRA contribution reduces state taxable income")
    func newYorkIRADropsStateTax() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .single
        let baseline = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .newYork,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            hsaContributionsAddedBack: 0,
            traditionalIRAContributionsSubtracted: 0,
            otherPreTaxDeductionsSubtracted: 0
        )
        let withIRA = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .newYork,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            hsaContributionsAddedBack: 0,
            traditionalIRAContributionsSubtracted: 5_000,
            otherPreTaxDeductionsSubtracted: 0
        )
        // NY is IRA-conforming → state tax with IRA contribution must be lower.
        #expect(withIRA < baseline)
        // Drop should be roughly 5_000 × NY marginal rate (~5–6%). Sanity-check
        // it's in a reasonable band, not zero and not absurd.
        let drop = baseline - withIRA
        #expect(drop > 100)      // non-trivial
        #expect(drop < 1_500)    // not more than ~30% (i.e., not absurd)
    }

    @Test("New York: Other pre-tax deductions reduce state taxable income")
    func newYorkOtherDropsStateTax() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .single
        let baseline = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .newYork,
            filingStatus: .single,
            taxableSocialSecurity: 0
        )
        let withOther = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .newYork,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            otherPreTaxDeductionsSubtracted: 300
        )
        #expect(withOther < baseline)
    }

    @Test("Texas (no income tax): IRA and Other deductions are a no-op")
    func texasNoOp() {
        let dm = DataManager(skipPersistence: true)
        let withDeductions = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .texas,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            traditionalIRAContributionsSubtracted: 5_000,
            otherPreTaxDeductionsSubtracted: 500
        )
        #expect(withDeductions == 0)
    }

    @Test("California: HSA non-conforming (adds back), IRA + Other conforming (subtract)")
    func californiaMixedConformity() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .marriedFilingJointly
        let baseline = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .california,
            filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0
        )
        // HSA: CA flag is true → addback raises state tax.
        let withHSAOnly = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .california,
            filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0,
            hsaContributionsAddedBack: 2_000
        )
        #expect(withHSAOnly > baseline)

        // IRA + Other: CA flags are false (conforming) → subtraction lowers state tax.
        let withIRAOther = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .california,
            filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0,
            traditionalIRAContributionsSubtracted: 5_000,
            otherPreTaxDeductionsSubtracted: 500
        )
        #expect(withIRAOther < baseline)
    }
}

@Suite("State tax helpers stay consistent with scenarioStateTax")
@MainActor
struct StateTaxHelpersConsistencyTests {

    /// I1 invariant: the parallel bracket-walk helper that powers the dashboard's
    /// State Tax panel must agree with scenarioStateTax even when IRA / R3 Other
    /// above-the-line contributions are non-zero in a conforming state.
    @Test("stateTaxBreakdown.totalStateTax matches scenarioStateTax (NY, IRA + Other)")
    func stateTaxBreakdownMatchesScenarioStateTax() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.selectedState = .newYork
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Wages", type: .consulting, annualAmount: 150_000, owner: .primary)
        ]
        dm.scenario.yourTraditionalIRAContribution = 7_000
        dm.scenario.yourOtherPreTaxDeductions = 1_500

        let breakdownTax = dm.scenarioStateTaxBreakdown.totalStateTax
        let engineTax = dm.scenarioStateTax

        // Tolerance: 1 dollar — these are computed independently but should agree
        // to within rounding.
        #expect(abs(breakdownTax - engineTax) < 1.0,
                "breakdown=\(breakdownTax) engine=\(engineTax)")
    }

    /// I2 invariant: the cost-spike helper, when sampled at the user's actual
    /// AGI, must produce a state tax matching scenarioStateTax. Previously the
    /// helper double-subtracted IRA/Other on the state side.
    @Test("estimatedThisYearCostAtAGI state-tax component matches scenarioStateTax at user's AGI")
    func costSpikeAtUserAGIMatchesScenarioStateTax() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.selectedState = .newYork
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Wages", type: .consulting, annualAmount: 150_000, owner: .primary)
        ]
        dm.scenario.yourTraditionalIRAContribution = 7_000
        dm.scenario.yourOtherPreTaxDeductions = 1_500

        // Engine truth (no ACA in this profile → acaImpact = 0; federal + state only).
        let engineState = dm.scenarioStateTax
        let engineFederal = dm.scenarioFederalTax

        let costAtUserAGI = dm.estimatedThisYearCostAtAGI(dm.federalAGI.value)

        // costAtUserAGI = federalTax + stateTax (+ acaImpact, which is 0 here since
        // enableACAModeling is false by default).
        // Federal portion in the helper uses a simplified standard-deduction-only
        // taxable income (no SS phase-in, no preferential income split), so we
        // back the federal portion out via the engine's federal-only computation
        // and compare what remains to engine state tax.
        //
        // Reconstruct helper's federal portion:
        var helperFederal = 0.0
        let stdDed = dm.standardDeductionAmount
        let federalTaxable = max(0, dm.federalAGI.value - stdDed)
        let brackets: [TaxYearConfig.BracketEntry] = dm.filingStatus == .single
            ? TaxCalculationEngine.config.federalBracketsSingle
            : TaxCalculationEngine.config.federalBracketsMFJ
        var remaining = federalTaxable
        for (i, b) in brackets.enumerated() {
            let nextThreshold = (i + 1 < brackets.count) ? brackets[i + 1].threshold : .infinity
            let w = min(remaining, nextThreshold - b.threshold)
            if w > 0 { helperFederal += w * b.rate; remaining -= w }
            if remaining <= 0 { break }
        }
        let helperState = costAtUserAGI - helperFederal

        #expect(abs(helperState - engineState) < 1.0,
                "helperState=\(helperState) engineState=\(engineState)")
        // Sanity: engineFederal differs from helperFederal only by preferential / SS
        // adjustments which are 0 here, so they should also match.
        #expect(abs(helperFederal - engineFederal) < 1.0,
                "helperFederal=\(helperFederal) engineFederal=\(engineFederal)")
    }
}
