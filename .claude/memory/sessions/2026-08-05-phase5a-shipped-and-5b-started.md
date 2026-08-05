# 2026-08-05: Phase 5a shipped, Iowa's open question resolved, Phase 5b started

**To resume, open `.claude/memory/roadmap/2026-08-05-state-tax-phase5b-RESUME-HERE.md` first.** It is written for someone with no memory of this session and carries everything needed to run Phase 5b Task 2. This file is the surrounding context.

`origin/main` @ `5024947`. Branch `feature/state-tax-phase5b` pushed at `b0e23fe`, not merged.

---

## 1. Phase 5a: the first tax corrections in the program

Merged and pushed. **118 defect cases to 99.** Six jurisdictions corrected, three completely: **Iowa** (6 of 6), **Georgia** (5 of 5), **Indiana** (4 of 4). Partially: **Kansas** (3 remain), **New Mexico** (2), **Utah** (4), each waiting on a model field that does not exist.

**75 baseline values moved**, each attributed to a named golden case citing a state's published form. Production diff was six config JSONs plus a comment-only Swift change. No logic moved.

**Iowa was the one that mattered.** It excludes retirement income from 55 including Roth conversion income by name, and the app modelled none of it, inventing roughly $7,600 of state tax on a $200,000 conversion. That is the exact transaction this product exists to plan.

### The mechanism 5a built, which 5b and beyond depend on

Phases 1 to 4 could assert nothing moved. Phase 5 moves numbers on purpose, so that assertion was replaced rather than weakened: **the frozen 1,020-value baseline stays frozen forever**, and every deliberate movement is a checked-in record naming the golden case that authorises it. That `goldenCase` is machine-checked against real fixture names, so a typo or an invented name fails the suite. A value that moves with no record still fails.

### The blocker 5a uncovered, and the decision

`configs2026Legacy` is a 1,651-line second copy of all 51 states' data in `StateTaxData.swift`. Its own comment says "Not the production path", but `config(for:)` tries JSON, then legacy, then `preconditionFailure`, **which traps in RELEASE too**. So it is a live fallback, and a Phase 1 test asserts the two tables match.

**Decision: freeze the legacy table at pre-correction law.** Not updated per correction (35 double-edits, and this project already drifted a hand-duplicated mirror five times on one branch), not deleted (deleting makes a bundling failure CRASH rather than serve slightly stale numbers). **The skip is LOUD:** a corrected jurisdiction must be asserted to have DIVERGED, so a reverted correction or a hand-edited legacy table both fail. Residual risk, disclosed in the table's own doc comment: if the bundled JSON ever fails to load, a user in a corrected state silently gets pre-correction rules.

---

## 2. Iowa's open question: RESOLVED, and the shipped value was right

Phase 5a shipped `withheldPortionRemainsTaxable: false` on a reasoned analogy to Illinois and Mississippi, because no Iowa DOR guidance on the withheld portion could be found. It was worth **$836** on a conversion with withholding, and the app has a withholding feature, so it was recorded as needing a human.

John brought three outside answers. Two converged; **Gemini's was off-topic**, having read "withheld-portion treatment" as a doctrine name and answered about pass-through entity and employer wage withholding. Worth noting as a failure mode: a plausible answer to a differently-understood question is harder to spot than a wrong one.

**I then fetched the Iowa DOR page directly rather than trusting the summaries**, which is the discipline this whole program enforces. Two clauses settle it:
- The qualifying-income section lists **"Roth conversion income"** by name.
- The FAQ "Iowa income tax was withheld on retirement income from a qualifying plan to a qualified recipient. What should I do?" answers that such tax is **ERRONEOUSLY WITHHELD**, directing the taxpayer to recover it from the plan administrator and file a new IA W-4P.

**Iowa does not treat the withheld portion as a taxable slice. It treats the withholding itself as a mistake.** So the exclusion covers the full distribution. `false` is correct, and is now cited rather than inferred, in both the fixture and the movement ledger. This is the OPPOSITE of Pennsylvania, whose `true` rests on a cost-recovery mechanism under which only the net amount reaching the Roth is exempt. Copying PA's flag would have been wrong.

