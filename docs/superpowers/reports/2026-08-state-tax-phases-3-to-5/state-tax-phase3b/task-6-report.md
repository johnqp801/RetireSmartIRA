# Task 6 report: the picker, and the disclosures

Status: DONE
HEAD before this task: `dc0cb7f`

## Summary

Tasks 1 through 5 built a correct engine (New York's Line 26 government-pension exclusion,
component-based, cross-path consistent) that no view exposed. This task is the four deliverables
that let a real user reach it: the classification picker, a classified 403(b)/457 displaying as
itself, the unclassified-New-York prompt plus its limitation wherever New York tax is computed,
and Hawaii's contextual disclosure plus the account-classification/Multi-Year disclosure.

No engine file was touched (`TaxCalculationEngine.swift`, `ProjectionEngine.swift`, all JSON under
`Resources/StateTaxData/` are untouched). `TaxCalculationEngine.applyRetirementExemptions` already
reads `IncomeSource.planStructure`/`.planSource` directly off every `.pension`/`.rmd` row (Task 4),
so once the picker writes those two fields the single-year engine picks the classification up with
no DataManager wiring required. The only production files this task needed to touch were the four
named in the brief plus one unavoidable call site (`MultiYearPlanView.swift`, the sole place
`CPABriefingModel` is constructed) to append the two new conditional strings the design doc's
section 3.7 asks the CPA briefing to carry.

## Step 1: RED transcript (verbatim excerpt)

