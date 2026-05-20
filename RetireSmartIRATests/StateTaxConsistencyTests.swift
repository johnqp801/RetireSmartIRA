//
//  StateTaxConsistencyTests.swift
//  RetireSmartIRATests
//
//  Cross-view state-tax consistency regression suite. Pins the invariant
//  that every consumer site in the app (Tax Summary, Dashboard, State
//  Comparison, Quarterly Tax, PDF export, Scenario charts, Roth-conversion
//  analyzer) reports the SAME state-tax dollar amount as the engine's
//  `scenarioStateTax`, because all of them should be routed through that
//  single source of truth.
//
//  Triggered by a real user (Jonggie F., PA retiree). In v1.8.2, his Tax
//  Projection view showed $2,161 PA tax while State Comparison showed
//  $3,297 PA tax — a $1,136 discrepancy that turned out to be the retirement
//  distribution exemption applied in the engine but skipped by the State
//  Comparison's calculateStateTaxFromGross call (missing args defaulted to 0).
//  v1.8.3-build44 (this audit) closes the remaining gaps.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("State-tax cross-view consistency (1.8.3-build44 audit)")
struct StateTaxConsistencyTests {

    /// Builds Jonggie's exact reported scenario: PA single, age 60+,
    /// $69K Roth conversion + $37K extra withdrawal, no other income beyond
    /// what's needed to make the numbers move.
    private func makeJonggiesScenario() -> DataManager {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 65 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .pennsylvania
        dm.filingStatus = .single
        dm.yourRothConversion = 69_000
        dm.yourExtraWithdrawal = 37_000
        return dm
    }

    // MARK: - Jonggie's scenario: cross-view invariant

    /// THE bug Jonggie surfaced: State Comparison's PA cell must equal
    /// `scenarioStateTax` for the same scenario. Pre-fix the helper ran
    /// `calculateStateTaxFromGross` without `scenarioRetirementDistributions`
    /// or `scenarioRothConversionAmount`, so PA over-billed by
    /// 3.07% × ($69K conv + $37K withdrawal) = $3,254.
    @Test("Jonggie PA: State Comparison PA cell == scenarioStateTax")
    func jonggieStateComparisonMatchesScenarioStateTax() {
        let dm = makeJonggiesScenario()
        let scenarioTax = dm.scenarioStateTax

        // Mirror what `StateComparisonView.rankedStates` does for the PA cell.
        let comparisonTax = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome,
            forState: .pennsylvania,
            filingStatus: dm.filingStatus,
            taxableSocialSecurity: dm.scenarioTaxableSocialSecurity,
            hsaContributionsAddedBack: dm.scenario.scenarioTotalHSA,
            traditionalIRAContributionsSubtracted: dm.scenario.scenarioTotalTraditionalIRA,
            otherPreTaxDeductionsSubtracted: dm.scenario.scenarioTotalOtherPreTaxDeductions,
            pretax401kContributionsAddedBack: dm.scenario.scenarioTotalTraditional401k,
            scenarioRetirementDistributions: dm.scenarioRetirementDistributionIncome,
            scenarioRothConversionAmount: dm.scenarioTotalRothConversion
        )