**A NEW LIMITATION SURFACED, and it runs the other way from nearly everything in this program.** Iowa's qualifying list does NOT reach nonqualified deferred compensation under IRC 409A, or nonqualified annuities, which commonly carry code D in box 7 of Form 1099-R. The app cannot distinguish them, so an Iowa holder of one is **UNDER-taxed**. Recorded in the Iowa fixture as `nonQualifyingPlansNote` and flagged for Phase 6 disclosure text.

---

## 3. Phase 5b started: Task 1 done

Scoped to the per-source track alone, eight jurisdictions and 29 defects, rather than everything remaining. Credits, the bracket base amount, South Carolina's age-65 deduction, attribution gates and cross-path work each need a different model change or method and get their own phases.

**Task 1 added `ownStateOrLocal`, `uniformedServices` and `railroadRetirement` to `PlanSource`, plus a survivor flag**, with 20 tests proving mutual exclusivity in both directions. Inertness proven, New York unmoved.

**Its Critical finding is a Swift trap worth remembering.** The survivor flag shipped as `let isSurvivorBenefit: Bool? = nil`. A reviewer compiled that exact shape and found: the memberwise init rejects an argument for it, the compiler warns it "will not be decoded", and **decoding JSON that explicitly sets it true succeeds and yields nil, silently.** Not merely useless. Fixed by `let` to `var`.

**The finding the whole phase is built around** is in the RESUME file: Kansas labels KPERS, its own system, with the enum case whose doc comment says it exists to STOP an out-of-state pension selecting a state's exclusion. The obvious rule would pass Kansas's fixtures and also exempt a California pension for a Kansas resident, caught by nothing.

---

## 4. Where the six promises stand

| # | Promised | Status |
|---|---|---|
| 1 | Kansas personal exemption | **corrected**, on main, unreleased |
| 2 | Iowa exclusion incl. Roth conversions | **corrected and now fully cited**, on main, unreleased |
| 3 | Per-state detail view | Phase 6, not started |
| 4 | RMD summary leads with whoever starts first | on main, unreleased |
| 5 | RMD chart separates the two people | on main, unreleased |
| 6 | Caret fix, owed to Alan since 07-19 | on main, unshipped, scope decided as all nine screens |

**Kansas is NOT fully correct.** Its per-source defect stands, so a KPERS holder is still over-taxed. Phase 5b Task 3 closes it. Do not tell Steve Kansas is fixed until then.

**NOTHING HAS SHIPPED.** `main` is far ahead of released 2.3.0.

---

## 5. Method findings from this session

- **Seven separate times a subagent caught an error in the brief it was given**, including two of mine that would have put false statements into fixtures, and one where my mutation probe targeted a single field when the gate rested on several independent ones. "Verify before you comply" is now standing in every fix dispatch.
- **Five agents stalled by backgrounding a build**, each costing a full turn, despite an explicit instruction in every dispatch. Repeating the instruction is not working. **The durable fix is a wrapper script that runs the suite with the right timeout by default. Nobody has written one.**
- **A fixture can be citation-clean and still not carry enough.** New Mexico's married bracket table was only partially quoted, so its corrector fetched the enrolled bill itself. Phase 4's reviews checked that quotes were real and correctly located, not that they were sufficient.
- **Georgia surfaced three pre-existing tests whose inputs sat exactly on a zero-crossing**, so they passed regardless of whether Georgia was right. Only changing the surrounding numbers exposed them.
- **Utah showed the subtler failure mode being avoided.** Its four surviving defect records were not just kept; two had their descriptions reworded to drop a now-fixed claim. A stale description would have sent Phase 5b to re-fix something already corrected.

---

## Next steps

1. **Run Phase 5b Task 2.** Everything needed is in the RESUME file.
2. **Answer Steve on the Tax Summary point.** Analysis done 08-04, no draft written. It was a real third issue, already fixed, and the reply must not say the amounts were missing, because they never were.
3. Phase 5b Tasks 3 to 10, then 5c (credits, bracket base, SC deduction, attribution gates, OK/AR/SC base values with re-derivation, cross-path), then Phase 6, then Phase 7.
4. **Write the xcodebuild wrapper script** before the next phase, so five wasted turns do not become ten.

**Housekeeping:** `feature/state-tax-phase4`, `feature/state-tax-phase5` and their `p5-t*` and `phase4-b*` worktrees are merged and removable. `feature/state-tax-phase5b` IS pushed. `feature/state-tax-phase3b` was never pushed and remains laptop-only.
