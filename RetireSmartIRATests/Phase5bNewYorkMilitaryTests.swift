//
//  Phase5bNewYorkMilitaryTests.swift
//  RetireSmartIRATests
//
//  Phase 5b WHOLE-BRANCH REVIEW, CRITICAL 1.
//
//  New York is the canary jurisdiction of this whole program: the only state
//  that shipped `perSourceExemptions` before Phase 5b, and the one every task
//  checked itself against. This file exists because the branch nevertheless
//  broke it, in the one direction the phase spent ten tasks avoiding.
//
//  WHAT WENT WRONG, and it is a good illustration of why "the suite is green"
//  is not evidence. Task 3 added three picker rows to `PlanClassificationChoice`
//  for EVERY jurisdiction, among them "Military retired pay", which writes
//  `(definedBenefit, uniformedServices)`. New York's rule named only
//  `nyStateOrLocal` and `federalCivilian`, because when it was written the model
//  had no separate case for uniformed services at all. So:
//
//    BEFORE the branch: a New York military retiree's best available pick was
//    "Government pension, federal civilian". The rule matched it. The uncapped
//    Line 26 exclusion applied. The answer was RIGHT, by accident.
//
//    AFTER Task 3: the honest pick writes `uniformedServices`,
//    `matchedPerSourceRule` returns nil, the row pools into `pensionIncome`, and
//    New York's CAPPED $20,000 Line 29 exclusion applies instead. Two taps away,
//    on the one jurisdiction that has been prompting users to classify at all.
//
//  WHAT IT COSTS depends on the household's other income, so this file pins it
//  at TWO shapes rather than quoting one round number. A single filer at 65
//  whose ONLY income is a $60,000 military pension paid $1,563.00 and now pays
//  $0.00. At NY-5's shape, $70,000 of pension plus $20,000 of other ordinary
//  income, it is $3,183.00 against $487.75, a delta of $2,695.25, because the
//  $40,000 the cap fails to exclude sits wholly in the 5.4% band there rather
//  than partly below it. Both are asserted in
//  `militaryRetiredPayIsUncappedInNewYork` below. An earlier draft of this file
//  said "roughly $2,200 a year on a $60,000 pension", which reproduces from
//  NEITHER shape; it was narrative imprecision in derivation-grade
//  surroundings, and it is recorded here rather than quietly deleted.
//
//  Every New York golden case stayed green throughout, because none of them
//  carried a `uniformedServices` row. Task 3's own doc comment worked out this
//  exact hazard for `ownStateGovernmentPension` and suppressed that row for New
//  York residents; the same reasoning was never applied to the two rows added
//  beside it.
//
//  THE FIX CHOSEN, and the one rejected. Two were available. (a) Widen New
//  York's rule to name `uniformedServices`. (b) Suppress the new picker rows for
//  New York residents, restoring the accident. (a) was chosen and (b) rejected:
//
//    - (a) is correct law by the authority New York's OWN fixture already
//      quotes, so it needs no research Step 1 forbids. Line 26 eligibility runs
//      to "an officer, employee, or beneficiary of an officer or employee of"
//      NYS, a NY locality, named NY authorities, "or the United States", and a
//      retired member of the uniformed services is an officer or employee of the
//      United States drawing a federal government pension.
//    - (a) also closes the type-versus-source divergence the ledger records as
//      its own inheritance item: `MilitaryRetirementExemption.exemption(for:
//      "NY")` already returns `.fullyExempt`, so before this change the answer
//      depended on which screen the money was entered from. That is the FIFTH
//      instance of that class found on this branch and the first that a
//      jurisdiction's own fixture had the authority to close.
//    - (b) would have required a New-York-specific hardcode in the very file
//      Task 3b spent a whole task de-special-casing, and it leaves the affected
//      user with no honest row: they would have to describe military retired pay
//      as a federal civilian pension. That is false on its face and it is a
//      landmine in five other states, because Kansas, Massachusetts, Arizona,
//      Idaho and Vermont all treat the two differently. (b) trades one New York
//      defect for a wrong answer everywhere else.
//
//  LAYER B. New York is NOT on `phase5CorrectedJurisdictions`, so
//  `StateTaxJSONStructuralEquivalenceTests.structurallyIdentical` requires its
//  bundled JSON and its `configs2026Legacy` entry to re-encode BYTE-IDENTICALLY
//  in every COMPUTED field. Task 3b hit this and its precedent is to MIRROR the
//  change into the legacy table rather than to add New York to the list,
//  because membership FLIPS that assertion into "must diverge" and permanently
//  excuses the canary from the byte-identity check. This change follows that
//  precedent, and the mirror matters more here than it did for a disclosure
//  string: a user who hits the JSON-load-failure fallback would otherwise be
//  over-taxed, not merely unwarned.
//
//  UPDATED 2026-08-06. New York is now on the accuracy-disclosure branch's
//  `disclosureOnlyDivergentJurisdictions`, so it is no longer on NEITHER list
//  and the two documents are no longer required to be byte-identical outright.
//  That set excuses `verification` ALONE and nothing else: everything outside
//  it, this rule included, is still held to byte-identity, so the mirror below
//  is still required and the argument above still holds. What changed is only
//  the premise, not the conclusion.
//
//  RAILROAD RETIREMENT IS A SEPARATE QUESTION AND IS DELIBERATELY NOT SHIPPED.
//  Task 3 added that picker row too, and it has the same shape of consequence,
//  but New York's fixture cites no provision covering Railroad Retirement Board
//  benefits and the quoted Line 26 list argues AGAINST folding them in: a
//  railroad retiree was an employee of a private carrier, not of the United
//  States. Recorded in `GoldenScenarioDefectCatalogueTests.knownButUnpinned`
//  with the deletion guard at the bottom of this file, following the Arizona and
//  Massachusetts railroad precedents.
//
//  NO BASELINE MOVEMENT. `StateTaxBehaviorBaselineTests.computedTax` builds its
//  pension rows with no classification, so they infer `(unknown, unknown)`, and
//  widening `matchSources` cannot match `.unknown`. Measured, not reasoned: the
//  frozen 1,020-value baseline and the movement ledger are both untouched by
//  this change, and the full suite is the proof.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 5b whole-branch review: New York's Line 26 exclusion reaches military retired pay")
struct Phase5bNewYorkMilitaryTests {

