//
//  TaxCalculationEngine.swift
//  RetireSmartIRA
//
//  Pure tax calculation logic extracted from DataManager.
//  All static methods — no SwiftUI, no persistence, no DataManager dependency.
//

import Foundation

struct TaxCalculationEngine {

    // MARK: - Tax Year Configuration

    /// The active tax year config, loaded from bundled JSON.
    /// Set at app startup via `loadConfig(forYear:)`. Falls back to hardcoded 2026 values.
    private(set) static var config: TaxYearConfig = TaxYearConfig.loadOrFallback(
        forYear: Calendar.current.component(.year, from: Date())
    )

    /// Reload the config for a different tax year (e.g., when user changes currentYear).
    static func loadConfig(forYear year: Int) {
        config = TaxYearConfig.loadOrFallback(forYear: year)
    }

    /// **TEST-ONLY.** Temporarily swap `config` to the bundled JSON for `year`,
    /// run `body`, then restore the original. Used by `TaxsimOracleTests` to
    /// validate the federal engine against NBER TAXSIM-35, which only codes
    /// federal law through TY2023 (year>=2024 returns STOP 1).
    ///
    /// @MainActor so the body can construct a DataManager (also @MainActor).
    /// Not thread-safe — only use from synchronous test code on the main actor.
    /// Do not use in production: the production tax year is set once at app
    /// startup via `loadConfig(forYear:)`.
    @MainActor
    static func withConfig<T>(forYear year: Int, _ body: () throws -> T) rethrows -> T {
        let original = config
        defer { config = original }
        config = TaxYearConfig.loadOrFallback(forYear: year)
        return try body()
    }

    // MARK: - Tax Bracket Constants (from config)

    static var default2026Brackets: TaxBrackets { config.toTaxBrackets() }

    // MARK: - 0% LTCG Bracket (1.8.2 L2)

    /// Top of the 0% long-term capital gains bracket for the given filing status, using the current TaxYearConfig.
    /// In 2026: $98,900 MFJ, $49,450 single.
    static func ltcg0PercentTop(filingStatus: FilingStatus) -> Double {
        let brackets = default2026Brackets
        let capGains = filingStatus == .single ? brackets.federalCapGainsSingle : brackets.federalCapGainsMarried
        if let firstNonZero = capGains.first(where: { $0.rate > 0 }) {
            return firstNonZero.threshold
        }
        return 0
    }

    /// Remaining headroom inside the 0% LTCG bracket, given current taxable income.
    static func ltcg0PercentHeadroom(taxableIncome: Double, filingStatus: FilingStatus) -> Double {
        let top = ltcg0PercentTop(filingStatus: filingStatus)
        return max(0, top - taxableIncome)
    }

    // MARK: - IRMAA Constants (from config)

    static var irmaaStandardPartB: Double { config.irmaaStandardPartB }
    static var irmaa2026Tiers: [IRMAATier] { config.toIRMAATiers() }

    // MARK: - NIIT Constants (from config)

    static var niitRate: Double { config.niitRate }
    static var niitThresholdSingle: Double { config.niitThresholdSingle }
    static var niitThresholdMFJ: Double { config.niitThresholdMFJ }

    static let niitQualifyingTypes: Set<IncomeType> = [
        .dividends, .qualifiedDividends, .interest,
        .capitalGainsShort, .capitalGainsLong
    ]

    // MARK: - AMT Constants (from config)

    static var amtExemptionSingle: Double { config.amtExemptionSingle }
    static var amtExemptionMFJ: Double { config.amtExemptionMFJ }
    static var amtPhaseoutThresholdSingle: Double { config.amtPhaseoutThresholdSingle }
    static var amtPhaseoutThresholdMFJ: Double { config.amtPhaseoutThresholdMFJ }
    static var amtPhaseoutRate: Double { config.amtPhaseoutRate }
    static var amt26PercentLimit: Double { config.amt26PercentLimit }
    static var amtRate26: Double { config.amtRate26 }
    static var amtRate28: Double { config.amtRate28 }

    // MARK: - Progressive Tax

