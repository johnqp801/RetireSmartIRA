//
//  SSCouplesStripTests.swift
//  RetireSmartIRATests
//
//  Coverage for SSCalculationEngine.couplesStrip and DataManager.ssCouplesStrip(),
//  the dedicated one-claimed / one-planning couples strategy strip. Fixes the "blank
//  best claiming age for [spouse]" bug: the general couplesMatrix() clamps each
//  spouse's minimum age to their current age, so a spouse who claimed in the past
//  drops out of the matrix entirely and any filter by their real claimed age
//  returns []. The strip instead holds the claimed spouse fixed at their true
//  locked age and only varies the deciding spouse.
//

import XCTest
@testable import RetireSmartIRA

// MARK: - Pure Engine Function

final class SSCouplesStripEngineTests: XCTestCase {

    /// Sanity check reproducing the original bug: filtering the general matrix by the
    /// claimed spouse's real locked age returns nothing once that age is in the past,
    /// because couplesMatrix() clamps each spouse's minimum age to current age.
    func test_oldMatrixFilterApproachIsEmpty_butStripIsNot() {
        let primaryPIA = 2200.0
        let primaryBirthYear = 1958
        let primaryLifeExp = 90
        let spousePIA = 1800.0
        let spouseBirthYear = 1963
        let spouseLifeExp = 92

        // Primary claimed at 65, is now 68 (3 years past their claiming age).
        let primaryCurrentAge = 68
        let claimedAge = 65
        // Spouse hasn't claimed yet, currently 63.
        let spouseCurrentAge = 63

        let matrix = SSCalculationEngine.couplesMatrix(
            primaryPIA: primaryPIA, primaryBirthYear: primaryBirthYear, primaryLifeExpectancy: primaryLifeExp,
            spousePIA: spousePIA, spouseBirthYear: spouseBirthYear, spouseLifeExpectancy: spouseLifeExp,
            primaryCurrentAge: primaryCurrentAge, spouseCurrentAge: spouseCurrentAge
        )
        let oldFilteredStrip = matrix.filter { $0.primaryClaimingAge == claimedAge }
        XCTAssertTrue(oldFilteredStrip.isEmpty,
                       "Sanity check: the general matrix clamps primary's min age to current age (68), " +
                       "so filtering by the real claimed age (65) finds nothing — this is the bug.")

        let strip = SSCalculationEngine.couplesStrip(
            primaryPIA: primaryPIA, primaryBirthYear: primaryBirthYear, primaryLifeExpectancy: primaryLifeExp,
            spousePIA: spousePIA, spouseBirthYear: spouseBirthYear, spouseLifeExpectancy: spouseLifeExp,
            claimedIsPrimary: true, lockedAge: claimedAge, decidingCurrentAge: spouseCurrentAge
        )
        XCTAssertFalse(strip.isEmpty, "Strip should hold the claimed spouse fixed at their real locked age.")
        XCTAssertTrue(strip.allSatisfy { $0.primaryClaimingAge == claimedAge },
                       "Every cell should have the claimed spouse (primary) locked at their real claiming age.")
    }

    func test_stripVariesDecidingSpouse_primaryClaimed() {
        let strip = SSCalculationEngine.couplesStrip(
            primaryPIA: 2200, primaryBirthYear: 1958, primaryLifeExpectancy: 90,
            spousePIA: 1800, spouseBirthYear: 1963, spouseLifeExpectancy: 92,
            claimedIsPrimary: true, lockedAge: 65, decidingCurrentAge: 63
        )
        // Deciding spouse (spouse) should range from max(62, min(70, 63))=63 through 70 → 8 cells.
        XCTAssertEqual(strip.count, 8)
        XCTAssertEqual(Set(strip.map(\.spouseClaimingAge)), Set(63...70))
        XCTAssertTrue(strip.allSatisfy { $0.primaryClaimingAge == 65 })
    }

    func test_stripVariesDecidingSpouse_spouseClaimed() {
        let strip = SSCalculationEngine.couplesStrip(
            primaryPIA: 2200, primaryBirthYear: 1963, primaryLifeExpectancy: 90,
            spousePIA: 1800, spouseBirthYear: 1958, spouseLifeExpectancy: 92,
            claimedIsPrimary: false, lockedAge: 68, decidingCurrentAge: 62
        )
        // Deciding spouse (primary) should range 62...70 → 9 cells.
        XCTAssertEqual(strip.count, 9)
        XCTAssertEqual(Set(strip.map(\.primaryClaimingAge)), Set(62...70))
        XCTAssertTrue(strip.allSatisfy { $0.spouseClaimingAge == 68 })
    }

    func test_stripClampsDecidingCurrentAgeBelow62() {
        // A deciding spouse currently younger than 62 should still start the strip at 62.
        let strip = SSCalculationEngine.couplesStrip(
            primaryPIA: 2200, primaryBirthYear: 1958, primaryLifeExpectancy: 90,
            spousePIA: 1800, spouseBirthYear: 1968, spouseLifeExpectancy: 92,
            claimedIsPrimary: true, lockedAge: 65, decidingCurrentAge: 58
        )
        XCTAssertEqual(strip.count, 9)
        XCTAssertEqual(Set(strip.map(\.spouseClaimingAge)), Set(62...70))
    }

