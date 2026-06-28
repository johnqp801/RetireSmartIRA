# Realism batch delta ledger (2026-06-26)

Conversion/terminal/objective numbers that moved because of the C3 gross-up and/or
objective PV-discounting, with attribution.

Task context:
- **C3 (Task 3):** conversion-year tax is now paid from the taxable account first;
  any shortfall is grossed-up via an extra `.traditionalWithdrawal` appended to the
  year's actions list (order: user actions, auto-RMD if any, gross-up if any).
- **PV (Task 5):** optimizer objective PV-discounts each in-horizon year's tax cost to
  base year, and discounts terminal tax by the full horizon, at `pvRealDiscountRate`
  (default 3%).

## Failing tests and their buckets

| Test | File:Line | Old expected | New expected / behavior | Attributed to | Bucket | Fix |
|---|---|---|---|---|---|---|
| "Action sequence is reflected in YearRecommendation.actions verbatim" | ProjectionEngineTests.swift:232 | `years[0].actions == [.rothConversion(30000), .hsaContribution(4300)]` | actions has a third element `.traditionalWithdrawal(~979.77)` appended | C3 gross-up (taxable==0, so engine draws from trad to fund conversion tax) | B | Updated assertion to check user actions appear as prefix; added check that exactly one gross-up withdrawal is appended |
| "Bug A: RMD computed on start-of-year trad balance, not post-conversion balance" | ProjectionEngineTests.swift:770 | `sum(all .traditionalWithdrawal amounts) ~= 37735.85` | Sum is now ~90155 (includes gross-up ~52419 for $200K conversion tax) | C3 gross-up (taxable==0) | B | Changed assertion to use `.first` instead of `.reduce(+)` — the RMD auto-withdrawal is always the first auto-generated traditional withdrawal, before the gross-up |

## Guardrail check

Both re-baselined tests involve user-specified actions (not optimizer-chosen conversions).
No optimizer-chosen conversion collapsed as a result of C3 or PV-discounting; the
guardrail criterion (in-horizon-justified conversion goes to zero) was not triggered.

The regression suite (`RealismRegressionTests.swift`) specifically guards against:
- The IRA being fully drained when taxable liquidity is constrained (`brakeStopsDrain`)
- The heir-vs-owner frontier going flat at high heir income (`frontierSpreads`)

Both new tests PASS, confirming the brake and PV discount produce the expected
qualitative behavior.

## No Bucket-A (structural invariant) failures

No tests in the "should NOT move" category failed. All monotonicity, blend,
formatting, and `lambdaZeroMatchesLegacy`-style invariant tests continued to pass.

## Suite results

Full suite: **1071 tests, 0 failures** (after re-baselines and new regression suite).
Previous run (pre-fix): 1069 tests, 2 failures.
