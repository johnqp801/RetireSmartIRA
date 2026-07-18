//
//  AssumptionsRecomputeTriggerTests.swift
//  RetireSmartIRATests
//
//  Root cause (2026-07-17, live-reproduced): the Advanced-assumptions sheet triggered its
//  recompute from the sheet's .onDisappear (onCommit), which does not fire reliably on macOS
//  sheet dismissal — so a terminal-rate/growth/CPI edit left the plan, the engine-optimal
//  recommendation, and the approach comparison silently STALE until some other control forced
//  a recompute. Third instance of the same manual-invalidation failure class in one day.
//
//  Fix: the view observes the assumptions VALUE (`.onChange(of: manager.assumptions)`) and
//  recomputes when an ENGINE-RELEVANT field changed. This pins the classification: UI-only
//  state (dismissed banners, onboarding confirmation) must NOT trigger an engine run;
//  everything the engine or its result displays read must.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Assumptions engine-relevant change detection")
@MainActor
struct AssumptionsRecomputeTriggerTests {

    private func base() -> MultiYearAssumptions { MultiYearAssumptions() }

    @Test("terminal liquidation rate change is engine-relevant")
    func terminalRate() {
        var new = base()
        new.terminalLiquidationTaxRate = 0.35
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), new))
    }

    @Test("growth, CPI, horizon, expenses, overrides, approach are engine-relevant")
    func coreFields() {
        var a = base(); a.investmentGrowthRate = 0.04
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), a))
        var b = base(); b.cpiRate = 0.03
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), b))
        var c = base(); c.horizonEndAge = 90
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), c))
        var d = base(); d.baselineAnnualExpenses = 200_000
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), d))
        var e = base(); e.perYearOverrides = [2030: YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: 10_000))]
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), e))
        var f = base(); f.conversionApproach = PersistedConversionApproach(.fillToBracket(rate: 0.24))
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), f))
        var g = base(); g.pvRealDiscountRate = 0.05   // feeds PV rows built during compute
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), g))
    }

    @Test("UI-only state (dismissed banners, onboarding confirmation) is NOT engine-relevant")
    func uiOnlyFields() {
        var a = base(); a.dismissedInsightKeys = ["ssNudge"]
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), a) == false)
        var b = base(); b.assumptionsConfirmed = true
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), b) == false)
    }

    @Test("identical assumptions are not a change")
    func identical() {
        #expect(MultiYearStrategyManager.engineRelevantChanged(base(), base()) == false)
    }
}
