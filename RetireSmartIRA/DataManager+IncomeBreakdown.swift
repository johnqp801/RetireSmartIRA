// RetireSmartIRA/DataManager+IncomeBreakdown.swift
import Foundation

@MainActor
extension DataManager {
    /// The single-year income chain, composed so each subtotal reproduces its tab's headline
    /// expression exactly. See docs/superpowers/specs/2026-07-02-income-consistency-design.md.
    ///
    /// - `totalWithRMDs` matches Tax Summary's `totalBaseline` (gross + regular RMD + inherited RMD).
    /// - `taxableFromSources` matches Scenarios' `incomeFromSourcesWithRMDs`
    ///   (`taxableIncome() + combinedRMD + inheritedRMD`).
    /// - `grossWithScenario` matches Quarterly's `scenarioGrossIncome`.
    ///
    /// The regular RMD is sourced once from `calculateCombinedRMD()` (the canonical combined-RMD
    /// figure) rather than re-deriving `calculatePrimaryRMD() + calculateSpouseRMD()` per view.
    var incomeBreakdown: IncomeBreakdown {
        let regularRMD = calculateCombinedRMD()
        let inheritedRMD = inheritedIRARMDTotal
        return IncomeBreakdown(
            allSources: totalAnnualIncome(),
            regularRMD: regularRMD,
            inheritedRMD: inheritedRMD,
            taxableFromSources: taxableIncome(filingStatus: filingStatus) + regularRMD + inheritedRMD,
            grossWithScenario: scenarioGrossIncome)
    }
}
