//
//  TaxCalculationEngine.swift
//  RetireSmartIRA
//
//  Pure tax calculation logic extracted from DataManager.
//  All static methods — no SwiftUI, no persistence, no DataManager dependency.
//

import Foundation

struct TaxCalculationEngine {

    // MARK: - Tax Bracket Constants

    static let default2026Brackets = TaxBrackets(
        federalSingle: [
            TaxBracket(threshold: 0, rate: 0.10),
            TaxBracket(threshold: 12_400, rate: 0.12),
            TaxBracket(threshold: 50_400, rate: 0.22),
            TaxBracket(threshold: 105_700, rate: 0.24),
            TaxBracket(threshold: 201_775, rate: 0.32),
            TaxBracket(threshold: 256_225, rate: 0.35),
            TaxBracket(threshold: 640_600, rate: 0.37)
        ],
        federalMarried: [
            TaxBracket(threshold: 0, rate: 0.10),
            TaxBracket(threshold: 24_800, rate: 0.12),
            TaxBracket(threshold: 100_800, rate: 0.22),
            TaxBracket(threshold: 211_400, rate: 0.24),
            TaxBracket(threshold: 403_550, rate: 0.32),
            TaxBracket(threshold: 512_450, rate: 0.35),
            TaxBracket(threshold: 768_700, rate: 0.37)
        ],
        federalCapGainsSingle: [
            TaxBracket(threshold: 0, rate: 0.0),
            TaxBracket(threshold: 49_450, rate: 0.15),
            TaxBracket(threshold: 545_500, rate: 0.20)
        ],
        federalCapGainsMarried: [
            TaxBracket(threshold: 0, rate: 0.0),
            TaxBracket(threshold: 98_900, rate: 0.15),
            TaxBracket(threshold: 613_700, rate: 0.20)
        ]
    )

    // MARK: - IRMAA Constants (CMS 2026)

    static let irmaaStandardPartB: Double = 202.90

    static let irmaa2026Tiers: [IRMAATier] = [
        IRMAATier(tier: 0, singleThreshold: 0,       mfjThreshold: 0,       partBMonthly: 202.90, partDMonthly: 0),
        IRMAATier(tier: 1, singleThreshold: 109_001,  mfjThreshold: 218_001,  partBMonthly: 284.10, partDMonthly: 14.50),
        IRMAATier(tier: 2, singleThreshold: 137_001,  mfjThreshold: 274_001,  partBMonthly: 405.50, partDMonthly: 37.40),
        IRMAATier(tier: 3, singleThreshold: 171_001,  mfjThreshold: 342_001,  partBMonthly: 527.00, partDMonthly: 60.30),
        IRMAATier(tier: 4, singleThreshold: 205_001,  mfjThreshold: 410_001,  partBMonthly: 608.40, partDMonthly: 83.10),
        IRMAATier(tier: 5, singleThreshold: 500_001,  mfjThreshold: 750_001,  partBMonthly: 689.90, partDMonthly: 91.00),
    ]

    // MARK: - NIIT Constants (IRC §1411)

    static let niitRate: Double = 0.038
    static let niitThresholdSingle: Double = 200_000
    static let niitThresholdMFJ: Double = 250_000

    static let niitQualifyingTypes: Set<IncomeType> = [
        .dividends, .qualifiedDividends, .interest,
        .capitalGainsShort, .capitalGainsLong
    ]

    // MARK: - AMT Constants (IRC §55)

    static let amtExemptionSingle: Double = 90_100
    static let amtExemptionMFJ: Double = 140_200
    static let amtPhaseoutThresholdSingle: Double = 500_000
    static let amtPhaseoutThresholdMFJ: Double = 1_000_000
    static let amtPhaseoutRate: Double = 0.50
    static let amt26PercentLimit: Double = 244_500
    static let amtRate26: Double = 0.26
    static let amtRate28: Double = 0.28

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
        let creditPerExemption = 144.0

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

        let phaseoutThreshold = filingStatus == .single ? 252_203.0 : 504_406.0
        if agi > phaseoutThreshold {
            let excess = agi - phaseoutThreshold
            let reduction = (excess / 2_500).rounded(.down) * 6.0
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
        let (threshold1, threshold2) = filingStatus == .single ? (25_000.0, 34_000.0) : (32_000.0, 44_000.0)

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
