# Per-State Accuracy Disclosure Implementation Plan

> **COPY STATUS, 2026-08-06: EVERY user-facing string this plan produced is APPROVED by John, as
> written.** That covers Task 4's thirteen limitation sentences, Task 6's four fallback strings,
> Task 7's three accessibility labels, the Roth conversion statement, and the multi-year delta tag.
> Where the steps below say new copy "ships flagged PROPOSED", read that as a description of how the
> work was staged, not as an open question. Nothing in this plan awaits John.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every jurisdiction a page answering "what tax treatment does this app apply for my state and tax year" and "what known limitations could affect that result", generated from the same config the engine consumes.

**Architecture:** `StateVerification.knownLimitations` becomes the single place a limitation sentence is written. The six pension-editor captions stop being hardcoded state branches and render from the resident's config. A new `StateAccuracyView` renders the factual half from `StateTaxConfig` and the limitations verbatim, reachable from three call sites that each resolve a DIFFERENT state.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing plus XCTest, bundled JSON under `RetireSmartIRA/Resources/StateTaxData/2026/`.

**Spec:** `docs/superpowers/specs/2026-08-05-per-state-accuracy-disclosure-design.md`.

**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure`, branch `feature/state-accuracy-disclosure`, cut from `feature/state-tax-phase5b` @ `587b5c4`.

## Global Constraints

- **NO EM DASH CHARACTERS** anywhere: Swift, JSON, UI copy, reports, commit messages.
- **RUN THE SUITE WITH `tools/run-tests.sh`, IN THE FOREGROUND, `timeout: 600000`.** Never `xcodebuild` directly. Never backgrounded. `MultiYearPerfTests` has a known wall-clock flake; the wrapper re-runs it in isolation and you must say so explicitly if it is your only failure.
- **ABSOLUTE PATHS and `git -C` only.** Never a bare relative path, never a chained `cd`. The controller's shell silently reset to a different worktree twice during Phase 5b.
- **Baseline to beat:** 2,035 Swift Testing in 305 suites + 509 XCTest, 0 failures.
- **NEVER edit a `knownDefect.observedToday`, a `tier`, or an `expectedStateTax`.** The frozen 1,020-value baseline in `RetireSmartIRATests/Baselines/` moves only via a MEASURED ledger entry.
- **A capped per-source `treatment` is banned phase-wide.** Do not introduce one.
- **Do not delete** `rulesAndDisclosuresStayInLockstep`, any `knownButUnpinned` entry, any deletion guard, or any caption.
- **All user-facing copy is John's to approve.** Moved sentences carry their existing approval. New sentences ship flagged PROPOSED and are batched for one review.
- **An empty `knownLimitations` NEVER renders as a clean bill of health.** Exact wording in Task 6.
- **VERIFY BEFORE YOU COMPLY.** The brief is evidence, not fact. Seventeen times in the predecessor program a subagent caught an error in its own brief. Follow the code where they disagree and say so.

---

## File Structure

| File | Responsibility |
|---|---|
| `RetireSmartIRA/StateTaxVerification.swift` | Existing. Holds `StateVerification` (`lastVerified: String`, `primarySources: [String]`, `billReferences`, `knownLimitations: [String]`, `isVerified`, `.unverified`). Gains `taxYear` in Task 2. |
| `RetireSmartIRA/StateAccuracyContent.swift` | NEW. Pure, view-free. Turns a `StateTaxConfig` into the ordered factual statements and the limitation list. Testable without SwiftUI. |
| `RetireSmartIRA/StateAccuracyView.swift` | NEW. Renders `StateAccuracyContent`. No formatting logic of its own. |
| `RetireSmartIRA/IncomeSourcesView.swift` | Modified. Six caption literals removed; captions render from config. |
| `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-*.json` | Modified. `verification.knownLimitations` populated for covered jurisdictions. |
| `RetireSmartIRATests/StateAccuracyContentTests.swift` | NEW. Gates 1 to 4. |

**Two files, not one, for the view.** `StateAccuracyContent` is where every assertion in Gate 3 points; putting the mapping inside a SwiftUI body would make effective-behaviour testing impossible, which is the mistake Phase 5b's captions made.

---

### Task 1: Hoist the three inline captions to testable statics

Three captions are already `static let` (`northCarolinaBaileyCaption:430`, `idahoRetirementBenefitsDeductionCaption:471`, `vermontRetirementExclusionCaption:517`). Three are inline literals in the view body and cannot be asserted against: DC's survivor-toggle explanation (`:1528`), Hawaii (`:1534`), Massachusetts (`:1560`). Two Phase 5b reviews flagged this. Hoist them so Task 3's byte-identity gate can exist at all.

**Files:**
- Modify: `RetireSmartIRA/IncomeSourcesView.swift`
- Test: `RetireSmartIRATests/StateAccuracyContentTests.swift` (new)

**Interfaces:**
- Produces: `IncomeSourcesView.hawaiiEmployerFundedCaption`, `.massachusettsContributoryCaption`, `.districtOfColumbiaSurvivorToggleCaption`, all `static let String`, alongside the three that already exist.

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
        #expect(IncomeSourcesView.hawaiiEmployerFundedCaption ==
            "Hawaii excludes the employer-funded portion of a pension from state tax. This app does not model the split between employer-funded and employee-contributed amounts, so your Hawaii state tax may be overstated.")
        #expect(IncomeSourcesView.massachusettsContributoryCaption ==
            "Massachusetts excludes a contributory state or local pension but taxes a noncontributory one. This app does not model that distinction, so if your pension is noncontributory your Massachusetts state tax may be understated.")
        #expect(IncomeSourcesView.districtOfColumbiaSurvivorToggleCaption ==
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
    /// The set is exactly phase5CorrectedJurisdictions UNION the knownButUnpinned
    /// states UNION the six caption states. NOT "every member has a pinned defect":
    /// GA, IA and IN were Phase 5 corrections with no pinned defect, and VT is
    /// caption-only. A test checks this derivation against the live catalogue.
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

### Task 3: Move the six captions into config and render from there

**Files:**
- Modify: `RetireSmartIRA/IncomeSourcesView.swift`
- Modify: `statetax-2026-{HI,MA,NC,ID,VT,DC}.json`
- Test: `RetireSmartIRATests/StateAccuracyContentTests.swift`

**Interfaces:**
- Consumes: the six caption statics from Task 1.
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

### Task 4: Author the remaining limitation sentences

Turn the eleven `knownButUnpinned` entries and the remaining pinned defects into user-facing sentences for the covered jurisdictions Task 2's failure list named.

**Files:**
- Modify: the covered `statetax-2026-*.json` files
- Test: `RetireSmartIRATests/StateAccuracyContentTests.swift`

- [ ] **Step 1: Read every source entry**

```bash
grep -n "UnpinnedDefect(" -A 20 /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift
```

Each carries `state`, `summary` (the mechanism) and `blockedOn`. **Translate, do not research.** Every sentence must be derivable from the entry it came from.

- [ ] **Step 2: Write one sentence per finding**

Plain language, naming the mechanism and the direction. The approved Kansas model:

> Kansas exempts a KPERS, federal government, military or Railroad Retirement pension from state tax with no dollar cap, but this figure taxes your pension in full until it is classified.

Direction matters and must be stated: "may be overstated" or "may be understated". Under-taxation cases (Massachusetts noncontributory, DC pre-existing rows) say so.

- [ ] **Step 3: Populate `taxYear`, `lastVerified` and `primarySources` for each covered state**

Sources come from that state's golden fixture `sourceURL` fields, which a Phase 4 reviewer independently opened. Do not invent URLs.

- [ ] **Step 4: Run, expecting green**

```bash
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh StateAccuracyContentTests
```
Expected: PASS. Task 2's deliberate RED is now green.

- [ ] **Step 5: Commit, flagging the copy as PROPOSED**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure add -A
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure commit -m "feat(disclosure): limitation sentences for covered jurisdictions, PROPOSED copy"
```

