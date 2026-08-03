import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Golden scenarios, single-year path")
struct GoldenScenarioSingleYearTests {

    static let pilot = ["PA", "IL", "MS", "NJ"]

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
    static func singleYearStateTax(_ scenario: GoldenScenario, state: USState) -> Double {
        var sources: [IncomeSource] = []
        if scenario.pensionIncome > 0 {
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
        return TaxCalculationEngine.calculateStateTax(
            income: scenario.federalAGI,
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
            #expect(abs(actual - scenario.expectedStateTax) < 0.01,
                    """
                    \(abbreviation) / \(scenario.name): engine \(actual), form says \(scenario.expectedStateTax).
                    Source: \(scenario.source)
                    Phase 2 corrects no tax value. If the engine is wrong, record it and leave it for Phase 5.
                    """)
        }
    }
}
