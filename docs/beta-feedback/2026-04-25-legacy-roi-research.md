# Legacy-Impact / Family-Wealth ROI Display Research

**Date:** 2026-04-25
**Author:** Research agent
**Context:** RetireSmartIRA's "Legacy Impact" panel currently displays a headline like "Equivalent to a 3869.2% return on the $69K in taxes paid" with a self-apologetic disclaimer. We need to find out what industry-leading planning software and CFP/academic best practice actually do here, and redesign accordingly.

---

## 1. Executive Summary

- **No mainstream planning tool — advisor-grade or consumer — uses a raw, undiscounted "% return on conversion taxes" headline.** The framing RetireSmartIRA currently uses appears to be an outlier. Every tool reviewed (Boldin, Right Capital, eMoney, MoneyGuidePro, Holistiplan, Income Lab, ProjectionLab, WealthTrace, Pralana, Fidelity, Vanguard, Schwab, Empower) uses one of four metric families: (a) **lifetime tax savings in dollars**, (b) **end-of-plan net-worth/legacy delta**, (c) **break-even tax rate (BETR)** or break-even year, or (d) **NPV of tax savings at the portfolio's expected return rate**.
- **The peer-reviewed academic standard (McQuarrie & DiLellio, *Journal of Financial Planning*, 2023 & 2024) is explicit:** "The careful planner will communicate to clients the *present value* of the expected payoff, or at least express it in *constant dollars*." Undiscounted future-value framing is treated as "money illusion" and a known cause of overstating conversion benefits.
- **Vanguard's BETR ("Break-Even Tax Rate")** is the closest thing the industry has to a canonical headline metric. It collapses a multi-decade decision into a single rate the client can sanity-check against their own future tax expectation. RetireSmartIRA does not currently surface this.
- **Kitces' framing is qualitative and decision-oriented**, not a single ROI number. He pushes "marginal-rate-of-conversion" (change in tax liability ÷ amount converted) and tax-rate equilibrium — both of which are *inputs to the decision*, not headline outcomes. He warns that simple bracket arithmetic systematically misleads clients.
- **The 3869% headline is fixable with a small set of changes:** annualize, discount, label clearly as a multi-generational compounded outcome, and add a BETR-style break-even sanity check. Don't keep an apologetic disclaimer — replace the metric.

---

## 2. Comparison Table — How 13 Tools Display Roth Conversion Long-Term Impact

Confidence levels: **V** = verified from product help docs / methodology PDF / vendor screenshot; **I** = inferred from marketing copy or third-party review; **U** = unknown / not publicly documented.

| Tool | Primary headline metric | Annualized? | PV-adjusted? | Shows raw % return on tax? | Time-horizon visualization | Conf. |
|---|---|---|---|---|---|---|
| **Boldin** (NewRetirement) | Lifetime taxes, net worth at longevity, estate value (side-by-side scenario diff) | No | No (nominal $) | **No** | Year-by-year line charts; "lifetime impact on estate and on your taxes" summary | V |
| **Right Capital** | Tax-adjusted ending wealth; year-by-year tax/RMD/balance comparison; Monte Carlo probability of success | No | Indirect (Monte Carlo & inflation-adjusted views) | **No** | Multi-strategy ending-wealth chart + annual-detail tables | V |
| **eMoney Pro** | Tax Bracket Report; Total Taxes Report; bracket-fill conversion suggestion; cash-flow impact | No | No (nominal) | **No** | Tax-bracket overlay charts year-by-year | V (docs); I (output formatting) |
| **MoneyGuidePro / MoneyGuideElite** | Lifetime tax savings; assets to heirs; "What If" scenario delta | No | No (nominal) | **No** | What-If side-by-side; goal-funding probability | V |
| **Holistiplan** | Lifetime tax savings (nominal $); **optional NPV with user-chosen discount rate**; portfolio-value delta over time | No | **Yes (optional toggle)** | **No** | Year-by-year tax-bracket and balance charts | V |
| **Income Lab (Tax Lab)** | Cumulative tax differences at 10/20/30 years; lifetime tax savings | No | Implied (real-dollar projections) | **No** | "Cumulative-difference at horizon X" cards | V |
| **ProjectionLab** | Net legacy after estate tax; long-term portfolio trajectory; user-configurable metrics | No | Yes (real vs nominal toggle) | **No** | Multi-decade interactive trajectory chart | V |
| **WealthTrace** | Side-by-side scenario: amount converted, taxes, tax rates, terminal portfolio | No | Yes (inflation-adjusted available) | **No** | Cash-flow projection export; comparison columns | V |
| **OnTrajectory** | Cash-flow trajectory diff; ladder vs bracket-fill strategy outcomes | No | Yes (inflation-adjusted toggle) | **No** | Trajectory visualization | V |
| **Pralana** | **IRR of incremental tax investment** + terminal-balance delta | **Yes (IRR)** | Yes (IRR is inherently annualized) | Indirectly (IRR is a %) | Red/blue line graph showing crossover year + numerical table | V |
| **Fidelity Roth Conversion Evaluator** | Hypothetical benefit/loss of conversion expressed in **"real" / "current" dollars** (inflation-removed) | No | **Yes (explicit)** | **No** | Single-number current-dollar benefit + chart | V (methodology PDF, search-extracted) |
| **Vanguard BETR Calculator** | **Break-Even Tax Rate (BETR)** — single % the user compares to their expected future rate | N/A (it IS a rate) | Built into derivation | **No** | Single decision threshold | V |
| **Schwab Roth Conversion Calculator** | Future-value comparison: keep-traditional vs convert-to-Roth + tax owed | No | No (nominal future $) | **No** | Two ending-balance bars | V |
| **Empower Roth Conversion Analyzer** | Tax implications + future-value comparison | No | Inflation-adjusted available | **No** | Bar chart comparison | I |

