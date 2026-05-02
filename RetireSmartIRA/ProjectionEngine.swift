//
//  ProjectionEngine.swift
//  RetireSmartIRA
//
//  Pure-calculation engine that projects retirement years forward given a sequence
//  of LeverAction inputs. Returns one YearRecommendation per year in sorted order.
//
//  Order of operations within each year:
//    1. Apply explicit LeverAction inputs (Roth conversions, withdrawals, contributions)
//    2. Compute SS income for the year
//    3. Auto-impose RMD trad withdrawal (NEW — v2.0 Phase 1)
//    4. Auto-fund living expenses from accounts per withdrawalOrderingRule
//    5. Apply investment growth to all remaining balances
//    6. Compute AGI, taxable SS, MAGI variants, and tax breakdown
//
//  RMD modeling (v2.0 Phase 1):
//    RMD age depends on birth year per SECURE / SECURE 2.0:
//      birthYear < 1951  → rmdAge = 72 (pre-SECURE)
//      1951 ≤ birthYear ≤ 1959 → rmdAge = 73 (SECURE 1.0)
//      birthYear ≥ 1960  → rmdAge = 75 (SECURE 2.0)
//
//    When primaryAge >= rmdAge, the engine computes the IRS-required RMD using
//    RMDCalculationEngine.calculateRMD(for:balance:) on the post-explicit-action
//    trad balance. If the user's explicit traditionalWithdrawal actions already
//    total >= RMD, no additional withdrawal is imposed. Otherwise, the shortfall
//    is auto-imposed and added to AGI.
//
//    Excess-RMD handling (Approach A, v2.0 simplification):
//    If the RMD exceeds the year's expense need, the gross excess is deposited to
//    the taxable bucket. Tax is computed on the full AGI (including the entire RMD).
//    This slightly overstates available after-tax wealth because the deposited amount
//    is pre-tax; effective rate ~15-20% × small residual = minor distortion. Will be
//    corrected in v2.1 per-spouse trad-balance tracking.
//
//    Couples simplification: applies primary's RMD age to the total trad balance.
//    In years where the primary is past RMD age but the spouse is not, this overstates
//    RMDs slightly (assumes all trad belongs to the older spouse). Revisit in v2.1.
//
//  Design note: ProjectionEngine does NOT optimize — that is OptimizationEngine's job
//  (Task 1.9). This engine takes actions as inputs and produces results.
//
//  COLA note: SSCalculationEngine.effectiveMonthlyBenefitSingle returns the benefit
//  at the original claim year WITHOUT COLA adjustment, per the 2026-05-02 SS module
//  audit. ProjectionEngine applies COLA compounding here using assumptions.cpiRate.
//
//  Base year: derived from Calendar.current.component(.year, from: Date()) since
//  MultiYearStaticInputs does not carry a base year field.
//
//  API wiring used (per Phase 0 discovery):
//    - Federal tax: TaxCalculationEngine.calculateFederalTax(income:filingStatus:brackets:preferentialIncome:)
//      with TaxCalculationEngine.default2026Brackets and preferentialIncome:0
//    - State tax: TaxCalculationEngine.calculateStateTax(income:forState:filingStatus:taxableSocialSecurity:
//      incomeSources:currentAge:enableSpouse:spouseBirthYear:currentYear:)
//    - IRMAA cost: TaxCalculationEngine.calculateIRMAA(magi:Double,filingStatus:) → IRMAAResult.annualSurchargePerPerson
//    - ACA subsidy: ACASubsidyEngine.calculateSubsidy(acaMAGI:householdSize:benchmarkSilverPlanAnnualPremium:config:)
//      → ACASubsidyResult.annualPremiumAssistance; acaPremiumImpact = -annualPremiumAssistance (negative = savings)
//    - SS benefit: SSCalculationEngine.effectiveMonthlyBenefitSingle; COLA = cpiRate^yearsSinceClaim applied here
//    - Taxable SS: TaxCalculationEngine.calculateTaxableSocialSecurity(filingStatus:additionalIncome:incomeSources:)
//      with SS wrapped in an IncomeSource(.socialSecurity) and other income as additionalIncome
//    - Standard deduction: derived directly from TaxCalculationEngine.config fields
//      (standardDeductionSingle/MFJ + additionalDeduction65Single/MFJ)
//    - RMD: RMDCalculationEngine.calculateRMD(for:balance:) — delegates to IRS Uniform Lifetime Table III
//

