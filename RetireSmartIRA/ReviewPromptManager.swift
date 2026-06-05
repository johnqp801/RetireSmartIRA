import Foundation
import Observation

/// Decides when to ask the user for an App Store review, based on in-app engagement.
/// Pure logic + UserDefaults; performs NO StoreKit (the view does that).
@Observable
final class ReviewPromptManager {

    // Tunable constants
    static let switchThreshold = 4
    static let recalcThreshold = 6
    static let recalcDebounceInterval: TimeInterval = 1.0

    private let defaults: UserDefaults
    private let currentVersion: String
    private let now: () -> Date

    // In-memory per-session state
    private(set) var switchCount = 0
    private(set) var recalcCount = 0
    private var lastRecalcTime: Date?

    private enum Key {
        static let lastPromptedVersion = "reviewPrompt.lastPromptedVersion"
        static let pendingRequest = "reviewPrompt.pendingRequest"
    }

    init(defaults: UserDefaults = .standard,
         currentVersion: String = ReviewPromptManager.bundleMarketingVersion,
         now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.now = now
    }

    static var bundleMarketingVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }

    // Read-only persisted accessors (tests read pendingRequest)
    var pendingRequest: Bool { defaults.bool(forKey: Key.pendingRequest) }
    private var lastPromptedVersion: String? { defaults.string(forKey: Key.lastPromptedVersion) }
    private var alreadyPromptedThisVersion: Bool { lastPromptedVersion == currentVersion }

    private func setPending(_ value: Bool) { defaults.set(value, forKey: Key.pendingRequest) }

    // Events
    func recordScenarioTaxSwitch() {
        switchCount += 1
        evaluateHighValue()
    }

    func recordScenarioRecalc() {
        let t = now()
        if let last = lastRecalcTime, t.timeIntervalSince(last) < Self.recalcDebounceInterval {
            return
        }
        lastRecalcTime = t
        recalcCount += 1
        evaluateHighValue()
    }

    private func evaluateHighValue() {
        guard !alreadyPromptedThisVersion, !pendingRequest else { return }
        if switchCount >= Self.switchThreshold || recalcCount >= Self.recalcThreshold {
            setPending(true)
        }
    }

    /// Call once when the app becomes active. Resets per-session engagement counters.
    func recordLaunch() {
        switchCount = 0
        recalcCount = 0
        lastRecalcTime = nil
    }

    /// Whether the root view should request a review now (call right after recordLaunch()).
    func shouldRequestReviewOnLaunch() -> Bool {
        pendingRequest && !alreadyPromptedThisVersion
    }

    /// Call after the native review request has been made.
    func markRequested() {
        defaults.set(currentVersion, forKey: Key.lastPromptedVersion)
        setPending(false)
    }
}
