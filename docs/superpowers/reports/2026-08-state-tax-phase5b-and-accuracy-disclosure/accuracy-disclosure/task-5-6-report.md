# Tasks 5 and 6: the factual half, the page, and the empty state

**Branch** `feature/state-accuracy-disclosure`, worktree
`/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure`.
Started clean at `e3ecabd`.

| Task | Commit | Full suite |
|---|---|---|
| 5, the factual half | `3074127` | 2,055 Swift Testing in 306 suites + 509 XCTest, 0 failures |
| 6, the page and its empty state | `870324c` | 2,062 Swift Testing in 306 suites + 509 XCTest, 0 failures |

Baseline entering the work was 2,048 + 509. Thirteen tests added, seven in Task 5
and six in Task 6. Command, in the foreground, both times:

```
/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure/tools/run-tests.sh
```

No `MultiYearPerfTests` flake occurred in either run. Neither run had any failure
to explain.

---

## 1. Copy APPROVED by John on 2026-08-06, as written

Four strings. All four are the fallback wording for a case where the data states
nothing, which is exactly where Task 3 declined to choose and left the decision
here. All four were approved as written; the alternatives below are recorded as
rejected, not as open options.

| Where | Shipped wording | Why it says this |
|---|---|---|
| Header title, no stated tax year | `Pennsylvania tax treatment, tax year not recorded` | Keeps state and year in ONE string even when the year is unknown |
| Verification line, empty `lastVerified` | `No verification date recorded.` | States the absence rather than omitting the line |
| Sources list, empty `primarySources` | `No primary sources recorded.` | Same reason |
| Navigation title | `State tax accuracy` | Neutral chrome; avoids a bare state name in the title bar |

Alternatives considered and REJECTED for the title, kept for the record:

1. `Pennsylvania tax treatment, tax year not recorded` (SHIPPED). One string, so
   no layout change can separate the state from the statement about its year.
2. `Pennsylvania tax treatment (tax year not stated)`. Reads more like an
   editorial aside than a data absence.
3. `Pennsylvania tax treatment`, with a separate `Tax year: not recorded` row.
   Rejected: it is the one shape that lets a future layout change drop the year
   line and leave a bare state name behind, which is the failure the design's
   third constraint names.

For the verification line, the alternative was `Not verified for this tax year.`
That claims more than the data supports. An empty `lastVerified` means no date
was recorded, not that a verification was attempted and failed.

**Also available and NOT shipped.** The design offers an optional second sentence
after the empty state: *"State tax rules are complex, and this does not mean
every unusual situation is represented."* It is not appended, because the plan's
gate is exact equality against John's sentence and the second sentence is
unapproved. It was NOT part of the 2026-08-06 approval either, deliberately: it
does not ship, so it was never put to him. It remains unapproved. Adding it later
is one line plus a test edit, and its own decision.

**Generated vocabulary is also new user-facing copy**, though it is generated
rather than authored: the seven statement labels (`Tax rates`, `Standard
deduction`, `Personal exemption`, `Social Security`, `Pension exemption`,
`IRA and 401(k) exemption`, `Rules by pension source`), the two section headings
(`What we model`, `Known limitations`, both taken verbatim from the design doc),
and the sentence templates the values are built from. Section 5 below shows the
rendered output for fourteen jurisdictions so this can be reviewed by reading
rather than by running the app.

---

## 2. Statement ordering, and why

`factualStatements(for:filingStatus:)` emits in the order the tax is actually
computed:

1. `Tax rates`
2. `Standard deduction`
3. `Personal exemption`
4. `Social Security`
5. `Pension exemption`
6. `IRA and 401(k) exemption`
7. `Rules by pension source`

Rates first, then the deductions and exemptions that reduce the base, then the
source-specific carve-outs that override the general exemption. The ordering is
load-bearing in one place and not merely aesthetic: Kansas's general
`pensionExemption` is `.none` and its KPERS exclusion lives entirely in a
per-source rule, so a page that listed the carve-out before the general
exemption it overrides would invert the logic a reader is trying to follow.

`statementsKeepTheirOrder` asserts this as a RELATIVE order over whichever
statements a jurisdiction emits, rather than as a fixed list, because two of the
seven are optional. It also fails on any label outside the known set, so a new
statement type cannot be added without deciding where it goes.

**Labels are unique per jurisdiction, and that is enforced.** `Statement.id` is
the label, the page renders them in a `ForEach`, and the plan's own test builds a
`Dictionary(uniqueKeysWithValues:)` keyed by label, which traps on a duplicate.
`statementLabelsAreUniquePerJurisdiction` sweeps all 51 jurisdictions and both
filing statuses. This is why Arizona's TWO per-source rules are joined into one
statement rather than emitted one apiece.