import Foundation

struct ProjectionEngine {

    init() {}

    /// Project the scenario forward for each year in `actionsPerYear` (sorted ascending).
    /// Returns one `YearRecommendation` per year.
    func project(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions,
        actionsPerYear: [Int: [LeverAction]]
    ) -> [YearRecommendation] {
        // Base year is the current calendar year (MultiYearStaticInputs has no base year field).
        let scenarioBaseYear = Calendar.current.component(.year, from: Date())

        let sortedYears = actionsPerYear.keys.sorted()
        guard !sortedYears.isEmpty else { return [] }

        // Mutable state that evolves year-over-year
        var trad = inputs.startingBalances.traditional
        var roth = inputs.startingBalances.roth
        var taxable = inputs.startingBalances.taxable
        var hsa = inputs.startingBalances.hsa
        var primaryAge = inputs.primaryCurrentAge
        var spouseAge = inputs.spouseCurrentAge

        // Resolve state once — default to .california if abbreviation lookup fails
        let usState: USState = USState.allCases.first { $0.abbreviation == inputs.state } ?? .california

        var results: [YearRecommendation] = []

        for year in sortedYears {
            let actions = actionsPerYear[year] ?? []

            // ─────────────────────────────────────────
            // Step 1: Apply explicit LeverActions
            // ─────────────────────────────────────────
            // Track income events for AGI computation
            var explicitTradWithdrawals = 0.0   // add to AGI
            var explicitRothConversions = 0.0   // add to AGI
            var aboveTheLineDeductions = 0.0    // HSA + pre-tax 401k contributions; reduces AGI

            for action in actions {
                switch action {
                case .rothConversion(let amount):
                    trad -= amount
                    roth += amount
                    explicitRothConversions += amount

                case .traditionalWithdrawal(let amount):
                    trad -= amount
                    explicitTradWithdrawals += amount

                case .taxableWithdrawal(let amount):
                    taxable -= amount
                    // Zero-gain approximation: no AGI impact in v2.0 (cost-basis tracking deferred to v2.1)

                case .rothWithdrawal(let amount):
                    roth -= amount
                    // Qualified Roth withdrawals: no AGI impact

                case .hsaContribution(let amount):
                    taxable -= amount
                    hsa += amount
                    aboveTheLineDeductions += amount

                case .fourOhOneKContribution(let amount):
                    trad += amount
                    taxable -= amount
                    // Pre-tax 401k contribution: reduces AGI (treated like HSA as above-the-line deduction)
                    aboveTheLineDeductions += amount

                case .deferSocialSecurity:
                    break   // marker only — no balance change

                case .claimSocialSecurity:
                    break   // marker only — no balance change
                }
            }

            // ─────────────────────────────────────────
            // Step 2: Compute SS income for this year
            // ─────────────────────────────────────────
            // Per SS audit: effectiveMonthlyBenefitSingle returns claim-year value (no COLA).
            // We apply COLA here as: benefit * (1 + cpiRate)^yearsSinceClaim.
            //
            // KNOWN v2.0 LIMITATION (tracked for Task 1.12 / SSClaimNudge):
            // For MFJ couples we compute each spouse's benefit independently via
            // effectiveMonthlyBenefitSingle. The corrections doc called for the couples-
            // aware effectiveMonthlyBenefit, which models the spousal-top-up rule (up to
            // 50% of higher earner's PIA at FRA when the other spouse has filed). For
            // couples with very asymmetric PIAs, the current path under-counts SS income
            // and the SSClaimNudge lifetime-tax delta math will be slightly off. Acceptable
            // simplification for v2.0 since spousal top-up is most material for one-low-
            // earner couples and the optimizer doesn't ride that effect aggressively. Fix
            // before Task 1.12 ships if reference scenarios show meaningful drift.
            let primaryGrossSSAnnual = computeSSAnnual(
                pia: inputs.primaryExpectedBenefitAtFRA,
                birthYear: inputs.primaryBirthYear,
                claimAge: inputs.primarySSClaimAge,
                cpiRate: assumptions.cpiRate,
                projectionYear: year,
                scenarioBaseYear: scenarioBaseYear
            )

            let spouseGrossSSAnnual: Double = {
                guard let spousePIA = inputs.spouseExpectedBenefitAtFRA,
                      let spouseClaimAge = inputs.spouseSSClaimAge,
                      let spouseBY = inputs.spouseBirthYear else { return 0 }
                return computeSSAnnual(
                    pia: spousePIA,
                    birthYear: spouseBY,
                    claimAge: spouseClaimAge,
                    cpiRate: assumptions.cpiRate,
                    projectionYear: year,
                    scenarioBaseYear: scenarioBaseYear
                )
            }()

            let totalGrossSSAnnual = primaryGrossSSAnnual + spouseGrossSSAnnual

            // ─────────────────────────────────────────
            // Step 3: Auto-impose RMD trad withdrawal
            // ─────────────────────────────────────────
            // RMD is computed from post-explicit-action trad balance. If the user's explicit
            // traditionalWithdrawal actions already total >= RMD, the RMD is satisfied and
            // nothing extra is imposed. Otherwise the shortfall is auto-imposed.
            //
            // Excess-RMD: if RMD > (expenses - passiveIncome), the gross excess is deposited
            // to the taxable bucket (Approach A). Tax is computed on the full AGI including the
            // entire RMD. Minor distortion accepted for v2.0.
            var autoImposedRMD = 0.0

            let primaryRMDAge = rmdAge(birthYear: inputs.primaryBirthYear)
            if primaryAge >= primaryRMDAge && trad > 0 {
                let requiredRMD = RMDCalculationEngine.calculateRMD(for: primaryAge, balance: trad)
                let rmdGap = max(0, requiredRMD - explicitTradWithdrawals)
                if rmdGap > 0 {
                    let withdrawal = min(rmdGap, trad)
                    trad -= withdrawal
                    autoImposedRMD = withdrawal
                }
            }

            // ─────────────────────────────────────────
            // Step 4: Compute expenses and auto-funding
            // ─────────────────────────────────────────
            let annualExpenses: Double = {
                if let override = assumptions.perYearExpenseOverrides[year] {
                    return override
                }
                return inputs.baselineAnnualExpenses
            }()

            let wageIncome = inputs.primaryWageIncome + inputs.spouseWageIncome
            let pensionIncome = inputs.primaryPensionIncome + inputs.spousePensionIncome
            let passiveIncome = wageIncome + pensionIncome + totalGrossSSAnnual

            var autoFundedTradWithdrawals = 0.0
            // RMD cash already extracted from trad; subtract from shortfall before auto-funding.
            // If RMD exceeds the full expense need, the gross excess is deposited to taxable (Approach A).
            let rmdCashAvailable = autoImposedRMD + explicitTradWithdrawals  // total trad drawn so far
            let expenseShortfallBeforeRMD = max(0, annualExpenses - passiveIncome)
            let expenseShortfall = max(0, expenseShortfallBeforeRMD - rmdCashAvailable)

            // Deposit gross excess RMD (above expense need) to taxable bucket
            let rmdExcess = max(0, rmdCashAvailable - expenseShortfallBeforeRMD)
            taxable += rmdExcess

            if expenseShortfall > 0 {
                let (tradWD, remaining) = autoFundExpenses(
                    shortfall: expenseShortfall,
                    trad: &trad,
                    taxableBalance: &taxable,
                    roth: &roth,
                    rule: assumptions.withdrawalOrderingRule
                )
                autoFundedTradWithdrawals = tradWD
                _ = remaining  // v2.0: assume solvent, ignore any residual
            }

            let totalTradWithdrawals = explicitTradWithdrawals + autoImposedRMD + autoFundedTradWithdrawals

            // ─────────────────────────────────────────
            // Step 5: Apply growth to remaining balances
            // ─────────────────────────────────────────
            let growthFactor = 1.0 + assumptions.investmentGrowthRate
            trad *= growthFactor
            roth *= growthFactor
            taxable *= growthFactor
            hsa *= growthFactor

            // ─────────────────────────────────────────
            // Step 6: Compute AGI and tax breakdown
            // ─────────────────────────────────────────

            // Taxable SS via provisional income formula.
            // We pass SS as an IncomeSource(.socialSecurity) and other income as additionalIncome.
            let ssIncomeSource = IncomeSource(
                name: "Social Security",
                type: .socialSecurity,
                annualAmount: totalGrossSSAnnual
            )
            let otherIncomeForSSTax = pensionIncome + wageIncome
                + totalTradWithdrawals + explicitRothConversions
            let taxableSS = TaxCalculationEngine.calculateTaxableSocialSecurity(
                filingStatus: inputs.filingStatus,
                additionalIncome: otherIncomeForSSTax,
                incomeSources: [ssIncomeSource]
            )

            // Federal AGI
            // = pension + wage + traditional withdrawals (explicit + auto-funded)
            //   + Roth conversions + taxable SS
            //   - above-the-line deductions (HSA contribution, 401k contribution)
            let federalAGI = max(0,
                pensionIncome
                + wageIncome
                + totalTradWithdrawals
                + explicitRothConversions
                + taxableSS
                - aboveTheLineDeductions
            )

            // ACA MAGI = federalAGI + tax-exempt interest + non-taxable SS
            // non-taxable SS = grossSS - taxableSS; tax-exempt interest = 0 for v2.0
            let nonTaxableSS = max(0, totalGrossSSAnnual - taxableSS)
            let magiAddback = nonTaxableSS  // tax-exempt interest = 0 in v2.0

            // ACA MAGI: relevant only when primary is pre-Medicare (age < 65)
            let acaMagiValue: Double? = primaryAge < 65
                ? federalAGI + magiAddback
                : nil

            // IRMAA MAGI: relevant from age 63 (2-year lookback window for Medicare)
            let irmaaMagiValue: Double? = primaryAge >= 63
                ? federalAGI + magiAddback
                : nil

            // Standard deduction — derived from TaxCalculationEngine.config
            let stdDed = standardDeduction(
                filingStatus: inputs.filingStatus,
                primaryAge: primaryAge,
                spouseAge: spouseAge,
                year: year,
                federalAGI: federalAGI
            )
            let taxableIncome = max(0, federalAGI - stdDed)

            // Federal tax (ordinary income only; no cap gains modeling in v2.0)
            let brackets = TaxCalculationEngine.default2026Brackets
            let federalTax = TaxCalculationEngine.calculateFederalTax(
                income: taxableIncome,
                filingStatus: inputs.filingStatus,
                brackets: brackets,
                preferentialIncome: 0
            )

            // State tax — build minimal income source list for retirement exemptions
            let stateTax = computeStateTax(
                federalAGI: federalAGI,
                taxableSS: taxableSS,
                pensionIncome: pensionIncome,
                totalTradWithdrawals: totalTradWithdrawals,
                filingStatus: inputs.filingStatus,
                usState: usState,
                primaryAge: primaryAge,
                spouseBirthYear: inputs.spouseBirthYear,
                year: year
            )

            // IRMAA surcharge (annual, per person)
            let irmaaCost: Double = {
                guard let irmaaMagi = irmaaMagiValue, primaryAge >= 65 else { return 0 }
                let result = TaxCalculationEngine.calculateIRMAA(
                    magi: irmaaMagi,
                    filingStatus: inputs.filingStatus
                )
                return result.annualSurchargePerPerson
            }()

            // ACA premium impact (negative = subsidy savings)
            let acaPremiumImpact: Double = {
                guard primaryAge < 65, inputs.acaEnrolled, let acaMagi = acaMagiValue else { return 0 }
                let taxConfig = TaxCalculationEngine.config
                let result = ACASubsidyEngine.calculateSubsidy(
                    acaMAGI: ACAMAGI(value: acaMagi),
                    householdSize: inputs.acaHouseholdSize,
                    benchmarkSilverPlanAnnualPremium: taxConfig.acaSubsidy2026.nationalAvgBenchmarkSilverPlanAnnual,
                    config: taxConfig
                )
                return -result.annualPremiumAssistance  // negative = savings to household
            }()

            let taxBreakdown = TaxBreakdown(
                federal: federalTax,
                state: stateTax,
                irmaa: irmaaCost,
                acaPremiumImpact: acaPremiumImpact
            )

            let snapshot = AccountSnapshot(
                traditional: max(0, trad),
                roth: max(0, roth),
                taxable: max(0, taxable),
                hsa: max(0, hsa)
            )

            // Build the combined actions list: explicit user actions + auto-imposed RMD (if any).
            // This lets callers inspect the full picture of what actually happened in the year,
            // including auto-imposed RMD trad withdrawals.
            var allActions = actions
            if autoImposedRMD > 0 {
                allActions.append(.traditionalWithdrawal(amount: autoImposedRMD))
            }

            results.append(YearRecommendation(
                year: year,
                agi: federalAGI,
                acaMagi: acaMagiValue,
                irmaaMagi: irmaaMagiValue,
                taxableIncome: taxableIncome,
                taxBreakdown: taxBreakdown,
                endOfYearBalances: snapshot,
                actions: allActions
            ))

            // Advance ages for next iteration
            primaryAge += 1
            if spouseAge != nil { spouseAge! += 1 }
        }

        return results
    }

