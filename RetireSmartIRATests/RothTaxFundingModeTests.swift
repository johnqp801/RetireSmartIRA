//
//  RothTaxFundingModeTests.swift
//  RetireSmartIRATests
//
//  V2.3: the funding-mode preset and its internal (remittance, shortfall-policy) resolution.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("RothTaxFundingMode preset resolution")
struct RothTaxFundingModeTests {

    @Test("Only the withholding preset uses custodial withholding")
    func withholdingResolution() {
        #expect(RothTaxFundingMode.withheldFromConversion.usesCustodialWithholding == true)
        #expect(RothTaxFundingMode.fundedFromAccounts.usesCustodialWithholding == false)
        #expect(RothTaxFundingMode.paidFromOutsideMoney.usesCustodialWithholding == false)
    }

    @Test("Both account-funded presets cascade a shortfall; outside money does not")
    func shortfallResolution() {
        #expect(RothTaxFundingMode.withheldFromConversion.fundsShortfallFromAccounts == true)
        #expect(RothTaxFundingMode.fundedFromAccounts.fundsShortfallFromAccounts == true)
        #expect(RothTaxFundingMode.paidFromOutsideMoney.fundsShortfallFromAccounts == false)
    }

    @Test("IRA dollars can pay tax in both account-touching modes (drives disclosures)")
    func iraExposure() {
        #expect(RothTaxFundingMode.withheldFromConversion.canTouchIRADollarsForTax == true)
        #expect(RothTaxFundingMode.fundedFromAccounts.canTouchIRADollarsForTax == true)
        #expect(RothTaxFundingMode.paidFromOutsideMoney.canTouchIRADollarsForTax == false)
    }

    @Test("Raw values are stable (persisted in saved scenarios)")
    func rawValuesStable() {
        #expect(RothTaxFundingMode.withheldFromConversion.rawValue == "withheldFromConversion")
        #expect(RothTaxFundingMode.fundedFromAccounts.rawValue == "fundedFromAccounts")
        #expect(RothTaxFundingMode.paidFromOutsideMoney.rawValue == "paidFromOutsideMoney")
    }

    @Test("Every preset states its funding order in the subtitle")
    func subtitlesStateFundingOrder() {
        // The whole point: a friendly label must not hide the cascade.
        #expect(RothTaxFundingMode.withheldFromConversion.fundingSubtitle.contains("taxable"))
        #expect(RothTaxFundingMode.withheldFromConversion.fundingSubtitle.contains("IRA"))
        #expect(RothTaxFundingMode.fundedFromAccounts.fundingSubtitle.contains("Taxable assets first"))
        #expect(RothTaxFundingMode.paidFromOutsideMoney.fundingSubtitle.contains("not tracked"))
    }

    @Test("No user-facing string contains an em dash")
    func noEmDash() {
        for mode in RothTaxFundingMode.allCases {
            #expect(mode.displayName.contains("\u{2014}") == false)
            #expect(mode.fundingSubtitle.contains("\u{2014}") == false)
        }
    }

    @Test("Shared federal withholding rates match the seven supported values")
    func sharedRates() {
        let rates = FederalWithholdingRates.options.map(\.rate)
        #expect(rates == [0.10, 0.12, 0.22, 0.24, 0.32, 0.35, 0.37])
        #expect(FederalWithholdingRates.defaultRate == 0.24)
    }
}
