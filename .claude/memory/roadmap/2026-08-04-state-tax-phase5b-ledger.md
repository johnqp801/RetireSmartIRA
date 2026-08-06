# State Tax Phase 5b: the per-source track -- SDD Progress Ledger

Plan: `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md`
Spec: `docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md`
Predecessor ledgers, both durable and both worth reading before starting anything downstream:
  `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md`  (the catalogue and its traps)
  `.claude/memory/roadmap/2026-08-04-state-tax-phase5a-ledger.md` (the corrections method)
Worktree: `.worktrees/state-tax-phase5b`, branch `feature/state-tax-phase5b`
Branch point: `c5a7bce` (the Phase 5a merge). `main` was merged IN at `b0039d3` to pick up the
  test wrapper, so `git merge-base HEAD main` reports `378c110`, not `c5a7bce`. Diff the branch
  with `main...HEAD` (three dots), not `main..HEAD`.
Commit at close: see the final section.

Read this file first if you are picking this program back up. The SDD progress ledger under
`.superpowers/` is GITIGNORED and does not survive; this file and
`.claude/memory/roadmap/2026-08-05-state-tax-phase5b-RESUME-HERE.md` are what remain.

## What Phase 5b was

Phase 4 measured, Phase 5a moved base values (rates, brackets, deductions, exemptions). Phase 5b
is the first phase to attack the RETIREMENT-EXEMPTION tier, where a state's rule depends on WHO
paid the pension rather than only on how much it is. Ten tasks: one model task, one fixture
re-labelling task, seven jurisdiction tasks, and this close. Task 3b was added mid-phase and is
not in the plan.

Nine jurisdictions were in scope. Four of them ship a rule (Kansas, Massachusetts, Arizona,
District of Columbia). Four deliberately ship nothing (Hawaii, North Carolina, Idaho, Vermont),
and those four are results, not shortfalls. New York, the only state that already shipped
`perSourceExemptions`, was the canary throughout.

## THE PROPERTY THAT CHANGED IN THIS PHASE

Phases 1 through 4 each ended with `git diff main -- RetireSmartIRA/` EMPTY. Phase 5a replaced
that with a narrower promise: the production diff stays confined to
`Resources/StateTaxData/2026/` plus documentation, and every moved value carries an attributed
movement-ledger record.

**Phase 5b broke that promise too, and it was the right call each time it broke.** The rule that
replaced it was "every Swift change must be an ADDITIVE model extension, provably inert until a
config opts into it", and Task 1 proved exactly that. It did not survive Task 3, and by Task 9 it
was gone. Fifteen production Swift files and five shipped config files changed. The inventory and
the reasons are in the PRODUCTION DIFF section below, and the plan's own Step 3 expectation
("the Swift diff is confined to the model extension") is stated there as false rather than
massaged.

## Headline counts, DERIVED in this task, not copied from any report

Command, run against the committed branch:

```
grep -c '"knownDefect"' RetireSmartIRATests/GoldenScenarios/*.golden.json \
  | grep -v ':0$' | sed 's#.*/statetax-2026-##; s/\.golden\.json//' | sort
```

and the same command against `c5a7bce` for the baseline. Results:

```
Phase 5a close (c5a7bce):  99 defect cases across 32 jurisdictions
Phase 5b close (HEAD):     88 defect cases across 29 jurisdictions
NET:                      -11 cases, -3 jurisdictions
```

**Gross, which is the number that actually describes the work:**

```
blocks DELETED:  12   AZ 3, DC 3, KS 3, MA 3
blocks ADDED:     1   ID (ID-8, the cap guard the Task 8 review demanded)
net:            -11
```

Golden scenarios overall went from 207 to 219 across the same 50 fixtures: **12 new cases, of
which 11 are guards that carry no `knownDefect` at all** (AZ 4, KS 2, ID 2, DC 1, NC 1, NY 1) and
one is the new Idaho pin. NY-5, the military-retired-pay case, was added by the whole-branch
review and is the only one that pins a CORRECTION rather than guarding an existing answer: it
fails against the pre-review rule at an observed $3,183.00 against its published $487.75. A
jurisdiction that was corrected can therefore show a raw case count that
went UP while its defect count went down; Arizona went from 5 cases to 9 while losing three of
its four defects, and Idaho gained three cases while losing none.

Full per-jurisdiction remaining-defect count at close, parsed from the shipped fixtures:
AL 3, AR 1, AZ 1, CO 1, CT 4, DE 3, HI 3, ID 5, KY 1, LA 3, MD 3, ME 4, MI 2, MN 5, MO 1, NC 3,
NE 4, NM 2, OH 5, OK 1, OR 4, RI 2, SC 4, UT 4, VA 3, VT 6, WA 4, WI 3, WV 3.

DC, Kansas and Massachusetts do not appear because their counts are zero. They join Iowa, Georgia
and Indiana from Phase 5a. **Six of 51 jurisdictions now carry no pinned defect at all.**

The known-but-unpinned catalogue moved further than the pin count did: **1 entry at Phase 5a
close (Missouri), 13 at Phase 5b close** (AZ x2, DC x2, HI, ID, KS, MA x2, MO, NC x2, NY). Twelve
of those thirteen were written by this phase. Read that as the phase's real output as much as the
minus eleven: most of what 5b learned is a defect no fixture can hold.

The last two arrived at the WHOLE-BRANCH REVIEW rather than from a jurisdiction task, which is
itself the finding: both are defects that fell BETWEEN tasks and that no single task's review
could see. New York's is the Railroad Retirement question Task 3's new picker row created; the
District's second is the NON-RESIDENT survivor case, where the toggle that writes the flag is
residence-gated while State Comparison computes DC's column for everybody.

## The four jurisdictions that SHIPPED A RULE, with their authority

### Kansas -- COMPLETE. 3 of 3 remaining defect cases resolved, 0 remain.

