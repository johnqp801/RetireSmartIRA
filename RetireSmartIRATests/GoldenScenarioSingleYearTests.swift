import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Golden scenarios, single-year path")
struct GoldenScenarioSingleYearTests {

    /// Single source of truth for which jurisdictions are asserted. Deliberately
    /// NOT a second literal list: a hand-maintained array is how a jurisdiction
    /// goes missing, and this codebase already shipped that failure once. This
    /// codebase previously returned California's configuration for any
    /// jurisdiction not found, so a missing state silently became California.
    /// Phase 2 replaced that fallback with a trap (`StateTaxData.config(for:)`
    /// now tries `configs2026`, then `configs2026Legacy`, then calls
    /// `preconditionFailure` rather than defaulting to any state).
    static let pilot = GoldenScenarioCoverageTests.covered

    /// Drives `TaxCalculationEngine.calculateStateTax` directly.
    ///
    /// This is deliberately the ENGINE, not the full Scenarios-screen path. The
    /// real screen path is `DataManager.scenarioStateTax` (`DataManager.swift:2055`)
    /// -> `calculateStateTaxFromGross` (`:586`) -> a wrapper (`:544`) -> this engine
    /// call. Those three layers also forward `localIncomeTaxRate` and
    /// `postExemptionDeduction` and reconcile the state standard deduction against
    /// above-the-line addbacks.
    ///
    /// Skipping them is numerically inert for the PA/IL/MS pilot: all three have
    /// `stateDeduction: .none`, none of them is New Jersey, and no fixture carries
    /// HSA, 401(k) or IRA contributions or capital losses.
    ///
    /// It stops being inert the moment a fixture needs any of those. New Jersey is
    /// exactly that moment: it is the only state where `postExemptionDeduction` is
    /// nonzero today (its per-filer personal exemptions, NJ-1040 line 13), and
    /// `DataManager.calculateStateTaxFromGross` reads it from the state's config
    /// as `config.personalExemption?.amount(...)` and forwards it before calling
    /// this same engine entry point. Reproduce that here rather
    /// than omit it: omitting it would make backlog I2 (multi-year drops
    /// `postExemptionDeduction`, `ProjectionEngine.swift:1622-1634`) invisible to a
    /// cross-path comparison, because both sides would then agree by both being
    /// wrong the same way.
    ///
    /// New York is the next such moment (Phase 3b Task 4): it is the first pilot
    /// state whose `stateDeduction` (`.fixed(single: 8_000, married: 16_050)`)
    /// actually changes this harness's answer. Mississippi's `stateDeduction` is
    /// also nonzero (`.fixed(single: 2_300, married: 4_600)`,
    /// `StateTaxData.swift:933`), but the `stateStandardDeduction` switch below
    /// is numerically inert for Mississippi's CURRENT fixture only: that
    /// fixture's retirement-income exemptions already zero out its taxable
    /// income before the state standard deduction has anything left to act on,
    /// so `expectedStateTax` is $0 with or without it. The next Mississippi
    /// fixture whose taxable income survives its exemptions will be affected by
    /// this switch, the same way New York's fixtures are here.
    /// `DataManager.calculateStateTaxFromGross` subtracts the state
    /// standard deduction from GROSS income BEFORE calling into
    /// `TaxCalculationEngine.calculateStateTax` (`stateTaxableIncome = max(0,
    /// adjustedGross - stateDeduction)`), not via `postExemptionDeduction` --
    /// that parameter is reserved for what comes AFTER retirement exemptions
    /// (NJ's personal exemption). Reproduced here the same way, so `federalAGI`
    /// keeps meaning literal federal AGI per its own doc comment rather than
    /// silently being redefined as "post-deduction taxable income." (For New
    /// York specifically the two orderings are algebraically identical --
    /// `applyRetirementExemptions` floors at zero only once, at the very end,
    /// and NY sets no `agiPhaseout` that would gate an exclusion's SIZE on
    /// which side of the subtraction it lands -- so this is not a case where
    /// order-of-operations could silently paper over a wrong exclusion.)
    static func singleYearStateTax(_ scenario: GoldenScenario, state: USState) -> Double {
        var sources: [IncomeSource] = []
        if let classified = scenario.classifiedPensionSources, !classified.isEmpty {
            precondition(scenario.pensionIncome == 0,
                         "classifiedPensionSources and pensionIncome both set -- would double count")
            for (index, row) in classified.enumerated() {
                // Force-decode: a typo'd raw value in a fixture must crash
                // this test loudly, not silently fall back to `nil` ->
                // `.unknown` inference, which would quietly turn a fixture
                // meant to trigger the per-source rule into one that never
                // matches it.
                let structure = try! JSONDecoder().decode(
                    PlanStructure.self, from: Data("\"\(row.planStructure)\"".utf8))
                let source = try! JSONDecoder().decode(
                    PlanSource.self, from: Data("\"\(row.planSource)\"".utf8))
                sources.append(IncomeSource(
                    name: "Pension \(index + 1)", type: .pension, annualAmount: row.amount,
                    planStructure: structure, planSource: source))
            }
        } else if scenario.pensionIncome > 0 {
            sources.append(IncomeSource(name: "Pension", type: .pension,
                                        annualAmount: scenario.pensionIncome))
        }
        let hasSpouse = scenario.spouseAge != nil
        let spouseAge = scenario.spouseAge ?? scenario.primaryAge
        // Mirrors what DataManager does now: read the state's personal exemption
        // from its config. Deliberately NOT a `state == .newJersey` check. Task 3
        // removed that hardcoded branch from production, and reinstating it here
        // would make this helper blind to every state that gains an exemption in
        // a later phase. Kansas is the first such state, and a blind helper would
        // let both sides of the cross-path comparison agree by being wrong the
        // same way, which is the exact failure this file's doc comment warns
        // about.
        let postExemptionDeduction = StateTaxData.config(for: state).personalExemption?
            .amount(filingStatus: scenario.resolvedFilingStatus, enableSpouse: hasSpouse,
                    primaryAge: scenario.primaryAge, spouseAge: spouseAge) ?? 0
        // Mirrors DataManager.calculateStateTaxFromGross's state-standard-
        // deduction step (see doc comment above).
        let stateStandardDeduction: Double
        switch StateTaxData.config(for: state).stateDeduction {
        case .none:
            stateStandardDeduction = 0
        case .conformsToFederal:
            // Task 4 (North Dakota): the first pilot state that actually needs
            // this branch. Mirrors DataManager.standardDeductionAmount
            // (DataManager.swift:1735-1775) in full: BASE federal standard
            // deduction, PLUS the age-65+ addition (added once per qualifying
            // person -- twice for MFJ when both spouses qualify), PLUS the
            // OBBBA senior bonus (per IRC section 151(d)(5)(B): $6,000 per
            // qualifying person, each person's $6,000 independently reduced by
            // 6% of MAGI over the threshold, THEN summed -- not one shared
            // reduction applied once and multiplied by headcount).
            //
            // An earlier version of this comment claimed both terms "depend on
            // a live DataManager instance this static helper doesn't have."
            // That was wrong for both terms: the age addition is a pure
            // function of the fixture's ages against two static config
            // constants already read in this function, and the bonus is a
            // pure function of MAGI, which this fixture already carries as
            // `federalAGI`.
            //
            // MAGI: production's `standardDeductionAmount` reads
            // `scenarioGrossIncome` (DataManager.swift:1721-1723), which is
            // `scenarioBaseIncome + scenarioTotalRothConversion +
            // scenarioTotalWithdrawals` -- i.e. every declared income
            // component summed. `GoldenScenario.federalAGI` is definitionally
            // identical to that sum for any income composition this fixture
            // schema can express: the schema's shape invariant requires
            // `federalAGI` to equal the sum of its declared components, and it
            // has no capital-gains or dividend field that could make the two
            // diverge. So `scenario.federalAGI` is an EXACT stand-in here, not
            // an approximation.
            let cfg = TaxCalculationEngine.config
            let magi = scenario.federalAGI
            // Matches the `currentYear: 2026` literal passed to
            // `calculateStateTax` below -- every bundled fixture file is
            // "statetax-2026-*.golden.json" and this helper has never taken a
            // year parameter.
            let year = 2026
            var amount: Double
            switch scenario.resolvedFilingStatus {
            case .single:
                amount = cfg.standardDeductionSingle
                if scenario.primaryAge >= 65 {
                    amount += cfg.additionalDeduction65Single
                }
                if scenario.primaryAge >= 65,
                   year >= cfg.seniorBonusFirstYear,
                   year <= cfg.seniorBonusLastYear {
                    let reduction = max(0, (magi - cfg.seniorBonusPhaseoutSingle) * cfg.seniorBonusPhaseoutRate)
                    amount += max(0, cfg.seniorBonusPerPerson - reduction)
                }
            case .marriedFilingJointly:
                amount = cfg.standardDeductionMFJ
                if scenario.primaryAge >= 65 { amount += cfg.additionalDeduction65MFJ }
                if hasSpouse && spouseAge >= 65 { amount += cfg.additionalDeduction65MFJ }
                if year >= cfg.seniorBonusFirstYear,
                   year <= cfg.seniorBonusLastYear {
                    var qualifyingSeniors = 0
                    if scenario.primaryAge >= 65 { qualifyingSeniors += 1 }
                    if hasSpouse && spouseAge >= 65 { qualifyingSeniors += 1 }
                    if qualifyingSeniors > 0 {
                        // Per IRC section 151(d)(5)(B): the $6,000 amount is
                        // reduced by 6% of MAGI over the threshold for EACH
                        // qualified individual, then summed across qualifying
                        // individuals on the return.
                        let perPersonReduction = max(0, (magi - cfg.seniorBonusPhaseoutMFJ) * cfg.seniorBonusPhaseoutRate)
                        let perPersonBonus = max(0, cfg.seniorBonusPerPerson - perPersonReduction)
                        amount += perPersonBonus * Double(qualifyingSeniors)
                    }
                }
            }
            stateStandardDeduction = amount
        case .fixed(let single, let married):
            // Filing status selects the bracket, mirroring
            // calculateStateTaxFromGross's `filingStatus == .single ? single :
            // married` -- deliberately NOT `hasSpouse`, which is a different
            // axis (MFJ status with spouse disabled is a real baseline case).
            stateStandardDeduction = scenario.resolvedFilingStatus == .single ? single : married
        }
        let stateTaxableIncomeBeforeExemptions = max(0, scenario.federalAGI - stateStandardDeduction)
        return TaxCalculationEngine.calculateStateTax(
            income: stateTaxableIncomeBeforeExemptions,
            forState: state,
            filingStatus: scenario.resolvedFilingStatus,
            taxableSocialSecurity: scenario.taxableSocialSecurity,
            incomeSources: sources,
            currentAge: scenario.primaryAge,
            enableSpouse: hasSpouse,
            spouseBirthYear: 2026 - (scenario.spouseAge ?? scenario.primaryAge),
            currentYear: 2026,
            scenarioRetirementDistributions: scenario.iraWithdrawals,
            scenarioRothConversionAmount: scenario.rothConversion,
            postExemptionDeduction: postExemptionDeduction
        )
    }

