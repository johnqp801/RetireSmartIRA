//
//  ConstraintAcceptorTests.swift
//  RetireSmartIRATests
//
//  Tests for ConstraintAcceptor — soft-constraint detection across a
//  [YearRecommendation] path (IRMAA tiers, ACA cliff, bracket overruns).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("ConstraintAcceptor — soft-constraint detection")
@MainActor
struct ConstraintAcceptorTests {

    private func year(
        year: Int,
        agi: Double,
        acaMagi: Double? = nil,
        irmaaMagi: Double? = nil,
        taxableIncome: Double,
        medicareEnrolledCount: Int = 0,
        actions: [LeverAction] = []
    ) -> YearRecommendation {
        YearRecommendation(
            year: year, agi: agi, acaMagi: acaMagi, irmaaMagi: irmaaMagi,
            taxableIncome: taxableIncome,
            taxBreakdown: .zero,
            endOfYearBalances: .zero,
            actions: actions,
            medicareEnrolledCount: medicareEnrolledCount
        )
    }

    // MARK: - IRMAA detection

    @Test("IRMAA: no hit below tier-1 threshold (single, MAGI $95k < $109,001)")
    func irmaaNoHitBelowThreshold() {
        let path = [year(year: 2026, agi: 95_000, irmaaMagi: 95_000, taxableIncome: 80_000)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        #expect(hits.filter { if case .irmaaTier = $0.type { return true } else { return false } }.isEmpty)
    }

    @Test("IRMAA: tier-1 hit at threshold + 1 (single, MAGI $110k > $109,001)")
    func irmaaTier1HitAtThreshold() {
        // 2026 single tier-1 starts at MAGI > $109,001. medicareEnrolledCount=1 (single, on Medicare).
        let path = [year(year: 2026, agi: 110_000, irmaaMagi: 110_000, taxableIncome: 95_000, medicareEnrolledCount: 1)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        let irmaaHits = hits.compactMap { hit -> Int? in
            if case .irmaaTier(let level) = hit.type { return level } else { return nil }
        }
        #expect(irmaaHits.count == 1)
        #expect(irmaaHits[0] >= 1)
        if let hit = hits.first(where: { if case .irmaaTier = $0.type { return true } else { return false } }) {
            #expect(hit.cost > 0)
            #expect(hit.acceptanceRationale == "")  // empty until caller fills in
        }
    }

    @Test("IRMAA: no hit when irmaaMagi is nil (pre-Medicare)")
    func irmaaNoHitWhenNil() {
        let path = [year(year: 2026, agi: 200_000, acaMagi: 200_000, irmaaMagi: nil, taxableIncome: 170_000)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        #expect(hits.filter { if case .irmaaTier = $0.type { return true } else { return false } }.isEmpty)
    }

    // MARK: - ACA cliff

    @Test("ACA: no cliff hit when MAGI < 400% FPL (single, $50k < $60,240)")
    func acaNoCliffBelowThreshold() {
        let path = [year(year: 2026, agi: 50_000, acaMagi: 50_000, taxableIncome: 35_000)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        #expect(hits.filter { $0.type == .acaCliff }.isEmpty)
    }

    @Test("ACA: cliff hit when MAGI > 400% FPL (single, $80k > $60,240)")
    func acaCliffAboveThreshold() {
        // 400% FPL single 2026 = 4 × $15,060 = $60,240
        let path = [year(year: 2026, agi: 80_000, acaMagi: 80_000, taxableIncome: 65_000)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        #expect(hits.contains { $0.type == .acaCliff })
        if let hit = hits.first(where: { $0.type == .acaCliff }) {
            #expect(hit.cost > 0)
            #expect(hit.acceptanceRationale == "")
        }
    }

    @Test("ACA: no cliff hit when acaMagi is nil (post-Medicare)")
    func acaNoCliffWhenNil() {
        let path = [year(year: 2026, agi: 200_000, acaMagi: nil, irmaaMagi: 200_000, taxableIncome: 150_000)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        #expect(hits.filter { $0.type == .acaCliff }.isEmpty)
    }

    // MARK: - Bracket overrun

    @Test("Bracket: 12% → 22% overrun flagged (single, taxableIncome $60k > $50,400)")
    func bracket12to22Overrun() {
        // 2026 single: 12% bracket ends at $50,400; 22% starts at $50,400
        let path = [year(year: 2026, agi: 80_000, taxableIncome: 60_000)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        let overruns = hits.compactMap { hit -> (Int, Int)? in
            if case .bracketOverrun(let from, let to) = hit.type { return (from, to) } else { return nil }
        }
        #expect(overruns.contains { $0.0 == 12 && $0.1 == 22 })
        if let hit = hits.first(where: { if case .bracketOverrun(12, 22) = $0.type { return true } else { return false } }) {
            #expect(hit.cost > 0)
            // cost ≈ (60000 - 50400) × 0.10 = $960
            #expect(hit.cost.rounded() == 960.0)
            #expect(hit.acceptanceRationale == "")
        }
    }

    @Test("Bracket: no overrun if income fits in 12% bracket (single, $30k < $50,400)")
    func bracketNoOverrunInside12() {
        let path = [year(year: 2026, agi: 50_000, taxableIncome: 30_000)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        #expect(hits.filter { if case .bracketOverrun = $0.type { return true } else { return false } }.isEmpty)
    }

    @Test("Bracket: 22% → 24% overrun flagged when income crosses into 24% band")
    func bracket22to24Overrun() {
        // 2026 single: 22% band is $50,400–$105,700; 24% starts at $105,700.
        // taxableIncome $110k is INSIDE 24%, so the more severe overrun (22→24) should be
        // emitted. (Previously this test asserted 12→22 fired here, which masked a dead-code
        // bug where the 24% branch was unreachable.)
        let path = [year(year: 2026, agi: 135_000, taxableIncome: 110_000)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        let overruns = hits.compactMap { hit -> (Int, Int)? in
            if case .bracketOverrun(let from, let to) = hit.type { return (from, to) } else { return nil }
        }
        #expect(overruns.count == 1)
        #expect(overruns[0].0 == 22 && overruns[0].1 == 24)
        // Cost = (110,000 - 105,700) × 0.02 = $86
        if let hit = hits.first(where: { if case .bracketOverrun = $0.type { return true } else { return false } }) {
            #expect(abs(hit.cost - 86.0) < 1.0)
        }
    }

    @Test("Bracket: 12% → 22% emitted (not 22→24) when income inside 22% band")
    func bracket12to22OnlyWhenInside22Band() {
        // 2026 single: income $80k is between threshold22 ($50,400) and threshold24 ($105,700).
        // Should emit 12→22 only — the 22→24 branch must NOT fire.
        let path = [year(year: 2026, agi: 95_000, taxableIncome: 80_000)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        let overruns = hits.compactMap { hit -> (Int, Int)? in
            if case .bracketOverrun(let from, let to) = hit.type { return (from, to) } else { return nil }
        }
        #expect(overruns.count == 1)
        #expect(overruns[0].0 == 12 && overruns[0].1 == 22)
    }

    @Test("Bracket: MFJ 12% → 22% overrun flagged (MFJ, taxableIncome $110k > $100,800)")
    func bracket12to22OverrunMFJ() {
        // 2026 MFJ: 12% bracket ends at $100,800; 22% starts at $100,800
        let path = [year(year: 2026, agi: 130_000, taxableIncome: 110_000)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .marriedFilingJointly, householdSize: 2)
        let overruns = hits.compactMap { hit -> (Int, Int)? in
            if case .bracketOverrun(let from, let to) = hit.type { return (from, to) } else { return nil }
        }
        #expect(overruns.contains { $0.0 == 12 && $0.1 == 22 })
    }

    // MARK: - Multi-year path

    @Test("Detect: aggregates hits across multi-year paths")
    func detectAcrossMultipleYears() {
        let path = [
            year(year: 2026, agi: 130_000, irmaaMagi: 130_000, taxableIncome: 110_000, medicareEnrolledCount: 1),  // IRMAA tier 1
            year(year: 2027, agi: 130_000, irmaaMagi: 130_000, taxableIncome: 110_000, medicareEnrolledCount: 1),  // IRMAA tier 1 again
            year(year: 2028, agi: 50_000, taxableIncome: 30_000)                                                   // no hits
        ]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        let irmaaHits = hits.filter { if case .irmaaTier = $0.type { return true } else { return false } }
        #expect(irmaaHits.count == 2)
        #expect(irmaaHits[0].year == 2026)
        #expect(irmaaHits[1].year == 2027)
    }

    @Test("Detect: empty path returns empty hits")
    func detectEmptyPath() {
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: [], filingStatus: .single, householdSize: 1)
        #expect(hits.isEmpty)
    }

    // MARK: - Acceptance rationale formatter

    @Test("Rationale: formats lifetime savings and cost as currency")
    func rationaleFormatsCurrency() {
        let acceptor = ConstraintAcceptor()
        let rationale = acceptor.formatAcceptanceRationale(lifetimeSavings: 18_400, constraintCost: 2_100)
        #expect(rationale.contains("18"))
        #expect(rationale.contains("2"))
        #expect(rationale.contains("$"))
    }

    @Test("Rationale: contains both savings and cost amounts")
    func rationaleContainsBothAmounts() {
        let acceptor = ConstraintAcceptor()
        let rationale = acceptor.formatAcceptanceRationale(lifetimeSavings: 50_000, constraintCost: 3_000)
        #expect(rationale.contains("50"))
        #expect(rationale.contains("3"))
        #expect(rationale.lowercased().contains("savings") || rationale.lowercased().contains("lifetime"))
    }

    // MARK: - IRMAA Medicare-enrolled-count scaling (Bug #1 fix)

    /// Helper: build a YearRecommendation with irmaaMagi set and a specific medicareEnrolledCount.
    private func irmaaYear(
        irmaaMagi: Double,
        medicareEnrolledCount: Int,
        filingStatus: FilingStatus = .single
    ) -> YearRecommendation {
        YearRecommendation(
            year: 2030,
            agi: irmaaMagi,
            acaMagi: nil,
            irmaaMagi: irmaaMagi,
            taxableIncome: irmaaMagi,
            taxBreakdown: .zero,
            endOfYearBalances: .zero,
            actions: [],
            medicareEnrolledCount: medicareEnrolledCount
        )
    }

    @Test("IRMAA: single filer (count=1) — ConstraintHit cost == 1× annualSurchargePerPerson")
    func irmaaSingleFilerCostIs1x() {
        // Single, MAGI well above tier-1 threshold so surcharge is non-zero.
        let magi = 150_000.0
        let path = [irmaaYear(irmaaMagi: magi, medicareEnrolledCount: 1)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        let irmaaHits = hits.filter { if case .irmaaTier = $0.type { return true } else { return false } }
        #expect(irmaaHits.count == 1)
        let perPerson = TaxCalculationEngine.calculateIRMAA(magi: magi, filingStatus: .single).annualSurchargePerPerson
        #expect(abs(irmaaHits[0].cost - perPerson * 1.0) < 0.01)
    }

    @Test("IRMAA: MFJ both on Medicare (count=2) — ConstraintHit cost == 2× annualSurchargePerPerson")
    func irmaaMFJBothOnMedicareCostIs2x() {
        // MFJ, MAGI above MFJ tier-1 threshold ($218,001); both on Medicare.
        let magi = 300_000.0
        let path = [irmaaYear(irmaaMagi: magi, medicareEnrolledCount: 2, filingStatus: .marriedFilingJointly)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .marriedFilingJointly, householdSize: 2)
        let irmaaHits = hits.filter { if case .irmaaTier = $0.type { return true } else { return false } }
        #expect(irmaaHits.count == 1)
        let perPerson = TaxCalculationEngine.calculateIRMAA(magi: magi, filingStatus: .marriedFilingJointly).annualSurchargePerPerson
        #expect(abs(irmaaHits[0].cost - perPerson * 2.0) < 0.01)
    }

    @Test("IRMAA: MFJ only primary on Medicare (count=1) — ConstraintHit cost == 1× annualSurchargePerPerson")
    func irmaaMFJOnlyPrimaryOnMedicareCostIs1x() {
        // MFJ, MAGI above MFJ tier-1 threshold; only primary on Medicare.
        let magi = 300_000.0
        let path = [irmaaYear(irmaaMagi: magi, medicareEnrolledCount: 1, filingStatus: .marriedFilingJointly)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .marriedFilingJointly, householdSize: 2)
        let irmaaHits = hits.filter { if case .irmaaTier = $0.type { return true } else { return false } }
        #expect(irmaaHits.count == 1)
        let perPerson = TaxCalculationEngine.calculateIRMAA(magi: magi, filingStatus: .marriedFilingJointly).annualSurchargePerPerson
        #expect(abs(irmaaHits[0].cost - perPerson * 1.0) < 0.01)
    }

    @Test("IRMAA: count=0 — no IRMAA hit even with irmaaMagi set (no one on Medicare)")
    func irmaaCount0NoHitEvenWithMagi() {
        // irmaaMagi is set (e.g. lookback window age 63) but no one is enrolled yet.
        let path = [irmaaYear(irmaaMagi: 200_000.0, medicareEnrolledCount: 0)]
        let acceptor = ConstraintAcceptor()
        let hits = acceptor.detect(path: path, filingStatus: .single, householdSize: 1)
        #expect(hits.filter { if case .irmaaTier = $0.type { return true } else { return false } }.isEmpty)
    }
}
