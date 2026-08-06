# Task 3 report: no-income-tax jurisdictions

Branch `feature/state-tax-phase4`, worktree `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4`.
Commit: `d9445c8c70fddeb9a826bfa6453ce28c49e78590`.

## Attestation

I personally opened every sourceURL in this batch and checked every clause of each source string against the page.

Six of the eight (AK, FL, NV, SD, TN, TX after the SPA rendered) were confirmed by loading the live page in the
Browser tool and reading its actual rendered text (`get_page_text`), or in Florida's case by downloading the
official PDF brochure and reading it directly. Wyoming and Texas needed extra steps recorded below because the
first URL each led to did not work as expected; the URL actually cited is the one I opened and read, not the
first one I tried.

## Per-jurisdiction citations

**AK** - Alaska Department of Revenue, Tax Division, "Personal Income Tax" program page.
URL: https://tax.alaska.gov/programs/programs/index.aspx?10001
Opened directly in the Browser tool (had to navigate from the Tax Types index page to this specific program page;
a first guess at a "what's new" URL 404'd, so I do not cite that one). Page text read verbatim:
"Does Alaska have a personal income tax? The State of Alaska currently does not have an individual income tax,
therefore no employee withholding for state income tax is required." Quoted verbatim in each of AK's four fixture
`source` strings.

**FL** - Florida Department of Revenue, GT-800025 "Tax Information for New Residents" (R. 08/25), page 3.
URL: https://floridarevenue.com/Forms_library/current/brochure/gt800025.pdf
Downloaded and read the PDF directly (3 pages). Page 3, "Other Taxes and Fees": "Florida does not impose personal
income tax, inheritance tax, gift taxes, or tax on intangible personal property." Quoted verbatim.

**NV** - Nevada Department of Taxation, "Income Tax in Nevada" page.
URL: https://tax.nv.gov/about-nevada-department-of-taxation/income-tax-in-nevada
The FAQ URL I first tried (`/FAQs/Information_About_Nevadas_Taxes_and_The_Department/`) redirected to the
Department's homepage rather than the FAQ content, so I do not cite that URL; I found and opened the current page
instead. Page text read verbatim: "No State Income Tax on Individuals: Nevada residents do not pay state tax on
income earned from salaries, wages, or similar compensation."

**SD** - South Dakota Department of Revenue, Individuals > Taxes page.
URL: https://dor.sd.gov/individuals/taxes/
Opened directly. "Income Tax" section reads verbatim: "South Dakota is one of seven states that does not impose a
state income tax."

**TN** - Tennessee Department of Revenue, Hall Income Tax overview page.
URL: https://www.tn.gov/revenue/taxes/hall-income-tax.html
Opened directly. Reads verbatim: "The Hall Income tax was repealed for tax periods that begin on January 1, 2021,
or later. Please do not file a return for any tax year that begins on or after January 1, 2021." The Hall Tax was
Tennessee's only individual-level income tax (on interest and dividend income only; Tennessee never taxed wages or
retirement income); its full repeal means no individual income tax remains for tax year 2026.

**TX** - Texas Constitution, Article 8, Section 24-a ("Individual Income Tax Prohibited"), official text via the
Texas Legislature's statutes site.
URL: https://statutes.capitol.texas.gov/Docs/CN/htm/CN.8/CN.8.24-a.htm
This site is a client-rendered app; a first navigation attempt and a raw `curl` both returned only the page shell
with no statute text, so I did not cite from those attempts. I re-navigated and waited for the JS to render, then
read the fully rendered Article 8 text (over 90,000 characters, via the page-text extraction tool, read in full,
not truncated at the point where Section 24-a appears). Confirmed verbatim: "Sec. 24-a. INDIVIDUAL INCOME TAX
PROHIBITED. The legislature may not impose a tax on the net incomes of individuals, including an individual's
share of partnership and unincorporated association income. (Added Nov. 5, 2019.)"

**WY** - Wyoming Legislature, Joint Revenue (interim) Committee publication "Wyoming Tax Structure: A comparison
to selected other states" (May 10, 2021, prepared by LSO Budget/Fiscal staff), Slide 4.
URL: https://wyoleg.gov/InterimCommittee/2021/03-202105102-6.wyotaxstructurecomparisontootherstatesLSO.pdf
Wyoming's DOR site does not carry a single page stating this in one sentence (its Tax Types listing and Annual
Report pages did not render usable content through the tools available, and a "Joint Revenue Committee Guide to
Wyoming's Tax Structure" PDF I checked first turned out not to mention income tax by name anywhere, so I do not
cite that guide). I downloaded and extracted text from this Legislative Service Office comparison deck instead.
Slide 4, "Major Components of Wyoming Tax Structure," lists Wyoming's tax categories alongside the explicit lines
"No Individual Income Taxes" and "No Corporate Income Taxes." Read directly from the extracted PDF text, not from
a search-engine summary.

