# Roth conversion treatment on the per-state accuracy page

**Branch:** `feature/state-accuracy-disclosure`, cut from `feature/state-tax-phase5b`.
**Started at:** `fee5c8f`.
**Scope:** the factual half only. No limitation sentence authored, `knownLimitations` untouched,
`coveredJurisdictions` unchanged.
**Authorised by John, 2026-08-06**, closing the gap raised in `task-5-6-report.md` section 4 and
seconded in `task-7-8-report.md` section 1.

---

## 1. What the four configs actually hold

The brief said four jurisdictions carry a `rothConversionExemption`, and that is correct as the app
resolves configs. **It is not correct of the Swift table**, and the distinction is worth recording
because it decides which specimen proves the JSON is live.

`RothConversionExemption` (`RetireSmartIRA/StateRothConversionExemption.swift`) has exactly two
fields: `minAge: Int` and `withheldPortionRemainsTaxable: Bool`.

| Jurisdiction | `minAge` | `withheldPortionRemainsTaxable` | Where the rule lives |
|---|---|---|---|
| Illinois | 0 | false | JSON `statetax-2026-IL.json` AND inline table `StateTaxData.swift:870` |
| Mississippi | 0 | false | JSON `statetax-2026-MS.json` AND inline table `StateTaxData.swift:1021` |
| Pennsylvania | 0 | **true** | JSON `statetax-2026-PA.json` AND inline table `StateTaxData.swift:1154` |
| Iowa | **55** | false | **JSON `statetax-2026-IA.json` ONLY** |

**They are NOT uniform.** Three distinct shapes across four jurisdictions:

- Illinois and Mississippi exempt the gross conversion with no condition of any kind. IL Pub 120 and
  MS Code 27-7-15(4)(j) per practitioner consensus, per the config comment.
- Pennsylvania exempts it with no age condition, but DOR Ans 274 holds the exemption reaches only the
  amount actually deposited into the Roth, so federal tax withheld out of the conversion stays
  PA-taxable.
- Iowa is the ONLY age-gated one, at 55.

**Iowa's rule exists solely in the bundled JSON.** The inline `configs[.iowa]` at
`StateTaxData.swift:891` carries no `rothConversionExemption` at all. `StateTaxData.config(for:)`
prefers `configs2026` (the JSON loader) and falls back to `configs2026Legacy` only when the loader has
nothing, so Iowa's page states an age gate that the frozen Swift table does not know about. That makes
Iowa a free fallback detector for this statement, the same role Kansas's personal exemption plays for
Task 5's deduction assertions: a run that silently read the legacy table would fail
`eachRothConversionStateRendersItsOwnConfig`, not pass quietly. `StateAccuracyContentTests.swift`
records this in the test's own doc comment.

Because the shapes differ, the renderer composes two independent clauses off the two fields rather
than switching on jurisdiction. Printing Pennsylvania's caveat on an Illinois page would understate an
exemption Illinois grants in full; dropping Iowa's gate would offer a 54 year old an exemption the
engine will not give them. A future config setting both `minAge > 0` and
`withheldPortionRemainsTaxable` renders both clauses with no fifth branch. Nothing ships that
combination today.

---

## 2. Where the statement sits, and why

The fixed order is now:

```
Tax rates
Standard deduction
Personal exemption        (optional)
Social Security
Pension exemption
IRA and 401(k) exemption
Roth conversions          (optional, NEW)
Rules by pension source   (optional)
```

**Directly after "IRA and 401(k) exemption", before the per-source rules.**

The governing argument is not importance, it is contradiction. A Roth conversion IS an IRA
distribution, so the IRA line is the statement a reader will otherwise apply to their conversion, and
in two of the four jurisdictions it says the opposite of the truth. **Iowa is the live proof:** its
page reads

> IRA and 401(k) exemption: None. IRA and 401(k) withdrawals are taxed as ordinary income.

while its conversion is exempt from 55. A reader who stopped at the IRA line would draw exactly the
wrong conclusion about the transaction the app exists to plan. A correction has to be adjacent to the
statement it corrects. This is the same reasoning the code already applies one line up, where
`pensionExemptionDescription` renders `.none` as "No general exemption." rather than a flat "None"
whenever a per-source rule follows and would contradict it.

It goes BEFORE "Rules by pension source" because those rules are about pensions classified by source
and say nothing about conversions, so putting them between the IRA line and its correction would
separate the two by a paragraph about an unrelated question.

**The argument I did not follow.** The brief suggests it may outrank the pension exemption that
precedes it, and for this app's users I agree it is the more decision-relevant fact. I did not hoist
it above the pension line, for two reasons. The section's stated principle, in the
`factualStatements` doc comment and pinned by `statementsKeepTheirOrder`, is the order the tax is
computed in, not a ranking by importance, and reordering on importance would leave the page with no
stated ordering rule at all. And the engine computes this one LAST: `TaxCalculationEngine.swift:868`
applies `rothConversionExemption` after the general exemptions and after the per-source partition, so
computation order argues for putting it last, not first. Placing it beside the IRA line is the
compromise the contradiction argument justifies and computation order tolerates, since it moves the
statement only one position earlier than strict engine order. **If John wants it promoted above the
pension line, that is a one-line change to the array in `statementsKeepTheirOrder` and the append
site, and it is his call, not mine.**

