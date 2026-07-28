//
//  TaxFundingDisclosureTests.swift
//  RetireSmartIRATests
//
//  V2.3: the disclosures are the reason this feature exists (a customer worried about
//  using IRA dollars to pay conversion tax), so their content is asserted, not assumed.
//

import Testing
import Foundation
import SwiftUI
@testable import RetireSmartIRA

@Suite("V2.3 tax-funding disclosures")
struct TaxFundingDisclosureTests {

    @Test("Ed Slott disclosure names the tradeoff")
    func edSlottMentionsTradeoff() {
        let text = V2Disclosures.edSlottIRAFunding
        #expect(text.contains("IRA"))
        #expect(text.isEmpty == false)
        #expect(text.contains("\u{2014}") == false, "no em dash")
    }

    @Test("Early-distribution disclosure states the limitation plainly")
    func earlyDistributionStatesNotModeled() {
        let text = V2Disclosures.earlyDistributionNotModeled
        #expect(text.contains("59"))
        #expect(text.lowercased().contains("not model"),
                "must say the additional tax is NOT modeled")
        #expect(text.contains("10%"))
        #expect(text.contains("\u{2014}") == false, "no em dash")
    }

    @Test("Infeasible-year copy reports amount and consequence")
    func infeasibleCopyExplains() {
        let text = V2Disclosures.infeasibleYearExplanation(shortfall: 8_420)
        #expect(text.contains("8,420"), "must state the amount")
        #expect(text.lowercased().contains("not reduced"),
                "must say the conversion was not reduced")
        #expect(text.lowercased().contains("later years"),
                "must say later years are affected")
        #expect(text.contains("\u{2014}") == false, "no em dash")
    }

    @Test("Both IRA-touching modes warrant the Ed Slott disclosure")
    func disclosureAppliesToBothAccountModes() {
        #expect(RothTaxFundingMode.withheldFromConversion.canTouchIRADollarsForTax)
        #expect(RothTaxFundingMode.fundedFromAccounts.canTouchIRADollarsForTax)
        #expect(RothTaxFundingMode.paidFromOutsideMoney.canTouchIRADollarsForTax == false)
    }

    @Test("Limitations list gains the early-distribution entry")
    func limitationsIncludeEarlyDistribution() {
        #expect(V2Disclosures.limitations.contains { $0.contains("59") })
    }
}

/// The card is the surface the user actually reads. These pin the two behaviors that
/// would silently defeat the feature: an option whose label hides its funding cascade,
/// and an under-59.5 warning that fails to appear.
@Suite("V2.3 tax-funding card", .serialized)
@MainActor
struct MultiYearTaxFundingCardTests {

    @Test("Every option's subtitle states its full funding behavior")
    func subtitlesStateFullBehavior() {
        // A friendly label that hides the cascade is the main usability risk here, so the
        // two modes that can cascade into IRA dollars must say so in their own subtitle.
        for mode in [RothTaxFundingMode.withheldFromConversion, .fundedFromAccounts] {
            #expect(mode.fundingSubtitle.contains("IRA"),
                    "\(mode) can reach IRA dollars and must say so")
            #expect(mode.fundingSubtitle.lowercased().contains("taxable"),
                    "\(mode) funds from taxable assets first and must say so")
        }
        #expect(RothTaxFundingMode.paidFromOutsideMoney.fundingSubtitle
            .lowercased().contains("outside this plan"))
    }

    @Test("Under-59.5 warning shows only when IRA dollars can pay the tax")
    func earlyWarningTriggers() {
        func card(_ mode: RothTaxFundingMode, age: Int) -> MultiYearTaxFundingCard {
            var a = MultiYearAssumptions()
            a.rothTaxFundingMode = mode
            return MultiYearTaxFundingCard(assumptions: .constant(a), youngestAge: age)
        }
        #expect(card(.withheldFromConversion, age: 55).showsEarlyDistributionWarning)
        #expect(card(.fundedFromAccounts, age: 55).showsEarlyDistributionWarning)
        // Outside money never touches the IRA, so the 72(t) exposure does not apply.
        #expect(card(.paidFromOutsideMoney, age: 55).showsEarlyDistributionWarning == false)
        // Age 60 is past 59.5, matching the single-year card's `currentAge < 60` gate.
        #expect(card(.withheldFromConversion, age: 60).showsEarlyDistributionWarning == false)
    }

    @Test("Card builds in every mode")
    func cardBuilds() {
        for mode in RothTaxFundingMode.allCases {
            var a = MultiYearAssumptions()
            a.rothTaxFundingMode = mode
            _ = MultiYearTaxFundingCard(assumptions: .constant(a), youngestAge: 55).body
        }
        #expect(true)
    }

    @Test("Shortfall banner reports the ROOT infeasible year, not a downstream one")
    func shortfallBannerPicksRootYear() {
        func year(_ y: Int, underfunded: Double?, infeasible: Bool, dependent: Bool) -> YearRecommendation {
            YearRecommendation(
                year: y, agi: 100_000, acaMagi: nil, irmaaMagi: nil, taxableIncome: 80_000,
                taxBreakdown: TaxBreakdown(federal: 10_000, state: 2_000, irmaa: 0,
                                           acaPremiumImpact: 0, niit: 0),
                endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
                actions: [],
                underfunded: underfunded,
                isInfeasible: infeasible,
                dependsOnInfeasibleYear: dependent)
        }
        let path = [
            year(2030, underfunded: nil, infeasible: false, dependent: false),
            year(2031, underfunded: 8_420, infeasible: true, dependent: false),
            year(2032, underfunded: 500, infeasible: true, dependent: true),
        ]
        #expect(TaxFundingShortfallBanner.firstInfeasible(in: path)?.year == 2031)
        // A fully funded plan must not raise the alarm.
        #expect(TaxFundingShortfallBanner.firstInfeasible(in: [path[0]]) == nil)
        #expect(TaxFundingShortfallBanner.firstInfeasible(in: []) == nil)
        _ = TaxFundingShortfallBanner(years: path).body
    }

    @Test("Withholding-only caveat names the taxes it does not cover")
    func withholdingCaveatNamesUncoveredTaxes() {
        let text = MultiYearTaxFundingCard.withholdingScopeNote
        #expect(text.lowercased().contains("federal only"))
        #expect(text.lowercased().contains("state"))
        #expect(text.lowercased().contains("medicare"))
        #expect(text.lowercased().contains("net investment income"))
        #expect(text.contains("\u{2014}") == false, "no em dash")
    }
}
