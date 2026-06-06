//
//  IRSGoldenCaseTests.swift
//  RetireSmartIRATests
//
//  ORACLE tests: each expected value is externally verified against IRS publications.
//  CRITICAL: If a test FAILS, do NOT change the expected IRS value. A failure indicates
//  a potential engine bug that requires human review.
//

import Testing
import Foundation
@testable import RetireSmartIRA

// MARK: - Helpers (mirrors RetireSmartIRATests.swift conventions)

/// Creates a DataManager with a specific birth year (Jan 1) and clean state.
/// Always pins currentYear=2026 to reset TaxCalculationEngine.config singleton.
private func makeDM(birthYear: Int = 1955, filingStatus: FilingStatus = .single, state: USState = .california) -> DataManager {
    let dm = DataManager(skipPersistence: true)
    dm.currentYear = 2026   // reset singleton; overridable per-test after this call
    dm.filingStatus = filingStatus
    dm.selectedState = state
    var c = DateComponents(); c.year = birthYear; c.month = 1; c.day = 1
    dm.birthDate = Calendar.current.date(from: c)!
    dm.incomeSources = []
    dm.iraAccounts = []
    dm.deductionItems = []
    dm.enableSpouse = false
    dm.yourRothConversion = 0
    dm.spouseRothConversion = 0
    dm.yourExtraWithdrawal = 0
    dm.spouseExtraWithdrawal = 0
    dm.yourQCDAmount = 0
    dm.spouseQCDAmount = 0
    dm.stockDonationEnabled = false
    dm.cashDonationAmount = 0
    dm.inheritedExtraWithdrawals = [:]
    dm.deductionOverride = nil
    return dm
}

/// Checks two doubles are within a given tolerance (default $0.01).
private func isClose(_ a: Double, _ b: Double, tolerance: Double = 0.01) -> Bool {
    abs(a - b) < tolerance
}

// MARK: - IRS Golden Cases

@Suite("IRS Golden Cases", .serialized)
@MainActor struct IRSGoldenCaseTests {

    // -------------------------------------------------------------------------
    // CASE 1: IRS Pub 915 (2024), Worksheet 1, Example 1 — Single, 50% tier
    // -------------------------------------------------------------------------
    // Source: IRS Publication 915, "Social Security and Equivalent Railroad Retirement
    // Benefits," Worksheet 1 (Figuring Your Taxable Benefits), Example 1.
    //
    // Inputs (from the IRS example):
    //   Filing status:  Single
    //   SS benefits:    $5,980
    //   Pension:        $18,600   (fully-taxable — entered as .pension)
    //   Wages/other:    $9,400    (entered as .consulting; engine treats as ordinary income)
    //   Taxable interest: $990    (entered as .interest)
    //
    // IRS worksheet computation:
    //   Other income = $18,600 + $9,400 + $990 = $28,990
    //   Half of SS   = $5,980 / 2              = $2,990
    //   Provisional income                     = $31,980
    //   Single tier-1 threshold                = $25,000
    //   Single tier-2 threshold                = $34,000
    //   Provisional falls in 50% tier ($25K–$34K):
    //     taxable SS = min(0.5 × SS, 0.5 × (provisional − $25,000))
    //                = min($2,990, 0.5 × $6,980)
    //                = min($2,990, $3,490)
    //                = $2,990                  ← Worksheet line 19
    //
    // Expected: $2,990
    @Test("Pub 915 Ex.1 — Single, 50% tier → taxable SS = $2,990")
    func pub915Example1Single50Tier() {
        /// IRS Pub 915 Worksheet 1, Example 1 — Single filer in the 50% tier.
        /// SS $5,980; pension $18,600; wages $9,400 (consulting); interest $990.
        /// Expected taxable SS (Worksheet line 19) = $2,990.
        let dm = makeDM(filingStatus: .single)
        dm.incomeSources = [
            IncomeSource(name: "SS",       type: .socialSecurity, annualAmount: 5_980),
            IncomeSource(name: "Pension",  type: .pension,         annualAmount: 18_600),
            IncomeSource(name: "Wages",    type: .consulting,      annualAmount: 9_400),
            IncomeSource(name: "Interest", type: .interest,        annualAmount: 990)
        ]
        let taxableSS = dm.calculateTaxableSocialSecurity(filingStatus: .single)
        #expect(isClose(taxableSS, 2_990), "IRS Pub 915 Ex.1 expects taxable SS = $2,990. Engine returned \(taxableSS).")
    }

