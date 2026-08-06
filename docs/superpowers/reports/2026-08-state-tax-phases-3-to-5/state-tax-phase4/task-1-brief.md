### Task 1: The `knownDefect` mechanism

**Files:**
- Modify: `RetireSmartIRATests/GoldenScenario.swift`
- Modify: `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift:127-141`
- Test: `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`

**Interfaces:**
- Produces: `KnownDefect` (`tier: String`, `summary: String`, `observedToday: Double`), `GoldenScenario.knownDefect: KnownDefect?`. Every later task authors fixtures against these names.

**Why two assertions and not one.** A fixture that merely skipped the comparison when a defect is known would go quiet: the state would be free to drift to any other wrong number and nothing would notice. Pinning `observedToday` means any drift fails. Asserting the engine still does NOT match the form means the pin is self-cleaning: when Phase 5 corrects the state, this test fails and the implementer is forced to delete the block rather than leaving a stale defect record behind. This is the same "pin as observed, never as an inequality" discipline already established by `newJerseyCrossPathGapPinnedAsObserved`.

- [ ] **Step 1: Write the failing test**

Add to `GoldenScenarioSingleYearTests.swift`:

```swift
    @Test("A knownDefect fixture pins today's wrong figure and asserts it is still wrong")
    func knownDefectMechanismRoundTrips() throws {
        let json = """
        {"state":"XX","taxYear":2026,"scenarios":[{
          "name":"synthetic",
          "source":"synthetic fixture for the mechanism test, cites no authority",
          "sourceURL":"https://example.invalid/none",
          "filingStatus":"single","primaryAge":65,"spouseAge":null,
          "federalAGI":50000,"taxableSocialSecurity":0,"pensionIncome":50000,
          "iraWithdrawals":0,"rothConversion":0,
          "expectedStateTax":1218.88,
          "knownDefect":{"tier":"tier2","summary":"missing personal exemption","observedToday":2171.52}
        }]}
        """
        let file = try JSONDecoder().decode(GoldenScenarioFile.self, from: Data(json.utf8))
        let scenario = try #require(file.scenarios.first)
        let defect = try #require(scenario.knownDefect)
        #expect(defect.tier == "tier2")
        #expect(abs(defect.observedToday - 2171.52) < 0.01)
        #expect(abs(scenario.expectedStateTax - 1218.88) < 0.01)
    }

    @Test("A fixture with no knownDefect decodes it as nil")
    func absentKnownDefectDecodesNil() throws {
        let file = try GoldenScenario.load(abbreviation: "PA")
        let scenario = try #require(file.scenarios.first)
        #expect(scenario.knownDefect == nil)
    }
```

