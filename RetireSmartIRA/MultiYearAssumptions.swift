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
    /// Baseline annual living expenses in today's dollars. Default $60K.
    /// Previously a caller-supplied parameter to MultiYearInputAdapter.build();
    /// migrated to assumptions in Plan B so it persists per-scenario.
    var baselineAnnualExpenses: Double = 60_000
    var terminalLiquidationTaxRate: Double       // default 0.22 — see optimizer-correctness-fixes spec
    var cliffBuffer: Double                      // default 5_000 — IRMAA/ACA cliff safety margin
    /// Hashes of dismissed insight callouts (SS nudge, widow stress).
    /// UI state; engine ignores during optimization. Persisted with assumptions.
    var dismissedInsightKeys: Set<String> = []

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
        baselineAnnualExpenses: Double = 60_000,
        terminalLiquidationTaxRate: Double = 0.22,
        cliffBuffer: Double = 5_000,
        dismissedInsightKeys: Set<String> = []
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
        self.baselineAnnualExpenses = baselineAnnualExpenses
        self.terminalLiquidationTaxRate = terminalLiquidationTaxRate
        self.cliffBuffer = cliffBuffer
        self.dismissedInsightKeys = dismissedInsightKeys
    }

    // Explicit init(from:) for backward compatibility — older saves that lack
    // baselineAnnualExpenses or dismissedInsightKeys decode cleanly with defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.horizonEndAge = try c.decode(Int.self, forKey: .horizonEndAge)
        self.horizonEndAgeSpouse = try c.decodeIfPresent(Int.self, forKey: .horizonEndAgeSpouse)
        self.cpiRate = try c.decode(Double.self, forKey: .cpiRate)
        self.investmentGrowthRate = try c.decode(Double.self, forKey: .investmentGrowthRate)
        self.withdrawalOrderingRule = try c.decode(WithdrawalOrderingRule.self, forKey: .withdrawalOrderingRule)
        self.stressTestEnabled = try c.decode(Bool.self, forKey: .stressTestEnabled)
        self.perYearExpenseOverrides = try c.decode([Int: Double].self, forKey: .perYearExpenseOverrides)
        self.currentTaxableBalance = try c.decode(Double.self, forKey: .currentTaxableBalance)
        self.currentHSABalance = try c.decode(Double.self, forKey: .currentHSABalance)
        self.baselineAnnualExpenses = (try? c.decode(Double.self, forKey: .baselineAnnualExpenses)) ?? 60_000
        self.terminalLiquidationTaxRate = try c.decode(Double.self, forKey: .terminalLiquidationTaxRate)
        self.cliffBuffer = try c.decode(Double.self, forKey: .cliffBuffer)
        self.dismissedInsightKeys = (try? c.decode(Set<String>.self, forKey: .dismissedInsightKeys)) ?? []
    }

    static let `default` = MultiYearAssumptions()

    func horizonEndAge(for spouse: SpouseID) -> Int {
        switch spouse {
        case .primary: return horizonEndAge
        case .spouse:  return horizonEndAgeSpouse ?? horizonEndAge
        }
    }
}
