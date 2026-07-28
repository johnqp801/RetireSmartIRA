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

    @Test("The picker shows EVERY option's funding order, not just the selected one")
    func allSubtitlesAreVisibleAtDecisionTime() {
        // A bare Picker in a Form renders as a macOS pop-up menu / iOS push list showing
        // `displayName` alone, so the user chooses "Withhold from conversion" without ever
        // reading that the remainder comes from taxable assets and then the IRA. The card
        // therefore renders one row per mode, each carrying its own subtitle.
        var a = MultiYearAssumptions()
        a.rothTaxFundingMode = .paidFromOutsideMoney       // selection must not matter
        let card = MultiYearTaxFundingCard(assumptions: .constant(a), youngestAge: 70,
                                           state: .california)
        let rows = card.optionRows
        #expect(rows.count == RothTaxFundingMode.allCases.count)
        for mode in RothTaxFundingMode.allCases {
            let row = rows.first { $0.mode == mode }
            #expect(row != nil, "\(mode) must be offered")
            #expect(row?.title == mode.displayName)
            // The UNSELECTED options carry their cascade copy too, which is the whole point.
            #expect(row?.subtitle == mode.fundingSubtitle)
            #expect(row?.subtitle.isEmpty == false)
        }
        // Distinct copy per option: a shared subtitle would defeat the purpose.
        #expect(Set(rows.map(\.subtitle)).count == rows.count)
    }

    @Test("Under-59.5 warning shows only when IRA dollars can pay the tax")
    func earlyWarningTriggers() {
        func card(_ mode: RothTaxFundingMode, age: Int) -> MultiYearTaxFundingCard {
            var a = MultiYearAssumptions()
            a.rothTaxFundingMode = mode
            return MultiYearTaxFundingCard(assumptions: .constant(a), youngestAge: age,
                                           state: .california)
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
            for state in [USState.california, .pennsylvania] {
                _ = MultiYearTaxFundingCard(assumptions: .constant(a), youngestAge: 55,
                                            state: state).body
            }
        }
        #expect(true)
    }

    @Test("PA note appears only for a Pennsylvania household electing withholding")
    func pennsylvaniaNoteGate() {
        func card(_ mode: RothTaxFundingMode, _ state: USState) -> MultiYearTaxFundingCard {
            var a = MultiYearAssumptions()
            a.rothTaxFundingMode = mode
            return MultiYearTaxFundingCard(assumptions: .constant(a), youngestAge: 70, state: state)
        }
        // Task 5 made the withheld portion PA-taxable in the engine; this screen has to say so.
        #expect(card(.withheldFromConversion, .pennsylvania).showsPennsylvaniaNote)
        // No withholding means the full pre-tax balance lands in the Roth: still PA-exempt.
        #expect(card(.fundedFromAccounts, .pennsylvania).showsPennsylvaniaNote == false)
        #expect(card(.paidFromOutsideMoney, .pennsylvania).showsPennsylvaniaNote == false)
        #expect(card(.withheldFromConversion, .california).showsPennsylvaniaNote == false)
    }

    @Test("PA note names the rule and the withheld portion")
    func pennsylvaniaNoteCopy() {
        let text = MultiYearTaxFundingCard.pennsylvaniaNote
        #expect(text.contains("Pennsylvania"))
        #expect(text.contains("274"), "cites the same PA DOR answer as the single-year card")
        #expect(text.lowercased().contains("withheld portion"))
        #expect(text.contains("\u{2014}") == false, "no em dash")
    }

    @Test("Ed Slott disclosure shows for BOTH IRA-touching modes, not just one")
    func iraFundingDisclosureGate() {
        func card(_ mode: RothTaxFundingMode) -> MultiYearTaxFundingCard {
            var a = MultiYearAssumptions()
            a.rothTaxFundingMode = mode
            return MultiYearTaxFundingCard(assumptions: .constant(a), youngestAge: 70,
                                           state: .california)
        }
        // Withholding still spends IRA dollars on tax, so it needs the disclosure just as
        // much as the explicit account-funded mode. Dropping either one defeats the feature.
        #expect(card(.withheldFromConversion).showsIRAFundingDisclosure)
        #expect(card(.fundedFromAccounts).showsIRAFundingDisclosure)
        #expect(card(.paidFromOutsideMoney).showsIRAFundingDisclosure == false)
    }

    @Test("Withholding-only caveat names the taxes it does not cover")
    func withholdingCaveatNamesUncoveredTaxes() {
        let text = MultiYearTaxFundingCard.withholdingScopeNote
        #expect(text.lowercased().contains("federal only"))
        #expect(text.lowercased().contains("state"))
        #expect(text.lowercased().contains("medicare"))
        #expect(text.lowercased().contains("net investment income"))
        // ACA repayment can run to thousands of dollars and rides the same non-federal
        // bucket as IRMAA and NIIT, so omitting it understates what withholding misses.
        #expect(text.contains("ACA"))
        #expect(text.contains("\u{2014}") == false, "no em dash")
    }
}
