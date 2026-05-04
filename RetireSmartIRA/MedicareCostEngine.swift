//
//  MedicareCostEngine.swift
//  RetireSmartIRA
//
//  Per-spouse Medicare cost composition. Pure-calculation: no SwiftUI / persistence.
//

import Foundation

enum MedicareCostEngine {

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
        config: TaxYearConfig
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
        let partB = partBBase + max(0, partBSurcharge)

        // Part D: base (override or config default) + IRMAA Part D surcharge.
        //
        // For Medicare Advantage Plus Drug (MAPD) plans, Part D coverage is INCLUDED
        // in the Advantage premium — adding partDBase separately would double-count
        // ~$50/month. However, Part D IRMAA surcharge is still separately billed by
        // CMS even with MAPD, so the surcharge portion still applies. (ChatGPT review 2026-05-03 #2)
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
