//
//  IRMAAInlineWarningPreMedicareTests.swift
//  RetireSmartIRATests
//
//  Verifies `projectedMedicareMemberCountForIRMAALookback` counts adults
//  aged 63+ (the 2-year IRMAA lookback window), so the inline IRMAA warning
//  fires for pre-Medicare users whose current MAGI determines their tier
//  2 years out. (D1)
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("IRMAA inline warning — pre-Medicare 63-64 projected count", .serialized)
@MainActor
struct IRMAAInlineWarningPreMedicareTests {

    /// Configures `dm` so `currentAge` (tax-year style) returns `age`.
    /// `currentAge` is computed as `currentYear - birthYear`, so we hold
    /// `currentYear` fixed and pick a birthDate whose year is `currentYear - age`.
    private func setAges(_ dm: DataManager, your: Int, spouse: Int? = nil) {
        let fixedYear = 2026
        dm.currentYear = fixedYear
        var c = DateComponents()
        c.year = fixedYear - your
        c.month = 6
        c.day = 1
        dm.birthDate = Calendar.current.date(from: c)!
        if let spouse {
            var sc = DateComponents()
            sc.year = fixedYear - spouse
            sc.month = 6
            sc.day = 1
            dm.spouseBirthDate = Calendar.current.date(from: sc)!
        }
    }

    @Test("Age under 63 → projected count is 0")
    func projectedCount_AgeUnder63_IsZero() {
        let dm = DataManager(skipPersistence: true)
        setAges(dm, your: 60)
        #expect(dm.projectedMedicareMemberCountForIRMAALookback == 0)
    }

    @Test("Age 63 → projected count includes you")
    func projectedCount_Age63_IncludesYou() {
        let dm = DataManager(skipPersistence: true)
        setAges(dm, your: 63)
        #expect(dm.projectedMedicareMemberCountForIRMAALookback == 1)
    }

    @Test("Age 64 → projected count includes you")
    func projectedCount_Age64_IncludesYou() {
        let dm = DataManager(skipPersistence: true)
        setAges(dm, your: 64)
        #expect(dm.projectedMedicareMemberCountForIRMAALookback == 1)
    }

    @Test("Age 65 → already Medicare-covered, still counted")
    func projectedCount_Age65_AlreadyCovered() {
        let dm = DataManager(skipPersistence: true)
        setAges(dm, your: 65)
        #expect(dm.projectedMedicareMemberCountForIRMAALookback == 1)
    }

    @Test("Both spouses 63 → counts both")
    func projectedCount_BothSpouses63_CountsBoth() {
        let dm = DataManager(skipPersistence: true)
        dm.enableSpouse = true
        setAges(dm, your: 63, spouse: 63)
        #expect(dm.projectedMedicareMemberCountForIRMAALookback == 2)
    }

    @Test("Only you 63, spouse still 55 → counts only you")
    func projectedCount_OnlyYou63_SpouseStill55() {
        let dm = DataManager(skipPersistence: true)
        dm.enableSpouse = true
        setAges(dm, your: 63, spouse: 55)
        #expect(dm.projectedMedicareMemberCountForIRMAALookback == 1)
    }

    @Test("Mixed couple — you 65, spouse 63 — projected count is 2 while medicare count is 1")
    func projectedCount_Mixed65And63_CountsBothButMedicareCountIsOne() {
        let dm = DataManager(skipPersistence: true)
        dm.enableSpouse = true
        setAges(dm, your: 65, spouse: 63)
        #expect(dm.projectedMedicareMemberCountForIRMAALookback == 2)
        #expect(dm.medicareMemberCount == 1)
    }
}
