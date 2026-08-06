//
//  Phase5bIdahoDecisionTests.swift
//  RetireSmartIRATests
//
//  Phase 5b Task 8: Idaho. The third task in this phase whose deliverable is a
//  DECISION rather than a rule, after Hawaii (Task 5) and North Carolina (Task
//  7), and this file is that decision made executable so it cannot quietly
//  evaporate the way a report does.
//
//  THE DECISION: Idaho ships NO `perSourceExemptions`. Its five `knownDefect`
//  blocks in statetax-2026-ID.golden.json STAY. Three new guard cases were ADDED,
//  and they are the deliverable: without them the wrong rules were available and
//  the suite would have gone green on them.
//
//  TWO BRANCHES, SETTLED DIFFERENTLY, and this is the distinction to carry away.
//  A rule naming `federalCivilian` or `ownStateOrLocal` is foreclosed
//  PROCEDURALLY. A rule naming `uniformedServices` ALONE is EXPRESSIBLE and was
//  DECLINED AS A JUDGEMENT CALL. Anyone reading this file as "Idaho is
//  impossible" has read it wrong, and the review that caught that reading is why
//  this paragraph exists.
//
//  WHY BRANCH 1 IS FORECLOSED. Idaho's Retirement Benefits Deduction is granted
//  to a CLOSED list whose membership turns on facts
//  `RetirementPlanClassification` does not carry: CSRS annuities where "the
//  employee must have established eligibility before 1984" (FERS is not on the
//  list and shares one picker row with CSRS), and PERSI FIREFIGHTERS plus certain
//  Idaho POLICE (not PERSI generally, which shares one picker row with them). The
//  case that would catch either over-match carries inputs byte-identical to an
//  existing fixture with a contradictory expected value, so Step 3 of the shared
//  procedure cannot be satisfied.
//
//  WHY BRANCH 2 WAS DECLINED, which is a different kind of reason. Line 8a
//  reduces the maximum dollar-for-dollar by Social Security and Railroad
//  Retirement RECEIVED, and nothing in the model carries that: measured, a single
//  military retiree at 65 with a $60,000 pension and $30,000 of Social Security
//  owes $934.60 where the rule would produce $0.00, and that is the common
//  household rather than an edge case. `exemptionAttribution: .household` also
//  lets an under-62 military spouse inherit a 62-plus spouse's gate, and the
//  accompanying `.none` rule must enumerate nine `PlanSource` cases by hand, so a
//  case added later falls silently INTO the pool. The first two ARE pinnable, so
//  a future task may legitimately decide differently; it should pin them first.
//
//  WHAT MAKES THIS MORE THAN AN OPINION, and the reason these tests exist: ALL
//  THREE candidate rules were MEASURED, following Task 5's standard, against the
//  really shipped config, and each was reverted.
//
//    1. A pooled `pensionExemption` of `.partial(48216)` at
//       `regularExemptionMinAge: 62` made ALL FIVE original cases pass (ID-1
//       correctly denied at 60; ID-2, ID-3, ID-4, ID-5 all reported as newly
//       matching their published form). It encodes 62 as the CIVILIAN gate, and
//       Part One's civilian gate is 65. The new ID-6 reported $0.00 against the
//       $1,266.70 Idaho requires. WRONG.
//
//    2. A `perSourceExemptions` rule of `matchSources: ["uniformedServices"]` at
//       `matchStructures: ["definedBenefit"]`, treatment `full`, made ID-3 pass.
//       It exempts military retired pay at EVERY age, because the engine applies
//       a matched rule "UNCONDITIONALLY (no age gate)" and `PerSourceExemptionRule`
//       has no age field. The new ID-7 reported $0.00 against $1,266.70. WRONG.
//
//    3. Arizona's actual shipped shape: the cap routed through the pool as
//       `.steppedPhaseoutByFilingStatus(48216, 72324, one 100% band)` at
//       `regularExemptionMinAge: 62`, plus ONE `.none` rule naming the nine
//       non-military `PlanSource` cases so only military retired pay stays
//       pooled. Measured: ID-3 GOES GREEN and nothing else moves. NOT WRONG, and
//       declined for the three reasons above. Task 8 did not evaluate this shape;
//       its review did, and the record was corrected rather than defended.
//
//  All three mutations were reverted. These tests reproduce their consequences
//  without shipping any of them.
//
//  THE POPULATION, which is the fact that decided it, and which is entailed by
//  the fixture's own quoted condition rather than imported from outside it: a
//  pre-1984 eligibility requirement means the qualifying CSRS class CLOSED IN
//  1984 and can never gain a member, while its complement has grown with every
//  federal civilian hire since. This is North Carolina's Bailey argument with
//  different dates, and it points the same way.
//
//  WHAT THIS FILE DOES NOT DO: it does not re-derive Idaho law. The golden
//  fixture is the specification, per the shared procedure, and its quoted Form
//  39R text is the only authority relied on here.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 5b Task 8: Idaho ships no per-source rule, and this is why")
struct Phase5bIdahoDecisionTests {

    /// The REAL shipped Idaho config, never a test-shaped stand-in.
    static var idahoExemptions: RetirementIncomeExemptions {
        StateTaxData.config(for: .idaho).retirementExemptions
    }

