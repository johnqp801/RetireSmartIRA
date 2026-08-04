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
    /// Whether ANYONE actually owes a distribution: age reached AND a
    /// traditional balance to take it from.
    ///
    /// Reaching RMD age is not the same as owing money. A Roth IRA has no
    /// required minimum distribution during the owner's lifetime, so a
    /// 73-year-old holding nothing but Roth owes nothing at all. The badge,
    /// the April 1 notices, the document alert flag and the Dashboard headline
    /// all read this rather than the household's age arithmetic, which is what
    /// stops the card announcing a deadline for money that does not exist.
    let anyoneDue: Bool
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

    /// The Multi-Year Plan tab's "Conversion opportunity window" banner.
    ///
    /// The banner counted down from the primary's RMD age alone, so a household
    /// whose spouse is nine years older and already taking distributions read
    /// "You have about 11 years before required minimum distributions begin" on
    /// the Multi-Year tab while the Legacy tab printed nothing at all and the
    /// Scenario Builder said her RMDs had already begun. Three screens, one
    /// household, three answers.
    struct MultiYearBanner: Equatable {
        let title: String
        let message: String
        /// True for the original opportunity banner, false once someone in the
        /// household is already taking distributions. The view reads it for the
        /// icon and tint, so the closed case is not painted as an opportunity.
        let isOpen: Bool
    }

    /// The banner's content, or nil when no banner renders.
    ///
    /// Every household whose text or countdown moves here is one whose banner
    /// today states something FALSE about the household. Nothing else moves:
    ///
    ///  - Primary already required: nil, exactly as today, whatever the spouse
    ///    is doing. `yearsBeforeFirstRMD` was 0 for these households and the
    ///    banner was hidden, so a required single filer is untouched.
    ///  - Nobody required: the original sentence, counting to whoever reaches
    ///    RMDs first rather than to the primary. Those differ only when the
    ///    spouse gets there sooner, which is precisely when today's number is
    ///    wrong; for a single filer they are the same number by construction.
    ///  - Primary still waiting while someone else is already required: the
    ///    promise comes off. Single filers cannot reach this case at all.
    static func multiYearBanner(
        status: RMDHouseholdStatus,
        primaryAge: Int, primaryRmdAge: Int,
        spouseEnabled: Bool, spouseAge: Int, spouseRmdAge: Int,
        spouseName: String
    ) -> MultiYearBanner? {
        // Today's banner is hidden once the primary's own countdown reaches
        // zero, and that stays true: this is a callout about a window the
        // reader still has, and the primary no longer has one.
        guard primaryAge < primaryRmdAge else { return nil }

        guard status.anyoneRequired else {
            // Byte-for-byte the sentence the banner has always shown. The only
            // change is WHOSE countdown it is: the first person in the
            // household to reach RMDs, which for a single filer, and for any
            // couple the primary reaches first, is the same value as before.
            let y = status.yearsUntilFirst
            guard y > 0 else { return nil }
            return MultiYearBanner(
                title: "Conversion opportunity window",
                message: "You have about \(y) year\(y == 1 ? "" : "s") before required minimum distributions begin. These pre-RMD years are often the best window for Roth conversions, while you have the most control over your taxable income.",
                isOpen: true)
        }

        // Someone is already taking distributions. The sentence naming them is
        // the SAME sentence the Scenario Builder prints, taken from the same
        // builder, so the two tabs cannot drift apart again.
        let window = conversionWindow(
            status: status,
            primaryAge: primaryAge, primaryRmdAge: primaryRmdAge,
            spouseEnabled: spouseEnabled, spouseAge: spouseAge, spouseRmdAge: spouseRmdAge,
            spouseName: spouseName)
        guard let begun = window.alreadyBegunSentence else { return nil }

        // The primary's own remaining years are still worth stating, and are
        // still true; what was false was calling them the household's.
        let years = primaryRmdAge - primaryAge
        let unit = years == 1 ? "year" : "years"
        return MultiYearBanner(
            title: "Required distributions have already begun",
            message: "\(begun) Your own required minimum distributions are still about \(years) \(unit) away.",
            isOpen: false)
    }

    /// The Age and RMD columns of the multi-year CPA briefing's year-by-year table.
    ///
    /// The Age column was `year - primaryBirthYear` printed on the same row as
    /// the household's RMD, which sums both spouses. A CPA reading a 2026 row
    /// for a household whose wife is nine years older saw "age 64" beside an
    /// RMD of $45,283 for a man whose own RMD age is 75. That is not merely
    /// incomplete, it is impossible, and the document's reader cannot ask what
    /// was meant.
    struct BriefingAgeColumn: Equatable {
        /// "Age" when one age explains the row, "Ages" when the cell carries two.
        let header: String
        let showsBothAges: Bool
        /// The sentence appended to the table's existing rounding note, or nil
        /// when the single-age table needs no explanation.
        let note: String?

        /// The Age cell for one row. `spouseAge` is ignored unless the column
        /// carries both, so a caller may pass any placeholder for a household
        /// with no spouse.
        func cell(primaryAge: Int, spouseAge: Int) -> String {
            showsBothAges ? "\(primaryAge) / \(spouseAge)" : "\(primaryAge)"
        }
    }

    /// Decides whether the briefing's Age column has to carry two ages.
    ///
    /// The contradiction is possible in exactly one situation: the spouse's
    /// first RMD falls in an EARLIER calendar year than the primary's, so a row
    /// can carry a household RMD while the primary is still below his own RMD
    /// age. Take the first RMD years rather than the RMD ages, since two people
    /// can share an RMD age of 75 and still reach it a decade apart.
    ///
    /// When the spouse reaches RMDs in the same year or later, no row can
    /// contradict itself, and the table renders exactly as it always has. That
    /// covers every single filer and every couple of similar age.
    static func briefingAgeColumn(
        spouseEnabled: Bool,
        primaryFirstRmdYear: Int,
        spouseFirstRmdYear: Int,
        spouseName: String
    ) -> BriefingAgeColumn {
        guard spouseEnabled, spouseFirstRmdYear < primaryFirstRmdYear else {
            return BriefingAgeColumn(header: "Age", showsBothAges: false, note: nil)
        }
        let who = spouseName.isEmpty ? "your spouse" : spouseName
        let possessive = spouseName.isEmpty ? "your spouse's" : "\(spouseName)'s"
        return BriefingAgeColumn(
            header: "Ages",
            showsBothAges: true,
            note: "Ages are shown as you / \(who). The RMD column is the household total for both, "
                + "so it can include \(possessive) required distribution in a year before your own begins.")
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
        firstRmdDeadlineYear: Int,
        primaryHasTraditionalBalance: Bool = true,
        spouseHasTraditionalBalance: Bool = true
    ) -> RMDStatusPresentation {
        // Age says WHEN a distribution would begin; a traditional balance says
        // WHETHER there is one at all. Both parameters default to true so a
        // caller that has not been taught about balances yet gets exactly the
        // age-driven behavior it got before.
        let primaryDue = primaryAge >= primaryRmdAge && primaryHasTraditionalBalance
        let spouseDue = spouseAge >= spouseRmdAge && spouseHasTraditionalBalance
        // When the household collapses to one clock the spouse's AGE is either
        // identical to the primary's or is not a real person's age at all, so
        // only the balances can differ. Reading the spouse's age here is what
        // would let a disabled spouse's placeholder age drive the card.
        let householdHoldsTraditional =
            primaryHasTraditionalBalance || spouseHasTraditionalBalance
        let anyoneDue = status.showsBothPeople
            ? (primaryDue || spouseDue)
            : (status.anyoneRequired && householdHoldsTraditional)

        // "RMDs Required" is a claim about money, so it follows due-ness. The
        // negative case keeps the wording it has always had: it is not a false
        // statement about a Roth-only 73-year-old, and the age lines directly
        // beneath it still say plainly that she has reached her RMD age.
        let badge = anyoneDue ? "RMDs Required" : "Not Yet Required"

        // The countdown counts to the first person who will actually owe
        // something, which is not necessarily the first person to reach RMD
        // age. `status.yearsUntilFirst` is left exactly as it is; this is a
        // display value, and it falls back to it whenever the household holds
        // no traditional money at all or sits on one shared clock.
        let yearsUntilDue: Int = {
            guard status.showsBothPeople else { return status.yearsUntilFirst }
            var candidates: [Int] = []
            if primaryHasTraditionalBalance {
                candidates.append(max(0, primaryRmdAge - primaryAge))
            }
            if spouseHasTraditionalBalance {
                candidates.append(max(0, spouseRmdAge - spouseAge))
            }
            return candidates.min() ?? status.yearsUntilFirst
        }()

        // Only a genuine split in RMD ages earns the "First" qualifier. Two
        // people who share an RMD age but not a birth year still show both
        // lines, yet a single "RMD Age" number remains true for both, so the
        // headline number stays exactly what it is today.
        let showsDistinctAges = status.showsBothPeople && primaryRmdAge != spouseRmdAge
        let ageTitle = showsDistinctAges ? "First RMD Age" : "RMD Age"
        let ageValue = showsDistinctAges ? "\(status.firstRmdAge)" : "\(primaryRmdAge)"

        guard status.showsBothPeople else {
            // One person drives the card, so the notice keeps its original
            // wording with no possessive attached to it. The April 1 deferral
            // is a right over a distribution, so it needs one to exist.
            let notices = primaryAge == primaryRmdAge && householdHoldsTraditional
                ? ["First RMD can be delayed until April 1 \(firstRmdDeadlineYear)"]
                : []
            // One statement is true of everyone here, so every downstream
            // surface keeps the exact single-person shape it has always had.
            let soleRow: DocumentRow
            if anyoneDue {
                soleRow = DocumentRow(label: "RMD Status", value: "Required", isAlert: true)
            } else if status.anyoneRequired {
                // Past the age with nothing to distribute. A CPA reading this
                // document cannot ask a follow-up question, so the row states
                // the age truthfully and is not flagged as an alert.
                soleRow = DocumentRow(
                    label: "RMD Status",
                    value: agePhrase(age: primaryAge, rmdAge: primaryRmdAge),
                    isAlert: false)
            } else {
                soleRow = DocumentRow(
                    label: "RMD Begins",
                    value: "Age \(status.firstRmdAge) (\(status.yearsUntilFirst) years)",
                    isAlert: false)
            }
            return RMDStatusPresentation(
                badge: badge,
                anyoneDue: anyoneDue,
                ageTitle: ageTitle,
                ageValue: ageValue,
                lines: [],
                firstYearNotices: notices,
                sections: bodySections(
                    status: status,
                    showsHouseholdLines: false,
                    hasInheritedRMDs: hasInheritedRMDs),
                headlineMetric: headline(
                    anyoneDue: anyoneDue, yearsUntilDue: yearsUntilDue, detail: nil),
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
        // The April 1 deferral is a right to postpone a distribution, so it
        // belongs only to someone who has one to postpone. Announcing it for a
        // Roth-only spouse, and with it the two-RMDs-in-one-year warning the
        // view hangs off these notices, names a deadline for money that does
        // not exist.
        let primaryNotice = notice(
            who: "Your", age: primaryAge, rmdAge: primaryRmdAge,
            hasTraditionalBalance: primaryHasTraditionalBalance,
            year: firstRmdDeadlineYear)
        let spouseNotice = notice(
            who: spousePossessive, age: spouseAge, rmdAge: spouseRmdAge,
            hasTraditionalBalance: spouseHasTraditionalBalance,
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
        //
        // The VALUE stays an age statement, true whatever the person holds.
        // The ALERT flag is the document's "act on this" mark, so it follows
        // due-ness: a CPA cannot ask a follow-up question of a PDF, and a red
        // row against a Roth-only spouse reads as an unmet obligation.
        let primaryRow = DocumentRow(
            label: "\(primaryName.isEmpty ? "Primary" : primaryName) RMD Status",
            value: agePhrase(age: primaryAge, rmdAge: primaryRmdAge),
            isAlert: primaryDue)
        let spouseRow = DocumentRow(
            label: "\(spouseName.isEmpty ? "Spouse" : spouseName) RMD Status",
            value: agePhrase(age: spouseAge, rmdAge: spouseRmdAge),
            isAlert: spouseDue)
        let documentRows = spouseFirst ? [spouseRow, primaryRow] : [primaryRow, spouseRow]

        // Whoever gets there first is who the one-card surfaces name.
        let firstSubject = spouseFirst ? (spouseName.isEmpty ? "your spouse" : spouseName) : "you"

        return RMDStatusPresentation(
            badge: badge,
            anyoneDue: anyoneDue,
            ageTitle: ageTitle,
            ageValue: ageValue,
            lines: lines,
            firstYearNotices: notices,
            sections: bodySections(
                status: status,
                showsHouseholdLines: true,
                hasInheritedRMDs: hasInheritedRMDs),
            headlineMetric: headline(
                anyoneDue: anyoneDue, yearsUntilDue: yearsUntilDue, detail: lines.first),
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

    /// The Dashboard reads "Required" only when something actually is.
    private static func headline(
        anyoneDue: Bool, yearsUntilDue: Int, detail: String?
    ) -> HeadlineMetric {
        anyoneDue
            ? HeadlineMetric(label: "RMD Status", value: "Required", detail: detail)
            : HeadlineMetric(
                label: "Years Until RMD",
                value: "\(yearsUntilDue)",
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

    private static func notice(
        who: String, age: Int, rmdAge: Int, hasTraditionalBalance: Bool, year: Int
    ) -> String? {
        guard hasTraditionalBalance, age == rmdAge else { return nil }
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
