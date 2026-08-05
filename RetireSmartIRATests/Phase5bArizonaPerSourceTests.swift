//
//  Phase5bArizonaPerSourceTests.swift
//  RetireSmartIRATests
//
//  Phase 5b Task 6: Arizona. The first jurisdiction in this phase whose rule
//  set is not a single grant. Arizona needs THREE behaviors from two lines of
//  Form 140, and only two of them are per-source rules:
//
//    Line 29b: uniformed-services retired pay, excluded in FULL, uncapped.
//              Shipped as a `.full` per-source rule.
//    Line 29a: U.S. government plus ARIZONA state and local pensions, capped
//              at $2,500. Shipped as the EXISTING pooled
//              `pensionExemption: .partial(2500)`, NOT as a per-source rule.
//    Everything else: no Arizona subtraction at all. Shipped as a `.none`
//              per-source rule, which removes the row from the pool the cap
//              machinery sees.
//
//  WHY THE CAP IS NOT A PER-SOURCE RULE, which is the central design decision
//  of this task and the thing most likely to be "simplified" later: design doc
//  section 3.4a requires per-source rules to PARTITION and the cap machinery to
//  then run ONCE on the pooled remainder. `PerSourceExemptionRule.treatment` is
//  evaluated inside the row loop in BOTH `TaxCalculationEngine
//  .applyRetirementExemptions` and its `DataManager.stateTaxBreakdown` mirror,
//  so a `.partial(2500)` treatment would grant $2,500 PER ROW. That is the
//  per-component-cap bug section 3.4a exists to prevent, and which this
//  codebase has already shipped once (New York's shared pension-and-IRA cap
//  exists because an earlier version granted $20,000 to each). The Arizona
//  golden fixture's per-taxpayer pooling guard case is what catches it: a
//  single filer with two qualifying pensions of $2,000 each must be excluded
//  $2,500 in total, and a per-row cap gives $4,000.
//
//  WHAT THE GOLDEN FIXTURE ALREADY COVERS, so this file does not repeat it:
//  statetax-2026-AZ.golden.json pins the end-to-end tax for a below-cap federal
//  civilian pension, a private pension, uncapped military retired pay, the
//  mixed government/private MFJ household, an ABOVE-cap federal civilian
//  pension, an out-of-state government pension, the two-qualifying-pensions
//  single filer, and the MFJ household whose qualifying pension sits on one
//  spouse. Those are the authority-derived numbers and they are the
//  specification.
//
//  WHAT THIS FILE ADDS, which no fixture reaches:
//    1. The negative sweep over every `PlanSource`, so a case added by a later
//       task is classified deliberately rather than by default.
//    2. The two config facts the fixture's arithmetic silently depends on and
//       which nothing else asserts: `pensionExemption` is still
//       `.partial(2500)` and `exemptionAppliesPerIndividual` is still `false`.
//    3. The phase-wide 3.4a invariant: NO shipped per-source rule anywhere
//       carries a capped treatment.
//    4. The `DataManager` income-breakdown MIRROR, which hand-duplicates the
//       engine's per-source partition and has drifted from it repeatedly. No
//       fixture drives that path: the golden runner calls
//       `TaxCalculationEngine` directly.
//    5. The picker reachability check, and the SECOND route to Arizona's
//       military exclusion that predates this task.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 5b Task 6: Arizona's Line 29a cap and Line 29b full exclusion")
struct Phase5bArizonaPerSourceTests {

    /// The REAL shipped Arizona config, never a test-shaped stand-in. A rule
    /// proven against a hand-built config proves nothing about the file that
    /// ships to users.
    static var arizonaExemptions: RetirementIncomeExemptions {
        StateTaxData.config(for: .arizona).retirementExemptions
    }

    // MARK: - The two rules, and which is which

