# Task 1 brief: extend the model, provably inert


---

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md`, plus four recorded amendments in `.claude/memory/decisions/log.md` dated 2026-08-04: base values first; golden scenarios stand in for the two-model protocol; the legacy Swift table is frozen at pre-correction law with the equivalence gate scoped; Iowa pulled forward.
- **UNLIKE PHASE 5a, THIS PHASE CHANGES SWIFT.** 5a was config-only and its confinement rule was "nothing but JSON." That rule does not apply here. What replaces it: every Swift change must be an ADDITIVE model extension that is provably inert until a config opts into it, and Task 1's gate is what proves that.
- **The frozen 1,020-value baseline stays frozen.** Every deliberate movement gets an entry in `RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json` naming the golden case that authorises it. That `goldenCase` is MACHINE-CHECKED against real fixture scenario names, so a typo or an invented name fails the suite. `after` values are MEASURED from failure messages, never predicted.
- **Two equivalence lists, and they mean different things.** `phase5CorrectedJurisdictions` asserts a state DIVERGES from the frozen legacy Swift table. `layerAProvenDivergentJurisdictions` asserts at least one scenario in a fixed 10-scenario grid diverges. Kansas and Indiana are deliberately in the first and not the second, because that grid never exercises a personal exemption. Place each new state on the same reasoning and say why in the report.
- **A golden case going green is the deliverable.** Deleting a `knownDefect` block is how a correction is declared complete, and the block's own second assertion forces it: once the engine matches the form, the test fails saying "delete the knownDefect block."
- **NO EM DASH CHARACTERS** anywhere, including JSON strings, code comments and reports.
- **Tests are the source of truth.** Baseline at branch point: 1,857 Swift Testing in 293 suites + 509 XCTest, 0 failures, 6 pre-existing env-gated skips. `MultiYearPerfTests` has a known pre-existing wall-clock flake; re-run in isolation rather than calling it a regression.
- **RUN XCODEBUILD IN THE FOREGROUND WITH `timeout: 600000`.** Five agents on this project have stalled by backgrounding a build. The 120 second default is not the ceiling. Do not use `run_in_background` or Monitor.
- **Never edit by chained `cd`.** Use absolute paths and `git -C`.

**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`, branch `feature/state-tax-phase5b`, off `main` @ `c5a7bce`.

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

---

## THE FINDING THIS PHASE IS BUILT AROUND

Phase 3b built `PerSourceExemptionRule` with two deliberately separate axes, `PlanSource` and `PlanStructure`, specifically so that a plain "government pension" label could not hand New York's uncapped exclusion to a California public pension. New York's fixture carries a permanent regression case proving exactly that.

**Kansas uses the same enum case BACKWARDS, and nothing catches it.**

`PlanSource.otherStateOrLocal` documents itself at `RetireSmartIRA/RetirementPlanClassification.swift:40-43` as "A DIFFERENT state or its localities. NOT Line 26 eligible. This case exists specifically to stop an out-of-state public pension from selecting New York's exclusion."

Kansas's three remaining fixtures label **KPERS**, the Kansas Public Employees Retirement System, as `otherStateOrLocal`. It is not a different state's system; it is Kansas's own, held by a Kansas resident. The label was forced because **the model has no way to say "this state's own system."**

So the obvious Kansas rule, `matchSources: ["otherStateOrLocal", "federalCivilian"]`, would:
1. Make all three Kansas fixtures pass, and
2. Exempt a **California** public pension for a Kansas resident, which Kansas law does not do, and
3. Be caught by nothing, because Kansas has no out-of-state negative case the way New York does.

That is the Phase 3b defect class reappearing in a different state. **The model extension in Task 1 exists to prevent it, and Task 2 adds the missing negative cases that would have caught it.**

The same gap blocks two more jurisdictions, which Phase 4 recorded as UNSATISFIABLE by any configuration:
- **Vermont** needs to distinguish a military pension from a CSRS one. Both are `federalCivilian` in its fixtures, so one rule cannot give them different treatments. Vermont's uncapped military exclusion and its $10,000 CSRS exclusion are indistinguishable.
- **DC** needs to distinguish a survivor benefit from the holder's own pension. Both are `federalCivilian`, and DC exempts the survivor benefit while taxing the own pension.

---

### Task 1: Extend the model, provably inert

**Files:**
- Modify: `RetireSmartIRA/RetirementPlanClassification.swift`
- Modify: `RetireSmartIRA/PerSourceExemptionRule.swift`
- Test: `RetireSmartIRATests/Phase5bModelExtensionTests.swift` (new)

**Interfaces:**
- Produces: three new `PlanSource` cases and one new optional property on the classified-source type. Tasks 3 through 9 author config against these names, so get them right here.

Add to `PlanSource`:
- **`ownStateOrLocal`**, meaning the taxpayer's OWN state or its localities. This is what KPERS is for a Kansas resident, what a Massachusetts contributory pension is for a Massachusetts resident, and so on. Its doc comment must contrast itself explicitly with `otherStateOrLocal`, whose comment already explains it exists to STOP an out-of-state pension selecting a state's exclusion. **These two cases are a matched pair and each doc comment should name the other.**
- **`uniformedServices`**, meaning military retired pay. Distinct from `federalCivilian`, which is CSRS and FERS. Vermont, Arizona, Idaho, Massachusetts and Kansas all treat these differently, and today they are indistinguishable.
- **`railroadRetirement`**, which Kansas exempts by name and which is neither a state nor an ordinary federal civilian pension.

Add to the classified-source type an optional survivor flag, defaulting to nil so every existing fixture and save decodes unchanged. DC exempts a survivor benefit while taxing the holder's own pension, and both are `federalCivilian` today.

**THE GATE FOR THIS TASK IS INERTNESS.** Adding enum cases must not move a single computed value. Specifically:
- The frozen 1,020-value baseline must not move. No new movement-ledger entries in this task.
- Every golden fixture must produce exactly what it produces today, including all 99 remaining pinned defects.
- New York's four fixtures must be byte-for-byte unaffected. New York is the only state shipping `perSourceExemptions` today, so it is the canary: if its numbers move, matching semantics changed rather than widened.

**Prove inertness by running the full suite before and after and showing no value moved.** Then prove the new cases are REACHABLE by a focused unit test that constructs a `PerSourceExemptionRule` matching each new case and asserts it matches what it should and, more importantly, does NOT match what it should not. `ownStateOrLocal` must not satisfy a rule naming `otherStateOrLocal`, and vice versa; that is the whole point.

**Watch for the decode trap Phase 3b already hit once.** Its ledger records that a single unrecognised classification string in one saved income row would have discarded EVERY stored income source, because `PersistenceManager.loadAll` wraps its decode in `try?`. The resolution then was that shipped state JSON keeps a strict throw while USER SAVES fall back to `.unknown` with an observable diagnostic. Adding enum cases means a save written by a newer build cannot be read by an older one. Verify that fallback still holds for the new cases and say how you verified it.
