//
//  TaxYearConfig.swift
//  RetireSmartIRA
//
//  Defines the tax year configuration schema and loading logic.
//  All year-dependent tax constants are loaded from a bundled JSON file
//  (e.g., tax-2026.json) so annual updates require only a new JSON file.
//

import Foundation

struct TaxYearConfig: Codable {
    let taxYear: Int

    // MARK: - Federal Income Tax Brackets
    let federalBracketsSingle: [BracketEntry]
    let federalBracketsMFJ: [BracketEntry]
    let federalCapGainsBracketsSingle: [BracketEntry]
    let federalCapGainsBracketsMFJ: [BracketEntry]

    // MARK: - Standard Deduction
    let standardDeductionSingle: Double
    let standardDeductionMFJ: Double
    let additionalDeduction65Single: Double
    let additionalDeduction65MFJ: Double

    // MARK: - OBBBA Senior Bonus (2025-2028)
    let seniorBonusPerPerson: Double
    let seniorBonusPhaseoutSingle: Double
    let seniorBonusPhaseoutMFJ: Double
    let seniorBonusPhaseoutRate: Double
    let seniorBonusFirstYear: Int
    let seniorBonusLastYear: Int

    // MARK: - SALT Cap (OBBBA 2025-2029)
    let saltBaseCap: Double
    let saltInflationRate: Double
    let saltBaseYear: Int
    let saltPhaseoutBaseThreshold: Double
    let saltPhaseoutRate: Double
    let saltFloor: Double
    let saltExpandedFirstYear: Int
    let saltExpandedLastYear: Int
    let saltDefaultCap: Double

    // MARK: - AMT
    let amtExemptionSingle: Double
    let amtExemptionMFJ: Double
    let amtPhaseoutThresholdSingle: Double
    let amtPhaseoutThresholdMFJ: Double
    let amtPhaseoutRate: Double
    let amt26PercentLimit: Double
    let amtRate26: Double
    let amtRate28: Double

    // MARK: - IRMAA (Medicare)
    let irmaaStandardPartB: Double
    let irmaaTiers: [IRMAATierEntry]

    // MARK: - NIIT
    let niitRate: Double
    let niitThresholdSingle: Double
    let niitThresholdMFJ: Double

    // MARK: - Social Security Taxation
    let ssTaxationThreshold1Single: Double
    let ssTaxationThreshold2Single: Double
    let ssTaxationThreshold1MFJ: Double
    let ssTaxationThreshold2MFJ: Double

    // MARK: - QCD
    let qcdAnnualLimit: Double

    // MARK: - California Exemption Credits
    let caExemptionCreditPerPerson: Double
    let caExemptionPhaseoutSingle: Double
    let caExemptionPhaseoutMFJ: Double
    let caExemptionPhaseoutReductionPer2500: Double

    // MARK: - Medical Deduction
    let medicalAGIFloorRate: Double

    // MARK: - Contribution Limits (1.9)
    let contributionLimits401k: ContributionLimits401k
    let contributionLimitsIRA: ContributionLimitsIRA
    let contributionLimitsHSA: ContributionLimitsHSA

    // MARK: - Medicare Premium Defaults (1.9)
    let medicare2026: MedicarePremiumDefaults

    // MARK: - ACA Subsidy (1.9)
    let acaSubsidy2026: ACASubsidyConfig

    // MARK: - Nested Types

    struct BracketEntry: Codable {
        let threshold: Double
        let rate: Double
    }

    struct IRMAATierEntry: Codable {
        let tier: Int
        let singleThreshold: Double
        let mfjThreshold: Double
        let partBMonthly: Double
        let partDMonthly: Double
    }

    struct ContributionLimits401k: Codable {
        let base: Double
        let catchupAge50To59: Double
        let catchupAge60To63: Double
        let catchupAge64Plus: Double
    }

    struct ContributionLimitsIRA: Codable {
        let base: Double
        let catchupAge50Plus: Double
    }

    struct ContributionLimitsHSA: Codable {
        let selfOnly: Double
        let family: Double
        let catchupAge55Plus: Double
    }

    struct MedicarePremiumDefaults: Codable {
        let partBStandardMonthly: Double
        let partDAvgMonthly: Double
        let medigapAvgMonthly: Double
        let advantageAvgMonthly: Double
    }

