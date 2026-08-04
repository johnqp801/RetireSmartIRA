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
    /// The single label/value/detail triple for surfaces that have room for
    /// exactly one card, such as the Tax Summary header.
    let headlineMetric: HeadlineMetric
    /// The rows an exported document prints under Personal Information. One
    /// row when a single statement is true of the whole household, otherwise
    /// one row per person carrying that person's OWN RMD age.
    let documentRows: [DocumentRow]
    /// The Legacy tab's pre-RMD conversion-window sentence, or nil when anyone
    /// is already required or the window is too short to advise on.
    let conversionGapSentence: String?

    /// A one-card summary of household RMD status.
    ///
    /// The Tax Summary header used to read `dataManager.yearsUntilRMD`
    /// directly, so a household six years into a spouse's RMDs was greeted
    /// with a countdown. `detail` is what names the person once the two are
    /// not in the same position; it stays nil when one statement covers both,
    /// which is what keeps single filers rendering exactly as before.
    struct HeadlineMetric: Equatable {
        let label: String
        let value: String
        let detail: String?
    }

    /// One Personal Information row in the CPA briefing PDF.
    ///
    /// A document read by a third party cannot answer a follow-up question, so
    /// a household with two different RMD ages gets two rows rather than one
    /// row built from the primary's numbers alone.
    struct DocumentRow: Equatable {
        let label: String
        let value: String
        /// Whether the value renders in the document's alert color, preserving
        /// the red "Required" treatment the single-row form has always had.
        let isAlert: Bool
    }

    /// The Scenario Builder's "Conversion Opportunity Window" sentences.
    ///
    /// The card promised "an ideal time for Roth conversions" off the primary's
    /// countdown alone, so a household whose spouse was already taking RMDs
    /// read that promise on one tab while the Legacy tab, looking at the same
    /// household, printed nothing at all because `conversionGapSentence` is nil
    /// once anyone is required. Two screens contradicting each other about one
    /// household is why these sentences live here.
    ///
    /// The per-person visibility gates stay in the view: they decide WHETHER a
    /// person's line shows. This decides only WHAT each line says.
    struct ConversionWindow: Equatable {
        /// The primary's line, shown when the primary is not yet required and
        /// holds a traditional balance.
        let primarySentence: String
        /// The spouse's line, under the equivalent per-person gate.
        let spouseSentence: String
        /// One household line naming whoever has already begun, or nil when
        /// nobody has. It is what stops the card reading as an open window.
        let alreadyBegunSentence: String?
    }

    /// Builds the opportunity-window sentences for the household.
    ///
    /// `spouseName` is the RAW name, not the view's display label, because the
    /// possessive form of a nameless spouse ("Your spouse's") differs from the
    /// subject form ("Spouse").
    static func conversionWindow(
        status: RMDHouseholdStatus,
        primaryAge: Int, primaryRmdAge: Int,
        spouseEnabled: Bool, spouseAge: Int, spouseRmdAge: Int,
        spouseName: String
    ) -> ConversionWindow {
        // These reproduce `yearsUntilRMD` / `spouseYearsUntilRMD` exactly, so
        // the nobody-is-required wording below stays byte-for-byte what the
        // view printed before, for every single filer and every couple still
        // ahead of their RMDs.
        let primaryYears = max(0, primaryRmdAge - primaryAge)
        let spouseYears = max(0, spouseRmdAge - spouseAge)
        // The view's own fallback for a nameless spouse, kept identical.
        let spouseLabel = spouseName.isEmpty ? "Spouse" : spouseName

        guard status.anyoneRequired else {
            return ConversionWindow(
                primarySentence: "You have \(primaryYears) years before RMDs start. This is an ideal time for Roth conversions while potentially in a lower tax bracket.",
                spouseSentence: "\(spouseLabel) has \(spouseYears) years before RMDs start.",
                alreadyBegunSentence: nil)
        }

        // Someone's RMDs are already consuming the low brackets the advice
        // pointed at, so the advice clause comes off and each remaining line
        // states only what is true of that person.
        let primaryRequired = primaryAge >= primaryRmdAge
        let spouseRequired = spouseEnabled && spouseAge >= spouseRmdAge
        let spousePossessive = spouseName.isEmpty ? "Your spouse's" : "\(spouseName)'s"
        let alreadyBegunTail = "RMDs have already begun, so part of your lower brackets is already in use."

        // The subject follows whoever is actually required, never the primary
        // by default: naming the wrong person here is the same misattribution
        // this type was created to end.
        let alreadyBegun: String?
        switch (primaryRequired, spouseRequired) {
        case (true, true):
            alreadyBegun = "Your RMDs and \(spousePossessive) \(alreadyBegunTail)"
        case (true, false):
            alreadyBegun = "Your \(alreadyBegunTail)"
        case (false, true):
            alreadyBegun = "\(spousePossessive) \(alreadyBegunTail)"
        case (false, false):
            alreadyBegun = nil
        }

        return ConversionWindow(
            primarySentence: "You have \(primaryYears) years before your own RMDs start.",
            spouseSentence: "\(spouseLabel) has \(spouseYears) years before \(spouseLabel)'s own RMDs start.",
            alreadyBegunSentence: alreadyBegun)
    }

    /// The label for a figure that already sums both people's RMDs.
    ///
    /// The collapsed Scenarios card called the combined figure "Required RMD"
    /// while the expanded card called the same number "Combined RMDs", so a
    /// user who knew their own RMD saw the household total under a label that
    /// read as personal.
    static func combinedRmdLabel(spouseEnabled: Bool) -> String {
        spouseEnabled ? "Combined RMDs" : "Required RMD"
    }

    /// The action-item title for the primary's own RMD.
    ///
    /// Unqualified "Take RMD" next to a named spouse item read as one personal
    /// instruction plus one unexplained figure. A solo filer has nobody to be
    /// confused with, so that case keeps its original bare wording.
    static func primaryRmdActionTitle(
        primaryName: String, spouseEnabled: Bool, amount: String
    ) -> String {
        guard spouseEnabled else { return "Take RMD: \(amount)" }
        let who = primaryName.isEmpty ? "Your" : "\(primaryName)'s"
        return "Take \(who) RMD: \(amount)"
    }

    /// The action-item title for the spouse's RMD, in the same possessive
    /// shape as the primary's so the pair reads as one list.
    static func spouseRmdActionTitle(spouseName: String, amount: String) -> String {
        let who = spouseName.isEmpty ? "Your spouse's" : "\(spouseName)'s"
        return "Take \(who) RMD: \(amount)"
    }

    static func build(
        status: RMDHouseholdStatus,
        primaryAge: Int, primaryRmdAge: Int,
        spouseAge: Int, spouseRmdAge: Int,
        primaryName: String = "",
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
            // One statement is true of everyone here, so every downstream
            // surface keeps the exact single-person shape it has always had.
            let soleRow = status.anyoneRequired
                ? DocumentRow(label: "RMD Status", value: "Required", isAlert: true)
                : DocumentRow(
                    label: "RMD Begins",
                    value: "Age \(status.firstRmdAge) (\(status.yearsUntilFirst) years)",
                    isAlert: false)
            return RMDStatusPresentation(
                badge: badge,
                ageTitle: ageTitle,
                ageValue: ageValue,
                lines: [],
                firstYearNotices: notices,
                sections: bodySections(
                    status: status,
                    showsHouseholdLines: false,
                    hasInheritedRMDs: hasInheritedRMDs),
                headlineMetric: headline(status: status, detail: nil),
                documentRows: [soleRow],
                conversionGapSentence: gapSentence(
                    status: status,
                    subject: nil))
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

        // Document rows carry each person's OWN RMD age, for the same reason
        // `lines` does: a shared trigger age printed beside two names is the
        // misattribution this whole type exists to prevent. The name fallbacks
        // match the ones the export already uses for its Age rows.
        let primaryRow = DocumentRow(
            label: "\(primaryName.isEmpty ? "Primary" : primaryName) RMD Status",
            value: agePhrase(age: primaryAge, rmdAge: primaryRmdAge),
            isAlert: primaryAge >= primaryRmdAge)
        let spouseRow = DocumentRow(
            label: "\(spouseName.isEmpty ? "Spouse" : spouseName) RMD Status",
            value: agePhrase(age: spouseAge, rmdAge: spouseRmdAge),
            isAlert: spouseAge >= spouseRmdAge)
        let documentRows = spouseFirst ? [spouseRow, primaryRow] : [primaryRow, spouseRow]

        // Whoever gets there first is who the one-card surfaces name.
        let firstSubject = spouseFirst ? (spouseName.isEmpty ? "your spouse" : spouseName) : "you"

        return RMDStatusPresentation(
            badge: badge,
            ageTitle: ageTitle,
            ageValue: ageValue,
            lines: lines,
            firstYearNotices: notices,
            sections: bodySections(
                status: status,
                showsHouseholdLines: true,
                hasInheritedRMDs: hasInheritedRMDs),
            headlineMetric: headline(status: status, detail: lines.first),
            documentRows: documentRows,
            conversionGapSentence: gapSentence(status: status, subject: firstSubject))
    }

    /// "Has reached RMD age 73" / "Reaches RMD age 75 in 14 years".
    ///
    /// The subject is deliberately absent: a document row's label already
    /// carries the name, and the sentence is about an AGE, so it stays true
    /// whatever that person happens to hold.
    private static func agePhrase(age: Int, rmdAge: Int) -> String {
        if age >= rmdAge { return "Has reached RMD age \(rmdAge)" }
        let years = rmdAge - age
        return "Reaches RMD age \(rmdAge) in \(years) \(years == 1 ? "year" : "years")"
    }

    private static func headline(
        status: RMDHouseholdStatus, detail: String?
    ) -> HeadlineMetric {
        status.anyoneRequired
            ? HeadlineMetric(label: "RMD Status", value: "Required", detail: detail)
            : HeadlineMetric(
                label: "Years Until RMD",
                value: "\(status.yearsUntilFirst)",
                detail: detail)
    }

    /// `subject` is nil when one statement covers the household, which keeps
    /// the original single-person sentence byte-for-byte.
    private static func gapSentence(
        status: RMDHouseholdStatus, subject: String?
    ) -> String? {
        // The view only ever showed this advice for a window longer than a
        // single year, and that gate lives here now so it is testable.
        guard !status.anyoneRequired, status.yearsUntilFirst > 1 else { return nil }
        guard let subject else {
            return "You have \(status.yearsUntilFirst) gap years before RMDs start at age \(status.firstRmdAge)."
        }
        return "Your household has \(status.yearsUntilFirst) gap years before RMDs start, when \(subject) reaches RMD age \(status.firstRmdAge)."
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
