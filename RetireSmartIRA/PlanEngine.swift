//
//  PlanEngine.swift
//  RetireSmartIRA
//
//  Multi-year Roth conversion optimization engine.
//  Runs a deterministic year-by-year forward simulation using DataManager's
//  existing tax, bracket, IRMAA, and RMD functions.
//
//  All calculations are local and on-device. No network calls or external APIs.
//

import Foundation

// MARK: - Data Structures

/// A single year in the multi-year conversion plan.
struct YearPlan: Identifiable {
    let id = UUID()
    let year: Int
    let age: Int
    let spouseAge: Int?
    let primaryConversion: Double
    let spouseConversion: Double
    var totalConversion: Double { primaryConversion + spouseConversion }
    let projectedRMD: Double
    let bracketRate: Double           // marginal federal rate after conversion
    let remainingTraditionalBalance: Double
    let rothBalance: Double
    let cumulativeTaxPaid: Double
    let irmaaStatus: String           // "Clear", "Tier 1", etc.
    let notes: String
}

/// The complete multi-year plan result.
struct PlanResult {
    let annualPlan: [YearPlan]        // with-plan simulation
    let noActionPlan: [YearPlan]      // do-nothing comparison
    let totalConversions: Double
    let totalTaxPaid: Double
    let conversionYears: Int
    let targetBracketRate: Double
    let targetBracketLabel: String    // "24%"
    let avoidsIRMAA: Bool
    let estimatedAnnualConversion: Double
    let hasTraditionalBalance: Bool   // false = nothing to convert
}

// MARK: - Plan Engine

/// Generates an optimized multi-year Roth conversion plan based on current DataManager state.
/// This is a pure computation layer — it reads from DataManager but never mutates it.
enum PlanEngine {

    // MARK: - Public API

    /// Generates a multi-year Roth conversion plan.
    ///
    /// The algorithm fills the user's current federal tax bracket each year while staying
    /// below IRMAA cliff thresholds. It simulates year-by-year: computing RMDs, bracket room,
    /// IRMAA room, optimal conversion amount, and tracks balances forward with growth.
    ///
    /// - Parameter dm: The app's DataManager (read-only access).
    /// - Returns: A PlanResult with the optimized plan and a do-nothing comparison.
    static func generatePlan(from dm: DataManager) -> PlanResult {
        let hasBalance = dm.totalTraditionalIRABalance > 0
        guard hasBalance else {
            return emptyResult()
        }

        // Snapshot current state
        let startYear = dm.currentYear
        let startAge = dm.currentAge
        let startSpouseAge: Int? = dm.enableSpouse ? dm.spouseCurrentAge : nil
        let rmdAge = dm.rmdAge
        let spouseRmdAge = dm.enableSpouse ? dm.spouseRmdAge : 0
        let growthRate = dm.primaryGrowthRate / 100.0
        let filingStatus = dm.filingStatus
        let deduction = dm.effectiveDeductionAmount

        // Base income (held constant for future years — documented assumption)
        let baseIncome = dm.scenarioBaseIncome

        // Determine target bracket (user's current bracket)
        let currentBracketInfo = dm.federalBracketInfo(
            income: max(0, baseIncome - deduction),
            filingStatus: filingStatus
        )
        let targetRate = currentBracketInfo.currentRate
        let targetLabel = "\(Int(targetRate * 100))%"

        // Get bracket thresholds for bracket room calculation
        let brackets = filingStatus == .single
            ? dm.currentTaxBrackets.federalSingle
            : dm.currentTaxBrackets.federalMarried
        let targetNextThreshold = currentBracketInfo.nextThreshold

        // IRMAA ceiling — stay below the first IRMAA tier (or current tier if already above)
        let irmaaCeiling = computeIRMAACeiling(baseIncome: baseIncome, filingStatus: filingStatus, dm: dm)

        // Run with-plan simulation
        let withPlan = runSimulation(
            startYear: startYear,
            startAge: startAge,
            startSpouseAge: startSpouseAge,
            primaryTrad: dm.primaryTraditionalIRABalance,
            spouseTrad: dm.enableSpouse ? dm.spouseTraditionalIRABalance : 0,
            rothBalance: dm.totalRothBalance,
            baseIncome: baseIncome,
            deduction: deduction,
            targetNextThreshold: targetNextThreshold,
            irmaaCeiling: irmaaCeiling,
            rmdAge: rmdAge,
            spouseRmdAge: spouseRmdAge,
            growthRate: growthRate,
            filingStatus: filingStatus,
            enableConversions: true,
            dm: dm
        )

        // Run do-nothing simulation
        let noAction = runSimulation(
            startYear: startYear,
            startAge: startAge,
            startSpouseAge: startSpouseAge,
            primaryTrad: dm.primaryTraditionalIRABalance,
            spouseTrad: dm.enableSpouse ? dm.spouseTraditionalIRABalance : 0,
            rothBalance: dm.totalRothBalance,
            baseIncome: baseIncome,
            deduction: deduction,
            targetNextThreshold: targetNextThreshold,
            irmaaCeiling: irmaaCeiling,
            rmdAge: rmdAge,
            spouseRmdAge: spouseRmdAge,
            growthRate: growthRate,
            filingStatus: filingStatus,
            enableConversions: false,
            dm: dm
        )

        // Compute summary stats
        let totalConversions = withPlan.reduce(0.0) { $0 + $1.totalConversion }
        let totalTax = withPlan.last?.cumulativeTaxPaid ?? 0
        let conversionYears = withPlan.filter { $0.totalConversion > 0 }.count
        let avgConversion = conversionYears > 0 ? totalConversions / Double(conversionYears) : 0
        let allClear = withPlan.allSatisfy { $0.irmaaStatus == "Clear" }

        return PlanResult(
            annualPlan: withPlan,
            noActionPlan: noAction,
            totalConversions: totalConversions,
            totalTaxPaid: totalTax,
            conversionYears: conversionYears,
            targetBracketRate: targetRate,
            targetBracketLabel: targetLabel,
            avoidsIRMAA: allClear,
            estimatedAnnualConversion: avgConversion,
            hasTraditionalBalance: true
        )
    }

