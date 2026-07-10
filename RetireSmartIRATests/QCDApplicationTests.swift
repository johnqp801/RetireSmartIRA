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

    /// Make a DataManager with no persistence and a known primary birth date (Jan 1 of the
    /// given year). Mirrors MultiYearInputAdapterTests.makeDataManager's fixture pattern.
    private func makeDMForQCD(primaryBornJan1 year: Int) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        var c = DateComponents()
        c.year = year; c.month = 1; c.day = 1
        dm.birthDate = Calendar.current.date(from: c)!
        return dm
    }

    @Test("Adapter threads primary/spouse birthDate into inputs")
    func adapterThreadsBirthDate() {
        let dm = makeDMForQCD(primaryBornJan1: 1953)
        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )
        let year = Calendar.current.component(.year, from: inputs.primaryBirthDate)
        #expect(year == 1953)
    }
}