    // MARK: - Private helpers

    /// Compute gross annual SS income for a person, with COLA applied for years after the claim year.
    ///
    /// COLA note: SSCalculationEngine.effectiveMonthlyBenefitSingle returns the benefit at
    /// the original claim year value (no COLA). COLA is applied here as:
    ///   annualBenefit * (1 + cpiRate)^max(0, projectionYear - claimYear)
    /// where claimYear = scenarioBaseYear + (claimAge - currentAgeAtBaseYear).
    private func computeSSAnnual(
        pia: Double,
        birthYear: Int,
        claimAge: Int,
        cpiRate: Double,
        projectionYear: Int,
        scenarioBaseYear: Int
    ) -> Double {
        let result = SSCalculationEngine.effectiveMonthlyBenefitSingle(
            personPIA: pia,
            personBirthYear: birthYear,
            personClaimingAge: claimAge,
            personClaimingMonth: 0,
            personIsAlreadyClaiming: false,
            personCurrentBenefit: 0,
            forYear: projectionYear
        )

        guard result.isCollecting else { return 0 }

        // Compute claim year: the year the person first reaches their claiming age
        let currentAgeAtBaseYear = scenarioBaseYear - birthYear
        let claimYear = scenarioBaseYear + (claimAge - currentAgeAtBaseYear)
        let yearsSinceClaim = max(0, projectionYear - claimYear)
        let colaFactor = pow(1.0 + cpiRate, Double(yearsSinceClaim))

        return result.monthly * 12.0 * colaFactor
    }