    // -------------------------------------------------------------------------
    // CASE 2: IRS Pub 590-B (2025), Example 1 — RMD at age 75
    // -------------------------------------------------------------------------
    // Source: IRS Publication 590-B (2025), "Distributions from Individual
    // Retirement Arrangements (IRAs)," Example 1 (Uniform Lifetime Table).
    //
    // Inputs:
    //   IRA balance (Dec 31 prior year): $100,000
    //   Account owner age:               75
    //   Uniform Lifetime Table divisor:  24.6
    //
    // IRS computation:
    //   RMD = $100,000 / 24.6 = $4,065.04 → rounds to $4,065
    //
    // Expected divisor: 24.6
    // Expected RMD:     ~$4,065
    @Test("Pub 590-B Ex.1 — Age 75 ULT divisor = 24.6")
    func pub590BAge75Divisor() {
        /// IRS Pub 590-B (2025), Uniform Lifetime Table, age 75.
        /// Table entry must equal 24.6.
        let dm = makeDM()
        #expect(dm.lifeExpectancyFactor(for: 75) == 24.6, "IRS ULT age-75 divisor must be 24.6. Engine returned \(dm.lifeExpectancyFactor(for: 75)).")
    }

    @Test("Pub 590-B Ex.1 — Age 75, $100K balance → RMD ≈ $4,065")
    func pub590BAge75RMD() {
        /// IRS Pub 590-B (2025) Example 1: balance $100,000, age 75.
        /// RMD = $100,000 / 24.6 = $4,065.04 ≈ $4,065.
        let dm = makeDM()
        let rmd = dm.calculateRMD(for: 75, balance: 100_000)
        #expect(isClose(rmd, 4_065, tolerance: 1.0), "IRS Pub 590-B Ex.1 expects RMD ≈ $4,065. Engine returned \(rmd).")
    }

    // -------------------------------------------------------------------------
    // CASE 3: IRS NIIT Q&A, Example A — MFJ
    // -------------------------------------------------------------------------
    // Source: IRS "Questions and Answers on the Net Investment Income Tax,"
    // https://www.irs.gov/newsroom/questions-and-answers-on-the-net-investment-income-tax
    // Example A.
    //
    // Inputs:
    //   Filing status:         Married Filing Jointly
    //   Net investment income: $225,000
    //   MAGI:                  $300,000
    //   NIIT threshold (MFJ):  $250,000
    //
    // IRS computation:
    //   Excess MAGI over threshold = $300,000 − $250,000 = $50,000
    //   NIIT base = min(NII, excess MAGI) = min($225,000, $50,000) = $50,000
    //   NIIT = 3.8% × $50,000 = $1,900
    //
    // Expected: $1,900
    @Test("NIIT Q&A Ex.A — MFJ, NII $225K, MAGI $300K → NIIT = $1,900")
    func niitQandAExampleA() {
        /// IRS "Questions and Answers on the NIIT," Example A.
        /// MFJ; NII $225,000; MAGI $300,000; threshold $250,000.
        /// Expected NIIT = 3.8% × min($225,000, $50,000) = $1,900.
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        let result = dm.calculateNIIT(nii: 225_000, magi: 300_000, filingStatus: .marriedFilingJointly)
        #expect(isClose(result.annualNIITax, 1_900), "IRS NIIT Q&A Ex.A expects NIIT = $1,900. Engine returned \(result.annualNIITax).")
    }