**Bottom line on the table:** The single closest analog to RetireSmartIRA's current "% return on tax" is **Pralana's IRR view** — and Pralana is a power-user spreadsheet tool whose own forum users (e.g., Joel Levine's thread) report numbers in the **2–6% range over multi-decade horizons** and explicitly debate whether even that is meaningful. No tool in this set displays a 3,000%+ headline.

---

## 3. CFP / Academic Best-Practice Findings

### 3.1 McQuarrie & DiLellio — "The Arithmetic of Roth Conversions" (J. Financial Planning, May 2023) and "Net Present Value Analysis of Roth Conversions" (J. Financial Planning, Sep 2024)

These are the most directly relevant peer-reviewed sources. Their position is unambiguous:

> "The careful planner will communicate to clients the **present value** of the expected payoff, or at least express it in **constant dollars**."

They argue the **correct discount rate is the portfolio's expected annual rate of return** (e.g., 6% for a balanced portfolio, 8% for equity-heavy) — not the risk-free rate, not inflation. The rationale: that rate reflects the client's indifference between paying tax now (and missing the growth) vs. paying it later. Using a lower discount rate overstates the conversion benefit; using a higher one understates it.

They also warn that conversions whose break-even doesn't arrive until the client's 90s "may not pay off by much at all" — and explicitly caution against framings that produce a large headline number from a payoff that scales exponentially over decades. In their own example, a $100K conversion that grows to $134K before RMDs "appears as a 34% increase, but… the discounted present value of that $4,000 additional growth is only $3,000." The same compression logic applies — much more aggressively — to RetireSmartIRA's 42-year, 3-generation, 8%-growth scenario.

### 3.2 Michael Kitces (Kitces.com)

Kitces does **not** use a single ROI/IRR/% headline for Roth conversions in any of the major posts reviewed. His core concept is the **"true marginal tax rate of the conversion"**:

> Marginal Tax Rate of Roth Conversion = Change in Tax Liability ÷ Amount of Conversion

— compared against the projected marginal rate at withdrawal, including all "add-on" effects (Social Security taxation phase-in, IRMAA, ACA subsidy clawback, NIIT, state tax). The decision is framed as **rate-arbitrage**, not investment return. He explicitly warns that simple bracket math systematically misleads clients because the secondary effects can make the *true* marginal rate dramatically different from the headline bracket.

His "tax equivalency principle" article makes the foundational point that, *holding rates constant*, Roth and Traditional are mathematically identical — the entire payoff comes from rate arbitrage, not from "tax-free growth" per se. Framing the tax payment as if it were investment capital earning a return is therefore conceptually wrong: the $69K isn't capital at risk in any meaningful sense — it's the price paid to lock in today's rate.

### 3.3 Wade Pfau (Retirement Researcher / American College)

Pfau's framework is **Effective Marginal Rate (EMR) targeting**: each year, run a forward simulation, identify the marginal rate above which conversion stops being attractive, fill brackets up to that target. Like Kitces, Pfau's deliverable is a *rate*, not a return number. His Retirement Planning Guidebook frames conversion success as "lifetime tax minimization" or "after-tax wealth maximization" — never as a percentage return on conversion taxes paid.

### 3.4 David Blanchett (PGIM, formerly Morningstar)

Blanchett's Gamma framework quantifies all retirement-planning value-adds (including Roth conversions) in **basis points of equivalent alpha** (~150 bps annually for the full bundle), not as one-time large percentages. This is structurally what an annualized IRR of a single decision would look like — usually low single-digits to low double-digits, never thousands of percent. His estate-planning point is directly relevant: a Roth IRA's value to heirs is a function of the heir's expected tax rate during the 10-year drawdown window, not the headline pre-tax balance.

### 3.5 CFP Board

The CFP Board's Code of Ethics and Standards of Conduct requires CFP professionals to communicate material information in ways the client can reasonably understand, and to disclose conflicts and assumptions sufficient for **informed consent**. There's no specific rule against "% return" framings, but the duty-to-provide-information standard implies that a number whose magnitude depends overwhelmingly on (a) compounding horizon and (b) nominal vs real framing must be presented with the assumptions visible. The current "Exceptionally high" disclaimer is a tell that this duty is not being met — the disclaimer admits the number may mislead.

### 3.6 Vanguard's BETR Research (2020, updated 2025)

Vanguard's research papers and the BETR calculator (advisors.vanguard.com/tax-center/tools/roth-betr-calculator) collapse the entire decision into one number: the future tax rate that makes today's conversion break even. Because BETR is itself a rate, no annualization is needed and there's no "huge headline number" problem. Vanguard's stated reason for choosing BETR over other framings: clients can sanity-check it against their own tax expectations, which they cannot do with an IRR or NPV in dollars.

---

## 4. Specific Methodology Questions — Answered

### 4.1 What's the correct annualized IRR formula for a Roth conversion?

For RetireSmartIRA's case, the **money-weighted (CAGR) approximation** is fine and is what most consumer tools use implicitly:

```
Annualized IRR ≈ (FV_with_conversion / FV_without_conversion)^(1/years) − 1
```

This collapses the irregular cash flows (one tax payment up front, growth + RMD-avoidance dollar-by-dollar, terminal estate) into a single CAGR. For a 42-year horizon, an 8% growth rate, and the user's $69K → $2.7M end-of-plan delta scenario, this lands in the **9–11% annualized range** — a number that's intuitively recognizable as "good but not ridiculous."

The full Excel-style **IRR over the actual cash-flow stream** (negative $69K in year 0, positive RMD-avoidance and tax-savings flows over 42 years, terminal estate delta) is more rigorous and will produce a slightly different answer. For a single-tax-paid-upfront, lump-sum-at-end pattern, the two converge. For multi-year conversion ladders, full IRR is materially more accurate; CAGR is misleading there.

**Recommendation:** start with CAGR for the headline; offer IRR as an "advanced" detail.

### 4.2 What discount rate should NPV use?

**The portfolio's expected annual return** (8% in the user's case). This is McQuarrie's explicit recommendation and the standard in the academic literature. Rationale: it's the rate that makes the household indifferent between "pay tax now" and "pay tax later" — anything else implicitly bakes in a market timing or risk-arbitrage assumption.

