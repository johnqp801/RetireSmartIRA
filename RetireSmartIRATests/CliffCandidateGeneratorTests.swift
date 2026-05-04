//
//  CliffCandidateGeneratorTests.swift
//  RetireSmartIRATests
//
//  Tests for OptimizationEngine.cliffCandidates(...) — verifies the per-year
//  cliff candidate generator produces targets aligned to IRMAA, ACA 400% FPL,
//  and ordinary tax bracket boundaries.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("OptimizationEngine.cliffCandidates")
struct CliffCandidateGeneratorTests {

    private func makeAssumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(cliffBuffer: 5_000)
    }

    @Test("Generates IRMAA Tier 1 fill candidate for MFJ baseline below threshold")
    func irmaaTier1MFJ() {
        // 2026 MFJ IRMAA Tier 1 threshold: 218_001 (from TaxYearConfig.config.irmaaTiers).
        // Baseline irmaaMagi = 150_000 → target = 218_001 - 5_000 - 150_000 = 63_001
        let candidates = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: 150_000,
            baselineACAMagi: nil,
            baselineTaxableIncome: 130_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions()
        )
        #expect(candidates.contains(where: { abs($0 - 63_001) < 1 }),
            "Expected IRMAA Tier 1 fill ~$63,001; got \(candidates)")
    }

    @Test("Generates IRMAA Tier 2 fill candidate for MFJ")
    func irmaaTier2MFJ() {
        // 2026 MFJ IRMAA Tier 2 threshold: 274_001
        // 274_001 - 5_000 - 150_000 = 119_001
        let candidates = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: 150_000,
            baselineACAMagi: nil,
            baselineTaxableIncome: 130_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions()
        )
        #expect(candidates.contains(where: { abs($0 - 119_001) < 1 }),
            "Expected IRMAA Tier 2 fill ~$119,001; got \(candidates)")
    }

    @Test("Generates ACA 400% FPL fill candidate when ACA-relevant")
    func acaCliffMFJHousehold2() {
        // Updated 2026-05-03 (constants refresh): old FPL HH2 20_440 / 400% = 81_760 / candidate 26_760.
        // New FPL HH2 = 21_640. 400% = 86_560. Target = 86_560 - 5_000 = 81_560
        // Baseline acaMagi = 50_000 → candidate = 81_560 - 50_000 = 31_560
        let candidates = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: nil,
            baselineACAMagi: 50_000,
            baselineTaxableIncome: 30_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions()
        )
        #expect(candidates.contains(where: { abs($0 - 31_560) < 1 }),
            "Expected ACA 400% FPL fill ~$31,560; got \(candidates)")
    }

    @Test("Generates ordinary bracket fill candidates with no buffer")
    func bracketFillNoBuffer() {
        // Baseline taxable income = 50_000. The 2026 MFJ 22% bracket top is at some value
        // (read from TaxYearConfig). Whatever it is, the candidate should be exactly
        // (top - baseline), no buffer.
        let candidates = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: nil,
            baselineACAMagi: nil,
            baselineTaxableIncome: 50_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions()
        )
        // For each MFJ bracket top above 50_000, expect exactly (top - 50_000) as a candidate
        // (no buffer subtracted). The bracket "tops" come from bracket[i+1].threshold for
        // each bracket i in the federalMarried array (drop the last bracket which has no top).
        // Note: the config singleton lives on TaxCalculationEngine, not TaxYearConfig.
        let bracketArray = TaxCalculationEngine.config.toTaxBrackets().federalMarried
        for i in 0..<(bracketArray.count - 1) {
            let top = bracketArray[i + 1].threshold
            let expected = top - 50_000
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
            assumptions: makeAssumptions()
        )
        let candidatesWithIRMAA = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: 150_000,
            baselineACAMagi: 50_000,
            baselineTaxableIncome: 30_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions()
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
            assumptions: makeAssumptions()
        )
        let withACA = OptimizationEngine.cliffCandidates(
            forYear: 2026,
            baselineIRMAAMagi: 150_000,
            baselineACAMagi: 50_000,
            baselineTaxableIncome: 130_000,
            filingStatus: .marriedFilingJointly,
            householdSize: 2,
            assumptions: makeAssumptions()
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
            assumptions: makeAssumptions()
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
            assumptions: makeAssumptions()
        )
        for c in candidates {
            #expect(c <= 500_000, "Candidate \(c) exceeds 500_000 cap")
        }
    }
}
