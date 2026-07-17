import Testing
import Foundation
@testable import RetireSmartIRA

/// Cross-λ Pareto-repair regression: the heir frontier runs the optimizer independently at each
/// preset weight, so on non-convergent profiles a higher-heir-weight point could plot MORE owner
/// tax AND FEWER heir dollars than a lower-weight point — a strictly dominated point. The frontier
/// must never surface such a point. Mirrors the v2.2 audit harness's `frontier.nonDominated`
/// invariant (Pareto non-domination on both display axes + heirsKeep monotone in weight, ε = $1).
///
/// These two households are confirmed offenders reproduced by the harness (single-c3-nj-shorthorizon,
/// mfj-c3-il-shorthorizon). See memory `frontier-cross-lambda-domination`.
@Suite("Heir frontier is cross-λ Pareto non-dominated", .serialized)
@MainActor
struct HeirFrontierParetoRepairTests {

    private static let epsilon = 1.0

    /// Returns human-readable descriptions of every domination / monotonicity violation, mirroring
    /// the audit harness predicate. Empty ⇒ the frontier is a proper non-dominated trade-off.
    private func violations(_ points: [FrontierPoint]) -> [String] {
        let eps = Self.epsilon
        var out: [String] = []
        for i in points.indices {
            let pi = points[i]
            for j in points.indices where j != i {
                let pj = points[j]
                let jNoWorseTax = pj.ownerLifetimeTaxToday <= pi.ownerLifetimeTaxToday + eps
                let jNoWorseHeirs = pj.heirAfterTaxInheritanceToday >= pi.heirAfterTaxInheritanceToday - eps
                let jStrictlyBetter = pj.ownerLifetimeTaxToday < pi.ownerLifetimeTaxToday - eps
                    || pj.heirAfterTaxInheritanceToday > pi.heirAfterTaxInheritanceToday + eps
                if jNoWorseTax && jNoWorseHeirs && jStrictlyBetter {
                    out.append("weight \(pi.weight) (tax \(pi.ownerLifetimeTaxToday), heirs \(pi.heirAfterTaxInheritanceToday)) dominated by weight \(pj.weight) (tax \(pj.ownerLifetimeTaxToday), heirs \(pj.heirAfterTaxInheritanceToday))")
                    break
                }
            }
        }
        let sorted = points.sorted { $0.weight < $1.weight }
        for k in 1..<sorted.count where sorted[k].heirAfterTaxInheritanceToday < sorted[k - 1].heirAfterTaxInheritanceToday - eps {
            out.append("heirsKeep decreased with weight: \(sorted[k - 1].weight)→\(sorted[k].weight)")
        }
        return out
    }

    private func singleInputs(age: Int, traditional: Double, roth: Double, state: String) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: traditional, roth: roth, taxable: 0, hsa: 0),
            baseYear: 2026, primaryCurrentAge: age, spouseCurrentAge: nil,
            filingStatus: .single, state: state,
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 2_200, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 2026 - age, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 60_000, heirSalary: 90_000,
            heirFilingStatus: .single, heirDrawdownYears: 10)
    }

    private func mfjInputs(primaryAge: Int, spouseAge: Int, traditional: Double, spouseTraditional: Double, state: String) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                primaryTraditionalIRA: traditional, primaryTraditional401k: 0,
                spouseTraditionalIRA: spouseTraditional, spouseTraditional401k: 0,
                roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026, primaryCurrentAge: primaryAge, spouseCurrentAge: spouseAge,
            filingStatus: .marriedFilingJointly, state: state,
            primarySSClaimAge: 70, spouseSSClaimAge: 70,
            primaryExpectedBenefitAtFRA: 2_600, spouseExpectedBenefitAtFRA: 1_800,
            primaryBirthYear: 2026 - primaryAge, spouseBirthYear: 2026 - spouseAge,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 90_000, heirSalary: 90_000,
            heirFilingStatus: .single, heirDrawdownYears: 10)
    }

    private func assumptions(horizonEndAge: Int) -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: horizonEndAge, horizonEndAgeSpouse: nil,
            cpiRate: 0.025, investmentGrowthRate: 0.06,
            withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
    }

    @Test("single-c3-nj-shorthorizon frontier has no dominated points")
    func njShortHorizon() {
        let provider = TaxYearConfigProvider.fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
        let inputs = singleInputs(age: 75, traditional: 900_000, roth: 150_000, state: "NJ")
        let result = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs, assumptions: assumptions(horizonEndAge: 90), configProvider: provider)
        let v = violations(result.points)
        #expect(v.isEmpty, "frontier should be non-dominated but found: \(v)")
    }

    @Test("mfj-c3-il-shorthorizon frontier has no dominated points")
    func ilShortHorizon() {
        let provider = TaxYearConfigProvider.fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
        let inputs = mfjInputs(primaryAge: 78, spouseAge: 76, traditional: 1_600_000, spouseTraditional: 400_000, state: "IL")
        let result = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs, assumptions: assumptions(horizonEndAge: 88), configProvider: provider)
        let v = violations(result.points)
        #expect(v.isEmpty, "frontier should be non-dominated but found: \(v)")
    }
}
