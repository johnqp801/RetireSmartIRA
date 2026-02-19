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
    let dm = DataManager()
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

@Suite("Federal Tax — Single")
struct FederalTaxSingleTests {

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

    @Test("$50,000 (22% bracket) → $5,914.00")
    func mid22Percent() {
        let dm = makeDM()
        // 10% on 11,925 = 1,192.50
        // 12% on 36,550 = 4,386.00
        // 22% on 1,525 = 335.50
        let tax = dm.calculateFederalTax(income: 50_000, filingStatus: .single)
        #expect(isClose(tax, 5_914.00))
    }

    @Test("$150,000 (24% bracket) → $28,847.00")
    func mid24Percent() {
        let dm = makeDM()
        // 10% on 11,925 = 1,192.50
        // 12% on 36,550 = 4,386.00
        // 22% on 54,875 = 12,072.50
        // 24% on 46,650 = 11,196.00
        let tax = dm.calculateFederalTax(income: 150_000, filingStatus: .single)
        #expect(isClose(tax, 28_847.00))
    }

    @Test("$700,000 (37% bracket) → $216,020.25")
    func in37Percent() {
        let dm = makeDM()
        // 10% on 11,925 = 1,192.50
        // 12% on 36,550 = 4,386.00
        // 22% on 54,875 = 12,072.50
        // 24% on 93,950 = 22,548.00
        // 32% on 53,225 = 17,032.00
        // 35% on 375,825 = 131,538.75
        // 37% on 73,650 = 27,250.50
        let tax = dm.calculateFederalTax(income: 700_000, filingStatus: .single)
        #expect(isClose(tax, 216_020.25))
    }
}

// MARK: - 2. Federal Tax — Married Filing Jointly

@Suite("Federal Tax — MFJ")
struct FederalTaxMFJTests {

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

    @Test("$100,000 (22% bracket) → $11,828.00")
    func mid22Percent() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        // 10% on 23,850 = 2,385.00
        // 12% on 73,100 = 8,772.00
        // 22% on 3,050 = 671.00
        let tax = dm.calculateFederalTax(income: 100_000, filingStatus: .marriedFilingJointly)
        #expect(isClose(tax, 11_828.00))
    }

    @Test("$300,000 (24% bracket) → $57,694.00")
    func mid24Percent() {
        let dm = makeDM(filingStatus: .marriedFilingJointly)
        // 10% on 23,850 = 2,385.00
        // 12% on 73,100 = 8,772.00
        // 22% on 109,750 = 24,145.00
        // 24% on 93,300 = 22,392.00
        let tax = dm.calculateFederalTax(income: 300_000, filingStatus: .marriedFilingJointly)
        #expect(isClose(tax, 57_694.00))
    }
}

// MARK: - 3. State Tax (California default)

@Suite("State Tax — California")
struct CaliforniaTaxTests {

    @Test("$0 income → $0 tax")
    func zeroIncome() {
        let dm = makeDM()
        let tax = dm.calculateStateTax(income: 0, filingStatus: .single)
        #expect(isClose(tax, 0))
    }

    @Test("$50,000 (6% bracket) → $1,623.02")
    func mid6Percent() {
        let dm = makeDM()
        // 1% on 10,412 = 104.12
        // 2% on 14,272 = 285.44
        // 4% on 14,275 = 571.00
        // 6% on 11,041 = 662.46
        let tax = dm.calculateStateTax(income: 50_000, filingStatus: .single)
        #expect(isClose(tax, 1_623.02))
    }

    @Test("$100,000 (9.3% bracket) → $5,952.85")
    func mid93Percent() {
        let dm = makeDM()
        // 1% on 10,412 = 104.12
        // 2% on 14,272 = 285.44
        // 4% on 14,275 = 571.00
        // 6% on 15,122 = 907.32
        // 8% on 14,269 = 1,141.52
        // 9.3% on 31,650 = 2,943.45
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 5_952.85))
    }
}

// MARK: - 4. Social Security Taxation

@Suite("Social Security Taxation")
struct SocialSecurityTaxTests {

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

@Suite("RMD Calculations")
struct RMDCalculationTests {

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

@Suite("RMD Age Rules")
struct RMDAgeTests {

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

@Suite("Medical Deduction Floor")
struct MedicalDeductionTests {

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

@Suite("Standard vs Itemized Deduction")
struct DeductionChoiceTests {

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

@Suite("Capital Gains Preferential Rates")
struct CapitalGainsTaxTests {

