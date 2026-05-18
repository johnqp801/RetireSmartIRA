//
//  BaselineACAMagiTests.swift
//  RetireSmartIRATests
//
//  Verifies `baselineACAMagi` returns the pre-scenario ACA MAGI, excluding
//  Roth conversions and extra withdrawals. The baseline value enables the
//  ACA Subsidy Bar in TaxPlanningView to render the dashed before-marker
//  alongside the solid after-marker. (C3 from 1.8.2 Phase 3)
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Baseline ACA MAGI — scenario adjustment exclusion", .serialized)
@MainActor
struct BaselineACAMagiTests {

    @Test("Baseline ACA MAGI excludes Roth conversion")
    func baselineExcludesRothConversion() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]

        // Record baseline MAGI before adding scenario conversion
        let baselineBeforeConversion = dm.baselineACAMagi.value

        // Add Roth conversion scenario
        dm.yourRothConversion = 40_000

        // Baseline should remain unchanged
        let baselineAfterConversion = dm.baselineACAMagi.value
        #expect(baselineBeforeConversion == baselineAfterConversion)

        // But scenario MAGI should increase
        let scenarioMAGI = dm.acaMAGI.value
        #expect(scenarioMAGI > baselineAfterConversion)

        // Delta should equal the conversion amount
        #expect(abs((scenarioMAGI - baselineAfterConversion) - 40_000) < 1)
    }

    @Test("Baseline ACA MAGI excludes extra withdrawal")
    func baselineExcludesExtraWithdrawal() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 100_000, owner: .primary)
        ]

        let baselineBeforeExtra = dm.baselineACAMagi.value

        // Add extra withdrawal
        dm.yourExtraWithdrawal = 15_000

        let baselineAfterExtra = dm.baselineACAMagi.value
        #expect(baselineBeforeExtra == baselineAfterExtra)

        let scenarioMAGI = dm.acaMAGI.value
        #expect(scenarioMAGI > baselineAfterExtra)
    }

    @Test("Baseline ACA MAGI includes tax-exempt interest")
    func baselineIncludesTaxExemptInterest() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000),
            IncomeSource(name: "Municipal Bonds", type: .taxExemptInterest, annualAmount: 2_000)
        ]

        let baseline = dm.baselineACAMagi.value

        // Baseline should include both pension and tax-exempt interest
        #expect(abs(baseline - 52_000) < 1)
    }

    @Test("Baseline ACA MAGI includes non-taxable Social Security")
    func baselineIncludesNonTaxableSS() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000),
            IncomeSource(name: "Social Security", type: .socialSecurity, annualAmount: 10_000)
        ]

        // The first portion of SS may not be taxable; baseline should still include it for ACA purposes
        let baseline = dm.baselineACAMagi.value
        let scenario = dm.acaMAGI.value

        // They should both be at least pension + full SS (including non-taxable portion)
        #expect(baseline >= 60_000)
        #expect(scenario >= 60_000)
    }

    @Test("Baseline ACA MAGI is zero with no income")
    func baselineIsZeroWithNoIncome() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026

        let baseline = dm.baselineACAMagi.value
        #expect(abs(baseline) < 0.01)
    }

    @Test("Baseline ACA MAGI remains unchanged when scenario is modified but then reset")
    func baselineStableAcrossScenarioToggle() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 75_000)
        ]

        let originalBaseline = dm.baselineACAMagi.value

        // Add Roth conversion
        dm.yourRothConversion = 50_000
        let baselineWithConversion = dm.baselineACAMagi.value

        // Remove Roth conversion
        dm.yourRothConversion = 0
        let baselineAfterReset = dm.baselineACAMagi.value

        #expect(originalBaseline == baselineWithConversion)
        #expect(originalBaseline == baselineAfterReset)
    }

    @Test("Baseline delta from scenario equals Roth conversion amount")
    func baselineDeltaEqualsConversionAmount() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 70_000)
        ]

        let conversionAmount = 30_000.0

        dm.yourRothConversion = conversionAmount

        let baseline = dm.baselineACAMagi.value
        let scenario = dm.acaMAGI.value
        let delta = scenario - baseline

        // Delta should equal the conversion amount
        #expect(abs(delta - conversionAmount) < 1)
    }
}
