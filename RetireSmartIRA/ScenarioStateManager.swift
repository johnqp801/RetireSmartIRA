//
//  ScenarioStateManager.swift
//  RetireSmartIRA
//
//  Manages tax planning scenario state (Roth conversions, withdrawals, QCDs, donations, etc.).
//  Extracted from DataManager as part of God Class decomposition.
//

import SwiftUI
import Foundation
import Combine

@MainActor
class ScenarioStateManager: ObservableObject {
    // MARK: - Published Properties

    @Published var yourRothConversion: Double = 0
    @Published var spouseRothConversion: Double = 0
    @Published var yourExtraWithdrawal: Double = 0
    @Published var spouseExtraWithdrawal: Double = 0
    @Published var yourQCDAmount: Double = 0
    @Published var spouseQCDAmount: Double = 0
    @Published var yourWithdrawalQuarter: Int = 4
    @Published var spouseWithdrawalQuarter: Int = 4
    @Published var yourRothConversionQuarter: Int = 4
    @Published var spouseRothConversionQuarter: Int = 4
    @Published var stockDonationEnabled: Bool = false
    @Published var stockPurchasePrice: Double = 0
    @Published var stockCurrentValue: Double = 0
    @Published var stockPurchaseDate: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
    @Published var cashDonationAmount: Double = 0
    @Published var inheritedExtraWithdrawals: [UUID: Double] = [:]
    @Published var deductionOverride: DeductionChoice? = nil
    @Published var completedActionKeys: Set<String> = []
    @Published var quarterlyPayments: [QuarterlyPayment] = []

    // MARK: - Reset

    func resetScenarioState() {
        yourRothConversion = 0
        spouseRothConversion = 0
        yourExtraWithdrawal = 0
        spouseExtraWithdrawal = 0
        yourQCDAmount = 0
        spouseQCDAmount = 0
        yourWithdrawalQuarter = 4
        spouseWithdrawalQuarter = 4
        yourRothConversionQuarter = 4
        spouseRothConversionQuarter = 4
        stockDonationEnabled = false
        stockPurchasePrice = 0
        stockCurrentValue = 0
        stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        cashDonationAmount = 0
        inheritedExtraWithdrawals = [:]
        deductionOverride = nil
        completedActionKeys = []
    }

    // MARK: - Simple Scenario Aggregations

    var scenarioTotalRothConversion: Double {
        yourRothConversion + spouseRothConversion
    }

    var scenarioTotalWithdrawals: Double {
        yourExtraWithdrawal + spouseExtraWithdrawal
    }

    var scenarioTotalQCD: Double {
        yourQCDAmount + spouseQCDAmount
    }
}
