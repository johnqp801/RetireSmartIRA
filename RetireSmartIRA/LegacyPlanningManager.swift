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
@Observable
class LegacyPlanningManager {
    var enableLegacyPlanning: Bool = true
    var legacyHeirType: String = "adultChild"
    var legacyHeirEstimatedSalary: Double = 75_000
    var legacyHeirFilingStatus: FilingStatus = .single
    /// Optional. If set and the heir is younger than 24 at the projected inheritance year,
    /// the Legacy Impact view surfaces a Kiddie Tax disclaimer.
    var legacyHeirBirthYear: Int? = nil
    var legacySpouseSurvivorYears: Int = 10

    /// Independent growth rate for legacy projections.
    /// `nil` means "use the RMD tab's primaryGrowthRate" (backwards-compatible default).
    /// Once the user adjusts this in the Legacy Impact card, it becomes independent.
    var legacyGrowthRate: Double?
}
