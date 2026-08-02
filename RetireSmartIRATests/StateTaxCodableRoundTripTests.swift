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
        #expect(unverified.isVerified == false)
    }
}