**NH** - New Hampshire Department of Revenue Administration press release, "Repeal of NH Interest and Dividends
Tax Now in Effect" (January 23, 2025).
URL: https://www.revenue.nh.gov/news-and-media/repeal-nh-interest-and-dividends-tax-now-effect
A first attempt via the automated web-fetch tool returned HTTP 403; I opened the same URL directly in the Browser
tool instead and it rendered normally. Read in full. Key sentences, both quoted verbatim in the fixture: "For tax
periods beginning on or after January 1, 2025, New Hampshire taxpayers are no longer required to pay the state's
Interest and Dividends Tax." and "House Bill 2, passed by the New Hampshire General Court and signed into law by
Governor Chris Sununu during the 2023 legislative session, repealed the Interest and Dividends Tax, effective
January 1, 2025. Initially set for repeal in 2026, the repeal was accelerated during the 2023 session to become
effective this year." Bill and disposition: HB 2, 2023 session, signed (enacted), effective January 1, 2025.

## New Hampshire trap check

Read `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-NH.json` before writing the fixture: `taxSystem`
is `specialLimited`, not `noIncomeTax`. Read `TaxCalculationEngine.swift:394-403` before writing the fixture:
`case .noIncomeTax, .specialLimited: tax = 0` -- both cases are handled identically and unconditionally, so the
engine was expected to return $0 for every NH scenario regardless of income. Ran
`GoldenScenarioSingleYearTests` after writing the fixture and confirmed NH's four cases all pass at $0 with no
`knownDefect` needed; this is a MEASURED result, not a prediction made before running the suite. No knownDefect
block appears in any of the eight fixtures in this batch.

## Batch design

All eight jurisdictions get the four-case matrix per the brief's rule for "no age threshold and no phase-out"
states: cases 1-2 vary income instead of age (single filer at $40,000 then $120,000, the second adding an IRA
withdrawal and a Roth conversion), case 3 is MFJ with both spouses present at moderate combined income including
taxable Social Security ($90,000), and case 4 is MFJ with a large age gap between spouses at the batch's highest
combined income ($150,000, adding all four income components). Every fixture's `federalAGI` is the exact sum of
its declared components (verified both by hand and by the suite's
`federalAGIIsInternallyConsistent` test). No fixture uses `classifiedPensionSources` or `otherOrdinaryIncome`;
none was needed since income composition and `federalAGI` already reconcile exactly with plain scalar fields.

## Test results

Step 6, targeted run against just the new fixtures plus the five existing ones (`GoldenScenarioSingleYearTests`):

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests
```

Result: `Test "Single-year path matches each state's own published form" with 13 test cases passed after 0.012
seconds.` (13 = the five existing states plus the eight new ones.) `Test run with 3 tests in 1 suite passed after
0.013 seconds.` `** TEST SUCCEEDED **`. No `knownDefect` block was needed for any of the eight new fixtures; every
case matched its cited form on the first run.

Step 9, full suite, run twice for confirmation (both green, both after the fixtures and `covered` edit were in
place):

```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA -destination 'platform=macOS'
```

Verbatim result (second/final run):

```
Test Suite 'RetireSmartIRATests.xctest' passed at 2026-08-04 13:24:01.299.
	 Executed 509 tests, with 0 failures (0 unexpected) in 21.315 (21.481) seconds
Test Suite 'All tests' passed at 2026-08-04 13:24:01.299.
	 Executed 509 tests, with 0 failures (0 unexpected) in 21.315 (21.481) seconds
