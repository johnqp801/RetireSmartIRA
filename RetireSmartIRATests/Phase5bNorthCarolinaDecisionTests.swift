//
//  Phase5bNorthCarolinaDecisionTests.swift
//  RetireSmartIRATests
//
//  Phase 5b Task 7: North Carolina. The second task in this phase whose
//  deliverable is a DECISION rather than a rule, and this file is that decision
//  made executable so it cannot quietly evaporate the way a report does.
//
//  THE DECISION: North Carolina ships NO `perSourceExemptions`. Its three
//  `knownDefect` blocks in statetax-2026-NC.golden.json STAY, and the Bailey
//  exclusion is recorded as remaining UNSATISFIABLE rather than as unresolved
//  law. The plan's own text sanctions this outcome outright ("Decide: add the
//  axis, or record NC as remaining unsatisfiable. Do not force it.").
//
//  WHY, in one sentence a future contributor can check against the tests below:
//  Bailey turns on whether the retiree had five or more years of creditable
//  service as of 1989-08-12, no field on `RetirementPlanClassification` records
//  that, and the only rule the model CAN express is keyed on source and
//  structure, which exempts every North Carolina public pension rather than
//  only the Bailey class.
//
//  WHAT MAKES THIS MORE THAN AN OPINION, and the reason these tests exist: the
//  rule that was declined would have made every North Carolina golden case
//  pass. That was MEASURED, not predicted, following Task 5's standard. A rule
//  of `matchSources: ["ownStateOrLocal", "federalCivilian"]` at
//  `matchStructures: ["definedBenefit"]`, treatment `full`, was temporarily
//  added to the shipped North Carolina config and `GoldenScenarioSingleYearTests`
//  reported NC-1, NC-3 and NC-4 as all three now matching their published form
//  ($0.00, $0.00, $379.05), with the only guard in the set raising no objection,
//  while that same rule silently exempts every North Carolina public employee
//  first hired after August 1984, who cannot have five years of creditable
//  service by 1989-08-12 and is fully taxable. "Every test is green" was
//  therefore available and would have been wrong. The mutation was reverted;
//  these tests reproduce its consequences without shipping it.
//
//  THE POPULATION, which is the fact that decided it and which no fixture
//  states: the Bailey class CLOSED in AUGUST 1984 and can never gain a member.
//  Five years of creditable service by 1989-08-12 requires a hire date five
//  years earlier, so the excluded group is everyone first hired from September
//  1984, not September 1989. Its complement has grown with every North Carolina
//  public hire for more than forty years and still does. Every North Carolina
//  public employee retiring today, and in every future year, is outside the
//  class.
//
//  WHAT THIS FILE DOES NOT DO: it does not re-derive North Carolina law. The
//  golden fixture is the specification, per the shared procedure, and its
//  quoted NCDOR text is the only authority relied on here.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 5b Task 7: North Carolina ships no per-source rule, and this is why")
struct Phase5bNorthCarolinaDecisionTests {

    /// The REAL shipped North Carolina config, never a test-shaped stand-in.
    static var northCarolinaExemptions: RetirementIncomeExemptions {
        StateTaxData.config(for: .northCarolina).retirementExemptions
    }

    /// The rule Task 7 DECLINED to ship, reproduced here and nowhere else so
    /// its consequences can be asserted without any of them reaching a user.
    ///
    /// The sources are exactly the ones NC-1's quoted NCDOR sentence names
    /// ("the North Carolina Consolidated Judicial Retirement System, the
    /// Federal Employees' Retirement System, or the United States Civil Service
    /// Retirement System"), mapped onto the model as `ownStateOrLocal` and
    /// `federalCivilian`. This is the NARROWEST shape the model can express,
    /// which is the point: even at its narrowest it over-matches, because the
    /// vesting condition in that same sentence has nowhere to live.
    static let declinedRule = PerSourceExemptionRule(
        matchSources: [.ownStateOrLocal, .federalCivilian],
        matchStructures: [.definedBenefit],
        treatment: .full
    )

    /// The sources the declined rule names. Kept beside the rule so the sweep
    /// below states an expectation rather than restating the rule's own data.
    static let sourcesTheDeclinedRuleNames: Set<PlanSource> = [.ownStateOrLocal, .federalCivilian]

