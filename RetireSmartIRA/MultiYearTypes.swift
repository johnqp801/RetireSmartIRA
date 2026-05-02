//
//  MultiYearTypes.swift
//  RetireSmartIRA
//
//  Foundation types for the Multi-Year Tax Strategy engine.
//  Pure value types, no SwiftUI / DataManager dependencies.
//

import Foundation

// MARK: - Withdrawal ordering rule (user-facing preset, per Q8 brainstorm decision)

enum WithdrawalOrderingRule: String, Codable, CaseIterable, Equatable {
    case taxEfficient = "tax_efficient"
    case depleteTradFirst = "deplete_trad_first"
    case preserveRoth = "preserve_roth"
    case proportional = "proportional"

    static let `default`: WithdrawalOrderingRule = .taxEfficient
}

// MARK: - Lever actions (per-year recommended moves the engine emits)

enum LeverAction: Codable, Equatable {
    case rothConversion(amount: Double)
    case traditionalWithdrawal(amount: Double)
    case taxableWithdrawal(amount: Double)
    case rothWithdrawal(amount: Double)
    case hsaContribution(amount: Double)
    case fourOhOneKContribution(amount: Double)
    case deferSocialSecurity
    case claimSocialSecurity(spouse: SpouseID)
}

// MARK: - Constraint types (soft-constraint hits the engine accepted)

enum ConstraintType: Codable, Equatable {
    case irmaaTier(level: Int)
    case acaCliff
    case bracketOverrun(fromBracket: Int, toBracket: Int)
}
