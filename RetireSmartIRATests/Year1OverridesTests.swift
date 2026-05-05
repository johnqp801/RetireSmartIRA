//
//  Year1OverridesTests.swift
//  RetireSmartIRATests
//

import XCTest
@testable import RetireSmartIRA

final class Year1OverridesTests: XCTestCase {

    func testHash_IgnoresSubDollarDrift() {
        let a = Year1Overrides(
            primaryRothConversion: 50_000.0,
            spouseRothConversion: 0,
            primaryWithdrawal: 0,
            spouseWithdrawal: 0,
            primaryQCD: 0,
            spouseQCD: 0
        )
        let b = Year1Overrides(
            primaryRothConversion: 50_000.000001,  // sub-cent drift from slider round-trip
            spouseRothConversion: 0,
            primaryWithdrawal: 0,
            spouseWithdrawal: 0,
            primaryQCD: 0,
            spouseQCD: 0
        )

        XCTAssertEqual(a, b, "Sub-dollar drift must NOT make overrides unequal")
        XCTAssertEqual(a.hashValue, b.hashValue, "Sub-dollar drift must NOT change hash")
    }

    func testHash_DistinguishesDollarLevelChanges() {
        let a = Year1Overrides(
            primaryRothConversion: 50_000,
            spouseRothConversion: 0,
            primaryWithdrawal: 0,
            spouseWithdrawal: 0,
            primaryQCD: 0,
            spouseQCD: 0
        )
        let b = Year1Overrides(
            primaryRothConversion: 50_001,  // 1-dollar change
            spouseRothConversion: 0,
            primaryWithdrawal: 0,
            spouseWithdrawal: 0,
            primaryQCD: 0,
            spouseQCD: 0
        )

        XCTAssertNotEqual(a, b, "Dollar-level changes MUST register as different")
        XCTAssertNotEqual(a.hashValue, b.hashValue,
            "Dollar-level changes SHOULD produce different hashes (collision possible but extremely unlikely)")
    }

    func testHash_RoundsHalfDollarToNearest() {
        let a = Year1Overrides(
            primaryRothConversion: 50_000.49,
            spouseRothConversion: 0,
            primaryWithdrawal: 0,
            spouseWithdrawal: 0,
            primaryQCD: 0,
            spouseQCD: 0
        )
        let b = Year1Overrides(
            primaryRothConversion: 50_000.0,
            spouseRothConversion: 0,
            primaryWithdrawal: 0,
            spouseWithdrawal: 0,
            primaryQCD: 0,
            spouseQCD: 0
        )

        XCTAssertEqual(a, b, "$50_000.49 rounds to $50_000")
    }
}
