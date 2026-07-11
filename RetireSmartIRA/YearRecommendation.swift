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
        taxableSocialSecurity: Double = 0
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
    }
}
