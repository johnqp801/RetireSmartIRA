import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Golden scenarios, multi-year path")
struct GoldenScenarioMultiYearTests {

    static let pilot = ["PA", "IL", "MS"]

    /// Year-1 state tax from the multi-year projection, or nil if the engine
    /// returned no years for this scenario.
    ///
    /// This drives `ProjectionEngine.project`, the full multi-year path -- NOT the
    /// same entry point `GoldenScenarioSingleYearTests` exercises. Social Security is
    /// set to 0 (benefit-at-FRA 0, claim age 70) so the projection does not inject
    /// income the golden scenario never specified; living expenses are 0 so nothing
    /// forces an unrequested withdrawal. The scenario's own IRA withdrawal and Roth
    /// conversion are driven in as explicit year-1 `LeverAction`s instead.
    ///
    /// `baseYear` is pinned to 2026 (matching the golden fixtures' `taxYear`) because
    /// `MultiYearStaticInputs.baseYear` otherwise defaults to `Calendar.current
    /// .component(.year, from: Date())`, which would make every scenario depend on
    /// today's date.
    static func multiYearYearOneStateTax(_ scenario: GoldenScenario,
                                         abbreviation: String) -> Double? {
        let baseYear = 2026
        let hasSpouse = scenario.spouseAge != nil

        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: max(scenario.iraWithdrawals * 20, 100_000),
                                              roth: 0, taxable: 0, hsa: 0),
            baseYear: baseYear,
            primaryCurrentAge: scenario.primaryAge,
            spouseCurrentAge: scenario.spouseAge,
            filingStatus: scenario.resolvedFilingStatus,
            state: abbreviation,
            primarySSClaimAge: 70,
            spouseSSClaimAge: hasSpouse ? 70 : nil,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: hasSpouse ? 0 : nil,
            primaryBirthYear: baseYear - scenario.primaryAge,
            spouseBirthYear: scenario.spouseAge.map { baseYear - $0 },
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: scenario.pensionIncome,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: hasSpouse ? 2 : 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: hasSpouse ? 65 : nil,
            baselineAnnualExpenses: 0
        )

        let assumptions = MultiYearAssumptions()
        var yearOneActions: [LeverAction] = []
        if scenario.iraWithdrawals > 0 {
            yearOneActions.append(.traditionalWithdrawal(amount: scenario.iraWithdrawals))
        }
        if scenario.rothConversion > 0 {
            yearOneActions.append(.rothConversion(amount: scenario.rothConversion))
        }
        let actions: [Int: [LeverAction]] = [baseYear: yearOneActions]

        let engine = ProjectionEngine()
        let path = engine.project(inputs: inputs, assumptions: assumptions, actionsPerYear: actions)
        guard let yearOne = path.first else { return nil }
        return yearOne.taxBreakdown.state
    }

    @Test("Multi-year year-1 matches each state's own published form",
          arguments: GoldenScenarioMultiYearTests.pilot)
    func multiYearMatchesGolden(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            let actual = try #require(Self.multiYearYearOneStateTax(scenario,
                                                                   abbreviation: abbreviation))
            #expect(abs(actual - scenario.expectedStateTax) < 0.01,
                    """
                    \(abbreviation) / \(scenario.name): multi-year \(actual), form says \(scenario.expectedStateTax).
                    Source: \(scenario.source)
                    Phase 2 corrects no tax value. Record any mismatch and leave it for Phase 5.
                    """)
        }
    }
}
