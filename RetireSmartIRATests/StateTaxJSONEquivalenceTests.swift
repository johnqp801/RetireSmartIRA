import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State tax JSON loader (Phase 1)")
struct StateTaxJSONLoaderTests {

    @Test("Loader returns all 51 jurisdictions")
    func loadsAllJurisdictions() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        #expect(configs.count == 51)
        for state in USState.allCases {
            #expect(configs[state] != nil, "missing \(state.abbreviation)")
        }
    }

    @Test("Loader throws for a tax year with no bundled data")
    func throwsForUnknownYear() {
        #expect(throws: (any Error).self) {
            try StateTaxDataLoader.load(taxYear: 1999)
        }
    }

    @Test("configs2026 static property is pre-populated with all 51 jurisdictions")
    func configs2026StaticPropertyLoads() {
        #expect(StateTaxDataLoader.configs2026.count == 51)
        for state in USState.allCases {
            #expect(StateTaxDataLoader.configs2026[state] != nil, "missing \(state.abbreviation)")
        }
    }

    // MARK: - Real-file survival checks (Task 9 item 5)
    //
    // The highest-value test here is that all 51 real bundled files genuinely
    // load and decode (loadsAllJurisdictions, above). These two go further:
    // they prove specific behaviorally-inert fields survive the ACTUAL file on
    // disk, not just a synthetic fixture. New Jersey's stepped phaseout upper
    // bound was nearly lost silently in Task 5 (an .infinity sentinel that a
    // naive Double decode would have turned into 0), so it is the highest-risk
    // field to re-check now that real, generated JSON is the input.

    @Test("New Jersey's pension exemption keeps its .infinity upper bound after loading the real bundled file")
    func newJerseyPensionExemptionInfinityUpperBoundSurvivesRealFile() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        let nj = try #require(configs[.newJersey])
        guard case .steppedPhaseoutByFilingStatus(_, _, let tiers) = nj.retirementExemptions.pensionExemption else {
            Issue.record("expected NJ pensionExemption to be steppedPhaseoutByFilingStatus, got \(nj.retirementExemptions.pensionExemption)")
            return
        }
        let lastTier = try #require(tiers.last)
        #expect(lastTier.upperBound.isInfinite, "NJ pensionExemption's last tier upperBound should be .infinity")
    }

    @Test("New Jersey's IRA withdrawal exemption keeps its .infinity upper bound after loading the real bundled file")
    func newJerseyIRAExemptionInfinityUpperBoundSurvivesRealFile() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        let nj = try #require(configs[.newJersey])
        guard case .steppedPhaseoutByFilingStatus(_, _, let tiers) = nj.retirementExemptions.iraWithdrawalExemption else {
            Issue.record("expected NJ iraWithdrawalExemption to be steppedPhaseoutByFilingStatus, got \(nj.retirementExemptions.iraWithdrawalExemption)")
            return
        }
        let lastTier = try #require(tiers.last)
        #expect(lastTier.upperBound.isInfinite, "NJ iraWithdrawalExemption's last tier upperBound should be .infinity")
    }

    // MARK: - estimatedPaymentSchedule quarters validation (Task 9 item 4)
    //
    // EstimatedPaymentSchedule's hand-written initializer enforces
    // `precondition(abs(q1+q2+q3+q4 - 1.0) < 0.001)`, but Codable's
    // compiler-synthesized init(from:) assigns stored properties directly and
    // bypasses that precondition entirely (PlanningModels.swift:100-113). The
    // table this loader replaces could never produce a bad schedule because
    // every instance went through the throwing initializer; JSON has no such
    // guarantee; a hand-edited or corrupted file could silently short (or
    // overpay) a whole state's estimated tax. This is the first code that
    // decodes the type from real files, so it is the first place the gap can
    // bite -- the loader must close it itself.

    @Test("decode throws a specific, state-naming error when estimatedPaymentSchedule quarters do not sum to 1.0")
    func decodeThrowsOnInvalidPaymentSchedule() throws {
        let malformed = Data("""
        {
            "state": "CA",
            "taxSystem": {"kind": "flat", "rate": 0.05},
            "retirementExemptions": {"socialSecurityExempt": true,
                                     "pensionExemption": {"kind": "none"},
                                     "iraWithdrawalExemption": {"kind": "none"}},
            "stateDeduction": {"kind": "none"},
            "estimatedPaymentSchedule": {"q1Pct": 0.5, "q2Pct": 0.5, "q3Pct": 0.5, "q4Pct": 0.5}
        }
        """.utf8)

        #expect(throws: StateTaxDataLoader.LoadError.self) {
            _ = try StateTaxDataLoader.decode(malformed, state: .california, taxYear: 2026)
        }

        do {
            _ = try StateTaxDataLoader.decode(malformed, state: .california, taxYear: 2026)
            Issue.record("expected decode to throw for a schedule summing to 2.0")
        } catch let error as StateTaxDataLoader.LoadError {
            guard case .invalidPaymentSchedule(let state, let taxYear, let sum) = error else {
                Issue.record("expected .invalidPaymentSchedule, got \(error)")
                return
            }
            #expect(state == .california)
            #expect(taxYear == 2026)
            #expect(abs(sum - 2.0) < 0.0001)
            #expect(error.errorDescription?.contains("CA") == true,
                    "error message should name the state, got: \(error.errorDescription ?? "nil")")
        } catch {
            Issue.record("expected StateTaxDataLoader.LoadError, got \(error)")
        }
    }

    @Test("decode succeeds when estimatedPaymentSchedule quarters sum to exactly 1.0")
    func decodeSucceedsOnValidPaymentSchedule() throws {
        let valid = Data("""
        {
            "state": "CA",
            "taxSystem": {"kind": "flat", "rate": 0.05},
            "retirementExemptions": {"socialSecurityExempt": true,
                                     "pensionExemption": {"kind": "none"},
                                     "iraWithdrawalExemption": {"kind": "none"}},
            "stateDeduction": {"kind": "none"},
            "estimatedPaymentSchedule": {"q1Pct": 0.30, "q2Pct": 0.40, "q3Pct": 0.0, "q4Pct": 0.30}
        }
        """.utf8)
        let config = try StateTaxDataLoader.decode(valid, state: .california, taxYear: 2026)
        #expect(config.state == .california)
    }

    @Test("decode throws a specific, state-naming error for malformed JSON")
    func decodeThrowsOnMalformedJSON() throws {
        let malformed = Data("not valid json at all".utf8)
        #expect(throws: StateTaxDataLoader.LoadError.self) {
            _ = try StateTaxDataLoader.decode(malformed, state: .wyoming, taxYear: 2026)
        }
    }
}
