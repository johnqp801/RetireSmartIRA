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
    /// case. `catalogue()` above can only ever see what a fixture carries, so a
    /// defect like this is invisible to it -- and a real defect invisible to the
    /// catalogue is exactly the thing Phase 5 would never act on. This list is
    /// the deliberate, documented alternative to letting it disappear: DATA, not
    /// a comment, so it survives independent of any one report or ledger.
    ///
    /// Distinct from both a pinned `knownDefect` (measured, cited, in
    /// `catalogue()`) and a clean pass (measured, cited, agrees with the form):
    /// this is measured to be WRONG in direction and mechanism, and cited for
    /// the mechanism, but something stops a fixture from asserting it.
    ///
    /// TWO ADMISSIBLE KINDS OF BLOCKER, and a contributor deciding whether their
    /// finding belongs here should check theirs against both. The list held only
    /// the first kind until Phase 5b Task 3, and an earlier version of this
    /// comment defined the whole category by it, which was the differentia of
    /// the single member that happened to exist rather than the genus:
    ///
    ///   1. NO ADMISSIBLE FIGURE. The correct `expectedStateTax` depends on a
    ///      dollar amount no reachable primary source states, so the fixture
    ///      could be written but its expected value could not be derived. The
    ///      Missouri entry below. Resolved by a source becoming reachable.
    ///
    ///   2. NOT EXPRESSIBLE. The household itself cannot be described in the
    ///      app's model, so the fixture cannot be written at all and a fixture
    ///      asserting a tax for it would assert something unreachable. The
    ///      Kansas TSP entry below: no `PlanClassificationChoice` row writes a
    ///      federal defined-contribution plan, so no user can classify one and
    ///      no fixture can pin what happens when they do. Resolved by a product
    ///      decision, not by research.
    ///
    /// What both share, and what actually defines the category: a defect
    /// measured against a state's own published form, whose mechanism is cited,
    /// which no golden case can hold. A finding that COULD be pinned belongs in
    /// a fixture with a `knownDefect` block instead, not here.
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
        ),
        UnpinnedDefect(
            state: "KS",
            summary: """
                Kansas's Schedule S Line A14 exempts federal retirement benefits
                "including Thrift Savings Plans" by name, inside the same federal
                category the Phase 5b Task 3 rule implements. A TSP is a
                defined-contribution plan, and that rule ships
                `matchStructures: ["definedBenefit"]`, so a Kansas resident holding a
                TSP is taxed in full on it. The direction is UNDER-exemption, i.e. the
                app over-taxes, which is the opposite direction from every other
                finding in this file. The constraint is deliberate and is the safer of
                the two errors available: Line A14 names "Kansas Public Employees'
                Retirement (KPERS) ANNUITIES", not the separate KPERS 457
                deferred-compensation plan, so dropping the structure constraint to
                reach TSP would simultaneously grant an unauthorised full exclusion to
                every government salary-reduction plan. See the KS-5 fixture's own
                source string, which quotes the A14 language, and
                Phase5bKansasPerSourceTests.namedSourceInAnotherStructureIsNotMatched,
                which pins the constraint this entry records the cost of.
                """,
            blockedOn: """
                NOT a missing dollar figure, unlike the Missouri entry above: this one
                is blocked on EXPRESSIVENESS, and this list is widened by exactly one
                kind of blocker to hold it rather than letting a real, measured
                under-exemption live only in a task report. No golden case can pin it,
                because no fixture can describe the household: `PlanClassificationChoice`
                has no row writing a federal DEFINED-CONTRIBUTION plan, so a Kansas TSP
                holder cannot classify one through the app at all, and a fixture
                asserting a tax for a classification no user can select would assert
                something unreachable. Resolving it needs a product decision, not
                research: either a picker row for a federal defined-contribution plan
                plus a second Kansas rule scoped to it, or an explicit decision that
                federal TSP stays unmodelled and is disclosed to Kansas users. Both are
                out of Task 3's scope. Revisit when Phase 6's disclosure work decides
                which.
                """
        ),
        UnpinnedDefect(
            state: "MA",
            summary: """
                Massachusetts excludes a Massachusetts state or local employee
                CONTRIBUTORY pension from Massachusetts gross income (mass.gov, Tax
                Treatment of Government Pensions in Massachusetts). A NONCONTRIBUTORY
                municipal pension is on none of that guidance's enumerated exempt
                categories and stays ordinary taxable income. The Phase 5b Task 4 rule
                ships `matchSources: ["ownStateOrLocal", "uniformedServices"]` at
                `definedBenefit`, and `RetirementPlanClassification` has no
                contributory axis, so a Massachusetts resident holding a
                noncontributory municipal pension is granted the full exclusion and is
                UNDER-taxed. Measured: $0.00 against $3,000.00 on the fixture's own
                $60,000 single filer at the flat 5% rate. The direction is
                under-taxation, which is the dangerous direction, and it is recorded
                here rather than avoided because the alternative was to leave the three
                CITED Massachusetts corrections (MA-1, MA-3, MA-4) undelivered to
                protect a category the fixture's own source note states is an inference
                from a closed list rather than a sentence on the page. It is REACHABLE
                by a real user, unlike the Kansas entry above: the picker's "Government
                pension, my own state or locality" row is the only row such a person
                can honestly select, and it writes exactly the classification the rule
                matches.
                """,
            blockedOn: """
                NOT EXPRESSIBLE, the same blocker kind as the Kansas entry above but
                for a different reason, and the reason is why no golden case can hold
                it. The contributory and noncontributory Massachusetts municipal
                households are described by the SAME `RetirementPlanClassification`:
                `(definedBenefit, ownStateOrLocal)`. Every field that would describe
                one describes the other. A golden case for the noncontributory
                household would therefore carry inputs byte-identical to MA-1's and a
                contradictory `expectedStateTax` ($3,000.00 against MA-1's $0.00), so
                the fixture set would assert a contradiction rather than a defect.
                Writing it was attempted in Task 4 and rejected for that reason.
                Resolving it needs a THIRD classification axis, employee-contributory
                against employer-funded, on `RetirementPlanClassification`, matched by
                `PerSourceExemptionRule`, with a picker affordance so a real user can
                state it and a migration default for every saved row that cannot. That
                axis is not Massachusetts-only and must not be designed from
                Massachusetts alone: Hawaii's golden fixture (Phase 5b Task 5) turns on
                the same axis in the OPPOSITE direction (employer-funded exempt,
                employee-funded taxable) and currently proxies it through
                `PlanStructure`, a different forced fit for the same missing dimension.
                Two jurisdictions with two incompatible proxies is a missing dimension,
                not a quirk. Revisit once Hawaii's authority-derived fixture has been
                read, and design the axis against both; the phase's own precedent is
                that a shared classification axis lands in the model task
                (`isSurvivorBenefit`, Task 1) and is consumed by the jurisdiction tasks,
                not invented by one of them.
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
