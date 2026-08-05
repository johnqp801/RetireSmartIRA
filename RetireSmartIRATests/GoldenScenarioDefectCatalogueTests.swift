import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 4's actual deliverable, in executable form.
///
/// The audit in 2026-08-02-full-50-state-verification.md is a single-source
/// research memo and says so. This suite is what converts it into evidence: every
/// entry here is a jurisdiction whose shipped behavior was measured against its
/// own published form and found to disagree, with the form cited.
///
/// Reading a green run of this suite: a `knownDefect` entry passing does NOT mean
/// the engine agrees with the state's own form. It means the opposite -- the
/// engine matches `observedToday` and DELIBERATELY does not match
/// `expectedStateTax`, because `GoldenScenarioSingleYearTests` pins that exact,
/// measured disagreement. "All tests pass" means every jurisdiction either
/// matches its own published form or disagrees with it in the exact, catalogued
/// way its fixture says it does. See `.claude/memory/roadmap/
/// 2026-08-04-state-tax-phase4-ledger.md` for the full catalogue rendered as
/// prose and the comparison against the audit's predictions.
@Suite("Golden scenarios, defect catalogue")
struct GoldenScenarioDefectCatalogueTests {

    struct Entry {
        let state: String
        let scenario: String
        let tier: String
        let summary: String
        let observed: Double
        let expected: Double
    }

    static func catalogue() throws -> [Entry] {
        var entries: [Entry] = []
        for abbreviation in GoldenScenarioCoverageTests.covered {
            guard let file = try? GoldenScenario.load(abbreviation: abbreviation) else { continue }
            for scenario in file.scenarios {
                guard let defect = scenario.knownDefect else { continue }
                entries.append(Entry(state: abbreviation, scenario: scenario.name,
                                     tier: defect.tier, summary: defect.summary,
                                     observed: defect.observedToday,
                                     expected: scenario.expectedStateTax))
            }
        }
        return entries
    }