    /// The comparison decision, extracted so it can be tested directly.
    ///
    /// Phase 4's whole method rests on this branch, and before it was hoisted
    /// the only thing that ever exercised it was a mutation experiment that was
    /// deliberately reverted, leaving the logic uncovered. A pure function with
    /// no engine, no fixture loading and no I/O can be pinned in every outcome.
    enum GoldenComparison: Equatable {
        /// No knownDefect, and the engine agrees with the state's form.
        case matchesForm
        /// A knownDefect is present and the engine still produces the pinned figure.
        case pinnedDefectHolds
        /// A knownDefect is present but the engine has moved off the pinned figure.
        case pinnedDefectMoved(actual: Double, pinned: Double)
        /// A knownDefect is present and the engine now MATCHES the form, so the
        /// defect looks fixed and the block must be deleted rather than updated.
        case defectAppearsFixed(formValue: Double)
        /// No knownDefect, and the engine disagrees with the state's form.
        case unexplainedDisagreement(actual: Double, formValue: Double)
    }

    static func classify(actual: Double, scenario: GoldenScenario) -> GoldenComparison {
        let tolerance = 0.01
        guard let defect = scenario.knownDefect else {
            return abs(actual - scenario.expectedStateTax) < tolerance
                ? .matchesForm
                : .unexplainedDisagreement(actual: actual, formValue: scenario.expectedStateTax)
        }
        if abs(actual - scenario.expectedStateTax) < tolerance {
            return .defectAppearsFixed(formValue: scenario.expectedStateTax)
        }
        return abs(actual - defect.observedToday) < tolerance
            ? .pinnedDefectHolds
            : .pinnedDefectMoved(actual: actual, pinned: defect.observedToday)
    }

