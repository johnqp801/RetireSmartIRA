//
//  VADisabilityTests.swift
//  RetireSmartIRATests
//
//  Verifies that VA Disability income (IRC §104(a)(4)) is correctly excluded
//  from every tax calculation in the engine. It is tracked for user budgeting
//  only and must be invisible to federal AGI, state AGI, provisional income
//  for Social Security taxation, MAGI for ACA/IRMAA, NIIT, and AMT.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("VA Disability — tax-exempt income type")
@MainActor
struct VADisabilityTests {

    // MARK: - Enum

    @Test("IncomeType has .vaDisability case")
    func incomeTypeHasVADisability() {
        let type = IncomeType.vaDisability
        #expect(type == .vaDisability)
    }

    @Test("vaDisability rawValue serializes to 'VA Disability'")
    func vaDisabilityRawValue() {
        #expect(IncomeType.vaDisability.rawValue == "VA Disability")
    }

    @Test("vaDisability displayName matches rawValue")
    func vaDisabilityDisplayName() {
        #expect(IncomeType.vaDisability.displayName == "VA Disability")
    }

    @Test("IncomeType.allCases includes .vaDisability (CaseIterable / UI picker)")
    func caseIterableIncludesVADisability() {
        #expect(IncomeType.allCases.contains(.vaDisability))
    }

    // MARK: - SS Provisional Income