Rule: `matchSources` = `ownStateOrLocal`, `federalCivilian`, `uniformedServices`,
`railroadRetirement`; `matchStructures` = `definedBenefit`; treatment `full`. Authority: Kansas
Schedule S Line A14, quoted in the fixture. Measured: KS-4 $1,432.31 to $0.00, KS-5 $1,218.88 to
$0.00, KS-6 $1,218.88 to $0.00. KS-6 was the deliberate COMBINED case and it resolved for the
reason its own summary predicted.

The rule deliberately does NOT match `otherStateOrLocal`, `governmentUnspecified`,
`privateEmployer`, `individual`, `nyStateOrLocal` or `unknown`. That last exclusion is the most
expensive over-match that was available: `unknown` is the migration default on every pre-Task-3b
saved row. Two permanent guards defend the boundary: KS-7 (a Kansas resident holding a CALIFORNIA
public pension, $1,432.31, added in Task 2) and KS-8 (an unestablished-jurisdiction guard, added
in Task 3 because nothing caught `governmentUnspecified`).

### Massachusetts -- 3 of 3 resolved, 0 remain, SHIPPED WITH A DISCLOSED UNDER-TAXATION PATH.

Rule: `matchSources` = `ownStateOrLocal`, `uniformedServices`; `matchStructures` =
`definedBenefit`; treatment `full`. Authority: mass.gov, Tax Treatment of Government Pensions in
Massachusetts, quoted. Re-labels: MA-1 and MA-3 `otherStateOrLocal` to `ownStateOrLocal`, MA-4
`federalCivilian` to `uniformedServices`, each confirmed against that case's own quoted source.

**The cost of shipping was disclosed, not discovered.** Massachusetts conditions the exclusion on
the plan being CONTRIBUTORY and the model has no contributory axis, so a noncontributory
municipal retiree who picks the own-state picker row now gets $0.00 instead of $3,000.00. That is
UNDER-taxation and it is reachable by a real user. John decided on 2026-08-05 to SHIP rather than
take the reversal: the three fixes rest on quoted affirmative statute, the new gap rests on a
closed-list inference the fixture itself flags as not verbatim, and reverting would over-tax the
large majority to protect a small legacy category. Section 13 of the Task 4 report keeps a
complete six-item reversal recipe as the record of what shipping cost.

MA-2 was renamed rather than re-scoped: `governmentUnspecified` means "a government employer
whose jurisdiction was not established", per its own doc comment, and never meant
"noncontributory". Do not reuse it as a funding marker.

### Arizona -- 3 of 4 resolved. AZ-4 stays pinned, deliberately.

Two rules: `uniformedServices` at `definedBenefit`, treatment `full` (Form 140 Line 29b); and a
DENIAL rule (`privateEmployer`, `otherStateOrLocal`, `nyStateOrLocal` at both structures,
treatment `none`) that keeps non-qualifying sources OUT of the pooled `pensionExemption`, which
is where the $2,500 Line 29a cap lives. Measured: $396.25, $0.00, $1,453.75. Four guard cases
were added including the ABOVE-CAP case Phase 4 said was missing.

**AZ-4 stays pinned and that is the correct outcome.** `exemptionAppliesPerIndividual: true`
would turn it green while granting $5,000 to an MFJ household where only ONE spouse holds the
qualifying pension: the flag doubles on the AGE gate, Arizona conditions doubling on each spouse
RECEIVING qualifying income. The trade is $37.50 of over-taxation against $62.50 of
under-taxation, and a new golden case pins it, so flipping the flag turns AZ-4 green and that
case red. AZ-4 also cannot be pinned against a correct engine at all, because the fixture schema
has NO OWNER FIELD and its two rows are one taxpayer's two pensions.

**Arizona is the first non-New-York config to name a jurisdiction-specific source.** It works
only because a Task 3 review changed `jurisdictionNamedSources` from a `Set` to a
`[PlanSource: USState]` compared against the residence state. Under the old shape, Arizona
residents would have had the own-state picker row suppressed and Line 29a would be unreachable
for an ASRS retiree.

### District of Columbia -- 3 of 3 resolved, 0 remain. The phase's largest production change.

Rule: `matchSources` = `federalCivilian`, `ownStateOrLocal`; `matchStructures` = `definedBenefit`;
`matchIsSurvivorBenefit: true`; `matchMinAge: 62`; treatment `full`. Authority: D.C. Code Section
47-1803.02(a)(2)(N)(ii). Measured: DC-2 $1,924.00 to $0.00, DC-3 $1,546.00 to $0.00, DC-4
$3,848.50 to $1,846.00. DC-1 and DC-5 never moved. DC-6, the Maryland survivor annuity a Task 2
reviewer said Task 9 owed DC, was added deliberately one enum case away from DC-2.

**`matchMinAge` had to be built and the brief's dependency chain did not say so.** The per-source
partition is unconditional on age, so DC-1 (a survivor at 55) fails without an age gate, and
`perQualifyingSpouse` cannot substitute because `ownerQualifies` returns true unconditionally for
a single filer. `matchMinAge` gates on the ROW OWNER's age, not the household maximum, which is
why it later removed one of Idaho's three objections as well.

**A deviation worth keeping:** no field was added to `IRAAccount`, against the brief. Nothing in
production constructs a `RetirementDistributionComponent` from an account, `IRAAccount` already
carries `beneficiaryType`, DC's rule is `definedBenefit`-only, and an unreachable PERSISTED field
is dead data in every user's save file, which "provably inert until a config opts in" cannot
cover. The field went on `RetirementDistributionComponent`, which is in-memory.

## The four jurisdictions that SHIP NOTHING, and why each is a decision

