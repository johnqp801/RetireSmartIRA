//
//  AuditProfiles.swift
//  RetireSmartIRATests
//
//  Deterministic catalog of household profiles for the Multi-Year Display Audit Harness
//  (Stage 1, Task 2). Each `AuditProfile` bundles a full, valid set of engine inputs so
//  Task 3's `DisplaySnapshot.capture(profile, provider:)` can run the real engine and
//  snapshot every displayed value.
//
//  No RNG, no `Date()` — every value here is a literal so the catalog (and downstream
//  snapshots) are byte-for-byte reproducible across runs and machines.
//

import Foundation
@testable import RetireSmartIRA

/// One deterministic household + assumption set + conversion approach + heir-weight to run
/// through the Multi-Year engine and audit.
struct AuditProfile {
    let id: String
    let inputs: MultiYearStaticInputs
    let assumptions: MultiYearAssumptions
    let approach: ConversionApproach
    let heirWeight: Double

    /// Human-readable inputs digest for the Stage-2 audit packet (deterministic; no Date()/RNG).
    /// Keys: state, filing, age, trad, approach, heirWeight. Values are plain strings so the
    /// packet's `inputsSummary` reads cleanly in JSON without decoding the full `MultiYearStaticInputs`.
    var summary: [String: String] {
        [
            "state": inputs.state,
            "filing": String(describing: inputs.filingStatus),
            "age": String(inputs.primaryCurrentAge),
            "trad": String(inputs.startingBalances.traditional),
            "approach": String(describing: approach),
            "heirWeight": String(heirWeight),
        ]
    }
}

enum AuditProfiles {

    // MARK: - Builders (mirror HeirObjectiveTests.heirInputs)

