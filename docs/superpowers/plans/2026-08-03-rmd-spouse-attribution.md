# RMD Spouse Attribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the RMD Calculator tell a two-person household whose RMDs are whose, and stop it saying RMDs have not started when one spouse's already have.

**Architecture:** No engine change. Every defect here is attribution in the presentation layer: the math already counts both people and the display credits only the primary. `spouseYearsUntilRMD`, `spouseIsRMDRequired`, `spouseRmdAge` and `calculateSpouseRMD()` all exist already and are simply not read by this screen.

**Promised in writing to Steve Nicolai on 2026-08-03**, in the reply to his twelve items: "the summary will lead with whichever of you starts sooner and show both, and the chart will separate the two." Treat that wording as the acceptance criteria.

**Worktree:** `.worktrees/rmd-spouse-attribution`, branch `fix/rmd-spouse-attribution`, off `main` @ `16fd6a2`.

---

## Global Constraints

- **No computed tax value may change.** This is a display and attribution fix. `calculateCombinedRMD()` (`DataManager.swift:490`) is already `calculatePrimaryRMD() + calculateSpouseRMD()`, and `scenarioTotalWithdrawals` (`:1662`) already uses it, so both spouses' RMDs are already in the tax math. If a tax figure moves, you have changed something you should not have.
- **The Phase 3a frozen baseline** (`RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift`, 51 jurisdictions x 20 scenarios = 1,020 values) must stay byte-identical and must NOT be regenerated. It is the tripwire for the point above.
- **Never edit `RetireSmartIRA.xcodeproj/project.pbxproj`.** Both source roots are `PBXFileSystemSynchronizedRootGroup`, so new files are bundled automatically. If you think you need to, stop and report BLOCKED.
- **No em dash characters** anywhere in code, comments, tests or commit messages. Verify with a command and paste the raw output; two reports in the preceding program asserted zero when there were four.
- **A disclosure or a label that always shows is not conditional, it is decoration.** Every test that asserts something appears must have a sibling asserting it does NOT appear when it should not. This is the rule that caught real defects in the previous phase.
- **Bash cwd resets to `/Users/johnurban/Projects/RetireSmartIRA` between calls** and chaining `cd X && a && b` does NOT protect the next separate call. Use absolute paths and `git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/rmd-spouse-attribution` for git. Before trusting any suite count, grep the log for the `.xcodeproj` path.
- **Stage explicit paths.** Never `git add -A`.

## Efficiency protocol

1. **Full suite once, at the end of your task.** Targeted `-only-testing` runs finish in under a second; the full suite takes about five minutes.
2. **Never background an xcodebuild run.** Eight agents in the preceding program did and returned before it finished, costing a round trip each.
3. **Measure before writing tests.** Mutate first, then write only what survived.

## Baseline

`main` @ `16fd6a2` was verified green when Phase 3b merged: **1,755 Swift Testing in 285 suites + 505 XCTest**, iOS build clean. This branch adds only doc files so far, so do not re-run a five-minute suite to confirm what was confirmed an hour ago. Task 1's own run is the first real measurement.

---

## The three defects, verified in code

All three are the same shape. The math counts both people; the display credits one.

**1. The status card is primary-only, and for Steve's household its headline is wrong, not merely partial.**

`RMDCalculatorView.swift` lines 105 to 190. Three separate elements all read primary-only values:

| Element | Reads | Should consider |
|---|---|---|
| Status badge ("Not Yet Required") | `dataManager.isRMDRequired` | `spouseIsRMDRequired` too |
| "RMD Age" large number | `dataManager.rmdAge` | both, when they differ |
| "RMDs start in N years" (`:184`) | `dataManager.yearsUntilRMD` | whoever starts sooner |

Steve's wife is nine years older and reaches RMD age first. The card can therefore say "Not Yet Required" and "RMDs start in 9 years" while her RMDs are already due this year. That is an actively false statement, not an incomplete one.

**2. The chart sums both people into one series.** `RMDCalculatorView.swift:778` declares `var regularRMD: Double = 0`, adds the primary's RMD, then adds the spouse's into the same accumulator. One series, labelled "IRA / 401(k)". Correct total, invisible attribution.

**3. Tax Summary attribution is UNVERIFIED and must be established before it is changed.** Steve reports spouse RMDs are absent there. The math includes them, so if anything is wrong it is presentational. Task 3 establishes what is actually true before touching anything.

