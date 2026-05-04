//
//  ProfileManager.swift
//  RetireSmartIRA
//
//  Manages user profile data: birth dates, filing status, state, spouse settings.
//  Extracted from DataManager as part of God Class decomposition.
//

import SwiftUI
import Foundation
import Combine

@MainActor
class ProfileManager: ObservableObject {
    // MARK: - Published Properties

    @Published var birthDate: Date = {
        var c = DateComponents(); c.year = 1953; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!
    }()
    @Published var currentYear: Int = Calendar.current.component(.year, from: Date()) {
        didSet { TaxCalculationEngine.loadConfig(forYear: currentYear) }
    }

    /// The tax year this user's plan is configured for. Unlike `currentYear`
    /// (which tracks the system clock and therefore rolls over on January 1),
    /// `planYear` is persisted and stable — once set, it only changes when
    /// the user (or a future "start new tax year" flow) explicitly bumps it.
    /// Drives year-specific UI labels ("2025 State Tax Balance", "auto-calculated
    /// for 2026") so labels don't go stale when the calendar ticks forward
    /// without the user actually starting a new plan.
    @Published var planYear: Int = Calendar.current.component(.year, from: Date())

    /// The tax year one before `planYear`. Convenience for "prior year" UI labels.
    var priorPlanYear: Int { planYear - 1 }
    @Published var filingStatus: FilingStatus = .single
    @Published var selectedState: USState = .california
    @Published var userName: String = ""
    @Published var spouseName: String = ""
    @Published var spouseBirthDate: Date = {
        var c = DateComponents(); c.year = 1955; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!
    }()
    @Published var enableSpouse: Bool = false

    // MARK: - Computed Properties

    var birthYear: Int {
        Calendar.current.component(.year, from: birthDate)
    }

    var spouseBirthYear: Int {
        Calendar.current.component(.year, from: spouseBirthDate)
    }

    var currentAge: Int {
        currentYear - birthYear
    }

    var rmdAge: Int {
        // SECURE Act 2.0 RMD age dispatcher by birth year cohort.
        if birthYear >= 1960 {
            return 75
        } else if birthYear >= 1951 {
            return 73
        } else if birthYear >= 1950 || (birthYear == 1949) {
            // Born July 1, 1949 - 1950: SECURE Act 1.0 raised from 70½ to 72.
            // (Note: precise SECURE 1.0 boundary is July 1, 1949. We approximate
            // by treating all of 1949 as the new-cohort; the half-year nuance
            // would require birth-month data, which the profile doesn't store.)
            return 72
        } else {
            // Born before 1949: pre-SECURE rules, RMD age 70½. Returned as 70
            // here since rmdAge is Int. Practical impact for V2.0 is minimal —
            // these users are 76+ and already deep in their RMDs; the engine's
            // job is to plan FORWARD, not retroactively model past distributions.
            return 70
        }
    }

    var yearsUntilRMD: Int {
        max(0, rmdAge - currentAge)
    }

    var isRMDRequired: Bool {
        currentAge >= rmdAge
    }

    func hasReachedAge70AndHalf(from dob: Date) -> Bool {
        let calendar = Calendar.current
        guard let seventieth = calendar.date(byAdding: .year, value: 70, to: dob) else { return false }
        guard let seventyAndHalf = calendar.date(byAdding: .month, value: 6, to: seventieth) else { return false }
        return Date() >= seventyAndHalf
    }

    var isQCDEligible: Bool {
        hasReachedAge70AndHalf(from: birthDate)
    }

    // MARK: - Spouse Computed Properties

    var spouseCurrentAge: Int {
        guard enableSpouse else { return 0 }
        return currentYear - spouseBirthYear
    }

    var spouseRmdAge: Int {
        guard enableSpouse else { return 0 }
        // SECURE Act 2.0 RMD age dispatcher by birth year cohort (mirrors rmdAge above).
        if spouseBirthYear >= 1960 {
            return 75
        } else if spouseBirthYear >= 1951 {
            return 73
        } else if spouseBirthYear >= 1950 || (spouseBirthYear == 1949) {
            return 72
        } else {
            return 70
        }
    }

    var spouseYearsUntilRMD: Int {
        guard enableSpouse else { return 0 }
        return max(0, spouseRmdAge - spouseCurrentAge)
    }

    var spouseIsRMDRequired: Bool {
        guard enableSpouse else { return false }
        return spouseCurrentAge >= spouseRmdAge
    }

    var spouseIsQCDEligible: Bool {
        guard enableSpouse else { return false }
        return hasReachedAge70AndHalf(from: spouseBirthDate)
    }

    // MARK: - State Tax Config

    var selectedStateConfig: StateTaxConfig {
        StateTaxData.config(for: selectedState)
    }
}