**Deviation from the plan's list, stated rather than silent.** The plan names
"IRA exemption"; the shipped label is `IRA and 401(k) exemption`. The field is
`iraWithdrawalExemption` and its own documentation says it governs "IRA/401(k)
withdrawals", so the plan's shorter label would understate what the line covers
for anyone holding a 401(k) rather than an IRA.

---

## 3. Absent against none, the distinction that decides whether a line appears

The plan says to "omit a statement whose config value is absent rather than
printing 'none'". Taken literally that collides with the plan's own Task 5 test,
which requires `byLabel["Pension exemption"] != nil` for Kansas, whose
`pensionExemption` is `{"kind": "none"}`. The two are only compatible under a
distinction the plan does not draw, so I drew it:

- **Absent** means the configuration carries no value at all: a Swift `nil`.
  The statement is OMITTED. Forty-eight jurisdictions have no `personalExemption`
  object, and rendering "Personal exemption: none" for each would assert a fact
  the configuration never stated, on the one page whose purpose is to separate
  what is known from what is not.
- **None** means the configuration states nothing as its value: an
  `ExemptionLevel.none`, or a `StateDeduction.none`. The statement is PRINTED.
  Kansas's `.none` is a positive statement that Kansas grants no general pension
  exemption, and a Kansas page silent on it leaves a KPERS holder without the
  answer they came for.

Two places where this changes what ships:

- **`pensionExemption == .none` with per-source rules present** renders
  `No general exemption.` rather than `None. Pension income is taxed as ordinary
  income.` A flat "None" is contradicted by the per-source sentence three lines
  later, and a reader who stopped at the first line would conclude their KPERS
  pension is fully taxable. `kansasPerSourceRuleIsStatedPlainly` pins both halves
  together for exactly this reason.
- **`pensionAndIRAShareSingleCap == true`** makes the IRA statement read
  `Shares the single cap stated for the pension exemption, rather than adding a
  second one.` It does NOT restate the IRA's own configured cap, because the
  engine ignores that field when the cap is shared. Restating it would claim a
  second $20,000 exclusion in New York that nobody receives, and New York's
  shared cap exists precisely because an earlier version of this app granted both.

---

## 4. Things I disagreed with, or found wrong in the brief

**One: the plan's "local tax" statement cannot be generated, because no
jurisdiction's configuration carries a local rate.** The plan's Task 5 Step 3
lists local tax as the last statement and the design says "local or city tax
where the config carries one". No config does. `localIncomeTaxRate` is a
parameter of `TaxCalculationEngine.calculateStateTax`, a figure the USER types
in, and it appears nowhere in `StateTaxConfig`. Verified by grep: the only two
occurrences in the whole production tree are the parameter declaration and its
single use at `TaxCalculationEngine.swift:413`.

No local-tax statement is emitted. That follows from the absent-is-omitted rule
above rather than needing a special case, and the design's own "where the config
carries one" anticipates it. Flagged because the plan's checklist reads as though
a line is missing.

**Two: `.specialLimited` needed a decision the plan does not cover.** New
Hampshire and Washington carry `pensionExemption: .full`, `iraWithdrawalExemption:
.full` and `socialSecurityExempt: true`, so a naive rendering produces "Pension
exemption: fully exempt" for New Hampshire, which implies a New Hampshire pension
tax that grants an exemption. The engine returns 0 for both `.noIncomeTax` and
`.specialLimited` before any bracket, deduction or exemption is read, so those
fields never reach a taxpayer at all.