---

## 3. Copy APPROVED by John on 2026-08-06, as written

Shipped in the pattern Tasks 3 and 4 set for the header fallbacks and the caption sentences.
**Both the label and the value template were new user-facing copy; John APPROVED BOTH AS WRITTEN on
2026-08-06.** The alternatives recorded further down are REJECTED, not open. The Pennsylvania value
is the notable one: PA exempts the conversion but NOT the portion withheld for federal tax, and this
page is the only surface in the app that says so.

### Shipped

**Label:** `Roth conversions`

**Value:**

| Config | Rendered |
|---|---|
| IL, MS | `Not taxed by this state.` |
| PA | `Not taxed by this state. Any part of the conversion withheld for federal tax does not reach the Roth account, so that part stays taxable.` |
| IA | `Not taxed by this state from age 55.` |

The leading clause is "Not taxed by this state", **word for word the Social Security statement's
wording**. That is deliberate: two exemptions from the same state's income tax should not read as two
different kinds of thing, and a reader who has already parsed the Social Security line parses this one
without re-reading it.

### Alternatives, for John

**Label.**

1. `Roth conversions` (shipped). Plural, matching "Rules by pension source" and needing no article.
2. `Roth conversion income`. More precise about what is being taxed or not, but longer, and the page's
   other labels name the thing rather than the income from it ("Pension exemption", not "Pension
   income exemption").
3. `Roth conversion exemption`. Parallel to "Pension exemption" and "IRA and 401(k) exemption", which
   is its strongest argument. Rejected because the label would then assert an exemption exists before
   the value says so, and unlike those two the statement is omitted entirely when there is no rule, so
   the parallel is with a statement that can read "None" and this one cannot.

**Value, plain case (IL, MS).**

1. `Not taxed by this state.` (shipped)
2. `Fully exempt.` Matches `pensionExemptionDescription`'s `.full` wording exactly, which is a real
   consistency argument. Rejected as the default because "exempt" invites the question "exempt from
   what", and this line is likelier than any other on the page to be read on its own.
3. `A Roth conversion is not taxed by this state.` Self-contained if the label scrolls out of view.
   Rejected as wordy beside seven sibling values that all omit their subject.

**Value, Pennsylvania's caveat.**

1. `Any part of the conversion withheld for federal tax does not reach the Roth account, so that part
   stays taxable.` (shipped) States the mechanism, which is what makes it actionable: the user can
   avoid the tax by paying the federal bill from outside the conversion, and only the mechanism tells
   them that.
2. `Any amount withheld for federal tax remains taxable.` Shorter, states the rule without the reason.
3. `The exemption covers only the amount actually deposited into the Roth account, so federal tax
   withheld from the conversion stays taxable.` Closest to the Ans 274 language in the config comment.
   Longest of the three.

**Value, Iowa's age gate.**

1. `Not taxed by this state from age 55.` (shipped)
2. `Not taxed by this state. Applies from age 55.` Reuses `ageQualifiers`' existing sentence form,
   which is the consistency argument. Rejected because a two-sentence value for one condition reads as
   two facts, and the first sentence alone is then wrong for anyone under 55.
3. `Not taxed by this state once the owner is 55 or older.` Matches the per-source renderer's
   "once the recipient is N or older". Longer, and "owner" is a term the page uses nowhere else.

**One thing NOT said, deliberately.** The engine gates the age on `effectiveAge`, the household
maximum, not on the converting owner's own age (`TaxCalculationEngine.swift:862` and its comment,
which flags this as undecided pending Iowa's Phase 5a golden scenario). The copy says "from age 55"
and says nothing about whose age. Saying "from age 55" is true for the single filer and for a couple
where the older spouse converts; it is arguably wrong for a couple where a 50 year old converts and a
60 year old spouse pulls the household maximum over the gate. **That is an engine question and a
candidate limitation sentence, both out of this scope.** I have not authored one. Flagging it so it is
not lost: it is a live example of the design's own warning that generated text proves the SOURCE of a
figure, not the engine's use of it.

---

## 4. How the other forty-seven were confirmed to gain nothing

Not by inspection. `onlyTheConfiguredStatesStateARothRule` sweeps all fifty-one jurisdictions and both
filing statuses and asserts **bidirectionally**:

- the set of configs whose `retirementExemptions.rothConversionExemption` is non-nil equals
  `{IA, IL, MS, PA}`, so a fifth jurisdiction gaining a rule fails here rather than passing silently;
- the set of jurisdictions whose PAGE carries a "Roth conversions" label equals that same set, read
  from the live configs rather than compared against a literal.

The second assertion is what makes this a real absent-is-omitted gate: it fails if the page ever
prints a row for a config that does not carry the rule, including an empty one, and it fails if a
config carries a rule the page drops.

Three pre-existing gates also cover the new statement without modification.
`everyJurisdictionProducesCleanStatements` sweeps all fifty-one for empty labels and values, em and en
dashes, doubled spaces and stray whitespace. `statementLabelsAreUniquePerJurisdiction` proves the new
label collides with none of the seven existing ones. `everyHeaderIsWellFormed` is unaffected.

---

## 5. The `.specialLimited` guard

Task 6 found that New Hampshire and Washington configure `pensionExemption: .full` against a system
that taxes none of the income this app models, so rendering that field would have claimed an exemption
from a tax that does not exist. The fix was the `guard config.taxSystem.hasIncomeTax` at the top of
`factualStatements`, which returns a single "Tax rates" statement and stops.

**The Roth statement is appended after that guard and therefore inherits it structurally.** It is not
reachable for `.noIncomeTax` or `.specialLimited`, by construction rather than by convention.

Confirmed rather than assumed, two ways, in
`untaxedJurisdictionsStateNothingAboutRothConversions`:

1. every jurisdiction whose `taxSystem.hasIncomeTax` is false emits no "Roth conversions" label, at
   either filing status;
2. none of the four jurisdictions carrying a rule is an untaxed jurisdiction in the first place, so
   the guard is not silently papering over a config that should not hold the field.

The pre-existing `untaxedJurisdictionsMakeOneStatement` independently pins the count at exactly one
for those jurisdictions, so an added row would fail there too.

---

## 6. The behaviour probe, and the assertion it corrected

`rothConversionStatementsMatchEngineBehaviour` follows the construction of the existing
`socialSecurityStatementsMatchEngineBehaviour` and `perSpouseStatementsMatchEngineBehaviour` probes:
it runs `TaxCalculationEngine.calculateStateTax` directly and asserts the engine does what the
sentence claims.

**My first version of this test asserted the wrong thing and the RED run caught it.** I asserted that
declaring the conversion LOWERS the tax. It does not: the probe puts the conversion into `income`, the
engine subtracts the exempt amount from that same base, and the correct outcome is that the tax is
IDENTICAL to a household with no conversion at all. The RED run reported `declared == undeclared` at
$2,280 for Iowa, $2,970 for Illinois, $2,308 for Mississippi and $1,842 for Pennsylvania, which back
out to a taxable base of exactly $60,000 in every case (Mississippi's $57,700 after its $2,300
standard deduction). Those figures were the exemption working perfectly, and I had written a test that
called it a failure.

The corrected probe takes three measurements per jurisdiction and needs all three. Equality alone
would also hold if the engine ignored the income entirely; inequality alone would also hold if the
exemption were partial.

- **no conversion**, $60,000 of income;
- **the same $200,000 in the base, not declared as a conversion**, the control that proves the income
  was really there to be exempted;
- **the conversion declared**, which must land on the first figure exactly.

Then, per shape: $50,000 of federal withholding moves the tax strictly between the exempt and the
fully taxed figures in Pennsylvania **and only there**, which is precisely what its extra clause
claims and what the other three sentences claim by omitting it; and at age 50 Iowa's tax equals the
fully taxed figure while the other three still equal the exempt figure, which is what "from age 55"
claims and what their silence on age claims.

---

## 7. Deliberately not done

- **No limitation sentence authored**, `knownLimitations` untouched. Two candidates surfaced and both
  are John's to commission: the household-maximum age gate in section 3, and the fact that
  `DataManager.swift:1140` hand-mirrors this exemption for its own breakdown rather than sharing the
  engine's code path.
- **`coveredJurisdictions` unchanged.** Iowa is already covered; Illinois, Mississippi and
  Pennsylvania are not, and their pages still show the "No known limitations are currently recorded"
  empty state. The Roth line is now the most substantive thing on a Pennsylvania page, which is an
  argument for covering Pennsylvania and not something this scope decides.
- **The design doc was not amended.** Its section 1 omission is the root cause of this gap, but the
  document is marked approved 2026-08-05 and editing an approved design is not in scope. Recording it
  here instead.
- No `knownDefect`, no pinned value, nothing under `RetireSmartIRATests/Baselines/`, and no existing
  limitation sentence was touched.

---

## 8. Files changed

- `RetireSmartIRA/StateAccuracyContent.swift`: the optional `Roth conversions` statement in
  `factualStatements(for:filingStatus:)` and the new private `rothConversionDescription(_:)`.
- `RetireSmartIRATests/StateAccuracyContentTests.swift`: five new tests plus the `rothConversionProbe`
  helper, and `statementsKeepTheirOrder`'s fixed-order array extended with the new label. That gate
  had to be extended rather than duplicated: it fails any label outside its array, so the feature
  could not compile past it.

## 9. Test result

```
tools/run-tests.sh
```

Run in the foreground from
`/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-accuracy-disclosure`.

```
Swift Testing:  Test run with 2076 tests in 306 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)

PASS. 2585 test(s) ran, no failures.
```

Baseline at `fee5c8f` was 2,071 Swift Testing in 306 suites plus 509 XCTest. Five tests added, no
suites added, nothing removed. No `MultiYearPerfTests` flake in this run: the wrapper reported a clean
pass and did not enter its re-run path.
