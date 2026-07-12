//
//  MultiYearItemizedParityTests.swift
//  RetireSmartIRATests
//
//  V2.1.1 Task 7: parity guard between the pure multi-year itemized-deduction
//  helper (`MultiYearItemizedDeduction`, Task 3) and the single-year DataManager
//  itemized computation. Asserts they agree on identical inputs so the helper
//  can't silently drift from the single-year reference as either side evolves.
//
//  Setup notes (see MultiYearItemizedDeduction.swift header for the full mirror
//  list this guards):
//    - Texas (no state income tax) avoids the CA SALT-itemize confound where
//      state income tax would flow into SALT differently on the two sides.
//    - stockDonationEnabled stays false: the helper is cash-charitable-only, so
//      the single-year 30% LT-stock bucket must be off or the two sides diverge
//      by construction.
//    - No above-the-line deductions (pension income only) so `federalAGI.value`
//      equals `scenarioGrossIncome`, matching the AGI the single-year itemized
//      vars (charitableAGIFloor, ceilingLimitedCharitable at DataManager.swift
//      :1863/:1873) actually compute against.
//    - `deductionOverride = .itemized` forces `scenarioEffectiveItemize`, which
//      gates `itemizedOverallLimitationReduction` (guard at DataManager.swift
//      :1939) — without it the §68 reduction is always 0 regardless of income,
//      which would make the "effective itemized" comparison meaningless at the
//      high-income case.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Multi-Year Itemized Helper vs Single-Year DataManager Parity", .serialized)
@MainActor
struct MultiYearItemizedParityTests {

    private func makeDM(income: Double) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.filingStatus = .single
        dm.selectedState = .texas            // no state income tax → SALT core = property tax only
        dm.stockDonationEnabled = false       // cash-only, matches the helper's scope
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: income)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 8_000),
            DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 6_000),
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 6_000)
        ]
        dm.cashDonationAmount = 20_000
        dm.deductionOverride = .itemized     // force itemizing so §68 isn't gated off
        return dm
    }

    /// Runs both sides for a given DataManager and returns (helper, singleYear) so callers
    /// can assert parity with `#expect` at their own call site (for a useful failure line).
    private func computeBothSides(_ dm: DataManager) -> (helper: Double, singleYear: Double) {
        let agi = dm.federalAGI.value
        let helperItemized = MultiYearItemizedDeduction.itemizedTotal(
            stateIncomeTax: 0,                          // TX: no state income tax
            otherSALT: dm.propertyTaxAmount,             // property tax only (no manual SALT items)
            mortgageAndOther: 8_000,                     // the Mortgage item (non-SALT, non-medical)
            grossMedical: dm.totalMedicalExpenses,
            cashCharitable: dm.cashDonationAmount,
            seniorBonus: dm.seniorBonusDeductionAmount,
            agi: agi,
            filingStatus: dm.filingStatus,
            year: dm.currentYear,
            config: TaxYearConfig.loadOrFallback(forYear: dm.currentYear)
        )
        // Single-year "effective itemized" (after §68) per the task brief.
        let singleYear = dm.totalItemizedDeductions - dm.itemizedOverallLimitationReduction
        return (helperItemized, singleYear)
    }

    @Test("Moderate income: agrees, §68 does not engage")
    func parityBelowThreshold() {
        let dm = makeDM(income: 150_000) // single, well under the $640,600 (2026) 37%-bracket threshold
        #expect(dm.itemizedOverallLimitationReduction == 0)
        // Senior bonus should be live and non-trivial (default profile birth year 1953 → age 73
        // in 2026; single phaseout threshold is $75,000, so a $150,000 MAGI partially phases it).
        #expect(dm.seniorBonusDeductionAmount > 0)
        let (helper, singleYear) = computeBothSides(dm)
        #expect(abs(helper - singleYear) < 0.01)
    }

    @Test("High income: agrees, §68 engages")
    func parityAboveThreshold() {
        let dm = makeDM(income: 900_000) // single, above the $640,600 (2026) 37%-bracket threshold
        #expect(dm.itemizedOverallLimitationReduction > 0)
        let (helper, singleYear) = computeBothSides(dm)
        #expect(abs(helper - singleYear) < 0.01)
    }
}