Both cases therefore emit exactly ONE statement and stop.
`untaxedJurisdictionsMakeOneStatement` derives the set from
`taxSystem.hasIncomeTax` rather than naming the nine states, and asserts the
count. The `.specialLimited` wording says what THIS APP does ("applies no state
income tax to the income it models") rather than naming interest, dividends or
capital gains, because the configuration records none of those categories and I
am not willing to author a claim the data cannot support.

**Three, and this one is a real gap rather than a wording choice: the page says
nothing about a state's Roth conversion treatment.** Four jurisdictions carry a
`rothConversionExemption` (Iowa, Illinois, Mississippi, Pennsylvania). The design's
section 1 enumerates the factual half's contents and does not include it, so I
did not add it, because widening the page's claims is a scope decision rather
than an implementation one.

It is worth John's attention. This is a Roth conversion app, the conversion is
the operation the user is on the page to evaluate, and for a Pennsylvania user
the fact that the state exempts the conversion entirely is the single most
decision-relevant thing the configuration knows. Nothing currently on the page
is wrong, and the omission is not a limitation in the `knownLimitations` sense
because those four states are modelled correctly. It is simply not stated.
Adding it is roughly ten lines and one test.

**Four: California's exemption credits have no configuration representation at
all.** `TaxCalculationEngine.calculateStateTax` subtracts
`californiaExemptionCredits(...)` in hardcoded Swift, keyed on `state ==
.california`. A page generated from `StateTaxConfig` cannot see it and does not
mention it. This is the exact "hardcoded engine logic that overrode config" risk
the design's section 1 names, and it is a live instance rather than a
hypothetical. California is outside `coveredJurisdictions` so nothing is
currently claimed about it, but the generated-from-config guarantee is a
guarantee about the SOURCE of the numbers and not about the engine's use of
them. The function's doc comment now says so explicitly. Task 8's Gate 3 is the
right place to close this.

**Five: the brief's own framing of `limitationsSummary` needed a small
decision.** The interface is pinned as returning a `String`, but a bulleted list
is much better for a jurisdiction with two or three limitations. Resolved by
having the VIEW branch on `limitations(for:).isEmpty` and choose a list or a
paragraph, while both strings still come from `StateAccuracyContent`. The view
chooses the shape, never the words. The non-empty return of
`limitationsSummary` is not dead code: it is the API for Tasks 7 and 8 and for
any surface that can render only one string, and it joins with a blank line so
those surfaces still get paragraphs.

---

## 5. The rendered output, for review

Captured from the shipped code across a spread chosen to cover every branch:
progressive and flat rates, all three deduction kinds, the stepped phaseout, the
age tier, the shared cap, the per-spouse cap, per-source rules with and without
survivor and age gates, per-spouse attribution, both untaxed systems, and a state
that taxes Social Security. Single filer unless noted.

```
NJ  Tax rates                 1.4% up to $20,000, 1.75% up to $35,000, 3.5% up to $40,000,
                              5.525% up to $75,000, 6.37% up to $500,000, 8.97% up to
                              $1,000,000, then 10.75%
    Standard deduction        This state grants no standard deduction.
    Personal exemption        $1,000, plus $1,000 for each filer aged 65 or older
    Social Security           Not taxed by this state.
    Pension exemption         Up to $75,000 exempt, reduced in steps once total income passes
                              $100,000, and unavailable above $150,000. Applies from age 62.
    IRA and 401(k) exemption  Shares the single cap stated for the pension exemption, rather
                              than adding a second one.

GA  Tax rates                 4.99% of taxable income
    Standard deduction        $15,000
    Social Security           Not taxed by this state.
    Pension exemption         Up to $65,000 exempt, as one cap covering pension and IRA income
                              together, and the cap applies to each qualifying spouse. Applies
                              from age 65. A reduced exemption of $35,000 applies from age 62 to 64.
    IRA and 401(k) exemption  Shares the single cap stated for the pension exemption, rather
                              than adding a second one.

KS  Tax rates                 5.2% up to $23,000, then 5.58%
    Standard deduction        $3,605
    Personal exemption        $9,160
    Social Security           Not taxed by this state.
    Pension exemption         No general exemption.
    IRA and 401(k) exemption  No general exemption.
    Rules by pension source   Kansas government, federal civilian service, military and
                              Railroad Retirement pensions are fully exempt.

DC  Pension exemption         No general exemption.
    Rules by pension source   Federal civilian service and District of Columbia government
                              pensions paid as a survivor benefit are fully exempt once the
                              recipient is 62 or older.

AZ  Standard deduction        This state starts from your federal taxable income, so your
                              federal deduction carries over.
    Pension exemption         Up to $2,500 exempt.
    Rules by pension source   Military pensions are fully exempt. Private employer, another
                              state's government and New York State or local government
                              pensions and 401(k), 403(b) and 457 plans are not exempt.

IA  Pension exemption         Fully exempt. Applies from age 55. Each spouse's exemption is
                              gated by that spouse's own age.

NY  Pension exemption         Up to $20,000 exempt, as one cap covering pension and IRA income
                              together, and the cap applies to each qualifying spouse. Applies
                              from age 59.
    Rules by pension source   New York State or local government, federal civilian service and
                              military pensions are fully exempt.

UT  Social Security           Taxed as ordinary income.
    Pension exemption         None. Pension income is taxed as ordinary income.

NH  Tax rates                 This state taxes only limited categories of income, and this app
                              applies no state income tax to the income it models.
TX  Tax rates                 This state has no income tax.
```

Two wording defects were found by reading this dump and fixed before commit: New
Jersey read "and gone above $150,000", and the IRA line said "the pension
exemption above", a positional claim about layout embedded in content.

### Per-source rules are written in the plural on purpose

The singular needs an article and the article depends on the first source phrase,
so a singular template produces "a another state's government pension" the first
time a rule leads with a vowel. Arizona's second rule does exactly that. The
plural needs no article and matches the design's own example wording.
`ownStateOrLocal` renders as the jurisdiction's own NAME rather than "this
state", so the sentence still reads correctly for the District of Columbia,
which is not one.

---

## 6. The empty state, and its test

`StateAccuracyContent.noRecordedLimitationsSentence` holds John's wording as a
named constant, so the tests assert against the shipped string rather than a
retyped copy and a reviewer grepping for the sentence finds one definition.

Rendered by `StateAccuracyView.limitationsSection` when `limitations(for:)` is
empty. The view chooses paragraph against list; it does not choose the words.

Four tests, not one:

- `emptyLimitationsDoesNotClaimCompleteness` is the plan's test verbatim: exact
  equality, plus the two negative assertions that the text contains neither
  "no limitations" nor "fully modeled".
- `coveredJurisdictionsWithEmptyListsClaimNothing` is the one the brief insisted
  on and the plan did not have. It sweeps `coveredJurisdictions`, asserts the
  empty sentence for every member shipping no limitation, and pins that the
  members doing so are exactly `["IA", "IN"]`. It also asserts the text does not
  contain "verified", so an empty list can never borrow the verification stamp
  sitting directly above it as a completeness claim. **The literal `["IA", "IN"]`
  is deliberate**: a jurisdiction newly falling to an empty list, whether by a
  correction removing its last sentence or by someone deleting one, fails this
  test and has to be acknowledged.
- `noSummaryAnywhereClaimsCompleteness` sweeps all 51 against five banned
  phrases, including "verified complete" and "no known issues".
- `populatedSummaryCarriesEverySentence` is the mirror image: a jurisdiction with
  limitations must not render the empty state, must carry every sentence, and
  must leak no scope token. A summary that silently dropped a sentence would be
  the same defect as a false empty state, one jurisdiction at a time.

## 7. `taxYear` 0

Thirty-six jurisdictions carry the sentinel. `header(for:)` reads
`statedTaxYear`, never `taxYear`, so the `0` cannot reach a reader as a year.

**No year is invented.** `StateTaxDataLoader` resolved these files out of the
`2026` directory, so printing 2026 would have been easy and would have
manufactured a provenance claim the data never made.
`headerHandlesTheMissingTaxYear` asserts the title contains neither `"0"` nor
`"2026"` for Pennsylvania, which is the assertion that fails if someone later
reaches for the loader's default.

`everyHeaderIsWellFormed` sweeps all 51 and additionally asserts that a
jurisdiction with an empty `lastVerified` never produces a line containing
"verified ", and that one WITH a date never leaks the raw ISO string. Dates are
parsed and formatted through a fixed `en_US_POSIX` locale and a fixed UTC time
zone: a device locale would make the shipped string differ per reader and the
test flaky, and a floating time zone would print a verification date one day
early for every reader west of UTC.

## 8. Notes for Task 7 and Task 8

- Interfaces are shipped under the exact names the brief specified:
  `StateAccuracyContent.Statement` with `label` and `value`,
  `factualStatements(for:filingStatus:)`, `limitationsSummary(for:)`. The last
  takes an additional defaulted `scope:` matching the existing
  `limitations(for:scope:)`.
- Additionally shipped for the page: `StateAccuracyContent.Header`, its nested
  `Header.Source`, and `header(for:)`.
- `StateAccuracyView` takes `state` and `filingStatus` as PARAMETERS and reads
  `DataManager` for nothing. Task 7's three resolvers can be wired straight in.
  The type doc says so, because that is the failure Task 7 exists to prevent.
- Task 8's Gate 3 has something to key on: `exemptionAppliesPerIndividual`
  renders as "the cap applies to each qualifying spouse" and is carried today by
  Georgia and New York only.
- Verified that `StateAccuracyView.o` is built into the app target, rather than
  inferring it from a green suite. The project uses
  `PBXFileSystemSynchronizedRootGroup`, so no `project.pbxproj` edit was needed
  or made.