    struct ACASubsidyConfig: Codable {
        let fpl2026: FPL2026
        let applicableFigures: [ApplicableFigure]
        let hasCliff: Bool
        let nationalAvgBenchmarkSilverPlanAnnual: Double

        struct FPL2026: Codable {
            let householdSizeToFPL: [String: Double]
            let alaskaMultiplier: Double
            let hawaiiMultiplier: Double
        }

        struct ApplicableFigure: Codable {
            let fplPercent: Double
            let applicableFigure: Double
        }
    }

    // MARK: - Conversion to App Types

    func toTaxBrackets() -> TaxBrackets {
        TaxBrackets(
            federalSingle: federalBracketsSingle.map { TaxBracket(threshold: $0.threshold, rate: $0.rate) },
            federalMarried: federalBracketsMFJ.map { TaxBracket(threshold: $0.threshold, rate: $0.rate) },
            federalCapGainsSingle: federalCapGainsBracketsSingle.map { TaxBracket(threshold: $0.threshold, rate: $0.rate) },
            federalCapGainsMarried: federalCapGainsBracketsMFJ.map { TaxBracket(threshold: $0.threshold, rate: $0.rate) }
        )
    }

    func toIRMAATiers() -> [IRMAATier] {
        irmaaTiers.map {
            IRMAATier(tier: $0.tier, singleThreshold: $0.singleThreshold, mfjThreshold: $0.mfjThreshold,
                      partBMonthly: $0.partBMonthly, partDMonthly: $0.partDMonthly)
        }
    }

    // MARK: - Loading

