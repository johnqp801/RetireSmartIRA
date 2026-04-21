//
//  LegacyPlanningManager.swift
//  RetireSmartIRA
//
//  Manages legacy planning configuration (heir type, salary, filing status, etc.).
//  Extracted from DataManager as part of God Class decomposition.
//

import SwiftUI
import Foundation
import Combine

@MainActor
class LegacyPlanningManager: ObservableObject {
    @Published var enableLegacyPlanning: Bool = true
    @Published var legacyHeirType: String = "adultChild"
    @Published var legacyHeirEstimatedSalary: Double = 75_000
    @Published var legacyHeirFilingStatus: FilingStatus = .single
    /// Optional. If set and the heir is younger than 24 at the projected inheritance year,
    /// the Legacy Impact view surfaces a Kiddie Tax disclaimer.
    @Published var legacyHeirBirthYear: Int? = nil
    @Published var legacySpouseSurvivorYears: Int = 10

    /// Independent growth rate for legacy projections.
    /// `nil` means "use the RMD tab's primaryGrowthRate" (backwards-compatible default).
    /// Once the user adjusts this in the Legacy Impact card, it becomes independent.
    @Published var legacyGrowthRate: Double?
}
