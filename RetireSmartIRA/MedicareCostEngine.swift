//
//  MedicareCostEngine.swift
//  RetireSmartIRA
//
//  Per-spouse Medicare cost composition. Pure-calculation: no SwiftUI / persistence.
//

import Foundation

enum MedicareCostEngine {

    /// Part B late-enrollment penalty multiplier for users who delay Medicare past 65
    /// without qualified employer coverage. 10% per 12 months delayed, lifelong.
    /// Returns 0 if start age <= 65 or qualified employer coverage applies.
    static func latePartBPenaltyMultiplier(
        plannedStartAge: Int,
        hasQualifiedEmployerCoverage: Bool
    ) -> Double {
        guard !hasQualifiedEmployerCoverage else { return 0 }
        let delayYears = max(0, plannedStartAge - 65)
        return Double(delayYears) * 0.10
    }

    /// Compute per-spouse Medicare cost for a single individual.
    ///
    /// Mixed-household: call this once per spouse with the SAME `irmaaMAGI` (joint MAGI for MFJ),
    /// since IRMAA brackets use joint MAGI. Per-spouse plan-type and overrides drive the rest.
    static func computeCostForSpouse(
        planType: MedicarePlanType,
        irmaaMAGI: IRMAAMAGI,
        partBOverride: Double?,
        partDOverride: Double?,
        medigapOverride: Double?,
        advantageOverride: Double?,
        filingStatus: FilingStatus,
        config: TaxYearConfig,
        plannedMedicareStartAge: Int = 65,
        hasQualifiedEmployerCoverage: Bool = false
    ) -> MedicareCostBreakdown {

        // Pre-Medicare spouse → no Medicare cost.
        if planType == .preMedicare {
            return MedicareCostBreakdown(
                planType: .preMedicare,
                partB: 0, partD: 0, medigap: nil, advantagePremium: nil,
                total: 0, annualTotal: 0,
                irmaaSurcharge: 0, irmaaTier: -1
            )
        }

        // IRMAA tier lookup using the existing engine.
        let irmaa = TaxCalculationEngine.calculateIRMAA(magi: irmaaMAGI, filingStatus: filingStatus)

        // Part B: base (override or config default) + IRMAA Part B surcharge.
        let partBBase = partBOverride ?? config.medicare2026.partBStandardMonthly
        let partBSurcharge = irmaa.monthlyPartB - config.irmaaStandardPartB
        let penaltyMultiplier = latePartBPenaltyMultiplier(
            plannedStartAge: plannedMedicareStartAge,
            hasQualifiedEmployerCoverage: hasQualifiedEmployerCoverage
        )
        let partBLatePenalty = partBBase * penaltyMultiplier
        let partB = partBBase + max(0, partBSurcharge) + partBLatePenalty

        // Part D: base (override or config default) + IRMAA Part D surcharge.
        //
        // For Medicare Advantage Plus Drug (MAPD) plans, Part D coverage is INCLUDED
        // in the Advantage premium — adding partDBase separately would double-count
        // ~$50/month. However, Part D IRMAA surcharge is still separately billed by
        // CMS even with MAPD, so the surcharge portion still applies.
        // Backported from V2.0 commit f323da8 (ChatGPT review 2026-05-03 #2).
        let partDBase: Double = {
            switch planType {
            case .originalMedicare: return partDOverride ?? config.medicare2026.partDAvgMonthly
            case .medicareAdvantage: return 0  // Part D coverage included in Advantage premium
            case .preMedicare: return 0  // unreachable due to early return above
            }
        }()
        let partDSurcharge = irmaa.monthlyPartD  // Part D IRMAA is purely additive surcharge
        let partD = partDBase + partDSurcharge

        // Plan-type-specific premium.
        var medigap: Double? = nil
        var advantagePremium: Double? = nil
        switch planType {
        case .originalMedicare:
            medigap = medigapOverride ?? config.medicare2026.medigapAvgMonthly
        case .medicareAdvantage:
            advantagePremium = advantageOverride ?? config.medicare2026.advantageAvgMonthly
        case .preMedicare:
            break  // unreachable due to early return
        }

        let total = partB + partD + (medigap ?? 0) + (advantagePremium ?? 0)
        let irmaaSurchargeMonthly = max(0, partBSurcharge) + partDSurcharge

        return MedicareCostBreakdown(
            planType: planType,
            partB: partB,
            partD: partD,
            medigap: medigap,
            advantagePremium: advantagePremium,
            total: total,
            annualTotal: total * 12,
            irmaaSurcharge: irmaaSurchargeMonthly,
            irmaaTier: irmaa.tier
        )
    }
}
