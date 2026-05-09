//
//  TimScenarioIntegrationTests.swift
//  RetireSmartIRATests
//
//  End-to-end integration tests for Tim's retired-military scenario (V1.8.1).
//
//  Tim's complaint (beta feedback):
//   "because it doesn't calculate the state tax exemption for mil retirement
//    or the federal and state exemption from VA disability the APP gives me
//    very inflated estimated tax amounts."
//
//  These tests verify the fix is complete: Military Retirement is federally
//  taxable but state-exempt in states like NC; VA Disability is universally
//  excluded from federal AGI, MAGI, and state taxable income.
//
//  Spec ref: docs/superpowers/specs/2026-05-09-1.8.1-incremental-design.md Item #18.
//

import XCTest
import Foundation
@testable import RetireSmartIRA

@MainActor
final class TimScenarioIntegrationTests: XCTestCase {

    // MARK: - Setup helpers

    /// Builds a DataManager simulating Tim's profile: retired military veteran
    /// receiving both military retirement pay and VA disability compensation.
    private func makeTimProfile(
        state: USState,
        militaryRetirement: Double = 50_000,
        vaDisability: Double = 30_000,
        primaryAge: Int = 65
    ) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.profile.selectedState = state

        // Set birth date so computed age == primaryAge
        let birthYear = dm.profile.currentYear - primaryAge
        var c = DateComponents()
        c.year = birthYear; c.month = 1; c.day = 1
        dm.profile.birthDate = Calendar.current.date(from: c)!
        dm.profile.filingStatus = .single

