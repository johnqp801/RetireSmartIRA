//
//  LegacyPlanningManager.swift
//  RetireSmartIRA
//
//  Manages legacy planning configuration (heir type, tax rate, etc.).
//  Extracted from DataManager as part of God Class decomposition.
//

import SwiftUI
import Foundation
import Combine

@MainActor
class LegacyPlanningManager: ObservableObject {
    @Published var enableLegacyPlanning: Bool = true
    @Published var legacyHeirType: String = "adultChild"
    @Published var legacyHeirTaxRate: Double = 0.24
    @Published var legacyHeirEstimatedSalary: Double = 75_000
    @Published var legacyHeirFilingStatus: FilingStatus = .single
    @Published var legacySpouseSurvivorYears: Int = 10

    /// Independent growth rate for legacy projections.
    /// `nil` means "use the RMD tab's primaryGrowthRate" (backwards-compatible default).
    /// Once the user adjusts this in the Legacy Impact card, it becomes independent.
    @Published var legacyGrowthRate: Double?
}