    static func progressiveTax(income: Double, brackets: [TaxBracket]) -> Double {
        var tax = 0.0
        for i in brackets.indices {
            let bracket = brackets[i]
            if income > bracket.threshold {
                let nextThreshold = i + 1 < brackets.count ? brackets[i + 1].threshold : income
                let taxableAtThisRate = min(income, nextThreshold) - bracket.threshold
                tax += taxableAtThisRate * bracket.rate
            }
        }
        return tax
    }

    // MARK: - Federal Tax

    static func calculateFederalTax(income: Double, filingStatus: FilingStatus, brackets: TaxBrackets, preferentialIncome: Double) -> Double {
        let capGains = max(0, preferentialIncome)
        let ordinaryIncome = max(0, income - capGains)

        let ordinaryBrackets = filingStatus == .single
            ? brackets.federalSingle : brackets.federalMarried
        var tax = progressiveTax(income: ordinaryIncome, brackets: ordinaryBrackets)

        if capGains > 0 {
            let capGainsBrackets = filingStatus == .single
                ? brackets.federalCapGainsSingle : brackets.federalCapGainsMarried
            let taxOnTotal = progressiveTax(income: income, brackets: capGainsBrackets)
            let taxOnOrdinary = progressiveTax(income: ordinaryIncome, brackets: capGainsBrackets)
            tax += taxOnTotal - taxOnOrdinary
        }

        return tax
    }

    // MARK: - Heir Tax Estimate (Progressive Brackets)

    /// Result of calculating progressive federal tax on an heir's inherited IRA distributions.
    struct HeirTaxEstimate {
        let annualDistribution: Double
        let heirSalary: Double
        let totalIncome: Double          // salary + distribution
        let taxOnTotalIncome: Double     // federal tax on salary + distribution
        let taxOnSalaryAlone: Double     // federal tax on salary only
        let incrementalTax: Double       // tax attributable to just the distribution
        let marginalRate: Double         // bracket rate on the last dollar of salary+distribution
        let salaryOnlyMarginalRate: Double // bracket rate on the last dollar of salary alone
        let effectiveRateOnDistribution: Double // incrementalTax / distribution
        let totalDrawdownYears: Int
        let totalTaxOverDrawdown: Double // incrementalTax × drawdownYears (approximate)

        /// True when the distribution pushes the heir into a higher bracket than their salary alone.
        var crossesBracket: Bool {
            marginalRate > salaryOnlyMarginalRate
        }
    }

    /// Calculates progressive federal tax impact on an heir receiving inherited IRA distributions.
    /// Returns marginal rate, effective rate, and dollar amounts based on current tax brackets.
    static func heirTaxEstimate(
        annualDistribution: Double,
        heirSalary: Double = 75_000,
        filingStatus: FilingStatus = .single,
        drawdownYears: Int = 10
    ) -> HeirTaxEstimate {
        let brackets = default2026Brackets
        let totalIncome = heirSalary + annualDistribution

        // Tax on combined income (salary + distribution)
        let taxOnTotal = calculateFederalTax(income: totalIncome, filingStatus: filingStatus, brackets: brackets, preferentialIncome: 0)

        // Tax on salary alone
        let taxOnSalary = calculateFederalTax(income: heirSalary, filingStatus: filingStatus, brackets: brackets, preferentialIncome: 0)

        // Incremental tax from the distribution
        let incremental = taxOnTotal - taxOnSalary

        // Find marginal rates (the bracket the last dollar of each income amount falls in)
        let ordinaryBrackets = filingStatus == .single
            ? brackets.federalSingle : brackets.federalMarried
        var marginal = 0.0
        var salaryMarginal = 0.0
        for bracket in ordinaryBrackets {
            if totalIncome > bracket.threshold {
                marginal = bracket.rate
            }
            if heirSalary > bracket.threshold {
                salaryMarginal = bracket.rate
            }
        }

        // Effective rate on just the distribution
        let effectiveOnDist = annualDistribution > 0 ? incremental / annualDistribution : 0

        return HeirTaxEstimate(
            annualDistribution: annualDistribution,
            heirSalary: heirSalary,
            totalIncome: totalIncome,
            taxOnTotalIncome: taxOnTotal,
            taxOnSalaryAlone: taxOnSalary,
            incrementalTax: incremental,
            marginalRate: marginal,
            salaryOnlyMarginalRate: salaryMarginal,
            effectiveRateOnDistribution: effectiveOnDist,
            totalDrawdownYears: drawdownYears,
            totalTaxOverDrawdown: incremental * Double(drawdownYears)
        )
    }

