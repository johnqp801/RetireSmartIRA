//
//  DataManager+Memo.swift
//  RetireSmartIRA
//
//  Memoization layer for expensive DataManager computed properties that are
//  re-evaluated dozens of times per Scenarios-tab render. SwiftUI runs many
//  layout passes during tab transitions; each pass re-invokes view bodies,
//  which re-read these properties. Caching the result against a hash of the
//  source-of-truth Observable state turns repeat reads into O(1) lookups.
//
//  Post-1.8.3 note: with all managers migrated to @Observable, fine-grained
//  tracking eliminates much of the "fan-in" multiplication that originally
//  motivated this cache (build 42). Multi-pass layout still re-invokes the
//  same body 2-3x per gesture frame though, and the underlying engine
//  pipelines (e.g. legacyForwardProjection's 10-year drain simulation) remain
//  expensive per-call. We keep all 8 cached properties as a defensive
//  measure — the hash check is microseconds, the protected computations are
//  milliseconds-to-tens-of-milliseconds. Per the migration plan: "when in
//  doubt, KEEP the memoization."
//
//  Design notes
//  ------------
//  • The cache lives in a `final class` instance held by DataManager as a `let`.
//    Mutating internal slots is invisible to SwiftUI's observation machinery
//    (the EngineMemoCache class is not @Observable), so the cache writes
//    themselves never re-trigger body invalidation — important to avoid loops.
//  • All 8 memoized properties depend transitively on essentially the same
//    set of Observable state (profile, accounts, income/deductions, scenario
//    state, growth rates, legacy planning). Rather than enumerate per-property
//    dependency lists — fragile and bug-prone given how deep
//    `scenarioGrossIncome` reaches — we hash one comprehensive snapshot
//    (`engineInputsHash`) and use it for every property. Any input change
//    invalidates all cached values. False positives (over-invalidation) only
//    cost performance; false negatives (stale reads) cause silent bugs.
//    Erring on the side of correctness here is the right call.
//

import Foundation

/// Holds memoized values for hot DataManager computed properties. One slot
/// per property; each slot stores an inputs hash plus the cached value.
/// Slots are nil-initialized and reset by `reset()`.
final class EngineMemoCache {
    struct Entry<V> {
        let inputsHash: Int
        let value: V
    }

    var legacyHeirTaxEstimate: Entry<TaxCalculationEngine.HeirTaxEstimate>?
    var convertNowVsHeirComparison: Entry<TaxCalculationEngine.HeirBracketComparison>?
    var seniorBonusDeductionAmount: Entry<Double>?
    var scenarioRetirementDistributionIncome: Entry<Double>?
    var scenarioStateTax: Entry<Double>?
    var scenarioFederalTax: Entry<Double>?
    var baselineACAMagi: Entry<ACAMAGI>?
    var ltcg0PercentHeadroom: Entry<Double>?

    func reset() {
        legacyHeirTaxEstimate = nil
        convertNowVsHeirComparison = nil
        seniorBonusDeductionAmount = nil
        scenarioRetirementDistributionIncome = nil
        scenarioStateTax = nil
        scenarioFederalTax = nil
        baselineACAMagi = nil
        ltcg0PercentHeadroom = nil
    }
}

extension DataManager {

    // MARK: - Comprehensive Inputs Hash
    //
    // Hashes a snapshot of every Observable source-of-truth that any of the 8
    // memoized properties could possibly depend on, transitively. Anything not
    // hashed here MUST be a derived/computed value (i.e. itself a pure function
    // of state already hashed), otherwise the cache will return stale results
    // when that input changes. When in doubt, add it.
    //
    // The hash is cheap (Swift's Hasher is well-optimized for these primitives);
    // we recompute it on every memoized property read. For the Scenarios-tab
    // hang scenario, even doing this 50+ times in a single layout pass is
    // dramatically cheaper than re-running the underlying engine pipelines.

