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
@Observable
class AccountsManager {
    // MARK: - Observable Properties

    var iraAccounts: [IRAAccount] = []

    var taxableAccounts: [TaxableAccount] = []

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

    /// Owners whose balances belong to the primary for per-owner math.
    ///
    /// `.joint` is folded in here deliberately.  An IRA has exactly one owner
    /// under IRS rules, so the Owner picker no longer offers Joint for
    /// retirement accounts — but installs in the field already hold joint IRAs,
    /// and a joint account that belongs to no per-owner bucket is counted by
    /// `totalTraditionalIRABalance` while being silently dropped from
    /// `calculateCombinedRMD()`.  Understating a required withdrawal carries a
    /// 25% excise penalty, so those dollars are priced off the primary rather
    /// than disappearing.
    private static let primaryOwners: Set<Owner> = [.primary, .joint]

    var primaryTraditionalIRABalance: Double {
        iraAccounts
            .filter { ($0.accountType == .traditionalIRA || $0.accountType == .traditional401k) && Self.primaryOwners.contains($0.owner) }
            .reduce(0) { $0 + $1.balance }
    }

    var primaryRothBalance: Double {
        iraAccounts
            .filter { ($0.accountType == .rothIRA || $0.accountType == .roth401k) && Self.primaryOwners.contains($0.owner) }
            .reduce(0) { $0 + $1.balance }
    }

    // MARK: - Spouse Teardown

    /// Accounts that need a configured spouse to be priced correctly.
    ///
    /// Drives the confirmation shown when Enable Spouse is switched off, so the
    /// user is told exactly what is affected instead of silently losing the
    /// balances from every household total.
    func spouseAndJointAccountSummary() -> (count: Int, balance: Double) {
        let iras = iraAccounts.filter { $0.owner != .primary }
        let taxables = taxableAccounts.filter { $0.owner != .primary }
        return (
            count: iras.count + taxables.count,
            balance: iras.reduce(0) { $0 + $1.balance } + taxables.reduce(0) { $0 + $1.balance }
        )
    }

    /// Hands spouse- and joint-owned accounts to the primary.
    ///
    /// Used when Enable Spouse is switched off, so no account is ever left
    /// pointing at an owner who no longer exists.  Reassigns rather than
    /// deletes: turning off a setting must never destroy account data.
    func reassignSpouseAndJointAccountsToPrimary() {
        for index in iraAccounts.indices where iraAccounts[index].owner != .primary {
            iraAccounts[index].owner = .primary
        }
        for index in taxableAccounts.indices where taxableAccounts[index].owner != .primary {
            taxableAccounts[index].owner = .primary
        }
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