    /// Auto-fund the expense shortfall from account buckets per the withdrawal ordering rule.
    /// Returns (totalTradWithdrawn, remainingShortfall).
    /// Mutates trad, taxable, and roth directly.
    private func autoFundExpenses(
        shortfall: Double,
        trad: inout Double,
        taxableBalance: inout Double,
        roth: inout Double,
        rule: WithdrawalOrderingRule
    ) -> (tradWithdrawn: Double, remaining: Double) {
        var remaining = shortfall
        var tradWithdrawn = 0.0

        switch rule {
        case .taxEfficient, .preserveRoth:
            // Order: taxable → traditional → roth
            let fromTaxable = min(remaining, max(0, taxableBalance))
            taxableBalance -= fromTaxable
            remaining -= fromTaxable

            let fromTrad = min(remaining, max(0, trad))
            trad -= fromTrad
            tradWithdrawn += fromTrad
            remaining -= fromTrad

            let fromRoth = min(remaining, max(0, roth))
            roth -= fromRoth
            remaining -= fromRoth

        case .depleteTradFirst:
            // Order: traditional → taxable → roth
            let fromTrad = min(remaining, max(0, trad))
            trad -= fromTrad
            tradWithdrawn += fromTrad
            remaining -= fromTrad

            let fromTaxable = min(remaining, max(0, taxableBalance))
            taxableBalance -= fromTaxable
            remaining -= fromTaxable

            let fromRoth = min(remaining, max(0, roth))
            roth -= fromRoth
            remaining -= fromRoth

        case .proportional:
            // Split proportionally between trad and taxable buckets (weighted by current
            // bucket size). HSA is intentionally excluded from auto-funding because it's
            // restricted-use (qualified medical expenses); auto-funding general living
            // expenses from HSA would mischaracterize withdrawals as taxable. Roth is the
            // last-resort fallback if both trad and taxable are exhausted.
            let total = max(1, trad + taxableBalance)
            let tradFrac = trad / total
            let taxableFrac = taxableBalance / total

            let fromTrad = min(remaining * tradFrac, max(0, trad))
            let fromTaxable = min(remaining * taxableFrac, max(0, taxableBalance))
            trad -= fromTrad
            taxableBalance -= fromTaxable
            tradWithdrawn += fromTrad
            remaining -= (fromTrad + fromTaxable)

            // If still short, try Roth last
            let fromRoth = min(remaining, max(0, roth))
            roth -= fromRoth
            remaining -= fromRoth
        }

        return (tradWithdrawn, remaining)
    }

