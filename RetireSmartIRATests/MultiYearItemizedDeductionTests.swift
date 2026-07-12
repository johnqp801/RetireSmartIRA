//
//  MultiYearItemizedDeductionTests.swift
//  RetireSmartIRATests
//
//  Task 3 (V2.1.1 multi-year cash-charitable itemizing): pure-logic tests for
//  MultiYearItemizedDeduction, the dependency-free replica of the single-year
//  itemized-deduction rules used by the multi-year ProjectionEngine.
//
//  Config accessor: TaxYearConfig.loadOrFallback(forYear:) is the real accessor
//  (confirmed via grep; there is no static TaxYearConfig.config(forYear:)).
//  TaxYearConfigProvider wraps this for the engine, but the helper itself takes
//  a plain TaxYearConfig, matching the sibling engine tests' convention, e.g.
//  `TaxYearConfig.loadOrFallback(forYear: 2026)` in EngineRoadmapBatchTests.swift.
//
import Testing
@testable import RetireSmartIRA

private var cfg2026: TaxYearConfig { TaxYearConfig.loadOrFallback(forYear: 2026) }

@Test func medicalFloorAppliedAtSevenPointFivePercent() {
    // gross 20k, AGI 100k -> floor 7.5k -> deductible 12.5k
    #expect(MultiYearItemizedDeduction.deductibleMedical(gross: 20_000, agi: 100_000, config: cfg2026) == 12_500)
    #expect(MultiYearItemizedDeduction.deductibleMedical(gross: 5_000, agi: 100_000, config: cfg2026) == 0)
}

@Test func charitableCashCeilingAndHalfPercentFloor() {
    // AGI 100k: 60% ceiling = 60k; 0.5% floor = 500. cash 10k -> min(10k,60k)-500 = 9_500
    #expect(MultiYearItemizedDeduction.deductibleCharitableCash(cash: 10_000, agi: 100_000, year: 2026, config: cfg2026) == 9_500)
    // cash above 60% ceiling: cash 80k, AGI 100k -> 60k - 500 = 59_500
    #expect(MultiYearItemizedDeduction.deductibleCharitableCash(cash: 80_000, agi: 100_000, year: 2026, config: cfg2026) == 59_500)
}

@Test func nonItemizerCapByFilingStatus() {
    #expect(MultiYearItemizedDeduction.nonItemizerCashCharitable(cash: 5_000, filingStatus: .single, year: 2026, config: cfg2026) == 1_000)
    #expect(MultiYearItemizedDeduction.nonItemizerCashCharitable(cash: 5_000, filingStatus: .marriedFilingJointly, year: 2026, config: cfg2026) == 2_000)
    #expect(MultiYearItemizedDeduction.nonItemizerCashCharitable(cash: 500, filingStatus: .single, year: 2026, config: cfg2026) == 500)
}

@Test func itemizedTotalSumsComponentsBelowSixtyEightThreshold() {
    // Low AGI so §68 does not bite. SALT 12k(state)+0 other, cap high; mortgage 8k; no medical;
    // charitable cash 10k (AGI 100k -> 9_500); senior bonus 0.
    let total = MultiYearItemizedDeduction.itemizedTotal(
        stateIncomeTax: 12_000, otherSALT: 0, mortgageAndOther: 8_000,
        grossMedical: 0, cashCharitable: 10_000, seniorBonus: 0,
        agi: 100_000, filingStatus: .single, year: 2026, config: cfg2026)
    // salt = min(12_000, saltCap) — 2026 expanded cap = (40_000 * 1.01).rounded() = 40_400, so 12_000.
    // total = 12_000 + 8_000 + 9_500 = 29_500
    #expect(total == 29_500)
}
