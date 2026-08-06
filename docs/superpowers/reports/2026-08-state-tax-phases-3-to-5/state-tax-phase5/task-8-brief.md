# Task 8 brief: close Phase 5a


---

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md`. **Two amendments apply and are recorded in `.claude/memory/decisions/log.md` (2026-08-04):** (1) base-value defects are corrected BEFORE the retirement-exemption tiers, because they hit every filer rather than only retirees; (2) Phase 4's golden scenarios stand in for the two-model confirmation protocol, so no external model pass gates these corrections.
- **THIS IS THE FIRST PHASE IN THE PROGRAM WHERE NUMBERS MOVE.** Phases 1 through 4 each ended with `git diff main -- RetireSmartIRA/` empty. That is no longer the goal and no longer possible. What replaces it is attribution: every moved value must be traceable to a named golden case citing a state's own published form.
- **Never regenerate the frozen baseline wholesale.** `RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json` holds 1,020 entries (51 jurisdictions x 20 scenarios) captured before Phase 3a. Its own test file says regeneration "is legitimate only in Phase 5, where each moved value is attributable to a named golden scenario citing a state's own published form." Task 1 builds the mechanism that enforces that sentence. Until it exists, correct nothing.
- **A golden case going green is the deliverable, not a green suite.** Deleting a `knownDefect` block is how a correction is declared complete. The block's own second assertion forces this: once the engine matches the form, the test fails with "delete the knownDefect block."
- **Do not touch OK, AR or SC in this plan.** Their `expectedStateTax` values are computed against the app's CONFIGURED brackets, which are themselves wrong, so correcting their base values without re-deriving their golden expectations in the same change turns meaningful pins into meaningless ones. They carry an explicit `PHASE 5 WARNING`. They are Phase 5b work, paired with the re-derivation.
- **NO EM DASH CHARACTERS** in any file, including JSON strings, code comments and reports. Standing user preference and a recurring review finding on this project.
- **Tests are the source of truth** (CLAUDE.md). Baseline at branch point: 1,856 Swift Testing in 292 suites + 509 XCTest, 0 failures, 6 pre-existing env-gated skips. `MultiYearPerfTests` has a known pre-existing wall-clock flake; re-run it in isolation rather than calling it a regression.
- **Never edit by chained `cd`.** Bash cwd resets between calls. Use absolute paths and `git -C`.
- **Never background an xcodebuild command.** Run it FOREGROUND with the Bash tool's `timeout` parameter set to 600000. Three agents died in Phase 4 by backgrounding builds; the 120 second default is not the ceiling.

**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5`, branch `feature/state-tax-phase5`, off `main` @ `2b4f4c1`.

**Build command:**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

---

### Task 8: Close Phase 5a

**Files:**
- Create: `.claude/memory/roadmap/2026-08-04-state-tax-phase5a-ledger.md`

- [ ] **Step 1: Count what moved.**

```bash
python3 -c "
import json,glob,collections
tot=0; st=collections.Counter()
for f in sorted(glob.glob('/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRATests/GoldenScenarios/*.golden.json')):
    d=json.load(open(f))
    n=sum(1 for s in d['scenarios'] if s.get('knownDefect'))
    tot+=n
    if n: st[d['state']]=n
print('defect cases remaining:',tot,'across',len(st),'jurisdictions')
m=json.load(open('/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5/RetireSmartIRATests/Baselines/statetax-behavior-movements-2026.json'))
print('baseline values moved:',len(m),'across',len({x[\"state\"] for x in m}),'jurisdictions')
"
```

Phase 4 closed with 118 defect cases across 35 jurisdictions. Report the delta.

- [ ] **Step 2: Run the FULL suite** and confirm 0 failures.

- [ ] **Step 3: Confirm production changes are confined to config data.**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5 diff --stat main -- RetireSmartIRA/
```

Expected: ONLY files under `RetireSmartIRA/Resources/StateTaxData/2026/`. **Any `.swift` file here means this plan's scope boundary was crossed and it must be justified or reverted.** This replaces Phase 4's empty-diff check: the diff is no longer empty by design, but it must still be confined.

- [ ] **Step 4: Write the ledger**, following `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md`. It must carry: every correction with its authority; every baseline movement grouped by jurisdiction; every `knownDefect` still standing and the field it waits on; and an explicit statement of what Phase 5b inherits.

- [ ] **Step 5: State the promises plainly.** Kansas and Iowa are the two written commitments. Say whether each is fully corrected, partially corrected, or not, and for Kansas name precisely which of its two defects remains. **Steve was promised both. A half-corrected Kansas described as "fixed" would be the failure this program has been trying to avoid all along.**

- [ ] **Step 6: Commit.**

---
