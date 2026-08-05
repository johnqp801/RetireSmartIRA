//
//  Phase5bKansasPerSourceTests.swift
//  RetireSmartIRATests
//
//  Phase 5b Task 3: the FIRST state rule written against the vocabulary Task
//  1 added. Kansas's Schedule S Line A14 is a CLOSED list of NAMED Kansas
//  public plans and NAMED federal plans; the shipped rule in
//  RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json names
//  four sources -- ownStateOrLocal (KPERS), federalCivilian (CSRS/FERS),
//  uniformedServices (armed forces retired pay) and railroadRetirement --
//  and constrains them to definedBenefit.
//
//  WHAT THE GOLDEN FIXTURE ALREADY COVERS, so this file does not repeat it:
//  statetax-2026-KS.golden.json pins the end-to-end tax for ownStateOrLocal
//  (KS-4), ownStateOrLocal + federalCivilian (KS-5), the mixed KPERS/private
//  household (KS-6), privateEmployer (KS-3), otherStateOrLocal (KS-7) and
//  governmentUnspecified (KS-8). Those are the authority-derived numbers and
//  they are the specification.
//
//  WHAT THIS FILE ADDS, which no fixture reaches:
//    1. The two sources the rule names that no fixture exercises,
//       uniformedServices and railroadRetirement. Kansas's promise covers all
//       four, and two of them were green only because nothing tested them.
//    2. The STRUCTURE half of the rule. Every fixture row is definedBenefit,
//       so `matchStructures` could be deleted outright and every golden case
//       would stay green.
//    3. The DataManager income-breakdown MIRROR, which hand-duplicates the
//       engine's per-source partition (DataManager.swift, "Phase 3b Task 4"
//       comment) and has drifted from the engine repeatedly on this project.
//       No fixture drives that path at all: the golden runner calls
//       TaxCalculationEngine directly.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 5b Task 3: the shipped Kansas per-source rule matches exactly what Line A14 names")
struct Phase5bKansasPerSourceTests {

    /// The REAL shipped Kansas config, never a test-shaped stand-in. A rule
    /// proven against a hand-built config proves nothing about the file that
    /// ships to users.
    static var kansasExemptions: RetirementIncomeExemptions {
        StateTaxData.config(for: .kansas).retirementExemptions
    }

    // MARK: - The rule exists at all, and is the only one

