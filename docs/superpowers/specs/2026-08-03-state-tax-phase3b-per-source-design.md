# State Tax Phase 3b: per-source exemptions, design

**Date:** 2026-08-03
**Status:** design, approved in outline; revised after review
**Parent program:** `2026-08-02-state-tax-verification-and-maintenance-design.md`, §3.3c
**Predecessor:** Phase 3a, merged at `b138a62`. Its ledger is `.claude/memory/roadmap/2026-08-03-state-tax-phase3a-ledger.md` and should be read before implementing this.

---

## 1. Problem

Some state retirement exemptions depend on **where the money came from**, not on the state alone. `RetirementIncomeExemptions` is per-state, so those rules cannot be expressed at all.

Two named users are affected today:

- **Alan Levy** collects a New York City employee pension. IT-201 **Line 26** excludes pensions of NYS, its localities and the federal government with **no cap**. The app applies only **Line 29**, the $20,000 per-person exclusion, so it overstates his New York State tax and the 3.88% city tax that runs on the same base. Confirmed 2026-07-31 in his own words.
- **Steve Nicolai's** wife worked for the state. Some of her 403(b) accounts are state-exempt and others are not, which he correctly identifies as an account-level property (his suggestion G).

**Nine Tier-2 jurisdictions** are blocked on this: KS, MA, HI, NY, AZ, NC, ID, VT, DC. **Alabama is a tenth affected jurisdiction but sits in Tier 1**, a wrong-value correction whose dividing line happens to be defined benefit versus defined contribution. Counting Alabama among the nine is an error; it needs the same dimension for a different reason.

Of those, the 2026-08-02 audit verified **New York, Alabama and Hawaii** in detail against primary sources and explicitly did **not** audit KS, MA, AZ, NC, ID, VT or DC.

## 2. Scope decisions

| Decision | Choice |
|---|---|
| Where classification lives | **Both `IncomeSource` and `Account`**, sharing one domain model |
| What the user is asked | **One flat picker**, backed by **two internal dimensions** |
| Existing data | **Infer what is knowable, prompt only for pensions** |
| Behavior change in this phase | **New York only** |
| Hawaii | **Disclosed, not modelled** |

### Why both surfaces

Income rows feed the tax engine directly. Accounts feed projected withdrawals, which reach the engine as a single unowned, unclassified scalar. Classifying only income rows leaves every multi-year projection unclassified, so a corrected New York rule would apply on the Scenarios tab and not in the plan. Classifying only accounts fails Alan, whose pension is income he receives rather than an account he holds.

### Why two dimensions rather than one enum

A single flat enum mixes unrelated attributes: employer type, plan structure, funding mechanism, and account wrapper. A public-school 403(b) is simultaneously government-employed, defined contribution and salary-reduction. Collapsing it into one case discards the other two facts, and a later state rule that turns on any of them cannot be expressed.

**This is not theoretical. The flat design contained a live defect.** A single `.governmentPension` case, offered to users under that plain-English label, would have handed New York's uncapped Line 26 exclusion to a California or Illinois public pension held by a New York resident. Line 26 covers officers, employees and their beneficiaries of **NYS, a NY locality, named NY public authorities, or the US government** and nothing else. Such a pension is Line 29 income, capped at $20,000. The error direction is **under-taxation**, which the audit names the dangerous one, and no planned fixture contained an out-of-state public pension, so nothing would have caught it.

## 3. Architecture

### 3.1 Domain model

```swift
enum PlanStructure: String, Codable, CaseIterable {
    case definedBenefit        // traditional pension, annuitised
    case definedContribution   // 401(k), 403(b), 457
    case ira                   // individual retirement arrangement
    case unknown               // migration default; behaves as today
}

enum PlanSource: String, Codable, CaseIterable {
    case nyStateOrLocal        // NYS, NY localities, named NY public authorities
    case federalCivilian       // US government civilian service
    case otherStateOrLocal     // a DIFFERENT state or its localities. NOT Line 26 eligible.
    case governmentUnspecified // a government employer whose jurisdiction was not established
    case privateEmployer
    case individual            // self-established, e.g. a personal IRA
    case unknown               // migration default; behaves as today
}
```

