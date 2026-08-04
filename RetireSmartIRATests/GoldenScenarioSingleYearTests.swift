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
            // this branch -- this comment used to say "no pilot state uses it"
            // and treated the case as 0, which was numerically inert for every
            // fixture written before ND's. Mirrors DataManager
            // .standardDeductionAmount's BASE federal standard deduction only:
            // no age-65+ addition and no OBBBA senior bonus, both of which
            // depend on a live DataManager instance this static helper doesn't
            // have. Every ND fixture keeps both filers under 65, which makes
            // this an exact reproduction for them, not an approximation -- see
            // that property's doc comment in DataManager.swift for the parts
            // intentionally left out.
            let cfg = TaxCalculationEngine.config
            stateStandardDeduction = scenario.resolvedFilingStatus == .single
                ? cfg.standardDeductionSingle : cfg.standardDeductionMFJ
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
}
