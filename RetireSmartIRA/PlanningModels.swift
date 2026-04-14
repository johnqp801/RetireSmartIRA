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

// MARK: - Estimated Payment Schedule

/// State-specific quarterly estimated tax payment percentages.
/// Federal always uses equal quarters (25/25/25/25).
/// California requires 30/40/0/30 (no September payment).
struct EstimatedPaymentSchedule: Equatable, Sendable {
    let q1Pct: Double
    let q2Pct: Double
    let q3Pct: Double
    let q4Pct: Double

    init(q1Pct: Double, q2Pct: Double, q3Pct: Double, q4Pct: Double) {
        precondition(abs((q1Pct + q2Pct + q3Pct + q4Pct) - 1.0) < 0.001,
                     "Quarterly percentages must sum to 1.0, got \(q1Pct + q2Pct + q3Pct + q4Pct)")
        self.q1Pct = q1Pct
        self.q2Pct = q2Pct
        self.q3Pct = q3Pct
        self.q4Pct = q4Pct
    }

    subscript(quarter: Int) -> Double {
        switch quarter {
        case 1: return q1Pct
        case 2: return q2Pct
        case 3: return q3Pct
        case 4: return q4Pct
        default: return 0
        }
    }

    /// Federal and most states: equal 25% per quarter.
    static let federal = EstimatedPaymentSchedule(q1Pct: 0.25, q2Pct: 0.25, q3Pct: 0.25, q4Pct: 0.25)

    /// California FTB: 30% / 40% / 0% / 30% (no September payment).
    static let california = EstimatedPaymentSchedule(q1Pct: 0.30, q2Pct: 0.40, q3Pct: 0.0, q4Pct: 0.30)

    /// Human-readable label, e.g. "30/40/0/30".
    var label: String {
        [q1Pct, q2Pct, q3Pct, q4Pct]
            .map { String(format: "%.0f", $0 * 100) }
            .joined(separator: "/")
    }
}

// MARK: - Safe Harbor Method

/// Which safe harbor rule the user chooses for estimated tax calculations.
enum SafeHarborMethod: String, Codable, CaseIterable {
    /// Pay ≥ 90% of current year's estimated tax liability.
    case currentYear90

    /// Pay ≥ 100% of prior year's total tax (110% if prior-year AGI > $150k MFJ / $75k MFS).
    case priorYear100_110

    var label: String {
        switch self {
        case .currentYear90: return "90% of Current Year"
        case .priorYear100_110: return "100%/110% of Prior Year"
        }
    }
}

// MARK: - State Safe Harbor Rule

/// State-specific safe harbor rule for the prior-year estimated tax method.
/// Each state has its own rules for how much of prior-year tax must be paid
/// via estimated payments to avoid underpayment penalties.
enum StateSafeHarborRule: Equatable, Sendable {
    /// Mirrors federal: 100% if prior AGI ≤ $150k, 110% if > $150k.
    /// States: NY, IL, MN, WI, SC, MI, IN, AL, DE, MO, NE, IA, DC
    case mirrorsFederal

    /// Fixed rate for all income levels.
    /// Examples: 1.00 for CT, OH, VA; 1.10 for MD.
    case flatRate(Double)

    /// AGI threshold with different rates above/below (like federal but different threshold).
    /// Example: KY uses $250k instead of federal's $150k.
    case agiThreshold(threshold: Double, lowRate: Double, highRate: Double)

    /// Mirrors federal 100%/110% rule, but prior-year safe harbor is completely
    /// unavailable when current-year AGI exceeds the disqualification threshold.
    /// CA only: if current-year AGI ≥ $1M ($500k MFS), must use current-year method.
    case mirrorsFederalWithDisqualification(disqualifyAGI: Double)

    /// No estimated tax penalty — payments are voluntary.
    /// ID only.
    case noPenalty

    /// Evaluate the rule for a given prior-year AGI and current-year AGI.
    /// Returns the required multiplier (e.g., 1.00 or 1.10), 0 for no penalty states,
    /// or nil if prior-year safe harbor is unavailable (CA $1M disqualification).
    func priorYearRate(priorAGI: Double, currentAGI: Double = 0) -> Double? {
        switch self {
        case .mirrorsFederal:
            return priorAGI > 150_000 ? 1.10 : 1.00
        case .flatRate(let rate):
            return rate
        case .agiThreshold(let threshold, let low, let high):
            return priorAGI > threshold ? high : low
        case .mirrorsFederalWithDisqualification(let disqualifyAGI):
            if currentAGI >= disqualifyAGI { return nil }
            return priorAGI > 150_000 ? 1.10 : 1.00
        case .noPenalty:
            return 0
        }
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