    /// Compute the standard deduction from TaxCalculationEngine.config (no DataManager dependency).
    /// Includes the age-65+ additional deduction and OBBBA senior bonus if applicable.
    private func standardDeduction(
        filingStatus: FilingStatus,
        primaryAge: Int,
        spouseAge: Int?,
        year: Int,
        federalAGI: Double
    ) -> Double {
        let cfg = TaxCalculationEngine.config

        var amount: Double
        switch filingStatus {
        case .single:
            amount = cfg.standardDeductionSingle
            if primaryAge >= 65 {
                amount += cfg.additionalDeduction65Single
            }
            // OBBBA Senior Bonus (2025–2028)
            if primaryAge >= 65 && year >= cfg.seniorBonusFirstYear && year <= cfg.seniorBonusLastYear {
                let reduction = max(0, (federalAGI - cfg.seniorBonusPhaseoutSingle) * cfg.seniorBonusPhaseoutRate)
                let bonus = max(0, cfg.seniorBonusPerPerson - reduction)
                amount += bonus
            }

        case .marriedFilingJointly:
            amount = cfg.standardDeductionMFJ
            if primaryAge >= 65 {
                amount += cfg.additionalDeduction65MFJ
            }
            if let sAge = spouseAge, sAge >= 65 {
                amount += cfg.additionalDeduction65MFJ
            }
            // OBBBA Senior Bonus per qualifying senior (2025–2028)
            if year >= cfg.seniorBonusFirstYear && year <= cfg.seniorBonusLastYear {
                var qualifyingSeniors = 0
                if primaryAge >= 65 { qualifyingSeniors += 1 }
                if let sAge = spouseAge, sAge >= 65 { qualifyingSeniors += 1 }
                if qualifyingSeniors > 0 {
                    let totalBonusBase = cfg.seniorBonusPerPerson * Double(qualifyingSeniors)
                    let reduction = max(0, (federalAGI - cfg.seniorBonusPhaseoutMFJ) * cfg.seniorBonusPhaseoutRate)
                    let bonus = max(0, totalBonusBase - reduction)
                    amount += bonus
                }
            }
        }

        return amount
    }