    // -------------------------------------------------------------------------
    // CASE 4: End-to-end stock-donation integration regression
    // -------------------------------------------------------------------------
    // Source: Hand-computed. NOT an IRS example — this is an end-to-end integration
    // regression that pins three recently-fixed engine bugs in one test:
    //   (a) Dividend-double-count fix: dividends must not appear twice in gross income.
    //   (b) Stock-gain-in-gross fix: avoided (unrealized) stock gain must NOT reduce
    //       scenarioGrossIncome (the gain was never realized).
    //   (c) Stock-gain-in-NII fix: avoided stock gain must NOT reduce
    //       scenarioNetInvestmentIncome (same reason).
    //
    // Scenario (MFJ):
    //   Income: qualified dividends $50,000 + interest $10,000 → base NII = $60,000
    //           pension $40,000 (ordinary income, not NII)
    //   Stock donation: purchase price $10,000; current FMV $60,000 → avoided gain $50,000
    //                   purchase date = 2 years ago (long-term)
    //
    // Assertions:
    //   1. scenarioGrossIncome is unchanged by adding the stock donation
    //      (avoided gain was never in income)
    //   2. scenarioNetInvestmentIncome is unchanged
    //      (same reasoning — gain was never realized)
    //   3. scenarioStockGainAvoided == $50,000
    //      (informational value is still reported)
    //   4. scenarioCharitableDeductions increased by FMV of donated stock ($60,000)
    //      after enabling the donation vs. before
    @Test("E2E stock donation — avoided gain does not reduce gross income or NII")
    func stockDonationEndToEndIntegrationRegression() {
        /// Integration regression for three engine fixes applied together:
        /// (a) dividend-double-count, (b) stock-gain-in-gross, (c) stock-gain-in-NII.
        /// MFJ; qualified dividends $50K + interest $10K (NII = $60K); pension $40K.
        /// Stock donation: purchase $10K, FMV $60K, long-term (2 years ago) → avoided gain $50K.
        /// The $50K avoided gain must NOT appear in gross income or NII.
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.incomeSources = [
            IncomeSource(name: "Qual Div", type: .qualifiedDividends, annualAmount: 50_000),
            IncomeSource(name: "Interest", type: .interest,            annualAmount: 10_000),
            IncomeSource(name: "Pension",  type: .pension,             annualAmount: 40_000)
        ]

        // Baseline (no stock donation)
        let baseGross = dm.scenarioGrossIncome
        let baseNII   = dm.scenarioNetInvestmentIncome

        // Enable stock donation: unrealized gain = $60,000 − $10,000 = $50,000 (long-term)
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue  = 60_000
        dm.stockPurchaseDate  = Calendar.current.date(byAdding: .year, value: -2, to: Date())!

        // (b) Avoided gain must NOT reduce gross income
        #expect(
            isClose(dm.scenarioGrossIncome, baseGross),
            "Bug (b): stock donation must not change gross income. Expected \(baseGross), got \(dm.scenarioGrossIncome)."
        )

        // (c) Avoided gain must NOT reduce NII
        #expect(
            isClose(dm.scenarioNetInvestmentIncome, baseNII),
            "Bug (c): stock donation must not change NII. Expected \(baseNII), got \(dm.scenarioNetInvestmentIncome)."
        )

        // Informational value still reported correctly
        #expect(
            isClose(dm.scenarioStockGainAvoided, 50_000),
            "scenarioStockGainAvoided should be $50,000. Got \(dm.scenarioStockGainAvoided)."
        )

        // Charitable deduction = FMV of long-term stock ($60,000) — no cash donation added
        #expect(
            isClose(dm.scenarioCharitableDeductions, 60_000),
            "Charitable deduction for long-term stock should equal FMV $60,000. Got \(dm.scenarioCharitableDeductions)."
        )
    }
}

// MARK: - OBBBA Persona Sub-Calculation Golden Cases (TY 2026)
// ─────────────────────────────────────────────────────────────────────────────
// Source: Gemini-generated retirement personas were used as INPUT TEMPLATES
// ONLY. Each expected value below was INDEPENDENTLY computed from IRS Pub 915
// Worksheet 1 (SS taxability) and the OBBBA senior-deduction statute
// (IRC §63(f)(5)) + IRS Schedule 1-A worksheet, confirmed by legal research.
// Gemini's own tax numbers are NOT used as the oracle — several of them are
// wrong (e.g. Scenario 3 taxable income $110,800 vs correct $104,800 because
// Gemini used gross SS of $40k instead of the IRS-worksheet taxable amount of
// $34k). These tests assert the sub-calculations the engine must get right.
// ─────────────────────────────────────────────────────────────────────────────

@Suite("OBBBA 2026 Persona Sub-Calculations", .serialized)
@MainActor struct OBBBAPersonaSubCalcTests {