`governmentUnspecified` exists because the picker establishes jurisdiction for pensions, where it changes the answer, and deliberately does not interrogate it for salary-reduction plans, where under every rule shipping in this phase it cannot. Recording "a government employer, jurisdiction unknown" is honest; recording `otherStateOrLocal` for a New York state employee's 403(b) would be a false statement stored in user data. No rule may match `governmentUnspecified` as though it were a specific jurisdiction.

Both are carried by `IncomeSource` and by `Account`.

**Military retirement is out of scope.** It already has its own `IncomeType` and its own per-state exemption table in `MilitaryRetirementExemption.swift`, which reads a state-code string and consults no `StateTaxConfig` field. Nothing here changes it.

### 3.2 The picker

The user sees one short list of plain-English choices. Each sets both dimensions.

| Choice shown | structure | source |
|---|---|---|
| Government pension, New York State or local | `definedBenefit` | `nyStateOrLocal` |
| Government pension, federal civilian | `definedBenefit` | `federalCivilian` |
| Government pension, another state or locality | `definedBenefit` | `otherStateOrLocal` |
| Private employer pension | `definedBenefit` | `privateEmployer` |
| 403(b) or 457, government employer | `definedContribution` | `governmentUnspecified` |
| 403(b) or 457, private or nonprofit employer | `definedContribution` | `privateEmployer` |
| Employer 401(k) | `definedContribution` | `privateEmployer` |
| IRA | `ira` | `individual` |
| Not sure | `unknown` | `unknown` |

The third row exists specifically to stop an out-of-state public pension from selecting New York's exclusion.

The two 403(b) rows exist for Steve Nicolai's case: some of his wife's 403(b) accounts are state-exempt and others are not, and the employer is what plausibly separates them. Splitting the choice captures that distinction with one extra row rather than a second question. Neither row affects any rule shipping in this phase, since New York excludes both by structure; they are recorded so the distinction survives until Kansas is verified.

### 3.3 Config: an ordered match list

`RetirementIncomeExemptions` gains:

```swift
/// Ordered, first match wins. Empty for every jurisdiction except New York.
/// An empty list means every source is treated identically, which is what
/// all 51 jurisdictions did before this phase.
var perSourceExemptions: [PerSourceExemptionRule] = []

struct PerSourceExemptionRule: Codable, Equatable, Sendable {
    /// Empty means "any". Non-empty means the source must be in this set.
    let matchSources: [PlanSource]
    /// Empty means "any".
    let matchStructures: [PlanStructure]
    let treatment: RetirementIncomeExemptions.ExemptionLevel
}
```

New York's single rule:

```swift
perSourceExemptions: [
    PerSourceExemptionRule(
        matchSources: [.nyStateOrLocal, .federalCivilian],
        matchStructures: [.definedBenefit],
        treatment: .full)
]
```

Income matching no rule falls through to the existing per-state `pensionExemption` and `iraWithdrawalExemption`, which for New York is the correct shared $20,000. **A government employee's 403(b) is excluded from Line 26 by its `definedContribution` structure**, so it falls through and is capped, with no special case needed.

### 3.4 Engine: components beside the scalar

`scenarioRetirementDistributions: Double` is **not** replaced. It has 42 call sites across production and tests, and replacing it would churn all of them and bury the change a reviewer needs to see. An optional parameter is added beside it:

```swift
struct RetirementDistributionComponent: Equatable, Sendable {
    let owner: Owner
    let structure: PlanStructure
    let source: PlanSource
    let amount: Double
}
```