    @Test("VA Disability is excluded from provisional income for SS taxation")
    func excludedFromProvisionalIncome() {
        // $20K gross SS + $30K VA Disability, nothing else.
        // Provisional income = 0 (other) + 0 (VA Disability) + 0.5*20K = $10K.
        // $10K < $25K threshold (single) → taxable SS = $0.
        // If VA Disability were erroneously included: 30K + 0.5*20K = $40K > $34K
        // → taxable SS would be > 0.
        let ssGross = 20_000.0
        let sources: [IncomeSource] = [
            IncomeSource(name: "Social Security", type: .socialSecurity, annualAmount: ssGross),
            IncomeSource(name: "VA Disability",   type: .vaDisability,   annualAmount: 30_000),
        ]
        let taxableSS = TaxCalculationEngine.calculateTaxableSocialSecurity(
            filingStatus: .single,
            additionalIncome: 0,
            incomeSources: sources
        )
        #expect(
            taxableSS == 0,
            "VA Disability must not contribute to provisional income; taxable SS should be $0, got \(taxableSS)"
        )
    }

    @Test("VA Disability plus pension: only pension contributes to provisional income")
    func provisionalIncomeOnlyCountsPension() {
        // $20K pension + $30K VA Disability + $20K SS.
        // Provisional income = 20K (pension) + 0 (VA) + 0.5*20K = $30K.
        // $30K > $25K but <= $34K (single) → taxable SS = min(30K - 25K, 20K * 0.5)
        //   = min(5,000, 10,000) = $5,000.
        // If VA were included: 20K + 30K + 0.5*20K = $60K > $34K → taxable SS would be
        //   min(tier1 + tier2 calculation, 20K * 0.85) ≈ $17,000 — much larger.
        let sources: [IncomeSource] = [
            IncomeSource(name: "Social Security", type: .socialSecurity, annualAmount: 20_000),
            IncomeSource(name: "Pension",         type: .pension,        annualAmount: 20_000),
            IncomeSource(name: "VA Disability",   type: .vaDisability,   annualAmount: 30_000),
        ]
        let taxableSS = TaxCalculationEngine.calculateTaxableSocialSecurity(
            filingStatus: .single,
            additionalIncome: 0,
            incomeSources: sources
        )
        // combined = 20K (pension) + 0.5*20K (SS) = 30K; 30K - 25K = 5K excess; taxable SS = 5K
        #expect(
            taxableSS == 5_000,
            "Only pension should contribute to provisional income, not VA Disability; expected $5,000, got \(taxableSS)"
        )
    }

    // MARK: - Federal AGI / ordinaryIncomeSubtotal

    @Test("VA Disability is excluded from ordinaryIncomeSubtotal")
    func excludedFromOrdinaryIncomeSubtotal() {
        let dm = DataManager(skipPersistence: true)
        dm.incomeDeductions.incomeSources = [
            IncomeSource(name: "VA Disability", type: .vaDisability, annualAmount: 25_000),
        ]
        #expect(
            dm.incomeDeductions.ordinaryIncomeSubtotal == 0,
            "VA Disability alone should produce zero ordinaryIncomeSubtotal, got \(dm.incomeDeductions.ordinaryIncomeSubtotal)"
        )
    }

    @Test("VA Disability does not pollute ordinaryIncomeSubtotal when mixed with pension")
    func mixedIncomeOrdinarySubtotal() {
        // $30K pension + $20K VA Disability → ordinaryIncomeSubtotal should be $30K only.
        let dm = DataManager(skipPersistence: true)
        dm.incomeDeductions.incomeSources = [
            IncomeSource(name: "Pension",       type: .pension,      annualAmount: 30_000),
            IncomeSource(name: "VA Disability", type: .vaDisability, annualAmount: 20_000),
        ]
        #expect(
            dm.incomeDeductions.ordinaryIncomeSubtotal == 30_000,
            "ordinaryIncomeSubtotal should be $30K (pension only); VA Disability is excluded. Got \(dm.incomeDeductions.ordinaryIncomeSubtotal)"
        )
    }

    // MARK: - scenarioGrossIncome (the root fed into all downstream tax calculations)

    @Test("VA Disability alone produces zero scenarioGrossIncome")
    func vaDisabilityAloneProducesZeroGrossIncome() {
        let dm = DataManager(skipPersistence: true)
        dm.incomeSources = [
            IncomeSource(name: "VA Disability", type: .vaDisability, annualAmount: 50_000),
        ]
        #expect(
            dm.scenarioGrossIncome == 0,
            "VA Disability must not contribute to scenarioGrossIncome; got \(dm.scenarioGrossIncome)"
        )
    }

    @Test("scenarioGrossIncome includes pension but not VA Disability")
    func grossIncomeExcludesVADisability() {
        let dm = DataManager(skipPersistence: true)
        dm.incomeSources = [
            IncomeSource(name: "Pension",       type: .pension,      annualAmount: 30_000),
            IncomeSource(name: "VA Disability", type: .vaDisability, annualAmount: 20_000),
        ]
        #expect(
            dm.scenarioGrossIncome == 30_000,
            "scenarioGrossIncome should be $30K (pension only); got \(dm.scenarioGrossIncome)"
        )
    }

    // MARK: - State Tax

    @Test("VA Disability alone produces zero state tax (California)")
    func vaDisabilityProducesZeroStateTax() {
        // California has progressive income tax — if VA Disability were taxable, $50K
        // would produce several hundred dollars of tax. It should be $0.
        let dm = DataManager(skipPersistence: true)
        dm.selectedState = .california
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "VA Disability", type: .vaDisability, annualAmount: 50_000),
        ]
        // State tax path: scenarioGrossIncome → calculateStateTaxFromGross.
        // scenarioGrossIncome should be 0 because VA Disability is excluded.
        let stateTax = dm.calculateStateTaxFromGross(
            grossIncome: dm.scenarioGrossIncome,
            forState: .california,
            filingStatus: .single,
            taxableSocialSecurity: 0
        )
        #expect(stateTax == 0, "VA Disability must produce zero California state tax; got \(stateTax)")
    }

    // MARK: - totalAnnualIncome (UI display — VA Disability IS shown to user)

    @Test("totalAnnualIncome includes VA Disability (correct for user budgeting display)")
    func totalAnnualIncomeIncludesVADisability() {
        // The user should see their total cash inflows including VA Disability.
        // Only tax calculations exclude it.
        let dm = DataManager(skipPersistence: true)
        dm.incomeSources = [
            IncomeSource(name: "Pension",       type: .pension,      annualAmount: 30_000),
            IncomeSource(name: "VA Disability", type: .vaDisability, annualAmount: 20_000),
        ]
        #expect(
            dm.totalAnnualIncome() == 50_000,
            "totalAnnualIncome should include VA Disability for budget display; got \(dm.totalAnnualIncome())"
        )
    }

    // MARK: - Multi-Year Adapter

    @Test("MultiYearInputAdapter: VA Disability excluded from wage and pension rollups")
    func adapterExcludesVADisability() {
        let dm = DataManager(skipPersistence: true)
        var c = DateComponents(); c.year = 1961; c.month = 1; c.day = 1
        dm.birthDate = Calendar.current.date(from: c)!
        dm.incomeSources = [
            IncomeSource(name: "Primary Pension", type: .pension,      annualAmount: 24_000, owner: .primary),
            IncomeSource(name: "VA Disability",   type: .vaDisability, annualAmount: 30_000, owner: .primary),
        ]

        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )

        // Only pension ($24K) should be in primaryPensionIncome; VA Disability ($30K) must be invisible.
        #expect(inputs.primaryPensionIncome == 24_000,
            "primaryPensionIncome should be $24K (pension only); got \(inputs.primaryPensionIncome)")
        // VA Disability must not appear as wage income either.
        #expect(inputs.primaryWageIncome == 0,
            "primaryWageIncome should be $0 (no employment income); got \(inputs.primaryWageIncome)")
    }
}
