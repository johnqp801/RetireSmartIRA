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
@Observable
class ScenarioStateManager {
    // MARK: - Observable Properties
    // SPIKE(observable): migrated from ObservableObject + @Published to @Observable macro.

    var yourRothConversion: Double = 0
    var spouseRothConversion: Double = 0
    var yourExtraWithdrawal: Double = 0
    var spouseExtraWithdrawal: Double = 0
    var yourQCDAmount: Double = 0
    var spouseQCDAmount: Double = 0
    var yourWithdrawalQuarter: Int = 4
    var spouseWithdrawalQuarter: Int = 4
    var yourRothConversionQuarter: Int = 4
    var spouseRothConversionQuarter: Int = 4
    var stockDonationEnabled: Bool = false
    var stockPurchasePrice: Double = 0
    var stockCurrentValue: Double = 0
    var stockPurchaseDate: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
    var cashDonationAmount: Double = 0
    var inheritedExtraWithdrawals: [UUID: Double] = [:]
    var deductionOverride: DeductionChoice? = nil
    var completedActionKeys: Set<String> = []
    var quarterlyPayments: [QuarterlyPayment] = []

    // MARK: - 1.9 Contribution Levers

    var yourTraditional401kContribution: Double = 0
    var spouseTraditional401kContribution: Double = 0
    var yourTraditionalIRAContribution: Double = 0
    var spouseTraditionalIRAContribution: Double = 0
    var yourHSAContribution: Double = 0
    var spouseHSAContribution: Double = 0

    // R3: Other above-the-line AGI reducers (educator expenses, student-loan interest,
    // self-employed health-insurance premiums, alimony pre-2019, military moving, etc.).
    // Single number per spouse — user enters total of their niche deductions.
    var yourOtherPreTaxDeductions: Double = 0
    var spouseOtherPreTaxDeductions: Double = 0

    // MARK: - 1.9 Medicare Plan Type (per spouse)

    var yourMedicarePlanType: MedicarePlanType = .preMedicare
    var spouseMedicarePlanType: MedicarePlanType = .preMedicare

    // MARK: - 1.9 Medicare Premium Overrides (per spouse, optional)
    //
    // Nil = use config default. Non-nil = user-corrected value.

    var yourMedicarePartBOverride: Double? = nil
    var spouseMedicarePartBOverride: Double? = nil
    var yourMedicarePartDOverride: Double? = nil
    var spouseMedicarePartDOverride: Double? = nil
    var yourMedigapOverride: Double? = nil
    var spouseMedigapOverride: Double? = nil
    var yourAdvantageOverride: Double? = nil
    var spouseAdvantageOverride: Double? = nil

    // MARK: - 1.9 ACA Marketplace Modeling

    var enableACAModeling: Bool = false
    var acaHouseholdSize: Int = 1
    var acaBenchmarkSilverPlanMonthlyOverride: Double? = nil

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
        yourOtherPreTaxDeductions = 0
        spouseOtherPreTaxDeductions = 0
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

    // R3: Other above-the-line AGI reducers (educator expenses, student-loan
    // interest, self-employed health-insurance premiums, alimony pre-2019,
    // military moving, etc.). Single number per spouse.
    //
    // State-tax treatment: subtracted from state taxable income by default
    // (conforming states). Non-conforming states can opt in via
    // StateTaxConfig.otherPreTaxDeductionsTaxableForState. Same pattern
    // applies to Traditional IRA via traditionalIRAContributionsTaxableForState.
    var scenarioTotalOtherPreTaxDeductions: Double {
        yourOtherPreTaxDeductions + spouseOtherPreTaxDeductions
    }

    /// All 1.9 above-the-line deductions: 401(k) + IRA + HSA + Other combined for both spouses.
    var scenarioTotalAboveTheLineDeductions: Double {
        scenarioTotalTraditional401k + scenarioTotalTraditionalIRA + scenarioTotalHSA + scenarioTotalOtherPreTaxDeductions
    }
}
