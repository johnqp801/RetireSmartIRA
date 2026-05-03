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

    // MARK: - 1.9 Contribution Levers

    @Published var yourTraditional401kContribution: Double = 0
    @Published var spouseTraditional401kContribution: Double = 0
    @Published var yourTraditionalIRAContribution: Double = 0
    @Published var spouseTraditionalIRAContribution: Double = 0
    @Published var yourHSAContribution: Double = 0
    @Published var spouseHSAContribution: Double = 0

    // MARK: - 1.9 Medicare Plan Type (per spouse)

    @Published var yourMedicarePlanType: MedicarePlanType = .preMedicare
    @Published var spouseMedicarePlanType: MedicarePlanType = .preMedicare

    // MARK: - 1.9 Medicare Premium Overrides (per spouse, optional)
    //
    // Nil = use config default. Non-nil = user-corrected value.

    @Published var yourMedicarePartBOverride: Double? = nil
    @Published var spouseMedicarePartBOverride: Double? = nil
    @Published var yourMedicarePartDOverride: Double? = nil
    @Published var spouseMedicarePartDOverride: Double? = nil
    @Published var yourMedigapOverride: Double? = nil
    @Published var spouseMedigapOverride: Double? = nil
    @Published var yourAdvantageOverride: Double? = nil
    @Published var spouseAdvantageOverride: Double? = nil

    // MARK: - 1.9 ACA Marketplace Modeling

    @Published var enableACAModeling: Bool = false
    @Published var acaHouseholdSize: Int = 1
    @Published var acaBenchmarkSilverPlanMonthlyOverride: Double? = nil

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
        yourTraditional401kContribution = 0
        spouseTraditional401kContribution = 0
        yourTraditionalIRAContribution = 0
        spouseTraditionalIRAContribution = 0
        yourHSAContribution = 0
        spouseHSAContribution = 0
        yourMedicarePlanType = .preMedicare
        spouseMedicarePlanType = .preMedicare
        yourMedicarePartBOverride = nil
        spouseMedicarePartBOverride = nil
        yourMedicarePartDOverride = nil
        spouseMedicarePartDOverride = nil
        yourMedigapOverride = nil
        spouseMedigapOverride = nil
        yourAdvantageOverride = nil
        spouseAdvantageOverride = nil
        enableACAModeling = false
        acaHouseholdSize = 1
        acaBenchmarkSilverPlanMonthlyOverride = nil
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

    // MARK: - 1.9 Above-the-Line Aggregations

    var scenarioTotalTraditional401k: Double {
        yourTraditional401kContribution + spouseTraditional401kContribution
    }

    var scenarioTotalTraditionalIRA: Double {
        yourTraditionalIRAContribution + spouseTraditionalIRAContribution
    }

    var scenarioTotalHSA: Double {
        yourHSAContribution + spouseHSAContribution
    }

    /// All 1.9 above-the-line deductions: 401(k) + IRA + HSA combined for both spouses.
    var scenarioTotalAboveTheLineDeductions: Double {
        scenarioTotalTraditional401k + scenarioTotalTraditionalIRA + scenarioTotalHSA
    }
}
