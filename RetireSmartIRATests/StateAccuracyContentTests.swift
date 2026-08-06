//
//  StateAccuracyContentTests.swift
//  RetireSmartIRATests
//
//  Per-state accuracy disclosure, Task 1. The three captions below were inline
//  string literals inside `IncomeSourcesView`'s view body until this task, which
//  meant no test could reach them and no test did. Two Phase 5b reviews recorded
//  that as a gap. Task 3 moves all six captions out to
//  `StateVerification.knownLimitations` so a single config field is the one place
//  a limitation sentence is written; that move is only provably lossless if the
//  strings are pinned BEFORE it, which is what this file does.
//
//  The literals here were extracted from the committed file rather than retyped,
//  so a drifted apostrophe or a doubled space cannot enter through this file.
//  All three are pure ASCII.
//
//  This copy is John's, approved 2026-08-05 one sentence at a time. If a caption
//  is reworded, this file is where the new wording must be recorded deliberately;
//  a failure here means someone changed approved copy, not that the test is stale.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State accuracy disclosure")
struct StateAccuracyContentTests {

    /// The three captions that were inline view-body literals before this task.
    /// Pinned so the hoist is provably lossless; Task 3 moves them to config and
    /// re-asserts the same strings from their new home.
    ///
    /// NOTE ON PLACEMENT: the plan's Interfaces section names these
    /// `PlanClassificationChoice.*`, but the three pre-existing captions are
    /// `IncomeSourcesView` statics and the plan says `PlanClassificationChoice`
    /// for those too, so it is a uniform type-name slip in the plan rather than a
    /// design intent to split six related constants across two types.
    @MainActor
    @Test("The three hoisted captions match the literals they replaced")
    func hoistedCaptionsAreUnchanged() {
        #expect(IncomeSourcesView.hawaiiEmployerFundedCaption ==
            "Hawaii excludes the employer-funded portion of a pension from state tax. This app does not model the split between employer-funded and employee-contributed amounts, so your Hawaii state tax may be overstated.")
        #expect(IncomeSourcesView.massachusettsContributoryCaption ==
            "Massachusetts excludes a contributory state or local pension but taxes a noncontributory one. This app does not model that distinction, so if your pension is noncontributory your Massachusetts state tax may be understated.")
        #expect(IncomeSourcesView.districtOfColumbiaSurvivorToggleCaption ==
            "The District of Columbia excludes a DC or federal government survivor annuity from tax once the survivor is 62 or older, but taxes an annuitant's own pension in full. Turn this on only for a pension paid to you as someone else's survivor or beneficiary.")
    }

    /// The hoist must not have introduced a dash character into approved copy,
    /// and must not have disturbed the three captions that were already statics.
    ///
    /// The dash and whitespace sweep covers all six. The direction pin covers
    /// only the two captions that carry a direction word, and it is those two
    /// that are load-bearing: Hawaii runs toward OVER-taxation and Massachusetts
    /// toward UNDER-taxation, so a copy edit that harmonised the pair would
    /// invert one of them. The other four say nothing about direction. DC's in
    /// particular is a scoping instruction ("turn this on only for..."), so
    /// there is no direction here for a test to pin, and this comment does not
    /// claim one.
    @MainActor
    @Test("All six pension-editor captions are dash-free, and the Hawaii and Massachusetts directions stay opposed")
    func captionsKeepTheirDirection() {
        let all = [
            IncomeSourcesView.hawaiiEmployerFundedCaption,
            IncomeSourcesView.massachusettsContributoryCaption,
            IncomeSourcesView.districtOfColumbiaSurvivorToggleCaption,
            IncomeSourcesView.northCarolinaBaileyCaption,
            IncomeSourcesView.idahoRetirementBenefitsDeductionCaption,
            IncomeSourcesView.vermontRetirementExclusionCaption
        ]
        for caption in all {
            #expect(!caption.contains("\u{2014}") && !caption.contains("\u{2013}"),
                    "no em or en dash in user-facing copy")
            #expect(!caption.contains("  "), "no doubled space in user-facing copy")
            #expect(caption == caption.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // One pin per direction, symmetrically. Hawaii previously also carried
        // a negative assertion that it does NOT contain "understated"; that
        // bought nothing the positive pin does not already give, and
        // Massachusetts never had its mirror image, so the asymmetry read as
        // meaningful when it was not.
        #expect(IncomeSourcesView.hawaiiEmployerFundedCaption.contains("overstated"))
        #expect(IncomeSourcesView.massachusettsContributoryCaption.contains("understated"))
    }

    // MARK: - Gate 2: the move to config is lossless

    /// Gate 2, TEMPORARY. Proves the relocation was lossless. Once merged, the
    /// permanent assertions are the structural ones in Gate 1; John may approve
    /// a copy change later without fighting this snapshot.
    ///
    /// Reads the RENDERED string, not the stored one. Hawaii's stored sentence
    /// carries a scope token and is 212 characters; neither of the two approved
    /// wordings it produces is, so an assertion against the stored form would
    /// fail by construction. See `hawaiiSentenceServesBothSurfaces` below.
    ///
    /// DC's survivor-toggle caption is deliberately absent. It is not a
    /// limitation: it is the instruction for a control ("Turn this on only
    /// for..."), it renders inside the survivor-toggle branch rather than
    /// alongside the other captions, and moving it into `knownLimitations`
    /// would show it to every DC resident whether or not the toggle is on
    /// screen. It stays a view static.
    @MainActor
    @Test("Each moved caption reproduces byte for byte from its new home in config")
    func movedCaptionsAreByteIdentical() {
        let cases: [(USState, String)] = [
            (.hawaii, IncomeSourcesView.hawaiiEmployerFundedCaption),
            (.massachusetts, IncomeSourcesView.massachusettsContributoryCaption),
            (.northCarolina, IncomeSourcesView.northCarolinaBaileyCaption),
            (.idaho, IncomeSourcesView.idahoRetirementBenefitsDeductionCaption),
            (.vermont, IncomeSourcesView.vermontRetirementExclusionCaption)
        ]
        for (state, expected) in cases {
            #expect(StateAccuracyContent.limitations(for: state).contains(expected),
                    "\(state.abbreviation)'s caption did not survive the move to config")
        }
    }

    /// Hawaii's caption and `MultiYearCPABriefing.hawaiiPensionSplitLimitation`
    /// are the SAME approved sentence differing in exactly one word: the caption
    /// says "This app does not model", the briefing says "This plan does not
    /// model". They are 208 and 209 characters. Both are John's copy, both are
    /// pinned, and one stored string cannot equal both.
    ///
    /// So the stored string equals NEITHER: it carries `{scope}` where they
    /// differ, and each surface substitutes its own word, which is the
    /// mechanism Phase 5b already uses for `unclassifiedPensionDisclosure`.
    /// The two literals below were extracted from the parent commit rather
    /// than retyped.
    ///
    /// This is the only collision of its kind. A normalized sweep of every
    /// string literal of 60 characters or more across `RetireSmartIRA/`, with
    /// Swift's multi-line concatenations joined and "this app|plan|figure"
    /// folded together, found no other sentence shared by two surfaces.
    @MainActor
    @Test("Hawaii's one stored sentence renders both approved wordings, and neither surface sees the token")
    func hawaiiSentenceServesBothSurfaces() throws {
        let stored = try #require(
            StateTaxData.config(for: .hawaii).verification.knownLimitations.first {
                $0.text.contains(UnclassifiedPensionDisclosure.scopeToken)
            }?.text,
            "Hawaii ships no scope-token limitation, so it cannot serve both surfaces")

        let tokenCount = stored.components(
            separatedBy: UnclassifiedPensionDisclosure.scopeToken).count - 1
        #expect(tokenCount == 1, "expected exactly one scope token, found \(tokenCount)")

        let inApp = try #require(
            StateAccuracyContent.surfaceDependentLimitations(for: .hawaii, scope: .app).first)
        #expect(inApp == IncomeSourcesView.hawaiiEmployerFundedCaption)
        #expect(inApp ==
            "Hawaii excludes the employer-funded portion of a pension from state tax. This app does not model the split between employer-funded and employee-contributed amounts, so your Hawaii state tax may be overstated.")

        let inBriefing = try #require(
            MultiYearCPABriefing.hawaiiPensionSplitLimitation(
                residesInHawaii: true, hasPensionIncome: true).first)
        #expect(inBriefing ==
            "Hawaii excludes the employer-funded portion of a pension from state tax. This plan does not model the split between employer-funded and employee-contributed amounts, so your Hawaii state tax may be overstated.")

        // The two differ in one word and nothing else.
        #expect(inApp.replacingOccurrences(of: "app", with: "plan") == inBriefing)
    }

    /// The failure mode a token buys: an unsubstituted `{scope}` reaching a
    /// user. Swept over every jurisdiction and both surfaces, not just the one
    /// that carries a token today, so a sentence added in a later task is
    /// covered without editing this test.
    @Test("No rendered limitation reaches a user carrying an unsubstituted token")
    func renderedLimitationsCarryNoToken() {
        for state in USState.allCases {
            for scope in [StateAccuracyContent.LimitationScope.app, .plan] {
                for line in StateAccuracyContent.limitations(for: state, scope: scope) {
                    #expect(!line.contains(UnclassifiedPensionDisclosure.scopeToken),
                            "\(state.abbreviation) leaked a scope token to a user: \(line)")
                }
            }
        }
    }

    // MARK: - Gate 4: verification metadata completeness

    /// Gate 4. Every covered jurisdiction must state which tax year its
    /// configuration describes, when it was last verified, and at least one
    /// primary source that can be opened.
    ///
    /// SCOPED DELIBERATELY, and widening it is the one-line change below.
    /// `StateAccuracyContent.coveredJurisdictions` holds fifteen of the
    /// fifty-one jurisdictions. Twenty-one further states carry pinned defects
    /// but are NOT in the set, so a green run here is not a statement that the
    /// other thirty-six are clean; it is a statement that the fifteen this
    /// release authors pages for carry complete provenance. Extending the gate
    /// to all fifty-one would require sourcing thirty-six more states' primary
    /// references, which is separate work that has not been scoped.
    ///
    /// WHAT ENFORCES THIS. Nothing at compile time. The configurations are
    /// JSON, so a jurisdiction that omits `taxYear` decodes to the `0` sentinel
    /// and a jurisdiction that omits `lastVerified` or `primarySources` fails
    /// at decode. Either way the failure surfaces here, in a test, and this
    /// test is the only gate on completeness.
    ///
    /// Sorted so the failure list is stable run to run and can be worked
    /// straight down; `Set` iteration order is not.
    ///
    /// The expected year is READ, not restated. `StateTaxData.config(for:)`
    /// resolves `StateTaxDataLoader.defaultTaxYear`, so the assertion and its
    /// message name the same thing the loader named. Written as a literal
    /// `2026` this gate would keep validating 2026 after a 2027 directory was
    /// added and `config(for:)` had moved on to it, while its own failure
    /// message claimed it was checking "the config's own year".
    @Test("Every covered jurisdiction carries a tax year, a verified date and an HTTPS source")
    func coveredJurisdictionsCarryCompleteVerification() {
        let dataYear = StateTaxDataLoader.defaultTaxYear
        let ordered = StateAccuracyContent.coveredJurisdictions
            .sorted { $0.abbreviation < $1.abbreviation }

        for state in ordered {
            let v = StateTaxData.config(for: state).verification
            #expect(v.taxYear == dataYear,
                    "\(state.abbreviation) verification.taxYear must state the year its config is loaded for, \(dataYear)")
            #expect(!v.lastVerified.isEmpty, "\(state.abbreviation) has no lastVerified")
            #expect(v.primarySources.contains { $0.contains("https://") },
                    "\(state.abbreviation) has no HTTPS primary source")
        }
    }

    /// Pins WHY the covered set holds the fifteen it holds, so that adding or
    /// removing a jurisdiction has to be a deliberate act rather than a drift.
    ///
    /// The set is exactly the union of three groups, each of which already
    /// exists in the test target and is maintained independently of this file:
    ///
    /// 1. the jurisdictions Phase 5 corrected, whose bundled JSON has already
    ///    diverged from the frozen legacy table;
    /// 2. the jurisdictions carrying a `knownButUnpinned` catalogue entry;
    /// 3. the six states whose pension editor shows a caption, because Task 3
    ///    moves those captions into `verification.knownLimitations` and a
    ///    caption cannot render from a config the gate does not cover.
    ///
    /// Vermont is in the set only through group 3, and Georgia, Iowa and
    /// Indiana only through group 1. The plan's own note said every member was
    /// traceable to "a pinned defect or a knownButUnpinned entry", which is not
    /// true of those four; this test states the actual rule.
    @Test("The covered set is exactly the Phase 5 corrections, the unpinned catalogue and the caption states")
    func coveredSetMatchesItsStatedRationale() {
        let unpinned = Set(GoldenScenarioDefectCatalogueTests.knownButUnpinned.compactMap { entry in
            USState.allCases.first { $0.abbreviation == entry.state }
        })

        /// The six states whose pension editor carries a caption today. Pinned
        /// as a literal because `IncomeSourcesView` branches on these states in
        /// its view body rather than declaring them as a set.
        let captionStates: Set<USState> = [
            .hawaii, .massachusetts, .districtOfColumbia,
            .northCarolina, .idaho, .vermont
        ]

        let expected = StateTaxJSONStructuralEquivalenceTests.phase5CorrectedJurisdictions
            .union(unpinned)
            .union(captionStates)

        #expect(StateAccuracyContent.coveredJurisdictions == expected,
                """
                The covered set no longer matches its stated rationale. \
                Only in coveredJurisdictions: \
                \(StateAccuracyContent.coveredJurisdictions.subtracting(expected).map(\.abbreviation).sorted()). \
                Only in the rationale: \
                \(expected.subtracting(StateAccuracyContent.coveredJurisdictions).map(\.abbreviation).sorted()).
                """)
        // No count assertion follows. Set equality already fixes the count,
        // and a bare `== 15` would put back the hardcoded number this test
        // exists to replace with a derivation, with no failure message.
    }

    // MARK: - Topic tagging, and the surface that filters on it

    /// The pension editor renders `pensionLimitations(for:)`, not
    /// `limitations(for:)`, and this is what makes that distinction real.
    ///
    /// THE DEFECT IT GUARDS. The editor's section is headed "What kind of
    /// pension is this?" and once Utah's two tax credits and New Mexico's
    /// age-65 Schedule PIT-ADJ exemption were authored, an unfiltered loop put
    /// all three under that heading. None of them turns on how a pension is
    /// classified; all three change tax for a qualifying filer who holds no
    /// pension at all, so the placement implies the picker moves them.
    ///
    /// Asserted as a PROPERTY over every covered jurisdiction rather than
    /// against Utah and New Mexico by name, so a non-pension sentence authored
    /// for a different state later is caught without editing this test.
    @Test("The pension editor sees pension sentences only, and every other topic still reaches the accuracy page")
    func pensionEditorFiltersToPensionTopics() {
        for state in StateAccuracyContent.coveredJurisdictions.sorted(by: { $0.abbreviation < $1.abbreviation }) {
            let stored = StateTaxData.config(for: state).verification.knownLimitations
            let all = StateAccuracyContent.limitations(for: state)
            let pensionOnly = StateAccuracyContent.pensionLimitations(for: state)

            #expect(all.count == stored.count,
                    "\(state.abbreviation): the accuracy page must show every stored sentence")
            #expect(pensionOnly.count == stored.filter { $0.topic == .pension }.count,
                    "\(state.abbreviation): the pension editor showed a different number of sentences than it has pension-topic ones")
            for line in pensionOnly {
                #expect(all.contains(line),
                        "\(state.abbreviation): the editor rendered a sentence the accuracy page does not")
            }
            for limitation in stored where limitation.topic != .pension {
                let rendered = StateAccuracyContent.limitations(for: state)
                    .first { $0.hasPrefix(String(limitation.text.prefix(30))) }
                #expect(rendered != nil,
                        "\(state.abbreviation): a \(limitation.topic.rawValue) sentence vanished from the accuracy page")
                #expect(!pensionOnly.contains { $0.hasPrefix(String(limitation.text.prefix(30))) },
                        "\(state.abbreviation): a \(limitation.topic.rawValue) sentence reached the pension editor")
            }
        }
    }

    /// Every topic in the enum is carried by a sentence that actually ships.
    ///
    /// A case no sentence uses is a distinction nothing has had to defend, and
    /// the pension editor's filter would keep working while the vocabulary
    /// drifted away from the copy. Fails in BOTH directions: an unused case
    /// here, or a topic that decode produced but the enum does not name, are
    /// both caught.
    @Test("Every limitation topic is earned by a sentence that ships")
    func everyTopicIsUsedBySomeShippedSentence() {
        var used: Set<LimitationTopic> = []
        for state in USState.allCases {
            for limitation in StateTaxData.config(for: state).verification.knownLimitations {
                used.insert(limitation.topic)
            }
        }
        #expect(used == Set(LimitationTopic.allCases),
                """
                Unused topics: \(Set(LimitationTopic.allCases).subtracting(used).map(\.rawValue).sorted()). \
                Add a case when a sentence needs one, not in advance.
                """)
    }

    /// `StateLimitation` decodes a BARE JSON string as a robustness fallback,
    /// resolving it to `.pension` so a mistyped entry keeps rendering rather
    /// than disappearing. That fallback exists because a decode THROW is
    /// converted by `StateTaxDataLoader` into a per-state fallback to the
    /// frozen legacy table, whose `verification` is `.unverified`, which would
    /// drop the state's disclosure entirely in release and trap the process in
    /// debug.
    ///
    /// It is a fallback, not a second supported shape, and this reads the
    /// shipped bytes off disk to prove no file relies on it. Decoding through
    /// `StateVerification` could not tell the two forms apart, which is the
    /// same reason Layer C inspects raw keys.
    @Test("No shipped file relies on the untagged fallback form")
    func everyShippedLimitationIsTaggedInTheFileItself() throws {
        for state in USState.allCases {
            let url = try StateTaxDataLoader.fileURL(for: state,
                                                     taxYear: StateTaxDataLoader.defaultTaxYear)
            let object = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
            guard let root = object as? [String: Any],
                  let verification = root["verification"] as? [String: Any],
                  let limitations = verification["knownLimitations"] as? [Any] else {
                Issue.record("\(state.abbreviation): could not read verification.knownLimitations")
                continue
            }
            for (index, entry) in limitations.enumerated() {
                guard let tagged = entry as? [String: Any] else {
                    Issue.record("""
                        \(state.abbreviation) knownLimitations[\(index)] ships as a bare string. \
                        That still decodes, as a pension-topic sentence, but the topic decides \
                        which surfaces render it and must be stated rather than inferred.
                        """)
                    continue
                }
                #expect(tagged["text"] is String,
                        "\(state.abbreviation) knownLimitations[\(index)] has no text")
                let raw = tagged["topic"] as? String
                #expect(raw.flatMap(LimitationTopic.init(rawValue:)) != nil,
                        "\(state.abbreviation) knownLimitations[\(index)] has an unknown topic \(raw ?? "<missing>")")
            }
        }
    }

    /// Every limitation sentence any user can see, on any surface, in both
    /// scopes. The six captions have their own pin above; this one covers the
    /// sentences authored afterwards, which have no other dash gate.
    @Test("No shipped limitation sentence carries a dash, a doubled space or stray whitespace")
    func everyShippedSentenceIsCleanCopy() {
        for state in USState.allCases {
            for scope in [StateAccuracyContent.LimitationScope.app, .plan] {
                for line in StateAccuracyContent.limitations(for: state, scope: scope) {
                    #expect(!line.contains("\u{2014}") && !line.contains("\u{2013}"),
                            "\(state.abbreviation): em or en dash in user-facing copy: \(line)")
                    #expect(!line.contains("  "),
                            "\(state.abbreviation): doubled space in user-facing copy: \(line)")
                    #expect(line == line.trimmingCharacters(in: .whitespacesAndNewlines),
                            "\(state.abbreviation): stray leading or trailing whitespace: \(line)")
                    #expect(!line.isEmpty, "\(state.abbreviation): empty limitation sentence")
                }
            }
        }
    }

    // MARK: - The taxYear sentinel

    /// `taxYear == 0` means "this file stated no year". It is not a year and
    /// has no rendering: thirty-six jurisdictions carry it today, so a header
    /// interpolating `taxYear` would read "Pennsylvania tax treatment, 0".
    ///
    /// `statedTaxYear` is the accessor every renderer must use, which turns
    /// that from a copy defect nobody would catch into a nil the author of the
    /// page has to answer for. What to SHOW when it is nil is user-facing copy
    /// and therefore John's; this type picks no fallback string.
    @Test("The taxYear sentinel is nil through the accessor renderers must use")
    func theTaxYearSentinelIsAnOptionalWhereItIsRead() {
        #expect(StateVerification.unverified.taxYear == 0)
        #expect(StateVerification.unverified.statedTaxYear == nil)

        // Pennsylvania is outside coveredJurisdictions and states no year, so
        // it is the live example Task 6's header has to handle.
        #expect(StateTaxData.config(for: .pennsylvania).verification.statedTaxYear == nil)

        // Georgia is the one jurisdiction populated today.
        #expect(StateTaxData.config(for: .georgia).verification.statedTaxYear
                == StateTaxDataLoader.defaultTaxYear)
    }

    // MARK: - Task 5: the factual half

    /// The factual half is GENERATED, so the thing worth pinning is that it
    /// reports the numbers the engine actually reads, for the filing status
    /// asked for.
    ///
    /// Kansas is the right specimen. Its standard deduction and personal
    /// exemption are both filing-status specific, and its personal exemption is
    /// a Phase 5a correction that exists in the bundled JSON and NOT in the
    /// frozen legacy table, so a run that silently fell back to the legacy
    /// config would fail here rather than pass quietly.
    @Test("The factual half states Kansas's configured deduction and exemption")
    func kansasFactualStatementsMatchItsConfig() {
        let statements = StateAccuracyContent.factualStatements(for: .kansas,
                                                                filingStatus: .single)
        let byLabel = Dictionary(uniqueKeysWithValues: statements.map { ($0.label, $0.value) })
        #expect(byLabel["Standard deduction"] == "$3,605")
        #expect(byLabel["Personal exemption"] == "$9,160")
        #expect(byLabel["Social Security"] != nil)
        #expect(byLabel["Pension exemption"] != nil)
    }

    /// The married column is a DIFFERENT column, and reading the wrong one is
    /// the defect most likely to survive a single-filing-status test: every
    /// value would still be a plausible dollar figure.
    @Test("The factual half switches columns with the filing status")
    func kansasFactualStatementsFollowTheFilingStatus() {
        let joint = StateAccuracyContent.factualStatements(for: .kansas,
                                                           filingStatus: .marriedFilingJointly)
        let byLabel = Dictionary(uniqueKeysWithValues: joint.map { ($0.label, $0.value) })
        #expect(byLabel["Standard deduction"] == "$8,240")
        #expect(byLabel["Personal exemption"] == "$18,320")
        // The bracket threshold doubles for a joint return in Kansas.
        #expect(byLabel["Tax rates"]?.contains("$46,000") == true)
    }

    /// Labels are the identity of a statement: `Statement.id` is the label, the
    /// accuracy page renders them in a `ForEach`, and the tests above build a
    /// dictionary keyed by them. A duplicate label would crash
    /// `Dictionary(uniqueKeysWithValues:)` and would give SwiftUI two rows with
    /// one identity.
    ///
    /// This is why Kansas's two per-source rules, and Arizona's, are joined into
    /// ONE statement rather than emitted one per rule.
    @Test("No jurisdiction emits the same statement label twice")
    func statementLabelsAreUniquePerJurisdiction() {
        for state in USState.allCases {
            for status in FilingStatus.allCases {
                let labels = StateAccuracyContent
                    .factualStatements(for: state, filingStatus: status)
                    .map(\.label)
                #expect(labels.count == Set(labels).count,
                        "\(state.abbreviation) \(status.rawValue) repeated a label: \(labels)")
            }
        }
    }

    /// Every jurisdiction says SOMETHING, and nothing it says is malformed.
    ///
    /// The empty-list case matters: a state whose statements were all omitted
    /// would render a page with a limitations section and no factual half at
    /// all, which reads as though the app models nothing for that state.
    @Test("Every jurisdiction and filing status produces well-formed statements")
    func everyJurisdictionProducesCleanStatements() {
        for state in USState.allCases {
            for status in FilingStatus.allCases {
                let statements = StateAccuracyContent.factualStatements(for: state,
                                                                        filingStatus: status)
                #expect(!statements.isEmpty,
                        "\(state.abbreviation) \(status.rawValue) produced no factual statements")
                for statement in statements {
                    let context = "\(state.abbreviation) \(status.rawValue) \(statement.label)"
                    #expect(!statement.label.isEmpty, "\(context): empty label")
                    #expect(!statement.value.isEmpty, "\(context): empty value")
                    for text in [statement.label, statement.value] {
                        #expect(!text.contains("\u{2014}") && !text.contains("\u{2013}"),
                                "\(context): em or en dash in user-facing copy: \(text)")
                        #expect(!text.contains("  "), "\(context): doubled space: \(text)")
                        #expect(text == text.trimmingCharacters(in: .whitespacesAndNewlines),
                                "\(context): stray whitespace: \(text)")
                    }
                }
            }
        }
    }

    /// A jurisdiction that levies no tax on the income this app models has no
    /// deduction, bracket or exemption to describe, and describing one would be
    /// worse than saying nothing: "Pension exemption: fully exempt" for Texas
    /// implies a Texas income tax that grants an exemption.
    ///
    /// The engine agrees, and that is what makes this safe rather than merely
    /// tidy: `TaxCalculationEngine.calculateStateTax` returns 0 for both
    /// `.noIncomeTax` and `.specialLimited` before any bracket is consulted.
    @Test("A jurisdiction with no tax on modelled income says exactly that, once")
    func untaxedJurisdictionsMakeOneStatement() {
        for state in USState.allCases {
            let config = StateTaxData.config(for: state)
            guard !config.taxSystem.hasIncomeTax else { continue }
            let statements = StateAccuracyContent.factualStatements(for: state,
                                                                    filingStatus: .single)
            #expect(statements.count == 1,
                    "\(state.abbreviation) has no tax on modelled income but made \(statements.count) statements")
            #expect(statements.first?.label == "Tax rates")
        }
    }

    /// The plan's fixed order, asserted as a RELATIVE order over whichever
    /// statements a jurisdiction emits, because the optional ones (personal
    /// exemption, per-source rules) are present for only a handful.
    ///
    /// Order is user-facing: rates before deductions before exemptions is the
    /// sequence the tax is actually computed in, and a page that listed the
    /// per-source carve-out before the general exemption it overrides would
    /// invert the logic a reader is trying to follow.
    @Test("Statements appear in the order the tax is computed in")
    func statementsKeepTheirOrder() {
        let expected = ["Tax rates", "Standard deduction", "Personal exemption",
                        "Social Security", "Pension exemption",
                        "IRA and 401(k) exemption", "Rules by pension source"]
        for state in USState.allCases {
            for status in FilingStatus.allCases {
                let labels = StateAccuracyContent
                    .factualStatements(for: state, filingStatus: status)
                    .map(\.label)
                let positions = labels.map { label -> Int in
                    expected.firstIndex(of: label) ?? -1
                }
                #expect(!positions.contains(-1),
                        "\(state.abbreviation) emitted a label outside the fixed order: \(labels)")
                #expect(positions == positions.sorted(),
                        "\(state.abbreviation) \(status.rawValue) emitted statements out of order: \(labels)")
            }
        }
    }

    /// A per-source rule is the ONLY thing standing between a Kansas KPERS
    /// holder and a fully taxed pension, and the general pension exemption
    /// reads `.none` for exactly that reason. Both halves of that have to
    /// reach the page or it tells a KPERS holder their pension is taxable.
    @Test("Kansas's per-source exclusion reaches the page in plain language")
    func kansasPerSourceRuleIsStatedPlainly() throws {
        let statements = StateAccuracyContent.factualStatements(for: .kansas,
                                                                filingStatus: .single)
        let rule = try #require(statements.first { $0.label == "Rules by pension source" })
        #expect(rule.value == "Kansas government, federal civilian service, military and Railroad Retirement pensions are fully exempt.")
        // And the general exemption does not contradict it by claiming nothing
        // is excluded.
        let general = try #require(statements.first { $0.label == "Pension exemption" })
        #expect(general.value == "No general exemption.")
    }

    // MARK: - Task 6: the limitations half, and the empty state

    /// THE SINGLE MOST IMPORTANT ASSERTION IN THIS FEATURE. An empty array
    /// records what has not been FOUND, never what does not EXIST. The
    /// 2026-08-02 audit found jurisdictions believed correct on their
    /// retirement exclusions that were wrong on brackets, deductions, credits
    /// and filing-status treatment.
    ///
    /// The wording is John's, specified exactly, and the negative assertions
    /// below are the ones that matter: they fail if a later edit softens this
    /// into a completeness claim.
    @Test("An empty limitations list never reads as a clean bill of health")
    func emptyLimitationsDoesNotClaimCompleteness() {
        let text = StateAccuracyContent.limitationsSummary(for: .pennsylvania)
        #expect(text == "No known limitations are currently recorded for this state and tax year.")
        #expect(!text.lowercased().contains("no limitations"))
        #expect(!text.lowercased().contains("fully modeled"))
    }

    /// The empty state is load-bearing INSIDE the covered set, not only for the
    /// thirty-six jurisdictions outside it.
    ///
    /// Iowa and Indiana were both Phase 5 corrections, both carry complete
    /// verification metadata, and both ship ZERO limitation sentences. A reader
    /// who reached an Iowa page through a "how accurate is this" affordance is
    /// exactly the reader most likely to read silence as a guarantee, and Iowa
    /// is a state whose withheld-portion treatment is an open question with its
    /// own Department of Revenue.
    ///
    /// Asserted as a property over the covered set rather than against Iowa and
    /// Indiana by name, so a jurisdiction whose last sentence is removed by a
    /// future correction is covered without editing this test.
    @Test("A covered jurisdiction with no recorded limitations makes no claim either")
    func coveredJurisdictionsWithEmptyListsClaimNothing() {
        var checked: [String] = []
        for state in StateAccuracyContent.coveredJurisdictions.sorted(by: { $0.abbreviation < $1.abbreviation }) {
            guard StateAccuracyContent.limitations(for: state).isEmpty else { continue }
            checked.append(state.abbreviation)
            let text = StateAccuracyContent.limitationsSummary(for: state)
            #expect(text == "No known limitations are currently recorded for this state and tax year.",
                    "\(state.abbreviation) is covered, ships no limitation, and must still claim nothing")
            #expect(!text.lowercased().contains("verified"),
                    "\(state.abbreviation): an empty list must not borrow the verification stamp as a completeness claim")
        }
        #expect(checked == ["IA", "IN"],
                "the covered jurisdictions shipping empty lists changed: \(checked)")
    }

    /// No jurisdiction, anywhere, produces a summary that reads as a clean bill
    /// of health. The two phrases are the ones the plan names; "verified
    /// complete" is the third way this has been phrased wrongly in review.
    @Test("No jurisdiction's limitations summary claims completeness")
    func noSummaryAnywhereClaimsCompleteness() {
        for state in USState.allCases {
            let text = StateAccuracyContent.limitationsSummary(for: state).lowercased()
            for banned in ["no limitations", "fully modeled", "fully modelled",
                           "verified complete", "no known issues"] {
                #expect(!text.contains(banned),
                        "\(state.abbreviation)'s summary contains \"\(banned)\"")
            }
        }
    }

    /// When a jurisdiction HAS limitations, the summary carries all of them and
    /// is not the empty sentence. A summary that silently dropped a sentence
    /// would be the same defect as the empty state, one jurisdiction at a time.
    @Test("A populated summary carries every sentence the jurisdiction ships")
    func populatedSummaryCarriesEverySentence() {
        for state in USState.allCases {
            let lines = StateAccuracyContent.limitations(for: state)
            guard !lines.isEmpty else { continue }
            let summary = StateAccuracyContent.limitationsSummary(for: state)
            #expect(summary != "No known limitations are currently recorded for this state and tax year.",
                    "\(state.abbreviation) ships \(lines.count) limitations but rendered the empty state")
            for line in lines {
                #expect(summary.contains(line),
                        "\(state.abbreviation): the summary dropped a sentence: \(line)")
            }
            #expect(!summary.contains(UnclassifiedPensionDisclosure.scopeToken),
                    "\(state.abbreviation): the summary leaked a scope token")
        }
    }

    // MARK: - Task 6: the header

    /// The header carries state AND tax year TOGETHER, in one string.
    ///
    /// Not a style preference. "Verified August 2026" beside a bare "Iowa"
    /// reads as a claim about Iowa's current law generally, when the
    /// configuration describes one tax year only. Keeping them in a single
    /// string means no layout change can separate them.
    @Test("The header names the state and the tax year in one string")
    func headerCarriesStateAndTaxYearTogether() {
        let header = StateAccuracyContent.header(for: .iowa)
        #expect(header.title == "Iowa tax treatment, 2026")
        #expect(header.verified == "Verified August 5, 2026.")
        #expect(header.sources.count == 1)
        #expect(header.sources.first?.label == "Iowa Department of Revenue, Retirement Income Tax Guidance")
        #expect(header.sources.first?.url?.absoluteString ==
                "https://revenue.iowa.gov/taxes/tax-guidance/individual-income-tax/retirement-income-tax-guidance")
    }

    /// The `taxYear == 0` sentinel is what thirty-six jurisdictions carry, and
    /// the failure this pins is a header reading "Pennsylvania tax treatment,
    /// 0". It would ship silently, because nothing about an `Int` invites the
    /// author to ask what `0` means.
    ///
    /// The replacement wording is PROPOSED and awaits John. What is NOT
    /// negotiable is that the page never invents a year: `StateTaxDataLoader`
    /// resolved this file from the 2026 directory, but the file itself states
    /// no year, and printing 2026 here would manufacture a provenance claim the
    /// data never made.
    @Test("A jurisdiction stating no tax year says so, and no year is invented for it")
    func headerHandlesTheMissingTaxYear() {
        let header = StateAccuracyContent.header(for: .pennsylvania)
        #expect(header.title == "Pennsylvania tax treatment, tax year not recorded")
        #expect(!header.title.contains("0"))
        #expect(!header.title.contains("2026"))
        #expect(header.verified == "No verification date recorded.")
        #expect(header.sources.isEmpty)
        #expect(header.noSourcesMessage == "No primary sources recorded.")
    }

    /// Every jurisdiction's header is well formed, names itself, and claims
    /// nothing it has no basis for.
    @Test("Every jurisdiction's header is well formed and claims nothing unsupported")
    func everyHeaderIsWellFormed() {
        for state in USState.allCases {
            let header = StateAccuracyContent.header(for: state)
            let verification = StateTaxData.config(for: state).verification

            #expect(header.title.hasPrefix("\(state.rawValue) tax treatment"),
                    "\(state.abbreviation): the header does not name the state first: \(header.title)")

            if let year = verification.statedTaxYear {
                #expect(header.title == "\(state.rawValue) tax treatment, \(year)")
            } else {
                #expect(header.title.contains("not recorded"),
                        "\(state.abbreviation): no stated year, so the header must say so: \(header.title)")
            }

            // A verification stamp is never implied where none exists.
            if verification.lastVerified.isEmpty {
                #expect(!header.verified.lowercased().contains("verified "),
                        "\(state.abbreviation): claims a verification it does not have: \(header.verified)")
            } else {
                #expect(header.verified.hasPrefix("Verified "),
                        "\(state.abbreviation): has a date but does not state it: \(header.verified)")
                #expect(!header.verified.contains(verification.lastVerified),
                        "\(state.abbreviation): the raw ISO date reached the page unformatted")
            }

            // Every stated source resolves to an HTTPS URL, so a "source" is
            // never an unfollowable claim.
            for source in header.sources {
                #expect(!source.label.isEmpty, "\(state.abbreviation): a source has no label")
                #expect(source.url?.scheme == "https",
                        "\(state.abbreviation): source is not an https URL: \(source.label)")
                #expect(!source.label.contains("https://"),
                        "\(state.abbreviation): the URL leaked into the source label")
            }

            for text in [header.title, header.verified, header.noSourcesMessage] {
                #expect(!text.contains("\u{2014}") && !text.contains("\u{2013}"),
                        "\(state.abbreviation): em or en dash in header copy: \(text)")
                #expect(!text.contains("  "), "\(state.abbreviation): doubled space: \(text)")
                #expect(text == text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}
