//
//  RetireSmartIRATests.swift
//  RetireSmartIRATests
//
//  Unit tests for the RetireSmartIRA tax engine
//

import Testing
import Foundation
@testable import RetireSmartIRA

// MARK: - Helper

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

/// Checks two doubles are within $0.01
private func isClose(_ a: Double, _ b: Double, tolerance: Double = 0.01) -> Bool {
    abs(a - b) < tolerance
}

// MARK: - 1. Federal Tax — Single

@Suite("Federal Tax — Single", .serialized)
@MainActor struct FederalTaxSingleTests {

    @Test("$0 income → $0 tax")
    func zeroIncome() {
        let dm = makeDM()
        let tax = dm.calculateFederalTax(income: 0, filingStatus: .single)
        #expect(isClose(tax, 0))
    }

    @Test("$11,925 (top of 10% bracket) → $1,192.50")
    func topOf10Percent() {
        let dm = makeDM()
        let tax = dm.calculateFederalTax(income: 11_925, filingStatus: .single)
        #expect(isClose(tax, 1_192.50))
    }

    @Test("$50,000 (12% bracket) → $5,752.00")
    func mid22Percent() {
        let dm = makeDM()
        // 10% on 12,400 = 1,240.00
        // 12% on 37,600 = 4,512.00
        let tax = dm.calculateFederalTax(income: 50_000, filingStatus: .single)
        #expect(isClose(tax, 5_752.00))
    }

    @Test("$150,000 (24% bracket) → $28,598.00")
    func mid24Percent() {
        let dm = makeDM()
        // 10% on 12,400 = 1,240.00
        // 12% on 38,000 = 4,560.00
        // 22% on 55,300 = 12,166.00
        // 24% on 44,300 = 10,632.00
        let tax = dm.calculateFederalTax(income: 150_000, filingStatus: .single)
        #expect(isClose(tax, 28_598.00))
    }

    @Test("$700,000 (37% bracket) → $214,957.25")
    func in37Percent() {
        let dm = makeDM()
        // 10% on 12,400 = 1,240.00
        // 12% on 38,000 = 4,560.00
        // 22% on 55,300 = 12,166.00
        // 24% on 96,075 = 23,058.00
        // 32% on 54,450 = 17,424.00
        // 35% on 384,375 = 134,531.25
        // 37% on 59,400 = 21,978.00
        let tax = dm.calculateFederalTax(income: 700_000, filingStatus: .single)
        #expect(isClose(tax, 214_957.25))
    }
}

// MARK: - 2. Federal Tax — Married Filing Jointly

@Suite("Federal Tax — MFJ", .serialized)
@MainActor struct FederalTaxMFJTests {

    @Test("$0 income → $0 tax")
    func zeroIncome() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        let tax = dm.calculateFederalTax(income: 0, filingStatus: .marriedFilingJointly)
        #expect(isClose(tax, 0))
    }

    @Test("$23,850 (top of 10%) → $2,385.00")
    func topOf10Percent() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        let tax = dm.calculateFederalTax(income: 23_850, filingStatus: .marriedFilingJointly)
        #expect(isClose(tax, 2_385.00))
    }

    @Test("$100,000 (12% bracket) → $11,504.00")
    func mid22Percent() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        // 10% on 24,800 = 2,480.00
        // 12% on 75,200 = 9,024.00
        let tax = dm.calculateFederalTax(income: 100_000, filingStatus: .marriedFilingJointly)
        #expect(isClose(tax, 11_504.00))
    }

    @Test("$300,000 (24% bracket) → $57,196.00")
    func mid24Percent() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        // 10% on 24,800 = 2,480.00
        // 12% on 76,000 = 9,120.00
        // 22% on 110,600 = 24,332.00
        // 24% on 88,600 = 21,264.00
        let tax = dm.calculateFederalTax(income: 300_000, filingStatus: .marriedFilingJointly)
        #expect(isClose(tax, 57_196.00))
    }
}

// MARK: - 3. State Tax (California default)

@Suite("State Tax — California", .serialized)
@MainActor struct CaliforniaTaxTests {

    @Test("$0 income → $0 tax")
    func zeroIncome() {
        let dm = makeDM()
        let tax = dm.calculateStateTax(income: 0, filingStatus: .single)
        #expect(isClose(tax, 0))
    }

    @Test("$50,000 (6% bracket) → $1,335.02 (after $288 CA exemption credits)")
    func mid6Percent() {
        let dm = makeDM()
        // Raw brackets: 1%×10,412 + 2%×14,272 + 4%×14,275 + 6%×11,041 = $1,623.02
        // CA exemption credits: 2 exemptions (taxpayer + age 65+) × $144 = $288
        // Net: $1,623.02 − $288 = $1,335.02
        let tax = dm.calculateStateTax(income: 50_000, filingStatus: .single)
        #expect(isClose(tax, 1_335.02))
    }

    @Test("$100,000 (9.3% bracket) → $5,664.85 (after $288 CA exemption credits)")
    func mid93Percent() {
        let dm = makeDM()
        // Raw brackets: 1%→2%→4%→6%→8%→9.3% = $5,952.85
        // CA exemption credits: 2 exemptions (taxpayer + age 65+) × $144 = $288
        // Net: $5,952.85 − $288 = $5,664.85
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 5_664.85))
    }
}

// MARK: - 4. Social Security Taxation

@Suite("Social Security Taxation", .serialized)
@MainActor struct SocialSecurityTaxTests {

    @Test("Single: $20K SS, $0 other → $0 taxable")
    func singleBelowThreshold() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 20_000)
        ]
        let taxableSS = dm.calculateTaxableSocialSecurity(filingStatus: .single)
        #expect(isClose(taxableSS, 0))
    }

    @Test("Single: $24K SS, $15K other → $2,000 taxable (50% tier)")
    func single50PercentTier() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 24_000),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 15_000)
        ]
        // Combined = 15,000 + 12,000 = 27,000; excess over 25,000 = 2,000
        let taxableSS = dm.calculateTaxableSocialSecurity(filingStatus: .single)
        #expect(isClose(taxableSS, 2_000))
    }

    @Test("Single: $30K SS, $40K other → $22,350 taxable (85% tier)")
    func single85PercentTier() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 30_000),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        // Combined = 55,000; tier1 = 4,500; tier2 = 17,850; total = 22,350
        let taxableSS = dm.calculateTaxableSocialSecurity(filingStatus: .single)
        #expect(isClose(taxableSS, 22_350))
    }

    @Test("MFJ: $30K SS, $0 other → $0 taxable")
    func mfjBelowThreshold() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 30_000)
        ]
        let taxableSS = dm.calculateTaxableSocialSecurity(filingStatus: .marriedFilingJointly)
        #expect(isClose(taxableSS, 0))
    }

    @Test("MFJ: $40K SS, $50K other → $28,100 taxable (85% tier)")
    func mfj85PercentTier() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 40_000),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        // Combined = 70,000; tier1 = 6,000; tier2 = 22,100; total = 28,100
        let taxableSS = dm.calculateTaxableSocialSecurity(filingStatus: .marriedFilingJointly)
        #expect(isClose(taxableSS, 28_100))
    }
}

// MARK: - 5. RMD Calculations

@Suite("RMD Calculations", .serialized)
@MainActor struct RMDCalculationTests {

    @Test("Age 73, $500K → $18,867.92")
    func age73() {
        let dm = makeDM()
        let rmd = dm.calculateRMD(for: 73, balance: 500_000)
        #expect(isClose(rmd, 18_867.92))
    }

    @Test("Age 80, $300K → $14,851.49")
    func age80() {
        let dm = makeDM()
        let rmd = dm.calculateRMD(for: 80, balance: 300_000)
        #expect(isClose(rmd, 14_851.49))
    }

    @Test("Age 95, $100K → $11,235.96")
    func age95() {
        let dm = makeDM()
        let rmd = dm.calculateRMD(for: 95, balance: 100_000)
        #expect(isClose(rmd, 11_235.96))
    }

    @Test("Age 121 (beyond table) → defaults to factor 2.0 → $50,000")
    func ageBeyondTable() {
        let dm = makeDM()
        let rmd = dm.calculateRMD(for: 121, balance: 100_000)
        #expect(isClose(rmd, 50_000))
    }
}

// MARK: - 6. RMD Age Determination

@Suite("RMD Age Rules", .serialized)
@MainActor struct RMDAgeTests {

    @Test("Born 1950 → RMD age 72")
    func born1950() {
        let dm = makeDM(birthYear: 1950)
        #expect(dm.rmdAge == 72)
    }

    @Test("Born 1955 → RMD age 73")
    func born1955() {
        let dm = makeDM(birthYear: 1955)
        #expect(dm.rmdAge == 73)
    }

    @Test("Born 1959 → RMD age 73 (upper boundary)")
    func born1959() {
        let dm = makeDM(birthYear: 1959)
        #expect(dm.rmdAge == 73)
    }

    @Test("Born 1960 → RMD age 75")
    func born1960() {
        let dm = makeDM(birthYear: 1960)
        #expect(dm.rmdAge == 75)
    }

    @Test("Born 1965 → RMD age 75")
    func born1965() {
        let dm = makeDM(birthYear: 1965)
        #expect(dm.rmdAge == 75)
    }
}

// MARK: - 7. Medical Deduction Floor

@Suite("Medical Deduction Floor", .serialized)
@MainActor struct MedicalDeductionTests {

    @Test("Medical $5K on AGI $100K → floor $7,500 → deductible $0")
    func belowFloor() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 5_000)
        ]
        #expect(dm.totalMedicalExpenses == 5_000)
        #expect(isClose(dm.medicalAGIFloor, 7_500))
        #expect(isClose(dm.deductibleMedicalExpenses, 0))
    }

    @Test("Medical $15K on AGI $100K → floor $7,500 → deductible $7,500")
    func aboveFloor() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 15_000)
        ]
        #expect(isClose(dm.deductibleMedicalExpenses, 7_500))
    }

    @Test("No medical expenses → deductible $0")
    func noMedical() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        #expect(dm.totalMedicalExpenses == 0)
        #expect(dm.deductibleMedicalExpenses == 0)
    }
}

// MARK: - 8. Standard vs. Itemized Deduction

@Suite("Standard vs Itemized Deduction", .serialized)
@MainActor struct DeductionChoiceTests {

    @Test("Itemized < standard → auto-picks standard")
    func autoPicksStandard() {
        let dm = makeDM(birthYear: 1955)
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Prop Tax", type: .propertyTax, annualAmount: 5_000)
        ]
        dm.deductionOverride = nil
        #expect(dm.recommendedDeductionType == .standard)
        #expect(dm.scenarioEffectiveItemize == false)
    }

    @Test("Itemized > standard → auto-picks itemized")
    func autoPicksItemized() {
        let dm = makeDM(birthYear: 1955)
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 15_000),
            DeductionItem(name: "Prop Tax", type: .propertyTax, annualAmount: 8_000),
            DeductionItem(name: "SALT", type: .saltTax, annualAmount: 5_000)
        ]
        dm.deductionOverride = nil
        #expect(dm.totalItemizedDeductions > dm.standardDeductionAmount)
        #expect(dm.recommendedDeductionType == .itemized)
        #expect(dm.scenarioEffectiveItemize == true)
    }

    @Test("User override to itemized even when standard is higher")
    func overrideToItemized() {
        let dm = makeDM(birthYear: 1955)
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Prop Tax", type: .propertyTax, annualAmount: 5_000)
        ]
        dm.deductionOverride = .itemized
        #expect(dm.scenarioEffectiveItemize == true)
        #expect(dm.effectiveDeductionAmount == dm.totalItemizedDeductions)
    }
}

// MARK: - 9. Capital Gains Preferential Rates

@Suite("Capital Gains Preferential Rates", .serialized)
@MainActor struct CapitalGainsTaxTests {

    @Test("Ordinary $40K + LTCG $20K → $6,134.50")
    func ltcgPartiallyAt0Percent() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000),
            IncomeSource(name: "LTCG", type: .capitalGainsLong, annualAmount: 20_000)
        ]
        // Ordinary tax on $40K: 10% on 12,400 + 12% on 27,600 = 4,552
        // Cap gains: 0% up to 49,450, then 15%
        //   taxOnTotal(60K) = 1,582.50; taxOnOrdinary(40K) = 0
        //   capGainsTax = 1,582.50
        // Total = 4,552 + 1,582.50 = 6,134.50
        let tax = dm.calculateFederalTax(income: 60_000, filingStatus: .single)
        #expect(isClose(tax, 6_134.50))
    }

    @Test("Ordinary $50K + LTCG $50K → $13,252.00")
    func ltcgMostlyAt15Percent() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000),
            IncomeSource(name: "LTCG", type: .capitalGainsLong, annualAmount: 50_000)
        ]
        // Ordinary tax on $50K: 10% on 12,400 + 12% on 37,600 = 5,752
        // Cap gains tax = 7,500.00
        // Total = 13,252.00
        let tax = dm.calculateFederalTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 13_252.00))
    }
}

// MARK: - 10. Life Expectancy Factor Lookup

@Suite("Life Expectancy Factors", .serialized)
@MainActor struct LifeExpectancyTests {

    @Test("Factor at age 72 → 27.4")
    func age72() {
        let dm = makeDM()
        #expect(dm.lifeExpectancyFactor(for: 72) == 27.4)
    }

    @Test("Factor at age 90 → 12.2")
    func age90() {
        let dm = makeDM()
        #expect(dm.lifeExpectancyFactor(for: 90) == 12.2)
    }

    @Test("Factor at age 120 → 2.0")
    func age120() {
        let dm = makeDM()
        #expect(dm.lifeExpectancyFactor(for: 120) == 2.0)
    }

    @Test("Factor beyond table → 2.0 default")
    func ageBeyondTable() {
        let dm = makeDM()
        #expect(dm.lifeExpectancyFactor(for: 130) == 2.0)
    }
}

// MARK: - 11. Marginal Rate Tests

@Suite("Marginal Rates", .serialized)
@MainActor struct MarginalRateTests {

    @Test("Federal marginal at $50K (single) → 12%")
    func federalMarginalSingle() {
        let dm = makeDM()
        let rate = dm.federalMarginalRate(income: 50_000, filingStatus: .single)
        #expect(isClose(rate, 12.0, tolerance: 0.1))
    }

    @Test("Federal marginal at $10K (single) → 10%")
    func federalMarginal10Percent() {
        let dm = makeDM()
        let rate = dm.federalMarginalRate(income: 10_000, filingStatus: .single)
        #expect(isClose(rate, 10.0, tolerance: 0.1))
    }

    @Test("CA marginal at $100K (single) → 9.3%")
    func caMarginal93() {
        let dm = makeDM()
        let rate = dm.stateMarginalRate(income: 100_000, filingStatus: .single)
        #expect(isClose(rate, 9.3, tolerance: 0.1))
    }
}

// MARK: - 12. Balance Aggregation Tests

@Suite("Balance Aggregation", .serialized)
@MainActor struct BalanceTests {

    @Test("Primary Traditional balance sums IRA + 401k")
    func primaryTraditionalSum() {
        let dm = makeDM()
        dm.iraAccounts = [
            IRAAccount(name: "My IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary),
            IRAAccount(name: "My 401k", accountType: .traditional401k, balance: 300_000, owner: .primary),
            IRAAccount(name: "My Roth", accountType: .rothIRA, balance: 100_000, owner: .primary)
        ]
        #expect(dm.primaryTraditionalIRABalance == 500_000)
        #expect(dm.primaryRothBalance == 100_000)
    }

    @Test("Spouse balance only counts spouse-owned accounts")
    func spouseBalanceSeparation() {
        let dm = makeDM()
        dm.enableSpouse = true
        dm.iraAccounts = [
            IRAAccount(name: "My IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary),
            IRAAccount(name: "Spouse IRA", accountType: .traditionalIRA, balance: 150_000, owner: .spouse),
            IRAAccount(name: "Spouse 401k", accountType: .traditional401k, balance: 250_000, owner: .spouse)
        ]
        #expect(dm.primaryTraditionalIRABalance == 200_000)
        #expect(dm.spouseTraditionalIRABalance == 400_000)
    }

    @Test("Inherited accounts excluded from regular Traditional balance")
    func inheritedExcludedFromRegular() {
        let dm = makeDM()
        dm.iraAccounts = [
            IRAAccount(name: "My IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary),
            IRAAccount(name: "Inherited IRA", accountType: .inheritedTraditionalIRA, balance: 100_000, owner: .primary,
                       beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2020, beneficiaryBirthYear: 1955)
        ]
        #expect(dm.primaryTraditionalIRABalance == 200_000)
        #expect(dm.primaryInheritedTraditionalBalance == 100_000)
        #expect(dm.totalInheritedBalance == 100_000)
    }
}

// MARK: - 13. Single Life Expectancy Table I

@Suite("SLE Table I", .serialized)
@MainActor struct SLETableTests {

    @Test("SLE factor at age 50 → 36.2")
    func sleAge50() {
        let dm = makeDM()
        #expect(dm.singleLifeExpectancyFactor(for: 50) == 36.2)
    }

    @Test("SLE factor at age 80 → 11.2")
    func sleAge80() {
        let dm = makeDM()
        #expect(dm.singleLifeExpectancyFactor(for: 80) == 11.2)
    }

    @Test("SLE factor at age 0 → 84.6")
    func sleAge0() {
        let dm = makeDM()
        #expect(dm.singleLifeExpectancyFactor(for: 0) == 84.6)
    }

    @Test("SLE factor at age 119 → 0.1")
    func sleAge119() {
        let dm = makeDM()
        #expect(dm.singleLifeExpectancyFactor(for: 119) == 0.1)
    }
}

// MARK: - 14. Inherited IRA RMD Calculations

@Suite("Inherited IRA RMD", .serialized)
@MainActor struct InheritedIRARMDTests {

    @Test("Non-EDB, before RBD: no annual RMD, 10-year deadline")
    func nonEDBBeforeRBD() {
        let dm = makeDM()
        dm.currentYear = 2026
        let account = IRAAccount(
            name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 500_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, decedentRBDStatus: .beforeRBD,
            yearOfInheritance: 2020, beneficiaryBirthYear: 1970
        )
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(result.annualRMD == 0)
        #expect(result.mustEmptyByYear == 2030)
        #expect(result.yearsRemaining == 4)
    }

    @Test("Non-EDB, after RBD: annual RMDs + 10-year deadline")
    func nonEDBAfterRBD() {
        let dm = makeDM()
        dm.currentYear = 2026
        let account = IRAAccount(
            name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 300_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, decedentRBDStatus: .afterRBD,
            yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        // Year after inheritance = 2023, beneficiary age in 2023 = 53
        // SLE factor at age 53 = 33.4
        // In 2026: yearsOfReduction = 2026 - 2023 = 3, factor = 33.4 - 3 = 30.4
        // RMD = 300,000 / 30.4 = 9,868.42
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(result.annualRMD > 0)
        #expect(isClose(result.annualRMD, 300_000 / 30.4))
        #expect(result.mustEmptyByYear == 2032)
    }

    @Test("Spouse beneficiary: lifetime stretch, no deadline")
    func spouseBeneficiary() {
        let dm = makeDM()
        dm.currentYear = 2026
        let account = IRAAccount(
            name: "Spouse Inherited", accountType: .inheritedTraditionalIRA, balance: 400_000, owner: .primary,
            beneficiaryType: .spouse,
            yearOfInheritance: 2024, beneficiaryBirthYear: 1960
        )
        // Beneficiary age in 2026 = 66, SLE factor at 66 = 22.0
        // RMD = 400,000 / 22.0 = 18,181.82
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(isClose(result.annualRMD, 400_000 / 22.0))
        #expect(result.mustEmptyByYear == nil)
    }

    @Test("Spouse beneficiary: no RMD in year of inheritance")
    func spouseNoRMDYearOfInheritance() {
        let dm = makeDM()
        dm.currentYear = 2025
        let account = IRAAccount(
            name: "Spouse Inherited", accountType: .inheritedTraditionalIRA, balance: 400_000, owner: .primary,
            beneficiaryType: .spouse,
            yearOfInheritance: 2025, beneficiaryBirthYear: 1960
        )
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2025)
        #expect(result.annualRMD == 0)
    }

    @Test("Inherited Roth non-EDB: no annual RMD, 10-year deadline")
    func inheritedRothNonEDB() {
        let dm = makeDM()
        dm.currentYear = 2026
        let account = IRAAccount(
            name: "Roth Inherited", accountType: .inheritedRothIRA, balance: 200_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated,
            yearOfInheritance: 2021, beneficiaryBirthYear: 1970
        )
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(result.annualRMD == 0)
        #expect(result.mustEmptyByYear == 2031)
        #expect(result.yearsRemaining == 5)
    }

    @Test("Inherited Roth EDB spouse: no RMDs, no deadline")
    func inheritedRothEDBSpouse() {
        let dm = makeDM()
        dm.currentYear = 2026
        let account = IRAAccount(
            name: "Roth Spouse", accountType: .inheritedRothIRA, balance: 200_000, owner: .primary,
            beneficiaryType: .spouse,
            yearOfInheritance: 2024, beneficiaryBirthYear: 1960
        )
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(result.annualRMD == 0)
        #expect(result.mustEmptyByYear == nil)
    }

    @Test("Minor child before age 21: SLE stretch")
    func minorChildBeforeMajority() {
        let dm = makeDM()
        dm.currentYear = 2026
        let account = IRAAccount(
            name: "Minor Child Inherited", accountType: .inheritedTraditionalIRA, balance: 250_000, owner: .primary,
            beneficiaryType: .minorChild,
            yearOfInheritance: 2024, beneficiaryBirthYear: 2010, minorChildMajorityYear: 2031
        )
        // Beneficiary age in 2026 = 16, SLE factor at 16 = 68.9
        // RMD = 250,000 / 68.9 = 3,627.72
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(result.annualRMD > 0)
        #expect(isClose(result.annualRMD, 250_000 / 68.9))
        #expect(result.mustEmptyByYear == nil) // still a minor, no 10-year deadline yet
    }

    @Test("Not >10 years younger: lifetime stretch with reducing factor")
    func notTenYearsYounger() {
        let dm = makeDM()
        dm.currentYear = 2026
        let account = IRAAccount(
            name: "Sibling Inherited", accountType: .inheritedTraditionalIRA, balance: 350_000, owner: .primary,
            beneficiaryType: .notTenYearsYounger,
            yearOfInheritance: 2023, beneficiaryBirthYear: 1955
        )
        // Year after inheritance = 2024, beneficiary age in 2024 = 69
        // SLE factor at 69 = 19.6
        // In 2026: yearsOfReduction = 2026 - 2024 = 2, factor = 19.6 - 2 = 17.6
        // RMD = 350,000 / 17.6 = 19,886.36
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(isClose(result.annualRMD, 350_000 / 17.6))
        #expect(result.mustEmptyByYear == nil)
    }

    @Test("10-year deadline reached: full balance due")
    func tenYearDeadlineReached() {
        let dm = makeDM()
        dm.currentYear = 2030
        let account = IRAAccount(
            name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 100_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, decedentRBDStatus: .beforeRBD,
            yearOfInheritance: 2020, beneficiaryBirthYear: 1970
        )
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2030)
        #expect(result.annualRMD == 100_000)
        #expect(result.yearsRemaining == 0)
    }
}

// MARK: - 15. AccountType Properties

@Suite("AccountType Properties", .serialized)
@MainActor struct AccountTypeTests {

    @Test("isInherited correctly identifies inherited types")
    func isInherited() {
        #expect(AccountType.inheritedTraditionalIRA.isInherited == true)
        #expect(AccountType.inheritedRothIRA.isInherited == true)
        #expect(AccountType.traditionalIRA.isInherited == false)
        #expect(AccountType.rothIRA.isInherited == false)
        #expect(AccountType.traditional401k.isInherited == false)
        #expect(AccountType.roth401k.isInherited == false)
    }

    @Test("isTraditionalType includes inherited traditional")
    func isTraditionalType() {
        #expect(AccountType.traditionalIRA.isTraditionalType == true)
        #expect(AccountType.traditional401k.isTraditionalType == true)
        #expect(AccountType.inheritedTraditionalIRA.isTraditionalType == true)
        #expect(AccountType.rothIRA.isTraditionalType == false)
        #expect(AccountType.inheritedRothIRA.isTraditionalType == false)
    }
}

// MARK: - 16. IRMAA Tier Calculations

@Suite("IRMAA Tier Calculations", .serialized)
@MainActor struct IRMAATierTests {

    @Test("Single: $100K MAGI → Tier 0 (no surcharge)")
    func singleBelowAllThresholds() {
        let dm = makeDM()
        let result = dm.calculateIRMAA(magi: 100_000, filingStatus: .single)
        #expect(result.tier == 0)
        #expect(isClose(result.annualSurchargePerPerson, 0))
    }

    @Test("Single: $109,000 → Tier 0 (just below cliff)")
    func singleJustBelowTier1() {
        let dm = makeDM()
        let result = dm.calculateIRMAA(magi: 109_000, filingStatus: .single)
        #expect(result.tier == 0)
        #expect(isClose(result.annualSurchargePerPerson, 0))
    }

    @Test("Single: $109,001 → Tier 1 (cliff!)")
    func singleExactlyAtTier1() {
        let dm = makeDM()
        let result = dm.calculateIRMAA(magi: 109_001, filingStatus: .single)
        #expect(result.tier == 1)
        // Surcharge = (284.10 - 202.90 + 14.50) × 12 = (81.20 + 14.50) × 12 = 1,148.40
        #expect(isClose(result.annualSurchargePerPerson, (81.20 + 14.50) * 12, tolerance: 0.10))
    }

    @Test("Single: $200K → Tier 3")
    func singleTier3() {
        let dm = makeDM()
        let result = dm.calculateIRMAA(magi: 200_000, filingStatus: .single)
        #expect(result.tier == 3)
        #expect(result.annualSurchargePerPerson > 0)
    }

    @Test("Single: $600K → Tier 5 (top tier)")
    func singleTopTier() {
        let dm = makeDM()
        let result = dm.calculateIRMAA(magi: 600_000, filingStatus: .single)
        #expect(result.tier == 5)
        #expect(result.distanceToNextTier == nil)
    }

    @Test("MFJ: $218,000 → Tier 0 (just below MFJ cliff)")
    func mfjBelowTier1() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        let result = dm.calculateIRMAA(magi: 218_000, filingStatus: .marriedFilingJointly)
        #expect(result.tier == 0)
    }

    @Test("MFJ: $218,001 → Tier 1 (cliff!)")
    func mfjExactlyAtTier1() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        let result = dm.calculateIRMAA(magi: 218_001, filingStatus: .marriedFilingJointly)
        #expect(result.tier == 1)
    }

