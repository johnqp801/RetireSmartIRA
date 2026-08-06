### Task 2: Add `taxYear` to `StateVerification` and gate metadata completeness

Gate 4 of the spec. The page must head with state AND tax year, and every jurisdiction must carry a verification date and at least one HTTPS source.

**SCOPE DECISION, and it is the one thing in this plan the implementer must not silently widen:** 50 of 51 configs have an empty `lastVerified` today. Only Georgia is populated. **This task enforces completeness ONLY for the covered jurisdictions in Task 4's list.** Applying it to all 51 would require sourcing 50 states' primary references, which is a separate body of work and is NOT in this plan. The gate is written so extending it later is a one-line change to its state list.

**Files:**
- Modify: `RetireSmartIRA/StateTaxVerification.swift`
- Modify: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-GA.json` (add `taxYear`)
- Test: `RetireSmartIRATests/StateAccuracyContentTests.swift`

**Interfaces:**
- Produces: `StateVerification.taxYear: Int` (defaulted to `0` on `.unverified`), and `StateAccuracyContent.coveredJurisdictions: Set<USState>`, consumed by Tasks 4, 7 and 8.

- [ ] **Step 1: Write the failing test**

```swift
    /// Gate 4. Scoped to jurisdictions this plan populates; see the plan's
    /// scope note. Extending to all 51 is a one-line change here.
    @Test("Every covered jurisdiction carries a tax year, a verified date and an HTTPS source")
    func coveredJurisdictionsCarryCompleteVerification() {
        for state in StateAccuracyContent.coveredJurisdictions {
            let v = StateTaxData.config(for: state).verification
            #expect(v.taxYear == 2026, "\(state.abbreviation) verification.taxYear must state the config's own year")
            #expect(!v.lastVerified.isEmpty, "\(state.abbreviation) has no lastVerified")
            #expect(v.primarySources.contains { $0.contains("https://") },
                    "\(state.abbreviation) has no HTTPS primary source")
        }
    }
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh StateAccuracyContentTests
```
Expected: FAIL, "has no member 'taxYear'".

- [ ] **Step 3: Add the field**

In `StateTaxVerification.swift`, add `let taxYear: Int` to the struct, add it to the memberwise init with no default so a config cannot omit it silently, decode it with `decodeIfPresent(Int.self, forKey: .taxYear) ?? 0`, and set `taxYear: 0` on `.unverified`.

**Note precisely what this does.** These configs are JSON, so a missing field fails at DECODE or TEST time, not at Swift compile time. The gate is the test above, not the compiler. Do not describe it otherwise in any comment.

- [ ] **Step 4: Populate Georgia and define the covered set**

Add `"taxYear": 2026` to Georgia's `verification` block. Create `StateAccuracyContent.swift` with only:

```swift
enum StateAccuracyContent {
    /// Jurisdictions this release populates with limitation sentences.
    /// Every member is traceable to a pinned defect or a knownButUnpinned entry.
    static let coveredJurisdictions: Set<USState> = [
        .kansas, .massachusetts, .hawaii, .arizona, .northCarolina, .idaho,
        .vermont, .districtOfColumbia, .newYork, .missouri,
        .iowa, .newMexico, .georgia, .utah, .indiana
    ]
}
```

- [ ] **Step 5: Run, expecting 14 failures naming the unpopulated states**

```bash
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh StateAccuracyContentTests
```
Expected: FAIL, one message per covered state except GA. **That failure list is Task 4's worklist.** Record it in the task report.

- [ ] **Step 6: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure add -A
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure commit -m "feat(disclosure): verification carries a tax year, and a gate that demands it"
```

The suite is RED at the end of this task, deliberately, and Task 4 turns it green. Say so in the report.

---

