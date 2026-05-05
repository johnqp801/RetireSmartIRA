//
//  MultiYearStrategyManager.swift
//  RetireSmartIRA
//
//  Owns multi-year assumptions, two engine-result caches (optimal + current),
//  debounced recompute, and the dirty-flag pattern that survives task
//  cancellation. See spec §5 / §6 for architectural detail.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class MultiYearStrategyManager: ObservableObject {

    // MARK: - Published state

    @Published var assumptions: MultiYearAssumptions
    @Published private(set) var engineOptimalResult: MultiYearStrategyResult?
    @Published private(set) var currentResult: MultiYearStrategyResult?
    @Published private(set) var isComputing: Bool = false
    @Published private(set) var hasEverComputed: Bool = false
    @Published private(set) var firstOffPlanShown: Bool = false

    // MARK: - Internal state

    /// Survives task cancellation. Set when an assumption / scenario-static-input
    /// change is detected; cleared only on successful optimal compute.
    /// See spec §5.2.
    private(set) var needsOptimalRecompute: Bool = false

    private weak var dataManager: DataManager?
    private weak var scenarioStateManager: ScenarioStateManager?
    private var debounceTask: Task<Void, Never>?

    // MARK: - Recompute reasons

    enum RecomputeReason {
        case assumptionsChanged   // pill bar interactions; sets needsOptimalRecompute
        case overridesChanged     // slider tweaks via DataManager
        case appLaunch            // initial compute on view appear; sets needsOptimalRecompute
    }

    // MARK: - Init / attach

    init(assumptions: MultiYearAssumptions = MultiYearAssumptions()) {
        self.assumptions = assumptions
    }

    /// Wire upstream dependencies post-init. StateObject construction can't
    /// access EnvironmentObjects, so SwiftUI views call attach(...) in onAppear.
    func attach(dataManager: DataManager, scenarioStateManager: ScenarioStateManager) {
        self.dataManager = dataManager
        self.scenarioStateManager = scenarioStateManager
        // Combine subscription added in Task 1.12 (Bundle C2). Skipped here.
    }

    // MARK: - Public API

    func recompute(reason: RecomputeReason) {
        // Mark optimal-cache dirty if assumptions or static inputs changed.
        // The flag survives task cancellation — see spec §5.2 dirty-flag pattern.
        if reason == .assumptionsChanged || reason == .appLaunch {
            needsOptimalRecompute = true
        }

        debounceTask?.cancel()
        isComputing = true

        debounceTask = Task { [weak self] in
            // Debounce window — 500ms after last call.
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let self else { return }

            await self.performCompute()
        }
    }

    func resetYear1ToEngineOptimal() {
        // Implemented in Bundle C2 (Task 1.11). For now, no-op; the test
        // for it is also Bundle C2.
    }

    func dismissInsight(_ key: String) {
        assumptions.dismissedInsightKeys.insert(key)
    }

    func restoreDismissedInsights() {
        assumptions.dismissedInsightKeys.removeAll()
    }

    func markFirstOffPlanShown() {
        firstOffPlanShown = true
    }

    // MARK: - Internal compute

    private func performCompute() async {
        guard let dataManager = self.dataManager,
              let scenarioStateManager = self.scenarioStateManager else {
            // Manager not attached — clear computing flag and bail.
            self.isComputing = false
            return
        }

        // Snapshot inputs on main actor before going to background.
        let assumptions = self.assumptions
        let needsOptimal = self.needsOptimalRecompute

        let currentInputs = MultiYearInputAdapter.build(
            from: dataManager,
            scenarioState: scenarioStateManager,
            assumptions: assumptions,
            excludeYear1Overrides: false
        )
        let optimalInputs: MultiYearStaticInputs? = needsOptimal
            ? MultiYearInputAdapter.build(
                from: dataManager,
                scenarioState: scenarioStateManager,
                assumptions: assumptions,
                excludeYear1Overrides: true
              )
            : nil

        // Run engine off-main.
        let result = await Task.detached(priority: .userInitiated) {
            let engine = MultiYearTaxStrategyEngine()
            let current = engine.compute(inputs: currentInputs, assumptions: assumptions)
            let optimal: MultiYearStrategyResult? = optimalInputs.map {
                engine.compute(inputs: $0, assumptions: assumptions)
            }
            return (optimal: optimal, current: current)
        }.value

        // Final cancellation check before mutating @Published state.
        guard !Task.isCancelled else { return }

        // Apply results on main actor.
        if let optimal = result.optimal {
            self.engineOptimalResult = optimal
            self.needsOptimalRecompute = false  // clear ONLY on success
        }
        self.currentResult = result.current
        self.hasEverComputed = true
        self.isComputing = false
    }
}