- [ ] **Step 2: Run and verify it fails**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests 2>&1 | tail -20
```

Expected: COMPILE FAILURE, `value of type 'GoldenScenario' has no member 'knownDefect'`. A compile failure is a valid RED here because the type does not exist yet.

- [ ] **Step 3: Add the type**

In `GoldenScenario.swift`, add above `struct GoldenScenarioFile`:

```swift
/// Records that a jurisdiction's shipped behavior is KNOWN to disagree with
/// its own published form, so the disagreement is pinned rather than silently
/// tolerated.
///
/// Phase 4 writes fixtures to CORRECT LAW, which means roughly 29 jurisdictions
/// are expected to disagree with the engine. Without this block the suite would
/// go red across the board and the phase could not gate. With it, every defect
/// is a named, pinned, citable record and the suite stays green.
///
/// `observedToday` is the figure the engine ACTUALLY produces right now. It is
/// not an endorsement. It exists so that any drift in a defective state fails a
/// test, and so Phase 5 can measure its own correction against a real baseline
/// rather than a remembered one.
struct KnownDefect: Codable {
    /// "tier1" | "tier2" | "tier3" | "tier4" | "unclassified", matching the
    /// tiers in `.claude/memory/roadmap/2026-08-02-full-50-state-verification.md`.
    let tier: String
    /// One sentence naming the mechanism, not the symptom.
    let summary: String
    /// Today's engine output for this scenario, measured, never predicted.
    let observedToday: Double
}
```

And add to `GoldenScenario`, after `classifiedPensionSources`:

```swift
    /// Present only when the engine is KNOWN to disagree with `expectedStateTax`.
    /// Absent (nil) means the jurisdiction is expected to match its own form.
    let knownDefect: KnownDefect?

    /// Ordinary income carried by `federalAGI` that no other field on this
    /// fixture represents, DECLARED so the shape invariant can stay an exact
    /// equality instead of an inequality.
    ///
    /// DECLARATIVE ONLY. It is never summed into anything and never reaches an
    /// engine: `federalAGI` remains the single number the single-year runner
    /// passes in. Wiring this into the runner would change New York's shipped
    /// fixture values, which Phase 4 forbids.
    ///
    /// New York's first fixture is the precedent and, at the time this field was
    /// added, the only user of it: $90,000 of AGI against a $70,000 classified
    /// government pension, with $20,000 of unrelated ordinary income that
    /// previously existed only inside a prose `source` string.
    ///
    /// A fixture with a nonzero value here can never join
    /// `GoldenScenarioCrossPathTests.agreeing`, because the multi-year runner
    /// derives AGI from the components and is structurally blind to this income.
    let otherOrdinaryIncome: Double?
```

- [ ] **Step 4: Run and verify it passes**

Same command as Step 2. Expected: both new tests PASS, all five existing fixtures still decode (they carry no `knownDefect` key, and Swift's synthesized `decodeIfPresent` for an Optional handles that).

- [ ] **Step 5: Switch the assertion to two branches**

Replace the body of `singleYearMatchesGolden`'s loop:

```swift
        for scenario in file.scenarios {
            let actual = Self.singleYearStateTax(scenario, state: state)
            if let defect = scenario.knownDefect {
                #expect(abs(actual - defect.observedToday) < 0.01,
                        """
                        \(abbreviation) / \(scenario.name): engine now \(actual), \
                        pinned observed value \(defect.observedToday).
                        A DEFECTIVE state moved. Diagnose what changed before touching this pin.
                        Defect: \(defect.summary)
                        """)
                #expect(abs(actual - scenario.expectedStateTax) >= 0.01,
                        """
                        \(abbreviation) / \(scenario.name) now MATCHES its published form \
                        (\(scenario.expectedStateTax)). The defect appears to be FIXED.
                        Delete the knownDefect block from this fixture so the case becomes a
                        normal passing assertion. Do not update observedToday to keep it quiet.
                        """)
            } else {
                #expect(abs(actual - scenario.expectedStateTax) < 0.01,
                        """
                        \(abbreviation) / \(scenario.name): engine \(actual), \
                        form says \(scenario.expectedStateTax).
                        Source: \(scenario.source)
                        Phase 4 corrects no tax value. If the engine is wrong, add a knownDefect
                        block recording the MEASURED observedToday and leave the fix for Phase 5.
                        """)
            }
        }
```

- [ ] **Step 6: Run the full suite**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

Expected: 0 failures. Baseline 1,752 Swift Testing + 505 XCTest, now +2.

- [ ] **Step 7: Prove the mechanism by mutation**

Temporarily add a `knownDefect` block to PA's first fixture with a deliberately wrong `observedToday` of `999.0`. Run the PA test. It MUST fail on the first `#expect`. Then set `observedToday` to PA's real observed figure and confirm it fails on the SECOND `#expect` instead (because PA genuinely matches its form). Revert the fixture completely and confirm `git diff` is empty.

Record both failure messages in the ledger. A mechanism that cannot be shown to fail is not a mechanism.

- [ ] **Step 8: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/GoldenScenario.swift RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): pin known defects instead of tolerating them"
```

---