    static var newYorkExemptions: RetirementIncomeExemptions {
        StateTaxData.config(for: .newYork).retirementExemptions
    }

    /// The three sources IT-201 Line 26 reaches, as this app encodes them.
    /// `nyStateOrLocal` is New York State, its localities and the named NY
    /// public authorities; `federalCivilian` and `uniformedServices` are the two
    /// halves of "the United States" that Task 1 split apart.
    static let sourcesLine26Names: Set<PlanSource> =
        [.nyStateOrLocal, .federalCivilian, .uniformedServices]

    // MARK: - The shipped rule

    @Test("New York ships exactly one per-source rule and it names all three Line 26 sources")
    func newYorkShipsTheWidenedRule() throws {
        let rules = Self.newYorkExemptions.perSourceExemptions
        #expect(rules.count == 1, "New York ships \(rules.count) per-source rules, expected exactly 1.")
        let rule = try #require(rules.first)
        #expect(Set(rule.matchSources) == Self.sourcesLine26Names,
                """
                New York's rule names \(rule.matchSources). Dropping `uniformedServices` \
                re-opens the defect this file documents: the "Military retired pay" picker \
                row falls through to the CAPPED $20,000 Line 29 exclusion, costing $1,563.00 \
                a year on a $60,000-only household and $2,695.25 at NY-5's shape. Adding \
                anything else needs an authority the New York fixture actually carries.
                """)
        #expect(rule.matchStructures == [.definedBenefit],
                """
                Line 26 explicitly does NOT cover salary-reduction or deferred-compensation \
                plans even from a qualifying employer, which is what NY-3 pins.
                """)
        if case .full = rule.treatment {} else {
            Issue.record("""
                New York's Line 26 exclusion is UNCAPPED, and a capped per-source treatment \
                is banned phase-wide besides: `treatment` is evaluated inside the engine's \
                per-row loop, so a `.partial` would cap PER PENSION ROW. The $20,000 cap \
                belongs where it already is, on the pooled `pensionExemption`.
                """)
        }
    }

    /// LAYER B, restated where the change is, rather than trusted to fire
    /// somewhere else. `structurallyIdentical` sweeps all 51 jurisdictions and
    /// would catch a missed mirror, but its failure message names a line number
    /// in a re-encoded document; this one names the reason.
    @Test("The bundled JSON and the frozen legacy table still agree on New York, byte for byte")
    func theLegacyMirrorWasUpdatedToo() throws {
        let jsonRule = try #require(
            StateTaxDataLoader.load(taxYear: 2026)[.newYork]?
                .retirementExemptions.perSourceExemptions.first)
        let legacyRule = try #require(
            StateTaxData.configs2026Legacy[.newYork]?
                .retirementExemptions.perSourceExemptions.first)

        #expect(Set(jsonRule.matchSources) == Set(legacyRule.matchSources),
                """
                statetax-2026-NY.json and StateTaxData.configs2026Legacy's New York entry \
                now disagree on matchSources. New York is NOT on \
                phase5CorrectedJurisdictions, so Layer B requires them to re-encode \
                byte-identically in every computed field; being on \
                disclosureOnlyDivergentJurisdictions since 2026-08-06 excuses `verification` \
                alone and not this rule. Task 3b's precedent is to MIRROR a New York change \
                into the legacy table rather than to add New York to \
                phase5CorrectedJurisdictions, because membership there flips \
                structurallyIdentical into a must-diverge assertion and permanently excuses \
                the canary from the check.
                """)
        #expect(Set(legacyRule.matchSources) == Self.sourcesLine26Names)
    }

    // MARK: - What the rule matches, swept

    @Test("The widened rule matches exactly the three sources it names, and no others",
          arguments: PlanSource.allCases)
    func theRuleMatchesOnlyWhatItNames(source: PlanSource) {
        let matched = Self.newYorkExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: source) != nil
        #expect(matched == Self.sourcesLine26Names.contains(source),
                """
                \(source): New York's rule now matches \(matched), expected \
                \(Self.sourcesLine26Names.contains(source)). `otherStateOrLocal` is the \
                load-bearing exclusion (NY-4 pins it end to end): Line 26's eligibility \
                list is CLOSED, and a rule reaching another state's public pension is the \
                exact defect the source dimension was invented to prevent.
                """)
    }

    // MARK: - End to end, and the figure the defect was worth

    /// Drives the engine the same way `GoldenScenarioSingleYearTests` does, at
    /// NY-5's shape: single filer aged 65, $70,000 pension, $20,000 of other
    /// ordinary income, New York's $8,000 single standard deduction.
    static func newYorkTaxOnOnePension(source: PlanSource,
                                       pension: Double = 70_000,
                                       other: Double = 20_000) -> Double {
        let sources = [IncomeSource(name: "Pension", type: .pension, annualAmount: pension,
                                    planStructure: .definedBenefit, planSource: source)]
        let deduction = 8_000.0
        return TaxCalculationEngine.calculateStateTax(
            income: max(0, pension + other - deduction),
            forState: .newYork,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            incomeSources: sources,
            currentAge: 65,
            enableSpouse: false,
            spouseBirthYear: 2026 - 65,
            currentYear: 2026,
            scenarioRetirementDistributions: 0,
            scenarioRothConversionAmount: 0,
            scenarioRothConversionWithholdingAmount: 0,
            postExemptionDeduction: 0,
            localIncomeTaxRate: 0)
    }

    /// THE COST, pinned as two numbers rather than described.
    ///
    /// $487.75 is NY-1's own hand-derived figure, reached by the identical
    /// arithmetic: $12,000 of taxable income after the Line 26 subtraction and
    /// the $8,000 standard deduction, taxed at 3.9% / 4.4% / 5.15%. $3,183.00 is
    /// what the same household paid with the pre-widening rule, when only the
    /// capped $20,000 Line 29 exclusion applied. The difference, $2,695.25 a
    /// year, is what this change is worth at NY-5's shape.
    @Test("A New York military retiree reaches the uncapped exclusion, not the $20,000 cap")
    func militaryRetiredPayIsUncappedInNewYork() {
        let military = Self.newYorkTaxOnOnePension(source: .uniformedServices)
        #expect(abs(military - 487.75) < 0.01,
                """
                A $70,000 military pension produced \(military) of New York tax, expected \
                $487.75. $3,183.00 is the pre-widening figure and means the rule no longer \
                names `uniformedServices`; the pension fell through to the capped $20,000 \
                Line 29 exclusion.
                """)

        // The same money entered as a federal civilian pension, which is what
        // this user's only honest option produced BEFORE Task 3 added the
        // military row. Equal answers is the point: the picker gained a truer
        // label without changing the tax.
        #expect(abs(Self.newYorkTaxOnOnePension(source: .federalCivilian) - 487.75) < 0.01)

        // And the guard, at the same shape: another state's public pension still
        // gets only the capped exclusion.
        let outOfState = Self.newYorkTaxOnOnePension(source: .otherStateOrLocal)
        #expect(abs(outOfState - 3_183.00) < 0.01,
                """
                An out-of-state public pension produced \(outOfState), expected the capped \
                $3,183.00. $487.75 means the rule was widened onto `otherStateOrLocal`, \
                which Line 26's closed eligibility list does not reach.
                """)

        // THE SECOND SHAPE, pinned because the cost is not one number and an
        // earlier draft of this file quoted one that reproduced from neither.
        // A single filer at 65 whose ONLY income is a $60,000 military pension:
        // $60,000 less the capped $20,000 less the $8,000 standard deduction
        // leaves $32,000 taxable, which walks to $331.50 + $140.80 + $113.30
        // plus $18,100 at 5.4% = $977.40, i.e. $1,563.00. Hand-derived from the
        // bracket schedule, not read off the engine.
        let sixtyOnlyCapped = Self.newYorkTaxOnOnePension(
            source: .otherStateOrLocal, pension: 60_000, other: 0)
        #expect(abs(sixtyOnlyCapped - 1_563.00) < 0.01,
                """
                The capped path on a $60,000-only household produced \(sixtyOnlyCapped), \
                expected $1,563.00. This is the figure the pre-widening defect actually \
                cost that household, and it is pinned so the narrative in this file, in \
                NY-5's source string and in statetax data's comment cannot drift from \
                arithmetic that reproduces.
                """)
        let sixtyOnlyMilitary = Self.newYorkTaxOnOnePension(
            source: .uniformedServices, pension: 60_000, other: 0)
        #expect(sixtyOnlyMilitary == 0.0,
                """
                A $60,000 military pension as a household's only income produced \
                \(sixtyOnlyMilitary), expected $0.00: the Line 26 subtraction exceeds the \
                income, so New York taxable income floors at zero.
                """)
    }

    /// THE TWO-ENCODINGS DIVERGENCE, closed for New York and asserted as closed.
    ///
    /// The ledger records `IncomeType.militaryRetirement` and
    /// `PlanSource.uniformedServices` as two encodings of one fact whose answers
    /// can disagree, and North Carolina's pair is still open by decision. New
    /// York's is the one this branch had the authority to close, because New
    /// York's own fixture quotes the sentence that puts military retired pay
    /// inside Line 26. Arizona's closed the same way in Task 6.
    @Test("New York's two encodings of military retired pay now agree")
    func bothMilitaryRoutesAgreeForNewYork() {
        #expect(MilitaryRetirementExemption.exemption(for: "NY", age: 65) == .fullyExempt,
                """
                The income-type table no longer says New York fully exempts military \
                retired pay. If that is a correction, the per-source rule must lose \
                `uniformedServices` in the same change and NY-5 must be re-derived; the \
                two encodings disagreeing is the defect, whichever way they disagree.
                """)
        #expect(Self.newYorkExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: .uniformedServices) != nil,
                """
                The classification route no longer exempts military retired pay in New \
                York while the income-type route still does, so the answer depends on which \
                screen the money was entered from. That is exactly the divergence this \
                change closed.
                """)
    }

    // MARK: - Reachability, which is what Task 3 proved the fixtures cannot show

    @Test("A New York resident is offered the military row, and it writes what the rule matches")
    func theMilitaryRowIsReachableForANewYorkResident() {
        let options = PlanClassificationChoice.options(for: .newYork, selected: nil)
        #expect(options.contains(.uniformedServicesPension),
                """
                The military row is suppressed for New York residents. That was the \
                REJECTED option (b): it restores the right number by making the user \
                describe military retired pay as a federal civilian pension, and it is \
                wrong in the five states that treat the two differently.
                """)

        // The own-state row IS still suppressed, which is the mitigation Task 3
        // shipped and which this change does not touch: for a New York resident
        // `ownStateGovernmentPension` and `nyGovernmentPension` describe the same
        // pension and only the latter selects Line 26.
        #expect(!options.contains(.ownStateGovernmentPension),
                "Task 3's New York suppression was dropped; the own-state row is a trap here")

        let written = PlanClassificationChoice.uniformedServicesPension.classification
        #expect(Self.newYorkExemptions.matchedPerSourceRule(
            structure: written.structure, source: written.source) != nil,
                """
                The picker row writes \(written.structure)/\(written.source), which New \
                York's rule does not match. The rule is unreachable through the app, which \
                is the failure Task 3 was created to fix.
                """)
    }

    // MARK: - The DataManager breakdown mirror

    /// The mirror check every rule change on this branch owes.
    ///
    /// `DataManager.stateTaxBreakdown` hand-duplicates the engine's per-source
    /// partition rather than calling into it, and that duplication has drifted
    /// from the engine five separate times on this branch. Nothing in the golden
    /// fixture set touches it: the golden runner drives
    /// `TaxCalculationEngine.calculateStateTax` directly and never builds a
    /// breakdown. Swept over `PlanSource.allCases` so a case added later is
    /// checked the moment it exists.
    @MainActor
    @Test("The income-breakdown mirror agrees with the tax computation for every New York source",
          arguments: PlanSource.allCases)
    func breakdownMirrorAgreesWithTheEngineForNewYork(source: PlanSource) {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 65; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .newYork
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 70_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: source)
        ]

        let breakdown = dm.stateTaxBreakdown(forState: .newYork, filingStatus: .single)
        let computed = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .newYork, filingStatus: .single,
            taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)

        #expect(abs(breakdown.totalStateTax - computed) < 0.01,
                """
                New York / \(source): the income-breakdown display reports \
                \(breakdown.totalStateTax) while the tax computation reports \(computed). \
                DataManager's per-source partition has drifted from \
                TaxCalculationEngine.applyRetirementExemptions.
                """)

        let isLine26Source = Self.sourcesLine26Names.contains(source)
        let expectedExempt = isLine26Source ? 70_000.0 : 20_000.0
        #expect(abs(breakdown.pensionExemptAmount - expectedExempt) < 0.01,
                """
                New York / \(source): breakdown attributes \(breakdown.pensionExemptAmount) \
                of pension exclusion, expected \(expectedExempt). A Line 26 source is \
                excluded in full; everything else draws the capped $20,000 Line 29 \
                exclusion. The total can be right while the displayed attribution is wrong, \
                and a user reads both.
                """)
    }

    // MARK: - The unpinned defect this change ships with

    /// Railroad Retirement's deletion guard.
    ///
    /// Task 3 added the "Railroad Retirement benefits" row to every
    /// jurisdiction, so a New York railroad retiree now has an honest pick that
    /// New York's rule does not name, and it draws the capped $20,000 exclusion
    /// where the nearest pre-branch pick drew the uncapped one. Whether the
    /// capped answer is right is not derivable from New York's fixture, which
    /// cites no provision covering these benefits, and Step 1 forbids
    /// re-researching the law. Recorded rather than guessed, following Task 6's
    /// Arizona precedent and Task 4's Massachusetts one.
    ///
    /// NON-VACUOUS: it re-derives both legs from live code, so the entry cannot
    /// outlive the defect either.
    @Test("New York's Railroad Retirement question stays recorded as a known-but-unpinned defect")
    func theRailroadRetirementQuestionStaysRecorded() throws {
        let entry = try #require(
            // Selected on CONTENT, not on `state == "NY"` alone. New York has
            // one entry today, so a bare state match is correct right now and
            // becomes wrong the moment a second lands, which this entry's own
            // text invites by naming a future New York golden case as the
            // resolution. Same hazard the Massachusetts pair documents and the
            // District's two now avoid.
            GoldenScenarioDefectCatalogueTests.knownButUnpinned.first {
                $0.state == "NY" && $0.summary.contains("RAILROAD RETIREMENT benefits is unresolved")
            },
            """
            New York's Railroad Retirement gap is no longer recorded. If a New York golden
            case derived from New York's own published treatment was added and the rule
            widened onto `railroadRetirement`, delete this test in the SAME change and name
            that case. If not, a live classification a real user can select was dropped from
            the catalogue.
            """)
        #expect(entry.blockedOn.contains("NO AUTHORITY IN THE FIXTURE"))

        // Leg 1: the rule still does not name it, so the capped answer is what
        // ships.
        #expect(Self.newYorkExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: .railroadRetirement) == nil,
                """
                New York's rule now matches `railroadRetirement`. That may well be right \
                under 45 U.S.C. 231m, but it is not derivable from anything New York's \
                fixture cites, and it must arrive with a reviewed golden case. Delete this \
                test and the entry in that same change.
                """)

        // Leg 2: it is picker-reachable, which is what makes this a live gap
        // rather than an unused enum case.
        #expect(PlanClassificationChoice.options(for: .newYork, selected: nil)
            .contains(.railroadRetirementPension),
                "the railroad row is no longer offered to a New York resident")
    }
}
