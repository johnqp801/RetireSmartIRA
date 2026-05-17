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