**List every new sentence in the task report under a heading John can review in one pass.** Do not batch them into prose.

---

### Task 5: `StateAccuracyContent` renders the factual half

**Files:**
- Modify: `RetireSmartIRA/StateAccuracyContent.swift`
- Test: `RetireSmartIRATests/StateAccuracyContentTests.swift`

**Interfaces:**
- Produces: `StateAccuracyContent.Statement` (`label: String`, `value: String`) and `factualStatements(for:filingStatus:) -> [Statement]`, consumed by Tasks 6 and 7.

- [ ] **Step 1: Write the failing test, asserting Kansas's real configured values**

```swift
    @Test("The factual half states Kansas's configured deduction and exemption")
    func kansasFactualStatementsMatchItsConfig() {
        let s = StateAccuracyContent.factualStatements(for: .kansas, filingStatus: .single)
        let byLabel = Dictionary(uniqueKeysWithValues: s.map { ($0.label, $0.value) })
        #expect(byLabel["Standard deduction"] == "$3,605")
        #expect(byLabel["Personal exemption"] == "$9,160")
        #expect(byLabel["Social Security"] != nil)
        #expect(byLabel["Pension exemption"] != nil)
    }
```

- [ ] **Step 2: Run and confirm it fails**

Expected: FAIL, "has no member 'factualStatements'".

