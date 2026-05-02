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
        #expect(dm.four01kLimit(for: .primary) == 23_500)
    }

    @Test("401(k) age 50 → base + standard catchup")
    func four01kAge50() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1976)  // age 50 in 2026
        #expect(dm.four01kLimit(for: .primary) == 31_000)  // 23_500 + 7_500
    }

    @Test("401(k) age 59 → base + standard catchup")
    func four01kAge59() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1967)  // age 59 in 2026
        #expect(dm.four01kLimit(for: .primary) == 31_000)
    }

    @Test("401(k) age 60 → base + super catchup (SECURE 2.0)")
    func four01kAge60SuperCatchup() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1966)  // age 60 in 2026
        #expect(dm.four01kLimit(for: .primary) == 34_750)  // 23_500 + 11_250
    }

    @Test("401(k) age 63 → base + super catchup (last super-catchup year)")
    func four01kAge63SuperCatchup() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1963)  // age 63 in 2026
        #expect(dm.four01kLimit(for: .primary) == 34_750)
    }

    @Test("401(k) age 64 → drops back to standard catchup")
    func four01kAge64DropsBack() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1962)  // age 64 in 2026
        #expect(dm.four01kLimit(for: .primary) == 31_000)
    }

    @Test("401(k) age 70 → standard catchup")
    func four01kAge70() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1956)  // age 70 in 2026
        #expect(dm.four01kLimit(for: .primary) == 31_000)
    }

    @Test("IRA under 50 → base only")
    func iraUnder50() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1980)
        #expect(dm.iraLimit(for: .primary) == 7_000)
    }

    @Test("IRA age 50+ → base + 1000 catchup")
    func iraAge50Plus() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1976)
        #expect(dm.iraLimit(for: .primary) == 8_000)
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
        #expect(dm.hsaCombinedLimit() == 4_300)
    }

    @Test("HSA combined limit for single filer age 55+ = self-only + catchup")
    func hsaSingle55Plus() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1970)  // age 56
        dm.profile.filingStatus = .single
        #expect(dm.hsaCombinedLimit() == 5_300)
    }

    @Test("HSA combined limit for MFJ under 55 = family")
    func hsaMFJUnder55() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1980)
        dm.profile.spouseBirthDate = dateForYear(1980)
        dm.profile.filingStatus = .marriedFilingJointly
        dm.enableSpouse = true
        #expect(dm.hsaCombinedLimit() == 8_550)
    }

    @Test("HSA combined limit for MFJ both 55+ = family + 2× catchup")
    func hsaMFJBoth55Plus() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1970)
        dm.profile.spouseBirthDate = dateForYear(1970)
        dm.profile.filingStatus = .marriedFilingJointly
        dm.enableSpouse = true
        #expect(dm.hsaCombinedLimit() == 10_550)  // 8550 + 1000 + 1000
    }

    @Test("HSA combined limit for MFJ one over 55 = family + 1× catchup")
    func hsaMFJOneOver55() {
        let dm = DataManager(skipPersistence: true)
        dm.profile.birthDate = dateForYear(1970)   // age 56
        dm.profile.spouseBirthDate = dateForYear(1980)  // age 46
        dm.profile.filingStatus = .marriedFilingJointly
        dm.enableSpouse = true
        #expect(dm.hsaCombinedLimit() == 9_550)  // 8550 + 1000
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