**Precedent worth reusing:** the Retirement Drawdown chart on this same screen already plots "RMDs begin" and "Spouse RMDs" as separate markers, so both dates are already computed and the visual language already exists.

---

## File Structure

**Created:**
| File | Responsibility |
|---|---|
| `RetireSmartIRA/RMDHouseholdStatus.swift` | Pure value type deciding who starts first, whether anyone is required, and what the card should say. Testable without a view. |
| `RetireSmartIRATests/RMDHouseholdStatusTests.swift` | The decision table for that type. |
| `RetireSmartIRATests/RMDChartSeriesTests.swift` | Per-owner chart series. |

**Modified:** `RMDCalculatorView.swift`, and in Task 3 whichever Tax Summary surface the audit implicates.

**Why a separate type rather than inline view logic.** The preceding phase learned this the hard way: a fix living inside a private method on a private SwiftUI view had no regression test and could be silently reverted by a refactor. Hoisting the decision into a pure type makes both branches testable, which is the difference between fixing this once and fixing it again later.

---

### Task 1: The household status decision, as a testable type

**Files:** create `RetireSmartIRA/RMDHouseholdStatus.swift` and `RetireSmartIRATests/RMDHouseholdStatusTests.swift`.

**Interfaces produced:**

```swift
struct RMDHouseholdStatus: Equatable {
    enum Who: Equatable { case primary, spouse }
    /// True when EITHER person is at or past their RMD age.
    let anyoneRequired: Bool
    /// Whichever person reaches RMD age sooner. Ties resolve to `.primary`.
    let startsFirst: Who
    /// Years until the FIRST of the two starts. Zero once anyone is required.
    let yearsUntilFirst: Int
    /// The RMD age of whoever starts first.
    let firstRmdAge: Int
    /// True when the two people have different RMD ages or different timing,
    /// which is when the card must show both rather than one.
    let showsBothPeople: Bool

    static func resolve(
        primaryAge: Int, primaryRmdAge: Int,
        spouseEnabled: Bool, spouseAge: Int, spouseRmdAge: Int
    ) -> RMDHouseholdStatus
}
```

Note that RMD age is NOT a constant: `ProfileManager.swift:101-109` returns 72 before 1951, 73 for 1951 to 1959, and **75 for 1960 or later**. A couple can legitimately have different RMD ages, so the type must take both rather than assume one.

- [ ] **Step 1: Write the failing tests.** Cover the decision table exhaustively, and include the two rows that carry Steve's case and its inverse:

```swift
@Suite("RMD household status")
struct RMDHouseholdStatusTests {

    @Test("A spouse who is already required makes the household required, even when the primary is not")
    func olderSpouseDrivesTheHeadline() {
        // Steve's household: wife nine years older, already past her RMD age.
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 73, spouseRmdAge: 73)
        #expect(s.anyoneRequired)
        #expect(s.startsFirst == .spouse)
        #expect(s.yearsUntilFirst == 0)
        #expect(s.showsBothPeople)
    }

    @Test("The primary can be the one who starts first")
    func olderPrimaryDrivesTheHeadline() {
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 73, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 64, spouseRmdAge: 73)
        #expect(s.anyoneRequired)
        #expect(s.startsFirst == .primary)
        #expect(s.showsBothPeople)
    }

    @Test("Neither required yet: the countdown is to whoever starts sooner")
    func countdownUsesWhoeverStartsSooner() {
        // Spouse is closer to her RMD age, so the countdown is hers, not his.
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 60, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 70, spouseRmdAge: 73)
        #expect(!s.anyoneRequired)
        #expect(s.startsFirst == .spouse)
        #expect(s.yearsUntilFirst == 3)
        #expect(s.firstRmdAge == 73)
    }

    @Test("Different RMD ages are respected, not assumed equal")
    func differentRmdAgesAreRespected() {
        // Born 1959 versus born 1960: 73 against 75, a real SECURE 2.0 boundary.
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 67, primaryRmdAge: 75,
            spouseEnabled: true, spouseAge: 67, spouseRmdAge: 73)
        #expect(s.startsFirst == .spouse)
        #expect(s.firstRmdAge == 73)
        #expect(s.showsBothPeople)
    }

    @Test("No spouse: everything resolves to the primary and nothing shows both")
    func singleFilerShowsOnePerson() {
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 64, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 99, spouseRmdAge: 73)
        #expect(!s.anyoneRequired)
        #expect(s.startsFirst == .primary)
        #expect(s.yearsUntilFirst == 9)
        #expect(!s.showsBothPeople)
    }

    @Test("A disabled spouse's ages are ignored entirely")
    func disabledSpouseCannotLeakIn() {
        // spouseAge 99 would dominate every field if the guard were missing.
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 60, primaryRmdAge: 73,
            spouseEnabled: false, spouseAge: 99, spouseRmdAge: 73)
        #expect(!s.anyoneRequired)
        #expect(s.yearsUntilFirst == 13)
    }

    @Test("Identical ages tie-break to the primary and do not claim to show both")
    func identicalHouseholdsResolveToPrimary() {
        let s = RMDHouseholdStatus.resolve(
            primaryAge: 70, primaryRmdAge: 73,
            spouseEnabled: true, spouseAge: 70, spouseRmdAge: 73)
        #expect(s.startsFirst == .primary)
        #expect(!s.showsBothPeople)
    }
}
```

