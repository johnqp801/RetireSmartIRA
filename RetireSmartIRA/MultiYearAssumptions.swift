//
//  MultiYearAssumptions.swift
//  RetireSmartIRA
//
//  Per-scenario assumption inputs for the Multi-Year Tax Strategy engine.
//

import Foundation

struct MultiYearAssumptions: Codable, Equatable {
    var horizonEndAge: Int                       // primary spouse / single, default 95
    var horizonEndAgeSpouse: Int?                // override for second spouse, optional
    var cpiRate: Double                          // e.g., 0.025 = 2.5%
    var investmentGrowthRate: Double             // e.g., 0.06 = 6% nominal
    var withdrawalOrderingRule: WithdrawalOrderingRule
    var stressTestEnabled: Bool
    var perYearExpenseOverrides: [Int: Double]   // year -> override expense amount
    var currentTaxableBalance: Double            // user-input, not in 1.9 AccountType
    var currentHSABalance: Double                // user-input, not in 1.9 AccountType
    var terminalLiquidationTaxRate: Double       // default 0.22 — see optimizer-correctness-fixes spec
    var cliffBuffer: Double                      // default 5_000 — IRMAA/ACA cliff safety margin

    init(
        horizonEndAge: Int = 95,
        horizonEndAgeSpouse: Int? = nil,
        cpiRate: Double = 0.025,
        investmentGrowthRate: Double = 0.06,
        withdrawalOrderingRule: WithdrawalOrderingRule = .taxEfficient,
        stressTestEnabled: Bool = true,
        perYearExpenseOverrides: [Int: Double] = [:],
        currentTaxableBalance: Double = 0,
        currentHSABalance: Double = 0,
        terminalLiquidationTaxRate: Double = 0.22,
        cliffBuffer: Double = 5_000
    ) {
        self.horizonEndAge = horizonEndAge
        self.horizonEndAgeSpouse = horizonEndAgeSpouse
        self.cpiRate = cpiRate
        self.investmentGrowthRate = investmentGrowthRate
        self.withdrawalOrderingRule = withdrawalOrderingRule
        self.stressTestEnabled = stressTestEnabled
        self.perYearExpenseOverrides = perYearExpenseOverrides
        self.currentTaxableBalance = currentTaxableBalance
        self.currentHSABalance = currentHSABalance
        self.terminalLiquidationTaxRate = terminalLiquidationTaxRate
        self.cliffBuffer = cliffBuffer
    }

    static let `default` = MultiYearAssumptions()

    func horizonEndAge(for spouse: SpouseID) -> Int {
        switch spouse {
        case .primary: return horizonEndAge
        case .spouse:  return horizonEndAgeSpouse ?? horizonEndAge
        }
    }
}
