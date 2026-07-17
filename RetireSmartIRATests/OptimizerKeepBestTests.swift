//
//  OptimizerKeepBestTests.swift
//  RetireSmartIRATests
//
//  A5 (Track 2, V2.1.1): the greedy `.recommendedTaxMin` optimizer does NOT always minimize
//  its own objective. On ~1/3 of the expanded oracle-sweep (INV13) profiles a fixed
//  deterministic approach (fill-to-bracket / limit-to-IRMAA) produces a LOWER
//  `totalObjectiveCost` (the exact PV-in-horizon + PV-terminal objective the greedy ranks by,
//  at heirWeight=0) than the greedy path. The keep-best-of-candidates fix makes
//  `.recommendedTaxMin` compute the greedy path AND the deterministic candidate ladders and
//  return the lowest-objective one, so "Minimize lifetime tax" can never be dominated by
//  another approach on the minimize objective's OWN terms.
//
//  These tests were written RED (greedy loses on the named sweep profiles) → GREEN after the fix.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("A5 — recommendedTaxMin keep-best-of-candidates (never dominated)", .serialized)
@MainActor
struct OptimizerKeepBestTests {

    // The federal ordinary rates present in the config brackets (10/12/22/24/32/35/37).
    static let federalRates: [Double] = [0.10, 0.12, 0.22, 0.24, 0.32, 0.35, 0.37]
    // IRMAA tiers 1-5 (tier 0 is the standard zone with no surcharge / threshold 0).
    static let irmaaTiers: [Int] = [1, 2, 3, 4, 5]
    static let cliffBuffer: Double = 5_000