- [ ] **Step 3: Implement**

Read `StateTaxData.config(for:)` and emit statements in a fixed order: brackets, standard deduction, personal exemption, Social Security treatment, pension exemption, IRA exemption, per-source rules, local tax. Omit a statement whose config value is absent rather than printing "none".

- [ ] **Step 4: Run**
- [ ] **Step 5: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure commit -am "feat(disclosure): the factual half, generated from live config"
```

---

### Task 6: `StateAccuracyView` and the empty state

**Files:**
- Create: `RetireSmartIRA/StateAccuracyView.swift`
- Test: `RetireSmartIRATests/StateAccuracyContentTests.swift`

- [ ] **Step 1: Write the failing test for the empty-state wording**

```swift
    /// The single most important assertion in this feature. An empty array
    /// records what has not been FOUND, never what does not EXIST. Phase 4
    /// found states believed correct on retirement exclusions that were wrong
    /// on brackets and deductions.
    @Test("An empty limitations list never reads as a clean bill of health")
    func emptyLimitationsDoesNotClaimCompleteness() {
        let text = StateAccuracyContent.limitationsSummary(for: .pennsylvania)
        #expect(text == "No known limitations are currently recorded for this state and tax year.")
        #expect(!text.lowercased().contains("no limitations"))
        #expect(!text.lowercased().contains("fully modeled"))
    }
```

- [ ] **Step 2: Run and confirm it fails**
- [ ] **Step 3: Implement `limitationsSummary(for:)`** returning that exact sentence when the list is empty, and the sentences joined otherwise.
- [ ] **Step 4: Build `StateAccuracyView`**, header showing state, tax year, last verified date and `primarySources` as links; then the factual statements; then the limitations. No formatting logic in the view.
- [ ] **Step 5: Run**
- [ ] **Step 6: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure commit -am "feat(disclosure): the per-state page, and an empty state that claims nothing"
```

---

### Task 7: Three entry points, three different states

The failure this task exists to prevent: a comparison sheet for Oregon showing California's disclosure because California is where the user lives.

