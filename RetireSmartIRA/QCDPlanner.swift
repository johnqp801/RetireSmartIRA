//
//  QCDPlanner.swift
//  RetireSmartIRA
//
//  Pure computation of the per-year, per-spouse Qualified Charitable Distribution from a
//  household CharitableGivingPlan. No engine state — the ProjectionEngine calls this, then
//  debits the IRA and reduces the taxable RMD. Mirrors the single-year QCD domain model.
//

import Foundation

enum QCDPlanner {

    struct YearlyQCD: Equatable, Sendable {
        var primaryQCD: Double
        var spouseQCD: Double
        var total: Double { primaryQCD + spouseQCD }
    }

    /// Compute the per-spouse QCD for a projected year.
    /// - primaryRMD/spouseRMD: each spouse's required owner RMD this year (the %-of-RMD basis and
    ///   what the QCD satisfies).
    /// - primaryIRA/spouseIRA: each spouse's available IRA balance (the QCD source).
    /// - primaryEligible/spouseEligible: 70½ eligibility this year.
    /// - qcdLimit: per-person annual QCD limit for the year.
    /// - inflationFactor: (1+cpi)^yearsFromBase, applied to a fixed target when maintainRealValue.
    static func plan(
        _ plan: CharitableGivingPlan,
        primaryRMD: Double, spouseRMD: Double,
        primaryIRA: Double, spouseIRA: Double,
        primaryEligible: Bool, spouseEligible: Bool,
        qcdLimit: Double, inflationFactor: Double
    ) -> YearlyQCD {
        guard plan.hasGiving else { return YearlyQCD(primaryQCD: 0, spouseQCD: 0) }

        // 1. Year's giving target.
        let target: Double
        switch plan.intent {
        case .fixedAnnualAmount(let amount):
            target = max(0, plan.maintainRealValue ? amount * inflationFactor : amount)
        case .percentOfRMD(let fraction):
            target = max(0, fraction) * max(0, primaryRMD + spouseRMD)
        }
        guard target > 0 else { return YearlyQCD(primaryQCD: 0, spouseQCD: 0) }

        // 2. Amount to route through QCDs (remainder of the target would be cash — not modeled here).
        let qcdBudget: Double
        switch plan.funding {
        case .qcdFirst:            qcdBudget = target
        case .fixedQCD(let amt):   qcdBudget = min(max(0, amt), target)
        }

        // 3. Per-spouse, primary IRA first, each capped by (budget share, annual limit, IRA balance),
        //    gated on 70½ eligibility.
        let primaryQCD = primaryEligible ? min(qcdBudget, qcdLimit, max(0, primaryIRA)) : 0
        let remaining = max(0, qcdBudget - primaryQCD)
        let spouseQCD = spouseEligible ? min(remaining, qcdLimit, max(0, spouseIRA)) : 0
        return YearlyQCD(primaryQCD: primaryQCD, spouseQCD: spouseQCD)
    }

    /// Month-precise: has the person reached age 70½ by Dec 31 of `year`?
    static func isEligible(birthDate: Date, byEndOf year: Int, calendar: Calendar = .current) -> Bool {
        guard let seventieth = calendar.date(byAdding: .year, value: 70, to: birthDate),
              let seventyAndHalf = calendar.date(byAdding: .month, value: 6, to: seventieth),
              let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
        else { return false }
        return yearEnd >= seventyAndHalf
    }
}
