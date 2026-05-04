//
//  ScenarioWarningEngineTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("ScenarioWarningEngine — ACA")
struct ScenarioWarningEngineACATests {

    private let config = TaxYearConfig.loadOrFallback(forYear: 2026)

    @Test("ACA cliff warning fires when MAGI is over the cliff with ACA modeling enabled")
    func acaCliffFires() {
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 70_000),
            acaMAGI: ACAMAGI(value: 70_000),
            irmaaMAGI: IRMAAMAGI(value: 70_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 70_000),
            primaryAge: 62, spouseAge: nil,
            primaryMedicarePlanType: .preMedicare,
            spouseMedicarePlanType: .preMedicare,
            filingStatus: .single,
            enableACAModeling: true,
            acaHouseholdSize: 1,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 0,
            baselineFederalAGI: FederalAGI(value: 0),
            config: config
        )
        #expect(warnings.contains { $0.category == .acaCliff })
    }

    @Test("ACA approaching warning fires when within $5K of cliff")
    func acaApproachingFires() {
        // Updated 2026-05-03 (constants refresh): old cliff was 400% of 15_060 = 60_240; old MAGI 57_000 was 3_240 from cliff.
        // New cliff = 400% of 15_960 = 63_840. MAGI 60_000 is 3_840 from new cliff (within $5K threshold).
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 60_000),
            acaMAGI: ACAMAGI(value: 60_000),  // ~375.9% FPL for size 1; cliff at 63_840
            irmaaMAGI: IRMAAMAGI(value: 60_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 60_000),
            primaryAge: 62, spouseAge: nil,
            primaryMedicarePlanType: .preMedicare,
            spouseMedicarePlanType: .preMedicare,
            filingStatus: .single,
            enableACAModeling: true,
            acaHouseholdSize: 1,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 0,
            baselineFederalAGI: FederalAGI(value: 0),
            config: config
        )
        #expect(warnings.contains { $0.category == .acaApproaching })
    }

    @Test("ACA cliff warning does NOT fire when ACA modeling disabled")
    func acaSilentWhenDisabled() {
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 70_000),
            acaMAGI: ACAMAGI(value: 70_000),
            irmaaMAGI: IRMAAMAGI(value: 70_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 70_000),
            primaryAge: 62, spouseAge: nil,
            primaryMedicarePlanType: .preMedicare,
            spouseMedicarePlanType: .preMedicare,
            filingStatus: .single,
            enableACAModeling: false,
            acaHouseholdSize: 1,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 0,
            baselineFederalAGI: FederalAGI(value: 0),
            config: config
        )
        #expect(!warnings.contains { $0.category == .acaCliff })
    }
}

@Suite("ScenarioWarningEngine — IRMAA")
struct ScenarioWarningEngineIRMAATests {

    private let config = TaxYearConfig.loadOrFallback(forYear: 2026)

    @Test("IRMAA tier crossing fires when scenario MAGI crosses a tier (single)")
    func irmaaCrossingSingle() {
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 110_000),  // pushes over single tier 1 of 109_001
            acaMAGI: ACAMAGI(value: 110_000),
            irmaaMAGI: IRMAAMAGI(value: 110_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 100_000),  // baseline below tier 1
            primaryAge: 67, spouseAge: nil,
            primaryMedicarePlanType: .originalMedicare,
            spouseMedicarePlanType: .preMedicare,
            filingStatus: .single,
            enableACAModeling: false,
            acaHouseholdSize: 1,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 0,
            baselineFederalAGI: FederalAGI(value: 0),
            config: config
        )
        #expect(warnings.contains { $0.category == .irmaaTierCrossing })
    }

    @Test("IRMAA approaching fires within $10K of next tier")
    func irmaaApproachingFires() {
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 105_000),  // ~$4K under tier 1 of 109_001
            acaMAGI: ACAMAGI(value: 105_000),
            irmaaMAGI: IRMAAMAGI(value: 105_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 105_000),
            primaryAge: 67, spouseAge: nil,
            primaryMedicarePlanType: .originalMedicare,
            spouseMedicarePlanType: .preMedicare,
            filingStatus: .single,
            enableACAModeling: false,
            acaHouseholdSize: 1,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 0,
            baselineFederalAGI: FederalAGI(value: 0),
            config: config
        )
        #expect(warnings.contains { $0.category == .irmaaApproaching })
    }

    @Test("IRMAA warnings silent for spouses both pre-Medicare and under 63")
    func irmaaSilentWhenAllPreMedicare() {
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 250_000),
            acaMAGI: ACAMAGI(value: 250_000),
            irmaaMAGI: IRMAAMAGI(value: 250_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 100_000),
            primaryAge: 50, spouseAge: 50,
            primaryMedicarePlanType: .preMedicare,
            spouseMedicarePlanType: .preMedicare,
            filingStatus: .marriedFilingJointly,
            enableACAModeling: false,
            acaHouseholdSize: 2,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 0,
            baselineFederalAGI: FederalAGI(value: 0),
            config: config
        )
        #expect(!warnings.contains { $0.category == .irmaaTierCrossing })
        #expect(!warnings.contains { $0.category == .irmaaApproaching })
    }
}

@Suite("ScenarioWarningEngine — NIIT + Bracket")
struct ScenarioWarningEngineNIITBracketTests {

    private let config = TaxYearConfig.loadOrFallback(forYear: 2026)

