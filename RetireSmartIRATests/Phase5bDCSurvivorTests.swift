//
//  Phase5bDCSurvivorTests.swift
//  RetireSmartIRATests
//
//  Phase 5b Task 9: the District of Columbia, and the largest production change
//  in the phase.
//
//  THE RULE. D.C. Code Section 47-1803.02(a)(2)(N)(ii) excludes "Survivor
//  benefits received from the District of Columbia or the federal government by
//  persons who are 62 years of age or older by the end of the taxable year",
//  with no dollar cap and no sunset clause. `statetax-2026-DC.json` now ships
//  it as `matchSources: ["federalCivilian", "ownStateOrLocal"]`,
//  `matchStructures: ["definedBenefit"]`, `matchIsSurvivorBenefit: true`,
//  `matchMinAge: 62`, treatment `full`.
//
//  WHAT HAD TO BE BUILT FOR IT, and why it is the phase's biggest Swift change.
//  Task 1 added `isSurvivorBenefit` to `RetirementPlanClassification` and
//  deliberately stopped there; Task 2 added it to the fixture type. Everything
//  between was missing: a field on `IncomeSource`, one on
//  `RetirementDistributionComponent`, `matchIsSurvivorBenefit` and
//  `matchMinAge` on `PerSourceExemptionRule`, two parameters on `matches()` and
//  on `matchedPerSourceRule`, pass-throughs at all six engine and DataManager
//  matching sites, a bridge in `GoldenScenarioSingleYearTests`, and a picker
//  affordance without which the rule would have been unreachable.
//
//  THE AGE GATE IS NOT OPTIONAL AND IT IS NOT IN THE PLAN'S CHAIN. The
//  per-source partition is documented as applying "UNCONDITIONALLY (no age
//  gate)", because New York's Line 26 exclusion has none. DC's has one, and
//  DC-1 (a flagged survivor at 55, expected fully taxable, carrying NO
//  `knownDefect`) fails outright against a rule that forgets it. So
//  `matchMinAge` had to be built alongside `matchIsSurvivorBenefit`, and it is
//  evaluated against the ROW OWNER's age rather than the household maximum
//  every pooled gate in the engine uses.
//
//  IT RE-OPENED IDAHO. Task 8 declined Idaho's military rule partly because no
//  age dimension existed, and asserted that by reflection so it would fail the
//  day one arrived. It fired on this task's first full-suite run. Idaho was
//  re-measured, the decision survived on the cap objection alone, and the
//  record was rewritten rather than silenced. See
//  `Phase5bIdahoDecisionTests.theDeclinedMilitaryRuleNowHasAnAgeGateButStillNoCap`.
//
//  WHAT THE GOLDEN FIXTURE ALREADY COVERS, so this file does not repeat it:
//  `statetax-2026-DC.golden.json` pins the end-to-end tax for a survivor below
//  the age gate (DC-1), a single survivor above it (DC-2), an MFJ household of
//  two survivors (DC-3), a mixed survivor-and-private household (DC-4), the
//  holder's OWN federal civilian pension (DC-5), and a Maryland survivor
//  annuity (DC-6). Those are the authority-derived numbers and they are the
//  specification.
//
//  WHAT THIS FILE ADDS, which no fixture reaches:
//    1. The DECODE PROOFS, by execution rather than by reading. Task 1's
//       Critical finding was a `Bool?` that compiled, warned, and then silently
//       decoded JSON setting it true as nil. Every new field in this task is
//       proven to survive a round trip, in both directions.
//    2. The three-valued semantics of `isSurvivorBenefit`, where `nil` is
//       "never asked" and satisfies neither a `true` nor a `false` rule.
//    3. The owner-age semantics of `matchMinAge`, which no bundled fixture can
//       reach because the golden runner builds every row as `.primary`.
//    4. The negative sweep over every `PlanSource`.
//    5. The `DataManager.stateTaxBreakdown` MIRROR, which hand-duplicates the
//       engine's per-source partition and has drifted from it five times on
//       this branch. No fixture drives it.
//    6. Picker reachability, and the fact that exactly one jurisdiction asks
//       the survivor question.
//    7. The non-vacuous deletion guard for the DC `knownButUnpinned` entry.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 5b Task 9: the District of Columbia's survivor-benefit exclusion")
struct Phase5bDCSurvivorTests {

