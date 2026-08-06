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

    // MARK: - Limitation sentences

    /// Which surface is rendering a limitation sentence.
    ///
    /// A sentence is stored once and read on more than one surface, and the
    /// surfaces do not all use the same noun for the thing that is wrong.
    /// Hawaii forced this: the pension editor's caption says "This app does
    /// not model the split" and the CPA briefing says "This plan does not
    /// model the split". Both are John's approved copy, both are pinned by
    /// tests, and neither may be edited to make the other unnecessary, so the
    /// stored sentence equals neither and carries `{scope}` where they differ.
    ///
    /// MIRRORS `UnclassifiedPensionDisclosure.Scope` WITHOUT REUSING IT, and
    /// the difference is not cosmetic. That type substitutes whole noun
    /// phrases mid-sentence ("this figure", "this plan"); Hawaii's token sits
    /// after a capitalised "This", so its substitutions are bare nouns.
    /// Sharing one enum would render "This this plan does not model". The
    /// TOKEN is shared, so there is still exactly one placeholder spelling in
    /// the codebase and a reviewer reading any config file sees the same
    /// thing.
    enum LimitationScope {
        /// Anything rendered inside the running app: the pension editor's
        /// caption and the per-state accuracy page.
        case app
        /// The exported CPA briefing, a document describing a multi-year plan
        /// that a preparer reads away from the app.
        case plan

        var substitution: String {
            switch self {
            case .app: "app"
            case .plan: "plan"
            }
        }
    }

    /// Every limitation sentence `state` ships, rendered for `scope`.
    ///
    /// `scope` DEFAULTS to `.app` because every on-screen surface is in the
    /// app and only the exported briefing is not; a default of `.plan` would
    /// be wrong everywhere except one call site. The briefing passes its own
    /// scope explicitly and `renderedLimitationsCarryNoToken` sweeps both.
    static func limitations(for state: USState,
                            scope: LimitationScope = .app) -> [String] {
        StateTaxData.config(for: state).verification.knownLimitations
            .map { render($0, scope: scope) }
    }

    /// Only those of `state`'s limitation sentences whose wording differs
    /// between surfaces, i.e. the ones carrying the scope token, rendered for
    /// `scope`.
    ///
    /// EXISTS SO THE CPA BRIEFING STAYS NARROW. Its Hawaii disclosure is gated
    /// on pension income and is about the employer-funded split specifically;
    /// handing it the whole of `limitations(for: .hawaii)` would silently
    /// widen it to whatever a later task adds to Hawaii's list, including
    /// sentences about brackets or deductions that a pension gate has no
    /// business selecting for.
    static func surfaceDependentLimitations(for state: USState,
                                            scope: LimitationScope) -> [String] {
        StateTaxData.config(for: state).verification.knownLimitations
            .filter { $0.contains(UnclassifiedPensionDisclosure.scopeToken) }
            .map { render($0, scope: scope) }
    }

    private static func render(_ sentence: String, scope: LimitationScope) -> String {
        sentence.replacingOccurrences(of: UnclassifiedPensionDisclosure.scopeToken,
                                      with: scope.substitution)
    }
}
