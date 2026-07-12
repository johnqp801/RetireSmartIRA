//
//  MultiYearItemizedDeduction.swift
//  RetireSmartIRA
//
//  Task 3 (V2.1.1 multi-year cash-charitable itemizing): a pure, dependency-free
//  replica of the single-year itemized-deduction rules, for the multi-year
//  ProjectionEngine to choose standard-vs-itemized per year. Cash-only charitable
//  (no stock/appreciated-property); no carryforward; no AMT.
//
//  Mirrors (single-year reference, DataManager.swift):
//    - saltCap                          -> DataManager.saltCap (~:1723)
//    - deductibleMedical                -> DataManager.deductibleMedicalExpenses (~:1647)
//    - deductibleCharitableCash         -> DataManager.deductibleCharitableDeductions /
//                                           ceilingLimitedCharitable / charitableAGIFloor (~:1860-1894, cash-only)
//    - itemizedTotal's §68 reduction     -> DataManager.itemizedOverallLimitationReduction (~:1938)
//    - nonItemizerCashCharitable         -> DataManager.nonItemizerCharitableDeduction (~:1987)
//
//  All year-dependent constants come from the passed TaxYearConfig (never hardcoded here),
//  so this stays valid across tax years as configs change. Guarded by a parity test (Task 7)
//  asserting agreement with the single-year DataManager computed vars.
//
//  AGI-basis note: the single `agi` argument is NET of above-the-line deductions (the engine
//  passes `federalAGI`, satisfying §68's `incomeBeforeItemized` contract). Single-year is itself
//  internally inconsistent — its charitable ceiling/floor and §68 use NET (federalAGI.value),
//  but its medical floor and SALT-cap phaseout use GROSS (scenarioGrossIncome). This helper uses
//  NET for all four. The two agree exactly whenever above-the-line deductions are 0 (the retiree
//  target case, which the parity test pins); they diverge slightly only for working households with
//  401k/HSA/trad-IRA contributions AND MAGI above the SALT-phaseout threshold. See the 2026-07-12
//  session memo for the tracked follow-up (align the medical-floor/SALT-cap calls to gross if that
//  population matters).
//
import Foundation

enum MultiYearItemizedDeduction {

    /// OBBBA SALT cap for the year (expanded base x inflation, MAGI phaseout, floor; else default).
    /// Mirrors DataManager.saltCap exactly, but takes `year`/`magi` as explicit scalars instead of
    /// reading `currentYear` / `scenarioGrossIncome` off a live DataManager.
    static func saltCap(year: Int, magi: Double, config cfg: TaxYearConfig) -> Double {
        guard year >= cfg.saltExpandedFirstYear && year <= cfg.saltExpandedLastYear else {
            return cfg.saltDefaultCap
        }
        let yearsFromBase = Double(year - cfg.saltBaseYear)
        let inflationMultiplier = pow(1.0 + cfg.saltInflationRate, yearsFromBase)
        let expandedCap = (cfg.saltBaseCap * inflationMultiplier).rounded()

        let phaseoutThreshold = (cfg.saltPhaseoutBaseThreshold * inflationMultiplier).rounded()
        let phaseoutReduction = max(0, (magi.rounded() - phaseoutThreshold) * cfg.saltPhaseoutRate)
        let afterPhaseout = expandedCap - phaseoutReduction

        return max(cfg.saltFloor, afterPhaseout)
    }

    /// Deductible medical expenses: only the portion of gross medical expenses exceeding
    /// `medicalAGIFloorRate` of AGI. Mirrors DataManager.deductibleMedicalExpenses.
    static func deductibleMedical(gross: Double, agi: Double, config cfg: TaxYearConfig) -> Double {
        let floor = max(0, agi) * cfg.medicalAGIFloorRate
        return max(0, gross - floor)
    }

    /// Cash charitable contributions after the 60%-of-AGI ceiling, then the OBBBA 0.5%-of-AGI
    /// floor (2026+). Cash-only: mirrors the `cashDonationAmount`-only portion of
    /// DataManager.ceilingLimitedCharitable / charitableAGIFloor / deductibleCharitableDeductions
    /// (the long-term-appreciated-stock 30% bucket is out of scope here).
    static func deductibleCharitableCash(cash: Double, agi: Double, year: Int, config cfg: TaxYearConfig) -> Double {
        let a = max(0, agi)
        let ceilingLimited = min(max(0, cash), cfg.charitableCashAGICeilingRate * a)
        let floor = year >= cfg.itemizedCharitableAGIFloorFirstYear ? cfg.itemizedCharitableAGIFloorRate * a : 0
        return max(0, ceilingLimited - floor)
    }

    /// OBBBA §170(p) below-the-line cash-charitable deduction available to filers who take the
    /// standard deduction (permanent, tax years beginning after 2025). Mirrors
    /// DataManager.nonItemizerCharitableDeduction, minus the `scenarioEffectiveItemize` gate
    /// (the multi-year engine decides standard-vs-itemized itself and calls this only on the
    /// standard-deduction path).
    static func nonItemizerCashCharitable(cash: Double, filingStatus: FilingStatus, year: Int, config cfg: TaxYearConfig) -> Double {
        guard year >= cfg.nonItemizerCashCharitableFirstYear else { return 0 }
        let cap = filingStatus == .marriedFilingJointly ? cfg.nonItemizerCashCharitableCapMFJ : cfg.nonItemizerCashCharitableCapSingle
        return min(max(0, cash), cap)
    }

    /// Effective itemized total for the year (after the OBBBA §68 overall limitation).
    /// `agi` here plays the role of DataManager's `incomeBeforeItemized` (taxable income before
    /// the itemized deduction) for the §68 excess computation — the caller is expected to pass
    /// AGI net of above-the-line deductions, matching the single-year reference.
    /// `seniorBonus` is accepted as an input because it applies to the itemized total on both
    /// paths in the single-year model; the caller computes it once and passes it through.
    static func itemizedTotal(
        stateIncomeTax: Double, otherSALT: Double, mortgageAndOther: Double,
        grossMedical: Double, cashCharitable: Double, seniorBonus: Double,
        agi: Double, filingStatus: FilingStatus, year: Int, config cfg: TaxYearConfig
    ) -> Double {
        let saltBeforeCap = max(0, stateIncomeTax) + max(0, otherSALT)
        let salt = min(saltBeforeCap, saltCap(year: year, magi: agi, config: cfg))
        let medical = deductibleMedical(gross: grossMedical, agi: agi, config: cfg)
        let charitable = deductibleCharitableCash(cash: cashCharitable, agi: agi, year: year, config: cfg)
        let beforeLimit = salt + max(0, mortgageAndOther) + medical + charitable + max(0, seniorBonus)

        guard year >= cfg.itemizedOverallLimitationFirstYear else { return beforeLimit }
        let brackets = filingStatus == .marriedFilingJointly ? cfg.federalBracketsMFJ : cfg.federalBracketsSingle
        let topOrdinaryBracketThreshold = brackets.map(\.threshold).max() ?? 0
        let excess = max(0, agi - topOrdinaryBracketThreshold)
        let reduction = cfg.itemizedOverallLimitationRate * min(beforeLimit, excess)
        return max(0, beforeLimit - reduction)
    }
}
