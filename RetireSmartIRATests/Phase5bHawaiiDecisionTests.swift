//
//  Phase5bHawaiiDecisionTests.swift
//  RetireSmartIRATests
//
//  Phase 5b Task 5: Hawaii. The one task in this phase whose deliverable is a
//  DECISION rather than a rule, and this file is that decision made executable
//  so it cannot quietly evaporate the way a report does.
//
//  THE DECISION: Hawaii ships NO `perSourceExemptions`. It stays "disclosed,
//  not modelled" per Phase 4, and the three `knownDefect` blocks in
//  statetax-2026-HI.golden.json stay. The plan's own text sanctions this
//  outcome outright ("if not, this is a disclosure item for Phase 6 and the
//  blocks stay").
//
//  WHY, in one sentence a future contributor can check against the tests
//  below: Hawaii's exclusion turns on WHO FUNDED the plan, no field on
//  `RetirementPlanClassification` records that, and the only field close
//  enough to be pressed into service, `PlanStructure.definedBenefit`, is
//  already carrying the OPPOSITE funding meaning in Massachusetts's shipped
//  rule on this same branch.
//
//  WHAT MAKES THIS MORE THAN AN OPINION, and the reason these tests exist:
//  the rule that was declined would have made every Hawaii golden case pass.
//  That was MEASURED, not predicted. A rule of `matchStructures:
//  ["definedBenefit"]` with an empty `matchSources` was temporarily added to
//  the shipped Hawaii config and `GoldenScenarioSingleYearTests` reported
//  HI-1, HI-3 and HI-4 as all three now matching their published form ($0.00,
//  $0.00, $266.00), with no fixture in the set objecting, while that same rule
//  granted a full Hawaii exclusion to every CONTRIBUTORY defined-benefit
//  pension, which Hawaii Schedule J excludes only in part. "Every test is
//  green" was therefore available and would have been wrong. The mutation was
//  reverted; these tests reproduce its consequences without shipping it.
//
//  WHAT THIS FILE DOES NOT DO: it does not re-derive Hawaii law. The golden
//  fixture is the specification, per the shared procedure, and its quoted
//  Schedule J text is the only authority relied on here.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 5b Task 5: Hawaii ships no per-source rule, and this is why")
struct Phase5bHawaiiDecisionTests {

    /// The REAL shipped Hawaii config, never a test-shaped stand-in.
    static var hawaiiExemptions: RetirementIncomeExemptions {
        StateTaxData.config(for: .hawaii).retirementExemptions
    }

    /// The rule Task 5 DECLINED to ship, reproduced here and nowhere else so
    /// its consequences can be asserted without any of them reaching a user.
    /// Hawaii's exclusion does not turn on employer type at all (HI-1's source:
    /// "Hawaii's rule keys on WHO FUNDED the plan, not on employer type"), so
    /// the only shape available was structure-only with `matchSources` empty,
    /// which `PerSourceExemptionRule.matches` reads as "any source".
    static let declinedRule = PerSourceExemptionRule(
        matchSources: [],
        matchStructures: [.definedBenefit],
        treatment: .full
    )

    // MARK: - The decision itself

