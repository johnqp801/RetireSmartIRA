import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 2c — conversion-approach UI logic", .serialized)
@MainActor
struct ApproachUITests {

    @Test("PersistedConversionApproach round-trips all three approaches through Codable")
    func persistRoundTrips() throws {
        let cases: [ConversionApproach] = [
            .recommendedTaxMin, .fillToBracket(rate: 0.24), .limitToIRMAA(tier: 2, buffer: 5_000)
        ]
        for approach in cases {
            let persisted = PersistedConversionApproach(approach)
            let data = try JSONEncoder().encode(persisted)
            let back = try JSONDecoder().decode(PersistedConversionApproach.self, from: data)
            #expect(back == persisted)
            #expect(back.toApproach() == approach)
        }
    }

    @Test("Assumptions saved without a conversionApproach key default to recommendedTaxMin")
    func assumptionsBackCompatDefault() throws {
        // A prior-version encoded assumptions blob has no conversionApproach key.
        var a = MultiYearAssumptions.default
        a.conversionApproach = PersistedConversionApproach(.fillToBracket(rate: 0.24))
        let full = try JSONEncoder().encode(a)
        var obj = try JSONSerialization.jsonObject(with: full) as! [String: Any]
        obj.removeValue(forKey: "conversionApproach")
        let stripped = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(MultiYearAssumptions.self, from: stripped)
        #expect(decoded.conversionApproach == .recommendedTaxMin)
    }
}