    // MARK: - Heir-Bracket Comparison (Phase 2 L3)

    /// Side-by-side comparison: pay tax now at the user's marginal rate vs heir pays
    /// it later at their marginal rate under a SECURE-Act 10-year drain. Positive
    /// `netFamilyBenefit` means converting now is cheaper for the family.
    struct HeirBracketComparison {
        let conversionAmount: Double
        let userMarginalRate: Double
        let heirMarginalRate: Double
        let userTaxIfConvertedNow: Double
        let heirTaxIfInheritedLater: Double
        let netFamilyBenefit: Double
    }

    /// Compare paying tax at the user's current marginal rate vs an heir paying tax
    /// at their marginal rate after a SECURE-Act 10-year drain. Positive
    /// `netFamilyBenefit` means converting now is cheaper for the family.
    static func convertNowVsHeirComparison(
        conversionAmount: Double,
        userMarginalRate: Double,
        heirMarginalRate: Double
    ) -> HeirBracketComparison {
        let userTax = conversionAmount * userMarginalRate
        let heirTax = conversionAmount * heirMarginalRate
        return HeirBracketComparison(
            conversionAmount: conversionAmount,
            userMarginalRate: userMarginalRate,
            heirMarginalRate: heirMarginalRate,
            userTaxIfConvertedNow: userTax,
            heirTaxIfInheritedLater: heirTax,
            netFamilyBenefit: heirTax - userTax
        )
    }

    /// Computes the effective tax rate on a given annual distribution amount using progressive brackets.
    /// Used by LegacyPlanningEngine as a replacement for flat-rate multiplication.
    static func heirEffectiveTaxRate(
        annualDistribution: Double,
        heirSalary: Double = 75_000,
        filingStatus: FilingStatus = .single
    ) -> Double {
        guard annualDistribution > 0 else { return 0 }
        let est = heirTaxEstimate(annualDistribution: annualDistribution, heirSalary: heirSalary, filingStatus: filingStatus)
        return est.effectiveRateOnDistribution
    }

    // MARK: - Widow Planning Helpers

    /// Approximate single-filer tax that the survivor would pay annually on the given
    /// pre-tax IRA RMD/distribution income, using progressive single-filer brackets.
    static func widowSurvivorAnnualTax(rmdIncome: Double) -> Double {
        let brackets = default2026Brackets
        return calculateFederalTax(income: rmdIncome, filingStatus: .single, brackets: brackets, preferentialIncome: 0)
    }

    /// Approximate MFJ tax on the given pre-tax IRA RMD/distribution income.
    static func widowMFJAnnualTax(rmdIncome: Double) -> Double {
        let brackets = default2026Brackets
        return calculateFederalTax(income: rmdIncome, filingStatus: .marriedFilingJointly, brackets: brackets, preferentialIncome: 0)
    }

    // MARK: - Federal Tax Breakdown (bracket-by-bracket)

