import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Audit — profile catalog", .serialized)
@MainActor
struct AuditProfilesTests {
    @Test("catalog is non-empty, ids unique, spans PA/IL/MS/CA/NJ and no-tax states")
    func catalogWellFormed() {
        let all = AuditProfiles.all
        #expect(all.count >= 24)
        #expect(Set(all.map(\.id)).count == all.count)
        let states = Set(all.map { $0.inputs.state })
        for s in ["PA", "IL", "MS", "CA", "NJ", "FL"] { #expect(states.contains(s)) }
    }
}
