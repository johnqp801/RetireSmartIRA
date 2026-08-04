import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 3b Task 5: the multi-year projection must classify pension income the
/// same way the single-year engine call does. Before this task,
/// `ProjectionEngine.computeStateTax` sums `inputs.primaryPensionIncome +
/// inputs.spousePensionIncome` into ONE scalar and synthesizes an unclassified
/// `.pension` `IncomeSource` row from it, so a New York government pension is
/// always capped at the shared $20,000 Line 29 exclusion in Multi-Year, even
/// when the equivalent single-year engine call (Line 26, uncapped) excludes it
/// in full. Same household, two different New York answers. See
/// docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
/// section 3.4b.
///
/// **Why this compares against `TaxCalculationEngine.calculateStateTax`
/// directly, not `GoldenScenarioSingleYearTests.singleYearStateTax` /
/// `scenario.expectedStateTax`:** New York's `stateDeduction` is
/// `.fixed(single: 8_000, married: 16_050)`, nonzero. `singleYearStateTax`
/// (documented as standing in for `DataManager.calculateStateTaxFromGross`)
/// subtracts that deduction from `federalAGI` BEFORE calling the engine.
/// `ProjectionEngine.computeStateTax` does not -- a grep of this file for
/// `stateDeduction`, `stateStandardDeduction` and `StateTaxConfig` returns
/// zero hits anywhere in `ProjectionEngine.swift`. That is a real,
/// PRE-EXISTING gap, orthogonal to pension classification, and it is why
/// `GoldenScenarioCrossPathTests.agreeing` is `["PA", "IL", "MS"]`: all three
/// have `stateDeduction: .none`, which makes the missing subtraction a no-op
/// for exactly those states and invisible in that suite. New York would be
/// the first state in a cross-path comparison where the gap is NOT a no-op,
/// and comparing against the golden $487.75 (which bakes the deduction in)
/// would fail for a reason this task does not touch, contaminating the
/// signal for the thing this task DOES touch. So this suite calls
/// `TaxCalculationEngine.calculateStateTax` the same way
/// `ProjectionEngine.computeStateTax` calls it -- `income: federalAGI`
/// directly, no pre-subtraction -- isolating the classification pass-through
/// Task 5 is scoped to fix. See task-5-report.md for this finding; it is not
/// fixed here.
@Suite("Phase 3b Task 5: multi-year pension classification cross-path")
struct Phase3bMultiYearPensionClassificationTests {

    /// Year-1 state tax from `ProjectionEngine.project`, for a single filer,
    /// age 65, New York, whose ONLY income is a pension of `pensionAmount`
    /// (optionally classified). `startingBalances.taxable` is set to
    /// $2,000,000: comfortably more than this household's combined federal +
    /// state tax bill, and cost-basis-equal-to-balance (the synthesized
    /// legacy bucket `ProjectionEngine.swift:142-156` builds when
    /// `taxableAccounts` is empty), so selling from it to fund the tax bill
    /// realizes ZERO gain. That keeps `dW == 0` and `saleGain == 0` in Step
    /// 7's funding cascade (`ProjectionEngine.swift:1019-1128`), so
    /// `taxBreakdown.state` is exactly the pre-cascade `computeStateTax`
    /// result at line ~777 -- this task's target -- with no additional,
    /// unrelated gross-up-recursion effect layered on top (the mechanism
    /// `GoldenScenarioCrossPathTests.newJerseyCrossPathGapPinnedAsObserved`
    /// documents for a household with NO such cushion).
    private static func yearOneStateTax(
        pensionAmount: Double,
        classification: RetirementPlanClassification?
    ) -> Double? {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 100_000, roth: 0, taxable: 2_000_000, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 65,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: "NY",
            primarySSClaimAge: 70,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 2026 - 65,
            spouseBirthYear: nil,
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: pensionAmount,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0,
            primaryPensionClassification: classification,
            spousePensionClassification: nil
        )
        let engine = ProjectionEngine()
        let path = engine.project(inputs: inputs, assumptions: MultiYearAssumptions(), actionsPerYear: [2026: []])
        return path.first?.taxBreakdown.state
    }

    /// The single-year engine call, using the EXACT convention
    /// `ProjectionEngine.computeStateTax` uses (`income: federalAGI`
    /// directly -- see the suite doc comment above for why).
    private static func engineLevelStateTax(
        federalAGI: Double,
        pensionAmount: Double,
        classification: RetirementPlanClassification?
    ) -> Double {
        var sources: [IncomeSource] = []
        if pensionAmount > 0 {
            sources.append(IncomeSource(
                name: "Pension", type: .pension, annualAmount: pensionAmount,
                owner: .primary,
                planStructure: classification?.structure,
                planSource: classification?.source
            ))
        }
        return TaxCalculationEngine.calculateStateTax(
            income: federalAGI,
            forState: .newYork,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            incomeSources: sources,
            currentAge: 65,
            enableSpouse: false,
            spouseBirthYear: 0,
            currentYear: 2026
        )
    }

    @Test("An unclassified NY pension stays capped in multi-year year 1 (baseline, unchanged by this task)")
    func unclassifiedPensionStaysCapped() throws {
        let expected = Self.engineLevelStateTax(federalAGI: 70_000, pensionAmount: 70_000, classification: nil)
        let actual = try #require(Self.yearOneStateTax(pensionAmount: 70_000, classification: nil))
        #expect(abs(actual - expected) < 0.01,
                "Unclassified pension: multi-year \(actual) should equal the engine-level call \(expected).")
    }

    @Test("New York government pension: multi-year year 1 agrees with the single-year engine call once classified")
    func classifiedGovernmentPensionMatchesSingleYearPath() throws {
        let classification = RetirementPlanClassification(structure: .definedBenefit, source: .nyStateOrLocal)

        let single = Self.engineLevelStateTax(federalAGI: 70_000, pensionAmount: 70_000, classification: classification)
        let multi = try #require(Self.yearOneStateTax(pensionAmount: 70_000, classification: classification))

        #expect(abs(single - multi) < 0.01,
                """
                NY government pension: single-year engine call \(single), multi-year year-1 \(multi).
                Same household, two engine entry points, different tax -- the projection is still
                capping what the single-year path excludes.
                """)

        // Not just two equal wrong numbers: the classified figure must actually be LOWER than
        // the capped baseline, proving Line 26's exclusion fired rather than both sides
        // coincidentally landing on the same (still-capped) value.
        let cappedBaseline = Self.engineLevelStateTax(federalAGI: 70_000, pensionAmount: 70_000, classification: nil)
        #expect(multi < cappedBaseline,
                "Classified multi-year (\(multi)) should be less than the capped baseline (\(cappedBaseline)).")
    }
}