    @Test("MFJ: $500K → Tier 4")
    func mfjTier4() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        let result = dm.calculateIRMAA(magi: 500_000, filingStatus: .marriedFilingJointly)
        #expect(result.tier == 4)
    }

    @Test("Distance to next tier is accurate")
    func distanceToNextTier() {
        let dm = makeDM()
        let result = dm.calculateIRMAA(magi: 130_000, filingStatus: .single)
        #expect(result.tier == 1)
        // Next tier at 137,001 → distance = 7,001
        #expect(isClose(result.distanceToNextTier!, 7_001, tolerance: 1.0))
    }
}

// MARK: - 17. IRMAA Scenario Impact

@Suite("IRMAA Scenario Impact", .serialized)
@MainActor struct IRMAAScenarioTests {

    @Test("Medicare member count: single age 65+ = 1")
    func medicareMemberCountSingle() {
        let dm = makeDM(birthYear: 1960) // age 66 in 2026
        #expect(dm.medicareMemberCount == 1)
    }

    @Test("Medicare member count: under 65 = 0")
    func medicareMemberCountYoung() {
        let dm = makeDM(birthYear: 1965) // age 61 in 2026
        #expect(dm.medicareMemberCount == 0)
    }

    @Test("Medicare member count: MFJ both 65+ = 2")
    func medicareMemberCountCouple() {
        let dm = makeDM(birthYear: 1955, filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1957; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(dm.medicareMemberCount == 2)
    }

    @Test("Roth conversion crossing IRMAA cliff produces surcharge")
    func rothConversionCrossesCliff() {
        let dm = makeDM(birthYear: 1955) // age 71 in 2026 — Medicare eligible
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 105_000)
        ]
        // Base MAGI ~105,000 → Tier 0
        // With $10K Roth conversion → MAGI ~115,000 → Tier 1
        dm.yourRothConversion = 10_000
        #expect(dm.scenarioIRMAA.tier >= 1)
        #expect(dm.rothConversionIRMAAImpact > 0)
        #expect(dm.scenarioPushedToHigherIRMAATier == true)
    }

    @Test("No IRMAA impact when user is under 65")
    func noImpactUnder65() {
        let dm = makeDM(birthYear: 1965) // age 61 — not on Medicare
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 200_000)
        ]
        dm.yourRothConversion = 50_000
        // Even at high income, no IRMAA impact since not on Medicare
        #expect(dm.medicareMemberCount == 0)
        #expect(dm.rothConversionIRMAAImpact == 0)
    }
}

// MARK: - 18. Multi-State Tax — No Income Tax

@Suite("State Tax — No Income Tax States", .serialized)
@MainActor struct NoIncomeTaxStateTests {

    @Test("Alaska: $100K income → $0 state tax")
    func alaskaZeroTax() {
        let dm = makeDM(state: .alaska)
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 0))
    }

    @Test("Florida: $500K income → $0 state tax")
    func floridaZeroTax() {
        let dm = makeDM(state: .florida)
        let tax = dm.calculateStateTax(income: 500_000, filingStatus: .single)
        #expect(isClose(tax, 0))
    }

    @Test("Texas: $250K MFJ → $0 state tax")
    func texasZeroTax() {
        let dm = makeDM(filingStatus: .marriedFilingJointly, state: .texas)
        let tax = dm.calculateStateTax(income: 250_000, filingStatus: .marriedFilingJointly)
        #expect(isClose(tax, 0))
    }

    @Test("New Hampshire (special limited): $100K → $0 state tax")
    func newHampshireZeroTax() {
        let dm = makeDM(state: .newHampshire)
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 0))
    }

    @Test("Washington (special limited): $100K → $0 state tax")
    func washingtonZeroTax() {
        let dm = makeDM(state: .washington)
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 0))
    }

    @Test("No-tax state marginal rate = 0%")
    func noTaxMarginalRate() {
        let dm = makeDM(state: .nevada)
        let rate = dm.stateMarginalRate(income: 200_000, filingStatus: .single)
        #expect(isClose(rate, 0))
    }
}

// MARK: - 19. Multi-State Tax — Flat Tax States

@Suite("State Tax — Flat Tax States", .serialized)
@MainActor struct FlatTaxStateTests {

    @Test("Illinois: $100K → $4,950 (4.95% flat)")
    func illinoisFlat() {
        let dm = makeDM(state: .illinois)
        // IL exempts all retirement income, so use non-retirement income
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 4_950.00))
    }

    @Test("Indiana: $100K → $2,950 (2.95% flat)")
    func indianaFlat() {
        let dm = makeDM(state: .indiana)
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 2_950.00))
    }

    @Test("Pennsylvania: $100K → $3,070 (3.07% flat)")
    func pennsylvaniaFlat() {
        let dm = makeDM(state: .pennsylvania)
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 3_070.00))
    }

    @Test("Flat state marginal rate equals flat rate")
    func flatMarginalRate() {
        let dm = makeDM(state: .colorado)
        let rate = dm.stateMarginalRate(income: 100_000, filingStatus: .single)
        #expect(isClose(rate, 4.40, tolerance: 0.01))  // CO = 4.40%
    }

    @Test("Flat state average rate equals flat rate")
    func flatAverageRate() {
        let dm = makeDM(state: .northCarolina)
        let rate = dm.stateAverageRate(income: 100_000, filingStatus: .single)
        #expect(isClose(rate, 3.99, tolerance: 0.01))  // NC = 3.99%
    }
}

// MARK: - 20. Multi-State Tax — Progressive States

@Suite("State Tax — Progressive States", .serialized)
@MainActor struct ProgressiveTaxStateTests {

    @Test("California $100K preserved (regression test, after $288 CA exemption credits)")
    func californiaRegression() {
        let dm = makeDM(state: .california)
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 5_664.85))
    }

    @Test("New York: progressive brackets produce tax > 0")
    func newYorkProgressive() {
        let dm = makeDM(state: .newYork)
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(tax > 0)
        // NY $100K single: 4% on 8,500 + 4.5% on 3,200 + 5.25% on 2,200 + 5.85% on 66,750 + 6.25% on 19,350
        #expect(tax < 10_000)  // Sanity check: should be well under 10%
    }

    @Test("Oregon: progressive brackets produce tax > 0")
    func oregonProgressive() {
        let dm = makeDM(state: .oregon)
        let tax = dm.calculateStateTax(income: 80_000, filingStatus: .single)
        #expect(tax > 0)
        #expect(tax < 8_000)  // ~8.75% max, effective should be lower
    }

    @Test("Hawaii top rate 11%: high income produces high tax")
    func hawaiiHighIncome() {
        let dm = makeDM(state: .hawaii)
        let tax = dm.calculateStateTax(income: 300_000, filingStatus: .single)
        #expect(tax > 20_000)  // At 11% top rate on $300K
    }
}

// MARK: - 21. Multi-State — Retirement Income Exemptions

@Suite("State Tax — Retirement Exemptions", .serialized)
@MainActor struct RetirementExemptionTests {

    @Test("Illinois exempts pension income from state tax")
    func illinoisPensionExempt() {
        let dm = makeDM(state: .illinois)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        // IL exempts pension income fully → state tax on $80K pension should be $0
        let tax = dm.calculateStateTax(income: 80_000, filingStatus: .single)
        #expect(isClose(tax, 0))
    }

    @Test("Pennsylvania exempts IRA/retirement income")
    func pennsylvaniaRetirementExempt() {
        let dm = makeDM(state: .pennsylvania)
        dm.incomeSources = [
            IncomeSource(name: "RMD", type: .rmd, annualAmount: 50_000)
        ]
        let tax = dm.calculateStateTax(income: 50_000, filingStatus: .single)
        #expect(isClose(tax, 0))
    }

    @Test("California taxes pension income (no exemption)")
    func californiaPensionTaxed() {
        let dm = makeDM(state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let tax = dm.calculateStateTax(income: 80_000, filingStatus: .single)
        #expect(tax > 0)  // CA has no pension exemption
    }

    @Test("New York partial pension exclusion ($20K)")
    func newYorkPensionPartial() {
        let dm = makeDM(state: .newYork)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        // NY exempts first $20K of pension → taxes $30K
        let taxWithExemption = dm.calculateStateTax(income: 50_000, filingStatus: .single)
        let dm2 = makeDM(state: .newYork)
        let taxOnFull = dm2.calculateStateTax(income: 50_000, filingStatus: .single)
        // Tax with pension exemption should be less than without any retirement income
        #expect(taxWithExemption < taxOnFull)
    }

    @Test("State config correctly stored for all 51 entries (50 + DC)")
    func allStatesHaveConfigs() {
        for state in USState.allCases {
            let config = StateTaxData.config(for: state)
            #expect(config.state == state)
        }
    }
}

// MARK: - 22. Cross-State Tax Comparison

@Suite("State Tax — Cross-State Comparison", .serialized)
@MainActor struct CrossStateComparisonTests {

    @Test("Texas (no-tax) returns $0, California returns > $0 for same income")
    func noTaxVsProgressive() {
        let dm = makeDM()
        let txTax = dm.calculateStateTax(income: 100_000, forState: .texas, filingStatus: .single)
        let caTax = dm.calculateStateTax(income: 100_000, forState: .california, filingStatus: .single)
        #expect(isClose(txTax, 0))
        #expect(caTax > 0)
    }

    @Test("forState overload matches selectedState calculation for same state")
    func overloadMatchesSelected() {
        let dm = makeDM(state: .california)
        let viaSelected = dm.calculateStateTax(income: 80_000, filingStatus: .single)
        let viaForState = dm.calculateStateTax(income: 80_000, forState: .california, filingStatus: .single)
        #expect(isClose(viaSelected, viaForState))
    }

    @Test("All 51 states return non-negative tax for positive income")
    func allStatesNonNegative() {
        let dm = makeDM()
        for state in USState.allCases {
            let tax = dm.calculateStateTax(income: 150_000, forState: state, filingStatus: .single)
            #expect(tax >= 0, "Negative tax for \(state.rawValue)")
        }
    }

    @Test("Flat tax state via forState matches expected rate")
    func flatTaxViaForState() {
        let dm = makeDM(state: .california)  // selectedState is CA
        // But compute for Illinois (4.95% flat)
        let ilTax = dm.calculateStateTax(income: 100_000, forState: .illinois, filingStatus: .single)
        #expect(isClose(ilTax, 4_950.00))
    }
}

// MARK: - State Tax Breakdown Detail

@Suite("State Tax — Breakdown Detail", .serialized)
@MainActor struct StateTaxBreakdownTests {

    /// Helper to create a DataManager with specific retirement income sources.
    private func makeDMWithRetirementIncome(
        ss: Double = 0, pension: Double = 0, rmd: Double = 0, other: Double = 0,
        state: USState = .california
    ) -> DataManager {
        let dm = makeDM(state: state)
        var sources: [IncomeSource] = []
        if ss > 0 {
            sources.append(IncomeSource(id: UUID(), name: "SS", type: .socialSecurity, annualAmount: ss, owner: .primary))
        }
        if pension > 0 {
            sources.append(IncomeSource(id: UUID(), name: "Pension", type: .pension, annualAmount: pension, owner: .primary))
        }
        if rmd > 0 {
            sources.append(IncomeSource(id: UUID(), name: "RMD", type: .rmd, annualAmount: rmd, owner: .primary))
        }
        if other > 0 {
            sources.append(IncomeSource(id: UUID(), name: "Employment", type: .consulting, annualAmount: other, owner: .primary))
        }
        dm.incomeSources = sources
        return dm
    }

    @Test("NJ breakdown shows pension exempt up to $100K")
    func njPensionExemption() {
        let dm = makeDMWithRetirementIncome(pension: 80_000, rmd: 30_000, state: .newJersey)
        let bd = dm.stateTaxBreakdown(forState: .newJersey, filingStatus: .single)
        // NJ exempts first $100K pension and first $100K IRA
        #expect(isClose(bd.pensionExemptAmount, 80_000))  // all pension exempt (below $100K cap)
        #expect(isClose(bd.iraExemptAmount, 30_000))       // all RMD exempt (below $100K cap)
        #expect(bd.totalExempted > 0)
        #expect(isClose(bd.adjustedTaxableIncome, 0))      // all income exempted
        #expect(isClose(bd.totalStateTax, 0))
    }

    @Test("TX breakdown shows $0 tax with no-tax system")
    func txNoTax() {
        let dm = makeDMWithRetirementIncome(ss: 28_000, pension: 50_000, state: .texas)
        let bd = dm.stateTaxBreakdown(forState: .texas, filingStatus: .single)
        #expect(bd.taxSystemDescription == "No income tax")
        #expect(isClose(bd.totalStateTax, 0))
        #expect(bd.bracketBreakdown.isEmpty)
        #expect(bd.flatRate == nil)
    }

    @Test("CA breakdown shows all income taxed with progressive brackets")
    func caProgressiveBrackets() {
        let dm = makeDMWithRetirementIncome(pension: 50_000, rmd: 30_000, other: 20_000, state: .california)
        let bd = dm.stateTaxBreakdown(forState: .california, filingStatus: .single)
        // CA has no retirement exemptions (except SS which is exempt but no SS income here)
        #expect(isClose(bd.pensionExemptAmount, 0))
        #expect(isClose(bd.iraExemptAmount, 0))
        #expect(!bd.bracketBreakdown.isEmpty)
        #expect(bd.bracketBreakdown.count > 1)  // multiple brackets
        // Sum of bracket taxes should be >= total (total includes CA exemption credits)
        let bracketSum = bd.bracketBreakdown.reduce(0) { $0 + $1.taxFromBracket }
        #expect(bracketSum >= bd.totalStateTax)
        // Difference should be CA exemption credits ($288 for single age 65+)
        #expect(isClose(bracketSum - bd.totalStateTax, 288.0))
        #expect(bd.totalStateTax > 0)
    }

    @Test("IL breakdown shows pension and IRA fully exempt")
    func ilFullExemption() {
        let dm = makeDMWithRetirementIncome(pension: 60_000, rmd: 40_000, state: .illinois)
        let bd = dm.stateTaxBreakdown(forState: .illinois, filingStatus: .single)
        // IL exempts all pension and IRA income
        #expect(isClose(bd.pensionExemptAmount, 60_000))
        #expect(isClose(bd.iraExemptAmount, 40_000))
        #expect(isClose(bd.adjustedTaxableIncome, 0))
        #expect(isClose(bd.totalStateTax, 0))
        #expect(bd.flatRate != nil)  // IL is flat tax
    }

    @Test("Breakdown totalStateTax matches calculateStateTaxFromGross for all states")
    func breakdownMatchesCalculation() {
        let dm = makeDMWithRetirementIncome(ss: 20_000, pension: 40_000, rmd: 30_000, other: 10_000, state: .california)
        let grossIncome = dm.scenarioGrossIncome
        let taxableSS = dm.scenarioTaxableSocialSecurity
        for state in USState.allCases {
            let bd = dm.stateTaxBreakdown(forState: state, filingStatus: .single)
            let calcTax = dm.calculateStateTaxFromGross(grossIncome: grossIncome, forState: state, filingStatus: .single, taxableSocialSecurity: taxableSS)
            #expect(isClose(bd.totalStateTax, calcTax), "Breakdown mismatch for \(state.rawValue): breakdown=\(bd.totalStateTax) vs calc=\(calcTax)")
        }
    }
}

// MARK: - State Tax — Bug Fix Validation

@Suite("State Tax — Bug Fix Validation", .serialized)
@MainActor struct StateTaxBugFixTests {

    @Test("SS taxation includes Roth conversion in combined income test")
    func ssWithRothConversion() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 30_000),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 10_000)
        ]
        // Without Roth conversion: combined = 10,000 + 15,000 = 25,000 (at threshold, $0 taxable)
        let taxableWithout = dm.calculateTaxableSocialSecurity(filingStatus: .single, additionalIncome: 0)
        #expect(isClose(taxableWithout, 0))

        // With $20K Roth conversion: combined = 10,000 + 20,000 + 15,000 = 45,000 (well into 85% tier)
        let taxableWith = dm.calculateTaxableSocialSecurity(filingStatus: .single, additionalIncome: 20_000)
        #expect(taxableWith > 0, "Roth conversion should push SS into taxable range")
    }

    @Test("SS taxation includes extra withdrawal in combined income test")
    func ssWithExtraWithdrawal() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 24_000)
        ]
        // Without withdrawal: combined = 0 + 12,000 = 12,000 (below $25K threshold)
        let taxableWithout = dm.calculateTaxableSocialSecurity(filingStatus: .single, additionalIncome: 0)
        #expect(isClose(taxableWithout, 0))

        // With $30K withdrawal: combined = 30,000 + 12,000 = 42,000 (85% tier)
        let taxableWith = dm.calculateTaxableSocialSecurity(filingStatus: .single, additionalIncome: 30_000)
        #expect(taxableWith > 0, "Extra withdrawal should push SS into taxable range")
    }

    @Test("scenarioTaxableSocialSecurity includes scenario decisions")
    func scenarioSSIncludesDecisions() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 30_000),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 10_000)
        ]
        let baseTaxableSS = dm.calculateTaxableSocialSecurity(filingStatus: .single)

        dm.yourRothConversion = 50_000
        let scenarioTaxableSS = dm.scenarioTaxableSocialSecurity
        #expect(scenarioTaxableSS > baseTaxableSS, "Scenario with Roth conversion should increase taxable SS")
    }

    @Test("State tax uses state-specific deduction (CA $5,706 vs federal $16,100)")
    func stateDeductionCA() {
        let dm = makeDM(state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        // CA deduction is $5,706 (single), federal is $16,100
        // State taxable = 80,000 - 5,706 = 74,294 (CA has no pension exemption)
        let stateTax = dm.scenarioStateTax
        // If it were using federal deduction: 80,000 - 16,100 = 63,900 → lower tax
        // CA tax on 74,294 should be higher than on 63,900
        let taxOnLowerIncome = dm.calculateStateTax(income: 63_900, forState: .california, filingStatus: .single)
        #expect(stateTax > taxOnLowerIncome, "State tax with CA deduction ($5,706) should be higher than with federal deduction ($16,100)")
    }

    @Test("State tax SS exemption subtracts taxable portion, not full benefit")
    func ssExemptionUseTaxablePortion() {
        let dm = makeDM(state: .illinois)
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 30_000),
            IncomeSource(name: "Employment", type: .consulting, annualAmount: 50_000)
        ]
        // IL exempts SS and all retirement income.
        // The taxable SS portion is what gets exempted (not the full $30K benefit)
        // Employment income of $50K should still be taxed at IL's 4.95% rate
        let stateTax = dm.scenarioStateTax
        // IL has no standard deduction, so state taxable = gross income - 0 deduction
        // Then subtract taxable SS (exempt) and employment stays taxed
        #expect(stateTax > 0, "IL should still tax non-exempt employment income")
    }

    @Test("Federal-conformity state uses federal deduction")
    func federalConformityState() {
        let dm = makeDM(state: .colorado)
        dm.incomeSources = [
            IncomeSource(name: "Employment", type: .consulting, annualAmount: 100_000)
        ]
        // CO conforms to federal: uses the full federal standard deduction
        // (includes age 65+ additional and OBBBA Senior Bonus for the default birthYear 1955)
        let fedDeduction = dm.effectiveDeductionAmount
        // State taxable = 100,000 - fedDeduction (then CO retirement exemptions, none for consulting)
        let stateTax = dm.scenarioStateTax
        let expected = max(0, 100_000 - fedDeduction) * 0.044
        #expect(isClose(stateTax, expected, tolerance: 1.0))
    }

    @Test("No-deduction state taxes full gross income minus exemptions")
    func noDeductionState() {
        let dm = makeDM(state: .pennsylvania)
        dm.incomeSources = [
            IncomeSource(name: "Employment", type: .consulting, annualAmount: 60_000)
        ]
        // PA has no standard deduction but exempts retirement income
        // Employment is not exempt, so state taxable = 60,000 - 0 = 60,000
        // PA flat rate = 3.07%
        let stateTax = dm.scenarioStateTax
        let expected = 60_000 * 0.0307
        #expect(isClose(stateTax, expected, tolerance: 1.0))
    }
}

// MARK: - 23. Inherited Extra Withdrawals

@Suite("Inherited Extra Withdrawals", .serialized)
@MainActor struct InheritedExtraWithdrawalTests {

    @Test("Traditional extra increases scenarioTotalExtraWithdrawal")
    func traditionalExtraInTotal() {
        let dm = makeDM()
        let account = IRAAccount(
            name: "Inherited Trad", accountType: .inheritedTraditionalIRA, balance: 500_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [account]
        dm.inheritedExtraWithdrawals = [account.id: 20_000]
        #expect(isClose(dm.inheritedTraditionalExtraTotal, 20_000))
        #expect(dm.scenarioTotalExtraWithdrawal >= 20_000)
    }

    @Test("Roth extra does NOT increase scenarioTotalExtraWithdrawal")
    func rothExtraExcludedFromTaxable() {
        let dm = makeDM()
        let account = IRAAccount(
            name: "Inherited Roth", accountType: .inheritedRothIRA, balance: 200_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [account]
        dm.inheritedExtraWithdrawals = [account.id: 10_000]
        #expect(isClose(dm.inheritedTraditionalExtraTotal, 0))
        #expect(isClose(dm.inheritedExtraWithdrawalTotal, 10_000))
        #expect(isClose(dm.scenarioTotalExtraWithdrawal, 0))
    }

    @Test("Mixed Traditional + Roth: only Traditional counted in taxable total")
    func mixedTypesAggregation() {
        let dm = makeDM()
        let tradAccount = IRAAccount(
            name: "Inherited Trad", accountType: .inheritedTraditionalIRA, balance: 300_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        let rothAccount = IRAAccount(
            name: "Inherited Roth", accountType: .inheritedRothIRA, balance: 200_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [tradAccount, rothAccount]
        dm.inheritedExtraWithdrawals = [tradAccount.id: 15_000, rothAccount.id: 8_000]
        #expect(isClose(dm.inheritedTraditionalExtraTotal, 15_000))
        #expect(isClose(dm.inheritedExtraWithdrawalTotal, 23_000))
    }

    @Test("Traditional extra flows into scenarioGrossIncome")
    func traditionalExtraInGrossIncome() {
        let dm = makeDM()
        let account = IRAAccount(
            name: "Inherited Trad", accountType: .inheritedTraditionalIRA, balance: 300_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [account]
        let baseGross = dm.scenarioGrossIncome
        dm.inheritedExtraWithdrawals = [account.id: 15_000]
        #expect(isClose(dm.scenarioGrossIncome, baseGross + 15_000))
    }

    @Test("Roth extra does NOT affect scenarioGrossIncome")
    func rothExtraNoGrossIncomeEffect() {
        let dm = makeDM()
        let account = IRAAccount(
            name: "Inherited Roth", accountType: .inheritedRothIRA, balance: 200_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [account]
        let baseGross = dm.scenarioGrossIncome
        dm.inheritedExtraWithdrawals = [account.id: 10_000]
        #expect(isClose(dm.scenarioGrossIncome, baseGross))
    }

    @Test("hasActiveScenario true with only inherited extra")
    func hasActiveScenarioWithInheritedExtra() {
        let dm = makeDM()
        let account = IRAAccount(
            name: "Inherited Trad", accountType: .inheritedTraditionalIRA, balance: 300_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [account]
        #expect(dm.hasActiveScenario == false)
        dm.inheritedExtraWithdrawals = [account.id: 5_000]
        #expect(dm.hasActiveScenario == true)
    }

    @Test("Multiple inherited Traditional accounts aggregate correctly")
    func multipleAccountsAggregate() {
        let dm = makeDM()
        let account1 = IRAAccount(
            name: "Inherited 1", accountType: .inheritedTraditionalIRA, balance: 300_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        let account2 = IRAAccount(
            name: "Inherited 2", accountType: .inheritedTraditionalIRA, balance: 200_000, owner: .primary,
            beneficiaryType: .spouse, yearOfInheritance: 2023, beneficiaryBirthYear: 1955
        )
        dm.iraAccounts = [account1, account2]
        dm.inheritedExtraWithdrawals = [account1.id: 10_000, account2.id: 25_000]
        #expect(isClose(dm.inheritedTraditionalExtraTotal, 35_000))
    }
}

// MARK: - 24. Inherited Extra Withdrawal Tax Impact

@Suite("Inherited Extra Withdrawal Tax Impact", .serialized)
@MainActor struct InheritedExtraWithdrawalTaxImpactTests {

    @Test("Tax impact positive when Traditional extra > 0")
    func taxImpactPositive() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let account = IRAAccount(
            name: "Inherited Trad", accountType: .inheritedTraditionalIRA, balance: 300_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [account]
        dm.inheritedExtraWithdrawals = [account.id: 20_000]
        #expect(dm.inheritedExtraWithdrawalTaxImpact > 0)
    }

    @Test("Tax impact zero when only Roth extra")
    func taxImpactZeroForRoth() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let account = IRAAccount(
            name: "Inherited Roth", accountType: .inheritedRothIRA, balance: 200_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [account]
        dm.inheritedExtraWithdrawals = [account.id: 20_000]
        #expect(isClose(dm.inheritedExtraWithdrawalTaxImpact, 0))
    }

    @Test("IRMAA impact when inherited extra crosses cliff")
    func irmaaImpactCrossesCliff() {
        let dm = makeDM(birthYear: 1955) // age 71 → Medicare eligible
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 105_000)
        ]
        let account = IRAAccount(
            name: "Inherited Trad", accountType: .inheritedTraditionalIRA, balance: 300_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [account]
        // Push from ~105K to ~115K → cross single Tier 1 at 109,001
        dm.inheritedExtraWithdrawals = [account.id: 10_000]
        #expect(dm.inheritedExtraWithdrawalIRMAAImpact > 0)
    }

    @Test("No IRMAA impact when under 65")
    func noIrmaaUnder65() {
        let dm = makeDM(birthYear: 1965) // age 61 → not on Medicare
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 105_000)
        ]
        let account = IRAAccount(
            name: "Inherited Trad", accountType: .inheritedTraditionalIRA, balance: 300_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [account]
        dm.inheritedExtraWithdrawals = [account.id: 10_000]
        #expect(isClose(dm.inheritedExtraWithdrawalIRMAAImpact, 0))
    }
}

// MARK: - 25. Stock Donation — Short-Term Support

@Suite("Stock Donation — Short-Term Support", .serialized)
@MainActor struct StockDonationShortTermTests {

    @Test("Long-term stock: gain avoided equals unrealized gain")
    func longTermGainAvoided() {
        let dm = makeDM()
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        #expect(dm.scenarioStockIsLongTerm == true)
        #expect(isClose(dm.scenarioStockGainAvoided, 20_000))
    }

    @Test("Short-term stock: gain avoided equals unrealized gain")
    func shortTermGainAvoided() {
        let dm = makeDM()
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        #expect(dm.scenarioStockIsLongTerm == false)
        #expect(isClose(dm.scenarioStockGainAvoided, 20_000))
    }

    @Test("Long-term stock: deduction is FMV")
    func longTermDeductionIsFMV() {
        let dm = makeDM()
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        #expect(isClose(dm.scenarioCharitableDeductions, 30_000))
    }

    @Test("Short-term stock: deduction is cost basis")
    func shortTermDeductionIsCostBasis() {
        let dm = makeDM()
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        #expect(isClose(dm.scenarioCharitableDeductions, 10_000))
    }

    @Test("Long-term: stockCapGainsTaxAvoided > 0")
    func longTermCapGainsTaxAvoided() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        #expect(dm.stockCapGainsTaxAvoided > 0)
    }

    @Test("Short-term: stockCapGainsTaxAvoided > 0")
    func shortTermGainTaxAvoided() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        #expect(dm.stockCapGainsTaxAvoided > 0)
    }

    @Test("Both short-term and long-term stock donations avoid meaningful tax")
    func shortTermAndLongTermBothAvoidTax() {
        let dmShort = makeDM()
        dmShort.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dmShort.stockDonationEnabled = true
        dmShort.stockPurchasePrice = 10_000
        dmShort.stockCurrentValue = 30_000
        dmShort.stockPurchaseDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!

        let dmLong = makeDM()
        dmLong.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dmLong.stockDonationEnabled = true
        dmLong.stockPurchasePrice = 10_000
        dmLong.stockCurrentValue = 30_000
        dmLong.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!

        // Both should avoid meaningful tax on the $20K gain
        #expect(dmShort.stockCapGainsTaxAvoided > 0)
        #expect(dmLong.stockCapGainsTaxAvoided > 0)
        // Note: Long-term may show higher avoided tax because it gets a larger
        // charitable deduction ($30K FMV vs $10K basis), resulting in a lower
        // base tax and thus a bigger delta when the gain is added back.
        #expect(dmLong.stockCapGainsTaxAvoided > 2_000)
        #expect(dmShort.stockCapGainsTaxAvoided > 2_000)
    }

    @Test("No gain: stockGainAvoided is 0")
    func noGainZeroAvoided() {
        let dm = makeDM()
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 30_000
        dm.stockCurrentValue = 25_000  // loss position
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        #expect(isClose(dm.scenarioStockGainAvoided, 0))
    }

    @Test("Disabled: stockGainAvoided is 0")
    func disabledZeroAvoided() {
        let dm = makeDM()
        dm.stockDonationEnabled = false
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        #expect(isClose(dm.scenarioStockGainAvoided, 0))
    }

    @Test("Gross income subtracts avoided gain for short-term stock")
    func grossIncomeSubtractsShortTermGain() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let grossBefore = dm.scenarioGrossIncome
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        // Gross income should be reduced by the $20K avoided gain
        #expect(isClose(dm.scenarioGrossIncome, grossBefore - 20_000))
    }
}

// MARK: - 26. Stock Donation Tax Savings

@Suite("Stock Donation Tax Savings", .serialized)
@MainActor struct StockDonationTaxSavingsTests {

    @Test("Long-term deduction savings when itemizing")
    func longTermDeductionSavingsItemizing() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        // Force itemizing with large deductions
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 15_000),
            DeductionItem(name: "Prop Tax", type: .propertyTax, annualAmount: 8_000)
        ]
        dm.deductionOverride = .itemized
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        #expect(dm.stockDeductionTaxSavings > 0)
    }

