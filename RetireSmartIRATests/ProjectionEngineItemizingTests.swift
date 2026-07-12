import Testing
import Foundation
@testable import RetireSmartIRA

/// Task 6 (V2.1.1): per-year standard-vs-itemized deduction selection in ProjectionEngine, with
/// deductible cash charitable (§170(p) below-the-line on the standard path, itemized charitable on
/// the itemized path). All scenarios pin `state: "TX"` (no state income tax) so the CA-SALT-itemize
/// confound cannot shift the standard-vs-itemized crossover — these tests isolate the FEDERAL effect.
///
/// Households are single filers, age 60 in the base year (born baseYear-60): below RMD age, below 65
/// (no senior bonus), pre-Medicare with ACA off, no Social Security. Income is a flat nominal pension,
/// so every projected year has an identical federal AGI. Tax is paid from an external source
/// (`.external`), so no gross-up perturbs the reported taxableIncome / federal tax — the reported
/// values equal the base per-year computation exactly.
@Suite("Task 6 — per-year standard-vs-itemized selection", .serialized)
@MainActor
struct ProjectionEngineItemizingTests {

    private var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    /// Single filer, TX, age 60, pension-only income, configurable gift plan + carried itemizables.
    private func makeInputs(
        pension: Double,
        plan: CharitableGivingPlan,
        carriedMortgageAndOther: Double = 0,
        carriedPropertyAndOtherSALT: Double = 0,
        carriedGrossMedical: Double = 0
    ) -> MultiYearStaticInputs {
        let by = baseYear - 60
        var c = DateComponents(); c.year = by; c.month = 1; c.day = 1
        let birthDate = Calendar.current.date(from: c)!
        return MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                primaryTraditionalIRA: 0, primaryTraditional401k: 0,
                spouseTraditionalIRA: 0, spouseTraditional401k: 0,
                roth: 0, taxable: 0, hsa: 0
            ),
            primaryCurrentAge: 60,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: "TX",
            primarySSClaimAge: 67,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: by,
            spouseBirthYear: nil,
            primaryBirthDate: birthDate,
            spouseBirthDate: nil,
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: pension,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0,
            charitableGivingPlan: plan,
            carriedMortgageAndOtherItemized: carriedMortgageAndOther,
            carriedPropertyAndOtherSALT: carriedPropertyAndOtherSALT,
            carriedGrossMedicalExpenses: carriedGrossMedical
        )
    }

    /// External tax payment → no gross-up perturbation of reported taxable income / federal tax.
    private func assumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0.025,
            investmentGrowthRate: 0.06, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearExpenseOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0,
            baselineAnnualExpenses: 0, taxPaymentSource: .external
        )
    }

    /// All giving is cash (QCD routed to 0): plan.hasGiving true, QCD total 0, cashCharitable = target.
    private func allCash(_ amount: Double) -> CharitableGivingPlan {
        CharitableGivingPlan(intent: .fixedAnnualAmount(amount), funding: .fixedQCD(0), maintainRealValue: false)
    }

    private func project(_ inputs: MultiYearStaticInputs) -> [YearRecommendation] {
        ProjectionEngine().project(inputs: inputs, assumptions: assumptions(), actionsPerYear: [baseYear: []])
    }

    @Test("A large all-cash gift itemizes and strictly lowers that year's federal tax")
    func bigCashGiftYearItemizesAndLowersTax() {
        // AGI = $250k pension. A $60k cash gift (plus $5k carried mortgage) makes the itemized total
        // (~$60k + $5k, less the 0.5%-AGI charitable floor) dwarf the ~$16.1k standard deduction, so
        // the year itemizes and pays strictly less federal tax than the same household with no giving.
        let withGift = project(makeInputs(pension: 250_000, plan: allCash(60_000), carriedMortgageAndOther: 5_000))
        let noGift = project(makeInputs(pension: 250_000, plan: .none))
        #expect(withGift[0].taxBreakdown.federal < noGift[0].taxBreakdown.federal)
        // And the taxable income is lower (itemized deduction chosen).
        #expect(withGift[0].taxableIncome < noGift[0].taxableIncome)
    }

    @Test("A small cash gift stays on the standard path and drops taxable income by exactly the §170(p) amount")
    func smallCashGiftUsesStandardPlus170p() {
        // AGI = $100k. A $500 cash gift: on the itemized path the 0.5%-AGI charitable floor ($500)
        // wipes the whole deduction (charitable = max(0, 500 - 500) = 0), so itemizing yields 0 and the
        // household stays on the standard path, taking §170(p) = min($500, $1,000 cap) = $500.
        // Taxable income therefore drops by exactly $500 vs. no gift.
        let withGift = project(makeInputs(pension: 100_000, plan: allCash(500)))
        let noGift = project(makeInputs(pension: 100_000, plan: .none))
        #expect(abs((noGift[0].taxableIncome - withGift[0].taxableIncome) - 500) < 0.5)
    }

    @Test("Bunching giving into one high-income year beats spreading it thin (§170(p) cap)")
    func bunchingBeatsSpreading() {
        // The CharitableGivingPlan is uniform per year, so the (30k, 0, 0) vs (10k, 10k, 10k) patterns
        // are composed from independent single-year runs — valid because cash charitable has no
        // cross-year balance effect (it is not debited from any account; it only changes the year's
        // deduction). AGI is an identical $250k every year (flat pension), so:
        //   bunch 3-yr total  = tax(gives $30k once) + 2 * tax(gives nothing)
        //   spread 3-yr total = 3 * tax(gives $10k)
        // Spreading caps each year's standard-path benefit at §170(p) = $1,000 (a $10k gift can't clear
        // the ~$16.1k standard deduction by itemizing), so bunching deducts far more per dollar given.
        let r30 = project(makeInputs(pension: 250_000, plan: allCash(30_000)))[0]
        let r10 = project(makeInputs(pension: 250_000, plan: allCash(10_000)))[0]
        let r0 = project(makeInputs(pension: 250_000, plan: .none))[0]
        let bunchTotal = r30.taxBreakdown.federal + 2 * r0.taxBreakdown.federal
        let spreadTotal = 3 * r10.taxBreakdown.federal
        // Strictly better, not merely no-worse: the bunched year deducts far more per dollar given.
        #expect(bunchTotal < spreadTotal)
        // Prove the mechanism, not just the total: the $30k year genuinely ITEMIZES — its taxable
        // income drops well past the ~$16.1k standard deduction (≈$28.75k itemized after the 0.5%-AGI
        // floor → a >$10k drop vs. no gift), whereas each $10k spread year can't clear the standard
        // deduction so it stays on the standard path and gets only the §170(p) $1,000 (a ~$1k drop).
        #expect((r0.taxableIncome - r30.taxableIncome) > 10_000)
        #expect(abs((r0.taxableIncome - r10.taxableIncome) - 1_000) < 1.0)
    }

    @Test("A no-giving, no-itemizable scenario is unchanged: standard path, §170(p)=0")
    func noGivingBaselineUnchanged() {
        // AGI = $100k, no giving, no carried itemizables, age 60 (no senior bonus). The standard path
        // must be chosen with the plain standard deduction and no §170(p): taxableIncome must equal
        // AGI - standardDeductionSingle(2026) = 100,000 - 16,100 = 83,900 (byte-identical to pre-Task-6
        // behavior), and the federal tax must equal calculateFederalTax on that ordinary-only income.
        let rows = project(makeInputs(pension: 100_000, plan: .none))
        let expectedTaxable = 100_000.0 - 16_100.0   // TaxYearConfig.swift 2026: standardDeductionSingle = 16100
        #expect(abs(rows[0].taxableIncome - expectedTaxable) < 0.5)
        let brackets = TaxYearConfigProvider.current.config(forYear: baseYear).toTaxBrackets()
        let expectedFed = TaxCalculationEngine.calculateFederalTax(
            income: expectedTaxable, filingStatus: .single, brackets: brackets, preferentialIncome: 0)
        #expect(abs(rows[0].taxBreakdown.federal - expectedFed) < 0.5)
    }
}
