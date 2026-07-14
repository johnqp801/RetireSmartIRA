//
//  ApproachComparisonTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 2b — three-way approach comparison", .serialized)
@MainActor
struct ApproachComparisonTests {

    @Test("YearRecommendation surfaces taxable Social Security, and it rises with more ordinary income")
    func surfacesTaxableSocialSecurity() {
        // A household collecting SS: a projection with a large Roth conversion pushes provisional
        // income up, so more of the SS becomes taxable than the no-conversion baseline.
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let base = inputs.baseYear
        let noConv = ProjectionEngine().project(inputs: inputs, assumptions: asmp,
                                                actionsPerYear: [base: []])
        let withConv = ProjectionEngine().project(inputs: inputs, assumptions: asmp,
                                                  actionsPerYear: [base: [.rothConversion(amount: 80_000)]])
        #expect(noConv[0].taxableSocialSecurity >= 0)
        #expect(withConv[0].taxableSocialSecurity >= noConv[0].taxableSocialSecurity)
    }
}

extension ApproachComparisonTests {
    static func makeAssumptions(
        cpi: Double = 0.025,
        growth: Double = 0.06,
        rule: WithdrawalOrderingRule = .taxEfficient
    ) -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95,
            horizonEndAgeSpouse: nil,
            cpiRate: cpi,
            investmentGrowthRate: growth,
            withdrawalOrderingRule: rule,
            stressTestEnabled: false,
            perYearExpenseOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0
        )
    }

    static func makeInputsWithSocialSecurity(
        currentAge: Int = 67,
        traditional: Double = 900_000,
        roth: Double = 0,
        taxable: Double = 0,
        hsa: Double = 0,
        wageIncome: Double = 0,
        pensionIncome: Double = 0,
        baselineExpenses: Double = 0,
        ssClaimAge: Int = 67,
        expectedBenefitAtFRA: Double = 3_333,  // monthly (~$40k/yr)
        filingStatus: FilingStatus = .single,
        state: String = "CA",
        netInvestmentIncome: Double = 0
    ) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: traditional, roth: roth, taxable: taxable, hsa: hsa),
            primaryCurrentAge: currentAge,
            spouseCurrentAge: nil,
            filingStatus: filingStatus,
            state: state,
            primarySSClaimAge: ssClaimAge,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: expectedBenefitAtFRA,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - currentAge,
            spouseBirthYear: nil,
            primaryWageIncome: wageIncome,
            spouseWageIncome: 0,
            primaryPensionIncome: pensionIncome,
            spousePensionIncome: 0,
            primaryNetInvestmentIncome: netInvestmentIncome,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: baselineExpenses
        )
    }
}

extension ApproachComparisonTests {
    @Test("PlanPathMetrics matches PlanComparison's own derivations on the same path")
    func planPathMetricsAgreeWithPlanComparison() {
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let base = inputs.baseYear
        let path = ProjectionEngine().project(inputs: inputs, assumptions: asmp, actionsPerYear: [base: []])

        let pc = PlanComparison(plan: path, doingNothing: path,
                                heirSalary: inputs.heirSalary,
                                heirFilingStatus: inputs.heirFilingStatus,
                                heirDrawdownYears: inputs.heirDrawdownYears)

        #expect(PlanPathMetrics.lifetimeTax(path) == pc.lifetimeTax.plan)
        #expect(PlanPathMetrics.endingTraditional(path) == pc.endingTraditional.plan)
        #expect(PlanPathMetrics.endingRoth(path) == pc.endingRoth.plan)
        #expect(PlanPathMetrics.endingTaxable(path) == pc.endingTaxable.plan)
        #expect(PlanPathMetrics.peakForcedRMD(path) == pc.peakForcedRMD.plan)
        #expect(PlanPathMetrics.heirsKeep(path, heirSalary: inputs.heirSalary,
                                          heirFilingStatus: inputs.heirFilingStatus,
                                          heirDrawdownYears: inputs.heirDrawdownYears) == pc.heirsKeep.plan)
    }
}

extension ApproachComparisonTests {
    @Test("ConsequenceDeltas subtract channel sums and reconcile with the total")
    func consequenceDeltasReconcile() {
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let base = inputs.baseYear
        let noConv = ProjectionEngine().project(inputs: inputs, assumptions: asmp,
                                                actionsPerYear: [base: []])
        let selected = OptimizationEngine().optimize(inputs: inputs, assumptions: asmp,
                                                     approach: .fillToBracket(rate: 0.24)).recommendedPath

        let d = ConsequenceDeltas(selected: selected, noConversion: noConv)

        func channelSum(_ p: [YearRecommendation], _ kp: KeyPath<TaxBreakdown, Double>) -> Double {
            p.reduce(0) { $0 + $1.taxBreakdown[keyPath: kp] }
        }
        #expect(abs(d.federal - (channelSum(selected, \.federal) - channelSum(noConv, \.federal))) < 0.01)
        #expect(abs(d.niit   - (channelSum(selected, \.niit)    - channelSum(noConv, \.niit)))    < 0.01)
        // Channel deltas reconcile with the total delta (no double-count, NIIT counted once).
        let totalDelta = channelSum(selected, \.federal) + channelSum(selected, \.state)
            + channelSum(selected, \.irmaa) + channelSum(selected, \.acaPremiumImpact) + channelSum(selected, \.niit)
            - (channelSum(noConv, \.federal) + channelSum(noConv, \.state)
               + channelSum(noConv, \.irmaa) + channelSum(noConv, \.acaPremiumImpact) + channelSum(noConv, \.niit))
        #expect(abs(d.total - totalDelta) < 1.0)
    }
}