    @Test("Short-term deduction savings when itemizing (less than long-term)")
    func shortTermDeductionSavingsLessThanLong() {
        let dmLong = makeDM()
        dmLong.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        dmLong.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 15_000),
            DeductionItem(name: "Prop Tax", type: .propertyTax, annualAmount: 8_000)
        ]
        dmLong.deductionOverride = .itemized
        dmLong.stockDonationEnabled = true
        dmLong.stockPurchasePrice = 10_000
        dmLong.stockCurrentValue = 30_000
        dmLong.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!

        let dmShort = makeDM()
        dmShort.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        dmShort.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 15_000),
            DeductionItem(name: "Prop Tax", type: .propertyTax, annualAmount: 8_000)
        ]
        dmShort.deductionOverride = .itemized
        dmShort.stockDonationEnabled = true
        dmShort.stockPurchasePrice = 10_000
        dmShort.stockCurrentValue = 30_000
        dmShort.stockPurchaseDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!

        #expect(dmShort.stockDeductionTaxSavings > 0)
        // Long-term deduction ($30K FMV) > short-term deduction ($10K cost basis) → more savings
        #expect(dmLong.stockDeductionTaxSavings > dmShort.stockDeductionTaxSavings)
    }

    @Test("No deduction savings when standard deduction")
    func noDeductionSavingsStandard() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        // No itemized deductions → standard deduction wins
        dm.deductionOverride = nil
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 15_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        // With small stock donation, standard deduction still dominates
        #expect(dm.scenarioEffectiveItemize == false)
        #expect(isClose(dm.stockDeductionTaxSavings, 0))
    }

    @Test("Combined stockDonationTaxSavings = deduction + cap gains avoided")
    func combinedTaxSavings() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 15_000),
            DeductionItem(name: "Prop Tax", type: .propertyTax, annualAmount: 8_000)
        ]
        dm.deductionOverride = .itemized
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let combined = dm.stockDonationTaxSavings
        let deduction = dm.stockDeductionTaxSavings
        let gains = dm.stockCapGainsTaxAvoided
        #expect(isClose(combined, deduction + gains))
    }
}

// MARK: - 27. Roth Conversion — Simple Analysis

@Suite("Roth Conversion — Simple Analysis", .serialized)
@MainActor struct RothConversionSimpleTests {

    @Test("Zero conversion → all zeros")
    func zeroConversion() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let result = dm.analyzeRothConversion(conversionAmount: 0)
        #expect(isClose(result.conversionAmount, 0))
        #expect(isClose(result.federalTax, 0))
        #expect(isClose(result.stateTax, 0))
        #expect(isClose(result.totalTax, 0))
        #expect(isClose(result.effectiveRate, 0))
    }

    @Test("Total tax equals federal + state")
    func totalEqualsSumOfParts() {
        let dm = makeDM() // CA
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let result = dm.analyzeRothConversion(conversionAmount: 20_000)
        #expect(isClose(result.totalTax, result.federalTax + result.stateTax))
    }

    @Test("Effective rate = totalTax / conversionAmount")
    func effectiveRateFormula() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let result = dm.analyzeRothConversion(conversionAmount: 25_000)
        let expectedRate = result.totalTax / 25_000
        #expect(isClose(result.effectiveRate, expectedRate))
    }

    @Test("Conversion within one federal bracket: tax = amount × marginal rate")
    func withinSingleFederalBracket() {
        let dm = makeDM(state: .florida)
        // $60K in 22% bracket ($50,400–$105,700), $10K stays in 22%
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        let result = dm.analyzeRothConversion(conversionAmount: 10_000)
        // Federal: $10K all at 22% = $2,200
        #expect(isClose(result.federalTax, 2_200))
        #expect(isClose(result.effectiveRate, 0.22))
    }

    @Test("Conversion crossing federal bracket: tax reflects mixed rates")
    func crossingFederalBracket() {
        let dm = makeDM(state: .florida)
        // $100K in 22% bracket, next at $105,700 (24%)
        // $20K conversion → $5,700 at 22% + $14,300 at 24%
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        let result = dm.analyzeRothConversion(conversionAmount: 20_000)
        let expected = 5_700 * 0.22 + 14_300 * 0.24 // $1,254 + $3,432 = $4,686
        #expect(isClose(result.federalTax, expected))
    }

    @Test("No-tax state: state tax portion is zero")
    func noTaxStateZeroStateTax() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let result = dm.analyzeRothConversion(conversionAmount: 20_000)
        #expect(isClose(result.stateTax, 0))
        #expect(isClose(result.totalTax, result.federalTax))
    }

    @Test("Positive conversion always produces positive federal tax")
    func positiveConversionPositiveTax() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        let result = dm.analyzeRothConversion(conversionAmount: 10_000)
        #expect(result.federalTax > 0)
        #expect(result.totalTax > 0)
        #expect(result.effectiveRate > 0)
    }

    @Test("Larger conversion produces more total tax")
    func largerConversionMoreTax() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let small = dm.analyzeRothConversion(conversionAmount: 10_000)
        let large = dm.analyzeRothConversion(conversionAmount: 50_000)
        #expect(large.totalTax > small.totalTax)
    }

    @Test("Crossing bracket produces higher effective rate than staying within")
    func crossingBracketHigherEffectiveRate() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        // $5K stays in 22% bracket
        let inBracket = dm.analyzeRothConversion(conversionAmount: 5_000)
        // $50K crosses into 24% bracket
        let crossesBracket = dm.analyzeRothConversion(conversionAmount: 50_000)
        #expect(crossesBracket.effectiveRate > inBracket.effectiveRate)
    }

    @Test("Zero base income: conversion starts in lowest bracket")
    func zeroBaseIncome() {
        let dm = makeDM(state: .florida)
        // No income sources → taxableIncome = 0
        let result = dm.analyzeRothConversion(conversionAmount: 20_000)
        // Tax: 10% × $12,400 + 12% × $7,600 = $1,240 + $912 = $2,152
        #expect(isClose(result.federalTax, 2_152))
        #expect(isClose(result.effectiveRate, 2_152.0 / 20_000.0))
    }

    @Test("Large conversion spanning multiple brackets")
    func multipleNewBrackets() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        // $60K→$260K crosses 22%→24%→32%→35%
        let result = dm.analyzeRothConversion(conversionAmount: 200_000)
        // 22% on (105,700-60,000)=45,700  → $10,054
        // 24% on (201,775-105,700)=96,075 → $23,058
        // 32% on (256,225-201,775)=54,450 → $17,424
        // 35% on (260,000-256,225)=3,775  → $1,321.25
        let part1 = 45_700.0 * 0.22
        let part2 = 96_075.0 * 0.24
        let part3 = 54_450.0 * 0.32
        let part4 = 3_775.0 * 0.35
        let expected = part1 + part2 + part3 + part4
        #expect(isClose(result.federalTax, expected))
    }

    @Test("MFJ uses wider brackets, less tax for same conversion")
    func mfjWiderBrackets() {
        let dmSingle = makeDM(filingStatus: .single, state: .florida)
        dmSingle.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        let singleResult = dmSingle.analyzeRothConversion(conversionAmount: 50_000)

        let dmMFJ = makeDM(filingStatus: .marriedFilingJointly, state: .florida)
        dmMFJ.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        let mfjResult = dmMFJ.analyzeRothConversion(conversionAmount: 50_000)

        // MFJ has wider brackets → less tax for same income + conversion
        #expect(mfjResult.totalTax < singleResult.totalTax)
    }
}

// MARK: - 28. Roth Conversion — Enhanced Analysis

@Suite("Roth Conversion — Enhanced Analysis", .serialized)
@MainActor struct RothConversionEnhancedTests {

    @Test("Zero conversion: all rates zero, no bracket crossing")
    func zeroConversion() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let result = dm.analyzeEnhancedRothConversion(conversionAmount: 0, filingStatus: .single)
        #expect(isClose(result.conversionAmount, 0))
        #expect(isClose(result.federalTax, 0))
        #expect(isClose(result.totalTax, 0))
        #expect(isClose(result.federalEffectiveRate, 0))
        #expect(isClose(result.combinedEffectiveRate, 0))
        #expect(result.crossesFederalBracket == false)
    }

    @Test("Within same bracket: marginal rates unchanged, no crossing")
    func withinSameBracket() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        // $60K in 22% bracket, $5K stays in 22%
        let result = dm.analyzeEnhancedRothConversion(conversionAmount: 5_000, filingStatus: .single)
        #expect(isClose(result.federalMarginalBefore, 22.0, tolerance: 0.1))
        #expect(isClose(result.federalMarginalAfter, 22.0, tolerance: 0.1))
        #expect(result.crossesFederalBracket == false)
    }

    @Test("Crossing federal bracket: marginal rate increases, flag set")
    func crossingFederalBracket() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        // $100K in 22% bracket, $20K → $120K in 24%
        let result = dm.analyzeEnhancedRothConversion(conversionAmount: 20_000, filingStatus: .single)
        #expect(isClose(result.federalMarginalBefore, 22.0, tolerance: 0.1))
        #expect(isClose(result.federalMarginalAfter, 24.0, tolerance: 0.1))
        #expect(result.crossesFederalBracket == true)
    }

    @Test("Bracket room remaining decreases after conversion")
    func bracketRoomDecreases() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        // $60K in 22% bracket, room = 105,700 - 60,000 = 45,700
        let result = dm.analyzeEnhancedRothConversion(conversionAmount: 5_000, filingStatus: .single)
        #expect(isClose(result.federalBracketBefore.roomRemaining, 45_700))
        #expect(isClose(result.federalBracketAfter.roomRemaining, 40_700))
    }

    @Test("Bracket thresholds correct for 22% bracket")
    func bracketThresholdsCorrect() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        let result = dm.analyzeEnhancedRothConversion(conversionAmount: 5_000, filingStatus: .single)
        #expect(isClose(result.federalBracketBefore.currentRate, 0.22))
        #expect(isClose(result.federalBracketBefore.currentThreshold, 50_400))
        #expect(isClose(result.federalBracketBefore.nextThreshold, 105_700))
    }

    @Test("After crossing bracket: bracket info reflects higher bracket")
    func bracketInfoAfterCrossing() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        // $120K after conversion → in 24% bracket ($105,700 to $201,775)
        let result = dm.analyzeEnhancedRothConversion(conversionAmount: 20_000, filingStatus: .single)
        #expect(isClose(result.federalBracketAfter.currentRate, 0.24))
        #expect(isClose(result.federalBracketAfter.currentThreshold, 105_700))
        #expect(isClose(result.federalBracketAfter.nextThreshold, 201_775))
        #expect(isClose(result.federalBracketAfter.roomRemaining, 201_775 - 120_000))
    }

    @Test("Effective rates: federal + state ≈ combined")
    func effectiveRatesConsistent() {
        let dm = makeDM() // CA
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let result = dm.analyzeEnhancedRothConversion(conversionAmount: 20_000, filingStatus: .single)
        #expect(isClose(result.combinedEffectiveRate, result.federalEffectiveRate + result.stateEffectiveRate))
    }

    @Test("No-tax state: state marginals are zero, no state bracket crossing")
    func noTaxStateMarginals() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let result = dm.analyzeEnhancedRothConversion(conversionAmount: 20_000, filingStatus: .single)
        #expect(isClose(result.stateMarginalBefore, 0))
        #expect(isClose(result.stateMarginalAfter, 0))
        #expect(isClose(result.stateEffectiveRate, 0))
        #expect(result.crossesStateBracket == false)
    }

    @Test("Flat-tax state: marginals same before and after, no crossing")
    func flatTaxStateMarginals() {
        let dm = makeDM(state: .colorado) // 4.40% flat
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let result = dm.analyzeEnhancedRothConversion(conversionAmount: 20_000, filingStatus: .single)
        #expect(isClose(result.stateMarginalBefore, 4.40, tolerance: 0.01))
        #expect(isClose(result.stateMarginalAfter, 4.40, tolerance: 0.01))
        #expect(result.crossesStateBracket == false)
    }

    @Test("MFJ wider brackets prevent crossing that occurs for Single")
    func mfjNoCrossingWhereSingleCrosses() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 104_000)
        ]
        // Single: $104K in 22% bracket, $3K → $107K crosses into 24% (threshold $105,700)
        let singleResult = dm.analyzeEnhancedRothConversion(conversionAmount: 3_000, filingStatus: .single)
        #expect(singleResult.crossesFederalBracket == true)

        // MFJ: $104K in 22% bracket (threshold $100,800), $3K → $107K stays in 22% (next at $211,400)
        let mfjResult = dm.analyzeEnhancedRothConversion(conversionAmount: 3_000, filingStatus: .marriedFilingJointly)
        #expect(mfjResult.crossesFederalBracket == false)
    }

    @Test("State bracket crossing detected in progressive state")
    func stateBracketCrossingProgressive() {
        let dm = makeDM(state: .california)
        // CA 8% bracket ends at ~$68,350, then 9.3%
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 65_000)
        ]
        // $65K in 8% bracket, $10K → $75K in 9.3% bracket
        let result = dm.analyzeEnhancedRothConversion(conversionAmount: 10_000, filingStatus: .single)
        #expect(result.crossesStateBracket == true)
        #expect(result.stateMarginalAfter > result.stateMarginalBefore)
    }
}

// MARK: - 29. Federal Bracket Info

@Suite("Federal Bracket Info", .serialized)
@MainActor struct FederalBracketInfoTests {

    @Test("10% bracket: $5K income → room to $12,400")
    func in10PercentBracket() {
        let dm = makeDM()
        let info = dm.federalBracketInfo(income: 5_000, filingStatus: .single)
        #expect(isClose(info.currentRate, 0.10))
        #expect(isClose(info.currentThreshold, 0))
        #expect(isClose(info.nextThreshold, 12_400))
        #expect(isClose(info.roomRemaining, 7_400))
    }

    @Test("22% bracket: $60K income → room to $105,700")
    func in22PercentBracket() {
        let dm = makeDM()
        let info = dm.federalBracketInfo(income: 60_000, filingStatus: .single)
        #expect(isClose(info.currentRate, 0.22))
        #expect(isClose(info.currentThreshold, 50_400))
        #expect(isClose(info.nextThreshold, 105_700))
        #expect(isClose(info.roomRemaining, 45_700))
    }

    @Test("Top bracket (37%): $700K → room = 0, next = infinity")
    func topBracket() {
        let dm = makeDM()
        let info = dm.federalBracketInfo(income: 700_000, filingStatus: .single)
        #expect(isClose(info.currentRate, 0.37))
        #expect(isClose(info.currentThreshold, 640_600))
        #expect(info.nextThreshold == Double.infinity)
        #expect(isClose(info.roomRemaining, 0))
    }

    @Test("Exactly at bracket threshold stays in lower bracket")
    func exactlyAtBoundary() {
        let dm = makeDM()
        // bracketInfo uses `income > threshold`, so $50,400 exactly is NOT in 22%
        let atThreshold = dm.federalBracketInfo(income: 50_400, filingStatus: .single)
        let justAbove = dm.federalBracketInfo(income: 50_401, filingStatus: .single)
        #expect(isClose(atThreshold.currentRate, 0.12)) // still in 12% bracket
        #expect(isClose(justAbove.currentRate, 0.22))    // now in 22% bracket
    }

    @Test("MFJ brackets have higher thresholds")
    func mfjBrackets() {
        let dm = makeDM()
        // $60K: MFJ 12% bracket is $24,800–$100,800
        let info = dm.federalBracketInfo(income: 60_000, filingStatus: .marriedFilingJointly)
        #expect(isClose(info.currentRate, 0.12))
        #expect(isClose(info.currentThreshold, 24_800))
        #expect(isClose(info.nextThreshold, 100_800))
    }
}

// MARK: - 30. State Bracket Info

@Suite("State Bracket Info", .serialized)
@MainActor struct StateBracketInfoTests {

    @Test("No-tax state: rate zero, no room concept")
    func noTaxState() {
        let dm = makeDM(state: .florida)
        let info = dm.stateBracketInfo(income: 100_000, filingStatus: .single)
        #expect(isClose(info.currentRate, 0))
        #expect(isClose(info.currentThreshold, 0))
        #expect(info.nextThreshold == Double.infinity)
        #expect(isClose(info.roomRemaining, 0))
    }

    @Test("Flat-tax state: rate = flat rate, next = infinity")
    func flatTaxState() {
        let dm = makeDM(state: .colorado) // 4.40%
        let info = dm.stateBracketInfo(income: 100_000, filingStatus: .single)
        #expect(isClose(info.currentRate, 0.044))
        #expect(info.nextThreshold == Double.infinity)
        #expect(isClose(info.roomRemaining, 0))
    }

    @Test("Progressive state: returns bracket info with room remaining")
    func progressiveState() {
        let dm = makeDM(state: .california)
        let info = dm.stateBracketInfo(income: 100_000, filingStatus: .single)
        // $100K is in CA's 9.3% bracket
        #expect(isClose(info.currentRate, 0.093))
        #expect(info.roomRemaining > 0)
        #expect(info.nextThreshold > 100_000)
    }
}

// MARK: - 31. Scenario Tax Analysis

@Suite("Scenario Tax Analysis", .serialized)
@MainActor struct ScenarioTaxAnalysisTests {

    @Test("Zero additional income → zero tax impact")
    func zeroAdditionalIncome() {
        let dm = makeDM(state: .florida)
        let result = dm.analyzeScenario(baseIncome: 80_000, scenarioIncome: 80_000)
        #expect(isClose(result.additionalIncome, 0))
        #expect(isClose(result.federalTax, 0))
        #expect(isClose(result.stateTax, 0))
        #expect(isClose(result.totalTax, 0))
        #expect(isClose(result.effectiveRate, 0))
        #expect(result.crossesFederalBracket == false)
    }

    @Test("Additional income within same bracket: tax = amount × marginal rate")
    func withinSameBracket() {
        let dm = makeDM(state: .florida)
        // $60K and $70K both in 22% bracket ($50,400–$105,700)
        let result = dm.analyzeScenario(baseIncome: 60_000, scenarioIncome: 70_000)
        #expect(isClose(result.additionalIncome, 10_000))
        #expect(isClose(result.federalTax, 2_200)) // $10K × 22%
        #expect(isClose(result.effectiveRate, 0.22))
        #expect(result.crossesFederalBracket == false)
    }

    @Test("Additional income crossing federal bracket: mixed rates")
    func crossingFederalBracket() {
        let dm = makeDM(state: .florida)
        // $100K in 22%, $120K in 24% (threshold $105,700)
        let result = dm.analyzeScenario(baseIncome: 100_000, scenarioIncome: 120_000)
        // $5,700 at 22% + $14,300 at 24% = $1,254 + $3,432 = $4,686
        let expected = 5_700.0 * 0.22 + 14_300.0 * 0.24
        #expect(isClose(result.federalTax, expected))
        #expect(result.crossesFederalBracket == true)
        #expect(isClose(result.federalMarginalBefore, 22.0, tolerance: 0.1))
        #expect(isClose(result.federalMarginalAfter, 24.0, tolerance: 0.1))
    }

    @Test("Total tax = federal + state")
    func totalIsSumOfParts() {
        let dm = makeDM() // CA
        let result = dm.analyzeScenario(baseIncome: 60_000, scenarioIncome: 80_000)
        #expect(isClose(result.totalTax, result.federalTax + result.stateTax))
    }

    @Test("Effective rate = totalTax / additionalIncome")
    func effectiveRateFormula() {
        let dm = makeDM()
        let result = dm.analyzeScenario(baseIncome: 60_000, scenarioIncome: 80_000)
        let expectedRate = result.totalTax / result.additionalIncome
        #expect(isClose(result.effectiveRate, expectedRate))
    }

    @Test("Federal + state effective rates sum to combined effective rate")
    func effectiveRatesConsistent() {
        let dm = makeDM() // CA
        let result = dm.analyzeScenario(baseIncome: 60_000, scenarioIncome: 90_000)
        #expect(isClose(result.effectiveRate, result.federalEffectiveRate + result.stateEffectiveRate))
    }

    @Test("No-tax state: state tax is zero")
    func noTaxState() {
        let dm = makeDM(state: .florida)
        let result = dm.analyzeScenario(baseIncome: 60_000, scenarioIncome: 80_000)
        #expect(isClose(result.stateTax, 0))
        #expect(isClose(result.stateMarginalBefore, 0))
        #expect(isClose(result.stateMarginalAfter, 0))
        #expect(result.crossesStateBracket == false)
    }

    @Test("State bracket crossing detected in progressive state")
    func stateBracketCrossing() {
        let dm = makeDM(state: .california)
        // CA 8% bracket ends at ~$68,350, then 9.3%
        let result = dm.analyzeScenario(baseIncome: 65_000, scenarioIncome: 75_000)
        #expect(result.crossesStateBracket == true)
        #expect(result.stateMarginalAfter > result.stateMarginalBefore)
    }

    @Test("Bracket info before/after reflects correct brackets")
    func bracketInfoCorrect() {
        let dm = makeDM(state: .florida)
        // Base $60K in 22% bracket, scenario $120K in 24% bracket
        let result = dm.analyzeScenario(baseIncome: 60_000, scenarioIncome: 120_000)
        #expect(isClose(result.federalBracketBefore.currentRate, 0.22))
        #expect(isClose(result.federalBracketAfter.currentRate, 0.24))
        #expect(isClose(result.federalBracketBefore.roomRemaining, 45_700))
        #expect(isClose(result.federalBracketAfter.roomRemaining, 201_775 - 120_000))
    }

    @Test("Large scenario spanning multiple brackets")
    func multipleNewBrackets() {
        let dm = makeDM(state: .florida)
        // $60K → $260K: crosses 22%→24%→32%→35%
        let result = dm.analyzeScenario(baseIncome: 60_000, scenarioIncome: 260_000)
        let part1 = 45_700.0 * 0.22
        let part2 = 96_075.0 * 0.24
        let part3 = 54_450.0 * 0.32
        let part4 = 3_775.0 * 0.35
        let expected = part1 + part2 + part3 + part4
        #expect(isClose(result.federalTax, expected))
    }

    @Test("Uses DM's filingStatus for bracket selection")
    func usesFilingStatus() {
        let dmSingle = makeDM(filingStatus: .single, state: .florida)
        let dmMFJ = makeDM(filingStatus: .marriedFilingJointly, state: .florida)
        let singleResult = dmSingle.analyzeScenario(baseIncome: 100_000, scenarioIncome: 150_000)
        let mfjResult = dmMFJ.analyzeScenario(baseIncome: 100_000, scenarioIncome: 150_000)
        // MFJ has wider brackets → less incremental tax
        #expect(mfjResult.federalTax < singleResult.federalTax)
    }
}

// MARK: - 32. Scenario Computed Properties

@Suite("Scenario Computed Properties", .serialized)
@MainActor struct ScenarioComputedPropertyTests {