    // MARK: - Private Simulation

    private static func runSimulation(
        startYear: Int,
        startAge: Int,
        startSpouseAge: Int?,
        primaryTrad: Double,
        spouseTrad: Double,
        rothBalance: Double,
        baseIncome: Double,
        deduction: Double,
        targetNextThreshold: Double,
        irmaaCeiling: Double,
        rmdAge: Int,
        spouseRmdAge: Int,
        growthRate: Double,
        filingStatus: FilingStatus,
        enableConversions: Bool,
        dm: DataManager
    ) -> [YearPlan] {
        var years: [YearPlan] = []
        var pTrad = primaryTrad
        var sTrad = spouseTrad
        var roth = rothBalance
        var cumTax = 0.0
        let maxYears = 30

        for offset in 0..<maxYears {
            let year = startYear + offset
            let age = startAge + offset
            let spAge: Int? = startSpouseAge.map { $0 + offset }
            let totalTrad = pTrad + sTrad

            // Early exit if Traditional is depleted
            if totalTrad < 100 && offset > 0 {
                break
            }

            // Step 1: Compute RMDs for this year
            var rmd = 0.0
            if age >= rmdAge && pTrad > 0 {
                rmd += dm.calculateRMD(for: age, balance: pTrad)
            }
            if let sa = spAge, sa >= spouseRmdAge, sTrad > 0 {
                rmd += dm.calculateRMD(for: sa, balance: sTrad)
            }

            // Step 2: Compute income for this year (base + RMD)
            let yearIncome = baseIncome + rmd   // AGI-level (pre-deduction)
            let taxableBeforeConversion = max(0, yearIncome - deduction)

            // Step 3: Compute conversion room
            var conversion = 0.0
            if enableConversions && totalTrad > 0 {
                // Bracket room (taxable income space)
                let bracketRoom = max(0, targetNextThreshold - taxableBeforeConversion)

                // IRMAA room (AGI space — pre-deduction)
                let irmaaRoom = max(0, irmaaCeiling - yearIncome)

                // Take the smaller of bracket room and IRMAA room
                conversion = min(bracketRoom, irmaaRoom)

                // Don't convert more than what's available
                conversion = min(conversion, totalTrad)

                // Floor at zero
                conversion = max(0, conversion)
            }

            // Step 4: Split conversion between primary and spouse
            var pConv = 0.0
            var sConv = 0.0
            if conversion > 0 && totalTrad > 0 {
                let pRatio = pTrad / totalTrad
                pConv = conversion * pRatio
                sConv = conversion * (1 - pRatio)
            }

            // Step 5: Compute tax on conversion
            var yearTax = 0.0
            if conversion > 0 {
                let taxBefore = dm.calculateFederalTax(income: taxableBeforeConversion, filingStatus: filingStatus)
                let taxAfter = dm.calculateFederalTax(income: taxableBeforeConversion + conversion, filingStatus: filingStatus)
                let fedTax = taxAfter - taxBefore

                // State tax on conversion
                let stateTaxBefore = dm.calculateStateTax(income: taxableBeforeConversion, filingStatus: filingStatus)
                let stateTaxAfter = dm.calculateStateTax(income: taxableBeforeConversion + conversion, filingStatus: filingStatus)
                let stateTax = stateTaxAfter - stateTaxBefore

                yearTax = fedTax + stateTax
            }
            cumTax += yearTax

            // Step 6: Determine bracket and IRMAA status after conversion
            let incomeAfterConversion = taxableBeforeConversion + conversion
            let bracketInfo = dm.federalBracketInfo(income: incomeAfterConversion, filingStatus: filingStatus)
            let irmaaResult = dm.calculateIRMAA(magi: yearIncome + conversion, filingStatus: filingStatus)
            let irmaaLabel = irmaaResult.tier == 0 ? "Clear" : "Tier \(irmaaResult.tier)"

            // Step 7: Generate notes
            var notes: [String] = []
            if offset == 0 && age < rmdAge {
                let yearsToRMD = rmdAge - age
                notes.append("\(yearsToRMD) years before RMDs")
            }
            if age == rmdAge { notes.append("RMDs begin") }
            if conversion > 0 && conversion >= totalTrad - 100 { notes.append("Balance depleted") }
            if enableConversions && conversion == 0 && totalTrad > 100 {
                if rmd > 0 {
                    notes.append("RMDs consume bracket room")
                }
            }

            // Step 8: Update balances (deduct RMDs and conversions, then grow)
            pTrad = max(0, pTrad - pConv - (age >= rmdAge ? dm.calculateRMD(for: age, balance: pTrad) : 0))
            if let sa = spAge, sa >= spouseRmdAge {
                sTrad = max(0, sTrad - sConv - dm.calculateRMD(for: sa, balance: sTrad))
            } else {
                sTrad = max(0, sTrad - sConv)
            }
            roth += conversion

            // Apply growth
            pTrad *= (1 + growthRate)
            sTrad *= (1 + growthRate)
            roth *= (1 + growthRate)

            years.append(YearPlan(
                year: year,
                age: age,
                spouseAge: spAge,
                primaryConversion: pConv,
                spouseConversion: sConv,
                projectedRMD: rmd,
                bracketRate: bracketInfo.currentRate,
                remainingTraditionalBalance: pTrad + sTrad,
                rothBalance: roth,
                cumulativeTaxPaid: cumTax,
                irmaaStatus: irmaaLabel,
                notes: notes.joined(separator: "; ")
            ))
        }

        return years
    }

    // MARK: - IRMAA Ceiling

    /// Computes the IRMAA ceiling — the AGI level to stay below to avoid the next IRMAA tier.
    /// If already above Tier 1, stays within the current tier instead of trying to drop.
    private static func computeIRMAACeiling(baseIncome: Double, filingStatus: FilingStatus, dm: DataManager) -> Double {
        let currentIRMAA = dm.calculateIRMAA(magi: baseIncome, filingStatus: filingStatus)

        if let distanceToNext = currentIRMAA.distanceToNextTier {
            // Stay below the next tier
            return baseIncome + distanceToNext - 1
        }

        // Already at the top IRMAA tier — no ceiling constraint
        return Double.infinity
    }

    // MARK: - Empty Result

    private static func emptyResult() -> PlanResult {
        PlanResult(
            annualPlan: [],
            noActionPlan: [],
            totalConversions: 0,
            totalTaxPaid: 0,
            conversionYears: 0,
            targetBracketRate: 0,
            targetBracketLabel: "N/A",
            avoidsIRMAA: true,
            estimatedAnnualConversion: 0,
            hasTraditionalBalance: false
        )
    }
}
