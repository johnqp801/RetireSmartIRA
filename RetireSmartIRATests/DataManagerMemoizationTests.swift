//
//  DataManagerMemoizationTests.swift
//  RetireSmartIRATests
//
//  Verifies the EngineMemoCache layer (DataManager+Memo.swift):
//    1. Repeated reads with no input changes return the same value (cache hit).
//    2. Mutating any source-of-truth @Published input invalidates the cache,
//       so the next read returns a value reflecting the new input.
//
//  Covers 5 of the 8 memoized properties:
//    - legacyHeirTaxEstimate
//    - scenarioStateTax
//    - scenarioFederalTax
//    - baselineACAMagi
//    - seniorBonusDeductionAmount
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("DataManager memoization — cache hit + invalidation", .serialized)
@MainActor
struct DataManagerMemoizationTests {

    // MARK: - legacyHeirTaxEstimate

    @Test("legacyHeirTaxEstimate caches stable result across repeated reads")
    func legacyHeirTaxEstimateCachesStableResult() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.iraAccounts = [
            IRAAccount(name: "Trad", accountType: .traditionalIRA, balance: 800_000, owner: .primary)
        ]
        dm.legacyHeirType = "adultChild"
        dm.legacyHeirEstimatedSalary = 90_000
        dm.legacyHeirFilingStatus = .single

        let first = dm.legacyHeirTaxEstimate
        let second = dm.legacyHeirTaxEstimate
        let third = dm.legacyHeirTaxEstimate

