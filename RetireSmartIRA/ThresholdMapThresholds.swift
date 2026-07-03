import Foundation

/// Builds threshold lines for the threshold/cliff map from a tax config. Pure (config injected),
/// so it is testable without touching globals. Values are 2026-nominal (see the view's caveat).
enum ThresholdMapThresholds {

    /// MAGI-driven cliffs: IRMAA tiers (above the $0 baseline), NIIT, and (optionally) the ACA
    /// 400% FPL cliff for the given household size.
    static func magiLines(config: TaxYearConfig,
                          filingStatus: FilingStatus,
                          householdSize: Int,
                          includeACA: Bool) -> [ThresholdMapChart.Line] {
        let mfj = (filingStatus == .marriedFilingJointly)
        var lines: [ThresholdMapChart.Line] = []

        for tier in config.irmaaTiers where tier.tier > 0 {
            let value = mfj ? tier.mfjThreshold : tier.singleThreshold
            lines.append(.init(id: "irmaa\(tier.tier)", label: "IRMAA tier \(tier.tier)", value: value))
        }

        lines.append(.init(id: "niit", label: "NIIT",
                           value: mfj ? config.niitThresholdMFJ : config.niitThresholdSingle))

        if includeACA, config.acaSubsidy2026.hasCliff,
           let fpl = config.acaSubsidy2026.fpl2026.householdSizeToFPL["\(householdSize)"] {
            lines.append(.init(id: "aca", label: "ACA 400% FPL cliff", value: fpl * 4.0))
        }

        return lines
    }

    /// Federal income-tax bracket entry thresholds (above the $0 bracket), labeled by rate.
    static func bracketLines(config: TaxYearConfig, filingStatus: FilingStatus) -> [ThresholdMapChart.Line] {
        let brackets = (filingStatus == .marriedFilingJointly)
            ? config.federalBracketsMFJ
            : config.federalBracketsSingle
        return brackets
            .filter { $0.threshold > 0 }
            .map { .init(id: "br\(Int($0.threshold))", label: "\(Int(($0.rate * 100).rounded()))%", value: $0.threshold) }
    }
}
