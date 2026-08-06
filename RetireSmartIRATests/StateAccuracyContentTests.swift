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
    @Test("Every covered jurisdiction carries a tax year, a verified date and an HTTPS source")
    func coveredJurisdictionsCarryCompleteVerification() {
        let ordered = StateAccuracyContent.coveredJurisdictions
            .sorted { $0.abbreviation < $1.abbreviation }

        for state in ordered {
            let v = StateTaxData.config(for: state).verification
            #expect(v.taxYear == 2026,
                    "\(state.abbreviation) verification.taxYear must state the config's own year")
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
        #expect(StateAccuracyContent.coveredJurisdictions.count == 15)
    }
}