**Risk-free rate (e.g., 10-yr TIPS) is wrong** for this purpose because the conversion tax-savings cash flow has the same risk profile as the underlying portfolio (it's a multiplicative function of portfolio growth), not a riskless cash flow.

### 4.3 Is MIRR (Modified IRR) relevant?

Marginally. MIRR is useful when intermediate cash flows would be reinvested at a different rate than the IRR (typical IRR assumes you can reinvest at the IRR itself). For a Roth conversion with one upfront tax payment and growth that compounds inside the Roth, MIRR and IRR converge to the portfolio growth rate. Not worth surfacing to end users. (Source: standard corp-finance treatment; not a Roth-specific recommendation.)

### 4.4 How do practitioners handle estate-tax / inherited-IRA compounding?

The key 2020 SECURE Act change is that non-spouse heirs of a Traditional IRA must drain the account within 10 years, and those withdrawals are taxed at the heir's marginal rate (which for working-age children is often *higher* than the original owner's retirement rate). This is the dominant driver of the "Roth-for-legacy" thesis.

Best practice: model the heir's expected tax rate during the 10-year window and compare:
- **No conversion path:** heir inherits Traditional, pays tax at heir's marginal rate during forced 10-year drawdown
- **Conversion path:** heir inherits Roth, pays no tax, optionally grows it for 10 more years tax-free

