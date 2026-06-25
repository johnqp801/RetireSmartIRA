//
//  HeirObjectiveTests.swift
//  RetireSmartIRATests
//
//  Heir-tax optimizer objective + trade-off frontier (engine layer).
//  Covers plan tasks 1-8 + the task-12 units invariant. UI/export (tasks 9-11) and the
//  tab wiring (task 10) belong with the deferred Multi-Year Plan tab.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Heir-tax objective + frontier", .serialized)
@MainActor
struct HeirObjectiveTests {

    // Pinned 2026 config so heir rates/brackets are deterministic.
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func heirInputs(
        primaryAge: Int = 65,
        traditional: Double = 1_000_000,
        roth: Double = 0,
        heirSalary: Double = 120_000,
        heirFilingStatus: FilingStatus = .single,
        heirDrawdownYears: Int = 10
    ) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: traditional, roth: roth, taxable: 0, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: primaryAge,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: "CA",
            primarySSClaimAge: 70,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 2026 - primaryAge,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0,
            heirSalary: heirSalary,
            heirFilingStatus: heirFilingStatus,
            heirDrawdownYears: heirDrawdownYears
        )
    }

    private func assumptions(horizonEndAge: Int = 80) -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: horizonEndAge,
            horizonEndAgeSpouse: nil,
            cpiRate: 0.0,
            investmentGrowthRate: 0.0,
            withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false,
            perYearExpenseOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0
        )
    }

    // MARK: Task 1 — heir tax helper

    @Test("Task1: helper = balance × effective rate")
    func helperMatchesEffectiveRateTimesBalance() {
        let balance = 800_000.0, salary = 120_000.0, drawdown = 10
        let expected = balance * TaxCalculationEngine.heirEffectiveTaxRate(
            annualDistribution: balance / Double(drawdown), heirSalary: salary, filingStatus: .single)
        let actual = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
            balance: balance, heirSalary: salary, heirFilingStatus: .single, drawdownYears: drawdown)
        #expect(abs(actual - expected) < 0.01)
    }

    @Test("Task1: zero balance is zero tax")
    func helperZeroBalance() {
        #expect(LegacyPlanningEngine.heirTaxOnInheritedTraditional(
            balance: 0, heirSalary: 120_000, heirFilingStatus: .single, drawdownYears: 10) == 0)
    }

    // MARK: Task 2/3 — heir fields carried + adapted

    @Test("Task2: heir fields are stored and readable")
    func staticInputsCarryHeirFields() {
        let inputs = heirInputs(heirSalary: 95_000, heirFilingStatus: .single, heirDrawdownYears: 10)
        #expect(inputs.heirSalary == 95_000)
        #expect(inputs.heirFilingStatus == .single)
        #expect(inputs.heirDrawdownYears == 10)
    }

    @Test("Task3: adapter copies heir fields from DataManager")
    func adapterCopiesHeirFields() {
        let dm = DataManager(skipPersistence: true)
        dm.legacyHeirEstimatedSalary = 110_000
        dm.legacyHeirFilingStatus = .single
        let inputs = MultiYearInputAdapter.build(
            from: dm, scenarioState: dm.scenario, assumptions: MultiYearAssumptions())
        #expect(inputs.heirSalary == 110_000)
        #expect(inputs.heirFilingStatus == .single)
        #expect(inputs.heirDrawdownYears == dm.legacyDrawdownYears)
    }

    // MARK: Task 4 — blended objective

    @Test("Task4: blendedObjectiveCost is a convex blend with correct endpoints")
    func blendComposition() {
        #expect(abs(OptimizationEngine.blendedObjectiveCost(
            inHorizon: 100_000, selfTerminalTax: 40_000, heirTerminalTax: 90_000, heirWeight: 0.25)
            - (100_000 + 0.75 * 40_000 + 0.25 * 90_000)) < 0.001)
        #expect(OptimizationEngine.blendedObjectiveCost(
            inHorizon: 100_000, selfTerminalTax: 40_000, heirTerminalTax: 90_000, heirWeight: 0) == 140_000)
        #expect(OptimizationEngine.blendedObjectiveCost(
            inHorizon: 100_000, selfTerminalTax: 40_000, heirTerminalTax: 90_000, heirWeight: 1) == 190_000)
    }

    @Test("Task4: λ=0 reproduces the legacy objective exactly")
    func lambdaZeroMatchesLegacy() {
        let inputs = heirInputs(), a = assumptions()
        let legacy = OptimizationEngine().optimize(inputs: inputs, assumptions: a, configProvider: provider)
        let atZero = OptimizationEngine().optimize(inputs: inputs, assumptions: a, configProvider: provider, heirWeight: 0)
        #expect(abs(atZero.totalObjectiveCost - legacy.totalObjectiveCost) < 0.5)
        #expect(atZero.recommendedPath.count == legacy.recommendedPath.count)
    }

    @Test("Task4: higher heir weight converts at least as much")
    func higherHeirWeightConvertsAtLeastAsMuch() {
        let inputs = heirInputs(heirSalary: 150_000), a = assumptions()
        func converted(_ w: Double) -> Double {
            OptimizationEngine().optimize(inputs: inputs, assumptions: a, configProvider: provider, heirWeight: w)
                .recommendedPath.reduce(0.0) { acc, yr in
                    acc + yr.actions.reduce(0.0) { a2, act in
                        if case let .rothConversion(amount) = act { return a2 + amount }
                        return a2
                    }
                }
        }
        #expect(converted(1.0) >= converted(0.0))
    }

    // MARK: Task 5 — frontier model

    @Test("Task5: FrontierPoint exposes both unit outputs")
    func frontierPointUnits() {
        let p = FrontierPoint(weight: 0.5, ownerLifetimeTaxToday: 168_000,
            heirAfterTaxInheritanceToday: 758_000, heirTaxToday: 242_000, pvDiscountFactor: 0.5537)
        #expect(p.ownerLifetimeTax(units: .todaysDollars) == 168_000)
        #expect(abs(p.ownerLifetimeTax(units: .presentValue) - 168_000 * 0.5537) < 0.01)
    }

    @Test("Task5: default PV real discount rate is 3%")
    func pvRateDefault() {
        #expect(abs(MultiYearAssumptions().pvRealDiscountRate - 0.03) < 1e-9)
    }

    // MARK: Task 6 — coordinator

    @Test("Task6: frontier produces six points; weighting toward heirs is directionally correct")
    func coordinatorSixPointsDirectional() {
        // Short horizon keeps the 6× optimize sweep fast.
        let inputs = heirInputs(primaryAge: 88, heirSalary: 150_000)
        let r = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs, assumptions: assumptions(horizonEndAge: 95), configProvider: provider)
        #expect(r.points.map(\.weight) == [0, 0.10, 0.25, 0.50, 0.75, 1.0])

        // The OPTIMIZER is greedy (cap=2, intentionally not a global optimum), so the decomposed
        // components can wiggle by a fraction of a percent between adjacent greedy local optima —
        // only the blended objective it minimizes is monotone. The genuine, user-facing guarantee
        // is the ENDPOINT direction: fully weighting toward heirs leaves heirs at least as much and
        // costs the owner at least as much vs. weighting only for the owner.
        let first = r.points.first!, last = r.points.last!
        #expect(last.heirAfterTaxInheritanceToday >= first.heirAfterTaxInheritanceToday - 1.0)
        #expect(last.ownerLifetimeTaxToday >= first.ownerLifetimeTaxToday - 1.0)
    }

    @Test("Task6: PV discount factor uses the assumption rate")
    func coordinatorPVFactor() {
        let inputs = heirInputs(primaryAge: 88)
        let a = assumptions(horizonEndAge: 95)
        let r = HeirFrontierCoordinator().computeFrontier(inputs: inputs, assumptions: a, configProvider: provider)
        let expected = pow(1.03, -Double(a.horizonEndAge - inputs.primaryCurrentAge))
        #expect(abs(r.points[0].pvDiscountFactor - expected) < 1e-6)
    }

    // MARK: Task 7 — cross-view consistency

    @Test("Task7: frontier heir tax matches the single-year Legacy Impact primitive")
    func crossViewConsistency() {
        let balance = 950_000.0, salary = 130_000.0, drawdown = 10
        let frontierTax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
            balance: balance, heirSalary: salary, heirFilingStatus: .single, drawdownYears: drawdown)
        // Same primitive the single-year view stacks (incrementalTax × years == balance × effRate).
        let singleYearTax = balance * TaxCalculationEngine.heirEffectiveTaxRate(
            annualDistribution: balance / Double(drawdown), heirSalary: salary, filingStatus: .single)
        #expect(abs(frontierTax - singleYearTax) < 0.01)
    }

    // MARK: Task 8 — golden validation (bracket-stacking spike)

    @Test("Task8: large salaried-heir balance lands the 10-year bracket-stacking spike")
    func goldenBracketStackingSpike() {
        // $1.5M over 10y = $150k/yr stacked on $150k salary → well past a flat-22% assumption.
        let tax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
            balance: 1_500_000, heirSalary: 150_000, heirFilingStatus: .single, drawdownYears: 10)
        #expect(tax / 1_500_000 > 0.30)
    }

    @Test("Task8: modest heir + modest balance stays in mid brackets")
    func goldenModestCase() {
        let rate = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
            balance: 300_000, heirSalary: 60_000, heirFilingStatus: .single, drawdownYears: 10) / 300_000
        #expect(rate > 0.10 && rate < 0.24)
    }

    // MARK: Task 12 — units toggle is relabel-only

    @Test("Task12: PV toggle preserves ordering and is a uniform relabel")
    func unitsToggleRelabelOnly() {
        let inputs = heirInputs(primaryAge: 88, heirSalary: 130_000)
        let r = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs, assumptions: assumptions(horizonEndAge: 95), configProvider: provider)
        let todayOrder = r.points.sorted { $0.heirAfterTaxInheritance(units: .todaysDollars) < $1.heirAfterTaxInheritance(units: .todaysDollars) }.map(\.weight)
        let pvOrder = r.points.sorted { $0.heirAfterTaxInheritance(units: .presentValue) < $1.heirAfterTaxInheritance(units: .presentValue) }.map(\.weight)
        #expect(todayOrder == pvOrder)
        for p in r.points {
            #expect(abs(p.heirAfterTaxInheritance(units: .presentValue)
                - p.heirAfterTaxInheritanceToday * p.pvDiscountFactor) < 0.01)
        }
    }
}
