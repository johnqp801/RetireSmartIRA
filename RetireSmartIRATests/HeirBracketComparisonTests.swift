//
//  HeirBracketComparisonTests.swift
//  RetireSmartIRATests
//
//  Phase 2 L3: Heir-Bracket Comparison Card.
//
//  Pure-math tests (XCTest) for TaxCalculationEngine.convertNowVsHeirComparison.
//  Gating + hybrid-display tests (Swift Testing) for DataManager accessors.
//

import XCTest
@testable import RetireSmartIRA

final class HeirBracketComparisonTests: XCTestCase {
    func test_basicComparison_userLowerThanHeir() {
        let c = TaxCalculationEngine.convertNowVsHeirComparison(
            conversionAmount: 100_000,
            userMarginalRate: 0.24,
            heirMarginalRate: 0.32
        )
        XCTAssertEqual(c.userTaxIfConvertedNow, 24_000, accuracy: 0.5)
        XCTAssertEqual(c.heirTaxIfInheritedLater, 32_000, accuracy: 0.5)
        XCTAssertEqual(c.netFamilyBenefit, 8_000, accuracy: 0.5)
    }

    func test_zeroConversion_returnsZeros() {
        let c = TaxCalculationEngine.convertNowVsHeirComparison(
            conversionAmount: 0,
            userMarginalRate: 0.24,
            heirMarginalRate: 0.32
        )
        XCTAssertEqual(c.userTaxIfConvertedNow, 0, accuracy: 0.01)
        XCTAssertEqual(c.heirTaxIfInheritedLater, 0, accuracy: 0.01)
        XCTAssertEqual(c.netFamilyBenefit, 0, accuracy: 0.01)
    }

    func test_negativeBenefit_whenUserHigherThanHeir() {
        let c = TaxCalculationEngine.convertNowVsHeirComparison(
            conversionAmount: 50_000,
            userMarginalRate: 0.37,
            heirMarginalRate: 0.22
        )
        XCTAssertEqual(c.netFamilyBenefit, -7_500, accuracy: 0.5)
    }

    /// Property: net benefit scales linearly with conversion amount.
    func test_linearScaling() {
        let small = TaxCalculationEngine.convertNowVsHeirComparison(
            conversionAmount: 10_000,
            userMarginalRate: 0.24,
            heirMarginalRate: 0.32
        )
        let big = TaxCalculationEngine.convertNowVsHeirComparison(
            conversionAmount: 100_000,
            userMarginalRate: 0.24,
            heirMarginalRate: 0.32
        )
        XCTAssertEqual(big.netFamilyBenefit, small.netFamilyBenefit * 10, accuracy: 0.5)
    }
}

// MARK: - Decision A: spouse-heir gating + Decision B: hybrid display
//
// Use Swift Testing for DataManager-state tests, matching the convention used
// by PlannedMedicareStartAgeTests + IRMAAInlineWarningPreMedicareTests.

import Testing

@Suite("Heir-comparison spouse-heir gating (Decision A)", .serialized)
@MainActor
struct HeirBracketComparisonGatingTests {
    @Test("Hidden when heir is a spouse")
    func shouldShowHeirComparison_hiddenForSpouseHeir() {
        let dm = DataManager(skipPersistence: true)
        dm.legacyHeirType = "spouse"
        #expect(dm.shouldShowHeirComparison == false)
    }

    @Test("Visible when heir is non-spouse (child)")
    func shouldShowHeirComparison_visibleForChildHeir() {
        let dm = DataManager(skipPersistence: true)
        dm.legacyHeirType = "child"
        #expect(dm.shouldShowHeirComparison == true)
    }

    @Test("Visible when heir is non-spouse (other)")
    func shouldShowHeirComparison_visibleForOtherHeir() {
        let dm = DataManager(skipPersistence: true)
        dm.legacyHeirType = "other"
        #expect(dm.shouldShowHeirComparison == true)
    }
}

@Suite("Heir-comparison hybrid display at $10K boundary (Decision B)", .serialized)
@MainActor
struct HeirComparisonHybridDisplayTests {
    @Test("Uses illustrative $100K constant when conversion < $10K")
    func usesIllustrativeConstant_whenConversionUnder10k() {
        let dm = DataManager(skipPersistence: true)
        dm.yourRothConversion = 5_000
        #expect(dm.heirComparisonUsesLiveAmount == false)
    }

    @Test("Uses live amount at $10K boundary")
    func usesLiveAmount_whenConversionAt10k() {
        let dm = DataManager(skipPersistence: true)
        dm.yourRothConversion = 10_000
        #expect(dm.heirComparisonUsesLiveAmount == true)
    }

    @Test("Uses live amount when conversion is $50K")
    func usesLiveAmount_whenConversion50k() {
        let dm = DataManager(skipPersistence: true)
        dm.yourRothConversion = 50_000
        #expect(dm.heirComparisonUsesLiveAmount == true)
    }
}
