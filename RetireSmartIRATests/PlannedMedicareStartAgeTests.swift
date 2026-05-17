//
//  PlannedMedicareStartAgeTests.swift
//  RetireSmartIRATests
//
//  Tests for D2: Medicare planned start age + Part B late-enrollment penalty.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Part B late-enrollment penalty multiplier")
struct LatePartBPenaltyTests {

    @Test("No delay (age 65): multiplier is 0")
    func latePartBPenalty_NoDelay_IsZero() {
        let m = MedicareCostEngine.latePartBPenaltyMultiplier(
            plannedStartAge: 65,
            hasQualifiedEmployerCoverage: false
        )
        #expect(m == 0.0)
    }

    @Test("Two-year delay, no employer coverage: 20%")
    func latePartBPenalty_TwoYearDelay_NoEmployerCoverage_Is20Percent() {
        let m = MedicareCostEngine.latePartBPenaltyMultiplier(
            plannedStartAge: 67,
            hasQualifiedEmployerCoverage: false
        )
        #expect(abs(m - 0.20) < 1e-9)
    }

    @Test("Five-year delay, no employer coverage: 50%")
    func latePartBPenalty_FiveYearDelay_NoEmployerCoverage_Is50Percent() {
        let m = MedicareCostEngine.latePartBPenaltyMultiplier(
            plannedStartAge: 70,
            hasQualifiedEmployerCoverage: false
        )
        #expect(abs(m - 0.50) < 1e-9)
    }

    @Test("Delay with qualified employer coverage: 0%")
    func latePartBPenalty_WithQualifiedEmployerCoverage_IsZero() {
        let m = MedicareCostEngine.latePartBPenaltyMultiplier(
            plannedStartAge: 68,
            hasQualifiedEmployerCoverage: true
        )
        #expect(m == 0.0)
    }

    @Test("Defensive: start age below 65 returns 0 (no negative penalty)")
    func latePartBPenalty_StartBefore65_IsZero() {
        let m = MedicareCostEngine.latePartBPenaltyMultiplier(
            plannedStartAge: 62,
            hasQualifiedEmployerCoverage: false
        )
        #expect(m == 0.0)
    }

    @Test("Engine integration: penalty inflates Part B by base * multiplier")
    func latePartBPenalty_AppliedInComputeCostForSpouse() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let base = MedicareCostEngine.computeCostForSpouse(
            planType: .originalMedicare,
            irmaaMAGI: IRMAAMAGI(value: 50_000),
            partBOverride: nil,
            partDOverride: nil,
            medigapOverride: nil,
            advantageOverride: nil,
            filingStatus: .single,
            config: config,
            plannedMedicareStartAge: 65,
            hasQualifiedEmployerCoverage: false
        )
        let delayed = MedicareCostEngine.computeCostForSpouse(
            planType: .originalMedicare,
            irmaaMAGI: IRMAAMAGI(value: 50_000),
            partBOverride: nil,
            partDOverride: nil,
            medigapOverride: nil,
            advantageOverride: nil,
            filingStatus: .single,
            config: config,
            plannedMedicareStartAge: 67,
            hasQualifiedEmployerCoverage: false
        )
        // 20% lift on the Part B base premium.
        let expectedDelta = config.medicare2026.partBStandardMonthly * 0.20
        #expect(abs((delayed.partB - base.partB) - expectedDelta) < 1e-6)
    }

    @Test("Engine integration: qualified employer coverage neutralizes delay")
    func latePartBPenalty_QualifiedCoverageDisablesPenaltyInEngine() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let withoutCoverage = MedicareCostEngine.computeCostForSpouse(
            planType: .originalMedicare,
            irmaaMAGI: IRMAAMAGI(value: 50_000),
            partBOverride: nil,
            partDOverride: nil,
            medigapOverride: nil,
            advantageOverride: nil,
            filingStatus: .single,
            config: config,
            plannedMedicareStartAge: 65,
            hasQualifiedEmployerCoverage: false
        )
        let withCoverage = MedicareCostEngine.computeCostForSpouse(
            planType: .originalMedicare,
            irmaaMAGI: IRMAAMAGI(value: 50_000),
            partBOverride: nil,
            partDOverride: nil,
            medigapOverride: nil,
            advantageOverride: nil,
            filingStatus: .single,
            config: config,
            plannedMedicareStartAge: 70,
            hasQualifiedEmployerCoverage: true
        )
        #expect(abs(withoutCoverage.partB - withCoverage.partB) < 1e-9)
    }

    @Test("partB combines IRMAA surcharge and late penalty correctly: 67yo single at MAGI 250k")
    func partB_WithBothIRMAASurchargeAndLatePenalty_AppliesPenaltyToStandardOnly() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let breakdown = MedicareCostEngine.computeCostForSpouse(
            planType: .originalMedicare,
            irmaaMAGI: IRMAAMAGI(value: 250_000),
            partBOverride: nil,
            partDOverride: nil,
            medigapOverride: nil,
            advantageOverride: nil,
            filingStatus: .single,
            config: config,
            plannedMedicareStartAge: 67,
            hasQualifiedEmployerCoverage: false
        )
        let partBBase = config.medicare2026.partBStandardMonthly
        // Expected: standard + IRMAA surcharge for 250k single + 20% penalty on standard only
        let expectedPenalty = partBBase * 0.20
        let irmaa = TaxCalculationEngine.calculateIRMAA(magi: IRMAAMAGI(value: 250_000), filingStatus: .single)
        let expectedSurcharge = max(0, irmaa.monthlyPartB - config.irmaaStandardPartB)
        let expected = partBBase + expectedSurcharge + expectedPenalty
        #expect(abs(breakdown.partB - expected) < 0.01)
    }
}

@Suite("ProfileManager planned Medicare start age default")
@MainActor
struct ProfileManagerPlannedMedicareStartAgeTests {

    @Test("Default planned start age is 65")
    func defaultPlannedStartAge_Is65() {
        let pm = ProfileManager()
        #expect(pm.plannedMedicareStartAge == 65)
    }

    @Test("Default qualified-coverage flag is false")
    func defaultQualifiedCoverage_IsFalse() {
        let pm = ProfileManager()
        #expect(pm.hasQualifiedEmployerCoverageForMedicare == false)
    }

    @Test("Setter assigns in-instance")
    func setter_AssignsInInstance() {
        let pm = ProfileManager()
        pm.plannedMedicareStartAge = 68
        pm.hasQualifiedEmployerCoverageForMedicare = true
        #expect(pm.plannedMedicareStartAge == 68)
        #expect(pm.hasQualifiedEmployerCoverageForMedicare == true)
    }

    // Persistence round-trip is tested at the integration level via PersistenceManager;
    // an in-process @Published-backed round-trip test would require teardown of
    // shared UserDefaults.standard keys and is omitted to avoid flakiness.
}