    static func load(forYear year: Int) -> TaxYearConfig? {
        let resource = "tax-\(year)"
        // Search all bundles (main app + test host plugin)
        let bundles = [Bundle.main] + Bundle.allBundles
        for bundle in bundles {
            if let url = bundle.url(forResource: resource, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let config = try? JSONDecoder().decode(TaxYearConfig.self, from: data) {
                return config
            }
        }
        return nil
    }

    /// Loads the config for the given year, falling back to the most recent available.
    /// Returns hardcoded 2026 defaults if no JSON is found (e.g., during unit tests).
    static func loadOrFallback(forYear year: Int) -> TaxYearConfig {
        // Try the exact year first
        if let config = load(forYear: year) { return config }
        // Walk backward to find the most recent config
        for y in stride(from: year - 1, through: 2026, by: -1) {
            if let config = load(forYear: y) { return config }
        }
        // Hardcoded 2026 fallback for unit tests / environments without bundle resources
        return Self.hardcoded2026
    }

    /// Hardcoded 2026 values — used only when bundled JSON cannot be loaded.
    private static let hardcoded2026 = TaxYearConfig(
        taxYear: 2026,
        federalBracketsSingle: [
            BracketEntry(threshold: 0, rate: 0.10), BracketEntry(threshold: 12400, rate: 0.12),
            BracketEntry(threshold: 50400, rate: 0.22), BracketEntry(threshold: 105700, rate: 0.24),
            BracketEntry(threshold: 201775, rate: 0.32), BracketEntry(threshold: 256225, rate: 0.35),
            BracketEntry(threshold: 640600, rate: 0.37)
        ],
        federalBracketsMFJ: [
            BracketEntry(threshold: 0, rate: 0.10), BracketEntry(threshold: 24800, rate: 0.12),
            BracketEntry(threshold: 100800, rate: 0.22), BracketEntry(threshold: 211400, rate: 0.24),
            BracketEntry(threshold: 403550, rate: 0.32), BracketEntry(threshold: 512450, rate: 0.35),
            BracketEntry(threshold: 768700, rate: 0.37)
        ],
        federalCapGainsBracketsSingle: [
            BracketEntry(threshold: 0, rate: 0.0), BracketEntry(threshold: 49450, rate: 0.15),
            BracketEntry(threshold: 545500, rate: 0.20)
        ],
        federalCapGainsBracketsMFJ: [
            BracketEntry(threshold: 0, rate: 0.0), BracketEntry(threshold: 98900, rate: 0.15),
            BracketEntry(threshold: 613700, rate: 0.20)
        ],
        standardDeductionSingle: 16100, standardDeductionMFJ: 32200,
        additionalDeduction65Single: 2050, additionalDeduction65MFJ: 1650,
        seniorBonusPerPerson: 6000, seniorBonusPhaseoutSingle: 75000,
        seniorBonusPhaseoutMFJ: 150000, seniorBonusPhaseoutRate: 0.06,
        seniorBonusFirstYear: 2025, seniorBonusLastYear: 2028,
        saltBaseCap: 40000, saltInflationRate: 0.01, saltBaseYear: 2025,
        saltPhaseoutBaseThreshold: 500000, saltPhaseoutRate: 0.30, saltFloor: 10000,
        saltExpandedFirstYear: 2025, saltExpandedLastYear: 2029, saltDefaultCap: 10000,
        amtExemptionSingle: 90100, amtExemptionMFJ: 140200,
        amtPhaseoutThresholdSingle: 500000, amtPhaseoutThresholdMFJ: 1000000,
        amtPhaseoutRate: 0.50, amt26PercentLimit: 244500, amtRate26: 0.26, amtRate28: 0.28,
        irmaaStandardPartB: 202.90,
        irmaaTiers: [
            IRMAATierEntry(tier: 0, singleThreshold: 0, mfjThreshold: 0, partBMonthly: 202.90, partDMonthly: 0),
            IRMAATierEntry(tier: 1, singleThreshold: 109001, mfjThreshold: 218001, partBMonthly: 284.10, partDMonthly: 14.50),
            IRMAATierEntry(tier: 2, singleThreshold: 137001, mfjThreshold: 274001, partBMonthly: 405.50, partDMonthly: 37.40),
            IRMAATierEntry(tier: 3, singleThreshold: 171001, mfjThreshold: 342001, partBMonthly: 527.00, partDMonthly: 60.30),
            IRMAATierEntry(tier: 4, singleThreshold: 205001, mfjThreshold: 410001, partBMonthly: 608.40, partDMonthly: 83.10),
            IRMAATierEntry(tier: 5, singleThreshold: 500001, mfjThreshold: 750001, partBMonthly: 689.90, partDMonthly: 91.00)
        ],
        niitRate: 0.038, niitThresholdSingle: 200000, niitThresholdMFJ: 250000,
        ssTaxationThreshold1Single: 25000, ssTaxationThreshold2Single: 34000,
        ssTaxationThreshold1MFJ: 32000, ssTaxationThreshold2MFJ: 44000,
        qcdAnnualLimit: 111000,
        caExemptionCreditPerPerson: 144, caExemptionPhaseoutSingle: 252203,
        caExemptionPhaseoutMFJ: 504406, caExemptionPhaseoutReductionPer2500: 6.0,
        medicalAGIFloorRate: 0.075,
        contributionLimits401k: ContributionLimits401k(
            base: 23_500, catchupAge50To59: 7_500,
            catchupAge60To63: 11_250, catchupAge64Plus: 7_500
        ),
        contributionLimitsIRA: ContributionLimitsIRA(
            base: 7_000, catchupAge50Plus: 1_000
        ),
        contributionLimitsHSA: ContributionLimitsHSA(
            selfOnly: 4_300, family: 8_550, catchupAge55Plus: 1_000
        ),
        medicare2026: MedicarePremiumDefaults(
            partBStandardMonthly: 202.90,
            partDAvgMonthly: 50.00,
            medigapAvgMonthly: 150.00,
            advantageAvgMonthly: 50.00
        ),
        acaSubsidy2026: ACASubsidyConfig(
            fpl2026: ACASubsidyConfig.FPL2026(
                householdSizeToFPL: [
                    "1": 15_060, "2": 20_440, "3": 25_820, "4": 31_200,
                    "5": 36_580, "6": 41_960, "7": 47_340, "8": 52_720
                ],
                alaskaMultiplier: 1.25, hawaiiMultiplier: 1.15
            ),
            applicableFigures: [
                ACASubsidyConfig.ApplicableFigure(fplPercent: 100, applicableFigure: 0.00),
                ACASubsidyConfig.ApplicableFigure(fplPercent: 150, applicableFigure: 0.00),
                ACASubsidyConfig.ApplicableFigure(fplPercent: 200, applicableFigure: 0.04),
                ACASubsidyConfig.ApplicableFigure(fplPercent: 250, applicableFigure: 0.06),
                ACASubsidyConfig.ApplicableFigure(fplPercent: 300, applicableFigure: 0.08),
                ACASubsidyConfig.ApplicableFigure(fplPercent: 400, applicableFigure: 1.00)
            ],
            hasCliff: true,
            nationalAvgBenchmarkSilverPlanAnnual: 7_800
        )
    )
}
