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
private func makeDM(birthYear: Int = 1955, filingStatus: FilingStatus = .single, state: USState = .california) -> DataManager {
    let dm = DataManager(skipPersistence: true)
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
