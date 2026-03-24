//
//  TermsAcceptanceManager.swift
//  RetireSmartIRA
//
//  Manages Terms of Use acceptance state via UserDefaults.
//  Tracks accepted flag, ToU version, timestamp, and app version.
//

import SwiftUI
import Combine

class TermsAcceptanceManager: ObservableObject {

    /// Bump this when the Terms of Use text changes materially.
    /// Users will be prompted to re-accept.
    static let currentToUVersion = "1.0"

    // MARK: - UserDefaults keys

    private enum Key {
        static let accepted = "tou_accepted"
        static let version = "tou_version"
        static let timestamp = "tou_timestamp"
        static let appVersion = "tou_app_version"
    }

    // MARK: - State

    @Published private(set) var hasAcceptedCurrentTerms: Bool

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let accepted = defaults.bool(forKey: Key.accepted)
        let version = defaults.string(forKey: Key.version) ?? ""
        self.hasAcceptedCurrentTerms = accepted && version == Self.currentToUVersion
    }

    // MARK: - Actions

    /// Records the user's acceptance of the current ToU version.
    func recordAcceptance() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

        defaults.set(true, forKey: Key.accepted)
        defaults.set(Self.currentToUVersion, forKey: Key.version)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.timestamp)
        defaults.set(appVersion, forKey: Key.appVersion)

        hasAcceptedCurrentTerms = true
    }

    /// Returns a human-readable debug string of what's stored, or nil if not accepted.
    func acceptanceRecord() -> String? {
        guard defaults.bool(forKey: Key.accepted) else { return nil }

        let version = defaults.string(forKey: Key.version) ?? "unknown"
        let appVersion = defaults.string(forKey: Key.appVersion) ?? "unknown"
        let ts = defaults.double(forKey: Key.timestamp)
        let date: String
        if ts > 0 {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            date = formatter.string(from: Date(timeIntervalSince1970: ts))
        } else {
            date = "unknown"
        }

        return "ToU v\(version) accepted on \(date) (app v\(appVersion))"
    }
}