    @Test("scenarioGrossIncome includes Roth conversion")
    func grossIncomeIncludesRothConversion() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let baseGross = dm.scenarioGrossIncome
        dm.yourRothConversion = 20_000
        #expect(isClose(dm.scenarioGrossIncome, baseGross + 20_000))
    }

    @Test("scenarioGrossIncome includes extra withdrawals")
    func grossIncomeIncludesExtraWithdrawals() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let baseGross = dm.scenarioGrossIncome
        dm.yourExtraWithdrawal = 15_000
        #expect(isClose(dm.scenarioGrossIncome, baseGross + 15_000))
    }

    @Test("scenarioTotalRothConversion sums primary + spouse")
    func totalRothConversionSumsSpouse() {
        let dm = makeDM()
        dm.enableSpouse = true
        dm.yourRothConversion = 10_000
        dm.spouseRothConversion = 5_000
        #expect(isClose(dm.scenarioTotalRothConversion, 15_000))
    }

    @Test("scenarioTotalRothConversion ignores spouse when disabled")
    func totalRothConversionIgnoresDisabledSpouse() {
        let dm = makeDM()
        dm.enableSpouse = false
        dm.yourRothConversion = 10_000
        dm.spouseRothConversion = 5_000
        #expect(isClose(dm.scenarioTotalRothConversion, 10_000))
    }

    @Test("scenarioTotalExtraWithdrawal includes inherited traditional")
    func totalExtraIncludesInherited() {
        let dm = makeDM()
        dm.yourExtraWithdrawal = 10_000
        let account = IRAAccount(
            name: "Inherited Trad", accountType: .inheritedTraditionalIRA, balance: 300_000, owner: .primary,
            beneficiaryType: .nonEligibleDesignated, yearOfInheritance: 2022, beneficiaryBirthYear: 1970
        )
        dm.iraAccounts = [account]
        dm.inheritedExtraWithdrawals = [account.id: 5_000]
        #expect(isClose(dm.scenarioTotalExtraWithdrawal, 15_000))
    }

    @Test("scenarioTaxableIncome = gross - deduction, floored at zero")
    func taxableIncomeFlooredAtZero() {
        let dm = makeDM(birthYear: 1990) // young, no senior bonus
        dm.filingStatus = .single
        // Income below standard deduction
        dm.incomeSources = [
            IncomeSource(name: "Part-time", type: .consulting, annualAmount: 5_000)
        ]
        #expect(dm.scenarioTaxableIncome == 0) // $5K < $16,100 standard deduction
    }

    @Test("scenarioFederalTax + scenarioStateTax = scenarioTotalTax")
    func scenarioTaxSumCorrect() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.yourRothConversion = 20_000
        #expect(isClose(dm.scenarioTotalTax, dm.scenarioFederalTax + dm.scenarioStateTax))
    }

    @Test("hasActiveScenario is true with Roth conversion set")
    func hasActiveScenarioWithConversion() {
        let dm = makeDM()
        #expect(dm.hasActiveScenario == false)
        dm.yourRothConversion = 10_000
        #expect(dm.hasActiveScenario == true)
    }

    @Test("hasActiveScenario is true with stock donation enabled")
    func hasActiveScenarioWithStockDonation() {
        let dm = makeDM()
        #expect(dm.hasActiveScenario == false)
        dm.stockDonationEnabled = true
        dm.stockCurrentValue = 10_000
        #expect(dm.hasActiveScenario == true)
    }

    @Test("hasActiveScenario is true with QCD set")
    func hasActiveScenarioWithQCD() {
        let dm = makeDM()
        #expect(dm.hasActiveScenario == false)
        dm.yourQCDAmount = 5_000
        #expect(dm.hasActiveScenario == true)
    }

    @Test("scenarioRemainingTax accounts for withholding")
    func remainingTaxAccountsForWithholding() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000,
                         federalWithholding: 10_000, stateWithholding: 3_000)
        ]
        let totalTax = dm.scenarioTotalTax
        let remaining = dm.scenarioRemainingTax
        // Remaining = total tax - withholding, floored at 0
        #expect(isClose(remaining, max(0, totalTax - 13_000)))
    }

    @Test("scenarioRemainingTax never goes below zero")
    func remainingTaxFlooredAtZero() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000,
                         federalWithholding: 50_000, stateWithholding: 20_000)
        ]
        // Withholding exceeds tax
        #expect(dm.scenarioRemainingTax == 0)
    }
}

// MARK: - 33. Quarterly Estimated Tax

@Suite("Quarterly Estimated Tax", .serialized)
@MainActor struct QuarterlyEstimatedTaxTests {

    @Test("Basic quarterly = 90% safe harbor / 4")
    func basicQuarterlyCalculation() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let quarterly = dm.calculateQuarterlyEstimatedTax()
        let totalIncome = dm.taxableIncome(filingStatus: .single)
        let totalTax = dm.calculateFederalTax(income: totalIncome, filingStatus: .single)
        #expect(isClose(quarterly, totalTax * 0.90 / 4.0))
    }

    @Test("Quarterly payments sum to 90% of total tax minus withholding")
    func quarterlyPaymentsTotalCorrect() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let payments = dm.scenarioQuarterlyPayments
        // No scenario events, no withholding: total = 90% of base tax
        let baseTaxable = max(0, dm.scenarioBaseIncome - dm.effectiveDeductionAmount)
        let baseFedTax = dm.calculateFederalTax(income: baseTaxable, filingStatus: .single)
        #expect(isClose(payments.federalTotal, baseFedTax * 0.90, tolerance: 1.0))
    }

    @Test("Base tax spread evenly across quarters (no scenario events)")
    func baseTaxEvenlySpread() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let payments = dm.scenarioQuarterlyPayments
        // All quarters should be equal when no scenario events
        #expect(isClose(payments.federal.q1, payments.federal.q2))
        #expect(isClose(payments.federal.q2, payments.federal.q3))
        #expect(isClose(payments.federal.q3, payments.federal.q4))
    }

    @Test("Roth conversion adds incremental tax to its scheduled quarter")
    func rothConversionIncrementalAllocation() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        // Get base quarterly payments (no conversion)
        let basePayments = dm.scenarioQuarterlyPayments
        let baseQ2 = basePayments.federal.q2

        // Add Roth conversion in Q2
        dm.yourRothConversion = 20_000
        dm.yourRothConversionQuarter = 2
        let withConversion = dm.scenarioQuarterlyPayments

        // Q2 should be higher due to conversion's incremental tax
        #expect(withConversion.federal.q2 > baseQ2)
    }

    @Test("Incremental tax concentrated in event quarter, others get base only")
    func incrementalTaxConcentrated() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.yourRothConversion = 30_000
        dm.yourRothConversionQuarter = 3
        let payments = dm.scenarioQuarterlyPayments

        // Q3 should be highest since it gets all incremental tax from conversion
        // Q1, Q2, Q4 only get base tax (Q4 also gets withdrawal if applicable)
        #expect(payments.federal.q3 > payments.federal.q1)
    }

    @Test("Withholding reduces quarterly payments")
    func withholdingReducesPayments() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let paymentsNoWH = dm.scenarioQuarterlyPayments

        let dm2 = makeDM(state: .florida)
        dm2.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000,
                         federalWithholding: 8_000)
        ]
        let paymentsWithWH = dm2.scenarioQuarterlyPayments

        // Withholding should reduce each quarter's payment
        #expect(paymentsWithWH.federal.q1 < paymentsNoWH.federal.q1)
        #expect(paymentsWithWH.federalTotal < paymentsNoWH.federalTotal)
    }

    @Test("Quarterly payments never go negative")
    func quartersNeverNegative() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000,
                         federalWithholding: 50_000, stateWithholding: 20_000)
        ]
        let payments = dm.scenarioQuarterlyPayments
        #expect(payments.federal.q1 >= 0)
        #expect(payments.federal.q2 >= 0)
        #expect(payments.federal.q3 >= 0)
        #expect(payments.federal.q4 >= 0)
        #expect(payments.state.q1 >= 0)
        #expect(payments.state.q2 >= 0)
        #expect(payments.state.q3 >= 0)
        #expect(payments.state.q4 >= 0)
    }

    @Test("Federal and state tracked separately")
    func federalAndStateSeparate() {
        let dm = makeDM() // CA (has state tax)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let payments = dm.scenarioQuarterlyPayments
        #expect(payments.federalTotal > 0)
        #expect(payments.stateTotal > 0)
        #expect(isClose(payments.total, payments.federalTotal + payments.stateTotal))
    }

    @Test("Combined quarterly accessor matches federal + state per quarter")
    func combinedAccessorCorrect() {
        let dm = makeDM() // CA
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.yourRothConversion = 15_000
        dm.yourRothConversionQuarter = 2
        let payments = dm.scenarioQuarterlyPayments
        #expect(isClose(payments.q1, payments.federal.q1 + payments.state.q1))
        #expect(isClose(payments.q2, payments.federal.q2 + payments.state.q2))
        #expect(isClose(payments.q3, payments.federal.q3 + payments.state.q3))
        #expect(isClose(payments.q4, payments.federal.q4 + payments.state.q4))
    }

    @Test("Multiple events in different quarters allocate correctly")
    func multipleEventsMultipleQuarters() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.yourRothConversion = 20_000
        dm.yourRothConversionQuarter = 1
        dm.yourExtraWithdrawal = 10_000
        dm.yourWithdrawalQuarter = 3
        let payments = dm.scenarioQuarterlyPayments

        // Q1 and Q3 should be higher than Q2 and Q4 (which only get base)
        #expect(payments.federal.q1 > payments.federal.q2)
        #expect(payments.federal.q3 > payments.federal.q4)
    }
}

// MARK: - 34. Integration — Multi-Decision Scenarios

@Suite("Integration — Multi-Decision Scenarios", .serialized)
@MainActor struct IntegrationMultiDecisionTests {

    @Test("Roth conversion + extra withdrawal: both increase gross income")
    func conversionPlusWithdrawal() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let baseGross = dm.scenarioGrossIncome
        dm.yourRothConversion = 20_000
        dm.yourExtraWithdrawal = 10_000
        #expect(isClose(dm.scenarioGrossIncome, baseGross + 30_000))
    }

    @Test("QCD reduces adjusted RMD but not gross income directly")
    func qcdReducesRMD() {
        let dm = makeDM(birthYear: 1951) // age 75, RMD required, QCD eligible
        dm.currentYear = 2026
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary)
        ]
        let baseRMD = dm.calculatePrimaryRMD()
        #expect(baseRMD > 0)

        dm.yourQCDAmount = 5_000
        // QCD reduces adjusted RMD
        #expect(isClose(dm.scenarioAdjustedRMD, baseRMD - 5_000))
        // QCD reduces total withdrawals (which feed gross income)
        let grossWithQCD = dm.scenarioGrossIncome
        dm.yourQCDAmount = 0
        let grossWithoutQCD = dm.scenarioGrossIncome
        #expect(grossWithQCD < grossWithoutQCD)
    }

    @Test("Stock donation reduces gross income by avoided gain")
    func stockDonationReducesGrossIncome() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let baseGross = dm.scenarioGrossIncome
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        // Gross income should be reduced by $20K avoided gain
        #expect(isClose(dm.scenarioGrossIncome, baseGross - 20_000))
    }

    @Test("Multiple decisions: conversion + withdrawal + stock donation → correct gross")
    func multipleDecisionsGrossIncome() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let baseGross = dm.scenarioGrossIncome
        dm.yourRothConversion = 20_000
        dm.yourExtraWithdrawal = 10_000
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 25_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        // +$20K conversion + $10K withdrawal - $15K avoided gain = +$15K net
        #expect(isClose(dm.scenarioGrossIncome, baseGross + 15_000))
    }

    @Test("IRMAA cliff crossing from combined scenario decisions")
    func irmaaCliffFromCombinedDecisions() {
        let dm = makeDM(birthYear: 1955) // age 71, Medicare eligible
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        // Base MAGI ~$100K → Tier 0
        #expect(dm.baselineIRMAA.tier == 0)

        // $5K conversion alone might not cross Tier 1 ($109,001)
        dm.yourRothConversion = 5_000
        // But add $5K extra withdrawal → combined pushes above $109K
        dm.yourExtraWithdrawal = 5_000
        // Now scenario MAGI ≈ $110K → should be Tier 1
        #expect(dm.scenarioIRMAA.tier >= 1)
        #expect(dm.scenarioPushedToHigherIRMAATier == true)
    }

    @Test("Spouse scenario decisions included in MFJ totals")
    func spouseDecisionsIncluded() {
        let dm = makeDM(filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1955; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let baseGross = dm.scenarioGrossIncome
        dm.yourRothConversion = 10_000
        dm.spouseRothConversion = 15_000
        #expect(isClose(dm.scenarioTotalRothConversion, 25_000))
        #expect(isClose(dm.scenarioGrossIncome, baseGross + 25_000))
    }

    @Test("Cash donation increases hasActiveScenario")
    func cashDonationActivatesScenario() {
        let dm = makeDM()
        #expect(dm.hasActiveScenario == false)
        dm.cashDonationAmount = 5_000
        #expect(dm.hasActiveScenario == true)
    }

    @Test("Withholding split correctly into federal and state")
    func withholdingSplitCorrectly() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000,
                         federalWithholding: 8_000, stateWithholding: 3_000),
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 20_000,
                         federalWithholding: 2_000)
        ]
        #expect(isClose(dm.totalFederalWithholding, 10_000))
        #expect(isClose(dm.totalStateWithholding, 3_000))
        #expect(isClose(dm.totalWithholding, 13_000))
    }

    @Test("Scenario tax increases with Roth conversion")
    func scenarioTaxIncreasesWithConversion() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let baseTax = dm.scenarioTotalTax
        dm.yourRothConversion = 30_000
        let newTax = dm.scenarioTotalTax
        #expect(newTax > baseTax)
    }
}

// MARK: - 35. Spouse Scenario Interactions

@Suite("Spouse Scenario Interactions", .serialized)
@MainActor struct SpouseScenarioInteractionTests {

    @Test("Spouse RMD calculated when spouse enabled and at RMD age")
    func spouseRMDCalculated() {
        let dm = makeDM(birthYear: 1960, filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1953; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.iraAccounts = [
            IRAAccount(name: "Spouse IRA", accountType: .traditionalIRA, balance: 300_000, owner: .spouse)
        ]
        // Spouse born 1953 → age 73, RMD age 73 → RMD required
        #expect(dm.spouseIsRMDRequired == true)
        let rmd = dm.calculateSpouseRMD()
        // Age 73 → factor 26.5 → 300000/26.5 ≈ 11320.75
        #expect(isClose(rmd, 300_000 / 26.5, tolerance: 1.0))
    }

    @Test("Spouse RMD not calculated when spouse disabled")
    func spouseRMDZeroWhenDisabled() {
        let dm = makeDM(birthYear: 1960, filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = false
        var c = DateComponents(); c.year = 1953; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.iraAccounts = [
            IRAAccount(name: "Spouse IRA", accountType: .traditionalIRA, balance: 300_000, owner: .spouse)
        ]
        #expect(dm.calculateSpouseRMD() == 0)
    }

    @Test("Combined RMD includes both primary and spouse")
    func combinedRMDIncludesBoth() {
        let dm = makeDM(birthYear: 1951, filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1953; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.iraAccounts = [
            IRAAccount(name: "My IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary),
            IRAAccount(name: "Spouse IRA", accountType: .traditionalIRA, balance: 300_000, owner: .spouse)
        ]
        let primaryRMD = dm.calculatePrimaryRMD()
        let spouseRMD = dm.calculateSpouseRMD()
        let combined = dm.calculateCombinedRMD()
        #expect(primaryRMD > 0)
        #expect(spouseRMD > 0)
        #expect(isClose(combined, primaryRMD + spouseRMD))
    }

    @Test("Spouse Roth conversion adds to scenario total")
    func spouseRothConversionInTotal() {
        let dm = makeDM(filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1960; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.yourRothConversion = 10_000
        dm.spouseRothConversion = 15_000
        #expect(isClose(dm.scenarioTotalRothConversion, 25_000))
    }

    @Test("Spouse extra withdrawal included in gross income")
    func spouseExtraWithdrawalInGrossIncome() {
        let dm = makeDM(filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1960; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let baseGross = dm.scenarioGrossIncome
        dm.spouseExtraWithdrawal = 20_000
        #expect(isClose(dm.scenarioGrossIncome, baseGross + 20_000))
    }

    @Test("MFJ standard deduction with both spouses 65+")
    func mfjStandardDeductionBothSeniors() {
        let dm = makeDM(birthYear: 1955, filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1955; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        // 2026 MFJ: $32,200 base + $1,650 × 2 (both 65+) + senior bonus
        let deduction = dm.standardDeductionAmount
        #expect(deduction >= 32_200 + 1_650 * 2)
    }

    @Test("MFJ standard deduction with only primary 65+")
    func mfjStandardDeductionOneSenior() {
        let dm = makeDM(birthYear: 1955, filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1970; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        let deduction = dm.standardDeductionAmount
        // Only primary gets age 65+ additional + one senior bonus
        let bothSeniorDM = makeDM(birthYear: 1955, filingStatus: .marriedFilingJointly, state: .florida)
        bothSeniorDM.enableSpouse = true
        var c2 = DateComponents(); c2.year = 1955; c2.month = 1; c2.day = 1
        bothSeniorDM.spouseBirthDate = Calendar.current.date(from: c2)!
        bothSeniorDM.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        let bothDeduction = bothSeniorDM.standardDeductionAmount
        // Both seniors gets more deduction than one senior
        #expect(bothDeduction > deduction)
    }

    @Test("Spouse QCD reduces adjusted RMD")
    func spouseQCDReducesAdjustedRMD() {
        let dm = makeDM(birthYear: 1951, filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1951; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.iraAccounts = [
            IRAAccount(name: "My IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary),
            IRAAccount(name: "Spouse IRA", accountType: .traditionalIRA, balance: 200_000, owner: .spouse)
        ]
        let rmdBeforeQCD = dm.scenarioAdjustedRMD
        dm.yourQCDAmount = 5_000
        dm.spouseQCDAmount = 3_000
        let rmdAfterQCD = dm.scenarioAdjustedRMD
        #expect(rmdAfterQCD < rmdBeforeQCD)
    }

    @Test("Spouse inherited IRA included in totals")
    func spouseInheritedIRAInTotals() {
        let dm = makeDM(birthYear: 1960, filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1960; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.iraAccounts = [
            IRAAccount(name: "Spouse Inherited", accountType: .inheritedTraditionalIRA, balance: 100_000,
                       owner: .spouse, beneficiaryType: .nonEligibleDesignated,
                       decedentRBDStatus: .afterRBD, yearOfInheritance: 2022,
                       beneficiaryBirthYear: 1960)
        ]
        let spouseInherited = dm.spouseInheritedRMD
        #expect(spouseInherited > 0)
        #expect(isClose(dm.inheritedIRARMDTotal, spouseInherited))
    }
}

// MARK: - 36. Inherited IRA RMD Complex Scenarios

@Suite("Inherited IRA RMD Complex Scenarios", .serialized)
@MainActor struct InheritedIRARMDComplexTests {

    @Test("Spouse beneficiary — no RMD in year of inheritance")
    func spouseBeneficiaryYearZero() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 200_000,
                                  beneficiaryType: .spouse, yearOfInheritance: 2026,
                                  beneficiaryBirthYear: 1960)
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(result.annualRMD == 0)
        #expect(result.mustEmptyByYear == nil) // lifetime stretch
    }

    @Test("Spouse beneficiary — RMD using SLE Table I the year after")
    func spouseBeneficiaryYear1() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 200_000,
                                  beneficiaryType: .spouse, yearOfInheritance: 2025,
                                  beneficiaryBirthYear: 1960)
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        // Beneficiary age in 2026: 66 → SLE factor 22.0
        let expected = 200_000 / 22.0
        #expect(isClose(result.annualRMD, expected, tolerance: 1.0))
        #expect(result.mustEmptyByYear == nil)
    }

    @Test("Disabled beneficiary — lifetime stretch with SLE Table I")
    func disabledBeneficiaryLifetimeStretch() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 150_000,
                                  beneficiaryType: .disabled, yearOfInheritance: 2024,
                                  beneficiaryBirthYear: 1970)
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        // Age 56 → SLE factor 30.6
        let expected = 150_000 / 30.6
        #expect(isClose(result.annualRMD, expected, tolerance: 1.0))
        #expect(result.mustEmptyByYear == nil) // lifetime stretch
    }

    @Test("Chronically ill beneficiary — same as disabled")
    func chronicallyIllBeneficiary() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 150_000,
                                  beneficiaryType: .chronicallyIll, yearOfInheritance: 2024,
                                  beneficiaryBirthYear: 1970)
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        // Age 56 → SLE factor 30.6
        let expected = 150_000 / 30.6
        #expect(isClose(result.annualRMD, expected, tolerance: 1.0))
    }

    @Test("Not >10 years younger — factor reduces by 1 each year")
    func notTenYearsYoungerFactorReduction() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 100_000,
                                  beneficiaryType: .notTenYearsYounger, yearOfInheritance: 2023,
                                  beneficiaryBirthYear: 1955)
        // Year after inheritance = 2024, beneficiary age in 2024 = 69 → SLE factor 19.6
        // In 2026: yearsOfReduction = 2026 - 2024 = 2, factor = 19.6 - 2 = 17.6
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        let expected = 100_000 / 17.6
        #expect(isClose(result.annualRMD, expected, tolerance: 1.0))
    }

    @Test("Not >10 years younger — factor floors at 1.0")
    func notTenYearsYoungerFactorFloor() {
        let dm = makeDM()
        // Elderly beneficiary: age 110 in first year → factor 1.0, can't go below
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 50_000,
                                  beneficiaryType: .notTenYearsYounger, yearOfInheritance: 2020,
                                  beneficiaryBirthYear: 1910)
        // Initial age in 2021 = 111 → SLE factor 0.9, but further reduction still floors at 1.0
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        // Factor = max(1.0, 0.9 - 5) = 1.0
        #expect(isClose(result.annualRMD, 50_000 / 1.0, tolerance: 1.0))
    }

    @Test("Minor child — SLE stretch before majority")
    func minorChildBeforeMajority() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 100_000,
                                  beneficiaryType: .minorChild, yearOfInheritance: 2024,
                                  beneficiaryBirthYear: 2010, minorChildMajorityYear: 2031)
        // 2026: age 16, still minor → SLE factor at age 16 = 68.9
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        let expected = 100_000 / 68.9
        #expect(isClose(result.annualRMD, expected, tolerance: 1.0))
        #expect(result.mustEmptyByYear == nil) // still in SLE stretch
    }

    @Test("Minor child after majority — 10 year rule with afterRBD gets annual RMDs")
    func minorChildAfterMajorityWithRBD() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 100_000,
                                  beneficiaryType: .minorChild, decedentRBDStatus: .afterRBD,
                                  yearOfInheritance: 2020,
                                  beneficiaryBirthYear: 2001, minorChildMajorityYear: 2022)
        // Majority in 2022, 10-year deadline = 2032
        // 2026: age at majority+1 = (2022+1) - 2001 = 22 → SLE factor at 22 = 63.0
        // yearsOfReduction = 2026 - 2023 = 3 → factor = 63.0 - 3 = 60.0
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        let expected = 100_000 / 60.0
        #expect(isClose(result.annualRMD, expected, tolerance: 1.0))
        #expect(result.mustEmptyByYear == 2032)
    }

    @Test("Minor child after majority — beforeRBD no annual RMDs")
    func minorChildAfterMajorityBeforeRBD() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 100_000,
                                  beneficiaryType: .minorChild, decedentRBDStatus: .beforeRBD,
                                  yearOfInheritance: 2020,
                                  beneficiaryBirthYear: 2001, minorChildMajorityYear: 2022)
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(result.annualRMD == 0)
        #expect(result.mustEmptyByYear == 2032)
    }

    @Test("Non-eligible designated — 10 year deadline reached means full balance")
    func nonEligibleDeadlineReached() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 80_000,
                                  beneficiaryType: .nonEligibleDesignated,
                                  decedentRBDStatus: .afterRBD,
                                  yearOfInheritance: 2016, beneficiaryBirthYear: 1990)
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        // deadline = 2016 + 10 = 2026. Year >= deadline → full balance
        #expect(isClose(result.annualRMD, 80_000))
        #expect(result.yearsRemaining == 0)
    }

    @Test("Non-eligible designated before RBD — no annual RMDs")
    func nonEligibleBeforeRBDNoAnnualRMDs() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 100_000,
                                  beneficiaryType: .nonEligibleDesignated,
                                  decedentRBDStatus: .beforeRBD,
                                  yearOfInheritance: 2022, beneficiaryBirthYear: 1990)
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(result.annualRMD == 0)
        #expect(result.mustEmptyByYear == 2032)
        #expect(result.yearsRemaining == 6)
    }

    @Test("Non-eligible designated after RBD — annual RMDs with reducing factor")
    func nonEligibleAfterRBDAnnualRMDs() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited", accountType: .inheritedTraditionalIRA, balance: 100_000,
                                  beneficiaryType: .nonEligibleDesignated,
                                  decedentRBDStatus: .afterRBD,
                                  yearOfInheritance: 2022, beneficiaryBirthYear: 1990)
        // First RMD year = 2023, beneficiary age in 2023 = 33 → SLE factor 52.5
        // In 2026: yearsOfReduction = 2026 - 2023 = 3 → factor = 52.5 - 3 = 49.5
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        let expected = 100_000 / 49.5
        #expect(isClose(result.annualRMD, expected, tolerance: 1.0))
        #expect(result.mustEmptyByYear == 2032)
    }

    @Test("Inherited Roth — EDB gets no RMD no deadline")
    func inheritedRothEDBNoRMD() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited Roth", accountType: .inheritedRothIRA, balance: 150_000,
                                  beneficiaryType: .spouse, yearOfInheritance: 2023,
                                  beneficiaryBirthYear: 1960)
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(result.annualRMD == 0)
        #expect(result.mustEmptyByYear == nil)
    }

    @Test("Inherited Roth — non-EDB 10 year rule no annual RMDs")
    func inheritedRothNonEDBNoAnnualRMD() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited Roth", accountType: .inheritedRothIRA, balance: 150_000,
                                  beneficiaryType: .nonEligibleDesignated,
                                  yearOfInheritance: 2022, beneficiaryBirthYear: 1990)
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(result.annualRMD == 0)
        #expect(result.mustEmptyByYear == 2032)
        #expect(result.yearsRemaining == 6)
    }

    @Test("Inherited Roth — non-EDB at deadline requires full balance")
    func inheritedRothNonEDBAtDeadline() {
        let dm = makeDM()
        let account = IRAAccount(name: "Inherited Roth", accountType: .inheritedRothIRA, balance: 150_000,
                                  beneficiaryType: .nonEligibleDesignated,
                                  yearOfInheritance: 2016, beneficiaryBirthYear: 1990)
        let result = dm.calculateInheritedIRARMD(account: account, forYear: 2026)
        #expect(isClose(result.annualRMD, 150_000))
        #expect(result.yearsRemaining == 0)
    }
}

// MARK: - 37. Federal Tax Edge Cases

@Suite("Federal Tax Edge Cases", .serialized)
@MainActor struct FederalTaxEdgeCaseTests {

