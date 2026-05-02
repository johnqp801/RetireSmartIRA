//
//  TaxYearConfigContributionLimitsTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("TaxYearConfig — Contribution Limits 2026")
struct TaxYearConfigContributionLimitsTests {

    @Test("401(k) limits load with base + 3 catchup tiers")
    func four01kLimits() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        #expect(config.contributionLimits401k.base == 23_500)
        #expect(config.contributionLimits401k.catchupAge50To59 == 7_500)
        #expect(config.contributionLimits401k.catchupAge60To63 == 11_250)
        #expect(config.contributionLimits401k.catchupAge64Plus == 7_500)
    }

    @Test("IRA limits load with base + over-50 catchup")
    func iraLimits() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        #expect(config.contributionLimitsIRA.base == 7_000)
        #expect(config.contributionLimitsIRA.catchupAge50Plus == 1_000)
    }

    @Test("HSA limits load with self-only / family / over-55 catchup")
    func hsaLimits() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        #expect(config.contributionLimitsHSA.selfOnly == 4_300)
        #expect(config.contributionLimitsHSA.family == 8_550)
        #expect(config.contributionLimitsHSA.catchupAge55Plus == 1_000)
    }
}

@Suite("TaxYearConfig — Medicare 2026 defaults")
struct TaxYearConfigMedicareTests {

    @Test("Medicare premium defaults load from JSON")
    func medicareDefaultsLoad() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        #expect(config.medicare2026.partBStandardMonthly == 185.00)
        #expect(config.medicare2026.partDAvgMonthly == 50.00)
        #expect(config.medicare2026.medigapAvgMonthly == 150.00)
        #expect(config.medicare2026.advantageAvgMonthly == 50.00)
    }
}
