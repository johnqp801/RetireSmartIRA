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
//    b) "frontierNonDominated" — a high-income heir's frontier is non-dominated + monotone in
//       weight (was "frontierSpreads"; its abs(spread) check passed on a backwards frontier — see
//       the test body for the history and the known non-convergence limitation it now documents)
//
//  If test (a) fails, DO NOT weaken the assertion. Report it as a blocking regression:
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

    // SHELVED 2026-07-12, RE-ENABLED 2026-07-17. The original λ=0 full-drain came from the
    // objective's growth-vs-discount asymmetry: tax flows were discounted at pvRealDiscountRate
    // (3%) while the balances they act on compound at investmentGrowthRate (6%), inflating the
    // effective terminal rate by (1.06/1.03)^H ≈ 2.05× (0.22 → ~0.45), so converting even at
    // 32–37% "beat" holding — full drain in every regime (the old CA pass was a knife-edge
    // state-tax coincidence, un-masked by V2.1.1 SALT itemizing). The objective now discounts ALL
    // tax flows at the growth rate (wealth-consistent: minimizing growth-discounted tax ≡
    // maximizing the terminal after-tax estate), so the effective terminal rate is the rate itself
    // and conversion stops at brackets below it — draining into 32–37% is genuinely suboptimal.
    @Test("constrained liquidity: traditional is no longer fully drained")
    func brakeStopsDrain() {
        // $1.5M trad, only $50K taxable — not enough to fund large Roth conversion taxes
        // without drawing extra from the IRA itself. The C3 gross-up is a real cost that
        // should make fully draining the IRA suboptimal when liquidity is constrained.
        //
        // Calls optimize() DIRECTLY (not computeFrontier): this pins the OPTIMIZER's λ=0
        // behavior. Going through the frontier would let the cross-λ Pareto repair swap a
        // non-drained sibling path into the λ=0 slot and mask a drain in the raw optimizer.
        let result = OptimizationEngine().optimize(
            inputs: inputs(trad: 1_500_000, taxable: 50_000, heirSalary: 75_000),
            assumptions: assumptions(),
            configProvider: provider,
            heirWeight: 0)
        let last = result.recommendedPath.last!
        let termTrad = last.endOfYearBalances.primaryTraditional + last.endOfYearBalances.spouseTraditional
        // DO NOT lower this threshold or delete this test if it fails.
        // A failure means the C3 brake + PV discount is not strong enough — report it.
        #expect(termTrad > 0,
                "with only $50K taxable to fund conversion tax, the engine should not drain the IRA to zero; termTrad=\(termTrad)")
    }

    // MARK: - Frontier non-domination test

    @Test("high-income heir: the frontier is non-dominated and monotone in weight")
    func frontierNonDominated() {
        // $1.5M trad, only $50K taxable, heir earning $250K.
        //
        // History: this test previously asserted `abs(λ=1 heirs − λ=0 heirs) > 1000`, i.e. a
        // "measurable trade-off." That `abs()` was a latent bug: on this profile the greedy
        // optimizer does NOT converge (iteration cap) and produced a strictly BACKWARDS frontier —
        // leaning toward heirs left them ~$109K LESS while costing the owner MORE tax. The absolute
        // value let that dominated frontier pass as if it were a real trade-off.
        //
        // The cross-λ Pareto repair (HeirFrontierCoordinator.paretoRepair) now collapses such a
        // backwards frontier onto its non-dominated envelope, so the honest result here is FLAT
        // (no achievable heir-favoring plan the engine can find). The correct, enforceable property
        // is therefore non-domination + monotonicity, NOT a nonzero spread.
        //
        // KNOWN LIMITATION (backlog, see memory over-conversion-brake-ineffective /
        // frontier-cross-lambda-domination): economically a $250K heir SHOULD benefit from
        // conversions, but the non-convergent greedy can't find that plan, so the frontier is flat
        // rather than opening. Recovering the genuine trade-off needs the deeper convergence fix.
        let r = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs(trad: 1_500_000, taxable: 50_000, heirSalary: 250_000),
            assumptions: assumptions(),
            configProvider: provider)
        let eps = 1.0
        let pts = r.points

        // (a) No plotted point is dominated on both axes (owner tax ↓, heirs-keep ↑).
        for i in pts.indices {
            for j in pts.indices where j != i {
                let noWorseTax = pts[j].ownerLifetimeTaxToday <= pts[i].ownerLifetimeTaxToday + eps
                let noWorseHeirs = pts[j].heirAfterTaxInheritanceToday >= pts[i].heirAfterTaxInheritanceToday - eps
                let strictlyBetter = pts[j].ownerLifetimeTaxToday < pts[i].ownerLifetimeTaxToday - eps
                    || pts[j].heirAfterTaxInheritanceToday > pts[i].heirAfterTaxInheritanceToday + eps
                #expect(!(noWorseTax && noWorseHeirs && strictlyBetter),
                        "weight \(pts[i].weight) is dominated by weight \(pts[j].weight)")
            }
        }
        // (b) Heirs-keep is monotone non-decreasing as heir weight rises.
        let sorted = pts.sorted { $0.weight < $1.weight }
        for k in 1..<sorted.count {
            #expect(sorted[k].heirAfterTaxInheritanceToday >= sorted[k - 1].heirAfterTaxInheritanceToday - eps,
                    "heirs-keep dropped from weight \(sorted[k - 1].weight) to \(sorted[k].weight)")
        }
    }

    // MARK: - Frontier opens test

    @Test("high-rate heir: leaning toward heirs genuinely leaves them more")
    func frontierOpensForHighRateHeir() {
        // $1.5M trad, $50K taxable, heir earning $250K (marginal ~35% on inherited-trad drawdown).
        // The owner's terminal self-liquidation rate is 22%, so the owner-optimal (λ=0) plan should
        // stop converting at brackets ≤22%, while the heir-optimal (λ=1) plan should keep converting
        // through brackets below the heir's ~35% — converting at 24–32% costs the owner less than it
        // saves the heir. Those are DIFFERENT plans, so the frontier must open: heirs keep strictly
        // more at λ=1 than at λ=0. This is the directional replacement for the old abs(spread) check
        // (which passed on a backwards frontier) and fails while the terminal-tax growth-vs-discount
        // asymmetry pushes every weight to the same full-drain corner.
        let r = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs(trad: 1_500_000, taxable: 50_000, heirSalary: 250_000),
            assumptions: assumptions(),
            configProvider: provider)
        let byWeight = r.points.sorted { $0.weight < $1.weight }
        let ownerOptimal = byWeight.first!
        let heirOptimal = byWeight.last!
        #expect(heirOptimal.heirAfterTaxInheritanceToday > ownerOptimal.heirAfterTaxInheritanceToday + 1_000,
                "with heir marginal rate well above the owner's terminal rate the frontier should open; λ=0 heirs=\(ownerOptimal.heirAfterTaxInheritanceToday), λ=1 heirs=\(heirOptimal.heirAfterTaxInheritanceToday)")
    }

    // Same heir, ample taxable liquidity: with no C3 gross-up cascade the conversion cost is close
    // to the sticker bracket rate, so the heir-favoring trade-off is unambiguous — a companion to
    // the liquidity-CONSTRAINED case above, guarding the frontier's opening in the easy regime too.
    @Test("liquidity-rich high-rate heir: the frontier opens")
    func frontierOpensLiquidityRich() {
        let r = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs(trad: 1_500_000, taxable: 750_000, heirSalary: 250_000),
            assumptions: assumptions(),
            configProvider: provider)
        let byWeight = r.points.sorted { $0.weight < $1.weight }
        #expect(byWeight.last!.heirAfterTaxInheritanceToday > byWeight.first!.heirAfterTaxInheritanceToday + 1_000,
                "λ=0 heirs=\(byWeight.first!.heirAfterTaxInheritanceToday), λ=1 heirs=\(byWeight.last!.heirAfterTaxInheritanceToday)")
    }
}