None of these is pending work. Each was measured rather than argued, each has a reviewed
decision, each keeps ALL of its `knownDefect` blocks, and each carries guard cases where guards
were expressible, a `knownButUnpinned` entry with a deletion guard, and a caption. **The common
finding across all four: the green outcome was available in every case and it was wrong in the
UNDER-taxation direction.**

### Hawaii -- ships no rule. Three defects stay. The method the later three copied.

The implementer temporarily shipped the declined rule (`matchStructures: ["definedBenefit"]`,
empty `matchSources`), watched HI-1, HI-3 and HI-4 all go green at their published figures with
NO fixture objecting, observed that the same rule grants a full Hawaii exclusion to every
contributory defined-benefit pension, and reverted. The reviewer reproduced the arithmetic
independently ($266.00 and $2,107.20 both exact) and confirmed the revert was complete.

Schedule J's authorising sentence contains the word "only" ("applies only to amounts attributable
to employer contributions"), so the grant and the limiter come out of THE SAME quoted sentence.
Massachusetts had an evidentiary asymmetry to trade on; Hawaii has none. Direction settles it:
today's error is OVER-taxation, disclosed on two surfaces; the rule would have converted it into
UNDISCLOSED UNDER-taxation at up to 11% for the LARGER population.

Step 3 of the plan ("if the fixture set has no case that would catch that, ADD one") is
PROCEDURALLY UNSATISFIABLE here: a contributory private-sector DB household writes
`(definedBenefit, privateEmployer)`, byte-identical to HI-1, with a contradictory expected value.

### North Carolina -- ships no Bailey rule. Three defects stay.

Same method. A rule of `["ownStateOrLocal", "federalCivilian"]` at `definedBenefit`, treatment
`full`, was temporarily shipped and turned all three defect cases green ($0.00, $0.00, $379.05)
with the only guard raising no objection. Reverted.

NCDOR's sentence grants the exclusion and limits it in the same clause ("if the retiree had five
or more years of creditable service as of August 12, 1989"), which is exactly what "only" does in
Hawaii's. **The class is CLOSED and can only shrink; its complement can only grow.** To have
entered NC public service by August 1984 a person must be at least 60 in 2026. Every NC public
employee retiring today, and in every future year, is outside it. NC-5 was added as the only
guard North Carolina can carry: it is the only VESTING-INDEPENDENT one.

North Carolina is the ONE place weaker than Hawaii, recorded because it cuts against the decision
rather than for it: Hawaii's over-taxation is disclosed on two surfaces, North Carolina's was
disclosed nowhere. A Bailey-vested retiree is over-taxed $1,486.27 a year at NC-1's shape. Task 7
shipped a caption; the structural answer is a Phase 6 disclosure item.

### Idaho -- ships no rule. Four defects stay and a fifth was ADDED.

Two conditions, neither expressible: the civilian grant requires eligibility established before
1984 (FERS is a different system and is not on the list, and one picker row writes both), and the
own-state grant covers PERSI FIREFIGHTERS and certain POLICE, not PERSI generally.

**Idaho is the one jurisdiction where the decline was a JUDGEMENT CALL rather than a procedural
foreclosure, and the catalogue entry originally got that wrong.** For `federalCivilian` and
`ownStateOrLocal` no catching case is pinnable, so shipping is foreclosed. For `uniformedServices`
alone a rule IS expressible: routed through the pooled cap in Arizona's shipped shape, or after
Task 9, as `matchSources: ["uniformedServices"]`, `matchMinAge: 62`, treatment `full`. Both were
MEASURED: ID-3 goes green and nothing else moves.

It was declined anyway, on the ONE objection that survived Task 9. Form 39R Line 8a reduces the
maximum DOLLAR-FOR-DOLLAR by Social Security and Railroad Retirement RECEIVED, and nothing in the
model carries that. A single military retiree at 65 with a $60,000 pension and $30,000 of Social
Security has a real Idaho maximum of $18,216, not $48,216: roughly $935 a year of UNDISCLOSED
UNDER-taxation, in the COMMON case rather than an edge case. `treatment: full` is also uncapped,
and a capped per-source treatment is banned phase-wide. Both of those ARE pinnable, so a future
task may legitimately reach a different conclusion, and it should do so by pinning them first.

**Task 8's reflective tripwire fired on Task 9's first full-suite run, exactly as designed**, and
re-opened Idaho legitimately because `matchMinAge` changed the facts. Two of the three objections
died there (the age gate, and household attribution, since `matchMinAge` is per owner). ID-8 (MFJ
68/70, $140,000 of CSRS, expected $1,069.33, observed $4,902.50) was added by the Task 8 review as
the cap guard, because every other Idaho case floors taxable income at $0.00 whether the deduction
is capped or not, so an UNCAPPED rule would have passed all of them.

### Vermont -- ships no rule. All six defects stay. THIS IS THE PHASE'S MOST IMPORTANT FINDING.

**Task 1's extension dissolved exactly the source collision it was built for, and Vermont is
STILL unsatisfiable, because the binding constraint was never sources.**

Phase 4 recorded Vermont as unsatisfiable because its military and CSRS cases both had to be
labelled `federalCivilian`. Task 2 re-labelled VT-5 and VT-6 to `uniformedServices` from their own
Act 71 citations. The collision is genuinely gone. Vermont did not move.

What actually blocks it:
- Vermont needs TWO exclusions with DIFFERENT CAPS and DIFFERENT AGI BANDS, and a jurisdiction
  carries one pooled cap and one `agiPhaseout`.
- Its CSRS exclusion applies "only to benefits not covered by the Social Security Act", which
  `federalCivilian` cannot express, because that one case covers CSRS AND FERS.

**Task 1 extended the WHO axis. Vermont's remainder lives on the HOW MUCH and WHEN axes.** That is
the sentence to carry forward: a model extension that dissolves a collision does not thereby make
a jurisdiction expressible, and Vermont is the proof.