    /// Single-filer household builder. Mirrors HeirObjectiveTests.heirInputs's construction
    /// pattern so every profile is a valid, complete MultiYearStaticInputs.
    private static func single(
        primaryAge: Int,
        traditional: Double,
        roth: Double = 0,
        taxable: Double = 0,
        state: String,
        ssClaimAge: Int = 70,
        benefitAtFRA: Double = 2_200,
        wageIncome: Double = 0,
        pensionIncome: Double = 0,
        acaEnrolled: Bool = false,
        baselineAnnualExpenses: Double = 60_000,
        heirSalary: Double = 90_000,
        givingPlan: CharitableGivingPlan = .none
    ) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                primaryTraditionalIRA: traditional, primaryTraditional401k: 0,
                spouseTraditionalIRA: 0, spouseTraditional401k: 0,
                roth: roth, taxable: taxable, hsa: 0
            ),
            baseYear: 2026,
            primaryCurrentAge: primaryAge,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: state,
            primarySSClaimAge: ssClaimAge,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: benefitAtFRA,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 2026 - primaryAge,
            spouseBirthYear: nil,
            primaryWageIncome: wageIncome, spouseWageIncome: 0,
            primaryPensionIncome: pensionIncome, spousePensionIncome: 0,
            acaEnrolled: acaEnrolled,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: baselineAnnualExpenses,
            heirSalary: heirSalary,
            heirFilingStatus: .single,
            heirDrawdownYears: 10,
            charitableGivingPlan: givingPlan
        )
    }

    /// Married-filing-jointly household builder. Mirrors the same construction pattern.
    private static func mfj(
        primaryAge: Int,
        spouseAge: Int,
        traditional: Double,
        spouseTraditional: Double = 0,
        roth: Double = 0,
        taxable: Double = 0,
        state: String,
        primarySSClaimAge: Int = 70,
        spouseSSClaimAge: Int = 70,
        primaryBenefitAtFRA: Double = 2_600,
        spouseBenefitAtFRA: Double = 1_800,
        wageIncome: Double = 0,
        pensionIncome: Double = 0,
        acaEnrolled: Bool = false,
        baselineAnnualExpenses: Double = 90_000,
        heirSalary: Double = 90_000,
        givingPlan: CharitableGivingPlan = .none
    ) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                primaryTraditionalIRA: traditional, primaryTraditional401k: 0,
                spouseTraditionalIRA: spouseTraditional, spouseTraditional401k: 0,
                roth: roth, taxable: taxable, hsa: 0
            ),
            baseYear: 2026,
            primaryCurrentAge: primaryAge,
            spouseCurrentAge: spouseAge,
            filingStatus: .marriedFilingJointly,
            state: state,
            primarySSClaimAge: primarySSClaimAge,
            spouseSSClaimAge: spouseSSClaimAge,
            primaryExpectedBenefitAtFRA: primaryBenefitAtFRA,
            spouseExpectedBenefitAtFRA: spouseBenefitAtFRA,
            primaryBirthYear: 2026 - primaryAge,
            spouseBirthYear: 2026 - spouseAge,
            primaryWageIncome: wageIncome, spouseWageIncome: 0,
            primaryPensionIncome: pensionIncome, spousePensionIncome: 0,
            acaEnrolled: acaEnrolled,
            acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: baselineAnnualExpenses,
            heirSalary: heirSalary,
            heirFilingStatus: .single,
            heirDrawdownYears: 10,
            charitableGivingPlan: givingPlan
        )
    }

    private static func assumptions(
        horizonEndAge: Int = 95,
        growth: Double = 0.06,
        cpi: Double = 0.025
    ) -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: horizonEndAge,
            horizonEndAgeSpouse: nil,
            cpiRate: cpi,
            investmentGrowthRate: growth,
            withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false,
            perYearExpenseOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0
        )
    }

    private static let fillToBracket22 = ConversionApproach.fillToBracket(rate: 0.22)
    private static let recommendedTaxMin = ConversionApproach.recommendedTaxMin

    // MARK: - Catalog

    /// Deterministic cross-product of filing status x age x traditional-balance size x state x
    /// giving x conversion approach x heir weight, plus three named finding-reproducing
    /// households. Fixed, literal list — no RNG, no Date().
    static let all: [AuditProfile] = [

        // MARK: Named finding-reproducing households

        // I1 finding: PA age-62 converter (PA excludes retirement income from state tax, so a
        // conversion at 62 interacts with PA's retirement-income exemption rules).
        AuditProfile(
            id: "pa62-single-converter",
            inputs: single(
                primaryAge: 62, traditional: 900_000, roth: 50_000, taxable: 100_000,
                state: "PA", ssClaimAge: 67, benefitAtFRA: 2_400,
                baselineAnnualExpenses: 55_000
            ),
            assumptions: assumptions(),
            approach: recommendedTaxMin,
            heirWeight: 0.0
        ),

        // B2 finding: residual-IRA high-income MFJ (large traditional balance remains at the
        // horizon; deferred-tax-on-remaining-IRA display row).
        AuditProfile(
            id: "residual-ira-highincome-mfj",
            inputs: mfj(
                primaryAge: 60, spouseAge: 58, traditional: 3_500_000, spouseTraditional: 1_200_000,
                roth: 200_000, taxable: 800_000, state: "CA",
                primaryBenefitAtFRA: 3_400, spouseBenefitAtFRA: 2_200,
                wageIncome: 150_000, baselineAnnualExpenses: 140_000, heirSalary: 180_000
            ),
            assumptions: assumptions(),
            approach: recommendedTaxMin,
            heirWeight: 0.5
        ),

        // I3 finding: $6M/CA MFJ (heir-frontier de-domination at all lambda).
        AuditProfile(
            id: "6m-ca-mfj",
            inputs: mfj(
                primaryAge: 65, spouseAge: 63, traditional: 4_500_000, spouseTraditional: 1_500_000,
                roth: 300_000, taxable: 500_000, state: "CA",
                primaryBenefitAtFRA: 3_600, spouseBenefitAtFRA: 2_800,
                baselineAnnualExpenses: 180_000, heirSalary: 200_000
            ),
            assumptions: assumptions(),
            approach: fillToBracket22,
            heirWeight: 1.0
        ),

        // MARK: Deterministic cross-product — filing x age x trad size x state x giving x
        //       approach x heir weight

        // Single filers, varying age / trad size / state / approach / heir weight.
        AuditProfile(
            id: "single-a1-fl-small-young",
            inputs: single(primaryAge: 60, traditional: 300_000, state: "FL"),
            assumptions: assumptions(), approach: recommendedTaxMin, heirWeight: 0.0
        ),
        AuditProfile(
            id: "single-a2-il-mid-fillbracket",
            inputs: single(primaryAge: 63, traditional: 700_000, state: "IL"),
            assumptions: assumptions(), approach: fillToBracket22, heirWeight: 0.25
        ),
        AuditProfile(
            id: "single-a3-ms-large-heirweighted",
            inputs: single(primaryAge: 66, traditional: 1_500_000, roth: 100_000, state: "MS"),
            assumptions: assumptions(), approach: recommendedTaxMin, heirWeight: 0.75
        ),
        AuditProfile(
            id: "single-a4-nj-small-giving",
            inputs: single(
                primaryAge: 68, traditional: 400_000, state: "NJ",
                givingPlan: CharitableGivingPlan(intent: .fixedAnnualAmount(5_000), funding: .qcdFirst, maintainRealValue: true)
            ),
            assumptions: assumptions(), approach: recommendedTaxMin, heirWeight: 0.0
        ),
        AuditProfile(
            id: "single-a5-ca-mid-irmaa",
            inputs: single(primaryAge: 64, traditional: 850_000, taxable: 200_000, state: "CA", acaEnrolled: true),
            assumptions: assumptions(), approach: .limitToIRMAA(tier: 1, buffer: 5_000), heirWeight: 0.5
        ),
        AuditProfile(
            id: "single-a6-pa-large-old",
            inputs: single(primaryAge: 72, traditional: 2_000_000, roth: 400_000, state: "PA"),
            assumptions: assumptions(), approach: fillToBracket22, heirWeight: 1.0
        ),
        AuditProfile(
            id: "single-a7-il-verylarge-noconvert",
            inputs: single(primaryAge: 70, traditional: 3_000_000, state: "IL"),
            assumptions: assumptions(), approach: .limitToIRMAA(tier: 2, buffer: 5_000), heirWeight: 0.25
        ),
        AuditProfile(
            id: "single-a8-fl-small-wage",
            inputs: single(primaryAge: 58, traditional: 250_000, state: "FL", wageIncome: 60_000),
            assumptions: assumptions(), approach: recommendedTaxMin, heirWeight: 0.0
        ),

        // MFJ households, varying age / trad size / state / approach / heir weight / giving.
        AuditProfile(
            id: "mfj-b1-fl-small-young",
            inputs: mfj(primaryAge: 61, spouseAge: 59, traditional: 500_000, state: "FL"),
            assumptions: assumptions(), approach: recommendedTaxMin, heirWeight: 0.0
        ),
        AuditProfile(
            id: "mfj-b2-nj-mid-fillbracket",
            inputs: mfj(primaryAge: 64, spouseAge: 62, traditional: 900_000, spouseTraditional: 300_000, state: "NJ"),
            assumptions: assumptions(), approach: fillToBracket22, heirWeight: 0.25
        ),
        AuditProfile(
            id: "mfj-b3-ms-large-heirweighted",
            inputs: mfj(primaryAge: 67, spouseAge: 65, traditional: 1_800_000, spouseTraditional: 600_000, roth: 200_000, state: "MS"),
            assumptions: assumptions(), approach: recommendedTaxMin, heirWeight: 0.75
        ),
        AuditProfile(
            id: "mfj-b4-il-mid-giving",
            inputs: mfj(
                primaryAge: 66, spouseAge: 64, traditional: 1_100_000, state: "IL",
                givingPlan: CharitableGivingPlan(intent: .percentOfRMD(0.25), funding: .qcdFirst, maintainRealValue: false)
            ),
            assumptions: assumptions(), approach: recommendedTaxMin, heirWeight: 0.5
        ),
        AuditProfile(
            id: "mfj-b5-pa-large-irmaa",
            inputs: mfj(primaryAge: 69, spouseAge: 67, traditional: 2_200_000, spouseTraditional: 700_000, taxable: 300_000, state: "PA", acaEnrolled: false),
            assumptions: assumptions(), approach: .limitToIRMAA(tier: 1, buffer: 5_000), heirWeight: 0.5
        ),
        AuditProfile(
            id: "mfj-b6-ca-verylarge-old",
            inputs: mfj(primaryAge: 73, spouseAge: 71, traditional: 3_800_000, spouseTraditional: 1_000_000, roth: 500_000, state: "CA"),
            assumptions: assumptions(), approach: fillToBracket22, heirWeight: 1.0
        ),
        AuditProfile(
            id: "mfj-b7-nj-small-wage",
            inputs: mfj(primaryAge: 59, spouseAge: 57, traditional: 400_000, state: "NJ", wageIncome: 90_000),
            assumptions: assumptions(), approach: recommendedTaxMin, heirWeight: 0.0
        ),
        AuditProfile(
            id: "mfj-b8-ms-mid-noconvert",
            inputs: mfj(primaryAge: 65, spouseAge: 65, traditional: 1_000_000, state: "MS"),
            assumptions: assumptions(), approach: .limitToIRMAA(tier: 2, buffer: 5_000), heirWeight: 0.25
        ),

        // Additional single-filer variants to widen coverage of age bands and horizons.
        AuditProfile(
            id: "single-c1-il-earlyclaim",
            inputs: single(primaryAge: 62, traditional: 650_000, state: "IL", ssClaimAge: 62, benefitAtFRA: 2_000),
            assumptions: assumptions(), approach: recommendedTaxMin, heirWeight: 0.0
        ),
        AuditProfile(
            id: "single-c2-fl-pension",
            inputs: single(primaryAge: 65, traditional: 1_200_000, state: "FL", pensionIncome: 30_000),
            assumptions: assumptions(), approach: fillToBracket22, heirWeight: 0.25
        ),
        AuditProfile(
            id: "single-c3-nj-shorthorizon",
            inputs: single(primaryAge: 75, traditional: 900_000, roth: 150_000, state: "NJ"),
            assumptions: assumptions(horizonEndAge: 90), approach: recommendedTaxMin, heirWeight: 0.5
        ),
        AuditProfile(
            id: "single-c4-ca-lowgrowth",
            inputs: single(primaryAge: 63, traditional: 750_000, state: "CA"),
            assumptions: assumptions(growth: 0.04, cpi: 0.02), approach: recommendedTaxMin, heirWeight: 0.0
        ),

        // Additional MFJ variants for horizon / growth / claim-age diversity.
        AuditProfile(
            id: "mfj-c1-pa-earlyclaim",
            inputs: mfj(primaryAge: 62, spouseAge: 60, traditional: 700_000, spouseTraditional: 200_000, state: "PA", primarySSClaimAge: 62, spouseSSClaimAge: 62),
            assumptions: assumptions(), approach: recommendedTaxMin, heirWeight: 0.0
        ),
        AuditProfile(
            id: "mfj-c2-ca-pension",
            inputs: mfj(primaryAge: 66, spouseAge: 64, traditional: 1_400_000, state: "CA", pensionIncome: 40_000),
            assumptions: assumptions(), approach: fillToBracket22, heirWeight: 0.25
        ),
        AuditProfile(
            id: "mfj-c3-il-shorthorizon",
            inputs: mfj(primaryAge: 78, spouseAge: 76, traditional: 1_600_000, spouseTraditional: 400_000, state: "IL"),
            assumptions: assumptions(horizonEndAge: 88), approach: recommendedTaxMin, heirWeight: 0.75
        ),
        AuditProfile(
            id: "mfj-c4-ms-lowgrowth",
            inputs: mfj(primaryAge: 64, spouseAge: 62, traditional: 850_000, state: "MS"),
            assumptions: assumptions(growth: 0.04, cpi: 0.02), approach: recommendedTaxMin, heirWeight: 0.0
        ),
    ]
}
