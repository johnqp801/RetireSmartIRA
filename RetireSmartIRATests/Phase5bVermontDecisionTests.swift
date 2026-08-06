//
//  Phase5bVermontDecisionTests.swift
//  RetireSmartIRATests
//
//  Phase 5b Task 9: Vermont. The fourth task in this phase whose deliverable is
//  a DECISION rather than a rule, after Hawaii (Task 5), North Carolina (Task 7)
//  and Idaho (Task 8), and this file is that decision made executable so it
//  cannot quietly evaporate the way a report does.
//
//  THE DECISION: Vermont ships NO `perSourceExemptions`, no `pensionExemption`
//  and no `agiPhaseout`. Its six `knownDefect` blocks in
//  statetax-2026-VT.golden.json STAY. A picker caption was ADDED, because
//  Vermont's gap is the largest in this phase and a Vermont resident sees
//  nothing about it on any other surface.
//
//  **DECIDED BY JOHN ON 2026-08-05: HOLD.** The recommendation was unanimous
//  across implementer, reviewer and controller, and John accepted it. Vermont
//  keeps its six blocks BY DECISION rather than by default, alongside Hawaii,
//  North Carolina and Idaho, and its $5,211.50 gap at VT-6's shape is a known,
//  disclosed cost of that hold rather than an oversight. This file is the record
//  of a settled decision, not of an open question. Do not re-open it without new
//  model capability; the two shapes below are why.
//
//  THE PLAN ASKED A QUESTION AND THIS IS THE ANSWER. Task 9's own text says
//  Vermont and DC "were UNSATISFIABLE before Task 1 and they share the reason",
//  and that if either is still unsatisfiable after Task 1's model extension,
//  "that is the single most important finding of this phase". VERMONT IS STILL
//  UNSATISFIABLE. Task 1's extension was NECESSARY and it is NOT SUFFICIENT,
//  and the reason is that the source vocabulary was never the whole blocker.
//
//  WHAT TASK 1 DID FIX. Before `uniformedServices` existed, VT-1 (CSRS, capped
//  at $10,000) and VT-5 (military, uncapped) sat on the SAME
//  (federalCivilian, definedBenefit) pair demanding contradictory treatment, so
//  no rule could address one without addressing the other. Task 2 re-labelled
//  VT-5 and VT-6 onto `uniformedServices` and that collision is genuinely gone.
//
//  WHAT REMAINS, and neither part is about sources. FIRST, the model carries
//  ONE pooled cap (`pensionExemption`) and ONE `agiPhaseout` per jurisdiction,
//  and Vermont needs TWO exclusions with different caps AND different bands:
//  CSRS at $10,000 phasing out over $55,000-$65,000 single / $70,000-$80,000
//  MFJ, and military under Act 71 uncapped phasing out over $125,000-$175,000
//  for every filing status. A per-source rule cannot carry either band, because
//  a matched row is excluded outright and per-source exclusions are ADDED ON TOP
//  of the phased-out pool rather than being phased out themselves
//  (`DataManager.swift`: `pensionExemptAmt = perSourceExcludedPension +
//  (agiPhaseout?.reduced(...))`), and it cannot carry the CSRS cap either,
//  because a `.partial` treatment is evaluated inside the engine's per-row loop
//  and is banned phase-wide. SECOND, the CSRS exclusion applies "only to
//  benefits that are based on earnings not covered by the Social Security Act",
//  which `federalCivilian` cannot express: that case is documented as covering
//  "CSRS and FERS", and FERS earnings ARE Social-Security-covered.
//
//  BOTH CANDIDATE SHAPES WERE MEASURED, following Task 5's standard, against the
//  really shipped Vermont config, and both were reverted.
//
//    1. THE CSRS SHAPE, config-only, no production Swift. Pooled
//       `pensionExemption: .partial(10000)`, `agiPhaseout` linear at
//       `perDollar: 1.0`, plus two `.none` per-source rules leaving only
//       (federalCivilian, definedBenefit) in the pool. Measured: VT-1, VT-2,
//       VT-3 and VT-4 ALL FOUR WENT GREEN at their published $742.03,
//       $1,579.53, $1,316.55 and $981.55, with VT-5 and VT-6 still correctly
//       pinned. NOT WRONG ARITHMETICALLY, and declined on Hawaii's test: the
//       exclusion and the over-match come out of the same quoted sentence, and
//       the over-matched population (FERS) is LARGER than the served one (CSRS,
//       closed to new entrants since 1984) and growing. See
//       `theCSRSShapeOverMatchesFERSFromItsOwnQuotedLimiter` below.
//
//    2. THE MILITARY SHAPE, `matchSources: ["uniformedServices"]`,
//       `matchStructures: ["definedBenefit"]`, treatment `full`. Measured: VT-5
//       WENT GREEN at $0.00 and VT-6 MOVED OFF ITS PIN to $0.00 against the
//       pinned $8,086.65, failing as `pinnedDefectMoved`. WRONG, and the fixture
//       caught it exactly as the plan predicted it would.
//
//  A THIRD SHAPE EXISTS AND IS DEFERRED TO PHASE 6 RATHER THAN ABANDONED. Task 9
//  added `matchMinAge` to `PerSourceExemptionRule` for the District of Columbia.
//  An income-gated sibling, `matchMaxIncome`, would let the military rule
//  implement Act 71's quoted "adjusted gross income equal to or less than
//  $125,000, all military retirement and survivor benefit income is exempt"
//  exactly, turn VT-5 green, leave VT-6 correctly pinned, and introduce NO
//  under-taxation anywhere. It was not built here for one reason, and it is a
//  program-level decision rather than a Vermont one, which is why it is a Phase 6
//  model task rather than something that could be settled here: the phase-out
//  mechanism
//  gates on the income figure passed to `calculateStateTax`, which callers have
//  already reduced by the state standard deduction, so Vermont's config would
//  carry $117,150 where Act 71 says $125,000. `AGIPhaseout`'s own doc comment
//  flags that basis as unverified and defers it. Deciding it inside a
//  jurisdiction task, by writing a non-statutory number into a config file,
//  is the class of thing this program exists to catch. IF IT IS EVER BUILT, VT-7
//  GOES IN FIRST: AGI $130,000, expected $172.53. It is the only case that
//  discriminates the two readings of the basis, confirmed by review to yield
//  three distinct values. See the Task 9 report.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 5b Task 9: Vermont ships no per-source rule, and this is why")
struct Phase5bVermontDecisionTests {

