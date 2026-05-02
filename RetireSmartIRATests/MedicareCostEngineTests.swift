//
//  MedicareCostEngineTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("MedicareCostEngine — pre-Medicare returns zero")
struct MedicareCostEnginePreMedicareTests {

    @Test("Pre-Medicare: returns zero-cost breakdown with irmaaTier -1")
    func preMedicareZero() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = MedicareCostEngine.computeCostForSpouse(
            planType: .preMedicare,
            irmaaMAGI: IRMAAMAGI(value: 100_000),
            partBOverride: nil,
            partDOverride: nil,
            medigapOverride: nil,
            advantageOverride: nil,
            filingStatus: .single,
            config: config
        )
        #expect(result.total == 0)
        #expect(result.annualTotal == 0)
        #expect(result.irmaaTier == -1)
        #expect(result.medigap == nil)
        #expect(result.advantagePremium == nil)
    }
}

@Suite("MedicareCostEngine — Original Medicare path")
struct MedicareCostEngineOriginalTests {

    @Test("Original Medicare tier 0 (single, MAGI under threshold): Part B + Part D + Medigap, no IRMAA")
    func originalTier0() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = MedicareCostEngine.computeCostForSpouse(
            planType: .originalMedicare,
            irmaaMAGI: IRMAAMAGI(value: 80_000),  // under tier 1 single threshold of 109_001
            partBOverride: nil,
            partDOverride: nil,
            medigapOverride: nil,
            advantageOverride: nil,
            filingStatus: .single,
            config: config
        )
        #expect(result.irmaaTier == 0)
        #expect(result.irmaaSurcharge == 0)
        #expect(result.medigap == 150.00)
        #expect(result.advantagePremium == nil)
        // partB = 185 base + 0 surcharge; partD = 50 base + 0 surcharge; medigap = 150
        // total monthly = 185 + 50 + 150 = 385
        #expect(result.total == 385.00)
        #expect(result.annualTotal == 4_620.00)
    }

    @Test("Original Medicare tier 1 (single, MAGI over threshold): IRMAA surcharge added")
    func originalTier1() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = MedicareCostEngine.computeCostForSpouse(
            planType: .originalMedicare,
            irmaaMAGI: IRMAAMAGI(value: 110_000),  // over tier 1 single threshold of 109_001
            partBOverride: nil,
            partDOverride: nil,
            medigapOverride: nil,
            advantageOverride: nil,
            filingStatus: .single,
            config: config
        )
        #expect(result.irmaaTier == 1)
        // Part B IRMAA tier 1 monthly: 284.10; standard 202.90; surcharge = 81.20
        // Part D IRMAA tier 1 monthly: 14.50 surcharge
        // partB = 185 + 81.20 = 266.20
        // partD = 50 + 14.50 = 64.50
        // medigap = 150
        // total = 266.20 + 64.50 + 150 = 480.70
        #expect(abs(result.partB - 266.20) < 0.01)
        #expect(abs(result.partD - 64.50) < 0.01)
        #expect(result.medigap == 150.00)
        #expect(abs(result.total - 480.70) < 0.01)
    }

    @Test("Original Medicare with overrides: overrides take precedence")
    func originalWithOverrides() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = MedicareCostEngine.computeCostForSpouse(
            planType: .originalMedicare,
            irmaaMAGI: IRMAAMAGI(value: 80_000),
            partBOverride: 200.00,    // user-corrected
            partDOverride: 60.00,
            medigapOverride: 200.00,
            advantageOverride: nil,
            filingStatus: .single,
            config: config
        )
        // tier 0 → no IRMAA surcharge → totals are pure base values
        #expect(result.partB == 200.00)
        #expect(result.partD == 60.00)
        #expect(result.medigap == 200.00)
        #expect(result.total == 460.00)
    }
}
