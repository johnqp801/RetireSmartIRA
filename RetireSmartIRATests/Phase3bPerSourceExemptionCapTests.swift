//
//  Phase3bPerSourceExemptionCapTests.swift
//  RetireSmartIRATests
//
//  Task 4, Step 4a: five cap tests derived from the statute (NY Tax Law
//  Section 612(c)(3) and Section 612(c)(3-a), IT-201 Lines 26/29 -- see
//  GoldenScenarios/statetax-2026-NY.golden.json for the primary-source
//  citations), not from observed engine output. These exercise
//  `perSourceExemptions` as a PARTITION: a matched row is excluded outright
//  and contributes nothing to the shared $20,000 pension/IRA cap; everything
//  unmatched pools into the EXISTING, unchanged
//  `pensionAndIRAShareSingleCap` + `exemptionAppliesPerIndividual` machinery.
//  See docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
//  section 3.4a.
//
//  Case 1 is the one the brief requires to discriminate against a per-
//  component cap loop, and it is proven to by mutation below (see the
//  report). All five use a flat 10% NY-shaped config (real NY progressive
//  brackets would make the arithmetic unreadable; the golden scenarios in
//  statetax-2026-NY.golden.json already cover the real bracket math).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 3b Task 4, Step 4a: per-source rules partition the shared cap, never evaluate it per row")
struct Phase3bPerSourceExemptionCapTests {

