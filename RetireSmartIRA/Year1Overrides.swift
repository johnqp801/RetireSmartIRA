//
//  Year1Overrides.swift
//  RetireSmartIRA
//
//  Hashable bundle of Year 1 lever values, rounded to nearest dollar
//  before hashing/equality to absorb SwiftUI slider sub-dollar drift.
//

import Foundation

struct Year1Overrides: Hashable {
    let primaryRothConversion: Double
    let spouseRothConversion: Double
    let primaryWithdrawal: Double
    let spouseWithdrawal: Double
    let primaryQCD: Double
    let spouseQCD: Double

    func hash(into hasher: inout Hasher) {
        hasher.combine(primaryRothConversion.rounded())
        hasher.combine(spouseRothConversion.rounded())
        hasher.combine(primaryWithdrawal.rounded())
        hasher.combine(spouseWithdrawal.rounded())
        hasher.combine(primaryQCD.rounded())
        hasher.combine(spouseQCD.rounded())
    }

    static func == (lhs: Year1Overrides, rhs: Year1Overrides) -> Bool {
        lhs.primaryRothConversion.rounded() == rhs.primaryRothConversion.rounded()
            && lhs.spouseRothConversion.rounded() == rhs.spouseRothConversion.rounded()
            && lhs.primaryWithdrawal.rounded() == rhs.primaryWithdrawal.rounded()
            && lhs.spouseWithdrawal.rounded() == rhs.spouseWithdrawal.rounded()
            && lhs.primaryQCD.rounded() == rhs.primaryQCD.rounded()
            && lhs.spouseQCD.rounded() == rhs.spouseQCD.rounded()
    }
}

extension Year1Overrides {
    /// Construct from a DataManager snapshot. Reads the same bindings
    /// the Year1QuickEditor sliders write to.
    static func from(dataManager: DataManager) -> Year1Overrides {
        Year1Overrides(
            primaryRothConversion: dataManager.yourRothConversion,
            spouseRothConversion: dataManager.enableSpouse ? dataManager.spouseRothConversion : 0,
            primaryWithdrawal: dataManager.yourExtraWithdrawal,
            spouseWithdrawal: dataManager.enableSpouse ? dataManager.spouseExtraWithdrawal : 0,
            primaryQCD: dataManager.yourQCDAmount,
            spouseQCD: dataManager.enableSpouse ? dataManager.spouseQCDAmount : 0
        )
    }
}