`nil` means the engine synthesises one component with `owner: .primary`, `structure: .unknown`, `source: .unknown` and the scalar's amount, which is today's behavior exactly.

**Owner attribution does not change in this phase.** The component carries `owner` so that a later phase can correct general per-spouse attribution, but no new owner behavior is activated here. Source classification and owner attribution are separate corrections, and bundling them would destroy the ability to prove that only New York's rule moved a value. Note also that no jurisdiction ships `.perQualifyingSpouse`, so owner-differentiated behavior is unreachable in production regardless.

**The sum invariant.** When components are supplied their amounts must agree with the scalar within one cent:

```swift
abs(components.reduce(0) { $0 + $1.amount } - scenarioRetirementDistributions) <= 0.01
```

Exact `Double` equality is unsafe for currency. Failure semantics are defined here rather than left to the implementer: **`assertionFailure` in debug**, which traps during development and in every test run; **in release, fall back to the scalar path and set an observable diagnostic flag**, following the precedent `StateTaxDataLoader.legacyFallbackFired` set in Phase 1. A `precondition` would crash a customer's app over a programming defect, and a silent fallback would hide it. This combination fails loudly where a developer will see it and degrades safely where a user would otherwise lose their plan.

### 3.4a Shared caps: rule matching partitions, it does not evaluate per component

The single largest correctness risk in moving from one scalar to many components is granting a capped exemption **once per component** instead of once per taxpayer. This codebase has already shipped that bug once: New York's shared pension-and-IRA cap exists because an earlier version granted $20,000 to pension and another $20,000 to IRA distributions.

So per-source rules are applied as a **partition before the existing cap machinery runs**, never as a per-component cap evaluation:

1. Each component and each `IncomeSource` row is tested against `perSourceExemptions`. First match wins.
2. Amounts matching a rule with `.full` treatment are subtracted outright and **contribute nothing to any shared cap**.
3. Everything unmatched is pooled exactly as today and passed to the existing `pensionExemption` / `iraWithdrawalExemption` logic, including `pensionAndIRAShareSingleCap` and `exemptionAppliesPerIndividual`.

The cap is therefore still applied **once, to a pooled figure, per eligible taxpayer**. The existing per-individual doubling is untouched. For New York this yields exactly the statute: the Line 26 government pension is excluded independently and does not consume the Line 29 allowance, and every other qualifying source shares one $20,000 per eligible taxpayer.

### 3.4b Multi-year: the pension input widens, accounts do not

`ProjectionEngine` receives scalars throughout. `inputs.primaryPensionIncome + inputs.spousePensionIncome` are summed into one number, and `AccountSnapshot` collapses every account into nine doubles. `computeStateTax` then synthesises `.pension` and `.rmd` income rows from those scalars, so **no classification of any kind reaches the projection today**. The projection knows owner and IRA-versus-401(k) and nothing finer.

Left alone, Alan would see the uncapped exclusion on Scenarios and the capped one in the Multi-Year plan: two New York answers for one household, which is the cross-path divergence class this program already carries one known instance of.

**In scope:** `primaryPensionIncome` and `spousePensionIncome` widen to carry classification, so the only rule that ships is cross-path consistent.

**Out of scope:** `AccountSnapshot`. It is a persisted `Codable` type with existing migration history, and the projection's bucket math, RMD basis and snapshot tests all read its four traditional scalars. Consequence, which must be disclosed rather than discovered: **account classification is inert in every tax path this phase ships, single-year and Multi-Year alike, not only the Multi-Year projection.** `IRAAccount.planStructure`/`planSource` are read at presentation sites only (the accounts list label and the edit sheet's own badge); no rule shipping in this phase reads them for a calculation. No number is wrong because of it; Steve's flag is stored and displayed but inert until Kansas is verified, and the in-app disclosure says exactly that rather than claiming a single-year effect that does not exist. (Whole-branch review, Fix 1: an earlier draft of this section claimed the opposite, that account classification affected the single-year calculation; a probe -- a New York household with a $500k traditional 401(k), classified `(definedBenefit, nyStateOrLocal)` versus unclassified -- computed the identical figure to the last digit either way.)

