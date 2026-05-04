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
        // partB = 202.90 base + 0 surcharge; partD = 50 base + 0 surcharge; medigap = 150
        // total monthly = 202.90 + 50 + 150 = 402.90
        #expect(abs(result.total - 402.90) < 0.01)
        #expect(abs(result.annualTotal - 4_834.80) < 0.01)
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
        // partB = 202.90 + 81.20 = 284.10
        // partD = 50 + 14.50 = 64.50
        // medigap = 150
        // total = 284.10 + 64.50 + 150 = 498.60
        #expect(abs(result.partB - 284.10) < 0.01)
        #expect(abs(result.partD - 64.50) < 0.01)
        #expect(result.medigap == 150.00)
        #expect(abs(result.total - 498.60) < 0.01)
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

@Suite("MedicareCostEngine — Medicare Advantage path")
struct MedicareCostEngineAdvantageTests {

    @Test("Advantage tier 0: Part B + Advantage premium (no Part D base, no Medigap)")
    func advantageTier0() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = MedicareCostEngine.computeCostForSpouse(
            planType: .medicareAdvantage,
            irmaaMAGI: IRMAAMAGI(value: 80_000),
            partBOverride: nil, partDOverride: nil,
            medigapOverride: nil, advantageOverride: nil,
            filingStatus: .single,
            config: config
        )
        #expect(result.medigap == nil)
        #expect(result.advantagePremium == 50.00)
        // CORRECTED (ChatGPT review 2026-05-03 #2): MAPD plans include Part D coverage in
        // the Advantage premium. partDBase is now 0 for .medicareAdvantage; Part D IRMAA
        // surcharge still applies (CMS bills it separately) but tier 0 → no IRMAA.
        // partB = 202.90, partD = 0 + 0 IRMAA = 0, advantage = 50 → total = 252.90
        #expect(abs(result.partD - 0.0) < 0.01)
        #expect(abs(result.total - 252.90) < 0.01)
    }

    @Test("Advantage tier 2 MFJ: full MFJ threshold lookup")
    func advantageTier2MFJ() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = MedicareCostEngine.computeCostForSpouse(
            planType: .medicareAdvantage,
            irmaaMAGI: IRMAAMAGI(value: 280_000),  // > MFJ tier 2 threshold of 274_001
            partBOverride: nil, partDOverride: nil,
            medigapOverride: nil, advantageOverride: nil,
            filingStatus: .marriedFilingJointly,
            config: config
        )
        #expect(result.irmaaTier == 2)
        // CORRECTED (ChatGPT review 2026-05-03 #2): MAPD plans include Part D base in
        // the Advantage premium. partDBase is now 0 for .medicareAdvantage; Part D IRMAA
        // surcharge is still separately billed by CMS.
        // Updated 2026-05-03 (constants refresh): old expected partB 405.50/partD 37.40 derived from old constants;
        // new expected partB 405.80/partD 37.50 reflects updated 2026 CMS values.
        // Tier 2: partB monthly 405.80 (surcharge = 405.80 - 202.90 = 202.90)
        //         partD base = 0 (included in Advantage), IRMAA surcharge 37.50
        // partB = 202.90 + 202.90 = 405.80
        // partD = 0 + 37.50 = 37.50
        // advantage = 50
        // total = 493.30
        #expect(abs(result.partB - 405.80) < 0.01)
        #expect(abs(result.partD - 37.50) < 0.01)
        #expect(result.advantagePremium == 50.00)
        #expect(abs(result.total - 493.30) < 0.01)
    }
}

@Suite("MedicareCostEngine — Mixed Household")
struct MedicareCostEngineMixedHouseholdTests {

    @Test("Primary on Medicare, spouse pre-Medicare: per-spouse breakdown distinct")
    func mixedHousehold() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let jointMAGI = IRMAAMAGI(value: 200_000)  // under MFJ tier 1 of 218_001 → tier 0

        let primary = MedicareCostEngine.computeCostForSpouse(
            planType: .originalMedicare,
            irmaaMAGI: jointMAGI,
            partBOverride: nil, partDOverride: nil,
            medigapOverride: nil, advantageOverride: nil,
            filingStatus: .marriedFilingJointly,
            config: config
        )
        let spouse = MedicareCostEngine.computeCostForSpouse(
            planType: .preMedicare,
            irmaaMAGI: jointMAGI,
            partBOverride: nil, partDOverride: nil,
            medigapOverride: nil, advantageOverride: nil,
            filingStatus: .marriedFilingJointly,
            config: config
        )

        #expect(primary.total > 0)
        #expect(spouse.total == 0)
        #expect(primary.irmaaTier == 0)  // joint MAGI under MFJ tier 1
        #expect(spouse.irmaaTier == -1)
    }

    @Test("Mixed household above IRMAA threshold: both Medicare spouses pay surcharge")
    func mixedHouseholdAboveTier() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let jointMAGI = IRMAAMAGI(value: 230_000)  // > MFJ tier 1 threshold of 218_001

        let primary = MedicareCostEngine.computeCostForSpouse(
            planType: .originalMedicare,
            irmaaMAGI: jointMAGI,
            partBOverride: nil, partDOverride: nil,
            medigapOverride: nil, advantageOverride: nil,
            filingStatus: .marriedFilingJointly,
            config: config
        )
        let spouse = MedicareCostEngine.computeCostForSpouse(
            planType: .medicareAdvantage,
            irmaaMAGI: jointMAGI,
            partBOverride: nil, partDOverride: nil,
            medigapOverride: nil, advantageOverride: nil,
            filingStatus: .marriedFilingJointly,
            config: config
        )

        #expect(primary.irmaaTier == 1)
        #expect(spouse.irmaaTier == 1)
        #expect(primary.irmaaSurcharge > 0)
        #expect(spouse.irmaaSurcharge > 0)
    }
}

@Suite("MedicareCostEngine — partBStandardMonthly constant")
struct MedicareCostEngineConstantTests {

    @Test("partBStandardMonthly matches CMS 2026 figure of $202.90")
    func test_partBStandardMonthly_matches_CMS_2026_figure() {
        // CMS published 2026 standard Part B premium is $202.90/month.
        // Source: https://www.cms.gov/newsroom/fact-sheets/2026-medicare-parts-b-premiums-and-deductibles
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        #expect(
            config.medicare2026.partBStandardMonthly == 202.90,
            "partBStandardMonthly must match CMS 2026 figure of $202.90"
        )
    }
}

@Suite("DataManager — householdMedicareCost")
@MainActor
struct DataManagerHouseholdMedicareCostTests {

    @Test("Both spouses pre-Medicare: householdMedicareCost = 0")
    func bothPreMedicare() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.filingStatus = .marriedFilingJointly
        dm.scenario.yourMedicarePlanType = .preMedicare
        dm.scenario.spouseMedicarePlanType = .preMedicare
        #expect(dm.householdMedicareCostAnnual == 0)
    }

    @Test("Single filer on Original Medicare: householdMedicareCost matches engine")
    func singleOriginalMedicare() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.filingStatus = .single
        dm.scenario.yourMedicarePlanType = .originalMedicare
        let primary = dm.primaryMedicareCost
        #expect(primary.planType == .originalMedicare)
        #expect(dm.householdMedicareCostAnnual == primary.annualTotal)
    }
}
