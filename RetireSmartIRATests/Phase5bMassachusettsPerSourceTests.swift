//
//  Phase5bMassachusettsPerSourceTests.swift
//  RetireSmartIRATests
//
//  Phase 5b Task 4: the SECOND state rule written against the vocabulary Task
//  1 added, and the first task to reuse Task 3's picker rather than build it.
//  The shipped rule in
//  RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-MA.json names two
//  sources -- ownStateOrLocal (a Commonwealth of Massachusetts or Massachusetts
//  municipal contributory system) and uniformedServices (U.S. military retired
//  pay) -- and constrains them to definedBenefit.
//
//  WHAT THE GOLDEN FIXTURE ALREADY COVERS, so this file does not repeat it:
//  statetax-2026-MA.golden.json pins the end-to-end tax for ownStateOrLocal
//  (MA-1 single, MA-3 both spouses), the mixed military/private household
//  (MA-4) and governmentUnspecified (MA-2). Those are the authority-derived
//  numbers and they are the specification.
//
//  WHAT THIS FILE ADDS, which no MA fixture reaches:
//    1. The NEGATIVE half of the rule, swept over PlanSource.allCases. The
//       fixture has one guard case (MA-2, governmentUnspecified). It has no
//       out-of-state guard and no migration-default guard, and neither could
//       be written as a golden case: see `outOfStateIsNotMatched` for why an
//       out-of-state dollar assertion would assert unverified reciprocity law.
//    2. The STRUCTURE half of the rule. Every classified MA fixture row that
//       the rule matches is definedBenefit, so `matchStructures` could be
//       deleted outright and every golden case would stay green.
//    3. PICKER REACHABILITY. Task 3's three new rows exist so a correct rule
//       is reachable by a real user rather than only by a fixture.
//       Massachusetts is their first real reuse and must not be suppressed.
//    4. The DataManager income-breakdown MIRROR, which hand-duplicates the
//       engine's per-source partition and has drifted from it repeatedly. No
//       fixture drives that path: the golden runner calls
//       TaxCalculationEngine directly.
//    5. The CONTRIBUTORY GAP, pinned as a record rather than as a tax. See
//       `theContributoryGapStaysRecorded`.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 5b Task 4: the shipped Massachusetts per-source rule matches exactly what mass.gov names")
struct Phase5bMassachusettsPerSourceTests {

    /// The REAL shipped Massachusetts config, never a test-shaped stand-in.
    static var massachusettsExemptions: RetirementIncomeExemptions {
        StateTaxData.config(for: .massachusetts).retirementExemptions
    }

    // MARK: - The rule exists at all, and is the only one

