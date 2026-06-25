//
//  CliffCandidateGeneratorTests.swift
//  RetireSmartIRATests
//
//  Tests for OptimizationEngine.cliffCandidates(...) — verifies the per-year
//  cliff candidate generator produces targets aligned to IRMAA, ACA 400% FPL,
//  and ordinary tax bracket boundaries.
//
//  Determinism: every case injects a FIXED config provider (`.fixed(config2026)`)
//  so results never depend on the process-global `TaxCalculationEngine.config`
//  static (which a TEST-ONLY swap elsewhere could mutate under parallel execution).
//  Value expectations are DERIVED from that config's published thresholds, so a future
//  bracket/IRMAA/FPL refresh updates the expected value automatically instead of leaving
//  a stale magic number. (This replaced a hardcoded ACA FPL of 21_640, which drifted from
//  the shipped 2026 value of 21_150 after the 1.8.7 FPL refresh on main.)
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("OptimizationEngine.cliffCandidates")
struct CliffCandidateGeneratorTests {

    /// The real bundled 2026 config, pinned so tests never read the global static.
    private let config2026 = TaxYearConfig.loadOrFallback(forYear: 2026)
    private var provider: TaxYearConfigProvider { .fixed(config2026) }
    private let buffer = 5_000.0

    private func makeAssumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(cliffBuffer: buffer)
    }

    @Test("Generates IRMAA Tier 1 fill candidate for MFJ baseline below threshold")
    func irmaaTier1MFJ() {
        let baselineMagi = 150_000.0
        let tier1 = config2026.irmaaTiers.first { $0.tier == 1 }!.mfjThreshold
        let expected = tier1 - buffer - baselineMagi
        let candidates = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: baselineMagi,
            baselineACAMagi: nil,
            baselineTaxableIncome: 130_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions(),
            configProvider: provider
        )
        #expect(candidates.contains(where: { abs($0 - expected) < 1 }),
            "Expected IRMAA Tier 1 fill ~\(expected); got \(candidates)")
    }

    @Test("Generates IRMAA Tier 2 fill candidate for MFJ")
    func irmaaTier2MFJ() {
        let baselineMagi = 150_000.0
        let tier2 = config2026.irmaaTiers.first { $0.tier == 2 }!.mfjThreshold
        let expected = tier2 - buffer - baselineMagi
        let candidates = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: baselineMagi,
            baselineACAMagi: nil,
            baselineTaxableIncome: 130_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions(),
            configProvider: provider
        )
        #expect(candidates.contains(where: { abs($0 - expected) < 1 }),
            "Expected IRMAA Tier 2 fill ~\(expected); got \(candidates)")
    }

    @Test("Generates ACA 400% FPL fill candidate when ACA-relevant")
    func acaCliffMFJHousehold2() {
        // Derived from the shipped 2026 FPL (household size 2 = 21_150):
        //   400% FPL = 84_600; target = 84_600 - buffer; candidate = target - baselineACAMagi.
        let baselineACAMagi = 50_000.0
        let fplHH2 = config2026.acaSubsidy2026.fpl2026.householdSizeToFPL["2"]!
        let expected = (fplHH2 * 4.0) - buffer - baselineACAMagi
        let candidates = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: nil,
            baselineACAMagi: baselineACAMagi,
            baselineTaxableIncome: 30_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions(),
            configProvider: provider
        )
        #expect(candidates.contains(where: { abs($0 - expected) < 1 }),
            "Expected ACA 400% FPL fill ~\(expected) (FPL HH2 \(fplHH2)); got \(candidates)")
    }

    @Test("Generates ordinary bracket fill candidates with no buffer")
    func bracketFillNoBuffer() {
        // For each MFJ bracket top above the baseline, expect exactly (top - baseline),
        // no buffer subtracted. Brackets come from the injected config for full determinism.
        let baseline = 50_000.0
        let candidates = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: nil,
            baselineACAMagi: nil,
            baselineTaxableIncome: baseline,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions(),
            configProvider: provider
        )
        let bracketArray = config2026.toTaxBrackets().federalMarried
        for i in 0..<(bracketArray.count - 1) {
            let top = bracketArray[i + 1].threshold
            let expected = top - baseline
            if expected > 0 && expected <= 500_000 {
                #expect(candidates.contains(where: { abs($0 - expected) < 1 }),
                    "Expected bracket fill of \(expected) for MFJ bracket top \(top); got \(candidates)")
            }
        }
    }

    @Test("Skips IRMAA candidates when irmaaMagi is nil (pre-Medicare)")
    func skipsIRMAAWhenNotMedicareEligible() {
        let candidatesWithoutIRMAA = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: nil,
            baselineACAMagi: 50_000,
            baselineTaxableIncome: 30_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions(),
            configProvider: provider
        )
        let candidatesWithIRMAA = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: 150_000,
            baselineACAMagi: 50_000,
            baselineTaxableIncome: 30_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions(),
            configProvider: provider
        )
        // With irmaaMagi set, more candidates should appear (the IRMAA tier deltas)
        #expect(candidatesWithIRMAA.count > candidatesWithoutIRMAA.count,
            "Adding IRMAA baseline should add cliff candidates")
    }

    @Test("Skips ACA cliff when acaMagi is nil")
    func skipsACAWhenNotEnrolled() {
        let withoutACA = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: 150_000,
            baselineACAMagi: nil,
            baselineTaxableIncome: 130_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions(),
            configProvider: provider
        )
        let withACA = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: 150_000,
            baselineACAMagi: 50_000,
            baselineTaxableIncome: 130_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions(),
            configProvider: provider
        )
        #expect(withACA.count > withoutACA.count,
            "Adding ACA baseline should add the ACA cliff candidate")
    }

    @Test("Drops candidates with non-positive deltas (cliff already passed)")
    func dropsNegativeDeltas() {
        // Baseline irmaaMagi = 800_000 → above all IRMAA tiers including Tier 5 (750_001).
        let candidates = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: 800_000,
            baselineACAMagi: nil,
            baselineTaxableIncome: 770_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions(),
            configProvider: provider
        )
        for c in candidates {
            #expect(c > 0, "Candidate \(c) should be positive (we drop negative deltas)")
        }
    }

    @Test("Drops candidates above $500K cap")
    func dropsCandidatesAboveCap() {
        // Baseline irmaaMagi = 0, MFJ. IRMAA Tier 5 = 750_001, buffer = 5_000.
        // Candidate = 750_001 - 5_000 - 0 = 745_001 > 500K cap → must be dropped.
        let candidates = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: 0,
            baselineACAMagi: nil,
            baselineTaxableIncome: 0,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions(),
            configProvider: provider
        )
        for c in candidates {
            #expect(c <= 500_000, "Candidate \(c) exceeds 500_000 cap")
        }
    }
}
