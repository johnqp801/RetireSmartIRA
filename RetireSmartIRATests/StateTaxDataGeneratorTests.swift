import Testing
import Foundation
@testable import RetireSmartIRA

/// Generates the bundled per-state JSON from the legacy hardcoded table.
///
/// Generated, never hand-written. Transcribing 51 jurisdictions by hand would
/// inject the exact class of error this whole program exists to remove.
///
/// Disabled in the normal loop. Run deliberately with:
///   STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA \
///     -destination 'platform=macOS' \
///     -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests
@Suite("State tax JSON generator (manual)")
struct StateTaxDataGeneratorTests {

    @Test("Generate all 51 jurisdiction files",
          .enabled(if: ProcessInfo.processInfo.environment["STATE_TAX_GENERATE"] == "1"))
    func generateAll() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // RetireSmartIRATests
            .deletingLastPathComponent()   // repo root
        let outDir = repoRoot
            .appendingPathComponent("RetireSmartIRA/Resources/StateTaxData/2026")
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
            try data.write(to: outDir.appendingPathComponent("\(state.abbreviation).json"))
            written += 1
        }
        #expect(written == 51, "expected 51 jurisdictions, wrote \(written)")
    }
}
