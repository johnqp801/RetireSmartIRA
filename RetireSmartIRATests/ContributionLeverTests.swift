//
//  ContributionLeverTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Contribution Limits — age-based")
@MainActor
struct ContributionLimitTests {

    func dateForYear(_ year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    @Test("401(k) under 50 → base only")
    func four01kUnder50() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1980)  // age 46 in 2026
        // Updated 2026-05-03 (constants refresh): old expected 23_500; new expected 24_500 reflects IRS Notice 2025-67.
        #expect(dm.four01kLimit(for: .primary) == 24_500)
    }

    @Test("401(k) age 50 → base + standard catchup")
    func four01kAge50() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1976)  // age 50 in 2026
        // Updated 2026-05-03 (constants refresh): old expected 31_000 (23_500 + 7_500); new expected 32_500 (24_500 + 8_000).
        #expect(dm.four01kLimit(for: .primary) == 32_500)  // 24_500 + 8_000
    }

    @Test("401(k) age 59 → base + standard catchup")
    func four01kAge59() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1967)  // age 59 in 2026
        // Updated 2026-05-03 (constants refresh): old expected 31_000; new expected 32_500.
        #expect(dm.four01kLimit(for: .primary) == 32_500)
    }

    @Test("401(k) age 60 → base + super catchup (SECURE 2.0)")
    func four01kAge60SuperCatchup() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1966)  // age 60 in 2026
        // Updated 2026-05-03 (constants refresh): old expected 34_750 (23_500 + 11_250); new expected 36_500 (24_500 + 12_000).
        #expect(dm.four01kLimit(for: .primary) == 36_500)  // 24_500 + 12_000
    }

    @Test("401(k) age 63 → base + super catchup (last super-catchup year)")
    func four01kAge63SuperCatchup() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1963)  // age 63 in 2026
        // Updated 2026-05-03 (constants refresh): old expected 34_750; new expected 36_500.
        #expect(dm.four01kLimit(for: .primary) == 36_500)
    }

    @Test("401(k) age 64 → drops back to standard catchup")
    func four01kAge64DropsBack() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1962)  // age 64 in 2026
        // Updated 2026-05-03 (constants refresh): old expected 31_000; new expected 32_500.
        #expect(dm.four01kLimit(for: .primary) == 32_500)
    }

    @Test("401(k) age 70 → standard catchup")
    func four01kAge70() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1956)  // age 70 in 2026
        // Updated 2026-05-03 (constants refresh): old expected 31_000; new expected 32_500.
        #expect(dm.four01kLimit(for: .primary) == 32_500)
    }

    @Test("IRA under 50 → base only")
    func iraUnder50() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1980)
        // Updated 2026-05-03 (constants refresh): old expected 7_000; new expected 7_500 reflects IRS Notice 2025-67.
        #expect(dm.iraLimit(for: .primary) == 7_500)
    }

    @Test("IRA age 50+ → base + 1000 catchup")
    func iraAge50Plus() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1976)
        // Updated 2026-05-03 (constants refresh): old expected 8_000 (7_000 + 1_000); new expected 8_600 (7_500 + 1_100).
        #expect(dm.iraLimit(for: .primary) == 8_600)
    }
}

@Suite("AGI subtracts above-the-line contributions")
@MainActor
struct AboveTheLineDeductionTests {

    @Test("totalAboveTheLineDeductions sums all six levers")
    func sumsAllSix() {
        let dm = DataManager(skipPersistence: true)
        dm.scenario.yourTraditional401kContribution = 20_000
        dm.scenario.spouseTraditional401kContribution = 10_000
        dm.scenario.yourTraditionalIRAContribution = 7_000
        dm.scenario.spouseTraditionalIRAContribution = 7_000
        dm.scenario.yourHSAContribution = 4_300
        dm.scenario.spouseHSAContribution = 0
        #expect(dm.totalAboveTheLineDeductions == 48_300)
    }

