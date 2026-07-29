//
//  CashFlowTaxFundingTests.swift
//  RetireSmartIRATests
//
//  A household that takes in more income than it spends pays its tax bill out of that
//  income. The funding cascade reaches only taxable buckets and traditional balances,
//  so a household with no traditional and nothing sellable was reported as unable to
//  pay a tax bill it could cover out of pocket several times over.
//
//  The sharpest case: a $30,000 pension, ZERO expenses, $2,000,000 in Roth, and $585 of
//  tax. Every year of the projection was flagged "cannot pay its modeled tax" while
//  $30,000 of unspent income evaporated from the model each year.
//
//  This is not the Roth-raid question. That income surplus is already discarded by the
//  projection (it is deliberately not reinvested -- see the spendable-surplus step), so
//  counting it as available to pay tax moves NO tracked balance. And because the
//  infeasibility gate requires assets to be exhausted, this can only ever change years
//  that were already being flagged. Every other year is untouched.
//
//  What this does NOT cover, by design: a household whose income falls SHORT of its
//  expenses has no surplus, so it is still flagged. Those years are honest about being
//  a limit of the model rather than of the household -- see FundingFeasibilitySummary.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Cash-flow tax funding", .serialized)
@MainActor
struct CashFlowTaxFundingTests {

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func inputs(pension: Double, expenses: Double, roth: Double,
                        trad: Double, taxable: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: roth, taxable: taxable, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 66, spouseCurrentAge: nil,
            filingStatus: .single, state: "FL",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1960, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: pension, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: expenses
        )
    }

    private func assumptions(expenses: Double, taxable: Double) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(
            horizonEndAge: 69, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearOverrides: [:],
            currentTaxableBalance: taxable, currentHSABalance: 0,
            baselineAnnualExpenses: expenses)
        a.rothTaxFundingMode = .fundedFromAccounts
        return a
    }

    /// `project` derives its year set from `actionsPerYear.keys`, so the years must be
    /// supplied explicitly even when no lever fires in them.
    private func run(pension: Double, expenses: Double, roth: Double,
                     trad: Double = 0, taxable: Double = 0,
                     conversion: Double = 0) -> [YearRecommendation] {
        var actions: [Int: [LeverAction]] = [2026: [], 2027: [], 2028: []]
        if conversion > 0 { actions[2026] = [.rothConversion(amount: conversion)] }
        return ProjectionEngine(configProvider: provider).project(
            inputs: inputs(pension: pension, expenses: expenses, roth: roth,
                           trad: trad, taxable: taxable),
            assumptions: assumptions(expenses: expenses, taxable: taxable),
            actionsPerYear: actions)
    }

    @Test("Unspent income pays the tax: a pension household with a large Roth is not infeasible")
    func incomeSurplusFundsTheTax() {
        // $30,000 pension, no expenses, $2,000,000 Roth, no traditional, nothing sellable.
        // The tax is a few hundred dollars against $30,000 of unspent income.
        let years = run(pension: 30_000, expenses: 0, roth: 2_000_000)
        #expect(years.isEmpty == false)
        for y in years {
            #expect(y.taxBreakdown.total > 0, "\(y.year): scenario must actually owe tax")
            #expect(
                y.isInfeasible == false,
                "\(y.year): $30,000 of unspent income covers a $\(Int(y.taxBreakdown.total)) tax bill"
            )
            #expect(y.dependsOnInfeasibleYear == false, "\(y.year): nothing upstream failed")
            #expect((y.underfunded ?? 0) < 1.0, "\(y.year): reported a shortfall it does not have")
        }
        #expect(FundingFeasibilitySummary(path: years).isFullyFunded)
    }

    @Test("Surplus is counted net of expenses, not gross income")
    func surplusIsNetOfExpenses() {
        // Income $30,000 against expenses $29,000 leaves $1,000 of headroom, which covers
        // this year's tax. The test would pass on gross income too, so its partner below
        // is what proves expenses are actually subtracted.
        let comfortable = run(pension: 30_000, expenses: 29_000, roth: 2_000_000)
        #expect(comfortable.allSatisfy { $0.isInfeasible == false })
    }

    @Test("A household whose income does not cover its expenses is still flagged")
    func noSurplusIsStillInfeasible() {
        // $30,000 of income against $60,000 of expenses: there is no surplus to pay tax
        // from, and the funding cascade cannot reach Roth. This year IS still reported as
        // unfunded, which is what keeps the fix from being a blanket suppression. The copy
        // it produces attributes the limit to the model rather than to the household.
        let years = run(pension: 30_000, expenses: 60_000, roth: 2_000_000)
        #expect(years.isEmpty == false)
        #expect(years.first!.isInfeasible, "no surplus and no reachable assets: still unfunded")
    }

    @Test("Counting cash flow does not move any balance in an ordinarily funded year")
    func fundedYearBalancesAreUnchanged() {
        // A household with ample traditional and a real conversion. `assetsExhausted` is
        // false here, so the gate never fired for this year either way, and the funding
        // cascade is untouched: the ending balances must be exactly what they were.
        let years = run(pension: 30_000, expenses: 0, roth: 0,
                        trad: 800_000, taxable: 0, conversion: 100_000)
        let first = years.first!
        #expect(first.isInfeasible == false)
        #expect(first.taxFundingWithdrawal > 0, "the gross-up must still fire and still be funded from the IRA")
        // Traditional falls by the conversion plus the tax-funding withdrawal, and by
        // nothing else. If cash flow had been wired into the cascade rather than into the
        // feasibility measurement, this balance would be higher.
        let expected = 800_000 - 100_000 - first.taxFundingWithdrawal
        #expect(
            abs(first.endOfYearBalances.traditional - expected) < 1.0,
            "traditional was \(first.endOfYearBalances.traditional), expected \(expected)"
        )
    }
}
