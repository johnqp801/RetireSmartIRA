//
//  TaxCalculationEngineMilitaryRetirementTests.swift
//  RetireSmartIRATests
//
//  Verifies that Military Retirement income is:
//   - Federally taxable as ordinary income (treated like .pension).
//   - Exempt from state tax in fully-exempt states (NC, PA, TX, etc.).
//   - Fully taxable in non-exempt states (CA).
//   - Iowa age-conditional (under 55 taxable; 55+ fully exempt).
//
//  Wires `MilitaryRetirementExemption` into the state-tax engine path
//  via `TaxCalculationEngine.applyRetirementExemptions`.
//

import XCTest
@testable import RetireSmartIRA

@MainActor
final class TaxCalculationEngineMilitaryRetirementTests: XCTestCase {

    // MARK: - Helper

    /// Build a minimal DataManager with a single Military Retirement income source.
    private func makeManager(
        state: USState,
        militaryRetirement: Double,
        age: Int = 65
    ) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.profile.selectedState = state
        // Set primary birthDate so currentAge = age (currentYear - birthYear).
        let birthYear = dm.profile.currentYear - age
        var c = DateComponents(); c.year = birthYear; c.month = 1; c.day = 1
        dm.profile.birthDate = Calendar.current.date(from: c)!

        dm.incomeDeductions.incomeSources = [
            IncomeSource(
                name: "Military Retirement",
                type: .militaryRetirement,
                annualAmount: militaryRetirement,
                owner: .primary
            )
        ]
        return dm
    }

    // MARK: - Direct exemption helper sanity (re-confirms Task 6.2 wiring)

    func testExemption_NorthCarolina_FullyExempt() {
        XCTAssertEqual(
            MilitaryRetirementExemption.stateTaxableAmount(gross: 50_000, stateCode: "NC", age: 65),
            0
        )
    }

    func testExemption_California_FullyTaxable() {
        XCTAssertEqual(
            MilitaryRetirementExemption.stateTaxableAmount(gross: 50_000, stateCode: "CA", age: 65),
            50_000
        )
    }

    func testExemption_Texas_NoStateIncomeTax() {
        XCTAssertEqual(
            MilitaryRetirementExemption.stateTaxableAmount(gross: 50_000, stateCode: "TX", age: 65),
            0
        )
    }

    func testExemption_Iowa_AgeConditional() {
        XCTAssertEqual(
            MilitaryRetirementExemption.stateTaxableAmount(gross: 50_000, stateCode: "IA", age: 50),
            50_000,
            "Iowa under 55: military retirement fully taxable"
        )
        XCTAssertEqual(
            MilitaryRetirementExemption.stateTaxableAmount(gross: 50_000, stateCode: "IA", age: 60),
            0,
            "Iowa 55+: military retirement fully exempt"
        )
    }

    // MARK: - Engine integration: state-tax path

    /// North Carolina fully exempts military retirement → state tax should be zero
    /// even though federal AGI includes the $50K.
    func testEngine_NorthCarolina_MilitaryRetirementExemptFromStateTax() {
        let dm = makeManager(state: .northCarolina, militaryRetirement: 50_000)

        // applyRetirementExemptions should subtract the full $50K of military
        // retirement from the state-taxable income aggregate.
        let config = StateTaxData.config(for: .northCarolina)
        let income = 50_000.0  // post-deduction state taxable income
        let adjusted = TaxCalculationEngine.applyRetirementExemptions(
            income: income,
            config: config,
            state: .northCarolina,
            taxableSocialSecurity: 0,
            incomeSources: dm.incomeDeductions.incomeSources,
            primaryAge: 65,
            spouseAge: 0,
            enableSpouse: false
        )
        XCTAssertEqual(
            adjusted, 0,
            "NC fully exempts military retirement → adjusted state-taxable income should be 0"
        )

        // The state tax itself should also be 0 (NC is flat-rate progressive).
        let stateTax = TaxCalculationEngine.calculateStateTax(
            income: income,
            forState: .northCarolina,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            incomeSources: dm.incomeDeductions.incomeSources,
            currentAge: 65,
            enableSpouse: false,
            spouseBirthYear: 1960,
            currentYear: dm.profile.currentYear
        )
        XCTAssertEqual(stateTax, 0, "NC military-retirement-only → $0 state tax, got \(stateTax)")
    }

    /// California does NOT exempt military retirement → state tax should match
    /// what $50K of any other ordinary income would generate.
    func testEngine_California_MilitaryRetirementTaxedAtState() {
        let dm = makeManager(state: .california, militaryRetirement: 50_000)
        let config = StateTaxData.config(for: .california)
        let income = 50_000.0

        let adjusted = TaxCalculationEngine.applyRetirementExemptions(
            income: income,
            config: config,
            state: .california,
            taxableSocialSecurity: 0,
            incomeSources: dm.incomeDeductions.incomeSources,
            primaryAge: 65,
            spouseAge: 0,
            enableSpouse: false
        )
        XCTAssertEqual(
            adjusted, 50_000,
            "CA does not exempt military retirement → adjusted income unchanged"
        )

        let stateTax = TaxCalculationEngine.calculateStateTax(
            income: income,
            forState: .california,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            incomeSources: dm.incomeDeductions.incomeSources,
            currentAge: 65,
            enableSpouse: false,
            spouseBirthYear: 1960,
            currentYear: dm.profile.currentYear
        )
        XCTAssertGreaterThan(
            stateTax, 0,
            "CA must tax military retirement; got \(stateTax)"
        )
    }

    /// Texas has no state income tax — should always be zero regardless.
    func testEngine_Texas_NoStateIncomeTax() {
        let dm = makeManager(state: .texas, militaryRetirement: 50_000)
        let stateTax = TaxCalculationEngine.calculateStateTax(
            income: 50_000,
            forState: .texas,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            incomeSources: dm.incomeDeductions.incomeSources,
            currentAge: 65,
            enableSpouse: false,
            spouseBirthYear: 1960,
            currentYear: dm.profile.currentYear
        )
        XCTAssertEqual(stateTax, 0)
    }

    /// Iowa under 55: military retirement fully taxable.
    func testEngine_Iowa_Under55_MilitaryRetirementTaxedAtState() {
        let dm = makeManager(state: .iowa, militaryRetirement: 50_000, age: 50)
        let config = StateTaxData.config(for: .iowa)
        let adjusted = TaxCalculationEngine.applyRetirementExemptions(
            income: 50_000,
            config: config,
            state: .iowa,
            taxableSocialSecurity: 0,
            incomeSources: dm.incomeDeductions.incomeSources,
            primaryAge: 50,
            spouseAge: 0,
            enableSpouse: false
        )
        XCTAssertEqual(adjusted, 50_000, "Iowa under 55: military retirement fully taxable")
    }

    /// Iowa 55+: military retirement fully exempt.
    func testEngine_Iowa_Age55Plus_MilitaryRetirementExemptFromStateTax() {
        let dm = makeManager(state: .iowa, militaryRetirement: 50_000, age: 60)
        let config = StateTaxData.config(for: .iowa)
        let adjusted = TaxCalculationEngine.applyRetirementExemptions(
            income: 50_000,
            config: config,
            state: .iowa,
            taxableSocialSecurity: 0,
            incomeSources: dm.incomeDeductions.incomeSources,
            primaryAge: 60,
            spouseAge: 0,
            enableSpouse: false
        )
        XCTAssertEqual(adjusted, 0, "Iowa 55+: military retirement fully exempt")
    }

    // MARK: - Federal side: military retirement remains ordinary income

    func testFederal_MilitaryRetirement_IncludedInOrdinaryIncome() {
        let dm = makeManager(state: .northCarolina, militaryRetirement: 50_000)
        // ordinaryIncomeSubtotal aggregates all non-(SS/capgains/qualdiv/taxexempt/VA)
        // income sources. .militaryRetirement is none of those → should be included.
        XCTAssertEqual(
            dm.incomeDeductions.ordinaryIncomeSubtotal, 50_000,
            "Military retirement must be included in federal ordinary income subtotal"
        )
    }

    /// Spouse-owned military retirement uses spouse's age for the Iowa age check.
    func testEngine_SpouseOwned_UsesSpouseAge() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.selectedState = .iowa
        dm.profile.enableSpouse = true
        // Primary age 50 (under 55), spouse age 60 (55+)
        var pc = DateComponents(); pc.year = dm.profile.currentYear - 50; pc.month = 1; pc.day = 1
        dm.profile.birthDate = Calendar.current.date(from: pc)!
        var sc = DateComponents(); sc.year = dm.profile.currentYear - 60; sc.month = 1; sc.day = 1
        dm.profile.spouseBirthDate = Calendar.current.date(from: sc)!

        dm.incomeDeductions.incomeSources = [
            IncomeSource(
                name: "Spouse Military Retirement",
                type: .militaryRetirement,
                annualAmount: 40_000,
                owner: .spouse
            )
        ]

        let config = StateTaxData.config(for: .iowa)
        let adjusted = TaxCalculationEngine.applyRetirementExemptions(
            income: 40_000,
            config: config,
            state: .iowa,
            taxableSocialSecurity: 0,
            incomeSources: dm.incomeDeductions.incomeSources,
            primaryAge: 50,
            spouseAge: 60,
            enableSpouse: true
        )
        XCTAssertEqual(
            adjusted, 0,
            "Iowa: spouse-owned military retirement should use spouse's age (60 → exempt)"
        )
    }
}
