//
//  YearRecommendation.swift
//  RetireSmartIRA
//
//  Per-year output of the Multi-Year Tax Strategy engine.
//

import Foundation

struct YearRecommendation: Codable, Equatable, Sendable {
    let year: Int
    let agi: Double
    let acaMagi: Double?      // nil when ACA-irrelevant (post-65)
    let irmaaMagi: Double?    // nil when IRMAA-irrelevant (pre-Medicare)
    let taxableIncome: Double
    /// The preferential-rate portion (LTCG + qualified dividends + realized gains) of taxableIncome.
    /// ordinaryTaxable == taxableIncome - taxablePreferential.
    let taxablePreferential: Double
    /// IRMAA/ACA-style MAGI (federal AGI + non-taxable SS + tax-exempt interest), populated EVERY
    /// year — unlike `irmaaMagi`/`acaMagi` which are nil outside their relevance windows.
    let magi: Double
    let taxBreakdown: TaxBreakdown
    let endOfYearBalances: AccountSnapshot
    let actions: [LeverAction]
    /// Number of household members enrolled in Medicare this year (0, 1, or 2).
    /// Set by ProjectionEngine based on each person's age vs their
    /// primaryMedicareEnrollmentAge / spouseMedicareEnrollmentAge.
    /// Used by ConstraintAcceptor to scale annualSurchargePerPerson correctly
    /// for MFJ couples where both spouses are on Medicare.
    let medicareEnrolledCount: Int
    /// Tax that could not be funded from taxable or traditional this year (genuinely insolvent).
    /// nil/0 means fully funded. Never silent "external" funding.
    let underfunded: Double?
    /// Forced required minimum distribution for this year (primary + spouse), pre-tax.
    /// 0 before RMD age. Surfaced separately so the UI can show forced income without
    /// digging it out of the bundled `.traditionalWithdrawal` actions.
    let rmd: Double
    /// Social Security dollars included in taxable income this year (0 when no SS collected or
    /// none is taxable at this provisional-income level). Surfaced so the comparison layer can
    /// flag "SS taxation increased" without recomputing provisional income.
    let taxableSocialSecurity: Double
    /// The ACTUAL traditional->Roth dollars converted this year, clamped to the balance that
    /// was really available (per-spouse convertible amount, net of that spouse's reserved RMD).
    /// `actions` carries the REQUESTED `.rothConversion` amount, which can exceed this once an
    /// IRA drains — this field is the single source of truth for conversion-amount reporting
    /// (B4 root cause 2, 2026-07-13). Defaults to 0 for back-compat with existing call sites.
    let executedRothConversion: Double
    /// The ADDITIONAL traditional-IRA withdrawal taken to pay this year's total tax bill (federal +
    /// state + IRMAA + ACA + NIIT, across pension/RMD/SS/wages/conversion) when the taxable bucket
    /// was short (the Step-7 gross-up, `.taxableThenGrossUp`). Not conversion-tax-only — a year with
    /// zero conversion can still have a gross-up. 0 when taxable funds covered the tax bill in full,
    /// or when `.external` funding is in effect. Surfaced so the UI can disclose total IRA outflow
    /// separately from the conversion amount itself — "convert $Y" alone understates total IRA
    /// depletion when a gross-up fires (A4, 2026-07-13).
    let taxFundingWithdrawal: Double
    /// True when this year's converged tax requirement exceeded available taxable +
    /// traditional assets. The requested conversion is PRESERVED as requested (V2.3 does
    /// not auto-reduce it, which would require solving conversion and funding jointly),
    /// but the year must not be presented as a funded recommendation.
    let isInfeasible: Bool
    /// True when an EARLIER year in this projection was infeasible, so this year's opening
    /// balances descend from a state the household could not actually have reached.
    let dependsOnInfeasibleYear: Bool

    /// A year is presentable as a funded recommendation only when it is neither infeasible
    /// itself nor downstream of an infeasible year.
    var isFullyFunded: Bool { !isInfeasible && !dependsOnInfeasibleYear }

    init(
        year: Int,
        agi: Double,
        acaMagi: Double?,
        irmaaMagi: Double?,
        taxableIncome: Double,
        taxablePreferential: Double = 0,
        magi: Double = 0,
        taxBreakdown: TaxBreakdown,
        endOfYearBalances: AccountSnapshot,
        actions: [LeverAction],
        medicareEnrolledCount: Int = 0,
        underfunded: Double? = nil,
        rmd: Double = 0,
        taxableSocialSecurity: Double = 0,
        executedRothConversion: Double = 0,
        taxFundingWithdrawal: Double = 0,
        isInfeasible: Bool = false,
        dependsOnInfeasibleYear: Bool = false
    ) {
        self.year = year
        self.agi = agi
        self.acaMagi = acaMagi
        self.irmaaMagi = irmaaMagi
        self.taxableIncome = taxableIncome
        self.taxablePreferential = taxablePreferential
        self.magi = magi
        self.taxBreakdown = taxBreakdown
        self.endOfYearBalances = endOfYearBalances
        self.actions = actions
        self.medicareEnrolledCount = medicareEnrolledCount
        self.underfunded = underfunded
        self.rmd = rmd
        self.taxableSocialSecurity = taxableSocialSecurity
        self.executedRothConversion = executedRothConversion
        self.taxFundingWithdrawal = taxFundingWithdrawal
        self.isInfeasible = isInfeasible
        self.dependsOnInfeasibleYear = dependsOnInfeasibleYear
    }
}
