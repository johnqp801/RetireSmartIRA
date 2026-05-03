//
//  StateTaxHSATests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State HSA add-back flag")
struct StateHSAAddBackTests {

    @Test("California taxes HSA contributions as ordinary income")
    func californiaTaxesHSA() {
        let config = StateTaxData.config(for: .california)
        #expect(config.hsaContributionsTaxableForState == true)
    }

    @Test("New Jersey taxes HSA contributions as ordinary income")
    func newJerseyTaxesHSA() {
        let config = StateTaxData.config(for: .newJersey)
        #expect(config.hsaContributionsTaxableForState == true)
    }

    @Test("All other states do NOT tax HSA contributions (parameterized)")
    func otherStatesConformToFederal() {
        for state in USState.allCases where state != .california && state != .newJersey {
            let config = StateTaxData.config(for: state)
            #expect(
                config.hsaContributionsTaxableForState == false,
                "State \(state) should not tax HSA contributions"
            )
        }
    }
}

@Suite("State HSA add-back behavior")
@MainActor
struct StateHSAAddBackBehaviorTests {

    @Test("California: HSA contributions added back to state taxable income")
    func californiaHSAAddBack() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .marriedFilingJointly
        dm.selectedState = .california
        let withoutHSA = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .california,
            filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0,
            hsaContributionsAddedBack: 0
        )
        let withHSA = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .california,
            filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0,
            hsaContributionsAddedBack: 8_550
        )
        // CA adds back the $8,550 to taxable income → state tax is HIGHER with HSA add-back
        #expect(withHSA > withoutHSA)
    }

    @Test("Texas (no income tax): HSA add-back is a no-op")
    func texasHSAAddBackNoop() {
        let dm = DataManager(skipPersistence: true)
        let zero = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .texas,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            hsaContributionsAddedBack: 8_550
        )
        #expect(zero == 0)
    }

    @Test("New York (does not tax HSA): HSA add-back is a no-op")
    func newYorkHSAAddBackNoop() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .single
        let withoutHSA = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .newYork,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            hsaContributionsAddedBack: 0
        )
        let withHSA = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .newYork,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            hsaContributionsAddedBack: 8_550
        )
        // NY does not tax HSA → state tax is unchanged
        #expect(withHSA == withoutHSA)
    }
}
