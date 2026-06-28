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

    @Published var assumptions: MultiYearAssumptions {
        didSet { dataManager?.multiYearAssumptions = assumptions }
    }
    @Published private(set) var engineOptimalResult: MultiYearStrategyResult?
    @Published private(set) var currentResult: MultiYearStrategyResult?
    @Published private(set) var isComputing: Bool = false
    @Published private(set) var hasEverComputed: Bool = false
    @Published private(set) var firstOffPlanShown: Bool = false
    @Published private(set) var computeFailed: Bool = false
    @Published private(set) var baselineProjection: [YearRecommendation]?
    @Published private(set) var heirFrontier: HeirFrontierResult?
    @Published private(set) var isComputingFrontier: Bool = false
    @Published var selectedHeirWeight: Double = 0   // 0 = owner-optimal (today's recommendation)
    private var frontierWorkTask: Task<HeirFrontierResult, Never>?

    // MARK: - Internal state

    /// Survives task cancellation. Set when an assumption / scenario-static-input
    /// change is detected; cleared only on successful optimal compute.
    /// See spec §5.2.
    private(set) var needsOptimalRecompute: Bool = false

    /// Number of times recompute(reason:) has been invoked. Test seam for verifying that upstream
    /// observation actually fires a recompute. Not used by the UI.
    private(set) var recomputeCount = 0

    private weak var dataManager: DataManager?
    private weak var scenarioStateManager: ScenarioStateManager?
    private var debounceTask: Task<Void, Never>?
    private var observationTask: Task<Void, Never>?

    /// Off-main engine compute output, bundled so the detached work task can be stored and
    /// cancelled when a newer compute supersedes it (M8 — cooperative cancellation).
    private struct EngineOutputs: Sendable {
        let optimal: MultiYearStrategyResult?
        let current: MultiYearStrategyResult
        let baseline: [YearRecommendation]?
    }
    private var engineWorkTask: Task<EngineOutputs, Never>?

    /// Resolves the tax-year config for the multi-year engine. Defaults to `.current`
    /// (the active global config), so production behavior is unchanged; tests inject a
    /// fixed provider for determinism.
    private let configProvider: TaxYearConfigProvider

    // MARK: - Recompute reasons

    enum RecomputeReason {
        case assumptionsChanged   // pill bar interactions; sets needsOptimalRecompute
        case overridesChanged     // slider tweaks via DataManager
        case appLaunch            // initial compute on view appear; sets needsOptimalRecompute
    }

    // MARK: - Init / attach

    init(assumptions: MultiYearAssumptions = MultiYearAssumptions(),
         configProvider: TaxYearConfigProvider = .current) {
        self.assumptions = assumptions
        self.configProvider = configProvider
    }

    deinit {
        // Cancel in-flight work so the manager never outlives itself via leaked Tasks
        // (these fire recompute()/observation on the shared main actor otherwise).
        observationTask?.cancel()
        debounceTask?.cancel()
        engineWorkTask?.cancel()
        frontierWorkTask?.cancel()
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

        // Restore persisted assumptions for this scenario (dismissed banners, horizon, balances, ...).
        self.assumptions = dataManager.multiYearAssumptions

        self.scenarioStateManager = scenarioStateManager

        // DataManager and ScenarioStateManager use the @Observable macro (not ObservableObject),
        // so we observe via withObservationTracking rather than Combine objectWillChange.
        observationTask?.cancel()
        observationTask = nil
        observeUpstreamChanges()
    }

    /// Re-arming observation of the upstream @Observable managers. `withObservationTracking`
    /// fires `onChange` exactly once per change, so we re-register inside `onChange` (no polling
    /// loop — the previous busy-loop spun the CPU and stacked redundant registrations). Each
    /// change schedules a 50ms-debounced `.overridesChanged` recompute; recompute()'s own 500ms
    /// debounce then throttles the engine (two-stage debounce). The closure below reads the full
    /// set of inputs MultiYearInputAdapter.build(...) consumes, so an edit to any of them in any tab
    /// refreshes the plan. (multiYearAssumptions is intentionally excluded: assumption changes
    /// recompute through their own commit paths, and tracking it here would couple dismissals to
    /// recompute.)
    private func observeUpstreamChanges() {
        guard let dataManager, let scenarioStateManager else { return }
        withObservationTracking {
            // Mirrors the inputs MultiYearInputAdapter.build(...) reads, so an edit to any of them
            // (in any tab) refreshes the multi-year plan. Excludes multiYearAssumptions by design.
            _ = dataManager.iraAccounts
            _ = dataManager.incomeSources
            _ = dataManager.yourRothConversion
            _ = dataManager.spouseRothConversion
            _ = dataManager.yourExtraWithdrawal
            _ = dataManager.spouseExtraWithdrawal
            _ = dataManager.yourQCDAmount
            _ = dataManager.spouseQCDAmount
            _ = dataManager.filingStatus
            _ = dataManager.selectedState
            _ = dataManager.enableSpouse
            _ = dataManager.birthYear
            _ = dataManager.spouseBirthYear
            _ = dataManager.primarySSBenefit
            _ = dataManager.spouseSSBenefit
            _ = dataManager.legacyHeirEstimatedSalary
            _ = dataManager.legacyHeirFilingStatus
            _ = dataManager.legacyDrawdownYears
            _ = scenarioStateManager.enableACAModeling
            _ = scenarioStateManager.acaHouseholdSize
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observationTask?.cancel()
                self.observationTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    guard !Task.isCancelled else { return }
                    self?.recompute(reason: .overridesChanged)
                }
                self.observeUpstreamChanges()   // re-arm for the next change
            }
        }
    }

    // MARK: - Public API

    func recompute(reason: RecomputeReason) {
        recomputeCount += 1
        // Mark optimal-cache dirty if assumptions or static inputs changed.
        // The flag survives task cancellation — see spec §5.2 dirty-flag pattern.
        if reason == .assumptionsChanged || reason == .appLaunch {
            needsOptimalRecompute = true
        }

        debounceTask?.cancel()
        engineWorkTask?.cancel()   // M8: stop any in-flight compute superseded by this call

        // Show the spinner immediately ONLY before the first result exists (initial load). After
        // that, do NOT flip @Published state synchronously per call: editors call recompute() on
        // every keystroke, and republishing here would re-render the whole tab (all charts) each
        // keystroke. The spinner flips once inside the debounced task when the compute actually runs.
        if currentResult == nil { isComputing = true }

        debounceTask = Task { [weak self] in
            // Debounce window — 500ms after last call.
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let self else { return }
            self.isComputing = true
            self.computeFailed = false
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

    /// Years before the first required minimum distribution kicks in.
    /// Returns nil if the user is already at or past RMD age, or if data is unavailable.
    /// Used by the Conversion Opportunity Window callout banner.
    var yearsBeforeFirstRMD: Int? {
        guard let dataManager = dataManager else { return nil }
        let primaryRMDStartAge = dataManager.rmdAge
        // Use planning-year age (currentYear - birthYear) so that this planning
        // metric responds correctly when the user sets a future planning year,
        // independent of today's calendar date.
        let planningAge = dataManager.currentYear - dataManager.birthYear
        let yearsTo = max(0, primaryRMDStartAge - planningAge)
        return yearsTo > 0 ? yearsTo : nil
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

    /// Compute the owner-vs-heirs trade-off frontier off the main actor and publish it.
    func computeHeirFrontier() {
        guard let dataManager, let scenarioStateManager else { return }
        let assumptions = self.assumptions
        let configProvider = self.configProvider
        let inputs = MultiYearInputAdapter.build(
            from: dataManager, scenarioState: scenarioStateManager,
            assumptions: assumptions, excludeYear1Overrides: false)
        isComputingFrontier = true
        frontierWorkTask?.cancel()
        // .utility (not .userInitiated): the 6-weight frontier optimize is heavy and secondary to the
        // main plan, so it should yield CPU to the UI / typing rather than compete with it.
        let work = Task.detached(priority: .utility) {
            HeirFrontierCoordinator().computeFrontier(
                inputs: inputs, assumptions: assumptions, configProvider: configProvider)
        }
        frontierWorkTask = work
        Task { @MainActor [weak self] in
            let result = await work.value
            guard let self, !Task.isCancelled, !work.isCancelled else { return }
            self.heirFrontier = result
            self.isComputingFrontier = false
        }
    }

    // MARK: - Internal compute

    private func performCompute() async {
        self.computeFailed = false
        guard let dataManager = self.dataManager,
              let scenarioStateManager = self.scenarioStateManager else {
            // Manager not attached — clear computing flag and bail.
            self.computeFailed = true
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

        // Build baseline action map (one entry per horizon year, each with []).
        // ProjectionEngine.project() iterates actionsPerYear.keys, so an empty dict
        // returns no projection — we must seed every horizon year. Only computed when
        // the optimal-path also recomputes (same cadence; baseline is static against
        // assumption / static-input changes, not slider-only tweaks).
        let baselineActions: [Int: [LeverAction]] = needsOptimal
            ? Self.buildEmptyActionsMap(for: currentInputs, assumptions: assumptions)
            : [:]

        // Run engine off-main. Capture the config provider (Sendable) for the detached task.
        // The work task is stored so a newer compute can cancel it (M8); the engine checks
        // Task.isCancelled in its hot loops and bails early.
        let configProvider = self.configProvider
        engineWorkTask?.cancel()
        let work = Task.detached(priority: .userInitiated) {
            let engine = MultiYearTaxStrategyEngine()
            let current = engine.compute(inputs: currentInputs, assumptions: assumptions, configProvider: configProvider)
            let optimal: MultiYearStrategyResult? = optimalInputs.map {
                engine.compute(inputs: $0, assumptions: assumptions, configProvider: configProvider)
            }
            let baseline: [YearRecommendation]? = baselineActions.isEmpty
                ? nil
                : ProjectionEngine(configProvider: configProvider).project(
                    inputs: currentInputs,
                    assumptions: assumptions,
                    actionsPerYear: baselineActions
                )
            return EngineOutputs(optimal: optimal, current: current, baseline: baseline)
        }
        engineWorkTask = work
        let result = await work.value

        // Discard a superseded/cancelled compute before mutating @Published state.
        guard !Task.isCancelled, !work.isCancelled else { return }

        // Apply results on main actor.
        if let optimal = result.optimal {
            self.engineOptimalResult = optimal
            self.needsOptimalRecompute = false  // clear ONLY on success
        }
        if let baseline = result.baseline {
            self.baselineProjection = baseline
        }
        self.currentResult = result.current
        self.hasEverComputed = true
        self.isComputing = false
        // The heir frontier and persistence are driven from the view off `currentResult` (once per
        // settled compute), keeping both out of the manager's cold-start path.
    }

    /// Builds a map of `year: []` for every projected year in the inputs.
    /// Required because `ProjectionEngine.project()` iterates `actionsPerYear.keys` —
    /// an empty dict returns no projection. MUST mirror OptimizationEngine.optimize()'s
    /// horizon derivation EXACTLY, or the no-conversion baseline path won't align with the
    /// recommended path (wrong "doing nothing" comparison + IRMAA attribution): base year is
    /// `inputs.baseYear` (not the calendar year — the user may set a future planning year), and
    /// the horizon runs to the LATER of the two spouses' endpoints (a younger spouse extends it).
    static func buildEmptyActionsMap(   // internal for testing the baseline-alignment invariant
        for inputs: MultiYearStaticInputs,
        assumptions: MultiYearAssumptions
    ) -> [Int: [LeverAction]] {
        let baseYear = inputs.baseYear
        let primaryEndYear = baseYear + (assumptions.horizonEndAge - inputs.primaryCurrentAge)
        let spouseEndYear: Int = {
            guard let spouseAge = inputs.spouseCurrentAge else { return primaryEndYear }
            return baseYear + (assumptions.horizonEndAge(for: .spouse) - spouseAge)
        }()
        let endYear = max(primaryEndYear, spouseEndYear)
        guard endYear >= baseYear else { return [:] }
        return Dictionary(uniqueKeysWithValues: (baseYear...endYear).map { ($0, []) })
    }
}