    func test_stripClampsDecidingCurrentAgeAbove70() {
        let strip = SSCalculationEngine.couplesStrip(
            primaryPIA: 2200, primaryBirthYear: 1958, primaryLifeExpectancy: 90,
            spousePIA: 1800, spouseBirthYear: 1950, spouseLifeExpectancy: 92,
            claimedIsPrimary: true, lockedAge: 65, decidingCurrentAge: 76
        )
        XCTAssertEqual(strip.count, 1)
        XCTAssertEqual(strip.first?.spouseClaimingAge, 70)
    }

    func test_stripBestCellIsSelectableByMaxLifetime() {
        let strip = SSCalculationEngine.couplesStrip(
            primaryPIA: 2200, primaryBirthYear: 1958, primaryLifeExpectancy: 90,
            spousePIA: 1800, spouseBirthYear: 1963, spouseLifeExpectancy: 92,
            claimedIsPrimary: true, lockedAge: 65, decidingCurrentAge: 63
        )
        let flagged = strip.filter(\.isHighestLifetime)
        XCTAssertEqual(flagged.count, 1, "Exactly one cell should be flagged as highest-lifetime")
        let maxByValue = strip.max(by: { $0.combinedLifetimeBenefit < $1.combinedLifetimeBenefit })
        XCTAssertEqual(flagged.first?.spouseClaimingAge, maxByValue?.spouseClaimingAge)
    }

    /// The strip must use the exact same per-cell math as couplesMatrix — cross-check
    /// against a matrix built with a wide-open age range (both current ages == 62) so
    /// the claimed spouse's locked age is still present in that matrix for comparison.
    func test_stripMathMatchesMatrixForSameAgePair() {
        let matrix = SSCalculationEngine.couplesMatrix(
            primaryPIA: 2200, primaryBirthYear: 1958, primaryLifeExpectancy: 90,
            spousePIA: 1800, spouseBirthYear: 1963, spouseLifeExpectancy: 92,
            primaryCurrentAge: 62, spouseCurrentAge: 62
        )
        let matrixCell = matrix.first { $0.primaryClaimingAge == 65 && $0.spouseClaimingAge == 66 }!

        let strip = SSCalculationEngine.couplesStrip(
            primaryPIA: 2200, primaryBirthYear: 1958, primaryLifeExpectancy: 90,
            spousePIA: 1800, spouseBirthYear: 1963, spouseLifeExpectancy: 92,
            claimedIsPrimary: true, lockedAge: 65, decidingCurrentAge: 62
        )
        let stripCell = strip.first { $0.spouseClaimingAge == 66 }!

        XCTAssertEqual(stripCell.combinedLifetimeBenefit, matrixCell.combinedLifetimeBenefit, accuracy: 0.01)
        XCTAssertEqual(stripCell.primaryMonthly, matrixCell.primaryMonthly, accuracy: 0.01)
        XCTAssertEqual(stripCell.spouseMonthly, matrixCell.spouseMonthly, accuracy: 0.01)
        XCTAssertEqual(stripCell.survivorBenefitIfPrimaryDies, matrixCell.survivorBenefitIfPrimaryDies, accuracy: 0.01)
        XCTAssertEqual(stripCell.survivorBenefitIfSpouseDies, matrixCell.survivorBenefitIfSpouseDies, accuracy: 0.01)
    }
}

// MARK: - DataManager Wrapper

@MainActor
final class SSCouplesStripDataManagerTests: XCTestCase {

    /// Reproduces Alan feedback #2: primary claimed years ago, spouse still deciding.
    /// The old view code filtered ssCouplesMatrix() by the claimed spouse's locked age,
    /// which is empty in this scenario — ssCouplesStrip() must be non-empty instead.
    func test_ssCouplesStrip_primaryClaimedInPast_nonEmpty() {
        let dm = DataManager()
        dm.profile.enableSpouse = true
        let year = dm.profile.currentYear

        // Primary claimed 3 years ago at age 65 (now 68).
        dm.profile.birthDate = Calendar.current.date(from: DateComponents(year: year - 68, month: 1, day: 1))!
        dm.primarySSBenefit = SSBenefitEstimate(
            owner: .primary, benefitAtFRA: 2200,
            plannedClaimingAge: 65, isAlreadyClaiming: true, currentBenefit: 2100
        )

        // Spouse still deciding, currently 63.
        dm.profile.spouseBirthDate = Calendar.current.date(from: DateComponents(year: year - 63, month: 1, day: 1))!
        dm.spouseSSBenefit = SSBenefitEstimate(
            owner: .spouse, benefitAtFRA: 1800,
            plannedClaimingAge: 67, isAlreadyClaiming: false
        )

        // Old path: filtering the general matrix by the claimed spouse's real age is empty.
        let matrix = dm.ssCouplesMatrix()
        let oldFiltered = matrix.filter { $0.primaryClaimingAge == 65 }
        XCTAssertTrue(oldFiltered.isEmpty, "Sanity check reproducing the bug via the DataManager matrix wrapper")

        // New path: the dedicated strip is non-empty and locks primary at 65.
        let strip = dm.ssCouplesStrip()
        XCTAssertFalse(strip.isEmpty)
        XCTAssertTrue(strip.allSatisfy { $0.primaryClaimingAge == 65 })
        XCTAssertEqual(Set(strip.map(\.spouseClaimingAge)), Set(63...70))

        // SocialSecurityPlannerView.couplesStripBestCell selects the best strip cell via
        // `.max(by: combinedLifetimeBenefit)`. Confirm that main-tab usage yields a real
        // (non-nil) cell with the claimed spouse still locked at their true age. This is
        // the exact call that used to return nil and blank the top-level SS tab.
        let bestCell = strip.max(by: { $0.combinedLifetimeBenefit < $1.combinedLifetimeBenefit })
        XCTAssertNotNil(bestCell)
        XCTAssertEqual(bestCell?.primaryClaimingAge, 65)
    }

