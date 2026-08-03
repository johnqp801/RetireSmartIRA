import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Golden scenarios, single-year path")
struct GoldenScenarioSingleYearTests {

    static let pilot = ["PA", "IL", "MS"]

    /// Drives `TaxCalculationEngine.calculateStateTax` directly.
    ///
    /// This is deliberately the ENGINE, not the full Scenarios-screen path. The
    /// real screen path is `DataManager.scenarioStateTax` (`DataManager.swift:2055`)
    /// -> `calculateStateTaxFromGross` (`:586`) -> a wrapper (`:544`) -> this engine
    /// call. Those three layers also forward `localIncomeTaxRate` and
    /// `postExemptionDeduction` and reconcile the state standard deduction against
    /// above-the-line addbacks.
    ///
    /// Skipping them is numerically inert for THIS pilot: PA, IL and MS all have
    /// `stateDeduction: .none`, none of them is New Jersey (the only state where
    /// `postExemptionDeduction` is nonzero today), and no fixture carries HSA,
    /// 401(k) or IRA contributions or capital losses.
    ///
    /// It stops being inert the moment a fixture needs any of those. In particular,
    /// a cross-path comparison that wants to observe backlog I2 (multi-year drops
    /// `postExemptionDeduction`) MUST supply that argument on this side, or both
    /// sides will omit it and the divergence will be invisible.
    static func singleYearStateTax(_ scenario: GoldenScenario, state: USState) -> Double {
        var sources: [IncomeSource] = []
        if scenario.pensionIncome > 0 {
            sources.append(IncomeSource(name: "Pension", type: .pension,
                                        annualAmount: scenario.pensionIncome))
        }
        let hasSpouse = scenario.spouseAge != nil
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
            scenarioRothConversionAmount: scenario.rothConversion
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
