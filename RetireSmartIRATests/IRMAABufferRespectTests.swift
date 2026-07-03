//
//  IRMAABufferRespectTests.swift
//  RetireSmartIRATests
//
//  Integration test: optimizer never lands MAGI in the (cliff - $5K, cliff)
//  dead zone for IRMAA tier boundaries.
//  See docs/superpowers/specs/2026-05-03-2.0-optimizer-correctness-fixes-design.md
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("IRMAA buffer respect")
struct IRMAABufferRespectTests {

    @Test("Optimizer never lands MAGI in any IRMAA dead zone (MFJ Medicare-enrolled)")
    func neverLandsInDeadZone() {
        // Profile: couple, both age 67, Medicare-enrolled. Modest $200K trad.
        // Pension income brings MAGI close to IRMAA Tier 1 (218_001 MFJ).
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 800_000, roth: 100_000, taxable: 200_000, hsa: 0),
            primaryCurrentAge: 67,
            spouseCurrentAge: 67,
            filingStatus: .marriedFilingJointly,
            state: "TX",
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 2_500, spouseExpectedBenefitAtFRA: 2_500,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 67,
            spouseBirthYear: Calendar.current.component(.year, from: Date()) - 67,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 80_000, spousePensionIncome: 50_000,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 100_000
        )
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 85
        assumptions.stressTestEnabled = false
        // cliffBuffer is the default 5_000

        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: assumptions)

        // 2026 MFJ IRMAA tier ENTRY thresholds (from TaxYearConfig.config.irmaaTiers)
        let mfjThresholds: [Double] = [218_001, 274_001, 342_001, 410_001, 750_001]
        let buffer = assumptions.cliffBuffer

        // For every year where the optimizer recommended any conversion, verify
        // resulting irmaaMagi (if Medicare-enrolled, which is true for this profile)
        // does NOT fall in any (T - buffer, T) dead zone.
        for yearRec in result.recommendedPath {
            let didConvert = yearRec.actions.contains {
                if case .rothConversion(let a) = $0, a > 0 { return true }
                return false
            }
            guard didConvert, let magi = yearRec.irmaaMagi else { continue }
            for T in mfjThresholds {
                let deadZoneLow = T - buffer
                let deadZoneHigh = T
                #expect(!(magi > deadZoneLow && magi < deadZoneHigh),
                    "Year \(yearRec.year): irmaaMagi \(magi) lands in dead zone (\(deadZoneLow), \(deadZoneHigh))")
            }
        }
    }
}
