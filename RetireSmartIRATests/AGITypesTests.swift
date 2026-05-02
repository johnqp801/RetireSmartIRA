//
//  AGITypesTests.swift
//  RetireSmartIRATests
//
//  Tests for FederalAGI / ACAMAGI / IRMAAMAGI strongly-typed wrappers.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("AGI Typed Wrappers")
struct AGITypesTests {

    @Test("FederalAGI wraps a Double value")
    func federalAGIStoresValue() {
        let agi = FederalAGI(value: 96_420)
        #expect(agi.value == 96_420)
    }

    @Test("ACAMAGI wraps a Double value")
    func acaMAGIStoresValue() {
        let magi = ACAMAGI(value: 84_200)
        #expect(magi.value == 84_200)
    }

    @Test("IRMAAMAGI wraps a Double value")
    func irmaaMAGIStoresValue() {
        let magi = IRMAAMAGI(value: 218_500)
        #expect(magi.value == 218_500)
    }

    @Test("AGI variants are not interchangeable types (compile-time only)")
    func agiVariantsAreDistinctTypes() {
        let federal = FederalAGI(value: 100_000)
        let aca = ACAMAGI(value: 100_000)
        let irmaa = IRMAAMAGI(value: 100_000)
        // Same numeric value, different types. Caller must explicitly extract `.value` to compare.
        #expect(federal.value == aca.value)
        #expect(aca.value == irmaa.value)
    }

    @Test("DataManager.federalAGI equals scenarioGrossIncome minus above-the-line deductions (zero today)")
    @MainActor
    func federalAGIComputedProperty() {
        let dm = DataManager(skipPersistence: true)
        // No income sources / scenario levers added → scenarioGrossIncome == 0.
        // No contribution levers exist yet (Phase 2) → totalAboveTheLineDeductions == 0.
        #expect(dm.federalAGI.value == dm.scenarioGrossIncome)
    }

    @Test("DataManager.acaMAGI = federalAGI + tax-exempt interest + non-taxable SS")
    @MainActor
    func acaMAGIComputedProperty() {
        let dm = DataManager(skipPersistence: true)
        // With no income, all three components are zero.
        #expect(dm.acaMAGI.value == dm.federalAGI.value
                + dm.taxExemptInterestTotal
                + (dm.totalSocialSecurityBenefits - dm.scenarioTaxableSocialSecurity))
    }

    @Test("DataManager.irmaaMAGIWrapped = federalAGI + tax-exempt interest")
    @MainActor
    func irmaaMAGIComputedProperty() {
        let dm = DataManager(skipPersistence: true)
        #expect(dm.irmaaMAGIWrapped.value == dm.federalAGI.value + dm.taxExemptInterestTotal)
    }

    @Test("irmaaMAGIWrapped.value matches existing untyped irmaaMagi (no behavior drift)")
    @MainActor
    func irmaaMAGIMatchesLegacyDouble() {
        let dm = DataManager(skipPersistence: true)
        #expect(dm.irmaaMAGIWrapped.value == dm.irmaaMagi)
    }
}
