# Task 10: Close Phase 5b

Verbatim from `docs/superpowers/plans/2026-08-04-state-tax-phase5b-per-source.md`, then a CONTROLLER
ADDENDUM carrying what the phase actually did, which differs from what the plan assumed.

---

## The task, verbatim from the plan

### Task 10: Close Phase 5b

- [ ] **Step 1: Count.** Phase 5a closed at 99 defect cases across 32 jurisdictions. Report the delta
      and the per-jurisdiction breakdown.
- [ ] **Step 2: Run the FULL suite,** foreground, `timeout: 600000`, 0 failures.
- [ ] **Step 3: Confirm what moved in production.** Unlike 5a, Swift changed here. Show that the Swift
      diff is confined to the model extension and that no engine logic changed beyond consuming new
      fields.
- [ ] **Step 4: State the Kansas promise plainly.** Kansas had two defects. 5a fixed one. If this phase
      fixed the other, Kansas is complete and Steve can be told so without qualification, which has not
      been true at any point in this program. If it did not, say exactly what remains.
- [ ] **Step 5: Write the ledger** at `.claude/memory/roadmap/2026-08-04-state-tax-phase5b-ledger.md`,
      following the Phase 5a ledger's shape, carrying what Phase 5c inherits organised by missing model
      field.
- [ ] **Step 6: Commit.**

---

# CONTROLLER ADDENDUM

## 1. STEP 3'S PREMISE IS NO LONGER TRUE. Report that, do not massage it.

The plan expected the Swift diff to be "confined to the model extension." **It is not.** Task 9 alone
touched eight production files, adding a whole matching dimension (`matchMinAge`), a survivor dimension
threaded from `IncomeSource` through `matches()`, `DataManager`, the engine, the multi-year adapter and
the projection engine, plus a picker toggle. Tasks 3, 4, 6, 7 and 8 also changed production Swift:
three picker rows, a suppression predicate, a residence mapping, and four captions.

**Step 3 is still worth doing, but the honest version is an inventory, not a confirmation.** Enumerate
every production file this branch touched against `main`, say what each change does, and state plainly
which are additive model extensions, which are new matching behaviour, and which are user-facing. Say
that the plan's expectation did not survive contact and why. A reviewer will check this against the
real diff, so an inventory that quietly asserts confinement will fail.

## 2. THE COUNT MUST BE DERIVED, NOT REMEMBERED

Step 1's baseline is 99 defect cases across 32 jurisdictions. **Derive the current number by counting
`knownDefect` blocks across the golden fixtures**, and show the command. Then produce the
per-jurisdiction delta. Several jurisdictions deliberately did NOT move and the count must reflect that
rather than the phase's intentions.

Expect roughly this shape, and **verify every line rather than trusting it**:
- **Kansas:** all defects resolved. **Arizona:** three resolved, one deliberately pinned. **DC:** three
  resolved. **Massachusetts:** three resolved.
- **Hawaii, North Carolina, Idaho, Vermont:** deliberately UNCHANGED, all blocks intact.
- Several fixtures gained NEW pinned cases and new guard cases, so a raw count can go UP for a
  jurisdiction that was corrected. Arizona and Idaho both added cases. Report gross and net.

## 3. STEP 4, THE KANSAS PROMISE, and the two caveats that qualify it

Kansas's two defects are both fixed and Kansas is complete in the engine AND selectable in the app,
which was never true before Task 3 added the picker rows. **But state the caveats rather than a bare
"complete":**
- Schedule S Line A14 also names Thrift Savings Plans, which are defined-contribution, and the rule
  matches `definedBenefit` only, so a Kansas TSP holder is still taxed. Recorded in `knownButUnpinned`.
- `ownStateOrLocal` goes STALE ON A RESIDENCE CHANGE and errs toward UNDER-taxation. Task 3 closed the
  comparing route and NOT the moving route, and its commit message says so.

Neither touches a Kansas KPERS holder who classifies their pension, which is the reported case, so the
claim is sound for that user. Say it that precisely.

## 4. THINGS THIS TASK MUST NOT DO

- **DO NOT DELETE OR SKIP `rulesAndDisclosuresStayInLockstep`.** It is the only thing binding the
  disclosure gate to the rules gate, and removing it silently reopens the Kansas defect for every later
  jurisdiction.
- **Do not retire any disclosure artifact.** The `knownButUnpinned` entries, their deletion guards, and
  the captions are what make three deliberate no-rule decisions and two disclosed gaps defensible
  rather than silent.
- **Do not touch a pin, a `knownDefect` block, or the frozen baseline.** This is a reporting task.
- **Do not re-open a decided jurisdiction.** Hawaii, North Carolina, Idaho and Vermont each ship no rule
  by a reviewed decision. Task 9 re-opened Idaho legitimately because `matchMinAge` changed the facts;
  nothing in Task 10 changes any facts.

## 5. STEP 5, THE LEDGER, and how to organise what Phase 5c inherits

The plan says organise it by MISSING MODEL FIELD. That is the right axis and the phase produced a clear
list. At minimum, and verify each against the repo rather than this brief:

- **An employee-contributory axis.** Massachusetts needs it CATEGORICAL, Hawaii needs it a PROPORTION.
  A boolean serves MA and serves HI only at its endpoints. **John assigned this to Phase 6 on
  2026-08-05.** Do not let the catalogue read as though Hawaii's proportion is unvalidatable: a fixture
  could stipulate the share as an input.
- **A vesting-date or Bailey-class fact.** North Carolina. Judged buildable but declined, because it is
  a service-credit computation rather than a date a user holds.
- **An eligibility fact and a second age gate over one shared cap.** Idaho.
- **A second capped pool and a second AGI phase-out band.** Vermont, plus a `matchMaxIncome` sibling of
  `matchMinAge` and a decision about which income basis the gate compares against, which no Vermont
  fixture currently pins.
- **Per-taxpayer exemption attribution.** Arizona's AZ-4, which also cannot be pinned because the
  fixture schema has no owner field.
- **Residence-relative source labels.** `ownStateOrLocal` going stale on a move.
- **A structural fix for the capped per-source treatment**, which is currently banned only by a test
  sweep because `treatment` is still typed as the full `ExemptionLevel`.

Also carry the DISCLOSURE finding: three surfaces gate on a jurisdiction shipping rules or having no
fixture, so the "fixture exists, defects pinned, rules deliberately zero" case is missed by all three,
which is now Hawaii, North Carolina and Idaho. `knownButUnpinned` has no production consumer at all.

## 6. Standing constraints

- **ABSOLUTE PATHS and `git -C` only.** The controller's own shell silently reset to a different
  worktree on a different branch twice in this session.
- **NO EM DASH CHARACTERS** anywhere.
- **RUN THE FULL SUITE with `tools/run-tests.sh` IN THE FOREGROUND, `timeout` 600000**, at the COMMITTED
  state. `MultiYearPerfTests` has a known wall-clock flake; the wrapper re-runs it in isolation, and if
  that is the only failure say so explicitly rather than calling it a regression.
- **VERIFY BEFORE YOU COMPLY.** Sixteen times in this program a subagent has caught an error in the
  brief it was handed, including several of the controller's, and two would have put false statements
  into fixtures. Everything above is evidence, not fact. **This brief in particular asserts a lot about
  what the phase did; check it.**
