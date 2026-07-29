//
//  GrossUpConvergenceTests.swift
//  RetireSmartIRATests
//
//  Step 7 of the projection funds a year's tax bill by selling taxable buckets and
//  then grossing up a traditional withdrawal for whatever is left. The gross-up is a
//  fixed point: the withdrawal is itself taxable, so
//
//      dW = shortfall + incrementalTax(dW)
//
//  solved by Picard iteration. The iteration contracts at the household's marginal
//  fed+state rate, so a 41% marginal household removes only ~59% of the error per
//  pass. A budget of 3 passes leaves a real residue of genuinely unpaid tax.
//
//  `underfundedTax` is an exact probe for this. Expanding it at the fixed point:
//
//      dW           = baseTotalTax - saleCash + (fedNew - fedOld) + (stNew - stOld)
//      underfunded  = (fedNew + stNew + nonFedState) - saleCash - dW  ==  0
//
//  So for a household that is NOT asset-exhausted, any nonzero `underfundedTax` is
//  iteration residue, not insolvency. These tests pin it at zero.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Gross-up fixed point convergence", .serialized)
@MainActor
struct GrossUpConvergenceTests {

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

    private func assumptions() -> MultiYearAssumptions {
        var a = MultiYearAssumptions(
            horizonEndAge: 67, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0, baselineAnnualExpenses: 0)
        // Fund the tax from accounts, not withholding, so the gross-up is the only
        // funding mechanism under test.
        a.rothTaxFundingMode = .fundedFromAccounts
        return a
    }

    private func runYear(conversion: Double, trad: Double, taxable: Double,
                         state: String) -> YearRecommendation {
        let engine = ProjectionEngine(configProvider: provider)
        return engine.project(
            inputs: inputs(state: state, trad: trad, taxable: taxable),
            assumptions: assumptions(),
            actionsPerYear: [2026: [.rothConversion(amount: conversion)]]
        ).first!
    }

    @Test("A $300K conversion in California funds its own tax to the last dollar")
    func largeConversionInHighTaxStateConverges() {
        // Single, CA, $300,000 conversion, no taxable bucket, so the entire bill
        // grosses up from traditional. Ample traditional remains afterward, so the
        // household is nowhere near insolvent and every dollar reported here is unpaid
        // tax the projection simply stopped iterating toward.
        let year = runYear(conversion: 300_000, trad: 1_000_000, taxable: 0, state: "CA")

        #expect(year.endOfYearBalances.traditional > 0, "traditional assets remain, so not exhausted")
        #expect(year.isInfeasible == false, "a solvent household must not read as infeasible")
        #expect(
            (year.underfunded ?? 0) < 1.0,
            "gross-up left \(year.underfunded ?? 0) of tax unfunded; the fixed point did not converge"
        )
    }

    @Test("Convergence holds across conversion sizes and state marginal rates")
    func convergesAcrossTheGrid() {
        // The contraction ratio IS the marginal fed+state rate, so the states with the
        // highest marginal rates converge slowest. FL (no income tax) is the control.
        for state in ["FL", "CA", "NY", "MN", "VT"] {
            for conversion in [50_000.0, 150_000.0, 300_000.0, 600_000.0] {
                let year = runYear(conversion: conversion, trad: 2_000_000,
                                   taxable: 0, state: state)
                #expect(
                    year.endOfYearBalances.traditional > 0,
                    "\(state) $\(conversion): traditional drained, test is mis-specified"
                )
                #expect(
                    (year.underfunded ?? 0) < 1.0,
                    "\(state) $\(conversion): \(year.underfunded ?? 0) of tax left unfunded"
                )
            }
        }
    }

    @Test("A solvent year funding tax from a mix of taxable and traditional converges")
    func mixedFundingConverges() {
        // Phase 1 sells the taxable bucket, whose realized gain adds preferential income
        // that Phase 2 must also gross up. This is the path where the gain-on-gain
        // sliver rides on top of the ordinary-income fixed point.
        let year = runYear(conversion: 400_000, trad: 1_500_000, taxable: 250_000, state: "CA")
        #expect(year.endOfYearBalances.traditional > 0)
        #expect(
            (year.underfunded ?? 0) < 1.0,
            "mixed funding left \(year.underfunded ?? 0) of tax unfunded"
        )
    }
}
