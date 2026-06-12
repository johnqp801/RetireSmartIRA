# 2.0 Brainstorm Prep — Multi-Year Tax Strategy Engine

**Generated:** 2026-05-02 (inline research pass + outside-reviewer critiques + horizon + liquidity discussion)
**For:** Brainstorm session on RetireSmartIRA's headline 2.0 feature
**Status:** Revised v2 — incorporates two outside reviewer critiques and follow-up discussion on horizon and liquidity

---

## ⚠️ Action item: 1.9 Medicare Part B bug to fix before PR #4 merges

While compiling competitive context, an outside reviewer caught that **1.9's Task 3.1 placed an incorrect Medicare Part B 2026 premium in `tax-2026.json`:** `partBStandardMonthly: 185.00`. The correct CMS-published 2026 figure is **$202.90/month**. The file already contains `irmaaStandardPartB: 202.90` at the right value — but `MedicareCostEngine.computeCostForSpouse()` reads from the new `medicare2026.partBStandardMonthly` key, so the engine output is ~$215/yr/Medicare-eligible-person too low.

Three-line fix (commit before PR #4 merges):
1. `tax-2026.json`: `"partBStandardMonthly": 202.90`
2. `TaxYearConfig.swift` hardcoded fallback: same change
3. `MedicareCostEngineTests.swift`: tier 0 expected total → `421.90` monthly / `5,062.80` annual (was `385.00` / `4,620.00`)

Spot-check the other three Medicare values (`partDAvgMonthly: 50`, `medigapAvgMonthly: 150`, `advantageAvgMonthly: 50`) against actual 2026 CMS data while you're in there.

---

## TL;DR for the brainstorm session

Read this if you have 2 minutes:

1. **The headline urgency is gone.** OBBBA (signed July 4, 2025) made TCJA brackets permanent. "Convert before sunset" is dead. Multi-year Roth is now about *bracket smoothing, IRMAA dodging, ACA preservation, RMD flattening, widow-penalty mitigation, and cash-flow-aware optimization.*

2. **Engine name is `MultiYearTaxStrategyEngine`, not `MultiYearRothEngine`.** Roth conversion is the headline output, but the engine ALSO routes QCDs, charitable bunching, withdrawal ordering, and ACA-preservation across years. Naming it Roth-only locks us out of those.

3. **The user promise** (this should govern the whole product):
   > *RetireSmartIRA 2.0 does not claim to find a mathematically perfect lifetime answer. It gives a transparent, editable, year-by-year tax strategy that explains why each year's amount is recommended, what constraint it is near, and what tradeoff the user is making.*

4. **Default objective is "Maximize after-tax lifetime wealth," not "Minimize lifetime tax."** Tax minimization in isolation produces perverse answers (just don't convert anything!). Wealth maximization captures the actual user goal.

5. **Default horizon is "until both spouses deceased,"** not "user lifetime" and not "through heirs." This captures the widow penalty fully, doesn't require heir-bracket guesses, doesn't optimize for non-customers. Heir impact is a supporting metric, opt-in.

6. **Constraints are SOFT by default, not hard.** The engine can cross IRMAA tier 1 in 2028 *if the lifetime benefit clearly outweighs the one-year Medicare cost*, then explains the trade. Rigid "never cross" produces inferior plans.

7. **The liquidity constraint is hard and often binding.** Many retirees have large Traditional IRA balances but limited cash to pay conversion tax. The engine tracks year-by-year liquid cash and constrains conversions accordingly. Single-bucket approximation in 2.0 (no per-account brokerage); full brokerage modeling deferred to 2.1.

8. **The market splits in three philosophies (none own consumer Mac-native):**
   - **Boldin** ($120/yr, web) — exploration + iteration with multiple strategies
   - **Pralana** ($99/yr, web) — power-user constraint specifier (already does ACA + IRMAA constraint optimization — they're more competitive than initially credited)
   - **MaxiFi** ($129/yr, web) — economic DP + consumption smoothing
   - **Income Lab** (advisor-tier, $300+/mo) — deepest IRMAA + SS + withdrawal integration

9. **The differentiation moat is EXPLANATION, not feature parity.** Pralana already includes ACA/IRMAA awareness. RetireSmartIRA's defensible position is: single recommendation + waterfall visualization + plain-English reasoning + soft-constraint tradeoff narration. "We explain it better and make it easier."

10. **Apple Silicon native compute is a real but not unlimited advantage.** Web tools are server-bound; we run locally on M-series. Brute-force grid search over ~3,000 states/year × 35 years is tractable in seconds (not milliseconds). Plan a perf prototype before committing to specific algorithm choice.

11. **Visible assumption panel is non-negotiable.** CPI for bracket projection, return rate, life expectancy, post-widow filing transition, state residency, SS claiming age, year-config projection mechanism — all surfaced and editable. Trust through transparency.

12. **The biggest roadblock to writing the first line of code isn't in the original Section 9 list — it's the state-transition model** for years where you don't have actual user data: how do balances grow, how does TaxYearConfig project forward, how does horizon terminate. Pin this first.

---

## 0. The user promise

This sentence should govern every product decision in 2.0:

> **RetireSmartIRA 2.0 does not claim to find a mathematically perfect lifetime answer. It gives a transparent, editable, year-by-year tax strategy that explains why each year's amount is recommended, what constraint it is near, and what tradeoff the user is making.**

What this commits us to:

- **No black-box recommendations.** Every year's number has a one-line "why this much, why this year" explanation, expandable to full reasoning.
- **No fake precision.** We name the assumptions that drive the recommendation. We don't pretend to optimize over uncertainty we can't actually quantify.
- **User is the editor, not the consumer.** The recommendation is a starting point; the user can override any year, and the engine re-narrates the consequence.
- **Honest about tradeoffs.** "This plan crosses IRMAA Tier 1 in 2028 because the one-year Medicare cost is outweighed by lower projected RMD taxes later" beats "do this." Always.

What this rules out:

- "Optimal Roth conversion plan" branding. We don't claim optimality; we claim transparency.
- Sliders that change a number without explaining what they're doing.
- "Trust the algorithm" framing.

---

## 1. Competitive landscape

### Boldin (formerly NewRetirement)

[Boldin's Roth Conversion Explorer](https://help.boldin.com/en/articles/6888336-boldin-s-roth-conversion-explorer) is the dominant DIY multi-year tool. Pricing: ~$120/yr (PlannerPlus tier).

**What it optimizes:** Two strategy classes — [Goal-Based and Rule-Based](https://help.boldin.com/en/articles/14151227-boldin-s-roth-conversion-explorer-best-practices):
- **Goal-Based**: cycles through every federal bracket, evaluates outcomes for chosen goal (Highest Estate Value, Lowest Lifetime Tax Liability), picks the bracket that wins.
- **Rule-Based**: user picks a target bracket; engine "fills" it each year until pre-tax dollars exhausted.

**UX:** Iteration-driven. [Boldin's own framing](https://www.boldin.com/retirement/planning-for-uncertainty-why-roth-conversions-require-iteration-not-perfection-its-an-art-not-a-science/) is "art, not science" — explicitly rejects optimal-single-answer claims.

**Engagement signal:** [93% of Boldin users have used the Explorer](https://www.boldin.com/retirement/strong-engagement-high-confidence-what-boldins-survey-of-users-reveals-about-strategizing-roth-conversions/); 50% plan 5-10 year ladders; 76% revisit multiple times per year.

**Gap RetireSmartIRA fills:** Boldin's iteration model assumes the user keeps coming back to refine. A native Mac tool can present a *single recommended ladder with reasoning*, sized for the user's situation, in one view.

### Pralana (Online + Gold) — more competitive than initially credited

[Pralana](https://pralanaretirementcalculator.com/pralana-gold/) is the power-user / spreadsheet-replacement tool. Pricing: $99/yr Online, $149 perpetual Gold.

**Important correction from outside reviewer:** Pralana already does the ACA + IRMAA constraint-aware optimization that 1.9 set up. Per [their docs](https://pralanaretirementcalculator.com/analysis-optimization/), Pralana lets users specify per-year constraints across **all** of: marginal tax bracket, LTCG bracket, IRMAA bracket, FPL multiple. The engine then optimizes the marginal tax bracket *limits* to maximize long-term savings while respecting FPL/IRMAA constraints.

**Coverage breadth:** NIIT, IRMAA, ACA premium credits, AMT, OBBBA over-65 deduction with phase-out, SS taxation, LTCG, OBBBA SALT phase-out. Comprehensive.

**UX:** Spreadsheet-feel. Year-by-year column inputs. Power users love it; civilians find it intimidating.

**Differentiation correction:** RetireSmartIRA's pitch is NOT "we include ACA/IRMAA awareness" (Pralana already does). The pitch IS "we explain the recommendation better and make it easier to act on." Explanation moat, not feature moat.

### MaxiFi Planner

[MaxiFi](https://www.maxifi.com/features/roth-conversion-optimizer) takes a fundamentally different mental model. Pricing: $129 first year, $109 renewal.

**What it optimizes:** [The only software that explicitly maximizes lifetime spending](https://www.maxifi.com/features/roth-conversion-optimizer) (consumption smoothing) rather than minimizing taxes or maximizing wealth. Built on dynamic programming.

**Philosophy:** Per [Kotlikoff's substack](https://larrykotlikoff.substack.com/p/theres-money-in-them-thar-roth-conversions): doesn't ask what you want to spend; tells you what you *can* afford. Smooths living standard across remaining years.

**Gap RetireSmartIRA fills:** MaxiFi's framing is academically pure but alienates users who think in tax/IRMAA/cliff terms. We can borrow the DP optimizer mechanics while presenting results in the framing the audience already understands.

### Income Lab Tax Lab

[Income Lab](https://incomelaboratory.com/best-roth-conversion-software/) is the newest serious entrant. T3 2026's #1-ranked retirement distribution tool (4.15% market share). Advisor-tier pricing (~$300+/mo).

**What it optimizes:** Multi-year Roth ladder integrated with IRMAA awareness, SS claiming-age interactions, withdrawal sequencing.

**Gap RetireSmartIRA fills:** No consumer equivalent of "Income Lab depth, consumer pricing, native UX." That's the lane.

### Mike Piper / Oblivious Investor

[Piper](https://obliviousinvestor.com/) writes the most respected free practitioner content. He famously [rejects fill-the-12%-bracket as a heuristic](https://obliviousinvestor.com/roth-conversion-deep-dive-addressing-left-out-topics/) — argues case-by-case, not formulaic. His [Open Social Security tool](https://opensocialsecurity.com) demonstrates the "free, opinionated, narrowly-scoped" approach.

**Implication:** A defensible product position is showing the user the case-by-case math, not a magic number. Piper's audience would actually accept this approach.

### Income Lab's 2026 advisor-tool comparison

[Income Lab's own comparison](https://incomelaboratory.com/best-roth-conversion-software/) ranks: Income Lab, Holistiplan Premium, RightCapital, MaxiFi, Covisum, Boldin. RetireSmartIRA fits in the consumer tier between Boldin and MaxiFi.

---

## 2. Federal tax law foundation

### The OBBBA shift (July 2025) — single most important development

[OBBBA, signed July 4, 2025](https://www.irs.gov/newsroom/one-big-beautiful-bill-provisions), made the [TCJA seven-bracket structure permanent](https://www.hrblock.com/tax-center/irs/tax-law-and-policy/one-big-beautiful-bill-taxes/), with inflation adjustment for 10% and 12% brackets in 2026. This kills the "convert before 2026 sunset" urgency.

**Implication:** The optimization is no longer time-pressured. The window is "your remaining lifetime + spouse," not "before sunset." Pace > urgency.

### The 5-year rule (often misunderstood)

Two rules:
1. **5-year rule for Roth contributions** (account-level): account must be 5 years old before *earnings* can be withdrawn tax-free.
2. **5-year rule for conversions** (per-conversion): each conversion has its own 5-year clock for the 10% early-withdrawal penalty on converted *principal* (not income tax — that was paid on conversion).

For the 60+ demographic: both rules are largely moot once age 59½ is passed. Engine surfaces these as warnings only when pre-59½ withdrawal would be needed; not a core optimization driver.

### T.D. 10001 (July 19, 2024) — inherited IRA final regs

[T.D. 10001](https://www.grantthornton.com/insights/newsletters/tax/2024/hot-topics/jul-30/final-rmd-rules-retain-10-year-rule-for-inherited-retirement-accounts) (260 pages) finalized the 10-year rule. If owner died on/after RMD beginning date, beneficiary must take annual RMDs throughout the 10-year period AND deplete by year 10. Effective Jan 1, 2025.

**Implication:** Inherited IRAs already in user's portfolio (per 1.9's existing modeling) are a separate optimization 2.0 should respect but not re-solve. Heir-side optimization (converting more now to lower heirs' 10-year-rule cost) is a supporting metric, not a driver.

### Widow penalty — first-class optimization input

[Multiple sources](https://www.financialplanningassociation.org/learning/publications/journal/DEC23-widow-tax-hit-debunked-OPEN) document MFJ→Single transition pushing the survivor into higher brackets and IRMAA tiers. Per [Income Lab](https://incomelaboratory.com/irmaa-brackets-2026-guide/), single-filer IRMAA brackets are roughly half MFJ — same income, two-tier jump.

**Multi-year Roth strategy:** Convert aggressively in MFJ years to drain Traditional balances *before* the survivor faces single-filer brackets. 1.9's `ScenarioWarningEngine` already detects this; 2.0 can let it drive optimization.

### SECURE 2.0 (already in 1.9)

RMD age 73→75 (2033), super-catchup 60-63 (1.9 implements), Roth 401(k) RMD elimination (2024), [Rothification mandate for high-earner catch-ups (2027)](https://www.irs.gov/newsroom/treasury-irs-issue-final-regulations-on-new-roth-catch-up-rule-other-secure-2point0-act-provisions).

---

## 3. State tax variations

States that **don't exempt IRA distributions** create state-level cost on Roth conversions: California, Connecticut, Minnesota, Nebraska, New Jersey, Vermont. Engine incorporates state marginal rate via 1.9's `StateTaxConfig`.

States with **flat tax**: Colorado, Illinois, Indiana, Kentucky, Massachusetts, Michigan, North Carolina, Pennsylvania, Utah. Simpler bracket-fill logic.

**Social Security taxability**: state-by-state variations, AND federal taxability is conversion-pivotal — a Roth conversion can push the user from 0% taxable SS to 50% to 85% (the "tax torpedo"). 1.9 handles this for current scenarios; 2.0 must propagate across years.

---

## 4. Optimization theory and heuristics

### The spectrum, simplest to most rigorous

| Approach | Pros | Cons | Scope |
|---|---|---|---|
| **A. Fill-the-bracket** | Trivial; easy to explain | Ignores RMD/IRMAA/widow | Small |
| **B. Pre-RMD smoothing** | Captures RMD avoidance | Doesn't see IRMAA tiers | Small |
| **C. Constraint-aware bracket-fill** (Pralana) | Matches user mental model; integrates 1.9 cliffs | Optimum bracket choice is *given* | Medium |
| **D. Goal-based brute-force search** (Boldin) | Defensible single number | Cycles many strategies | Medium |
| **E. Dynamic programming** (MaxiFi) | Provably optimal under model | Hard to explain output | Large |
| **F. Stochastic DP** | Handles uncertainty rigorously | Heavyweight; output is distribution | Very large |

### Where RetireSmartIRA should sit — and the Apple Silicon advantage

The original analysis recommended **medium scope (C + D hybrid)** based on competitor compute constraints. An outside reviewer flagged that this assumption may be too conservative.

**The native-compute opportunity:**
- Pralana, Boldin, MaxiFi all run server-side. Every optimization pass costs them server compute or web-worker latency.
- RetireSmartIRA runs natively on Apple Silicon (M-series Mac, A-series iOS) with multi-threaded Swift Concurrency.
- A 35-year horizon × ~10 conversion levels × 6 IRMAA tiers × 2 ACA states ≈ 4,200 states/year × 35 years ≈ 150K-state DP. On M-series, that's *seconds*, not milliseconds — but seconds are more than acceptable for a one-time recommendation generation.
- Brute-force grid over 50-100 constraint pattern combinations × heuristic per pattern = ~5K evaluations. Sub-second on M-series.

**Recommendation:** Build a perf prototype as task 1 of implementation. Don't pre-commit to a scope tier. Start with C + D, but architect so that E (DP) is a drop-in upgrade if benchmark says compute is plentiful.

**Architectural caveat:** If we commit to E (DP), we owe the user an explanation of the output — a DP black box undermines the user-promise principle. Boldin's answer is "we cycle strategies," which is human-interpretable. DP would need a similar narrative wrapper.

---

## 5. Practitioner literature highlights

### Michael Kitces — the bible

[Kitces.com](https://www.kitces.com/) is the deepest technical library. The [Tax Diversification Limits and Roth Optimization Benefits article](https://www.kitces.com/blog/tax-diversification-roth-optimization-conversion-tax-alpha/) frames Roth as a "tax alpha" play — marginal benefit comes from arbitraging current low rates against future high rates (mostly RMD-driven). Kitces also runs [an entire Roth Conversion course](https://www.kitces.com/roth-conversions-course/) for advisors.

### Wade Pfau

Academic anchor at [retirement researcher](https://retirementresearcher.com). Emphasizes that single-year analysis underestimates lifetime value because it ignores compounding tax-free growth and RMD-avoidance.

### Mike Piper — case-by-case skeptic

Piper [explicitly rejects](https://obliviousinvestor.com/roth-conversion-deep-dive-addressing-left-out-topics/) the fill-12%-bracket heuristic as too simple. He argues case-by-case math, not heuristics.

### Where the field is evolving (2024-2026)

1. **OBBBA-aware re-framing**: from "convert before sunset" to "find your optimal pace." See [Highland Financial Advisors](https://www.highlandplanning.com/learning-center-1/roth-ira-conversions-under-the-one-big-beautiful-bill-act-for-2025-and-2026).
2. **IRMAA cliff first-class treatment**: every recent advisor-software comparison ranks IRMAA awareness as a core feature — but it's now table stakes, not a differentiator.
3. **Inherited-IRA cascade**: post-T.D. 10001, advisors revisiting whether to over-convert now to lower heirs' 10-year-rule cost. [Kitces analysis](https://www.kitces.com/blog/secure-act-2-0-irs-regulations-rmd-required-minimum-distributions-10-year-rule-eligible-designated-beneficiary-see-through-conduit-trust/).

---

## 6. Objective function & horizon — the deepest design call

### Why "minimize lifetime tax" is wrong

The original prep doc recommended "minimize lifetime federal tax" as the default. After outside-reviewer pushback, the user's intuition flagged this, and we worked through it — there are five distinct problems with the framing:

1. **Time value of money.** Tax paid in 2026 isn't the same as tax in 2056. Without a discount rate, a naïve sum overweights distant tax. With a discount rate, the optimizer might prefer paying NOW over later — opposite of conventional advice. The horizon you pick changes the discount weighting massively.

2. **Horizon = a value judgment.** "Lifetime" can mean three things, each producing different "optimal" plans. (See horizon-options table below.)

3. **It can produce nonsense.** "Minimize lifetime tax" admits a perverse winner: never convert anything. Zero conversion → zero conversion tax → wins on the metric. Framework requires implicit constraint to be sensible.

4. **Widow penalty truncation effects.** A 30-year horizon catches some widow years; 40-year catches all. The recommended ladder genuinely shifts.

5. **Tax is a cost, not a benefit.** This is the deepest issue. Minimizing a cost in isolation is what you do for spending categories you want LESS of. The thing the user actually wants is more *after-tax wealth* (or spending power). Minimizing the cost without anchoring to a benefit is like minimizing your grocery bill by not eating.

### Why "maximize after-tax lifetime wealth" dodges most of these

- **Problem 5 vanishes** — optimizing the benefit directly.
- **Problem 3 vanishes** — if you don't convert and have huge RMDs, terminal wealth drops because future tax compounds. Captured.
- **Problem 1 partially resolves** — terminal wealth at fixed horizon is cleaner than discounted tax stream.
- **Problems 2 and 4 still exist** — still pick a horizon. But "wealth at *what age*?" is more interpretable than "tax through *what year*?"

### The three horizon options

| Horizon | Captures | Misses | Recommend? |
|---|---|---|---|
| **User's lifetime only** (~30 yr from age 65) | User's tax + RMD | Widow penalty entirely. Heir cascade entirely. | NO — under-optimizes |
| **User + surviving spouse** (~35-40 yr until both deceased) | Widow penalty in full. Avoids non-customer optimization. | Heir cascade. | **YES — recommended default** |
| **User + spouse + heirs through estate** (40+ yr including 10-year rule) | Everything | Requires guessing heirs' brackets and circumstances. Optimizes for non-customers. | Opt-in supporting metric |

**Recommended default:** "Maximize after-tax lifetime wealth, until both spouses deceased." Heir-impact is a supporting metric ("if you leave $X to heirs, the 10-year-rule cascade costs them ~$Y at their assumed bracket") — surfaced but not driving.

**Mortality assumption made visible.** User picks: deterministic (age 95 default, override), simple (life-expectancy table), or stress-test (toggle "what if X dies at Y"). Same UX pattern as the widow stress-test.

### Soft constraints with explanations, not hard walls

Outside-reviewer-driven decision: the engine should be allowed to cross IRMAA or ACA thresholds when lifetime benefit clearly outweighs the cliff cost. Then explain the trade:

> "This plan intentionally crosses IRMAA Tier 1 in 2028 because the one-year Medicare cost ($2,400) is outweighed by lower projected RMD taxes later ($18,000 lifetime saving). Net benefit: $15,600."

Rigid "never cross" produces inferior plans. Soft + explained beats hard + opaque every time.

User can convert constraints to hard if they prefer: "I never want to cross IRMAA Tier 2." Honor that. But default is soft.

### The opinionated-default UX

Outside-reviewer framing: pick ONE opinionated default. Run other objectives silently in the background. Surface alternatives only when meaningfully different.

Default: "Maximize after-tax lifetime wealth (until both spouses deceased)."

Silently run: minimize-lifetime-tax, maximize-estate-value, MaxiFi-style consumption-smoothing.

Surface alternative ONLY when:
- It produces >5% improvement on its own metric
- AND the tradeoff vs. the default is interpretable in one sentence
- AND the alternative doesn't violate a hard user constraint

Example surface: *"Your current strategy maximizes after-tax wealth. Shifting $10K from year 3 to year 4 would maximize estate value with $24K less heir tax — at the cost of $3K more in your own taxes. [View Alternative]"*

### Supporting metrics shown alongside the recommendation

Per outside reviewer:
- Lifetime tax paid (federal + state)
- Ending Roth balance
- Ending Traditional balance
- IRMAA cost (cumulative)
- ACA subsidy preserved/lost
- Survivor-year tax impact
- Heir impact (optional, on by default for users with named heirs)
- Liquidity headroom (cash buffer at year-end, low-water-mark across horizon)

---

## 7. Liquidity constraint (cash to pay tax)

This was missing from the original prep doc and is genuinely the most underrated real-world constraint.

### Why it matters mathematically

Three ways to fund a Roth conversion's tax bill:

1. **Out-of-pocket cash** (savings/brokerage) — full conversion lands in Roth. Future growth tax-free.
2. **Withhold from the conversion** — only conversion-minus-tax lands in Roth. Under 59½, withheld portion ALSO triggers the 10% early-withdrawal penalty.
3. **Sell brokerage to fund tax** — adds capital-gains tax on top, may push into NIIT or higher LTCG bracket.

The math is dramatically worse without #1. Convert $50K from Trad IRA at 30% effective rate:
- **With cash on hand**: $50K → Roth, $15K leaves checking. Future $50K grows tax-free.
- **Tax from conversion**: $35K → Roth, $15K paid as tax. You "converted" $50K of basis but only $35K is working tax-free — a **30% efficiency loss**.

### The demographic this hits — it's huge

This is the **majority** of soon-retired or recently-retired people. They've spent decades maxing 401(k) and Trad IRA, but never built proportionate brokerage savings:
- Large Traditional IRA ($1M+)
- Small liquid cash buffer ($20-100K)
- Limited annual cash inflow until SS claimed / RMDs begin

For these users, the *theoretically optimal* conversion ladder (e.g., "convert $80K/yr through age 72") is unrealizable. They'd run their cash buffer dry by year 2 and have to fund tax from the conversion itself, collapsing the math.

### Engine treatment — hard constraint, not soft tradeoff

Unlike IRMAA/ACA cliffs (soft, with explanation), liquidity is a **hard constraint**:

1. **Year-by-year liquid cash state variable.** Tracked as part of the multi-year state vector.
2. **Conversion size capped by available cash.** If projected year-N cash covers $10K of tax, the optimizer doesn't propose a conversion that owes $15K — OR it proposes both options with explicit efficiency-loss callout.
3. **Cash-source planning** as a tier of optimization beneath conversion sizing:
   - QCD redirects RMDs to charity, freeing cash that would have been donated anyway
   - Tax-loss harvesting in brokerage offsets gains, freeing cash (defer to 2.1 brokerage modeling)
   - 0% LTCG bracket years — realize gains at zero cost to fund conversion tax (defer to 2.1)
4. **Multi-year cash-flow projection.** Maybe optimal ladder is "small conversions years 1-3 while cash-tight, larger years 4-7 once SS income flows."

### How this reshapes recommendations

For cash-constrained users:
- Smaller annual conversions, longer ladder
- Front-loaded only if a brokerage realization opportunity exists
- **Sometimes: don't convert at all, or convert minimally** — math just doesn't work

The user lands on "no conversion is the right answer" surprisingly often when cash is the binding constraint. That's a defensible recommendation, AND it's a huge differentiator from competitors who implicitly assume tax can always be funded.

### Single-bucket approximation in 2.0; full brokerage in 2.1

The 2.0 scope doc explicitly defers full brokerage modeling to 2.1. So 2.0 uses a single-bucket approximation:

**User input (one number):** "Investable assets outside retirement accounts" — combines cash, savings, brokerage at fair value.

**Plus 2-3 supporting fields with sensible defaults:**
- Annual living expenses (default: derive from existing 1.9 scenario withdrawals)
- Expected after-tax growth rate on investable assets (default 4-5%)
- Optional rough basis fraction ("roughly X% of my brokerage is gains") — used to estimate selling cost when funding tax

**Year-by-year propagation:**
```
Year N+1 cash = (Year N cash × (1 + growth)) + income - expenses - tax
```

When evaluating a conversion in year N: "Does projected year-N cash cover the conversion tax?" If no, conversion is constrained or flagged.

### What 2.0 gives up vs. full brokerage modeling

Honest list of limitations:
- **No 0% LTCG bracket optimization.** Can't say "realize $30K of gains in 2027 because you're in the 0% LTCG bracket and fund a conversion tax-free."
- **No tax-loss harvesting integration.** Can't say "harvest $10K of losses to offset realized gains."
- **No concentrated low-basis warning.** A user whose investable assets are mostly Apple at $5 cost basis is overstating tax-paying capacity.
- **No step-up-at-death modeling.** Doesn't matter for user's lifetime optimization; does for heir-impact metric.

For the cash-rich-Trad-poor demographic this is fine. For the user with concentrated taxable position, the engine recommends something slightly suboptimal. Acceptable tradeoff for 2.0.

### How it composes when 2.1 ships

When brokerage modeling lands in 2.1, the engine signature stays the same — it just gets a richer cash-projection input. The single-bucket field becomes a derived sum from modeled accounts. No engine rewrite required.

---

## 8. Trust & assumption management

Multi-year tax planning is assumption-sensitive. The engine's recommendation only earns user trust if the assumptions are visible and editable. The product needs an **Assumption Panel** as a first-class UI element.

### Required assumptions surfaced

| Assumption | Default | User can override? | Engine reaction |
|---|---|---|---|
| **CPI for tax bracket projection** | 2.5%/yr | Yes | Brackets/IRMAA/FPL/deductions inflate annually |
| **Annual investment growth rate** (retirement accounts) | 6% nominal | Yes | Drives RMD trajectory, terminal wealth |
| **After-tax growth rate on investable assets** | 4% nominal | Yes | Drives liquidity-bucket evolution |
| **User mortality assumption** | Age 95 | Yes (deterministic / table / stress-test) | Sets horizon |
| **Spouse mortality assumption** | Age 95 | Yes (incl. stress-test "what if X dies at Y") | Drives widow-penalty modeling |
| **Filing status after spouse death** | Single | (system-determined) | Switches brackets/IRMAA tiers |
| **State residency** | Current | Year-by-year override allowed | Per-year state tax calc |
| **Social Security claim age** | From 1.9 SS planner | Yes | Income flow timing |
| **Tax law projection** | OBBBA permanent | Yes (toggle "what if 2030 sunset?") | Future-year bracket structure |
| **Medicare premium projection** | CMS-published + CPI | Yes | IRMAA cost projection |
| **ACA cliff persistence** | Continues post-2025 | Yes (toggle "if enhanced subsidies restored") | ACA constraint shape |
| **Annual living expenses** | From 1.9 scenario | Yes | Cash-flow projection |

### Visibility rules

- Assumption panel is one click from the recommendation view
- When user changes an assumption, the recommendation re-renders with a "What changed" callout
- When IRS publishes new actual data (e.g., 2027 brackets), the projection visibly shifts and the user sees why ("2027 brackets published; was projected $X / actual $Y")

### What this rules out

- Hidden assumptions baked into the engine
- "Trust the algorithm" framing
- Recommendations that don't show their work

This is the trust moat. Pralana doesn't have a clean assumption panel; Boldin's is buried. RetireSmartIRA can lead here with a single, prominent, always-accessible Assumption Panel.

---

## 9. UX patterns for output

### What the competitors do

- **Boldin**: year-by-year ladder + "compare to no conversion" headline number. Iterate.
- **Pralana**: spreadsheet view; year columns × constraint rows; output is a chart of cumulative balance.
- **MaxiFi**: year-by-year affordable spending number; conversions are a *cause*, not the *output*.
- **Income Lab**: ladder + IRMAA-tier sidebar + SS-claiming integration.

### What none of them do well — the differentiation moats

1. **"Why this much, why this year"** — text explanations. RetireSmartIRA leads here.
2. **Waterfall chart visualizing capital flow** — outside-reviewer recommendation. Show year-by-year tax-free Roth growth (brand teal) vs. taxes paid (gray) vs. cliff costs (amber). Visually proves the math without forcing the user to read a wall of text.
3. **Cliff visualization** with the recommendation overlaid — 1.9's cost-spike chart already exists; 2.0 adds a vertical line showing where the recommended conversion lands.
4. **Native macOS feel** — every competitor is web-only. Crisp typography, real animations, offline-capable.
5. **Single recommended ladder** with discoverable alternatives — modern UX choice vs. Boldin's pick-from-5-strategies.
6. **Stress-test framing for sensitive inputs** — outside-reviewer recommendation. Don't ask "when does your spouse die"; offer "Stress test: if primary spouse passes at age X, here's the survivor impact."

### The "why this year" explanation pattern

Each year's recommendation card shows:
- Recommended conversion amount (bold)
- One-line headline ("Fills 22% bracket; stays under IRMAA Tier 1")
- Constraint proximity ("$3,200 from IRMAA Tier 1 ceiling")
- Tradeoff narration ("Crossing tier 1 would cost $2,400 in 2030 Medicare; lifetime benefit insufficient")
- Expandable: full reasoning with all five supporting metrics

---

## 10. Edge cases the engine must handle

| Edge case | 1.9 status | 2.0 must address |
|---|---|---|
| Pre-RMD age (47-72) vs RMD-age (73+) | Single-year only | Yes — different optimization shapes |
| Spouse death / widow bracket jump | Warning surfaced | Yes — first-class driver via stress-test toggle |
| Inherited IRAs with 10-year rule | Modeled separately | Respect, don't re-solve |
| State tax changes mid-horizon | Single state | Allow per-year state override |
| Estate / heirs' brackets | Not addressed | Optional supporting metric (not driver) |
| QCD interactions | Modeled in 1.9 | Reuse — QCDs reduce taxable RMD |
| HSA / contribution levers | 1.9 handles annual | Allow per-year variation |
| SS claiming age interactions | Single-claim assumption | Yes — SS taxability is conversion-pivotal |
| Health-status / longevity uncertainty | User-input lifespan | Stress-test add-on; defer probabilistic to later |
| Account ordering (Trad vs 401(k) vs Roth 401(k)) | Single-account model | Yes — first-touch ordering matters |
| **Liquidity / cash-to-pay-tax** | Not addressed | **Yes — hard constraint, single-bucket in 2.0** |
| **Concentrated brokerage low-basis** | Not addressed | Acceptable approximation in 2.0 (defer real handling to 2.1) |

---

## 11. Open design questions for the brainstorm

The original Section 9 list, revised with what the critiques and discussions resolved:

### Resolved (carry forward as decisions)

- ✅ **Engine name**: `MultiYearTaxStrategyEngine` (not Roth-only)
- ✅ **Default objective**: Maximize after-tax lifetime wealth (until both spouses deceased)
- ✅ **Horizon**: Until both spouses deceased; mortality made visible & overrideable
- ✅ **Heir impact**: Supporting metric, not driver
- ✅ **Constraint hardness**: Soft by default with explanation; user can convert to hard
- ✅ **Output format**: Single recommendation + discoverable alternatives + waterfall chart
- ✅ **Uncertainty handling**: 3-scenario per scope doc + stress-test toggles
- ✅ **Liquidity**: Hard constraint via single-bucket approximation
- ✅ **Re-optimization cadence**: One-shot for 2.0; tied to plan-history feature

### Still open — the actual brainstorm targets

1. **State-transition model.** The biggest blocker. How do account balances grow? Single deterministic rate or 3-scenario fork? How does TaxYearConfig project to 2027+? CPI projection or year-specific JSON or hybrid? How does horizon terminate? How does filing status transition?

2. **Apple Silicon compute commitment.** Build a perf prototype before deciding whether to commit to scope C+D (medium) or push to E (DP). What's the time budget for "generate recommendation"?

3. **Assumption panel UX surface.** Where in the navigation? Modal vs. sidebar vs. tab? How do changes propagate?

4. **Soft-constraint tradeoff narration.** When the engine crosses a cliff, what's the *exact format* of the explanation? One sentence? Tooltip? Expandable card?

5. **Account ordering rule.** When converting, which account first — Trad IRA or Trad 401(k)? Engine recommends or user specifies?

6. **Integration with existing single-year scenario.** Does 2.0's multi-year recommendation override single-year decisions, or run alongside? Which is "active" for the dashboard view?

7. **5-year rule warning surface.** When pre-59½ withdrawal would be needed, where does the warning appear? Inline on the year? In the assumption panel? Both?

8. **Recommendation re-narration.** When user overrides a year's amount, does the engine re-narrate downstream years' recommendations or just show the impact? What's the latency budget?

9. **First architecture sketch.** With everything decided, what does the file structure look like? (See Section 12 for first cut.)

---

## 12. Architecture sketch

### Proposed new files

```
RetireSmartIRA/
├── MultiYearTaxStrategyEngine.swift     ← NEW: outer optimization loop
├── MultiYearProjection.swift            ← NEW: year-by-year state propagation
├── MultiYearStrategyResult.swift        ← NEW: result data structure (ladder + reasoning)
├── TaxStrategyObjective.swift           ← NEW: objective function enum + evaluators
├── ProjectedTaxYearConfig.swift         ← NEW: CPI-based projection wrapper
├── LiquidityProjection.swift            ← NEW: single-bucket cash-flow tracker
└── (1.9 engines reused unchanged)

RetireSmartIRATests/
├── MultiYearTaxStrategyEngineTests.swift
├── ProjectedTaxYearConfigTests.swift
├── LiquidityProjectionTests.swift
├── TaxStrategyObjectiveTests.swift
└── ...
```

### Reuses from 1.9 (substantial)

- `TaxCalculationEngine` — call once per year for federal tax + IRMAA + NIIT
- `ACASubsidyEngine` — call once per year for FPL/cliff during pre-Medicare years
- `MedicareCostEngine` — call once per year for Medicare cost projection (2-year lookback already handled)
- `ScenarioWarningEngine` — fires per year for cliff warnings
- `FederalAGI` / `ACAMAGI` / `IRMAAMAGI` typed wrappers — already enforce right-MAGI-into-right-engine
- `RMDCalculationEngine` — for projecting RMD trajectory across horizon
- `TaxYearConfig.loadOrFallback(forYear:)` — wrapped by `ProjectedTaxYearConfig` for forward projection

### `ProjectedTaxYearConfig` — the year-projection mechanism

The single hardest infrastructure problem: the engine optimizes across years 2026 → 2050+. RetireSmartIRA only has `tax-2026.json`. The wrapper:

```swift
struct ProjectedTaxYearConfig {
    let baseYear: Int
    let baseConfig: TaxYearConfig
    let cpiAssumption: Double  // user-overridable, default 0.025

    func config(forYear year: Int) -> TaxYearConfig {
        // If year-specific JSON exists, use it
        if let actual = TaxYearConfig.load(forYear: year) {
            return actual
        }
        // Else project: brackets, IRMAA tiers, FPL, deductions all inflate
        return projectedConfig(from: baseConfig, by: year - baseYear)
    }
}
```

**Visibility:** the assumption panel shows "Tax brackets projected at 2.5% inflation; if IRS releases actual brackets, projection updates." When `tax-2027.json` ships, the projection silently swaps for the actual year. User can see when projection vs. actual is in play per year.

### `LiquidityProjection` — the cash-flow tracker

Tracks single liquid bucket year by year:

```swift
struct LiquidityProjection {
    let openingCash: Double
    let growthRate: Double
    let yearByYearIncome: [Int: Double]
    let yearByYearExpenses: [Int: Double]

    func cashAvailable(atYear year: Int, afterTax: Double) -> Double {
        // year N cash = (N-1 cash * (1+growth)) + income - expenses - tax
    }

    func canFundConversionTax(amount: Double, atYear year: Int) -> (canFund: Bool, efficiencyLoss: Double)
}
```

### State management

`ScenarioStateManager` already has the contribution levers and current-year Roth conversion. 2.0 needs:
- A `MultiYearScenarioStateManager` (or extension) holding the year-by-year state vector
- Storage for "the recommended ladder" via `PersistenceManager` (same pattern as 1.9 Medicare/ACA persistence)
- The Assumption Panel as a separate state group (CPI, growth rate, mortality, etc.)

### UI surface

Two natural homes:
1. **New "Multi-Year Plan" tab** in Tax Planning. Shows the ladder, waterfall chart, supporting metrics, and the assumption panel.
2. **Reduce-AGI dashboard section** (1.9 just shipped) gets a new bullet: "Optimal multi-year strategy: convert $X this year, $Y next year… [see Multi-Year Plan]."

The dashboard hook is essential — ties 2.0's headline feature into existing UX rather than creating a parallel UI.

### Test strategy

- Unit tests on each `TaxStrategyObjective` evaluator
- Unit tests on `ProjectedTaxYearConfig` (year 2026 actual = real config; year 2030 = projection)
- Unit tests on `LiquidityProjection` (cash-constrained scenarios)
- Integration test on canonical Kitces "fill-the-22%-bracket" example — verify engine reproduces published recommendation within 1% tolerance
- Edge case tests: pre-RMD only, RMD-age, widow stress-test, mixed-Medicare household, cash-poor scenario, high-basis vs low-basis brokerage

### Brainstorm recommendation

Start the implementation phase with these as ordered tasks:

1. **`ProjectedTaxYearConfig` first.** Without it, no future-year evaluation works. Pin the CPI projection mechanism. Test against 1.9's `tax-2026.json` actuals.
2. **`LiquidityProjection` second.** Single-bucket projection logic. Test cash-constrained scenarios.
3. **Perf prototype third.** Build a stub `MultiYearTaxStrategyEngine` that runs a brute-force grid for one fixed scenario. Measure on M-series. Decide whether to commit to scope C+D or push toward E.
4. **Then the actual engine + UI.**

Putting items 1-3 first means you don't write the engine until the foundation is benched and proven.

---

## Sources cited

- Boldin: [Roth Conversion Explorer best practices](https://help.boldin.com/en/articles/14151227-boldin-s-roth-conversion-explorer-best-practices), [Strong Engagement survey](https://www.boldin.com/retirement/strong-engagement-high-confidence-what-boldins-survey-of-users-reveals-about-strategizing-roth-conversions/), [Highest Estate Value strategy](https://help.boldin.com/en/articles/12067249-boldin-s-highest-estate-value-roth-conversion-strategy), [Iteration not perfection](https://www.boldin.com/retirement/planning-for-uncertainty-why-roth-conversions-require-iteration-not-perfection-its-an-art-not-a-science/)
- Pralana: [Online/Gold features](https://pralanaretirementcalculator.com/pralana-gold/), [Analysis & Optimization](https://pralanaretirementcalculator.com/analysis-optimization/)
- MaxiFi: [Roth Conversion Optimizer](https://www.maxifi.com/features/roth-conversion-optimizer), [Consumption Smoothing](https://www.maxifi.com/why-maxifi/economics-based-planning), [Kotlikoff substack](https://larrykotlikoff.substack.com/p/theres-money-in-them-thar-roth-conversions)
- Income Lab: [Best Roth Conversion Software 2026](https://incomelaboratory.com/best-roth-conversion-software/), [IRMAA Brackets 2026 Guide](https://incomelaboratory.com/irmaa-brackets-2026-guide/)
- OBBBA: [IRS bill provisions](https://www.irs.gov/newsroom/one-big-beautiful-bill-provisions), [H&R Block analysis](https://www.hrblock.com/tax-center/irs/tax-law-and-policy/one-big-beautiful-bill-taxes/), [Highland Financial Advisors update](https://www.highlandplanning.com/learning-center-1/roth-ira-conversions-under-the-one-big-beautiful-bill-act-for-2025-and-2026)
- T.D. 10001: [Grant Thornton summary](https://www.grantthornton.com/insights/newsletters/tax/2024/hot-topics/jul-30/final-rmd-rules-retain-10-year-rule-for-inherited-retirement-accounts), [Kitces analysis](https://www.kitces.com/blog/secure-act-2-0-irs-regulations-rmd-required-minimum-distributions-10-year-rule-eligible-designated-beneficiary-see-through-conduit-trust/)
- Widow penalty: [FPA Journal](https://www.financialplanningassociation.org/learning/publications/journal/DEC23-widow-tax-hit-debunked-OPEN), [Retirement Planning Advisors](https://retirementplanningadvisors.com/articles/decrease-the-impact-of-the-widows-penalty-with-roth-conversions)
- Kitces: [Tax diversification & Roth alpha](https://www.kitces.com/blog/tax-diversification-roth-optimization-conversion-tax-alpha/), [Kitces Roth course](https://www.kitces.com/roth-conversions-course/)
- Mike Piper: [Oblivious Investor](https://obliviousinvestor.com/), [Roth Conversion Deep Dive](https://obliviousinvestor.com/roth-conversion-deep-dive-addressing-left-out-topics/), [Open Social Security](https://opensocialsecurity.com)
- Medicare 2026: CMS Part B premium ($202.90/month) — [confirm via CMS announcement](https://www.cms.gov/) before merge

---

*End of prep doc v2. Total: ~5,200 words. Ready for brainstorm.*
