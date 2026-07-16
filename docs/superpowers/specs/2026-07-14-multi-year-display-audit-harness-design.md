# Multi-Year Display Audit Harness — Design

**Date:** 2026-07-14
**Status:** Design (approved in brainstorming; pending written-spec review)
**Branch:** `2.2/display-audit-harness` (off `main` @ 4cda6be = shipped V2.1.1)
**Owner:** John

## 1. Purpose

Systematically verify that everything the **Multi-Year Plan** surface renders — charts, graphs, the heir-frontier, the approach-comparison table, and the CPA PDF report — shows the *correct value* AND the *correct thing*. The harness is a development / CI tool. **It does not ship in the app.**

### Motivating evidence (2026-07-14 session)
Two distinct failure modes surfaced, and a robust process must catch both:

- **I1 (wrong number):** the multi-year state-tax path taxed PA Roth conversions it should have exempted (~$82k spurious). A pure arithmetic error.
- **B2 (right number, wrong definition):** the "Lifetime tax" column correctly summed in-horizon tax, but showing *only* in-horizon tax was the wrong thing — it hid the deferred tax on a residual IRA, making "Fill to bracket" look cheaper than "Minimize." The engine was right; the *definition of what to display* was the bug.

An oracle that recomputes "in-horizon tax" would have agreed with the app and **missed B2**. So numbers alone are not enough; the *definitions* must be audited too.

### Core trust principle
"Don't trust Claude to audit Claude" — correct, but swapping Claude for another LLM as the auditor just moves the same problem one seat over (two confident guessers). During this session Claude was confidently **wrong** about B2 until a *deterministic reproduction* printed the actual numbers. Therefore:

> **The pass/fail gate is deterministic. LLMs never produce a number and never hold the gate. They review definitions, labels, and tax-claims against numbers the oracle produced, and multiple models must independently agree.**

## 2. Architecture (two stages + a spec)

```
            ┌─────────────────────────── Display Spec (Stage 0) ───────────────────────────┐
            │  For every chart line / column / CPA row: what it represents, units, formula,  │
            │  and what "correct" means. The oracle implements it; the LLMs audit it.        │
            └───────────────┬───────────────────────────────────────────┬───────────────────┘
                            │ implements                                 │ audited by
                            ▼                                            ▼
  Stage 1 — DETERMINISTIC CORE (Swift, test target)          Stage 2 — MULTI-MODEL REVIEW (CLI, out of app)
  ┌───────────────────────────────────────────┐             ┌──────────────────────────────────────────┐
  │ 1 Profile generator  (diverse households)  │  packets    │ Reads Stage-1 packets + the Display Spec   │
  │ 2 Display extractor  (what each surface     │ ──────────▶ │ Sends each to GPT + Gemini (+opt Claude)   │
  │    would show, via the real engine)         │  (JSON)     │ Bounded prompt: is the DEFINITION / label /│
  │ 3 Oracle  (independent recompute + property │             │ tax-claim right, given the oracle numbers? │
  │    checks, NOT the app engine)              │             │ Collects independent verdicts.             │
  │ 4 Differ (extractor vs oracle → packets)    │             │ Surfaces ONLY disagreements / flags.       │
  └───────────────────────────────────────────┘             └──────────────────────────────────────────┘
        catches I1-class (wrong number)                            catches B2-class (wrong definition)
```

### Why two stages
- Numeric bugs die in Stage 1, deterministically, with **no LLM involved**.
- Definition/label/tax-prose bugs are caught in Stage 2, where **≥2 independent models must raise the same concern** before it becomes a ticket (consensus filters noise).
- Neither layer is trusted alone. Stage 2 also answers "who audits the oracle?" — the LLMs review the spec the oracle implements.

## 3. Stage 0 — The Display Spec (the center of gravity)

A written spec of **every multi-year display**. For each chart series, table column, cliff line, frontier axis, and CPA report row:
- **What it represents** (plain-language definition).
- **Units** (nominal $, PV $, %, count, age).
- **Formula / derivation** (how it should be computed, referencing tax concepts, not app code).
- **"Correct" means** (invariants it must satisfy; e.g. frontier heirs-keep monotic non-decreasing in heir weight; MAGI ≥ AGI; lifetime-tax-paid + deferred-tax reconciles to gross-minus-heirs-keep).

Writing this spec *is* half the value: B2 was a spec ambiguity, not arithmetic. The oracle implements this document; the LLMs audit this document.

## 4. Stage 1 — Deterministic core (Swift, test target)

Lives in `RetireSmartIRATests/` (or a dedicated `AuditHarness` test suite). Reuses the real engine so "what the app shows" is genuinely what the app shows.