    static func federalTaxBreakdown(income: Double, filingStatus: FilingStatus, brackets: TaxBrackets, preferentialIncome: Double) -> FederalTaxBreakdown {
        let capGains = max(0, preferentialIncome)
        let ordinaryIncome = max(0, income - capGains)

        let ordinaryBrackets = filingStatus == .single
            ? brackets.federalSingle : brackets.federalMarried

        // Build ordinary bracket lines
        var ordinaryLines: [FederalTaxBreakdown.BracketLine] = []
        var ordinaryTax = 0.0
        for i in ordinaryBrackets.indices {
            let bracket = ordinaryBrackets[i]
            if ordinaryIncome > bracket.threshold {
                let ceiling = i + 1 < ordinaryBrackets.count ? ordinaryBrackets[i + 1].threshold : nil
                let effectiveCeiling = ceiling ?? ordinaryIncome
                let taxable = min(ordinaryIncome, effectiveCeiling) - bracket.threshold
                let tax = taxable * bracket.rate
                ordinaryTax += tax
                ordinaryLines.append(FederalTaxBreakdown.BracketLine(
                    rate: bracket.rate,
                    bracketFloor: bracket.threshold,
                    bracketCeiling: ceiling,
                    taxableInBracket: taxable,
                    taxFromBracket: tax
                ))
            }
        }

        // Capital gains bracket lines (layered on top of ordinary income)
        var capGainsLines: [FederalTaxBreakdown.BracketLine] = []
        var capGainsTax = 0.0
        if capGains > 0 {
            let cgBrackets = filingStatus == .single
                ? brackets.federalCapGainsSingle : brackets.federalCapGainsMarried
            // Tax on total income at cap gains rates minus tax on ordinary portion
            let taxOnTotal = progressiveTax(income: income, brackets: cgBrackets)
            let taxOnOrdinary = progressiveTax(income: ordinaryIncome, brackets: cgBrackets)
            capGainsTax = taxOnTotal - taxOnOrdinary

            // Build per-bracket detail for the cap gains portion
            for i in cgBrackets.indices {
                let bracket = cgBrackets[i]
                let ceiling = i + 1 < cgBrackets.count ? cgBrackets[i + 1].threshold : nil
                let effectiveCeiling = ceiling ?? income
                // Portion of cap gains income in this bracket
                let bracketStart = max(ordinaryIncome, bracket.threshold)
                let bracketEnd = min(income, effectiveCeiling)
                if bracketEnd > bracketStart {
                    let taxable = bracketEnd - bracketStart
                    let tax = taxable * bracket.rate
                    capGainsLines.append(FederalTaxBreakdown.BracketLine(
                        rate: bracket.rate,
                        bracketFloor: bracket.threshold,
                        bracketCeiling: ceiling,
                        taxableInBracket: taxable,
                        taxFromBracket: tax
                    ))
                }
            }
        }

        return FederalTaxBreakdown(
            ordinaryIncome: ordinaryIncome,
            preferentialIncome: capGains,
            ordinaryBrackets: ordinaryLines,
            ordinaryTax: ordinaryTax,
            capGainsBrackets: capGainsLines,
            capGainsTax: capGainsTax,
            totalFederalTax: ordinaryTax + capGainsTax
        )
    }

    // MARK: - State Tax

    static func calculateStateTax(
        income: Double,
        forState state: USState,
        filingStatus: FilingStatus,
        taxableSocialSecurity: Double,
        incomeSources: [IncomeSource],
        currentAge: Int,
        enableSpouse: Bool,
        spouseBirthYear: Int,
        currentYear: Int,
        scenarioRetirementDistributions: Double = 0,
        scenarioRothConversionAmount: Double = 0
    ) -> Double {
        let config = StateTaxData.config(for: state)
        let spouseAge = currentYear - spouseBirthYear
        let adjustedIncome = applyRetirementExemptions(
            income: income,
            config: config,
            state: state,
            taxableSocialSecurity: taxableSocialSecurity,
            incomeSources: incomeSources,
            primaryAge: currentAge,
            spouseAge: spouseAge,
            enableSpouse: enableSpouse,
            scenarioRetirementDistributions: scenarioRetirementDistributions,
            scenarioRothConversionAmount: scenarioRothConversionAmount
        )

        var tax: Double
        switch config.taxSystem {
        case .noIncomeTax, .specialLimited:
            return 0
        case .flat(let rate):
            tax = max(0, adjustedIncome) * rate
        case .progressive(let single, let married):
            let brackets = filingStatus == .single ? single : married
            tax = progressiveTax(income: max(0, adjustedIncome), brackets: brackets)
        }

        if state == .california {
            tax -= californiaExemptionCredits(filingStatus: filingStatus, agi: adjustedIncome, currentAge: currentAge, enableSpouse: enableSpouse, spouseBirthYear: spouseBirthYear, currentYear: currentYear)
        }

        return max(0, tax)
    }

    // MARK: - California Exemption Credits

