//
//  LegacyPlanningEngine.swift
//  RetireSmartIRA
//
//  Pure legacy planning calculation logic extracted from DataManager.
//  All static methods — no SwiftUI, no persistence, no DataManager dependency.
//

import Foundation

struct LegacyPlanningEngine {

    // MARK: - Projection Parameters

    /// Bundles all the inputs needed for legacy projection calculations.
    struct ProjectionParams {
        let currentAge: Int
        let rmdAge: Int
        let yearsUntilDeath: Int
        let growthRate: Double          // primaryGrowthRate (percentage, e.g. 6.0)
        let taxableGrowthRate: Double   // taxableAccountGrowthRate (percentage)
        let heirTaxRate: Double
        let heirType: String
        let drawdownYears: Int
        let spouseSurvivorYears: Int
        let spouseBirthYear: Int
        let currentYear: Int
        let totalPostDeathYears: Int
    }

    // MARK: - Core Projections

    /// Projects a Traditional IRA balance forward through the owner's lifetime,
    /// accounting for annual RMDs (starting at rmdAge) and growth.
    static func projectTraditionalToInheritance(startingBalance: Double, params: ProjectionParams) -> Double {
        guard startingBalance > 0 else { return 0 }
        var balance = startingBalance
        for yearOffset in 0..<params.yearsUntilDeath {
            let projectedAge = params.currentAge + yearOffset + 1
            if projectedAge >= params.rmdAge {
                let rmd = RMDCalculationEngine.calculateRMD(for: projectedAge, balance: balance)
                balance -= rmd
            }
            balance *= (1 + params.growthRate / 100)
        }
        return max(0, balance)
    }

    /// Projects a Roth IRA balance forward through the owner's lifetime.
    /// No RMDs on Roth — it just compounds tax-free.
    static func projectRothToInheritance(startingBalance: Double, params: ProjectionParams) -> Double {
        guard startingBalance > 0 else { return 0 }
        return startingBalance * pow(1 + params.growthRate / 100, Double(params.yearsUntilDeath))
    }

    /// Projects total withdrawals during heir's drawdown period with growth.
    /// Returns total amount withdrawn (larger than starting balance due to continued growth).
    static func projectHeirDrawdownTotal(startingBalance: Double, params: ProjectionParams) -> Double {
        guard startingBalance > 0 else { return 0 }
        var balance = startingBalance
        var totalWithdrawn = 0.0
        for yearsLeft in stride(from: params.drawdownYears, through: 1, by: -1) {
            let withdrawal = balance / Double(yearsLeft)
            totalWithdrawn += withdrawal
            balance -= withdrawal
            balance *= (1 + params.growthRate / 100)
        }
        return totalWithdrawn
    }

    // MARK: - Spouse-then-Child Chain Projections

    /// Projects Traditional IRA through three phases: owner's life → spouse rollover → child's 10-year drawdown.
    static func projectTraditionalSpouseThenChild(startingBalance: Double, params: ProjectionParams) -> Double {
        guard startingBalance > 0 else { return 0 }

        // Phase 1: Owner's lifetime
        let balanceAtOwnerDeath = projectTraditionalToInheritance(startingBalance: startingBalance, params: params)

        // Phase 2: Spouse rollover period — spouse takes RMDs based on their age
        var balance = balanceAtOwnerDeath
        let spouseAgeAtInheritance = (params.currentYear - params.spouseBirthYear) + params.yearsUntilDeath
        let spouseRmdStartAge: Int = params.spouseBirthYear >= 1960 ? 75 : (params.spouseBirthYear >= 1951 ? 73 : 72)

        for yearOffset in 0..<params.spouseSurvivorYears {
            let spouseAge = spouseAgeAtInheritance + yearOffset + 1
            if spouseAge >= spouseRmdStartAge {
                let rmd = RMDCalculationEngine.calculateRMD(for: spouseAge, balance: balance)
                balance -= rmd
            }
            balance *= (1 + params.growthRate / 100)
        }
        let balanceAtSpouseDeath = max(0, balance)

        // Phase 3: Child inherits — 10-year SECURE Act forced drawdown
        return projectHeirDrawdownTotal(startingBalance: balanceAtSpouseDeath, params: params)
    }

