//
//  InheritedAccountInput.swift
//  RetireSmartIRA
//
//  Pure value-type snapshot of one inherited IRA for the multi-year engine.
//  Carries exactly the fields RMDCalculationEngine.calculateInheritedIRARMD needs,
//  so the multi-year distribution schedule and the single-year RMD calculator share
//  one rules implementation and cannot drift apart.
//

import Foundation

struct InheritedAccountInput: Equatable, Sendable {
    let balance: Double
    let isRoth: Bool
    let beneficiaryType: BeneficiaryType
    let decedentRBDStatus: DecedentRBDStatus?
    let yearOfInheritance: Int
    let decedentBirthYear: Int?
    let beneficiaryBirthYear: Int
    let minorChildMajorityYear: Int?

    init(
        balance: Double,
        isRoth: Bool,
        beneficiaryType: BeneficiaryType,
        decedentRBDStatus: DecedentRBDStatus? = nil,
        yearOfInheritance: Int,
        decedentBirthYear: Int? = nil,
        beneficiaryBirthYear: Int,
        minorChildMajorityYear: Int? = nil
    ) {
        self.balance = balance
        self.isRoth = isRoth
        self.beneficiaryType = beneficiaryType
        self.decedentRBDStatus = decedentRBDStatus
        self.yearOfInheritance = yearOfInheritance
        self.decedentBirthYear = decedentBirthYear
        self.beneficiaryBirthYear = beneficiaryBirthYear
        self.minorChildMajorityYear = minorChildMajorityYear
    }

    /// Fails unless the account is inherited AND carries the metadata the schedule
    /// needs. Accounts that fail here keep the legacy roll-up into the owner buckets
    /// (uniform-table RMDs) so their balance is never silently dropped.
    init?(account: IRAAccount) {
        guard account.accountType.isInherited,
              let beneficiaryType = account.beneficiaryType,
              let yearOfInheritance = account.yearOfInheritance,
              let beneficiaryBirthYear = account.beneficiaryBirthYear else { return nil }
        self.init(
            balance: account.balance,
            isRoth: account.accountType == .inheritedRothIRA,
            beneficiaryType: beneficiaryType,
            decedentRBDStatus: account.decedentRBDStatus,
            yearOfInheritance: yearOfInheritance,
            decedentBirthYear: account.decedentBirthYear,
            beneficiaryBirthYear: beneficiaryBirthYear,
            minorChildMajorityYear: account.minorChildMajorityYear
        )
    }

    /// This year's forced distribution for a running balance, clamped to the balance.
    /// Delegates to the single-year rules engine (single-life factors, 10-year rule,
    /// pre-SECURE stretch, RBD branching, Roth deeming) via an IRAAccount snapshot.
    func requiredDistribution(forYear year: Int, balance runningBalance: Double) -> Double {
        guard runningBalance > 0 else { return 0 }
        let snapshot = IRAAccount(
            name: "engine-inherited",
            accountType: isRoth ? .inheritedRothIRA : .inheritedTraditionalIRA,
            balance: runningBalance,
            beneficiaryType: beneficiaryType,
            decedentRBDStatus: decedentRBDStatus,
            yearOfInheritance: yearOfInheritance,
            decedentBirthYear: decedentBirthYear,
            beneficiaryBirthYear: beneficiaryBirthYear,
            minorChildMajorityYear: minorChildMajorityYear
        )
        let result = RMDCalculationEngine.calculateInheritedIRARMD(account: snapshot, forYear: year)
        return min(max(0, result.annualRMD), runningBalance)
    }
}
