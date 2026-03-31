//
//  PlanningModels.swift
//  RetireSmartIRA
//
//  Planning, quarterly, and setup data models extracted from DataManager.
//

import Foundation

// MARK: - Setup Progress

struct SetupProgress {
    let hasSetBirthDate: Bool
    let hasSSBenefits: Bool
    let hasAccounts: Bool
    let hasIncomeSources: Bool
    let hasDeductions: Bool

    var completedSteps: Int {
        [hasSetBirthDate, hasSSBenefits, hasAccounts, hasIncomeSources, hasDeductions].filter { $0 }.count
    }
    var totalSteps: Int { 5 }
    var isComplete: Bool { completedSteps == totalSteps }
}

// MARK: - Quarterly Payments

struct QuarterlyBreakdown {
    var q1: Double = 0
    var q2: Double = 0
    var q3: Double = 0
    var q4: Double = 0

    var total: Double { q1 + q2 + q3 + q4 }

    subscript(quarter: Int) -> Double {
        get {
            switch quarter {
            case 1: return q1
            case 2: return q2
            case 3: return q3
            case 4: return q4
            default: return 0
            }
        }
        set {
            switch quarter {
            case 1: q1 = newValue
            case 2: q2 = newValue
            case 3: q3 = newValue
            case 4: q4 = newValue
            default: break
            }
        }
    }
}

struct FederalStateQuarterlyBreakdown {
    var federal: QuarterlyBreakdown = QuarterlyBreakdown()
    var state: QuarterlyBreakdown = QuarterlyBreakdown()

    /// Combined payment per quarter (backward-compatible)
    var q1: Double { federal.q1 + state.q1 }
    var q2: Double { federal.q2 + state.q2 }
    var q3: Double { federal.q3 + state.q3 }
    var q4: Double { federal.q4 + state.q4 }

    var total: Double { federal.total + state.total }
    var federalTotal: Double { federal.total }
    var stateTotal: Double { state.total }

    subscript(quarter: Int) -> Double { federal[quarter] + state[quarter] }
}

struct QuarterlyPayment: Identifiable, Codable {
    let id: UUID
    var quarter: Int // 1-4
    var year: Int
    var dueDate: Date
    var estimatedAmount: Double
    var paidAmount: Double
    var isPaid: Bool

    init(id: UUID = UUID(), quarter: Int, year: Int, dueDate: Date, estimatedAmount: Double, paidAmount: Double = 0, isPaid: Bool = false) {
        self.id = id
        self.quarter = quarter
        self.year = year
        self.dueDate = dueDate
        self.estimatedAmount = estimatedAmount
        self.paidAmount = paidAmount
        self.isPaid = isPaid
    }
}

// MARK: - Action Items

struct ActionItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let deadline: String
    let category: ActionCategory
}

enum ActionCategory: String {
    case rmd, rothConversion, qcd, withdrawal, estimatedTax, charitable
}

// MARK: - Legacy Planning

struct LegacyCompoundingPoint: Identifiable {
    let id = UUID()
    let year: Int
    let rothValue: Double       // Tax-free value to heir
    let traditionalValue: Double // After-tax value to heir + tax money kept
}

// MARK: - RMD

struct InheritedRMDResult {
    let annualRMD: Double           // required withdrawal this year (0 if none)
    let mustEmptyByYear: Int?       // year account must be fully emptied (nil if lifetime stretch)
    let yearsRemaining: Int?        // years until must-empty deadline
    let rule: String                // human-readable description of the rule
}
