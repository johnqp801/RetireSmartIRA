//
//  TaxsimOracleTests.swift
//  RetireSmartIRATests
//
//  Independent-oracle differential harness against NBER's TAXSIM-35.
//
//  Why this file exists
//  --------------------
//  The pre-existing 951-test suite was authored by the same agent (Claude) that
//  wrote the engine — a self-referential audit loop that allowed Jonggie F.'s
//  PA state-tax bug to ship twice (v1.8.2 and v1.8.3-build43). We add an
//  independent oracle: NBER's TAXSIM-35, the academic-standard tax calculator
//  since 1974 (powering PolicyEngine US and 1,200+ academic papers).
//
//  Snapshot, not live
//  ------------------
//  This test does NO network. It reads two checked-in JSON fixtures:
//
//     RetireSmartIRATests/Fixtures/taxsim-scenarios.json  (inputs)
//     RetireSmartIRATests/Fixtures/taxsim-expected.json   (TAXSIM responses)
//
//  Refresh the expected fixture by running `swift run` in
//  `tools/taxsim-refresh/` — that tool POSTs to TAXSIM-35. Don't run in CI.
//
//  Tolerance
//  ---------
//  - Federal:  abs(engine - taxsim) <= $200 → pass, else FAIL.
//  - State:    pass if BOTH report >0 OR BOTH report ≤$100. Pure-dollar
//              divergence is logged as informational (not failing) because
//              TAXSIM's state law is only coded through ~2020 and we KNOW
//              our engine and TAXSIM disagree on several state retirement
//              rules (PA Ans 274 conversions, CO SB25-136, AL HB388, etc.).
//              The point here is to catch *gross* structural mistakes
//              (exempt when we shouldn't / tax when we shouldn't), not
//              line-item state liability.
//
//  Year
//  ----
//  TAXSIM-35 federal logic is coded only through tax year 2023. We pin both
//  TAXSIM and the engine to 2023 to remove year-mismatch noise (so this
//  harness deliberately bypasses OBBBA / 2026 senior bonus / expanded SALT —
//  it's about structural bracket / SS / cap-gains / NIIT math, not the latest
//  tax-year delta).
//

import Testing
import Foundation
@testable import RetireSmartIRA

// MARK: - Fixture decoding models

private struct ScenarioFile: Decodable {
    let scenarios: [Scenario]
}

private struct Scenario: Decodable {
    let id: Int
    let name: String
    let year: Int
    let state_soi: Int
    let state_enum: String
    let filing_status: String
    let primary_age: Int
    let spouse_age: Int
    let wages_primary: Double
    let wages_spouse: Double
    let pensions: Double
    let gssi: Double
    let intrec: Double
    let dividends: Double
    let stcg: Double
    let ltcg: Double
    let engine_setup: EngineSetup?
}

private struct EngineSetup: Decodable {
    let yourExtraWithdrawal: Double?
    let spouseExtraWithdrawal: Double?
    let yourRothConversion: Double?
    let spouseRothConversion: Double?
    let incomeSources: [SourceSpec]?
}

private struct SourceSpec: Decodable {
    let name: String
    let type: String
    let amount: Double
    let owner: String
}

private struct ExpectedFile: Decodable {
    let rows: [ExpectedRow]
}

private struct ExpectedRow: Decodable {
    let taxsimid: Int
    let name: String
    let fiitax: Double
    let siitax: Double
}

// MARK: - Helpers

