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
    ///
    /// "Roth conversions" sits DIRECTLY AFTER "IRA and 401(k) exemption" and
    /// before the per-source rules, because a conversion is an IRA distribution
    /// and the IRA line is the one a reader would otherwise apply to it. Iowa is
    /// the live proof: its IRA line says withdrawals are taxed as ordinary
    /// income while its conversion is exempt from 55, so a reader who stopped at
    /// the IRA line would draw the opposite conclusion. A correction has to be
    /// adjacent to the statement it corrects.
    @Test("Statements appear in the order the tax is computed in")
    func statementsKeepTheirOrder() {
        let expected = ["Tax rates", "Standard deduction", "Personal exemption",
                        "Social Security", "Pension exemption",
                        "IRA and 401(k) exemption", "Roth conversions",
                        "Rules by pension source"]
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

    // MARK: - Roth conversion treatment

    /// THE FOUR JURISDICTIONS CARRYING A `rothConversionExemption`, and the
    /// authority for every figure asserted below is the bundled 2026 JSON, not
    /// this test's memory of it. `expectedRothConversionStates` is asserted
    /// against the live configs in `onlyTheConfiguredStatesStateARothRule`, so a
    /// fifth jurisdiction gaining a rule fails there rather than passing
    /// silently here.
    private static let expectedRothConversionStates: Set<USState> =
        [.iowa, .illinois, .mississippi, .pennsylvania]

    /// PENNSYLVANIA IS THE SPECIMEN THAT MATTERS MOST. It exempts the conversion
    /// outright, so a Pennsylvania household converting $200,000 currently
    /// assumes a state cost of roughly $6,140 that the engine never charges, and
    /// until this statement existed the one page built to say what the app
    /// models was silent about it.
    ///
    /// Its config is ALSO the one that is not like the others: Ans 274 holds the
    /// exemption reaches only the amount actually deposited into the Roth, so
    /// `withheldPortionRemainsTaxable` is true and the sentence has to carry
    /// that caveat or it overstates the exemption for anyone withholding federal
    /// tax out of the conversion itself.
    @Test("Pennsylvania's Roth conversion exemption reaches the page, withholding caveat and all")
    func pennsylvaniaStatesItsRothConversionExemption() throws {
        let statements = StateAccuracyContent.factualStatements(for: .pennsylvania,
                                                                filingStatus: .single)
        let line = try #require(statements.first { $0.label == "Roth conversions" })
        #expect(line.value == "Not taxed by this state. Any part of the conversion withheld for federal tax does not reach the Roth account, so that part stays taxable.")
    }

    /// EACH OF THE FOUR RENDERS ITS OWN CONFIG, and the three distinct shapes
    /// are the reason this is not one assertion repeated four times:
    ///
    ///   - Illinois and Mississippi: `minAge` 0, withholding does not reduce it.
    ///   - Pennsylvania: `minAge` 0, withheld portion stays taxable.
    ///   - Iowa: `minAge` 55, withholding does not reduce it. Iowa is the ONLY
    ///     age-gated one, and it is also the only one whose rule exists solely
    ///     in the bundled JSON and not in the frozen legacy Swift table, so a
    ///     run that silently fell back to that table fails here.
    ///
    /// Flattening these into one sentence would print a Pennsylvania caveat on
    /// an Illinois page and drop Iowa's age gate, which is the specific failure
    /// a generated page is supposed to make impossible.
    @Test("Each Roth conversion state renders its own config, not a shared assumption")
    func eachRothConversionStateRendersItsOwnConfig() throws {
        let expected: [USState: String] = [
            .illinois: "Not taxed by this state.",
            .mississippi: "Not taxed by this state.",
            .pennsylvania: "Not taxed by this state. Any part of the conversion withheld for federal tax does not reach the Roth account, so that part stays taxable.",
            .iowa: "Not taxed by this state from age 55."
        ]
        for (state, sentence) in expected {
            for status in FilingStatus.allCases {
                let statements = StateAccuracyContent.factualStatements(for: state,
                                                                        filingStatus: status)
                let line = try #require(statements.first { $0.label == "Roth conversions" },
                                        "\(state.abbreviation) \(status.rawValue) states nothing about Roth conversions")
                #expect(line.value == sentence,
                        "\(state.abbreviation) \(status.rawValue): \(line.value)")
            }
        }
    }

    /// ABSENT IS OMITTED, swept across all fifty-one jurisdictions and both
    /// filing statuses. A configuration that carries no `rothConversionExemption`
    /// has not said the conversion is taxable, it has said nothing, and printing
    /// "Roth conversions: taxed as ordinary income" for the other forty-seven
    /// would assert a fact no config states on the one page built to separate
    /// what is known from what is not.
    ///
    /// Asserted BIDIRECTIONALLY against the live configs, so this cannot pass by
    /// agreeing with a stale literal: the set of states whose page carries the
    /// statement must equal the set whose config carries the rule, which must in
    /// turn equal the four named above.
    @Test("Only the configured jurisdictions say anything about Roth conversions")
    func onlyTheConfiguredStatesStateARothRule() {
        var pageStates: Set<USState> = []
        var configStates: Set<USState> = []
        for state in USState.allCases {
            if StateTaxData.config(for: state).retirementExemptions.rothConversionExemption != nil {
                configStates.insert(state)
            }
            for status in FilingStatus.allCases {
                let labels = StateAccuracyContent
                    .factualStatements(for: state, filingStatus: status)
                    .map(\.label)
                if labels.contains("Roth conversions") { pageStates.insert(state) }
            }
        }
        #expect(configStates == Self.expectedRothConversionStates,
                "the set of configs carrying a Roth conversion rule moved: \(configStates.map(\.abbreviation).sorted())")
        #expect(pageStates == configStates,
                """
                the page and the configuration disagree about which jurisdictions have a Roth \
                conversion rule. Page: \(pageStates.map(\.abbreviation).sorted()). \
                Config: \(configStates.map(\.abbreviation).sorted()).
                """)
    }

    /// THE `.specialLimited` TRAP, RE-ASSERTED FOR THIS STATEMENT. Task 6 found
    /// that New Hampshire and Washington configure a FULL pension exemption
    /// against a system that levies no tax on the income this app models, so
    /// rendering that field would have claimed an exemption from a tax that does
    /// not exist. The fix was the `hasIncomeTax` guard, which returns a single
    /// "Tax rates" statement and stops.
    ///
    /// The Roth statement is emitted AFTER that guard and therefore inherits it.
    /// This test proves the inheritance two ways: no untaxed jurisdiction's page
    /// mentions Roth conversions, and none of the four that do carry a rule is
    /// an untaxed jurisdiction in the first place.
    @Test("No jurisdiction without an income tax states a Roth conversion rule")
    func untaxedJurisdictionsStateNothingAboutRothConversions() {
        for state in USState.allCases {
            let config = StateTaxData.config(for: state)
            guard !config.taxSystem.hasIncomeTax else { continue }
            for status in FilingStatus.allCases {
                let labels = StateAccuracyContent
                    .factualStatements(for: state, filingStatus: status)
                    .map(\.label)
                #expect(!labels.contains("Roth conversions"),
                        "\(state.abbreviation) levies no tax on modelled income but its page states a Roth conversion rule")
            }
        }
        for state in Self.expectedRothConversionStates {
            #expect(StateTaxData.config(for: state).taxSystem.hasIncomeTax,
                    "\(state.abbreviation) carries a Roth conversion rule against a system with no income tax on modelled income")
        }
    }

    /// THE STATEMENT IS BACKED BY WHAT THE ENGINE DOES, in the same spirit as
    /// the Social Security and per-spouse probes. A generated page proves only
    /// that the SOURCE of a figure is the engine's own config; it does not prove
    /// the engine acts on it. Here it does, and this is the assertion that says
    /// so.
    ///
    /// Three claims, one per shape:
    ///
    ///   1. A $200,000 conversion costs a qualifying household NOTHING in state
    ///      tax: the bill is identical to the same household with no conversion
    ///      at all, and strictly lower than the same $260,000 of income with the
    ///      conversion not declared as one. Both halves are needed. The equality
    ///      alone would also hold if the engine ignored the income entirely, and
    ///      the inequality alone would also hold if the exemption were partial.
    ///   2. Federal withholding taken out of the conversion changes the tax in
    ///      Pennsylvania and ONLY in Pennsylvania, which is exactly what its
    ///      sentence's extra clause claims and what the other three sentences
    ///      claim by omitting it.
    ///   3. Iowa's exemption disappears below 55, which is what "from age 55"
    ///      claims, and the other three keep theirs at 50, which is what their
    ///      silence on age claims.
    @Test("The Roth conversion statement is backed by what the engine does with a conversion")
    func rothConversionStatementsMatchEngineBehaviour() {
        for state in Self.expectedRothConversionStates.sorted(by: { $0.abbreviation < $1.abbreviation }) {
            let rule = StateTaxData.config(for: state).retirementExemptions.rothConversionExemption

            // No conversion at all.
            let withoutConversion = Self.rothConversionProbe(state: state, conversion: 0,
                                                             withholding: 0, age: 75)
            // The same $200,000 in the state's base, NOT declared as a
            // conversion. This is what the household would pay if the state
            // taxed the conversion, and it is the control that proves the
            // income was really there to be exempted.
            let taxedAsOrdinary = Self.rothConversionProbe(state: state, conversion: 0,
                                                           withholding: 0, age: 75,
                                                           extraIncome: 200_000)
            let exempted = Self.rothConversionProbe(state: state, conversion: 200_000,
                                                    withholding: 0, age: 75)

            #expect(taxedAsOrdinary > withoutConversion,
                    "\(state.abbreviation): the probe's $200,000 never reached the state base, so nothing here is measuring an exemption")
            #expect(abs(exempted - withoutConversion) < 0.01,
                    """
                    \(state.abbreviation)'s page says a Roth conversion is not taxed, but the \
                    engine charged \(exempted) with a $200,000 conversion against \
                    \(withoutConversion) with none.
                    """)

            let withWithholding = Self.rothConversionProbe(state: state, conversion: 200_000,
                                                           withholding: 50_000, age: 75)
            if rule?.withheldPortionRemainsTaxable == true {
                #expect(withWithholding > exempted && withWithholding < taxedAsOrdinary,
                        """
                        \(state.abbreviation)'s page says the withheld portion stays taxable and \
                        the rest does not, but the engine charged \(withWithholding) with $50,000 \
                        withheld, against \(exempted) fully exempt and \(taxedAsOrdinary) fully \
                        taxed.
                        """)
            } else {
                #expect(abs(withWithholding - exempted) < 0.01,
                        """
                        \(state.abbreviation)'s page states no withholding caveat, but the engine \
                        taxed the withheld portion: \(withWithholding) against \(exempted).
                        """)
            }

            let atFifty = Self.rothConversionProbe(state: state, conversion: 200_000,
                                                   withholding: 0, age: 50)
            if let minAge = rule?.minAge, minAge > 50 {
                #expect(abs(atFifty - taxedAsOrdinary) < 0.01,
                        """
                        \(state.abbreviation)'s page says the exemption applies from age \
                        \(minAge), but a 50 year old was charged \(atFifty) rather than the \
                        \(taxedAsOrdinary) an unexempted conversion costs.
                        """)
            } else {
                #expect(abs(atFifty - exempted) < 0.01,
                        """
                        \(state.abbreviation)'s page states no age gate, but the engine withheld \
                        the exemption from a 50 year old: \(atFifty) against \(exempted).
                        """)
            }
        }
    }

    /// Same construction as `socialSecurityProbe`, single filer, varying only
    /// the conversion, the withholding taken out of it, the age, and any
    /// undeclared income standing in for the conversion.
    ///
    /// `income` INCLUDES the conversion, because it must: the engine subtracts
    /// the exempt amount from the income it was handed, so a probe that declared
    /// a conversion the income never contained would measure a subtraction
    /// against a floor of zero and pass for every state.
    private static func rothConversionProbe(state: USState,
                                            conversion: Double,
                                            withholding: Double,
                                            age: Int,
                                            extraIncome: Double = 0) -> Double {
        let config = StateTaxData.config(for: state)
        let stateStandardDeduction: Double
        switch config.stateDeduction {
        case .fixed(let single, _): stateStandardDeduction = single
        case .none, .conformsToFederal: stateStandardDeduction = 0
        }
        let postExemptionDeduction = config.personalExemption?
            .amount(filingStatus: .single, enableSpouse: false,
                    primaryAge: age, spouseAge: age) ?? 0

        return TaxCalculationEngine.calculateStateTax(
            income: max(0, 60_000 + conversion + extraIncome - stateStandardDeduction),
            forState: state,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            incomeSources: [],
            currentAge: age,
            enableSpouse: false,
            spouseBirthYear: 2026 - age,
            currentYear: 2026,
            scenarioRetirementDistributions: 0,
            scenarioRothConversionAmount: conversion,
            scenarioRothConversionWithholdingAmount: withholding,
            postExemptionDeduction: postExemptionDeduction)
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
    /// Georgia, Iowa and Indiana were all Phase 5 corrections, all carry
    /// complete verification metadata, and all ship ZERO limitation sentences.
    /// A reader who reached an Iowa page through a "how accurate is this"
    /// affordance is exactly the reader most likely to read silence as a
    /// guarantee, and Iowa is a state whose withheld-portion treatment is an
    /// open question with its own Department of Revenue.
    ///
    /// GEORGIA JOINED ON 2026-08-06, which is this assertion doing its job: its
    /// one unapproved sentence was withdrawn from production, and the count
    /// below is what forced that removal to be acknowledged here rather than
    /// passing in silence. Georgia is now a third state rendering a verified
    /// date, a primary source and "no known limitations are currently
    /// recorded", which in aggregate reads closer to a clean bill than any one
    /// line of it claims. That aggregate is John's open call; the design's
    /// optional second sentence remains unshipped and unapproved.
    ///
    /// Asserted as a property over the covered set rather than against the
    /// three by name, so a jurisdiction whose last sentence is removed by a
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
        #expect(checked == ["GA", "IA", "IN"],
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
    /// The replacement wording was APPROVED BY JOHN ON 2026-08-06, as written.
    /// What is NOT negotiable is that the page never invents a year: `StateTaxDataLoader`
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

    // MARK: - Task 7: two entry points, two different states

    // A THIRD ENTRY POINT, ON THE MULTI-YEAR TAB, WAS REMOVED BEFORE MERGE, and
    // `noMultiYearSurfacePresentsTheAccuracyPage` below is what keeps it gone.
    // The assertions in this section are unchanged for the two that ship: they
    // still prove each resolves its own state and that the two disagree.

    /// The plan's own test, verbatim minus the removed multi-year destination.
    /// One example per surviving destination.
    @Test("Each entry point resolves its own state, not the resident's")
    func entryPointsResolveTheCorrectState() {
        #expect(StateAccuracyContent.stateForComparisonSheet(inspecting: .oregon,
                                                             resident: .california) == .oregon)
        #expect(StateAccuracyContent.stateForSingleYearResults(resident: .california) == .california)
    }

    /// The example above passes for a resolver that returns the resident
    /// whenever the two happen to be equal, or that returns a hardcoded Oregon.
    /// This one does not: it sweeps every ordered pair of the fifty-one
    /// jurisdictions, so the comparison sheet is proved to follow the INSPECTED
    /// state across 2,601 combinations including all fifty-one where the two
    /// coincide.
    ///
    /// THE DEFECT THIS IS ABOUT is not a typo, it is a plausible-looking
    /// convenience: reaching for `dataManager.selectedState` inside the
    /// comparison sheet because it is already in scope there and reads like
    /// "the user's state". A Californian browsing Oregon would then see
    /// California's limitations printed under Oregon's tax figure, and every
    /// sentence on the page would be true, about the wrong state.
    @Test("The comparison sheet follows the inspected state for every pair of jurisdictions")
    func comparisonSheetNeverFallsBackToTheResident() {
        for inspected in USState.allCases {
            for resident in USState.allCases {
                #expect(StateAccuracyContent.stateForComparisonSheet(
                    inspecting: inspected, resident: resident) == inspected,
                    "inspecting \(inspected.abbreviation) while resident in \(resident.abbreviation) resolved the wrong state")
                #expect(StateAccuracyContent.stateForSingleYearResults(
                    resident: resident) == resident)
            }
        }
    }

    /// The two destinations DISAGREE whenever the states they read differ,
    /// which is the property that would be lost by collapsing them into one
    /// resolver.
    ///
    /// Stated as its own assertion because the sweep above would still pass if
    /// both returned their first argument and the call sites all passed the
    /// resident: the guarantee is about the resolvers being distinguishable
    /// at all.
    @Test("A comparison sheet and the single-year screen resolve different states when they should")
    func theTwoDestinationsAreDistinguishable() {
        let resident = USState.california
        let inspected = USState.oregon

        let comparison = StateAccuracyContent.stateForComparisonSheet(inspecting: inspected,
                                                                       resident: resident)
        let singleYear = StateAccuracyContent.stateForSingleYearResults(resident: resident)
        #expect(comparison != singleYear)
    }

    /// `ProjectionEngine` decides which jurisdiction to tax each projected year
    /// in by resolving `inputs.state` through
    /// `MultiYearStaticInputs.modelledState`, so any surface that ever names
    /// the state a multi-year figure was computed in reads the same expression
    /// rather than a second copy of it. Swept over all fifty-one so no
    /// jurisdiction's abbreviation fails to round-trip, plus the malformed
    /// case, where `ProjectionEngine` falls back to California and asserts in
    /// DEBUG.
    ///
    /// KEPT AFTER THE MULTI-YEAR AFFORDANCE WAS REMOVED. Its subject is the
    /// engine's own state resolution, which still ships; the affordance was
    /// only its second reader.
    @Test("The state the multi-year engine taxes in round-trips for every jurisdiction")
    func modelledStateResolvesEveryAbbreviation() {
        for state in USState.allCases {
            #expect(Self.inputs(state: state.abbreviation).modelledState == state,
                    "\(state.abbreviation) does not resolve back to itself")
        }
        // The malformed case. `ProjectionEngine` taxes this plan as California
        // and asserts in DEBUG. Any future surface naming this plan's state has
        // to treat `nil` as "say nothing", because a page headed with the
        // resident's state would claim the figures came from rules that were
        // never applied.
        #expect(Self.inputs(state: "ZZ").modelledState == nil)
    }

    /// The smallest `MultiYearStaticInputs` that carries a state. Every other
    /// field is inert here; only `state` is read.
    private static func inputs(state: String) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 65,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: state,
            primarySSClaimAge: 67,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1961,
            spouseBirthYear: nil,
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: 0,
            spousePensionIncome: 0,
            primaryNetInvestmentIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0)
    }

    // MARK: - The Multi-Year tab presents no accuracy page

    // WHY THIS GATE EXISTS. Task 7 put an info affordance beside the Multi-Year
    // tab's `State` delta tag, opening the per-state accuracy page. The whole
    // branch review removed it before merge, because THE PAGE CANNOT EXPLAIN
    // THE NUMBER IT SITS BESIDE: it prints the jurisdiction's standard
    // deduction and personal exemption as modelled facts, and the multi-year
    // path applies neither. `ProjectionEngine.computeStateTax` hands
    // `TaxCalculationEngine.calculateStateTax` a raw federal AGI with no
    // `postExemptionDeduction`, where the single-year caller
    // `DataManager.calculateStateTax` subtracts both first. Kansas MFJ is about
    // $1,482 a year of phantom state tax on that path; Idaho MFJ both 67 about
    // $2,517.
    //
    // RESTORING THE AFFORDANCE DEPENDS ON one of these landing first:
    //   1. the engine gap being closed, so the page's deduction and exemption
    //      lines are true of multi-year figures too; or
    //   2. a path-aware disclosure page, with its own path-specific copy and
    //      its own behavioural tests.
    // If the route is (1), AN END-TO-END MULTI-YEAR BEHAVIOUR PROBE MUST LAND
    // BEFORE THE AFFORDANCE IS RESTORED. Gate 3 below cannot stand in for one;
    // see the note on its own MARK.
    //
    // WHY IT IS A SOURCE SWEEP RATHER THAN A SYMBOL CHECK. There is no runtime
    // handle on "which view can open this sheet": SwiftUI presentation is a
    // modifier on a body, and asserting against one property name would pass
    // the moment someone re-added the affordance under a different name, in a
    // different view, or through a wrapper. What is invariant is that opening
    // the page means CONSTRUCTING `StateAccuracyView` somewhere, and that an
    // affordance for it carries the shared accessibility label. So the gate
    // sweeps every production source and asserts the set of files doing either
    // is EXACTLY the approved set, which fails on any new presenter anywhere,
    // not only on the multi-year ones.

    /// The only production files entitled to construct `StateAccuracyView`.
    /// Its own file appears because of its `#Preview` blocks.
    static let filesEntitledToPresentTheAccuracyPage: Set<String> = [
        "StateAccuracyView.swift",
        "DashboardView.swift",
        "StateComparisonView.swift"
    ]

    /// The only production files entitled to carry an accuracy affordance's
    /// accessibility label. `StateAccuracyView.swift` is NOT among them: it
    /// carries the navigation title "State tax accuracy", which is a different
    /// string and is not an affordance.
    static let filesEntitledToCarryTheAffordanceLabel: Set<String> = [
        "DashboardView.swift",
        "StateComparisonView.swift"
    ]

    /// The Multi-Year tab's own presentation files, checked by name as well as
    /// by the sweep above. Redundant on purpose: the sweep is the gate, and
    /// this names the surfaces the removal was about, so a failure here says
    /// what happened instead of only which set differed.
    static let multiYearPresentationFiles: [String] = [
        "MultiYearPlanView.swift",
        "ApproachComparisonView.swift",
        "MultiYearStrategyManager.swift"
    ]

    /// Marker for constructing the page. A presentation cannot avoid it.
    static let accuracyPagePresentationMarker = "StateAccuracyView("

    /// Marker for an affordance that opens the page. Every shipped entry point
    /// carries it, and VoiceOver users depend on it, so an affordance that
    /// dropped it to evade this gate would be a different, worse defect.
    static let accuracyAffordanceLabelMarker = "State tax accuracy for "

    /// Every `.swift` file under the production target, by base name.
    ///
    /// Read from the checkout through `#filePath`, the same way
    /// `TaxsimOracleTests` and `Phase3bPersistenceTests` reach their fixtures,
    /// because the subject is Swift source rather than data and nothing in the
    /// built product carries it.
    private static func productionSources() throws -> [(name: String, text: String)] {
        struct ProductionTreeMissing: Error { let path: String }
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // RetireSmartIRATests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("RetireSmartIRA")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            throw ProductionTreeMissing(path: root.path)
        }
        var files: [(name: String, text: String)] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            let url = root.appendingPathComponent(relative)
            files.append((name: url.lastPathComponent,
                          text: try String(contentsOf: url, encoding: .utf8)))
        }
        return files
    }

    @Test("No Multi-Year surface presents the per-state accuracy page")
    func noMultiYearSurfacePresentsTheAccuracyPage() throws {
        let sources = try Self.productionSources()

        // NON-VACUITY. A sweep that found nothing would pass every assertion
        // below while proving nothing at all, which is the failure mode of
        // every source-reading gate.
        #expect(sources.count > 100,
                """
                The production source sweep found only \(sources.count) files. It resolves the \
                tree from #filePath, so a moved test file or a renamed target makes this gate \
                vacuous rather than red. Fix the path before trusting anything below.
                """)
        let names = sources.map(\.name)
        #expect(Set(names).count == names.count,
                """
                Two production files share a base name, so the sets below are ambiguous about \
                which one they mean. Key this gate on the relative path instead.
                """)

        var presenting: Set<String> = []
        var labelling: Set<String> = []
        for file in sources {
            if file.text.contains(Self.accuracyPagePresentationMarker) {
                presenting.insert(file.name)
            }
            if file.text.contains(Self.accuracyAffordanceLabelMarker) {
                labelling.insert(file.name)
            }
        }

        #expect(presenting == Self.filesEntitledToPresentTheAccuracyPage,
                """
                The set of production files constructing StateAccuracyView changed. \
                Added: \(presenting.subtracting(Self.filesEntitledToPresentTheAccuracyPage).sorted()). \
                Missing: \(Self.filesEntitledToPresentTheAccuracyPage.subtracting(presenting).sorted()). \
                If this is the Multi-Year affordance coming back, read the note above this test \
                first: the page states a standard deduction and a personal exemption that the \
                multi-year path does not apply, so it contradicts the figure it would sit \
                beside. Close that engine gap and land an end-to-end multi-year behaviour probe \
                before adding the entry point, or ship a path-aware page instead. If this is a \
                new, legitimate entry point on some other surface, add its file here \
                deliberately.
                """)

        #expect(labelling == Self.filesEntitledToCarryTheAffordanceLabel,
                """
                The set of production files carrying an accuracy affordance's accessibility \
                label changed. \
                Added: \(labelling.subtracting(Self.filesEntitledToCarryTheAffordanceLabel).sorted()). \
                Missing: \(Self.filesEntitledToCarryTheAffordanceLabel.subtracting(labelling).sorted()). \
                A missing entry means a shipped entry point lost its VoiceOver label; an added \
                one means a new affordance exists.
                """)

        // The named multi-year surfaces, checked individually so the failure
        // names the tab rather than a set difference. Requiring each file to
        // EXIST means a rename cannot silently drop it from coverage.
        for name in Self.multiYearPresentationFiles {
            let file = try #require(sources.first { $0.name == name },
                                    """
                                    \(name) no longer exists under the production target. It was \
                                    one of the Multi-Year tab's presentation files when the \
                                    accuracy affordance was removed from it. If it was renamed, \
                                    rename it here too; the sweep above still holds the real \
                                    gate, but this list stops naming the right surfaces.
                                    """)
            #expect(!file.text.contains(Self.accuracyPagePresentationMarker),
                    "\(name) constructs StateAccuracyView. The Multi-Year tab presents no accuracy page; see the note above this test.")
            #expect(!file.text.contains(Self.accuracyAffordanceLabelMarker),
                    "\(name) carries an accuracy affordance's accessibility label. The Multi-Year tab presents no accuracy page; see the note above this test.")
        }
    }

    // MARK: - Task 8, Gate 3: rendering fidelity against EFFECTIVE BEHAVIOUR
    //
    // WHAT GATE 3 DOES NOT COVER, stated here so its existence is not mistaken
    // for coverage of the page as a whole.
    //
    // 1. IT IS NOT A MULTI-YEAR GATE. Both probes below call
    //    `TaxCalculationEngine.calculateStateTax` with an `income` the probe
    //    ITSELF already reduced by the state standard deduction, and pass
    //    `postExemptionDeduction` explicitly. That is the SINGLE-YEAR caller's
    //    contract, reproduced faithfully from `DataManager.calculateStateTax`,
    //    and re-verified here. The multi-year caller
    //    (`ProjectionEngine.computeStateTax`) does NEITHER, which is why the
    //    Multi-Year accuracy affordance was removed before merge and why a
    //    green Gate 3 could not have caught it. When that engine gap is closed,
    //    a true end-to-end multi-year behaviour probe has to be written; this
    //    one cannot be adapted by changing an argument.
    //
    // 2. IT PROBES THREE CLAIMS, NOT THE PAGE. The per-spouse cap (two
    //    jurisdictions), Social Security (fifteen) and Roth conversions (four).
    //    Bracket rates, the standard deduction, the personal exemption, pension
    //    and IRA exemption levels, per-source rules and age gates are NOT
    //    behaviour-backed. That set is not academic: the STANDARD-DEDUCTION
    //    claim was among the unprobed ones, and it is the one that turned out
    //    to be wrong on the multi-year path.

    /// NOT AN ECHO TEST, and that is the whole point of this gate.
    ///
    /// If the page says the exclusion applies to each qualifying spouse, the
    /// ENGINE must actually grant a second full cap when both spouses qualify,
    /// and one when only one does. Reading `exemptionAppliesPerIndividual` and
    /// `maxExempt` back out of the configuration would pass while the engine
    /// ignored both, and the predecessor branch shipped several engine faults a
    /// config echo would have missed.
    ///
    /// THREE PROBES, NOT TWO, and the third is what makes this an assertion
    /// about the AMOUNT rather than only the direction:
    ///
    ///   1. one spouse qualifies,
    ///   2. both spouses qualify,
    ///   3. one spouse qualifies, on a pension smaller by exactly the
    ///      configured cap.
    ///
    /// Probes 2 and 3 must produce the SAME tax. That holds only if the second
    /// qualifying spouse moved the taxable base by exactly one more full cap:
    /// a doubling that stopped short, or one that ran twice, breaks the
    /// equality while `bothQualify < oneQualifies` would still pass. The
    /// configured cap is read to build probe 3, but nothing here asserts the
    /// configured value; what is asserted is how far the engine moved.
    ///
    /// Only ONE input differs between probes 1 and 2: the spouse's age. The
    /// household's filing status, the standard deduction, the personal
    /// exemption and the pooled exemption LEVEL are identical, because
    /// `effectiveAge` is the household maximum and the primary is above every
    /// gate in both. So a difference in the result can only come from
    /// `perIndividualMultiplier`.
    ///
    /// Measured when this gate was written, by mutation: dropping the second
    /// spouse to an age that does not qualify moves Georgia by $3,243.50, which
    /// is its $65,000 cap at 4.99%, and New York by $1,080.00.
    @Test("A per-spouse statement is backed by the engine actually doubling it")
    func perSpouseStatementsMatchEngineBehaviour() {
        let phrase = "the cap applies to each qualifying spouse"
        var checked: [String] = []

        for state in StateAccuracyContent.coveredJurisdictions.sorted(by: { $0.abbreviation < $1.abbreviation }) {
            let config = StateTaxData.config(for: state)
            let exemptions = config.retirementExemptions
            let saysPerSpouse = StateAccuracyContent
                .factualStatements(for: state, filingStatus: .marriedFilingJointly)
                .contains { $0.value.contains(phrase) }

            // The page and the configuration agree about WHETHER the claim is
            // made. Both directions: a config flag with no sentence hides a
            // rule the user is entitled to, and a sentence with no flag
            // promises one the engine was never asked for.
            #expect(saysPerSpouse == exemptions.exemptionAppliesPerIndividual,
                    """
                    \(state.abbreviation): the page \(saysPerSpouse ? "claims" : "does not claim") \
                    a per-spouse cap while the configuration \
                    \(exemptions.exemptionAppliesPerIndividual ? "sets" : "does not set") \
                    exemptionAppliesPerIndividual.
                    """)

            guard exemptions.exemptionAppliesPerIndividual else { continue }
            checked.append(state.abbreviation)

            guard case .partial(let cap) = exemptions.pensionExemption else {
                Issue.record("""
                    \(state.abbreviation) claims a per-spouse cap on an exemption level this \
                    test cannot size. Extend the probe rather than dropping the jurisdiction: \
                    an unsized claim is an untested claim.
                    """)
                continue
            }
            if case .conformsToFederal = config.stateDeduction {
                Issue.record("""
                    \(state.abbreviation) conforms to the federal deduction, which this probe \
                    does not reproduce, so its per-spouse claim would go untested.
                    """)
                continue
            }

            // Six caps of pension, so both the single and the doubled cap bind
            // and neither probe is limited by `min(eligibleIncome, ...)`.
            let pension = cap * 6
            let oneQualifies = Self.perSpouseProbe(state: state, pension: pension, spouseAge: 50)
            let bothQualify = Self.perSpouseProbe(state: state, pension: pension, spouseAge: 75)
            let oneQualifiesOnACapLessPension =
                Self.perSpouseProbe(state: state, pension: pension - cap, spouseAge: 50)

            #expect(oneQualifies > 0,
                    "\(state.abbreviation): the probe produced no tax at all, so nothing below is meaningful")
            #expect(bothQualify < oneQualifies,
                    "\(state.abbreviation) claims a per-spouse exclusion the engine does not double")
            #expect(abs(bothQualify - oneQualifiesOnACapLessPension) < 0.01,
                    """
                    \(state.abbreviation): the second qualifying spouse moved the taxable base by \
                    something other than one full cap. Both spouses qualifying gave \
                    \(bothQualify); one spouse qualifying on a pension \(cap) smaller gave \
                    \(oneQualifiesOnACapLessPension). Those are the same household's base and \
                    must produce the same tax.
                    """)
        }

        // Deliberately a literal, for the same reason `["GA", "IA", "IN"]` is one
        // above: a jurisdiction that gains or loses a per-spouse cap has to be
        // acknowledged here rather than quietly changing what this gate covers,
        // and an empty sweep would otherwise pass in silence.
        #expect(checked == ["GA", "NY"],
                "the covered jurisdictions claiming a per-spouse cap changed: \(checked)")
    }

    /// The one probe, built from `GoldenScenarioSingleYearTests.singleYearStateTax`'s
    /// own construction rather than an invented one.
    ///
    /// Married filing jointly with a spouse enabled, primary aged 75 so every
    /// covered state's regular age gate is cleared, and one private-employer
    /// defined-benefit pension so no per-source rule can match and change the
    /// pooled figure underneath the comparison. New York's rule names
    /// `nyStateOrLocal`, `federalCivilian` and `uniformedServices`, so a
    /// private pension is left to the pooled cap this test is about.
    ///
    /// `postExemptionDeduction` is computed with BOTH ages qualifying and
    /// passed unchanged to every probe. That is deliberate: a state granting a
    /// per-filer senior addition would otherwise give the younger-spouse probe
    /// a smaller exemption and therefore a higher tax, which biases the
    /// comparison in the direction the test is trying to prove. Holding it
    /// constant leaves the spouse's age affecting exactly one thing.
    private static func perSpouseProbe(state: USState,
                                       pension: Double,
                                       spouseAge: Int) -> Double {
        let config = StateTaxData.config(for: state)

        let stateStandardDeduction: Double
        switch config.stateDeduction {
        case .fixed(_, let married): stateStandardDeduction = married
        case .none: stateStandardDeduction = 0
        // Unreachable: the caller records an issue and skips this case rather
        // than reaching here, because reproducing the federal deduction is the
        // whole of `singleYearStateTax`'s longest branch and a silent 0 would
        // make the probe quietly wrong instead of loudly unsupported.
        case .conformsToFederal: stateStandardDeduction = 0
        }

        let postExemptionDeduction = config.personalExemption?
            .amount(filingStatus: .marriedFilingJointly, enableSpouse: true,
                    primaryAge: 75, spouseAge: 75) ?? 0

        return TaxCalculationEngine.calculateStateTax(
            income: max(0, pension - stateStandardDeduction),
            forState: state,
            filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0,
            incomeSources: [IncomeSource(name: "Pension", type: .pension,
                                         annualAmount: pension,
                                         planStructure: .definedBenefit,
                                         planSource: .privateEmployer)],
            currentAge: 75,
            enableSpouse: true,
            spouseBirthYear: 2026 - spouseAge,
            currentYear: 2026,
            scenarioRetirementDistributions: 0,
            scenarioRothConversionAmount: 0,
            postExemptionDeduction: postExemptionDeduction)
    }

    /// The Social Security line is the page's most-read sentence, and it is
    /// also the one a config echo would validate most convincingly: the
    /// statement is generated straight from `socialSecurityExempt`, so reading
    /// that flag back would prove only that a boolean equals itself.
    ///
    /// What is asserted instead: feeding the engine taxable Social Security
    /// must LOWER the tax for a jurisdiction whose page says the benefit is not
    /// taxed, and must leave it UNCHANGED for one whose page says it is taxed
    /// as ordinary income. Both directions, over every covered jurisdiction.
    ///
    /// The nine untaxed jurisdictions are outside this by construction: they
    /// emit no Social Security statement at all (Task 6), so there is no claim
    /// here to back, and asserting one would be asserting a Texas Social
    /// Security exemption against a Texas income tax that does not exist.
    @Test("The Social Security statement is backed by what the engine does with the benefit")
    func socialSecurityStatementsMatchEngineBehaviour() {
        for state in StateAccuracyContent.coveredJurisdictions.sorted(by: { $0.abbreviation < $1.abbreviation }) {
            let statements = StateAccuracyContent.factualStatements(for: state, filingStatus: .single)
            guard let line = statements.first(where: { $0.label == "Social Security" })?.value else {
                #expect(!StateTaxData.config(for: state).taxSystem.hasIncomeTax,
                        "\(state.abbreviation) taxes income but its page says nothing about Social Security")
                continue
            }
            let saysExempt = line == "Not taxed by this state."

            let withoutBenefit = Self.socialSecurityProbe(state: state, taxableSocialSecurity: 0)
            let withBenefit = Self.socialSecurityProbe(state: state, taxableSocialSecurity: 30_000)

            if saysExempt {
                #expect(withBenefit < withoutBenefit,
                        """
                        \(state.abbreviation)'s page says Social Security is not taxed, but the \
                        engine charged the same tax with a taxable benefit as without one \
                        (\(withBenefit) against \(withoutBenefit)).
                        """)
            } else {
                #expect(abs(withBenefit - withoutBenefit) < 0.01,
                        """
                        \(state.abbreviation)'s page says Social Security is taxed as ordinary \
                        income, but the engine subtracted it: \(withBenefit) against \
                        \(withoutBenefit).
                        """)
            }
        }
    }

    /// Same construction as `perSpouseProbe`, single filer, varying only the
    /// taxable Social Security handed to the engine. The state-taxable `income`
    /// is held constant on purpose: the engine's Social Security subtraction
    /// applies to the income it is already given, so varying both would test
    /// arithmetic rather than the exemption.
    private static func socialSecurityProbe(state: USState,
                                            taxableSocialSecurity: Double) -> Double {
        let config = StateTaxData.config(for: state)
        let stateStandardDeduction: Double
        switch config.stateDeduction {
        case .fixed(let single, _): stateStandardDeduction = single
        case .none, .conformsToFederal: stateStandardDeduction = 0
        }
        let postExemptionDeduction = config.personalExemption?
            .amount(filingStatus: .single, enableSpouse: false,
                    primaryAge: 75, spouseAge: 75) ?? 0

        return TaxCalculationEngine.calculateStateTax(
            income: max(0, 120_000 - stateStandardDeduction),
            forState: state,
            filingStatus: .single,
            taxableSocialSecurity: taxableSocialSecurity,
            incomeSources: [],
            currentAge: 75,
            enableSpouse: false,
            spouseBirthYear: 1951,
            currentYear: 2026,
            scenarioRetirementDistributions: 0,
            scenarioRothConversionAmount: 0,
            postExemptionDeduction: postExemptionDeduction)
    }

    /// WHAT GATE 3 CANNOT SEE, recorded as an executable statement rather than
    /// a comment, because the design names this exact risk and this branch
    /// carries a live instance of it.
    ///
    /// `TaxCalculationEngine.calculateStateTax` subtracts
    /// `californiaExemptionCredits(...)` behind a `state == .california` branch.
    /// No field of `StateTaxConfig` carries it, so a page generated from that
    /// config cannot mention it, and no behaviour probe written against the
    /// config could discover it either: there is no claim to test, because the
    /// page makes none. The page is not WRONG about California; it is silent
    /// about a reduction California filers actually receive.
    ///
    /// So the gate this test can honestly hold is the SCOPE one: a jurisdiction
    /// whose tax the engine changes by name, outside anything the configuration
    /// expresses, must not be one this release publishes an accuracy page for.
    /// California is outside `coveredJurisdictions` today, and this is what
    /// makes adding it a deliberate act: it fails here until either the credits
    /// gain a config representation or a limitation sentence discloses them.
    ///
    /// The literal is maintained by hand and cannot be derived, because the
    /// thing it names is Swift source rather than data. It was compiled by
    /// sweeping the production tree for a state compared by name inside a tax
    /// computation; as of this commit `TaxCalculationEngine.swift:405` and its
    /// single-year mirror `DataManager.swift:1229` are the only two, and both
    /// name California.
    static let jurisdictionsWithEngineLogicNoConfigExpresses: Set<USState> = [.california]

    @Test("No covered jurisdiction's tax depends on engine logic its configuration cannot express")
    func coveredJurisdictionsCarryNoUnrepresentedEngineLogic() {
        let overlap = StateAccuracyContent.coveredJurisdictions
            .intersection(Self.jurisdictionsWithEngineLogicNoConfigExpresses)
        #expect(overlap.isEmpty,
                """
                \(overlap.map(\.abbreviation).sorted()) ship a generated accuracy page while \
                their tax is changed by hardcoded engine logic no configuration field carries, \
                so the page cannot state it and no behaviour probe can discover it. Give the \
                logic a config representation, or a limitation sentence, before covering the \
                jurisdiction.
                """)
    }

    /// The literal above is not decorative: California really does receive a
    /// reduction the page cannot see. Asserted so a future refactor that moves
    /// the credits into config makes this fail and the literal get cleaned up,
    /// rather than leaving a stale exclusion behind forever.
    @Test("California's exemption credits are real, and the generated page states nothing about them")
    func californiaCreditsAreInvisibleToAConfigGeneratedPage() {
        let credit = TaxCalculationEngine.californiaExemptionCredits(
            filingStatus: .marriedFilingJointly, agi: 120_000,
            currentAge: 70, enableSpouse: true, spouseBirthYear: 1956, currentYear: 2026)
        #expect(credit > 0, """
            California's exemption credits are now zero for an ordinary joint household. If they \
            were moved into StateTaxConfig, drop California from \
            jurisdictionsWithEngineLogicNoConfigExpresses rather than leaving a stale exclusion.
            """)

        for status in FilingStatus.allCases {
            for statement in StateAccuracyContent.factualStatements(for: .california,
                                                                     filingStatus: status) {
                #expect(!statement.value.lowercased().contains("credit"),
                        """
                        California's page now mentions a credit. It is generated from config, \
                        which carries none, so either the credits moved into config or the page \
                        started authoring prose.
                        """)
            }
        }
    }

    // MARK: - Task 8, Gate 1: disclosure completeness, bidirectional

    /// Why a covered jurisdiction is entitled to ship the sentences it ships.
    ///
    /// Traceability is per JURISDICTION, not per sentence, and that limit is
    /// worth stating rather than glossing: `StateLimitation` carries `text` and
    /// `topic` and no citation field, so nothing in the data links one sentence
    /// to one catalogue entry. Adding such a field is a config schema change
    /// and belongs with the disclosure taxonomy the design assigns to Phase 6.
    /// What this gate can enforce is that every jurisdiction with a sentence
    /// has a recorded reason to have one, that the reason survives being
    /// checked against the live catalogue, and that the COUNT of sentences is
    /// declared, so a correction cannot leave one behind unnoticed.
    enum LimitationBasis {
        /// At least one golden scenario for this jurisdiction carries a
        /// `knownDefect` block. Verified against the live catalogue.
        case pinnedDefect
        /// At least one `GoldenScenarioDefectCatalogueTests.knownButUnpinned`
        /// entry names this jurisdiction. Verified against the live list.
        case unpinnedCatalogue
        /// NEITHER, and therefore the category that has to be argued for. The
        /// sentence is not about a defect against this tax year's law at all.
        /// The reason is required and checked to be non-empty; the ABSENCE of a
        /// defect is checked too, so this cannot be used to park a finding that
        /// does trace and would otherwise be caught by direction 1.
        case disclosureOnly(reason: String)
    }

    /// Every covered jurisdiction, its basis, and how many sentences it ships.
    ///
    /// THE COUNT IS THE FORCING FUNCTION the design asks for. "A corrected
    /// defect forces removal or revision of its limitation" cannot be enforced
    /// by the basis alone, because a jurisdiction with two findings keeps its
    /// basis when one of them is fixed. The count fails, and someone has to
    /// decide whether the surviving sentence is still true.
    static let limitationBasis: [String: (basis: LimitationBasis, sentences: Int)] = [
        "AZ": (.unpinnedCatalogue, 2),
        "DC": (.unpinnedCatalogue, 2),
        "GA": (.disclosureOnly(reason: """
            Georgia's configuration is correct for TY2026 and no golden case disagrees with the \
            state's own form. It shipped ONE sentence, about the TY2027 retirement-income \
            exclusion, and that sentence was REMOVED on 2026-08-06: it was factually garbled \
            (it called the $70,000 a standard deduction when Georgia's standard deduction is \
            $15,000/$30,000 and the $70,000 is the exclusion), it said "this config" on a user \
            surface, it stated no direction where every other sentence says overstated or \
            understated, and its "pension" topic put it inside the pension editor under "What \
            kind of pension is this?", which is the placement LimitationTopic exists to \
            prevent. It predates this branch and had no production consumer; this branch built \
            two readers for it, and it is not among the thirteen sentences John approved. \
            Georgia now ships zero, and the underlying TY2027 fact is kept in \
            .claude/memory/roadmap/2026-08-02-full-50-state-verification.md. A replacement is \
            John's copy to approve, not an implementer's to write.
            """), 0),
        "HI": (.unpinnedCatalogue, 1),
        "IA": (.disclosureOnly(reason: """
            Iowa was a Phase 5a correction and ships NO sentence. It is here so the table covers \
            the whole of coveredJurisdictions and a jurisdiction cannot escape this gate by being \
            left out of it. Its zero is load-bearing: the empty-state wording is what an Iowa \
            reader sees, and coveredJurisdictionsWithEmptyListsClaimNothing pins that it claims \
            nothing.
            """), 0),
        "ID": (.unpinnedCatalogue, 1),
        "IN": (.disclosureOnly(reason: """
            Indiana, like Iowa: a Phase 5a correction shipping no sentence, listed so the table \
            covers the covered set exactly.
            """), 0),
        "KS": (.unpinnedCatalogue, 1),
        "MA": (.unpinnedCatalogue, 2),
        "MO": (.unpinnedCatalogue, 2),
        "NC": (.unpinnedCatalogue, 2),
        "NM": (.pinnedDefect, 1),
        "NY": (.unpinnedCatalogue, 1),
        "UT": (.pinnedDefect, 2),
        "VT": (.pinnedDefect, 1)
    ]

    /// Gate 1, all four directions, modelled on
    /// `Phase5bUnclassifiedPensionDisclosureTests.rulesAndDisclosuresStayInLockstep`.
    ///
    ///   1. Every covered jurisdiction carrying a pinned `knownDefect` ships at
    ///      least one limitation.
    ///   2. Every limitation traces to a pinned defect, a `knownButUnpinned`
    ///      catalogue entry, or a documented disclosure-only finding.
    ///   3. A corrected defect forces removal or revision, through the declared
    ///      sentence count and through the basis falling away.
    ///   4. No orphan disclosure survives: a jurisdiction shipping a sentence
    ///      whose basis no longer exists fails, and so does a jurisdiction
    ///      OUTSIDE the covered set that ships one at all.
    @Test("Limitations and the findings behind them stay in lockstep, both directions")
    func limitationsAndFindingsStayInLockstep() throws {
        let pinned = Set(try GoldenScenarioDefectCatalogueTests.catalogue().map(\.state))
        let unpinned = Set(GoldenScenarioDefectCatalogueTests.knownButUnpinned.map(\.state))
        let covered = StateAccuracyContent.coveredJurisdictions
            .sorted { $0.abbreviation < $1.abbreviation }
        let coveredAbbreviations = Set(covered.map(\.abbreviation))

        // The table covers the covered set exactly, so a jurisdiction cannot
        // escape this gate by being absent from the table.
        #expect(Set(Self.limitationBasis.keys) == coveredAbbreviations,
                """
                The basis table and coveredJurisdictions disagree. Only in the table: \
                \(Set(Self.limitationBasis.keys).subtracting(coveredAbbreviations).sorted()). \
                Only in the covered set: \
                \(coveredAbbreviations.subtracting(Self.limitationBasis.keys).sorted()).
                """)

        for state in covered {
            let abbreviation = state.abbreviation
            let sentences = StateAccuracyContent.limitations(for: state)
            let declared = try #require(Self.limitationBasis[abbreviation],
                                        "\(abbreviation) has no declared basis")

            // DIRECTION 1: a pinned defect must produce a sentence.
            if pinned.contains(abbreviation) {
                #expect(!sentences.isEmpty,
                        """
                        \(abbreviation) carries a pinned knownDefect and ships no limitation, so \
                        a user reading its accuracy page is told nothing about a disagreement \
                        with the state's own published form that this repository has measured.
                        """)
            }

            // DIRECTION 3: revision is forced by the count.
            #expect(sentences.count == declared.sentences,
                    """
                    \(abbreviation) ships \(sentences.count) limitation sentences, the table \
                    declares \(declared.sentences). If a finding was corrected, remove its \
                    sentence and this count together; if one was added, record why it is \
                    admissible.
                    """)

            // DIRECTIONS 2 and 4: the declared basis must still hold.
            switch declared.basis {
            case .pinnedDefect:
                #expect(pinned.contains(abbreviation),
                        """
                        \(abbreviation)'s limitations are declared to rest on a pinned defect and \
                        no golden scenario carries one any more. If the defect was fixed, its \
                        sentence is now an ORPHAN telling users about a problem that no longer \
                        exists: delete it, or re-declare the basis.
                        """)
            case .unpinnedCatalogue:
                #expect(unpinned.contains(abbreviation),
                        """
                        \(abbreviation)'s limitations are declared to rest on a knownButUnpinned \
                        catalogue entry and no entry names it any more. If the finding was \
                        resolved, its sentence is now an ORPHAN: delete it, or re-declare the \
                        basis.
                        """)
            case .disclosureOnly(let reason):
                #expect(!reason.isEmpty, "\(abbreviation): disclosureOnly with no reason recorded")
                #expect(!pinned.contains(abbreviation) && !unpinned.contains(abbreviation),
                        """
                        \(abbreviation) is declared disclosure-only but a defect now traces to it. \
                        That category is for findings that are NOT defects against this tax year's \
                        law; using it for one that is would hide the traceable finding from \
                        direction 1. Re-declare the basis.
                        """)
            }
        }

        // DIRECTION 4, the outward half: nothing outside the covered set ships
        // a sentence. A limitation on an uncovered jurisdiction would carry no
        // verification date, no primary source and no entry in this table, so
        // nothing would ever check it again.
        for state in USState.allCases where !StateAccuracyContent.coveredJurisdictions.contains(state) {
            #expect(StateAccuracyContent.limitations(for: state).isEmpty,
                    """
                    \(state.abbreviation) is outside coveredJurisdictions and ships a limitation. \
                    Gate 4 does not require its verification metadata, so the sentence has no \
                    date, no source and no recorded basis. Add the jurisdiction to the covered \
                    set, with its provenance, or remove the sentence.
                    """)
        }
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