    @Test("The catalogue is non-empty and every entry is well formed")
    func catalogueIsWellFormed() throws {
        let entries = try Self.catalogue()
        #expect(!entries.isEmpty, """
            No defects catalogued at all. The audit predicted roughly 29 defective
            jurisdictions. An empty catalogue means either the fixtures were written from
            the app's own output rather than from published forms, or knownDefect blocks
            were omitted. Both are Phase 4 failures.
            """)
        for entry in entries {
            #expect(!entry.summary.isEmpty, "\(entry.state): defect with no mechanism named")
            #expect(["tier1", "tier2", "tier3", "tier4", "unclassified"].contains(entry.tier),
                    "\(entry.state): unrecognised tier '\(entry.tier)'")
            #expect(abs(entry.observed - entry.expected) >= 0.01,
                    "\(entry.state) / \(entry.scenario): catalogued as defective but the two figures agree")
        }
    }

    @Test("Print the catalogue, grouped by tier")
    func printCatalogue() throws {
        let entries = try Self.catalogue()
        let byTier = Dictionary(grouping: entries, by: \.tier)
        var report = "\nPHASE 4 DEFECT CATALOGUE: \(entries.count) cases across "
        report += "\(Set(entries.map(\.state)).count) jurisdictions\n"
        for tier in ["tier1", "tier2", "tier3", "tier4", "unclassified"] {
            guard let group = byTier[tier], !group.isEmpty else { continue }
            report += "\n\(tier.uppercased()), \(group.count) cases, "
            report += "\(Set(group.map(\.state)).count) jurisdictions\n"
            for entry in group.sorted(by: { $0.state < $1.state }) {
                let delta = entry.observed - entry.expected
                let direction = delta > 0 ? "OVERTAXES" : "UNDERTAXES"
                report += String(format: "  %@  %@ by $%.2f, %@\n",
                                 entry.state, direction, abs(delta), entry.summary)
            }
        }
        print(report)
        #expect(!entries.isEmpty)
    }

    // MARK: - Known but unpinned

    /// A real, confirmed defect the phase found but could NOT pin with a golden
    /// case, because the correct `expectedStateTax` depends on a dollar figure
    /// no reachable primary source states. `catalogue()` above can only ever see
    /// what a fixture carries, so a defect like this is invisible to it -- and a
    /// real defect invisible to the catalogue is exactly the thing Phase 5 would
    /// never act on. This list is the deliberate, documented alternative to
    /// letting it disappear: DATA, not a comment, so it survives independent of
    /// any one report or ledger.
    ///
    /// Distinct from both a pinned `knownDefect` (measured, cited, in
    /// `catalogue()`) and a clean pass (measured, cited, agrees with the form):
    /// this is measured to be WRONG in direction and mechanism, cited for the
    /// mechanism, but has no admissible source for the one number
    /// `expectedStateTax` would need, so no fixture asserts it.
    struct UnpinnedDefect {
        let state: String
        /// The mechanism, stated the same way a `knownDefect.summary` would be.
        let summary: String
        /// What's missing, and what would resolve it. Not "give up" -- a
        /// concrete blocker Phase 5 (or a later pass) can check again.
        let blockedOn: String
    }

    static let knownButUnpinned: [UnpinnedDefect] = [
        UnpinnedDefect(
            state: "MO",
            summary: """
                Missouri's public pension exemption is coded `.full` (unlimited) in
                StateTaxData.swift. Real law (MO-A 2025, Part 3, Section A, Line 2)
                caps it at the LESSER of the pension received or each individual's own
                maximum Social Security benefit, reduced by any Social Security
                deduction the same person claims. This is the exact defect the
                2026-08-02 audit named in section 5, Confirmed CORRECT, as a caveat --
                not a Tier 1 finding. The 2026-08-04 b5 batch confirmed the
                mechanism directly against the published MO-A form and Missouri DOR's
                pension FAQ, and hand-derived the correct arithmetic for a $150,000 /
                $120,000 MFJ public-pension case: correct tax $6,157.41 against the
                engine's measured $0.00.
                """,
            blockedOn: """
                The one figure `expectedStateTax` needs -- the 2026 maximum Social
                Security benefit at full retirement age -- has no reachable official
                source as of 2026-08-04. Tried, in order, and all exhausted: the 2026
                Federal Register COLA determination notice (reachable, official, does
                not carry this figure); ssa.gov's press release, fact-sheet, and OACT
                example-max pages (every path returns HTTP 403 to both WebFetch and
                curl); CRS Report 94-803 (reachable, does not carry this figure);
                Missouri's own 2026 MO-A form (404, not yet published); the Wayback
                Machine (no snapshot of the SSA pages that would carry it). The
                scenario that would have pinned this was written, verified arithmetic
                for a secondary-sourced $49,824 figure, and then DELETED rather than
                shipped on that secondary source, per this phase's own citation
                discipline (Missouri's fixture now carries 3 scenarios, not 4).
                Revisit when ssa.gov becomes reachable from this environment, or when
                Missouri DOR publishes the 2026 MO-A form.
                """
        )
    ]

    @Test("Every known-but-unpinned defect names both a real mechanism and a concrete blocker")
    func knownButUnpinnedIsWellFormed() {
        #expect(!Self.knownButUnpinned.isEmpty, """
            No known-but-unpinned defects recorded. Missouri's public-pension cap is a
            confirmed real defect the phase found and could not pin (see the Task 5
            report and the 2026-08-04 ledger). An empty list here would silently drop
            it from Phase 5's inheritance.
            """)
        for entry in Self.knownButUnpinned {
            #expect(!entry.summary.isEmpty, "\(entry.state): unpinned defect with no mechanism named")
            #expect(!entry.blockedOn.isEmpty, "\(entry.state): unpinned defect with no stated blocker")
        }
    }
}