    static func californiaExemptionCredits(filingStatus: FilingStatus, agi: Double, currentAge: Int, enableSpouse: Bool, spouseBirthYear: Int, currentYear: Int) -> Double {
        let creditPerExemption = config.caExemptionCreditPerPerson

        var exemptions = 1
        if filingStatus == .marriedFilingJointly {
            exemptions += 1
        }

        if currentAge >= 65 {
            exemptions += 1
        }
        if filingStatus == .marriedFilingJointly && enableSpouse {
            let spouseAge = currentYear - spouseBirthYear
            if spouseAge >= 65 {
                exemptions += 1
            }
        }

        let totalCredit = Double(exemptions) * creditPerExemption

        let phaseoutThreshold = filingStatus == .single ? config.caExemptionPhaseoutSingle : config.caExemptionPhaseoutMFJ
        if agi > phaseoutThreshold {
            let excess = agi - phaseoutThreshold
            let reduction = (excess / 2_500).rounded(.down) * config.caExemptionPhaseoutReductionPer2500
            return max(0, totalCredit - reduction)
        }

        return totalCredit
    }

    // MARK: - Retirement Income Exemptions

    static func applyRetirementExemptions(
        income: Double,
        config: StateTaxConfig,
        state: USState,
        taxableSocialSecurity: Double,
        incomeSources: [IncomeSource],
        primaryAge: Int,
        spouseAge: Int,
        enableSpouse: Bool,
        scenarioRetirementDistributions: Double = 0,
        scenarioRothConversionAmount: Double = 0
    ) -> Double {
        // TODO(post-1.8.3): Several refinements outside this fix:
        // - Verified-2026 exemption value updates: CO unlimited (SB25-136, currently
        //   $24K), AL $12K age 65+ (HB388, currently $2,500), MD $40,600 age 65+
        //   (employer pensions only, not IRA), MI $67,610/$135,220 final phase-in
        //   (currently `.full` overstates), KY HB146 status, GA's $35K 62-64 tier.
        // - Per-state age thresholds (NJ 62, CO pre-SB25-136 was 65) — we use a
        //   flat 59½ baseline here for `scenarioRetirementDistributions`.
        // - When the engine can distinguish pension vs IRA portions of
        //   `scenarioRetirementDistributions` separately, apply pensionExemption
        //   and iraWithdrawalExemption independently rather than reusing the
        //   IRA-withdrawal exemption level alone.
        var adjusted = income
        let exemptions = config.retirementExemptions

        if exemptions.socialSecurityExempt {
            adjusted -= taxableSocialSecurity
        }

        // Effective pension/IRA exemption level given the taxpayer's age:
        //   1) If `regularExemptionMinAge` is set and the user is at/above it,
        //      use the regular pensionExemption/iraWithdrawalExemption field.
        //   2) Else if `earlyAgeTier` is set and the user falls in its range,
        //      use the tier's `level` for both pension and IRA.
        //   3) Otherwise the exemption is .none.
        // Per-individual rule: for MFJ where each spouse may qualify at a
        // different tier, take the most-generous tier that EITHER spouse
        // qualifies for. This is a conservative planning-tool approximation
        // (state law generally allows each spouse their own tier based on
        // their own age and income, but our engine doesn't yet attribute
        // pension/IRA dollars per-spouse).
        let effectiveAge = enableSpouse ? max(primaryAge, spouseAge) : primaryAge
        let minAge = exemptions.regularExemptionMinAge

        // Whether a given spouse's age qualifies them for ANY level of
        // the state's retirement exemption (regular tier OR earlyAgeTier).
        // Used for per-individual cap doubling — both spouses must
        // independently qualify to merit doubling the cap. States with no
        // explicit age gate fall back to the 59½ statutory baseline used
        // by NY § 612(c)(3-a) and most similar per-individual states.
        func ageQualifiesForExemption(_ age: Int) -> Bool {
            if minAge > 0 {
                if age >= minAge { return true }
                if let tier = exemptions.earlyAgeTier, tier.ageRange.contains(age) {
                    return true
                }
                return false
            }
            return age >= 59
        }

        // Per-individual cap multiplier: when MFJ AND BOTH spouses individually
        // qualify for the state's exemption AND the state's exemption applies
        // per-taxpayer rather than per-return, the partial cap is doubled.
        // Used by NY ($20K per IT-201) and GA ($35K/$65K per O.C.G.A. § 48-7-27).
        let bothSpousesQualify = enableSpouse
            && ageQualifiesForExemption(primaryAge)
            && ageQualifiesForExemption(spouseAge)
        let perIndividualMultiplier: Double =
            (exemptions.exemptionAppliesPerIndividual && bothSpousesQualify) ? 2.0 : 1.0

        func resolveLevel(regular: RetirementIncomeExemptions.ExemptionLevel) -> RetirementIncomeExemptions.ExemptionLevel {
            if minAge > 0 {
                if effectiveAge >= minAge {
                    return regular
                }
                if let tier = exemptions.earlyAgeTier, tier.ageRange.contains(effectiveAge) {
                    return tier.level
                }
                return .none
            }
            // No min-age gate: keep existing behavior (regular exemption applies
            // regardless of age; scenario-distribution age gating still happens
            // separately below).
            return regular
        }

        let effectivePensionExemption = resolveLevel(regular: exemptions.pensionExemption)
        let effectiveIRAExemption = resolveLevel(regular: exemptions.iraWithdrawalExemption)

        let pensionIncome = incomeSources.filter { $0.type == .pension }.reduce(0) { $0 + $1.annualAmount }

        // Sum of state-recognized IRA-withdrawal income:
        //   1) `.rmd`-typed IncomeSource rows (demo profile / explicit entries), plus
        //   2) `scenarioRetirementDistributions` — RMDs computed from IRA balances,
        //      inherited-IRA RMDs, and extra withdrawals. These don't appear as
        //      IncomeSource rows but flow into scenarioGrossIncome via
        //      scenarioTotalWithdrawals. Age-gate the scenario portion at 59½
        //      (early-withdrawal IRA distributions are taxable in PA and most
        //      states); user-entered `.rmd` rows are not gated because they
        //      implicitly represent retirement-age income.
        let rmdSourceIncome = incomeSources.filter { $0.type == .rmd }.reduce(0) { $0 + $1.annualAmount }
        let retirementAge = primaryAge >= 59 || (enableSpouse && spouseAge >= 59)
        let scenarioExemptable = retirementAge ? scenarioRetirementDistributions : 0
        let iraIncome = rmdSourceIncome + scenarioExemptable

        if exemptions.pensionAndIRAShareSingleCap {
            // Shared-cap state (e.g., CO C.R.S. § 39-22-104(4)(f)): pension
            // and IRA distributions are combined and subjected to ONE annual
            // subtraction cap. Use the effective pension exemption level (the
            // pension and IRA fields should be set to the same value when
            // this flag is true; we ignore the IRA-side level here to avoid
            // double-counting).
            let combinedIncome = pensionIncome + iraIncome
            switch effectivePensionExemption {
            case .full:
                adjusted -= combinedIncome
            case .partial(let maxExempt):
                adjusted -= min(combinedIncome, maxExempt * perIndividualMultiplier)
            case .none:
                break
            }
        } else {
            // Standard per-type application: each type's cap applied independently.
            switch effectivePensionExemption {
            case .full:
                adjusted -= pensionIncome
            case .partial(let maxExempt):
                adjusted -= min(pensionIncome, maxExempt * perIndividualMultiplier)
            case .none:
                break
            }
            switch effectiveIRAExemption {
            case .full:
                adjusted -= iraIncome
            case .partial(let maxExempt):
                adjusted -= min(iraIncome, maxExempt * perIndividualMultiplier)
            case .none:
                break
            }
        }

        // Military Retirement: per-state exemption applied per-source using the
        // owner's age (Iowa is age-55-conditional; some states have age cliffs).
        // Federal side is unchanged — military retirement remains fully taxable
        // as ordinary income (treated like .pension in `ordinaryIncomeSubtotal`).
        let stateCode = state.abbreviation
        for source in incomeSources where source.type == .militaryRetirement {
            let ownerAge: Int
            switch source.owner {
            case .primary: ownerAge = primaryAge
            case .spouse:  ownerAge = enableSpouse ? spouseAge : primaryAge
            case .joint:   ownerAge = enableSpouse ? max(primaryAge, spouseAge) : primaryAge
            }
            let stillTaxable = MilitaryRetirementExemption.stateTaxableAmount(
                gross: source.annualAmount,
                stateCode: stateCode,
                age: ownerAge
            )
            let exemptPortion = source.annualAmount - stillTaxable
            adjusted -= exemptPortion
        }

        // Roth conversion exemption (v1.8.3): PA per DOR Ans 274 holds that a
        // trustee-to-trustee Roth conversion is NOT a taxable event in PA in
        // the conversion year. Illinois (IL Pub 120) and Mississippi (MS Code
        // §27-7-15(4)(j)) follow the same treatment per practitioner consensus.
        // Critically this exemption is NOT age-gated — Ans 274 imposes no
        // retirement-age condition on the conversion itself. We therefore apply
        // it independently of `scenarioRetirementDistributions`, which retains
        // its 59½ gate for distributions.
        switch state {
        case .pennsylvania, .illinois, .mississippi:
            adjusted -= scenarioRothConversionAmount
        default:
            break
        }

        return max(0, adjusted)
    }

