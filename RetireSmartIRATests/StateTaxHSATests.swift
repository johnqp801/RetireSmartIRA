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