    static func makeAssumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95,
            horizonEndAgeSpouse: nil,
            cpiRate: 0.025,
            investmentGrowthRate: 0.06,
            withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false,
            perYearExpenseOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0
        )
    }

    /// A sweep-style household: retiree(s) with SS, a large traditional IRA, no wages, modest
    /// expenses. Mirrors the INV13 sweep profiles (filing × age × trad-size × state).
    static func makeSweepInputs(
        filing: FilingStatus,
        primaryAge: Int,
        spouseAge: Int?,
        traditional: Double,
        state: String
    ) -> MultiYearStaticInputs {
        let thisYear = Calendar.current.component(.year, from: Date())
        return MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: traditional, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: primaryAge,
            spouseCurrentAge: spouseAge,
            filingStatus: filing,
            state: state,
            primarySSClaimAge: 67,
            spouseSSClaimAge: spouseAge == nil ? nil : 67,
            primaryExpectedBenefitAtFRA: 3_333,                 // ~$40k/yr
            spouseExpectedBenefitAtFRA: spouseAge == nil ? nil : 3_000,  // ~$36k/yr
            primaryBirthYear: thisYear - primaryAge,
            spouseBirthYear: spouseAge == nil ? nil : thisYear - spouseAge!,
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: 0,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: spouseAge == nil ? 1 : 2,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: spouseAge == nil ? nil : 65,
            baselineAnnualExpenses: 100_000
        )
    }

    /// Core invariant: recommendedTaxMin's objective must be <= every deterministic candidate's
    /// objective (fill-to-bracket at each rate; limit-to-IRMAA at each tier). RED today for the
    /// sweep's known-failing profiles; GREEN after keep-best-of-candidates.
    private func assertNeverDominated(_ inputs: MultiYearStaticInputs, _ label: String) {
        let asmp = Self.makeAssumptions()
        let engine = OptimizationEngine()
        let taxMin = engine.optimize(inputs: inputs, assumptions: asmp,
                                     heirWeight: 0, approach: .recommendedTaxMin).totalObjectiveCost

        for rate in Self.federalRates {
            let cand = engine.optimize(inputs: inputs, assumptions: asmp,
                                       heirWeight: 0, approach: .fillToBracket(rate: rate)).totalObjectiveCost
            // Tiny tolerance for FP noise; the real gaps are $6k–$442k.
            #expect(taxMin <= cand + 1.0,
                    "\(label): recommendedTaxMin (\(taxMin)) dominated by fillToBracket(\(rate)) (\(cand))")
        }
        for tier in Self.irmaaTiers {
            let cand = engine.optimize(inputs: inputs, assumptions: asmp,
                                       heirWeight: 0,
                                       approach: .limitToIRMAA(tier: tier, buffer: Self.cliffBuffer)).totalObjectiveCost
            #expect(taxMin <= cand + 1.0,
                    "\(label): recommendedTaxMin (\(taxMin)) dominated by limitToIRMAA(tier \(tier)) (\(cand))")
        }
    }

    @Test("MFJ / age 63 / $6M / CA — recommendedTaxMin never dominated (the worst sweep case)")
    func mfjAge63_6M_CA_neverDominated() {
        let inputs = Self.makeSweepInputs(filing: .marriedFilingJointly, primaryAge: 63,
                                          spouseAge: 63, traditional: 6_000_000, state: "CA")
        assertNeverDominated(inputs, "MFJ/age63/$6M/CA")
    }

    @Test("MFJ / age 68 / $1.8M / PA — recommendedTaxMin never dominated")
    func mfjAge68_1_8M_PA_neverDominated() {
        let inputs = Self.makeSweepInputs(filing: .marriedFilingJointly, primaryAge: 68,
                                          spouseAge: 68, traditional: 1_800_000, state: "PA")
        assertNeverDominated(inputs, "MFJ/age68/$1.8M/PA")
    }

    @Test("Single / age 63 / $1.8M / PA — recommendedTaxMin never dominated")
    func singleAge63_1_8M_PA_neverDominated() {
        let inputs = Self.makeSweepInputs(filing: .single, primaryAge: 63,
                                          spouseAge: nil, traditional: 1_800_000, state: "PA")
        assertNeverDominated(inputs, "single/age63/$1.8M/PA")
    }

    /// A5 guarantee on a strong-greedy profile: recommendedTaxMin is never dominated by ANY
    /// user-selectable deterministic candidate (`taxMin <= cand` for all). Under the pre-2026-07-17
    /// objective this profile's greedy STRICTLY beat every ladder (~$15k margin) and the test
    /// asserted strict `<`; the wealth-consistent objective (all tax flows discounted at the
    /// growth rate) moved the optimum onto a deterministic ladder, so recommendedTaxMin now TIES
    /// the best candidate exactly (equality = the same plan, which is precisely the never-dominated
    /// contract at work). Ties keep the incumbent greedy per keep-best's `<` substitution rule.
    @Test("Strong-greedy profile: recommendedTaxMin is never dominated by any candidate")
    func greedyWinsProfileIsNoOp() {
        let inputs = Self.makeSweepInputs(filing: .single, primaryAge: 68,
                                          spouseAge: nil, traditional: 1_800_000, state: "CA")
        let asmp = Self.makeAssumptions()
        let engine = OptimizationEngine()
        let taxMin = engine.optimize(inputs: inputs, assumptions: asmp,
                                     heirWeight: 0, approach: .recommendedTaxMin).totalObjectiveCost
        for rate in Self.federalRates {
            let cand = engine.optimize(inputs: inputs, assumptions: asmp,
                                       heirWeight: 0, approach: .fillToBracket(rate: rate)).totalObjectiveCost
            #expect(taxMin <= cand + 0.01, "recommendedTaxMin must not be dominated by fillToBracket(\(rate))")
        }
        for tier in Self.irmaaTiers {
            let cand = engine.optimize(inputs: inputs, assumptions: asmp,
                                       heirWeight: 0,
                                       approach: .limitToIRMAA(tier: tier, buffer: Self.cliffBuffer)).totalObjectiveCost
            #expect(taxMin <= cand + 0.01, "recommendedTaxMin must not be dominated by limitToIRMAA(tier \(tier))")
        }
    }

    /// The λ>0 heir-weighted path is unaffected by keep-best (scope: A5 applies to
    /// recommendedTaxMin at heirWeight=0 / the frontier λ=0 endpoint; other λ use the greedy
    /// heir-weighted path). This just confirms optimize still returns a valid non-empty path at λ>0.
    @Test("Heir-weighted (λ>0) recommendedTaxMin still returns a valid path")
    func heirWeightedPathStillValid() {
        let inputs = Self.makeSweepInputs(filing: .marriedFilingJointly, primaryAge: 63,
                                          spouseAge: 63, traditional: 6_000_000, state: "CA")
        let asmp = Self.makeAssumptions()
        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: asmp,
                                                   heirWeight: 0.5, approach: .recommendedTaxMin)
        #expect(!result.recommendedPath.isEmpty)
        #expect(result.totalObjectiveCost > 0)
    }
}
