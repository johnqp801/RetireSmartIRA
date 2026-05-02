//
//  ConstraintAcceptor.swift
//  RetireSmartIRA
//
//  Pure-calculation module that scans a [YearRecommendation] path for soft-constraint
//  hits: IRMAA tier crossings, ACA subsidy cliff trips, and federal bracket overruns.
//
//  Used by OptimizationEngine (Task 1.9) to enrich the tradeOffsAccepted field.
//  Returned ConstraintHits have empty acceptanceRationale — the caller fills that in
//  via formatAcceptanceRationale(lifetimeSavings:constraintCost:) once it has computed
//  whether lifetime savings exceed the constraint cost.
//

import Foundation

struct ConstraintAcceptor {

    init() {}

    // MARK: - Public API

    /// Scan a recommended path for soft-constraint hits across all years.
    ///
    /// Returns `ConstraintHit` values with empty `acceptanceRationale`.
    /// The caller (OptimizationEngine) fills in the rationale via
    /// `formatAcceptanceRationale(lifetimeSavings:constraintCost:)` once it
    /// has compared lifetime savings to the constraint cost.
    func detect(
        path: [YearRecommendation],
        filingStatus: FilingStatus,
        householdSize: Int
    ) -> [ConstraintHit] {
        var hits: [ConstraintHit] = []
        for year in path {
            if let hit = detectIRMAAHit(year: year, filingStatus: filingStatus) {
                hits.append(hit)
            }
            if let hit = detectACAHit(year: year, householdSize: householdSize) {
                hits.append(hit)
            }
            if let hit = detectBracketOverrun(year: year, filingStatus: filingStatus) {
                hits.append(hit)
            }
        }
        return hits
    }

    /// Format a human-readable acceptance rationale for a constraint hit that has been
    /// accepted because lifetime savings exceed the constraint cost.
    ///
    /// Example: `"Lifetime savings $18,400 > constraint cost $2,100"`
    func formatAcceptanceRationale(lifetimeSavings: Double, constraintCost: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        let savingsStr = formatter.string(from: NSNumber(value: lifetimeSavings)) ?? "$\(Int(lifetimeSavings))"
        let costStr = formatter.string(from: NSNumber(value: constraintCost)) ?? "$\(Int(constraintCost))"
        return "Lifetime savings \(savingsStr) > constraint cost \(costStr)"
    }

    // MARK: - Private detectors

    /// Detect an IRMAA tier crossing for a year where `irmaaMagi` is present.
    ///
    /// Returns nil when:
    /// - `irmaaMagi` is nil (person is pre-Medicare)
    /// - The IRMAA result is tier 0 (standard premium, no surcharge)
    ///
    /// **MFJ cost note (v2.0 simplification):** `annualSurchargePerPerson` is the
    /// per-spouse surcharge amount. For MFJ couples where both spouses are on Medicare,
    /// the household actually pays 2× this. Currently the engine surfaces the per-person
    /// cost only — matching `ProjectionEngine`'s `taxBreakdown.irmaa` which is also
    /// per-person. This consistently understates IRMAA cost for couples by half. Acceptable
    /// for v2.0 since the under-count is uniform across all paths the optimizer compares
    /// (relative ranking is preserved); revisit when ProjectionEngine starts modelling
    /// per-spouse Medicare enrollment ages — fix both files together.
    private func detectIRMAAHit(
        year: YearRecommendation,
        filingStatus: FilingStatus
    ) -> ConstraintHit? {
        guard let magi = year.irmaaMagi else { return nil }
        let result = TaxCalculationEngine.calculateIRMAA(magi: magi, filingStatus: filingStatus)
        guard result.tier > 0 else { return nil }
        return ConstraintHit(
            year: year.year,
            type: .irmaaTier(level: result.tier),
            cost: result.annualSurchargePerPerson,
            acceptanceRationale: ""
        )
    }

