import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("RMD status presentation")
struct RMDStatusPresentationTests {

    /// Mirrors what the view does: resolve the household, then render it.
    private func build(
        primaryAge: Int, primaryRmdAge: Int,
        spouseEnabled: Bool, spouseAge: Int, spouseRmdAge: Int,
        spouseName: String = ""
    ) -> RMDStatusPresentation {
        let status = RMDHouseholdStatus.resolve(
            primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
            spouseEnabled: spouseEnabled, spouseAge: spouseAge, spouseRmdAge: spouseRmdAge)
        return RMDStatusPresentation.build(
            status: status,
            primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
            spouseAge: spouseAge, spouseRmdAge: spouseRmdAge,
            spouseName: spouseName)
    }

    @Test("Steve's household: the already-required wife leads and the card reads Required")
    func olderSpouseLeadsAndFlipsTheBadge() {
        // Wife nine years older and already at her RMD age. The card previously
        // read "Not Yet Required / RMDs start in 9 years" off the primary alone
        // while her RMD was overdue. This is the headline regression.
        let p = build(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.badge == "RMDs Required")
        #expect(p.lines.count == 2)
        #expect(p.lines[0] == "Karen's RMDs are required now (began at age 73)")
        #expect(p.lines[1] == "Your RMDs start in 9 years (age 73)")
        // Shared RMD age, so the single headline number is still true for both.
        #expect(p.ageTitle == "RMD Age")
        #expect(p.ageValue == "73")
    }

    @Test("Single filer: no spouse text can leak into the card")
    func singleFilerRendersExactlyAsBefore() {
        // spouseAge 99 and a loud name would dominate every field if the
        // spouse branch were reachable with the spouse disabled.
        let p = build(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 99, spouseRmdAge: 73,
            spouseName: "Ghost")

        #expect(p.badge == "Not Yet Required")
        #expect(p.lines.isEmpty)
        #expect(p.ageTitle == "RMD Age")
        #expect(p.ageValue == "73")
        for line in p.lines {
            #expect(!line.contains("Ghost"))
        }
    }

    @Test("Single filer already required reads Required with no extra lines")
    func singleFilerAlreadyRequired() {
        let p = build(
            primaryAge: 75, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 0, spouseRmdAge: 73)

        #expect(p.badge == "RMDs Required")
        #expect(p.lines.isEmpty)
        #expect(p.ageTitle == "RMD Age")
    }

    @Test("Both already required: each line carries its OWN trigger age")
    func bothRequiredKeepTheirOwnAges() {
        // The misattribution guard. Primary triggered at 75, spouse at 73.
        // A line built from the household's first RMD age would stamp 73 on
        // both names.
        let p = build(
            primaryAge: 78, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 85, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.badge == "RMDs Required")
        #expect(p.lines.count == 2)
        // Spouse became required first, so she leads.
        #expect(p.lines[0] == "Karen's RMDs are required now (began at age 73)")
        #expect(p.lines[1] == "Your RMDs are required now (began at age 75)")
        #expect(p.lines[1].contains("75"))
        #expect(!p.lines[1].contains("73"))
        #expect(p.lines[0].contains("73"))
        #expect(!p.lines[0].contains("75"))
    }

    @Test("Both required with the primary earlier: the primary leads")
    func bothRequiredPrimaryLeads() {
        let p = build(
            primaryAge: 85, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 78, spouseRmdAge: 75,
            spouseName: "Karen")

        #expect(p.lines[0] == "Your RMDs are required now (began at age 73)")
        #expect(p.lines[1] == "Karen's RMDs are required now (began at age 75)")
    }

    @Test("Differing RMD ages title the number as the FIRST one")
    func differingRmdAgesRetitleTheNumber() {
        // Born 1959 against born 1960: 75 versus 73, a real SECURE 2.0 split.
        let p = build(
            primaryAge: 67, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 67, spouseRmdAge: 73)

        #expect(p.ageTitle == "First RMD Age")
        #expect(p.ageValue == "73")
        #expect(p.badge == "Not Yet Required")
        #expect(p.lines.count == 2)
    }

    @Test("Equal RMD ages keep the plain RMD Age title")
    func equalRmdAgesKeepTheTitle() {
        let p = build(
            primaryAge: 60, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 70, spouseRmdAge: 73)

        #expect(p.ageTitle == "RMD Age")
        #expect(p.ageValue == "73")
        #expect(p.lines.count == 2)
        #expect(p.lines[0] == "Your spouse's RMDs start in 3 years (age 73)")
        #expect(p.lines[1] == "Your RMDs start in 13 years (age 73)")
    }

    @Test("An empty spouse name falls back to the generic possessive")
    func emptySpouseNameUsesGenericPossessive() {
        let p = build(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "")

        #expect(p.lines[0] == "Your spouse's RMDs are required now (began at age 73)")
    }

    @Test("A named spouse is addressed by her possessive name")
    func namedSpouseUsesThePossessiveName() {
        let p = build(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.lines[0].hasPrefix("Karen's "))
        #expect(!p.lines[0].contains("spouse"))
    }

    @Test("Exactly one year out reads 1 year, not 1 years")
    func singularYearReadsCorrectly() {
        let p = build(
            primaryAge: 72, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 60, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.lines[0] == "Your RMDs start in 1 year (age 73)")
        #expect(!p.lines[0].contains("1 years"))
        #expect(p.lines[1] == "Karen's RMDs start in 13 years (age 73)")
    }

    @Test("A couple who match exactly collapses to one person and shows no lines")
    func matchedCoupleCollapsesToOnePerson() {
        let p = build(
            primaryAge: 70, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 70, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.lines.isEmpty)
        #expect(p.ageTitle == "RMD Age")
        #expect(p.badge == "Not Yet Required")
    }
}
