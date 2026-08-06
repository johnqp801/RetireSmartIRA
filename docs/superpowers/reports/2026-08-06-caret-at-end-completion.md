# Caret-at-end, completed

Branch `fix/caret-at-end-completion`, off `main` @ `d58f489`.
Commitment item 6 of six. Reported by Alan Levy 2026-07-19, promised the same day,
missed by 2.3.0 / build 63.

## The shape, and the evidence for it

**One call site, at the WindowGroup root in `RetireSmartIRAApp.swift`.** Not eight
more screens. The redundant per-screen call in `SettingsView.swift` is removed.

`.caretAtEndOnFocus()` does not behave like a normal view modifier. It subscribes
to `UITextField.textDidBeginEditingNotification`, which UIKit posts process-wide,
and the notification carries the field that began editing as its `object`. The
modifier never consults the view hierarchy. So its REACH is the whole process no
matter where it is attached; the attachment point decides only how long the
subscription lives. `onReceive` is live while the modified view is installed, and
the WindowGroup's root content is installed for the entire session.

That is the reasoning. It was verified in the iOS Simulator rather than trusted,
and the verification changed what I believed twice. Both experiments are below.

`.dismissableKeyboard()` in the same codebase really is per-screen, because it
attaches a `.toolbar(placement: .keyboard)`, which is subtree-scoped. The header
comment in `CaretAtEnd.swift` said the two were analogous and told the next
person to "apply once per screen". That was wrong, and it is the sentence that
would have produced the eight-screens answer. It has been rewritten.

## The sheet and popover question, answered concretely

This was the stated risk: SwiftUI presentations do not inherit modifiers from the
presenting view, and several numeric fields live in sheets. A root-level fix that
worked by inheritance would silently miss them.

It does not work by inheritance, and the A/B below proves it on a real sheet
(`TaxableAccountEditor`, presented from `AccountsView`, in a different tab from
the one the old call site lived on).

Probe, identical in all three runs: cold launch, More, Accounts, Add Account
under Taxable Accounts, tap the LEFT end of the trailing-aligned `Balance` field
showing `0`, type one `5`.

| Build | Navigation before the probe | Result |
| --- | --- | --- |
| Shipped (`af45404`, SettingsView only) | straight to Accounts | **`50`** the bug, in a sheet |
| Shipped (`af45404`, SettingsView only) | My Profile first, then Accounts | `05` correct |
| This branch (root call site) | straight to Accounts | `05` correct |

Rows one and two are the same binary. The only difference is whether the user
happened to open My Profile first, which is what instantiated `SettingsView`'s
body and started its observer. So the shipped fix's coverage was not merely
limited to one screen, it was **session-order dependent**: the same field
corrupted the same keystroke or not depending on which tab the user had visited
earlier. Row three is this branch, with My Profile never opened.

Two further runtime checks on this branch:

* **First tap into a field is overridden, later taps are not.** With the field
  reading `05` and already focused, tapping between the digits and typing `9`
  gave `905`. The caret went where the tap went. Text is not made unselectable
  and mid-string editing still works, because a tap inside an already-focused
  field posts no begin-editing notification.
* **The reported field itself.** My Profile, Local / city income tax showing
  `83`, fresh focus, tap the far left of the 56pt field, type `1` gives `831`.
  A front-insert would have given `183`.

One methodological note, recorded because it briefly looked like a failure. My
second probe of the day appeared to show the root fix not working: a field
showing `3` took an `8` and became `83`. The field was still first responder from
the previous probe (tapping a Form section header does not resign it), so that
tap was a reposition, not a fresh focus. It was measuring the correct behaviour
described above. Every result in the table is from a cold launch.

## Per-file enumeration

The defect needs three things at once: **trailing alignment** (so the wide part
of the tap target is left of the digits), **pre-filled** (so there is something
to insert in front of), and **numeric** (so the corrupted value commits silently).
Leading-aligned fields are listed as a weaker case: their wide empty tap area is
to the RIGHT of the text, so a tap there already lands at the end, and only a tap
on the first character inserts in front. Empty-on-open fields cannot exhibit it
at all.

All of them are covered now regardless, because one observer covers the process.
The column that matters is which ones were exposed.

### Exhibited the defect (trailing-aligned, pre-filled, numeric)

| File | Fields | Note |
| --- | --- | --- |
| `SettingsView.swift` | local/city income tax rate; primary heir birth year; eight Medicare Part B/D/Medigap/Advantage overrides; ACA benchmark premium | The rate field is Alan's exact report. The override fields read `?? default`, so they always DISPLAY a number even when unset. |
| `TaxableAccountsSection.swift` | balance, cost basis, price growth, four yields, protected amount | In a SHEET. This is the field the A/B above uses. |
| `QuarterlyTaxView.swift` | prior-year federal tax, state tax, AGI; per-payment paid amount | Paid amount is seeded from the estimate the moment the Paid toggle flips, so it is pre-filled by the time it is tappable. |
| `SSDataEntryView.swift` | monthly benefit, the shared `benefitField`, future earnings, future years | The whole view is presented in a SHEET from `SocialSecurityPlannerView`. |
| `TaxPlanningView.swift` | stock purchase price, stock current value; `CurrencyField` | `CurrencyField` is the shared slider-paired control, so this is many fields, not one. Both stock fields are seeded from `dataManager` on appear when non-zero. |
| `MultiYearPlanSections.swift` | annual living expenses, HSA balance | |
| `ConversionApproachSection.swift` | safety buffer below the tier threshold | |
| `Year1EditorView.swift` | Roth conversion this year | Seeded on appear from the plan's Year-1 amount, so never empty in practice. |
| `IncomeSourcesView.swift` | prior-year state balance | Value-bound currency, always shows a number. |

