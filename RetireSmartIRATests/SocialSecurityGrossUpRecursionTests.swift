//
//  SocialSecurityGrossUpRecursionTests.swift
//  RetireSmartIRATests
//
//  A traditional withdrawal taken to PAY a year's tax is ordinary income like any
//  other. It therefore raises provisional income, which can pull more Social Security
//  into taxation, which raises the tax, which enlarges the withdrawal. The projection
//  computed `taxableSS` once from pre-gross-up income and never revisited it, so the
//  gross-up's own effect on benefit taxation was dropped.
//
//  The MAGI trap that comes with fixing it:
//
//      MAGI = AGI + nonTaxableSS + taxExempt
//           = (non-SS income) + taxableSS + (grossSS - taxableSS) + taxExempt
//           = (non-SS income) + grossSS + taxExempt
//
//  MAGI is algebraically INVARIANT to how benefits split between taxable and
//  non-taxable. Raising `taxableSS` by delta raises AGI by delta and must lower the
//  MAGI add-back by the same delta. Recomputing benefit taxation for AGI while leaving
//  the add-back stale would silently overstate MAGI by delta, and MAGI is what drives
//  IRMAA tiers and ACA cliffs. `magiIsInvariantToTheBenefitSplit` pins that.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Social Security recursion through the gross-up", .serialized)
@MainActor
struct SocialSecurityGrossUpRecursionTests {

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    /// Age 70, collecting Social Security, modest balances. Deliberately NOT a large
    /// conversion: benefit taxation saturates at 85% of benefits, and above that ceiling
    /// no amount of extra income changes anything, so a big conversion would make these
    /// tests vacuous.
    /// `ssAtFRA` is MONTHLY, in today's dollars, matching MultiYearStaticInputs.
    private func inputs(state: String, trad: Double, taxable: Double,
                        ssAtFRA: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 70, spouseCurrentAge: nil,
            filingStatus: .single, state: state,
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: ssAtFRA, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1956, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
    }

    private func assumptions(_ mode: RothTaxFundingMode) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(
            horizonEndAge: 71, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0, baselineAnnualExpenses: 0)
        a.rothTaxFundingMode = mode
        return a
    }

    private func runYear(mode: RothTaxFundingMode, conversion: Double,
                         trad: Double = 500_000, taxable: Double = 0,
                         ssAtFRA: Double = 3_000, state: String = "CA") -> YearRecommendation {
        ProjectionEngine(configProvider: provider).project(
            inputs: inputs(state: state, trad: trad, taxable: taxable, ssAtFRA: ssAtFRA),
            assumptions: assumptions(mode),
            actionsPerYear: [2026: [.rothConversion(amount: conversion)]]
        ).first!
    }

    /// Gross benefits, recovered from the identity MAGI = AGI + nonTaxableSS (no
    /// tax-exempt interest in these profiles). Taken from the outside-money run, where
    /// no gross-up fires and the benefit split is therefore not in question.
    private func grossBenefits(from year: YearRecommendation) -> Double {
        year.magi - year.agi + year.taxableSocialSecurity
    }

    @Test("A tax-funding withdrawal pulls more Social Security into taxation")
    func grossUpRaisesTaxableBenefits() {
        // Same conversion both ways. `paidFromOutsideMoney` funds the tax with untracked
        // money, so no withdrawal happens and provisional income stays at its base level.
        // `fundedFromAccounts` must take a traditional withdrawal, which IS ordinary
        // income and must show up in the benefit-taxation test.
        let outside = runYear(mode: .paidFromOutsideMoney, conversion: 30_000)
        let funded  = runYear(mode: .fundedFromAccounts, conversion: 30_000)

        #expect(funded.taxFundingWithdrawal > 0, "scenario must actually force a gross-up")

        // Guard against a vacuous test: if benefits are already at the 85% ceiling there
        // is no headroom for more of them to become taxable, and the comparison proves
        // nothing.
        let gross = grossBenefits(from: outside)
        #expect(gross > 0, "profile must actually collect Social Security")
        #expect(
            outside.taxableSocialSecurity < gross * 0.85 - 1.0,
            "profile must leave benefit-taxation headroom; it is already at the 85% ceiling"
        )

        #expect(
            funded.taxableSocialSecurity > outside.taxableSocialSecurity + 1.0,
            """
            the gross-up withdrawal did not feed back into benefit taxation: \
            outside=\(outside.taxableSocialSecurity) funded=\(funded.taxableSocialSecurity)
            """
        )
    }

    @Test("Reported MAGI is invariant to the taxable/non-taxable benefit split")
    func magiIsInvariantToTheBenefitSplit() {
        // The trap. Gross benefits are a property of the household, not of how the tax
        // is funded, so recovering them from each run's own reported figures must give
        // the same answer. If `taxableSS` is recomputed for AGI while the MAGI add-back
        // keeps the stale non-taxable remainder, this identity breaks by exactly the
        // amount MAGI is overstated -- and MAGI is what sets IRMAA tiers and ACA cliffs.
        let outside = runYear(mode: .paidFromOutsideMoney, conversion: 30_000)
        let funded  = runYear(mode: .fundedFromAccounts, conversion: 30_000)

        #expect(
            abs(grossBenefits(from: funded) - grossBenefits(from: outside)) < 1.0,
            """
            MAGI add-back is inconsistent with reported taxable benefits: \
            outside implies gross SS of \(grossBenefits(from: outside)), \
            funded implies \(grossBenefits(from: funded))
            """
        )
    }

    @Test("Benefit taxation stays self-consistent across states and conversion sizes")
    func selfConsistentAcrossTheGrid() {
        // State income tax enlarges the gross-up, which enlarges the feedback. The
        // identity must hold everywhere, including the no-income-tax control.
        for state in ["FL", "CA", "MN", "VT"] {
            for conversion in [20_000.0, 30_000.0, 40_000.0] {
                let outside = runYear(mode: .paidFromOutsideMoney, conversion: conversion, state: state)
                let funded  = runYear(mode: .fundedFromAccounts, conversion: conversion, state: state)
                #expect(
                    abs(grossBenefits(from: funded) - grossBenefits(from: outside)) < 1.0,
                    "\(state) $\(conversion): MAGI add-back drifted from reported taxable benefits"
                )
                #expect(
                    funded.taxableSocialSecurity >= outside.taxableSocialSecurity - 0.01,
                    "\(state) $\(conversion): funding the tax REDUCED taxable benefits"
                )
            }
        }
    }
}
