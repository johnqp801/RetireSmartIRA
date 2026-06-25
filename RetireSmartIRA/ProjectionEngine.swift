//
//  ProjectionEngine.swift
//  RetireSmartIRA
//
//  Pure-calculation engine that projects retirement years forward given a sequence
//  of LeverAction inputs. Returns one YearRecommendation per year in sorted order.
//
//  Order of operations within each year:
//    1. Apply explicit LeverAction inputs (Roth conversions, withdrawals, contributions)
//       Each action is clamped to the source-bucket balance so balances never go negative.
//    2. Compute SS income for the year
//    3. Auto-impose RMD trad withdrawal (v2.0 Phase 1)
//    4. Auto-fund living expenses from accounts per withdrawalOrderingRule
//    5. Apply investment growth to all remaining balances
//    6. Compute AGI, taxable SS, MAGI variants, and tax breakdown
//    7. Debit year's total tax (max(0, taxBreakdown.total)) from the taxable bucket.
//       If taxable is insufficient, debit what's available; remainder is assumed paid
//       from external sources (v2.0 limitation — v2.1 will let users designate source).
//       endOfYearBalances.taxable therefore reflects the realistic post-tax position.
//       This closes the phantom-wealth gap that existed when taxes were computed but
//       never debited (projected wealth was overstated by the cumulative tax bill).
//
//  RMD modeling (v2.0):
//    RMD age depends on birth year per SECURE / SECURE 2.0:
//      birthYear < 1949  → rmdAge = 70 (pre-SECURE; represents 70½, returned as Int)
//      birthYear 1949-1950 → rmdAge = 72 (SECURE Act 1.0 boundary ~July 1, 1949)
//      1951 ≤ birthYear ≤ 1959 → rmdAge = 73 (SECURE Act 1.0)
//      birthYear ≥ 1960  → rmdAge = 75 (SECURE Act 2.0)
//
//    Per IRS Pub 590-B, RMDs are calculated using the prior-year-end balance, which
//    equals the start of the current year's loop iteration — BEFORE any explicit Roth
//    conversions, withdrawals, or contributions are applied. The engine captures
//    startOfYearPrimaryTrad / startOfYearSpouseTrad before step 1 and uses them as
//    the RMD basis in step 3. This prevents the optimizer from illegally reducing
//    current-year RMD obligations by testing large Roth conversions.
//
//    Per-spouse RMD computation (v2.0 — Bug D fix):
//    AccountSnapshot now carries primaryTraditional and spouseTraditional as separate
//    buckets. Each spouse's RMD is computed independently on their own start-of-year
//    balance using their own RMD age. For a 73/65 couple, only the 73-year-old's
//    bucket contributes an RMD; the younger spouse's bucket has no obligation yet.
//    Previously, applying primary's RMD age to the combined total would force ~2× the
//    actual required RMD for mixed-age couples.
//
//    Explicit withdrawal attribution (older-spouse-first rule):
//    LeverAction.traditionalWithdrawal and .rothConversion amounts are attributed to
//    the OLDER spouse's bucket first, then the younger. This naturally satisfies the
//    older spouse's RMD obligation first and is tax-sensible (older = more RMD pressure).
//    The fourOhOneKContribution contribution goes to the primary's bucket by default.
//
//    Excess-RMD handling (Approach A):
//    If the combined RMD exceeds the year's expense need, the gross excess is deposited
//    to the taxable bucket. Tax is computed on the full AGI (including the entire RMD).
//    The year's total tax is then debited from taxable (Step 7).
//
//  Action clamping (v2.0):
//    Every explicit LeverAction is clamped to its source-bucket balance at the time
//    it executes. This prevents the optimizer from minting phantom wealth by testing
//    conversion or withdrawal amounts that exceed the user's actual balance.
//
//  ACA / IRMAA MAGI gating (v2.0):
//    ACA MAGI is tracked when EITHER spouse is pre-Medicare (age < medicareEnrollmentAge).
//    Gating on primary age only was incorrect for mixed-age couples where the younger
//    spouse is still on an ACA Marketplace plan after the older spouse turns 65.
//    IRMAA MAGI tracking starts when EITHER spouse is within the 2-year lookback window
//    (age >= 63), not just the primary.
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
//      × medicareEnrolledCount (0/1/2 based on primary + spouse ages vs enrollment ages)
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

        // Mutable state that evolves year-over-year.
        // Bug D fix: split trad into per-spouse buckets so RMDs can be computed independently.
        var primaryTrad = inputs.startingBalances.primaryTraditional
        var spouseTrad = inputs.startingBalances.spouseTraditional
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

            // Bug A + D fix: capture per-spouse start-of-year trad balances BEFORE step 1 mutations.
            // Per IRS Pub 590-B, the RMD basis is the prior-year-end balance, which
            // equals the beginning of the current year's loop — before any explicit
            // Roth conversions, withdrawals, or contributions are applied.
            let startOfYearPrimaryTrad = primaryTrad
            let startOfYearSpouseTrad = spouseTrad

            // ─────────────────────────────────────────
            // Step 1: Apply explicit LeverActions
            // ─────────────────────────────────────────
            // Bug B fix: every action is clamped to its source-bucket balance.
            // Bug D fix: trad withdrawals and conversions use older-spouse-first attribution.
            //
            // Track income events for AGI computation
            var explicitPrimaryTradWithdrawals = 0.0   // primary's trad pulled out (for RMD check)
            var explicitSpouseTradWithdrawals = 0.0    // spouse's trad pulled out (for RMD check)
            var explicitRothConversions = 0.0          // add to AGI
            var aboveTheLineDeductions = 0.0           // HSA + pre-tax 401k; reduces AGI

            // Helper: is primary the older spouse (or single filer)?
            let primaryIsOlderOrSingle = (spouseAge == nil) || (primaryAge >= spouseAge!)

            for action in actions {
                switch action {
                case .rothConversion(let amount):
                    // Draw from OLDER spouse's bucket first, then younger.
                    // Roth conversions count toward the AGI but NOT toward RMD satisfaction
                    // (per IRS, RMD must be taken first as an actual distribution).
                    var remaining = amount
                    if primaryIsOlderOrSingle {
                        let fromPrimary = min(remaining, max(0, primaryTrad))
                        primaryTrad -= fromPrimary
                        roth += fromPrimary
                        explicitRothConversions += fromPrimary
                        remaining -= fromPrimary
                        if remaining > 0 {
                            let fromSpouse = min(remaining, max(0, spouseTrad))
                            spouseTrad -= fromSpouse
                            roth += fromSpouse
                            explicitRothConversions += fromSpouse
                        }
                    } else {
                        let fromSpouse = min(remaining, max(0, spouseTrad))
                        spouseTrad -= fromSpouse
                        roth += fromSpouse
                        explicitRothConversions += fromSpouse
                        remaining -= fromSpouse
                        if remaining > 0 {
                            let fromPrimary = min(remaining, max(0, primaryTrad))
                            primaryTrad -= fromPrimary
                            roth += fromPrimary
                            explicitRothConversions += fromPrimary
                        }
                    }

                case .traditionalWithdrawal(let amount):
                    // Draw from OLDER spouse's bucket first, then younger.
                    var remaining = amount
                    if primaryIsOlderOrSingle {
                        let fromPrimary = min(remaining, max(0, primaryTrad))
                        primaryTrad -= fromPrimary
                        explicitPrimaryTradWithdrawals += fromPrimary
                        remaining -= fromPrimary
                        if remaining > 0 {
                            let fromSpouse = min(remaining, max(0, spouseTrad))
                            spouseTrad -= fromSpouse
                            explicitSpouseTradWithdrawals += fromSpouse
                        }
                    } else {
                        let fromSpouse = min(remaining, max(0, spouseTrad))
                        spouseTrad -= fromSpouse
                        explicitSpouseTradWithdrawals += fromSpouse
                        remaining -= fromSpouse
                        if remaining > 0 {
                            let fromPrimary = min(remaining, max(0, primaryTrad))
                            primaryTrad -= fromPrimary
                            explicitPrimaryTradWithdrawals += fromPrimary
                        }
                    }

                case .taxableWithdrawal(let amount):
                    let actual = min(amount, max(0, taxable))
                    taxable -= actual
                    // Zero-gain approximation: no AGI impact in v2.0 (cost-basis tracking deferred to v2.1)
                    _ = actual

                case .rothWithdrawal(let amount):
                    let actual = min(amount, max(0, roth))
                    roth -= actual
                    // Qualified Roth withdrawals: no AGI impact
                    _ = actual

                case .hsaContribution(let amount):
                    let actual = min(amount, max(0, taxable))
                    taxable -= actual
                    hsa += actual
                    aboveTheLineDeductions += actual

                case .fourOhOneKContribution(let amount):
                    // Default to primary's bucket (one employer's 401k per spouse; primary default)
                    let actual = min(amount, max(0, taxable))
                    taxable -= actual
                    primaryTrad += actual
                    // Pre-tax 401k contribution: reduces AGI (treated like HSA as above-the-line deduction)
                    aboveTheLineDeductions += actual

                case .deferSocialSecurity:
                    break   // marker only — no balance change

                case .claimSocialSecurity:
                    break   // marker only — no balance change
                }
            }

            // Combined explicit trad withdrawals for AGI
            let explicitTradWithdrawals = explicitPrimaryTradWithdrawals + explicitSpouseTradWithdrawals

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
            // Step 3: Auto-impose per-spouse RMD withdrawals
            // ─────────────────────────────────────────
            // Bug A fix: RMD basis is the start-of-year balance per IRS Pub 590-B.
            // Bug D fix: each spouse's RMD is computed independently on their own bucket.
            //   For a 73/65 couple, only the primary's bucket has an obligation.
            //   The explicit trad withdrawals attributed to each spouse in step 1 are
            //   used as the offset against each spouse's required RMD.
            //
            // Excess-RMD: if combined RMD > expense need, the gross excess is deposited
            // to the taxable bucket (Approach A). Tax is computed on the full AGI.
            var autoImposedRMD = 0.0

            // Primary's RMD
            let primaryRMDAge = rmdAge(birthYear: inputs.primaryBirthYear)
            let primaryRequired: Double = {
                guard primaryAge >= primaryRMDAge, startOfYearPrimaryTrad > 0 else { return 0 }
                return RMDCalculationEngine.calculateRMD(for: primaryAge, balance: startOfYearPrimaryTrad)
            }()
            let primaryRmdShortfall = max(0, primaryRequired - explicitPrimaryTradWithdrawals)
            if primaryRmdShortfall > 0 {
                let withdrawal = min(primaryRmdShortfall, primaryTrad)
                primaryTrad -= withdrawal
                autoImposedRMD += withdrawal
            }

            // Spouse's RMD (if applicable)
            let spouseRequired: Double = {
                guard let sa = spouseAge, let sby = inputs.spouseBirthYear,
                      startOfYearSpouseTrad > 0 else { return 0 }
                let spouseRMDAge = rmdAge(birthYear: sby)
                guard sa >= spouseRMDAge else { return 0 }
                return RMDCalculationEngine.calculateRMD(for: sa, balance: startOfYearSpouseTrad)
            }()
            let spouseRmdShortfall = max(0, spouseRequired - explicitSpouseTradWithdrawals)
            if spouseRmdShortfall > 0 {
                let withdrawal = min(spouseRmdShortfall, spouseTrad)
                spouseTrad -= withdrawal
                autoImposedRMD += withdrawal
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
            // V2.0: otherOrdinaryIncome captures dividends + interest + cap gains + state refund + other,
            // all taxed as ordinary for v2.0 simplicity. V2.1 will classify properly.
            let otherOrdinaryIncome = inputs.primaryOtherOrdinaryIncome + inputs.spouseOtherOrdinaryIncome
            let passiveIncome = wageIncome + pensionIncome + otherOrdinaryIncome + totalGrossSSAnnual

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
                // Bug D: pass both per-spouse trad buckets; older-spouse-first is applied inside.
                let (tradWD, remaining) = autoFundExpenses(
                    shortfall: expenseShortfall,
                    primaryTrad: &primaryTrad,
                    spouseTrad: &spouseTrad,
                    taxableBalance: &taxable,
                    roth: &roth,
                    rule: assumptions.withdrawalOrderingRule,
                    primaryIsOlderOrSingle: primaryIsOlderOrSingle
                )
                autoFundedTradWithdrawals = tradWD
                _ = remaining  // v2.0: assume solvent, ignore any residual
            }

            let totalTradWithdrawals = explicitTradWithdrawals + autoImposedRMD + autoFundedTradWithdrawals

            // ─────────────────────────────────────────
            // Step 5: Apply growth to remaining balances
            // ─────────────────────────────────────────
            let growthFactor = 1.0 + assumptions.investmentGrowthRate
            primaryTrad *= growthFactor
            spouseTrad *= growthFactor
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
            let otherIncomeForSSTax = pensionIncome + wageIncome + otherOrdinaryIncome
                + totalTradWithdrawals + explicitRothConversions
            let taxableSS = TaxCalculationEngine.calculateTaxableSocialSecurity(
                filingStatus: inputs.filingStatus,
                additionalIncome: otherIncomeForSSTax,
                incomeSources: [ssIncomeSource]
            )

            // Federal AGI
            // = pension + wage + other ordinary income (dividends, interest, cap gains, etc.)
            //   + traditional withdrawals (explicit + auto-funded)
            //   + Roth conversions + taxable SS
            //   - above-the-line deductions (HSA contribution, 401k contribution)
            let federalAGI = max(0,
                pensionIncome
                + wageIncome
                + otherOrdinaryIncome  // V2.0: ordinary-rate bucket; v2.1 will classify LTCG/qualDiv separately
                + totalTradWithdrawals
                + explicitRothConversions
                + taxableSS
                - aboveTheLineDeductions
            )

            // ACA MAGI = federalAGI + tax-exempt interest + non-taxable SS
            // non-taxable SS = grossSS - taxableSS; tax-exempt interest = 0 for v2.0
            let nonTaxableSS = max(0, totalGrossSSAnnual - taxableSS)
            let magiAddback = nonTaxableSS  // tax-exempt interest = 0 in v2.0

            // Bug C fix: ACA MAGI is tracked when EITHER spouse is pre-Medicare.
            // Gating on primaryAge < 65 alone was incorrect for mixed-age couples where
            // the younger spouse is still on an ACA Marketplace plan after the older
            // spouse turns 65. Both spouses are tested against their own enrollment age.
            let primaryPreMedicare = primaryAge < inputs.primaryMedicareEnrollmentAge
            let spousePreMedicare: Bool = {
                guard let sa = spouseAge, let sma = inputs.spouseMedicareEnrollmentAge else { return false }
                return sa < sma
            }()
            let anyPreMedicare = primaryPreMedicare || spousePreMedicare

            let acaMagiValue: Double? = (anyPreMedicare && inputs.acaEnrolled) ? federalAGI + magiAddback : nil

            // Bug C fix: IRMAA MAGI tracking starts from EITHER spouse reaching age 63
            // (2-year lookback). Using primary-only missed the window where only the
            // spouse approaches Medicare.
            let primaryWithinIrmaaWindow = primaryAge >= 63
            let spouseWithinIrmaaWindow: Bool = {
                guard let sa = spouseAge else { return false }
                return sa >= 63
            }()
            let anyInIrmaaWindow = primaryWithinIrmaaWindow || spouseWithinIrmaaWindow

            let irmaaMagiValue: Double? = anyInIrmaaWindow ? federalAGI + magiAddback : nil

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

            // Count how many household members are enrolled in Medicare this year.
            // Single filer: 1 if primaryAge >= primaryMedicareEnrollmentAge, else 0.
            // MFJ: above + 1 if spouse exists AND spouseAge >= spouseMedicareEnrollmentAge.
            let primaryOnMedicare = primaryAge >= inputs.primaryMedicareEnrollmentAge ? 1 : 0
            let spouseOnMedicare: Int = {
                guard let sa = spouseAge, let sma = inputs.spouseMedicareEnrollmentAge else { return 0 }
                return sa >= sma ? 1 : 0
            }()
            let medicareEnrolledCount = primaryOnMedicare + spouseOnMedicare

            // IRMAA surcharge — scaled by number of Medicare-enrolled household members.
            // annualSurchargePerPerson is the per-spouse amount; for MFJ couples where both
            // are on Medicare the household pays 2× this. Using per-person only would halve
            // the perceived penalty and cause the optimizer to over-recommend conversions
            // that cross IRMAA tiers (the cost-vs-savings comparison would be wrong).
            let irmaaCost: Double = {
                guard let irmaaMagi = irmaaMagiValue, medicareEnrolledCount > 0 else { return 0 }
                let result = TaxCalculationEngine.calculateIRMAA(
                    magi: irmaaMagi,
                    filingStatus: inputs.filingStatus
                )
                return result.annualSurchargePerPerson * Double(medicareEnrolledCount)
            }()

            // ACA premium impact (negative = subsidy savings)
            // acaMagiValue is already nil when no one is pre-Medicare (Bug C fix upstream),
            // so guarding on acaMagiValue != nil is sufficient — no separate age check needed.
            let acaPremiumImpact: Double = {
                guard inputs.acaEnrolled, let acaMagi = acaMagiValue else { return 0 }
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

            // ─────────────────────────────────────────
            // Step 7: Debit year's total tax from the taxable bucket
            // ─────────────────────────────────────────
            // taxBreakdown.total = federal + state + irmaa + acaPremiumImpact.
            // acaPremiumImpact is negative for subsidy savings (reduces net cost), positive
            // for an ACA cliff penalty (increases net cost). Using taxBreakdown.total correctly
            // nets these out. max(0, ...) guards against the edge case where a large ACA subsidy
            // makes total negative — a positive subsidy cash-flow, not a debit.
            //
            // If taxable is insufficient, debit what's available; the remainder is implicitly
            // assumed paid from external sources (v2.0 limitation). v2.1 will let users
            // designate the tax-payment source (Roth / trad / taxable / external).
            //
            // This step closes the phantom-wealth gap: the previous engine reported taxBreakdown
            // but never debited any account, so projected end-of-horizon wealth was overstated
            // by the cumulative tax bill (significant at 6% compounding over 30 years).
            //
            // Note on excess RMD: gross RMD still flows to the taxable bucket (Approach A),
            // and the year's tax is then debited from taxable. The net effect is the post-tax
            // position the user actually holds.
            let yearTaxBurden = max(0, taxBreakdown.total)
            let taxDebit = min(taxable, yearTaxBurden)
            taxable -= taxDebit

            let snapshot = AccountSnapshot(
                primaryTraditional: max(0, primaryTrad),
                spouseTraditional: max(0, spouseTrad),
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
                actions: allActions,
                medicareEnrolledCount: medicareEnrolledCount
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
    /// Mutates primaryTrad, spouseTrad, taxable, and roth directly.
    /// When drawing from trad, uses older-spouse-first order (primaryIsOlderOrSingle).
    private func autoFundExpenses(
        shortfall: Double,
        primaryTrad: inout Double,
        spouseTrad: inout Double,
        taxableBalance: inout Double,
        roth: inout Double,
        rule: WithdrawalOrderingRule,
        primaryIsOlderOrSingle: Bool
    ) -> (tradWithdrawn: Double, remaining: Double) {
        var remaining = shortfall
        var tradWithdrawn = 0.0

        // Helper: withdraw `amount` from trad buckets using older-spouse-first ordering.
        func withdrawFromTrad(_ amount: Double) -> Double {
            var toWithdraw = amount
            var withdrawn = 0.0
            if primaryIsOlderOrSingle {
                let fromPrimary = min(toWithdraw, max(0, primaryTrad))
                primaryTrad -= fromPrimary; withdrawn += fromPrimary; toWithdraw -= fromPrimary
                if toWithdraw > 0 {
                    let fromSpouse = min(toWithdraw, max(0, spouseTrad))
                    spouseTrad -= fromSpouse; withdrawn += fromSpouse
                }
            } else {
                let fromSpouse = min(toWithdraw, max(0, spouseTrad))
                spouseTrad -= fromSpouse; withdrawn += fromSpouse; toWithdraw -= fromSpouse
                if toWithdraw > 0 {
                    let fromPrimary = min(toWithdraw, max(0, primaryTrad))
                    primaryTrad -= fromPrimary; withdrawn += fromPrimary
                }
            }
            return withdrawn
        }

        let combinedTrad = primaryTrad + spouseTrad

        switch rule {
        case .taxEfficient, .preserveRoth:
            // Order: taxable → traditional → roth
            let fromTaxable = min(remaining, max(0, taxableBalance))
            taxableBalance -= fromTaxable; remaining -= fromTaxable

            let fromTrad = withdrawFromTrad(min(remaining, max(0, combinedTrad)))
            tradWithdrawn += fromTrad; remaining -= fromTrad

            let fromRoth = min(remaining, max(0, roth))
            roth -= fromRoth; remaining -= fromRoth

        case .depleteTradFirst:
            // Order: traditional → taxable → roth
            let fromTrad = withdrawFromTrad(min(remaining, max(0, combinedTrad)))
            tradWithdrawn += fromTrad; remaining -= fromTrad

            let fromTaxable = min(remaining, max(0, taxableBalance))
            taxableBalance -= fromTaxable; remaining -= fromTaxable

            let fromRoth = min(remaining, max(0, roth))
            roth -= fromRoth; remaining -= fromRoth

        case .proportional:
            // Split proportionally between trad and taxable buckets (weighted by current
            // bucket size). HSA is intentionally excluded from auto-funding because it's
            // restricted-use (qualified medical expenses); auto-funding general living
            // expenses from HSA would mischaracterize withdrawals as taxable. Roth is the
            // last-resort fallback if both trad and taxable are exhausted.
            let total = max(1, combinedTrad + taxableBalance)
            let tradFrac = combinedTrad / total
            let taxableFrac = taxableBalance / total

            let fromTrad = withdrawFromTrad(min(remaining * tradFrac, max(0, combinedTrad)))
            let fromTaxable = min(remaining * taxableFrac, max(0, taxableBalance))
            taxableBalance -= fromTaxable
            tradWithdrawn += fromTrad
            remaining -= (fromTrad + fromTaxable)

            // If still short, try Roth last
            let fromRoth = min(remaining, max(0, roth))
            roth -= fromRoth; remaining -= fromRoth
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
        // SECURE Act 2.0 RMD age dispatcher (mirrors ProfileManager.rmdAge).
        if birthYear >= 1960 { return 75 }
        if birthYear >= 1951 { return 73 }
        if birthYear >= 1949 { return 72 }  // SECURE Act 1.0 boundary ~July 1, 1949; approximate as all of 1949
        return 70  // pre-SECURE: RMD age 70½, returned as Int
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
