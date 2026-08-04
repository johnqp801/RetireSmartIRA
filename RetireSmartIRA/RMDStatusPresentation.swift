import Foundation

/// The exact sentences the RMD Status card shows, built as data rather than as
/// SwiftUI view code so every wording and ordering rule is directly testable.
///
/// The card used to read three primary-only values, so a household whose spouse
/// was already past her RMD age could read "Not Yet Required / RMDs start in 9
/// years". That is false, not merely incomplete. Everything that decides WHO
/// leads, WHAT each line says, and WHICH body blocks render now lives here.
struct RMDStatusPresentation: Equatable {
    /// Which blocks of the card body render. These are decided here, and the
    /// view reads them rather than re-deriving conditions inline, so the tests
    /// actually govern what appears on screen. Reverting any one of them to a
    /// primary-only condition in the view would otherwise leave the old wrong
    /// countdown printing underneath the correct lines with every test green.
    struct BodySections: Equatable {
        let showsHouseholdLines: Bool
        let showsDeadlines: Bool
        /// The inherited-IRA block, which replaces the deadline block when
        /// nobody's own RMD has started yet.
        let showsInheritedCountdown: Bool
        /// The original single-person "RMDs start in N years" sentence.
        let showsLegacyCountdown: Bool
    }

    /// "RMDs Required" or "Not Yet Required".
    let badge: String
    /// "RMD Age" or "First RMD Age".
    let ageTitle: String
    /// The large number under `ageTitle`.
    let ageValue: String
    /// Zero entries when one person drives the card, otherwise exactly two,
    /// ordered with whoever starts sooner FIRST.
    ///
    /// Each sentence is a statement about an AGE, never about account balances.
    /// The type is given ages and nothing else, so "Karen has reached RMD age
    /// 73" is a claim it can support; "Karen's RMDs are required now" would not
    /// be, since she may hold no traditional IRA at all.
    let lines: [String]
    /// One entry per person currently in their FIRST RMD year, ordered the same
    /// way `lines` is. The April 1 deferral is a per-person right, so a spouse
    /// in her first RMD year must get the notice even when the primary is years
    /// away from his.
    let firstYearNotices: [String]
    /// Which body blocks the view renders.
    let sections: BodySections

    static func build(
        status: RMDHouseholdStatus,
        primaryAge: Int, primaryRmdAge: Int,
        spouseAge: Int, spouseRmdAge: Int,
        spouseName: String,
        hasInheritedRMDs: Bool,
        firstRmdDeadlineYear: Int
    ) -> RMDStatusPresentation {
        let badge = status.anyoneRequired ? "RMDs Required" : "Not Yet Required"

        // Only a genuine split in RMD ages earns the "First" qualifier. Two
        // people who share an RMD age but not a birth year still show both
        // lines, yet a single "RMD Age" number remains true for both, so the
        // headline number stays exactly what it is today.
        let showsDistinctAges = status.showsBothPeople && primaryRmdAge != spouseRmdAge
        let ageTitle = showsDistinctAges ? "First RMD Age" : "RMD Age"
        let ageValue = showsDistinctAges ? "\(status.firstRmdAge)" : "\(primaryRmdAge)"

        guard status.showsBothPeople else {
            // One person drives the card, so the notice keeps its original
            // wording with no possessive attached to it.
            let notices = primaryAge == primaryRmdAge
                ? ["First RMD can be delayed until April 1 \(firstRmdDeadlineYear)"]
                : []
            return RMDStatusPresentation(
                badge: badge,
                ageTitle: ageTitle,
                ageValue: ageValue,
                lines: [],
                firstYearNotices: notices,
                sections: bodySections(
                    status: status,
                    showsHouseholdLines: false,
                    hasInheritedRMDs: hasInheritedRMDs))
        }

        // Each line is built ONLY from that person's own age and own RMD age.
        // Never from `status.firstRmdAge`: a shared trigger age attached to two
        // different names is how the earlier misattribution bug read, and a
        // self-contained per-person sentence cannot repeat it. Each sentence is
        // also strictly about an AGE, since balances are not an input here.
        let primaryLine = line(
            subject: "You", isThirdPerson: false, age: primaryAge, rmdAge: primaryRmdAge)
        let spouseSubject = spouseName.isEmpty ? "Your spouse" : spouseName
        let spouseLine = line(
            subject: spouseSubject, isThirdPerson: true, age: spouseAge, rmdAge: spouseRmdAge)

        let spousePossessive = spouseName.isEmpty ? "Your spouse's" : "\(spouseName)'s"
        let primaryNotice = notice(
            who: "Your", age: primaryAge, rmdAge: primaryRmdAge, year: firstRmdDeadlineYear)
        let spouseNotice = notice(
            who: spousePossessive, age: spouseAge, rmdAge: spouseRmdAge,
            year: firstRmdDeadlineYear)

        let spouseFirst = status.startsFirst == .spouse
        let lines = spouseFirst ? [spouseLine, primaryLine] : [primaryLine, spouseLine]
        let notices = spouseFirst
            ? [spouseNotice, primaryNotice].compactMap { $0 }
            : [primaryNotice, spouseNotice].compactMap { $0 }

        return RMDStatusPresentation(
            badge: badge,
            ageTitle: ageTitle,
            ageValue: ageValue,
            lines: lines,
            firstYearNotices: notices,
            sections: bodySections(
                status: status,
                showsHouseholdLines: true,
                hasInheritedRMDs: hasInheritedRMDs))
    }

    private static func line(
        subject: String, isThirdPerson: Bool, age: Int, rmdAge: Int
    ) -> String {
        if age >= rmdAge {
            return "\(subject) \(isThirdPerson ? "has" : "have") reached RMD age \(rmdAge)"
        }
        let years = rmdAge - age
        let unit = years == 1 ? "year" : "years"
        return "\(subject) \(isThirdPerson ? "reaches" : "reach") RMD age \(rmdAge) in \(years) \(unit)"
    }

    private static func notice(who: String, age: Int, rmdAge: Int, year: Int) -> String? {
        guard age == rmdAge else { return nil }
        return "\(who) first RMD can be delayed until April 1 \(year)"
    }

    private static func bodySections(
        status: RMDHouseholdStatus, showsHouseholdLines: Bool, hasInheritedRMDs: Bool
    ) -> BodySections {
        // The three lower blocks are one exclusive chain in the view, in this
        // order, so at most one of them can be true at a time.
        BodySections(
            showsHouseholdLines: showsHouseholdLines,
            showsDeadlines: status.anyoneRequired,
            showsInheritedCountdown: !status.anyoneRequired && hasInheritedRMDs,
            showsLegacyCountdown:
                !status.anyoneRequired && !hasInheritedRMDs && !showsHouseholdLines)
    }
}