    /// Mirror of the primary-claimed case with roles swapped: the SPOUSE claimed in the
    /// past and the PRIMARY is still deciding. This exercises `ssCouplesStrip()`'s own
    /// `claimedIsPrimary` / `lockedAge` selection ternary for the spouse-claimed branch,
    /// which the pure-engine tests bypass by hand-passing those params directly.
    func test_ssCouplesStrip_spouseClaimedInPast_nonEmpty() {
        let dm = DataManager()
        dm.profile.enableSpouse = true
        let year = dm.profile.currentYear

        // Primary still deciding, currently 63.
        dm.profile.birthDate = Calendar.current.date(from: DateComponents(year: year - 63, month: 1, day: 1))!
        dm.primarySSBenefit = SSBenefitEstimate(
            owner: .primary, benefitAtFRA: 2200,
            plannedClaimingAge: 67, isAlreadyClaiming: false
        )

        // Spouse claimed 3 years ago at age 65 (now 68).
        dm.profile.spouseBirthDate = Calendar.current.date(from: DateComponents(year: year - 68, month: 1, day: 1))!
        dm.spouseSSBenefit = SSBenefitEstimate(
            owner: .spouse, benefitAtFRA: 1800,
            plannedClaimingAge: 65, isAlreadyClaiming: true, currentBenefit: 1750
        )

        // Old path: filtering the general matrix by the claimed spouse's real age is empty.
        let matrix = dm.ssCouplesMatrix()
        let oldFiltered = matrix.filter { $0.spouseClaimingAge == 65 }
        XCTAssertTrue(oldFiltered.isEmpty, "Sanity check reproducing the bug via the DataManager matrix wrapper")

        // New path: the dedicated strip is non-empty, pins the spouse at their real
        // locked age (65), and varies the primary across their actionable range (63...70).
        let strip = dm.ssCouplesStrip()
        XCTAssertFalse(strip.isEmpty)
        XCTAssertTrue(strip.allSatisfy { $0.spouseClaimingAge == 65 })
        XCTAssertEqual(Set(strip.map(\.primaryClaimingAge)), Set(63...70))

        let bestCell = strip.max(by: { $0.combinedLifetimeBenefit < $1.combinedLifetimeBenefit })
        XCTAssertNotNil(bestCell)
        XCTAssertEqual(bestCell?.spouseClaimingAge, 65)
    }

    func test_ssCouplesStrip_emptyWhenSpouseHasNoData() {
        let dm = DataManager()
        dm.profile.enableSpouse = true
        let year = dm.profile.currentYear
        dm.profile.birthDate = Calendar.current.date(from: DateComponents(year: year - 68, month: 1, day: 1))!
        dm.primarySSBenefit = SSBenefitEstimate(
            owner: .primary, benefitAtFRA: 2200,
            plannedClaimingAge: 65, isAlreadyClaiming: true, currentBenefit: 2100
        )
        // No spouse SS data entered at all.
        dm.spouseSSBenefit = nil

        XCTAssertTrue(dm.ssCouplesStrip().isEmpty)
    }

    func test_ssCouplesStrip_emptyWhenBothHaveClaimed() {
        let dm = DataManager()
        dm.profile.enableSpouse = true
        let year = dm.profile.currentYear
        dm.profile.birthDate = Calendar.current.date(from: DateComponents(year: year - 68, month: 1, day: 1))!
        dm.primarySSBenefit = SSBenefitEstimate(
            owner: .primary, benefitAtFRA: 2200,
            plannedClaimingAge: 65, isAlreadyClaiming: true, currentBenefit: 2100
        )
        dm.profile.spouseBirthDate = Calendar.current.date(from: DateComponents(year: year - 67, month: 1, day: 1))!
        dm.spouseSSBenefit = SSBenefitEstimate(
            owner: .spouse, benefitAtFRA: 1800,
            plannedClaimingAge: 67, isAlreadyClaiming: true, currentBenefit: 1750
        )

        // Both claimed — this is the both-claimed branch's territory, not the strip's.
        XCTAssertTrue(dm.ssCouplesStrip().isEmpty)
    }
}
