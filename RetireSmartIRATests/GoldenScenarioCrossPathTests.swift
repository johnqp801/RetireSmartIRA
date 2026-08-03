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
/// Two divergences are already known. Both are fixed in Phase 5, not here,
/// because fixing them moves numbers.
///
/// 1. ProjectionEngine.computeStateTax omits `postExemptionDeduction`
///    (ProjectionEngine.swift:1622-1634), so NJ's per-filer personal exemptions
///    vanish in Multi-Year. Backlog I2. This is ONE of two components of the
///    gap `newJerseyCrossPathGapPinnedAsObserved` below records -- see that
///    test's doc comment for the full decomposition. It is not the only
///    component and is not even the larger one.
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

    /// Pins TODAY'S OBSERVED figures, not an inequality between them.
    ///
    /// An earlier version of this test asserted `abs(single - multi) >= 0.01`
    /// ("a divergence exists"). That is a tripwire that stays armed regardless
    /// of WHY the two numbers differ: it would pass identically if I2 were
    /// fixed, if the multi-year figure regressed to $50,000, or if any other
    /// unrelated change moved either side. It cannot fail for the right
    /// reason. Pinning the actual values closes that hole: this test now fails
    /// the moment EITHER side moves, for any reason, which is what a Phase 2
    /// "make every disagreement visible" test should do.
    ///
    /// The NJ fixture's `federalAGI` is set to $80,000, equal to
    /// `pensionIncome + iraWithdrawals`, matching the invariant Task 4
    /// established for PA/IL/MS (`federalAGI == pensionIncome +
    /// iraWithdrawals`). An earlier fixture set `federalAGI` to $95,000 while
    /// pension was $80,000; the single-year runner reads `federalAGI`
    /// directly but the multi-year runner derives its own AGI from
    /// `pensionIncome` alone (`ProjectionEngine.swift:680-690`) and never
    /// reads `federalAGI` at all, so that $15,000 mismatch was a FIXTURE
    /// AUTHORING ARTIFACT, not an engine divergence, and it dominated the
    /// gap: single-year moved from $42.00 to $252.00 (a $210.00 swing) purely
    /// because of the AGI it was handed, while the multi-year figure could not
    /// move at all, being blind to that field. With the fixture corrected, the
    /// two engine entry points genuinely receive the same income, and the full
    /// remaining gap decomposes into two real mechanisms, not three:
    ///
    ///   single-year (form-derived, NJ-1040 for AGI $80,000):        $42.00
    ///   + tax-funding cascade (structural, present even with I2
    ///     fixed -- see below):                                    +$129.89
    ///   + I2 (missing $2,000 NJ personal exemption inside the
    ///     cascade's own recomputation):                            +$28.51
    ///   = multi-year (observed):                                  $200.40
    ///
    /// The cascade term exists because this fixture's household has $0
    /// taxable-account balance and $0 living expenses (mirroring the rest of
    /// the Task 5 runner's setup), so it owes nonzero tax with no funding
    /// source on hand. `ProjectionEngine`'s Step 7 tax-funding cascade
    /// (`ProjectionEngine.swift:966-1150`, the `.fundedFromAccounts` default)
    /// responds by grossing up an ADDITIONAL traditional-account withdrawal to
    /// pay the household's combined federal + state bill, converging via a
    /// Picard/Aitken fixed point. That withdrawal is itself NJ-taxable
    /// ordinary income, so year 1's reported state tax already includes
    /// tax-on-the-tax-funding-withdrawal. The single-year runner is a static
    /// point calculation with no such mechanism and cannot replicate this by
    /// construction, so it is not just "I2 missing", it is a different KIND
    /// of calculation.
    ///
    /// Both terms were measured directly, not estimated. The $28.51 I2 term
    /// came from a temporary, fully reverted local experiment: patching
    /// `ProjectionEngine.computeStateTax` to also forward NJ's
    /// `postExemptionDeduction` (the Phase 5 fix) moved the multi-year figure
    /// from $200.40 to $171.89 for this fixture. `171.89 - 42.00 = 129.89` is
    /// the cascade term (what remains even with I2 fixed); `200.40 - 171.89 =
    /// 28.51` is I2's own contribution. The experiment never left this
    /// session: `git checkout -- RetireSmartIRA/ProjectionEngine.swift`
    /// restored the file and `git status`/`git diff` confirmed zero changes
    /// before anything was committed. Phase 2 changes no computed number in
    /// shipped code.
    ///
    /// Consequence for Phase 5: fixing I2 alone will move the multi-year
    /// figure from $200.40 to roughly $171.89, NOT to $42.00. The two figures
    /// pinned below will therefore both need to be re-measured (not
    /// hand-predicted) after that fix lands, and this test should keep
    /// failing on the multi-year side until the cascade term is also
    /// addressed or the fixture is changed to avoid triggering it (for
    /// example, giving the household enough taxable/spendable cash that
    /// `dW == 0`). A continued failure here after Phase 5's I2 fix is
    /// EXPECTED, not a sign the fix did not work.
    @Test("PINNED, New Jersey single-year vs multi-year: two components, I2 is the smaller one")
    func newJerseyCrossPathGapPinnedAsObserved() throws {
        let file = try GoldenScenario.load(abbreviation: "NJ")
        let scenario = try #require(file.scenarios.first)
        let single = GoldenScenarioSingleYearTests.singleYearStateTax(scenario, state: .newJersey)
        let multi = try #require(
            GoldenScenarioMultiYearTests.multiYearYearOneStateTax(scenario, abbreviation: "NJ"))

        // Form-derived. Must not move: if it does, either the fixture changed
        // or the single-year engine's NJ math changed, both of which are
        // Phase 5+ events that deserve a fresh look, not a quiet update here.
        #expect(abs(single - 42.0) < 0.01,
                """
                NJ single-year moved from the form-derived $42.00 to \(single).
                Re-derive from the NJ-1040 Tax Table before updating this pin.
                """)

        // Pinned AS OBSERVED, not as correct: this is today's multi-year
        // output for this household, tax-funding cascade and I2 both
        // included. See the doc comment above for the two-term decomposition.
        #expect(abs(multi - 200.40469973890345) < 0.01,
                """
                NJ multi-year moved from the observed $200.40469973890345 to \(multi).
                That means either I2 was fixed, the tax-funding cascade's sizing
                changed, or something else in the multi-year path moved. Diagnose
                which before updating this pin -- do not assume it was I2.
                """)
    }
}
