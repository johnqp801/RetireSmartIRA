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

    /// Locates a jurisdiction's bundled JSON file without decoding it.
    ///
    /// Filenames are `statetax-<year>-<ABBR>.json`, e.g. `statetax-2026-CA.json`.
    /// The target uses PBXFileSystemSynchronizedRootGroup (Xcode 16+), which
    /// flattens `Resources/StateTaxData/2026/` into the bundle root -- no
    /// subdirectory survives packaging -- so the year is folded into the
    /// filename itself rather than relied on as a `subdirectory:` argument.
    ///
    /// Exposed (rather than kept private inside `loadConfig`) so the Phase 1
    /// key-completeness gate can inspect the raw top-level keys the encoder
    /// actually wrote. Decoding through `StateTaxConfig` would silently fill
    /// in a default for any key the encoder dropped, hiding exactly the
    /// failure mode that gate exists to catch.
    static func fileURL(for state: USState, taxYear: Int,
                         bundle: Bundle = Bundle(for: BundleMarker.self)) throws -> URL {
        guard let url = bundle.url(forResource: "statetax-\(taxYear)-\(state.abbreviation)",
                                    withExtension: "json") else {
            throw LoadError.fileMissing(state: state, taxYear: taxYear)
        }
        return url
    }

    /// Loads and decodes a single jurisdiction's bundled file.
    static func loadConfig(for state: USState, taxYear: Int,
                            bundle: Bundle = Bundle(for: BundleMarker.self)) throws -> StateTaxConfig {
        let url = try fileURL(for: state, taxYear: taxYear, bundle: bundle)
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

    /// Set to `true` if any jurisdiction's bundled JSON failed to load and
    /// `configs2026` fell back to `StateTaxData.configs2026Legacy` for that
    /// state. `false` in normal operation. Task 11 does not build UI for
    /// this; it exists so a later phase can surface a load failure to the
    /// user instead of it being invisible. Not reset once set -- `configs2026`
    /// only evaluates once per process.
    static private(set) var legacyFallbackFired = false

    /// Loads every jurisdiction for `taxYear` against `bundle`, falling
    /// back per state to `StateTaxData.configs2026Legacy` on a load
    /// failure. Returns the resulting dictionary plus the list of states
    /// that needed the fallback (empty in normal operation).
    ///
    /// Deliberately does not call `assertionFailure` itself -- that stays
    /// at the `configs2026` call site below, where it belongs as the loud
    /// debug trap. This function is the fallback-assignment logic
    /// underneath that trap, pulled out so it can be exercised directly by
    /// a test: point it at a `taxYear` with no matching bundled files (the
    /// same seam `throwsForUnknownYear` already uses) and confirm each
    /// state's fallback lands on that SAME state's legacy entry, never a
    /// different one, without ever reaching the trap.
    static func resolveConfigs(taxYear: Int, bundle: Bundle = Bundle(for: BundleMarker.self))
        -> (configs: [USState: StateTaxConfig], fallbackStates: [USState]) {
        var configs: [USState: StateTaxConfig] = [:]
        var fallbackStates: [USState] = []
        for state in USState.allCases {
            do {
                configs[state] = try loadConfig(for: state, taxYear: taxYear, bundle: bundle)
            } catch {
                fallbackStates.append(state)
                configs[state] = StateTaxData.configs2026Legacy[state]
            }
        }
        return (configs, fallbackStates)
    }

    /// Decoded once at first use. Each of the 51 jurisdictions loads
    /// independently (see `resolveConfigs`).
    ///
    /// On a per-state load failure, the release build falls back to that
    /// SAME state's entry in `StateTaxData.configs2026Legacy` -- never a
    /// different state's data, and never an empty dictionary. This is safe
    /// specifically because Task 10's Phase 1 gate (`StateTaxJSONEquivalenceTests`)
    /// proved, across all 51 jurisdictions and three independent layers
    /// (numeric engine output, byte-identical re-encoding, and file key
    /// completeness), that the JSON and the legacy table produce identical
    /// results FOR TAX YEAR 2026, against `configs2026Legacy` as it exists
    /// today. Falling back to legacy is therefore not a degraded guess or a
    /// different state's rules substituted in -- it is provably the same
    /// data for 2026, by that gate's own evidence -- so a bundle failure in
    /// production yields a correct number instead of an error screen or a
    /// crash. That proof does not extend to any other tax year: a future
    /// phase adding, say, 2027 by copying this pattern needs its own
    /// equivalence gate for 2027 before this fallback can be trusted on the
    /// same reasoning.
    ///
    /// Scoping this to "tax year 2026" names the wrong invalidation event,
    /// though. This fallback is safe only while the JSON and
    /// `configs2026Legacy` remain equivalent, which the Phase 1 gate proves
    /// TODAY -- and it is Phase 5, not a tax-year rollover, that breaks that
    /// equivalence first. Phase 5 corrects wrong tax values in the JSON for
    /// this SAME tax year 2026. From the first such correction,
    /// `configs2026Legacy` holds known-wrong data for those states, and this
    /// fallback would serve it in production while the gate itself (which
    /// compares JSON against that same now-wrong legacy table) stops being a
    /// tripwire for exactly the states it was corrected for. At that point
    /// the fallback must be removed or re-pointed at a corrected source, not
    /// merely re-scoped to a later year.
    ///
    /// In debug builds, `assertionFailure` still traps immediately so a
    /// broken bundle is impossible to miss during development; the fallback
    /// only reaches production because `assertionFailure` compiles to a
    /// no-op there.
    static let configs2026: [USState: StateTaxConfig] = {
        let result = resolveConfigs(taxYear: 2026)
        if !result.fallbackStates.isEmpty {
            let names = result.fallbackStates.map(\.abbreviation).joined(separator: ", ")
            assertionFailure("State tax data failed to load for \(names); fell back to configs2026Legacy for those states only.")
            legacyFallbackFired = true
        }
        return result.configs
    }()
}