...
✔ Test run with 1850 tests in 291 suites passed after 310.842 seconds.
** TEST SUCCEEDED **
```

6 skipped tests, all pre-existing and env-gated (confirmed by grepping the log): the 4 `RUN_AUDIT_HARNESS`-gated
27-profile display-audit tests, plus "Generate the frozen behavior baseline" and "Generate all 51 jurisdiction
files."

**Baseline reconciliation.** The task brief's own text stated a baseline of "1,845 Swift Testing in 290 suites"
measured on this branch, while my direct instructions stated "1,850 Swift Testing tests in 291 suites." These
two numbers disagree, and I did not want to guess which was current, so I checked directly: I `git stash`ed my
fixture files and the `covered` edit, reran the full suite against the untouched starting commit, and got
`Executed 509 tests` (XCTest) and `Test run with 1850 tests in 291 suites` (Swift Testing) -- identical to my
final post-change numbers. I then popped the stash and reran once more to confirm the post-change suite is still
green. Conclusion: the true starting baseline was 1,850/291/509/0-failures/6-skipped, matching my direct
instructions; the brief's "1,845/290" figure was stale. Adding eight fixtures and eight `covered` entries changes
the number of *test cases* inside the existing parameterized `@Test` declarations (`fixtureLoads`,
`federalAGIIsInternallyConsistent`, `citationsAreWellFormed`, `noDoubleCountedPension`,
`singleYearMatchesGolden`), not the count of `@Test` declarations or `@Suite`s themselves, so the top-level
"N tests in M suites" figure is unchanged before and after this batch. Both runs: 0 failures, 6 skipped.

## Production diff (must be empty)

```
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 diff --stat main -- RetireSmartIRA/
```

Output: empty. No file under `RetireSmartIRA/` (the production target) was touched. `git status --porcelain`
shows only `RetireSmartIRATests/GoldenScenarioCoverageTests.swift` (modified, one line: the `covered` array) and
the eight new `RetireSmartIRATests/GoldenScenarios/statetax-2026-*.golden.json` files. The five existing fixtures
(PA, IL, MS, NJ, NY) are untouched.

## Em dash check

Scanned every changed/new file for the U+2014 em dash character (byte sequence `\xe2\x80\x94`) using a Python
byte-level check, not a shell grep alias that could silently misbehave. All nine files (the eight new fixtures
plus `GoldenScenarioCoverageTests.swift`) came back clean. No em dashes anywhere in this batch's changes, in JSON
strings or in code.

## Deviations from the brief, with reasoning

- Wyoming's citation is a Legislative Service Office presentation PDF rather than a single DOR web page, because
  no single Wyoming DOR page stating "no individual income tax" in one sentence could be found and confirmed
  through the tools available; a first-choice LSO "Guide to Wyoming's Tax Structure" PDF was checked and rejected
  because it never mentions income tax by name. The LSO comparison deck is a Wyoming Legislature publication
  (admissible per the brief's "state DOR pages, statutes, enrolled bills... legislature page" category) and its
  Slide 4 states the fact explicitly and was read directly, not summarized secondhand.
- Texas's citation required re-navigating and waiting for client-side rendering rather than reading the URL on
  the first attempt (both `WebFetch` and a raw `curl` returned only the page shell). This is disclosed above and
  the actual rendered constitutional text was read before citing it.
- No `knownDefect` blocks were needed anywhere in this batch; expectation was "all pass at $0" and that held for
  all 32 cases (8 states x 4 cases) on the first test run.

## Files

- `RetireSmartIRATests/GoldenScenarioCoverageTests.swift` (modified, `covered` array only)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-AK.golden.json` (new)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-FL.golden.json` (new)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-NV.golden.json` (new)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-SD.golden.json` (new)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-TN.golden.json` (new)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-TX.golden.json` (new)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-WY.golden.json` (new)
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-NH.golden.json` (new)

Commit: `d9445c8c70fddeb9a826bfa6453ce28c49e78590`, "test(state-tax): golden scenarios for no-income-tax
jurisdictions", 9 files changed, 497 insertions(+), 1 deletion(-).

## Follow-up: Wyoming citation slide-number correction (2026-08-04)

### Finding under review

All four Wyoming golden scenarios cited "Slide 4 'Major Components of Wyoming Tax Structure'" as the
location of the quoted lines "No Individual Income Taxes" and "No Corporate Income Taxes." A reviewer
downloaded the cited PDF and reported those lines are actually on Slide 5, and that Slide 4 is a
different slide ("Tax Structure Categories Included in Comparison") with no such statement.

### Independent verification performed

Downloaded the cited PDF directly (`curl -sL` to
`https://wyoleg.gov/InterimCommittee/2021/03-202105102-6.wyotaxstructurecomparisontootherstatesLSO.pdf`,
1,970,770 bytes, confirmed as a 32-page PDF via `file`). Extracted text page by page with `python3` and
`pypdf` (`PdfReader.extract_text()` per page) rather than trusting a plain-text fetch, since the source
is a PDF slide deck.

