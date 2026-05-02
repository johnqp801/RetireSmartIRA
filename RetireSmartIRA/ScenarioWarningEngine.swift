//
//  ScenarioWarningEngine.swift
//  RetireSmartIRA
//
//  Cross-feature scenario warning generation. Pure-calculation: no SwiftUI
//  or persistence. Returns ALL active warnings; UI sorts/truncates by
//  dollarImpactPerYear.
//

import Foundation

enum ScenarioWarningEngine {

    static func warningsFor(
        federalAGI: FederalAGI,
        acaMAGI: ACAMAGI,
        irmaaMAGI: IRMAAMAGI,
        baselineIRMAAMAGI: IRMAAMAGI,
        primaryAge: Int,
        spouseAge: Int?,
        primaryMedicarePlanType: MedicarePlanType,
        spouseMedicarePlanType: MedicarePlanType,
        filingStatus: FilingStatus,
        enableACAModeling: Bool,
        acaHouseholdSize: Int,
        acaBenchmarkSilverPlanAnnual: Double,
        acaRegionalAdjustment: ACASubsidyEngine.AlaskaHawaii,
        config: TaxYearConfig
    ) -> [ScenarioWarning] {

        var warnings: [ScenarioWarning] = []

        // ──── ACA cliff + approaching ────
        if enableACAModeling {
            let primaryPreMedicare = primaryAge < 65 || primaryMedicarePlanType == .preMedicare
            let spousePreMedicare: Bool = {
                guard let age = spouseAge else { return false }
                return age < 65 || spouseMedicarePlanType == .preMedicare
            }()
            if primaryPreMedicare || spousePreMedicare {
                let aca = ACASubsidyEngine.calculateSubsidy(
                    acaMAGI: acaMAGI,
                    householdSize: max(1, acaHouseholdSize),
                    benchmarkSilverPlanAnnualPremium: acaBenchmarkSilverPlanAnnual,
                    regionalAdjustment: acaRegionalAdjustment,
                    config: config
                )
                if aca.isOverCliff {
                    warnings.append(ScenarioWarning(
                        category: .acaCliff,
                        timing: .currentYear,
                        severity: .warning,
                        dollarImpactPerYear: aca.benchmarkSilverPlanAnnual,
                        messageHeadline: "Crosses ACA subsidy cliff",
                        messageDetail: "MAGI is over the 400% FPL threshold; estimated subsidy lost this year."
                    ))
                } else if let toCliff = aca.dollarsToCliff, toCliff > 0 && toCliff < 5_000 {
                    warnings.append(ScenarioWarning(
                        category: .acaApproaching,
                        timing: .currentYear,
                        severity: .warning,
                        dollarImpactPerYear: aca.annualPremiumAssistance,
                        messageHeadline: "Approaching ACA cliff",
                        messageDetail: "Within $\(Int(toCliff)) of the 400% FPL threshold. Crossing it zeroes out APTC."
                    ))
                }
            }
        }

        // ──── IRMAA tier crossing + approaching ────
        // Apply only when at least one spouse is on Medicare or within 2 years of 65.
        let primaryIRMAARelevant = primaryAge >= 63 || primaryMedicarePlanType != .preMedicare
        let spouseIRMAARelevant: Bool = {
            guard let age = spouseAge else { return false }
            return age >= 63 || spouseMedicarePlanType != .preMedicare
        }()
        if primaryIRMAARelevant || spouseIRMAARelevant {
            let scenarioIRMAA = TaxCalculationEngine.calculateIRMAA(magi: irmaaMAGI, filingStatus: filingStatus)
            let baselineIRMAA = TaxCalculationEngine.calculateIRMAA(magi: baselineIRMAAMAGI, filingStatus: filingStatus)
            if scenarioIRMAA.tier > baselineIRMAA.tier {
                let surchargeIncrease = scenarioIRMAA.annualSurchargePerPerson - baselineIRMAA.annualSurchargePerPerson
                let medicareCount: Int = {
                    var c = 0
                    if primaryMedicarePlanType != .preMedicare { c += 1 }
                    if spouseMedicarePlanType != .preMedicare { c += 1 }
                    return max(c, 1)
                }()
                warnings.append(ScenarioWarning(
                    category: .irmaaTierCrossing,
                    timing: .twoYearsOut,
                    severity: .warning,
                    dollarImpactPerYear: surchargeIncrease * Double(medicareCount),
                    messageHeadline: "Crosses IRMAA tier \(scenarioIRMAA.tier)",
                    messageDetail: "Medicare premium impact in 2 years: ~$\(Int(surchargeIncrease * Double(medicareCount)))/yr."
                ))
            } else if let distanceToNext = scenarioIRMAA.distanceToNextTier,
                      distanceToNext > 0 && distanceToNext < 10_000 {
                warnings.append(ScenarioWarning(
                    category: .irmaaApproaching,
                    timing: .twoYearsOut,
                    severity: .info,
                    dollarImpactPerYear: 0,
                    messageHeadline: "Approaching IRMAA tier \(scenarioIRMAA.tier + 1)",
                    messageDetail: "Within $\(Int(distanceToNext)) of next IRMAA tier."
                ))
            }
        }

        // bracket + NIIT + widow warnings: filled in subsequent tasks (5.3, 5.4).
        return warnings
    }
}
