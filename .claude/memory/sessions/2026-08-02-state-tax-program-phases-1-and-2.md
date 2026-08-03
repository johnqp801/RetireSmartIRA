# 2026-08-02 — The state tax verification program: Phase 1 shipped, Phase 2 nearly done

**Resume at `roadmap/2026-08-02-state-tax-phase2-ledger.md`** (the SDD ledger, preserved) and
`docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md` (the 7-phase spec).

Started from Steve Nicolai's email reporting that Iowa no longer taxes retirement income. John asked
whether Iowa was the only state needing updating. It was not.

---

## 1. The audit: roughly 29 of 51 jurisdictions are defective

Full findings + sources: `roadmap/2026-08-02-full-50-state-verification.md`.

**Iowa exempts Roth conversion income by name** for anyone 55+, no cap, no income limit (HF 2317,
effective TY 2023). The app taxes it at 3.8%. For a conversion-planning tool this is the worst
possible miss: a $200k conversion shows ~$7,600 of tax that does not exist, biasing the optimizer
toward under-converting.

**Michigan, Connecticut, Virginia and Arizona overstate exemptions**, which costs users money rather
than opportunity. Michigan grants unlimited where the 2026 cap is $67,610/$135,220. Connecticut and
Virginia share a failure mode this app should care about most: **the conversion destroys the
exemption**, because a large conversion lifts AGI through their phase-outs, and the app models both
as unconditional.

**Nine states are blocked on a per-source design** (KS, MA, HI, NY, AZ, NC, ID, VT, DC): their rules
depend on which plan the money came from, which `RetirementIncomeExemptions` cannot express.

**Colorado is the cautionary case.** A syndicated advisor guide states its caps were removed for
2026. SB25-136 died in committee 2025-02-27. Acting on that source would have broken a correct
state. The false claim had already reached a code comment and a TODO telling a future engineer to
make the change.

## 2. Phase 1: COMPLETE, MERGED, PUSHED

`origin/main` @ `7e25516`. 23 commits. The app now reads 51 schema-validated JSON files instead of a
2,100-line Swift table, and **not one computed tax value changed**, proven by a three-layer gate.

Two silent-wrong-answer bugs died: `config(for:)` returned CALIFORNIA's rules for a missing state,
and a bundle failure produced an empty config in release (the guard was an `assertionFailure`, which
compiles to nothing outside debug).

**The result worth remembering:** `calculateStateTax` reads only **2 of `StateTaxConfig`'s 13
fields**. The original single-layer numeric gate was structurally blind to eleven of them, including
every state's standard deduction and the safe-harbor rules 24 states set explicitly. It would have
certified a migration that dropped all of them.

Full detail: `roadmap/2026-08-02-state-tax-phase1-ledger.md`.

## 3. Phase 2: Tasks 1-5 done, Task 6 fix in flight, NOT merged

Branch `feature/state-tax-phase2`, worktree `.worktrees/state-tax-phase2`, off main @ `7e25516`.

Built: tax-year-keyed config access, `StateTaxYearAvailability` (constant-law extrapolation is now an
inspectable fact rather than a silent assumption), the golden-scenario fixture format, single-year
and multi-year runners, and the cross-path invariant.

**Two cross-path divergences found by reading both call sites before writing any test**
(`roadmap/2026-08-02-cross-path-state-tax-divergences.md`):
- **I2**: multi-year omits `postExemptionDeduction`, so NJ's per-filer exemptions vanish there.
- **NEW, unrecorded**: `.rmd` income rows are ungated while `scenarioRetirementDistributions` is
  gated at 59.5. Multi-year synthesizes `.rmd` rows, so **a 55-year-old with IRA withdrawals gets
  the state IRA exemption in Multi-Year and is denied it in Scenarios.** Early retirees converting
  before 59.5 are a core audience.

The second finding invalidated the gate the spec wrote for Phase 2. "Green on confirmed-correct
jurisdictions" conflated CONFIG-correctness with PATH-agreement.

## 4. What this program actually taught, and it is not about state tax

The same failure recurred in six distinct costumes: **a test that looks like verification and
provides none.**

1. NJ's `.infinity` tier bound is behaviorally inert, so a round-trip test passes even if it
   collapses to 0.
2. NJ's cap pair could swap undetected because the fixture's income clamped below both.
3. `socialSecurityExempt` could vanish from the encoder because its fixture value equalled the
   default it would fall back to.
4. Two same-valued booleans could have their CodingKeys swapped, producing byte-identical JSON.
   Pigeonhole: N booleans need ceil(log2 N) fixtures for unique signatures.
5. `safeHarborRule` sits OUTSIDE what a numeric gate measures at all (it governs penalty timing,
   not the tax figure), yet 24 states set it explicitly.
6. NJ's entire golden fixture was in no pilot list, so its hand-derived value, citation and URL were
   asserted by nothing. Proven by setting the expectation to 99999.0 and watching every suite pass.

**Two controls came out of this, both now in the spec:**
- When claiming a test discriminates, **mutate the code under test, not the expectation.** Mutating
  a fixture proves only that the comparison is wired up.
- Golden fixtures carry `source` AND a resolvable `sourceURL`, and the author and reviewer must each
  state they opened the URL and checked EVERY clause. Structural assertions cannot do semantic
  matching.

**Citations were wrong three times, all authored with full confidence, all in fixtures whose numbers
were right** (so every test passed): Mississippi's combat-zone-pay paragraph instead of the
retirement one, Illinois' Schedule M (which its DOR warns causes a double-subtraction) instead of
Line 5, and Worksheet D attributed to line 28a instead of 28b.

## 5. Owed in writing, still outstanding

- **Steve Nicolai**: answers + a plan on his twelve items, due ~08-03, now thirteen with Iowa.
- **Alan Levy**: the caret fix, owed since 2026-07-19, missed 2.3.0. It is on `origin/main` now
  (`af45404`) but has NOT shipped in a build.

## 6. Where to resume

1. Let Task 6's fix land, re-review it, run the full suite, whole-branch review, merge Phase 2.
2. **Phase 4 blockers are recorded in the Phase 2 ledger and must be settled first**: the multi-year
   runner needs a funding source (a Step-7 gross-up injected $9,314 of phantom income into the only
   nonzero pilot fixture, and every Phase 4 fixture with tax due inherits it); fixtures must satisfy
   `federalAGI == components`; and every fixture must appear in a pilot list.
3. Phases 3-7 unstarted. Nothing has shipped to users; `main` is ahead of released 2.3.0.