extension ApproachComparisonTests {
    @Test("ConsequenceFlags trip when the selected approach pushes past baseline thresholds")
    func consequenceFlagsTrip() {
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let base = inputs.baseYear
        let noConv = ProjectionEngine().project(inputs: inputs, assumptions: asmp,
                                                actionsPerYear: [base: []])
        let selected = OptimizationEngine().optimize(inputs: inputs, assumptions: asmp,
                                                     approach: .fillToBracket(rate: 0.24)).recommendedPath

        let flags = ConsequenceFlags(selected: selected, noConversion: noConv,
                                     filingStatus: inputs.filingStatus, configProvider: .current)

        // A fill-to-24% ladder on an SS household raises ordinary income and SS inclusion.
        #expect(flags.ordinaryBracketCrossed || flags.ssTaxationIncreased)
    }

    @Test("ConsequenceFlags are all false when selected == no-conversion baseline")
    func consequenceFlagsAllFalseWhenIdentical() {
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let base = inputs.baseYear
        let noConv = ProjectionEngine().project(inputs: inputs, assumptions: asmp,
                                                actionsPerYear: [base: []])
        let flags = ConsequenceFlags(selected: noConv, noConversion: noConv,
                                     filingStatus: inputs.filingStatus, configProvider: .current)
        #expect(flags == ConsequenceFlags(ssTaxationIncreased: false, irmaaTierCrossed: false,
                                          acaCliffCrossed: false, ordinaryBracketCrossed: false,
                                          capGainBracketAffected: false, niitIncreased: false))
    }
}

extension ApproachComparisonTests {
    @Test("Coordinator runs the three paths; deterministic approach differs from no-conversion")
    func coordinatorProducesThreeColumns() {
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let cmp = ApproachComparisonCoordinator().compare(
            inputs: inputs, assumptions: asmp,
            selectedApproach: .fillToBracket(rate: 0.24), heirWeight: 0)

        #expect(!cmp.collapsesToTwoColumns)                             // selected != recommendedTaxMin
        #expect(cmp.selected.path.count == cmp.noAdditionalConversions.path.count)
        // Filling to 24% converts more than doing nothing → less ending traditional.
        #expect(cmp.selected.endingTraditional <= cmp.noAdditionalConversions.endingTraditional)
        // Deltas are wired to selected-vs-noConversion.
        let expected = ConsequenceDeltas(selected: cmp.selected.path,
                                         noConversion: cmp.noAdditionalConversions.path)
        #expect(cmp.deltas == expected)
    }

    @Test("Selected == recommendedTaxMin collapses to two columns and does not run the optimizer twice")
    func recommendedApproachCollapses() {
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let cmp = ApproachComparisonCoordinator().compare(
            inputs: inputs, assumptions: asmp,
            selectedApproach: .recommendedTaxMin, heirWeight: 0)

        #expect(cmp.collapsesToTwoColumns)
        #expect(cmp.selected == cmp.recommended)   // identical column when collapsed
    }
}

extension ApproachComparisonTests {
    @Test("CPA briefing summarizes selected-vs-recommended deltas")
    func cpaBriefingApproachDelta() {
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let cmp = ApproachComparisonCoordinator().compare(
            inputs: inputs, assumptions: asmp,
            selectedApproach: .fillToBracket(rate: 0.24), heirWeight: 0)

        let s = MultiYearCPABriefing.approachDeltaSummary(cmp)
        // B2 fix: the CPA delta is present-value (what the anchor's "Minimize lifetime tax"
        // approach actually minimizes), not the nominal undiscounted sum. See ComparisonDisplayTests.
        #expect(s.deltaLifetimeTax == cmp.selected.lifetimeTaxPV - cmp.recommended.lifetimeTaxPV)
        #expect(s.deltaPeakConversion == cmp.selected.peakAnnualRothConversion - cmp.recommended.peakAnnualRothConversion)
    }

