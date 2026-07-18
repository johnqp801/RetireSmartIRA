//
//  MultiYearAssumptions.swift
//  RetireSmartIRA
//
//  Per-scenario assumption inputs for the Multi-Year Tax Strategy engine.
//

import Foundation

enum TaxPaymentSource: String, Codable, Sendable {
    case taxableThenGrossUp   // pay from taxable; shortfall pulled from traditional (taxed)
    case external             // legacy: tax assumed paid from outside funds (for tests/back-compat)
}

struct MultiYearAssumptions: Codable, Equatable, Sendable {
    var horizonEndAge: Int                       // primary spouse / single, default 95
    var horizonEndAgeSpouse: Int?                // override for second spouse, optional
    var cpiRate: Double                          // e.g., 0.025 = 2.5%
    var investmentGrowthRate: Double             // e.g., 0.06 = 6% nominal
    var withdrawalOrderingRule: WithdrawalOrderingRule
    var stressTestEnabled: Bool
    var perYearOverrides: [Int: YearOverride]    // year -> per-field overrides (living expenses, etc.)
    var perYearOverridesSchema: Int              // 0 = pre-feature/legacy, 1 = migrated
    var currentTaxableBalance: Double            // user-input, not in 1.9 AccountType
    var currentHSABalance: Double                // user-input, not in 1.9 AccountType
    /// Baseline annual living expenses in today's dollars. Default $60K.
    /// Previously a caller-supplied parameter to MultiYearInputAdapter.build();
    /// migrated to assumptions in Plan B so it persists per-scenario.
    var baselineAnnualExpenses: Double = 120_000
    var terminalLiquidationTaxRate: Double       // default 0.22 — see optimizer-correctness-fixes spec
    var cliffBuffer: Double                      // default 5_000 — IRMAA/ACA cliff safety margin
    /// Hashes of dismissed insight callouts (SS nudge, widow stress).
    /// UI state; engine ignores during optimization. Persisted with assumptions.
    var dismissedInsightKeys: Set<String> = []
    /// Whether the user has confirmed assumptions via the onboarding sheet.
    /// Gates the macro pane: false = locked overlay/banner; true = pane unlocked.
    var assumptionsConfirmed: Bool = false
    /// Real discount rate for the heir-frontier present-value display toggle (display-only;
    /// does NOT affect optimization). Default 3% real.
    var pvRealDiscountRate: Double = 0.03
    /// Where conversion/year tax is paid from. Default brakes over-conversion (C3).
    var taxPaymentSource: TaxPaymentSource = .taxableThenGrossUp
    /// User-selected conversion approach for the multi-year optimizer (Phase 2c). Default is the
    /// existing greedy lifetime-tax minimizer, so behavior is unchanged unless the user opts in.
    var conversionApproach: PersistedConversionApproach = .recommendedTaxMin
    /// Transient: the OLD (pre-2.1.2) legacy expense-override map, decoded only so
    /// `upgradedOverrides(...)` can migrate it into `perYearOverrides`. Never re-persisted —
    /// excluded from `CodingKeys` for encode, so synthesized `encode(to:)` skips it (default
    /// value + no matching case = excluded from synthesis). Cleared to `[:]` once migrated.
    var legacyExpenseOverrides: [Int: Double] = [:]

    private enum CodingKeys: String, CodingKey {
        case horizonEndAge, horizonEndAgeSpouse, cpiRate, investmentGrowthRate
        case withdrawalOrderingRule, stressTestEnabled
        case perYearOverrides, perYearOverridesSchema
        case currentTaxableBalance, currentHSABalance, baselineAnnualExpenses
        case terminalLiquidationTaxRate, cliffBuffer, dismissedInsightKeys
        case assumptionsConfirmed, pvRealDiscountRate, taxPaymentSource, conversionApproach
        /// OLD key, decode-only (see `legacyExpenseOverrides` above) — never encoded.
        case perYearExpenseOverrides
    }

    init(
        horizonEndAge: Int = 95,
        horizonEndAgeSpouse: Int? = nil,
        cpiRate: Double = 0.025,
        investmentGrowthRate: Double = 0.06,
        withdrawalOrderingRule: WithdrawalOrderingRule = .taxEfficient,
        stressTestEnabled: Bool = true,
        perYearOverrides: [Int: YearOverride] = [:],
        perYearOverridesSchema: Int = 1,
        currentTaxableBalance: Double = 0,
        currentHSABalance: Double = 0,
        baselineAnnualExpenses: Double = 120_000,
        terminalLiquidationTaxRate: Double = 0.22,
        cliffBuffer: Double = 5_000,
        dismissedInsightKeys: Set<String> = [],
        assumptionsConfirmed: Bool = false,
        pvRealDiscountRate: Double = 0.03,
        taxPaymentSource: TaxPaymentSource = .taxableThenGrossUp,
        conversionApproach: PersistedConversionApproach = .recommendedTaxMin
    ) {
        self.horizonEndAge = horizonEndAge
        self.horizonEndAgeSpouse = horizonEndAgeSpouse
        self.cpiRate = cpiRate
        self.investmentGrowthRate = investmentGrowthRate
        self.withdrawalOrderingRule = withdrawalOrderingRule
        self.stressTestEnabled = stressTestEnabled
        self.perYearOverrides = perYearOverrides
        self.perYearOverridesSchema = perYearOverridesSchema
        self.currentTaxableBalance = currentTaxableBalance
        self.currentHSABalance = currentHSABalance
        self.baselineAnnualExpenses = baselineAnnualExpenses
        self.terminalLiquidationTaxRate = terminalLiquidationTaxRate
        self.cliffBuffer = cliffBuffer
        self.dismissedInsightKeys = dismissedInsightKeys
        self.assumptionsConfirmed = assumptionsConfirmed
        self.pvRealDiscountRate = pvRealDiscountRate
        self.taxPaymentSource = taxPaymentSource
        self.conversionApproach = conversionApproach
    }

