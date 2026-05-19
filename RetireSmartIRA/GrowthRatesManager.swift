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

    /// After-tax return on money kept in a taxable account (opportunity cost of conversion).
    /// Derived as 5/8 of the pretax investment return to reflect tax drag.
    var taxableAccountGrowthRate: Double {
        primaryGrowthRate * 5.0 / 8.0
    }
}
