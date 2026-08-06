### Task 1: Hoist the three inline captions to testable statics

Three captions are already `static let` (`northCarolinaBaileyCaption:430`, `idahoRetirementBenefitsDeductionCaption:471`, `vermontRetirementExclusionCaption:517`). Three are inline literals in the view body and cannot be asserted against: DC's survivor-toggle explanation (`:1528`), Hawaii (`:1534`), Massachusetts (`:1560`). Two Phase 5b reviews flagged this. Hoist them so Task 3's byte-identity gate can exist at all.

**Files:**
- Modify: `RetireSmartIRA/IncomeSourcesView.swift`
- Test: `RetireSmartIRATests/StateAccuracyContentTests.swift` (new)

**Interfaces:**
- Produces: `PlanClassificationChoice.hawaiiEmployerFundedCaption`, `.massachusettsContributoryCaption`, `.districtOfColumbiaSurvivorToggleCaption`, all `static let String`, alongside the three that already exist.

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/StateAccuracyContentTests.swift`:

```swift
import Testing
@testable import RetireSmartIRA

@Suite("State accuracy disclosure")
struct StateAccuracyContentTests {

    /// The three captions that were inline view-body literals before this task.
    /// Pinned so the hoist is provably lossless; Task 3 moves them to config and
    /// re-asserts the same strings from their new home.
    @Test("The three hoisted captions match the literals they replaced")
    func hoistedCaptionsAreUnchanged() {
        #expect(PlanClassificationChoice.hawaiiEmployerFundedCaption ==
            "Hawaii excludes the employer-funded portion of a pension from state tax. This app does not model the split between employer-funded and employee-contributed amounts, so your Hawaii state tax may be overstated.")
        #expect(PlanClassificationChoice.massachusettsContributoryCaption ==
            "Massachusetts excludes a contributory state or local pension but taxes a noncontributory one. This app does not model that distinction, so if your pension is noncontributory your Massachusetts state tax may be understated.")
        #expect(PlanClassificationChoice.districtOfColumbiaSurvivorToggleCaption ==
            "The District of Columbia excludes a DC or federal government survivor annuity from tax once the survivor is 62 or older, but taxes an annuitant's own pension in full. Turn this on only for a pension paid to you as someone else's survivor or beneficiary.")
    }
}
```

**Before writing these literals, extract each from the parent commit rather than retyping it:**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure show HEAD:RetireSmartIRA/IncomeSourcesView.swift | sed -n '1520,1570p'
```

- [ ] **Step 2: Run it and confirm it fails to compile**

```bash
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh StateAccuracyContentTests
```
Expected: build failure, "type 'PlanClassificationChoice' has no member 'hawaiiEmployerFundedCaption'".

- [ ] **Step 3: Hoist the three literals**

In `IncomeSourcesView.swift`, beside the three existing caption statics, add the three new ones with the exact strings, then replace each inline literal at `:1528`, `:1534` and `:1560` with a reference to its static. Change no wording.

- [ ] **Step 4: Run the test and the presentation suite**

```bash
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh StateAccuracyContentTests Phase3bPresentationTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure add RetireSmartIRA/IncomeSourcesView.swift RetireSmartIRATests/StateAccuracyContentTests.swift
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure commit -m "refactor(disclosure): hoist three inline captions so they can be asserted"
```

---