        #expect(first.totalTaxOverDrawdown == second.totalTaxOverDrawdown)
        #expect(second.totalTaxOverDrawdown == third.totalTaxOverDrawdown)
        #expect(first.marginalRate == third.marginalRate)
    }

    @Test("legacyHeirTaxEstimate invalidates when primary Traditional IRA balance changes")
    func legacyHeirTaxEstimateInvalidatesOnBalanceChange() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.iraAccounts = [
            IRAAccount(name: "Trad", accountType: .traditionalIRA, balance: 500_000, owner: .primary)
        ]
        dm.legacyHeirType = "adultChild"

        let before = dm.legacyHeirTaxEstimate.totalTaxOverDrawdown

        // Bump the balance — heir taxable distribution should rise, so total tax should rise.
        dm.iraAccounts[0].balance = 2_000_000

        let after = dm.legacyHeirTaxEstimate.totalTaxOverDrawdown
        #expect(after > before, "Expected total heir tax to rise after IRA balance increase; got before=\(before) after=\(after)")
    }

    @Test("legacyHeirTaxEstimate invalidates when legacyHeirType changes")
    func legacyHeirTaxEstimateInvalidatesOnHeirTypeChange() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.iraAccounts = [
            IRAAccount(name: "Trad", accountType: .traditionalIRA, balance: 1_000_000, owner: .primary)
        ]
        dm.legacyHeirType = "adultChild"

        let firstHash = dm.engineInputsHash
        _ = dm.legacyHeirTaxEstimate  // warm cache

        dm.legacyHeirType = "spouseThenChild"

        let secondHash = dm.engineInputsHash
        #expect(firstHash != secondHash, "Changing legacyHeirType should change engineInputsHash")

        // Force a fresh read; if the cache had not been invalidated, the value would still
        // be tagged with `firstHash` and the comparison below would pass trivially. So we
        // assert via the hash slot itself that the cache entry now reflects the new hash.
        _ = dm.legacyHeirTaxEstimate
        #expect(dm.memoCache.legacyHeirTaxEstimate?.inputsHash == secondHash)
    }

    // MARK: - scenarioStateTax

    @Test("scenarioStateTax caches stable result across repeated reads")
    func scenarioStateTaxCachesStableResult() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.selectedState = .california
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 120_000)
        ]

        let first = dm.scenarioStateTax
        let second = dm.scenarioStateTax
        let third = dm.scenarioStateTax

        #expect(first == second)
        #expect(second == third)
    }

    @Test("scenarioStateTax invalidates when yourRothConversion changes")
    func scenarioStateTaxInvalidatesOnRothConversionChange() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.selectedState = .california
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        dm.iraAccounts = [
            IRAAccount(name: "Trad", accountType: .traditionalIRA, balance: 500_000, owner: .primary)
        ]

        let before = dm.scenarioStateTax

        dm.yourRothConversion = 50_000

        let after = dm.scenarioStateTax
        #expect(after > before, "Adding a $50K conversion should raise CA state tax; got before=\(before) after=\(after)")
    }

    // MARK: - scenarioFederalTax

    @Test("scenarioFederalTax caches stable result across repeated reads")
    func scenarioFederalTaxCachesStableResult() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]

        let first = dm.scenarioFederalTax
        let second = dm.scenarioFederalTax
        #expect(first == second)
    }

    @Test("scenarioFederalTax invalidates when filingStatus changes")
    func scenarioFederalTaxInvalidatesOnFilingStatusChange() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 150_000)
        ]

        let asSingle = dm.scenarioFederalTax

        dm.filingStatus = .marriedFilingJointly
        dm.enableSpouse = true

        let asMFJ = dm.scenarioFederalTax
        #expect(asSingle != asMFJ, "Federal tax should differ between Single and MFJ at $150K income")
    }

    // MARK: - baselineACAMagi

    @Test("baselineACAMagi caches stable result across repeated reads")
    func baselineACAMagiCachesStableResult() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 70_000)
        ]

        let first = dm.baselineACAMagi
        let second = dm.baselineACAMagi
        #expect(first == second)
    }

    @Test("baselineACAMagi invalidates when income source amount changes")
    func baselineACAMagiInvalidatesOnIncomeChange() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000)
        ]
        let before = dm.baselineACAMagi.value

        dm.incomeSources[0].annualAmount = 90_000
        let after = dm.baselineACAMagi.value

        #expect(after > before)
        #expect(abs((after - before) - 30_000) < 1)
    }

    // MARK: - seniorBonusDeductionAmount

    @Test("seniorBonusDeductionAmount caches stable result across repeated reads")
    func seniorBonusDeductionCachesStableResult() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        // Birth date that makes the user 70 at end of 2026 (eligible).
        var c = DateComponents(); c.year = 1956; c.month = 6; c.day = 1
        dm.birthDate = Calendar.current.date(from: c)!
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]

        let first = dm.seniorBonusDeductionAmount
        let second = dm.seniorBonusDeductionAmount
        #expect(first == second)
        #expect(first > 0, "User aged 70 with modest income should have a positive senior bonus deduction")
    }

    @Test("seniorBonusDeductionAmount invalidates when income (phaseout MAGI) changes")
    func seniorBonusDeductionInvalidatesOnIncomeChange() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        var c = DateComponents(); c.year = 1956; c.month = 6; c.day = 1
        dm.birthDate = Calendar.current.date(from: c)!
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]

        let modestIncomeBonus = dm.seniorBonusDeductionAmount

        // Push MAGI well into the phaseout zone (Single phaseout starts at $75K).
        dm.incomeSources[0].annualAmount = 300_000
        let highIncomeBonus = dm.seniorBonusDeductionAmount

        #expect(highIncomeBonus < modestIncomeBonus, "Senior bonus should phase down as MAGI rises; got modest=\(modestIncomeBonus) high=\(highIncomeBonus)")
    }

    // MARK: - Cross-property: engine hash changes when any input changes

    @Test("engineInputsHash changes when scenarioYourExtraWithdrawal changes")
    func engineInputsHashChangesOnExtraWithdrawal() {
        let dm = DataManager(skipPersistence: true)
        dm.iraAccounts = [
            IRAAccount(name: "Trad", accountType: .traditionalIRA, balance: 500_000, owner: .primary)
        ]
        let before = dm.engineInputsHash
        dm.yourExtraWithdrawal = 20_000
        let after = dm.engineInputsHash
        #expect(before != after)
    }

    // MARK: - Phase 3b regression: plan classification must invalidate the memo
    //
    // Reproduces the in-app defect: a New York resident reclassifies a pension
    // from "Government pension, New York State or local" (planStructure:
    // .definedBenefit, planSource: .nyStateOrLocal -- fully excluded under NY's
    // IT-201 Line 26 per-source rule) to "Government pension, another state or
    // locality" (planSource: .otherStateOrLocal -- no longer matches that rule,
    // falls back to NY's ordinary $20,000-capped pension/IRA exclusion). The
    // engine computation is correct either way (`stateTaxBreakdown`/
    // `TaxCalculationEngine.calculateStateTax` both read `planStructure`/
    // `planSource` fresh off the row every call); the bug was that
    // `memoizedScenarioStateTax`'s cache key (`engineInputsHash`) did not
    // include either field, so `scenarioStateTax` kept returning the
    // pre-reclassification value forever.

    @Test("scenarioStateTax invalidates when a pension's planSource classification changes (NY)")
    func scenarioStateTaxInvalidatesOnPensionPlanSourceChange() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.selectedState = .newYork
        dm.filingStatus = .single
        var c = DateComponents(); c.year = 1953; c.month = 6; c.day = 1
        dm.birthDate = Calendar.current.date(from: c)!  // age 73 in 2026
        dm.incomeSources = [
            IncomeSource(
                name: "NY State Pension", type: .pension, annualAmount: 70_000,
                planStructure: .definedBenefit, planSource: .nyStateOrLocal
            )
        ]

        // Prime the memo: "Government pension, New York State or local" is
        // fully excluded under NY's per-source Line 26 rule.
        let beforeHash = dm.engineInputsHash
        let before = dm.scenarioStateTax

        // Mutate ONLY the classification -- reclassify to "another state or
        // locality," which no longer matches NY's per-source rule and falls
        // back to the ordinary $20,000-capped pension exclusion.
        dm.incomeSources[0].planSource = .otherStateOrLocal

        let afterHash = dm.engineInputsHash
        #expect(beforeHash != afterHash, "Changing planSource should change engineInputsHash")

        let after = dm.scenarioStateTax
        #expect(after != before, "Reclassifying the pension's planSource must change scenarioStateTax; got before=\(before) after=\(after) (stale memo would leave these equal)")
        #expect(after > before, "Losing the full Line 26 exclusion for a $50K larger taxable base should raise NY state tax; got before=\(before) after=\(after)")
    }

    @Test("scenarioStateTax invalidates when a pension's planStructure classification changes (NY)")
    func scenarioStateTaxInvalidatesOnPensionPlanStructureChange() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.selectedState = .newYork
        dm.filingStatus = .single
        var c = DateComponents(); c.year = 1953; c.month = 6; c.day = 1
        dm.birthDate = Calendar.current.date(from: c)!  // age 73 in 2026
        dm.incomeSources = [
            IncomeSource(
                name: "NY State Pension", type: .pension, annualAmount: 70_000,
                planStructure: .definedBenefit, planSource: .nyStateOrLocal
            )
        ]

        let beforeHash = dm.engineInputsHash
        let before = dm.scenarioStateTax

        // Mutate ONLY the structure -- NY's per-source rule requires
        // .definedBenefit; .definedContribution no longer matches even though
        // the source is still NY state/local.
        dm.incomeSources[0].planStructure = .definedContribution

        let afterHash = dm.engineInputsHash
        #expect(beforeHash != afterHash, "Changing planStructure should change engineInputsHash")

        let after = dm.scenarioStateTax
        #expect(after != before, "Reclassifying the pension's planStructure must change scenarioStateTax; got before=\(before) after=\(after) (stale memo would leave these equal)")
        #expect(after > before, "Losing the full Line 26 exclusion for a $50K larger taxable base should raise NY state tax; got before=\(before) after=\(after)")
    }

    // MARK: - Phase 3b: account-level plan classification, hash coverage only
    //
    // Audit finding (see fix report): no production code path ever populates
    // `stateTaxBreakdown`/`calculateStateTaxFromGross`'s `distributionComponents`
    // parameter for the single-year DataManager pipeline these 8 memoized
    // properties sit behind -- every production call site passes `nil`, so
    // `IRAAccount.planStructure`/`planSource` reach the per-source exemption
    // matcher only via `ProjectionEngine`'s multi-year path, which builds its
    // own income-source rows directly against `TaxCalculationEngine` and never
    // goes through `DataManager`'s `EngineMemoCache`. So there is currently no
    // memoized *value* whose output depends on an account's classification to
    // assert against -- this test instead proves the hash itself now covers
    // those two fields, per the file's "when in doubt, add it" policy, so a
    // future wiring of account classification into this pipeline fails safe
    // rather than reintroducing this exact staleness bug silently.

    @Test("engineInputsHash changes when an account's planStructure or planSource changes")
    func engineInputsHashChangesOnAccountPlanClassificationChange() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.iraAccounts = [
            IRAAccount(
                name: "Trad", accountType: .traditionalIRA, balance: 500_000, owner: .primary,
                planStructure: .definedContribution, planSource: .privateEmployer
            )
        ]

        let sourceBefore = dm.engineInputsHash
        dm.iraAccounts[0].planSource = .governmentUnspecified
        let sourceAfter = dm.engineInputsHash
        #expect(sourceBefore != sourceAfter, "Changing an account's planSource should change engineInputsHash")

        dm.iraAccounts[0].planStructure = .ira
        let structureAfter = dm.engineInputsHash
        #expect(sourceAfter != structureAfter, "Changing an account's planStructure should change engineInputsHash")
    }
}
