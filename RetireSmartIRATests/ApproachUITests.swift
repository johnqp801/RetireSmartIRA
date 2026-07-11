import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 2c — conversion-approach UI logic", .serialized)
@MainActor
struct ApproachUITests {

    @Test("PersistedConversionApproach round-trips all three approaches through Codable")
    func persistRoundTrips() throws {
        let cases: [ConversionApproach] = [
            .recommendedTaxMin, .fillToBracket(rate: 0.24), .limitToIRMAA(tier: 2, buffer: 5_000)
        ]
        for approach in cases {
            let persisted = PersistedConversionApproach(approach)
            let data = try JSONEncoder().encode(persisted)
            let back = try JSONDecoder().decode(PersistedConversionApproach.self, from: data)
            #expect(back == persisted)
            #expect(back.toApproach() == approach)
        }
    }

    @Test("Assumptions saved without a conversionApproach key default to recommendedTaxMin")
    func assumptionsBackCompatDefault() throws {
        // A prior-version encoded assumptions blob has no conversionApproach key.
        var a = MultiYearAssumptions.default
        a.conversionApproach = PersistedConversionApproach(.fillToBracket(rate: 0.24))
        let full = try JSONEncoder().encode(a)
        var obj = try JSONSerialization.jsonObject(with: full) as! [String: Any]
        obj.removeValue(forKey: "conversionApproach")
        let stripped = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(MultiYearAssumptions.self, from: stripped)
        #expect(decoded.conversionApproach == .recommendedTaxMin)
    }
}

extension ApproachUITests {
    /// Mirrors ManagerHeirFrontierTests' setup: a fresh non-persisting DataManager attached to a
    /// fresh MultiYearStrategyManager, so an off-main compute has real inputs to run against.
    static func makeAttachedManager() -> (MultiYearStrategyManager, DataManager) {
        let dm = DataManager(skipPersistence: true)
        let mgr = MultiYearStrategyManager()
        mgr.attach(dataManager: dm, scenarioStateManager: dm.scenario)
        return (mgr, dm)
    }

    /// Polls the manager's published comparison until the detached compute lands, mirroring the
    /// deadline-poll pattern ManagerHeirFrontierTests uses for computeHeirFrontier.
    static func settle(_ manager: MultiYearStrategyManager) async {
        let deadline = Date().addingTimeInterval(20)
        while manager.approachComparison == nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @Test("computeApproachComparison publishes a comparison for the selected approach")
    func managerComputesComparison() async {
        // dm must stay alive for the test's duration: MultiYearStrategyManager holds it via a weak
        // reference (mirrors production ownership, where a view's @StateObject DataManager outlives
        // the manager), so discarding it to `_` here would deallocate it before the detached compute
        // runs and the manager's `guard let dataManager` would silently no-op forever.
        let (manager, dm) = ApproachUITests.makeAttachedManager()
        _ = dm
        manager.assumptions.conversionApproach = PersistedConversionApproach(.fillToBracket(rate: 0.24))
        manager.computeApproachComparison()
        await ApproachUITests.settle(manager)
        #expect(manager.approachComparison != nil)
        #expect(manager.approachComparison?.selectedApproach == .fillToBracket(rate: 0.24))
        #expect(manager.approachComparison?.collapsesToTwoColumns == false)
    }
}

extension ApproachUITests {
    @Test("Anchor label is objective-based and never says 'Recommended'")
    func anchorLabelObjectiveBased() {
        #expect(ApproachUILogic.anchorLabel(effectiveHeirWeight: 0) == "Minimize lifetime tax")
        #expect(ApproachUILogic.anchorLabel(effectiveHeirWeight: 0.25) == "Optimize tax + legacy")
        #expect(!ApproachUILogic.anchorLabel(effectiveHeirWeight: 0).contains("Recommend"))
        #expect(ApproachUILogic.columnLabel(.fillToBracket(rate: 0.24), effectiveHeirWeight: 0) == "Fill to 24% bracket")
        #expect(ApproachUILogic.columnLabel(.limitToIRMAA(tier: 2, buffer: 5000), effectiveHeirWeight: 0) == "Limit to IRMAA tier 2")
    }

    @Test("Baseline-above-target is detected")
    func baselineTargetStatus() {
        #expect(ApproachUILogic.bracketStatus(bracketTopOrdinaryIncome: 100_000, baselineOrdinaryIncome: 120_000) == .exceededByBaseline)
        #expect(ApproachUILogic.bracketStatus(bracketTopOrdinaryIncome: 200_000, baselineOrdinaryIncome: 120_000) == .reachable)
    }

    @Test("Active path follows the deterministic approach, else the frontier/current path")
    func activePathSelection() {
        let fallback = [YearRecommendation]()   // empty stand-in
        #expect(ApproachUILogic.activePath(selected: .recommendedTaxMin, comparison: nil, frontierOrCurrent: fallback).isEmpty)
        // deterministic with no comparison yet falls back
        #expect(ApproachUILogic.activePath(selected: .fillToBracket(rate: 0.24), comparison: nil, frontierOrCurrent: fallback).isEmpty)
    }

    @Test("Editing Year-1 reverts a deterministic approach to the objective optimizer")
    func year1RevertRule() {
        #expect(ApproachUILogic.approachAfterYear1Edit(.fillToBracket(rate: 0.24)) == .recommendedTaxMin)
        #expect(ApproachUILogic.approachAfterYear1Edit(.recommendedTaxMin) == .recommendedTaxMin)
    }
}

extension ApproachUITests {
    @Test("Editing Year-1 while a deterministic approach is selected reverts the persisted approach")
    func year1EditRevertsPersistedApproach() {
        var a = MultiYearAssumptions.default
        a.conversionApproach = PersistedConversionApproach(.limitToIRMAA(tier: 2, buffer: 5_000))
        // The view's onYear1Edited applies ApproachUILogic.approachAfterYear1Edit to the persisted value.
        a.conversionApproach = PersistedConversionApproach(
            ApproachUILogic.approachAfterYear1Edit(a.conversionApproach.toApproach()))
        #expect(a.conversionApproach == .recommendedTaxMin)
    }
}
