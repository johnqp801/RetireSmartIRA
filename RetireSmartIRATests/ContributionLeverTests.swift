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
