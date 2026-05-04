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
    /// Above the cliff entry → caller short-circuits before calling (see calculateSubsidy step 4).
    static func interpolateApplicableFigure(
        fplPercent: Double,
        schedule: [TaxYearConfig.ACASubsidyConfig.ApplicableFigure]
    ) -> Double {
        // Filter out cliff sentinel rows (applicableFigure >= 1.0) — these mark the
        // hard subsidy cliff and should not be used as interpolation endpoints.
        // Without this, a household at 350% FPL would get interpolated between
        // (300% → 0.08) and (400% → 1.00) → ~0.54 applicable figure (~54% of income
        // expected as premium), which is wrong. The 300-400% FPL band should stay
        // near the 300% schedule value (~8%) which represents pre-ARPA expected
        // contribution ceiling. (ChatGPT review 2026-05-03 #1)
        let interpolatable = schedule.filter { $0.applicableFigure < 1.0 }

        guard let first = interpolatable.first else { return 0.0 }
        if fplPercent <= first.fplPercent { return first.applicableFigure }

        // Find the bracket: the largest row whose fplPercent <= fplPercent, and the next row.
        for i in 0..<(interpolatable.count - 1) {
            let lo = interpolatable[i]
            let hi = interpolatable[i + 1]
            if fplPercent >= lo.fplPercent && fplPercent < hi.fplPercent {
                let fraction = (fplPercent - lo.fplPercent) / (hi.fplPercent - lo.fplPercent)
                return lo.applicableFigure + fraction * (hi.applicableFigure - lo.applicableFigure)
            }
        }
        // Above the last interpolatable row but below the cliff: stay at the last value.
        return interpolatable.last!.applicableFigure
    }
}
