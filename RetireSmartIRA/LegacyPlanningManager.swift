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
    @Published var enableLegacyPlanning: Bool = false
    @Published var legacyHeirType: String = "adultChild"
    @Published var legacyHeirTaxRate: Double = 0.24
    @Published var legacySpouseSurvivorYears: Int = 10
}
