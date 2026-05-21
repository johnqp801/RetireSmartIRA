//
//  RothConversionWithholdingTests.swift
//  RetireSmartIRATests
//
//  v1.8.4 regression suite for the Roth conversion withholding feature
//  (Jonggie Issue 2). Pins:
//
//  - `.paidFromOutside` (default) produces a withholding amount of $0 and
//    leaves all state-tax calculations identical to pre-1.8.4 behavior.
//  - `.withheldFromConversion` at rate R on gross conversion G yields
//    withholding = G × R and net Roth deposit = G − G × R.
//  - PA Ans 274 partially unwinds in withhold mode: the withheld portion
//    is PA-taxable as a distribution; only the net portion qualifies for
//    the PA exemption.
//  - IL and MS keep full Roth-conversion exemption regardless of
//    withholding (their guidance does not impose PA's "full balance"
//    requirement).
//  - The household-level setting applies to combined yourRothConversion +
//    spouseRothConversion when both are non-zero.
//
//  Primary sources:
//    - PA DOR Answer ID 274 ("Roth conversion not taxable in PA in the
//      conversion year if the full pre-tax balance is deposited into the
//      Roth; any amount withheld for federal tax IS PA-taxable as
//      distribution.")
//    - IL Publication 120
//    - MS Code § 27-7-15(4)(j)
//

import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("Roth Conversion Withholding (v1.8.4, Jonggie Issue 2)")
struct RothConversionWithholdingTests {