    @Test("Massachusetts ships exactly one per-source rule, treated as a full exclusion")
    func massachusettsShipsOneFullExclusionRule() throws {
        let rules = Self.massachusettsExemptions.perSourceExemptions
        #expect(rules.count == 1, "expected exactly one Massachusetts rule, found \(rules.count)")
        let rule = try #require(rules.first)
        #expect(rule.treatment.matchesShape(of: .full),
                """
                mass.gov states the Massachusetts contributory exclusion and the U.S. \
                military exclusion outright, with no dollar cap and no age gate. A \
                partial or capped treatment here would be a different rule than the one \
                the fixture's arithmetic was derived from.
                """)
    }

    // MARK: - What the rule MUST match

    /// The two categories the shipped rule implements, and the ONE
    /// hand-written list in this file. Everything below is derived from it, so
    /// a `PlanSource` case added by a later Phase 5b task cannot slip past the
    /// negative sweep: it lands in `sourcesMassachusettsDoesNotName`
    /// automatically and is asserted against on the next run.
    static let sourcesMassachusettsNames: [PlanSource] = [
        .ownStateOrLocal, .uniformedServices
    ]

    /// DERIVED, never listed. Every `PlanSource` the Massachusetts rule must
    /// reject.
    static let sourcesMassachusettsDoesNotName: [PlanSource] =
        PlanSource.allCases.filter { !sourcesMassachusettsNames.contains($0) }

    /// DERIVED, never listed.
    static let structuresOtherThanDefinedBenefit: [PlanStructure] =
        PlanStructure.allCases.filter { $0 != .definedBenefit }

    @Test("Every source the Massachusetts rule names is matched, as a defined-benefit pension",
          arguments: Phase5bMassachusettsPerSourceTests.sourcesMassachusettsNames)
    func namedSourcesAreMatched(source: PlanSource) {
        #expect(Self.massachusettsExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: source) != nil,
                "\(source) is on the shipped Massachusetts rule and must be excluded")
    }

    // MARK: - What the rule MUST NOT match

    /// The negative half, which is the half this phase exists to protect.
    ///
    ///   - `otherStateOrLocal`: a DIFFERENT state's system. Massachusetts has
    ///     no golden guard case for it (see `outOfStateIsNotMatched` below for
    ///     why one could not be written), so this sweep is the ONLY thing
    ///     standing between a widened rule and a California public pension
    ///     taking a Massachusetts exclusion.
    ///   - `governmentUnspecified`: jurisdiction never established. Golden
    ///     case MA-2, and `PlanSource.governmentUnspecified`'s own doc comment
    ///     forbids any rule treating it as a specific jurisdiction.
    ///   - `federalCivilian`: CSRS/FERS. mass.gov treats federal civilian
    ///     pensions under a separate heading from the U.S. military exclusion,
    ///     and no Massachusetts golden case pins a federal-civilian figure, so
    ///     naming it here would be writing a rule from unpinned law. The
    ///     resulting under-match (Massachusetts arguably does exclude federal
    ///     CONTRIBUTORY pensions) errs toward over-taxation and is disclosed
    ///     in the Task 4 report rather than guessed at.
    ///   - `railroadRetirement`: on mass.gov's enumerated exempt list but
    ///     pinned by no Massachusetts golden case, for the same reason.
    ///   - `nyStateOrLocal`: New York's jurisdiction-named case. A
    ///     Massachusetts resident cannot hold one, but the State Comparison
    ///     screen evaluates one household's rows against every state's config.
    ///   - `privateEmployer`: on no exempt category. Golden case MA-4's second
    ///     spouse.
    ///   - `individual`: a personal IRA. Massachusetts's
    ///     `iraWithdrawalExemption` is `.none`.
    ///   - `unknown`: the migration default every pre-Phase-3b saved row
    ///     carries. Matching it would hand a full Massachusetts exclusion to
    ///     every unclassified pension in every existing user save, which is
    ///     the single most expensive over-match available and is precisely
    ///     what the shipped `unclassifiedPensionDisclosure` warns those users
    ///     about instead.
    @Test("No source outside the shipped Massachusetts rule is matched",
          arguments: Phase5bMassachusettsPerSourceTests.sourcesMassachusettsDoesNotName)
    func unnamedSourcesAreNotMatched(source: PlanSource) {
        #expect(Self.massachusettsExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: source) == nil,
                """
                \(source) is not on the shipped Massachusetts rule and must stay fully \
                taxable. A rule matching it is over-matching, which is the defect class \
                Phase 5b exists to prevent.
                """)
    }

    /// The out-of-state guard, called out by name because Massachusetts is the
    /// one jurisdiction in this phase where a maintainer has a PLAUSIBLE
    /// reason to widen the rule onto `otherStateOrLocal` and be wrong.
    ///
    /// mass.gov's enumerated exempt list includes out-of-state contributory
    /// pensions from states that RECIPROCATE, i.e. that exempt Massachusetts
    /// pensions in turn. That is a per-state reciprocity table this app does
    /// not have and this task did not establish from a primary source. Kansas
    /// pinned its out-of-state guard as golden case KS-7 with a dollar figure,
    /// which Massachusetts deliberately does NOT do: asserting "$3,000.00 on a
    /// California public pension" would assert that California does not
    /// reciprocate, and this phase deleted a Missouri scenario rather than
    /// ship a figure on an unverified source. The guard therefore lives here,
    /// as a match-level assertion that needs no reciprocity law at all.
    @Test("An out-of-state public pension is not matched, and the guard is deliberately not a golden case")
    func outOfStateIsNotMatched() {
        #expect(Self.massachusettsExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: .otherStateOrLocal) == nil,
                """
                A different state's public pension took the Massachusetts exclusion. \
                Massachusetts excludes an out-of-state contributory pension only where \
                that state RECIPROCATES, which this app does not model. Widening the \
                rule to otherStateOrLocal grants it unconditionally.
                """)
    }

    /// The structure half of the rule, which no fixture reaches on the
    /// matching side: every MA row the rule matches is `definedBenefit`.
    ///
    /// Why the constraint is there rather than "any structure": the exclusion
    /// is for contributory ANNUITY, pension, endowment and retirement funds of
    /// the Commonwealth, not for a Massachusetts state employee's 457 deferred
    /// compensation, which is employee salary reduction. Widening to any
    /// structure would auto-exempt a government salary-reduction plan on no
    /// authority, and `PlanClassificationChoice.governmentSalaryReduction` is
    /// a row a real user can already select.
    @Test("A named source in a NON-definedBenefit structure is not matched",
          arguments: Phase5bMassachusettsPerSourceTests.structuresOtherThanDefinedBenefit)
    func namedSourceInAnotherStructureIsNotMatched(structure: PlanStructure) {
        #expect(Self.massachusettsExemptions.matchedPerSourceRule(
            structure: structure, source: .ownStateOrLocal) == nil,
                """
                The Massachusetts rule constrains matchStructures to definedBenefit. A \
                \(structure) plan reaching it means the constraint was dropped.
                """)
    }

    // MARK: - End to end

    /// Inputs deliberately identical to golden cases MA-1 and MA-2 ($60,000
    /// defined-benefit pension, $60,000 gross, single, age 66), so the ONLY
    /// variable is `planSource`. The two expected figures are the fixture's
    /// own: $0.00 when the pension is excluded, $3,000.00 when it is not
    /// ($60,000 at the flat 5% rate; Massachusetts's `stateDeduction` is
    /// `none` in this app's config and it ships no `personalExemption`).
    @MainActor
    static func massachusettsTaxOnOnePension(source: PlanSource,
                                             structure: PlanStructure = .definedBenefit) -> Double {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 66; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .massachusetts
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000, owner: .primary,
                         planStructure: structure, planSource: source)
        ]
        return dm.calculateStateTaxFromGross(
            grossIncome: 60_000, forState: .massachusetts, filingStatus: .single,
            taxableSocialSecurity: 0)
    }

    @MainActor
    @Test("A Massachusetts contributory state pension is fully excluded, end to end")
    func ownStatePensionIsExemptEndToEnd() {
        let tax = Self.massachusettsTaxOnOnePension(source: .ownStateOrLocal)
        #expect(abs(tax) < 0.01,
                "expected $0.00 for a Massachusetts contributory state pension, got \(tax)")
    }

    @MainActor
    @Test("U.S. military retired pay is fully excluded in Massachusetts, end to end")
    func uniformedServicesPensionIsExemptEndToEnd() {
        let tax = Self.massachusettsTaxOnOnePension(source: .uniformedServices)
        #expect(abs(tax) < 0.01,
                """
                mass.gov: "U.S. military pensions, which are included in federal gross \
                income, are excluded from Massachusetts gross income." Expected $0.00, \
                got \(tax). $3,000.00 means the rule does not name uniformedServices; a \
                figure between the two means it names it with a cap.
                """)
    }

    /// The contrast that makes the two tests above mean something: identical
    /// inputs, one axis changed, a different answer. Without it a rule that
    /// excluded EVERYTHING would pass both.
    @MainActor
    @Test("An out-of-state public pension at identical inputs is still fully taxed, end to end")
    func otherStatePensionIsStillTaxedEndToEnd() {
        let tax = Self.massachusettsTaxOnOnePension(source: .otherStateOrLocal)
        #expect(abs(tax - 3_000.00) < 0.01,
                """
                $60,000 with no state standard deduction and no personal exemption, at \
                the flat 5% rate, is $3,000.00. Got \(tax). $0.00 means the \
                Massachusetts rule over-matched onto a different state's system.
                """)
    }

    /// The DISCLOSED UNDER-MATCH, pinned so its cost is a number rather than a
    /// sentence in a report.
    ///
    /// mass.gov's enumerated exempt list includes federal CONTRIBUTORY pensions
    /// and Railroad Retirement, and the shipped rule names neither, so both are
    /// taxed in full today. The omission is deliberate: the only statement of
    /// those two categories on this branch is a paraphrase inside golden case
    /// MA-2's `source` prose, and this task may not widen a rule from a
    /// paraphrase. This test is the durable record of what that costs, cited by
    /// the `knownButUnpinned` MA federal-civilian entry.
    ///
    /// It goes RED the day someone widens the rule, which is correct: widening
    /// it must come with reviewed golden cases, and this test failing is what
    /// forces that to be a deliberate, visible change rather than a quiet one.
    @MainActor
    @Test("A federal civilian or Railroad Retirement pension is taxed in full in Massachusetts today",
          arguments: [PlanSource.federalCivilian, .railroadRetirement])
    func federalCivilianIsTaxedInFullToday(source: PlanSource) {
        let tax = Self.massachusettsTaxOnOnePension(source: source)
        #expect(abs(tax - 3_000.00) < 0.01,
                """
                \(source): expected the full $3,000.00 the shipped rule produces today, \
                got \(tax). $0.00 means the Massachusetts rule was widened onto this \
                category. That may well be CORRECT under mass.gov's enumerated exempt \
                list, but it must arrive with a reviewed golden case pinning the figure, \
                and the knownButUnpinned entry for it must be deleted in the same change.
                """)
    }

    /// The structure guard, end to end. A Massachusetts state employee's 457
    /// plan carries `ownStateOrLocal` with a `definedContribution` structure
    /// and must be taxed in full.
    @MainActor
    @Test("An own-state plan that is NOT a defined-benefit annuity is still fully taxed, end to end")
    func ownStateDefinedContributionIsStillTaxedEndToEnd() {
        let tax = Self.massachusettsTaxOnOnePension(source: .ownStateOrLocal,
                                                    structure: .definedContribution)
        #expect(abs(tax - 3_000.00) < 0.01,
                "expected the full $3,000.00 for a non-annuity own-state plan, got \(tax)")
    }

    // MARK: - The picker, which is what makes the rule reachable by a real user

    /// The controller addendum's "verify, do not assume". Task 3 added
    /// `ownStateGovernmentPension` and `uniformedServicesPension` precisely so
    /// a correct rule would be reachable, and added a suppression rule
    /// (`residenceNamesItsOwnJurisdiction`) that hides the own-state row from
    /// residents of a state whose own config names its own jurisdiction.
    /// New York is the only such state. Massachusetts must NOT suppress:
    /// suppression here would leave a Massachusetts contributory retiree with
    /// no row that writes `ownStateOrLocal` at all, and every golden case in
    /// this phase would still be green while no real user could reach the
    /// exclusion. That is the exact failure Task 3 was created to fix, one
    /// state over.
    @Test("A Massachusetts resident is offered both rows the shipped rule needs")
    func pickerOffersTheRowsTheRuleNeeds() {
        #expect(!PlanClassificationChoice.residenceNamesItsOwnJurisdiction(.massachusetts),
                """
                Massachusetts's config names no jurisdiction-named PlanSource (it uses \
                the generic ownStateOrLocal), so the own-state row must not be \
                suppressed for its residents.
                """)

        let options = PlanClassificationChoice.options(for: .massachusetts, selected: nil)
        #expect(options.contains(.ownStateGovernmentPension),
                "a Massachusetts contributory retiree has no other row that writes ownStateOrLocal")
        #expect(options.contains(.uniformedServicesPension),
                "a Massachusetts military retiree has no other row that writes uniformedServices")

        // And what those rows WRITE is what the rule MATCHES. Asserting the
        // row exists is not enough: a row whose classification drifted would
        // still be present and still be useless.
        for choice in [PlanClassificationChoice.ownStateGovernmentPension, .uniformedServicesPension] {
            let classification = choice.classification
            #expect(Self.massachusettsExemptions.matchedPerSourceRule(
                structure: classification.structure, source: classification.source) != nil,
                    """
                    The picker row \(choice.rawValue) writes \(classification.structure)/\
                    \(classification.source), which the shipped Massachusetts rule does not \
                    match. The rule is unreachable through the app.
                    """)
        }
    }

    // MARK: - The disclosure, which the lockstep sweep requires

    @Test("Massachusetts fires the unclassified-pension disclosure on both surfaces")
    func disclosureFiresOnBothSurfaces() throws {
        let comparison = try #require(
            StateComparisonPresentation.unclassifiedPensionLimitationText(viewedState: .massachusetts))
        #expect(comparison.contains("Massachusetts excludes a contributory"))
        #expect(comparison.contains("this figure"))

        let briefing = MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: .massachusetts, hasUnclassifiedPension: true)
        #expect(briefing.count == 1)
        #expect(try #require(briefing.first).contains("this plan"))
    }

    // MARK: - The DataManager breakdown mirror

    /// THE MIRROR CHECK the Task 4 brief requires.
    ///
    /// `DataManager.stateTaxBreakdown` hand-duplicates the engine's per-source
    /// partition rather than calling into it, and that duplication has drifted
    /// from the engine five separate times on one branch. Nothing in the
    /// golden fixture set touches it: `GoldenScenarioSingleYearTests` drives
    /// `TaxCalculationEngine.calculateStateTax` directly and never constructs
    /// a breakdown.
    ///
    /// Swept over `PlanSource.allCases`, matched and unmatched together, so a
    /// case added by a later task is mirror-checked the moment it exists.
    @MainActor
    @Test("The income-breakdown mirror agrees with the tax computation for every Massachusetts source",
          arguments: PlanSource.allCases)
    func breakdownMirrorAgreesWithTheEngineForMassachusetts(source: PlanSource) {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 66; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .massachusetts
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: source)
        ]

        let breakdown = dm.stateTaxBreakdown(forState: .massachusetts, filingStatus: .single)
        let computed = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .massachusetts, filingStatus: .single,
            taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)

        #expect(abs(breakdown.totalStateTax - computed) < 0.01,
                """
                Massachusetts / \(source): the income-breakdown display reports \
                \(breakdown.totalStateTax) while the tax computation reports \(computed). \
                DataManager's per-source partition has drifted from \
                TaxCalculationEngine.applyRetirementExemptions.
                """)

        let isExemptSource = Self.massachusettsExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: source) != nil
        #expect(abs(breakdown.pensionExemptAmount - (isExemptSource ? 60_000 : 0)) < 0.01,
                """
                Massachusetts / \(source): breakdown attributes \(breakdown.pensionExemptAmount) \
                of pension exclusion, expected \(isExemptSource ? 60_000 : 0). The total can \
                be right while the displayed attribution is wrong; both are read by a user.
                """)
    }

    // MARK: - The contributory gap this task chose to record rather than close

    /// Task 4's judgement, made executable so it cannot quietly evaporate.
    ///
    /// Massachusetts's exclusion is conditioned on the plan being
    /// CONTRIBUTORY. `RetirementPlanClassification` has no contributory axis,
    /// so `(definedBenefit, ownStateOrLocal)` describes the exempt
    /// contributory household and the taxable noncontributory one
    /// identically, and the shipped rule excludes both. That is a REACHABLE
    /// under-taxation, it is deliberate, and it is recorded as a
    /// known-but-unpinned defect rather than pinned as a golden case, because
    /// a golden case for it would carry inputs byte-identical to MA-1's and a
    /// contradictory `expectedStateTax`.
    ///
    /// This test fails if that record is deleted. Without it the whole
    /// judgement lives in a report nobody re-reads, and the next person to
    /// touch Massachusetts sees only a green suite.
    @Test("The contributory-axis gap stays recorded as a known-but-unpinned defect")
    func theContributoryGapStaysRecorded() throws {
        // Massachusetts has TWO entries in this list and they record OPPOSITE
        // directions, so this must select on content, not on `state == "MA"`.
        // A `.first { $0.state == "MA" }` would silently start asserting
        // against the federal-civilian entry if the two were ever reordered.
        let entry = try #require(
            GoldenScenarioDefectCatalogueTests.knownButUnpinned.first {
                $0.state == "MA" && $0.summary.contains("NONCONTRIBUTORY")
            },
            """
            The Massachusetts contributory-axis gap is no longer recorded. Either the \
            axis was actually added, in which case this test should be replaced by a \
            golden case for the noncontributory household, or a real, reachable \
            under-taxation was silently dropped from the catalogue.
            """)
        #expect(entry.blockedOn.contains("contributory"))

        // And the gap is real, not merely described: the rule DOES match the
        // classification a noncontributory Massachusetts municipal retiree
        // would honestly select.
        let whatSuchAUserWouldSelect = PlanClassificationChoice.ownStateGovernmentPension.classification
        #expect(Self.massachusettsExemptions.matchedPerSourceRule(
            structure: whatSuchAUserWouldSelect.structure,
            source: whatSuchAUserWouldSelect.source) != nil,
                """
                The rule no longer matches the row a noncontributory Massachusetts \
                municipal retiree would select. If a contributory axis was added, delete \
                this test and the knownButUnpinned entry together.
                """)
    }

    /// The SECOND Massachusetts entry's deletion guard, which was missing.
    ///
    /// Added by the Phase 5b whole-branch review. `federalCivilianIsTaxedInFullToday`
    /// above pins the FIGURE this entry records the cost of, and its doc comment
    /// says the entry cites it, but it never touches the catalogue, so it is not
    /// a deletion guard. The only guard in this file selects on
    /// `summary.contains("NONCONTRIBUTORY")` and therefore guards the OTHER
    /// Massachusetts entry. That left the federal-civilian and Railroad
    /// Retirement gap deletable in silence, since
    /// `knownButUnpinnedIsWellFormed` checks only non-emptiness.
    ///
    /// Selects on content for the same reason its sibling does: Massachusetts
    /// has two entries recording OPPOSITE directions, so `state == "MA"` alone
    /// would assert against whichever came first.
    @Test("The Massachusetts federal-civilian and Railroad Retirement gap stays recorded")
    func theFederalCivilianGapStaysRecorded() throws {
        let entry = try #require(
            GoldenScenarioDefectCatalogueTests.knownButUnpinned.first {
                $0.state == "MA" && $0.summary.contains("FEDERAL CONTRIBUTORY")
            },
            """
            The Massachusetts federal-civilian and Railroad Retirement gap is no longer
            recorded. mass.gov's enumerated exempt list includes both categories and the
            shipped rule names neither, so a CSRS or FERS annuitant is over-taxed by
            $3,000.00 at the fixture's $60,000 single-filer shape. If the rule was widened
            it must arrive with reviewed golden cases, and this entry is deleted in that
            same change; if not, a measured over-taxation was silently dropped.
            """)
        #expect(entry.blockedOn.contains("REVIEWED derivation"))

        // Non-vacuous: the two categories the entry names are still unmatched by
        // the shipped rule, re-derived from live config rather than restated.
        for source in [PlanSource.federalCivilian, .railroadRetirement] {
            #expect(Self.massachusettsExemptions.matchedPerSourceRule(
                structure: .definedBenefit, source: source) == nil,
                    """
                    Massachusetts's shipped rule now matches \(source). That may well be \
                    correct under mass.gov's enumerated exempt list, but it must arrive \
                    with a reviewed golden case pinning the figure, and this test and the \
                    knownButUnpinned entry are deleted in the same change.
                    """)
        }

        // And both categories are picker-reachable, which is what makes the gap
        // a live user-facing one rather than a theoretical hole in the config.
        let options = PlanClassificationChoice.options(for: .massachusetts, selected: nil)
        for choice in [PlanClassificationChoice.federalCivilianPension, .railroadRetirementPension] {
            #expect(options.contains(choice),
                    "\(choice.rawValue) is no longer offered to a Massachusetts resident")
        }
    }
}