    /// Projects Roth IRA through three phases: owner's life → spouse rollover → child's 10-year drawdown.
    /// Roth has no RMDs for owner or spouse (spousal rollover), so phases 1+2 are pure compounding.
    static func projectRothSpouseThenChild(startingBalance: Double, params: ProjectionParams) -> Double {
        guard startingBalance > 0 else { return 0 }

        let totalCompoundingYears = params.yearsUntilDeath + params.spouseSurvivorYears
        let balanceAtSpouseDeath = startingBalance * pow(1 + params.growthRate / 100, Double(totalCompoundingYears))

        return projectHeirDrawdownTotal(startingBalance: balanceAtSpouseDeath, params: params)
    }

    // MARK: - Family Wealth Advantage

    /// Computes family wealth advantage for a given heir tax rate using the full simulation.
    static func familyWealthAdvantageAtHeirRate(
        _ testRate: Double,
        params: ProjectionParams,
        totalTraditionalBalance: Double,
        totalRothBalance: Double,
        traditionalAtInheritance: Double,
        rothAtInheritance: Double,
        conversionTaxPaidToday: Double,
        scenarioTotalRothConversion: Double
    ) -> Double {
        guard scenarioTotalRothConversion > 0 else { return 0 }
        let rTaxable = params.taxableGrowthRate / 100

        // "No conversion" wealth
        let noActionTraditionalAtDeath = projectTraditionalToInheritance(startingBalance: totalTraditionalBalance, params: params)
        let noActionRothAtDeath = projectRothToInheritance(startingBalance: totalRothBalance, params: params)

        let noActionHeirTaxableDrawdown: Double
        let noActionRothDrawdown: Double
        if params.heirType == "spouseThenChild" {
            noActionHeirTaxableDrawdown = projectTraditionalSpouseThenChild(startingBalance: totalTraditionalBalance, params: params)
            noActionRothDrawdown = projectRothSpouseThenChild(startingBalance: totalRothBalance, params: params)
        } else {
            noActionHeirTaxableDrawdown = projectHeirDrawdownTotal(startingBalance: noActionTraditionalAtDeath, params: params)
            noActionRothDrawdown = projectHeirDrawdownTotal(startingBalance: noActionRothAtDeath, params: params)
        }
        let noActionHeirAfterTax = noActionHeirTaxableDrawdown * (1 - testRate)
        let totalYears = Double(params.yearsUntilDeath + params.totalPostDeathYears)
        let taxMoneyGrown = conversionTaxPaidToday * pow(1 + rTaxable, totalYears)
        let noConversionWealth = noActionHeirAfterTax + noActionRothDrawdown + taxMoneyGrown

        // "With conversion" wealth
        let withScenarioTraditionalAtDeath = projectTraditionalToInheritance(startingBalance: traditionalAtInheritance, params: params)
        let withScenarioRothAtDeath = projectRothToInheritance(startingBalance: rothAtInheritance, params: params)

        let withHeirTaxableDrawdown: Double
        let withRothDrawdown: Double
        if params.heirType == "spouseThenChild" {
            withHeirTaxableDrawdown = projectTraditionalSpouseThenChild(startingBalance: traditionalAtInheritance, params: params)
            withRothDrawdown = projectRothSpouseThenChild(startingBalance: rothAtInheritance, params: params)
        } else {
            withHeirTaxableDrawdown = projectHeirDrawdownTotal(startingBalance: withScenarioTraditionalAtDeath, params: params)
            withRothDrawdown = projectHeirDrawdownTotal(startingBalance: withScenarioRothAtDeath, params: params)
        }
        let withHeirAfterTax = withHeirTaxableDrawdown * (1 - testRate)
        let withConversionWealth = withHeirAfterTax + withRothDrawdown

        return withConversionWealth - noConversionWealth
    }

    // MARK: - Break-Even Analysis