    // Explicit init(from:) for backward compatibility — older saves that lack
    // baselineAnnualExpenses or dismissedInsightKeys decode cleanly with defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.horizonEndAge = try c.decode(Int.self, forKey: .horizonEndAge)
        self.horizonEndAgeSpouse = try c.decodeIfPresent(Int.self, forKey: .horizonEndAgeSpouse)
        self.cpiRate = try c.decode(Double.self, forKey: .cpiRate)
        self.investmentGrowthRate = try c.decode(Double.self, forKey: .investmentGrowthRate)
        self.withdrawalOrderingRule = try c.decodeIfPresent(WithdrawalOrderingRule.self, forKey: .withdrawalOrderingRule) ?? .taxEfficient
        self.stressTestEnabled = try c.decodeIfPresent(Bool.self, forKey: .stressTestEnabled) ?? true
        self.perYearOverrides = (try? c.decodeIfPresent([Int: YearOverride].self, forKey: .perYearOverrides)) ?? [:]
        self.perYearOverridesSchema = (try? c.decodeIfPresent(Int.self, forKey: .perYearOverridesSchema)) ?? 0
        self.currentTaxableBalance = try c.decodeIfPresent(Double.self, forKey: .currentTaxableBalance) ?? 0
        self.currentHSABalance = try c.decodeIfPresent(Double.self, forKey: .currentHSABalance) ?? 0
        self.baselineAnnualExpenses = try c.decodeIfPresent(Double.self, forKey: .baselineAnnualExpenses) ?? 120_000
        self.terminalLiquidationTaxRate = try c.decode(Double.self, forKey: .terminalLiquidationTaxRate)
        self.cliffBuffer = try c.decode(Double.self, forKey: .cliffBuffer)
        self.dismissedInsightKeys = try c.decodeIfPresent(Set<String>.self, forKey: .dismissedInsightKeys) ?? []
        self.assumptionsConfirmed = try c.decodeIfPresent(Bool.self, forKey: .assumptionsConfirmed) ?? false
        self.pvRealDiscountRate = try c.decodeIfPresent(Double.self, forKey: .pvRealDiscountRate) ?? 0.03
        self.taxPaymentSource = try c.decodeIfPresent(TaxPaymentSource.self, forKey: .taxPaymentSource) ?? .taxableThenGrossUp
        self.conversionApproach = try c.decodeIfPresent(PersistedConversionApproach.self, forKey: .conversionApproach) ?? .recommendedTaxMin
        self.legacyExpenseOverrides = (try? c.decodeIfPresent([Int: Double].self, forKey: .perYearExpenseOverrides)) ?? [:]
    }

    // Explicit encode(to:) — required because CodingKeys carries the decode-only
    // `perYearExpenseOverrides` case (no matching stored property), which disables
    // synthesis. `legacyExpenseOverrides` is deliberately NOT written here: it is
    // transient and must never re-persist.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(horizonEndAge, forKey: .horizonEndAge)
        try c.encodeIfPresent(horizonEndAgeSpouse, forKey: .horizonEndAgeSpouse)
        try c.encode(cpiRate, forKey: .cpiRate)
        try c.encode(investmentGrowthRate, forKey: .investmentGrowthRate)
        try c.encode(withdrawalOrderingRule, forKey: .withdrawalOrderingRule)
        try c.encode(stressTestEnabled, forKey: .stressTestEnabled)
        try c.encode(perYearOverrides, forKey: .perYearOverrides)
        try c.encode(perYearOverridesSchema, forKey: .perYearOverridesSchema)
        try c.encode(currentTaxableBalance, forKey: .currentTaxableBalance)
        try c.encode(currentHSABalance, forKey: .currentHSABalance)
        try c.encode(baselineAnnualExpenses, forKey: .baselineAnnualExpenses)
        try c.encode(terminalLiquidationTaxRate, forKey: .terminalLiquidationTaxRate)
        try c.encode(cliffBuffer, forKey: .cliffBuffer)
        try c.encode(dismissedInsightKeys, forKey: .dismissedInsightKeys)
        try c.encode(assumptionsConfirmed, forKey: .assumptionsConfirmed)
        try c.encode(pvRealDiscountRate, forKey: .pvRealDiscountRate)
        try c.encode(taxPaymentSource, forKey: .taxPaymentSource)
        try c.encode(conversionApproach, forKey: .conversionApproach)
    }

    static let `default` = MultiYearAssumptions()

    func horizonEndAge(for spouse: SpouseID) -> Int {
        switch spouse {
        case .primary: return horizonEndAge
        case .spouse:  return horizonEndAgeSpouse ?? horizonEndAge
        }
    }

    /// Idempotent, atomic upgrade: a schema-0 plan migrates its legacy expense map into the additive
    /// model and stamps schema 1; a schema-1 plan is returned unchanged (never migrates twice).
    func upgradedOverrides(baselineAnnualExpenses: Double, cpiRate: Double, baseYear: Int) -> MultiYearAssumptions {
        guard perYearOverridesSchema < 1 else { return self }
        var copy = self
        let migrated = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: legacyExpenseOverrides,
            baselineAnnualExpenses: baselineAnnualExpenses, cpiRate: cpiRate, baseYear: baseYear)
        copy.perYearOverrides = perYearOverrides.merging(migrated) { _, new in new }.pruned()
        copy.legacyExpenseOverrides = [:]
        copy.perYearOverridesSchema = 1
        return copy
    }
}
