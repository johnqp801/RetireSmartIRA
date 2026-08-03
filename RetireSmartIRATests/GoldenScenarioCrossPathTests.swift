import Testing
import Foundation
@testable import RetireSmartIRA

/// Compares two ENGINE ENTRY POINTS, not two screens.
///
/// `GoldenScenarioSingleYearTests.singleYearStateTax` drives
/// `TaxCalculationEngine.calculateStateTax` the way `DataManager
/// .calculateStateTaxFromGross` does (`DataManager.swift:544-671`), including its
/// `postExemptionDeduction` forwarding. `GoldenScenarioMultiYearTests
/// .multiYearYearOneStateTax` drives `ProjectionEngine.project` with hand-pinned
/// year-1 lever actions. Neither runner is the real screen: the real Scenarios
/// screen is `DataManager.scenarioStateTax` and the real Multi-Year screen is
/// `MultiYearTaxStrategyEngine.compute` -> `OptimizationEngine.optimize`, which
/// per `OptimizationEngine.swift:410-416` never pins withdrawal amounts the way
/// this runner does. So this suite isolates the SHARED PRIMITIVE the two screens
/// both eventually call, not the screens themselves. A pass here says the two
/// engine entry points agree on a given household; it says nothing about whatever
/// the optimizer or the Scenarios UI layer might additionally do to that household
/// before or after calling in.
///
/// CAVEAT ON `agreeing` (PA/IL/MS): every scenario in those three fixtures
/// computes $0 state tax (the pension/IRA income is fully exempt in all three
/// states), so `pathsAgree` below currently verifies 0 == 0 for them. It has not
/// yet exercised agreement on a NONZERO tax bill, because Phase 2's pilot has no
/// PA/IL/MS fixture where tax is actually owed. NJ is the first (and, in this
/// phase, only) scenario with nonzero tax, and it does not agree -- see below.
///
/// Two divergences are already known and are pinned as expected failures, so
/// they stay visible and so a NEW divergence is distinguishable from them.
/// Both are fixed in Phase 5, not here, because fixing them moves numbers.
///
/// 1. ProjectionEngine.computeStateTax omits `postExemptionDeduction`
///    (ProjectionEngine.swift:1622-1634), so NJ's per-filer personal exemptions
///    vanish in Multi-Year. Backlog I2. Pinned by
///    `newJerseyPersonalExemptionDivergenceIsStillPresent` below -- but see that
///    test's doc comment: I2 is NOT the only thing that test is observing, and
///    fixing I2 in isolation will very likely NOT make it converge.
/// 2. `.rmd` IncomeSource rows are ungated while `scenarioRetirementDistributions`
///    is gated at 59.5 (TaxCalculationEngine.swift:582-585). Multi-year synthesizes
///    `.rmd` rows, so an under-59.5 household gets the IRA exemption in Multi-Year
///    and is denied it in Scenarios. No pilot fixture exercises this age band, so
///    it is not independently pinned by a test here; it remains recorded in the
///    Phase 2 plan / backlog only.
@Suite("Golden scenarios, cross-path agreement")
struct GoldenScenarioCrossPathTests {

    /// States where the two engine entry points are expected to agree today.
    /// Read the CAVEAT above the suite before treating a pass here as strong
    /// evidence: all three currently agree on $0, not on a nonzero figure.
    static let agreeing = ["PA", "IL", "MS"]

    @Test("Both engine entry points report the same state tax",
          arguments: GoldenScenarioCrossPathTests.agreeing)
    func pathsAgree(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        let state = try #require(USState.allCases.first { $0.abbreviation == abbreviation })
        for scenario in file.scenarios {
            let single = GoldenScenarioSingleYearTests.singleYearStateTax(scenario, state: state)
            let multi = try #require(
                GoldenScenarioMultiYearTests.multiYearYearOneStateTax(scenario,
                                                                     abbreviation: abbreviation))
            #expect(abs(single - multi) < 0.01,
                    """
                    \(abbreviation) / \(scenario.name): single-year engine call \(single), \
                    multi-year engine call \(multi).
                    Same household, two engine entry points, different tax. If this is a NEW
                    divergence, it is a finding: report the mechanism, do not adjust either number.
                    """)
        }
    }

    /// Pinned as PRESENT, not as correct, and NOT as a clean measurement of I2's
    /// isolated effect.
    ///
    /// This fixture's household has $0 taxable-account balance and $0 living
    /// expenses (mirroring the rest of the Task 5 runner's setup), so it owes
    /// nonzero tax with no funding source on hand. `ProjectionEngine`'s Step 7
    /// tax-funding cascade (`ProjectionEngine.swift:966-1150`, the
    /// `.fundedFromAccounts` default) responds by grossing up an ADDITIONAL
    /// traditional-account withdrawal to pay the household's combined federal +
    /// state bill, converging via a Picard/Aitken fixed point. That withdrawal is
    /// itself NJ-taxable ordinary income, so year 1's reported state tax already
    /// includes tax-on-the-tax-funding-withdrawal. The single-year runner has no
    /// such mechanism at all: it is a static point calculation with no funding
    /// step, so it cannot replicate this even in principle.
    ///
    /// Verified by a temporary, reverted experiment (not part of this commit):
    /// forwarding NJ's `postExemptionDeduction` inside `ProjectionEngine
    /// .computeStateTax`, mirroring the Phase 5 fix, moved the multi-year figure
    /// from $200.40 to $171.89 for this fixture -- still $80.11 away from the
    /// single-year figure of $252.00, i.e. FURTHER apart in the direction I2
    /// alone would not predict, not closer. So:
    ///
    ///   - The current gap ($200.40 vs $252.00, $51.60) is I2 and the
    ///     tax-funding cascade CONFOUNDED together, not I2 alone. Do not read
    ///     $51.60 (or $28.00 = $2,000 x 1.4%) as "the cost of I2".
    ///   - When Phase 5 fixes I2, this test will almost certainly KEEP PASSING
    ///     (the two figures will still disagree), for a reason unrelated to I2.
    ///     Do not take a continued pass after that fix as evidence I2 is still
    ///     present, and do not delete this test on that basis alone -- diagnose
    ///     which mechanism is firing before touching it.
    ///   - A clean, single-variable measurement of I2 needs a multi-year fixture
    ///     with enough taxable/spendable cash that the funding cascade never
    ///     fires (so `dW == 0`), which no fixture in this pilot provides.
    @Test("KNOWN DIVERGENCE, backlog I2: New Jersey personal exemptions vanish in Multi-Year")
    func newJerseyPersonalExemptionDivergenceIsStillPresent() throws {
        let file = try GoldenScenario.load(abbreviation: "NJ")
        let scenario = try #require(file.scenarios.first)
        let single = GoldenScenarioSingleYearTests.singleYearStateTax(scenario, state: .newJersey)
        let multi = try #require(
            GoldenScenarioMultiYearTests.multiYearYearOneStateTax(scenario, abbreviation: "NJ"))

        #expect(abs(single - multi) >= 0.01,
                """
                NJ single-year \(single) and multi-year \(multi) now agree.
                That would mean BOTH I2 was fixed AND the tax-funding cascade
                stopped mattering for this fixture. Read this test's doc comment
                before deleting it: diagnose which changed, do not assume I2 alone.
                """)
    }
}