    @Test("Hawaii ships no per-source exemption rule")
    func hawaiiShipsNoPerSourceRule() {
        #expect(Self.hawaiiExemptions.perSourceExemptions.isEmpty,
                """
                Hawaii now ships a per-source rule. Phase 5b Task 5 decided it should not, \
                on the ground that Hawaii's exclusion is conditioned on who funded the plan \
                and RetirementPlanClassification records no such fact. If a contributory \
                axis was added, this whole file should be replaced by golden cases for the \
                contributory and noncontributory households, and the HI entry in \
                GoldenScenarioDefectCatalogueTests.knownButUnpinned deleted in the same \
                change. If a rule was added WITHOUT that axis, read \
                theDeclinedRuleWouldExemptEveryContributoryPension below before going \
                further: it is the reason.
                """)
    }

    /// Task 3b's `rulesAndDisclosuresStayInLockstep` is bidirectional, so this
    /// is not merely a second way of saying the test above. A disclosure
    /// sentence without a rule fails the suite exactly as a rule without a
    /// sentence does, and Hawaii must ship neither.
    ///
    /// Hawaii's real disclosure is a different mechanism and is asserted
    /// separately below: `UnclassifiedPensionDisclosure` warns that a pension
    /// is UNCLASSIFIED, which is not Hawaii's problem. A Hawaii pension can be
    /// perfectly classified and still be taxed wrongly, because the fact
    /// Hawaii needs is not on the classification at all.
    @Test("Hawaii ships no unclassified-pension disclosure sentence either")
    func hawaiiShipsNoDisclosureSentence() {
        #expect(Self.hawaiiExemptions.unclassifiedPensionDisclosure == nil,
                """
                Hawaii now ships an unclassifiedPensionDisclosure sentence with no rule to \
                go with it. Phase 5b Task 3b's lockstep sweep will fail on this. The \
                sentence would also be false for Hawaii: it tells a user their exclusion is \
                waiting on classification, and Hawaii's is not.
                """)
        #expect(UnclassifiedPensionDisclosure.text(for: .hawaii, scope: .stateComparisonFigure) == nil)
        #expect(UnclassifiedPensionDisclosure.text(for: .hawaii, scope: .cpaBriefingPlan) == nil)
    }

    // MARK: - What the declined rule would have wrongly matched

    /// The Step 3 question ("what would this wrongly match?"), answered as an
    /// assertion rather than as prose.
    ///
    /// Swept over `PlanSource.allCases`, so the answer stays complete when a
    /// later task adds a case. Every single one matches, by construction: an
    /// empty `matchSources` means "any". That includes `federalCivilian`,
    /// whose annuities are contributory (mass.gov's own closed list names the
    /// exempt federal category as federal CONTRIBUTORY pensions, quoted in the
    /// MA-2 fixture), and `ownStateOrLocal`, which is the classification a
    /// Massachusetts c. 32 contributory retiree writes.
    @Test("The declined rule would exempt every defined-benefit pension regardless of who funded it",
          arguments: PlanSource.allCases)
    func theDeclinedRuleWouldExemptEveryContributoryPension(source: PlanSource) {
        #expect(Self.declinedRule.matches(structure: .definedBenefit, source: source),
                """
                \(source) is no longer matched by a structure-only definedBenefit rule. \
                If PerSourceExemptionRule.matches changed its treatment of an empty \
                matchSources, the Task 5 reasoning needs re-checking rather than this \
                expectation being edited.
                """)
    }

    /// `unknown` deserves calling out on its own, because Kansas's shipped
    /// rule deliberately does NOT match it and every pre-Phase-3b saved row
    /// carries it. A structure-only rule cannot make that choice: it takes
    /// `unknown` too, so the migration default would silently start claiming
    /// a Hawaii exclusion on rows no user ever classified.
    @Test("The declined rule would also have matched the migration default, which Kansas's deliberately does not")
    func theDeclinedRuleWouldHaveMatchedTheMigrationDefault() {
        #expect(Self.declinedRule.matches(structure: .definedBenefit, source: .unknown))

        let kansas = StateTaxData.config(for: .kansas).retirementExemptions
        #expect(kansas.matchedPerSourceRule(structure: .definedBenefit, source: .unknown) == nil,
                """
                Kansas's rule now matches the migration default. That is the precedent \
                Task 5 relied on: a rule that names its sources can decline `unknown`, and \
                a structure-only rule cannot.
                """)
    }

    // MARK: - Why no golden case could have caught it

    /// The blocker, proven from the fixture's own data rather than asserted.
    ///
    /// The household that would catch the over-match is a CONTRIBUTORY
    /// defined-benefit pensioner. HI-1 already pins the noncontributory one.
    /// Both are the same `RetirementPlanClassification`, so a fixture for the
    /// contributory household would carry inputs byte-identical to HI-1's and
    /// a contradictory `expectedStateTax`. That is the same blocker Task 4 hit
    /// in Massachusetts, and it is why the plan's Step 3 instruction to "ADD
    /// one" if no case would catch the over-match cannot be satisfied here.
    @Test("A contributory Hawaii pensioner is byte-identical to HI-1, so no golden case can separate them")
    func noHawaiiGoldenCaseCouldCatchTheOverMatch() throws {
        let file = try GoldenScenario.load(abbreviation: "HI")
        let hi1 = try #require(file.scenarios.first)
        let row = try #require(hi1.classifiedPensionSources?.first)

        // What HI-1's noncontributory household carries.
        #expect(row.planStructure == "definedBenefit")
        #expect(row.planSource == "privateEmployer")

        // What a CONTRIBUTORY private-sector defined-benefit retiree would
        // honestly select in the picker: the same thing. There is no other
        // row for them, and nothing they could select that says otherwise.
        let whatAContributoryRetireeWouldSelect =
            PlanClassificationChoice.privateEmployerPension.classification
        #expect(whatAContributoryRetireeWouldSelect.structure.rawValue == row.planStructure)
        #expect(whatAContributoryRetireeWouldSelect.source.rawValue == row.planSource,
                """
                HI-1's classification and the picker row a contributory retiree would \
                select have diverged. If a funding affordance was added, the contributory \
                household is now expressible and this task's decision should be revisited.
                """)

        // And the fixture set contains no case that asserts a taxable
        // defined-benefit pension, which is the other half of the blocker: not
        // only can such a case not be added, none is there today.
        let taxableDefinedBenefitCases = file.scenarios.filter { scenario in
            let rows = scenario.classifiedPensionSources ?? []
            let hasDefinedBenefit = rows.contains { $0.planStructure == "definedBenefit" }
            let allDefinedBenefit = !rows.isEmpty && rows.allSatisfy { $0.planStructure == "definedBenefit" }
            return hasDefinedBenefit && allDefinedBenefit && scenario.expectedStateTax > 0
        }
        #expect(taxableDefinedBenefitCases.isEmpty,
                """
                A Hawaii golden case now asserts a taxable all-definedBenefit household: \
                \(taxableDefinedBenefitCases.map(\.name)). Something can now distinguish \
                the contributory household from HI-1's, and Task 5's decision should be \
                revisited against it.
                """)
    }

    /// The picker half of the same point. Task 3 added rows so a correct rule
    /// would be REACHABLE by a real user; Task 5's finding is that for Hawaii
    /// there is nothing to reach. No row states funding, so a Hawaii user
    /// cannot tell the app the one fact Hawaii's exclusion turns on, and every
    /// row a Hawaii pensioner can honestly select is one the declined rule
    /// would have exempted.
    @Test("No picker row lets a Hawaii user state who funded their pension")
    func thePickerOffersNoFundingAffordance() {
        for choice in PlanClassificationChoice.allCases {
            #expect(!choice.label.lowercased().contains("contributor"),
                    """
                    The picker row '\(choice.label)' now mentions contribution. If a funding \
                    affordance was added, Hawaii's decision changes: revisit this whole file \
                    and the HI knownButUnpinned entry together.
                    """)
        }

        // Every defined-benefit row a Hawaii pensioner could pick is one the
        // declined rule would have exempted, contributory or not.
        let definedBenefitRows = PlanClassificationChoice.allCases.filter {
            $0.classification.structure == .definedBenefit
        }
        #expect(!definedBenefitRows.isEmpty)
        for choice in definedBenefitRows {
            #expect(Self.declinedRule.matches(structure: choice.classification.structure,
                                              source: choice.classification.source),
                    "\(choice.rawValue) would have escaped the declined rule; the sweep above says none does")
        }
    }

    // MARK: - The field contradiction, which is the heart of the decision

    /// `PlanStructure.definedBenefit` cannot carry funding semantics, because
    /// a rule already shipped on this branch reads it the other way.
    ///
    /// Massachusetts's Task 4 rule matches `(definedBenefit, ownStateOrLocal)`
    /// for a Commonwealth of Massachusetts system, which mass.gov's quoted
    /// text calls a CONTRIBUTORY fund. A Hawaii rule would have had to read
    /// the identical tuple as NONCONTRIBUTORY. This test pins that both rules
    /// select the same tuple, which is what makes the two readings
    /// incompatible rather than merely different.
    @Test("definedBenefit carries no funding semantics: Massachusetts's shipped rule reads the same value as contributory")
    func definedBenefitCarriesNoFundingSemantics() {
        let contributoryMassachusettsRetiree =
            PlanClassificationChoice.ownStateGovernmentPension.classification

        let massachusetts = StateTaxData.config(for: .massachusetts).retirementExemptions
        #expect(massachusetts.matchedPerSourceRule(
            structure: contributoryMassachusettsRetiree.structure,
            source: contributoryMassachusettsRetiree.source) != nil,
                """
                Massachusetts's shipped rule no longer matches its own contributory \
                retiree. Task 5's decision rests on the fact that it does; re-check it.
                """)

        #expect(Self.declinedRule.matches(
            structure: contributoryMassachusettsRetiree.structure,
            source: contributoryMassachusettsRetiree.source),
                """
                The declined Hawaii rule would have matched the SAME tuple Massachusetts \
                matches as contributory, and would have had to read it as noncontributory \
                to be correct. One field, two contradictory meanings.
                """)
    }

    /// And the contradiction is reachable in one on-screen table, not just in
    /// principle. State Comparison re-reads the SAME stored rows through every
    /// state's configuration, and `DataManager.incomeSources(asResidentOf:)`
    /// remaps `planSource` only. `planStructure` is handed through untouched,
    /// so a single stored row would be read as noncontributory by Hawaii's
    /// column and as contributory by Massachusetts's column of the same grid.
    @MainActor
    @Test("The cross-state residence mapping never remaps planStructure, so one row would carry both meanings at once")
    func residenceMappingNeverRemapsPlanStructure() {
        let dm = DataManager(skipPersistence: true)
        dm.selectedState = .massachusetts
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .ownStateOrLocal)
        ]

        let asHawaiian = dm.incomeSources(asResidentOf: .hawaii)
        #expect(asHawaiian.count == 1)
        #expect(asHawaiian.first?.planStructure == .definedBenefit,
                """
                planStructure is now remapped across states. That would change Task 5's \
                reasoning: the field could then mean different things in different \
                columns by design rather than by accident.
                """)
        // planSource IS remapped, which is the contrast that makes the point:
        // the mapping exists and deliberately covers only the other axis.
        #expect(asHawaiian.first?.planSource == .otherStateOrLocal)
    }

    // MARK: - The decision stays inert, and stays recorded

    /// "Provably inert" for a task that ships no rule means the classification
    /// a user records has no effect on their Hawaii tax, and that the
    /// income-breakdown mirror agrees with the tax computation for every one
    /// of them. Swept over `PlanSource.allCases` in the same shape as Task 4's
    /// mirror check, since `DataManager.stateTaxBreakdown` hand-duplicates the
    /// engine's per-source partition and has drifted from it repeatedly.
    @MainActor
    @Test("Classification changes nothing for a Hawaii resident, and the breakdown mirror agrees",
          arguments: PlanSource.allCases)
    func hawaiiIsUnaffectedByClassification(source: PlanSource) {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 65; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .hawaii
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: source)
        ]

        let breakdown = dm.stateTaxBreakdown(forState: .hawaii, filingStatus: .single)
        let computed = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .hawaii, filingStatus: .single,
            taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)

        #expect(abs(breakdown.totalStateTax - computed) < 0.01,
                """
                Hawaii / \(source): the income-breakdown display reports \
                \(breakdown.totalStateTax) while the tax computation reports \(computed). \
                DataManager's per-source partition has drifted from \
                TaxCalculationEngine.applyRetirementExemptions.
                """)
        #expect(abs(breakdown.pensionExemptAmount) < 0.01,
                """
                Hawaii / \(source): the breakdown attributes \(breakdown.pensionExemptAmount) \
                of pension exclusion. Hawaii ships no rule, so every source must attribute \
                zero. This is the assertion that catches a Hawaii rule arriving through the \
                mirror rather than through the config.
                """)
        // The measured HI-1 figure from the fixture, reached with a
        // classification HI-1 never carries: the classification is inert.
        #expect(abs(computed - 2_107.20) < 0.01,
                "Hawaii / \(source): expected the unexcluded $2,107.20, got \(computed)")
    }

    /// The record that outlives this file's reasoning, in the same shape as
    /// Task 4's `theContributoryGapStaysRecorded`. This test fails if the
    /// entry is deleted, so a future green suite cannot mean "Hawaii is fine".
    @Test("Hawaii's employer-funded-portion gap stays recorded as a known-but-unpinned defect")
    func theEmployerFundedPortionGapStaysRecorded() throws {
        let entry = try #require(
            GoldenScenarioDefectCatalogueTests.knownButUnpinned.first { $0.state == "HI" },
            """
            Hawaii's employer-funded-portion gap is no longer recorded. Either a funding \
            axis was actually added, in which case this test should be replaced by golden \
            cases for the contributory and noncontributory households, or a real, cited \
            over-taxation was silently dropped from the catalogue.
            """)
        #expect(entry.summary.contains("EMPLOYER-FUNDED PORTION"))
        #expect(entry.blockedOn.contains("NOT EXPRESSIBLE"))
        #expect(entry.blockedOn.contains("NO ADMISSIBLE FIGURE"))
    }

    // MARK: - The disclosure, which is what a Hawaii user actually gets

    /// Phase 4 scoped Hawaii as "disclosed, not modelled", so the disclosure
    /// is the deliverable a user sees and it must survive this decision
    /// unchanged. TWO surfaces carry it, not one: the Income Sources caption
    /// (`IncomeSourcesView.swift`, a view-body literal with no test seam) and
    /// the CPA briefing, which is the one this test can reach.
    ///
    /// The DIRECTION word is the load-bearing part. Hawaii's error runs toward
    /// OVER-statement, and it still does after this decision, because nothing
    /// changed. Massachusetts's runs the other way and its caption says so.
    /// A copy edit that harmonised the two would make one of them false.
    @Test("Hawaii's CPA-briefing disclosure survives the decision and still names the right direction")
    func hawaiisDisclosureStillHoldsAfterTheDecision() throws {
        let lines = MultiYearCPABriefing.hawaiiPensionSplitLimitation(
            residesInHawaii: true, hasPensionIncome: true)
        let text = try #require(lines.first)
        #expect(text.contains("employer-funded portion"))
        #expect(text.contains("does not model the split"))
        #expect(text.contains("overstated"),
                """
                Hawaii's disclosure no longer says the tax may be OVERSTATED. Hawaii ships \
                no exclusion at all, so every error runs toward over-taxation; understated \
                would be false. If a Hawaii rule was added, this sentence needs rewriting \
                and so does the whole of this file.
                """)
        #expect(!text.contains("understated"))
    }

    /// The gating, restated here rather than left to Phase3bPresentationTests
    /// alone, because those tests assert only that the array is non-empty. A
    /// disclosure that fired for the wrong household would still pass them.
    @Test("Hawaii's disclosure is gated on residence and on having pension income")
    func hawaiisDisclosureIsCorrectlyGated() {
        #expect(MultiYearCPABriefing.hawaiiPensionSplitLimitation(
            residesInHawaii: false, hasPensionIncome: true).isEmpty)
        #expect(MultiYearCPABriefing.hawaiiPensionSplitLimitation(
            residesInHawaii: true, hasPensionIncome: false).isEmpty)
        #expect(!MultiYearCPABriefing.hawaiiPensionSplitLimitation(
            residesInHawaii: true, hasPensionIncome: true).isEmpty)
    }
}