    /// The per-source rule Task 8 DECLINED to ship, reproduced here and nowhere
    /// else so its consequences can be asserted without any of them reaching a
    /// user. This is the narrowest shape that gives ID-3 its lenient Line 8e
    /// gate, and it is still wrong, because the gate it gives is "always".
    static let declinedMilitaryRule = PerSourceExemptionRule(
        matchSources: [.uniformedServices],
        matchStructures: [.definedBenefit],
        treatment: .full
    )

    /// Idaho's flat rate, from the shipped config's own `taxSystem`.
    static let idahoFlatRate = 0.053

    /// The measured Idaho tax for a single 70-year-old with a $50,000 pension
    /// and no exclusion of any kind: the $50,000 less the age-70 federal
    /// standard deduction ($16,100 base + $2,050 age-65 addition + $6,000 full
    /// OBBBA senior bonus = $24,150), times the flat 5.3%. Idaho's
    /// `stateDeduction` is `conformsToFederal`, so this is the same arithmetic
    /// ID-2's citation performs at its own age and amount.
    static let unexcludedIdahoTax = 1_370.05

    // MARK: - The decision itself

    @Test("Idaho ships no per-source exemption rule")
    func idahoShipsNoPerSourceRule() {
        #expect(Self.idahoExemptions.perSourceExemptions.isEmpty,
                """
                Idaho now ships a per-source rule. Before assuming that is wrong, note \
                that Task 8's two branches were settled DIFFERENTLY, and only one of them \
                is foreclosed.

                A rule naming federalCivilian or ownStateOrLocal is foreclosed \
                PROCEDURALLY: Idaho's list is CSRS with eligibility established before \
                1984 (not FERS, which shares one picker row with it) and PERSI \
                firefighters plus certain police (not PERSI generally, which shares one \
                row with them), so the case that would catch the over-match has inputs \
                byte-identical to ID-2's and a contradictory expected value. Step 3 cannot \
                be satisfied. See noIdahoGoldenCaseCanCatchTheFERSOverMatch.

                A rule naming uniformedServices ALONE is EXPRESSIBLE and was declined as a \
                JUDGEMENT CALL, not foreclosed. Measured, it makes ID-3 green and moves \
                nothing else. It was declined because Line 8a's dollar-for-dollar \
                reduction by Social Security and Railroad Retirement RECEIVED is \
                unmodelled (about $935 a year of under-taxation for a common household), \
                because exemptionAttribution .household lets an under-62 military spouse \
                inherit a 62-plus spouse's gate, and because the accompanying .none rule \
                must enumerate nine PlanSource cases by hand. All three are recorded in \
                the ID entry of GoldenScenarioDefectCatalogueTests.knownButUnpinned, and \
                the first two ARE pinnable. If you are shipping this rule, pin them first.
                """)
    }

    /// Task 3b's `rulesAndDisclosuresStayInLockstep` is bidirectional, so this is
    /// not merely a second way of saying the test above. The sentence would also
    /// be FALSE for Idaho, for the reason Tasks 5 and 7 gave for Hawaii and North
    /// Carolina: `UnclassifiedPensionDisclosure` warns that a pension is
    /// UNCLASSIFIED, and that is not Idaho's problem. An Idaho pension can be
    /// perfectly classified by a user who answered every picker question
    /// correctly and still be taxed wrongly, because the facts Form 39R Part Two
    /// needs are not on the classification at all.
    @Test("Idaho ships no unclassified-pension disclosure sentence either")
    func idahoShipsNoDisclosureSentence() {
        #expect(Self.idahoExemptions.unclassifiedPensionDisclosure == nil,
                """
                Idaho now ships an unclassifiedPensionDisclosure sentence with no rule to \
                go with it. Phase 5b Task 3b's lockstep sweep will fail on this. The \
                sentence would also be false for Idaho: it tells a user their exclusion is \
                waiting on classification, and Idaho's is not.
                """)
        #expect(UnclassifiedPensionDisclosure.text(for: .idaho, scope: .stateComparisonFigure) == nil)
        #expect(UnclassifiedPensionDisclosure.text(for: .idaho, scope: .cpaBriefingPlan) == nil)
    }

    /// Idaho grants nothing today, which is what the four pinned defects record.
    /// Asserted directly so that a pooled exemption arriving through the config,
    /// which is the shape of declined rule 1 and would NOT be caught by
    /// `idahoShipsNoPerSourceRule` above, still fails a test.
    @Test("Idaho's pooled pension exemption is still none, and still ungated")
    func idahoShipsNoPooledExemptionEither() {
        if case .none = Self.idahoExemptions.pensionExemption {} else {
            Issue.record("""
                Idaho now ships a pooled pensionExemption. TWO different rules have this \
                shape and they are not equally wrong.

                Declined rule 1, `.partial(48216)` at `regularExemptionMinAge: 62` with NO \
                per-source rules, is simply WRONG: measured, it made all five original \
                golden cases pass while encoding 62 as the CIVILIAN gate, when Form 39R \
                Part One's civilian gate is 65. ID-6 is the case that catches it.

                Declined rule 3 is DEFENSIBLE and was a judgement call: the same pool as \
                `.steppedPhaseoutByFilingStatus(48216, 72324, one 100% band)` at \
                `regularExemptionMinAge: 62`, PLUS a `.none` rule naming the nine \
                non-military PlanSource cases so only military retired pay remains \
                pooled. That one makes ID-3 green and moves nothing else. If that is what \
                just arrived, this test is the wrong thing to fix: read the ID entry in \
                GoldenScenarioDefectCatalogueTests.knownButUnpinned for the three reasons \
                it was declined (unmodelled Social Security offset, household attribution, \
                hand-enumerated denial list) and pin the first two before shipping.
                """)
        }
        #expect(Self.idahoExemptions.regularExemptionMinAge == 0,
                """
                Idaho's regularExemptionMinAge moved off 0. With pensionExemption at \
                .none this changes no tax, but it is half of both declined pooled rules \
                and should not arrive on its own.
                """)
    }

    // MARK: - Why the military rule could not be narrowed

    /// The Step 3 question ("what would this wrongly match?") for declined rule
    /// 2, answered as an assertion. Swept over `PlanSource.allCases` so the
    /// answer stays complete when a later task adds a case.
    @Test("The declined military rule matches exactly the one source it names, and no others",
          arguments: PlanSource.allCases)
    func theDeclinedMilitaryRuleMatchesOnlyWhatItNames(source: PlanSource) {
        let matched = Self.declinedMilitaryRule.matches(structure: .definedBenefit, source: source)
        #expect(matched == (source == .uniformedServices),
                """
                \(source): the declined military rule now matches \(matched), expected \
                \(source == .uniformedServices). If PerSourceExemptionRule.matches changed \
                its containment semantics, Task 8's reasoning needs re-checking rather than \
                this expectation being edited.
                """)
    }

    /// SUPERSEDED BY TASK 9, AND THE TRIPWIRE THAT SUPERSEDED IT WORKED.
    ///
    /// Task 8 declined Idaho's military rule partly because
    /// `PerSourceExemptionRule` carried no age dimension, and asserted that
    /// structurally, by reflection, so it would FAIL the day someone added an
    /// age field. Task 9 added `matchMinAge` (for D.C. Code Section
    /// 47-1803.02(a)(2)(N)(ii), whose survivor exclusion starts at 62) and this
    /// test fired on the first full-suite run, exactly as designed.
    ///
    /// IDAHO WAS RE-OPENED AND RE-MEASURED rather than silenced. Task 9
    /// temporarily shipped declined rule 2 in its now-expressible form,
    /// `matchSources: ["uniformedServices"]`, `matchStructures: ["definedBenefit"]`,
    /// `matchMinAge: 62`, treatment `full`, against the really shipped Idaho
    /// config, and reverted it. Measured result: ID-3 GOES GREEN at its
    /// published $0.00, and NOTHING ELSE MOVES. ID-7 (military, age 55) stays
    /// correctly denied, and ID-1 and ID-6 (civilians at 60 and 63) are
    /// untouched, because `matchMinAge` gates the rule and not the pool.
    ///
    /// TWO OF TASK 8's THREE OBJECTIONS TO THAT RULE ARE NOW GONE. The age gate
    /// exists. And the household-attribution objection ("an under-62 military
    /// spouse inherits a 62-plus spouse's gate") is gone too, because
    /// `matchMinAge` is evaluated against the ROW OWNER's own age rather than
    /// the household maximum every pooled gate uses; see
    /// `PerSourceExemptionRule.matchMinAge`.
    ///
    /// THE DECISION STILL HOLDS, on the one surviving objection, which is the
    /// cap. Form 39R Line 8a is a CAPPED deduction ($48,216 single / $72,324
    /// MFJ) reduced dollar-for-dollar by Social Security and Railroad
    /// Retirement RECEIVED. `treatment: full` is uncapped, and a `.partial`
    /// per-source treatment is banned phase-wide because `treatment` is
    /// evaluated inside the engine's per-row loop and would cap PER ROW. So the
    /// rule over-exempts a military pension above the maximum, and over-exempts
    /// every military household receiving Social Security. Task 8 measured that
    /// second one: $934.60 owed against $0.00 produced, for a single retiree at
    /// 65 with a $60,000 pension and $30,000 of Social Security.
    ///
    /// Unlike the FERS over-match below, BOTH of those ARE pinnable: neither
    /// case's inputs collide with an existing fixture. So Step 3 of the shared
    /// procedure ("if the fixture set has no case that would catch that, ADD
    /// one") is satisfiable for Idaho, and shipping this rule requires adding
    /// them, at which point the rule fails them. That is why Task 9 did not
    /// ship it either.
    ///
    /// The reflection assertion is KEPT and re-pointed at the surviving
    /// blocker, so it fails the day a capped-but-not-per-row treatment or a
    /// Social-Security-offset field arrives, which is the next day Idaho should
    /// be revisited.
    @Test("The per-source age gate now exists; Idaho's surviving blocker is the capped, SS-reduced maximum")
    func theDeclinedMilitaryRuleNowHasAnAgeGateButStillNoCap() {
        let fields = Set(Mirror(reflecting: Self.declinedMilitaryRule).children.compactMap(\.label))
        #expect(fields == ["matchSources", "matchStructures",
                           "matchIsSurvivorBenefit", "matchMinAge", "treatment"],
                """
                PerSourceExemptionRule's stored properties are now \(fields). Task 9 left \
                them at matchSources / matchStructures / matchIsSurvivorBenefit / \
                matchMinAge / treatment. If a field arrived that can express Form 39R Line \
                8a's HOUSEHOLD-level maximum, or its dollar-for-dollar reduction by Social \
                Security and Railroad Retirement received, re-open Idaho a third time: \
                those two are the only objections left, both are pinnable, and Step 3 \
                requires the catching cases be ADDED before any such rule ships.
                """)

        // The age gate that arrived is genuinely usable for Line 8e, not merely
        // present: a rule carrying it denies at 61 and grants at 62, and a row
        // whose owner's age is unknown is denied rather than granted.
        let gated = PerSourceExemptionRule(
            matchSources: [.uniformedServices], matchStructures: [.definedBenefit],
            matchMinAge: 62, treatment: .full)
        #expect(!gated.matches(structure: .definedBenefit, source: .uniformedServices, age: 61))
        #expect(gated.matches(structure: .definedBenefit, source: .uniformedServices, age: 62))
        #expect(!gated.matches(structure: .definedBenefit, source: .uniformedServices, age: nil),
                """
                A gated rule matched a row whose owner's age is unknown. That direction \
                matters: it must fail CLOSED (no exclusion, taxpayer over-taxed) rather \
                than open.
                """)

        // And it is still true that `treatment` cannot carry the cap, which is
        // what actually keeps Idaho unshipped.
        if case .partial = Self.declinedMilitaryRule.treatment {
            Issue.record("""
                The declined Idaho rule now carries a capped per-source treatment. That is \
                banned phase-wide: `treatment` is evaluated inside the engine's per-row \
                loop, so a `.partial` caps PER PENSION ROW rather than per household. \
                Phase3bPerSourceExemptionCapTests is the sweep that enforces it.
                """)
        }
    }

    /// The second, INDEPENDENT blocker, which survives even if both eligibility
    /// conditions and an age gate became expressible.
    ///
    /// Idaho's Line 8a cap is ONE household maximum shared by civilian and
    /// military benefits, and the two carry different age gates. A pooled
    /// `pensionExemption` carries exactly one cap and one `regularExemptionMinAge`;
    /// `earlyAgeTier` adds a second age band but it is SOURCE-BLIND, so lowering
    /// the gate to 62 for the service member lowers it for the civilian too,
    /// which is declined rule 1. And a per-source rule cannot carry the cap,
    /// because `treatment` is evaluated inside the engine's per-row loop and a
    /// `.partial` there caps PER PENSION ROW rather than per household, which is
    /// banned phase-wide.
    ///
    /// Asserted against the model rather than the config, so it stays true while
    /// Idaho ships nothing.
    @Test("One pool carries one cap and one age gate, so Idaho's two gates cannot share it")
    func theTwoAgeGatesCannotShareTheOneCap() {
        let exemptions = RetirementIncomeExemptions()
        let fields = Set(Mirror(reflecting: exemptions).children.compactMap(\.label))

        // The WHOLE stored-property set, not a count of one name. A second age
        // gate would arrive as a NEW, differently named property, which a
        // `filter { $0 == "regularExemptionMinAge" }.count == 1` check could
        // never see: that only catches a rename. Review MINOR 1.
        let known: Set<String> = [
            "socialSecurityExempt", "pensionExemption", "iraWithdrawalExemption",
            "exemptionAppliesPerIndividual", "regularExemptionMinAge",
            "exemptionAttribution", "distributionMinAge", "earlyAgeTier",
            "pensionAndIRAShareSingleCap", "otherRetirementIncomeExclusion",
            "agiPhaseout", "rothConversionExemption", "capitalGainsTreatment",
            "perSourceExemptions", "unclassifiedPensionDisclosure"
        ]
        #expect(fields == known,
                """
                RetirementIncomeExemptions' stored properties changed. Added: \
                \(fields.subtracting(known)). Removed: \(known.subtracting(fields)).

                Task 8 relied on this type carrying exactly ONE pooled pension cap \
                (`pensionExemption`) and exactly ONE regular age gate \
                (`regularExemptionMinAge`), because Idaho needs TWO gates (Part One's 65 \
                for civilians, Line 8e's 62 for retired service members) over ONE shared \
                Line 8a cap. If a second age gate or a second cap was just added, re-open \
                Idaho against it. If the change is unrelated, add the property here.
                """)

        // And the only second age dimension, `earlyAgeTier`, is source-blind:
        // it carries an age range and a level, and no source dimension to
        // restrict it to service members.
        let tier = RetirementIncomeExemptions.AgeTier(ageRange: 62...64, level: .full)
        let tierFields = Mirror(reflecting: tier).children.compactMap(\.label)
        #expect(Set(tierFields) == ["ageRange", "level"],
                """
                AgeTier's stored properties are now \(tierFields). Task 8 relied on it \
                being SOURCE-BLIND: an earlyAgeTier of 62...64 would hand Idaho's lenient \
                service-member gate to a 63-year-old CIVILIAN too, which is exactly what \
                ID-6 forbids. If a source dimension was added, re-open Idaho.
                """)
    }

    // MARK: - Why no golden case could have caught the eligibility over-match

    /// The blocker that forecloses shipping PROCEDURALLY rather than as a
    /// judgement call, proven from the fixture's own data.
    ///
    /// Step 3 says: "what would this wrongly match? If the fixture set has no
    /// case that would catch that, ADD one." The case that would catch a
    /// `federalCivilian` rule is a FERS retiree at 65 or older, who is fully
    /// taxable in Idaho. Its inputs are byte-identical to ID-2's, with a
    /// contradictory `expectedStateTax`. A fixture can assert one or the other,
    /// never both, so Step 3 cannot be satisfied.
    @Test("No Idaho golden case can catch the FERS over-match, so Step 3 cannot be satisfied")
    func noIdahoGoldenCaseCanCatchTheFERSOverMatch() throws {
        let file = try GoldenScenario.load(abbreviation: "ID")

        // Every all-federalCivilian household at 65 or over whose pensions sit
        // UNDER the deduction maximum expects $0.00. A FERS household at the
        // same shape expects a positive tax, on inputs this fixture format
        // cannot tell apart from these.
        //
        // The cap filter is load-bearing and was added when ID-8 was: ID-8 is an
        // all-federalCivilian household at 68/70 that expects a POSITIVE
        // $1,069.33, but for a reason that has nothing to do with source. Its
        // $140,000 of pensions exceeds the $72,324 MFJ maximum, so tax survives
        // the deduction. Including it here would have made this test read as
        // "Idaho already distinguishes CSRS from FERS", which is false.
        let uncappedCivilianAtOrOver65 = file.scenarios.filter { scenario in
            let rows = scenario.classifiedPensionSources ?? []
            let total = rows.reduce(0.0) { $0 + $1.amount }
            let maximum = scenario.filingStatus == "marriedFilingJointly" ? 72_324.0 : 48_216.0
            return scenario.primaryAge >= 65 && !rows.isEmpty && total <= maximum
                && rows.allSatisfy { $0.planSource == PlanSource.federalCivilian.rawValue }
        }
        #expect(!uncappedCivilianAtOrOver65.isEmpty,
                "ID-2 and ID-4 are the federal-civilian households this blocker is about; they are gone.")
        #expect(uncappedCivilianAtOrOver65.allSatisfy { $0.expectedStateTax == 0.0 },
                """
                An Idaho golden case now asserts a TAXABLE all-federalCivilian household at \
                65 or over whose pensions are UNDER the deduction maximum, alongside the \
                exempt ones: \(uncappedCivilianAtOrOver65.map(\.name)). Those inputs are \
                identical, so either something can now distinguish CSRS from FERS, in which \
                case Task 8's decision should be revisited against it, or a fixture is \
                asserting a fact its own inputs do not carry.
                """)

        // And every one of them still carries a knownDefect. A green suite must
        // not be readable as "Idaho is fine".
        #expect(uncappedCivilianAtOrOver65.allSatisfy { $0.knownDefect != nil },
                """
                An Idaho CSRS case lost its knownDefect block without a rule shipping. \
                Idaho still grants no Retirement Benefits Deduction at all.
                """)
    }

    // MARK: - The two guard cases this task added, which are its deliverable

    /// ID-6, the discriminating case Phase 4 asked for. Without it, declined
    /// rule 1 was a green suite.
    ///
    /// It is ID-3's inputs with ONE field changed, and that is the point: at the
    /// same age 63 Idaho denies the civilian and allows the service member, and
    /// the two became separable only because Task 1 added `uniformedServices` and
    /// Task 8 re-labelled ID-3 onto it. While they shared `federalCivilian` they
    /// demanded contradictory answers from one enum case.
    @Test("The discriminating civilian-at-63 case exists, is taxable, and carries no knownDefect")
    func theDiscriminatingCivilianCaseStaysInTheFixture() throws {
        let file = try GoldenScenario.load(abbreviation: "ID")
        let civilian63 = try #require(
            file.scenarios.first { scenario in
                scenario.primaryAge == 63
                    && (scenario.classifiedPensionSources ?? []).allSatisfy {
                        $0.planSource == PlanSource.federalCivilian.rawValue
                    }
                    && !(scenario.classifiedPensionSources ?? []).isEmpty
            },
            """
            Idaho's civilian-at-63 case is gone. It is the ONLY case in the file that \
            separates a 62 age gate from a 65 one: measured, a pooled exemption at \
            regularExemptionMinAge 62 passes every other Idaho case. Phase 4 flagged this \
            exact hole and Task 8 filled it. Restore it.
            """)

        #expect(civilian63.expectedStateTax == 1_266.70,
                """
                The civilian-at-63 case expects \(civilian63.expectedStateTax). Form 39R \
                Part One requires age 65, or 62 AND disabled; at 63 and not disabled this \
                taxpayer deducts nothing, so the answer is the fully taxed $1,266.70.
                """)
        #expect(civilian63.knownDefect == nil,
                """
                The civilian-at-63 case gained a knownDefect. The engine is CORRECT here \
                today and must stay correct: a defect block would mean Idaho had started \
                granting the deduction below 65.
                """)
    }

    /// ID-7, the guard against declined rule 2. Without it, an ungated
    /// `uniformedServices -> full` rule was a green suite.
    ///
    /// The population this protects is not marginal: a service member retiring at
    /// twenty years is routinely in their early forties, so the ungated rule
    /// would be wrong for most military retirees for about two decades each, in
    /// the under-taxation direction.
    @Test("The military-under-62 guard case exists, is taxable, and carries no knownDefect")
    func theMilitaryUnderAgeGuardStaysInTheFixture() throws {
        let file = try GoldenScenario.load(abbreviation: "ID")
        let military55 = try #require(
            file.scenarios.first { scenario in
                scenario.primaryAge < 62
                    && !(scenario.classifiedPensionSources ?? []).isEmpty
                    && (scenario.classifiedPensionSources ?? []).allSatisfy {
                        $0.planSource == PlanSource.uniformedServices.rawValue
                    }
            },
            """
            Idaho's military-under-62 guard case is gone. It is what fails if a future \
            Idaho rule grants uniformedServices an exemption with no age gate, which is \
            the only shape PerSourceExemptionRule can currently express. Restore it.
            """)

        #expect(military55.expectedStateTax > 0,
                """
                The military-under-62 guard expects \(military55.expectedStateTax). Form \
                39R Line 8e is more lenient than Part One but not ageless: at 55 and not \
                disabled this retiree deducts nothing. A zero here means an ungated \
                military rule has shipped.
                """)
        #expect(military55.knownDefect == nil,
                """
                The military-under-62 guard gained a knownDefect. The engine is CORRECT \
                here today and must stay correct.
                """)
    }

    /// ID-8, the cap guard, added by Task 8's review. The third indistinguishability
    /// this task found and the only one that turned out to be PINNABLE.
    ///
    /// ID-4 is named a cap straddle but cannot test one: at its $80,000 of
    /// pensions, taxable income before the deduction is $32,500, so it floors at
    /// $0.00 whether the deduction is capped at $72,324 or left uncapped. ID-8
    /// raises the pensions to $140,000 so the difference reaches the tax line:
    /// $1,069.33 capped against $0.00 uncapped.
    @Test("The cap guard case exists and separates a capped deduction from an uncapped one")
    func theCapGuardCaseStaysInTheFixture() throws {
        let file = try GoldenScenario.load(abbreviation: "ID")
        let capCase = try #require(
            file.scenarios.first { scenario in
                (scenario.classifiedPensionSources ?? []).reduce(0) { $0 + $1.amount } > 100_000
            },
            """
            Idaho's cap guard case is gone. It is the ONLY Idaho case where the $72,324 \
            MFJ maximum changes the answer: every other case floors taxable income at \
            $0.00 whether the deduction is capped or not, so an UNCAPPED rule passes all \
            of them. Restore it.
            """)

        #expect(capCase.expectedStateTax == 1_069.33,
                """
                The cap guard expects \(capCase.expectedStateTax). Form 39R Line 8a caps \
                the MFJ deduction at $72,324, so $92,500 of post-standard-deduction income \
                less $72,324 leaves $20,176 at the 5.3% flat rate.
                """)
        let defect = try #require(capCase.knownDefect,
                                  """
                                  The cap guard lost its knownDefect block. Idaho grants no \
                                  Retirement Benefits Deduction at all, so this case is still \
                                  over-taxed; a missing block would mean a rule shipped.
                                  """)
        #expect(defect.observedToday == 4_902.50,
                """
                The cap guard's pinned observedToday moved to \(defect.observedToday). \
                MEASURED at $4,902.50, the whole $92,500 at 5.3%. Diagnose what changed \
                before touching this pin.
                """)
    }

    /// ID-3's re-label, asserted rather than trusted. Task 8 owed this, and the
    /// fixture's own prose previously carried the instruction forward as a TODO.
    @Test("ID-3 carries uniformedServices, and is the only Idaho case at 63 that does")
    func theMilitaryCaseWasRelabelled() throws {
        let file = try GoldenScenario.load(abbreviation: "ID")
        let military63 = try #require(
            file.scenarios.first { scenario in
                scenario.primaryAge == 63 && (scenario.classifiedPensionSources ?? []).allSatisfy {
                    $0.planSource == PlanSource.uniformedServices.rawValue
                } && !(scenario.classifiedPensionSources ?? []).isEmpty
            },
            """
            Idaho's military case at 63 no longer carries uniformedServices. Task 8 \
            re-labelled it off federalCivilian precisely so that it and the civilian case \
            at the same age stop demanding contradictory answers from one enum case.
            """)
        #expect(military63.expectedStateTax == 0.0)
        #expect(military63.knownDefect != nil,
                """
                ID-3 lost its knownDefect block. Idaho ships no rule matching \
                uniformedServices, so this case is still over-taxed and the re-label \
                changed no number.
                """)
    }

    // MARK: - The decision stays inert, and the mirror agrees

    /// "Provably inert" for a task that ships no rule means the classification a
    /// user records has no effect on their Idaho tax, and that the
    /// income-breakdown mirror agrees with the tax computation for every one of
    /// them. Swept over `PlanSource.allCases`, because `DataManager.stateTaxBreakdown`
    /// hand-duplicates the engine's per-source partition and has drifted from it
    /// five times on this branch.
    ///
    /// This is also what proves the ID-3 RE-LABEL was value-neutral:
    /// `federalCivilian` and `uniformedServices` both appear in this sweep at the
    /// same figure.
    @MainActor
    @Test("Classification changes nothing for an Idaho resident, and the breakdown mirror agrees",
          arguments: PlanSource.allCases)
    func idahoIsUnaffectedByClassification(source: PlanSource) {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 70; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .idaho
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: source)
        ]

        let breakdown = dm.stateTaxBreakdown(forState: .idaho, filingStatus: .single)
        let computed = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .idaho, filingStatus: .single,
            taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)

        #expect(abs(breakdown.totalStateTax - computed) < 0.01,
                """
                ID / \(source): the income-breakdown display reports \
                \(breakdown.totalStateTax) while the tax computation reports \(computed). \
                DataManager's per-source partition has drifted from \
                TaxCalculationEngine.applyRetirementExemptions.
                """)
        #expect(abs(breakdown.pensionExemptAmount) < 0.01,
                """
                ID / \(source): the breakdown attributes \(breakdown.pensionExemptAmount) \
                of pension exclusion. Idaho ships no rule, so every source must attribute \
                zero. This is the assertion that catches a Retirement Benefits Deduction \
                arriving through the mirror rather than through the config.
                """)
        #expect(abs(computed - Self.unexcludedIdahoTax) < 0.01,
                """
                ID / \(source): expected the unexcluded \(Self.unexcludedIdahoTax), got \
                \(computed). Every classification must reach the same figure, which is \
                what makes this task inert and what made the ID-3 re-label value-neutral.
                """)
    }

    /// Task 7 found a REACHABLE divergence in North Carolina between the two
    /// paths military retired pay can take, and the Task 8 brief asked whether
    /// Idaho lands the same way. It does NOT, and that is worth pinning rather
    /// than merely reporting.
    ///
    /// `MilitaryRetirementExemption` gates on `IncomeSource.type ==
    /// .militaryRetirement`, while the picker's "Military retired pay" row writes
    /// `(definedBenefit, uniformedServices)` onto a `.pension` row. For North
    /// Carolina those two disagree. For Idaho both say FULLY TAXABLE, so the two
    /// paths AGREE and Task 8 created no third answer.
    ///
    /// They agree on the WRONG answer: Form 39R Line 8e grants the deduction from
    /// age 62 and Idaho grants nothing on either path. That defect is already
    /// pinned by ID-3, so it needs no catalogue entry; what this test protects is
    /// that a future Idaho military rule must move BOTH paths together.
    @MainActor
    @Test("Idaho's two military paths agree, both fully taxable, and must move together")
    func theTwoMilitaryPathsAgreeForIdaho() {
        // Path 1: by income TYPE. Idaho's entry in the shipped table.
        #expect(MilitaryRetirementExemption.stateTaxableAmount(
            gross: 50_000, stateCode: "ID", age: 70) == 50_000,
                """
                MilitaryRetirementExemption no longer treats Idaho military retired pay as \
                fully taxable. If that changed, it has diverged from the classified path \
                below, which is the North Carolina defect (see the NC entries in \
                GoldenScenarioDefectCatalogueTests.knownButUnpinned). Move both together.
                """)

        // Path 2: by CLASSIFICATION. Also taxed in full, because Idaho ships no
        // rule.
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - 70; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .idaho
        dm.incomeSources = [
            IncomeSource(name: "Military pension", type: .pension, annualAmount: 50_000,
                         owner: .primary, planStructure: .definedBenefit,
                         planSource: .uniformedServices)
        ]
        let classified = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .idaho,
            filingStatus: .single, taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)

        #expect(abs(classified - Self.unexcludedIdahoTax) < 0.01,
                """
                The classified Idaho military path now reports \(classified) rather than \
                \(Self.unexcludedIdahoTax). If an Idaho uniformedServices rule shipped, \
                check it against ID-7 first: an ungated rule exempts military retired pay \
                below Line 8e's own age 62, and MilitaryRetirementExemption's Idaho entry \
                must be updated in the same change or the two paths will diverge.
                """)
    }

    // MARK: - The record that outlives this file

    /// The deletion guard. This test fails if the catalogue entry is removed, so
    /// a future green suite cannot mean "Idaho is fine". Task 6 shipped an entry
    /// without this guard and was caught; Tasks 5 and 7 shipped one each.
    @Test("Idaho's Retirement Benefits Deduction gap stays recorded as a known-but-unpinned defect")
    func theIdahoDeductionGapStaysRecorded() throws {
        let entry = try #require(
            GoldenScenarioDefectCatalogueTests.knownButUnpinned.first { $0.state == "ID" },
            """
            Idaho's Retirement Benefits Deduction gap is no longer recorded. Either the \
            eligibility axes were actually added, in which case this whole file should be \
            replaced by golden cases for the CSRS and FERS households, or a real, cited \
            over-taxation was silently dropped from the catalogue.
            """)
        #expect(entry.blockedOn.contains("NOT EXPRESSIBLE AS A GOLDEN CASE"))
        #expect(entry.summary.contains("1984"),
                """
                The ID entry no longer records the pre-1984 CSRS eligibility condition, \
                which is the fact that closed the qualifying class and decided this task.
                """)
    }

    // MARK: - The disclosure that ships with this decision

    /// The Income Sources caption, APPROVED by John on 2026-08-05 as written,
    /// together with North Carolina's.
    ///
    /// Idaho is the second jurisdiction this phase touched with ZERO disclosure
    /// on any surface, and for a structural reason worth stating: both existing
    /// disclosure surfaces gate on the jurisdiction SHIPPING RULES.
    /// `shouldPromptForClassification` requires `residenceHasPerSourceRules`, and
    /// `UnclassifiedPensionDisclosure.text` requires the config sentence, which is
    /// in lockstep with the rules. So a jurisdiction that ships no rule because
    /// its law is inexpressible is exactly the jurisdiction whose users are told
    /// nothing, which is the wrong way round.
    ///
    /// The DIRECTION word is load-bearing, as in Hawaii's and North Carolina's.
    /// Idaho applies no part of the deduction, so every error runs toward
    /// over-taxation and "understated" would be false.
    @MainActor
    @Test("Idaho's Income Sources caption ships and names the right direction")
    func idahoCaptionNamesTheRightDirection() {
        let text = IncomeSourcesView.idahoRetirementBenefitsDeductionCaption
        #expect(text.contains("Idaho"))
        #expect(text.contains("overstated"),
                """
                Idaho's caption no longer says the tax may be OVERSTATED. Idaho applies no \
                Retirement Benefits Deduction at all, so every error runs toward \
                over-taxation; understated would be false. A copy edit that harmonised this \
                with the Massachusetts caption would invert it.
                """)
        #expect(!text.contains("understated"))
        #expect(text.contains("62") && text.contains("65"),
                """
                Idaho's caption no longer names both age gates. Naming only one is what \
                makes a reader unable to tell whether it applies to them: the civilian gate \
                is 65 and the retired-service-member gate is 62, and the gap between them is \
                the whole subject of ID-6.
                """)
        // Written as escapes rather than as the literal characters, unlike the
        // otherwise-identical line in Phase5bNorthCarolinaDecisionTests, so that
        // this phase's "no em dash characters anywhere" constraint holds even
        // under a mechanical grep of the source. Same assertion, same two
        // characters: U+2014 EM DASH and U+2013 EN DASH.
        #expect(!text.contains("\u{2014}") && !text.contains("\u{2013}"),
                "no em or en dash in user-facing copy")
    }

    // MARK: - Picker reachability

    /// A rule no real user can select is a green suite and an undelivered fix, so
    /// the brief asks this even of a task that ships no rule. For Idaho it
    /// establishes that the two over-matching rows ARE reachable, which is what
    /// makes the over-match a real user-facing risk rather than a fixture
    /// artifact, and that the row ID-3 was re-labelled onto is reachable too.
    @Test("An Idaho user can reach the rows the decision turns on")
    func idahoUserCanReachTheRowsTheDecisionTurnsOn() {
        #expect(!PlanClassificationChoice.residenceNamesItsOwnJurisdiction(.idaho),
                """
                Idaho's config now names its own jurisdiction, which suppresses the generic \
                own-state row for Idaho residents. An Idaho PERSI retiree would then have no \
                way to describe their own pension.
                """)
        let options = PlanClassificationChoice.options(for: .idaho, selected: nil)

        // The two rows whose over-breadth decided the task.
        #expect(options.contains(.federalCivilianPension),
                """
                The federal-civilian row is no longer offered to an Idaho resident. It is \
                the single row BOTH a CSRS and a FERS retiree must select, which is the \
                indistinguishability this task turns on.
                """)
        #expect(options.contains(.ownStateGovernmentPension),
                """
                The own-state row is no longer offered to an Idaho resident. It is the \
                single row an Idaho PERSI firefighter (who qualifies) and an Idaho PERSI \
                teacher (who does not) must both select.
                """)

        // And the row the re-label depends on.
        #expect(options.contains(.uniformedServicesPension),
                """
                The military row is no longer offered to an Idaho resident. ID-3 and ID-7 \
                both carry uniformedServices precisely because a real user can select it.
                """)

        // Idaho ships no rules, so the classification prompt stays silent. This
        // is the gap the caption exists to fill, asserted so that the caption
        // cannot be deleted as redundant.
        #expect(!PlanClassificationChoice.residenceHasPerSourceRules(.idaho),
                "Idaho ships no per-source rules, so no classification prompt fires.")
        let unclassified = IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000,
                                        owner: .primary, planStructure: .unknown,
                                        planSource: .unknown)
        #expect(!PlanClassificationChoice.shouldPromptForClassification(
            source: unclassified,
            residenceHasPerSourceRules: PlanClassificationChoice.residenceHasPerSourceRules(.idaho)),
                """
                Idaho now prompts for classification. If an Idaho rule shipped, this whole \
                file needs revisiting; if not, the prompt is firing for a state where \
                classification cannot change the answer.
                """)
    }
}
