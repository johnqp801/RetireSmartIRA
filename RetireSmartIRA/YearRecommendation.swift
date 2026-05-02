//
//  YearRecommendation.swift
//  RetireSmartIRA
//
//  Per-year output of the Multi-Year Tax Strategy engine.
//

import Foundation

struct YearRecommendation: Codable, Equatable {
    let year: Int
    let agi: Double
    let acaMagi: Double?      // nil when ACA-irrelevant (post-65)
    let irmaaMagi: Double?    // nil when IRMAA-irrelevant (pre-Medicare)
    let taxableIncome: Double
    let taxBreakdown: TaxBreakdown
    let endOfYearBalances: AccountSnapshot
    let actions: [LeverAction]

    init(
        year: Int,
        agi: Double,
        acaMagi: Double?,
        irmaaMagi: Double?,
        taxableIncome: Double,
        taxBreakdown: TaxBreakdown,
        endOfYearBalances: AccountSnapshot,
        actions: [LeverAction]
    ) {
        self.year = year
        self.agi = agi
        self.acaMagi = acaMagi
        self.irmaaMagi = irmaaMagi
        self.taxableIncome = taxableIncome
        self.taxBreakdown = taxBreakdown
        self.endOfYearBalances = endOfYearBalances
        self.actions = actions
    }
}
