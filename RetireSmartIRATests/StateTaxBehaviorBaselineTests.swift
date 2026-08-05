import Testing
import Foundation
@testable import RetireSmartIRA

/// PHASE 3a GATE: today's computed state tax equals yesterday's.
///
/// The Phase 1 gate compares the JSON-loaded config against the legacy Swift
/// config. Phase 3a edits BOTH, so they move together and that gate stays
/// green even if every number in the app changes. It is structurally blind to
/// a Phase 3a regression.
///
/// This suite closes that. The expected values were captured from `main`
/// @ e540e9f BEFORE any Phase 3a model change and are checked in as literal
/// data. Every new field added in this phase must default to reproducing
/// them exactly.
///
/// IF THIS SUITE FAILS, THE CHANGE THAT BROKE IT IS THE DEFECT. Do not
/// regenerate the fixture to make it pass. Regeneration is legitimate only in
/// Phase 5, where each moved value is attributable to a named golden scenario
/// citing a state's own published form.
struct BaselineScenario {
    let name: String
    let income: Double
    let filingStatus: FilingStatus
    let taxableSocialSecurity: Double
    let retirementDistributions: Double
    let rothConversion: Double
    let rothConversionWithholding: Double
    let primaryAge: Int
    let spouseAge: Int
    let enableSpouse: Bool
    let postExemptionDeduction: Double
    let pensionIncome: Double
    let rmdRowIncome: Double
}

@Suite("PHASE 3a GATE: state tax behavior baseline")
struct StateTaxBehaviorBaselineTests {