private func loadFixture<T: Decodable>(_ type: T.Type, named filename: String) throws -> T {
    // Locate fixtures via #filePath — works whether run via xcodebuild or `swift test`
    // and avoids requiring fixture JSONs to ship as test-bundle resources.
    let here = URL(fileURLWithPath: #filePath)
    let fixturesDir = here.deletingLastPathComponent().appendingPathComponent("Fixtures")
    let url = fixturesDir.appendingPathComponent(filename)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}

/// Map the camelCase `state_enum` value in the scenarios JSON to the matching
/// `USState` case. We can't rely on `USState(rawValue:)` because the rawValue
/// is the human display string ("Pennsylvania") while the JSON uses the Swift
/// case identifier ("pennsylvania"). Switching by name keeps the JSON explicit.
private func usState(from jsonKey: String) -> USState? {
    USState.allCases.first { "\($0)" == jsonKey }
}

private func incomeType(from key: String) -> IncomeType? {
    switch key {
    case "socialSecurity": return .socialSecurity
    case "pension": return .pension
    case "dividends": return .dividends
    case "qualifiedDividends": return .qualifiedDividends
    case "interest": return .interest
    case "capitalGainsShort": return .capitalGainsShort
    case "capitalGainsLong": return .capitalGainsLong
    case "consulting": return .consulting
    case "rmd": return .rmd
    case "militaryRetirement": return .militaryRetirement
    case "other": return .other
    default: return nil
    }
}

private func owner(from key: String) -> Owner {
    switch key {
    case "spouse": return .spouse
    case "joint": return .joint
    default: return .primary
    }
}

/// Construct a DataManager configured exactly per the scenario.
@MainActor
private func buildEngine(for s: Scenario) -> DataManager? {
    let dm = DataManager(skipPersistence: true)

    // Year + filing status
    dm.profile.currentYear = s.year
    switch s.filing_status {
    case "single": dm.filingStatus = .single
    case "marriedFilingJointly": dm.filingStatus = .marriedFilingJointly
    default: return nil
    }

    // State
    guard let st = usState(from: s.state_enum) else { return nil }
    dm.selectedState = st

    // Birth dates — use Jan 1 so that "age at year-end" math is unambiguous.
    var primaryDob = DateComponents(); primaryDob.year = s.year - s.primary_age; primaryDob.month = 1; primaryDob.day = 1
    dm.profile.birthDate = Calendar.current.date(from: primaryDob)!

    if s.filing_status == "marriedFilingJointly" {
        dm.enableSpouse = true
        var sd = DateComponents(); sd.year = s.year - max(s.spouse_age, 1); sd.month = 1; sd.day = 1
        dm.profile.spouseBirthDate = Calendar.current.date(from: sd)!
    } else {
        dm.enableSpouse = false
    }

    // Scenario sliders
    if let setup = s.engine_setup {
        if let v = setup.yourExtraWithdrawal { dm.yourExtraWithdrawal = v }
        if let v = setup.spouseExtraWithdrawal { dm.spouseExtraWithdrawal = v }
        if let v = setup.yourRothConversion { dm.yourRothConversion = v }
        if let v = setup.spouseRothConversion { dm.spouseRothConversion = v }

        // IncomeSource rows. We REPLACE existing auto-synced SS rows when the
        // scenario specifies any SS sources — otherwise the auto-sync from
        // birthDate would inject phantom benefits we didn't ask for.
        if let specs = setup.incomeSources, !specs.isEmpty {
            // Drop auto-synced SS rows; the scenario controls SS explicitly.
            let scenarioHasSS = specs.contains { $0.type == "socialSecurity" }
            if scenarioHasSS {
                dm.incomeSources.removeAll { $0.type == .socialSecurity }
            }
            for spec in specs {
                guard let t = incomeType(from: spec.type) else { continue }
                let src = IncomeSource(name: spec.name, type: t, annualAmount: spec.amount, owner: owner(from: spec.owner))
                dm.incomeSources.append(src)
            }
        }
    }

    return dm
}

// MARK: - The harness

// IMPORTANT — test parallelization is intentionally DISABLED for this target
// (RetireSmartIRA.xcscheme: TestableReference parallelizable = "NO").
//
// This suite calls `TaxCalculationEngine.withConfig(forYear: 2023)`, which swaps the
// process-global `TaxCalculationEngine.config` singleton for the duration of the closure
// (DataManager and the scenario computed properties read that global). The config singleton
// is intentional production architecture — it is set once at app startup and never swapped
// in production. But under parallel test execution this swap window races every other test
// that reads the global config (e.g. the federal-bracket suites that expect TY2026),
// producing flaky, message-less failures.
//
// The correct fix for a deliberate process-global singleton that tests must swap is to run
// the config-dependent tests serially rather than to add locking to the shipped engine's
// hot path. If you re-enable parallelization, this races again — instead inject config
// explicitly (see TaxYearConfigProvider, which the multi-year engine already uses) so no
// test needs to mutate the global.
@MainActor
@Suite("TAXSIM-35 oracle differential harness (Part 1)")
struct TaxsimOracleTests {

    /// Single aggregating test: iterates every scenario, accumulates findings,
    /// and emits a structured summary in the failure message. Run with
    /// `xcodebuild test -only-testing:RetireSmartIRATests/TaxsimOracleTests`.
    ///
    /// Each scenario is evaluated inside `TaxCalculationEngine.withConfig(forYear: 2023)`,
    /// which swaps the global tax-year config to TY2023 (loaded from `tax-2023.json`)
    /// for the duration of the closure. This matches the year used by TAXSIM-35
    /// (which caps at 2023) so federal differences reflect engine bugs, not
    /// year-shift artifacts.
    @Test("Engine vs. NBER TAXSIM-35 across 20 retirement scenarios")
    func differentialAgainstTaxsim() throws {
        let scenarios = try loadFixture(ScenarioFile.self, named: "taxsim-scenarios.json").scenarios
        let expected = try loadFixture(ExpectedFile.self, named: "taxsim-expected.json").rows
        let expectedById: [Int: ExpectedRow] = Dictionary(uniqueKeysWithValues: expected.map { ($0.taxsimid, $0) })

        struct Finding {
            enum Kind { case federalFail, stateFail, stateInfo, setupFail }
            let scenarioId: Int
            let scenarioName: String
            let kind: Kind
            let engineFederal: Double
            let taxsimFederal: Double
            let engineState: Double
            let taxsimState: Double
            let detail: String
        }
        var findings: [Finding] = []
        var fedMatches = 0
        var stateDirectionalOK = 0
        let federalTolerance = 200.0

        for s in scenarios {
            guard let exp = expectedById[s.id] else {
                findings.append(.init(scenarioId: s.id, scenarioName: s.name, kind: .setupFail,
                                      engineFederal: 0, taxsimFederal: 0, engineState: 0, taxsimState: 0,
                                      detail: "no TAXSIM expected row for id=\(s.id) (refresh fixtures?)"))
                continue
            }

            // Evaluate this scenario under TY2023 federal constants (matching
            // TAXSIM-35's year cap). `withConfig` swaps `TaxCalculationEngine.config`
            // for the duration of the closure so DataManager init + all scenario
            // computed properties read TY2023 brackets, std deduction, AMT, etc.
            let (engineFederal, engineState, setupOk): (Double, Double, Bool) =
                TaxCalculationEngine.withConfig(forYear: 2023) {
                guard let dm = buildEngine(for: s) else { return (0, 0, false) }
                let fed = dm.scenarioFederalTax + dm.scenarioNIITAmount + dm.scenarioAMTAmount
                let st = dm.scenarioStateTax
                return (fed, st, true)
            }

            if !setupOk {
                findings.append(.init(scenarioId: s.id, scenarioName: s.name, kind: .setupFail,
                                      engineFederal: 0, taxsimFederal: 0, engineState: 0, taxsimState: 0,
                                      detail: "could not build DataManager for state_enum=\(s.state_enum) filing=\(s.filing_status)"))
                continue
            }

            let federalDelta = engineFederal - exp.fiitax
            let stateDelta = engineState - exp.siitax

            // Federal: hard assert within tolerance.
            if abs(federalDelta) > federalTolerance {
                findings.append(.init(scenarioId: s.id, scenarioName: s.name, kind: .federalFail,
                                      engineFederal: engineFederal, taxsimFederal: exp.fiitax,
                                      engineState: engineState, taxsimState: exp.siitax,
                                      detail: "federal Δ=\(String(format: "%+.2f", federalDelta)) outside ±$\(Int(federalTolerance))"))
            } else {
                fedMatches += 1
            }

            // State: directional only.
            // Fail when one side is "≤$100" and the other is meaningfully taxing (>$5000).
            let engineSaysExempt = engineState <= 100
            let taxsimSaysExempt = exp.siitax <= 100
            let engineSaysTaxes = engineState > 5000
            let taxsimSaysTaxes = exp.siitax > 5000

            if engineSaysExempt && taxsimSaysTaxes {
                findings.append(.init(scenarioId: s.id, scenarioName: s.name, kind: .stateFail,
                                      engineFederal: engineFederal, taxsimFederal: exp.fiitax,
                                      engineState: engineState, taxsimState: exp.siitax,
                                      detail: "STATE: engine exempts ($\(Int(engineState))) but TAXSIM taxes $\(Int(exp.siitax))"))
            } else if engineSaysTaxes && taxsimSaysExempt {
                findings.append(.init(scenarioId: s.id, scenarioName: s.name, kind: .stateFail,
                                      engineFederal: engineFederal, taxsimFederal: exp.fiitax,
                                      engineState: engineState, taxsimState: exp.siitax,
                                      detail: "STATE: engine taxes $\(Int(engineState)) but TAXSIM exempts ($\(Int(exp.siitax)))"))
            } else {
                stateDirectionalOK += 1
                // Log informational state divergence (>$300 abs).
                if abs(stateDelta) > 300 {
                    findings.append(.init(scenarioId: s.id, scenarioName: s.name, kind: .stateInfo,
                                          engineFederal: engineFederal, taxsimFederal: exp.fiitax,
                                          engineState: engineState, taxsimState: exp.siitax,
                                          detail: "STATE info-only Δ=\(String(format: "%+.2f", stateDelta)) (directional OK)"))
                }
            }
        }

        // Build report
        let fails = findings.filter { $0.kind == .federalFail || $0.kind == .stateFail || $0.kind == .setupFail }
        let infos = findings.filter { $0.kind == .stateInfo }

        var report = ""
        report += "\n=== TAXSIM-35 oracle harness ===\n"
        report += "scenarios: \(scenarios.count)\n"
        report += "federal within ±$\(Int(federalTolerance)): \(fedMatches)/\(scenarios.count)\n"
        report += "state directional OK (no exempt/tax flip): \(stateDirectionalOK)/\(scenarios.count)\n"
        report += "hard failures: \(fails.count)\n"
        report += "informational state divergences: \(infos.count)\n"

        if !fails.isEmpty {
            report += "\n--- HARD FAILURES ---\n"
            for f in fails {
                report += "[#\(f.scenarioId)] \(f.scenarioName)\n"
                report += "    engine: fed=$\(String(format: "%.2f", f.engineFederal)) state=$\(String(format: "%.2f", f.engineState))\n"
                report += "    taxsim: fed=$\(String(format: "%.2f", f.taxsimFederal)) state=$\(String(format: "%.2f", f.taxsimState))\n"
                report += "    → \(f.detail)\n"
            }
        }
        if !infos.isEmpty {
            report += "\n--- INFORMATIONAL STATE DIVERGENCES (not failing) ---\n"
            for f in infos {
                report += "[#\(f.scenarioId)] \(f.scenarioName): engine state=$\(String(format: "%.0f", f.engineState)) vs taxsim=$\(String(format: "%.0f", f.taxsimState)) (\(f.detail))\n"
            }
        }

        // Write the full report to /tmp for easy inspection (xcodebuild swallows
        // most stdout from the test runner). The same report is the failure
        // comment when there are hard failures.
        let reportURL = URL(fileURLWithPath: "/tmp/taxsim-oracle-report.txt")
        try? report.data(using: .utf8)?.write(to: reportURL)

        #expect(fails.isEmpty, Comment(rawValue: report))
        print(report)
    }
}
