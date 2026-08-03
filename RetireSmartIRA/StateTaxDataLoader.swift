import Foundation

/// Anchors `Bundle(for:)` to the framework/app bundle that actually contains the
/// resources. `Bundle.main` resolves to the test runner under xcodebuild, where
/// the JSON is not present.
private final class BundleMarker {}

/// Loads per-jurisdiction tax configuration from bundled JSON.
///
/// Replaces the hardcoded table that shipped through v2.3.0. The move exists so
/// that state data is diffable in review, machine-checkable, readable by someone
/// who does not write Swift, and keyed by tax year rather than pinned to one.
enum StateTaxDataLoader {

    enum LoadError: LocalizedError {
        /// No bundled file matches this state's abbreviation for this tax year.
        case fileMissing(state: USState, taxYear: Int)
        /// A file was found but its contents did not decode as `StateTaxConfig`.
        case malformed(state: USState, taxYear: Int, underlying: Error)
        /// A file decoded, but its `estimatedPaymentSchedule` quarters do not
        /// sum to 1.0. See `decode(_:state:taxYear:)` for why this cannot be
        /// caught by `EstimatedPaymentSchedule`'s own initializer.
        case invalidPaymentSchedule(state: USState, taxYear: Int, sum: Double)

        var errorDescription: String? {
            switch self {
            case .fileMissing(let state, let year):
                return "Missing state tax data for \(state.abbreviation) in \(year)."
            case .malformed(let state, let year, let underlying):
                return "Malformed state tax data for \(state.abbreviation) in \(year): \(underlying.localizedDescription)"
            case .invalidPaymentSchedule(let state, let year, let sum):
                return "Invalid estimated payment schedule for \(state.abbreviation) in \(year): quarters sum to \(sum), expected 1.0."
            }
        }
    }

    /// Decodes every jurisdiction for `taxYear`.
    ///
    /// Throws rather than substituting a default. The table this replaces
    /// returned California's rules for any missing state, which produced a
    /// confident wrong number attributed to the wrong jurisdiction.
    static func load(taxYear: Int) throws -> [USState: StateTaxConfig] {
        let bundle = Bundle(for: BundleMarker.self)
        var configs: [USState: StateTaxConfig] = [:]
        for state in USState.allCases {
            configs[state] = try loadConfig(for: state, taxYear: taxYear, bundle: bundle)
        }
        return configs
    }

    /// Loads and decodes a single jurisdiction's bundled file.
    ///
    /// Filenames are `statetax-<year>-<ABBR>.json`, e.g. `statetax-2026-CA.json`.
    /// The target uses PBXFileSystemSynchronizedRootGroup (Xcode 16+), which
    /// flattens `Resources/StateTaxData/2026/` into the bundle root -- no
    /// subdirectory survives packaging -- so the year is folded into the
    /// filename itself rather than relied on as a `subdirectory:` argument.
    static func loadConfig(for state: USState, taxYear: Int,
                            bundle: Bundle = Bundle(for: BundleMarker.self)) throws -> StateTaxConfig {
        guard let url = bundle.url(forResource: "statetax-\(taxYear)-\(state.abbreviation)",
                                    withExtension: "json") else {
            throw LoadError.fileMissing(state: state, taxYear: taxYear)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LoadError.malformed(state: state, taxYear: taxYear, underlying: error)
        }
        return try decode(data, state: state, taxYear: taxYear)
    }

    /// Decodes and validates one jurisdiction's raw JSON.
    ///
    /// `EstimatedPaymentSchedule`'s hand-written initializer enforces
    /// `precondition(abs(q1+q2+q3+q4 - 1.0) < 0.001)`, but Codable's
    /// compiler-synthesized `init(from:)` assigns stored properties directly
    /// and bypasses that precondition entirely. A missing or malformed source
    /// file is one failure mode; a well-formed file with a schedule that does
    /// not sum to 1.0 is a distinct, silent one, so it gets its own check and
    /// its own named error here rather than relying on the type to protect
    /// itself.
    static func decode(_ data: Data, state: USState, taxYear: Int) throws -> StateTaxConfig {
        let config: StateTaxConfig
        do {
            config = try JSONDecoder().decode(StateTaxConfig.self, from: data)
        } catch {
            throw LoadError.malformed(state: state, taxYear: taxYear, underlying: error)
        }

        let schedule = config.estimatedPaymentSchedule
        let sum = schedule.q1Pct + schedule.q2Pct + schedule.q3Pct + schedule.q4Pct
        guard abs(sum - 1.0) < 0.001 else {
            throw LoadError.invalidPaymentSchedule(state: state, taxYear: taxYear, sum: sum)
        }

        return config
    }

    /// Decoded once at first use.
    static let configs2026: [USState: StateTaxConfig] = {
        do {
            return try load(taxYear: 2026)
        } catch {
            // A missing or malformed bundle is a build defect, not a runtime
            // condition. Fail loudly in debug; Task 11 defines release behavior.
            assertionFailure("State tax data failed to load: \(error)")
            return [:]
        }
    }()
}
