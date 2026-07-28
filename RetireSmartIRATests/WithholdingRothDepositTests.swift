//
//  WithholdingRothDepositTests.swift
//  RetireSmartIRATests
//
//  V2.3: gross out of the IRA, net into the Roth, and PA's Ans 274 treatment of the
//  withheld portion.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Withholding: net Roth deposit and PA treatment", .serialized)
@MainActor
struct WithholdingRothDepositTests {

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func inputs(state: String, trad: Double, taxable: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 66, spouseCurrentAge: nil,
            filingStatus: .single, state: state,
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1960, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
    }

    private func assumptions(_ mode: RothTaxFundingMode, rate: Double) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(
            horizonEndAge: 67, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0, baselineAnnualExpenses: 0)
        a.rothTaxFundingMode = mode
        a.federalWithholdingRate = rate
        return a
    }

    private func runYear(_ mode: RothTaxFundingMode, rate: Double = 0.22,
                         state: String = "FL", trad: Double = 500_000,
                         taxable: Double = 300_000) -> YearRecommendation {
        ProjectionEngine(configProvider: provider).project(
            inputs: inputs(state: state, trad: trad, taxable: taxable),
            assumptions: assumptions(mode, rate: rate),
            actionsPerYear: [2026: [.rothConversion(amount: 100_000)]]
        ).first!
    }

    @Test("Roth receives gross minus withholding")
    func rothReceivesNet() {
        let y = runYear(.withheldFromConversion, rate: 0.22)
        // $100,000 gross, 22% withheld, $78,000 lands in the Roth.
        #expect(abs(y.endOfYearBalances.roth - 78_000) < 1.0)
    }

    @Test("Without withholding the full gross lands in the Roth")
    func rothReceivesGrossWhenNotWithholding() {
        let y = runYear(.fundedFromAccounts)
        #expect(abs(y.endOfYearBalances.roth - 100_000) < 1.0)
    }

    @Test("Outside-money mode also lands the full gross in the Roth")
    func rothReceivesGrossWhenPaidFromOutsideMoney() {
        let y = runYear(.paidFromOutsideMoney)
        #expect(abs(y.endOfYearBalances.roth - 100_000) < 1.0)
    }

    @Test("Executed conversion still reports the GROSS distribution")
    func executedConversionIsGross() {
        let y = runYear(.withheldFromConversion, rate: 0.22)
        #expect(abs(y.executedRothConversion - 100_000) < 1.0,
                "the IRA gave up the full gross; only the Roth deposit is net")
    }

    @Test("Wealth is conserved: gross leaves the IRA, net lands in the Roth, tax leaves the household")
    func wealthIsConserved() {
        // FL (no state tax), taxable empty, 22% withheld against a smaller federal bill.
        // Nothing is grossed up, so the only movements are the conversion, the remittance,
        // and the overpayment credit back to taxable.
        let y = runYear(.withheldFromConversion, rate: 0.22, state: "FL",
                        trad: 500_000, taxable: 0)
        #expect(y.taxFundingWithdrawal == 0, "withholding alone should cover this year's bill")
        // The traditional side gives up the FULL gross, not the net.
        #expect(abs(y.endOfYearBalances.traditional - 400_000) < 1.0)
        // The Roth receives only what the custodian actually deposited.
        #expect(abs(y.endOfYearBalances.roth - 78_000) < 1.0)
        // No dollars invented or destroyed: everything that left the household is tax.
        let endTotal = y.endOfYearBalances.total
        #expect(abs((500_000 - endTotal) - y.taxBreakdown.total) < 1.0,
                "household wealth may fall only by the tax actually owed")
    }

    @Test("PA: the withheld portion is state-taxable, the converted portion is not")
    func pennsylvaniaWithheldPortionTaxable() {
        let withheld = runYear(.withheldFromConversion, rate: 0.22, state: "PA")
        let notWithheld = runYear(.fundedFromAccounts, state: "PA")
        // PA Ans 274: exemption applies only to the portion actually deposited, so a
        // withholding election creates PA tax the non-withholding case does not have.
        #expect(notWithheld.taxBreakdown.state == 0,
                "a fully deposited conversion is entirely PA-exempt")
        #expect(withheld.taxBreakdown.state > notWithheld.taxBreakdown.state)
        // PA is a flat tax, so the added state tax is the PA rate on the withheld $22,000.
        #expect(abs(withheld.taxBreakdown.state - 22_000 * 0.0307) < 1.0,
                "only the withheld portion should be PA-taxable")
    }

    @Test("PA federal treatment is unchanged: gross is included once")
    func pennsylvaniaFederalUnchanged() {
        let pa = runYear(.withheldFromConversion, rate: 0.22, state: "PA")
        let fl = runYear(.withheldFromConversion, rate: 0.22, state: "FL")
        #expect(abs(pa.taxBreakdown.federal - fl.taxBreakdown.federal) < 1.0,
                "state treatment must never alter federal inclusion")
    }
}
