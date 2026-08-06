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

    // MARK: - Which jurisdiction each entry point describes

    // TWO ENTRY POINTS, TWO DIFFERENT STATES, and getting this wrong is the
    // failure these functions exist to prevent: a State Comparison sheet
    // opened on Oregon must never show California's disclosure because
    // California is where the user lives.
    //
    // A THIRD RESOLVER, `stateForMultiYear`, WAS REMOVED BEFORE MERGE along
    // with the Multi-Year tab's affordance. Not because it resolved the wrong
    // state, which it did not, but because the page it opened contradicts the
    // figure it sat beside: the multi-year path applies neither the state
    // standard deduction nor the personal exemption the page reports as
    // modelled. Restoring the resolver is the last step of restoring the
    // affordance, not the first; the preconditions are recorded in
    // `ApproachComparisonView` and gated by
    // `StateAccuracyContentTests.noMultiYearSurfacePresentsTheAccuracyPage`.
    //
    // THE ASYMMETRY IS DELIBERATE and is the same one Phase 5b established for
    // the unclassified-pension disclosure. `StateComparisonPresentation` gates
    // on the VIEWED state, because the sheet computes and shows that state's own
    // tax whether or not the viewer lives there; `MultiYearCPABriefing
    // .unclassifiedPensionLimitation` gates on RESIDENCE, because a briefing
    // describes the household's own plan rather than a column they are
    // browsing. Collapsing the two would either silence the sheet for the
    // non-resident comparer it exists to warn, or put another state's mechanics
    // into a document about the user's own plan.
    //
    // WHY TWO ONE-LINE FUNCTIONS RATHER THAN ONE. Each takes only the states
    // its own destination has, and names them, so a call site cannot hand over
    // the wrong one without the label saying so. `stateForSingleYearResults`
    // takes no viewed state at all, because that screen has none;
    // `stateForComparisonSheet` takes both and returns the one its destination
    // is about. A single `state(for:)` taking a destination enum would make
    // both call sites pass the same two arguments and put the choice back
    // inside a switch nobody reads.

    /// The single-year results screen shows the household's own tax, so its
    /// accuracy page describes where the household LIVES.
    ///
    /// There is no viewed state on this screen, and this signature is why one
    /// cannot arrive here by mistake.
    static func stateForSingleYearResults(resident: USState) -> USState {
        resident
    }

    /// The State Comparison detail sheet shows the tax of the state being
    /// INSPECTED, computed for the user's own income, so its accuracy page
    /// describes that state and not the resident's.
    ///
    /// `resident` is taken and deliberately unused. It is what makes the choice
    /// legible at the call site and testable here: a reader of
    /// `stateForComparisonSheet(inspecting: item.state, resident: ...)` can see
    /// which one wins without opening this file, and
    /// `comparisonSheetNeverFallsBackToTheResident` proves the resident never
    /// leaks into the answer.
    static func stateForComparisonSheet(inspecting inspected: USState,
                                        resident _: USState) -> USState {
        inspected
    }

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
            .map { render($0.text, scope: scope) }
    }

    /// Only those of `state`'s limitation sentences that are about how a
    /// pension or other retirement distribution is taxed, rendered for `scope`.
    ///
    /// THE PENSION EDITOR MUST USE THIS, NOT `limitations(for:)`. That section
    /// is headed "What kind of pension is this?" and its whole job is to help a
    /// user classify one plan. A state's full list also carries sentences about
    /// credits and age exemptions, which are true, belong on the per-state
    /// accuracy page, and are noise under a pension picker: Utah's taxpayer tax
    /// credit and retirement credit and New Mexico's age-65 Schedule PIT-ADJ
    /// exemption change tax for a qualifying filer who holds no pension at all,
    /// so showing them there implies the picker affects them.
    ///
    /// The filter is on the sentence's OWN topic, so adding a jurisdiction
    /// stays a data change. Nothing here enumerates states.
    static func pensionLimitations(for state: USState,
                                   scope: LimitationScope = .app) -> [String] {
        StateTaxData.config(for: state).verification.knownLimitations
            .filter { $0.topic == .pension }
            .map { render($0.text, scope: scope) }
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
            .filter { $0.text.contains(UnclassifiedPensionDisclosure.scopeToken) }
            .map { render($0.text, scope: scope) }
    }

    private static func render(_ sentence: String, scope: LimitationScope) -> String {
        sentence.replacingOccurrences(of: UnclassifiedPensionDisclosure.scopeToken,
                                      with: scope.substitution)
    }

    // MARK: - The limitations half

    /// The exact sentence an empty `knownLimitations` renders as.
    ///
    /// JOHN'S WORDING, SPECIFIED CHARACTER FOR CHARACTER, and the most
    /// load-bearing string in this feature. An empty array records what has not
    /// been FOUND for a jurisdiction; it never records that nothing exists. The
    /// 2026-08-02 audit found jurisdictions believed correct on their
    /// retirement exclusions that were wrong on brackets, deductions, credits
    /// and filing-status treatment, so silence here is ignorance, not a
    /// clearance.
    ///
    /// A constant rather than a literal at its one use site so the tests assert
    /// against the shipped string rather than a retyped copy of it, and so a
    /// reviewer grepping for the sentence finds one definition.
    ///
    /// THE COMPLEXITY CAVEAT IS NOT APPENDED HERE, DELIBERATELY, and the reason
    /// is the gate rather than the copy. `modellingCaveatSentence` was approved
    /// by John on 2026-08-06 and now ships on every state page, but it ships as
    /// a SEPARATE always-rendered element. Folding it into this constant would
    /// make one string carry two decisions, and the assertions on this one are
    /// exact equality. A future edit to the caveat would then have to move the
    /// pin on the sentence John specified character for character. See
    /// `modellingCaveatSentence` below.
    static let noRecordedLimitationsSentence =
        "No known limitations are currently recorded for this state and tax year."

    /// The caveat that closes the limitations section on EVERY state page,
    /// whether or not the jurisdiction ships a limitation sentence.
    ///
    /// JOHN'S WORDING, APPROVED 2026-08-06, CHARACTER FOR CHARACTER. The design
    /// (section 1) offered it as an OPTIONAL follow-on to the empty state only.
    /// John widened it to every page, which is the opposite framing, and the
    /// reason is aggregate rather than per-line: Georgia, Iowa and Indiana each
    /// render a verification date, a primary source and "no known limitations
    /// are currently recorded", and while every one of those lines is
    /// individually true, together they read close to a warranty of
    /// completeness. A jurisdiction that DOES ship limitations makes the same
    /// implicit claim about everything its list omits.
    ///
    /// So it is unconditional, and it is a constant rather than a view literal
    /// for the same reason as the sentence above: so the shipped string is what
    /// the tests read.
    static let modellingCaveatSentence =
        "State tax rules are complex, and this does not mean every unusual situation is represented."

    /// What the accuracy page says under "Known limitations" for `state`.
    ///
    /// Returns `noRecordedLimitationsSentence` when nothing is recorded, and the
    /// jurisdiction's sentences otherwise, blank-line separated so a surface
    /// that can only render one string still shows them as separate paragraphs.
    ///
    /// STRONGER LANGUAGE IS OUT OF SCOPE, deliberately. "No known limitations
    /// were identified in our latest verification" would require a recorded
    /// verification SCOPE, meaning a record of what was actually examined, and
    /// an empty array is not that. Iowa and Indiana are the live proof that
    /// this matters inside the covered set: both carry a verification date and
    /// a primary source, and both ship no limitation sentence at all.
    ///
    /// THIS STRING DOES NOT CARRY `modellingCaveatSentence`. The caveat renders
    /// unconditionally, alongside a populated list as well as an empty one, so
    /// it belongs to the SECTION rather than to this summary. A surface that
    /// renders this string alone renders an incomplete section.
    static func limitationsSummary(for state: USState,
                                   scope: LimitationScope = .app) -> String {
        let sentences = limitations(for: state, scope: scope)
        guard !sentences.isEmpty else { return noRecordedLimitationsSentence }
        return sentences.joined(separator: "\n\n")
    }

    // MARK: - The header

    /// The provenance block at the top of the accuracy page.
    ///
    /// Built here rather than in the view because every field is a decision
    /// about what the app is willing to claim, and those decisions have to be
    /// assertable. `StateAccuracyView` renders these strings and composes none
    /// of them.
    struct Header: Equatable, Sendable {
        /// State AND tax year, in ONE string.
        ///
        /// They travel together so that no layout change can separate them.
        /// A bare "Iowa" beside "Verified August 2026" reads as a claim about
        /// Iowa's current law generally, when the configuration describes a
        /// single tax year.
        let title: String

        /// When this jurisdiction was last verified, or an explicit statement
        /// that no date is recorded. Never blank, because a missing line reads
        /// as an absent question rather than an unanswered one.
        let verified: String

        /// The jurisdiction's primary sources, split into a readable label and
        /// a followable URL.
        let sources: [Source]

        /// Shown in place of `sources` when it is empty.
        let noSourcesMessage: String

        /// One primary source: what it is, and where to read it.
        struct Source: Equatable, Identifiable, Sendable {
            let label: String
            let url: URL?
            var id: String { label }
        }
    }

    /// The provenance header for `state`.
    ///
    /// NO YEAR IS EVER INVENTED. A file that states no `taxYear` decodes to the
    /// `0` sentinel, and `StateVerification.statedTaxYear` turns that into
    /// `nil` precisely so this function has to answer for it. Thirty-six
    /// jurisdictions are in that position. `StateTaxDataLoader` resolved their
    /// files out of the 2026 directory, so printing 2026 here would be easy and
    /// would be wrong: it would manufacture a provenance claim the data never
    /// made, on the one page whose purpose is to separate what is known from
    /// what is not.
    ///
    /// APPROVED BY JOHN ON 2026-08-06, as written: the three fallback strings
    /// for the unknown cases, "tax year not recorded", "No verification date
    /// recorded." and "No primary sources recorded." Task 3 added
    /// `statedTaxYear` with deliberately NO fallback string because the wording
    /// was John's to approve; Task 6 drafted these, and they now stand as
    /// shipped copy rather than as a proposal. The task report keeps the
    /// alternatives that were considered and rejected.
    static func header(for state: USState) -> Header {
        let verification = StateTaxData.config(for: state).verification

        let title: String
        if let year = verification.statedTaxYear {
            title = "\(state.rawValue) tax treatment, \(year)"
        } else {
            title = "\(state.rawValue) tax treatment, tax year not recorded"
        }

        let verified: String
        if let formatted = verifiedDate(verification.lastVerified) {
            verified = "Verified \(formatted)."
        } else {
            verified = "No verification date recorded."
        }

        return Header(title: title,
                      verified: verified,
                      sources: verification.primarySources.map(source(from:)),
                      noSourcesMessage: "No primary sources recorded.")
    }

    /// `lastVerified` is stored ISO `yyyy-MM-dd`. Rendered as prose because a
    /// disclosure page is read by people, not parsers.
    ///
    /// Parsed and formatted through a FIXED locale and time zone. A device
    /// locale would make the shipped string differ per reader and make the test
    /// that pins it flaky; a floating time zone would shift the date across a
    /// day boundary for readers west of UTC, printing a verification date one
    /// day earlier than the one recorded.
    ///
    /// Returns `nil` for an empty or unparseable value rather than echoing the
    /// raw string, so the caller states the absence instead of showing
    /// "Verified " followed by nothing.
    private static func verifiedDate(_ isoDate: String) -> String? {
        guard !isoDate.isEmpty else { return nil }
        let parser = DateFormatter()
        parser.locale = fixedLocale
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: isoDate) else { return nil }

        let display = DateFormatter()
        display.locale = fixedLocale
        display.timeZone = TimeZone(identifier: "UTC")
        display.dateFormat = "MMMM d, yyyy"
        return display.string(from: date)
    }

    /// Splits a stored source, which is written "Description: https://url", into
    /// a label a reader can scan and a URL they can open.
    ///
    /// Splits at the URL rather than at the last colon, because several
    /// descriptions contain their own colons and one of them
    /// ("D.C. Code Section 47-1803.02") would otherwise lose half its name.
    private static func source(from stored: String) -> Header.Source {
        guard let schemeStart = stored.range(of: "https://") else {
            return Header.Source(label: stored, url: nil)
        }
        let label = String(stored[stored.startIndex..<schemeStart.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: " :"))
        let address = String(stored[schemeStart.lowerBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Header.Source(label: label.isEmpty ? address : label,
                             url: URL(string: address))
    }

    // MARK: - The factual half

    /// One labelled fact about how this app taxes a jurisdiction.
    ///
    /// `label` IS the identity. The accuracy page renders these in a `ForEach`,
    /// so a repeated label would give SwiftUI two rows sharing one identity, and
    /// the tests key a dictionary by it. `statementLabelsAreUniquePerJurisdiction`
    /// enforces that across all fifty-one jurisdictions and both filing
    /// statuses; it is the reason a state's several per-source rules are joined
    /// into one statement rather than emitted one apiece.
    struct Statement: Equatable, Identifiable, Sendable {
        /// The short noun phrase naming what this fact is about.
        let label: String
        /// The fact itself, already formatted. A bare figure carries no
        /// terminal period ("$3,605"); a sentence does.
        let value: String

        var id: String { label }
    }

    /// What this app applies for `state` and `filingStatus`, in the order the
    /// tax is computed in: rates, then the deductions and exemptions that
    /// reduce the base, then the source-specific carve-outs that override them.
    ///
    /// GENERATED, NEVER AUTHORED. Every figure here is read from the same
    /// `StateTaxConfig` the engine consumes, so the page cannot state a
    /// deduction the engine does not apply. That is a guarantee about the
    /// SOURCE of these numbers and not about the engine's use of them: the
    /// engine carries logic no config expresses (California's exemption
    /// credits are computed in `TaxCalculationEngine` with no config
    /// representation at all), and closing that gap is what the plan's Gate 3
    /// behaviour test is for, not this function.
    ///
    /// ABSENT IS NOT THE SAME AS NONE, and the distinction decides whether a
    /// statement appears at all:
    ///
    ///   - A value the configuration does not carry is OMITTED. Forty-eight
    ///     jurisdictions have no `personalExemption` object, and printing
    ///     "Personal exemption: none" for each would assert a fact the config
    ///     never stated, on a page whose whole purpose is to distinguish what
    ///     is known from what is not.
    ///   - A value the configuration states as nothing is PRINTED. Kansas's
    ///     `pensionExemption` is `.none`, which is a positive statement that
    ///     Kansas grants no general pension exemption, and omitting it would
    ///     leave a Kansas page silent on the question a reader came with.
    ///
    /// LOCAL AND CITY TAX IS DELIBERATELY ABSENT. The plan lists it last, but
    /// no jurisdiction's configuration carries a local rate: local tax reaches
    /// the engine as `calculateStateTax(localIncomeTaxRate:)`, a figure the
    /// user types in, so there is nothing per-state to report and the rule
    /// above omits it. See the task report.
    static func factualStatements(for state: USState,
                                  filingStatus: FilingStatus) -> [Statement] {
        let config = StateTaxData.config(for: state)
        let exemptions = config.retirementExemptions

        // A jurisdiction that taxes none of the income this app models has no
        // bracket, deduction or exemption worth describing, and describing one
        // would mislead: "Pension exemption: fully exempt" for Texas implies a
        // Texas income tax that grants an exemption. The engine agrees before
        // any of those fields is consulted, returning 0 for both cases.
        guard config.taxSystem.hasIncomeTax else {
            return [Statement(label: "Tax rates", value: untaxedDescription(config.taxSystem))]
        }

        var statements: [Statement] = [
            Statement(label: "Tax rates",
                      value: rateDescription(config.taxSystem, filingStatus: filingStatus)),
            Statement(label: "Standard deduction",
                      value: deductionDescription(config.stateDeduction, filingStatus: filingStatus))
        ]

        if let personalExemption = config.personalExemption {
            statements.append(Statement(
                label: "Personal exemption",
                value: personalExemptionDescription(personalExemption, filingStatus: filingStatus)))
        }

        statements.append(Statement(
            label: "Social Security",
            value: exemptions.socialSecurityExempt
                ? "Not taxed by this state."
                : "Taxed as ordinary income."))

        statements.append(Statement(
            label: "Pension exemption",
            value: pensionExemptionDescription(exemptions, filingStatus: filingStatus)))

        statements.append(Statement(
            label: "IRA and 401(k) exemption",
            value: iraExemptionDescription(exemptions, filingStatus: filingStatus)))

        // DIRECTLY AFTER THE IRA LINE, AND THAT PLACEMENT IS THE POINT. A Roth
        // conversion IS an IRA distribution, so the statement above is the one a
        // reader will otherwise apply to it, and in two of the four
        // jurisdictions carrying a rule it says the opposite of the truth. Iowa
        // is the live proof: its IRA line reads "None. IRA and 401(k)
        // withdrawals are taxed as ordinary income", while its conversion is
        // exempt from age 55. A correction has to sit beside the statement it
        // corrects, so it goes here rather than after the per-source rules,
        // which are about pensions by source and say nothing about conversions.
        //
        // WHY IT IS ON THIS PAGE AT ALL. This is a Roth conversion planning
        // app, and Pennsylvania exempts the conversion outright: a Pennsylvania
        // household converting $200,000 assumes a state cost of roughly $6,140
        // the engine never charges. Of everything a config holds, this is the
        // fact most likely to change what a user decides to do.
        if let conversionRule = exemptions.rothConversionExemption {
            statements.append(Statement(
                label: "Roth conversions",
                value: rothConversionDescription(conversionRule)))
        }

        if !exemptions.perSourceExemptions.isEmpty {
            statements.append(Statement(
                label: "Rules by pension source",
                value: exemptions.perSourceExemptions
                    .map { perSourceDescription($0, state: state) }
                    .joined(separator: " ")))
        }

        return statements
    }

    // MARK: - Rendering the configuration, one field at a time

    private static func untaxedDescription(_ system: StateTaxSystem) -> String {
        switch system {
        case .noIncomeTax:
            "This state has no income tax."
        case .specialLimited:
            // NH taxes interest and dividends, WA taxes certain capital gains.
            // The configuration records neither, only that the system is
            // limited, so the sentence says what this app does rather than
            // naming categories no field carries.
            "This state taxes only limited categories of income, and this app applies no state income tax to the income it models."
        case .flat, .progressive:
            // Unreachable: the caller guards on `hasIncomeTax`. Stated rather
            // than crashed, because a wrong sentence on a disclosure page is
            // better than a trap in a shipped consumer app.
            "This state taxes income."
        }
    }

    private static func rateDescription(_ system: StateTaxSystem,
                                        filingStatus: FilingStatus) -> String {
        switch system {
        case .flat(let rate):
            return "\(percent(rate)) of taxable income"
        case .progressive(let single, let married):
            let brackets = filingStatus == .single ? single : married
            guard !brackets.isEmpty else { return "No brackets are configured for this state" }
            var parts: [String] = []
            for (index, bracket) in brackets.enumerated() {
                if index + 1 < brackets.count {
                    parts.append("\(percent(bracket.rate)) up to \(money(brackets[index + 1].threshold))")
                } else if parts.isEmpty {
                    parts.append("\(percent(bracket.rate)) of taxable income")
                } else {
                    parts.append("then \(percent(bracket.rate))")
                }
            }
            return parts.joined(separator: ", ")
        case .noIncomeTax, .specialLimited:
            return untaxedDescription(system)
        }
    }

    private static func deductionDescription(_ deduction: StateDeduction,
                                             filingStatus: FilingStatus) -> String {
        switch deduction {
        case .fixed(let single, let married):
            money(filingStatus == .single ? single : married)
        case .conformsToFederal:
            "This state starts from your federal taxable income, so your federal deduction carries over."
        case .none:
            "This state grants no standard deduction."
        }
    }

    private static func personalExemptionDescription(_ exemption: StatePersonalExemption,
                                                     filingStatus: FilingStatus) -> String {
        let base = filingStatus == .single ? exemption.single : exemption.marriedFilingJointly
        guard exemption.seniorAdditionalPerFiler > 0 else { return money(base) }
        return "\(money(base)), plus \(money(exemption.seniorAdditionalPerFiler)) for each filer aged \(exemption.seniorAge) or older"
    }

    private static func pensionExemptionDescription(_ exemptions: RetirementIncomeExemptions,
                                                    filingStatus: FilingStatus) -> String {
        var sentences: [String] = []

        switch exemptions.pensionExemption {
        case .none:
            // A state whose only exclusion is source-specific (Kansas,
            // Massachusetts, DC) says so here rather than "None", because the
            // source rule that follows contradicts a flat "None" and a reader
            // stopping at this line would conclude their KPERS pension is
            // taxable.
            sentences.append(exemptions.perSourceExemptions.isEmpty
                             ? "None. Pension income is taxed as ordinary income."
                             : "No general exemption.")
        case .full:
            sentences.append("Fully exempt.")
        case .partial(let maxExempt):
            var first = "Up to \(money(maxExempt)) exempt"
            if exemptions.pensionAndIRAShareSingleCap {
                first += ", as one cap covering pension and IRA income together"
            }
            if exemptions.exemptionAppliesPerIndividual {
                first += ", and the cap applies to each qualifying spouse"
            }
            sentences.append(first + ".")
        case .steppedPhaseoutByFilingStatus(let maxExemptSingle, let maxExemptMFJ, let tiers):
            sentences.append(steppedDescription(
                cap: filingStatus == .single ? maxExemptSingle : maxExemptMFJ,
                tiers: tiers))
        }

        sentences.append(contentsOf: ageQualifiers(exemptions))
        return sentences.joined(separator: " ")
    }

    private static func iraExemptionDescription(_ exemptions: RetirementIncomeExemptions,
                                                filingStatus: FilingStatus) -> String {
        // The engine ignores this field's own cap when the two share one, so a
        // page that restated it would claim a second exclusion nobody gets.
        if exemptions.pensionAndIRAShareSingleCap {
            return "Shares the single cap stated for the pension exemption, rather than adding a second one."
        }

        var sentences: [String] = []
        switch exemptions.iraWithdrawalExemption {
        case .none:
            sentences.append(exemptions.perSourceExemptions.isEmpty
                             ? "None. IRA and 401(k) withdrawals are taxed as ordinary income."
                             : "No general exemption.")
        case .full:
            sentences.append("Fully exempt.")
        case .partial(let maxExempt):
            var first = "Up to \(money(maxExempt)) exempt"
            if exemptions.exemptionAppliesPerIndividual {
                first += ", and the cap applies to each qualifying spouse"
            }
            sentences.append(first + ".")
        case .steppedPhaseoutByFilingStatus(let maxExemptSingle, let maxExemptMFJ, let tiers):
            sentences.append(steppedDescription(
                cap: filingStatus == .single ? maxExemptSingle : maxExemptMFJ,
                tiers: tiers))
        }

        sentences.append(contentsOf: ageQualifiers(exemptions))
        return sentences.joined(separator: " ")
    }

    /// How this app treats a Roth conversion in the year it is made.
    ///
    /// APPROVED BY JOHN ON 2026-08-06, as written, in the pattern Tasks 3 and 4
    /// set: it ships as final copy, not as a proposal, and the task report keeps
    /// the alternatives that were considered and rejected. The Pennsylvania
    /// caveat is the notable one, because PA exempts the conversion but NOT the
    /// portion withheld for federal tax, and this page is the only surface that
    /// states that. The label is "Roth conversions" and the leading
    /// clause is "Not taxed by this state", matching the Social Security
    /// statement word for word so that two exemptions from the same state's tax
    /// do not read as two different kinds of thing.
    ///
    /// THE FOUR CONFIGS ARE NOT UNIFORM and this renders each rather than
    /// flattening them. Illinois and Mississippi gate on nothing. Pennsylvania
    /// gates on nothing but keeps the withheld portion taxable, because DOR Ans
    /// 274 holds the exemption reaches only what is actually deposited into the
    /// Roth. Iowa gates on age 55 and is the only one that does. Printing the
    /// Pennsylvania caveat on an Illinois page would understate an exemption
    /// Illinois grants in full; dropping Iowa's age gate would offer a
    /// 54 year old an exemption the engine will not give them.
    ///
    /// The two conditions compose, so a future config setting both renders both
    /// without a fifth branch. No jurisdiction ships that combination today.
    private static func rothConversionDescription(_ rule: RothConversionExemption) -> String {
        var sentence = "Not taxed by this state"
        if rule.minAge > 0 {
            sentence += " from age \(rule.minAge)"
        }
        sentence += "."
        if rule.withheldPortionRemainsTaxable {
            sentence += " Any part of the conversion withheld for federal tax does not reach the Roth account, so that part stays taxable."
        }
        return sentence
    }

    /// New Jersey's is the only stepped exclusion that ships, and its shape is
    /// read from the tiers rather than restated, so a rate change in the JSON
    /// moves this sentence with it.
    private static func steppedDescription(
        cap: Double,
        tiers: [RetirementIncomeExemptions.PhaseoutTier]
    ) -> String {
        var sentence = "Up to \(money(cap)) exempt"
        // The top of the band that still retains the whole exclusion.
        if let fullBandTop = tiers.last(where: { $0.mfjPercent >= 1.0 && $0.upperBound.isFinite })?.upperBound {
            sentence += ", reduced in steps once total income passes \(money(fullBandTop))"
        }
        // The floor of the first band retaining nothing is the previous band's
        // top, because bands are inclusive of their upper bound.
        if let cliffIndex = tiers.firstIndex(where: { $0.mfjPercent == 0 }), cliffIndex > 0 {
            sentence += ", and unavailable above \(money(tiers[cliffIndex - 1].upperBound))"
        }
        return sentence + "."
    }

    /// The age and attribution qualifiers both exemptions share.
    private static func ageQualifiers(_ exemptions: RetirementIncomeExemptions) -> [String] {
        var sentences: [String] = []
        if exemptions.regularExemptionMinAge > 0 {
            sentences.append("Applies from age \(exemptions.regularExemptionMinAge).")
        }
        if let tier = exemptions.earlyAgeTier, case .partial(let maxExempt) = tier.level {
            sentences.append("A reduced exemption of \(money(maxExempt)) applies from age \(tier.ageRange.lowerBound) to \(tier.ageRange.upperBound).")
        }
        if exemptions.exemptionAttribution == .perQualifyingSpouse {
            sentences.append("Each spouse's exemption is gated by that spouse's own age.")
        }
        return sentences
    }

    /// One per-source rule as a sentence.
    ///
    /// WRITTEN IN THE PLURAL ON PURPOSE. The singular needs an article, and the
    /// article depends on the first source phrase ("a private employer pension"
    /// against "an unidentified government pension"), so a singular template
    /// produces "a another state's government pension" the first time a rule
    /// leads with a vowel. The plural needs no article and matches the spec's
    /// own example wording.
    private static func perSourceDescription(_ rule: PerSourceExemptionRule,
                                             state: USState) -> String {
        let sources = rule.matchSources.isEmpty
            ? "Retirement income from any source"
            : andList(rule.matchSources.map { sourcePhrase($0, state: state) })
        let structures = rule.matchStructures.isEmpty
            ? ""
            : " " + andList(rule.matchStructures.map(structurePhrase))

        var sentence = capitalizingFirst(sources) + structures
        switch rule.matchIsSurvivorBenefit {
        case .some(true): sentence += " paid as a survivor benefit"
        case .some(false): sentence += " that are not survivor benefits"
        case .none: break
        }

        switch rule.treatment {
        case .none: sentence += " are not exempt"
        case .full: sentence += " are fully exempt"
        case .partial(let maxExempt): sentence += " are exempt up to \(money(maxExempt))"
        case .steppedPhaseoutByFilingStatus: sentence += " are exempt under this state's stepped exclusion"
        }

        if let minimumAge = rule.matchMinAge {
            sentence += " once the recipient is \(minimumAge) or older"
        }
        return sentence + "."
    }

    private static func sourcePhrase(_ source: PlanSource, state: USState) -> String {
        switch source {
        case .nyStateOrLocal: "New York State or local government"
        case .federalCivilian: "federal civilian service"
        case .uniformedServices: "military"
        case .railroadRetirement: "Railroad Retirement"
        // Named rather than called "this state" so the sentence still reads
        // correctly for the District of Columbia, which is not one.
        case .ownStateOrLocal: "\(state.rawValue) government"
        case .otherStateOrLocal: "another state's government"
        case .governmentUnspecified: "unidentified government"
        case .privateEmployer: "private employer"
        case .individual: "individually established"
        case .unknown: "unclassified"
        }
    }

    private static func structurePhrase(_ structure: PlanStructure) -> String {
        switch structure {
        case .definedBenefit: "pensions"
        case .definedContribution: "401(k), 403(b) and 457 plans"
        case .ira: "IRAs"
        case .unknown: "accounts"
        }
    }

    // MARK: - Formatting

    /// Fixed to `en_US_POSIX` rather than the reader's locale, so the shipped
    /// figures and the tests that pin them agree on every device. These are
    /// United States tax figures in United States dollars in every case.
    private static let fixedLocale = Locale(identifier: "en_US_POSIX")

    private static func money(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = fixedLocale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .halfUp
        return "$" + (formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))")
    }

    private static func percent(_ rate: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = fixedLocale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        // Three places, because New Jersey's 5.525% needs them and rounding to
        // two would print a rate no filer is charged.
        formatter.maximumFractionDigits = 3
        formatter.roundingMode = .halfUp
        let scaled = rate * 100
        return (formatter.string(from: NSNumber(value: scaled)) ?? "\(scaled)") + "%"
    }

    private static func andList(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + " and " + (items.last ?? "")
        }
    }

    private static func capitalizingFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }
}