    static var dcExemptions: RetirementIncomeExemptions {
        StateTaxData.config(for: .districtOfColumbia).retirementExemptions
    }

    /// The sources D.C. Code Section 47-1803.02(a)(2)(N)(ii) names: benefits
    /// "received from the District of Columbia or the federal government". The
    /// District's own system is `ownStateOrLocal` to a DC resident (Task 2
    /// re-labelled it off `otherStateOrLocal` for exactly this reason).
    static let sourcesTheStatuteNames: Set<PlanSource> = [.federalCivilian, .ownStateOrLocal]

    // MARK: - The shipped rule

    @Test("DC ships exactly one per-source rule, and it is the survivor exclusion")
    func dcShipsTheSurvivorRule() throws {
        let rules = Self.dcExemptions.perSourceExemptions
        #expect(rules.count == 1, "DC ships \(rules.count) per-source rules, expected exactly 1.")
        let rule = try #require(rules.first)
        #expect(Set(rule.matchSources) == Self.sourcesTheStatuteNames)
        #expect(rule.matchStructures == [.definedBenefit])
        #expect(rule.matchIsSurvivorBenefit == true,
                """
                DC's rule no longer requires the survivor flag. DC-5 is the guard that \
                catches this end to end: an unflagged OWN federal civilian pension at 65 \
                is fully taxable, and subparagraph (N)(i)'s general $3,000 pension \
                exclusion EXPIRED for tax years after 2014.
                """)
        #expect(rule.matchMinAge == 62,
                """
                DC's rule no longer carries the age-62 gate the statute states. DC-1 is \
                the guard that catches this end to end: a flagged survivor at 55 is fully \
                taxable at $1,924.00 and carries no knownDefect.
                """)
        if case .full = rule.treatment {} else {
            Issue.record("""
                DC's survivor exclusion is uncapped: subparagraph (N)(ii) states no dollar \
                figure, unlike the expired (N)(i) which capped at $3,000. A `.partial` \
                treatment here would also be banned phase-wide, because `treatment` is \
                evaluated inside the engine's per-row loop.
                """)
        }
    }

    /// The config fact DC's fixture arithmetic silently rests on, asserted
    /// nowhere else: DC grants NO pooled pension exemption. Subparagraph (N)(i)
    /// expired after tax year 2014, and DC-5's own source records that the app
    /// was already right to grant nothing for it.
    @Test("DC still grants no pooled pension exemption, because subparagraph (N)(i) expired")
    func dcGrantsNoPooledPensionExemption() {
        if case .none = Self.dcExemptions.pensionExemption {} else {
            Issue.record("""
                DC now ships a pooled pensionExemption. D.C. Code Section \
                47-1803.02(a)(2)(N)(i)'s $3,000 exclusion for a person's OWN District or \
                federal pension carried "this sub-subparagraph shall apply for taxable \
                years beginning before January 1, 2015", and DC OTR's current D-40 \
                Schedule I has no pension-exclusion line at all. Reinstating it would \
                break DC-5 and DC-1, both of which expect the full $1,924.00.
                """)
        }
        #expect(Self.dcExemptions.regularExemptionMinAge == 0,
                """
                DC's regularExemptionMinAge moved off 0. The age-62 test belongs on the \
                RULE (`matchMinAge`), not on the pooled level: `regularExemptionMinAge` \
                gates `pensionExemption`/`iraWithdrawalExemption` through `resolveLevel`, \
                which the per-source partition never consults, and it is household-wide \
                rather than per recipient.
                """)
    }

    /// Step 3's question, answered as an assertion and swept over
    /// `PlanSource.allCases` so a case added by a later task is classified
    /// deliberately rather than by default.
    @Test("DC's rule matches exactly the two sources the statute names, and no others",
          arguments: PlanSource.allCases)
    func dcRuleMatchesOnlyWhatTheStatuteNames(source: PlanSource) throws {
        let rule = try #require(Self.dcExemptions.perSourceExemptions.first)
        let matched = rule.matches(structure: .definedBenefit, source: source,
                                   isSurvivorBenefit: true, age: 65)
        #expect(matched == Self.sourcesTheStatuteNames.contains(source),
                """
                \(source): DC's rule matches \(matched), expected \
                \(Self.sourcesTheStatuteNames.contains(source)). Subparagraph (N)(ii) \
                covers survivor benefits from the District or the federal government and \
                from nowhere else. `otherStateOrLocal` in particular must stay out: DC-6 \
                is the Maryland guard that pins it end to end.
                """)
    }

    // MARK: - The three-valued survivor flag

    /// `nil` is "never asked", not "no". This is the property that keeps a
    /// pension saved before this task existed from silently claiming DC's
    /// exclusion, and it is the same discipline `PlanSource.unknown` already
    /// encodes.
    @Test("A row that was never asked matches neither a true nor a false survivor condition")
    func neverAskedMatchesNeitherCondition() {
        let wantsSurvivor = PerSourceExemptionRule(
            matchSources: [], matchStructures: [], matchIsSurvivorBenefit: true, treatment: .full)
        let wantsOwn = PerSourceExemptionRule(
            matchSources: [], matchStructures: [], matchIsSurvivorBenefit: false, treatment: .full)
        let ignoresIt = PerSourceExemptionRule(
            matchSources: [], matchStructures: [], treatment: .full)

        #expect(wantsSurvivor.matches(structure: .definedBenefit, source: .federalCivilian,
                                      isSurvivorBenefit: true))
        #expect(!wantsSurvivor.matches(structure: .definedBenefit, source: .federalCivilian,
                                       isSurvivorBenefit: false))
        #expect(!wantsSurvivor.matches(structure: .definedBenefit, source: .federalCivilian,
                                       isSurvivorBenefit: nil),
                """
                An unasked row satisfied a rule REQUIRING the survivor fact. Every pension \
                saved before this task carries nil, so this is the difference between DC's \
                exclusion applying only to people who said they are survivors and it \
                applying to every federal pension in the District.
                """)

        #expect(wantsOwn.matches(structure: .definedBenefit, source: .federalCivilian,
                                 isSurvivorBenefit: false))
        #expect(!wantsOwn.matches(structure: .definedBenefit, source: .federalCivilian,
                                  isSurvivorBenefit: nil),
                """
                An unasked row satisfied a rule requiring the row NOT to be a survivor \
                benefit. nil is not an answer in either direction.
                """)

        // And a rule that does not mention the dimension is unaffected by it,
        // which is what keeps New York's, Kansas's, Massachusetts's and
        // Arizona's shipped rules behaving exactly as they did.
        for value: Bool? in [true, false, nil] {
            #expect(ignoresIt.matches(structure: .definedBenefit, source: .federalCivilian,
                                      isSurvivorBenefit: value),
                    "a rule with no survivor condition changed answer for \(String(describing: value))")
        }
    }

    /// The same three-valued discipline for the age gate, including the
    /// direction an unknown age fails in.
    @Test("The age gate denies below the minimum and denies an unknown age")
    func theAgeGateFailsClosed() {
        let gated = PerSourceExemptionRule(
            matchSources: [], matchStructures: [], matchMinAge: 62, treatment: .full)
        #expect(!gated.matches(structure: .definedBenefit, source: .federalCivilian, age: 61))
        #expect(gated.matches(structure: .definedBenefit, source: .federalCivilian, age: 62))
        #expect(gated.matches(structure: .definedBenefit, source: .federalCivilian, age: 90))
        #expect(!gated.matches(structure: .definedBenefit, source: .federalCivilian, age: nil),
                """
                A gated rule matched a row whose owner's age is unknown. The direction \
                matters: it must fail CLOSED, leaving the taxpayer over-taxed and the \
                error visible, rather than handing out an exclusion on a fact nobody has.
                """)

        let ungated = PerSourceExemptionRule(
            matchSources: [], matchStructures: [], treatment: .full)
        for age: Int? in [nil, 0, 55, 62, 99] {
            #expect(ungated.matches(structure: .definedBenefit, source: .federalCivilian, age: age),
                    "a rule with no age condition changed answer for \(String(describing: age))")
        }
    }

    // MARK: - Decode proofs, by execution

    /// Task 1's Critical finding, guarded at every new site.
    ///
    /// `let isSurvivorBenefit: Bool? = nil` compiled, produced only a warning,
    /// and then SILENTLY DECODED JSON setting it true as nil. Reasoning about
    /// Swift's synthesis rules is what let that ship; these assertions run the
    /// round trip instead.
    @Test("PerSourceExemptionRule round-trips both new fields, in both directions")
    func perSourceRuleRoundTripsTheNewFields() throws {
        let json = """
            {"matchSources":["federalCivilian"],"matchStructures":["definedBenefit"],
             "matchIsSurvivorBenefit":true,"matchMinAge":62,"treatment":{"kind":"full"}}
            """
        let decoded = try JSONDecoder().decode(PerSourceExemptionRule.self, from: Data(json.utf8))
        #expect(decoded.matchIsSurvivorBenefit == true,
                "matchIsSurvivorBenefit decoded as \(String(describing: decoded.matchIsSurvivorBenefit)), not true. This is Task 1's silent-loss failure at a new site.")
        #expect(decoded.matchMinAge == 62,
                "matchMinAge decoded as \(String(describing: decoded.matchMinAge)), not 62.")

        let reencoded = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        #expect(reencoded.contains("matchIsSurvivorBenefit"))
        #expect(reencoded.contains("matchMinAge"))

        // A rule written before this task has neither key and must decode to
        // nil for both, which is what keeps New York's shipped config inert.
        let legacy = """
            {"matchSources":["nyStateOrLocal"],"matchStructures":["definedBenefit"],"treatment":{"kind":"full"}}
            """
        let legacyRule = try JSONDecoder().decode(PerSourceExemptionRule.self, from: Data(legacy.utf8))
        #expect(legacyRule.matchIsSurvivorBenefit == nil)
        #expect(legacyRule.matchMinAge == nil)
        let legacyReencoded = String(decoding: try JSONEncoder().encode(legacyRule), as: UTF8.self)
        #expect(!legacyReencoded.contains("matchIsSurvivorBenefit"),
                """
                An unconditioned rule now encodes a matchIsSurvivorBenefit key. \
                `encodeIfPresent` is what keeps a rule that says nothing about the \
                dimension from re-encoding differently than it was written, which Layer B \
                of the Phase 1 equivalence gate compares byte for byte.
                """)
        #expect(!legacyReencoded.contains("matchMinAge"))
    }

    @Test("IncomeSource round-trips isSurvivorBenefit, and an absent key stays nil")
    func incomeSourceRoundTripsTheSurvivorFlag() throws {
        for value in [true, false] {
            let row = IncomeSource(name: "Survivor annuity", type: .pension, annualAmount: 50_000,
                                   planStructure: .definedBenefit, planSource: .federalCivilian,
                                   isSurvivorBenefit: value)
            let data = try JSONEncoder().encode(row)
            let text = String(decoding: data, as: UTF8.self)
            #expect(text.contains("isSurvivorBenefit"),
                    "IncomeSource dropped the key on encode for \(value). Encoded as: \(text)")
            let back = try JSONDecoder().decode(IncomeSource.self, from: data)
            #expect(back.isSurvivorBenefit == value,
                    """
                    IncomeSource round-tripped \(value) as \
                    \(String(describing: back.isSurvivorBenefit)). A user who answered the \
                    survivor question would lose the answer on the next app launch, and \
                    with it DC's exclusion.
                    """)
        }

        // Never asked: no key on the way out, nil on the way back.
        let unasked = IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000,
                                   planStructure: .definedBenefit, planSource: .federalCivilian)
        let unaskedText = String(decoding: try JSONEncoder().encode(unasked), as: UTF8.self)
        #expect(!unaskedText.contains("isSurvivorBenefit"),
                "an unasked row wrote a survivor key: \(unaskedText)")
        #expect(try JSONDecoder().decode(IncomeSource.self,
                                         from: Data(unaskedText.utf8)).isSurvivorBenefit == nil)
    }

    /// The `PersistenceManager.loadAll` hazard Phase 3b's decode-trap lesson
    /// covers. `loadAll` wraps its `[IncomeSource]` decode in `try?`, so ONE row
    /// throwing discards EVERY stored income source. A malformed survivor value
    /// must therefore resolve, never throw.
    @Test("A malformed isSurvivorBenefit value does not throw, so loadAll cannot discard every row")
    func aMalformedSurvivorValueNeverThrows() throws {
        let good = IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000,
                                planStructure: .definedBenefit, planSource: .federalCivilian,
                                isSurvivorBenefit: true)
        var object = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(good)) as! [String: Any]
        object["isSurvivorBenefit"] = "yes please"
        let corrupted = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(IncomeSource.self, from: corrupted)
        #expect(decoded.isSurvivorBenefit == nil,
                """
                A non-boolean survivor value resolved to \
                \(String(describing: decoded.isSurvivorBenefit)) rather than nil. nil is \
                the right answer: the stored value states nothing this app can act on, and \
                the conservative reading of "unknown" is that no exclusion is claimed.
                """)
        #expect(decoded.annualAmount == 50_000,
                "the rest of the row must survive; a throw here would take every stored income source with it")

        // And the whole ARRAY still decodes, which is the shape loadAll uses.
        let array = try JSONDecoder().decode([IncomeSource].self,
                                             from: try JSONSerialization.data(withJSONObject: [object, object]))
        #expect(array.count == 2)
    }

    // MARK: - Owner-age semantics, which no fixture can reach

    /// `GoldenScenarioSingleYearTests.singleYearStateTax` builds every
    /// classified row with the default `owner: .primary`, so DC-3 (spouse 63)
    /// and DC-4 (spouse 60) both evaluate the gate against the PRIMARY's 65 and
    /// neither can tell owner-age from primary-age. This can.
    ///
    /// Two identical survivor annuities, one on each spouse, one spouse over
    /// the gate and one under. The statute conditions on the age of the person
    /// RECEIVING the benefit, so exactly one must be excluded.
    @Test("The age gate reads the row owner's own age, not the household maximum")
    func theAgeGateReadsTheRowOwnersOwnAge() {
        func tax(primaryAge: Int, spouseAge: Int) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: 100_000, forState: .districtOfColumbia,
                filingStatus: .marriedFilingJointly, taxableSocialSecurity: 0,
                incomeSources: [
                    IncomeSource(name: "Primary survivor annuity", type: .pension,
                                 annualAmount: 50_000, owner: .primary,
                                 planStructure: .definedBenefit, planSource: .federalCivilian,
                                 isSurvivorBenefit: true),
                    IncomeSource(name: "Spouse survivor annuity", type: .pension,
                                 annualAmount: 50_000, owner: .spouse,
                                 planStructure: .definedBenefit, planSource: .federalCivilian,
                                 isSurvivorBenefit: true)
                ],
                currentAge: primaryAge, enableSpouse: true,
                spouseBirthYear: 2026 - spouseAge, currentYear: 2026)
        }

        let bothOver = tax(primaryAge: 70, spouseAge: 65)
        let oneUnder = tax(primaryAge: 70, spouseAge: 55)
        let bothUnder = tax(primaryAge: 55, spouseAge: 55)

        #expect(bothOver == 0,
                "both survivors clear 62, so both annuities are excluded and nothing is left to tax; got \(bothOver)")
        #expect(oneUnder > bothOver,
                """
                One spouse is 55 and their own survivor annuity is NOT excluded, so this \
                household must owe more than one where both clear the gate. Got \
                \(oneUnder) against \(bothOver). If these are equal, `matchMinAge` is \
                being evaluated against the household maximum, which would hand a \
                55-year-old widow an exclusion D.C. Code Section 47-1803.02(a)(2)(N)(ii) \
                conditions on HER age.
                """)
        #expect(bothUnder > oneUnder,
                """
                Neither survivor clears 62, so neither annuity is excluded and this \
                household must owe more than the one where exactly one does. Got \
                \(bothUnder) against \(oneUnder).
                """)

        // The exact size, so this pins the mechanism and not merely its sign.
        // One excluded $50,000 annuity at DC's 8.5% band boundary is a real
        // figure, not a sign test: bothUnder taxes $100,000 of DC taxable
        // income and oneUnder taxes $50,000 of it.
        #expect(oneUnder > 0,
                "with one annuity excluded there is still $50,000 of DC taxable income to tax")
    }

    // MARK: - The DataManager mirror

    @MainActor
    static func dcBreakdown(source: PlanSource, isSurvivorBenefit: Bool?,
                            age: Int = 66) -> (DataManager, StateTaxBreakdown) {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - age; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.enableSpouse = false
        dm.selectedState = .districtOfColumbia
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: source,
                         isSurvivorBenefit: isSurvivorBenefit)
        ]
        return (dm, dm.stateTaxBreakdown(forState: .districtOfColumbia, filingStatus: .single))
    }

    /// THE MIRROR CHECK this task owes, and it is higher risk than usual.
    ///
    /// `DataManager.stateTaxBreakdown` hand-duplicates the engine's per-source
    /// partition rather than calling into it, and that duplication has drifted
    /// from the engine five separate times on this branch. This task's survivor
    /// and age pass-throughs land in exactly that mirror. Nothing in the golden
    /// fixture set touches it: the golden runner drives
    /// `TaxCalculationEngine.calculateStateTax` directly and never constructs a
    /// breakdown.
    ///
    /// PROVEN CAPABLE OF FAILING, by mutation rather than by reading. During
    /// this task `DataManager.stateTaxBreakdown`'s pension-row call site had its
    /// `isSurvivorBenefit:` argument temporarily replaced with a literal `nil`.
    /// This test failed for `federalCivilian` and `ownStateOrLocal`, reporting a
    /// breakdown of $1,924.00 against a computed $0.00 and an exempt amount of
    /// $0 against $50,000. The mutation was reverted and `git diff` confirmed
    /// the file clean before anything was committed.
    @MainActor
    @Test("The income-breakdown mirror agrees with the tax computation for every DC source",
          arguments: PlanSource.allCases)
    func breakdownMirrorAgreesWithTheEngineForDC(source: PlanSource) {
        let (dm, breakdown) = Self.dcBreakdown(source: source, isSurvivorBenefit: true)
        let computed = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome, forState: .districtOfColumbia,
            filingStatus: .single, taxableSocialSecurity: dm.scenarioTaxableSocialSecurity)

        #expect(abs(breakdown.totalStateTax - computed) < 0.01,
                """
                DC / \(source): the income-breakdown display reports \
                \(breakdown.totalStateTax) while the tax computation reports \(computed). \
                DataManager's per-source partition has drifted from \
                TaxCalculationEngine.applyRetirementExemptions.
                """)

        let expectedExempt: Double = Self.sourcesTheStatuteNames.contains(source) ? 50_000 : 0
        #expect(abs(breakdown.pensionExemptAmount - expectedExempt) < 0.01,
                """
                DC / \(source): breakdown attributes \(breakdown.pensionExemptAmount) of \
                pension exclusion, expected \(expectedExempt). A mirror that agrees on the \
                total while displaying the wrong exempt figure is still a defect a DC user \
                reads.
                """)
    }

    /// The contrast that makes the sweep above mean something: identical
    /// inputs, one axis changed at a time, and the mirror must move with the
    /// engine on BOTH axes.
    @MainActor
    @Test("The mirror moves on the survivor axis and on the age axis, not just the source axis")
    func theMirrorMovesOnBothNewAxes() {
        let survivorOver = Self.dcBreakdown(source: .federalCivilian, isSurvivorBenefit: true, age: 66).1
        let survivorUnder = Self.dcBreakdown(source: .federalCivilian, isSurvivorBenefit: true, age: 55).1
        let ownPension = Self.dcBreakdown(source: .federalCivilian, isSurvivorBenefit: false, age: 66).1
        let neverAsked = Self.dcBreakdown(source: .federalCivilian, isSurvivorBenefit: nil, age: 66).1

        #expect(abs(survivorOver.pensionExemptAmount - 50_000) < 0.01,
                "a 66-year-old survivor's federal annuity is excluded in full")
        #expect(abs(survivorUnder.pensionExemptAmount) < 0.01,
                "a 55-year-old survivor fails the age-62 gate; got \(survivorUnder.pensionExemptAmount)")
        #expect(abs(ownPension.pensionExemptAmount) < 0.01,
                """
                A 66-year-old's OWN federal civilian pension was excluded \
                (\(ownPension.pensionExemptAmount)). Subparagraph (N)(i)'s $3,000 \
                exclusion expired after tax year 2014; this is DC-5's defect reappearing \
                in the breakdown.
                """)
        #expect(abs(neverAsked.pensionExemptAmount) < 0.01,
                """
                A row whose survivor question was never asked was excluded \
                (\(neverAsked.pensionExemptAmount)). Every DC pension saved before this \
                task carries nil, so this is the difference between an opt-in exclusion \
                and a blanket one.
                """)
        #expect(survivorUnder.totalStateTax > survivorOver.totalStateTax)
        #expect(ownPension.totalStateTax > survivorOver.totalStateTax)
    }

    // MARK: - Picker reachability

    /// A rule no real user can select is a green suite and an undelivered fix.
    ///
    /// The twelve-row plan-type picker writes `planStructure`/`planSource` and
    /// nothing else, so before this task NO combination of user actions could
    /// set `isSurvivorBenefit`, and every DC golden case would have gone green
    /// while a real survivor annuitant received nothing. Task 3 established that
    /// adding the affordance is in scope when the alternative is an unreachable
    /// rule; this asserts the two halves the rule needs are both reachable.
    @Test("Both sources DC's rule names are reachable from the picker")
    func dcsSourcesAreReachableFromThePicker() {
        let reachable = Set(PlanClassificationChoice.allCases.map { $0.classification.source })
        for source in Self.sourcesTheStatuteNames {
            #expect(reachable.contains(source),
                    """
                    No picker row writes \(source), which DC's rule names. A DC survivor \
                    annuitant could not select the exclusion, so every DC golden case \
                    would pass while the fix reached nobody.
                    """)
        }

        // And the structure half: DC's rule is definedBenefit-only, so at least
        // one reachable row must pair a named source with that structure.
        let reachablePairs = Set(PlanClassificationChoice.allCases.map {
            "\($0.classification.structure)|\($0.classification.source)"
        })
        for source in Self.sourcesTheStatuteNames {
            #expect(reachablePairs.contains("\(PlanStructure.definedBenefit)|\(source)"),
                    "no picker row writes (definedBenefit, \(source)), the pair DC's rule requires")
        }
    }

    /// The survivor question is asked where it can change an answer and nowhere
    /// else, derived from live config rather than from a hardcoded jurisdiction
    /// check.
    @Test("Exactly the jurisdictions whose rules consult the survivor dimension ask the question")
    func onlyTheDistrictAsksTheSurvivorQuestion() {
        for state in USState.allCases {
            let asks = PlanClassificationChoice.residenceUsesSurvivorDimension(state)
            let consults = StateTaxData.config(for: state).retirementExemptions
                .perSourceExemptions.contains { $0.matchIsSurvivorBenefit != nil }
            #expect(asks == consults,
                    """
                    \(state.abbreviation): the pension editor asks the survivor question \
                    \(asks) while the jurisdiction's shipped rules consult it \(consults). \
                    These must be the same predicate, so a jurisdiction that ships a \
                    survivor rule gets the affordance for free and one that does not is \
                    not asked a question that cannot change its tax.
                    """)
        }

        // Today exactly one jurisdiction does, and it is the District. Asserted
        // as a DERIVED fact rather than as the gate itself, so a second
        // jurisdiction shipping a survivor rule updates this line deliberately
        // instead of silently.
        let asking = USState.allCases.filter(PlanClassificationChoice.residenceUsesSurvivorDimension)
        #expect(asking == [.districtOfColumbia],
                "jurisdictions asking the survivor question are \(asking.map(\.abbreviation)), expected [DC]")
    }

    // MARK: - The disclosure

    /// Task 3b's lockstep sweep asserts a sentence EXISTS. This asserts it says
    /// the right things, which the sweep cannot.
    ///
    /// PROPOSED COPY, AWAITING JOHN. Two alternatives were drafted and are
    /// recorded in the Task 9 report. This one was recommended because it names
    /// both conditions a reader needs to test themselves against, the two
    /// employers and the age, rather than warning vaguely that something may be
    /// wrong. Rewording is a one-line change in `statetax-2026-DC.json` plus
    /// these assertions.
    @Test("DC's disclosure sentence names the employers, the age and the direction")
    func dcDisclosureNamesTheRightThings() throws {
        let sentence = try #require(Self.dcExemptions.unclassifiedPensionDisclosure)
        #expect(sentence.contains(UnclassifiedPensionDisclosure.scopeToken),
                "the sentence must carry the {scope} token so both surfaces can substitute their own word")
        #expect(sentence.contains("survivor"),
                "the sentence must name the survivor condition, which is what the rule turns on")
        #expect(sentence.contains("62"),
                "the sentence must name the age gate, or a 58-year-old survivor reads it as applying to them")
        #expect(sentence.contains("taxes your pension in full until it is classified"),
                """
                DC's default is NO exclusion, so the direction is over-taxation, matching \
                Kansas's and Massachusetts's sentences and NOT Arizona's, whose \
                unclassified default grants an allowance. A sentence implying DC already \
                gives something back would invert it.
                """)

        // Composed end to end, both surfaces.
        let figure = try #require(UnclassifiedPensionDisclosure.text(
            for: .districtOfColumbia, scope: .stateComparisonFigure))
        #expect(figure.contains("this figure") && !figure.contains("{scope}"))
        let plan = try #require(UnclassifiedPensionDisclosure.text(
            for: .districtOfColumbia, scope: .cpaBriefingPlan))
        #expect(plan.contains("this plan") && !plan.contains("{scope}"))
    }

    // MARK: - The unpinned defect this task ships with

    /// The non-vacuous deletion guard the catalogue's own well-formedness test
    /// cannot provide. Task 6 shipped an entry without one and was caught.
    ///
    /// This fails if the DC entry is deleted, AND it re-derives the condition
    /// the entry describes from the SHIPPED config, so the entry cannot outlive
    /// the defect either.
    @Test("The DC pre-existing-row defect stays recorded, and its condition still holds")
    func theSilentlyOverTaxedExistingRowDefectStaysRecorded() throws {
        let entry = try #require(
            GoldenScenarioDefectCatalogueTests.knownButUnpinned.first { $0.state == "DC" },
            """
            DC's known-but-unpinned defect is gone from the catalogue. A DC survivor whose
            pension row predates this task carries isSurvivorBenefit nil, gets no exclusion,
            and gets no warning on any surface, because both disclosure surfaces gate on the
            pension being UNCLASSIFIED and this one is classified. If that was fixed, delete
            this test in the SAME change and say which surface now fires.
            """)
        #expect(entry.summary.contains("over-taxed, silently, on every surface"))
        #expect(entry.blockedOn.contains("residenceUsesSurvivorDimension"))

        // The condition, re-derived rather than restated: DC's shipped rule
        // still requires the flag, so a nil row still gets nothing.
        let rule = try #require(Self.dcExemptions.perSourceExemptions.first)
        #expect(rule.matchIsSurvivorBenefit == true,
                """
                DC's rule no longer requires the survivor flag, so the catalogue entry \
                describing pre-existing rows as silently over-taxed is stale and must be \
                deleted along with this test.
                """)
        #expect(Self.dcExemptions.matchedPerSourceRule(
            structure: .definedBenefit, source: .federalCivilian,
            isSurvivorBenefit: nil, age: 70) == nil,
                """
                A row that was never asked the survivor question now matches DC's rule. \
                That would resolve the catalogued defect, but it would do it by granting \
                the exclusion to every DC federal pension, which subparagraph (N)(ii) does \
                not.
                """)
    }
}
