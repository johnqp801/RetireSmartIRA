### Task 3: Move five of the six captions into config and render from there

**Corrected 2026-08-06:** as shipped this was FIVE (HI, MA, NC, ID, VT). DC's survivor-toggle
caption stayed a Swift literal in `IncomeSourcesView`; it explains a control, not a limitation.

**Files:**
- Modify: `RetireSmartIRA/IncomeSourcesView.swift`
- Modify: `statetax-2026-{HI,MA,NC,ID,VT,DC}.json`
- Test: `RetireSmartIRATests/StateAccuracyContentTests.swift`

**Interfaces:**
- Consumes: five of the six caption statics from Task 1.
- Produces: `StateAccuracyContent.limitations(for:) -> [String]`, reading `config.verification.knownLimitations`.

- [ ] **Step 1: Write the migration byte-identity test**

```swift
    /// Gate 2, TEMPORARY. Proves the relocation was lossless. Once merged, the
    /// permanent assertions are the structural ones in Gate 1; John may approve
    /// a copy change later without fighting this snapshot.
    @Test("Each moved caption reproduces byte for byte from its new home in config")
    func movedCaptionsAreByteIdentical() {
        let cases: [(USState, String)] = [
            (.hawaii, IncomeSourcesView.hawaiiEmployerFundedCaption),
            (.massachusetts, IncomeSourcesView.massachusettsContributoryCaption),
            (.northCarolina, IncomeSourcesView.northCarolinaBaileyCaption),
            (.idaho, IncomeSourcesView.idahoRetirementBenefitsDeductionCaption),
            (.vermont, IncomeSourcesView.vermontRetirementExclusionCaption)
        ]
        for (state, expected) in cases {
            #expect(StateAccuracyContent.limitations(for: state).contains(expected),
                    "\(state.abbreviation)'s caption did not survive the move to config")
        }
    }
```

**DC's survivor-toggle caption is deliberately NOT in this list.** It explains a control rather than describing a limitation, so it stays a static in the view. Say so in the report if you disagree.

**THE HAWAII COLLISION, found by Task 1 and not anticipated when this plan was written.**
`MultiYearCPABriefing.hawaiiPensionSplitLimitation:421` carries the SAME sentence as Hawaii's caption
except for one word: it says "This **plan**" where the caption says "This **app**", and it is pinned by
a different test. **One `knownLimitations` string cannot hold both.**

Use the mechanism this codebase already has for exactly this. Phase 5b's
`unclassifiedPensionDisclosure` carries a `{scope}` token that resolves to "this figure" on State
Comparison and "this plan" in the CPA briefing. Apply the same treatment: Hawaii's stored sentence
carries `{scope}`, each surface substitutes its own word, and the byte-identity gate asserts that
substituting "app" reproduces the caption and substituting "plan" reproduces the briefing string, both
extracted from the parent commit.

That keeps both approved wordings byte-identical while there is still only one sentence stored.
**Assert the RENDERED string per surface, never the stored one.** The two Hawaii strings differ in
length, 209 against 208, so a gate comparing the stored sentence to either literal fails by
construction. **If any
other jurisdiction turns out to have the same split, apply the same treatment rather than storing two
strings.** Report every collision you find, because Task 1 found this one only by reading the file.

- [ ] **Step 2: Run and confirm it fails**

Expected: FAIL, "has no member 'limitations'".

- [ ] **Step 3: Implement the accessor and populate the five configs**

Add to `StateAccuracyContent`:

```swift
    static func limitations(for state: USState) -> [String] {
        StateTaxData.config(for: state).verification.knownLimitations
    }
```

Add each caption's exact string as an element of that state's `verification.knownLimitations`, alongside `taxYear`, `lastVerified` and `primarySources` sourced from the state's Phase 5b catalogue entry.

- [ ] **Step 4: Point the view at config**

Replace each `if dataManager.selectedState == .hawaii { Label(IncomeSourcesView.hawaiiEmployerFundedCaption, ...) }` branch with one loop over `StateAccuracyContent.limitations(for: dataManager.selectedState)`. Five hardcoded state branches become zero.

- [ ] **Step 5: Run**

```bash
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh StateAccuracyContentTests Phase3bPresentationTests Phase5bUnclassifiedPensionDisclosureTests
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure add -A
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure commit -m "refactor(disclosure): captions render from config, not from state branches"
```

---