Both shapes were measured with Hawaii's method and both reverted. The config-only CSRS shape
(pooled `.partial(10000)` plus a linear `agiPhaseout` plus two `.none` rules) turned VT-1 through
VT-4 ALL GREEN at 742.03 / 1579.53 / 1316.55 / 981.55. Declined on Hawaii's test. The military
`.full` rule turned VT-5 green and moved VT-6 off its pin to $0.00; **VT-6 caught it exactly as
the brief predicted it would.**

Vermont carries the single largest dollar gap measured in this phase: $5,211.50 a year at VT-6's
shape ($8,086.65 observed against $2,875.15 expected).

**A THIRD shape exists, is recommended to John, and was not built.** An income-gated military rule
(`matchMaxIncome`, a sibling of `matchMinAge`) implements Act 71's quoted $125,000 sentence
exactly: VT-5 green, VT-6 correctly still pinned, no under-taxation anywhere, worth $4,525.15 a
year. It was not built because the gate would compare against the post-state-deduction income
figure, so Vermont's config would carry $117,150 where Act 71 says $125,000, and **no Vermont
fixture pins the basis** (VT-5 and VT-6 fall the same side under both readings). That is a
program-level decision `AGIPhaseout`'s own doc comment already defers, not a jurisdiction one. The
fixture that would pin it is a VT-7 at AGI $130,000, expected **$172.53**.

## THE KANSAS PROMISE, stated as precisely as it can honestly be stated

Kansas had two defects. Phase 5a fixed the personal exemption. Phase 5b Task 3 fixed the
retirement exclusion. **Kansas is complete in the engine AND selectable in the app**, and the
second half of that was never true before Task 3 added the picker rows. Kansas carries zero
pinned defect cases and two permanent guards. Steve Nicolai's report is fully addressed.

Two caveats, and neither touches a Kansas KPERS holder who classifies their pension, which is the
reported case, so the claim is sound FOR THAT USER:

1. **Schedule S Line A14 also names Thrift Savings Plans**, which are defined-contribution, and
   the rule matches `definedBenefit` only, so a Kansas TSP holder is still taxed in full. Recorded
   in `knownButUnpinned`. The constraint is deliberate and is the safer error: Line A14 names
   "KPERS ANNUITIES", not the separate KPERS 457 plan, so dropping the structure constraint would
   simultaneously grant an unauthorised full exclusion to every government salary-reduction plan.
   It also cannot be pinned, because `PlanClassificationChoice` has no row writing a federal
   defined-contribution plan, so no user can classify one.
2. **`ownStateOrLocal` goes STALE ON A RESIDENCE CHANGE and errs toward UNDER-taxation.** Task 3
   closed the COMPARING route (State Comparison) and NOT the MOVING route, and its commit message
   says so. A Vermont user who classifies VSERS as own-state and later changes residence to Kansas
   collects Kansas's full exclusion on a Vermont pension.

An earlier caveat is CLOSED: an unclassified Kansas pension used to get no warning while an
identically-placed New York user was warned on two surfaces. Task 3b fixed that.

## PRODUCTION DIFF: the plan's confinement expectation, and why it did not hold

The plan's Step 3 asked this task to "show that the Swift diff is confined to the model extension
and that no engine logic changed beyond consuming new fields." **Both halves are false.** What
follows is the inventory, verified against `git diff main...HEAD -- RetireSmartIRA/`.

**20 production files: 15 Swift, 5 shipped JSON configs.**

Additive model extension, the part the plan did anticipate:

| File | What changed |
|---|---|
| `RetirementPlanClassification.swift` | Task 1: three new `PlanSource` cases (`ownStateOrLocal`, `uniformedServices`, `railroadRetirement`) plus `isSurvivorBenefit: Bool?`. Task 3b: a new `UnclassifiedPensionDisclosure` enum with a `Scope` and a `{scope}` token. |
| `PerSourceExemptionRule.swift` | Task 9: two NEW MATCHING DIMENSIONS, `matchIsSurvivorBenefit` and `matchMinAge`, and `matches()` widened by two defaulted parameters. This is new matching behaviour, not a passive field. |
| `IncomeModels.swift` | Task 9: `IncomeSource.isSurvivorBenefit: Bool?`, added to `CodingKeys`. A PERSISTED user-data field. |
| `RetirementDistributionComponent.swift` | Task 9: the same flag on the in-memory component. |
| `StateTaxData.swift` | Task 3b: `unclassifiedPensionDisclosure: String?` on `RetirementIncomeExemptions`. Task 9: `matchedPerSourceRule` widened by survivor and age. |
| `StateTaxCodable.swift` | Task 3b: encode/decode for that string, `encodeIfPresent` so the other 49 files stay byte-identical. |

New matching behaviour reaching the engines, which the plan did NOT anticipate:

| File | What changed |
|---|---|
| `TaxCalculationEngine.swift` | Task 9: an `ageOf(_:)` owner-age resolver and a `componentRule(_:)` helper replacing two inline filters, so the survivor flag and the owner's age reach rule matching. |
| `DataManager.swift` | Task 9: the same two, in the breakdown mirror. Task 3: `incomeSources(asResidentOf:)`, a residence remapping now applied to pension and RMD rows, which is a suppression predicate rather than a field read. |
| `MultiYearInputAdapter.swift` | Task 9 review: the survivor flag travels with the pooled classification, with a deliberate disagreement-falls-back-to-nil rule. Without it, single-year and Multi-Year disagreed for the same DC household. |
| `ProjectionEngine.swift` | Task 9 review: the flag forwarded into each projected year's components. |

User-facing, which the plan did not anticipate at all:

| File | What changed |
|---|---|
| `IncomeSourcesView.swift` (+447) | Task 3: three new picker rows and the `options(for:selected:)` suppression plus `jurisdictionNamedSources`. Task 9: `residenceUsesSurvivorDimension`, the survivor toggle and its caption. Tasks 7, 8, 9: the North Carolina, Idaho and Vermont captions (Massachusetts's and Hawaii's are inline). |
| `AccountsView.swift` | Task 3: the account picker uses the same suppression. |
| `StateComparisonView.swift` | Task 3b: the unclassified-pension banner stops hardcoding New York and reads the VIEWED state's config. |
| `MultiYearCPABriefing.swift` | Task 3b: the same for the briefing, gating on RESIDENCE. The asymmetry with State Comparison is deliberate and is now structural. |
| `MultiYearPlanView.swift` | Task 3b: the call site. |

Shipped config: `statetax-2026-KS.json`, `-MA.json`, `-AZ.json`, `-DC.json` each gain
`perSourceExemptions` and an `unclassifiedPensionDisclosure` sentence; `-NY.json` gains the
sentence, hoisted out of Swift so New York stops being special-cased, and then, at the
whole-branch review, `uniformedServices` on its existing rule. New York's live copy was proven
byte-identical by extraction from the parent commit and full `==`, then proven capable of failing
by a reverted one-space mutation.

**NEW YORK'S RULE CHANGED AT THE CLOSE, and the reason is the most important single finding of
the whole-branch review.** Task 3 added the "Military retired pay" picker row to EVERY
jurisdiction. New York's rule named `nyStateOrLocal` and `federalCivilian` only, so before Task 3
a New York military retiree's best available pick was "Government pension, federal civilian",
which matched, and the uncapped Line 26 exclusion applied BY ACCIDENT. After Task 3 the honest
pick wrote `uniformedServices`, matched nothing, and fell back to the CAPPED $20,000 Line 29
exclusion. The cost depends on the household's other income, so it is stated at two shapes rather
than as one round number: a single filer at 65 whose ONLY income is a $60,000 military pension
paid $1,563.00 and now pays $0.00; at NY-5's shape ($70,000 pension plus $20,000 of other
ordinary income) it is $3,183.00 against $487.75, a delta of $2,695.25. Both are pinned by
`Phase5bNewYorkMilitaryTests`. Two taps away either way, on the canary jurisdiction.

**A correction worth carrying as a method note.** An earlier draft of this paragraph, of the
shipped comment in `StateTaxData.swift` and of NY-5's own `source` string all said "roughly $2,200
a year on a $60,000 pension". That figure does not reproduce from the inputs beside it: it holds
only with $20,000 of unstated other income pushing the uncapped slice into the 5.4% band. Nothing
asserted on it and every load-bearing figure was exact, so it was narrative imprecision, but it
sat in derivation-grade surroundings where a reader is entitled to assume every number reproduces.
An independent verifier caught it after the figure had already been repeated to John. **A dollar
figure in a fixture, a config comment or this ledger must be re-derivable from the inputs stated
next to it, or it must name the shape it belongs to.**
Every New York golden case stayed green, because none carried such a row. **The branch replaced a
right-by-accident answer with a wrong one and nothing recorded it.**

