//
//  SSPersistenceSafetyTests.swift
//  RetireSmartIRATests
//
//  Data-loss guard (2026-07-17): saveSSData used to REMOVE the stored benefit/earnings keys
//  whenever the in-memory value was nil. Nil never means "user deleted" (no UI sets these to
//  nil); it means "not loaded yet" or "never entered" — so a failed/absent load followed by any
//  auto-save (saveAllData fires from dozens of onChange hooks) permanently erased the user's
//  Social Security data. A save must never destroy stored data it didn't load.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("SS persistence safety — nil memory never erases stored data", .serialized)
@MainActor
struct SSPersistenceSafetyTests {

    private func freshSuite(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func estimate(fra: Double) -> SSBenefitEstimate {
        SSBenefitEstimate(owner: .primary, benefitAt62: fra * 0.7, benefitAtFRA: fra,
                          benefitAt70: fra * 1.24, plannedClaimingAge: 70,
                          plannedClaimingMonth: 0, isAlreadyClaiming: true)
    }

    @Test("saveSSData with nil in-memory benefits leaves stored benefits intact")
    func nilMemoryDoesNotErase() throws {
        let suite = freshSuite("ss-safety-nil")
        let stored = estimate(fra: 5_400)
        suite.set(try JSONEncoder().encode(stored), forKey: "primarySSBenefit")
        suite.set(try JSONEncoder().encode(stored), forKey: "spouseSSBenefit")

        let dm = DataManager()
        dm.primarySSBenefit = nil
        dm.spouseSSBenefit = nil
        dm.saveSSData(defaults: suite)

        let dataAfter = suite.data(forKey: "primarySSBenefit")
        #expect(dataAfter != nil, "stored primary benefit must survive a save from a nil-memory session")
        if let dataAfter {
            let decoded = try JSONDecoder().decode(SSBenefitEstimate.self, from: dataAfter)
            #expect(decoded.benefitAtFRA == 5_400)
        }
        #expect(suite.data(forKey: "spouseSSBenefit") != nil)
    }

    @Test("saveSSData with real in-memory benefits still writes them")
    func realMemoryStillSaves() throws {
        let suite = freshSuite("ss-safety-write")
        let dm = DataManager()
        dm.primarySSBenefit = estimate(fra: 6_000)
        dm.saveSSData(defaults: suite)
        let data = try #require(suite.data(forKey: "primarySSBenefit"))
        let decoded = try JSONDecoder().decode(SSBenefitEstimate.self, from: data)
        #expect(decoded.benefitAtFRA == 6_000)
    }
}