    // MARK: - RMD helpers

    /// Returns the RMD age for a given birth year per SECURE / SECURE 2.0.
    ///   birthYear < 1951  → 72 (pre-SECURE)
    ///   1951 ≤ birthYear ≤ 1959 → 73 (SECURE 1.0)
    ///   birthYear ≥ 1960  → 75 (SECURE 2.0)
    private func rmdAge(birthYear: Int) -> Int {
        if birthYear >= 1960 { return 75 }
        if birthYear >= 1951 { return 73 }
        return 72
    }

    /// Compute state tax using TaxCalculationEngine.calculateStateTax.
    /// Builds minimal IncomeSource list for retirement exemption logic.
    private func computeStateTax(
        federalAGI: Double,
        taxableSS: Double,
        pensionIncome: Double,
        totalTradWithdrawals: Double,
        filingStatus: FilingStatus,
        usState: USState,
        primaryAge: Int,
        spouseBirthYear: Int?,
        year: Int
    ) -> Double {
        // Build a minimal income source list so retirement exemptions can be applied.
        // StateTaxData uses .pension and .rmd types for exemption bucketing.
        var sources: [IncomeSource] = []
        if pensionIncome > 0 {
            sources.append(IncomeSource(
                name: "Pension",
                type: .pension,
                annualAmount: pensionIncome
            ))
        }
        if totalTradWithdrawals > 0 {
            sources.append(IncomeSource(
                name: "IRA/401k Withdrawal",
                type: .rmd,
                annualAmount: totalTradWithdrawals
            ))
        }

        let hasSpouse = spouseBirthYear != nil
        return TaxCalculationEngine.calculateStateTax(
            income: federalAGI,
            forState: usState,
            filingStatus: filingStatus,
            taxableSocialSecurity: taxableSS,
            incomeSources: sources,
            currentAge: primaryAge,
            enableSpouse: hasSpouse,
            spouseBirthYear: spouseBirthYear ?? 0,
            currentYear: year
        )
    }
}
