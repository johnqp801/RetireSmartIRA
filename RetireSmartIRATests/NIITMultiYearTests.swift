import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 0 — NIIT in the multi-year engine", .serialized)
@MainActor
struct NIITMultiYearTests {

    @Test("TaxBreakdown.total includes niit")
    func totalIncludesNIIT() {
        let b = TaxBreakdown(federal: 1_000, state: 200, irmaa: 300, acaPremiumImpact: 0, niit: 380)
        #expect(b.total == 1_880)
    }

    @Test("TaxBreakdown niit defaults to zero and zero-value has niit 0")
    func niitDefaultsZero() {
        let b = TaxBreakdown(federal: 1_000, state: 0, irmaa: 0, acaPremiumImpact: 0)
        #expect(b.niit == 0)
        #expect(b.total == 1_000)
        #expect(TaxBreakdown.zero.niit == 0)
    }

    @Test("TaxBreakdown decodes legacy JSON without a niit key as niit == 0")
    func decodesLegacyWithoutNIIT() throws {
        let legacy = #"{"federal":1000,"state":0,"irmaa":0,"acaPremiumImpact":0}"#
        let decoded = try JSONDecoder().decode(TaxBreakdown.self, from: Data(legacy.utf8))
        #expect(decoded.niit == 0)
        #expect(decoded.total == 1_000)
    }
}