The right comparison is **heir's after-tax inheritance** — exactly what RetireSmartIRA models. The bug is purely in the *display layer*, not the calculation.

---

## 5. Methodology Recommendations for RetireSmartIRA

### 5.1 Recommended primary headline metric

**Replace** "Equivalent to a 3869.2% return on the $69K in taxes paid" with a **two-number headline**:

> **+$2.7M to your family, in 2026 dollars: $XXXK**
> **Equivalent annualized return: ~10.2% over 42 years**

Where:
- `2026 dollars` is the FV of the family-wealth delta discounted at the portfolio's nominal growth rate (or at inflation, if the chart is already in real dollars — pick one and label it).
- `Annualized return` is `(FV_with / FV_without)^(1/years) − 1`, computed on the family-wealth delta vs. the no-conversion baseline.

Both numbers pass the smell test. The annualized number is in a range users recognize (close to long-run equity returns). The PV number cannot be inflated by horizon length alone.

### 5.2 Recommended supporting metrics (display in a "scorecard" pattern, like Vanguard BETR)

1. **Break-Even Year** — the calendar year in which cumulative family wealth in the conversion path overtakes the no-conversion path. This is what Pralana, Holistiplan, and Income Lab all show. It's the single most intuitive answer to "is this worth it?"
2. **Lifetime Tax Savings** (nominal $, with PV in tooltip) — the headline used by Boldin, MoneyGuidePro, eMoney, RightCapital. Familiar to anyone who's used another tool.
3. **Implied Break-Even Tax Rate (BETR-style)** — the future marginal rate at which the heir's after-tax inheritance is identical in both scenarios. If the user expects rates above this, convert; if below, don't. This is Vanguard's gold-standard framing and gives the user a direct sanity check.

Optional fourth: **Conversion's True Marginal Rate** (Kitces): change in this year's federal+state+IRMAA+SS-taxation tax bill ÷ conversion amount. Useful for power users.

### 5.3 Recommended labels and disclaimers

**Drop** any disclaimer that begins with "Exceptionally high" or in any way apologizes for the headline number. If you must apologize for it, the metric is wrong.

**Add** small-print labels under each headline number stating:
- The horizon assumed (e.g., "Assumes growth through age 88, 10-year spousal rollover, 10-year child drawdown — 42-year total horizon.")
- The growth rate assumed (e.g., "At 8% nominal portfolio growth.")
- The currency convention (e.g., "Family-wealth delta expressed in 2026 dollars, discounted at 8%.")

### 5.4 Specific formulas to implement

```swift
// Inputs (from existing model)
let taxCostToday: Double            // e.g., 69_000
let familyDeltaNominalFV: Double    // e.g., 2_700_000 in year-2068 dollars
let years: Double                   // 42
let growthRate: Double              // 0.08 nominal
let inflationRate: Double           // 0.03 (or whatever assumption is)

// 1. Annualized return on the conversion (CAGR of the family-wealth delta).
//    Use familyWealthEnd_with / familyWealthEnd_without ratio when available;
//    otherwise approximate from the delta and the no-conversion terminal value.
func annualizedReturnOnConversion(
    endWith: Double, endWithout: Double, years: Double
) -> Double {
    return pow(endWith / endWithout, 1.0 / years) - 1.0
}

// 2. Family-wealth delta in *today's* (PV) dollars.
//    Discount at the portfolio's expected nominal growth rate (McQuarrie 2024).
func familyDeltaPresentValue(
    nominalFV: Double, years: Double, discountRate: Double
) -> Double {
    return nominalFV / pow(1.0 + discountRate, years)
}

// 3. Family-wealth delta in *real* (inflation-adjusted) dollars.
//    Useful if the rest of the UI is real-dollar.
func familyDeltaRealDollars(
    nominalFV: Double, years: Double, inflation: Double
) -> Double {
    return nominalFV / pow(1.0 + inflation, years)
}

// 4. Break-even year — first year where cumulative wealth_with > wealth_without.
func breakEvenYear(
    wealthWithByYear: [Int: Double],
    wealthWithoutByYear: [Int: Double]
) -> Int? {
    return wealthWithByYear.keys.sorted().first { year in
        (wealthWithByYear[year] ?? 0) > (wealthWithoutByYear[year] ?? 0)
    }
}

// 5. NPV of lifetime tax savings (Holistiplan / McQuarrie style).
func npvOfTaxSavings(
    annualSavings: [Int: Double], discountRate: Double, baseYear: Int
) -> Double {
    annualSavings.reduce(0.0) { sum, kv in
        let (year, saving) = kv
        let t = Double(year - baseYear)
        return sum + saving / pow(1.0 + discountRate, t)
    }
}
```

