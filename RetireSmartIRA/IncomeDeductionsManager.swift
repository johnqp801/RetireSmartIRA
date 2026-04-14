//
//  IncomeDeductionsManager.swift
//  RetireSmartIRA
//
//  Manages income sources, deduction items, and their pure aggregations.
//  Extracted from DataManager as part of God Class decomposition.
//

import SwiftUI
import Foundation
import Combine

@MainActor
class IncomeDeductionsManager: ObservableObject {
    // MARK: - Published Properties

    @Published var incomeSources: [IncomeSource] = []
    @Published var deductionItems: [DeductionItem] = []
    @Published var priorYearStateBalance: Double = 0

    /// Prior year federal tax liability (Line 24, Form 1040). Used for 100%/110% safe harbor.
    @Published var priorYearFederalTax: Double = 0
    /// Prior year state tax liability (from state return). Used for state safe harbor.
    @Published var priorYearStateTax: Double = 0
    /// Prior year AGI (Line 11, Form 1040). Determines 100% vs 110% safe harbor rate.
    @Published var priorYearAGI: Double = 0

    // MARK: - Income Aggregations

    func totalAnnualIncome() -> Double {
        incomeSources.reduce(0) { $0 + $1.annualAmount }
    }

    var totalFederalWithholding: Double {
        incomeSources.reduce(0) { $0 + $1.federalWithholding }
    }

    var totalStateWithholding: Double {
        incomeSources.reduce(0) { $0 + $1.stateWithholding }
    }

    var totalWithholding: Double {
        totalFederalWithholding + totalStateWithholding
    }

    var totalSocialSecurityBenefits: Double {
        incomeSources
            .filter { $0.type == .socialSecurity }
            .reduce(0) { $0 + $1.annualAmount }
    }

    var qualifiedDividendsTotal: Double {
        incomeSources
            .filter { $0.type == .qualifiedDividends }
            .reduce(0) { $0 + $1.annualAmount }
    }

    var longTermCapGainsTotal: Double {
        incomeSources
            .filter { $0.type == .capitalGainsLong }
            .reduce(0) { $0 + $1.annualAmount }
    }

    /// Ordinary income from sources — excludes SS, cap gains, qualified dividends, tax-exempt interest.
    var ordinaryIncomeSubtotal: Double {
        incomeSources
            .filter { $0.type != .socialSecurity && $0.type != .capitalGainsLong && $0.type != .qualifiedDividends && $0.type != .taxExemptInterest }
            .reduce(0) { $0 + $1.annualAmount }
    }

    // MARK: - Deduction Aggregations

    var totalMedicalExpenses: Double {
        deductionItems.filter { $0.type == .medicalExpenses }.reduce(0) { $0 + $1.annualAmount }
    }

    var propertyTaxAmount: Double {
        deductionItems.filter { $0.type == .propertyTax }.reduce(0) { $0 + $1.annualAmount }
    }

    var additionalSALTAmount: Double {
        deductionItems.filter { $0.type == .saltTax }.reduce(0) { $0 + $1.annualAmount }
    }

    var priorYearSALTDeductible: Double {
        max(0, priorYearStateBalance)
    }
}
