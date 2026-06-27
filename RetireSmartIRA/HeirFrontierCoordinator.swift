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
        // is unaffected). Balances are projected in NOMINAL dollars, so deflate by CPI to today's
        // dollars and then discount at the real rate: the combined (Fisher) factor (1+cpi)(1+r).
        let combinedRate = (1.0 + assumptions.cpiRate) * (1.0 + assumptions.pvRealDiscountRate)

        let points: [FrontierPoint] = Self.presetWeights.map { w in
            let result = OptimizationEngine().optimize(
                inputs: inputs, assumptions: assumptions,
                configProvider: configProvider, heirWeight: w)

            // Derive the terminal year from the path itself (lastYear - baseYear), so this factor
            // matches PlanComparison.terminalPVFactor exactly and the two on-screen "heirs keep"
            // figures never disagree (even for couples whose spouse horizon extends the path).
            let yearsToTerminal = max(0, (result.recommendedPath.last?.year ?? inputs.baseYear) - inputs.baseYear)
            let pvFactor = pow(combinedRate, -Double(yearsToTerminal))

            let inHorizonTax = result.recommendedPath.reduce(0.0) { $0 + $1.taxBreakdown.total }

            let terminalTrad = result.recommendedPath.last.map {
                $0.endOfYearBalances.primaryTraditional + $0.endOfYearBalances.spouseTraditional
            } ?? 0
            let terminalRoth = result.recommendedPath.last?.endOfYearBalances.roth ?? 0
            let terminalTaxable = result.recommendedPath.last?.endOfYearBalances.taxable ?? 0

            let heirTax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
                balance: terminalTrad,
                heirSalary: inputs.heirSalary,
                heirFilingStatus: inputs.heirFilingStatus,
                drawdownYears: inputs.heirDrawdownYears)

            // Heirs keep: tax-free Roth + after-(heir-)tax traditional + taxable at stepped-up basis.
            let heirKeeps = HeirValue.afterTaxToHeirs(
                roth: terminalRoth, traditional: terminalTrad,
                taxable: terminalTaxable, heirTaxOnTraditional: heirTax)

            return FrontierPoint(
                weight: w,
                ownerLifetimeTaxToday: inHorizonTax,
                heirAfterTaxInheritanceToday: heirKeeps,
                heirTaxToday: heirTax,
                pvDiscountFactor: pvFactor,
                recommendedPath: result.recommendedPath)
        }

        return HeirFrontierResult(points: points)
    }
}
