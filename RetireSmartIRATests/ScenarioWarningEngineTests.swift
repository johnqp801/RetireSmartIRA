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
            config: config
        )
        #expect(warnings.contains { $0.category == .acaCliff })
    }

    @Test("ACA approaching warning fires when within $5K of cliff")
    func acaApproachingFires() {
        let warnings = ScenarioWarningEngine.warningsFor(
            federalAGI: FederalAGI(value: 57_000),
            acaMAGI: ACAMAGI(value: 57_000),  // ~378% FPL for size 1; cliff at 60240
            irmaaMAGI: IRMAAMAGI(value: 57_000),
            baselineIRMAAMAGI: IRMAAMAGI(value: 57_000),
            primaryAge: 62, spouseAge: nil,
            primaryMedicarePlanType: .preMedicare,
            spouseMedicarePlanType: .preMedicare,
            filingStatus: .single,
            enableACAModeling: true,
            acaHouseholdSize: 1,
            acaBenchmarkSilverPlanAnnual: 7_800,
            acaRegionalAdjustment: .mainland48,
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
            config: config
        )
        #expect(!warnings.contains { $0.category == .irmaaTierCrossing })
        #expect(!warnings.contains { $0.category == .irmaaApproaching })
    }
}
