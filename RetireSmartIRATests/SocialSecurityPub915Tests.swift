//
//  SocialSecurityPub915Tests.swift
//  RetireSmartIRATests
//
//  IRC §86(a)(1) / IRS Publication 915 Worksheet 1 conformance for the *50%* taxation
//  tier, plus shape properties that must hold across the whole provisional-income
//  domain.
//
//  §86(a)(1) includes in gross income the LESSER of:
//     (A) one-half of the social security benefits received, or
//     (B) one-half of the excess of provisional income over the base amount.
//
//  The "one-half of" in (B) is the point of these tests. The 85%-tier branch already
//  applies it (`min((threshold2 - threshold1) * 0.5, ssIncome * 0.5)`); the 50%-tier
//  branch historically returned the *full* excess, overstating taxable benefits by up
//  to 2x for single filers with provisional income $25,000-$34,000 and MFJ
//  $32,000-$44,000.
//
//  Expected values here are computed from the statute and Pub 915 Worksheet 1, never
//  from application output.
//

import Testing
@testable import RetireSmartIRA

private func isClose(_ a: Double, _ b: Double, tolerance: Double = 0.01) -> Bool {
    abs(a - b) < tolerance
}

@Suite("Social Security §86 conformance", .serialized)
@MainActor struct SocialSecurityPub915Tests {

    /// Direct engine call. `other` is ordinary (fully taxable) income.
    private func taxableSS(ss: Double, other: Double, _ filingStatus: FilingStatus) -> Double {
        TaxCalculationEngine.calculateTaxableSocialSecurity(
            filingStatus: filingStatus,
            additionalIncome: 0,
            incomeSources: [
                IncomeSource(name: "SS", type: .socialSecurity, annualAmount: ss),
                IncomeSource(name: "Pension", type: .pension, annualAmount: other)
            ]
        )
    }

    private func thresholds(_ filingStatus: FilingStatus) -> (Double, Double) {
        let c = TaxCalculationEngine.config
        return filingStatus == .single
            ? (c.ssTaxationThreshold1Single, c.ssTaxationThreshold2Single)
            : (c.ssTaxationThreshold1MFJ, c.ssTaxationThreshold2MFJ)
    }

    // MARK: - 50% tier: statutory worked examples

    @Test("Single 50% tier: $24K SS + $15K other → $1,000 (half the excess)")
    func single50PercentTierHalvesTheExcess() {
        // Pub 915 Worksheet 1 (Single), benefits $24,000, pension $15,000:
        //   provisional = 15,000 + (24,000 * 0.5)      = 27,000
        //   excess over the $25,000 base               =  2,000
        //   §86(a)(1) = min(one-half of benefits, one-half of the excess)
        //             = min(0.5 * 24,000, 0.5 * 2,000)
        //             = min(12,000, 1,000)             =  1,000
        // Returning the *full* $2,000 excess omits §86(a)(1)(B)'s "one-half of".
        #expect(isClose(taxableSS(ss: 24_000, other: 15_000, .single), 1_000))
    }

    @Test("MFJ 50% tier: $30K SS + $20K other → $1,500 (half the excess)")
    func mfj50PercentTierHalvesTheExcess() {
        // Pub 915 Worksheet 1 (MFJ), benefits $30,000, pension $20,000:
        //   provisional = 20,000 + 15,000              = 35,000
        //   excess over the $32,000 base               =  3,000
        //   min(0.5 * 30,000, 0.5 * 3,000) = min(15,000, 1,500) = 1,500
        #expect(isClose(taxableSS(ss: 30_000, other: 20_000, .marriedFilingJointly), 1_500))
    }

    @Test("50% tier: the one-half-of-benefits cap binds when benefits are small")
    func fiftyPercentTierBenefitsCapBinds() {
        // Single, benefits $4,000, pension $30,000:
        //   provisional = 30,000 + 2,000 = 32,000 ; excess over 25,000 = 7,000
        //   min(0.5 * 4,000, 0.5 * 7,000) = min(2,000, 3,500) = 2,000
        // Here limb (A) binds, so this case passes even with the bug — it pins the
        // cap so a future "fix" cannot drop limb (A).
        #expect(isClose(taxableSS(ss: 4_000, other: 30_000, .single), 2_000))
    }

    @Test("At the base amount exactly, no benefits are taxable")
    func atBaseAmountNothingTaxable() {
        for status in [FilingStatus.single, .marriedFilingJointly] {
            let (t1, _) = thresholds(status)
            let ss = 20_000.0
            // provisional == t1 exactly
            #expect(isClose(taxableSS(ss: ss, other: t1 - ss * 0.5, status), 0))
        }
    }

    // MARK: - Continuity at the second threshold

    @Test("Taxable SS does not jump across the second threshold")
    func continuousAtSecondThreshold() {
        // The 50%-tier and 85%-tier formulas must agree at the seam. At provisional
        // == threshold2 both reduce to min((t2 - t1) * 0.5, benefits * 0.5).
        // With the excess un-halved the 50% side reaches (t2 - t1) instead, so taxable
        // SS falls by ~(t2 - t1) * 0.5 as provisional crosses t2 — a ~$4,500 cliff for
        // a single filer, and the source of genuine limit cycles when this function is
        // folded into the gross-up fixed point.
        for status in [FilingStatus.single, .marriedFilingJointly] {
            let (_, t2) = thresholds(status)
            let ss = 40_000.0            // large enough that the benefits cap never binds
            let otherAtSeam = t2 - ss * 0.5

            let below = taxableSS(ss: ss, other: otherAtSeam - 1, status)
            let above = taxableSS(ss: ss, other: otherAtSeam + 1, status)

            // Across a $2 span the statutory function can rise by at most 0.85 * 2.
            #expect(
                above - below >= 0 && above - below <= 1.71,
                "\(status): taxable SS jumped from \(below) to \(above) across threshold2 = \(t2)"
            )
        }
    }

    // MARK: - Domain-wide shape properties

    @Test("Taxable SS is non-decreasing and rises at most 85 cents per dollar")
    func monotonicAndLipschitzInOtherIncome() {
        // Both limbs of §86 are non-decreasing in provisional income, and no tier taxes
        // benefits faster than 85 cents per additional dollar. The un-halved excess
        // violates BOTH: it climbs at 100 cents per dollar inside the 50% tier, then
        // falls off a cliff at threshold2.
        let step = 250.0
        for status in [FilingStatus.single, .marriedFilingJointly] {
            for ss in [8_000.0, 24_000.0, 40_000.0] {
                var previous = taxableSS(ss: ss, other: 0, status)
                var other = step
                while other <= 120_000 {
                    let current = taxableSS(ss: ss, other: other, status)
                    let delta = current - previous
                    #expect(
                        delta >= -0.01,
                        "\(status) SS \(ss): taxable SS DECREASED \(previous) → \(current) at other income \(other)"
                    )
                    #expect(
                        delta <= 0.85 * step + 0.01,
                        "\(status) SS \(ss): taxable SS rose \(delta) over a \(step) step at other income \(other)"
                    )
                    previous = current
                    other += step
                }
            }
        }
    }

    @Test("Taxable SS never exceeds 85% of benefits and is never negative")
    func boundedByStatutoryCeiling() {
        for status in [FilingStatus.single, .marriedFilingJointly] {
            for ss in [0.0, 8_000.0, 24_000.0, 40_000.0] {
                for other in stride(from: 0.0, through: 200_000.0, by: 5_000.0) {
                    let value = taxableSS(ss: ss, other: other, status)
                    #expect(value >= 0)
                    #expect(value <= ss * 0.85 + 0.01)
                }
            }
        }
    }
}
