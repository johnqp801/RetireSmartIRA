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

    // --- QCDPlanner.plan ---
    @Test("qcdFirst fixed target: primary IRA first, spouse takes the remainder")
    func plannerQcdFirstAllocation() {
        let plan = CharitableGivingPlan(intent: .fixedAnnualAmount(30_000), funding: .qcdFirst, maintainRealValue: false)
        let q = QCDPlanner.plan(plan, primaryRMD: 50_000, spouseRMD: 50_000,
                                primaryIRA: 20_000, spouseIRA: 100_000,
                                primaryEligible: true, spouseEligible: true,
                                qcdLimit: 111_000, inflationFactor: 1.0)
        #expect(q.primaryQCD == 20_000)   // capped by primary IRA
        #expect(q.spouseQCD == 10_000)    // remainder of the 30k target
        #expect(q.total == 30_000)
    }

    @Test("Per-person QCD annual limit caps each spouse")
    func plannerLimitCaps() {
        let plan = CharitableGivingPlan(intent: .fixedAnnualAmount(500_000), funding: .qcdFirst, maintainRealValue: false)
        let q = QCDPlanner.plan(plan, primaryRMD: 0, spouseRMD: 0,
                                primaryIRA: 1_000_000, spouseIRA: 1_000_000,
                                primaryEligible: true, spouseEligible: true,
                                qcdLimit: 111_000, inflationFactor: 1.0)
        #expect(q.primaryQCD == 111_000)  // limit
        #expect(q.spouseQCD == 111_000)   // limit; remainder still huge
    }

    @Test("Ineligible spouse contributes nothing")
    func plannerEligibilityGate() {
        let plan = CharitableGivingPlan(intent: .fixedAnnualAmount(20_000), funding: .qcdFirst, maintainRealValue: false)
        let q = QCDPlanner.plan(plan, primaryRMD: 0, spouseRMD: 0,
                                primaryIRA: 100_000, spouseIRA: 100_000,
                                primaryEligible: false, spouseEligible: true,
                                qcdLimit: 111_000, inflationFactor: 1.0)
        #expect(q.primaryQCD == 0)
        #expect(q.spouseQCD == 20_000)
    }

    @Test("percentOfRMD uses owner RMD basis")
    func plannerPercentOfRMD() {
        let plan = CharitableGivingPlan(intent: .percentOfRMD(0.25), funding: .qcdFirst, maintainRealValue: false)
        let q = QCDPlanner.plan(plan, primaryRMD: 40_000, spouseRMD: 40_000,
                                primaryIRA: 1_000_000, spouseIRA: 1_000_000,
                                primaryEligible: true, spouseEligible: true,
                                qcdLimit: 111_000, inflationFactor: 1.0)
        #expect(q.total == 20_000)        // 0.25 * (40k + 40k)
    }

    @Test("fixedQCD is capped at the target; maintainRealValue inflates a fixed target")
    func plannerFixedQCDandInflation() {
        let capped = CharitableGivingPlan(intent: .fixedAnnualAmount(10_000), funding: .fixedQCD(40_000), maintainRealValue: false)
        let qc = QCDPlanner.plan(capped, primaryRMD: 0, spouseRMD: 0, primaryIRA: 1_000_000, spouseIRA: 0,
                                 primaryEligible: true, spouseEligible: false, qcdLimit: 111_000, inflationFactor: 1.0)
        #expect(qc.total == 10_000)       // fixedQCD(40k) capped at the 10k target

        let infl = CharitableGivingPlan(intent: .fixedAnnualAmount(10_000), funding: .qcdFirst, maintainRealValue: true)
        let qi = QCDPlanner.plan(infl, primaryRMD: 0, spouseRMD: 0, primaryIRA: 1_000_000, spouseIRA: 0,
                                 primaryEligible: true, spouseEligible: false, qcdLimit: 111_000, inflationFactor: 1.21)
        #expect(abs(qi.total - 12_100) < 0.001)  // 10k * 1.21
    }

    @Test(".none plan yields no QCD")
    func plannerNoneNoQCD() {
        let q = QCDPlanner.plan(.none, primaryRMD: 50_000, spouseRMD: 0, primaryIRA: 1_000_000, spouseIRA: 0,
                                primaryEligible: true, spouseEligible: false, qcdLimit: 111_000, inflationFactor: 1.0)
        #expect(q.total == 0)
    }

    // --- QCDPlanner.isEligible (month-precise) ---
    @Test("isEligible is month-precise at the Dec-31 boundary")
    func eligibilityMonthPrecise() {
        let cal = Calendar(identifier: .gregorian)
        func dob(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }
        // Born 1953-07-01 -> 70.5 on 2024-01-01 -> eligible for tax year 2024.
        #expect(QCDPlanner.isEligible(birthDate: dob(1953, 7, 1), byEndOf: 2024, calendar: cal) == true)
        // Born 1953-08-01 -> 70.5 on 2024-02-01 -> eligible tax year 2024 (Dec 31 2024 >= Feb 1 2024).
        #expect(QCDPlanner.isEligible(birthDate: dob(1953, 8, 1), byEndOf: 2024, calendar: cal) == true)
        // Born 1954-08-01 -> 70.5 on 2025-02-01 -> NOT eligible tax year 2024, eligible 2025.
        #expect(QCDPlanner.isEligible(birthDate: dob(1954, 8, 1), byEndOf: 2024, calendar: cal) == false)
        #expect(QCDPlanner.isEligible(birthDate: dob(1954, 8, 1), byEndOf: 2025, calendar: cal) == true)
    }
}
