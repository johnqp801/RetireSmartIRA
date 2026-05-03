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
    /// Number of household members enrolled in Medicare this year (0, 1, or 2).
    /// Set by ProjectionEngine based on each person's age vs their
    /// primaryMedicareEnrollmentAge / spouseMedicareEnrollmentAge.
    /// Used by ConstraintAcceptor to scale annualSurchargePerPerson correctly
    /// for MFJ couples where both spouses are on Medicare.
    let medicareEnrolledCount: Int

    init(
        year: Int,
        agi: Double,
        acaMagi: Double?,
        irmaaMagi: Double?,
        taxableIncome: Double,
        taxBreakdown: TaxBreakdown,
        endOfYearBalances: AccountSnapshot,
        actions: [LeverAction],
        medicareEnrolledCount: Int = 0
    ) {
        self.year = year
        self.agi = agi
        self.acaMagi = acaMagi
        self.irmaaMagi = irmaaMagi
        self.taxableIncome = taxableIncome
        self.taxBreakdown = taxBreakdown
        self.endOfYearBalances = endOfYearBalances
        self.actions = actions
        self.medicareEnrolledCount = medicareEnrolledCount
    }
}
