import Foundation

/// Pure, view-free source of the per-state accuracy page's content.
///
/// Later tasks add the factual statements and the limitation list. This task
/// adds only the scope: which jurisdictions this release authors a populated
/// page for.
enum StateAccuracyContent {

    /// The jurisdictions this release populates with verification metadata and
    /// limitation sentences.
    ///
    /// WHY THESE FIFTEEN. The set is the union of three groups:
    ///
    /// 1. the nine jurisdictions Phase 5 corrected, whose bundled JSON has
    ///    already diverged from the frozen legacy table (KS, IA, NM, GA, UT,
    ///    IN, MA, AZ, DC);
    /// 2. the nine jurisdictions carrying a `knownButUnpinned` catalogue entry
    ///    (AZ, MO, KS, MA, HI, NC, ID, DC, NY);
    /// 3. the six states whose pension editor shows a caption (HI, MA, DC, NC,
    ///    ID, VT), because those captions move into
    ///    `verification.knownLimitations` and a caption cannot render from a
    ///    config this set does not cover.
    ///
    /// Vermont enters only through group 3. Georgia, Iowa and Indiana enter
    /// only through group 1.
    ///
    /// WHY NOT ALL FIFTY-ONE. Twenty-one further states carry pinned defects
    /// and are deliberately absent. Covering them would mean sourcing
    /// thirty-six more jurisdictions' primary references, which is a separate
    /// body of work that has not been scoped or approved. Membership here is
    /// therefore a statement about what this release authored, NOT a statement
    /// that the states outside it are clean.
    ///
    /// Widening the scope later is this one declaration plus the metadata the
    /// added jurisdictions need; the gate in `StateAccuracyContentTests` reads
    /// the set and needs no change.
    static let coveredJurisdictions: Set<USState> = [
        .kansas, .massachusetts, .hawaii, .arizona, .northCarolina, .idaho,
        .vermont, .districtOfColumbia, .newYork, .missouri,
        .iowa, .newMexico, .georgia, .utah, .indiana
    ]
}
