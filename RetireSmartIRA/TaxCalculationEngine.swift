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
        /// Phase 3b Task 3: optional, additive alongside
        /// `scenarioRetirementDistributions`. `nil` short-circuits straight
        /// to the scalar -- it does not construct an `.unknown`/`.unknown`
        /// component -- which is numerically today's behavior exactly; see
        /// `RetirementDistributionComponent.resolvePooledAmount`. When
        /// supplied, the components' amounts must sum to
        /// `scenarioRetirementDistributions` within one cent (spec 3.4).
        distributionComponents: [RetirementDistributionComponent]? = nil,
        scenarioRothConversionAmount: Double = 0,
        scenarioRothConversionWithholdingAmount: Double = 0,
        postExemptionDeduction: Double = 0,
        localIncomeTaxRate: Double = 0,
        /// Test-only seam. When non-nil, bypasses the `StateTaxData` lookup so a
        /// caller can exercise this function against a specific configuration.
        /// The Phase 1 equivalence gate uses it to run the JSON-loaded and legacy
        /// tables through identical code. Production always passes nil.
        configOverride: StateTaxConfig? = nil
    ) -> Double {
        let config = configOverride ?? StateTaxData.config(for: state)
        let spouseAge = currentYear - spouseBirthYear
        let exemptedIncome = applyRetirementExemptions(
            income: income,
            config: config,
            state: state,
            filingStatus: filingStatus,
            taxableSocialSecurity: taxableSocialSecurity,
            incomeSources: incomeSources,
            primaryAge: currentAge,
            spouseAge: spouseAge,
            enableSpouse: enableSpouse,
            scenarioRetirementDistributions: scenarioRetirementDistributions,
            distributionComponents: distributionComponents,
            scenarioRothConversionAmount: scenarioRothConversionAmount,
            scenarioRothConversionWithholdingAmount: scenarioRothConversionWithholdingAmount
        )

        // Personal exemptions / similar post-exclusion deductions (e.g. NJ's
        // $1,000-per-filer personal exemptions) reduce taxable income AFTER the
        // retirement-income exclusions and their income-gated phaseouts — they
        // do not shift the NJ Worksheet exclusion bands, which key off total
        // income (line 27).
        let adjustedIncome = max(0, exemptedIncome - postExemptionDeduction)

        var tax: Double
        switch config.taxSystem {
        case .noIncomeTax, .specialLimited:
            tax = 0
        case .flat(let rate):
            tax = max(0, adjustedIncome) * rate
        case .progressive(let single, let married):
            let brackets = filingStatus == .single ? single : married
            tax = progressiveTax(income: max(0, adjustedIncome), brackets: brackets)
        }

        if state == .california {
            tax -= californiaExemptionCredits(filingStatus: filingStatus, agi: adjustedIncome, currentAge: currentAge, enableSpouse: enableSpouse, spouseBirthYear: spouseBirthYear, currentYear: currentYear)
        }

        // User-entered local/city income tax (Alan 2nd-round). A flat rate on the same
        // state-taxable base (after retirement exclusions + deductions), folded into the
        // returned state figure. Applies regardless of the state's own income-tax system
        // (e.g. a locality in a no-state-income-tax state). Rate 0 → byte-identical to before.
        let localTax = max(0, adjustedIncome) * max(0, localIncomeTaxRate)

        return max(0, tax) + localTax
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

    // MARK: - New Jersey Personal Exemptions

    /// NJ-1040 personal exemptions (NJ has no standard deduction). Each filer
    /// (and spouse, if MFJ/`enableSpouse`) gets a $1,000 regular exemption, plus
    /// an additional $1,000 per filer/spouse age 65+. Amounts are statutory and
    /// stable for 2026. Subtracted from NJ taxable income by the caller.
    ///
    ///   single, under 65   → $1,000
    ///   single, 65+        → $2,000
    ///   MFJ, both under 65 → $2,000
    ///   MFJ, both 65+      → $4,000
    ///
    /// Retained for tests that predate Phase 3a. New Jersey's amounts now live
    /// in `StateTaxConfig.personalExemption`; this delegates so there is one
    /// implementation rather than two that can drift.
    static func njPersonalExemptions(
        filingStatus: FilingStatus,
        enableSpouse: Bool,
        primaryAge: Int,
        spouseAge: Int
    ) -> Double {
        guard let exemption = StateTaxData.config(for: .newJersey).personalExemption else {
            return 0
        }
        return exemption.amount(filingStatus: filingStatus, enableSpouse: enableSpouse,
                                primaryAge: primaryAge, spouseAge: spouseAge)
    }

    // MARK: - Retirement Income Exemptions

    static func applyRetirementExemptions(
        income: Double,
        config: StateTaxConfig,
        state: USState,
        filingStatus: FilingStatus = .single,
        taxableSocialSecurity: Double,
        incomeSources: [IncomeSource],
        primaryAge: Int,
        spouseAge: Int,
        enableSpouse: Bool,
        scenarioRetirementDistributions: Double = 0,
        /// Phase 3b Task 3: see `calculateStateTax`'s parameter of the same
        /// name. Pooled with `RetirementDistributionComponent.resolvePooledAmount`
        /// below and handed to the SAME age-gate/exemption logic the scalar
        /// already uses -- never evaluated per component.
        distributionComponents: [RetirementDistributionComponent]? = nil,
        scenarioRothConversionAmount: Double = 0,
        scenarioRothConversionWithholdingAmount: Double = 0
    ) -> Double {
        // Known gaps, superseded by the 2026-08-02 full 51-jurisdiction audit.
        // DO NOT action items from this comment. The authoritative list is
        // docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md,
        // and every correction is gated on Phase 5 of that program, each backed by
        // a golden scenario derived from the state's own published form.
        //
        // The prior version of this comment listed "CO unlimited (SB25-136)" as
        // pending work. That is WRONG and acting on it would break a jurisdiction
        // that is currently CORRECT: SB25-136 was postponed indefinitely on
        // 2025-02-27 and never became law. Colorado's $24,000 age-65+ and $20,000
        // age-55-to-64 tiers are right and must not be changed. The same comment
        // also reported Alabama's current value as $2,500, which is Arizona's;
        // Alabama is configured `.none`.
        //
        // Still open and confirmed by the audit: this function cannot apply
        // `pensionExemption` and `iraWithdrawalExemption` independently, because
        // `scenarioRetirementDistributions` is not split by source.
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
            return age >= exemptions.distributionMinAge
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

        /// Whether income owned by `owner` is eligible under the state's
        /// attribution rule. Under `.household` every row is eligible when any
        /// spouse qualifies, which is what `effectiveAge` already encodes.
        func ownerQualifies(_ owner: Owner) -> Bool {
            guard exemptions.exemptionAttribution == .perQualifyingSpouse, enableSpouse else {
                return true
            }
            switch owner {
            case .primary: return ageQualifiesForExemption(primaryAge)
            case .spouse:  return ageQualifiesForExemption(spouseAge)
            case .joint:   return ageQualifiesForExemption(primaryAge)
                                || ageQualifiesForExemption(spouseAge)
            }
        }

        // Used both by the per-source partition below and by the existing
        // cap machinery further down (hoisted so both share one value).
        let isMarried = filingStatus == .marriedFilingJointly

        // Phase 5b Task 9: the age a per-source rule's `matchMinAge` is tested
        // against, for a row belonging to `owner`. Deliberately the OWNER's own
        // age rather than `effectiveAge` (the household maximum every pooled
        // gate in this function uses): D.C. Code Section 47-1803.02(a)(2)(N)(ii)
        // conditions on the age of the person RECEIVING the survivor benefit,
        // so a 55-year-old widow does not qualify because her 65-year-old
        // spouse would. Same owner-age resolution the military-retirement block
        // further down already performs.
        func ageOf(_ owner: Owner) -> Int {
            switch owner {
            case .primary: return primaryAge
            case .spouse:  return enableSpouse ? spouseAge : primaryAge
            case .joint:   return enableSpouse ? max(primaryAge, spouseAge) : primaryAge
            }
        }

        // Phase 3b Task 4 (design doc 3.4a): partition BEFORE any pooling or
        // cap logic runs. Each qualifying `.pension` row is tested against
        // `exemptions.perSourceExemptions`; a match is excluded per its own
        // rule's `treatment`, and contributes NOTHING
        // to `pensionIncome`, the pooled figure the cap machinery below
        // consumes. This is a single pass over the rows, never a cap
        // evaluated inside a loop -- see RetirementDistributionComponent.swift's
        // file-level doc comment for why that distinction is the single
        // largest correctness risk in this phase. When
        // `exemptions.perSourceExemptions` is empty (every jurisdiction
        // except New York), `matchedPerSourceRule` returns `nil` for every
        // row and this reduces to exactly the old single `.reduce`.
        //
        // NO AGE GATE UNLESS THE RULE ASKS FOR ONE. Phase 3b Task 4 stated this
        // partition as unconditional on age outright, because New York's Line
        // 26 government-pension exclusion has none, and Kansas's,
        // Massachusetts's and Arizona's do not either. Phase 5b Task 9 made it
        // conditional on the RULE: `PerSourceExemptionRule.matchMinAge` is nil
        // for all four of those, so they are unchanged, and it is 62 for the
        // District of Columbia, whose survivor exclusion under D.C. Code
        // 47-1803.02(a)(2)(N)(ii) grants nothing below that age. The age passed
        // is the ROW OWNER's, not `effectiveAge`: the statute conditions on the
        // age of the person RECEIVING the benefit, so a 55-year-old widow does
        // not qualify on a 65-year-old spouse's age. Deliberately NOT
        // `regularExemptionMinAge`, which gates the POOLED levels through
        // `resolveLevel` and is household-wide.
        let qualifyingPensionRows = incomeSources.filter { $0.type == .pension && ownerQualifies($0.owner) }
        var pensionIncome = 0.0
        var perSourceExcludedPension = 0.0
        for row in qualifyingPensionRows {
            if let rule = exemptions.matchedPerSourceRule(
                structure: row.planStructure, source: row.planSource,
                isSurvivorBenefit: row.isSurvivorBenefit, age: ageOf(row.owner)) {
                perSourceExcludedPension += rule.treatment.excludedAmount(
                    eligibleIncome: row.annualAmount, totalGrossIncome: income,
                    isMarried: isMarried, perIndividualMultiplier: 1.0)
            } else {
                pensionIncome += row.annualAmount
            }
        }

        // Sum of state-recognized IRA-withdrawal income:
        //   1) `.rmd`-typed IncomeSource rows (demo profile / explicit entries), plus
        //   2) `scenarioRetirementDistributions` — RMDs computed from IRA balances,
        //      inherited-IRA RMDs, and extra withdrawals. These don't appear as
        //      IncomeSource rows but flow into scenarioGrossIncome via
        //      scenarioTotalWithdrawals. Age-gate the scenario portion at 59½
        //      (early-withdrawal IRA distributions are taxable in PA and most
        //      states); user-entered `.rmd` rows are not gated because they
        //      implicitly represent retirement-age income.
        //
        // Same partition as pension rows above, applied to `.rmd` rows.
        let qualifyingRMDRows = incomeSources.filter { $0.type == .rmd && ownerQualifies($0.owner) }
        var rmdSourceIncome = 0.0
        var perSourceExcludedRMD = 0.0
        for row in qualifyingRMDRows {
            if let rule = exemptions.matchedPerSourceRule(
                structure: row.planStructure, source: row.planSource,
                isSurvivorBenefit: row.isSurvivorBenefit, age: ageOf(row.owner)) {
                perSourceExcludedRMD += rule.treatment.excludedAmount(
                    eligibleIncome: row.annualAmount, totalGrossIncome: income,
                    isMarried: isMarried, perIndividualMultiplier: 1.0)
            } else {
                rmdSourceIncome += row.annualAmount
            }
        }
        // Under `.perQualifyingSpouse` the scalar has no owner to attribute it
        // to, so it is gated on the primary. See ExemptionAttribution.
        let retirementAge: Bool
        switch exemptions.exemptionAttribution {
        case .household:
            retirementAge = primaryAge >= exemptions.distributionMinAge
                || (enableSpouse && spouseAge >= exemptions.distributionMinAge)
        case .perQualifyingSpouse:
            // Both conditions, because either alone leaks. `distributionMinAge`
            // alone would admit a primary who fails the state's real age gate,
            // who would then draw a level computed from `effectiveAge`, the
            // household maximum. `ageQualifiesForExemption` alone would admit a
            // primary who clears only an `earlyAgeTier` but sits below the
            // 59.5 distribution floor: Colorado and Georgia both ship
            // `earlyAgeTier: 55...64` with `distributionMinAge: 59`, so a
            // 57-year-old would pass. Requiring both closes each gap, and
            // reduces to the plain `primaryAge >= distributionMinAge`
            // comparison whenever `regularExemptionMinAge` is 0, which is NOT
            // true for every state (NY 59, NJ 62, CO 65, GA 65 all ship a
            // nonzero value). No state ships `.perQualifyingSpouse` as of
            // Phase 3a, so the gap this closes was latent, not live.
            retirementAge = primaryAge >= exemptions.distributionMinAge
                && ageQualifiesForExemption(primaryAge)
        }
        // Phase 3b Task 4: partition distributionComponents (if supplied) the
        // same way, BEFORE pooling. A component matching a per-source rule is
        // excluded outright and removed from BOTH the amount fed to the sum
        // invariant and the pool the age-gated cap machinery below sees. When
        // `distributionComponents` is nil, `matchedComponents` is empty and
        // the adjusted scalar equals the original scalar exactly, so
        // `resolvePooledAmount` still takes its nil short-circuit unchanged
        // -- this partition is a pure no-op for every one of the 42
        // pre-existing scalar-only call sites and for every jurisdiction
        // other than New York.
        let allComponents = distributionComponents ?? []
        // Phase 5b Task 9: one closure, three call sites, so the survivor and
        // age arguments cannot drift between the two filters and the sum.
        func componentRule(_ component: RetirementDistributionComponent) -> PerSourceExemptionRule? {
            exemptions.matchedPerSourceRule(
                structure: component.structure, source: component.source,
                isSurvivorBenefit: component.isSurvivorBenefit, age: ageOf(component.owner))
        }
        let matchedComponents = allComponents.filter { componentRule($0) != nil }
        let unmatchedComponents = allComponents.filter { componentRule($0) == nil }
        let perSourceExcludedComponents = matchedComponents.reduce(0.0) { total, component in
            guard let rule = componentRule(component) else { return total }
            return total + rule.treatment.excludedAmount(
                eligibleIncome: component.amount, totalGrossIncome: income,
                isMarried: isMarried, perIndividualMultiplier: 1.0)
        }
        let matchedComponentsAmount = matchedComponents.reduce(0.0) { $0 + $1.amount }
        // Phase 3b Task 3: pool distributionComponents (or short-circuit
        // straight to the scalar when nil -- no component is synthesized)
        // into ONE figure BEFORE the age gate, exactly reproducing
        // scenarioRetirementDistributions when nil or when the invariant
        // holds. See RetirementDistributionComponent.resolvePooledAmount.
        let pooledScenarioDistribution = RetirementDistributionComponent.resolvePooledAmount(
            components: distributionComponents == nil ? nil : unmatchedComponents,
            scalar: scenarioRetirementDistributions - matchedComponentsAmount
        )
        let scenarioExemptable = retirementAge ? pooledScenarioDistribution : 0
        let iraIncome = rmdSourceIncome + scenarioExemptable

        // The three matched, outright-excluded sums above -- pension rows,
        // RMD rows, and distribution components -- are subtracted here, ONCE,
        // independent of the cap machinery below, which never sees them
        // (design doc 3.4a step 2: "contribute nothing to any shared cap").
        // Zero for every jurisdiction except New York, and zero for New York
        // too unless a row/component actually carries a matching
        // classification.
        adjusted -= (perSourceExcludedPension + perSourceExcludedRMD + perSourceExcludedComponents)

        if exemptions.pensionAndIRAShareSingleCap {
            // Shared-cap state (e.g., CO C.R.S. § 39-22-104(4)(f)): pension
            // and IRA distributions are combined and subjected to ONE annual
            // subtraction cap. Use the effective pension exemption level (the
            // pension and IRA fields should be set to the same value when
            // this flag is true; we ignore the IRA-side level here to avoid
            // double-counting).
            // The stepped phaseout (NJ) gates on TOTAL state gross income —
            // the original `income` argument, before SS/exemption subtraction.
            // (`isMarried` is hoisted above, shared with the per-source
            // partition.)
            let combinedIncome = pensionIncome + iraIncome
            let rawExclusion = effectivePensionExemption.excludedAmount(
                eligibleIncome: combinedIncome,
                totalGrossIncome: income,
                isMarried: isMarried,
                perIndividualMultiplier: perIndividualMultiplier
            )
            let pensionIRAExclusion = exemptions.agiPhaseout?.reduced(
                exclusion: rawExclusion, totalGrossIncome: income, isMarried: isMarried
            ) ?? rawExclusion
            adjusted -= pensionIRAExclusion

            // NOTE for Phase 5: `chartMax` derives from the UNREDUCED exemption
            // level, so a smaller `pensionIRAExclusion` makes `unused` larger.
            // A state carrying all three of `.steppedPhaseoutByFilingStatus`,
            // `otherRetirementIncomeExclusion` and an `agiPhaseout` would hand
            // back through this block what the phase-out just took, up to
            // `chartMax`. Unreachable today: `chartMax` is 0 for every level
            // except the stepped one, New Jersey is the only state setting
            // `otherRetirementIncomeExclusion`, and it has no `agiPhaseout`.
            // NJ-1040 Worksheet D — Other Retirement Income Exclusion.
            // The UNUSED chart maximum (chartMax − pension/IRA exclusion)
            // shelters OTHER eligible income when the taxpayer is at/above the
            // exemption age, total gross income ≤ $150,000, and earned income
            // (NJ lines 15+18+21+22 ≈ `.consulting`) ≤ $3,000.
            if exemptions.otherRetirementIncomeExclusion {
                let earnedIncome = incomeSources
                    .filter { $0.type == .consulting }
                    .reduce(0) { $0 + $1.annualAmount }
                let ageQualifies = effectiveAge >= max(minAge, 1)
                if ageQualifies && income <= 150_000 && earnedIncome <= 3_000 {
                    let chartMax = effectivePensionExemption.chartMax(
                        totalGrossIncome: income, isMarried: isMarried)
                    let unused = max(0, chartMax - pensionIRAExclusion)
                    // Other eligible income = everything still in NJ taxable
                    // income after the SS exemption and the pension/IRA
                    // exclusion, minus earned income (which is not eligible).
                    // `adjusted` already reflects both subtractions here.
                    let otherEligible = max(0, adjusted - earnedIncome)
                    let otherExclusion = min(unused, otherEligible)
                    adjusted -= otherExclusion
                }
            }
        } else {
            // Standard per-type application: each type's cap applied
            // independently. (`isMarried` is hoisted above.)
            let rawPension = effectivePensionExemption.excludedAmount(
                eligibleIncome: pensionIncome,
                totalGrossIncome: income,
                isMarried: isMarried,
                perIndividualMultiplier: perIndividualMultiplier
            )
            adjusted -= exemptions.agiPhaseout?.reduced(
                exclusion: rawPension, totalGrossIncome: income, isMarried: isMarried
            ) ?? rawPension

            let rawIRA = effectiveIRAExemption.excludedAmount(
                eligibleIncome: iraIncome,
                totalGrossIncome: income,
                isMarried: isMarried,
                perIndividualMultiplier: perIndividualMultiplier
            )
            adjusted -= exemptions.agiPhaseout?.reduced(
                exclusion: rawIRA, totalGrossIncome: income, isMarried: isMarried
            ) ?? rawIRA
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

        // Roth conversion treatment, config-driven since Phase 3a. The rule
        // and the Ans 274 withholding caveat that used to live in a
        // `switch state` here now live on each state's config; see
        // RothConversionExemption for the citations.
        //
        // The age gate compares against `effectiveAge`, the household maximum
        // (`max(primaryAge, spouseAge)` when a spouse is enabled), matching
        // every other age gate in this function. No state is age-gated in
        // Phase 3a, so this branch is unreachable today and this choice
        // decides nothing yet. Iowa's Phase 5a golden scenario is what will
        // decide whether a conversion should be gated on the household
        // maximum or on the converting owner's own age.
        if let conversionRule = exemptions.rothConversionExemption {
            let qualifies = conversionRule.minAge == 0
                || effectiveAge >= conversionRule.minAge
            if qualifies {
                let exemptAmount = conversionRule.withheldPortionRemainsTaxable
                    ? max(0, scenarioRothConversionAmount - scenarioRothConversionWithholdingAmount)
                    : scenarioRothConversionAmount
                adjusted -= exemptAmount
            }
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
            // IRC §86(a)(1): gross income includes the LESSER of (A) one-half of the
            // benefits or (B) one-half of the excess of provisional income over the
            // base amount. Both limbs are halved — the excess in (B) just as much as
            // the benefits in (A). Returning the full excess overstated taxable
            // benefits by up to 2x for single filers between $25,000 and $34,000 of
            // provisional income (MFJ $32,000-$44,000), and made taxable SS fall
            // discontinuously as provisional income crossed the second threshold.
            let excessOverFirst = roundedCombined - threshold1
            return min(excessOverFirst * 0.5, ssIncome * 0.5)
        } else {
            let excessOverSecond = roundedCombined - threshold2
            // IRS Pub 915 Worksheet 1, line 14: the 50%-taxed tier is the *smaller* of
            // half the threshold band and half the benefits. Without the `ssIncome * 0.5`
            // cap, taxable SS is overstated when gross benefits are below the band
            // ($9K single / $12K MFJ) — e.g. Pub 915 Ex. 3 returned $7,275 vs. the
            // correct $6,275.
            let tier1Amount = min((threshold2 - threshold1) * 0.5, ssIncome * 0.5)
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
