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
                    + $0.endOfYearBalances.inheritedTraditional
            } ?? 0
            let terminalRoth = result.recommendedPath.last.map {
                $0.endOfYearBalances.roth + $0.endOfYearBalances.inheritedRoth
            } ?? 0
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

        return HeirFrontierResult(points: Self.paretoRepair(points))
    }

    /// Near-tie cushion (dollars). Domination/monotonicity are only enforced beyond this, so
    /// floating-point noise never triggers a spurious repair. Matches the audit harness's ε.
    static let repairEpsilon = 1.0

    /// Cross-λ Pareto repair. The optimizer runs independently at each preset weight, and on
    /// non-convergent profiles (iteration cap) a higher-heir-weight point can plot MORE owner tax
    /// AND FEWER heir dollars than a lower-weight point — a strictly dominated, economically
    /// nonsensical frontier point. Per-λ de-domination (`keepBestOfCandidates`) can't see this
    /// because it never compares across weights.
    ///
    /// Since every point's `recommendedPath` is a plan the household could actually choose, the
    /// honest fix is: any dominated weight adopts a genuinely-better sibling's outcome (keeping its
    /// own weight label). Two passes on the display axes (owner lifetime tax ↓, heirs-keep ↑):
    ///   1. Domination pull-up (to a fixed point): a point dominated by a sibling takes that
    ///      sibling's economics + path.
    ///   2. Monotonicity pull-up: scanning ascending weight, a point whose heirs-keep dips below the
    ///      previous weight's takes the previous weight's plan.
    /// Both only ever copy an already-plotted, non-dominated, achievable outcome, so the result is a
    /// proper non-dominated + monotone trade-off. A no-op on already-clean frontiers (the common case)
    /// — leaning-toward-heirs weights that can't beat a lower weight simply collapse onto it, which
    /// the presentation surfaces as "no meaningful owner-vs-heir tradeoff."
    static func paretoRepair(_ points: [FrontierPoint]) -> [FrontierPoint] {
        guard points.count > 1 else { return points }
        let eps = repairEpsilon

        // j dominates i: no worse on both axes, strictly better on at least one (ε-cushioned).
        func dominates(_ j: FrontierPoint, _ i: FrontierPoint) -> Bool {
            let noWorseTax = j.ownerLifetimeTaxToday <= i.ownerLifetimeTaxToday + eps
            let noWorseHeirs = j.heirAfterTaxInheritanceToday >= i.heirAfterTaxInheritanceToday - eps
            let strictlyBetter = j.ownerLifetimeTaxToday < i.ownerLifetimeTaxToday - eps
                || j.heirAfterTaxInheritanceToday > i.heirAfterTaxInheritanceToday + eps
            return noWorseTax && noWorseHeirs && strictlyBetter
        }
        // A new point at `weight`'s label carrying `src`'s economics + path.
        func adopt(weight: Double, from src: FrontierPoint) -> FrontierPoint {
            FrontierPoint(
                weight: weight,
                ownerLifetimeTaxToday: src.ownerLifetimeTaxToday,
                heirAfterTaxInheritanceToday: src.heirAfterTaxInheritanceToday,
                heirTaxToday: src.heirTaxToday,
                pvDiscountFactor: src.pvDiscountFactor,
                recommendedPath: src.recommendedPath)
        }

        var pts = points

        // Pass 1 — domination pull-up. Bounded fixed-point: each replacement moves a point to a
        // strictly-better sibling outcome from the fixed original pool, so it converges well within
        // count² iterations.
        var changed = true
        var iterations = 0
        while changed && iterations < pts.count * pts.count {
            changed = false
            iterations += 1
            for i in pts.indices {
                if let dominator = pts.first(where: { $0.weight != pts[i].weight && dominates($0, pts[i]) }) {
                    pts[i] = adopt(weight: pts[i].weight, from: dominator)
                    changed = true
                }
            }
        }

        // Pass 2 — monotonicity pull-up across ascending weight.
        let order = pts.indices.sorted { pts[$0].weight < pts[$1].weight }
        for k in 1..<order.count {
            let cur = order[k], prev = order[k - 1]
            if pts[cur].heirAfterTaxInheritanceToday < pts[prev].heirAfterTaxInheritanceToday - eps {
                pts[cur] = adopt(weight: pts[cur].weight, from: pts[prev])
            }
        }

        return pts
    }
}