    @Test("Arizona ships exactly two per-source rules: one full exclusion and one outright denial")
    func arizonaShipsAGrantRuleAndADenialRule() throws {
        let rules = Self.arizonaExemptions.perSourceExemptions
        #expect(rules.count == 2, "expected exactly two Arizona rules, found \(rules.count)")

        let grant = try #require(rules.first)
        #expect(grant.treatment.matchesShape(of: .full),
                """
                Line 29b excludes uniformed-services retired pay in full: "you may subtract \
                100% of the amount you received", with no dollar cap and no age gate. A \
                capped treatment here would be the Line 29a rule, which is a different line \
                of the form and is NOT shipped as a per-source rule.
                """)

        let denial = try #require(rules.last)
        #expect(denial.treatment.matchesShape(of: .none),
                """
                The second rule exists to REMOVE non-qualifying pensions from the pool the \
                $2,500 cap machinery sees, which is how a government-only exclusion is \
                expressed without turning the cap itself into a per-row cap. A treatment \
                other than `.none` here changes it from a denial into a grant.
                """)
    }

    // MARK: - The cap is NOT a per-source rule, and must never become one

    /// The 3.4a invariant, asserted across every shipped jurisdiction rather
    /// than only Arizona, because the bug it guards is a property of the
    /// evaluation site (a cap inside the row loop) and not of any one state.
    ///
    /// This is the test that fails if someone "simplifies" Arizona's two-rule
    /// arrangement into a single `.partial(2500)` per-source rule. That change
    /// leaves every ORIGINAL Arizona golden case green, which is precisely why
    /// a targeted test is needed alongside the fixture's pooling guard case.
    @Test("No shipped per-source rule anywhere carries a capped treatment",
          arguments: USState.allCases)
    func noShippedPerSourceRuleIsCapped(state: USState) {
        for rule in StateTaxData.config(for: state).retirementExemptions.perSourceExemptions {
            // Tested by CASE, not via `matchesShape`, which compares the
            // associated value too and would therefore pass for any cap other
            // than the one named.
            let isCapped: Bool
            switch rule.treatment {
            case .partial, .steppedPhaseoutByFilingStatus: isCapped = true
            case .none, .full: isCapped = false
            }
            #expect(!isCapped,
                    """
                    \(state.abbreviation) ships a per-source rule with a `partial` treatment. \
                    `PerSourceExemptionRule.treatment` is evaluated INSIDE the row loop in \
                    both TaxCalculationEngine.applyRetirementExemptions and the \
                    DataManager.stateTaxBreakdown mirror, so a capped treatment grants the \
                    cap once PER ROW rather than once per taxpayer. Design doc section 3.4a \
                    forbids exactly this, and this codebase has shipped the bug before. A \
                    capped exclusion belongs in `pensionExemption`, which the cap machinery \
                    applies once to the pooled remainder; use a `.none` per-source rule to \
                    keep non-qualifying sources out of that pool, as Arizona does.
                    """)
        }
    }

    /// The two config facts every arithmetic line in the Arizona fixture rests
    /// on. Neither is asserted anywhere else, and changing either silently
    /// re-derives eight expected values.
    @Test("Arizona's $2,500 cap is still the pooled pension exemption, applied once per return")
    func arizonaCapIsPooledAndNotDoubled() {
        let exemptions = Self.arizonaExemptions
        #expect(exemptions.pensionExemption.matchesShape(of: .partial(maxExempt: 2500)),
                """
                Line 29a's $2,500 subtraction is modelled as the pooled `pensionExemption`. \
                Setting it to `.none` and moving the cap into a per-source rule is the \
                change `noShippedPerSourceRuleIsCapped` above forbids.
                """)
        #expect(!exemptions.exemptionAppliesPerIndividual,
                """
                `exemptionAppliesPerIndividual` doubles the cap whenever BOTH spouses clear \
                the AGE gate. Arizona's Line 29a doubling is conditioned on both spouses \
                RECEIVING qualifying pension income, which is a different condition. Setting \
                this true makes the MFJ both-spouses golden case green and simultaneously \
                grants $5,000 to a household where only ONE spouse holds a qualifying \
                pension, understating its tax by $62.50. That trade was measured and \
                declined; the fixture's non-doubling guard case pins the consequence.
                """)
    }

    // MARK: - What the rules MUST and MUST NOT match

    /// The single hand-written list in this file: the sources Line 29b covers.
    static let sourcesLine29bNames: [PlanSource] = [.uniformedServices]

    /// The sources the denial rule names, hand-written for the same reason.
    /// Each is a pension Arizona Form 140 Line 29a does not reach:
    /// `privateEmployer` (on no 29a category), `otherStateOrLocal` (a DIFFERENT
    /// state's system; 29a covers Arizona's own), and `nyStateOrLocal` (New
    /// York's jurisdiction-named case, which an Arizona resident can still
    /// select because Arizona's config names no jurisdiction of its own, so
    /// `options(for:)` does not suppress any row for them).
    static let sourcesDeniedOutright: [PlanSource] = [
        .privateEmployer, .otherStateOrLocal, .nyStateOrLocal
    ]

    /// DERIVED, never listed. Everything the two rules leave alone, which
    /// therefore falls through to the pooled $2,500 cap.
    static let sourcesFallingThroughToTheCap: [PlanSource] =
        PlanSource.allCases.filter {
            !sourcesLine29bNames.contains($0) && !sourcesDeniedOutright.contains($0)
        }

    /// DERIVED, never listed.
    static let structuresOtherThanDefinedBenefit: [PlanStructure] =
        PlanStructure.allCases.filter { $0 != .definedBenefit }

    @Test("Uniformed-services retired pay is matched by the full-exclusion rule",
          arguments: Phase5bArizonaPerSourceTests.sourcesLine29bNames)
    func line29bSourcesAreFullyExcluded(source: PlanSource) throws {
        let rule = try #require(Self.arizonaExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: source))
        #expect(rule.treatment.matchesShape(of: .full),
                "\(source) is Line 29b income and must be excluded in full, not capped")
    }

    @Test("Every source the denial rule names is matched, and matched as a denial",
          arguments: Phase5bArizonaPerSourceTests.sourcesDeniedOutright)
    func deniedSourcesAreMatchedAsDenials(source: PlanSource) throws {
        let rule = try #require(Self.arizonaExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: source),
                                """
                                \(source) is not reachable by Form 140 Line 29a and must be \
                                removed from the pool the $2,500 cap sees. An unmatched row \
                                is POOLED, which would hand it the government-pension \
                                allowance.
                                """)
        #expect(rule.treatment.matchesShape(of: .none))
    }

    /// The half that matters most, and the half a green fixture set cannot
    /// prove on its own. `federalCivilian` and `ownStateOrLocal` must NOT be
    /// matched by any rule: they qualify for Line 29a, and Line 29a is the
    /// pooled cap, so being matched by a `.full` rule would make them uncapped
    /// and being matched by a `.none` rule would deny them entirely.
    ///
    /// DERIVED from `PlanSource.allCases`, so a case a later task adds falls
    /// here by default and has to be moved deliberately, which a reviewer sees.
    @Test("Everything Line 29a can reach falls through to the pooled cap, matched by no rule",
          arguments: Phase5bArizonaPerSourceTests.sourcesFallingThroughToTheCap)
    func line29aSourcesFallThroughToThePooledCap(source: PlanSource) {
        #expect(Self.arizonaExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: source) == nil,
                """
                \(source) is matched by an Arizona per-source rule. Line 29a's $2,500 \
                allowance is the POOLED pensionExemption, so a qualifying source must reach \
                the cap machinery unmatched. A `.full` match makes it uncapped; a `.none` \
                match denies it outright. Both are wrong for federalCivilian and \
                ownStateOrLocal.
                """)
    }

    /// `unknown` is in the fall-through list above, and deliberately so. This
    /// spells out the decision rather than leaving it to be inferred from a
    /// derived array, because Kansas made the OPPOSITE call and the contrast
    /// is the thing a later reader needs.
    ///
    /// Kansas's rule GRANTS, so leaving `unknown` unmatched there means "taxed
    /// in full until classified", the conservative outcome. Arizona's second
    /// rule DENIES, so naming `unknown` there would mean "no allowance until
    /// classified" and would RAISE tax for every existing Arizona user who has
    /// not classified, including genuine government pensioners entitled to it.
    /// Arizona follows New York's precedent instead: the blanket allowance
    /// keeps applying to unclassified rows and `unclassifiedPensionDisclosure`
    /// warns about it. The residual defect is recorded in
    /// `GoldenScenarioDefectCatalogueTests.knownButUnpinned`.
    @Test("An unclassified pension keeps the $2,500 allowance, following New York rather than Kansas")
    func unclassifiedPensionKeepsTheAllowance() {
        #expect(Self.arizonaExemptions.matchedPerSourceRule(
            structure: .unknown, source: .unknown) == nil)
        #expect(Self.arizonaExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: .unknown) == nil,
                """
                Arizona's denial rule now names `unknown`, the migration default on every \
                pre-Phase-3b saved row. That raises state tax for every existing Arizona \
                user who has not classified their pension, with no action on their part. If \
                that is intended, the knownButUnpinned AZ entry and the disclosure sentence \
                both need rewriting in the same change.
                """)
    }

    /// The structure half of the Line 29b rule, which no fixture reaches
    /// because every classified row in the Arizona fixture is `definedBenefit`.
    /// Deleting `matchStructures` from the shipped grant rule leaves every
    /// golden case green and this test red.
    @Test("Uniformed-services income in a NON-definedBenefit structure is not fully excluded",
          arguments: Phase5bArizonaPerSourceTests.structuresOtherThanDefinedBenefit)
    func militaryInAnotherStructureIsNotFullyExcluded(structure: PlanStructure) {
        let rule = Self.arizonaExemptions.matchedPerSourceRule(
            structure: structure, source: .uniformedServices)
        #expect(rule == nil,
                """
                Line 29b names "retired or retainer pay of the uniformed services", the \
                annuity axis this app models as definedBenefit. A \(structure) plan reaching \
                the full-exclusion rule means the constraint was dropped.
                """)
    }

    /// The denial rule deliberately spans BOTH employer-plan structures, so a
    /// private 401(k) or 403(b) entered as pension income is denied too, while
    /// `ira` stays outside it. That last point is load-bearing: `.rmd` rows
    /// infer `(ira, individual)` and are partitioned by the same
    /// `matchedPerSourceRule` call, so widening the denial rule to `ira` would
    /// start removing RMD rows from the IRA pool.
    @Test("The denial rule covers both employer-plan structures but never reaches IRA rows")
    func denialRuleSpansEmployerStructuresOnly() {
        for structure in [PlanStructure.definedBenefit, .definedContribution] {
            #expect(Self.arizonaExemptions.matchedPerSourceRule(
                structure: structure, source: .privateEmployer) != nil,
                    "a private \(structure) plan is not Line 29a income and must be denied")
        }
        for structure in [PlanStructure.ira, .unknown] {
            #expect(Self.arizonaExemptions.matchedPerSourceRule(
                structure: structure, source: .privateEmployer) == nil,
                    """
                    The denial rule now reaches \(structure). `.rmd` income rows infer \
                    (ira, individual) and run through the same partition, so widening this \
                    rule changes IRA handling as a side effect.
                    """)
        }
    }

    // MARK: - End to end, through the paths no fixture reaches

    /// One $10,000 pension, ABOVE the $2,500 cap so capped and uncapped answers
    /// differ, with only `planSource` varying. $10,000 is used rather than the
    /// fixture's $2,000 for exactly the reason Phase 4 flagged Arizona: at
    /// $2,000 every candidate rule produces the same number.
    ///
    /// The $30,000 of other income is load-bearing and is NOT padding. Arizona
    /// conforms to the federal standard deduction, which for a single 66-year
    /// old in 2026 is $24,150 (base $16,100 + age-65 addition $2,050 + the full
    /// OBBBA senior bonus $6,000). With the pension as the only income, taxable
    /// income floors at zero and all three treatments compute $0.00, so a
    /// comparison between them proves nothing. This mirrors the fixture's own
    /// $40,000 AGI shape, where the cap is worth a visible $62.50.
    @MainActor
    static func arizonaBreakdown(source: PlanSource,
                                 structure: PlanStructure = .definedBenefit) -> (DataManager, StateTaxBreakdown) {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 66; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .arizona
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 10_000, owner: .primary,
                         planStructure: structure, planSource: source),
            IncomeSource(name: "Other", type: .consulting, annualAmount: 30_000, owner: .primary)
        ]
        return (dm, dm.stateTaxBreakdown(forState: .arizona, filingStatus: .single))
    }

    /// THE MIRROR CHECK this task owes.
    ///
    /// `DataManager.stateTaxBreakdown` hand-duplicates the engine's per-source
    /// partition rather than calling into it, and that duplication has drifted
    /// from the engine five separate times on one branch. Nothing in the golden
    /// fixture set touches it: `GoldenScenarioSingleYearTests.singleYearStateTax`
    /// drives `TaxCalculationEngine.calculateStateTax` directly and never
    /// constructs a breakdown.
    ///
    /// Swept over every `PlanSource`, asserting both that the breakdown's total
    /// agrees with the computed tax AND that it attributes the right exclusion
    /// amount. A mirror that agrees on the total while displaying the wrong
    /// exempt figure is still a defect an Arizona user reads.
    @MainActor
    @Test("The income-breakdown mirror agrees with the tax computation for every Arizona source",
          arguments: PlanSource.allCases)
    func breakdownMirrorAgreesWithTheEngineForArizona(source: PlanSource) {
        let (dm, breakdown) = Self.arizonaBreakdown(source: source)
        let computed = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .arizona, filingStatus: .single,
            taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)

        #expect(abs(breakdown.totalStateTax - computed) < 0.01,
                """
                Arizona / \(source): the income-breakdown display reports \
                \(breakdown.totalStateTax) while the tax computation reports \(computed). \
                DataManager's per-source partition has drifted from \
                TaxCalculationEngine.applyRetirementExemptions.
                """)

        let expectedExempt: Double
        if Self.sourcesLine29bNames.contains(source) {
            expectedExempt = 10_000          // Line 29b, uncapped
        } else if Self.sourcesDeniedOutright.contains(source) {
            expectedExempt = 0               // not Line 29a income at all
        } else {
            expectedExempt = 2_500           // Line 29a, pooled and capped
        }
        #expect(abs(breakdown.pensionExemptAmount - expectedExempt) < 0.01,
                """
                Arizona / \(source): breakdown attributes \(breakdown.pensionExemptAmount) \
                of pension exclusion, expected \(expectedExempt). $10,000 means an \
                uncapped grant where Line 29a caps at $2,500; $0 means a qualifying \
                pension was denied; $2,500 for a military pension means Line 29b was \
                modelled as the capped line.
                """)
    }

    /// The contrast that makes the sweep above mean something: identical
    /// inputs, one axis changed, three different answers. Without it a rule
    /// that exempted everything, or nothing, would still satisfy a total-only
    /// check.
    @MainActor
    @Test("Military, government and private pensions at identical inputs produce three different taxes")
    func theThreeTreatmentsAreActuallyDistinct() {
        let military = Self.arizonaBreakdown(source: .uniformedServices).1.totalStateTax
        let government = Self.arizonaBreakdown(source: .federalCivilian).1.totalStateTax
        let priv = Self.arizonaBreakdown(source: .privateEmployer).1.totalStateTax

        #expect(military < government,
                "military retired pay is uncapped and must be taxed less than a capped government pension")
        #expect(government < priv,
                "a government pension gets $2,500 that a private pension does not, so it must be taxed less")
        // The $2,500 allowance at Arizona's 2.5% flat rate is worth exactly
        // $62.50, which pins the SIZE of the gap and not merely its sign.
        #expect(abs((priv - government) - 62.50) < 0.01,
                """
                The Line 29a allowance is worth $2,500 x 2.5% = $62.50. Got \
                \(priv - government), which means the cap is not $2,500.
                """)
    }

    /// An Arizona resident's OWN state system is Line 29a income; a different
    /// state's is not. The two are one enum case apart and the fixture's
    /// out-of-state guard case pins the dollars, but only through the engine.
    /// This pins it through the residence mapping, which is the path the State
    /// Comparison screen actually uses.
    @MainActor
    @Test("An Arizona resident's own-state pension is capped, and another state's gets nothing")
    func ownStateIsCappedAndOutOfStateIsDenied() {
        let ownState = Self.arizonaBreakdown(source: .ownStateOrLocal).1
        #expect(abs(ownState.pensionExemptAmount - 2_500) < 0.01,
                """
                An Arizona State Retirement System pension is named on Line 29a and must \
                receive the $2,500 allowance, got \(ownState.pensionExemptAmount).
                """)

        let outOfState = Self.arizonaBreakdown(source: .otherStateOrLocal).1
        #expect(abs(outOfState.pensionExemptAmount) < 0.01,
                """
                Line 29a covers U.S. government plus ARIZONA state and local systems. A \
                California public pension held by an Arizona resident is not on that list \
                and must receive nothing, got \(outOfState.pensionExemptAmount).
                """)
    }

    /// And the same fact reached the way the State Comparison screen reaches
    /// it: a Kansas resident's KPERS pension is `ownStateOrLocal`, and asking
    /// "what would I pay in Arizona" must remap it to `otherStateOrLocal` and
    /// deny it, rather than letting it claim Arizona's own-state allowance.
    @MainActor
    @Test("Another state's resident does not inherit Arizona's own-state allowance when comparing")
    func ownStateAllowanceIsNotInheritedByComparison() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 66; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .kansas
        dm.incomeSources = [
            IncomeSource(name: "KPERS", type: .pension, annualAmount: 10_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .ownStateOrLocal)
        ]

        #expect(dm.incomeSources(asResidentOf: .arizona).first?.planSource == .otherStateOrLocal)
        let breakdown = dm.stateTaxBreakdown(forState: .arizona, filingStatus: .single)
        #expect(abs(breakdown.pensionExemptAmount) < 0.01,
                """
                A Kansas KPERS pension claimed Arizona's Line 29a allowance \
                (\(breakdown.pensionExemptAmount) exempted). Arizona grants it to U.S. \
                government and ARIZONA systems only.
                """)
        let computed = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .arizona, filingStatus: .single,
            taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)
        #expect(abs(breakdown.totalStateTax - computed) < 0.01,
                "the residence mapping was applied to one path and not the other")
    }

    // MARK: - The SECOND route to Arizona's military exclusion, which predates this task

    /// Arizona has excluded military retired pay in full since 2022, and this
    /// app already implemented that: `MilitaryRetirementExemption
    /// .stateTaxableAmount` returns `.fullyExempt` for "AZ". That path fires
    /// for rows typed `IncomeType.militaryRetirement` and is DISJOINT from the
    /// per-source partition, which only ever inspects `.pension` and `.rmd`
    /// rows, so there is no double exclusion: a row has exactly one type.
    ///
    /// What this task changed is that the SAME money entered the other way, as
    /// a pension classified "Military retired pay" in the picker, now gets the
    /// same answer. Before it, that row took the $2,500 cap. This test pins the
    /// two routes together, so a later change to either is caught by the
    /// disagreement rather than by a user noticing two Arizona answers for one
    /// household.
    @MainActor
    @Test("Both routes to Arizona's military exclusion now agree")
    func bothMilitaryRoutesAgree() {
        func tax(type: IncomeType, source: PlanSource) -> Double {
            let dm = DataManager(skipPersistence: true)
            var dob = DateComponents(); dob.year = 2026 - 66; dob.month = 1; dob.day = 1
            dm.profile.birthDate = Calendar.current.date(from: dob)!
            dm.profile.currentYear = 2026
            dm.filingStatus = .single
            dm.enableSpouse = false
            dm.selectedState = .arizona
            dm.incomeSources = [
                IncomeSource(name: "Retired pay", type: type, annualAmount: 40_000, owner: .primary,
                             planStructure: .definedBenefit, planSource: source)
            ]
            return dm.calculateStateTaxFromGross(
                grossIncome: 40_000, forState: .arizona, filingStatus: .single,
                taxableSocialSecurity: 0)
        }

        let asMilitaryRow = tax(type: .militaryRetirement, source: .unknown)
        let asClassifiedPension = tax(type: .pension, source: .uniformedServices)
        #expect(abs(asMilitaryRow - asClassifiedPension) < 0.01,
                """
                Arizona taxes the same military retired pay differently depending on which \
                screen it was entered from: \(asMilitaryRow) as a military-retirement row \
                against \(asClassifiedPension) as a classified pension. Both are Form 140 \
                Line 29b income.
                """)
    }

    // MARK: - Reachability: a real user can select what the rules need

    /// Task 3 added picker rows so a correct rule is reachable by a user rather
    /// than only by a golden fixture. Arizona's rules turn on three of them.
    @Test("An Arizona user can select every classification Arizona's rules distinguish")
    func arizonaUserCanReachEveryClassificationTheRulesNeed() {
        let options = PlanClassificationChoice.options(for: .arizona, selected: nil)
        for required in [PlanClassificationChoice.ownStateGovernmentPension,
                         .federalCivilianPension,
                         .uniformedServicesPension,
                         .otherStateGovernmentPension,
                         .privateEmployerPension] {
            #expect(options.contains(required),
                    """
                    An Arizona resident cannot select \(required.label). Arizona's rules \
                    distinguish it, so a rule that depends on it would be unreachable \
                    outside the fixtures.
                    """)
        }
    }

    /// The specific suppression the brief flagged. `options(for:)` hides the
    /// generic own-state row for residents whose own config names their own
    /// jurisdiction, which today is New York alone. Arizona's config names no
    /// jurisdiction-named source, so the row must survive: it is the ONLY way
    /// an Arizona State Retirement System retiree can describe their pension,
    /// and Line 29a covers it.
    @Test("Arizona does not suppress the own-state picker row")
    func arizonaDoesNotSuppressTheOwnStateRow() {
        #expect(!PlanClassificationChoice.residenceNamesItsOwnJurisdiction(.arizona),
                """
                Arizona's config now names a jurisdiction-named PlanSource, which suppresses \
                the generic own-state picker row for Arizona residents. Arizona's Line 29a \
                rule reaches ownStateOrLocal, so suppressing that row makes the allowance \
                unreachable for an ASRS retiree.
                """)
        #expect(PlanClassificationChoice.options(for: .arizona, selected: nil)
            .contains(.ownStateGovernmentPension))
    }

    /// Shipping `perSourceExemptions` is what turns the classification prompt
    /// on for a jurisdiction. Arizona had no prompt before this task, so an
    /// Arizona user was never asked the question their tax now turns on.
    @Test("Arizona now prompts an unclassified pension for classification")
    func arizonaNowPromptsForClassification() {
        let unclassified = IncomeSource(name: "Pension", type: .pension, annualAmount: 10_000,
                                        planStructure: .unknown, planSource: .unknown)
        #expect(PlanClassificationChoice.shouldPromptForClassification(
            source: unclassified,
            residenceHasPerSourceRules: PlanClassificationChoice
                .residenceHasPerSourceRules(.arizona)),
                """
                An Arizona resident with an unclassified pension is not prompted to classify \
                it, while their tax now depends on the answer. This is the Kansas defect \
                Task 3b closed, reappearing for Arizona.
                """)
    }

    // MARK: - The disclosure

    /// Task 3b's lockstep sweep asserts a sentence EXISTS. This asserts it says
    /// the right things, which the sweep cannot.
    @Test("Arizona's disclosure names both lines and the allowance a user actually gets")
    func arizonaDisclosureNamesBothLines() throws {
        let sentence = try #require(Self.arizonaExemptions.unclassifiedPensionDisclosure)
        #expect(sentence.contains("military retired pay"),
                "the uncapped Line 29b exclusion is the larger of the two and must be named")
        #expect(sentence.contains("$2,500"),
                "a user cannot act on the warning without the figure")
        #expect(sentence.contains(UnclassifiedPensionDisclosure.scopeToken))

        let figure = try #require(
            UnclassifiedPensionDisclosure.text(for: .arizona, scope: .stateComparisonFigure))
        #expect(figure.contains("this figure"))
        #expect(!figure.contains(UnclassifiedPensionDisclosure.scopeToken))
    }
}