    /// NY's actual Section 612(c)(3-a) shape (design doc 3.3): government
    /// pension excluded outright and independently, everything else sharing
    /// ONE $20,000 cap, doubled once per return when both spouses
    /// individually qualify. Flat 10% / no standard deduction, so every
    /// expected value below is exact, hand-derived arithmetic rather than a
    /// bracket walk.
    static func nyShapedConfig() -> StateTaxConfig {
        StateTaxConfig(
            state: .newYork,
            taxSystem: .flat(rate: 0.10),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false,
                pensionExemption: .partial(maxExempt: 20_000),
                iraWithdrawalExemption: .partial(maxExempt: 20_000),
                exemptionAppliesPerIndividual: true,
                regularExemptionMinAge: 59,
                pensionAndIRAShareSingleCap: true,
                perSourceExemptions: [
                    RetirementIncomeExemptions.PerSourceExemptionRule(
                        matchSources: [.nyStateOrLocal, .federalCivilian],
                        matchStructures: [.definedBenefit],
                        treatment: .full)
                ]
            ),
            stateDeduction: .none)
    }

    // MARK: - Case 1: two private pensions, ONE $20,000 cap, not two

    /// Statute-derived: Section 612(c)(3-a) grants ONE $20,000 exclusion per
    /// qualifying individual, not one per pension. Two private pensions held
    /// by the same taxpayer must share the single cap.
    @Test("Two private pensions owned by the primary share ONE $20,000 cap, not two")
    func twoPrivatePensionsShareOneCap() {
        let sources = [
            IncomeSource(name: "Pension A", type: .pension, annualAmount: 15_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer),
            IncomeSource(name: "Pension B", type: .pension, annualAmount: 15_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer)
        ]
        let tax = TaxCalculationEngine.calculateStateTax(
            income: 30_000, forState: .newYork, filingStatus: .single,
            taxableSocialSecurity: 0, incomeSources: sources,
            currentAge: 65, enableSpouse: false, spouseBirthYear: 1961,
            currentYear: 2026, configOverride: Self.nyShapedConfig())

        #expect(tax == 1_000,
                """
                ONE $20,000 cap on the pooled $30,000 (two $15,000 pensions): \
                taxable $10,000 @ 10% = $1,000. A per-component cap loop would \
                let BOTH $15,000 pensions pass under the cap individually and \
                exempt the full $30,000 (tax $0), which is the historical New \
                York double-$20,000 bug applied at the pension level.
                """)
    }

    /// Mirror side of the same case, and the mirror's own Step 4a discriminator.
    @Test("The mirror shares ONE $20,000 cap across two private pensions, not two")
    @MainActor func mirrorTwoPrivatePensionsShareOneCap() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.selectedState = .newYork
        dm.incomeSources = [
            IncomeSource(name: "Pension A", type: .pension, annualAmount: 15_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer),
            IncomeSource(name: "Pension B", type: .pension, annualAmount: 15_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer)
        ]

        let breakdown = dm.stateTaxBreakdown(
            forState: .newYork, filingStatus: .single, configOverride: Self.nyShapedConfig())

        #expect(breakdown.pensionExemptAmount == 20_000,
                "the pooled $30,000 must be capped ONCE at $20,000, not twice (which would read $30,000)")
        #expect(breakdown.totalStateTax == 1_000)
    }

    // MARK: - Case 2: one IRA distribution + one private pension, one shared cap

    /// `pensionAndIRAShareSingleCap` already enforces this; this proves the
    /// per-source partition (added in this task) does not disturb it when
    /// nothing matches a rule.
    @Test("An IRA distribution plus a private pension share one cap, unaffected by per-source partitioning")
    func iraPlusPrivatePensionShareOneCap() {
        let sources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 15_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer)
        ]
        let tax = TaxCalculationEngine.calculateStateTax(
            income: 30_000, forState: .newYork, filingStatus: .single,
            taxableSocialSecurity: 0, incomeSources: sources,
            currentAge: 65, enableSpouse: false, spouseBirthYear: 1961,
            currentYear: 2026, scenarioRetirementDistributions: 15_000,
            configOverride: Self.nyShapedConfig())

        #expect(tax == 1_000,
                "pension $15,000 + IRA $15,000 = $30,000 pooled, ONE $20,000 cap, taxable $10,000 @ 10% = $1,000")
    }

    // MARK: - Case 3: both spouses qualify, the cap doubles ONCE (existing exemptionAppliesPerIndividual), not per component

    /// Statute-derived: each SPOUSE gets their own $20,000 (IT-201
    /// instructions, per-person cap), so MFJ where both individually qualify
    /// doubles the cap to $40,000 -- but as ONE doubled pool, via the
    /// existing `exemptionAppliesPerIndividual` mechanism, not as two
    /// separately-doubled per-component caps.
    @Test("Both spouses qualifying doubles the cap ONCE for the pooled total, not per component")
    func bothSpousesQualifyDoublesCapOnce() {
        let sources = [
            IncomeSource(name: "Primary Pension", type: .pension, annualAmount: 22_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer),
            IncomeSource(name: "Spouse Pension", type: .pension, annualAmount: 22_000, owner: .spouse,
                         planStructure: .definedBenefit, planSource: .privateEmployer)
        ]
        let tax = TaxCalculationEngine.calculateStateTax(
            income: 44_000, forState: .newYork, filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0, incomeSources: sources,
            currentAge: 65, enableSpouse: true, spouseBirthYear: 1961,
            currentYear: 2026, configOverride: Self.nyShapedConfig())

        #expect(tax == 400,
                """
                pooled $44,000 capped ONCE at the doubled $40,000 (2 x $20,000): \
                taxable $4,000 @ 10% = $400. A bug that doubled the cap AND \
                applied it per component (each $22,000 pension against its own \
                $40,000 cap) would exempt the full $44,000 instead (tax $0).
                """)
    }

    // MARK: - Case 4: uncapped government pension + capped private income, independent

    /// The core New York rule itself (Alan's bug), stated as a cap test: the
    /// government pension is excluded independently and consumes NONE of the
    /// $20,000, so the private income's cap binds exactly as if the
    /// government pension were not in the return at all.
    @Test("An uncapped government pension consumes none of the $20,000 shared with capped private income")
    func governmentPensionConsumesNoneOfSharedCap() {
        let sources = [
            IncomeSource(name: "NY Pension", type: .pension, annualAmount: 50_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .nyStateOrLocal),
            IncomeSource(name: "Private Pension", type: .pension, annualAmount: 25_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer)
        ]
        let tax = TaxCalculationEngine.calculateStateTax(
            income: 75_000, forState: .newYork, filingStatus: .single,
            taxableSocialSecurity: 0, incomeSources: sources,
            currentAge: 65, enableSpouse: false, spouseBirthYear: 1961,
            currentYear: 2026, configOverride: Self.nyShapedConfig())

        #expect(tax == 500,
                """
                $50,000 government pension excluded outright (Line 26) + \
                $20,000 of the $25,000 private pension excluded (Line 29 cap, \
                unaffected by the government pension): taxable $5,000 @ 10% = \
                $500. A bug that pooled the government pension INTO the shared \
                cap base (ignoring the per-source match) would compute \
                combinedIncome $75,000, still capped at $20,000, leaving \
                $55,000 taxable ($5,500 tax) -- overstating this taxpayer's \
                bill more than tenfold, exactly Alan's bug.
                """)
    }

    @Test("The mirror: an uncapped government pension consumes none of the shared cap")
    @MainActor func mirrorGovernmentPensionConsumesNoneOfSharedCap() {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 1961; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        dm.selectedState = .newYork
        dm.incomeSources = [
            IncomeSource(name: "NY Pension", type: .pension, annualAmount: 50_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .nyStateOrLocal),
            IncomeSource(name: "Private Pension", type: .pension, annualAmount: 25_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer)
        ]

        let breakdown = dm.stateTaxBreakdown(
            forState: .newYork, filingStatus: .single, configOverride: Self.nyShapedConfig())

        #expect(breakdown.pensionExemptAmount == 70_000,
                "the full $50,000 government pension (outright) plus the $20,000 capped private share")
        #expect(breakdown.totalStateTax == 500)
    }

    // MARK: - Case 5: several capped sources summing past $20,000, the excess is taxed

    @Test("Several capped private pensions summing past $20,000: the excess is taxed")
    func severalCappedSourcesExcessTaxed() {
        let sources = [
            IncomeSource(name: "Pension A", type: .pension, annualAmount: 10_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer),
            IncomeSource(name: "Pension B", type: .pension, annualAmount: 8_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer),
            IncomeSource(name: "Pension C", type: .pension, annualAmount: 7_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer)
        ]
        let tax = TaxCalculationEngine.calculateStateTax(
            income: 25_000, forState: .newYork, filingStatus: .single,
            taxableSocialSecurity: 0, incomeSources: sources,
            currentAge: 65, enableSpouse: false, spouseBirthYear: 1961,
            currentYear: 2026, configOverride: Self.nyShapedConfig())

        #expect(tax == 500,
                "three pensions pool to $25,000, capped at $20,000, taxable $5,000 @ 10% = $500")
    }
}
