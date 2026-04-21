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
        let heirType: String
        let drawdownYears: Int
        let spouseSurvivorYears: Int
        let spouseBirthYear: Int
        let currentYear: Int
        let totalPostDeathYears: Int
        let heirEstimatedSalary: Double
        let heirFilingStatus: FilingStatus

        init(currentAge: Int, rmdAge: Int, yearsUntilDeath: Int, growthRate: Double,
             taxableGrowthRate: Double, heirType: String,
             drawdownYears: Int, spouseSurvivorYears: Int, spouseBirthYear: Int,
             currentYear: Int, totalPostDeathYears: Int,
             heirEstimatedSalary: Double = 75_000, heirFilingStatus: FilingStatus = .single) {
            self.currentAge = currentAge
            self.rmdAge = rmdAge
            self.yearsUntilDeath = yearsUntilDeath
            self.growthRate = growthRate
            self.taxableGrowthRate = taxableGrowthRate
            self.heirType = heirType
            self.drawdownYears = drawdownYears
            self.spouseSurvivorYears = spouseSurvivorYears
            self.spouseBirthYear = spouseBirthYear
            self.currentYear = currentYear
            self.totalPostDeathYears = totalPostDeathYears
            self.heirEstimatedSalary = heirEstimatedSalary
            self.heirFilingStatus = heirFilingStatus
        }
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

    // MARK: - Compounding Divergence Chart Data

    /// Year-by-year data showing how Roth and Traditional paths diverge.
    static func computeCompoundingChartData(
        scenarioTotalRothConversion: Double,
        conversionTaxPaidToday: Double,
        growthRate: Double,
        taxableGrowthRate: Double,
        heirEstimatedSalary: Double,
        heirFilingStatus: FilingStatus,
        maxYears: Int
    ) -> [LegacyCompoundingPoint] {
        guard scenarioTotalRothConversion > 0, conversionTaxPaidToday > 0 else { return [] }
        let rPretax = growthRate / 100
        let rTaxable = taxableGrowthRate / 100

        var points: [LegacyCompoundingPoint] = []
        for year in stride(from: 0, through: maxYears, by: 5) {
            let rothFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(year))
            let annualDist = rothFV / 10.0
            let effRate = TaxCalculationEngine.heirEffectiveTaxRate(
                annualDistribution: annualDist,
                heirSalary: heirEstimatedSalary,
                filingStatus: heirFilingStatus)
            let tradFV = rothFV * (1 - effRate)
            let taxKeptFV = conversionTaxPaidToday * pow(1 + rTaxable, Double(year))
            points.append(LegacyCompoundingPoint(year: year, rothValue: rothFV, traditionalValue: tradFV + taxKeptFV))
        }
        if maxYears % 5 != 0 {
            let rothFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(maxYears))
            let annualDist = rothFV / 10.0
            let effRate = TaxCalculationEngine.heirEffectiveTaxRate(
                annualDistribution: annualDist,
                heirSalary: heirEstimatedSalary,
                filingStatus: heirFilingStatus)
            let tradFV = rothFV * (1 - effRate)
            let taxKeptFV = conversionTaxPaidToday * pow(1 + rTaxable, Double(maxYears))
            points.append(LegacyCompoundingPoint(year: maxYears, rothValue: rothFV, traditionalValue: tradFV + taxKeptFV))
        }
        return points
    }

    /// The year at which the Roth path overtakes the Traditional+tax path.
    /// Uses the progressive heir-tax effective rate derived from salary + filing status
    /// at each year's hypothetical distribution (treating the whole traditional FV as a
    /// 10-year drawdown, matching the compounding chart).
    static func computeBreakEvenYear(
        scenarioTotalRothConversion: Double,
        conversionTaxPaidToday: Double,
        growthRate: Double,
        taxableGrowthRate: Double,
        heirEstimatedSalary: Double,
        heirFilingStatus: FilingStatus,
        maxYears: Int
    ) -> Int? {
        guard scenarioTotalRothConversion > 0, conversionTaxPaidToday > 0 else { return nil }
        let rPretax = growthRate / 100
        let rTaxable = taxableGrowthRate / 100

        func effRate(rothFV: Double) -> Double {
            TaxCalculationEngine.heirEffectiveTaxRate(
                annualDistribution: rothFV / 10.0,
                heirSalary: heirEstimatedSalary,
                filingStatus: heirFilingStatus)
        }

        let roth0 = scenarioTotalRothConversion
        let trad0 = scenarioTotalRothConversion * (1 - effRate(rothFV: roth0)) + conversionTaxPaidToday
        if roth0 >= trad0 { return 0 }

        for year in 1...maxYears {
            let rothFV = scenarioTotalRothConversion * pow(1 + rPretax, Double(year))
            let tradFV = rothFV * (1 - effRate(rothFV: rothFV))
            let taxKeptFV = conversionTaxPaidToday * pow(1 + rTaxable, Double(year))
            if rothFV >= (tradFV + taxKeptFV) { return year }
        }
        return nil
    }
}