    @Test("Approach delta summary is all zero when the selected approach is the recommended plan")
    func cpaBriefingApproachDeltaZeroWhenCollapsed() {
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let cmp = ApproachComparisonCoordinator().compare(
            inputs: inputs, assumptions: asmp,
            selectedApproach: .recommendedTaxMin, heirWeight: 0)
        let s = MultiYearCPABriefing.approachDeltaSummary(cmp)
        #expect(s.deltaLifetimeTax == 0)
        #expect(s.deltaPeakConversion == 0)
        #expect(s.deltaMedicareCost == 0)
    }
}

extension ApproachComparisonTests {
    /// Regression for the Phase 2b coordinator bug: `ApproachComparisonCoordinator.compare(...)`
    /// built `ConsequenceFlags` without threading `inputs.acaHouseholdSize`, so it silently used
    /// the `householdSize: Int = 1` default. Household size 1 has the LOWEST FPL and therefore
    /// the lowest 400%-FPL cliff MAGI, so an MFJ household (size 2) sitting between the size-1
    /// and size-2 cliffs got a false-positive `acaCliffCrossed`. This constructs the exact band
    /// using the live config's real FPL/cliff numbers (no fabricated tax figures) and checks the
    /// flag both ways: false at the real household size 2, true at the old buggy default of 1 —
    /// proving the band itself is a genuine false positive, not just a threshold nudge.
    @Test("ACA cliff flag is household-size aware: MFJ between the size-1 and size-2 cliffs is NOT flagged")
    func acaCliffFlagRespectsHouseholdSize() {
        let configProvider = TaxYearConfigProvider.current
        let year = Calendar.current.component(.year, from: Date())
        let config = configProvider.config(forYear: year)
        let acaConfig = config.acaSubsidy2026
        let fpl = acaConfig.fpl2026.householdSizeToFPL
        let cliffFplPercent = acaConfig.applicableFigures.first { $0.applicableFigure >= 1.0 }!.fplPercent
        let size1Cliff = fpl["1"]! * cliffFplPercent / 100
        let size2Cliff = fpl["2"]! * cliffFplPercent / 100
        #expect(size2Cliff > size1Cliff)   // sanity: size-2 FPL (and cliff) is higher than size-1

        let baselineMagi = size1Cliff - 5_000               // under both cliffs
        let selectedMagi = (size1Cliff + size2Cliff) / 2    // over the size-1 cliff, under size-2

        func makeYear(magi: Double) -> YearRecommendation {
            YearRecommendation(year: year, agi: magi, acaMagi: magi, irmaaMagi: nil,
                               taxableIncome: magi, taxBreakdown: .zero,
                               endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
                               actions: [])
        }
        let baseline = [makeYear(magi: baselineMagi)]
        let selected = [makeYear(magi: selectedMagi)]

        // Real household size (2, MFJ): the household is genuinely still under its cliff.
        let atRealHouseholdSize = ConsequenceFlags(selected: selected, noConversion: baseline,
                                                    filingStatus: .marriedFilingJointly,
                                                    configProvider: configProvider, householdSize: 2)
        #expect(!atRealHouseholdSize.acaCliffCrossed)

        // Old buggy default (1): the same MAGIs false-positive because size-1's cliff is lower.
        let atDefaultHouseholdSize = ConsequenceFlags(selected: selected, noConversion: baseline,
                                                       filingStatus: .marriedFilingJointly,
                                                       configProvider: configProvider)
        #expect(atDefaultHouseholdSize.acaCliffCrossed)
    }

    @Test("ApproachComparisonCoordinator threads the household's real ACA household size into ConsequenceFlags")
    func coordinatorThreadsRealHouseholdSize() {
        // A married couple enrolled in ACA coverage pre-Medicare, household size 2. Regardless of
        // the specific dollar amounts this run produces, the coordinator must build ConsequenceFlags
        // using inputs.acaHouseholdSize, not the ConsequenceFlags default of 1.
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 900_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 60,
            spouseCurrentAge: 58,
            filingStatus: .marriedFilingJointly,
            state: "CA",
            primarySSClaimAge: 67,
            spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: 0,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 60,
            spouseBirthYear: Calendar.current.component(.year, from: Date()) - 58,
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: 0,
            spousePensionIncome: 0,
            acaEnrolled: true,
            acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 60_000
        )
        let asmp = ApproachComparisonTests.makeAssumptions()

        let cmp = ApproachComparisonCoordinator().compare(
            inputs: inputs, assumptions: asmp,
            selectedApproach: .fillToBracket(rate: 0.24), heirWeight: 0)

        // Recompute flags directly at both household sizes on the SAME paths the coordinator
        // produced, to confirm which one the coordinator's flags actually match.
        let expectedAtRealSize = ConsequenceFlags(selected: cmp.selected.path, noConversion: cmp.noAdditionalConversions.path,
                                                   filingStatus: inputs.filingStatus, configProvider: .current,
                                                   householdSize: inputs.acaHouseholdSize)
        #expect(cmp.flags == expectedAtRealSize)
    }
}
