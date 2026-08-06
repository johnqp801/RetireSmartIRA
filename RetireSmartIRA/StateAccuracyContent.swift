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