    static let scenarios: [BaselineScenario] = [
        // Ages below, at, and above the hardcoded 59 distribution gate that
        // Task 2 makes configurable. 55 is the age Iowa will use in Phase 5.
        .init(name: "single 55, distributions only", income: 60_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 40_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 55, spouseAge: 55, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        .init(name: "single 58, distributions only", income: 60_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 40_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 58, spouseAge: 58, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        .init(name: "single 59, distributions only", income: 60_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 40_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 59, spouseAge: 59, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        // The `||` household gate: primary below, spouse above. Task 5 makes
        // this attribution configurable and MUST leave this value unmoved.
        .init(name: "MFJ 57 with spouse 61", income: 120_000, filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 50_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 57, spouseAge: 61, enableSpouse: true,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        .init(name: "MFJ 61 with spouse 56", income: 120_000, filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 50_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 61, spouseAge: 56, enableSpouse: true,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        // BOTH spouses below the distribution gate, the only combination in
        // which the household `||` is observed evaluating FALSE with a spouse
        // enabled. Without it, a default branch that degraded to
        // `primaryAge >= minAge || enableSpouse` would move none of the
        // baseline's values.
        .init(name: "MFJ 56 with spouse 55, both below the gate", income: 120_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 50_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 56, spouseAge: 55, enableSpouse: true,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        // Both spouses qualify: exercises exemptionAppliesPerIndividual doubling (NY, GA).
        .init(name: "MFJ 68 both qualify, pension + IRA", income: 140_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 24_000, retirementDistributions: 40_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 68, spouseAge: 67, enableSpouse: true,
              postExemptionDeduction: 2_000, pensionIncome: 60_000, rmdRowIncome: 0),
        // MFJ filing status with NO spouse enabled. This pins the combination
        // of married brackets, isMarried, and effectiveAge = primaryAge inside
        // calculateStateTax. It does NOT guard personal-exemption logic:
        // calculateStateTax never computes that, it receives the already
        // computed figure as postExemptionDeduction, passed here as a literal.
        // The guard for that logic is NJOtherExclusionAndExemptionsTests,
        // which calls njPersonalExemptions directly.
        .init(name: "MFJ status but spouse disabled, 66", income: 95_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 66, spouseAge: 66, enableSpouse: false,
              postExemptionDeduction: 1_000, pensionIncome: 80_000, rmdRowIncome: 0),
        // NJ stepped phase-out bands: below 100k, inside 100k-125k, inside
        // 125k-150k, and over the cliff. Task 4 adds a phase-out mechanism that
        // must not disturb any of them.
        .init(name: "single 65 pension, total 95k", income: 95_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 65, spouseAge: 65, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 80_000, rmdRowIncome: 0),
        // NJ tier 2 (100k to 125k), SINGLE column. Without a single filer in
        // this band, NJ's singlePercent of 0.375 multiplies nothing.
        .init(name: "single 68 pension, total 120k", income: 120_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 68, spouseAge: 68, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 100_000, rmdRowIncome: 0),
        // NJ tier 3 (125k to 150k), SINGLE column, covering singlePercent 0.1875.
        .init(name: "single 68 pension, total 140k", income: 140_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 68, spouseAge: 68, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 110_000, rmdRowIncome: 0),
        .init(name: "MFJ 68 pension, total 120k", income: 120_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 68, spouseAge: 68, enableSpouse: true,
              postExemptionDeduction: 2_000, pensionIncome: 110_000, rmdRowIncome: 0),
        .init(name: "MFJ 68 pension, total 140k", income: 140_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 68, spouseAge: 68, enableSpouse: true,
              postExemptionDeduction: 2_000, pensionIncome: 110_000, rmdRowIncome: 0),
        .init(name: "MFJ 68 pension, total 200k over the cliff", income: 200_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 68, spouseAge: 68, enableSpouse: true,
              postExemptionDeduction: 2_000, pensionIncome: 110_000, rmdRowIncome: 0),
        // Roth conversion with and without withholding: PA exempts only the net
        // deposited amount, IL and MS exempt the gross. Task 6 moves this rule
        // into config and must preserve BOTH behaviors.
        .init(name: "single 62 conversion 100k no withholding", income: 160_000,
              filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 20_000, rothConversion: 100_000,
              rothConversionWithholding: 0, primaryAge: 62, spouseAge: 62, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        .init(name: "single 62 conversion 100k with 22k withheld", income: 160_000,
              filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 20_000, rothConversion: 100_000,
              rothConversionWithholding: 22_000, primaryAge: 62, spouseAge: 62, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        // A conversion BELOW the distribution age gate. The conversion exemption
        // is not age-gated today; the distributions alongside it are.
        .init(name: "single 54 conversion 80k", income: 140_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 30_000, rothConversion: 80_000,
              rothConversionWithholding: 0, primaryAge: 54, spouseAge: 54, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        // `.rmd`-typed IncomeSource rows, which are UNGATED by age today while
        // scenarioRetirementDistributions is gated at 59. This is the cross-path
        // divergence Phase 2 found. Pinned here so Task 2 cannot quietly close it.
        .init(name: "single 55 rmd rows not scenario distributions", income: 60_000,
              filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 55, spouseAge: 55, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 40_000),
        // Age-tier boundary: GA's 62-64 early tier versus its 65+ regular tier.
        .init(name: "single 63 in the early age tier", income: 90_000, filingStatus: .single,
              taxableSocialSecurity: 18_000, retirementDistributions: 40_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 63, spouseAge: 63, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        .init(name: "zero income", income: 0, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 65, spouseAge: 65, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0)
    ]

    static func key(_ state: USState, _ scenario: BaselineScenario) -> String {
        "\(state.abbreviation)|\(scenario.name)"
    }

    static func computedTax(state: USState, scenario: BaselineScenario) -> Double {
        var sources: [IncomeSource] = []
        if scenario.pensionIncome > 0 {
            sources.append(IncomeSource(name: "Pension", type: .pension,
                                        annualAmount: scenario.pensionIncome))
        }
        if scenario.rmdRowIncome > 0 {
            sources.append(IncomeSource(name: "RMD", type: .rmd,
                                        annualAmount: scenario.rmdRowIncome))
        }
        return TaxCalculationEngine.calculateStateTax(
            income: scenario.income,
            forState: state,
            filingStatus: scenario.filingStatus,
            taxableSocialSecurity: scenario.taxableSocialSecurity,
            incomeSources: sources,
            currentAge: scenario.primaryAge,
            enableSpouse: scenario.enableSpouse,
            spouseBirthYear: 2026 - scenario.spouseAge,
            currentYear: 2026,
            scenarioRetirementDistributions: scenario.retirementDistributions,
            scenarioRothConversionAmount: scenario.rothConversion,
            scenarioRothConversionWithholdingAmount: scenario.rothConversionWithholding,
            postExemptionDeduction: scenario.postExemptionDeduction,
            localIncomeTaxRate: 0
        )
    }

    static func loadBaseline() throws -> [String: Double] {
        let url = try #require(
            Bundle(for: BehaviorBaselineMarker.self).url(
                forResource: "statetax-behavior-baseline-2026", withExtension: "json"),
            "baseline fixture is not bundled")
        return try JSONDecoder().decode([String: Double].self, from: Data(contentsOf: url))
    }

    @Test("Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline",
          arguments: USState.allCases)
    func matchesFrozenBaseline(state: USState) throws {
        let baseline = try Self.loadBaseline()
        #expect(baseline.count == USState.allCases.count * Self.scenarios.count,
                """
                Baseline holds \(baseline.count) entries for \(USState.allCases.count) \
                jurisdictions x \(Self.scenarios.count) scenarios. A mismatch means the \
                scenario grid was narrowed or widened without regenerating. Narrowing the \
                grid to make a red gate green is not a fix.
                """)
        // The count comparison above cannot catch a scenario deleted AND the
        // fixture regenerated, because both of its operands move together. This
        // literal does not move on its own, so that path fails here instead.
        // Adding a legitimate scenario means bumping this number, which is the
        // deliberate act the gate wants; quietly dropping one is not.
        #expect(Self.scenarios.count == 20,
                """
                The scenario grid changed size. If that was intended, bump this literal \
                in the same commit as the regenerated fixture and say why.
                """)
        let movements = try BaselineMovementLedger.movements()
        for scenario in Self.scenarios {
            let k = Self.key(state, scenario)
            let frozen = try #require(baseline[k], "no baseline entry for \(k)")
            let actual = Self.computedTax(state: state, scenario: scenario)

            if let moved = movements[k] {
                // A DELIBERATE, ATTRIBUTED movement. The frozen file is never
                // edited; this record carries the new value and its authority.
                #expect(moved.before == frozen,
                        """
                        \(k): the movement ledger records a `before` of \(moved.before) \
                        but the frozen baseline holds \(frozen). The ledger is describing \
                        a starting point that never existed. Fix the ledger, never the \
                        frozen file.
                        """)
                #expect(actual == moved.after,
                        """
                        \(k): computed \(actual), ledger records \(moved.after).
                        This value is under deliberate correction and has moved AGAIN, \
                        or moved to somewhere other than recorded. Diagnose which before \
                        touching either file.
                        Golden case: \(moved.goldenCase)
                        """)
            } else {
                #expect(
                    actual == frozen,
                    """
                    \(k): computed \(actual), baseline \(frozen).
                    This value moved with NO entry in the movement ledger, so nothing \
                    authorises it. Either the change that moved it is a defect, or it is \
                    a real correction that must be recorded in \
                    statetax-behavior-movements-2026.json naming the golden case behind it. \
                    Do NOT regenerate the frozen baseline.
                    """
                )
            }
        }
    }
}

/// Writes the frozen baseline. Run ONCE, from `main` before any Phase 3a
/// model change, and never again in this phase. See
/// StateTaxDataGeneratorTests.swift for why the env var needs the
/// TEST_RUNNER_ prefix and why ENABLE_APP_SANDBOX=NO is required.
///
///     TEST_RUNNER_STATE_TAX_BASELINE=1 xcodebuild test -scheme RetireSmartIRA \
///         -destination 'platform=macOS' \
///         -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineGeneratorTests \
///         ENABLE_APP_SANDBOX=NO
@Suite("State tax behavior baseline generator (manual)")
struct StateTaxBehaviorBaselineGeneratorTests {

    @Test("Generate the frozen behavior baseline",
          .enabled(if: ProcessInfo.processInfo.environment["STATE_TAX_BASELINE"] == "1"))
    func generate() throws {
        var baseline: [String: Double] = [:]
        for state in USState.allCases {
            for scenario in StateTaxBehaviorBaselineTests.scenarios {
                baseline[StateTaxBehaviorBaselineTests.key(state, scenario)] =
                    StateTaxBehaviorBaselineTests.computedTax(state: state, scenario: scenario)
            }
        }
        #expect(baseline.count == USState.allCases.count
                * StateTaxBehaviorBaselineTests.scenarios.count)

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let outDir = repoRoot.appendingPathComponent("RetireSmartIRATests/Baselines")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(baseline).write(
            to: outDir.appendingPathComponent("statetax-behavior-baseline-2026.json"))
    }
}

private final class BehaviorBaselineMarker {}
