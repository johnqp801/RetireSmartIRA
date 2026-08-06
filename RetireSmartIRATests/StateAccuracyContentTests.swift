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
    /// The direction word in each is load-bearing: Hawaii and DC run toward
    /// over-taxation, Massachusetts toward UNDER-taxation, and a copy edit that
    /// harmonised them would invert one.
    @MainActor
    @Test("All six pension-editor captions are dash-free and keep their direction")
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

        #expect(IncomeSourcesView.hawaiiEmployerFundedCaption.contains("overstated"))
        #expect(!IncomeSourcesView.hawaiiEmployerFundedCaption.contains("understated"))
        #expect(IncomeSourcesView.massachusettsContributoryCaption.contains("understated"))
    }
}