### Weaker case (leading-aligned, pre-filled, numeric)

| File | Fields | Note |
| --- | --- | --- |
| `AccountsView.swift` | balance; year inherited; decedent birth year; beneficiary birth year; year child reaches 21 | In a SHEET. Empty when adding, pre-filled from `accountToEdit` when editing. The four year fields are marked required and feed RMD rules. |
| `IncomeSourcesView.swift` | annual amount; federal and state withholding, both percent and dollar | In the add/edit income and deduction SHEETS. Empty when adding, pre-filled when editing. |
| `YearDetailEditor.swift` | ongoing annual expenses; one-time adjustment | In a SHEET. Empty unless that year already has an override. |

### Did not need it

| File | Fields | Why not |
| --- | --- | --- |
| `RothConversionView.swift` | conversion amount | `@State` starting `""`, reset to `""` after each conversion, and leading-aligned. Never pre-filled on entry. |
| `AccountsView.swift` | account name, institution | Non-numeric. No silent numeric corruption is possible. |
| `TaxableAccountsSection.swift` | account name | Same. |
| `IncomeSourcesView.swift` | description (both sheets) | Same. |
| `SettingsView.swift` | your name, spouse name | Trailing-aligned and pre-filled, but text. Caret-at-end is the right default for a short single-line name anyway: appending is the common edit. |

## The test

`RetireSmartIRATests/CaretAtEndCoverageTests.swift`, 5 tests, following the
`StateAccuracyContentTests.noMultiYearSurfacePresentsTheAccuracyPage` pattern:
sweep production `.swift` files from `#filePath`, assert set equality, prove
non-vacuity first.

Four gates:

1. The sweep finds the real tree (>100 files, unique base names, both subject
   files present) and the comment stripper is actually stripping. This is checked
   on its own so the vacuous-sweep failure is legible rather than showing up as a
   confusing set difference.
2. The set of production files applying `.caretAtEndOnFocus()` is exactly
   `{RetireSmartIRAApp.swift}`. Missing means the app-wide fix stopped shipping;
   added means someone started scattering it per-screen again.
3. The call site is inside the `WindowGroup` body and outside the
   terms-acceptance branch.
4. `CaretAtEnd.swift` keeps both platform arms, still imports UIKit, and still
   observes `textDidBeginEditingNotification`. If that mechanism ever changes to
   something hierarchy-scoped, one call site stops being sufficient and every
   other gate here is measuring the wrong thing.
5. The twelve numeric-field files each still exist, still declare a `TextField`,
   and none carries its own call site.

Three mutations were run and all were caught, then reverted:

* remove the root call site: gates 2 and 3 fail
* add a call site to `SettingsView`: gates 2 and 5 fail
* move the call site inside the accepted-terms arm: gate 3 fails on both its
  assertions

### What the test does NOT prove

Stated at the bottom of the file too, so a green run is never mistaken for
evidence the fix works.

* **Nothing about caret position.** No assertion observes a `UITextField`, a
  `selectedTextRange`, or a keystroke.
* **Nothing on device or in the simulator.** The suite runs against the macOS
  destination, where the entire modifier compiles to `self`. The iOS arm is not
  compiled by the test run at all.
* **It cannot see a UIKit behaviour change.** If a future iOS stopped posting
  `textDidBeginEditingNotification` for SwiftUI-hosted fields, or set its own
  initial selection after the one runloop turn the modifier defers by, every gate
  would stay green and the bug would be back.
* **It does not cover `UITextView`.** `TextEditor` and multiline
  `TextField(axis:)` are outside the mechanism. None hold numbers today.

The only evidence for runtime behaviour is the manual A/B in the simulator above.
It covers one sheet field, one non-sheet field, and the reposition case, on
iPhone 17 Pro. It does not cover iPad, macOS, or a physical device.

## Verification run

```
tools/run-tests.sh
```

```
PASS. 2593 test(s) ran, no failures.
EXIT=0
```

Swift Testing: 2,084 tests in 307 suites passed (baseline 2,079 in 306, plus the
5 new). XCTest: 509 tests, 0 failures. Zero failing suites.

Note on an earlier run of the same command, in case it recurs. Run immediately
after the simulator work, it reported `MultiYearPerfTests` failing, and the
script's automatic isolation re-run failed too, which normally means a real
regression rather than the known flake. It was the flake: the failing assertion
was `elapsed 15.207 < 15.0`, the documented wall-clock budget missed by two
tenths of a second, and Simulator.app was still running and eating CPU during
the isolation re-run. With the simulator shut down the suite alone passed and
then the full suite passed clean, which is the run recorded above. Nothing on
this branch touches the engine.

iOS Simulator build (`RetireSmartIRA.xcodeproj`, Debug, iPhone 17 Pro):
BUILD SUCCEEDED, 0 errors. The 19 warnings are all pre-existing and none is in a
file this branch touches. macOS compiles as part of the test run.

## Concerns

1. **`af45404` was never verified at runtime.** It works, but only on a screen
   whose body has been instantiated, and nobody appears to have checked what that
   meant for the rest of the app. The session-order dependence in the table above
   is the kind of thing a manual pass finds in two minutes and no test in this
   repo could have found.
2. **The mechanism is undefended against UIKit.** A single `DispatchQueue.main.async`
   hop is a timing assumption about when UIKit sets its own initial selection.
   It holds on iOS 18 and on the current simulator. Nothing detects it breaking,
   and the failure mode is silent and numeric. Worth a manual re-check on each
   major iOS bump.
3. **Not verified on iPad or macOS.** iPad runs a different root
   (`NavigationSplitView`), still under the same WindowGroup, so the reasoning
   carries, but it was not exercised. macOS is a no-op by design.
