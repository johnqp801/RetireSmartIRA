// RetireSmartIRA/DataManager+IncomeBreakdown.swift
import Foundation

@MainActor
extension DataManager {
    /// The single-year income chain, composed from the existing figures each tab uses. See
    /// docs/superpowers/specs/2026-07-02-income-consistency-design.md.
    var incomeBreakdown: IncomeBreakdown {
        IncomeBreakdown(
            allSources: totalAnnualIncome(),
            inheritedRMD: inheritedIRARMDTotal,
            taxExempt: taxExemptInterestTotal,
            taxableFromSources: scenarioBaseIncome,
            scenarioAdditions: scenarioTotalRothConversion + scenarioTotalWithdrawals,
            grossWithScenario: scenarioGrossIncome)
    }
}
