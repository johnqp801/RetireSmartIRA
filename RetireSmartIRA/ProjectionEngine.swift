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
//  Inherited-IRA buckets (2.1):
//    inputs.inheritedAccounts get their own per-account balances. Each year the
//    beneficiary schedule (RMDCalculationEngine.calculateInheritedIRARMD) forces a
//    distribution from the start-of-year balance: single-life RMDs when the decedent
//    died on/after RBD, full drain in the 10-year-deadline year for non-EDBs, tax-free
//    for inherited Roth. Forced trad distributions join totalTradWithdrawals (AGI,
//    taxable SS, state tax, gross-up); forced cash funds expenses first and any excess
//    is deposited to taxable. Conversions and auto-funding never touch these buckets.
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

    /// Resolves the tax-year config for each projection year. Defaults to `.current`
    /// (the active global config for every year), preserving existing behavior exactly.
    let configProvider: TaxYearConfigProvider

    init(configProvider: TaxYearConfigProvider = .current) {
        self.configProvider = configProvider
    }

    /// Project the scenario forward for each year in `actionsPerYear` (sorted ascending).
    /// Returns one `YearRecommendation` per year.
    func project(
        inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions,
        actionsPerYear: [Int: [LeverAction]]
    ) -> [YearRecommendation] {
        // Scenario base year (year 0). Injectable via inputs.baseYear (defaults to the current
        // calendar year), so projections are deterministic and can model a non-current planning year.
        let scenarioBaseYear = inputs.baseYear

        let sortedYears = actionsPerYear.keys.sorted()
        guard !sortedYears.isEmpty else { return [] }

        // Mutable state that evolves year-over-year.
        // Bug D fix: split trad into per-spouse buckets so RMDs can be computed independently.
        // Phase 1a: each spouse's bucket is itself split into IRA vs 401(k) portions
        // (TradBucket), so QCD sourcing (a later Phase-1 task) can be restricted to IRA only.
        // Non-QCD debits deplete 401(k) first, preserving IRA. All tax/AGI/RMD math below
        // uses `.total`, so this split is behavior-neutral for v2.0/Phase 1a.
        var primary = TradBucket(ira: inputs.startingBalances.primaryTraditionalIRA,
                                 k401: inputs.startingBalances.primaryTraditional401k)
        var spouse = TradBucket(ira: inputs.startingBalances.spouseTraditionalIRA,
                                k401: inputs.startingBalances.spouseTraditional401k)
        var roth = inputs.startingBalances.roth
        // V2.0 first-class taxable accounts: model per-account buckets instead of one scalar.
        // When no accounts were supplied, synthesize a single legacy-equivalent bucket from
        // startingBalances.taxable (basis = balance, both flags true, zero yields, appreciation =
        // investmentGrowthRate) so a no-accounts projection reproduces the old scalar's numbers exactly.
        // Legacy mode: no first-class accounts were supplied. The old engine modeled taxable as a
        // single gain-free scalar (every dollar withdrawable with no embedded capital gain). To
        // reproduce that EXACTLY, the synthesized bucket's basis tracks its balance through
        // appreciation (Step 5), so selling to fund expenses/tax never realizes a phantom gain.
        let legacyTaxableMode = inputs.taxableAccounts.isEmpty
        var buckets: [TaxableBucket] = inputs.taxableAccounts.isEmpty
            ? (inputs.startingBalances.taxable > 0
                ? [TaxableBucket(balance: inputs.startingBalances.taxable,
                                 costBasis: inputs.startingBalances.taxable,
                                 input: TaxableAccountInput(
                                    balance: inputs.startingBalances.taxable,
                                    costBasis: inputs.startingBalances.taxable,
                                    protectedAmount: 0, appreciationRate: assumptions.investmentGrowthRate,
                                    qualifiedDividendYield: 0, ordinaryIncomeYield: 0, taxExemptYield: 0,
                                    realizedLongTermGainYield: 0, availableForExpenses: true,
                                    availableForConversionTaxes: true, fundingPriority: nil))]
                : [])
            : inputs.taxableAccounts.map {
                TaxableBucket(balance: $0.balance, costBasis: $0.costBasis, input: $0)
            }
        var hsa = inputs.startingBalances.hsa
        // Sum of all taxable-bucket balances. Replaces every read of the old `taxable` scalar.
        func totalTaxableBalance() -> Double { buckets.reduce(0) { $0 + $1.balance } }

        // Inherited-IRA buckets (2.1): per-account running balances, parallel to
        // inputs.inheritedAccounts. Each year the beneficiary schedule (via
        // RMDCalculationEngine) forces a distribution from the start-of-year balance:
        // single-life RMDs when the decedent died on/after RBD, the full remaining
        // balance in the 10-year-deadline year for non-EDBs, tax-free for inherited
        // Roth. These buckets are never sources for Roth conversions, explicit
        // withdrawals, or expense auto-funding (non-spouse beneficiaries cannot
        // convert; voluntary early drawdown is a future lever), so the forced income
        // is baseline income in every optimizer candidate by construction.
        var inheritedBalances: [Double] = inputs.inheritedAccounts.map { $0.balance }

        // Deposit already-taxed cash (excess RMD, spendable surplus) into the first
        // expense-available bucket, raising both balance and basis by the same amount (no gain
        // on a fresh deposit). If no bucket exists yet (legacy zero-taxable path), synthesize one
        // so the cash is preserved exactly as the old scalar held it.
        func depositToBuckets(_ amount: Double) {
            guard amount > 0 else { return }
            if let i = buckets.firstIndex(where: { $0.input.availableForExpenses }) {
                buckets[i].balance += amount
                buckets[i].costBasis += amount
            } else {
                buckets.append(TaxableBucket(
                    balance: amount, costBasis: amount,
                    input: TaxableAccountInput(
                        balance: amount, costBasis: amount, protectedAmount: 0,
                        appreciationRate: assumptions.investmentGrowthRate,
                        qualifiedDividendYield: 0, ordinaryIncomeYield: 0, taxExemptYield: 0,
                        realizedLongTermGainYield: 0, availableForExpenses: true,
                        availableForConversionTaxes: true, fundingPriority: nil)))
            }
        }
        var primaryAge = inputs.primaryCurrentAge
        var spouseAge = inputs.spouseCurrentAge

        // Resolve state once. A malformed/unknown abbreviation falls back to .california so the
        // projection still runs, but that silently mis-taxes the household — assert in DEBUG so
        // bad input surfaces in tests/dev instead of producing a quietly-wrong plan. (A future
        // diagnostics channel on MultiYearStrategyResult should surface this to the user.)
        let resolvedState = USState.allCases.first { $0.abbreviation == inputs.state }
        assert(resolvedState != nil, "Unknown state abbreviation '\(inputs.state)' — defaulting to CA")
        let usState: USState = resolvedState ?? .california

        var results: [YearRecommendation] = []

        // IRMAA uses a 2-year MAGI lookback (CMS): the premium in year Y is determined by
        // year Y-2 MAGI. Record every projected year's MAGI so a conversion at (e.g.) 63
        // correctly raises the age-65 premium — the exact pre-Medicare planning window.
        var irmaaMagiByYear: [Int: Double] = [:]

        for year in sortedYears {
            let actions = actionsPerYear[year] ?? []

            // Bug A + D fix: capture per-spouse start-of-year trad balances BEFORE step 1 mutations.
            // Per IRS Pub 590-B, the RMD basis is the prior-year-end balance, which
            // equals the beginning of the current year's loop — before any explicit
            // Roth conversions, withdrawals, or contributions are applied.
            let startOfYearPrimaryTrad = primary.total
            let startOfYearSpouseTrad = spouse.total

            // Required RMD for each spouse, computed from the start-of-year balance per IRS
            // Pub 590-B. Computed BEFORE any actions so Roth conversions cannot consume the
            // dollars that must legally be distributed as an RMD first (IRS: the RMD is not
            // an eligible rollover/conversion amount). Conversions are reserved against these;
            // Step 3 then takes the actual RMD distribution from the preserved balance.
            let primaryRequiredRMD: Double = {
                guard primaryAge >= rmdAge(birthYear: inputs.primaryBirthYear),
                      startOfYearPrimaryTrad > 0 else { return 0 }
                return RMDCalculationEngine.calculateRMD(for: primaryAge, balance: startOfYearPrimaryTrad)
            }()
            let spouseRequiredRMD: Double = {
                guard let sa = spouseAge, let sby = inputs.spouseBirthYear,
                      startOfYearSpouseTrad > 0, sa >= rmdAge(birthYear: sby) else { return 0 }
                return RMDCalculationEngine.calculateRMD(for: sa, balance: startOfYearSpouseTrad)
            }()

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
            var explicitTaxableWithdrawals = 0.0       // taxable cash pulled out (funds expenses)
            var explicitTaxableGain = 0.0              // realized LTCG from explicit taxable sales (preferential)
            var explicitRothWithdrawals = 0.0          // qualified Roth cash pulled out (funds expenses)

            // Helper: is primary the older spouse (or single filer)?
            let primaryIsOlderOrSingle = (spouseAge == nil) || (primaryAge >= spouseAge!)

            for action in actions {
                switch action {
                case .rothConversion(let amount):
                    // Draw from OLDER spouse's bucket first, then younger.
                    // Roth conversions count toward the AGI but NOT toward RMD satisfaction
                    // (per IRS, RMD must be taken first as an actual distribution). Each draw
                    // is reserved against that spouse's required RMD so a conversion can never
                    // consume the dollars Step 3 must distribute as the RMD. (Conservative when
                    // an explicit trad withdrawal in the same year also satisfies the RMD — a
                    // combination the optimizer does not emit; documented v2.0 simplification.)
                    let primaryConvertible = max(0, primary.total - primaryRequiredRMD)
                    let spouseConvertible = max(0, spouse.total - spouseRequiredRMD)
                    var remaining = amount
                    if primaryIsOlderOrSingle {
                        let fromPrimary = min(remaining, primaryConvertible)
                        primary.debit(fromPrimary)
                        roth += fromPrimary
                        explicitRothConversions += fromPrimary
                        remaining -= fromPrimary
                        if remaining > 0 {
                            let fromSpouse = min(remaining, spouseConvertible)
                            spouse.debit(fromSpouse)
                            roth += fromSpouse
                            explicitRothConversions += fromSpouse
                        }
                    } else {
                        let fromSpouse = min(remaining, spouseConvertible)
                        spouse.debit(fromSpouse)
                        roth += fromSpouse
                        explicitRothConversions += fromSpouse
                        remaining -= fromSpouse
                        if remaining > 0 {
                            let fromPrimary = min(remaining, primaryConvertible)
                            primary.debit(fromPrimary)
                            roth += fromPrimary
                            explicitRothConversions += fromPrimary
                        }
                    }

                case .traditionalWithdrawal(let amount):
                    // Draw from OLDER spouse's bucket first, then younger.
                    var remaining = amount
                    if primaryIsOlderOrSingle {
                        let fromPrimary = min(remaining, max(0, primary.total))
                        primary.debit(fromPrimary)
                        explicitPrimaryTradWithdrawals += fromPrimary
                        remaining -= fromPrimary
                        if remaining > 0 {
                            let fromSpouse = min(remaining, max(0, spouse.total))
                            spouse.debit(fromSpouse)
                            explicitSpouseTradWithdrawals += fromSpouse
                        }
                    } else {
                        let fromSpouse = min(remaining, max(0, spouse.total))
                        spouse.debit(fromSpouse)
                        explicitSpouseTradWithdrawals += fromSpouse
                        remaining -= fromSpouse
                        if remaining > 0 {
                            let fromPrimary = min(remaining, max(0, primary.total))
                            primary.debit(fromPrimary)
                            explicitPrimaryTradWithdrawals += fromPrimary
                        }
                    }

                case .taxableWithdrawal(let amount):
                    // Sell from buckets (expense funding), realizing a proportional long-term gain.
                    let s = TaxableAccountEngine.sell(amount: amount, from: &buckets, forTaxes: false)
                    explicitTaxableWithdrawals += s.raised
                    explicitTaxableGain += s.realizedGain   // preferential income (LTCG schedule)

                case .rothWithdrawal(let amount):
                    let actual = min(amount, max(0, roth))
                    roth -= actual
                    // Qualified Roth withdrawals: no AGI impact; cash available to fund expenses.
                    explicitRothWithdrawals += actual

                case .hsaContribution(let amount):
                    // Funded by selling taxable buckets; realized gain feeds preferential income.
                    let s = TaxableAccountEngine.sell(amount: amount, from: &buckets, forTaxes: false)
                    explicitTaxableGain += s.realizedGain
                    hsa += s.raised
                    aboveTheLineDeductions += s.raised

                case .fourOhOneKContribution(let amount):
                    // Default to primary's bucket (one employer's 401k per spouse; primary default).
                    // Funded by selling taxable buckets; realized gain feeds preferential income.
                    let s = TaxableAccountEngine.sell(amount: amount, from: &buckets, forTaxes: false)
                    explicitTaxableGain += s.realizedGain
                    primary.credit401k(s.raised)
                    // Pre-tax 401k contribution: reduces AGI (treated like HSA as above-the-line deduction)
                    aboveTheLineDeductions += s.raised

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

            // ─── QCD application (Phase 1c) ───
            // QCDs come from the IRA, count toward the RMD, and are excluded from AGI. Computed
            // here (after RMD is known, before the RMD is force-distributed) so they reduce the
            // taxable RMD. The QCD money leaves the household (to charity); it is not reinvested.
            var primaryQCD = 0.0
            var spouseQCD = 0.0
            if inputs.charitableGivingPlan.hasGiving {
                let yearsFromBase = max(0, year - scenarioBaseYear)
                let inflationFactor = pow(1.0 + assumptions.cpiRate, Double(yearsFromBase))
                let qcdLimit = configProvider.config(forYear: year).qcdAnnualLimit
                let primaryEligible = QCDPlanner.isEligible(birthDate: inputs.primaryBirthDate, byEndOf: year)
                let spouseEligible = inputs.spouseBirthDate.map { QCDPlanner.isEligible(birthDate: $0, byEndOf: year) } ?? false
                let q = QCDPlanner.plan(
                    inputs.charitableGivingPlan,
                    primaryRMD: primaryRequiredRMD, spouseRMD: spouseRequiredRMD,
                    primaryIRA: primary.ira, spouseIRA: spouse.ira,
                    primaryEligible: primaryEligible, spouseEligible: spouseEligible,
                    qcdLimit: qcdLimit, inflationFactor: inflationFactor)
                primaryQCD = q.primaryQCD
                spouseQCD = q.spouseQCD
                primary.debitIRA(primaryQCD)   // IRA-only; leaves the household to charity
                spouse.debitIRA(spouseQCD)
            }

            var autoImposedRMD = 0.0

            // Primary's RMD (required amount precomputed above from the start-of-year balance).
            // Because conversions were reserved against it in Step 1, the bucket still holds at
            // least the required RMD, so the shortfall withdrawal below always fully succeeds.
            let primaryRmdShortfall = max(0, primaryRequiredRMD - explicitPrimaryTradWithdrawals - primaryQCD)
            if primaryRmdShortfall > 0 {
                let withdrawal = min(primaryRmdShortfall, primary.total)
                primary.debit(withdrawal)
                autoImposedRMD += withdrawal
            }

            // Spouse's RMD (if applicable; required amount precomputed above).
            let spouseRmdShortfall = max(0, spouseRequiredRMD - explicitSpouseTradWithdrawals - spouseQCD)
            if spouseRmdShortfall > 0 {
                let withdrawal = min(spouseRmdShortfall, spouse.total)
                spouse.debit(withdrawal)
                autoImposedRMD += withdrawal
            }

            // Forced inherited-IRA distributions (beneficiary schedule). Start-of-year
            // balances are the basis, consistent with the Pub 590-B prior-year-end
            // convention used for owner RMDs above. Actions in Step 1 never touch these
            // buckets, so the balances here still equal start-of-year values.
            // Traditional distributions are ordinary income (joined to
            // totalTradWithdrawals below); Roth distributions are tax-free cash.
            var inheritedTradDistributions = 0.0
            var inheritedRothDistributions = 0.0
            for i in inputs.inheritedAccounts.indices {
                let dist = inputs.inheritedAccounts[i].requiredDistribution(
                    forYear: year, balance: inheritedBalances[i])
                guard dist > 0 else { continue }
                inheritedBalances[i] -= dist
                if inputs.inheritedAccounts[i].isRoth {
                    inheritedRothDistributions += dist
                } else {
                    inheritedTradDistributions += dist
                }
            }

            // ─────────────────────────────────────────
            // Step 4: Compute expenses and auto-funding
            // ─────────────────────────────────────────
            let annualExpenses: Double = {
                if let override = assumptions.perYearExpenseOverrides[year] {
                    return override   // explicit nominal value for this year
                }
                // H4: inflate the baseline (stated in today's dollars) by CPI so expenses stay
                // consistent with COLA-adjusted Social Security. Without this, flat-nominal
                // expenses understated late-horizon withdrawals and overstated end balances.
                let yearsFromBase = max(0, year - scenarioBaseYear)
                return inputs.baselineAnnualExpenses * pow(1.0 + assumptions.cpiRate, Double(yearsFromBase))
            }()

            let wageIncome = inputs.primaryWageIncome + inputs.spouseWageIncome
            let pensionIncome = inputs.primaryPensionIncome + inputs.spousePensionIncome
            // V2.0: otherOrdinaryIncome captures dividends + interest + cap gains + state refund + other,
            // all taxed as ordinary for v2.0 simplicity. V2.1 will classify properly.
            let otherOrdinaryIncome = inputs.primaryOtherOrdinaryIncome + inputs.spouseOtherOrdinaryIncome
            // Preferential-rate income (qualified dividends + LTCG): part of AGI/MAGI/provisional
            // income and spendable cash, but taxed at the federal LTCG schedule (not ordinary).
            let preferentialIncome = inputs.primaryPreferentialIncome + inputs.spousePreferentialIncome
            // Account income on the START-of-year balances (before growth). Ordinary + preferential
            // flow into AGI; tax-exempt flows into MAGI add-back only. spendableCash is the income
            // from expense-available accounts (walled-account income is taxed but reinvested in Step 5).
            let acctIncome = TaxableAccountEngine.annualIncome(buckets)
            let passiveIncome = wageIncome + pensionIncome + otherOrdinaryIncome + preferentialIncome
                + totalGrossSSAnnual + acctIncome.spendableCash

            var autoFundedTradWithdrawals = 0.0
            // RMD cash already extracted from trad; subtract from shortfall before auto-funding.
            // If RMD exceeds the full expense need, the gross excess is deposited to taxable (Approach A).
            // Forced inherited distributions (trad AND Roth) join this pool: like owner RMD
            // cash they fund expenses first, and any excess flows to taxable via the
            // rmdExcess deposit below, so a year-10 drain becomes taxable wealth instead
            // of leaking out of the projection.
            let rmdCashAvailable = autoImposedRMD + explicitTradWithdrawals
                + inheritedTradDistributions + inheritedRothDistributions  // total forced cash so far
            // Explicit taxable/Roth withdrawals also provide spendable cash (already pulled from
            // those buckets in Step 1). Their surplus is not redeposited in v2.0 (only RMD surplus is).
            let explicitNonTradCash = explicitTaxableWithdrawals + explicitRothWithdrawals
            let expenseShortfallBeforeRMD = max(0, annualExpenses - passiveIncome)
            let expenseShortfall = max(0, expenseShortfallBeforeRMD - rmdCashAvailable - explicitNonTradCash)

            // Deposit gross excess RMD (above expense need) into a taxable bucket (Approach A).
            let rmdExcess = max(0, rmdCashAvailable - expenseShortfallBeforeRMD)
            depositToBuckets(rmdExcess)

            // Realized LTCG from auto-fund taxable sales (preferential income, like explicit sales).
            var autoFundTaxableGain = 0.0
            if expenseShortfall > 0 {
                // Bug D: pass both per-spouse trad buckets; older-spouse-first is applied inside.
                // The taxable leg runs against a scratch scalar seeded from the bucket total so the
                // ordering rules are unchanged; we then realize exactly that draw from the buckets,
                // capturing its proportional gain.
                var scratchTaxable = totalTaxableBalance()
                let (tradWD, taxableWD, remaining) = autoFundExpenses(
                    shortfall: expenseShortfall,
                    primary: &primary,
                    spouse: &spouse,
                    taxableBalance: &scratchTaxable,
                    roth: &roth,
                    rule: assumptions.withdrawalOrderingRule,
                    primaryIsOlderOrSingle: primaryIsOlderOrSingle
                )
                autoFundedTradWithdrawals = tradWD
                if taxableWD > 0 {
                    let s = TaxableAccountEngine.sell(amount: taxableWD, from: &buckets, forTaxes: false)
                    autoFundTaxableGain = s.realizedGain
                }
                _ = remaining  // v2.0: assume solvent, ignore any residual
            }

            // Inherited traditional distributions ride with totalTradWithdrawals so AGI,
            // taxable-SS, state retirement-income bucketing, and the tax gross-up all
            // treat them as the ordinary pre-tax income they are.
            let totalTradWithdrawals = explicitTradWithdrawals + autoImposedRMD + autoFundedTradWithdrawals
                + inheritedTradDistributions

            // ─────────────────────────────────────────
            // Step 5: Apply growth to remaining balances
            // ─────────────────────────────────────────
            let growthFactor = 1.0 + assumptions.investmentGrowthRate
            primary.grow(growthFactor)
            spouse.grow(growthFactor)
            roth *= growthFactor
            hsa *= growthFactor
            for i in inheritedBalances.indices {
                inheritedBalances[i] = max(0, inheritedBalances[i]) * growthFactor
            }

            // Per-account taxable growth: each bucket appreciates at its own appreciationRate
            // (basis unchanged by appreciation). Walled accounts (not available for expenses) have
            // their year's income reinvested first — it was taxed in Step 6 but is not spendable, so
            // it compounds in-account (raising both balance and basis, since it's already-taxed cash).
            for i in buckets.indices {
                if !buckets[i].input.availableForExpenses {
                    let inc = (buckets[i].input.ordinaryIncomeYield + buckets[i].input.qualifiedDividendYield
                               + buckets[i].input.taxExemptYield + buckets[i].input.realizedLongTermGainYield)
                              * buckets[i].balance
                    buckets[i].balance += inc
                    buckets[i].costBasis += inc
                }
                buckets[i].balance *= (1.0 + buckets[i].input.appreciationRate)  // appreciation only; basis unchanged
                // Legacy mode keeps basis == balance so the synthesized bucket stays gain-free,
                // reproducing the old gain-agnostic scalar exactly (no phantom realized gains).
                if legacyTaxableMode { buckets[i].costBasis = buckets[i].balance }
            }

            // Spendable surplus reinvestment: account distributions that exceeded the year's expense
            // need are already-taxed cash. Redeposit the unspent portion into the first available
            // bucket so it compounds instead of leaking out of the projection. Only the account-sourced
            // distributions are reinvested (wage/SS/pension surplus is consumption, not re-invested).
            let spendSurplus = max(0, passiveIncome - annualExpenses)
            depositToBuckets(min(acctIncome.spendableCash, spendSurplus))

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
            // Account income that flows into taxable income:
            //   ordinary  → taxed at ordinary brackets (interest, non-qualified dividends, walled too)
            //   preferential → taxed at the LTCG schedule. Realized gains from THIS year's sales
            //     (explicit taxable withdrawals, expense auto-funding, contribution funding) are
            //     also preferential and join the bucket here. Tax-paying sales' gains are added
            //     inside the Step 7 gross-up loop, not here.
            let accountOrdinaryIncome = acctIncome.ordinary
            let realizedSaleGains = explicitTaxableGain + autoFundTaxableGain
            let totalPreferentialIncome = preferentialIncome + acctIncome.preferential + realizedSaleGains

            let otherIncomeForSSTax = pensionIncome + wageIncome + otherOrdinaryIncome
                + accountOrdinaryIncome + totalPreferentialIncome
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
                + otherOrdinaryIncome       // ordinary-rate investment/other income
                + accountOrdinaryIncome     // taxable-account ordinary income (interest, non-qual divs)
                + totalPreferentialIncome   // qualified dividends + LTCG + realized sale gains (in AGI; taxed preferentially below)
                + totalTradWithdrawals
                + explicitRothConversions
                + taxableSS
                - aboveTheLineDeductions
            )

            // NIIT (3.8%): net investment income = the user's stated NIIT-qualifying income
            // (mirrored from single-year) + the taxable account's investment throw-off this year
            // (ordinary + preferential) + realized sale gains. MAGI ~= AGI for retirees, exactly as
            // the single-year engine does (DataManager.scenarioNIIT passes estimatedAGI as MAGI).
            let netInvestmentIncome = inputs.primaryNetInvestmentIncome
                + inputs.spouseNetInvestmentIncome
                + accountOrdinaryIncome
                + acctIncome.preferential
                + realizedSaleGains
            let niitTax = TaxCalculationEngine.calculateNIIT(
                nii: netInvestmentIncome,
                magi: federalAGI,
                filingStatus: inputs.filingStatus
            ).annualNIITax

            // ACA / IRMAA MAGI = federalAGI + tax-exempt interest + non-taxable SS.
            // non-taxable SS = grossSS - taxableSS; tax-exempt interest = muni income on taxable
            // accounts (V2.0: now modeled per-account instead of the old hardcoded 0).
            let nonTaxableSS = max(0, totalGrossSSAnnual - taxableSS)
            let magiAddback = nonTaxableSS + acctIncome.taxExempt

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

            // Record this year's MAGI for the 2-year IRMAA lookback (stored for ALL years,
            // including pre-Medicare years, since they determine future-year premiums).
            irmaaMagiByYear[year] = federalAGI + magiAddback

            // Standard deduction — derived from TaxCalculationEngine.config
            let stdDed = standardDeduction(
                filingStatus: inputs.filingStatus,
                primaryAge: primaryAge,
                spouseAge: spouseAge,
                year: year,
                federalAGI: federalAGI
            )
            let taxableIncome = max(0, federalAGI - stdDed)
            // Preferential portion of taxable income (qualified dividends + LTCG), capped at
            // taxable income. The standard deduction offsets ordinary income first, so the
            // preferential amount stacks on top at the LTCG schedule — matching the single-year
            // engine's calculateFederalTax(preferentialIncome:) convention.
            let taxablePreferential = min(max(0, totalPreferentialIncome), taxableIncome)

            // Federal tax — ordinary brackets on the ordinary portion, the federal LTCG schedule
            // on the preferential portion. Brackets resolve through the per-year config provider.
            let brackets = configProvider.config(forYear: year).toTaxBrackets()
            let federalTax = TaxCalculationEngine.calculateFederalTax(
                income: taxableIncome,
                filingStatus: inputs.filingStatus,
                brackets: brackets,
                preferentialIncome: taxablePreferential
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
                guard medicareEnrolledCount > 0 else { return 0 }
                // CMS 2-year lookback: the year-Y premium is set by year Y-2 MAGI. For the
                // first ≤2 projection years, Y-2 predates the projection, so fall back to the
                // current year's MAGI (the best available proxy for recent income).
                let lookbackMagi = irmaaMagiByYear[year - 2] ?? (federalAGI + magiAddback)
                let result = TaxCalculationEngine.calculateIRMAA(
                    magi: lookbackMagi,
                    filingStatus: inputs.filingStatus
                )
                return result.annualSurchargePerPerson * Double(medicareEnrolledCount)
            }()

            // ACA premium impact (negative = subsidy savings)
            // acaMagiValue is already nil when no one is pre-Medicare (Bug C fix upstream),
            // so guarding on acaMagiValue != nil is sufficient — no separate age check needed.
            let acaPremiumImpact: Double = {
                guard inputs.acaEnrolled, let acaMagi = acaMagiValue else { return 0 }
                let taxConfig = configProvider.config(forYear: year)
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
                acaPremiumImpact: acaPremiumImpact,
                niit: niitTax
            )

            // ─────────────────────────────────────────
            // Step 7: Debit year's total tax from the taxable bucket,
            //         with optional gross-up from traditional when taxable is short.
            // ─────────────────────────────────────────
            // taxBreakdown.total = federal + state + irmaa + acaPremiumImpact + niit.
            // acaPremiumImpact is negative for subsidy savings (reduces net cost), positive
            // for an ACA cliff penalty (increases net cost). Using taxBreakdown.total correctly
            // nets these out. max(0, ...) guards against the edge case where a large ACA subsidy
            // makes total negative — a positive subsidy cash-flow, not a debit.
            //
            // .taxableThenGrossUp (default): pay tax from taxable; if short, fund the gap by
            //   an additional traditional withdrawal grossed-up for the federal+state tax that
            //   withdrawal itself creates (3-iteration fixed-point). IRMAA/ACA are NOT
            //   recomputed for the gross-up withdrawal (documented approximation).
            // .external: any shortfall after taxable is silently absorbed (legacy behavior).
            //
            // This step closes the phantom-wealth gap: the previous engine reported taxBreakdown
            // but never debited any account, so projected end-of-horizon wealth was overstated
            // by the cumulative tax bill (significant at 6% compounding over 30 years).
            //
            // Note on excess RMD: gross RMD still flows to the taxable bucket (Approach A),
            // and the year's tax is then debited from taxable. The net effect is the post-tax
            // position the user actually holds.
            var grossUpWithdrawal = 0.0
            var underfundedTax = 0.0
            var fedTax = federalTax
            var stTax = stateTax
            var reportedAGI = federalAGI
            var reportedTaxableIncome = taxableIncome
            var taxFundingGain = 0.0   // realized LTCG from selling buckets to PAY the tax bill

            if assumptions.taxPaymentSource == .taxableThenGrossUp {
                let nonFedState = max(0, taxBreakdown.total - federalTax - stateTax) // irmaa+aca+niit, NOT recomputed
                let baseTotalTax = federalTax + stateTax + nonFedState

                // Incremental fed+state tax created by (a) realized gains from tax-funding bucket
                // sales (preferential) and (b) a grossed-up traditional withdrawal (ordinary). Both
                // ride on top of the already-computed federalTax/stateTax. The gain enters as
                // additional preferential income; dW enters as additional ordinary income + AGI.
                func incrementalTax(saleGain: Double, dW: Double) -> Double {
                    let fed = TaxCalculationEngine.calculateFederalTax(
                        income: max(0, taxableIncome + dW), filingStatus: inputs.filingStatus,
                        brackets: brackets, preferentialIncome: min(taxablePreferential + max(0, saleGain),
                                                                     max(0, taxableIncome + dW))) - federalTax
                    let st = computeStateTax(
                        federalAGI: federalAGI + dW + max(0, saleGain), taxableSS: taxableSS, pensionIncome: pensionIncome,
                        totalTradWithdrawals: totalTradWithdrawals + dW, filingStatus: inputs.filingStatus,
                        usState: usState, primaryAge: primaryAge, spouseBirthYear: inputs.spouseBirthYear,
                        year: year) - stateTax
                    return max(0, fed) + max(0, st)
                }

                // Phase 1: fund the tax bill by selling taxable buckets (forTaxes: true). This is the
                // direct analogue of the legacy "pay tax from taxable first" step. The realized gain
                // raises taxable income, which is folded into the gross-up fixed point below. In legacy
                // mode the synthesized bucket is gain-free, so saleGain == 0 and this reproduces the old
                // taxable debit exactly.
                //
                // V2.0 simplification: Phase 1 sells only enough to cover the BASE tax (the
                // incrementalTax(0,0) term is zero by construction). The extra tax created by the
                // sale's own realized gain is then grossed up below (Phase 2), funded from traditional
                // rather than by re-selling the bucket. The reported total tax is still exact (recomputed
                // with saleGain folded in); only the funding source of the gain-on-gain sliver is
                // approximate. Re-selling within the iteration is a v2.1 refinement.
                let availableTrad = max(0, primary.total + spouse.total)
                let sellTarget = baseTotalTax + incrementalTax(saleGain: 0, dW: 0)
                let applied = TaxableAccountEngine.sell(amount: sellTarget, from: &buckets, forTaxes: true)
                let saleCash = applied.raised
                let saleGain = applied.realizedGain
                taxFundingGain = saleGain

                // Phase 2: gross up from traditional for whatever the buckets could not cover, including
                // the incremental tax created by the realized gain AND by the gross-up withdrawal itself.
                // This mirrors the legacy 3-iteration fixed point: dW = shortfall + taxOn(dW), seeded at
                // the bucket shortfall so the iteration count and convergence match exactly.
                let shortfall0 = max(0, baseTotalTax - saleCash) // base tax not covered by bucket sales
                var dW = min(shortfall0 + incrementalTax(saleGain: saleGain, dW: 0), availableTrad)
                if shortfall0 > 0 || saleGain > 0 {
                    for _ in 0..<3 {
                        let next = min(shortfall0 + incrementalTax(saleGain: saleGain, dW: dW), availableTrad)
                        if abs(next - dW) < 1.0 { dW = next; break }
                        dW = next
                    }
                } else {
                    dW = 0
                }

                // Apply the converged traditional gross-up (older-spouse-first).
                grossUpWithdrawal = dW
                if dW > 0 {
                    var remaining = dW
                    if primaryIsOlderOrSingle {
                        let fromP = min(remaining, max(0, primary.total)); primary.debit(fromP); remaining -= fromP
                        let fromS = min(remaining, max(0, spouse.total)); spouse.debit(fromS)
                    } else {
                        let fromS = min(remaining, max(0, spouse.total)); spouse.debit(fromS); remaining -= fromS
                        let fromP = min(remaining, max(0, primary.total)); primary.debit(fromP)
                    }
                }

                // Recompute reported tax with the realized gain and gross-up folded in.
                if saleGain > 0 || dW > 0 {
                    reportedTaxableIncome = max(0, taxableIncome + dW)
                    reportedAGI = federalAGI + dW + saleGain
                    fedTax = TaxCalculationEngine.calculateFederalTax(
                        income: reportedTaxableIncome, filingStatus: inputs.filingStatus,
                        brackets: brackets,
                        preferentialIncome: min(taxablePreferential + saleGain, reportedTaxableIncome))
                    stTax = computeStateTax(
                        federalAGI: reportedAGI, taxableSS: taxableSS, pensionIncome: pensionIncome,
                        totalTradWithdrawals: totalTradWithdrawals + dW, filingStatus: inputs.filingStatus,
                        usState: usState, primaryAge: primaryAge, spouseBirthYear: inputs.spouseBirthYear, year: year)
                    underfundedTax = max(0, (fedTax + stTax + nonFedState) - saleCash - dW)
                }
            }

            let taxBreakdownFinal = TaxBreakdown(
                federal: fedTax,
                state: stTax,
                irmaa: taxBreakdown.irmaa,
                acaPremiumImpact: taxBreakdown.acaPremiumImpact,
                niit: taxBreakdown.niit)

            // The bucket sales above raised cash to pay the tax; that cash leaves the household as the
            // tax payment. Any tax not covered by sales/gross-up (underfunded) is assumed paid from an
            // external source (v2.0 limitation), so no further bucket debit is needed here.
            _ = max(0, taxBreakdownFinal.total)

            let snapshot = AccountSnapshot(
                primaryTraditionalIRA: max(0, primary.ira),
                primaryTraditional401k: max(0, primary.k401),
                spouseTraditionalIRA: max(0, spouse.ira),
                spouseTraditional401k: max(0, spouse.k401),
                roth: max(0, roth),
                taxable: max(0, totalTaxableBalance()),
                hsa: max(0, hsa),
                inheritedTraditional: inputs.inheritedAccounts.indices
                    .filter { !inputs.inheritedAccounts[$0].isRoth }
                    .reduce(0.0) { $0 + max(0, inheritedBalances[$1]) },
                inheritedRoth: inputs.inheritedAccounts.indices
                    .filter { inputs.inheritedAccounts[$0].isRoth }
                    .reduce(0.0) { $0 + max(0, inheritedBalances[$1]) }
            )

            // Build the combined actions list: explicit user actions + auto-imposed RMD (if any)
            // + gross-up withdrawal (if any).
            // This lets callers inspect the full picture of what actually happened in the year.
            var allActions = actions
            if autoImposedRMD > 0 {
                allActions.append(.traditionalWithdrawal(amount: autoImposedRMD))
            }
            if inheritedTradDistributions > 0 {
                allActions.append(.traditionalWithdrawal(amount: inheritedTradDistributions))
            }
            if inheritedRothDistributions > 0 {
                allActions.append(.rothWithdrawal(amount: inheritedRothDistributions))
            }
            if grossUpWithdrawal > 0 {
                allActions.append(.traditionalWithdrawal(amount: grossUpWithdrawal))
            }

            results.append(YearRecommendation(
                year: year,
                agi: reportedAGI,
                acaMagi: acaMagiValue,
                irmaaMagi: irmaaMagiValue,
                taxableIncome: reportedTaxableIncome,
                taxBreakdown: taxBreakdownFinal,
                endOfYearBalances: snapshot,
                actions: allActions,
                medicareEnrolledCount: medicareEnrolledCount,
                underfunded: underfundedTax > 0 ? underfundedTax : nil,
                // Inherited traditional distributions are required minimum distributions
                // too; include them so forced income is visible without digging through
                // the bundled actions. (Inherited Roth drains are forced but tax-free,
                // so they are reported via the .rothWithdrawal action instead.)
                rmd: primaryRequiredRMD + spouseRequiredRMD + inheritedTradDistributions
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
    /// Returns (totalTradWithdrawn, taxableWithdrawn, remainingShortfall).
    /// Mutates primary, spouse, taxableBalance, and roth directly. The caller realizes the
    /// taxableBalance decrement against the per-account buckets (so basis/gain are tracked there).
    /// When drawing from trad, uses older-spouse-first order (primaryIsOlderOrSingle); each
    /// spouse's TradBucket.debit depletes 401(k) before IRA.
    private func autoFundExpenses(
        shortfall: Double,
        primary: inout TradBucket,
        spouse: inout TradBucket,
        taxableBalance: inout Double,
        roth: inout Double,
        rule: WithdrawalOrderingRule,
        primaryIsOlderOrSingle: Bool
    ) -> (tradWithdrawn: Double, taxableWithdrawn: Double, remaining: Double) {
        let taxableStart = taxableBalance
        var remaining = shortfall
        var tradWithdrawn = 0.0

        // Helper: withdraw `amount` from trad buckets using older-spouse-first ordering.
        func withdrawFromTrad(_ amount: Double) -> Double {
            var toWithdraw = amount
            var withdrawn = 0.0
            if primaryIsOlderOrSingle {
                let fromPrimary = min(toWithdraw, max(0, primary.total))
                primary.debit(fromPrimary); withdrawn += fromPrimary; toWithdraw -= fromPrimary
                if toWithdraw > 0 {
                    let fromSpouse = min(toWithdraw, max(0, spouse.total))
                    spouse.debit(fromSpouse); withdrawn += fromSpouse
                }
            } else {
                let fromSpouse = min(toWithdraw, max(0, spouse.total))
                spouse.debit(fromSpouse); withdrawn += fromSpouse; toWithdraw -= fromSpouse
                if toWithdraw > 0 {
                    let fromPrimary = min(toWithdraw, max(0, primary.total))
                    primary.debit(fromPrimary); withdrawn += fromPrimary
                }
            }
            return withdrawn
        }

        let combinedTrad = primary.total + spouse.total

        switch rule {
        case .taxEfficient, .preserveRoth:
            // V2.0: `.taxEfficient` and `.preserveRoth` intentionally share one order
            // (taxable → traditional → roth) — both spend Roth last. They are NOT yet
            // differentiated: a true `.taxEfficient` should sequence by marginal tax / ACA /
            // IRMAA per year, which requires the withdrawal-strategy optimizer planned for
            // v2.1. Documented here so the shared branch reads as deliberate, not a bug.
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

            // Second pass: if one bucket couldn't cover its proportional share (e.g. taxable
            // too small), draw the remainder from the OTHER bucket's remaining capacity before
            // falling back to Roth — otherwise proportional prematurely drains Roth.
            if remaining > 0 {
                let extraTaxable = min(remaining, max(0, taxableBalance))
                taxableBalance -= extraTaxable; remaining -= extraTaxable
            }
            if remaining > 0 {
                let extraTrad = withdrawFromTrad(min(remaining, max(0, primary.total + spouse.total)))
                tradWithdrawn += extraTrad; remaining -= extraTrad
            }

            // If still short, try Roth last
            let fromRoth = min(remaining, max(0, roth))
            roth -= fromRoth; remaining -= fromRoth
        }

        return (tradWithdrawn, max(0, taxableStart - taxableBalance), remaining)
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
        let cfg = configProvider.config(forYear: year)

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
