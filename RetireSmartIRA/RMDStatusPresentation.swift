import Foundation

/// The exact sentences the RMD Status card shows, built as data rather than as
/// SwiftUI view code so every wording and ordering rule is directly testable.
///
/// The card used to read three primary-only values, so a household whose spouse
/// was already past her RMD age could read "Not Yet Required / RMDs start in 9
/// years". That is false, not merely incomplete. Everything that decides WHO
/// leads and WHAT each line says now lives here.
struct RMDStatusPresentation: Equatable {
    /// "RMDs Required" or "Not Yet Required".
    let badge: String
    /// "RMD Age" or "First RMD Age".
    let ageTitle: String
    /// The large number under `ageTitle`.
    let ageValue: String
    /// Zero entries when one person drives the card, otherwise exactly two,
    /// ordered with whoever starts sooner FIRST.
    let lines: [String]

    static func build(
        status: RMDHouseholdStatus,
        primaryAge: Int, primaryRmdAge: Int,
        spouseAge: Int, spouseRmdAge: Int,
        spouseName: String
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
            return RMDStatusPresentation(
                badge: badge, ageTitle: ageTitle, ageValue: ageValue, lines: [])
        }

        // Each line is built ONLY from that person's own age and own RMD age.
        // Never from `status.firstRmdAge`: a shared trigger age attached to two
        // different names is how the earlier misattribution bug read, and a
        // self-contained per-person sentence cannot repeat it.
        let primaryLine = line(who: "Your", age: primaryAge, rmdAge: primaryRmdAge)
        let spouseWho = spouseName.isEmpty ? "Your spouse's" : "\(spouseName)'s"
        let spouseLine = line(who: spouseWho, age: spouseAge, rmdAge: spouseRmdAge)

        let lines = status.startsFirst == .spouse
            ? [spouseLine, primaryLine]
            : [primaryLine, spouseLine]

        return RMDStatusPresentation(
            badge: badge, ageTitle: ageTitle, ageValue: ageValue, lines: lines)
    }

    private static func line(who: String, age: Int, rmdAge: Int) -> String {
        if age >= rmdAge {
            return "\(who) RMDs are required now (began at age \(rmdAge))"
        }
        let years = rmdAge - age
        let unit = years == 1 ? "year" : "years"
        return "\(who) RMDs start in \(years) \(unit) (age \(rmdAge))"
    }
}