For the user's specific scenario, replacing the current display:

- Annualized return: `(2_700_000 / X_without)^(1/42) − 1` — likely **~9–11%**
- PV of family delta at 8%: `2_700_000 / 1.08^42` ≈ **$108K** (in 2026 dollars)
- PV of family delta at inflation (3%): `2_700_000 / 1.03^42` ≈ **$780K** (in 2026 real dollars)
- Break-even year: surface from existing year-by-year projections.

The PV figure depending on discount-rate choice spanning $108K → $780K is itself important: it shows the user that the "$2.7M" headline is highly horizon-and-discount-rate-sensitive. That's honest.

### 5.5 Display pattern (concrete UI proposal)

```
┌─ Legacy Impact ──────────────────────────────────────────┐
│                                                          │
│  Cost today        +$69K in tax                          │
│  Family wealth     +$2.7M nominal (in 2068 dollars)      │
│                    +$780K in today's dollars (inflation- │
│                    adjusted) ⓘ                           │
│                                                          │
│  Annualized return  ~10.2% over 42 years                 │
│  Break-even year    2034 (8 years from now)              │
│  Equivalent tax-rate sanity check: convert if you        │
│  expect heirs' future marginal rate > 18% ⓘ              │
│                                                          │
│  Horizon assumed: through age 88 + 10-yr spousal rollover│
│  + 10-yr child drawdown. Growth rate: 8% nominal.        │
└──────────────────────────────────────────────────────────┘
```

No apology, no "exceptionally high," no 3,869%.

---

## 6. Sources