    static var vermontExemptions: RetirementIncomeExemptions {
        StateTaxData.config(for: .vermont).retirementExemptions
    }

    /// The declined military rule, shape 2 above. Held here so the tests below
    /// reason about the real object rather than about prose.
    static let declinedMilitaryRule = PerSourceExemptionRule(
        matchSources: [.uniformedServices], matchStructures: [.definedBenefit], treatment: .full)

    /// The declined CSRS shape's pooled half, shape 1 above.
    static let declinedCSRSPoolCap: Double = 10_000

    // MARK: - The decision, asserted against the shipped config

    @Test("Vermont ships no per-source rule and no disclosure sentence")
    func vermontShipsNothing() {
        #expect(Self.vermontExemptions.perSourceExemptions.isEmpty,
                """
                Vermont now ships a per-source rule. Both shapes Task 9 measured were \
                declined: the CSRS shape over-matches FERS out of its own quoted limiter, \
                and the military shape moves VT-6 off its pin to $0.00 because a matched \
                per-source row is excluded in FULL and Act 71's phase-out band cannot be \
                expressed. If a rule arrived, it needs a golden case authorising it and \
                this file needs rewriting, not deleting.
                """)
        #expect(Self.vermontExemptions.unclassifiedPensionDisclosure == nil,
                """
                Vermont now ships an unclassifiedPensionDisclosure sentence with no rules. \
                `rulesAndDisclosuresStayInLockstep` is bidirectional and would fail this \
                too. A Vermont pension can be perfectly classified through the picker and \
                still be taxed wrongly, so that sentence would be false as well as \
                unpaired; the caption in IncomeSourcesView is the right surface.
                """)
    }

    /// The pooled half of the declined CSRS shape, asserted so it cannot arrive
    /// on its own. `pensionExemption` alone would grant $10,000 to any Vermont
    /// pension including a private one, which VT-4's own quoted source says is
    /// not eligible.
    @Test("Vermont ships no pooled pension exemption and no AGI phase-out either")
    func vermontShipsNoPooledMechanismEither() {
        if case .none = Self.vermontExemptions.pensionExemption {} else {
            Issue.record("""
                Vermont now ships a pooled pensionExemption. HALF of the declined CSRS \
                shape has this form and half of it is worse than none: without the two \
                accompanying `.none` per-source rules, a $10,000 exclusion reaches every \
                Vermont pension, including the private-employer pension VT-4's source \
                excludes by quoting "only to benefits that are based on earnings not \
                covered by the Social Security Act". Read this file's header before \
                fixing this test.
                """)
        }
        #expect(Self.vermontExemptions.agiPhaseout == nil,
                """
                Vermont now ships an agiPhaseout. It was the second half of the declined \
                CSRS shape, and Vermont would be the FIRST jurisdiction in the program to \
                ship one: `StateTaxPhase3aMechanismTests.noStateShipsAnAGIPhaseoutKey` \
                pins that. Its threshold basis is unresolved (see AGIPhaseout's own doc \
                comment), and no Vermont fixture distinguishes the candidate bases, so a \
                value shipped here would be unverifiable by construction.
                """)
    }

    // MARK: - Why the military rule could not be shipped as-is

    /// Step 3's question for the declined military rule, answered as an
    /// assertion and swept so the answer stays complete when a later task adds a
    /// `PlanSource` case.
    @Test("The declined military rule matches exactly the one source it names",
          arguments: PlanSource.allCases)
    func theDeclinedMilitaryRuleMatchesOnlyWhatItNames(source: PlanSource) {
        let matched = Self.declinedMilitaryRule.matches(structure: .definedBenefit, source: source)
        #expect(matched == (source == .uniformedServices),
                """
                \(source): the declined military rule matches \(matched), expected \
                \(source == .uniformedServices). The rule's SCOPE was never the problem; \
                its uncapped, unphased TREATMENT was.
                """)
    }

    /// THE HEART of why the military rule was declined, stated structurally
    /// rather than as prose: a matched per-source row is excluded in FULL, and
    /// nothing in the rule can reduce that by Act 71's phase-out fraction.
    ///
    /// VT-6 is the fixture that catches it, at AGI $150,000 where Act 71 retains
    /// exactly half of an uncapped exclusion. This reproduces the consequence
    /// without shipping the rule.
    @Test("A matched military row is excluded in full, which is wrong inside Act 71's phase-out band")
    func aMatchedRowIsExcludedInFullWithNoPhaseOut() throws {
        let file = try GoldenScenario.load(abbreviation: "VT")
        let vt6 = try #require(file.scenarios.first { $0.name.contains("AGI $150,000") })

        // The fixture still demands a PARTIAL exclusion, which is the thing no
        // per-source treatment can produce.
        #expect(vt6.expectedStateTax > 0,
                """
                VT-6 no longer expects a positive tax. It exists to pin Act 71's linear \
                phase-out at AGI $150,000, where $75,000 of a $150,000 military pension is \
                excludable and $67,150 remains taxable. An expectation of $0.00 would make \
                the declined `.full` rule correct and this whole decision moot.
                """)
        #expect(vt6.knownDefect != nil,
                "VT-6's defect block was deleted without Vermont shipping a rule, so nothing pins the gap")

        // And the treatment the rule would apply: the WHOLE row, every time.
        let excluded = Self.declinedMilitaryRule.treatment.excludedAmount(
            eligibleIncome: 150_000, totalGrossIncome: 150_000, isMarried: false)
        #expect(excluded == 150_000,
                """
                A `.full` treatment excluded \(excluded) of a $150,000 military pension. It \
                must exclude all of it, which is exactly the problem: Act 71 excludes \
                $75,000 at this AGI. Measured end to end, shipping this rule moved VT-6 \
                from its pinned $8,086.65 to $0.00 against a published $2,875.15.
                """)
    }

    /// The second, INDEPENDENT blocker, which survives even if a per-source
    /// phase-out became expressible: Vermont needs TWO bands and the model
    /// carries one.
    ///
    /// Asserted against the model rather than against Vermont's config, so it
    /// stays true while Vermont ships nothing.
    @Test("One jurisdiction carries one pooled cap and one phase-out, so Vermont's two cannot share them")
    func theTwoExclusionsCannotShareOneCapAndOnePhaseOut() {
        let exemptions = RetirementIncomeExemptions()
        let fields = Set(Mirror(reflecting: exemptions).children.compactMap(\.label))
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

                Task 9 relied on this type carrying exactly ONE pooled cap \
                (`pensionExemption`) and exactly ONE income phase-out (`agiPhaseout`), \
                because Vermont needs TWO of each: $10,000 over $55,000-$65,000 single for \
                CSRS, and uncapped over $125,000-$175,000 for military retired pay under \
                Act 71. If a second cap or a second phase-out was just added, re-open \
                Vermont against it: VT-2 and VT-6 are the cases that pin the two bands.
                """)

        // And the only per-source lever, `treatment`, cannot carry a cap at all.
        // This is the phase-wide ban, restated where Vermont depends on it.
        let capped = PerSourceExemptionRule(
            matchSources: [.federalCivilian], matchStructures: [.definedBenefit],
            treatment: .partial(maxExempt: Self.declinedCSRSPoolCap))
        let twoRowsOfFiveThousand = (0..<2).reduce(0.0) { total, _ in
            total + capped.treatment.excludedAmount(
                eligibleIncome: 6_000, totalGrossIncome: 40_000, isMarried: false)
        }
        #expect(twoRowsOfFiveThousand == 12_000,
                """
                Two $6,000 CSRS rows drew \(twoRowsOfFiveThousand) from a `.partial(10000)` \
                per-source treatment. It must be $12,000, and that is the POINT: the \
                treatment is evaluated once per row, so Vermont's ONE $10,000 household \
                line would become $10,000 per pension. VT-3's source says the worksheet \
                "provides ONE $10,000 line for the joint return, not a per-spouse doubled \
                figure". This is why the CSRS cap has to ride the pooled exemption.
                """)
    }

    // MARK: - Why the CSRS shape was declined despite going green

    /// Hawaii's test, applied to Vermont, and it points the same way.
    ///
    /// The CSRS shape is arithmetically correct on all four CSRS fixtures and
    /// was MEASURED going green on all four. It was declined because the only
    /// source it can name is `federalCivilian`, whose own doc comment says it
    /// covers "CSRS and FERS", while Vermont's exclusion applies (VT-4's quoted
    /// source) "only to benefits that are based on earnings not covered by the
    /// Social Security Act". FERS earnings are Social-Security-covered.
    ///
    /// So the grant and the over-match come out of the same quoted authority,
    /// which is precisely the asymmetry Massachusetts HAD and Hawaii did not.
    /// Direction settles the rest: today's error is OVER-taxation, and the rule
    /// would trade that for UNDER-taxation of the larger population, undisclosed
    /// on every output surface.
    @Test("The CSRS shape's only expressible source covers the very group Vermont's limiter excludes")
    func theCSRSShapeOverMatchesFERSFromItsOwnQuotedLimiter() throws {
        // The over-match is structural, not incidental: there is no source the
        // rule could name instead.
        let csrsShapeRule = PerSourceExemptionRule(
            matchSources: [.federalCivilian], matchStructures: [.definedBenefit], treatment: .none)
        #expect(csrsShapeRule.matches(structure: .definedBenefit, source: .federalCivilian),
                "the shape's pool membership turns on federalCivilian and nothing narrower exists")

        // Step 3 is PROCEDURALLY UNSATISFIABLE here, and this proves it from the
        // fixture's own data rather than by assertion: the case that would catch
        // the over-match is a FERS retiree under the AGI threshold, whose inputs
        // are byte-identical to VT-1's with a contradictory expected value.
        let file = try GoldenScenario.load(abbreviation: "VT")
        let vt1 = try #require(file.scenarios.first { $0.name.contains("AGI $40,000") })
        let rows = try #require(vt1.classifiedPensionSources)
        #expect(rows.count == 1)
        #expect(rows[0].planSource == "federalCivilian",
                """
                VT-1's CSRS row is no longer federalCivilian. If a Social-Security-coverage \
                axis or a CSRS-specific source arrived, the over-match this decision rests \
                on may be gone: re-open Vermont, re-measure the CSRS shape, and rewrite \
                this file.
                """)
        #expect(vt1.expectedStateTax == 742.03,
                """
                VT-1's published figure is now \(vt1.expectedStateTax) rather than the \
                $742.03 the declined CSRS shape was measured producing. That figure is \
                half of the collision this decision rests on: a FERS household at the same \
                shape owes the UNRELIEVED $1,077.03 VT-1's knownDefect pins as today's \
                output, on inputs this schema cannot tell apart from VT-1's. If the \
                published figure moved, re-derive both halves before trusting this file.
                """)
        #expect(vt1.knownDefect?.observedToday == 1077.03)
    }

    /// The measured result of the CSRS shape, recorded as data so the report is
    /// not the only place it survives. These four figures are the fixtures' own
    /// published values, and shipping the shape made the engine produce every
    /// one of them.
    @Test("All four Vermont CSRS cases stay pinned, and their published figures are the ones the declined shape produced")
    func theFourCSRSCasesStayPinnedAtTheirMeasuredGap() throws {
        let file = try GoldenScenario.load(abbreviation: "VT")
        let expectedByMarker: [(marker: String, form: Double, observed: Double)] = [
            ("AGI $40,000", 742.03, 1077.03),
            ("AGI $60,000", 1579.53, 1885.15),
            ("totaling $65,000", 1316.55, 1651.55),
            ("exclusion-eligible", 981.55, 1316.55)
        ]
        for expectation in expectedByMarker {
            let matches = file.scenarios.filter { $0.name.contains(expectation.marker) }
            #expect(matches.count == 1,
                    "\"\(expectation.marker)\" matches \(matches.count) VT scenarios, expected exactly 1")
            guard let scenario = matches.first else { continue }
            #expect(scenario.expectedStateTax == expectation.form)
            #expect(scenario.knownDefect?.observedToday == expectation.observed,
                    """
                    \(expectation.marker): pinned at \
                    \(String(describing: scenario.knownDefect?.observedToday)), expected \
                    \(expectation.observed). Vermont ships no rule, so nothing in this \
                    task should have moved any of these. If the block was DELETED, a rule \
                    shipped without this file being updated.
                    """)
        }
    }

    // MARK: - The caption, which is the only surface a Vermont user sees

    /// Vermont's position is North Carolina's and Idaho's: no rule, therefore no
    /// disclosure on any surface, therefore a caption is the whole delivery.
    /// This asserts it says the right things, and in the right DIRECTION.
    ///
    /// THE COPY IS APPROVED, as written, by John on 2026-08-05. See
    /// `IncomeSourcesView.vermontRetirementExclusionCaption`. John separately
    /// DECIDED the underlying question the same day: HOLD, Vermont ships no rule,
    /// accepting the unanimous recommendation. So this caption is not a placeholder
    /// for a rule that is coming; it is the delivery.
    @Test("Vermont's caption names both exclusions, both limits and the right direction")
    func vermontCaptionNamesTheRightDirection() {
        let caption = IncomeSourcesView.vermontRetirementExclusionCaption
        #expect(caption.contains("$10,000"), "the CSRS exclusion's cap")
        #expect(caption.contains("$55,000"), "the CSRS exclusion's single-filer income limit")
        #expect(caption.contains("military retired pay"), "the larger of the two exclusions")
        #expect(caption.contains("$125,000"), "Act 71's income limit")
        #expect(caption.contains("overstated"),
                """
                Vermont applies neither exclusion today, so every error runs toward \
                OVER-taxation. A caption saying "understated" would invert it and would \
                match Massachusetts's situation, which is the opposite of this one.
                """)
        // The two surfaces that would otherwise carry this are both silent,
        // which is what makes the caption load-bearing rather than decorative.
        #expect(UnclassifiedPensionDisclosure.text(for: .vermont, scope: .stateComparisonFigure) == nil)
        #expect(!PlanClassificationChoice.residenceHasPerSourceRules(.vermont))
    }
}
