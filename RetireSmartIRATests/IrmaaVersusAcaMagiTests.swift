//
//  IrmaaVersusAcaMagiTests.swift
//  RetireSmartIRATests
//
//  IRMAA MAGI and ACA MAGI are DIFFERENT statutory quantities, and the difference is
//  exactly the non-taxable half of Social Security.
//
//    IRMAA, 42 U.S.C. 1395r(i)(4): adjusted gross income, increased by tax-exempt
//      interest (and the section 135/911/931/933 exclusions). Social Security is NOT
//      added back -- only the part already in AGI under section 86 counts.
//
//    ACA premium tax credit, IRC 36B(d)(2)(B): adjusted gross income, increased by
//      excluded foreign earned income, tax-exempt interest, AND "the portion of the
//      taxpayer's social security benefits ... not included in gross income under
//      section 86".
//
//  The multi-year projection computed ONE add-back (non-taxable SS + tax-exempt
//  interest) and used it for both, so IRMAA MAGI was overstated by the non-taxable
//  portion of benefits for every household collecting Social Security. That is not a
//  rounding difference: a household with $40,000 of benefits, $15,000 of it non-taxable,
//  was measured against the IRMAA tiers $15,000 too high, and the optimizer reads the
//  same figure through its `.limitToIRMAA` constraint.
//
//  The single-year engine already had this right -- `DataManager.irmaaMagi` is
//  `estimatedAGI + taxExemptInterestTotal` with no benefit add-back, while its ACA MAGI
//  adds `nonTaxableSS`. These tests hold the multi-year engine to the same distinction.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("IRMAA MAGI vs ACA MAGI", .serialized)
@MainActor
struct IrmaaVersusAcaMagiTests {

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    /// `ssAtFRA` is MONTHLY. `age`/`claimAge` decide whether ACA MAGI is tracked at all:
    /// it is reported only while someone is pre-Medicare.
    private func inputs(age: Int, claimAge: Int, ssAtFRA: Double,
                        trad: Double, acaEnrolled: Bool,
                        muniAccount: TaxableAccountInput? = nil) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: age, spouseCurrentAge: nil,
            filingStatus: .single, state: "FL",
            primarySSClaimAge: claimAge, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: ssAtFRA, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 2026 - age, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: acaEnrolled, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0,
            taxableAccounts: muniAccount.map { [$0] } ?? []
        )
    }

    private func assumptions() -> MultiYearAssumptions {
        var a = MultiYearAssumptions(
            horizonEndAge: 200, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0, baselineAnnualExpenses: 0)
        a.rothTaxFundingMode = .paidFromOutsideMoney   // keep the year's income clean
        return a
    }

    private func run(_ inputs: MultiYearStaticInputs, conversion: Double = 0) -> YearRecommendation {
        var actions: [Int: [LeverAction]] = [2026: [], 2027: []]
        if conversion > 0 { actions[2026] = [.rothConversion(amount: conversion)] }
        return ProjectionEngine(configProvider: provider).project(
            inputs: inputs, assumptions: assumptions(), actionsPerYear: actions).first!
    }

    // MARK: - IRMAA MAGI

    @Test("IRMAA MAGI equals AGI when benefits are partly non-taxable and there is no muni interest")
    func irmaaMagiExcludesNonTaxableBenefits() {
        // Age 70, $3,000/month of benefits, a conversion sized to leave benefits below the
        // 85% ceiling. With no tax-exempt interest, 42 U.S.C. 1395r(i)(4) leaves IRMAA MAGI
        // equal to AGI exactly. Adding the non-taxable benefit portion is what this pins out.
        let y = run(inputs(age: 70, claimAge: 67, ssAtFRA: 3_000,
                           trad: 800_000, acaEnrolled: false),
                    conversion: 30_000)
        #expect(y.taxableSocialSecurity > 0, "benefits must actually be partly taxable")
        #expect(
            abs(y.magi - y.agi) < 1.0,
            "IRMAA MAGI \(y.magi) should equal AGI \(y.agi): no tax-exempt interest, and benefits are not added back"
        )
    }

    @Test("IRMAA MAGI adds tax-exempt interest, and only that")
    func irmaaMagiAddsMuniInterest() {
        // The one add-back the statute does specify. A $500,000 muni position at a 4% yield
        // throws off $20,000 of tax-exempt interest, which belongs in IRMAA MAGI and in no
        // part of AGI.
        let muni = TaxableAccountInput(
            balance: 500_000, costBasis: 500_000, protectedAmount: 0, appreciationRate: 0,
            qualifiedDividendYield: 0, ordinaryIncomeYield: 0, taxExemptYield: 0.04,
            realizedLongTermGainYield: 0, availableForExpenses: true,
            availableForConversionTaxes: true, fundingPriority: nil)
        let y = run(inputs(age: 70, claimAge: 67, ssAtFRA: 3_000,
                           trad: 800_000, acaEnrolled: false, muniAccount: muni),
                    conversion: 30_000)
        #expect(y.taxableSocialSecurity > 0, "benefits must actually be partly taxable")
        #expect(
            abs((y.magi - y.agi) - 20_000) < 1.0,
            "IRMAA MAGI should exceed AGI by the $20,000 of tax-exempt interest and nothing else; got \(y.magi - y.agi)"
        )
    }

    // MARK: - ACA MAGI keeps its benefit add-back

    @Test("ACA MAGI still adds the non-taxable portion of benefits")
    func acaMagiIncludesNonTaxableBenefits() throws {
        // Age 63 claiming at 62, so benefits are flowing AND the household is pre-Medicare,
        // which is the only window where ACA MAGI is reported. IRC 36B(d)(2)(B)(iii) puts the
        // non-taxable portion of benefits back in, so ACA MAGI must sit strictly above the
        // IRMAA figure.
        let y = run(inputs(age: 63, claimAge: 62, ssAtFRA: 3_000,
                           trad: 800_000, acaEnrolled: true),
                    conversion: 30_000)
        let aca = try #require(y.acaMagi, "profile must be ACA-tracked")
        #expect(y.taxableSocialSecurity > 0, "benefits must actually be partly taxable")
        #expect(
            aca > y.magi + 1.0,
            "ACA MAGI \(aca) must exceed IRMAA MAGI \(y.magi) by the non-taxable benefit portion"
        )
        // And the gap IS that portion: with no tax-exempt interest, IRMAA MAGI == AGI, so
        // the whole difference is the benefits kept out of gross income under section 86.
        #expect(abs(y.magi - y.agi) < 1.0)
    }

    @Test("With no Social Security at all, the two definitions coincide")
    func definitionsAgreeWithoutBenefits() throws {
        // The control. Every difference asserted above must vanish when there are no
        // benefits to split, which is what makes those tests about benefits rather than
        // about some unrelated basis mismatch.
        let y = run(inputs(age: 63, claimAge: 62, ssAtFRA: 0,
                           trad: 800_000, acaEnrolled: true),
                    conversion: 30_000)
        let aca = try #require(y.acaMagi)
        #expect(y.taxableSocialSecurity == 0)
        #expect(abs(aca - y.magi) < 1.0)
        #expect(abs(y.magi - y.agi) < 1.0)
    }

    // MARK: - Parity with the single-year engine

    @Test("Multi-year IRMAA MAGI uses the same definition the single-year engine does")
    func matchesSingleYearDefinition() {
        // DataManager.irmaaMagi is `estimatedAGI + taxExemptInterestTotal`. Whatever else
        // changes, the two engines must not disagree about what IRMAA MAGI IS, or the same
        // household sees two different tiers depending on which screen it looks at.
        let y = run(inputs(age: 70, claimAge: 67, ssAtFRA: 4_000,
                           trad: 800_000, acaEnrolled: false),
                    conversion: 40_000)
        #expect(y.taxableSocialSecurity > 0)
        #expect(abs(y.magi - (y.agi + 0)) < 1.0,
                "no tax-exempt interest in this profile, so IRMAA MAGI is just AGI")
    }
}