    /// NC-1's measured figure with no exclusion applied: $50,000 pension less
    /// the $12,750 single standard deduction, times the 3.99% flat rate. This
    /// is both the fixture's pinned `observedToday` and the correct answer for
    /// a NON-Bailey-vested North Carolina public retiree at the same shape,
    /// which is precisely the collision this task turns on.
    static let unexcludedNC1Tax = 1_486.27

    // MARK: - The decision itself

    @Test("North Carolina ships no per-source exemption rule")
    func northCarolinaShipsNoPerSourceRule() {
        #expect(Self.northCarolinaExemptions.perSourceExemptions.isEmpty,
                """
                North Carolina now ships a per-source rule. Phase 5b Task 7 decided it \
                should not, on the ground that the Bailey exclusion is conditioned on a \
                vesting fact RetirementPlanClassification does not record, so any \
                expressible rule exempts every North Carolina public pension rather than \
                only the Bailey class. If a vesting axis was added, this whole file should \
                be replaced by golden cases for the vested and non-vested households, and \
                the NC entry in GoldenScenarioDefectCatalogueTests.knownButUnpinned deleted \
                in the same change. If a rule was added WITHOUT that axis, read \
                theDeclinedRuleCannotBeNarrowedToTheBaileyClass below before going further: \
                it is the reason.
                """)
    }

    /// Task 3b's `rulesAndDisclosuresStayInLockstep` is bidirectional, so this
    /// is not merely a second way of saying the test above. A disclosure
    /// sentence without a rule fails the suite exactly as a rule without a
    /// sentence does, and North Carolina must ship neither.
    ///
    /// The sentence would also be FALSE for North Carolina, for the same reason
    /// Task 5 gave for Hawaii: `UnclassifiedPensionDisclosure` warns that a
    /// pension is UNCLASSIFIED, and that is not North Carolina's problem. A
    /// North Carolina pension can be perfectly classified, by a user who
    /// answered every picker question correctly, and still be taxed wrongly,
    /// because the fact Bailey needs is not on the classification at all.
    @Test("North Carolina ships no unclassified-pension disclosure sentence either")
    func northCarolinaShipsNoDisclosureSentence() {
        #expect(Self.northCarolinaExemptions.unclassifiedPensionDisclosure == nil,
                """
                North Carolina now ships an unclassifiedPensionDisclosure sentence with no \
                rule to go with it. Phase 5b Task 3b's lockstep sweep will fail on this. \
                The sentence would also be false for North Carolina: it tells a user their \
                exclusion is waiting on classification, and Bailey is not.
                """)
        #expect(UnclassifiedPensionDisclosure.text(for: .northCarolina, scope: .stateComparisonFigure) == nil)
        #expect(UnclassifiedPensionDisclosure.text(for: .northCarolina, scope: .cpaBriefingPlan) == nil)
    }

    // MARK: - What the declined rule would have wrongly matched

    /// The Step 3 question ("what would this wrongly match?"), answered as an
    /// assertion rather than as prose.
    ///
    /// Swept over `PlanSource.allCases`, so the answer stays complete when a
    /// later task adds a case. Unlike Hawaii's structure-only rule, this one is
    /// NOT true by construction: it names two sources and must decline the
    /// other eight. `otherStateOrLocal` is the load-bearing exclusion, because
    /// before Task 7's re-label the three Bailey rows carried that very label,
    /// and a rule written to make them pass would have handed a full North
    /// Carolina exclusion to a California public pension held by an NC resident.
    @Test("The declined rule matches exactly the two sources it names, and no others",
          arguments: PlanSource.allCases)
    func theDeclinedRuleMatchesOnlyWhatItNames(source: PlanSource) {
        let matched = Self.declinedRule.matches(structure: .definedBenefit, source: source)
        #expect(matched == Self.sourcesTheDeclinedRuleNames.contains(source),
                """
                \(source): the declined rule now matches \(matched), expected \
                \(Self.sourcesTheDeclinedRuleNames.contains(source)). If \
                PerSourceExemptionRule.matches changed its containment semantics, Task 7's \
                reasoning needs re-checking rather than this expectation being edited.
                """)
    }

    /// THE HEART OF THE DECISION, stated as the thing that is actually wrong
    /// with the declined rule.
    ///
    /// The rule's over-match is not out-of-state pensions, which it correctly
    /// declines above. It is that a NON-Bailey-vested North Carolina public
    /// retiree, hired after August 1984 and fully taxable, selects the SAME
    /// picker row and writes the SAME classification as the Bailey-vested one
    /// NC-1 pins. The rule cannot tell them apart because nothing can.
    ///
    /// This is the operational form of "the model has no vesting axis", and it
    /// is asserted here rather than by re-checking the classification's encoded
    /// key set, which `Phase5bHawaiiDecisionTests.theModelCarriesNoFundingAxis`
    /// already covers for the whole type.
    @Test("A non-Bailey North Carolina retiree writes the identical classification, so no rule can separate them")
    func theDeclinedRuleCannotBeNarrowedToTheBaileyClass() throws {
        // What a North Carolina public retiree selects, whether or not they are
        // Bailey-vested. There is exactly one row for them.
        let whatAnyNCPublicRetireeSelects =
            PlanClassificationChoice.ownStateGovernmentPension.classification

        #expect(Self.declinedRule.matches(
            structure: whatAnyNCPublicRetireeSelects.structure,
            source: whatAnyNCPublicRetireeSelects.source),
                """
                The declined rule no longer matches the row a North Carolina public retiree \
                selects. If the picker gained a Bailey-specific row, the Bailey class is now \
                expressible and Task 7's decision should be revisited against it.
                """)

        // And it is byte-identical to the classification NC-1 carries, which
        // is the fixture that expects $0.00. The same tuple therefore has two
        // correct answers depending on a fact the tuple does not carry.
        let file = try GoldenScenario.load(abbreviation: "NC")
        let nc1 = try #require(file.scenarios.first)
        let row = try #require(nc1.classifiedPensionSources?.first)
        #expect(row.planStructure == whatAnyNCPublicRetireeSelects.structure.rawValue)
        #expect(row.planSource == whatAnyNCPublicRetireeSelects.source.rawValue,
                """
                NC-1's classification and the picker row a North Carolina public retiree \
                would select have diverged. Task 7's re-label put them onto the same tuple \
                deliberately; if they no longer agree, the fixture no longer describes a \
                household a real user can enter.
                """)
        #expect(nc1.expectedStateTax == 0.0,
                """
                NC-1 no longer expects $0.00. Its whole role is to be the Bailey-vested \
                household whose inputs a non-vested household cannot be distinguished from.
                """)
    }

    // MARK: - Why no golden case could have caught it

    /// The blocker, proven from the fixture's own data rather than asserted,
    /// and the reason shipping a rule is foreclosed PROCEDURALLY rather than
    /// as a judgement call.
    ///
    /// Step 3 of the shared procedure says: "For each rule ask: what would this
    /// wrongly match? If the fixture set has no case that would catch that, ADD
    /// one." The case that would catch this over-match is a non-Bailey-vested
    /// North Carolina state pension. Its inputs are byte-identical to NC-1's,
    /// with a contradictory `expectedStateTax` of $1,486.27 against $0.00. A
    /// fixture can assert one or the other, never both. Step 3 is a requirement
    /// of the procedure, not a preference, and it cannot be satisfied.
    @Test("No North Carolina golden case can catch the vesting over-match, so Step 3 cannot be satisfied")
    func noNorthCarolinaGoldenCaseCouldCatchTheVestingOverMatch() throws {
        let file = try GoldenScenario.load(abbreviation: "NC")

        // The case that would catch it would be a household of North Carolina
        // OWN-state defined-benefit pensions expecting a POSITIVE tax. NC-1 and
        // NC-3 are exactly that household expecting $0.00. Both cannot exist.
        let ownStateDefinedBenefitCases = file.scenarios.filter { scenario in
            let rows = scenario.classifiedPensionSources ?? []
            return !rows.isEmpty && rows.allSatisfy {
                $0.planStructure == PlanStructure.definedBenefit.rawValue
                    && $0.planSource == PlanSource.ownStateOrLocal.rawValue
            }
        }
        #expect(!ownStateDefinedBenefitCases.isEmpty,
                "NC-1 and NC-3 are the ownStateOrLocal households this blocker is about; they are gone.")
        #expect(ownStateDefinedBenefitCases.allSatisfy { $0.expectedStateTax == 0.0 },
                """
                A North Carolina golden case now asserts a TAXABLE all-ownStateOrLocal \
                household alongside the exempt ones: \
                \(ownStateDefinedBenefitCases.map(\.name)). Those inputs are identical, so \
                either something can now distinguish Bailey vesting, in which case Task 7's \
                decision should be revisited against it, or a fixture is asserting a fact \
                its own inputs do not carry.
                """)

        // And every one of them still carries a knownDefect. A green suite must
        // not be readable as "North Carolina is fine".
        #expect(ownStateDefinedBenefitCases.allSatisfy { $0.knownDefect != nil },
                """
                A North Carolina Bailey case lost its knownDefect block without a rule \
                shipping. North Carolina still taxes these households in full.
                """)
    }

    /// The one guard case North Carolina CAN carry, and the test that stops it
    /// being deleted by whoever next writes a Bailey rule.
    ///
    /// It is the only vesting-INDEPENDENT guard available: another state's
    /// public pension is fully taxable in North Carolina at every vesting date,
    /// so no correct Bailey rule, present or future, can make it exempt, and
    /// its expected value asserts nothing its inputs do not carry. That is
    /// exactly what a guard for a NON-Bailey NORTH CAROLINA pension could not
    /// manage, per the test above.
    @Test("The out-of-state guard case exists, is taxable, and carries no knownDefect")
    func theOutOfStateGuardCaseStaysInTheFixture() throws {
        let file = try GoldenScenario.load(abbreviation: "NC")
        let guards = file.scenarios.filter { scenario in
            (scenario.classifiedPensionSources ?? []).contains {
                $0.planSource == PlanSource.otherStateOrLocal.rawValue
            }
        }
        #expect(!guards.isEmpty,
                """
                North Carolina's out-of-state guard case is gone. It is what fails if a \
                future North Carolina rule names `otherStateOrLocal`, which would exempt \
                another state's public pension held by an NC resident: the Kansas/KPERS \
                trap. Before Task 7's re-label all three Bailey rows carried that label, so \
                this is the trap a rule-writer walks into by default. Restore it.
                """)
        // Asserted over EVERY otherStateOrLocal case, not just the first. A
        // `guards.first` check would let a second, weaker out-of-state case
        // added later shadow this one and silently stop guarding anything.
        for outOfState in guards {
            #expect(outOfState.expectedStateTax > 0,
                    """
                    \(outOfState.name): an out-of-state public pension expects \
                    \(outOfState.expectedStateTax). North Carolina taxes it in full at every \
                    vesting date, so a zero here means a rule has started exempting another \
                    state's pension.
                    """)
            #expect(outOfState.knownDefect == nil,
                    """
                    \(outOfState.name) gained a knownDefect. The engine is CORRECT on the \
                    out-of-state case today and must stay correct; a defect block here would \
                    mean North Carolina had started exempting an out-of-state pension.
                    """)
        }
    }

    // MARK: - The decision stays inert, and stays recorded

    /// "Provably inert" for a task that ships no rule means the classification
    /// a user records has no effect on their North Carolina tax, and that the
    /// income-breakdown mirror agrees with the tax computation for every one of
    /// them. Swept over `PlanSource.allCases`, because
    /// `DataManager.stateTaxBreakdown` hand-duplicates the engine's per-source
    /// partition and has drifted from it five times on this branch.
    ///
    /// This is also what proves the RE-LABEL was value-neutral: NC-1's row
    /// moved from `otherStateOrLocal` to `ownStateOrLocal`, and both appear in
    /// this sweep at the same figure.
    @MainActor
    @Test("Classification changes nothing for a North Carolina resident, and the breakdown mirror agrees",
          arguments: PlanSource.allCases)
    func northCarolinaIsUnaffectedByClassification(source: PlanSource) {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 70; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .northCarolina
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: source)
        ]

        let breakdown = dm.stateTaxBreakdown(forState: .northCarolina, filingStatus: .single)
        let computed = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .northCarolina, filingStatus: .single,
            taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)

        #expect(abs(breakdown.totalStateTax - computed) < 0.01,
                """
                NC / \(source): the income-breakdown display reports \
                \(breakdown.totalStateTax) while the tax computation reports \(computed). \
                DataManager's per-source partition has drifted from \
                TaxCalculationEngine.applyRetirementExemptions.
                """)
        #expect(abs(breakdown.pensionExemptAmount) < 0.01,
                """
                NC / \(source): the breakdown attributes \(breakdown.pensionExemptAmount) of \
                pension exclusion. North Carolina ships no rule, so every source must \
                attribute zero. This is the assertion that catches a Bailey rule arriving \
                through the mirror rather than through the config.
                """)
        #expect(abs(computed - Self.unexcludedNC1Tax) < 0.01,
                """
                NC / \(source): expected the unexcluded \(Self.unexcludedNC1Tax), got \
                \(computed). Every classification must reach the same figure, which is what \
                makes this task inert and what made the re-label value-neutral.
                """)
    }

    /// The record that outlives this file's reasoning, in the same shape as
    /// Task 4's `theContributoryGapStaysRecorded` and Task 5's
    /// `theEmployerFundedPortionGapStaysRecorded`. This test fails if the entry
    /// is deleted, so a future green suite cannot mean "North Carolina is fine".
    @Test("North Carolina's Bailey gap stays recorded as a known-but-unpinned defect")
    func theBaileyGapStaysRecorded() throws {
        // Selected by SUMMARY, not merely by state: North Carolina now carries
        // TWO unpinned entries (Bailey, and the military type-versus-source
        // divergence below), so a `first { $0.state == "NC" }` lookup would pass
        // on the wrong one if this one were deleted.
        let entry = try #require(
            GoldenScenarioDefectCatalogueTests.knownButUnpinned.first {
                $0.state == "NC" && $0.summary.contains("BAILEY")
            },
            """
            North Carolina's Bailey gap is no longer recorded. Either a vesting axis was \
            actually added, in which case this test should be replaced by golden cases for \
            the vested and non-vested households, or a real, cited over-taxation was \
            silently dropped from the catalogue.
            """)
        #expect(entry.blockedOn.contains("NOT EXPRESSIBLE AS A GOLDEN CASE"))
        #expect(entry.summary.contains("disclosed NOWHERE"),
                """
                The NC entry no longer records that North Carolina's over-taxation is \
                undisclosed on the CPA briefing. The Income Sources caption shipped in Task \
                7, but the briefing still carries no North Carolina line, so this is still \
                only partly closed.
                """)
    }

    /// The type-versus-source divergence found by this task's own mirror sweep,
    /// kept as a durable record with its own deletion guard.
    ///
    /// North Carolina already answers military retired pay:
    /// `MilitaryRetirementExemption.stateTaxableAmount` returns `.fullyExempt`
    /// for "NC". But that path gates on `IncomeSource.type == .militaryRetirement`,
    /// while Task 3's "Military retired pay" picker row writes
    /// `(definedBenefit, uniformedServices)` onto a `.pension` row, which North
    /// Carolina taxes in full because it ships no per-source rule. Same money,
    /// two screens, opposite answers.
    ///
    /// This test MEASURES both paths rather than restating the entry, so it
    /// fails the day either one moves, including the day someone ships the
    /// `uniformedServices` rule that would close it.
    @MainActor
    @Test("North Carolina's two military paths still disagree, and the divergence stays recorded")
    func theMilitaryTypeVersusSourceDivergenceStaysRecorded() throws {
        // Path 1: by income TYPE. The shipped North Carolina answer.
        #expect(MilitaryRetirementExemption.stateTaxableAmount(
            gross: 50_000, stateCode: "NC", age: 70) == 0,
                """
                North Carolina no longer fully exempts military retired pay by income type. \
                If that changed deliberately, this whole entry and the NC catalogue record \
                need revisiting together.
                """)

        // Path 2: by CLASSIFICATION. Taxed in full, because NC ships no rule.
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 70; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .northCarolina
        dm.incomeSources = [
            IncomeSource(name: "Military pension", type: .pension, annualAmount: 50_000,
                         owner: .primary, planStructure: .definedBenefit,
                         planSource: .uniformedServices)
        ]
        let classified = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .northCarolina,
            filingStatus: .single, taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)

        #expect(abs(classified - Self.unexcludedNC1Tax) < 0.01,
                """
                The classified military path now reports \(classified) rather than \
                \(Self.unexcludedNC1Tax). If a North Carolina `uniformedServices` rule \
                shipped, the two paths have CONVERGED, which is the fix: delete the NC \
                military entry from knownButUnpinned, delete this test, and narrow \
                northCarolinaIsUnaffectedByClassification to exclude uniformedServices in \
                the same change.
                """)

        let military = try #require(
            GoldenScenarioDefectCatalogueTests.knownButUnpinned.first {
                $0.state == "NC" && $0.summary.contains("TWO PATHS")
            },
            """
            North Carolina's military type-versus-source divergence is no longer recorded. \
            The two paths above still disagree, so this is a real, measured, reachable \
            over-taxation that was silently dropped from the catalogue.
            """)
        #expect(military.blockedOn.contains("NOT A GOLDEN-CASE DEFECT"))
    }

    // MARK: - The disclosure that ships with this decision

    /// The Income Sources caption, APPROVED by John on 2026-08-05 as written.
    ///
    /// North Carolina was the only jurisdiction this phase touched with ZERO
    /// disclosure on any surface. Task 4 shipped the Massachusetts caption three
    /// lines above this one, in this same phase, and its comment block records
    /// that it "is the only surface that reaches the affected user". The same
    /// applies here, with the direction reversed: Massachusetts's error runs
    /// toward UNDER-taxation, North Carolina's toward OVER-taxation.
    ///
    /// The DIRECTION word is the load-bearing part, exactly as in Hawaii's
    /// caption. North Carolina applies no Bailey exclusion at all, so every
    /// error runs toward over-taxation and "understated" would be false.
    @MainActor
    @Test("North Carolina's Income Sources caption ships and names the right direction")
    func northCarolinaCaptionNamesTheRightDirection() {
        let text = IncomeSourcesView.northCarolinaBaileyCaption
        #expect(text.contains("Bailey"))
        #expect(text.contains("overstated"),
                """
                North Carolina's caption no longer says the tax may be OVERSTATED. North \
                Carolina applies no Bailey exclusion, so every error runs toward \
                over-taxation; understated would be false. A copy edit that harmonised this \
                with the Massachusetts caption directly above it would invert one of them.
                """)
        #expect(!text.contains("understated"))
        #expect(!text.contains("—") && !text.contains("–"), "no em or en dash in user-facing copy")
    }

    // MARK: - Picker reachability, and what a North Carolina user is actually asked

    /// Task 3 added picker rows so a correct rule would be REACHABLE by a real
    /// user rather than only by a golden fixture. For North Carolina the row
    /// the re-label depends on is reachable, which is what makes the re-label
    /// describe a household a user can actually enter.
    ///
    /// `residenceNamesItsOwnJurisdiction(.northCarolina)` is false, because
    /// North Carolina's config names no jurisdiction-named source (it ships no
    /// rules at all), so the generic own-state row survives. If a Bailey rule
    /// is ever written, this is the row it has to match.
    @Test("A North Carolina user can reach both the own-state and the out-of-state rows")
    func northCarolinaUserCanReachTheRowsTheDecisionTurnsOn() {
        #expect(!PlanClassificationChoice.residenceNamesItsOwnJurisdiction(.northCarolina),
                """
                North Carolina's config now names its own jurisdiction, which suppresses \
                the generic own-state row for North Carolina residents. A North Carolina \
                public retiree would then have no way to describe their own pension.
                """)
        let options = PlanClassificationChoice.options(for: .northCarolina, selected: nil)
        #expect(options.contains(.ownStateGovernmentPension),
                """
                The own-state row is no longer offered to a North Carolina resident. Task \
                7's re-label put NC-1, NC-3 and NC-4 onto that classification precisely \
                because a real user can select it.
                """)
        #expect(options.contains(.otherStateGovernmentPension),
                "The out-of-state row backs the guard case; a user must be able to select it.")
    }

}
