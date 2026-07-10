//
//  InheritedIRAMultiYearTests.swift
//  RetireSmartIRATests
//
//  Regression tests for inherited-IRA distribution modeling in the multi-year engine.
//  Prior to the 2.1 inherited split, MultiYearInputAdapter rolled inherited accounts
//  into the owner buckets and ProjectionEngine applied only the owner's uniform-table
//  RMDs, understating forced taxable income, tax, and IRMAA exposure.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Inherited IRA in the multi-year engine", .serialized)
@MainActor
struct InheritedIRAMultiYearTests {

    // MARK: Fixtures

    private let baseYear = 2026

    /// Single filer, age 68 (birth 1958, own RMD age 73), no SS, no wage income,
    /// zero expenses so forced distributions are isolated from expense auto-funding.
    private func makeInputs(
        ownTraditional: Double = 0,
        taxable: Double = 0,
        inherited: [InheritedAccountInput]
    ) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                traditional: ownTraditional, roth: 0, taxable: taxable, hsa: 0,
                inheritedTraditional: inherited.filter { !$0.isRoth }.reduce(0) { $0 + $1.balance },
                inheritedRoth: inherited.filter { $0.isRoth }.reduce(0) { $0 + $1.balance }),
            baseYear: baseYear,
            primaryCurrentAge: 68,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: "CA",
            primarySSClaimAge: 70,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1958,
            spouseBirthYear: nil,
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: 0,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0,
            inheritedAccounts: inherited
        )
    }

    private func makeAssumptions(growth: Double = 0.05) -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95,
            horizonEndAgeSpouse: nil,
            cpiRate: 0.025,
            investmentGrowthRate: growth,
            withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false,
            perYearExpenseOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0
        )
    }

    private func noActions(through lastYear: Int) -> [Int: [LeverAction]] {
        Dictionary(uniqueKeysWithValues: (baseYear...lastYear).map { ($0, [LeverAction]()) })
    }

    /// Died on/after RBD, non-EDB, inherited end of 2025: annual single-life RMDs
    /// 2026-2034, forced full drain in 2035.
    private var afterRBDTrad: InheritedAccountInput {
        InheritedAccountInput(
            balance: 1_000_000, isRoth: false,
            beneficiaryType: .nonEligibleDesignated,
            decedentRBDStatus: .afterRBD,
            yearOfInheritance: 2025,
            decedentBirthYear: 1948,
            beneficiaryBirthYear: 1958)
    }

    // MARK: Died on/after RBD: annual RMDs plus year-10 drain

    @Test("After-RBD inherited trad: years 1-9 single-life RMDs flow into AGI and rmd")
    func afterRBDAnnualRMDs() {
        let years = ProjectionEngine().project(
            inputs: makeInputs(taxable: 600_000, inherited: [afterRBDTrad]),
            assumptions: makeAssumptions(),
            actionsPerYear: noActions(through: 2037))

        // 2026: initial factor is SLE(age 68) = 20.4, so RMD = 1,000,000 / 20.4.
        let expected2026 = 1_000_000.0 / 20.4
        #expect(abs(years[0].rmd - expected2026) < 1.0)
        #expect(abs(years[0].agi - expected2026) < 1.0)

        // Every pre-deadline year forces a positive RMD.
        for idx in 0...8 {
            #expect(years[idx].rmd > 0, "year \(years[idx].year) should force an annual RMD")
        }
    }

    @Test("After-RBD inherited trad: year-10 drain spikes income and later IRMAA")
    func afterRBDYearTenDrain() {
        let years = ProjectionEngine().project(
            inputs: makeInputs(taxable: 600_000, inherited: [afterRBDTrad]),
            assumptions: makeAssumptions(),
            actionsPerYear: noActions(through: 2037))

        let drain = years.first { $0.year == 2035 }!
        let priorYear = years.first { $0.year == 2034 }!
        let afterDrain = years.first { $0.year == 2036 }!

        // Deadline year forces the full remaining balance: a large income spike.
        #expect(drain.rmd > 3 * priorYear.rmd)
        #expect(drain.agi > 3 * priorYear.agi)
        #expect(drain.endOfYearBalances.inheritedTraditional == 0)

        // Nothing left to distribute afterwards.
        #expect(afterDrain.rmd == 0)

        // IRMAA two-year lookback: the 2035 MAGI spike lands on the 2037 premium.
        let irmaa2035 = drain.taxBreakdown.irmaa
        let irmaa2037 = years.first { $0.year == 2037 }!.taxBreakdown.irmaa
        #expect(irmaa2037 > 0)
        #expect(irmaa2037 > irmaa2035)

        // The drained dollars (net of the year's tax) land in taxable rather than
        // leaking out of the projection.
        #expect(drain.endOfYearBalances.taxable > priorYear.endOfYearBalances.taxable)
    }

    // MARK: Died before RBD: no annual RMDs, only the year-10 drain

    @Test("Before-RBD inherited trad: zero forced income until the year-10 drain")
    func beforeRBDNoAnnualRMDs() {
        let account = InheritedAccountInput(
            balance: 1_000_000, isRoth: false,
            beneficiaryType: .nonEligibleDesignated,
            decedentRBDStatus: .beforeRBD,
            yearOfInheritance: 2025,
            decedentBirthYear: 1948,
            beneficiaryBirthYear: 1958)
        let years = ProjectionEngine().project(
            inputs: makeInputs(taxable: 600_000, inherited: [account]),
            assumptions: makeAssumptions(growth: 0.05),
            actionsPerYear: noActions(through: 2036))

        for idx in 0...8 {
            #expect(years[idx].rmd == 0, "no annual RMD when decedent died before RBD")
            #expect(years[idx].agi == 0, "no forced income before the deadline year")
        }

        // Untouched balance compounds 9 years, then the deadline forces all of it:
        // 1,000,000 * 1.05^9 = 1,551,328.22.
        let drain = years.first { $0.year == 2035 }!
        #expect(abs(drain.rmd - 1_000_000 * pow(1.05, 9)) < 5.0)
        #expect(drain.endOfYearBalances.inheritedTraditional == 0)
    }

    // MARK: Inherited Roth: forced drain is tax-free

    @Test("Inherited Roth: year-10 drain moves balance to taxable with no AGI impact")
    func inheritedRothDrainIsTaxFree() {
        let account = InheritedAccountInput(
            balance: 500_000, isRoth: true,
            beneficiaryType: .nonEligibleDesignated,
            decedentRBDStatus: nil,
            yearOfInheritance: 2025,
            decedentBirthYear: 1948,
            beneficiaryBirthYear: 1958)
        let years = ProjectionEngine().project(
            inputs: makeInputs(taxable: 0, inherited: [account]),
            assumptions: makeAssumptions(growth: 0.05),
            actionsPerYear: noActions(through: 2036))

        let drain = years.first { $0.year == 2035 }!
        let priorYear = years.first { $0.year == 2034 }!

        // Tax-free: no AGI, no rmd-field income, no tax in the drain year.
        #expect(drain.agi == 0)
        #expect(drain.rmd == 0)
        #expect(drain.taxBreakdown.federal == 0)
        #expect(drain.endOfYearBalances.inheritedRoth == 0)

        // Balance compounds untouched for 9 years, is deposited to taxable in the
        // drain year, then grows with that year's growth step.
        let drained: Double = 500_000.0 * pow(1.05, 9.0)
        #expect(abs(drain.endOfYearBalances.taxable - drained * 1.05) < 5.0)

        // Total wealth is preserved through the drain (no leak).
        #expect(abs(drain.endOfYearBalances.total - priorYear.endOfYearBalances.total * 1.05) < 5.0)
    }

    // MARK: Isolation from levers

    @Test("Roth conversions cannot draw from or alter inherited buckets")
    func conversionsDoNotTouchInherited() {
        let inputs = makeInputs(ownTraditional: 100_000, taxable: 600_000, inherited: [afterRBDTrad])
        var actions = noActions(through: 2030)
        actions[baseYear] = [.rothConversion(amount: 500_000)]

        let withConversion = ProjectionEngine().project(
            inputs: inputs, assumptions: makeAssumptions(), actionsPerYear: actions)
        let withoutConversion = ProjectionEngine().project(
            inputs: inputs, assumptions: makeAssumptions(), actionsPerYear: noActions(through: 2030))

        // The oversized conversion clamps to the OWN trad balance; the inherited
        // bucket's path is identical either way.
        for (a, b) in zip(withConversion, withoutConversion) {
            #expect(a.endOfYearBalances.inheritedTraditional == b.endOfYearBalances.inheritedTraditional)
            #expect(a.rmd == b.rmd)
        }
        #expect(withConversion[0].endOfYearBalances.roth < 105_001.0)
    }

    // MARK: Adapter routing

    @Test("Adapter routes complete-metadata inherited accounts to their own bucket")
    func adapterRoutesInheritedAccounts() {
        let dm = DataManager(skipPersistence: true)
        dm.iraAccounts = [
            IRAAccount(name: "Own Trad", accountType: .traditionalIRA, balance: 300_000, owner: .primary),
            IRAAccount(name: "Inherited Trad", accountType: .inheritedTraditionalIRA, balance: 250_000,
                       owner: .primary, beneficiaryType: .nonEligibleDesignated,
                       decedentRBDStatus: .afterRBD, yearOfInheritance: 2024,
                       decedentBirthYear: 1950, beneficiaryBirthYear: 1961),
            IRAAccount(name: "Inherited Roth", accountType: .inheritedRothIRA, balance: 80_000,
                       owner: .primary, beneficiaryType: .nonEligibleDesignated,
                       yearOfInheritance: 2024, beneficiaryBirthYear: 1961),
        ]

        let inputs = MultiYearInputAdapter.build(
            from: dm, scenarioState: dm.scenario, assumptions: MultiYearAssumptions())

        #expect(inputs.startingBalances.primaryTraditional == 300_000)
        #expect(inputs.startingBalances.roth == 0)
        #expect(inputs.startingBalances.inheritedTraditional == 250_000)
        #expect(inputs.startingBalances.inheritedRoth == 80_000)
        #expect(inputs.inheritedAccounts.count == 2)
        #expect(inputs.inheritedAccounts.filter { $0.isRoth }.count == 1)
    }

    @Test("Adapter keeps metadata-incomplete inherited accounts in the owner buckets")
    func adapterLegacyFallbackForIncompleteMetadata() {
        let dm = DataManager(skipPersistence: true)
        dm.iraAccounts = [
            // No beneficiaryType/yearOfInheritance/beneficiaryBirthYear: legacy roll-up.
            IRAAccount(name: "Inherited Trad (no metadata)", accountType: .inheritedTraditionalIRA,
                       balance: 125_000, owner: .primary),
        ]

        let inputs = MultiYearInputAdapter.build(
            from: dm, scenarioState: dm.scenario, assumptions: MultiYearAssumptions())

        #expect(inputs.startingBalances.primaryTraditional == 125_000)
        #expect(inputs.startingBalances.inheritedTraditional == 0)
        #expect(inputs.inheritedAccounts.isEmpty)
    }

    // MARK: AccountSnapshot back-compat

    @Test("AccountSnapshot: inherited fields default to zero and flow into total")
    func accountSnapshotDefaultsAndTotal() {
        let legacy = AccountSnapshot(traditional: 100, roth: 50, taxable: 25, hsa: 10)
        #expect(legacy.inheritedTraditional == 0)
        #expect(legacy.inheritedRoth == 0)
        #expect(legacy.total == 185)

        let split = AccountSnapshot(traditional: 100, roth: 50, taxable: 25, hsa: 10,
                                    inheritedTraditional: 40, inheritedRoth: 15)
        #expect(split.traditional == 100)
        #expect(split.total == 240)
    }
}
