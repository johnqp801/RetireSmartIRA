import Foundation

/// One column of the three-way approach comparison: the metrics for a single projected path.
/// Value type; built via `ApproachColumn.make(...)` so every column derives its figures from the
/// shared `PlanPathMetrics` statics rather than re-deriving inline.
struct ApproachColumn: Equatable, Sendable {
    let lifetimeTaxNominal: Double
    let lifetimeTaxPV: Double
    let endingTraditional: Double
    let endingRoth: Double
    let endingTaxable: Double
    let heirsKeep: Double
    let peakForcedRMD: Double
    let peakAnnualRothConversion: Double
    let terminalPVFactor: Double
    let path: [YearRecommendation]
}

extension ApproachColumn {
    /// Build a column from a projected path (nominal + PV), reusing the shared metric derivations.
    static func make(path: [YearRecommendation], inputs: MultiYearStaticInputs,
                     assumptions: MultiYearAssumptions) -> ApproachColumn {
        let baseYear = path.first?.year ?? inputs.baseYear
        let lastYear = path.last?.year ?? baseYear
        let terminalPVFactor = EngineMath.realPresentValue(1.0, yearsFromBase: lastYear - baseYear,
                                                           cpiRate: assumptions.cpiRate,
                                                           realDiscountRate: assumptions.pvRealDiscountRate)
        return ApproachColumn(
            lifetimeTaxNominal: PlanPathMetrics.lifetimeTax(path),
            lifetimeTaxPV: PlanPathMetrics.lifetimeTaxPV(path, baseYear: baseYear,
                                                         cpiRate: assumptions.cpiRate,
                                                         pvRealDiscountRate: assumptions.pvRealDiscountRate),
            endingTraditional: PlanPathMetrics.endingTraditional(path),
            endingRoth: PlanPathMetrics.endingRoth(path),
            endingTaxable: PlanPathMetrics.endingTaxable(path),
            heirsKeep: PlanPathMetrics.heirsKeep(path, heirSalary: inputs.heirSalary,
                                                 heirFilingStatus: inputs.heirFilingStatus,
                                                 heirDrawdownYears: inputs.heirDrawdownYears),
            peakForcedRMD: PlanPathMetrics.peakForcedRMD(path),
            peakAnnualRothConversion: PlanPathMetrics.peakAnnualRothConversion(path),
            terminalPVFactor: terminalPVFactor,
            path: path)
    }
}

/// The assembled three-way comparison: the selected approach, the Recommended plan, and the
/// no-additional-conversion baseline, plus the selected-vs-noConversion deltas and flags.
struct ApproachComparison: Equatable, Sendable {
    let selectedApproach: ConversionApproach
    let selected: ApproachColumn
    let recommended: ApproachColumn
    let noAdditionalConversions: ApproachColumn
    let deltas: ConsequenceDeltas       // selected vs noAdditionalConversions
    let flags: ConsequenceFlags         // selected vs noAdditionalConversions
    /// True when the selected approach IS the Recommended plan (`.recommendedTaxMin`);
    /// the UI collapses `selected` + `recommended` into one column.
    var collapsesToTwoColumns: Bool { selectedApproach == .recommendedTaxMin }
}