### 3.5 The DataManager mirror

`DataManager.stateTaxBreakdown` hand-duplicates `applyRetirementExemptions`. **On Phase 3a alone, five changes landed in the engine and not the mirror**, three caught per-task and two only by the final whole-branch review, one of which was worth $3,503.50 of divergence for a single Georgia filer.

Every task in this phase that touches the engine syncs the mirror in the same commit, and no task is done until `grep <new identifier> DataManager.swift` has been run. The mirror also still has **no test seam**: `stateTaxBreakdown(forState:filingStatus:)` accepts no `configOverride`. Adding one is in scope for this phase, because per-source rules multiply the ways the two can drift.

### 3.6 Migration

Inference runs on decode:

| Existing thing | structure | source |
|---|---|---|
| `Account` of type `traditionalIRA` | `ira` | `individual` |
| `Account` of type `traditional401k` | `definedContribution` | `privateEmployer` |
| `IncomeSource` of type `.rmd` | `ira` | `individual` |
| `IncomeSource` of type `.pension` | `unknown` | `unknown`, and prompted |
| everything else | `unknown` | `unknown` |

**The promise, stated precisely: existing saves decode without user intervention and preserve current calculated behavior.** They do not remain literally unchanged, because inference writes classifications.

`IncomeSource` **is persisted** through `PersistenceManager` and already carries migration logic for a removed enum case. Phase 3a's final review confirmed none of its five fields were persisted, which is why a renamed coding key could not orphan a decoder there. **That protection does not carry over**, and a renamed key orphaning a legacy decoder is precisely the defect that shipped on the V2.3 branch with every per-task review passing. Every new key is `decodeIfPresent` with the inference as fallback, and a test decodes a pre-3b fixture blob and asserts the computed tax is unchanged.

**The two data sources get different strictness, deliberately.** Shipped state JSON is authored by us and read identically by every install, so an unrecognised value there is a build defect and must fail loudly: a silent default would turn a corrupt config into a plausible wrong tax. A user's saved data is different. `PersistenceManager.loadAll` wraps its decode in `try?`, so a single unrecognised string in one income row discards **every** stored income source. That trade is wrong in both directions: it destroys real user data to guard against a value that, being unrecognised, the app has no rule for anyway, and `.unknown` is already the migration default and already behavior-preserving.

The concrete trigger is not hypothetical once the picker ships. A later phase adding a `PlanSource` case produces saves that an older build cannot read, and a user who downgrades, or restores an older install, loses their income list rather than one classification.

### 3.7 Presentation

**403(b) and 457 accounts display as themselves.** The engine-level `AccountType` is unchanged for this phase, since new account types would reach RMD logic, contribution limits and the accounts UI well beyond it. But once a user classifies an account as a salary-reduction plan, the accounts list, the account detail view and the CPA briefing show that plan type. Nothing continues to call it a Traditional 401(k) after the user has said it is not one.

**An unclassified New York pension is not a silent default.** For a resident of a state with a non-empty `perSourceExemptions`, a `.pension` row whose source is `unknown` shows a prominent prompt, worded as a question about the pension rather than as an optional field, and the computed result carries a visible limitation until it is answered.

**Hawaii's disclosure is contextual.** Its `knownLimitations` entry states that the app does not model the employer-funded versus employee-contributed split and may overstate its tax. It surfaces where a Hawaii user with a pension will encounter it, not only on a general accuracy page.

**No user-facing copy implies a jurisdiction is handled until it is verified.** The dimensions exist internally for all states; only New York's rule ships.

## 4. What changes for users

