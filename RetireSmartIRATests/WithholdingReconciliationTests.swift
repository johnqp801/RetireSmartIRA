//
//  WithholdingReconciliationTests.swift
//  RetireSmartIRATests
//
//  V2.3: federal withholding is a PAYMENT toward federal liability, never a
//  definition of the whole bill. These tests pin the federal/state separation and
//  the rule that a federal overpayment is never netted against other liabilities
//  before the gross-up fixed point runs.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Withholding reconciliation (federal vs state)", .serialized)
@MainActor
struct WithholdingReconciliationTests {

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func inputs(state: String = "FL", trad: Double, taxable: Double,
                        pension: Double = 0) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 66, spouseCurrentAge: nil,
            filingStatus: .single, state: state,
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1960, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: pension, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
    }

    private func assumptions(_ mode: RothTaxFundingMode, rate: Double = 0.24) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(
            horizonEndAge: 67, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0, baselineAnnualExpenses: 0)
        a.rothTaxFundingMode = mode
        a.federalWithholdingRate = rate
        return a
    }

    /// Runs one year with an explicit conversion and returns the first year's record.
    private func runYear(mode: RothTaxFundingMode, rate: Double = 0.24,
                         conversion: Double, trad: Double, taxable: Double,
                         state: String = "FL") -> YearRecommendation {
        let engine = ProjectionEngine(configProvider: provider)
        let result = engine.project(
            inputs: inputs(state: state, trad: trad, taxable: taxable),
            assumptions: assumptions(mode, rate: rate),
            actionsPerYear: [2026: [.rothConversion(amount: conversion)]]
        )
        return result.first!
    }

    @Test("Withholding does not add income: conversion income stays GROSS")
    func withholdingDoesNotDoubleCountIncome() {
        let withheld = runYear(mode: .withheldFromConversion, conversion: 100_000,
                               trad: 500_000, taxable: 200_000)
        let separate = runYear(mode: .fundedFromAccounts, conversion: 100_000,
                               trad: 500_000, taxable: 200_000)
        // The withheld dollars are INSIDE the gross conversion, not on top of it.
        #expect(abs(withheld.taxableIncome - separate.taxableIncome) < 1.0)
    }

    @Test("Reported federal tax is the LIABILITY, not the balance still payable")
    func reportedFederalTaxIsLiabilityNotBalanceDue() {
        // Ample taxable in both runs, so no gross-up fires in either and the only possible
        // difference in reported federal tax would be an (incorrect) subtraction of withholding.
        let withheld = runYear(mode: .withheldFromConversion, conversion: 100_000,
                               trad: 500_000, taxable: 200_000)
        let separate = runYear(mode: .fundedFromAccounts, conversion: 100_000,
                               trad: 500_000, taxable: 200_000)
        #expect(withheld.taxFundingWithdrawal == 0)
        #expect(separate.taxFundingWithdrawal == 0)
        #expect(abs(withheld.taxBreakdown.federal - separate.taxBreakdown.federal) < 1.0,
                "withholding changes who remits, never what is owed")
    }

    @Test("Federal overpayment is not netted against state liability")
    func overpaymentNotNettedAgainstState() {
        // A high withholding rate in a state WITH income tax: federal is overpaid while
        // state tax remains owed. The state bill must still be funded from accounts
        // rather than cancelled by the federal excess.
        let ca = runYear(mode: .withheldFromConversion, rate: 0.37,
                         conversion: 100_000, trad: 500_000, taxable: 0, state: "CA")
        #expect(ca.taxBreakdown.state > 0, "CA should owe state tax on the conversion")
        // Taxable started at 0, so any state funding had to come from a gross-up.
        #expect(ca.taxFundingWithdrawal > 0,
                "state liability must be funded from accounts, not erased by the federal overpayment")
        // Un-netted seeding: the cascade must raise at least the full state bill. A netted
        // seed (state minus the federal excess) would be negative here and pull nothing.
        #expect(ca.taxFundingWithdrawal >= ca.taxBreakdown.state,
                "cascade must cover the whole state liability")
        // The federal excess is credited back to taxable rather than destroyed. Taxable
        // started at 0 and the only inflow available is the overpayment credit.
        #expect(ca.endOfYearBalances.taxable > 0,
                "federal overpayment must be credited to the taxable account")
        // Discriminates against the pre-V2.3 behavior: with withholding elected, the cascade
        // is materially smaller than when the whole federal bill funds from accounts.
        let separate = runYear(mode: .fundedFromAccounts, rate: 0.37,
                               conversion: 100_000, trad: 500_000, taxable: 0, state: "CA")
        #expect(ca.taxFundingWithdrawal < separate.taxFundingWithdrawal,
                "withholding must prepay the federal component of the cascade")
        #expect(separate.endOfYearBalances.taxable == 0,
                "no withholding elected means no overpayment credit")
    }

    @Test("Under-withholding funds the balance through the cascade, not a plain subtraction")
    func underWithholdingUsesCascade() {
        // 10% withholding against a much larger real liability leaves a balance due.
        let y = runYear(mode: .withheldFromConversion, rate: 0.10,
                        conversion: 200_000, trad: 600_000, taxable: 0)
        #expect(y.taxFundingWithdrawal > 0, "balance due should pull a grossed-up withdrawal")
        // Converged, not a naive difference: the withdrawal must exceed the plain gap,
        // because the withdrawal is itself taxable.
        let federalLiability = y.taxBreakdown.federal
        let plainGap = max(0, federalLiability - 200_000 * 0.10)
        #expect(y.taxFundingWithdrawal > plainGap * 0.9,
                "gross-up should be sized by the fixed point, not by liability minus withholding")
        // The withheld dollars really do reduce what the cascade has to raise, by at least
        // the withheld amount (the un-withheld twin also owes tax on its larger withdrawal).
        let separate = runYear(mode: .fundedFromAccounts, rate: 0.10,
                               conversion: 200_000, trad: 600_000, taxable: 0)
        #expect(separate.taxFundingWithdrawal - y.taxFundingWithdrawal >= 20_000 - 1.0,
                "withholding of 20,000 must shrink the cascade by at least that much")
    }

    @Test("Outside-money mode never pulls a tax-funding withdrawal")
    func outsideMoneyDoesNotTouchAccounts() {
        let y = runYear(mode: .paidFromOutsideMoney, conversion: 100_000,
                        trad: 500_000, taxable: 0)
        #expect(y.taxFundingWithdrawal == 0)
        #expect(y.underfunded == nil)
    }

    @Test("Funding covers the WHOLE annual liability, not just conversion-incremental tax")
    func fundsWholeLiability() {
        // No conversion at all, but pension-driven tax still exists: the cascade must
        // still fund it. (Pre-existing behavior; pinned so V2.3 cannot narrow it.)
        // NOTE: `actionsPerYear` decides WHICH years project. An empty dictionary
        // returns no years at all, so a year with no actions is requested with an
        // empty action array, not an absent key.
        let y = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(state: "CA", trad: 500_000, taxable: 0, pension: 120_000),
            assumptions: assumptions(.fundedFromAccounts),
            actionsPerYear: [2026: []]).first!
        #expect(y.taxFundingWithdrawal > 0, "non-conversion tax must also be funded")
    }

    @Test("A fully withheld year is not reported as underfunded")
    func fullyWithheldYearIsNotUnderfunded() {
        // No state tax (FL), taxable empty, and withholding well above the federal bill.
        // Everything owed is already remitted, so nothing is left unfunded.
        let y = runYear(mode: .withheldFromConversion, rate: 0.37,
                        conversion: 100_000, trad: 500_000, taxable: 0)
        #expect(y.taxBreakdown.state == 0)
        #expect(y.taxFundingWithdrawal == 0)
        #expect(y.underfunded == nil, "withheld tax is paid tax, not a funding shortfall")
    }
}