    // MARK: - IRMAA

    static func calculateIRMAA(magi: Double, filingStatus: FilingStatus) -> IRMAAResult {
        let tiers = irmaa2026Tiers
        let standardB = irmaaStandardPartB

        let roundedMAGI = magi.rounded()
        var matchedTier = tiers[0]
        for tier in tiers.reversed() {
            let threshold = filingStatus == .single ? tier.singleThreshold : tier.mfjThreshold
            if roundedMAGI >= threshold {
                matchedTier = tier
                break
            }
        }

        let surchargeB = matchedTier.partBMonthly - standardB
        let surchargeD = matchedTier.partDMonthly
        let annualSurcharge = (surchargeB + surchargeD) * 12

        let nextTierIndex = matchedTier.tier + 1
        var distanceToNext: Double? = nil
        if nextTierIndex < tiers.count {
            let nextThreshold = filingStatus == .single
                ? tiers[nextTierIndex].singleThreshold
                : tiers[nextTierIndex].mfjThreshold
            distanceToNext = nextThreshold - magi
        }

        var distanceToPrevious: Double? = nil
        if matchedTier.tier > 0 {
            let currentThreshold = filingStatus == .single
                ? matchedTier.singleThreshold
                : matchedTier.mfjThreshold
            distanceToPrevious = magi - currentThreshold
        }

        return IRMAAResult(
            tier: matchedTier.tier,
            annualSurchargePerPerson: annualSurcharge,
            monthlyPartB: matchedTier.partBMonthly,
            monthlyPartD: matchedTier.partDMonthly,
            distanceToNextTier: distanceToNext,
            distanceToPreviousTier: distanceToPrevious,
            magi: magi
        )
    }

