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
    /// Cost is scaled by `year.medicareEnrolledCount` (0/1/2) so that MFJ couples
    /// where both spouses are on Medicare pay 2× the per-person surcharge. This matches
    /// ProjectionEngine's `taxBreakdown.irmaa` computation.
    private func detectIRMAAHit(
        year: YearRecommendation,
        filingStatus: FilingStatus
    ) -> ConstraintHit? {
        guard let magi = year.irmaaMagi, year.medicareEnrolledCount > 0 else { return nil }
        let result = TaxCalculationEngine.calculateIRMAA(magi: magi, filingStatus: filingStatus)
        guard result.tier > 0 else { return nil }
        return ConstraintHit(
            year: year.year,
            type: .irmaaTier(level: result.tier),
            cost: result.annualSurchargePerPerson * Double(year.medicareEnrolledCount),
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
        //
        // V2.0 SIMPLIFICATION (Gemini review 2026-05-03): this is a conservative MAX
        // cost. Real cost = the actual subsidy the user was receiving (could be much
        // less than the full benchmark premium, especially for users near the upper
        // income range whose subsidy was already small). Using the full benchmark as
        // a blunt deterrent is acceptable for v2.0 — it just means the optimizer is
        // slightly more reluctant to cross the ACA cliff than it strictly needs to be.
        // V2.1 should compute the true subsidy lost based on the user's pre-cliff MAGI.
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
    /// "Painful" jumps are 12%→22% and 22%→24%, since those are the transitions most
    /// Roth-conversion planning aims to avoid.
    ///
    /// Cost is CUMULATIVE across all bracket boundaries crossed. A jump from 12% all
    /// the way to 24% pays both the 22%-vs-12% penalty on the dollars between
    /// threshold22 and threshold24, AND the 24%-vs-22% penalty on the dollars above
    /// threshold24. The previous implementation only counted the highest marginal jump
    /// and lost the 12→22 portion entirely on multi-bracket conversions, causing the
    /// optimizer to accept aggressive conversions that looked cheaper than they were
    /// (Gemini review 2026-05-03).
    ///
    /// Implicit assumption: cost is computed as if the user is "natively" in the 12%
    /// bracket. Users with native taxable income already in 22% see a slight over-count
    /// of the 12→22 portion. This is conservative (favors rejecting aggressive trades
    /// rather than accepting bad ones) and acceptable for v2.0. v2.1 should compute
    /// pre-conversion income to attribute the marginal cost more precisely.
    ///
    /// Type:
    ///   - 12→24: income > threshold24 (most severe; reports the full traversal)
    ///   - 12→22: income > threshold22 but ≤ threshold24
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

        // Multi-bracket jump: income crossed both 22% AND 24% thresholds.
        // Sum the penalties for both crossings.
        if income > threshold24 {
            let twentyTwoPortion = (threshold24 - threshold22) * 0.10  // 22% - 12% = 10pp
            let twentyFourPortion = (income - threshold24) * 0.02      // 24% - 22% = 2pp
            let cost = twentyTwoPortion + twentyFourPortion
            return ConstraintHit(
                year: year.year,
                type: .bracketOverrun(fromBracket: 12, toBracket: 24),
                cost: cost,
                acceptanceRationale: ""
            )
        }

        // Single-boundary 12→22: income crossed above 22% bracket start but didn't reach 24%
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
