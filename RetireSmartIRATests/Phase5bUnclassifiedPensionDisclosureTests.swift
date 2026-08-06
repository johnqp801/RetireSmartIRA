//
//  Phase5bUnclassifiedPensionDisclosureTests.swift
//  RetireSmartIRATests
//
//  Phase 5b Task 3b. Two disclosures exist to tell a user that a per-source
//  rule is going unused because their pension is unclassified. Both were
//  hardcoded to New York, so the Kansas KPERS holder Task 3 had just made
//  correct was silently over-taxed with no warning while an identically
//  placed New York user was warned twice. Task 3b gates both on the relevant
//  jurisdiction's OWN config instead, and takes the jurisdiction-specific
//  sentence from that config.
//
//  WHAT THIS FILE IS FOR, and what it is not.
//
//  The load-bearing test here is `newYorkCopyIsByteIdenticalToWhatShipped`.
//  New York's wording is live and user-visible, and moving a string from a
//  Swift literal into JSON is exactly the kind of change that drifts a
//  character and is never noticed. The two literals in that test were
//  extracted mechanically from the pre-change sources at HEAD 93d91c0
//  (StateComparisonView.swift's `unclassifiedNewYorkPensionLimitationText`
//  and MultiYearCPABriefing.swift's `newYorkUnclassifiedPensionLimitation`),
//  not retyped, and they are 250 and 248 characters long respectively. They
//  are the definition of "did not drift", so nothing in this file may be
//  "fixed" by editing them: if they stop matching, the SHIPPED COPY changed
//  and that is a decision for John, not for a test edit.
//
//  Everything else here exists because the New York-only gate was never
//  caught: seven tests covered both surfaces before this task and every one
//  of them passed while Kansas got no warning at all, because each asserted
//  only "New York fires, California does not" and "the text is non-empty".
//  Non-emptiness is what let the copy be untestable, and hardcoding New York
//  into the TEST as well as the code is what let the gap survive review.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 5b Task 3b: the unclassified-pension disclosure follows the config, not New York")
struct Phase5bUnclassifiedPensionDisclosureTests {

    // MARK: - The regression guard: New York's shipped copy did not move

    /// Extracted from `StateComparisonView.swift` at HEAD 93d91c0, before
    /// this task touched it. 250 characters.
    static let shippedStateComparisonTextNY =
        "Your pension is not yet classified as government or private in Income Sources. New York excludes a qualifying government pension from state tax with no dollar cap, but this figure applies the standard $20,000 pension exclusion until it is classified."

    /// Extracted from `MultiYearCPABriefing.swift` at HEAD 93d91c0, before
    /// this task touched it. 248 characters. Differs from the string above
    /// at exactly one place, character 173: "this figure" against "this
    /// plan". That single difference is the whole reason the config sentence
    /// carries a token rather than being stored twice.
    static let shippedCPABriefingTextNY =
        "Your pension is not yet classified as government or private in Income Sources. New York excludes a qualifying government pension from state tax with no dollar cap, but this plan applies the standard $20,000 pension exclusion until it is classified."