- [ ] **Step 2: Run and watch it fail to compile.** Paste the transcript verbatim.

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/rmd-spouse-attribution && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/RMDHouseholdStatusTests 2>&1 | tail -20
```

- [ ] **Step 3: Implement the type.** Pure, no `DataManager` dependency, no view code. `spouseEnabled == false` must short-circuit before any spouse value is read.

- [ ] **Step 4: Run, confirm green, commit.**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/rmd-spouse-attribution && git add RetireSmartIRA/RMDHouseholdStatus.swift RetireSmartIRATests/RMDHouseholdStatusTests.swift && git commit -m "feat(rmd): household RMD status as a testable decision"
```

---

### Task 2: The status card reads the household, not the primary

**Files:** modify `RetireSmartIRA/RMDCalculatorView.swift` (the card at lines 105 to 190).

- [ ] **Step 1: Wire the card to `RMDHouseholdStatus.resolve(...)`.** Feed it `dataManager.currentAge`, `rmdAge`, `enableSpouse`, `spouseCurrentAge`, `spouseRmdAge`.

Three changes, matching what Steve was promised:

1. **The status badge** uses `anyoneRequired` rather than `isRMDRequired`, so an older spouse who is already required makes the household read as required.
2. **The countdown at `:184`** reads `yearsUntilFirst` and names the person when `showsBothPeople` is true. Wording along the lines of "Your spouse's RMDs start in 3 years (age 73)" versus today's unattributed "RMDs start in 9 years". Use `dataManager.spouseName` when it is non-empty, matching the existing pattern at `:355`.
3. **When `showsBothPeople` is true, show BOTH lines**, ordered with whoever starts sooner first. That is the literal promise: "lead with whichever of you starts sooner and show both."

Leave the inherited-IRA branch at `:176` alone except to keep it consistent; it is a different rule.

- [ ] **Step 2: View tests** asserting the card's strings for the same decision table Task 1 covers, including the absence case: a single filer must NOT get a spouse line. Follow the patterns in the existing view tests rather than inventing a new harness.

- [ ] **Step 3: Prove it discriminates.** Revert the badge to `dataManager.isRMDRequired` and confirm the Steve-shaped test fails. Restore, verify with `git diff`.

