//
//  TabPurposeChipTests.swift
//  RetireSmartIRATests
//

import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class TabPurposeChipTests: XCTestCase {

    func testInputsChip_HasInputsLabel() {
        let purpose = TabPurpose.inputs
        XCTAssertEqual(purpose.label, "Inputs")
        XCTAssertEqual(purpose.icon, "square.and.pencil")
    }

    func testAnalysisChip_HasAnalysisLabel() {
        let purpose = TabPurpose.analysis
        XCTAssertEqual(purpose.label, "Analysis")
        XCTAssertEqual(purpose.icon, "chart.bar.doc.horizontal")
    }

    func testTabPurpose_Equatable() {
        XCTAssertEqual(TabPurpose.inputs, TabPurpose.inputs)
        XCTAssertNotEqual(TabPurpose.inputs, TabPurpose.analysis)
    }
}
