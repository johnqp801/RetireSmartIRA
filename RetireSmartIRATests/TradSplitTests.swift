import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 1a — owner IRA/401(k) split", .serialized)
@MainActor
struct TradSplitTests {

    @Test("AccountSnapshot computed traditional == IRA + 401k")
    func snapshotCombinedEqualsSum() {
        let s = AccountSnapshot(primaryTraditionalIRA: 300_000, primaryTraditional401k: 200_000,
                                spouseTraditionalIRA: 100_000, spouseTraditional401k: 50_000,
                                roth: 0, taxable: 0, hsa: 0)
        #expect(s.primaryTraditional == 500_000)
        #expect(s.spouseTraditional == 150_000)
        #expect(s.traditional == 650_000)
    }

    @Test("Legacy combined init routes to the IRA portion")
    func legacyInitRoutesToIRA() {
        let s = AccountSnapshot(primaryTraditional: 400_000, spouseTraditional: 100_000,
                                roth: 0, taxable: 0, hsa: 0)
        #expect(s.primaryTraditionalIRA == 400_000)
        #expect(s.primaryTraditional401k == 0)
        #expect(s.spouseTraditionalIRA == 100_000)
        #expect(s.primaryTraditional == 400_000)
    }

    @Test("Legacy JSON without split keys decodes (routes combined -> IRA)")
    func legacyJSONDecodes() throws {
        let legacy = #"{"primaryTraditional":400000,"spouseTraditional":100000,"roth":0,"taxable":0,"hsa":0}"#
        let s = try JSONDecoder().decode(AccountSnapshot.self, from: Data(legacy.utf8))
        #expect(s.primaryTraditionalIRA == 400_000)
        #expect(s.primaryTraditional401k == 0)
        #expect(s.spouseTraditionalIRA == 100_000)
        #expect(s.traditional == 500_000)
    }

    @Test("Round-trip encode/decode of split snapshot preserves the split")
    func roundTripSplit() throws {
        let s = AccountSnapshot(primaryTraditionalIRA: 300_000, primaryTraditional401k: 200_000,
                                spouseTraditionalIRA: 0, spouseTraditional401k: 0,
                                roth: 10, taxable: 20, hsa: 30)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(AccountSnapshot.self, from: data)
        #expect(back == s)
        #expect(back.primaryTraditional401k == 200_000)
    }

    // MARK: - Adapter fixture

    /// Build a DataManager whose accounts include one primary traditional IRA ($300k)
    /// and one primary traditional 401(k) ($200k), for exercising the adapter's split.
    private func makeDMForSplit() -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.iraAccounts = [
            IRAAccount(name: "Primary Trad IRA", accountType: .traditionalIRA, balance: 300_000, owner: .primary),
            IRAAccount(name: "Primary Trad 401k", accountType: .traditional401k, balance: 200_000, owner: .primary),
        ]
        return dm
    }

    @Test("Adapter splits owner traditional into IRA vs 401k per spouse")
    func adapterSplitsIRAvs401k() {
        // Build a DataManager with a primary traditional IRA + primary 401(k).
        let dm = makeDMForSplit()
        let inputs = MultiYearInputAdapter.build(
            from: dm,
            scenarioState: dm.scenario,
            assumptions: MultiYearAssumptions()
        )
        #expect(inputs.startingBalances.primaryTraditionalIRA == 300_000)
        #expect(inputs.startingBalances.primaryTraditional401k == 200_000)
        // Combined is unchanged from the pre-split behavior:
        #expect(inputs.startingBalances.primaryTraditional == 500_000)
    }
}
