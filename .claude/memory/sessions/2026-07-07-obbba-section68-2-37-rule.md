# Session Summary — OBBBA §68 Overall Itemized-Deduction Limitation (2/37 rule)

**Date:** 2026-07-07
**Branch work:** `claude/blissful-lehmann-34cb01` → merged to `main` (`--no-ff`, commit `11cf855`) → pushed to `origin/main`

---

## What happened

Built the "35% cap" that was *filed* (not built) during the 2026-07-07 charitable-floor session — the OBBBA §68-as-amended overall limitation on itemized deductions, the "2/37 rule." Low-priority engine enhancement; TDD throughout. This closes the backlog item the memory index tracked as "35% cap filed."

### Statutory mechanism (confirmed before coding, per CLAUDE.md)

Verified against IRC §68 text (Cornell LII) + Thomson Reuters + Greenleaf Trust. For an itemizer whose taxable income **before** the itemized deduction exceeds the 37%-bracket threshold, itemized deductions are reduced by:

```
2/37 × min( total itemized deductions,  income_before_itemized − 37%_threshold )
```

- **The subtle part** — amount (2) uses income **before** the itemized deduction is subtracted. Pinned by the statute's own "increased by such amount of itemized deductions" clause and the Thomson Reuters Max & Penny worked example ($850k income, $41,750 post-floor itemized → reduction $41,750 × 2/37 = $2,257). One of the 7 tests (`reducesByExcessWhenExcessIsLesser`) exists specifically to distinguish before-vs-after: income $660k, itemized $50k → after-deduction taxable income ($610k) is *below* the threshold, but the reduction still applies to the $19,400 pre-deduction excess. An after-itemized implementation would wrongly return 0.
- Applied AFTER all other floors/phaseouts, including the already-modeled 0.5% charitable AGI floor.
- Net effect: caps marginal benefit near 35¢/dollar instead of 37¢.
- Federal only; does **not** touch AGI or state. 2026 thresholds: single $640,600 / MFJ $768,700 (read from `federalBracketsSingle/MFJ`, top ordinary bracket).

### Implementation

- **`DataManager.swift`** — new `itemizedOverallLimitationReduction` (gated on `scenarioEffectiveItemize` + `currentYear >= config.itemizedOverallLimitationFirstYear` + income over threshold); private `topOrdinaryBracketThreshold` reads the top bracket from the config brackets (no new threshold field). `effectiveDeductionAmount` subtracts the reduction on the itemized path only, so it flows into `scenarioTaxableIncome` → raises federal tax for top-bracket itemizers.
- **`TaxYearConfig.swift`** — added `itemizedOverallLimitationRate` (2/37 = 0.05405405405405406) + `itemizedOverallLimitationFirstYear` (2026) to the schema and the hardcoded fallback; added to all four `tax-*.json`.
- **`ItemizedDeductionOverallLimitationTests.swift`** (new) — 7 tests: itemized-is-lesser, excess-is-lesser (pins before-itemized reading), below-threshold, pre-2026, standard-path, MFJ-threshold, post-charitable-floor interaction.

### Design decisions

- Amount (1) uses `totalItemizedDeductions` **including** the senior bonus, per the task spec. Numerically a no-op: the senior bonus is always fully phased out to $0 at 37%-bracket income.
- `recommendedDeductionType` still compares the **gross** itemized total vs standard — the ~5.4% haircut never flips the itemize-vs-standard choice in the 37% bracket (itemized dwarfs standard there).
- No existing itemizer test encoded 37%-bracket pre-cap behavior, so none needed updating (the charitable-floor tests all run at $200k–$400k, below the threshold).

### Verification

TDD cycle observed: RED (7 failures, missing member) → GREEN (7/7) → **full suite 1,196 tests, 0 failures** (`xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`). No em dash in any added line.

### Git

- Committed on `claude/blissful-lehmann-34cb01` (`8a1fd12`).
- Decision-log entry appended (newest-at-top) to `.claude/memory/decisions/log.md`.
- `main` had diverged (2 docs/memory commits: V2.0.1-live + Chris Viscomi note) — merge base `d9c4759`. Not a fast-forward. `main` is checked out in the `.worktrees/main-baseline` worktree, so merged there with `git -C … merge --no-ff` (matching the prior `Merge fix/charitable-agi-floor into main` pattern). Clean merge — main's commits touched only memory drafts/roadmap, zero overlap with the code or the decision log.
- Pushed: `61738a5..11cf855  main -> main`.

---

## State of main after this session

| Commit | Description |
|--------|-------------|
| 11cf855 | Merge claude/blissful-lehmann-34cb01 into main |
| 8a1fd12 | feat(deductions): apply OBBBA §68 overall itemized-deduction limitation (2/37 rule) |
| 61738a5 | docs(memory): Chris Viscomi 2.0.1-live note SENT |

`main` in sync with `origin/main`.

---

## Open items / next steps

- **Stale task chip:** the 35%-cap was originally spawned as background task `task_bf6c96bd` in the charitable-floor session. Now built, but task IDs don't persist across app restarts so it couldn't be dismissed from this session — dismiss manually if still showing.
- **No UI surfacing yet.** The 0.5% charitable floor got an itemized-breakdown line ("0.5% AGI Floor" / "Deductible Charitable"); the 2/37 reduction is engine-only for now (no breakdown line, no disclosure copy). Consider whether the itemized breakdown should show the §68 haircut for the narrow 37%-bracket audience. Not done this session.
- **iOS/Mac build:** binary changed (engine + config), so a new build is required before any App Store submission that should include this. Not versioned/bumped this session.
