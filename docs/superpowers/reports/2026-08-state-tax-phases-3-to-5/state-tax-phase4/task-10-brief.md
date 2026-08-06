# Task 10 brief: close the phase


---

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md`. §3.4 governs fixture shape and citation discipline; §4a defines this phase's gate.
- **Phase 4 corrects NO tax value.** Not one line of `StateTaxData.swift`, `TaxCalculationEngine.swift` or any `Resources/StateTaxData/2026/*.json` changes in this phase. Every correction is Phase 5. A task that "fixes" a state has failed.
- **`expectedStateTax` MUST be derived from the state's own published form, instructions or worked example.** Never from this app's output. A fixture whose expected value came from the engine proves only that the engine agrees with itself.
- **Citation discipline (§3.4, the PROCESS control this phase carries):** every fixture carries `source` and a resolvable https `sourceURL`. **The fixture author, and the reviewer, must each state in their report that they personally opened every `sourceURL` and checked every clause of `source` against it.** Not "a citation is present". Not "the URL resolves". Every clause, against the page. This exists because three fixtures in Phase 2 had confidently wrong citations whose expected VALUES were correct, so every test passed.
- **Admissible sources:** state DOR pages, statutes, enrolled bills, official form instructions. Advisor blogs, tax-prep vendor help pages and news articles are inadmissible as sole basis. Any claimed 2024-2026 change must state the bill number and its final disposition (signed, vetoed, died). This is the check that catches the Colorado class of error, where a syndicated guide reported a bill that was Postponed Indefinitely on 2025-02-27 as enacted law.
- **`CANNOT_VERIFY` is a legitimate outcome.** If a state's rule cannot be established from a primary source, record the jurisdiction as unverified per §3.4 rather than guessing. The failure mode is confident fabrication, not silence.
- **No em dashes** in any file, per user preference. This has been a recurring review finding; a report claiming there are none when there are is treated as the worse half of the defect.
- **Suite is the source of truth** (CLAUDE.md). Baseline at branch point, MEASURED on this branch 2026-08-04: 1,845 Swift Testing in 290 suites + 509 XCTest, 0 failures. (The 1,752 + 505 figure in the Phase 3b ledger was measured on the phase3b branch tip, BEFORE the RMD spouse attribution work merged; that work added five test files and 1,835 lines, which accounts for the whole difference. Do not cite the Phase 3b number as this branch's baseline.)
- **Never edit files by chained `cd`.** Bash cwd resets between calls. Use absolute paths and `git -C`. This bit the previous phase four times, once committing a ledger to the wrong branch.

**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4`, branch `feature/state-tax-phase4`, off `main` @ `6097430`.

**Build command (always pass `-project` explicitly, per the build trap in the 2026-08-04 session note):**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

---

### Task 10: Close the phase: completeness, catalogue, and the gate

**Files:**
- Modify: `RetireSmartIRATests/GoldenScenarioCoverageTests.swift`
- Create: `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift`
- Create: `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md`

**Interfaces:**
- Consumes: all 51 fixtures, `KnownDefect` from Task 1.

- [ ] **Step 1: Flip completeness on**

Replace `covered` and add the full sweep:

```swift
    /// All 51 jurisdictions. Derived, not hand-listed: see the doc on
    /// `everyJurisdictionHasAFixture` for why a literal list is a liability here.
    static let covered: [String] = USState.allCases.map(\.abbreviation)

    @Test("Every one of the 51 jurisdictions has a fixture")
    func everyJurisdictionHasAFixture() throws {
        var missing: [String] = []
        for state in USState.allCases {
            if (try? GoldenScenario.load(abbreviation: state.abbreviation)) == nil {
                missing.append(state.abbreviation)
            }
        }
        #expect(missing.isEmpty,
                """
                No golden fixture bundled for: \(missing.sorted().joined(separator: ", ")).
                Phase 4's deliverable is all 51. A jurisdiction with no fixture is not
                "assumed correct", it is unverified, and Phase 6 must render it as such.
                """)
        #expect(USState.allCases.count == 51)
    }
```

- [ ] **Step 2: Run and verify**

Expected: PASS if all seven batches landed. If it fails, the named jurisdictions are genuinely missing and the phase is not done. Do not weaken this test to close the phase.

- [ ] **Step 3: Write the catalogue test**

Create `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 4's actual deliverable, in executable form.
///
/// The audit in 2026-08-02-full-50-state-verification.md is a single-source
/// research memo and says so. This suite is what converts it into evidence: every
/// entry here is a jurisdiction whose shipped behavior was measured against its
/// own published form and found to disagree, with the form cited.
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
}
```

- [ ] **Step 4: Run it and capture the output**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioDefectCatalogueTests 2>&1 | tail -80
```

Save the printed catalogue verbatim into the ledger. **This is the artifact Phase 5 consumes.**

- [ ] **Step 5: Compare the catalogue against the audit's predictions**

The audit predicted roughly 29 defective jurisdictions in five categories. Write the comparison into the ledger explicitly:

  - **Predicted and confirmed**: the audit was right.
  - **Predicted and NOT reproduced**: either the audit was wrong or the fixture is. Investigate each one and say which. This is the single most valuable output of the phase, because it is where a single-source memo gets falsified.
  - **NOT predicted but found**: the audit missed it. Expect some, since the audit covered ONE of thirteen configuration dimensions.
  - **`CANNOT_VERIFY`**: list them; they become Phase 6 `knownLimitations` rather than Phase 5 corrections.

- [ ] **Step 6: Run the full suite**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

Expected: **0 failures.** Every one of the 51 jurisdictions either matches its own published form or carries a pinned, catalogued defect. That is the Phase 4 gate.

- [ ] **Step 7: Verify no tax value moved**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 diff --stat main -- RetireSmartIRA/
```

Expected: **empty.** Phase 4 touches no production file. If this shows anything under `RetireSmartIRA/`, a task corrected something it should not have and it must be reverted into Phase 5.

- [ ] **Step 8: Write the ledger** at `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md`, following the shape of `2026-08-03-state-tax-phase3b-ledger.md`: per-task outcomes, mutations that discriminated, findings recorded but not fixed, and the full defect catalogue.

- [ ] **Step 9: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/ .claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): all 51 jurisdictions covered, defect catalogue closed"
```

---