    /// Detect an ACA subsidy cliff trip for a year where `acaMagi` is present (pre-Medicare).
    ///
    /// The cliff sits at 400% FPL. If the person's ACA MAGI exceeds that threshold,
    /// they lose access to the entire ACA subsidy.
    ///
    /// Cost = the national average benchmark Silver plan annual premium. This is the same
    /// convention used by ScenarioWarningEngine: when over the cliff you owe the full
    /// benchmark premium, so the maximum possible annual loss is the full premium.
    ///
    /// Returns nil when:
    /// - `acaMagi` is nil (person is post-Medicare / ACA-irrelevant)
    /// - MAGI is at or below 400% FPL (no cliff crossed)
    private func detectACAHit(
        year: YearRecommendation,
        householdSize: Int
    ) -> ConstraintHit? {
        guard let magi = year.acaMagi else { return nil }

        let config = TaxCalculationEngine.config
        let acaConfig = config.acaSubsidy2026
        let fplBase = acaConfig.fpl2026.householdSizeToFPL[String(householdSize)]
            ?? acaConfig.fpl2026.householdSizeToFPL[String(min(householdSize, 8))]!
        let cliffThreshold = fplBase * 4.0

        guard magi > cliffThreshold else { return nil }

        // Cost = the national average benchmark Silver plan annual premium.
        // Consistent with ScenarioWarningEngine's dollarImpactPerYear convention:
        // crossing the cliff means the person now owes the full benchmark premium with
        // no subsidy assistance.
        let cost = acaConfig.nationalAvgBenchmarkSilverPlanAnnual

        return ConstraintHit(
            year: year.year,
            type: .acaCliff,
            cost: cost,
            acceptanceRationale: ""
        )
    }

    /// Detect a federal bracket overrun for a year.
    ///
    /// Only the most severe overrun per year is flagged (12→22 takes priority over 22→24).
    /// "Painful" jumps are 12%→22% and 22%→24%, since those are the transitions most
    /// Roth-conversion planning aims to avoid.
    ///
    /// Cost = marginal-rate jump × overrun amount.
    ///   - 12→22: `(taxableIncome - threshold_22) × 0.10`
    ///   - 22→24: `(taxableIncome - threshold_24) × 0.02`
    private func detectBracketOverrun(
        year: YearRecommendation,
        filingStatus: FilingStatus
    ) -> ConstraintHit? {
        let brackets = TaxCalculationEngine.default2026Brackets
        let ordinaryBrackets = filingStatus == .single
            ? brackets.federalSingle
            : brackets.federalMarried

        // Find threshold where rate first becomes 22% and 24%.
        guard
            let threshold22 = ordinaryBrackets.first(where: { $0.rate == 0.22 })?.threshold,
            let threshold24 = ordinaryBrackets.first(where: { $0.rate == 0.24 })?.threshold
        else {
            return nil
        }

        let income = year.taxableIncome

        // Check 24% overrun FIRST (more severe). If income spans threshold24, that's the
        // hit we want to surface — checking 22 first would short-circuit and emit the wrong
        // type with the wrong cost (income > threshold24 implies income > threshold22).
        if income > threshold24 {
            let overrun = income - threshold24
            let cost = overrun * 0.02   // 24% - 22% = 2pp marginal jump
            return ConstraintHit(
                year: year.year,
                type: .bracketOverrun(fromBracket: 22, toBracket: 24),
                cost: cost,
                acceptanceRationale: ""
            )
        }

        // 12→22 overrun: income crossed above 22% bracket start but didn't reach 24%
        if income > threshold22 {
            let overrun = income - threshold22
            let cost = overrun * 0.10   // 22% - 12% = 10pp marginal jump
            return ConstraintHit(
                year: year.year,
                type: .bracketOverrun(fromBracket: 12, toBracket: 22),
                cost: cost,
                acceptanceRationale: ""
            )
        }

        return nil
    }
}
