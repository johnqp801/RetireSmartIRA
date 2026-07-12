//
//  MultiYearGivingIntegrationTests.swift
//  RetireSmartIRATests
//
//  Task 8 (V2.1.1): MFJ end-to-end integration test exercising QCD + cash charitable together
//  under the `.limitToIRMAA` conversion approach. Closes a pre-existing 2.1 follow-up — every
//  prior ladder e2e test in ConversionApproachTests was single-filer only.
//
//  Two halves, each mirroring an existing test idiom exactly:
//
//   - Part A isolates the giving-plan mechanics with a DIRECT ProjectionEngine call (zero
//     explicit actions), exactly like QCDApplicationTests / ProjectionEngineItemizingTests do.
//     This is necessary, not just a style choice: under `.limitToIRMAA` the ladder bisects the
//     Roth conversion amount to LAND that year's MAGI at a fixed ceiling. Comparing AGI between
//     a giving-plan scenario and a no-giving scenario *through the optimizer* would just make
//     the ladder convert a different amount to hit the same ceiling in both cases, washing out
//     the QCD/cash effect entirely (verified by hand: with the ceiling binding, both scenarios'
//     `magi` converge to ~the same target regardless of the giving plan). Fixing the actions
//     (zero conversion, same as the existing QCD/itemizing e2e tests) is what makes the QCD and
//     cash-charitable effects visible and attributable.
//   - Part B proves the `.limitToIRMAA` approach itself is honored (MAGI ceiling never exceeded,
//     any year) when a giving plan is active, using OptimizationEngine().optimize(approach:)
//     exactly like ConversionApproachTests.limitToIRMAAKeepsMagiUnderTier — just MFJ instead of
//     single, and with QCD + cash charitable in play.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Task 8 — MFJ QCD+cash giving under limit-to-IRMAA (e2e)", .serialized)
@MainActor
struct MultiYearGivingIntegrationTests {