**Files:**
- Modify: `RetireSmartIRA/StateComparisonView.swift` (sheet at `:585`, presented at `:66`)
- Modify: the single-year results view and `MultiYearPlanView`
- Test: `RetireSmartIRATests/StateAccuracyContentTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
    @Test("Each entry point resolves its own state, not the resident's")
    func entryPointsResolveTheCorrectState() {
        #expect(StateAccuracyContent.stateForComparisonSheet(inspecting: .oregon,
                                                             resident: .california) == .oregon)
        #expect(StateAccuracyContent.stateForSingleYearResults(resident: .california) == .california)
        #expect(StateAccuracyContent.stateForMultiYear(scenarioState: .newYork,
                                                       resident: .california) == .newYork)
    }
```

- [ ] **Step 2: Run and confirm it fails**
- [ ] **Step 3: Implement the three resolvers** as one-line functions, then wire each call site to its own resolver.
- [ ] **Step 4: Run**
- [ ] **Step 5: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure commit -am "feat(disclosure): three entry points, each resolving its own state"
```

---

### Task 8: Gates 1 and 3, and close the branch

**Files:**
- Modify: `RetireSmartIRATests/StateAccuracyContentTests.swift`

- [ ] **Step 1: Write Gate 3, effective behaviour, not a config echo**

```swift
    /// NOT an echo test. If the page says a per-spouse exclusion, the ENGINE
    /// must apply double when both spouses qualify. Reading the amount and the
    /// boolean back out of config would pass while the engine was wrong, and
    /// Phase 5b shipped several engine faults a config echo would have missed.
    @Test("A per-spouse statement is backed by the engine actually doubling it")
    func perSpouseStatementsMatchEngineBehaviour() {
        for state in StateAccuracyContent.coveredJurisdictions {
            let config = StateTaxData.config(for: state)
            guard config.retirementExemptions.exemptionAppliesPerIndividual else { continue }
            let single = TaxCalculationEngine.calculateStateTax(/* one qualifying spouse */)
            let both = TaxCalculationEngine.calculateStateTax(/* two qualifying spouses */)
            #expect(both < single, "\(state.abbreviation) claims a per-spouse exclusion the engine does not double")
        }
    }
```

Fill the two call sites from `GoldenScenarioSingleYearTests.singleYearStateTax`'s existing construction rather than inventing one.

- [ ] **Step 2: Write Gate 1, bidirectional**

Every covered jurisdiction with a pinned `knownDefect` carries at least one limitation; every limitation traces to a pinned defect or a `knownButUnpinned` entry; no orphan disclosure survives a correction. Model on `Phase5bUnclassifiedPensionDisclosureTests.rulesAndDisclosuresStayInLockstep`.

- [ ] **Step 3: Run the FULL suite**

```bash
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh
```
Expected: 0 failures, above the 2,035 + 509 baseline.

- [ ] **Step 4: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure commit -am "test(disclosure): behaviour-backed fidelity and bidirectional completeness"
```

---

## Self-review against the spec

**Covered:** core promise (Tasks 5, 6), both halves (5, 6), state-and-tax-year header (2, 6), three entry points with per-destination resolution (7), required verification block described accurately as a decode-and-test gate (2), consolidation to two sources (3), `unclassifiedPensionDisclosure` deliberately untouched (3), content scope (4), all four gates (1 in Task 8, 2 in Task 3, 3 in Task 8, 4 in Task 2), empty state as exact wording (6).

**Deliberately deferred, and flagged rather than silently dropped:** the spec's Gate 4 says "loading every jurisdiction." **This plan enforces it for the 15 covered jurisdictions only**, because 50 of 51 configs have an empty `lastVerified` and sourcing the other 36 states' primary references is a separate body of work. Task 2 is written so widening is a one-line change. **This is the one scope decision in the plan that needs John's agreement before Task 2 ships.**

**Naming consistency checked:** `coveredJurisdictions`, `limitations(for:)`, `limitationsSummary(for:)`, `factualStatements(for:filingStatus:)`, `Statement`, and the three resolvers are used identically wherever they appear.
