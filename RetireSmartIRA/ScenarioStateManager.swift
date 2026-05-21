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

    // MARK: - 1.8.4 Roth Conversion Withholding (Jonggie Issue 2)
    //
    // When a user does a Roth conversion without outside money to pay the
    // federal tax, the brokerage withholds a portion of the conversion to
    // cover that tax — reducing the amount that actually lands in the Roth.
    //
    // `paidFromOutside` (default): user pays conversion tax from non-
    //   retirement assets; full gross amount lands in the Roth.
    // `withheldFromConversion`: a portion equal to
    //   `rothConversionFederalWithholdingRate × gross` is withheld and
    //   remitted to the IRS, with only the net amount deposited.
    //
    // Household-level (applies to both spouse conversions when both are
    // non-zero). Federal-only — most brokerages do not withhold state
    // tax from Roth conversions, and PA / IL / MS exempt the conversion
    // entirely anyway. PA's exemption per Ans 274 partially unwinds in
    // withhold mode: the withheld portion becomes PA-taxable.
    var rothConversionWithholdingMode: RothConversionWithholdingMode = .paidFromOutside
    var rothConversionFederalWithholdingRate: Double = 0.24

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
        rothConversionWithholdingMode = .paidFromOutside
        rothConversionFederalWithholdingRate = 0.24
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

// MARK: - Roth Conversion Withholding (1.8.4)

/// Whether the federal tax on a Roth conversion is paid from non-retirement
/// assets (default) or withheld from the conversion itself.
///
/// Driven by tester report (Jonggie F., May 2026): users without outside
/// cash to cover the federal tax need to see what actually lands in the
/// Roth after withholding, especially for heir-comparison planning. Most
/// custodians (Fidelity, Schwab, Vanguard) allow a federal withholding
/// election (typically 10%-37%) on conversions; state withholding is rarely
/// offered for Roth conversions. PA's Ans 274 retirement exemption
/// partially unwinds in withhold mode — the withheld portion becomes
/// PA-taxable as a distribution.
enum RothConversionWithholdingMode: String, Codable {
    /// User pays the federal conversion tax from non-retirement assets
    /// (taxable brokerage, savings, etc.). Full gross conversion lands in
    /// the Roth. Net Roth deposit = gross.
    case paidFromOutside

    /// Custodian withholds a portion of the gross conversion (per the
    /// elected federal rate) and remits to the IRS. Only the net amount
    /// reaches the Roth. Net Roth deposit = gross × (1 − withholdingRate).
    /// For PA residents, the withheld portion becomes state-taxable as a
    /// distribution per PA DOR Ans 274 ("full balance must be deposited").
    case withheldFromConversion
}