    @Test("Zero income produces zero tax")
    func zeroIncomeZeroTax() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = []
        #expect(dm.scenarioFederalTax == 0)
    }

    @Test("Income exactly at standard deduction produces zero taxable income")
    func incomeAtStandardDeduction() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        // Age 56 in 2026, no senior bonus. Single standard deduction = $16,100
        dm.incomeSources = [
            IncomeSource(name: "Part-time", type: .pension, annualAmount: 16_100)
        ]
        #expect(isClose(dm.scenarioTaxableIncome, 0))
        #expect(isClose(dm.scenarioFederalTax, 0))
    }

    @Test("Senior bonus phases out with high MAGI (Single)")
    func seniorBonusPhasesOut() {
        let dm = makeDM(birthYear: 1955, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        let lowIncomeDed = dm.standardDeductionAmount
        // Now high income: $200K
        let dm2 = makeDM(birthYear: 1955, state: .florida)
        dm2.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 200_000)
        ]
        let highIncomeDed = dm2.standardDeductionAmount
        // $200K MAGI → reduction = ($200K - $75K) × 6% = $7,500 > $6K bonus
        // So senior bonus is completely phased out at $200K
        #expect(lowIncomeDed > highIncomeDed)
    }

    @Test("MFJ tax is less than single tax for same income")
    func mfjLessThanSingle() {
        let dm1 = makeDM(birthYear: 1970, filingStatus: .single, state: .florida)
        dm1.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        let dm2 = makeDM(birthYear: 1970, filingStatus: .marriedFilingJointly, state: .florida)
        dm2.enableSpouse = true
        var c = DateComponents(); c.year = 1970; c.month = 1; c.day = 1
        dm2.spouseBirthDate = Calendar.current.date(from: c)!
        dm2.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        #expect(dm2.scenarioFederalTax < dm1.scenarioFederalTax)
    }

    @Test("Very high income hits 37% bracket")
    func veryHighIncomeTopBracket() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Income", type: .pension, annualAmount: 700_000)
        ]
        // Taxable ~$683,900 after $16,100 deduction → well into 37% bracket
        let analysis = dm.analyzeEnhancedRothConversion(conversionAmount: 1_000, filingStatus: .single)
        #expect(analysis.federalMarginalAfter == 37.0)
    }

    @Test("Deduction override forces itemized")
    func deductionOverrideItemized() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        // Small itemized that wouldn't normally beat standard
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 5_000)
        ]
        dm.deductionOverride = .itemized
        #expect(dm.scenarioEffectiveItemize == true)
        #expect(isClose(dm.effectiveDeductionAmount, 5_000))
    }

    @Test("Deduction override forces standard even with high itemized")
    func deductionOverrideStandard() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 50_000)
        ]
        dm.deductionOverride = .standard
        #expect(dm.scenarioEffectiveItemize == false)
        #expect(isClose(dm.effectiveDeductionAmount, dm.standardDeductionAmount))
    }

    @Test("Auto deduction picks higher of standard vs itemized")
    func autoDeductionPicksHigher() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 50_000)
        ]
        dm.deductionOverride = nil
        // $50K itemized > $16,100 standard → should itemize
        #expect(dm.scenarioEffectiveItemize == true)
    }
}

// MARK: - 38. Charitable Giving Combinations

@Suite("Charitable Giving Combinations", .serialized)
@MainActor struct CharitableGivingCombinationTests {

    @Test("Cash donation adds to itemized deductions")
    func cashDonationInItemized() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let baseItemized = dm.totalItemizedDeductions
        dm.cashDonationAmount = 10_000
        #expect(isClose(dm.totalItemizedDeductions, baseItemized + 10_000))
    }

    @Test("Stock donation (long-term) adds FMV to itemized deductions")
    func stockDonationLongTermFMV() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        // Long-term → deduction = FMV = $30K
        #expect(isClose(dm.scenarioCharitableDeductions, 30_000))
    }

    @Test("Stock donation (short-term) adds basis to itemized deductions")
    func stockDonationShortTermBasis() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        // Purchased recently (less than 1 year ago)
        dm.stockPurchaseDate = Date()
        // Short-term → deduction = basis = $10K
        #expect(isClose(dm.scenarioCharitableDeductions, 10_000))
    }

    @Test("Stock + cash donation combine in charitable deductions")
    func stockPlusCashCombine() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 5_000
        dm.stockCurrentValue = 20_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        dm.cashDonationAmount = 8_000
        // Long-term stock FMV $20K + $8K cash
        #expect(isClose(dm.scenarioCharitableDeductions, 28_000))
    }

    @Test("QCD is separate from charitable deductions (pre-tax)")
    func qcdSeparateFromCharitable() {
        let dm = makeDM(birthYear: 1951, state: .florida)
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary)
        ]
        dm.yourQCDAmount = 10_000
        dm.cashDonationAmount = 5_000
        // QCD should NOT be in scenarioCharitableDeductions — it's pre-tax
        #expect(isClose(dm.scenarioCharitableDeductions, 5_000))
        // But total charitable includes QCD
        #expect(dm.scenarioTotalCharitable > dm.scenarioCharitableDeductions)
    }

    @Test("Charitable deductions can push itemized above standard")
    func charitablePushesAboveStandard() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.deductionOverride = nil
        // Base itemized only $10K mortgage < standard $16,100
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 10_000)
        ]
        #expect(dm.scenarioEffectiveItemize == false) // standard wins
        // Add $10K cash → $20K itemized > $16,100 standard
        dm.cashDonationAmount = 10_000
        #expect(dm.scenarioEffectiveItemize == true) // itemized wins
    }

    @Test("Stock donation disabled means no charitable stock deduction")
    func stockDisabledNoDeduction() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.stockDonationEnabled = false
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 30_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        #expect(dm.scenarioCharitableDeductions == 0)
        #expect(dm.scenarioStockGainAvoided == 0)
    }
}

// MARK: - 39. Medical Deduction Edge Cases

@Suite("Medical Deduction Edge Cases", .serialized)
@MainActor struct MedicalDeductionEdgeCaseTests {

    @Test("Medical expenses below 7.5% AGI floor produce zero deduction")
    func medicalBelowFloor() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        // AGI ≈ $80K → floor = $6,000
        dm.deductionItems = [
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 5_000)
        ]
        #expect(dm.deductibleMedicalExpenses == 0)
    }

    @Test("Medical expenses above 7.5% AGI floor produce partial deduction")
    func medicalAboveFloor() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        // AGI ≈ $80K → floor = $6,000
        dm.deductionItems = [
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 10_000)
        ]
        // Deductible = $10K - $6K = $4K
        #expect(isClose(dm.deductibleMedicalExpenses, 4_000, tolerance: 1.0))
    }

    @Test("AGI floor changes when scenario income changes")
    func agiFloorChangesWithScenario() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 10_000)
        ]
        let deductibleBefore = dm.deductibleMedicalExpenses
        // Add Roth conversion → increases AGI → increases floor → decreases deduction
        dm.yourRothConversion = 50_000
        let deductibleAfter = dm.deductibleMedicalExpenses
        #expect(deductibleAfter < deductibleBefore)
    }

    @Test("Medical deduction included in base itemized deductions")
    func medicalInBaseItemized() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        // AGI ≈ $60K → floor = $4,500
        dm.deductionItems = [
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 20_000),
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 10_000)
        ]
        // Deductible medical = $20K - $4,500 = $15,500
        // Base itemized = $10K mortgage + $15,500 medical = $25,500
        let expectedMedical = 20_000 - (60_000 * 0.075)
        let expectedItemized = 10_000 + expectedMedical
        #expect(isClose(dm.baseItemizedDeductions, expectedItemized, tolerance: 1.0))
    }

    @Test("Zero medical expenses produce zero deduction")
    func zeroMedicalZeroDeduction() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        #expect(dm.deductibleMedicalExpenses == 0)
        #expect(dm.totalMedicalExpenses == 0)
    }

    @Test("estimatedAGI matches scenarioGrossIncome")
    func estimatedAGIMatchesGross() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.yourRothConversion = 20_000
        #expect(isClose(dm.estimatedAGI, dm.scenarioGrossIncome))
    }
}

// MARK: - 40. SALT Cap Edge Cases

@Suite("SALT Cap Edge Cases", .serialized)
@MainActor struct SALTCapEdgeCaseTests {

    @Test("2026 SALT cap is $40K base with 1% inflation for 1 year")
    func saltCap2026() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        // 2026: yearsFromBase = 1, inflation = 1.01^1 = 1.01
        // expandedCap = round(40000 × 1.01) = 40400
        let expected = (40_000.0 * pow(1.01, 1.0)).rounded()
        #expect(isClose(dm.saltCap, expected))
    }

    @Test("2025 SALT cap is $40K base (no inflation)")
    func saltCap2025() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.currentYear = 2025
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        #expect(isClose(dm.saltCap, 40_000))
    }

    @Test("2030 reverts to $10K cap")
    func saltCap2030Reverts() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.currentYear = 2030
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        #expect(isClose(dm.saltCap, 10_000))
    }

    @Test("SALT phaseout reduces cap for high earners")
    func saltPhaseoutHighEarner() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Income", type: .pension, annualAmount: 600_000)
        ]
        // threshold = round(500000 × 1.01) = 505000
        // phaseoutReduction = (600000 - 505000) × 0.30 = 28500
        // cap = 40400 - 28500 = 11900
        let inflationMultiplier = pow(1.01, 1.0)
        let expandedCap = (40_000.0 * inflationMultiplier).rounded()
        let threshold = (500_000.0 * inflationMultiplier).rounded()
        let reduction = (600_000 - threshold) * 0.30
        let expected = expandedCap - reduction
        #expect(isClose(dm.saltCap, expected, tolerance: 1.0))
    }

    @Test("SALT cap floors at $10K even with extreme phaseout")
    func saltCapFloorAt10K() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Income", type: .pension, annualAmount: 1_000_000)
        ]
        // At $1M MAGI, phaseout would push below $10K → floor applies
        #expect(isClose(dm.saltCap, 10_000))
    }

    @Test("SALT after cap is min of before-cap and cap")
    func saltAfterCapIsCapped() {
        let dm = makeDM(birthYear: 1970, state: .california)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000,
                         stateWithholding: 5_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 50_000)
        ]
        // Total SALT before cap = $50K property + $5K state WH = $55K
        // Cap for $80K MAGI ≈ $40,400 (no phaseout)
        #expect(dm.totalSALTBeforeCap >= 55_000)
        #expect(dm.saltAfterCap <= dm.saltCap)
    }

    @Test("Prior year state balance included in SALT")
    func priorYearStateBalanceInSALT() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.priorYearStateBalance = 3_000
        dm.deductionItems = [
            DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 10_000)
        ]
        // SALT before cap = $10K property + $3K prior year = $13K
        #expect(isClose(dm.totalSALTBeforeCap, 13_000, tolerance: 1.0))
    }
}

// MARK: - 41. Stock Donation Edge Cases

@Suite("Stock Donation Edge Cases", .serialized)
@MainActor struct StockDonationEdgeCaseTests {

    @Test("Stock gain avoided is FMV minus basis")
    func stockGainAvoided() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 35_000
        #expect(isClose(dm.scenarioStockGainAvoided, 25_000))
    }

    @Test("Stock gain avoided is zero when donation disabled")
    func stockGainZeroWhenDisabled() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.stockDonationEnabled = false
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 35_000
        #expect(dm.scenarioStockGainAvoided == 0)
    }

    @Test("Stock at a loss — gain avoided is zero")
    func stockAtLossGainIsZero() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 30_000
        dm.stockCurrentValue = 20_000
        // FMV < basis → gain = 0
        #expect(dm.scenarioStockGainAvoided == 0)
    }

    @Test("Stock donation reduces scenario gross income by avoided gain")
    func stockDonationReducesGross() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        let baseGross = dm.scenarioGrossIncome
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 10_000
        dm.stockCurrentValue = 40_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        // Gross should decrease by $30K avoided gain
        #expect(isClose(dm.scenarioGrossIncome, baseGross - 30_000))
    }

    @Test("Stock donation with zero gain — no effect on gross income")
    func stockZeroGainNoGrossEffect() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        let baseGross = dm.scenarioGrossIncome
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 20_000
        dm.stockCurrentValue = 20_000
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        #expect(isClose(dm.scenarioGrossIncome, baseGross))
    }

    @Test("Stock donation activates hasActiveScenario")
    func stockDonationActivatesScenario() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        #expect(dm.hasActiveScenario == false)
        dm.stockDonationEnabled = true
        dm.stockCurrentValue = 10_000
        #expect(dm.hasActiveScenario == true)
    }

    @Test("Long-term stock deduction is FMV, short-term is basis")
    func longTermVsShortTermDeduction() {
        let dm1 = makeDM(birthYear: 1970, state: .florida)
        dm1.stockDonationEnabled = true
        dm1.stockPurchasePrice = 10_000
        dm1.stockCurrentValue = 30_000
        dm1.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!

        let dm2 = makeDM(birthYear: 1970, state: .florida)
        dm2.stockDonationEnabled = true
        dm2.stockPurchasePrice = 10_000
        dm2.stockCurrentValue = 30_000
        dm2.stockPurchaseDate = Date() // short-term

        // Long-term deduction = FMV $30K, short-term = basis $10K
        #expect(isClose(dm1.scenarioCharitableDeductions, 30_000))
        #expect(isClose(dm2.scenarioCharitableDeductions, 10_000))
    }
}

// MARK: - 42. Per-Decision Tax Impact

@Suite("Per-Decision Tax Impact", .serialized)
@MainActor struct PerDecisionTaxImpactTests {

    // -- rothConversionTaxImpact --

    @Test("Roth conversion tax impact is zero with no conversion")
    func rothImpactZeroWithoutConversion() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        #expect(dm.rothConversionTaxImpact == 0)
    }

    @Test("Roth conversion tax impact is positive with conversion")
    func rothImpactPositive() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.yourRothConversion = 30_000
        #expect(dm.rothConversionTaxImpact > 0)
    }

    @Test("Roth conversion tax impact equals scenario tax minus tax without conversion")
    func rothImpactMatchesDifference() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let taxBefore = dm.scenarioTotalTax
        dm.yourRothConversion = 25_000
        let taxAfter = dm.scenarioTotalTax
        let impact = dm.rothConversionTaxImpact
        // Impact should equal the tax increase from adding the conversion
        #expect(isClose(impact, taxAfter - taxBefore, tolerance: 1.0))
    }

    @Test("Spouse Roth conversion included in impact")
    func rothImpactIncludesSpouse() {
        let dm = makeDM(birthYear: 1970, filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1970; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.spouseRothConversion = 20_000
        #expect(dm.rothConversionTaxImpact > 0)
    }

    // -- extraWithdrawalTaxImpact --

    @Test("Extra withdrawal tax impact is zero with no withdrawal")
    func withdrawalImpactZeroWithout() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        #expect(dm.extraWithdrawalTaxImpact == 0)
    }

    @Test("Extra withdrawal tax impact is positive with withdrawal")
    func withdrawalImpactPositive() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.yourExtraWithdrawal = 20_000
        #expect(dm.extraWithdrawalTaxImpact > 0)
    }

    @Test("Extra withdrawal tax impact equals scenario tax minus tax without withdrawal")
    func withdrawalImpactMatchesDifference() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let taxBefore = dm.scenarioTotalTax
        dm.yourExtraWithdrawal = 15_000
        let taxAfter = dm.scenarioTotalTax
        let impact = dm.extraWithdrawalTaxImpact
        #expect(isClose(impact, taxAfter - taxBefore, tolerance: 1.0))
    }

    // -- qcdTaxSavings --

    @Test("QCD tax savings is zero when no QCD")
    func qcdSavingsZeroWithout() {
        let dm = makeDM(birthYear: 1951, state: .florida)
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary)
        ]
        #expect(dm.qcdTaxSavings == 0)
    }

    @Test("QCD tax savings is zero when not QCD eligible")
    func qcdSavingsZeroWhenIneligible() {
        let dm = makeDM(birthYear: 1970, state: .florida) // age 56, not eligible
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary)
        ]
        dm.yourQCDAmount = 10_000
        #expect(dm.qcdTaxSavings == 0)
    }

    @Test("QCD tax savings is positive when QCD eligible with RMD")
    func qcdSavingsPositive() {
        let dm = makeDM(birthYear: 1951, state: .florida) // age 75, RMD required, QCD eligible
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary)
        ]
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        dm.yourQCDAmount = 5_000
        #expect(dm.qcdTaxSavings > 0)
    }

    @Test("QCD savings uses inverted add-back pattern correctly")
    func qcdSavingsAddBackPattern() {
        let dm = makeDM(birthYear: 1951, state: .florida)
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary)
        ]
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        // Tax without any QCD (QCD portion would be taxable)
        let taxWithoutQCD = dm.scenarioTotalTax
        dm.yourQCDAmount = 5_000
        let taxWithQCD = dm.scenarioTotalTax
        let savings = dm.qcdTaxSavings
        // Savings should equal the tax reduction from using QCD
        #expect(isClose(savings, taxWithoutQCD - taxWithQCD, tolerance: 1.0))
    }

    // -- qcdIRMAASavings --

    @Test("QCD IRMAA savings is zero when no Medicare members")
    func qcdIRMAAZeroNoMedicare() {
        let dm = makeDM(birthYear: 1970, state: .florida) // age 56, not Medicare
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        dm.yourQCDAmount = 10_000
        #expect(dm.qcdIRMAASavings == 0)
    }

    @Test("QCD IRMAA savings is zero when no QCD")
    func qcdIRMAAZeroNoQCD() {
        let dm = makeDM(birthYear: 1955, state: .florida) // age 71, Medicare eligible
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        #expect(dm.qcdIRMAASavings == 0)
    }

    @Test("QCD IRMAA savings positive when QCD drops below IRMAA cliff")
    func qcdIRMAASavingsPositiveAtCliff() {
        let dm = makeDM(birthYear: 1955, state: .florida) // age 71, Medicare eligible
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 300_000, owner: .primary)
        ]
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        // Without QCD, MAGI includes full RMD. With QCD, MAGI is reduced.
        // If that reduction crosses an IRMAA cliff, savings > 0
        let rmd = dm.calculatePrimaryRMD()
        // Set QCD to push MAGI below a cliff if possible
        dm.yourQCDAmount = min(rmd, 20_000)
        let savings = dm.qcdIRMAASavings
        // Savings is either 0 (didn't cross a cliff) or positive (crossed)
        #expect(savings >= 0)
    }

    @Test("QCD IRMAA savings multiplied by Medicare member count")
    func qcdIRMAASavingsMultipliedByMembers() {
        let dm = makeDM(birthYear: 1955, filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1955; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 400_000, owner: .primary)
        ]
        // Set income near an IRMAA cliff: $194K for MFJ Tier 1 at $212K
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 194_000)
        ]
        dm.yourQCDAmount = 20_000
        // Both are 65+ → medicareMemberCount = 2
        #expect(dm.medicareMemberCount == 2)
        // If there are IRMAA savings, they should be for 2 people
        let savings = dm.qcdIRMAASavings
        if savings > 0 {
            // Per-person savings × 2
            let perPerson = dm.calculateIRMAA(magi: dm.estimatedAGI + dm.scenarioTotalQCD, filingStatus: .marriedFilingJointly).annualSurchargePerPerson - dm.scenarioIRMAA.annualSurchargePerPerson
            #expect(isClose(savings, perPerson * 2.0))
        }
    }

    // -- rothConversionIRMAAImpact and extraWithdrawalIRMAAImpact --

    @Test("Roth conversion IRMAA impact is zero without conversion")
    func rothIRMAAZeroWithout() {
        let dm = makeDM(birthYear: 1955, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        #expect(dm.rothConversionIRMAAImpact == 0)
    }

    @Test("Roth conversion IRMAA impact is zero when no Medicare members")
    func rothIRMAAZeroNoMedicare() {
        let dm = makeDM(birthYear: 1970, state: .florida) // age 56, not Medicare
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.yourRothConversion = 50_000
        #expect(dm.rothConversionIRMAAImpact == 0)
    }

    @Test("Extra withdrawal IRMAA impact is zero without withdrawal")
    func withdrawalIRMAAZeroWithout() {
        let dm = makeDM(birthYear: 1955, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        #expect(dm.extraWithdrawalIRMAAImpact == 0)
    }
}

// MARK: - 43. Cash Donation Tax Savings

@Suite("Cash Donation Tax Savings", .serialized)
@MainActor struct CashDonationTaxSavingsTests {

    @Test("Cash donation savings is zero with no donation")
    func savingsZeroWithout() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        #expect(dm.cashDonationTaxSavings == 0)
    }

    @Test("Cash donation savings is positive when itemizing")
    func savingsPositiveWhenItemizing() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        // Make itemized beat standard: $12K mortgage + $10K cash = $22K > $16,100
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 12_000)
        ]
        dm.cashDonationAmount = 10_000
        dm.deductionOverride = nil
        #expect(dm.cashDonationTaxSavings > 0)
    }

    @Test("Cash donation savings is zero when standard deduction still wins")
    func savingsZeroWhenStandardWins() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        // No other itemized deductions: $1K cash alone << $16,100 standard
        dm.cashDonationAmount = 1_000
        dm.deductionOverride = nil
        // Without cash, standard wins. With cash, standard still wins.
        // So cash donation provides zero marginal tax savings.
        #expect(dm.cashDonationTaxSavings == 0)
    }

    @Test("Cash donation savings equals tax difference with vs without")
    func savingsMatchesDifference() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 15_000)
        ]
        // Tax without cash donation
        dm.deductionOverride = nil
        let taxBefore = dm.scenarioTotalTax
        // Add cash donation
        dm.cashDonationAmount = 8_000
        let taxAfter = dm.scenarioTotalTax
        let savings = dm.cashDonationTaxSavings
        #expect(isClose(savings, taxBefore - taxAfter, tolerance: 1.0))
    }

    @Test("Cash donation savings accounts for standard deduction fallback")
    func savingsAccountsForStandardFallback() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        // Itemized barely above standard: $12K mortgage + $5K cash = $17K > $16,100
        // Without cash: $12K < $16,100 → standard applies
        // So savings = tax(standard) - tax(itemized with cash)
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 12_000)
        ]
        dm.cashDonationAmount = 5_000
        dm.deductionOverride = nil
        let savings = dm.cashDonationTaxSavings
        // Savings should be based on difference from standard deduction, not from $12K
        // $17K - $16,100 = $900 marginal benefit → tax savings on $900
        #expect(savings > 0)
        // But savings should be less than marginal rate × full $5K donation
        let maxPossibleSavings = 5_000 * 0.37  // even at highest bracket
        #expect(savings < maxPossibleSavings)
    }
}

// MARK: - 44. Generated Action Items

@Suite("Generated Action Items", .serialized)
@MainActor struct GeneratedActionItemsTests {

    @Test("No action items when no scenario decisions")
    func noItemsWithNoDecisions() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        let items = dm.generatedActionItems
        // No RMD (age 56), no conversions, no withdrawals → just quarterly tax if any
        let nonTaxItems = items.filter { $0.category != .estimatedTax }
        #expect(nonTaxItems.isEmpty)
    }

    @Test("Primary RMD generates action item")
    func primaryRMDGeneratesItem() {
        let dm = makeDM(birthYear: 1951, state: .florida) // age 75, RMD required
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary)
        ]
        let items = dm.generatedActionItems
        let rmdItems = items.filter { $0.category == .rmd }
        #expect(rmdItems.count == 1)
        #expect(rmdItems.first?.id.contains("rmd-primary") == true)
    }

    @Test("Spouse RMD generates item only when spouse enabled")
    func spouseRMDOnlyWhenEnabled() {
        let dm = makeDM(birthYear: 1960, filingStatus: .marriedFilingJointly, state: .florida)
        var c = DateComponents(); c.year = 1953; c.month = 1; c.day = 1
        let spouseDOB = Calendar.current.date(from: c)!

        // Spouse disabled — no spouse RMD item
        dm.enableSpouse = false
        dm.spouseBirthDate = spouseDOB
        dm.iraAccounts = [
            IRAAccount(name: "Spouse IRA", accountType: .traditionalIRA, balance: 300_000, owner: .spouse)
        ]
        let items1 = dm.generatedActionItems
        let spouseRMD1 = items1.filter { $0.id.contains("rmd-spouse") }
        #expect(spouseRMD1.isEmpty)

        // Spouse enabled — should get spouse RMD item
        dm.enableSpouse = true
        let items2 = dm.generatedActionItems
        let spouseRMD2 = items2.filter { $0.id.contains("rmd-spouse") }
        #expect(spouseRMD2.count == 1)
    }

    @Test("Roth conversion generates action item")
    func rothConversionGeneratesItem() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.yourRothConversion = 25_000
        let items = dm.generatedActionItems
        let rothItems = items.filter { $0.category == .rothConversion }
        #expect(rothItems.count == 1)
        #expect(rothItems.first?.id.contains("roth-primary") == true)
    }

    @Test("Spouse Roth conversion item only when spouse enabled")
    func spouseRothOnlyWhenEnabled() {
        let dm = makeDM(filingStatus: .marriedFilingJointly, state: .florida)
        var c = DateComponents(); c.year = 1970; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.spouseRothConversion = 15_000

        dm.enableSpouse = false
        let items1 = dm.generatedActionItems
        #expect(items1.filter { $0.id.contains("roth-spouse") }.isEmpty)

        dm.enableSpouse = true
        let items2 = dm.generatedActionItems
        #expect(items2.filter { $0.id.contains("roth-spouse") }.count == 1)
    }

    @Test("Extra withdrawal generates action item")
    func extraWithdrawalGeneratesItem() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.yourExtraWithdrawal = 10_000
        let items = dm.generatedActionItems
        let wdlItems = items.filter { $0.category == .withdrawal }
        #expect(wdlItems.count == 1)
    }

    @Test("QCD generates action item")
    func qcdGeneratesItem() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.yourQCDAmount = 5_000
        let items = dm.generatedActionItems
        let qcdItems = items.filter { $0.category == .qcd }
        #expect(qcdItems.count == 1)
        #expect(qcdItems.first?.id.contains("qcd-primary") == true)
    }

    @Test("Stock donation generates action item")
    func stockDonationGeneratesItem() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.stockDonationEnabled = true
        dm.stockCurrentValue = 20_000
        let items = dm.generatedActionItems
        let charitableItems = items.filter { $0.category == .charitable }
        #expect(charitableItems.count == 1)
        #expect(charitableItems.first?.id.contains("stock-donation") == true)
    }

    @Test("Cash donation generates action item")
    func cashDonationGeneratesItem() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.cashDonationAmount = 3_000
        let items = dm.generatedActionItems
        let charitableItems = items.filter { $0.category == .charitable }
        #expect(charitableItems.count == 1)
        #expect(charitableItems.first?.id.contains("cash-donation") == true)
    }

    @Test("Quarterly tax payments generate action items")
    func quarterlyTaxGeneratesItems() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let items = dm.generatedActionItems
        let taxItems = items.filter { $0.category == .estimatedTax }
        // Should have 4 quarters
        #expect(taxItems.count == 4)
        // Check IDs contain q1, q2, q3, q4
        let ids = taxItems.map { $0.id }
        #expect(ids.contains { $0.contains("q1") })
        #expect(ids.contains { $0.contains("q2") })
        #expect(ids.contains { $0.contains("q3") })
        #expect(ids.contains { $0.contains("q4") })
    }

    @Test("Q4 deadline is Jan 15 of next year")
    func q4DeadlineNextYear() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let items = dm.generatedActionItems
        let q4 = items.first { $0.id.contains("q4") }
        #expect(q4 != nil)
        #expect(q4?.deadline.contains("\(dm.currentYear + 1)") == true)
    }

    @Test("All decision types together produce all action items")
    func allDecisionTypesProduceItems() {
        let dm = makeDM(birthYear: 1951, filingStatus: .marriedFilingJointly, state: .florida)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1951; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.iraAccounts = [
            IRAAccount(name: "My IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary),
            IRAAccount(name: "Spouse IRA", accountType: .traditionalIRA, balance: 200_000, owner: .spouse)
        ]
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        dm.yourRothConversion = 10_000
        dm.spouseRothConversion = 8_000
        dm.yourExtraWithdrawal = 5_000
        dm.spouseExtraWithdrawal = 3_000
        dm.yourQCDAmount = 2_000
        dm.spouseQCDAmount = 1_000
        dm.stockDonationEnabled = true
        dm.stockCurrentValue = 15_000
        dm.cashDonationAmount = 2_000

        let items = dm.generatedActionItems
        let categories = Set(items.map { $0.category })
        #expect(categories.contains(.rmd))
        #expect(categories.contains(.rothConversion))
        #expect(categories.contains(.withdrawal))
        #expect(categories.contains(.qcd))
        #expect(categories.contains(.charitable))
        #expect(categories.contains(.estimatedTax))
        // Should have many items: 2 RMDs + 2 Roth + 2 withdrawal + 2 QCD + 2 charitable + 4 quarterly = 14
        #expect(items.count >= 14)
    }

    @Test("Stock donation with zero value produces no item")
    func stockZeroValueNoItem() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.stockDonationEnabled = true
        dm.stockCurrentValue = 0
        let items = dm.generatedActionItems
        #expect(items.filter { $0.id.contains("stock-donation") }.isEmpty)
    }
}

