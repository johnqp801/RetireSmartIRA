import Testing
import Foundation
@testable import RetireSmartIRA

/// Generates the bundled per-state JSON from the legacy hardcoded table.
///
/// Generated, never hand-written. Transcribing 51 jurisdictions by hand would
/// inject the exact class of error this whole program exists to remove.
///
/// Files are written to `RetireSmartIRA/Resources/StateTaxData/<year>/` for
/// human organization in the source tree, but named `statetax-<year>-<ABBR>.json`
/// rather than plain `<ABBR>.json`. This matters because the target uses
/// `PBXFileSystemSynchronizedRootGroup`, which FLATTENS this directory when it
/// bundles resources: every file lands directly in `Contents/Resources/` with
/// no subdirectory surviving packaging (verified by inspecting a real build).
/// A plain `<ABBR>.json` name would collide the day a second tax year is
/// added (2027's `CA.json` would silently overwrite or lose to 2026's), even
/// though the spec requires adding a year to be purely additive. The
/// year-prefixed name is unique across tax years regardless of bundle
/// layout, and it follows the convention this codebase already uses for
/// `tax-<year>.json` (see `TaxYearConfig.swift`, `load(forYear:)`).
///
/// Disabled in the normal loop. Run deliberately with:
///
///     TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA \
///         -destination 'platform=macOS' \
///         -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests \
///         ENABLE_APP_SANDBOX=NO
///
/// Two gotchas, both required, neither obvious from the command alone:
///
/// 1. The env var MUST be shell-prefixed as `TEST_RUNNER_STATE_TAX_GENERATE=1`
///    (set before `xcodebuild`, not appended after it as a trailing argument).
///    `RetireSmartIRATests.xctest` is hosted inside `RetireSmartIRA.app`
///    (same as the Display Audit Harness), and that host process does not
///    inherit the invoking shell's environment. `xcodebuild` forwards any
///    variable prefixed `TEST_RUNNER_` into the test host with the prefix
///    stripped; a plain `STATE_TAX_GENERATE=1`, in any position, is silently
///    dropped and the test just skips rather than running or failing.
///
/// 2. `ENABLE_APP_SANDBOX=NO` is required as a command-line build-setting
///    override. `RetireSmartIRA` ships fully sandboxed
///    (`ENABLE_APP_SANDBOX = YES` in `project.pbxproj`, no filesystem
///    entitlement declared), and because the test bundle runs hosted inside
///    the app process, the write to the source tree is denied with
///    `NSCocoaErrorDomain Code=513 "Operation not permitted"` without this
///    override. The override is command-line-only for this one local,
///    opt-in, dev-only run; it does not touch `project.pbxproj` and does not
///    affect the shipped app's entitlements.
@Suite("State tax JSON generator (manual)")
struct StateTaxDataGeneratorTests {

    @Test("Generate all 51 jurisdiction files",
          .enabled(if: ProcessInfo.processInfo.environment["STATE_TAX_GENERATE"] == "1"))
    func generateAll() throws {
        let taxYear = 2026
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // RetireSmartIRATests
            .deletingLastPathComponent()   // repo root
        let outDir = repoRoot
            .appendingPathComponent("RetireSmartIRA/Resources/StateTaxData/\(taxYear)")
        try FileManager.default.createDirectory(
            at: outDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        var written = 0
        for state in USState.allCases {
            guard let config = StateTaxData.configs2026Legacy[state] else {
                Issue.record("No legacy config for \(state.abbreviation)")
                continue
            }
            let data = try encoder.encode(config)
            let fileName = "statetax-\(taxYear)-\(state.abbreviation).json"
            try data.write(to: outDir.appendingPathComponent(fileName))
            written += 1
        }
        #expect(written == 51, "expected 51 jurisdictions, wrote \(written)")
    }
}
