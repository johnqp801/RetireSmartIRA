import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State tax Codable round trips (Phase 1)")
struct StateTaxCodableRoundTripTests {

    @Test("StateVerification round-trips through JSON")
    func verificationRoundTrips() throws {
        let original = StateVerification(
            lastVerified: "2026-08-02",
            primarySources: ["https://www.ksrevenue.gov/webfile/help/scheduleS_A.html"],
            billReferences: ["SB 1 (2024 special session)"],
            knownLimitations: ["Public pensions are not distinguished from private."]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StateVerification.self, from: data)
        #expect(decoded == original)
    }

    @Test("StateVerification defaults to unverified with empty collections")
    func verificationUnverifiedDefault() {
        let unverified = StateVerification.unverified
        #expect(unverified.lastVerified == "")
        #expect(unverified.primarySources.isEmpty)
        #expect(unverified.knownLimitations.isEmpty)
        #expect(unverified.billReferences.isEmpty)
        #expect(unverified.isVerified == false)
    }

    @Test("StateTaxSystem round-trips every case")
    func taxSystemRoundTrips() throws {
        let cases: [StateTaxSystem] = [
            .noIncomeTax,
            .specialLimited,
            .flat(rate: 0.038),
            .progressive(
                single: [TaxBracket(threshold: 0, rate: 0.052),
                         TaxBracket(threshold: 23_000, rate: 0.0558)],
                married: [TaxBracket(threshold: 0, rate: 0.052),
                          TaxBracket(threshold: 46_000, rate: 0.0558)]
            )
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StateTaxSystem.self, from: data)
            #expect(decoded.matchesShape(of: original), "round trip lost \(original)")
        }
    }

    @Test("StateDeduction round-trips every case")
    func stateDeductionRoundTrips() throws {
        let cases: [StateDeduction] = [
            .none,
            .conformsToFederal,
            .fixed(single: 3_360, married: 3_360),
            .fixed(single: 8_000, married: 16_000)
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StateDeduction.self, from: data)
            switch (decoded, original) {
            case (.none, .none), (.conformsToFederal, .conformsToFederal):
                break
            case let (.fixed(s1, m1), .fixed(s2, m2)):
                #expect(s1 == s2 && m1 == m2)
            default:
                Issue.record("round trip lost \(original)")
            }
        }
    }

    @Test("EstimatedPaymentSchedule round-trips")
    func estimatedScheduleRoundTrips() throws {
        let original = EstimatedPaymentSchedule.california
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EstimatedPaymentSchedule.self, from: data)
        #expect(decoded == original)
    }

    @Test("StateSafeHarborRule round-trips every case")
    func safeHarborRoundTrips() throws {
        let cases: [StateSafeHarborRule] = [
            .mirrorsFederal,
            .flatRate(1.10),
            .agiThreshold(threshold: 250_000, lowRate: 1.00, highRate: 1.10),
            .mirrorsFederalWithDisqualification(disqualifyAGI: 1_000_000),
            .noPenalty
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StateSafeHarborRule.self, from: data)
            #expect(decoded == original, "round trip lost \(original)")
        }
    }
}

extension StateTaxSystem {
    /// Structural equality ignoring TaxBracket.id, which is regenerated on decode.
    func matchesShape(of other: StateTaxSystem) -> Bool {
        switch (self, other) {
        case (.noIncomeTax, .noIncomeTax), (.specialLimited, .specialLimited):
            return true
        case let (.flat(a), .flat(b)):
            return a == b
        case let (.progressive(s1, m1), .progressive(s2, m2)):
            let sameBrackets: ([TaxBracket], [TaxBracket]) -> Bool = { x, y in
                x.count == y.count && zip(x, y).allSatisfy {
                    $0.threshold == $1.threshold && $0.rate == $1.rate
                }
            }
            return sameBrackets(s1, s2) && sameBrackets(m1, m2)
        default:
            return false
        }
    }
}