    /// Numerically finds the heir tax rate where family wealth advantage = 0.
    static func computeBreakEvenHeirTaxRate(
        params: ProjectionParams,
        totalTraditionalBalance: Double,
        totalRothBalance: Double,
        traditionalAtInheritance: Double,
        rothAtInheritance: Double,
        conversionTaxPaidToday: Double,
        scenarioTotalRothConversion: Double
    ) -> Double {
        guard scenarioTotalRothConversion > 0, conversionTaxPaidToday > 0 else { return 0 }

        let advantage = { (rate: Double) in
            familyWealthAdvantageAtHeirRate(rate, params: params,
                totalTraditionalBalance: totalTraditionalBalance, totalRothBalance: totalRothBalance,
                traditionalAtInheritance: traditionalAtInheritance, rothAtInheritance: rothAtInheritance,
                conversionTaxPaidToday: conversionTaxPaidToday, scenarioTotalRothConversion: scenarioTotalRothConversion)
        }

        if advantage(0.0) >= 0 { return 0 }
        if advantage(1.0) <= 0 { return 1.0 }

        var lo = 0.0
        var hi = 1.0
        for _ in 0..<50 {
            let mid = (lo + hi) / 2
            if advantage(mid) < 0 { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    /// Family wealth advantage at multiple time horizons (simplified, no RMD drag).
    static func computeBreakEvenAtHorizons(
        scenarioTotalRothConversion: Double,
        conversionTaxPaidToday: Double,
        growthRate: Double,
        taxableGrowthRate: Double,
        heirTaxRate: Double
    ) -> [(years: Int, rate: Double, advantage: Double)] {
        guard scenarioTotalRothConversion > 0, conversionTaxPaidToday > 0 else { return [] }
        let rPretax = growthRate / 100
        let rTaxable = taxableGrowthRate / 100

        return [10, 20, 30].map { totalYears in
            let rothFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(totalYears))
            let tradFV = rothFV * (1 - heirTaxRate)
            let taxKeptFV = conversionTaxPaidToday * pow(1 + rTaxable, Double(totalYears))
            let advantage = rothFV - tradFV - taxKeptFV

            var lo = 0.0
            var hi = 1.0
            for _ in 0..<40 {
                let mid = (lo + hi) / 2
                let testTradFV = rothFV * (1 - mid)
                let testAdv = rothFV - testTradFV - taxKeptFV
                if testAdv < 0 { lo = mid } else { hi = mid }
            }
            let breakEven = (lo + hi) / 2
            return (years: totalYears, rate: breakEven, advantage: advantage)
        }
    }

    // MARK: - Compounding Divergence Chart Data

    /// Year-by-year data showing how Roth and Traditional paths diverge.
    static func computeCompoundingChartData(
        scenarioTotalRothConversion: Double,
        conversionTaxPaidToday: Double,
        growthRate: Double,
        taxableGrowthRate: Double,
        heirTaxRate: Double,
        maxYears: Int
    ) -> [LegacyCompoundingPoint] {
        guard scenarioTotalRothConversion > 0, conversionTaxPaidToday > 0 else { return [] }
        let rPretax = growthRate / 100
        let rTaxable = taxableGrowthRate / 100

        var points: [LegacyCompoundingPoint] = []
        for year in stride(from: 0, through: maxYears, by: 5) {
            let rothFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(year))
            let tradFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(year)) * (1 - heirTaxRate)
            let taxKeptFV = conversionTaxPaidToday * pow(1 + rTaxable, Double(year))
            points.append(LegacyCompoundingPoint(year: year, rothValue: rothFV, traditionalValue: tradFV + taxKeptFV))
        }
        if maxYears % 5 != 0 {
            let rothFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(maxYears))
            let tradFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(maxYears)) * (1 - heirTaxRate)
            let taxKeptFV = conversionTaxPaidToday * pow(1 + rTaxable, Double(maxYears))
            points.append(LegacyCompoundingPoint(year: maxYears, rothValue: rothFV, traditionalValue: tradFV + taxKeptFV))
        }
        return points
    }

    /// The year at which the Roth path overtakes the Traditional+tax path.
    static func computeBreakEvenYear(
        scenarioTotalRothConversion: Double,
        conversionTaxPaidToday: Double,
        growthRate: Double,
        taxableGrowthRate: Double,
        heirTaxRate: Double,
        maxYears: Int
    ) -> Int? {
        guard scenarioTotalRothConversion > 0, conversionTaxPaidToday > 0 else { return nil }
        let rPretax = growthRate / 100
        let rTaxable = taxableGrowthRate / 100

        let roth0 = scenarioTotalRothConversion
        let trad0 = scenarioTotalRothConversion * (1 - heirTaxRate) + conversionTaxPaidToday
        if roth0 >= trad0 { return 0 }

        for year in 1...maxYears {
            let rothFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(year))
            let tradFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(year)) * (1 - heirTaxRate)
            let taxKeptFV = conversionTaxPaidToday * pow(1 + rTaxable, Double(year))
            if rothFV >= (tradFV + taxKeptFV) { return year }
        }
        return nil
    }
}