        dm.incomeDeductions.incomeSources = [
            IncomeSource(
                name: "Military Retirement",
                type: .militaryRetirement,
                annualAmount: militaryRetirement,
                owner: .primary
            ),
            IncomeSource(
                name: "VA Disability",
                type: .vaDisability,
                annualAmount: vaDisability,
                owner: .primary
            )
        ]
        return dm
    }

    // MARK: - Federal AGI verification

    func testFederalAGI_IncludesMilitaryRetirement_ExcludesVADisability() {
        let dm = makeTimProfile(state: .northCarolina)

        let agi = dm.federalAGI.value
        // Should include $50K military retirement but NOT $30K VA disability
        XCTAssertEqual(agi, 50_000, accuracy: 0.01,
            "Federal AGI: military retirement included (50K), VA disability excluded; expected 50K, got \(agi)")
    }

    // MARK: - State tax — North Carolina (fully exempts both)

    func testNorthCarolina_BothExempt_ZeroStateTax() {
        let dm = makeTimProfile(state: .northCarolina, militaryRetirement: 50_000, vaDisability: 30_000)

        // NC fully exempts military retirement AND VA disability is universally excluded,
        // so state tax on these two sources should be zero.
        let stateTax = dm.scenarioStateTax
        XCTAssertEqual(stateTax, 0, accuracy: 1.00,
            "NC state tax should be zero with only military retirement + VA disability income; got \(stateTax)")
    }

    // MARK: - State tax — California (taxes military, exempts VA)

    func testCalifornia_MilitaryTaxed_VAExempt() {
        let dm = makeTimProfile(state: .california, militaryRetirement: 50_000, vaDisability: 30_000)

        // CA fully taxes military retirement but VA disability is universally excluded.
        // State tax should be > 0 (from the military retirement).
        let stateTax = dm.scenarioStateTax
        XCTAssertGreaterThan(stateTax, 0, "CA should tax military retirement; got \(stateTax)")

        // The engine's exemption helper should confirm CA keeps the full military amount.
        let stateTaxable = MilitaryRetirementExemption.stateTaxableAmount(
            gross: 50_000, stateCode: "CA", age: 65
        )
        XCTAssertEqual(stateTaxable, 50_000, "CA fully taxes military retirement portion")
    }

    // MARK: - State tax — Texas (no state income tax)

    func testTexas_NoStateIncomeTax_ZeroFromAnySource() {
        let dm = makeTimProfile(state: .texas, militaryRetirement: 50_000, vaDisability: 30_000)

        let stateTax = dm.scenarioStateTax
        XCTAssertEqual(stateTax, 0, accuracy: 0.01,
            "TX has no state income tax — state tax should be zero; got \(stateTax)")
    }

    // MARK: - The "before vs after" inflated-estimate scenario

    /// Demonstrates the V1.8.1 fix: with both income types correctly excluded/exempted,
    /// Tim's effective state tax is significantly lower than if both were treated as ordinary income.
    func testTimScenario_InflatedEstimateDrops_NorthCarolina() {
        let correctDM = makeTimProfile(state: .northCarolina, militaryRetirement: 50_000, vaDisability: 30_000)
        let correctStateTax = correctDM.scenarioStateTax

        // Build the "before fix" scenario: pretend both were ordinary pension income
        let inflatedDM = DataManager(skipPersistence: true)
        inflatedDM.profile.selectedState = .northCarolina
        let birthYear = inflatedDM.profile.currentYear - 65
        var c = DateComponents()
        c.year = birthYear; c.month = 1; c.day = 1
        inflatedDM.profile.birthDate = Calendar.current.date(from: c)!
        inflatedDM.profile.filingStatus = .single
        inflatedDM.incomeDeductions.incomeSources = [
            IncomeSource(name: "Pension 1", type: .pension, annualAmount: 50_000, owner: .primary),
            IncomeSource(name: "Pension 2", type: .pension, annualAmount: 30_000, owner: .primary),
        ]
        let inflatedStateTax = inflatedDM.scenarioStateTax

        XCTAssertLessThan(correctStateTax, inflatedStateTax,
            "Tim's correct state tax (\(correctStateTax)) must be LESS than the inflated estimate (\(inflatedStateTax))")
    }

    // MARK: - Federal taxable income verification

    func testFederalOrdinaryIncome_OnlyMilitaryRetirement() {
        let dm = makeTimProfile(state: .northCarolina, militaryRetirement: 50_000, vaDisability: 30_000)
        let ordinary = dm.incomeDeductions.ordinaryIncomeSubtotal

        XCTAssertEqual(ordinary, 50_000, accuracy: 0.01,
            "Ordinary income should equal military retirement only (VA disability excluded); got \(ordinary)")
    }

    // MARK: - MAGI checks (ACA / IRMAA)

    func testIRMAAMagi_ExcludesVADisability() {
        let dm = makeTimProfile(state: .northCarolina, militaryRetirement: 50_000, vaDisability: 30_000)
        let irmaaMagi = dm.irmaaMAGIWrapped.value

        XCTAssertEqual(irmaaMagi, 50_000, accuracy: 1.00,
            "IRMAA MAGI must exclude VA disability; expected 50K (military only), got \(irmaaMagi)")
    }

    func testACAMagi_ExcludesVADisability() {
        let dm = makeTimProfile(state: .northCarolina, militaryRetirement: 50_000, vaDisability: 30_000)
        let acaMagi = dm.acaMAGI.value

        XCTAssertEqual(acaMagi, 50_000, accuracy: 1.00,
            "ACA MAGI must exclude VA disability; expected 50K (military only), got \(acaMagi)")
    }

    // MARK: - Iowa age-conditional (military exempt at 55+)

    func testIowa_AgeConditional_BelowThreshold_MilitaryTaxed() {
        let dm = makeTimProfile(state: .iowa, militaryRetirement: 50_000, vaDisability: 30_000, primaryAge: 50)

        // IA below age 55: military fully taxable; VA still excluded from federal AGI
        let stateTaxable = MilitaryRetirementExemption.stateTaxableAmount(
            gross: 50_000, stateCode: "IA", age: 50
        )
        XCTAssertEqual(stateTaxable, 50_000,
            "Iowa under 55: military retirement should be fully taxable")

        // VA disability still excluded regardless of age
        let agi = dm.federalAGI.value
        XCTAssertEqual(agi, 50_000, accuracy: 0.01,
            "VA disability excluded from federal AGI even at IA age 50")
    }

    func testIowa_AgeConditional_AboveThreshold_BothExempt() {
        let dm = makeTimProfile(state: .iowa, militaryRetirement: 50_000, vaDisability: 30_000, primaryAge: 60)

        // IA age 55+: military fully exempt from state tax
        let stateTaxable = MilitaryRetirementExemption.stateTaxableAmount(
            gross: 50_000, stateCode: "IA", age: 60
        )
        XCTAssertEqual(stateTaxable, 0,
            "Iowa 55+: military retirement should be fully exempt from state tax")

        // State tax should be zero: military exempt by IA age rule, VA universally excluded
        let stateTax = dm.scenarioStateTax
        XCTAssertEqual(stateTax, 0, accuracy: 1.00,
            "Iowa 55+ with only military retirement + VA disability: expected $0 state tax, got \(stateTax)")
    }
}
