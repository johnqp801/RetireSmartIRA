# Fred's Inherited IRA Chart Bug — Diagnosis

**Date:** 2026-05-09
**Investigator:** Claude (Opus, V1.8.1 Task 5.1)
**Bug:** NEDB inherited IRA shows 100% RMD in year 1 of projection bar chart instead of 10-year distribution

## Engine math verification

`RMDCalculationEngine.swift:73` `calculateInheritedIRARMD()` and `RMDCalculationEngine.swift:340` `projectInheritedIRA()` are correct for the NEDB cases:

- **NEDB pre-RBD (post-SECURE)** — `RMDCalculationEngine.swift:298-304`: returns `annualRMD = 0` for years before deadline, with `mustEmptyByYear = yearOfInheritance + 10`.
- **NEDB post-RBD (post-SECURE)** — `RMDCalculationEngine.swift:305-321`: returns small annual RMD via `balance / factor` for years 1..9, full balance once `year >= deadline`.
- **Deadline year** — `RMDCalculationEngine.swift:289-296`: returns full `account.balance` and `isDeadline = true`.

`projectInheritedIRA()` correctly bounds `lastYear = max(deadline, currentYear)` (line 369-373) when a deadline exists, so the projection array always includes the deadline row (year `yearOfInheritance + 10`). It snapshots the running balance into `snapshot.balance` (line 382-383) before delegating to `calculateInheritedIRARMD`, ensuring per-year balances are correctly tracked.

Engine math is therefore consistent with IRS rules. The bug is in how the chart consumes the projection data.

## Chart location

`RetireSmartIRA/RMDCalculatorView.swift`

- Chart data construction: `rmdChartData` at lines **721-784**.
- Inherited-IRA per-year aggregation block: lines **762-781**.
- Chart render (`BarMark`): lines **857-864**, inside `rmdProjectionChart` (line 797).

The wide-layout (iPad/Mac) places the LEFT-side `inheritedIRASection` (current-year RMD numbers) and RIGHT-side `rmdProjectionChart` in two separate scroll columns (`RMDCalculatorView.swift:53-78`), which matches Fred's "left/right" framing.

## Data flow

1. `rmdProjectionChart` reads `chartData = rmdChartData` (line 800).
2. `rmdChartData` loops `for yearOffset in 0..<projectionYears` (line 724), where `projectionYears` defaults to 10 (line 14) and is selectable 5/10/15/20 via segmented picker (line 1002).
3. For each `projectedYear = currentYear + yearOffset`, it calls `RMDCalculationEngine.projectInheritedIRA(...)` once **per inherited account** (line 769) and then does `projections.first(where: { $0.year == projectedYear })` (line 775) to pluck that year's row, summing `row.rmd` into `inheritedRMD` and emitting one `RMDChartDataPoint` per (year, "Inherited IRA") pair (line 781).
4. `BarMark` stacks the two categories ("IRA / 401(k)" and "Inherited IRA") at each x-tick.

The LEFT side (`inheritedIRASection`, line 528-613) calls `dataManager.calculateInheritedIRARMD(account, forYear: dataManager.currentYear)` (line 538) — same engine, current year only. Because both sides use `RMDCalculationEngine.calculateInheritedIRARMD` against the same account, they should agree on year-1 (= currentYear) values.

## Root cause

**Most likely root cause: the chart's loop bound `0..<projectionYears` (default 10) fails to include the deadline year of a freshly-inherited NEDB account, while a different display path correctly includes it — and a separate projection-rebuild quirk produces a misleading "deadline-only bar" that a user reads as 100% in year 1.**

After a careful trace I cannot find a code path that would literally produce `inheritedRMD = account.balance` at `yearOffset = 0` while leaving the LEFT side computing $0 / small RMD, because both code paths funnel through `RMDCalculationEngine.calculateInheritedIRARMD` against `account.balance` at `forYear: currentYear`. They are guaranteed to agree at year 1.

The two suspicious chart-side behaviors I CAN confirm from the code:

### Issue A — chart window omits the deadline for a freshly-inherited NEDB

For an NEDB account where `yearOfInheritance == currentYear` (just inherited) the deadline is `currentYear + 10`. The chart loop iterates `0..<10` (years `currentYear..currentYear+9`) and never queries projection year `currentYear+10`, so the deadline bar is never plotted. With `projectionYears = 10` the user sees:

- Pre-RBD: ten zero-height bars (looks empty).
- Post-RBD: ten small bars and **no** terminal "100% remaining balance" bar.

This is a chart-vs-table inconsistency. The TABLE (`inheritedIRAProjectionsSection`, line 1260-1397) uses `ForEach(projections)` and renders the full 11-row engine output, including the deadline. The CHART truncates at `projectionYears` years from currentYear regardless of where the deadline actually falls.

### Issue B — for an inheritance occurring before currentYear, the chart's "year 1 = currentYear" bar IS the engine-correct value, but if `yearOfInheritance + 10 ≤ currentYear` the engine returns full balance for currentYear (line 289-296 path)

This matches "100% in year 1" in the chart — but it would ALSO produce "100% in current year" on the LEFT side (`inheritedIRASection`). Fred says LEFT is correct (small RMD), so this scenario is inconsistent with his report unless there is a state-mismatch I cannot reproduce by inspection.

### Buggy code

The loop range that drives the chart:

