//
//  GrowthRatesManager.swift
//  RetireSmartIRA
//
//  Manages investment growth rate assumptions.
//  Extracted from DataManager as part of God Class decomposition.
//

import SwiftUI
import Foundation
import Combine

@MainActor
@Observable
class GrowthRatesManager {
    var primaryGrowthRate: Double = 8.0
    var spouseGrowthRate: Double = 8.0

    // MARK: - Drawdown projection settings (V1.9, Task 8)
    /// How the drawdown projection determines each year's desired withdrawal.
    var drawdownMode: DrawdownMode = .spendingGap
    /// Household annual spending target in today's dollars (mode .spendingGap).
    var drawdownSpendingTarget: Double = 0
    /// Annual withdrawal rate as a whole percent, e.g. 4.0 (mode .withdrawalRate).
    var drawdownRatePercent: Double = 4.0
    /// Inflation rate applied to spending target and guaranteed income, whole percent.
    var drawdownInflationPercent: Double = 2.5

    /// After-tax return on money kept in a taxable account (opportunity cost of conversion).
    /// Derived as 5/8 of the pretax investment return to reflect tax drag.
    var taxableAccountGrowthRate: Double {
        primaryGrowthRate * 5.0 / 8.0
    }
}
