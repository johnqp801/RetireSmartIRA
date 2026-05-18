# 2026-05-17 — Jonggie F. — PA state tax on distributions + Roth conversion withholding

## Context

Email received from tester Jonggie F. ~30 minutes after 1.8.2 build 40 was tagged but before it was pushed to origin. Reported two issues:
1. PA state tax being applied to IRA distributions (PA exempts these for 59½+ retirees)
2. Roth conversion math doesn't account for withholding-from-the-conversion when user has no outside money to pay the tax

Issue 1 was a real correctness bug; the `RetirementIncomeExemptions` data was declared per-state but the engine wasn't reading it. Fixed in 1.8.2 build 41 (commit `cccc33c`) before push. Issue 2 is a feature gap, slated for 1.8.3.

## Original email from Jonggie

> Question with PA Sate tax on distribution and withholding tax on Roth conversion
>
> Hi,
>
> I tried to put all information and it said that I need to pay Pa state tax on my taxable income which are mainly from my IRA distribution. As I know that PA doesn't tax IRA distribution unless I am less than 59½ Yo?
>
> Also, since I don't have outside money for my Roth conversion, it doesn't calculate the actual Roth conversion after withholding tax where I can find if it is still worth conversion for heir.
>
> Best regards,
> Jonggie F.

## John's reply (sent 2026-05-17)

> Hi Jonggie,
>
> Thank you for taking the time to write this up — it's a genuinely useful report, and you're right on both points. Detailed, well-informed feedback like this is exactly what makes the app better, so I really appreciate you sending it. Thank you!
>
> On the PA state tax: you found a real bug. As you pointed out, Pennsylvania doesn't tax IRA, 401(k), or pension distributions once you've reached 59½, and the app was getting that wrong. The fix is done and going out in the next update — a retirement-age PA resident taking an IRA distribution will correctly show $0 in PA state tax.
>
> On the Roth conversion: you're also right that when there's no outside cash to cover the tax, the app should show what actually lands in the Roth after withholding — that net amount is what the heir comparison should be built on. I'm adding an option to choose whether the conversion tax is paid from outside money or withheld from the conversion itself, and the heir-benefit math will use the real net figure either way. That's slated for the release after this one.
>
> One note for your own planning on the PA side: at retirement age (59½+), Pennsylvania generally doesn't tax the conversion itself either, so the withholding decision mainly affects your federal tax and how much actually reaches the Roth. The app will reflect that correctly once the conversion option is in.
>
> I'll let you know as soon as the updates are live. Thanks again — reports this specific genuinely move the app forward. And please don't hesitate to send along any other issues or ideas that would make RetireSmartIRA more valuable to you.
>
> Best,
> John

## Resulting work

### Issue 1 — PA state tax on retirement distributions (FIXED in build 41)

**Diagnosis:** The codebase had `RetirementIncomeExemptions` struct with `pensionExemption` and `iraWithdrawalExemption` fields, and PA's config correctly declared both as `.full`. But `calculateStateTaxFromGross` was not consuming these fields — they were declared but unused. Affects PA, IL, MS, MI (declared `.full`), plus partial-exemption states (GA, CO, KY, NY, NJ, VA, AL, MD).

**Fix (commit `cccc33c`, branch `1.8.2/incremental`, tag `v1.8.2-build41`):**
- New `DataManager.scenarioRetirementDistributionIncome` accessor sums `.pension`, `.rmd`, `.militaryRetirement` IncomeType rows + `scenarioTotalWithdrawals` (RMDs, extra withdrawals, inherited IRA distributions). Roth conversions explicitly excluded (PA-specific exemption deferred — see below).
- Wired `pensionExemption` + `iraWithdrawalExemption` through 6 call sites in DataManager (`scenarioStateTax`, `estimatedThisYearCostAtAGI`, `totalTaxFor`, `extraWithdrawalTaxImpact`, `qcdTaxSavings`, `inheritedExtraWithdrawalTaxImpact`) + `stateTaxBreakdown` helper.
- Age gate: 59½ universal threshold (`primaryAge >= 59 || (enableSpouse && spouseAge >= 59)`). Per-state variations (NJ 62, pre-SB25-136 CO 65) noted as approximations in TODO.
- Handles `.full` / `.partial(maxExempt)` / `.none` correctly via a `mostRestrictiveExemption` helper when pension and IRA levels differ.
- Build bumped 40 → 41. Tag moved from `v1.8.2-build40` (deleted) to `v1.8.2-build41`.

**Verification:** Jonggie's reported scenario constructed as a test case — PA resident, age 65, $50K extra withdrawal, $0 wages → PA state tax = $0 (was ~$1,535 pre-fix). Test name: `paRetirementAgeIRAFullyExempt`.

**Test count delta:** +11 new tests in `StateRetirementExemptionTests` covering PA/IL/MS/GA/CA at retirement age vs early withdrawal, partial-cap math, and Jonggie's exact scenario. 4 pre-existing NY-scenario tests in `RetireSmartIRATests.swift` (`b_stateTax`, `b_totalTax`, `d_stateTax`, `d_totalTax`) had expected values updated by $1,170–$1,370 each — NY's $20K IRA cap is now correctly applied to scenario-level auto-calc RMDs that were previously being missed.

