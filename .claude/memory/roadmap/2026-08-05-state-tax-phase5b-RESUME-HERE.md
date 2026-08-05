# RESUME HERE: State Tax Phase 5b, ready to run Task 2

**This file exists because the SDD progress ledger lives in `.superpowers/`, which is GITIGNORED and would not survive a new session.** Everything a fresh session needs is below.

---

## Pick up exactly here

**Branch:** `feature/state-tax-phase5b`, pushed to origin at **`b0e23fe`**. Not merged.
**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b`
**Plan:** `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md` (on that branch)
**Next task:** **Task 2**, re-label the fixtures the old model forced into wrong cases, and add the missing negative regression cases.

Suite on that branch: **1,880 Swift Testing in 294 suites + 509 XCTest, 0 failures**, 6 pre-existing env-gated skips.

`origin/main` is at `5024947`. Phases 1 through 5a are all merged and pushed.

---

## Read these first, in this order

1. `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md` (the catalogue and its traps)
2. `.claude/memory/roadmap/2026-08-04-state-tax-phase5a-ledger.md` (the corrections method, plus the Iowa resolution appended 2026-08-05)
3. The Phase 5b plan named above
4. This file

---

## THE FINDING PHASE 5B IS BUILT AROUND

Phase 3b built `PerSourceExemptionRule` with two deliberately separate axes so a plain "government pension" label could not hand New York's uncapped exclusion to a California public pension. New York carries a permanent regression case proving it.

**Kansas uses the same enum case BACKWARDS.** `PlanSource.otherStateOrLocal` documents itself at `RetireSmartIRA/RetirementPlanClassification.swift:40-43` as "A DIFFERENT state or its localities... exists specifically to stop an out-of-state public pension from selecting New York's exclusion." Kansas's three remaining fixtures label **KPERS**, Kansas's OWN system, with that case. The label was forced because the model could not say "this state's own system."

So the obvious Kansas rule would (a) pass all three Kansas fixtures, (b) exempt a **California** public pension for a Kansas resident, which Kansas law does not do, and (c) be caught by NOTHING, because Kansas has no out-of-state negative case the way New York does. **Task 2 adds that case.** It is the whole reason Task 2 exists.

The same missing vocabulary is what made **Vermont** (military vs CSRS, both `federalCivilian`) and **DC** (survivor vs own pension, both `federalCivilian`) UNSATISFIABLE by any configuration, per Phase 4.

---

## Task 1 is COMPLETE (commits `ebd2544`..`b0e23fe`), reviewed, one Critical found and fixed

Added to `PlanSource`: **`ownStateOrLocal`**, **`uniformedServices`**, **`railroadRetirement`**. Added a survivor flag to `RetirementPlanClassification`.

**20 exclusivity tests** in `RetireSmartIRATests/Phase5bModelExtensionTests.swift` prove BOTH directions for every new-versus-old pair. That mutual exclusion is the entire point: a rule naming `ownStateOrLocal` must NOT match `otherStateOrLocal`, and the converse.

**Inertness proven.** Only the two model files changed. No baseline, no movement ledger, no golden fixture. `PerSourceExemptionRule.matches()` is byte-for-byte unchanged, so a rule written before this behaves identically after. **New York was the canary** (only state shipping `perSourceExemptions`) and is unmoved.

**THE CRITICAL FINDING, worth remembering as a Swift trap.** The survivor flag shipped as `let isSurvivorBenefit: Bool? = nil`. A reviewer COMPILED that exact shape rather than reasoning about it and established by execution: the memberwise init REJECTS an argument for it ("extra argument in call"); the compiler warns the property "will not be decoded"; and **decoding JSON that explicitly sets it `true` SUCCEEDS AND YIELDS NIL**, with no error. Not merely useless, **silently lossy**. Fixed by `let` to `var`, with the compile error captured as RED first.

`Bool?` was kept over a plain `Bool` defaulting false, and the reasoning is worth preserving: a migrated `federalCivilian` record has genuinely never been ASKED whether it is a survivor benefit, so `false` would assert "known not survivor" for an unanswered question. Same discipline the file already applies via `PlanStructure.unknown` and `PlanSource.unknown`.

**DOWNSTREAM CHAIN, deliberately NOT built in Task 1, needed before DC can work:** a field on `IncomeSource` and `IRAAccount`; `matchIsSurvivorBenefit` on `PerSourceExemptionRule`; a parameter on `matches()`; a pass-through in `DataManager.matchedPerSourceRule`; a field on the fixture type `ClassifiedPensionSource`; and a bridge in `GoldenScenarioSingleYearTests.singleYearStateTax`.

---

## What Task 2 must do

Modify three fixtures. **This changes golden fixtures, which Phase 4 otherwise treats as frozen, and that is deliberate**: these three were written against a model that could not express their rules, and Phase 4 recorded VT and DC as unsatisfiable for exactly that reason. Justify it in the report.

- **Kansas:** re-label KPERS from `otherStateOrLocal` to `ownStateOrLocal` in all three cases. **Then ADD the out-of-state negative case Kansas lacks**, mirroring New York's: a Kansas resident holding a CALIFORNIA public pension, which Kansas does NOT exempt. Name it so a later reader knows it is the guard.
- **Vermont:** re-label military cases from `federalCivilian` to `uniformedServices`, leaving genuine CSRS cases alone. Read each case's `source` string to decide which is which; do not guess from amounts.
- **DC:** set the survivor flag on survivor-benefit cases, leaving own-pension cases alone. **Note the downstream chain above is not built yet**, so DC may need part of it before the flag can be set from a fixture at all. If so, that is a real finding and belongs in the report rather than being worked around.

**Expected: no tax value moves in Task 2.** Re-labelling changes what a FUTURE rule can match, not today's computation, because no state yet has a rule naming the new cases. The `observedToday` pins should hold. If any moves, something matched on the old label that should not have, and that is a finding. The new Kansas negative case is the exception, being new.

---

## Then Tasks 3 to 10

3 Kansas per-source (**COMPLETES the second half of Steve Nicolai's promise**), 4 Massachusetts, 5 Hawaii, 6 Arizona, 7 North Carolina, 8 Idaho, 9 Vermont and DC together, 10 close the phase.

**Two states currently PASS ON WRONG LAW and Phase 4 flagged both:**
- **Arizona:** every civilian amount in its fixtures is under the $2,500 cap, so an uncapped federal-civilian rule leaves cases green while being wrong above the cap.
- **Idaho:** its only sub-62 case is at age 60, so a single age-62 gate turns all five cases green while being wrong for civilian retirees whose real gate is 65.

**North Carolina may stay unsatisfiable.** Bailey keys on vesting before 1989-08-12 and the model has no vesting-date axis. Decide whether to add the axis or record NC as remaining unsatisfiable. **Do not force it.**

---

## Standing rules that cost real time when ignored

- **RUN XCODEBUILD IN THE FOREGROUND with the Bash tool's `timeout: 600000`.** Five agents stalled by backgrounding a build, each costing a full turn. The 120 second default is not the ceiling. Do not use `run_in_background` or Monitor. **The durable fix is a wrapper script; nobody has written one.**
- **"Verify before you comply" belongs in every fix dispatch.** Seven separate times a subagent caught an error in the brief it was given, including two of mine that would have put false statements into fixtures. A reviewer finding is evidence, not fact, exactly like an implementer report.
- **The frozen 1,020-value baseline stays frozen forever.** Movements go in `statetax-behavior-movements-2026.json` with a `goldenCase` that is machine-checked against real fixture names. `after` values are MEASURED from failure messages, never predicted.
- **Two equivalence lists mean different things.** `phase5CorrectedJurisdictions` (KS, IA, NM, GA, UT, IN) asserts divergence from the frozen legacy Swift table. `layerAProvenDivergentJurisdictions` (IA, NM, GA, UT) asserts at least one scenario in a fixed grid diverges. Kansas and Indiana are deliberately in the first and NOT the second, because that grid never exercises a personal exemption.
- **NO EM DASH CHARACTERS** anywhere.
- **A fixture can be citation-clean and still not carry enough.** New Mexico's married bracket table was only partially quoted, so its corrector had to fetch the enrolled bill. Expect this again.