1. **Profile generator** — productionizes the section-H sweep. Diverse households across: filing status × age band × traditional-balance size × taxable/Roth mix × state (incl. PA/IL/MS/CA/NJ/no-tax) × giving (none/QCD/cash) × SS timing × inherited IRAs × conversion approach (taxMin / fill-22 / fill-24 / limit-IRMAA) × heir weight. Deterministic seed list (no RNG — reproducible).
2. **Display extractor** — for each profile, runs the engine and captures **exactly what each surface renders**: `ApproachComparison` columns (incl. the new deferred-tax row), every Swift-Charts series (conversion ladder, cumulative tax, balances, heir frontier, cliff map), and every `MultiYearCPABriefing` row. Pull from the same model the views bind to, not a re-derivation.
3. **Oracle** — an **independent** recomputation from the Stage-0 spec. Two flavors, used where each fits:
   - **Exact-value** for table/CPA figures and simple series (recompute the number a different way).
   - **Property/invariant** where exact is impractical (monotone frontier; no phantom conversions; NIIT within 3.8%×(MAGI−threshold); IRMAA per-person×enrolled×2-yr-lag; fill-to-bracket lands at/under the ordinary top; MAGI ≥ AGI; deferred-tax reconciliation). This absorbs and extends the section-H invariant set.
   - The oracle must **not** call the app's engine (that would just confirm the app agrees with itself).
4. **Differ** — compares extractor vs oracle, writes one JSON packet per profile: `{profileId, inputs, displayed{...}, expected{...}, diffs[...], specRefs[...]}`. A nonzero exact diff or a violated invariant **fails the build** (this is the hard gate). Packets for all profiles (pass or fail) are emitted for Stage 2.

## 5. Stage 2 — Automated multi-model review (CLI, outside the app)

A standalone runner (language TBD in plan — Python or Node; provider-agnostic). Not in the app or its test target (keeps network out of Swift tests).

- **Input:** the Stage-1 packets + the Stage-0 Display Spec.
- **Providers:** provider-agnostic adapter; ship with OpenAI (GPT) and Google (Gemini); optionally Claude as *one voice, never the arbiter*. Keys via env vars; per-run cost logged.
- **Prompt (bounded):** "Here is a profile, what the app displays, the spec's definition of what each value should mean, and the oracle's numbers. The numbers are given — do **not** recompute them. Judge: does the definition hold? Are labels/units right? Are any tax statements (esp. CPA prose) correct? What is misleading or missing?" Structured output per display.
- **Consensus:** a flag is raised only when **≥2 models independently** raise it (configurable). Consensus-pass is silent; dissent becomes a ticket with the models' rationales.
- **Output:** a report of disagreements/flags only, ranked, for John to triage. No auto-merge, no auto-pass on LLM say-so.

## 6. Scope

Everything the Multi-Year tab renders:
- Approach-comparison table (all columns incl. deferred-tax row) + consequence strip/flags.
- The four core charts: conversion ladder, cumulative tax (plan vs nothing), account balances (+ growth band), heir-frontier scatter.
- The cliff map (MAGI cliffs / income brackets).
- The heir-frontier "Owner vs heirs" table.
- The CPA PDF report (every line, including prose statements).

Out of scope (this spec): the single-year Scenarios/Tax Summary displays (separate surface); the v2.2 *feature* work (per-year income/expense overrides, workflow integration) — the harness is built **first** so that feature work can be verified as it lands.

## 7. Cadence

Standing regression gate. Stage 1 runs on every build (fast, deterministic, fails red). Stage 2 runs per release (or on demand) since it costs API calls; its flags are advisory-to-triage, not build-breaking, because LLM review is a widening layer, not the gate.

## 8. Success criteria

- Stage 1 reproduces every known 2026-07-14 finding from a clean checkout: I1 (PA state tax), the B2 reconciliation, no-phantom-conversion (B4), MAGI-gross-up (A3), frontier non-domination (I3).
- A deliberately re-introduced wrong number fails Stage 1 without any LLM.
- A deliberately mislabeled/misdefined display is flagged by ≥2 models in Stage 2.
- The Display Spec covers 100% of the surfaces in §6 with no "TBD".

## 9. Non-goals / YAGNI

- Not a fuzzer of the tax engine internals (the section-H sweep already cleared engine arithmetic; this targets *displays*).
- LLMs do not compute projections or hold the gate.
- No hand-verified golden fixtures in v1 (option B was set aside); the oracle + property checks are the deterministic truth. Revisit if the oracle itself proves hard to trust.

## 10. Relationship to existing work

- Productionizes the **section-H invariant sweep** (backlog `2026-07-13-multi-year-fix-backlog.md`) and the parked `MultiYearInvariantTests` note.
- Consumes the finding catalog (I1/I2/I3/B2/B4/A3/A5) as its regression seed.
- Precedes the v2.2 feature work (per-year income/expense overrides + Scenarios↔Multi-Year workflow) so those land against a working display gate.

## 11. Open questions (for the plan phase)

- Stage-2 runner language (Python vs Node) and how it's invoked (make target / CI step).
- Packet schema versioning (so the spec + oracle + extractor stay in lockstep).
- How many profiles is "enough" for the standing sweep vs a nightly deep sweep.
