//
//  RealismRegressionTests.swift
//  RetireSmartIRATests
//
//  Regression suite for the "engine realism" batch (2026-06-26):
//    - C3: conversion/year tax paid from taxable first, then grossed-up from traditional
//    - PV: optimizer objective PV-discounts in-horizon and terminal tax at pvRealDiscountRate
//
//  These tests guard against the over-conversion failure mode:
//    a) "brakeStopsDrain" — with little taxable liquidity the IRA is NOT fully drained
//    b) "frontierSpreads" — a high-income heir still produces a measurable frontier spread
//
//  If either test fails, DO NOT weaken the assertion. Report it as a blocking regression:
//  the realism approach may need revisiting by the human.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Realism regression", .serialized)
@MainActor
struct RealismRegressionTests {

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func inputs(trad: Double, taxable: Double, heirSalary: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 70,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: "CA",
            primarySSClaimAge: 70,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1956,
            spouseBirthYear: nil,
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: 0,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0,
            heirSalary: heirSalary,
            heirFilingStatus: .single,
            heirDrawdownYears: 10)
    }

    private func assumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95,
            horizonEndAgeSpouse: nil,
            cpiRate: 0,
            investmentGrowthRate: 0.06,
            withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false,
            perYearExpenseOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0)
    }

    // MARK: - Brake test

    @Test("constrained liquidity: traditional is no longer fully drained")
    func brakeStopsDrain() {
        // $1.5M trad, only $50K taxable — not enough to fund large Roth conversion taxes
        // without drawing extra from the IRA itself. The C3 gross-up is a real cost that
        // should make fully draining the IRA suboptimal when liquidity is constrained.
        let r = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs(trad: 1_500_000, taxable: 50_000, heirSalary: 75_000),
            assumptions: assumptions(),
            configProvider: provider)

        // Weight == 0 means λ=0 (owner-only objective, maximum conversion pressure)
        let baselinePath = r.points.first(where: { $0.weight == 0 })!.recommendedPath
        let last = baselinePath.last!
        let termTrad = last.endOfYearBalances.primaryTraditional + last.endOfYearBalances.spouseTraditional
        // DO NOT lower this threshold or delete this test if it fails.
        // A failure means the C3 brake + PV discount is not strong enough — report it.
        #expect(termTrad > 0,
                "with only $50K taxable to fund conversion tax, the engine should not drain the IRA to zero; termTrad=\(termTrad)")
    }

    // MARK: - Frontier spread test

    @Test("high-income heir: the frontier shows a measurable trade-off")
    func frontierSpreads() {
        // $1.5M trad, only $50K taxable, heir earning $250K.
        // Heir at $250K faces high marginal rates on inherited traditional drawdown (~35%+).
        // Roth conversion reduces heir's tax burden vs. leaving trad untouched.
        // The frontier should show a non-trivial spread between owner-only (λ=0) and
        // heir-favoring (λ=1) outcomes in heirAfterTaxInheritanceToday.
        let r = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs(trad: 1_500_000, taxable: 50_000, heirSalary: 250_000),
            assumptions: assumptions(),
            configProvider: provider)

        let spread = abs(r.points.last!.heirAfterTaxInheritanceToday
                         - r.points.first!.heirAfterTaxInheritanceToday)
        // DO NOT lower this threshold or delete this test if it fails.
        // A failure means the frontier is flat, which indicates either:
        //   a) trad drained regardless of weight (same as brakeStopsDrain finding), or
        //   b) heir marginal rate ≈ owner conversion rate at $250K (report this).
        #expect(spread > 1000,
                "when heir rates differ materially the frontier should open; got spread=\(spread)")
    }
}
