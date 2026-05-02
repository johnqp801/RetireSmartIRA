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