```swift
// RMDCalculatorView.swift:724
for yearOffset in 0..<projectionYears {
    let projectedYear = dataManager.currentYear + yearOffset
    ...
    if dataManager.hasInheritedAccounts {
        for account in dataManager.inheritedAccounts {
            let projections = RMDCalculationEngine.projectInheritedIRA(
                account: account,
                currentYear: dataManager.currentYear,
                projectionYears: projectionYears,
                growthPercent: growthRate
            )
            if let row = projections.first(where: { $0.year == projectedYear }) {
                inheritedRMD += row.rmd
            }
        }
    }
    data.append(RMDChartDataPoint(year: projectedYear, yearLabel: label, amount: inheritedRMD, category: "Inherited IRA"))
}
```

The loop bound `0..<projectionYears` is the wrong window for inherited accounts because their meaningful timeline runs `currentYear...(yearOfInheritance + 10)`, not `currentYear...(currentYear + projectionYears - 1)`.

Additionally, `projectInheritedIRA` is recomputed for the same account once per outer loop iteration (per yearOffset). The engine's `projectInheritedIRA` is deterministic in its inputs, so the result is identical each call — but it is wasteful and, more importantly, decouples the chart from the projection it should be displaying directly.

## Proposed fix

Two related changes in `RMDCalculatorView.rmdChartData` (lines 721-784):

1. **Build the inherited bars from the projection itself rather than re-querying it inside the year-offset loop.** Compute each account's projection once, then iterate `projection` rows to populate `RMDChartDataPoint`s (using `row.year` for the x-axis and `row.rmd` for the height). This guarantees the chart always shows the same year/RMD pairs the table renders, including the deadline row.

2. **Extend the chart's x-domain to cover all inherited-account deadline years.** Compute `let chartLastYear = max(currentYear + projectionYears - 1, inheritedAccounts.compactMap { engine.deadlineFor($0) }.max() ?? currentYear)` and iterate that range when building points. This ensures a freshly-inherited NEDB's terminal "100% balance" bar is visible at year 10 (or year 11 for post-RBD edge cases).

Concretely, restructure to:

```swift
private var rmdChartData: [RMDChartDataPoint] {
    var data: [RMDChartDataPoint] = []

    // 1. Determine the chart's year window — extend past projectionYears
    //    to include any inherited-account deadlines.
    let inheritedProjections: [(account: IRAAccount, rows: [RMDCalculationEngine.InheritedProjectionRow])] =
        dataManager.inheritedAccounts.map { account in
            let growthRate = account.owner == .spouse ? dataManager.spouseGrowthRate : dataManager.primaryGrowthRate
            return (account, RMDCalculationEngine.projectInheritedIRA(
                account: account, currentYear: dataManager.currentYear,
                projectionYears: projectionYears, growthPercent: growthRate))
        }
    let lastInheritedYear = inheritedProjections.flatMap { $0.rows.map(\.year) }.max() ?? dataManager.currentYear
    let lastYear = max(dataManager.currentYear + projectionYears - 1, lastInheritedYear)

    for projectedYear in dataManager.currentYear...lastYear {
        let yearOffset = projectedYear - dataManager.currentYear
        let label = "'\(String(projectedYear).suffix(2))"

        // Regular RMD as before, but only when within projectionYears window
        var regularRMD: Double = 0
        if yearOffset < projectionYears {
            // ... existing primary + spouse logic ...
        }
        data.append(RMDChartDataPoint(year: projectedYear, yearLabel: label, amount: regularRMD, category: "IRA / 401(k)"))

        // Inherited: pull directly from the projection rows.
        var inheritedRMD: Double = 0
        for (_, rows) in inheritedProjections {
            if let row = rows.first(where: { $0.year == projectedYear }) {
                inheritedRMD += row.rmd
            }
        }
        data.append(RMDChartDataPoint(year: projectedYear, yearLabel: label, amount: inheritedRMD, category: "Inherited IRA"))
    }
    return data
}
```

If after this fix Fred still reports "100% in year 1", the next investigation step would be to capture his actual account inputs (yearOfInheritance, decedentRBDStatus, beneficiaryBirthYear, decedentBirthYear, balance, currentYear) — the static-trace analysis in this report cannot reproduce a state where the LEFT side shows a small annual RMD while the SAME engine call from the chart produces full balance at year 1.

## Test approach

Add a unit test in the existing RMD-engine test suite that exercises the chart-data construction (or its extracted helper) end-to-end:

1. **Fresh NEDB, post-RBD, post-SECURE** — `yearOfInheritance = currentYear`, `decedentRBDStatus = .afterRBD`, balance = $250K, beneficiaryBirthYear set so factor ≈ 25. Build `rmdChartData` (or a refactored testable helper); assert:
   - Year 1 bar amount is small (`< balance / 5`).
   - The chart series contains a bar at year `currentYear + 10` whose amount is approximately the balance net of accumulated withdrawals (the deadline drain).
   - The bar series length is `≥ 11` (covers the deadline).

2. **Fresh NEDB, pre-RBD** — same as above but `decedentRBDStatus = .beforeRBD`. Assert:
   - Years 1..10 bars all amount = 0.
   - Year 11 bar amount ≈ balance × growth^10 (full deadline drain).
   - Bar series length is `≥ 11`.

3. **Regression — old NEDB past-deadline** — `yearOfInheritance = currentYear - 11`. Assert that the chart's year-1 bar matches `dataManager.calculateInheritedIRARMD(account, forYear: currentYear).annualRMD` (i.e., chart and LEFT side agree).

Optionally also add a UI snapshot test of `rmdProjectionChart` for the fresh-NEDB-post-RBD scenario to lock the visual: small bars years 1-10, large bar at year 11.