The rule was WIDENED rather than the picker row suppressed. Widening is correct law by the
authority NY-1 already quotes (Line 26 reaches "an officer, employee, or beneficiary of an officer
or employee of ... the United States", and a retired service member is one), so it needed no
research Step 1 forbids; it also closes the type-versus-source divergence, since
`MilitaryRetirementExemption.exemption(for: "NY")` already returned `.fullyExempt`. Suppression
would have required a New-York-specific hardcode in the file Task 3b spent a task de-special-casing
and would have left the user describing military retired pay as a federal civilian pension, which
is a landmine in the five states that treat the two differently.

**Layer B was handled by MIRRORING into `configs2026Legacy`, per Task 3b's precedent**, not by
adding New York to `phase5CorrectedJurisdictions`. Membership FLIPS `structurallyIdentical` into a
must-diverge assertion and would permanently excuse the canary from the byte-identity check that
has guarded it since Phase 1. Mirroring also keeps the load-failure fallback correct, which matters
more for a rule than for a disclosure string: a user on that path would otherwise be over-taxed
rather than merely unwarned. Railroad Retirement was deliberately NOT widened alongside it and is
recorded in `knownButUnpinned` instead; New York's fixture cites no provision covering it, and the
quoted Line 26 list argues against folding it in, because a railroad retiree was an employee of a
private carrier rather than of the United States.

**Why the expectation failed, in three steps.** (1) Task 3: a controller audit before dispatch
found `PlanClassificationChoice`, the enum driving the user-facing picker, is SEPARATE from
`PlanSource` and had no option writing any of Task 1's three new cases. A correct Kansas rule
would have turned every golden case green while a real KPERS holder got nothing. John chose to add
all three rows once so Tasks 4, 6, 8 and 9 would inherit them. (2) Task 3b was not in the plan at
all: it exists because Kansas shipped a correct rule and got neither the classification prompt nor
the disclosure New York got, and fixing that meant touching two view layers. (3) Task 9: DC's rule
is the first whose discriminant is not fully described by `(structure, source)`, so the survivor
dimension had to be threaded from `IncomeSource` through `matches()`, `DataManager`, the engine,
the multi-year adapter and the projection engine, plus a picker toggle, plus a whole new
`matchMinAge` dimension the brief's chain omitted.

The narrower claim that IS true and worth keeping: **no jurisdiction's numbers move without a
config opting in.** Task 1 proved inertness with New York as the canary and 20 exclusivity tests
proving both directions for every new-versus-old `PlanSource` pair. Every subsequent numeric
movement is attributable to one of the four shipped `perSourceExemptions` blocks.

## NOTHING AWAITS JOHN. Every item in this phase is settled.

**ALL PHASE 5b COPY IS APPROVED.** Task 3's three picker labels, the Massachusetts, Hawaii, North
Carolina and Idaho captions and disclosure sentences, and, **approved by John on 2026-08-05 as
written**, Task 9's three: DC's `unclassifiedPensionDisclosure` sentence in `statetax-2026-DC.json`,
DC's survivor toggle label and its explanatory caption, and Vermont's caption, both in
`IncomeSourcesView.swift`. The "PROPOSED COPY, AWAITING JOHN" markers are cleared from the tree. The
alternatives drafted and rejected for each stay in Task 9 report section 6 as the record of what was
considered, retitled so no later reader mistakes them for open options.

**AND THE LAST JUDGEMENT CALL IS DECIDED.**

**DECIDED BY JOHN ON 2026-08-05: HOLD. Vermont ships no rule.** The recommendation was unanimous
(implementer, reviewer, controller) and John accepted it. Vermont keeps all six `knownDefect` blocks
BY DECISION rather than by default, alongside Hawaii, North Carolina and Idaho.

The rejected shape is the config-only CSRS one: four cases green, roughly $335 of bounded
over-match, but it over-exempts FERS retirees, a GROWING population, to serve CSRS retirees, a class
CLOSED SINCE 1984. That is the same population logic that decided North Carolina.

The preferred fix is DEFERRED, not abandoned: an income-gated military rule implementing Act 71's
quoted $125,000 sentence corrects $4,525.15 a year with NO under-taxation anywhere. It is blocked on
which income basis the gate compares against, a program-level decision no Vermont fixture pins.
**If it is ever built, VT-7 goes in FIRST: AGI $130,000, expected $172.53.** It is the only case
that discriminates the two readings, and a reviewer confirmed it yields three distinct values.

Vermont still holds the largest single dollar gap in the phase, $5,211.50 a year at VT-6's shape.
That is a KNOWN, DISCLOSED COST OF THE HOLD, carried by the caption and by the six pinned blocks,
not an oversight.

**So the count of items awaiting John is ZERO.** A reader arriving here does not need to work that
out from a list; there is no list.

## WHAT THE NEXT PHASE INHERITS, ORGANISED BY MISSING MODEL FIELD

This is the axis the plan asked for and the phase produced a clean list. Each item names the
jurisdictions blocked on it and what would resolve it.

### 1. An employee-contributory axis. Blocks Massachusetts and Hawaii. ASSIGNED TO PHASE 6 by John, 2026-08-05.

**Massachusetts needs it CATEGORICAL. Hawaii needs it a PROPORTION.** A boolean serves
Massachusetts exactly and serves Hawaii only at its two endpoints, silently wrong for every
partially employer-funded plan in between, which is most of them. That is the finding: design it
against both, in a model task, per this phase's own precedent that a shared classification axis
lands in the model task (`isSurvivorBenefit`, Task 1) and is consumed by jurisdiction tasks.

**Do not read the catalogue as saying Hawaii's proportion is unvalidatable.** A golden fixture
COULD stipulate the employer-funded share as an INPUT, exactly as it carries `amount`, and the
correct expected tax would follow from Schedule J arithmetically. The real obstacles are three: a
FIELD on the classification, a PICKER AFFORDANCE, and an answer to whether a real user CAN supply
a share Schedule J makes them compute from cost basis.

Two fixtures on this branch assign OPPOSITE funding semantics to `PlanStructure.definedBenefit`
(HI-1 says noncontributory, MA-1 says the contributory Commonwealth pension) and the enum's own
doc comment takes neither side. That is a missing dimension, not a quirk.

### 2. A vesting-date or Bailey-class fact. Blocks North Carolina.

Judged BUILDABLE and declined, which is the distinction to preserve. It is a boolean, a fixture
could carry it as an input, and an entitled retiree already claims it on Form D-400 Schedule S
Line 20, so many users can answer it from their own return. It is NOT a date axis despite the
plan's framing: "five or more years of creditable service as of August 12, 1989" is a
service-credit computation, not a date a user holds, so the honest picker question is a
Bailey-membership boolean.

Weigh before building: it serves ONE jurisdiction and one cohort whose correct-answer population
declines monotonically to zero, while becoming a permanent field in stored user data that cannot
be removed without a migration. A user who guesses wrong moves their own tax by 3.99% of the
pension with nothing to cross-check them.

### 3. An eligibility fact, plus a second age gate over one shared cap. Blocks Idaho.

Two facts for branch 1: pre-1984 CSRS eligibility, and police-or-firefighter service within a
state system. For branch 2 (`uniformedServices`), two different things: a BENEFITS-RECEIVED OFFSET
on the pooled cap (Social Security and Railroad Retirement, dollar for dollar, Form 39R Line 8a)
and a HOUSEHOLD-level cap a per-source rule can carry.

**Half of the earlier ask is already done.** Task 9 shipped `matchMinAge`, which is the per-source
age gate this entry used to request, and it is evaluated per ROW OWNER, which also killed the
household-attribution objection. Do not re-request either.

### 4. A second capped pool and a second AGI phase-out band. Blocks Vermont.

A jurisdiction carries one pooled cap and one `agiPhaseout`; Vermont needs two of each. Plus a
`matchMaxIncome` sibling of `matchMinAge`. Plus a decision, which is program-level and not
Vermont's, about WHICH INCOME BASIS the gate compares against: no Vermont fixture pins it, and a
config would carry $117,150 where Act 71 says $125,000. **VT-7 at AGI $130,000, expected $172.53,
is the fixture that would pin it. Write it first.** Also a way to say "not covered by the Social
Security Act", which `federalCivilian` cannot, because that case covers CSRS and FERS.

### 5. Per-taxpayer exemption attribution. Blocks Arizona's AZ-4.

`exemptionAppliesPerIndividual` doubles on the AGE gate; Arizona conditions doubling on each
spouse RECEIVING qualifying income. Also unpinnable for a second, independent reason: the fixture
schema has NO OWNER FIELD, so AZ-4's two rows are one taxpayer's two pensions.

### 6. Residence-relative source labels. Affects every jurisdiction naming `ownStateOrLocal`.

`PlanSource.ownStateOrLocal` carries no jurisdiction identity, so a pension classified own-state
in one state KEEPS that label after a move, and the error runs toward UNDER-taxation. Task 3
closed the comparing route and not the moving route. Kansas, Massachusetts and DC all ship rules
naming it today, so its reach grows with every jurisdiction added. Closing it needs a new STORED
field. **This is the most important open question left on the branch.**

### 7. A structural fix for the capped per-source treatment.

`PerSourceExemptionRule.treatment` is evaluated INSIDE the per-row loop
(`TaxCalculationEngine.swift`, `DataManager.swift`), so a `.partial` treatment caps PER PENSION
ROW rather than per household, and this codebase HAS SHIPPED THAT BUG ONCE, in New York's $20,000
exclusion. A sweep now asserts no shipped rule in any of the 51 configs carries a capped
treatment, but **`treatment` is still typed as the full `ExemptionLevel`, so the ban is a test
guard and not a structural guarantee.** The durable fix is a narrower treatment type, or grouping
matched rows by rule and applying the treatment once per rule. The workaround that ships today
(route the cap through the pooled `pensionExemption`, use per-source rules only to keep
non-qualifying sources out of the pool) generalises ONLY to a jurisdiction with exactly one capped
pool, which is why it does not reach Vermont.

### 8. One fact with two encodings. `IncomeType.militaryRetirement` and `PlanSource.uniformedServices`.

North Carolina's military retired pay has TWO PATHS WITH OPPOSITE ANSWERS, reachable by a real
user today, and it predates this phase. By income type, `MilitaryRetirementExemption` returns
`.fullyExempt` for NC and the UI renders a green "fully exempt" badge. By classification, the
Task 3 picker row writes `(definedBenefit, uniformedServices)` onto a `.pension` row, North
Carolina ships no rule, and the money is taxed in full: $1,486.27 measured. The two loops are
disjoint, so there is no double exclusion and no arithmetic bug; the defect is that the ANSWER
DEPENDS ON WHICH SCREEN the money was entered from. Arizona had the same divergence and it
happened to resolve when Arizona's `uniformedServices` rule made the two paths agree. The
structural fix is that one of the two encodings should be derived from the other.

## THE DISCLOSURE FINDING, which is structural and not any one jurisdiction's

Phase 5b produced a category that did not exist when the disclosure surfaces were designed: **a
jurisdiction with a real golden fixture, defects measured and pinned, and `perSourceExemptions`
deliberately EMPTY.** Three surfaces all gate on something that category fails:

- `PlanClassificationChoice.shouldPromptForClassification` gates on `residenceHasPerSourceRules`,
  so the prompt never fires.
- `UnclassifiedPensionDisclosure.text(for:scope:)` gates on a config sentence that is in
  BIDIRECTIONAL LOCKSTEP with the rules, so it cannot exist without them.
- `GoldenScenarioCoverageTests.cannotVerify` gates on having NO fixture, and these have good ones.

**The gate is "did this state ship rules", and the answer that needs disclosing most is "no,
deliberately, because we could not."** That is backwards. Four jurisdictions are now in the
category: Hawaii, North Carolina, Idaho and Vermont. The standing note is
`.claude/memory/roadmap/2026-08-05-disclosure-surfaces-miss-the-no-rule-case.md`; it was written
at Task 8 and lists three, and Vermont joined at Task 9.

Two further gaps in the same area:
- **`knownButUnpinned` has NO production consumer at all.** Eleven entries, and nothing outside
  the test target reads any of them. No user and no CPA briefing is told anything they contain.
- **The captions render only inside the pension EDIT sheet.** A user who entered a pension and
  then moved, or who simply never reopens the row, never sees one. The CPA briefing carries no
  line for any of them.

A related gap has a sharper edge, and it is DC's: a DC survivor whose row predates Task 9 carries
`nil`, gets no exclusion, and gets NO WARNING, because both disclosure surfaces gate on the
pension being UNCLASSIFIED and this one is perfectly classified. The trigger is not a missing
answer to a question the user was asked; it is a question that did not exist when they answered.

## ARTIFACTS THAT MUST NOT BE RETIRED

These are what make four no-rule decisions and several disclosed gaps defensible rather than
silent. Deleting any of them converts a disclosed tradeoff into an undisclosed defect.

- **`Phase5bUnclassifiedPensionDisclosureTests.rulesAndDisclosuresStayInLockstep`.** It is the
  only thing binding the disclosure gate to the rules gate. Removing it silently reopens the
  Kansas defect for every jurisdiction added after it. A reviewer confirmed it genuinely fires.
- **All THIRTEEN `knownButUnpinned` entries and their deletion guards**, in
  `Phase5bArizonaPerSourceTests`, `Phase5bKansasPerSourceTests`,
  `Phase5bMassachusettsPerSourceTests`, `Phase5bHawaiiDecisionTests`,
  `Phase5bNorthCarolinaDecisionTests`, `Phase5bIdahoDecisionTests`, `Phase5bDCSurvivorTests`,
  `Phase5bNewYorkMilitaryTests` and, for Missouri alone, `GoldenScenarioDefectCatalogueTests`
  itself. DC's two guards are both explicitly non-vacuous.

  **CORRECTED BY THE WHOLE-BRANCH REVIEW, 2026-08-05.** This entry previously said "all eleven"
  and named `Phase5bKansasPerSourceTests` among the files holding guards. Both halves were
  false, and this was the one document the next phase acts on. THREE of the eleven had NO
  deletion guard at all: Kansas's TSP entry (that file contained no reference to the catalogue),
  the Massachusetts FEDERAL-CIVILIAN entry (the only Massachusetts guard selects on
  `summary.contains("NONCONTRIBUTORY")`, so it guards the OTHER Massachusetts entry), and
  Missouri's, inherited from Phase 5a and never given one.
  `knownButUnpinnedIsWellFormed` asserts only that the array is non-empty and that each entry's
  two strings are non-blank, so all three deleted in silence. The three guards were added, and
  the count is now thirteen because the review also added two entries: New York's Railroad
  Retirement question and the District's NON-RESIDENT survivor case. Missouri's guard lives in
  the catalogue file for want of a Missouri suite; move it the moment one exists.
- **The four captions** (Hawaii, Massachusetts, North Carolina, Idaho) plus Vermont's and DC's
  proposed ones. For Hawaii, North Carolina, Idaho and Vermont the caption is the ONLY surface
  that reaches the affected user at all.
- **Idaho's reflective tripwire** in `Phase5bIdahoDecisionTests`, which re-opens Idaho if a second
  pooled cap, a phase-out or a new matching dimension ever arrives. It has already earned its keep
  once, firing on Task 9's first full-suite run.
- **Vermont's equivalent** in `Phase5bVermontDecisionTests`, and the two the whole-branch review
  added to `Phase5bHawaiiDecisionTests` and `Phase5bNorthCarolinaDecisionTests`. Those two
  jurisdictions previously carried only `PlanSource.allCases` sweeps plus, for Hawaii, a
  reflection over `RetirementPlanClassification`'s encoded keys. Neither fires on a new MATCHING
  DIMENSION arriving on `PerSourceExemptionRule`, which is how `matchIsSurvivorBenefit` and
  `matchMinAge` actually arrived in Task 9 and how Idaho was legitimately re-opened. All four
  no-rule decisions now carry the same tripwire shape.
- **The frozen 1,020-value baseline.** Untouched by this phase, INCLUDING by the whole-branch
  review's New York correction. The baseline grid builds its pension rows with no classification,
  so they infer `(unknown, unknown)`, and widening `matchSources` cannot match `.unknown`. The
  movement ledger is still empty of New York entries and this phase still records zero baseline
  movements.

## Method findings worth carrying

- **Measure the declined rule, do not argue it.** Hawaii established the method and North
  Carolina, Idaho and Vermont each repeated it: temporarily ship the rule you are about to
  decline, record which cases go green and at what figures, note which fixture objects (usually
  none), then revert. In all four the green outcome was AVAILABLE. A suite that goes green is not
  evidence a rule is right.
- **Direction decides.** Over-taxation that is disclosed beats under-taxation that is not, every
  time, and the comparison is between POPULATIONS rather than between dollar figures. Hawaii, NC
  and Idaho all turn on a served cohort that is closed or shrinking against an over-matched cohort
  that is open and growing.
- **A green outcome and a reachable feature are different things.** Task 3's controller audit is
  the case: a correct Kansas rule would have passed every golden case while a real KPERS holder
  got nothing, because the picker could not write the classification. Every later jurisdiction
  task inherited the fix. **Check the affordance before believing the fixtures.**
- **Coverage can be written to the implementation's shape.** Seven tests covered the two
  disclosure surfaces and all seven PASSED while Kansas got no warning, because each asserted only
  "New York fires, California does not" and "the text is non-empty". The replacements iterate
  `USState.allCases` and derive their subject from data.
- **Verify by mutation, not by reading.** Task 2's fixture guard pinned survivor flags by COUNT,
  so swapping the flag between two byte-identical rows still passed. Now pinned by case identity,
  and both implementer and reviewer performed the swap. Task 9 verified the DataManager mirror the
  same way, and found that the pre-existing `StateTaxBreakdownTests.breakdownMatchesCalculation`
  stayed GREEN through a mutation that changed the number, because no existing test drove DC with
  a survivor row.
- **A Swift trap worth remembering.** `let isSurvivorBenefit: Bool? = nil` compiles, warns that
  the property "will not be decoded", and then DECODES JSON THAT SETS IT TRUE AS NIL, silently. A
  reviewer established that by compiling it rather than reasoning about it. Fixed by `let` to
  `var`. `Bool?` was kept over a `Bool` defaulting false, deliberately: a migrated record has never
  been ASKED the question, and false would assert "known not survivor".
- **Verify before you comply.** Sixteen times in this program a subagent caught an error in the
  brief it was handed, several of them the controller's, and two would have put false statements
  into fixtures. Two corrections in this phase outlive their reports: the Hawaii test that
  asserted a FALSE claim about the migration default and shipped it marked [MEASURED], and the
  Idaho catalogue entry that said shipping was "foreclosed procedurally" when that was true of two
  branches and false of a third. Both would have stopped a future task from looking.

## Full suite gate

Run at the committed state (`faf79b1`) with `tools/run-tests.sh` in the foreground, timeout 600000.
The wrapper's own header confirmed it built THIS worktree at THAT commit.

```
Swift Testing:  Test run with 2020 tests in 304 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)
PASS. 2529 test(s) ran, no failures.
```

6 pre-existing env-gated skips. **No `MultiYearPerfTests` flake on this run**, so the wrapper's
isolation re-run was not triggered and there is nothing to qualify.

Commit at close: `faf79b1` (the ledger and the resume update), plus this gate line.

## Em dash check

A grep for the em dash character returns 0 for this ledger, for the RESUME-HERE file, and for every
file this task wrote or touched.

## What was NOT done, deliberately

- No pin, `knownDefect` block, frozen baseline or shipped config was touched by Task 10. This was
  a reporting task and it changed no tax behaviour.
- No decided jurisdiction was re-opened.
- Vermont was not shipped, and that is now a DECISION: John accepted the unanimous HOLD
  recommendation on 2026-08-05. See the section above.
