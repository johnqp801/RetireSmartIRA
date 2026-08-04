import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Golden scenarios, single-year path")
struct GoldenScenarioSingleYearTests {

    static let pilot = ["PA", "IL", "MS", "NJ", "NY"]

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
        // deduction step (see doc comment above). `.conformsToFederal` is not
        // handled -- no pilot state uses it -- so it is treated as 0 here
        // rather than pulled in via the federal standard deduction table;
        // flag this comment if a future pilot state needs it.
        let stateStandardDeduction: Double
        switch StateTaxData.config(for: state).stateDeduction {
        case .none, .conformsToFederal:
            stateStandardDeduction = 0
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

    @Test("Single-year path matches each state's own published form",
          arguments: GoldenScenarioSingleYearTests.pilot)
    func singleYearMatchesGolden(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        let state = try #require(USState.allCases.first { $0.abbreviation == abbreviation })
        for scenario in file.scenarios {
            let actual = Self.singleYearStateTax(scenario, state: state)
            if let defect = scenario.knownDefect {
                #expect(abs(actual - defect.observedToday) < 0.01,
                        """
                        \(abbreviation) / \(scenario.name): engine now \(actual), \
                        pinned observed value \(defect.observedToday).
                        A DEFECTIVE state moved. Diagnose what changed before touching this pin.
                        Defect: \(defect.summary)
                        """)
                #expect(abs(actual - scenario.expectedStateTax) >= 0.01,
                        """
                        \(abbreviation) / \(scenario.name) now MATCHES its published form \
                        (\(scenario.expectedStateTax)). The defect appears to be FIXED.
                        Delete the knownDefect block from this fixture so the case becomes a
                        normal passing assertion. Do not update observedToday to keep it quiet.
                        """)
            } else {
                #expect(abs(actual - scenario.expectedStateTax) < 0.01,
                        """
                        \(abbreviation) / \(scenario.name): engine \(actual), \
                        form says \(scenario.expectedStateTax).
                        Source: \(scenario.source)
                        Phase 4 corrects no tax value. If the engine is wrong, add a knownDefect
                        block recording the MEASURED observedToday and leave the fix for Phase 5.
                        """)
            }
        }
    }

    @Test("A knownDefect fixture pins today's wrong figure and asserts it is still wrong")
    func knownDefectMechanismRoundTrips() throws {
        let json = """
        {"state":"XX","taxYear":2026,"scenarios":[{
          "name":"synthetic",
          "source":"synthetic fixture for the mechanism test, cites no authority",
          "sourceURL":"https://example.invalid/none",
          "filingStatus":"single","primaryAge":65,"spouseAge":null,
          "federalAGI":50000,"taxableSocialSecurity":0,"pensionIncome":50000,
          "iraWithdrawals":0,"rothConversion":0,
          "expectedStateTax":1218.88,
          "knownDefect":{"tier":"tier2","summary":"missing personal exemption","observedToday":2171.52}
        }]}
        """
        let file = try JSONDecoder().decode(GoldenScenarioFile.self, from: Data(json.utf8))
        let scenario = try #require(file.scenarios.first)
        let defect = try #require(scenario.knownDefect)
        #expect(defect.tier == "tier2")
        #expect(abs(defect.observedToday - 2171.52) < 0.01)
        #expect(abs(scenario.expectedStateTax - 1218.88) < 0.01)
    }

    @Test("A fixture with no knownDefect decodes it as nil")
    func absentKnownDefectDecodesNil() throws {
        let file = try GoldenScenario.load(abbreviation: "PA")
        let scenario = try #require(file.scenarios.first)
        #expect(scenario.knownDefect == nil)
    }
}
