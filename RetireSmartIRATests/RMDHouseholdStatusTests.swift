import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("RMD household status")
struct RMDHouseholdStatusTests {

    @Test("A spouse who is already required makes the household required, even when the primary is not")
    func olderSpouseDrivesTheHeadline() {
        // Steve's household: wife nine years older, already past her RMD age.
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73)
        #expect(s.anyoneRequired)
        #expect(s.startsFirst == .spouse)
        #expect(s.yearsUntilFirst == 0)
        #expect(s.showsBothPeople)
    }

    @Test("The primary can be the one who starts first")
    func olderPrimaryDrivesTheHeadline() {
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 73, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 64, spouseRmdAge: 73)
        #expect(s.anyoneRequired)
        #expect(s.startsFirst == .primary)
        #expect(s.showsBothPeople)
    }

    @Test("Neither required yet: the countdown is to whoever starts sooner")
    func countdownUsesWhoeverStartsSooner() {
        // Spouse is closer to her RMD age, so the countdown is hers, not his.
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 60, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 70, spouseRmdAge: 73)
        #expect(!s.anyoneRequired)
        #expect(s.startsFirst == .spouse)
        #expect(s.yearsUntilFirst == 3)
        #expect(s.firstRmdAge == 73)
    }

    @Test("Different RMD ages are respected, not assumed equal")
    func differentRmdAgesAreRespected() {
        // Born 1959 versus born 1960: 73 against 75, a real SECURE 2.0 boundary.
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 67, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 67, spouseRmdAge: 73)
        #expect(s.startsFirst == .spouse)
        #expect(s.firstRmdAge == 73)
        #expect(s.showsBothPeople)
    }

    @Test("No spouse: everything resolves to the primary and nothing shows both")
    func singleFilerShowsOnePerson() {
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 99, spouseRmdAge: 73)
        #expect(!s.anyoneRequired)
        #expect(s.startsFirst == .primary)
        #expect(s.yearsUntilFirst == 9)
        #expect(!s.showsBothPeople)
    }

    @Test("A disabled spouse's ages are ignored entirely")
    func disabledSpouseCannotLeakIn() {
        // spouseAge 99 would dominate every field if the guard were missing.
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 60, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 99, spouseRmdAge: 73)
        #expect(!s.anyoneRequired)
        #expect(s.yearsUntilFirst == 13)
    }

    @Test("Identical ages tie-break to the primary and do not claim to show both")
    func identicalHouseholdsResolveToPrimary() {
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 70, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 70, spouseRmdAge: 73)
        #expect(s.startsFirst == .primary)
        #expect(!s.showsBothPeople)
    }
}