    /// Strongly-typed overload — forwards to the legacy `Double` overload.
    /// Prevents callers from accidentally passing FederalAGI or ACAMAGI.
    static func calculateIRMAA(magi: IRMAAMAGI, filingStatus: FilingStatus) -> IRMAAResult {
        calculateIRMAA(magi: magi.value, filingStatus: filingStatus)
    }

    // MARK: - NIIT

    static func calculateNIIT(nii: Double, magi: Double, filingStatus: FilingStatus) -> NIITResult {
        let threshold = filingStatus == .single ? niitThresholdSingle : niitThresholdMFJ

        let roundedMAGI = magi.rounded()
        let magiExcess = max(0, roundedMAGI - threshold)
        let taxableNII = min(nii, magiExcess)
        let tax = taxableNII * niitRate
        let distance = threshold - roundedMAGI

        return NIITResult(
            netInvestmentIncome: nii,
            magi: magi,
            threshold: threshold,
            magiExcess: magiExcess,
            taxableNII: taxableNII,
            annualNIITax: tax,
            distanceToThreshold: distance
        )
    }

    // MARK: - AMT

    static func calculateAMT(taxableIncome: Double, regularTax: Double, filingStatus: FilingStatus, scenarioEffectiveItemize: Bool, saltAfterCap: Double, deductibleMedicalExpenses: Double, preferentialIncome: Double, brackets: TaxBrackets) -> AMTResult {
        var addBacks = 0.0
        if scenarioEffectiveItemize {
            addBacks += saltAfterCap
            addBacks += deductibleMedicalExpenses
        }
        let amti = taxableIncome + addBacks

        let baseExemption = filingStatus == .single ? amtExemptionSingle : amtExemptionMFJ
        let phaseoutThreshold = filingStatus == .single ? amtPhaseoutThresholdSingle : amtPhaseoutThresholdMFJ
        let phaseout = max(0, (amti.rounded() - phaseoutThreshold) * amtPhaseoutRate)
        let exemption = max(0, baseExemption - phaseout)

        let taxableAMTI = max(0, amti - exemption)

        let capGains = max(0, preferentialIncome)
        let ordinaryAMTI = max(0, taxableAMTI - capGains)

        var tmt = 0.0
        if ordinaryAMTI <= amt26PercentLimit {
            tmt = ordinaryAMTI * amtRate26
        } else {
            tmt = amt26PercentLimit * amtRate26
                + (ordinaryAMTI - amt26PercentLimit) * amtRate28
        }

        if capGains > 0 {
            let capGainsBrackets = filingStatus == .single
                ? brackets.federalCapGainsSingle : brackets.federalCapGainsMarried
            let taxOnTotal = progressiveTax(income: taxableAMTI, brackets: capGainsBrackets)
            let taxOnOrdinary = progressiveTax(income: ordinaryAMTI, brackets: capGainsBrackets)
            tmt += taxOnTotal - taxOnOrdinary
        }

        let amt = max(0, tmt - regularTax)

        return AMTResult(
            amti: amti,
            exemption: exemption,
            taxableAMTI: taxableAMTI,
            tentativeMinimumTax: tmt,
            regularTax: regularTax,
            amt: amt
        )
    }