    @Test("""
          New York's copy on both surfaces is byte-identical to what shipped before the sentence \
          moved into config
          """)
    func newYorkCopyIsByteIdenticalToWhatShipped() throws {
        let comparison = try #require(
            StateComparisonPresentation.unclassifiedPensionLimitationText(viewedState: .newYork),
            "New York ships perSourceExemptions, so it must also ship a disclosure sentence")
        let briefing = try #require(
            UnclassifiedPensionDisclosure.text(for: .newYork, scope: .cpaBriefingPlan))

        #expect(comparison == Self.shippedStateComparisonTextNY,
                """
                State Comparison's New York copy CHANGED. This string is live and \
                user-visible. Expected (\(Self.shippedStateComparisonTextNY.count) chars):
                \(Self.shippedStateComparisonTextNY)
                Got (\(comparison.count) chars):
                \(comparison)
                """)
        #expect(briefing == Self.shippedCPABriefingTextNY,
                """
                The CPA briefing's New York copy CHANGED. This string is live and \
                user-visible. Expected (\(Self.shippedCPABriefingTextNY.count) chars):
                \(Self.shippedCPABriefingTextNY)
                Got (\(briefing.count) chars):
                \(briefing)
                """)
    }

    @Test("The CPA briefing's New York limitation array carries exactly that one byte-identical string")
    func newYorkBriefingArrayIsByteIdentical() {
        let limitations = MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: .newYork, hasUnclassifiedPension: true)
        #expect(limitations == [Self.shippedCPABriefingTextNY])
    }

    // MARK: - Kansas, the state the New York-only gate silently skipped

    @Test("Kansas now fires on State Comparison, which it did not before this task")
    func kansasFiresOnStateComparison() throws {
        #expect(StateComparisonPresentation.showsUnclassifiedPensionLimitation(
            viewedState: .kansas, hasUnclassifiedPension: true))
        let text = try #require(
            StateComparisonPresentation.unclassifiedPensionLimitationText(viewedState: .kansas))
        #expect(text.hasPrefix(UnclassifiedPensionDisclosure.leadSentence + " "))
        #expect(text.contains("Kansas exempts a KPERS"),
                "the Kansas sentence must name Kansas's own mechanics, got: \(text)")
        #expect(text.contains("this figure"),
                "State Comparison shows a FIGURE, so its scope word is 'this figure'; got: \(text)")
        #expect(!text.contains("this plan"))
    }

    @Test("Kansas now fires on the CPA briefing, which it did not before this task")
    func kansasFiresOnCPABriefing() throws {
        let limitations = MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: .kansas, hasUnclassifiedPension: true)
        let text = try #require(limitations.first)
        #expect(limitations.count == 1)
        #expect(text.hasPrefix(UnclassifiedPensionDisclosure.leadSentence + " "))
        #expect(text.contains("Kansas exempts a KPERS"))
        #expect(text.contains("this plan"),
                "the briefing describes a PLAN, so its scope word is 'this plan'; got: \(text)")
        #expect(!text.contains("this figure"))
    }

    @Test("The rendered CPA briefing HTML carries the Kansas sentence, not just the array")
    func kansasSentenceReachesTheRenderedBriefingHTML() throws {
        let extra = MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: .kansas, hasUnclassifiedPension: true)
        #expect(!extra.isEmpty)
        let model = Phase3bPresentationTests.briefingModel(
            limitations: V2Disclosures.limitations + extra)
        let html = MultiYearCPABriefingHTML.build(model)
        for line in extra {
            #expect(html.contains(MultiYearCPABriefingHTML.escapeForTest(line)),
                    "the Kansas disclosure never reached the rendered briefing")
        }
    }

    // MARK: - Neither surface fires without a reason to

    @Test("A jurisdiction with no per-source rules fires on neither surface",
          arguments: [USState.california, .pennsylvania, .texas, .newJersey])
    func stateWithoutPerSourceRulesFiresOnNeitherSurface(state: USState) {
        #expect(StateTaxData.config(for: state).retirementExemptions.perSourceExemptions.isEmpty,
                "\(state.abbreviation) was chosen for this test BECAUSE it has no per-source rules")
        #expect(!StateComparisonPresentation.showsUnclassifiedPensionLimitation(
            viewedState: state, hasUnclassifiedPension: true))
        #expect(StateComparisonPresentation.unclassifiedPensionLimitationText(viewedState: state) == nil)
        #expect(MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: state, hasUnclassifiedPension: true).isEmpty)
    }

    @Test("A classified pension fires on neither surface, even where rules exist",
          arguments: [USState.newYork, .kansas])
    func classifiedPensionFiresOnNeitherSurface(state: USState) {
        #expect(!StateComparisonPresentation.showsUnclassifiedPensionLimitation(
            viewedState: state, hasUnclassifiedPension: false))
        #expect(MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: state, hasUnclassifiedPension: false).isEmpty)
    }

    // MARK: - The two surfaces gate on DIFFERENT things, deliberately

    @Test("""
          State Comparison keys on the VIEWED state while the CPA briefing keys on RESIDENCE, and \
          collapsing them would be a regression
          """)
    func viewedStateAndResidenceGatesStayDistinct() {
        // A California resident comparing New York's column is reading a New
        // York number this app computed for them, so State Comparison warns
        // them. `showsUnclassifiedPensionLimitation` takes no residence
        // argument AT ALL, which is what makes that structural rather than
        // remembered: there is no residence to accidentally gate on.
        #expect(StateComparisonPresentation.showsUnclassifiedPensionLimitation(
            viewedState: .newYork, hasUnclassifiedPension: true))
        #expect(StateComparisonPresentation.showsUnclassifiedPensionLimitation(
            viewedState: .kansas, hasUnclassifiedPension: true))

        // The same household's CPA briefing describes THEIR OWN plan, which
        // is a California plan, so it carries no New York or Kansas
        // sentence. If this ever starts returning a sentence, the briefing
        // has begun keying on something other than residence.
        #expect(MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: .california, hasUnclassifiedPension: true).isEmpty)
    }

    // MARK: - The sweep that makes tasks 4 through 9 impossible to forget

    /// John's decision (2026-08-05) was that every jurisdiction shipping a
    /// per-source rule owes its own disclosure sentence, because the copy
    /// names that state's own mechanics and cannot be generalised. Phase 5b
    /// tasks 4 through 9 (MA, HI, AZ, NC, ID, VT and DC) each add a rule.
    /// Without this test, any one of them could ship the rule, forget the
    /// sentence, and reproduce Kansas's exact defect with a green suite.
    @Test("Every jurisdiction with per-source rules ships a disclosure sentence, and vice versa")
    func rulesAndDisclosuresStayInLockstep() {
        var withRules: [USState] = []
        var withDisclosure: [USState] = []
        for state in USState.allCases {
            let ex = StateTaxData.config(for: state).retirementExemptions
            if !ex.perSourceExemptions.isEmpty { withRules.append(state) }
            if ex.unclassifiedPensionDisclosure != nil { withDisclosure.append(state) }
        }

        #expect(withRules.map(\.abbreviation).sorted() == withDisclosure.map(\.abbreviation).sorted(),
                """
                A jurisdiction's per-source rule and its unclassified-pension disclosure must \
                ship together. Rules: \(withRules.map(\.abbreviation).sorted()). Disclosures: \
                \(withDisclosure.map(\.abbreviation).sorted()). A state in the first list and \
                not the second silently over-taxes an unclassified pension with no warning, \
                which is the Kansas defect this task exists to close. A state in the second and \
                not the first shows a warning about a rule it does not have.
                """)

        #expect(withRules.contains(.newYork))
        #expect(withRules.contains(.kansas))
    }

    @Test("Every shipped disclosure sentence is well formed")
    func everyShippedSentenceIsWellFormed() {
        for state in USState.allCases {
            guard let sentence =
                    StateTaxData.config(for: state).retirementExemptions.unclassifiedPensionDisclosure
            else { continue }
            let abbr = state.abbreviation

            let tokenCount = sentence.components(
                separatedBy: UnclassifiedPensionDisclosure.scopeToken).count - 1
            #expect(tokenCount == 1,
                    """
                    \(abbr)'s sentence must carry the scope token \
                    \(UnclassifiedPensionDisclosure.scopeToken) exactly once, found \
                    \(tokenCount). The token is what lets one stored sentence serve both \
                    surfaces; without it the sentence reads identically on a screen showing a \
                    figure and in a document describing a plan.
                    """)
            #expect(sentence.contains(abbr) || sentence.contains(state.rawValue),
                    "\(abbr)'s sentence should name its own jurisdiction, got: \(sentence)")
            #expect(!sentence.contains(UnclassifiedPensionDisclosure.leadSentence),
                    """
                    \(abbr) repeats the lead sentence, which the composer already prepends. \
                    The user would read it twice.
                    """)
            #expect(!sentence.contains("\u{2014}"), "\(abbr)'s sentence contains an em dash")
            #expect(sentence.hasSuffix("."), "\(abbr)'s sentence should end in a period")
        }
    }

    // MARK: - The composer itself

    @Test("The scope token cannot occur in ordinary prose")
    func scopeTokenIsNotProse() {
        let token = UnclassifiedPensionDisclosure.scopeToken
        #expect(!token.isEmpty)
        #expect(token.contains("{") && token.contains("}"),
                "the token must be visibly non-prose so a reviewer sees it in the JSON")
        #expect(!UnclassifiedPensionDisclosure.leadSentence.contains(token))
    }

    @Test("Substitution replaces the token and leaves the rest of the sentence untouched")
    func substitutionTouchesOnlyTheToken() throws {
        let raw = try #require(
            StateTaxData.config(for: .newYork).retirementExemptions.unclassifiedPensionDisclosure)
        let figure = try #require(
            UnclassifiedPensionDisclosure.text(for: .newYork, scope: .stateComparisonFigure))
        let plan = try #require(
            UnclassifiedPensionDisclosure.text(for: .newYork, scope: .cpaBriefingPlan))

        #expect(!figure.contains(UnclassifiedPensionDisclosure.scopeToken),
                "an unsubstituted token reached user-visible copy: \(figure)")
        #expect(!plan.contains(UnclassifiedPensionDisclosure.scopeToken))
        // The only difference between the two rendered strings is the scope
        // word, which is exactly what the shipped New York pair proves too.
        #expect(figure.replacingOccurrences(of: "this figure", with: UnclassifiedPensionDisclosure.scopeToken)
                == UnclassifiedPensionDisclosure.leadSentence + " " + raw)
        #expect(plan.replacingOccurrences(of: "this plan", with: UnclassifiedPensionDisclosure.scopeToken)
                == UnclassifiedPensionDisclosure.leadSentence + " " + raw)
    }

    // MARK: - The config field is additive

    @Test("A config JSON with no disclosure key decodes with a nil disclosure")
    func absentKeyDecodesToNil() throws {
        let minimal = Data("""
        {
            "state": "CA",
            "taxSystem": {"kind": "flat", "rate": 0.05},
            "retirementExemptions": {"socialSecurityExempt": true,
                                     "pensionExemption": {"kind": "none"},
                                     "iraWithdrawalExemption": {"kind": "none"}},
            "stateDeduction": {"kind": "none"}
        }
        """.utf8)
        let config = try StateTaxDataLoader.decode(minimal, state: .california, taxYear: 2026)
        #expect(config.retirementExemptions.unclassifiedPensionDisclosure == nil)
        #expect(config.retirementExemptions.perSourceExemptions.isEmpty)
    }

    @Test("The disclosure survives an encode/decode round trip, and stays absent when nil")
    func disclosureRoundTrips() throws {
        var exemptions = RetirementIncomeExemptions()
        exemptions.unclassifiedPensionDisclosure = "Testland does a thing, but \(UnclassifiedPensionDisclosure.scopeToken) does not."
        let data = try JSONEncoder().encode(exemptions)
        let back = try JSONDecoder().decode(RetirementIncomeExemptions.self, from: data)
        #expect(back.unclassifiedPensionDisclosure == exemptions.unclassifiedPensionDisclosure)

        let bare = try JSONEncoder().encode(RetirementIncomeExemptions())
        let bareJSON = String(decoding: bare, as: UTF8.self)
        #expect(!bareJSON.contains("unclassifiedPensionDisclosure"),
                """
                The key must be OMITTED, not encoded as null, when a jurisdiction has no \
                disclosure. 49 shipped files carry no such key and regenerating them with one \
                would be a 49-file diff this task has no business making.
                """)
    }
}