### Issue 2 — Roth conversion with tax withheld from the conversion (1.8.3 candidate)

Not fixed in 1.8.2. Slated for 1.8.3. Required work:
- UI toggle in TaxPlanningView or per-scenario: "pay conversion tax from outside money / pay tax via withholding"
- Engine plumbing: when withholding mode is active, compute net Roth deposit = conversion − (conversion × marginal rate)
- Heir-comparison card (L3, shipped in commit `2846fc0`): rework so the comparison reflects the actual net Roth amount when withholding mode is active. Currently assumes outside money → 100% of conversion lands in Roth.
- Consider whether early-withdrawal penalty applies to the withheld portion (under 59½ would face 10% penalty on the tax withheld since it's effectively a distribution). For 59½+ users, no penalty — clean.

### Known follow-up TODOs (documented in code at TaxCalculationEngine.swift `applyRetirementExemptions`)

1. **Verified-2026 stale exemption value corrections** (from the research dispatched during the build-41 fix):
   - **Colorado**: codebase says `.partial($24,000)` for 65+; real 2026 is **unlimited** for pension/annuity income (SB25-136, effective TY 2026).
   - **Alabama**: codebase says `.partial($2,500)` pensions, `.none` IRA; real 2026 is **$12,000 for 65+** (HB388 doubled it from $6K effective 1/1/2026). DB pensions still fully exempt; IRAs/401(k)s do NOT qualify as DB pensions.
   - **Maryland**: real 2026 is **$40,600** for age 65+ (up from $39,500 TY 2025); only employer pensions / 401(k) / 403(b) qualify — IRAs do NOT qualify.
   - **Michigan**: codebase says `.full`; real 2026 final phase-in is **$67,610 single / $135,220 MFJ** for born 1946+. Codebase currently overstates.
   - **Kentucky**: codebase has $31,110; HB146 to $41,110 pending — verify enactment status before TY 2026.
   - **Georgia**: codebase has $65K (matches 65+ tier); missing the $35K tier for ages 62-64.
   - **New York**: codebase has $20K (verify); public NY/federal/military pensions get a SEPARATE unlimited exemption — if codebase treats all pensions as $20K-capped, it under-exempts public retirees.
   - **New Jersey**: tiered phaseout at $100K-$150K AGI not yet modeled.
   - **New Hampshire**: I&D tax repealed effective TY 2025 (HB 2, 2023) — confirm codebase reflects.

2. **PA Roth conversion exemption** per PA DOR Answer 274: conversions are NOT taxable in PA in the conversion year, provided the full pre-tax balance is deposited into the Roth (any amount withheld for federal tax IS PA-taxable as distribution). This materially affects heir-comparison math for PA users. Filing as separate task because state-by-state Roth-conversion treatment differs and deserves its own analysis. Mentioned to Jonggie in the reply.

3. **Per-owner attribution**: when distributions can be attributed to specific spouse (your-vs-spouse), apply age gating per-owner instead of "either spouse 59½+".

4. **Pension vs IRA distinction**: when the engine can distinguish pension vs IRA portions of the retirement income stream, apply `pensionExemption` and `iraWithdrawalExemption` independently rather than the most-restrictive merge.

## Tester-feedback workflow notes

This is a model case of how a single tester report should drive engineering:
1. **Validation first.** Don't just trust the user; verify the tax law from primary state DOR sources before changing code.
2. **Investigate the architectural shape of the bug.** Is it a one-state issue or a broader engine gap? Here it was the latter — the engine wiring was missing for ALL states with declared exemptions.
3. **Scope discipline.** The research surfaced 8+ states with stale declared values. Updating all of them is its own audit project. The minimum-viable fix wires the engine to consume existing declared values + documents the known stale data in TODOs — let perfect not be the enemy of shipping the user's reported fix.
4. **Verify the user's specific scenario as a test.** Don't just generalize — construct the actual reported case as a regression test (`paRetirementAgeIRAFullyExempt`).
5. **Hold the release.** 1.8.2 was tagged but not pushed when the report came in. Fixing pre-push was much cleaner than shipping then patching.
6. **Don't claim perfect.** John's reply is honest about what's fixed now vs. what's coming next, and the in-code TODOs document known approximations rather than papering over them.

## Next steps

- Push branch `1.8.2/incremental` + tag `v1.8.2-build41` to origin
- TestFlight submission with build 41
- Notify Jonggie when TestFlight build 41 is live
- File 1.8.3 features:
  - Roth conversion withholding toggle + net-Roth heir-comparison rework
  - PA-specific Roth conversion exemption (per PA DOR Ans 274)
- File 1.8.4 (or general housekeeping):
  - Verified-2026 stale exemption value corrections (CO/AL/MD/MI/KY/GA/NY/NJ/NH)
  - Per-state age threshold variations
  - Per-owner attribution + pension/IRA distinction