    /// Helper: build a baseline PA retiree with a $50K Roth conversion.
    private func makePAConversionScenario(
        mode: RothConversionWithholdingMode = .paidFromOutside,
        rate: Double = 0.24
    ) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!  // age 65 in 2026
        dm.profile.currentYear = 2026
        dm.selectedState = .pennsylvania
        dm.filingStatus = .single
        dm.yourRothConversion = 50_000
        dm.rothConversionWithholdingMode = mode
        dm.rothConversionFederalWithholdingRate = rate
        return dm
    }

    // MARK: - Default mode: withholding = 0, behavior identical to pre-1.8.4

    @Test("Default mode is .paidFromOutside")
    func defaultModeIsPaidFromOutside() {
        let dm = DataManager(skipPersistence: true)
        #expect(dm.rothConversionWithholdingMode == .paidFromOutside)
        #expect(dm.rothConversionFederalWithholdingRate == 0.24)
    }

    @Test(".paidFromOutside: withholding amount = $0, net = gross")
    func paidFromOutsideZeroWithholding() {
        let dm = makePAConversionScenario(mode: .paidFromOutside)
        #expect(dm.scenarioRothConversionWithholdingAmount == 0)
        #expect(dm.scenarioRothConversionNetAmount == 50_000)
    }

    @Test(".paidFromOutside on PA: full $50K conversion stays PA-exempt (Ans 274)")
    func paidFromOutsidePAFullyExempt() {
        let dm = makePAConversionScenario(mode: .paidFromOutside)
        // PA Single with no other income besides the $50K Roth conversion.
        // Full exemption → $0 PA tax.
        #expect(dm.scenarioStateTax == 0,
                "PA + paidFromOutside: $50K conversion should be fully exempt. Got \(dm.scenarioStateTax)")
    }

    // MARK: - Withhold mode: withholding > 0, net < gross

    @Test(".withheldFromConversion at 24%: $50K conv → $12K withheld, $38K net")
    func withheldFromConversion24Percent() {
        let dm = makePAConversionScenario(mode: .withheldFromConversion, rate: 0.24)
        #expect(dm.scenarioRothConversionWithholdingAmount == 12_000)
        #expect(dm.scenarioRothConversionNetAmount == 38_000)
    }

    @Test(".withheldFromConversion at 10%: $50K conv → $5K withheld, $45K net")
    func withheldFromConversion10Percent() {
        let dm = makePAConversionScenario(mode: .withheldFromConversion, rate: 0.10)
        #expect(dm.scenarioRothConversionWithholdingAmount == 5_000)
        #expect(dm.scenarioRothConversionNetAmount == 45_000)
    }

    @Test(".withheldFromConversion at 37% (top bracket): $50K conv → $18,500 withheld, $31,500 net")
    func withheldFromConversion37Percent() {
        let dm = makePAConversionScenario(mode: .withheldFromConversion, rate: 0.37)
        #expect(dm.scenarioRothConversionWithholdingAmount == 18_500)
        #expect(dm.scenarioRothConversionNetAmount == 31_500)
    }

    // MARK: - PA Ans 274 withholding interaction

    /// The headline behavior: PA exemption only covers the NET portion when
    /// withholding is on. The withheld amount becomes PA-taxable.
    ///
    /// $50K conversion, 24% withholding → $12K withheld → $12K is PA-taxable
    /// distribution. PA flat rate 3.07% × $12K = $368.40 PA tax.
    @Test("PA + .withheldFromConversion: withheld portion becomes PA-taxable (Ans 274)")
    func paWithheldPortionTaxable() {
        let dm = makePAConversionScenario(mode: .withheldFromConversion, rate: 0.24)
        let tax = dm.scenarioStateTax
        // Approximately $368 (3.07% × $12K). Allow tolerance for any
        // intermediate rounding.
        #expect(tax > 350 && tax < 400,
                "PA Ans 274 withholding caveat: $12K withheld → ~$368 PA tax. Got \(tax)")
    }

    /// Negative control: identical scenario with rate=0 (still .withheldFromConversion
    /// mode) — no withholding amount, so full PA exemption preserved.
    @Test("PA + .withheldFromConversion at 0%: full exemption preserved")
    func paWithheldAtZeroRateStillExempt() {
        let dm = makePAConversionScenario(mode: .withheldFromConversion, rate: 0.0)
        #expect(dm.scenarioRothConversionWithholdingAmount == 0)
        #expect(dm.scenarioStateTax == 0,
                "PA + 0% withholding: no withheld amount → full exemption. Got \(dm.scenarioStateTax)")
    }

    // MARK: - IL and MS: full exemption regardless of withholding

    /// IL exempts Roth conversions per IL Pub 120, with NO documented
    /// "full balance" requirement. So in withhold mode, the full conversion
    /// stays IL-exempt.
    @Test("IL + .withheldFromConversion: full $50K conversion still exempt (no Ans 274 analog)")
    func ilWithheldFullExemption() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .illinois
        dm.filingStatus = .single
        dm.yourRothConversion = 50_000
        dm.rothConversionWithholdingMode = .withheldFromConversion
        dm.rothConversionFederalWithholdingRate = 0.24

        #expect(dm.scenarioStateTax == 0,
                "IL: Roth conversion fully exempt regardless of withholding. Got \(dm.scenarioStateTax)")
    }

    /// MS likewise — no documented "full balance" requirement.
    @Test("MS + .withheldFromConversion: full $50K conversion still exempt (no Ans 274 analog)")
    func msWithheldFullExemption() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.selectedState = .mississippi
        dm.filingStatus = .single
        dm.yourRothConversion = 50_000
        dm.rothConversionWithholdingMode = .withheldFromConversion
        dm.rothConversionFederalWithholdingRate = 0.24

        #expect(dm.scenarioStateTax == 0,
                "MS: Roth conversion fully exempt regardless of withholding. Got \(dm.scenarioStateTax)")
    }

    // MARK: - Federal tax is unaffected by withholding choice

    /// The withholding choice is a cash-flow decision; the tax liability on
    /// the conversion is the same either way. Verify federal scenario tax
    /// is identical between .paidFromOutside and .withheldFromConversion.
    @Test("Federal tax liability identical between paidFromOutside and withheld modes")
    func federalUnaffectedByWithholdingMode() {
        let dmOutside = makePAConversionScenario(mode: .paidFromOutside)
        let dmWithheld = makePAConversionScenario(mode: .withheldFromConversion, rate: 0.24)

        let fedOutside = dmOutside.scenarioFederalTax
        let fedWithheld = dmWithheld.scenarioFederalTax

        #expect(abs(fedOutside - fedWithheld) < 1.0,
                "Federal tax must be identical regardless of withholding source. outside=\(fedOutside) withheld=\(fedWithheld)")
    }

    // MARK: - Household-level setting applies to spouse conversion too

    /// Both spouse conversions count toward the same household withholding
    /// amount when both are non-zero.
    @Test("Household withholding applies to combined yourRothConversion + spouseRothConversion")
    func householdWithholdingAcrossSpouses() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        var sDob = DateComponents(); sDob.year = 1962; sDob.month = 1; sDob.day = 1
        dm.profile.spouseBirthDate = Calendar.current.date(from: sDob)!
        dm.profile.currentYear = 2026
        dm.enableSpouse = true
        dm.selectedState = .pennsylvania
        dm.filingStatus = .marriedFilingJointly
        dm.yourRothConversion = 30_000
        dm.spouseRothConversion = 20_000
        dm.rothConversionWithholdingMode = .withheldFromConversion
        dm.rothConversionFederalWithholdingRate = 0.24

        // Combined gross = $50K → withholding = $12K → net = $38K
        #expect(dm.scenarioTotalRothConversion == 50_000)
        #expect(dm.scenarioRothConversionWithholdingAmount == 12_000)
        #expect(dm.scenarioRothConversionNetAmount == 38_000)
    }

    // MARK: - Scenario consistency: stateTaxBreakdown mirrors scenarioStateTax

    /// The stateTaxBreakdown helper (which displays exemption attribution)
    /// must agree with scenarioStateTax. Mirror parity check for the new
    /// withholding-aware logic.
    @Test("stateTaxBreakdown matches scenarioStateTax in withhold mode (PA)")
    func breakdownMatchesInWithholdMode() {
        let dm = makePAConversionScenario(mode: .withheldFromConversion, rate: 0.24)
        let breakdown = dm.stateTaxBreakdown(forState: .pennsylvania, filingStatus: dm.filingStatus)
        #expect(abs(breakdown.totalStateTax - dm.scenarioStateTax) < 1.0,
                "breakdown=\(breakdown.totalStateTax) must match scenarioStateTax=\(dm.scenarioStateTax)")
    }
}
