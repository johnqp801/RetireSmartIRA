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
    private var dataCancellable: AnyCancellable?

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
    ///
    /// Subscribes to DataManager and ScenarioStateManager objectWillChange so
    /// that slider tweaks and state changes trigger a debounced recompute.
    /// SwiftUI fires objectWillChange BEFORE mutations land, so the 50ms Combine
    /// debounce coalesces the notification storm into a single recompute trigger.
    /// The 500ms inner debounce in recompute() then handles engine throttling —
    /// two-stage debouncing.
    ///
    /// Note: objectWillChange fires for any mutation (including PDF-export flags, etc.).
    /// For V2.0 we treat all upstream changes as .overridesChanged; assumption changes
    /// still go through explicit recompute(.assumptionsChanged) calls from the pill bar.
    func attach(dataManager: DataManager, scenarioStateManager: ScenarioStateManager) {
        self.dataManager = dataManager
        self.scenarioStateManager = scenarioStateManager

        // Subscribe to upstream changes. SwiftUI fires objectWillChange BEFORE
        // mutations land, so a 50ms debounce on this pipeline coalesces the
        // notification storm into a single recompute trigger.
        let merged = Publishers.Merge(
            dataManager.objectWillChange.eraseToAnyPublisher(),
            scenarioStateManager.objectWillChange.eraseToAnyPublisher()
        )
        dataCancellable = merged
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.recompute(reason: .overridesChanged)
            }
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

    /// Resets all Year 1 lever overrides to match the engine-optimal recommendation.
    ///
    /// The engine returns a combined Roth conversion amount (not per-spouse) for V2.0.
    /// We assign the full combined amount to the primary spouse and zero the secondary.
    /// Per-spouse Roth conversion split is deferred to v2.1.
    ///
    /// Withdrawal and QCD overrides are zeroed because the V2.0 engine does not emit
    /// withdrawal or QCD candidates; pinning them would incorrectly constrain the engine.
    func resetYear1ToEngineOptimal() {
        guard let dataManager = dataManager,
              let optimal = engineOptimalResult,
              let firstYear = optimal.recommendedPath.first else { return }

        // Sum any .rothConversion actions in Year 1.
        let totalRoth: Double = firstYear.actions.compactMap { action -> Double? in
            if case .rothConversion(let amount) = action { return amount } else { return nil }
        }.reduce(0, +)

        // Reset all six lever fields to engine optimal.
        // Engine returns combined Roth — assign to primary; spouse split is V2.1.
        dataManager.yourRothConversion = totalRoth
        dataManager.spouseRothConversion = 0
        dataManager.yourExtraWithdrawal = 0
        dataManager.spouseExtraWithdrawal = 0
        dataManager.yourQCDAmount = 0
        dataManager.spouseQCDAmount = 0

        // Explicit recompute ensures isComputing flips synchronously for instant
        // UX feedback when the user taps Reset. The Combine pipeline will fire a
        // redundant recompute ~50ms later from the DataManager mutations above;
        // the cancel-restart pattern in recompute() coalesces them into a single
        // engine compute.
        recompute(reason: .overridesChanged)
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
