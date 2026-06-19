//
//  DrawdownProjectionEngine.swift
//  RetireSmartIRA
//
//  Pure drawdown projection logic. No SwiftUI, no persistence, no DataManager dependency.
//

import Foundation

enum DrawdownMode: String, Codable, CaseIterable {
    case rmdOnly = "RMD only"
    case spendingGap = "Spending gap"
    case withdrawalRate = "Withdrawal rate"
}

/// User-entered drawdown settings. Dollar amounts are in TODAY's dollars; the
/// engine inflates them forward. Percents are whole numbers (4.0 == 4%).
struct DrawdownInputs: Equatable {
    var mode: DrawdownMode
    var annualSpendingTarget: Double   // mode .spendingGap (household, today's $)
    var withdrawalRatePercent: Double  // mode .withdrawalRate (e.g., 4.0)
    var inflationRatePercent: Double   // e.g., 2.5
    var horizonYears: Int              // capped at 40 by the caller
}

/// One account owner's starting position. `startingBalance` is the
/// Traditional + 401(k) aggregate attributable to this owner.
struct OwnerState: Equatable {
    var currentAge: Int
    var rmdAge: Int
    var growthRatePercent: Double
    var startingBalance: Double
}

/// Gross guaranteed income (SS + pension) per year offset, already NOMINAL
/// (ramped at SS claiming age and inflated). Out-of-range offsets return 0
/// (treated as no guaranteed income that year).
struct GuaranteedIncomeSchedule: Equatable {
    var annualByYearOffset: [Double]
    func income(atOffset y: Int) -> Double {
        guard y >= 0 && y < annualByYearOffset.count else { return 0 }
        return annualByYearOffset[y]
    }
}

struct DrawdownYear: Equatable {
    let yearOffset: Int
    let calendarYear: Int
    let primaryAge: Int
    let spouseAge: Int?
    let householdBalanceStart: Double  // nominal, before this year's withdrawal
    let householdWithdrawal: Double    // nominal, actual taken
    let plannedPortion: Double         // the desired (gap/rate) portion actually taken
    let rmdForcedPortion: Double       // amount RMD forced above the planned portion
    let guaranteedIncome: Double       // nominal
    let projectedIncome: Double        // withdrawal + guaranteedIncome (IRMAA proxy)
    let householdBalanceEnd: Double    // nominal, after withdrawal + growth
}

struct DrawdownProjection: Equatable {
    let years: [DrawdownYear]
}

enum DrawdownProjectionEngine {
    static func project(inputs: DrawdownInputs,
                        owners: [OwnerState],
                        guaranteed: GuaranteedIncomeSchedule,
                        startCalendarYear: Int) -> DrawdownProjection {
        guard !owners.isEmpty else { return DrawdownProjection(years: []) }
        let infl = inputs.inflationRatePercent / 100.0
        var balances = owners.map { $0.startingBalance }
        var rows: [DrawdownYear] = []

        for y in 0..<inputs.horizonYears {
            let householdStart = balances.reduce(0, +)
            let gIncome = guaranteed.income(atOffset: y)

            let desired: Double
            switch inputs.mode {
            case .rmdOnly:
                // No voluntary withdrawal; RMDs still apply via the per-owner floor below.
                desired = 0
            case .spendingGap:
                let spend = inputs.annualSpendingTarget * pow(1 + infl, Double(y))
                desired = max(0, spend - gIncome)
            case .withdrawalRate:
                desired = householdStart * inputs.withdrawalRatePercent / 100.0
            }

            var householdWithdrawal = 0.0
            var plannedPortion = 0.0
            var rmdForced = 0.0
            for i in owners.indices {
                let age = owners[i].currentAge + y
                let share = householdStart > 0 ? desired * (balances[i] / householdStart) : 0
                let rmd = age >= owners[i].rmdAge
                    ? RMDCalculationEngine.calculateRMD(for: age, balance: balances[i]) : 0
                let actual = max(share, rmd)
                householdWithdrawal += actual
                plannedPortion += min(share, actual)
                rmdForced += max(0, actual - share)
                balances[i] = max(0, balances[i] - actual)
                balances[i] *= (1 + owners[i].growthRatePercent / 100.0)
            }

            rows.append(DrawdownYear(
                yearOffset: y,
                calendarYear: startCalendarYear + y,
                primaryAge: owners[0].currentAge + y,
                spouseAge: owners.count > 1 ? owners[1].currentAge + y : nil,
                householdBalanceStart: householdStart,
                householdWithdrawal: householdWithdrawal,
                plannedPortion: plannedPortion,
                rmdForcedPortion: rmdForced,
                guaranteedIncome: gIncome,
                projectedIncome: householdWithdrawal + gIncome,
                householdBalanceEnd: balances.reduce(0, +)
            ))
        }
        return DrawdownProjection(years: rows)
    }

    /// Inflates a nominal IRMAA tier-1 MAGI threshold forward to a given year offset.
    /// `inflationPercent` is a whole number (10 == 10%). Pure, view-agnostic.
    static func inflatedIrmaaTier1(threshold: Double, inflationPercent: Double, yearOffset: Int) -> Double {
        threshold * pow(1 + inflationPercent / 100, Double(yearOffset))
    }
}