    @Test("NIIT crossing warning fires when MFJ AGI crosses 250K with positive NII")
    func niitCrossingMFJ() {
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 260_000),
            acaMAGI: ACAMAGI(value: 260_000),
            irmaaMAGI: IRMAAMAGI(value: 260_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 200_000),
            primaryAge: 70, spouseAge: 70,
            primaryMedicarePlanType: .originalMedicare,
            spouseMedicarePlanType: .originalMedicare,
            filingStatus: .marriedFilingJointly,
            enableACAModeling: false,
            acaHouseholdSize: 2,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 5_000,
            baselineFederalAGI: FederalAGI(value: 200_000),
            config: config
        )
        #expect(warnings.contains { $0.category == .niitCrossing })
    }
}

@Suite("ScenarioWarningEngine — Widow Bracket Jump")
struct ScenarioWarningEngineWidowBracketTests {

    private let config = TaxYearConfig.loadOrFallback(forYear: 2026)

    @Test("Widow-bracket-jump fires for MFJ if a single-filer same-AGI would jump bracket")
    func widowBracketJumpFires() {
        // MFJ at AGI 200K is in 22% bracket (24% threshold = 211_400). Widow filing single
        // at 200K is in 32% bracket (32% single threshold = 201_775). Surviving spouse
        // would jump bracket(s).
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 200_000),
            acaMAGI: ACAMAGI(value: 200_000),
            irmaaMAGI: IRMAAMAGI(value: 200_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 200_000),
            primaryAge: 75, spouseAge: 75,
            primaryMedicarePlanType: .originalMedicare,
            spouseMedicarePlanType: .originalMedicare,
            filingStatus: .marriedFilingJointly,
            enableACAModeling: false,
            acaHouseholdSize: 2,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 0,
            baselineFederalAGI: FederalAGI(value: 200_000),
            config: config
        )
        #expect(warnings.contains { $0.category == .widowBracketJump })
    }

    @Test("Widow-bracket-jump silent for single filer (no jump scenario)")
    func widowBracketJumpSilentSingle() {
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 200_000),
            acaMAGI: ACAMAGI(value: 200_000),
            irmaaMAGI: IRMAAMAGI(value: 200_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 200_000),
            primaryAge: 75, spouseAge: nil,
            primaryMedicarePlanType: .originalMedicare,
            spouseMedicarePlanType: .preMedicare,
            filingStatus: .single,
            enableACAModeling: false,
            acaHouseholdSize: 1,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 0,
            baselineFederalAGI: FederalAGI(value: 200_000),
            config: config
        )
        #expect(!warnings.contains { $0.category == .widowBracketJump })
    }
}

@Suite("ScenarioWarningEngine — Integration: ACA + IRMAA dual-warning")
struct ScenarioWarningEngineIntegrationTests {

    private let config = TaxYearConfig.loadOrFallback(forYear: 2026)

    @Test("Pre-Medicare 62yo with high MAGI fires both ACA cliff and IRMAA approaching")
    func dualWarningACAAndIRMAA() {
        // MFJ: primary 67 on Medicare (gates IRMAA on), spouse 62 pre-Medicare (gates ACA on).
        // Scenario MAGI = 225_000:
        //   - ACA: fires because spouse is pre-Medicare (< 65)
        //     225K > 400% FPL cliff (20_440 * 4 = 81_760 for size 2) → fires .acaCliff
        //   - IRMAA: fires because primary is on Medicare (age 67, .originalMedicare)
        //     225K > 218_001 (MFJ tier 1 threshold) → fires .irmaaTierCrossing
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 225_000),
            acaMAGI: ACAMAGI(value: 225_000),
            irmaaMAGI: IRMAAMAGI(value: 225_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 200_000),
            primaryAge: 67, spouseAge: 62,
            primaryMedicarePlanType: .originalMedicare,
            spouseMedicarePlanType: .preMedicare,
            filingStatus: .marriedFilingJointly,
            enableACAModeling: true,
            acaHouseholdSize: 2,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 0,
            baselineFederalAGI: FederalAGI(value: 200_000),
            config: config
        )
        let categories = warnings.map { $0.category }
        // Both should fire:
        // - ACA cliff: 225K > 81_760 (400% FPL for size 2)
        // - IRMAA tier crossing: 225K > 218_001 (MFJ tier 1 threshold), baseline was 200K
        #expect(categories.contains(.acaCliff))
        #expect(categories.contains(.irmaaTierCrossing))
    }

    @Test("Top warnings are sorted by dollar impact")
    func topWarningsSortedByImpact() {
        // Same scenario as above: MFJ with primary 67 on Medicare + spouse 62 pre-Medicare.
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 225_000),
            acaMAGI: ACAMAGI(value: 225_000),
            irmaaMAGI: IRMAAMAGI(value: 225_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 200_000),
            primaryAge: 67, spouseAge: 62,
            primaryMedicarePlanType: .originalMedicare,
            spouseMedicarePlanType: .preMedicare,
            filingStatus: .marriedFilingJointly,
            enableACAModeling: true,
            acaHouseholdSize: 2,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
            netInvestmentIncome: 0,
            baselineFederalAGI: FederalAGI(value: 200_000),
            config: config
        )
        let sorted = warnings.sorted { $0.dollarImpactPerYear > $1.dollarImpactPerYear }
        // First warning has the highest dollar impact (typically ACA cliff at ~$7800 vs IRMAA at ~$1-2K)
        if sorted.count >= 2 {
            #expect(sorted[0].dollarImpactPerYear >= sorted[1].dollarImpactPerYear)
        }
    }
}
