//
//  ComparisonDisplayTests.swift
//  RetireSmartIRATests
//
//  B2 regression: the approach-comparison table's "Lifetime tax" figure must be the
//  PRESENT-VALUE sum (what the optimizer actually minimizes), not the nominal undiscounted
//  sum — otherwise "Minimize lifetime tax" can display a HIGHER lifetime tax than a
//  front-loaded "Fill to bracket" approach (same dollars, different time-weighting; reads
//  as "the minimize option doesn't minimize"). See
//  .claude/memory/roadmap/2026-07-13-multi-year-fix-backlog.md section B2.
//
//  NOTE on scope (A5, tracked separately): the greedy "Minimize lifetime tax" optimizer can
//  be suboptimal even on its OWN present-value objective (a fixed fill/limit approach can
//  beat it on PV). This suite does NOT assert that recommendedTaxMin always ranks lowest —
//  only that the DISPLAYED figure is the PV figure. If a fixture below still shows the
//  ranking inverted after switching to PV, that is Track 2's problem (A5), not this task's.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("B2 — approach-comparison displays PV lifetime tax, not nominal")
@MainActor
struct ComparisonDisplayTests {

    // MARK: - Fabricated repro (fast, no engine run)

    /// Stands in for the $20M MFJ Bob/Sue repro noted in the backlog: fill-to-bracket's nominal
    /// lifetime tax ($718k) came in LOWER than the minimize-lifetime-tax anchor's nominal figure
    /// ($755k), even though the anchor is the one optimizing (a PV) objective. PV figures here are
    /// deliberately the OPPOSITE order, matching what the optimizer actually minimizes.
    private static func fillToBracketColumn() -> ApproachColumn {
        ApproachColumn(lifetimeTaxNominal: 718_000, lifetimeTaxPV: 640_000,
                       endingTraditional: 0, endingRoth: 0, endingTaxable: 0, heirsKeep: 0,
                       peakForcedRMD: 0, peakAnnualRothConversion: 0, terminalPVFactor: 1, path: [])
    }
    private static func minimizeLifetimeTaxColumn() -> ApproachColumn {
        ApproachColumn(lifetimeTaxNominal: 755_000, lifetimeTaxPV: 590_000,
                       endingTraditional: 0, endingRoth: 0, endingTaxable: 0, heirsKeep: 0,
                       peakForcedRMD: 0, peakAnnualRothConversion: 0, terminalPVFactor: 1, path: [])
    }

    @Test("Fabricated repro: nominal ranks minimize-tax WORSE than fill-to-bracket; PV agrees it minimizes")
    func fabricatedReproShowsNominalPvDisagreement() {
        let fill = Self.fillToBracketColumn()
        let taxMin = Self.minimizeLifetimeTaxColumn()
        #expect(taxMin.lifetimeTaxNominal > fill.lifetimeTaxNominal)   // the B2 symptom
        #expect(taxMin.lifetimeTaxPV < fill.lifetimeTaxPV)             // PV agrees it minimizes
    }

    @Test("ApproachUILogic.displayedLifetimeTax always returns the PV figure, not nominal")
    func displayedLifetimeTaxUsesPV() {
        let fill = Self.fillToBracketColumn()
        let taxMin = Self.minimizeLifetimeTaxColumn()

        #expect(ApproachUILogic.displayedLifetimeTax(fill) == fill.lifetimeTaxPV)
        #expect(ApproachUILogic.displayedLifetimeTax(fill) != fill.lifetimeTaxNominal)
        #expect(ApproachUILogic.displayedLifetimeTax(taxMin) == taxMin.lifetimeTaxPV)

        // Ranking by the DISPLAYED metric now agrees with the PV ordering (minimize genuinely
        // ranks lowest on this fabricated fixture), not the nominal ordering used pre-fix.
        #expect(ApproachUILogic.displayedLifetimeTax(taxMin) < ApproachUILogic.displayedLifetimeTax(fill))
    }

    @Test("CPA briefing / on-screen headline delta uses PV lifetime tax, not nominal")
    func cpaBriefingDeltaUsesPV() {
        let fill = Self.fillToBracketColumn()
        let taxMin = Self.minimizeLifetimeTaxColumn()
        let cmp = ApproachComparison(
            selectedApproach: .fillToBracket(rate: 0.22),
            selected: fill,
            recommended: taxMin,
            noAdditionalConversions: fill,
            deltas: ConsequenceDeltas(selected: [], noConversion: []),
            flags: ConsequenceFlags(ssTaxationIncreased: false, irmaaTierCrossed: false,
                                    acaCliffCrossed: false, ordinaryBracketCrossed: false,
                                    capGainBracketAffected: false, niitIncreased: false))

        let s = MultiYearCPABriefing.approachDeltaSummary(cmp)
        #expect(s.deltaLifetimeTax == fill.lifetimeTaxPV - taxMin.lifetimeTaxPV)
        #expect(s.deltaLifetimeTax != fill.lifetimeTaxNominal - taxMin.lifetimeTaxNominal)
        // Selected (fill, PV $640k) genuinely costs MORE in present value than the anchor
        // (taxMin, PV $590k) on this fixture — the anchor really does minimize on PV, even though
        // it looked worse on nominal ($755k vs $718k) before this fix.
        #expect(s.deltaLifetimeTax > 0)
    }

    // MARK: - Full-engine fixture

    /// Runs the real coordinator on a large-balance household (standing in for the $20M Bob/Sue
    /// profile that surfaced B2) and confirms the DISPLAYED lifetime-tax figure for both the
    /// selected (fill-to-24%) and anchor (minimize-lifetime-tax) columns is the PV figure, not
    /// nominal. Does NOT assert which one ranks lower — see the suite-level note re: A5.
    @Test("Full-engine fixture: displayed lifetime tax for both approaches equals PV, not nominal")
    func fullEngineDisplayedMetricIsPV() {
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity(
            currentAge: 63,
            traditional: 6_000_000,
            taxable: 3_000_000,
            baselineExpenses: 150_000,
            ssClaimAge: 67,
            filingStatus: .marriedFilingJointly,
            state: "TX")
        let asmp = ApproachComparisonTests.makeAssumptions()

        let cmp = ApproachComparisonCoordinator().compare(
            inputs: inputs, assumptions: asmp,
            selectedApproach: .fillToBracket(rate: 0.24), heirWeight: 0)

        let displayedFill = ApproachUILogic.displayedLifetimeTax(cmp.selected)
        let displayedTaxMin = ApproachUILogic.displayedLifetimeTax(cmp.recommended)

        #expect(displayedFill == cmp.selected.lifetimeTaxPV)
        #expect(displayedTaxMin == cmp.recommended.lifetimeTaxPV)
        // Sanity: PV and nominal actually differ on this fixture (otherwise the assertions
        // above wouldn't distinguish the fix from the pre-fix behavior).
        #expect(cmp.selected.lifetimeTaxPV != cmp.selected.lifetimeTaxNominal)
        // NOT asserted here (out of this task's scope, see suite note re: A5): whether
        // displayedTaxMin <= displayedFill. On this fixture it happens to hold (recommendedTaxMin
        // ranks at/below fillToBracket even on PV) — checked manually while writing this test,
        // not asserted, since A5 (greedy optimizer suboptimality) could flip it on another
        // fixture without this task's fix being wrong.
    }
}
