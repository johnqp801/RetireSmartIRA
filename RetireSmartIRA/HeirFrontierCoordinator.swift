//
//  HeirFrontierCoordinator.swift
//  RetireSmartIRA
//
//  Runs the optimizer across the six preset heir weights (λ) and assembles the
//  owner-vs-heirs trade-off frontier. Pure value-in / value-out; the UI layer is
//  responsible for dispatching this off the main thread.
//

import Foundation

struct HeirFrontierCoordinator {

    /// The six preset weights surfaced on the frontier (choose by dollar outcomes, not λ).
    static let presetWeights: [Double] = [0, 0.10, 0.25, 0.50, 0.75, 1.0]

    func computeFrontier(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions,
        configProvider: TaxYearConfigProvider = .current
    ) -> HeirFrontierResult {

        // Present-value discount factor for the display toggle (display-only; the optimizer
        // is unaffected). Discount from the terminal year back to the base year.
        let yearsToTerminal = Double(assumptions.horizonEndAge - inputs.primaryCurrentAge)
        let pvFactor = pow(1.0 + assumptions.pvRealDiscountRate, -max(0, yearsToTerminal))

        let points: [FrontierPoint] = Self.presetWeights.map { w in
            let result = OptimizationEngine().optimize(
                inputs: inputs, assumptions: assumptions,
                configProvider: configProvider, heirWeight: w)

            let inHorizonTax = result.recommendedPath.reduce(0.0) { $0 + $1.taxBreakdown.total }

            let terminalTrad = result.recommendedPath.last.map {
                $0.endOfYearBalances.primaryTraditional + $0.endOfYearBalances.spouseTraditional
            } ?? 0
            let terminalRoth = result.recommendedPath.last?.endOfYearBalances.roth ?? 0

            let heirTax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
                balance: terminalTrad,
                heirSalary: inputs.heirSalary,
                heirFilingStatus: inputs.heirFilingStatus,
                drawdownYears: inputs.heirDrawdownYears)

            // Heirs keep: tax-free Roth + after-(heir-)tax traditional.
            let heirKeeps = terminalRoth + (terminalTrad - heirTax)

            return FrontierPoint(
                weight: w,
                ownerLifetimeTaxToday: inHorizonTax,
                heirAfterTaxInheritanceToday: heirKeeps,
                heirTaxToday: heirTax,
                pvDiscountFactor: pvFactor)
        }

        return HeirFrontierResult(points: points)
    }
}
