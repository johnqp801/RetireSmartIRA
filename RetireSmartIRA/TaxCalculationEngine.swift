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

    // MARK: - Tax Bracket Constants (from config)

    static var default2026Brackets: TaxBrackets { config.toTaxBrackets() }

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
        let marginalRate: Double         // bracket rate on the last dollar
        let effectiveRateOnDistribution: Double // incrementalTax / distribution
        let totalDrawdownYears: Int
        let totalTaxOverDrawdown: Double // incrementalTax × drawdownYears (approximate)
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

        // Find marginal rate (the bracket the last dollar of total income falls in)
        let ordinaryBrackets = filingStatus == .single
            ? brackets.federalSingle : brackets.federalMarried
        var marginal = 0.0
        for bracket in ordinaryBrackets {
            if totalIncome > bracket.threshold {
                marginal = bracket.rate
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
            effectiveRateOnDistribution: effectiveOnDist,
            totalDrawdownYears: drawdownYears,
            totalTaxOverDrawdown: incremental * Double(drawdownYears)
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
        currentYear: Int
    ) -> Double {
        let config = StateTaxData.config(for: state)
        let adjustedIncome = applyRetirementExemptions(income: income, config: config, taxableSocialSecurity: taxableSocialSecurity, incomeSources: incomeSources)

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

    static func applyRetirementExemptions(income: Double, config: StateTaxConfig, taxableSocialSecurity: Double, incomeSources: [IncomeSource]) -> Double {
        var adjusted = income
        let exemptions = config.retirementExemptions

        if exemptions.socialSecurityExempt {
            adjusted -= taxableSocialSecurity
        }

        let pensionIncome = incomeSources.filter { $0.type == .pension }.reduce(0) { $0 + $1.annualAmount }
        switch exemptions.pensionExemption {
        case .full:
            adjusted -= pensionIncome
        case .partial(let maxExempt):
            adjusted -= min(pensionIncome, maxExempt)
        case .none:
            break
        }

        let iraIncome = incomeSources.filter { $0.type == .rmd }.reduce(0) { $0 + $1.annualAmount }
        switch exemptions.iraWithdrawalExemption {
        case .full:
            adjusted -= iraIncome
        case .partial(let maxExempt):
            adjusted -= min(iraIncome, maxExempt)
        case .none:
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

        let otherIncome = incomeSources
            .filter { $0.type != .socialSecurity }
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