`RetireSmartIRATests/Phase3bPresentationTests.swift` (33 tests) was written first, referencing
`PlanClassificationChoice`, `StateComparisonPresentation`, and two new
`MultiYearCPABriefing` functions that did not exist yet anywhere in the codebase. Ran
`-only-testing:RetireSmartIRATests/Phase3bPresentationTests`:

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bPresentationTests.swift:23:24: error: cannot find type 'PlanClassificationChoice' in scope
        let expected: [PlanClassificationChoice] = [
                       ^~~~~~~~~~~~~~~~~~~~~~~~
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bPresentationTests.swift:28:17: error: cannot find 'PlanClassificationChoice' in scope
        #expect(PlanClassificationChoice.allCases == expected)
                ^~~~~~~~~~~~~~~~~~~~~~~~
        ... (22 total "Cannot find 'PlanClassificationChoice' in scope" errors across the picker,
        reverse-lookup, display-name and prompt tests)
	Cannot infer contextual base in reference to member 'nyStateOrLocal'
	Cannot infer contextual base in reference to member 'federalCivilian'
	Cannot infer contextual base in reference to member 'traditionalIRA'
	Cannot infer contextual base in reference to member 'traditional401k'
	Cannot infer contextual base in reference to member 'definedContribution'
	Cannot infer contextual base in reference to member 'governmentUnspecified'
	Cannot infer contextual base in reference to member 'newYork'
	Cannot infer contextual base in reference to member 'california'
	Cannot find 'StateComparisonPresentation' in scope   (x4)
	Type 'MultiYearCPABriefing' has no member 'newYorkUnclassifiedPensionLimitation'   (x4)
	Type 'MultiYearCPABriefing' has no member 'hawaiiPensionSplitLimitation'   (x4)
	Testing cancelled because the build failed.

** TEST FAILED **

The following build commands failed:
	SwiftCompile normal arm64 /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bPresentationTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	SwiftCompile normal arm64 Compiling Phase3bPresentationTests.swift /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/Phase3bPresentationTests.swift (in target 'RetireSmartIRATests' from project 'RetireSmartIRA')
	Testing project RetireSmartIRA with scheme RetireSmartIRA
(3 failures)
```

After implementing `PlanClassificationChoice` (`RetireSmartIRA/IncomeSourcesView.swift`),
`StateComparisonPresentation` (`RetireSmartIRA/StateComparisonView.swift`), and the two
`MultiYearCPABriefing` functions (`RetireSmartIRA/MultiYearCPABriefing.swift`), then wiring the
three consuming views and `MultiYearPlanView.swift`'s call site:

```
✔ Test run with 33 tests in 1 suite passed after 0.026 seconds.
```

## The four deliverables

### 1. The picker

`RetireSmartIRA/IncomeSourcesView.swift:16` -- `enum PlanClassificationChoice`, the flat list
of nine rows, exact labels and `(structure, source)` mappings per spec section 3.2, in
declaration order. `PlanClassificationChoice.showsPickerFor(accountType:)` (line 96) gates it to
non-Roth, non-inherited accounts.

- Pension usage: `IncomeSourcesView.swift:1090`, `Section("What kind of pension is this?")` inside
  `AddIncomeView`, shown only `if incomeType == .pension`.
- Account usage: `AccountsView.swift:306`, `Section("What kind of retirement account is this?")`
  inside `AddAccountView`, shown only `if PlanClassificationChoice.showsPickerFor(accountType:
  accountType)`.
- Proving test: `Phase3bPresentationTests.pickerRowsExactlyMatchSpec`,
  `pickerLabelsMatchSpec`, `pickerClassificationsMatchSpec`,
  `outOfStateRowDoesNotMapToNewYork`, `rothAndInheritedAccountsGetNoPicker`, plus
  `addIncomeViewBuildsForPension` / `addAccountViewBuildsForTraditionalAccount` (construction
  smoke tests for the actual SwiftUI sections).

### 2. A classified 403(b)/457 displays as itself

`IncomeSourcesView.swift:115` -- `PlanClassificationChoice.accountDisplayName(accountType:
planStructure:planSource:)`. It returns `"403(b) or 457 (Government Employer)"` for
`(definedContribution, governmentUnspecified)`, the one tuple no `AccountType`'s default inference
ever produces, and falls back to `accountType.rawValue` otherwise.

- Accounts list: `AccountsView.swift:158` -- `AccountRow` now calls
  `accountDisplayName(...)` instead of `account.accountType.rawValue`. This is the exact line
  named in the brief that used to print "Traditional 401(k)" over a classified 403(b).
- Account detail/edit view: `AccountsView.swift:302-320` -- `AddAccountView`'s new "What kind
  of retirement account is this?" section shows a `"Classified as: <name>"` badge whenever the
  resolved display name differs from `accountType.rawValue`.
- `MultiYearCPABriefing.swift`: audited and found to contain **no** per-account or
  accountType-labeled table anywhere in the document (its year-by-year table shows aggregated
  `End Trad`/`End Roth`/`End Txbl` totals across every account of a kind, never one account's
  type). There is no "Traditional 401(k)" mislabel there to fix, so this file is unchanged for
  deliverable 2, confirmed by `grep -n accountType RetireSmartIRA/MultiYearCPABriefing.swift`
  returning nothing before or after this task.
- Two other production call sites DO have the identical bug and were confirmed out of this task's
  four-file scope: `RetireSmartIRA/PDFExportService.swift:1326` (the single-year Tax Summary PDF
  export) and `RetireSmartIRA/RMDCalculatorView.swift:687` (the RMD calculator's account list).
  Flagged as a follow-up task (see below), not fixed here.
- Proving tests: `governmentSalaryReductionAccountDisplaysAsItself`,
  `unclassified401kStillDisplaysAsTraditional401k`, `explicitEmployer401kDisplaysAsTraditional401k`,
  `traditionalIRADisplayUntouched`, `accountRowBuildsForClassifiedAccount`.

**Known, documented limitation (not a bug):** "Employer 401(k)" and "403(b) or 457, private or
nonprofit employer" write the identical `(definedContribution, privateEmployer)` tuple per spec
section 3.2, and that tuple is also every plain 401(k)'s untouched default. A privately-employed
403(b)/457 therefore still displays as "Traditional 401(k)" after classification; only the
government-employer row is unambiguous. This is documented in
`accountDisplayName`'s doc comment and pinned by `explicitEmployer401kDisplaysAsTraditional401k`.
Steve Nicolai's wife worked for the state, so her accounts use the government row and display
correctly.

### 3. The unclassified New York prompt and its limitation

Prompt: `IncomeSourcesView.swift:129` -- `PlanClassificationChoice.shouldPromptForClassification`.
Rendered at `IncomeSourcesView.swift:778-790` in `IncomeRow`, a prominent amber banner reading "Is
this a government pension? Tap to answer. It could change your state tax." Shown only when
`source.type == .pension && source.planSource == .unknown && residenceHasPerSourceRules`.
`residenceHasPerSourceRules` (line 138) reads `StateTaxData.config(for:).retirementExemptions.perSourceExemptions.isEmpty`
live, so it is New-York-only today without hardcoding "New York."

Limitation wherever New York tax is computed:
- `StateComparisonView.swift:20` -- `enum StateComparisonPresentation`,
  `showsUnclassifiedNewYorkPensionLimitation(viewedState:hasUnclassifiedPension:)`. Gates on
  `viewedState == .newYork`, not on residence, so it fires identically whether the viewer resides
  in New York and taps their own detail sheet, or resides elsewhere and taps New York's row while
  comparing. Rendered at `StateComparisonView.swift:582-596`
  (`StateTaxDetailSheet.newYorkPensionLimitationBanner`), placed directly under the state header,
  above every other section.
- `MultiYearCPABriefing.swift:357` -- `newYorkUnclassifiedPensionLimitation(residesInNewYork:
  hasUnclassifiedPension:)`, wired into the `limitations:` array at the sole `CPABriefingModel`
  call site, `MultiYearPlanView.swift:356-368`.
- Proving tests: `unclassifiedPensionInNewYorkShouldPrompt`, `classifiedPensionShouldNotPrompt`,
  `unclassifiedPensionOutsideNewYorkShouldNotPrompt`, `unclassifiedRMDShouldNotPrompt`,
  `residenceHasPerSourceRulesReflectsLiveConfig`,
  `stateComparisonShowsLimitationForUnclassifiedNewYorkPension`,
  `stateComparisonOmitsLimitationOnceClassified`, `stateComparisonOmitsLimitationForOtherStates`,
  `cpaBriefingCarriesNewYorkLimitationWhenApplicable`,
  `cpaBriefingOmitsNewYorkLimitationOutsideNewYork`,
  `cpaBriefingOmitsNewYorkLimitationOnceClassified`,
  `cpaBriefingHTMLContainsNewYorkLimitation`, `incomeRowBuildsWithPrompt`.

### 4. Two contextual disclosures

**4a. Hawaii.** `IncomeSourcesView.swift:1098-1103` -- inside the same `.pension` picker
section, `if dataManager.selectedState == .hawaii`, a caption stating Hawaii does not model the
employer-funded vs. employee-contributed split and may overstate the tax. Also added to the CPA
briefing: `MultiYearCPABriefing.swift:368` -- `hawaiiPensionSplitLimitation(residesInHawaii:
hasPensionIncome:)`, wired the same way as the New York limitation. Gated on pension income alone
(not on classification), since the unmodeled split exists either way.
Proving tests: `hawaiiDisclosureAppearsWithPensionIncome`, `hawaiiDisclosureAbsentOutsideHawaii`,
`hawaiiDisclosureAbsentWithoutPensionIncome`, `cpaBriefingHTMLContainsHawaiiDisclosure`.

**4b. Account classification doesn't reach Multi-Year (Task 5, spec 3.4b).**
`AccountsView.swift:311` -- inside the new "What kind of retirement account is this?"
section: "This affects your single-year Tax Summary and Scenarios. It does not yet affect the
Multi-Year plan." Placed exactly where a user who has just classified an account will see it,
directly under the picker.

## Mutations proving discrimination

**Picker mapping** (`PlanClassificationChoice.otherStateGovernmentPension.classification`),
changed `source: .otherStateOrLocal` to `source: .nyStateOrLocal` (i.e. made the out-of-state row
incorrectly select New York's exclusion, the exact bug the row exists to prevent):

```
✘ Test "Each row's classification matches spec 3.2 columns 2 and 3, exactly" recorded an issue at Phase3bPresentationTests.swift:51:9: Expectation failed: (PlanClassificationChoice.otherStateGovernmentPension.classification → RetirementPlanClassification(structure: .definedBenefit, source: .nyStateOrLocal)) == (RetirementPlanClassification(structure: .definedBenefit, source: .otherStateOrLocal) → RetirementPlanClassification(structure: .definedBenefit, source: .otherStateOrLocal))
✘ Test "The out-of-state government pension row does NOT map to New York's exclusion" recorded an issue at Phase3bPresentationTests.swift:74:9: Expectation failed: (source → .nyStateOrLocal) == .otherStateOrLocal
✘ Test "The out-of-state government pension row does NOT map to New York's exclusion" recorded an issue at Phase3bPresentationTests.swift:75:9: Expectation failed: (source → .nyStateOrLocal) != .nyStateOrLocal
✘ Test "Reverse lookup round-trips every row's own classification except the shared tuple" recorded an issue at Phase3bPresentationTests.swift:100:13: Expectation failed: (PlanClassificationChoice.choice(for: choice.classification) → .nyGovernmentPension) == (choice → .otherStateGovernmentPension)
✘ Suite "Phase 3b Task 6: picker, classified-account display, NY prompt, disclosures" failed after 0.011 seconds with 4 issues.
```

Four tests failed, exactly the ones that encode this row's identity. Reverted; re-ran, all 28
tests (at that point in development) green.

**New York prompt** (`PlanClassificationChoice.shouldPromptForClassification`), dropped the
`&& residenceHasPerSourceRules` clause so an unclassified pension prompts regardless of state:

```
✘ Test "An unclassified pension in a state with no per-source rules should NOT prompt" recorded an issue at Phase3bPresentationTests.swift:168:9: Expectation failed: !(PlanClassificationChoice.shouldPromptForClassification(source: (row → IncomeSource(..., planStructure: .unknown, planSource: .unknown)), residenceHasPerSourceRules: false) → true)
✘ Suite "Phase 3b Task 6: picker, classified-account display, NY prompt, disclosures" failed after 0.019 seconds with 1 issue.
```

Reverted; re-ran, green again (28/28 at that point).

## Frozen baseline and I2 pins

```
$ xcodebuild test ... -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests -only-testing:RetireSmartIRATests/GoldenScenarioCrossPathTests
✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.043 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.043 seconds.
✔ Test "PINNED, New Jersey single-year vs multi-year: two components, I2 is the smaller one" started.
✔ Test "PINNED, New Jersey single-year vs multi-year: two components, I2 is the smaller one" passed after 0.001 seconds.
✔ Test run with 3 tests in 2 suites passed after 0.048 seconds.
```

`RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json` was not touched
(`git status --porcelain RetireSmartIRATests/Baselines/` is empty; no task 6 file writes to it).
The 1,020-value baseline stayed byte-identical because it was never regenerated, and the
`GoldenScenarioCrossPathTests` single-year `$42.00` / multi-year `200.40469973890345` pins passed
unchanged. This task cannot move any computed tax value: it adds UI and pure display/disclosure
predicates only, and touches no engine file.

## Em dash check

```
$ python3 -c "... git diff production files, count the em dash character on added lines ..."
TOTAL ADDED-LINE EM DASHES (production diff): 0
$ python3 -c "... full content of the new test file, count the em dash character ..."
TOTAL EM DASHES (new test file, full content): 0
```

## Full suite (run once, foreground)

```
$ xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
...
✔ Test run with 1738 tests in 285 suites passed after 312.431 seconds.
...
	 Executed 503 tests, with 0 failures (0 unexpected) in 20.914 (21.234) seconds
...
** TEST SUCCEEDED **
```

Growth from Task 5's suite (1705 Swift Testing tests / 284 suites, inferred) to 1738/285 is
exactly the 33 tests and 1 new suite (`Phase3bPresentationTests`) this task added. XCTest count
unchanged at 503/0 failures.

**Tree-confirmation grep:**
```
$ grep -m5 "\.xcodeproj" full-suite.log
    /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination platform=macOS
    cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj
```

## `git diff --stat`

```
 RetireSmartIRA/AccountsView.swift         |  65 ++++++++-
 RetireSmartIRA/IncomeSourcesView.swift    | 212 +++++++++++++++++++++++++++++-
 RetireSmartIRA/MultiYearCPABriefing.swift |  23 ++++
 RetireSmartIRA/MultiYearPlanView.swift    |  14 +-
 RetireSmartIRA/StateComparisonView.swift  |  60 ++++++++-
 5 files changed, 366 insertions(+), 8 deletions(-)
```

One new test file staged separately (not counted above): `RetireSmartIRATests/Phase3bPresentationTests.swift`
(33 tests). `RetireSmartIRA.xcodeproj/project.pbxproj` not touched (`git diff --stat -- RetireSmartIRA.xcodeproj/project.pbxproj`
empty). No engine file, no JSON under `Resources/StateTaxData/`, no `AccountType` case added.

`MultiYearPlanView.swift` is the one file beyond the brief's named four that needed a change: it
is the sole call site that constructs `CPABriefingModel`, so wiring the two new
`MultiYearCPABriefing` disclosure functions into `limitations:` required touching it. The change
there is two function calls appended to an array; no new logic or copy lives in that file.

## Two latent bugs fixed as a side effect

Neither `AddIncomeView.saveIncome()` nor `AddAccountView.saveAccount()` passed
`planStructure`/`planSource` to the `IncomeSource`/`IRAAccount` initializer before this task, so
re-saving an already-classified row (once one existed) would have silently reset it to the
inferred default on every edit. Both `@State private var planChoice` now initialize by reverse
lookup from the row/account's existing classification (falling back to inference only when
absent), and both save paths pass the resolved classification through explicitly, so an edit no
longer discards a prior classification. For income, this is gated to `incomeType == .pension`
only, so `.rmd` and every other income type are provably unaffected (see the `explicitStructure`/
`explicitSource` comment at `IncomeSourcesView.swift:1257`).

## Follow-up flagged, not fixed here

Spawned a background task (`task_56590910`) for `PDFExportService.swift:1326` and
`RMDCalculatorView.swift:687`, which share the "Traditional 401(k)" mislabel bug this task fixed
in `AccountsView.swift` but are outside its four-file scope.

## IN-APP VERIFICATION SCRIPT for John

No mechanical gate covers this task. Here is exactly what to open, click, and expect.

### 1. The picker on a pension (Income Sources tab)

1. Go to **Income Sources**. Tap **Add Income**.
2. Set Income Type to **Pension**. A new section, **"What kind of pension is this?"**, appears
   with a "Plan type" picker.
3. Open the picker. You should see exactly these nine rows, in this order: *Government pension,
   New York State or local* / *Government pension, federal civilian* / *Government pension,
   another state or locality* / *Private employer pension* / *403(b) or 457, government employer*
   / *403(b) or 457, private or nonprofit employer* / *Employer 401(k)* / *IRA* / *Not sure*.
4. Enter a name and amount, pick **Government pension, New York State or local**, save.
5. **If your state of residence (Settings) is New York:** go to Tax Summary / Scenarios and note
   the state tax figure, then edit this pension back to **Not sure** and save. The state tax
   figure should rise (the exclusion is gone; it falls back to the standard $20,000 pension cap).
   Re-classify it as NY State/local again and confirm the figure drops back.
6. **The case that must NOT change:** create a second pension, classify it **Government pension,
   another state or locality** (an out-of-state public pension). While your residence is New
   York, this pension must stay CAPPED at the shared $20,000 exclusion, exactly like an
   unclassified one. If it becomes fully excluded, that is the regression this task was written
   to prevent.

### 2. The unclassified-pension prompt (Income Sources list)

1. Add a pension and leave its plan type at the default **Not sure**, OR look at any pre-existing
   pension row that has never been classified.
2. **If your residence state is New York:** the row in the Income Sources list should show an
   amber banner: "Is this a government pension? Tap to answer. It could change your state tax."
3. **If your residence state is anything else (e.g. California, Texas):** that banner must NOT
   appear on the same unclassified row. This is the "absence otherwise" half of the check.
4. Classify the pension (any answer other than "Not sure") and confirm the banner disappears.

### 3. A classified 403(b)/457 displays as itself (Accounts tab)

1. Go to **Accounts**. Tap **Add Account**.
2. Set Account Type to **Traditional 401(k)**. A new section, **"What kind of retirement account
   is this?"**, appears with the same nine-row picker.
3. Pick **403(b) or 457, government employer**, save.
4. In the accounts list, this account should now read **"403(b) or 457 (Government Employer)"**,
   not "Traditional 401(k)".
5. Tap the account to edit it again: you should see a teal "Classified as: 403(b) or 457
   (Government Employer)" badge under the picker, and a caption noting this affects the
   single-year Tax Summary and Scenarios but not yet the Multi-Year plan.
6. For comparison, add a second Traditional 401(k) account and pick **Employer 401(k)** (or leave
   the default). It should keep reading "Traditional 401(k)" in the list, unchanged. This is
   expected: per spec, "Employer 401(k)" and "403(b) or 457, private or nonprofit employer" are
   recorded identically and cannot be told apart from stored data, so only the government-employer
   row changes the displayed label.
7. Add a Roth IRA or an Inherited Traditional IRA: no plan-type picker section should appear at
   all for either.

### 4. Hawaii's disclosure

1. Set residence state to **Hawaii** (Settings tab).
2. Go to **Income Sources**, add or edit a pension. In the "What kind of pension is this?"
   section, you should see a caption: "Hawaii excludes the employer-funded portion of a pension
   from state tax. This app does not model the split between employer-funded and
   employee-contributed amounts, so your Hawaii state tax may be overstated."
3. Switch residence to a different state (e.g. New York) and re-open the same pension edit sheet:
   that caption must be gone.

### 5. New York limitation in State Comparison

1. Add an unclassified pension (Not sure).
2. Go to **State Comparison**. Tap New York's row anywhere in the ranked list (or, if your
   residence is already New York, tap your own state card at the top).
3. The detail sheet should show an amber banner near the top: "Your pension is not yet classified
   as government or private in Income Sources. New York excludes a qualifying government pension
   from state tax with no dollar cap, but this figure applies the standard $20,000 pension
   exclusion until it is classified." This should appear whether or not your OWN residence is New
   York, as long as the sheet you are viewing is New York's.
4. Classify the pension, reopen New York's detail sheet: the banner should be gone.
5. Open any OTHER state's detail sheet (e.g. California) with the pension still unclassified: no
   New York banner should appear there.

### 6. Multi-Year CPA briefing

1. With residence set to New York and an unclassified pension present, go to the **Multi-Year
   Plan** tab and generate/export the CPA briefing (PDF or share sheet).
2. The Limitations section should include the same New York sentence as above.
3. If residence is Hawaii and there is any pension income, the Limitations section should also
   include the Hawaii sentence.
4. Classify the pension (New York case) or remove/leave Hawaii (Hawaii case): the corresponding
   sentence should disappear from a freshly generated briefing.

## Whole-branch review fixes

Four findings from the whole-branch review of this phase (HEAD `4c05388`), fixed on top of Task
6. Two user-facing falsehoods (Fix 1, Fix 4), one real divergence a named user can hit (Fix 2),
and one missing regression test for the phase's most consequential bug (Fix 3).

### Fix 1: the account picker's disclosure was false, and so was the spec sentence it came from

`AccountsView.swift:312` told the user account classification "affects your single-year Tax
Summary and Scenarios. It does not yet affect the Multi-Year plan." It affects **neither**.
`IRAAccount.planStructure`/`planSource` are read at two presentation sites repo-wide
(`AccountsView.swift:159` the list label, `AccountsView.swift:263` the edit sheet's reverse
lookup for the badge), plus `Codable` encode/decode; `TaxCalculationEngine.swift` never
references `iraAccounts` at all, confirmed by `grep -n iraAccounts RetireSmartIRA/TaxCalculationEngine.swift`
returning nothing.

Replaced the string with the truth (`AccountsView.swift:312`): "This is recorded for a possible
future state rule based on account type. It does not change any calculated tax today, anywhere
in the app."

Corrected the source of the error: `docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md`
section 3.4b claimed "a user's account classification affects the single-year calculation and
not the Multi-Year projection," the overpromising direction. Its own next clause ("stored and
displayed but inert until Kansas is verified") was already the accurate one; the section now
says account classification is inert in every tax path this phase ships, names the two
presentation-only read sites, and keeps the accurate clause.

No dedicated test: this is a string-literal disclosure and a doc-comment correction, neither
computes anything. Confirmed no existing test asserted the old (false) string
(`grep -rn "does not yet affect the Multi-Year" RetireSmartIRA*/*.swift` returned nothing before
the edit), so nothing needed updating.

### Fix 2: two pension rows for one owner dropped the classification silently

`MultiYearInputAdapter.swift:362-366`, `pensionClassification(from:owner:)`, returned `nil`
whenever an owner had more than one `.pension` row, even when every row agreed. A New York City
retiree holding a NYSLRS state pension and a separate NYC pension (both `(definedBenefit,
nyStateOrLocal)`) is an ordinary profile, not a corner case, and lost the exclusion in
Multi-Year while keeping it in single-year: same household, two different New York answers,
every year of the horizon. All three disclosure surfaces stayed silent too, because they gated
on `planSource == .unknown` and both rows were classified.

**RED transcript** (`RetireSmartIRATests/MultiYearInputAdapterTests.swift`, two new tests added
before touching any production code, run via `-only-testing:RetireSmartIRATests/MultiYearInputAdapterTests`):

```
Test Case '-[RetireSmartIRATests.MultiYearInputAdapterTests test_buildInputs_agreeingMultiplePensionRowsForOneOwnerKeepClassification]' started.
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/MultiYearInputAdapterTests.swift:496: error: -[RetireSmartIRATests.MultiYearInputAdapterTests test_buildInputs_agreeingMultiplePensionRowsForOneOwnerKeepClassification] : XCTAssertEqual failed: ("nil") is not equal to ("Optional(RetireSmartIRA.PlanStructure.definedBenefit)") - Two AGREEING pension rows for the same owner should keep the shared classification, not drop to nil
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRATests/MultiYearInputAdapterTests.swift:498: error: -[RetireSmartIRATests.MultiYearInputAdapterTests test_buildInputs_agreeingMultiplePensionRowsForOneOwnerKeepClassification] : XCTAssertEqual failed: ("nil") is not equal to ("Optional(RetireSmartIRA.PlanSource.nyStateOrLocal)") - Two AGREEING pension rows for the same owner should keep the shared classification, not drop to nil
Test Case '-[RetireSmartIRATests.MultiYearInputAdapterTests test_buildInputs_agreeingMultiplePensionRowsForOneOwnerKeepClassification]' failed (0.350 seconds).
...
Test Case '-[RetireSmartIRATests.MultiYearInputAdapterTests test_buildInputs_disagreeingMultiplePensionRowsForOneOwnerFallBackToNilClassification]' passed (0.000 seconds).
...
Test Suite 'MultiYearInputAdapterTests' failed at 2026-08-03 19:31:01.175.
	 Executed 18 tests, with 2 failures (0 unexpected) in 0.938 (0.944) seconds
```

The companion "disagreeing rows still fall back to nil" test passed immediately, as expected: it
documents behavior this fix must NOT change (a genuine mix, e.g. one NY government pension plus
one private pension for the same owner, must still fall back to `nil` rather than guess which
row's classification belongs on the pooled total).

**Fix:** `pensionClassification(from:owner:)` now attaches the shared classification when every
row for that owner agrees, and falls back to `nil` only when they genuinely disagree, via a new
`PlanClassificationChoice.hasMixedPensionClassification(in:owner:)` (`IncomeSourcesView.swift`).
Extended the three disclosure predicates so a genuine mix still warns (previously `nil`
classification with no `.unknown` row warned nobody):
- `PlanClassificationChoice.shouldPromptForClassification` (`IncomeSourcesView.swift:129`) gained
  an `hasMixedPensionClassification: Bool = false` parameter, OR'd with the existing
  `planSource == .unknown` check. `IncomeRow` (the per-row amber banner) now computes and passes
  it.
- `StateComparisonView.hasUnclassifiedPension` and `MultiYearPlanView.swift:365`'s CPA-briefing
  call site both OR in a new `PlanClassificationChoice.hasAnyMixedPensionClassification(in:)`,
  which checks every owner who has pension income.

After the fix, both new tests plus a full run of `MultiYearInputAdapterTests` (18/18) and
`Phase3bPresentationTests` (47/47, including 6 new tests directly proving
`hasMixedPensionClassification`/`hasAnyMixedPensionClassification`/the extended prompt
predicate) passed green.

### Fix 3: the phase's most consequential bug (Task 6's own "two latent bugs fixed as a side
effect") had no regression test

Neither `AddIncomeView.saveIncome()` nor `AddAccountView.saveAccount()` had passed
`planStructure`/`planSource` before Task 6, so any edit to a classified row silently reverted it
to the inferred default. Task 6 fixed this at `IncomeSourcesView.swift:1263-1264` and
`AccountsView.swift:589`/`:605`, but both save methods are private methods on private view
structs, so a refactor could re-break it with every test green.

Hoisted the decision out of each into a testable static on `PlanClassificationChoice`
(`IncomeSourcesView.swift`):
- `classificationToSave(incomeType:choice:) -> RetirementPlanClassification?`: `choice.classification`
  for `.pension`, `nil` for everything else (the exact branch at the old `IncomeSourcesView.swift:1263`).
- `classificationToSave(accountType:choice:) -> RetirementPlanClassification?`: `choice.classification`
  when `showsPickerFor(accountType:)` is true, `nil` otherwise (defensive: a Roth/inherited
  account never saves a stray classification even if a future refactor stops resetting the
  picker's selection on an account-type change; behaviorally identical to before since `planChoice`
  was already reset to the correct inferred default for those types).

`saveIncome()` and `saveAccount()` now call these statics instead of inlining the decision. Four
new tests pin both branches for both types (`Phase3bPresentationTests.swift`):
`pensionSaveCarriesChosenClassification`, `nonPensionSavePassesNil`,
`accountSaveCarriesChosenClassificationWhenPickerShown`, `rothAndInheritedAccountSavePassesNil`.

**Mutation proof**, `classificationToSave(incomeType:choice:)` (flipped `==` to `!=`):

```
✘ Test "A pension row's save carries the picker's chosen classification" recorded an issue at Phase3bPresentationTests.swift:291:9: Expectation failed: (PlanClassificationChoice.classificationToSave(incomeType: .pension, choice: choice) → nil) == (choice.classification → RetirementPlanClassification(structure: RetireSmartIRA.PlanStructure.definedBenefit, source: RetireSmartIRA.PlanSource.nyStateOrLocal))
✘ Test "A non-pension row's save passes nil, regardless of the picker's leftover selection" recorded an issue at Phase3bPresentationTests.swift:297:9: ...
✘ Test "A non-pension row's save passes nil, regardless of the picker's leftover selection" failed after 0.005 seconds with 3 issues.
```

Reverted; re-ran, both tests green again.

**Mutation proof**, `classificationToSave(accountType:choice:)` (flipped `showsPickerFor(...)` to
`!showsPickerFor(...)`):

```
✘ Test "An account whose type shows the picker saves the picker's chosen classification" recorded an issue at Phase3bPresentationTests.swift:305:9: Expectation failed: (PlanClassificationChoice.classificationToSave(accountType: .traditional401k, choice: choice) → nil) == (choice.classification → RetirementPlanClassification(structure: RetireSmartIRA.PlanStructure.definedContribution, source: RetireSmartIRA.PlanSource.privateEmployer))
✘ Test "An account whose type shows the picker saves the picker's chosen classification" failed after 0.001 seconds with 2 issues.
✘ Test "A Roth or inherited account's save passes nil, regardless of the picker's leftover selection" recorded an issue at Phase3bPresentationTests.swift:313:13: ... (x4, one per Roth/inherited AccountType case)
✘ Test "A Roth or inherited account's save passes nil, regardless of the picker's leftover selection" failed after 0.002 seconds with 4 issues.
```

Reverted; re-ran, both tests green again.

### Fix 4: two surfaces still printed "Traditional 401(k)" over a classified 403(b) (known-open, promoted)

Task 6 fixed `AccountsView.swift:159` (the accounts list) but flagged two more call sites with
the identical bug as out of its four-file scope: `PDFExportService.swift:1326` (the account
table in the exported Tax Summary PDF) and `RMDCalculatorView.swift:687` (the RMD calculator's
account list), both rendering `account.accountType.rawValue` directly instead of
`PlanClassificationChoice.accountDisplayName(...)`. Promoted because, given Fix 1, the label IS
the entire deliverable for a classified 403(b): there is no tax effect behind it, so a label
that is right on one screen and wrong on the two a user would print for their CPA is worse than
not shipping it.

Fixed both call sites to use `PlanClassificationChoice.accountDisplayName(accountType:planStructure:planSource:)`:
- `PDFExportService.swift`'s `sectionAccounts(_:)` (made non-`private`, matching this file's own
  `MultiYearCPABriefingHTML.build` convention, so a test can call it without constructing the
  46-field `PDFExportData` fixture by hand -- it already has a `PDFExportData(from: DataManager)`
  convenience init used elsewhere in the app).
- `RMDCalculatorView.swift` gained a new `static func accountTypeLabel(for account: IRAAccount) -> String`
  (not `private`, not an instance method, so a test can call it without constructing the view),
  used at the one call site that used to print the raw type.

Two new tests per surface (`Phase3bPresentationTests.swift`): a "classified account shows the
new label" test and an "unclassified account is unchanged" test, for both
`pdfAccountsSectionShowsClassifiedAccountLabel`/`pdfAccountsSectionUnclassifiedAccountUnchanged`
and `rmdCalculatorShowsClassifiedAccountLabel`/`rmdCalculatorUnclassifiedAccountUnchanged`.

**Mutation proof**, reverted `PDFExportService.swift`'s row back to `a.accountType.rawValue`:

```
✘ Test "The PDF export's account table shows a classified 403(b)/457 as itself, not Traditional 401(k)" recorded an issue at Phase3bPresentationTests.swift:160:9: Expectation failed: (html → "...<td>State 403(b)</td><td>Traditional 401(k)</td>...").contains("403(b) or 457 (Government Employer)")
✘ Test "The PDF export's account table shows a classified 403(b)/457 as itself, not Traditional 401(k)" recorded an issue at Phase3bPresentationTests.swift:161:9: Expectation failed: !((html → "...").contains(">Traditional 401(k)<") → true)
✘ Test "The PDF export's account table shows a classified 403(b)/457 as itself, not Traditional 401(k)" failed after 0.012 seconds with 2 issues.
```

Every other test in the suite (46/47) stayed green, including the RMD calculator's own pair,
confirming the mutation was isolated to the surface it targeted. Reverted; re-ran, green again.

### Mutation summary

| Mutation | Target | Discriminated |
|---|---|---|
| (a) revert Fix 2 adapter change | `MultiYearInputAdapter.pensionClassification` | Yes -- the two new agreeing/disagreeing tests, exactly (2 failures, rest of suite untouched) |
| (b1) break `classificationToSave(incomeType:choice:)` | Fix 3 income static | Yes -- both income-save tests (4 failures across the two) |
| (b2) break `classificationToSave(accountType:choice:)` | Fix 3 account static | Yes -- both account-save tests (6 failures across the two) |
| (c) revert PDFExportService surface | Fix 4 PDF surface | Yes -- exactly the PDF classified-label test (2 failures), RMD calculator's tests unaffected |

### Frozen baseline and I2 pins

```
$ xcodebuild test ... -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests -only-testing:RetireSmartIRATests/GoldenScenarioCrossPathTests
✔ Test "Both engine entry points report the same state tax" with 3 test cases passed after 0.004 seconds.
✔ Test "PINNED, New Jersey single-year vs multi-year: two components, I2 is the smaller one" passed after 0.001 seconds.
✔ Suite "Golden scenarios, cross-path agreement" passed after 0.004 seconds.
✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.041 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.041 seconds.
✔ Test run with 3 tests in 2 suites passed after 0.046 seconds.
```

`git status --porcelain RetireSmartIRATests/Baselines/ RetireSmartIRA/TaxCalculationEngine.swift RetireSmartIRA/Resources/StateTaxData/ RetireSmartIRA.xcodeproj/project.pbxproj`
returned nothing: none of these were touched by any of the four fixes. The 1,020-value baseline
stayed byte-identical because it was never regenerated. `GoldenScenarioCrossPathTests`' single-
year `$42.00` and multi-year `200.40469973890345` New Jersey pins (`GoldenScenarioCrossPathTests.swift:151,160`)
are still asserted verbatim and passed unchanged. No computed tax value moved for any
jurisdiction other than New York, and for New York only in the multiple-pension case Fix 2
repairs (proved by the two new adapter tests: the agreeing case now excludes the pension the way
single-year always did; the disagreeing case is unchanged, still capped).

### Em dash check

```
$ python3 -c "... git diff -- RetireSmartIRA RetireSmartIRATests docs, count U+2014 on added lines ..."
TOTAL ADDED-LINE EM DASHES (whole-branch-review diff): 0
```

### Full suite (run once, foreground)

```
$ xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
...
✔ Test run with 1752 tests in 285 suites passed after 307.147 seconds.
...
	 Executed 505 tests, with 0 failures (0 unexpected) in 20.372 (20.684) seconds
...
** TEST SUCCEEDED **
```

Growth from Task 6's suite (1738 Swift Testing tests / 285 suites, 503 XCTest) to 1752/285 (+14
Swift Testing) and 505 XCTest (+2) is exactly the fourteen `Phase3bPresentationTests` additions
(6 for Fix 2's predicates, 4 for Fix 3's hoisted statics, 4 for Fix 4's two surfaces) and two
`MultiYearInputAdapterTests` additions (Fix 2's agreeing/disagreeing adapter tests) this pass
added.

**Tree-confirmation grep:**
```
$ grep -m5 "\.xcodeproj" full-suite.log
    /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination platform=macOS
    cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3b/RetireSmartIRA.xcodeproj
```

### `git diff --stat`

```
 RetireSmartIRA/AccountsView.swift                  |  15 ++-
 RetireSmartIRA/IncomeSourcesView.swift             | 100 ++++++++++++---
 RetireSmartIRA/MultiYearInputAdapter.swift         |  25 ++--
 RetireSmartIRA/MultiYearPlanView.swift             |   6 +-
 RetireSmartIRA/PDFExportService.swift              |  12 +-
 RetireSmartIRA/RMDCalculatorView.swift             |  13 +-
 RetireSmartIRA/StateComparisonView.swift           |  12 +-
 RetireSmartIRATests/MultiYearInputAdapterTests.swift        |  58 +++++++++
 RetireSmartIRATests/Phase3bPresentationTests.swift          | 137 ++++++++++++++++++++-
 docs/.../2026-08-03-state-tax-phase3b-per-source-design.md  |   2 +-
 10 files changed, 341 insertions(+), 39 deletions(-)
```

No new files created; all four fixes landed in existing production and test files.
`RetireSmartIRA.xcodeproj/project.pbxproj`, `TaxCalculationEngine.swift`, and
`Resources/StateTaxData/` untouched. `AccountSnapshot` untouched (Fix 2 only widened the
adapter's internal `pensionClassification` helper and the shared `PlanClassificationChoice`
predicates, never the persisted account-bucket type).