    // ── Scenario 3: Conversion Window ──────────────────────────────────────────
    // MFJ, ages 67 (you) & 65 (spouse). Social Security gross $40,000.
    // Pension $35,000. Strategic Roth Conversion $80,000.
    // Gemini labeled SS as "85% taxable: $40,000" and used it at 100% in AGI.
    // IRS Pub 915 Worksheet 1 (MFJ):
    //   combined income = ($35k+$80k) + 0.5×$40k = $135,000
    //   tier-1 = min(0.5×($44k-$32k), 0.5×$40k) = min($6k,$20k) = $6,000  ← needs line-14 cap
    //   tier-2 = min(($135k-$44k)×0.85, $40k×0.85-$6k) = min($77,350,$28k) = $28,000
    //   taxable SS = min($6k+$28k, $40k×0.85) = $34,000  (NOT $40,000)

    @Test("Persona 3 (Conversion Window): taxable SS = $34k (not $40k Gemini said)")
    func persona3TaxableSS() {
        // Source: IRS Pub 915 Worksheet 1, hand-computed.
        // Confirms the Pub 915 line-14 cap fix matters even for a high-income couple.
        let dm = makeDM(birthYear: 1959, filingStatus: .marriedFilingJointly)  // age 67 in 2026
        dm.enableSpouse = true
        // Set spouse born 1961 → age 65 in 2026
        var comps = DateComponents(); comps.year = 1961; comps.month = 1; comps.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: comps)!
        dm.incomeSources = [
            IncomeSource(name: "SS",      type: .socialSecurity, annualAmount: 40_000),
            IncomeSource(name: "Pension", type: .pension,         annualAmount: 35_000)
        ]
        dm.yourRothConversion = 80_000
        dm.currentYear = 2026  // pin explicitly — singleton may carry earlier year from other tests
        // Use scenarioTaxableSocialSecurity (not calculateTaxableSocialSecurity(filingStatus:))
        // because the Roth conversion must be included in the IRS combined-income test.
        // calculateTaxableSocialSecurity(filingStatus:) uses additionalIncome=0 by default.
        let taxSS = dm.scenarioTaxableSocialSecurity
        #expect(isClose(taxSS, 34_000),
            "IRS Pub 915 Worksheet 1: taxable SS should be $34,000. Engine: \(taxSS). (Gemini wrongly used $40,000.)")
    }

    @Test("Persona 3 (Conversion Window): senior deduction = $12k (MAGI $149k < $150k threshold)")
    func persona3SeniorDeduction() {
        // Source: IRC §63(f)(5) + IRS Schedule 1-A (per-person phase-out confirmed by legal research).
        // Both spouses 65+. MAGI = pension$35k + Roth$80k + taxable-SS$34k = $149,000.
        // Phase-out threshold MFJ $150,000. $149k < $150k → no phase-out → full $12,000.
        // (Gemini used MAGI $155k from wrong SS amount, but coincidentally also applied full $12k.)
        let dm = makeDM(birthYear: 1959, filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var comps = DateComponents(); comps.year = 1961; comps.month = 1; comps.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: comps)!
        dm.incomeSources = [
            IncomeSource(name: "SS",      type: .socialSecurity, annualAmount: 40_000),
            IncomeSource(name: "Pension", type: .pension,         annualAmount: 35_000)
        ]
        dm.yourRothConversion = 80_000
        dm.currentYear = 2026
        #expect(isClose(dm.seniorBonusDeductionAmount, 12_000),
            "OBBBA §63(f)(5): MAGI $149k < $150k threshold → full $12,000. Engine: \(dm.seniorBonusDeductionAmount).")
    }

    // ── Scenario 4: RMD Management ─────────────────────────────────────────────
    // Single, age 75. SS gross $25,000. Pension $20,000. Net taxable RMD $40,000
    // (gross $60k − $20k QCD). Note: QCD must be modeled as a pension/withdrawal;
    // this test asserts the SS sub-calculation and senior deduction on the
    // resulting income, which is the oracle-verifiable portion.
    //
    // IRS Pub 915 Worksheet 1 (Single), other income = pension$20k + netRMD$40k = $60k:
    //   combined = $60k + 0.5×$25k = $72,500
    //   $72,500 > $34,000 (second threshold) → 85% tier
    //   tier-1 = min(0.5×($34k-$25k), 0.5×$25k) = min($4,500, $12,500) = $4,500
    //   tier-2 = min(($72.5k-$34k)×0.85, $25k×0.85-$4,500) = min($32,725, $16,750) = $16,750
    //   taxable SS = min($4,500+$16,750, $25k×0.85) = min($21,250, $21,250) = $21,250
    // (Gemini's $21,250 happens to be correct here.)
    //
    // Senior deduction (IRC §63(f)(5), Single):
    //   MAGI = $60k + $21,250 = $81,250. Threshold $75,000.
    //   Reduction = ($81,250 - $75,000) × 6% = $375
    //   Deduction = max(0, $6,000 - $375) = $5,625
    // (Gemini said $6,000 — wrong; MAGI exceeds the $75k single threshold.)

    @Test("Persona 4 (RMD Management): taxable SS = $21,250 (IRS Pub 915)")
    func persona4TaxableSS() {
        // Source: IRS Pub 915 Worksheet 1, Single, hand-computed.
        let dm = makeDM(birthYear: 1951)  // age 75 in 2026
        dm.incomeSources = [
            IncomeSource(name: "SS",      type: .socialSecurity, annualAmount: 25_000),
            IncomeSource(name: "Pension", type: .pension,         annualAmount: 20_000),
            IncomeSource(name: "RMD",     type: .pension,         annualAmount: 40_000)  // net of QCD
        ]
        dm.currentYear = 2026
        let taxSS = dm.calculateTaxableSocialSecurity(filingStatus: .single)
        #expect(isClose(taxSS, 21_250),
            "IRS Pub 915 Worksheet 1: taxable SS should be $21,250. Engine: \(taxSS).")
    }

    @Test("Persona 4 (RMD Management): senior deduction = $5,625 (MAGI $81,250 exceeds $75k floor)")
    func persona4SeniorDeduction() {
        // Source: IRC §63(f)(5) + IRS Schedule 1-A, hand-computed.
        // MAGI = $81,250 (pension$20k + netRMD$40k + taxableSS$21,250).
        // Reduction = ($81,250 - $75,000) × 6% = $375.  Deduction = $6,000 - $375 = $5,625.
        // Gemini said $6,000 — wrong; they ignored the phase-out.
        let dm = makeDM(birthYear: 1951)
        dm.incomeSources = [
            IncomeSource(name: "SS",      type: .socialSecurity, annualAmount: 25_000),
            IncomeSource(name: "Pension", type: .pension,         annualAmount: 20_000),
            IncomeSource(name: "RMD",     type: .pension,         annualAmount: 40_000)
        ]
        dm.currentYear = 2026
        #expect(isClose(dm.seniorBonusDeductionAmount, 5_625),
            "OBBBA §63(f)(5) Single: MAGI $81,250 → deduction $5,625. Engine: \(dm.seniorBonusDeductionAmount). (Gemini wrongly said $6,000.)")
    }

    // ── Single filer — full truth table (5 cases, formula confirmed) ──────────
    // Source: IRC §63(f)(5); IRS Schedule 1-A Part V.
    // Single: D = max(0, $6,000 − 0.06 × max(0, MAGI − $75,000)).
    // Full phase-out at MAGI $175,000. No cliff.
    //
    // NOTE: The combined MFJ formula D = 12,000 − 0.06×(MAGI−150,000) is WRONG.
    // It overstates the deduction by $3k–$6k in the $150k–$250k band and implies
    // a false cliff at $250,001. The IRS Schedule 1-A computes the phase-out
    // per-person (Line 35), then enters it for each qualifying spouse (36a/36b).

    @Test("OBBBA senior deduction Single: MAGI $50k → $6,000 (below threshold)")
    func seniorDeductionSingleBelowThreshold() {
        let dm = makeDM(birthYear: 1961)  // age 65 in 2026
        dm.incomeSources = [IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)]
        dm.currentYear = 2026
        #expect(dm.seniorBonusDeductionAmount == 6_000,
            "MAGI $50k < $75k threshold → full $6,000. Got \(dm.seniorBonusDeductionAmount).")
    }

    @Test("OBBBA senior deduction Single: MAGI $75k → $6,000 (at threshold boundary)")
    func seniorDeductionSingleAtThreshold() {
        let dm = makeDM(birthYear: 1961)
        dm.incomeSources = [IncomeSource(name: "Pension", type: .pension, annualAmount: 75_000)]
        dm.currentYear = 2026
        #expect(isClose(dm.seniorBonusDeductionAmount, 6_000),
            "MAGI exactly $75k → full $6,000. Got \(dm.seniorBonusDeductionAmount).")
    }

    @Test("OBBBA senior deduction Single: MAGI $100k → $4,500 (mid phase-out)")
    func seniorDeductionSingleMidPhaseout() {
        // 6,000 − 0.06 × (100,000 − 75,000) = 6,000 − 1,500 = $4,500
        let dm = makeDM(birthYear: 1961)
        dm.incomeSources = [IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)]
        dm.currentYear = 2026
        #expect(isClose(dm.seniorBonusDeductionAmount, 4_500),
            "MAGI $100k → $4,500. Got \(dm.seniorBonusDeductionAmount).")
    }

    @Test("OBBBA senior deduction Single: MAGI $175k → $0 (upper phase-out boundary)")
    func seniorDeductionSingleAtUpperBoundary() {
        // 6,000 − 0.06 × (175,000 − 75,000) = 6,000 − 6,000 = $0. Smooth zero, no cliff.
        let dm = makeDM(birthYear: 1961)
        dm.incomeSources = [IncomeSource(name: "Pension", type: .pension, annualAmount: 175_000)]
        dm.currentYear = 2026
        #expect(dm.seniorBonusDeductionAmount == 0,
            "MAGI $175k → $0 (phase-out complete). Got \(dm.seniorBonusDeductionAmount).")
    }

    @Test("OBBBA senior deduction Single: MAGI $200k → $0 (above limit)")
    func seniorDeductionSingleAboveLimit() {
        let dm = makeDM(birthYear: 1961)
        dm.incomeSources = [IncomeSource(name: "Pension", type: .pension, annualAmount: 200_000)]
        dm.currentYear = 2026
        #expect(dm.seniorBonusDeductionAmount == 0,
            "MAGI $200k → $0. Got \(dm.seniorBonusDeductionAmount).")
    }

    // ── MFJ both 65+: correct per-person truth table ───────────────────────────
    // Per IRC §63(f)(5) + IRS Schedule 1-A: each spouse's $6,000 is independently
    // reduced by 6% × (MAGI − $150k), then summed.
    // Full phase-out at $250,000 MAGI. NO cliff.
    // Contrast with wrong "combined" reading: at $200k the combined model gives
    // $9,000 but the correct per-person answer is $6,000.

    @Test("OBBBA senior deduction MFJ both-65: MAGI $200k → $6,000 (NOT $9,000 combined)")
    func seniorDeductionMFJMidPhaseout() {
        // Per-person: each = max(0, $6,000 − 0.06×$50,000) = $3,000. Total = $6,000.
        // The wrong "combined" formula gives $12,000 − $3,000 = $9,000 — an overstatement.
        let dm = makeDM(birthYear: 1959, filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var comps = DateComponents(); comps.year = 1961; comps.month = 1; comps.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: comps)!
        dm.incomeSources = [IncomeSource(name: "Pension", type: .pension, annualAmount: 200_000)]
        dm.currentYear = 2026
        #expect(isClose(dm.seniorBonusDeductionAmount, 6_000),
            "MAGI $200k MFJ both-65 → $6,000 per-person (wrong combined formula gives $9,000). Got \(dm.seniorBonusDeductionAmount).")
    }

    // ── Senior deduction phase-out: full-phase-out boundary (MFJ both 65+) ────
    // Source: IRC §63(f)(5) per-person phase-out confirmed by legal research.
    // At MAGI = $250,000 (MFJ both 65+): per-person reduction = ($250k-$150k)×6% = $6,000
    // → per-person deduction = max(0, $6k-$6k) = $0 → combined = $0.
    // This pins the legally-confirmed full-phase-out threshold.

    @Test("OBBBA senior deduction: MFJ both 65+ fully phases out at MAGI $250k")
    func seniorDeductionFullPhaseoutMFJ() {
        // Source: IRC §63(f)(5) enacted statutory text; IRS Schedule 1-A Part V structure.
        // Full-phase-out MAGI for MFJ both-65 = $150,000 + $6,000/0.06 = $250,000.
        let dm = makeDM(birthYear: 1959, filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var comps = DateComponents(); comps.year = 1961; comps.month = 1; comps.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: comps)!
        dm.incomeSources = [
            IncomeSource(name: "Income", type: .pension, annualAmount: 250_000)
        ]
        dm.currentYear = 2026
        #expect(dm.seniorBonusDeductionAmount == 0,
            "At MAGI $250k (MFJ both 65+), senior deduction should be fully phased out. Engine: \(dm.seniorBonusDeductionAmount).")
    }
}