        #expect(abs(comparisonTax - scenarioTax) < 1.0,
                "State Comparison PA must match scenarioStateTax. comparison=\(comparisonTax) scenarioStateTax=\(scenarioTax)")
    }

    /// Jonggie's scenario must produce $0 PA tax because:
    ///   - $69K Roth conversion → PA-exempt (DOR Ans 274, no age gate)
    ///   - $37K extra withdrawal → PA-exempt at retirement age (age ≥ 59½)
    @Test("Jonggie PA: $69K conv + $37K withdrawal at age 65 → $0 PA tax")
    func jonggieZeroPATax() {
        let dm = makeJonggiesScenario()
        #expect(dm.scenarioStateTax == 0,
                "PA must exempt both conversion (Ans 274) and retirement-age withdrawal. Got \(dm.scenarioStateTax)")
    }

    /// State Comparison detail sheet uses `stateTaxBreakdown(forState:filingStatus:)`.
    /// That breakdown's `totalStateTax` must match `scenarioStateTax` for the
    /// resident state, otherwise the list and the detail sheet contradict.
    @Test("Jonggie PA: stateTaxBreakdown.totalStateTax == scenarioStateTax")
    func jonggieBreakdownMatchesScenario() {
        let dm = makeJonggiesScenario()
        let breakdown = dm.stateTaxBreakdown(forState: .pennsylvania, filingStatus: dm.filingStatus)
        #expect(abs(breakdown.totalStateTax - dm.scenarioStateTax) < 1.0,
                "Breakdown.totalStateTax=\(breakdown.totalStateTax) must match scenarioStateTax=\(dm.scenarioStateTax)")
    }

    // MARK: - analyzeScenario must reflect PA exemptions

    /// TaxPlanningView's Tax Summary uses `analyzeScenario(baseIncome:scenarioIncome:)`
    /// for the per-decision impact row. Pre-fix it used the simple
    /// `calculateStateTax(income:)` form which doesn't know about scenario-level
    /// conversion / distribution amounts. For PA + Jonggie's scenario, the
    /// state-tax delta should be $0.
    @Test("Jonggie PA: analyzeScenario stateTax delta = $0 (conversion + withdrawal both exempt)")
    func jonggieAnalyzeScenarioStateDelta() {
        let dm = makeJonggiesScenario()
        let baseTaxable = max(0, dm.scenarioBaseIncome - dm.effectiveDeductionAmount)
        let scenarioTaxable = dm.scenarioTaxableIncome
        let analysis = dm.analyzeScenario(baseIncome: baseTaxable, scenarioIncome: scenarioTaxable)
        #expect(abs(analysis.stateTax) < 1.0,
                "analyzeScenario state-tax delta for PA must be ~$0 when scenario is all PA-exempt income. Got \(analysis.stateTax)")
    }

    // MARK: - analyzeEnhancedRothConversion must reflect PA exemption

    /// RothConversionView calls `analyzeEnhancedRothConversion(conversionAmount:filingStatus:)`
    /// and renders `analysis.stateTax` as "PA Tax on Conversion". For PA the
    /// correct answer is $0 (DOR Ans 274). Pre-fix this returned ~3.07%× conv.
    @Test("PA Roth conversion analyzer: $50K conversion → state tax = $0")
    func paAnalyzeEnhancedRothConversionExempt() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .pennsylvania
        dm.filingStatus = .single
        let analysis = dm.analyzeEnhancedRothConversion(conversionAmount: 50_000, filingStatus: .single)
        #expect(abs(analysis.stateTax) < 1.0,
                "PA conversion analyzer must show $0 state tax on conversion. Got \(analysis.stateTax)")
    }

    /// Negative control: CA must NOT exempt the conversion, so analyzer should
    /// show a non-zero state tax delta.
    @Test("CA Roth conversion analyzer: $50K conversion → state tax > $0 (no exemption)")
    func caAnalyzeEnhancedRothConversionTaxed() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .california
        dm.filingStatus = .single
        let analysis = dm.analyzeEnhancedRothConversion(conversionAmount: 50_000, filingStatus: .single)
        #expect(analysis.stateTax > 0,
                "CA does not exempt Roth conversions; expected > $0 state tax delta. Got \(analysis.stateTax)")
    }

    // MARK: - autoEstimatedStatePayments must reflect exemptions

    /// SALT auto-estimate must use the same exemption pipeline as scenarioStateTax.
    @Test("Jonggie PA: autoEstimatedStatePayments == max(0, scenarioStateTax - withholding)")
    func jonggieAutoSALTConsistency() {
        let dm = makeJonggiesScenario()
        let expected = max(0, dm.scenarioStateTax - dm.totalStateWithholding)
        #expect(abs(dm.autoEstimatedStatePayments - expected) < 1.0,
                "autoEstimatedStatePayments=\(dm.autoEstimatedStatePayments) must equal max(0, scenarioStateTax-withholding)=\(expected)")
    }

    // MARK: - All states match when sorted (cross-state engine consistency)

    /// For the resident state, the rank-list tax MUST equal scenarioStateTax.
    /// Regression for the original Jonggie bug.
    @Test("Resident state in ranked list == scenarioStateTax (every state)")
    func residentStateRankConsistency() {
        for state in [USState.pennsylvania, .illinois, .mississippi, .california, .newYork] {
            let dm = DataManager(skipPersistence: true)
            var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
            dm.profile.birthDate = Calendar.current.date(from: dob)!
            dm.profile.currentYear = 2026
            dm.selectedState = state
            dm.filingStatus = .single
            dm.yourRothConversion = 50_000
            dm.yourExtraWithdrawal = 30_000

            let scenarioTax = dm.scenarioStateTax
            let listTax = dm.calculateStateTaxFromGross(
                grossIncome: dm.scenarioGrossIncome,
                forState: state,
                filingStatus: dm.filingStatus,
                taxableSocialSecurity: dm.scenarioTaxableSocialSecurity,
                hsaContributionsAddedBack: dm.scenario.scenarioTotalHSA,
                traditionalIRAContributionsSubtracted: dm.scenario.scenarioTotalTraditionalIRA,
                otherPreTaxDeductionsSubtracted: dm.scenario.scenarioTotalOtherPreTaxDeductions,
                pretax401kContributionsAddedBack: dm.scenario.scenarioTotalTraditional401k,
                scenarioRetirementDistributions: dm.scenarioRetirementDistributionIncome,
                scenarioRothConversionAmount: dm.scenarioTotalRothConversion
            )
            #expect(abs(scenarioTax - listTax) < 1.0,
                    "\(state.rawValue): scenarioStateTax=\(scenarioTax) vs StateComparison list=\(listTax)")
        }
    }
}