    @Test("Single-year path matches each state's own published form",
          arguments: GoldenScenarioSingleYearTests.pilot)
    func singleYearMatchesGolden(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        let state = try #require(USState.allCases.first { $0.abbreviation == abbreviation })
        for scenario in file.scenarios {
            let actual = Self.singleYearStateTax(scenario, state: state)
            switch Self.classify(actual: actual, scenario: scenario) {
            case .matchesForm, .pinnedDefectHolds:
                break
            case .pinnedDefectMoved(let actual, let pinned):
                #expect(Bool(false),
                        """
                        \(abbreviation) / \(scenario.name): engine now \(actual), \
                        pinned observed value \(pinned).
                        A DEFECTIVE state moved. Diagnose what changed before touching this pin.
                        Defect: \(scenario.knownDefect?.summary ?? "")
                        """)
            case .defectAppearsFixed(let formValue):
                #expect(Bool(false),
                        """
                        \(abbreviation) / \(scenario.name) now MATCHES its published form \
                        (\(formValue)). The defect appears to be FIXED.
                        Delete the knownDefect block from this fixture so the case becomes a
                        normal passing assertion. Do not update observedToday to keep it quiet.
                        """)
            case .unexplainedDisagreement(let actual, let formValue):
                #expect(Bool(false),
                        """
                        \(abbreviation) / \(scenario.name): engine \(actual), \
                        form says \(formValue).
                        Source: \(scenario.source)
                        Phase 4 corrects no tax value. If the engine is wrong, add a knownDefect
                        block recording the MEASURED observedToday and leave the fix for Phase 5.
                        """)
            }
        }
    }

    @Test("classify covers all five outcomes of the defect-pin decision")
    func classifyCoversAllOutcomes() throws {
        let noDefect = Self.makeScenario(expectedStateTax: 1000, knownDefect: nil)
        let withDefect = Self.makeScenario(
            expectedStateTax: 1000,
            knownDefect: KnownDefect(tier: "tier2", summary: "x", observedToday: 1200))

        // No knownDefect, engine agrees with the form.
        #expect(Self.classify(actual: 1000, scenario: noDefect) == .matchesForm)

        // No knownDefect, engine disagrees with the form.
        #expect(Self.classify(actual: 1200, scenario: noDefect)
                == .unexplainedDisagreement(actual: 1200, formValue: 1000))

        // knownDefect present, engine still produces the pinned figure.
        #expect(Self.classify(actual: 1200, scenario: withDefect) == .pinnedDefectHolds)

        // knownDefect present, engine matches neither the pin nor the form: the
        // pin has moved.
        #expect(Self.classify(actual: 1300, scenario: withDefect)
                == .pinnedDefectMoved(actual: 1300, pinned: 1200))

        // knownDefect present, but engine now matches the form: the defect
        // appears fixed. This must win over pinnedDefectMoved/pinnedDefectHolds
        // -- see the ordering note on `classify`.
        #expect(Self.classify(actual: 1000, scenario: withDefect)
                == .defectAppearsFixed(formValue: 1000))
    }

    /// Builds a minimal `GoldenScenario` in Swift, for tests that only need to
    /// vary `expectedStateTax` and `knownDefect`. Every other field is a fixed,
    /// arbitrary placeholder: `classify` never looks at them.
    static func makeScenario(expectedStateTax: Double, knownDefect: KnownDefect?) -> GoldenScenario {
        GoldenScenario(
            name: "synthetic", source: "synthetic fixture for classify() unit tests",
            sourceURL: "https://example.invalid/none",
            filingStatus: "single", primaryAge: 65, spouseAge: nil,
            federalAGI: 50000, taxableSocialSecurity: 0, pensionIncome: 50000,
            iraWithdrawals: 0, rothConversion: 0,
            expectedStateTax: expectedStateTax, classifiedPensionSources: nil,
            knownDefect: knownDefect, otherOrdinaryIncome: nil)
    }

    @Test("A fixture with no knownDefect decodes it as nil")
    func absentKnownDefectDecodesNil() throws {
        let file = try GoldenScenario.load(abbreviation: "PA")
        let scenario = try #require(file.scenarios.first)
        #expect(scenario.knownDefect == nil)
    }

    /// Finding 1 regression coverage: the `.conformsToFederal` branch of
    /// `singleYearStateTax` must deduct the age-65+ addition and the OBBBA
    /// senior bonus, not just the base federal standard deduction. No bundled
    /// fixture reaches this: North Dakota is the only `.conformsToFederal`
    /// state with fixtures today, and all four of its cases keep both filers
    /// under 65. This test is built in Swift, not a bundled fixture, per
    /// Finding 1's instruction to exercise the branch without touching the
    /// bundled ND fixtures.
    ///
    /// Reuses ND's own "single, moderate income, 1.95% bracket" fixture
    /// ($70,000 federal AGI, all pension income, no Social Security) but ages
    /// the filer to 70. Without the fix, the same $70,000 input produces
    /// $105.79 (that fixture's pinned value at age 52) because only the base
    /// $16,100 federal standard deduction is subtracted. With the fix:
    ///   base $16,100 + age-65 addition $2,050 + full OBBBA senior bonus
    ///   $6,000 (MAGI $70,000 is under the $75,000 single phaseout threshold,
    ///   so the bonus is un-reduced) = $24,150 deduction.
    ///   Taxable income = 70,000 - 24,150 = $45,850, which falls entirely
    ///   inside ND's 0% first bracket ($0-$48,475), so tax = $0.00.
    @Test("The .conformsToFederal branch deducts the age-65+ addition and OBBBA senior bonus")
    func conformsToFederalDeductsForAge65AndOver() throws {
        let state = try #require(USState.allCases.first { $0.abbreviation == "ND" })
        let scenario = GoldenScenario(
            name: "single, age 70, exercises .conformsToFederal age-65 deduction (synthetic, not bundled)",
            source: """
                Synthetic regression case for Finding 1, not a bundled fixture. Same $70,000 \
                federal AGI / all-pension income as ND's bundled 'single, moderate income, \
                1.95% bracket' fixture (primaryAge 52, expectedStateTax 105.79), but the filer \
                is aged to 70 so this test exercises the age-65 addition and OBBBA senior bonus \
                that no bundled ND fixture reaches. Expected deduction: base $16,100 + age-65 \
                addition $2,050 + full $6,000 senior bonus (MAGI $70,000 is under the $75,000 \
                single phaseout threshold) = $24,150. Taxable income = 70,000 - 24,150 = 45,850, \
                entirely inside ND's 0% first bracket ($0-$48,475), so tax = $0.00. Without the \
                age/bonus terms this would compute $105.79 instead, identical to the under-65 \
                fixture at the same income.
                """,
            sourceURL: "https://example.invalid/synthetic-conformsToFederal-age65-regression",
            filingStatus: "single", primaryAge: 70, spouseAge: nil,
            federalAGI: 70000, taxableSocialSecurity: 0, pensionIncome: 70000,
            iraWithdrawals: 0, rothConversion: 0,
            expectedStateTax: 0.0, classifiedPensionSources: nil,
            knownDefect: nil, otherOrdinaryIncome: nil)

        let actual = Self.singleYearStateTax(scenario, state: state)
        #expect(abs(actual - 0.0) < 0.01,
                """
                Expected $0.00 (taxable income $45,850 falls entirely inside ND's 0% bracket \
                once the age-65 addition and senior bonus are deducted). Got \(actual). If this \
                is $105.79, the .conformsToFederal branch has regressed to deducting only the \
                base federal standard deduction.
                """)
    }
}