    @Test("Ordinary $40K + LTCG $20K → $6,309.00")
    func ltcgPartiallyAt0Percent() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000),
            IncomeSource(name: "LTCG", type: .capitalGainsLong, annualAmount: 20_000)
        ]
        // Ordinary tax on $40K = 4,561.50
        // Cap gains: 0% up to 48,350, then 15%
        //   taxOnTotal(60K) = 1,747.50; taxOnOrdinary(40K) = 0
        //   capGainsTax = 1,747.50
        // Total = 4,561.50 + 1,747.50 = 6,309.00
        let tax = dm.calculateFederalTax(income: 60_000, filingStatus: .single)
        #expect(isClose(tax, 6_309.00))
    }

    @Test("Ordinary $50K + LTCG $50K → $13,414.00")
    func ltcgMostlyAt15Percent() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000),
            IncomeSource(name: "LTCG", type: .capitalGainsLong, annualAmount: 50_000)
        ]
        // Ordinary tax on $50K = 5,914.00
        // Cap gains tax = 7,500.00
        // Total = 13,414.00
        let tax = dm.calculateFederalTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 13_414.00))
    }
}

// MARK: - 10. Life Expectancy Factor Lookup

@Suite("Life Expectancy Factors")
struct LifeExpectancyTests {

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

@Suite("Marginal Rates")
struct MarginalRateTests {

    @Test("Federal marginal at $50K (single) → 22%")
    func federalMarginalSingle() {
        let dm = makeDM()
        let rate = dm.federalMarginalRate(income: 50_000, filingStatus: .single)
        #expect(isClose(rate, 22.0, tolerance: 0.1))
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

@Suite("Balance Aggregation")
struct BalanceTests {

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

@Suite("SLE Table I")
struct SLETableTests {

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

@Suite("Inherited IRA RMD")
struct InheritedIRARMDTests {

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

@Suite("AccountType Properties")
struct AccountTypeTests {

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

@Suite("IRMAA Tier Calculations")
struct IRMAATierTests {

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

@Suite("IRMAA Scenario Impact")
struct IRMAAScenarioTests {

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

@Suite("State Tax — No Income Tax States")
struct NoIncomeTaxStateTests {

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

@Suite("State Tax — Flat Tax States")
struct FlatTaxStateTests {

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

@Suite("State Tax — Progressive States")
struct ProgressiveTaxStateTests {

    @Test("California $100K preserved (regression test)")
    func californiaRegression() {
        let dm = makeDM(state: .california)
        let tax = dm.calculateStateTax(income: 100_000, filingStatus: .single)
        #expect(isClose(tax, 5_952.85))
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

@Suite("State Tax — Retirement Exemptions")
struct RetirementExemptionTests {

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

@Suite("State Tax — Cross-State Comparison")
struct CrossStateComparisonTests {

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

@Suite("State Tax — Breakdown Detail")
struct StateTaxBreakdownTests {

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
        // Sum of bracket taxes should equal total
        let bracketSum = bd.bracketBreakdown.reduce(0) { $0 + $1.taxFromBracket }
        #expect(isClose(bracketSum, bd.totalStateTax))
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

    @Test("Breakdown totalStateTax matches calculateStateTax for all states")
    func breakdownMatchesCalculation() {
        let dm = makeDMWithRetirementIncome(ss: 20_000, pension: 40_000, rmd: 30_000, other: 10_000, state: .california)
        for state in USState.allCases {
            let bd = dm.stateTaxBreakdown(forState: state, filingStatus: .single)
            let calcTax = dm.calculateStateTax(income: dm.scenarioTaxableIncome, forState: state, filingStatus: .single)
            #expect(isClose(bd.totalStateTax, calcTax), "Breakdown mismatch for \(state.rawValue): breakdown=\(bd.totalStateTax) vs calc=\(calcTax)")
        }
    }
}

// MARK: - 23. Inherited Extra Withdrawals

@Suite("Inherited Extra Withdrawals")
struct InheritedExtraWithdrawalTests {

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

@Suite("Inherited Extra Withdrawal Tax Impact")
struct InheritedExtraWithdrawalTaxImpactTests {

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

@Suite("Stock Donation — Short-Term Support")
struct StockDonationShortTermTests {

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

    @Test("Short-term avoided tax ≥ long-term for same gain (ordinary rate ≥ cap gains)")
    func shortTermAvoidedTaxHigherOrEqual() {
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

        #expect(dmShort.stockCapGainsTaxAvoided >= dmLong.stockCapGainsTaxAvoided)
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

@Suite("Stock Donation Tax Savings")
struct StockDonationTaxSavingsTests {

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
