//
//  AccountsManager.swift
//  RetireSmartIRA
//
//  Manages IRA account data and balance aggregations.
//  Extracted from DataManager as part of God Class decomposition.
//

import SwiftUI
import Foundation
import Combine

@MainActor
class AccountsManager: ObservableObject {
    // MARK: - Published Properties

    @Published var iraAccounts: [IRAAccount] = []

    // MARK: - Balance Aggregations (all accounts)

    var totalTraditionalIRABalance: Double {
        iraAccounts
            .filter { $0.accountType == .traditionalIRA || $0.accountType == .traditional401k }
            .reduce(0) { $0 + $1.balance }
    }

    var totalRothBalance: Double {
        iraAccounts
            .filter { $0.accountType == .rothIRA || $0.accountType == .roth401k }
            .reduce(0) { $0 + $1.balance }
    }

    // MARK: - Balance by Owner (primary — no enableSpouse guard needed)

    var primaryTraditionalIRABalance: Double {
        iraAccounts
            .filter { ($0.accountType == .traditionalIRA || $0.accountType == .traditional401k) && $0.owner == .primary }
            .reduce(0) { $0 + $1.balance }
    }

    var primaryRothBalance: Double {
        iraAccounts
            .filter { ($0.accountType == .rothIRA || $0.accountType == .roth401k) && $0.owner == .primary }
            .reduce(0) { $0 + $1.balance }
    }

    // MARK: - Balance by Owner (spouse — requires enableSpouse check by caller)

    func spouseTraditionalIRABalance(enableSpouse: Bool) -> Double {
        guard enableSpouse else { return 0 }
        return iraAccounts
            .filter { ($0.accountType == .traditionalIRA || $0.accountType == .traditional401k) && $0.owner == .spouse }
            .reduce(0) { $0 + $1.balance }
    }

    func spouseRothBalance(enableSpouse: Bool) -> Double {
        guard enableSpouse else { return 0 }
        return iraAccounts
            .filter { ($0.accountType == .rothIRA || $0.accountType == .roth401k) && $0.owner == .spouse }
            .reduce(0) { $0 + $1.balance }
    }

    // MARK: - Inherited IRA Balances

    var primaryInheritedTraditionalBalance: Double {
        iraAccounts
            .filter { $0.accountType == .inheritedTraditionalIRA && $0.owner == .primary }
            .reduce(0) { $0 + $1.balance }
    }

    func spouseInheritedTraditionalBalance(enableSpouse: Bool) -> Double {
        guard enableSpouse else { return 0 }
        return iraAccounts
            .filter { $0.accountType == .inheritedTraditionalIRA && $0.owner == .spouse }
            .reduce(0) { $0 + $1.balance }
    }

    var primaryInheritedRothBalance: Double {
        iraAccounts
            .filter { $0.accountType == .inheritedRothIRA && $0.owner == .primary }
            .reduce(0) { $0 + $1.balance }
    }

    func spouseInheritedRothBalance(enableSpouse: Bool) -> Double {
        guard enableSpouse else { return 0 }
        return iraAccounts
            .filter { $0.accountType == .inheritedRothIRA && $0.owner == .spouse }
            .reduce(0) { $0 + $1.balance }
    }

    var totalInheritedBalance: Double {
        iraAccounts
            .filter { $0.accountType.isInherited }
            .reduce(0) { $0 + $1.balance }
    }

    var inheritedAccounts: [IRAAccount] {
        iraAccounts.filter { $0.accountType.isInherited }
    }

    var hasInheritedAccounts: Bool {
        iraAccounts.contains { $0.accountType.isInherited }
    }
}