    private var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    // MARK: - Fixtures
    //
    // MFJ, TX (no state income tax, so the CA-SALT-itemize confound can't shift the standard-vs-
    // itemized crossover — mirrors Task 6's ProjectionEngineItemizingTests convention). Both
    // spouses are age 76 in the base year (born baseYear-76, Jan 1): well past owner RMD age
    // (72 for this birth cohort) AND month-precise 70½-QCD-eligible, so the household has a REAL
    // forced RMD for the QCD to offset (not just bare eligibility with nothing to shelter).
    // Traditional balances are split IRA (small — this is what caps the QCD) / 401(k) (large —
    // absorbs the forced RMD and conversions so the IRA survives for the QCD), per TradBucket's
    // "non-QCD debits deplete the 401(k) first" rule.
    private func makeInputs(plan: CharitableGivingPlan, pension: Double = 0) -> MultiYearStaticInputs {
        let birthYear = baseYear - 76
        var c = DateComponents(); c.year = birthYear; c.month = 1; c.day = 1
        let birthDate = Calendar.current.date(from: c)!
        return MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                primaryTraditionalIRA: 15_000, primaryTraditional401k: 985_000,
                spouseTraditionalIRA: 10_000, spouseTraditional401k: 990_000,
                roth: 0, taxable: 0, hsa: 0
            ),
            primaryCurrentAge: 76,
            spouseCurrentAge: 76,
            filingStatus: .marriedFilingJointly,
            state: "TX",
            primarySSClaimAge: 70,
            spouseSSClaimAge: 70,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: 0,
            primaryBirthYear: birthYear,
            spouseBirthYear: birthYear,
            primaryBirthDate: birthDate,
            spouseBirthDate: birthDate,
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: pension,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 0,
            charitableGivingPlan: plan
        )
    }

    /// Fund the target with QCDs first (the household's actual funding method); whatever the QCD
    /// caps can't cover is cash charitable, deducted by ProjectionEngine.
    private func givingPlan(target: Double) -> CharitableGivingPlan {
        CharitableGivingPlan(intent: .fixedAnnualAmount(target), funding: .qcdFirst, maintainRealValue: false)
    }

    /// External tax payment -> no gross-up perturbation of reported AGI/taxableIncome
    /// (ProjectionEngineItemizingTests convention — isolates the giving-plan mechanics cleanly).
    private func externalTaxAssumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0.025,
            investmentGrowthRate: 0.06, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearExpenseOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0,
            baselineAnnualExpenses: 0, taxPaymentSource: .external
        )
    }

    /// Mirrors ConversionApproachTests.makeAssumptions exactly, for the optimizer/approach half.
    private func ladderAssumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0.025,
            investmentGrowthRate: 0.06, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearExpenseOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0
        )
    }

    private func project(_ inputs: MultiYearStaticInputs) -> [YearRecommendation] {
        ProjectionEngine().project(inputs: inputs, assumptions: externalTaxAssumptions(),
                                   actionsPerYear: [baseYear: []])
    }

    /// IRMAA tier threshold, read the same way the engine reads it (mirrors ConversionApproachTests).
    private func irmaaTierThreshold(tier: Int, filingStatus: FilingStatus, year: Int) -> Double {
        let cfg = TaxYearConfigProvider.current.config(forYear: year)
        let tiers = cfg.toIRMAATiers()
        guard let tierEntry = tiers.first(where: { $0.tier == tier }) else { return .greatestFiniteMagnitude }
        return filingStatus == .single ? tierEntry.singleThreshold : tierEntry.mfjThreshold
    }

    // MARK: - Part A: QCD + cash charitable mechanics (direct engine, isolates each effect)

    @Test("QCD is capped by each spouse's IRA balance and excludes exactly that much from AGI")
    func qcdReducesAGIByTheCappedAmount() {
        // Both spouses' IRA balances (15k / 10k) are small relative to a $60k giving target and
        // the household's real forced RMD (age 76, ~$1M/spouse traditional) — so QCD funds only
        // PART of the target (capped at 15k + 10k = 25k combined) and cash covers the rest.
        // Compute the engine's OWN expected QCD via QCDPlanner — the real allocator, not a guess.
        let qcdLimit = TaxYearConfigProvider.current.config(forYear: baseYear).qcdAnnualLimit
        let fullPlan = givingPlan(target: 60_000)
        let expected = QCDPlanner.plan(
            fullPlan, primaryRMD: 0, spouseRMD: 0,           // unused by fixedAnnualAmount + qcdFirst
            primaryIRA: 15_000, spouseIRA: 10_000,
            primaryEligible: true, spouseEligible: true,
            qcdLimit: qcdLimit, inflationFactor: 1.0)
        #expect(expected.total < 60_000)          // QCD covers only PART of the target
        #expect(expected.total > 0)
        #expect(60_000 - expected.total > 0)      // the rest is a cash remainder

        let withGiving = project(makeInputs(plan: fullPlan))
        let noGiving = project(makeInputs(plan: .none))
        // AGI is lower by exactly the QCD total. Cash charitable is a below-AGI deduction, so it
        // cannot contaminate this comparison — this isolates the "QCD excludes from AGI" effect.
        #expect(abs((noGiving[0].agi - withGiving[0].agi) - expected.total) < 1.0)
    }

    @Test("The cash-charitable remainder is deducted on top of the QCD exclusion, itemizing the gift year")
    func cashRemainderIsDeductedAndItemizes() {
        // Two scenarios with the IDENTICAL QCD total (both spouses' IRAs are capped the same way
        // regardless of the target, since QCD is capped by IRA balance, not by the target) but
        // DIFFERENT cash remainders: a $25k target that QCD fully covers (cash = 0) vs. a $150k
        // target where QCD still covers the same 25k and cash covers the other 125k. Any taxable-
        // income difference between them is attributable ONLY to the cash-charitable deduction.
        //
        // A $300k combined pension is added (identical in both scenarios) purely to raise AGI, so
        // the 60%-of-AGI charitable ceiling doesn't clip a $125k cash gift and the itemized-vs-
        // standard crossover isn't a razor's edge (a smaller-AGI version of this scenario was tried
        // first and landed the household just barely on the standard side of the crossover, where
        // only the $2,000 MFJ §170(p) non-itemizer cap applied instead of full itemizing — a real
        // setup issue, not an engine bug: fixed by giving the itemized path more AGI headroom).
        let qcdOnly = givingPlan(target: 25_000)
        let full = givingPlan(target: 150_000)
        let qcdOnlyRows = project(makeInputs(plan: qcdOnly, pension: 300_000))
        let fullRows = project(makeInputs(plan: full, pension: 300_000))

        // Sanity: the QCD-driven AGI reduction is identical between the two (same 25k IRA-capped QCD).
        #expect(abs(qcdOnlyRows[0].agi - fullRows[0].agi) < 1.0)

        // The extra $125k cash remainder strictly lowers taxable income and federal tax...
        #expect(fullRows[0].taxableIncome < qcdOnlyRows[0].taxableIncome)
        #expect(fullRows[0].taxBreakdown.federal < qcdOnlyRows[0].taxBreakdown.federal)
        // ...and the reduction is far larger than the $2,000 MFJ §170(p) non-itemizer cap, proving
        // the household actually ITEMIZED the cash gift rather than taking the standard-path cap.
        #expect((qcdOnlyRows[0].taxableIncome - fullRows[0].taxableIncome) > 20_000)
    }

    // MARK: - Part B: `.limitToIRMAA` is honored with a giving plan in play (closes the MFJ-e2e gap)

    @Test("limitToIRMAA keeps MFJ MAGI at or below the tier ceiling every year, with QCD+cash giving active")
    func limitToIRMAAHonoredWithGivingPlan() {
        let inputs = makeInputs(plan: givingPlan(target: 60_000))
        let buffer = 2_000.0
        let result = OptimizationEngine().optimize(
            inputs: inputs, assumptions: ladderAssumptions(),
            approach: .limitToIRMAA(tier: 1, buffer: buffer))
        #expect(!result.recommendedPath.isEmpty)
        for year in result.recommendedPath {
            // Threshold is read per-year (mirrors ConversionApproachTests) since the config can
            // vary across the multi-decade horizon. The ladder never overshoots its target (the
            // bisection invariant covered by ConversionApproachTests' bisection unit tests), so
            // MAGI is at-or-below the ceiling in EVERY year, whether or not that year's QCD/cash
            // giving reshaped AGI.
            let tier1MFJ = irmaaTierThreshold(tier: 1, filingStatus: .marriedFilingJointly, year: year.year)
            #expect(year.magi <= tier1MFJ - buffer + 1)
        }
    }
}