    @Test("federalAGI subtracts above-the-line deductions from gross")
    func federalAGISubtracts() {
        let dm = DataManager(skipPersistence: true)
        // scenarioGrossIncome is 0 with no income, so federalAGI = -deductions.
        // Use a mocked income source via incomeDeductions if available; otherwise
        // verify the algebraic relationship directly.
        dm.scenario.yourTraditional401kContribution = 20_000
        let expected = dm.scenarioGrossIncome - 20_000
        #expect(dm.federalAGI.value == expected)
    }
}

@Suite("HSA Combined Limit + Medicare gating")
@MainActor
struct HSACombinedLimitTests {

    func dateForYear(_ year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    @Test("HSA combined limit for single filer under 55 = self-only")
    func hsaSingleUnder55() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1980)  // age 46
        dm.profile.filingStatus = .single
        // Updated 2026-05-03 (constants refresh): old expected 4_300; new expected 4_400 reflects IRS Rev. Proc. 2025-19.
        #expect(dm.hsaCombinedLimit() == 4_400)
    }

    @Test("HSA combined limit for single filer age 55+ = self-only + catchup")
    func hsaSingle55Plus() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1970)  // age 56
        dm.profile.filingStatus = .single
        // Updated 2026-05-03 (constants refresh): old expected 5_300 (4_300 + 1_000); new expected 5_400 (4_400 + 1_000).
        #expect(dm.hsaCombinedLimit() == 5_400)
    }

    @Test("HSA combined limit for MFJ under 55 = family")
    func hsaMFJUnder55() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1980)
        dm.profile.spouseBirthDate = dateForYear(1980)
        dm.profile.filingStatus = .marriedFilingJointly
        dm.enableSpouse = true
        // Updated 2026-05-03 (constants refresh): old expected 8_550; new expected 8_750 reflects IRS Rev. Proc. 2025-19.
        #expect(dm.hsaCombinedLimit() == 8_750)
    }

    @Test("HSA combined limit for MFJ both 55+ = family + 2× catchup")
    func hsaMFJBoth55Plus() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1970)
        dm.profile.spouseBirthDate = dateForYear(1970)
        dm.profile.filingStatus = .marriedFilingJointly
        dm.enableSpouse = true
        // Updated 2026-05-03 (constants refresh): old expected 10_550 (8_550 + 1_000 + 1_000); new expected 10_750 (8_750 + 1_000 + 1_000).
        #expect(dm.hsaCombinedLimit() == 10_750)  // 8_750 + 1_000 + 1_000
    }

    @Test("HSA combined limit for MFJ one over 55 = family + 1× catchup")
    func hsaMFJOneOver55() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1970)   // age 56
        dm.profile.spouseBirthDate = dateForYear(1980)  // age 46
        dm.profile.filingStatus = .marriedFilingJointly
        dm.enableSpouse = true
        // Updated 2026-05-03 (constants refresh): old expected 9_550 (8_550 + 1_000); new expected 9_750 (8_750 + 1_000).
        #expect(dm.hsaCombinedLimit() == 9_750)  // 8_750 + 1_000
    }
}

@Suite("HSA Medicare gating")
@MainActor
struct HSAMedicareGatingTests {

    func dateForYear(_ year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    @Test("HSA-eligible: pre-Medicare returns true")
    func hsaPreMedicare() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1980)  // age 46
        dm.scenario.yourMedicarePlanType = .preMedicare
        #expect(dm.isHSAEligible(for: .primary) == true)
    }

    @Test("HSA-eligible: original Medicare returns false")
    func hsaOriginalMedicareBlocks() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1958)  // age 68
        dm.scenario.yourMedicarePlanType = .originalMedicare
        #expect(dm.isHSAEligible(for: .primary) == false)
    }

    @Test("HSA-eligible: Medicare Advantage returns false")
    func hsaMedicareAdvantageBlocks() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1958)
        dm.scenario.yourMedicarePlanType = .medicareAdvantage
        #expect(dm.isHSAEligible(for: .primary) == false)
    }
}