    var engineInputsHash: Int {
        var h = Hasher()

        // ProfileManager
        h.combine(profile.birthDate)
        h.combine(profile.spouseBirthDate)
        h.combine(profile.currentYear)
        h.combine(profile.planYear)
        h.combine(profile.filingStatus)
        h.combine(profile.selectedState)
        h.combine(profile.enableSpouse)
        h.combine(profile.plannedMedicareStartAge)
        h.combine(profile.hasQualifiedEmployerCoverageForMedicare)

        // AccountsManager (full account list — balance, type, owner, inherited fields all affect engine output)
        h.combine(accounts.iraAccounts.count)
        for account in accounts.iraAccounts {
            h.combine(account.id)
            h.combine(account.accountType)
            h.combine(account.balance)
            h.combine(account.owner)
            h.combine(account.beneficiaryType)
            h.combine(account.decedentRBDStatus)
            h.combine(account.yearOfInheritance)
            h.combine(account.decedentBirthYear)
            h.combine(account.beneficiaryBirthYear)
            h.combine(account.minorChildMajorityYear)
        }

        // IncomeDeductionsManager
        h.combine(incomeDeductions.incomeSources.count)
        for source in incomeDeductions.incomeSources {
            h.combine(source.id)
            h.combine(source.type)
            h.combine(source.annualAmount)
            h.combine(source.federalWithholding)
            h.combine(source.stateWithholding)
            h.combine(source.owner)
            h.combine(source.ssWithholdingRate)
            h.combine(source.federalWithholdingMode)
            h.combine(source.federalWithholdingPercent)
        }
        h.combine(incomeDeductions.deductionItems.count)
        for item in incomeDeductions.deductionItems {
            h.combine(item.id)
            h.combine(item.type)
            h.combine(item.annualAmount)
            h.combine(item.owner)
        }
        h.combine(incomeDeductions.priorYearStateBalance)
        h.combine(incomeDeductions.priorYearFederalTax)
        h.combine(incomeDeductions.priorYearStateTax)
        h.combine(incomeDeductions.priorYearAGI)

        // ScenarioStateManager
        h.combine(scenario.yourRothConversion)
        h.combine(scenario.spouseRothConversion)
        h.combine(scenario.yourExtraWithdrawal)
        h.combine(scenario.spouseExtraWithdrawal)
        h.combine(scenario.yourQCDAmount)
        h.combine(scenario.spouseQCDAmount)
        h.combine(scenario.yourWithdrawalQuarter)
        h.combine(scenario.spouseWithdrawalQuarter)
        h.combine(scenario.yourRothConversionQuarter)
        h.combine(scenario.spouseRothConversionQuarter)
        h.combine(scenario.stockDonationEnabled)
        h.combine(scenario.stockPurchasePrice)
        h.combine(scenario.stockCurrentValue)
        h.combine(scenario.stockPurchaseDate)
        h.combine(scenario.cashDonationAmount)
        h.combine(scenario.inheritedExtraWithdrawals.count)
        for (k, v) in scenario.inheritedExtraWithdrawals {
            h.combine(k)
            h.combine(v)
        }
        h.combine(scenario.deductionOverride)
        h.combine(scenario.yourTraditional401kContribution)
        h.combine(scenario.spouseTraditional401kContribution)
        h.combine(scenario.yourTraditionalIRAContribution)
        h.combine(scenario.spouseTraditionalIRAContribution)
        h.combine(scenario.yourHSAContribution)
        h.combine(scenario.spouseHSAContribution)
        h.combine(scenario.yourOtherPreTaxDeductions)
        h.combine(scenario.spouseOtherPreTaxDeductions)
        h.combine(scenario.yourMedicarePlanType)
        h.combine(scenario.spouseMedicarePlanType)
        h.combine(scenario.yourMedicarePartBOverride)
        h.combine(scenario.spouseMedicarePartBOverride)
        h.combine(scenario.yourMedicarePartDOverride)
        h.combine(scenario.spouseMedicarePartDOverride)
        h.combine(scenario.yourMedigapOverride)
        h.combine(scenario.spouseMedigapOverride)
        h.combine(scenario.yourAdvantageOverride)
        h.combine(scenario.spouseAdvantageOverride)
        h.combine(scenario.enableACAModeling)
        h.combine(scenario.acaHouseholdSize)
        h.combine(scenario.acaBenchmarkSilverPlanMonthlyOverride)

        // GrowthRatesManager
        h.combine(growthRates.primaryGrowthRate)
        h.combine(growthRates.spouseGrowthRate)

        // LegacyPlanningManager
        h.combine(legacy.enableLegacyPlanning)
        h.combine(legacy.legacyHeirType)
        h.combine(legacy.legacyHeirEstimatedSalary)
        h.combine(legacy.legacyHeirFilingStatus)
        h.combine(legacy.legacyHeirBirthYear)
        h.combine(legacy.legacySpouseSurvivorYears)
        h.combine(legacy.legacyGrowthRate)

        // DataManager-owned Observable state
        h.combine(safeHarborMethod)

        return h.finalize()
    }