**Exactly one jurisdiction's numbers move: New York.** A NYS, NY local or federal civilian defined-benefit pension becomes fully excluded. Everything else in New York, including a government employee's 403(b), keeps today's shared $20,000 cap. The change is gated by a golden scenario derived from IT-201 Lines 26 and 29 with line numbers cited, written as part of this phase rather than waiting for Phase 4.

Alabama, Hawaii and the seven unaudited Tier-2 jurisdictions change nothing here.

## 5. Testing

- **The Phase 3a behavior baseline is the inertness gate for all 50 other jurisdictions.** 51 jurisdictions x 20 scenarios of frozen values. Only New York's entries may move, and each moved value must be attributable to the golden scenario.
- **New York golden scenarios**, on both the single-year and multi-year paths: a NYC pension alone; a NYC pension plus a private pension; a government employee's 403(b), which must stay capped; and an **out-of-state public pension, which must stay capped**. That last case is the regression test for the defect this design was revised to remove.
- **A pre-3b persistence fixture** decoded and asserted to produce unchanged tax.
- **Cross-path invariant** holds for every new scenario.
- **Mirror parity:** every per-source rule exercised through `DataManager.stateTaxBreakdown` as well as the engine, using the new test seam.
- **Mutation discipline**, carried from Phase 3a: to claim a test discriminates, mutate the code or data under test and paste the failure. Shipped-data assertions read raw JSON keys, never decoded values, because the asserted value doubles as the decode fallback.
- Existing suite stays green. Phase 3a ended at 1,657 Swift Testing in 278 suites plus 503 XCTest.

## 6. Error handling

| Condition | Behavior |
|---|---|
| Source classified `unknown` in a state with per-source rules | Falls through to the per-state exemption, the same figure as today, with a visible limitation on the result |
| A rule matches no income | No effect; fall through |
| Pre-3b persisted blob | Decodes via `decodeIfPresent` with inference; computed tax unchanged |
| Unknown `PlanStructure` or `PlanSource` string in **shipped state JSON** | Typed `DecodingError` naming the state, never a silent default |
| Unknown `PlanStructure` or `PlanSource` string in a **user's saved data** | Falls back to `.unknown` and sets an observable diagnostic flag. It must NOT throw |
| Components supplied that do not sum to the scalar within one cent | `assertionFailure` in debug; in release fall back to the scalar and set an observable diagnostic flag |
| New York tax computed for an unclassified pension | Falls through to the capped figure, and the result carries a visible limitation wherever that figure is shown |

## 7. Risks

- **Scope growth.** The two-dimension model with structured components is materially larger than the flat enum first proposed. Accepted deliberately: the flat design's brittleness produced the out-of-state pension defect.
- **Persistence.** The one place this phase can break existing users. Mitigated by the fixture test in §3.6 and by every key being optional on decode.
- **The mirror.** Five drifts on the previous phase. Mitigated by same-commit syncing, the grep rule, and adding the test seam.
- **UI surface.** Phase 3a had none. A picker cannot be gated by a frozen baseline, so in-app verification is a required step rather than an optional one, as it was for V2.3.

## 8. Out of scope

New `AccountType` cases for 403(b) and 457; widening `AccountSnapshot` so account classification reaches the Multi-Year projection; general per-spouse owner attribution, which is a separate correction with its own golden scenarios; the eight other per-source jurisdictions; Hawaii's employer-funded split; Alabama's defined-benefit correction; decumulation; per-year income entry; anything in Phases 4 through 7.

## 9. Decisions taken here

- Classification lives on both `IncomeSource` and `Account`, sharing one domain model.
- Two internal dimensions, one flat picker.
- Inference where safe, prompting only where classification cannot be inferred.
- The engine receives owner and source metadata, not plan-kind totals.
- New York is the only jurisdiction whose numbers change.
- Hawaii disclosed and deferred; all other jurisdictions verified before behavior changes.
- A classified 403(b) or 457 is displayed as itself, though the engine-level account type is unchanged.
