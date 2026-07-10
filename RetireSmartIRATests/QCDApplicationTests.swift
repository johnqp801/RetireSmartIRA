import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 1c — recurring QCD application", .serialized)
@MainActor
struct QCDApplicationTests {

    @Test("TradBucket.debitIRA takes from IRA only, never 401k, clamped")
    func debitIRAOnly() {
        var b = TradBucket(ira: 100_000, k401: 50_000)
        b.debitIRA(30_000)
        #expect(b.ira == 70_000)
        #expect(b.k401 == 50_000)          // 401k untouched
        b.debitIRA(1_000_000)              // over-withdraw clamps at 0
        #expect(b.ira == 0)
        #expect(b.k401 == 50_000)
    }
}