    // MARK: - SS Taxation

    static func calculateTaxableSocialSecurity(filingStatus: FilingStatus, additionalIncome: Double, incomeSources: [IncomeSource]) -> Double {
        let ssIncome = incomeSources
            .filter { $0.type == .socialSecurity }
            .reduce(0.0) { $0 + $1.annualAmount }

        // VA Disability is excluded from provisional income per IRC §104(a)(4) —
        // it is never in gross income and therefore never in the combined-income test.
        let otherIncome = incomeSources
            .filter { $0.type != .socialSecurity && $0.type != .vaDisability }
            .reduce(0.0) { $0 + $1.annualAmount }

        let combinedIncome = otherIncome + additionalIncome + (ssIncome * 0.5)
        let roundedCombined = combinedIncome.rounded()
        let (threshold1, threshold2) = filingStatus == .single
            ? (config.ssTaxationThreshold1Single, config.ssTaxationThreshold2Single)
            : (config.ssTaxationThreshold1MFJ, config.ssTaxationThreshold2MFJ)

        if roundedCombined <= threshold1 {
            return 0.0
        } else if roundedCombined <= threshold2 {
            let excessOverFirst = roundedCombined - threshold1
            return min(excessOverFirst, ssIncome * 0.5)
        } else {
            let excessOverSecond = roundedCombined - threshold2
            let tier1Amount = (threshold2 - threshold1) * 0.5
            let tier2Amount = min(excessOverSecond * 0.85, ssIncome * 0.85 - tier1Amount)
            return min(tier1Amount + tier2Amount, ssIncome * 0.85)
        }
    }

    // MARK: - Bracket Info

    static func bracketInfo(income: Double, brackets: [TaxBracket]) -> BracketInfo {
        for i in brackets.indices.reversed() {
            if income > brackets[i].threshold {
                let isTopBracket = i == brackets.count - 1
                let nextThreshold = isTopBracket ? Double.infinity : brackets[i + 1].threshold
                let room = isTopBracket ? 0 : nextThreshold - income
                return BracketInfo(
                    currentRate: brackets[i].rate,
                    currentThreshold: brackets[i].threshold,
                    nextThreshold: nextThreshold,
                    roomRemaining: max(0, room)
                )
            }
        }
        let first = brackets.first!
        let nextThreshold = brackets.count > 1 ? brackets[1].threshold : Double.infinity
        return BracketInfo(
            currentRate: first.rate,
            currentThreshold: first.threshold,
            nextThreshold: nextThreshold,
            roomRemaining: max(0, nextThreshold - income)
        )
    }
}
