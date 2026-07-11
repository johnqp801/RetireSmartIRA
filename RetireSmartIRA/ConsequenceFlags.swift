//
//  ConsequenceFlags.swift
//  RetireSmartIRA
//
//  Which tax/benefit effects the selected Roth-conversion approach triggered relative to taking
//  NO additional conversions (the no-conversion baseline path). Explanatory context for the dollar
//  deltas in ConsequenceDeltas (2.1.0). Each flag is the OR across horizon years, comparing the
//  selected path to the no-conversion path aligned by `year`. Per-conversion attribution is 2.1.1.
//

import Foundation

struct ConsequenceFlags: Equatable, Sendable {
    let ssTaxationIncreased: Bool
    let irmaaTierCrossed: Bool
    let acaCliffCrossed: Bool
    let ordinaryBracketCrossed: Bool
    let capGainBracketAffected: Bool
    let niitIncreased: Bool

    /// Memberwise (used by tests / callers that already know the booleans).
    init(ssTaxationIncreased: Bool, irmaaTierCrossed: Bool, acaCliffCrossed: Bool,
         ordinaryBracketCrossed: Bool, capGainBracketAffected: Bool, niitIncreased: Bool) {
        self.ssTaxationIncreased = ssTaxationIncreased
        self.irmaaTierCrossed = irmaaTierCrossed
        self.acaCliffCrossed = acaCliffCrossed
        self.ordinaryBracketCrossed = ordinaryBracketCrossed
        self.capGainBracketAffected = capGainBracketAffected
        self.niitIncreased = niitIncreased
    }

    /// Derive the triggered-effect flags by comparing the selected path to the no-conversion
    /// baseline, year by year. A flag is true if ANY aligned year trips the effect.
    ///
    /// `householdSize` feeds the ACA 400%-FPL cliff lookup (household FPL is size-dependent);
    /// it defaults to 1 for callers that only care about the ordinary/SS/IRMAA/cap-gain flags.
    /// All threshold sources are the app's live config/engine lookups — no hardcoded tax numbers.
    init(selected: [YearRecommendation], noConversion: [YearRecommendation],
         filingStatus: FilingStatus, configProvider: TaxYearConfigProvider,
         householdSize: Int = 1) {
        let baseByYear = Dictionary(noConversion.map { ($0.year, $0) }, uniquingKeysWith: { a, _ in a })

        var ss = false, tier = false, cliff = false, ord = false, cap = false, niit = false
        for s in selected {
            guard let b = baseByYear[s.year] else { continue }

            // SS taxation and NIIT: direct dollar comparisons (>$1 to ignore rounding).
            if s.taxableSocialSecurity > b.taxableSocialSecurity + 1 { ss = true }
            if s.taxBreakdown.niit > b.taxBreakdown.niit + 1 { niit = true }

            // Ordinary bracket: same config bracket table ConstraintAcceptor uses, selected by
            // filing status. ordinaryTaxable = taxableIncome − taxablePreferential.
            let brackets = configProvider.config(forYear: s.year).toTaxBrackets()
            let ordinaryBrackets = filingStatus == .single ? brackets.federalSingle : brackets.federalMarried
            let sOrd = s.taxableIncome - s.taxablePreferential
            let bOrd = b.taxableIncome - b.taxablePreferential
            if Self.bracketIndex(sOrd, ordinaryBrackets) > Self.bracketIndex(bOrd, ordinaryBrackets) { ord = true }

            // Cap-gain preferential bracket: conservatively derived from the config's LTCG
            // breakpoints. Added ordinary income can push the LTCG stack into a higher bracket.
            if Self.ltcgBracketIndex(ordinary: sOrd, preferential: s.taxablePreferential, brackets: brackets, filingStatus: filingStatus)
                > Self.ltcgBracketIndex(ordinary: bOrd, preferential: b.taxablePreferential, brackets: brackets, filingStatus: filingStatus) {
                cap = true
            }

            // IRMAA tier: the exact lookup ConstraintAcceptor uses (TaxCalculationEngine.calculateIRMAA).
            if let sMagi = s.irmaaMagi, let bMagi = b.irmaaMagi,
               Self.irmaaTier(sMagi, filingStatus) > Self.irmaaTier(bMagi, filingStatus) {
                tier = true
            }

            // ACA cliff: selected crossed the 400%-FPL cliff the baseline was under. Reuses the
            // ACA engine's own data-driven cliff detection (ACASubsidyEngine.isOverCliff).
            if let sAca = s.acaMagi, let bAca = b.acaMagi,
               Self.aboveACACliff(sAca, s.year, householdSize, configProvider),
               !Self.aboveACACliff(bAca, b.year, householdSize, configProvider) {
                cliff = true
            }
        }
        self.init(ssTaxationIncreased: ss, irmaaTierCrossed: tier, acaCliffCrossed: cliff,
                  ordinaryBracketCrossed: ord, capGainBracketAffected: cap, niitIncreased: niit)
    }

    // MARK: - Private lookup helpers (reuse the app's existing config/engine sources)

    /// Index of the highest bracket whose lower bound `income` reaches. Brackets are ascending by
    /// threshold, matching TaxCalculationEngine.progressiveTax's bracket convention.
    private static func bracketIndex(_ income: Double, _ brackets: [TaxBracket]) -> Int {
        var idx = 0
        for (i, bracket) in brackets.enumerated() where income >= bracket.threshold {
            idx = i
        }
        return idx
    }

    /// Preferential-rate (0/15/20%) bracket index of the LTCG stack, or 0 when there is no
    /// preferential income that year. LTCG stacks on top of ordinary income, so the marginal
    /// preferential dollar sits at `ordinary + preferential` within the config's cap-gains
    /// breakpoints (federalCapGainsSingle / federalCapGainsMarried from TaxYearConfig).
    private static func ltcgBracketIndex(ordinary: Double, preferential: Double,
                                         brackets: TaxBrackets, filingStatus: FilingStatus) -> Int {
        guard preferential > 0 else { return 0 }
        let capGainsBrackets = filingStatus == .single
            ? brackets.federalCapGainsSingle : brackets.federalCapGainsMarried
        return bracketIndex(ordinary + preferential, capGainsBrackets)
    }

    /// IRMAA tier for a MAGI, via the same engine lookup ConstraintAcceptor uses
    /// (TaxCalculationEngine.calculateIRMAA(magi:filingStatus:).tier).
    private static func irmaaTier(_ magi: Double, _ filingStatus: FilingStatus) -> Int {
        TaxCalculationEngine.calculateIRMAA(magi: magi, filingStatus: filingStatus).tier
    }

    /// Whether an ACA MAGI is at/above the subsidy cliff, reusing the ACA engine's own data-driven
    /// cliff detection (ACASubsidyEngine.calculateSubsidy(...).isOverCliff) with the live config.
    private static func aboveACACliff(_ magi: Double, _ year: Int, _ householdSize: Int,
                                      _ configProvider: TaxYearConfigProvider) -> Bool {
        let config = configProvider.config(forYear: year)
        return ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: magi),
            householdSize: householdSize,
            benchmarkSilverPlanAnnualPremium: config.acaSubsidy2026.nationalAvgBenchmarkSilverPlanAnnual,
            config: config
        ).isOverCliff
    }
}