    @Test("Kansas ships exactly one per-source rule, treated as a full exclusion")
    func kansasShipsOneFullExclusionRule() throws {
        let rules = Self.kansasExemptions.perSourceExemptions
        #expect(rules.count == 1, "expected exactly one Kansas rule, found \(rules.count)")
        let rule = try #require(rules.first)
        #expect(rule.treatment.matchesShape(of: .full),
                """
                Line A14 exempts each named plan in FULL, with no dollar cap and no age \
                gate stated. A partial or capped treatment here would be a different rule \
                than the one the fixture's arithmetic was derived from.
                """)
    }

    // MARK: - What the rule MUST match

    /// The four sources Line A14 names. `uniformedServices` and
    /// `railroadRetirement` are here because no golden case reaches them:
    /// without this test the rule could name only two of the four and the
    /// whole suite would stay green while two thirds of the written promise
    /// went undelivered.
    @Test("Every source Line A14 names is matched, as a defined-benefit pension", arguments: [
        PlanSource.ownStateOrLocal, .federalCivilian, .uniformedServices, .railroadRetirement
    ])
    func namedSourcesAreMatched(source: PlanSource) {
        #expect(Self.kansasExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: source) != nil,
                "\(source) is enumerated on Schedule S Line A14 and must be excluded")
    }

    // MARK: - What the rule MUST NOT match

    /// The negative half, which is the half this phase exists to protect.
    /// Each entry is a source a Kansas rule could plausibly have swept up.
    ///
    ///   - `otherStateOrLocal`: a DIFFERENT state's system. Golden case KS-7
    ///     pins the dollar consequence; this pins the match itself.
    ///   - `governmentUnspecified`: "some government employer", jurisdiction
    ///     never established. Line A14 lists NAMED plans, and
    ///     `PlanSource.governmentUnspecified`'s own doc comment forbids any
    ///     rule treating it as a specific jurisdiction. Golden case KS-8.
    ///   - `privateEmployer`: on no A14 category. Golden case KS-3.
    ///   - `individual`: a personal IRA. Kansas's `iraWithdrawalExemption` is
    ///     `.none`, so IRA money is taxable and must not reach a rule written
    ///     for employer plans.
    ///   - `nyStateOrLocal`: New York's own jurisdiction-named case. A Kansas
    ///     resident cannot hold one, but a rule that matched "any state-named
    ///     source" would sweep it up, and the State Comparison screen
    ///     evaluates one household's rows against every state's config.
    ///   - `unknown`: the migration default every pre-Phase-3b saved row
    ///     carries. Matching it would hand a full Kansas exclusion to every
    ///     unclassified pension in every existing user save.
    @Test("No source outside Line A14's closed list is matched", arguments: [
        PlanSource.otherStateOrLocal, .governmentUnspecified, .privateEmployer,
        .individual, .nyStateOrLocal, .unknown
    ])
    func unnamedSourcesAreNotMatched(source: PlanSource) {
        #expect(Self.kansasExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: source) == nil,
                """
                \(source) is not on Schedule S Line A14's closed list and must stay fully \
                taxable in Kansas. A rule matching it is over-matching, which is the defect \
                class Phase 5b exists to prevent.
                """)
    }

    /// The structure half of the rule, which no fixture reaches because
    /// every classified row in statetax-2026-KS.golden.json is
    /// `definedBenefit`. Deleting `matchStructures` from the shipped file
    /// would leave every golden case green and this test red.
    ///
    /// Why the constraint is there rather than "any structure": Line A14
    /// names "Kansas Public Employees' Retirement (KPERS) ANNUITIES", not
    /// the separate KPERS 457 deferred-compensation plan, and this app's
    /// `definedBenefit` is the annuity axis. Widening to any structure would
    /// auto-exempt a government salary-reduction plan on no authority. The
    /// known cost of the constraint is recorded in the Task 3 report: A14
    /// does name Thrift Savings Plans inside its federal category, and a TSP
    /// is defined-contribution, so a Kansas TSP holder is still taxed. That
    /// is a disclosed under-match, not something to close by guessing.
    @Test("A named source in a NON-definedBenefit structure is not matched", arguments: [
        PlanStructure.definedContribution, .ira, .unknown
    ])
    func namedSourceInAnotherStructureIsNotMatched(structure: PlanStructure) {
        #expect(Self.kansasExemptions.matchedPerSourceRule(
            structure: structure, source: .ownStateOrLocal) == nil,
                """
                The Kansas rule constrains matchStructures to definedBenefit. A \
                \(structure) plan reaching it means the constraint was dropped.
                """)
    }

    // MARK: - End to end, through the two sources no fixture exercises

    /// Inputs deliberately identical to the fixture's three age-68 single
    /// cases ($40,000 defined-benefit pension, $40,000 gross, single, age
    /// 68), so the ONLY variable is `planSource`. The two expected figures
    /// are the fixture's own, hand-derived from ip25.pdf: $0.00 when the
    /// pension is exempt, $1,432.31 when it is not.
    @MainActor
    static func kansasTaxOnOnePension(source: PlanSource,
                                      structure: PlanStructure = .definedBenefit) -> Double {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 68; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .kansas
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000, owner: .primary,
                         planStructure: structure, planSource: source)
        ]
        return dm.calculateStateTaxFromGross(
            grossIncome: 40_000, forState: .kansas, filingStatus: .single,
            taxableSocialSecurity: 0)
    }

    @MainActor
    @Test("Military retired pay is fully exempt in Kansas, end to end")
    func uniformedServicesPensionIsExemptEndToEnd() {
        let tax = Self.kansasTaxOnOnePension(source: .uniformedServices)
        #expect(abs(tax) < 0.01,
                """
                Schedule S Line A14 exempts "any other amounts received as retirement \
                benefits ... for service in the United States Armed Forces". Expected \
                $0.00, got \(tax). $1,432.31 means the rule does not name \
                uniformedServices; a figure between the two means it names it with a cap.
                """)
    }

    @MainActor
    @Test("Railroad Retirement benefits are fully exempt in Kansas, end to end")
    func railroadRetirementIsExemptEndToEnd() {
        let tax = Self.kansasTaxOnOnePension(source: .railroadRetirement)
        #expect(abs(tax) < 0.01,
                """
                Line A14 exempts U.S. Railroad Retirement Board plans by name. Expected \
                $0.00, got \(tax).
                """)
    }

    /// The contrast that makes the two tests above mean something: identical
    /// inputs, one axis changed, a different answer. Without it, a rule that
    /// exempted EVERYTHING would pass both of them.
    @MainActor
    @Test("An out-of-state public pension at identical inputs is still fully taxed")
    func otherStatePensionIsStillTaxedEndToEnd() {
        let tax = Self.kansasTaxOnOnePension(source: .otherStateOrLocal)
        #expect(abs(tax - 1_432.31) < 0.01,
                """
                $40,000 minus the $3,605 single standard deduction minus the $9,160 SB1 \
                personal exemption = $27,235; $23,000 x 5.2% + $4,235 x 5.58% = $1,432.31. \
                Got \(tax). $0.00 means the Kansas rule over-matched onto a different \
                state's system, which is exactly what golden case KS-7 exists to catch.
                """)
    }

    /// The structure guard, end to end. A government salary-reduction plan
    /// classified to the taxpayer's own state carries `ownStateOrLocal` with
    /// a `definedContribution` structure, and must be taxed in full.
    @MainActor
    @Test("An own-state plan that is NOT a defined-benefit annuity is still fully taxed")
    func ownStateDefinedContributionIsStillTaxedEndToEnd() {
        let tax = Self.kansasTaxOnOnePension(source: .ownStateOrLocal,
                                             structure: .definedContribution)
        #expect(abs(tax - 1_432.31) < 0.01,
                "expected the full $1,432.31 for a non-annuity own-state plan, got \(tax)")
    }

    // MARK: - The DataManager breakdown mirror

    /// THE MIRROR CHECK the Task 3 brief requires.
    ///
    /// `DataManager.stateTaxBreakdown` hand-duplicates the engine's
    /// per-source partition rather than calling into it (it calls the same
    /// `matchedPerSourceRule`, but re-implements the loop, the pooling and
    /// the cap interaction around it). That duplication has drifted from the
    /// engine five separate times on one branch, and nothing in the golden
    /// fixture set touches it: `GoldenScenarioSingleYearTests.singleYearStateTax`
    /// drives `TaxCalculationEngine.calculateStateTax` directly and never
    /// constructs a breakdown at all.
    ///
    /// This sweeps every source the Kansas rule names AND every source it
    /// deliberately rejects, asserting on each that the breakdown's
    /// `totalStateTax` equals what `calculateStateTaxFromGross` computes, and
    /// that the breakdown ATTRIBUTES the exclusion to the pension line
    /// rather than merely arriving at the right total by a different route.
    /// A mirror that agrees on the total while showing $0 exempted would
    /// still be a display defect a Kansas user would notice.
    @MainActor
    @Test("The income-breakdown mirror agrees with the tax computation for every Kansas source", arguments: [
        PlanSource.ownStateOrLocal, .federalCivilian, .uniformedServices, .railroadRetirement,
        .otherStateOrLocal, .governmentUnspecified, .privateEmployer, .unknown
    ])
    func breakdownMirrorAgreesWithTheEngineForKansas(source: PlanSource) {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 68; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .kansas
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: source)
        ]

        let breakdown = dm.stateTaxBreakdown(forState: .kansas, filingStatus: .single)
        let computed = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .kansas, filingStatus: .single,
            taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)

        #expect(abs(breakdown.totalStateTax - computed) < 0.01,
                """
                Kansas / \(source): the income-breakdown display reports \
                \(breakdown.totalStateTax) while the tax computation reports \(computed). \
                DataManager's per-source partition has drifted from \
                TaxCalculationEngine.applyRetirementExemptions.
                """)

        let isExemptSource = Self.kansasExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: source) != nil
        #expect(abs(breakdown.pensionExemptAmount - (isExemptSource ? 40_000 : 0)) < 0.01,
                """
                Kansas / \(source): breakdown attributes \(breakdown.pensionExemptAmount) \
                of pension exclusion, expected \(isExemptSource ? 40_000 : 0). The total \
                can be right while the displayed attribution is wrong; both are read by a \
                user.
                """)
    }
}
