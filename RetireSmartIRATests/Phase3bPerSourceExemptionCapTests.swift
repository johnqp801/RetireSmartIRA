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

    /// A SYNTHETIC config in NY's Section 612(c)(3-a) CAP SHAPE (design doc
    /// 3.3): government pension excluded outright and independently,
    /// everything else sharing ONE $20,000 cap, doubled once per return when
    /// both spouses individually qualify. Flat 10% / no standard deduction, so
    /// every expected value below is exact, hand-derived arithmetic rather than
    /// a bracket walk.
    ///
    /// NOT NEW YORK'S ACTUAL SHIPPED RULE, and this comment used to claim it
    /// was. The whole-branch review widened New York's real `matchSources` to
    /// `[.nyStateOrLocal, .federalCivilian, .uniformedServices]`, and this
    /// helper deliberately keeps the narrower pair, because what it exercises
    /// is the CAP MECHANICS (one pool, one cap, the per-individual doubling and
    /// the independence of the per-source exclusion from the pooled one), none
    /// of which turns on which sources the rule names. Leaving the claim
    /// uncorrected would have made this a second, divergent description of New
    /// York's rule living in the test target, so read the source list below as
    /// "some matched source and some unmatched source", not as New York's.
    /// `Phase5bNewYorkMilitaryTests` is what pins the real rule.
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
                    PerSourceExemptionRule(
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
    ///
    /// The private pension is deliberately BELOW the $20,000 cap ($15,000,
    /// not e.g. $25,000): if the shared-cap base wrongly pooled the matched
    /// government pension back in, `min(pooled, 20_000)` would still equal
    /// `min(unmatched alone, 20_000)` whenever the unmatched amount already
    /// exceeds the cap on its own, and that mutation would pass silently.
    /// Below the cap the two bases diverge ($65,000 pooled vs $15,000
    /// unmatched), so this is the case that actually discriminates "a
    /// matched amount still counts toward the shared cap" -- see the report
    /// for the mutation proof.
    ///
    /// `income` ($115,000) is deliberately larger than the two pensions'
    /// $65,000 sum -- the extra $50,000 models other ordinary income not
    /// itemized as a source here. Without it, BOTH the correct total
    /// exclusion ($65,000) and the mutated one ($70,000: $50,000 outright +
    /// a $20,000-capped $65,000 pooled base) would exceed a $65,000 income
    /// and floor taxable income at $0 either way, hiding the mutation behind
    /// the SAME saturation this case already exists to rule out on the cap
    /// side. With $115,000 of income, the two paths land at different
    /// nonzero taxable amounts ($50,000 vs $45,000), so the mutation is
    /// caught on the tax figure itself.
    @Test("An uncapped government pension consumes none of the $20,000 shared with capped private income")
    func governmentPensionConsumesNoneOfSharedCap() {
        let sources = [
            IncomeSource(name: "NY Pension", type: .pension, annualAmount: 50_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .nyStateOrLocal),
            IncomeSource(name: "Private Pension", type: .pension, annualAmount: 15_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer)
        ]
        let tax = TaxCalculationEngine.calculateStateTax(
            income: 115_000, forState: .newYork, filingStatus: .single,
            taxableSocialSecurity: 0, incomeSources: sources,
            currentAge: 65, enableSpouse: false, spouseBirthYear: 1961,
            currentYear: 2026, configOverride: Self.nyShapedConfig())

        #expect(tax == 5_000,
                """
                $50,000 government pension excluded outright (Line 26) + the \
                full $15,000 private pension excluded (Line 29, under the \
                $20,000 cap on its own, unaffected by the government \
                pension): taxable $115,000 - $65,000 = $50,000 @ 10% = \
                $5,000. A bug that pooled the government pension INTO the \
                shared cap base (ignoring the per-source match) would compute \
                combinedIncome $65,000, still capped at $20,000 (not \
                $65,000), leaving $115,000 - $50,000 - $20,000 = $45,000 \
                taxable ($4,500 tax) -- understating this taxpayer's bill by \
                $500, exactly Alan's bug in the direction that costs the \
                state revenue instead of the taxpayer.
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
            IncomeSource(name: "Private Pension", type: .pension, annualAmount: 15_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .privateEmployer),
            // Mirrors the engine test's income: 115_000 (see that test's doc
            // comment for why $65,000 of pension income alone would floor
            // taxable income at $0 under both the correct AND the mutated
            // computation, hiding the mutation). The mirror has no separate
            // `income:` parameter -- it derives gross income from
            // `incomeSources` -- so this $50,000 ordinary-interest row plays
            // the same role the engine test's higher scalar plays there.
            // `.interest` is ordinary income (not pension/RMD), so it never
            // reaches `matchedPerSourceRule` and is untouched by either the
            // correct or the mutated cap logic.
            IncomeSource(name: "Other Ordinary Income", type: .interest, annualAmount: 50_000)
        ]

        let breakdown = dm.stateTaxBreakdown(
            forState: .newYork, filingStatus: .single, configOverride: Self.nyShapedConfig())

        #expect(breakdown.pensionExemptAmount == 65_000,
                "the full $50,000 government pension (outright) plus the full $15,000 private pension (under the cap on its own)")
        #expect(breakdown.totalStateTax == 5_000)
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