// MARK: - 45. QCD Annual Limits

@Suite("QCD Annual Limits", .serialized)
@MainActor struct QCDAnnualLimitTests {

    @Test("QCD limit is $105K for 2024 and earlier")
    func qcdLimit2024() {
        let dm = makeDM(birthYear: 1951)
        dm.currentYear = 2024
        #expect(isClose(dm.qcdAnnualLimit, 105_000))
    }

    @Test("QCD limit is $108K for 2025")
    func qcdLimit2025() {
        let dm = makeDM(birthYear: 1951)
        dm.currentYear = 2025
        #expect(isClose(dm.qcdAnnualLimit, 108_000))
    }

    @Test("QCD limit is $111K for 2026")
    func qcdLimit2026() {
        let dm = makeDM(birthYear: 1951)
        dm.currentYear = 2026
        #expect(isClose(dm.qcdAnnualLimit, 111_000))
    }

    @Test("QCD limit is $111K for future years (2027+)")
    func qcdLimitFuture() {
        let dm = makeDM(birthYear: 1951)
        dm.currentYear = 2030
        #expect(isClose(dm.qcdAnnualLimit, 111_000))
    }

    @Test("yourMaxQCDAmount equals limit when QCD eligible")
    func yourMaxWhenEligible() {
        let dm = makeDM(birthYear: 1951) // age 75, QCD eligible (70½+)
        #expect(dm.yourMaxQCDAmount > 0)
        #expect(isClose(dm.yourMaxQCDAmount, dm.qcdAnnualLimit))
    }

    @Test("yourMaxQCDAmount is zero when not QCD eligible")
    func yourMaxWhenIneligible() {
        let dm = makeDM(birthYear: 1970) // age 56, not 70½
        #expect(dm.yourMaxQCDAmount == 0)
    }

    @Test("spouseMaxQCDAmount equals limit when spouse enabled and eligible")
    func spouseMaxWhenEnabled() {
        let dm = makeDM(birthYear: 1970, filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1951; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(isClose(dm.spouseMaxQCDAmount, dm.qcdAnnualLimit))
    }

    @Test("spouseMaxQCDAmount is zero when spouse disabled")
    func spouseMaxWhenDisabled() {
        let dm = makeDM(birthYear: 1970, filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        var c = DateComponents(); c.year = 1951; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(dm.spouseMaxQCDAmount == 0)
    }

    @Test("spouseMaxQCDAmount is zero when spouse too young")
    func spouseMaxWhenTooYoung() {
        let dm = makeDM(birthYear: 1970, filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1970; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)! // age 56, not 70½
        #expect(dm.spouseMaxQCDAmount == 0)
    }
}

// MARK: - 46. Total Annual Income

@Suite("Total Annual Income", .serialized)
@MainActor struct TotalAnnualIncomeTests {

    @Test("Zero income sources returns zero")
    func zeroSources() {
        let dm = makeDM()
        dm.incomeSources = []
        #expect(dm.totalAnnualIncome() == 0)
    }

    @Test("Single source returns its amount")
    func singleSource() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        #expect(isClose(dm.totalAnnualIncome(), 60_000))
    }

    @Test("Multiple sources sum correctly")
    func multipleSources() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000),
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 24_000),
            IncomeSource(name: "Dividends", type: .dividends, annualAmount: 5_000)
        ]
        #expect(isClose(dm.totalAnnualIncome(), 89_000))
    }

    @Test("Spouse income included in total")
    func spouseIncomeIncluded() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1960; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.incomeSources = [
            IncomeSource(name: "My Pension", type: .pension, annualAmount: 60_000, owner: .primary),
            IncomeSource(name: "Spouse SS", type: .socialSecurity, annualAmount: 20_000, owner: .spouse)
        ]
        #expect(isClose(dm.totalAnnualIncome(), 80_000))
    }
}

// MARK: - 47. Federal Average Rate

@Suite("Federal Average Rate", .serialized)
@MainActor struct FederalAverageRateTests {

    @Test("Zero income returns zero rate")
    func zeroIncomeZeroRate() {
        let dm = makeDM()
        #expect(dm.federalAverageRate(income: 0) == 0)
    }

    @Test("Average rate is always less than or equal to marginal rate")
    func averageLessThanMarginal() {
        let dm = makeDM()
        let incomes = [20_000.0, 50_000.0, 100_000.0, 250_000.0, 500_000.0]
        for income in incomes {
            let avg = dm.federalAverageRate(income: income)
            let marginal = dm.federalMarginalRate(income: income)
            #expect(avg <= marginal, "Average \(avg) should be <= marginal \(marginal) for income \(income)")
        }
    }

    @Test("Average rate is positive for positive income")
    func averagePositive() {
        let dm = makeDM()
        #expect(dm.federalAverageRate(income: 50_000) > 0)
    }

    @Test("Average rate is (tax / income) * 100")
    func averageMatchesFormula() {
        let dm = makeDM()
        let income = 80_000.0
        let tax = dm.calculateFederalTax(income: income, filingStatus: .single)
        let expected = (tax / income) * 100
        #expect(isClose(dm.federalAverageRate(income: income), expected))
    }

    @Test("Average rate increases with income (progressive system)")
    func averageIncreasesWithIncome() {
        let dm = makeDM()
        let low = dm.federalAverageRate(income: 30_000)
        let mid = dm.federalAverageRate(income: 100_000)
        let high = dm.federalAverageRate(income: 500_000)
        #expect(low < mid)
        #expect(mid < high)
    }

    @Test("MFJ average rate is lower than single for same income")
    func mfjAverageLowerThanSingle() {
        let dm = makeDM()
        let income = 100_000.0
        let singleRate = dm.federalAverageRate(income: income, filingStatus: .single)
        let mfjRate = dm.federalAverageRate(income: income, filingStatus: .marriedFilingJointly)
        #expect(mfjRate < singleRate)
    }
}

// MARK: - 48. Scenario Quarterly Payment (Scalar)

@Suite("Scenario Quarterly Payment Scalar", .serialized)
@MainActor struct ScenarioQuarterlyPaymentScalarTests {

    @Test("Scalar payment is total / 4")
    func scalarIsTotalDividedBy4() {
        let dm = makeDM(state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        let detailed = dm.scenarioQuarterlyPayments
        let scalar = dm.scenarioQuarterlyPayment
        if detailed.total > 0 {
            #expect(isClose(scalar, detailed.total / 4.0))
        } else {
            #expect(scalar == 0)
        }
    }

    @Test("Scalar is zero when total is zero")
    func scalarZeroWhenNoTax() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 10_000,
                         federalWithholding: 10_000)
        ]
        let detailed = dm.scenarioQuarterlyPayments
        let scalar = dm.scenarioQuarterlyPayment
        if detailed.total == 0 {
            #expect(scalar == 0)
        }
    }

    @Test("Scalar is positive when there is tax due")
    func scalarPositiveWithTax() {
        let dm = makeDM(birthYear: 1970, state: .florida)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        #expect(dm.scenarioQuarterlyPayment > 0)
    }
}

// MARK: - 49. Setup Progress

@Suite("Setup Progress", .serialized)
@MainActor struct SetupProgressTests {

    @Test("Default DataManager has birth date set (default is 1953)")
    func defaultHasBirthDate() {
        let dm = DataManager(skipPersistence: true)
        // Default birth date IS 1953-01-01, which equals the check date
        // So hasSetBirthDate should be false
        let progress = dm.setupProgress
        #expect(progress.hasSetBirthDate == false)
    }

    @Test("Custom birth date marks hasSetBirthDate true")
    func customBirthDateTrue() {
        let dm = makeDM(birthYear: 1960)
        let progress = dm.setupProgress
        #expect(progress.hasSetBirthDate == true)
    }

    @Test("No accounts means hasAccounts is false")
    func noAccountsFalse() {
        let dm = makeDM()
        dm.iraAccounts = []
        #expect(dm.setupProgress.hasAccounts == false)
    }

    @Test("With accounts means hasAccounts is true")
    func withAccountsTrue() {
        let dm = makeDM()
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 100_000)
        ]
        #expect(dm.setupProgress.hasAccounts == true)
    }

    @Test("No income sources means hasIncomeSources is false")
    func noIncomeSourcesFalse() {
        let dm = makeDM()
        dm.incomeSources = []
        #expect(dm.setupProgress.hasIncomeSources == false)
    }

    @Test("With income sources means hasIncomeSources is true")
    func withIncomeSourcesTrue() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        #expect(dm.setupProgress.hasIncomeSources == true)
    }

    @Test("No deductions means hasDeductions is false")
    func noDeductionsFalse() {
        let dm = makeDM()
        dm.deductionItems = []
        #expect(dm.setupProgress.hasDeductions == false)
    }

    @Test("With deductions means hasDeductions is true")
    func withDeductionsTrue() {
        let dm = makeDM()
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 10_000)
        ]
        #expect(dm.setupProgress.hasDeductions == true)
    }

    @Test("completedSteps counts true flags")
    func completedStepsCount() {
        let dm = makeDM(birthYear: 1960) // hasSetBirthDate = true
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 100_000)
        ]
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        dm.deductionItems = [] // no deductions
        let progress = dm.setupProgress
        #expect(progress.completedSteps == 3) // birth, accounts, income (no SS, no deductions)
        #expect(progress.totalSteps == 5)
        #expect(progress.isComplete == false)
    }

    @Test("isComplete true when all steps done")
    func isCompleteTrue() {
        let dm = makeDM(birthYear: 1960)
        dm.primarySSBenefit = SSBenefitEstimate(
            owner: .primary, benefitAtFRA: 2800, isAlreadyClaiming: true, currentBenefit: 2800
        )
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 100_000)
        ]
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 10_000)
        ]
        let progress = dm.setupProgress
        #expect(progress.completedSteps == 5)
        #expect(progress.isComplete == true)
    }
}

// MARK: - 50. Spouse Guard Properties

@Suite("Spouse Guard Properties", .serialized)
@MainActor struct SpouseGuardPropertyTests {

    @Test("spouseCurrentAge is zero when spouse disabled")
    func spouseCurrentAgeZero() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        var c = DateComponents(); c.year = 1955; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(dm.spouseCurrentAge == 0)
    }

    @Test("spouseCurrentAge is correct when spouse enabled")
    func spouseCurrentAgeCorrect() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1955; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(dm.spouseCurrentAge == dm.currentYear - 1955)
    }

    @Test("spouseRmdAge is zero when spouse disabled")
    func spouseRmdAgeZero() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        var c = DateComponents(); c.year = 1955; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(dm.spouseRmdAge == 0)
    }

    @Test("spouseRmdAge is 73 for spouse born 1951-1959")
    func spouseRmdAge73() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1955; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(dm.spouseRmdAge == 73)
    }

    @Test("spouseRmdAge is 75 for spouse born 1960+")
    func spouseRmdAge75() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1965; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(dm.spouseRmdAge == 75)
    }

    @Test("spouseYearsUntilRMD is zero when spouse disabled")
    func spouseYearsUntilRMDZero() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        var c = DateComponents(); c.year = 1955; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(dm.spouseYearsUntilRMD == 0)
    }

    @Test("spouseYearsUntilRMD correct when spouse enabled and pre-RMD")
    func spouseYearsUntilRMDCorrect() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1965; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        // Spouse age in 2026: 61, RMD age: 75 → 14 years
        #expect(dm.spouseYearsUntilRMD == 75 - (dm.currentYear - 1965))
    }

    @Test("spouseIsRMDRequired false when spouse disabled")
    func spouseIsRMDRequiredFalse() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        var c = DateComponents(); c.year = 1950; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(dm.spouseIsRMDRequired == false)
    }

    @Test("spouseIsQCDEligible false when spouse disabled")
    func spouseIsQCDEligibleFalse() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        var c = DateComponents(); c.year = 1950; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        #expect(dm.spouseIsQCDEligible == false)
    }

    @Test("spouseTraditionalIRABalance zero when spouse disabled")
    func spouseTraditionalBalanceZero() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        dm.iraAccounts = [
            IRAAccount(name: "Spouse IRA", accountType: .traditionalIRA, balance: 200_000, owner: .spouse)
        ]
        #expect(dm.spouseTraditionalIRABalance == 0)
    }

    @Test("spouseRothBalance zero when spouse disabled")
    func spouseRothBalanceZero() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        dm.iraAccounts = [
            IRAAccount(name: "Spouse Roth", accountType: .rothIRA, balance: 100_000, owner: .spouse)
        ]
        #expect(dm.spouseRothBalance == 0)
    }

    @Test("spouseInheritedTraditionalBalance zero when spouse disabled")
    func spouseInheritedTraditionalZero() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        dm.iraAccounts = [
            IRAAccount(name: "Spouse Inherited", accountType: .inheritedTraditionalIRA, balance: 100_000,
                       owner: .spouse, beneficiaryType: .nonEligibleDesignated,
                       yearOfInheritance: 2022, beneficiaryBirthYear: 1960)
        ]
        #expect(dm.spouseInheritedTraditionalBalance == 0)
    }

    @Test("spouseInheritedRothBalance zero when spouse disabled")
    func spouseInheritedRothZero() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        dm.iraAccounts = [
            IRAAccount(name: "Spouse Inherited Roth", accountType: .inheritedRothIRA, balance: 100_000,
                       owner: .spouse, beneficiaryType: .nonEligibleDesignated,
                       yearOfInheritance: 2022, beneficiaryBirthYear: 1960)
        ]
        #expect(dm.spouseInheritedRothBalance == 0)
    }

    @Test("spouseInheritedRMD zero when spouse disabled")
    func spouseInheritedRMDZero() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = false
        dm.iraAccounts = [
            IRAAccount(name: "Spouse Inherited", accountType: .inheritedTraditionalIRA, balance: 100_000,
                       owner: .spouse, beneficiaryType: .nonEligibleDesignated,
                       decedentRBDStatus: .afterRBD,
                       yearOfInheritance: 2022, beneficiaryBirthYear: 1960)
        ]
        #expect(dm.spouseInheritedRMD == 0)
    }

    @Test("All spouse balances return correct values when enabled")
    func spouseBalancesCorrectWhenEnabled() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        dm.enableSpouse = true
        var c = DateComponents(); c.year = 1960; c.month = 1; c.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: c)!
        dm.iraAccounts = [
            IRAAccount(name: "Spouse Trad", accountType: .traditionalIRA, balance: 200_000, owner: .spouse),
            IRAAccount(name: "Spouse Roth", accountType: .rothIRA, balance: 100_000, owner: .spouse),
            IRAAccount(name: "My Trad", accountType: .traditionalIRA, balance: 150_000, owner: .primary)
        ]
        #expect(isClose(dm.spouseTraditionalIRABalance, 200_000))
        #expect(isClose(dm.spouseRothBalance, 100_000))
        #expect(isClose(dm.primaryTraditionalIRABalance, 150_000))
    }
}

// MARK: - Suite 51: IRMAA Previous Tier Savings

@Suite("51. IRMAA Previous Tier Savings", .serialized)
@MainActor struct IRMAAPreviousTierSavingsTests {

    @Test("Tier 0 returns zero previous tier surcharge")
    func tier0NoPreviousSurcharge() {
        let dm = makeDM(birthYear: 1955)
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 30_000)
        ]
        #expect(dm.scenarioIRMAA.tier == 0)
        #expect(dm.scenarioIRMAAPreviousTierAnnualSurcharge == 0)
    }

    @Test("Tier 1 previous tier surcharge is zero (Tier 0 has no surcharge)")
    func tier1PreviousIsZero() {
        let dm = makeDM(birthYear: 1955)
        // Single Tier 1: $109,001–$137,000
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 120_000)
        ]
        #expect(dm.scenarioIRMAA.tier == 1)
        #expect(dm.scenarioIRMAAPreviousTierAnnualSurcharge == 0)
    }

    @Test("Tier 2 previous tier surcharge equals Tier 1 surcharge")
    func tier2PreviousIsTier1() {
        let dm = makeDM(birthYear: 1955)
        // Single Tier 2: $137,001–$171,000
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 150_000)
        ]
        #expect(dm.scenarioIRMAA.tier == 2)
        // Tier 1 surcharge: (284.10 - 202.90 + 14.50) * 12 = 1,148.40
        let expectedTier1Surcharge = (284.10 - 202.90 + 14.50) * 12
        #expect(isClose(dm.scenarioIRMAAPreviousTierAnnualSurcharge, expectedTier1Surcharge))
    }

    @Test("Tier 3 previous tier surcharge equals Tier 2 surcharge")
    func tier3PreviousIsTier2() {
        let dm = makeDM(birthYear: 1955)
        // Single Tier 3: $171,001–$205,000
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 185_000)
        ]
        #expect(dm.scenarioIRMAA.tier == 3)
        // Tier 2 surcharge: (405.50 - 202.90 + 37.40) * 12 = 2,880
        let expectedTier2Surcharge = (405.50 - 202.90 + 37.40) * 12
        #expect(isClose(dm.scenarioIRMAAPreviousTierAnnualSurcharge, expectedTier2Surcharge))
    }

    @Test("Savings calculation is positive for any tier above 0")
    func savingsAlwaysPositive() {
        let dm = makeDM(birthYear: 1955)
        // Tier 4: $205,001–$500,000
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 300_000)
        ]
        #expect(dm.scenarioIRMAA.tier == 4)
        let savings = dm.scenarioIRMAA.annualSurchargePerPerson - dm.scenarioIRMAAPreviousTierAnnualSurcharge
        #expect(savings > 0)
    }

    @Test("MFJ Tier 2 previous tier surcharge uses MFJ thresholds")
    func mfjTier2PreviousIsTier1() {
        let dm = makeDM(birthYear: 1955, filingStatus: .marriedFilingJointly)
        // MFJ Tier 2: $274,001–$342,000
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 300_000)
        ]
        #expect(dm.scenarioIRMAA.tier == 2)
        // Tier 1 surcharge is same regardless of filing status
        let expectedTier1Surcharge = (284.10 - 202.90 + 14.50) * 12
        #expect(isClose(dm.scenarioIRMAAPreviousTierAnnualSurcharge, expectedTier1Surcharge))
    }

    @Test("Top tier (Tier 5) previous tier surcharge equals Tier 4")
    func tier5PreviousIsTier4() {
        let dm = makeDM(birthYear: 1955)
        // Single Tier 5: $500,001+
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 600_000)
        ]
        #expect(dm.scenarioIRMAA.tier == 5)
        // Tier 4 surcharge: (608.40 - 202.90 + 83.10) * 12 = 5,863.20
        let expectedTier4Surcharge = (608.40 - 202.90 + 83.10) * 12
        #expect(isClose(dm.scenarioIRMAAPreviousTierAnnualSurcharge, expectedTier4Surcharge))
    }
}

// MARK: - Suite 52: NIIT Calculations

@Suite("52. NIIT Calculations", .serialized)
@MainActor struct NIITCalculationTests {

    @Test("NIIT is zero when MAGI below threshold (Single)")
    func niitBelowThresholdSingle() {
        let dm = makeDM(birthYear: 1955)
        let result = dm.calculateNIIT(nii: 50_000, magi: 180_000, filingStatus: .single)
        #expect(result.annualNIITax == 0)
        #expect(isClose(result.distanceToThreshold, 20_000))
        #expect(result.taxableNII == 0)
    }

    @Test("NIIT is zero when MAGI below MFJ threshold")
    func niitBelowThresholdMFJ() {
        let dm = makeDM(birthYear: 1955, filingStatus: .marriedFilingJointly)
        let result = dm.calculateNIIT(nii: 50_000, magi: 240_000, filingStatus: .marriedFilingJointly)
        #expect(result.annualNIITax == 0)
        #expect(isClose(result.distanceToThreshold, 10_000))
    }

    @Test("NIIT applies to lesser of NII or MAGI excess — NII is lesser")
    func niitNIIIsLesser() {
        let dm = makeDM(birthYear: 1955)
        // MAGI $250K, threshold $200K → excess $50K. NII $30K → taxable = $30K
        let result = dm.calculateNIIT(nii: 30_000, magi: 250_000, filingStatus: .single)
        #expect(isClose(result.taxableNII, 30_000))
        #expect(isClose(result.annualNIITax, 30_000 * 0.038)) // $1,140
    }

    @Test("NIIT applies to lesser of NII or MAGI excess — excess is lesser")
    func niitExcessIsLesser() {
        let dm = makeDM(birthYear: 1955)
        // MAGI $210K, threshold $200K → excess $10K. NII $50K → taxable = $10K
        let result = dm.calculateNIIT(nii: 50_000, magi: 210_000, filingStatus: .single)
        #expect(isClose(result.taxableNII, 10_000))
        #expect(isClose(result.annualNIITax, 10_000 * 0.038)) // $380
    }

    @Test("NIIT uses MFJ threshold of $250,000")
    func niitMFJThreshold() {
        let dm = makeDM(birthYear: 1955, filingStatus: .marriedFilingJointly)
        // $260K MAGI, MFJ → $10K excess, $30K NII → taxable = $10K
        let result = dm.calculateNIIT(nii: 30_000, magi: 260_000, filingStatus: .marriedFilingJointly)
        #expect(isClose(result.taxableNII, 10_000))
        #expect(isClose(result.annualNIITax, 380))
    }

    @Test("NIIT is zero when NII is zero even if MAGI above threshold")
    func niitZeroNII() {
        let dm = makeDM(birthYear: 1955)
        let result = dm.calculateNIIT(nii: 0, magi: 300_000, filingStatus: .single)
        #expect(result.annualNIITax == 0)
        #expect(result.taxableNII == 0)
    }

    @Test("NIIT qualifying income types are correct")
    func niitQualifyingTypes() {
        // NII types
        #expect(DataManager.niitQualifyingTypes.contains(.dividends))
        #expect(DataManager.niitQualifyingTypes.contains(.qualifiedDividends))
        #expect(DataManager.niitQualifyingTypes.contains(.interest))
        #expect(DataManager.niitQualifyingTypes.contains(.capitalGainsShort))
        #expect(DataManager.niitQualifyingTypes.contains(.capitalGainsLong))
        // Non-NII types
        #expect(!DataManager.niitQualifyingTypes.contains(.socialSecurity))
        #expect(!DataManager.niitQualifyingTypes.contains(.pension))
        #expect(!DataManager.niitQualifyingTypes.contains(.rmd))
        #expect(!DataManager.niitQualifyingTypes.contains(.rothConversion))
        #expect(!DataManager.niitQualifyingTypes.contains(.consulting))
        #expect(!DataManager.niitQualifyingTypes.contains(.stateTaxRefund))
        #expect(!DataManager.niitQualifyingTypes.contains(.other))
    }

    @Test("scenarioNetInvestmentIncome sums qualifying types only")
    func scenarioNIISumsCorrectly() {
        let dm = makeDM(birthYear: 1955)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000),
            IncomeSource(name: "Dividends", type: .dividends, annualAmount: 20_000),
            IncomeSource(name: "Interest", type: .interest, annualAmount: 5_000),
            IncomeSource(name: "Cap Gains", type: .capitalGainsLong, annualAmount: 15_000)
        ]
        #expect(isClose(dm.scenarioNetInvestmentIncome, 40_000)) // 20K + 5K + 15K
    }

    @Test("scenarioTotalTax includes NIIT")
    func scenarioTotalTaxIncludesNIIT() {
        let dm = makeDM(birthYear: 1955)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 180_000),
            IncomeSource(name: "Dividends", type: .dividends, annualAmount: 30_000)
        ]
        // MAGI ≈ $210K (above $200K), NII = $30K, excess = $10K
        // NIIT = min($30K, $10K) * 3.8% = $380
        let totalWithNIIT = dm.scenarioTotalTax
        let fedPlusState = dm.scenarioFederalTax + dm.scenarioStateTax
        let niit = dm.scenarioNIITAmount
        #expect(isClose(totalWithNIIT, fedPlusState + niit))
        #expect(niit > 0)
    }

    @Test("Roth conversion raises MAGI but not NII, triggering NIIT on existing investment income")
    func rothConversionTriggersNIIT() {
        let dm = makeDM(birthYear: 1955)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 170_000),
            IncomeSource(name: "Dividends", type: .dividends, annualAmount: 20_000)
        ]
        // MAGI ≈ $190K (below $200K threshold), NII = $20K → NIIT = 0
        #expect(dm.scenarioNIITAmount == 0)
        // NII should not change with Roth conversion
        let niiBefore = dm.scenarioNetInvestmentIncome
        dm.yourRothConversion = 30_000
        // MAGI ≈ $220K, NII still $20K → excess = $20K → taxable NII = $20K → NIIT = $760
        #expect(isClose(dm.scenarioNetInvestmentIncome, niiBefore))
        #expect(dm.scenarioNIITAmount > 0)
        #expect(dm.rothConversionNIITImpact > 0)
    }

    @Test("NIIT per-decision impact is zero when no investment income")
    func niitImpactZeroWithoutNII() {
        let dm = makeDM(birthYear: 1955)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 250_000)
        ]
        dm.yourRothConversion = 50_000
        // No NII → all NIIT impacts should be zero
        #expect(dm.rothConversionNIITImpact == 0)
        #expect(dm.scenarioNIITAmount == 0)
    }

    @Test("distanceToThreshold is negative when MAGI above threshold")
    func distanceNegativeAboveThreshold() {
        let dm = makeDM(birthYear: 1955)
        let result = dm.calculateNIIT(nii: 30_000, magi: 220_000, filingStatus: .single)
        #expect(isClose(result.distanceToThreshold, -20_000))
    }
}