What was actually found:

- Page 4 of the PDF, footer "State of Wyoming Legislature Slide 4," is titled "Tax Structure Categories
  Included in Comparison." Its body defines the five tax categories used throughout the deck (Property
  Taxes, General Sales Taxes, Individual Income Taxes, Corporate Income Taxes, Other Taxes) in the
  abstract. It contains no state-specific statement about Wyoming and no occurrence of the phrase
  "No Individual Income Taxes" or "No Corporate Income Taxes."
- Page 5 of the PDF, footer "State of Wyoming Legislature Slide 5," is titled "Major Components of
  Wyoming Tax Structure." Its body lists Wyoming's actual FY18 tax composition by category (Property
  Taxes 39.7%, General Sales Taxes 26.5%) and includes the two lines verbatim: "No Individual Income
  Taxes" and "No Corporate Income Taxes," followed by Other Taxes 31.8%.

This independently confirms the reviewer's finding: the quoted text sits on Slide 5, not Slide 4. The
URL, the document, the slide title quoted ("Major Components of Wyoming Tax Structure"), and the quoted
words were all already correct; only the slide number was wrong.

### Edits applied

File changed: `RetireSmartIRATests/GoldenScenarios/statetax-2026-WY.golden.json` (the only file touched).
Four occurrences of "Slide 4" in the `source` field, one per scenario, were changed to "Slide 5." No
other text in any `source` string was altered, and no other field (URL, quoted words, ages, incomes,
`expectedStateTax`, etc.) was touched in this or any other fixture.

1. Scenario 1 ("single, lower income..."): "...Slide 4 'Major Components of Wyoming Tax Structure'..."
   to "...Slide 5 'Major Components of Wyoming Tax Structure'..."
2. Scenario 2 ("single, higher income including a Roth conversion..."): "...Slide 4, 'No Individual
   Income Taxes.'" to "...Slide 5, 'No Individual Income Taxes.'"
3. Scenario 3 ("MFJ, both spouses present..."): "...Slide 4, 'No Individual Income Taxes' (the slide is
   not filing-status-scoped..." to "...Slide 5, 'No Individual Income Taxes' (the slide is not
   filing-status-scoped..."
4. Scenario 4 ("MFJ, only one spouse retirement-aged..."): "...Slide 4. This is the batch's..." to
   "...Slide 5. This is the batch's..."

A follow-up grep confirmed zero remaining occurrences of "Slide 4" in the file and four occurrences of
"Slide 5," one per scenario.

### Focused suite output (foreground, full paste)

Command:
```
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/GoldenScenarioCoverageTests \
  -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests
```

Relevant tail of output:
```
✔ Test "Single-year path matches each state's own published form" with 13 test cases passed after 0.007 seconds.
◇ Test "classify covers all five outcomes of the defect-pin decision" started.
✔ Test "classify covers all five outcomes of the defect-pin decision" passed after 0.001 seconds.
◇ Test "A fixture with no knownDefect decodes it as nil" started.
✔ Test "A fixture with no knownDefect decodes it as nil" passed after 0.001 seconds.
✔ Suite "Golden scenarios, single-year path" passed after 0.014 seconds.
✔ Test run with 8 tests in 2 suites passed after 0.060 seconds.
** TEST SUCCEEDED **
```

### Diff checks

`git diff --stat` (whole worktree) showed two modified files:
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-WY.golden.json` (the intended edit)
- `docs/superpowers/plans/2026-08-04-state-tax-phase4-golden-scenarios.md` (a pre-existing uncommitted
  edit already present in the working tree before this task started, appending review notes about
  Task 3's citation defect and the income-template-reuse note for Task 4+; this agent did not create or
  touch this file). Confirmed via `git diff` on that file that its content is unrelated review/planning
  prose, not touched by this task, and it was deliberately excluded from the commit below by staging the
  WY fixture path explicitly rather than using `git add -A`.

`git diff --stat main -- RetireSmartIRA/` returned empty: no production file changed.

### Em dash check

`grep -n $'\xe2\x80\x94' RetireSmartIRATests/GoldenScenarios/statetax-2026-WY.golden.json` returned no
matches (exit code 1). None present.

### Commit

Staged and committed only `RetireSmartIRATests/GoldenScenarios/statetax-2026-WY.golden.json` (explicit
path, not `git add -A`). The pre-existing plan-doc edit was left uncommitted and untouched.