    // MARK: - Memoized Property Accessors
    //
    // Each helper checks the cache slot against the current engineInputsHash.
    // On hit, returns the cached value. On miss, invokes the supplied compute
    // closure, stores the result, and returns it.

    func memoizedLegacyHeirTaxEstimate(_ compute: () -> TaxCalculationEngine.HeirTaxEstimate) -> TaxCalculationEngine.HeirTaxEstimate {
        let hash = engineInputsHash
        if let entry = memoCache.legacyHeirTaxEstimate, entry.inputsHash == hash {
            return entry.value
        }
        let value = compute()
        memoCache.legacyHeirTaxEstimate = .init(inputsHash: hash, value: value)
        return value
    }

    func memoizedConvertNowVsHeirComparison(_ compute: () -> TaxCalculationEngine.HeirBracketComparison) -> TaxCalculationEngine.HeirBracketComparison {
        let hash = engineInputsHash
        if let entry = memoCache.convertNowVsHeirComparison, entry.inputsHash == hash {
            return entry.value
        }
        let value = compute()
        memoCache.convertNowVsHeirComparison = .init(inputsHash: hash, value: value)
        return value
    }

    func memoizedSeniorBonusDeductionAmount(_ compute: () -> Double) -> Double {
        let hash = engineInputsHash
        if let entry = memoCache.seniorBonusDeductionAmount, entry.inputsHash == hash {
            return entry.value
        }
        let value = compute()
        memoCache.seniorBonusDeductionAmount = .init(inputsHash: hash, value: value)
        return value
    }

    func memoizedScenarioRetirementDistributionIncome(_ compute: () -> Double) -> Double {
        let hash = engineInputsHash
        if let entry = memoCache.scenarioRetirementDistributionIncome, entry.inputsHash == hash {
            return entry.value
        }
        let value = compute()
        memoCache.scenarioRetirementDistributionIncome = .init(inputsHash: hash, value: value)
        return value
    }

    func memoizedScenarioStateTax(_ compute: () -> Double) -> Double {
        let hash = engineInputsHash
        if let entry = memoCache.scenarioStateTax, entry.inputsHash == hash {
            return entry.value
        }
        let value = compute()
        memoCache.scenarioStateTax = .init(inputsHash: hash, value: value)
        return value
    }

    func memoizedScenarioFederalTax(_ compute: () -> Double) -> Double {
        let hash = engineInputsHash
        if let entry = memoCache.scenarioFederalTax, entry.inputsHash == hash {
            return entry.value
        }
        let value = compute()
        memoCache.scenarioFederalTax = .init(inputsHash: hash, value: value)
        return value
    }

    func memoizedBaselineACAMagi(_ compute: () -> ACAMAGI) -> ACAMAGI {
        let hash = engineInputsHash
        if let entry = memoCache.baselineACAMagi, entry.inputsHash == hash {
            return entry.value
        }
        let value = compute()
        memoCache.baselineACAMagi = .init(inputsHash: hash, value: value)
        return value
    }

    func memoizedLTCG0PercentHeadroom(_ compute: () -> Double) -> Double {
        let hash = engineInputsHash
        if let entry = memoCache.ltcg0PercentHeadroom, entry.inputsHash == hash {
            return entry.value
        }
        let value = compute()
        memoCache.ltcg0PercentHeadroom = .init(inputsHash: hash, value: value)
        return value
    }
}
