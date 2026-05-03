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
        netInvestmentIncome: Double = 0,
        baselineFederalAGI: FederalAGI,
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

        // ──── NIIT crossing ────
        // Fires when scenario AGI crosses NIIT threshold AND positive NII exists.
        let niitThreshold = filingStatus == .single ? config.niitThresholdSingle : config.niitThresholdMFJ
        if netInvestmentIncome > 0
            && federalAGI.value >= niitThreshold
            && baselineFederalAGI.value < niitThreshold {
            let nii = TaxCalculationEngine.calculateNIIT(
                nii: netInvestmentIncome,
                magi: federalAGI.value,
                filingStatus: filingStatus
            )
            warnings.append(ScenarioWarning(
                category: .niitCrossing,
                timing: .currentYear,
                severity: .info,
                dollarImpactPerYear: nii.annualNIITax,
                messageHeadline: "Crosses NIIT threshold",
                messageDetail: "Net investment income now subject to 3.8% surtax: ~$\(Int(nii.annualNIITax))/yr."
            ))
        }

        // ──── Bracket crossing ────
        let brackets: [TaxYearConfig.BracketEntry] = filingStatus == .single
            ? config.federalBracketsSingle
            : config.federalBracketsMFJ
        let baselineBracketIndex = brackets.lastIndex(where: { baselineFederalAGI.value >= $0.threshold }) ?? 0
        let scenarioBracketIndex = brackets.lastIndex(where: { federalAGI.value >= $0.threshold }) ?? 0
        if scenarioBracketIndex > baselineBracketIndex {
            let scenarioBracket = brackets[scenarioBracketIndex]
            warnings.append(ScenarioWarning(
                category: .bracketCrossing,
                timing: .currentYear,
                severity: .info,
                dollarImpactPerYear: 0,
                messageHeadline: "Crosses into \(Int(scenarioBracket.rate * 100))% bracket",
                messageDetail: "Marginal federal rate increases."
            ))
        }

        // ──── Widow Bracket Jump (MFJ only) ────
        if filingStatus == .marriedFilingJointly {
            let mfjBracket = config.federalBracketsMFJ.lastIndex(where: { federalAGI.value >= $0.threshold }) ?? 0
            let widowSingleBracket = config.federalBracketsSingle.lastIndex(where: { federalAGI.value >= $0.threshold }) ?? 0
            if widowSingleBracket > mfjBracket {
                let widowRate = config.federalBracketsSingle[widowSingleBracket].rate
                warnings.append(ScenarioWarning(
                    category: .widowBracketJump,
                    timing: .currentYear,
                    severity: .info,
                    dollarImpactPerYear: 0,
                    messageHeadline: "Surviving spouse would jump to \(Int(widowRate * 100))% bracket",
                    messageDetail: "MFJ-to-single transition pushes future widow into a higher tax bracket at this AGI."
                ))
            }
        }

        return warnings
    }
}
