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

        // IRMAA + bracket + NIIT + widow warnings: filled in subsequent tasks (5.2, 5.3, 5.4).
        return warnings
    }
}
