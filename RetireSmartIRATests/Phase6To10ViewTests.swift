//
//  Phase6To10ViewTests.swift
//  RetireSmartIRATests
//
//  Construct tests for views added in Phases 6–10 of the Plan B UI.
//  These tests verify that enums, constructors, and computed properties
//  work without crashing. No SwiftUI rendering is performed.
//

import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class Phase6To10ViewTests: XCTestCase {

    // MARK: - AssumptionPill

    func test_AssumptionPill_allStylesExist() {
        let _: [AssumptionPill.Style] = [.standard, .featured, .toggleOn, .toggleOff, .overflow]
    }

    func test_AssumptionPill_constructsStandard() {
        _ = AssumptionPill(label: "CPI 2%", style: .standard) {}
    }

    func test_AssumptionPill_constructsFeatured() {
        _ = AssumptionPill(label: "Heir Tax Rate: 22%", style: .featured) {}
    }

    func test_AssumptionPill_constructsToggleOn() {
        _ = AssumptionPill(label: "⚡ Stress ON", style: .toggleOn) {}
    }

    func test_AssumptionPill_constructsToggleOff() {
        _ = AssumptionPill(label: "⚡ Stress OFF", style: .toggleOff) {}
    }

    func test_AssumptionPill_constructsOverflow() {
        _ = AssumptionPill(label: "⋯ Advanced", style: .overflow) {}
    }

    // MARK: - NumericStepperPopover

    func test_NumericStepperPopover_constructsWithoutCrash() {
        var val: Double = 2.5
        _ = NumericStepperPopover(
            title: "CPI rate",
            value: Binding(get: { val }, set: { val = $0 }),
            range: 0...6,
            step: 0.1,
            format: { String(format: "%.1f%%", $0) },
            onCommit: {}
        )
    }

    // MARK: - EnumPickerPopover

    func test_EnumPickerPopover_constructsWithoutCrash() {
        var selection: WithdrawalOrderingRule = .taxEfficient
        _ = EnumPickerPopover<WithdrawalOrderingRule>(
            title: "Withdrawal ordering",
            selection: Binding(get: { selection }, set: { selection = $0 }),
            options: [
                ("Tax-efficient", .taxEfficient),
                ("Deplete trad first", .depleteTradFirst),
                ("Preserve Roth", .preserveRoth),
                ("Proportional", .proportional)
            ],
            onCommit: {}
        )
    }

    // MARK: - InsightCalloutBanner

    func test_InsightCalloutBanner_allImpactLevels() {
        let _: [InsightCalloutBanner.Impact] = [.minor, .moderate, .major]
    }

    func test_InsightCalloutBanner_constructsMajor() {
        _ = InsightCalloutBanner(
            title: "Delay SS could save ~$40K",
            message: "Consider claiming at 70.",
            primaryActionLabel: "Re-run with 70",
            onPrimaryAction: {},
            onDismiss: {},
            impact: .major
        )
    }

    func test_InsightCalloutBanner_constructsModerate() {
        _ = InsightCalloutBanner(
            title: "IRMAA cliff ahead",
            message: "Income near Tier 1 boundary.",
            primaryActionLabel: nil,
            onPrimaryAction: nil,
            onDismiss: {},
            impact: .moderate
        )
    }

    func test_InsightCalloutBanner_constructsMinor() {
        _ = InsightCalloutBanner(
            title: "Minor bracket adjustment",
            message: "Small bracket shift next year.",
            primaryActionLabel: nil,
            onPrimaryAction: nil,
            onDismiss: {},
            impact: .minor
        )
    }

    // MARK: - OffPlanIndicator — PlanState cases

    func test_OffPlanIndicator_allPlanStateCasesConstruct() {
        let _: [OffPlanIndicator.PlanState] = [
            .onPlan,
            .nearOptimal(deltaDollars: 500),
            .offPlan(deltaDollars: 5_000),
            .significantlyOffPlan(deltaDollars: 50_000)
        ]
    }

    func test_OffPlanIndicator_constructsWithoutCrash() {
        _ = OffPlanIndicator(state: .onPlan, useNeutralFraming: false, onReset: {})
        _ = OffPlanIndicator(state: .nearOptimal(deltaDollars: 200), useNeutralFraming: false, onReset: {})
        _ = OffPlanIndicator(state: .offPlan(deltaDollars: 3_000), useNeutralFraming: true, onReset: {})
        _ = OffPlanIndicator(state: .significantlyOffPlan(deltaDollars: 40_000), useNeutralFraming: true, onReset: {})
    }

    // MARK: - OffPlanIndicator.PlanState.fromDelta

    func test_OffPlanIndicator_PlanState_fromDelta_zero_isOnPlan() {
        let state = OffPlanIndicator.PlanState.fromDelta(0)
        if case .onPlan = state { } else {
            XCTFail("Expected .onPlan for delta 0, got \(state)")
        }
    }

    func test_OffPlanIndicator_PlanState_fromDelta_small_isNearOptimal() {
        let state = OffPlanIndicator.PlanState.fromDelta(500)   // < 1_000 nearOptimal threshold
        if case .nearOptimal = state { } else {
            XCTFail("Expected .nearOptimal for delta 500, got \(state)")
        }
    }

    func test_OffPlanIndicator_PlanState_fromDelta_medium_isOffPlan() {
        let state = OffPlanIndicator.PlanState.fromDelta(5_000) // >= 1_000, < 25_000
        if case .offPlan = state { } else {
            XCTFail("Expected .offPlan for delta 5_000, got \(state)")
        }
    }

    func test_OffPlanIndicator_PlanState_fromDelta_large_isSignificantlyOffPlan() {
        let state = OffPlanIndicator.PlanState.fromDelta(50_000) // >= 25_000
        if case .significantlyOffPlan = state { } else {
            XCTFail("Expected .significantlyOffPlan for delta 50_000, got \(state)")
        }
    }

    func test_OffPlanIndicator_PlanState_fromDelta_customThresholds() {
        let thresholds = OffPlanIndicator.PlanState.Thresholds(nearOptimal: 100, major: 10_000)
        let nearOptimalState = OffPlanIndicator.PlanState.fromDelta(50, thresholds: thresholds)
        let offPlanState = OffPlanIndicator.PlanState.fromDelta(5_000, thresholds: thresholds)
        let significantState = OffPlanIndicator.PlanState.fromDelta(20_000, thresholds: thresholds)

        if case .nearOptimal = nearOptimalState { } else {
            XCTFail("Expected .nearOptimal with custom thresholds, got \(nearOptimalState)")
        }
        if case .offPlan = offPlanState { } else {
            XCTFail("Expected .offPlan with custom thresholds, got \(offPlanState)")
        }
        if case .significantlyOffPlan = significantState { } else {
            XCTFail("Expected .significantlyOffPlan with custom thresholds, got \(significantState)")
        }
    }

    // MARK: - LockedMacroOverlay

    func test_LockedMacroOverlay_constructsWithoutCrash() {
        _ = LockedMacroOverlay(onSetUp: {}, onDismiss: {})
    }

    // MARK: - LockedMacroSlimBanner

    func test_LockedMacroSlimBanner_constructsWithoutCrash() {
        _ = LockedMacroSlimBanner(onSetUp: {})
    }

    // MARK: - MacroPaneSkeleton

    func test_MacroPaneSkeleton_constructsWithoutCrash() {
        _ = MacroPaneSkeleton()
    }

    // MARK: - YearOverYearDeltaSynthesizer

    func test_YearOverYearDeltaSynthesizer_nilPriorReturnsNilFields() {
        let result = YearOverYearDeltaSynthesizer.synthesize(prior: nil, current: .stub())
        XCTAssertNil(result.taxDelta)
        XCTAssertNil(result.causeSentence)
    }

    func test_YearOverYearDeltaSynthesizer_resultConstructsWithoutCrash() {
        // Verify the Result struct's stored properties are accessible.
        let r = YearOverYearDeltaSynthesizer.synthesize(prior: nil, current: .stub())
        _ = r.taxDelta
        _ = r.causeSentence
    }

    // MARK: - MultiYearAssumptions

    func test_MultiYearAssumptions_assumptionsConfirmedDefaultsFalse() {
        let assumptions = MultiYearAssumptions()
        XCTAssertFalse(assumptions.assumptionsConfirmed)
    }

    func test_MultiYearAssumptions_defaultStaticInstanceHasExpectedDefaults() {
        let a = MultiYearAssumptions.default
        XCTAssertFalse(a.assumptionsConfirmed)
        XCTAssertEqual(a.horizonEndAge, 95)
        XCTAssertFalse(a.stressTestEnabled == false, "stressTestEnabled should default to true")
    }

    // MARK: - WithdrawalOrderingRule

    func test_WithdrawalOrderingRule_allFourCasesExist() {
        let _: [WithdrawalOrderingRule] = [
            .taxEfficient,
            .depleteTradFirst,
            .preserveRoth,
            .proportional
        ]
    }

    func test_WithdrawalOrderingRule_caseIterableHasFourCases() {
        XCTAssertEqual(WithdrawalOrderingRule.allCases.count, 4)
    }

    func test_WithdrawalOrderingRule_defaultIsTaxEfficient() {
        XCTAssertEqual(WithdrawalOrderingRule.default, .taxEfficient)
    }
}

// MARK: - Test helpers

private extension YearRecommendation {
    /// Minimal stub for synthesizer tests — fills required fields with neutral values.
    static func stub() -> YearRecommendation {
        YearRecommendation(
            year: 2025,
            agi: 0,
            acaMagi: nil,
            irmaaMagi: nil,
            taxableIncome: 0,
            taxBreakdown: .zero,
            endOfYearBalances: .zero,
            actions: []
        )
    }
}