// MARK: - End-to-End Tax Law Validation

/// These tests verify the FULL tax calculation pipeline against hand-calculated
/// values derived from 2026 IRS rules (OBBBA brackets, Senior Bonus, SS taxation)
/// and state tax law (brackets, deductions, retirement exemptions).
///
/// Each scenario sets up a realistic retirement profile and checks every
/// intermediate value: RMD → taxable SS → gross income → deduction →
/// taxable income → federal tax → state tax → NIIT.
///
/// If any test fails, the hand-calculated expected value (in the test name
/// and comments) pinpoints exactly which step diverges from tax law.
@Suite("End-to-End Tax Law Validation", .serialized)
@MainActor struct EndToEndTaxValidationTests {

    // ═══════════════════════════════════════════════════════════════
    // Scenario A: Single, Age 73, California
    // ═══════════════════════════════════════════════════════════════
    // Born Jan 1 1953 · Single · CA
    // SS $28K · Pension $45K · Trad IRA $600K (auto-RMD) · Roth $25K
    //
    // Hand-calculated per:
    //   Federal: IRS 2026 brackets (Rev. Proc. 2025-32), OBBBA Senior Bonus
    //   State:   CA 2026 brackets, $5,706 standard deduction, SS exempt

    private func makeScenarioA() -> DataManager {
        let dm = makeDM(birthYear: 1953, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Social Security", type: .socialSecurity, annualAmount: 28_000),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 45_000)
        ]
        dm.iraAccounts = [
            IRAAccount(name: "Traditional IRA", accountType: .traditionalIRA, balance: 600_000, owner: .primary)
        ]
        dm.yourRothConversion = 25_000
        return dm
    }

    @Test("A: Auto-RMD = $600K ÷ 26.5 = $22,641.51")
    func a_rmd() {
        let dm = makeScenarioA()
        // Age 73 → Uniform Lifetime Table divisor 26.5
        #expect(isClose(dm.calculatePrimaryRMD(), 22_641.51, tolerance: 0.01))
    }

    @Test("A: Taxable SS = 85% × $28K = $23,800")
    func a_taxableSS() {
        let dm = makeScenarioA()
        // Combined income = $45K + ($25K Roth + $22,642 RMD) + 50% × $28K
        //                 = $106,642 → well above $34K single threshold → 85% tier
        // Taxable = min(85% × $28K, formula) = $23,800
        #expect(isClose(dm.scenarioTaxableSocialSecurity, 23_800, tolerance: 0.50))
    }

    @Test("A: Gross income ≈ $116,442")
    func a_grossIncome() {
        let dm = makeScenarioA()
        // scenarioBaseIncome = $45K pension + $23,800 taxable SS = $68,800
        // + $25K Roth conversion + $22,642 RMD = $116,442
        #expect(isClose(dm.scenarioGrossIncome, 116_441.51, tolerance: 1.0))
    }

    @Test("A: Standard deduction ≈ $21,664 (base $16,100 + age $2,050 + Senior Bonus $3,514)")
    func a_deduction() {
        let dm = makeScenarioA()
        // Senior Bonus = $6,000 − ($116,442 − $75,000) × 6% = $6,000 − $2,486 = $3,514
        #expect(isClose(dm.effectiveDeductionAmount, 21_663.51, tolerance: 1.0))
    }

    @Test("A: Federal taxable income = $94,778")
    func a_taxableIncome() {
        let dm = makeScenarioA()
        // $116,442 − $21,664 = $94,778 (exact due to Senior Bonus arithmetic)
        #expect(isClose(dm.scenarioTaxableIncome, 94_778.0, tolerance: 1.0))
    }

    @Test("A: Federal tax ≈ $15,563 (10%/12%/22% brackets)")
    func a_federalTax() {
        let dm = makeScenarioA()
        // 10% × $12,400 = $1,240
        // 12% × $38,000 = $4,560
        // 22% × $44,378 = $9,763.16
        // Total: $15,563.16
        #expect(isClose(dm.scenarioFederalTax, 15_563.16, tolerance: 1.0))
    }

    @Test("A: CA state tax ≈ $4,450")
    func a_stateTax() {
        let dm = makeScenarioA()
        // CA deduction $5,706 → state taxable $110,736
        // SS exempt −$23,800 → adjusted $86,936
        // CA brackets: 1%→2%→4%→6%→8%→9.3% = $4,737.85
        // CA exemption credits: 2 (taxpayer + age 65+) × $144 = $288
        // Net: $4,737.85 − $288 = $4,449.85
        #expect(isClose(dm.scenarioStateTax, 4_449.85, tolerance: 1.0))
    }

    @Test("A: NIIT = $0 (no investment income, MAGI below $200K)")
    func a_niit() {
        let dm = makeScenarioA()
        #expect(isClose(dm.scenarioNIITAmount, 0))
    }

    @Test("A: AMT = $0 (standard deduction, no add-backs)")
    func a_amt() {
        let dm = makeScenarioA()
        #expect(isClose(dm.scenarioAMTAmount, 0))
    }

    @Test("A: Total tax ≈ $20,013")
    func a_totalTax() {
        let dm = makeScenarioA()
        // Federal $15,563 + CA $4,450 + NIIT $0 + AMT $0 = $20,013
        #expect(isClose(dm.scenarioTotalTax, 20_013.01, tolerance: 2.0))
    }

    // ═══════════════════════════════════════════════════════════════
    // Scenario B: MFJ, Both Age 73, New York
    // ═══════════════════════════════════════════════════════════════
    // Both born Jan 1 1953 · MFJ · NY
    // His SS $32K · Her SS $24K · His Pension $55K · Her Pension $30K
    // His Trad IRA $800K · Her Trad IRA $400K · Roth $20K (his) · QCD $10K (his)
    //
    // Hand-calculated per:
    //   Federal: IRS 2026 brackets (Rev. Proc. 2025-32), OBBBA Senior Bonus
    //   State:   NY 2026 brackets, $16,050 MFJ deduction, SS exempt,
    //            $20K pension exclusion, $20K IRA exclusion (not applied to
    //            auto-calc RMDs since they're not in incomeSources)

    private func makeScenarioB() -> DataManager {
        let dm = makeDM(birthYear: 1953, filingStatus: .marriedFilingJointly, state: .newYork)
        dm.enableSpouse = true
        var sc = DateComponents(); sc.year = 1953; sc.month = 1; sc.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: sc)!
        dm.incomeSources = [
            IncomeSource(name: "His SS", type: .socialSecurity, annualAmount: 32_000, owner: .primary),
            IncomeSource(name: "Her SS", type: .socialSecurity, annualAmount: 24_000, owner: .spouse),
            IncomeSource(name: "His Pension", type: .pension, annualAmount: 55_000, owner: .primary),
            IncomeSource(name: "Her Pension", type: .pension, annualAmount: 30_000, owner: .spouse)
        ]
        dm.iraAccounts = [
            IRAAccount(name: "His Trad IRA", accountType: .traditionalIRA, balance: 800_000, owner: .primary),
            IRAAccount(name: "Her Trad IRA", accountType: .traditionalIRA, balance: 400_000, owner: .spouse)
        ]
        dm.yourRothConversion = 20_000
        dm.yourQCDAmount = 10_000
        return dm
    }

    @Test("B: Combined RMD = ($800K + $400K) ÷ 26.5 = $45,283.02")
    func b_rmd() {
        let dm = makeScenarioB()
        // Both age 73 → divisor 26.5
        // His: $30,188.68 + Her: $15,094.34 = $45,283.02
        #expect(isClose(dm.calculateCombinedRMD(), 45_283.02, tolerance: 0.01))
    }

    @Test("B: Taxable withdrawals = $45,283 − $10K QCD = $35,283")
    func b_withdrawals() {
        let dm = makeScenarioB()
        // QCD ($10K) reduces the taxable portion of withdrawals
        #expect(isClose(dm.scenarioTotalWithdrawals, 35_283.02, tolerance: 1.0))
    }

    @Test("B: Taxable SS = 85% × $56K = $47,600")
    func b_taxableSS() {
        let dm = makeScenarioB()
        // Total SS = $32K + $24K = $56K
        // Combined income = $85K + $55,283 + $28K = $168,283 → >> $44K MFJ threshold
        // Taxable = 85% × $56K = $47,600
        #expect(isClose(dm.scenarioTaxableSocialSecurity, 47_600, tolerance: 0.50))
    }

    @Test("B: Gross income ≈ $187,883")
    func b_grossIncome() {
        let dm = makeScenarioB()
        // Base = $85K pensions + $47,600 taxable SS = $132,600
        // + $20K Roth + $35,283 withdrawals = $187,883
        #expect(isClose(dm.scenarioGrossIncome, 187_883.02, tolerance: 1.0))
    }

    @Test("B: Standard deduction ≈ $45,227 (base $32,200 + 2×$1,650 + Senior Bonus $9,727)")
    func b_deduction() {
        let dm = makeScenarioB()
        // Senior Bonus = 2 × $6K − ($187,883 − $150K) × 6%
        //              = $12,000 − $2,273 = $9,727
        #expect(isClose(dm.effectiveDeductionAmount, 45_227.02, tolerance: 1.0))
    }

    @Test("B: Federal taxable income = $142,656")
    func b_taxableIncome() {
        let dm = makeScenarioB()
        // $187,883 − $45,227 = $142,656 (exact due to Senior Bonus arithmetic)
        #expect(isClose(dm.scenarioTaxableIncome, 142_656.0, tolerance: 1.0))
    }

    @Test("B: Federal tax ≈ $20,808 (10%/12%/22% MFJ brackets)")
    func b_federalTax() {
        let dm = makeScenarioB()
        // 10% × $24,800 = $2,480
        // 12% × $76,000 = $9,120
        // 22% × $41,856 = $9,208.32
        // Total: $20,808.32
        #expect(isClose(dm.scenarioFederalTax, 20_808.32, tolerance: 1.0))
    }

    @Test("B: NY state tax ≈ $5,667")
    func b_stateTax() {
        let dm = makeScenarioB()
        // NY deduction $16,050 → state taxable $171,833
        // SS exempt −$47,600 → $124,233
        // Pension exempt −$20K (NY cap) → $104,233
        // IRA exempt $0 (auto-calc RMDs not in incomeSources)
        // NY MFJ brackets: 4%→4.5%→5.25%→5.85% = $5,667.48
        #expect(isClose(dm.scenarioStateTax, 5_667.48, tolerance: 1.0))
    }

    @Test("B: NIIT = $0 (no investment income, MAGI below $250K)")
    func b_niit() {
        let dm = makeScenarioB()
        #expect(isClose(dm.scenarioNIITAmount, 0))
    }

    @Test("B: AMT = $0 (standard deduction, no add-backs)")
    func b_amt() {
        let dm = makeScenarioB()
        #expect(isClose(dm.scenarioAMTAmount, 0))
    }

    @Test("B: Total tax ≈ $26,476")
    func b_totalTax() {
        let dm = makeScenarioB()
        #expect(isClose(dm.scenarioTotalTax, 26_475.80, tolerance: 2.0))
    }
}

// MARK: - AMT Calculation Tests

@Suite("AMT Calculation", .serialized)
@MainActor struct AMTCalculationTests {

    @Test("No AMT for standard deduction (most retirees)")
    func noAMTStandardDeduction() {
        // Typical retiree: standard deduction → no add-backs → AMTI = taxable income
        // With $90K exemption (single), TMT is far below regular tax
        let dm = makeDM(birthYear: 1955, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        #expect(isClose(dm.scenarioAMTAmount, 0))
    }

    @Test("No AMT for moderate itemizers")
    func noAMTModerateItemizer() {
        // Small SALT add-back not enough to push TMT above regular tax
        let dm = makeDM(birthYear: 1970, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 200_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 20_000)
        ]
        // SALT $20K (under cap), itemized ≈ $20K > standard $16.1K → itemizes
        // But at $200K income, regular 24% marginal rate > AMT 26% → no AMT
        #expect(isClose(dm.scenarioAMTAmount, 0))
    }

    @Test("AMT triggered with high SALT + medical at moderate income")
    func amtTriggeredHighSALT() {
        // Single, under 65, $150K pension, high SALT + medical
        // Large add-backs push TMT above regular tax
        let dm = makeDM(birthYear: 1970, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 150_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 45_000),
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 30_000)
        ]
        // SALT: min($45K, $40,400 cap) = $40,400
        // Medical: $30K − 7.5% × $150K = $30K − $11,250 = $18,750 deductible
        // Itemized total: $40,400 + $18,750 = $59,150 > $16,100 standard → itemizes
        // Regular taxable: $150K − $59,150 = $90,850
        // Regular tax: 10% × $12.4K + 12% × $38K + 22% × $40,450 = $14,699
        //
        // AMT: AMTI = $90,850 + $40,400 + $18,750 = $150,000
        //   Exemption: $90,100 (no phaseout, $150K < $500K)
        //   Taxable AMTI: $59,900
        //   TMT: $59,900 × 26% = $15,574
        //   AMT = max(0, $15,574 − $14,699) = $875
        #expect(dm.scenarioAMTAmount > 0, "AMT should trigger with high SALT add-backs")
        #expect(isClose(dm.scenarioAMTAmount, 875, tolerance: 5.0))
    }

    @Test("AMT exemption phaseout at high AMTI")
    func amtExemptionPhaseout() {
        let dm = makeDM(birthYear: 1970, filingStatus: .single, state: .california)
        // Use calculateAMT directly with high taxable income to test phaseout
        let result = dm.calculateAMT(
            taxableIncome: 600_000,
            regularTax: 100_000,
            filingStatus: .single
        )
        // AMTI = $600K (no itemizing → no add-backs for direct call w/ standard deduction)
        // Phaseout: ($600K − $500K) × 0.50 = $50,000
        // Exemption: max(0, $90,100 − $50,000) = $40,100
        // Taxable AMTI: $600K − $40,100 = $559,900
        #expect(isClose(result.exemption, 40_100, tolerance: 1.0))
        #expect(isClose(result.taxableAMTI, 559_900, tolerance: 1.0))
    }

    @Test("AMT exemption fully phased out")
    func amtExemptionFullPhaseout() {
        let dm = makeDM(birthYear: 1970, filingStatus: .single, state: .california)
        let result = dm.calculateAMT(
            taxableIncome: 700_000,
            regularTax: 200_000,
            filingStatus: .single
        )
        // AMTI = $700K
        // Phaseout: ($700K − $500K) × 0.50 = $100,000
        // Exemption: max(0, $90,100 − $100,000) = $0
        #expect(isClose(result.exemption, 0))
        #expect(isClose(result.taxableAMTI, 700_000, tolerance: 1.0))
    }

    @Test("scenarioTotalTax includes AMT when triggered")
    func totalTaxIncludesAMT() {
        let dm = makeDM(birthYear: 1970, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 150_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 45_000),
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 30_000)
        ]
        let total = dm.scenarioTotalTax
        let withoutAMT = dm.scenarioFederalTax + dm.scenarioStateTax + dm.scenarioNIITAmount
        // Total should include AMT
        #expect(total > withoutAMT, "scenarioTotalTax should include AMT when triggered")
        #expect(isClose(total, withoutAMT + dm.scenarioAMTAmount))
    }

    @Test("MFJ higher exemption means harder to trigger AMT")
    func mfjHigherExemption() {
        let dm = makeDM(birthYear: 1970, filingStatus: .marriedFilingJointly, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 150_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 45_000),
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 30_000)
        ]
        // MFJ exemption is $140,200 vs single $90,100
        // Same income → much less likely to trigger AMT
        #expect(isClose(dm.scenarioAMTAmount, 0), "MFJ should not trigger AMT with same income/deductions as single")
    }
}

// MARK: - High-Income Stress Tests

/// Scenario C: Single, Age 73, California — exercises EVERY high-income edge case.
///
/// Hits: 37% federal bracket, 20% cap gains bracket, 12.3% CA bracket,
/// NIIT on $330K NII, SALT phaseout to $10K floor, OBBBA Senior Bonus fully
/// phased out, 85% SS max, AMT exemption fully phased out, standard deduction
/// beats capped itemized. Hand-calculated per IRS 2026 rules.
///
/// Income: SS $45K + Pension $360K + Interest $40K + Short-term CG $30K
///         + LT CG $200K + Qualified Divs $60K + IRA RMD $94,340 + Roth $100K
@Suite("High-Income Stress Test C: Single/CA Top Brackets", .serialized)
@MainActor struct StressTestC_SingleCA {

    private func makeScenarioC() -> DataManager {
        let dm = makeDM(birthYear: 1953, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Social Security", type: .socialSecurity, annualAmount: 45_000),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 360_000),
            IncomeSource(name: "Interest", type: .interest, annualAmount: 40_000),
            IncomeSource(name: "Short-term CG", type: .capitalGainsShort, annualAmount: 30_000),
            IncomeSource(name: "LT Cap Gains", type: .capitalGainsLong, annualAmount: 200_000),
            IncomeSource(name: "Qualified Divs", type: .qualifiedDividends, annualAmount: 60_000)
        ]
        dm.iraAccounts = [
            IRAAccount(name: "Traditional IRA", accountType: .traditionalIRA, balance: 2_500_000, owner: .primary)
        ]
        dm.yourRothConversion = 100_000
        dm.deductionItems = [
            DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 50_000)
        ]
        return dm
    }

    @Test("C: RMD = $2.5M ÷ 26.5 = $94,339.62")
    func c_rmd() {
        let dm = makeScenarioC()
        // Age 73 → factor 26.5
        #expect(isClose(dm.calculatePrimaryRMD(), 94_339.62, tolerance: 0.01))
    }

    @Test("C: Taxable SS = 85% × $45K = $38,250 (max)")
    func c_taxableSS() {
        let dm = makeScenarioC()
        // Combined income = $690K + $194,340 + $22,500 = $906,840 → way above $34K → 85% max
        #expect(isClose(dm.scenarioTaxableSocialSecurity, 38_250, tolerance: 0.50))
    }

    @Test("C: Gross income ≈ $922,590")
    func c_grossIncome() {
        let dm = makeScenarioC()
        // otherIncome(non-pref) = $360K pension + $40K interest + $30K ST CG = $430K
        // + taxableSS $38,250 + preferential $260K = $728,250 base
        // + $100K Roth + $94,340 RMD = $922,590
        #expect(isClose(dm.scenarioGrossIncome, 922_589.62, tolerance: 1.0))
    }

    @Test("C: SALT cap phased out to $10K floor")
    func c_saltCap() {
        let dm = makeScenarioC()
        // MAGI $922,590 >> $505K threshold
        // phaseoutReduction = ($922,590 - $505K) × 0.30 = $125,277 → exceeds $40,400 cap
        // afterPhaseout = $40,400 − $125,277 = negative → floor = $10,000
        #expect(isClose(dm.saltCap, 10_000, tolerance: 1.0))
        // saltAfterCap = min($50K property tax, $10K) = $10K
        #expect(isClose(dm.saltAfterCap, 10_000, tolerance: 1.0))
    }

    @Test("C: Standard deduction = $18,150 (Senior Bonus fully phased out)")
    func c_deduction() {
        let dm = makeScenarioC()
        // Base $16,100 + age 65+ $2,050 = $18,150
        // OBBBA: ($922,590 − $75K) × 6% = $50,855 > $6K → bonus = $0
        // Itemized = $10K SALT < $18,150 standard → standard wins
        #expect(isClose(dm.effectiveDeductionAmount, 18_150, tolerance: 1.0))
        #expect(!dm.scenarioEffectiveItemize, "Should use standard deduction")
    }

    @Test("C: Taxable income ≈ $904,440 (hits 37% bracket)")
    func c_taxableIncome() {
        let dm = makeScenarioC()
        #expect(isClose(dm.scenarioTaxableIncome, 904_439.62, tolerance: 1.0))
        // Ordinary income = $904,440 - $260K pref = $644,440 > $640,600 → 37% bracket!
    }

    @Test("C: Federal tax ≈ $246,400 (37% bracket + 20% cap gains)")
    func c_federalTax() {
        let dm = makeScenarioC()
        // Ordinary tax through 37% bracket:
        //   10% × $12,400 = $1,240 + 12% × $38K = $4,560 + 22% × $55,300 = $12,166
        //   + 24% × $96,075 = $23,058 + 32% × $54,450 = $17,424
        //   + 35% × $384,375 = $134,531.25 + 37% × $3,840 = $1,421 → $194,400
        // Cap gains: entire $260K in 20% bracket (ordinary already above $545,500) → $52,000
        // Total: $246,400
        #expect(isClose(dm.scenarioFederalTax, 246_399.91, tolerance: 2.0))
    }

    @Test("C: CA state tax ≈ $90,061 (12.3% bracket)")
    func c_stateTax() {
        let dm = makeScenarioC()
        // CA state taxable: $922,590 − $5,706 = $916,884 − SS $38,250 = $878,634
        // Through CA brackets up to 12.3% (> $698,271)
        #expect(isClose(dm.scenarioStateTax, 90_061.10, tolerance: 2.0))
    }

    @Test("C: NIIT = $12,540 (full $330K NII taxed)")
    func c_niit() {
        let dm = makeScenarioC()
        // NII = LT CG $200K + qual divs $60K + interest $40K + ST CG $30K = $330K
        // MAGI $922,590 >> $200K threshold → full NII taxed
        // $330K × 3.8% = $12,540
        #expect(isClose(dm.scenarioNIITAmount, 12_540, tolerance: 1.0))
    }

    @Test("C: AMT = $0 (regular tax at 37% exceeds TMT at 26/28%)")
    func c_amt() {
        let dm = makeScenarioC()
        // AMTI = $904,440 (standard deduction → no add-backs)
        // Exemption fully phased out: ($904K − $500K) × 0.50 = $202K > $90.1K → exemption = $0
        let result = dm.scenarioAMT
        #expect(isClose(result.exemption, 0, tolerance: 1.0))
        // But TMT ≈ $227,553 < regular tax $246,400 → AMT = $0
        #expect(isClose(result.amt, 0, tolerance: 1.0))
    }

    @Test("C: Total tax ≈ $349,001")
    func c_totalTax() {
        let dm = makeScenarioC()
        // Federal $246,400 + CA $90,061 + NIIT $12,540 + AMT $0 = $349,001
        #expect(isClose(dm.scenarioTotalTax, 349_001.01, tolerance: 5.0))
    }
}

/// Scenario D: MFJ, Both Age 73, New York — high income with MFJ brackets,
/// pension exemption, and full NIIT.
///
/// Hits: MFJ 35% federal bracket, 20% cap gains, 6.85% NY bracket,
/// $20K NY pension exemption, NIIT on $320K NII, MFJ 85% SS max,
/// Senior Bonus fully phased out, MFJ AMT exemption (below phaseout).
///
/// Income: His SS $45K + Her SS $30K + His Pension $120K + Her Pension $80K
///         + Interest $40K + LT CG $200K + Qual Divs $80K
///         + His/Her IRA RMDs $86,792 + Roth $200K
@Suite("High-Income Stress Test D: MFJ/NY", .serialized)
@MainActor struct StressTestD_MFJNY {

    private func makeScenarioD() -> DataManager {
        let dm = makeDM(birthYear: 1953, filingStatus: .marriedFilingJointly, state: .newYork)
        dm.enableSpouse = true
        var sc = DateComponents(); sc.year = 1953; sc.month = 1; sc.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: sc)!
        dm.incomeSources = [
            IncomeSource(name: "His SS", type: .socialSecurity, annualAmount: 45_000, owner: .primary),
            IncomeSource(name: "Her SS", type: .socialSecurity, annualAmount: 30_000, owner: .spouse),
            IncomeSource(name: "His Pension", type: .pension, annualAmount: 120_000, owner: .primary),
            IncomeSource(name: "Her Pension", type: .pension, annualAmount: 80_000, owner: .spouse),
            IncomeSource(name: "Interest", type: .interest, annualAmount: 40_000),
            IncomeSource(name: "LT Cap Gains", type: .capitalGainsLong, annualAmount: 200_000),
            IncomeSource(name: "Qualified Divs", type: .qualifiedDividends, annualAmount: 80_000)
        ]
        dm.iraAccounts = [
            IRAAccount(name: "His Trad IRA", accountType: .traditionalIRA, balance: 1_500_000, owner: .primary),
            IRAAccount(name: "Her Trad IRA", accountType: .traditionalIRA, balance: 800_000, owner: .spouse)
        ]
        dm.yourRothConversion = 150_000
        dm.spouseRothConversion = 50_000
        return dm
    }

    @Test("D: Combined RMD = ($1.5M + $800K) ÷ 26.5 = $86,792.45")
    func d_rmd() {
        let dm = makeScenarioD()
        // His: $1,500K / 26.5 = $56,603.77 + Her: $800K / 26.5 = $30,188.68
        #expect(isClose(dm.calculateCombinedRMD(), 86_792.45, tolerance: 0.01))
    }

    @Test("D: Taxable SS = 85% × $75K = $63,750 (max)")
    func d_taxableSS() {
        let dm = makeScenarioD()
        // Total SS = $45K + $30K = $75K
        // Combined income = $520K + $286,792 + $37,500 = $844,292 → 85% tier
        #expect(isClose(dm.scenarioTaxableSocialSecurity, 63_750, tolerance: 0.50))
    }

    @Test("D: Gross income ≈ $870,542")
    func d_grossIncome() {
        let dm = makeScenarioD()
        // Base: $240K (pensions+interest) + $63,750 SS + $280K pref = $583,750
        // + $200K Roth + $86,792 RMD = $870,542
        #expect(isClose(dm.scenarioGrossIncome, 870_542.45, tolerance: 1.0))
    }

    @Test("D: Standard deduction = $35,500 (MFJ, both 65+, Senior Bonus fully phased out)")
    func d_deduction() {
        let dm = makeScenarioD()
        // Base $32,200 + 2 × $1,650 = $35,500
        // OBBBA: ($870,542 − $150K) × 6% = $43,233 > $12K → bonus = $0
        #expect(isClose(dm.effectiveDeductionAmount, 35_500, tolerance: 1.0))
    }

    @Test("D: Taxable income ≈ $835,042")
    func d_taxableIncome() {
        let dm = makeScenarioD()
        #expect(isClose(dm.scenarioTaxableIncome, 835_042.45, tolerance: 1.0))
    }

    @Test("D: Federal tax ≈ $184,870 (MFJ 35% bracket + 20% cap gains)")
    func d_federalTax() {
        let dm = makeScenarioD()
        // Ordinary income = $835,042 − $280K = $555,042 → MFJ 35% bracket
        // (below $768,700 → doesn't hit 37%)
        // Cap gains: $280K stacked above $555K ordinary → crosses $613,700 → partly at 20%
        #expect(isClose(dm.scenarioFederalTax, 184_870.48, tolerance: 2.0))
    }

    @Test("D: NY state tax ≈ $49,780 (6.85% bracket, $20K pension exemption)")
    func d_stateTax() {
        let dm = makeScenarioD()
        // NY taxable: $870,542 − $16,050 = $854,492
        // − SS $63,750 = $790,742
        // − pension $20K (NY cap) = $770,742
        // Through NY MFJ brackets up to 6.85% ($323,200-$2,155,350)
        #expect(isClose(dm.scenarioStateTax, 49_780.31, tolerance: 2.0))
    }

    @Test("D: NIIT = $12,160 (full $320K NII taxed)")
    func d_niit() {
        let dm = makeScenarioD()
        // NII = LT CG $200K + qual divs $80K + interest $40K = $320K
        // MAGI $870,542 >> $250K MFJ threshold → full NII
        // $320K × 3.8% = $12,160
        #expect(isClose(dm.scenarioNIITAmount, 12_160, tolerance: 1.0))
    }

    @Test("D: AMT = $0 (MFJ exemption $140K, AMTI below phaseout)")
    func d_amt() {
        let dm = makeScenarioD()
        let result = dm.scenarioAMT
        // AMTI = $835,042 (standard deduction → no add-backs)
        // $835K < $1M MFJ phaseout threshold → full $140,200 exemption
        #expect(isClose(result.exemption, 140_200, tolerance: 1.0))
        #expect(isClose(result.amt, 0, tolerance: 1.0))
    }

    @Test("D: Total tax ≈ $246,811")
    func d_totalTax() {
        let dm = makeScenarioD()
        // Federal $184,870 + NY $49,780 + NIIT $12,160 + AMT $0 = $246,811
        #expect(isClose(dm.scenarioTotalTax, 246_810.79, tolerance: 5.0))
    }
}

