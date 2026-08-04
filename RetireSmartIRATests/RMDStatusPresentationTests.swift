import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("RMD status presentation")
struct RMDStatusPresentationTests {

    /// Mirrors what the view does: resolve the household, then render it.
    private func build(
        primaryAge: Int, primaryRmdAge: Int,
        spouseEnabled: Bool, spouseAge: Int, spouseRmdAge: Int,
        spouseName: String = "",
        hasInheritedRMDs: Bool = false,
        firstRmdDeadlineYear: Int = 2027
    ) -> RMDStatusPresentation {
        let status = RMDHouseholdStatus.resolve(
            primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
            spouseEnabled: spouseEnabled, spouseAge: spouseAge, spouseRmdAge: spouseRmdAge)
        return RMDStatusPresentation.build(
            status: status,
            primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
            spouseAge: spouseAge, spouseRmdAge: spouseRmdAge,
            spouseName: spouseName,
            hasInheritedRMDs: hasInheritedRMDs,
            firstRmdDeadlineYear: firstRmdDeadlineYear)
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
        #expect(p.lines[0] == "Karen has reached RMD age 73")
        #expect(p.lines[1] == "You reach RMD age 73 in 9 years")
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
        for notice in p.firstYearNotices {
            #expect(!notice.contains("Ghost"))
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
        #expect(p.lines[0] == "Karen has reached RMD age 73")
        #expect(p.lines[1] == "You have reached RMD age 75")
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

        #expect(p.lines[0] == "You have reached RMD age 73")
        #expect(p.lines[1] == "Karen has reached RMD age 75")
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

    @Test("Differing RMD ages with the PRIMARY leading: both sentences in full")
    func differingRmdAgesWithPrimaryLeading() {
        // Every other differing-age case has the spouse leading, so the
        // primary-leading combination had no assertion on line TEXT at all.
        let p = build(
            primaryAge: 70, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 60, spouseRmdAge: 75,
            spouseName: "Karen")

        let status = RMDHouseholdStatus.resolve(
            primaryAge: 70, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 60, spouseRmdAge: 75)
        #expect(status.startsFirst == .primary)

        #expect(p.ageTitle == "First RMD Age")
        #expect(p.ageValue == "73")
        #expect(p.lines.count == 2)
        #expect(p.lines[0] == "You reach RMD age 73 in 3 years")
        #expect(p.lines[1] == "Karen reaches RMD age 75 in 15 years")
    }

    @Test("Equal RMD ages keep the plain RMD Age title")
    func equalRmdAgesKeepTheTitle() {
        let p = build(
            primaryAge: 60, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 70, spouseRmdAge: 73)

        #expect(p.ageTitle == "RMD Age")
        #expect(p.ageValue == "73")
        #expect(p.lines.count == 2)
        #expect(p.lines[0] == "Your spouse reaches RMD age 73 in 3 years")
        #expect(p.lines[1] == "You reach RMD age 73 in 13 years")
    }

    @Test("An empty spouse name falls back to the generic subject")
    func emptySpouseNameUsesGenericSubject() {
        let p = build(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "")

        #expect(p.lines[0] == "Your spouse has reached RMD age 73")
    }

    @Test("A named spouse is addressed by name")
    func namedSpouseUsesTheName() {
        let p = build(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.lines[0].hasPrefix("Karen "))
        #expect(!p.lines[0].contains("spouse"))
    }

    @Test("Exactly one year out reads 1 year, not 1 years")
    func singularYearReadsCorrectly() {
        let p = build(
            primaryAge: 72, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 60, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.lines[0] == "You reach RMD age 73 in 1 year")
        #expect(!p.lines[0].contains("1 years"))
        #expect(p.lines[1] == "Karen reaches RMD age 73 in 13 years")
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

    // MARK: - No line may claim anything the type cannot know

    @Test("No line asserts that a distribution is owed, only that an age was reached")
    func linesAreAgeStatementsNotBalanceClaims() {
        // `build` receives ages and a name. It never sees an account balance, so
        // a sentence naming a person and asserting an RMD is due would be a
        // claim the type cannot support for a spouse who holds no traditional
        // IRA. Every line must stay an age statement.
        let households: [RMDStatusPresentation] = [
            build(primaryAge: 64, primaryRmdAge: 73,
                  spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73, spouseName: "Karen"),
            build(primaryAge: 78, primaryRmdAge: 75,
                  spouseEnabled: true, spouseAge: 85, spouseRmdAge: 73, spouseName: "Karen"),
            build(primaryAge: 60, primaryRmdAge: 73,
                  spouseEnabled: true, spouseAge: 70, spouseRmdAge: 73)
        ]

        for p in households {
            for line in p.lines {
                #expect(line.contains("RMD age"))
                #expect(!line.contains("required now"))
                #expect(!line.contains("RMDs are"))
                #expect(!line.contains("RMDs start"))
            }
        }
    }

    // MARK: - First-year April 1 notices

    @Test("Single filer in her first RMD year keeps today's exact notice wording")
    func singleFilerFirstYearNotice() {
        let p = build(
            primaryAge: 73, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 0, spouseRmdAge: 73,
            firstRmdDeadlineYear: 2027)

        #expect(p.firstYearNotices == ["First RMD can be delayed until April 1 2027"])
    }

    @Test("Single filer past her first RMD year gets no notice")
    func singleFilerPastFirstYearHasNoNotice() {
        let p = build(
            primaryAge: 76, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 0, spouseRmdAge: 73)

        #expect(p.firstYearNotices.isEmpty)
    }

    @Test("Steve's household: the April 1 notice belongs to the SPOUSE, not the primary")
    func firstYearNoticeFollowsTheSpouse() {
        // The primary is 64 with RMD age 73 and has no April 1 right at all.
        // The spouse is 73 with RMD age 73, so the deferral is hers. Deciding
        // this from the primary's age denies it to the only person who has it.
        let p = build(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "Karen",
            firstRmdDeadlineYear: 2027)

        #expect(p.firstYearNotices == ["Karen's first RMD can be delayed until April 1 2027"])
        #expect(p.sections.showsDeadlines)
    }

    @Test("An unnamed spouse's notice uses the generic possessive")
    func unnamedSpouseNoticePossessive() {
        let p = build(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            firstRmdDeadlineYear: 2027)

        #expect(p.firstYearNotices == ["Your spouse's first RMD can be delayed until April 1 2027"])
    }

    @Test("The primary's own first-year notice is attributed to him")
    func primaryFirstYearNoticeIsHis() {
        let p = build(
            primaryAge: 73, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 60, spouseRmdAge: 73,
            spouseName: "Karen",
            firstRmdDeadlineYear: 2027)

        #expect(p.firstYearNotices == ["Your first RMD can be delayed until April 1 2027"])
    }

    @Test("Two people in their first RMD year get two notices in line order")
    func bothInFirstYearGetTwoNoticesInLineOrder() {
        // Different RMD ages, both landing on their trigger year at once. Both
        // are zero years past their own age, so the tie resolves to the primary
        // and the notices must follow the SAME order as the lines rather than
        // an order of their own.
        let p = build(
            primaryAge: 75, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "Karen",
            firstRmdDeadlineYear: 2027)

        #expect(p.lines == [
            "You have reached RMD age 75",
            "Karen has reached RMD age 73"
        ])
        #expect(p.firstYearNotices == [
            "Your first RMD can be delayed until April 1 2027",
            "Karen's first RMD can be delayed until April 1 2027"
        ])
    }

    @Test("Nobody in a first RMD year means no notices at all")
    func noNoticesWhenNobodyIsInTheirFirstYear() {
        let p = build(
            primaryAge: 78, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 85, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.firstYearNotices.isEmpty)
        #expect(p.sections.showsDeadlines)
    }

    // MARK: - Which body blocks render

    @Test("Single filer not yet required: only the legacy countdown")
    func sectionsSingleFilerNotRequired() {
        let p = build(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 0, spouseRmdAge: 73)

        #expect(p.sections == RMDStatusPresentation.BodySections(
            showsHouseholdLines: false,
            showsDeadlines: false,
            showsInheritedCountdown: false,
            showsLegacyCountdown: true))
    }

    @Test("Single filer required: deadlines only, no countdown")
    func sectionsSingleFilerRequired() {
        let p = build(
            primaryAge: 75, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 0, spouseRmdAge: 73)

        #expect(p.sections == RMDStatusPresentation.BodySections(
            showsHouseholdLines: false,
            showsDeadlines: true,
            showsInheritedCountdown: false,
            showsLegacyCountdown: false))
    }

    @Test("Couple on one clock: identical to a single filer")
    func sectionsCoupleOnTheSameClock() {
        let p = build(
            primaryAge: 70, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 70, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.sections == RMDStatusPresentation.BodySections(
            showsHouseholdLines: false,
            showsDeadlines: false,
            showsInheritedCountdown: false,
            showsLegacyCountdown: true))
    }

    @Test("Split couple, primary required: lines plus deadlines, no legacy countdown")
    func sectionsSplitCouplePrimaryRequired() {
        let p = build(
            primaryAge: 75, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 60, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.sections == RMDStatusPresentation.BodySections(
            showsHouseholdLines: true,
            showsDeadlines: true,
            showsInheritedCountdown: false,
            showsLegacyCountdown: false))
    }

    @Test("Split couple, SPOUSE required: the deadline block still renders")
    func sectionsSplitCoupleSpouseRequired() {
        // The household this whole fix exists for. Gating the deadline block on
        // the primary drops December 31 for the one person who has a deadline.
        let p = build(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(p.sections == RMDStatusPresentation.BodySections(
            showsHouseholdLines: true,
            showsDeadlines: true,
            showsInheritedCountdown: false,
            showsLegacyCountdown: false))
    }

    @Test("Split couple with inherited IRAs and nobody required: inherited block, not the legacy countdown")
    func sectionsSplitCoupleWithInheritedIRAs() {
        let p = build(
            primaryAge: 60, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 70, spouseRmdAge: 73,
            spouseName: "Karen",
            hasInheritedRMDs: true)

        #expect(p.sections == RMDStatusPresentation.BodySections(
            showsHouseholdLines: true,
            showsDeadlines: false,
            showsInheritedCountdown: true,
            showsLegacyCountdown: false))
    }

    @Test("The household lines and the legacy countdown are never both shown")
    func linesAndLegacyCountdownAreMutuallyExclusive() {
        // Reverting the view's final branch to a plain `else` reprints the old
        // primary-only countdown UNDERNEATH the two correct lines. This is the
        // invariant that seam violates.
        for primaryAge in [55, 64, 70, 73, 75, 85] {
            for primaryRmdAge in [73, 75] {
                for spouseAge in [55, 60, 70, 73, 85] {
                    for spouseRmdAge in [73, 75] {
                        for spouseEnabled in [true, false] {
                            for inherited in [true, false] {
                                let p = build(
                                    primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
                                    spouseEnabled: spouseEnabled,
                                    spouseAge: spouseAge, spouseRmdAge: spouseRmdAge,
                                    spouseName: "Karen",
                                    hasInheritedRMDs: inherited)
                                #expect(!(p.sections.showsHouseholdLines
                                    && p.sections.showsLegacyCountdown))
                                // The three lower blocks are one exclusive chain.
                                let lower = [
                                    p.sections.showsDeadlines,
                                    p.sections.showsInheritedCountdown,
                                    p.sections.showsLegacyCountdown
                                ].filter { $0 }.count
                                #expect(lower <= 1)
                                // Lines exist exactly when the flag says so.
                                #expect(p.sections.showsHouseholdLines == !p.lines.isEmpty)
                            }
                        }
                    }
                }
            }
        }
    }
}
