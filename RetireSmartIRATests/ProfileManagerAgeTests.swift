//
//  ProfileManagerAgeTests.swift
//  RetireSmartIRATests
//
//  Verifies the calendar-correct displayAge / spouseDisplayAge computations
//  are semantically distinct from the IRS-tax-year currentAge / spouseCurrentAge.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("ProfileManager — display vs tax-year age")
@MainActor
struct ProfileManagerAgeTests {

    // Helper: build a Date for (year, month, day)
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return Calendar.current.date(from: c)!
    }

    @Test("displayAge: birthday already happened this calendar year")
    func displayAge_birthdayPassedThisYear() {
        let profile = ProfileManager()
        profile.birthDate = date(1970, 1, 1)        // Jan 1 1970

        let asOf = date(2026, 5, 2)                 // May 2 2026
        // Born Jan 1 1970, on May 2 2026: 56th birthday already passed → 56
        #expect(profile.age(asOf: asOf) == 56)
    }

    @Test("displayAge: birthday has NOT happened yet this calendar year")
    func displayAge_birthdayNotYetReached() {
        let profile = ProfileManager()
        profile.birthDate = date(1968, 9, 4)        // Sept 4 1968 (the user's actual case)

        let asOf = date(2026, 5, 2)                 // May 2 2026
        // Born Sept 4 1968, on May 2 2026: 58th birthday is Sept 4 2026 (still 4 months away) → 57
        #expect(profile.age(asOf: asOf) == 57)
    }

    @Test("displayAge: exactly on the birthday")
    func displayAge_onBirthday() {
        let profile = ProfileManager()
        profile.birthDate = date(1970, 9, 4)        // Sept 4 1970

        let asOf = date(2026, 9, 4)                 // Sept 4 2026 — birthday today
        #expect(profile.age(asOf: asOf) == 56)
    }

    @Test("displayAge: differs from tax-year currentAge for late-in-year birthdays")
    func displayAge_diverges_fromCurrentAge_whenBirthdayPending() {
        // Sept 4 1968 born; in May 2026 (currentYear = 2026):
        //   currentAge (currentYear - birthYear) = 2026 - 1968 = 58 (IRS-style end-of-year)
        //   displayAge (calendar)                = 57 (haven't turned 58 yet)
        let profile = ProfileManager()
        profile.birthDate = date(1968, 9, 4)
        profile.currentYear = 2026

        let asOf = date(2026, 5, 2)
        #expect(profile.currentAge == 58)
        #expect(profile.age(asOf: asOf) == 57)
    }

    @Test("spouseDisplayAge: returns 0 when spouse not enabled")
    func spouseDisplayAge_zero_whenNoSpouse() {
        let profile = ProfileManager()
        profile.enableSpouse = false
        profile.spouseBirthDate = date(1970, 1, 1)

        let asOf = date(2026, 5, 2)
        #expect(profile.spouseAge(asOf: asOf) == 0)
    }

    @Test("spouseDisplayAge: birthday not yet reached this year")
    func spouseDisplayAge_birthdayNotYetReached() {
        let profile = ProfileManager()
        profile.enableSpouse = true
        profile.spouseBirthDate = date(1970, 11, 15)  // Nov 15 1970

        let asOf = date(2026, 5, 2)                   // May 2 2026
        // Spouse turns 56 on Nov 15 2026 — still 55 in May
        #expect(profile.spouseAge(asOf: asOf) == 55)
    }

    @Test("spouseDisplayAge: birthday already passed this year")
    func spouseDisplayAge_birthdayPassedThisYear() {
        let profile = ProfileManager()
        profile.enableSpouse = true
        profile.spouseBirthDate = date(1970, 1, 15)   // Jan 15 1970

        let asOf = date(2026, 5, 2)                   // May 2 2026
        // Spouse turned 56 on Jan 15 2026
        #expect(profile.spouseAge(asOf: asOf) == 56)
    }
}
