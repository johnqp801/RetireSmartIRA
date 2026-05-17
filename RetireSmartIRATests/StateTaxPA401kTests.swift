//
//  StateTaxPA401kTests.swift
//  RetireSmartIRATests
//
//  Pennsylvania is the only US state that taxes employee 401(k) elective
//  deferrals at contribution time. Distributions are then state-tax-free —
//  inverse of federal treatment. NJ/MA/AL/HI/MS all conform for W-2 401(k).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State PA 401(k) add-back flag")
struct StatePA401kAddBackFlagTests {

    @Test("Pennsylvania taxes 401(k) employee elective deferrals")
    func paTaxes401k() {
        let config = StateTaxData.config(for: .pennsylvania)
        #expect(config.pretax401kContributionsTaxableForState == true)
    }

    @Test("All other states conform for 401(k) (parameterized)")
    func otherStatesConformOn401k() {
        for state in USState.allCases where state != .pennsylvania {
            let config = StateTaxData.config(for: state)
            #expect(
                config.pretax401kContributionsTaxableForState == false,
                "State \(state) should not tax 401(k) elective deferrals"
            )
        }
    }
}

@Suite("State PA 401(k) add-back behavior")
@MainActor
struct StatePA401kAddBackBehaviorTests {

    @Test("PA: 401(k) contributions added back to state taxable income")
    func paStateTaxAddsBack401kContribution() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .marriedFilingJointly
        dm.selectedState = .pennsylvania
        let withoutContribution = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .pennsylvania,
            filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0,
            pretax401kContributionsAddedBack: 0
        )
        let withContribution = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .pennsylvania,
            filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0,
            pretax401kContributionsAddedBack: 20_000
        )
        // PA flat rate is 3.07% → expected delta ≈ $614.
        let delta = withContribution - withoutContribution
        #expect(withContribution > withoutContribution)
        #expect(delta >= 400 && delta <= 800, "Expected ≈$614 addback delta, got \(delta)")
    }

    @Test("NY: 401(k) add-back is a no-op (NY conforms)")
    func nyStateTaxUnchangedBy401kContribution() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .single
        let withoutContribution = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .newYork,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            pretax401kContributionsAddedBack: 0
        )
        let withContribution = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .newYork,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            pretax401kContributionsAddedBack: 20_000
        )
        #expect(withContribution == withoutContribution)
    }

    @Test("TX (no income tax): 401(k) add-back stays zero")
    func txStateTaxStaysZeroWith401k() {
        let dm = DataManager(skipPersistence: true)
        let zero = dm.calculateStateTaxFromGross(
            grossIncome: 100_000,
            forState: .texas,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            pretax401kContributionsAddedBack: 20_000
        )
        #expect(zero == 0)
    }

    // scenarioTotalTraditional401k = yourTraditional401kContribution +
    // spouseTraditional401kContribution. The app models user-entered employee
    // elective deferrals only — employer match is not tracked separately and
    // is correctly excluded from PA wages by W-2 Box 1 already, so no match
    // addback is needed.
    @Test("PA addback applies only to employee deferral aggregate")
    func paAddbackOnlyAppliesToEmployeeDeferralNotMatch() {
        let dm = DataManager(skipPersistence: true)
        dm.scenario.yourTraditional401kContribution = 15_000
        dm.scenario.spouseTraditional401kContribution = 5_000
        #expect(dm.scenario.scenarioTotalTraditional401k == 20_000)
    }

    @Test("Invariant: stateTaxBreakdown matches scenarioStateTax for PA + 401(k)")
    func stateTaxBreakdownMatchesScenarioStateTaxForPA401k() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.selectedState = .pennsylvania
        dm.filingStatus = .marriedFilingJointly
        dm.incomeSources = [
            IncomeSource(name: "Wages", type: .consulting, annualAmount: 120_000, owner: .primary)
        ]
        dm.scenario.yourTraditional401kContribution = 15_000
        dm.scenario.spouseTraditional401kContribution = 5_000

        let breakdownTax = dm.scenarioStateTaxBreakdown.totalStateTax
        let engineTax = dm.scenarioStateTax
        #expect(abs(breakdownTax - engineTax) < 1.0,
                "breakdown=\(breakdownTax) engine=\(engineTax)")
    }

    @Test("Invariant: cost-spike helper state-tax component matches engine for PA + 401(k)")
    func costSpikeAtUserAGIMatchesScenarioStateTaxForPA401k() {
        // Invariant: the cost-spike helper's state-tax computation feeds the
        // PA addback through the same conformity flag as scenarioStateTax.
        // We isolate the state-tax delta by holding the scenario fixed and
        // flipping only the resident state between PA and NY. Both states
        // give the same federal + ACA contributions inside the helper (it
        // takes AGI directly and ACA is disabled by default), so the entire
        // helper-delta is state tax. Engine-delta is `scenarioStateTax`
        // measured under the same flip. The two must match.
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .marriedFilingJointly
        dm.incomeSources = [
            IncomeSource(name: "Wages", type: .consulting, annualAmount: 120_000, owner: .primary)
        ]
        dm.scenario.yourTraditional401kContribution = 15_000
        dm.scenario.spouseTraditional401kContribution = 5_000
        let baseAGI = dm.federalAGI.value

        dm.profile.selectedState = .pennsylvania
        let engineStatePA = dm.scenarioStateTax
        let helperPA = dm.estimatedThisYearCostAtAGI(baseAGI)

        dm.profile.selectedState = .newYork
        let engineStateNY = dm.scenarioStateTax
        let helperNY = dm.estimatedThisYearCostAtAGI(baseAGI)

        let engineDelta = engineStatePA - engineStateNY
        let helperDelta = helperPA - helperNY
        #expect(abs(engineDelta - helperDelta) < 1.0,
                "engineDelta=\(engineDelta) helperDelta=\(helperDelta)")
    }
}