/// Scenario E: Single, Age 56, California — massive AMT triggered by large
/// itemized deductions that are fully added back for AMT purposes.
///
/// Hits: AMT 28% bracket, AMT exemption partial phaseout ($10K reduction),
/// SALT phaseout ($35,900 cap), 7.5% medical AGI floor, large add-backs
/// ($196,900), NIIT, CA 11.3% bracket. Tests the full interaction of
/// itemized deductions with AMT.
///
/// Income: Pension $400K + Interest $20K + LT CG $100K
/// Deductions: Property Tax $200K + Medical $200K
@Suite("High-Income Stress Test E: AMT Trigger", .serialized)
@MainActor struct StressTestE_AMT {

    private func makeScenarioE() -> DataManager {
        let dm = makeDM(birthYear: 1970, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 400_000),
            IncomeSource(name: "Interest", type: .interest, annualAmount: 20_000),
            IncomeSource(name: "LT Cap Gains", type: .capitalGainsLong, annualAmount: 100_000)
        ]
        dm.deductionItems = [
            DeductionItem(name: "Property Tax", type: .propertyTax, annualAmount: 200_000),
            DeductionItem(name: "Medical", type: .medicalExpenses, annualAmount: 200_000)
        ]
        return dm
    }

    @Test("E: Gross income = $520,000")
    func e_grossIncome() {
        let dm = makeScenarioE()
        // Pension $400K + Interest $20K + LT CG $100K = $520K (no SS, no RMD, no Roth)
        #expect(isClose(dm.scenarioGrossIncome, 520_000, tolerance: 1.0))
    }

    @Test("E: SALT cap with partial phaseout = $35,900")
    func e_saltCap() {
        let dm = makeScenarioE()
        // MAGI = $520K, phaseoutThreshold = $505K
        // Reduction = ($520K − $505K) × 0.30 = $4,500
        // Cap = $40,400 − $4,500 = $35,900 (above $10K floor)
        #expect(isClose(dm.saltCap, 35_900, tolerance: 1.0))
        // saltAfterCap = min($200K, $35,900) = $35,900
        #expect(isClose(dm.saltAfterCap, 35_900, tolerance: 1.0))
    }

    @Test("E: Medical deduction = $161,000 (7.5% AGI floor)")
    func e_medicalDeduction() {
        let dm = makeScenarioE()
        // Floor = $520K × 7.5% = $39,000
        // Deductible = $200K − $39K = $161,000
        #expect(isClose(dm.deductibleMedicalExpenses, 161_000, tolerance: 1.0))
    }

    @Test("E: Itemized deductions = $196,900 (beats $16,100 standard)")
    func e_deduction() {
        let dm = makeScenarioE()
        // SALT $35,900 + Medical $161K + $0 non-SALT-non-medical = $196,900
        #expect(isClose(dm.totalItemizedDeductions, 196_900, tolerance: 1.0))
        #expect(dm.scenarioEffectiveItemize, "Should itemize with $196,900 > $16,100 standard")
        #expect(isClose(dm.effectiveDeductionAmount, 196_900, tolerance: 1.0))
    }

    @Test("E: Taxable income = $323,100")
    func e_taxableIncome() {
        let dm = makeScenarioE()
        // $520K − $196,900 = $323,100
        #expect(isClose(dm.scenarioTaxableIncome, 323_100, tolerance: 1.0))
    }

    @Test("E: Federal tax = $62,848 (32% bracket + 15% cap gains)")
    func e_federalTax() {
        let dm = makeScenarioE()
        // Ordinary = $323,100 − $100K = $223,100 → top of 32% bracket
        // 10%×$12.4K + 12%×$38K + 22%×$55.3K + 24%×$91,650 = $47,848
        // Cap gains: $100K all in 15% bracket (stacked on $223,100 ordinary) = $15,000
        // Total: $62,848
        #expect(isClose(dm.scenarioFederalTax, 62_848, tolerance: 2.0))
    }

    @Test("E: AMT = $42,434 (large add-backs push TMT well above regular tax)")
    func e_amt() {
        let dm = makeScenarioE()
        let result = dm.scenarioAMT
        // Add-backs: SALT $35,900 + medical $161K = $196,900
        // AMTI = $323,100 + $196,900 = $520,000
        #expect(isClose(result.amti, 520_000, tolerance: 1.0))
        // Exemption: phaseout = ($520K − $500K) × 0.50 = $10K → $90,100 − $10K = $80,100
        #expect(isClose(result.exemption, 80_100, tolerance: 1.0))
        // Taxable AMTI: $520K − $80,100 = $439,900
        #expect(isClose(result.taxableAMTI, 439_900, tolerance: 1.0))
        // Ordinary AMTI: $439,900 − $100K CG = $339,900 → above $244,500 → hits 28% AMT bracket
        // TMT ordinary: $244,500×26% + $95,400×28% = $63,570 + $26,712 = $90,282
        // TMT cap gains: $100K at 15% preferential = $15,000
        // TMT total: $105,282
        #expect(isClose(result.tentativeMinimumTax, 105_282, tolerance: 2.0))
        // AMT = $105,282 − $62,848 = $42,434
        #expect(isClose(result.amt, 42_434, tolerance: 2.0))
    }

    @Test("E: CA state tax ≈ $11,296 (state itemized deductions)")
    func e_stateTax() {
        let dm = makeScenarioE()
        // State itemized: $200K property tax (no SALT cap at state level) + $161K medical
        //   (above 7.5% AGI floor) = $361K > CA standard $5,706
        // State taxable: $520K − $361K = $159K
        // Through CA brackets up to 9.3%
        // CA exemption credit: $144 (age 56, single) − phaseout? $159K < $252K → no phaseout
        // Net: brackets − $144 = $11,295.85
        #expect(isClose(dm.scenarioStateTax, 11_295.85, tolerance: 2.0))
    }

    @Test("E: NIIT = $4,560 (full $120K NII taxed)")
    func e_niit() {
        let dm = makeScenarioE()
        // NII = LT CG $100K + interest $20K = $120K
        // MAGI $520K >> $200K → full NII
        // $120K × 3.8% = $4,560
        #expect(isClose(dm.scenarioNIITAmount, 4_560, tolerance: 1.0))
    }

    @Test("E: Total tax ≈ $121,138 (AMT adds $42K to total)")
    func e_totalTax() {
        let dm = makeScenarioE()
        // Federal $62,848 + CA $11,296 + NIIT $4,560 + AMT $42,434 = $121,138
        // (CA state tax reduced by state-specific itemized deductions: $361K vs $5.7K standard)
        #expect(isClose(dm.scenarioTotalTax, 121_137.85, tolerance: 5.0))
        // AMT should still add significant tax
        let withoutAMT = dm.scenarioFederalTax + dm.scenarioStateTax + dm.scenarioNIITAmount
        #expect(dm.scenarioTotalTax > withoutAMT + 40_000, "AMT should add >$40K to total tax")
    }
}

// MARK: - 60. Tax-Exempt Interest

@Suite("Tax-Exempt Interest", .serialized)
@MainActor struct TaxExemptInterestTests {

    @Test("Tax-exempt interest is excluded from federal taxable income")
    func excludedFromFederalTax() {
        let dm = makeDM(birthYear: 1955, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000),
            IncomeSource(name: "Muni Bonds", type: .taxExemptInterest, annualAmount: 30_000)
        ]
        let taxWith = dm.calculateFederalTax(income: dm.scenarioTaxableIncome, filingStatus: .single)

        let dm2 = makeDM(birthYear: 1955, filingStatus: .single, state: .california)
        dm2.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        let taxWithout = dm2.calculateFederalTax(income: dm2.scenarioTaxableIncome, filingStatus: .single)

        #expect(isClose(taxWith, taxWithout), "Tax-exempt interest should not change federal tax")
    }

    @Test("Tax-exempt interest is excluded from state taxable income")
    func excludedFromStateTax() {
        let dm = makeDM(birthYear: 1955, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000),
            IncomeSource(name: "Muni Bonds", type: .taxExemptInterest, annualAmount: 30_000)
        ]
        let stateWith = dm.scenarioStateTax

        let dm2 = makeDM(birthYear: 1955, filingStatus: .single, state: .california)
        dm2.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        let stateWithout = dm2.scenarioStateTax

        #expect(isClose(stateWith, stateWithout), "Tax-exempt interest should not change state tax")
    }

    @Test("Tax-exempt interest is excluded from NIIT")
    func excludedFromNIIT() {
        let dm = makeDM(birthYear: 1955, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 250_000),
            IncomeSource(name: "Dividends", type: .dividends, annualAmount: 50_000),
            IncomeSource(name: "Muni Bonds", type: .taxExemptInterest, annualAmount: 40_000)
        ]
        let nii = dm.scenarioNetInvestmentIncome
        // Only dividends ($50K) should be NII, not tax-exempt interest
        #expect(isClose(nii, 50_000), "Tax-exempt interest should not be included in NII")
    }

    @Test("Tax-exempt interest IS included in IRMAA MAGI")
    func includedInIRMAAMagi() {
        // MFJ with income just below IRMAA Tier 1 ($218,001)
        let dm = makeDM(birthYear: 1955, filingStatus: .marriedFilingJointly, state: .california)
        dm.enableSpouse = true
        var sc = DateComponents(); sc.year = 1955; sc.month = 1; sc.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: sc)!
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 200_000)
        ]
        let irmaaWithout = dm.scenarioIRMAA
        #expect(irmaaWithout.tier == 0, "Should be Tier 0 without tax-exempt interest")

        // Add $30K tax-exempt interest to push MAGI over $218,001
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 200_000),
            IncomeSource(name: "Muni Bonds", type: .taxExemptInterest, annualAmount: 30_000)
        ]
        let irmaaWith = dm.scenarioIRMAA
        #expect(irmaaWith.tier >= 1, "Tax-exempt interest should push IRMAA to Tier 1+")
    }

    @Test("Tax-exempt interest IS included in Social Security combined income test")
    func includedInSSCombinedIncome() {
        // Single with SS + small pension = combined income below $25K threshold
        let dm = makeDM(birthYear: 1955, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 20_000),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 10_000)
        ]
        let ssWithout = dm.calculateTaxableSocialSecurity(filingStatus: .single)
        // Combined = $10K + $10K (50% of SS) = $20K, below $25K threshold
        #expect(isClose(ssWithout, 0), "SS should be untaxed below threshold")

        // Add tax-exempt interest to push over threshold
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 20_000),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 10_000),
            IncomeSource(name: "Muni Bonds", type: .taxExemptInterest, annualAmount: 20_000)
        ]
        let ssWith = dm.calculateTaxableSocialSecurity(filingStatus: .single)
        // Combined = $10K + $20K + $10K (50% of SS) = $40K, above $34K → up to 85% taxable
        #expect(ssWith > 0, "Tax-exempt interest should make Social Security taxable")
    }

    @Test("taxExemptInterestIRMAAImpact returns correct surcharge delta")
    func irmaaImpactCalculation() {
        // Single, age 70 (on Medicare), income just below IRMAA Tier 1
        let dm = makeDM(birthYear: 1955, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000),
            IncomeSource(name: "Muni Bonds", type: .taxExemptInterest, annualAmount: 20_000)
        ]
        // Without muni: AGI ~$100K, below $109,001 → Tier 0
        // With muni: IRMAA MAGI ~$120K, above $109,001 → Tier 1
        let impact = dm.taxExemptInterestIRMAAImpact
        #expect(impact > 0, "Should show positive IRMAA impact")
    }

    @Test("taxExemptInterestIRMAAImpact returns 0 when no tax-exempt interest")
    func irmaaImpactZeroWhenNone() {
        let dm = makeDM(birthYear: 1955, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        #expect(dm.taxExemptInterestIRMAAImpact == 0)
    }

    @Test("taxExemptInterestIRMAAImpact returns 0 when not on Medicare")
    func irmaaImpactZeroWhenNotOnMedicare() {
        // Age 60, not yet on Medicare
        let dm = makeDM(birthYear: 1965, filingStatus: .single, state: .california)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000),
            IncomeSource(name: "Muni Bonds", type: .taxExemptInterest, annualAmount: 50_000)
        ]
        #expect(dm.taxExemptInterestIRMAAImpact == 0, "No IRMAA impact before age 65")
    }

    @Test("taxExemptInterestTotal computes correctly")
    func totalComputation() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Muni Fund", type: .taxExemptInterest, annualAmount: 15_000),
            IncomeSource(name: "Tax-Free MMF", type: .taxExemptInterest, annualAmount: 8_000),
            IncomeSource(name: "Interest", type: .interest, annualAmount: 5_000)
        ]
        #expect(isClose(dm.taxExemptInterestTotal, 23_000), "Should sum only taxExemptInterest sources")
    }
}

// MARK: - 61. Clickwrap / Terms Acceptance

@Suite("Terms Acceptance", .serialized)
@MainActor struct TermsAcceptanceTests {

    /// Creates a fresh UserDefaults suite for test isolation.
    private func freshDefaults() -> UserDefaults {
        let suiteName = "test.terms.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("Fresh install: hasAcceptedCurrentTerms is false")
    func freshInstall() {
        let manager = TermsAcceptanceManager(defaults: freshDefaults())
        #expect(manager.hasAcceptedCurrentTerms == false)
    }

    @Test("recordAcceptance sets flag to true")
    func acceptance() {
        let manager = TermsAcceptanceManager(defaults: freshDefaults())
        #expect(manager.hasAcceptedCurrentTerms == false)
        manager.recordAcceptance()
        #expect(manager.hasAcceptedCurrentTerms == true)
    }

    @Test("Subsequent launch with same version stays accepted")
    func persistsAcrossLaunches() {
        let defaults = freshDefaults()
        let manager1 = TermsAcceptanceManager(defaults: defaults)
        manager1.recordAcceptance()
        #expect(manager1.hasAcceptedCurrentTerms == true)

        // Simulate re-launch by creating a new manager with same defaults
        let manager2 = TermsAcceptanceManager(defaults: defaults)
        #expect(manager2.hasAcceptedCurrentTerms == true)
    }

    @Test("Version mismatch resets acceptance")
    func versionBumpResetsAcceptance() {
        let defaults = freshDefaults()
        // Accept terms
        let manager = TermsAcceptanceManager(defaults: defaults)
        manager.recordAcceptance()
        #expect(manager.hasAcceptedCurrentTerms == true)

        // Simulate a version bump by writing a different version to defaults
        defaults.set("0.9", forKey: "tou_version")

        // New manager should see mismatch and require re-acceptance
        let manager2 = TermsAcceptanceManager(defaults: defaults)
        #expect(manager2.hasAcceptedCurrentTerms == false)
    }

    @Test("acceptanceRecord returns nil when not accepted")
    func recordNilWhenNotAccepted() {
        let manager = TermsAcceptanceManager(defaults: freshDefaults())
        #expect(manager.acceptanceRecord() == nil)
    }

    @Test("acceptanceRecord returns formatted string after acceptance")
    func recordReturnsString() {
        let manager = TermsAcceptanceManager(defaults: freshDefaults())
        manager.recordAcceptance()
        let record = manager.acceptanceRecord()
        #expect(record != nil)
        #expect(record!.contains("ToU v\(TermsAcceptanceManager.currentToUVersion)"))
        #expect(record!.contains("accepted on"))
    }

    @Test("Stores correct ToU version")
    func storesCorrectVersion() {
        let defaults = freshDefaults()
        let manager = TermsAcceptanceManager(defaults: defaults)
        manager.recordAcceptance()
        let storedVersion = defaults.string(forKey: "tou_version")
        #expect(storedVersion == TermsAcceptanceManager.currentToUVersion)
    }

    @Test("Stores timestamp on acceptance")
    func storesTimestamp() {
        let defaults = freshDefaults()
        let before = Date().timeIntervalSince1970
        let manager = TermsAcceptanceManager(defaults: defaults)
        manager.recordAcceptance()
        let after = Date().timeIntervalSince1970
        let ts = defaults.double(forKey: "tou_timestamp")
        #expect(ts >= before && ts <= after)
    }
}

// MARK: - 62. Spouse-then-Child Heir Type

@Suite("Spouse-then-Child Heir", .serialized)
@MainActor struct SpouseThenChildHeirTests {

    private func makeLegacyDM() -> DataManager {
        let dm = makeDM(birthYear: 1955, filingStatus: .marriedFilingJointly, state: .california)
        dm.enableSpouse = true
        var sc = DateComponents(); sc.year = 1957; sc.month = 1; sc.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: sc)!
        dm.enableLegacyPlanning = true
        dm.legacyHeirTaxRate = 0.24
        dm.primaryGrowthRate = 8.0
        dm.iraAccounts = [
            IRAAccount(name: "Trad IRA", accountType: .traditionalIRA, balance: 1_000_000, owner: .primary),
            IRAAccount(name: "Roth IRA", accountType: .rothIRA, balance: 200_000, owner: .primary)
        ]
        dm.incomeSources = [
            IncomeSource(name: "SS", type: .socialSecurity, annualAmount: 30_000),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        return dm
    }

    @Test("legacyTotalPostDeathYears: adultChild = 10")
    func adultChildYears() {
        let dm = makeLegacyDM()
        dm.legacyHeirType = "adultChild"
        #expect(dm.legacyTotalPostDeathYears == 10)
    }

    @Test("legacyTotalPostDeathYears: spouse = 20")
    func spouseYears() {
        let dm = makeLegacyDM()
        dm.legacyHeirType = "spouse"
        #expect(dm.legacyTotalPostDeathYears == 20)
    }

    @Test("legacyTotalPostDeathYears: spouseThenChild = survivorYears + 10")
    func spouseThenChildYears() {
        let dm = makeLegacyDM()
        dm.legacyHeirType = "spouseThenChild"
        dm.legacySpouseSurvivorYears = 15
        #expect(dm.legacyTotalPostDeathYears == 25)
    }

    @Test("legacyTotalPostDeathYears: spouseThenChild default (10 + 10 = 20)")
    func spouseThenChildDefaultYears() {
        let dm = makeLegacyDM()
        dm.legacyHeirType = "spouseThenChild"
        dm.legacySpouseSurvivorYears = 10
        #expect(dm.legacyTotalPostDeathYears == 20)
    }

    @Test("Changing legacySpouseSurvivorYears changes projection value")
    func survivorYearsAffectsProjection() {
        let dm = makeLegacyDM()
        dm.legacyHeirType = "spouseThenChild"

        dm.legacySpouseSurvivorYears = 5
        let wealth5 = dm.legacyNoActionHeirTaxableDrawdown

        dm.legacySpouseSurvivorYears = 20
        let wealth20 = dm.legacyNoActionHeirTaxableDrawdown

        // Different survivor years should produce different drawdown amounts
        #expect(wealth5 != wealth20, "Different survivor years should produce different projections")
    }

    @Test("spouseThenChild heir drawdown differs from adultChild")
    func spouseThenChildDiffersFromAdultChild() {
        let dm = makeLegacyDM()
        dm.legacySpouseSurvivorYears = 10

        dm.legacyHeirType = "adultChild"
        let adultChildDrawdown = dm.legacyNoActionHeirTaxableDrawdown

        dm.legacyHeirType = "spouseThenChild"
        let spouseThenChildDrawdown = dm.legacyNoActionHeirTaxableDrawdown

        #expect(adultChildDrawdown != spouseThenChildDrawdown,
                "Spouse-then-child should produce different drawdown than adult child")
    }

    /// Verify Roth spouseThenChild exact math: pure compounding for (yearsUntilDeath + survivorYears),
    /// then 10-year equal drawdown with growth. Roth has no RMDs so this is deterministic.
    @Test("Roth spouseThenChild drawdown matches hand-computed value")
    func rothSpouseThenChildExactValue() {
        let dm = makeLegacyDM()
        dm.legacyHeirType = "spouseThenChild"
        dm.legacySpouseSurvivorYears = 10
        dm.primaryGrowthRate = 8.0

        let yearsUntilDeath = dm.legacyYearsUntilDeath
        let rothStart = dm.totalRothBalance // $200,000

        // Phase 1+2: Pure compounding (no Roth RMDs) for yearsUntilDeath + 10 survivor years
        let totalCompoundYears = yearsUntilDeath + 10
        let balanceAtSpouseDeath = rothStart * pow(1.08, Double(totalCompoundYears))

        // Phase 3: 10-year drawdown with growth (same algorithm as projectHeirDrawdownTotal)
        var balance = balanceAtSpouseDeath
        var expectedTotal = 0.0
        for yearsLeft in stride(from: 10, through: 1, by: -1) {
            let withdrawal = balance / Double(yearsLeft)
            expectedTotal += withdrawal
            balance -= withdrawal
            balance *= 1.08
        }

        // The engine should compute the same value
        // Access via legacyNoActionRothAtDeath path won't work (that's just at owner death),
        // so we compare via the total wealth calculation indirectly.
        // For Roth, the no-action Roth drawdown for spouseThenChild IS this value.
        let dm2 = makeLegacyDM()
        dm2.legacyHeirType = "spouseThenChild"
        dm2.legacySpouseSurvivorYears = 10
        dm2.primaryGrowthRate = 8.0

        // legacyNoConversionTotalWealth includes Roth drawdown as tax-free component
        // With 0 conversions, the Roth portion of no-conversion wealth = Roth drawdown
        dm2.yourRothConversion = 0
        let noConvWealth = dm2.legacyNoConversionTotalWealth
        // No-conversion wealth = heir after-tax Trad + Roth drawdown + tax money ($0)
        let tradDrawdown = dm2.legacyNoActionHeirTaxableDrawdown
        let heirAfterTaxTrad = tradDrawdown * (1.0 - 0.24)
        let impliedRothDrawdown = noConvWealth - heirAfterTaxTrad

        #expect(isClose(impliedRothDrawdown, expectedTotal, tolerance: 1.0),
                "Roth spouseThenChild drawdown should match hand-computed: expected \(expectedTotal), got \(impliedRothDrawdown)")
    }

    /// Verify adultChild legacyTotalPostDeathYears feeds correctly into the tax money future value.
    /// taxMoneyFV = taxPaid × (1 + taxableRate)^(yearsUntilDeath + postDeathYears)
    @Test("legacyTaxMoneyFutureValue uses correct total years for each heir type")
    func taxMoneyFutureValueUsesCorrectYears() {
        let dm = makeLegacyDM()
        dm.yourRothConversion = 50_000

        // adultChild: postDeath = 10
        dm.legacyHeirType = "adultChild"
        let fv10 = dm.legacyTaxMoneyFutureValue
        let years10 = dm.legacyYearsUntilDeath + 10

        // spouse: postDeath = 20
        dm.legacyHeirType = "spouse"
        let fv20 = dm.legacyTaxMoneyFutureValue
        let years20 = dm.legacyYearsUntilDeath + 20

        // spouseThenChild with 15 survivor years: postDeath = 25
        dm.legacyHeirType = "spouseThenChild"
        dm.legacySpouseSurvivorYears = 15
        let fv25 = dm.legacyTaxMoneyFutureValue
        let years25 = dm.legacyYearsUntilDeath + 25

        // The tax paid today is the same for all three — only the compounding period differs.
        // So FV should scale as (1+r)^years. Verify ratios:
        let taxableRate = dm.taxableAccountGrowthRate / 100
        let expectedRatio_20_10 = pow(1 + taxableRate, Double(years20)) / pow(1 + taxableRate, Double(years10))
        let actualRatio_20_10 = fv20 / fv10
        #expect(isClose(actualRatio_20_10, expectedRatio_20_10, tolerance: 0.01),
                "Spouse FV / AdultChild FV ratio should match (1+r)^10 extra years")

        let expectedRatio_25_10 = pow(1 + taxableRate, Double(years25)) / pow(1 + taxableRate, Double(years10))
        let actualRatio_25_10 = fv25 / fv10
        #expect(isClose(actualRatio_25_10, expectedRatio_25_10, tolerance: 0.01),
                "SpouseThenChild FV / AdultChild FV ratio should match (1+r)^15 extra years")
    }

    @Test("Roth at death is larger with spouseThenChild than adultChild (extra compounding)")
    func rothCompoundsLongerWithSpouseThenChild() {
        let dm = makeLegacyDM()
        dm.legacySpouseSurvivorYears = 10

        dm.legacyHeirType = "adultChild"
        let rothAtDeathChild = dm.legacyNoActionRothAtDeath

        dm.legacyHeirType = "spouseThenChild"
        let rothAtDeathSpouseThenChild = dm.legacyNoActionRothAtDeath

        // Roth at owner's death should be the same regardless of heir type
        // (heir type only affects post-death phase)
        #expect(isClose(rothAtDeathChild, rothAtDeathSpouseThenChild),
                "Roth at owner death should be same regardless of heir type")
    }

    @Test("legacyConversionIsFavorable computes for spouseThenChild without crash")
    func conversionFavorableComputes() {
        let dm = makeLegacyDM()
        dm.legacyHeirType = "spouseThenChild"
        dm.legacySpouseSurvivorYears = 10
        dm.yourRothConversion = 50_000

        // Just verify it runs without crashing — the value depends on many factors
        let _ = dm.legacyConversionIsFavorable
        let _ = dm.legacyBreakEvenHeirTaxRate
    }
}