- [ ] **Step 4: Targeted run, then the frozen baseline to prove no tax moved, then commit.**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/rmd-spouse-attribution && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/RMDHouseholdStatusTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests 2>&1 | tail -15
```

---

### Task 3: Establish the Tax Summary truth BEFORE changing anything

Steve reports spouse RMDs are absent from Tax Summary. **The math includes them:** `calculateCombinedRMD()` (`DataManager.swift:490`) is `calculatePrimaryRMD() + calculateSpouseRMD()`, and `scenarioTotalWithdrawals` (`:1662`) uses it. So either the display omits the attribution, or he inferred absence from the primary-only RMD Calculator headline, or there is a third thing.

**Do not fix anything until you know which.** Report first.

- [ ] **Step 1: Audit and report.** Establish, with file and line references:
  - Where Tax Summary surfaces retirement distributions at all.
  - Whether the figure shown includes `calculateSpouseRMD()`. Prove it with a test that builds a household with a spouse-only RMD and asserts the Tax Summary figure is nonzero.
  - Whether anything attributes the amount per person.

- [ ] **Step 2: Report the finding and STOP if it is a real omission of a different shape.** If the number is correct and only the attribution is missing, continue to Step 3. If the number is wrong, that is a tax defect rather than a display one and it needs its own plan; say so and stop.

- [ ] **Step 3: If, and only if, it is attribution:** show the split where the total is shown, in the same visual language the Drawdown chart already uses for "RMDs begin" and "Spouse RMDs". Add a test with the absence case: a single filer must not get a spouse row.

- [ ] **Step 4: Targeted run, baseline, commit.**

---

### Task 4: The chart separates the two people

**Files:** modify `RetireSmartIRA/RMDCalculatorView.swift` (`rmdChartData`, from line 753); create `RetireSmartIRATests/RMDChartSeriesTests.swift`.

`:778` declares one `var regularRMD: Double = 0` and adds both people into it. The per-person math already runs inside that loop; it only needs to emit two points rather than sum them.

- [ ] **Step 1: Write the failing test.** A household with a spouse-only RMD must produce a spouse series with a nonzero value and a primary series at zero for that year, and the two series must sum to today's single-series total for every year in the projection. That second assertion is what proves the split did not change any number.

- [ ] **Step 2: Run, watch it fail, paste.**

- [ ] **Step 3: Emit two series.** Give `RMDChartDataPoint` an owner dimension and stop summing. Keep the inherited-IRA projection as its own thing; it is already separate and is not part of this fix.

- [ ] **Step 4: Update the chart to plot two series**, with a legend that names the spouse when `dataManager.spouseName` is non-empty. Match the existing token and colour usage rather than introducing new ones.

- [ ] **Step 5: Prove it discriminates.** Sum the two series back into one and confirm the per-owner test fails. Restore.

- [ ] **Step 6: Full suite ONCE, then commit.** Paste both summary lines and the tree-confirmation grep.

---

### Task 5: The gate

- [ ] **Step 1: Full macOS suite**, foreground, tree confirmed, both summary lines pasted. Expect the Phase 3b baseline of 1,755 Swift Testing plus 505 XCTest, plus this branch's additions, with nothing removed.
- [ ] **Step 2: iOS build** clean.
- [ ] **Step 3: Confirm nothing moved that should not.** The frozen baseline byte-identical and NOT regenerated; `GoldenScenarioCrossPathTests` still pinning single-year 42.0 and multi-year 200.40469973890345; no `project.pbxproj` change; no em dash in any added line.
- [ ] **Step 4: IN-APP VERIFICATION.** Build to the iOS Simulator and drive it, because no mechanical gate covers a label. Set up Steve's household: primary 64, spouse 73, spouse holding a traditional balance, and check that:
  - the card does NOT say "Not Yet Required",
  - the countdown names the spouse and reads zero years,
  - the chart shows two distinguishable series,
  - a single filer sees none of the spouse wording anywhere.

  Note for whoever drives it: `type` triggers iOS press-and-hold accent popups in the Simulator, so use `xcrun simctl pbcopy <udid>` and paste with `cmd+v` for text entry. Scroll wheel does not register; use a click-drag to swipe.
- [ ] **Step 5: Whole-branch review** via superpowers:requesting-code-review. Point it specifically at whether any test asserts a presence without a matching absence, and at whether the two chart series still sum to the previous total.

---

## Self-Review

**Scope coverage.** Steve's promised wording, "the summary will lead with whichever of you starts sooner and show both, and the chart will separate the two", is Tasks 2 and 4. His third sub-point, Tax Summary, is Task 3, deliberately framed as an audit first because it is the one item never verified.

**The risk this plan is built around.** Everything here is presentational, and presentational fixes have no mechanical gate. That is why the decision logic is hoisted into a pure type in Task 1 rather than left inline in the view, why every presence test needs an absence sibling, and why Task 5 Step 4 requires driving the real app. The preceding phase shipped a defect that 1,752 tests missed because none of them exercised the property a user actually reads.

**What is deliberately NOT here.** No engine change, no change to `calculateCombinedRMD`, no change to any tax figure. If a task finds itself editing tax math, it has misread the problem: the arithmetic already counts both people.

**Known soft spot.** Task 3 may turn up a fourth thing rather than the attribution gap assumed here. The plan handles that by requiring a report before a fix, and by saying explicitly that a wrong number is a different defect needing its own plan.
