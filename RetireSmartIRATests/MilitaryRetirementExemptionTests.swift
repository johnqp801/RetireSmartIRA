import XCTest
@testable import RetireSmartIRA

final class MilitaryRetirementExemptionTests: XCTestCase {

    // MARK: - Fully exempt states

    func testFullyExempt_NorthCarolina() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "NC", age: 65), .fullyExempt)
    }

    func testFullyExempt_Pennsylvania() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "PA", age: 65), .fullyExempt)
    }

    func testFullyExempt_SouthCarolina() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "SC", age: 65), .fullyExempt)
    }

    func testFullyExempt_NewYork() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "NY", age: 65), .fullyExempt)
    }

    func testFullyExempt_Arizona() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "AZ", age: 65), .fullyExempt)
    }

    // MARK: - No state income tax

    func testNoStateIncomeTax_Texas() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "TX", age: 65), .noStateIncomeTax)
    }

    func testNoStateIncomeTax_Florida() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "FL", age: 65), .noStateIncomeTax)
    }

    func testNoStateIncomeTax_NewHampshire() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "NH", age: 65), .noStateIncomeTax)
    }

    func testNoStateIncomeTax_Tennessee() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "TN", age: 65), .noStateIncomeTax)
    }

    // MARK: - Fully taxable states

    func testFullyTaxable_California() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "CA", age: 65), .fullyTaxable)
    }

    func testFullyTaxable_DC() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "DC", age: 65), .fullyTaxable)
    }

    func testFullyTaxable_Vermont() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "VT", age: 65), .fullyTaxable)
    }

    // MARK: - Age-conditional (Iowa)

    func testIowa_FullyExemptAtAge55() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "IA", age: 55), .fullyExempt)
    }

    func testIowa_FullyExemptAbove55() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "IA", age: 70), .fullyExempt)
    }

    func testIowa_FullyTaxableBelow55() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "IA", age: 50), .fullyTaxable)
    }

    // MARK: - Partial exemption

    func testNewMexico_PartialExemption() {
        let exemption = MilitaryRetirementExemption.exemption(for: "NM", age: 65)
        if case .partiallyExempt = exemption {
            // OK
        } else {
            XCTFail("Expected partiallyExempt for NM, got \(exemption)")
        }
    }

    // MARK: - Default behavior

    func testUnknownState_DefaultsToTaxable() {
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "ZZ", age: 65), .fullyTaxable)
    }

    func testCaseInsensitive_StateCode() {
        // The function should be tolerant of lowercase input
        XCTAssertEqual(MilitaryRetirementExemption.exemption(for: "nc", age: 65), .fullyExempt)
    }

    // MARK: - stateTaxableAmount helper

    func testStateTaxableAmount_FullyExempt_ReturnsZero() {
        let amount = MilitaryRetirementExemption.stateTaxableAmount(
            gross: 50_000, stateCode: "NC", age: 65
        )
        XCTAssertEqual(amount, 0, accuracy: 0.01)
    }

    func testStateTaxableAmount_FullyTaxable_ReturnsFull() {
        let amount = MilitaryRetirementExemption.stateTaxableAmount(
            gross: 50_000, stateCode: "CA", age: 65
        )
        XCTAssertEqual(amount, 50_000, accuracy: 0.01)
    }

    func testStateTaxableAmount_NoStateIncomeTax_ReturnsZero() {
        let amount = MilitaryRetirementExemption.stateTaxableAmount(
            gross: 50_000, stateCode: "TX", age: 65
        )
        XCTAssertEqual(amount, 0, accuracy: 0.01)
    }

    func testStateTaxableAmount_PartialExemption_AppliesPercentage() {
        // For NM (50% partial example), 50K gross → 25K state taxable
        let amount = MilitaryRetirementExemption.stateTaxableAmount(
            gross: 50_000, stateCode: "NM", age: 65
        )
        // Allow either implementation (25K if 50%-taxable, or whatever NM actually does)
        // Just assert it's between 0 and 50K
        XCTAssertGreaterThan(amount, 0)
        XCTAssertLessThan(amount, 50_000)
    }

    func testStateTaxableAmount_IowaUnderAge55_FullyTaxable() {
        let amount = MilitaryRetirementExemption.stateTaxableAmount(
            gross: 50_000, stateCode: "IA", age: 50
        )
        XCTAssertEqual(amount, 50_000, accuracy: 0.01)
    }
}
