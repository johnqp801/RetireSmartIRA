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

    // MARK: - TradBucket

    @Test("TradBucket.debit depletes 401k first, then IRA, clamped")
    func tradBucketDebitOrder() {
        var b = TradBucket(ira: 100_000, k401: 50_000)
        b.debit(30_000)                       // all from 401k
        #expect(b.k401 == 20_000)
        #expect(b.ira == 100_000)
        b.debit(40_000)                       // 20k from 401k, 20k from IRA
        #expect(b.k401 == 0)
        #expect(b.ira == 80_000)
        b.debit(1_000_000)                    // over-withdraw: clamps at 0, never negative
        #expect(b.k401 == 0)
        #expect(b.ira == 0)
    }

    @Test("TradBucket.grow scales both portions; total sums them")
    func tradBucketGrowAndTotal() {
        var b = TradBucket(ira: 100_000, k401: 100_000)
        #expect(b.total == 200_000)
        b.grow(1.06)
        #expect(abs(b.ira - 106_000) < 0.001)
        #expect(abs(b.k401 - 106_000) < 0.001)
    }

    @Test("TradBucket.credit401k adds to the 401k portion only")
    func tradBucketCredit401k() {
        var b = TradBucket(ira: 10, k401: 20)
        b.credit401k(5)
        #expect(b.k401 == 25)
        #expect(b.ira == 10)
    }

    // MARK: - ProjectionEngine behavior-preservation

    private var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    @Test("Split trad yields identical projection as the equivalent all-IRA pool")
    func splitProjectionMatchesCombined() {
        // Same $1M combined, one as all-IRA, one split 600k IRA / 400k 401k.
        let allIRA = MultiYearStaticInputs.forSplitTest(primaryIRA: 1_000_000, primary401k: 0)
        let split   = MultiYearStaticInputs.forSplitTest(primaryIRA: 600_000, primary401k: 400_000)
        let engine = ProjectionEngine()
        let a = engine.project(inputs: allIRA, assumptions: MultiYearStaticInputs.splitTestAssumptions(),
                               actionsPerYear: [baseYear: [.rothConversion(amount: 100_000)]])
        let b = engine.project(inputs: split, assumptions: MultiYearStaticInputs.splitTestAssumptions(),
                               actionsPerYear: [baseYear: [.rothConversion(amount: 100_000)]])
        #expect(a.count == b.count)
        for (ya, yb) in zip(a, b) {
            #expect(abs(ya.taxBreakdown.total - yb.taxBreakdown.total) < 0.01)
            #expect(abs(ya.agi - yb.agi) < 0.01)
            #expect(abs(ya.endOfYearBalances.primaryTraditional - yb.endOfYearBalances.primaryTraditional) < 0.01)
        }
        // 401k-first: the $100k conversion (and any traditional gross-up funding the tax bill,
        // since this fixture has no taxable bucket to sell) draws from the 401(k) portion before
        // touching the IRA. So the 401k's *fraction* of its starting balance remaining should be
        // strictly less than the IRA's fraction of its starting balance remaining (401k depleted
        // relatively more) — a tight, sub-vacuous ordering check. Pre-fix, the legacy scalar
        // snapshot always reports 401k == 0 regardless of draw order, which would trivially
        // satisfy a loose "401k < starting401k" check but fail this ratio comparison the moment
        // the IRA is untouched (ira fraction remaining == 1.0 > 401k fraction remaining).
        let ira401kAfter = b[0].endOfYearBalances
        let k401FractionRemaining = ira401kAfter.primaryTraditional401k / (400_000 * 1.06)
        let iraFractionRemaining = ira401kAfter.primaryTraditionalIRA / (600_000 * 1.06)
        #expect(k401FractionRemaining < iraFractionRemaining)
        // And the IRA must be fully untouched by the $100k conversion itself: the only debits
        // against this fixture are the conversion and a possible tax gross-up, both 401k-first,
        // so IRA can only be touched once the 401k ($400k, grown) is fully exhausted — it isn't
        // here, so IRA should still equal its full starting balance grown by one year.
        #expect(abs(ira401kAfter.primaryTraditionalIRA - 600_000 * 1.06) < 0.01)
    }
}

extension MultiYearStaticInputs {
    /// Test-only fixture mirroring `ProjectionEngineTests.makeInputs`'s defaults (single filer,
    /// age 65, no expenses/wage/pension income, CA), but with an explicit IRA/401k split on the
    /// primary's traditional balance instead of the collapsed scalar.
    static func forSplitTest(primaryIRA: Double, primary401k: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                primaryTraditionalIRA: primaryIRA, primaryTraditional401k: primary401k,
                spouseTraditionalIRA: 0, spouseTraditional401k: 0,
                roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 66,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: "CA",
            primarySSClaimAge: 67,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 3_000,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 66,
            spouseBirthYear: nil,
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: 0,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
    }

    /// Test-only fixture mirroring `ProjectionEngineTests.makeAssumptions`'s defaults.
    static func splitTestAssumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95,
            horizonEndAgeSpouse: nil,
            cpiRate: 0.025,
            investmentGrowthRate: 0.06,
            withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false,
            perYearExpenseOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0
        )
    }
}
