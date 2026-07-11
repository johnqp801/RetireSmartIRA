import Foundation

/// Runs the three fixed comparison paths and assembles an ApproachComparison. Pure value-in /
/// value-out (the UI dispatches it off the main thread, like HeirFrontierCoordinator). The
/// heir frontier applies only to `.recommendedTaxMin`; deterministic approaches ignore heirWeight.
struct ApproachComparisonCoordinator {

    /// Canonical empty (no-additional-conversion) action map: `year: []` for every horizon year.
    /// Mirrors OptimizationEngine.optimize()'s horizon derivation EXACTLY (base year = inputs.baseYear;
    /// horizon runs to the LATER of the two spouses' endpoints). Shared with MultiYearStrategyManager.
    static func emptyActionsMap(inputs: MultiYearStaticInputs,
                               assumptions: MultiYearAssumptions) -> [Int: [LeverAction]] {
        let baseYear = inputs.baseYear
        let primaryEndYear = baseYear + (assumptions.horizonEndAge - inputs.primaryCurrentAge)
        let spouseEndYear: Int = {
            guard let spouseAge = inputs.spouseCurrentAge else { return primaryEndYear }
            return baseYear + (assumptions.horizonEndAge(for: .spouse) - spouseAge)
        }()
        let endYear = max(primaryEndYear, spouseEndYear)
        guard endYear >= baseYear else { return [:] }
        return Dictionary(uniqueKeysWithValues: (baseYear...endYear).map { ($0, []) })
    }

    func compare(inputs: MultiYearStaticInputs,
                 assumptions: MultiYearAssumptions,
                 selectedApproach: ConversionApproach,
                 heirWeight: Double,
                 configProvider: TaxYearConfigProvider = .current) -> ApproachComparison {

        // Recommended plan: greedy tax-min at the user's heir setting (heir-aware when legacy on).
        let recommendedPath = OptimizationEngine().optimize(
            inputs: inputs, assumptions: assumptions, configProvider: configProvider,
            heirWeight: heirWeight, approach: .recommendedTaxMin).recommendedPath

        // Selected approach: reuse the recommended run when they coincide (no double optimize).
        let selectedPath: [YearRecommendation]
        if selectedApproach == .recommendedTaxMin {
            selectedPath = recommendedPath
        } else {
            selectedPath = OptimizationEngine().optimize(
                inputs: inputs, assumptions: assumptions, configProvider: configProvider,
                heirWeight: heirWeight, approach: selectedApproach).recommendedPath
        }

        // No additional Roth conversions: empty action map.
        let noConvPath = ProjectionEngine(configProvider: configProvider).project(
            inputs: inputs, assumptions: assumptions,
            actionsPerYear: Self.emptyActionsMap(inputs: inputs, assumptions: assumptions))

        let selectedCol = ApproachColumn.make(path: selectedPath, inputs: inputs, assumptions: assumptions)
        return ApproachComparison(
            selectedApproach: selectedApproach,
            selected: selectedCol,
            recommended: selectedApproach == .recommendedTaxMin
                ? selectedCol
                : ApproachColumn.make(path: recommendedPath, inputs: inputs, assumptions: assumptions),
            noAdditionalConversions: ApproachColumn.make(path: noConvPath, inputs: inputs, assumptions: assumptions),
            deltas: ConsequenceDeltas(selected: selectedPath, noConversion: noConvPath),
            flags: ConsequenceFlags(selected: selectedPath, noConversion: noConvPath,
                                    filingStatus: inputs.filingStatus, configProvider: configProvider))
    }
}