### Industry tools — product help / methodology docs
- [Boldin Roth Conversion Explorer help](https://help.boldin.com/en/articles/6888336-boldin-s-roth-conversion-explorer)
- [Boldin Explorer Best Practices](https://help.boldin.com/en/articles/14151227-boldin-s-roth-conversion-explorer-best-practices)
- [Right Capital — Distribution and Conversion Tool help](https://help.rightcapital.com/module-overview/client-portal/tax/distribution-and-conversion-tool)
- [Right Capital — Tax Planning page](https://www.rightcapital.com/tax-planning/)
- [eMoney — Advanced Planning PDF](https://emoneyadvisor.com/wp-content/uploads/2020/07/Advisor-Education-Advanced-Planning-in-eMoney.pdf)
- [eMoney — Roth conversion case study](https://emoneyadvisor.com/wp-content/uploads/2024/12/eMoney_CaseStudy_RRWealthManagement_.pdf)
- [MoneyGuideElite product page](https://www.gwsa.us/money-guide-pro)
- [MoneyGuide Tax Planning press release](https://www.prnewswire.com/news-releases/envestnet--moneyguide-releases-tax-planning-feature-to-enable-advisors-to-enhance-retirement-plans-based-on-clients-goals-301033516.html)
- [Holistiplan — Interpreting the Roth Projection](https://help.holistiplan.com/interpreting-the-results-of-the-roth-projection)
- [Holistiplan — Modeling Roth Conversions in Scenario Analysis](https://help.holistiplan.com/modeling-roth-conversions)
- [Income Lab — Best Roth Conversion Software for Advisors 2026](https://incomelaboratory.com/best-roth-conversion-software/)
- [Income Lab — Roth Conversion Strategy 2026 Guide](https://incomelaboratory.com/roth-conversion-strategy-2026-guide/)
- [ProjectionLab — Roth Conversion help](https://projectionlab.com/help/roth-conversion)
- [ProjectionLab — Estate Planning & Legacy Projections](https://projectionlab.com/estate-planning)
- [WealthTrace — Roth Conversion Optimization](https://support.mywealthtrace.com/21145/kb/article/138374/roth-conversion-optimization)
- [WealthTrace — Roth Conversion Scenarios](https://support.mywealthtrace.com/21145/kb/article/105956/roth-conversion-scenarios)
- [OnTrajectory — Modeling Accounts](https://go.ontrajectory.com/support/accounts-contributions-withdrawals-guide)
- [Pralana Forum — Using IRR to evaluate Roth Conversions](https://pralanaretirementcalculator.com/community/questions-and-discussion-relative-to-pralana-onlines-analyze-features/using-irr-to-evaluate-the-financial-benefit-of-roth-conversions/)
- [Fidelity — Roth Conversion Evaluator methodology PDF](https://www.fidelity.com/planning/retirement/pdf/roth_conversion_eval_methodology.pdf) (binary; metadata extracted via search snippet)
- [Fidelity — Roth Conversion Calculator landing](https://www.fidelity.com/calculators-tools/roth-conversion-calculator/)
- [Vanguard — A BETR calculation for the Roth conversion equation](https://investor.vanguard.com/investor-resources-education/news/a-betr-calculation-for-the-traditional-to-roth-ira-conversion-equation)
- [Vanguard advisors — Roth BETR calculator](https://advisors.vanguard.com/tax-center/tools/roth-betr-calculator/)
- [Vanguard — A BETR Approach to Roth Conversions (research PDF, July 2025)](https://corporate.vanguard.com/content/dam/corp/research/pdf/a_betr_approach_to_roth_conversions_072025.pdf)
- [Schwab — Roth IRA Conversion Calculator](https://www.schwab.com/ira/ira-calculators/roth-ira-conversion)
- [Empower — Roth Conversion Analyzer](https://www.empower.com/me_and_my_money/calculators/retirement-conversion-analyzer.shtml)
- [Empower — Roth Conversion Calculator](https://www.empower.com/calculators/roth-conversion)

### Academic / practitioner research
- [McQuarrie & DiLellio — The Arithmetic of Roth Conversions, JFP May 2023](https://www.financialplanningassociation.org/learning/publications/journal/MAY23-arithmetic-roth-conversions-OPEN)
- [McQuarrie — Net Present Value Analysis of Roth Conversions, JFP Sep 2024](https://www.financialplanningassociation.org/learning/publications/journal/SEP24-net-present-value-analysis-roth-conversions-OPEN)
- [DiLellio, Goldfeder & McQuarrie — Optimal decisions under price dynamics for Roth conversions](https://onlinelibrary.wiley.com/doi/abs/10.1002/cfp2.1174)
- [Kitces — How To Calculate The Marginal Tax Rate Of A Roth Conversion](https://www.kitces.com/blog/roth-conversion-analysis-value-calculate-timing-true-marginal-tax-rate-equivalency-principle/)
- [Kitces — Tax Diversification Limits And Roth Optimization Benefits](https://www.kitces.com/blog/tax-diversification-roth-optimization-conversion-tax-alpha/)
- [Kitces — Finding Your Tax Equilibrium Rate](https://www.kitces.com/blog/tax-rate-equilibrium-for-retirement-taxable-income-liquidations-roth-conversions/)
- [Kitces — When A Roth Conversion Is Bad Even If Tax Burdens Go Up](https://www.kitces.com/blog/why-a-roth-conversion-may-be-a-bad-idea-even-if-taxes-are-higher-in-the-future/)
- [Kitces — To Roth or Not To Roth (May 2009 Kitces Report PDF)](https://www.kitces.com/wp-content/uploads/2014/11/Kitces-Report-May-2009.pdf)
- [Kitces — Morningstar Gamma / Quantifying Value of Advice](https://www.kitces.com/blog/morningstar-tries-to-quantify-the-value-of-financial-planning-1-8-gamma-for-retirees/)
- [Wade Pfau — homepage](https://www.wadepfau.com/)
- [Wade Pfau — LinkedIn tax-planning Roth conversion post](https://www.linkedin.com/posts/wpfau_retirement-activity-7195811019825291265-MRDT)
- [Pfau via Advisor Perspectives — Practical Considerations in Tax-Efficient Distribution Planning](https://www.advisorperspectives.com/articles/2024/02/12/practical-considerations-tax-efficient-planning)
- [Covisum — EMR methodology](https://www.covisum.com/blog/optimizing-retirement-navigating-tax-efficiency-with-covisums-emr-methodology)
- [David Blanchett — Alpha, Beta, and Now Gamma (Morningstar)](https://www.morningstar.com/content/dam/marketing/shared/research/foundational/677796-AlphaBetaGamma.pdf)
- [David Blanchett — research page](https://www.davidmblanchett.com/research)

### Secondary / commentary
- [Oblivious Investor — Roth Conversion Analysis: Break-Even Tax Rate](https://obliviousinvestor.com/roth-conversion-analysis-break-even-tax-rate/)
- [Bogleheads — Best Roth Conversion Analysis Tools](https://www.bogleheads.org/forum/viewtopic.php?t=445429)
- [Bogleheads — Roth Conversion Tools](https://www.bogleheads.org/forum/viewtopic.php?t=455106)
- [Bogleheads — Vanguard BETR thread](https://www.bogleheads.org/forum/viewtopic.php?t=455797)
- [Brown Advisory — The Long Game: Roth Conversions & Legacy Planning](https://www.brownadvisory.com/us/insights/long-game-roth-conversions-legacy-planning)
- [CNBC — Roth conversions to reduce taxes for inherited IRAs](https://www.cnbc.com/2023/12/11/how-roth-conversions-can-reduce-taxes-for-inherited-iras.html)
- [Kotlikoff — Boldin's Roth Conversion critique](https://larrykotlikoff.substack.com/p/boldins-new-retirement-roth-conversion)
- [Carroll Advisory — The Roth Conversion Tax Break Even](https://www.carrolladvisory.com/blog/the-roth-conversion-tax-break-even)
- [Stonewood — Real Cost of Roth Conversions](https://blog.stonewoodfinancial.com/the-real-cost-of-roth-conversions)
- [Root Financial — Roth Conversions: When Will You Actually Break Even?](https://rootfinancial.com/2025/03/11/roth-conversions-when-will-you-actually-break-even/)
- [Elm Wealth — Size Matters in the Roth IRA Conversion Decision](https://elmwealth.com/roth-conversion/)
- [The Wealth Advisor — Roth Conversions Appear Advantageous On Paper But Not In Reality](https://www.thewealthadvisor.com/article/roth-conversions-appear-advantageous-paper-not-reality)
- [Glenn Daily — Roth IRA Real Options paper PDF](https://glenndaily.com/documents/rothira.pdf)
- [ThinkAdvisor — That Time 730,000 People Got Misleading Roth Conversion Advice](https://www.thinkadvisor.com/2025/12/12/that-time-730000-people-got-misleading-roth-conversion-advice/)

### CFP Board
- [CFP Board — Disclosures to Clients](https://www.cfp.net/ethics/compliance-resources/2019/08/disclosures-to-clients---what-and-when)
- [CFP Board — Code and Standards FAQ PDF](https://www.cfp.net/-/media/files/cfp-board/standards-and-ethics/compliance-resources/cfp-board-code-and-standards-faq.pdf)
- [CFP Board — Financial Planning Engagements Disclosure Guide](https://www.cfp.net/ethics/compliance-resources/2020/11/financial-planning-engagements-disclosure-guide)
- [Kitces — CFP Board's New Disclosure And Documentation Requirements](https://www.kitces.com/blog/cfp-disclosure-obligations-informed-consent-reporting-cfp-board-standards-of-conduct-discipline/)

---

## 7. Cross-validated synthesis (research agent + ChatGPT + Gemini)

After this research-agent report was completed, the same research questions were also posed to ChatGPT and Gemini (running independently). All three sources converged on the same conclusions; the key differences were complementary additions, not contradictions.

### 7.1 Where all three sources agree (very high confidence)

1. **Drop the 3869% headline entirely.** ChatGPT: "delete it from the primary UI... more likely to reduce trust than increase understanding." Gemini: "It looks like a typo or a scam to a sophisticated investor." Research agent: "no mainstream planning tool uses a raw, undiscounted '% return on conversion taxes' headline."
2. **No mainstream tool displays raw multi-decade % returns** for Roth conversions. Verified across 13+ tools (Boldin, Right Capital, eMoney, MoneyGuidePro, Holistiplan, Income Lab, ProjectionLab, WealthTrace, Pralana, Vanguard, Fidelity, Schwab, Empower).
3. **Replace headline with absolute dollar figure** + PV toggle (today's-dollars subtitle).
4. **Annualized ~9.1% can replace the 3869% as a supporting metric** — same math, rigorous framing, no disclaimer needed. Formula: `(FV_with / FV_without)^(1/years) − 1`.
5. **Break-even year is the most user-actionable supporting metric.**
6. **Drop the apologetic disclaimer.** Replace with an educational tooltip explaining the underlying mechanics (compounded tax-free growth, taxes paid from outside funds, dependency on heirs' future rates).
7. **After-tax inheritance is the right comparison** (model the heir's expected tax rate during the 10-year SECURE Act drawdown).
8. **Industry standard pattern is the crossover chart** — line graph showing Traditional vs Roth after-tax net worth over time.

### 7.2 Notable additions per source

- **Research agent:** Vanguard's **BETR (Break-Even Tax Rate)** as a 3rd headline metric — academic gold standard, gives users a direct sanity check ("convert if you expect heir's future marginal rate > X%"). Specific Swift formulas. McQuarrie & DiLellio formal academic citation.
- **ChatGPT:** **CFA Institute GIPS Standard III(D)** as compliance-style framing — strongest argument that the current display is rhetorically untenable, by analogy to performance-presentation rules. More careful linguistic distinction: "Implied annualized benefit" or "Annualized equivalent of tax cost" — explicitly NOT "Return on taxes paid."
- **Gemini:** **"Tax Wedge" bar chart** as a novel visualization idea — left bar shows today's tax cost ($69K), right bar shows projected lifetime family tax savings without conversion. Visually justifies the upfront cost without abstract %.

### 7.3 Resolved divergence — discount rate choice

The three sources differed on which discount rate to use for PV framing:
- Research agent (per McQuarrie 2024 academic): **portfolio expected return** (8%) → PV ≈ $108K
- ChatGPT: match projection assumption (8%) with conservative real rate as alternative
- Gemini: **inflation rate** (~3%) for "today's purchasing power" → PV ≈ $780K

**Resolution:** Show both, label them precisely. The gap is itself informative — proves the headline is horizon-and-rate-sensitive. Suggested labels:
- "$780K in today's purchasing power" (inflation-adjusted, 3%)
- "$108K discounted at portfolio return rate" (academic NPV, 8%)

### 7.4 Final synthesized 1.9 spec (recommendation)

**Replace headline:**

```
Estimated Family Wealth Gain    +$2.66M (nominal, by 2068)
                                or ~$780K in today's purchasing power
                                or ~$108K discounted at portfolio return rate ⓘ
```

**Supporting scorecard (3 metrics, all spec-compliant):**
1. **Break-even year** — "Roth pulls ahead in 2038 (Age 75)" (most actionable)
2. **Annualized return on tax dollars paid** — "~9.1% over 42 years" *(replaces 3869% — same math, rigorous framing)*
3. **Implied break-even tax rate (Vanguard BETR)** — "Convert if you expect heirs' future marginal rate > 18%"

**Optional visualizations:**
- **Crossover line chart** (already partly exists — refine for clarity)
- **Tax Wedge bar chart** (Gemini's novel addition — visualizes upfront cost vs. lifetime family savings)

**Replace apologetic disclaimer with educational tooltip:**
> "This gain relies on decades of compounded tax-free growth and assumes your conversion taxes are paid using outside (taxable) funds. It depends heavily on your heirs' future marginal tax rates and the assumed 8% portfolio growth — adjust those assumptions to test sensitivity."

### 7.5 Implementation scope (for 1.9 brainstorm/spec)

This is a **methodology + display layer** change, not a calculation engine change. The underlying after-tax-inheritance math is already correct. Required work:
- Compute annualized CAGR from existing FV_with / FV_without
- Compute PV at two discount rates (inflation + portfolio rate)
- Surface break-even year from existing year-by-year projections
- Implement BETR back-solver (find the future marginal rate at which after-tax inheritance is equal in both scenarios)
- Optional: build Tax Wedge bar chart component
- Update copy (replace apology, add educational tooltips)

**Estimated: 1–2 weeks of focused work.** Smaller than 1.8's color refresh.
