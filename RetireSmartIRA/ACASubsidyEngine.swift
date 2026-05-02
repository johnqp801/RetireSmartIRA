//
//  ACASubsidyEngine.swift
//  RetireSmartIRA
//
//  Pure-calculation engine for ACA Marketplace APTC subsidy modeling.
//  Data-driven cliff: cliff threshold is derived from the applicable-figures
//  schedule (first row where applicable_figure >= 1.0). JSON updates can
//  restore enhanced subsidies without code changes.
//

import Foundation

enum ACASubsidyEngine {

    enum AlaskaHawaii {
        case alaska, hawaii, mainland48
    }

    /// Compute the household's ACA Marketplace APTC subsidy.
    static func calculateSubsidy(
        acaMAGI: ACAMAGI,
        householdSize: Int,
        benchmarkSilverPlanAnnualPremium: Double,
        regionalAdjustment: AlaskaHawaii = .mainland48,
        config: TaxYearConfig
    ) -> ACASubsidyResult {

        let acaConfig = config.acaSubsidy2026

        // 1. Household FPL with optional AK/HI multiplier.
        let fplBase = acaConfig.fpl2026.householdSizeToFPL[String(householdSize)]
            ?? acaConfig.fpl2026.householdSizeToFPL[String(min(householdSize, 8))]!
        let multiplier: Double = {
            switch regionalAdjustment {
            case .alaska: return acaConfig.fpl2026.alaskaMultiplier
            case .hawaii: return acaConfig.fpl2026.hawaiiMultiplier
            case .mainland48: return 1.0
            }
        }()
        let fplAmount = fplBase * multiplier

        // 2. fplPercent.
        let fplPercent = (acaMAGI.value / fplAmount) * 100

        // 3. Detect cliff: first row where applicableFigure >= 1.0.
        let cliffEntry = acaConfig.applicableFigures.first { $0.applicableFigure >= 1.0 }
        let isOverCliff: Bool
        let dollarsToCliff: Double?
        if let cliff = cliffEntry {
            let cliffMAGI = cliff.fplPercent * fplAmount / 100
            isOverCliff = acaMAGI.value >= cliffMAGI
            dollarsToCliff = cliffMAGI - acaMAGI.value
        } else {
            isOverCliff = false
            dollarsToCliff = nil
        }

        // 4. If over cliff, subsidy = 0.
        if isOverCliff {
            return ACASubsidyResult(
                acaMAGI: acaMAGI.value,
                householdSize: householdSize,
                fplAmount: fplAmount,
                fplPercent: fplPercent,
                applicableFigure: 1.0,
                benchmarkSilverPlanAnnual: benchmarkSilverPlanAnnualPremium,
                expectedContribution: acaMAGI.value,
                annualPremiumAssistance: 0,
                dollarsToCliff: dollarsToCliff,
                isOverCliff: true
            )
        }

        // 5. Look up applicable_figure (interpolate between the two surrounding rows).
        let applicableFigure = interpolateApplicableFigure(
            fplPercent: fplPercent,
            schedule: acaConfig.applicableFigures
        )

        // 6. Compute expected contribution + APTC.
        let expectedContribution = acaMAGI.value * applicableFigure
        let annualPremiumAssistance = max(0, benchmarkSilverPlanAnnualPremium - expectedContribution)

        return ACASubsidyResult(
            acaMAGI: acaMAGI.value,
            householdSize: householdSize,
            fplAmount: fplAmount,
            fplPercent: fplPercent,
            applicableFigure: applicableFigure,
            benchmarkSilverPlanAnnual: benchmarkSilverPlanAnnualPremium,
            expectedContribution: expectedContribution,
            annualPremiumAssistance: annualPremiumAssistance,
            dollarsToCliff: dollarsToCliff,
            isOverCliff: false
        )
    }

    /// Linear interpolation of applicable_figure between two adjacent FPL-percent rows.
    /// Below the first row → returns the first row's figure (0.00).
    /// Above the cliff entry → returns 1.0 (caller short-circuits before calling).
    static func interpolateApplicableFigure(
        fplPercent: Double,
        schedule: [TaxYearConfig.ACASubsidyConfig.ApplicableFigure]
    ) -> Double {
        guard let first = schedule.first else { return 0.0 }
        if fplPercent <= first.fplPercent { return first.applicableFigure }
        // Find the bracket: the largest row whose fplPercent <= fplPercent, and the next row.
        for i in 0..<(schedule.count - 1) {
            let lo = schedule[i]
            let hi = schedule[i + 1]
            if fplPercent >= lo.fplPercent && fplPercent < hi.fplPercent {
                let fraction = (fplPercent - lo.fplPercent) / (hi.fplPercent - lo.fplPercent)
                return lo.applicableFigure + fraction * (hi.applicableFigure - lo.applicableFigure)
            }
        }
        // At or beyond last row.
        return schedule.last!.applicableFigure
    }
}
