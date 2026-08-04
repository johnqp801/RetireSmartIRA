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
        firstRmdDeadlineYear: Int = 2027,
        primaryName: String = "",
        primaryHasTraditionalBalance: Bool = true,
        spouseHasTraditionalBalance: Bool = true
    ) -> RMDStatusPresentation {
        let status = RMDHouseholdStatus.resolve(
            primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
            spouseEnabled: spouseEnabled, spouseAge: spouseAge, spouseRmdAge: spouseRmdAge)
        return RMDStatusPresentation.build(
            status: status,
            primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
            spouseAge: spouseAge, spouseRmdAge: spouseRmdAge,
            primaryName: primaryName,
            spouseName: spouseName,
            hasInheritedRMDs: hasInheritedRMDs,
            firstRmdDeadlineYear: firstRmdDeadlineYear,
            primaryHasTraditionalBalance: primaryHasTraditionalBalance,
            spouseHasTraditionalBalance: spouseHasTraditionalBalance)
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

    // MARK: - Reaching RMD age is not the same as owing a distribution

    @Test("A Roth-only spouse past her RMD age is announced no deadline, but her AGE is still stated")
    func rothOnlySpouseIsPastHerAgeYetOwesNothing() {
        // Primary 64 with RMD age 75 and a traditional balance. Karen is 73
        // with RMD age 73 and holds $800,000 of ROTH and no traditional money
        // at all. A Roth IRA has no required minimum distribution during the
        // owner's lifetime, so this household owes nothing this year: the
        // combined RMD is zero and the dollar section of the card is hidden.
        // The card nonetheless read "RMDs Required", offered Karen an April 1
        // deferral and warned her about taking two RMDs in one year.
        let p = build(
            primaryAge: 64, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "Karen",
            primaryHasTraditionalBalance: true,
            spouseHasTraditionalBalance: false)

        #expect(p.badge != "RMDs Required")
        #expect(p.badge == "Not Yet Required")
        #expect(!p.anyoneDue)
        // No April 1 notice, and with it no two-RMDs-in-one-year warning: the
        // view hangs that warning off a non-empty notice list.
        #expect(p.firstYearNotices.isEmpty)

        // The other half of the rule. Her AGE statement is true whatever she
        // holds, it is what an earlier review asked for, and balance-gating it
        // would be the over-correction.
        #expect(p.lines.contains("Karen has reached RMD age 73"))
        #expect(p.lines.count == 2)
    }

    @Test("Both people holding traditional balances behave exactly as they do today")
    func bothHoldingTraditionalBalancesIsUnchanged() {
        // The customer's real household, and the pin against over-correcting.
        // Balances present means the age-driven answers all stand.
        let p = build(
            primaryAge: 64, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "Karen",
            firstRmdDeadlineYear: 2027,
            primaryHasTraditionalBalance: true,
            spouseHasTraditionalBalance: true)

        #expect(p.badge == "RMDs Required")
        #expect(p.anyoneDue)
        #expect(p.firstYearNotices == ["Karen's first RMD can be delayed until April 1 2027"])
        #expect(p.lines.contains("Karen has reached RMD age 73"))
        #expect(p.headlineMetric.label == "RMD Status")
        #expect(p.headlineMetric.value == "Required")
    }

    @Test("A Roth-only PRIMARY past his own RMD age is announced no deadline either")
    func rothOnlyPrimaryOwesNothing() {
        // The mirror of the household above, so the fix cannot pass by having
        // been applied to the spouse alone. He is 78 against an RMD age of 75
        // and holds only Roth; she is 60 and not close to hers.
        let p = build(
            primaryAge: 78, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 60, spouseRmdAge: 73,
            spouseName: "Karen",
            primaryHasTraditionalBalance: false,
            spouseHasTraditionalBalance: true)

        #expect(p.badge != "RMDs Required")
        #expect(p.badge == "Not Yet Required")
        #expect(!p.anyoneDue)
        #expect(p.firstYearNotices.isEmpty)
        #expect(p.lines.contains("You have reached RMD age 75"))
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

    // MARK: - Conversion Opportunity Window

    /// Mirrors what the Scenario Builder does: resolve the household, then ask
    /// for the window sentences.
    private func window(
        primaryAge: Int, primaryRmdAge: Int,
        spouseEnabled: Bool, spouseAge: Int, spouseRmdAge: Int,
        spouseName: String = ""
    ) -> RMDStatusPresentation.ConversionWindow {
        let status = RMDHouseholdStatus.resolve(
            primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
            spouseEnabled: spouseEnabled, spouseAge: spouseAge, spouseRmdAge: spouseRmdAge)
        return RMDStatusPresentation.conversionWindow(
            status: status,
            primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
            spouseEnabled: spouseEnabled,
            spouseAge: spouseAge, spouseRmdAge: spouseRmdAge,
            spouseName: spouseName)
    }

    @Test("A spouse already taking RMDs ends the card's ideal-time promise")
    func requiredSpouseDropsTheIdealTimeAdvice() {
        // Seen in the running app: primary 66 with RMD age 75, Karen 73 and
        // already required, owing $33,962 by December 31. The card still read
        // "This is an ideal time for Roth conversions" while the Legacy tab,
        // looking at the same household, printed nothing at all.
        let w = window(
            primaryAge: 66, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(!w.primarySentence.contains("ideal time"))
        #expect(w.primarySentence == "You have 9 years before your own RMDs start.")
        #expect(w.alreadyBegunSentence == "Karen's RMDs have already begun, so part of your lower brackets is already in use.")
    }

    @Test("A couple with nobody required keeps today's wording exactly")
    func nobodyRequiredCoupleWordingIsUnchanged() {
        // Hard compatibility pin: this is the household the advice was written
        // for, and its strings must not move by a single byte.
        let w = window(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 60, spouseRmdAge: 75,
            spouseName: "Karen")

        #expect(w.primarySentence == "You have 9 years before RMDs start. This is an ideal time for Roth conversions while potentially in a lower tax bracket.")
        #expect(w.spouseSentence == "Karen has 15 years before RMDs start.")
        #expect(w.alreadyBegunSentence == nil)
    }

    @Test("A single filer with nobody required keeps today's wording exactly")
    func nobodyRequiredSingleFilerWordingIsUnchanged() {
        let w = window(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 0, spouseRmdAge: 0)

        #expect(w.primarySentence == "You have 9 years before RMDs start. This is an ideal time for Roth conversions while potentially in a lower tax bracket.")
        #expect(w.alreadyBegunSentence == nil)
    }

    @Test("When the primary is the required one, the household line says Your")
    func requiredPrimaryNamesTheUser() {
        // The mirror of the household above. Attributing this line to the
        // primary by default would pass the case above for the wrong reason,
        // so the two directions are pinned separately.
        let w = window(
            primaryAge: 75, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 66, spouseRmdAge: 73,
            spouseName: "Karen")

        #expect(w.spouseSentence == "Karen has 7 years before Karen's own RMDs start.")
        #expect(!w.spouseSentence.contains("ideal time"))
        #expect(w.alreadyBegunSentence == "Your RMDs have already begun, so part of your lower brackets is already in use.")
    }

    @Test("A nameless spouse is called Your spouse's in the already-begun line")
    func namelessSpousePossessive() {
        let w = window(
            primaryAge: 66, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73,
            spouseName: "")

        #expect(w.alreadyBegunSentence == "Your spouse's RMDs have already begun, so part of your lower brackets is already in use.")
    }

    @Test("The window never promises an ideal time once the Legacy tab has gone silent")
    func windowAgreesWithTheLegacyGapSentence() {
        // The exact contradiction seen on screen: `conversionGapSentence` is
        // nil for a required household, yet the Scenario Builder kept printing
        // the advice. Pin the agreement between the two surfaces directly.
        for primaryAge in [55, 64, 66, 70, 73, 75, 85] {
            for primaryRmdAge in [73, 75] {
                for spouseAge in [55, 60, 66, 70, 73, 85] {
                    for spouseRmdAge in [73, 75] {
                        for spouseEnabled in [true, false] {
                            let p = build(
                                primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
                                spouseEnabled: spouseEnabled,
                                spouseAge: spouseAge, spouseRmdAge: spouseRmdAge,
                                spouseName: "Karen")
                            guard p.conversionGapSentence == nil,
                                  RMDHouseholdStatus.resolve(
                                    primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
                                    spouseEnabled: spouseEnabled,
                                    spouseAge: spouseAge, spouseRmdAge: spouseRmdAge
                                  ).anyoneRequired
                            else { continue }

                            let w = window(
                                primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
                                spouseEnabled: spouseEnabled,
                                spouseAge: spouseAge, spouseRmdAge: spouseRmdAge,
                                spouseName: "Karen")
                            #expect(!w.primarySentence.contains("ideal time"))
                            #expect(!w.spouseSentence.contains("ideal time"))
                            #expect(!(w.alreadyBegunSentence ?? "").contains("ideal time"))
                            // Somebody is required, so the card must say so.
                            #expect(w.alreadyBegunSentence != nil)
                        }
                    }
                }
            }
        }
    }
}

/// The two surfaces outside the RMD card that also announced due-ness from age
/// alone: the CPA briefing's Personal Information table and the Dashboard's
/// header metric.
///
/// These run through the real call sites rather than through
/// `RMDStatusPresentation.build` directly, because the defect being pinned is
/// as much "the caller never told the presentation about balances" as it is
/// "the presentation ignored them".
@Suite("RMD due-ness at the export and dashboard call sites", .serialized)
@MainActor
struct RMDDuenessCallSiteTests {

    /// Primary 64 (RMD age 75) holding traditional money; Karen 73 (RMD age
    /// 73) holding $800,000 of ROTH and no traditional money whatsoever.
    /// Nothing is due from anyone this year.
    private func rothOnlySpouse() -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.filingStatus = .marriedFilingJointly
        dm.selectedState = .florida
        dm.userName = "John"
        dm.spouseName = "Karen"
        dm.birthDate = date(1962)          // age 64, RMD age 75
        dm.enableSpouse = true
        dm.spouseBirthDate = date(1953)    // age 73, RMD age 73
        dm.iraAccounts = [
            IRAAccount(name: "His IRA", accountType: .traditionalIRA,
                       balance: 500_000, owner: .primary),
            IRAAccount(name: "Her Roth", accountType: .rothIRA,
                       balance: 800_000, owner: .spouse)
        ]
        return dm
    }

    /// The same household with Karen's $800,000 in a TRADITIONAL IRA, where
    /// her RMD genuinely is due. Everything must read exactly as it does today.
    private func traditionalSpouse() -> DataManager {
        let dm = rothOnlySpouse()
        dm.iraAccounts = [
            IRAAccount(name: "His IRA", accountType: .traditionalIRA,
                       balance: 500_000, owner: .primary),
            IRAAccount(name: "Her IRA", accountType: .traditionalIRA,
                       balance: 800_000, owner: .spouse)
        ]
        return dm
    }

    private func date(_ year: Int) -> Date {
        var c = DateComponents(); c.year = year; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!
    }

    @Test("The briefing states the Roth-only spouse's age without flagging it as an alert")
    func briefingDoesNotFlagAnAgeAsAnObligation() {
        let dm = rothOnlySpouse()
        #expect(dm.calculateSpouseRMD() == 0)

        let html = PDFExportService.sectionPersonalInfo(PDFExportData(from: dm))

        // Present and truthful: she really has reached RMD age 73.
        #expect(html.contains("<tr><td>Karen RMD Status</td><td>Has reached RMD age 73</td></tr>"))
        // But not printed in the document's alert color, which a CPA reads as
        // an obligation that has not been met.
        #expect(!html.contains("<td class=\"red\">Has reached RMD age 73</td>"))
        #expect(html.contains("<tr><td>John RMD Status</td><td>Reaches RMD age 75 in 11 years</td></tr>"))
    }

    @Test("The briefing DOES flag the spouse whose traditional balance makes it due")
    func briefingStillFlagsARealObligation() {
        let dm = traditionalSpouse()
        #expect(dm.calculateSpouseRMD() > 0)

        let html = PDFExportService.sectionPersonalInfo(PDFExportData(from: dm))

        #expect(html.contains("<tr><td>Karen RMD Status</td><td class=\"red\">Has reached RMD age 73</td></tr>"))
    }

    @Test("The Dashboard header does not read Required for the Roth-only household")
    func dashboardHeaderDoesNotClaimRequired() {
        let metric = DashboardView.rmdHeadlineMetric(rothOnlySpouse())

        #expect(metric.value != "Required")
        #expect(metric.label != "RMD Status")
        // It counts to the first person who will actually owe one: the primary
        // at 75, eleven years out. Karen never will on this balance.
        #expect(metric.label == "Years Until RMD")
        #expect(metric.value == "11")
    }

    @Test("The Dashboard header still reads Required when the money is really there")
    func dashboardHeaderStillClaimsRequiredWhenDue() {
        let metric = DashboardView.rmdHeadlineMetric(traditionalSpouse())

        #expect(metric.label == "RMD Status")
        #expect(metric.value == "Required")
        #expect(metric.detail == "Karen has reached RMD age 73")
    }
}
